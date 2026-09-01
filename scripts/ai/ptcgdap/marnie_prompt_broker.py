from __future__ import annotations

import hashlib
from collections.abc import Mapping
from pathlib import Path, PurePosixPath
from types import MappingProxyType
from typing import Any
import weakref

from .cabt_selection import CabtSelectionSanitizer, CabtSelectionWindow
from .engine_decision_port import EngineDecisionPort
from .godot_option_binding import GodotOptionBinding
from .shadow_prompt_broker import ShadowPromptBroker
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


ROOT = Path(__file__).resolve().parents[3]
PROFILE_ID = "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
BUNDLE_ID = "ptcgdap-marnie-prompt-broker-bundle-p5-wp5-v1"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1"
EXPECTED_DOCUMENT_INTEGRITY_SHA256 = "24425ECEC54E9D1ED173ACC05639EA30DAE7F64035410A9C545F0213B15EDC25"
EXPECTED_ARTIFACTS = MappingProxyType({
    "schema": ("contracts/ptcgdap/marnie_prompt_broker.schema.json", "6D5942D4A319B78FFF9B49814A9661DD0CA99E4E3B531DF0B5A5E13FEBFF153A"),
    "profile": ("contracts/ptcgdap/marnie_prompt_broker_profile.json", "A136829945D95CC686FB7D5BBC705FF0ABB6387975CAA45191D0C3DA1B06E096"),
    "audit": ("data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json", "05A9AC6440B16EEC83C7FD42A360ADF481142C5EB313170CC407AF8A1CA6B393"),
    "vectors": ("contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json", "98CD8D6EB35469A74BD042DF00714AF5601E16F89E247FBAE2E9855830FB1391"),
})
PARENT_BUNDLES = MappingProxyType({
    "vertical_slice_bundle": ("contracts/ptcgdap/marnie_vertical_slice_bundle.json", "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"),
    "capability_policy_bundle": ("contracts/ptcgdap/marnie_capability_policy_bundle.json", "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"),
    "identity_projection_bundle": ("contracts/ptcgdap/marnie_identity_projection_bundle.json", "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4"),
    "shadow_prompt_broker_bundle": ("contracts/ptcgdap/shadow_prompt_broker_bundle.json", "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"),
    "engine_decision_port_bundle": ("contracts/ptcgdap/engine_decision_port_bundle.json", "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"),
    "godot_option_binding_bundle": ("contracts/ptcgdap/godot_option_binding_bundle.json", "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"),
})
LIFECYCLE_PREFIX = b"PTCGDAP\0MARNIE_PROMPT_LIFECYCLE_V1\0"
MAX_BYTES = 2 * 1024 * 1024
FACTORY_TOKEN = object()
FORBIDDEN_PUBLIC_KEYS = frozenset({
    "session_id", "callback_binding_hash", "current_source", "private_engine_command",
    "private_object_refs", "private_resolutions", "ticket", "preflight", "command",
})


class MarniePromptBrokerError(RuntimeError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_hash(value: Any) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _copy(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _copy(item) for key, item in value.items()}
    if type(value) in (list, tuple):
        return [_copy(item) for item in value]
    return value


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(item) for key, item in value.items()})
    if type(value) in (list, tuple):
        return tuple(_freeze(item) for item in value)
    return value


def _safe_relative(raw: Any) -> str:
    if type(raw) is not str or not raw or "\\" in raw or "\0" in raw:
        raise MarniePromptBrokerError("contract_integrity_invalid")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise MarniePromptBrokerError("contract_integrity_invalid")
    return raw


def _contained(root: Path, relative: str) -> Path:
    relative = _safe_relative(relative)
    resolved_root = root.resolve()
    candidate = (resolved_root / relative).resolve()
    try:
        candidate.relative_to(resolved_root)
    except ValueError as exc:
        raise MarniePromptBrokerError("contract_integrity_invalid") from exc
    return candidate


def _read_json_once(path: Path) -> tuple[Any, bytes]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise MarniePromptBrokerError("contract_integrity_invalid") from exc
    if not raw or len(raw) > MAX_BYTES:
        raise MarniePromptBrokerError("contract_integrity_invalid")
    try:
        return load_json_bytes_strict(raw), raw
    except (TypeError, UnicodeError, ValueError) as exc:
        raise MarniePromptBrokerError("contract_integrity_invalid") from exc


def _contains_forbidden(value: Any) -> bool:
    if type(value) is dict:
        return any(type(key) is not str or key in FORBIDDEN_PUBLIC_KEYS or _contains_forbidden(item) for key, item in value.items())
    if type(value) in (list, tuple):
        return any(_contains_forbidden(item) for item in value)
    return False


class _FixtureCapability:
    __slots__ = ("__weakref__", "frame_id", "position")

    def __init__(self, frame_id: str, position: int) -> None:
        self.frame_id = frame_id
        self.position = position


class MarniePromptBrokerResult:
    __slots__ = ("__weakref__", "_owner_ref", "_snapshot", "_snapshot_hash", "_factory_token")

    def __new__(cls, *_: Any, **__: Any) -> "MarniePromptBrokerResult":
        raise TypeError("MarniePromptBrokerResult is owner-produced")

    @classmethod
    def _from_owner(cls, owner: "MarniePromptBroker", snapshot: dict[str, Any]) -> "MarniePromptBrokerResult":
        result = object.__new__(cls)
        object.__setattr__(result, "_owner_ref", weakref.ref(owner))
        object.__setattr__(result, "_snapshot", _freeze(snapshot))
        object.__setattr__(result, "_snapshot_hash", _canonical_hash(snapshot))
        object.__setattr__(result, "_factory_token", FACTORY_TOKEN)
        return result

    def validate_integrity(self, owner: object) -> bool:
        if type(owner) is not MarniePromptBroker or self._owner_ref() is not owner or self._factory_token is not FACTORY_TOKEN:
            return False
        try:
            snapshot = _copy(self._snapshot)
            return owner._integrity_valid() and not _contains_forbidden(snapshot) and _canonical_hash(snapshot) == self._snapshot_hash and owner._result_valid(snapshot)
        except (AttributeError, TypeError, ValueError):
            return False

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not self.validate_integrity(owner):
            return {
                "accepted": False, "error_code": "contract_integrity_invalid",
                "frame_count": 0, "brokered_frame_count": 0,
                "initial_deck_frame_count": 0, "terminal_frame_count": 0,
                "serialized_private_resolution_count": 0,
                "extension_profile_id": PROFILE_ID, "lifecycle_chain_head": None,
                "frames": [], "production_actions_used": False, "execution_authority": False,
            }
        return _copy(self._snapshot)


class MarniePromptBroker:
    __slots__ = ("__weakref__", "_documents", "_frames", "_expected", "_document_integrity", "_construction_seal")

    def __new__(cls, *_: Any, **__: Any) -> "MarniePromptBroker":
        raise TypeError("use load_default() or load_trusted_bundle()")

    @classmethod
    def load_default(cls) -> "MarniePromptBroker":
        return cls.load_trusted_bundle(ROOT)

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarniePromptBroker":
        if not isinstance(repository_root, Path):
            raise MarniePromptBrokerError("contract_integrity_invalid")
        root = repository_root.resolve()
        bundle, _ = _read_json_once(_contained(root, "contracts/ptcgdap/marnie_prompt_broker_bundle.json"))
        if type(bundle) is not dict or _canonical_hash(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        if bundle.get("bundle_id") != BUNDLE_ID or bundle.get("profile_id") != PROFILE_ID or bundle.get("parent_contracts") != {key: value[1] for key, value in PARENT_BUNDLES.items()}:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        entries = bundle.get("artifacts")
        if type(entries) is not list or len(entries) != 4:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        documents: dict[str, Any] = {}
        seen: set[str] = set()
        for entry in entries:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise MarniePromptBrokerError("contract_integrity_invalid")
            artifact_id = entry["id"]
            if artifact_id in seen or artifact_id not in EXPECTED_ARTIFACTS:
                raise MarniePromptBrokerError("contract_integrity_invalid")
            path, digest = EXPECTED_ARTIFACTS[artifact_id]
            if entry != {"id": artifact_id, "path": path, "canonical_sha256": digest}:
                raise MarniePromptBrokerError("contract_integrity_invalid")
            document, _ = _read_json_once(_contained(root, path))
            if _canonical_hash(document) != digest:
                raise MarniePromptBrokerError("contract_integrity_invalid")
            documents[artifact_id] = document
            seen.add(artifact_id)
        if seen != set(EXPECTED_ARTIFACTS):
            raise MarniePromptBrokerError("contract_integrity_invalid")
        for parent_id, (path, digest) in PARENT_BUNDLES.items():
            parent, _ = _read_json_once(_contained(root, path))
            if _canonical_hash(parent) != digest or documents["profile"]["parent_contracts"].get(parent_id) != digest:
                raise MarniePromptBrokerError("contract_integrity_invalid")
        cls._validate_documents(documents)
        document_integrity = _canonical_hash(documents)
        if document_integrity != EXPECTED_DOCUMENT_INTEGRITY_SHA256:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        owner = object.__new__(cls)
        object.__setattr__(owner, "_documents", _freeze(documents))
        frames = documents["audit"]["frames"]
        object.__setattr__(owner, "_frames", MappingProxyType({item["frame_id"]: _freeze(item) for item in frames}))
        object.__setattr__(owner, "_expected", _freeze(documents["audit"]["expected_public_result"]))
        object.__setattr__(owner, "_document_integrity", document_integrity)
        object.__setattr__(owner, "_construction_seal", FACTORY_TOKEN)
        return owner

    @staticmethod
    def _validate_documents(documents: dict[str, Any]) -> None:
        profile, audit, vectors = documents["profile"], documents["audit"], documents["vectors"]
        if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        if type(audit) is not dict or audit.get("profile_id") != PROFILE_ID or audit.get("audit_id") != "ptcgdap-marnie-prompt-broker-audit-p5-wp5-v1":
            raise MarniePromptBrokerError("contract_integrity_invalid")
        frames = audit.get("frames")
        if type(frames) is not list or len(frames) != 13 or [item.get("frame_id") for item in frames if type(item) is dict] != profile.get("frame_order"):
            raise MarniePromptBrokerError("contract_integrity_invalid")
        if sum(item.get("window") is not None for item in frames) != 11:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        if frames[0].get("window") is not None or not frames[-1].get("terminal") or frames[-1].get("window") is not None:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        if frames[3].get("option_types") != [8, 8, 7, 14] or frames[8].get("option_types") != [7, 13, 12, 14]:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        cases = vectors.get("cases") if type(vectors) is dict else None
        if type(cases) is not list or len(cases) != 23 or len({item.get("case_id") for item in cases if type(item) is dict}) != 23:
            raise MarniePromptBrokerError("contract_integrity_invalid")
        if audit.get("production_actions_used") is not False or audit.get("execution_authority") is not False:
            raise MarniePromptBrokerError("contract_integrity_invalid")

    def _integrity_valid(self) -> bool:
        try:
            documents = _copy(self._documents)
            expected_frames = {
                item["frame_id"]: item for item in documents["audit"]["frames"]
            }
            actual_frames = _copy(self._frames)
            return (
                self._construction_seal is FACTORY_TOKEN
                and self._document_integrity == EXPECTED_DOCUMENT_INTEGRITY_SHA256
                and _canonical_hash(documents) == EXPECTED_DOCUMENT_INTEGRITY_SHA256
                and isinstance(self._frames, MappingProxyType)
                and actual_frames == expected_frames
                and _canonical_hash(_copy(self._expected)) == _canonical_hash(documents["audit"]["expected_public_result"])
            )
        except (AttributeError, TypeError, ValueError):
            return False

    def _require_integrity(self) -> None:
        if not self._integrity_valid():
            raise MarniePromptBrokerError("contract_integrity_invalid")

    def _execute(self, target_ordinal: int = 12) -> list[dict[str, Any]]:
        self._require_integrity()
        if type(target_ordinal) is not int or not 0 <= target_ordinal <= 12:
            raise MarniePromptBrokerError("frame_unknown")
        port = EngineDecisionPort(1)
        binding_owner = GodotOptionBinding()
        broker = ShadowPromptBroker(1, "session:marnie-p5-wp5-offline")
        actual_frames: list[dict[str, Any]] = []
        previous_hash: str | None = None
        previous_snapshot: str | None = None
        previous_window: str | None = None
        previous_binding: int | None = None
        for ordinal in range(target_ordinal + 1):
            frame = _copy(self._documents["audit"]["frames"][ordinal])
            expected = frame["expected_public_result"]
            window_document = frame["window"]
            if window_document is None:
                actual = {key: _copy(value) for key, value in expected.items() if key not in {"previous_lifecycle_hash", "lifecycle_hash"}}
            else:
                select_payload = {
                    "type": window_document["select_type_raw"], "context": window_document["select_context_raw"],
                    "minCount": window_document["min_count"], "maxCount": window_document["max_count"],
                    "remainDamageCounter": window_document["remain_damage_counter"],
                    "remainEnergyCost": window_document["remain_energy_cost"],
                    "option": window_document["options"], "deck": window_document["public_deck_candidates"],
                    "contextCard": window_document["context_card"], "effect": window_document["effect"],
                }
                built = CabtSelectionWindow.build(
                    select_payload,
                    public_observation_hash=window_document["public_observation_hash"],
                    public_hash_authority=window_document["public_hash_authority"],
                    chooser_player_index=window_document["chooser_player_index"],
                )
                window = built.window
                if built.decision_state != "policy_allowed" or window is None or window.to_public_dict() != window_document:
                    raise MarniePromptBrokerError("lifecycle_rejected")
                source = frame["source"]
                generation = expected["decision_generation"]
                published = port.publish_p5_extended(source, generation, window.chooser_player_index, PROFILE_ID)
                if not published.accepted or published.snapshot is None or not published.validate_integrity(port):
                    raise MarniePromptBrokerError("lifecycle_rejected")
                snapshot = published.snapshot
                if snapshot.snapshot_id == previous_snapshot or window.window_id == previous_window:
                    raise MarniePromptBrokerError("lifecycle_rejected")
                commands = [_FixtureCapability(frame["frame_id"], index) for index in range(window.option_count)]
                bound = binding_owner.bind_p5_extended(
                    port=port, snapshot=snapshot, current_source=source, window=window,
                    callback_binding_hash=frame["callback_binding_hash"], private_commands=commands,
                    private_object_refs=[[] for _ in commands], extension_profile_id=PROFILE_ID,
                )
                if not bound.accepted or bound.binding is None or not bound.validate_integrity(binding_owner):
                    raise MarniePromptBrokerError("lifecycle_rejected")
                if bound.binding.binding_version == previous_binding:
                    raise MarniePromptBrokerError("lifecycle_rejected")
                opened = broker.open_prompt(
                    prompt_family=frame["window_family"], port=port, snapshot=snapshot,
                    binding_owner=binding_owner, binding=bound.binding, current_source=source,
                    window=window, callback_binding_hash=frame["callback_binding_hash"],
                )
                if not opened.accepted or opened.prompt is None or not opened.validate_integrity(broker):
                    raise MarniePromptBrokerError("lifecycle_rejected")
                resolution = CabtSelectionSanitizer.resolve_policy_attempt(window, frame["policy_selected_indexes"])
                if not resolution.validate_integrity(window) or list(resolution.selected_indexes) != frame["policy_selected_indexes"]:
                    raise MarniePromptBrokerError("lifecycle_rejected")
                prepared = broker.prepare_selection(opened.prompt, resolution)
                if not prepared.accepted or not prepared.validate_integrity(broker):
                    raise MarniePromptBrokerError("lifecycle_rejected")
                committed = broker.commit_prompt(opened.prompt)
                committed_public = committed.to_public_dict()
                if not committed.accepted or not committed.validate_integrity(broker) or committed_public.get("audit", {}).get("state") != "awaiting_reobserve":
                    raise MarniePromptBrokerError("lifecycle_rejected")
                actual = {
                    "ordinal": ordinal, "frame_id": frame["frame_id"], "window_family": frame["window_family"],
                    "callback_role": frame["callback_role"], "status": "committed_shadow",
                    "decision_generation": snapshot.decision_generation,
                    "broker_generation": committed_public["audit"]["broker_generation"],
                    "snapshot_id": snapshot.snapshot_id, "source_digest": snapshot.source_digest,
                    "window_id": window.window_id, "binding_version": bound.binding.binding_version,
                    "option_count": window.option_count, "option_types": [option["type"] for option in window.options],
                    "selected_indexes": list(resolution.selected_indexes),
                    "committed_resolution_count": committed_public["audit"]["resolution_count"],
                    "serialized_private_resolution_count": 0, "broker_state": committed_public["audit"]["state"],
                    "extension_profile_id": PROFILE_ID, "production_action_used": False, "execution_authority": False,
                }
                previous_snapshot = snapshot.snapshot_id
                previous_window = window.window_id
                previous_binding = bound.binding.binding_version
            lifecycle_payload = _copy(actual)
            lifecycle_payload["previous_lifecycle_hash"] = previous_hash
            lifecycle_hash = _sha(LIFECYCLE_PREFIX + canonical_json_v1_bytes(lifecycle_payload))
            actual["previous_lifecycle_hash"] = previous_hash
            actual["lifecycle_hash"] = lifecycle_hash
            previous_hash = lifecycle_hash
            if actual != expected:
                raise MarniePromptBrokerError("lifecycle_rejected")
            actual_frames.append(actual)
        return actual_frames

    def evaluate_all(self) -> MarniePromptBrokerResult:
        frames = self._execute(12)
        snapshot = {
            "accepted": True, "error_code": "", "frame_count": 13,
            "brokered_frame_count": 11, "initial_deck_frame_count": 1,
            "terminal_frame_count": 1, "serialized_private_resolution_count": 0,
            "extension_profile_id": PROFILE_ID, "lifecycle_chain_head": frames[-1]["lifecycle_hash"],
            "frames": frames, "production_actions_used": False, "execution_authority": False,
        }
        if snapshot != _copy(self._expected):
            raise MarniePromptBrokerError("lifecycle_rejected")
        return MarniePromptBrokerResult._from_owner(self, snapshot)

    def evaluate_frame(self, frame_id: Any) -> MarniePromptBrokerResult:
        self._require_integrity()
        if type(frame_id) is not str:
            raise MarniePromptBrokerError("input_type_invalid")
        frame = self._frames.get(frame_id)
        if frame is None:
            raise MarniePromptBrokerError("frame_unknown")
        frames = self._execute(frame["ordinal"])
        chosen = frames[-1]
        snapshot = {
            "accepted": True, "error_code": "", "frame_count": 1,
            "brokered_frame_count": 1 if chosen["status"] == "committed_shadow" else 0,
            "initial_deck_frame_count": 1 if chosen["status"] == "initial_deck_fixture" else 0,
            "terminal_frame_count": 1 if chosen["status"] == "terminal_no_callback" else 0,
            "serialized_private_resolution_count": 0, "extension_profile_id": PROFILE_ID,
            "lifecycle_chain_head": chosen["lifecycle_hash"], "frames": [chosen],
            "production_actions_used": False, "execution_authority": False,
        }
        return MarniePromptBrokerResult._from_owner(self, snapshot)

    def _result_valid(self, snapshot: dict[str, Any]) -> bool:
        if type(snapshot) is not dict or set(snapshot) != {
            "accepted", "error_code", "frame_count", "brokered_frame_count",
            "initial_deck_frame_count", "terminal_frame_count", "serialized_private_resolution_count",
            "extension_profile_id", "lifecycle_chain_head", "frames", "production_actions_used", "execution_authority",
        }:
            return False
        frames = snapshot["frames"]
        return (
            snapshot["accepted"] is True and snapshot["error_code"] == ""
            and type(frames) is list and snapshot["frame_count"] == len(frames) in {1, 13}
            and snapshot["serialized_private_resolution_count"] == 0
            and snapshot["extension_profile_id"] == PROFILE_ID
            and snapshot["production_actions_used"] is False and snapshot["execution_authority"] is False
            and not _contains_forbidden(snapshot)
            and all(frame == _copy(self._frames[frame["frame_id"]]["expected_public_result"]) for frame in frames)
        )

    def run(self, operation: Any, input_value: Any) -> dict[str, Any]:
        try:
            self._require_integrity()
            if type(operation) is not str:
                raise MarniePromptBrokerError("input_type_invalid")
            if operation == "evaluate_frame":
                result = self.evaluate_frame(input_value)
                return {"ok": True, "error_code": "", "value": result.to_public_dict()["frames"][0]}
            if operation == "evaluate_all":
                if input_value is not None:
                    raise MarniePromptBrokerError("input_type_invalid")
                return {"ok": True, "error_code": "", "value": self.evaluate_all().to_public_dict()}
            if operation == "audit_snapshot":
                if input_value is not None:
                    raise MarniePromptBrokerError("input_type_invalid")
                return {"ok": True, "error_code": "", "value": self.audit_snapshot()}
            raise MarniePromptBrokerError("operation_unknown")
        except MarniePromptBrokerError as exc:
            return {"ok": False, "error_code": exc.code, "value": None}

    def bundle_hash(self) -> str:
        self._require_integrity()
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def audit_snapshot(self) -> dict[str, Any]:
        self._require_integrity()
        return _copy(self._documents["audit"]["summary"])


def load_default() -> MarniePromptBroker:
    return MarniePromptBroker.load_default()


__all__ = ["MarniePromptBroker", "MarniePromptBrokerError", "MarniePromptBrokerResult", "load_default"]
