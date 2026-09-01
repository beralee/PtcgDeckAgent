from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "artifacts/ptcgdap/p3_wp4/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp4/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp3/manifest.json"
EXECUTOR_BUNDLE = ROOT / "contracts/ptcgdap/godot_action_executor_bundle.json"
TICKET_BUNDLE = ROOT / "contracts/ptcgdap/godot_action_ticket_bundle.json"
OWNER_PATHS = {
    "scripts/ai/ptcgdap/godot_action_executor.py",
    "scripts/engine/decision/GodotActionExecutor.gd",
}
APPROVED_SHADOW_BROKER_CONSUMERS = {
    "scripts/ai/ptcgdap/shadow_prompt_broker.py",
    "scripts/engine/decision/ShadowPromptBroker.gd",
}
ADDITIVE_PATHS = {
    "contracts/ptcgdap/godot_action_executor.schema.json",
    "contracts/ptcgdap/godot_action_executor_profile.json",
    "contracts/ptcgdap/godot_action_executor_conformance_vectors.json",
    "contracts/ptcgdap/godot_action_executor_bundle.json",
    "scripts/ai/ptcgdap/godot_action_executor.py",
    "scripts/engine/decision/GodotActionExecutor.gd",
    "tools/ptcgdap/build_godot_action_executor_contract.py",
    "tests/ptcgdap/test_godot_action_executor_contract_builder.py",
    "tests/ptcgdap/test_godot_action_executor.py",
    "tests/ptcgdap/test_godot_action_executor_properties.py",
    "tests/ptcgdap/test_p3_wp4_boundaries.py",
    "tests/ptcgdap/test_p3_wp4_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_action_executor.gd",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def all_keys(value):
    if type(value) is dict:
        output = set(value)
        for child in value.values():
            output.update(all_keys(child))
        return output
    if type(value) is list:
        output = set()
        for child in value:
            output.update(all_keys(child))
        return output
    return set()


class P3Wp4BoundaryTests(unittest.TestCase):
    def test_governance_parent_alignment_and_cursor_are_exact(self) -> None:
        package = load_json_strict(PACKAGE)
        self.assertEqual(package["work_package"], "P3-WP4")
        final = FINAL_MANIFEST.is_file()
        completed = package["implementation_state"] == "completed"
        self.assertEqual(package["status"], "shadow" if final or completed else "planned")
        self.assertIn(package["implementation_state"], {"not_started", "completed"})
        self.assertEqual(
            package["shadow_or_live"],
            "shadow_host_private_executor_preflight_and_non_live_atomic_commit_only_no_engine_invocation_or_live_consumer",
        )
        self.assertEqual(package["entry_evidence"]["parent_manifest_raw_sha256"], sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(
            package["entry_evidence"]["parent_manifest_canonical_sha256"],
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))),
        )
        self.assertEqual(package["alignment_claim"]["A0"], "partial / not claimed")
        self.assertTrue(all(package["alignment_claim"][key] == "not evaluated" for key in ["A1", "A2", "A3", "A4", "A5"]))
        self.assertEqual(package["next_permitted_work"]["work_package"], "P3-WP5")
        declared = set(package["files_allowed"]["contracts"] + package["files_allowed"]["implementation"] + package["files_allowed"]["tests"])
        self.assertTrue(ADDITIVE_PATHS.issubset(declared))

    def test_parent_ticket_and_executor_contracts_are_exact_and_noncyclic(self) -> None:
        self.assertEqual(sha(PARENT_MANIFEST.read_bytes()), "9564EE72D2BD400D010123E8563F50CCF0233BDC6436A3C35FDCDD9F78710556")
        self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))), "5ACC39769D3A63EA7B27CAA61B107FCCF284DC52FCFB93F9B77B1547883FAF2B")
        self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(TICKET_BUNDLE))), "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED")
        bundle = load_json_strict(EXECUTOR_BUNDLE)
        self.assertEqual(sha(canonical_json_v1_bytes(bundle)), "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92")
        self.assertEqual(bundle["contract_id"], "ptcgdap-godot-action-executor-p3-wp4-v1")
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        self.assertFalse(any(entry["path"].endswith("godot_action_executor_bundle.json") for entry in bundle["artifacts"]))

    def test_owner_dependencies_are_private_pure_and_engine_invocation_free(self) -> None:
        forbidden = [
            "GameStateMachine", "BattleScene", "HeadlessMatchBridge", "AIOpponent", "DeckStrategy",
            "_pending_choice", "_dialog_data", "CardDatabase", "CardIdCatalog", "subprocess", "socket",
            "requests", "http://", "https://", "ptcgabc", "Engine.call", "engine_method",
            "private_engine_command()", ".execute(", ".invoke(", "emit_signal(", "Input.", "DisplayServer",
        ]
        for relative in OWNER_PATHS:
            text = (ROOT / relative).read_text(encoding="utf-8")
            for token in forbidden:
                self.assertNotIn(token, text, f"{relative}: {token}")
        tree = ast.parse((ROOT / "scripts/ai/ptcgdap/godot_action_executor.py").read_text(encoding="utf-8"))
        imports = {node.names[0].name for node in ast.walk(tree) if isinstance(node, ast.Import)}
        self.assertTrue(imports.isdisjoint({"os", "subprocess", "socket", "requests", "random"}))

    def test_no_live_consumer_or_autoload_exists(self) -> None:
        needles = ["GodotActionExecutor", "scripts/engine/decision/GodotActionExecutor.gd"]
        hits = []
        for scan_root in (ROOT / "scripts", ROOT / "scenes"):
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.suffix not in {".gd", ".py", ".tscn", ".tres"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in OWNER_PATHS or relative in APPROVED_SHADOW_BROKER_CONSUMERS:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                if any(needle in text for needle in needles):
                    hits.append(relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(hits, [])

    def test_serialization_contract_and_vectors_never_echo_private_authority(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/godot_action_executor_profile.json")
        serialization = profile["serialization_contract"]
        self.assertTrue(serialization["dto_only"])
        self.assertFalse(serialization["grants_execution_authority"])
        private = {
            "session_id", "callback_binding_hash", "current_source", "private_engine_command",
            "private_object_refs", "binding_resolutions", "command_refs", "private_refs",
        }
        self.assertTrue(private.issubset(set(serialization["forbidden_fields"])))
        vectors = load_json_strict(ROOT / "contracts/ptcgdap/godot_action_executor_conformance_vectors.json")
        expected = [case["expected"] for section in ("preflight_cases", "commit_cases") for case in vectors[section]]
        self.assertTrue(private.isdisjoint(all_keys(expected)))

    def test_final_docs_keep_executor_non_live_and_p3_wp5_cursor(self) -> None:
        if not FINAL_MANIFEST.is_file():
            self.skipTest("final evidence not yet generated")
        readme = (ROOT / "docs/ptcgdap/README.md").read_text(encoding="utf-8")
        status = (ROOT / "docs/ptcgdap/STATUS.md").read_text(encoding="utf-8")
        checklist = (ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md").read_text(encoding="utf-8")
        for text in (readme, status):
            self.assertIn("P3-WP4", text)
            self.assertIn("P3-WP5", text)
            self.assertIn("A0", text)
        self.assertIn("P3-04", checklist)


if __name__ == "__main__":
    unittest.main()
