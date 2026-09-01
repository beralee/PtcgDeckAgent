from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class CompetitiveStrategyEvaluatorBoundaryTests(unittest.TestCase):
    def test_wp2_is_additive_shadow_and_not_wired_into_gameplay_or_ui(self) -> None:
        runtime_paths = (
            ROOT / "scripts/ai/ptcgdap/competitive_strategy_evaluator.py",
            ROOT / "scripts/ai/ptcgdap/platform/evaluation/CompetitiveStrategyEvaluator.gd",
        )
        for path in runtime_paths:
            source = path.read_text(encoding="utf-8")
            for forbidden in (
                "BattleScene",
                "GameStateMachine",
                "ActionTicket",
                "AIOpponent",
                "HTTPClient",
                "HTTPRequest",
                "socket",
            ):
                self.assertNotIn(forbidden, source, (path, forbidden))
            self.assertNotIn(
                "9D61B19DEFFD5A60BA844AF492EC2CC44449C5697B326919703BAC031CAE7F60",
                source,
                path,
            )

        for path in (
            ROOT / "scenes/main_menu/MainMenu.gd",
            ROOT / "scenes/battle/BattleSceneRuntime.gd",
            ROOT / "scripts/ai/HeadlessMatchBridge.gd",
        ):
            self.assertNotIn("CompetitiveStrategyEvaluator", path.read_text(encoding="utf-8"), path)

    def test_profile_cannot_claim_production_or_accept_self_reported_sources(self) -> None:
        profile = json.loads(
            (ROOT / "contracts/ptcgdap/competitive_strategy_evaluator_profile.json").read_text(encoding="utf-8")
        )
        self.assertEqual(profile["authority_mode"], "shadow_test_only")
        self.assertFalse(profile["production_authority"])
        self.assertEqual(profile["grants"], [])
        self.assertFalse(profile["runtime_report_contract"]["historical_import_allowed"])
        self.assertFalse(profile["runtime_report_contract"]["client_self_report_allowed"])
        self.assertEqual(profile["runtime_report_contract"]["source"], "official_evaluator_runtime")

    def test_wp0_contract_bundle_remains_frozen(self) -> None:
        bundle = json.loads(
            (ROOT / "contracts/ptcgdap/competitive_strategy_platform_bundle.json").read_text(encoding="utf-8")
        )
        self.assertEqual(bundle["bundle_id"], "ptcgdap-competitive-strategy-platform-csp-wp0-v1")
        self.assertEqual(len(bundle["artifacts"]), 4)


if __name__ == "__main__":
    unittest.main()
