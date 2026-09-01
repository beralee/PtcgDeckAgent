"""Deterministic public-only Turn Program proposal materialization.

The host-facing Competitive Policy layer is responsible for expanding its
signed adapter into normalized semantic candidates and for obtaining the fresh
Base proof for each candidate's current step.  This module never sees or emits
an option index.  It computes a bounded public effect-summary outcome, keeps the
best Top-K candidates, and returns an ordinary Turn Program v1 request for the
non-authoritative planner.
"""

from __future__ import annotations

import copy
import re
from typing import Any

from .cabt_tree_hash import CabtTreeHashError, public_observation_hash
from .state_conditioned_transaction_value import (
    PROFILE_ID as CONDITIONED_VALUE_PROFILE_ID,
    StateConditionedTransactionValueV2,
)
from .turn_program_planner import DEFAULT_VALUE_MODEL, FEATURES
from .turn_program_transition_evaluator import TurnProgramTransitionEvaluator


PROFILE_ID = "ptcgdap-turn-program-generator-v1"
FRAME_PROFILE_ID = "ptcgdap-competitive-public-frame-v2"
REQUEST_PROFILE_ID = "ptcgdap-turn-program-request-v1"
MAX_SAFE_INTEGER = 9_007_199_254_740_991
IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
SHA256 = re.compile(r"^[0-9A-F]{64}$")

SOURCE_KINDS = frozenset(
    {"turn_transaction", "turn_route", "base_action", "base_terminal"}
)
TERMINAL_KINDS = frozenset({"none", "attack", "end_turn"})
EFFECT_KINDS = frozenset(
    {
        "ability",
        "attack",
        "bench",
        "conversion",
        "damage_transfer",
        "disruption",
        "draw",
        "end_turn",
        "energy",
        "evolution",
        "handoff",
        "search",
        "tool",
    }
)

_CANDIDATE_KEYS = {
    "program_id",
    "goal_id",
    "route_id",
    "deadline_turns",
    "priority",
    "source_kind",
    "semantic_steps",
    "current_step_id",
    "current_option_facts",
    "terminal_option_facts",
    "base_proof",
}
_STEP_KEYS = {
    "step_id",
    "transaction_id",
    "method_id",
    "depends_on",
    "terminal_kind",
    "effect_kind",
}
_OPTIONAL_STEP_KEYS = {"resource_claim"}
_RESOURCE_CLAIMS = {"none", "supporter", "manual_attachment", "retreat", "unknown"}
_OUTPUT_STEP_KEYS = (
    "step_id",
    "transaction_id",
    "method_id",
    "depends_on",
    "terminal_kind",
)
_OPTION_FACT_KEYS = {
    "kind",
    "projected_damage",
    "projected_knockout",
    "target_remaining_hp",
    "target_prize_value",
}
_OPTION_FACT_CONTEXT_KEYS = {"card_uid", "source_uid", "target_uid", "tags"}
_PROOF_KEYS = {
    "admissible",
    "current_step_executable",
    "mandatory_preserved",
    "terminal_preserved",
    "base_vetoed",
}

_EFFECT_VALUES: dict[str, dict[str, int]] = {
    "ability": {
        "board_development_milli": 100,
        "next_turn_continuity_milli": 140,
    },
    "bench": {
        "board_development_milli": 220,
        "next_turn_continuity_milli": 260,
    },
    "conversion": {
        "attack_pressure_milli": 220,
        "next_turn_continuity_milli": 120,
    },
    "damage_transfer": {
        "attack_pressure_milli": 260,
        "next_turn_continuity_milli": 180,
    },
    "disruption": {
        "hand_quality_milli": 80,
        "disruption_milli": 620,
        "next_turn_continuity_milli": 120,
    },
    "draw": {
        "hand_quality_milli": 520,
        "next_turn_continuity_milli": 100,
    },
    "energy": {
        "board_development_milli": 180,
        "attack_pressure_milli": 120,
        "next_turn_continuity_milli": 280,
    },
    "evolution": {
        "board_development_milli": 320,
        "next_turn_continuity_milli": 300,
    },
    "handoff": {
        "attack_pressure_milli": 160,
        "next_turn_continuity_milli": 160,
    },
    "search": {
        "board_development_milli": 100,
        "hand_quality_milli": 260,
        "next_turn_continuity_milli": 180,
    },
    "tool": {
        "board_development_milli": 100,
        "next_turn_continuity_milli": 140,
    },
}

_RESOURCE_COST = {
    "ability": 10,
    "attack": 0,
    "bench": 70,
    "conversion": 100,
    "damage_transfer": 10,
    "disruption": 120,
    "draw": 120,
    "end_turn": 0,
    "energy": 80,
    "evolution": 80,
    "handoff": 50,
    "search": 90,
    "tool": 90,
}


def _safe_int(value: Any, *, signed: bool = False) -> bool:
    return type(value) is int and (
        -MAX_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER
        if signed
        else 0 <= value <= MAX_SAFE_INTEGER
    )


def _identifier(value: Any) -> bool:
    return type(value) is str and IDENTIFIER.fullmatch(value) is not None


def _source(value: Any) -> bool:
    return (
        type(value) is dict
        and set(value) == {"public_observation_hash", "window_id"}
        and SHA256.fullmatch(value.get("public_observation_hash", "")) is not None
        and SHA256.fullmatch(value.get("window_id", "")) is not None
    )


def _frame_error(frame: Any) -> str | None:
    if (
        type(frame) is not dict
        or frame.get("schema_version") != 2
        or frame.get("profile_id") != FRAME_PROFILE_ID
        or not _source(frame.get("source"))
        or type(frame.get("seat")) is not int
        or frame.get("seat") not in (0, 1)
        or not _safe_int(frame.get("public_state", {}).get("turn_number"))
        or type(frame.get("options")) is not list
    ):
        return "invalid_turn_program_generation_frame"
    return None


def _option_fact_error(value: Any) -> str | None:
    if (
        type(value) is not dict
        or not _OPTION_FACT_KEYS.issubset(value)
        or not set(value).issubset(_OPTION_FACT_KEYS | _OPTION_FACT_CONTEXT_KEYS)
        or type(value.get("kind")) is not str
        or not value["kind"]
        or type(value.get("projected_knockout")) is not bool
    ):
        return "invalid_turn_program_candidate"
    for key in ("projected_damage", "target_remaining_hp", "target_prize_value"):
        item = value[key]
        if item is not None and not _safe_int(item):
            return "invalid_turn_program_candidate"
    if value["target_prize_value"] is not None and value["target_prize_value"] > 3:
        return "invalid_turn_program_candidate"
    for key in ("card_uid", "source_uid", "target_uid"):
        item = value.get(key)
        if item is not None and (type(item) is not str or not item or len(item) > 128):
            return "invalid_turn_program_candidate"
    tags = value.get("tags", [])
    if type(tags) is not list or len(tags) > 32 or any(
        type(tag) is not str or len(tag) > 64 for tag in tags
    ):
        return "invalid_turn_program_candidate"
    return None


def _step_error(value: Any, seen: set[str], offset: int, total: int) -> str | None:
    if (
        type(value) is not dict
        or not _STEP_KEYS.issubset(value)
        or not set(value).issubset(_STEP_KEYS | _OPTIONAL_STEP_KEYS)
        or not all(
            _identifier(value.get(key))
            for key in ("step_id", "transaction_id", "method_id")
        )
        or type(value.get("depends_on")) is not list
        or len(value["depends_on"]) > 16
        or len(value["depends_on"]) != len(set(value["depends_on"]))
        or any(not _identifier(item) or item not in seen for item in value["depends_on"])
        or value.get("terminal_kind") not in TERMINAL_KINDS
        or value.get("effect_kind") not in EFFECT_KINDS
        or (
            "resource_claim" in value
            and value.get("resource_claim") is not None
            and value.get("resource_claim") not in _RESOURCE_CLAIMS
        )
    ):
        return "invalid_turn_program_candidate"
    if value["step_id"] in seen:
        return "invalid_turn_program_candidate"
    if value["terminal_kind"] != "none" and offset != total - 1:
        return "invalid_turn_program_candidate"
    return None


def _candidate_error(value: Any) -> str | None:
    if (
        type(value) is not dict
        or set(value) != _CANDIDATE_KEYS
        or not all(
            _identifier(value.get(key))
            for key in ("program_id", "goal_id", "route_id", "current_step_id")
        )
        or not _safe_int(value.get("deadline_turns"))
        or value["deadline_turns"] > 8
        or not _safe_int(value.get("priority"))
        or value["source_kind"] not in SOURCE_KINDS
        or type(value.get("semantic_steps")) is not list
        or not 1 <= len(value["semantic_steps"]) <= 32
        or type(value.get("current_option_facts")) is not list
        or not 1 <= len(value["current_option_facts"]) <= 32
        or type(value.get("terminal_option_facts")) is not list
        or len(value["terminal_option_facts"]) > 32
        or type(value.get("base_proof")) is not dict
        or set(value["base_proof"]) != _PROOF_KEYS
        or any(type(value["base_proof"].get(key)) is not bool for key in _PROOF_KEYS)
    ):
        return "invalid_turn_program_candidate"
    seen: set[str] = set()
    terminal_count = 0
    steps = value["semantic_steps"]
    for offset, step in enumerate(steps):
        error = _step_error(step, seen, offset, len(steps))
        if error:
            return error
        seen.add(step["step_id"])
        terminal_count += int(step["terminal_kind"] != "none")
    if terminal_count > 1 or value["current_step_id"] != steps[0]["step_id"]:
        return "invalid_turn_program_candidate"
    for fact in [*value["current_option_facts"], *value["terminal_option_facts"]]:
        error = _option_fact_error(fact)
        if error:
            return error
    return None


def _empty_outcome() -> dict[str, int]:
    return {feature: 0 for feature in FEATURES}


def _best_terminal(facts: list[dict[str, Any]]) -> dict[str, Any] | None:
    attack_facts = [fact for fact in facts if fact["kind"] in {"attack", "granted_attack"}]
    if not attack_facts:
        return None
    return max(
        attack_facts,
        key=lambda fact: (
            int(fact["projected_knockout"]),
            fact["target_prize_value"] or 0,
            fact["projected_damage"] or 0,
            -(fact["target_remaining_hp"] or 0),
        ),
    )


def _outcome(
    candidate: dict[str, Any],
    *,
    prizes_remaining: int,
    visible_debt_count: int,
) -> dict[str, int]:
    outcome = _empty_outcome()
    steps = candidate["semantic_steps"]
    nonterminal = [step for step in steps if step["terminal_kind"] == "none"]
    for step in nonterminal:
        for feature, amount in _EFFECT_VALUES.get(step["effect_kind"], {}).items():
            outcome[feature] = min(1000, outcome[feature] + amount)

    terminal = _best_terminal(candidate["terminal_option_facts"])
    if terminal is None and steps[-1]["terminal_kind"] == "attack":
        terminal = _best_terminal(candidate["current_option_facts"])
    if terminal is not None:
        damage = terminal["projected_damage"]
        outcome["attack_pressure_milli"] = min(
            1000,
            max(outcome["attack_pressure_milli"], 300 if damage is None else damage * 4),
        )
        prize_yield = (
            terminal["target_prize_value"] or 0
            if terminal["projected_knockout"]
            else 0
        )
        outcome["prize_gain_milli"] = min(3000, prize_yield * 1000)
        # The hard terminal channel means "take the last prize in this fresh
        # window", not merely "this longer route also intends to attack later".
        # Optional development may never delay a currently proven close-out.
        current_terminal = steps[0]["terminal_kind"] == "attack"
        current_attack = _best_terminal(candidate["current_option_facts"])
        outcome["final_prize_knockout"] = int(
            current_terminal
            and current_attack is not None
            and current_attack["projected_knockout"]
            and (current_attack["target_prize_value"] or 0) > 0
            and prizes_remaining <= (current_attack["target_prize_value"] or 0)
        )

    outcome["next_turn_continuity_milli"] = min(
        1000,
        outcome["next_turn_continuity_milli"] + min(260, candidate["priority"] // 25),
    )
    resource_cost = sum(_RESOURCE_COST[step["effect_kind"]] for step in steps)
    outcome["resource_preservation_milli"] = max(0, 720 - resource_cost)
    resolved_debt = len(nonterminal)
    outcome["unresolved_debt_milli"] = min(
        1000, max(0, visible_debt_count - resolved_debt) * 250
    )
    future_steps = max(0, len(steps) - 1)
    no_terminal = steps[-1]["terminal_kind"] == "none"
    unknown_attack = steps[-1]["terminal_kind"] == "attack" and terminal is None
    outcome["risk_milli"] = min(
        1000,
        future_steps * 55 + (260 if no_terminal else 0) + (180 if unknown_attack else 0),
    )
    return outcome


def _utility(outcome: dict[str, int], value_model: dict[str, Any]) -> int:
    weights = value_model["feature_weights_milli"]
    return sum(outcome[feature] * weights[feature] for feature in weights)


def _public_action_context(candidate: dict[str, Any]) -> dict[str, list[str]]:
    facts = candidate.get("current_option_facts", [])
    first_step = candidate.get("semantic_steps", [])[0]
    return {
        "card_uids": sorted(
            {str(fact["card_uid"]) for fact in facts if fact.get("card_uid") is not None}
        ),
        "source_uids": sorted(
            {str(fact["source_uid"]) for fact in facts if fact.get("source_uid") is not None}
        ),
        "target_uids": sorted(
            {str(fact["target_uid"]) for fact in facts if fact.get("target_uid") is not None}
        ),
        "kinds": sorted({str(fact["kind"]) for fact in facts}),
        "tags": sorted({str(tag) for fact in facts for tag in fact.get("tags", [])}),
        "current_effect_kinds": [str(first_step["effect_kind"])],
        "current_resource_claims": [str(first_step.get("resource_claim") or "none")],
    }


def _value_model(value: Any) -> bool:
    if type(value) is dict and value.get("profile_id") == CONDITIONED_VALUE_PROFILE_ID:
        return StateConditionedTransactionValueV2.is_model(value)
    return bool(
        type(value) is dict
        and set(value) == {"profile_id", "model_version", "feature_weights_milli"}
        and value.get("profile_id") == "ptcgdap-turn-program-value-v1"
        and _safe_int(value.get("model_version"))
        and value["model_version"] >= 1
        and type(value.get("feature_weights_milli")) is dict
        and set(value["feature_weights_milli"])
        == set(DEFAULT_VALUE_MODEL["feature_weights_milli"])
        and all(
            _safe_int(weight, signed=True)
            for weight in value["feature_weights_milli"].values()
        )
    )


def _audit_hash(value: dict[str, Any]) -> str:
    try:
        return public_observation_hash(value)
    except (CabtTreeHashError, TypeError, ValueError, RecursionError):
        return ""


def _error(code: str) -> dict[str, Any]:
    return {
        "accepted": False,
        "error_code": code,
        "profile_id": PROFILE_ID,
        "mode": "shadow",
        "authoritative": False,
        "public_only": True,
        "candidate_count": 0,
        "emitted_count": 0,
        "request": None,
        "candidate_audit": [],
        "audit_hash": "",
    }


class TurnProgramGenerator:
    """Build a Turn Program request from normalized, fresh Base-proven candidates."""

    @staticmethod
    def generate(
        frame: Any,
        candidates: Any,
        *,
        max_programs: int = 8,
        value_model: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        error = _frame_error(frame)
        if error:
            return _error(error)
        model = copy.deepcopy(DEFAULT_VALUE_MODEL if value_model is None else value_model)
        if (
            type(candidates) is not list
            or not 1 <= len(candidates) <= 64
            or type(max_programs) is not int
            or not 1 <= max_programs <= 8
            or not _value_model(model)
        ):
            return _error("invalid_turn_program_generation_request")
        seen: set[str] = set()
        normalized: list[dict[str, Any]] = []
        for candidate in copy.deepcopy(candidates):
            error = _candidate_error(candidate)
            if error:
                return _error(error)
            if candidate["program_id"] in seen:
                return _error("duplicate_turn_program_candidate")
            seen.add(candidate["program_id"])
            normalized.append(candidate)

        visible_debt_count = max(
            sum(step["terminal_kind"] == "none" for step in candidate["semantic_steps"])
            for candidate in normalized
            if candidate["base_proof"]["admissible"]
            and candidate["base_proof"]["current_step_executable"]
            and not candidate["base_proof"]["base_vetoed"]
        ) if any(
            candidate["base_proof"]["admissible"]
            and candidate["base_proof"]["current_step_executable"]
            and not candidate["base_proof"]["base_vetoed"]
            for candidate in normalized
        ) else 0
        prizes_remaining = frame["public_state"].get("self", {}).get("prizes_remaining", 0)
        if not _safe_int(prizes_remaining) or prizes_remaining > 6:
            return _error("invalid_turn_program_generation_frame")

        materialized: list[tuple[tuple[int | str, ...], dict[str, Any], dict[str, Any], int]] = []
        audit_rows: list[dict[str, Any]] = []
        for candidate in normalized:
            transition = TurnProgramTransitionEvaluator.evaluate(
                frame,
                candidate,
                visible_debt_count=visible_debt_count,
            )
            if not transition.get("accepted"):
                return _error(
                    str(transition.get("error_code", "turn_program_transition_failed"))
                )
            outcome = _outcome(
                candidate,
                prizes_remaining=prizes_remaining,
                visible_debt_count=visible_debt_count,
            )
            proof = candidate["base_proof"]
            admitted = (
                proof["admissible"]
                and proof["current_step_executable"]
                and proof["mandatory_preserved"]
                and proof["terminal_preserved"]
                and not proof["base_vetoed"]
            )
            program = {
                "program_id": candidate["program_id"],
                "goal_id": candidate["goal_id"],
                "route_id": candidate["route_id"],
                "deadline_turns": candidate["deadline_turns"],
                "semantic_steps": [
                    {key: copy.deepcopy(step[key]) for key in _OUTPUT_STEP_KEYS}
                    for step in candidate["semantic_steps"]
                ],
                "public_outcome": outcome,
            }
            if model.get("profile_id") == CONDITIONED_VALUE_PROFILE_ID:
                program["public_action_context"] = _public_action_context(candidate)
            conditioned_value: dict[str, Any] | None = None
            if model.get("profile_id") == CONDITIONED_VALUE_PROFILE_ID:
                conditioned_value = StateConditionedTransactionValueV2.score(
                    frame, program, outcome, model
                )
                if not conditioned_value.get("accepted"):
                    return _error(
                        str(
                            conditioned_value.get(
                                "error_code", "state_conditioned_value_failed"
                            )
                        )
                    )
                utility = int(conditioned_value["total_utility"])
            else:
                utility = _utility(outcome, model)
            row = {
                "program_id": candidate["program_id"],
                "source_kind": candidate["source_kind"],
                "priority": candidate["priority"],
                "admitted": admitted,
                "emitted": False,
                "utility": utility,
                "public_outcome": copy.deepcopy(outcome),
                "transition_evaluation": copy.deepcopy(transition),
            }
            if conditioned_value is not None:
                row["conditioned_value"] = copy.deepcopy(conditioned_value)
            audit_rows.append(row)
            if not admitted:
                continue
            base_proof = {
                "program_id": candidate["program_id"],
                "current_step_id": candidate["current_step_id"],
                **copy.deepcopy(proof),
            }
            comparison: tuple[int | str, ...] = (
                -outcome["final_prize_knockout"],
                -utility,
                -candidate["priority"],
                candidate["program_id"],
            )
            materialized.append((comparison, program, base_proof, len(audit_rows) - 1))

        if not materialized:
            return _error("no_admissible_turn_program_candidates")
        materialized.sort(key=lambda item: item[0])
        emitted = materialized[:max_programs]
        for _comparison, _program, _proof, audit_index in emitted:
            audit_rows[audit_index]["emitted"] = True
        request = {
            "schema_version": 1,
            "profile_id": REQUEST_PROFILE_ID,
            "source": copy.deepcopy(frame["source"]),
            "value_model": copy.deepcopy(model),
            "programs": [copy.deepcopy(item[1]) for item in emitted],
            "base_proofs": [copy.deepcopy(item[2]) for item in emitted],
        }
        payload = {
            "accepted": True,
            "error_code": "",
            "profile_id": PROFILE_ID,
            "mode": "shadow",
            "authoritative": False,
            "public_only": True,
            "candidate_count": len(normalized),
            "emitted_count": len(emitted),
            "request": request,
            "candidate_audit": audit_rows,
        }
        return {**payload, "audit_hash": _audit_hash(payload)}

    @staticmethod
    def default_value_model() -> dict[str, Any]:
        return copy.deepcopy(DEFAULT_VALUE_MODEL)


__all__ = ["PROFILE_ID", "TurnProgramGenerator"]
