from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_public_base_policy_contract import artifacts


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
NAMES = (
    "public_base_policy.schema.json",
    "public_base_policy_profile.json",
    "public_base_policy_conformance_vectors.json",
    "public_base_policy_bundle.json",
)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class PublicBasePolicyContractBuilderTests(unittest.TestCase):
    def test_builder_check_and_bundle_bindings_are_exact(self) -> None:
        subprocess.run([sys.executable, "tools/ptcgdap/build_public_base_policy_contract.py", "--check"], cwd=ROOT, check=True)
        expected = artifacts()
        for name in NAMES:
            self.assertEqual(expected[name], load_json_strict(CONTRACT_ROOT / name), name)
        bundle = expected[NAMES[-1]]
        self.assertEqual("C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1", bundle["parent_bundle_canonical_sha256"])
        self.assertEqual(3, len(bundle["artifacts"]))
        for entry in bundle["artifacts"]:
            value = expected[Path(entry["path"]).name]
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(value)))

    def test_schema_validates_every_shared_request_and_result(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / NAMES[0])
        vectors = load_json_strict(CONTRACT_ROOT / NAMES[2])
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        for case in vectors["orchestration_cases"]:
            validator.validate(case["request"])
            validator.validate(case["expected_result"])
        bad = vectors["orchestration_cases"][0]["expected_result"] | {"private_state": "PRIVATE_SENTINEL"}
        self.assertTrue(list(validator.iter_errors(bad)))

    def test_profile_closes_stage_authority_and_time_budget_scope(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / NAMES[1])
        self.assertEqual(
            [
                "validate_exact_owners",
                "propose_public_adapter_hints",
                "execute_restricted_base_graph",
                "sanitize_against_exact_current_window",
                "issue_policy_decision",
                "issue_strategic_trace",
                "seal_public_audit_result",
            ],
            profile["orchestration_contract"]["fixed_stage_order"],
        )
        self.assertFalse(profile["result_contract"]["serialized_result_is_execution_authority"])
        self.assertTrue(profile["scope"]["policy_orchestration"])
        self.assertTrue(profile["scope"]["strategic_trace_issuer"])
        self.assertFalse(profile["scope"]["time_budget_telemetry"])
        self.assertFalse(profile["scope"]["live_owner"])


if __name__ == "__main__":
    unittest.main()
