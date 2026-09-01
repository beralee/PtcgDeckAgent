from __future__ import annotations

import copy
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = load_json_strict(ROOT / "contracts/ptcgdap/marnie_public_base.schema.json")
PROFILE = load_json_strict(ROOT / "contracts/ptcgdap/marnie_public_base_profile.json")
VECTORS = load_json_strict(ROOT / "contracts/ptcgdap/marnie_public_base_conformance_vectors.json")
AUDIT = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json")
BUNDLE = load_json_strict(ROOT / "contracts/ptcgdap/marnie_public_base_bundle.json")


class MarniePublicBaseSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        Draft202012Validator.check_schema(SCHEMA)
        cls.validator = Draft202012Validator(SCHEMA)

    def assert_invalid(self, value: object) -> None:
        self.assertTrue(list(self.validator.iter_errors(value)))

    def test_all_bound_documents_validate(self) -> None:
        for label, value in (("profile", PROFILE), ("vectors", VECTORS), ("audit", AUDIT), ("bundle", BUNDLE)):
            with self.subTest(document=label):
                self.validator.validate(value)

    def test_profile_and_vector_inner_drift_is_rejected(self) -> None:
        profile = copy.deepcopy(PROFILE)
        profile["macro_catalog"][0]["official_card_ids"] = [999999]
        self.assert_invalid(profile)
        profile = copy.deepcopy(PROFILE)
        profile["authority_contract"]["serialized_results_are_authority"] = True
        self.assert_invalid(profile)
        vectors = copy.deepcopy(VECTORS)
        vectors["cases"][0]["expected"]["value"]["selected_indexes"] = [999999]
        self.assert_invalid(vectors)

    def test_audit_status_authority_and_chain_relations_are_closed(self) -> None:
        audit = copy.deepcopy(AUDIT)
        audit["cases"][0]["selected_indexes"] = [0, 0]
        self.assert_invalid(audit)
        audit = copy.deepcopy(AUDIT)
        audit["cases"][0]["public_observation_hash"] = "A" * 64
        self.assert_invalid(audit)
        audit = copy.deepcopy(AUDIT)
        audit["cases"][3]["reason_code"] = "terminal_no_callback"
        self.assert_invalid(audit)
        audit = copy.deepcopy(AUDIT)
        audit["cases"][13]["offline_seeded_extension"] = False
        self.assert_invalid(audit)
        audit = copy.deepcopy(AUDIT)
        audit["cases"][3]["authoritative"] = True
        self.assert_invalid(audit)

    def test_bundle_id_path_pairs_order_and_parent_are_closed(self) -> None:
        bundle = copy.deepcopy(BUNDLE)
        bundle["artifacts"][0]["path"] = bundle["artifacts"][1]["path"]
        self.assert_invalid(bundle)
        bundle = copy.deepcopy(BUNDLE)
        bundle["artifacts"].reverse()
        self.assert_invalid(bundle)
        bundle = copy.deepcopy(BUNDLE)
        bundle["parent_contract"]["canonical_sha256"] = "A" * 64
        self.assert_invalid(bundle)
        bundle = copy.deepcopy(BUNDLE)
        bundle["runtime_authority"] = "live"
        self.assert_invalid(bundle)


if __name__ == "__main__":
    unittest.main()
