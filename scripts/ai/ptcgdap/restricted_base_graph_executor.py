from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any, Final, Mapping

from .cabt_tree_hash import CabtTreeHashError, jcs_canonical_json_bytes
from .source_lock import canonical_json_v1_bytes, load_json_strict
from .strategic_context_v18 import StrategicContextV18
from .strategic_trace_v2 import RestrictedBaseGraphIR


PROFILE_ID: Final = "ptcgdap-restricted-base-graph-executor-p4-wp3-v1"
BUNDLE_ID: Final = "ptcgdap-restricted-base-graph-executor-p4-wp3-v1"
BUNDLE_CANONICAL_SHA256: Final = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
PARENT_BUNDLE_CANONICAL_SHA256: Final = "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
EXECUTION_PREFIX: Final = b"PTCGDAP\0RESTRICTED_BASE_GRAPH_EXECUTION_V1\0"
MAX_SAFE_INTEGER: Final = 9_007_199_254_740_991
EXPECTED_ARTIFACTS: Final = {
    "restricted_base_graph_executor.schema.json": "1B51354DBCEE1EE4C91A27BBF1FB2E3DC6847959D3B305B92E854EF1028A511E",
    "restricted_base_graph_executor_profile.json": "FCE7CD9F86F9AFC92152B0DD9342F3F7172F61EB26469397D70B85CEA95E185B",
    "restricted_base_graph_executor_conformance_vectors.json": "FBFD16F39742D7DB9DF531A4F7ADB130882EFD86477A074A1855B0F214725326",
}
ADAPTER_REASONS: Final = MappingProxyType(
    {
        "goal_proposal": "public_goal_proposal",
        "macro_proposal": "public_macro_proposal",
        "tiebreak_score": "public_tiebreak_proposal",
    }
)
_INPUT_KEYS: Final = frozenset(
    {
        "execution_id",
        "mandatory_indexes",
        "terminal_indexes",
        "base_hard_tiers",
        "base_vetoed_indexes",
        "adapter_proposals",
    }
)
_RESULT_TOKEN = object()


class RestrictedBaseGraphExecutionError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if type(value) is list:
        return tuple(_freeze(child) for child in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(child) for key, child in value.items()}
    if type(value) is tuple:
        return [_thaw(child) for child in value]
    return copy.deepcopy(value)


def _exact_safe_int(value: Any) -> bool:
    return type(value) is int and -MAX_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER


def _identifier(value: Any) -> bool:
    return (
        type(value) is str
        and 1 <= len(value) <= 128
        and value[0] in "abcdefghijklmnopqrstuvwxyz0123456789"
        and all(character in "abcdefghijklmnopqrstuvwxyz0123456789._-" for character in value)
        and "PRIVATE" not in value.upper()
    )


def _domain_hash(payload: dict[str, Any]) -> str:
    return _sha(EXECUTION_PREFIX + jcs_canonical_json_bytes(payload))


@dataclass(frozen=True, slots=True)
class _Contracts:
    profile: Mapping[str, Any]


def _contract_root(contract_root: Path | None) -> Path:
    if contract_root is None:
        return Path(__file__).resolve().parents[3] / "contracts/ptcgdap"
    return Path(contract_root).resolve()


def _load_contracts(contract_root: Path | None = None) -> _Contracts:
    root = _contract_root(contract_root)
    try:
        bundle_path = root / "restricted_base_graph_executor_bundle.json"
        bundle = load_json_strict(bundle_path)
        if _sha(canonical_json_v1_bytes(bundle)) != BUNDLE_CANONICAL_SHA256:
            raise RestrictedBaseGraphExecutionError("contract_error")
        if (
            type(bundle) is not dict
            or bundle.get("bundle_id") != BUNDLE_ID
            or bundle.get("parent_bundle_canonical_sha256") != PARENT_BUNDLE_CANONICAL_SHA256
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != len(EXPECTED_ARTIFACTS)
        ):
            raise RestrictedBaseGraphExecutionError("contract_error")
        loaded: dict[str, Any] = {}
        seen: set[str] = set()
        for entry in bundle["artifacts"]:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise RestrictedBaseGraphExecutionError("contract_error")
            path = entry["path"]
            if type(path) is not str or not path.startswith("contracts/ptcgdap/"):
                raise RestrictedBaseGraphExecutionError("contract_error")
            name = Path(path).name
            if name not in EXPECTED_ARTIFACTS or name in seen or entry["canonical_sha256"] != EXPECTED_ARTIFACTS[name]:
                raise RestrictedBaseGraphExecutionError("contract_error")
            value = load_json_strict(root / name)
            if _sha(canonical_json_v1_bytes(value)) != EXPECTED_ARTIFACTS[name]:
                raise RestrictedBaseGraphExecutionError("contract_error")
            loaded[name] = value
            seen.add(name)
        if seen != set(EXPECTED_ARTIFACTS):
            raise RestrictedBaseGraphExecutionError("contract_error")
        profile = loaded["restricted_base_graph_executor_profile.json"]
        if (
            type(profile) is not dict
            or profile.get("profile_id") != PROFILE_ID
            or profile.get("parent_bundle_canonical_sha256") != PARENT_BUNDLE_CANONICAL_SHA256
            or profile.get("source_authority") != "exact_current_p4_wp1_context_and_p4_wp2_ir_owner"
            or profile.get("execution_contract", {}).get("adapter_authority") != "same_tier_ordering_hint_only"
            or profile.get("result_contract", {}).get("serialized_result_is_execution_authority") is not False
        ):
            raise RestrictedBaseGraphExecutionError("contract_error")
        return _Contracts(_freeze(profile))
    except RestrictedBaseGraphExecutionError:
        raise
    except (CabtTreeHashError, KeyError, OSError, TypeError, ValueError, RecursionError) as exc:
        raise RestrictedBaseGraphExecutionError("contract_error") from exc


def _index_list(value: Any, option_count: int) -> bool:
    return (
        type(value) is list
        and len(value) <= 1024
        and all(type(index) is int and 0 <= index < option_count for index in value)
        and len(value) == len(set(value))
    )


def _input_error(value: Any, option_count: int, ir_document: dict[str, Any]) -> str | None:
    if type(value) is not dict or set(value) != _INPUT_KEYS or not _identifier(value.get("execution_id")):
        return "invalid_execution_input"
    for key in ("mandatory_indexes", "terminal_indexes", "base_vetoed_indexes"):
        if not _index_list(value[key], option_count):
            return "invalid_execution_input"
    if set(value["mandatory_indexes"]) & set(value["base_vetoed_indexes"]) or set(value["terminal_indexes"]) & set(value["base_vetoed_indexes"]):
        return "forced_index_vetoed"
    tiers = value["base_hard_tiers"]
    if type(tiers) is not list or len(tiers) != option_count:
        return "invalid_execution_input"
    tier_indexes: list[int] = []
    for entry in tiers:
        if type(entry) is not dict or set(entry) != {"index", "tier"}:
            return "invalid_execution_input"
        index, tier = entry["index"], entry["tier"]
        if type(index) is not int or not 0 <= index < option_count or type(tier) is not list or not 1 <= len(tier) <= 8 or not all(_exact_safe_int(part) for part in tier):
            return "invalid_execution_input"
        tier_indexes.append(index)
    if sorted(tier_indexes) != list(range(option_count)):
        return "invalid_execution_input"
    proposals = value["adapter_proposals"]
    ir_operators = {node["operator"] for node in ir_document["nodes"]}
    if type(proposals) is not list or len(proposals) > 64:
        return "invalid_execution_input"
    for proposal in proposals:
        if type(proposal) is not dict or set(proposal) != {"operator", "indexes", "reason_code"}:
            return "invalid_execution_input"
        operator = proposal["operator"]
        if type(operator) is not str or operator not in ADAPTER_REASONS or operator not in ir_operators or proposal["reason_code"] != ADAPTER_REASONS[operator] or not _index_list(proposal["indexes"], option_count):
            return "invalid_execution_input"
        if any(type(child) is str and "PRIVATE" in child.upper() for child in proposal.values()):
            return "invalid_execution_input"
    return None


def _ordered_hint(current: list[int], proposals: list[dict[str, Any]], operator: str) -> list[int]:
    preferred: list[int] = []
    for proposal in proposals:
        if proposal["operator"] == operator:
            for index in proposal["indexes"]:
                if index in current and index not in preferred:
                    preferred.append(index)
    return preferred + [index for index in current if index not in preferred]


def _compute(context_payload: dict[str, Any], ir_document: dict[str, Any], execution_input: dict[str, Any]) -> tuple[str | None, dict[str, Any] | None]:
    source = context_payload["source"]
    semantics = context_payload["select_semantics"]
    option_count = source["option_count"]
    min_count = semantics["min_count"]
    max_count = semantics["max_count"]
    if not all(type(value) is int and 0 <= value <= option_count for value in (min_count, max_count)) or min_count > max_count:
        return "invalid_context", None
    error = _input_error(execution_input, option_count, ir_document)
    if error is not None:
        return error, None
    mandatory = execution_input["mandatory_indexes"]
    terminal = execution_input["terminal_indexes"]
    forced = terminal or mandatory
    if forced and not min_count <= len(forced) <= max_count:
        return "invalid_execution_input", None
    current = list(range(option_count))
    tiers = {entry["index"]: tuple(entry["tier"]) for entry in execution_input["base_hard_tiers"]}
    audit: list[dict[str, Any]] = []
    for node in ir_document["nodes"]:
        before = list(current)
        operator = node["operator"]
        if operator == "legality_guard":
            current = list(range(option_count))
        elif operator == "mandatory_terminal_guard" and forced:
            current = list(forced)
        elif operator in ADAPTER_REASONS and not forced:
            current = _ordered_hint(current, execution_input["adapter_proposals"], operator)
        elif operator == "hard_tier_filter" and not forced and current:
            best = min(tiers[index] for index in current)
            current = [index for index in current if tiers[index] == best]
        elif operator == "base_veto" and not forced:
            current = [index for index in current if index not in execution_input["base_vetoed_indexes"]]
        elif operator == "deterministic_fallback":
            if len(current) < min_count:
                return "insufficient_candidates", None
            current = current[:min_count]
        audit.append({"node_id": node["node_id"], "operator": operator, "owner": node["owner"], "input_indexes": before, "output_indexes": list(current)})
    if min_count == 0:
        reason, branch = "empty_selection", "optional_zero"
    elif terminal:
        reason, branch = "terminal_selection", "terminal"
    elif mandatory:
        reason, branch = "mandatory_selection", "mandatory"
    else:
        reason, branch = "deterministic_fallback", "same_window_first_min"
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "execution_id": execution_input["execution_id"],
        "source": {"context_hash": context_payload["context_hash"], "window_id": source["window_id"], "ir_hash": ir_document["ir_hash"]},
        "selected_indexes": list(current),
        "reason_code": reason,
        "fallback_branch": branch,
        "node_audit": audit,
        "adapter_audit": copy.deepcopy(execution_input["adapter_proposals"]),
        "authoritative": False,
    }
    return None, {**payload, "execution_hash": _domain_hash(payload)}


@dataclass(frozen=True, slots=True, init=False)
class RestrictedBaseGraphExecutionResult:
    _snapshot: Mapping[str, Any]
    _construction_seal: object
    _context_binding: StrategicContextV18
    _ir_binding: RestrictedBaseGraphIR
    _input_snapshot: Mapping[str, Any]

    def __new__(cls) -> RestrictedBaseGraphExecutionResult:
        raise TypeError("RestrictedBaseGraphExecutionResult is executor-owned")

    @classmethod
    def _from_owner(cls, payload: dict[str, Any], context: StrategicContextV18, ir: RestrictedBaseGraphIR, execution_input: dict[str, Any], token: object) -> RestrictedBaseGraphExecutionResult:
        if token is not _RESULT_TOKEN:
            raise RestrictedBaseGraphExecutionError("execution_integrity_invalid")
        value = object.__new__(cls)
        object.__setattr__(value, "_snapshot", _freeze(copy.deepcopy(payload)))
        object.__setattr__(value, "_construction_seal", token)
        object.__setattr__(value, "_context_binding", context)
        object.__setattr__(value, "_ir_binding", ir)
        object.__setattr__(value, "_input_snapshot", _freeze(copy.deepcopy(execution_input)))
        if not value.validate_integrity(context, ir):
            raise RestrictedBaseGraphExecutionError("execution_integrity_invalid")
        return value

    @property
    def selected_indexes(self) -> list[int]:
        return (
            list(self._snapshot.get("selected_indexes", ()))
            if isinstance(self._snapshot, Mapping) and self.validate_integrity(self._context_binding, self._ir_binding)
            else []
        )

    @property
    def execution_hash(self) -> str:
        return (
            str(self._snapshot.get("execution_hash", ""))
            if isinstance(self._snapshot, Mapping) and self.validate_integrity(self._context_binding, self._ir_binding)
            else ""
        )

    def validate_integrity(self, context: StrategicContextV18, ir: RestrictedBaseGraphIR) -> bool:
        try:
            if type(self) is not RestrictedBaseGraphExecutionResult or self._construction_seal is not _RESULT_TOKEN or context is not self._context_binding or ir is not self._ir_binding or not isinstance(self._snapshot, Mapping) or not isinstance(self._input_snapshot, Mapping):
                return False
            if not context.validate_integrity() or not ir.validate_integrity():
                return False
            error, expected = _compute(context.to_public_dict(), ir.to_public_dict(), _thaw(self._input_snapshot))
            return error is None and expected is not None and _thaw(self._snapshot) == expected
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._context_binding, self._ir_binding):
            raise RestrictedBaseGraphExecutionError("execution_integrity_invalid")
        return _thaw(self._snapshot)


@dataclass(frozen=True, slots=True)
class RestrictedBaseGraphExecutionOutcome:
    accepted: bool
    error_code: str
    result: RestrictedBaseGraphExecutionResult | None


class RestrictedBaseGraphExecutor:
    __slots__ = ()

    @staticmethod
    def execute(context: Any, ir: Any, execution_input: Any, *, contract_root: Path | None = None) -> RestrictedBaseGraphExecutionOutcome:
        try:
            _load_contracts(contract_root)
        except RestrictedBaseGraphExecutionError:
            return RestrictedBaseGraphExecutionOutcome(False, "contract_error", None)
        if type(context) is not StrategicContextV18:
            return RestrictedBaseGraphExecutionOutcome(False, "invalid_context", None)
        if type(ir) is not RestrictedBaseGraphIR:
            return RestrictedBaseGraphExecutionOutcome(False, "invalid_ir", None)
        try:
            if not context.validate_integrity():
                return RestrictedBaseGraphExecutionOutcome(False, "invalid_context", None)
            if not ir.validate_integrity():
                return RestrictedBaseGraphExecutionOutcome(False, "invalid_ir", None)
            error, payload = _compute(context.to_public_dict(), ir.to_public_dict(), execution_input)
            if error is not None or payload is None:
                return RestrictedBaseGraphExecutionOutcome(False, error or "invalid_execution_input", None)
            result = RestrictedBaseGraphExecutionResult._from_owner(payload, context, ir, execution_input, _RESULT_TOKEN)
            return RestrictedBaseGraphExecutionOutcome(True, "", result)
        except RestrictedBaseGraphExecutionError as exc:
            return RestrictedBaseGraphExecutionOutcome(False, exc.code, None)
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return RestrictedBaseGraphExecutionOutcome(False, "invalid_execution_input", None)
