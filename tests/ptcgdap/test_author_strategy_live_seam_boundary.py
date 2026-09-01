from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SEAM = ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd"
SOURCE = ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd"
COMMAND = ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyLiveCommand.gd"
PROFILE = ROOT / "contracts/ptcgdap/author_strategy_live_seam_profile.json"
RUNTIME = ROOT / "scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd"


class AuthorStrategyLiveSeamBoundaryTests(unittest.TestCase):
    def test_contract_and_owner_modules_exist(self) -> None:
        for path in (SEAM, SOURCE, COMMAND, PROFILE):
            self.assertTrue(path.is_file(), path.as_posix())

    def test_profile_starts_only_with_reversible_w1_canary(self) -> None:
        profile = json.loads(PROFILE.read_text(encoding="utf-8"))
        self.assertEqual(profile["enabled_prompt_families"], ["W1"])
        self.assertEqual(profile["enabled_callback_roles"], ["setup_active"])
        self.assertFalse(profile["trust_scope"]["player_package_execution"])
        self.assertTrue(profile["lifecycle"]["immediate_reobserve_required"])
        self.assertTrue(profile["lifecycle"]["one_use_ticket_required"])

    def test_seam_uses_current_window_chain_without_classic_ai_or_network(self) -> None:
        source = SEAM.read_text(encoding="utf-8")
        for required in (
            "EngineDecisionPort.gd",
            "GodotOptionBinding.gd",
            "ShadowPromptBroker.gd",
            "CabtSelectionSanitizer.gd",
            "GodotObservationProjector.gd",
            "open_current_prompt",
            "request_current_selection",
            "awaiting_reobserve",
        ):
            self.assertIn(required, source)
        for forbidden in (
            "AIOpponent",
            "BattleAiOpponentFactory",
            "HTTPRequest",
            "HTTPClient",
            "OS.execute",
            "Python",
        ):
            self.assertNotIn(forbidden, source)

    def test_private_command_is_setup_active_only_and_nonserializable(self) -> None:
        source = COMMAND.read_text(encoding="utf-8")
        self.assertIn("setup_place_active_pokemon", source)
        self.assertIn("validate_current", source)
        self.assertIn("execute_once", source)
        self.assertNotIn("Callable", source)
        self.assertNotIn("to_public_dict", source)

    def test_battle_runtime_cannot_promote_fixture_or_fall_back_classic(self) -> None:
        source = RUNTIME.read_text(encoding="utf-8")
        self.assertIn("_maybe_run_author_setup_active_canary", source)
        self.assertIn("VS_AUTHOR_STRATEGY_AI", source)
        self.assertNotIn("author_strategy_fixture_trusted", source)


if __name__ == "__main__":
    unittest.main()
