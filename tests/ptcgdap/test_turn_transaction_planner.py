from __future__ import annotations

import copy
import json
import unittest

from scripts.ai.ptcgdap.competitive_policy_v2 import (
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)
from scripts.ai.ptcgdap.turn_transaction_planner import TurnTransactionJournal


DARK = "SVI_003"
GRIMMSNARL = "M2_001"
IONO = "PAL_185"
TM_EVOLUTION = "PAR_178"


def _option(index: int, kind: str, *, card_uid: str | None = None, damage: int | None = None) -> dict[str, object]:
    attack_source_uid = GRIMMSNARL if kind == "attack" else None
    return {
        "index": index,
        "kind": kind,
        "card_uid": card_uid,
        "card_serial": 1000 + index if card_uid is not None else None,
        "source_uid": attack_source_uid,
        "source_serial": 2000 + index if attack_source_uid is not None else None,
        "target_uid": None,
        "target_serial": None,
        "target_remaining_hp": None,
        "target_prize_value": None,
        "target_attached_energy_count": None,
        "target_attached_energy_uids": None,
        "target_minimum_attack_energy_count": None,
        "target_attack_ready": None,
        "target_energy_debt": None,
        "projected_damage": damage,
        "projected_knockout": False,
        "requires_interaction": False,
        "attack_index": 0 if kind == "attack" else None,
        "option_number": None,
        "ability_index": None,
        "energy_type_raw": None,
        "energy_count": None,
        "special_condition_type": None,
        "pending_assignment_count": 0,
        "tags": [],
        "option_type_raw": 14 if kind == "end_turn" else (13 if kind == "attack" else 7),
        "option_player_index": 0,
    }


def _frame(options: list[dict[str, object]], *, turn: int = 3) -> dict[str, object]:
    return {
        "schema_version": 2,
        "profile_id": "ptcgdap-competitive-public-frame-v2",
        "sequence": turn,
        "seat": 0,
        "prompt_kind": "main",
        "source": {
            "public_observation_hash": ("A" if turn == 3 else "C") * 64,
            "window_id": ("B" if turn == 3 else "D") * 64,
        },
        "public_state": {
            "turn_number": turn,
            "phase": "MAIN",
            "self": {
                "hand": [
                    {"serial": 1, "local_card_uid": IONO},
                    {"serial": 2, "local_card_uid": TM_EVOLUTION},
                ],
                "active": [],
                "bench": [],
                "discard": [],
                "deck_count": 30,
                "prizes_remaining": 4,
                "turn": {
                    "supporter_available": True,
                    "manual_attachment_available": True,
                    "retreat_available": True,
                },
            },
            "opponent": {
                "hand_count": 7,
                "active": [],
                "bench": [],
                "discard": [],
                "deck_count": 28,
                "prizes_remaining": 4,
            },
        },
        "select_semantics": {
            "min_count": 1,
            "max_count": 1,
            "select_type_raw": 1,
            "select_context_raw": 0,
        },
        "options": options,
    }


def _document() -> dict[str, object]:
    condition = lambda fact, op, value, card_uid=None: {
        "fact": fact,
        "op": op,
        "value": value,
        "card_uid": card_uid,
    }
    return {
        "schema_version": 2,
        "adapter_id": "test.turn-transaction-v1",
        "adapter_version": 2,
        "goals": [
            {
                "goal_id": "core-online",
                "stage": "deploy",
                "priority": 1000,
                "requirements": [
                    {
                        "card_uid": GRIMMSNARL,
                        "ready_target_count": 1,
                        "energy_required": 2,
                    }
                ],
            }
        ],
        "count_rules": [],
        "rules": [
            {
                "rule_id": "neutral.attack",
                "goal_id": "core-online",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 0,
                "when": [condition("option.kind", "eq", "attack")],
                "score_terms": [],
            }
        ],
        "turn_transactions": [
            {
                "transaction_id": "develop-before-attack",
                "priority": 1000,
                "goal_id": "core-online",
                "deadline_turns": 1,
                "when": [condition("prompt_kind", "eq", "main")],
                "success_when": [
                    condition("self.hand.count_uid", "eq", 0, IONO),
                    condition("self.hand.count_uid", "eq", 0, TM_EVOLUTION),
                ],
                "abort_when": [],
                "methods": [
                    {
                        "method_id": "supporter-then-evolution",
                        "priority": 1000,
                        "when": [],
                        "steps": [
                            {
                                "step_id": "refresh-hand",
                                "prompt_kinds": ["main"],
                                "goal_id": "core-online",
                                "required_when": [
                                    condition("self.hand.count_uid", "gte", 1, IONO),
                                    condition("turn.supporter_available", "eq", True),
                                ],
                                "complete_when": [
                                    condition("self.hand.count_uid", "eq", 0, IONO)
                                ],
                                "option_when": [
                                    condition("option.card_uid", "eq", IONO)
                                ],
                                "score_bonus": 200000,
                                "selection_count": 1,
                                "terminal": False,
                                "checkpoint": True,
                                "required_before_attack": True,
                            },
                            {
                                "step_id": "double-evolution",
                                "prompt_kinds": ["main"],
                                "goal_id": "core-online",
                                "required_when": [
                                    condition("self.hand.count_uid", "gte", 1, TM_EVOLUTION)
                                ],
                                "complete_when": [
                                    condition("self.hand.count_uid", "eq", 0, TM_EVOLUTION)
                                ],
                                "option_when": [
                                    condition("option.card_uid", "eq", TM_EVOLUTION)
                                ],
                                "score_bonus": 200000,
                                "selection_count": 1,
                                "terminal": True,
                                "checkpoint": True,
                                "required_before_attack": True,
                            },
                        ],
                    }
                ],
            }
        ],
    }


class TurnTransactionPlannerTests(unittest.TestCase):
    def setUp(self) -> None:
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            _document(),
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        self.policy = compiled.policy
        self.journal = TurnTransactionJournal("match-1", 0, "test.package@1")

    def test_live_debt_owns_the_current_safe_action_before_attack(self) -> None:
        frame = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
                _option(2, "play_trainer", card_uid=TM_EVOLUTION),
            ]
        )
        decision = CompetitivePolicyV2Runtime.decide(
            self.policy,
            frame,
            turn_transaction_journal=self.journal,
        )

        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual(decision.selected_indexes, [1])
        contract = decision.audit["turn_transaction"]
        self.assertEqual(contract["transaction_id"], "develop-before-attack")
        self.assertEqual(contract["method_id"], "supporter-then-evolution")
        self.assertEqual(contract["step_id"], "refresh-hand")
        self.assertTrue(contract["attack_commit_blocked"])

    def test_reobserved_window_rebinds_semantic_step_and_never_persists_indexes(self) -> None:
        first = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
            ]
        )
        CompetitivePolicyV2Runtime.decide(
            self.policy, first, turn_transaction_journal=self.journal
        )

        second = _frame(
            [
                _option(0, "play_trainer", card_uid=TM_EVOLUTION),
                _option(1, "attack", damage=160),
            ],
            turn=4,
        )
        second["public_state"]["self"]["hand"] = [
            {"serial": 2, "local_card_uid": TM_EVOLUTION}
        ]
        second["public_state"]["self"]["turn"]["supporter_available"] = False
        decision = CompetitivePolicyV2Runtime.decide(
            self.policy, second, turn_transaction_journal=self.journal
        )

        self.assertEqual(decision.selected_indexes, [0])
        self.assertEqual(decision.audit["turn_transaction"]["step_id"], "double-evolution")
        snapshot_text = json.dumps(self.journal.snapshot(), sort_keys=True)
        for forbidden in ("index", "window", "observation_hash", "score", "binding", "proof"):
            self.assertNotIn(forbidden, snapshot_text)

    def test_reobserved_window_invalidates_entry_conditions_and_rearbitrates(self) -> None:
        document = copy.deepcopy(_document())
        document["turn_transactions"].append(
            {
                "transaction_id": "search-window-transaction",
                "priority": 2000,
                "goal_id": "core-online",
                "deadline_turns": 0,
                "when": [
                    {
                        "fact": "prompt_kind",
                        "op": "eq",
                        "value": "search",
                        "card_uid": None,
                    }
                ],
                "success_when": [],
                "abort_when": [],
                "methods": [
                    {
                        "method_id": "bind-fresh-search-window",
                        "priority": 1000,
                        "when": [],
                        "steps": [
                            {
                                "step_id": "select-evolution-tool",
                                "prompt_kinds": ["search"],
                                "goal_id": "core-online",
                                "required_when": [],
                                "complete_when": [],
                                "option_when": [
                                    {
                                        "fact": "option.card_uid",
                                        "op": "eq",
                                        "value": TM_EVOLUTION,
                                        "card_uid": None,
                                    }
                                ],
                                "score_bonus": 300000,
                                "selection_count": 1,
                                "terminal": True,
                                "checkpoint": True,
                                "required_before_attack": True,
                            }
                        ],
                    }
                ],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        journal = TurnTransactionJournal("match-rearbitrate", 0, "test.package@1")
        CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            _frame(
                [
                    _option(0, "attack", damage=160),
                    _option(1, "play_trainer", card_uid=IONO),
                ]
            ),
            turn_transaction_journal=journal,
        )
        search = _frame([_option(0, "search", card_uid=TM_EVOLUTION)], turn=3)
        search["prompt_kind"] = "search"
        search["source"]["public_observation_hash"] = "E" * 64
        search["source"]["window_id"] = "F" * 64

        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            search,
            turn_transaction_journal=journal,
        )

        self.assertEqual(decision.selected_indexes, [0])
        self.assertEqual(
            decision.audit["turn_transaction"]["transaction_id"],
            "search-window-transaction",
        )
        self.assertEqual(
            decision.audit["turn_transaction"]["step_id"],
            "select-evolution-tool",
        )

    def test_current_window_selection_groups_bind_one_option_from_each_semantic_quota(self) -> None:
        condition = lambda fact, op, value, card_uid=None: {
            "fact": fact,
            "op": op,
            "value": value,
            "card_uid": card_uid,
        }
        document = copy.deepcopy(_document())
        document["turn_transactions"] = [
            {
                "transaction_id": "balanced-multi-select",
                "priority": 2000,
                "goal_id": "core-online",
                "deadline_turns": 0,
                "when": [condition("prompt_kind", "eq", "search")],
                "success_when": [],
                "abort_when": [],
                "methods": [
                    {
                        "method_id": "one-of-each",
                        "priority": 1000,
                        "when": [],
                        "steps": [
                            {
                                "step_id": "bind-balanced-current-window-subset",
                                "prompt_kinds": ["search"],
                                "goal_id": "core-online",
                                "required_when": [],
                                "complete_when": [],
                                "option_when": [condition("option.kind", "eq", "search")],
                                "selection_groups": [
                                    {
                                        "group_id": "supporter",
                                        "selection_count": 1,
                                        "option_when": [
                                            condition("option.card_uid", "eq", IONO)
                                        ],
                                    },
                                    {
                                        "group_id": "tool",
                                        "selection_count": 1,
                                        "option_when": [
                                            condition("option.card_uid", "eq", TM_EVOLUTION)
                                        ],
                                    },
                                ],
                                "score_bonus": 900000,
                                "selection_count": 2,
                                "terminal": True,
                                "checkpoint": True,
                                "required_before_attack": True,
                            }
                        ],
                    }
                ],
            }
        ]
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "search", card_uid=IONO),
                _option(1, "search", card_uid=IONO),
                _option(2, "search", card_uid=TM_EVOLUTION),
                _option(3, "search", card_uid=TM_EVOLUTION),
            ]
        )
        frame["prompt_kind"] = "search"
        frame["select_semantics"]["min_count"] = 2
        frame["select_semantics"]["max_count"] = 2
        journal = TurnTransactionJournal("match-groups", 0, "test.package@1")

        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy, frame, turn_transaction_journal=journal
        )

        self.assertEqual(decision.selected_indexes, [0, 2])
        self.assertEqual(
            decision.audit["turn_contract"]["route_authority_indexes"], [0, 2]
        )
        snapshot_text = json.dumps(journal.snapshot(), sort_keys=True)
        self.assertNotIn("index", snapshot_text)

    def test_continue_when_keeps_started_intent_but_cannot_start_itself(self) -> None:
        condition = lambda fact, op, value, card_uid=None: {
            "fact": fact,
            "op": op,
            "value": value,
            "card_uid": card_uid,
        }
        document = copy.deepcopy(_document())
        document["turn_transactions"] = [
            {
                "transaction_id": "main-start-search-continue",
                "priority": 2000,
                "goal_id": "core-online",
                "deadline_turns": 0,
                "when": [condition("prompt_kind", "eq", "main")],
                "continue_when": [condition("turn_number", "eq", 3)],
                "success_when": [],
                "abort_when": [],
                "methods": [
                    {
                        "method_id": "search-after-main",
                        "priority": 1000,
                        "when": [],
                        "steps": [
                            {
                                "step_id": "open-search",
                                "prompt_kinds": ["main"],
                                "goal_id": "core-online",
                                "required_when": [],
                                "complete_when": [
                                    condition("prompt_kind", "eq", "search")
                                ],
                                "option_when": [
                                    condition("option.card_uid", "eq", IONO)
                                ],
                                "score_bonus": 900000,
                                "selection_count": 1,
                                "terminal": False,
                                "checkpoint": True,
                                "required_before_attack": True,
                            },
                            {
                                "step_id": "bind-fresh-search-window",
                                "prompt_kinds": ["search"],
                                "goal_id": "core-online",
                                "required_when": [],
                                "complete_when": [],
                                "option_when": [
                                    condition("option.card_uid", "eq", TM_EVOLUTION)
                                ],
                                "score_bonus": 900000,
                                "selection_count": 1,
                                "terminal": True,
                                "checkpoint": True,
                                "required_before_attack": True,
                            },
                        ],
                    }
                ],
            }
        ]
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)

        search = _frame([_option(0, "search", card_uid=TM_EVOLUTION)], turn=3)
        search["prompt_kind"] = "search"
        unrelated = TurnTransactionJournal("match-unrelated", 0, "test.package@1")
        unrelated_decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy, search, turn_transaction_journal=unrelated
        )
        self.assertIsNone(
            unrelated_decision.audit["turn_transaction"]["transaction_id"]
        )

        journal = TurnTransactionJournal("match-continued", 0, "test.package@1")
        main = _frame([_option(0, "play_trainer", card_uid=IONO)], turn=3)
        started = CompetitivePolicyV2Runtime.decide(
            compiled.policy, main, turn_transaction_journal=journal
        )
        self.assertEqual(started.selected_indexes, [0])
        continued = CompetitivePolicyV2Runtime.decide(
            compiled.policy, search, turn_transaction_journal=journal
        )
        self.assertEqual(continued.selected_indexes, [0])
        self.assertEqual(
            continued.audit["turn_transaction"]["step_id"],
            "bind-fresh-search-window",
        )

    def test_no_current_safe_debt_does_not_create_a_broad_attack_last_rule(self) -> None:
        frame = _frame([_option(0, "attack", damage=160)])
        decision = CompetitivePolicyV2Runtime.decide(
            self.policy,
            frame,
            turn_transaction_journal=self.journal,
        )

        self.assertEqual(decision.selected_indexes, [0])
        self.assertFalse(decision.audit["turn_transaction"]["attack_commit_blocked"])
        self.assertEqual(decision.audit["turn_transaction"]["event"], "no_current_safe_step")

    def test_declared_safe_debt_preempts_end_turn_commit(self) -> None:
        frame = _frame(
            [
                _option(0, "play_trainer", card_uid=IONO),
                _option(1, "end_turn"),
            ]
        )
        decision = CompetitivePolicyV2Runtime.decide(
            self.policy,
            frame,
            turn_transaction_journal=TurnTransactionJournal(
                "match-end-commit", 0, "test.package@1"
            ),
        )

        self.assertEqual(decision.selected_indexes, [0])
        self.assertTrue(decision.audit["turn_transaction"]["turn_commit_blocked"])
        self.assertFalse(decision.audit["turn_transaction"]["attack_commit_blocked"])
        self.assertTrue(decision.audit["turn_contract"]["route_authority_applied"])

    def test_transaction_can_require_a_legal_attack_in_the_current_window(self) -> None:
        document = copy.deepcopy(_document())
        document["turn_transactions"][0]["methods"][0]["steps"][0][
            "required_when"
        ].append(
            {
                "fact": "window.attack_option_count",
                "op": "gt",
                "value": 0,
                "card_uid": None,
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)

        without_attack = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            _frame(
                [
                    _option(0, "play_trainer", card_uid=IONO),
                    _option(1, "end_turn"),
                ]
            ),
            turn_transaction_journal=TurnTransactionJournal(
                "match-no-attack", 0, "test.package@1"
            ),
        )
        with_attack = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            _frame(
                [
                    _option(0, "attack", damage=160),
                    _option(1, "play_trainer", card_uid=IONO),
                ]
            ),
            turn_transaction_journal=TurnTransactionJournal(
                "match-live-attack", 0, "test.package@1"
            ),
        )

        self.assertEqual(without_attack.selected_indexes, [1])
        self.assertEqual(with_attack.selected_indexes, [1])
        self.assertEqual(
            with_attack.audit["turn_transaction"]["step_id"], "refresh-hand"
        )

    def test_transaction_debt_does_not_preempt_a_better_noncommit_action(self) -> None:
        document = copy.deepcopy(_document())
        document["turn_transactions"][0]["methods"][0]["steps"][0][
            "score_bonus"
        ] = 900000
        document["turn_transactions"][0]["methods"][0]["steps"][0][
            "terminal"
        ] = True
        document["rules"].append(
            {
                "rule_id": "fund-before-supporter",
                "goal_id": "core-online",
                "goal_stage": "deploy",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 400000,
                "when": [
                    {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None}
                ],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
                _option(2, "attach_energy", card_uid=DARK),
            ]
        )

        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_transaction_journal=TurnTransactionJournal(
                "match-noncommit", 0, "test.package@1"
            ),
        )

        self.assertEqual(decision.selected_indexes, [2])
        self.assertEqual(decision.audit["turn_transaction"]["step_id"], "refresh-hand")
        self.assertFalse(decision.audit["turn_contract"]["route_authority_applied"])

    def test_sequence_barrier_owns_the_current_noncommit_ordering_point(self) -> None:
        document = copy.deepcopy(_document())
        transaction_step = document["turn_transactions"][0]["methods"][0]["steps"][0]
        transaction_step["score_bonus"] = 900000
        transaction_step["sequence_barrier"] = True
        document["rules"].append(
            {
                "rule_id": "independent-fund-proposal",
                "goal_id": "core-online",
                "goal_stage": "deploy",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 400000,
                "when": [
                    {
                        "fact": "option.kind",
                        "op": "eq",
                        "value": "attach_energy",
                        "card_uid": None,
                    }
                ],
                "score_terms": [],
            }
        )
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "play_trainer", card_uid=IONO),
                _option(1, "attach_energy", card_uid=DARK),
            ]
        )

        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_transaction_journal=TurnTransactionJournal(
                "match-sequence-barrier", 0, "test.package@1"
            ),
        )

        self.assertEqual(decision.selected_indexes, [0])
        self.assertTrue(decision.audit["turn_contract"]["sequence_barrier"])
        self.assertTrue(decision.audit["turn_contract"]["route_authority_applied"])

    def test_transaction_arbitration_keeps_independent_turn_route_proposal(self) -> None:
        document = copy.deepcopy(_document())
        transaction_step = document["turn_transactions"][0]["methods"][0]["steps"][0]
        transaction_step["score_bonus"] = 900000
        transaction_step["terminal"] = True
        document["turn_routes"] = [
            {
                "route_id": "supporter-before-commit",
                "priority": 1000,
                "goal_id": "core-online",
                "owner_goal_id": "core-online",
                "bridge_goal_id": "core-online",
                "pivot_goal_id": "core-online",
                "when": [],
                "steps": [
                    {
                        "step_id": "disrupt-before-tm",
                        "prompt_kinds": ["main"],
                        "goal_id": "core-online",
                        "when": [],
                        "option_when": [
                            {
                                "fact": "option.card_uid",
                                "op": "eq",
                                "value": IONO,
                                "card_uid": None,
                            }
                        ],
                        "score_bonus": 600000,
                        "selection_count": 1,
                        "terminal": False,
                        "checkpoint": True,
                    }
                ],
            }
        ]
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids={DARK, GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        frame = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
                _option(2, "play_trainer", card_uid=TM_EVOLUTION),
            ]
        )

        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_transaction_journal=TurnTransactionJournal(
                "match-route-arbitration", 0, "test.package@1"
            ),
        )

        self.assertEqual(decision.selected_indexes, [1])
        self.assertFalse(decision.audit["turn_contract"]["route_authority_applied"])
        self.assertEqual(
            decision.audit["turn_contract"]["proposal_route_id"],
            "supporter-before-commit",
        )
        matched = {
            rule["rule_id"]
            for card in decision.audit["scorecards"]
            for rule in card["matched_rules"]
        }
        self.assertIn(
            "@turn_route.supporter-before-commit.disrupt-before-tm", matched
        )

    def test_base_terminal_and_veto_authority_remain_final(self) -> None:
        frame = _frame(
            [
                _option(0, "attack", damage=160),
                _option(1, "play_trainer", card_uid=IONO),
            ]
        )
        terminal = CompetitivePolicyV2Runtime.decide(
            self.policy,
            frame,
            terminal_indexes=[0],
            turn_transaction_journal=self.journal,
        )
        vetoed = CompetitivePolicyV2Runtime.decide(
            self.policy,
            copy.deepcopy(frame),
            base_vetoed_indexes=[1],
            turn_transaction_journal=self.journal,
        )

        self.assertEqual(terminal.selected_indexes, [0])
        self.assertEqual(terminal.audit["owner_layer"], "terminal")
        self.assertEqual(vetoed.selected_indexes, [0])
        self.assertFalse(vetoed.audit["turn_contract"]["route_authority_applied"])


if __name__ == "__main__":
    unittest.main()
