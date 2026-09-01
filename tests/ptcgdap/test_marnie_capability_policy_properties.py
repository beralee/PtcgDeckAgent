from __future__ import annotations

from copy import deepcopy
import unittest

from scripts.ai.ptcgdap.marnie_capability_policy import (
    MarnieCapabilityPolicy,
    MarnieCapabilityPolicyError,
)


class MarnieCapabilityPolicyPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = MarnieCapabilityPolicy.load_default()

    def test_every_index_result_is_legal_for_the_exact_bound_window(self) -> None:
        frames = self.policy.evaluate_all().to_public_dict()["frames"]
        parent = self.policy._parent_owner
        for decision in frames:
            with self.subTest(frame_id=decision["frame_id"]):
                self.assertFalse(decision["production_action_used"])
                self.assertFalse(decision["execution_authority"])
                indexes = decision["selected_indexes"]
                if indexes is None:
                    continue
                frame = parent.frame(decision["frame_id"])
                window = frame["window"]
                self.assertIsNotNone(window)
                self.assertEqual(decision["public_observation_hash"], frame["public_observation_hash"])
                self.assertEqual(decision["window_id"], window["window_id"])
                self.assertEqual(decision["option_fingerprints"], window["option_fingerprints"])
                self.assertEqual(len(indexes), len(set(indexes)))
                self.assertLessEqual(window["min_count"], len(indexes))
                self.assertLessEqual(len(indexes), window["max_count"])
                self.assertTrue(all(type(index) is int for index in indexes))
                self.assertTrue(all(0 <= index < len(window["options"]) for index in indexes))

    def test_mutations_and_stale_binding_fail_closed_without_private_echo(self) -> None:
        cases = (
            ("w4_spikemuth_deck", "public_observation_hash", "0" * 64),
            ("w4_spikemuth_deck", "window_id", "0" * 64),
            ("w4_spikemuth_deck", "option_fingerprints", []),
            ("w4_spikemuth_deck", "options", "reverse"),
            ("w4_spikemuth_deck", "min_count", 2),
        )
        for frame_id, field, value in cases:
            with self.subTest(field=field):
                self.assertEqual(
                    {"ok": False, "error_code": "frame_binding_mismatch", "value": None},
                    self.policy.probe_frame_mutation(frame_id, field, value),
                )
        private = self.policy.run(
            "probe_frame_mutation",
            {"frame_id": "w4_spikemuth_deck", "field": "private_sentinel", "value": "private_sentinel"},
        )
        self.assertEqual({"ok": False, "error_code": "input_type_invalid", "value": None}, private)
        self.assertNotIn("private_sentinel", repr(private))

    def test_internal_rebaseline_and_parent_substitution_fail_closed(self) -> None:
        mutations = (
            ("_runtime_integrity_sha256", "0" * 64),
            ("_policy", {}),
            ("_expected_frames", ()),
            ("_parent_owner", object()),
            ("_replay_owner", object()),
        )
        for field, value in mutations:
            with self.subTest(field=field):
                owner = MarnieCapabilityPolicy.load_default()
                object.__setattr__(owner, field, value)
                self.assertEqual(
                    {"ok": False, "error_code": "policy_integrity_invalid", "value": None},
                    owner.run("evaluate_all", {}),
                )
                with self.assertRaises(MarnieCapabilityPolicyError) as exc:
                    owner.audit_snapshot()
                self.assertEqual("policy_integrity_invalid", exc.exception.code)

    def test_results_are_deterministic_deep_copies_and_owner_scoped(self) -> None:
        first = self.policy.evaluate_all()
        second = self.policy.evaluate_all()
        self.assertEqual(first.to_public_dict(), second.to_public_dict())
        copy_value = first.to_public_dict()
        copy_value["frames"][4]["selected_indexes"] = [999]
        self.assertNotEqual(copy_value, first.to_public_dict())
        other = MarnieCapabilityPolicy.load_default()
        self.assertFalse(first.validate_integrity(other))
        decisions = first.to_public_dict()["frames"]
        self.assertIsNone(decisions[0]["previous_decision_hash"])
        for previous, current in zip(decisions, decisions[1:]):
            self.assertEqual(previous["decision_hash"], current["previous_decision_hash"])


if __name__ == "__main__":
    unittest.main()
