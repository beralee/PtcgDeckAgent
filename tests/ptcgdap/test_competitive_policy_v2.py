from __future__ import annotations

import copy
import unittest

from scripts.ai.ptcgdap.competitive_policy_v2 import (
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)


DARK = "SVI_003"
GRASS = "SVE_001"
FIGHTING = "SVE_002"
LIGHTNING = "SVE_003"
GRIMMSNARL = "M2_001"
MORGREM = "M2_002"
IMPIDIMP = "M2_003"
MUNKIDORI = "TWM_095"
NIGHT_STRETCHER = "SFA_061"


def _card(serial: int, uid: str) -> dict[str, object]:
    return {"serial": serial, "local_card_uid": uid}


def _slot(
    serial: int,
    uid: str,
    *,
    energy: int,
    required: int,
    prizes: int,
) -> dict[str, object]:
    return {
        "serial": serial,
        "local_card_uid": uid,
        "remaining_hp": 280,
        "prize_value": prizes,
        "attached_energy_count": energy,
        "attached_energy_uids": [DARK] * energy,
        "minimum_attack_energy_count": required,
        "attack_ready": energy >= required,
        "energy_debt": max(0, required - energy),
    }


def _option(index: int, kind: str, **updates: object) -> dict[str, object]:
    value: dict[str, object] = {
        "index": index,
        "kind": kind,
        "card_uid": None,
        "card_serial": None,
        "source_uid": None,
        "source_serial": None,
        "target_uid": None,
        "target_serial": None,
        "target_remaining_hp": None,
        "target_prize_value": None,
        "target_attached_energy_count": None,
        "target_attached_energy_uids": None,
        "target_minimum_attack_energy_count": None,
        "target_attack_ready": None,
        "target_energy_debt": None,
        "projected_damage": None,
        "projected_knockout": False,
        "requires_interaction": False,
        "attack_index": None,
        "option_number": None,
        "ability_index": None,
        "energy_type_raw": None,
        "energy_count": None,
        "special_condition_type": None,
        "pending_assignment_count": 0,
        "tags": [],
        "option_type_raw": 3,
        "option_player_index": 0,
    }
    value.update(updates)
    kind_to_type = {
        "attack": 13,
        "attach_energy": 8,
        "end_turn": 14,
        "play_card": 7,
        "play_trainer": 7,
    }
    value["option_type_raw"] = kind_to_type.get(kind, 3)
    value["card_serial"] = 1000 + index if value["card_uid"] is not None else None
    if value["source_uid"] is not None and value["source_serial"] is None:
        value["source_serial"] = 2000 + index
    if value["target_uid"] is not None and value["target_serial"] is None:
        value["target_serial"] = 3000 + index
    if value["option_type_raw"] == 3 and value["card_uid"] is None and value["target_uid"] is not None:
        value["card_uid"] = value["target_uid"]
        value["card_serial"] = value["target_serial"]
    return value


def _frame(
    options: list[dict[str, object]],
    *,
    prompt_kind: str,
    minimum: int,
    maximum: int,
    active: list[dict[str, object]] | None = None,
    bench: list[dict[str, object]] | None = None,
    opponent_prizes: int = 6,
    select_type_raw: int = 1,
    select_context_raw: int = 0,
) -> dict[str, object]:
    return {
        "schema_version": 2,
        "profile_id": "ptcgdap-competitive-public-frame-v2",
        "sequence": 1,
        "seat": 0,
        "prompt_kind": prompt_kind,
        "source": {
            "public_observation_hash": "A" * 64,
            "window_id": "B" * 64,
        },
        "public_state": {
            "turn_number": 10,
            "phase": "MAIN",
            "self": {
                "hand": [_card(1, DARK)],
                "active": active or [],
                "bench": bench or [],
                "discard": [],
                "deck_count": 30,
                "prizes_remaining": 4,
            },
            "opponent": {
                "hand_count": 5,
                "active": [],
                "bench": [],
                "discard": [],
                "deck_count": 28,
                "prizes_remaining": opponent_prizes,
            },
        },
        "select_semantics": {
            "min_count": minimum,
            "max_count": maximum,
            "select_type_raw": select_type_raw,
            "select_context_raw": select_context_raw,
        },
        "options": options,
    }


def _policy() -> dict[str, object]:
    return {
        "schema_version": 2,
        "adapter_id": "test.marnie.competitive-v2",
        "adapter_version": 2,
        "goals": [
            {
                "goal_id": "two-ready-grimmsnarl",
                "stage": "fund",
                "priority": 100,
                "requirements": [
                    {
                        "card_uid": GRIMMSNARL,
                        "ready_target_count": 2,
                        "energy_required": 2,
                    },
                    {
                        "card_uid": MORGREM,
                        "ready_target_count": 2,
                        "energy_required": 2,
                    },
                ],
            }
        ],
        "count_rules": [
            {
                "rule_id": "punk-up.exact-public-debt",
                "priority": 0,
                "goal_id": "two-ready-grimmsnarl",
                "mode": "goal_energy_debt",
                "fixed_count": None,
                "fact": None,
                "divisor": None,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None}
                ],
            }
        ],
        "rules": [
            {
                "rule_id": "punk-up.dark-energy",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [
                    {"fact": "option.card_uid", "op": "eq", "value": DARK, "card_uid": None}
                ],
                "score_terms": [],
            },
            {
                "rule_id": "assignment.highest-debt",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 0,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "assignment_target", "card_uid": None}
                ],
                "score_terms": [
                    {
                        "fact": "option.target_energy_debt",
                        "coefficient": 100,
                        "minimum": 0,
                        "maximum": 10,
                    }
                ],
            },
            {
                "rule_id": "send-out.avoid-final-two-prize-liability",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "recover",
                "channel": "future",
                "horizon": 1,
                "confidence_milli": 1000,
                "base_score": -1000,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "send_out", "card_uid": None},
                    {"fact": "opponent.prizes_remaining", "op": "lte", "value": 2, "card_uid": None},
                    {"fact": "option.target_prize_value", "op": "gte", "value": 2, "card_uid": None},
                    {"fact": "option.target_attack_ready", "op": "eq", "value": False, "card_uid": None},
                ],
                "score_terms": [],
            },
            {
                "rule_id": "send-out.ready-counterattack",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "execute",
                "channel": "future",
                "horizon": 1,
                "confidence_milli": 1000,
                "base_score": 1500,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "send_out", "card_uid": None},
                    {"fact": "option.target_attack_ready", "op": "eq", "value": True, "card_uid": None},
                ],
                "score_terms": [],
            },
            {
                "rule_id": "send-out.one-prize-bridge",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "recover",
                "channel": "future",
                "horizon": 1,
                "confidence_milli": 1000,
                "base_score": 500,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "send_out", "card_uid": None},
                    {"fact": "option.target_prize_value", "op": "eq", "value": 1, "card_uid": None},
                ],
                "score_terms": [],
            },
        ],
    }


class CompetitivePolicyV2Tests(unittest.TestCase):
    def test_energy_bearing_board_count_is_scoped_to_the_requested_pokemon_uid(self) -> None:
        document = _policy()
        document["count_rules"] = []
        document["rules"] = [
            {
                "rule_id": "night-stretcher.keep-basic-by-default",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "recover",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [
                    {"fact": "option.card_uid", "op": "eq", "value": IMPIDIMP, "card_uid": None}
                ],
                "score_terms": [],
            },
            {
                "rule_id": "night-stretcher.morgrem-only-for-funded-impidimp",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "recover",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 2000,
                "when": [
                    {"fact": "option.card_uid", "op": "eq", "value": MORGREM, "card_uid": None},
                    {
                        "fact": "self.board.energy_bearing_count_uid",
                        "op": "gte",
                        "value": 1,
                        "card_uid": IMPIDIMP,
                    },
                ],
                "score_terms": [],
            },
        ]
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, IMPIDIMP, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        options = [
            _option(0, "effect_target", card_uid=IMPIDIMP, source_uid=NIGHT_STRETCHER),
            _option(1, "effect_target", card_uid=MORGREM, source_uid=NIGHT_STRETCHER),
        ]
        unfunded = _frame(
            options,
            prompt_kind="effect_target",
            minimum=1,
            maximum=1,
            active=[_slot(10, IMPIDIMP, energy=0, required=1, prizes=1)],
            bench=[_slot(11, MUNKIDORI, energy=1, required=1, prizes=1)],
        )
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(compiled.policy, unfunded).selected_indexes,
            [0],
        )
        funded = copy.deepcopy(unfunded)
        funded["source"]["window_id"] = "C" * 64
        funded["public_state"]["self"]["active"] = [
            _slot(10, IMPIDIMP, energy=1, required=1, prizes=1)
        ]
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(compiled.policy, funded).selected_indexes,
            [1],
        )

    def test_tm_evolution_target_facts_include_same_turn_slots_and_require_morgrem_energy(self) -> None:
        document = _policy()
        document["count_rules"] = []
        document["rules"] = [
            {
                "rule_id": "tm.safe-two-target-proof",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "deploy",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 3000,
                "when": [
                    {"fact": "option.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None},
                    {
                        "fact": "self.bench.evolution_eligible_count_uid",
                        "op": "eq",
                        "value": 2,
                        "card_uid": IMPIDIMP,
                    },
                    {
                        "fact": "self.bench.energy_bearing_evolution_eligible_count_uid",
                        "op": "eq",
                        "value": 1,
                        "card_uid": MORGREM,
                    },
                ],
                "score_terms": [],
            },
            {
                "rule_id": "fallback",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "maintain",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 100,
                "when": [
                    {"fact": "option.card_uid", "op": "eq", "value": MUNKIDORI, "card_uid": None}
                ],
                "score_terms": [],
            },
        ]
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, IMPIDIMP, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        established = _slot(20, IMPIDIMP, energy=0, required=1, prizes=1)
        established["appeared_this_turn"] = False
        fresh = _slot(21, IMPIDIMP, energy=0, required=1, prizes=1)
        fresh["appeared_this_turn"] = True
        funded_morgrem = _slot(22, MORGREM, energy=1, required=1, prizes=1)
        funded_morgrem["appeared_this_turn"] = False
        frame = _frame(
            [
                _option(0, "search", card_uid=GRIMMSNARL),
                _option(1, "search", card_uid=MUNKIDORI),
            ],
            prompt_kind="search",
            minimum=1,
            maximum=1,
            bench=[established, fresh, funded_morgrem],
        )
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(compiled.policy, frame).selected_indexes,
            [0],
        )
        frame["source"]["window_id"] = "D" * 64
        frame["public_state"]["self"]["bench"][2]["attached_energy_uids"] = []
        frame["public_state"]["self"]["bench"][2]["attached_energy_count"] = 0
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(compiled.policy, frame).selected_indexes,
            [1],
        )

    def test_route_candidate_adjudicator_owns_route_before_local_score(self) -> None:
        document = _policy()
        goal_id = "two-ready-grimmsnarl"
        document["adapter_version"] = 25
        document["count_rules"] = []
        document["rules"] = [
            {
                "rule_id": "local.greedy-attack",
                "goal_id": goal_id,
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 900000,
                "when": [
                    {"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": None}
                ],
                "score_terms": [],
            }
        ]

        def component(base: int) -> dict[str, object]:
            return {"base": base, "terms": []}

        def budget(manual: int) -> dict[str, int]:
            return {
                "supporter_uses": 0,
                "manual_attachments": manual,
                "retreats": 0,
                "bench_slots": 0,
                "ability_uses": 0,
                "discard_cards": 0,
                "search_cards": 0,
            }

        def value(continuity: int, cost: int, risk: int) -> dict[str, object]:
            return {
                "attack_windows": component(1),
                "prize_progress": component(1),
                "continuity": component(continuity),
                "resource_cost": component(cost),
                "response_risk": component(risk),
                "uncertainty": component(0),
            }

        def candidate(route_id: str, kind: str, manual: int, continuity: int) -> dict[str, object]:
            return {
                "route_id": route_id,
                "goal_id": goal_id,
                "owner_goal_id": goal_id,
                "bridge_goal_id": goal_id,
                "pivot_goal_id": goal_id,
                "when": [],
                "resource_budget": budget(manual),
                "value": value(continuity, 3 if manual else 0, 1 if manual else 2),
                "steps": [
                    {
                        "step_id": f"{route_id}-step",
                        "prompt_kinds": ["main"],
                        "goal_id": goal_id,
                        "when": [],
                        "option_when": [
                            {"fact": "option.kind", "op": "eq", "value": kind, "card_uid": None}
                        ],
                        "selection_count": 1,
                        "terminal": kind == "attack",
                        "checkpoint": False,
                    }
                ],
            }

        document["route_candidates"] = [
            candidate("continuity-first", "attach_energy", 1, 5),
            candidate("attack-now", "attack", 0, 1),
        ]
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document, allowed_card_uids={DARK, GRIMMSNARL, MORGREM}
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(
                    0,
                    "attack",
                    source_uid=GRIMMSNARL,
                    source_serial=10,
                    attack_index=0,
                    projected_damage=120,
                ),
                _option(
                    1,
                    "attach_energy",
                    card_uid=DARK,
                    target_uid=MORGREM,
                    target_serial=11,
                    target_attached_energy_count=0,
                    target_attached_energy_uids=[],
                    target_minimum_attack_energy_count=2,
                    target_attack_ready=False,
                    target_energy_debt=2,
                ),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
            active=[_slot(10, GRIMMSNARL, energy=1, required=2, prizes=2)],
            bench=[_slot(11, MORGREM, energy=0, required=2, prizes=1)],
        )
        frame["public_state"]["self"]["turn"] = {
            "supporter_available": True,
            "manual_attachment_available": True,
            "retreat_available": True,
        }
        planned = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)
        self.assertEqual([1], planned.selected_indexes)
        self.assertEqual(
            "continuity-first",
            planned.audit["turn_contract"]["route_candidate_adjudication"]["selected_route_id"],
        )
        frame["public_state"]["self"]["turn"]["manual_attachment_available"] = False
        spent = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)
        self.assertEqual([0], spent.selected_indexes)
        self.assertEqual(
            "attack-now",
            spent.audit["turn_contract"]["route_candidate_adjudication"]["selected_route_id"],
        )

    def setUp(self) -> None:
        outcome = CompetitivePolicyV2Compiler.compile_local_uid(
            _policy(),
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(outcome.accepted, outcome.error_code)
        self.assertIsNotNone(outcome.policy)
        self.policy = outcome.policy

    def test_goal_relative_continuity_facts_bind_public_debt_and_position(self) -> None:
        goal_id = "public-continuity"
        document = {
            "schema_version": 2,
            "adapter_id": "test.public-continuity-facts",
            "adapter_version": 19,
            "goals": [
                {
                    "goal_id": goal_id,
                    "stage": "maintain",
                    "priority": 900,
                    "requirements": [
                        {
                            "card_uid": GRIMMSNARL,
                            "ready_target_count": 2,
                            "energy_required": 2,
                            "energy_requirements": [
                                {"energy_uid": DARK, "count": 1},
                                {"energy_uid": GRASS, "count": 1},
                            ],
                            "attack_index": 1,
                            "ability_index": None,
                        },
                        {
                            "card_uid": MORGREM,
                            "ready_target_count": 1,
                            "energy_required": 1,
                            "energy_requirements": [
                                {"energy_uid": FIGHTING, "count": 1}
                            ],
                            "attack_index": None,
                            "ability_index": 0,
                        },
                    ],
                }
            ],
            "count_rules": [],
            "rules": [
                {
                    "rule_id": "attack-baseline",
                    "goal_id": goal_id,
                    "goal_stage": "execute",
                    "channel": "tactical",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 1000,
                    "when": [
                        {"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": None}
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "attach-baseline",
                    "goal_id": goal_id,
                    "goal_stage": "fund",
                    "channel": "future",
                    "horizon": 1,
                    "confidence_milli": 1000,
                    "base_score": 900,
                    "when": [
                        {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None}
                    ],
                    "score_terms": [],
                },
            ],
            "turn_bonus_contracts": [
                {
                    "contract_id": "continuity",
                    "priority": 900,
                    "goal_id": goal_id,
                    "when": [
                        {"fact": "goal.active_ready_count_uid", "op": "gte", "value": 1, "card_uid": GRIMMSNARL},
                        {"fact": "goal.board_energy_count", "op": "lt", "value": 5, "card_uid": None},
                        {"fact": "goal.discard_energy_count", "op": "gte", "value": 2, "card_uid": None},
                        {"fact": "self.bench_open", "op": "eq", "value": True, "card_uid": None},
                    ],
                    "bonuses": [
                        {
                            "bonus_id": "fund-backup",
                            "prompt_kinds": ["main"],
                            "goal_id": goal_id,
                            "when": [
                                {"fact": "goal.near_ready_count_uid", "op": "gte", "value": 2, "card_uid": GRIMMSNARL},
                                {"fact": "goal.ready_count_uid", "op": "eq", "value": 0, "card_uid": MORGREM},
                            ],
                            "option_when": [
                                {"fact": "option.target_is_active", "op": "eq", "value": False, "card_uid": None},
                                {"fact": "goal.option.funds_target", "op": "eq", "value": True, "card_uid": None},
                            ],
                            "score_bonus": 500,
                        }
                    ],
                }
            ],
        }
        outcome = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRASS, FIGHTING, GRIMMSNARL, MORGREM},
        )
        self.assertTrue(outcome.accepted, outcome.error_code)
        active = _slot(20, GRIMMSNARL, energy=2, required=2, prizes=2)
        active["attached_energy_uids"] = [DARK, GRASS]
        backup = _slot(21, GRIMMSNARL, energy=1, required=2, prizes=2)
        backup["attached_energy_uids"] = [GRASS]
        engine = _slot(22, MORGREM, energy=0, required=1, prizes=1)
        frame = _frame(
            [
                _option(0, "attack", source_uid=GRIMMSNARL, source_serial=20, attack_index=1, projected_damage=140),
                _option(
                    1,
                    "attach_energy",
                    card_uid=DARK,
                    target_uid=GRIMMSNARL,
                    target_serial=21,
                    target_attached_energy_count=1,
                    target_attached_energy_uids=[GRASS],
                    target_minimum_attack_energy_count=2,
                    target_attack_ready=False,
                    target_energy_debt=1,
                ),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
            active=[active],
            bench=[
                backup,
                engine,
                _slot(23, MORGREM, energy=0, required=1, prizes=1),
                _slot(24, MORGREM, energy=0, required=1, prizes=1),
                _slot(25, MORGREM, energy=0, required=1, prizes=1),
            ],
        )
        frame["public_state"]["self"]["bench_capacity"] = 8
        frame["public_state"]["self"]["hand"] = [_card(30, FIGHTING)]
        frame["public_state"]["self"]["discard"] = [_card(31, DARK), _card(32, GRASS)]
        decision = CompetitivePolicyV2Runtime.decide(outcome.policy, frame)
        self.assertEqual([1], decision.selected_indexes)

        frame["source"]["window_id"] = "C" * 64
        frame["options"][1]["target_serial"] = 20
        active_target = CompetitivePolicyV2Runtime.decide(outcome.policy, frame)
        self.assertEqual([0], active_target.selected_indexes)

    def test_soft_turn_bonus_rebinds_and_yields_to_terminal_route(self) -> None:
        goal_id = "two-ready-grimmsnarl"
        document = _policy()
        document["adapter_version"] = 17
        document["rules"].extend(
            [
                {
                    "rule_id": "baseline-morgrem",
                    "goal_id": goal_id,
                    "goal_stage": "fund",
                    "channel": "future",
                    "horizon": 1,
                    "confidence_milli": 1000,
                    "base_score": 2000,
                    "when": [
                        {"fact": "option.card_uid", "op": "eq", "value": MORGREM, "card_uid": None}
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "baseline-grimmsnarl",
                    "goal_id": goal_id,
                    "goal_stage": "fund",
                    "channel": "future",
                    "horizon": 1,
                    "confidence_milli": 1000,
                    "base_score": 1000,
                    "when": [
                        {"fact": "option.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None}
                    ],
                    "score_terms": [],
                },
            ]
        )
        document["turn_bonus_contracts"] = [
            {
                "contract_id": "soft-continuity",
                "priority": 900,
                "goal_id": goal_id,
                "when": [
                    {"fact": "self.prizes_remaining", "op": "gte", "value": 3, "card_uid": None}
                ],
                "bonuses": [
                    {
                        "bonus_id": "build-owner",
                        "prompt_kinds": ["main"],
                        "goal_id": goal_id,
                        "when": [],
                        "option_when": [
                            {"fact": "option.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None}
                        ],
                        "score_bonus": 1500,
                    },
                    {
                        "bonus_id": "defer-bridge",
                        "prompt_kinds": ["main"],
                        "goal_id": goal_id,
                        "when": [],
                        "option_when": [
                            {"fact": "option.card_uid", "op": "eq", "value": MORGREM, "card_uid": None}
                        ],
                        "score_bonus": -1000,
                    },
                ],
            }
        ]
        outcome = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(outcome.accepted, outcome.error_code)

        frame = _frame(
            [
                _option(0, "play_card", card_uid=MORGREM),
                _option(1, "play_card", card_uid=GRIMMSNARL),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
        )
        softened = CompetitivePolicyV2Runtime.decide(outcome.policy, frame)
        self.assertEqual(softened.selected_indexes, [1])
        contract = softened.audit["turn_contract"]
        self.assertEqual(contract["turn_bonus_contract_id"], "soft-continuity")
        self.assertEqual(contract["turn_bonus_ids"], ["build-owner", "defer-bridge"])
        self.assertFalse(contract["terminal"])
        self.assertIsNone(contract["selection_count"])

        reordered = copy.deepcopy(frame)
        reordered["source"]["window_id"] = "C" * 64
        reordered["options"].reverse()
        for index, option in enumerate(reordered["options"]):
            option["index"] = index
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(outcome.policy, reordered).selected_indexes,
            [0],
        )

        terminal_document = copy.deepcopy(document)
        terminal_document["turn_routes"] = [
            {
                "route_id": "terminal-owner",
                "priority": 1000,
                "goal_id": goal_id,
                "owner_goal_id": goal_id,
                "bridge_goal_id": goal_id,
                "pivot_goal_id": goal_id,
                "when": [],
                "steps": [
                    {
                        "step_id": "finish-now",
                        "prompt_kinds": ["main"],
                        "goal_id": goal_id,
                        "when": [],
                        "option_when": [
                            {"fact": "option.card_uid", "op": "eq", "value": MORGREM, "card_uid": None}
                        ],
                        "score_bonus": 100000,
                        "selection_count": 1,
                        "terminal": True,
                        "checkpoint": False,
                    }
                ],
            }
        ]
        terminal_outcome = CompetitivePolicyV2Compiler.compile_local_uid(
            terminal_document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(terminal_outcome.accepted, terminal_outcome.error_code)
        terminal = CompetitivePolicyV2Runtime.decide(terminal_outcome.policy, frame)
        self.assertEqual(terminal.selected_indexes, [0])
        terminal_contract = terminal.audit["turn_contract"]
        self.assertTrue(terminal_contract["terminal"])
        self.assertNotIn("turn_bonus_contract_id", terminal_contract)
        matched = [
            item["rule_id"]
            for card in terminal.audit["scorecards"]
            for item in card["matched_rules"]
        ]
        self.assertFalse(any(rule_id.startswith("@turn_bonus.") for rule_id in matched))

    def test_public_turn_route_and_source_bound_recipe_replan_each_window(self) -> None:
        document = {
            "schema_version": 2,
            "adapter_id": "test.turn-route-contract",
            "adapter_version": 11,
            "goals": [
                {
                    "goal_id": "grimmsnarl-owner",
                    "stage": "execute",
                    "priority": 900,
                    "requirements": [
                        {
                            "card_uid": GRIMMSNARL,
                            "ready_target_count": 1,
                            "energy_required": 2,
                            "attack_index": 1,
                            "ability_index": None,
                        }
                    ],
                }
            ],
            "count_rules": [],
            "rules": [
                {
                    "rule_id": "legacy.prefers-redraw",
                    "goal_id": "grimmsnarl-owner",
                    "goal_stage": "execute",
                    "channel": "tactical",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 5000,
                    "when": [
                        {"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": None},
                        {"fact": "option.attack_index", "op": "eq", "value": 0, "card_uid": None},
                    ],
                    "score_terms": [],
                }
            ],
            "turn_routes": [
                {
                    "route_id": "owner-continuity",
                    "priority": 900,
                    "goal_id": "grimmsnarl-owner",
                    "owner_goal_id": "grimmsnarl-owner",
                    "bridge_goal_id": "grimmsnarl-owner",
                    "pivot_goal_id": "grimmsnarl-owner",
                    "when": [
                        {
                            "fact": "self.board.count_uid",
                            "op": "gte",
                            "value": 1,
                            "card_uid": GRIMMSNARL,
                        }
                    ],
                    "steps": [
                        {
                            "step_id": "fund-owner",
                            "prompt_kinds": ["main"],
                            "goal_id": "grimmsnarl-owner",
                            "when": [
                                {"fact": "goal.energy_debt", "op": "gt", "value": 0, "card_uid": None},
                                {
                                    "fact": "turn.manual_attachment_available",
                                    "op": "eq",
                                    "value": True,
                                    "card_uid": None,
                                },
                            ],
                            "option_when": [
                                {
                                    "fact": "goal.option.funds_target",
                                    "op": "eq",
                                    "value": True,
                                    "card_uid": None,
                                }
                            ],
                            "score_bonus": 100000,
                            "selection_count": 1,
                            "terminal": False,
                            "checkpoint": False,
                        },
                        {
                            "step_id": "declared-attack",
                            "prompt_kinds": ["main"],
                            "goal_id": "grimmsnarl-owner",
                            "when": [
                                {"fact": "goal.energy_debt", "op": "eq", "value": 0, "card_uid": None}
                            ],
                            "option_when": [
                                {
                                    "fact": "goal.option.executes_requirement",
                                    "op": "eq",
                                    "value": True,
                                    "card_uid": None,
                                }
                            ],
                            "score_bonus": 100000,
                            "selection_count": 1,
                            "terminal": True,
                            "checkpoint": False,
                        },
                    ],
                },
                {
                    "route_id": "owner-rebuild",
                    "priority": 800,
                    "goal_id": "grimmsnarl-owner",
                    "owner_goal_id": "grimmsnarl-owner",
                    "bridge_goal_id": "grimmsnarl-owner",
                    "pivot_goal_id": "grimmsnarl-owner",
                    "when": [
                        {
                            "fact": "self.board.count_uid",
                            "op": "eq",
                            "value": 0,
                            "card_uid": GRIMMSNARL,
                        }
                    ],
                    "steps": [
                        {
                            "step_id": "recover-owner",
                            "prompt_kinds": ["effect_target"],
                            "goal_id": "grimmsnarl-owner",
                            "when": [
                                {
                                    "fact": "self.discard.count_uid",
                                    "op": "gte",
                                    "value": 1,
                                    "card_uid": GRIMMSNARL,
                                }
                            ],
                            "option_when": [
                                {"fact": "option.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None},
                                {
                                    "fact": "option.source_uid",
                                    "op": "eq",
                                    "value": NIGHT_STRETCHER,
                                    "card_uid": None,
                                },
                            ],
                            "score_bonus": 90000,
                            "selection_count": 1,
                            "terminal": False,
                            "checkpoint": True,
                        }
                    ],
                },
            ],
            "interaction_recipes": [
                {
                    "recipe_id": "stretcher-recovers-owner",
                    "priority": 1000,
                    "route_id": "owner-rebuild",
                    "goal_id": "grimmsnarl-owner",
                    "source_uids": [NIGHT_STRETCHER],
                    "when": [
                        {
                            "fact": "self.discard.count_uid",
                            "op": "gte",
                            "value": 1,
                            "card_uid": GRIMMSNARL,
                        }
                    ],
                    "steps": [
                        {
                            "step_id": "recover-owner-target",
                            "prompt_kinds": ["effect_target"],
                            "goal_id": "grimmsnarl-owner",
                            "when": [],
                            "option_when": [
                                {"fact": "option.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None}
                            ],
                            "score_bonus": 120000,
                            "selection_count": 1,
                            "terminal": False,
                            "checkpoint": True,
                        }
                    ],
                }
            ],
        }
        outcome = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, NIGHT_STRETCHER},
        )
        self.assertTrue(outcome.accepted, outcome.error_code)

        frame = _frame(
            [
                _option(
                    0,
                    "attach_energy",
                    card_uid=DARK,
                    target_uid=GRIMMSNARL,
                    target_serial=20,
                    target_attached_energy_count=1,
                    target_attached_energy_uids=[DARK],
                    target_minimum_attack_energy_count=2,
                    target_attack_ready=False,
                    target_energy_debt=1,
                ),
                _option(1, "attack", source_uid=GRIMMSNARL, source_serial=20, attack_index=0, projected_damage=0),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
            active=[_slot(20, GRIMMSNARL, energy=1, required=2, prizes=2)],
        )
        frame["public_state"]["self"]["turn"] = {
            "supporter_available": True,
            "manual_attachment_available": True,
            "retreat_available": True,
        }
        funded = CompetitivePolicyV2Runtime.decide(outcome.policy, frame)
        self.assertEqual(funded.selected_indexes, [0])
        self.assertEqual(funded.audit["turn_contract"]["route_id"], "owner-continuity")
        self.assertEqual(funded.audit["turn_contract"]["first_executable_step_id"], "fund-owner")
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(
                outcome.policy, frame, base_vetoed_indexes=[0]
            ).selected_indexes,
            [1],
        )
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(
                outcome.policy, frame, mandatory_indexes=[1]
            ).selected_indexes,
            [1],
        )

        ready = copy.deepcopy(frame)
        ready["source"]["window_id"] = "C" * 64
        ready["public_state"]["self"]["turn"]["manual_attachment_available"] = False
        ready["public_state"]["self"]["active"] = [
            _slot(20, GRIMMSNARL, energy=2, required=2, prizes=2)
        ]
        ready["options"] = [
            _option(0, "attack", source_uid=GRIMMSNARL, source_serial=20, attack_index=1, projected_damage=210),
            _option(1, "attack", source_uid=GRIMMSNARL, source_serial=20, attack_index=0, projected_damage=0),
        ]
        attacked = CompetitivePolicyV2Runtime.decide(outcome.policy, ready)
        self.assertEqual(attacked.selected_indexes, [0])
        self.assertEqual(attacked.audit["turn_contract"]["first_executable_step_id"], "declared-attack")
        self.assertTrue(attacked.audit["turn_contract"]["terminal"])

        reordered = copy.deepcopy(ready)
        reordered["source"]["window_id"] = "D" * 64
        reordered["options"].reverse()
        for index, option in enumerate(reordered["options"]):
            option["index"] = index
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(outcome.policy, reordered).selected_indexes,
            [1],
        )

        recipe = _frame(
            [
                _option(0, "effect_target", card_uid=DARK, source_uid=NIGHT_STRETCHER),
                _option(1, "effect_target", card_uid=GRIMMSNARL, source_uid=NIGHT_STRETCHER),
            ],
            prompt_kind="effect_target",
            minimum=1,
            maximum=1,
        )
        recipe["public_state"]["self"]["discard"] = [_card(30, GRIMMSNARL)]
        recovered = CompetitivePolicyV2Runtime.decide(outcome.policy, recipe)
        self.assertEqual(recovered.selected_indexes, [1])
        self.assertEqual(
            recovered.audit["turn_contract"]["interaction_recipe_id"],
            "stretcher-recovers-owner",
        )
        self.assertEqual(recovered.audit["desired_count"], 1)

        wrong_source = copy.deepcopy(recipe)
        wrong_source["source"]["window_id"] = "E" * 64
        for option in wrong_source["options"]:
            option["source_uid"] = DARK
        ignored = CompetitivePolicyV2Runtime.decide(outcome.policy, wrong_source)
        self.assertEqual(ignored.selected_indexes, [0])
        self.assertIsNone(ignored.audit["turn_contract"]["interaction_recipe_id"])

        unknown_source = copy.deepcopy(document)
        unknown_source["interaction_recipes"][0]["source_uids"] = ["SFA_999"]
        rejected = CompetitivePolicyV2Compiler.compile_local_uid(
            unknown_source,
            allowed_card_uids={DARK, GRIMMSNARL, NIGHT_STRETCHER},
        )
        self.assertFalse(rejected.accepted)
        self.assertEqual(rejected.error_code, "invalid_interaction_recipe")

    def test_exact_three_of_five_uses_public_goal_energy_debt(self) -> None:
        active = [_slot(10, GRIMMSNARL, energy=1, required=2, prizes=2)]
        bench = [_slot(11, MORGREM, energy=0, required=2, prizes=1)]
        options = [_option(i, "assignment_source", card_uid=DARK) for i in range(5)]
        frame = _frame(options, prompt_kind="assignment_source", minimum=0, maximum=5, active=active, bench=bench)

        result = CompetitivePolicyV2Runtime.decide(self.policy, frame)

        self.assertTrue(result.accepted, result.error_code)
        self.assertEqual(result.selected_indexes, [0, 1, 2])
        self.assertEqual(result.audit["desired_count"], 3)
        self.assertEqual(result.audit["goal_states"][0]["energy_debt"], 3)

    def test_goal_energy_debt_can_cap_every_existing_member_of_a_multi_printing_family(self) -> None:
        document = _policy()
        document["adapter_version"] = 23
        document["goals"][0]["requirements"] = [
            {"card_uid": GRIMMSNARL, "ready_target_count": 6, "energy_required": 2},
            {"card_uid": MORGREM, "ready_target_count": 6, "energy_required": 2},
            {"card_uid": IMPIDIMP, "ready_target_count": 6, "energy_required": 2},
        ]
        document["count_rules"][0]["mode"] = "goal_energy_debt"
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, IMPIDIMP, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)

        active = _slot(10, GRIMMSNARL, energy=1, required=2, prizes=2)
        backup = _slot(11, IMPIDIMP, energy=1, required=1, prizes=1)
        already_capped = _slot(12, MORGREM, energy=4, required=2, prizes=1)
        options = [_option(i, "assignment_source", card_uid=DARK) for i in range(4)]
        frame = _frame(
            options,
            prompt_kind="assignment_source",
            minimum=0,
            maximum=4,
            active=[active],
            bench=[backup, already_capped],
        )

        exact_two = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)

        self.assertTrue(exact_two.accepted, exact_two.error_code)
        self.assertEqual(exact_two.selected_indexes, [0, 1])
        self.assertEqual(exact_two.audit["desired_count"], 2)

        cleared = copy.deepcopy(frame)
        cleared["source"]["window_id"] = "9" * 64
        cleared["public_state"]["self"]["active"][0]["attached_energy_count"] = 2
        cleared["public_state"]["self"]["active"][0]["attached_energy_uids"] = [DARK, DARK]
        cleared["public_state"]["self"]["active"][0]["energy_debt"] = 0
        cleared["public_state"]["self"]["active"][0]["attack_ready"] = True
        cleared["public_state"]["self"]["bench"][0]["attached_energy_count"] = 2
        cleared["public_state"]["self"]["bench"][0]["attached_energy_uids"] = [DARK, DARK]
        cleared["public_state"]["self"]["bench"][0]["energy_debt"] = 0
        cleared["public_state"]["self"]["bench"][0]["attack_ready"] = True
        no_excess = CompetitivePolicyV2Runtime.decide(compiled.policy, cleared)
        self.assertEqual(no_excess.selected_indexes, [])
        self.assertEqual(no_excess.audit["desired_count"], 0)

    def test_exact_subset_rebinds_after_option_reorder(self) -> None:
        active = [_slot(10, GRIMMSNARL, energy=1, required=2, prizes=2)]
        bench = [_slot(11, MORGREM, energy=0, required=2, prizes=1)]
        options = [
            _option(0, "assignment_source", card_uid="OTHER_001"),
            _option(1, "assignment_source", card_uid=DARK),
            _option(2, "assignment_source", card_uid=DARK),
            _option(3, "assignment_source", card_uid="OTHER_002"),
            _option(4, "assignment_source", card_uid=DARK),
        ]
        frame = _frame(options, prompt_kind="assignment_source", minimum=0, maximum=5, active=active, bench=bench)

        result = CompetitivePolicyV2Runtime.decide(self.policy, frame)

        self.assertEqual(result.selected_indexes, [1, 2, 4])

    def test_official_select_context_distinguishes_energy_to_hand_from_attachment_source(self) -> None:
        document = _policy()
        document["count_rules"].extend(
            [
                {
                    "rule_id": "interaction.choose-one-to-hand",
                    "priority": 0,
                    "goal_id": "two-ready-grimmsnarl",
                    "mode": "fixed",
                    "fixed_count": 1,
                    "fact": None,
                    "divisor": None,
                    "when": [
                        {"fact": "select.context", "op": "eq", "value": "to_hand_energy", "card_uid": None},
                    ],
                },
                {
                    "rule_id": "interaction.choose-one-attachment-source",
                    "priority": 1,
                    "goal_id": "two-ready-grimmsnarl",
                    "mode": "fixed",
                    "fixed_count": 1,
                    "fact": None,
                    "divisor": None,
                    "when": [
                        {"fact": "select.context", "op": "eq", "value": "attach_to", "card_uid": None},
                    ],
                },
            ]
        )
        document["rules"].extend(
            [
                {
                    "rule_id": "interaction.keep-grass-in-hand",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "fund",
                    "channel": "interaction",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 20000,
                    "when": [
                        {"fact": "select.type", "op": "eq", "value": "energy", "card_uid": None},
                        {"fact": "select.context", "op": "eq", "value": "to_hand_energy", "card_uid": None},
                        {"fact": "option.card_uid", "op": "eq", "value": GRASS, "card_uid": None},
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "interaction.attach-fighting-from-deck",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "fund",
                    "channel": "interaction",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 20000,
                    "when": [
                        {"fact": "select.type", "op": "eq", "value": "energy", "card_uid": None},
                        {"fact": "select.context", "op": "eq", "value": "attach_to", "card_uid": None},
                        {"fact": "option.card_uid", "op": "eq", "value": FIGHTING, "card_uid": None},
                    ],
                    "score_terms": [],
                },
            ]
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRASS, FIGHTING, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        options = [
            _option(0, "search", card_uid=FIGHTING),
            _option(1, "search", card_uid=GRASS),
        ]

        to_hand = _frame(
            options,
            prompt_kind="search",
            minimum=0,
            maximum=1,
            select_type_raw=4,
            select_context_raw=31,
        )
        attach_source = copy.deepcopy(to_hand)
        attach_source["source"]["window_id"] = "C" * 64
        attach_source["select_semantics"]["select_context_raw"] = 22

        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(compiled.policy, to_hand).selected_indexes,
            [1],
        )
        self.assertEqual(
            CompetitivePolicyV2Runtime.decide(compiled.policy, attach_source).selected_indexes,
            [0],
        )

    def test_variable_damage_discard_uses_public_hp_and_preserves_exact_attack_cost(self) -> None:
        document = _policy()
        document["count_rules"].insert(
            0,
            {
                "rule_id": "bellowing-thunder.minimum-lethal",
                "priority": 0,
                "goal_id": "two-ready-grimmsnarl",
                "mode": "ceil_public_fact_divisor",
                "fixed_count": None,
                "fact": "opponent.active.remaining_hp",
                "divisor": 70,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                    {"fact": "window.source_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None}
                ],
            },
        )
        document["rules"].extend(
            [
                {
                    "rule_id": "bellowing-thunder.grass-fuel",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "execute",
                    "channel": "interaction",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 900,
                    "when": [
                        {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                        {"fact": "option.card_uid", "op": "eq", "value": GRASS, "card_uid": None},
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "bellowing-thunder.preserve-only-fighting",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "execute",
                    "channel": "interaction",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": -2000,
                    "when": [
                        {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                        {"fact": "option.card_uid", "op": "eq", "value": FIGHTING, "card_uid": None},
                        {"fact": "self.active.energy_count_uid", "op": "eq", "value": 1, "card_uid": FIGHTING},
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "bellowing-thunder.preserve-only-lightning",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "execute",
                    "channel": "interaction",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": -2000,
                    "when": [
                        {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                        {"fact": "option.card_uid", "op": "eq", "value": LIGHTNING, "card_uid": None},
                        {"fact": "self.active.energy_count_uid", "op": "eq", "value": 1, "card_uid": LIGHTNING},
                    ],
                    "score_terms": [],
                },
            ]
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRASS, FIGHTING, LIGHTNING, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        active = _slot(10, GRIMMSNARL, energy=0, required=2, prizes=2)
        active["attached_energy_count"] = 4
        active["attached_energy_uids"] = [FIGHTING, LIGHTNING, GRASS, GRASS]
        active["attack_ready"] = True
        active["energy_debt"] = 0
        frame = _frame(
            [
                _option(0, "assignment_source", card_uid=FIGHTING, source_uid=GRIMMSNARL),
                _option(1, "assignment_source", card_uid=GRASS, source_uid=GRIMMSNARL),
                _option(2, "assignment_source", card_uid=LIGHTNING, source_uid=GRIMMSNARL),
                _option(3, "assignment_source", card_uid=GRASS, source_uid=GRIMMSNARL),
            ],
            prompt_kind="assignment_source",
            minimum=1,
            maximum=4,
            active=[active],
        )
        opponent = _slot(20, MORGREM, energy=0, required=2, prizes=2)
        opponent["remaining_hp"] = 140
        frame["public_state"]["opponent"]["active"] = [opponent]

        decision = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)

        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual(decision.audit["desired_count"], 2)
        self.assertEqual(decision.selected_indexes, [1, 3])

    def test_assignment_reobserves_current_target_energy_debt(self) -> None:
        targets = [
            _slot(10, GRIMMSNARL, energy=1, required=2, prizes=2),
            _slot(11, MORGREM, energy=0, required=2, prizes=1),
        ]
        picks: list[int] = []
        for _ in range(3):
            options = [
                _option(
                    index,
                    "assignment_target",
                    target_uid=slot["local_card_uid"],
                    target_serial=slot["serial"],
                    target_prize_value=slot["prize_value"],
                    target_attached_energy_count=slot["attached_energy_count"],
                    target_minimum_attack_energy_count=slot["minimum_attack_energy_count"],
                    target_attack_ready=slot["attack_ready"],
                    target_energy_debt=slot["energy_debt"],
                )
                for index, slot in enumerate(targets)
            ]
            frame = _frame(options, prompt_kind="assignment_target", minimum=1, maximum=1, active=[targets[0]], bench=[targets[1]])
            result = CompetitivePolicyV2Runtime.decide(self.policy, frame)
            self.assertTrue(result.accepted, result.error_code)
            picked = result.selected_indexes[0]
            picks.append(picked)
            targets[picked]["attached_energy_count"] = int(targets[picked]["attached_energy_count"]) + 1
            targets[picked]["attached_energy_uids"] = [DARK] * int(
                targets[picked]["attached_energy_count"]
            )
            targets[picked]["energy_debt"] = max(
                0,
                int(targets[picked]["minimum_attack_energy_count"])
                - int(targets[picked]["attached_energy_count"]),
            )
            targets[picked]["attack_ready"] = targets[picked]["energy_debt"] == 0

        self.assertEqual(picks, [1, 0, 1])
        self.assertEqual([slot["attached_energy_count"] for slot in targets], [2, 2])

    def test_public_frame_accepts_typed_energy_debt_not_just_card_count(self) -> None:
        typed_slot = _slot(10, GRIMMSNARL, energy=1, required=2, prizes=2)
        typed_slot["energy_debt"] = 2
        typed_slot["attack_ready"] = False
        frame = _frame(
            [_option(0, "send_out", target_uid=GRIMMSNARL, target_serial=10,
                     target_prize_value=2, target_attack_ready=False, target_energy_debt=2)],
            prompt_kind="send_out",
            minimum=1,
            maximum=1,
            active=[typed_slot],
        )
        decision = CompetitivePolicyV2Runtime.decide(self.policy, frame)
        self.assertTrue(decision.accepted, decision.error_code)

    def test_goal_readiness_requires_declared_typed_energy_mix(self) -> None:
        document = _policy()
        document["goals"][0]["requirements"][0]["energy_requirements"] = [
            {"energy_uid": FIGHTING, "count": 1},
            {"energy_uid": LIGHTNING, "count": 1},
        ]
        document["rules"].append(
            {
                "rule_id": "typed-ready.attack",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [
                    {"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": None},
                    {"fact": "goal.ready_count", "op": "gte", "value": 1, "card_uid": None},
                ],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, FIGHTING, LIGHTNING, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        slot = _slot(10, GRIMMSNARL, energy=2, required=1, prizes=2)
        slot["attached_energy_uids"] = [FIGHTING, FIGHTING]
        frame = _frame(
            [_option(0, "attack", source_uid=GRIMMSNARL, attack_index=0, projected_damage=0), _option(1, "end_turn")],
            prompt_kind="main",
            minimum=1,
            maximum=1,
            active=[slot],
        )

        wrong_mix = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)

        self.assertTrue(wrong_mix.accepted, wrong_mix.error_code)
        self.assertEqual(wrong_mix.selected_indexes, [1])
        self.assertEqual(wrong_mix.audit["goal_states"][0]["ready_count"], 0)
        self.assertEqual(wrong_mix.audit["goal_states"][0]["energy_debt"], 1)

        correct_frame = copy.deepcopy(frame)
        correct_frame["source"]["window_id"] = "C" * 64
        correct_frame["public_state"]["self"]["active"][0]["attached_energy_uids"] = [
            FIGHTING,
            LIGHTNING,
        ]
        correct_mix = CompetitivePolicyV2Runtime.decide(compiled.policy, correct_frame)
        self.assertEqual(correct_mix.selected_indexes, [0])
        self.assertEqual(correct_mix.audit["goal_states"][0]["ready_count"], 1)
        self.assertEqual(correct_mix.audit["goal_states"][0]["energy_debt"], 0)

    def test_window_option_uid_counts_allow_semantic_action_ordering(self) -> None:
        document = _policy()
        document["rules"].extend(
            [
                {
                    "rule_id": "ordering.bridge",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "fund",
                    "channel": "future",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 1000,
                    "when": [
                        {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None},
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "ordering.defer-bridge-for-search",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "acquire",
                    "channel": "macro",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": -1900,
                    "when": [
                        {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None},
                        {"fact": "window.option_count_card_uid", "op": "gte", "value": 1, "card_uid": MUNKIDORI},
                    ],
                    "score_terms": [],
                },
                {
                    "rule_id": "ordering.search",
                    "goal_id": "two-ready-grimmsnarl",
                    "goal_stage": "acquire",
                    "channel": "macro",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 200,
                    "when": [
                        {"fact": "option.card_uid", "op": "eq", "value": MUNKIDORI, "card_uid": None},
                    ],
                    "score_terms": [],
                },
            ]
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "attach_energy", card_uid=DARK, target_uid=MORGREM),
                _option(1, "play_trainer", card_uid=MUNKIDORI),
                _option(2, "end_turn"),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
        )

        with_search = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)

        self.assertTrue(with_search.accepted, with_search.error_code)
        self.assertEqual(with_search.selected_indexes, [1])
        reordered = copy.deepcopy(frame)
        reordered["source"]["window_id"] = "C" * 64
        reordered["options"] = [reordered["options"][1], reordered["options"][0], reordered["options"][2]]
        for index, option in enumerate(reordered["options"]):
            option["index"] = index
        self.assertEqual(CompetitivePolicyV2Runtime.decide(compiled.policy, reordered).selected_indexes, [0])

        without_search = copy.deepcopy(frame)
        without_search["source"]["window_id"] = "D" * 64
        without_search["options"] = [without_search["options"][0], without_search["options"][2]]
        without_search["options"][1]["index"] = 1
        self.assertEqual(CompetitivePolicyV2Runtime.decide(compiled.policy, without_search).selected_indexes, [0])

    def test_unmatched_main_window_uses_base_end_turn_fallback(self) -> None:
        frame = _frame(
            [_option(0, "play_trainer", card_uid=MUNKIDORI), _option(1, "end_turn")],
            prompt_kind="main",
            minimum=1,
            maximum=1,
        )
        decision = CompetitivePolicyV2Runtime.decide(self.policy, frame)
        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual(decision.selected_indexes, [1])
        self.assertTrue(decision.audit["fallback_used"])

    def test_neutral_unmatched_action_does_not_escape_base_fallback_because_another_option_is_vetoed(self) -> None:
        document = _policy()
        document["rules"].append(
            {
                "rule_id": "base-fixture.veto-other-option",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "maintain",
                "channel": "future",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -1000,
                "when": [
                    {"fact": "option.card_uid", "op": "eq", "value": MORGREM, "card_uid": None}
                ],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "play_trainer", card_uid=MUNKIDORI),
                _option(1, "play_trainer", card_uid=MORGREM),
                _option(2, "end_turn"),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
        )

        decision = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)

        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual(decision.selected_indexes, [2])
        self.assertTrue(decision.audit["fallback_used"])

    def test_base_tactical_floor_attacks_only_with_strictly_positive_public_damage(self) -> None:
        frame = _frame(
            [
                _option(0, "attack", source_uid=MORGREM, attack_index=0, projected_damage=10),
                _option(1, "end_turn"),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
        )

        productive = CompetitivePolicyV2Runtime.decide(self.policy, frame)

        self.assertTrue(productive.accepted, productive.error_code)
        self.assertEqual(productive.selected_indexes, [0])
        self.assertFalse(productive.audit["fallback_used"])
        self.assertIn(
            "@base.positive-damage-attack",
            [rule["rule_id"] for rule in productive.audit["scorecards"][0]["matched_rules"]],
        )

        zero_damage = copy.deepcopy(frame)
        zero_damage["source"]["window_id"] = "C" * 64
        zero_damage["options"][0]["projected_damage"] = 0
        guarded = CompetitivePolicyV2Runtime.decide(self.policy, zero_damage)
        self.assertEqual(guarded.selected_indexes, [1])
        self.assertTrue(guarded.audit["fallback_used"])

    def test_prize_clock_bridge_flips_when_two_prize_attacker_is_ready(self) -> None:
        options = [
            _option(0, "send_out", target_uid=GRIMMSNARL, target_serial=10, target_prize_value=2, target_attack_ready=False),
            _option(1, "send_out", target_uid=MUNKIDORI, target_serial=11, target_prize_value=1, target_attack_ready=False),
        ]
        frame = _frame(options, prompt_kind="send_out", minimum=1, maximum=1, opponent_prizes=2)
        bridge = CompetitivePolicyV2Runtime.decide(self.policy, frame)
        self.assertEqual(bridge.selected_indexes, [1])

        ready_frame = copy.deepcopy(frame)
        ready_frame["source"]["window_id"] = "C" * 64
        ready_frame["options"][0]["target_attack_ready"] = True
        counterattack = CompetitivePolicyV2Runtime.decide(self.policy, ready_frame)
        self.assertEqual(counterattack.selected_indexes, [0])

    def test_base_forced_veto_and_invalid_desired_count_remain_authoritative(self) -> None:
        options = [_option(i, "assignment_source", card_uid=DARK) for i in range(5)]
        active = [_slot(10, GRIMMSNARL, energy=1, required=2, prizes=2)]
        bench = [_slot(11, MORGREM, energy=0, required=2, prizes=1)]
        frame = _frame(
            options,
            prompt_kind="assignment_source",
            minimum=0,
            maximum=5,
            active=active,
            bench=bench,
        )
        forced = CompetitivePolicyV2Runtime.decide(
            self.policy,
            frame,
            terminal_indexes=[4],
            base_vetoed_indexes=[4],
        )
        self.assertEqual(forced.selected_indexes, [4])
        self.assertEqual(forced.audit["owner_layer"], "terminal")

        invalid_frame = copy.deepcopy(frame)
        invalid_frame["select_semantics"]["max_count"] = 1
        invalid_forced_count = CompetitivePolicyV2Runtime.decide(
            self.policy,
            invalid_frame,
            mandatory_indexes=[0, 1],
        )
        self.assertFalse(invalid_forced_count.accepted)
        self.assertEqual(invalid_forced_count.error_code, "invalid_base_authority")

        vetoed = CompetitivePolicyV2Runtime.decide(
            self.policy,
            frame,
            base_vetoed_indexes=[0, 1, 2],
        )
        self.assertTrue(vetoed.accepted, vetoed.error_code)
        self.assertEqual(vetoed.selected_indexes, [])
        self.assertTrue(vetoed.audit["fallback_used"])

    def test_not_contains_targets_only_a_missing_typed_energy(self) -> None:
        document = _policy()
        document["rules"].append(
            {
                "rule_id": "attach.only-missing-fighting",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 2000,
                "when": [
                    {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None},
                    {"fact": "option.card_uid", "op": "eq", "value": FIGHTING, "card_uid": None},
                    {
                        "fact": "option.target_attached_energy_uids",
                        "op": "not_contains",
                        "value": FIGHTING,
                        "card_uid": None,
                    },
                ],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, FIGHTING, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "attach_energy", card_uid=FIGHTING, target_uid=GRIMMSNARL,
                        target_attached_energy_uids=[FIGHTING]),
                _option(1, "attach_energy", card_uid=FIGHTING, target_uid=MORGREM,
                        target_attached_energy_uids=[]),
            ],
            prompt_kind="main",
            minimum=1,
            maximum=1,
        )

        decision = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)

        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual(decision.selected_indexes, [1])

    def test_private_or_unknown_fact_fails_closed_at_compile(self) -> None:
        document = _policy()
        document["rules"][0]["when"][0]["fact"] = "opponent.private_hand"
        outcome = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI},
        )
        self.assertFalse(outcome.accepted)
        self.assertEqual(outcome.error_code, "invalid_public_fact")

    def test_public_number_option_fact_selects_exact_counter_amount(self) -> None:
        document = _policy()
        document["adapter_version"] = 91
        document["rules"].append(
            {
                "rule_id": "munkidori.public-number",
                "goal_id": "two-ready-grimmsnarl",
                "goal_stage": "execute",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 0,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "effect_target", "card_uid": None}
                ],
                "score_terms": [
                    {
                        "fact": "option.option_number",
                        "coefficient": 1000,
                        "minimum": 1,
                        "maximum": 3,
                    }
                ],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, MORGREM, MUNKIDORI, NIGHT_STRETCHER},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        number_options = [
            _option(0, "effect_target", option_number=1),
            _option(1, "effect_target", option_number=3),
            _option(2, "effect_target", option_number=2),
        ]
        for option in number_options:
            option["option_type_raw"] = 0
        frame = _frame(
            number_options,
            prompt_kind="effect_target",
            minimum=1,
            maximum=1,
            select_type_raw=8,
            select_context_raw=40,
        )
        decision = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)
        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual([1], decision.selected_indexes)


if __name__ == "__main__":
    unittest.main()
