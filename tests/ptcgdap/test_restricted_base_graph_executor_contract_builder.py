from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools/ptcgdap/build_restricted_base_graph_executor_contract.py"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
ARTIFACTS = (
    "restricted_base_graph_executor.schema.json",
    "restricted_base_graph_executor_profile.json",
    "restricted_base_graph_executor_conformance_vectors.json",
    "restricted_base_graph_executor_bundle.json",
)


class RestrictedBaseGraphExecutorContractBuilderTests(unittest.TestCase):
    def test_builder_check_reproduces_all_exact_artifacts(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        for name in ARTIFACTS:
            self.assertTrue((CONTRACT_ROOT / name).is_file(), name)

    def test_bundle_exactly_binds_three_artifacts_without_self_cycle(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / ARTIFACTS[-1])
        self.assertEqual("ptcgdap-restricted-base-graph-executor-p4-wp3-v1", bundle["bundle_id"])
        self.assertEqual(
            "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4",
            bundle["parent_bundle_canonical_sha256"],
        )
        self.assertEqual(list(ARTIFACTS[:3]), [Path(item["path"]).name for item in bundle["artifacts"]])
        self.assertNotIn(ARTIFACTS[-1], [Path(item["path"]).name for item in bundle["artifacts"]])
        for item in bundle["artifacts"]:
            value = load_json_strict(ROOT / item["path"])
            actual = hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()
            self.assertEqual(item["canonical_sha256"], actual)

    def test_profile_closes_authority_and_result_surface(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / ARTIFACTS[1])
        self.assertEqual("exact_current_p4_wp1_context_and_p4_wp2_ir_owner", profile["source_authority"])
        self.assertFalse(profile["result_contract"]["serialized_result_is_execution_authority"])
        self.assertEqual(
            ["terminal", "mandatory", "legal_frontier"],
            profile["execution_contract"]["selection_precedence"],
        )
        self.assertEqual(
            "same_tier_ordering_hint_only",
            profile["execution_contract"]["adapter_authority"],
        )
        self.assertIn("PRIVATE", profile["private_identifier_tokens_denied"])

    def test_vectors_cover_every_branch_and_rejection(self) -> None:
        vectors = load_json_strict(CONTRACT_ROOT / ARTIFACTS[2])
        success = vectors["execution_cases"]
        rejected = vectors["execution_rejections"]
        self.assertGreaterEqual(len(success), 8)
        self.assertGreaterEqual(len(rejected), 10)
        self.assertEqual(len(success), len({case["id"] for case in success}))
        self.assertEqual(len(rejected), len({case["id"] for case in rejected}))
        reasons = {case["expected_result"]["reason_code"] for case in success}
        self.assertTrue({"terminal_selection", "mandatory_selection", "deterministic_fallback"} <= reasons)
        errors = {case["expected_error_code"] for case in rejected}
        self.assertTrue({"invalid_context", "invalid_ir", "invalid_execution_input", "insufficient_candidates"} <= errors)

    def test_schema_accepts_owner_outputs_and_rejects_unsafe_or_open_shapes(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / ARTIFACTS[0])
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        vectors = load_json_strict(CONTRACT_ROOT / ARTIFACTS[2])
        for case in vectors["execution_cases"]:
            self.assertEqual([], list(validator.iter_errors(case["input"])), case["id"])
            self.assertEqual([], list(validator.iter_errors(case["expected_result"])), case["id"])
        valid = vectors["execution_cases"][0]["input"]
        malformed = dict(valid)
        malformed["private"] = "sentinel"
        self.assertTrue(list(validator.iter_errors(malformed)))
        malformed = __import__("copy").deepcopy(valid)
        malformed["mandatory_indexes"] = [0, 0]
        self.assertTrue(list(validator.iter_errors(malformed)))
        malformed = __import__("copy").deepcopy(valid)
        malformed["base_hard_tiers"][0]["tier"] = [9_007_199_254_740_992]
        self.assertTrue(list(validator.iter_errors(malformed)))
        malformed = __import__("copy").deepcopy(valid)
        malformed["execution_id"] = "PRIVATE-sentinel"
        self.assertTrue(list(validator.iter_errors(malformed)))


if __name__ == "__main__":
    unittest.main()
