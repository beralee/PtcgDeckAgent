from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_godot_action_executor_contract import PROFILE_ID


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class GodotActionExecutorContractBuilderTests(unittest.TestCase):
    def test_builder_check_reproduces_all_four_artifacts(self) -> None:
        subprocess.run([sys.executable, "tools/ptcgdap/build_godot_action_executor_contract.py", "--check"], cwd=ROOT, check=True)

    def test_bundle_binds_exact_three_noncyclic_artifacts(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / "godot_action_executor_bundle.json")
        self.assertEqual(bundle["contract_id"], PROFILE_ID)
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        for entry in bundle["artifacts"]:
            self.assertNotEqual(entry["path"], "contracts/ptcgdap/godot_action_executor_bundle.json")
            self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))), entry["canonical_sha256"])

    def test_parent_and_profile_are_exact(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "godot_action_executor_profile.json")
        self.assertEqual(profile["profile_id"], PROFILE_ID)
        self.assertEqual(profile["parent"]["manifest_raw_sha256"], "9564EE72D2BD400D010123E8563F50CCF0233BDC6436A3C35FDCDD9F78710556")
        self.assertEqual(profile["parent"]["manifest_canonical_sha256"], "5ACC39769D3A63EA7B27CAA61B107FCCF284DC52FCFB93F9B77B1547883FAF2B")
        self.assertFalse(profile["commit_contract"]["engine_method_invocation"])

    def test_vector_counts_and_ids_are_exact(self) -> None:
        vectors = load_json_strict(CONTRACT_ROOT / "godot_action_executor_conformance_vectors.json")
        self.assertEqual(len(vectors["preflight_cases"]), 13)
        self.assertEqual(len(vectors["commit_cases"]), 10)
        self.assertEqual(len(vectors["transition_cases"]), 5)
        ids = [case["id"] for key in ("preflight_cases", "commit_cases", "transition_cases") for case in vectors[key]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_schema_accepts_owner_dtos_and_rejects_private_fields(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / "godot_action_executor.schema.json")
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        base = {"schema_version": 1, "profile_id": PROFILE_ID, "kind": "preflight_result", "value": {"accepted": False, "error_code": "invalid_claim_result", "audit": None}}
        self.assertEqual(list(validator.iter_errors(base)), [])
        bad = {**base, "value": {**base["value"], "private_engine_command": "sentinel"}}
        self.assertTrue(list(validator.iter_errors(bad)))
        wrong_kind = copy.deepcopy(base)
        wrong_kind["value"] = {"accepted": False, "error_code": "already_committed", "audit": None}
        self.assertTrue(list(validator.iter_errors(wrong_kind)))
        commit = copy.deepcopy(base)
        commit["kind"] = "commit_result"
        commit["value"] = {"accepted": False, "error_code": "invalid_ticket_owner", "audit": None}
        self.assertTrue(list(validator.iter_errors(commit)))

    def test_serialization_forbidden_fields_are_closed(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "godot_action_executor_profile.json")
        forbidden = set(profile["serialization_contract"]["forbidden_fields"])
        self.assertTrue({"session_id", "callback_binding_hash", "current_source", "private_engine_command", "private_object_refs", "binding_resolutions"}.issubset(forbidden))


if __name__ == "__main__":
    unittest.main()
