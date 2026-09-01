from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.author_strategy_match_host import AuthorStrategyMatchHandleBuilder
from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from tools.ptcgdap.build_author_strategy_release_candidate import build_candidate_bytes


ROOT = Path(__file__).resolve().parents[2]
PYTHON_MATCH_HOST = ROOT / "scripts/ai/ptcgdap/author_strategy_match_host.py"
GODOT_DECK_GATE = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd"
GODOT_DECK_MATERIALIZER = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd"
GAME_MANAGER = ROOT / "scripts/autoload/GameManager.gd"
BATTLE_START = ROOT / "scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd"
BATTLE_SETUP = ROOT / "scenes/battle_setup/BattleSetup.gd"
GAME_STATE_MACHINE = ROOT / "scripts/engine/GameStateMachine.gd"
AUTHOR_OWNER = ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"


class AuthorStrategyPackageDeckAuthorityTests(unittest.TestCase):
    @staticmethod
    def _gdscript_function(source: str, name: str) -> str:
        marker = f"func {name}("
        start = source.index(marker)
        next_function = source.find("\nfunc ", start + len(marker))
        return source[start:] if next_function < 0 else source[start:next_function]

    def test_windows_local_package_materializes_without_any_numbered_deck_file(self) -> None:
        package = AuthorStrategyPackageLoader().load_bytes(build_candidate_bytes())
        manifest = json.loads(package.payload_bytes("deck/deck_manifest.json"))

        with tempfile.TemporaryDirectory() as temporary:
            isolated_root = Path(temporary)
            cards_root = isolated_root / "data/bundled_user/cards"
            cards_root.mkdir(parents=True)
            for entry in manifest["cards"]:
                uid = entry["local_card_uid"]
                shutil.copyfile(
                    ROOT / "data/bundled_user/cards" / f"{uid}.json",
                    cards_root / f"{uid}.json",
                )

            self.assertFalse((isolated_root / "data/bundled_user/decks").exists())
            handle = AuthorStrategyMatchHandleBuilder.build(package, root=isolated_root)
            self.assertEqual(60, handle.to_public_dict()["local_deck_card_count"])
            self.assertEqual(
                [(row["local_card_uid"], row["count"]) for row in manifest["cards"]],
                [(row["local_card_uid"], row["count"]) for row in handle.local_deck_snapshot()],
            )

    def test_godot_runtime_uses_package_csv_not_source_deck_id(self) -> None:
        self.assertTrue(GODOT_DECK_MATERIALIZER.is_file())
        gate = GODOT_DECK_GATE.read_text(encoding="utf-8")
        materializer = GODOT_DECK_MATERIALIZER.read_text(encoding="utf-8")
        manager = GAME_MANAGER.read_text(encoding="utf-8")
        battle_setup = BATTLE_SETUP.read_text(encoding="utf-8")
        owner = AUTHOR_OWNER.read_text(encoding="utf-8")
        python_host = PYTHON_MATCH_HOST.read_text(encoding="utf-8")

        for source in (gate, python_host):
            self.assertNotIn("data/bundled_user/decks", source)
        self.assertNotIn("source_deck_id", materializer)
        self.assertNotIn('CardDatabase.get_deck(int(admitted.get("source_deck_id"', manager)
        self.assertNotIn('CardDatabase.get_deck(int(admitted.get("source_deck_id"', battle_setup)
        self.assertIn("materialize_author_strategy_battle_deck", battle_setup)
        self.assertIn("AuthorStrategyDeckMaterializer.gd", manager)
        self.assertNotIn('"deck_id": str(_pins.get("source_deck_id"', owner)
        self.assertIn('"deck_id": "%s@%s"', owner)

    def test_author_owner_is_bound_before_setup_can_publish_a_prompt(self) -> None:
        battle_start = BATTLE_START.read_text(encoding="utf-8")
        game_state_machine = GAME_STATE_MACHINE.read_text(encoding="utf-8")

        self.assertIn("defer_setup_until_owner_bound", game_state_machine)
        self.assertIn("func begin_deferred_setup()", game_state_machine)
        self.assertIn("begin_deferred_setup", battle_start)
        self.assertLess(
            battle_start.index("build_windows_author_owner"),
            battle_start.index("begin_deferred_setup"),
        )

    def test_ai_deck_picker_hot_path_never_revalidates_or_materializes_archives(self) -> None:
        battle_setup = BATTLE_SETUP.read_text(encoding="utf-8")

        for function_name in (
            "_author_strategy_record_can_start",
            "_author_strategy_display_status_label",
            "_author_strategy_display_status_detail",
            "_selected_deck_for_slot",
            "_refresh_deck_picker",
            "_sync_deck_picker_button",
        ):
            body = self._gdscript_function(battle_setup, function_name)
            self.assertNotIn(
                "_materialize_author_strategy_deck",
                body,
                f"{function_name} is a setup/picker hot path and must remain metadata-only",
            )
            self.assertNotIn(
                "request_match_handle",
                body,
                f"{function_name} must not synchronously recapture a package archive",
            )

        admission = self._gdscript_function(
            battle_setup, "_author_strategy_record_can_start"
        )
        self.assertIn("evaluate_selection", admission)

        explicit_start = self._gdscript_function(battle_setup, "_apply_setup_selection")
        self.assertIn("_materialize_author_strategy_deck", explicit_start)


if __name__ == "__main__":
    unittest.main()
