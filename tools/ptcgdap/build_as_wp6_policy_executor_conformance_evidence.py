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


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_policy_executor_conformance"
REPORT = EVIDENCE / "python_report.json"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"

FILES = (
    "artifacts/ptcgdap/as_wp6_policy_executor_conformance/README.md",
    "artifacts/ptcgdap/as_wp6_policy_executor_conformance/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_policy_executor_conformance/test_results.json",
    "artifacts/ptcgdap/as_wp6_policy_executor_conformance/python_report.json",
    "artifacts/ptcgdap/as_wp6_policy_executor_conformance/evidence_summary.json",
    "contracts/ptcgdap/policy_executor_conformance_v1.schema.json",
    "contracts/ptcgdap/policy_executor_conformance_v1_profile.json",
    "contracts/ptcgdap/policy_executor_conformance_v1_vectors.json",
    "contracts/ptcgdap/policy_executor_conformance_v1_bundle.json",
    "data/ptcgdap/marnie_windows_policy_package_v1.json",
    "contracts/ptcgdap/marnie_portable_policy_bundle.json",
    "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json",
    "scripts/ai/ptcgdap/policy_executor_conformance.py",
    "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd",
    "tests/ptcgdap/test_policy_executor_conformance_v1.py",
    "tests/ptcgdap/test_as_wp6_policy_executor_conformance_evidence.py",
    "tests/ptcgdap/test_p2_wp3_boundaries.py",
    "tests/ptcgdap/godot/test_policy_executor_conformance.gd",
    "tools/ptcgdap/build_policy_executor_conformance_v1.py",
    "tools/ptcgdap/run_policy_executor_conformance.py",
    "tools/ptcgdap/build_as_wp6_policy_executor_conformance_evidence.py",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/08-author-strategy-package-mode.md",
    "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical(path: Path) -> str | None:
    try:
        return _sha(canonical_json_v1_bytes(load_json_strict(path)))
    except ValueError:
        return None


def _entry(relative: str) -> dict[str, object]:
    path = ROOT / relative
    value = path.read_bytes()
    row: dict[str, object] = {"path": relative, "bytes": len(value), "raw_sha256": _sha(value)}
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = _canonical(path)
    return row


def build_summary() -> dict[str, object]:
    report = load_json_strict(REPORT)
    results = load_json_strict(EVIDENCE / "test_results.json")
    profile_path = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_profile.json"
    vectors_path = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_vectors.json"
    bundle_path = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_bundle.json"
    if (
        type(report) is not dict
        or report.get("accepted") is not True
        or report.get("parent_vector_case_count") != 28
        or report.get("parent_vector_mismatch_count") != 0
        or report.get("probe_case_count") != 8
        or report.get("probe_mismatch_count") != 0
        or report.get("skipped_case_count") != 0
        or report.get("model") != {"learned_model": "none", "backend": "none", "operator_case_count": 0, "operator_skip_count": 0}
    ):
        raise ValueError("D052 Python conformance report invalid")
    if type(results) is not dict or results.get("godot", {}).get("passed") != 1 or results.get("godot", {}).get("failed") != 0:
        raise ValueError("D052 Godot evidence invalid")
    compatibility = results.get("compatibility")
    if compatibility != {
        "parent_snapshots_passed": 106,
        "static_boundaries_passed": 189,
        "source_lock_passed": 24,
        "failed": 0,
    }:
        raise ValueError("D052 compatibility evidence invalid")
    godot_log = ROOT / results["godot"]["log_path"]
    text = godot_log.read_text(encoding="utf-8", errors="replace")
    if "PASS test_declared_no_model_subset_matches_parent_and_all_p6_probes" not in text or "Total: 1 | Failed: 0" not in text:
        raise ValueError("D052 Godot log invalid")
    return {
        "document_type": "as_wp6_policy_executor_conformance_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D052",
        "work_package": "AS-WP6/P6-02",
        "status": "windows_no_model_cross_runtime_conformance_complete",
        "generated_on": "2026-08-14",
        "contract": {
            "profile_canonical_sha256": _canonical(profile_path),
            "vectors_canonical_sha256": _canonical(vectors_path),
            "bundle_canonical_sha256": _canonical(bundle_path),
            "policy_package_manifest_canonical_sha256": report["policy_package_manifest_canonical_sha256"],
            "portable_policy_bundle_canonical_sha256": report["portable_policy_bundle_canonical_sha256"],
        },
        "python": {
            "report_path": REPORT.relative_to(ROOT).as_posix(),
            "report_raw_sha256": _sha(REPORT.read_bytes()),
            "report_canonical_sha256": _canonical(REPORT),
            "unit_passed": results["python"]["passed"],
            "parent_cases": report["parent_vector_case_count"],
            "probe_cases": report["probe_case_count"],
            "mismatches": report["parent_vector_mismatch_count"] + report["probe_mismatch_count"],
            "skips": report["skipped_case_count"],
        },
        "godot": {
            "focused_passed": results["godot"]["passed"],
            "focused_failed": results["godot"]["failed"],
            "elapsed_seconds": results["godot"]["elapsed_seconds"],
            "log_path": results["godot"]["log_path"],
            "log_raw_sha256": _sha(godot_log.read_bytes()),
            "same_parent_case_count": 28,
            "same_probe_case_count": 8,
            "mismatches": 0,
            "skips": 0,
        },
        "model": report["model"],
        "compatibility": compatibility,
        "claims": {
            "p6_02_declared_no_model_subset": True,
            "p6_03_local_policy_executor": False,
            "model_backed_lane": False,
            "execution_authority": False,
            "production_ready": False,
            "device_accepted": False,
            "a2_claimed": False,
            "a5_claimed": False,
            "android_claimed": False,
        },
    }


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_policy_executor_conformance_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D052",
        "files": [_entry(path) for path in FILES],
    }


def _render(value: dict[str, object]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    summary = build_summary()
    if args.write:
        SUMMARY.write_bytes(_render(summary))
    elif not SUMMARY.is_file() or SUMMARY.read_bytes() != _render(summary):
        raise SystemExit("D052 evidence summary drift")
    manifest = build_manifest()
    if args.write:
        MANIFEST.write_bytes(_render(manifest))
    elif not MANIFEST.is_file() or MANIFEST.read_bytes() != _render(manifest):
        raise SystemExit("D052 evidence manifest drift")
    print("D052 evidence verified" if args.check else "D052 evidence written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
