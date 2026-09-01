from __future__ import annotations

import ast
import re
import unittest
from pathlib import Path

from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
PTCGDAP_RUNTIME = ROOT / "scripts" / "ai" / "ptcgdap"


class P1Wp3BoundaryTests(unittest.TestCase):
    def test_wp3_python_core_has_no_engine_ui_network_process_or_legacy_dependency(self) -> None:
        runtime_files = (
            PTCGDAP_RUNTIME / "contract_set.py",
            PTCGDAP_RUNTIME / "cabt_selection.py",
        )
        forbidden_import_roots = {
            "asyncio",
            "ctypes",
            "http",
            "requests",
            "socket",
            "subprocess",
            "urllib",
        }
        forbidden_text = {
            "AIOpponent",
            "BattleScene",
            "CardInstance",
            "GameState",
            "GameStateMachine",
            "PokemonSlot",
            "D:\\ai\\code\\ptcgabc",
        }

        for path in runtime_files:
            with self.subTest(path=path.name):
                source = path.read_text(encoding="utf-8")
                tree = ast.parse(source, filename=str(path))
                imports: set[str] = set()
                for node in ast.walk(tree):
                    if isinstance(node, ast.Import):
                        imports.update(alias.name.split(".", 1)[0] for alias in node.names)
                    elif isinstance(node, ast.ImportFrom) and node.module:
                        imports.add(node.module.split(".", 1)[0])
                self.assertTrue(imports.isdisjoint(forbidden_import_roots), imports)
                for marker in forbidden_text:
                    self.assertNotIn(marker, source)

    def test_wp3_godot_core_stays_inside_the_pure_ptcgdap_boundary(self) -> None:
        runtime_files = (
            PTCGDAP_RUNTIME / "cabt" / "CabtContractSet.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtOptionFingerprint.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtSelectionWindow.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtSelectionSanitizer.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtDeterministicFallback.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtDeckSelectionValidator.gd",
        )
        forbidden_text = {
            "AIOpponent",
            "BattleScene",
            "CardInstance",
            "GameState",
            "GameStateMachine",
            "PokemonSlot",
            "HTTPRequest",
            "HTTPClient",
            "PacketPeerUDP",
            "StreamPeerTCP",
            "WebSocketPeer",
            "OS.create_process",
            "OS.execute",
            "_dialog_data",
            "_pending_choice",
            "D:\\ai\\code\\ptcgabc",
        }
        resource_pattern = re.compile(r'(?:preload|load)\("(res://[^"]+)"\)')

        for path in runtime_files:
            with self.subTest(path=path.name):
                source = path.read_text(encoding="utf-8")
                for marker in forbidden_text:
                    self.assertNotIn(marker, source)
                for resource_path in resource_pattern.findall(source):
                    self.assertTrue(
                        resource_path.startswith("res://scripts/ai/ptcgdap/"),
                        f"{path.name} loads outside the pure PtcgDAP runtime: {resource_path}",
                    )

    def test_wp3_selection_dtos_have_no_live_consumer_before_p2(self) -> None:
        forbidden_markers = {
            "CabtSelectionResolution",
            "CabtSelectionSanitizer",
            "CabtDeterministicFallback",
            "CabtDeckSelectionValidator",
            "resolve_policy_attempt",
        }
        owner_files = {
            PTCGDAP_RUNTIME / "cabt_selection.py",
            PTCGDAP_RUNTIME / "cabt" / "CabtSelectionWindow.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtSelectionSanitizer.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtDeterministicFallback.gd",
            PTCGDAP_RUNTIME / "cabt" / "CabtDeckSelectionValidator.gd",
        }
        approved_shadow_consumers = {
            PTCGDAP_RUNTIME / "marnie_prompt_broker.py",
            PTCGDAP_RUNTIME / "public" / "MarniePromptBroker.gd",
            PTCGDAP_RUNTIME / "godot_action_ticket.py",
            ROOT / "scripts" / "engine" / "decision" / "GodotActionTicket.gd",
            PTCGDAP_RUNTIME / "shadow_prompt_broker.py",
            ROOT / "scripts" / "engine" / "decision" / "ShadowPromptBroker.gd",
            PTCGDAP_RUNTIME / "strategic_context_v18.py",
            PTCGDAP_RUNTIME / "public" / "StrategicContextV18.gd",
            PTCGDAP_RUNTIME / "public_base_policy.py",
            PTCGDAP_RUNTIME / "public" / "PublicBasePolicy.gd",
            PTCGDAP_RUNTIME / "public_policy_budget.py",
            PTCGDAP_RUNTIME / "public" / "PublicPolicyBudget.gd",
        }
        external_runtime_files = [
            path
            for path in (ROOT / "scripts").rglob("*")
            if path.is_file()
            and path.suffix in {".gd", ".py"}
            and path not in owner_files
            and path not in approved_shadow_consumers
            and path.relative_to(ROOT).as_posix() not in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS
        ]
        for path in external_runtime_files:
            source = path.read_text(encoding="utf-8", errors="strict")
            for marker in forbidden_markers:
                self.assertNotIn(
                    marker,
                    source,
                    f"{path.relative_to(ROOT)} consumes the offline-only WP3 core",
                )


if __name__ == "__main__":
    unittest.main()
