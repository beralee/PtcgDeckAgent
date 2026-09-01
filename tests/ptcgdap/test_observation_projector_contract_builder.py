from __future__ import annotations

import hashlib
import copy
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools" / "ptcgdap" / "build_observation_projector_contract.py"
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
BUNDLE = CONTRACT_ROOT / "godot_observation_projector_bundle.json"
SCHEMA = CONTRACT_ROOT / "godot_observation_projector.schema.json"
VECTORS = CONTRACT_ROOT / "godot_observation_projector_conformance_vectors.json"
EXPECTED_IDS = {
    "godot_observation_projector_schema_v1",
    "godot_observation_projector_profile_v1",
    "godot_observation_projector_conformance_v1",
}


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class ObservationProjectorContractBuilderTests(unittest.TestCase):
    def test_builder_check_and_exact_bundle_bindings(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(bundle["bundle_id"], "ptcgdap-godot-observation-projector-p2-wp5-v1")
        self.assertEqual(bundle["parent_cursor_bundle_canonical_sha256"], "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D")
        self.assertEqual(bundle["firewall_bundle_canonical_sha256"], "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947")
        self.assertEqual(bundle["catalog_bundle_canonical_sha256"], "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4")
        entries = bundle["artifacts"]
        self.assertEqual({entry["id"] for entry in entries}, EXPECTED_IDS)
        self.assertEqual(len(entries), 3)
        for entry in entries:
            path = ROOT / entry["path"]
            self.assertEqual(_sha(canonical_json_v1_bytes(load_json_strict(path))), entry["canonical_sha256"])

    def test_schema_closes_select_event_expected_and_hidden_hand_shapes(self) -> None:
        schema = load_json_strict(SCHEMA)
        vectors = load_json_strict(VECTORS)
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        self.assertEqual(list(validator.iter_errors(vectors)), [])

        mutations: list[dict[str, object]] = []
        private_event = copy.deepcopy(vectors)
        private_event["projection_cases"][2]["public_events"][0]["private_sentinel"] = "must-reject"
        mutations.append(private_event)
        option_extra = copy.deepcopy(vectors)
        option_extra["projection_cases"][0]["select_source"]["option"][0]["cardId"] = 646
        mutations.append(option_extra)
        unsafe_index = copy.deepcopy(vectors)
        unsafe_index["projection_cases"][0]["select_source"]["option"][0]["index"] = 9007199254740992
        mutations.append(unsafe_index)
        hidden_hand = copy.deepcopy(vectors)
        hidden_hand["state_fixtures"]["base_mapped_state"]["players"][1]["hand"] = "private"
        mutations.append(hidden_hand)
        incomplete_expected = copy.deepcopy(vectors)
        del incomplete_expected["projection_cases"][0]["expected_result"]["opponent_hand_hidden"]
        mutations.append(incomplete_expected)
        false_success = copy.deepcopy(vectors)
        false_success["projection_cases"][0]["expected_result"]["accepted"] = False
        mutations.append(false_success)
        for index, mutated in enumerate(mutations):
            with self.subTest(mutation=index):
                self.assertNotEqual(list(validator.iter_errors(mutated)), [])


if __name__ == "__main__":
    unittest.main()
