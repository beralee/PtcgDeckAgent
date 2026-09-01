from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts" / "ptcgdap" / "as_wp6_windows_ui_match"
PACKAGE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
RELEASE_EXE_SHA256 = "DFB0E5D77251A9015A8F97494C2256F1D7A473132AF4E2295589708EF18917AA"


def _read_json(name: str) -> dict:
    return json.loads((EVIDENCE / name).read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class AuthorStrategyWindowsUiMatchEvidenceTests(unittest.TestCase):
    def test_real_mouse_ui_match_is_clean_and_scoped(self) -> None:
        summary = _read_json("windows_ui_match_summary.json")
        match = summary["match"]
        wrapper = (ROOT / "scripts" / "tools" / "run_ptcgdap_windows_ui_match.ps1").read_text(encoding="utf-8")

        self.assertEqual(summary["milestone"], "D046/P6-25")
        self.assertEqual(summary["package"]["archive_sha256"], PACKAGE_SHA256)
        self.assertEqual(summary["package"]["card_id_domain"], "godot_local_card_uid_v1")
        self.assertFalse(summary["package"]["cabt_exportable"])
        self.assertTrue(summary["input_and_scene_path"]["real_mouse_input_proven"])
        self.assertEqual(summary["input_and_scene_path"]["real_mouse_click_count"], 3)
        self.assertEqual(
            summary["input_and_scene_path"]["observed_scene_paths"],
            [
                "res://scenes/main_menu/MainMenu.tscn",
                "res://scenes/battle_setup/BattleSetup.tscn",
                "res://scenes/battle/BattleScene.tscn",
            ],
        )
        self.assertTrue(summary["network"]["application_network_disabled"])
        self.assertEqual(summary["network"]["application_network_attempt_markers"], "")
        self.assertFalse(summary["network"]["network_isolation_proven"])
        self.assertTrue(match["passed"] and match["is_clean"] and match["complete_match_finished"])
        self.assertEqual((match["policy_calls"], match["policy_successes"]), (44, 44))
        self.assertEqual(match["engine_commits"], 44)
        for key in (
            "policy_errors",
            "invalid_outputs",
            "same_window_fallbacks",
            "classic_fallbacks",
            "engine_rejections",
            "external_process_attempts",
        ):
            self.assertEqual(match[key], 0, key)
        self.assertEqual(len(summary["screenshots"]), 5)
        self.assertEqual(len({row["sha256"] for row in summary["screenshots"]}), 5)
        self.assertFalse(summary["claims"]["production_ready"])
        self.assertFalse(summary["claims"]["airplane_mode_claimed"])
        self.assertFalse(summary["claims"]["a5_claimed"])
        self.assertIn("ArtifactDirectory must stay under", wrapper)
        self.assertIn("Refusing to overwrite existing artifact directory", wrapper)
        self.assertNotIn("netsh advfirewall", wrapper.lower())

    def test_current_source_release_export_completes_three_clean_matches(self) -> None:
        summary = _read_json("windows_release_match_summary.json")
        match = summary["match"]

        self.assertEqual(summary["executable"]["sha256"], RELEASE_EXE_SHA256)
        self.assertEqual(summary["inventory"]["entry_count"], 4491)
        self.assertEqual(summary["inventory"]["required_path_count"], 19)
        self.assertEqual(summary["inventory"]["present_required_path_count"], 19)
        self.assertEqual(summary["inventory"]["missing_paths"], [])
        self.assertEqual((match["terminal_games"], match["games"]), (3, 3))
        self.assertEqual(match["seeds"], [84600, 84601, 84602])
        self.assertEqual((match["policy_calls"], match["policy_successes"]), (186, 186))
        self.assertEqual(match["engine_commits"], 186)
        for key in (
            "policy_errors",
            "invalid_outputs",
            "same_window_fallbacks",
            "classic_fallbacks",
            "engine_rejections",
            "external_process_attempts",
        ):
            self.assertEqual(match[key], 0, key)
        self.assertEqual(summary["process"]["observed_child_process_count"], 0)
        self.assertEqual(summary["process"]["observed_network_endpoint_count"], 0)
        self.assertFalse(summary["claims"]["network_isolation_proven"])
        self.assertFalse(summary["claims"]["production_ready"])

    def test_feature_rollback_fails_closed_before_author_execution(self) -> None:
        drill = _read_json("rollback_drill.json")
        wrapper = (ROOT / "scripts" / "tools" / "run_ptcgdap_author_strategy_rollback_drill.ps1").read_text(
            encoding="utf-8"
        )

        self.assertEqual(drill["executable_sha256"], RELEASE_EXE_SHA256)
        self.assertEqual(drill["activation_argument"], "--ptcgdap-disable-author-strategy-mode")
        self.assertEqual((drill["expected_exit_code"], drill["actual_exit_code"]), (1, 1))
        self.assertEqual(drill["failure_code"], "author_strategy_feature_disabled")
        self.assertEqual(drill["policy_calls"], 0)
        self.assertEqual(drill["engine_commits"], 0)
        self.assertTrue(drill["failed_closed_before_execution"])
        self.assertFalse(drill["user_packages_deleted"])
        self.assertFalse(drill["active_match_hot_switch_allowed"])
        self.assertFalse(drill["production_rollback_claimed"])
        self.assertIn("Exported executable no longer matches the export manifest", wrapper)
        self.assertIn("--ptcgdap-disable-author-strategy-mode", wrapper)
        self.assertIn("author_strategy_feature_disabled", wrapper)
        self.assertIn("Refusing to overwrite existing output", wrapper)
        self.assertIn("policy_calls -eq 0", wrapper)

    def test_evidence_manifest_covers_exact_public_files(self) -> None:
        manifest = _read_json("manifest.json")
        expected = {
            "README.md",
            "known_gaps.md",
            "rollback_drill.json",
            "test_results.json",
            "windows_release_match_summary.json",
            "windows_ui_match_summary.json",
        }
        actual = {path.name for path in EVIDENCE.iterdir() if path.is_file() and path.name != "manifest.json"}
        listed = {row["path"] for row in manifest["files"]}
        self.assertEqual(actual, expected)
        self.assertEqual(listed, expected)
        for row in manifest["files"]:
            path = EVIDENCE / row["path"]
            self.assertEqual(row["bytes"], path.stat().st_size)
            self.assertEqual(row["sha256"], _sha256(path))

    def test_governance_records_development_scope_without_overclaim(self) -> None:
        paths = (
            ROOT / "docs" / "ptcgdap" / "README.md",
            ROOT / "docs" / "ptcgdap" / "07-decisions-risks-and-open-questions.md",
            ROOT / "docs" / "ptcgdap" / "08-author-strategy-package-mode.md",
            ROOT / "docs" / "ptcgdap" / "09-author-strategy-package-engineering-handoff.md",
            ROOT / "docs" / "ptcgdap" / "STATUS.md",
            ROOT / "docs" / "ptcgdap" / "IMPLEMENTATION_CHECKLIST.md",
        )
        for path in paths:
            text = path.read_text(encoding="utf-8")
            self.assertIn("D046", text, path.name)
            self.assertIn("as_wp6_windows_ui_match", text, path.name)
        decisions = paths[1].read_text(encoding="utf-8")
        self.assertIn("network_isolation_proven=false", decisions)
        self.assertIn("production_ready=false", decisions)
        self.assertIn("AS-WP6 仍是唯一即时游标", decisions)


if __name__ == "__main__":
    unittest.main()
