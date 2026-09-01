from __future__ import annotations

from pathlib import Path
import unittest

from scripts.ai.ptcgdap.observation_projector import GodotObservationProjector
from scripts.ai.ptcgdap.public_log_cursor import PublicLogCursor
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "contracts" / "ptcgdap" / "godot_observation_projector_conformance_vectors.json"


class ObservationProjectorTests(unittest.TestCase):
    def test_all_shared_w1_through_w7_vectors(self) -> None:
        vectors = load_json_strict(VECTORS)
        projector = GodotObservationProjector.load_default()
        self.assertEqual({case["window"] for case in vectors["projection_cases"]}, {"W1", "W2", "W3", "W4", "W5", "W6", "W7"})
        for case in vectors["projection_cases"]:
            with self.subTest(case=case["case_id"]):
                result = projector.project_conformance_case(vectors, case)
                self.assertTrue(result.accepted)
                self.assertEqual(result.to_conformance_summary(), case["expected_result"])
                self.assertTrue(result.validate_integrity())
                cursor = PublicLogCursor.load_default()
                log_slice = cursor.peek(result.firewall_result)
                self.assertEqual(log_slice.status, "slice_ready")
                self.assertEqual(log_slice.logs, result.observation["logs"])
                self.assertTrue(log_slice.validate_integrity(cursor))
                self.assertEqual(cursor.commit(log_slice).status, "committed")

    def test_rejection_vectors_fail_closed_without_private_echo(self) -> None:
        vectors = load_json_strict(VECTORS)
        projector = GodotObservationProjector.load_default()
        for case in vectors["rejection_cases"]:
            with self.subTest(case=case["case_id"]):
                result = projector.project_conformance_case(vectors, case)
                public = result.to_conformance_summary()
                self.assertEqual(public, case["expected_result"])
                self.assertNotIn("private_sentinel", repr(public))


if __name__ == "__main__":
    unittest.main()
