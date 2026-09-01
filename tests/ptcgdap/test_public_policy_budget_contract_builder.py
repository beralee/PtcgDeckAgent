from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class PublicPolicyBudgetContractBuilderTests(unittest.TestCase):
    def test_builder_check_and_contract_shape(self) -> None:
        subprocess.run([sys.executable, "tools/ptcgdap/build_public_policy_budget_contract.py", "--check"], cwd=ROOT, check=True)
        bundle = load_json_strict(CONTRACT_ROOT / "public_policy_budget_bundle.json")
        profile = load_json_strict(CONTRACT_ROOT / "public_policy_budget_profile.json")
        vectors = load_json_strict(CONTRACT_ROOT / "public_policy_budget_conformance_vectors.json")
        self.assertEqual("ptcgdap-public-policy-budget-p4-wp6-v1", bundle["bundle_id"])
        self.assertEqual(3, len(bundle["artifacts"]))
        self.assertEqual(600000, profile["budget_contract"]["total_match_budget_ms"])
        self.assertEqual(["full", "base_only", "deterministic_fallback"], profile["budget_contract"]["modes"])
        self.assertEqual(8, len(vectors["step_cases"]))
        self.assertEqual(8, len(vectors["rejections"]))
        self.assertNotIn("final_bundle_hash", canonical_json_v1_bytes(vectors).decode("utf-8"))

        schema = load_json_strict(CONTRACT_ROOT / "public_policy_budget.schema.json")
        validator = Draft202012Validator(schema)
        validator.validate(vectors["fixture"]["initial_ledger"])
        for case in vectors["step_cases"]:
            validator.validate(case["expected_result"])

        invalid = dict(vectors["step_cases"][0]["expected_result"])
        invalid["mode"] = "full"
        invalid["reason_code"] = "unknown_capability"
        invalid["unknown_capability_count"] = 0
        self.assertTrue(list(validator.iter_errors(invalid)))

        invalid = dict(vectors["step_cases"][4]["expected_result"])
        invalid["fallback_used"] = False
        invalid["selected_indexes"] = []
        self.assertTrue(list(validator.iter_errors(invalid)))


if __name__ == "__main__":
    unittest.main()
