from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools/ptcgdap/build_shadow_prompt_broker_contract.py"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
ARTIFACTS = {
    "schema": CONTRACT_ROOT / "shadow_prompt_broker.schema.json",
    "profile": CONTRACT_ROOT / "shadow_prompt_broker_profile.json",
    "vectors": CONTRACT_ROOT / "shadow_prompt_broker_conformance_vectors.json",
}
BUNDLE = CONTRACT_ROOT / "shadow_prompt_broker_bundle.json"


def digest(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


class ShadowPromptBrokerContractBuilderTests(unittest.TestCase):
    def test_builder_check_reproduces_four_artifacts(self) -> None:
        result = subprocess.run([sys.executable, str(BUILDER), "--check"], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_bundle_binds_exact_artifact_set_without_cycle(self) -> None:
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(bundle["contract_id"], "ptcgdap-shadow-prompt-broker-p3-wp5-v1")
        self.assertEqual(bundle["parent_executor_bundle_canonical_sha256"], "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92")
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        for entry in bundle["artifacts"]:
            self.assertEqual(Path(entry["path"]), ARTIFACTS[entry["id"]].relative_to(ROOT))
            self.assertEqual(entry["canonical_sha256"], digest(load_json_strict(ARTIFACTS[entry["id"]])))
        self.assertNotIn(digest(bundle), canonical_json_v1_bytes(bundle).decode("utf-8"))

    def test_profile_freezes_w1_w7_and_closed_lifecycle(self) -> None:
        profile = load_json_strict(ARTIFACTS["profile"])
        self.assertEqual(profile["prompt_families"], ["W1", "W2", "W3", "W4", "W5", "W6", "W7"])
        self.assertEqual(profile["states"], ["open", "prepared", "awaiting_reobserve", "aborted", "superseded"])
        self.assertFalse(profile["authority_contract"]["engine_method_invocation"])
        self.assertTrue(profile["authority_contract"]["strictly_newer_prompt_required_after_commit"])

    def test_vectors_cover_every_family_and_fault_class(self) -> None:
        vectors = load_json_strict(ARTIFACTS["vectors"])
        self.assertEqual([case["family"] for case in vectors["family_cases"]], ["W1", "W2", "W3", "W4", "W5", "W6", "W7"])
        ids = [case["case_id"] for section in ("family_cases", "lifecycle_cases") for case in vectors[section]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertGreaterEqual(len(vectors["lifecycle_cases"]), 10)


if __name__ == "__main__":
    unittest.main()
