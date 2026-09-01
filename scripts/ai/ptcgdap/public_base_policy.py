from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Final, Mapping

from .cabt_selection import (
    CabtSelectionResolution,
    CabtSelectionSanitizer,
    CabtSelectionWindow,
    _require_current_window,
)
from .public_deck_adapter import PublicDeckAdapter, PublicDeckAdapterProposer, PublicDeckAdapterProposalResult
from .restricted_base_graph_executor import (
    RestrictedBaseGraphExecutionResult,
    RestrictedBaseGraphExecutor,
)
from .source_lock import canonical_json_v1_bytes, load_json_strict
from .strategic_context_v18 import PolicyDecision, PolicyDecisionFactory, StrategicContextV18
from .strategic_trace_v2 import (
    RestrictedBaseGraphIR,
    StrategicTraceV2,
    StrategicTraceV2Builder,
)


PROFILE_ID: Final = "ptcgdap-public-base-policy-p4-wp5-v1"
EXPECTED_BUNDLE_SHA256: Final = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
EXPECTED_PARENT_BUNDLE_SHA256: Final = "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
EXPECTED_SOURCE_LOCK_SHA256: Final = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_ARTIFACTS: Final = MappingProxyType(
    {
        "public_base_policy.schema.json": "25041F0E72EEC217522B0606CA77C100D66DD76ECED39C7F3B233DFB4C0FB42D",
        "public_base_policy_profile.json": "AEA206038915757F1D32004CBF0E5662A244953A5D40C7952281E861D4E3313C",
        "public_base_policy_conformance_vectors.json": "377F5BB2B3DE594D1DD17B5FD548D6EAB26D5CA7D933DBEF6D8B24216CE65072",
    }
)
DEFAULT_ROOT: Final = Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
ORCHESTRATION_PREFIX: Final = b"PTCGDAP\0PUBLIC_BASE_POLICY_ORCHESTRATION_V1\0"
SAFE_MAX: Final = 9_007_199_254_740_991
STAGES: Final = (
    "validate_exact_owners",
    "propose_public_adapter_hints",
    "execute_restricted_base_graph",
    "sanitize_against_exact_current_window",
    "issue_policy_decision",
    "issue_strategic_trace",
    "seal_public_audit_result",
)
REQUEST_KEYS: Final = frozenset(
    {
        "orchestration_id",
        "proposal_id",
        "execution_id",
        "scene_id",
        "decision_id",
        "determinism_key",
        "trace_id",
        "policy_hash",
        "mandatory_indexes",
        "terminal_indexes",
        "base_hard_tiers",
        "base_vetoed_indexes",
    }
)
IDENTITY_KEYS: Final = (
    "orchestration_id",
    "proposal_id",
    "execution_id",
    "scene_id",
    "decision_id",
    "determinism_key",
    "trace_id",
)
PRIVATE_KEYS: Final = frozenset(
    {
        "raw_private_hash",
        "token_free_callback_hash",
        "search_begin_input",
        "session",
        "callback",
        "binding",
        "ticket",
        "command",
        "object_ref",
        "pokemon_entity_serial",
    }
)
_IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
_UPPER_SHA = re.compile(r"^[0-9A-F]{64}$")
_RESULT_TOKEN = object()


class PublicBasePolicyError(ValueError):
    pass


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _domain_hash(value: Any) -> str:
    return _sha(ORCHESTRATION_PREFIX + canonical_json_v1_bytes(value))


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


def _identifier(value: Any) -> bool:
    return (
        type(value) is str
        and _IDENTIFIER.fullmatch(value) is not None
        and "private" not in value.lower()
    )


def _safe_int(value: Any) -> bool:
    return type(value) is int and -SAFE_MAX <= value <= SAFE_MAX


def _contains_private(value: Any) -> bool:
    if type(value) is str:
        return value.lower() in PRIVATE_KEYS or "private" in value.lower()
    if type(value) is list:
        return any(_contains_private(child) for child in value)
    if type(value) is dict:
        return any(_contains_private(key) or _contains_private(child) for key, child in value.items())
    return False


def _load_contracts(root: Path | None = None) -> None:
    contract_root = DEFAULT_ROOT if root is None else Path(root)
    try:
        bundle = load_json_strict(contract_root / "public_base_policy_bundle.json")
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_SHA256:
            raise PublicBasePolicyError("contract_error")
        if type(bundle) is not dict or set(bundle) != {
            "schema_version",
            "bundle_id",
            "parent_bundle_canonical_sha256",
            "source_lock_canonical_sha256",
            "artifacts",
        }:
            raise PublicBasePolicyError("contract_error")
        if (
            bundle["schema_version"] != 1
            or bundle["bundle_id"] != PROFILE_ID
            or bundle["parent_bundle_canonical_sha256"] != EXPECTED_PARENT_BUNDLE_SHA256
            or bundle["source_lock_canonical_sha256"] != EXPECTED_SOURCE_LOCK_SHA256
        ):
            raise PublicBasePolicyError("contract_error")
        entries = bundle["artifacts"]
        expected_names = tuple(EXPECTED_ARTIFACTS)
        if type(entries) is not list or len(entries) != len(expected_names):
            raise PublicBasePolicyError("contract_error")
        documents: dict[str, Any] = {}
        for entry, name in zip(entries, expected_names, strict=True):
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise PublicBasePolicyError("contract_error")
            if (
                entry["id"] != name.removesuffix(".json")
                or entry["path"] != f"contracts/ptcgdap/{name}"
                or entry["canonical_sha256"] != EXPECTED_ARTIFACTS[name]
            ):
                raise PublicBasePolicyError("contract_error")
            document = load_json_strict(contract_root / name)
            if _sha(canonical_json_v1_bytes(document)) != EXPECTED_ARTIFACTS[name]:
                raise PublicBasePolicyError("contract_error")
            documents[name] = document
        profile = documents["public_base_policy_profile.json"]
        contract = profile.get("orchestration_contract", {}) if type(profile) is dict else {}
        result = profile.get("result_contract", {}) if type(profile) is dict else {}
        if (
            profile.get("profile_id") != PROFILE_ID
            or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256
            or tuple(contract.get("fixed_stage_order", ())) != STAGES
            or contract.get("failure_atomicity") != "no_partial_proposal_execution_resolution_decision_or_trace"
            or contract.get("executor_output_revalidated_by_current_window_sanitizer") is not True
            or contract.get("mandatory_terminal_precedes_hard_tier") is not True
            or contract.get("adapter_authority") != "same_base_tier_ordering_hint_only"
            or result.get("serialized_result_is_execution_authority") is not False
            or result.get("exact_owner_revalidation_required") is not True
        ):
            raise PublicBasePolicyError("contract_error")
    except PublicBasePolicyError:
        raise
    except Exception as exc:
        raise PublicBasePolicyError("contract_error") from exc


def _index_list(value: Any, option_count: int) -> bool:
    return (
        type(value) is list
        and len(value) <= 1024
        and all(type(index) is int and 0 <= index < option_count for index in value)
        and len(value) == len(set(value))
    )


def _request_error(value: Any, option_count: int) -> str | None:
    if _contains_private(value):
        return "private_orchestration_input"
    if type(value) is not dict or set(value) != REQUEST_KEYS:
        return "invalid_orchestration_input"
    if any(not _identifier(value[key]) for key in IDENTITY_KEYS):
        return "invalid_orchestration_input"
    if type(value["policy_hash"]) is not str or _UPPER_SHA.fullmatch(value["policy_hash"]) is None:
        return "invalid_orchestration_input"
    for key in ("mandatory_indexes", "terminal_indexes", "base_vetoed_indexes"):
        if not _index_list(value[key], option_count):
            return "invalid_orchestration_input"
    tiers = value["base_hard_tiers"]
    if type(tiers) is not list or len(tiers) != option_count:
        return "invalid_orchestration_input"
    seen: set[int] = set()
    for entry in tiers:
        if type(entry) is not dict or set(entry) != {"index", "tier"}:
            return "invalid_orchestration_input"
        index, tier = entry["index"], entry["tier"]
        if (
            type(index) is not int
            or not 0 <= index < option_count
            or index in seen
            or type(tier) is not list
            or not 1 <= len(tier) <= 8
            or not all(_safe_int(child) for child in tier)
        ):
            return "invalid_orchestration_input"
        seen.add(index)
    if seen != set(range(option_count)):
        return "invalid_orchestration_input"
    return None


def _exact_owners(context: Any, window: Any, ir: Any, adapter: Any) -> str | None:
    if type(context) is not StrategicContextV18 or not context.validate_integrity():
        return "invalid_context"
    try:
        current = _require_current_window(window)
    except (AttributeError, TypeError, ValueError):
        return "invalid_window"
    if type(window) is not CabtSelectionWindow or current is not window:
        return "invalid_window"
    if context._window_binding is not window or context.window_id != window.window_id:
        return "invalid_window"
    if type(ir) is not RestrictedBaseGraphIR or not ir.validate_integrity():
        return "invalid_ir"
    if type(adapter) is not PublicDeckAdapter or not adapter.validate_integrity():
        return "invalid_adapter"
    return None


def _result_payload(
    context: StrategicContextV18,
    window: CabtSelectionWindow,
    ir: RestrictedBaseGraphIR,
    adapter: PublicDeckAdapter,
    proposal: PublicDeckAdapterProposalResult,
    execution: RestrictedBaseGraphExecutionResult,
    decision: PolicyDecision,
    trace: StrategicTraceV2,
    request: dict[str, Any],
) -> dict[str, Any]:
    decision_value = decision.to_public_dict()
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "orchestration_id": request["orchestration_id"],
        "source": {
            "context_hash": context.context_hash,
            "window_id": window.window_id,
            "ir_hash": ir.ir_hash,
            "adapter_hash": adapter.adapter_hash,
            "proposal_hash": proposal.proposal_hash,
            "execution_hash": execution.execution_hash,
            "decision_audit_id": decision.audit_id,
            "trace_hash": trace.trace_hash,
            "policy_hash": request["policy_hash"],
        },
        "selected_indexes": list(decision_value["selected_indexes"]),
        "owner_layer": decision_value["owner_layer"],
        "reason_code": decision_value["reason_code"],
        "fallback_tier": decision_value["fallback_tier"],
        "completed_stages": list(STAGES),
        "public_only": True,
        "authority": "public_base_policy_orchestration_audit",
        "authoritative": False,
    }
    return {**payload, "orchestration_hash": _domain_hash(payload)}


@dataclass(frozen=True, slots=True, init=False)
class PublicBasePolicyResult:
    _snapshot: Mapping[str, Any]
    _request: Mapping[str, Any]
    _construction_seal: object
    _context_binding: StrategicContextV18
    _window_binding: CabtSelectionWindow
    _ir_binding: RestrictedBaseGraphIR
    _adapter_binding: PublicDeckAdapter
    _proposal_binding: PublicDeckAdapterProposalResult
    _execution_binding: RestrictedBaseGraphExecutionResult
    _resolution_binding: CabtSelectionResolution
    _decision_binding: PolicyDecision
    _trace_binding: StrategicTraceV2

    def __new__(cls) -> PublicBasePolicyResult:
        raise TypeError("PublicBasePolicyResult is orchestrator-owned")

    @classmethod
    def _from_owner(
        cls,
        context: StrategicContextV18,
        window: CabtSelectionWindow,
        ir: RestrictedBaseGraphIR,
        adapter: PublicDeckAdapter,
        proposal: PublicDeckAdapterProposalResult,
        execution: RestrictedBaseGraphExecutionResult,
        resolution: CabtSelectionResolution,
        decision: PolicyDecision,
        trace: StrategicTraceV2,
        request: dict[str, Any],
        token: object,
    ) -> PublicBasePolicyResult:
        if token is not _RESULT_TOKEN:
            raise PublicBasePolicyError("orchestration_integrity_invalid")
        value = object.__new__(cls)
        payload = _result_payload(context, window, ir, adapter, proposal, execution, decision, trace, request)
        for name, child in (
            ("_snapshot", _freeze(copy.deepcopy(payload))),
            ("_request", _freeze(copy.deepcopy(request))),
            ("_construction_seal", token),
            ("_context_binding", context),
            ("_window_binding", window),
            ("_ir_binding", ir),
            ("_adapter_binding", adapter),
            ("_proposal_binding", proposal),
            ("_execution_binding", execution),
            ("_resolution_binding", resolution),
            ("_decision_binding", decision),
            ("_trace_binding", trace),
        ):
            object.__setattr__(value, name, child)
        if not value.validate_integrity(context, window, ir, adapter):
            raise PublicBasePolicyError("orchestration_integrity_invalid")
        return value

    @property
    def decision(self) -> PolicyDecision | None:
        return self._decision_binding if self.validate_integrity(self._context_binding, self._window_binding, self._ir_binding, self._adapter_binding) else None

    @property
    def trace(self) -> StrategicTraceV2 | None:
        return self._trace_binding if self.validate_integrity(self._context_binding, self._window_binding, self._ir_binding, self._adapter_binding) else None

    def validate_integrity(self, context: Any, window: Any, ir: Any, adapter: Any) -> bool:
        try:
            if (
                type(self) is not PublicBasePolicyResult
                or self._construction_seal is not _RESULT_TOKEN
                or context is not self._context_binding
                or window is not self._window_binding
                or ir is not self._ir_binding
                or adapter is not self._adapter_binding
                or _exact_owners(context, window, ir, adapter) is not None
                or not isinstance(self._snapshot, Mapping)
                or not isinstance(self._request, Mapping)
            ):
                return False
            request = _thaw(self._request)
            if _request_error(request, window.option_count) is not None:
                return False
            if not self._proposal_binding.validate_integrity(context, adapter):
                return False
            if not self._execution_binding.validate_integrity(context, ir):
                return False
            if not self._resolution_binding.validate_integrity(window):
                return False
            if not self._decision_binding.validate_integrity(context, window, self._resolution_binding):
                return False
            if not self._trace_binding.validate_integrity(context, self._decision_binding, ir):
                return False
            if self._execution_binding.selected_indexes != list(self._resolution_binding.selected_indexes):
                return False
            expected = _result_payload(
                context,
                window,
                ir,
                adapter,
                self._proposal_binding,
                self._execution_binding,
                self._decision_binding,
                self._trace_binding,
                request,
            )
            return _thaw(self._snapshot) == expected
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._context_binding, self._window_binding, self._ir_binding, self._adapter_binding):
            raise PublicBasePolicyError("orchestration_integrity_invalid")
        return copy.deepcopy(_thaw(self._snapshot))

    def agent_output(self) -> list[int]:
        if not self.validate_integrity(self._context_binding, self._window_binding, self._ir_binding, self._adapter_binding):
            return []
        return list(self._resolution_binding.selected_indexes)


@dataclass(frozen=True, slots=True)
class PublicBasePolicyOutcome:
    accepted: bool
    failed_stage: str
    error_code: str
    result: PublicBasePolicyResult | None


def _failure(stage: str, code: str) -> PublicBasePolicyOutcome:
    return PublicBasePolicyOutcome(False, stage, code, None)


class PublicBasePolicyOrchestrator:
    __slots__ = ()

    @staticmethod
    def orchestrate(
        context: Any,
        window: Any,
        ir: Any,
        adapter: Any,
        request: Any,
        *,
        contract_root: Path | None = None,
    ) -> PublicBasePolicyOutcome:
        try:
            _load_contracts(contract_root)
        except PublicBasePolicyError:
            return _failure("contract", "contract_error")
        owner_error = _exact_owners(context, window, ir, adapter)
        if owner_error is not None:
            return _failure("validate_exact_owners", owner_error)
        request_error = _request_error(request, window.option_count)
        if request_error is not None:
            return _failure("validate_exact_owners", request_error)
        request_value = copy.deepcopy(request)

        proposal_outcome = PublicDeckAdapterProposer.propose(context, adapter, request_value["proposal_id"])
        if not proposal_outcome.accepted or proposal_outcome.result is None:
            return _failure("propose_public_adapter_hints", "adapter_proposal_failed")
        proposal = proposal_outcome.result

        execution_input = {
            "execution_id": request_value["execution_id"],
            "mandatory_indexes": request_value["mandatory_indexes"],
            "terminal_indexes": request_value["terminal_indexes"],
            "base_hard_tiers": request_value["base_hard_tiers"],
            "base_vetoed_indexes": request_value["base_vetoed_indexes"],
            "adapter_proposals": proposal.adapter_proposals,
        }
        execution_outcome = RestrictedBaseGraphExecutor.execute(context, ir, execution_input)
        if not execution_outcome.accepted or execution_outcome.result is None:
            return _failure("execute_restricted_base_graph", "base_execution_failed")
        execution = execution_outcome.result

        try:
            resolution = CabtSelectionSanitizer.resolve_policy_attempt(
                window,
                execution.selected_indexes,
                outcome="returned",
            )
        except Exception:
            return _failure("sanitize_against_exact_current_window", "selection_sanitization_failed")
        if (
            type(resolution) is not CabtSelectionResolution
            or not resolution.validate_integrity(window)
            or resolution.owner != "policy"
            or list(resolution.selected_indexes) != execution.selected_indexes
        ):
            return _failure("sanitize_against_exact_current_window", "selection_sanitization_failed")

        decision_outcome = PolicyDecisionFactory.build(
            context,
            window,
            resolution,
            policy_hash=request_value["policy_hash"],
            scene_id=request_value["scene_id"],
            decision_id=request_value["decision_id"],
            determinism_key=request_value["determinism_key"],
        )
        if not decision_outcome.accepted or decision_outcome.decision is None:
            return _failure("issue_policy_decision", "policy_decision_failed")
        decision = decision_outcome.decision

        trace_audit = {
            "legal_indexes": list(range(window.option_count)),
            "strategic_indexes": list(range(window.option_count)),
            "mandatory_indexes": copy.deepcopy(request_value["mandatory_indexes"]),
            "terminal_indexes": copy.deepcopy(request_value["terminal_indexes"]),
            "base_hard_tiers": copy.deepcopy(request_value["base_hard_tiers"]),
            "base_vetoed_indexes": copy.deepcopy(request_value["base_vetoed_indexes"]),
            "adapter_proposals": proposal.adapter_proposals,
            "fallback_reason": "",
        }
        trace_outcome = StrategicTraceV2Builder.build(
            context,
            decision,
            ir,
            trace_id=request_value["trace_id"],
            audit=trace_audit,
        )
        if not trace_outcome.accepted or trace_outcome.trace is None:
            return _failure("issue_strategic_trace", "strategic_trace_failed")
        trace = trace_outcome.trace

        try:
            result = PublicBasePolicyResult._from_owner(
                context,
                window,
                ir,
                adapter,
                proposal,
                execution,
                resolution,
                decision,
                trace,
                request_value,
                _RESULT_TOKEN,
            )
            return PublicBasePolicyOutcome(True, "", "", result)
        except Exception:
            return _failure("seal_public_audit_result", "orchestration_integrity_invalid")


__all__ = [
    "EXPECTED_BUNDLE_SHA256",
    "PROFILE_ID",
    "PublicBasePolicyError",
    "PublicBasePolicyOrchestrator",
    "PublicBasePolicyOutcome",
    "PublicBasePolicyResult",
]
