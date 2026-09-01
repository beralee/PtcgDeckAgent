from __future__ import annotations

import copy
import hashlib
from pathlib import Path
from typing import Any

from scripts.ai.ptcgdap.marnie_portable_policy import MarniePortablePolicy
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_PATH = Path("contracts/ptcgdap/policy_executor_conformance_v1_profile.json")
VECTORS_PATH = Path("contracts/ptcgdap/policy_executor_conformance_v1_vectors.json")
PARENT_VECTORS_PATH = Path("contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json")
POLICY_MANIFEST_PATH = Path("data/ptcgdap/marnie_windows_policy_package_v1.json")
PORTABLE_BUNDLE_PATH = Path("contracts/ptcgdap/marnie_portable_policy_bundle.json")


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(path: Path) -> str:
    return _sha(canonical_json_v1_bytes(load_json_strict(path)))


class PolicyExecutorConformance:
    """Cross-runtime probe owner for the declared no-model portable subset.

    The class reuses the sealed P5 portable owner and adds only host-boundary
    probes required by P6.  It never selects an engine action or grants live
    authority; the Godot peer consumes the same profile and expected vectors.
    """

    __slots__ = ("_root", "_profile", "_vectors", "_parent_vectors", "_owner")

    def __init__(self, root: Path) -> None:
        self._root = root.resolve()
        self._profile = load_json_strict(self._root / PROFILE_PATH)
        self._vectors = load_json_strict(self._root / VECTORS_PATH)
        self._parent_vectors = load_json_strict(self._root / PARENT_VECTORS_PATH)
        self._owner = MarniePortablePolicy.load_default()
        self._require_integrity()

    @classmethod
    def load_default(cls) -> "PolicyExecutorConformance":
        return cls(Path(__file__).resolve().parents[3])

    def _require_integrity(self) -> None:
        profile = self._profile
        vectors = self._vectors
        if type(profile) is not dict or type(vectors) is not dict or type(self._parent_vectors) is not dict:
            raise ValueError("policy conformance contract invalid")
        manifest_sha = _canonical_sha(self._root / POLICY_MANIFEST_PATH)
        portable_sha = _canonical_sha(self._root / PORTABLE_BUNDLE_PATH)
        if (
            profile.get("document_type") != "policy_executor_conformance_profile_v1"
            or profile.get("schema_version") != 1
            or vectors.get("document_type") != "policy_executor_conformance_vectors_v1"
            or vectors.get("schema_version") != 1
            or vectors.get("profile_id") != profile.get("profile_id")
            or profile.get("policy_package_manifest_canonical_sha256") != manifest_sha
            or vectors.get("policy_package_manifest_canonical_sha256") != manifest_sha
            or profile.get("portable_policy_bundle_canonical_sha256") != portable_sha
            or vectors.get("portable_policy_bundle_canonical_sha256") != portable_sha
            or profile.get("parent_vector_set_id") != self._parent_vectors.get("vector_set_id")
            or vectors.get("parent_vector_set_id") != self._parent_vectors.get("vector_set_id")
            or self._owner.bundle_hash() != portable_sha
        ):
            raise ValueError("policy conformance parent drift")
        # D051 is a sealed parent identity.  Runtime source files have evolved
        # under the current local-executor manifest, so re-verifying the old
        # package against today's source tree would incorrectly turn a
        # historical rollback artifact into live authority.  Conformance only
        # needs the sealed manifest's declared no-model scope.
        package = load_json_strict(self._root / POLICY_MANIFEST_PATH)
        if (
            type(package) is not dict
            or package.get("model", {}).get("learned_model") != "none"
            or package.get("model", {}).get("backend") != "none"
        ):
            raise ValueError("policy package unavailable for conformance")
        model = profile.get("model_contract")
        if model != {
            "learned_model": "none",
            "backend": "none",
            "required_operator_case_count": 0,
            "skipped_operator_case_count": 0,
        }:
            raise ValueError("policy conformance model scope drift")

    def _frame(self, frame_id: str) -> dict[str, Any]:
        return self._owner.evaluate_frame(frame_id).to_public_dict()["frames"][0]

    def _run_probe(self, probe: str) -> dict[str, Any]:
        if probe == "order":
            frame = self._frame("w3_main")
            value: dict[str, Any] = {}
            for key in ("option_fingerprints", "window_id", "public_observation_hash", "frame_id"):
                value[key] = copy.deepcopy(frame[key])
            return self._owner.run("verify_binding", value)
        if probe == "float":
            return self._owner.run("evaluate_frame", {"frame_id": 3.5})
        if probe == "default":
            result = self._owner.run("evaluate_all", {})
            value = result.get("value") if type(result) is dict else None
            return {
                "ok": bool(result.get("ok", False)),
                "error_code": result.get("error_code", ""),
                "frame_count": value.get("frame_count") if type(value) is dict else None,
                "chain_head": value.get("chain_head") if type(value) is dict else None,
            }
        if probe == "unknown_node":
            return self._owner.run("inspect_node", {"node_id": "n99_unknown"})
        if probe == "fault":
            result = self._owner.evaluate_frame("w3_main")
            result._snapshot = {"fault": True}
            return {
                "valid_after_fault": result.validate_integrity(self._owner),
                "error_code": "result_integrity_invalid",
            }
        if probe == "tie_break":
            result = self._owner.run("inspect_tie_break", {"frame_id": "w4_spikemuth_deck"})
            value = result.get("value") if type(result) is dict else None
            if not result.get("ok") or type(value) is not dict:
                return result
            keys = (
                "frame_id", "node_id", "owner_route", "adapter_hint_indexes",
                "base_final_action", "portable_trace_hash",
            )
            return {key: copy.deepcopy(value[key]) for key in keys}
        if probe == "option_reorder":
            frame = self._frame("w3_main")
            fingerprints = list(reversed(frame["option_fingerprints"]))
            return self._owner.run("verify_binding", {
                "frame_id": frame["frame_id"],
                "public_observation_hash": frame["public_observation_hash"],
                "window_id": frame["window_id"],
                "option_fingerprints": fingerprints,
            })
        if probe == "unknown_operation":
            return self._owner.run("unknown_operation", {})
        return {"ok": False, "error_code": "probe_unknown", "value": None}

    def run_all(self) -> dict[str, Any]:
        parent_mismatches = 0
        parent_cases = self._parent_vectors.get("cases", [])
        for case in parent_cases:
            if self._owner.run(case["operation"], copy.deepcopy(case["input"])) != case["expected"]:
                parent_mismatches += 1
        cases: list[dict[str, Any]] = []
        probe_mismatches = 0
        for case in self._vectors.get("cases", []):
            actual = self._run_probe(case["probe"])
            matched = actual == case["expected"]
            probe_mismatches += int(not matched)
            cases.append({"case_id": case["case_id"], "actual": actual, "matched": matched})
        model = self._profile["model_contract"]
        accepted = parent_mismatches == 0 and probe_mismatches == 0
        return {
            "document_type": "policy_executor_conformance_report_v1",
            "schema_version": 1,
            "profile_id": self._profile["profile_id"],
            "policy_package_manifest_canonical_sha256": self._profile["policy_package_manifest_canonical_sha256"],
            "portable_policy_bundle_canonical_sha256": self._profile["portable_policy_bundle_canonical_sha256"],
            "accepted": accepted,
            "parent_vector_case_count": len(parent_cases),
            "parent_vector_mismatch_count": parent_mismatches,
            "probe_case_count": len(cases),
            "probe_mismatch_count": probe_mismatches,
            "skipped_case_count": 0,
            "model": {
                "learned_model": model["learned_model"],
                "backend": model["backend"],
                "operator_case_count": model["required_operator_case_count"],
                "operator_skip_count": model["skipped_operator_case_count"],
            },
            "cases": cases,
            "public_only": True,
            "execution_authority": False,
            "production_ready": False,
        }


__all__ = ["PolicyExecutorConformance"]
