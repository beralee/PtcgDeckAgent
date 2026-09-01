from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

import jsonschema

from scripts.ai.ptcgdap.competitive_policy_v2 import (
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)
from scripts.ai.ptcgdap.state_conditioned_transaction_value import (
    StateConditionedTransactionValueV2,
)
from scripts.ai.ptcgdap.turn_program_generator import TurnProgramGenerator
from scripts.ai.ptcgdap.turn_program_planner import TurnProgramShadowPlanner
from scripts.ai.ptcgdap.turn_transaction_planner import TurnTransactionJournal
from tests.ptcgdap.test_turn_transaction_planner import (
    DARK,
    GRIMMSNARL,
    IONO,
    TM_EVOLUTION,
    _document,
    _frame,
    _option,
)


def _semantic_step(
    step_id: str,
    effect_kind: str,
    *,
    terminal_kind: str = "none",
    previous: str | None = None,
) -> dict[str, object]:
    return {
        "step_id": step_id,
        "transaction_id": "develop-before-attack",
        "method_id": "complete-board",
        "depends_on": [] if previous is None else [previous],
        "terminal_kind": terminal_kind,
        "effect_kind": effect_kind,
    }


def _option_fact(
    kind: str,
    *,
    damage: int | None = None,
    knockout: bool = False,
    prize_value: int | None = None,
    remaining_hp: int | None = None,
) -> dict[str, object]:
    return {
        "kind": kind,
        "projected_damage": damage,
        "projected_knockout": knockout,
        "target_remaining_hp": remaining_hp,
        "target_prize_value": prize_value,
    }


def _candidate(
    program_id: str,
    steps: list[dict[str, object]],
    *,
    current_facts: list[dict[str, object]],
    terminal_facts: list[dict[str, object]],
    priority: int = 1000,
    source_kind: str = "turn_transaction",
) -> dict[str, object]:
    first = steps[0]
    return {
        "program_id": program_id,
        "goal_id": "complete-board",
        "route_id": program_id,
        "deadline_turns": 0,
        "priority": priority,
        "source_kind": source_kind,
        "semantic_steps": steps,
        "current_step_id": first["step_id"],
        "current_option_facts": current_facts,
        "terminal_option_facts": terminal_facts,
        "base_proof": {
            "admissible": True,
            "current_step_executable": True,
            "mandatory_preserved": True,
            "terminal_preserved": True,
            "base_vetoed": False,
        },
    }


def _normalized_candidates(*, final_prize: bool = False) -> list[dict[str, object]]:
    attack = _option_fact(
        "attack",
        damage=180,
        knockout=final_prize,
        prize_value=1,
        remaining_hp=100,
    )
    full_turn = _candidate(
        "tx.complete-board-then-attack",
        [
            _semantic_step("evolve-two", "evolution"),
            _semantic_step("fill-board-energy", "energy", previous="evolve-two"),
            _semantic_step("move-damage", "damage_transfer", previous="fill-board-energy"),
            _semantic_step("disrupt-hand", "disruption", previous="move-damage"),
            _semantic_step(
                "attack-after-debt",
                "attack",
                terminal_kind="attack",
                previous="disrupt-hand",
            ),
        ],
        current_facts=[_option_fact("evolve")],
        terminal_facts=[attack],
        priority=7300,
    )
    premature = _candidate(
        "base.attack-now",
        [
            {
                **_semantic_step("attack-now", "attack", terminal_kind="attack"),
                "transaction_id": "base-terminal",
                "method_id": "current-attack",
            }
        ],
        current_facts=[attack],
        terminal_facts=[attack],
        source_kind="base_terminal",
    )
    optional_draw = _candidate(
        "route.optional-draw",
        [
            _semantic_step("draw-more", "draw"),
            _semantic_step(
                "attack-after-draw",
                "attack",
                terminal_kind="attack",
                previous="draw-more",
            ),
        ],
        current_facts=[_option_fact("play_trainer")],
        terminal_facts=[attack],
        priority=500,
        source_kind="turn_route",
    )
    return [premature, optional_draw, full_turn]


class TurnProgramGeneratorTest(unittest.TestCase):
    def test_language_neutral_generation_conformance_vectors(self) -> None:
        root = Path(__file__).resolve().parents[2]
        vectors = json.loads(
            (root / "contracts/ptcgdap/turn_program_generation_v1_conformance_vectors.json").read_text(
                encoding="utf-8"
            )
        )
        schema = json.loads(
            (root / "contracts/ptcgdap/turn_program_generation_v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        jsonschema.Draft202012Validator(schema).validate(vectors)
        for case in vectors["cases"]:
            generated = TurnProgramGenerator.generate(
                case["frame"], case["candidates"], max_programs=case["max_programs"]
            )
            expected = case["expected"]
            self.assertTrue(generated["accepted"], (case["case_id"], generated))
            self.assertEqual(expected["audit_hash"], generated["audit_hash"])
            self.assertEqual(expected["candidate_count"], generated["candidate_count"])
            self.assertEqual(expected["emitted_count"], generated["emitted_count"])
            self.assertEqual(
                expected["program_ids"],
                [row["program_id"] for row in generated["request"]["programs"]],
            )
            selected = TurnProgramShadowPlanner.evaluate(
                case["frame"], generated["request"]
            )
            for key in (
                "selected_program_id",
                "selected_current_step_id",
                "ranked_program_ids",
            ):
                self.assertEqual(expected[key], getattr(selected, key, selected[key]))

    def test_generated_public_outcomes_rank_full_turn_above_premature_attack(self) -> None:
        frame = _frame([], turn=5)
        generated = TurnProgramGenerator.generate(
            frame, _normalized_candidates(), max_programs=8
        )

        self.assertTrue(generated["accepted"], generated)
        self.assertEqual(3, generated["candidate_count"])
        self.assertEqual(3, generated["emitted_count"])
        request = generated["request"]
        self.assertEqual(frame["source"], request["source"])
        self.assertFalse(any("public_outcome" in row for row in _normalized_candidates()))

        result = TurnProgramShadowPlanner.evaluate(frame, request)
        self.assertTrue(result["accepted"], result)
        self.assertEqual("tx.complete-board-then-attack", result["selected_program_id"])
        self.assertEqual("evolve-two", result["selected_current_step_id"])
        self.assertEqual(
            [
                "tx.complete-board-then-attack",
                "route.optional-draw",
                "base.attack-now",
            ],
            result["ranked_program_ids"],
        )
        payload = json.dumps(generated, sort_keys=True)
        self.assertNotIn("selected_indexes", payload)
        self.assertNotIn("option_index", payload)

    def test_generation_records_public_transition_proof_for_every_candidate(self) -> None:
        frame = _frame([], turn=5)
        generated = TurnProgramGenerator.generate(
            frame, _normalized_candidates(), max_programs=8
        )

        self.assertTrue(generated["accepted"], generated)
        self.assertEqual(3, len(generated["candidate_audit"]))
        for row in generated["candidate_audit"]:
            transition = row["transition_evaluation"]
            self.assertTrue(transition["accepted"], transition)
            self.assertTrue(transition["public_only"])
            self.assertFalse(transition["authoritative"])
            self.assertEqual(row["program_id"], transition["program_id"])
            self.assertEqual(frame["source"], transition["source"])
            self.assertTrue(transition["audit_hash"])

    def test_language_neutral_value_model_is_injected_per_package_not_per_deck_id(self) -> None:
        frame = _frame([], turn=5)
        model = copy.deepcopy(
            TurnProgramGenerator.default_value_model()
        )
        model["model_version"] = 9
        model["feature_weights_milli"].update(
            {
                "prize_gain_milli": 0,
                "board_development_milli": 0,
                "attack_pressure_milli": 0,
                "next_turn_continuity_milli": 0,
                "hand_quality_milli": 0,
                "disruption_milli": 0,
                "resource_preservation_milli": 10000,
                "risk_milli": 0,
                "unresolved_debt_milli": 0,
            }
        )

        generated = TurnProgramGenerator.generate(
            frame,
            _normalized_candidates(),
            max_programs=8,
            value_model=model,
        )
        self.assertTrue(generated["accepted"], generated)
        self.assertEqual(model, generated["request"]["value_model"])
        selected = TurnProgramShadowPlanner.evaluate(frame, generated["request"])
        self.assertEqual("base.attack-now", selected["selected_program_id"])
        payload = json.dumps(generated, sort_keys=True)
        self.assertNotIn("deck_id", payload)
        self.assertNotIn("source_deck_id", payload)

    def test_generator_and_final_planner_share_exact_conditioned_utility(self) -> None:
        frame = _frame([], turn=5)
        model = StateConditionedTransactionValueV2.default_model(
            training_run_id="generator-planner-single-score-exam"
        )
        for name in model["fallback_value_model"]["feature_weights_milli"]:
            model["fallback_value_model"]["feature_weights_milli"][name] = 0
        model["action_value_weights_milli"] = {
            "program.current_effect.attack_milli": -500,
            "program.current_effect.disruption_milli": 1200,
            "program.current_effect.evolution_milli": 800,
        }

        generated = TurnProgramGenerator.generate(
            frame,
            _normalized_candidates(),
            max_programs=8,
            value_model=model,
        )
        self.assertTrue(generated["accepted"], generated)
        final = TurnProgramShadowPlanner.evaluate(frame, generated["request"])
        self.assertTrue(final["accepted"], final)

        generated_values = {
            row["program_id"]: (
                row["utility"],
                row["conditioned_value"]["action_feature_hash"],
            )
            for row in generated["candidate_audit"]
            if row["emitted"]
        }
        final_values = {
            row["program_id"]: (
                row["utility_milli"],
                row["conditioned_value"]["action_feature_hash"],
            )
            for row in final["candidate_audit"]
        }
        self.assertEqual(generated_values, final_values)
        self.assertGreater(
            generated_values["tx.complete-board-then-attack"][0],
            generated_values["base.attack-now"][0],
        )

    def test_final_prize_knockout_remains_a_hard_terminal_exception(self) -> None:
        frame = _frame([], turn=5)
        frame["public_state"]["self"]["prizes_remaining"] = 1
        generated = TurnProgramGenerator.generate(
            frame, _normalized_candidates(final_prize=True)
        )

        self.assertTrue(generated["accepted"], generated)
        result = TurnProgramShadowPlanner.evaluate(frame, generated["request"])
        self.assertEqual("base.attack-now", result["selected_program_id"])
        attack = next(
            row
            for row in generated["request"]["programs"]
            if row["program_id"] == "base.attack-now"
        )
        self.assertEqual(1, attack["public_outcome"]["final_prize_knockout"])

    def test_fresh_generation_recomputes_current_step_and_source(self) -> None:
        first = _frame([], turn=3)
        first_candidates = _normalized_candidates()
        first_generated = TurnProgramGenerator.generate(first, first_candidates)

        second = _frame([], turn=4)
        second_candidates = copy.deepcopy(first_candidates)
        full_turn = next(
            row
            for row in second_candidates
            if row["program_id"] == "tx.complete-board-then-attack"
        )
        full_turn["semantic_steps"] = full_turn["semantic_steps"][2:]
        full_turn["semantic_steps"][0]["depends_on"] = []
        full_turn["current_step_id"] = "move-damage"
        full_turn["current_option_facts"] = [_option_fact("use_ability")]
        second_generated = TurnProgramGenerator.generate(second, second_candidates)

        self.assertNotEqual(
            first_generated["request"]["source"], second_generated["request"]["source"]
        )
        second_result = TurnProgramShadowPlanner.evaluate(
            second, second_generated["request"]
        )
        self.assertEqual("move-damage", second_result["selected_current_step_id"])

    def test_automatic_shadow_integration_never_changes_live_selection(self) -> None:
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            _document(),
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        frame = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
                _option(2, "play_trainer", card_uid=TM_EVOLUTION),
            ]
        )
        baseline = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_transaction_journal=TurnTransactionJournal(
                "auto-shadow-baseline", 0, "test.package@1"
            ),
        )
        shadowed = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_transaction_journal=TurnTransactionJournal(
                "auto-shadow-enabled", 0, "test.package@1"
            ),
            auto_turn_program_shadow=True,
        )

        self.assertTrue(baseline.accepted, baseline.error_code)
        self.assertTrue(shadowed.accepted, shadowed.error_code)
        self.assertEqual([1], baseline.selected_indexes)
        self.assertEqual(baseline.selected_indexes, shadowed.selected_indexes)
        self.assertNotIn("turn_program_shadow", baseline.audit)
        self.assertTrue(shadowed.audit["turn_program_generation"]["accepted"])
        self.assertTrue(shadowed.audit["turn_program_shadow"]["accepted"])
        self.assertEqual(
            "tx.develop-before-attack.supporter-then-evolution",
            shadowed.audit["turn_program_shadow"]["selected_program_id"],
        )
        self.assertTrue(
            shadowed.audit["turn_program_differential"]["current_step_matches_live"]
        )
        self.assertFalse(shadowed.audit["turn_program_shadow"]["authoritative"])

    def test_automatic_shadow_includes_current_nonterminal_base_action(self) -> None:
        document = _document()
        document["rules"].append(
            {
                "rule_id": "fund-before-end",
                "goal_id": "core-online",
                "goal_stage": "fund",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 500000,
                "when": [{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None}],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document, allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION}
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        frame = _frame(
            [
                _option(0, "attach_energy", card_uid=DARK),
                _option(1, "end_turn"),
            ]
        )
        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy, frame, auto_turn_program_shadow=True
        )
        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual([0], decision.selected_indexes)
        shadow = decision.audit["turn_program_shadow"]
        self.assertTrue(shadow["selected_program_id"].startswith("base.attach_energy."))
        self.assertTrue(
            decision.audit["turn_program_differential"]["current_step_matches_live"]
        )

    def test_canary_rebinds_only_fresh_commit_safe_transaction_step(self) -> None:
        document = _document()
        document["rules"].append(
            {
                "rule_id": "fixture-premature-attack",
                "goal_id": "core-online",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 900000,
                "when": [
                    {
                        "fact": "option.kind",
                        "op": "eq",
                        "value": "attack",
                        "card_uid": None,
                    }
                ],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document, allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION}
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        frame = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
                _option(2, "play_trainer", card_uid=TM_EVOLUTION),
            ]
        )
        baseline = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)
        canary = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            auto_turn_program_shadow=True,
            turn_program_canary_profile={
                "profile_id": "ptcgdap-turn-program-canary-v1",
                "allowed_source_kinds": ["turn_transaction", "turn_route"],
                "allowed_current_effect_kinds": ["draw", "disruption", "evolution"],
                "max_uncertainty_milli": 400,
                "minimum_utility_margin": 1,
            },
        )

        self.assertEqual([0], baseline.selected_indexes)
        self.assertEqual([1], canary.selected_indexes)
        gate = canary.audit["turn_program_canary"]
        self.assertTrue(gate["accepted"], gate)
        self.assertTrue(gate["applied"], gate)
        self.assertTrue(gate["authoritative"])
        self.assertEqual("turn_program_shadow_final", gate["utility_source"])
        self.assertEqual(1, gate["minimum_utility_margin"])
        self.assertGreaterEqual(
            gate["selected_utility"], gate["live_utility"] + gate["minimum_utility_margin"]
        )
        self.assertEqual("turn_program_canary", canary.audit["owner_layer"])
        self.assertTrue(canary.audit["turn_program_shadow"]["reobserve_before_execution"])
        self.assertFalse(canary.audit["stale_plan_has_authority"])

    def test_canary_fails_closed_for_unknown_base_action(self) -> None:
        document = _document()
        document["rules"].append(
            {
                "rule_id": "fixture-premature-attack",
                "goal_id": "core-online",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 900000,
                "when": [
                    {
                        "fact": "option.kind",
                        "op": "eq",
                        "value": "attack",
                        "card_uid": None,
                    }
                ],
                "score_terms": [],
            }
        )
        document["turn_transactions"] = []
        document["turn_routes"] = []
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document, allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION}
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        frame = _frame(
            [
                _option(0, "attack", damage=0),
                _option(1, "play_trainer", card_uid=IONO),
            ]
        )
        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            auto_turn_program_shadow=True,
            turn_program_canary_profile={
                "profile_id": "ptcgdap-turn-program-canary-v1",
                "allowed_source_kinds": ["base_action"],
                "allowed_current_effect_kinds": ["search"],
                "max_uncertainty_milli": 400,
                "minimum_utility_margin": 1,
            },
        )

        self.assertEqual([0], decision.selected_indexes)
        gate = decision.audit["turn_program_canary"]
        self.assertTrue(gate["accepted"], gate)
        self.assertFalse(gate["applied"])
        self.assertEqual("transition_not_commit_safe", gate["reason"])

    def test_public_action_semantics_admits_known_supporter_without_deck_id(self) -> None:
        document = _document()
        document["turn_transactions"] = []
        document["turn_routes"] = []
        document["rules"].append(
            {
                "rule_id": "fixture-premature-attack",
                "goal_id": "core-online",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 900000,
                "when": [{"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": None}],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document, allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION}
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        frame = _frame([
            _option(0, "attack", damage=0),
            _option(1, "play_trainer", card_uid=IONO),
        ])
        semantics = {
            "profile_id": "ptcgdap-turn-program-action-semantics-v1",
            "uid_effect_kinds": {IONO: "disruption"},
            "uid_resource_claims": {IONO: "supporter"},
        }
        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            auto_turn_program_shadow=True,
            turn_program_canary_profile={
                "profile_id": "ptcgdap-turn-program-canary-v1",
                "allowed_source_kinds": ["base_action"],
                "allowed_current_effect_kinds": ["disruption"],
                "max_uncertainty_milli": 400,
                "minimum_utility_margin": 1,
            },
            turn_program_action_semantics=semantics,
        )

        self.assertEqual([1], decision.selected_indexes)
        gate = decision.audit["turn_program_canary"]
        self.assertTrue(gate["applied"], gate)
        selected_program = gate["selected_program_id"]
        selected_row = next(
            row for row in decision.audit["turn_program_generation"]["candidate_audit"]
            if row["program_id"] == selected_program
        )
        self.assertEqual("disruption", selected_row["transition_evaluation"]["step_audit"][0]["effect_kind"])
        self.assertEqual("supporter", selected_row["transition_evaluation"]["step_audit"][0]["resource_claim"])
        self.assertNotIn("deck_id", str(decision.audit))

        unavailable = copy.deepcopy(frame)
        unavailable["source"]["window_id"] = "D" * 64
        unavailable["public_state"]["self"]["turn"]["supporter_available"] = False
        blocked = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            unavailable,
            auto_turn_program_shadow=True,
            turn_program_canary_profile={
                "profile_id": "ptcgdap-turn-program-canary-v1",
                "allowed_source_kinds": ["base_action"],
                "allowed_current_effect_kinds": ["disruption"],
                "max_uncertainty_milli": 400,
                "minimum_utility_margin": 1,
            },
            turn_program_action_semantics=semantics,
        )
        self.assertEqual([0], blocked.selected_indexes)
        self.assertEqual("transition_not_commit_safe", blocked.audit["turn_program_canary"]["reason"])

        guarded_semantics = copy.deepcopy(semantics)
        guarded_semantics["uid_public_guards"] = {
            IONO: {
                "mode": "any",
                "max_own_hand_count": 4,
                "min_opponent_hand_count": 5,
            }
        }
        healthy_hand = copy.deepcopy(frame)
        healthy_hand["source"]["window_id"] = "E" * 64
        healthy_hand["public_state"]["self"]["hand"] = [
            {"serial": 10 + offset, "local_card_uid": TM_EVOLUTION}
            for offset in range(6)
        ]
        healthy_hand["public_state"]["opponent"]["hand_count"] = 2
        guarded = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            healthy_hand,
            auto_turn_program_shadow=True,
            turn_program_canary_profile={
                "profile_id": "ptcgdap-turn-program-canary-v1",
                "allowed_source_kinds": ["base_action"],
                "allowed_current_effect_kinds": ["disruption"],
                "max_uncertainty_milli": 400,
                "minimum_utility_margin": 1,
            },
            turn_program_action_semantics=guarded_semantics,
        )
        self.assertEqual([0], guarded.selected_indexes)
        self.assertEqual(
            "public_precondition_not_met",
            guarded.audit["turn_program_canary"]["reason"],
        )

    def test_public_active_prize_value_proves_current_final_knockout(self) -> None:
        document = _document()
        document["rules"].append(
            {
                "rule_id": "prefer-attachment-fixture",
                "goal_id": "core-online",
                "goal_stage": "fund",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 500000,
                "when": [{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None}],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document, allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION}
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        attack = _option(0, "attack", damage=320)
        attack["projected_knockout"] = True
        frame = _frame(
            [attack, _option(1, "attach_energy", card_uid=DARK)]
        )
        frame["public_state"]["self"]["prizes_remaining"] = 2
        frame["public_state"]["opponent"]["active"] = [
            {
                "serial": 77,
                "local_card_uid": GRIMMSNARL,
                "remaining_hp": 200,
                "prize_value": 2,
                "attached_energy_count": 0,
                "attached_energy_uids": [],
                "minimum_attack_energy_count": 0,
                "attack_ready": True,
                "energy_debt": 0,
            }
        ]
        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy, frame, auto_turn_program_shadow=True
        )
        shadow = decision.audit["turn_program_shadow"]
        self.assertTrue(shadow["selected_program_id"].startswith("base.attack."))
        attack_program = next(
            row
            for row in decision.audit["turn_program_generation"]["request"]["programs"]
            if row["program_id"] == shadow["selected_program_id"]
        )
        self.assertEqual(1, attack_program["public_outcome"]["final_prize_knockout"])


if __name__ == "__main__":
    unittest.main()
