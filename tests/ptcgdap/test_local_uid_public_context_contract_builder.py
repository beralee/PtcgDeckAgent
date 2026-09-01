from __future__ import annotations

import copy
import hashlib
import subprocess
import sys
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_local_uid_public_context_contract import ARTIFACTS, PARENT_BUNDLE, artifacts


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class LocalUidPublicContextContractBuilderTests(unittest.TestCase):
    def test_builder_check_and_exact_parent_bundle(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_local_uid_public_context_contract.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        generated = artifacts()
        bundle = generated["local_uid_public_context_bundle.json"]
        self.assertEqual(PARENT_BUNDLE, bundle["parent_bundle_canonical_sha256"])
        self.assertEqual(
            [f"contracts/ptcgdap/{name}" for name in ARTIFACTS],
            [entry["path"] for entry in bundle["artifacts"]],
        )
        for entry in bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            self.assertEqual(
                hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper(),
                entry["canonical_sha256"],
            )

    def test_schema_accepts_owned_public_value_and_closes_hidden_surface(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / "local_uid_public_context.schema.json")
        vectors = load_json_strict(CONTRACT_ROOT / "local_uid_public_context_conformance_vectors.json")
        validator = Draft202012Validator(schema)
        validator.validate(vectors["accepted_case"]["value"])
        non_c_suffix = copy.deepcopy(vectors["accepted_case"]["value"])
        non_c_suffix["options"][0]["local_card_uid"] = "SVP_105"
        validator.validate(non_c_suffix)
        invalid_ids = {case["id"] for case in vectors["rejected_cases"]}
        self.assertEqual(
            {"unknown_uid", "serial_drift", "window_drift", "option_index_drift", "extra_opponent_hidden_field", "private_sentinel"},
            invalid_ids,
        )
        with self.assertRaises(Exception):
            validator.validate(next(case["value"] for case in vectors["rejected_cases"] if case["id"] == "extra_opponent_hidden_field"))
        profile = load_json_strict(CONTRACT_ROOT / "local_uid_public_context_profile.json")
        self.assertEqual("^[A-Za-z0-9.]+_[A-Za-z0-9]+$", profile["card_identity"]["syntax_pattern"])
        self.assertFalse(profile["card_identity"]["merge_with_official_card_id"])
        self.assertFalse(profile["binding_contract"]["opponent_hidden_identity_allowed"])
        self.assertFalse(profile["scope"]["player_live_authority"])


if __name__ == "__main__":
    unittest.main()
