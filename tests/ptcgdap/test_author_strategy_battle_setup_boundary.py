from __future__ import annotations

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp3/work_package.json"
MODEL = ROOT / "scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd"
GAME_MANAGER = ROOT / "scripts/autoload/GameManager.gd"
BATTLE_SETUP = ROOT / "scenes/battle_setup/BattleSetup.gd"
SCENE = ROOT / "scenes/battle_setup/BattleSetup.tscn"
GODOT_TEST = ROOT / "tests/ptcgdap/godot/test_author_strategy_battle_setup.gd"
CLASSIC_REGRESSION = ROOT / "tests/test_battle_setup_ai_versions.gd"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def without_comments(value: str) -> str:
    return re.sub(r"(?m)#.*$", "", value)


class AuthorStrategyBattleSetupBoundaryTests(unittest.TestCase):
    def test_work_package_declares_only_setup_metadata_scope(self) -> None:
        work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
        self.assertEqual("AS-WP3: BattleSetup author-strategy mode and metadata UI", work["work_package"])
        allowed = work["files_allowed"]
        self.assertIn("scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd", allowed["as_wp3_additive"])
        self.assertIn("tests/test_battle_setup_ai_versions.gd", allowed["existing_compatibility_files"])
        combined = "\n".join(sum((value for value in allowed.values() if isinstance(value, list)), []))
        for forbidden in ("BattleScene", "BattleAiOpponentFactory", "DeckStrategyRegistry", "AIOpponent"):
            self.assertNotIn(forbidden, combined)

    def test_game_manager_has_independent_copy_only_selection(self) -> None:
        source = without_comments(text(GAME_MANAGER))
        self.assertIn("VS_AUTHOR_STRATEGY_AI", source)
        self.assertIn("func set_author_strategy_selection(", source)
        self.assertIn("func get_author_strategy_selection(", source)
        self.assertIn("func reset_author_strategy_selection(", source)
        self.assertIn("current_mode == GameMode.VS_AUTHOR_STRATEGY_AI", source)
        self.assertRegex(source, r"(?s)current_mode == GameMode\.VS_AUTHOR_STRATEGY_AI.*?player_index == 1.*?return null")

    def test_scene_declares_third_mode_and_metadata_controls(self) -> None:
        source = text(SCENE)
        for node in (
            "ModeAuthorStrategyButton",
            "AuthorStrategyPanel",
            "AuthorStrategyPackageOption",
            "AuthorStrategyStatusLabel",
            "AuthorStrategyDetailsLabel",
        ):
            self.assertIn(f'[node name="{node}"', source)

    def test_battle_setup_unifies_picker_but_preserves_independent_execution_gate(self) -> None:
        source = without_comments(text(BATTLE_SETUP))
        self.assertIn("AuthorStrategySetupModel.gd", source)
        self.assertIn('add_item("作者策略包", 2)', source)
        self.assertIn("func _is_author_strategy_mode()", source)
        self.assertIn("func _apply_author_strategy_catalog_report(", source)
        self.assertIn("func _author_strategy_start_allowed()", source)
        self.assertIn("AuthorStrategyPackageCatalog", source)
        self.assertIn("func _on_deck_picker_author_strategy_selected(", source)
        self.assertRegex(
            source,
            r"(?s)func _refresh_deck_options\(.*?_is_any_ai_controlled_mode\(\).*?_ai_deck_list = CardDatabase\.get_all_ai_decks",
        )
        self.assertRegex(
            source,
            r"(?s)func _apply_setup_selection\(.*?VS_AUTHOR_STRATEGY_AI.*?AuthorStrategyWindowsExecutionGateScript\.evaluate_selection",
        )

    def test_setup_model_is_copy_only_and_has_no_runtime_owner_dependencies(self) -> None:
        source = without_comments(text(MODEL))
        self.assertIn("func normalize_catalog_report(", source)
        self.assertIn("func stable_ref(", source)
        self.assertIn("func same_ref(", source)
        for forbidden in (
            "BattleScene",
            "GameState",
            "AIOpponent",
            "DeckStrategyRegistry",
            "policy_ir",
            "archive_bytes",
            "weights/",
            "goto_battle",
        ):
            self.assertNotIn(forbidden, source)

    def test_unified_ai_picker_and_classic_regression_are_registered(self) -> None:
        self.assertTrue(GODOT_TEST.is_file())
        self.assertIn("func test_", text(GODOT_TEST))
        regression = text(CLASSIC_REGRESSION)
        self.assertIn('find_child("ModeAuthorStrategyButton"', regression)
        self.assertIn("Author packages should be selected inside the AI opponent picker", regression)
        self.assertIn("The hidden legacy button must not change mode", regression)


if __name__ == "__main__":
    unittest.main()
