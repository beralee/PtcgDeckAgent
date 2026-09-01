from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_profile_approval"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_windows_profile_approval_evidence.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6WindowsProfileApprovalEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_closes_profile_and_resource_gates_without_os_or_a5_claim(self) -> None:
        summary = load_json_strict(SUMMARY)
        self.assertEqual("D057", summary["decision_id"])
        self.assertEqual("windows_profile_product_approved", summary["status"])
        self.assertTrue(summary["claims"]["p6_05_profile_approved"])
        self.assertTrue(summary["claims"]["p6_11_windows_resources_accepted"])
        self.assertEqual("waived_by_product", summary["claims"]["p6_08_os_disconnection"])
        for key in (
            "os_network_isolation_proven",
            "production_ready",
            "a5_claimed",
            "android_claimed",
        ):
            self.assertFalse(summary["claims"][key], key)
        self.assertEqual(6, summary["qualification"]["thresholds_met"])
        self.assertEqual(173, summary["qualification"]["decision_samples"])
        self.assertEqual(3, summary["qualification"]["ordinary_ui_terminal_games"])

    def test_manifest_binds_approval_contract_qualification_and_governance(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "data/ptcgdap/author_strategy_device_acceptance_profile.json",
            "data/ptcgdap/marnie_windows_device_manifest_v1.json",
            "artifacts/ptcgdap/as_wp6_windows_profile_qualification/windows_profile_qualification_report.json",
            "docs/ptcgdap/STATUS.md",
            "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
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
