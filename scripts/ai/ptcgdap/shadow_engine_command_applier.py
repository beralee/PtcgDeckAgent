from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any
import weakref

from scripts.ai.ptcgdap.godot_action_ticket import GodotActionTicket
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionResolution
from scripts.ai.ptcgdap.shadow_match_owner_gate import ShadowMatchOwnerGate
from scripts.ai.ptcgdap.shadow_prompt_broker import (
    ShadowPromptBroker,
    ShadowPromptBrokerResult,
    ShadowPromptHandle,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "shadow_engine_command_applier_bundle.json"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C"
PROFILE_ID = "ptcgdap-shadow-engine-command-applier-p3-wp7-v1"
SAFE_MAX = 9007199254740991
MAX_RESOLUTION_COUNT = 256
FACTORY_TOKEN = object()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_contracts() -> tuple[MappingProxyType[str, Any], frozenset[str], frozenset[str], bytes]:
    bundle = load_json_strict(BUNDLE_PATH)
    if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise RuntimeError("shadow engine command applier bundle trust-anchor mismatch")
    if type(bundle) is not dict or bundle.get("contract_id") != PROFILE_ID:
        raise RuntimeError("shadow engine command applier identity mismatch")
    expected = {
        "schema": "contracts/ptcgdap/shadow_engine_command_applier.schema.json",
        "profile": "contracts/ptcgdap/shadow_engine_command_applier_profile.json",
        "vectors": "contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json",
    }
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("shadow engine command applier artifact set mismatch")
    documents: dict[str, Any] = {}
    for entry in entries:
        if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
            raise RuntimeError("shadow engine command applier artifact entry mismatch")
        artifact_id = entry["id"]
        if artifact_id in documents or expected.get(artifact_id) != entry["path"]:
            raise RuntimeError("shadow engine command applier artifact identity mismatch")
        document = load_json_strict(ROOT / entry["path"])
        if _sha(canonical_json_v1_bytes(document)) != entry["canonical_sha256"]:
            raise RuntimeError("shadow engine command applier artifact hash mismatch")
        documents[artifact_id] = document
    if set(documents) != set(expected):
        raise RuntimeError("shadow engine command applier artifact set mismatch")
    profile = documents["profile"]
    if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("shadow engine command applier profile mismatch")
    states = profile.get("states")
    errors = profile.get("error_codes")
    protocol = profile.get("command_protocol")
    result_contract = profile.get("command_protocol_results")
    if states != ["ready", "executed", "aborted", "poisoned"]:
        raise RuntimeError("shadow engine command applier state domain mismatch")
    if type(errors) is not list or not errors or len(errors) != len(set(errors)):
        raise RuntimeError("shadow engine command applier error domain mismatch")
    if any(type(code) is not str or not code for code in errors):
        raise RuntimeError("shadow engine command applier error domain mismatch")
    if protocol != ["shadow_capture", "shadow_apply", "shadow_restore"]:
        raise RuntimeError("shadow engine command protocol mismatch")
    if result_contract != {
        "shadow_capture": {"argument_count": 0, "result_exact_object_keys": ["ok", "snapshot"], "ok_exact_boolean": True},
        "shadow_apply": {"argument_count": 0, "result_exact_boolean": True},
        "shadow_restore": {"argument_count": 1, "result_exact_boolean": True},
    }:
        raise RuntimeError("shadow engine command protocol result mismatch")
    if profile.get("limits") != {"max_execution_generation_per_applier": 1, "max_resolution_count": 256}:
        raise RuntimeError("shadow engine command applier limits mismatch")
    prefix_hex = profile.get("execution_hash", {}).get("domain_prefix_utf8_hex")
    if type(prefix_hex) is not str or not prefix_hex or len(prefix_hex) % 2:
        raise RuntimeError("shadow executed witness prefix mismatch")
    try:
        prefix = bytes.fromhex(prefix_hex)
    except ValueError as exc:
        raise RuntimeError("shadow executed witness prefix mismatch") from exc
    if prefix != b"PTCGDAP\0SHADOW_EXECUTED_WITNESS_V1\0":
        raise RuntimeError("shadow executed witness domain mismatch")
    return MappingProxyType(profile), frozenset(states), frozenset(errors), prefix


PROFILE, STATES, ERROR_CODES, EXECUTION_PREFIX = _load_contracts()


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) in (list, tuple):
        return [_copy_json(item) for item in value]
    return value


def _positive(value: Any) -> bool:
    return type(value) is int and 1 <= value <= SAFE_MAX


def _nonnegative(value: Any) -> bool:
    return type(value) is int and 0 <= value <= SAFE_MAX


def _upper_sha(value: Any) -> bool:
    return type(value) is str and len(value) == 64 and all(character in "0123456789ABCDEF" for character in value)


def _execution_id(payload: dict[str, Any]) -> str:
    return _sha(EXECUTION_PREFIX + canonical_json_v1_bytes(payload))


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class ShadowExecutedWitness:
    profile: str
    execution_id: str
    execution_generation: int
    match_generation: int
    broker_generation: int
    decision_generation: int
    snapshot_id: str
    window_id: str
    public_observation_hash: str
    chooser_player_index: int
    selected_indexes: tuple[int, ...]
    selected_fingerprint_hashes: tuple[str, ...]
    resolution_count: int
    state: str
    authority: str
    authoritative: bool
    _owner_ref: weakref.ReferenceType["ShadowEngineCommandApplier"]
    _broker_result: ShadowPromptBrokerResult
    _construction_seal: object
    _sealed_digest: str

    def __new__(cls) -> "ShadowExecutedWitness":
        raise TypeError("shadow executed witnesses must be owner-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "ShadowEngineCommandApplier",
        broker_result: ShadowPromptBrokerResult,
        payload_without_id: dict[str, Any],
    ) -> "ShadowExecutedWitness":
        witness = object.__new__(cls)
        public = {"execution_id": _execution_id(payload_without_id), **payload_without_id}
        values = {
            **public,
            "selected_indexes": tuple(public["selected_indexes"]),
            "selected_fingerprint_hashes": tuple(public["selected_fingerprint_hashes"]),
            "_owner_ref": weakref.ref(owner),
            "_broker_result": broker_result,
            "_construction_seal": FACTORY_TOKEN,
            "_sealed_digest": _sha(canonical_json_v1_bytes(public)),
        }
        for name, value in values.items():
            object.__setattr__(witness, name, value)
        return witness

    def validate_integrity(self, owner: "ShadowEngineCommandApplier") -> bool:
        return type(owner) is ShadowEngineCommandApplier and owner._witness_valid(self)

    def witness_snapshot(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        return owner._witness_public(self) if type(owner) is ShadowEngineCommandApplier and owner._witness_valid(self) else {}

    def to_public_dict(self) -> dict[str, Any]:
        return self.witness_snapshot()

    def to_dict(self) -> dict[str, Any]:
        return self.witness_snapshot()


@dataclass(frozen=True, slots=True, init=False)
class ShadowEngineApplyResult:
    accepted: bool
    error_code: str
    witness: ShadowExecutedWitness | None
    rolled_back: bool
    poisoned: bool
    _owner_ref: weakref.ReferenceType["ShadowEngineCommandApplier"]
    _construction_seal: object
    _sealed_digest: str

    def __new__(cls) -> "ShadowEngineApplyResult":
        raise TypeError("shadow engine apply results must be owner-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "ShadowEngineCommandApplier",
        accepted: bool,
        error_code: str,
        witness: ShadowExecutedWitness | None,
        rolled_back: bool,
        poisoned: bool,
    ) -> "ShadowEngineApplyResult":
        result = object.__new__(cls)
        public = {
            "accepted": accepted,
            "error_code": error_code,
            "witness": None if witness is None else witness.witness_snapshot(),
            "rolled_back": rolled_back,
            "poisoned": poisoned,
        }
        for name, value in {
            "accepted": accepted,
            "error_code": error_code,
            "witness": witness,
            "rolled_back": rolled_back,
            "poisoned": poisoned,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": FACTORY_TOKEN,
            "_sealed_digest": _sha(canonical_json_v1_bytes(public)),
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "ShadowEngineCommandApplier") -> bool:
        return type(owner) is ShadowEngineCommandApplier and owner._result_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not ShadowEngineCommandApplier or not owner._result_valid(self):
            return {
                "accepted": False,
                "error_code": "invalid_applier",
                "witness": None,
                "rolled_back": False,
                "poisoned": False,
            }
        return owner._result_public(self)

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


class ShadowEngineCommandApplier:
    __slots__ = (
        "__weakref__", "_gate", "_broker", "_state", "_execution_generation",
        "_applied_result", "_witness", "_construction_seal",
    )

    def __init__(self, gate: Any, broker: Any) -> None:
        self._gate = gate
        self._broker = broker
        self._state = "ready"
        self._execution_generation = 0
        self._applied_result: ShadowPromptBrokerResult | None = None
        self._witness: ShadowExecutedWitness | None = None
        self._construction_seal = FACTORY_TOKEN

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def validate_integrity(self) -> bool:
        if not self._structural_valid():
            return False
        if type(self._gate) is not ShadowMatchOwnerGate or type(self._broker) is not ShadowPromptBroker:
            return False
        if self._state == "executed":
            return self._witness_valid(self._witness)
        return True

    def audit_snapshot(self) -> dict[str, Any]:
        if not self._structural_valid():
            return {}
        match_generation = None
        if type(self._gate) is ShadowMatchOwnerGate:
            gate_audit = self._gate.audit_snapshot()
            match_generation = gate_audit.get("match_generation") if type(gate_audit) is dict else None
        return {
            "profile": PROFILE_ID,
            "state": self._state,
            "execution_generation": self._execution_generation,
            "match_generation": match_generation,
            "executed": self._state == "executed",
            "poisoned": self._state == "poisoned",
            "authority": "shadow_engine_command_applier_audit",
            "authoritative": False,
        }

    def apply(self, broker_result: Any) -> ShadowEngineApplyResult:
        if not self._structural_valid():
            return self._result(False, "invalid_applier")
        if self._state == "poisoned":
            return self._result(False, "rollback_failed", poisoned=True)
        if self._state != "ready":
            return self._result(False, "already_applied")
        code = self._authority_error()
        if code:
            return self._result(False, code)
        if not self._broker_result_base_valid(broker_result):
            return self._result(False, "invalid_broker_result")
        assert type(broker_result) is ShadowPromptBrokerResult
        prompt = broker_result.prompt
        assert type(prompt) is ShadowPromptHandle
        if prompt.state != "awaiting_reobserve":
            return self._result(False, "prompt_not_committed")
        if not self._committed_payload_valid(broker_result):
            return self._result(False, "invalid_broker_result")
        resolutions = broker_result.private_resolutions
        commands = tuple(resolution.private_engine_command for resolution in resolutions)
        if len(commands) > MAX_RESOLUTION_COUNT:
            self._state = "aborted"
            return self._result(False, "invalid_command")
        if any(command is prior for index, command in enumerate(commands) for prior in commands[:index]):
            self._state = "aborted"
            return self._result(False, "duplicate_command")
        if any(not self._command_protocol_valid(command) for command in commands):
            self._state = "aborted"
            return self._result(False, "invalid_command")
        captured: list[tuple[Any, Any]] = []
        for command in commands:
            if not self._command_protocol_valid(command):
                self._state = "aborted"
                return self._result(False, "invalid_command")
            try:
                capture = command.shadow_capture()
            except Exception:
                self._state = "aborted"
                return self._result(False, "capture_failed")
            if type(capture) is not dict or set(capture) != {"ok", "snapshot"} or type(capture["ok"]) is not bool:
                self._state = "aborted"
                return self._result(False, "capture_failed")
            if not capture["ok"]:
                self._state = "aborted"
                return self._result(False, "capture_failed")
            captured.append((command, capture["snapshot"]))

        apply_failed = False
        for command, _snapshot in captured:
            if not self._command_protocol_valid(command):
                apply_failed = True
                break
            try:
                applied = command.shadow_apply()
            except Exception:
                applied = False
            if type(applied) is not bool or not applied:
                apply_failed = True
                break
        if apply_failed:
            restored = True
            for command, snapshot in reversed(captured):
                if not self._command_protocol_valid(command):
                    restored = False
                    continue
                try:
                    restore_result = command.shadow_restore(snapshot)
                except Exception:
                    restore_result = False
                if type(restore_result) is not bool or not restore_result:
                    restored = False
            if restored:
                self._state = "aborted"
                return self._result(False, "command_apply_failed", rolled_back=True)
            self._state = "poisoned"
            return self._result(False, "rollback_failed", poisoned=True)

        self._execution_generation += 1
        self._state = "executed"
        self._applied_result = broker_result
        payload = self._witness_payload(broker_result)
        self._witness = ShadowExecutedWitness._from_owner(self, broker_result, payload)
        return self._result(True, "", witness=self._witness)

    def _authority_error(self) -> str:
        if type(self._gate) is not ShadowMatchOwnerGate or not self._gate.validate_integrity():
            return "invalid_gate"
        gate_audit = self._gate.audit_snapshot()
        if gate_audit.get("state") != "active" or gate_audit.get("active_mode") != "aligned_shadow":
            return "owner_mode_not_aligned"
        if type(self._broker) is not ShadowPromptBroker or not self._broker.validate_integrity():
            return "invalid_broker"
        if self._gate._active_broker is not self._broker:
            return "broker_not_current"
        if self._broker._match_generation != gate_audit.get("match_generation"):
            return "broker_not_current"
        return ""

    def _broker_result_base_valid(self, result: Any) -> bool:
        try:
            if (
                type(result) is not ShadowPromptBrokerResult
                or not result.accepted
                or result.error_code != ""
                or not result.validate_integrity(self._broker)
                or type(result.prompt) is not ShadowPromptHandle
                or result.prompt is not self._broker.current_prompt()
            ):
                return False
            return True
        except (AttributeError, TypeError, ValueError):
            return False

    def _committed_payload_valid(self, result: Any) -> bool:
        try:
            if not self._broker_result_base_valid(result):
                return False
            if (
                result.prompt.state != "awaiting_reobserve"
                or result.private_resolutions is not result.prompt._committed_resolutions
                or type(result.private_resolutions) is not tuple
            ):
                return False
            prompt = result.prompt
            claim = prompt._claim_result
            ticket_owner = prompt._ticket_owner
            if claim is None or ticket_owner is None or not claim.validate_integrity(ticket_owner):
                return False
            ticket = claim._ticket
            if type(ticket) is not GodotActionTicket or not ticket.validate_integrity(ticket_owner):
                return False
            if len(result.private_resolutions) != len(ticket.selected_indexes):
                return False
            if len(ticket.selected_indexes) != len(ticket.selected_fingerprint_hashes):
                return False
            for resolution, index, fingerprint in zip(
                result.private_resolutions,
                ticket.selected_indexes,
                ticket.selected_fingerprint_hashes,
                strict=True,
            ):
                if (
                    type(resolution) is not GodotOptionResolution
                    or not resolution.validate_integrity(prompt._binding_owner)
                    or resolution.option_index != index
                    or prompt._window.option_fingerprints[index] != fingerprint
                ):
                    return False
            return True
        except (AttributeError, IndexError, TypeError, ValueError):
            return False

    def _witness_payload(self, result: ShadowPromptBrokerResult) -> dict[str, Any]:
        prompt = result.prompt
        assert type(prompt) is ShadowPromptHandle and prompt._claim_result is not None
        ticket = prompt._claim_result._ticket
        assert type(ticket) is GodotActionTicket
        return {
            "profile": PROFILE_ID,
            "execution_generation": self._execution_generation,
            "match_generation": prompt.match_generation,
            "broker_generation": prompt.broker_generation,
            "decision_generation": prompt.decision_generation,
            "snapshot_id": prompt.snapshot_id,
            "window_id": prompt.window_id,
            "public_observation_hash": prompt.public_observation_hash,
            "chooser_player_index": prompt.chooser_player_index,
            "selected_indexes": list(ticket.selected_indexes),
            "selected_fingerprint_hashes": list(ticket.selected_fingerprint_hashes),
            "resolution_count": len(result.private_resolutions),
            "state": "executed",
            "authority": "shadow_executed_witness_audit",
            "authoritative": False,
        }

    def _witness_public(self, witness: ShadowExecutedWitness) -> dict[str, Any]:
        return {
            "profile": witness.profile,
            "execution_id": witness.execution_id,
            "execution_generation": witness.execution_generation,
            "match_generation": witness.match_generation,
            "broker_generation": witness.broker_generation,
            "decision_generation": witness.decision_generation,
            "snapshot_id": witness.snapshot_id,
            "window_id": witness.window_id,
            "public_observation_hash": witness.public_observation_hash,
            "chooser_player_index": witness.chooser_player_index,
            "selected_indexes": list(witness.selected_indexes),
            "selected_fingerprint_hashes": list(witness.selected_fingerprint_hashes),
            "resolution_count": witness.resolution_count,
            "state": witness.state,
            "authority": witness.authority,
            "authoritative": witness.authoritative,
        }

    def _witness_valid(self, witness: Any) -> bool:
        try:
            if (
                type(witness) is not ShadowExecutedWitness
                or witness._construction_seal is not FACTORY_TOKEN
                or witness._owner_ref() is not self
                or self._state != "executed"
                or self._witness is not witness
                or self._applied_result is not witness._broker_result
            ):
                return False
            public = self._witness_public(witness)
            payload = dict(public)
            execution_id = payload.pop("execution_id", None)
            if execution_id != _execution_id(payload):
                return False
            if witness.profile != PROFILE_ID or witness.state != "executed":
                return False
            if witness.authority != "shadow_executed_witness_audit" or witness.authoritative is not False:
                return False
            if not all(_positive(value) for value in (
                witness.execution_generation, witness.match_generation, witness.broker_generation,
                witness.decision_generation,
            )):
                return False
            if witness.execution_generation != self._execution_generation:
                return False
            if not all(_upper_sha(value) for value in (
                witness.execution_id, witness.snapshot_id, witness.window_id, witness.public_observation_hash,
            )):
                return False
            if type(witness.chooser_player_index) is not int or witness.chooser_player_index not in (0, 1):
                return False
            if type(witness.selected_indexes) is not tuple or any(not _nonnegative(value) for value in witness.selected_indexes):
                return False
            if len(set(witness.selected_indexes)) != len(witness.selected_indexes):
                return False
            if type(witness.selected_fingerprint_hashes) is not tuple or any(not _upper_sha(value) for value in witness.selected_fingerprint_hashes):
                return False
            if len(set(witness.selected_fingerprint_hashes)) != len(witness.selected_fingerprint_hashes):
                return False
            if witness.resolution_count != len(witness.selected_indexes) or witness.resolution_count != len(witness.selected_fingerprint_hashes):
                return False
            if witness.resolution_count != len(witness._broker_result.private_resolutions):
                return False
            expected = self._witness_payload(witness._broker_result)
            if payload != expected:
                return False
            return type(witness._sealed_digest) is str and _sha(canonical_json_v1_bytes(public)) == witness._sealed_digest
        except (AttributeError, TypeError, ValueError):
            return False

    def _structural_valid(self) -> bool:
        try:
            if (
                self._construction_seal is not FACTORY_TOKEN
                or self._state not in STATES
                or not _nonnegative(self._execution_generation)
            ):
                return False
            if self._state == "ready":
                return self._execution_generation == 0 and self._applied_result is None and self._witness is None
            if self._state == "executed":
                return self._execution_generation > 0 and type(self._applied_result) is ShadowPromptBrokerResult and type(self._witness) is ShadowExecutedWitness
            return self._execution_generation == 0 and self._applied_result is None and self._witness is None
        except (AttributeError, TypeError):
            return False

    @staticmethod
    def _command_protocol_valid(command: Any) -> bool:
        try:
            if command is None or type(command) in (bool, int, float, str, bytes, list, tuple, dict, set, frozenset):
                return False
            return all(callable(getattr(command, name, None)) for name in ("shadow_capture", "shadow_apply", "shadow_restore"))
        except Exception:
            return False

    def _result(
        self,
        accepted: bool,
        error_code: str,
        *,
        witness: ShadowExecutedWitness | None = None,
        rolled_back: bool = False,
        poisoned: bool = False,
    ) -> ShadowEngineApplyResult:
        return ShadowEngineApplyResult._from_owner(self, accepted, error_code, witness, rolled_back, poisoned)

    def _result_public(self, result: ShadowEngineApplyResult) -> dict[str, Any]:
        return {
            "accepted": result.accepted,
            "error_code": result.error_code,
            "witness": None if result.witness is None else result.witness.witness_snapshot(),
            "rolled_back": result.rolled_back,
            "poisoned": result.poisoned,
        }

    def _result_valid(self, result: Any) -> bool:
        try:
            if (
                type(result) is not ShadowEngineApplyResult
                or result._construction_seal is not FACTORY_TOKEN
                or result._owner_ref() is not self
                or type(result.accepted) is not bool
                or type(result.error_code) is not str
                or type(result.rolled_back) is not bool
                or type(result.poisoned) is not bool
            ):
                return False
            if result.accepted:
                if (
                    result.error_code != ""
                    or result.witness is not self._witness
                    or result.rolled_back
                    or result.poisoned
                    or not self._witness_valid(result.witness)
                ):
                    return False
            elif (
                result.error_code not in ERROR_CODES
                or result.witness is not None
                or result.poisoned != (result.error_code == "rollback_failed")
                or (result.rolled_back and result.error_code != "command_apply_failed")
            ):
                return False
            public = self._result_public(result)
            return type(result._sealed_digest) is str and _sha(canonical_json_v1_bytes(public)) == result._sealed_digest
        except (AttributeError, TypeError, ValueError):
            return False


__all__ = [
    "EXPECTED_BUNDLE_CANONICAL_SHA256",
    "ShadowEngineApplyResult",
    "ShadowEngineCommandApplier",
    "ShadowExecutedWitness",
]
