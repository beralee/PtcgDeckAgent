from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


SCHEMA_PATH = ROOT / "contracts/ptcgdap/device_manifest_v1.schema.json"
PROFILE_PATH = ROOT / "contracts/ptcgdap/device_manifest_v1_profile.json"
MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_device_manifest_v1.json"
BUNDLE_PATH = ROOT / "contracts/ptcgdap/device_manifest_v1_bundle.json"
ACCEPTANCE_PROFILE_PATH = ROOT / "data/ptcgdap/author_strategy_device_acceptance_profile.json"
LOCAL_EXECUTOR_MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
ROLLBACK_MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
AUTHOR_ARCHIVE_PATH = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
RUNTIME_REPORT_PATH = ROOT / "artifacts/ptcgdap/as_wp6_windows_deterministic_export/reproducibility_report.json"

MANIFEST_ID = "ptcgdap-marnie-windows-device-v1"
LOCAL_EXECUTOR_CANONICAL_SHA256 = "0B8FB2A551429CBAFFF7DD0B9DFACEC3FFF76AA867A8B1BC666F540875489BA7"
ROLLBACK_CANONICAL_SHA256 = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
AUTHOR_ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
RUNTIME_VERSION = "4.6.1"
RUNTIME_BUILD = "4.6.1.stable.official.14d19694e"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def pretty(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def compact(value: object) -> bytes:
    return canonical_json_v1_bytes(value) + b"\n"


def _object_schema(properties: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties),
        "properties": properties,
    }


def _acceptance_profile() -> dict[str, Any]:
    value = load_json_strict(ACCEPTANCE_PROFILE_PATH)
    if (
        type(value) is not dict
        or value.get("document_type") != "author_strategy_device_acceptance_profile_v1"
        or value.get("schema_version") != 1
        or value.get("profile_id") != "ptcgdap-device-acceptance-candidate-v1"
        or value.get("approval_status") != "approved"
        or value.get("formal_a5_eligible") is not False
        or type(value.get("platforms")) is not dict
        or set(value["platforms"]) != {"windows"}
        or type(value["platforms"].get("windows")) is not dict
    ):
        raise RuntimeError("candidate device acceptance profile drift")
    return value


def _resource_limits() -> dict[str, Any]:
    return dict(_acceptance_profile()["platforms"]["windows"])


def build_schema() -> dict[str, Any]:
    digest = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    nullable_digest = {"oneOf": [{"$ref": "#/$defs/sha256"}, {"type": "null"}]}
    limits = _resource_limits()
    limit_properties: dict[str, Any] = {}
    for key, value in limits.items():
        limit_properties[key] = {"type": "null"} if value is None else {"const": value}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/device_manifest_v1.schema.json",
        "title": "PTCGDAP Windows no-model device manifest v1",
        "$defs": {"sha256": digest, "nullable_sha256": nullable_digest},
        "type": "object",
        "additionalProperties": False,
        "required": [
            "document_type", "schema_version", "manifest_id", "manifest_version",
            "target_platforms", "deferred_targets", "local_policy_executor",
            "inference_backend", "model_artifacts", "execution",
            "device_acceptance_profile", "resource_profile", "package_integrity",
            "fallback", "release_status",
        ],
        "properties": {
            "document_type": {"const": "device_manifest_v1"},
            "schema_version": {"const": 1},
            "manifest_id": {"const": MANIFEST_ID},
            "manifest_version": {"const": "1.1.0"},
            "target_platforms": {
                "type": "array", "minItems": 1, "maxItems": 1,
                "items": _object_schema({
                    "os": {"const": "windows"},
                    "architecture": {"const": "x86_64"},
                    "abi": {"const": "windows-x86_64"},
                    "host": {"const": "godot"},
                    "minimum_runtime_version": {"const": RUNTIME_VERSION},
                    "runtime_build": {"const": RUNTIME_BUILD},
                    "portable_baseline": {"const": "gdscript"},
                }),
            },
            "deferred_targets": {
                "type": "array", "minItems": 1, "maxItems": 1,
                "items": _object_schema({
                    "os": {"const": "android"},
                    "architecture": {"const": "arm64-v8a"},
                    "declared": {"const": False},
                    "reason": {"const": "independent_android_adapter_and_a5_required"},
                }),
            },
            "local_policy_executor": _object_schema({
                "path": {"const": "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"},
                "canonical_sha256": {"$ref": "#/$defs/sha256"},
                "executor_id": {"const": "ptcgdap-local-policy-executor-v1"},
                "executor_version": {"const": "1.0.0"},
            }),
            "inference_backend": _object_schema({
                "kind": {"const": "none"},
                "version": {"type": "null"},
                "implementation_path": {"type": "null"},
                "implementation_hash": {"$ref": "#/$defs/nullable_sha256"},
            }),
            "model_artifacts": {"type": "array", "maxItems": 0},
            "execution": _object_schema({
                "location": {"const": "device_local"},
                "aligned_ai_network": {"const": "denied"},
                "external_compute": {"const": "denied"},
                "system_python": {"const": False},
                "sidecar": {"const": False},
                "dynamic_model_download": {"const": False},
            }),
            "device_acceptance_profile": _object_schema({
                "path": {"const": "data/ptcgdap/author_strategy_device_acceptance_profile.json"},
                "profile_id": {"const": "ptcgdap-device-acceptance-candidate-v1"},
                "canonical_sha256": {"$ref": "#/$defs/sha256"},
                "approval_status": {"const": "approved"},
                "formal_a5_eligible": {"const": False},
                "thresholds_authority": {"const": "referenced_profile_only"},
            }),
            "resource_profile": _object_schema({
                "source_platform": {"const": "windows"},
                "limits": _object_schema(limit_properties),
                "candidate_override_allowed": {"const": False},
                "acceptance_claim": {"const": True},
            }),
            "package_integrity": _object_schema({
                "hash_algorithm": {"const": "sha256"},
                "manifest_hash_algorithm": {"const": "canonical_json_v1_sha256"},
                "author_archive_sha256": {"$ref": "#/$defs/sha256"},
                "production_signature_required": {"const": True},
                "production_signature_status": {"const": "unprovisioned"},
                "signature_algorithm": {"const": "ed25519"},
                "signing_key_id": {"type": "null"},
                "trust_root_id": {"type": "null"},
                "signed_scope": {"const": "production_release"},
                "development_unsigned_allowed": {"const": True},
            }),
            "fallback": _object_schema({
                "kind": {"const": "deterministic_local"},
                "owner": {"const": "restricted_base_graph"},
                "remote": {"const": False},
                "classic_raw_state": {"const": False},
                "new_matches_only": {"const": True},
                "match_hot_swap": {"const": False},
                "rollback_manifest": _object_schema({
                    "document_type": {"const": "policy_package_v1"},
                    "path": {"const": "data/ptcgdap/marnie_windows_policy_package_v1.json"},
                    "canonical_sha256": {"$ref": "#/$defs/sha256"},
                }),
            }),
            "release_status": _object_schema({
                "authority_scope": {"const": "development_and_device_canary_only"},
                "p6_04_windows_manifest_complete": {"const": True},
                "device_profile_approved": {"const": True},
                "os_network_isolation_proven": {"const": False},
                "production_ready": {"const": False},
                "a2_claimed": {"const": False},
                "a5_claimed": {"const": False},
                "android_claimed": {"const": False},
            }),
        },
    }


def build_profile() -> dict[str, Any]:
    return {
        "document_type": "device_manifest_profile_v1",
        "schema_version": 1,
        "profile_id": "ptcgdap-windows-no-model-device-manifest-v1",
        "manifest_id": MANIFEST_ID,
        "manifest_path": MANIFEST_PATH.relative_to(ROOT).as_posix(),
        "declared_target": {
            "os": "windows", "architecture": "x86_64", "abi": "windows-x86_64",
            "host": "godot", "minimum_runtime_version": RUNTIME_VERSION,
        },
        "deferred_target": {"os": "android", "architecture": "arm64-v8a"},
        "parent_contracts": {
            "local_policy_executor_canonical_sha256": LOCAL_EXECUTOR_CANONICAL_SHA256,
            "rollback_policy_package_canonical_sha256": ROLLBACK_CANONICAL_SHA256,
        },
        "approval_boundary": {
            "device_profile_approved": True,
            "production_ready": False,
            "a5_claimed": False,
            "development_key_required": False,
            "production_signature_gate": "P6-06",
        },
    }


def build_manifest() -> dict[str, Any]:
    acceptance = _acceptance_profile()
    runtime_report = load_json_strict(RUNTIME_REPORT_PATH)
    if type(runtime_report) is not dict or runtime_report.get("godot_version") != RUNTIME_BUILD:
        raise RuntimeError("Windows runtime build evidence drift")
    if canonical_sha(LOCAL_EXECUTOR_MANIFEST_PATH) != LOCAL_EXECUTOR_CANONICAL_SHA256:
        raise RuntimeError("D053 local policy executor manifest drift")
    if canonical_sha(ROLLBACK_MANIFEST_PATH) != ROLLBACK_CANONICAL_SHA256:
        raise RuntimeError("D051 rollback policy manifest drift")
    if sha(AUTHOR_ARCHIVE_PATH.read_bytes()) != AUTHOR_ARCHIVE_SHA256:
        raise RuntimeError("author archive drift")
    return {
        "document_type": "device_manifest_v1",
        "schema_version": 1,
        "manifest_id": MANIFEST_ID,
        "manifest_version": "1.1.0",
        "target_platforms": [{
            "os": "windows", "architecture": "x86_64", "abi": "windows-x86_64",
            "host": "godot", "minimum_runtime_version": RUNTIME_VERSION,
            "runtime_build": RUNTIME_BUILD, "portable_baseline": "gdscript",
        }],
        "deferred_targets": [{
            "os": "android", "architecture": "arm64-v8a", "declared": False,
            "reason": "independent_android_adapter_and_a5_required",
        }],
        "local_policy_executor": {
            "path": LOCAL_EXECUTOR_MANIFEST_PATH.relative_to(ROOT).as_posix(),
            "canonical_sha256": LOCAL_EXECUTOR_CANONICAL_SHA256,
            "executor_id": "ptcgdap-local-policy-executor-v1",
            "executor_version": "1.0.0",
        },
        "inference_backend": {
            "kind": "none", "version": None,
            "implementation_path": None, "implementation_hash": None,
        },
        "model_artifacts": [],
        "execution": {
            "location": "device_local", "aligned_ai_network": "denied",
            "external_compute": "denied", "system_python": False,
            "sidecar": False, "dynamic_model_download": False,
        },
        "device_acceptance_profile": {
            "path": ACCEPTANCE_PROFILE_PATH.relative_to(ROOT).as_posix(),
            "profile_id": acceptance["profile_id"],
            "canonical_sha256": canonical_sha(ACCEPTANCE_PROFILE_PATH),
            "approval_status": acceptance["approval_status"],
            "formal_a5_eligible": acceptance["formal_a5_eligible"],
            "thresholds_authority": "referenced_profile_only",
        },
        "resource_profile": {
            "source_platform": "windows",
            "limits": dict(acceptance["platforms"]["windows"]),
            "candidate_override_allowed": False,
            "acceptance_claim": True,
        },
        "package_integrity": {
            "hash_algorithm": "sha256",
            "manifest_hash_algorithm": "canonical_json_v1_sha256",
            "author_archive_sha256": AUTHOR_ARCHIVE_SHA256,
            "production_signature_required": True,
            "production_signature_status": "unprovisioned",
            "signature_algorithm": "ed25519",
            "signing_key_id": None,
            "trust_root_id": None,
            "signed_scope": "production_release",
            "development_unsigned_allowed": True,
        },
        "fallback": {
            "kind": "deterministic_local", "owner": "restricted_base_graph",
            "remote": False, "classic_raw_state": False,
            "new_matches_only": True, "match_hot_swap": False,
            "rollback_manifest": {
                "document_type": "policy_package_v1",
                "path": ROLLBACK_MANIFEST_PATH.relative_to(ROOT).as_posix(),
                "canonical_sha256": ROLLBACK_CANONICAL_SHA256,
            },
        },
        "release_status": {
            "authority_scope": "development_and_device_canary_only",
            "p6_04_windows_manifest_complete": True,
            "device_profile_approved": True,
            "os_network_isolation_proven": False,
            "production_ready": False,
            "a2_claimed": False,
            "a5_claimed": False,
            "android_claimed": False,
        },
    }


def build_outputs() -> dict[Path, bytes]:
    outputs = {
        SCHEMA_PATH: pretty(build_schema()),
        PROFILE_PATH: pretty(build_profile()),
        MANIFEST_PATH: compact(build_manifest()),
    }
    artifacts = []
    for path in (SCHEMA_PATH, PROFILE_PATH, MANIFEST_PATH):
        value = outputs[path]
        document = json.loads(value.decode("utf-8"))
        artifacts.append({
            "path": path.relative_to(ROOT).as_posix(),
            "raw_sha256": sha(value),
            "canonical_sha256": sha(canonical_json_v1_bytes(document)),
        })
    outputs[BUNDLE_PATH] = pretty({
        "document_type": "device_manifest_bundle_v1",
        "schema_version": 1,
        "manifest_id": MANIFEST_ID,
        "artifacts": artifacts,
    })
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    outputs = build_outputs()
    if args.write:
        for path, value in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
        print("device manifest v1 written")
        print("manifest_canonical_sha256=" + canonical_sha(MANIFEST_PATH))
    else:
        for path, expected in outputs.items():
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(
                    "device manifest artifact drift: " + path.relative_to(ROOT).as_posix()
                )
        print("device manifest v1 verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
