from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Final, Mapping

from .cabt_tree_hash import CabtTreeHashError, jcs_canonical_json_bytes
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict
from .strategic_context_v18 import PolicyDecision, StrategicContextV18


PROFILE_ID: Final = "ptcgdap-strategic-trace-v2-p4-wp2-v1"
IR_PROFILE_ID: Final = "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"
EXPECTED_BUNDLE_SHA256: Final = "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
EXPECTED_ARTIFACTS: Final = MappingProxyType(
    {
        "schema": ("strategic_trace_v2.schema.json", "9E455A3D90121265046BE7A48DD182E15B197D0D0930AE7FC1254D98637870F5"),
        "profile": ("strategic_trace_v2_profile.json", "5F98592945C60DE94896960C240F5D19002154F2FBEC6A82F553D4ED9EF1A00E"),
        "vectors": ("strategic_trace_v2_conformance_vectors.json", "5270260C817BE20A749A0404A2413CDB90F5C7AF871BD1DFCC64ECF85DA4E7B1"),
    }
)
IR_PREFIX: Final = b"PTCGDAP\0RESTRICTED_BASE_GRAPH_IR_V1\0"
TRACE_PREFIX: Final = b"PTCGDAP\0STRATEGIC_TRACE_V2\0"
MAX_CONTRACT_BYTES: Final = 2 * 1024 * 1024
MAX_VALUE_BYTES: Final = 1024 * 1024
SAFE_MAX: Final = 2**53 - 1
BASE_OPERATORS: Final = (
    "legality_guard",
    "mandatory_terminal_guard",
    "hard_tier_filter",
    "base_veto",
    "deterministic_fallback",
    "emit_decision",
)
ADAPTER_OPERATORS: Final = ("goal_proposal", "macro_proposal", "tiebreak_score")
CAPABILITIES: Final = ("public_context", "current_window", "deterministic_fallback", "strategic_trace_v2")
ADAPTER_REASONS: Final = MappingProxyType(
    {
        "goal_proposal": "public_goal_proposal",
        "macro_proposal": "public_macro_proposal",
        "tiebreak_score": "public_tiebreak_proposal",
    }
)
_IR_TOKEN: Final = object()
_TRACE_TOKEN: Final = object()
_IDENTIFIER = re.compile(r"^[A-Za-z0-9._:-]+$")
_DOCUMENT_KEYS: Final = frozenset(
    {"schema_version", "profile_id", "graph_id", "entry_node_id", "required_capabilities", "nodes"}
)
_NODE_KEYS: Final = frozenset({"node_id", "operator", "owner", "config", "next_node_ids"})
_AUDIT_KEYS: Final = frozenset(
    {
        "legal_indexes",
        "strategic_indexes",
        "mandatory_indexes",
        "terminal_indexes",
        "base_hard_tiers",
        "base_vetoed_indexes",
        "adapter_proposals",
        "fallback_reason",
    }
)


class StrategicTraceContractError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _domain_hash(prefix: bytes, payload: dict[str, Any]) -> str:
    return _sha(prefix + jcs_canonical_json_bytes(payload))


def _identifier(value: Any) -> bool:
    return type(value) is str and 0 < len(value) <= 128 and "PRIVATE" not in value and _IDENTIFIER.fullmatch(value) is not None


def _exact_safe_int(value: Any) -> bool:
    return type(value) is int and -SAFE_MAX <= value <= SAFE_MAX


def _index(value: Any) -> bool:
    return _exact_safe_int(value) and value >= 0


def _upper_sha(value: Any) -> bool:
    return (
        type(value) is str
        and len(value) == 64
        and value == value.upper()
        and all(character in "0123456789ABCDEF" for character in value)
    )


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
    return value


@dataclass(frozen=True, slots=True)
class _Contracts:
    root: Path
    profile: Mapping[str, Any]


def _load_contracts(contract_root: Path | None = None) -> _Contracts:
    root = contract_root or Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
    try:
        raw = (root / "strategic_trace_v2_bundle.json").read_bytes()
        if len(raw) > MAX_CONTRACT_BYTES:
            raise StrategicTraceContractError("contract_error")
        bundle = load_json_bytes_strict(raw)
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_SHA256:
            raise StrategicTraceContractError("contract_error")
        if type(bundle) is not dict or set(bundle) != {
            "schema_version",
            "bundle_id",
            "profile_id",
            "ir_profile_id",
            "parent_strategic_context_bundle_canonical_sha256",
            "source_lock_canonical_sha256",
            "base_graph_v1_8_source_raw_sha256",
            "base_graph_v1_8_contract_raw_sha256",
            "artifacts",
        }:
            raise StrategicTraceContractError("contract_error")
        if (
            bundle["schema_version"] != 1
            or bundle["bundle_id"] != PROFILE_ID
            or bundle["profile_id"] != PROFILE_ID
            or bundle["ir_profile_id"] != IR_PROFILE_ID
        ):
            raise StrategicTraceContractError("contract_error")
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != 3:
            raise StrategicTraceContractError("contract_error")
        documents: dict[str, Any] = {}
        seen: set[str] = set()
        for entry in entries:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise StrategicTraceContractError("contract_error")
            artifact_id = entry["id"]
            if type(artifact_id) is not str or artifact_id in seen or artifact_id not in EXPECTED_ARTIFACTS:
                raise StrategicTraceContractError("contract_error")
            name, expected_hash = EXPECTED_ARTIFACTS[artifact_id]
            if entry["path"] != f"contracts/ptcgdap/{name}" or entry["canonical_sha256"] != expected_hash:
                raise StrategicTraceContractError("contract_error")
            artifact_raw = (root / name).read_bytes()
            if len(artifact_raw) > MAX_CONTRACT_BYTES:
                raise StrategicTraceContractError("contract_error")
            document = load_json_bytes_strict(artifact_raw)
            if _sha(canonical_json_v1_bytes(document)) != expected_hash:
                raise StrategicTraceContractError("contract_error")
            documents[artifact_id] = document
            seen.add(artifact_id)
        if seen != set(EXPECTED_ARTIFACTS):
            raise StrategicTraceContractError("contract_error")
        profile = documents["profile"]
        if (
            type(profile) is not dict
            or profile.get("profile_id") != PROFILE_ID
            or profile.get("ir_profile_id") != IR_PROFILE_ID
            or profile.get("ir_contract", {}).get("base_operators_in_required_order") != list(BASE_OPERATORS)
            or profile.get("ir_contract", {}).get("adapter_operators") != list(ADAPTER_OPERATORS)
            or profile.get("ir_contract", {}).get("required_capabilities") != list(CAPABILITIES)
            or profile.get("ir_contract", {}).get("adapter_reason_codes") != list(ADAPTER_REASONS.values())
            or profile.get("ir_contract", {}).get("private_identifier_tokens_denied") != ["PRIVATE"]
            or profile.get("scope", {}).get("ir_executor") is not False
            or profile.get("scope", {}).get("live_owner") is not False
        ):
            raise StrategicTraceContractError("contract_error")
        hashes = profile.get("hash_contract")
        if (
            type(hashes) is not dict
            or bytes.fromhex(hashes["ir_prefix_utf8_hex"]) != IR_PREFIX
            or bytes.fromhex(hashes["trace_prefix_utf8_hex"]) != TRACE_PREFIX
        ):
            raise StrategicTraceContractError("contract_error")
        return _Contracts(root, _freeze(copy.deepcopy(profile)))
    except StrategicTraceContractError:
        raise
    except (AttributeError, OSError, ValueError, TypeError, KeyError, RecursionError) as exc:
        raise StrategicTraceContractError("contract_error") from exc


def _identifier_list(value: Any) -> bool:
    return (
        type(value) is list
        and 1 <= len(value) <= 64
        and all(_identifier(child) for child in value)
        and len(value) == len(set(value))
    )


def _config_valid(operator: str, config: Any) -> bool:
    if type(config) is not dict:
        return False
    if operator == "legality_guard":
        return set(config) == {"frontier"} and type(config["frontier"]) is str and config["frontier"] == "current_window"
    if operator == "mandatory_terminal_guard":
        return (
            set(config) == {"mandatory_precedence", "terminal_precedence"}
            and type(config["mandatory_precedence"]) is bool
            and config["mandatory_precedence"] is True
            and type(config["terminal_precedence"]) is bool
            and config["terminal_precedence"] is True
        )
    if operator == "hard_tier_filter":
        return set(config) == {"same_tier_only"} and type(config["same_tier_only"]) is bool and config["same_tier_only"] is True
    if operator == "base_veto":
        return set(config) == {"enabled"} and type(config["enabled"]) is bool and config["enabled"] is True
    if operator == "deterministic_fallback":
        return set(config) == {"strategy"} and type(config["strategy"]) is str and config["strategy"] == "same_window_first_min"
    if operator == "emit_decision":
        return config == {}
    if operator == "goal_proposal":
        return set(config) == {"goal_ids"} and _identifier_list(config["goal_ids"])
    if operator == "macro_proposal":
        return set(config) == {"macro_ids"} and _identifier_list(config["macro_ids"])
    if operator == "tiebreak_score":
        return (
            set(config) == {"feature_ids", "weight_scale"}
            and _identifier_list(config["feature_ids"])
            and type(config["weight_scale"]) is int
            and config["weight_scale"] == 1_000_000
        )
    return False


def _document_error(document: Any) -> str | None:
    if type(document) is not dict or set(document) != _DOCUMENT_KEYS:
        return "invalid_ir_document"
    if (
        type(document["schema_version"]) is not int
        or document["schema_version"] != 1
        or document["profile_id"] != IR_PROFILE_ID
        or not _identifier(document["graph_id"])
        or not _identifier(document["entry_node_id"])
    ):
        return "invalid_ir_document"
    capabilities = document["required_capabilities"]
    if type(capabilities) is not list or not all(type(value) is str for value in capabilities):
        return "invalid_ir_document"
    if capabilities != list(CAPABILITIES):
        return "unsupported_capability"
    nodes = document["nodes"]
    if type(nodes) is not list or len(nodes) > 64:
        return "invalid_ir_document"
    recognized = set(BASE_OPERATORS + ADAPTER_OPERATORS)
    for value in nodes:
        if type(value) is not dict or set(value) != _NODE_KEYS:
            return "invalid_ir_document"
        if not _identifier(value["node_id"]):
            return "invalid_ir_document"
        next_ids = value["next_node_ids"]
        if type(next_ids) is not list or len(next_ids) > 1 or not all(_identifier(child) for child in next_ids):
            return "invalid_ir_document"
        operator = value["operator"]
        if type(operator) is not str:
            return "invalid_ir_document"
        if operator not in recognized:
            return "unsupported_ir_operator"
        expected_owner = "base" if operator in BASE_OPERATORS else "adapter"
        if type(value["owner"]) is not str or value["owner"] != expected_owner:
            return "invalid_ir_owner"
        if not _config_valid(operator, value["config"]):
            return "invalid_ir_config"
    base_sequence = [value["operator"] for value in nodes if value["operator"] in BASE_OPERATORS]
    if base_sequence != list(BASE_OPERATORS):
        return "missing_base_authority"
    identifiers = [value["node_id"] for value in nodes]
    if len(identifiers) != len(set(identifiers)) or document["entry_node_id"] != identifiers[0]:
        return "invalid_ir_topology"
    for index, value in enumerate(nodes):
        expected_next = [] if index + 1 == len(nodes) else [identifiers[index + 1]]
        if value["next_node_ids"] != expected_next:
            return "invalid_ir_topology"
    mandatory_index = next(index for index, value in enumerate(nodes) if value["operator"] == "mandatory_terminal_guard")
    tier_index = next(index for index, value in enumerate(nodes) if value["operator"] == "hard_tier_filter")
    veto_index = next(index for index, value in enumerate(nodes) if value["operator"] == "base_veto")
    for index, value in enumerate(nodes):
        if value["operator"] in ("goal_proposal", "macro_proposal") and not mandatory_index < index < tier_index:
            return "invalid_ir_topology"
        if value["operator"] == "tiebreak_score" and not tier_index < index < veto_index:
            return "invalid_ir_topology"
    try:
        if len(jcs_canonical_json_bytes(document)) > MAX_VALUE_BYTES:
            return "invalid_ir_document"
    except (CabtTreeHashError, TypeError, ValueError, RecursionError):
        return "invalid_ir_document"
    return None


def _compiled_payload(document: dict[str, Any]) -> dict[str, Any]:
    payload = copy.deepcopy(document)
    payload.update({"authority": "restricted_base_graph_ir_audit", "authoritative": False})
    payload["ir_hash"] = _domain_hash(IR_PREFIX, payload)
    return payload


@dataclass(frozen=True, slots=True, init=False)
class RestrictedBaseGraphIR:
    _document: Mapping[str, Any]
    _snapshot: Mapping[str, Any]
    _construction_seal: object

    def __new__(cls) -> RestrictedBaseGraphIR:
        raise TypeError("RestrictedBaseGraphIR is compiler-owned")

    @classmethod
    def _from_owner(cls, document: dict[str, Any], token: object) -> RestrictedBaseGraphIR:
        if token is not _IR_TOKEN or _document_error(document) is not None:
            raise StrategicTraceContractError("ir_integrity_invalid")
        value = object.__new__(cls)
        object.__setattr__(value, "_document", _freeze(copy.deepcopy(document)))
        object.__setattr__(value, "_snapshot", _freeze(_compiled_payload(document)))
        object.__setattr__(value, "_construction_seal", token)
        if not value.validate_integrity():
            raise StrategicTraceContractError("ir_integrity_invalid")
        return value

    @property
    def ir_hash(self) -> str:
        return str(self._snapshot.get("ir_hash", "")) if isinstance(self._snapshot, Mapping) else ""

    @property
    def graph_id(self) -> str:
        return str(self._snapshot.get("graph_id", "")) if isinstance(self._snapshot, Mapping) else ""

    def validate_integrity(self) -> bool:
        try:
            document = _thaw(self._document)
            return (
                type(self) is RestrictedBaseGraphIR
                and self._construction_seal is _IR_TOKEN
                and type(document) is dict
                and _document_error(document) is None
                and isinstance(self._snapshot, Mapping)
                and _thaw(self._snapshot) == _compiled_payload(document)
            )
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise StrategicTraceContractError("ir_integrity_invalid")
        return _thaw(self._snapshot)


@dataclass(frozen=True, slots=True)
class RestrictedIrBuildResult:
    accepted: bool
    error_code: str
    ir: RestrictedBaseGraphIR | None


class RestrictedBaseGraphIRCompiler:
    __slots__ = ()

    @staticmethod
    def compile(document: Any, *, contract_root: Path | None = None) -> RestrictedIrBuildResult:
        try:
            _load_contracts(contract_root)
        except StrategicTraceContractError:
            return RestrictedIrBuildResult(False, "contract_error", None)
        error = _document_error(document)
        if error is not None:
            return RestrictedIrBuildResult(False, error, None)
        try:
            return RestrictedIrBuildResult(True, "", RestrictedBaseGraphIR._from_owner(copy.deepcopy(document), _IR_TOKEN))
        except (StrategicTraceContractError, CabtTreeHashError, TypeError, ValueError, RecursionError):
            return RestrictedIrBuildResult(False, "ir_integrity_invalid", None)


def _index_list(value: Any, *, max_items: int = 1024) -> bool:
    return (
        type(value) is list
        and len(value) <= max_items
        and all(_index(child) for child in value)
        and len(value) == len(set(value))
    )


def _trace_payload(
    context: StrategicContextV18,
    decision: PolicyDecision,
    ir: RestrictedBaseGraphIR,
    trace_id: str,
    audit: dict[str, Any],
) -> dict[str, Any]:
    context_value = context.to_public_dict()
    decision_value = decision.to_public_dict()
    ir_value = ir.to_public_dict()
    payload = {
        "schema_version": 2,
        "profile_id": PROFILE_ID,
        "trace_id": trace_id,
        "identities": {
            "scene_id": decision_value["scene_id"],
            "decision_id": decision_value["decision_id"],
            "determinism_key": decision_value["determinism_key"],
        },
        "source": {
            "context_hash": context_value["context_hash"],
            "decision_audit_id": decision_value["audit_id"],
            "policy_hash": decision_value["policy_hash"],
            "window_id": decision_value["window_id"],
            "public_observation_hash": decision_value["public_observation_hash"],
        },
        "ir": {
            "graph_id": ir_value["graph_id"],
            "ir_hash": ir_value["ir_hash"],
            "required_capabilities": copy.deepcopy(ir_value["required_capabilities"]),
        },
        "frontier": {
            "option_fingerprints": [value["fingerprint"] for value in context_value["select_semantics"]["options"]],
            "legal_indexes": copy.deepcopy(audit["legal_indexes"]),
            "strategic_indexes": copy.deepcopy(audit["strategic_indexes"]),
            "mandatory_indexes": copy.deepcopy(audit["mandatory_indexes"]),
            "terminal_indexes": copy.deepcopy(audit["terminal_indexes"]),
            "base_hard_tiers": copy.deepcopy(audit["base_hard_tiers"]),
            "base_vetoed_indexes": copy.deepcopy(audit["base_vetoed_indexes"]),
        },
        "adapter_proposals": copy.deepcopy(audit["adapter_proposals"]),
        "owner_audit": [
            {"node_id": value["node_id"], "operator": value["operator"], "owner": value["owner"]}
            for value in ir_value["nodes"]
        ],
        "decision": {
            "selected_indexes": copy.deepcopy(decision_value["selected_indexes"]),
            "owner_layer": decision_value["owner_layer"],
            "reason_code": decision_value["reason_code"],
            "fallback_tier": decision_value["fallback_tier"],
        },
        "fallback_reason": audit["fallback_reason"],
        "public_only": True,
        "authority": "strategic_trace_v2_public_audit",
        "authoritative": False,
    }
    payload["trace_hash"] = _domain_hash(TRACE_PREFIX, payload)
    return payload


def _trace_audit_valid(context: StrategicContextV18, decision: PolicyDecision, ir: RestrictedBaseGraphIR, audit: Any) -> bool:
    try:
        if type(audit) is not dict or set(audit) != _AUDIT_KEYS:
            return False
        context_value = context.to_public_dict()
        decision_value = decision.to_public_dict()
        ir_value = ir.to_public_dict()
        option_count = len(context_value["select_semantics"]["options"])
        for key in ("legal_indexes", "strategic_indexes", "mandatory_indexes", "terminal_indexes", "base_vetoed_indexes"):
            if not _index_list(audit[key]):
                return False
        legal = audit["legal_indexes"]
        strategic = audit["strategic_indexes"]
        mandatory = audit["mandatory_indexes"]
        terminal = audit["terminal_indexes"]
        vetoed = audit["base_vetoed_indexes"]
        selected = decision_value["selected_indexes"]
        if legal != list(range(option_count)):
            return False
        legal_set = set(legal)
        strategic_set = set(strategic)
        selected_set = set(selected)
        if not strategic_set <= legal_set or not selected_set <= strategic_set:
            return False
        forced = terminal if terminal else mandatory
        if not set(forced) <= selected_set:
            return False
        if not set(vetoed) <= strategic_set or selected_set & set(vetoed):
            return False
        tiers = audit["base_hard_tiers"]
        if type(tiers) is not list or len(tiers) != len(strategic):
            return False
        tier_by_index: dict[int, tuple[int, ...]] = {}
        for position, entry in enumerate(tiers):
            if type(entry) is not dict or set(entry) != {"index", "tier"} or entry["index"] != strategic[position]:
                return False
            tier = entry["tier"]
            if type(tier) is not list or not 1 <= len(tier) <= 8 or not all(_exact_safe_int(value) for value in tier):
                return False
            tier_by_index[entry["index"]] = tuple(tier)
        if selected and not forced:
            best = min(tier_by_index.values()) if tier_by_index else None
            if best is None or any(tier_by_index.get(value) != best for value in selected):
                return False
        proposals = audit["adapter_proposals"]
        if type(proposals) is not list or len(proposals) > 64:
            return False
        for proposal in proposals:
            if type(proposal) is not dict or set(proposal) != {"operator", "indexes", "reason_code"}:
                return False
            operator = proposal["operator"]
            if operator not in ADAPTER_OPERATORS or proposal["reason_code"] != ADAPTER_REASONS[operator]:
                return False
            if not _index_list(proposal["indexes"]) or not set(proposal["indexes"]) <= strategic_set:
                return False
        fallback_reason = audit["fallback_reason"]
        if type(fallback_reason) is not str or len(fallback_reason) > 128:
            return False
        expected_fallback = "" if decision_value["fallback_tier"] == "none" else decision_value["reason_code"]
        if fallback_reason != expected_fallback:
            return False
        if ir_value["required_capabilities"] != list(CAPABILITIES):
            return False
        return len(jcs_canonical_json_bytes(audit)) <= MAX_VALUE_BYTES
    except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
        return False


def _decision_bound_to_context(context: StrategicContextV18, decision: PolicyDecision) -> bool:
    try:
        return (
            type(context) is StrategicContextV18
            and type(decision) is PolicyDecision
            and decision._context_binding is context
            and decision.validate_integrity(context, decision._window_binding, decision._resolution_binding)
        )
    except (AttributeError, TypeError, ValueError, RecursionError):
        return False


@dataclass(frozen=True, slots=True, init=False)
class StrategicTraceV2:
    _snapshot: Mapping[str, Any]
    _audit: Mapping[str, Any]
    _construction_seal: object
    _context_binding: StrategicContextV18
    _decision_binding: PolicyDecision
    _ir_binding: RestrictedBaseGraphIR

    def __new__(cls) -> StrategicTraceV2:
        raise TypeError("StrategicTraceV2 is builder-owned")

    @classmethod
    def _from_owner(
        cls,
        payload: dict[str, Any],
        audit: dict[str, Any],
        context: StrategicContextV18,
        decision: PolicyDecision,
        ir: RestrictedBaseGraphIR,
        token: object,
    ) -> StrategicTraceV2:
        if token is not _TRACE_TOKEN:
            raise StrategicTraceContractError("trace_integrity_invalid")
        value = object.__new__(cls)
        object.__setattr__(value, "_snapshot", _freeze(copy.deepcopy(payload)))
        object.__setattr__(value, "_audit", _freeze(copy.deepcopy(audit)))
        object.__setattr__(value, "_construction_seal", token)
        object.__setattr__(value, "_context_binding", context)
        object.__setattr__(value, "_decision_binding", decision)
        object.__setattr__(value, "_ir_binding", ir)
        if not value.validate_integrity(context, decision, ir):
            raise StrategicTraceContractError("trace_integrity_invalid")
        return value

    @property
    def trace_hash(self) -> str:
        return str(self._snapshot.get("trace_hash", "")) if isinstance(self._snapshot, Mapping) else ""

    def validate_integrity(self, context: StrategicContextV18, decision: PolicyDecision, ir: RestrictedBaseGraphIR) -> bool:
        try:
            if (
                type(self) is not StrategicTraceV2
                or self._construction_seal is not _TRACE_TOKEN
                or context is not self._context_binding
                or decision is not self._decision_binding
                or ir is not self._ir_binding
                or not _decision_bound_to_context(context, decision)
                or type(ir) is not RestrictedBaseGraphIR
                or not ir.validate_integrity()
                or not isinstance(self._snapshot, Mapping)
                or not isinstance(self._audit, Mapping)
            ):
                return False
            snapshot = _thaw(self._snapshot)
            audit = _thaw(self._audit)
            if type(snapshot) is not dict or type(audit) is not dict or not _trace_audit_valid(context, decision, ir, audit):
                return False
            expected = _trace_payload(context, decision, ir, snapshot.get("trace_id", ""), audit)
            return _identifier(snapshot.get("trace_id")) and snapshot == expected
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._context_binding, self._decision_binding, self._ir_binding):
            raise StrategicTraceContractError("trace_integrity_invalid")
        return _thaw(self._snapshot)


@dataclass(frozen=True, slots=True)
class StrategicTraceBuildResult:
    accepted: bool
    error_code: str
    trace: StrategicTraceV2 | None


class StrategicTraceV2Builder:
    __slots__ = ()

    @staticmethod
    def build(
        context: Any,
        decision: Any,
        ir: Any,
        *,
        trace_id: Any,
        audit: Any,
        contract_root: Path | None = None,
    ) -> StrategicTraceBuildResult:
        try:
            _load_contracts(contract_root)
        except StrategicTraceContractError:
            return StrategicTraceBuildResult(False, "contract_error", None)
        if type(context) is not StrategicContextV18 or not context.validate_integrity():
            return StrategicTraceBuildResult(False, "invalid_context", None)
        if not _decision_bound_to_context(context, decision):
            return StrategicTraceBuildResult(False, "invalid_decision", None)
        if type(ir) is not RestrictedBaseGraphIR or not ir.validate_integrity():
            return StrategicTraceBuildResult(False, "ir_integrity_invalid", None)
        if not _identifier(trace_id):
            return StrategicTraceBuildResult(False, "invalid_trace_identity", None)
        if not _trace_audit_valid(context, decision, ir, audit):
            return StrategicTraceBuildResult(False, "invalid_trace_audit", None)
        try:
            payload = _trace_payload(context, decision, ir, trace_id, audit)
            trace = StrategicTraceV2._from_owner(payload, copy.deepcopy(audit), context, decision, ir, _TRACE_TOKEN)
            return StrategicTraceBuildResult(True, "", trace)
        except (StrategicTraceContractError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return StrategicTraceBuildResult(False, "trace_integrity_invalid", None)


__all__ = [
    "EXPECTED_BUNDLE_SHA256",
    "IR_PROFILE_ID",
    "PROFILE_ID",
    "RestrictedBaseGraphIR",
    "RestrictedBaseGraphIRCompiler",
    "RestrictedIrBuildResult",
    "StrategicTraceBuildResult",
    "StrategicTraceContractError",
    "StrategicTraceV2",
    "StrategicTraceV2Builder",
]
