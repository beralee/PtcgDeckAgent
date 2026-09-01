from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

from scripts.ai.ptcgdap.state_conditioned_transaction_value import (
    StateConditionedTransactionValueV2,
)
from tools.ptcgdap.train_state_conditioned_transaction_value import (
    MARNIE_UID_ROLES,
    _frame,
    _outcome,
    _program,
    build_authored_exam_preferences,
    extract_paired_branch_preferences,
    extract_trace_samples,
    fit_joint_model,
    preference_accuracy,
    split_paired_branch_preferences,
    select_validation_calibrated_model,
)


class StateConditionedValueTrainingTest(unittest.TestCase):
    def test_paired_branch_groups_are_disjoint_between_fit_and_selection(self) -> None:
        samples = [
            {"sample_id": f"sample-{offset}", "group_id": f"match-{offset // 2}"}
            for offset in range(10)
        ]

        training, validation, receipt = split_paired_branch_preferences(samples)

        training_groups = {sample["group_id"] for sample in training}
        validation_groups = {sample["group_id"] for sample in validation}
        self.assertTrue(training_groups)
        self.assertTrue(validation_groups)
        self.assertTrue(training_groups.isdisjoint(validation_groups))
        self.assertEqual(
            {sample["sample_id"] for sample in samples},
            {
                sample["sample_id"]
                for sample in [*training, *validation]
            },
        )
        self.assertEqual(sorted(training_groups), receipt["training_groups"])
        self.assertEqual(sorted(validation_groups), receipt["validation_groups"])
        self.assertTrue(receipt["group_disjoint"])

    def test_paired_branch_credit_labels_only_the_first_exact_public_divergence(self) -> None:
        model = StateConditionedTransactionValueV2.default_model(
            uid_roles=MARNIE_UID_ROLES,
            training_run_id="unit-paired-branch-credit-v1",
        )
        stadium = _program(
            "base.play_stadium.stadium",
            _outcome(board_development_milli=300),
            card_uid="CSV2C_127",
            effect_kind="ability",
        )
        stadium["public_action_context"]["kinds"] = ["play_stadium"]
        end_turn = _program(
            "base.end_turn.commit",
            _outcome(unresolved_debt_milli=250),
            terminal="end_turn",
            effect_kind="end_turn",
        )
        end_turn["public_action_context"]["kinds"] = ["end_turn"]

        def branch_decision(selected_index: int) -> dict[str, object]:
            frame = _frame(turn=2)
            frame["source"] = {
                "public_observation_hash": "B" * 64,
                "window_id": "C" * 64,
            }
            frame["options"] = [
                {"index": 0, "kind": "play_stadium", "card_uid": "CSV2C_127"},
                {"index": 1, "kind": "end_turn", "card_uid": None},
            ]
            return {
                "frame": frame,
                "host": {"accepted_indexes": [selected_index], "status": "accepted"},
                "policy": {
                    "reported_indexes": [selected_index],
                    "reported_public_observation_hash": frame["source"][
                        "public_observation_hash"
                    ],
                    "reported_window_id": frame["source"]["window_id"],
                    "base_result": {
                        "turn_program_generation": {
                            "accepted": True,
                            "request": {"programs": [stadium, end_turn]},
                        }
                    },
                },
            }

        def document(*, won: bool, selected_index: int) -> dict[str, object]:
            return {
                "capture_developer_trace": True,
                "is_clean": True,
                "games": 1,
                "candidate_wins": int(won),
                "opponent": {"archive_sha256": "D" * 64},
                "per_game": [
                    {
                        "candidate_seat": 1,
                        "winner_index": 1 if won else 0,
                        "seed": 991,
                        "terminal": True,
                        "candidate_developer_decisions": [
                            branch_decision(selected_index)
                        ],
                    }
                ],
            }

        with tempfile.TemporaryDirectory() as directory:
            win_path = Path(directory) / "winning.json"
            loss_path = Path(directory) / "losing.json"
            win_path.write_text(json.dumps(document(won=True, selected_index=0)))
            loss_path.write_text(json.dumps(document(won=False, selected_index=1)))
            preferences, receipt = extract_paired_branch_preferences(
                [(win_path, loss_path)], model
            )

        self.assertEqual(1, len(preferences))
        self.assertEqual("paired_branch_outcome_trace", preferences[0]["source"])
        self.assertEqual(3000, preferences[0]["weight_milli"])
        self.assertEqual(1, receipt["qualified_pair_count"])
        self.assertEqual(1, receipt["preference_count"])
        self.assertEqual("B" * 64, receipt["qualified_pairs"][0]["source_hash"])

    def test_validation_calibration_preserves_a_dominant_prior_instead_of_rewriting_it(self) -> None:
        seed_model = StateConditionedTransactionValueV2.default_model(
            uid_roles=MARNIE_UID_ROLES,
            training_run_id="unit-anchored-calibration-v3",
        )
        exams = build_authored_exam_preferences(seed_model)
        prior = fit_joint_model(
            seed_model,
            state_samples=[],
            preference_samples=exams,
            calibration_samples=exams,
            training_run_id="unit-prior-v2",
            dataset_sha256="A" * 64,
        )
        degraded = copy.deepcopy(prior)
        degraded["action_value_weights_milli"] = {
            name: -weight
            for name, weight in prior["action_value_weights_milli"].items()
        }

        selected, receipt = select_validation_calibrated_model(
            prior,
            degraded,
            authored_exams=exams,
            validation_preferences=exams,
            validation_states=[],
        )

        self.assertEqual("anchored_prior", receipt["selected_candidate"])
        self.assertEqual(
            prior["action_value_weights_milli"],
            selected["action_value_weights_milli"],
        )
        self.assertGreater(
            receipt["candidates"]["anchored_prior"]["validation_preference_accuracy"],
            receipt["candidates"]["fresh_refit"]["validation_preference_accuracy"],
        )

    def test_executed_canary_calibration_outranks_generic_validation(self) -> None:
        prior = StateConditionedTransactionValueV2.default_model(
            uid_roles=MARNIE_UID_ROLES,
            training_run_id="unit-canary-gate-prior-v1",
        )
        fresh = copy.deepcopy(prior)
        for candidate in (prior, fresh):
            candidate["fallback_value_model"]["feature_weights_milli"] = {
                name: 0
                for name in candidate["fallback_value_model"][
                    "feature_weights_milli"
                ]
            }
            candidate["action_value_weights_milli"] = {
                name: 0 for name in candidate["action_value_weights_milli"]
            }
            candidate["interaction_weights_milli"] = {
                name: 0 for name in candidate["interaction_weights_milli"]
            }
        prior["action_value_weights_milli"].update(
            {
                "program.current_effect.evolution_milli": -1000,
                "program.current_effect.attack_milli": 1000,
            }
        )
        fresh["action_value_weights_milli"].update(
            {
                "program.current_effect.evolution_milli": 1000,
                "program.current_effect.attack_milli": -1000,
            }
        )

        def preference(sample_id: str, action_feature: str) -> dict[str, object]:
            return {
                "sample_id": sample_id,
                "group_id": sample_id,
                "state_features_milli": {},
                "preferred_action_features_milli": {action_feature: 1000},
                "other_action_features_milli": {},
                "weight_milli": 1000,
            }

        selected, receipt = select_validation_calibrated_model(
            prior,
            fresh,
            authored_exams=[],
            executed_canary_exams=[
                preference(
                    "host-executed-winning-canary",
                    "program.current_effect.evolution_milli",
                )
            ],
            validation_preferences=[
                preference(
                    "generic-validation",
                    "program.current_effect.attack_milli",
                )
            ],
            validation_states=[],
        )

        self.assertEqual("fresh_refit", receipt["selected_candidate"])
        self.assertEqual(
            fresh["action_value_weights_milli"],
            selected["action_value_weights_milli"],
        )
        self.assertEqual(
            [
                "authored_exam_accuracy.desc",
                "paired_branch_exam_accuracy.desc",
                "executed_canary_exam_accuracy.desc",
                "validation_preference_accuracy.desc",
                "validation_state_sign_accuracy.desc",
                "interaction_feature_count.asc",
                "anchor_weight_drift_l1.asc",
            ],
            receipt["selection_order"],
        )

    def test_winning_preferences_require_exact_executed_shadow_agreement(self) -> None:
        model = StateConditionedTransactionValueV2.default_model(
            uid_roles=MARNIE_UID_ROLES,
            training_run_id="unit-executed-preference-v3",
        )
        preferred = _program(
            "preferred",
            _outcome(board_development_milli=600),
            effect_kind="evolution",
        )
        other = _program(
            "other",
            _outcome(attack_pressure_milli=300),
            effect_kind="attack",
        )

        def decision(
            sequence: int,
            matches_live: bool,
            *,
            canary_applied: bool = False,
            legacy_programs: bool = False,
        ) -> dict[str, object]:
            frame = _frame(turn=sequence)
            frame["source"] = {
                "public_observation_hash": f"{sequence:064X}",
                "window_id": f"{sequence + 100:064X}",
            }
            programs = copy.deepcopy([preferred, other])
            if legacy_programs:
                for program in programs:
                    program.pop("public_action_context", None)
            return {
                "frame": frame,
                "host": {"accepted_indexes": [0], "status": "accepted"},
                "policy": {
                    "reported_indexes": [0],
                    "reported_public_observation_hash": frame["source"][
                        "public_observation_hash"
                    ],
                    "reported_window_id": frame["source"]["window_id"],
                    "base_result": {
                        "owner_layer": (
                            "turn_program_canary" if canary_applied else "base_graph"
                        ),
                        "turn_program_generation": {
                            "accepted": True,
                            "request": {"programs": programs},
                        },
                        "turn_program_shadow": {
                            "accepted": True,
                            "selected_program_id": preferred["program_id"],
                        },
                        "turn_program_differential": {
                            "accepted": True,
                            "current_step_matches_live": matches_live,
                            "shadow_current_binding_found": True,
                            "public_only": True,
                        },
                        "turn_program_canary": {
                            "applied": canary_applied,
                            "authoritative": canary_applied,
                            "selected_program_id": (
                                preferred["program_id"] if canary_applied else None
                            ),
                        },
                    }
                },
            }

        document = {
            "capture_developer_trace": True,
            "is_clean": True,
            "games": 2,
            "candidate_wins": 1,
            "per_game": [
                {
                    "candidate_seat": 0,
                    "winner_index": 1,
                    "seed": 7,
                    "candidate_developer_decisions": [
                        decision(
                            3,
                            False,
                            canary_applied=True,
                            legacy_programs=True,
                        ),
                    ],
                },
                {
                    "candidate_seat": 0,
                    "winner_index": 0,
                    "seed": 7,
                    "candidate_developer_decisions": [
                        decision(1, False),
                        decision(2, True),
                        decision(3, False, canary_applied=True),
                    ],
                }
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            trace_path = Path(directory) / "trace.json"
            trace_path.write_text(json.dumps(document), encoding="utf-8")
            states, preferences, extraction = extract_trace_samples(
                [trace_path], model
            )

        self.assertEqual(4, len(states))
        self.assertEqual(2, len(preferences))
        self.assertEqual("winning_executed_trace", preferences[0]["source"])
        self.assertEqual(3, extraction["winning_shadow_window_count"])
        self.assertEqual(2, extraction["executed_preference_window_count"])
        self.assertEqual(1, extraction["canary_executed_preference_window_count"])
        self.assertEqual(1, extraction["shadow_mismatch_preference_window_count"])
        self.assertEqual(1, extraction["conflicting_outcome_observation_count"])
        canary_preference = next(
            row for row in preferences if row["sample_id"].startswith(f"{3:064X}")
        )
        self.assertEqual("winning_executed_canary_trace", canary_preference["source"])
        self.assertEqual(2000, canary_preference["weight_milli"])
        self.assertEqual(
            1000,
            canary_preference["preferred_action_features_milli"][
                "program.current_effect.evolution_milli"
            ],
        )

    def test_joint_training_exports_all_three_heads_and_locks_exams(self) -> None:
        seed_model = StateConditionedTransactionValueV2.default_model(
            uid_roles=MARNIE_UID_ROLES,
            training_run_id="unit-joint-training-v2",
        )
        preferences = build_authored_exam_preferences(seed_model)
        spent_attachment_exam = next(
            sample
            for sample in preferences
            if sample["sample_id"]
            == "exam-spent-attachment-energy-search-does-not-preempt-attack"
        )
        self.assertEqual(
            1000,
            spent_attachment_exam["state_features_milli"][
                "turn.manual_attachment_spent_milli"
            ],
        )
        self.assertNotEqual(
            spent_attachment_exam["preferred_action_features_milli"][
                "program.current_effect.attack_milli"
            ],
            spent_attachment_exam["other_action_features_milli"][
                "program.current_effect.attack_milli"
            ],
        )

        trained = fit_joint_model(
            seed_model,
            state_samples=[
                {
                    "group_id": "win-a",
                    "features_milli": preferences[0]["state_features_milli"],
                    "label_utility": 1_000_000,
                },
                {
                    "group_id": "loss-b",
                    "features_milli": preferences[1]["state_features_milli"],
                    "label_utility": -1_000_000,
                },
            ],
            preference_samples=preferences,
            training_run_id="unit-joint-training-v2",
            dataset_sha256="A" * 64,
        )

        self.assertIsNone(StateConditionedTransactionValueV2.model_error(trained))
        self.assertTrue(trained["state_value_weights_milli"])
        self.assertTrue(trained["action_value_weights_milli"])
        self.assertTrue(trained["interaction_weights_milli"])
        self.assertEqual(1.0, preference_accuracy(trained, preferences))
        self.assertGreaterEqual(
            trained["calibration"]["minimum_override_margin_utility"], 0
        )
        self.assertEqual(
            0,
            trained["calibration"]["minimum_override_margin_utility"] % 50_000,
        )
        payload = json.dumps(trained, sort_keys=True)
        self.assertNotIn("deck_id", payload)
        self.assertNotIn("source_deck_id", payload)

    def test_joint_training_distills_interactions_to_declared_budget(self) -> None:
        seed_model = StateConditionedTransactionValueV2.default_model(
            uid_roles=MARNIE_UID_ROLES,
            training_run_id="unit-sparse-interaction-v1",
        )
        preferences = build_authored_exam_preferences(seed_model)

        trained = fit_joint_model(
            seed_model,
            state_samples=[],
            preference_samples=preferences,
            calibration_samples=preferences,
            max_interaction_features=16,
            training_run_id="unit-sparse-interaction-v1",
            dataset_sha256="B" * 64,
        )

        self.assertLessEqual(len(trained["interaction_weights_milli"]), 16)
        self.assertEqual(1.0, preference_accuracy(trained, preferences))
        self.assertIsNone(StateConditionedTransactionValueV2.model_error(trained))


if __name__ == "__main__":
    unittest.main()
