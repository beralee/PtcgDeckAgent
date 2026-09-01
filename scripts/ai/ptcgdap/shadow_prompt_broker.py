from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any
import weakref

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionResolution, CabtSelectionWindow, _require_current_window
from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort, EngineDecisionSnapshot
from scripts.ai.ptcgdap.godot_action_executor import GodotActionExecutor, GodotPreparedActionBatch
from scripts.ai.ptcgdap.godot_action_ticket import GodotActionClaimResult, GodotActionTicketOwner
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding, GodotOptionBindingSet, GodotOptionResolution
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "shadow_prompt_broker_bundle.json"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
PROFILE_ID = "ptcgdap-shadow-prompt-broker-p3-wp5-v1"
SAFE_MAX = 9007199254740991
SESSION_RE = re.compile(r"^session:[a-z0-9_-]{1,64}$")
FACTORY_TOKEN = object()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_contracts() -> tuple[MappingProxyType[str, Any], frozenset[str], frozenset[str]]:
    bundle = load_json_strict(BUNDLE_PATH)
    if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise RuntimeError("shadow prompt broker bundle trust-anchor mismatch")
    if type(bundle) is not dict or bundle.get("contract_id") != PROFILE_ID:
        raise RuntimeError("shadow prompt broker identity mismatch")
    expected = {
        "schema": "contracts/ptcgdap/shadow_prompt_broker.schema.json",
        "profile": "contracts/ptcgdap/shadow_prompt_broker_profile.json",
        "vectors": "contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json",
    }
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("shadow prompt broker artifact set mismatch")
    docs: dict[str, Any] = {}
    for entry in entries:
        if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
            raise RuntimeError("shadow prompt broker artifact entry mismatch")
        artifact_id = entry["id"]
        if artifact_id in docs or expected.get(artifact_id) != entry["path"]:
            raise RuntimeError("shadow prompt broker artifact identity mismatch")
        document = load_json_strict(ROOT / entry["path"])
        if _sha(canonical_json_v1_bytes(document)) != entry["canonical_sha256"]:
            raise RuntimeError("shadow prompt broker artifact hash mismatch")
        docs[artifact_id] = document
    if set(docs) != set(expected):
        raise RuntimeError("shadow prompt broker artifact set mismatch")
    profile = docs["profile"]
    if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("shadow prompt broker profile mismatch")
    families = profile.get("prompt_families")
    states = profile.get("states")
    codes = profile.get("error_codes")
    if families != ["W1", "W2", "W3", "W4", "W5", "W6", "W7"]:
        raise RuntimeError("shadow prompt family domain mismatch")
    if states != ["open", "prepared", "awaiting_reobserve", "aborted", "superseded"]:
        raise RuntimeError("shadow prompt state domain mismatch")
    if type(codes) is not list or not codes or len(codes) != len(set(codes)) or any(type(code) is not str or not code for code in codes):
        raise RuntimeError("shadow prompt error domain mismatch")
    return MappingProxyType(profile), frozenset(families), frozenset(codes)


PROFILE, PROMPT_FAMILIES, ERROR_CODES = _load_contracts()


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) in (list, tuple):
        return [_copy_json(item) for item in value]
    return value


def _positive(value: Any) -> bool:
    return type(value) is int and 1 <= value <= SAFE_MAX


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class ShadowPromptHandle:
    prompt_family: str
    broker_generation: int
    match_generation: int
    decision_generation: int
    snapshot_id: str
    window_id: str
    public_observation_hash: str
    chooser_player_index: int
    state: str
    _owner_ref: weakref.ReferenceType["ShadowPromptBroker"]
    _port: EngineDecisionPort
    _snapshot: EngineDecisionSnapshot
    _binding_owner: GodotOptionBinding
    _binding: GodotOptionBindingSet
    _window: CabtSelectionWindow
    _current_source: Any
    _callback_hash: str
    _ticket_owner: GodotActionTicketOwner | None
    _claim_result: GodotActionClaimResult | None
    _executor: GodotActionExecutor | None
    _preflight: GodotPreparedActionBatch | None
    _committed_resolutions: tuple[GodotOptionResolution, ...]
    _construction_seal: object

    def __new__(cls) -> "ShadowPromptHandle":
        raise TypeError("shadow prompt handles must be broker-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "ShadowPromptBroker",
        family: str,
        generation: int,
        port: EngineDecisionPort,
        snapshot: EngineDecisionSnapshot,
        binding_owner: GodotOptionBinding,
        binding: GodotOptionBindingSet,
        window: CabtSelectionWindow,
        current_source: Any,
        callback_hash: str,
    ) -> "ShadowPromptHandle":
        result = object.__new__(cls)
        values = {
            "prompt_family": family,
            "broker_generation": generation,
            "match_generation": snapshot.match_generation,
            "decision_generation": snapshot.decision_generation,
            "snapshot_id": snapshot.snapshot_id,
            "window_id": window.window_id,
            "public_observation_hash": window.public_observation_hash,
            "chooser_player_index": window.chooser_player_index,
            "state": "open",
            "_owner_ref": weakref.ref(owner),
            "_port": port,
            "_snapshot": snapshot,
            "_binding_owner": binding_owner,
            "_binding": binding,
            "_window": window,
            "_current_source": current_source,
            "_callback_hash": callback_hash,
            "_ticket_owner": None,
            "_claim_result": None,
            "_executor": None,
            "_preflight": None,
            "_committed_resolutions": (),
            "_construction_seal": FACTORY_TOKEN,
        }
        for name, value in values.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "ShadowPromptBroker") -> bool:
        return type(owner) is ShadowPromptBroker and owner._prompt_fields_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        return owner._audit(self) if type(owner) is ShadowPromptBroker and owner._prompt_fields_valid(self) else {}


@dataclass(frozen=True, slots=True, init=False)
class ShadowPromptBrokerResult:
    accepted: bool
    error_code: str
    prompt: ShadowPromptHandle | None
    private_resolutions: tuple[GodotOptionResolution, ...]
    _owner_ref: weakref.ReferenceType["ShadowPromptBroker"]
    _construction_seal: object

    def __new__(cls) -> "ShadowPromptBrokerResult":
        raise TypeError("shadow prompt broker results must be owner-created")

    @classmethod
    def _from_owner(
        cls,
        owner: "ShadowPromptBroker",
        accepted: bool,
        code: str,
        prompt: ShadowPromptHandle | None,
        resolutions: tuple[GodotOptionResolution, ...] = (),
    ) -> "ShadowPromptBrokerResult":
        result = object.__new__(cls)
        for name, value in {
            "accepted": accepted,
            "error_code": code,
            "prompt": prompt,
            "private_resolutions": resolutions,
            "_owner_ref": weakref.ref(owner),
            "_construction_seal": FACTORY_TOKEN,
        }.items():
            object.__setattr__(result, name, value)
        return result

    def validate_integrity(self, owner: "ShadowPromptBroker") -> bool:
        return type(owner) is ShadowPromptBroker and owner._result_fields_valid(self)

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref() if type(self._owner_ref) is weakref.ReferenceType else None
        if type(owner) is not ShadowPromptBroker or not owner._result_fields_valid(self):
            return {"accepted": False, "error_code": "invalid_broker", "audit": None}
        return {
            "accepted": self.accepted,
            "error_code": self.error_code,
            "audit": None if self.prompt is None else owner._audit(self.prompt),
        }

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


class ShadowPromptBroker:
    __slots__ = ("__weakref__", "_match_generation", "_session_id", "_next_generation", "_last_decision_generation", "_port_owner", "_current")

    def __init__(self, match_generation: Any, session_id: Any) -> None:
        self._match_generation = match_generation
        self._session_id = session_id
        self._next_generation = 1
        self._last_decision_generation = 0
        self._port_owner: EngineDecisionPort | None = None
        self._current: ShadowPromptHandle | None = None

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def validate_integrity(self) -> bool:
        return (
            _positive(self._match_generation)
            and type(self._session_id) is str
            and SESSION_RE.fullmatch(self._session_id) is not None
            and _positive(self._next_generation)
            and type(self._last_decision_generation) is int
            and 0 <= self._last_decision_generation <= SAFE_MAX
            and (self._port_owner is None or type(self._port_owner) is EngineDecisionPort)
            and (self._current is None or self._prompt_fields_valid(self._current))
        )

    def current_prompt(self) -> ShadowPromptHandle | None:
        return self._current

    def open_prompt(
        self,
        *,
        prompt_family: Any,
        port: Any,
        snapshot: Any,
        binding_owner: Any,
        binding: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
    ) -> ShadowPromptBrokerResult:
        if not self.validate_integrity():
            return self._reject("invalid_broker")
        if type(prompt_family) is not str or prompt_family not in PROMPT_FAMILIES:
            return self._reject("invalid_family")
        if self._current is not None and self._current.state in {"open", "prepared"}:
            return self._reject("active_prompt_exists", self._current)
        code = self._context_error(port, snapshot, binding_owner, binding, current_source, window, callback_binding_hash)
        if code:
            return self._reject(code, self._current)
        if self._port_owner is not None and port is not self._port_owner:
            return self._reject("cross_owner", self._current)
        assert type(snapshot) is EngineDecisionSnapshot and type(window) is CabtSelectionWindow
        if snapshot.match_generation != self._match_generation:
            return self._reject("match_generation_mismatch", self._current)
        if snapshot.decision_generation <= self._last_decision_generation:
            return self._reject("stale_decision_generation", self._current)
        if self._current is not None and (
            snapshot.snapshot_id == self._current.snapshot_id
            or window.window_id == self._current.window_id
            or binding is self._current._binding
        ):
            return self._reject("same_window_reused", self._current)
        if self._next_generation > SAFE_MAX:
            return self._reject("generation_exhausted", self._current)
        previous = self._current
        if previous is not None:
            object.__setattr__(previous, "state", "superseded")
        prompt = ShadowPromptHandle._from_owner(
            self, prompt_family, self._next_generation, port, snapshot,
            binding_owner, binding, window, current_source, callback_binding_hash,
        )
        self._next_generation += 1
        self._last_decision_generation = snapshot.decision_generation
        if self._port_owner is None:
            self._port_owner = port
        self._current = prompt
        return ShadowPromptBrokerResult._from_owner(self, True, "", prompt)

    def prepare_selection(self, prompt: Any, selection_resolution: Any) -> ShadowPromptBrokerResult:
        code = self._prompt_error(prompt)
        if code:
            return self._reject(code, prompt if type(prompt) is ShadowPromptHandle else None)
        assert type(prompt) is ShadowPromptHandle
        if prompt.state == "awaiting_reobserve":
            return self._reject("reobserve_required", prompt)
        if prompt.state != "open":
            return self._reject("prompt_not_current", prompt)
        if type(selection_resolution) is not CabtSelectionResolution or not selection_resolution.validate_integrity(prompt._window):
            return self._abort(prompt, "selection_invalid")
        ticket_owner = GodotActionTicketOwner()
        issued = ticket_owner.issue(
            session_id=self._session_id,
            public_observation_hash=prompt.public_observation_hash,
            binding_owner=prompt._binding_owner,
            binding=prompt._binding,
            port=prompt._port,
            snapshot=prompt._snapshot,
            current_source=prompt._current_source,
            window=prompt._window,
            callback_binding_hash=prompt._callback_hash,
            selection_resolution=selection_resolution,
        )
        if not issued.accepted:
            return self._abort(prompt, "ticket_issue_failed")
        claimed = ticket_owner.claim(
            ticket=issued.ticket,
            session_id=self._session_id,
            public_observation_hash=prompt.public_observation_hash,
            binding_owner=prompt._binding_owner,
            binding=prompt._binding,
            port=prompt._port,
            snapshot=prompt._snapshot,
            current_source=prompt._current_source,
            window=prompt._window,
            callback_binding_hash=prompt._callback_hash,
        )
        if not claimed.accepted:
            return self._abort(prompt, "ticket_claim_failed")
        executor = GodotActionExecutor()
        prepared = executor.prepare(
            ticket_owner=ticket_owner,
            claim_result=claimed,
            binding_owner=prompt._binding_owner,
            binding=prompt._binding,
            port=prompt._port,
            snapshot=prompt._snapshot,
            current_source=prompt._current_source,
            window=prompt._window,
            callback_binding_hash=prompt._callback_hash,
        )
        if not prepared.accepted or prepared.preflight is None:
            return self._abort(prompt, "preflight_failed")
        for name, value in {
            "_ticket_owner": ticket_owner,
            "_claim_result": claimed,
            "_executor": executor,
            "_preflight": prepared.preflight,
            "state": "prepared",
        }.items():
            object.__setattr__(prompt, name, value)
        return ShadowPromptBrokerResult._from_owner(self, True, "", prompt)

    def commit_prompt(self, prompt: Any) -> ShadowPromptBrokerResult:
        code = self._prompt_error(prompt)
        if code:
            return self._reject(code, prompt if type(prompt) is ShadowPromptHandle else None)
        assert type(prompt) is ShadowPromptHandle
        if prompt.state == "awaiting_reobserve":
            return self._reject("reobserve_required", prompt)
        if prompt.state != "prepared" or prompt._executor is None or prompt._ticket_owner is None or prompt._preflight is None:
            return self._reject("prompt_not_current", prompt)
        committed = prompt._executor.commit(
            prompt._preflight,
            ticket_owner=prompt._ticket_owner,
            binding_owner=prompt._binding_owner,
            binding=prompt._binding,
            port=prompt._port,
            snapshot=prompt._snapshot,
            current_source=prompt._current_source,
            window=prompt._window,
            callback_binding_hash=prompt._callback_hash,
        )
        if not committed.accepted:
            return self._abort(prompt, "commit_failed")
        resolutions = tuple(committed.binding_resolutions)
        object.__setattr__(prompt, "_committed_resolutions", resolutions)
        object.__setattr__(prompt, "state", "awaiting_reobserve")
        return ShadowPromptBrokerResult._from_owner(self, True, "", prompt, resolutions)

    def abort_prompt(self, prompt: Any) -> ShadowPromptBrokerResult:
        code = self._prompt_error(prompt)
        if code:
            return self._reject(code, prompt if type(prompt) is ShadowPromptHandle else None)
        assert type(prompt) is ShadowPromptHandle
        if prompt._executor is not None and prompt._preflight is not None:
            prompt._executor.abort(prompt._preflight)
        return self._abort(prompt, "broker_aborted")

    def reset_match(self, match_generation: Any, session_id: Any) -> bool:
        if not _positive(match_generation) or match_generation <= self._match_generation:
            return False
        if type(session_id) is not str or SESSION_RE.fullmatch(session_id) is None:
            return False
        if self._current is not None:
            object.__setattr__(self._current, "state", "superseded")
        self._match_generation = match_generation
        self._session_id = session_id
        self._next_generation = 1
        self._last_decision_generation = 0
        self._port_owner = None
        self._current = None
        return True

    def _context_error(self, port: Any, snapshot: Any, binding_owner: Any, binding: Any, current_source: Any, window: Any, callback_hash: Any) -> str:
        if type(port) is not EngineDecisionPort or type(snapshot) is not EngineDecisionSnapshot:
            return "invalid_context"
        if not snapshot.validate_integrity(port) or port.current_snapshot() is not snapshot:
            return "invalid_context"
        if type(binding_owner) is not GodotOptionBinding or type(binding) is not GodotOptionBindingSet:
            return "invalid_context"
        if binding_owner.current_binding() is not binding or not binding.validate_integrity(binding_owner):
            return "invalid_context"
        if type(window) is not CabtSelectionWindow:
            return "invalid_context"
        try:
            _require_current_window(window)
        except (AttributeError, TypeError, ValueError):
            return "invalid_context"
        state = getattr(binding_owner, "_current", None)
        if (
            state is None or state.port is not port or state.snapshot is not snapshot or state.window is not window
            or state.binding is not binding or state.callback_binding_hash != callback_hash
            or binding.snapshot_id != snapshot.snapshot_id or binding.window_id != window.window_id
            or binding.public_observation_hash != window.public_observation_hash
            or binding.chooser_player_index != window.chooser_player_index
        ):
            return "invalid_context"
        rebound = port.rebind(snapshot, current_source)
        return "" if rebound.get("ok") is True else "invalid_context"

    def _prompt_error(self, prompt: Any) -> str:
        if type(prompt) is not ShadowPromptHandle:
            return "prompt_integrity_invalid"
        owner = prompt._owner_ref() if type(prompt._owner_ref) is weakref.ReferenceType else None
        if owner is not self:
            return "cross_owner"
        if prompt.match_generation != self._match_generation:
            return "match_generation_mismatch"
        if prompt is not self._current:
            return "prompt_not_current"
        if not self._prompt_fields_valid(prompt):
            return "prompt_integrity_invalid"
        return ""

    def _prompt_fields_valid(self, prompt: ShadowPromptHandle) -> bool:
        if (
            type(prompt) is not ShadowPromptHandle or prompt._construction_seal is not FACTORY_TOKEN
            or prompt._owner_ref() is not self or prompt.prompt_family not in PROMPT_FAMILIES
            or not _positive(prompt.broker_generation) or not _positive(prompt.match_generation)
            or not _positive(prompt.decision_generation) or prompt.match_generation != self._match_generation
            or prompt.state not in {"open", "prepared", "awaiting_reobserve", "aborted", "superseded"}
            or type(prompt._port) is not EngineDecisionPort or type(prompt._snapshot) is not EngineDecisionSnapshot
            or self._port_owner is not prompt._port
            or type(prompt._binding_owner) is not GodotOptionBinding or type(prompt._binding) is not GodotOptionBindingSet
            or type(prompt._window) is not CabtSelectionWindow
            or prompt.snapshot_id != prompt._snapshot.snapshot_id or prompt.window_id != prompt._window.window_id
            or prompt.public_observation_hash != prompt._window.public_observation_hash
            or prompt.chooser_player_index != prompt._window.chooser_player_index
        ):
            return False
        if prompt.state == "open":
            return prompt._ticket_owner is None and prompt._claim_result is None and prompt._executor is None and prompt._preflight is None and prompt._committed_resolutions == ()
        if prompt.state == "prepared":
            return (
                type(prompt._ticket_owner) is GodotActionTicketOwner
                and type(prompt._claim_result) is GodotActionClaimResult
                and type(prompt._executor) is GodotActionExecutor
                and type(prompt._preflight) is GodotPreparedActionBatch
                and prompt._preflight.validate_integrity(prompt._executor)
                and prompt._committed_resolutions == ()
            )
        if prompt.state == "awaiting_reobserve":
            return (
                type(prompt._executor) is GodotActionExecutor
                and type(prompt._preflight) is GodotPreparedActionBatch
                and prompt._preflight.state == "committed"
                and all(type(item) is GodotOptionResolution for item in prompt._committed_resolutions)
            )
        if prompt.state == "aborted":
            return prompt._committed_resolutions == ()
        return prompt._committed_resolutions == () or all(type(item) is GodotOptionResolution for item in prompt._committed_resolutions)

    def _result_fields_valid(self, result: ShadowPromptBrokerResult) -> bool:
        if type(result) is not ShadowPromptBrokerResult or result._construction_seal is not FACTORY_TOKEN or result._owner_ref() is not self:
            return False
        if result.accepted:
            return result.error_code == "" and type(result.prompt) is ShadowPromptHandle and self._prompt_fields_valid(result.prompt) and all(type(item) is GodotOptionResolution for item in result.private_resolutions)
        return (
            result.error_code in ERROR_CODES
            and result.error_code != ""
            and result.private_resolutions == ()
            and (result.prompt is None or (type(result.prompt) is ShadowPromptHandle and self._prompt_fields_valid(result.prompt)))
        )

    def _audit(self, prompt: ShadowPromptHandle) -> dict[str, Any]:
        prepared = prompt.state in {"prepared", "awaiting_reobserve"}
        committed = prompt.state == "awaiting_reobserve"
        return {
            "profile": PROFILE_ID,
            "prompt_family": prompt.prompt_family,
            "broker_generation": prompt.broker_generation,
            "match_generation": prompt.match_generation,
            "decision_generation": prompt.decision_generation,
            "snapshot_id": prompt.snapshot_id,
            "window_id": prompt.window_id,
            "public_observation_hash": prompt.public_observation_hash,
            "chooser_player_index": prompt.chooser_player_index,
            "state": prompt.state,
            "witness": {"accepted": True, "bound": prepared, "committed": committed},
            "resolution_count": len(prompt._committed_resolutions) if committed else 0,
            "authority": "shadow_prompt_broker_audit",
            "authoritative": False,
        }

    def _reject(self, code: str, prompt: ShadowPromptHandle | None = None) -> ShadowPromptBrokerResult:
        return ShadowPromptBrokerResult._from_owner(self, False, code, prompt)

    def _abort(self, prompt: ShadowPromptHandle, code: str) -> ShadowPromptBrokerResult:
        if prompt._executor is not None and prompt._preflight is not None and prompt._preflight.state == "prepared":
            prompt._executor.abort(prompt._preflight)
        object.__setattr__(prompt, "_committed_resolutions", ())
        object.__setattr__(prompt, "state", "aborted")
        return self._reject(code, prompt)


__all__ = ["ShadowPromptBroker", "ShadowPromptBrokerResult", "ShadowPromptHandle"]
