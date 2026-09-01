from __future__ import annotations

import copy
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class MarnieTrajectoryReplaySchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(CONTRACT_ROOT / "marnie_trajectory_replay.schema.json")
        Draft202012Validator.check_schema(cls.schema)
        cls.validator = Draft202012Validator(cls.schema)
        cls.profile = load_json_strict(CONTRACT_ROOT / "marnie_trajectory_replay_profile.json")
        cls.vectors = load_json_strict(CONTRACT_ROOT / "marnie_trajectory_replay_conformance_vectors.json")
        cls.replay = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json")

    def test_all_bound_documents_validate(self) -> None:
        for document in (self.profile, self.vectors, self.replay):
            with self.subTest(kind=document["artifact_kind"]):
                self.validator.validate(document)

    def test_profile_scope_and_nested_private_fields_are_closed(self) -> None:
        mutations = []
        for path, value in (
            (("setup_bench_concealment", "turn"), 1),
            (("setup_bench_concealment", "own_active_exact"), []),
            (("replay", "production_actions_are_policy_goldens"), True),
        ):
            document = copy.deepcopy(self.profile)
            document[path[0]][path[1]] = value
            mutations.append(document)
        private_profile = copy.deepcopy(self.profile)
        private_profile["private_engine_state"] = "PRIVATE_SENTINEL"
        mutations.append(private_profile)
        private_frame = copy.deepcopy(self.replay)
        private_frame["frames"][2]["private_identity"] = {"card": "PRIVATE_SENTINEL"}
        mutations.append(private_frame)
        for index, document in enumerate(mutations):
            with self.subTest(index=index):
                self.assertFalse(self.validator.is_valid(document))

    def test_vectors_close_case_shape_result_shape_and_error_domain(self) -> None:
        mutations = []
        extra_case = copy.deepcopy(self.vectors)
        extra_case["cases"][0]["private"] = True
        mutations.append(extra_case)
        both_results = copy.deepcopy(self.vectors)
        both_results["cases"][0]["expected_error_code"] = "frame_unknown"
        mutations.append(both_results)
        private_error = copy.deepcopy(self.vectors)
        private_error["cases"][2]["expected"]["error_code"] = "PRIVATE_SENTINEL"
        mutations.append(private_error)
        private_result = copy.deepcopy(self.vectors)
        private_result["cases"][2]["expected"]["private"] = True
        mutations.append(private_result)
        for index, document in enumerate(mutations):
            with self.subTest(index=index):
                self.assertFalse(self.validator.is_valid(document))


if __name__ == "__main__":
    unittest.main()
