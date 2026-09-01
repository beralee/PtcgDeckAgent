from __future__ import annotations

import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "artifacts/ptcgdap/p3_wp5/work_package.json"
MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp5/manifest.json"
PY_OWNER = ROOT / "scripts/ai/ptcgdap/shadow_prompt_broker.py"
GD_OWNER = ROOT / "scripts/engine/decision/ShadowPromptBroker.gd"
BUNDLE = ROOT / "contracts/ptcgdap/shadow_prompt_broker_bundle.json"
PROFILE = ROOT / "contracts/ptcgdap/shadow_prompt_broker_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P3Wp5BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK)
        expected_status = "shadow" if MANIFEST.exists() or work["implementation_state"] == "completed" else "planned"
        self.assertEqual(work["status"], expected_status)
        self.assertEqual(work["entry_evidence"]["parent_manifest_raw_sha256"], "5321F57EBF81AEFE1D042730AC05B93CDCEC3052A94CC469EA5BFDEE40719FAF")
        self.assertEqual(work["entry_evidence"]["parent_manifest_canonical_sha256"], "055ABF3E759069C6DC52FC760C81F9041A32EF3FC14B80A958E69174D0287643")
        self.assertEqual(work["entry_evidence"]["parent_candidate_canonical_sha256"], "F338695685482CF2ED90BE115690F5DB5CA6F826B8E19222B822D014F7BFF239")
        self.assertEqual(work["alignment_claim"], {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"})
        self.assertEqual(work["next_permitted_work"]["work_package"], "P3-WP6")

    def test_contract_is_exact_subordinate_w1_w7_family(self) -> None:
        bundle = load_json_strict(BUNDLE)
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(bundle["contract_id"], "ptcgdap-shadow-prompt-broker-p3-wp5-v1")
        self.assertEqual(bundle["parent_executor_bundle_canonical_sha256"], "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92")
        self.assertEqual(profile["prompt_families"], ["W1","W2","W3","W4","W5","W6","W7"])
        self.assertEqual([case["family"] for case in vectors["family_cases"]], profile["prompt_families"])
        self.assertFalse(profile["authority_contract"]["engine_method_invocation"])
        self.assertTrue(profile["authority_contract"]["strictly_newer_prompt_required_after_commit"])
        for entry in bundle["artifacts"]:
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))))

    def test_parent_contracts_and_source_lock_remain_unchanged(self) -> None:
        anchors = {
            "contracts/ptcgdap/godot_action_executor_bundle.json": "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92",
            "contracts/ptcgdap/godot_action_ticket_bundle.json": "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED",
            "contracts/ptcgdap/godot_option_binding_bundle.json": "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1",
            "docs/ptcgdap/SOURCE_LOCK.json": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        }
        for path, expected in anchors.items():
            self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT / path))), expected, path)

    def test_runtime_has_only_approved_shadow_dependencies(self) -> None:
        py = PY_OWNER.read_text(encoding="utf-8")
        gd = GD_OWNER.read_text(encoding="utf-8")
        forbidden = [
            "GameStateMachine", "BattleScene", "AIOpponent", "DeckStrategy", "HeadlessMatchBridge",
            "_pending_choice", "_dialog_data", "requests", "urllib", "socket", "subprocess", "ptcgabc",
            "FileAccess.open(\"user://", "OS.execute", "HTTPRequest", "RandomNumberGenerator",
        ]
        for token in forbidden:
            self.assertNotIn(token, py, token)
            self.assertNotIn(token, gd, token)
        self.assertNotRegex(py, r"\b(eval|exec)\s*\(")
        allowed_preloads = {
            "CabtJsonTree.gd", "CabtSelectionWindow.gd", "CabtDeterministicFallback.gd",
            "EngineDecisionPort.gd", "GodotOptionBinding.gd", "GodotActionTicket.gd", "GodotActionExecutor.gd",
        }
        self.assertEqual(set(re.findall(r'preload\("[^"]*/([^/"]+)"\)', gd)), allowed_preloads)

    def test_no_live_or_project_consumer_exists(self) -> None:
        needles = ["ShadowPromptBroker", "scripts/engine/decision/ShadowPromptBroker.gd"]
        allowed_shadow_consumers = {
            "scripts/ai/ptcgdap/marnie_prompt_broker.py",
            "scripts/ai/ptcgdap/public/MarniePromptBroker.gd",
            "scripts/ai/ptcgdap/shadow_match_owner_gate.py",
            "scripts/engine/decision/ShadowMatchOwnerGate.gd",
            "scripts/ai/ptcgdap/shadow_engine_command_applier.py",
            "scripts/engine/decision/ShadowEngineCommandApplier.gd",
            "scripts/ai/ptcgdap/shadow_whole_match_harness.py",
            "scripts/engine/decision/ShadowWholeMatchHarness.gd",
        } | AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS
        offenders = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path in {GD_OWNER, PY_OWNER} or path.suffix.lower() not in {".gd", ".py", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                relative = path.relative_to(ROOT).as_posix()
                if any(needle in text for needle in needles) and relative not in allowed_shadow_consumers:
                    offenders.append(relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(offenders, [])
        self.assertTrue(all((ROOT / path).exists() for path in allowed_shadow_consumers))

    def test_public_audit_has_no_private_or_execution_capability_fields(self) -> None:
        schema_text = (ROOT / "contracts/ptcgdap/shadow_prompt_broker.schema.json").read_text(encoding="utf-8")
        profile = load_json_strict(PROFILE)
        for key in profile["private_fields_forbidden_from_audit"]:
            self.assertNotIn(f'"{key}"', schema_text)
        self.assertNotIn("engine_method", schema_text)
        self.assertIn('"authoritative"', schema_text)


if __name__ == "__main__":
    unittest.main()
