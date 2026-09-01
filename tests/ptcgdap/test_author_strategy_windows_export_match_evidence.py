from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts" / "ptcgdap" / "as_wp6_windows_export_match"
PACKAGE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
SEED_REVISION = "26765D24DDA00DAEC4E99DA75D71A17FE7D85B2516CC1E5C120A5A94E1565072"


def _read_json(name: str) -> dict:
    return json.loads((EVIDENCE / name).read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class AuthorStrategyWindowsExportMatchEvidenceTests(unittest.TestCase):
    def test_exported_executable_completes_three_clean_rules_matches(self) -> None:
        report = _read_json("windows_export_match_3games.json")
        match = report["match"]
        totals = match["totals"]

        self.assertEqual(report["document_type"], "author_strategy_windows_export_match_execution_v1")
        self.assertTrue(report["development_only"])
        self.assertFalse(report["production_ready"])
        self.assertFalse(report["a5_claimed"])
        self.assertFalse(report["ui_driven"])
        self.assertFalse(report["network_blocked"])
        self.assertFalse(report["network_isolation_proven"])
        self.assertEqual(match["archive_sha256"], PACKAGE_SHA256)
        self.assertEqual(match["card_id_domain"], "godot_local_card_uid_v1")
        self.assertTrue(match["standalone_export"])
        self.assertTrue(match["export_template_feature"])
        self.assertEqual(match["runtime_platform"], "Windows")
        self.assertTrue(match["is_clean"])
        self.assertTrue(match["complete_match_finished"])
        self.assertEqual(match["games"], 3)
        self.assertEqual([row["seed"] for row in match["per_game"]], [84600, 84601, 84602])
        self.assertTrue(all(row["terminal"] and not row["failure"] for row in match["per_game"]))
        self.assertEqual(totals["policy_calls"], 186)
        self.assertEqual(totals["policy_successes"], 186)
        self.assertEqual(totals["engine_commits"], 186)
        for key in (
            "policy_errors",
            "invalid_outputs",
            "same_window_fallbacks",
            "classic_fallbacks",
            "external_process_attempts",
            "engine_rejections",
        ):
            self.assertEqual(totals[key], 0, key)
        self.assertEqual(report["process"]["observed_child_process_ids"], [])
        self.assertEqual(report["process"]["observed_network_endpoints"], [])
        self.assertTrue(report["claims"]["exported_executable_complete_rules_match"])
        self.assertFalse(report["claims"]["exported_exe_airplane_ui_match"])
        self.assertFalse(report["claims"]["production_signature"])
        self.assertFalse(report["claims"]["approved_device_profile"])
        self.assertFalse(report["claims"]["formal_a5"])

    def test_cold_install_seed_and_export_inventory_are_pinned(self) -> None:
        marker = _read_json("runtime_seed_marker.json")
        export = _read_json("export_artifact_summary.json")
        report = _read_json("windows_export_match_3games.json")

        self.assertEqual(marker["schema_version"], 1)
        self.assertEqual(marker["pipeline_revision"], 1)
        self.assertEqual(marker["manifest_entry_count"], 1712)
        self.assertEqual(marker["content_revision"], SEED_REVISION)
        self.assertEqual(export["inventory_entry_count"], 4485)
        self.assertEqual(export["required_path_count"], 19)
        self.assertEqual(export["present_required_path_count"], 19)
        self.assertEqual(export["missing_paths"], [])
        self.assertEqual(export["executable"]["sha256"], report["export"]["executable_sha256"])
        self.assertEqual(export["executable"]["bytes"], report["export"]["executable_bytes"])
        self.assertGreater(report["process"]["elapsed_msec"], report["match"]["elapsed_msec"])
        self.assertLess(report["process"]["elapsed_msec"], 60_000)

    def test_evidence_manifest_covers_exact_public_files(self) -> None:
        manifest = _read_json("manifest.json")
        expected = {
            "README.md",
            "diagnostic_history.md",
            "export_artifact_summary.json",
            "known_gaps.md",
            "reproducibility_audit.json",
            "runtime_seed_marker.json",
            "test_results.json",
            "windows_export_match_3games.json",
            "windows_pck_runtime_probe.log",
        }
        actual_files = {path.name for path in EVIDENCE.iterdir() if path.is_file() and path.name != "manifest.json"}
        listed = {row["path"] for row in manifest["files"]}
        self.assertEqual(actual_files, expected)
        self.assertEqual(listed, expected)
        for row in manifest["files"]:
            path = EVIDENCE / row["path"]
            self.assertEqual(row["bytes"], path.stat().st_size)
            self.assertEqual(row["sha256"], _sha256(path))

    def test_repeat_export_preserves_logical_inventory_but_not_raw_containers(self) -> None:
        audit = _read_json("reproducibility_audit.json")
        self.assertEqual(audit["godot_version"], "4.6.1.stable.official.14d19694e")
        self.assertEqual(audit["inventory_entry_count"], 4485)
        self.assertEqual(audit["logical_member_difference_count"], 0)
        self.assertTrue(audit["logical_inventory_equal"])
        self.assertFalse(audit["raw_container_reproducible"])
        self.assertNotEqual(audit["build_a"]["pck_sha256"], audit["build_b"]["pck_sha256"])
        self.assertNotEqual(audit["build_a"]["executable_sha256"], audit["build_b"]["executable_sha256"])

    def test_governance_records_scope_without_overclaim(self) -> None:
        decisions = (ROOT / "docs" / "ptcgdap" / "07-decisions-risks-and-open-questions.md").read_text(encoding="utf-8")
        status = (ROOT / "docs" / "ptcgdap" / "STATUS.md").read_text(encoding="utf-8")
        for text in (decisions, status):
            self.assertIn("D045", text)
            self.assertIn("as_wp6_windows_export_match", text)
            self.assertIn("186/186", text)
            self.assertIn("exported EXE", text)
        self.assertIn("production_ready=false", decisions)
        self.assertIn("airplane-mode UI", decisions)


if __name__ == "__main__":
    unittest.main()
