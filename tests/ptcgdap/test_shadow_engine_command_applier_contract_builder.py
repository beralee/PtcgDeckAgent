from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict

ROOT=Path(__file__).resolve().parents[2]
CONTRACT_ROOT=ROOT/"contracts/ptcgdap"
BUNDLE=CONTRACT_ROOT/"shadow_engine_command_applier_bundle.json"
PROFILE_ID="ptcgdap-shadow-engine-command-applier-p3-wp7-v1"
PARENT_GATE="9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C"
EXPECTED={"schema":"contracts/ptcgdap/shadow_engine_command_applier.schema.json","profile":"contracts/ptcgdap/shadow_engine_command_applier_profile.json","vectors":"contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json"}
def sha(value:bytes)->str:return hashlib.sha256(value).hexdigest().upper()

class ShadowEngineCommandApplierContractBuilderTests(unittest.TestCase):
    def test_builder_is_deterministic_and_bundle_is_exact(self)->None:
        subprocess.run([sys.executable,"tools/ptcgdap/build_shadow_engine_command_applier_contract.py","--check"],cwd=ROOT,check=True)
        bundle=load_json_strict(BUNDLE)
        self.assertEqual(bundle["contract_id"],PROFILE_ID); self.assertEqual(bundle["parent_owner_gate_bundle_canonical_sha256"],PARENT_GATE)
        self.assertEqual({x["id"]:x["path"] for x in bundle["artifacts"]},EXPECTED)
        for entry in bundle["artifacts"]: self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT/entry["path"]))),entry["canonical_sha256"])

    def test_profile_closes_protocol_states_errors_and_privacy(self)->None:
        profile=load_json_strict(CONTRACT_ROOT/"shadow_engine_command_applier_profile.json")
        self.assertEqual(profile["profile_id"],PROFILE_ID)
        self.assertEqual(profile["states"],["ready","executed","aborted","poisoned"])
        self.assertEqual(profile["command_protocol"],["shadow_capture","shadow_apply","shadow_restore"])
        self.assertEqual(profile["command_protocol_results"],{
            "shadow_capture":{"argument_count":0,"result_exact_object_keys":["ok","snapshot"],"ok_exact_boolean":True},
            "shadow_apply":{"argument_count":0,"result_exact_boolean":True},
            "shadow_restore":{"argument_count":1,"result_exact_boolean":True},
        })
        self.assertTrue(profile["semantics"]["exact_aligned_gate_and_broker_required"])
        self.assertTrue(profile["semantics"]["successful_result_consumed_at_most_once"])
        self.assertTrue(profile["semantics"]["capture_hook_is_observational"])
        self.assertTrue(profile["semantics"]["failed_apply_restores_all_captured_state"])
        self.assertFalse(profile["semantics"]["live_consumer"])
        self.assertFalse(profile["semantics"]["serialized_witness_is_authority"])
        self.assertFalse(profile["semantics"]["schema_alone_authorizes_witness"])
        self.assertEqual(len(profile["error_codes"]),len(set(profile["error_codes"])))
        for key in ["private_engine_command","private_object_refs","captured_state","session_id","callback_binding_hash","current_source"]:
            self.assertIn(key,profile["private_fields_forbidden_from_witness"])

    def test_vectors_cover_success_replay_restore_and_poison(self)->None:
        vectors=load_json_strict(CONTRACT_ROOT/"shadow_engine_command_applier_conformance_vectors.json")
        ids=[case["case_id"] for case in vectors["cases"]]
        self.assertEqual(len(ids),len(set(ids)))
        self.assertTrue({"ordered-success","replay-rejected","legacy-gate-rejected","wrong-broker-rejected","capture-failure","apply-failure-restored","restore-failure-poisons","duplicate-command-rejected","mutated-result-rejected","uncommitted-result-rejected"}.issubset(ids))
        self.assertEqual(vectors["private_sentinels"],["PRIVATE_COMMAND_SENTINEL","PRIVATE_STATE_SENTINEL","PRIVATE_SESSION_SENTINEL"])

    def test_schema_rejects_private_extra_and_broken_witness_relations(self)->None:
        schema=load_json_strict(CONTRACT_ROOT/"shadow_engine_command_applier.schema.json"); Draft202012Validator.check_schema(schema); validator=Draft202012Validator(schema)
        witness={"profile":PROFILE_ID,"execution_id":"A"*64,"execution_generation":1,"match_generation":1,"broker_generation":1,"decision_generation":1,"snapshot_id":"B"*64,"window_id":"C"*64,"public_observation_hash":"D"*64,"chooser_player_index":0,"selected_indexes":[1,0],"selected_fingerprint_hashes":["E"*64,"F"*64],"resolution_count":2,"state":"executed","authority":"shadow_executed_witness_audit","authoritative":False}
        self.assertEqual(list(validator.iter_errors(witness)),[])
        for bad in [{**witness,"authoritative":True},{**witness,"selected_indexes":[1,1]},{**witness,"selected_fingerprint_hashes":["E"*64,"E"*64]},{**witness,"private_engine_command":"leak"},{**witness,"execution_generation":9007199254740992}]:
            self.assertTrue(list(validator.iter_errors(bad)),bad)

if __name__=="__main__":unittest.main()
