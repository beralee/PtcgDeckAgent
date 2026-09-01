from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "artifacts/ptcgdap/marnie_package_rules_e2e_10_games.json"
ARCHIVE = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
EXPECTED_ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
POST_D043_AUDITED_SOURCE_UPDATES = {
    "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd":
        "424A8331BB739117252437170A535EEB3C6A2B3E74C9FBF33D896390BD25491F",
    "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd":
        "24A5570491CB0B2DB2B737533652B9713DC508567C3122168015D9D8C8DB84CF",
    "scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd":
        "A964AF93E9175FB72C86A274E81AAF2A658A56B75081013FADE462FA6C67D01D",
    "scripts/ai/HeadlessMatchBridge.gd":
        "63B3238FBAEA1AD077668B82F41D914815DCCCCF56673A7F32B02858380F588E",
    "scripts/ai/DeckStrategyRegistry.gd":
        "3217C209BEEBD1637B62BD9B18DFBD39D6C51AD561A66284D944283BBB9EC8DD",
    "scripts/engine/GameStateMachine.gd":
        "E3D5E5E5F2F9383C12A449558B536FF5574E700E64F9D7B9039B3CF0E8619783",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class AuthorStrategyDevelopmentExecutionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = load_json_strict(REPORT)

    def test_exact_candidate_completed_ten_real_engine_games_cleanly(self) -> None:
        report = self.report
        self.assertEqual("windows_development_author_package_real_engine_e2e", report["evidence_kind"])
        self.assertEqual("godot_local_uid_package_development_execution", report["alignment_level"])
        self.assertEqual(EXPECTED_ARCHIVE_SHA256, report["package_archive_sha256"])
        self.assertEqual(EXPECTED_ARCHIVE_SHA256, sha256(ARCHIVE))
        self.assertEqual(list(range(84200, 84210)), report["seeds"])
        self.assertEqual((10, 2, 8, 0), (report["games"], report["wins"], report["losses"], report["draws"]))
        self.assertEqual(918, report["policy_calls"])
        self.assertEqual(report["policy_calls"], report["policy_successes"])
        for key in ("policy_errors", "invalid_outputs", "fallbacks"):
            self.assertEqual(0, report[key], key)
        self.assertEqual(10, report["setup_calls"])
        self.assertEqual(166, report["matched_rule_evaluations"])
        self.assertEqual(138, report["macro_preferred_selections"])
        self.assertTrue(report["is_clean"])
        self.assertEqual([], report["dirty_reasons"])
        for game in report["per_game"]:
            self.assertIn(game["winner_index"], (0, 1))
            self.assertIn(game["failure_reason"], ("normal_game_end", "deck_out"))
            self.assertFalse(game["stalled"])
            self.assertFalse(game["terminated_by_cap"])

    def test_report_binds_run_sources_and_post_run_updates_are_audited(self) -> None:
        self.assertFalse(self.report["source_changed_during_run"])
        self.assertEqual(self.report["source_at_start"], self.report["source_at_end"])
        for entry in self.report["source_at_start"]["files"]:
            path = ROOT / entry["path"]
            self.assertTrue(path.is_file(), entry["path"])
            current_sha = sha256(path)
            if current_sha != entry["raw_sha256"]:
                self.assertEqual(
                    POST_D043_AUDITED_SOURCE_UPDATES.get(entry["path"]),
                    current_sha,
                    entry["path"],
                )

    def test_development_execution_does_not_overclaim_product_authority(self) -> None:
        report = self.report
        self.assertTrue(report["development_host_execution"])
        self.assertTrue(report["local_index_boundary"])
        self.assertTrue(report["exact_archive_sha_development_gate"])
        self.assertFalse(report["external_process_dependency"])
        self.assertFalse(report["development_package_signature_required"])
        self.assertEqual("exact_builtin_archive_sha256", report["development_authority"])
        self.assertTrue(report["production_signature_gate_unchanged"])
        self.assertEqual("unprovisioned", report["production_signature_status"])
        self.assertFalse(report["official_cabt_interface_alignment"])
        self.assertFalse(report["cross_runtime_policy_conformance"])
        self.assertFalse(report["official_cabt_engine_parity"])
        self.assertFalse(report["player_live_allowed"])
        self.assertFalse(report["android_validated"])
        self.assertFalse(report["cabt_exportable"])
        self.assertFalse(report["learned_model_invoked"])
        self.assertEqual("none", report["learned_model"])
        self.assertEqual("none", report["model_backend"])
        self.assertEqual("device_local", report["execution_location"])
        self.assertEqual("ptcgdap.marnie.windows-local.policy", report["policy_package_id"])
        self.assertEqual(64, len(report["policy_package_manifest_canonical_sha256"]))
        self.assertEqual(
            "headless_bridge_first_legal_slot_not_package_selected",
            report["capabilities"]["take_prize"],
        )

    def test_public_policy_has_no_engine_object_or_process_boundary(self) -> None:
        policy = (ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd").read_text(encoding="utf-8")
        for forbidden in (
            "GameState",
            "GameStateMachine",
            "BattleScene",
            "CardInstance",
            "PokemonSlot",
            "OS.create_process",
            "HTTPClient",
        ):
            self.assertNotIn(forbidden, policy)
        support = (ROOT / "tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd").read_text(encoding="utf-8")
        self.assertNotIn("OS.create_process", support)
        self.assertIn("func _invoke_python(frame: Dictionary)", support)
        self.assertIn(EXPECTED_ARCHIVE_SHA256, support)

    def test_player_runtime_and_ready_gate_remain_closed(self) -> None:
        catalog = (ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd").read_text(encoding="utf-8")
        match_host = (ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd").read_text(encoding="utf-8")
        production_consumers = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (
                ROOT / "scripts/autoload/GameManager.gd",
                ROOT / "scenes/battle_setup/BattleSetup.gd",
                ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd",
            )
        )
        self.assertIn("package_release_not_approved", catalog)
        self.assertNotIn("extends AIOpponent", match_host)
        self.assertNotIn("AuthorStrategyDevelopmentPolicy", production_consumers)
        self.assertNotIn("MarniePackageDevelopmentAIOpponent", production_consumers)

    def test_player_owner_binds_policy_response_to_the_current_window(self) -> None:
        owner = (
            ROOT
            / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'response.get("public_observation_hash") != source.get("public_observation_hash")',
            owner,
        )
        self.assertIn('response.get("window_id") != source.get("window_id")', owner)
        self.assertIn('selector.call("expected_selection_source")', owner)
        self.assertIn('response.get("selection_source") != expected_source', owner)
        self.assertIn('response_error = "stale_policy_response"', owner)
        catalog = (ROOT / "tests/TestSuiteCatalog.gd").read_text(encoding="utf-8")
        self.assertIn('"test_author_strategy_windows_player_owner.gd": true', catalog)

    def test_player_owner_distinguishes_optional_empty_from_invalid_output(self) -> None:
        owner = (
            ROOT
            / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
        ).read_text(encoding="utf-8")
        self.assertIn("var validated_result: Variant = _validated_indexes(", owner)
        self.assertIn("if validated_result != null:", owner)
        self.assertIn('response_error = "invalid_policy_output"', owner)
        self.assertIn("_invalid_outputs += 1", owner)
        self.assertIn(
            "static func _validated_indexes(raw: Variant, count: int, minimum: int, maximum: int) -> Variant:",
            owner,
        )
        self.assertGreaterEqual(owner.count("return null"), 3)

    def test_new_real_engine_suite_is_registered_in_the_ai_lane(self) -> None:
        catalog = (ROOT / "tests/TestSuiteCatalog.gd").read_text(encoding="utf-8")
        self.assertIn('"test_author_strategy_package_rules_e2e.gd": true', catalog)

    def test_governance_records_the_development_subgate_without_live_promotion(self) -> None:
        decisions = (ROOT / "docs/ptcgdap/07-decisions-risks-and-open-questions.md").read_text(encoding="utf-8")
        design = (ROOT / "docs/ptcgdap/08-author-strategy-package-mode.md").read_text(encoding="utf-8")
        handoff = (ROOT / "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md").read_text(encoding="utf-8")
        status = (ROOT / "docs/ptcgdap/STATUS.md").read_text(encoding="utf-8")
        checklist = (ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md").read_text(encoding="utf-8")
        self.assertIn("D043 — Windows 开发执行先以 exact 内置 archive SHA 放行", decisions)
        for document in (design, handoff, status):
            self.assertIn("D043", document)
            self.assertIn("918/918", document)
        self.assertIn("P6-22 / exact-SHA Windows development execution subgate", checklist)
        self.assertIn("不勾选 P6-14/P6-17", checklist)


if __name__ == "__main__":
    unittest.main()
