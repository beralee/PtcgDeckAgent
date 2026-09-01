from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


SCHEMA_PATH = ROOT / "contracts/ptcgdap/local_policy_executor_v1.schema.json"
PROFILE_PATH = ROOT / "contracts/ptcgdap/local_policy_executor_v1_profile.json"
MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
BUNDLE_PATH = ROOT / "contracts/ptcgdap/local_policy_executor_v1_bundle.json"
PARENT_MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
AUTHOR_ARCHIVE_PATH = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"

EXECUTOR_ID = "ptcgdap-local-policy-executor-v1"
PARENT_CANONICAL_SHA256 = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
AUTHOR_ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"

PRODUCT_RESOURCES = (
    "contracts/ptcgdap/cabt_contract_bundle.json",
    "contracts/ptcgdap/card_id_catalog_bundle.json",
    "contracts/ptcgdap/public_deck_adapter_bundle.json",
    "contracts/ptcgdap/restricted_base_graph_executor_bundle.json",
    "contracts/ptcgdap/strategic_trace_v2_bundle.json",
)
ARCHIVE_RESOURCES = (
    "policy/adapter.json",
    "policy/config.json",
    "policy/policy_ir.json",
    "policy/weights.bin",
)
IMPLEMENTATIONS = (
    ("engine_action_executor", "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd"),
    ("inherited_policy_base", "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"),
    ("local_policy_executor", "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd"),
    ("match_owner", "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd"),
    ("public_deck_adapter", "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd"),
    ("restricted_base_executor", "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd"),
    ("strategic_trace_compiler", "scripts/ai/ptcgdap/public/StrategicTraceV2.gd"),
)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def pretty(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def compact(value: object) -> bytes:
    return canonical_json_v1_bytes(value) + b"\n"


def build_schema() -> dict[str, Any]:
    sha_def = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/local_policy_executor_v1.schema.json",
        "title": "PTCGDAP Windows local policy executor closure v1",
        "$defs": {"sha256": sha_def},
        "type": "object",
        "additionalProperties": False,
        "required": [
            "document_type", "schema_version", "executor_id", "executor_version",
            "authority_scope", "target", "parent_policy_package", "author_package",
            "resources", "implementation", "input_contract", "model", "fallback", "capabilities",
        ],
        "properties": {
            "document_type": {"const": "local_policy_executor_v1"},
            "schema_version": {"const": 1},
            "executor_id": {"const": EXECUTOR_ID},
            "executor_version": {"const": "1.0.0"},
            "authority_scope": {"const": "development_and_device_canary_only"},
            "target": _object_schema({
                "host": {"const": "godot"},
                "platform": {"const": "windows"},
                "architecture": {"const": "x86_64"},
                "execution_location": {"const": "device_local"},
                "portable_baseline": {"const": "gdscript"},
            }),
            "parent_policy_package": _object_schema({
                "path": {"const": "data/ptcgdap/marnie_windows_policy_package_v1.json"},
                "canonical_sha256": {"$ref": "#/$defs/sha256"},
                "package_id": {"const": "ptcgdap.marnie.windows-local.policy"},
                "package_version": {"const": "0.1.0"},
            }),
            "author_package": _object_schema({
                "path": {"const": "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"},
                "archive_sha256": {"$ref": "#/$defs/sha256"},
                "package_id": {"const": "ptcgdap.marnie.windows-local"},
                "package_version": {"const": "0.1.0"},
            }),
            "resources": {
                "type": "array", "minItems": 9, "maxItems": 9,
                "items": _object_schema({
                    "location": {"enum": ["product_bundle", "author_archive"]},
                    "path": {"type": "string", "minLength": 1, "maxLength": 256},
                    "hash_kind": {"enum": ["canonical_json_v1", "raw_sha256"]},
                    "sha256": {"$ref": "#/$defs/sha256"},
                    "required": {"const": True},
                }),
            },
            "implementation": {
                "type": "array", "minItems": 7, "maxItems": 7,
                "items": _object_schema({
                    "role": {"type": "string", "minLength": 1, "maxLength": 64},
                    "path": {"type": "string", "minLength": 1, "maxLength": 256},
                    "raw_sha256": {"$ref": "#/$defs/sha256"},
                }),
            },
            "input_contract": _object_schema({
                "boundary": {"const": "agent(raw_observation)->list[int]"},
                "card_id_domain": {"const": "godot_local_card_uid_v1"},
                "policy_output": {"const": "current_window_indexes_only"},
                "public_only": {"const": True},
                "same_window_required": {"const": True},
                "engine_reference_allowed": {"const": False},
            }),
            "model": _object_schema({
                "learned_model": {"const": "none"},
                "backend": {"const": "none"},
                "artifact_path": {"type": "null"},
                "artifact_sha256": {"type": "null"},
                "weights_status": {"const": "unused_non_model_payload"},
            }),
            "fallback": _object_schema({
                "owner": {"const": "restricted_base_graph"},
                "mode": {"const": "deterministic_same_window"},
                "remote": {"const": False},
                "classic_raw_state": {"const": False},
                "unexpected_fallback_expected": {"const": 0},
            }),
            "capabilities": _object_schema({
                "cabt_search": {"const": "none"},
                "seeded_offline": {"const": False},
                "network_ingress": {"const": False},
                "network_egress": {"const": False},
                "system_python": {"const": False},
                "external_process": {"const": False},
                "dynamic_model_download": {"const": False},
                "match_hot_swap": {"const": False},
            }),
        },
    }


def _object_schema(properties: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties),
        "properties": properties,
    }


def build_profile() -> dict[str, Any]:
    return {
        "document_type": "local_policy_executor_profile_v1",
        "schema_version": 1,
        "profile_id": "ptcgdap-windows-local-policy-executor-v1",
        "executor_id": EXECUTOR_ID,
        "manifest_path": MANIFEST_PATH.relative_to(ROOT).as_posix(),
        "parent_policy_package_canonical_sha256": PARENT_CANONICAL_SHA256,
        "declared_target": {
            "host": "godot", "platform": "windows", "architecture": "x86_64",
            "execution_location": "device_local", "portable_baseline": "gdscript",
        },
        "runtime_authority": {
            "selects_current_window_indexes": True,
            "owns_engine_commit": False,
            "owns_action_ticket": False,
            "classic_fallback": False,
            "remote_fallback": False,
        },
        "model_contract": {
            "learned_model": "none", "backend": "none",
            "operator_case_count": 0, "operator_skip_count": 0,
        },
        "rollback": {
            "previous_executor": "AuthorStrategyDevelopmentPolicy.gd",
            "new_matches_only": True,
            "match_hot_swap": False,
        },
        "production_ready": False,
    }


def build_manifest() -> dict[str, Any]:
    if canonical_sha(PARENT_MANIFEST_PATH) != PARENT_CANONICAL_SHA256:
        raise RuntimeError("D051 parent policy manifest drift")
    if sha(AUTHOR_ARCHIVE_PATH.read_bytes()) != AUTHOR_ARCHIVE_SHA256:
        raise RuntimeError("author archive drift")
    with zipfile.ZipFile(AUTHOR_ARCHIVE_PATH, "r") as archive:
        members = {name: archive.read(name) for name in ARCHIVE_RESOURCES}
    resources = [
        {
            "location": "product_bundle", "path": path,
            "hash_kind": "canonical_json_v1", "sha256": canonical_sha(ROOT / path), "required": True,
        }
        for path in PRODUCT_RESOURCES
    ]
    resources.extend(
        {
            "location": "author_archive", "path": path,
            "hash_kind": "raw_sha256", "sha256": sha(members[path]), "required": True,
        }
        for path in ARCHIVE_RESOURCES
    )
    resources.sort(key=lambda row: row["path"])
    implementation = [
        {"role": role, "path": path, "raw_sha256": sha((ROOT / path).read_bytes())}
        for role, path in IMPLEMENTATIONS
    ]
    implementation.sort(key=lambda row: row["path"])
    return {
        "document_type": "local_policy_executor_v1",
        "schema_version": 1,
        "executor_id": EXECUTOR_ID,
        "executor_version": "1.0.0",
        "authority_scope": "development_and_device_canary_only",
        "target": {
            "host": "godot", "platform": "windows", "architecture": "x86_64",
            "execution_location": "device_local", "portable_baseline": "gdscript",
        },
        "parent_policy_package": {
            "path": PARENT_MANIFEST_PATH.relative_to(ROOT).as_posix(),
            "canonical_sha256": PARENT_CANONICAL_SHA256,
            "package_id": "ptcgdap.marnie.windows-local.policy",
            "package_version": "0.1.0",
        },
        "author_package": {
            "path": AUTHOR_ARCHIVE_PATH.relative_to(ROOT).as_posix(),
            "archive_sha256": AUTHOR_ARCHIVE_SHA256,
            "package_id": "ptcgdap.marnie.windows-local",
            "package_version": "0.1.0",
        },
        "resources": resources,
        "implementation": implementation,
        "input_contract": {
            "boundary": "agent(raw_observation)->list[int]",
            "card_id_domain": "godot_local_card_uid_v1",
            "policy_output": "current_window_indexes_only",
            "public_only": True,
            "same_window_required": True,
            "engine_reference_allowed": False,
        },
        "model": {
            "learned_model": "none", "backend": "none",
            "artifact_path": None, "artifact_sha256": None,
            "weights_status": "unused_non_model_payload",
        },
        "fallback": {
            "owner": "restricted_base_graph", "mode": "deterministic_same_window",
            "remote": False, "classic_raw_state": False, "unexpected_fallback_expected": 0,
        },
        "capabilities": {
            "cabt_search": "none", "seeded_offline": False,
            "network_ingress": False, "network_egress": False,
            "system_python": False, "external_process": False,
            "dynamic_model_download": False, "match_hot_swap": False,
        },
    }


def build_outputs() -> dict[Path, bytes]:
    schema = build_schema()
    profile = build_profile()
    manifest = build_manifest()
    outputs = {
        SCHEMA_PATH: pretty(schema),
        PROFILE_PATH: pretty(profile),
        MANIFEST_PATH: compact(manifest),
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
        "document_type": "local_policy_executor_bundle_v1",
        "schema_version": 1,
        "executor_id": EXECUTOR_ID,
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
        print("local policy executor v1 written")
        print("manifest_canonical_sha256=" + canonical_sha(MANIFEST_PATH))
    else:
        for path, expected in outputs.items():
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(f"local policy executor artifact drift: {path.relative_to(ROOT).as_posix()}")
        print("local policy executor v1 verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
