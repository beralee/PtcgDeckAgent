from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_local_policy_executor"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
NORMALIZED_REPORT = EVIDENCE / "windows_ui_match_report.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_local_policy_executor_evidence.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6LocalPolicyExecutorEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"], cwd=ROOT,
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_closes_only_p6_03_windows_no_model_subgate(self) -> None:
        summary = load_json_strict(SUMMARY)
        report = load_json_strict(NORMALIZED_REPORT)
        self.assertEqual("D053", summary["decision_id"])
        self.assertEqual("windows_no_model_local_policy_executor_complete", summary["status"])
        self.assertTrue(summary["claims"]["p6_03_windows_no_model"])
        for open_claim in (
            "production_ready", "os_network_isolation", "device_profile_approved",
            "a2_claimed", "a5_claimed", "model_backed", "official_cabt_parity", "android_claimed",
        ):
            self.assertFalse(summary["claims"][open_claim], open_claim)
        self.assertTrue(report["accepted"])
        self.assertGreater(report["policy_calls"], 0)
        self.assertEqual(report["policy_calls"], report["policy_successes"])
        self.assertGreater(report["engine_commits"], 0)
        self.assertLessEqual(report["engine_commits"], report["policy_calls"])
        self.assertEqual(0, report["failure_counters_total"])
        self.assertEqual("ptcgdap-local-policy-executor-v1", report["executor_id"])
        self.assertEqual(931, summary["validation"]["python_full_passed"])
        self.assertEqual(1496, summary["validation"]["godot_ai_full_passed"])
        self.assertEqual(4976, summary["validation"]["godot_functional_ui_full_passed"])
        self.assertTrue(summary["rollback"]["immutable_parent_preserved"])
        self.assertEqual(10, summary["rollback"]["real_rules_terminal_games"])
        self.assertEqual(593, summary["rollback"]["real_rules_policy_successes"])
        self.assertEqual(586, summary["rollback"]["real_rules_engine_commits"])
        self.assertEqual(0, summary["rollback"]["real_rules_failure_counters_total"])

    def test_manifest_binds_every_evidence_input(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertIn("data/ptcgdap/marnie_windows_local_policy_executor_v1.json", paths)
        self.assertIn("scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd", paths)
        self.assertIn("scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd", paths)
        self.assertIn("scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd", paths)
        self.assertIn("artifacts/ptcgdap/as_wp6_windows_player_owner/player_owner_10_games.json", paths)
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
