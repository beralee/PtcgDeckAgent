from __future__ import annotations

import copy
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from .cabt_tree_hash import (
    CabtTreeHashError,
    raw_private_hash,
    token_free_callback_hash,
)
from .contract_set import CabtContractSet, load_contract_set
from .source_lock import load_json_bytes_strict


ENVELOPE_VERSION = 1
HASH_PROFILE = "cabt_tree_hash_v1"
MAX_INPUT_BYTES = 64 * 1024 * 1024
MAX_JSON_DEPTH = 128
MAX_JSON_NODES = 1_000_000
SAFE_INTEGER_MIN = -(2**53) + 1
SAFE_INTEGER_MAX = 2**53 - 1
_REQUIRED_CALLBACK_FIELDS = ("select", "logs", "current", "search_begin_input")


@dataclass(frozen=True)
class CabtParseIssue:
    code: str
    pointer: str
    severity: str = "error"

    def to_dict(self) -> dict[str, str]:
        return {
            "code": self.code,
            "pointer": self.pointer,
            "severity": self.severity,
        }


@dataclass(frozen=True)
class EnvelopeParseResult:
    envelope: RawCabtEnvelope | None
    issues: tuple[CabtParseIssue, ...]

    @property
    def policy_eligible(self) -> bool:
        return self.envelope is not None and not any(
            issue.severity == "error" for issue in self.issues
        )

    @property
    def ok(self) -> bool:
        return self.policy_eligible

    def safe_diagnostics(self) -> list[dict[str, str]]:
        return [issue.to_dict() for issue in self.issues]


class _JsonTreeError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _validate_unicode_string(value: str) -> None:
    for character in value:
        codepoint = ord(character)
        if (
            0xD800 <= codepoint <= 0xDFFF
            or 0xFDD0 <= codepoint <= 0xFDEF
            or (codepoint & 0xFFFF) in (0xFFFE, 0xFFFF)
        ):
            raise _JsonTreeError("invalid_unicode")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise _JsonTreeError("invalid_unicode") from exc


class RawCabtEnvelope:
    __slots__ = (
        "_raw_payload",
        "_known_view",
        "_field_presence",
        "_unknown_fields",
        "_framework",
        "_enum_values",
        "_parse_issues",
        "_source_lock_id",
        "_source_contract_hash",
        "_raw_private_hash",
        "_token_free_callback_hash",
        "_opaque_search_capability_present",
    )

    def __init__(
        self,
        *,
        raw_payload: dict[str, Any],
        known_view: dict[str, Any],
        field_presence: dict[str, str],
        unknown_fields: list[dict[str, str]],
        framework: dict[str, Any],
        enum_values: list[dict[str, Any]],
        parse_issues: list[CabtParseIssue],
        source_lock_id: str,
        source_contract_hash: str,
        raw_hash: str,
        token_free_hash: str,
    ) -> None:
        self._raw_payload = copy.deepcopy(raw_payload)
        self._known_view = copy.deepcopy(known_view)
        self._field_presence = dict(field_presence)
        self._unknown_fields = copy.deepcopy(unknown_fields)
        self._framework = copy.deepcopy(framework)
        self._enum_values = copy.deepcopy(enum_values)
        self._parse_issues = tuple(parse_issues)
        self._source_lock_id = source_lock_id
        self._source_contract_hash = source_contract_hash
        self._raw_private_hash = raw_hash
        self._token_free_callback_hash = token_free_hash
        self._opaque_search_capability_present = (
            raw_payload["search_begin_input"] is not None
        )

    @property
    def raw_payload(self) -> dict[str, Any]:
        return copy.deepcopy(self._raw_payload)

    @property
    def known_view(self) -> dict[str, Any]:
        return copy.deepcopy(self._known_view)

    @property
    def field_presence(self) -> dict[str, str]:
        return dict(self._field_presence)

    @property
    def unknown_fields(self) -> list[dict[str, str]]:
        return copy.deepcopy(self._unknown_fields)

    @property
    def framework(self) -> dict[str, Any]:
        return copy.deepcopy(self._framework)

    @property
    def enum_values(self) -> list[dict[str, Any]]:
        return copy.deepcopy(self._enum_values)

    @property
    def parse_issues(self) -> list[dict[str, str]]:
        return [issue.to_dict() for issue in self._parse_issues]

    @property
    def source_lock_id(self) -> str:
        return self._source_lock_id

    @property
    def source_contract_hash(self) -> str:
        return self._source_contract_hash

    @property
    def raw_private_hash(self) -> str:
        return self._raw_private_hash

    @property
    def token_free_callback_hash(self) -> str:
        return self._token_free_callback_hash

    @property
    def opaque_search_capability_present(self) -> bool:
        return self._opaque_search_capability_present

    @property
    def firewall_status(self) -> str:
        return "pending"

    @property
    def public_observation_hash(self) -> None:
        return None

    @property
    def is_initial_callback(self) -> bool:
        return self._raw_payload["select"] is None

    def to_host_dict(self) -> dict[str, Any]:
        return {
            "envelope_version": ENVELOPE_VERSION,
            "source_lock_id": self.source_lock_id,
            "hash_profile": HASH_PROFILE,
            "raw_payload": self.raw_payload,
            "raw_private_hash": self.raw_private_hash,
            "token_free_callback_hash": self.token_free_callback_hash,
            "field_presence": self.field_presence,
            "known_view": self.known_view,
            "unknown_fields": self.unknown_fields,
            "framework": self.framework,
            "enum_values": self.enum_values,
            "parse_issues": self.parse_issues,
            "opaque_search_capability_present": self.opaque_search_capability_present,
            "firewall_status": self.firewall_status,
            "public_observation_hash": self.public_observation_hash,
            "source_contract_hash": self.source_contract_hash,
        }

    def safe_metadata(self) -> dict[str, Any]:
        safe_presence = {
            pointer: presence
            for pointer, presence in self._field_presence.items()
            if pointer != "/search_begin_input"
        }
        return {
            "envelope_version": ENVELOPE_VERSION,
            "source_lock_id": self.source_lock_id,
            "hash_profile": HASH_PROFILE,
            "source_contract_hash": self.source_contract_hash,
            "field_presence": safe_presence,
            "enum_values": self.enum_values,
            "parse_issues": self.parse_issues,
            "opaque_search_capability_present": self.opaque_search_capability_present,
            "firewall_status": self.firewall_status,
            "public_observation_hash": self.public_observation_hash,
        }


def _load_contract_set(contract_root: Path) -> CabtContractSet:
    """Compatibility wrapper around the single normative contract-set owner."""

    return load_contract_set(contract_root)


def _validate_json_tree(value: Any) -> None:
    active: set[int] = set()
    node_count = 0

    def walk(current: Any, depth: int) -> None:
        nonlocal node_count
        node_count += 1
        if node_count > MAX_JSON_NODES:
            raise _JsonTreeError("json_tree_too_large")
        if depth > MAX_JSON_DEPTH:
            raise _JsonTreeError("json_tree_too_deep")
        current_type = type(current)
        if current is None or current_type in (bool, str):
            if current_type is str:
                _validate_unicode_string(current)
            return
        if current_type is int:
            if current < SAFE_INTEGER_MIN or current > SAFE_INTEGER_MAX:
                raise _JsonTreeError("integer_out_of_range")
            return
        if current_type is float:
            if not math.isfinite(current):
                raise _JsonTreeError("invalid_json_tree")
            return
        if current_type not in (dict, list):
            raise _JsonTreeError("invalid_json_tree")
        identity = id(current)
        if identity in active:
            raise _JsonTreeError("cyclic_json_tree")
        active.add(identity)
        try:
            if current_type is dict:
                if any(type(key) is not str for key in current):
                    raise _JsonTreeError("invalid_json_tree")
                for key, child in current.items():
                    _validate_unicode_string(key)
                    walk(child, depth + 1)
            else:
                for child in current:
                    walk(child, depth + 1)
        finally:
            active.remove(identity)

    walk(value, 0)


def _escape_pointer_segment(segment: str) -> str:
    return segment.replace("~", "~0").replace("/", "~1")


def _join_pointer(parent: str, segment: str | int) -> str:
    return f"{parent}/{_escape_pointer_segment(str(segment))}"


def _json_type_name(value: Any) -> str:
    if value is None:
        return "null"
    value_type = type(value)
    if value_type is bool:
        return "boolean"
    if value_type is int:
        return "integer"
    if value_type is float:
        return "number"
    if value_type is str:
        return "string"
    if value_type is list:
        return "array"
    if value_type is dict:
        return "object"
    raise AssertionError("validated JSON tree has an unsupported value")


class _TypedProjector:
    def __init__(self, contracts: CabtContractSet) -> None:
        self.profile = contracts.typed_profile
        self.enum_snapshot = contracts.enum_snapshot
        self.presence: dict[str, str] = {}
        self.unknown: list[dict[str, str]] = []
        self.enums: list[dict[str, Any]] = []
        self.issues: list[CabtParseIssue] = []
        enum_map = self.enum_snapshot.get("enums", {})
        self._enum_names: dict[str, dict[int, str]] = {
            enum_name: {int(raw): name for name, raw in values.items()}
            for enum_name, values in enum_map.items()
            if isinstance(values, dict)
        }
        engine_only = self.enum_snapshot.get("locked_engine_only_observations", {})
        self._engine_only: dict[str, dict[int, str]] = {
            enum_name: {int(raw): str(name) for raw, name in values.items()}
            for enum_name, values in engine_only.items()
            if isinstance(values, dict)
        }

    def project_callback(self, raw: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
        callback = self.profile["callback_root"]
        callback_fields = callback["fields"]
        framework_fields = self.profile["framework_fields"]
        known_root_names = {field["name"] for field in callback_fields}
        known_root_names.update(field["name"] for field in framework_fields)
        for key, value in raw.items():
            if key not in known_root_names:
                self._record_unknown(_join_pointer("", key), value)

        known_view: dict[str, Any] = {}
        known_view_fields = set(callback["known_view_fields"])
        for descriptor in callback_fields:
            name = descriptor["name"]
            pointer = _join_pointer("", name)
            if name not in raw:
                self.presence[pointer] = "missing"
                if descriptor.get("required", False) or name in _REQUIRED_CALLBACK_FIELDS:
                    self.issues.append(CabtParseIssue("missing_required_field", pointer))
                continue
            value = raw[name]
            self.presence[pointer] = "null" if value is None else "value"
            if name not in known_view_fields:
                continue
            valid, projected = self._project_descriptor(value, descriptor, pointer)
            known_view[name] = projected

        framework: dict[str, Any] = {
            "step": None,
            "remaining_overage_time": None,
        }
        for descriptor in framework_fields:
            name = descriptor["name"]
            pointer = _join_pointer("", name)
            if name not in raw:
                self.presence[pointer] = "missing"
                continue
            value = raw[name]
            self.presence[pointer] = "null" if value is None else "value"
            valid, projected = self._project_descriptor(value, descriptor, pointer)
            if valid:
                output_name = "remaining_overage_time" if name == "remainingOverageTime" else name
                framework[output_name] = projected
        return known_view, framework

    def _project_shape(
        self, value: Any, shape_name: str, pointer: str
    ) -> tuple[bool, Any]:
        if type(value) is not dict:
            self.issues.append(CabtParseIssue("invalid_field_type", pointer))
            return False, None
        shape = self.profile["shapes"].get(shape_name)
        if not isinstance(shape, dict):
            self.issues.append(CabtParseIssue("unknown_shape", pointer))
            return False, None
        descriptors = shape["fields"]
        descriptor_by_name = {field["name"]: field for field in descriptors}
        allowed_names = set(descriptor_by_name)

        if shape_name in ("Option", "Log"):
            sparse_name = "option_shapes" if shape_name == "Option" else "log_shapes"
            raw_type = value.get("type")
            if type(raw_type) is int:
                sparse = self.profile[sparse_name].get(str(raw_type))
                allowed_names = set(sparse) if isinstance(sparse, list) else {"type"}
            else:
                allowed_names = {"type"}

        for descriptor in descriptors:
            field_name = descriptor["name"]
            field_pointer = _join_pointer(pointer, field_name)
            if field_name not in value:
                self.presence[field_pointer] = "missing"
            else:
                self.presence[field_pointer] = "null" if value[field_name] is None else "value"

        for key, child in value.items():
            if key not in allowed_names:
                self._record_unknown(_join_pointer(pointer, key), child)

        result: dict[str, Any] = {}
        all_valid = True
        for descriptor in descriptors:
            name = descriptor["name"]
            if name not in allowed_names:
                continue
            field_pointer = _join_pointer(pointer, name)
            if name not in value:
                if descriptor.get("required", False):
                    self.issues.append(CabtParseIssue("missing_required_field", field_pointer))
                    all_valid = False
                continue
            valid, projected = self._project_descriptor(value[name], descriptor, field_pointer)
            all_valid = all_valid and valid
            if valid:
                result[name] = projected
        return all_valid, result

    def _project_descriptor(
        self, value: Any, descriptor: Mapping[str, Any], pointer: str
    ) -> tuple[bool, Any]:
        if value is None:
            if descriptor.get("nullable", False):
                return True, None
            self.issues.append(CabtParseIssue("invalid_null", pointer))
            return False, None
        kind = descriptor.get("kind")
        if kind == "shape":
            return self._project_shape(value, str(descriptor["shape"]), pointer)
        if kind == "array":
            if type(value) is not list:
                self.issues.append(CabtParseIssue("invalid_field_type", pointer))
                return False, None
            projected_items: list[Any] = []
            all_valid = True
            items = descriptor.get("items")
            if not isinstance(items, dict):
                self.issues.append(CabtParseIssue("invalid_contract_descriptor", pointer))
                return False, None
            for index, child in enumerate(value):
                valid, projected = self._project_descriptor(
                    child, items, _join_pointer(pointer, index)
                )
                all_valid = all_valid and valid
                projected_items.append(projected if valid else None)
            return all_valid, projected_items
        expected = {
            "integer": lambda item: type(item) is int,
            "number": lambda item: type(item) in (int, float),
            "boolean": lambda item: type(item) is bool,
            "string": lambda item: type(item) is str,
        }.get(kind)
        if expected is None or not expected(value):
            code = "invalid_enum_type" if "enum" in descriptor else "invalid_field_type"
            self.issues.append(CabtParseIssue(code, pointer))
            return False, None
        enum_name = descriptor.get("enum")
        if isinstance(enum_name, str):
            self._record_enum(enum_name, value, pointer)
        return True, copy.deepcopy(value)

    def _record_enum(self, enum_name: str, raw_value: int, pointer: str) -> None:
        known_name = self._enum_names.get(enum_name, {}).get(raw_value)
        authority = "official_known"
        if known_name is None:
            known_name = self._engine_only.get(enum_name, {}).get(raw_value)
            authority = "locked_engine_only" if known_name is not None else "unknown_future"
        self.enums.append(
            {
                "pointer": pointer,
                "raw_int": raw_value,
                "known_name": known_name,
                "authority": authority,
            }
        )
        if authority == "unknown_future":
            self.issues.append(CabtParseIssue("unknown_enum_value", pointer))

    def _record_unknown(self, pointer: str, value: Any) -> None:
        self.unknown.append(
            {
                "pointer": pointer,
                "presence": "null" if value is None else "value",
                "json_type": _json_type_name(value),
            }
        )


def _structural_root_issues(raw: Any) -> list[CabtParseIssue]:
    if type(raw) is not dict:
        return [CabtParseIssue("callback_root_not_object", "")]
    issues: list[CabtParseIssue] = []
    for field_name in _REQUIRED_CALLBACK_FIELDS:
        if field_name not in raw:
            issues.append(CabtParseIssue("missing_required_field", f"/{field_name}"))
    if issues:
        return issues
    if raw["select"] is not None and type(raw["select"]) is not dict:
        issues.append(CabtParseIssue("invalid_field_type", "/select"))
    if type(raw["logs"]) is not list:
        issues.append(CabtParseIssue("invalid_field_type", "/logs"))
    if raw["current"] is not None and type(raw["current"]) is not dict:
        issues.append(CabtParseIssue("invalid_field_type", "/current"))
    if raw["search_begin_input"] is not None and type(raw["search_begin_input"]) is not str:
        issues.append(CabtParseIssue("invalid_field_type", "/search_begin_input"))
    return issues


def parse_raw_cabt_envelope(
    raw_payload: Any,
    *,
    contract_root: str | Path | None = None,
) -> EnvelopeParseResult:
    try:
        _validate_json_tree(raw_payload)
    except _JsonTreeError as exc:
        return EnvelopeParseResult(None, (CabtParseIssue(exc.code, ""),))
    except (RecursionError, RuntimeError, MemoryError):
        return EnvelopeParseResult(None, (CabtParseIssue("invalid_json_tree", ""),))

    structural_issues = _structural_root_issues(raw_payload)
    if structural_issues:
        return EnvelopeParseResult(None, tuple(structural_issues))

    root = (
        Path(contract_root)
        if contract_root is not None
        else Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
    )
    try:
        contracts = _load_contract_set(root)
        projector = _TypedProjector(contracts)
        known_view, framework = projector.project_callback(raw_payload)
        raw_hash = raw_private_hash(raw_payload)
        token_free_hash = token_free_callback_hash(raw_payload)
        raw_snapshot = copy.deepcopy(raw_payload)
    except (OSError, ValueError, TypeError, KeyError, CabtTreeHashError, RecursionError):
        return EnvelopeParseResult(None, (CabtParseIssue("contract_runtime_error", ""),))

    envelope = RawCabtEnvelope(
        raw_payload=raw_snapshot,
        known_view=known_view,
        field_presence=projector.presence,
        unknown_fields=projector.unknown,
        framework=framework,
        enum_values=projector.enums,
        parse_issues=projector.issues,
        source_lock_id=contracts.source_lock_id,
        source_contract_hash=contracts.source_contract_hash,
        raw_hash=raw_hash,
        token_free_hash=token_free_hash,
    )
    return EnvelopeParseResult(envelope, tuple(projector.issues))


def parse_raw_cabt_json_bytes(
    data: bytes,
    *,
    contract_root: str | Path | None = None,
    max_bytes: int = MAX_INPUT_BYTES,
) -> EnvelopeParseResult:
    if type(data) is not bytes:
        return EnvelopeParseResult(None, (CabtParseIssue("invalid_json_bytes", ""),))
    if type(max_bytes) is not int or max_bytes < 1 or max_bytes > MAX_INPUT_BYTES:
        return EnvelopeParseResult(None, (CabtParseIssue("invalid_size_limit", ""),))
    if len(data) > max_bytes:
        return EnvelopeParseResult(None, (CabtParseIssue("json_input_too_large", ""),))
    try:
        value = load_json_bytes_strict(data)
    except (UnicodeError, ValueError, TypeError, RecursionError):
        return EnvelopeParseResult(None, (CabtParseIssue("invalid_json_bytes", ""),))
    return parse_raw_cabt_envelope(value, contract_root=contract_root)
