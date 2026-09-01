from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "contracts/ptcgdap/marnie_prompt_broker.schema.json"
DOCUMENTS = (
    ROOT / "contracts/ptcgdap/marnie_prompt_broker_profile.json",
    ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json",
    ROOT / "contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json",
    ROOT / "contracts/ptcgdap/marnie_prompt_broker_bundle.json",
)


class MarniePromptBrokerSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(SCHEMA)
        Draft202012Validator.check_schema(cls.schema)
        cls.validator = Draft202012Validator(cls.schema)
        cls.audit = load_json_strict(DOCUMENTS[1])
        cls.vectors = load_json_strict(DOCUMENTS[2])
        cls.bundle = load_json_strict(DOCUMENTS[3])

    def assert_invalid(self, value: object) -> None:
        self.assertTrue(list(self.validator.iter_errors(value)))

    def test_every_bound_document_is_valid_under_draft_2020_12(self) -> None:
        for path in DOCUMENTS:
            with self.subTest(path=path.name):
                self.assertEqual([], list(self.validator.iter_errors(load_json_strict(path))))

    def test_nested_private_additive_and_unsafe_values_are_rejected(self) -> None:
        extra = deepcopy(self.audit)
        extra["frames"][3]["window"]["options"][0]["name"] = "private-sentinel"
        self.assert_invalid(extra)

        private = deepcopy(self.audit)
        private["expected_public_result"]["frames"][3]["private_engine_command"] = "private-sentinel"
        self.assert_invalid(private)

        unsafe = deepcopy(self.audit)
        unsafe["frames"][3]["window"]["options"][0]["inPlayIndex"] = 9_007_199_254_740_992
        self.assert_invalid(unsafe)

        duplicate = deepcopy(self.audit)
        duplicate["frames"][5]["expected_public_result"]["selected_indexes"] = [0, 0]
        self.assert_invalid(duplicate)

    def test_frame_order_and_terminal_relations_are_closed(self) -> None:
        reordered = deepcopy(self.audit)
        reordered["frames"][1], reordered["frames"][2] = reordered["frames"][2], reordered["frames"][1]
        self.assert_invalid(reordered)

        terminal_hash = deepcopy(self.audit)
        terminal_hash["frames"][-1]["public_observation_hash"] = "A" * 64
        self.assert_invalid(terminal_hash)

        missing_broker_window = deepcopy(self.audit)
        missing_broker_window["frames"][3]["window"] = None
        self.assert_invalid(missing_broker_window)

    def test_bundle_order_paths_and_self_cycle_are_closed(self) -> None:
        reordered = deepcopy(self.bundle)
        reordered["artifacts"][0], reordered["artifacts"][1] = reordered["artifacts"][1], reordered["artifacts"][0]
        self.assert_invalid(reordered)

        self_cycle = deepcopy(self.bundle)
        self_cycle["artifacts"][0]["path"] = "contracts/ptcgdap/marnie_prompt_broker_bundle.json"
        self.assert_invalid(self_cycle)

        extra = deepcopy(self.bundle)
        extra["artifacts"][0]["raw_sha256"] = "0" * 64
        self.assert_invalid(extra)

    def test_vector_result_shape_cannot_serialize_private_authority(self) -> None:
        private = deepcopy(self.vectors)
        private["cases"][0]["expected"]["value"]["private_resolutions"] = []
        self.assert_invalid(private)

        wrong_error = deepcopy(self.vectors)
        wrong_error["cases"][-1]["expected"]["error_code"] = "private-sentinel"
        self.assert_invalid(wrong_error)


if __name__ == "__main__":
    unittest.main()
