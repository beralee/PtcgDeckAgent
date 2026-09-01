from __future__ import annotations

import argparse
import copy
import hashlib
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.competitive_policy_v2 import (
    FRAME_PROFILE_ID,
    PROFILE_ID,
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


BUNDLE_ID = "ptcgdap-competitive-policy-v2-as2-wp1"
PARENT_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
ARTIFACT_PATHS = {
    "schema": "contracts/ptcgdap/competitive_policy_v2.schema.json",
    "profile": "contracts/ptcgdap/competitive_policy_v2_profile.json",
    "vectors": "contracts/ptcgdap/competitive_policy_v2_conformance_vectors.json",
    "bundle": "contracts/ptcgdap/competitive_policy_v2_bundle.json",
}


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _object(properties: dict[str, Any], required: list[str]) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required,
        "properties": properties,
    }


def build_schema() -> dict[str, Any]:
    safe_unsigned = {"type": "integer", "minimum": 0, "maximum": 9007199254740991}
    safe_signed = {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991,
    }
    nullable_unsigned = {"oneOf": [safe_unsigned, {"type": "null"}]}
    nullable_bool = {"oneOf": [{"type": "boolean"}, {"type": "null"}]}
    nullable_uid = {
        "oneOf": [
            {"type": "string", "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$", "maxLength": 64},
            {"type": "null"},
        ]
    }
    uid = {"type": "string", "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$", "maxLength": 64}
    identifier = {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,127}$"}
    upper_sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    stage = {"enum": ["acquire", "deploy", "fund", "ready", "execute", "maintain", "recover"]}
    scalar = {
        "oneOf": [
            {"type": "string", "maxLength": 128},
            safe_signed,
            {"type": "boolean"},
            {"type": "null"},
        ]
    }
    condition = _object(
        {
            "fact": {"type": "string", "minLength": 1, "maxLength": 96},
            "op": {"enum": ["eq", "ne", "lt", "lte", "gt", "gte", "contains", "not_contains"]},
            "value": scalar,
            "card_uid": nullable_uid,
        },
        ["fact", "op", "value", "card_uid"],
    )
    energy_requirement = _object(
        {
            "energy_uid": uid,
            "count": {"type": "integer", "minimum": 1, "maximum": 16},
        },
        ["energy_uid", "count"],
    )
    requirement = _object(
        {
            "card_uid": uid,
            "ready_target_count": {"type": "integer", "minimum": 1, "maximum": 6},
            "energy_required": {"type": "integer", "minimum": 0, "maximum": 16},
            "energy_requirements": {
                "type": "array",
                "maxItems": 16,
                "items": energy_requirement,
            },
            "attack_index": {
                "oneOf": [
                    {"type": "integer", "minimum": 0, "maximum": 15},
                    {"type": "null"},
                ]
            },
            "ability_index": {
                "oneOf": [
                    {"type": "integer", "minimum": 0, "maximum": 15},
                    {"type": "null"},
                ]
            },
        },
        ["card_uid", "ready_target_count", "energy_required"],
    )
    goal = _object(
        {
            "goal_id": identifier,
            "stage": stage,
            "priority": safe_unsigned,
            "requirements": {"type": "array", "minItems": 1, "maxItems": 32, "items": requirement},
        },
        ["goal_id", "stage", "priority", "requirements"],
    )
    count_rule = _object(
        {
            "rule_id": identifier,
            "priority": safe_unsigned,
            "goal_id": identifier,
            "mode": {
                "enum": [
                    "fixed",
                    "goal_energy_debt",
                    "goal_missing_energy_sources",
                    "distinct_card_uids",
                    "ceil_public_fact_divisor",
                    "ceil_public_fact_divisor_with_reserve",
                ]
            },
            "fixed_count": {
                "oneOf": [
                    {"type": "integer", "minimum": 0, "maximum": 1024},
                    {"type": "null"},
                ]
            },
            "fact": {
                "oneOf": [
                    {"type": "string", "minLength": 1, "maxLength": 96},
                    {"type": "null"},
                ]
            },
            "divisor": {
                "oneOf": [
                    {"type": "integer", "minimum": 1, "maximum": 1000000},
                    {"type": "null"},
                ]
            },
            "when": {"type": "array", "maxItems": 32, "items": condition},
        },
        ["rule_id", "priority", "goal_id", "mode", "fixed_count", "fact", "divisor", "when"],
    )
    score_term = _object(
        {
            "fact": {"type": "string", "minLength": 1, "maxLength": 96},
            "coefficient": {"type": "integer", "minimum": -10000, "maximum": 10000},
            "minimum": safe_signed,
            "maximum": safe_signed,
        },
        ["fact", "coefficient", "minimum", "maximum"],
    )
    rule = _object(
        {
            "rule_id": identifier,
            "goal_id": identifier,
            "goal_stage": stage,
            "channel": {"enum": ["macro", "tactical", "interaction", "future", "uncertainty"]},
            "horizon": {"type": "integer", "minimum": 0, "maximum": 2},
            "confidence_milli": {"type": "integer", "minimum": 0, "maximum": 1000},
            "base_score": {"type": "integer", "minimum": -1000000, "maximum": 1000000},
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "score_terms": {"type": "array", "maxItems": 16, "items": score_term},
        },
        [
            "rule_id",
            "goal_id",
            "goal_stage",
            "channel",
            "horizon",
            "confidence_milli",
            "base_score",
            "when",
            "score_terms",
        ],
    )
    route_step = _object(
        {
            "step_id": identifier,
            "prompt_kinds": {
                "type": "array",
                "minItems": 1,
                "maxItems": 16,
                "uniqueItems": True,
                "items": {"type": "string", "minLength": 1, "maxLength": 64},
            },
            "goal_id": identifier,
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "option_when": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": condition,
            },
            "score_bonus": {
                "type": "integer",
                "minimum": 0,
                "maximum": 1000000,
            },
            "selection_count": {
                "oneOf": [
                    {"type": "integer", "minimum": 0, "maximum": 1024},
                    {"type": "null"},
                ]
            },
            "terminal": {"type": "boolean"},
            "checkpoint": {"type": "boolean"},
        },
        [
            "step_id",
            "prompt_kinds",
            "goal_id",
            "when",
            "option_when",
            "score_bonus",
            "selection_count",
            "terminal",
            "checkpoint",
        ],
    )
    turn_route = _object(
        {
            "route_id": identifier,
            "priority": {"type": "integer", "minimum": 0, "maximum": 1000000},
            "goal_id": identifier,
            "owner_goal_id": identifier,
            "bridge_goal_id": identifier,
            "pivot_goal_id": identifier,
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "steps": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": route_step,
            },
        },
        [
            "route_id",
            "priority",
            "goal_id",
            "owner_goal_id",
            "bridge_goal_id",
            "pivot_goal_id",
            "when",
            "steps",
        ],
    )
    route_candidate_step = _object(
        {
            "step_id": identifier,
            "prompt_kinds": {
                "type": "array",
                "minItems": 1,
                "maxItems": 16,
                "uniqueItems": True,
                "items": {"type": "string", "minLength": 1, "maxLength": 64},
            },
            "goal_id": identifier,
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "option_when": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": condition,
            },
            "selection_count": {
                "oneOf": [
                    {"type": "integer", "minimum": 0, "maximum": 1024},
                    {"type": "null"},
                ]
            },
            "terminal": {"type": "boolean"},
            "checkpoint": {"type": "boolean"},
        },
        [
            "step_id",
            "prompt_kinds",
            "goal_id",
            "when",
            "option_when",
            "selection_count",
            "terminal",
            "checkpoint",
        ],
    )
    route_value_component = _object(
        {
            "base": {"type": "integer", "minimum": -1000000, "maximum": 1000000},
            "terms": {"type": "array", "maxItems": 16, "items": score_term},
        },
        ["base", "terms"],
    )
    route_candidate = _object(
        {
            "route_id": identifier,
            "goal_id": identifier,
            "owner_goal_id": identifier,
            "bridge_goal_id": identifier,
            "pivot_goal_id": identifier,
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "resource_budget": _object(
                {
                    "supporter_uses": {"type": "integer", "minimum": 0, "maximum": 1},
                    "manual_attachments": {"type": "integer", "minimum": 0, "maximum": 1},
                    "retreats": {"type": "integer", "minimum": 0, "maximum": 1},
                    "bench_slots": {"type": "integer", "minimum": 0, "maximum": 8},
                    "ability_uses": {"type": "integer", "minimum": 0, "maximum": 16},
                    "discard_cards": {"type": "integer", "minimum": 0, "maximum": 60},
                    "search_cards": {"type": "integer", "minimum": 0, "maximum": 60},
                },
                [
                    "supporter_uses",
                    "manual_attachments",
                    "retreats",
                    "bench_slots",
                    "ability_uses",
                    "discard_cards",
                    "search_cards",
                ],
            ),
            "value": _object(
                {
                    "attack_windows": route_value_component,
                    "prize_progress": route_value_component,
                    "continuity": route_value_component,
                    "resource_cost": route_value_component,
                    "response_risk": route_value_component,
                    "uncertainty": route_value_component,
                },
                [
                    "attack_windows",
                    "prize_progress",
                    "continuity",
                    "resource_cost",
                    "response_risk",
                    "uncertainty",
                ],
            ),
            "steps": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": route_candidate_step,
            },
        },
        [
            "route_id",
            "goal_id",
            "owner_goal_id",
            "bridge_goal_id",
            "pivot_goal_id",
            "when",
            "resource_budget",
            "value",
            "steps",
        ],
    )
    interaction_recipe = _object(
        {
            "recipe_id": identifier,
            "priority": {"type": "integer", "minimum": 0, "maximum": 1000000},
            "route_id": {"oneOf": [identifier, {"type": "null"}]},
            "goal_id": identifier,
            "source_uids": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "uniqueItems": True,
                "items": uid,
            },
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "steps": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": route_step,
            },
        },
        ["recipe_id", "priority", "route_id", "goal_id", "source_uids", "when", "steps"],
    )
    turn_bonus = _object(
        {
            "bonus_id": identifier,
            "prompt_kinds": {
                "type": "array",
                "minItems": 1,
                "maxItems": 16,
                "uniqueItems": True,
                "items": {"type": "string", "minLength": 1, "maxLength": 64},
            },
            "goal_id": identifier,
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "option_when": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": condition,
            },
            "score_bonus": {
                "type": "integer",
                "minimum": -1000000,
                "maximum": 1000000,
            },
        },
        ["bonus_id", "prompt_kinds", "goal_id", "when", "option_when", "score_bonus"],
    )
    turn_bonus_contract = _object(
        {
            "contract_id": identifier,
            "priority": {"type": "integer", "minimum": 0, "maximum": 1000000},
            "goal_id": identifier,
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "bonuses": {
                "type": "array",
                "minItems": 1,
                "maxItems": 64,
                "items": turn_bonus,
            },
        },
        ["contract_id", "priority", "goal_id", "when", "bonuses"],
    )
    damage_plan = _object(
        {
            "plan_id": identifier,
            "goal_id": identifier,
            "priority": safe_unsigned,
            "horizon_attack_windows": {"type": "integer", "minimum": 1, "maximum": 2},
            "capability_ids": {
                "type": "array",
                "minItems": 1,
                "maxItems": 16,
                "uniqueItems": True,
                "items": identifier,
            },
            "target_roles": {
                "type": "array",
                "minItems": 1,
                "maxItems": 2,
                "uniqueItems": True,
                "items": {"enum": ["opponent.active", "opponent.bench"]},
            },
            "objective_order": {
                "const": [
                    "attack_windows",
                    "prize_yield",
                    "remaining_debt",
                    "overkill",
                    "response_risk",
                ]
            },
        },
        [
            "plan_id",
            "goal_id",
            "priority",
            "horizon_attack_windows",
            "capability_ids",
            "target_roles",
            "objective_order",
        ],
    )
    semantic_transaction = _object(
        {
            "transaction_id": identifier,
            "goal_id": identifier,
            "priority": safe_unsigned,
            "max_own_turns": {"type": "integer", "minimum": 1, "maximum": 2},
            "target_role": {"enum": ["opponent.pokemon", "self.pokemon"]},
            "start_when": {"type": "array", "maxItems": 32, "items": condition},
            "continue_when": {"type": "array", "maxItems": 32, "items": condition},
            "success_when": {"type": "array", "maxItems": 32, "items": condition},
            "abort_when": {"type": "array", "maxItems": 32, "items": condition},
            "step_prompt_kinds": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "uniqueItems": True,
                "items": {"type": "string", "minLength": 1, "maxLength": 64},
            },
        },
        [
            "transaction_id",
            "goal_id",
            "priority",
            "max_own_turns",
            "target_role",
            "start_when",
            "continue_when",
            "success_when",
            "abort_when",
            "step_prompt_kinds",
        ],
    )
    turn_transaction_selection_group = _object(
        {
            "group_id": identifier,
            "selection_count": {
                "type": "integer",
                "minimum": 1,
                "maximum": 1024,
            },
            "option_when": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": condition,
            },
        },
        ["group_id", "selection_count", "option_when"],
    )
    turn_transaction_step = _object(
        {
            "step_id": identifier,
            "prompt_kinds": {
                "type": "array",
                "minItems": 1,
                "maxItems": 16,
                "uniqueItems": True,
                "items": {"type": "string", "minLength": 1, "maxLength": 64},
            },
            "goal_id": identifier,
            "required_when": {"type": "array", "maxItems": 32, "items": condition},
            "complete_when": {"type": "array", "maxItems": 32, "items": condition},
            "option_when": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": condition,
            },
            "selection_groups": {
                "type": "array",
                "maxItems": 16,
                "items": turn_transaction_selection_group,
            },
            "sequence_barrier": {"type": "boolean"},
            "score_bonus": {"type": "integer", "minimum": 0, "maximum": 1000000},
            "selection_count": {
                "oneOf": [
                    {"type": "integer", "minimum": 0, "maximum": 1024},
                    {"type": "null"},
                ]
            },
            "terminal": {"type": "boolean"},
            "checkpoint": {"type": "boolean"},
            "required_before_attack": {"type": "boolean"},
        },
        [
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
        ],
    )
    turn_transaction_method = _object(
        {
            "method_id": identifier,
            "priority": {"type": "integer", "minimum": 0, "maximum": 1000000},
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "steps": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": turn_transaction_step,
            },
        },
        ["method_id", "priority", "when", "steps"],
    )
    turn_transaction = _object(
        {
            "transaction_id": identifier,
            "priority": {"type": "integer", "minimum": 0, "maximum": 1000000},
            "goal_id": identifier,
            "deadline_turns": {"type": "integer", "minimum": 0, "maximum": 16},
            "when": {"type": "array", "maxItems": 32, "items": condition},
            "continue_when": {"type": "array", "maxItems": 32, "items": condition},
            "success_when": {"type": "array", "maxItems": 32, "items": condition},
            "abort_when": {"type": "array", "maxItems": 32, "items": condition},
            "methods": {
                "type": "array",
                "minItems": 1,
                "maxItems": 16,
                "items": turn_transaction_method,
            },
        },
        [
            "transaction_id",
            "priority",
            "goal_id",
            "deadline_turns",
            "when",
            "success_when",
            "abort_when",
            "methods",
        ],
    )
    adapter = _object(
        {
            "schema_version": {"const": 2},
            "adapter_id": identifier,
            "adapter_version": {"type": "integer", "minimum": 2, "maximum": 9007199254740991},
            "goals": {"type": "array", "minItems": 1, "maxItems": 64, "items": goal},
            "count_rules": {"type": "array", "maxItems": 128, "items": count_rule},
            "rules": {"type": "array", "minItems": 1, "maxItems": 512, "items": rule},
            "turn_routes": {"type": "array", "maxItems": 64, "items": turn_route},
            "route_candidates": {
                "type": "array",
                "maxItems": 32,
                "items": route_candidate,
            },
            "interaction_recipes": {
                "type": "array",
                "maxItems": 128,
                "items": interaction_recipe,
            },
            "turn_bonus_contracts": {
                "type": "array",
                "maxItems": 64,
                "items": turn_bonus_contract,
            },
            "damage_plans": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": damage_plan,
            },
            "semantic_transactions": {
                "type": "array",
                "minItems": 1,
                "maxItems": 32,
                "items": semantic_transaction,
            },
            "turn_transactions": {
                "type": "array",
                "maxItems": 64,
                "items": turn_transaction,
            },
        },
        ["schema_version", "adapter_id", "adapter_version", "goals", "count_rules", "rules"],
    )
    card = _object({"serial": safe_unsigned, "local_card_uid": uid}, ["serial", "local_card_uid"])
    slot = _object(
        {
            "serial": safe_unsigned,
            "local_card_uid": uid,
            "remaining_hp": safe_unsigned,
            "prize_value": {"type": "integer", "minimum": 1, "maximum": 3},
            "attached_energy_count": safe_unsigned,
            "attached_energy_uids": {"type": "array", "maxItems": 64, "items": uid},
            "minimum_attack_energy_count": safe_unsigned,
            "attack_ready": {"type": "boolean"},
            "energy_debt": safe_unsigned,
            "entity_serial": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
            "max_hp": safe_unsigned,
            "damage_counters": safe_unsigned,
            "appeared_this_turn": {"type": "boolean"},
            "attached_tool_uid": nullable_uid,
            "pokemon_stack_uids": {
                "type": "array",
                "minItems": 1,
                "maxItems": 3,
                "items": uid,
            },
        },
        [
            "serial",
            "local_card_uid",
            "remaining_hp",
            "prize_value",
            "attached_energy_count",
            "attached_energy_uids",
            "minimum_attack_energy_count",
            "attack_ready",
            "energy_debt",
        ],
    )
    option = _object(
        {
            "index": safe_unsigned,
            "kind": {"type": "string", "minLength": 1, "maxLength": 64},
            "card_uid": nullable_uid,
            "card_serial": nullable_unsigned,
            "source_uid": nullable_uid,
            "source_serial": nullable_unsigned,
            "source_entity_serial": nullable_unsigned,
            "target_uid": nullable_uid,
            "target_serial": nullable_unsigned,
            "target_entity_serial": nullable_unsigned,
            "target_remaining_hp": nullable_unsigned,
            "target_prize_value": nullable_unsigned,
            "target_attached_energy_count": nullable_unsigned,
            "target_attached_energy_uids": {
                "oneOf": [
                    {"type": "array", "maxItems": 64, "items": uid},
                    {"type": "null"},
                ]
            },
            "target_minimum_attack_energy_count": nullable_unsigned,
            "target_attack_ready": nullable_bool,
            "target_energy_debt": nullable_unsigned,
            "projected_damage": nullable_unsigned,
            "projected_knockout": {"type": "boolean"},
            "requires_interaction": {"type": "boolean"},
            "attack_index": nullable_unsigned,
            "option_number": nullable_unsigned,
            "ability_index": nullable_unsigned,
            "energy_type_raw": nullable_unsigned,
            "energy_count": nullable_unsigned,
            "special_condition_type": nullable_unsigned,
            "pending_assignment_count": safe_unsigned,
            "tags": {"type": "array", "maxItems": 64, "items": {"type": "string", "maxLength": 64}},
            "option_type_raw": safe_unsigned,
            "option_player_index": {"enum": [0, 1, None]},
        },
        [
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
        ],
    )
    own = _object(
        {
            "hand": {"type": "array", "maxItems": 60, "items": card},
            "active": {"type": "array", "maxItems": 1, "items": slot},
            "bench": {"type": "array", "maxItems": 8, "items": slot},
            "bench_capacity": {"type": "integer", "minimum": 0, "maximum": 8},
            "discard": {"type": "array", "maxItems": 60, "items": card},
            "deck_count": safe_unsigned,
            "prizes_remaining": safe_unsigned,
            "turn": _object(
                {
                    "supporter_available": {"type": "boolean"},
                    "manual_attachment_available": {"type": "boolean"},
                    "retreat_available": {"type": "boolean"},
                },
                [
                    "supporter_available",
                    "manual_attachment_available",
                    "retreat_available",
                ],
            ),
        },
        ["hand", "active", "bench", "discard", "deck_count", "prizes_remaining"],
    )
    opponent = _object(
        {
            "hand_count": safe_unsigned,
            "active": {"type": "array", "maxItems": 1, "items": slot},
            "bench": {"type": "array", "maxItems": 8, "items": slot},
            "discard": {"type": "array", "maxItems": 60, "items": card},
            "deck_count": safe_unsigned,
            "prizes_remaining": safe_unsigned,
        },
        ["hand_count", "active", "bench", "discard", "deck_count", "prizes_remaining"],
    )
    frame = _object(
        {
            "schema_version": {"const": 2},
            "profile_id": {"const": FRAME_PROFILE_ID},
            "sequence": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
            "seat": {"enum": [0, 1]},
            "prompt_kind": {"type": "string", "minLength": 1, "maxLength": 64},
            "source": _object(
                {"public_observation_hash": upper_sha, "window_id": upper_sha},
                ["public_observation_hash", "window_id"],
            ),
            "public_state": _object(
                {
                    "turn_number": safe_unsigned,
                    "phase": {"type": "string", "maxLength": 64},
                    "self": own,
                    "opponent": opponent,
                },
                ["turn_number", "phase", "self", "opponent"],
            ),
            "select_semantics": _object(
                {
                    "min_count": safe_unsigned,
                    "max_count": safe_unsigned,
                    "select_type_raw": safe_unsigned,
                    "select_context_raw": safe_unsigned,
                },
                ["min_count", "max_count", "select_type_raw", "select_context_raw"],
            ),
            "options": {"type": "array", "maxItems": 1024, "items": option},
        },
        [
            "schema_version",
            "profile_id",
            "sequence",
            "seat",
            "prompt_kind",
            "source",
            "public_state",
            "select_semantics",
            "options",
        ],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/competitive_policy_v2.schema.json",
        "title": "PtcgDAP Competitive Policy IR v2",
        "oneOf": [{"$ref": "#/$defs/adapter"}, {"$ref": "#/$defs/public_frame"}],
        "$defs": {"adapter": adapter, "public_frame": frame},
    }


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 2,
        "profile_id": PROFILE_ID,
        "frame_profile_id": FRAME_PROFILE_ID,
        "parent_author_package_bundle_canonical_sha256": PARENT_PACKAGE_BUNDLE,
        "official_policy_boundary": "agent(raw_observation)->list[int]",
        "selection_semantics": {
            "exact_count": "returned_current_window_index_list_length",
            "assignment": "one_fresh_current_window_per_source_to_target_binding",
            "accepted_output": "unique_indexes_within_current_select.option_only",
            "neutral_main_fallback": "end_turn_precedes_equal_score_unmatched_actions_even_when_another_option_matches_a_negative_rule",
            "typed_source_count": "exact_missing_energy_identity_quota_capped_by_current_window_options",
        },
        "public_frame_additions": [
            "goal_state",
            "resource_debt",
            "target_energy_and_attack_readiness",
            "prize_clock",
            "pending_assignment_progress",
            "typed_attached_energy_identity",
            "typed_goal_energy_requirements",
            "goal_relative_declared_attack_and_ability_routes",
            "goal_relative_current_option_progress",
            "goal_relative_current_window_max_progress",
            "goal_relative_current_window_setup_progress",
            "typed_missing_energy_source_quota",
            "current_window_option_uid_counts",
            "public_active_hp_for_variable_count",
            "variable_damage_lethal_or_excess_after_public_reserve",
            "official_select_type_and_context_symbolic_aliases",
            "public_turn_resource_ledger",
            "current_window_turn_route_first_executable_debt",
            "source_bound_typed_interaction_recipe",
            "owner_bridge_and_pivot_semantic_goal_identity",
            "current_window_soft_turn_intent_bonus",
            "goal_relative_active_bench_and_near_ready_counts",
            "goal_declared_energy_totals_across_public_zones",
            "current_option_source_and_target_active_position",
            "public_bench_capacity_and_remaining_space",
            "bounded_whole_turn_route_candidates",
            "typed_route_resource_budget",
            "lexicographic_route_value_and_opponent_response_risk",
            "base_owned_route_candidate_adjudication_audit",
            "stable_public_pokemon_entity_serial",
            "public_damage_capability_registry_v1",
            "current_and_next_own_attack_window_damage_plan",
            "semantic_transaction_current_window_rebinding",
            "htn_turn_transaction_goal_method_step_decomposition",
            "semantic_journal_without_stale_option_authority",
            "separate_transaction_start_and_continuation_predicates",
            "base_adjudicated_transaction_sequence_barrier",
            "exact_safe_debt_attack_commit_guard",
            "current_window_semantic_multi_select_group_quotas",
            "tm_evolution_effect_accepts_same_turn_bench_targets",
            "reobserved_multi_target_postcondition_proof",
            "public_active_attached_tool_identity",
        ],
        "official_select_semantics": {
            "oracle": "ptcgabc/official_data/kaggle_bundle/sample_submission/sample_submission/cg/api.py",
            "unknown_appended_enum": "retain_raw_integer_and_symbolic_alias_is_null",
        },
        "base_authority": [
            "legality",
            "terminal",
            "mandatory",
            "hard_tier",
            "veto",
            "cardinality",
            "deterministic_fallback",
        ],
        "adapter_authority": [
            "goal_proposal",
            "current_window_score",
            "declared_attack_or_ability_route_proposal",
            "current_option_route_progress_proposal",
            "exact_legal_count_proposal",
            "exact_typed_energy_source_subset_proposal",
            "current_assignment_target_proposal",
            "current_window_turn_route_proposal",
            "source_bound_interaction_recipe_proposal",
            "same_tier_soft_turn_intent_bonus_proposal",
            "goal_relative_public_continuity_debt_proposal",
            "bounded_current_window_route_candidate_proposal",
            "verified_damage_plan_same_tier_proposal",
            "semantic_transaction_current_window_step_proposal",
            "turn_transaction_current_window_rebound_step_proposal",
        ],
        "forbidden_inputs": [
            "opponent_hidden_cards",
            "deck_order",
            "face_down_prizes",
            "private_rng",
            "engine_object",
            "callback",
            "binding",
            "ticket",
            "command",
            "credential",
        ],
        "compatibility": {
            "v1_behavior_unchanged": True,
            "optional_host_capabilities": [
                "public_damage_plan_v1",
                "semantic_transaction_v1",
                "turn_transaction_v1",
            ],
            "v2_windows_local_only": True,
            "classic_gdscript_fallback_for_package": False,
        },
    }


def _sample_policy() -> dict[str, Any]:
    return {
        "schema_version": 2,
        "adapter_id": "contract.marnie.competitive-v2",
        "adapter_version": 2,
        "goals": [
            {
                "goal_id": "ready-two-attackers",
                "stage": "fund",
                "priority": 100,
                "requirements": [
                    {"card_uid": "M2_001", "ready_target_count": 1, "energy_required": 2},
                    {"card_uid": "M2_002", "ready_target_count": 1, "energy_required": 2},
                ],
            }
        ],
        "count_rules": [
            {
                "rule_id": "exact-public-debt",
                "priority": 0,
                "goal_id": "ready-two-attackers",
                "mode": "goal_energy_debt",
                "fixed_count": None,
                "fact": None,
                "divisor": None,
                "when": [{"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None}],
            }
        ],
        "rules": [
            {
                "rule_id": "dark-energy",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [{"fact": "option.card_uid", "op": "eq", "value": "SVI_003", "card_uid": None}],
                "score_terms": [],
            },
            {
                "rule_id": "assignment-debt",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 0,
                "when": [{"fact": "prompt_kind", "op": "eq", "value": "assignment_target", "card_uid": None}],
                "score_terms": [
                    {"fact": "option.target_energy_debt", "coefficient": 100, "minimum": 0, "maximum": 10}
                ],
            },
            {
                "rule_id": "send-out-avoid-final-two-prize-liability",
                "goal_id": "ready-two-attackers",
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
                "rule_id": "send-out-ready-counterattack",
                "goal_id": "ready-two-attackers",
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
                "rule_id": "send-out-one-prize-bridge",
                "goal_id": "ready-two-attackers",
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


def _turn_contract_policy() -> dict[str, Any]:
    condition = lambda fact, op, value: {
        "fact": fact,
        "op": op,
        "value": value,
        "card_uid": None,
    }
    return {
        "schema_version": 2,
        "adapter_id": "contract.turn-route-v2",
        "adapter_version": 11,
        "goals": [
            {
                "goal_id": "declared-owner",
                "stage": "execute",
                "priority": 900,
                "requirements": [
                    {
                        "card_uid": "M2_001",
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
                "rule_id": "legacy-prefers-redraw",
                "goal_id": "declared-owner",
                "goal_stage": "execute",
                "channel": "tactical",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 5000,
                "when": [
                    condition("option.kind", "eq", "attack"),
                    condition("option.attack_index", "eq", 0),
                ],
                "score_terms": [],
            }
        ],
        "turn_routes": [
            {
                "route_id": "owner-continuity",
                "priority": 900,
                "goal_id": "declared-owner",
                "owner_goal_id": "declared-owner",
                "bridge_goal_id": "declared-owner",
                "pivot_goal_id": "declared-owner",
                "when": [
                    {
                        "fact": "self.board.count_uid",
                        "op": "gte",
                        "value": 1,
                        "card_uid": "M2_001",
                    }
                ],
                "steps": [
                    {
                        "step_id": "fund-owner",
                        "prompt_kinds": ["main"],
                        "goal_id": "declared-owner",
                        "when": [
                            condition("goal.energy_debt", "gt", 0),
                            condition("turn.manual_attachment_available", "eq", True),
                        ],
                        "option_when": [
                            condition("goal.option.funds_target", "eq", True)
                        ],
                        "score_bonus": 100000,
                        "selection_count": 1,
                        "terminal": False,
                        "checkpoint": False,
                    },
                    {
                        "step_id": "declared-attack",
                        "prompt_kinds": ["main"],
                        "goal_id": "declared-owner",
                        "when": [condition("goal.energy_debt", "eq", 0)],
                        "option_when": [
                            condition("goal.option.executes_requirement", "eq", True)
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
                "goal_id": "declared-owner",
                "owner_goal_id": "declared-owner",
                "bridge_goal_id": "declared-owner",
                "pivot_goal_id": "declared-owner",
                "when": [
                    {
                        "fact": "self.board.count_uid",
                        "op": "eq",
                        "value": 0,
                        "card_uid": "M2_001",
                    }
                ],
                "steps": [
                    {
                        "step_id": "recover-owner",
                        "prompt_kinds": ["effect_target"],
                        "goal_id": "declared-owner",
                        "when": [
                            {
                                "fact": "self.discard.count_uid",
                                "op": "gte",
                                "value": 1,
                                "card_uid": "M2_001",
                            }
                        ],
                        "option_when": [
                            condition("option.card_uid", "eq", "M2_001"),
                            condition("option.source_uid", "eq", "SFA_061"),
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
                "goal_id": "declared-owner",
                "source_uids": ["SFA_061"],
                "when": [
                    {
                        "fact": "self.discard.count_uid",
                        "op": "gte",
                        "value": 1,
                        "card_uid": "M2_001",
                    }
                ],
                "steps": [
                    {
                        "step_id": "recover-owner-target",
                        "prompt_kinds": ["effect_target"],
                        "goal_id": "declared-owner",
                        "when": [],
                        "option_when": [condition("option.card_uid", "eq", "M2_001")],
                        "score_bonus": 120000,
                        "selection_count": 1,
                        "terminal": False,
                        "checkpoint": True,
                    }
                ],
            }
        ],
    }


def _slot(serial: int, uid: str, energy: int) -> dict[str, Any]:
    return {
        "serial": serial,
        "local_card_uid": uid,
        "remaining_hp": 280,
        "prize_value": 2 if uid == "M2_001" else 1,
        "attached_energy_count": energy,
        "attached_energy_uids": ["SVI_003"] * energy,
        "minimum_attack_energy_count": 2,
        "attack_ready": energy >= 2,
        "energy_debt": max(0, 2 - energy),
    }


def _option(index: int, **updates: Any) -> dict[str, Any]:
    value = {
        "index": index,
        "kind": "search",
        "card_uid": "SVI_003",
        "card_serial": 1000 + index,
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
    value["option_type_raw"] = kind_to_type.get(value["kind"], 3)
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
    options: list[dict[str, Any]],
    prompt: str,
    minimum: int,
    maximum: int,
    *,
    select_type_raw: int = 1,
    select_context_raw: int = 0,
) -> dict[str, Any]:
    return {
        "schema_version": 2,
        "profile_id": FRAME_PROFILE_ID,
        "sequence": 1,
        "seat": 0,
        "prompt_kind": prompt,
        "source": {"public_observation_hash": "A" * 64, "window_id": "B" * 64},
        "public_state": {
            "turn_number": 10,
            "phase": "MAIN",
            "self": {
                "hand": [],
                "active": [_slot(10, "M2_001", 1)],
                "bench": [_slot(11, "M2_002", 0)],
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
                "prizes_remaining": 2,
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


def build_vectors() -> dict[str, Any]:
    condition = lambda fact, op, value, card_uid=None: {
        "fact": fact,
        "op": op,
        "value": value,
        "card_uid": card_uid,
    }
    allowed = {"SVI_003", "M2_001", "M2_002"}
    policy_doc = _sample_policy()
    compiled = CompetitivePolicyV2Compiler.compile_local_uid(policy_doc, allowed_card_uids=allowed)
    if not compiled.accepted or compiled.policy is None:
        raise AssertionError(compiled.error_code)
    exact_frame = _frame([_option(index, kind="assignment_source") for index in range(5)], "assignment_source", 0, 5)
    exact = CompetitivePolicyV2Runtime.decide(compiled.policy, exact_frame)
    assignment_frame = _frame(
        [
            _option(
                0,
                kind="assignment_target",
                card_uid=None,
                target_uid="M2_001",
                target_serial=10,
                target_prize_value=2,
                target_attached_energy_count=1,
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=1,
            ),
            _option(
                1,
                kind="assignment_target",
                card_uid=None,
                target_uid="M2_002",
                target_serial=11,
                target_prize_value=1,
                target_attached_energy_count=0,
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=2,
            ),
        ],
        "assignment_target",
        1,
        1,
    )
    assignment = CompetitivePolicyV2Runtime.decide(compiled.policy, assignment_frame)
    bridge_frame = _frame(
        [
            _option(
                0,
                kind="send_out",
                card_uid=None,
                target_uid="M2_001",
                target_serial=10,
                target_prize_value=2,
                target_attached_energy_count=0,
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=2,
            ),
            _option(
                1,
                kind="send_out",
                card_uid=None,
                target_uid="M2_002",
                target_serial=11,
                target_prize_value=1,
                target_attached_energy_count=0,
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=2,
            ),
        ],
        "send_out",
        1,
        1,
    )
    bridge = CompetitivePolicyV2Runtime.decide(compiled.policy, bridge_frame)
    counterattack_frame = bridge_frame.copy()
    counterattack_frame = {**bridge_frame, "source": {"public_observation_hash": "A" * 64, "window_id": "C" * 64}}
    counterattack_frame["options"] = [dict(option) for option in bridge_frame["options"]]
    counterattack_frame["options"][0]["target_attached_energy_count"] = 2
    counterattack_frame["options"][0]["target_attack_ready"] = True
    counterattack_frame["options"][0]["target_energy_debt"] = 0
    counterattack = CompetitivePolicyV2Runtime.decide(compiled.policy, counterattack_frame)
    private_doc = _sample_policy()
    private_doc["rules"][0]["when"][0]["fact"] = "opponent.deck_order"
    rejected = CompetitivePolicyV2Compiler.compile_local_uid(private_doc, allowed_card_uids=allowed)
    burst_allowed = allowed | {"SVE_001", "SVE_002", "SVE_003"}
    burst_policy = copy.deepcopy(policy_doc)
    burst_policy["count_rules"].insert(
        0,
        {
            "rule_id": "minimum-lethal-public-hp",
            "priority": 0,
            "goal_id": "ready-two-attackers",
            "mode": "ceil_public_fact_divisor_with_reserve",
            "fixed_count": 2,
            "fact": "opponent.active.remaining_hp",
            "divisor": 70,
            "when": [
                {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                {"fact": "window.source_uid", "op": "eq", "value": "M2_001", "card_uid": None},
            ],
        },
    )
    burst_policy["rules"].extend(
        [
            {
                "rule_id": "grass-fuel",
                "goal_id": "ready-two-attackers",
                "goal_stage": "execute",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 900,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                    {"fact": "option.card_uid", "op": "eq", "value": "SVE_001", "card_uid": None},
                ],
                "score_terms": [],
            },
            {
                "rule_id": "preserve-only-fighting",
                "goal_id": "ready-two-attackers",
                "goal_stage": "execute",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -2000,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                    {"fact": "option.card_uid", "op": "eq", "value": "SVE_002", "card_uid": None},
                    {"fact": "self.active.energy_count_uid", "op": "eq", "value": 1, "card_uid": "SVE_002"},
                ],
                "score_terms": [],
            },
            {
                "rule_id": "preserve-only-lightning",
                "goal_id": "ready-two-attackers",
                "goal_stage": "execute",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -2000,
                "when": [
                    {"fact": "prompt_kind", "op": "eq", "value": "assignment_source", "card_uid": None},
                    {"fact": "option.card_uid", "op": "eq", "value": "SVE_003", "card_uid": None},
                    {"fact": "self.active.energy_count_uid", "op": "eq", "value": 1, "card_uid": "SVE_003"},
                ],
                "score_terms": [],
            },
        ]
    )
    burst_frame = _frame(
        [
            _option(0, kind="assignment_source", card_uid="SVE_002", source_uid="M2_001"),
            _option(1, kind="assignment_source", card_uid="SVE_001", source_uid="M2_001"),
            _option(2, kind="assignment_source", card_uid="SVE_003", source_uid="M2_001"),
            _option(3, kind="assignment_source", card_uid="SVE_001", source_uid="M2_001"),
        ],
        "assignment_source",
        1,
        4,
    )
    burst_frame["public_state"]["self"]["active"][0].update(
        {
            "attached_energy_count": 4,
            "attached_energy_uids": ["SVE_002", "SVE_003", "SVE_001", "SVE_001"],
            "attack_ready": True,
            "energy_debt": 0,
        }
    )
    burst_target = _slot(20, "M2_002", 0)
    burst_target["remaining_hp"] = 140
    burst_frame["public_state"]["opponent"]["active"] = [burst_target]
    burst_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        burst_policy, allowed_card_uids=burst_allowed
    )
    if not burst_compiled.accepted or burst_compiled.policy is None:
        raise AssertionError(burst_compiled.error_code)
    burst = CompetitivePolicyV2Runtime.decide(burst_compiled.policy, burst_frame)
    burst_reserve_frame = copy.deepcopy(burst_frame)
    burst_reserve_frame["source"]["window_id"] = "9" * 64
    burst_reserve_frame["public_state"]["opponent"]["active"][0]["remaining_hp"] = 350
    burst_reserve = CompetitivePolicyV2Runtime.decide(
        burst_compiled.policy, burst_reserve_frame
    )
    neutral_policy = copy.deepcopy(policy_doc)
    neutral_policy["rules"].append(
        {
            "rule_id": "base-fixture.veto-other-option",
            "goal_id": "ready-two-attackers",
            "goal_stage": "maintain",
            "channel": "future",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": -1000,
            "when": [{"fact": "option.card_uid", "op": "eq", "value": "M2_002", "card_uid": None}],
            "score_terms": [],
        }
    )
    neutral_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        neutral_policy, allowed_card_uids=allowed
    )
    if not neutral_compiled.accepted or neutral_compiled.policy is None:
        raise AssertionError(neutral_compiled.error_code)
    neutral_frame = _frame(
        [
            _option(0, kind="play_trainer", card_uid="M2_001"),
            _option(1, kind="play_trainer", card_uid="M2_002"),
            _option(2, kind="end_turn", card_uid=None),
        ],
        "main",
        1,
        1,
    )
    neutral = CompetitivePolicyV2Runtime.decide(neutral_compiled.policy, neutral_frame)
    ordering_policy = copy.deepcopy(policy_doc)
    ordering_policy["rules"].extend(
        [
            {
                "rule_id": "ordering-bridge",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "future",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None}],
                "score_terms": [],
            },
            {
                "rule_id": "ordering-defer-bridge-for-search",
                "goal_id": "ready-two-attackers",
                "goal_stage": "acquire",
                "channel": "macro",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -1900,
                "when": [
                    {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None},
                    {"fact": "window.option_count_card_uid", "op": "gte", "value": 1, "card_uid": "M2_002"},
                ],
                "score_terms": [],
            },
            {
                "rule_id": "ordering-search",
                "goal_id": "ready-two-attackers",
                "goal_stage": "acquire",
                "channel": "macro",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 200,
                "when": [{"fact": "option.card_uid", "op": "eq", "value": "M2_002", "card_uid": None}],
                "score_terms": [],
            },
        ]
    )
    ordering_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        ordering_policy, allowed_card_uids=allowed
    )
    if not ordering_compiled.accepted or ordering_compiled.policy is None:
        raise AssertionError(ordering_compiled.error_code)
    ordering_frame = _frame(
        [
            _option(0, kind="attach_energy", card_uid="SVI_003", target_uid="M2_002"),
            _option(1, kind="play_trainer", card_uid="M2_002"),
            _option(2, kind="end_turn", card_uid=None),
        ],
        "main",
        1,
        1,
    )
    ordering = CompetitivePolicyV2Runtime.decide(ordering_compiled.policy, ordering_frame)
    typed_policy = copy.deepcopy(policy_doc)
    typed_policy["goals"][0]["requirements"][0]["energy_requirements"] = [
        {"energy_uid": "SVE_002", "count": 1},
        {"energy_uid": "SVE_003", "count": 1},
    ]
    typed_policy["rules"].append(
        {
            "rule_id": "typed-ready-attack",
            "goal_id": "ready-two-attackers",
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
    typed_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        typed_policy, allowed_card_uids=burst_allowed
    )
    if not typed_compiled.accepted or typed_compiled.policy is None:
        raise AssertionError(typed_compiled.error_code)
    typed_wrong_frame = _frame(
        [
            _option(0, kind="attack", card_uid=None, source_uid="M2_001", attack_index=0, projected_damage=0),
            _option(1, kind="end_turn", card_uid=None),
        ],
        "main",
        1,
        1,
    )
    typed_wrong_frame["public_state"]["self"]["active"][0].update(
        {
            "attached_energy_count": 2,
            "attached_energy_uids": ["SVE_002", "SVE_002"],
            "attack_ready": True,
            "energy_debt": 0,
        }
    )
    typed_wrong = CompetitivePolicyV2Runtime.decide(typed_compiled.policy, typed_wrong_frame)
    typed_correct_frame = copy.deepcopy(typed_wrong_frame)
    typed_correct_frame["source"]["window_id"] = "E" * 64
    typed_correct_frame["public_state"]["self"]["active"][0]["attached_energy_uids"] = [
        "SVE_002",
        "SVE_003",
    ]
    typed_correct = CompetitivePolicyV2Runtime.decide(typed_compiled.policy, typed_correct_frame)
    context_policy = copy.deepcopy(policy_doc)
    context_policy["count_rules"].insert(
        0,
        {
            "rule_id": "official-context-choose-one",
            "priority": 0,
            "goal_id": "ready-two-attackers",
            "mode": "fixed",
            "fixed_count": 1,
            "fact": None,
            "divisor": None,
            "when": [
                {"fact": "select.type", "op": "eq", "value": "energy", "card_uid": None},
            ],
        },
    )
    context_policy["rules"].extend(
        [
            {
                "rule_id": "official-context-grass-to-hand",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 20000,
                "when": [
                    {"fact": "select.context", "op": "eq", "value": "to_hand_energy", "card_uid": None},
                    {"fact": "option.card_uid", "op": "eq", "value": "SVE_001", "card_uid": None},
                ],
                "score_terms": [],
            },
            {
                "rule_id": "official-context-fighting-to-field",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 20000,
                "when": [
                    {"fact": "select.context", "op": "eq", "value": "attach_to", "card_uid": None},
                    {"fact": "option.card_uid", "op": "eq", "value": "SVE_002", "card_uid": None},
                ],
                "score_terms": [],
            },
        ]
    )
    context_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        context_policy, allowed_card_uids=burst_allowed
    )
    if not context_compiled.accepted or context_compiled.policy is None:
        raise AssertionError(context_compiled.error_code)
    context_options = [
        _option(0, kind="search", card_uid="SVE_002", source_uid="M2_001"),
        _option(1, kind="search", card_uid="SVE_001", source_uid="M2_001"),
    ]
    context_hand_frame = _frame(
        context_options,
        "search",
        0,
        1,
        select_type_raw=4,
        select_context_raw=31,
    )
    context_hand = CompetitivePolicyV2Runtime.decide(context_compiled.policy, context_hand_frame)
    context_attach_frame = copy.deepcopy(context_hand_frame)
    context_attach_frame["source"]["window_id"] = "F" * 64
    context_attach_frame["prompt_kind"] = "assignment_source"
    context_attach_frame["select_semantics"]["select_context_raw"] = 22
    context_attach = CompetitivePolicyV2Runtime.decide(context_compiled.policy, context_attach_frame)
    not_contains_policy = copy.deepcopy(policy_doc)
    not_contains_policy["rules"].append(
        {
            "rule_id": "typed-attachment-only-when-missing",
            "goal_id": "ready-two-attackers",
            "goal_stage": "fund",
            "channel": "interaction",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 20000,
            "when": [
                {"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": None},
                {"fact": "option.card_uid", "op": "eq", "value": "SVE_002", "card_uid": None},
                {
                    "fact": "option.target_attached_energy_uids",
                    "op": "not_contains",
                    "value": "SVE_002",
                    "card_uid": None,
                },
            ],
            "score_terms": [],
        }
    )
    not_contains_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        not_contains_policy, allowed_card_uids=burst_allowed
    )
    if not not_contains_compiled.accepted or not_contains_compiled.policy is None:
        raise AssertionError(not_contains_compiled.error_code)
    not_contains_frame = _frame(
        [
            _option(
                0,
                kind="attach_energy",
                card_uid="SVE_002",
                target_uid="M2_001",
                target_attached_energy_count=1,
                target_attached_energy_uids=["SVE_002"],
            ),
            _option(
                1,
                kind="attach_energy",
                card_uid="SVE_002",
                target_uid="M2_002",
                target_attached_energy_count=0,
                target_attached_energy_uids=[],
            ),
        ],
        "main",
        1,
        1,
    )
    not_contains = CompetitivePolicyV2Runtime.decide(
        not_contains_compiled.policy, not_contains_frame
    )
    route_policy = copy.deepcopy(policy_doc)
    route_policy["adapter_id"] = "contract.declared-attack-route-v3"
    route_policy["adapter_version"] = 3
    route_policy["goals"] = [
        {
            "goal_id": "declared-main-attack",
            "stage": "execute",
            "priority": 900,
            "requirements": [
                {
                    "card_uid": "M2_001",
                    "ready_target_count": 1,
                    "energy_required": 2,
                    "energy_requirements": [
                        {"energy_uid": "SVE_002", "count": 1},
                        {"energy_uid": "SVE_003", "count": 1},
                    ],
                    "attack_index": 1,
                    "ability_index": None,
                }
            ],
        }
    ]
    route_policy["count_rules"] = []
    route_policy["rules"] = [
        {
            "rule_id": "route-fund",
            "goal_id": "declared-main-attack",
            "goal_stage": "fund",
            "channel": "macro",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 3000,
            "when": [
                {
                    "fact": "goal.window.max_progress",
                    "op": "gte",
                    "value": 1,
                    "card_uid": None,
                },
                {
                    "fact": "goal.option.is_max_progress",
                    "op": "eq",
                    "value": True,
                    "card_uid": None,
                },
                {
                    "fact": "goal.window.max_setup_progress",
                    "op": "gte",
                    "value": 1,
                    "card_uid": None,
                },
                {
                    "fact": "goal.option.is_max_setup_progress",
                    "op": "eq",
                    "value": True,
                    "card_uid": None,
                },
            ],
            "score_terms": [],
        },
        {
            "rule_id": "route-pivot",
            "goal_id": "declared-main-attack",
            "goal_stage": "ready",
            "channel": "macro",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 4000,
            "when": [
                {
                    "fact": "goal.option.pivots_ready_target",
                    "op": "eq",
                    "value": True,
                    "card_uid": None,
                }
            ],
            "score_terms": [],
        },
        {
            "rule_id": "route-execute",
            "goal_id": "declared-main-attack",
            "goal_stage": "execute",
            "channel": "tactical",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 5000,
            "when": [
                {
                    "fact": "goal.option.executes_requirement",
                    "op": "eq",
                    "value": True,
                    "card_uid": None,
                }
            ],
            "score_terms": [],
        },
    ]
    route_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        route_policy, allowed_card_uids=burst_allowed
    )
    if not route_compiled.accepted or route_compiled.policy is None:
        raise AssertionError(route_compiled.error_code)
    route_fund_frame = _frame(
        [
            _option(0, kind="attach_energy", card_uid="SVE_003", target_uid="M2_002", target_serial=20),
            _option(1, kind="attach_energy", card_uid="SVE_003", target_uid="M2_001", target_serial=21),
            _option(2, kind="end_turn", card_uid=None),
        ],
        "main",
        1,
        1,
    )
    support_slot = _slot(20, "M2_002", 1)
    support_slot["attached_energy_uids"] = ["SVE_002"]
    route_bolt_slot = _slot(21, "M2_001", 1)
    route_bolt_slot.update(
        {
            "attached_energy_uids": ["SVE_002"],
            "minimum_attack_energy_count": 1,
            "attack_ready": True,
            "energy_debt": 0,
        }
    )
    route_fund_frame["public_state"]["self"]["active"] = [support_slot]
    route_fund_frame["public_state"]["self"]["bench"] = [route_bolt_slot]
    route_fund = CompetitivePolicyV2Runtime.decide(route_compiled.policy, route_fund_frame)
    route_fund_reordered_frame = copy.deepcopy(route_fund_frame)
    route_fund_reordered_frame["source"]["window_id"] = "0" * 64
    route_fund_reordered_frame["options"] = [
        _option(0, kind="end_turn", card_uid=None),
        _option(1, kind="attach_energy", card_uid="SVE_003", target_uid="M2_001", target_serial=21),
        _option(2, kind="attach_energy", card_uid="SVE_003", target_uid="M2_002", target_serial=20),
    ]
    route_fund_reordered = CompetitivePolicyV2Runtime.decide(
        route_compiled.policy, route_fund_reordered_frame
    )
    route_not_ready_frame = copy.deepcopy(route_fund_frame)
    route_not_ready_frame["source"]["window_id"] = "1" * 64
    route_not_ready_frame["prompt_kind"] = "send_out"
    route_not_ready_frame["options"] = [
        _option(0, kind="send_out", card_uid=None, target_uid="M2_002", target_serial=20),
        _option(1, kind="send_out", card_uid=None, target_uid="M2_001", target_serial=21),
        _option(2, kind="end_turn", card_uid=None),
    ]
    route_not_ready = CompetitivePolicyV2Runtime.decide(
        route_compiled.policy, route_not_ready_frame
    )
    route_ready_frame = copy.deepcopy(route_not_ready_frame)
    route_ready_frame["source"]["window_id"] = "2" * 64
    route_ready_frame["public_state"]["self"]["bench"][0].update(
        {
            "attached_energy_count": 2,
            "attached_energy_uids": ["SVE_002", "SVE_003"],
        }
    )
    route_ready = CompetitivePolicyV2Runtime.decide(route_compiled.policy, route_ready_frame)
    route_attack_frame = copy.deepcopy(route_ready_frame)
    route_attack_frame["source"]["window_id"] = "3" * 64
    route_attack_frame["prompt_kind"] = "main"
    route_attack_frame["public_state"]["self"]["active"] = [
        route_attack_frame["public_state"]["self"]["bench"][0]
    ]
    route_attack_frame["public_state"]["self"]["bench"] = [support_slot]
    route_attack_frame["options"] = [
        _option(0, kind="attack", card_uid=None, source_uid="M2_001", source_serial=21, attack_index=0, projected_damage=0),
        _option(1, kind="attack", card_uid=None, source_uid="M2_001", source_serial=21, attack_index=1, projected_damage=0),
        _option(2, kind="end_turn", card_uid=None),
    ]
    route_attack = CompetitivePolicyV2Runtime.decide(route_compiled.policy, route_attack_frame)
    source_policy = copy.deepcopy(route_policy)
    source_policy["adapter_id"] = "contract.typed-source-quota-v4"
    source_policy["adapter_version"] = 4
    source_policy["count_rules"] = [
        {
            "rule_id": "typed-source-count",
            "priority": 0,
            "goal_id": "declared-main-attack",
            "mode": "goal_missing_energy_sources",
            "fixed_count": None,
            "fact": None,
            "divisor": None,
            "when": [
                {
                    "fact": "prompt_kind",
                    "op": "eq",
                    "value": "assignment_source",
                    "card_uid": None,
                }
            ],
        }
    ]
    source_policy["rules"] = [
        {
            "rule_id": "typed-source-progress",
            "goal_id": "declared-main-attack",
            "goal_stage": "fund",
            "channel": "interaction",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 1000,
            "when": [
                {
                    "fact": "goal.option.supplies_missing_energy",
                    "op": "eq",
                    "value": True,
                    "card_uid": None,
                }
            ],
            "score_terms": [],
        }
    ]
    source_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        source_policy, allowed_card_uids=burst_allowed
    )
    if not source_compiled.accepted or source_compiled.policy is None:
        raise AssertionError(source_compiled.error_code)
    source_frame = _frame(
        [
            _option(0, kind="effect_target", card_uid="SVE_002"),
            _option(1, kind="effect_target", card_uid="SVE_002"),
            _option(2, kind="effect_target", card_uid="SVE_003"),
            _option(3, kind="effect_target", card_uid="SVE_001"),
        ],
        "assignment_source",
        0,
        2,
    )
    source_slot = _slot(21, "M2_001", 1)
    source_slot.update(
        {
            "attached_energy_uids": ["SVE_001"],
            "minimum_attack_energy_count": 1,
            "attack_ready": True,
            "energy_debt": 0,
        }
    )
    source_frame["public_state"]["self"]["active"] = [source_slot]
    source_frame["public_state"]["self"]["bench"] = []
    typed_source = CompetitivePolicyV2Runtime.decide(source_compiled.policy, source_frame)
    source_reordered_frame = copy.deepcopy(source_frame)
    source_reordered_frame["source"]["window_id"] = "4" * 64
    source_reordered_frame["options"] = [
        _option(0, kind="effect_target", card_uid="SVE_003"),
        _option(1, kind="effect_target", card_uid="SVE_001"),
        _option(2, kind="effect_target", card_uid="SVE_002"),
        _option(3, kind="effect_target", card_uid="SVE_002"),
    ]
    typed_source_reordered = CompetitivePolicyV2Runtime.decide(
        source_compiled.policy, source_reordered_frame
    )
    source_unavailable_frame = copy.deepcopy(source_frame)
    source_unavailable_frame["source"]["window_id"] = "5" * 64
    source_unavailable_frame["options"] = [
        _option(0, kind="effect_target", card_uid="SVE_001")
    ]
    typed_source_unavailable = CompetitivePolicyV2Runtime.decide(
        source_compiled.policy, source_unavailable_frame
    )
    turn_allowed = {"SVI_003", "M2_001", "SFA_061"}
    turn_policy = _turn_contract_policy()
    turn_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        turn_policy, allowed_card_uids=turn_allowed
    )
    if not turn_compiled.accepted or turn_compiled.policy is None:
        raise AssertionError(turn_compiled.error_code)
    turn_fund_frame = _frame(
        [
            _option(
                0,
                kind="attach_energy",
                card_uid="SVI_003",
                target_uid="M2_001",
                target_serial=10,
                target_attached_energy_count=1,
                target_attached_energy_uids=["SVI_003"],
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=1,
            ),
            _option(
                1,
                kind="attack",
                card_uid=None,
                source_uid="M2_001",
                source_serial=10,
                attack_index=0,
                projected_damage=0,
            ),
        ],
        "main",
        1,
        1,
    )
    turn_fund_frame["public_state"]["self"]["turn"] = {
        "supporter_available": True,
        "manual_attachment_available": True,
        "retreat_available": True,
    }
    turn_fund = CompetitivePolicyV2Runtime.decide(turn_compiled.policy, turn_fund_frame)
    turn_attack_frame = copy.deepcopy(turn_fund_frame)
    turn_attack_frame["source"]["window_id"] = "6" * 64
    turn_attack_frame["public_state"]["self"]["turn"]["manual_attachment_available"] = False
    turn_attack_frame["public_state"]["self"]["active"] = [_slot(10, "M2_001", 2)]
    turn_attack_frame["options"] = [
        _option(
            0,
            kind="attack",
            card_uid=None,
            source_uid="M2_001",
            source_serial=10,
            attack_index=0,
            projected_damage=0,
        ),
        _option(
            1,
            kind="attack",
            card_uid=None,
            source_uid="M2_001",
            source_serial=10,
            attack_index=1,
            projected_damage=210,
        ),
    ]
    turn_attack = CompetitivePolicyV2Runtime.decide(
        turn_compiled.policy, turn_attack_frame
    )
    recipe_frame = _frame(
        [
            _option(0, kind="effect_target", card_uid="SVI_003", source_uid="SFA_061"),
            _option(1, kind="effect_target", card_uid="M2_001", source_uid="SFA_061"),
        ],
        "effect_target",
        1,
        1,
    )
    recipe_frame["public_state"]["self"]["active"] = []
    recipe_frame["public_state"]["self"]["bench"] = []
    recipe_frame["public_state"]["self"]["discard"] = [
        {"serial": 20, "local_card_uid": "M2_001"}
    ]
    recipe_bound = CompetitivePolicyV2Runtime.decide(turn_compiled.policy, recipe_frame)
    recipe_wrong_source_frame = copy.deepcopy(recipe_frame)
    recipe_wrong_source_frame["source"]["window_id"] = "7" * 64
    for option in recipe_wrong_source_frame["options"]:
        option["source_uid"] = "SVI_003"
    recipe_wrong_source = CompetitivePolicyV2Runtime.decide(
        turn_compiled.policy, recipe_wrong_source_frame
    )
    unknown_recipe_policy = copy.deepcopy(turn_policy)
    unknown_recipe_policy["interaction_recipes"][0]["source_uids"] = ["SFA_999"]
    unknown_recipe = CompetitivePolicyV2Compiler.compile_local_uid(
        unknown_recipe_policy, allowed_card_uids=turn_allowed
    )
    soft_policy = copy.deepcopy(policy_doc)
    soft_policy["adapter_version"] = 17
    soft_policy["rules"].extend(
        [
            {
                "rule_id": "soft-baseline-bridge",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "future",
                "horizon": 1,
                "confidence_milli": 1000,
                "base_score": 2000,
                "when": [
                    {
                        "fact": "option.card_uid",
                        "op": "eq",
                        "value": "M2_002",
                        "card_uid": None,
                    }
                ],
                "score_terms": [],
            },
            {
                "rule_id": "soft-baseline-owner",
                "goal_id": "ready-two-attackers",
                "goal_stage": "fund",
                "channel": "future",
                "horizon": 1,
                "confidence_milli": 1000,
                "base_score": 1000,
                "when": [
                    {
                        "fact": "option.card_uid",
                        "op": "eq",
                        "value": "M2_001",
                        "card_uid": None,
                    }
                ],
                "score_terms": [],
            },
        ]
    )
    soft_policy["turn_bonus_contracts"] = [
        {
            "contract_id": "soft-continuity",
            "priority": 900,
            "goal_id": "ready-two-attackers",
            "when": [
                {
                    "fact": "self.prizes_remaining",
                    "op": "gte",
                    "value": 3,
                    "card_uid": None,
                }
            ],
            "bonuses": [
                {
                    "bonus_id": "build-owner",
                    "prompt_kinds": ["main"],
                    "goal_id": "ready-two-attackers",
                    "when": [],
                    "option_when": [
                        {
                            "fact": "option.card_uid",
                            "op": "eq",
                            "value": "M2_001",
                            "card_uid": None,
                        }
                    ],
                    "score_bonus": 1500,
                },
                {
                    "bonus_id": "defer-bridge",
                    "prompt_kinds": ["main"],
                    "goal_id": "ready-two-attackers",
                    "when": [],
                    "option_when": [
                        {
                            "fact": "option.card_uid",
                            "op": "eq",
                            "value": "M2_002",
                            "card_uid": None,
                        }
                    ],
                    "score_bonus": -1000,
                },
            ],
        }
    ]
    soft_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        soft_policy, allowed_card_uids=allowed
    )
    if not soft_compiled.accepted or soft_compiled.policy is None:
        raise AssertionError(soft_compiled.error_code)
    soft_frame = _frame(
        [
            _option(0, kind="play_card", card_uid="M2_002"),
            _option(1, kind="play_card", card_uid="M2_001"),
        ],
        "main",
        1,
        1,
    )
    soft_decision = CompetitivePolicyV2Runtime.decide(
        soft_compiled.policy, soft_frame
    )
    continuity_policy = copy.deepcopy(policy_doc)
    continuity_policy["adapter_version"] = 19
    for requirement in continuity_policy["goals"][0]["requirements"]:
        requirement["energy_requirements"] = [
            {"energy_uid": "SVI_003", "count": 2}
        ]
    continuity_policy["count_rules"] = []
    continuity_policy["rules"] = [
        {
            "rule_id": "continuity-attack-baseline",
            "goal_id": "ready-two-attackers",
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
            "rule_id": "continuity-attach-baseline",
            "goal_id": "ready-two-attackers",
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
    ]
    continuity_policy["turn_bonus_contracts"] = [
        {
            "contract_id": "public-continuity-debt",
            "priority": 900,
            "goal_id": "ready-two-attackers",
            "when": [
                {"fact": "goal.active_ready_count_uid", "op": "gte", "value": 1, "card_uid": "M2_001"},
                {"fact": "goal.board_energy_count", "op": "lt", "value": 5, "card_uid": None},
                {"fact": "goal.discard_energy_count", "op": "gte", "value": 2, "card_uid": None},
                {"fact": "self.bench_open", "op": "eq", "value": True, "card_uid": None},
            ],
            "bonuses": [
                {
                    "bonus_id": "fund-non-active-backup",
                    "prompt_kinds": ["main"],
                    "goal_id": "ready-two-attackers",
                    "when": [
                        {"fact": "goal.near_ready_count_uid", "op": "gte", "value": 1, "card_uid": "M2_002"},
                        {"fact": "goal.ready_count_uid", "op": "eq", "value": 0, "card_uid": "M2_002"},
                    ],
                    "option_when": [
                        {"fact": "option.target_is_active", "op": "eq", "value": False, "card_uid": None},
                        {"fact": "goal.option.funds_target", "op": "eq", "value": True, "card_uid": None},
                    ],
                    "score_bonus": 500,
                }
            ],
        }
    ]
    continuity_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        continuity_policy, allowed_card_uids=allowed
    )
    if not continuity_compiled.accepted or continuity_compiled.policy is None:
        raise AssertionError(continuity_compiled.error_code)
    continuity_frame = _frame(
        [
            _option(
                0,
                kind="attack",
                card_uid=None,
                source_uid="M2_001",
                source_serial=10,
                projected_damage=140,
            ),
            _option(
                1,
                kind="attach_energy",
                card_uid="SVI_003",
                target_uid="M2_002",
                target_serial=11,
                target_attached_energy_count=1,
                target_attached_energy_uids=["SVI_003"],
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=1,
            ),
        ],
        "main",
        1,
        1,
    )
    continuity_frame["public_state"]["self"]["active"] = [_slot(10, "M2_001", 2)]
    continuity_frame["public_state"]["self"]["bench"] = [
        _slot(11, "M2_002", 1),
        _slot(12, "M2_002", 0),
        _slot(13, "M2_002", 0),
        _slot(14, "M2_002", 0),
        _slot(15, "M2_002", 0),
    ]
    continuity_frame["public_state"]["self"]["bench_capacity"] = 8
    continuity_frame["public_state"]["self"]["discard"] = [
        {"serial": 20, "local_card_uid": "SVI_003"},
        {"serial": 21, "local_card_uid": "SVI_003"},
    ]
    continuity_decision = CompetitivePolicyV2Runtime.decide(
        continuity_compiled.policy, continuity_frame
    )
    route_candidate_policy = copy.deepcopy(policy_doc)
    route_candidate_policy["adapter_version"] = 25
    route_candidate_policy["count_rules"] = []
    route_candidate_policy["rules"] = [
        {
            "rule_id": "local-greedy-attack",
            "goal_id": "ready-two-attackers",
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

    def route_component(base: int) -> dict[str, Any]:
        return {"base": base, "terms": []}

    def route_budget(manual_attachments: int) -> dict[str, int]:
        return {
            "supporter_uses": 0,
            "manual_attachments": manual_attachments,
            "retreats": 0,
            "bench_slots": 0,
            "ability_uses": 0,
            "discard_cards": 0,
            "search_cards": 0,
        }

    def route_value(continuity: int, resource_cost: int, response_risk: int) -> dict[str, Any]:
        return {
            "attack_windows": route_component(1),
            "prize_progress": route_component(1),
            "continuity": route_component(continuity),
            "resource_cost": route_component(resource_cost),
            "response_risk": route_component(response_risk),
            "uncertainty": route_component(0),
        }

    route_candidate_policy["route_candidates"] = [
        {
            "route_id": "continuity-first",
            "goal_id": "ready-two-attackers",
            "owner_goal_id": "ready-two-attackers",
            "bridge_goal_id": "ready-two-attackers",
            "pivot_goal_id": "ready-two-attackers",
            "when": [],
            "resource_budget": route_budget(1),
            "value": route_value(5, 3, 1),
            "steps": [
                {
                    "step_id": "fund-next-attacker",
                    "prompt_kinds": ["main"],
                    "goal_id": "ready-two-attackers",
                    "when": [],
                    "option_when": [
                        {
                            "fact": "option.kind",
                            "op": "eq",
                            "value": "attach_energy",
                            "card_uid": None,
                        }
                    ],
                    "selection_count": 1,
                    "terminal": False,
                    "checkpoint": False,
                }
            ],
        },
        {
            "route_id": "attack-now",
            "goal_id": "ready-two-attackers",
            "owner_goal_id": "ready-two-attackers",
            "bridge_goal_id": "ready-two-attackers",
            "pivot_goal_id": "ready-two-attackers",
            "when": [],
            "resource_budget": route_budget(0),
            "value": route_value(1, 0, 2),
            "steps": [
                {
                    "step_id": "take-current-attack",
                    "prompt_kinds": ["main"],
                    "goal_id": "ready-two-attackers",
                    "when": [],
                    "option_when": [
                        {
                            "fact": "option.kind",
                            "op": "eq",
                            "value": "attack",
                            "card_uid": None,
                        }
                    ],
                    "selection_count": 1,
                    "terminal": True,
                    "checkpoint": False,
                }
            ],
        },
    ]
    route_candidate_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        route_candidate_policy, allowed_card_uids=allowed
    )
    if not route_candidate_compiled.accepted or route_candidate_compiled.policy is None:
        raise AssertionError(route_candidate_compiled.error_code)
    route_candidate_frame = _frame(
        [
            _option(
                0,
                kind="attack",
                card_uid=None,
                source_uid="M2_001",
                source_serial=10,
                attack_index=0,
                projected_damage=120,
            ),
            _option(
                1,
                kind="attach_energy",
                card_uid="SVI_003",
                target_uid="M2_002",
                target_serial=11,
                target_attached_energy_count=0,
                target_attached_energy_uids=[],
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=2,
            ),
        ],
        "main",
        1,
        1,
    )
    route_candidate_frame["public_state"]["self"]["turn"] = {
        "supporter_available": True,
        "manual_attachment_available": True,
        "retreat_available": True,
    }
    route_candidate_decision = CompetitivePolicyV2Runtime.decide(
        route_candidate_compiled.policy, route_candidate_frame
    )
    spent_route_candidate_frame = copy.deepcopy(route_candidate_frame)
    spent_route_candidate_frame["source"]["window_id"] = "E" * 64
    spent_route_candidate_frame["public_state"]["self"]["turn"][
        "manual_attachment_available"
    ] = False
    spent_route_candidate_decision = CompetitivePolicyV2Runtime.decide(
        route_candidate_compiled.policy, spent_route_candidate_frame
    )
    response_route_policy = copy.deepcopy(policy_doc)
    response_route_policy["adapter_version"] = 26
    response_route_policy["count_rules"] = []

    def response_route_value(response_risk: dict[str, Any]) -> dict[str, Any]:
        return {
            "attack_windows": route_component(1),
            "prize_progress": route_component(1),
            "continuity": route_component(1),
            "resource_cost": route_component(0),
            "response_risk": response_risk,
            "uncertainty": route_component(0),
        }

    response_route_policy["route_candidates"] = [
        {
            "route_id": "ready-two-prize-counter",
            "goal_id": "ready-two-attackers",
            "owner_goal_id": "ready-two-attackers",
            "bridge_goal_id": "ready-two-attackers",
            "pivot_goal_id": "ready-two-attackers",
            "when": [],
            "resource_budget": route_budget(0),
            "value": response_route_value(route_component(2)),
            "steps": [
                {
                    "step_id": "send-ready-counter",
                    "prompt_kinds": ["send_out"],
                    "goal_id": "ready-two-attackers",
                    "when": [],
                    "option_when": [
                        {
                            "fact": "option.target_uid",
                            "op": "eq",
                            "value": "M2_001",
                            "card_uid": None,
                        }
                    ],
                    "selection_count": 1,
                    "terminal": False,
                    "checkpoint": False,
                }
            ],
        },
        {
            "route_id": "one-prize-bridge",
            "goal_id": "ready-two-attackers",
            "owner_goal_id": "ready-two-attackers",
            "bridge_goal_id": "ready-two-attackers",
            "pivot_goal_id": "ready-two-attackers",
            "when": [],
            "resource_budget": route_budget(0),
            "value": response_route_value(
                {
                    "base": -2,
                    "terms": [
                        {
                            "fact": "opponent.prizes_remaining",
                            "coefficient": 1,
                            "minimum": 0,
                            "maximum": 6,
                        }
                    ],
                }
            ),
            "steps": [
                {
                    "step_id": "send-one-prize-bridge",
                    "prompt_kinds": ["send_out"],
                    "goal_id": "ready-two-attackers",
                    "when": [],
                    "option_when": [
                        {
                            "fact": "option.target_uid",
                            "op": "eq",
                            "value": "M2_002",
                            "card_uid": None,
                        }
                    ],
                    "selection_count": 1,
                    "terminal": False,
                    "checkpoint": False,
                }
            ],
        },
    ]
    response_route_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        response_route_policy, allowed_card_uids=allowed
    )
    if not response_route_compiled.accepted or response_route_compiled.policy is None:
        raise AssertionError(response_route_compiled.error_code)
    response_route_frame = _frame(
        [
            _option(
                0,
                kind="send_out",
                card_uid=None,
                target_uid="M2_001",
                target_serial=10,
                target_prize_value=2,
                target_attached_energy_count=2,
                target_attached_energy_uids=["SVI_003", "SVI_003"],
                target_minimum_attack_energy_count=2,
                target_attack_ready=True,
                target_energy_debt=0,
            ),
            _option(
                1,
                kind="send_out",
                card_uid=None,
                target_uid="M2_002",
                target_serial=11,
                target_prize_value=1,
                target_attached_energy_count=0,
                target_attached_energy_uids=[],
                target_minimum_attack_energy_count=2,
                target_attack_ready=False,
                target_energy_debt=2,
            ),
        ],
        "send_out",
        1,
        1,
    )
    response_route_frame["public_state"]["opponent"]["prizes_remaining"] = 2
    bridge_route_decision = CompetitivePolicyV2Runtime.decide(
        response_route_compiled.policy, response_route_frame
    )
    early_response_route_frame = copy.deepcopy(response_route_frame)
    early_response_route_frame["source"]["window_id"] = "F" * 64
    early_response_route_frame["public_state"]["opponent"]["prizes_remaining"] = 6
    counter_route_decision = CompetitivePolicyV2Runtime.decide(
        response_route_compiled.policy, early_response_route_frame
    )
    evolution_policy = copy.deepcopy(policy_doc)
    evolution_policy["adapter_version"] = 41
    evolution_policy["count_rules"] = []
    evolution_policy["rules"] = [
        {
            "rule_id": "evolution.safe-current-window-proof",
            "goal_id": "ready-two-attackers",
            "goal_stage": "deploy",
            "channel": "interaction",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 3000,
            "when": [
                condition("option.card_uid", "eq", "M2_001"),
                condition(
                    "self.bench.evolution_eligible_count_uid",
                    "eq",
                    2,
                    "M2_001",
                ),
                condition(
                    "self.bench.energy_bearing_evolution_eligible_count_uid",
                    "eq",
                    1,
                    "M2_002",
                ),
            ],
            "score_terms": [],
        },
        {
            "rule_id": "evolution.safe-proof-fallback",
            "goal_id": "ready-two-attackers",
            "goal_stage": "maintain",
            "channel": "interaction",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 100,
            "when": [condition("option.card_uid", "eq", "M2_002")],
            "score_terms": [],
        },
    ]
    evolution_compiled = CompetitivePolicyV2Compiler.compile_local_uid(
        evolution_policy, allowed_card_uids=allowed
    )
    if not evolution_compiled.accepted or evolution_compiled.policy is None:
        raise AssertionError(evolution_compiled.error_code)
    evolution_frame = _frame(
        [
            _option(0, kind="search", card_uid="M2_001"),
            _option(1, kind="search", card_uid="M2_002"),
        ],
        "search",
        1,
        1,
    )
    established = _slot(30, "M2_001", 0)
    established["appeared_this_turn"] = False
    fresh = _slot(31, "M2_001", 0)
    fresh["appeared_this_turn"] = True
    funded_morgrem = _slot(32, "M2_002", 1)
    funded_morgrem["appeared_this_turn"] = False
    evolution_frame["public_state"]["self"]["bench"] = [
        established,
        fresh,
        funded_morgrem,
    ]
    evolution_safe = CompetitivePolicyV2Runtime.decide(
        evolution_compiled.policy, evolution_frame
    )
    evolution_changed_frame = copy.deepcopy(evolution_frame)
    evolution_changed_frame["source"]["window_id"] = "E" * 64
    evolution_changed_frame["public_state"]["self"]["bench"][2][
        "attached_energy_uids"
    ] = []
    evolution_changed_frame["public_state"]["self"]["bench"][2][
        "attached_energy_count"
    ] = 0
    evolution_changed = CompetitivePolicyV2Runtime.decide(
        evolution_compiled.policy, evolution_changed_frame
    )
    return {
        "schema_version": 2,
        "profile_id": PROFILE_ID,
        "artifact_id": "competitive_policy_v2_conformance_vectors",
        "cases": [
            {
                "case_id": "exact-three-of-five",
                "operation": "decide",
                "policy": policy_doc,
                "allowed_card_uids": sorted(allowed),
                "frame": exact_frame,
                "expected": {"accepted": exact.accepted, "error_code": exact.error_code, "selected_indexes": exact.selected_indexes},
            },
            {
                "case_id": "assignment-highest-current-debt",
                "operation": "decide",
                "policy": policy_doc,
                "allowed_card_uids": sorted(allowed),
                "frame": assignment_frame,
                "expected": {
                    "accepted": assignment.accepted,
                    "error_code": assignment.error_code,
                    "selected_indexes": assignment.selected_indexes,
                },
            },
            {
                "case_id": "prize-clock-one-prize-bridge",
                "operation": "decide",
                "policy": policy_doc,
                "allowed_card_uids": sorted(allowed),
                "frame": bridge_frame,
                "expected": {"accepted": bridge.accepted, "error_code": bridge.error_code, "selected_indexes": bridge.selected_indexes},
            },
            {
                "case_id": "prize-clock-ready-attacker-flip",
                "operation": "decide",
                "policy": policy_doc,
                "allowed_card_uids": sorted(allowed),
                "frame": counterattack_frame,
                "expected": {
                    "accepted": counterattack.accepted,
                    "error_code": counterattack.error_code,
                    "selected_indexes": counterattack.selected_indexes,
                },
            },
            {
                "case_id": "public-hp-minimum-lethal-preserves-typed-cost",
                "operation": "decide",
                "policy": burst_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": burst_frame,
                "expected": {
                    "accepted": burst.accepted,
                    "error_code": burst.error_code,
                    "selected_indexes": burst.selected_indexes,
                },
            },
            {
                "case_id": "public-hp-nonlethal-reserves-core-energy",
                "operation": "decide",
                "policy": burst_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": burst_reserve_frame,
                "expected": {
                    "accepted": burst_reserve.accepted,
                    "error_code": burst_reserve.error_code,
                    "selected_indexes": burst_reserve.selected_indexes,
                },
            },
            {
                "case_id": "neutral-main-fallback-survives-other-option-veto",
                "operation": "decide",
                "policy": neutral_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": neutral_frame,
                "expected": {
                    "accepted": neutral.accepted,
                    "error_code": neutral.error_code,
                    "selected_indexes": neutral.selected_indexes,
                },
            },
            {
                "case_id": "window-option-uid-count-orders-search-before-bridge-attach",
                "operation": "decide",
                "policy": ordering_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": ordering_frame,
                "expected": {
                    "accepted": ordering.accepted,
                    "error_code": ordering.error_code,
                    "selected_indexes": ordering.selected_indexes,
                },
            },
            {
                "case_id": "typed-goal-wrong-energy-mix-is-not-ready",
                "operation": "decide",
                "policy": typed_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": typed_wrong_frame,
                "expected": {
                    "accepted": typed_wrong.accepted,
                    "error_code": typed_wrong.error_code,
                    "selected_indexes": typed_wrong.selected_indexes,
                },
            },
            {
                "case_id": "typed-goal-correct-energy-mix-is-ready",
                "operation": "decide",
                "policy": typed_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": typed_correct_frame,
                "expected": {
                    "accepted": typed_correct.accepted,
                    "error_code": typed_correct.error_code,
                    "selected_indexes": typed_correct.selected_indexes,
                },
            },
            {
                "case_id": "official-context-energy-to-hand",
                "operation": "decide",
                "policy": context_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": context_hand_frame,
                "expected": {
                    "accepted": context_hand.accepted,
                    "error_code": context_hand.error_code,
                    "selected_indexes": context_hand.selected_indexes,
                },
            },
            {
                "case_id": "official-context-attachment-source",
                "operation": "decide",
                "policy": context_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": context_attach_frame,
                "expected": {
                    "accepted": context_attach.accepted,
                    "error_code": context_attach.error_code,
                    "selected_indexes": context_attach.selected_indexes,
                },
            },
            {
                "case_id": "typed-attachment-not-contains",
                "operation": "decide",
                "policy": not_contains_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": not_contains_frame,
                "expected": {
                    "accepted": not_contains.accepted,
                    "error_code": not_contains.error_code,
                    "selected_indexes": not_contains.selected_indexes,
                },
            },
            {
                "case_id": "goal-route-funds-declared-attacker-not-support",
                "operation": "decide",
                "policy": route_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": route_fund_frame,
                "expected": {
                    "accepted": route_fund.accepted,
                    "error_code": route_fund.error_code,
                    "selected_indexes": route_fund.selected_indexes,
                },
            },
            {
                "case_id": "goal-route-max-progress-survives-option-reorder",
                "operation": "decide",
                "policy": route_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": route_fund_reordered_frame,
                "expected": {
                    "accepted": route_fund_reordered.accepted,
                    "error_code": route_fund_reordered.error_code,
                    "selected_indexes": route_fund_reordered.selected_indexes,
                },
            },
            {
                "case_id": "goal-route-generic-ready-does-not-satisfy-declared-attack",
                "operation": "decide",
                "policy": route_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": route_not_ready_frame,
                "expected": {
                    "accepted": route_not_ready.accepted,
                    "error_code": route_not_ready.error_code,
                    "selected_indexes": route_not_ready.selected_indexes,
                },
            },
            {
                "case_id": "goal-route-exact-energy-pivots-declared-attacker",
                "operation": "decide",
                "policy": route_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": route_ready_frame,
                "expected": {
                    "accepted": route_ready.accepted,
                    "error_code": route_ready.error_code,
                    "selected_indexes": route_ready.selected_indexes,
                },
            },
            {
                "case_id": "goal-route-executes-only-declared-attack-index",
                "operation": "decide",
                "policy": route_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": route_attack_frame,
                "expected": {
                    "accepted": route_attack.accepted,
                    "error_code": route_attack.error_code,
                    "selected_indexes": route_attack.selected_indexes,
                },
            },
            {
                "case_id": "typed-source-quota-rejects-duplicate-and-wrong-energy",
                "operation": "decide",
                "policy": source_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": source_frame,
                "expected": {
                    "accepted": typed_source.accepted,
                    "error_code": typed_source.error_code,
                    "selected_indexes": typed_source.selected_indexes,
                },
            },
            {
                "case_id": "typed-source-quota-survives-option-reorder",
                "operation": "decide",
                "policy": source_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": source_reordered_frame,
                "expected": {
                    "accepted": typed_source_reordered.accepted,
                    "error_code": typed_source_reordered.error_code,
                    "selected_indexes": typed_source_reordered.selected_indexes,
                },
            },
            {
                "case_id": "typed-source-quota-selects-zero-when-only-wrong-type-exists",
                "operation": "decide",
                "policy": source_policy,
                "allowed_card_uids": sorted(burst_allowed),
                "frame": source_unavailable_frame,
                "expected": {
                    "accepted": typed_source_unavailable.accepted,
                    "error_code": typed_source_unavailable.error_code,
                    "selected_indexes": typed_source_unavailable.selected_indexes,
                },
            },
            {
                "case_id": "turn-route-pays-first-public-resource-debt",
                "operation": "decide",
                "policy": turn_policy,
                "allowed_card_uids": sorted(turn_allowed),
                "frame": turn_fund_frame,
                "expected": {
                    "accepted": turn_fund.accepted,
                    "error_code": turn_fund.error_code,
                    "selected_indexes": turn_fund.selected_indexes,
                },
            },
            {
                "case_id": "turn-route-reobserves-and-executes-declared-attack-after-funding",
                "operation": "decide",
                "policy": turn_policy,
                "allowed_card_uids": sorted(turn_allowed),
                "frame": turn_attack_frame,
                "expected": {
                    "accepted": turn_attack.accepted,
                    "error_code": turn_attack.error_code,
                    "selected_indexes": turn_attack.selected_indexes,
                },
            },
            {
                "case_id": "interaction-recipe-binds-current-uniform-source",
                "operation": "decide",
                "policy": turn_policy,
                "allowed_card_uids": sorted(turn_allowed),
                "frame": recipe_frame,
                "expected": {
                    "accepted": recipe_bound.accepted,
                    "error_code": recipe_bound.error_code,
                    "selected_indexes": recipe_bound.selected_indexes,
                },
            },
            {
                "case_id": "interaction-recipe-ignores-wrong-source",
                "operation": "decide",
                "policy": turn_policy,
                "allowed_card_uids": sorted(turn_allowed),
                "frame": recipe_wrong_source_frame,
                "expected": {
                    "accepted": recipe_wrong_source.accepted,
                    "error_code": recipe_wrong_source.error_code,
                    "selected_indexes": recipe_wrong_source.selected_indexes,
                },
            },
            {
                "case_id": "interaction-recipe-unknown-source-fails-closed",
                "operation": "compile",
                "policy": unknown_recipe_policy,
                "allowed_card_uids": sorted(turn_allowed),
                "frame": None,
                "expected": {
                    "accepted": unknown_recipe.accepted,
                    "error_code": unknown_recipe.error_code,
                    "selected_indexes": [],
                },
            },
            {
                "case_id": "soft-turn-bonus-rebinds-semantic-option",
                "operation": "decide",
                "policy": soft_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": soft_frame,
                "expected": {
                    "accepted": soft_decision.accepted,
                    "error_code": soft_decision.error_code,
                    "selected_indexes": soft_decision.selected_indexes,
                },
            },
            {
                "case_id": "goal-relative-public-continuity-debt",
                "operation": "decide",
                "policy": continuity_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": continuity_frame,
                "expected": {
                    "accepted": continuity_decision.accepted,
                    "error_code": continuity_decision.error_code,
                    "selected_indexes": continuity_decision.selected_indexes,
                },
            },
            {
                "case_id": "whole-turn-route-candidate-overrides-local-greedy-score",
                "operation": "decide",
                "policy": route_candidate_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": route_candidate_frame,
                "expected": {
                    "accepted": route_candidate_decision.accepted,
                    "error_code": route_candidate_decision.error_code,
                    "selected_indexes": route_candidate_decision.selected_indexes,
                    "audit_hash": route_candidate_decision.audit["audit_hash"],
                },
            },
            {
                "case_id": "route-resource-budget-public-fact-flip",
                "operation": "decide",
                "policy": route_candidate_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": spent_route_candidate_frame,
                "expected": {
                    "accepted": spent_route_candidate_decision.accepted,
                    "error_code": spent_route_candidate_decision.error_code,
                    "selected_indexes": spent_route_candidate_decision.selected_indexes,
                    "audit_hash": spent_route_candidate_decision.audit["audit_hash"],
                },
            },
            {
                "case_id": "route-response-risk-prefers-one-prize-bridge-at-final-clock",
                "operation": "decide",
                "policy": response_route_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": response_route_frame,
                "expected": {
                    "accepted": bridge_route_decision.accepted,
                    "error_code": bridge_route_decision.error_code,
                    "selected_indexes": bridge_route_decision.selected_indexes,
                    "audit_hash": bridge_route_decision.audit["audit_hash"],
                },
            },
            {
                "case_id": "route-response-risk-prefers-ready-counter-before-final-clock",
                "operation": "decide",
                "policy": response_route_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": early_response_route_frame,
                "expected": {
                    "accepted": counter_route_decision.accepted,
                    "error_code": counter_route_decision.error_code,
                    "selected_indexes": counter_route_decision.selected_indexes,
                    "audit_hash": counter_route_decision.audit["audit_hash"],
                },
            },
            {
                "case_id": "tm-evolution-allows-same-turn-targets-and-requires-funded-morgrem",
                "operation": "decide",
                "policy": evolution_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": evolution_frame,
                "expected": {
                    "accepted": evolution_safe.accepted,
                    "error_code": evolution_safe.error_code,
                    "selected_indexes": evolution_safe.selected_indexes,
                },
            },
            {
                "case_id": "tm-evolution-proof-reobserves-energy-change",
                "operation": "decide",
                "policy": evolution_policy,
                "allowed_card_uids": sorted(allowed),
                "frame": evolution_changed_frame,
                "expected": {
                    "accepted": evolution_changed.accepted,
                    "error_code": evolution_changed.error_code,
                    "selected_indexes": evolution_changed.selected_indexes,
                },
            },
            {
                "case_id": "private-fact-fails-closed",
                "operation": "compile",
                "policy": private_doc,
                "allowed_card_uids": sorted(allowed),
                "frame": None,
                "expected": {"accepted": rejected.accepted, "error_code": rejected.error_code, "selected_indexes": []},
            },
        ],
    }


def build_contract_documents() -> dict[str, dict[str, Any]]:
    documents = {"schema": build_schema(), "profile": build_profile(), "vectors": build_vectors()}
    documents["bundle"] = {
        "schema_version": 2,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "parent_author_package_bundle_canonical_sha256": PARENT_PACKAGE_BUNDLE,
        "artifacts": [
            {
                "id": artifact_id,
                "path": ARTIFACT_PATHS[artifact_id],
                "canonical_sha256": _sha(canonical_json_v1_bytes(document)),
            }
            for artifact_id, document in documents.items()
        ],
    }
    return documents


def write_or_check(*, check: bool) -> None:
    documents = build_contract_documents()
    for artifact_id, document in documents.items():
        path = ROOT / ARTIFACT_PATHS[artifact_id]
        expected = canonical_json_v1_bytes(document)
        if check:
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(f"contract drift: {path.relative_to(ROOT).as_posix()}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Competitive Policy IR v2 contracts")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    write_or_check(check=args.check)


if __name__ == "__main__":
    main()
