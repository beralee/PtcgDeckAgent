from __future__ import annotations

import copy
import unittest

from scripts.ai.ptcgdap.turn_program_transition_evaluator import (
    TurnProgramOutcomeGate,
    TurnProgramTransitionEvaluator,
)
from tests.ptcgdap.test_turn_program_generator import (
    _candidate,
    _frame,
    _option_fact,
    _semantic_step,
)


class TurnProgramTransitionEvaluatorTest(unittest.TestCase):
    def test_rolls_forward_public_effects_without_private_state(self) -> None:
        frame = _frame([], turn=5)
        candidate = _candidate(
            "tx.complete-engine-then-attack",
            [
                _semantic_step("evolve-engine", "evolution"),
                _semantic_step(
                    "move-damage", "damage_transfer", previous="evolve-engine"
                ),
                _semantic_step(
                    "attack-after-engine",
                    "attack",
                    terminal_kind="attack",
                    previous="move-damage",
                ),
            ],
            current_facts=[_option_fact("evolve")],
            terminal_facts=[_option_fact("attack", damage=180)],
            priority=7200,
        )

        result = TurnProgramTransitionEvaluator.evaluate(
            frame, candidate, visible_debt_count=2
        )

        self.assertTrue(result["accepted"], result)
        self.assertTrue(result["public_only"])
        self.assertFalse(result["authoritative"])
        self.assertEqual(3, result["executed_prefix_length"])
        self.assertTrue(result["terminal_reached"])
        self.assertEqual(0, result["unresolved_dependency_count"])
        self.assertEqual(0, result["resource_conflict_count"])
        self.assertLessEqual(result["uncertainty_milli"], 400)
        self.assertTrue(result["commit_safe"])
        self.assertGreater(
            result["predicted_public_delta"]["board_development_milli"], 0
        )
        self.assertGreater(
            result["predicted_public_delta"]["attack_pressure_milli"], 0
        )
        self.assertNotIn("deck_order", repr(result))

    def test_double_supporter_claim_is_rejected_before_scoring(self) -> None:
        frame = _frame([], turn=5)
        candidate = _candidate(
            "tx.illegal-double-supporter",
            [
                _semantic_step("research", "draw"),
                _semantic_step("iono", "disruption", previous="research"),
                _semantic_step(
                    "attack",
                    "attack",
                    terminal_kind="attack",
                    previous="iono",
                ),
            ],
            current_facts=[_option_fact("play_trainer")],
            terminal_facts=[_option_fact("attack", damage=180)],
        )

        result = TurnProgramTransitionEvaluator.evaluate(
            frame, candidate, visible_debt_count=2
        )

        self.assertTrue(result["accepted"], result)
        self.assertEqual(1, result["resource_conflict_count"])
        self.assertFalse(result["commit_safe"])
        self.assertEqual("supporter", result["step_audit"][1]["resource_claim"])

    def test_unknown_generic_trainer_fails_closed_for_live_commit(self) -> None:
        frame = _frame([], turn=5)
        candidate = _candidate(
            "base.unknown-trainer",
            [_semantic_step("play-unknown", "search")],
            current_facts=[_option_fact("play_trainer")],
            terminal_facts=[],
            source_kind="base_action",
        )

        result = TurnProgramTransitionEvaluator.evaluate(
            frame, candidate, visible_debt_count=1
        )

        self.assertTrue(result["accepted"], result)
        self.assertGreaterEqual(result["uncertainty_milli"], 500)
        self.assertFalse(result["commit_safe"])
        self.assertEqual("unknown", result["step_audit"][0]["resource_claim"])

    def test_stale_source_cannot_be_labeled_or_reused(self) -> None:
        frame = _frame([], turn=5)
        next_frame = copy.deepcopy(frame)
        next_frame["source"] = copy.deepcopy(frame["source"])
        prediction = {
            "source": copy.deepcopy(frame["source"]),
            "program_id": "tx.evolve-before-attack",
            "effect_kind": "evolution",
            "expected_delta_milli": 320,
        }

        result = TurnProgramOutcomeGate.label(prediction, next_frame)

        self.assertFalse(result["accepted"])
        self.assertEqual("stale_transition_observation", result["error_code"])
        self.assertFalse(result["promotion_eligible"])

    def test_public_outcome_label_requires_repeated_confirmed_transitions(self) -> None:
        frame = _frame([], turn=5)
        prediction = {
            "source": copy.deepcopy(frame["source"]),
            "program_id": "tx.evolve-before-attack",
            "effect_kind": "evolution",
            "expected_delta_milli": 320,
        }
        labels = []
        for sequence in range(2, 10):
            observed = _frame([], turn=5)
            observed["sequence"] = sequence
            observed["source"] = {
                "public_observation_hash": ("%064X" % sequence),
                "window_id": ("%064X" % (sequence + 100)),
            }
            observed["public_state"]["self"]["bench"] = [
                {
                    "serial": sequence,
                    "local_card_uid": "CSV7C_059",
                    "remaining_hp": 140,
                    "prize_value": 1,
                    "attached_energy_count": 0,
                    "attached_energy_uids": [],
                    "minimum_attack_energy_count": 1,
                    "attack_ready": False,
                    "energy_debt": 1,
                }
            ]
            labels.append(TurnProgramOutcomeGate.label(prediction, observed))

        summary = TurnProgramOutcomeGate.summarize(labels)
        self.assertTrue(all(label["accepted"] for label in labels))
        self.assertEqual(8, summary["confirmed_count"])
        self.assertEqual(0, summary["contradicted_count"])
        self.assertTrue(summary["promotion_eligible"])
        self.assertFalse(summary["authoritative"])


if __name__ == "__main__":
    unittest.main()
