from __future__ import annotations

import ast
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Mapping

from .enum_snapshot import extract_int_enums
from .option_shapes import extract_option_sparse_shapes
from .source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
    resolve_locked_artifact,
    sha256_bytes,
    sha256_file,
)


EXPECTED_SCHEMA_VERSION = 1
PROFILE_ID = "cabt_typed_view_profile_v1"
PYTHON_API_ARTIFACT_ID = "official_cg_api_py"
OBSERVATION_WRITER_ARTIFACT_ID = "official_to_json_h"
OPTION_LOG_WRITER_ARTIFACT_ID = "official_api_json_h"

_PROFILE_SOURCE_ARTIFACTS = {
    "python_api": PYTHON_API_ARTIFACT_ID,
    "observation_writer": OBSERVATION_WRITER_ARTIFACT_ID,
    "option_log_writer": OPTION_LOG_WRITER_ARTIFACT_ID,
}
_SHAPE_NAMES = (
    "Card",
    "Pokemon",
    "PlayerState",
    "State",
    "Option",
    "SelectData",
    "Log",
)
_OBSERVATION_WRITER_FUNCTIONS = {
    "Card": "CardJson",
    "Pokemon": "PokemonJson",
    "PlayerState": "PlayerJson",
    "State": "Current",
    "SelectData": "SelectJson",
}
_WRITER_FIELD_EXCLUSIONS = {
    "Card": {"name": "non_agent_add_name_mode"},
    "Pokemon": {"name": "non_agent_add_name_mode"},
    "PlayerState": {"deck": "non_contract_send_deck_or_visualizer"},
    "State": {"lookingCount": "web_only"},
    "SelectData": {},
}
_POLICIES: dict[str, Any] = {
    "field_presence": "preserve_missing_null_value",
    "known_view_search_capability": "exclude_search_begin_input",
    "integer_wire_type": "exact_integer_node_only; integral binary64 values are not coerced",
    "unknown_enum": "preserve_raw_integer_fail_closed",
    "safe_metadata_unknown_pointer": "forbidden; the Host-private quarantine index may retain pointers but safe/public metadata omits them",
    "unknown_subtree": {
        "action": "quarantine_entire_subtree",
        "descend_into_unknown_object": False,
        "metadata_fields": ["pointer", "presence", "json_type"],
        "raw_value_location": "raw_payload_only",
    },
}
_EXPECTED_TOP_LEVEL_KEYS = {
    "schema_version",
    "profile_id",
    "source_lock_id",
    "sources",
    "policies",
    "callback_root",
    "framework_fields",
    "shapes",
    "option_types",
    "option_shapes",
    "log_types",
    "log_shapes",
    "enum_locations",
}


@dataclass(frozen=True)
class TypedViewContractIssue:
    code: str
    detail: str
    expected: Any = None
    actual: Any = None


@dataclass
class TypedViewContractReport:
    shape_count: int = 0
    option_shape_count: int = 0
    log_shape_count: int = 0
    source_hashes: dict[str, str] = field(default_factory=dict)
    profile_canonical_sha256: str | None = None
    issues: list[TypedViewContractIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.issues

    def add(
        self,
        code: str,
        detail: str,
        expected: Any = None,
        actual: Any = None,
    ) -> None:
        self.issues.append(TypedViewContractIssue(code, detail, expected, actual))

    def to_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "shape_count": self.shape_count,
            "option_shape_count": self.option_shape_count,
            "log_shape_count": self.log_shape_count,
            "source_hashes": dict(sorted(self.source_hashes.items())),
            "profile_canonical_sha256": self.profile_canonical_sha256,
            "issues": [asdict(issue) for issue in self.issues],
        }


def _extract_cpp_function_body(source: str, function_name: str) -> str:
    signatures = list(
        re.finditer(
            rf"\b(?:inline\s+)?void\s+{re.escape(function_name)}\s*\([^)]*\)\s*\{{",
            source,
        )
    )
    if len(signatures) != 1:
        raise ValueError(f"expected exactly one {function_name} definition")
    opening_brace = signatures[0].end() - 1
    depth = 1
    index = opening_brace + 1
    state = "normal"
    while index < len(source):
        char = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "normal":
            if char == "/" and following == "/":
                state = "line_comment"
                index += 2
                continue
            if char == "/" and following == "*":
                state = "block_comment"
                index += 2
                continue
            if char == '"':
                state = "string"
            elif char == "'":
                state = "character"
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return source[opening_brace + 1 : index]
        elif state == "line_comment":
            if char in "\r\n":
                state = "normal"
        elif state == "block_comment":
            if char == "*" and following == "/":
                state = "normal"
                index += 2
                continue
        else:
            if char == "\\":
                index += 2
                continue
            if (state == "string" and char == '"') or (
                state == "character" and char == "'"
            ):
                state = "normal"
        index += 1
    raise ValueError(f"unterminated {function_name} definition")


def _strip_cpp_comments(source: str) -> str:
    result: list[str] = []
    index = 0
    state = "normal"
    while index < len(source):
        char = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "normal":
            if char == "/" and following == "/":
                result.extend((" ", " "))
                state = "line_comment"
                index += 2
                continue
            if char == "/" and following == "*":
                result.extend((" ", " "))
                state = "block_comment"
                index += 2
                continue
            result.append(char)
            if char == '"':
                state = "string"
            elif char == "'":
                state = "character"
        elif state == "line_comment":
            result.append(char if char in "\r\n" else " ")
            if char in "\r\n":
                state = "normal"
        elif state == "block_comment":
            if char == "*" and following == "/":
                result.extend((" ", " "))
                state = "normal"
                index += 2
                continue
            result.append(char if char in "\r\n" else " ")
        else:
            result.append(char)
            if char == "\\" and following:
                result.append(following)
                index += 2
                continue
            if (state == "string" and char == '"') or (
                state == "character" and char == "'"
            ):
                state = "normal"
        index += 1
    if state == "block_comment":
        raise ValueError("unterminated C++ block comment")
    return "".join(result)


def _cpp_case_to_python_enum(case_name: str) -> str:
    with_acronym_boundaries = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", case_name)
    with_word_boundaries = re.sub(
        r"([a-z0-9])([A-Z])", r"\1_\2", with_acronym_boundaries
    )
    return with_word_boundaries.upper()


def _extract_literal_writer_fields(source: str, function_name: str) -> list[str]:
    body = _strip_cpp_comments(_extract_cpp_function_body(source, function_name))
    call_pattern = re.compile(
        r"\bj\s*\.\s*(?:appendCommaKeyValue|appendKeyValue|appendCommaKey|appendKey)\s*\("
    )
    literal_pattern = re.compile(
        r"\bj\s*\.\s*"
        r"(?:appendCommaKeyValue|appendKeyValue|appendCommaKey|appendKey)"
        r'\s*\(\s*"([^"\\]+)"'
    )
    calls = call_pattern.findall(body)
    literals = literal_pattern.findall(body)
    if len(calls) != len(literals):
        raise ValueError(f"{function_name} contains a non-literal JSON field name")
    ordered: list[str] = []
    for field_name in literals:
        if field_name not in ordered:
            ordered.append(field_name)
    return ordered


def _flatten_union(annotation: ast.expr) -> list[ast.expr]:
    if isinstance(annotation, ast.BinOp) and isinstance(annotation.op, ast.BitOr):
        return [*_flatten_union(annotation.left), *_flatten_union(annotation.right)]
    return [annotation]


def _type_descriptor(
    annotation: ast.expr,
    *,
    enum_names: set[str],
    shape_names: set[str],
) -> dict[str, Any]:
    union_parts = _flatten_union(annotation)
    non_null = [
        part
        for part in union_parts
        if not (isinstance(part, ast.Constant) and part.value is None)
    ]
    nullable = len(non_null) != len(union_parts)
    if len(non_null) != 1:
        raise ValueError(f"unsupported annotation union: {ast.unparse(annotation)}")
    value = non_null[0]
    if isinstance(value, ast.Name):
        if value.id == "int":
            descriptor: dict[str, Any] = {"kind": "integer"}
        elif value.id == "bool":
            descriptor = {"kind": "boolean"}
        elif value.id == "str":
            descriptor = {"kind": "string"}
        elif value.id in enum_names:
            descriptor = {"kind": "integer", "enum": value.id}
        elif value.id in shape_names:
            descriptor = {"kind": "shape", "shape": value.id}
        else:
            raise ValueError(f"unsupported annotation name: {value.id}")
    elif (
        isinstance(value, ast.Subscript)
        and isinstance(value.value, ast.Name)
        and value.value.id == "list"
    ):
        descriptor = {
            "kind": "array",
            "items": _type_descriptor(
                value.slice,
                enum_names=enum_names,
                shape_names=shape_names,
            ),
        }
    else:
        raise ValueError(f"unsupported annotation: {ast.unparse(annotation)}")
    descriptor["nullable"] = nullable
    return descriptor


def _extract_sdk_fields(
    api_path: str | Path,
) -> tuple[dict[str, list[dict[str, Any]]], dict[str, dict[str, int]]]:
    path = Path(api_path)
    tree = ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
    enums = extract_int_enums(path)
    enum_names = set(enums)
    dataclass_nodes: dict[str, ast.ClassDef] = {}
    for node in tree.body:
        if not isinstance(node, ast.ClassDef):
            continue
        if any(
            isinstance(decorator, ast.Name) and decorator.id == "dataclass"
            for decorator in node.decorator_list
        ):
            dataclass_nodes[node.name] = node
    required_classes = {*_SHAPE_NAMES, "Observation"}
    missing = required_classes - set(dataclass_nodes)
    if missing:
        raise ValueError(f"official api.py is missing dataclasses: {sorted(missing)}")
    known_shapes = set(dataclass_nodes)
    result: dict[str, list[dict[str, Any]]] = {}
    for class_name in (*_SHAPE_NAMES, "Observation"):
        fields: list[dict[str, Any]] = []
        for statement in dataclass_nodes[class_name].body:
            if not isinstance(statement, ast.AnnAssign):
                continue
            if not isinstance(statement.target, ast.Name):
                raise ValueError(f"unsupported dataclass field target in {class_name}")
            descriptor = {
                "name": statement.target.id,
                **_type_descriptor(
                    statement.annotation,
                    enum_names=enum_names,
                    shape_names=known_shapes,
                ),
                "required": statement.value is None,
            }
            fields.append(descriptor)
        if not fields:
            raise ValueError(f"official dataclass contains no fields: {class_name}")
        if len({item["name"] for item in fields}) != len(fields):
            raise ValueError(f"duplicate official dataclass field: {class_name}")
        result[class_name] = fields
    return result, enums


def _shape_from_sdk_and_writer(
    shape_name: str,
    sdk_fields: list[dict[str, Any]],
    writer_fields: list[str],
) -> dict[str, Any]:
    sdk_by_name = {field["name"]: field for field in sdk_fields}
    additions: dict[str, dict[str, Any]] = {}
    if shape_name == "Pokemon" and "playerIndex" in writer_fields:
        additions["playerIndex"] = {
            "name": "playerIndex",
            "kind": "integer",
            "nullable": False,
            "required": True,
            "authority": "wire_only_sdk_gap",
        }
    exclusions = _WRITER_FIELD_EXCLUSIONS[shape_name]
    fields: list[dict[str, Any]] = []
    emitted_names: set[str] = set()
    for field_name in writer_fields:
        if field_name in sdk_by_name:
            descriptor = dict(sdk_by_name[field_name])
            descriptor["authority"] = "sdk_and_wire"
        elif field_name in additions:
            descriptor = dict(additions[field_name])
        else:
            continue
        fields.append(descriptor)
        emitted_names.add(field_name)
    for sdk_field in sdk_fields:
        if sdk_field["name"] in emitted_names:
            continue
        descriptor = dict(sdk_field)
        descriptor["authority"] = "sdk_only"
        fields.append(descriptor)
    quarantined: dict[str, str] = {}
    for field_name in writer_fields:
        if field_name in sdk_by_name or field_name in additions:
            continue
        quarantined[field_name] = exclusions.get(
            field_name, "unclassified_writer_only"
        )
    return {
        "fields": fields,
        "quarantined_writer_fields": quarantined,
        "sdk_fields_missing_from_writer": [
            field["name"]
            for field in sdk_fields
            if field["name"] not in writer_fields
        ],
    }


def _shape_from_sparse_writer(
    sdk_fields: list[dict[str, Any]],
    sparse_shapes: Mapping[str, list[str]],
) -> dict[str, Any]:
    wire_fields = {
        field_name for shape in sparse_shapes.values() for field_name in shape
    }
    sdk_names = {field["name"] for field in sdk_fields}
    fields: list[dict[str, Any]] = []
    for sdk_field in sdk_fields:
        descriptor = dict(sdk_field)
        descriptor["authority"] = (
            "sdk_and_wire" if sdk_field["name"] in wire_fields else "sdk_only"
        )
        fields.append(descriptor)
    return {
        "fields": fields,
        "quarantined_writer_fields": {
            name: "unclassified_writer_only" for name in sorted(wire_fields - sdk_names)
        },
        "sdk_fields_missing_from_writer": sorted(sdk_names - wire_fields),
    }


def extract_log_sparse_shapes(
    api_path: str | Path, api_json_path: str | Path
) -> tuple[dict[str, int], dict[str, list[str]]]:
    """Extract emitted API log keys, including hidden-information reverse variants."""
    enums = extract_int_enums(api_path)
    log_types = enums.get("LogType")
    if not isinstance(log_types, dict) or not log_types:
        raise ValueError("official api.py contains no LogType IntEnum")
    if any(type(value) is not int for value in log_types.values()):
        raise ValueError("LogType ordinals must be integer literals")
    if len(set(log_types.values())) != len(log_types):
        raise ValueError("LogType ordinals must be unique")

    source = Path(api_json_path).read_text(encoding="utf-8-sig")
    body = _strip_cpp_comments(_extract_cpp_function_body(source, "LogJson"))
    if re.search(r"\bswitch\s*\(\s*log\s*\.\s*logType\s*\)", body) is None:
        raise ValueError("LogJson must switch on log.logType")
    initial_type_keys = re.findall(r'\bj\s*\.\s*appendKey\s*\(\s*"([^"]+)"', body)
    if initial_type_keys != ["type"]:
        raise ValueError('LogJson must emit exactly one appendKey("type")')
    labels = list(
        re.finditer(
            r"(?m)^\s*(?:case\s+LogType::"
            r"(?P<case>[A-Za-z_][A-Za-z0-9_]*)\s*:|"
            r"(?P<default>default)\s*:)",
            body,
        )
    )
    if not labels or sum(label.group("default") is not None for label in labels) != 1:
        raise ValueError("LogJson must contain cases and exactly one default")
    case_names = {
        _cpp_case_to_python_enum(label.group("case"))
        for label in labels
        if label.group("case") is not None
    }
    if case_names != set(log_types):
        raise ValueError(
            "LogJson cases do not match official api.py LogType names: "
            f"missing={sorted(set(log_types) - case_names)}, "
            f"extra={sorted(case_names - set(log_types))}"
        )

    emit_pattern = re.compile(
        r"\bj\s*\.\s*append\s*\(\s*\(\s*int\s*\)\s*"
        r"(?P<value>log\s*\.\s*logType|LogType::[A-Za-z_][A-Za-z0-9_]*)"
        r"\s*\)\s*;"
    )
    field_pattern = re.compile(
        r'\bj\s*\.\s*appendCommaKeyValue\s*\(\s*"([A-Za-z_][A-Za-z0-9_]*)"'
    )
    all_shapes_by_name: dict[str, list[str]] = {}
    for label_index, label in enumerate(labels):
        case_name = label.group("case")
        segment_end = (
            labels[label_index + 1].start()
            if label_index + 1 < len(labels)
            else len(body)
        )
        segment = body[label.end() : segment_end]
        if case_name is None:
            continue
        if len(re.findall(r"\bbreak\s*;", segment)) != 1:
            raise ValueError(f"LogJson {case_name} must contain exactly one break")
        emitters = list(emit_pattern.finditer(segment))
        if not emitters:
            raise ValueError(f"LogJson {case_name} has no numeric API type emission")
        accounted_field_count = 0
        for emitter_index, emitter in enumerate(emitters):
            interval_end = (
                emitters[emitter_index + 1].start()
                if emitter_index + 1 < len(emitters)
                else len(segment)
            )
            fields = field_pattern.findall(segment[emitter.end() : interval_end])
            accounted_field_count += len(fields)
            if len(fields) != len(set(fields)):
                raise ValueError(
                    f"LogJson {case_name} emitted variant contains duplicate fields"
                )
            raw_value = re.sub(r"\s+", "", emitter.group("value"))
            emitted_name = (
                _cpp_case_to_python_enum(case_name)
                if raw_value == "log.logType"
                else _cpp_case_to_python_enum(raw_value.split("::", 1)[1])
            )
            preceding_start = (
                emitters[emitter_index - 1].end() if emitter_index else 0
            )
            web_labels = re.findall(
                r'\bj\s*\.\s*appendDoubleQuote\s*\(\s*"([A-Za-z_][A-Za-z0-9_]*)"',
                segment[preceding_start : emitter.start()],
            )
            if not web_labels or _cpp_case_to_python_enum(web_labels[-1]) != emitted_name:
                raise ValueError(
                    f"LogJson {case_name} web/API emitted types do not agree"
                )
            shape = ["type", *fields]
            previous = all_shapes_by_name.get(emitted_name)
            if previous is not None and previous != shape:
                raise ValueError(
                    f"LogJson emits conflicting sparse shapes for {emitted_name}"
                )
            all_shapes_by_name[emitted_name] = shape
        if accounted_field_count != len(field_pattern.findall(segment)):
            raise ValueError(
                f"LogJson {case_name} contains fields outside a numeric API variant"
            )
    if set(all_shapes_by_name) != set(log_types):
        raise ValueError(
            "LogJson emitted types do not cover official LogType: "
            f"missing={sorted(set(log_types) - set(all_shapes_by_name))}, "
            f"extra={sorted(set(all_shapes_by_name) - set(log_types))}"
        )
    shapes = {
        str(ordinal): all_shapes_by_name[name]
        for name, ordinal in sorted(log_types.items(), key=lambda item: item[1])
    }
    return dict(log_types), shapes


def _with_callback_authority(
    fields: list[dict[str, Any]], native_writer_fields: list[str]
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for field in fields:
        descriptor = dict(field)
        if field["name"] == "search_begin_input":
            descriptor["authority"] = "sdk_host_overlay"
        elif field["name"] in native_writer_fields:
            descriptor["authority"] = "sdk_and_native_wire"
        else:
            descriptor["authority"] = "sdk_only"
        result.append(descriptor)
    return result


def _collect_enum_locations(
    callback_fields: list[dict[str, Any]], shapes: Mapping[str, Mapping[str, Any]]
) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []

    def visit(descriptor: Mapping[str, Any], pointer: str) -> None:
        enum_name = descriptor.get("enum")
        if isinstance(enum_name, str):
            result.append({"enum": enum_name, "pattern": pointer})
        kind = descriptor.get("kind")
        if kind == "shape":
            shape_name = descriptor.get("shape")
            shape = shapes.get(str(shape_name))
            if not isinstance(shape, Mapping):
                raise ValueError(f"unresolved shape reference: {shape_name!r}")
            fields = shape.get("fields")
            if not isinstance(fields, list):
                raise ValueError(f"shape contains no field list: {shape_name!r}")
            for field in fields:
                if not isinstance(field, Mapping) or not isinstance(field.get("name"), str):
                    raise ValueError(f"invalid field descriptor in shape: {shape_name!r}")
                visit(field, f"{pointer}/{field['name']}")
        elif kind == "array":
            items = descriptor.get("items")
            if not isinstance(items, Mapping):
                raise ValueError("array descriptor contains no item contract")
            visit(items, f"{pointer}/*")

    for field in callback_fields:
        if field["name"] == "search_begin_input":
            continue
        visit(field, f"/{field['name']}")
    seen: set[tuple[str, str]] = set()
    unique: list[dict[str, str]] = []
    for location in result:
        identity = (location["enum"], location["pattern"])
        if identity not in seen:
            unique.append(location)
            seen.add(identity)
    return unique


def extract_typed_wire_profile(
    api_path: str | Path,
    to_json_path: str | Path,
    api_json_path: str | Path,
    *,
    source_lock_id: str | None = None,
) -> dict[str, Any]:
    """Build the language-neutral typed profile from the three official sources."""
    api_path = Path(api_path)
    to_json_path = Path(to_json_path)
    api_json_path = Path(api_json_path)
    sdk_fields, _ = _extract_sdk_fields(api_path)
    to_json_source = to_json_path.read_text(encoding="utf-8-sig")
    writer_fields = {
        shape_name: _extract_literal_writer_fields(to_json_source, function_name)
        for shape_name, function_name in _OBSERVATION_WRITER_FUNCTIONS.items()
    }
    native_root_fields = _extract_literal_writer_fields(to_json_source, "ToJsonApi")
    option_types, option_shapes = extract_option_sparse_shapes(
        api_path, api_json_path
    )
    log_types, log_shapes = extract_log_sparse_shapes(api_path, api_json_path)

    shapes: dict[str, dict[str, Any]] = {}
    for shape_name in ("Card", "Pokemon", "PlayerState", "State", "SelectData"):
        shapes[shape_name] = _shape_from_sdk_and_writer(
            shape_name,
            sdk_fields[shape_name],
            writer_fields[shape_name],
        )
    shapes["Option"] = _shape_from_sparse_writer(
        sdk_fields["Option"], option_shapes
    )
    shapes["Log"] = _shape_from_sparse_writer(sdk_fields["Log"], log_shapes)
    shapes = {name: shapes[name] for name in _SHAPE_NAMES}

    callback_fields = _with_callback_authority(
        sdk_fields["Observation"], native_root_fields
    )
    callback_root = {
        "name": "Callback",
        "fields": callback_fields,
        "known_view_fields": ["select", "logs", "current"],
        "native_writer_fields": native_root_fields,
        "host_overlay_fields": ["search_begin_input"],
        "sdk_fields_missing_from_native_writer": [
            field["name"]
            for field in sdk_fields["Observation"]
            if field["name"] not in native_root_fields
            and field["name"] != "search_begin_input"
        ],
        "unclassified_native_writer_fields": [
            name
            for name in native_root_fields
            if name not in {field["name"] for field in sdk_fields["Observation"]}
        ],
    }
    framework_fields = [
        {
            "name": "step",
            "view_name": "step",
            "kind": "integer",
            "nullable": True,
            "required": False,
            "authority": "kaggle_framework_overlay",
        },
        {
            "name": "remainingOverageTime",
            "view_name": "remaining_overage_time",
            "kind": "number",
            "nullable": True,
            "required": False,
            "authority": "kaggle_framework_overlay",
        },
    ]
    return {
        "schema_version": EXPECTED_SCHEMA_VERSION,
        "profile_id": PROFILE_ID,
        "source_lock_id": source_lock_id,
        "sources": {
            "python_api": {
                "artifact_id": PYTHON_API_ARTIFACT_ID,
                "sha256": sha256_file(api_path),
            },
            "observation_writer": {
                "artifact_id": OBSERVATION_WRITER_ARTIFACT_ID,
                "sha256": sha256_file(to_json_path),
            },
            "option_log_writer": {
                "artifact_id": OPTION_LOG_WRITER_ARTIFACT_ID,
                "sha256": sha256_file(api_json_path),
            },
        },
        "policies": _POLICIES,
        "callback_root": callback_root,
        "framework_fields": framework_fields,
        "shapes": shapes,
        "option_types": option_types,
        "option_shapes": option_shapes,
        "log_types": log_types,
        "log_shapes": log_shapes,
        "enum_locations": _collect_enum_locations(callback_fields, shapes),
    }


def verify_typed_view_contract(
    profile_path: str | Path,
    source_lock_path: str | Path,
    *,
    root_overrides: Mapping[str, str | Path] | None = None,
) -> TypedViewContractReport:
    """Verify a profile against strictly resolved and hash-checked locked sources."""
    report = TypedViewContractReport()
    try:
        profile = load_json_strict(Path(profile_path))
        source_lock = load_json_strict(Path(source_lock_path))
        if not isinstance(profile, dict) or not isinstance(source_lock, dict):
            raise ValueError("typed profile and source lock roots must be objects")
        report.profile_canonical_sha256 = sha256_bytes(
            canonical_json_v1_bytes(profile)
        )
        if type(profile.get("schema_version")) is not int or profile.get(
            "schema_version"
        ) != EXPECTED_SCHEMA_VERSION:
            raise ValueError(
                f"unsupported typed view profile schema: {profile.get('schema_version')!r}"
            )
        if profile.get("profile_id") != PROFILE_ID:
            raise ValueError(f"unexpected typed view profile id: {profile.get('profile_id')!r}")
        if set(profile) != _EXPECTED_TOP_LEVEL_KEYS:
            raise ValueError(
                "typed view profile top-level keys differ from the reviewed schema"
            )
        lock_id = source_lock.get("lock_id")
        if not isinstance(lock_id, str) or profile.get("source_lock_id") != lock_id:
            raise ValueError("typed view profile source_lock_id does not match SOURCE_LOCK")

        sources = profile.get("sources")
        if not isinstance(sources, dict) or set(sources) != set(
            _PROFILE_SOURCE_ARTIFACTS
        ):
            raise ValueError("typed view profile source bindings are incomplete")
        resolved_paths: dict[str, Path] = {}
        for source_name, artifact_id in _PROFILE_SOURCE_ARTIFACTS.items():
            path, artifact = resolve_locked_artifact(
                source_lock,
                artifact_id,
                root_overrides=root_overrides,
            )
            resolved_paths[source_name] = path
            if artifact.get("hash_mode") != "raw_bytes":
                raise ValueError(
                    f"typed profile source must use raw_bytes hashing: {artifact_id}"
                )
            locked_hash = artifact.get("sha256")
            if not isinstance(locked_hash, str):
                raise ValueError(f"locked source hash is invalid: {artifact_id}")
            report.source_hashes[source_name] = locked_hash
            declared = sources.get(source_name)
            if not isinstance(declared, dict):
                raise ValueError(f"typed profile source must be an object: {source_name}")
            if declared.get("artifact_id") != artifact_id:
                report.add(
                    "source_artifact_binding_mismatch",
                    f"{source_name} artifact id differs from the reviewed binding",
                    artifact_id,
                    declared.get("artifact_id"),
                )
            if declared.get("sha256") != locked_hash:
                report.add(
                    "source_hash_binding_mismatch",
                    f"{source_name} SHA-256 differs from SOURCE_LOCK",
                    locked_hash,
                    declared.get("sha256"),
                )

        actual = extract_typed_wire_profile(
            resolved_paths["python_api"],
            resolved_paths["observation_writer"],
            resolved_paths["option_log_writer"],
            source_lock_id=lock_id,
        )
        report.shape_count = len(actual["shapes"])
        report.option_shape_count = len(actual["option_shapes"])
        report.log_shape_count = len(actual["log_shapes"])
        if profile != actual:
            report.add(
                "typed_profile_mismatch",
                "typed view profile differs from the locked SDK and wire writers",
                profile,
                actual,
            )
    except (
        OSError,
        ValueError,
        TypeError,
        KeyError,
        RuntimeError,
        RecursionError,
        SyntaxError,
        json.JSONDecodeError,
    ) as exc:
        report.add("typed_profile_verification_error", str(exc))
    return report
