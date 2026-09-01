from __future__ import annotations

import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "artifacts/ptcgdap/p3_wp7/work_package.json"
MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp7/manifest.json"
PY_OWNER = ROOT / "scripts/ai/ptcgdap/shadow_engine_command_applier.py"
GD_OWNER = ROOT / "scripts/engine/decision/ShadowEngineCommandApplier.gd"
BUNDLE = ROOT / "contracts/ptcgdap/shadow_engine_command_applier_bundle.json"
PROFILE = ROOT / "contracts/ptcgdap/shadow_engine_command_applier_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json"
EXPECTED_BUNDLE = "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P3Wp7BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK)
        expected_status = "shadow" if MANIFEST.exists() or work["implementation_state"] == "completed" else "planned"
        self.assertEqual(work["status"], expected_status)
        self.assertEqual(work["entry_evidence"]["parent_manifest_raw_sha256"], "8BBBE90A68D21C575C3457F1AECC0547A2C1894E6DA2F9D434C141147D87A7CB")
        self.assertEqual(work["entry_evidence"]["parent_manifest_canonical_sha256"], "5B20B9D5CC9D8B4167251FFFB9B170DD0FEE8836A28548C28A105C8DA5187EE0")
        self.assertEqual(work["entry_evidence"]["parent_candidate_canonical_sha256"], "8E8D6BC920C55505855A11082F6975D870C09E14972249C9EE45B28D6C0A86E4")
        self.assertEqual(work["alignment_claim"], {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"})
        self.assertEqual(work["next_permitted_work"]["work_package"], "P3-WP8")

    def test_contract_is_exact_one_shot_reversible_shadow_applier(self) -> None:
        bundle = load_json_strict(BUNDLE)
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(sha(canonical_json_v1_bytes(bundle)), EXPECTED_BUNDLE)
        self.assertEqual(bundle["contract_id"], "ptcgdap-shadow-engine-command-applier-p3-wp7-v1")
        self.assertEqual(bundle["parent_owner_gate_bundle_canonical_sha256"], "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C")
        self.assertEqual(bundle["parent_prompt_broker_bundle_canonical_sha256"], "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E")
        self.assertEqual(profile["command_protocol"], ["shadow_capture","shadow_apply","shadow_restore"])
        self.assertEqual(profile["limits"]["max_execution_generation_per_applier"], 1)
        self.assertTrue(profile["semantics"]["capture_hook_is_observational"])
        self.assertTrue(profile["semantics"]["failed_apply_restores_all_captured_state"])
        self.assertFalse(profile["semantics"]["live_consumer"])
        self.assertFalse(profile["semantics"]["serialized_witness_is_authority"])
        self.assertEqual(len(vectors["cases"]), 11)
        for entry in bundle["artifacts"]:
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))))

    def test_parent_contracts_and_source_lock_remain_unchanged(self) -> None:
        anchors = {
            "contracts/ptcgdap/shadow_match_owner_gate_bundle.json": "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C",
            "contracts/ptcgdap/shadow_prompt_broker_bundle.json": "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E",
            "contracts/ptcgdap/godot_action_executor_bundle.json": "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92",
            "docs/ptcgdap/SOURCE_LOCK.json": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        }
        for path, expected in anchors.items():
            self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT / path))), expected, path)

    def test_runtime_has_only_approved_shadow_dependencies(self) -> None:
        py = PY_OWNER.read_text(encoding="utf-8")
        gd = GD_OWNER.read_text(encoding="utf-8")
        forbidden = [
            "GameStateMachine", "GameState", "BattleScene", "AIOpponent", "DeckStrategy", "HeadlessMatchBridge",
            "_pending_choice", "_dialog_data", "requests", "urllib", "socket", "subprocess", "ptcgabc",
            "FileAccess.open(\"user://", "OS.execute", "HTTPRequest", "RandomNumberGenerator", ".invoke(", "call(\"invoke\"",
        ]
        for token in forbidden:
            self.assertNotIn(token, py, token)
            self.assertNotIn(token, gd, token)
        self.assertNotRegex(py, r"\b(eval|exec)\s*\(")
        self.assertEqual(
            set(re.findall(r'preload\("[^"]*/([^/"]+)"\)', gd)),
            {"CabtJsonTree.gd", "ShadowMatchOwnerGate.gd", "ShadowPromptBroker.gd"},
        )

    def test_no_live_ui_headless_or_project_consumer_exists(self) -> None:
        needles = ["ShadowEngineCommandApplier", "scripts/engine/decision/ShadowEngineCommandApplier.gd"]
        allowed_shadow_consumers = {
            "scripts/ai/ptcgdap/shadow_whole_match_harness.py",
            "scripts/engine/decision/ShadowWholeMatchHarness.gd",
        }
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
                    offenders.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(offenders, [])
        self.assertTrue(all((ROOT / path).exists() for path in allowed_shadow_consumers))

    def test_serialized_witness_schema_excludes_private_capabilities(self) -> None:
        schema_text = (ROOT / "contracts/ptcgdap/shadow_engine_command_applier.schema.json").read_text(encoding="utf-8")
        profile = load_json_strict(PROFILE)
        for key in profile["private_fields_forbidden_from_witness"]:
            self.assertNotIn(f'"{key}"', schema_text)
        self.assertIn('"authoritative"', schema_text)
        self.assertIn('"resolution_count"', schema_text)


if __name__ == "__main__":
    unittest.main()
