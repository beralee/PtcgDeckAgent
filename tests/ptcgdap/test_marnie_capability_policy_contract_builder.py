from __future__ import annotations

from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
BUILDER_PATH = ROOT / "tools/ptcgdap/build_marnie_capability_policy_contract.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class MarnieCapabilityPolicyBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location("p5_wp3_builder", BUILDER_PATH)
        if spec is None or spec.loader is None:
            raise AssertionError("builder import failed")
        cls.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.builder)

    def test_generated_documents_match_checked_in_bytes_and_parent_anchors(self) -> None:
        documents = self.builder.build_documents()
        for key, path in self.builder.output_paths().items():
            self.assertEqual(documents[key], load_json_strict(path))
        bundle = documents["bundle"]
        self.assertEqual(self.builder.PARENT_REPLAY_HASH, bundle["parent_replay_bundle"]["canonical_sha256"])
        self.assertEqual(self.builder.PARENT_FIXTURE_HASH, bundle["parent_fixture_bundle"]["canonical_sha256"])
        self.assertEqual(4, len(bundle["artifacts"]))
        self.assertEqual(13, len(documents["policy"]["rules"]))
        self.assertEqual(23, len(documents["vectors"]["cases"]))
        self.assertFalse(documents["policy"]["production_actions_used"])
        self.assertFalse(documents["policy"]["execution_authority"])

    def test_bundle_binds_every_artifact_without_hash_cycle(self) -> None:
        documents = self.builder.build_documents()
        bundle_hash = sha(canonical_json_v1_bytes(documents["bundle"]))
        for entry, (_, path, key) in zip(documents["bundle"]["artifacts"], self.builder.ARTIFACTS, strict=True):
            self.assertEqual(path, entry["path"])
            self.assertEqual(sha(canonical_json_v1_bytes(documents[key])), entry["canonical_sha256"])
            self.assertNotIn(bundle_hash, json.dumps(documents[key], sort_keys=True))

    def test_rule_or_source_mutation_changes_canonical_identity(self) -> None:
        documents = self.builder.build_documents()
        mutated = deepcopy(documents["policy"])
        mutated["rules"][4]["target_official_id"] = 647
        self.assertNotEqual(
            sha(canonical_json_v1_bytes(documents["policy"])),
            sha(canonical_json_v1_bytes(mutated)),
        )
        initial = documents["policy"]["initial_deck_card_ids"]
        self.assertEqual(60, len(initial))
        self.assertTrue(all(type(value) is int and value > 0 for value in initial))


if __name__ == "__main__":
    unittest.main()
