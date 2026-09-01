from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_public_deck_adapter_contract import ARTIFACTS, artifacts


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class PublicDeckAdapterContractBuilderTests(unittest.TestCase):
    def test_builder_check_and_exact_bundle_bindings(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_public_deck_adapter_contract.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        generated = artifacts()
        bundle = generated["public_deck_adapter_bundle.json"]
        self.assertEqual("69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389", bundle["parent_bundle_canonical_sha256"])
        self.assertEqual(
            [f"contracts/ptcgdap/{name}" for name in ARTIFACTS],
            [entry["path"] for entry in bundle["artifacts"]],
        )
        for entry in bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            self.assertEqual(hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper(), entry["canonical_sha256"])

    def test_schema_validates_all_owned_documents_and_results(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / "public_deck_adapter.schema.json")
        vectors = load_json_strict(CONTRACT_ROOT / "public_deck_adapter_conformance_vectors.json")
        validator = Draft202012Validator(schema)
        for case in vectors["adapter_documents"]:
            validator.validate(case["document"])
            validator.validate(case["expected_adapter"])
        for case in vectors["proposal_cases"]:
            validator.validate(case["expected_result"])

    def test_contract_closes_private_and_arbitrary_behavior_surfaces(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "public_deck_adapter_profile.json")
        text = (CONTRACT_ROOT / "public_deck_adapter_conformance_vectors.json").read_text(encoding="utf-8")
        self.assertEqual(7, len(profile["adapter_contract"]["goal_stages"]))
        self.assertEqual(3, len(profile["adapter_contract"]["operators"]))
        self.assertEqual(7, len(profile["adapter_contract"]["predicate_fields"]))
        self.assertFalse(profile["result_contract"]["serialized_result_is_execution_authority"])
        for token in ("callable", "module", "class", "path", "url", "private_state", "display_name"):
            self.assertIn(token, profile["forbidden_fields"])
        for sentinel in ("PRIVATE_HAND_SENTINEL", "PRIVATE_SEARCH_SENTINEL", "PRIVATE_SESSION_SENTINEL"):
            self.assertIn(sentinel, text)


if __name__ == "__main__":
    unittest.main()
