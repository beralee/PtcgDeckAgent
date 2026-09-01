from __future__ import annotations

from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
BUILDER_PATH = ROOT / "tools/ptcgdap/build_marnie_identity_projection_contract.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class MarnieIdentityProjectionBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location("p5_wp4_builder", BUILDER_PATH)
        if spec is None or spec.loader is None:
            raise AssertionError("builder import failed")
        cls.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.builder)

    def test_generated_documents_match_checked_in_bytes_and_locked_parents(self) -> None:
        documents = self.builder.build_documents()
        for key, path in self.builder.output_paths().items():
            self.assertEqual(documents[key], load_json_strict(path))
        profile = documents["profile"]
        self.assertEqual(self.builder.PARENT_FIXTURE_HASH, profile["parent_fixture_bundle_canonical_sha256"])
        self.assertEqual(self.builder.PARENT_POLICY_HASH, profile["parent_capability_policy_bundle_canonical_sha256"])
        self.assertEqual(self.builder.CATALOG_HASH, profile["card_catalog_bundle_canonical_sha256"])
        self.assertEqual(self.builder.PROJECTOR_HASH, profile["projector_bundle_canonical_sha256"])
        self.assertFalse(profile["execution_authority"])
        self.assertFalse(profile["production_actions_used"])

    def test_source_frame_audit_has_exact_identity_and_mapping_relations(self) -> None:
        audit = self.builder.build_documents()["audit"]
        self.assertEqual(13, len(audit["frames"]))
        summary = audit["summary"]
        self.assertEqual(12, summary["public_frame_count"])
        self.assertEqual(573, summary["identity_occurrence_count"])
        self.assertEqual(94, summary["cross_frame_unique_serial_count"])
        self.assertEqual(34, len(summary["distinct_official_card_ids"]))
        self.assertEqual(9, len(summary["mapped_official_card_ids"]))
        self.assertEqual(25, len(summary["known_unmapped_official_card_ids"]))
        self.assertEqual([937, 1240], summary["official_attack_ids"])
        self.assertTrue(summary["cross_frame_serial_relation_consistent"])
        self.assertTrue(summary["hidden_identity_absent"])
        self.assertTrue(summary["host_entity_absent"])
        self.assertEqual(19, summary["official_deck_unique_card_id_count"])
        self.assertEqual(9, summary["official_deck_mapped_unique_card_id_count"])
        self.assertEqual(10, summary["official_deck_known_unmapped_unique_card_id_count"])
        self.assertEqual(34, summary["official_deck_mapped_card_count"])
        self.assertEqual(26, summary["official_deck_known_unmapped_card_count"])

    def test_bundle_binds_exact_artifacts_without_hash_cycle(self) -> None:
        documents = self.builder.build_documents()
        bundle_hash = sha(canonical_json_v1_bytes(documents["bundle"]))
        self.assertEqual(4, len(documents["bundle"]["artifacts"]))
        for entry, (_, path, key) in zip(documents["bundle"]["artifacts"], self.builder.ARTIFACTS, strict=True):
            self.assertEqual(path, entry["path"])
            self.assertEqual(sha(canonical_json_v1_bytes(documents[key])), entry["canonical_sha256"])
            self.assertNotIn(bundle_hash, json.dumps(documents[key], sort_keys=True))

    def test_mutation_changes_identity_and_check_mode_is_clean(self) -> None:
        documents = self.builder.build_documents()
        mutated = deepcopy(documents["audit"])
        mutated["frames"][1]["mapped_official_card_ids"][0] = 104
        self.assertNotEqual(
            sha(canonical_json_v1_bytes(documents["audit"])),
            sha(canonical_json_v1_bytes(mutated)),
        )
        result = subprocess.run(
            [sys.executable, str(BUILDER_PATH), "--check"], cwd=ROOT,
            check=False, capture_output=True, text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
