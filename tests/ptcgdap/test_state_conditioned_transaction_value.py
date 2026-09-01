from __future__ import annotations

import copy
import json
import unittest

from scripts.ai.ptcgdap.state_conditioned_transaction_value import (
    StateConditionedTransactionValueV2,
)
from scripts.ai.ptcgdap.turn_program_generator import TurnProgramGenerator
from scripts.ai.ptcgdap.turn_program_planner import TurnProgramShadowPlanner
from tests.ptcgdap.test_turn_program_generator import (
    _candidate,
    _normalized_candidates,
    _option_fact,
    _semantic_step,
)
from tests.ptcgdap.test_turn_transaction_planner import _frame


SNORUNT = "CSV6C_052"
FROSLASS = "CSV6C_053"
IMPIDIMP = "M2_020"
MORGREM = "M2_021"
GRIMMSNARL = "M2_022"
MUNKIDORI = "TWM_095"
BUDEW = "PRE_004"
DARK_ENERGY = "SVE_007"
ENERGY_SEARCH = "CSVH1C_035"


def _slot(uid: str, serial: int, *, energy: int = 0, debt: int = 0) -> dict[str, object]:
    return {
        "serial": serial,
        "entity_serial": serial + 10_000,
        "local_card_uid": uid,
        "remaining_hp": 100,
        "max_hp": 100,
        "prize_value": 1,
        "attached_energy_count": energy,
        "attached_energy_uids": [DARK_ENERGY] * energy,
        "minimum_attack_energy_count": energy + debt,
        "attack_ready": debt == 0,
        "energy_debt": debt,
        "damage_counters": 0,
    }


def _model() -> dict[str, object]:
    model = StateConditionedTransactionValueV2.default_model(
        uid_roles={
            SNORUNT: ["froslass_basic"],
            FROSLASS: ["froslass_engine"],
            IMPIDIMP: ["grimmsnarl_basic"],
            MORGREM: ["punk_up_stage1"],
            GRIMMSNARL: ["grimmsnarl_engine"],
            MUNKIDORI: ["damage_engine"],
            BUDEW: ["early_stall"],
            DARK_ENERGY: ["energy"],
            ENERGY_SEARCH: ["energy_search"],
        },
        training_run_id="exam-state-value-v2",
    )
    model["fallback_value_model"]["feature_weights_milli"] = {
        key: 0 for key in model["fallback_value_model"]["feature_weights_milli"]
    }
    model["action_value_weights_milli"] = {
        "outcome.attack_pressure_milli": 1200,
    }
    model["interaction_weights_milli"] = {
        "self.hand.shortage_milli::outcome.disruption_milli": 9000,
        "self.hand.abundance_milli::outcome.disruption_milli": -9000,
        "opponent.hand.excess_milli::outcome.disruption_milli": 6000,
        "opponent.hand.shortage_milli::outcome.disruption_milli": -6000,
        "self.board.role.froslass_basic_milli::outcome.board_development_milli": 5000,
        "self.board.role.grimmsnarl_basic_milli::outcome.board_development_milli": 5000,
        "self.board.role.punk_up_stage1_milli::outcome.board_development_milli": -2500,
        "self.board.energy_debt_milli::outcome.board_development_milli": -2500,
        "self.board.role.damage_engine_milli::outcome.attack_pressure_milli": 3500,
        "self.board.role.early_stall_milli::outcome.board_development_milli": -3500,
        "turn.progress_milli::action.card.role.early_stall_milli": -12000,
        "turn.progress_milli::action.card.role.damage_engine_milli": 8000,
    }
    return model


def _disrupt_and_attack_candidates() -> list[dict[str, object]]:
    attack = _option_fact("attack", damage=180, knockout=False, prize_value=1, remaining_hp=100)
    disrupt = _candidate(
        "tx.disrupt-then-attack",
        [
            _semantic_step("disrupt-hand", "disruption"),
            _semantic_step(
                "attack-after-disruption",
                "attack",
                terminal_kind="attack",
                previous="disrupt-hand",
            ),
        ],
        current_facts=[_option_fact("play_trainer")],
        terminal_facts=[attack],
        priority=1000,
    )
    attack_now = _candidate(
        "base.attack-now",
        [_semantic_step("attack-now", "attack", terminal_kind="attack")],
        current_facts=[attack],
        terminal_facts=[attack],
        priority=1000,
        source_kind="base_terminal",
    )
    return [attack_now, disrupt]


class StateConditionedTransactionValueV2Test(unittest.TestCase):
    def test_encoder_uses_complete_public_context_and_uid_roles_not_deck_id(self) -> None:
        frame = _frame([], turn=6)
        frame["public_state"]["self"].update(
            {
                "hand": [
                    {"serial": 1, "local_card_uid": DARK_ENERGY},
                    {"serial": 2, "local_card_uid": SNORUNT},
                ],
                "active": [_slot(MUNKIDORI, 11, energy=1)],
                "bench": [_slot(SNORUNT, 12, debt=1), _slot(MORGREM, 13, debt=2)],
                "discard": [
                    {"serial": 30, "local_card_uid": FROSLASS},
                    {"serial": 31, "local_card_uid": DARK_ENERGY},
                ],
            }
        )
        frame["public_state"]["opponent"]["hand_count"] = 8
        frame["public_state"]["opponent"]["discard"] = [
            {"serial": 40, "local_card_uid": BUDEW}
        ]

        encoded = StateConditionedTransactionValueV2.encode_public_state(frame, _model())

        self.assertTrue(encoded["accepted"], encoded)
        features = encoded["features_milli"]
        self.assertGreater(features["self.hand.shortage_milli"], 0)
        self.assertGreater(features["opponent.hand.excess_milli"], 0)
        self.assertGreater(features["self.board.energy_debt_milli"], 0)
        self.assertGreater(features["self.board.role.froslass_basic_milli"], 0)
        self.assertGreater(features["self.board.role.punk_up_stage1_milli"], 0)
        self.assertGreater(features["self.discard.role.froslass_engine_milli"], 0)
        self.assertGreater(features["opponent.discard.role.early_stall_milli"], 0)
        self.assertEqual(1000, features["turn.manual_attachment_available_milli"])
        self.assertEqual(0, features["turn.manual_attachment_spent_milli"])
        self.assertNotIn("deck_id", json.dumps(encoded, sort_keys=True))

    def test_consumed_turn_resources_and_current_transaction_semantics_are_explicit(self) -> None:
        frame = _frame([], turn=5)
        frame["public_state"]["self"]["turn"] = {
            "supporter_available": False,
            "manual_attachment_available": False,
            "retreat_available": True,
        }
        fact = {
            **_option_fact("play_trainer"),
            "card_uid": ENERGY_SEARCH,
            "tags": ["item", "search"],
        }
        candidate = _candidate(
            "base.energy-search",
            [_semantic_step("energy-search", "search")],
            current_facts=[fact],
            terminal_facts=[],
            priority=1000,
            source_kind="base_action",
        )

        encoded = StateConditionedTransactionValueV2.encode_public_state(frame, _model())
        generated = TurnProgramGenerator.generate(frame, [candidate], value_model=_model())

        self.assertTrue(encoded["accepted"], encoded)
        self.assertEqual(1000, encoded["features_milli"]["turn.supporter_spent_milli"])
        self.assertEqual(1000, encoded["features_milli"]["turn.manual_attachment_spent_milli"])
        self.assertEqual(0, encoded["features_milli"]["turn.retreat_spent_milli"])
        self.assertTrue(generated["accepted"], generated)
        program = generated["request"]["programs"][0]
        self.assertEqual(["search"], program["public_action_context"]["current_effect_kinds"])
        self.assertEqual(["none"], program["public_action_context"]["current_resource_claims"])
        action = StateConditionedTransactionValueV2.action_features(
            program, program["public_outcome"], _model()
        )
        self.assertEqual(1000, action["program.current_effect.search_milli"])
        self.assertEqual(1000, action["program.current_resource.none_milli"])

    def test_private_oracle_fields_fail_closed(self) -> None:
        frame = _frame([], turn=4)
        frame["public_state"]["opponent"]["deck_order"] = ["secret"]

        encoded = StateConditionedTransactionValueV2.encode_public_state(frame, _model())

        self.assertFalse(encoded["accepted"])
        self.assertEqual("private_state_conditioned_value_input", encoded["error_code"])

    def test_same_legal_frontier_flips_disruption_rank_from_complete_public_state(self) -> None:
        low_hand = _frame([], turn=5)
        low_hand["public_state"]["self"]["hand"] = [
            {"serial": 1, "local_card_uid": DARK_ENERGY}
        ]
        low_hand["public_state"]["opponent"]["hand_count"] = 8
        rich_hand = copy.deepcopy(low_hand)
        rich_hand["public_state"]["self"]["hand"] = [
            {"serial": index + 1, "local_card_uid": DARK_ENERGY} for index in range(8)
        ]
        rich_hand["public_state"]["opponent"]["hand_count"] = 2
        candidates = _disrupt_and_attack_candidates()

        low_generated = TurnProgramGenerator.generate(
            low_hand, candidates, value_model=_model()
        )
        rich_generated = TurnProgramGenerator.generate(
            rich_hand, candidates, value_model=_model()
        )

        self.assertTrue(low_generated["accepted"], low_generated)
        self.assertTrue(rich_generated["accepted"], rich_generated)
        low = TurnProgramShadowPlanner.evaluate(low_hand, low_generated["request"])
        rich = TurnProgramShadowPlanner.evaluate(rich_hand, rich_generated["request"])
        self.assertEqual("tx.disrupt-then-attack", low["selected_program_id"])
        self.assertEqual("base.attack-now", rich["selected_program_id"])

    def test_engine_incomplete_board_raises_evolution_transaction_value(self) -> None:
        incomplete = _frame([], turn=4)
        incomplete["public_state"]["self"]["bench"] = [
            _slot(SNORUNT, 10, debt=1),
            _slot(IMPIDIMP, 11, debt=2),
        ]
        complete = copy.deepcopy(incomplete)
        complete["public_state"]["self"]["bench"] = [
            _slot(FROSLASS, 10, debt=1),
            _slot(GRIMMSNARL, 11, energy=2),
        ]
        candidates = _normalized_candidates()
        evolution_model = _model()
        evolution_model["interaction_weights_milli"] = {
            key: weight
            for key, weight in evolution_model["interaction_weights_milli"].items()
            if "hand." not in key
        }

        incomplete_result = TurnProgramGenerator.generate(
            incomplete, candidates, value_model=evolution_model
        )
        complete_result = TurnProgramGenerator.generate(
            complete, candidates, value_model=evolution_model
        )

        self.assertTrue(incomplete_result["accepted"], incomplete_result)
        self.assertTrue(complete_result["accepted"], complete_result)
        incomplete_ranking = TurnProgramShadowPlanner.evaluate(
            incomplete, incomplete_result["request"]
        )["ranked_program_ids"]
        complete_ranking = TurnProgramShadowPlanner.evaluate(
            complete, complete_result["request"]
        )["ranked_program_ids"]
        self.assertLess(
            incomplete_ranking.index("tx.complete-board-then-attack"),
            incomplete_ranking.index("base.attack-now"),
        )
        self.assertLess(
            complete_ranking.index("base.attack-now"),
            complete_ranking.index("tx.complete-board-then-attack"),
        )

    def test_late_budew_and_munkidori_are_distinguished_by_public_action_uid(self) -> None:
        frame = _frame([], turn=8)
        bench_fact = _option_fact("bench")
        budew_fact = {**bench_fact, "card_uid": BUDEW, "tags": ["bench"]}
        munkidori_fact = {
            **bench_fact,
            "card_uid": MUNKIDORI,
            "tags": ["bench"],
        }
        candidates = [
            _candidate(
                "base.bench-budew",
                [_semantic_step("bench-budew", "bench")],
                current_facts=[budew_fact],
                terminal_facts=[],
                priority=1000,
                source_kind="base_action",
            ),
            _candidate(
                "base.bench-munkidori",
                [_semantic_step("bench-munkidori", "bench")],
                current_facts=[munkidori_fact],
                terminal_facts=[],
                priority=1000,
                source_kind="base_action",
            ),
        ]

        generated = TurnProgramGenerator.generate(frame, candidates, value_model=_model())
        selected = TurnProgramShadowPlanner.evaluate(frame, generated["request"])

        self.assertTrue(generated["accepted"], generated)
        self.assertEqual("base.bench-munkidori", selected["selected_program_id"])
        contexts = {
            program["program_id"]: program["public_action_context"]
            for program in generated["request"]["programs"]
        }
        self.assertEqual([BUDEW], contexts["base.bench-budew"]["card_uids"])
        self.assertEqual([MUNKIDORI], contexts["base.bench-munkidori"]["card_uids"])


if __name__ == "__main__":
    unittest.main()
