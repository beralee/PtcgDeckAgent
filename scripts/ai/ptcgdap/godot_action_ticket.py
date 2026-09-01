from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any
import weakref

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionResolution, CabtSelectionWindow
from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort, EngineDecisionSnapshot
from scripts.ai.ptcgdap.godot_option_binding import (
    GodotOptionBinding,
    GodotOptionBindingSet,
    GodotOptionResolution,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "godot_action_ticket_bundle.json"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED"
PROFILE_ID = "ptcgdap-godot-action-ticket-p3-wp3-v1"
SAFE_MAX = 9007199254740991
SESSION_RE = re.compile(r"^session:[a-z0-9_-]{1,64}$")
SHA_RE = re.compile(r"^[A-F0-9]{64}$")
_FACTORY_TOKEN = object()


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _load_contracts() -> tuple[MappingProxyType[str, Any], bytes, frozenset[str]]:
    bundle = load_json_strict(BUNDLE_PATH)
    if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise RuntimeError("action ticket bundle trust-anchor mismatch")
    if type(bundle) is not dict or bundle.get("contract_id") != PROFILE_ID:
        raise RuntimeError("action ticket bundle identity mismatch")
    expected = {
        "schema": "contracts/ptcgdap/godot_action_ticket.schema.json",
        "profile": "contracts/ptcgdap/godot_action_ticket_profile.json",
        "vectors": "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json",
    }
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("action ticket artifact set mismatch")
    documents: dict[str, Any] = {}
    seen: set[str] = set()
    for entry in entries:
        if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
            raise RuntimeError("action ticket artifact entry mismatch")
        artifact_id = entry["id"]
        if type(artifact_id) is not str or artifact_id in seen or expected.get(artifact_id) != entry["path"]:
            raise RuntimeError("action ticket artifact identity mismatch")
        path = ROOT / entry["path"]
        document = load_json_strict(path)
        if _sha(canonical_json_v1_bytes(document)) != entry["canonical_sha256"]:
            raise RuntimeError("action ticket artifact hash mismatch")
        documents[artifact_id] = document
        seen.add(artifact_id)
    if seen != set(expected):
        raise RuntimeError("action ticket artifact set mismatch")
    profile = documents["profile"]
    if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("action ticket profile mismatch")
    prefix_hex = profile.get("hash_profile", {}).get("prefix_utf8_hex")
    if type(prefix_hex) is not str or not prefix_hex or len(prefix_hex) % 2 or prefix_hex != prefix_hex.upper():
        raise RuntimeError("action ticket prefix mismatch")
    try:
        prefix = bytes.fromhex(prefix_hex)
    except ValueError as exc:
        raise RuntimeError("action ticket prefix mismatch") from exc
    if prefix != b"PTCGDAP\0GODOT_ACTION_TICKET_V1\0":
        raise RuntimeError("action ticket prefix mismatch")
    codes = profile.get("error_codes")
    if type(codes) is not list or not codes or any(type(code) is not str for code in codes) or len(codes) != len(set(codes)):
        raise RuntimeError("action ticket error domain mismatch")
    return MappingProxyType(profile), prefix, frozenset(codes)


_PROFILE, _TICKET_PREFIX, _ERROR_CODES = _load_contracts()


def _deep_copy(value: Any) -> Any:
    if type(value) is dict:
        return {key: _deep_copy(item) for key, item in value.items()}
    if type(value) is list:
        return [_deep_copy(item) for item in value]
    if type(value) is tuple:
        return [_deep_copy(item) for item in value]
    return value


def _session(value: Any) -> bool:
    return type(value) is str and SESSION_RE.fullmatch(value) is not None


def _upper_sha(value: Any) -> bool:
    return type(value) is str and SHA_RE.fullmatch(value) is not None


def _ticket_hash(
    generation: int,
    session_id: str,
    callback_hash: str,
    binding_version: int,
    snapshot_id: str,
    window_id: str,
    public_hash: str,
    indexes: tuple[int, ...],
    fingerprints: tuple[str, ...],
) -> str:
    payload = {
        "profile": PROFILE_ID,
        "ticket_generation": generation,
        "session_id": session_id,
        "callback_binding_hash": callback_hash,
        "binding_version": binding_version,
        "snapshot_id": snapshot_id,
        "window_id": window_id,
        "public_observation_hash": public_hash,
        "selected_indexes": list(indexes),
        "selected_fingerprint_hashes": list(fingerprints),
    }
    return _sha(_TICKET_PREFIX + canonical_json_v1_bytes(payload))


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class GodotActionTicket:
    ticket_id: str
    ticket_generation: int
    binding_version: int
    snapshot_id: str
    window_id: str
    public_observation_hash: str
    selected_indexes: tuple[int, ...]
    selected_fingerprint_hashes: tuple[str, ...]
    _session_id: str
    _callback_binding_hash: str
    _binding_owner: GodotOptionBinding
    _binding: GodotOptionBindingSet
    _port: EngineDecisionPort
    _snapshot: EngineDecisionSnapshot
    _window: CabtSelectionWindow
    _selection_resolution: CabtSelectionResolution
    _owner_ref: weakref.ReferenceType["GodotActionTicketOwner"]
    _construction_seal: object
    _public_snapshot: dict[str, Any]

    def __new__(cls) -> "GodotActionTicket":
        raise TypeError("GodotActionTicket instances must be owner-created")

    @classmethod
    def _from_owner(
        cls,
        *,
        owner: "GodotActionTicketOwner",
        generation: int,
        session_id: str,
        callback_hash: str,
        binding_owner: GodotOptionBinding,
        binding: GodotOptionBindingSet,
        port: EngineDecisionPort,
        snapshot: EngineDecisionSnapshot,
        window: CabtSelectionWindow,
        selection_resolution: CabtSelectionResolution,
        token: object,
    ) -> "GodotActionTicket":
        if token is not _FACTORY_TOKEN:
            raise TypeError("GodotActionTicket construction is owner-only")
        indexes = tuple(selection_resolution.selected_indexes)
        fingerprints = tuple(window.option_fingerprints[index] for index in indexes)
        ticket_id = _ticket_hash(
            generation,
            session_id,
            callback_hash,
            binding.binding_version,
            snapshot.snapshot_id,
            window.window_id,
            window.public_observation_hash,
            indexes,
            fingerprints,
        )
        result = object.__new__(cls)
        fields = {
            "ticket_id": ticket_id,
            "ticket_generation": generation,
            "binding_version": binding.binding_version,
            "snapshot_id": snapshot.snapshot_id,
            "window_id": window.window_id,
            "public_observation_hash": window.public_observation_hash,
            "selected_indexes": indexes,
            "selected_fingerprint_hashes": fingerprints,
            "_session_id": session_id,
            "_callback_binding_hash": callback_hash,
            "_binding_owner": binding_owner,
            "_binding": binding,
            "_port": port,
            "_snapshot": snapshot,
            "_window": window,
            "_selection_resolution": selection_resolution,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": token,
        }
        for name, value in fields.items():
            object.__setattr__(result, name, value)
        object.__setattr__(result, "_public_snapshot", owner._ticket_audit(result))
        return result

    def validate_integrity(self, owner: "GodotActionTicketOwner") -> bool:
        return type(owner) is GodotActionTicketOwner and owner._ticket_fields_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not GodotActionTicketOwner or not owner._ticket_fields_valid(self):
            return {}
        return _deep_copy(self._public_snapshot)

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False)
class GodotActionTicketIssueResult:
    accepted: bool
    error_code: str
    ticket: GodotActionTicket | None
    _owner_ref: weakref.ReferenceType["GodotActionTicketOwner"]
    _construction_seal: object
    _public_snapshot: dict[str, Any]

    def __new__(cls) -> "GodotActionTicketIssueResult":
        raise TypeError("ticket issue results must be owner-created")

    @classmethod
    def _from_owner(cls, owner: "GodotActionTicketOwner", accepted: bool, code: str, ticket: GodotActionTicket | None) -> "GodotActionTicketIssueResult":
        result = object.__new__(cls)
        for name, value in {
            "accepted": accepted,
            "error_code": code,
            "ticket": ticket,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": _FACTORY_TOKEN,
            "_public_snapshot": {"accepted": accepted, "error_code": code, "audit": None if ticket is None else ticket.to_public_dict()},
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "GodotActionTicketOwner") -> bool:
        return owner._issue_result_valid(self) if type(owner) is GodotActionTicketOwner else False

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        return _deep_copy(self._public_snapshot) if type(owner) is GodotActionTicketOwner and owner._issue_result_valid(self) else {}

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False)
class GodotActionClaimResult:
    accepted: bool
    error_code: str
    binding_resolutions: tuple[GodotOptionResolution, ...]
    _ticket: GodotActionTicket | None
    _owner_ref: weakref.ReferenceType["GodotActionTicketOwner"]
    _construction_seal: object
    _public_snapshot: dict[str, Any]

    def __new__(cls) -> "GodotActionClaimResult":
        raise TypeError("ticket claim results must be owner-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "GodotActionTicketOwner",
        accepted: bool,
        code: str,
        ticket: GodotActionTicket | None,
        resolutions: tuple[GodotOptionResolution, ...] = (),
    ) -> "GodotActionClaimResult":
        audit = owner._claim_audit(ticket) if accepted and ticket is not None else None
        result = object.__new__(cls)
        for name, value in {
            "accepted": accepted,
            "error_code": code,
            "binding_resolutions": tuple(resolutions),
            "_ticket": ticket,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": _FACTORY_TOKEN,
            "_public_snapshot": {"accepted": accepted, "error_code": code, "audit": audit},
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "GodotActionTicketOwner") -> bool:
        return owner._claim_result_valid(self) if type(owner) is GodotActionTicketOwner else False

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        return _deep_copy(self._public_snapshot) if type(owner) is GodotActionTicketOwner and owner._claim_result_valid(self) else {}

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


class GodotActionTicketOwner:
    def __init__(self) -> None:
        self._next_generation = 1
        self._ticket: GodotActionTicket | None = None
        self._state = "none"
        self._closed_bindings: list[weakref.ReferenceType[GodotOptionBindingSet]] = []
        self._construction_seal = _FACTORY_TOKEN

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def validate_integrity(self) -> bool:
        try:
            if (
                self._construction_seal is not _FACTORY_TOKEN
                or type(self._next_generation) is not int
                or not 1 <= self._next_generation <= SAFE_MAX + 1
                or self._state not in {"none", "issued", "claimed", "revoked"}
                or type(self._closed_bindings) is not list
                or any(type(item) is not weakref.ReferenceType for item in self._closed_bindings)
            ):
                return False
            if self._ticket is None:
                return self._state == "none"
            return type(self._ticket) is GodotActionTicket and self._ticket_fields_valid(self._ticket)
        except (AttributeError, TypeError, ValueError):
            return False

    def current_ticket(self) -> GodotActionTicket | None:
        return self._ticket if self._state == "issued" and self._ticket_fields_valid(self._ticket) else None

    def issue(
        self,
        *,
        session_id: Any,
        public_observation_hash: Any,
        binding_owner: Any,
        binding: Any,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
        selection_resolution: Any,
    ) -> GodotActionTicketIssueResult:
        if not self.validate_integrity():
            return self._issue_reject("ticket_integrity_invalid")
        if not _session(session_id):
            return self._issue_reject("invalid_session_id")
        if not _upper_sha(public_observation_hash):
            return self._issue_reject("invalid_public_observation_hash")
        if type(binding_owner) is not GodotOptionBinding:
            return self._issue_reject("invalid_binding_owner")
        if type(binding) is not GodotOptionBindingSet:
            return self._issue_reject("invalid_binding")
        if type(window) is not CabtSelectionWindow:
            return self._issue_reject("binding_not_current")
        current_state = getattr(binding_owner, "_current", None)
        if (
            binding_owner.current_binding() is not binding
            or current_state is None
            or getattr(current_state, "binding", None) is not binding
            or getattr(current_state, "port", None) is not port
            or getattr(current_state, "snapshot", None) is not snapshot
            or getattr(current_state, "window", None) is not window
            or getattr(current_state, "callback_binding_hash", None) != callback_binding_hash
            or port.current_snapshot() is not snapshot
        ):
            return self._issue_reject("binding_not_current")
        if not binding_owner._binding_static_fields_valid(binding):
            return self._issue_reject("invalid_binding")
        if type(selection_resolution) is not CabtSelectionResolution or not selection_resolution.validate_integrity(window):
            return self._issue_reject("invalid_selection_resolution")
        if public_observation_hash != window.public_observation_hash:
            return self._issue_reject("public_hash_mismatch")
        if not _upper_sha(callback_binding_hash):
            return self._issue_reject("invalid_callback_binding_hash")
        indexes = tuple(selection_resolution.selected_indexes)
        resolved, code = self._resolve_context(
            binding_owner=binding_owner,
            binding=binding,
            port=port,
            snapshot=snapshot,
            current_source=current_source,
            window=window,
            callback_hash=callback_binding_hash,
            indexes=indexes,
        )
        if code:
            return self._issue_reject(code)
        if self._binding_closed(binding):
            return self._issue_reject("binding_already_claimed")
        if self._state == "issued" and self._ticket is not None:
            current = self._ticket
            if current._binding is binding:
                if (
                    current._session_id == session_id
                    and current.public_observation_hash == public_observation_hash
                    and current._callback_binding_hash == callback_binding_hash
                    and current._port is port
                    and current._snapshot is snapshot
                    and current._window is window
                    and current._selection_resolution is selection_resolution
                    and current.selected_indexes == indexes
                ):
                    return GodotActionTicketIssueResult._from_owner(self, True, "", current)
                return self._issue_reject("active_ticket_exists")
            self._close_binding(current._binding)
            self._state = "revoked"
        if self._next_generation > SAFE_MAX:
            return self._issue_reject("ticket_space_exhausted")
        ticket = GodotActionTicket._from_owner(
            owner=self,
            generation=self._next_generation,
            session_id=session_id,
            callback_hash=callback_binding_hash,
            binding_owner=binding_owner,
            binding=binding,
            port=port,
            snapshot=snapshot,
            window=window,
            selection_resolution=selection_resolution,
            token=_FACTORY_TOKEN,
        )
        self._next_generation += 1
        self._ticket = ticket
        self._state = "issued"
        return GodotActionTicketIssueResult._from_owner(self, True, "", ticket)

    def claim(
        self,
        *,
        ticket: Any,
        session_id: Any,
        public_observation_hash: Any,
        binding_owner: Any,
        binding: Any,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
    ) -> GodotActionClaimResult:
        if type(ticket) is not GodotActionTicket:
            return self._claim_reject("invalid_ticket")
        foreign = ticket._owner_ref() if type(ticket._owner_ref) is weakref.ReferenceType else None
        if foreign is not self:
            return self._claim_reject("owner_mismatch")
        if not self._ticket_fields_valid(ticket):
            return self._claim_reject("ticket_integrity_invalid")
        if ticket is not self._ticket:
            return self._claim_reject("ticket_not_current")
        if self._state == "claimed":
            return self._claim_reject("ticket_already_claimed")
        if self._state == "revoked":
            return self._claim_reject("ticket_revoked")
        if self._state != "issued":
            return self._claim_reject("ticket_not_current")
        if type(session_id) is not str or session_id != ticket._session_id:
            return self._claim_reject("session_mismatch")
        if type(callback_binding_hash) is not str or callback_binding_hash != ticket._callback_binding_hash:
            return self._claim_reject("callback_mismatch")
        if type(public_observation_hash) is not str or public_observation_hash != ticket.public_observation_hash:
            return self._claim_reject("public_hash_mismatch")
        if (
            binding_owner is not ticket._binding_owner
            or binding is not ticket._binding
            or port is not ticket._port
            or snapshot is not ticket._snapshot
            or window is not ticket._window
        ):
            self._revoke(ticket)
            return self._claim_reject("binding_not_current")
        if not ticket._selection_resolution.validate_integrity(ticket._window):
            self._revoke(ticket)
            return self._claim_reject("selection_not_current")
        resolutions, code = self._resolve_context(
            binding_owner=binding_owner,
            binding=binding,
            port=port,
            snapshot=snapshot,
            current_source=current_source,
            window=window,
            callback_hash=callback_binding_hash,
            indexes=ticket.selected_indexes,
        )
        if code:
            self._revoke(ticket)
            return self._claim_reject(code)
        self._state = "claimed"
        self._close_binding(binding)
        return GodotActionClaimResult._from_owner(self, True, "", ticket, resolutions)

    def _resolve_context(
        self,
        *,
        binding_owner: GodotOptionBinding,
        binding: GodotOptionBindingSet,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_hash: str,
        indexes: tuple[int, ...],
    ) -> tuple[tuple[GodotOptionResolution, ...], str]:
        results: list[GodotOptionResolution] = []
        for index in indexes:
            result = binding_owner.resolve(
                binding=binding,
                port=port,
                snapshot=snapshot,
                current_source=current_source,
                window=window,
                callback_binding_hash=callback_hash,
                option_index=index,
            )
            if not result.accepted:
                code = "private_reference_unavailable" if result.error_code == "reference_released" else "binding_not_current"
                return (), code
            if not result.validate_integrity(binding_owner):
                return (), "binding_not_current"
            results.append(result)
        return tuple(results), ""

    def _ticket_fields_valid(self, ticket: Any) -> bool:
        try:
            if (
                type(ticket) is not GodotActionTicket
                or ticket._construction_seal is not _FACTORY_TOKEN
                or ticket._owner_ref() is not self
                or not _upper_sha(ticket.ticket_id)
                or type(ticket.ticket_generation) is not int
                or not 1 <= ticket.ticket_generation <= SAFE_MAX
                or type(ticket.binding_version) is not int
                or ticket.binding_version != ticket._binding.binding_version
                or ticket.snapshot_id != ticket._snapshot.snapshot_id
                or ticket.window_id != ticket._window.window_id
                or ticket.public_observation_hash != ticket._window.public_observation_hash
                or type(ticket.selected_indexes) is not tuple
                or any(type(index) is not int for index in ticket.selected_indexes)
                or len(set(ticket.selected_indexes)) != len(ticket.selected_indexes)
                or type(ticket.selected_fingerprint_hashes) is not tuple
                or len(ticket.selected_fingerprint_hashes) != len(ticket.selected_indexes)
                or not _session(ticket._session_id)
                or not _upper_sha(ticket._callback_binding_hash)
                or type(ticket._binding_owner) is not GodotOptionBinding
                or type(ticket._binding) is not GodotOptionBindingSet
                or type(ticket._port) is not EngineDecisionPort
                or type(ticket._snapshot) is not EngineDecisionSnapshot
                or type(ticket._window) is not CabtSelectionWindow
                or type(ticket._selection_resolution) is not CabtSelectionResolution
                or ticket.selected_indexes != tuple(ticket._selection_resolution.selected_indexes)
                or ticket.selected_fingerprint_hashes != tuple(ticket._window.option_fingerprints[index] for index in ticket.selected_indexes)
                or ticket.ticket_id != _ticket_hash(
                    ticket.ticket_generation,
                    ticket._session_id,
                    ticket._callback_binding_hash,
                    ticket.binding_version,
                    ticket.snapshot_id,
                    ticket.window_id,
                    ticket.public_observation_hash,
                    ticket.selected_indexes,
                    ticket.selected_fingerprint_hashes,
                )
            ):
                return False
            return ticket._public_snapshot == self._ticket_audit(ticket)
        except (AttributeError, IndexError, TypeError, ValueError):
            return False

    def _ticket_audit(self, ticket: GodotActionTicket) -> dict[str, Any]:
        return {
            "ticket_profile": PROFILE_ID,
            "ticket_id": ticket.ticket_id,
            "ticket_generation": ticket.ticket_generation,
            "binding_version": ticket.binding_version,
            "snapshot_id": ticket.snapshot_id,
            "window_id": ticket.window_id,
            "public_observation_hash": ticket.public_observation_hash,
            "selected_indexes": list(ticket.selected_indexes),
            "selected_fingerprint_hashes": list(ticket.selected_fingerprint_hashes),
            "authority": "godot_action_ticket_shadow",
            "authoritative": False,
        }

    def _claim_audit(self, ticket: GodotActionTicket) -> dict[str, Any]:
        return {
            "ticket_profile": PROFILE_ID,
            "ticket_id": ticket.ticket_id,
            "ticket_generation": ticket.ticket_generation,
            "selected_indexes": list(ticket.selected_indexes),
            "selected_fingerprint_hashes": list(ticket.selected_fingerprint_hashes),
            "state": "claimed",
            "authority": "godot_action_claim_shadow",
            "authoritative": False,
        }

    def _issue_result_valid(self, result: Any) -> bool:
        try:
            if (
                type(result) is not GodotActionTicketIssueResult
                or result._construction_seal is not _FACTORY_TOKEN
                or result._owner_ref() is not self
                or type(result.accepted) is not bool
                or type(result.error_code) is not str
                or result.error_code not in _ERROR_CODES
            ):
                return False
            if result.accepted:
                return result.error_code == "" and result.ticket is not None and self._ticket_fields_valid(result.ticket) and result._public_snapshot == {"accepted": True, "error_code": "", "audit": result.ticket.to_public_dict()}
            return result.error_code != "" and result.ticket is None and result._public_snapshot == {"accepted": False, "error_code": result.error_code, "audit": None}
        except (AttributeError, TypeError):
            return False

    def _claim_result_valid(self, result: Any) -> bool:
        try:
            if (
                type(result) is not GodotActionClaimResult
                or result._construction_seal is not _FACTORY_TOKEN
                or result._owner_ref() is not self
                or type(result.accepted) is not bool
                or type(result.error_code) is not str
                or result.error_code not in _ERROR_CODES
                or type(result.binding_resolutions) is not tuple
            ):
                return False
            if result.accepted:
                ticket = result._ticket
                return (
                    result.error_code == ""
                    and ticket is self._ticket
                    and self._state == "claimed"
                    and self._ticket_fields_valid(ticket)
                    and len(result.binding_resolutions) == len(ticket.selected_indexes)
                    and all(item.validate_integrity(ticket._binding_owner) for item in result.binding_resolutions)
                    and result._public_snapshot == {"accepted": True, "error_code": "", "audit": self._claim_audit(ticket)}
                )
            return result.error_code != "" and not result.binding_resolutions and result._ticket is None and result._public_snapshot == {"accepted": False, "error_code": result.error_code, "audit": None}
        except (AttributeError, TypeError):
            return False

    def _binding_closed(self, binding: GodotOptionBindingSet) -> bool:
        alive = []
        found = False
        for ref in self._closed_bindings:
            value = ref()
            if value is not None:
                alive.append(ref)
                found = found or value is binding
        self._closed_bindings = alive
        return found

    def _close_binding(self, binding: GodotOptionBindingSet) -> None:
        if not self._binding_closed(binding):
            self._closed_bindings.append(weakref.ref(binding))

    def _revoke(self, ticket: GodotActionTicket) -> None:
        self._state = "revoked"
        self._close_binding(ticket._binding)

    def _issue_reject(self, code: str) -> GodotActionTicketIssueResult:
        return GodotActionTicketIssueResult._from_owner(self, False, code, None)

    def _claim_reject(self, code: str) -> GodotActionClaimResult:
        return GodotActionClaimResult._from_owner(self, False, code, None)


__all__ = [
    "GodotActionTicket",
    "GodotActionTicketIssueResult",
    "GodotActionClaimResult",
    "GodotActionTicketOwner",
]
