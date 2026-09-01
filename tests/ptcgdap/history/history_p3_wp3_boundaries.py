from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "artifacts/ptcgdap/p3_wp3/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp3/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp2/manifest.json"
TICKET_BUNDLE = ROOT / "contracts/ptcgdap/godot_action_ticket_bundle.json"
BINDING_BUNDLE = ROOT / "contracts/ptcgdap/godot_option_binding_bundle.json"
OWNER_PATHS = {
    "scripts/ai/ptcgdap/godot_action_ticket.py",
    "scripts/engine/decision/GodotActionTicket.gd",
}
APPROVED_SHADOW_EXECUTOR_CONSUMERS = {
    "scripts/ai/ptcgdap/godot_action_executor.py",
    "scripts/engine/decision/GodotActionExecutor.gd",
    "scripts/ai/ptcgdap/shadow_prompt_broker.py",
    "scripts/engine/decision/ShadowPromptBroker.gd",
    "scripts/ai/ptcgdap/shadow_engine_command_applier.py",
}
ADDITIVE_PATHS = {
    "contracts/ptcgdap/godot_action_ticket.schema.json",
    "contracts/ptcgdap/godot_action_ticket_profile.json",
    "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json",
    "contracts/ptcgdap/godot_action_ticket_bundle.json",
    "scripts/ai/ptcgdap/godot_action_ticket.py",
    "scripts/engine/decision/GodotActionTicket.gd",
    "tools/ptcgdap/build_godot_action_ticket_contract.py",
    "tests/ptcgdap/test_godot_action_ticket_contract_builder.py",
    "tests/ptcgdap/test_godot_action_ticket.py",
    "tests/ptcgdap/test_godot_action_ticket_properties.py",
    "tests/ptcgdap/test_p3_wp3_boundaries.py",
    "tests/ptcgdap/test_p3_wp3_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_action_ticket.gd",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def all_keys(value):
    if type(value) is dict:
        result = set(value)
        for item in value.values():
            result.update(all_keys(item))
        return result
    if type(value) is list:
        result = set()
        for item in value:
            result.update(all_keys(item))
        return result
    return set()


class P3Wp3BoundaryTests(unittest.TestCase):
    def test_governance_parent_alignment_and_cursor_are_exact(self) -> None:
        package = load_json_strict(PACKAGE)
        self.assertEqual(package["work_package"], "P3-WP3")
        final = FINAL_MANIFEST.is_file()
        self.assertEqual(package["status"], "shadow" if final else "planned")
        self.assertEqual(package["implementation_state"], "completed" if final else "not_started")
        self.assertEqual(
            package["shadow_or_live"],
            "shadow_host_private_one_use_action_ticket_only_no_engine_commit_execution_or_live_consumer",
        )
        self.assertEqual(package["entry_evidence"]["parent_manifest_raw_sha256"], sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(
            package["entry_evidence"]["parent_manifest_canonical_sha256"],
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))),
        )
        self.assertEqual(package["alignment_claim"]["A0"], "partial / not claimed")
        self.assertTrue(
            all(package["alignment_claim"][key] == "not evaluated" for key in ["A1", "A2", "A3", "A4", "A5"])
        )
        self.assertEqual(package["next_permitted_work"]["work_package"], "P3-WP4")
        declared = set(
            package["files_allowed"]["contracts"]
            + package["files_allowed"]["implementation"]
            + package["files_allowed"]["tests"]
        )
        self.assertTrue(ADDITIVE_PATHS.issubset(declared))

    def test_parent_and_ticket_contracts_are_exact_and_noncyclic(self) -> None:
        self.assertEqual(
            sha(PARENT_MANIFEST.read_bytes()),
            "342DDC34D8EB95DBB9253944B871F6AB3433A0E14FE03BBA3A9714E72B9019B1",
        )
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))),
            "F1ABB0D82469174C321DA42D54AC24F045908183898F16F1A80E97BE4277BA0E",
        )
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(BINDING_BUNDLE))),
            "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1",
        )
        bundle = load_json_strict(TICKET_BUNDLE)
        self.assertEqual(
            sha(canonical_json_v1_bytes(bundle)),
            "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED",
        )
        self.assertEqual(bundle["contract_id"], "ptcgdap-godot-action-ticket-p3-wp3-v1")
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        self.assertFalse(any(entry["path"].endswith("godot_action_ticket_bundle.json") for entry in bundle["artifacts"]))

    def test_owner_dependencies_are_host_private_and_execution_free(self) -> None:
        forbidden = [
            "GameStateMachine", "BattleScene", "HeadlessMatchBridge", "AIOpponent", "DeckStrategy",
            "_pending_choice", "_dialog_data", "CardDatabase", "CardIdCatalog", "subprocess", "socket",
            "requests", "http://", "https://", "ptcgabc", "func execute", "def execute", "func commit",
            "def commit",
        ]
        for relative in OWNER_PATHS:
            if not (ROOT / relative).is_file():
                continue
            text = (ROOT / relative).read_text(encoding="utf-8")
            for token in forbidden:
                self.assertNotIn(token, text, f"{relative}: {token}")

    def test_no_live_consumer_or_autoload_exists(self) -> None:
        needles = ["GodotActionTicket", "scripts/engine/decision/GodotActionTicket.gd"]
        hits = []
        for scan_root in (ROOT / "scripts", ROOT / "scenes"):
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.suffix not in {".gd", ".py", ".tscn", ".tres"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in OWNER_PATHS or relative in APPROVED_SHADOW_EXECUTOR_CONSUMERS:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                if any(needle in text for needle in needles):
                    hits.append(relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(hits, [])

    def test_serialized_ticket_contract_never_echoes_private_authority(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/godot_action_ticket_profile.json")
        serialization = profile["serialization_contract"]
        self.assertTrue(serialization["dto_only"])
        private = {
            "session_id", "callback_binding_hash", "private_engine_command", "private_object_refs",
            "command_refs", "private_refs", "current_source",
        }
        self.assertTrue(private.issubset(set(serialization["forbidden_fields"])))
        vectors = load_json_strict(ROOT / "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json")
        expected = [case["expected"] for section in ("issue_cases", "claim_cases") for case in vectors[section]]
        self.assertTrue(private.isdisjoint(all_keys(expected)))

    def test_final_docs_keep_ticket_shadow_and_p3_wp4_cursor(self) -> None:
        if not FINAL_MANIFEST.is_file():
            self.skipTest("final evidence not yet generated")
        readme = (ROOT / "docs/ptcgdap/README.md").read_text(encoding="utf-8")
        status = (ROOT / "docs/ptcgdap/STATUS.md").read_text(encoding="utf-8")
        checklist = (ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md").read_text(encoding="utf-8")
        for text in (readme, status):
            self.assertIn("P3-WP3", text)
            self.assertIn("P3-WP4", text)
            self.assertIn("A0", text)
        self.assertIn("P3-03", checklist)


if __name__ == "__main__":
    unittest.main()
