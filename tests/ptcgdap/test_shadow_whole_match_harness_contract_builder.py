from __future__ import annotations
import json,subprocess,sys
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes,load_json_strict
import hashlib

ROOT=Path(__file__).resolve().parents[2]
BUNDLE=ROOT/"contracts/ptcgdap/shadow_whole_match_harness_bundle.json"
PROFILE=ROOT/"contracts/ptcgdap/shadow_whole_match_harness_profile.json"
VECTORS=ROOT/"contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json"
SCHEMA=ROOT/"contracts/ptcgdap/shadow_whole_match_harness.schema.json"
EXPECTED="0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"
def sha(v:bytes)->str:return hashlib.sha256(v).hexdigest().upper()

class ShadowWholeMatchHarnessContractBuilderTests(unittest.TestCase):
    def test_builder_is_deterministic_and_bundle_is_exact(self)->None:
        subprocess.run([sys.executable,"tools/ptcgdap/build_shadow_whole_match_harness_contract.py","--check"],cwd=ROOT,check=True)
        bundle=load_json_strict(BUNDLE);self.assertEqual(sha(canonical_json_v1_bytes(bundle)),EXPECTED)
        self.assertEqual([e["id"] for e in bundle["artifacts"]],["schema","profile","vectors"])
        for entry in bundle["artifacts"]:self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT/entry["path"]))),entry["canonical_sha256"])

    def test_profile_closes_chain_fault_rollback_and_privacy(self)->None:
        profile=load_json_strict(PROFILE)
        self.assertEqual(profile["states"],["ready","active","completed","faulted","dirty","rollback_verified"])
        self.assertEqual(profile["limits"],{"max_prompt_count":64})
        self.assertTrue(profile["semantics"]["any_prompt_fault_requests_next_match_legacy"])
        self.assertFalse(profile["semantics"]["rollback_changes_current_match"])
        self.assertFalse(profile["semantics"]["live_consumer"])
        self.assertIn("private_engine_command",profile["private_fields_forbidden_from_report"])

    def test_vectors_cover_success_dirty_replay_and_next_match_rollback(self)->None:
        vectors=load_json_strict(VECTORS);self.assertEqual(len(vectors["cases"]),9)
        self.assertEqual(len({case["case_id"] for case in vectors["cases"]}),9)
        scenarios={case["scenario"] for case in vectors["cases"]}
        self.assertTrue({"two_prompt_success","capture_fault","apply_fault","restore_fault","replay_chain","legacy_start","wrong_broker"}.issubset(scenarios))

    def test_schema_rejects_private_extra_and_broken_relations(self)->None:
        validator=Draft202012Validator(load_json_strict(SCHEMA))
        report={"profile":"ptcgdap-shadow-whole-match-harness-p3-wp8-v1","state":"completed","match_generation":1,"prompt_count":1,"broker_generations":[1],"decision_generations":[1],"snapshot_ids":["A"*64],"window_ids":["B"*64],"execution_ids":["C"*64],"fault_code":"","dirty":False,"rollback_requested":False,"match_ended":True,"next_match_mode":None,"authority":"shadow_whole_match_report_audit","authoritative":False}
        validator.validate(report);validator.validate({"accepted":True,"error_code":"","report":report})
        for mutation in ({**report,"private_engine_command":"PRIVATE"},{**report,"dirty":"yes"},{**report,"fault_code":"PRIVATE"}):
            with self.assertRaises(Exception):validator.validate(mutation)

if __name__=="__main__":unittest.main()
