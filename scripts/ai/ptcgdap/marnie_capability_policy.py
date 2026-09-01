from __future__ import annotations

from copy import deepcopy
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Mapping

from .marnie_trajectory_replay import MarnieTrajectoryReplay
from .marnie_vertical_slice import MarnieVerticalSlice
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


_EXPECTED_BUNDLE_CANONICAL_SHA256 = "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
_EXPECTED_RUNTIME_INTEGRITY_SHA256 = "4CE8CE339F1C147C2E8A8CC44E70FB38B33551C2B1AF6C3E406C675F7BBEFACE"
_EXPECTED_FRAME_SET_SHA256 = "B9D6946F133C5AB9DD549B2A2B9B7D51AB7934E7AC4B9ECA2C479B78905C4E04"
_EXPECTED_PARENT_REPLAY_SHA256 = "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
_EXPECTED_PARENT_FIXTURE_SHA256 = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
_RESULT_PREFIX = b"PTCGDAP\0MARNIE_CAPABILITY_POLICY_RESULT_V1\0"
_MAX_JSON_BYTES = 2 * 1024 * 1024
_SHA256_RE = re.compile(r"[0-9A-F]{64}")
_CONSTRUCTION_TOKEN = object()
_FRAME_IDS = (
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
    "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
    "w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
    "w7_take_prize", "w7_forced_send_out", "w7_terminal",
)
_EXPECTED_ARTIFACTS = (
    ("marnie_capability_policy_schema_v1", "contracts/ptcgdap/marnie_capability_policy.schema.json", "schema"),
    ("marnie_capability_policy_profile_v1", "contracts/ptcgdap/marnie_capability_policy_profile.json", "profile"),
    ("marnie_capability_policy_rules_v1", "data/ptcgdap/marnie_vertical_slice/marnie_capability_policy_v1.json", "policy"),
    ("marnie_capability_policy_vectors_v1", "contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json", "vectors"),
)
_MUTATION_FIELDS = frozenset(("public_observation_hash", "window_id", "option_fingerprints", "options", "min_count"))


class MarnieCapabilityPolicyError(RuntimeError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


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


def _contained(root: Path, relative: str) -> Path:
    if type(relative) is not str or not relative or "\\" in relative or "\0" in relative:
        raise MarnieCapabilityPolicyError("policy_bundle_invalid")
    path = Path(relative)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise MarnieCapabilityPolicyError("policy_bundle_invalid")
    resolved = (root / path).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise MarnieCapabilityPolicyError("policy_bundle_invalid") from exc
    return resolved


def _read_json_once(path: Path) -> tuple[Any, bytes]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise MarnieCapabilityPolicyError("policy_file_missing") from exc
    if len(raw) > _MAX_JSON_BYTES:
        raise MarnieCapabilityPolicyError("policy_file_too_large")
    try:
        return load_json_bytes_strict(raw), raw
    except (UnicodeError, ValueError) as exc:
        raise MarnieCapabilityPolicyError("policy_json_invalid") from exc


def _runtime_digest(documents: Mapping[str, Any]) -> str:
    return _sha256(canonical_json_v1_bytes({key: _thaw(documents[key]) for key in ("bundle", "schema", "profile", "policy", "vectors")}))


def _decision_hash(value: dict[str, Any]) -> str:
    return _sha256(_RESULT_PREFIX + canonical_json_v1_bytes(value))


def _select(rule: dict[str, Any], frame: dict[str, Any], deck_ids: list[int]) -> tuple[str, str, list[int] | None, list[int] | None]:
    rule_id = rule["rule_id"]
    window = frame["window"]
    if rule_id == "official_initial_deck":
        return "accepted", "official_initial_deck_fixture", None, deepcopy(deck_ids)
    if rule_id == "terminal_no_callback":
        return "not_applicable_terminal", "terminal_no_callback", None, None
    if type(window) is not dict:
        raise MarnieCapabilityPolicyError("frame_binding_mismatch")
    if rule_id == "optional_zero":
        indexes: list[int] = []
    elif rule_id == "first_min":
        indexes = list(range(window["min_count"]))
    elif rule_id in {"public_deck_card_id", "all_public_deck_card_id"}:
        candidates = window.get("public_deck_candidates")
        if type(candidates) is not list:
            raise MarnieCapabilityPolicyError("frame_binding_mismatch")
        matches = []
        for option_index, option in enumerate(window["options"]):
            if type(option) is not dict or type(option.get("index")) is not int or not 0 <= option["index"] < len(candidates):
                raise MarnieCapabilityPolicyError("frame_binding_mismatch")
            candidate = candidates[option["index"]]
            if type(candidate) is dict and candidate.get("id") == rule["target_official_id"]:
                matches.append(option_index)
        indexes = matches[:1] if rule_id == "public_deck_card_id" else matches[:window["max_count"]]
    elif rule_id == "official_attack_id":
        indexes = [index for index, option in enumerate(window["options"]) if type(option) is dict and option.get("attackId") == rule["target_official_id"]][:1]
    else:
        raise MarnieCapabilityPolicyError("policy_integrity_invalid")
    if (
        type(window.get("min_count")) is not int
        or type(window.get("max_count")) is not int
        or type(window.get("options")) is not list
        or not window["min_count"] <= len(indexes) <= window["max_count"]
        or len(indexes) != len(set(indexes))
        or any(type(index) is not int or not 0 <= index < len(window["options"]) for index in indexes)
    ):
        raise MarnieCapabilityPolicyError("frame_binding_mismatch")
    return "accepted", "deterministic_policy_selected", indexes, None


def _build_frames(parent: MarnieVerticalSlice, replay: MarnieTrajectoryReplay, policy: dict[str, Any]) -> list[dict[str, Any]]:
    rules = {rule["frame_id"]: rule for rule in policy["rules"]}
    if set(rules) != set(_FRAME_IDS):
        raise MarnieCapabilityPolicyError("policy_integrity_invalid")
    previous: str | None = None
    output = []
    for ordinal, frame_id in enumerate(_FRAME_IDS):
        frame = parent.frame(frame_id)
        replay_result = replay.replay_frame(frame_id)
        if not replay_result.validate_integrity(replay):
            raise MarnieCapabilityPolicyError("frame_binding_mismatch")
        replay_frame = replay_result.to_public_dict()["frames"][0]
        window = frame["window"]
        binding = {
            "public_observation_hash": frame["public_observation_hash"],
            "window_id": None if window is None else window["window_id"],
            "option_fingerprints": [] if window is None else window["option_fingerprints"],
        }
        if any(replay_frame[key] != value for key, value in binding.items()):
            raise MarnieCapabilityPolicyError("frame_binding_mismatch")
        rule = rules[frame_id]
        status, reason, indexes, cards = _select(rule, frame, policy["initial_deck_card_ids"])
        value = {
            "ordinal": ordinal, "frame_id": frame_id, "capability_id": rule["capability_id"],
            "capability_state": "source_locked_fixture_only", "status": status, "reason_code": reason,
            "rule_id": rule["rule_id"],
            "selection_domain": "initial_deck_card_ids" if cards is not None else "none" if indexes is None else "current_window_indexes",
            "selected_indexes": indexes, "selected_card_ids": cards,
            "public_observation_hash": binding["public_observation_hash"], "window_id": binding["window_id"],
            "option_fingerprints": deepcopy(binding["option_fingerprints"]),
            "previous_decision_hash": previous, "production_action_used": False, "execution_authority": False,
        }
        value["decision_hash"] = _decision_hash(value)
        previous = value["decision_hash"]
        output.append(value)
    return output


class MarnieCapabilityPolicyResult:
    __slots__ = ("_owner", "_operation", "_argument", "_snapshot")

    def __init__(self, *_: Any, **__: Any) -> None:
        raise MarnieCapabilityPolicyError("direct_construction_forbidden")

    @classmethod
    def _from_owner(
        cls, token: object, owner: "MarnieCapabilityPolicy", operation: str,
        argument: str | None, snapshot: dict[str, Any],
    ) -> "MarnieCapabilityPolicyResult":
        if token is not _CONSTRUCTION_TOKEN:
            raise MarnieCapabilityPolicyError("direct_construction_forbidden")
        result = object.__new__(cls)
        object.__setattr__(result, "_owner", owner)
        object.__setattr__(result, "_operation", operation)
        object.__setattr__(result, "_argument", argument)
        object.__setattr__(result, "_snapshot", _freeze(snapshot))
        return result

    def validate_integrity(self, owner: object) -> bool:
        try:
            return (
                owner is self._owner
                and type(owner) is MarnieCapabilityPolicy
                and owner._integrity_valid()
                and _thaw(self._snapshot) == owner._expected_snapshot(self._operation, self._argument)
            )
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._owner):
            raise MarnieCapabilityPolicyError("result_integrity_invalid")
        return _thaw(self._snapshot)


class MarnieCapabilityPolicy:
    __slots__ = (
        "_bundle", "_schema", "_profile", "_policy", "_vectors",
        "_parent_owner", "_replay_owner", "_expected_frames", "_runtime_integrity_sha256",
    )

    def __init__(self, *_: Any, **__: Any) -> None:
        raise MarnieCapabilityPolicyError("direct_construction_forbidden")

    @classmethod
    def load_default(cls) -> "MarnieCapabilityPolicy":
        return cls.load_trusted_bundle(Path(__file__).resolve().parents[3])

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarnieCapabilityPolicy":
        root = Path(repository_root).resolve()
        bundle, _ = _read_json_once(_contained(root, "contracts/ptcgdap/marnie_capability_policy_bundle.json"))
        try:
            bundle_hash = _sha256(canonical_json_v1_bytes(bundle))
        except (TypeError, ValueError) as exc:
            raise MarnieCapabilityPolicyError("policy_bundle_invalid") from exc
        if bundle_hash != _EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise MarnieCapabilityPolicyError("policy_bundle_trust_anchor_mismatch")
        if (
            type(bundle) is not dict
            or set(bundle) != {"schema_version", "artifact_kind", "bundle_id", "status", "parent_replay_bundle", "parent_fixture_bundle", "artifacts", "self_hash_policy"}
            or bundle.get("schema_version") != 1
            or bundle.get("artifact_kind") != "bundle"
            or bundle.get("bundle_id") != "ptcgdap-marnie-capability-policy-p5-wp3-v1"
            or bundle.get("status") != "offline_shadow_policy"
            or bundle.get("parent_replay_bundle") != {"path": "contracts/ptcgdap/marnie_trajectory_replay_bundle.json", "canonical_sha256": _EXPECTED_PARENT_REPLAY_SHA256}
            or bundle.get("parent_fixture_bundle") != {"path": "contracts/ptcgdap/marnie_vertical_slice_bundle.json", "canonical_sha256": _EXPECTED_PARENT_FIXTURE_SHA256}
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != len(_EXPECTED_ARTIFACTS)
            or bundle.get("self_hash_policy") != "bundle and bound artifacts do not contain the final bundle hash"
        ):
            raise MarnieCapabilityPolicyError("policy_bundle_invalid")
        documents: dict[str, Any] = {"bundle": bundle}
        seen: set[str] = set()
        for index, (artifact_id, relative, key) in enumerate(_EXPECTED_ARTIFACTS):
            entry = bundle["artifacts"][index]
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"} or (entry.get("id"), entry.get("path")) != (artifact_id, relative):
                raise MarnieCapabilityPolicyError("policy_bundle_invalid")
            expected = entry.get("canonical_sha256")
            if type(expected) is not str or _SHA256_RE.fullmatch(expected) is None or relative in seen:
                raise MarnieCapabilityPolicyError("policy_bundle_invalid")
            seen.add(relative)
            document, _ = _read_json_once(_contained(root, relative))
            try:
                actual = _sha256(canonical_json_v1_bytes(document))
            except (TypeError, ValueError) as exc:
                raise MarnieCapabilityPolicyError("policy_artifact_invalid") from exc
            if actual != expected:
                raise MarnieCapabilityPolicyError("policy_artifact_hash_mismatch")
            documents[key] = document
        if _runtime_digest(documents) != _EXPECTED_RUNTIME_INTEGRITY_SHA256:
            raise MarnieCapabilityPolicyError("policy_integrity_invalid")
        parent = MarnieVerticalSlice.load_trusted_bundle(root)
        replay = MarnieTrajectoryReplay.load_trusted_bundle(root)
        if parent.bundle_hash() != _EXPECTED_PARENT_FIXTURE_SHA256 or replay.bundle_hash() != _EXPECTED_PARENT_REPLAY_SHA256:
            raise MarnieCapabilityPolicyError("policy_parent_mismatch")
        frames = _build_frames(parent, replay, documents["policy"])
        positive = {case["input"].get("frame_id"): case["expected"]["value"]["frames"][0] for case in documents["vectors"]["cases"] if case["operation"] == "evaluate_frame" and type(case["input"].get("frame_id")) is str and case["input"]["frame_id"] in _FRAME_IDS}
        if positive != {frame["frame_id"]: frame for frame in frames}:
            raise MarnieCapabilityPolicyError("policy_conformance_mismatch")
        instance = object.__new__(cls)
        for key in ("bundle", "schema", "profile", "policy", "vectors"):
            object.__setattr__(instance, f"_{key}", _freeze(documents[key]))
        object.__setattr__(instance, "_parent_owner", parent)
        object.__setattr__(instance, "_replay_owner", replay)
        object.__setattr__(instance, "_expected_frames", _freeze(frames))
        object.__setattr__(instance, "_runtime_integrity_sha256", _EXPECTED_RUNTIME_INTEGRITY_SHA256)
        return instance

    def _documents(self) -> dict[str, Any]:
        return {key: getattr(self, f"_{key}") for key in ("bundle", "schema", "profile", "policy", "vectors")}

    def _integrity_valid(self) -> bool:
        try:
            return (
                type(self._parent_owner) is MarnieVerticalSlice
                and type(self._replay_owner) is MarnieTrajectoryReplay
                and self._runtime_integrity_sha256 == _EXPECTED_RUNTIME_INTEGRITY_SHA256
                and _runtime_digest(self._documents()) == _EXPECTED_RUNTIME_INTEGRITY_SHA256
                and _sha256(canonical_json_v1_bytes(_thaw(self._expected_frames))) == _EXPECTED_FRAME_SET_SHA256
            )
        except Exception:
            return False

    def _require_integrity(self) -> None:
        if not self._integrity_valid():
            raise MarnieCapabilityPolicyError("policy_integrity_invalid")

    def _expected_snapshot(self, operation: str, argument: str | None) -> dict[str, Any]:
        frames = _thaw(self._expected_frames)
        if operation == "evaluate_all" and argument is None:
            selected = frames
        elif operation == "evaluate_frame" and type(argument) is str:
            selected = [frame for frame in frames if frame["frame_id"] == argument]
            if not selected:
                raise MarnieCapabilityPolicyError("frame_unknown")
        else:
            raise MarnieCapabilityPolicyError("result_integrity_invalid")
        return {"accepted": True, "frame_count": len(selected), "chain_head": selected[-1]["decision_hash"], "frames": selected, "production_actions_used": False, "execution_authority": False}

    def evaluate_all(self) -> MarnieCapabilityPolicyResult:
        self._require_integrity()
        return MarnieCapabilityPolicyResult._from_owner(_CONSTRUCTION_TOKEN, self, "evaluate_all", None, self._expected_snapshot("evaluate_all", None))

    def evaluate_frame(self, frame_id: str) -> MarnieCapabilityPolicyResult:
        self._require_integrity()
        if type(frame_id) is not str:
            raise MarnieCapabilityPolicyError("input_type_invalid")
        return MarnieCapabilityPolicyResult._from_owner(_CONSTRUCTION_TOKEN, self, "evaluate_frame", frame_id, self._expected_snapshot("evaluate_frame", frame_id))

    @staticmethod
    def _dto(value: Any = None, error_code: str = "") -> dict[str, Any]:
        return {"ok": error_code == "", "error_code": error_code, "value": deepcopy(value) if not error_code else None}

    def probe_frame_mutation(self, frame_id: object, field: object, value: object) -> dict[str, Any]:
        self._require_integrity()
        if type(frame_id) is not str or type(field) is not str or field not in _MUTATION_FIELDS:
            return self._dto(error_code="input_type_invalid")
        try:
            frame = self._parent_owner.frame(frame_id)
        except Exception:
            return self._dto(error_code="frame_unknown")
        mutated = deepcopy(frame)
        window = mutated.get("window")
        if field == "public_observation_hash":
            mutated["public_observation_hash"] = deepcopy(value)
        elif type(window) is not dict:
            return self._dto(error_code="frame_binding_mismatch")
        elif field == "options" and value == "reverse":
            window["options"] = list(reversed(window["options"]))
        else:
            window[field] = deepcopy(value)
        if mutated != frame:
            return self._dto(error_code="frame_binding_mismatch")
        return self._dto(error_code="policy_integrity_invalid")

    def run(self, operation: object, input_value: object) -> dict[str, Any]:
        try:
            self._require_integrity()
        except MarnieCapabilityPolicyError as exc:
            return self._dto(error_code=exc.code)
        if type(operation) is not str or type(input_value) is not dict:
            return self._dto(error_code="input_type_invalid")
        try:
            if operation == "evaluate_all":
                if input_value:
                    return self._dto(error_code="input_type_invalid")
                return self._dto(self.evaluate_all().to_public_dict())
            if operation == "evaluate_frame":
                if set(input_value) != {"frame_id"} or type(input_value["frame_id"]) is not str:
                    return self._dto(error_code="input_type_invalid")
                return self._dto(self.evaluate_frame(input_value["frame_id"]).to_public_dict())
            if operation == "probe_frame_mutation":
                if set(input_value) != {"frame_id", "field", "value"}:
                    return self._dto(error_code="input_type_invalid")
                return self.probe_frame_mutation(input_value["frame_id"], input_value["field"], input_value["value"])
            return self._dto(error_code="operation_unknown")
        except MarnieCapabilityPolicyError as exc:
            return self._dto(error_code=exc.code)

    def bundle_hash(self) -> str:
        self._require_integrity()
        return _EXPECTED_BUNDLE_CANONICAL_SHA256

    def audit_snapshot(self) -> dict[str, Any]:
        self._require_integrity()
        return {
            "bundle_canonical_sha256": _EXPECTED_BUNDLE_CANONICAL_SHA256,
            "runtime_integrity_sha256": _EXPECTED_RUNTIME_INTEGRITY_SHA256,
            "artifact_count": len(_EXPECTED_ARTIFACTS), "frame_count": len(_FRAME_IDS),
            "vector_count": len(self._vectors["cases"]), "production_actions_used": False,
            "execution_authority": False, "live_consumer": False, "portable_ready": False,
        }


def load_default() -> MarnieCapabilityPolicy:
    return MarnieCapabilityPolicy.load_default()
