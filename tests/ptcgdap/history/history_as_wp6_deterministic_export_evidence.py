from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_deterministic_export"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class AsWp6DeterministicExportEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = load_json_strict(EVIDENCE / "manifest.json")
        self.report = load_json_strict(EVIDENCE / "reproducibility_report.json")
        self.results = load_json_strict(EVIDENCE / "test_results.json")

    def test_manifest_binds_evidence_and_current_owners(self) -> None:
        self.assertEqual("D050/P6-29", self.manifest["work_package"])
        self.assertEqual(
            "raw_windows_export_container_reproducibility_closed",
            self.manifest["status"],
        )
        for row in self.manifest["files"]:
            path = ROOT / row["path"] if "/" in row["path"] else EVIDENCE / row["path"]
            self.assertTrue(path.is_file(), row["path"])
            self.assertEqual(row["bytes"], path.stat().st_size, row["path"])
            self.assertEqual(row["sha256"], sha(path), row["path"])

    def test_two_full_exports_are_byte_exact_and_runtime_loadable(self) -> None:
        self.assertEqual("4.6.1.stable.official.14d19694e", self.report["godot_version"])
        self.assertEqual(4496, self.report["inventory_entry_count"])
        self.assertTrue(self.report["all_bound_outputs_exact_match"])
        outputs = self.report["outputs"]
        self.assertEqual(
            {
                "ptcgdap-windows-resources.zip": "9A90F8DC5750F29B421EFB9185B38348CB3A407ECAFE7C56389A92B2089A0E12",
                "ptcgdap-windows-resources.pck": "47279C38342565FE10DB55179D27300EE7EA69C9E803D8221A832C58317E7B38",
                "PtcgDeckAgent.exe": "6D3DCA39033468923A95ED8D0BE6FEF1EF37F0E4DCFD67420AF766D245117AB0",
                "windows-inventory.json": "69039475DB8F00E7CEFE85D30F5E842DC99264B98CA4A7AFAE8E67F0305BAD44",
                "windows-pck-runtime-probe.log": "54E2832701F2BAD3CC44F2E89EE4506B1443773734A962186DDE97EF799921C9",
            },
            {name: row["sha256_a"] for name, row in outputs.items()},
        )
        self.assertTrue(all(row["exact_match"] for row in outputs.values()))
        self.assertTrue(self.report["pck_runtime_probe"]["accepted"])
        self.assertEqual(22, self.report["pck_runtime_probe"]["present_required_path_count"])

    def test_canonicalized_executable_completed_real_rules_matches(self) -> None:
        match = self.report["canonicalized_executable_match"]
        self.assertEqual(3, match["games"])
        self.assertTrue(match["clean"])
        self.assertTrue(match["complete"])
        self.assertEqual(182, match["policy_calls"])
        self.assertEqual(182, match["policy_successes"])
        self.assertEqual(179, match["engine_commits"])
        for key in (
            "policy_errors",
            "invalid_outputs",
            "same_window_fallbacks",
            "classic_fallbacks",
            "engine_rejections",
            "external_process_attempts",
            "observed_child_processes",
            "observed_network_endpoints",
        ):
            self.assertEqual(0, match[key], key)

    def test_claim_boundary_remains_non_production(self) -> None:
        claims = self.manifest["claim_boundary"]
        self.assertTrue(claims["deterministic_windows_export_containers"])
        self.assertTrue(claims["canonicalized_executable_rules_match"])
        for key in (
            "production_key_provisioned",
            "production_package_approved",
            "os_network_isolation_proven",
            "approved_device_profile",
            "formal_a5",
            "android_claimed",
        ):
            self.assertFalse(claims[key], key)
        self.assertEqual(5, self.results["canonicalizer_unit_tests"]["passed"])
        self.assertEqual(13, self.results["focused_python_tests"]["passed"])

    def test_governance_records_the_closed_subgate_without_overclaim(self) -> None:
        decisions = (ROOT / "docs/ptcgdap/07-decisions-risks-and-open-questions.md").read_text(encoding="utf-8")
        checklist = (ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md").read_text(encoding="utf-8")
        status = (ROOT / "docs/ptcgdap/STATUS.md").read_text(encoding="utf-8")
        self.assertIn("### D050", decisions)
        self.assertIn("**REQUIRED P6-29", checklist)
        self.assertIn("as_wp6_windows_deterministic_export", status)
        self.assertIn("AS-WP6 仍是唯一即时游标", decisions)


if __name__ == "__main__":
    unittest.main()
