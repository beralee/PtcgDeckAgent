from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_bytes_strict, load_json_strict


SCHEMA_PATH = ROOT / "contracts/ptcgdap/policy_package_v1.schema.json"
PROFILE_PATH = ROOT / "contracts/ptcgdap/policy_package_v1_profile.json"
MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
BUNDLE_PATH = ROOT / "contracts/ptcgdap/policy_package_v1_bundle.json"
CANDIDATE_PATH = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
SEALED_D051_RELEASE_BUNDLE_CANONICAL = "8C023680073C8CD0B7A423B07B840629812B2043305EA16411765A44F7F4D1EB"
SEALED_D051_ROLLBACK_PROFILE_CANONICAL = "01FCA4ED2B6228732AE91B5934F1A93272F92A2EC0B144E2695616C55BE7BF07"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(path: Path) -> str:
    return _sha(canonical_json_v1_bytes(load_json_strict(path)))


def _member_bytes() -> dict[str, bytes]:
    with zipfile.ZipFile(CANDIDATE_PATH, "r") as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("candidate archive has duplicate members")
        return {name: archive.read(name) for name in names}


def build_manifest() -> dict[str, object]:
    members = _member_bytes()
    author_manifest = load_json_bytes_strict(members["strategy_package.json"])
    if type(author_manifest) is not dict:
        raise ValueError("candidate strategy manifest must be an object")
    return {
        "document_type": "policy_package_v1",
        "schema_version": 1,
        "package_id": "ptcgdap.marnie.windows-local.policy",
        "package_version": "0.1.0",
        "authority_scope": "development_and_device_canary_only",
        "target": {
            "host": "godot",
            "platform": "windows",
            "architecture": "x86_64",
            "execution_location": "device_local",
        },
        "author_package": {
            "path": CANDIDATE_PATH.relative_to(ROOT).as_posix(),
            "package_id": author_manifest["package_id"],
            "package_version": author_manifest["package_version"],
            "archive_sha256": _sha(CANDIDATE_PATH.read_bytes()),
            "manifest_sha256": _sha(members["strategy_package.json"]),
            "deck_manifest_sha256": _sha(members["deck/deck_manifest.json"]),
            "policy_ir_sha256": _sha(members["policy/policy_ir.json"]),
            "adapter_sha256": _sha(members["policy/adapter.json"]),
            "config_sha256": _sha(members["policy/config.json"]),
            "weights": {
                "path": "policy/weights.bin",
                "sha256": _sha(members["policy/weights.bin"]),
                "status": "unused_non_model_payload",
            },
        },
        "contracts": {
            "cabt_contract_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/cabt_contract_bundle.json"),
            "card_catalog_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/card_id_catalog_bundle.json"),
            "base_executor_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/restricted_base_graph_executor_bundle.json"),
            "public_deck_adapter_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/public_deck_adapter_bundle.json"),
            "strategic_trace_v2_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/strategic_trace_v2_bundle.json"),
            "source_lock_canonical_sha256": _canonical_sha(ROOT / "docs/ptcgdap/SOURCE_LOCK.json"),
        },
        "executor": {
            "kind": "gdscript_restricted_ir_v1",
            "portable_baseline": "gdscript",
            "host_adapter_path": "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
            "host_adapter_sha256": _sha((ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd").read_bytes()),
            "base_executor_path": "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
            "base_executor_sha256": _sha((ROOT / "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd").read_bytes()),
            "match_owner_path": "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
            "match_owner_sha256": _sha((ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd").read_bytes()),
            "engine_action_executor_path": "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd",
            "engine_action_executor_sha256": _sha((ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd").read_bytes()),
            "policy_boundary": "agent(raw_observation)->list[int]",
        },
        "model": {
            "learned_model": "none",
            "backend": "none",
            "artifact_path": None,
            "artifact_sha256": None,
            "unexpected_fallback_expected": 0,
        },
        "trace": {
            "profile": "strategic_trace_v2",
            "bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/strategic_trace_v2_bundle.json"),
        },
        "capabilities": {
            "cabt_search": "none",
            "seeded_offline": False,
            "card_id_domain": "godot_local_card_uid_v1",
            "cabt_exportable": False,
            "network_ingress": False,
            "network_egress": False,
            "system_python": False,
            "external_process": False,
            "dynamic_model_download": False,
            "policy_output": "current_window_indexes_only",
        },
        "fallback": {
            "owner": "restricted_base_graph",
            "mode": "deterministic_same_window",
            "remote": False,
            "classic_raw_state": False,
        },
        "parents": {
            "author_package_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/author_strategy_package_bundle.json"),
            "author_match_host_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/author_strategy_match_host_bundle.json"),
            "author_live_seam_bundle_canonical_sha256": _canonical_sha(ROOT / "contracts/ptcgdap/author_strategy_live_seam_bundle.json"),
            "author_release_bundle_canonical_sha256": SEALED_D051_RELEASE_BUNDLE_CANONICAL,
            "source_lock_canonical_sha256": _canonical_sha(ROOT / "docs/ptcgdap/SOURCE_LOCK.json"),
        },
        "rollback": {
            "mode": "disable_author_strategy_for_new_matches",
            "target_kind": "author_strategy_disabled_release_profile",
            "target_path": "contracts/ptcgdap/author_strategy_release_profile.json",
            "target_canonical_sha256": SEALED_D051_ROLLBACK_PROFILE_CANONICAL,
            "current_match_hot_swap": False,
            "user_packages_preserved": True,
        },
    }


def build_bundle(manifest: dict[str, object]) -> dict[str, object]:
    artifacts = (
        ("schema", SCHEMA_PATH),
        ("profile", PROFILE_PATH),
    )
    entries = [
        {
            "id": artifact_id,
            "path": path.relative_to(ROOT).as_posix(),
            "canonical_sha256": _canonical_sha(path),
        }
        for artifact_id, path in artifacts
    ]
    entries.append({
        "id": "manifest",
        "path": MANIFEST_PATH.relative_to(ROOT).as_posix(),
        "canonical_sha256": _sha(canonical_json_v1_bytes(manifest)),
    })
    return {
        "schema_version": 1,
        "bundle_id": "ptcgdap-policy-package-v1-d051",
        "artifacts": entries,
    }


def _render(document: dict[str, object]) -> bytes:
    return canonical_json_v1_bytes(document) + b"\n"


def write_or_check(*, check: bool) -> None:
    manifest = build_manifest()
    bundle = build_bundle(manifest)
    for path, document in ((MANIFEST_PATH, manifest), (BUNDLE_PATH, bundle)):
        expected = _render(document)
        if check:
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(f"generated policy package document drift: {path.relative_to(ROOT).as_posix()}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    write_or_check(check=args.check)
    print("policy_package_v1 verified" if args.check else "policy_package_v1 written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
