from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.marnie_trajectory_replay import (
    MarnieTrajectoryReplay,
    MarnieTrajectoryReplayError,
)


ROOT = Path(__file__).resolve().parents[2]


class MarnieTrajectoryReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarnieTrajectoryReplay.load_default()

    def test_all_parent_frames_replay_in_order(self) -> None:
        result = self.owner.replay_all()
        self.assertTrue(result.validate_integrity(self.owner))
        payload = result.to_public_dict()
        self.assertTrue(payload["accepted"])
        self.assertEqual(13, len(payload["frames"]))
        self.assertEqual("w0_initial", payload["frames"][0]["frame_id"])
        self.assertEqual("w7_terminal", payload["frames"][-1]["frame_id"])
        self.assertTrue(all(frame["firewall_status"] == "accepted" for frame in payload["frames"][:-1]))
        self.assertEqual("not_applicable_terminal", payload["frames"][-1]["firewall_status"])

    def test_w2_is_exact_scoped_concealment_not_identity_reconstruction(self) -> None:
        payload = self.owner.replay_frame("w2_setup_bench").to_public_dict()
        self.assertTrue(payload["accepted"])
        frame = payload["frames"][0]
        self.assertEqual("setup_bench_concealment_v1", frame["compatibility_rule"])
        self.assertEqual("firewall_accepted", frame["public_hash_authority"])
        self.assertEqual([None], frame["own_active"])
        self.assertEqual(1, frame["option_count"])

    def test_scope_mutations_fail_closed(self) -> None:
        for field, value in (("select_type", 0), ("select_context", 1), ("turn", 1), ("own_active", [])):
            with self.subTest(field=field):
                result = self.owner.probe_w2_mutation(field, value)
                self.assertFalse(result["ok"])
                self.assertIn(result["error_code"], {"setup_concealment_scope_mismatch", "own_active_concealed"})

    def test_result_copy_and_mutation_never_gain_authority(self) -> None:
        result = self.owner.replay_frame("w2_setup_bench")
        copied = result.to_public_dict()
        copied["frames"][0]["own_active"] = [{"private": "sentinel"}]
        self.assertTrue(result.validate_integrity(self.owner))
        self.assertEqual([None], result.to_public_dict()["frames"][0]["own_active"])
        object.__setattr__(result, "_snapshot", deepcopy(copied))
        self.assertFalse(result.validate_integrity(self.owner))
        with self.assertRaises(MarnieTrajectoryReplayError) as caught:
            result.to_public_dict()
        self.assertEqual("result_integrity_invalid", caught.exception.code)


if __name__ == "__main__":
    unittest.main()
