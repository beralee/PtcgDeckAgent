from __future__ import annotations

import ast
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PTCGDAP_RUNTIME = ROOT / "scripts" / "ai" / "ptcgdap"


class P1Wp2BoundaryTests(unittest.TestCase):
    def test_wp2_python_runtime_has_no_engine_ui_network_process_or_legacy_dependency(self) -> None:
        runtime_files = (
            PTCGDAP_RUNTIME / "cabt_tree_hash.py",
            PTCGDAP_RUNTIME / "wire_shapes.py",
            PTCGDAP_RUNTIME / "cabt_envelope.py",
            PTCGDAP_RUNTIME / "ptcgdap_session.py",
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

    def test_safe_envelope_metadata_schema_cannot_carry_private_values_or_hashes(self) -> None:
        from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope

        raw = {
            "select": None,
            "logs": [],
            "current": None,
            "search_begin_input": "never-persist-this-token",
            "unknownPrivatePayload": {"sentinel": "never-persist-this-value"},
            "step": 0,
        }
        result = parse_raw_cabt_envelope(
            raw, contract_root=ROOT / "contracts" / "ptcgdap"
        )
        safe = result.envelope.safe_metadata()
        safe_json = json.dumps(safe, sort_keys=True)
        self.assertEqual(
            set(safe),
            {
                "envelope_version",
                "source_lock_id",
                "hash_profile",
                "source_contract_hash",
                "field_presence",
                "enum_values",
                "parse_issues",
                "opaque_search_capability_present",
                "firewall_status",
                "public_observation_hash",
            },
        )
        self.assertNotIn("never-persist-this-token", safe_json)
        self.assertNotIn("never-persist-this-value", safe_json)
        self.assertNotIn("raw_private_hash", safe_json)
        self.assertNotIn("token_free_callback_hash", safe_json)


if __name__ == "__main__":
    unittest.main()
