from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_policy_package_v1"
SOURCE_EXPORT = ROOT / ".tmp/ptcgdap_device_release/20260814-policy-package-v1-final"
EDITOR_REPORT = ROOT / "artifacts/ptcgdap/marnie_package_rules_e2e_10_games.json"
PERSISTENT_EXPORT_MANIFEST = EVIDENCE / "windows_export_manifest.json"
PERSISTENT_EXPORT_MATCH = EVIDENCE / "windows_export_match.json"
PERSISTENT_INVENTORY = EVIDENCE / "windows_export_inventory_policy_paths.json"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(document: object) -> str:
    return _sha(canonical_json_v1_bytes(document))


def _render(document: object) -> bytes:
    return canonical_json_v1_bytes(document) + b"\n"


def _copy_source_documents() -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    export_manifest = load_json_strict(SOURCE_EXPORT / "export-manifest.json")
    export_match = load_json_strict(SOURCE_EXPORT / "windows-export-match-policy-package.json")
    inventory = load_json_strict(SOURCE_EXPORT / "windows-inventory.json")
    members = [
        entry
        for entry in inventory["members"]
        if "policy_package_v1" in entry["path"] or "PolicyPackageManifest" in entry["path"]
    ]
    inventory_subset = {
        "document_type": "policy_package_export_inventory_subset_v1",
        "schema_version": 1,
        "parent_inventory_raw_sha256": _sha((SOURCE_EXPORT / "windows-inventory.json").read_bytes()),
        "parent_inventory_entry_count": inventory["entry_count"],
        "members": members,
    }
    return export_manifest, export_match, inventory_subset


def _persistent_documents(*, write: bool) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    if write:
        documents = _copy_source_documents()
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        for path, document in zip(
            (PERSISTENT_EXPORT_MANIFEST, PERSISTENT_EXPORT_MATCH, PERSISTENT_INVENTORY),
            documents,
            strict=True,
        ):
            path.write_bytes(_render(document))
        return documents
    return (
        load_json_strict(PERSISTENT_EXPORT_MANIFEST),
        load_json_strict(PERSISTENT_EXPORT_MATCH),
        load_json_strict(PERSISTENT_INVENTORY),
    )


def build_summary(
    export_manifest: dict[str, object],
    exported_wrapper: dict[str, object],
    inventory: dict[str, object],
) -> dict[str, object]:
    policy = load_json_strict(ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json")
    bundle = load_json_strict(ROOT / "contracts/ptcgdap/policy_package_v1_bundle.json")
    editor = load_json_strict(EDITOR_REPORT)
    exported = exported_wrapper["match"]
    process = exported_wrapper["process"]
    totals = exported["totals"]
    outputs = {
        entry["kind"]: {"bytes": entry["bytes"], "sha256": entry["sha256"]}
        for entry in export_manifest["outputs"]
    }
    return {
        "document_type": "as_wp6_policy_package_v1_evidence_summary_v1",
        "schema_version": 1,
        "date": "2026-08-14",
        "decision_id": "D051",
        "scope": "windows_local_policy_manifest_and_no_model_witness",
        "policy_package": {
            "document_type": policy["document_type"],
            "path": "data/ptcgdap/marnie_windows_policy_package_v1.json",
            "raw_sha256": _sha((ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json").read_bytes()),
            "canonical_sha256": _canonical_sha(policy),
            "bundle_canonical_sha256": _canonical_sha(bundle),
            "author_archive_sha256": policy["author_package"]["archive_sha256"],
            "learned_model": policy["model"]["learned_model"],
            "model_backend": policy["model"]["backend"],
            "weights_status": policy["author_package"]["weights"]["status"],
            "execution_location": policy["target"]["execution_location"],
            "authority_scope": policy["authority_scope"],
        },
        "editor_rules_e2e": {
            "report_path": EDITOR_REPORT.relative_to(ROOT).as_posix(),
            "report_raw_sha256": _sha(EDITOR_REPORT.read_bytes()),
            "is_clean": editor["is_clean"],
            "games": editor["games"],
            "wins": editor["wins"],
            "losses": editor["losses"],
            "policy_calls": editor["policy_calls"],
            "policy_successes": editor["policy_successes"],
            "policy_errors": editor["policy_errors"],
            "invalid_outputs": editor["invalid_outputs"],
            "fallbacks": editor["fallbacks"],
            "policy_package_manifest_canonical_sha256": editor["policy_package_manifest_canonical_sha256"],
            "learned_model": editor["learned_model"],
            "learned_model_invoked": editor["learned_model_invoked"],
        },
        "windows_export": {
            "run_id": "20260814-policy-package-v1-final",
            "manifest_raw_sha256": _sha(PERSISTENT_EXPORT_MANIFEST.read_bytes()),
            "inventory_parent_raw_sha256": inventory["parent_inventory_raw_sha256"],
            "inventory_entry_count": inventory["parent_inventory_entry_count"],
            "policy_package_resource_count": len(inventory["members"]),
            "outputs": outputs,
        },
        "exported_windows_rules_e2e": {
            "report_raw_sha256": _sha(PERSISTENT_EXPORT_MATCH.read_bytes()),
            "is_clean": exported["is_clean"],
            "games": exported["games"],
            "policy_calls": totals["policy_calls"],
            "policy_successes": totals["policy_successes"],
            "policy_errors": totals["policy_errors"],
            "invalid_outputs": totals["invalid_outputs"],
            "same_window_fallbacks": totals["same_window_fallbacks"],
            "classic_fallbacks": totals["classic_fallbacks"],
            "engine_commits": totals["engine_commits"],
            "engine_rejections": totals["engine_rejections"],
            "external_process_attempts": totals["external_process_attempts"],
            "policy_package_manifest_canonical_sha256": exported["policy_package_manifest_canonical_sha256"],
            "learned_model": exported["learned_model"],
            "learned_model_invoked": exported["learned_model_invoked"],
            "elapsed_msec": process["elapsed_msec"],
            "peak_working_set_mib": process["peak_working_set_mib"],
            "observed_child_process_ids": process["observed_child_process_ids"],
            "observed_network_endpoints": process["observed_network_endpoints"],
        },
        "claims": {
            "policy_package_v1_subgate": True,
            "device_local_windows_execution": True,
            "learned_model_declared_none": True,
            "production_ready": False,
            "player_live_allowed": False,
            "os_network_isolation_proven": False,
            "a5_claimed": False,
            "android_validated": False,
            "official_cabt_conformance": False,
        },
    }


def build_manifest() -> dict[str, object]:
    paths = (
        EVIDENCE / "README.md",
        EVIDENCE / "known_gaps.md",
        SUMMARY,
        PERSISTENT_EXPORT_MANIFEST,
        PERSISTENT_EXPORT_MATCH,
        PERSISTENT_INVENTORY,
        EVIDENCE / "test_results.json",
        ROOT / "contracts/ptcgdap/policy_package_v1.schema.json",
        ROOT / "contracts/ptcgdap/policy_package_v1_profile.json",
        ROOT / "contracts/ptcgdap/policy_package_v1_bundle.json",
        ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json",
        ROOT / "scripts/ai/ptcgdap/policy_package.py",
        ROOT / "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
        ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
        ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
        ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd",
        ROOT / "tools/ptcgdap/build_policy_package_v1.py",
        ROOT / "tests/ptcgdap/test_policy_package_v1.py",
    )
    files = []
    for path in paths:
        raw = path.read_bytes()
        relative = path.relative_to(ROOT).as_posix()
        entry: dict[str, object] = {"path": relative, "bytes": len(raw), "raw_sha256": _sha(raw)}
        if path.suffix == ".json":
            try:
                entry["canonical_sha256"] = _canonical_sha(load_json_strict(path))
            except ValueError:
                entry["canonical_sha256"] = None
        files.append(entry)
    return {
        "document_type": "as_wp6_policy_package_v1_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D051",
        "files": files,
    }


def write_or_check(*, check: bool) -> None:
    export_manifest, export_match, inventory = _persistent_documents(write=not check)
    summary = build_summary(export_manifest, export_match, inventory)
    if not check:
        SUMMARY.write_bytes(_render(summary))
    elif SUMMARY.read_bytes() != _render(summary):
        raise SystemExit("D051 evidence summary drift")
    manifest = build_manifest()
    if not check:
        MANIFEST.write_bytes(_render(manifest))
    elif MANIFEST.read_bytes() != _render(manifest):
        raise SystemExit("D051 evidence manifest drift")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    write_or_check(check=args.check)
    print("D051 evidence verified" if args.check else "D051 evidence written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
