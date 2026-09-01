"""Portable Competitive Policy IR v2 reference runtime.

The module consumes only a closed public frame and returns indexes from the
current immutable option window.  It deliberately owns no engine objects,
bindings, tickets or commands.  Base cardinality, forced selections, hard
tiers and veto remain the final adjudication boundary.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass
import math
import re
from types import MappingProxyType
from typing import Any, Mapping

from .cabt_tree_hash import CabtTreeHashError, public_observation_hash
from .public_damage_planning import (
    PublicDamageCapabilityRegistry,
    PublicDamagePlanner,
    SemanticTransactionJournal,
    validate_damage_plans,
    validate_semantic_transactions,
)
from .turn_transaction_planner import TurnTransactionJournal
from .turn_program_generator import TurnProgramGenerator
from .turn_program_planner import TurnProgramJournal, TurnProgramShadowPlanner


PROFILE_ID = "ptcgdap-competitive-policy-v2"
FRAME_PROFILE_ID = "ptcgdap-competitive-public-frame-v2"
MAX_SAFE_INTEGER = 9_007_199_254_740_991
MAX_SCORE = 1_000_000_000
GOAL_STAGES = frozenset(
    {"acquire", "deploy", "fund", "ready", "execute", "maintain", "recover"}
)
CHANNELS = frozenset({"macro", "tactical", "interaction", "future", "uncertainty"})
OPS = frozenset({"eq", "ne", "lt", "lte", "gt", "gte", "contains", "not_contains"})
COUNT_MODES = frozenset(
    {
        "fixed",
        "goal_energy_debt",
        "goal_missing_energy_sources",
        "distinct_card_uids",
        "ceil_public_fact_divisor",
        "ceil_public_fact_divisor_with_reserve",
    }
)
IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
LOCAL_UID = re.compile(r"^[A-Za-z0-9.]+_[A-Za-z0-9._]+$")
UPPER_SHA = re.compile(r"^[0-9A-F]{64}$")

# Locked to the official CABT sample bundle. New enum values may be appended
# upstream; an unknown raw integer deliberately maps to None so symbolic rules
# fail closed while select.type_raw/select.context_raw remain auditable.
SELECT_TYPE_NAMES = (
    "main",
    "card",
    "attached_card",
    "card_or_attached_card",
    "energy",
    "skill",
    "attack",
    "evolve",
    "count",
    "yes_no",
    "special_condition",
)
SELECT_CONTEXT_NAMES = (
    "main",
    "setup_active_pokemon",
    "setup_bench_pokemon",
    "switch",
    "to_active",
    "to_bench",
    "to_field",
    "to_hand",
    "discard",
    "to_deck",
    "to_deck_bottom",
    "to_prize",
    "not_move",
    "damage_counter",
    "damage_counter_any",
    "damage",
    "remove_damage_counter",
    "heal",
    "evolves_from",
    "evolves_to",
    "devolve",
    "attach_from",
    "attach_to",
    "detach_from",
    "look",
    "effect_target",
    "discard_energy_card",
    "discard_tool_card",
    "switch_energy_card",
    "discard_card_or_attached_card",
    "discard_energy",
    "to_hand_energy",
    "to_deck_energy",
    "switch_energy",
    "skill_order",
    "attack",
    "disable_attack",
    "evolve",
    "draw_count",
    "damage_counter_count",
    "remove_damage_counter_count",
    "is_first",
    "mulligan",
    "activate",
    "first_effect",
    "more_devolve",
    "coin_head",
    "affect_special_condition",
    "recover_special_condition",
)

SCALAR_FACTS = frozenset(
    {
        "prompt_kind",
        "select.type",
        "select.context",
        "select.type_raw",
        "select.context_raw",
        "turn_number",
        "turn.supporter_available",
        "turn.manual_attachment_available",
        "turn.retreat_available",
        "self.prizes_remaining",
        "opponent.prizes_remaining",
        "self.deck_count",
        "opponent.deck_count",
        "self.hand_count",
        "opponent.hand_count",
        "self.bench_count",
        "self.bench_capacity",
        "self.bench_space",
        "self.bench_open",
        "opponent.bench_count",
        "self.active.remaining_hp",
        "self.active.prize_value",
        "self.active.attached_tool_uid",
        "opponent.active.remaining_hp",
        "opponent.active.prize_value",
        "window.source_uid",
        "window.option_kind",
        "window.attack_option_count",
        "select.min_count",
        "select.max_count",
        "option.index",
        "option.kind",
        "option.card_uid",
        "option.source_uid",
        "option.source_serial",
        "option.source_entity_serial",
        "option.target_uid",
        "option.target_serial",
        "option.target_entity_serial",
        "option.target_remaining_hp",
        "option.target_prize_value",
        "option.target_attached_energy_count",
        "option.target_attached_energy_uids",
        "option.target_minimum_attack_energy_count",
        "option.target_attack_ready",
        "option.target_energy_debt",
        "option.projected_damage",
        "option.projected_knockout",
        "option.requires_interaction",
        "option.attack_index",
        "option.option_number",
        "option.ability_index",
        "option.pending_assignment_count",
        "option.tags",
        "option.target_attached_energy_uids",
        "option.source_is_active",
        "option.target_is_active",
        "self.bench_open",
        "goal.energy_debt",
        "goal.ready_count",
        "goal.deployed_count",
        "goal.active_ready_count",
        "goal.bench_ready_count",
        "goal.near_ready_count",
        "goal.board_energy_count",
        "goal.hand_energy_count",
        "goal.discard_energy_count",
        "goal.immediate",
        "goal.complete",
        "goal.option.matches_target",
        "goal.option.acquires_missing_target",
        "goal.option.deploys_missing_target",
        "goal.option.supplies_missing_energy",
        "goal.option.funds_target",
        "goal.option.completes_target",
        "goal.option.pivots_ready_target",
        "goal.option.executes_requirement",
        "goal.option.target_energy_debt",
        "goal.option.progress",
        "goal.option.is_max_progress",
        "goal.window.max_progress",
        "goal.option.is_max_setup_progress",
        "goal.window.max_setup_progress",
        "threat.own_attacks_to_win",
        "threat.opponent_attacks_to_win",
        "threat.tempo_margin",
        "damage.movable_counter_count",
        "damage.available_mover_count",
        "damage.froslass_check_count",
        "damage.best_transfer_count",
        "damage.best_transfer_target_entity_serial",
        "damage.best_transfer_attack_windows_to_ko",
        "damage.best_transfer_prize_yield",
        "damage.best_transfer_remaining_debt",
        "damage.best_target_entity_serial",
        "damage.best_attack_windows_to_ko",
        "damage.best_prize_yield",
        "damage.best_remaining_debt",
        "damage.current_attack_damage",
        "damage.current_attack_bench_damage",
        "damage.best_gust_target_entity_serial",
        "damage.best_gust_attack_windows_to_ko",
        "damage.best_gust_prize_yield",
        "damage.best_gust_remaining_debt",
        "damage.option.target_entity_serial",
        "damage.option.projected_damage",
        "damage.option.bench_damage",
        "damage.option.attack_windows_to_ko",
        "damage.option.prize_yield",
        "damage.option.remaining_debt",
        "damage.option.overkill",
        "damage.option.response_risk",
        "transaction.active",
        "transaction.id",
        "transaction.phase",
        "transaction.target_entity_serial",
        "transaction.remaining_damage_debt",
        "transaction.remaining_energy_debt",
        "transaction.deadline_turn",
        "transaction.candidate.card_uid",
        "transaction.candidate.remaining_damage_debt",
        "transaction.candidate.remaining_energy_debt",
        "transaction.candidate.is_damage_best",
        "transaction.candidate.is_transfer_best",
        "transaction.candidate.is_gust_best",
        "transaction.option.matches_target",
        "transaction.candidate.is_damage_best",
        "transaction.candidate.is_transfer_best",
        "transaction.candidate.is_gust_best",
    }
)
ZONE_FACTS = frozenset(
    {
        "self.hand.count_uid",
        "self.active.count_uid",
        "self.bench.count_uid",
        "self.bench.evolution_eligible_count_uid",
        "self.discard.count_uid",
        "self.board.count_uid",
        "opponent.active.count_uid",
        "opponent.bench.count_uid",
        "opponent.discard.count_uid",
        "opponent.board.count_uid",
    }
)
ENERGY_ZONE_FACTS = frozenset(
    {
        "self.active.energy_count_uid",
        "self.bench.energy_count_uid",
        "self.board.energy_count_uid",
        "opponent.active.energy_count_uid",
        "opponent.bench.energy_count_uid",
        "opponent.board.energy_count_uid",
    }
)
ENERGY_BEARING_ZONE_FACTS = frozenset(
    {
        "self.board.energy_bearing_count_uid",
        "self.bench.energy_bearing_evolution_eligible_count_uid",
    }
)
GOAL_UID_FACTS = frozenset(
    {
        "goal.deployed_count_uid",
        "goal.ready_count_uid",
        "goal.near_ready_count_uid",
        "goal.energy_debt_uid",
        "goal.active_ready_count_uid",
        "goal.bench_ready_count_uid",
    }
)
WINDOW_UID_FACTS = frozenset(
    {
        "window.option_count_card_uid",
        "window.option_count_source_uid",
        "window.option_count_target_uid",
    }
)
NUMERIC_TERM_FACTS = frozenset(
    fact
    for fact in SCALAR_FACTS
    if fact
    not in {
        "prompt_kind",
        "select.type",
        "select.context",
        "option.kind",
        "option.card_uid",
        "option.source_uid",
        "option.target_uid",
        "option.tags",
        "option.source_is_active",
        "option.target_is_active",
        "goal.complete",
        "goal.immediate",
        "goal.option.matches_target",
        "goal.option.acquires_missing_target",
        "goal.option.deploys_missing_target",
        "goal.option.supplies_missing_energy",
        "goal.option.funds_target",
        "goal.option.completes_target",
        "goal.option.pivots_ready_target",
        "goal.option.executes_requirement",
        "goal.option.is_max_progress",
        "goal.option.is_max_setup_progress",
        "turn.supporter_available",
        "turn.manual_attachment_available",
        "turn.retreat_available",
        "transaction.active",
        "transaction.id",
        "transaction.phase",
        "transaction.option.matches_target",
    }
)
PRIVATE_KEYS = frozenset(
    {
        "deck_order",
        "private_state",
        "search_begin_input",
        "callback",
        "binding",
        "ticket",
        "command",
        "object_ref",
        "instance_id",
        "raw_private_hash",
    }
)

DOCUMENT_REQUIRED_KEYS = {
    "schema_version",
    "adapter_id",
    "adapter_version",
    "goals",
    "count_rules",
    "rules",
}
DOCUMENT_KEYS = DOCUMENT_REQUIRED_KEYS | {
    "turn_routes",
    "route_candidates",
    "interaction_recipes",
    "turn_bonus_contracts",
    "damage_plans",
    "semantic_transactions",
    "turn_transactions",
}
GOAL_KEYS = {"goal_id", "stage", "priority", "requirements"}
REQUIREMENT_REQUIRED_KEYS = {"card_uid", "ready_target_count", "energy_required"}
REQUIREMENT_KEYS = REQUIREMENT_REQUIRED_KEYS | {
    "energy_requirements",
    "attack_index",
    "ability_index",
}
ENERGY_REQUIREMENT_KEYS = {"energy_uid", "count"}
COUNT_RULE_KEYS = {
    "rule_id",
    "priority",
    "goal_id",
    "mode",
    "fixed_count",
    "fact",
    "divisor",
    "when",
}
RULE_KEYS = {
    "rule_id",
    "goal_id",
    "goal_stage",
    "channel",
    "horizon",
    "confidence_milli",
    "base_score",
    "when",
    "score_terms",
}
TURN_ROUTE_KEYS = {
    "route_id",
    "priority",
    "goal_id",
    "owner_goal_id",
    "bridge_goal_id",
    "pivot_goal_id",
    "when",
    "steps",
}
ROUTE_CANDIDATE_KEYS = {
    "route_id",
    "goal_id",
    "owner_goal_id",
    "bridge_goal_id",
    "pivot_goal_id",
    "when",
    "resource_budget",
    "value",
    "steps",
}
ROUTE_RESOURCE_BUDGET_KEYS = {
    "supporter_uses",
    "manual_attachments",
    "retreats",
    "bench_slots",
    "ability_uses",
    "discard_cards",
    "search_cards",
}
ROUTE_VALUE_COMPONENTS = (
    "attack_windows",
    "prize_progress",
    "continuity",
    "resource_cost",
    "response_risk",
    "uncertainty",
)
ROUTE_VALUE_COMPONENT_KEYS = {"base", "terms"}
ROUTE_STEP_KEYS = {
    "step_id",
    "prompt_kinds",
    "goal_id",
    "when",
    "option_when",
    "score_bonus",
    "selection_count",
    "terminal",
    "checkpoint",
}
ROUTE_CANDIDATE_STEP_KEYS = ROUTE_STEP_KEYS - {"score_bonus"}
INTERACTION_RECIPE_KEYS = {
    "recipe_id",
    "priority",
    "route_id",
    "goal_id",
    "source_uids",
    "when",
    "steps",
}
TURN_BONUS_CONTRACT_KEYS = {
    "contract_id",
    "priority",
    "goal_id",
    "when",
    "bonuses",
}
TURN_BONUS_KEYS = {
    "bonus_id",
    "prompt_kinds",
    "goal_id",
    "when",
    "option_when",
    "score_bonus",
}
TURN_TRANSACTION_REQUIRED_KEYS = {
    "transaction_id",
    "priority",
    "goal_id",
    "deadline_turns",
    "when",
    "success_when",
    "abort_when",
    "methods",
}
TURN_TRANSACTION_KEYS = TURN_TRANSACTION_REQUIRED_KEYS | {"continue_when"}
TURN_TRANSACTION_METHOD_KEYS = {"method_id", "priority", "when", "steps"}
TURN_TRANSACTION_STEP_REQUIRED_KEYS = {
    "step_id",
    "prompt_kinds",
    "goal_id",
    "required_when",
    "complete_when",
    "option_when",
    "score_bonus",
    "selection_count",
    "terminal",
    "checkpoint",
    "required_before_attack",
}
TURN_TRANSACTION_STEP_KEYS = TURN_TRANSACTION_STEP_REQUIRED_KEYS | {
    "selection_groups",
    "sequence_barrier",
}
TURN_TRANSACTION_SELECTION_GROUP_KEYS = {
    "group_id",
    "selection_count",
    "option_when",
}
CONDITION_KEYS = {"fact", "op", "value", "card_uid"}
TERM_KEYS = {"fact", "coefficient", "minimum", "maximum"}
FRAME_KEYS = {
    "schema_version",
    "profile_id",
    "sequence",
    "seat",
    "prompt_kind",
    "source",
    "public_state",
    "select_semantics",
    "options",
}
SOURCE_KEYS = {"public_observation_hash", "window_id"}
STATE_KEYS = {"turn_number", "phase", "self", "opponent"}
SELF_REQUIRED_KEYS = {"hand", "active", "bench", "discard", "deck_count", "prizes_remaining"}
SELF_KEYS = SELF_REQUIRED_KEYS | {"turn", "bench_capacity"}
TURN_LEDGER_KEYS = {
    "supporter_available",
    "manual_attachment_available",
    "retreat_available",
}
OPPONENT_KEYS = {
    "hand_count",
    "active",
    "bench",
    "discard",
    "deck_count",
    "prizes_remaining",
}
SEMANTIC_KEYS = {"min_count", "max_count", "select_type_raw", "select_context_raw"}
CARD_KEYS = {"serial", "local_card_uid"}
SLOT_REQUIRED_KEYS = {
    "serial",
    "local_card_uid",
    "remaining_hp",
    "prize_value",
    "attached_energy_count",
    "attached_energy_uids",
    "minimum_attack_energy_count",
    "attack_ready",
    "energy_debt",
}
SLOT_KEYS = SLOT_REQUIRED_KEYS | {
    "entity_serial",
    "max_hp",
    "damage_counters",
    "appeared_this_turn",
    "attached_tool_uid",
    "pokemon_stack_uids",
}
OPTION_REQUIRED_KEYS = {
    "index",
    "kind",
    "card_uid",
    "card_serial",
    "source_uid",
    "source_serial",
    "target_uid",
    "target_serial",
    "target_remaining_hp",
    "target_prize_value",
    "target_attached_energy_count",
    "target_attached_energy_uids",
    "target_minimum_attack_energy_count",
    "target_attack_ready",
    "target_energy_debt",
    "projected_damage",
    "projected_knockout",
    "requires_interaction",
    "attack_index",
    "option_number",
    "ability_index",
    "energy_type_raw",
    "energy_count",
    "special_condition_type",
    "pending_assignment_count",
    "tags",
    "option_type_raw",
    "option_player_index",
}
OPTION_KEYS = OPTION_REQUIRED_KEYS | {"source_entity_serial", "target_entity_serial"}


def _sha(value: Any) -> str:
    try:
        return public_observation_hash(value)
    except CabtTreeHashError:
        return ""


def _safe_int(value: Any, *, signed: bool = False) -> bool:
    if type(value) is not int:
        return False
    minimum = -MAX_SAFE_INTEGER if signed else 0
    return minimum <= value <= MAX_SAFE_INTEGER


def _uid(value: Any) -> bool:
    return type(value) is str and 3 <= len(value) <= 64 and LOCAL_UID.fullmatch(value) is not None


def _identifier(value: Any) -> bool:
    return type(value) is str and IDENTIFIER.fullmatch(value) is not None and "private" not in value


def _contains_private(value: Any) -> bool:
    if type(value) is dict:
        for key, child in value.items():
            if type(key) is not str or key.lower() in PRIVATE_KEYS or "private" in key.lower():
                return True
            if _contains_private(child):
                return True
    elif type(value) is list:
        return any(_contains_private(child) for child in value)
    elif type(value) not in {str, int, bool, type(None)}:
        return True
    return False


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if type(value) is list:
        return tuple(_freeze(child) for child in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(child) for key, child in value.items()}
    if type(value) is tuple:
        return [_thaw(child) for child in value]
    return value


def _condition_error(value: Any, allowed_uids: frozenset[str]) -> str | None:
    if type(value) is not dict or set(value) != CONDITION_KEYS:
        return "invalid_public_condition"
    fact = value["fact"]
    if type(fact) is not str or fact not in SCALAR_FACTS | ZONE_FACTS | ENERGY_ZONE_FACTS | ENERGY_BEARING_ZONE_FACTS | GOAL_UID_FACTS | WINDOW_UID_FACTS:
        return "invalid_public_fact"
    if value["op"] not in OPS:
        return "invalid_public_condition"
    card_uid = value["card_uid"]
    if fact in ZONE_FACTS | ENERGY_ZONE_FACTS | ENERGY_BEARING_ZONE_FACTS | GOAL_UID_FACTS | WINDOW_UID_FACTS:
        if not _uid(card_uid) or card_uid not in allowed_uids:
            return "invalid_public_condition"
    elif card_uid is not None:
        return "invalid_public_condition"
    scalar = value["value"]
    if type(scalar) not in {str, int, bool, type(None)} or (type(scalar) is int and not _safe_int(scalar, signed=True)):
        return "invalid_public_condition"
    if (
        fact not in ZONE_FACTS | ENERGY_ZONE_FACTS | ENERGY_BEARING_ZONE_FACTS | GOAL_UID_FACTS | WINDOW_UID_FACTS
        and fact.endswith("_uid")
        and scalar is not None
        and (not _uid(scalar) or scalar not in allowed_uids)
    ):
        return "invalid_public_condition"
    return None


def _condition_list_error(
    value: Any,
    allowed_uids: frozenset[str],
    *,
    allow_option_facts: bool,
) -> str | None:
    if type(value) is not list or len(value) > 32:
        return "invalid_public_condition"
    for condition in value:
        error = _condition_error(condition, allowed_uids)
        if error is not None:
            return error
        fact = condition["fact"]
        if not allow_option_facts and (
            fact.startswith("option.")
            or fact.startswith("goal.option.")
            or fact.startswith("damage.option.")
            or fact.startswith("transaction.option.")
        ):
            return "invalid_public_condition"
    return None


def _route_step_error(
    step: Any,
    allowed_uids: frozenset[str],
    goal_ids: set[str],
) -> str | None:
    if type(step) is not dict or set(step) != ROUTE_STEP_KEYS:
        return "invalid_turn_route"
    if (
        not _identifier(step["step_id"])
        or step["goal_id"] not in goal_ids
        or type(step["prompt_kinds"]) is not list
        or not step["prompt_kinds"]
        or len(step["prompt_kinds"]) > 16
        or any(type(kind) is not str or not kind or len(kind) > 64 for kind in step["prompt_kinds"])
        or len(set(step["prompt_kinds"])) != len(step["prompt_kinds"])
        or not _safe_int(step["score_bonus"])
        or not 0 <= step["score_bonus"] <= 1_000_000
        or type(step["terminal"]) is not bool
        or type(step["checkpoint"]) is not bool
    ):
        return "invalid_turn_route"
    selection_count = step["selection_count"]
    if selection_count is not None and (
        not _safe_int(selection_count) or not 0 <= selection_count <= 1024
    ):
        return "invalid_turn_route"
    error = _condition_list_error(
        step["when"], allowed_uids, allow_option_facts=False
    )
    if error is not None:
        return error
    if not step["option_when"]:
        return "invalid_turn_route"
    return _condition_list_error(
        step["option_when"], allowed_uids, allow_option_facts=True
    )


def _route_candidate_step_error(
    step: Any,
    allowed_uids: frozenset[str],
    goal_ids: set[str],
) -> str | None:
    if type(step) is not dict or set(step) != ROUTE_CANDIDATE_STEP_KEYS:
        return "invalid_route_candidate"
    if (
        not _identifier(step["step_id"])
        or step["goal_id"] not in goal_ids
        or type(step["prompt_kinds"]) is not list
        or not step["prompt_kinds"]
        or len(step["prompt_kinds"]) > 16
        or any(
            type(kind) is not str or not kind or len(kind) > 64
            for kind in step["prompt_kinds"]
        )
        or len(set(step["prompt_kinds"])) != len(step["prompt_kinds"])
        or type(step["terminal"]) is not bool
        or type(step["checkpoint"]) is not bool
    ):
        return "invalid_route_candidate"
    selection_count = step["selection_count"]
    if selection_count is not None and (
        not _safe_int(selection_count) or not 0 <= selection_count <= 1024
    ):
        return "invalid_route_candidate"
    error = _condition_list_error(
        step["when"], allowed_uids, allow_option_facts=False
    )
    if error is not None:
        return error
    if not step["option_when"]:
        return "invalid_route_candidate"
    return _condition_list_error(
        step["option_when"], allowed_uids, allow_option_facts=True
    )


def _route_value_component_error(value: Any) -> str | None:
    if type(value) is not dict or set(value) != ROUTE_VALUE_COMPONENT_KEYS:
        return "invalid_route_value"
    if (
        not _safe_int(value["base"], signed=True)
        or abs(value["base"]) > 1_000_000
        or type(value["terms"]) is not list
        or len(value["terms"]) > 16
    ):
        return "invalid_route_value"
    for term in value["terms"]:
        if type(term) is not dict or set(term) != TERM_KEYS:
            return "invalid_route_value"
        fact = term["fact"]
        if (
            fact not in NUMERIC_TERM_FACTS
            or fact.startswith("option.")
            or fact.startswith("goal.option.")
            or not _safe_int(term["coefficient"], signed=True)
            or abs(term["coefficient"]) > 10_000
            or not _safe_int(term["minimum"], signed=True)
            or not _safe_int(term["maximum"], signed=True)
            or term["minimum"] > term["maximum"]
        ):
            return "invalid_route_value"
    return None


def _turn_bonus_error(
    bonus: Any,
    allowed_uids: frozenset[str],
    goal_ids: set[str],
) -> str | None:
    if type(bonus) is not dict or set(bonus) != TURN_BONUS_KEYS:
        return "invalid_turn_bonus_contract"
    if (
        not _identifier(bonus["bonus_id"])
        or bonus["goal_id"] not in goal_ids
        or type(bonus["prompt_kinds"]) is not list
        or not bonus["prompt_kinds"]
        or len(bonus["prompt_kinds"]) > 16
        or any(
            type(kind) is not str or not kind or len(kind) > 64
            for kind in bonus["prompt_kinds"]
        )
        or len(set(bonus["prompt_kinds"])) != len(bonus["prompt_kinds"])
        or not _safe_int(bonus["score_bonus"], signed=True)
        or not -1_000_000 <= bonus["score_bonus"] <= 1_000_000
    ):
        return "invalid_turn_bonus_contract"
    error = _condition_list_error(
        bonus["when"], allowed_uids, allow_option_facts=False
    )
    if error is not None:
        return error
    if not bonus["option_when"]:
        return "invalid_turn_bonus_contract"
    return _condition_list_error(
        bonus["option_when"], allowed_uids, allow_option_facts=True
    )


def _turn_transaction_error(
    transaction: Any,
    allowed_uids: frozenset[str],
    goal_ids: set[str],
) -> str | None:
    if (
        type(transaction) is not dict
        or not TURN_TRANSACTION_REQUIRED_KEYS
        <= set(transaction)
        <= TURN_TRANSACTION_KEYS
    ):
        return "invalid_turn_transaction"
    if (
        not _identifier(transaction["transaction_id"])
        or transaction["goal_id"] not in goal_ids
        or not _safe_int(transaction["priority"])
        or transaction["priority"] > 1_000_000
        or not _safe_int(transaction["deadline_turns"])
        or not 0 <= transaction["deadline_turns"] <= 16
        or type(transaction["methods"]) is not list
        or not transaction["methods"]
        or len(transaction["methods"]) > 16
    ):
        return "invalid_turn_transaction"
    for key in ("when", "continue_when", "success_when", "abort_when"):
        error = _condition_list_error(
            transaction.get(key, []), allowed_uids, allow_option_facts=False
        )
        if error is not None:
            return error
    method_ids: set[str] = set()
    for method in transaction["methods"]:
        if (
            type(method) is not dict
            or set(method) != TURN_TRANSACTION_METHOD_KEYS
            or not _identifier(method["method_id"])
            or method["method_id"] in method_ids
            or not _safe_int(method["priority"])
            or method["priority"] > 1_000_000
            or type(method["steps"]) is not list
            or not method["steps"]
            or len(method["steps"]) > 32
        ):
            return "invalid_turn_transaction"
        method_ids.add(method["method_id"])
        error = _condition_list_error(
            method["when"], allowed_uids, allow_option_facts=False
        )
        if error is not None:
            return error
        step_ids: set[str] = set()
        for step in method["steps"]:
            if (
                type(step) is not dict
                or not TURN_TRANSACTION_STEP_REQUIRED_KEYS <= set(step) <= TURN_TRANSACTION_STEP_KEYS
                or not _identifier(step["step_id"])
                or step["step_id"] in step_ids
                or step["goal_id"] not in goal_ids
                or type(step["prompt_kinds"]) is not list
                or not step["prompt_kinds"]
                or len(step["prompt_kinds"]) > 16
                or any(
                    type(kind) is not str or not kind or len(kind) > 64
                    for kind in step["prompt_kinds"]
                )
                or len(set(step["prompt_kinds"])) != len(step["prompt_kinds"])
                or not _safe_int(step["score_bonus"])
                or step["score_bonus"] > 1_000_000
                or type(step["terminal"]) is not bool
                or type(step["checkpoint"]) is not bool
                or type(step["required_before_attack"]) is not bool
                or type(step.get("sequence_barrier", False)) is not bool
            ):
                return "invalid_turn_transaction"
            step_ids.add(step["step_id"])
            selection_count = step["selection_count"]
            if selection_count is not None and (
                not _safe_int(selection_count) or not 0 <= selection_count <= 1024
            ):
                return "invalid_turn_transaction"
            for key in ("required_when", "complete_when"):
                error = _condition_list_error(
                    step[key], allowed_uids, allow_option_facts=False
                )
                if error is not None:
                    return error
            if not step["option_when"]:
                return "invalid_turn_transaction"
            error = _condition_list_error(
                step["option_when"], allowed_uids, allow_option_facts=True
            )
            if error is not None:
                return error
            selection_groups = step.get("selection_groups", [])
            if type(selection_groups) is not list or len(selection_groups) > 16:
                return "invalid_turn_transaction"
            group_ids: set[str] = set()
            grouped_count = 0
            for group in selection_groups:
                if (
                    type(group) is not dict
                    or set(group) != TURN_TRANSACTION_SELECTION_GROUP_KEYS
                    or not _identifier(group["group_id"])
                    or group["group_id"] in group_ids
                    or not _safe_int(group["selection_count"])
                    or not 1 <= group["selection_count"] <= 1024
                    or not group["option_when"]
                ):
                    return "invalid_turn_transaction"
                group_ids.add(group["group_id"])
                grouped_count += group["selection_count"]
                error = _condition_list_error(
                    group["option_when"], allowed_uids, allow_option_facts=True
                )
                if error is not None:
                    return error
            if selection_groups and (
                selection_count is None or grouped_count != selection_count
            ):
                return "invalid_turn_transaction"
    return None


def _document_error(value: Any, allowed_uids: frozenset[str]) -> str | None:
    if _contains_private(value):
        return "private_policy_input"
    if (
        type(value) is not dict
        or not DOCUMENT_REQUIRED_KEYS <= set(value) <= DOCUMENT_KEYS
    ):
        return "invalid_policy_document"
    if (
        value["schema_version"] != 2
        or not _identifier(value["adapter_id"])
        or not _safe_int(value["adapter_version"])
        or value["adapter_version"] < 2
    ):
        return "invalid_policy_document"
    goals = value["goals"]
    count_rules = value["count_rules"]
    rules = value["rules"]
    turn_routes = value.get("turn_routes", [])
    route_candidates = value.get("route_candidates", [])
    interaction_recipes = value.get("interaction_recipes", [])
    turn_bonus_contracts = value.get("turn_bonus_contracts", [])
    damage_plans = value.get("damage_plans", [])
    semantic_transactions = value.get("semantic_transactions", [])
    turn_transactions = value.get("turn_transactions", [])
    if type(goals) is not list or not goals or len(goals) > 64:
        return "invalid_goal_state"
    if type(count_rules) is not list or len(count_rules) > 128:
        return "invalid_count_rule"
    if type(rules) is not list or not rules or len(rules) > 512:
        return "invalid_score_rule"
    if type(turn_routes) is not list or len(turn_routes) > 64:
        return "invalid_turn_route"
    if type(route_candidates) is not list or len(route_candidates) > 32:
        return "invalid_route_candidate"
    if type(interaction_recipes) is not list or len(interaction_recipes) > 128:
        return "invalid_interaction_recipe"
    if type(turn_bonus_contracts) is not list or len(turn_bonus_contracts) > 64:
        return "invalid_turn_bonus_contract"
    if type(turn_transactions) is not list or len(turn_transactions) > 64:
        return "invalid_turn_transaction"
    if damage_plans:
        damage_error = validate_damage_plans(damage_plans)
        if damage_error:
            return damage_error
    if semantic_transactions:
        transaction_error = validate_semantic_transactions(semantic_transactions)
        if transaction_error:
            return transaction_error
    goal_ids: set[str] = set()
    for goal in goals:
        if type(goal) is not dict or set(goal) != GOAL_KEYS:
            return "invalid_goal_state"
        if (
            not _identifier(goal["goal_id"])
            or goal["goal_id"] in goal_ids
            or goal["stage"] not in GOAL_STAGES
            or not _safe_int(goal["priority"])
        ):
            return "invalid_goal_state"
        goal_ids.add(goal["goal_id"])
        requirements = goal["requirements"]
        if type(requirements) is not list or not requirements or len(requirements) > 32:
            return "invalid_goal_state"
        seen_uids: set[str] = set()
        for requirement in requirements:
            if (
                type(requirement) is not dict
                or not REQUIREMENT_REQUIRED_KEYS <= set(requirement) <= REQUIREMENT_KEYS
            ):
                return "invalid_goal_state"
            uid = requirement["card_uid"]
            if (
                not _uid(uid)
                or uid not in allowed_uids
                or uid in seen_uids
                or not _safe_int(requirement["ready_target_count"])
                or not 1 <= requirement["ready_target_count"] <= 6
                or not _safe_int(requirement["energy_required"])
                or not 0 <= requirement["energy_required"] <= 16
            ):
                return "invalid_goal_state"
            energy_requirements = requirement.get("energy_requirements", [])
            if type(energy_requirements) is not list or len(energy_requirements) > 16:
                return "invalid_goal_state"
            seen_energy_uids: set[str] = set()
            typed_total = 0
            for energy_requirement in energy_requirements:
                if (
                    type(energy_requirement) is not dict
                    or set(energy_requirement) != ENERGY_REQUIREMENT_KEYS
                    or not _uid(energy_requirement["energy_uid"])
                    or energy_requirement["energy_uid"] not in allowed_uids
                    or energy_requirement["energy_uid"] in seen_energy_uids
                    or not _safe_int(energy_requirement["count"])
                    or not 1 <= energy_requirement["count"] <= 16
                ):
                    return "invalid_goal_state"
                seen_energy_uids.add(energy_requirement["energy_uid"])
                typed_total += energy_requirement["count"]
            if typed_total > 16:
                return "invalid_goal_state"
            attack_index = requirement.get("attack_index")
            ability_index = requirement.get("ability_index")
            if (
                attack_index is not None
                and (not _safe_int(attack_index) or not 0 <= attack_index <= 15)
            ):
                return "invalid_goal_state"
            if (
                ability_index is not None
                and (not _safe_int(ability_index) or not 0 <= ability_index <= 15)
            ):
                return "invalid_goal_state"
            if attack_index is not None and ability_index is not None:
                return "invalid_goal_state"
            seen_uids.add(uid)
    for damage_plan in damage_plans:
        if damage_plan["goal_id"] not in goal_ids:
            return "invalid_damage_plan"
    for transaction in semantic_transactions:
        if transaction["goal_id"] not in goal_ids:
            return "invalid_semantic_transaction"
        for key in ("start_when", "continue_when", "success_when", "abort_when"):
            error = _condition_list_error(
                transaction[key], allowed_uids, allow_option_facts=False
            )
            if error is not None:
                return error
    transaction_ids: set[str] = set()
    for transaction in turn_transactions:
        error = _turn_transaction_error(transaction, allowed_uids, goal_ids)
        if error is not None:
            return error
        transaction_id = transaction["transaction_id"]
        if transaction_id in transaction_ids:
            return "invalid_turn_transaction"
        transaction_ids.add(transaction_id)
    route_ids: set[str] = set()
    for route in turn_routes:
        if type(route) is not dict or set(route) != TURN_ROUTE_KEYS:
            return "invalid_turn_route"
        route_id = route["route_id"]
        referenced_goals = (
            route["goal_id"],
            route["owner_goal_id"],
            route["bridge_goal_id"],
            route["pivot_goal_id"],
        )
        if (
            not _identifier(route_id)
            or route_id in route_ids
            or not _safe_int(route["priority"])
            or route["priority"] > 1_000_000
            or any(goal_id not in goal_ids for goal_id in referenced_goals)
            or type(route["steps"]) is not list
            or not route["steps"]
            or len(route["steps"]) > 32
        ):
            return "invalid_turn_route"
        route_ids.add(route_id)
        error = _condition_list_error(
            route["when"], allowed_uids, allow_option_facts=False
        )
        if error is not None:
            return error
        step_ids: set[str] = set()
        for step in route["steps"]:
            error = _route_step_error(step, allowed_uids, goal_ids)
            if error is not None:
                return error
            if step["step_id"] in step_ids:
                return "invalid_turn_route"
            step_ids.add(step["step_id"])
    for route in route_candidates:
        if type(route) is not dict or set(route) != ROUTE_CANDIDATE_KEYS:
            return "invalid_route_candidate"
        route_id = route["route_id"]
        referenced_goals = (
            route["goal_id"],
            route["owner_goal_id"],
            route["bridge_goal_id"],
            route["pivot_goal_id"],
        )
        budget = route["resource_budget"]
        route_value = route["value"]
        if (
            not _identifier(route_id)
            or route_id in route_ids
            or any(goal_id not in goal_ids for goal_id in referenced_goals)
            or type(budget) is not dict
            or set(budget) != ROUTE_RESOURCE_BUDGET_KEYS
            or not all(_safe_int(amount) for amount in budget.values())
            or not 0 <= budget["supporter_uses"] <= 1
            or not 0 <= budget["manual_attachments"] <= 1
            or not 0 <= budget["retreats"] <= 1
            or not 0 <= budget["bench_slots"] <= 8
            or not 0 <= budget["ability_uses"] <= 16
            or not 0 <= budget["discard_cards"] <= 60
            or not 0 <= budget["search_cards"] <= 60
            or type(route_value) is not dict
            or set(route_value) != set(ROUTE_VALUE_COMPONENTS)
            or type(route["steps"]) is not list
            or not route["steps"]
            or len(route["steps"]) > 32
        ):
            return "invalid_route_candidate"
        route_ids.add(route_id)
        error = _condition_list_error(
            route["when"], allowed_uids, allow_option_facts=False
        )
        if error is not None:
            return error
        for component_name in ROUTE_VALUE_COMPONENTS:
            error = _route_value_component_error(route_value[component_name])
            if error is not None:
                return error
        step_ids: set[str] = set()
        for step in route["steps"]:
            error = _route_candidate_step_error(step, allowed_uids, goal_ids)
            if error is not None:
                return error
            if step["step_id"] in step_ids:
                return "invalid_route_candidate"
            step_ids.add(step["step_id"])
    recipe_ids: set[str] = set()
    for recipe in interaction_recipes:
        if type(recipe) is not dict or set(recipe) != INTERACTION_RECIPE_KEYS:
            return "invalid_interaction_recipe"
        route_id = recipe["route_id"]
        if (
            not _identifier(recipe["recipe_id"])
            or recipe["recipe_id"] in recipe_ids
            or not _safe_int(recipe["priority"])
            or recipe["priority"] > 1_000_000
            or (route_id is not None and route_id not in route_ids)
            or recipe["goal_id"] not in goal_ids
            or type(recipe["source_uids"]) is not list
            or not recipe["source_uids"]
            or len(recipe["source_uids"]) > 32
            or len(set(recipe["source_uids"])) != len(recipe["source_uids"])
            or any(not _uid(uid) or uid not in allowed_uids for uid in recipe["source_uids"])
            or type(recipe["steps"]) is not list
            or not recipe["steps"]
            or len(recipe["steps"]) > 32
        ):
            return "invalid_interaction_recipe"
        recipe_ids.add(recipe["recipe_id"])
        error = _condition_list_error(
            recipe["when"], allowed_uids, allow_option_facts=False
        )
        if error is not None:
            return error
        step_ids: set[str] = set()
        for step in recipe["steps"]:
            error = _route_step_error(step, allowed_uids, goal_ids)
            if error is not None:
                return "invalid_interaction_recipe" if error == "invalid_turn_route" else error
            if step["step_id"] in step_ids:
                return "invalid_interaction_recipe"
            step_ids.add(step["step_id"])
    contract_ids: set[str] = set()
    for contract in turn_bonus_contracts:
        if type(contract) is not dict or set(contract) != TURN_BONUS_CONTRACT_KEYS:
            return "invalid_turn_bonus_contract"
        contract_id = contract["contract_id"]
        if (
            not _identifier(contract_id)
            or contract_id in contract_ids
            or not _safe_int(contract["priority"])
            or contract["priority"] > 1_000_000
            or contract["goal_id"] not in goal_ids
            or type(contract["bonuses"]) is not list
            or not contract["bonuses"]
            or len(contract["bonuses"]) > 64
        ):
            return "invalid_turn_bonus_contract"
        contract_ids.add(contract_id)
        error = _condition_list_error(
            contract["when"], allowed_uids, allow_option_facts=False
        )
        if error is not None:
            return error
        bonus_ids: set[str] = set()
        for bonus in contract["bonuses"]:
            error = _turn_bonus_error(bonus, allowed_uids, goal_ids)
            if error is not None:
                return error
            if bonus["bonus_id"] in bonus_ids:
                return "invalid_turn_bonus_contract"
            bonus_ids.add(bonus["bonus_id"])
    rule_ids: set[str] = set()
    for count_rule in count_rules:
        if type(count_rule) is not dict or set(count_rule) != COUNT_RULE_KEYS:
            return "invalid_count_rule"
        if (
            not _identifier(count_rule["rule_id"])
            or count_rule["rule_id"] in rule_ids
            or not _safe_int(count_rule["priority"])
            or count_rule["goal_id"] not in goal_ids
            or count_rule["mode"] not in COUNT_MODES
        ):
            return "invalid_count_rule"
        rule_ids.add(count_rule["rule_id"])
        fixed = count_rule["fixed_count"]
        fact = count_rule["fact"]
        divisor = count_rule["divisor"]
        if count_rule["mode"] == "fixed":
            if not _safe_int(fixed) or fixed > 1024 or fact is not None or divisor is not None:
                return "invalid_count_rule"
        elif count_rule["mode"] in {
            "goal_energy_debt",
            "goal_missing_energy_sources",
            "distinct_card_uids",
        }:
            if fixed is not None or fact is not None or divisor is not None:
                return "invalid_count_rule"
            if count_rule["mode"] == "goal_missing_energy_sources":
                goal = next(goal for goal in goals if goal["goal_id"] == count_rule["goal_id"])
                if not any(
                    requirement.get("energy_requirements", [])
                    for requirement in goal["requirements"]
                ):
                    return "invalid_count_rule"
        else:
            if (
                fact not in NUMERIC_TERM_FACTS
                or type(fact) is not str
                or fact.startswith("option.")
                or fact.startswith("goal.option.")
                or not _safe_int(divisor)
                or not 1 <= divisor <= 1_000_000
            ):
                return "invalid_count_rule"
            if count_rule["mode"] == "ceil_public_fact_divisor":
                if fixed is not None:
                    return "invalid_count_rule"
            elif not _safe_int(fixed) or fixed > 1024:
                return "invalid_count_rule"
        if type(count_rule["when"]) is not list or len(count_rule["when"]) > 32:
            return "invalid_count_rule"
        for condition in count_rule["when"]:
            error = _condition_error(condition, allowed_uids)
            if error is not None:
                return error
    for rule in rules:
        if type(rule) is not dict or set(rule) != RULE_KEYS:
            return "invalid_score_rule"
        if (
            not _identifier(rule["rule_id"])
            or rule["rule_id"] in rule_ids
            or rule["goal_id"] not in goal_ids
            or rule["goal_stage"] not in GOAL_STAGES
            or rule["channel"] not in CHANNELS
            or not _safe_int(rule["horizon"])
            or rule["horizon"] > 2
            or not _safe_int(rule["confidence_milli"])
            or rule["confidence_milli"] > 1000
            or not _safe_int(rule["base_score"], signed=True)
            or abs(rule["base_score"]) > 1_000_000
        ):
            return "invalid_score_rule"
        rule_ids.add(rule["rule_id"])
        if type(rule["when"]) is not list or len(rule["when"]) > 32:
            return "invalid_score_rule"
        for condition in rule["when"]:
            error = _condition_error(condition, allowed_uids)
            if error is not None:
                return error
        terms = rule["score_terms"]
        if type(terms) is not list or len(terms) > 16:
            return "invalid_score_rule"
        for term in terms:
            if type(term) is not dict or set(term) != TERM_KEYS:
                return "invalid_score_rule"
            if (
                term["fact"] not in NUMERIC_TERM_FACTS
                or not _safe_int(term["coefficient"], signed=True)
                or abs(term["coefficient"]) > 10_000
                or not _safe_int(term["minimum"], signed=True)
                or not _safe_int(term["maximum"], signed=True)
                or term["minimum"] > term["maximum"]
            ):
                return "invalid_score_rule"
    return None


@dataclass(frozen=True, slots=True, init=False)
class CompetitivePolicyV2:
    _document: Any
    _allowed_uids: frozenset[str]
    _policy_hash: str

    @classmethod
    def _create(cls, document: dict[str, Any], allowed_uids: frozenset[str]) -> "CompetitivePolicyV2":
        value = object.__new__(cls)
        object.__setattr__(value, "_document", _freeze(copy.deepcopy(document)))
        object.__setattr__(value, "_allowed_uids", allowed_uids)
        object.__setattr__(value, "_policy_hash", _sha({"profile_id": PROFILE_ID, "document": document}))
        return value

    @property
    def policy_hash(self) -> str:
        return self._policy_hash if self.validate_integrity() else ""

    def validate_integrity(self) -> bool:
        document = _thaw(self._document)
        return (
            bool(self._allowed_uids)
            and all(_uid(uid) for uid in self._allowed_uids)
            and _document_error(document, self._allowed_uids) is None
            and self._policy_hash == _sha({"profile_id": PROFILE_ID, "document": document})
        )

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise ValueError("policy_integrity_invalid")
        return copy.deepcopy(_thaw(self._document))


@dataclass(frozen=True, slots=True)
class CompetitivePolicyV2CompileOutcome:
    accepted: bool
    error_code: str
    policy: CompetitivePolicyV2 | None


class CompetitivePolicyV2Compiler:
    @staticmethod
    def compile_local_uid(document: Any, *, allowed_card_uids: Any) -> CompetitivePolicyV2CompileOutcome:
        if type(allowed_card_uids) not in {set, frozenset}:
            return CompetitivePolicyV2CompileOutcome(False, "invalid_allowed_card_uids", None)
        allowed = frozenset(allowed_card_uids)
        if not allowed or not all(_uid(uid) for uid in allowed):
            return CompetitivePolicyV2CompileOutcome(False, "invalid_allowed_card_uids", None)
        error = _document_error(document, allowed)
        if error is not None:
            return CompetitivePolicyV2CompileOutcome(False, error, None)
        return CompetitivePolicyV2CompileOutcome(
            True,
            "",
            CompetitivePolicyV2._create(copy.deepcopy(document), allowed),
        )


def _card_error(value: Any, *, slot: bool) -> bool:
    if type(value) is not dict or (
        (not SLOT_REQUIRED_KEYS <= set(value) <= SLOT_KEYS)
        if slot
        else set(value) != CARD_KEYS
    ):
        return True
    if not _safe_int(value["serial"]) or not _uid(value["local_card_uid"]):
        return True
    if not slot:
        return False
    if "entity_serial" in value and (
        not _safe_int(value["entity_serial"]) or value["entity_serial"] < 1
    ):
        return True
    if "max_hp" in value and not _safe_int(value["max_hp"]):
        return True
    if "damage_counters" in value and not _safe_int(value["damage_counters"]):
        return True
    if "appeared_this_turn" in value and type(value["appeared_this_turn"]) is not bool:
        return True
    if "attached_tool_uid" in value and value["attached_tool_uid"] is not None \
        and not _uid(value["attached_tool_uid"]):
        return True
    if "pokemon_stack_uids" in value and (
        type(value["pokemon_stack_uids"]) is not list
        or not value["pokemon_stack_uids"]
        or any(not _uid(uid) for uid in value["pokemon_stack_uids"])
    ):
        return True
    return not (
        _safe_int(value["remaining_hp"])
        and _safe_int(value["prize_value"])
        and 1 <= value["prize_value"] <= 3
        and _safe_int(value["attached_energy_count"])
        and type(value["attached_energy_uids"]) is list
        and len(value["attached_energy_uids"]) == value["attached_energy_count"]
        and all(_uid(uid) for uid in value["attached_energy_uids"])
        and _safe_int(value["minimum_attack_energy_count"])
        and type(value["attack_ready"]) is bool
        and _safe_int(value["energy_debt"])
        and value["energy_debt"] <= 16
    )


def _nullable(value: Any, kind: type) -> bool:
    return value is None or type(value) is kind


def _frame_error(value: Any) -> str | None:
    if _contains_private(value):
        return "private_or_runtime_frame"
    if type(value) is not dict or set(value) != FRAME_KEYS:
        return "invalid_public_frame"
    if (
        value["schema_version"] != 2
        or value["profile_id"] != FRAME_PROFILE_ID
        or not _safe_int(value["sequence"])
        or value["sequence"] < 1
        or value["seat"] not in {0, 1}
        or type(value["prompt_kind"]) is not str
        or not value["prompt_kind"]
    ):
        return "invalid_public_frame"
    source = value["source"]
    state = value["public_state"]
    semantics = value["select_semantics"]
    options = value["options"]
    if (
        type(source) is not dict
        or set(source) != SOURCE_KEYS
        or UPPER_SHA.fullmatch(str(source["public_observation_hash"])) is None
        or UPPER_SHA.fullmatch(str(source["window_id"])) is None
        or type(state) is not dict
        or set(state) != STATE_KEYS
        or type(semantics) is not dict
        or set(semantics) != SEMANTIC_KEYS
        or type(options) is not list
        or len(options) > 1024
    ):
        return "invalid_public_frame"
    own = state["self"]
    opponent = state["opponent"]
    if (
        type(own) is not dict
        or not SELF_REQUIRED_KEYS <= set(own) <= SELF_KEYS
        or type(opponent) is not dict
        or set(opponent) != OPPONENT_KEYS
    ):
        return "invalid_public_frame"
    if "turn" in own:
        turn = own["turn"]
        if (
            type(turn) is not dict
            or set(turn) != TURN_LEDGER_KEYS
            or any(type(value) is not bool for value in turn.values())
        ):
            return "invalid_public_frame"
    if not _safe_int(state["turn_number"]) or type(state["phase"]) is not str:
        return "invalid_public_frame"
    for key in ("hand", "active", "bench", "discard"):
        values = own[key]
        if type(values) is not list or any(_card_error(child, slot=key in {"active", "bench"}) for child in values):
            return "invalid_public_frame"
    if "bench_capacity" in own and (
        not _safe_int(own["bench_capacity"])
        or own["bench_capacity"] > 8
        or own["bench_capacity"] < len(own["bench"])
    ):
        return "invalid_public_frame"
    for key in ("active", "bench", "discard"):
        values = opponent[key]
        if type(values) is not list or any(_card_error(child, slot=key in {"active", "bench"}) for child in values):
            return "invalid_public_frame"
    for item in (
        own["deck_count"],
        own["prizes_remaining"],
        opponent["hand_count"],
        opponent["deck_count"],
        opponent["prizes_remaining"],
    ):
        if not _safe_int(item):
            return "invalid_public_frame"
    minimum = semantics["min_count"]
    maximum = semantics["max_count"]
    if (
        not _safe_int(minimum)
        or not _safe_int(maximum)
        or not 0 <= minimum <= maximum <= len(options)
        or not _safe_int(semantics["select_type_raw"])
        or not _safe_int(semantics["select_context_raw"])
    ):
        return "invalid_public_frame"
    for index, option in enumerate(options):
        if (
            type(option) is not dict
            or not OPTION_REQUIRED_KEYS <= set(option) <= OPTION_KEYS
            or option["index"] != index
        ):
            return "invalid_public_frame"
        if type(option["kind"]) is not str or not option["kind"]:
            return "invalid_public_frame"
        for key in ("card_uid", "source_uid", "target_uid"):
            if option[key] is not None and not _uid(option[key]):
                return "invalid_public_frame"
        for key in (
            "card_serial",
            "source_serial",
            "source_entity_serial",
            "target_serial",
            "target_entity_serial",
            "target_remaining_hp",
            "target_prize_value",
            "target_attached_energy_count",
            "target_minimum_attack_energy_count",
            "target_energy_debt",
            "projected_damage",
            "attack_index",
            "option_number",
            "ability_index",
            "energy_type_raw",
            "energy_count",
            "special_condition_type",
        ):
            if key not in option:
                continue
            if not _nullable(option[key], int) or (type(option[key]) is int and not _safe_int(option[key])):
                return "invalid_public_frame"
        attached_uids = option["target_attached_energy_uids"]
        if attached_uids is not None and (
            type(attached_uids) is not list
            or len(attached_uids) > 64
            or any(not _uid(uid) for uid in attached_uids)
        ):
            return "invalid_public_frame"
        for key in ("target_attack_ready",):
            if not _nullable(option[key], bool):
                return "invalid_public_frame"
        if (
            type(option["projected_knockout"]) is not bool
            or type(option["requires_interaction"]) is not bool
            or not _safe_int(option["pending_assignment_count"])
            or type(option["tags"]) is not list
            or any(type(tag) is not str for tag in option["tags"])
            or not _safe_int(option["option_type_raw"])
            or option["option_player_index"] not in {0, 1, None}
        ):
            return "invalid_public_frame"
        if not _valid_native_option_shape(option):
            return "invalid_public_frame"
    return None


def _valid_native_option_shape(option: Mapping[str, Any]) -> bool:
    option_type = option["option_type_raw"]

    def entity(prefix: str) -> bool:
        serial = option[f"{prefix}_serial"]
        return _uid(option[f"{prefix}_uid"]) and _safe_int(serial) and serial > 0

    if option_type == 0:
        return _safe_int(option["option_number"])
    if option_type in {3, 4, 5, 7, 11}:
        return entity("card")
    if option_type == 6:
        return (
            entity("source")
            and _safe_int(option["energy_type_raw"])
            and 0 <= option["energy_type_raw"] <= 11
            and _safe_int(option["energy_count"])
            and option["energy_count"] > 0
        )
    if option_type in {8, 9}:
        return entity("card") and entity("target")
    if option_type == 10:
        return entity("source")
    if option_type == 13:
        return _uid(option["source_uid"]) and _safe_int(option["attack_index"])
    if option_type == 15:
        return (
            option["card_uid"] is None and option["card_serial"] is None
        ) or entity("card")
    if option_type == 16:
        return _safe_int(option["special_condition_type"]) and 0 <= option["special_condition_type"] <= 4
    return option_type in {1, 2, 12, 14}


def _requirement_slot_debt(requirement: dict[str, Any], slot: dict[str, Any]) -> int:
    attached = slot["attached_energy_count"]
    generic_debt = max(0, requirement["energy_required"] - attached)
    typed_debt = sum(
        max(0, item["count"] - slot["attached_energy_uids"].count(item["energy_uid"]))
        for item in requirement.get("energy_requirements", [])
    )
    return max(generic_debt, typed_debt)


def _requirement_slot_ready(requirement: dict[str, Any], slot: dict[str, Any]) -> bool:
    if _requirement_slot_debt(requirement, slot) != 0:
        return False
    if requirement.get("attack_index") is not None:
        return True
    if requirement.get("ability_index") is not None:
        return True
    return bool(slot["attack_ready"])


def _goal_states(
    document: dict[str, Any], frame: dict[str, Any]
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    own = frame["public_state"]["self"]
    active_slots = list(own["active"])
    bench_slots = list(own["bench"])
    slots = [*active_slots, *bench_slots]
    active_serials = {slot["serial"] for slot in active_slots}
    states: list[dict[str, Any]] = []
    by_id: dict[str, dict[str, Any]] = {}
    for goal in document["goals"]:
        deployed = 0
        ready = 0
        debt = 0
        active_ready = 0
        bench_ready = 0
        near_ready = 0
        requirement_states: dict[str, dict[str, int]] = {}
        energy_uids: set[str] = set()
        for requirement in goal["requirements"]:
            energy_uids.update(
                item["energy_uid"]
                for item in requirement.get("energy_requirements", [])
            )
            matches = [slot for slot in slots if slot["local_card_uid"] == requirement["card_uid"]]
            matches.sort(
                key=lambda slot: (
                    _requirement_slot_debt(requirement, slot),
                    -slot["attached_energy_count"],
                    slot["serial"],
                )
            )
            matches = matches[: requirement["ready_target_count"]]
            deployed_count = len(matches)
            ready_matches = [
                slot for slot in matches if _requirement_slot_ready(requirement, slot)
            ]
            ready_count = len(ready_matches)
            requirement_debt = sum(
                _requirement_slot_debt(requirement, slot) for slot in matches
            )
            near_ready_count = sum(
                1
                for slot in matches
                if _requirement_slot_debt(requirement, slot) <= 1
            )
            active_ready_count = sum(
                1 for slot in ready_matches if slot["serial"] in active_serials
            )
            bench_ready_count = ready_count - active_ready_count
            deployed += deployed_count
            ready += ready_count
            debt += requirement_debt
            active_ready += active_ready_count
            bench_ready += bench_ready_count
            near_ready += near_ready_count
            requirement_states[requirement["card_uid"]] = {
                "deployed_count": deployed_count,
                "ready_count": ready_count,
                "near_ready_count": near_ready_count,
                "energy_debt": requirement_debt,
                "active_ready_count": active_ready_count,
                "bench_ready_count": bench_ready_count,
            }
        state = {
            "goal_id": goal["goal_id"],
            "stage": goal["stage"],
            "priority": goal["priority"],
            "deployed_count": deployed,
            "ready_count": ready,
            "energy_debt": debt,
            "active_ready_count": active_ready,
            "bench_ready_count": bench_ready,
            "near_ready_count": near_ready,
        }
        states.append(state)
        by_id[goal["goal_id"]] = {
            "priority": goal["priority"],
            "deployed_count": deployed,
            "ready_count": ready,
            "energy_debt": debt,
            "active_ready_count": active_ready,
            "bench_ready_count": bench_ready,
            "near_ready_count": near_ready,
            "requirement_states": requirement_states,
            "energy_uids": sorted(energy_uids),
            "required_target_count": sum(
                requirement["ready_target_count"] for requirement in goal["requirements"]
            ),
            "requirements": [dict(requirement) for requirement in goal["requirements"]],
        }
    return states, by_id


_DEPLOY_OPTION_KINDS = frozenset({"setup_active", "setup_bench", "play_basic_to_bench", "evolve"})
_PIVOT_OPTION_KINDS = frozenset({"retreat", "send_out"})
_FUND_OPTION_KINDS = frozenset({"attach_energy", "assignment_target"})


def _self_slots(frame: dict[str, Any]) -> list[dict[str, Any]]:
    own = frame["public_state"]["self"]
    return [*own["active"], *own["bench"]]


def _target_slot(frame: dict[str, Any], option: dict[str, Any]) -> dict[str, Any] | None:
    target_serial = option.get("target_serial")
    target_uid = option.get("target_uid")
    for slot in _self_slots(frame):
        if target_serial is not None and slot["serial"] == target_serial:
            return slot
    for slot in _self_slots(frame):
        if target_uid is not None and slot["local_card_uid"] == target_uid:
            return slot
    return None


def _energy_uid_needed(
    requirement: dict[str, Any], slot: dict[str, Any] | None, energy_uid: Any
) -> bool:
    if type(energy_uid) is not str:
        return False
    typed = requirement.get("energy_requirements", [])
    if typed:
        attached_uids = [] if slot is None else slot["attached_energy_uids"]
        for item in typed:
            if item["energy_uid"] == energy_uid and attached_uids.count(energy_uid) < item["count"]:
                return True
        return False
    if slot is None:
        return requirement["energy_required"] > 0
    return slot["attached_energy_count"] < requirement["energy_required"]


def _goal_missing_energy_source_quotas(
    goal: dict[str, Any], frame: dict[str, Any]
) -> dict[str, int]:
    """Bind an optional multi-select source window to exact public typed debt.

    Quotas are computed from the closest deployed targets required by the goal,
    then capped by the energy identities actually present in this immutable
    option window. This prevents duplicate copies of one type from satisfying a
    different missing type and permits a legal zero-card choice when no offered
    source advances the declared route.
    """
    slots = _self_slots(frame)
    debt_by_uid: dict[str, int] = {}
    for requirement in goal.get("requirements", []):
        typed = requirement.get("energy_requirements", [])
        if not typed:
            continue
        matches = [
            slot
            for slot in slots
            if slot["local_card_uid"] == requirement["card_uid"]
        ]
        matches.sort(
            key=lambda slot: (
                _requirement_slot_debt(requirement, slot),
                -slot["attached_energy_count"],
                slot["serial"],
            )
        )
        for slot in matches[: requirement["ready_target_count"]]:
            for item in typed:
                uid = item["energy_uid"]
                debt_by_uid[uid] = debt_by_uid.get(uid, 0) + max(
                    0, item["count"] - slot["attached_energy_uids"].count(uid)
                )
    available_by_uid: dict[str, int] = {}
    for option in frame["options"]:
        uid = option.get("card_uid")
        if type(uid) is str:
            available_by_uid[uid] = available_by_uid.get(uid, 0) + 1
    return {
        uid: min(debt, available_by_uid.get(uid, 0))
        for uid, debt in debt_by_uid.items()
        if debt > 0 and available_by_uid.get(uid, 0) > 0
    }


def _distinct_card_uid_quotas(frame: dict[str, Any]) -> dict[str, int]:
    """Select at most one option for every distinct public printing UID."""
    return {
        uid: 1
        for uid in dict.fromkeys(
            option.get("card_uid")
            for option in frame["options"]
            if type(option.get("card_uid")) is str and option.get("card_uid")
        )
    }


def _slot_after_energy(slot: dict[str, Any], energy_uid: str) -> dict[str, Any]:
    projected = dict(slot)
    projected["attached_energy_count"] = slot["attached_energy_count"] + 1
    projected["attached_energy_uids"] = [*slot["attached_energy_uids"], energy_uid]
    return projected


def _goal_option_facts(
    goal: dict[str, Any], frame: dict[str, Any], option: dict[str, Any] | None
) -> dict[str, Any]:
    empty = {
        "matches_target": False,
        "acquires_missing_target": False,
        "deploys_missing_target": False,
        "supplies_missing_energy": False,
        "funds_target": False,
        "completes_target": False,
        "pivots_ready_target": False,
        "executes_requirement": False,
        "target_energy_debt": None,
        "progress": 0,
    }
    if option is None:
        return empty
    kind = option["kind"]
    slots = _self_slots(frame)
    target_slot = _target_slot(frame, option)
    target_uid = option.get("target_uid")
    source_uid = option.get("source_uid")
    card_uid = option.get("card_uid")
    for requirement in goal.get("requirements", []):
        uid = requirement["card_uid"]
        matches = [slot for slot in slots if slot["local_card_uid"] == uid]
        missing_target = len(matches) < requirement["ready_target_count"]
        target_matches = target_uid == uid and target_slot is not None
        if target_matches:
            empty["matches_target"] = True
            debt = _requirement_slot_debt(requirement, target_slot)
            current = empty["target_energy_debt"]
            empty["target_energy_debt"] = debt if current is None else min(current, debt)
        if kind == "search" and missing_target and card_uid == uid:
            empty["acquires_missing_target"] = True
        if kind in _DEPLOY_OPTION_KINDS and missing_target and card_uid == uid:
            empty["deploys_missing_target"] = True
        energy_uid = card_uid
        if frame["prompt_kind"] in {"search", "assignment_source"}:
            for slot in matches or [None]:
                if _energy_uid_needed(requirement, slot, energy_uid):
                    empty["supplies_missing_energy"] = True
                    break
        if kind in _FUND_OPTION_KINDS and target_matches and _energy_uid_needed(
            requirement, target_slot, energy_uid
        ):
            empty["funds_target"] = True
            projected = _slot_after_energy(target_slot, energy_uid)
            if _requirement_slot_debt(requirement, projected) == 0:
                empty["completes_target"] = True
        if kind in _PIVOT_OPTION_KINDS and target_matches and _requirement_slot_ready(
            requirement, target_slot
        ):
            empty["pivots_ready_target"] = True
        if kind in {"attack", "granted_attack"} and source_uid == uid:
            declared = requirement.get("attack_index")
            if declared is not None and option.get("attack_index") == declared:
                source_slot = next(
                    (slot for slot in slots if slot["serial"] == option.get("source_serial")),
                    None,
                )
                if source_slot is not None and _requirement_slot_ready(requirement, source_slot):
                    empty["executes_requirement"] = True
        if kind == "use_ability" and source_uid == uid:
            declared = requirement.get("ability_index")
            if declared is not None and option.get("ability_index") == declared:
                empty["executes_requirement"] = True
    progress_levels = (
        ("executes_requirement", 7),
        ("pivots_ready_target", 6),
        ("completes_target", 5),
        ("funds_target", 4),
        ("supplies_missing_energy", 3),
        ("deploys_missing_target", 2),
        ("acquires_missing_target", 1),
    )
    empty["progress"] = next((level for key, level in progress_levels if empty[key]), 0)
    return empty


def _goal_window_max_progress(
    goal: dict[str, Any], frame: dict[str, Any]
) -> int:
    return max(
        (
            int(_goal_option_facts(goal, frame, option).get("progress", 0))
            for option in frame["options"]
        ),
        default=0,
    )


def _goal_window_max_setup_progress(
    goal: dict[str, Any], frame: dict[str, Any]
) -> int:
    return max(
        (
            progress
            if 0 < progress < 7
            else 0
            for progress in (
                int(_goal_option_facts(goal, frame, option).get("progress", 0))
                for option in frame["options"]
            )
        ),
        default=0,
    )


def _threat_clock(frame: dict[str, Any]) -> dict[str, int]:
    own = frame["public_state"]["self"]
    opponent = frame["public_state"]["opponent"]
    opponent_targets = [*opponent["active"], *opponent["bench"]]
    own_targets = [*own["active"], *own["bench"]]
    opponent_yield = max((slot["prize_value"] for slot in opponent_targets), default=1)
    own_yield = max((slot["prize_value"] for slot in own_targets), default=1)
    own_attacks = int(math.ceil(own["prizes_remaining"] / max(1, opponent_yield)))
    opponent_attacks = int(math.ceil(opponent["prizes_remaining"] / max(1, own_yield)))
    return {
        "own_attacks_to_win": own_attacks,
        "opponent_attacks_to_win": opponent_attacks,
        "tempo_margin": opponent_attacks - own_attacks,
    }


def _zone(frame: dict[str, Any], fact: str) -> list[dict[str, Any]]:
    owner, rest = fact.split(".", 1)
    state = frame["public_state"][owner]
    zone_name = rest.split(".", 1)[0]
    if zone_name == "board":
        return [*state["active"], *state["bench"]]
    return list(state[zone_name])


def _active_scalar(state: dict[str, Any], field: str) -> int | None:
    active = state["active"]
    return active[0].get(field) if active else None


def _window_uniform(frame: dict[str, Any], field: str) -> Any:
    values = {option[field] for option in frame["options"] if option[field] is not None}
    return next(iter(values)) if len(values) == 1 else None


def _enum_name(names: tuple[str, ...], raw: Any) -> str | None:
    return names[raw] if type(raw) is int and 0 <= raw < len(names) else None


def _fact(
    fact: str,
    frame: dict[str, Any],
    option: dict[str, Any] | None,
    goal: dict[str, Any],
    threat: dict[str, int],
    card_uid: str | None,
) -> Any:
    damage = frame.get("_derived_damage", {})
    transaction = frame.get("_derived_transaction", {})
    if fact.startswith("damage.option."):
        if option is None:
            return None
        metrics = damage.get("options", {}).get(str(option.get("index")), {})
        return metrics.get(fact.removeprefix("damage.option."))
    if fact.startswith("damage."):
        return damage.get("facts", {}).get(fact)
    if fact == "transaction.active":
        return bool(transaction.get("state"))
    if fact == "transaction.id":
        return transaction.get("state", {}).get("transaction_id")
    if fact == "transaction.phase":
        return transaction.get("state", {}).get("phase")
    if fact.startswith("transaction.option."):
        if option is None:
            return None
        target = transaction.get("state", {}).get("target_entity_serial")
        option_target = option.get("target_entity_serial")
        if option.get("kind") in {"attack", "granted_attack"}:
            option_target = damage.get("options", {}).get(
                str(option.get("index")), {}
            ).get("target_entity_serial")
        return type(target) is int and target == option_target
    if fact.startswith("transaction."):
        return transaction.get("state", {}).get(fact.removeprefix("transaction."))
    own = frame["public_state"]["self"]
    opponent = frame["public_state"]["opponent"]
    turn = own.get("turn", {})
    scalar = {
        "prompt_kind": frame["prompt_kind"],
        "select.type": _enum_name(SELECT_TYPE_NAMES, frame["select_semantics"]["select_type_raw"]),
        "select.context": _enum_name(SELECT_CONTEXT_NAMES, frame["select_semantics"]["select_context_raw"]),
        "select.type_raw": frame["select_semantics"]["select_type_raw"],
        "select.context_raw": frame["select_semantics"]["select_context_raw"],
        "turn_number": frame["public_state"]["turn_number"],
        "turn.supporter_available": turn.get("supporter_available"),
        "turn.manual_attachment_available": turn.get("manual_attachment_available"),
        "turn.retreat_available": turn.get("retreat_available"),
        "self.prizes_remaining": own["prizes_remaining"],
        "opponent.prizes_remaining": opponent["prizes_remaining"],
        "self.deck_count": own["deck_count"],
        "opponent.deck_count": opponent["deck_count"],
        "self.hand_count": len(own["hand"]),
        "opponent.hand_count": opponent["hand_count"],
        "self.bench_count": len(own["bench"]),
        "self.bench_capacity": own.get("bench_capacity"),
        "self.bench_space": (
            own["bench_capacity"] - len(own["bench"])
            if "bench_capacity" in own
            else None
        ),
        "self.bench_open": (
            len(own["bench"]) < own["bench_capacity"]
            if "bench_capacity" in own
            else any(
                current["kind"] == "play_basic_to_bench"
                for current in frame["options"]
            )
        ),
        "opponent.bench_count": len(opponent["bench"]),
        "self.active.remaining_hp": _active_scalar(own, "remaining_hp"),
        "self.active.prize_value": _active_scalar(own, "prize_value"),
        "self.active.attached_tool_uid": _active_scalar(own, "attached_tool_uid"),
        "opponent.active.remaining_hp": _active_scalar(opponent, "remaining_hp"),
        "opponent.active.prize_value": _active_scalar(opponent, "prize_value"),
        "window.source_uid": _window_uniform(frame, "source_uid"),
        "window.option_kind": _window_uniform(frame, "kind"),
        "window.attack_option_count": sum(
            1 for current in frame["options"] if current["kind"] == "attack"
        ),
        "select.min_count": frame["select_semantics"]["min_count"],
        "select.max_count": frame["select_semantics"]["max_count"],
        "goal.energy_debt": goal["energy_debt"],
        "goal.ready_count": goal["ready_count"],
        "goal.deployed_count": goal["deployed_count"],
        "goal.active_ready_count": goal["active_ready_count"],
        "goal.bench_ready_count": goal["bench_ready_count"],
        "goal.near_ready_count": goal["near_ready_count"],
        "goal.complete": goal["ready_count"] >= goal["required_target_count"],
        "threat.own_attacks_to_win": threat["own_attacks_to_win"],
        "threat.opponent_attacks_to_win": threat["opponent_attacks_to_win"],
        "threat.tempo_margin": threat["tempo_margin"],
    }
    if fact in scalar:
        return scalar[fact]
    if fact in {"goal.board_energy_count", "goal.hand_energy_count", "goal.discard_energy_count"}:
        energy_uids = set(goal.get("energy_uids", []))
        if fact == "goal.board_energy_count":
            return sum(
                1
                for slot in _self_slots(frame)
                for uid in slot["attached_energy_uids"]
                if uid in energy_uids
            )
        zone_name = "hand" if fact == "goal.hand_energy_count" else "discard"
        return sum(
            1
            for card in frame["public_state"]["self"][zone_name]
            if card["local_card_uid"] in energy_uids
        )
    if fact == "goal.immediate":
        if goal.get("active_ready_count", 0) > 0:
            return True
        return any(
            _goal_option_facts(goal, frame, current).get("pivots_ready_target", False)
            for current in frame["options"]
        )
    if fact in GOAL_UID_FACTS:
        field = fact.removeprefix("goal.").removesuffix("_uid")
        return goal.get("requirement_states", {}).get(card_uid, {}).get(field, 0)
    if fact == "goal.window.max_progress":
        return _goal_window_max_progress(goal, frame)
    if fact == "goal.option.is_max_progress":
        if option is None:
            return None
        progress = int(_goal_option_facts(goal, frame, option).get("progress", 0))
        maximum = _goal_window_max_progress(goal, frame)
        return maximum > 0 and progress == maximum
    if fact == "goal.window.max_setup_progress":
        return _goal_window_max_setup_progress(goal, frame)
    if fact == "goal.option.is_max_setup_progress":
        if option is None:
            return None
        progress = int(_goal_option_facts(goal, frame, option).get("progress", 0))
        maximum = _goal_window_max_setup_progress(goal, frame)
        return maximum > 0 and progress == maximum
    if fact.startswith("goal.option."):
        route_facts = _goal_option_facts(goal, frame, option)
        return route_facts.get(fact.removeprefix("goal.option."))
    if fact in ZONE_FACTS:
        return sum(
            1
            for item in _zone(frame, fact)
            if item["local_card_uid"] == card_uid
        )
    if fact in ENERGY_ZONE_FACTS:
        return sum(slot["attached_energy_uids"].count(card_uid) for slot in _zone(frame, fact))
    if fact in ENERGY_BEARING_ZONE_FACTS:
        return sum(
            1
            for slot in _zone(frame, fact)
            if slot["local_card_uid"] == card_uid
            and len(slot["attached_energy_uids"]) > 0
        )
    if fact in WINDOW_UID_FACTS:
        field = fact.removeprefix("window.option_count_")
        return sum(1 for current in frame["options"] if current[field] == card_uid)
    if fact in {"option.source_is_active", "option.target_is_active"}:
        if option is None:
            return None
        prefix = "source" if fact == "option.source_is_active" else "target"
        entity_serial = option.get(f"{prefix}_entity_serial")
        serial = option.get(f"{prefix}_serial")
        return (entity_serial is not None or serial is not None) and any(
            (
                slot.get("entity_serial") == entity_serial
                if entity_serial is not None
                else slot["serial"] == serial
            )
            for slot in frame["public_state"]["self"]["active"]
        )
    if fact.startswith("option."):
        return None if option is None else option.get(fact.split(".", 1)[1])
    return None


def _compare(actual: Any, op: str, expected: Any) -> bool:
    try:
        if op == "eq":
            return type(actual) is type(expected) and actual == expected
        if op == "ne":
            return type(actual) is not type(expected) or actual != expected
        if op == "contains":
            return type(actual) is list and expected in actual
        if op == "not_contains":
            return type(actual) is list and expected not in actual
        if type(actual) is not int or type(expected) is not int:
            return False
        if op == "lt":
            return actual < expected
        if op == "lte":
            return actual <= expected
        if op == "gt":
            return actual > expected
        if op == "gte":
            return actual >= expected
    except Exception:
        return False
    return False


def _matches(
    conditions: list[dict[str, Any]],
    frame: dict[str, Any],
    option: dict[str, Any] | None,
    goal: dict[str, int],
    threat: dict[str, int],
) -> bool:
    return all(
        _compare(
            _fact(condition["fact"], frame, option, goal, threat, condition["card_uid"]),
            condition["op"],
            condition["value"],
        )
        for condition in conditions
    )


def _trunc_div(value: int, divisor: int) -> int:
    return value // divisor if value >= 0 else -((-value) // divisor)


def _clamp_score(value: int) -> int:
    return max(-MAX_SCORE, min(MAX_SCORE, value))


def _base_tactical_floor(
    option: dict[str, Any], frame: dict[str, Any]
) -> dict[str, Any] | None:
    """Return the locked public Base floor for a strictly productive action.

    This is deliberately narrower than the classic deck strategy: a legal
    positive-damage attack dominates ending the same public turn, while
    zero/unknown-damage effect attacks remain adapter-owned.
    """
    if option["kind"] != "attack":
        return None
    projected_damage = option["projected_damage"]
    option_damage = frame.get("_derived_damage", {}).get("options", {}).get(
        str(option["index"]), {}
    )
    bench_damage = option_damage.get("bench_damage", 0)
    active_productive = type(projected_damage) is int and projected_damage > 0
    bench_productive = type(bench_damage) is int and bench_damage > 0
    if not active_productive and not bench_productive:
        return None
    return {
        "rule_id": "@base.positive-damage-attack",
        "channel": "base",
        "contribution": 1,
    }


def _executable_route_step(
    steps: list[dict[str, Any]],
    frame: dict[str, Any],
    goals: dict[str, dict[str, Any]],
    threat: dict[str, int],
) -> tuple[dict[str, Any], list[int]] | None:
    minimum = frame["select_semantics"]["min_count"]
    maximum = frame["select_semantics"]["max_count"]
    for step in steps:
        if frame["prompt_kind"] not in step["prompt_kinds"]:
            continue
        goal = goals[step["goal_id"]]
        if not _matches(step["when"], frame, None, goal, threat):
            continue
        matching = [
            option["index"]
            for option in frame["options"]
            if _matches(step["option_when"], frame, option, goal, threat)
        ]
        selection_count = step["selection_count"]
        if selection_count is not None:
            if not minimum <= selection_count <= maximum:
                continue
            if selection_count > len(matching):
                continue
            if selection_count == 0:
                return step, []
        if matching:
            return step, matching
    return None


def _route_budget_rejection(
    budget: dict[str, int], frame: dict[str, Any]
) -> str | None:
    own = frame["public_state"]["self"]
    turn = own.get("turn", {})
    if budget["supporter_uses"] > 0 and turn.get("supporter_available") is not True:
        return "supporter_unavailable"
    if (
        budget["manual_attachments"] > 0
        and turn.get("manual_attachment_available") is not True
    ):
        return "manual_attachment_unavailable"
    if budget["retreats"] > 0 and turn.get("retreat_available") is not True:
        return "retreat_unavailable"
    if budget["bench_slots"] > 0:
        capacity = own.get("bench_capacity")
        if type(capacity) is not int:
            return "bench_capacity_unknown"
        if capacity - len(own["bench"]) < budget["bench_slots"]:
            return "insufficient_bench_space"
    return None


def _route_component_value(
    component: dict[str, Any],
    frame: dict[str, Any],
    goal: dict[str, Any],
    threat: dict[str, int],
) -> int:
    value = component["base"]
    for term in component["terms"]:
        actual = _fact(term["fact"], frame, None, goal, threat, None)
        if type(actual) is not int:
            continue
        bounded = max(term["minimum"], min(term["maximum"], actual))
        value = _clamp_score(value + bounded * term["coefficient"])
    return value


def _route_candidate_adjudication(
    document: dict[str, Any],
    frame: dict[str, Any],
    goals: dict[str, dict[str, Any]],
    threat: dict[str, int],
) -> tuple[
    dict[str, Any] | None,
    dict[str, Any] | None,
    list[int],
    dict[str, Any],
]:
    considered: list[dict[str, Any]] = []
    proposals: list[
        tuple[tuple[int | str, ...], dict[str, Any], dict[str, Any], list[int], int]
    ] = []
    for order, route in enumerate(document.get("route_candidates", [])):
        goal = goals[route["goal_id"]]
        row: dict[str, Any] = {
            "route_id": route["route_id"],
            "accepted": False,
            "selected": False,
            "rejection_reason": "",
            "first_executable_step_id": None,
            "current_indexes": [],
            "value": None,
        }
        if not _matches(route["when"], frame, None, goal, threat):
            row["rejection_reason"] = "route_guard_unmatched"
            considered.append(row)
            continue
        rejection = _route_budget_rejection(route["resource_budget"], frame)
        if rejection is not None:
            row["rejection_reason"] = rejection
            considered.append(row)
            continue
        executable = _executable_route_step(route["steps"], frame, goals, threat)
        if executable is None:
            row["rejection_reason"] = "no_current_executable_step"
            considered.append(row)
            continue
        step, indexes = executable
        route_value = {
            component_name: _route_component_value(
                route["value"][component_name], frame, goal, threat
            )
            for component_name in ROUTE_VALUE_COMPONENTS
        }
        comparison: tuple[int | str, ...] = (
            route_value["attack_windows"],
            -route_value["prize_progress"],
            -route_value["continuity"],
            route_value["resource_cost"],
            route_value["response_risk"],
            route_value["uncertainty"],
            route["route_id"],
        )
        row.update(
            {
                "accepted": True,
                "first_executable_step_id": step["step_id"],
                "current_indexes": list(indexes),
                "value": route_value,
            }
        )
        considered.append(row)
        proposals.append((comparison, route, step, indexes, order))
    selected_route: dict[str, Any] | None = None
    selected_step: dict[str, Any] | None = None
    selected_indexes: list[int] = []
    selected_value: dict[str, int] | None = None
    if proposals:
        _comparison, selected_route, selected_step, selected_indexes, selected_order = min(
            proposals, key=lambda proposal: (proposal[0], proposal[4])
        )
        considered[selected_order]["selected"] = True
        selected_value = considered[selected_order]["value"]
    audit = {
        "comparison_order": [
            "attack_windows.asc",
            "prize_progress.desc",
            "continuity.desc",
            "resource_cost.asc",
            "response_risk.asc",
            "uncertainty.asc",
            "route_id.asc",
        ],
        "considered_routes": considered,
        "selected_route_id": (
            None if selected_route is None else selected_route["route_id"]
        ),
        "selected_step_id": (
            None if selected_step is None else selected_step["step_id"]
        ),
        "selected_value": selected_value,
        "public_current_window_only": True,
    }
    return selected_route, selected_step, list(selected_indexes), audit


def _current_turn_contract(
    document: dict[str, Any],
    frame: dict[str, Any],
    goals: dict[str, dict[str, Any]],
    threat: dict[str, int],
) -> tuple[dict[str, Any], list[dict[str, Any]], int | None]:
    own = frame["public_state"]["self"]
    ledger = copy.deepcopy(own.get("turn", {}))
    contract: dict[str, Any] = {
        "route_id": None,
        "route_source": None,
        "route_goal_id": None,
        "owner_goal_id": None,
        "bridge_goal_id": None,
        "pivot_goal_id": None,
        "first_executable_step_id": None,
        "interaction_recipe_id": None,
        "interaction_step_id": None,
        "terminal": False,
        "checkpoint": False,
        "sequence_barrier": False,
        "selection_count": None,
        "turn_ledger": ledger,
        "route_authority_indexes": [],
        "route_authority_eligible": False,
        "route_authority_applied": False,
        "route_candidate_adjudication": {},
        "current_window_only": True,
        "reobserve_after_commit": True,
        "stale_index_authority": False,
    }
    overlays: list[dict[str, Any]] = []
    selection_count: int | None = None
    selected_route: dict[str, Any] | None = None
    transaction_contract_update: dict[str, Any] | None = None
    transaction_selection_count: int | None = None

    turn_transaction = frame.get("_derived_turn_transaction", {})
    transaction_indexes = list(turn_transaction.get("current_indexes", []))
    if transaction_indexes:
        transaction_id = turn_transaction["transaction_id"]
        method_id = turn_transaction["method_id"]
        step_id = turn_transaction["step_id"]
        goal_id = turn_transaction["goal_id"]
        transaction_route = {
            "route_id": f"turn-transaction.{transaction_id}",
            "goal_id": goal_id,
        }
        transaction_selection_count = turn_transaction.get("selection_count")
        transaction_contract_update = {
            "route_id": transaction_route["route_id"],
            "route_source": "turn_transaction",
            "route_goal_id": goal_id,
            "owner_goal_id": goal_id,
            "bridge_goal_id": goal_id,
            "pivot_goal_id": goal_id,
            "first_executable_step_id": step_id,
            "terminal": bool(turn_transaction.get("terminal", False)),
            "checkpoint": bool(turn_transaction.get("checkpoint", False)),
            "sequence_barrier": bool(
                turn_transaction.get("sequence_barrier", False)
            ),
            "selection_count": transaction_selection_count,
            "route_authority_indexes": transaction_indexes,
            "turn_transaction_id": transaction_id,
            "turn_transaction_method_id": method_id,
            "attack_commit_blocked": bool(
                turn_transaction.get("attack_commit_blocked", False)
            ),
            "turn_commit_blocked": bool(
                turn_transaction.get("turn_commit_blocked", False)
            ),
        }
        overlays.append(
            {
                "rule_id": (
                    f"@turn_transaction.{transaction_id}.{method_id}.{step_id}"
                ),
                "channel": "turn_transaction",
                "contribution": turn_transaction.get("score_bonus", 0),
                "goal_id": goal_id,
                "indexes": transaction_indexes,
            }
        )

    candidate_route, candidate_step, candidate_indexes, candidate_audit = (
        _route_candidate_adjudication(document, frame, goals, threat)
    )
    contract["route_candidate_adjudication"] = candidate_audit
    if (
        selected_route is None
        and candidate_route is not None
        and candidate_step is not None
    ):
        selected_route = candidate_route
        selection_count = candidate_step["selection_count"]
        contract.update(
            {
                "route_id": candidate_route["route_id"],
                "route_source": "route_candidate",
                "route_goal_id": candidate_route["goal_id"],
                "owner_goal_id": candidate_route["owner_goal_id"],
                "bridge_goal_id": candidate_route["bridge_goal_id"],
                "pivot_goal_id": candidate_route["pivot_goal_id"],
                "first_executable_step_id": candidate_step["step_id"],
                "terminal": candidate_step["terminal"],
                "checkpoint": candidate_step["checkpoint"],
                "selection_count": selection_count,
                "route_authority_indexes": candidate_indexes,
            }
        )
        overlays.append(
            {
                "rule_id": (
                    f"@route_candidate.{candidate_route['route_id']}."
                    f"{candidate_step['step_id']}"
                ),
                "channel": "route_candidate",
                "contribution": 0,
                "goal_id": candidate_step["goal_id"],
                "indexes": candidate_indexes,
            }
        )

    ordered_routes = sorted(
        enumerate(document.get("turn_routes", [])),
        key=lambda pair: (-pair[1]["priority"], pair[0]),
    )
    for _order, route in ordered_routes if selected_route is None else []:
        goal = goals[route["goal_id"]]
        if not _matches(route["when"], frame, None, goal, threat):
            continue
        executable = _executable_route_step(route["steps"], frame, goals, threat)
        if executable is None:
            continue
        step, indexes = executable
        selected_route = route
        selection_count = step["selection_count"]
        contract.update(
            {
                "route_id": route["route_id"],
                "route_source": "turn_route",
                "route_goal_id": route["goal_id"],
                "owner_goal_id": route["owner_goal_id"],
                "bridge_goal_id": route["bridge_goal_id"],
                "pivot_goal_id": route["pivot_goal_id"],
                "first_executable_step_id": step["step_id"],
                "terminal": step["terminal"],
                "checkpoint": step["checkpoint"],
                "selection_count": selection_count,
            }
        )
        overlays.append(
            {
                "rule_id": f"@turn_route.{route['route_id']}.{step['step_id']}",
                "channel": "route",
                "contribution": step["score_bonus"],
                "goal_id": step["goal_id"],
                "indexes": indexes,
            }
        )
        break

    source_uid = _window_uniform(frame, "source_uid")
    ordered_recipes = sorted(
        enumerate(document.get("interaction_recipes", [])),
        key=lambda pair: (-pair[1]["priority"], pair[0]),
    )
    for _order, recipe in ordered_recipes:
        if source_uid not in recipe["source_uids"]:
            continue
        if recipe["route_id"] is not None and (
            selected_route is None or selected_route["route_id"] != recipe["route_id"]
        ):
            continue
        goal = goals[recipe["goal_id"]]
        if not _matches(recipe["when"], frame, None, goal, threat):
            continue
        executable = _executable_route_step(recipe["steps"], frame, goals, threat)
        if executable is None:
            continue
        step, indexes = executable
        if step["selection_count"] is not None:
            selection_count = step["selection_count"]
            contract["selection_count"] = selection_count
        contract["interaction_recipe_id"] = recipe["recipe_id"]
        contract["interaction_step_id"] = step["step_id"]
        contract["terminal"] = bool(contract["terminal"] or step["terminal"])
        contract["checkpoint"] = bool(contract["checkpoint"] or step["checkpoint"])
        overlays.append(
            {
                "rule_id": f"@interaction_recipe.{recipe['recipe_id']}.{step['step_id']}",
                "channel": "interaction_recipe",
                "contribution": step["score_bonus"],
                "goal_id": step["goal_id"],
                "indexes": indexes,
            }
        )
        break

    if not contract["terminal"]:
        ordered_contracts = sorted(
            enumerate(document.get("turn_bonus_contracts", [])),
            key=lambda pair: (-pair[1]["priority"], pair[0]),
        )
        for _order, bonus_contract in ordered_contracts:
            contract_goal = goals[bonus_contract["goal_id"]]
            if not _matches(
                bonus_contract["when"], frame, None, contract_goal, threat
            ):
                continue
            matched_bonus_ids: list[str] = []
            for bonus in bonus_contract["bonuses"]:
                if frame["prompt_kind"] not in bonus["prompt_kinds"]:
                    continue
                goal = goals[bonus["goal_id"]]
                if not _matches(bonus["when"], frame, None, goal, threat):
                    continue
                indexes = [
                    option["index"]
                    for option in frame["options"]
                    if _matches(bonus["option_when"], frame, option, goal, threat)
                ]
                if not indexes:
                    continue
                matched_bonus_ids.append(bonus["bonus_id"])
                overlays.append(
                    {
                        "rule_id": (
                            f"@turn_bonus.{bonus_contract['contract_id']}."
                            f"{bonus['bonus_id']}"
                        ),
                        "channel": "turn_bonus",
                        "contribution": bonus["score_bonus"],
                        "goal_id": bonus["goal_id"],
                        "indexes": indexes,
                    }
                )
            if matched_bonus_ids:
                contract["turn_bonus_contract_id"] = bonus_contract["contract_id"]
                contract["turn_bonus_ids"] = matched_bonus_ids
                break
    if transaction_contract_update is not None:
        # The transaction is a competing current-window proposal, not a
        # replacement for the independent route and bonus planners.
        contract["proposal_route_id"] = contract.get("route_id")
        contract["proposal_route_source"] = contract.get("route_source")
        contract["proposal_selection_count"] = selection_count
        contract["proposal_route_authority_indexes"] = copy.deepcopy(
            contract.get("route_authority_indexes", [])
        )
        contract.update(transaction_contract_update)
        selection_count = transaction_selection_count
    return contract, overlays, selection_count


def _evaluate(
    policy: CompetitivePolicyV2,
    frame: dict[str, Any],
) -> tuple[
    list[int],
    int,
    list[dict[str, Any]],
    list[dict[str, Any]],
    dict[str, int],
    bool,
    dict[str, int] | None,
    dict[str, Any],
]:
    document = policy.to_public_dict()
    goal_states, goals = _goal_states(document, frame)
    threat = _threat_clock(frame)
    turn_contract, route_overlays, route_selection_count = _current_turn_contract(
        document, frame, goals, threat
    )
    scorecards: list[dict[str, Any]] = []
    for option in frame["options"]:
        total = 0
        matched: list[dict[str, Any]] = []
        best_priority = 0
        base_floor = _base_tactical_floor(option, frame)
        if base_floor is not None:
            total = _clamp_score(total + base_floor["contribution"])
            matched.append(base_floor)
        for rule in document["rules"]:
            goal = goals[rule["goal_id"]]
            if not _matches(rule["when"], frame, option, goal, threat):
                continue
            raw = rule["base_score"]
            for term in rule["score_terms"]:
                actual = _fact(term["fact"], frame, option, goal, threat, None)
                if type(actual) is not int:
                    continue
                bounded = max(term["minimum"], min(term["maximum"], actual))
                raw = _clamp_score(raw + bounded * term["coefficient"])
            contribution = _trunc_div(raw * rule["confidence_milli"], 1000)
            total = _clamp_score(total + contribution)
            best_priority = max(best_priority, goal["priority"])
            matched.append(
                {
                    "rule_id": rule["rule_id"],
                    "channel": rule["channel"],
                    "contribution": contribution,
                }
            )
        proposal_total = total
        proposal_priority = best_priority
        for overlay in route_overlays:
            if option["index"] not in overlay["indexes"]:
                continue
            contribution = overlay["contribution"]
            total = _clamp_score(total + contribution)
            best_priority = max(best_priority, goals[overlay["goal_id"]]["priority"])
            if overlay["channel"] != "turn_transaction":
                proposal_total = _clamp_score(proposal_total + contribution)
                proposal_priority = max(
                    proposal_priority, goals[overlay["goal_id"]]["priority"]
                )
            matched.append(
                {
                    "rule_id": overlay["rule_id"],
                    "channel": overlay["channel"],
                    "contribution": contribution,
                }
            )
        scorecards.append(
            {
                "index": option["index"],
                "score": total,
                "goal_priority": best_priority,
                "proposal_score": proposal_total,
                "proposal_goal_priority": proposal_priority,
                "matched_rules": matched,
            }
        )
    option_kinds = {option["index"]: option["kind"] for option in frame["options"]}
    ranked = [
        card["index"]
        for card in sorted(
            scorecards,
            key=lambda card: (
                -card["score"],
                -card["goal_priority"],
                0 if option_kinds.get(card["index"]) == "end_turn" else 1,
                card["index"],
            ),
        )
    ]
    route_authority_indexes = turn_contract["route_authority_indexes"]
    route_authority_eligible = bool(
        route_authority_indexes
        and _turn_transaction_authority_eligible(frame, turn_contract, scorecards)
    )
    turn_contract["route_authority_eligible"] = route_authority_eligible
    if (
        turn_contract.get("route_source") == "turn_transaction"
        and not route_authority_eligible
    ):
        for card in scorecards:
            card["score"] = card["proposal_score"]
            card["goal_priority"] = card["proposal_goal_priority"]
            card["matched_rules"] = [
                rule
                for rule in card["matched_rules"]
                if rule.get("channel") != "turn_transaction"
            ]
        ranked = [
            card["index"]
            for card in sorted(
                scorecards,
                key=lambda card: (
                    -card["score"],
                    -card["goal_priority"],
                    0 if option_kinds.get(card["index"]) == "end_turn" else 1,
                    card["index"],
                ),
            )
        ]
        turn_contract["turn_transaction_suppressed_reason"] = (
            "independent_noncommit_proposal"
        )
        route_selection_count = turn_contract.get("proposal_selection_count")
    if route_authority_eligible:
        ranked = [
            *(index for index in ranked if index in route_authority_indexes),
            *(index for index in ranked if index not in route_authority_indexes),
        ]
    minimum = frame["select_semantics"]["min_count"]
    maximum = frame["select_semantics"]["max_count"]
    desired = minimum
    count_rule_matched = False
    selection_quotas: dict[str, int] | None = None
    ordered_count_rules = sorted(enumerate(document["count_rules"]), key=lambda pair: (pair[1]["priority"], pair[0]))
    for _order, rule in ordered_count_rules:
        goal = goals[rule["goal_id"]]
        if not _matches(rule["when"], frame, None, goal, threat):
            continue
        if rule["mode"] == "fixed":
            desired = rule["fixed_count"]
        elif rule["mode"] == "goal_energy_debt":
            desired = goal["energy_debt"]
        elif rule["mode"] == "goal_missing_energy_sources":
            selection_quotas = _goal_missing_energy_source_quotas(goal, frame)
            desired = sum(selection_quotas.values())
        elif rule["mode"] == "distinct_card_uids":
            selection_quotas = _distinct_card_uid_quotas(frame)
            desired = sum(selection_quotas.values())
        else:
            actual = _fact(rule["fact"], frame, None, goal, threat, None)
            if type(actual) is not int:
                continue
            lethal = int(math.ceil(max(0, actual) / rule["divisor"]))
            if rule["mode"] == "ceil_public_fact_divisor_with_reserve":
                available = len(frame["options"])
                desired = (
                    lethal
                    if lethal <= available
                    else max(0, available - rule["fixed_count"])
                )
            else:
                desired = lethal
        desired = max(minimum, min(maximum, desired))
        count_rule_matched = True
        break
    if route_authority_eligible and route_selection_count is not None:
        desired = max(minimum, min(maximum, route_selection_count))
        count_rule_matched = True
    return (
        ranked,
        desired,
        scorecards,
        goal_states,
        threat,
        count_rule_matched,
        selection_quotas,
        turn_contract,
    )


def _turn_transaction_authority_eligible(
    frame: dict[str, Any],
    turn_contract: dict[str, Any],
    scorecards: list[dict[str, Any]],
) -> bool:
    """Let a semantic transaction veto attack commit, not better setup actions.

    Adapter transactions propose an exact current-window debt. On a main-action
    window, that proposal becomes route authority only when the independently
    scored proposal would otherwise commit a normal attack. Interaction prompts
    and an already-active terminal transaction step retain exact authority.
    """
    if turn_contract.get("route_source") != "turn_transaction":
        return True
    if turn_contract.get("sequence_barrier"):
        # The adapter proposes a proven non-commutative ordering point. Base
        # still owns forced, terminal, hard-tier and veto adjudication.
        return True
    if frame.get("prompt_kind") != "main":
        return True
    option_kinds = {option["index"]: option["kind"] for option in frame["options"]}
    proposals = sorted(
        scorecards,
        key=lambda card: (
            -card["proposal_score"],
            -card["proposal_goal_priority"],
            0 if option_kinds.get(card["index"]) == "end_turn" else 1,
            card["index"],
        ),
    )
    if not proposals:
        return False
    proposal_kind = option_kinds.get(proposals[0]["index"])
    if turn_contract.get("terminal"):
        return proposal_kind in {"attack", "granted_attack", "end_turn"}
    return bool(
        turn_contract.get("turn_commit_blocked")
        and proposal_kind in {"attack", "granted_attack", "end_turn"}
    )


@dataclass(frozen=True, slots=True)
class CompetitivePolicyV2Decision:
    accepted: bool
    error_code: str
    selected_indexes: list[int]
    audit: dict[str, Any]


def _index_list(value: Any, option_count: int) -> bool:
    return (
        type(value) is list
        and len(value) == len(set(value))
        and all(type(index) is int and 0 <= index < option_count for index in value)
    )


def _turn_program_option_fact(
    option: dict[str, Any], frame: dict[str, Any] | None = None
) -> dict[str, Any]:
    public_target: dict[str, Any] = {}
    if (
        frame is not None
        and option["kind"] in {"attack", "granted_attack"}
        and frame.get("public_state", {}).get("opponent", {}).get("active")
    ):
        public_target = frame["public_state"]["opponent"]["active"][0]
    return {
        "kind": option["kind"],
        "card_uid": option.get("card_uid"),
        "source_uid": option.get("source_uid"),
        "target_uid": option.get("target_uid"),
        "tags": copy.deepcopy(option.get("tags", [])),
        "projected_damage": option.get("projected_damage"),
        "projected_knockout": bool(option.get("projected_knockout", False)),
        "target_remaining_hp": (
            option.get("target_remaining_hp")
            if option.get("target_remaining_hp") is not None
            else public_target.get("remaining_hp")
        ),
        "target_prize_value": (
            option.get("target_prize_value")
            if option.get("target_prize_value") is not None
            else public_target.get("prize_value")
        ),
    }


def _turn_program_condition_value(
    conditions: list[dict[str, Any]], fact: str
) -> Any:
    for condition in conditions:
        if condition.get("fact") == fact and condition.get("op") == "eq":
            return condition.get("value")
    return None


def _turn_program_action_semantics_profile(value: Any) -> bool:
    required = {"profile_id", "uid_effect_kinds", "uid_resource_claims"}
    if (
        type(value) is not dict
        or not required.issubset(value)
        or not set(value).issubset(required | {"uid_public_guards"})
    ):
        return False
    effects = value["uid_effect_kinds"]
    claims = value["uid_resource_claims"]
    if (
        value["profile_id"] != "ptcgdap-turn-program-action-semantics-v1"
        or type(effects) is not dict
        or not effects
        or type(claims) is not dict
        or set(effects) != set(claims)
    ):
        return False
    if not all(
        type(uid) is str
        and 1 <= len(uid) <= 128
        and type(effect) is str
        and effect in {
            "ability", "bench", "conversion", "damage_transfer", "disruption",
            "draw", "energy", "evolution", "handoff", "search", "tool",
        }
        and claims[uid] in {"none", "supporter", "manual_attachment", "retreat"}
        for uid, effect in effects.items()
    ):
        return False
    guards = value.get("uid_public_guards", {})
    if type(guards) is not dict or not set(guards).issubset(effects):
        return False
    for guard in guards.values():
        if (
            type(guard) is not dict
            or set(guard) != {
                "mode", "max_own_hand_count", "min_opponent_hand_count"
            }
            or guard["mode"] not in {"all", "any"}
            or (
                guard["max_own_hand_count"] is not None
                and (
                    type(guard["max_own_hand_count"]) is not int
                    or not 0 <= guard["max_own_hand_count"] <= 30
                )
            )
            or (
                guard["min_opponent_hand_count"] is not None
                and (
                    type(guard["min_opponent_hand_count"]) is not int
                    or not 0 <= guard["min_opponent_hand_count"] <= 30
                )
            )
            or (
                guard["max_own_hand_count"] is None
                and guard["min_opponent_hand_count"] is None
            )
        ):
            return False
    return True


def _turn_program_declared_semantics(
    card_uid: Any, action_semantics: dict[str, Any] | None
) -> tuple[str | None, str | None]:
    if (
        action_semantics is None
        or type(card_uid) is not str
        or card_uid not in action_semantics["uid_effect_kinds"]
    ):
        return None, None
    return (
        str(action_semantics["uid_effect_kinds"][card_uid]),
        str(action_semantics["uid_resource_claims"][card_uid]),
    )


def _turn_program_public_guard_satisfied(
    frame: dict[str, Any],
    binding: list[int],
    action_semantics: dict[str, Any] | None,
) -> bool:
    if action_semantics is None or not action_semantics.get("uid_public_guards"):
        return True
    guards = action_semantics["uid_public_guards"]
    guarded: list[dict[str, Any]] = []
    for index in binding:
        option = frame["options"][index]
        uid = option.get("card_uid") or option.get("source_uid")
        if uid in guards:
            guarded.append(guards[uid])
    if not guarded:
        return True
    own_hand = len(frame.get("public_state", {}).get("self", {}).get("hand", []))
    opponent_hand = int(
        frame.get("public_state", {}).get("opponent", {}).get("hand_count", 0) or 0
    )
    for guard in guarded:
        checks: list[bool] = []
        if guard["max_own_hand_count"] is not None:
            checks.append(own_hand <= guard["max_own_hand_count"])
        if guard["min_opponent_hand_count"] is not None:
            checks.append(opponent_hand >= guard["min_opponent_hand_count"])
        if not (all(checks) if guard["mode"] == "all" else any(checks)):
            return False
    return True


def _turn_program_effect_kind(
    step: dict[str, Any], action_semantics: dict[str, Any] | None = None
) -> str:
    option_kind = _turn_program_condition_value(step.get("option_when", []), "option.kind")
    card_uid = _turn_program_condition_value(step.get("option_when", []), "option.card_uid")
    if card_uid is None:
        card_uid = _turn_program_condition_value(step.get("option_when", []), "option.source_uid")
    declared_effect, _declared_claim = _turn_program_declared_semantics(
        card_uid, action_semantics
    )
    if declared_effect is not None:
        return declared_effect
    tokens = "-".join(
        str(step.get(key, "")).casefold()
        for key in ("step_id", "goal_id")
    )
    if option_kind in {"attack", "granted_attack"}:
        return "attack"
    if "munkidori" in tokens or "move-damage" in tokens or "transfer" in tokens:
        return "damage_transfer"
    if "iono" in tokens or "disrupt" in tokens:
        return "disruption"
    if "research" in tokens or "draw" in tokens or "refill" in tokens or "refresh" in tokens:
        return "draw"
    if option_kind == "evolve" or "evol" in tokens:
        return "evolution"
    if option_kind == "attach_energy" or "energy" in tokens or "fund" in tokens or "punk" in tokens:
        return "energy"
    if option_kind == "play_basic_to_bench" or "bench" in tokens or "reserve" in tokens:
        return "bench"
    if option_kind in {"send_out", "retreat", "switch"} or any(
        token in tokens for token in ("send-out", "retreat", "handoff", "pivot")
    ):
        return "handoff"
    if option_kind == "attach_tool":
        return "tool"
    if option_kind in {"search", "use_stadium_effect"} or "search" in tokens:
        return "search"
    if option_kind == "use_ability":
        return "ability"
    if any(token in tokens for token in ("gust", "prize", "devolution", "finish")):
        return "conversion"
    if option_kind == "end_turn":
        return "end_turn"
    return "search" if option_kind == "play_trainer" else "ability"


def _turn_program_terminal_kind(step: dict[str, Any]) -> str:
    if not bool(step.get("terminal", False)):
        return "none"
    option_kind = _turn_program_condition_value(step.get("option_when", []), "option.kind")
    return "attack" if option_kind in {"attack", "granted_attack"} else "end_turn"


def _turn_program_group_indexes(
    step: dict[str, Any],
    frame: dict[str, Any],
    candidate_indexes: list[int],
    goal: dict[str, Any],
    threat: dict[str, int],
) -> list[int] | None:
    groups = step.get("selection_groups", [])
    if not groups:
        return candidate_indexes
    allowed = set(candidate_indexes)
    used: set[int] = set()
    selected: list[int] = []
    for group in groups:
        group_indexes = [
            option["index"]
            for option in frame["options"]
            if option["index"] in allowed
            and option["index"] not in used
            and _matches(group["option_when"], frame, option, goal, threat)
        ]
        count = group["selection_count"]
        if len(group_indexes) < count:
            return None
        for index in group_indexes[:count]:
            used.add(index)
            selected.append(index)
    return selected


def _turn_program_step_binding(
    step: dict[str, Any],
    frame: dict[str, Any],
    goal: dict[str, Any],
    threat: dict[str, int],
) -> list[int] | None:
    if frame["prompt_kind"] not in step["prompt_kinds"]:
        return None
    indexes = [
        option["index"]
        for option in frame["options"]
        if _matches(step["option_when"], frame, option, goal, threat)
    ]
    indexes = _turn_program_group_indexes(step, frame, indexes, goal, threat)
    if indexes is None:
        return None
    count = step.get("selection_count")
    minimum = frame["select_semantics"]["min_count"]
    maximum = frame["select_semantics"]["max_count"]
    if count is not None and (
        count < minimum or count > maximum or count > len(indexes)
    ):
        return None
    return indexes if indexes else None


def _turn_program_proof(
    indexes: list[int],
    selection_count: int | None,
    frame: dict[str, Any],
    mandatory: list[int],
    terminal: list[int],
    tiers: dict[int, tuple[int, ...]],
    vetoed: list[int],
) -> dict[str, bool]:
    option_count = len(frame["options"])
    frontier = list(range(option_count))
    if frontier:
        best_tier = min(tiers[index] for index in frontier)
        frontier = [index for index in frontier if tiers[index] == best_tier]
    non_vetoed = [index for index in indexes if index not in vetoed]
    current = [index for index in non_vetoed if index in frontier]
    count = frame["select_semantics"]["min_count"] if selection_count is None else selection_count
    executable = len(current) >= count
    forced = terminal if terminal else mandatory
    forced_preserved = not forced or (
        len(forced) == count and set(forced).issubset(current)
    )
    return {
        "admissible": executable,
        "current_step_executable": executable,
        "mandatory_preserved": not mandatory or forced_preserved,
        "terminal_preserved": not terminal or forced_preserved,
        "base_vetoed": not non_vetoed,
    }


def _turn_program_semantic_step(
    step: dict[str, Any],
    transaction_id: str,
    method_id: str,
    previous: str | None,
    action_semantics: dict[str, Any] | None = None,
) -> dict[str, Any]:
    card_uid = _turn_program_condition_value(step.get("option_when", []), "option.card_uid")
    if card_uid is None:
        card_uid = _turn_program_condition_value(step.get("option_when", []), "option.source_uid")
    _declared_effect, declared_claim = _turn_program_declared_semantics(
        card_uid, action_semantics
    )
    return {
        "step_id": step["step_id"],
        "transaction_id": transaction_id,
        "method_id": method_id,
        "depends_on": [] if previous is None else [previous],
        "terminal_kind": _turn_program_terminal_kind(step),
        "effect_kind": _turn_program_effect_kind(step, action_semantics),
        "resource_claim": declared_claim,
    }


def _turn_program_terminal_options(
    frame: dict[str, Any],
    tiers: dict[int, tuple[int, ...]],
    vetoed: list[int],
) -> list[dict[str, Any]]:
    return [
        option
        for option in _turn_program_base_options(frame, tiers, vetoed)
        if option["kind"] in {"attack", "granted_attack", "end_turn"}
    ]


def _turn_program_base_options(
    frame: dict[str, Any],
    tiers: dict[int, tuple[int, ...]],
    vetoed: list[int],
) -> list[dict[str, Any]]:
    indexes = list(range(len(frame["options"])))
    if indexes:
        best_tier = min(tiers[index] for index in indexes)
        indexes = [index for index in indexes if tiers[index] == best_tier]
    return [
        option
        for option in frame["options"]
        if option["index"] in indexes
        and option["index"] not in vetoed
    ]


def _turn_program_base_effect_kind(
    option: dict[str, Any], action_semantics: dict[str, Any] | None = None
) -> str:
    kind = option["kind"]
    declared_effect, _declared_claim = _turn_program_declared_semantics(
        option.get("card_uid") or option.get("source_uid"), action_semantics
    )
    if declared_effect is not None and kind not in {"attack", "granted_attack", "end_turn"}:
        return declared_effect
    if kind in {"attack", "granted_attack"}:
        return "attack"
    if kind == "end_turn":
        return "end_turn"
    if kind == "evolve":
        return "evolution"
    if kind == "attach_energy" or kind == "assignment_target":
        return "energy"
    if kind == "attach_tool":
        return "tool"
    if kind in {"play_basic_to_bench", "setup_active", "setup_bench"}:
        return "bench"
    if kind in {"send_out", "retreat", "switch"}:
        return "handoff"
    if kind == "use_ability":
        return "ability"
    if kind in {"play_trainer", "play_stadium", "use_stadium_effect", "search"}:
        return "search"
    return "ability"


def _turn_program_base_resource_claim(
    option: dict[str, Any], action_semantics: dict[str, Any] | None
) -> str | None:
    _declared_effect, declared_claim = _turn_program_declared_semantics(
        option.get("card_uid") or option.get("source_uid"), action_semantics
    )
    if declared_claim is not None:
        return declared_claim
    if option["kind"] == "attach_energy":
        return "manual_attachment"
    if option["kind"] == "retreat":
        return "retreat"
    return None


def _turn_program_canary_profile(value: Any) -> bool:
    if type(value) is not dict or set(value) != {
        "profile_id",
        "allowed_source_kinds",
        "allowed_current_effect_kinds",
        "max_uncertainty_milli",
        "minimum_utility_margin",
    }:
        return False
    if value["profile_id"] != "ptcgdap-turn-program-canary-v1":
        return False
    sources = value["allowed_source_kinds"]
    effects = value["allowed_current_effect_kinds"]
    return bool(
        type(sources) is list
        and sources
        and len(sources) == len(set(sources))
        and all(source in {
            "turn_transaction", "turn_route", "base_action"
        } for source in sources)
        and type(effects) is list
        and effects
        and len(effects) == len(set(effects))
        and all(effect in {
            "ability", "bench", "conversion", "damage_transfer",
            "disruption", "draw", "energy", "evolution", "handoff",
            "search", "tool",
        } for effect in effects)
        and _safe_int(value["max_uncertainty_milli"])
        and value["max_uncertainty_milli"] <= 1000
        and _safe_int(value["minimum_utility_margin"])
        and value["minimum_utility_margin"] <= 10_000_000
    )


def _automatic_turn_program_candidates(
    document: dict[str, Any],
    frame: dict[str, Any],
    goals: dict[str, dict[str, Any]],
    threat: dict[str, int],
    mandatory: list[int],
    terminal: list[int],
    tiers: dict[int, tuple[int, ...]],
    vetoed: list[int],
    ranked_indexes: list[int],
    action_semantics: dict[str, Any] | None = None,
) -> tuple[list[dict[str, Any]], dict[str, list[int]]]:
    candidates: list[dict[str, Any]] = []
    bindings: dict[str, list[int]] = {}
    terminal_options = _turn_program_terminal_options(frame, tiers, vetoed)
    terminal_facts = [
        _turn_program_option_fact(option, frame)
        for option in terminal_options
        if option["kind"] in {"attack", "granted_attack"}
    ]

    for transaction in document.get("turn_transactions", []):
        goal = goals[transaction["goal_id"]]
        if not _matches(transaction["when"], frame, None, goal, threat):
            continue
        if transaction["success_when"] and _matches(
            transaction["success_when"], frame, None, goal, threat
        ):
            continue
        if transaction["abort_when"] and _matches(
            transaction["abort_when"], frame, None, goal, threat
        ):
            continue
        for method in transaction["methods"]:
            if not _matches(method["when"], frame, None, goal, threat):
                continue
            required_steps = [
                step
                for step in method["steps"]
                if not (
                    step["complete_when"]
                    and _matches(step["complete_when"], frame, None, goals[step["goal_id"]], threat)
                )
                and (
                    not step["required_when"]
                    or _matches(step["required_when"], frame, None, goals[step["goal_id"]], threat)
                )
            ]
            current_offset = -1
            current_indexes: list[int] = []
            for offset, step in enumerate(required_steps):
                bound = _turn_program_step_binding(
                    step, frame, goals[step["goal_id"]], threat
                )
                if bound is not None:
                    current_offset = offset
                    current_indexes = bound
                    break
            if current_offset < 0:
                continue
            current_step = required_steps[current_offset]
            selected_steps = [current_step]
            if not current_step["terminal"]:
                for step in required_steps[current_offset + 1 :]:
                    if len(selected_steps) >= 7 or step["terminal"]:
                        break
                    if step.get("required_before_attack", False):
                        selected_steps.append(step)
            semantic_steps: list[dict[str, Any]] = []
            previous: str | None = None
            for step in selected_steps:
                semantic = _turn_program_semantic_step(
                    step, transaction["transaction_id"], method["method_id"], previous,
                    action_semantics,
                )
                semantic_steps.append(semantic)
                previous = semantic["step_id"]
            if semantic_steps[-1]["terminal_kind"] == "none" and terminal_facts:
                terminal_id = f"terminal-after-{semantic_steps[0]['step_id']}"
                semantic_steps.append(
                    {
                        "step_id": terminal_id[:128],
                        "transaction_id": transaction["transaction_id"],
                        "method_id": method["method_id"],
                        "depends_on": [previous],
                        "terminal_kind": "attack",
                        "effect_kind": "attack",
                        "resource_claim": "none",
                    }
                )
            program_id = f"tx.{transaction['transaction_id']}.{method['method_id']}"[:128]
            proof = _turn_program_proof(
                current_indexes,
                current_step.get("selection_count"),
                frame,
                mandatory,
                terminal,
                tiers,
                vetoed,
            )
            candidates.append(
                {
                    "program_id": program_id,
                    "goal_id": transaction["goal_id"],
                    "route_id": transaction["transaction_id"],
                    "deadline_turns": transaction["deadline_turns"],
                    "priority": transaction["priority"] + method["priority"],
                    "source_kind": "turn_transaction",
                    "semantic_steps": semantic_steps,
                    "current_step_id": semantic_steps[0]["step_id"],
                    "current_option_facts": [
                        _turn_program_option_fact(frame["options"][index], frame)
                        for index in current_indexes
                    ],
                    "terminal_option_facts": copy.deepcopy(terminal_facts),
                    "base_proof": proof,
                }
            )
            bindings[program_id] = list(current_indexes)

    for route in document.get("turn_routes", []):
        goal = goals[route["goal_id"]]
        if not _matches(route["when"], frame, None, goal, threat):
            continue
        executable = _executable_route_step(route["steps"], frame, goals, threat)
        if executable is None:
            continue
        current_step, current_indexes = executable
        current_offset = route["steps"].index(current_step)
        source_steps = [current_step]
        if not current_step["terminal"]:
            for step in route["steps"][current_offset + 1 :]:
                source_steps.append(step)
                if step["terminal"] or len(source_steps) >= 7:
                    break
        semantic_steps = []
        previous = None
        for step in source_steps:
            semantic = _turn_program_semantic_step(
                step, route["route_id"], route["route_id"], previous,
                action_semantics,
            )
            semantic_steps.append(semantic)
            previous = semantic["step_id"]
        if semantic_steps[-1]["terminal_kind"] == "none" and terminal_facts:
            terminal_id = f"terminal-after-{semantic_steps[0]['step_id']}"
            semantic_steps.append(
                {
                    "step_id": terminal_id[:128],
                    "transaction_id": route["route_id"],
                    "method_id": route["route_id"],
                    "depends_on": [previous],
                    "terminal_kind": "attack",
                    "effect_kind": "attack",
                    "resource_claim": "none",
                }
            )
        program_id = f"route.{route['route_id']}"[:128]
        proof = _turn_program_proof(
            current_indexes,
            current_step.get("selection_count"),
            frame,
            mandatory,
            terminal,
            tiers,
            vetoed,
        )
        candidates.append(
            {
                "program_id": program_id,
                "goal_id": route["goal_id"],
                "route_id": route["route_id"],
                "deadline_turns": 0,
                "priority": route["priority"],
                "source_kind": "turn_route",
                "semantic_steps": semantic_steps,
                "current_step_id": semantic_steps[0]["step_id"],
                "current_option_facts": [
                    _turn_program_option_fact(frame["options"][index], frame)
                    for index in current_indexes
                ],
                "terminal_option_facts": copy.deepcopy(terminal_facts),
                "base_proof": proof,
            }
        )
        bindings[program_id] = list(current_indexes)

    seen_base_ids: set[str] = set()
    base_options = _turn_program_base_options(frame, tiers, vetoed)
    rank_by_index = {index: offset for offset, index in enumerate(ranked_indexes)}
    for option in base_options:
        if len(candidates) >= 64:
            break
        semantic_identity = {
            key: option.get(key)
            for key in (
                "kind",
                "card_uid",
                "card_serial",
                "source_uid",
                "source_serial",
                "source_entity_serial",
                "target_uid",
                "target_serial",
                "target_entity_serial",
                "attack_index",
                "ability_index",
                "option_number",
                "projected_damage",
                "projected_knockout",
            )
        }
        digest = _sha(semantic_identity)[:16].casefold()
        program_id = f"base.{option['kind']}.{digest}"
        if program_id in seen_base_ids:
            continue
        seen_base_ids.add(program_id)
        terminal_kind = (
            "end_turn"
            if option["kind"] == "end_turn"
            else "attack"
            if option["kind"] in {"attack", "granted_attack"}
            else "none"
        )
        step_id = f"current-{option['kind']}-{digest}"
        facts = [_turn_program_option_fact(option, frame)]
        proof = _turn_program_proof(
            [option["index"]],
            1,
            frame,
            mandatory,
            terminal,
            tiers,
            vetoed,
        )
        candidates.append(
            {
                "program_id": program_id,
                "goal_id": "base-terminal",
                "route_id": program_id,
                "deadline_turns": 0,
                "priority": (
                    0
                    if terminal_kind != "none"
                    else max(0, 8000 - 250 * rank_by_index.get(option["index"], 32))
                ),
                "source_kind": (
                    "base_terminal" if terminal_kind != "none" else "base_action"
                ),
                "semantic_steps": [
                    {
                        "step_id": step_id,
                        "transaction_id": "base-terminal",
                        "method_id": f"current-{option['kind']}",
                        "depends_on": [],
                        "terminal_kind": terminal_kind,
                        "effect_kind": _turn_program_base_effect_kind(
                            option, action_semantics
                        ),
                        "resource_claim": _turn_program_base_resource_claim(
                            option, action_semantics
                        ),
                    }
                ],
                "current_step_id": step_id,
                "current_option_facts": facts,
                "terminal_option_facts": facts if terminal_kind == "attack" else [],
                "base_proof": proof,
            }
        )
        bindings[program_id] = [option["index"]]
    return candidates, bindings


class CompetitivePolicyV2Runtime:
    @staticmethod
    def decide(
        policy: Any,
        frame: Any,
        *,
        mandatory_indexes: list[int] | None = None,
        terminal_indexes: list[int] | None = None,
        base_hard_tiers: list[dict[str, Any]] | None = None,
        base_vetoed_indexes: list[int] | None = None,
        transaction_journal: SemanticTransactionJournal | None = None,
        turn_transaction_journal: TurnTransactionJournal | None = None,
        turn_program_request: dict[str, Any] | None = None,
        turn_program_journal: TurnProgramJournal | None = None,
        auto_turn_program_shadow: bool = False,
        turn_program_canary_profile: dict[str, Any] | None = None,
        turn_program_value_model: dict[str, Any] | None = None,
        turn_program_action_semantics: dict[str, Any] | None = None,
    ) -> CompetitivePolicyV2Decision:
        if type(policy) is not CompetitivePolicyV2 or not policy.validate_integrity():
            return CompetitivePolicyV2Decision(False, "invalid_policy", [], {})
        frame_value = copy.deepcopy(frame)
        error = _frame_error(frame_value)
        if error is not None:
            return CompetitivePolicyV2Decision(False, error, [], {})
        turn_program_frame = copy.deepcopy(frame_value)
        document = policy.to_public_dict()
        damage_result: dict[str, Any] = {
            "accepted": True,
            "error_code": "",
            "facts": {},
            "options": {},
            "targets": {},
            "audit_hash": "",
        }
        if document.get("damage_plans"):
            damage_result = PublicDamagePlanner.calculate(
                frame_value,
                document["damage_plans"],
                PublicDamageCapabilityRegistry.load_default(),
            )
            if not damage_result.get("accepted"):
                return CompetitivePolicyV2Decision(
                    False,
                    str(damage_result.get("error_code", "damage_plan_failed")),
                    [],
                    {},
                )
        transaction_result: dict[str, Any] = {
            "accepted": True,
            "error_code": "",
            "event": "idle",
            "reason": "journal_not_bound",
            "state": {},
            "audit_hash": "",
        }
        if document.get("semantic_transactions") and transaction_journal is not None:
            transaction_result = transaction_journal.advance(
                frame_value,
                document["semantic_transactions"],
                damage_result,
            )
            if not transaction_result.get("accepted"):
                return CompetitivePolicyV2Decision(
                    False,
                    str(transaction_result.get("error_code", "semantic_transaction_failed")),
                    [],
                    {},
                )
        frame_value["_derived_damage"] = damage_result
        frame_value["_derived_transaction"] = transaction_result
        turn_transaction_result: dict[str, Any] = {
            "accepted": True,
            "error_code": "",
            "event": "idle",
            "reason": "journal_not_bound",
            "transaction_id": None,
            "method_id": None,
            "step_id": None,
            "goal_id": None,
            "current_indexes": [],
            "selection_count": None,
            "score_bonus": 0,
            "terminal": False,
            "checkpoint": False,
            "sequence_barrier": False,
            "required_before_attack": False,
            "attack_commit_blocked": False,
            "turn_commit_blocked": False,
            "state": {},
            "audit_hash": "",
        }
        if document.get("turn_transactions") and turn_transaction_journal is not None:
            _transaction_goal_states, transaction_goals = _goal_states(
                document, frame_value
            )
            transaction_threat = _threat_clock(frame_value)

            def transaction_matches(
                conditions: list[dict[str, Any]],
                option: dict[str, Any] | None,
                goal_id: str,
            ) -> bool:
                return _matches(
                    conditions,
                    frame_value,
                    option,
                    transaction_goals[goal_id],
                    transaction_threat,
                )

            turn_transaction_result = turn_transaction_journal.advance(
                frame_value,
                document["turn_transactions"],
                transaction_matches,
            )
            if not turn_transaction_result.get("accepted"):
                return CompetitivePolicyV2Decision(
                    False,
                    str(
                        turn_transaction_result.get(
                            "error_code", "turn_transaction_failed"
                        )
                    ),
                    [],
                    {},
                )
        frame_value["_derived_turn_transaction"] = turn_transaction_result
        turn_program_shadow: dict[str, Any] = {
            "accepted": True,
            "error_code": "",
            "mode": "shadow",
            "authoritative": False,
            "public_only": True,
            "selected_program_id": None,
            "selected_current_step_id": None,
            "ranked_program_ids": [],
            "candidate_audit": [],
            "reobserve_before_execution": True,
            "stale_plan_has_authority": False,
            "reason": "shadow_not_requested",
            "audit_hash": "",
        }
        if turn_program_request is not None:
            try:
                turn_program_shadow = (
                    turn_program_journal.advance(
                        turn_program_frame, turn_program_request
                    )
                    if turn_program_journal is not None
                    else TurnProgramShadowPlanner.evaluate(
                        turn_program_frame, turn_program_request
                    )
                )
            except (AttributeError, KeyError, TypeError, ValueError, RecursionError):
                turn_program_shadow = {
                    **turn_program_shadow,
                    "accepted": False,
                    "error_code": "turn_program_shadow_failure",
                    "reason": "shadow_failed_closed",
                }
        if type(auto_turn_program_shadow) is not bool:
            return CompetitivePolicyV2Decision(False, "invalid_turn_program_shadow_mode", [], {})
        if turn_program_canary_profile is not None and not _turn_program_canary_profile(
            turn_program_canary_profile
        ):
            return CompetitivePolicyV2Decision(
                False, "invalid_turn_program_canary_profile", [], {}
            )
        if turn_program_canary_profile is not None and not auto_turn_program_shadow:
            return CompetitivePolicyV2Decision(
                False, "turn_program_canary_requires_fresh_generation", [], {}
            )
        if turn_program_action_semantics is not None and not _turn_program_action_semantics_profile(
            turn_program_action_semantics
        ):
            return CompetitivePolicyV2Decision(
                False, "invalid_turn_program_action_semantics", [], {}
            )
        if turn_program_action_semantics is not None and not auto_turn_program_shadow:
            return CompetitivePolicyV2Decision(
                False, "turn_program_action_semantics_requires_fresh_generation", [], {}
            )
        turn_program_generation: dict[str, Any] = {
            "accepted": False,
            "error_code": "turn_program_generation_not_requested",
            "mode": "shadow",
            "authoritative": False,
            "public_only": True,
            "candidate_count": 0,
            "emitted_count": 0,
            "request": None,
            "candidate_audit": [],
            "audit_hash": "",
        }
        turn_program_differential: dict[str, Any] = {
            "accepted": False,
            "error_code": "turn_program_differential_not_requested",
            "current_step_matches_live": False,
            "shadow_current_binding_found": False,
            "live_selected_option_kinds": [],
            "live_turn_route_id": None,
            "shadow_program_id": None,
            "shadow_current_step_id": None,
            "public_only": True,
            "authoritative": False,
        }
        turn_program_canary: dict[str, Any] = {
            "accepted": turn_program_canary_profile is not None,
            "error_code": "",
            "requested": turn_program_canary_profile is not None,
            "applied": False,
            "authoritative": False,
            "public_only": True,
            "reason": (
                "not_requested"
                if turn_program_canary_profile is None
                else "awaiting_fresh_generation"
            ),
            "selected_program_id": None,
            "selected_current_step_id": None,
            "utility_source": None,
            "selected_utility": None,
            "live_utility": None,
            "minimum_utility_margin": None,
            "reobserve_before_execution": True,
            "stale_plan_has_authority": False,
        }
        option_count = len(frame_value["options"])
        mandatory = [] if mandatory_indexes is None else copy.deepcopy(mandatory_indexes)
        terminal = [] if terminal_indexes is None else copy.deepcopy(terminal_indexes)
        vetoed = [] if base_vetoed_indexes is None else copy.deepcopy(base_vetoed_indexes)
        if not all(_index_list(value, option_count) for value in (mandatory, terminal, vetoed)):
            return CompetitivePolicyV2Decision(False, "invalid_base_authority", [], {})
        if base_hard_tiers is None:
            tiers = {index: (0,) for index in range(option_count)}
        else:
            if type(base_hard_tiers) is not list or len(base_hard_tiers) != option_count:
                return CompetitivePolicyV2Decision(False, "invalid_base_authority", [], {})
            tiers: dict[int, tuple[int, ...]] = {}
            for entry in base_hard_tiers:
                if (
                    type(entry) is not dict
                    or set(entry) != {"index", "tier"}
                    or type(entry["index"]) is not int
                    or not 0 <= entry["index"] < option_count
                    or entry["index"] in tiers
                    or type(entry["tier"]) is not list
                    or not entry["tier"]
                    or len(entry["tier"]) > 8
                    or any(not _safe_int(part, signed=True) for part in entry["tier"])
                ):
                    return CompetitivePolicyV2Decision(False, "invalid_base_authority", [], {})
                tiers[entry["index"]] = tuple(entry["tier"])
            if set(tiers) != set(range(option_count)):
                return CompetitivePolicyV2Decision(False, "invalid_base_authority", [], {})
        minimum = frame_value["select_semantics"]["min_count"]
        maximum = frame_value["select_semantics"]["max_count"]
        for forced in (terminal, mandatory):
            if forced and not minimum <= len(forced) <= maximum:
                return CompetitivePolicyV2Decision(False, "invalid_base_authority", [], {})
        (
            ranked,
            desired,
            scorecards,
            goals,
            threat,
            count_matched,
            selection_quotas,
            turn_contract,
        ) = _evaluate(policy, frame_value)
        any_rule_matched = any(card["matched_rules"] for card in scorecards)
        if not count_matched and not any_rule_matched:
            end_turn = [
                option["index"]
                for option in frame_value["options"]
                if option["kind"] == "end_turn"
            ]
            ranked = [*end_turn, *(index for index in ranked if index not in end_turn)]
        fallback_used = False
        if terminal:
            owner = "terminal"
            selected = list(terminal)
        elif mandatory:
            owner = "mandatory"
            selected = list(mandatory)
        else:
            owner = "base_graph"
            frontier = list(range(option_count))
            if frontier:
                best_tier = min(tiers[index] for index in frontier)
                frontier = [index for index in frontier if tiers[index] == best_tier]
            frontier = [index for index in frontier if index not in vetoed]
            ordered = [index for index in ranked if index in frontier]
            if selection_quotas is not None:
                remaining = dict(selection_quotas)
                typed_ordered: list[int] = []
                for index in ordered:
                    uid = frame_value["options"][index].get("card_uid")
                    if type(uid) is str and remaining.get(uid, 0) > 0:
                        typed_ordered.append(index)
                        remaining[uid] -= 1
                if len(typed_ordered) < minimum:
                    fallback_used = True
                    desired = minimum
                    selected = ordered[:desired]
                else:
                    desired = max(minimum, min(maximum, len(typed_ordered)))
                    selected = typed_ordered[:desired]
            else:
                if desired > len(ordered):
                    fallback_used = True
                    desired = minimum
                selected = ordered[:desired]
            if not minimum <= len(selected) <= maximum:
                return CompetitivePolicyV2Decision(False, "insufficient_candidates", [], {})
            if not count_matched and not any_rule_matched:
                fallback_used = True
            elif not count_matched and any(
                frame_value["options"][index]["kind"] == "end_turn"
                and not scorecards[index]["matched_rules"]
                for index in selected
            ):
                # A veto/negative rule on some other option must not make a
                # neutral, unmatched action outrank Base's safe end-turn tie
                # fallback. Keep the audit honest about who owned that choice.
                fallback_used = True
        normalized_candidates: list[dict[str, Any]] = []
        semantic_bindings: dict[str, list[int]] = {}
        if auto_turn_program_shadow and turn_program_request is None:
            try:
                _auto_goal_states, auto_goals = _goal_states(document, frame_value)
                normalized_candidates, semantic_bindings = (
                    _automatic_turn_program_candidates(
                        document,
                        frame_value,
                        auto_goals,
                        threat,
                        mandatory,
                        terminal,
                        tiers,
                        vetoed,
                        ranked,
                        turn_program_action_semantics,
                    )
                )
                turn_program_generation = TurnProgramGenerator.generate(
                    turn_program_frame,
                    normalized_candidates,
                    max_programs=8,
                    value_model=turn_program_value_model,
                )
                generated_request = turn_program_generation.get("request")
                if turn_program_generation.get("accepted") and type(generated_request) is dict:
                    turn_program_shadow = (
                        turn_program_journal.advance(turn_program_frame, generated_request)
                        if turn_program_journal is not None
                        else TurnProgramShadowPlanner.evaluate(
                            turn_program_frame, generated_request
                        )
                    )
                else:
                    turn_program_shadow = {
                        **turn_program_shadow,
                        "accepted": False,
                        "error_code": str(
                            turn_program_generation.get(
                                "error_code", "turn_program_generation_failed"
                            )
                        ),
                        "reason": "automatic_generation_failed_closed",
                    }
                selected_program_id = turn_program_shadow.get("selected_program_id")
                shadow_binding = semantic_bindings.get(selected_program_id, [])
                live_kinds = [
                    frame_value["options"][index]["kind"] for index in selected
                ]
                turn_program_differential = {
                    "accepted": bool(turn_program_shadow.get("accepted", False)),
                    "error_code": str(turn_program_shadow.get("error_code", "")),
                    "current_step_matches_live": bool(
                        shadow_binding
                        and len(shadow_binding) == len(selected)
                        and set(shadow_binding) == set(selected)
                    ),
                    "shadow_current_binding_found": bool(shadow_binding),
                    "live_selected_option_kinds": live_kinds,
                    "live_turn_route_id": turn_contract.get("route_id"),
                    "shadow_program_id": selected_program_id,
                    "shadow_current_step_id": turn_program_shadow.get(
                        "selected_current_step_id"
                    ),
                    "public_only": True,
                    "authoritative": False,
                }
                if turn_program_canary_profile is not None:
                    selected_candidate = next(
                        (
                            candidate
                            for candidate in normalized_candidates
                            if candidate["program_id"] == selected_program_id
                        ),
                        None,
                    )
                    selected_generation_audit = next(
                        (
                            row
                            for row in turn_program_generation.get(
                                "candidate_audit", []
                            )
                            if row.get("program_id") == selected_program_id
                        ),
                        None,
                    )
                    selected_final_audit = next(
                        (
                            row
                            for row in turn_program_shadow.get("candidate_audit", [])
                            if row.get("program_id") == selected_program_id
                        ),
                        None,
                    )
                    live_final_rows = [
                        row
                        for row in turn_program_shadow.get("candidate_audit", [])
                        if semantic_bindings.get(row.get("program_id"), [])
                        and len(semantic_bindings[row["program_id"]]) == len(selected)
                        and set(semantic_bindings[row["program_id"]]) == set(selected)
                    ]
                    live_utility = max(
                        (int(row.get("utility_milli", 0)) for row in live_final_rows),
                        default=0,
                    )
                    selected_utility = (
                        None
                        if selected_final_audit is None
                        else int(selected_final_audit.get("utility_milli", 0))
                    )
                    reason = "eligible"
                    if not turn_program_shadow.get("accepted") or not shadow_binding:
                        reason = "shadow_binding_unavailable"
                    elif owner != "base_graph":
                        reason = "base_authority_not_delegable"
                    elif (
                        selected_candidate is None
                        or selected_generation_audit is None
                        or selected_final_audit is None
                    ):
                        reason = "selected_candidate_unavailable"
                    elif selected_candidate["source_kind"] not in turn_program_canary_profile[
                        "allowed_source_kinds"
                    ]:
                        reason = "source_kind_not_allowed"
                    elif selected_candidate["semantic_steps"][0]["effect_kind"] not in turn_program_canary_profile[
                        "allowed_current_effect_kinds"
                    ]:
                        reason = "effect_kind_not_allowed"
                    elif not _turn_program_public_guard_satisfied(
                        frame_value, shadow_binding, turn_program_action_semantics
                    ):
                        reason = "public_precondition_not_met"
                    elif not live_final_rows:
                        reason = "live_utility_unavailable"
                    else:
                        transition = selected_generation_audit.get(
                            "transition_evaluation", {}
                        )
                        if (
                            not transition.get("accepted")
                            or not transition.get("commit_safe")
                            or int(transition.get("uncertainty_milli", 1000))
                            > turn_program_canary_profile["max_uncertainty_milli"]
                        ):
                            reason = "transition_not_commit_safe"
                        elif not any(
                            frame_value["options"][index]["kind"]
                            in {"attack", "granted_attack", "end_turn"}
                            for index in selected
                        ):
                            reason = "live_selection_not_a_commit"
                        elif any(
                            int(row.get("final_prize_knockout", 0)) == 1
                            for row in live_final_rows
                        ):
                            reason = "final_prize_terminal_protected"
                        elif selected_utility < (
                            live_utility
                            + turn_program_canary_profile["minimum_utility_margin"]
                        ):
                            reason = "utility_margin_not_met"
                    applied = reason == "eligible"
                    if applied:
                        selected = list(shadow_binding)
                        owner = "turn_program_canary"
                    turn_program_canary = {
                        **turn_program_canary,
                        "applied": applied,
                        "authoritative": applied,
                        "reason": reason,
                        "selected_program_id": selected_program_id,
                        "selected_current_step_id": turn_program_shadow.get(
                            "selected_current_step_id"
                        ),
                        "utility_source": "turn_program_shadow_final",
                        "selected_utility": selected_utility,
                        "live_utility": live_utility if live_final_rows else None,
                        "minimum_utility_margin": turn_program_canary_profile[
                            "minimum_utility_margin"
                        ],
                    }
            except (AttributeError, KeyError, TypeError, ValueError, RecursionError):
                turn_program_generation = {
                    **turn_program_generation,
                    "error_code": "turn_program_generation_failure",
                }
                turn_program_shadow = {
                    **turn_program_shadow,
                    "accepted": False,
                    "error_code": "turn_program_shadow_failure",
                    "reason": "automatic_shadow_failed_closed",
                }
                turn_program_differential = {
                    **turn_program_differential,
                    "error_code": "turn_program_differential_failure",
                }
                if turn_program_canary_profile is not None:
                    turn_program_canary = {
                        **turn_program_canary,
                        "accepted": False,
                        "error_code": "turn_program_canary_failure",
                        "reason": "failed_closed",
                    }
        audit_payload = {
            "schema_version": 2,
            "profile_id": PROFILE_ID,
            "policy_hash": policy.policy_hash,
            "public_observation_hash": frame_value["source"]["public_observation_hash"],
            "window_id": frame_value["source"]["window_id"],
            "owner_layer": owner,
            "ranked_indexes": ranked,
            "desired_count": desired,
            "selected_indexes": selected,
            "goal_states": goals,
            "threat_clock": threat,
            "turn_contract": turn_contract,
            "damage_plan": {
                "audit_hash": damage_result.get("audit_hash", ""),
                "facts": copy.deepcopy(damage_result.get("facts", {})),
                "best_target_entity_serial": damage_result.get("best_target_entity_serial"),
            },
            "semantic_transaction": copy.deepcopy(transaction_result),
            "turn_transaction": copy.deepcopy(turn_transaction_result),
            "scorecards": scorecards,
            "fallback_used": fallback_used,
            "public_only": True,
            "stale_plan_has_authority": False,
        }
        if turn_program_request is not None or auto_turn_program_shadow:
            audit_payload["turn_program_shadow"] = copy.deepcopy(turn_program_shadow)
        if auto_turn_program_shadow and turn_program_request is None:
            audit_payload["turn_program_generation"] = copy.deepcopy(
                turn_program_generation
            )
            audit_payload["turn_program_differential"] = copy.deepcopy(
                turn_program_differential
            )
        if turn_program_canary_profile is not None:
            audit_payload["turn_program_canary"] = copy.deepcopy(turn_program_canary)
        authority_indexes = turn_contract.get("route_authority_indexes", [])
        turn_contract["route_authority_applied"] = bool(
            authority_indexes
            and turn_contract.get("route_authority_eligible", False)
            and owner == "base_graph"
            and any(index in authority_indexes for index in selected)
        )
        audit = {**audit_payload, "audit_hash": _sha(audit_payload)}
        return CompetitivePolicyV2Decision(True, "", list(selected), audit)


__all__ = [
    "CompetitivePolicyV2",
    "CompetitivePolicyV2CompileOutcome",
    "CompetitivePolicyV2Compiler",
    "CompetitivePolicyV2Decision",
    "CompetitivePolicyV2Runtime",
    "TurnTransactionJournal",
    "FRAME_PROFILE_ID",
    "PROFILE_ID",
]
