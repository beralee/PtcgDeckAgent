from __future__ import annotations

import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "artifacts/ptcgdap/p3_wp8/work_package.json"
MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp8/manifest.json"
PY_OWNER = ROOT / "scripts/ai/ptcgdap/shadow_whole_match_harness.py"
GD_OWNER = ROOT / "scripts/engine/decision/ShadowWholeMatchHarness.gd"
BUNDLE = ROOT / "contracts/ptcgdap/shadow_whole_match_harness_bundle.json"
PROFILE = ROOT / "contracts/ptcgdap/shadow_whole_match_harness_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json"
EXPECTED_BUNDLE = "0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P3Wp8BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK)
        expected_status = "shadow" if MANIFEST.exists() or work["implementation_state"] == "completed" else "planned"
        self.assertEqual(work["status"], expected_status)
        self.assertEqual(work["entry_evidence"]["parent_manifest_raw_sha256"], "ACDF0483435F5CFFEB5C3B3676EFA9F894CDE27B1BAF4E8ED477440E68E2A3ED")
        self.assertEqual(work["entry_evidence"]["parent_manifest_canonical_sha256"], "48F93ABD93948101D60FA88A4C01FCA7992E31A082E4F5BED81FDA92F4ADA4DD")
        self.assertEqual(work["entry_evidence"]["parent_candidate_canonical_sha256"], "CF5A489DA8F6CD2F6B94C3654A8478AEE9C1C4082C27CF43E6FB0B7406FF1836")
        self.assertEqual(work["entry_evidence"]["parent_candidate_entry_count"], 632)
        self.assertEqual(work["alignment_claim"], {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"})
        self.assertEqual(work["next_permitted_work"]["work_package"], "P4-WP1")

    def test_contract_is_exact_whole_match_shadow_fault_gate(self) -> None:
        bundle = load_json_strict(BUNDLE)
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(sha(canonical_json_v1_bytes(bundle)), EXPECTED_BUNDLE)
        self.assertEqual(bundle["contract_id"], "ptcgdap-shadow-whole-match-harness-p3-wp8-v1")
        self.assertEqual(bundle["parent_applier_bundle_canonical_sha256"], "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C")
        self.assertEqual(bundle["parent_owner_gate_bundle_canonical_sha256"], "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C")
        self.assertEqual(bundle["parent_prompt_broker_bundle_canonical_sha256"], "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E")
        self.assertEqual(profile["limits"], {"max_prompt_count":64})
        self.assertTrue(profile["semantics"]["fresh_applier_per_prompt"])
        self.assertTrue(profile["semantics"]["any_prompt_fault_requests_next_match_legacy"])
        self.assertTrue(profile["semantics"]["next_match_generation_strictly_increases"])
        self.assertFalse(profile["semantics"]["live_consumer"])
        self.assertFalse(profile["semantics"]["serialized_report_is_authority"])
        self.assertEqual(len(vectors["cases"]), 9)
        self.assertEqual({case["scenario"] for case in vectors["cases"]}, {"two_prompt_success","capture_fault","apply_fault","restore_fault","replay_chain","invalid_result","legacy_start","wrong_broker","finish_clean"})
        for entry in bundle["artifacts"]:
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))))

    def test_parent_contracts_and_source_lock_remain_unchanged(self) -> None:
        anchors = {
            "contracts/ptcgdap/shadow_engine_command_applier_bundle.json": "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C",
            "contracts/ptcgdap/shadow_match_owner_gate_bundle.json": "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C",
            "contracts/ptcgdap/shadow_prompt_broker_bundle.json": "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E",
            "docs/ptcgdap/SOURCE_LOCK.json": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        }
        for path, expected in anchors.items():
            self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT / path))), expected, path)

    def test_runtime_has_only_approved_shadow_dependencies(self) -> None:
        py = PY_OWNER.read_text(encoding="utf-8")
        gd = GD_OWNER.read_text(encoding="utf-8")
        forbidden = [
            "GameStateMachine","GameState","BattleScene","AIOpponent","DeckStrategy","HeadlessMatchBridge",
            "_pending_choice","_dialog_data","requests","urllib","socket","subprocess","ptcgabc",
            "FileAccess.open(\"user://","OS.execute","HTTPRequest","RandomNumberGenerator",".invoke(","call(\"invoke\"",
        ]
        for token in forbidden:
            self.assertNotIn(token, py, token)
            self.assertNotIn(token, gd, token)
        self.assertNotRegex(py, r"\b(eval|exec)\s*\(")
        self.assertEqual(set(re.findall(r'preload\("[^"]*/([^/"]+)"\)', gd)), {"CabtJsonTree.gd","ShadowMatchOwnerGate.gd","ShadowPromptBroker.gd","ShadowEngineCommandApplier.gd"})

    def test_no_live_ui_headless_or_project_consumer_exists(self) -> None:
        needles = ["ShadowWholeMatchHarness", "scripts/engine/decision/ShadowWholeMatchHarness.gd"]
        offenders: list[str] = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path in {GD_OWNER,PY_OWNER} or path.suffix.lower() not in {".gd",".py",".tscn",".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                if any(needle in text for needle in needles): offenders.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(offenders, [])

    def test_report_schema_excludes_private_capabilities(self) -> None:
        schema_text = (ROOT / "contracts/ptcgdap/shadow_whole_match_harness.schema.json").read_text(encoding="utf-8")
        profile = load_json_strict(PROFILE)
        for key in profile["private_fields_forbidden_from_report"]:
            self.assertNotIn(f'"{key}"', schema_text)
        self.assertIn('"authoritative"', schema_text)
        self.assertIn('"execution_ids"', schema_text)


if __name__ == "__main__":
    unittest.main()
