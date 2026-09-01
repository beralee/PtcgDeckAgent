from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_profile_qualification"
SUMMARY = EVIDENCE / "evidence_summary.json"
REPORT = EVIDENCE / "windows_profile_qualification_report.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_windows_profile_qualification_evidence.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6WindowsProfileQualificationEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_records_candidate_limits_without_approving_profile_or_a5(self) -> None:
        summary = load_json_strict(SUMMARY)
        report = load_json_strict(REPORT)
        self.assertEqual("D056", summary["decision_id"])
        self.assertEqual("windows_candidate_profile_qualified", summary["status"])
        self.assertEqual(3, summary["validation"]["ordinary_ui_terminal_games"])
        self.assertEqual(955, summary["validation"]["full_python_regression_passed"])
        self.assertEqual(173, summary["validation"]["decision_samples"])
        self.assertEqual(173, summary["validation"]["policy_successes"])
        self.assertEqual(172, summary["validation"]["engine_commits"])
        self.assertEqual(0, summary["validation"]["failure_counters_total"])
        self.assertTrue(summary["claims"]["candidate_resource_limits_met"])
        for key in (
            "device_profile_approved",
            "os_network_isolation",
            "production_ready",
            "a2_claimed",
            "a5_claimed",
            "android_claimed",
        ):
            self.assertFalse(summary["claims"][key], key)
        self.assertEqual(
            "A19C3CBB3AD8D5F9B0FA93C6D385982DBCF8D1F97F60D61D427DB5806E1150AE",
            report["qualification_id"],
        )
        self.assertTrue(report["threshold_evaluation"]["all_limits_met"])
        self.assertFalse(report["claims"]["profile_approval_granted"])
        self.assertFalse(report["claims"]["formal_device_report"])
        self.assertFalse(report["claims"]["a5_claimed"])

    def test_manifest_binds_evidence_implementation_validation_and_parent(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "artifacts/ptcgdap/as_wp6_windows_profile_qualification/windows_profile_qualification_report.json",
            "artifacts/ptcgdap/as_wp6/parent_snapshot/manifest.json",
            "data/ptcgdap/author_strategy_device_acceptance_profile.json",
            "scripts/tools/run_ptcgdap_windows_profile_qualification.ps1",
            "tools/ptcgdap/build_windows_profile_qualification.py",
            "tests/ptcgdap/test_windows_profile_qualification.py",
        ):
            self.assertIn(required, paths)
        for row in manifest["files"]:
            path = ROOT / row["path"]
            value = path.read_bytes()
            self.assertEqual(row["bytes"], len(value), row["path"])
            self.assertEqual(row["raw_sha256"], sha(value), row["path"])
            if row.get("canonical_sha256") is not None:
                self.assertEqual(
                    row["canonical_sha256"],
                    sha(canonical_json_v1_bytes(load_json_strict(path))),
                    row["path"],
                )


if __name__ == "__main__":
    unittest.main()
