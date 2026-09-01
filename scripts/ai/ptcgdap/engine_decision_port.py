from __future__ import annotations

import hashlib
import json
import weakref
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any

from .source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
EXPECTED_BUNDLE_SHA256 = "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"
EXPECTED_ARTIFACTS = MappingProxyType({
    "schema": ("contracts/ptcgdap/engine_decision_port.schema.json", "8EF3CBA573647B49535AFA46A980991CBBE22C001F0CD5CCD765305A73214914"),
    "profile": ("contracts/ptcgdap/engine_decision_port_profile.json", "39ACEB7EA9E61FAACE04160364B4CA82B98D4991A34CAA701A3A2310FC55F238"),
    "vectors": ("contracts/ptcgdap/engine_decision_port_conformance_vectors.json", "27EF66FBE19D37A19A8AA95662BEF1E06BC29283DEBF6D87CB03569139294D8D"),
})
SAFE_MAX = 9007199254740991
SOURCE_PREFIX = bytes.fromhex("5054434744415000454E47494E455F4445434953494F4E5F534F555243455F563100")
SNAPSHOT_PREFIX = bytes.fromhex("5054434744415000454E47494E455F4445434953494F4E5F534E415053484F545F563100")
SOURCE_KEYS = frozenset({"select", "deck_cards", "context_card", "effect_card", "option_card_refs", "turn_action_count"})
SELECT_KEYS = frozenset({"type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck", "contextCard", "effect"})
OPTION_SHAPES = MappingProxyType({3: frozenset({"type"}), 7: frozenset({"type", "index"}), 13: frozenset({"type", "local_attack_index"}), 14: frozenset({"type"}), 15: frozenset({"type"})})
P5_EXTENSION_PROFILE_ID = "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
P5_OPTION_SHAPES = MappingProxyType({
    3: frozenset({"type"}),
    7: frozenset({"type", "index"}),
    8: frozenset({"type", "area", "index", "inPlayArea", "inPlayIndex"}),
    12: frozenset({"type"}),
    13: frozenset({"type", "local_attack_index", "official_attack_id"}),
    14: frozenset({"type"}),
    15: frozenset({"type"}),
})


def _hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def _load_contract() -> dict[str, Any]:
    bundle_path = CONTRACT_ROOT / "engine_decision_port_bundle.json"
    bundle = load_json_strict(bundle_path)
    if _hash(bundle) != EXPECTED_BUNDLE_SHA256:
        raise RuntimeError("decision port bundle trust-anchor mismatch")
    entries = bundle.get("artifacts")
    if type(entries) is not list or len(entries) != 3:
        raise RuntimeError("decision port bundle shape mismatch")
    for entry in entries:
        artifact_id = entry.get("id") if type(entry) is dict else None
        if artifact_id not in EXPECTED_ARTIFACTS:
            raise RuntimeError("decision port bundle artifact mismatch")
        path, digest = EXPECTED_ARTIFACTS[artifact_id]
        if entry != {"id": artifact_id, "path": path, "canonical_sha256": digest}:
            raise RuntimeError("decision port bundle binding mismatch")
        if _hash(load_json_strict(ROOT / path)) != digest:
            raise RuntimeError("decision port artifact hash mismatch")
    return load_json_strict(CONTRACT_ROOT / "engine_decision_port_profile.json")


PROFILE = _load_contract()
ERROR_CODES = frozenset(PROFILE["error_codes"])


def _exact_nonnegative(value: Any) -> bool:
    return type(value) is int and 0 <= value <= SAFE_MAX


def _exact_positive(value: Any) -> bool:
    return type(value) is int and 1 <= value <= SAFE_MAX


def _copy_json(value: Any) -> Any:
    if type(value) is dict:
        return {key: _copy_json(item) for key, item in value.items()}
    if type(value) is list:
        return [_copy_json(item) for item in value]
    return value


def _reference(value: Any) -> weakref.ReferenceType[Any] | None:
    if value is None or type(value) in {dict, list, str, int, bool, float, bytes, tuple}:
        return None
    try:
        return weakref.ref(value)
    except TypeError:
        return None


@dataclass(frozen=True, slots=True)
class EngineDecisionSnapshot:
    match_generation: int
    decision_generation: int
    chooser_player_index: int
    snapshot_id: str
    source_digest: str
    _audit: dict[str, Any]
    _owner_ref: weakref.ReferenceType["EngineDecisionPort"]
    _binding_id: int

    def to_audit_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not owner._snapshot_fields_valid(self):
            return {}
        return _copy_json(self._audit)

    def validate_integrity(self, port: "EngineDecisionPort") -> bool:
        return type(port) is EngineDecisionPort and port._validate_snapshot(self)[0]


@dataclass(frozen=True, slots=True)
class EngineDecisionPublishResult:
    accepted: bool
    error_code: str
    snapshot: EngineDecisionSnapshot | None
    _owner_ref: weakref.ReferenceType["EngineDecisionPort"]

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not self.validate_integrity(owner):
            return {"accepted": False, "error_code": "snapshot_integrity_invalid", "audit": None}
        return {"accepted": self.accepted, "error_code": self.error_code, "audit": None if self.snapshot is None else self.snapshot.to_audit_dict()}

    def validate_integrity(self, port: "EngineDecisionPort") -> bool:
        if type(port) is not EngineDecisionPort or self._owner_ref() is not port:
            return False
        if self.accepted:
            return self.error_code == "" and self.snapshot is not None and port._validate_snapshot(self.snapshot)[0]
        return self.snapshot is None and self.error_code in ERROR_CODES and self.error_code != ""


@dataclass(slots=True)
class _Binding:
    binding_id: int
    descriptor: dict[str, Any]
    references: tuple[weakref.ReferenceType[Any], ...]
    extension_profile_id: str = ""


class EngineDecisionPort:
    __slots__ = ("__weakref__", "_match_generation", "_last_generation", "_current", "_binding_counter")

    def __init__(self, match_generation: Any) -> None:
        self._match_generation = match_generation
        self._last_generation = 0
        self._current: tuple[EngineDecisionSnapshot, _Binding] | None = None
        self._binding_counter = 0

    @property
    def match_generation(self) -> Any:
        return self._match_generation

    def publish(self, source: Any, decision_generation: Any, chooser_player_index: Any) -> EngineDecisionPublishResult:
        return self._publish(source, decision_generation, chooser_player_index, "")

    def publish_p5_extended(
        self,
        source: Any,
        decision_generation: Any,
        chooser_player_index: Any,
        extension_profile_id: Any,
    ) -> EngineDecisionPublishResult:
        if type(extension_profile_id) is not str or extension_profile_id != P5_EXTENSION_PROFILE_ID:
            return self._rejected("invalid_decision_source")
        return self._publish(source, decision_generation, chooser_player_index, extension_profile_id)

    def _publish(
        self,
        source: Any,
        decision_generation: Any,
        chooser_player_index: Any,
        extension_profile_id: str,
    ) -> EngineDecisionPublishResult:
        if not _exact_positive(self._match_generation):
            return self._rejected("invalid_match_generation")
        if not _exact_positive(decision_generation):
            return self._rejected("invalid_decision_generation")
        if type(chooser_player_index) is not int or chooser_player_index not in (0, 1):
            return self._rejected("invalid_chooser_player_index")
        if decision_generation <= self._last_generation:
            return self._rejected("stale_decision_generation")
        code, descriptor, references = (
            self._analyze_source_p5(source)
            if extension_profile_id == P5_EXTENSION_PROFILE_ID
            else self._analyze_source(source)
        )
        if code:
            return self._rejected(code)
        source_digest = hashlib.sha256(SOURCE_PREFIX + canonical_json_v1_bytes(descriptor)).hexdigest().upper()
        snapshot_payload = {
            "match_generation": self._match_generation,
            "decision_generation": decision_generation,
            "chooser_player_index": chooser_player_index,
            "source_digest": source_digest,
        }
        snapshot_id = hashlib.sha256(SNAPSHOT_PREFIX + canonical_json_v1_bytes(snapshot_payload)).hexdigest().upper()
        self._binding_counter += 1
        audit = {
            **snapshot_payload,
            "snapshot_id": snapshot_id,
            "select": _copy_json(descriptor["select"]),
            "turn_action_count": descriptor["turn_action_count"],
            "reference_count": len(references),
            "authority": "engine_decision_port_shadow",
            "authoritative": False,
        }
        snapshot = EngineDecisionSnapshot(
            self._match_generation, decision_generation, chooser_player_index,
            snapshot_id, source_digest, audit, weakref.ref(self), self._binding_counter,
        )
        binding = _Binding(self._binding_counter, descriptor, references, extension_profile_id)
        self._last_generation = decision_generation
        self._current = (snapshot, binding)
        return EngineDecisionPublishResult(True, "", snapshot, weakref.ref(self))

    def rebind(self, snapshot: Any, current_source: Any) -> dict[str, Any]:
        valid, code = self._validate_snapshot(snapshot)
        if not valid:
            return {"ok": False, "error_code": code, "value": None}
        assert self._current is not None
        binding = self._current[1]
        analysis_code, descriptor, references = (
            self._analyze_source_p5(current_source)
            if binding.extension_profile_id == P5_EXTENSION_PROFILE_ID
            else self._analyze_source(current_source)
        )
        if analysis_code:
            code = "reference_released" if analysis_code == "reference_released" else "source_mutated"
            return {"ok": False, "error_code": code, "value": None}
        if descriptor != binding.descriptor or len(references) != len(binding.references):
            return {"ok": False, "error_code": "source_mutated", "value": None}
        for current, expected in zip(references, binding.references, strict=True):
            current_value, expected_value = current(), expected()
            if expected_value is None:
                return {"ok": False, "error_code": "reference_released", "value": None}
            if current_value is not expected_value:
                return {"ok": False, "error_code": "source_mutated", "value": None}
        return {"ok": True, "error_code": "", "value": self._copy_source(current_source)}

    def current_snapshot(self) -> EngineDecisionSnapshot | None:
        return None if self._current is None else self._current[0]

    def _rejected(self, code: str) -> EngineDecisionPublishResult:
        return EngineDecisionPublishResult(False, code, None, weakref.ref(self))

    def _snapshot_fields_valid(self, snapshot: EngineDecisionSnapshot) -> bool:
        if self._current is None or self._current[0] is not snapshot or self._current[1].binding_id != snapshot._binding_id:
            return False
        binding = self._current[1]
        payload = {
            "match_generation": snapshot.match_generation,
            "decision_generation": snapshot.decision_generation,
            "chooser_player_index": snapshot.chooser_player_index,
            "source_digest": snapshot.source_digest,
        }
        expected_id = hashlib.sha256(SNAPSHOT_PREFIX + canonical_json_v1_bytes(payload)).hexdigest().upper()
        return snapshot.snapshot_id == expected_id and snapshot._audit == {
            **payload,
            "snapshot_id": expected_id,
            "select": _copy_json(binding.descriptor["select"]),
            "turn_action_count": binding.descriptor["turn_action_count"],
            "reference_count": len(binding.references),
            "authority": "engine_decision_port_shadow",
            "authoritative": False,
        }

    def _validate_snapshot(self, snapshot: Any) -> tuple[bool, str]:
        if type(snapshot) is not EngineDecisionSnapshot:
            return False, "snapshot_integrity_invalid"
        if snapshot._owner_ref() is not self:
            return False, "snapshot_owner_mismatch"
        if snapshot.match_generation != self._match_generation:
            return False, "stale_match_generation"
        if self._current is None or self._current[0] is not snapshot or self._current[1].binding_id != snapshot._binding_id:
            return False, "snapshot_not_current"
        if not self._snapshot_fields_valid(snapshot):
            return False, "snapshot_integrity_invalid"
        return True, ""

    def _analyze_source(self, source: Any) -> tuple[str, dict[str, Any], tuple[weakref.ReferenceType[Any], ...]]:
        return self._analyze_source_with_shapes(source, OPTION_SHAPES, False)

    def _analyze_source_p5(self, source: Any) -> tuple[str, dict[str, Any], tuple[weakref.ReferenceType[Any], ...]]:
        return self._analyze_source_with_shapes(source, P5_OPTION_SHAPES, True)

    def _analyze_source_with_shapes(
        self,
        source: Any,
        option_shapes: MappingProxyType[int, frozenset[str]],
        p5_extended: bool,
    ) -> tuple[str, dict[str, Any], tuple[weakref.ReferenceType[Any], ...]]:
        if type(source) is not dict or set(source) != SOURCE_KEYS:
            return "invalid_decision_source", {}, ()
        if not _exact_nonnegative(source["turn_action_count"]):
            return "invalid_decision_source", {}, ()
        option_refs = source["option_card_refs"]
        if type(option_refs) is not list:
            return "invalid_decision_source", {}, ()
        select = source["select"]
        if select is None:
            if option_refs or source["deck_cards"] is not None or source["context_card"] is not None or source["effect_card"] is not None:
                return "invalid_decision_source", {}, ()
            return "", {"select": None, "turn_action_count": source["turn_action_count"]}, ()
        if type(select) is not dict or set(select) != SELECT_KEYS:
            return "invalid_select", {}, ()
        for key in ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost"]:
            if not _exact_nonnegative(select[key]):
                return "invalid_select", {}, ()
        if select["deck"] is not None or select["contextCard"] is not None or select["effect"] is not None:
            return "invalid_select", {}, ()
        options = select["option"]
        if type(options) is not list or len(options) > 256 or len(options) != len(option_refs):
            return "invalid_select", {}, ()
        if select["minCount"] > select["maxCount"] or select["maxCount"] > len(options):
            return "invalid_select", {}, ()
        reference_list: list[weakref.ReferenceType[Any]] = []
        audit_options: list[dict[str, Any]] = []
        for position, (option, reference_value) in enumerate(zip(options, option_refs, strict=True)):
            if type(option) is not dict or type(option.get("type")) is not int or option.get("type") not in option_shapes or set(option) != option_shapes[option["type"]]:
                return "invalid_option_source", {}, ()
            option_type = option["type"]
            if option_type == 7 and not _exact_nonnegative(option["index"]):
                return "invalid_option_source", {}, ()
            if option_type == 8 and (
                not p5_extended
                or any(not _exact_nonnegative(option[key]) for key in ("area", "index", "inPlayArea", "inPlayIndex"))
            ):
                return "invalid_option_source", {}, ()
            if option_type == 13 and (
                not _exact_nonnegative(option["local_attack_index"])
                or (p5_extended and not _exact_nonnegative(option["official_attack_id"]))
            ):
                return "invalid_option_source", {}, ()
            if option_type == 12 and not p5_extended:
                return "invalid_option_source", {}, ()
            reference_token: str | None = None
            if option_type == 15:
                ref = _reference(reference_value)
                if ref is None:
                    return "invalid_reference", {}, ()
                reference_list.append(ref)
                reference_token = "card_reference"
            elif reference_value is not None:
                return "invalid_reference", {}, ()
            audit_options.append({"position": position, "option": _copy_json(option), "reference_token": reference_token})
        deck_tokens, code = self._analyze_reference_collection(source["deck_cards"], reference_list, 120)
        if code:
            return code, {}, ()
        context_token, code = self._analyze_single_reference(source["context_card"], reference_list)
        if code:
            return code, {}, ()
        effect_token, code = self._analyze_single_reference(source["effect_card"], reference_list)
        if code:
            return code, {}, ()
        if len(reference_list) > 384:
            return "invalid_reference", {}, ()
        audit_select = {
            "type": select["type"], "context": select["context"], "minCount": select["minCount"], "maxCount": select["maxCount"],
            "remainDamageCounter": select["remainDamageCounter"], "remainEnergyCost": select["remainEnergyCost"],
            "option": audit_options, "deck_tokens": deck_tokens, "context_token": context_token, "effect_token": effect_token,
        }
        return "", {"select": audit_select, "turn_action_count": source["turn_action_count"]}, tuple(reference_list)

    @staticmethod
    def _analyze_reference_collection(value: Any, references: list[weakref.ReferenceType[Any]], limit: int) -> tuple[list[str] | None, str]:
        if value is None:
            return None, ""
        if type(value) is not list or len(value) > limit:
            return None, "invalid_reference"
        tokens = []
        for item in value:
            ref = _reference(item)
            if ref is None:
                return None, "invalid_reference"
            references.append(ref)
            tokens.append("card_reference")
        return tokens, ""

    @staticmethod
    def _analyze_single_reference(value: Any, references: list[weakref.ReferenceType[Any]]) -> tuple[str | None, str]:
        if value is None:
            return None, ""
        ref = _reference(value)
        if ref is None:
            return None, "invalid_reference"
        references.append(ref)
        return "card_reference", ""

    @staticmethod
    def _copy_source(source: dict[str, Any]) -> dict[str, Any]:
        return {
            "select": None if source["select"] is None else _copy_json(source["select"]),
            "deck_cards": None if source["deck_cards"] is None else list(source["deck_cards"]),
            "context_card": source["context_card"],
            "effect_card": source["effect_card"],
            "option_card_refs": list(source["option_card_refs"]),
            "turn_action_count": source["turn_action_count"],
        }


__all__ = ["EngineDecisionPort", "EngineDecisionPublishResult", "EngineDecisionSnapshot"]
