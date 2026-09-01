from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"


class MarnieCapabilityPolicySchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(CONTRACT_ROOT / "marnie_capability_policy.schema.json")
        Draft202012Validator.check_schema(cls.schema)
        cls.validator = Draft202012Validator(cls.schema)
        cls.profile = load_json_strict(CONTRACT_ROOT / "marnie_capability_policy_profile.json")
        cls.policy = load_json_strict(DATA_ROOT / "marnie_capability_policy_v1.json")
        cls.vectors = load_json_strict(CONTRACT_ROOT / "marnie_capability_policy_conformance_vectors.json")
        cls.bundle = load_json_strict(CONTRACT_ROOT / "marnie_capability_policy_bundle.json")

    def assert_invalid(self, value: object) -> None:
        self.assertTrue(list(self.validator.iter_errors(value)))

    def test_all_bound_artifact_documents_validate(self) -> None:
        for value in (self.profile, self.policy, self.vectors, self.bundle):
            self.assertEqual([], list(self.validator.iter_errors(value)))

    def test_nested_policy_fields_are_closed_and_exact_typed(self) -> None:
        extra = deepcopy(self.policy)
        extra["rules"][0]["private_sentinel"] = "PRIVATE"
        self.assert_invalid(extra)
        unsafe = deepcopy(self.policy)
        unsafe["initial_deck_card_ids"][0] = 9007199254740992
        self.assert_invalid(unsafe)
        boolean = deepcopy(self.policy)
        boolean["rules"][4]["target_official_id"] = True
        self.assert_invalid(boolean)

    def test_vector_operation_input_and_result_relations_are_closed(self) -> None:
        wrong_input = deepcopy(self.vectors)
        wrong_input["cases"][0]["input"] = {}
        self.assert_invalid(wrong_input)
        private_value = deepcopy(self.vectors)
        private_value["cases"][0]["expected"]["value"]["frames"][0]["private_sentinel"] = "PRIVATE"
        self.assert_invalid(private_value)
        duplicate = deepcopy(self.vectors)
        frame = duplicate["cases"][1]["expected"]["value"]["frames"][0]
        frame["selected_indexes"] = [0, 0]
        self.assert_invalid(duplicate)

    def test_bundle_paths_are_exact_and_cannot_self_bind(self) -> None:
        self_cycle = deepcopy(self.bundle)
        self_cycle["artifacts"][0]["path"] = "contracts/ptcgdap/marnie_capability_policy_bundle.json"
        self.assert_invalid(self_cycle)
        extra = deepcopy(self.bundle)
        extra["artifacts"][0]["private_sentinel"] = "PRIVATE"
        self.assert_invalid(extra)


if __name__ == "__main__":
    unittest.main()
