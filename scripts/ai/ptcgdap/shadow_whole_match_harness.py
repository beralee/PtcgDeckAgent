from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any
import weakref

from scripts.ai.ptcgdap.shadow_engine_command_applier import ShadowEngineCommandApplier
from scripts.ai.ptcgdap.shadow_match_owner_gate import ShadowMatchOwnerGate
from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker, ShadowPromptBrokerResult, ShadowPromptHandle
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "shadow_whole_match_harness_bundle.json"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"
PROFILE_ID = "ptcgdap-shadow-whole-match-harness-p3-wp8-v1"
SAFE_MAX = 9007199254740991
MAX_PROMPT_COUNT = 64
FACTORY_TOKEN = object()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_contracts() -> tuple[MappingProxyType[str, Any], frozenset[str], frozenset[str], frozenset[str]]:
    bundle = load_json_strict(BUNDLE_PATH)
    if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise RuntimeError("shadow whole-match harness bundle trust-anchor mismatch")
    if type(bundle) is not dict or bundle.get("contract_id") != PROFILE_ID:
        raise RuntimeError("shadow whole-match harness identity mismatch")
    parents = {
        "parent_applier_bundle_canonical_sha256": "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C",
        "parent_owner_gate_bundle_canonical_sha256": "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C",
        "parent_prompt_broker_bundle_canonical_sha256": "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E",
    }
    if any(bundle.get(key) != value for key, value in parents.items()):
        raise RuntimeError("shadow whole-match harness parent mismatch")
    expected = {
        "schema": "contracts/ptcgdap/shadow_whole_match_harness.schema.json",
        "profile": "contracts/ptcgdap/shadow_whole_match_harness_profile.json",
        "vectors": "contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json",
    }
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("shadow whole-match harness artifact set mismatch")
    documents: dict[str, Any] = {}
    for entry in entries:
        if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
            raise RuntimeError("shadow whole-match harness artifact entry mismatch")
        artifact_id = entry["id"]
        if artifact_id in documents or expected.get(artifact_id) != entry["path"]:
            raise RuntimeError("shadow whole-match harness artifact identity mismatch")
        document = load_json_strict(ROOT / entry["path"])
        if _sha(canonical_json_v1_bytes(document)) != entry["canonical_sha256"]:
            raise RuntimeError("shadow whole-match harness artifact hash mismatch")
        documents[artifact_id] = document
    if set(documents) != set(expected):
        raise RuntimeError("shadow whole-match harness artifact set mismatch")
    profile = documents["profile"]
    if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("shadow whole-match harness profile mismatch")
    if any(profile.get(key) != value for key, value in parents.items()):
        raise RuntimeError("shadow whole-match harness profile parent mismatch")
    states, errors, faults = profile.get("states"), profile.get("error_codes"), profile.get("fault_codes")
    if states != ["ready", "active", "completed", "faulted", "dirty", "rollback_verified"]:
        raise RuntimeError("shadow whole-match harness state mismatch")
    if type(errors) is not list or not errors or len(errors) != len(set(errors)):
        raise RuntimeError("shadow whole-match harness error mismatch")
    if type(faults) is not list or faults != ["", "capture_failed", "command_apply_failed", "rollback_failed", "invalid_broker_result", "stale_prompt_chain", "prompt_limit_exceeded"]:
        raise RuntimeError("shadow whole-match harness fault mismatch")
    if profile.get("limits") != {"max_prompt_count": MAX_PROMPT_COUNT}:
        raise RuntimeError("shadow whole-match harness limit mismatch")
    return MappingProxyType(profile), frozenset(states), frozenset(errors), frozenset(faults)


PROFILE, STATES, ERROR_CODES, FAULT_CODES = _load_contracts()


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) in (list, tuple):
        return [_copy_json(item) for item in value]
    return value


def _positive(value: Any) -> bool:
    return type(value) is int and 1 <= value <= SAFE_MAX


def _upper_sha(value: Any) -> bool:
    return type(value) is str and len(value) == 64 and all(ch in "0123456789ABCDEF" for ch in value)


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class ShadowWholeMatchResult:
    accepted: bool
    error_code: str
    _report: dict[str, Any]
    _owner_ref: weakref.ReferenceType["ShadowWholeMatchHarness"]
    _construction_seal: object
    _sealed_digest: str

    def __new__(cls) -> "ShadowWholeMatchResult":
        raise TypeError("shadow whole-match results must be owner-created")

    @classmethod
    def _from_owner(cls, owner: "ShadowWholeMatchHarness", accepted: bool, error_code: str, report: dict[str, Any]) -> "ShadowWholeMatchResult":
        result = object.__new__(cls)
        sealed = _copy_json(report)
        payload = {"accepted": accepted, "error_code": error_code, "report": sealed}
        for name, value in {
            "accepted": accepted,
            "error_code": error_code,
            "_report": sealed,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": FACTORY_TOKEN,
            "_sealed_digest": _sha(canonical_json_v1_bytes(payload)),
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "ShadowWholeMatchHarness") -> bool:
        try:
            if type(owner) is not ShadowWholeMatchHarness or self._owner_ref() is not owner or self._construction_seal is not FACTORY_TOKEN:
                return False
            if type(self.accepted) is not bool or type(self.error_code) is not str:
                return False
            if self.accepted != (self.error_code == "") or (not self.accepted and self.error_code not in ERROR_CODES):
                return False
            if not owner._report_valid(self._report):
                return False
            payload = {"accepted": self.accepted, "error_code": self.error_code, "report": self._report}
            return _upper_sha(self._sealed_digest) and _sha(canonical_json_v1_bytes(payload)) == self._sealed_digest
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not ShadowWholeMatchHarness or not self.validate_integrity(owner):
            return {"accepted": False, "error_code": "invalid_harness", "report": owner._empty_report() if type(owner) is ShadowWholeMatchHarness else {}}
        return {"accepted": self.accepted, "error_code": self.error_code, "report": _copy_json(self._report)}

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


class ShadowWholeMatchHarness:
    __slots__ = (
        "__weakref__", "_gate", "_broker", "_state", "_match_generation", "_records", "_fault_code",
        "_dirty", "_rollback_requested", "_match_ended", "_next_match_mode", "_construction_seal", "_state_digest",
    )

    def __init__(self, gate: Any, broker: Any) -> None:
        self._gate = gate
        self._broker = broker
        self._state = "ready"
        self._match_generation: int | None = None
        self._records: tuple[dict[str, Any], ...] = ()
        self._fault_code = ""
        self._dirty = False
        self._rollback_requested = False
        self._match_ended = False
        self._next_match_mode: str | None = None
        self._construction_seal = FACTORY_TOKEN
        self._state_digest = self._digest()

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def start(self) -> ShadowWholeMatchResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_harness")
        if self._state != "ready":
            return self._result(False, "already_started")
        code = self._authority_error()
        if code:
            return self._result(False, code)
        audit = self._gate.audit_snapshot()
        self._match_generation = audit["match_generation"]
        self._state = "active"
        self._reseal()
        return self._result(True, "")

    def apply_prompt(self, broker_result: Any) -> ShadowWholeMatchResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_harness")
        if self._state == "ready":
            return self._result(False, "not_started")
        if self._state != "active":
            return self._result(False, "match_terminal")
        code = self._authority_error()
        if code:
            return self._terminal_fault("invalid_broker_result", code)
        if len(self._records) >= MAX_PROMPT_COUNT:
            return self._terminal_fault("prompt_limit_exceeded", "prompt_limit_exceeded")
        if type(broker_result) is not ShadowPromptBrokerResult or not broker_result.accepted or broker_result.error_code != "" or not broker_result.validate_integrity(self._broker):
            return self._terminal_fault("invalid_broker_result", "invalid_broker_result")
        prompt = broker_result.prompt
        if type(prompt) is not ShadowPromptHandle or prompt.state != "awaiting_reobserve":
            return self._terminal_fault("invalid_broker_result", "invalid_broker_result")
        public = broker_result.to_public_dict()
        audit = public.get("audit") if type(public) is dict else None
        if type(audit) is not dict:
            return self._terminal_fault("invalid_broker_result", "invalid_broker_result")
        candidate = {
            "broker_generation": audit.get("broker_generation"),
            "decision_generation": audit.get("decision_generation"),
            "snapshot_id": audit.get("snapshot_id"),
            "window_id": audit.get("window_id"),
        }
        if not self._candidate_chain_valid(candidate):
            return self._terminal_fault("stale_prompt_chain", "stale_prompt_chain")
        applier = ShadowEngineCommandApplier(self._gate, self._broker)
        applied = applier.apply(broker_result)
        if not applied.accepted:
            fault = applied.error_code if applied.error_code in {"capture_failed", "command_apply_failed", "rollback_failed"} else "invalid_broker_result"
            error = "dirty_game_detected" if applied.poisoned else "prompt_apply_failed"
            return self._terminal_fault(fault, error, dirty=applied.poisoned)
        witness = applied.witness
        if witness is None or not witness.validate_integrity(applier):
            return self._terminal_fault("invalid_broker_result", "invalid_broker_result")
        witness_public = witness.witness_snapshot()
        record = {
            **candidate,
            "execution_id": witness_public.get("execution_id"),
        }
        if not self._record_valid(record):
            return self._terminal_fault("invalid_broker_result", "invalid_broker_result")
        self._records = (*self._records, record)
        self._reseal()
        return self._result(True, "")

    def finish_match(self) -> ShadowWholeMatchResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_harness")
        if self._state == "ready":
            return self._result(False, "not_started")
        if self._match_ended or self._state in {"completed", "rollback_verified"}:
            return self._result(False, "match_terminal")
        assert self._match_generation is not None
        ended = self._gate.end_match(self._match_generation)
        if not ended.accepted or not ended.validate_integrity(self._gate):
            return self._result(False, "match_end_failed")
        self._match_ended = True
        if self._state == "active":
            self._state = "completed"
        self._reseal()
        return self._result(True, "")

    def verify_next_match_rollback(self, next_match_generation: Any) -> ShadowWholeMatchResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_harness")
        if self._state not in {"faulted", "dirty"} or not self._rollback_requested:
            return self._result(False, "rollback_not_required")
        if not self._match_ended:
            return self._result(False, "match_end_failed")
        if not _positive(next_match_generation) or self._match_generation is None or next_match_generation <= self._match_generation:
            return self._result(False, "invalid_match_generation")
        begun = self._gate.begin_match(next_match_generation, "aligned_shadow")
        audit = self._gate.audit_snapshot()
        if not begun.accepted or not begun.validate_integrity(self._gate) or audit.get("active_mode") != "legacy" or audit.get("rollback_applied") is not True:
            return self._result(False, "next_match_rollback_failed")
        self._state = "rollback_verified"
        self._next_match_mode = "legacy"
        self._reseal()
        return self._result(True, "")

    def validate_integrity(self) -> bool:
        try:
            return self._structural_valid() and _upper_sha(self._state_digest) and self._digest() == self._state_digest
        except Exception:
            return False

    def audit_snapshot(self) -> dict[str, Any]:
        return self._report() if self.validate_integrity() else self._empty_report()

    def _authority_error(self) -> str:
        if type(self._gate) is not ShadowMatchOwnerGate or not self._gate.validate_integrity():
            return "invalid_gate"
        audit = self._gate.audit_snapshot()
        if audit.get("state") != "active" or audit.get("active_mode") != "aligned_shadow":
            return "owner_mode_not_aligned"
        if type(self._broker) is not ShadowPromptBroker or not self._broker.validate_integrity():
            return "invalid_broker"
        if self._gate._active_broker is not self._broker:
            return "broker_not_current"
        if self._broker._match_generation != audit.get("match_generation"):
            return "broker_not_current"
        if self._match_generation is not None and self._match_generation != audit.get("match_generation"):
            return "invalid_gate"
        return ""

    def _terminal_fault(self, fault: str, error: str, *, dirty: bool = False) -> ShadowWholeMatchResult:
        assert fault in FAULT_CODES and fault
        self._fault_code = fault
        self._dirty = dirty
        self._state = "dirty" if dirty else "faulted"
        assert self._match_generation is not None
        requested = self._gate.request_legacy_next_match(self._match_generation)
        if not requested.accepted or not requested.validate_integrity(self._gate):
            self._dirty = True
            self._state = "dirty"
            self._fault_code = "rollback_failed"
            # The aligned path is terminally closed even when the owner gate
            # cannot persist the request.  Keep that requirement in the
            # sealed report so a caller cannot treat the match as reusable.
            self._rollback_requested = True
            self._reseal()
            return self._result(False, "rollback_request_failed")
        self._rollback_requested = True
        self._reseal()
        return self._result(False, error)

    def _candidate_chain_valid(self, candidate: dict[str, Any]) -> bool:
        if not _positive(candidate["broker_generation"]) or not _positive(candidate["decision_generation"]):
            return False
        if not _upper_sha(candidate["snapshot_id"]) or not _upper_sha(candidate["window_id"]):
            return False
        if not self._records:
            return True
        prior = self._records[-1]
        return (
            candidate["broker_generation"] > prior["broker_generation"]
            and candidate["decision_generation"] > prior["decision_generation"]
            and candidate["snapshot_id"] not in {record["snapshot_id"] for record in self._records}
            and candidate["window_id"] not in {record["window_id"] for record in self._records}
        )

    @staticmethod
    def _record_valid(record: Any) -> bool:
        return type(record) is dict and set(record) == {"broker_generation", "decision_generation", "snapshot_id", "window_id", "execution_id"} and _positive(record["broker_generation"]) and _positive(record["decision_generation"]) and _upper_sha(record["snapshot_id"]) and _upper_sha(record["window_id"]) and _upper_sha(record["execution_id"])

    def _structural_valid(self) -> bool:
        if self._construction_seal is not FACTORY_TOKEN or type(self._state) is not str or self._state not in STATES:
            return False
        if type(self._records) is not tuple or len(self._records) > MAX_PROMPT_COUNT or any(not self._record_valid(record) for record in self._records):
            return False
        brokers=[record["broker_generation"] for record in self._records]; decisions=[record["decision_generation"] for record in self._records]
        for key in ("snapshot_id", "window_id", "execution_id"):
            values=[record[key] for record in self._records]
            if len(values)!=len(set(values)): return False
        if brokers != sorted(set(brokers)) or decisions != sorted(set(decisions)):
            return False
        if self._fault_code not in FAULT_CODES or type(self._dirty) is not bool or type(self._rollback_requested) is not bool or type(self._match_ended) is not bool:
            return False
        if self._next_match_mode not in {None, "legacy"}:
            return False
        if self._state == "ready":
            return self._match_generation is None and not self._records and self._fault_code == "" and not self._dirty and not self._rollback_requested and not self._match_ended and self._next_match_mode is None
        if not _positive(self._match_generation):
            return False
        if self._state == "active":
            return self._fault_code == "" and not self._dirty and not self._rollback_requested and not self._match_ended and self._next_match_mode is None
        if self._state == "completed":
            return self._fault_code == "" and not self._dirty and not self._rollback_requested and self._match_ended and self._next_match_mode is None
        if self._state == "faulted":
            return self._fault_code not in {"", "rollback_failed"} and not self._dirty and self._rollback_requested and self._next_match_mode is None
        if self._state == "dirty":
            return self._fault_code == "rollback_failed" and self._dirty and self._rollback_requested and self._next_match_mode is None
        return self._state == "rollback_verified" and self._fault_code != "" and self._rollback_requested and self._match_ended and self._next_match_mode == "legacy"

    def _state_payload(self) -> dict[str, Any]:
        return {
            "state": self._state,
            "match_generation": self._match_generation,
            "records": [_copy_json(record) for record in self._records],
            "fault_code": self._fault_code,
            "dirty": self._dirty,
            "rollback_requested": self._rollback_requested,
            "match_ended": self._match_ended,
            "next_match_mode": self._next_match_mode,
        }

    def _digest(self) -> str:
        return _sha(canonical_json_v1_bytes(self._state_payload()))

    def _reseal(self) -> None:
        self._state_digest = self._digest()

    def _report(self) -> dict[str, Any]:
        return {
            "profile": PROFILE_ID,
            "state": self._state,
            "match_generation": self._match_generation,
            "prompt_count": len(self._records),
            "broker_generations": [record["broker_generation"] for record in self._records],
            "decision_generations": [record["decision_generation"] for record in self._records],
            "snapshot_ids": [record["snapshot_id"] for record in self._records],
            "window_ids": [record["window_id"] for record in self._records],
            "execution_ids": [record["execution_id"] for record in self._records],
            "fault_code": self._fault_code,
            "dirty": self._dirty,
            "rollback_requested": self._rollback_requested,
            "match_ended": self._match_ended,
            "next_match_mode": self._next_match_mode,
            "authority": "shadow_whole_match_report_audit",
            "authoritative": False,
        }

    def _empty_report(self) -> dict[str, Any]:
        return {"profile":PROFILE_ID,"state":"ready","match_generation":None,"prompt_count":0,"broker_generations":[],"decision_generations":[],"snapshot_ids":[],"window_ids":[],"execution_ids":[],"fault_code":"","dirty":False,"rollback_requested":False,"match_ended":False,"next_match_mode":None,"authority":"shadow_whole_match_report_audit","authoritative":False}

    def _report_valid(self, report: Any) -> bool:
        if type(report) is not dict or set(report) != set(self._empty_report()):
            return False
        if report.get("profile") != PROFILE_ID or report.get("state") not in STATES or report.get("authority") != "shadow_whole_match_report_audit" or report.get("authoritative") is not False:
            return False
        count=report.get("prompt_count")
        if type(count) is not int or not 0<=count<=MAX_PROMPT_COUNT:
            return False
        arrays=[report.get(key) for key in ("broker_generations","decision_generations","snapshot_ids","window_ids","execution_ids")]
        if any(type(value) is not list or len(value)!=count or len(value)!=len(set(value)) for value in arrays):
            return False
        if any(not _positive(value) for value in arrays[0]+arrays[1]) or any(not _upper_sha(value) for value in arrays[2]+arrays[3]+arrays[4]):
            return False
        return report.get("fault_code") in FAULT_CODES and type(report.get("dirty")) is bool and type(report.get("rollback_requested")) is bool and type(report.get("match_ended")) is bool and report.get("next_match_mode") in {None,"legacy"} and (report.get("match_generation") is None or _positive(report.get("match_generation")))

    def _result(self, accepted: bool, error_code: str) -> ShadowWholeMatchResult:
        report = self._report() if self._structural_valid() else self._empty_report()
        return ShadowWholeMatchResult._from_owner(self, accepted, error_code, report)
