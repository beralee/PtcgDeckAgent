from __future__ import annotations

import unittest

from scripts.ai.ptcgdap.a3_differential import TranscriptEngineAdapter, _hash
from scripts.ai.ptcgdap.a3_self_replay import EngineSelfReplayOwner


def checkpoint(ordinal: int, *, damage: int = 0, terminal: bool = False) -> dict:
    options = [] if terminal else [{"type": 3, "index": 0}]
    return {
        "source_lane": "test_fixture",
        "kind": "TERMINAL" if terminal else "SELECTION",
        "transition_ordinal": ordinal,
        "callback_ordinal": ordinal,
        "acting_seat": None if terminal else 0,
        "raw_actor_observation": None if terminal else {"public": ordinal},
        "raw_observation_hash": _hash(None if terminal else {"public": ordinal}),
        "window_handle": None if terminal else f"private-{ordinal}",
        "window_generation": None if terminal else ordinal + 1,
        "select": None if terminal else {"type": 1, "context": 25, "minCount": 1, "maxCount": 1},
        "ordered_options": options,
        "option_fingerprints": [_hash(option) for option in options],
        "incremental_logs": [],
        "public_snapshot": {"damage": damage, "terminal": terminal},
        "random_event_cursor": 0,
        "diagnostic_capability_mask": [],
    }


class A3SelfReplayTests(unittest.TestCase):
    def test_two_fresh_runs_are_hashed_and_must_match_exactly(self) -> None:
        transcript = [checkpoint(0), checkpoint(1, terminal=True)]
        receipt = EngineSelfReplayOwner.evaluate(
            lambda: TranscriptEngineAdapter("fixture", transcript),
            {"deck_pair": [1, 2]},
            [[0]],
            scope_sha256="A" * 64,
        )
        self.assertTrue(receipt["deterministic"])
        self.assertEqual(receipt["first_run_sha256"], receipt["second_run_sha256"])
        self.assertEqual(receipt["executed_selection_count"], 1)
        self.assertFalse(receipt["a3_promoted"])

    def test_state_drift_between_fresh_runs_fails_self_replay(self) -> None:
        created = 0

        def factory() -> TranscriptEngineAdapter:
            nonlocal created
            created += 1
            damage = 0 if created == 1 else 10
            return TranscriptEngineAdapter(
                "fixture", [checkpoint(0, damage=damage), checkpoint(1, terminal=True)],
            )

        receipt = EngineSelfReplayOwner.evaluate(
            factory, {}, [[0]], scope_sha256="A" * 64,
        )
        self.assertFalse(receipt["deterministic"])
        self.assertEqual(receipt["status"], "self_replay_mismatch")


if __name__ == "__main__":
    unittest.main()
