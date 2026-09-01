from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "artifacts/ptcgdap/p3_wp2/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp2/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp1/manifest.json"
BUNDLE = ROOT / "contracts/ptcgdap/godot_option_binding_bundle.json"
DECISION_BUNDLE = ROOT / "contracts/ptcgdap/engine_decision_port_bundle.json"
SELECTION_BUNDLE = ROOT / "contracts/ptcgdap/cabt_contract_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
OWNER_PATHS = {
    "scripts/ai/ptcgdap/godot_option_binding.py",
    "scripts/engine/decision/GodotOptionBinding.gd",
}
APPROVED_SHADOW_TICKET_CONSUMERS = {
    "scripts/ai/ptcgdap/marnie_prompt_broker.py",
    "scripts/ai/ptcgdap/public/MarniePromptBroker.gd",
    "scripts/ai/ptcgdap/godot_action_ticket.py",
    "scripts/engine/decision/GodotActionTicket.gd",
    "scripts/ai/ptcgdap/godot_action_executor.py",
    "scripts/engine/decision/GodotActionExecutor.gd",
    "scripts/ai/ptcgdap/shadow_prompt_broker.py",
    "scripts/engine/decision/ShadowPromptBroker.gd",
}
ADDITIVE_PATHS = {
    "contracts/ptcgdap/godot_option_binding.schema.json",
    "contracts/ptcgdap/godot_option_binding_profile.json",
    "contracts/ptcgdap/godot_option_binding_conformance_vectors.json",
    "contracts/ptcgdap/godot_option_binding_bundle.json",
    "scripts/ai/ptcgdap/godot_option_binding.py",
    "scripts/engine/decision/GodotOptionBinding.gd",
    "tools/ptcgdap/build_godot_option_binding_contract.py",
    "tests/ptcgdap/test_godot_option_binding_contract_builder.py",
    "tests/ptcgdap/test_godot_option_binding.py",
    "tests/ptcgdap/test_godot_option_binding_properties.py",
    "tests/ptcgdap/test_p3_wp2_boundaries.py",
    "tests/ptcgdap/test_p3_wp2_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_option_binding.gd",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class P3Wp2BoundaryTests(unittest.TestCase):
    def test_governance_parent_alignment_and_cursor_are_exact(self) -> None:
        package = load_json_strict(PACKAGE)
        self.assertEqual(package["work_package"], "P3-WP2")
        expected_status = "shadow" if FINAL_MANIFEST.is_file() else "planned"
        expected_state = "completed" if FINAL_MANIFEST.is_file() else "not_started"
        self.assertEqual(package["status"], expected_status)
        self.assertEqual(package["implementation_state"], expected_state)
        self.assertEqual(
            package["shadow_or_live"],
            "shadow_host_private_option_binding_only_no_ticket_commit_execution_or_live_consumer",
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
        self.assertEqual(package["next_permitted_work"]["work_package"], "P3-WP3")
        allowed = package["files_allowed"]
        declared = set(allowed["contracts"] + allowed["implementation"] + allowed["tests"])
        self.assertEqual(ADDITIVE_PATHS - {"tests/ptcgdap/test_p3_wp1_boundaries.py", "tests/ptcgdap/test_p3_wp1_parent_snapshot.py"}, declared - {
            "tests/ptcgdap/test_p3_wp1_boundaries.py",
            "tests/ptcgdap/test_p3_wp1_parent_snapshot.py",
            "tests/ptcgdap/test_p2_wp1_parent_snapshot.py",
            "tests/ptcgdap/test_p2_wp2_parent_snapshot.py",
            "tests/ptcgdap/test_p2_wp3_parent_snapshot.py",
            "tests/ptcgdap/test_p2_wp4_parent_snapshot.py",
            "tests/ptcgdap/test_p2_wp5_parent_snapshot.py",
        })

    def test_parent_contracts_and_evidence_remain_byte_exact(self) -> None:
        self.assertEqual(
            sha(PARENT_MANIFEST.read_bytes()),
            "E0FD12EEE352976D930EE46685F937B0E0264EA567CBEB5FDF151372E57FE619",
        )
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))),
            "B47E808277C954003494A5C414E02AD6FA81C0CE6EC73A1E7064B40E991B2F4F",
        )
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(DECISION_BUNDLE))),
            "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81",
        )
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(SELECTION_BUNDLE))),
            "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294",
        )
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(SOURCE_LOCK))),
            "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        )

    def test_binding_bundle_is_exact_independent_and_noncyclic(self) -> None:
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(
            sha(canonical_json_v1_bytes(bundle)),
            "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1",
        )
        self.assertEqual(bundle["contract_id"], "ptcgdap-godot-option-binding-p3-wp2-v1")
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        self.assertFalse(any(entry["path"].endswith("godot_option_binding_bundle.json") for entry in bundle["artifacts"]))
        self.assertEqual(bundle["parent"]["work_package"], "P3-WP1")

    def test_owner_dependencies_are_narrow_and_execution_free(self) -> None:
        forbidden = [
            "GameStateMachine", "BattleScene", "HeadlessMatchBridge", "AIOpponent", "DeckStrategy",
            "ActionTicket", "_pending_choice", "_dialog_data", "CardDatabase", "CardIdCatalog",
            "subprocess", "socket", "requests", "http://", "https://", "ptcgabc",
            "func execute", "def execute", "func commit", "def commit", "func consume", "def consume",
        ]
        for relative in OWNER_PATHS:
            text = (ROOT / relative).read_text(encoding="utf-8")
            for token in forbidden:
                self.assertNotIn(token, text, f"{relative}: {token}")
        python_text = (ROOT / "scripts/ai/ptcgdap/godot_option_binding.py").read_text(encoding="utf-8")
        self.assertNotIn("scripts.data", python_text)
        godot_text = (ROOT / "scripts/engine/decision/GodotOptionBinding.gd").read_text(encoding="utf-8")
        preload_lines = [line.strip() for line in godot_text.splitlines() if "preload(" in line or "load(" in line]
        for line in preload_lines:
            self.assertTrue(
                any(token in line for token in ("CabtJsonTree.gd", "EngineDecisionPort.gd", "CabtSelectionWindow.gd")),
                line,
            )

    def test_no_live_consumer_or_autoload_exists(self) -> None:
        needles = ["GodotOptionBinding", "scripts/engine/decision/GodotOptionBinding.gd"]
        hits = []
        for scan_root in (ROOT / "scripts", ROOT / "scenes"):
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.suffix not in {".gd", ".py", ".tscn", ".tres"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in OWNER_PATHS or relative in APPROVED_SHADOW_TICKET_CONSUMERS or relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                if any(needle in text for needle in needles):
                    hits.append(relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(hits, [])

    def test_serialized_contract_has_no_private_binding_material(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/godot_option_binding_profile.json")
        serialization = profile["serialization_contract"]
        self.assertTrue(serialization["dto_only"])
        self.assertIn("callback_binding_hash", serialization["forbidden_fields"])
        self.assertIn("private_engine_command", serialization["forbidden_fields"])
        self.assertIn("private_object_refs", serialization["forbidden_fields"])
        vectors = load_json_strict(ROOT / "contracts/ptcgdap/godot_option_binding_conformance_vectors.json")
        expected = [case["expected"] for section in ("bind_cases", "resolve_cases") for case in vectors[section]]
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
        self.assertTrue(
            {"callback_binding_hash", "private_engine_command", "private_object_refs"}.isdisjoint(all_keys(expected))
        )

    def test_final_docs_keep_shadow_claim_and_next_cursor(self) -> None:
        if not FINAL_MANIFEST.is_file():
            self.skipTest("final evidence not yet generated")
        readme = (ROOT / "docs/ptcgdap/README.md").read_text(encoding="utf-8")
        status = (ROOT / "docs/ptcgdap/STATUS.md").read_text(encoding="utf-8")
        self.assertIn("P3-WP2", readme)
        self.assertIn("P3-WP3", readme)
        self.assertIn("P3-WP2", status)
        self.assertIn("P3-WP3", status)
        self.assertIn("A0", status)
        self.assertIn("partial", status)
        self.assertIn("A5", status)
        self.assertIn("not evaluated", status)


if __name__ == "__main__":
    unittest.main()
