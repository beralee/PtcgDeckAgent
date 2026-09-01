from __future__ import annotations

import hashlib
import re
import weakref
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any

from .cabt_selection import CabtSelectionWindow, _require_current_window
from .engine_decision_port import EngineDecisionPort, EngineDecisionSnapshot
from .source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
PROFILE_ID = "ptcgdap-godot-option-binding-p3-wp2-v1"
EXPECTED_BUNDLE_SHA256 = "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"
EXPECTED_ARTIFACTS = MappingProxyType({
    "schema": (
        "contracts/ptcgdap/godot_option_binding.schema.json",
        "FF4CE1D7F1655062E8BD25951E34030582408CBA4990A9E8C34351B68D98614F",
    ),
    "profile": (
        "contracts/ptcgdap/godot_option_binding_profile.json",
        "2E42620EFF40CEC465FF46B4F252389AABF8D26708B1B93F392FB03D169E71C0",
    ),
    "vectors": (
        "contracts/ptcgdap/godot_option_binding_conformance_vectors.json",
        "8B13EABF6039F20346D4F52326E4B20CDD6FE000E7F685B7527DB6163F06B40F",
    ),
})
SAFE_MAX = 9007199254740991
UPPER_SHA256 = re.compile(r"^[A-F0-9]{64}$")
AUDIT_KEYS = frozenset({
    "binding_profile", "binding_version", "snapshot_id", "window_id",
    "public_observation_hash", "chooser_player_index", "option_count",
    "option_fingerprints", "authority", "authoritative",
})
RESOLUTION_AUDIT_KEYS = frozenset({
    "binding_profile", "binding_version", "snapshot_id", "window_id",
    "option_index", "fingerprint_hash", "authority", "authoritative",
})


def _canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def _load_contracts() -> dict[str, Any]:
    bundle_path = CONTRACT_ROOT / "godot_option_binding_bundle.json"
    bundle = load_json_strict(bundle_path)
    if _canonical_hash(bundle) != EXPECTED_BUNDLE_SHA256:
        raise RuntimeError("option binding bundle trust-anchor mismatch")
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("option binding bundle shape mismatch")
    seen: set[str] = set()
    for entry in entries:
        artifact_id = entry.get("id") if type(entry) is dict else None
        if artifact_id not in EXPECTED_ARTIFACTS or artifact_id in seen:
            raise RuntimeError("option binding artifact identity mismatch")
        path, digest = EXPECTED_ARTIFACTS[artifact_id]
        if entry != {"id": artifact_id, "path": path, "canonical_sha256": digest}:
            raise RuntimeError("option binding artifact binding mismatch")
        if _canonical_hash(load_json_strict(ROOT / path)) != digest:
            raise RuntimeError("option binding artifact hash mismatch")
        seen.add(artifact_id)
    if seen != set(EXPECTED_ARTIFACTS):
        raise RuntimeError("option binding artifact set mismatch")
    profile = load_json_strict(CONTRACT_ROOT / "godot_option_binding_profile.json")
    if profile.get("profile_id") != PROFILE_ID:
        raise RuntimeError("option binding profile mismatch")
    return profile


PROFILE = _load_contracts()
ERROR_CODES = frozenset(PROFILE["error_codes"])
SUPPORTED_OPTION_TYPES = frozenset(PROFILE["supported_source_option_types"])
P5_EXTENSION_PROFILE_ID = "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
P5_SUPPORTED_OPTION_TYPES = frozenset({3, 7, 8, 12, 13, 14, 15})
MAX_OPTIONS = PROFILE["limits"]["max_options"]
MAX_REFS_PER_OPTION = PROFILE["limits"]["max_private_refs_per_option"]
MAX_TOTAL_REFS = PROFILE["limits"]["max_total_private_refs"]


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) is list:
        return [_copy_json(item) for item in value]
    return value


def _upper_sha(value: Any) -> bool:
    return type(value) is str and UPPER_SHA256.fullmatch(value) is not None


def _weak(value: Any) -> weakref.ReferenceType[Any] | None:
    if value is None or type(value) in {dict, list, tuple, str, bytes, int, bool, float}:
        return None
    try:
        return weakref.ref(value)
    except TypeError:
        return None


@dataclass(slots=True)
class _CurrentState:
    binding: "GodotOptionBindingSet"
    binding_version: int
    port: EngineDecisionPort
    snapshot: EngineDecisionSnapshot
    window: CabtSelectionWindow
    callback_binding_hash: str
    command_refs: tuple[weakref.ReferenceType[Any], ...]
    private_refs: tuple[tuple[weakref.ReferenceType[Any], ...], ...]
    audit: dict[str, Any]
    binding_profile: str


@dataclass(frozen=True, slots=True, weakref_slot=True, eq=False)
class GodotOptionBindingSet:
    binding_version: int
    snapshot_id: str
    window_id: str
    public_observation_hash: str
    chooser_player_index: int
    option_count: int
    option_fingerprints: tuple[str, ...]
    _owner_ref: weakref.ReferenceType["GodotOptionBinding"]
    _audit: dict[str, Any]

    def validate_integrity(self, owner: "GodotOptionBinding") -> bool:
        return type(owner) is GodotOptionBinding and owner._binding_fields_valid(self)

    def to_audit_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not owner._binding_fields_valid(self):
            return {}
        return _copy_json(self._audit)

    def to_public_dict(self) -> dict[str, Any]:
        return self.to_audit_dict()


@dataclass(frozen=True, slots=True, weakref_slot=True, eq=False)
class GodotOptionBindResult:
    accepted: bool
    error_code: str
    binding: GodotOptionBindingSet | None
    _owner_ref: weakref.ReferenceType["GodotOptionBinding"]

    def validate_integrity(self, owner: "GodotOptionBinding") -> bool:
        if type(owner) is not GodotOptionBinding or self._owner_ref() is not owner:
            return False
        if self.accepted:
            return (
                self.error_code == ""
                and type(self.binding) is GodotOptionBindingSet
                and owner._binding_fields_valid(self.binding)
            )
        return self.binding is None and self.error_code in ERROR_CODES and self.error_code != ""

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not self.validate_integrity(owner):
            return {"accepted": False, "error_code": "binding_integrity_invalid", "audit": None}
        return {
            "accepted": self.accepted,
            "error_code": self.error_code,
            "audit": None if self.binding is None else self.binding.to_audit_dict(),
        }


@dataclass(frozen=True, slots=True, weakref_slot=True, eq=False)
class GodotOptionResolution:
    accepted: bool
    error_code: str
    option_index: int | None
    private_engine_command: Any
    private_object_refs: tuple[Any, ...]
    _owner_ref: weakref.ReferenceType["GodotOptionBinding"]
    _binding: GodotOptionBindingSet | None
    _audit: dict[str, Any] | None

    def validate_integrity(self, owner: "GodotOptionBinding") -> bool:
        if type(owner) is not GodotOptionBinding or self._owner_ref() is not owner:
            return False
        if self.accepted:
            return owner._resolution_fields_valid(self)
        return (
            self.error_code in ERROR_CODES
            and self.error_code != ""
            and self.option_index is None
            and self.private_engine_command is None
            and self.private_object_refs == ()
            and self._binding is None
            and self._audit is None
        )

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not self.validate_integrity(owner):
            return {"accepted": False, "error_code": "binding_integrity_invalid", "audit": None}
        return {
            "accepted": self.accepted,
            "error_code": self.error_code,
            "audit": None if self._audit is None else _copy_json(self._audit),
        }


class GodotOptionBinding:
    __slots__ = ("__weakref__", "_current", "_last_binding_version")

    def __init__(self) -> None:
        self._current: _CurrentState | None = None
        self._last_binding_version = 0

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_SHA256

    def validate_integrity(self) -> bool:
        return (
            EXPECTED_BUNDLE_SHA256 == _canonical_hash(load_json_strict(CONTRACT_ROOT / "godot_option_binding_bundle.json"))
            and type(self._last_binding_version) is int
            and 0 <= self._last_binding_version <= SAFE_MAX
            and (self._current is None or self._binding_fields_valid(self._current.binding))
        )

    def current_binding(self) -> GodotOptionBindingSet | None:
        return None if self._current is None else self._current.binding

    def bind(
        self,
        *,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
        private_commands: Any,
        private_object_refs: Any,
    ) -> GodotOptionBindResult:
        return self._bind(
            port=port,
            snapshot=snapshot,
            current_source=current_source,
            window=window,
            callback_binding_hash=callback_binding_hash,
            private_commands=private_commands,
            private_object_refs=private_object_refs,
            binding_profile=PROFILE_ID,
        )

    def bind_p5_extended(
        self,
        *,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
        private_commands: Any,
        private_object_refs: Any,
        extension_profile_id: Any,
    ) -> GodotOptionBindResult:
        if type(extension_profile_id) is not str or extension_profile_id != P5_EXTENSION_PROFILE_ID:
            return self._rejected_bind("window_mismatch")
        return self._bind(
            port=port,
            snapshot=snapshot,
            current_source=current_source,
            window=window,
            callback_binding_hash=callback_binding_hash,
            private_commands=private_commands,
            private_object_refs=private_object_refs,
            binding_profile=extension_profile_id,
        )

    def _bind(
        self,
        *,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
        private_commands: Any,
        private_object_refs: Any,
        binding_profile: str,
    ) -> GodotOptionBindResult:
        if type(port) is not EngineDecisionPort:
            return self._rejected_bind("invalid_port")
        if type(snapshot) is not EngineDecisionSnapshot:
            return self._rejected_bind("snapshot_integrity_invalid")
        rebound = port.rebind(snapshot, current_source)
        if not rebound["ok"]:
            return self._rejected_bind(self._map_snapshot_error(rebound["error_code"]))
        if type(window) is not CabtSelectionWindow:
            return self._rejected_bind("invalid_window")
        try:
            _require_current_window(window)
        except (AttributeError, TypeError, ValueError):
            return self._rejected_bind("invalid_window")
        source = rebound["value"]
        source_matches = (
            self._source_window_match_p5(source, window, snapshot)
            if binding_profile == P5_EXTENSION_PROFILE_ID
            else self._source_window_match(source, window, snapshot)
        )
        if not source_matches:
            return self._rejected_bind("window_mismatch")
        if not _upper_sha(callback_binding_hash):
            return self._rejected_bind("invalid_callback_binding_hash")
        command_refs = self._command_refs(private_commands, window.option_count)
        if command_refs is None:
            return self._rejected_bind("invalid_private_commands")
        refs = self._private_refs(private_object_refs, window.option_count)
        if refs is None:
            return self._rejected_bind("invalid_private_object_refs")
        if self._last_binding_version >= SAFE_MAX:
            return self._rejected_bind("binding_integrity_invalid")
        version = self._last_binding_version + 1
        audit = self._binding_audit(version, snapshot, window, binding_profile)
        binding = GodotOptionBindingSet(
            version,
            snapshot.snapshot_id,
            window.window_id,
            window.public_observation_hash,
            window.chooser_player_index,
            window.option_count,
            tuple(window.option_fingerprints),
            weakref.ref(self),
            _copy_json(audit),
        )
        state = _CurrentState(
            binding,
            version,
            port,
            snapshot,
            window,
            callback_binding_hash,
            command_refs,
            refs,
            _copy_json(audit),
            binding_profile,
        )
        self._last_binding_version = version
        self._current = state
        return GodotOptionBindResult(True, "", binding, weakref.ref(self))

    def resolve(
        self,
        *,
        binding: Any,
        port: Any,
        snapshot: Any,
        current_source: Any,
        window: Any,
        callback_binding_hash: Any,
        option_index: Any,
    ) -> GodotOptionResolution:
        if type(binding) is not GodotOptionBindingSet:
            return self._rejected_resolution("binding_integrity_invalid")
        if binding._owner_ref() is not self:
            return self._rejected_resolution("owner_mismatch")
        if self._current is None or self._current.binding is not binding:
            return self._rejected_resolution("binding_not_current")
        if not self._binding_static_fields_valid(binding):
            return self._rejected_resolution("binding_integrity_invalid")
        state = self._current
        if type(port) is not EngineDecisionPort or port is not state.port:
            return self._rejected_resolution("invalid_port")
        if type(snapshot) is not EngineDecisionSnapshot or snapshot is not state.snapshot:
            return self._rejected_resolution("snapshot_not_current")
        rebound = port.rebind(snapshot, current_source)
        if not rebound["ok"]:
            return self._rejected_resolution(self._map_snapshot_error(rebound["error_code"]))
        if type(window) is not CabtSelectionWindow:
            return self._rejected_resolution("invalid_window")
        if window is not state.window:
            return self._rejected_resolution("window_mismatch")
        try:
            _require_current_window(window)
        except (AttributeError, TypeError, ValueError):
            return self._rejected_resolution("invalid_window")
        source_matches = (
            self._source_window_match_p5(rebound["value"], window, snapshot)
            if state.binding_profile == P5_EXTENSION_PROFILE_ID
            else self._source_window_match(rebound["value"], window, snapshot)
        )
        if not source_matches:
            return self._rejected_resolution("window_mismatch")
        if not _upper_sha(callback_binding_hash) or callback_binding_hash != state.callback_binding_hash:
            return self._rejected_resolution("binding_not_current")
        if type(option_index) is not int or not 0 <= option_index < state.binding.option_count:
            return self._rejected_resolution("option_index_invalid")
        command = state.command_refs[option_index]()
        if command is None:
            return self._rejected_resolution("reference_released")
        objects: list[Any] = []
        for reference in state.private_refs[option_index]:
            value = reference()
            if value is None:
                return self._rejected_resolution("reference_released")
            objects.append(value)
        audit = {
            "binding_profile": state.binding_profile,
            "binding_version": state.binding_version,
            "snapshot_id": state.snapshot.snapshot_id,
            "window_id": state.window.window_id,
            "option_index": option_index,
            "fingerprint_hash": state.window.option_fingerprints[option_index],
            "authority": "godot_option_resolution_shadow",
            "authoritative": False,
        }
        return GodotOptionResolution(
            True,
            "",
            option_index,
            command,
            tuple(objects),
            weakref.ref(self),
            binding,
            audit,
        )

    def _binding_fields_valid(self, binding: Any) -> bool:
        return (
            self._binding_static_fields_valid(binding)
            and self._current is not None
            and self._current.port.current_snapshot() is self._current.snapshot
            and self._current.snapshot.validate_integrity(self._current.port)
        )

    def _binding_static_fields_valid(self, binding: Any) -> bool:
        if type(binding) is not GodotOptionBindingSet or binding._owner_ref() is not self:
            return False
        state = self._current
        if state is None or state.binding is not binding:
            return False
        try:
            _require_current_window(state.window)
        except (AttributeError, TypeError, ValueError):
            return False
        expected = self._binding_audit(state.binding_version, state.snapshot, state.window, state.binding_profile)
        return (
            state.binding_profile in {PROFILE_ID, P5_EXTENSION_PROFILE_ID}
            and type(state.callback_binding_hash) is str
            and _upper_sha(state.callback_binding_hash)
            and type(state.command_refs) is tuple
            and len(state.command_refs) == state.window.option_count
            and all(type(reference) is weakref.ReferenceType for reference in state.command_refs)
            and type(state.private_refs) is tuple
            and len(state.private_refs) == state.window.option_count
            and all(
                type(group) is tuple
                and len(group) <= MAX_REFS_PER_OPTION
                and all(type(reference) is weakref.ReferenceType for reference in group)
                for group in state.private_refs
            )
            and binding.binding_version == state.binding_version
            and binding.snapshot_id == state.snapshot.snapshot_id
            and binding.window_id == state.window.window_id
            and binding.public_observation_hash == state.window.public_observation_hash
            and binding.chooser_player_index == state.window.chooser_player_index
            and binding.option_count == state.window.option_count
            and binding.option_fingerprints == tuple(state.window.option_fingerprints)
            and type(binding._audit) is dict
            and set(binding._audit) == AUDIT_KEYS
            and binding._audit == expected
            and state.audit == expected
        )

    def _resolution_fields_valid(self, result: GodotOptionResolution) -> bool:
        if (
            self._current is None
            or result._binding is not self._current.binding
            or not self._binding_fields_valid(result._binding)
            or type(result.option_index) is not int
            or not 0 <= result.option_index < self._current.binding.option_count
            or result.error_code != ""
            or type(result._audit) is not dict
            or set(result._audit) != RESOLUTION_AUDIT_KEYS
        ):
            return False
        command = self._current.command_refs[result.option_index]()
        if command is None or result.private_engine_command is not command:
            return False
        expected_objects: list[Any] = []
        for reference in self._current.private_refs[result.option_index]:
            value = reference()
            if value is None:
                return False
            expected_objects.append(value)
        expected_audit = {
            "binding_profile": self._current.binding_profile,
            "binding_version": self._current.binding_version,
            "snapshot_id": self._current.snapshot.snapshot_id,
            "window_id": self._current.window.window_id,
            "option_index": result.option_index,
            "fingerprint_hash": self._current.window.option_fingerprints[result.option_index],
            "authority": "godot_option_resolution_shadow",
            "authoritative": False,
        }
        return (
            result.private_object_refs == tuple(expected_objects)
            and result._audit == expected_audit
        )

    @staticmethod
    def _binding_audit(
        version: int,
        snapshot: EngineDecisionSnapshot,
        window: CabtSelectionWindow,
        binding_profile: str = PROFILE_ID,
    ) -> dict[str, Any]:
        return {
            "binding_profile": binding_profile,
            "binding_version": version,
            "snapshot_id": snapshot.snapshot_id,
            "window_id": window.window_id,
            "public_observation_hash": window.public_observation_hash,
            "chooser_player_index": window.chooser_player_index,
            "option_count": window.option_count,
            "option_fingerprints": list(window.option_fingerprints),
            "authority": "godot_option_binding_shadow",
            "authoritative": False,
        }

    @staticmethod
    def _source_window_match(
        source: Any,
        window: CabtSelectionWindow,
        snapshot: EngineDecisionSnapshot,
    ) -> bool:
        if (
            type(source) is not dict
            or snapshot.chooser_player_index != window.chooser_player_index
            or source.get("select") is None
            or type(source.get("select")) is not dict
        ):
            return False
        select = source["select"]
        scalar_pairs = (
            ("type", window.select_type_raw),
            ("context", window.select_context_raw),
            ("minCount", window.min_count),
            ("maxCount", window.max_count),
            ("remainDamageCounter", window.remain_damage_counter),
            ("remainEnergyCost", window.remain_energy_cost),
        )
        if any(select.get(key) != expected for key, expected in scalar_pairs):
            return False
        source_options = select.get("option")
        window_options = window.options
        if (
            type(source_options) is not list
            or len(source_options) != len(window_options)
            or len(source_options) > MAX_OPTIONS
            or len(window.option_fingerprints) != len(source_options)
        ):
            return False
        for source_option, window_option in zip(source_options, window_options, strict=True):
            if (
                type(source_option) is not dict
                or type(window_option) is not dict
                or type(source_option.get("type")) is not int
                or source_option.get("type") not in SUPPORTED_OPTION_TYPES
                or source_option.get("type") != window_option.get("type")
            ):
                return False
            if source_option["type"] == 7 and source_option.get("index") != window_option.get("index"):
                return False
        return True

    @staticmethod
    def _source_window_match_p5(
        source: Any,
        window: CabtSelectionWindow,
        snapshot: EngineDecisionSnapshot,
    ) -> bool:
        if (
            type(source) is not dict
            or snapshot.chooser_player_index != window.chooser_player_index
            or type(source.get("select")) is not dict
        ):
            return False
        select = source["select"]
        scalar_pairs = (
            ("type", window.select_type_raw),
            ("context", window.select_context_raw),
            ("minCount", window.min_count),
            ("maxCount", window.max_count),
            ("remainDamageCounter", window.remain_damage_counter),
            ("remainEnergyCost", window.remain_energy_cost),
        )
        if any(type(select.get(key)) is not int or select.get(key) != expected for key, expected in scalar_pairs):
            return False
        source_options = select.get("option")
        window_options = window.options
        if (
            type(source_options) is not list
            or len(source_options) != len(window_options)
            or len(source_options) > MAX_OPTIONS
            or len(window.option_fingerprints) != len(source_options)
        ):
            return False
        for source_option, window_option in zip(source_options, window_options, strict=True):
            if (
                type(source_option) is not dict
                or type(window_option) is not dict
                or type(source_option.get("type")) is not int
                or source_option["type"] not in P5_SUPPORTED_OPTION_TYPES
                or source_option["type"] != window_option.get("type")
            ):
                return False
            option_type = source_option["type"]
            if option_type == 7 and source_option.get("index") != window_option.get("index"):
                return False
            if option_type == 8 and any(
                source_option.get(key) != window_option.get(key)
                for key in ("area", "index", "inPlayArea", "inPlayIndex")
            ):
                return False
            if option_type == 13 and source_option.get("official_attack_id") != window_option.get("attackId"):
                return False
        return True

    @staticmethod
    def _command_refs(value: Any, count: int) -> tuple[weakref.ReferenceType[Any], ...] | None:
        if type(value) is not list or len(value) != count or count > MAX_OPTIONS:
            return None
        output = []
        for item in value:
            reference = _weak(item)
            if reference is None:
                return None
            output.append(reference)
        return tuple(output)

    @staticmethod
    def _private_refs(
        value: Any,
        count: int,
    ) -> tuple[tuple[weakref.ReferenceType[Any], ...], ...] | None:
        if type(value) is not list or len(value) != count or count > MAX_OPTIONS:
            return None
        output = []
        total = 0
        for group in value:
            if type(group) is not list or len(group) > MAX_REFS_PER_OPTION:
                return None
            converted = []
            for item in group:
                reference = _weak(item)
                if reference is None:
                    return None
                converted.append(reference)
            total += len(converted)
            if total > MAX_TOTAL_REFS:
                return None
            output.append(tuple(converted))
        return tuple(output)

    @staticmethod
    def _map_snapshot_error(code: Any) -> str:
        if code in {
            "snapshot_not_current", "snapshot_owner_mismatch", "snapshot_integrity_invalid",
            "source_mutated", "reference_released",
        }:
            return code
        return "snapshot_integrity_invalid"

    def _rejected_bind(self, code: str) -> GodotOptionBindResult:
        if code not in ERROR_CODES or code == "":
            code = "binding_integrity_invalid"
        return GodotOptionBindResult(False, code, None, weakref.ref(self))

    def _rejected_resolution(self, code: str) -> GodotOptionResolution:
        if code not in ERROR_CODES or code == "":
            code = "binding_integrity_invalid"
        return GodotOptionResolution(False, code, None, None, (), weakref.ref(self), None, None)


__all__ = [
    "GodotOptionBinding",
    "GodotOptionBindingSet",
    "GodotOptionBindResult",
    "GodotOptionResolution",
]
