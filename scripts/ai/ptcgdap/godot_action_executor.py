from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any
import weakref

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort, EngineDecisionSnapshot
from scripts.ai.ptcgdap.godot_action_ticket import GodotActionClaimResult, GodotActionTicketOwner
from scripts.ai.ptcgdap.godot_option_binding import (
    GodotOptionBinding,
    GodotOptionBindingSet,
    GodotOptionResolution,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "godot_action_executor_bundle.json"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92"
PROFILE_ID = "ptcgdap-godot-action-executor-p3-wp4-v1"
SAFE_MAX = 9007199254740991
SHA_RE = re.compile(r"^[A-F0-9]{64}$")
_FACTORY_TOKEN = object()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_contracts() -> tuple[MappingProxyType[str, Any], bytes, frozenset[str], frozenset[str]]:
    bundle = load_json_strict(BUNDLE_PATH)
    if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise RuntimeError("action executor bundle trust-anchor mismatch")
    if type(bundle) is not dict or bundle.get("contract_id") != PROFILE_ID:
        raise RuntimeError("action executor bundle identity mismatch")
    expected = {
        "schema": "contracts/ptcgdap/godot_action_executor.schema.json",
        "profile": "contracts/ptcgdap/godot_action_executor_profile.json",
        "vectors": "contracts/ptcgdap/godot_action_executor_conformance_vectors.json",
    }
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("action executor artifact set mismatch")
    documents: dict[str, Any] = {}
    seen: set[str] = set()
    for entry in entries:
        if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
            raise RuntimeError("action executor artifact entry mismatch")
        artifact_id = entry["id"]
        if type(artifact_id) is not str or artifact_id in seen or expected.get(artifact_id) != entry["path"]:
            raise RuntimeError("action executor artifact identity mismatch")
        document = load_json_strict(ROOT / entry["path"])
        if _sha(canonical_json_v1_bytes(document)) != entry["canonical_sha256"]:
            raise RuntimeError("action executor artifact hash mismatch")
        documents[artifact_id] = document
        seen.add(artifact_id)
    if seen != set(expected):
        raise RuntimeError("action executor artifact set mismatch")
    profile = documents["profile"]
    if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("action executor profile mismatch")
    prefix_hex = profile.get("hash_profile", {}).get("prefix_utf8_hex")
    if type(prefix_hex) is not str or not prefix_hex or len(prefix_hex) % 2 or prefix_hex != prefix_hex.upper():
        raise RuntimeError("action executor prefix mismatch")
    try:
        prefix = bytes.fromhex(prefix_hex)
    except ValueError as exc:
        raise RuntimeError("action executor prefix mismatch") from exc
    if prefix != b"PTCGDAP\0GODOT_ACTION_EXECUTOR_V1\0":
        raise RuntimeError("action executor prefix mismatch")
    preflight = profile.get("preflight_error_codes")
    commit = profile.get("commit_error_codes")
    if (
        type(preflight) is not list
        or type(commit) is not list
        or not preflight
        or not commit
        or any(type(code) is not str or not code for code in preflight + commit)
        or len(preflight) != len(set(preflight))
        or len(commit) != len(set(commit))
    ):
        raise RuntimeError("action executor error domain mismatch")
    return MappingProxyType(profile), prefix, frozenset(preflight), frozenset(commit)


_PROFILE, _PREFLIGHT_PREFIX, _PREFLIGHT_CODES, _COMMIT_CODES = _load_contracts()


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) in (list, tuple):
        return [_copy_json(item) for item in value]
    return value


def _upper_sha(value: Any) -> bool:
    return type(value) is str and SHA_RE.fullmatch(value) is not None


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class GodotPreparedActionBatch:
    preflight_id: str
    preflight_generation: int
    state: str
    _owner_ref: weakref.ReferenceType["GodotActionExecutor"]
    _ticket_owner: GodotActionTicketOwner
    _claim_result: GodotActionClaimResult
    _binding_owner: GodotOptionBinding
    _binding: GodotOptionBindingSet
    _port: EngineDecisionPort
    _snapshot: EngineDecisionSnapshot
    _current_source: Any
    _window: CabtSelectionWindow
    _callback_hash: str
    _resolutions: tuple[GodotOptionResolution, ...]
    _construction_seal: object

    def __new__(cls) -> "GodotPreparedActionBatch":
        raise TypeError("prepared action batches must be executor-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "GodotActionExecutor",
        generation: int,
        ticket_owner: GodotActionTicketOwner,
        claim_result: GodotActionClaimResult,
        binding_owner: GodotOptionBinding,
        binding: GodotOptionBindingSet,
        port: EngineDecisionPort,
        snapshot: EngineDecisionSnapshot,
        current_source: Any,
        window: CabtSelectionWindow,
        callback_hash: str,
    ) -> "GodotPreparedActionBatch":
        ticket = claim_result._ticket
        assert ticket is not None
        payload = {
            "profile": PROFILE_ID,
            "preflight_generation": generation,
            "ticket_id": ticket.ticket_id,
            "ticket_generation": ticket.ticket_generation,
            "binding_version": binding.binding_version,
            "snapshot_id": snapshot.snapshot_id,
            "window_id": window.window_id,
            "public_observation_hash": window.public_observation_hash,
            "chooser_player_index": window.chooser_player_index,
            "selected_indexes": list(ticket.selected_indexes),
            "selected_fingerprint_hashes": list(ticket.selected_fingerprint_hashes),
            "resolution_count": len(claim_result.binding_resolutions),
        }
        result = object.__new__(cls)
        for name, value in {
            "preflight_id": _sha(_PREFLIGHT_PREFIX + canonical_json_v1_bytes(payload)),
            "preflight_generation": generation,
            "state": "prepared",
            "_owner_ref": weakref.ref(owner),
            "_ticket_owner": ticket_owner,
            "_claim_result": claim_result,
            "_binding_owner": binding_owner,
            "_binding": binding,
            "_port": port,
            "_snapshot": snapshot,
            "_current_source": current_source,
            "_window": window,
            "_callback_hash": callback_hash,
            "_resolutions": tuple(claim_result.binding_resolutions),
            "_construction_seal": _FACTORY_TOKEN,
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "GodotActionExecutor") -> bool:
        return type(owner) is GodotActionExecutor and owner._batch_fields_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        return owner._audit(self) if type(owner) is GodotActionExecutor and owner._batch_fields_valid(self) else {}

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False)
class GodotActionPreflightResult:
    accepted: bool
    error_code: str
    preflight: GodotPreparedActionBatch | None
    _owner_ref: weakref.ReferenceType["GodotActionExecutor"]
    _construction_seal: object

    def __new__(cls) -> "GodotActionPreflightResult":
        raise TypeError("preflight results must be executor-created")

    @classmethod
    def _from_owner(cls, owner: "GodotActionExecutor", accepted: bool, code: str, batch: GodotPreparedActionBatch | None) -> "GodotActionPreflightResult":
        result = object.__new__(cls)
        for name, value in {
            "accepted": accepted,
            "error_code": code,
            "preflight": batch,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": _FACTORY_TOKEN,
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "GodotActionExecutor") -> bool:
        return type(owner) is GodotActionExecutor and owner._preflight_result_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not GodotActionExecutor or not owner._preflight_result_valid(self):
            return {}
        return {"accepted": self.accepted, "error_code": self.error_code, "audit": None if self.preflight is None else self.preflight.to_public_dict()}

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False)
class GodotActionCommitResult:
    accepted: bool
    error_code: str
    binding_resolutions: tuple[GodotOptionResolution, ...]
    _preflight: GodotPreparedActionBatch | None
    _owner_ref: weakref.ReferenceType["GodotActionExecutor"]
    _construction_seal: object

    def __new__(cls) -> "GodotActionCommitResult":
        raise TypeError("commit results must be executor-created")

    @classmethod
    def _from_owner(cls, owner: "GodotActionExecutor", accepted: bool, code: str, batch: GodotPreparedActionBatch | None, resolutions: tuple[GodotOptionResolution, ...] = ()) -> "GodotActionCommitResult":
        result = object.__new__(cls)
        for name, value in {
            "accepted": accepted,
            "error_code": code,
            "binding_resolutions": tuple(resolutions),
            "_preflight": batch,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": _FACTORY_TOKEN,
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "GodotActionExecutor") -> bool:
        return type(owner) is GodotActionExecutor and owner._commit_result_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not GodotActionExecutor or not owner._commit_result_valid(self):
            return {}
        return {
            "accepted": self.accepted,
            "error_code": self.error_code,
            "audit": self._preflight.to_public_dict() if self.accepted and self._preflight is not None else None,
        }

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


class GodotActionExecutor:
    def __init__(self) -> None:
        self._next_generation = 1
        self._active: GodotPreparedActionBatch | None = None
        self._construction_seal = _FACTORY_TOKEN

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def validate_integrity(self) -> bool:
        try:
            return (
                self._construction_seal is _FACTORY_TOKEN
                and type(self._next_generation) is int
                and 1 <= self._next_generation <= SAFE_MAX + 1
                and (
                    self._active is None
                    or (
                        type(self._active) is GodotPreparedActionBatch
                        and type(self._active._owner_ref) is weakref.ReferenceType
                        and self._active._owner_ref() is self
                    )
                )
            )
        except (AttributeError, TypeError, ValueError):
            return False

    def current_preflight(self) -> GodotPreparedActionBatch | None:
        return self._active if self._active is not None and self._active.state == "prepared" and self._batch_fields_valid(self._active) else None

    def prepare(
        self,
        *,
        ticket_owner: Any,
        claim_result: Any,
        binding_owner: Any,
        binding: Any,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
    ) -> GodotActionPreflightResult:
        if not self.validate_integrity():
            return self._preflight_reject("executor_integrity_invalid")
        if self._active is not None and self._active.state == "prepared":
            return self._preflight_reject("active_preflight_exists")
        if self._next_generation > SAFE_MAX:
            return self._preflight_reject("preflight_space_exhausted")
        code, _ = self._context_error(
            ticket_owner, claim_result, binding_owner, binding, port, snapshot,
            current_source, window, callback_binding_hash,
        )
        if code:
            return self._preflight_reject(code)
        batch = GodotPreparedActionBatch._from_owner(
            self, self._next_generation, ticket_owner, claim_result, binding_owner,
            binding, port, snapshot, current_source, window, callback_binding_hash,
        )
        self._next_generation += 1
        self._active = batch
        return GodotActionPreflightResult._from_owner(self, True, "", batch)

    def commit(
        self,
        preflight: Any,
        *,
        ticket_owner: Any,
        binding_owner: Any,
        binding: Any,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
    ) -> GodotActionCommitResult:
        if not self.validate_integrity():
            return self._commit_reject("executor_integrity_invalid")
        if type(preflight) is not GodotPreparedActionBatch:
            return self._commit_reject("invalid_preflight")
        owner = preflight._owner_ref() if type(preflight._owner_ref) is weakref.ReferenceType else None
        if owner is not self:
            return self._commit_reject("owner_mismatch")
        if not self._batch_fields_valid(preflight):
            return self._commit_reject("preflight_integrity_invalid")
        if preflight.state == "committed":
            return self._commit_reject("already_committed", preflight)
        if preflight.state == "aborted":
            return self._commit_reject("preflight_aborted", preflight)
        if preflight is not self._active:
            return self._commit_reject("preflight_not_current")
        code, current = self._context_error(
            ticket_owner, preflight._claim_result, binding_owner, binding, port,
            snapshot, current_source, window, callback_binding_hash,
        )
        if code:
            object.__setattr__(preflight, "state", "aborted")
            mapped = code if code in {"private_resolution_invalid", "private_reference_unavailable"} else "commit_context_changed"
            return self._commit_reject(mapped, preflight)
        if current != preflight._resolutions:
            object.__setattr__(preflight, "state", "aborted")
            return self._commit_reject("private_resolution_invalid", preflight)
        object.__setattr__(preflight, "state", "committed")
        return GodotActionCommitResult._from_owner(self, True, "", preflight, preflight._resolutions)

    def abort(self, preflight: Any) -> bool:
        if (
            not self.validate_integrity()
            or type(preflight) is not GodotPreparedActionBatch
            or preflight is not self._active
            or not self._batch_fields_valid(preflight)
            or preflight.state != "prepared"
        ):
            return False
        object.__setattr__(preflight, "state", "aborted")
        return True

    def _context_error(
        self,
        ticket_owner: Any,
        claim: Any,
        binding_owner: Any,
        binding: Any,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_hash: Any,
    ) -> tuple[str, tuple[GodotOptionResolution, ...]]:
        if type(ticket_owner) is not GodotActionTicketOwner:
            return "invalid_ticket_owner", ()
        if type(claim) is not GodotActionClaimResult:
            return "invalid_claim_result", ()
        if not claim.accepted:
            return "claim_not_accepted", ()
        ticket = getattr(claim, "_ticket", None)
        if ticket is None or getattr(claim, "_owner_ref", lambda: None)() is not ticket_owner:
            return "invalid_claim_result", ()
        if type(claim.binding_resolutions) is not tuple:
            return "invalid_claim_result", ()
        indexes = tuple(getattr(item, "option_index", None) for item in claim.binding_resolutions)
        if indexes != ticket.selected_indexes:
            return "selection_mismatch", ()
        if type(binding_owner) is not GodotOptionBinding:
            return "invalid_binding_owner", ()
        if binding_owner is not ticket._binding_owner or binding is not ticket._binding or binding_owner.current_binding() is not binding:
            return "binding_not_current", ()
        if port is not ticket._port or snapshot is not ticket._snapshot or port.current_snapshot() is not snapshot:
            return "snapshot_not_current", ()
        if window is not ticket._window:
            return "window_not_current", ()
        if type(callback_hash) is not str or callback_hash != ticket._callback_binding_hash:
            return "callback_mismatch", ()
        if any(type(item) is not GodotOptionResolution for item in claim.binding_resolutions):
            return "private_resolution_invalid", ()
        if any(not item.accepted or item.private_engine_command is None for item in claim.binding_resolutions):
            return "private_reference_unavailable", ()
        current: list[GodotOptionResolution] = []
        for expected, index in zip(claim.binding_resolutions, ticket.selected_indexes, strict=True):
            resolved = binding_owner.resolve(
                binding=binding,
                port=port,
                snapshot=snapshot,
                current_source=current_source,
                window=window,
                callback_binding_hash=callback_hash,
                option_index=index,
            )
            if not resolved.accepted:
                code = "private_reference_unavailable" if resolved.error_code == "reference_released" else "binding_not_current"
                return code, ()
            if not resolved.validate_integrity(binding_owner):
                return "private_resolution_invalid", ()
            if (
                expected.option_index != resolved.option_index
                or expected.private_engine_command is not resolved.private_engine_command
                or len(expected.private_object_refs) != len(resolved.private_object_refs)
                or any(left is not right for left, right in zip(expected.private_object_refs, resolved.private_object_refs, strict=True))
            ):
                return "private_resolution_invalid", ()
            current.append(expected)
        if not claim.validate_integrity(ticket_owner):
            return "private_resolution_invalid", ()
        return "", tuple(current)

    def _batch_fields_valid(self, batch: Any) -> bool:
        try:
            if (
                type(batch) is not GodotPreparedActionBatch
                or batch._construction_seal is not _FACTORY_TOKEN
                or batch._owner_ref() is not self
                or not _upper_sha(batch.preflight_id)
                or type(batch.preflight_generation) is not int
                or not 1 <= batch.preflight_generation <= SAFE_MAX
                or batch.state not in {"prepared", "committed", "aborted"}
                or type(batch._ticket_owner) is not GodotActionTicketOwner
                or type(batch._claim_result) is not GodotActionClaimResult
                or type(batch._binding_owner) is not GodotOptionBinding
                or type(batch._binding) is not GodotOptionBindingSet
                or type(batch._port) is not EngineDecisionPort
                or type(batch._snapshot) is not EngineDecisionSnapshot
                or type(batch._window) is not CabtSelectionWindow
                or not _upper_sha(batch._callback_hash)
                or type(batch._resolutions) is not tuple
            ):
                return False
            ticket = batch._claim_result._ticket
            if ticket is None or batch._claim_result._owner_ref() is not batch._ticket_owner:
                return False
            payload = {
                "profile": PROFILE_ID,
                "preflight_generation": batch.preflight_generation,
                "ticket_id": ticket.ticket_id,
                "ticket_generation": ticket.ticket_generation,
                "binding_version": batch._binding.binding_version,
                "snapshot_id": batch._snapshot.snapshot_id,
                "window_id": batch._window.window_id,
                "public_observation_hash": batch._window.public_observation_hash,
                "chooser_player_index": batch._window.chooser_player_index,
                "selected_indexes": list(ticket.selected_indexes),
                "selected_fingerprint_hashes": list(ticket.selected_fingerprint_hashes),
                "resolution_count": len(batch._resolutions),
            }
            return (
                batch.preflight_id == _sha(_PREFLIGHT_PREFIX + canonical_json_v1_bytes(payload))
                and batch._resolutions == batch._claim_result.binding_resolutions
            )
        except (AttributeError, TypeError, ValueError):
            return False

    def _audit(self, batch: GodotPreparedActionBatch) -> dict[str, Any]:
        ticket = batch._claim_result._ticket
        assert ticket is not None
        return {
            "executor_profile": PROFILE_ID,
            "preflight_id": batch.preflight_id,
            "preflight_generation": batch.preflight_generation,
            "ticket_id": ticket.ticket_id,
            "ticket_generation": ticket.ticket_generation,
            "binding_version": batch._binding.binding_version,
            "snapshot_id": batch._snapshot.snapshot_id,
            "window_id": batch._window.window_id,
            "public_observation_hash": batch._window.public_observation_hash,
            "chooser_player_index": batch._window.chooser_player_index,
            "selected_indexes": list(ticket.selected_indexes),
            "selected_fingerprint_hashes": list(ticket.selected_fingerprint_hashes),
            "resolution_count": len(batch._resolutions),
            "state": batch.state,
            "authority": "godot_action_executor_shadow",
            "authoritative": False,
        }

    def _preflight_result_valid(self, result: Any) -> bool:
        try:
            if (
                type(result) is not GodotActionPreflightResult
                or result._construction_seal is not _FACTORY_TOKEN
                or result._owner_ref() is not self
                or type(result.accepted) is not bool
                or type(result.error_code) is not str
            ):
                return False
            if result.accepted:
                return result.error_code == "" and result.preflight is self._active and self._batch_fields_valid(result.preflight)
            return result.error_code in _PREFLIGHT_CODES and result.preflight is None
        except (AttributeError, TypeError):
            return False

    def _commit_result_valid(self, result: Any) -> bool:
        try:
            if (
                type(result) is not GodotActionCommitResult
                or result._construction_seal is not _FACTORY_TOKEN
                or result._owner_ref() is not self
                or type(result.accepted) is not bool
                or type(result.error_code) is not str
                or type(result.binding_resolutions) is not tuple
            ):
                return False
            if result.accepted:
                return (
                    result.error_code == ""
                    and result._preflight is self._active
                    and result._preflight.state == "committed"
                    and result.binding_resolutions == result._preflight._resolutions
                    and self._batch_fields_valid(result._preflight)
                )
            return result.error_code in _COMMIT_CODES and not result.binding_resolutions and (result._preflight is None or self._batch_fields_valid(result._preflight))
        except (AttributeError, TypeError):
            return False

    def _preflight_reject(self, code: str) -> GodotActionPreflightResult:
        return GodotActionPreflightResult._from_owner(self, False, code, None)

    def _commit_reject(self, code: str, batch: GodotPreparedActionBatch | None = None) -> GodotActionCommitResult:
        return GodotActionCommitResult._from_owner(self, False, code, batch)


__all__ = [
    "GodotPreparedActionBatch",
    "GodotActionPreflightResult",
    "GodotActionCommitResult",
    "GodotActionExecutor",
]
