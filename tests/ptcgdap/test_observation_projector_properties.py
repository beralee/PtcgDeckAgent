from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.observation_projector import (
    GodotObservationProjector,
    ObservationProjectorError,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "contracts" / "ptcgdap" / "godot_observation_projector_conformance_vectors.json"


class ObservationProjectorPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vectors = load_json_strict(VECTORS)
        cls.projector = GodotObservationProjector.load_default()

    def _fixture(self, case_index: int = 0) -> dict[str, object]:
        case = self.vectors["projection_cases"][case_index]
        value = self.projector._materialize_case(self.vectors, case)
        self.assertIs(type(value), dict)
        return value

    def test_positive_allow_list_never_materializes_opponent_hand_identity(self) -> None:
        base = self.vectors["state_fixtures"]["base_mapped_state"]
        acting = base["acting_player_index"]
        self.assertIs(type(base["players"][acting]["hand"]), list)
        self.assertIsNone(base["players"][1 - acting]["hand"])
        hidden = copy.deepcopy(self._fixture())
        hidden["current_source"]["players"][1 - acting]["hand"] = [
            {"official_card_id": 1259, "serial": 62, "player_index": 1 - acting}
        ]
        result = self.projector.project_conformance_fixture(hidden)
        self.assertFalse(result.accepted)
        self.assertEqual(result.to_conformance_summary()["error_code"], "invalid_state")
        self.assertNotIn("1259", repr(result.to_conformance_summary()))

    def test_select_null_and_opponent_hidden_hand_coordinates_fail_closed(self) -> None:
        initial = copy.deepcopy(self._fixture())
        initial["select_source"] = None
        initial_result = self.projector.project_conformance_fixture(initial)
        self.assertFalse(initial_result.accepted)
        self.assertEqual(initial_result.to_conformance_summary()["error_code"], "firewall_rejected")

        hidden_coordinate = copy.deepcopy(self._fixture())
        hidden_coordinate["select_source"]["option"] = [
            {"type": 3, "area": 2, "index": 0, "playerIndex": 1}
        ]
        hidden_result = self.projector.project_conformance_fixture(hidden_coordinate)
        self.assertFalse(hidden_result.accepted)
        self.assertEqual(hidden_result.to_conformance_summary()["error_code"], "invalid_select")

    def test_public_event_order_changes_hash_and_unknown_fields_reject(self) -> None:
        fixture = copy.deepcopy(self._fixture(5))
        self.assertGreaterEqual(len(fixture["public_events"]), 2)
        first = self.projector.project_conformance_fixture(fixture)
        reordered = copy.deepcopy(fixture)
        reordered["public_events"] = list(reversed(reordered["public_events"]))
        second = self.projector.project_conformance_fixture(reordered)
        self.assertTrue(first.accepted)
        self.assertTrue(second.accepted)
        self.assertNotEqual(first.public_observation_hash, second.public_observation_hash)

        private = copy.deepcopy(fixture)
        private["public_events"][0]["private_sentinel"] = "must-not-echo"
        rejected = self.projector.project_conformance_fixture(private)
        self.assertFalse(rejected.accepted)
        self.assertEqual(rejected.to_conformance_summary()["error_code"], "invalid_public_event")
        self.assertNotIn("must-not-echo", repr(rejected.to_conformance_summary()))

    def test_cross_owner_attachment_preserves_physical_card_owner(self) -> None:
        fixture = copy.deepcopy(self._fixture())
        energy = fixture["current_source"]["players"][0]["active"][0]["attached_energy"][0]
        energy["player_index"] = 1
        result = self.projector.project_conformance_fixture(fixture)
        self.assertTrue(result.accepted)
        wire_energy = result.observation["current"]["players"][0]["active"][0]["energyCards"][0]
        self.assertEqual(wire_energy["playerIndex"], 1)

    def test_result_mutation_and_copied_dto_never_authorize(self) -> None:
        result = self.projector.project_conformance_case(
            self.vectors,
            self.vectors["projection_cases"][0],
        )
        copied = result.to_public_dict()
        self.assertIs(type(copied), dict)
        result._public_hash = "F" * 64
        self.assertFalse(result.validate_integrity())
        with self.assertRaisesRegex(ObservationProjectorError, "result_integrity_invalid"):
            result.to_public_dict()
        self.assertNotIn("_bound_input", json.dumps(copied, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
