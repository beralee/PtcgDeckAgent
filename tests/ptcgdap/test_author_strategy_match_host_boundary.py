from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
LOADER = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd"
CATALOG = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
HANDLE = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd"
DECK_GATE = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd"
PROMPT = ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd"
HOST = ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd"
FACTORY = ROOT / "scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
BATTLE_SCENE_PATHS = [
    ROOT / "scenes/battle/BattleScene.gd",
    ROOT / "scenes/battle/BattleSceneRuntime.gd",
    *sorted((ROOT / "scenes/battle/runtime").glob("*.gd")),
]


class AuthorStrategyMatchHostBoundaryTests(unittest.TestCase):
    def test_work_package_is_shadow_only_and_scoped_to_as_wp4(self) -> None:
        work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
        self.assertEqual("AS-WP4: match-time package handle, exact deck gate and shadow Host", work["work_package"])
        self.assertEqual("complete", work["status"])
        self.assertEqual("match_time_shadow_handle_host_complete", work["implementation_state"])
        self.assertIn("no BattleScene consumer", work["shadow_or_live"])
        self.assertEqual("AS-WP5", work["next_permitted_work"]["work_package"])
        self.assertEqual("allowed", work["next_permitted_work"]["status"])

    def test_declared_runtime_owners_exist_and_have_closed_responsibilities(self) -> None:
        for path in (HANDLE, DECK_GATE, PROMPT, HOST, FACTORY):
            self.assertTrue(path.is_file(), path)
        loader = LOADER.read_text(encoding="utf-8")
        catalog = CATALOG.read_text(encoding="utf-8")
        handle = HANDLE.read_text(encoding="utf-8")
        gate = DECK_GATE.read_text(encoding="utf-8")
        prompt = PROMPT.read_text(encoding="utf-8")
        host = HOST.read_text(encoding="utf-8")
        factory = FACTORY.read_text(encoding="utf-8")
        self.assertIn("func inspect_match_bytes(", loader)
        self.assertIn("func request_match_handle(", catalog)
        self.assertIn("func validate_integrity(", handle)
        self.assertIn("func local_deck_snapshot(", handle)
        self.assertIn("CardIdCatalog.gd", gate)
        self.assertIn("lookup_local_printing_for_official_card", gate)
        self.assertIn("CardDatabase", gate)
        self.assertIn("StrategicContextV18.gd", prompt)
        self.assertIn("CabtSelectionWindow.gd", prompt)
        self.assertIn("func open_current_prompt(", host)
        self.assertIn("func request_current_selection(", host)
        self.assertIn("PublicBasePolicy.gd", host)
        self.assertIn("BattleAiOpponentFactory.gd", factory)
        self.assertIn("VS_AUTHOR_STRATEGY_AI", factory)

    def test_author_runtime_has_no_private_engine_or_external_runtime_capability(self) -> None:
        combined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (HANDLE, DECK_GATE, PROMPT, HOST)
        )
        for forbidden in (
            "AIOpponent",
            "DeckStrategyRegistry",
            "GameState",
            "GameStateMachine",
            "BattleScene",
            "CardInstance",
            "PokemonSlot",
            "ActionTicket",
            "HTTPClient",
            "HTTPRequest",
            "OS.execute",
            "TCPServer",
            "PacketPeerUDP",
            "load_resource_pack",
        ):
            self.assertNotIn(forbidden, combined)
        factory = FACTORY.read_text(encoding="utf-8")
        self.assertNotIn("extends AIOpponent", factory)
        self.assertNotIn("DeckStrategyRegistry", factory)

    def test_battle_scene_does_not_consume_legacy_author_host_or_shadow_indexes(self) -> None:
        combined = "\n".join(path.read_text(encoding="utf-8") for path in BATTLE_SCENE_PATHS)
        for forbidden in (
            "PtcgDAPAuthorMatchHost",
            "request_current_selection",
            "author_strategy_shadow",
        ):
            self.assertNotIn(forbidden, combined)
        # D044 may route the separately gated Windows development owner through
        # the mode-level factory.  It must not revive the AS-WP4 shadow host as
        # an execution consumer.
        self.assertIn("BattleDecisionOwnerFactoryScript", combined)
        factory = FACTORY.read_text(encoding="utf-8")
        self.assertIn("build_windows_development_author_owner", factory)
        self.assertNotIn("request_current_selection", factory)

    def test_classic_factory_is_not_modified_by_as_wp4(self) -> None:
        work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
        allowed = work["files_allowed"]
        classic = "scripts/ui/battle/ai/BattleAiOpponentFactory.gd"
        self.assertNotIn(classic, allowed["existing_project_files"])
        self.assertNotIn(classic, allowed["as_wp4_additive"])


if __name__ == "__main__":
    unittest.main()
