"""Bundle-bound, offline-only replay of the P5 Marnie public trajectory.

The replay result is an audit/conformance DTO.  It does not grant selection or
execution authority and this module has no live Host or engine consumer.
"""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import struct
from types import MappingProxyType
from typing import Any, Mapping

from .cabt_envelope import parse_raw_cabt_json_bytes
from .cabt_selection import build_cabt_selection_window
from .marnie_vertical_slice import MarnieVerticalSlice, MarnieVerticalSliceError
from .public_observation_firewall import (
    EXPECTED_FIREWALL_BUNDLE_SHA256,
    PublicObservationFirewall,
)
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict, sha256_bytes


_MAX_JSON_BYTES = 2 * 1024 * 1024
_SHA256_RE = re.compile(r"^[0-9A-F]{64}$")
_EXPECTED_BUNDLE_CANONICAL_SHA256 = (
    "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
)
_EXPECTED_RUNTIME_INTEGRITY_SHA256 = (
    "83913228EA51F82F57A39A9B4D01EF27AEF069D64B30BE073EB041F5B9E554FD"
)
_EXPECTED_PARENT_FIXTURE_SHA256 = (
    "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
)
_EXPECTED_ARTIFACTS = (
    ("marnie_trajectory_replay.schema", "contracts/ptcgdap/marnie_trajectory_replay.schema.json", "schema"),
    ("marnie_trajectory_replay_profile_v1", "contracts/ptcgdap/marnie_trajectory_replay_profile.json", "profile"),
    ("marnie_trajectory_replay_conformance_v1", "contracts/ptcgdap/marnie_trajectory_replay_conformance_vectors.json", "vectors"),
    ("w0_w7_firewall_replay_v1", "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json", "replay"),
)
_FRAME_IDS = (
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
    "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
    "w5_punk_up_target_2", "w6_shadow_bullet_attack",
    "w6_shadow_bullet_target", "w7_take_prize", "w7_forced_send_out",
    "w7_terminal",
)
_CHAIN_PREFIX = b"PTCGDAP\0MARNIE_TRAJECTORY_REPLAY_V1\0"
_CONSTRUCTION_TOKEN = object()


class MarnieTrajectoryReplayError(RuntimeError):
    """Stable fail-closed error that never echoes supplied values."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


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


def _contained_path(root: Path, relative: str) -> Path:
    if type(relative) is not str or not relative or "\\" in relative:
        raise MarnieTrajectoryReplayError("replay_path_invalid")
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except (OSError, ValueError, RuntimeError) as exc:
        raise MarnieTrajectoryReplayError("replay_path_invalid") from exc
    return candidate


def _read_json_once(path: Path) -> tuple[Any, bytes]:
    try:
        data = path.read_bytes()
    except OSError as exc:
        raise MarnieTrajectoryReplayError("replay_file_missing") from exc
    if len(data) > _MAX_JSON_BYTES:
        raise MarnieTrajectoryReplayError("replay_file_too_large")
    try:
        return load_json_bytes_strict(data), data
    except (UnicodeError, ValueError) as exc:
        raise MarnieTrajectoryReplayError("replay_json_invalid") from exc


def _runtime_integrity_digest(documents: Mapping[str, Any]) -> str:
    return sha256_bytes(
        canonical_json_v1_bytes(
            {key: _thaw(documents[key]) for key in ("bundle", "schema", "profile", "vectors", "replay")}
        )
    )


def _decode_node(node: Any) -> Any:
    if node is None:
        return None
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise MarnieTrajectoryReplayError("parent_frame_invalid")
    kind = node["kind"]
    if kind == "null":
        return None
    if kind in {"boolean", "integer", "string"}:
        return node.get("value")
    if kind == "binary64":
        try:
            return struct.unpack(">d", bytes.fromhex(node["ieee754_hex"]))[0]
        except (KeyError, TypeError, ValueError, struct.error) as exc:
            raise MarnieTrajectoryReplayError("parent_frame_invalid") from exc
    if kind == "array" and type(node.get("items")) is list:
        return [_decode_node(child) for child in node["items"]]
    if kind == "object" and type(node.get("entries")) is list:
        result: dict[str, Any] = {}
        for entry in node["entries"]:
            if type(entry) is not dict or type(entry.get("key")) is not str or entry["key"] in result:
                raise MarnieTrajectoryReplayError("parent_frame_invalid")
            result[entry["key"]] = _decode_node(entry.get("value"))
        return result
    raise MarnieTrajectoryReplayError("parent_frame_invalid")


def _raw_bytes(public_tree: dict[str, Any]) -> bytes:
    raw = deepcopy(public_tree)
    raw["search_begin_input"] = None
    try:
        return json.dumps(raw, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")
    except (TypeError, ValueError, UnicodeError) as exc:
        raise MarnieTrajectoryReplayError("parent_frame_invalid") from exc


def _witness(payload: dict[str, Any]) -> str:
    return hashlib.sha256(_CHAIN_PREFIX + canonical_json_v1_bytes(payload)).hexdigest().upper()


def _frame_summary(
    parent_owner: MarnieVerticalSlice,
    firewall: PublicObservationFirewall,
    frame_id: str,
    ordinal: int,
    previous_witness: str | None,
) -> dict[str, Any]:
    try:
        parent = parent_owner.frame(frame_id)
    except MarnieVerticalSliceError as exc:
        raise MarnieTrajectoryReplayError("parent_frame_invalid") from exc
    if parent["public_tree"] is None:
        if parent["terminal"] != {
            "new_callback_expected": False,
            "final_step": 145,
            "both_seats_done": True,
        } or parent["window"] is not None:
            raise MarnieTrajectoryReplayError("parent_frame_invalid")
        summary = {
            "ordinal": ordinal, "frame_id": frame_id,
            "source_replay_id": parent["source_replay_id"], "source_step": parent["source_step"],
            "source_seat": parent["source_seat"], "firewall_status": "not_applicable_terminal",
            "compatibility_rule": None, "public_observation_hash": None,
            "public_hash_authority": None, "window_id": None, "option_count": 0,
            "option_fingerprints": [], "own_active": None, "terminal": True,
            "previous_witness": previous_witness,
        }
        summary["witness_hash"] = _witness(summary)
        return summary

    public_tree = _decode_node(parent["public_tree"])
    if type(public_tree) is not dict:
        raise MarnieTrajectoryReplayError("parent_frame_invalid")
    parsed = parse_raw_cabt_json_bytes(_raw_bytes(public_tree))
    if not parsed.policy_eligible:
        raise MarnieTrajectoryReplayError("parent_frame_invalid")
    base = firewall.project(parsed)
    evaluation = firewall._evaluate_setup_bench_concealment(parsed)
    if evaluation.get("status") != "accepted" or evaluation.get("public_observation") != public_tree:
        raise MarnieTrajectoryReplayError("firewall_replay_mismatch")
    if evaluation.get("public_observation_hash") != parent["public_observation_hash"]:
        raise MarnieTrajectoryReplayError("firewall_replay_mismatch")

    compatibility = "setup_bench_concealment_v1" if frame_id == "w2_setup_bench" else None
    if evaluation.get("compatibility_rule") != compatibility:
        raise MarnieTrajectoryReplayError("base_firewall_compatibility_mismatch")
    if compatibility is not None:
        if base.status != "rejected" or base.issues != [
            {"code":"own_active_concealed","pointer":"/current/players/0/active","severity":"error"}
        ]:
            raise MarnieTrajectoryReplayError("base_firewall_compatibility_mismatch")
    elif base.status != "accepted":
        raise MarnieTrajectoryReplayError("base_firewall_compatibility_mismatch")

    select = public_tree["select"]
    window_id: str | None = None
    option_count = 0
    fingerprints: list[str] = []
    authority: str | None = None
    if select is not None:
        built = build_cabt_selection_window(
            select,
            public_observation_hash=evaluation["public_observation_hash"],
            public_hash_authority="firewall_accepted",
            chooser_player_index=public_tree["current"]["yourIndex"],
        )
        if not built.accepted or built.window is None or not built.validate_integrity():
            raise MarnieTrajectoryReplayError("window_replay_mismatch")
        window = built.window.to_public_dict()
        if parent["window"] is None or window["window_id"] != parent["window"]["window_id"] or window["option_fingerprints"] != parent["window"]["option_fingerprints"]:
            raise MarnieTrajectoryReplayError("window_replay_mismatch")
        window_id = window["window_id"]
        option_count = len(window["options"])
        fingerprints = window["option_fingerprints"]
        authority = "firewall_accepted"
    elif parent["window"] is not None:
        raise MarnieTrajectoryReplayError("window_replay_mismatch")

    own_active = None
    if compatibility is not None:
        acting = public_tree["current"]["yourIndex"]
        own_active = deepcopy(public_tree["current"]["players"][acting]["active"])
    summary = {
        "ordinal": ordinal, "frame_id": frame_id,
        "source_replay_id": parent["source_replay_id"], "source_step": parent["source_step"],
        "source_seat": parent["source_seat"], "firewall_status": "accepted",
        "compatibility_rule": compatibility,
        "public_observation_hash": evaluation["public_observation_hash"],
        "public_hash_authority": authority, "window_id": window_id,
        "option_count": option_count, "option_fingerprints": fingerprints,
        "own_active": own_active, "terminal": False, "previous_witness": previous_witness,
    }
    summary["witness_hash"] = _witness(summary)
    return summary


class MarnieTrajectoryReplayResult:
    """Copy-only, non-authoritative replay result bound to one exact owner."""

    __slots__ = ("_owner", "_operation", "_argument", "_snapshot")

    def __init__(self, *_: Any, **__: Any) -> None:
        raise MarnieTrajectoryReplayError("direct_construction_forbidden")

    @classmethod
    def _from_owner(
        cls,
        token: object,
        owner: "MarnieTrajectoryReplay",
        operation: str,
        argument: str | None,
        snapshot: dict[str, Any],
    ) -> "MarnieTrajectoryReplayResult":
        if token is not _CONSTRUCTION_TOKEN:
            raise MarnieTrajectoryReplayError("direct_construction_forbidden")
        instance = object.__new__(cls)
        object.__setattr__(instance, "_owner", owner)
        object.__setattr__(instance, "_operation", operation)
        object.__setattr__(instance, "_argument", argument)
        object.__setattr__(instance, "_snapshot", _freeze(snapshot))
        return instance

    def validate_integrity(self, owner: object) -> bool:
        try:
            return (
                owner is self._owner
                and type(owner) is MarnieTrajectoryReplay
                and owner._integrity_valid()
                and _thaw(self._snapshot) == owner._expected_snapshot(self._operation, self._argument)
            )
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._owner):
            raise MarnieTrajectoryReplayError("result_integrity_invalid")
        return _thaw(self._snapshot)


class MarnieTrajectoryReplay:
    """Fixed-contract owner for deterministic P5 public replay validation."""

    __slots__ = (
        "_bundle", "_schema", "_profile", "_vectors", "_replay",
        "_parent_owner", "_firewall", "_runtime_integrity_sha256",
    )

    def __init__(self, *_: Any, **__: Any) -> None:
        raise MarnieTrajectoryReplayError("direct_construction_forbidden")

    @classmethod
    def load_default(cls) -> "MarnieTrajectoryReplay":
        return cls.load_trusted_bundle(Path(__file__).resolve().parents[3])

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarnieTrajectoryReplay":
        root = Path(repository_root).resolve()
        bundle, _ = _read_json_once(_contained_path(root, "contracts/ptcgdap/marnie_trajectory_replay_bundle.json"))
        if type(bundle) is not dict:
            raise MarnieTrajectoryReplayError("replay_bundle_invalid")
        try:
            bundle_hash = sha256_bytes(canonical_json_v1_bytes(bundle))
        except (TypeError, ValueError) as exc:
            raise MarnieTrajectoryReplayError("replay_bundle_invalid") from exc
        if bundle_hash != _EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise MarnieTrajectoryReplayError("replay_bundle_trust_anchor_mismatch")
        if (
            set(bundle) != {"schema_version","bundle_id","status","parent_fixture_bundle","base_firewall_bundle","artifacts","self_hash_policy"}
            or bundle.get("schema_version") != 1
            or bundle.get("bundle_id") != "ptcgdap-marnie-trajectory-replay-p5-wp2-v1"
            or bundle.get("status") != "offline_shadow_replay"
            or bundle.get("parent_fixture_bundle") != {"path":"contracts/ptcgdap/marnie_vertical_slice_bundle.json","canonical_sha256":_EXPECTED_PARENT_FIXTURE_SHA256}
            or bundle.get("base_firewall_bundle") != {"path":"contracts/ptcgdap/cabt_public_firewall_bundle.json","canonical_sha256":EXPECTED_FIREWALL_BUNDLE_SHA256}
            or bundle.get("self_hash_policy") != "bundle and bound artifacts do not contain the final bundle hash"
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != len(_EXPECTED_ARTIFACTS)
        ):
            raise MarnieTrajectoryReplayError("replay_bundle_invalid")

        documents: dict[str, Any] = {"bundle": bundle}
        seen_paths: set[str] = set()
        for index, (artifact_id, relative, key) in enumerate(_EXPECTED_ARTIFACTS):
            entry = bundle["artifacts"][index]
            if type(entry) is not dict or set(entry) != {"id","path","canonical_sha256"}:
                raise MarnieTrajectoryReplayError("replay_bundle_invalid")
            if (entry.get("id"), entry.get("path")) != (artifact_id, relative):
                raise MarnieTrajectoryReplayError("replay_bundle_invalid")
            expected_hash = entry.get("canonical_sha256")
            if type(expected_hash) is not str or _SHA256_RE.fullmatch(expected_hash) is None or relative in seen_paths:
                raise MarnieTrajectoryReplayError("replay_bundle_invalid")
            seen_paths.add(relative)
            document, _ = _read_json_once(_contained_path(root, relative))
            try:
                actual_hash = sha256_bytes(canonical_json_v1_bytes(document))
            except (TypeError, ValueError) as exc:
                raise MarnieTrajectoryReplayError("replay_artifact_invalid") from exc
            if actual_hash != expected_hash:
                raise MarnieTrajectoryReplayError("replay_artifact_hash_mismatch")
            documents[key] = document
        if _runtime_integrity_digest(documents) != _EXPECTED_RUNTIME_INTEGRITY_SHA256:
            raise MarnieTrajectoryReplayError("replay_integrity_invalid")

        parent_owner = MarnieVerticalSlice.load_trusted_bundle(root)
        firewall = PublicObservationFirewall.load_from_root(root / "contracts" / "ptcgdap")
        actual_frames: list[dict[str, Any]] = []
        previous: str | None = None
        for ordinal, frame_id in enumerate(_FRAME_IDS):
            frame = _frame_summary(parent_owner, firewall, frame_id, ordinal, previous)
            actual_frames.append(frame)
            previous = frame["witness_hash"]
        replay = documents["replay"]
        if (
            type(replay) is not dict
            or replay.get("frames") != actual_frames
            or replay.get("frame_count") != len(_FRAME_IDS)
            or replay.get("chain_head") != previous
        ):
            raise MarnieTrajectoryReplayError("replay_conformance_mismatch")

        instance = object.__new__(cls)
        for key in ("bundle", "schema", "profile", "vectors", "replay"):
            object.__setattr__(instance, f"_{key}", _freeze(documents[key]))
        object.__setattr__(instance, "_parent_owner", parent_owner)
        object.__setattr__(instance, "_firewall", firewall)
        object.__setattr__(instance, "_runtime_integrity_sha256", _EXPECTED_RUNTIME_INTEGRITY_SHA256)
        return instance

    def _documents(self) -> dict[str, Any]:
        return {key: getattr(self, f"_{key}") for key in ("bundle", "schema", "profile", "vectors", "replay")}

    def _integrity_valid(self) -> bool:
        try:
            return (
                type(self._parent_owner) is MarnieVerticalSlice
                and self._parent_owner.bundle_hash() == _EXPECTED_PARENT_FIXTURE_SHA256
                and type(self._firewall) is PublicObservationFirewall
                and self._firewall._integrity_valid()
                and self._runtime_integrity_sha256 == _EXPECTED_RUNTIME_INTEGRITY_SHA256
                and _runtime_integrity_digest(self._documents()) == _EXPECTED_RUNTIME_INTEGRITY_SHA256
            )
        except Exception:
            return False

    def _require_integrity(self) -> None:
        if not self._integrity_valid():
            raise MarnieTrajectoryReplayError("replay_integrity_invalid")

    def _frame(self, frame_id: str) -> dict[str, Any]:
        if type(frame_id) is not str:
            raise MarnieTrajectoryReplayError("input_type_invalid")
        for frame in self._replay["frames"]:
            if frame["frame_id"] == frame_id:
                return _thaw(frame)
        raise MarnieTrajectoryReplayError("frame_unknown")

    def _expected_snapshot(self, operation: str, argument: str | None) -> dict[str, Any]:
        if operation == "replay_all" and argument is None:
            frames = _thaw(self._replay["frames"])
            return {"accepted":True,"frame_count":13,"chain_head":self._replay["chain_head"],"frames":frames,"execution_authority":False}
        if operation == "replay_frame" and type(argument) is str:
            frame = self._frame(argument)
            return {"accepted":True,"frame_count":1,"chain_head":frame["witness_hash"],"frames":[frame],"execution_authority":False}
        raise MarnieTrajectoryReplayError("result_integrity_invalid")

    def replay_all(self) -> MarnieTrajectoryReplayResult:
        self._require_integrity()
        return MarnieTrajectoryReplayResult._from_owner(
            _CONSTRUCTION_TOKEN, self, "replay_all", None, self._expected_snapshot("replay_all", None)
        )

    def replay_frame(self, frame_id: str) -> MarnieTrajectoryReplayResult:
        self._require_integrity()
        snapshot = self._expected_snapshot("replay_frame", frame_id)
        return MarnieTrajectoryReplayResult._from_owner(
            _CONSTRUCTION_TOKEN, self, "replay_frame", frame_id, snapshot
        )

    @staticmethod
    def _dto(value: Any = None, error_code: str = "") -> dict[str, Any]:
        return {"ok": error_code == "", "error_code": error_code, "value": deepcopy(value) if not error_code else None}

    def probe_w2_mutation(self, field: object, value: object) -> dict[str, Any]:
        self._require_integrity()
        allowed_fields = {
            "select_type", "select_context", "turn", "own_active", "max_count", "result",
            "remain_damage_counter", "remain_energy_cost", "select_deck", "context_card", "effect",
            "opponent_active", "opponent_hand", "own_prize", "opponent_draw_log",
        }
        if type(field) is not str or field not in allowed_fields:
            return self._dto(error_code="input_type_invalid")
        parent = self._parent_owner.frame("w2_setup_bench")
        public_tree = _decode_node(parent["public_tree"])
        if field == "select_type":
            public_tree["select"]["type"] = deepcopy(value)
        elif field == "select_context":
            public_tree["select"]["context"] = deepcopy(value)
        elif field == "turn":
            public_tree["current"]["turn"] = deepcopy(value)
        elif field == "own_active":
            acting = public_tree["current"]["yourIndex"]
            public_tree["current"]["players"][acting]["active"] = deepcopy(value)
        elif field == "max_count":
            public_tree["select"]["maxCount"] = deepcopy(value)
        elif field == "result":
            public_tree["current"]["result"] = deepcopy(value)
        elif field == "remain_damage_counter":
            public_tree["select"]["remainDamageCounter"] = deepcopy(value)
        elif field == "remain_energy_cost":
            public_tree["select"]["remainEnergyCost"] = deepcopy(value)
        elif field == "select_deck":
            public_tree["select"]["deck"] = deepcopy(value)
        elif field == "context_card":
            public_tree["select"]["contextCard"] = deepcopy(value)
        elif field == "effect":
            public_tree["select"]["effect"] = deepcopy(value)
        else:
            acting = public_tree["current"]["yourIndex"]
            opponent = 1 - acting
            if field == "opponent_active":
                public_tree["current"]["players"][opponent]["active"] = deepcopy(value)
            elif field == "opponent_hand":
                public_tree["current"]["players"][opponent]["hand"] = deepcopy(value)
            elif field == "own_prize":
                public_tree["current"]["players"][acting]["prize"][0] = deepcopy(value)
            else:
                public_tree["logs"].append(deepcopy(value))
        parsed = parse_raw_cabt_json_bytes(_raw_bytes(public_tree))
        evaluation = self._firewall._evaluate_setup_bench_concealment(parsed)
        if (
            evaluation.get("status") == "accepted"
            and evaluation.get("compatibility_rule") == "setup_bench_concealment_v1"
        ):
            return self._dto({"accepted": True})
        return self._dto(error_code="setup_concealment_scope_mismatch")

    def run(self, operation: object, input_value: object) -> dict[str, Any]:
        if not self._integrity_valid():
            return self._dto(error_code="replay_integrity_invalid")
        if type(operation) is not str or type(input_value) is not dict:
            return self._dto(error_code="input_type_invalid")
        try:
            if operation == "replay_all" and not input_value:
                return self._dto(self.replay_all().to_public_dict())
            if operation == "replay_frame" and set(input_value) == {"frame_id"}:
                return self._dto(self.replay_frame(input_value["frame_id"]).to_public_dict())
            if operation == "probe_w2_mutation" and set(input_value) == {"field","value"}:
                return self.probe_w2_mutation(input_value["field"], input_value["value"])
            if operation not in {"replay_all","replay_frame","probe_w2_mutation"}:
                return self._dto(error_code="operation_unknown")
            return self._dto(error_code="input_type_invalid")
        except MarnieTrajectoryReplayError as exc:
            return self._dto(error_code=exc.code)

    def bundle_hash(self) -> str:
        self._require_integrity()
        return _EXPECTED_BUNDLE_CANONICAL_SHA256

    def audit_snapshot(self) -> dict[str, Any]:
        self._require_integrity()
        return {
            "bundle_canonical_sha256": _EXPECTED_BUNDLE_CANONICAL_SHA256,
            "runtime_integrity_sha256": _EXPECTED_RUNTIME_INTEGRITY_SHA256,
            "frame_count": 13,
            "execution_authority": False,
            "live_consumer": False,
        }


def load_default() -> MarnieTrajectoryReplay:
    return MarnieTrajectoryReplay.load_default()


__all__ = [
    "MarnieTrajectoryReplay",
    "MarnieTrajectoryReplayError",
    "MarnieTrajectoryReplayResult",
    "load_default",
]
