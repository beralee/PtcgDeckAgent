from __future__ import annotations

import copy
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping
import weakref

from .marnie_capability_policy import MarnieCapabilityPolicy
from .marnie_public_base import MarniePublicBase
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_ID = "ptcgdap-marnie-portable-policy-p5-wp7-v1"
PROFILE_ID = "marnie_portable_policy_profile_v1"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2"
EXPECTED_DOCUMENT_INTEGRITY_SHA256 = "6A2381855F98FB806B456F445AEE5A6F24A3C93A4ADE8259C8A106593AFC9210"
EXPECTED_FRAME_SET_SHA256 = "5DFB7ED299D566B71130F8049A27338462E23E2331D41344E27E684EFBEC4740"
TRACE_PREFIX = b"PTCGDAP\0MARNIE_PORTABLE_TRACE_V1\0"
FRAME_IDS = (
    "w0_initial",
    "w1_setup_active",
    "w2_setup_bench",
    "w3_main",
    "w4_spikemuth_deck",
    "w5_punk_up_sources",
    "w5_punk_up_target_1",
    "w5_punk_up_target_2",
    "w6_shadow_bullet_attack",
    "w6_shadow_bullet_target",
    "w7_take_prize",
    "w7_forced_send_out",
    "w7_terminal",
)
PARENT_BUNDLES = {
    "marnie_capability_policy": (
        "contracts/ptcgdap/marnie_capability_policy_bundle.json",
        "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C",
    ),
    "marnie_public_base": (
        "contracts/ptcgdap/marnie_public_base_bundle.json",
        "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105",
    ),
    "marnie_trajectory_replay": (
        "contracts/ptcgdap/marnie_trajectory_replay_bundle.json",
        "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F",
    ),
}
EXPECTED_ARTIFACTS = {
    "schema": (
        "contracts/ptcgdap/marnie_portable_policy.schema.json",
        "31E041BC61625BB265C900A5E3E073A121FE92E4B5D954F7506472C2E4F2A398",
    ),
    "profile": (
        "contracts/ptcgdap/marnie_portable_policy_profile.json",
        "963CDB706D6EAB7389ED6096DFBF61E69A2819A838D36837D9BC8FFE0E9A2626",
    ),
    "vectors": (
        "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json",
        "5BA16562A20331D99673756C46183055B17CC0CD47FB3EF1F1A1D2B0A8EB41A8",
    ),
    "audit": (
        "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json",
        "B981C14562590E4FCFCF297148B6D317BFCA7FB5A5D6DB801A6C26CBC9802D8D",
    ),
}
FORBIDDEN_KEYS = {
    "search_begin_input",
    "raw_private_hash",
    "token_free_callback_hash",
    "callback_binding_hash",
    "private_engine_command",
    "private_object_refs",
}
_CONSTRUCTION_TOKEN = object()
_DEFAULT_PARENT_CACHE: tuple[MarnieCapabilityPolicy, MarniePublicBase, tuple[Any, ...], tuple[Any, ...]] | None = None


class MarniePortablePolicyError(RuntimeError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_hash(value: Any) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(item) for key, item in value.items()})
    if type(value) is list:
        return tuple(_freeze(item) for item in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(item) for key, item in value.items()}
    if isinstance(value, tuple):
        return [_thaw(item) for item in value]
    return value


def _contains_forbidden(value: Any) -> bool:
    if isinstance(value, Mapping):
        return any(key in FORBIDDEN_KEYS or _contains_forbidden(item) for key, item in value.items())
    if isinstance(value, (list, tuple)):
        return any(_contains_forbidden(item) for item in value)
    return False


def _contained(root: Path, relative: str) -> Path:
    if type(relative) is not str or not relative or "\\" in relative or "\0" in relative:
        raise MarniePortablePolicyError("contract_integrity_invalid")
    parts = Path(relative).parts
    if Path(relative).is_absolute() or any(part in {".", ".."} or ":" in part for part in parts):
        raise MarniePortablePolicyError("contract_integrity_invalid")
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as exc:
        raise MarniePortablePolicyError("contract_integrity_invalid") from exc
    return candidate


def _read_json_once(path: Path) -> Any:
    try:
        return load_json_bytes_strict(path.read_bytes())
    except Exception as exc:
        raise MarniePortablePolicyError("contract_integrity_invalid") from exc


def _portable_hash(payload: dict[str, Any]) -> str:
    return _sha(TRACE_PREFIX + canonical_json_v1_bytes(payload))


def _compose_frames(profile: dict[str, Any], capability_frames: list[dict[str, Any]], base_cases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if len(capability_frames) != 13 or len(base_cases) != 13 or len(profile.get("dispatch", [])) != 13:
        raise MarniePortablePolicyError("parent_conformance_invalid")
    results: list[dict[str, Any]] = []
    previous: str | None = None
    for dispatch, capability, base in zip(profile["dispatch"], capability_frames, base_cases, strict=True):
        frame_id = dispatch.get("frame_id")
        if (
            frame_id not in FRAME_IDS
            or capability.get("frame_id") != frame_id
            or base.get("source_frame_id") != frame_id
            or base.get("offline_seeded_extension") is not False
        ):
            raise MarniePortablePolicyError("parent_conformance_invalid")
        route = dispatch.get("owner_route")
        if route == "capability_initial_deck":
            if base.get("status") != "not_applicable" or base.get("reason_code") != "initial_no_window":
                raise MarniePortablePolicyError("parent_conformance_invalid")
            action = copy.deepcopy(capability.get("selected_card_ids"))
            reason = "official_initial_deck_fixture"
            status = "action"
        elif route == "capability_optional_zero":
            if base.get("status") != "not_applicable" or base.get("reason_code") != "firewall_not_accepted" or capability.get("selected_indexes") != []:
                raise MarniePortablePolicyError("parent_conformance_invalid")
            action = []
            reason = "deterministic_optional_zero"
            status = "action"
        elif route == "terminal_lifecycle":
            if capability.get("status") != "not_applicable_terminal" or base.get("reason_code") != "terminal_no_callback":
                raise MarniePortablePolicyError("parent_conformance_invalid")
            action = []
            reason = "terminal_no_callback"
            status = "terminal_no_callback"
        elif route == "base_final":
            if base.get("status") != "orchestrated":
                raise MarniePortablePolicyError("parent_conformance_invalid")
            if capability.get("public_observation_hash") != base.get("public_observation_hash") or capability.get("window_id") != base.get("window_id"):
                raise MarniePortablePolicyError("parent_conformance_invalid")
            action = copy.deepcopy(base.get("selected_indexes"))
            reason = "base_final_decision"
            status = "action"
        else:
            raise MarniePortablePolicyError("unsupported_node")
        if type(action) is not list or any(type(index) is not int or index < 0 for index in action):
            raise MarniePortablePolicyError("parent_conformance_invalid")
        fingerprints = copy.deepcopy(capability.get("option_fingerprints"))
        if type(fingerprints) is not list:
            raise MarniePortablePolicyError("parent_conformance_invalid")
        selected_fingerprints: list[str] = []
        if dispatch.get("output_domain") == "current_window_indexes":
            if any(index >= len(fingerprints) for index in action):
                raise MarniePortablePolicyError("parent_conformance_invalid")
            selected_fingerprints = [fingerprints[index] for index in action]
        payload = {
            "ordinal": dispatch.get("ordinal"),
            "frame_id": frame_id,
            "capability_id": capability.get("capability_id"),
            "node_id": dispatch.get("node_id"),
            "owner_route": route,
            "output_domain": dispatch.get("output_domain"),
            "status": status,
            "reason_code": reason,
            "action": action,
            "public_observation_hash": capability.get("public_observation_hash"),
            "window_id": capability.get("window_id"),
            "option_fingerprints": fingerprints,
            "selected_option_fingerprints": selected_fingerprints,
            "capability_proposal_indexes": copy.deepcopy(capability.get("selected_indexes") or []),
            "adapter_hint_indexes": copy.deepcopy(base.get("adapter_indexes")),
            "parent_capability_decision_hash": capability.get("decision_hash"),
            "parent_base_result_hash": base.get("result_hash"),
            "parent_base_decision_audit_id": base.get("decision_audit_id") if route == "base_final" else None,
            "parent_base_trace_hash": base.get("trace_hash") if route == "base_final" else None,
            "previous_portable_trace_hash": previous,
            "public_only": True,
            "authoritative": False,
            "execution_authority": False,
        }
        result = {**payload, "portable_trace_hash": _portable_hash(payload)}
        if _contains_forbidden(result):
            raise MarniePortablePolicyError("parent_conformance_invalid")
        results.append(result)
        previous = result["portable_trace_hash"]
    return results


def _load_parent_outputs(root: Path) -> tuple[MarnieCapabilityPolicy, MarniePublicBase, list[dict[str, Any]], list[dict[str, Any]]]:
    global _DEFAULT_PARENT_CACHE
    use_cache = root.resolve() == ROOT.resolve()
    if use_cache and _DEFAULT_PARENT_CACHE is not None:
        capability_owner, base_owner, frozen_capability, frozen_base = _DEFAULT_PARENT_CACHE
        if capability_owner.bundle_hash() == PARENT_BUNDLES["marnie_capability_policy"][1] and base_owner.bundle_hash() == PARENT_BUNDLES["marnie_public_base"][1]:
            return capability_owner, base_owner, _thaw(frozen_capability), _thaw(frozen_base)
        _DEFAULT_PARENT_CACHE = None
    try:
        capability_owner = MarnieCapabilityPolicy.load_trusted_bundle(root)
        base_owner = MarniePublicBase.load_trusted_bundle(root)
        capability_result = capability_owner.evaluate_all()
        base_result = base_owner.evaluate_all()
        if not capability_result.validate_integrity(capability_owner) or not base_result.validate_integrity(base_owner):
            raise MarniePortablePolicyError("parent_conformance_invalid")
        capability_frames = capability_result.to_public_dict()["frames"]
        base_cases = [case for case in base_result.to_public_dict()["cases"] if not case["offline_seeded_extension"]]
    except MarniePortablePolicyError:
        raise
    except Exception as exc:
        raise MarniePortablePolicyError("parent_contract_invalid") from exc
    if use_cache:
        _DEFAULT_PARENT_CACHE = (
            capability_owner,
            base_owner,
            _freeze(capability_frames),
            _freeze(base_cases),
        )
    return capability_owner, base_owner, capability_frames, base_cases


class MarniePortablePolicyResult:
    __slots__ = ("_owner_ref", "_operation", "_argument", "_snapshot", "_snapshot_hash", "_factory_token")

    def __init__(self, *_: Any, **__: Any) -> None:
        raise TypeError("result values are owner-created")

    @classmethod
    def _from_owner(
        cls,
        token: object,
        owner: "MarniePortablePolicy",
        operation: str,
        argument: str | None,
        snapshot: dict[str, Any],
    ) -> "MarniePortablePolicyResult":
        if token is not _CONSTRUCTION_TOKEN:
            raise TypeError("result values are owner-created")
        result = object.__new__(cls)
        object.__setattr__(result, "_owner_ref", weakref.ref(owner))
        object.__setattr__(result, "_operation", operation)
        object.__setattr__(result, "_argument", argument)
        object.__setattr__(result, "_snapshot", _freeze(copy.deepcopy(snapshot)))
        object.__setattr__(result, "_snapshot_hash", _canonical_hash(snapshot))
        object.__setattr__(result, "_factory_token", _CONSTRUCTION_TOKEN)
        return result

    def validate_integrity(self, owner: object) -> bool:
        try:
            actual_owner = self._owner_ref()
            snapshot = _thaw(self._snapshot)
            return (
                type(owner) is MarniePortablePolicy
                and actual_owner is owner
                and self._factory_token is _CONSTRUCTION_TOKEN
                and owner._integrity_valid()
                and owner._result_valid(self._operation, self._argument, snapshot)
                and _canonical_hash(snapshot) == self._snapshot_hash
                and not _contains_forbidden(snapshot)
            )
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        owner = self._owner_ref()
        if owner is None or not self.validate_integrity(owner):
            return {}
        return _thaw(self._snapshot)


class MarniePortablePolicy:
    __slots__ = (
        "__weakref__",
        "_documents",
        "_frames",
        "_capability_owner",
        "_base_owner",
        "_document_integrity_sha256",
    )

    def __init__(self, *_: Any, **__: Any) -> None:
        raise TypeError("use load_default() or load_trusted_bundle()")

    @classmethod
    def load_default(cls) -> "MarniePortablePolicy":
        return cls.load_trusted_bundle(ROOT)

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarniePortablePolicy":
        root = Path(repository_root).resolve()
        bundle_path = _contained(root, "contracts/ptcgdap/marnie_portable_policy_bundle.json")
        bundle = _read_json_once(bundle_path)
        if type(bundle) is not dict or _canonical_hash(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise MarniePortablePolicyError("contract_integrity_invalid")
        expected_parents = [
            {"id": parent_id, "path": spec[0], "canonical_sha256": spec[1]}
            for parent_id, spec in PARENT_BUNDLES.items()
        ]
        if (
            set(bundle) != {"schema_version", "contract_id", "status", "parents", "artifacts", "runtime_authority"}
            or bundle.get("schema_version") != 1
            or bundle.get("contract_id") != CONTRACT_ID
            or bundle.get("status") != "offline_shadow"
            or bundle.get("parents") != expected_parents
            or bundle.get("runtime_authority") != "offline_public_differential_only"
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != 4
        ):
            raise MarniePortablePolicyError("contract_integrity_invalid")
        documents: dict[str, Any] = {"bundle": copy.deepcopy(bundle)}
        seen: set[str] = set()
        for entry in bundle["artifacts"]:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise MarniePortablePolicyError("contract_integrity_invalid")
            artifact_id = entry.get("id")
            if type(artifact_id) is not str or artifact_id in seen or artifact_id not in EXPECTED_ARTIFACTS:
                raise MarniePortablePolicyError("contract_integrity_invalid")
            relative, digest = EXPECTED_ARTIFACTS[artifact_id]
            if entry != {"id": artifact_id, "path": relative, "canonical_sha256": digest}:
                raise MarniePortablePolicyError("contract_integrity_invalid")
            value = _read_json_once(_contained(root, relative))
            if _canonical_hash(value) != digest:
                raise MarniePortablePolicyError("contract_integrity_invalid")
            documents[artifact_id] = value
            seen.add(artifact_id)
        if seen != set(EXPECTED_ARTIFACTS) or _canonical_hash(documents) != EXPECTED_DOCUMENT_INTEGRITY_SHA256:
            raise MarniePortablePolicyError("contract_integrity_invalid")
        profile = documents["profile"]
        if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID or profile.get("parent_bundle_hashes") != {key: value[1] for key, value in PARENT_BUNDLES.items()}:
            raise MarniePortablePolicyError("contract_integrity_invalid")
        for parent in expected_parents:
            value = _read_json_once(_contained(root, parent["path"]))
            if _canonical_hash(value) != parent["canonical_sha256"]:
                raise MarniePortablePolicyError("parent_contract_invalid")
        capability_owner, base_owner, capability_frames, base_cases = _load_parent_outputs(root)
        frames = _compose_frames(profile, capability_frames, base_cases)
        if _canonical_hash(frames) != EXPECTED_FRAME_SET_SHA256 or frames != documents["audit"].get("frames"):
            raise MarniePortablePolicyError("parent_conformance_invalid")
        instance = object.__new__(cls)
        object.__setattr__(instance, "_documents", _freeze(copy.deepcopy(documents)))
        object.__setattr__(instance, "_frames", _freeze(copy.deepcopy(frames)))
        object.__setattr__(instance, "_capability_owner", capability_owner)
        object.__setattr__(instance, "_base_owner", base_owner)
        object.__setattr__(instance, "_document_integrity_sha256", EXPECTED_DOCUMENT_INTEGRITY_SHA256)
        if not instance._integrity_valid():
            raise MarniePortablePolicyError("contract_integrity_invalid")
        return instance

    def _integrity_valid(self) -> bool:
        try:
            frames = _thaw(self._frames)
            documents = _thaw(self._documents)
            return (
                self._document_integrity_sha256 == EXPECTED_DOCUMENT_INTEGRITY_SHA256
                and type(self._capability_owner) is MarnieCapabilityPolicy
                and type(self._base_owner) is MarniePublicBase
                and self._capability_owner.bundle_hash() == PARENT_BUNDLES["marnie_capability_policy"][1]
                and self._base_owner.bundle_hash() == PARENT_BUNDLES["marnie_public_base"][1]
                and _canonical_hash(documents) == EXPECTED_DOCUMENT_INTEGRITY_SHA256
                and _canonical_hash(frames) == EXPECTED_FRAME_SET_SHA256
                and frames == documents["audit"]["frames"]
                and not _contains_forbidden(frames)
            )
        except Exception:
            return False

    def _require_integrity(self) -> None:
        if not self._integrity_valid():
            raise MarniePortablePolicyError("contract_integrity_invalid")

    def _expected_snapshot(self, operation: str, argument: str | None) -> dict[str, Any]:
        frames = _thaw(self._frames)
        selected: list[dict[str, Any]]
        if operation == "evaluate_all" and argument is None:
            selected = frames
        elif operation == "evaluate_frame" and type(argument) is str:
            selected = [frame for frame in frames if frame["frame_id"] == argument]
        else:
            return {}
        if not selected:
            return {}
        return {
            "accepted": True,
            "frame_count": len(selected),
            "chain_head": selected[-1]["portable_trace_hash"],
            "frames": selected,
            "public_only": True,
            "authoritative": False,
            "execution_authority": False,
            "production_actions_used": False,
        }

    def _result_valid(self, operation: str, argument: str | None, snapshot: dict[str, Any]) -> bool:
        return snapshot == self._expected_snapshot(operation, argument)

    def evaluate_all(self) -> MarniePortablePolicyResult:
        self._require_integrity()
        return MarniePortablePolicyResult._from_owner(_CONSTRUCTION_TOKEN, self, "evaluate_all", None, self._expected_snapshot("evaluate_all", None))

    def evaluate_frame(self, frame_id: str) -> MarniePortablePolicyResult:
        self._require_integrity()
        if type(frame_id) is not str:
            raise MarniePortablePolicyError("input_type_invalid")
        snapshot = self._expected_snapshot("evaluate_frame", frame_id)
        if not snapshot:
            raise MarniePortablePolicyError("frame_unknown")
        return MarniePortablePolicyResult._from_owner(_CONSTRUCTION_TOKEN, self, "evaluate_frame", frame_id, snapshot)

    def _frame(self, frame_id: str) -> dict[str, Any]:
        result = self.evaluate_frame(frame_id)
        return result.to_public_dict()["frames"][0]

    def verify_binding(self, input_value: dict[str, Any]) -> dict[str, Any]:
        self._require_integrity()
        required = {"frame_id", "public_observation_hash", "window_id", "option_fingerprints"}
        if type(input_value) is not dict or set(input_value) != required:
            raise MarniePortablePolicyError("input_type_invalid")
        if any(type(input_value[key]) is not str for key in ("frame_id", "public_observation_hash", "window_id")) or type(input_value["option_fingerprints"]) is not list or any(type(value) is not str for value in input_value["option_fingerprints"]):
            raise MarniePortablePolicyError("input_type_invalid")
        frame = self._frame(input_value["frame_id"])
        if frame["window_id"] is None:
            raise MarniePortablePolicyError("binding_not_applicable")
        if any(input_value[key] != frame[key] for key in ("public_observation_hash", "window_id", "option_fingerprints")):
            raise MarniePortablePolicyError("binding_mismatch")
        return {
            "binding_matches": True,
            "frame_id": frame["frame_id"],
            "portable_trace_hash": frame["portable_trace_hash"],
            "authoritative": False,
            "execution_authority": False,
        }

    def inspect_tie_break(self, frame_id: str) -> dict[str, Any]:
        self._require_integrity()
        if type(frame_id) is not str:
            raise MarniePortablePolicyError("input_type_invalid")
        frame = self._frame(frame_id)
        if frame["owner_route"] != "base_final" or len(frame["adapter_hint_indexes"]) < 2:
            raise MarniePortablePolicyError("tie_break_not_applicable")
        return {
            "frame_id": frame["frame_id"],
            "node_id": frame["node_id"],
            "owner_route": frame["owner_route"],
            "option_fingerprints": copy.deepcopy(frame["option_fingerprints"]),
            "capability_proposal_indexes": copy.deepcopy(frame["capability_proposal_indexes"]),
            "adapter_hint_indexes": copy.deepcopy(frame["adapter_hint_indexes"]),
            "base_final_action": copy.deepcopy(frame["action"]),
            "parent_base_trace_hash": frame["parent_base_trace_hash"],
            "portable_trace_hash": frame["portable_trace_hash"],
            "authoritative": False,
            "execution_authority": False,
        }

    def inspect_node(self, node_id: str) -> dict[str, Any]:
        self._require_integrity()
        if type(node_id) is not str:
            raise MarniePortablePolicyError("input_type_invalid")
        for node in _thaw(self._documents)["profile"]["portable_nodes"]:
            if node["node_id"] == node_id:
                return {**node, "authoritative": False, "execution_authority": False}
        raise MarniePortablePolicyError("unsupported_node")

    @staticmethod
    def _dto(value: Any = None, error_code: str = "") -> dict[str, Any]:
        return {"ok": not error_code, "error_code": error_code, "value": copy.deepcopy(value) if not error_code else None}

    def run(self, operation: object, input_value: object) -> dict[str, Any]:
        try:
            self._require_integrity()
            if type(operation) is not str or type(input_value) is not dict:
                raise MarniePortablePolicyError("input_type_invalid")
            if operation == "evaluate_all":
                if input_value:
                    raise MarniePortablePolicyError("input_type_invalid")
                return self._dto(self.evaluate_all().to_public_dict())
            if operation == "evaluate_frame":
                if set(input_value) != {"frame_id"} or type(input_value["frame_id"]) is not str:
                    raise MarniePortablePolicyError("input_type_invalid")
                return self._dto(self.evaluate_frame(input_value["frame_id"]).to_public_dict())
            if operation == "verify_binding":
                return self._dto(self.verify_binding(input_value))
            if operation == "inspect_tie_break":
                if set(input_value) != {"frame_id"} or type(input_value["frame_id"]) is not str:
                    raise MarniePortablePolicyError("input_type_invalid")
                return self._dto(self.inspect_tie_break(input_value["frame_id"]))
            if operation == "inspect_node":
                if set(input_value) != {"node_id"} or type(input_value["node_id"]) is not str:
                    raise MarniePortablePolicyError("input_type_invalid")
                return self._dto(self.inspect_node(input_value["node_id"]))
            raise MarniePortablePolicyError("operation_unknown")
        except MarniePortablePolicyError as exc:
            return self._dto(error_code=exc.code)
        except Exception:
            return self._dto(error_code="contract_integrity_invalid")

    def bundle_hash(self) -> str:
        self._require_integrity()
        return EXPECTED_BUNDLE_CANONICAL_SHA256

    def audit_snapshot(self) -> dict[str, Any]:
        self._require_integrity()
        summary = _thaw(self._documents)["audit"]["summary"]
        return {
            "bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
            "document_integrity_sha256": EXPECTED_DOCUMENT_INTEGRITY_SHA256,
            "frame_set_sha256": EXPECTED_FRAME_SET_SHA256,
            "frame_count": summary["frame_count"],
            "base_owned_count": summary["base_owned_count"],
            "capability_owned_count": summary["capability_owned_count"],
            "terminal_lifecycle_count": summary["terminal_lifecycle_count"],
            "vector_count": len(_thaw(self._documents)["vectors"]["cases"]),
            "execution_authority": False,
            "live_consumer": False,
            "portable_ready": False,
        }


def load_default() -> MarniePortablePolicy:
    return MarniePortablePolicy.load_default()
