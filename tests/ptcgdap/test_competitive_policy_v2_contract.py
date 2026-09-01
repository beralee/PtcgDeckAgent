from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.competitive_policy_v2 import (
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class CompetitivePolicyV2ContractTests(unittest.TestCase):
    def test_contract_is_reproducible_and_keeps_official_boundary(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / "competitive_policy_v2.schema.json")
        profile = load_json_strict(CONTRACT_ROOT / "competitive_policy_v2_profile.json")
        bundle = load_json_strict(CONTRACT_ROOT / "competitive_policy_v2_bundle.json")
        Draft202012Validator.check_schema(schema)
        self.assertEqual("agent(raw_observation)->list[int]", profile["official_policy_boundary"])
        self.assertTrue(profile["compatibility"]["v1_behavior_unchanged"])
        self.assertFalse(profile["compatibility"]["classic_gdscript_fallback_for_package"])
        self.assertEqual(
            {"schema", "profile", "vectors"},
            {entry["id"] for entry in bundle["artifacts"]},
        )
        for entry in bundle["artifacts"]:
            self.assertEqual(
                entry["canonical_sha256"],
                _sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))),
            )
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_competitive_policy_v2_contract.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_python_runtime_replays_pinned_conformance_vectors(self) -> None:
        vectors = load_json_strict(
            CONTRACT_ROOT / "competitive_policy_v2_conformance_vectors.json"
        )
        for case in vectors["cases"]:
            with self.subTest(case=case["case_id"]):
                compiled = CompetitivePolicyV2Compiler.compile_local_uid(
                    copy.deepcopy(case["policy"]),
                    allowed_card_uids=set(case["allowed_card_uids"]),
                )
                if case["operation"] == "compile":
                    actual = {
                        "accepted": compiled.accepted,
                        "error_code": compiled.error_code,
                        "selected_indexes": [],
                    }
                else:
                    self.assertTrue(compiled.accepted, compiled.error_code)
                    decision = CompetitivePolicyV2Runtime.decide(
                        compiled.policy,
                        copy.deepcopy(case["frame"]),
                    )
                    actual = {
                        "accepted": decision.accepted,
                        "error_code": decision.error_code,
                        "selected_indexes": decision.selected_indexes,
                    }
                    if "audit_hash" in case["expected"]:
                        actual["audit_hash"] = decision.audit["audit_hash"]
                self.assertEqual(case["expected"], actual)


if __name__ == "__main__":
    unittest.main()
