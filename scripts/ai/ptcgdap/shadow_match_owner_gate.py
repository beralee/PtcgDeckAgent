from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any
import weakref

from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "shadow_match_owner_gate_bundle.json"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C"
PROFILE_ID = "ptcgdap-shadow-match-owner-gate-p3-wp6-v1"
SAFE_MAX = 9007199254740991
FACTORY_TOKEN = object()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_contracts() -> tuple[MappingProxyType[str, Any], frozenset[str], frozenset[str]]:
    bundle = load_json_strict(BUNDLE_PATH)
    if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise RuntimeError("shadow match owner gate bundle trust-anchor mismatch")
    if type(bundle) is not dict or bundle.get("contract_id") != PROFILE_ID:
        raise RuntimeError("shadow match owner gate identity mismatch")
    expected = {
        "schema": "contracts/ptcgdap/shadow_match_owner_gate.schema.json",
        "profile": "contracts/ptcgdap/shadow_match_owner_gate_profile.json",
        "vectors": "contracts/ptcgdap/shadow_match_owner_gate_conformance_vectors.json",
    }
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("shadow match owner gate artifact set mismatch")
    documents: dict[str, Any] = {}
    for entry in entries:
        if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
            raise RuntimeError("shadow match owner gate artifact entry mismatch")
        artifact_id = entry["id"]
        if artifact_id in documents or expected.get(artifact_id) != entry["path"]:
            raise RuntimeError("shadow match owner gate artifact identity mismatch")
        document = load_json_strict(ROOT / entry["path"])
        if _sha(canonical_json_v1_bytes(document)) != entry["canonical_sha256"]:
            raise RuntimeError("shadow match owner gate artifact hash mismatch")
        documents[artifact_id] = document
    if set(documents) != set(expected):
        raise RuntimeError("shadow match owner gate artifact set mismatch")
    profile = documents["profile"]
    if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("shadow match owner gate profile mismatch")
    modes = profile.get("owner_modes")
    states = profile.get("states")
    errors = profile.get("error_codes")
    if modes != ["legacy", "aligned_shadow"] or states != ["idle", "active", "between_matches"]:
        raise RuntimeError("shadow match owner gate domain mismatch")
    if type(errors) is not list or not errors or len(errors) != len(set(errors)) or any(type(code) is not str or not code for code in errors):
        raise RuntimeError("shadow match owner gate error domain mismatch")
    return MappingProxyType(profile), frozenset(modes), frozenset(errors)


PROFILE, OWNER_MODES, ERROR_CODES = _load_contracts()


def _positive(value: Any) -> bool:
    return type(value) is int and 1 <= value <= SAFE_MAX


def _nonnegative(value: Any) -> bool:
    return type(value) is int and 0 <= value <= SAFE_MAX


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) in (list, tuple):
        return [_copy_json(item) for item in value]
    return value


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class ShadowMatchOwnerGateResult:
    accepted: bool
    error_code: str
    _audit: dict[str, Any] | None
    _owner_ref: weakref.ReferenceType["ShadowMatchOwnerGate"]
    _construction_seal: object
    _sealed_digest: str

    def __new__(cls) -> "ShadowMatchOwnerGateResult":
        raise TypeError("shadow match owner gate results must be owner-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "ShadowMatchOwnerGate",
        accepted: bool,
        error_code: str,
        audit: dict[str, Any] | None,
    ) -> "ShadowMatchOwnerGateResult":
        result = object.__new__(cls)
        sealed_audit = None if audit is None else _copy_json(audit)
        payload = {"accepted": accepted, "error_code": error_code, "audit": sealed_audit}
        for name, value in {
            "accepted": accepted,
            "error_code": error_code,
            "_audit": sealed_audit,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": FACTORY_TOKEN,
            "_sealed_digest": _sha(canonical_json_v1_bytes(payload)),
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "ShadowMatchOwnerGate") -> bool:
        try:
            if (
                type(owner) is not ShadowMatchOwnerGate
                or type(self._owner_ref) is not weakref.ReferenceType
                or self._owner_ref() is not owner
                or self._construction_seal is not FACTORY_TOKEN
            ):
                return False
            if type(self.accepted) is not bool or type(self.error_code) is not str:
                return False
            if self.accepted:
                if self.error_code != "" or type(self._audit) is not dict:
                    return False
            elif self.error_code not in ERROR_CODES or (self._audit is not None and type(self._audit) is not dict):
                return False
            payload = {"accepted": self.accepted, "error_code": self.error_code, "audit": self._audit}
            return type(self._sealed_digest) is str and _sha(canonical_json_v1_bytes(payload)) == self._sealed_digest
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not ShadowMatchOwnerGate or not self.validate_integrity(owner):
            return {"accepted": False, "error_code": "invalid_gate", "audit": None}
        return {"accepted": self.accepted, "error_code": self.error_code, "audit": _copy_json(self._audit)}

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()

    def audit_snapshot(self) -> dict[str, Any]:
        public = self.to_public_dict()
        return {} if type(public["audit"]) is not dict else public["audit"]


class ShadowMatchOwnerGate:
    __slots__ = (
        "__weakref__", "_state", "_match_generation", "_last_match_generation", "_active_mode",
        "_active_broker", "_rollback_pending", "_rollback_applied", "_gate_generation", "_construction_seal",
    )

    def __init__(self) -> None:
        self._state = "idle"
        self._match_generation: int | None = None
        self._last_match_generation = 0
        self._active_mode: str | None = None
        self._active_broker: ShadowPromptBroker | None = None
        self._rollback_pending = False
        self._rollback_applied = False
        self._gate_generation = 0
        self._construction_seal = FACTORY_TOKEN

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def validate_integrity(self) -> bool:
        try:
            if self._construction_seal is not FACTORY_TOKEN:
                return False
            if type(self._state) is not str or self._state not in {"idle", "active", "between_matches"}:
                return False
            if not _nonnegative(self._last_match_generation) or not _nonnegative(self._gate_generation):
                return False
            if type(self._rollback_pending) is not bool or type(self._rollback_applied) is not bool:
                return False
            if self._state == "idle":
                return (
                    self._match_generation is None and self._last_match_generation == 0 and self._active_mode is None
                    and self._active_broker is None and not self._rollback_pending and not self._rollback_applied
                )
            if self._state == "between_matches":
                return (
                    _positive(self._match_generation) and self._match_generation == self._last_match_generation
                    and self._active_mode is None and self._active_broker is None and not self._rollback_applied
                )
            if not _positive(self._match_generation) or self._match_generation != self._last_match_generation:
                return False
            if type(self._active_mode) is not str or self._active_mode not in OWNER_MODES:
                return False
            if self._active_mode == "legacy":
                return self._active_broker is None
            return (
                type(self._active_broker) is ShadowPromptBroker
                and self._active_broker.validate_integrity()
                and self._active_broker._match_generation == self._match_generation
                and not self._rollback_applied
            )
        except Exception:
            return False

    def _audit(self) -> dict[str, Any]:
        return {
            "profile": PROFILE_ID,
            "gate_generation": self._gate_generation,
            "state": self._state,
            "match_generation": self._match_generation,
            "active_mode": self._active_mode,
            "rollback_pending": self._rollback_pending,
            "next_forced_mode": "legacy" if self._rollback_pending else None,
            "rollback_applied": self._rollback_applied,
            "authority": "shadow_match_owner_gate_audit",
            "authoritative": False,
        }

    def audit_snapshot(self) -> dict[str, Any]:
        return _copy_json(self._audit()) if self.validate_integrity() else {}

    def _result(self, accepted: bool, error_code: str) -> ShadowMatchOwnerGateResult:
        audit = self._audit() if self.validate_integrity() else None
        return ShadowMatchOwnerGateResult._from_owner(self, accepted, error_code, audit)

    def begin_match(self, match_generation: Any, requested_mode: Any, broker: Any = None) -> ShadowMatchOwnerGateResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_gate")
        if not _positive(match_generation):
            return self._result(False, "invalid_match_generation")
        if type(requested_mode) is not str or requested_mode not in OWNER_MODES:
            return self._result(False, "invalid_mode")
        if self._state == "active":
            return self._result(False, "active_match_exists")
        if match_generation <= self._last_match_generation:
            return self._result(False, "stale_match_generation")
        forced = self._rollback_pending
        effective_mode = "legacy" if forced else requested_mode
        retained_broker: ShadowPromptBroker | None = None
        if not forced:
            if effective_mode == "legacy":
                if broker is not None:
                    return self._result(False, "broker_forbidden")
            else:
                if broker is None:
                    return self._result(False, "broker_required")
                if type(broker) is not ShadowPromptBroker or not broker.validate_integrity():
                    return self._result(False, "broker_invalid")
                if broker._match_generation != match_generation:
                    return self._result(False, "broker_match_generation_mismatch")
                retained_broker = broker
        if self._gate_generation >= SAFE_MAX:
            return self._result(False, "generation_exhausted")
        self._gate_generation += 1
        self._state = "active"
        self._match_generation = match_generation
        self._last_match_generation = match_generation
        self._active_mode = effective_mode
        self._active_broker = retained_broker
        self._rollback_pending = False
        self._rollback_applied = forced
        return self._result(True, "")

    def current_owner(self) -> ShadowMatchOwnerGateResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_gate")
        if self._state != "active":
            return self._result(False, "no_active_match")
        return self._result(True, "")

    def request_legacy_next_match(self, match_generation: Any) -> ShadowMatchOwnerGateResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_gate")
        if not _positive(match_generation):
            return self._result(False, "invalid_match_generation")
        if self._state != "active":
            return self._result(False, "no_active_match")
        if match_generation != self._match_generation:
            return self._result(False, "stale_match_generation")
        if self._rollback_pending:
            return self._result(False, "rollback_already_pending")
        if self._gate_generation >= SAFE_MAX:
            return self._result(False, "generation_exhausted")
        self._gate_generation += 1
        self._rollback_pending = True
        return self._result(True, "")

    def end_match(self, match_generation: Any) -> ShadowMatchOwnerGateResult:
        if not self.validate_integrity():
            return self._result(False, "invalid_gate")
        if not _positive(match_generation):
            return self._result(False, "invalid_match_generation")
        if self._state != "active":
            return self._result(False, "no_active_match")
        if match_generation != self._match_generation:
            return self._result(False, "stale_match_generation")
        if self._gate_generation >= SAFE_MAX:
            return self._result(False, "generation_exhausted")
        self._gate_generation += 1
        self._state = "between_matches"
        self._active_mode = None
        self._active_broker = None
        self._rollback_applied = False
        return self._result(True, "")
