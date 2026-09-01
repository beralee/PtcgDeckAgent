from __future__ import annotations

import copy
import unittest

from scripts.ai.ptcgdap.public_damage_planning import (
    PublicDamageCapabilityRegistry,
    PublicDamagePlanner,
    SemanticTransactionJournal,
)
from scripts.ai.ptcgdap.competitive_policy_v2 import (
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)


GRIMMSNARL = "CSV10C_148"
FROSLASS = "CSV7C_059"
MUNKIDORI = "CSV8C_094"
OGERPON = "CSV8C_028"
LEAFEON_EX = "CSV9.5C_006"
DEFIANCE_BAND = "CSV1C_117"
DARK = "CSVE1C_DAR"


def _slot(
    entity_serial: int,
    card_serial: int,
    uid: str,
    *,
    remaining_hp: int,
    max_hp: int,
    prize_value: int,
    damage_counters: int = 0,
    energy_uids: list[str] | None = None,
    tool_uid: str | None = None,
    stack_uids: list[str] | None = None,
) -> dict[str, object]:
    energies = list(energy_uids or [])
    return {
        "serial": card_serial,
        "entity_serial": entity_serial,
        "local_card_uid": uid,
        "remaining_hp": remaining_hp,
        "max_hp": max_hp,
        "damage_counters": damage_counters,
        "prize_value": prize_value,
        "attached_energy_count": len(energies),
        "attached_energy_uids": energies,
        "attached_tool_uid": tool_uid,
        "pokemon_stack_uids": list(stack_uids or [uid]),
        "minimum_attack_energy_count": 2,
        "attack_ready": len(energies) >= 2,
        "energy_debt": max(0, 2 - len(energies)),
    }


def _option(index: int, kind: str, **updates: object) -> dict[str, object]:
    value: dict[str, object] = {
        "index": index,
        "kind": kind,
        "card_uid": None,
        "card_serial": None,
        "source_uid": None,
        "source_serial": None,
        "source_entity_serial": None,
        "target_uid": None,
        "target_serial": None,
        "target_entity_serial": None,
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
        "option_type_raw": 13 if kind == "attack" else 3,
        "option_player_index": 0,
    }
    value.update(updates)
    return value


def _frame(*, behind: bool = True, target_card_serial: int = 201) -> dict[str, object]:
    active = _slot(
        100,
        101,
        GRIMMSNARL,
        remaining_hp=260,
        max_hp=320,
        prize_value=2,
        damage_counters=60,
        energy_uids=[DARK, DARK],
        tool_uid=DEFIANCE_BAND,
    )
    own_bench = [
        _slot(110, 111, FROSLASS, remaining_hp=90, max_hp=90, prize_value=1),
        _slot(120, 121, FROSLASS, remaining_hp=90, max_hp=90, prize_value=1),
        _slot(
            130,
            131,
            MUNKIDORI,
            remaining_hp=90,
            max_hp=110,
            prize_value=1,
            damage_counters=20,
            energy_uids=[DARK],
        ),
    ]
    opponent_active = _slot(
        900,
        target_card_serial,
        OGERPON,
        remaining_hp=210,
        max_hp=210,
        prize_value=2,
        energy_uids=["CSVE1C_GRA"],
    )
    return {
        "schema_version": 2,
        "profile_id": "ptcgdap-competitive-public-frame-v2",
        "sequence": 1,
        "seat": 0,
        "prompt_kind": "main_action",
        "source": {"public_observation_hash": "A" * 64, "window_id": "B" * 64},
        "public_state": {
            "turn_number": 8,
            "phase": "MAIN",
            "self": {
                "hand": [],
                "active": [active],
                "bench": own_bench,
                "discard": [],
                "deck_count": 25,
                "prizes_remaining": 4 if behind else 2,
            },
            "opponent": {
                "hand_count": 5,
                "active": [opponent_active],
                "bench": [],
                "discard": [],
                "deck_count": 24,
                "prizes_remaining": 2 if behind else 4,
            },
        },
        "select_semantics": {
            "min_count": 1,
            "max_count": 1,
            "select_type_raw": 6,
            "select_context_raw": 36,
        },
        "options": [
            _option(
                0,
                "attack",
                source_uid=GRIMMSNARL,
                source_serial=101,
                source_entity_serial=100,
                attack_index=0,
            ),
            _option(1, "end_turn", option_type_raw=14),
        ],
    }


def _damage_plans() -> list[dict[str, object]]:
    return [
        {
            "plan_id": "ogerpon-prize-map",
            "goal_id": "take-two-prize-knockout",
            "priority": 0,
            "horizon_attack_windows": 2,
            "capability_ids": [
                "attack.fixed_split.v1",
                "attack.bench_heal.v1",
                "between_turn.ability_counter.v1",
                "ability.move_damage_counters.v1",
                "tool.conditional_active_damage_bonus.v1",
                "attack.mass_devolution.v1",
            ],
            "target_roles": ["opponent.active", "opponent.bench"],
            "objective_order": [
                "attack_windows",
                "prize_yield",
                "remaining_debt",
                "overkill",
                "response_risk",
            ],
        }
    ]


def _transactions() -> list[dict[str, object]]:
    return [
        {
            "transaction_id": "ogerpon-two-prize-conversion",
            "goal_id": "take-two-prize-knockout",
            "priority": 0,
            "max_own_turns": 2,
            "target_role": "opponent.pokemon",
            "start_when": [],
            "continue_when": [],
            "success_when": [
                {"fact": "transaction.remaining_damage_debt", "op": "eq", "value": 0, "card_uid": None}
            ],
            "abort_when": [],
            "step_prompt_kinds": ["main_action", "attack", "damage_target"],
        }
    ]


def _three_transactions() -> list[dict[str, object]]:
    return [
        {
            "transaction_id": "devolution-finish",
            "goal_id": "take-two-prize-knockout",
            "priority": 20,
            "max_own_turns": 1,
            "target_role": "opponent.pokemon",
            "start_when": [
                {"fact": "self.hand.count_uid", "op": "gt", "value": 0, "card_uid": "CSV5C_120"}
            ],
            "continue_when": [],
            "success_when": [],
            "abort_when": [],
            "step_prompt_kinds": ["main_action", "damage_target"],
        },
        {
            "transaction_id": "backup-grimmsnarl-ready",
            "goal_id": "take-two-prize-knockout",
            "priority": 10,
            "max_own_turns": 2,
            "target_role": "self.pokemon",
            "start_when": [
                {"fact": "transaction.candidate.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": None},
                {"fact": "transaction.candidate.remaining_energy_debt", "op": "gt", "value": 0, "card_uid": None}
            ],
            "continue_when": [
                {"fact": "transaction.remaining_energy_debt", "op": "gt", "value": 0, "card_uid": None}
            ],
            "success_when": [
                {"fact": "transaction.remaining_energy_debt", "op": "eq", "value": 0, "card_uid": None}
            ],
            "abort_when": [],
            "step_prompt_kinds": ["main_action", "search", "assignment_source", "assignment_target"],
        },
        {
            "transaction_id": "ogerpon-two-prize-conversion",
            "goal_id": "take-two-prize-knockout",
            "priority": 0,
            "max_own_turns": 2,
            "target_role": "opponent.pokemon",
            "start_when": [
                {"fact": "damage.best_prize_yield", "op": "eq", "value": 2, "card_uid": None}
            ],
            "continue_when": [
                {"fact": "transaction.remaining_damage_debt", "op": "gt", "value": 0, "card_uid": None}
            ],
            "success_when": [
                {"fact": "transaction.remaining_damage_debt", "op": "eq", "value": 0, "card_uid": None}
            ],
            "abort_when": [
                {"fact": "opponent.prizes_remaining", "op": "eq", "value": 0, "card_uid": None}
            ],
            "step_prompt_kinds": ["main_action", "attack", "damage_target"],
        },
    ]


def _policy() -> dict[str, object]:
    return {
        "schema_version": 2,
        "adapter_id": "dev.bodao-yongzhe.marnies-gift-box",
        "adapter_version": 2,
        "goals": [
            {
                "goal_id": "take-two-prize-knockout",
                "stage": "execute",
                "priority": 100,
                "requirements": [
                    {
                        "card_uid": GRIMMSNARL,
                        "ready_target_count": 1,
                        "energy_required": 2,
                        "energy_requirements": [{"energy_uid": DARK, "count": 2}],
                        "attack_index": 0,
                    }
                ],
            }
        ],
        "count_rules": [],
        "rules": [
            {
                "rule_id": "damage-plan.prefer-two-prize-attack",
                "goal_id": "take-two-prize-knockout",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [
                    {"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": None},
                    {"fact": "damage.option.prize_yield", "op": "eq", "value": 2, "card_uid": None},
                ],
                "score_terms": [
                    {"fact": "damage.option.remaining_debt", "coefficient": -10, "minimum": 0, "maximum": 400}
                ],
            }
        ],
        "damage_plans": _damage_plans(),
        "semantic_transactions": _transactions(),
    }


class PublicDamagePlanningTests(unittest.TestCase):
    def test_ready_bench_heal_is_public_response_risk_but_unready_heal_is_not(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        self.assertIn("attack.bench_heal.v1", registry.card(LEAFEON_EX)["capability_ids"])
        frame = _frame(behind=False)
        frame["public_state"]["opponent"]["active"] = [
            _slot(
                900,
                901,
                LEAFEON_EX,
                remaining_hp=260,
                max_hp=270,
                prize_value=2,
                energy_uids=["CSVE1C_GRA", "CSVE1C_WAT", "CSVE1C_COL"],
            )
        ]
        frame["public_state"]["opponent"]["bench"] = [
            _slot(910, 911, OGERPON, remaining_hp=100, max_hp=210, prize_value=2)
        ]
        frame["options"] = [
            _option(
                0,
                "use_ability",
                source_uid=MUNKIDORI,
                source_entity_serial=130,
                ability_index=0,
            )
        ]
        ready = PublicDamagePlanner.calculate(frame, _damage_plans(), registry)
        self.assertTrue(ready["accepted"], ready)
        self.assertGreaterEqual(ready["targets"]["910"]["response_risk"], 100)

        unready = copy.deepcopy(frame)
        unready["source"]["window_id"] = "E" * 64
        unready["public_state"]["opponent"]["active"][0]["attached_energy_uids"] = [
            "CSVE1C_GRA",
            "CSVE1C_WAT",
        ]
        unready["public_state"]["opponent"]["active"][0]["attached_energy_count"] = 2
        result = PublicDamagePlanner.calculate(unready, _damage_plans(), registry)
        self.assertLess(result["targets"]["910"]["response_risk"], 100)

    def test_transfer_plan_counts_current_legal_movers_and_finishes_easy_ko_before_heal(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        frame = _frame(behind=False)
        frame["public_state"]["self"]["bench"].extend(
            [
                _slot(
                    131,
                    132,
                    MUNKIDORI,
                    remaining_hp=80,
                    max_hp=110,
                    prize_value=1,
                    damage_counters=30,
                    energy_uids=[DARK],
                ),
                _slot(
                    132,
                    133,
                    MUNKIDORI,
                    remaining_hp=80,
                    max_hp=110,
                    prize_value=1,
                    damage_counters=30,
                    energy_uids=[DARK],
                ),
            ]
        )
        frame["public_state"]["opponent"]["active"] = [
            _slot(
                900,
                901,
                LEAFEON_EX,
                remaining_hp=260,
                max_hp=270,
                prize_value=2,
                energy_uids=["CSVE1C_GRA", "CSVE1C_WAT", "CSVE1C_COL"],
            )
        ]
        frame["public_state"]["opponent"]["bench"] = [
            _slot(910, 911, OGERPON, remaining_hp=100, max_hp=210, prize_value=2),
            _slot(920, 921, OGERPON, remaining_hp=70, max_hp=210, prize_value=1),
        ]
        frame["options"] = [
            _option(
                index,
                "use_ability",
                source_uid=MUNKIDORI,
                source_entity_serial=entity,
                ability_index=0,
            )
            for index, entity in enumerate((130, 131, 132))
        ]
        result = PublicDamagePlanner.calculate(frame, _damage_plans(), registry)
        self.assertTrue(result["accepted"], result)
        self.assertEqual(3, result["facts"]["damage.available_mover_count"])
        self.assertEqual(920, result["facts"]["damage.best_transfer_target_entity_serial"])
        self.assertEqual(1, result["facts"]["damage.best_transfer_attack_windows_to_ko"])

    def test_current_attack_exposes_exact_two_prize_gust_target(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        frame = _frame(behind=True)
        frame["public_state"]["opponent"]["active"] = [
            _slot(
                900,
                901,
                LEAFEON_EX,
                remaining_hp=260,
                max_hp=270,
                prize_value=2,
                energy_uids=["CSVE1C_GRA", "CSVE1C_WAT", "CSVE1C_COL"],
            )
        ]
        frame["public_state"]["opponent"]["bench"] = [
            _slot(910, 911, OGERPON, remaining_hp=210, max_hp=210, prize_value=2)
        ]
        frame["options"] = [
            _option(
                0,
                "attack",
                source_uid=GRIMMSNARL,
                source_serial=101,
                source_entity_serial=100,
                attack_index=0,
                projected_damage=210,
            ),
            _option(1, "play_trainer", card_uid="CSV6C_114"),
            _option(2, "play_trainer", card_uid="CSVH1aC_023"),
        ]
        result = PublicDamagePlanner.calculate(frame, _damage_plans(), registry)
        self.assertTrue(result["accepted"], result)
        self.assertEqual(2, result["options"]["0"]["attack_windows_to_ko"])
        self.assertEqual(210, result["facts"]["damage.current_attack_damage"])
        self.assertEqual(910, result["facts"]["damage.best_gust_target_entity_serial"])
        self.assertEqual(1, result["facts"]["damage.best_gust_attack_windows_to_ko"])
        self.assertEqual(2, result["facts"]["damage.best_gust_prize_yield"])

    def test_competitive_policy_extensions_compile_and_drive_current_window(self) -> None:
        allowed = {GRIMMSNARL, FROSLASS, MUNKIDORI, DEFIANCE_BAND, DARK}
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            _policy(), allowed_card_uids=allowed
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        journal = SemanticTransactionJournal("match-1", 0, "package-identity")
        decision = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            _frame(behind=False),
            transaction_journal=journal,
        )
        self.assertTrue(decision.accepted, decision.error_code)
        self.assertEqual([0], decision.selected_indexes)
        self.assertEqual(30, decision.audit["damage_plan"]["facts"]["damage.best_remaining_debt"])
        self.assertEqual("start", decision.audit["semantic_transaction"]["event"])

    def test_registry_is_catalog_derived_and_effect_capability_bound(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        self.assertTrue(registry.validate_integrity())
        grimmsnarl = registry.card(GRIMMSNARL)
        self.assertEqual("863479acd128e1e5e2643a3a1e77ce26", grimmsnarl["effect_id"])
        self.assertIn("attack.fixed_split.v1", grimmsnarl["capability_ids"])
        self.assertNotIn("name", grimmsnarl)
        self.assertEqual(180, grimmsnarl["attacks"][0]["active_damage"])
        self.assertEqual(30, grimmsnarl["attacks"][0]["bench_damage"])

    def test_damage_plan_handles_defiance_froslass_and_munkidori(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        result = PublicDamagePlanner.calculate(_frame(behind=True), _damage_plans(), registry)
        self.assertTrue(result["accepted"], result)
        self.assertEqual(0, result["facts"]["damage.available_mover_count"])
        self.assertEqual(0, result["facts"]["damage.best_transfer_count"])
        self.assertEqual(2, result["facts"]["damage.froslass_check_count"])
        attack = result["options"]["0"]
        self.assertEqual(210, attack["projected_damage"])
        self.assertEqual(1, attack["attack_windows_to_ko"])
        self.assertEqual(2, attack["prize_yield"])
        self.assertEqual(0, attack["remaining_debt"])
        self.assertEqual(0, attack["overkill"])

        even = PublicDamagePlanner.calculate(_frame(behind=False), _damage_plans(), registry)
        self.assertEqual(180, even["options"]["0"]["projected_damage"])
        self.assertEqual(30, even["options"]["0"]["remaining_debt"])

    def test_current_attack_option_post_modifier_zero_damage_is_authoritative(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        blocked = _frame(behind=False)
        blocked["public_state"]["opponent"]["bench"] = [
            _slot(910, 911, OGERPON, remaining_hp=210, max_hp=210, prize_value=2),
        ]
        blocked["options"][0]["projected_damage"] = 0
        result = PublicDamagePlanner.calculate(blocked, _damage_plans(), registry)
        self.assertTrue(result["accepted"], result)
        self.assertEqual(0, result["options"]["0"]["projected_damage"])
        self.assertEqual(30, result["options"]["0"]["bench_damage"])
        self.assertEqual(30, result["facts"]["damage.current_attack_bench_damage"])
        self.assertEqual(3, result["options"]["0"]["attack_windows_to_ko"])
        self.assertEqual(210, result["options"]["0"]["remaining_debt"])

        unblocked = copy.deepcopy(blocked)
        unblocked["source"]["window_id"] = "D" * 64
        unblocked["options"][0]["projected_damage"] = 180
        restored = PublicDamagePlanner.calculate(unblocked, _damage_plans(), registry)
        self.assertEqual(180, restored["options"]["0"]["projected_damage"])
        self.assertEqual(30, restored["options"]["0"]["remaining_debt"])

    def test_semantic_option_reorder_changes_only_indexes(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        frame = _frame()
        original = PublicDamagePlanner.calculate(frame, _damage_plans(), registry)
        reordered = copy.deepcopy(frame)
        reordered["source"]["window_id"] = "C" * 64
        reordered["options"].reverse()
        for index, option in enumerate(reordered["options"]):
            option["index"] = index
        moved = PublicDamagePlanner.calculate(reordered, _damage_plans(), registry)
        self.assertEqual(original["best_target_entity_serial"], moved["best_target_entity_serial"])
        self.assertEqual(original["facts"], moved["facts"])
        self.assertNotEqual(original["audit_hash"], moved["audit_hash"])
        self.assertEqual(original["options"]["0"], moved["options"]["1"])

    def test_hidden_input_and_unknown_capability_fail_closed(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        hidden = _frame()
        hidden["private_state"] = {"deck_order": [OGERPON]}
        rejected = PublicDamagePlanner.calculate(hidden, _damage_plans(), registry)
        self.assertFalse(rejected["accepted"])
        self.assertEqual("private_damage_plan_input", rejected["error_code"])
        plans = _damage_plans()
        plans[0]["capability_ids"].append("unknown.capability")
        unknown = PublicDamagePlanner.calculate(_frame(), plans, registry)
        self.assertFalse(unknown["accepted"])
        self.assertEqual("unknown_damage_capability", unknown["error_code"])

    def test_transaction_survives_top_card_change_but_not_scope_or_target_loss(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        damage = PublicDamagePlanner.calculate(_frame(behind=False), _damage_plans(), registry)
        journal = SemanticTransactionJournal("match-1", 0, "PKG" * 21 + "P")
        started = journal.advance(_frame(behind=False), _transactions(), damage)
        self.assertEqual("start", started["event"])
        self.assertEqual(900, started["state"]["target_entity_serial"])
        self.assertEqual(
            {
                "transaction_id",
                "goal_id",
                "phase",
                "target_entity_serial",
                "remaining_damage_debt",
                "remaining_energy_debt",
                "deadline_turn",
            },
            set(started["state"]),
        )

        evolved = _frame(behind=False, target_card_serial=999)
        evolved["sequence"] = 2
        evolved_damage = PublicDamagePlanner.calculate(evolved, _damage_plans(), registry)
        continued = journal.advance(evolved, _transactions(), evolved_damage)
        self.assertIn(continued["event"], {"continue", "replan"})
        self.assertEqual(900, continued["state"]["target_entity_serial"])

        wrong_seat = copy.deepcopy(evolved)
        wrong_seat["seat"] = 1
        isolated = journal.advance(wrong_seat, _transactions(), evolved_damage)
        self.assertEqual("scope_mismatch", isolated["error_code"])

        missing = copy.deepcopy(evolved)
        missing["sequence"] = 3
        missing["public_state"]["opponent"]["active"] = []
        missing_damage = PublicDamagePlanner.calculate(missing, _damage_plans(), registry)
        aborted = journal.advance(missing, _transactions(), missing_damage)
        self.assertEqual("abort", aborted["event"])
        self.assertEqual("target_unavailable", aborted["reason"])

    def test_transaction_selects_highest_eligible_template_and_tracks_energy_debt(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        frame = _frame(behind=False)
        frame["public_state"]["self"]["bench"].append(
            _slot(
                140,
                141,
                GRIMMSNARL,
                remaining_hp=320,
                max_hp=320,
                prize_value=2,
                energy_uids=[DARK],
            )
        )
        damage = PublicDamagePlanner.calculate(frame, _damage_plans(), registry)
        journal = SemanticTransactionJournal("match-templates", 0, "package-identity")
        started = journal.advance(frame, _three_transactions(), damage)
        self.assertEqual("backup-grimmsnarl-ready", started["state"]["transaction_id"])
        self.assertEqual(140, started["state"]["target_entity_serial"])
        self.assertEqual(1, started["state"]["remaining_energy_debt"])

        funded = copy.deepcopy(frame)
        funded["sequence"] = 2
        funded["source"]["window_id"] = "D" * 64
        funded["public_state"]["self"]["bench"][-1]["attached_energy_count"] = 2
        funded["public_state"]["self"]["bench"][-1]["attached_energy_uids"] = [DARK, DARK]
        funded["public_state"]["self"]["bench"][-1]["energy_debt"] = 0
        funded["public_state"]["self"]["bench"][-1]["attack_ready"] = True
        completed = journal.advance(
            funded,
            _three_transactions(),
            PublicDamagePlanner.calculate(funded, _damage_plans(), registry),
        )
        self.assertEqual("complete", completed["event"])
        self.assertEqual(0, completed["state"]["remaining_energy_debt"])

    def test_transaction_template_conditions_and_prompt_gate_are_enforced(self) -> None:
        registry = PublicDamageCapabilityRegistry.load_default()
        frame = _frame(behind=False)
        frame["prompt_kind"] = "setup_active"
        damage = PublicDamagePlanner.calculate(frame, _damage_plans(), registry)
        journal = SemanticTransactionJournal("match-gate", 0, "package-identity")
        idle = journal.advance(frame, _three_transactions(), damage)
        self.assertEqual("idle", idle["event"])
        self.assertEqual("no_eligible_transaction", idle["reason"])


if __name__ == "__main__":
    unittest.main()
