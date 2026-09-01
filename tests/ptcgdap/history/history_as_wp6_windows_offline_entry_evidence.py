from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_offline_entry"
SUMMARY = EVIDENCE / "evidence_summary.json"
REPORT = EVIDENCE / "windows_offline_entry_report.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_windows_offline_entry_evidence.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6WindowsOfflineEntryEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"], cwd=ROOT,
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_closes_only_p6_07_windows_entry_subgate(self) -> None:
        summary = load_json_strict(SUMMARY)
        report = load_json_strict(REPORT)
        self.assertEqual("D055", summary["decision_id"])
        self.assertEqual("windows_project_offline_entry_complete", summary["status"])
        self.assertTrue(summary["claims"]["p6_07_windows_project_entry"])
        for key in (
            "os_network_isolation", "device_profile_approved", "production_ready",
            "a2_claimed", "a5_claimed", "android_claimed",
        ):
            self.assertFalse(summary["claims"][key], key)
        self.assertTrue(report["accepted"])
        self.assertEqual(6, report["required_device_member_count"])
        self.assertEqual(58, report["policy_calls"])
        self.assertEqual(58, report["policy_successes"])
        self.assertEqual(58, report["engine_commits"])
        self.assertEqual(0, report["failure_counters_total"])
        self.assertTrue(report["real_mouse_input_proven"])
        self.assertTrue(report["application_network_disabled"])
        self.assertFalse(report["os_network_isolation_proven"])

    def test_manifest_binds_every_evidence_input(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "scripts/tools/run_ptcgdap_windows_offline_entry.ps1",
            "tests/ptcgdap/test_windows_offline_entry.py",
            "artifacts/ptcgdap/as_wp6_windows_offline_entry/windows_offline_entry_report.json",
            "data/ptcgdap/marnie_windows_device_manifest_v1.json",
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
