from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/as_wp6_windows_player_owner"
REPORT_PATH = EVIDENCE_ROOT / "player_owner_10_games.json"
MANIFEST_PATH = EVIDENCE_ROOT / "manifest.json"
PACKAGE_PATH = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
PACKAGE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
POST_D044_AUDITED_SOURCE_UPDATES = {
    "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd":
        "24A5570491CB0B2DB2B737533652B9713DC508567C3122168015D9D8C8DB84CF",
}


def load_json_strict(path: Path) -> dict:
    def reject_duplicates(pairs: list[tuple[str, object]]) -> dict:
        result: dict = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate key {key!r} in {path}")
            result[key] = value
        return result

    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicates)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class AuthorStrategyWindowsPlayerOwnerEvidenceTests(unittest.TestCase):
    def test_manifest_rehashes_every_declared_file(self) -> None:
        manifest = load_json_strict(MANIFEST_PATH)
        self.assertEqual(manifest["schema_version"], 1)
        self.assertEqual(manifest["milestone"], "D044/P6-23")
        self.assertEqual(manifest["package_archive_sha256"], PACKAGE_SHA256)
        self.assertEqual(sha256(PACKAGE_PATH), PACKAGE_SHA256)
        paths = {entry["path"] for entry in manifest["files"]}
        self.assertIn("artifacts/ptcgdap/as_wp6_windows_player_owner/player_owner_10_games.json", paths)
        self.assertIn("scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd", paths)
        self.assertIn("docs/ptcgdap/STATUS.md", paths)
        for entry in manifest["files"]:
            target = ROOT / entry["path"]
            self.assertTrue(target.is_file(), entry["path"])
            self.assertEqual(target.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha256(target), entry["sha256"], entry["path"])

    def test_real_rules_report_is_clean_and_post_run_updates_are_audited(self) -> None:
        report = load_json_strict(REPORT_PATH)
        self.assertEqual(report["evidence_kind"], "windows_development_player_owner_real_rules_e2e")
        self.assertEqual(report["games"], 10)
        self.assertEqual(report["seed_base"], 84400)
        self.assertEqual(report["owner_seat"], 1)
        self.assertTrue(report["is_clean"])
        self.assertFalse(report["source_changed_during_run"])
        self.assertEqual(report["source_at_start"], report["source_at_end"])
        self.assertEqual(
            report["totals"],
            {
                "classic_fallbacks": 0,
                "engine_commits": 586,
                "engine_rejections": 0,
                "invalid_outputs": 0,
                "policy_calls": 593,
                "policy_errors": 0,
                "policy_successes": 593,
                "same_window_fallbacks": 0,
            },
        )
        for entry in report["source_at_start"]["files"]:
            current_sha = sha256(ROOT / entry["path"])
            if current_sha != entry["raw_sha256"]:
                self.assertEqual(
                    POST_D044_AUDITED_SOURCE_UPDATES.get(entry["path"]),
                    current_sha,
                    entry["path"],
                )
        self.assertEqual(len(report["per_game"]), 10)
        self.assertTrue(all(game["terminal"] for game in report["per_game"]))
        self.assertEqual(sum(game["winner_index"] == 1 for game in report["per_game"]), 1)
        for game in report["per_game"]:
            audit = game["audit"]
            self.assertEqual(audit["policy_calls"], audit["policy_successes"])
            self.assertEqual(audit["policy_errors"], 0)
            self.assertEqual(audit["invalid_outputs"], 0)
            self.assertEqual(audit["same_window_fallbacks"], 0)
            self.assertEqual(audit["classic_fallbacks"], 0)
            self.assertEqual(audit["engine_rejections"], 0)
            self.assertFalse(audit["legacy_deck_strategy_preferences"])
            self.assertTrue(audit["development_player_authority"])
            self.assertFalse(audit["production_ready"])
            self.assertFalse(audit["android_ready"])
            self.assertEqual(audit["policy_package_id"], "ptcgdap.marnie.windows-local.policy")
            self.assertEqual(audit["learned_model"], "none")
            self.assertEqual(audit["model_backend"], "none")
            self.assertFalse(audit["learned_model_invoked"])
            self.assertEqual(audit["execution_location"], "device_local")
            self.assertEqual(len(audit["policy_package_manifest_canonical_sha256"]), 64)

    def test_governance_records_only_development_authority(self) -> None:
        decisions = (ROOT / "docs/ptcgdap/07-decisions-risks-and-open-questions.md").read_text(encoding="utf-8")
        status = (ROOT / "docs/ptcgdap/STATUS.md").read_text(encoding="utf-8")
        checklist = (ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md").read_text(encoding="utf-8")
        gaps = (EVIDENCE_ROOT / "known_gaps.md").read_text(encoding="utf-8")
        self.assertIn("D044 — exact Marnie 候选可进入 Windows 开发态玩家路径", decisions)
        self.assertIn("P6-23 / exact-candidate Windows development player-owner subgate", checklist)
        for document in (decisions, status, checklist):
            self.assertIn("593/593", document)
            self.assertIn("1492/1492", document)
            self.assertIn("872/872", document)
            self.assertIn("Android", document)
        self.assertIn("Android", gaps)
        self.assertIn("production-signed package", gaps)
        results = load_json_strict(EVIDENCE_ROOT / "test_results.json")["results"]
        python_full = next(result for result in results if result["lane"] == "ptcgdap_python_full")
        self.assertEqual((python_full["passed"], python_full["failed"], python_full["status"]), (872, 0, "passed"))
        functional_full = next(result for result in results if result["lane"] == "functional_full")
        self.assertIn("timed_out", functional_full["status"])
        manifest = load_json_strict(MANIFEST_PATH)
        self.assertTrue(manifest["claims"]["windows_development_player_authority"])
        self.assertFalse(manifest["claims"]["production_ready"])
        self.assertFalse(manifest["claims"]["exported_exe_airplane_match"])
        self.assertFalse(manifest["claims"]["android_ready"])
        self.assertFalse(manifest["claims"]["cabt_exportable"])
        self.assertFalse(manifest["claims"]["official_engine_parity"])


if __name__ == "__main__":
    unittest.main()
