from __future__ import annotations

from types import SimpleNamespace
import unittest

from scripts.ai.ptcgdap.a3_match_plan import A3MatchPlan, A3MatchPlanError


class A3MatchPlanTests(unittest.TestCase):
    def _plan(self) -> A3MatchPlan:
        return A3MatchPlan.build(
            official_deck0=[1] * 60,
            official_deck1=[1] * 60,
            private_deck0_entries=[{"set_code": "X", "card_index": "1", "count": 60}],
            private_deck1_entries=[{"set_code": "X", "card_index": "1", "count": 60}],
            relation_sha256="A" * 64,
            godot_seed=7,
        )

    def test_plan_locks_same_starting_player_setup_occurrence(self) -> None:
        plan = self._plan()
        checkpoint = SimpleNamespace(
            kind="SELECTION",
            acting_seat=1,
            select={"type": 9, "context": 41},
        )
        anchor = plan.resolved_operation_anchor(checkpoint)
        self.assertEqual(anchor["acting_seat"], 1)
        self.assertEqual(anchor["occurrence_ordinal"], 1)
        self.assertEqual(anchor["candidate_count"], 1)
        self.assertEqual(anchor["starting_player_choice_index"], 0)
        self.assertEqual(
            anchor["lifecycle_id"],
            "setup_active_after_starting_player_yes",
        )
        self.assertEqual(A3MatchPlan.parse(plan.to_private_dict()), plan)

    def test_anchor_or_hash_drift_fails_closed(self) -> None:
        value = self._plan().to_private_dict()
        value["operation_anchor"]["occurrence_ordinal"] = 2
        with self.assertRaises(A3MatchPlanError):
            A3MatchPlan.parse(value)
        value = self._plan().to_private_dict()
        value["plan_sha256"] = "B" * 64
        with self.assertRaises(A3MatchPlanError):
            A3MatchPlan.parse(value)


if __name__ == "__main__":
    unittest.main()
