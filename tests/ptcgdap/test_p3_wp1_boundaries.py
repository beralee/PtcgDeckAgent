from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "artifacts/ptcgdap/p3_wp1/work_package.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p2_wp5/manifest.json"
BUNDLE = ROOT / "contracts/ptcgdap/engine_decision_port_bundle.json"
P1_BUNDLE = ROOT / "contracts/ptcgdap/cabt_contract_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
OWNER_PATHS = {
    "scripts/ai/ptcgdap/engine_decision_port.py",
    "scripts/engine/decision/EngineDecisionPort.gd",
}
APPROVED_SHADOW_BINDING_CONSUMERS = {
    "scripts/ai/ptcgdap/marnie_prompt_broker.py",
    "scripts/ai/ptcgdap/public/MarniePromptBroker.gd",
    "scripts/ai/ptcgdap/godot_option_binding.py",
    "scripts/engine/decision/GodotOptionBinding.gd",
    "scripts/ai/ptcgdap/godot_action_ticket.py",
    "scripts/engine/decision/GodotActionTicket.gd",
    "scripts/ai/ptcgdap/godot_action_executor.py",
    "scripts/engine/decision/GodotActionExecutor.gd",
    "scripts/ai/ptcgdap/shadow_prompt_broker.py",
    "scripts/engine/decision/ShadowPromptBroker.gd",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class P3Wp1BoundaryTests(unittest.TestCase):
    def test_governance_and_parent_anchors_are_exact(self) -> None:
        package = load_json_strict(PACKAGE)
        self.assertEqual(package["work_package"], "P3-WP1")
        self.assertIn(package["status"], {"planned", "shadow"})
        self.assertEqual(package["shadow_or_live"], "shadow_decision_source_snapshot_only_no_binding_ticket_commit_or_live_consumer")
        self.assertEqual(package["entry_evidence"]["parent_manifest_raw_sha256"], sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(package["entry_evidence"]["parent_manifest_canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(package["alignment_claim"]["A0"], "partial / not claimed")
        self.assertTrue(all(package["alignment_claim"][key] == "not evaluated" for key in ["A1", "A2", "A3", "A4", "A5"]))
        self.assertEqual(package["next_permitted_work"]["work_package"], "P3-WP2")

    def test_p1_and_p2_parent_contracts_remain_unchanged(self) -> None:
        self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(P1_BUNDLE))), "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294")
        self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(SOURCE_LOCK))), "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205")
        parent = load_json_strict(PARENT_MANIFEST)
        self.assertEqual(parent["trust_anchors"]["projector_bundle_canonical_sha256"], "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041")

    def test_decision_bundle_is_independent_exact_and_noncyclic(self) -> None:
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(sha(canonical_json_v1_bytes(bundle)), "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81")
        self.assertEqual(bundle["contract_id"], "ptcgdap-engine-decision-port-p3-wp1-v1")
        self.assertEqual([item["id"] for item in bundle["artifacts"]], ["schema", "profile", "vectors"])
        self.assertFalse(any(item["path"].endswith("engine_decision_port_bundle.json") for item in bundle["artifacts"]))

    def test_owner_dependencies_are_narrow_and_have_no_execution_surface(self) -> None:
        forbidden = [
            "GameStateMachine", "BattleScene", "HeadlessMatchBridge", "AIOpponent", "DeckStrategy",
            "GodotOptionBinding", "ActionTicket", "private_engine_command", "_pending_choice", "_dialog_data",
            "execute(", "commit(", "subprocess", "socket", "requests", "http://", "https://", "ptcgabc",
        ]
        for relative in OWNER_PATHS:
            text = (ROOT / relative).read_text(encoding="utf-8")
            for token in forbidden:
                self.assertNotIn(token, text, f"{relative}: {token}")

    def test_no_live_consumer_or_autoload_exists(self) -> None:
        needles = ["EngineDecisionPort", "scripts/engine/decision/EngineDecisionPort.gd"]
        roots = [ROOT / "scripts", ROOT / "scenes"]
        hits = []
        for scan_root in roots:
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.suffix not in {".gd", ".tscn", ".tres", ".py"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in OWNER_PATHS or relative in APPROVED_SHADOW_BINDING_CONSUMERS or relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                if any(needle in text for needle in needles):
                    hits.append(relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(hits, [])

    def test_serialized_contract_is_explicitly_non_authoritative(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/engine_decision_port_profile.json")
        contract = profile["serialization_contract"]
        self.assertTrue(contract["dto_only"])
        self.assertIn("never grants decision, window, binding or execution authority", contract["consumer_rule"])
        self.assertEqual(profile["hash_profile"]["authority"], "audit_only_not_binding_or_execution_authority")


if __name__ == "__main__":
    unittest.main()
