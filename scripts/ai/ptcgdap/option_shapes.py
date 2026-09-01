from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Mapping

from .enum_snapshot import extract_int_enums
from .source_lock import load_json_strict, resolve_locked_artifact


EXPECTED_SCHEMA_VERSION = 1
ENUM_ARTIFACT_ID = "official_cg_api_py"
WRITER_ARTIFACT_ID = "official_api_json_h"
MISSING_FIELD_POLICY = "preserve_missing_distinct_from_explicit_null"


@dataclass(frozen=True)
class OptionShapeIssue:
    code: str
    detail: str
    expected: Any = None
    actual: Any = None


@dataclass
class OptionShapeReport:
    option_type_count: int = 0
    shape_count: int = 0
    source_hashes: dict[str, str] = field(default_factory=dict)
    issues: list[OptionShapeIssue] = field(default_factory=list)

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
        self.issues.append(OptionShapeIssue(code, detail, expected, actual))

    def to_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "option_type_count": self.option_type_count,
            "shape_count": self.shape_count,
            "source_hashes": dict(sorted(self.source_hashes.items())),
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
        elif state in {"string", "character"}:
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
        elif state in {"string", "character"}:
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


def _brace_depth_at(source: str, position: int) -> int:
    depth = 0
    quote: str | None = None
    index = 0
    while index < position:
        char = source[index]
        if quote is not None:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in {'"', "'"}:
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth < 0:
                raise ValueError("unbalanced braces in SelectOptionJson case")
        index += 1
    return depth


def extract_select_option_cases(api_json_path: str | Path) -> dict[str, list[str]]:
    source = Path(api_json_path).read_text(encoding="utf-8-sig")
    body = _strip_cpp_comments(_extract_cpp_function_body(source, "SelectOptionJson"))

    append_key_calls = re.findall(r"\bj\s*\.\s*appendKey\s*\(", body)
    literal_keys = re.findall(r'\bj\s*\.\s*appendKey\s*\(\s*"([^"]+)"', body)
    if len(append_key_calls) != 1 or literal_keys != ["type"]:
        raise ValueError('SelectOptionJson must emit exactly one literal appendKey("type")')
    if re.search(r"\bswitch\s*\(\s*option\s*\.\s*type\s*\)", body) is None:
        raise ValueError("SelectOptionJson must switch on option.type")
    if re.search(
        r"\bif\s*\(\s*!\s*web\s*\)\s*\{\s*j\s*\.\s*append\s*\(\s*\(\s*int\s*\)\s*option\s*\.\s*type\s*\)\s*;\s*\}",
        body,
        flags=re.DOTALL,
    ) is None:
        raise ValueError("SelectOptionJson non-web path must emit (int)option.type")

    labels = list(
        re.finditer(
            r"(?m)^\s*(?:case\s+SelectOptionType::(?P<case>[A-Za-z_][A-Za-z0-9_]*)\s*:|(?P<default>default)\s*:)",
            body,
        )
    )
    if not labels:
        raise ValueError("SelectOptionJson contains no SelectOptionType cases")
    if sum(match.group("default") is not None for match in labels) != 1:
        raise ValueError("SelectOptionJson must contain exactly one default case")

    cases: dict[str, list[str]] = {}
    matched_field_call_count = 0
    for label_index, label in enumerate(labels):
        segment_end = (
            labels[label_index + 1].start()
            if label_index + 1 < len(labels)
            else len(body)
        )
        segment = body[label.end() : segment_end]
        if len(re.findall(r"\bbreak\s*;", segment)) != 1:
            case_label = label.group("case") or "default"
            raise ValueError(f"SelectOptionJson {case_label} must contain exactly one break")
        case_name = label.group("case")
        if case_name is None:
            continue
        if case_name in cases:
            raise ValueError(f"duplicate SelectOptionType case: {case_name}")
        web_labels = re.findall(
            r'\bj\s*\.\s*appendDoubleQuote\s*\(\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*\)',
            segment,
        )
        if web_labels != [case_name]:
            raise ValueError(
                f"SelectOptionJson {case_name} web label must exactly match its case"
            )
        all_calls = re.findall(r"\bj\s*\.\s*appendCommaKeyValue\s*\(", segment)
        field_matches = list(re.finditer(
            r'\bj\s*\.\s*appendCommaKeyValue\s*\(\s*"([A-Za-z_][A-Za-z0-9_]*)"',
            segment,
        ))
        fields = [match.group(1) for match in field_matches]
        if len(all_calls) != len(fields):
            raise ValueError(
                f"SelectOptionJson {case_name} contains a non-literal field name"
            )
        if len(fields) != len(set(fields)):
            raise ValueError(f"SelectOptionJson {case_name} contains duplicate fields")
        if "type" in fields:
            raise ValueError(f"SelectOptionJson {case_name} emits type more than once")
        if any(_brace_depth_at(segment, match.start()) != 0 for match in field_matches):
            raise ValueError(
                f"SelectOptionJson {case_name} contains a conditional sparse field"
            )
        matched_field_call_count += len(fields)
        cases[case_name] = fields

    all_field_call_count = len(
        re.findall(r"\bj\s*\.\s*appendCommaKeyValue\s*\(", body)
    )
    if matched_field_call_count != all_field_call_count:
        raise ValueError("appendCommaKeyValue call exists outside a SelectOptionType case")
    return cases


def extract_option_sparse_shapes(
    api_path: str | Path,
    api_json_path: str | Path,
) -> tuple[dict[str, int], dict[str, list[str]]]:
    enums = extract_int_enums(api_path)
    option_types = enums.get("OptionType")
    if not isinstance(option_types, dict) or not option_types:
        raise ValueError("official api.py contains no OptionType IntEnum")
    if any(type(value) is not int for value in option_types.values()):
        raise ValueError("OptionType ordinals must be integer literals")
    if len(set(option_types.values())) != len(option_types):
        raise ValueError("OptionType ordinals must be unique")

    cpp_cases = extract_select_option_cases(api_json_path)
    cases_by_enum_name: dict[str, list[str]] = {}
    for cpp_name, fields in cpp_cases.items():
        enum_name = _cpp_case_to_python_enum(cpp_name)
        if enum_name in cases_by_enum_name:
            raise ValueError(f"C++ case names collide after normalization: {enum_name}")
        cases_by_enum_name[enum_name] = fields
    if set(cases_by_enum_name) != set(option_types):
        raise ValueError(
            "SelectOptionJson cases do not match official api.py OptionType names: "
            f"missing={sorted(set(option_types) - set(cases_by_enum_name))}, "
            f"extra={sorted(set(cases_by_enum_name) - set(option_types))}"
        )

    shapes = {
        str(ordinal): ["type", *cases_by_enum_name[name]]
        for name, ordinal in sorted(option_types.items(), key=lambda item: item[1])
    }
    return dict(option_types), shapes


def _require_option_types(value: Any) -> dict[str, int]:
    if not isinstance(value, dict) or not value:
        raise ValueError("contract option_types must be a non-empty object")
    if any(not isinstance(name, str) or type(ordinal) is not int for name, ordinal in value.items()):
        raise ValueError("contract option_types must map names to integer ordinals")
    if len(set(value.values())) != len(value):
        raise ValueError("contract option_type ordinals must be unique")
    return dict(value)


def _require_shapes(value: Any) -> dict[str, list[str]]:
    if not isinstance(value, dict) or not value:
        raise ValueError("contract shapes must be a non-empty object")
    result: dict[str, list[str]] = {}
    for raw_type, fields in value.items():
        if (
            not isinstance(raw_type, str)
            or not raw_type.isdecimal()
            or raw_type != str(int(raw_type))
        ):
            raise ValueError("contract shape keys must be canonical non-negative ordinals")
        if (
            not isinstance(fields, list)
            or not fields
            or any(not isinstance(field_name, str) for field_name in fields)
            or fields[0] != "type"
            or len(fields) != len(set(fields))
        ):
            raise ValueError(f"invalid contract sparse shape: {raw_type}")
        result[raw_type] = list(fields)
    return result


def verify_option_shape_contract(
    contract_path: str | Path,
    source_lock_path: str | Path,
    *,
    root_overrides: Mapping[str, str | Path] | None = None,
) -> OptionShapeReport:
    report = OptionShapeReport()
    try:
        contract = load_json_strict(Path(contract_path))
        source_lock = load_json_strict(Path(source_lock_path))
        if not isinstance(contract, dict) or not isinstance(source_lock, dict):
            raise ValueError("contract and source lock roots must be objects")
        if (
            type(contract.get("schema_version")) is not int
            or contract.get("schema_version") != EXPECTED_SCHEMA_VERSION
        ):
            raise ValueError(
                f"unsupported option shape schema: {contract.get('schema_version')!r}"
            )
        if contract.get("source_lock_id") != source_lock.get("lock_id"):
            raise ValueError("option shape contract source_lock_id does not match SOURCE_LOCK")
        if contract.get("missing_field_policy") != MISSING_FIELD_POLICY:
            report.add(
                "missing_field_policy_mismatch",
                "missing fields must remain distinct from explicit null",
                MISSING_FIELD_POLICY,
                contract.get("missing_field_policy"),
            )

        enum_artifact_id = contract.get("enum_source_artifact_id")
        writer_artifact_id = contract.get("writer_source_artifact_id")
        if enum_artifact_id != ENUM_ARTIFACT_ID:
            raise ValueError(f"unexpected OptionType source artifact: {enum_artifact_id!r}")
        if writer_artifact_id != WRITER_ARTIFACT_ID:
            raise ValueError(f"unexpected SelectOptionJson source artifact: {writer_artifact_id!r}")

        api_path, enum_artifact = resolve_locked_artifact(
            source_lock,
            enum_artifact_id,
            root_overrides=root_overrides,
        )
        api_json_path, writer_artifact = resolve_locked_artifact(
            source_lock,
            writer_artifact_id,
            root_overrides=root_overrides,
        )
        for label, artifact, contract_hash_key in (
            ("enum", enum_artifact, "enum_source_sha256"),
            ("writer", writer_artifact, "writer_source_sha256"),
        ):
            if artifact.get("hash_mode") != "raw_bytes":
                raise ValueError(f"{label} source artifact must use raw_bytes hashing")
            locked_hash = artifact.get("sha256")
            report.source_hashes[label] = str(locked_hash)
            if contract.get(contract_hash_key) != locked_hash:
                report.add(
                    "source_hash_binding_mismatch",
                    f"{label} source hash differs from SOURCE_LOCK",
                    locked_hash,
                    contract.get(contract_hash_key),
                )

        actual_option_types, actual_shapes = extract_option_sparse_shapes(
            api_path, api_json_path
        )
        expected_option_types = _require_option_types(contract.get("option_types"))
        expected_shapes = _require_shapes(contract.get("shapes"))
        report.option_type_count = len(actual_option_types)
        report.shape_count = len(actual_shapes)
        if expected_option_types != actual_option_types:
            report.add(
                "option_type_ordinal_mismatch",
                "official api.py OptionType ordinals differ from the contract",
                expected_option_types,
                actual_option_types,
            )
        if expected_shapes != actual_shapes:
            report.add(
                "option_shape_mismatch",
                "SelectOptionJson sparse fields differ from the contract",
                expected_shapes,
                actual_shapes,
            )
    except (
        OSError,
        ValueError,
        TypeError,
        KeyError,
        RuntimeError,
        SyntaxError,
        json.JSONDecodeError,
    ) as exc:
        report.add("option_shape_verification_error", str(exc))
    return report
