from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
from typing import Mapping


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (  # noqa: E402
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    load_json_strict,
)


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_profile_qualification"
REPORT = EVIDENCE / "windows_profile_qualification_report.json"
SUMMARY = EVIDENCE / "evidence_summary.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
MANIFEST = EVIDENCE / "manifest.json"
ALLOWED_SOURCE_ROOT = ROOT / ".tmp/ptcgdap_device_release"
EXPECTED_QUALIFICATION_ID = "A19C3CBB3AD8D5F9B0FA93C6D385982DBCF8D1F97F60D61D427DB5806E1150AE"
EXPECTED_PROFILE_CANONICAL = "DEE312331F6415A5A44D7767D94489A24C07B51A6164FA153765E420017F18FF"
EXPECTED_EXECUTABLE_SHA256 = "767C8AC08F64ADC35852677F6E62F155BD42717279AA259FDFD72ED15B1CD6FD"
EXPECTED_ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
EXPECTED_POLICY_PACKAGE = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
EXPECTED_LOCAL_EXECUTOR = "DCFA65A979F1525BD690D6919A80C0FE0858B819B7A4DA06795EB8B38AC824B5"


FILES = (
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/README.md",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/test_results.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/windows_profile_qualification_report.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6/parent_snapshot/manifest.json",
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/windows_offline_entry_report.json",
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/manifest.json",
    "data/ptcgdap/author_strategy_device_acceptance_profile.json",
    "data/ptcgdap/marnie_windows_device_manifest_v1.json",
    "scripts/tools/run_ptcgdap_windows_profile_qualification.ps1",
    "scripts/tools/run_ptcgdap_windows_ui_match.ps1",
    "scripts/tools/run_ptcgdap_author_strategy_rollback_drill.ps1",
    "tools/ptcgdap/build_windows_profile_qualification.py",
    "tools/ptcgdap/build_as_wp6_windows_profile_qualification_evidence.py",
    "tests/ptcgdap/test_windows_profile_qualification.py",
    "tests/ptcgdap/test_as_wp6_windows_profile_qualification_evidence.py",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
    "docs/ptcgdap/SOURCE_LOCK.json",
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _mapping(value: object, label: str) -> Mapping[str, object]:
    if type(value) is not dict:
        raise ValueError(f"{label} must be an object")
    return value


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _source(path: Path) -> dict[str, object]:
    allowed = ALLOWED_SOURCE_ROOT.resolve(strict=True)
    lexical = Path(os.path.abspath(path))
    if (
        not _is_within(lexical, allowed)
        or not lexical.is_file()
        or lexical.is_symlink()
        or lexical.resolve(strict=True) != lexical
        or getattr(lexical.stat(), "st_nlink", 1) != 1
        or lexical.stat().st_size <= 0
        or lexical.stat().st_size > 16 * 1024 * 1024
    ):
        raise ValueError("D056 source report must be one regular non-link file under the fixed export root")
    value = load_json_bytes_strict(lexical.read_bytes())
    if type(value) is not dict:
        raise ValueError("D056 source report must be a JSON object")
    return value


def _validate(report: dict[str, object]) -> None:
    profile = _mapping(report.get("profile"), "profile")
    export = _mapping(report.get("export"), "export")
    package = _mapping(report.get("package"), "package")
    samples = _mapping(report.get("samples"), "samples")
    measurements = _mapping(report.get("measurements"), "measurements")
    threshold = _mapping(report.get("threshold_evaluation"), "threshold evaluation")
    accounting = _mapping(report.get("match_accounting"), "match accounting")
    rollback = _mapping(report.get("rollback"), "rollback")
    claims = _mapping(report.get("claims"), "claims")
    evidence = _mapping(report.get("evidence"), "evidence")
    if (
        report.get("document_type") != "author_strategy_windows_profile_qualification_v1"
        or report.get("schema_version") != 1
        or report.get("qualification_id") != EXPECTED_QUALIFICATION_ID
        or profile.get("approval_status") != "proposed"
        or profile.get("formal_a5_eligible") is not False
        or profile.get("canonical_sha256") != EXPECTED_PROFILE_CANONICAL
        or export.get("executable_sha256") != EXPECTED_EXECUTABLE_SHA256
        or export.get("executable_bytes") != 274638736
        or package.get("archive_sha256") != EXPECTED_ARCHIVE_SHA256
        or package.get("policy_package_manifest_canonical_sha256") != EXPECTED_POLICY_PACKAGE
        or package.get("local_policy_executor_manifest_canonical_sha256") != EXPECTED_LOCAL_EXECUTOR
        or package.get("signature_scope") != "test_fixture_only"
        or package.get("execution_trusted") is not False
    ):
        raise ValueError("D056 source identity or trust boundary drift")
    if (
        samples.get("cold_start_count") != 3
        or samples.get("decision_count") != 173
        or type(samples.get("cold_start_msec")) is not list
        or len(samples["cold_start_msec"]) != 3
        or type(samples.get("decision_msec")) is not list
        or len(samples["decision_msec"]) != 173
        or type(samples.get("target_process_ids")) is not list
        or len(set(samples["target_process_ids"])) != 3
    ):
        raise ValueError("D056 sample coverage drift")
    expected_measurements = {
        "catalog_scan_msec": 305,
        "cold_start_msec": 5252,
        "decision_p95_msec": 22,
        "match_load_msec": 2103,
        "package_mib": 262,
        "peak_memory_mib": 545,
    }
    if dict(measurements) != expected_measurements:
        raise ValueError("D056 measurements drift")
    metrics = _mapping(threshold.get("metrics"), "threshold metrics")
    if threshold.get("all_limits_met") is not True or len(metrics) != 6:
        raise ValueError("D056 fixed threshold result drift")
    for metric, actual in expected_measurements.items():
        row = _mapping(metrics.get(metric), f"threshold {metric}")
        if row.get("actual") != actual or row.get("met") is not True:
            raise ValueError(f"D056 threshold drift: {metric}")
    if (
        accounting.get("ui_runs_passed") != 3
        or accounting.get("policy_calls") != 173
        or accounting.get("engine_commits") != 172
        or any(
            accounting.get(key) != 0
            for key in (
                "policy_errors",
                "invalid_outputs",
                "same_window_fallbacks",
                "classic_fallbacks",
                "engine_rejections",
                "external_process_attempts",
            )
        )
        or rollback.get("failed_closed_before_execution") is not True
        or rollback.get("policy_calls") != 0
        or rollback.get("engine_commits") != 0
        or rollback.get("user_packages_deleted") is not False
    ):
        raise ValueError("D056 match or rollback accounting drift")
    expected_claims = {
        "a5_claimed": False,
        "development_only": True,
        "formal_device_report": False,
        "os_network_isolation_proven": False,
        "production_ready": False,
        "profile_approval_granted": False,
    }
    if dict(claims) != expected_claims:
        raise ValueError("D056 claim boundary drift")
    ui_evidence = evidence.get("ui_reports")
    rollback_evidence = _mapping(evidence.get("rollback_report"), "rollback evidence")
    if (
        type(ui_evidence) is not list
        or len(ui_evidence) != 3
        or [row.get("index") for row in ui_evidence if type(row) is dict] != [1, 2, 3]
        or any(type(row) is not dict or len(str(row.get("raw_sha256", ""))) != 64 for row in ui_evidence)
        or len(str(rollback_evidence.get("raw_sha256", ""))) != 64
    ):
        raise ValueError("D056 evidence hash coverage drift")
    serialized = json.dumps(report, ensure_ascii=False)
    if "D:\\" in serialized or "C:\\" in serialized or "private" in serialized.lower():
        raise ValueError("D056 public evidence contains a host path or private marker")


def normalize(source_report: Path) -> dict[str, object]:
    report = _source(source_report)
    _validate(report)
    return report


def build_summary() -> dict[str, object]:
    report = load_json_strict(REPORT)
    results = load_json_strict(TEST_RESULTS)
    if type(report) is not dict or type(results) is not dict:
        raise ValueError("D056 evidence inputs are invalid")
    _validate(report)
    focused = _mapping(results.get("focused_green"), "focused results")
    release = _mapping(results.get("release_device_regression"), "release regression")
    real = _mapping(results.get("real_windows_qualification"), "real qualification")
    full = _mapping(results.get("full_python_regression"), "full Python regression")
    if (
        focused.get("passed") != 4
        or focused.get("failed") != 0
        or focused.get("skipped") != 0
        or release.get("passed") != 23
        or release.get("failed") != 0
        or release.get("skipped") != 0
        or real.get("qualification_id") != EXPECTED_QUALIFICATION_ID
        or real.get("passed") is not True
        or full.get("passed") != 955
        or full.get("failed") != 0
        or full.get("skipped") != 0
    ):
        raise ValueError("D056 validation results drift")
    accounting = _mapping(report["match_accounting"], "match accounting")
    samples = _mapping(report["samples"], "samples")
    measurements = _mapping(report["measurements"], "measurements")
    return {
        "document_type": "as_wp6_windows_profile_qualification_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D056",
        "work_package": "AS-WP6/P6-05-qualification",
        "status": "windows_candidate_profile_qualified",
        "generated_on": "2026-08-15",
        "qualification_id": EXPECTED_QUALIFICATION_ID,
        "validation": {
            "focused_python_passed": 4,
            "release_device_regression_passed": 23,
            "full_python_regression_passed": 955,
            "ordinary_ui_terminal_games": accounting["ui_runs_passed"],
            "decision_samples": samples["decision_count"],
            "policy_successes": accounting["policy_calls"],
            "engine_commits": accounting["engine_commits"],
            "failure_counters_total": 0,
            "candidate_thresholds_met": 6,
            "measurements": dict(measurements),
        },
        "claims": {
            "candidate_resource_limits_met": True,
            "device_profile_approved": False,
            "os_network_isolation": False,
            "production_ready": False,
            "a2_claimed": False,
            "a5_claimed": False,
            "android_claimed": False,
        },
    }


def _file_entry(relative_path: str) -> dict[str, object]:
    path = ROOT / relative_path
    raw = path.read_bytes()
    row: dict[str, object] = {
        "path": relative_path,
        "bytes": len(raw),
        "raw_sha256": _sha(raw),
    }
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = _sha(canonical_json_v1_bytes(load_json_strict(path)))
    return row


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_windows_profile_qualification_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D056",
        "files": [_file_entry(path) for path in FILES],
    }


def _render(value: dict[str, object]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--source-report", type=Path)
    args = parser.parse_args()
    if args.write:
        if args.source_report is None:
            raise SystemExit("--source-report is required with --write")
        REPORT.write_bytes(_render(normalize(args.source_report)))
        SUMMARY.write_bytes(_render(build_summary()))
        MANIFEST.write_bytes(_render(build_manifest()))
        print("D056 evidence written")
    else:
        if args.source_report is not None:
            raise SystemExit("--source-report is only valid with --write")
        if REPORT.read_bytes() != _render(load_json_strict(REPORT)):
            raise SystemExit("D056 normalized report drift")
        if SUMMARY.read_bytes() != _render(build_summary()):
            raise SystemExit("D056 evidence summary drift")
        if MANIFEST.read_bytes() != _render(build_manifest()):
            raise SystemExit("D056 evidence manifest drift")
        print("D056 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
