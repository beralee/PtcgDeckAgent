"""Public-only roll-forward and observed-outcome gates for Turn Programs.

This module deliberately predicts bounded semantic deltas instead of cloning a
private engine state.  It is a development/conformance component: Base Graph
still owns legality and a caller must reobserve and rebind before execution.
"""

from __future__ import annotations

import copy
from typing import Any

from .cabt_tree_hash import CabtTreeHashError, public_observation_hash


PROFILE_ID = "ptcgdap-turn-program-transition-v1"
OUTCOME_GATE_PROFILE_ID = "ptcgdap-turn-program-outcome-gate-v1"

_DELTA_BY_EFFECT: dict[str, dict[str, int]] = {
    "ability": {"board_development_milli": 100, "next_turn_continuity_milli": 140},
    "bench": {"board_development_milli": 220, "next_turn_continuity_milli": 260},
    "conversion": {"attack_pressure_milli": 220, "next_turn_continuity_milli": 120},
    "damage_transfer": {"attack_pressure_milli": 260, "next_turn_continuity_milli": 180},
    "disruption": {"disruption_milli": 620, "next_turn_continuity_milli": 120},
    "draw": {"hand_quality_milli": 520, "next_turn_continuity_milli": 100},
    "energy": {"board_development_milli": 180, "attack_pressure_milli": 120, "next_turn_continuity_milli": 280},
    "evolution": {"board_development_milli": 320, "next_turn_continuity_milli": 300},
    "handoff": {"attack_pressure_milli": 160, "next_turn_continuity_milli": 160},
    "search": {"board_development_milli": 100, "hand_quality_milli": 260, "next_turn_continuity_milli": 180},
    "tool": {"board_development_milli": 100, "next_turn_continuity_milli": 140},
}

_BASE_UNCERTAINTY = {
    "ability": 120,
    "attack": 100,
    "bench": 80,
    "conversion": 180,
    "damage_transfer": 100,
    "disruption": 100,
    "draw": 100,
    "end_turn": 0,
    "energy": 80,
    "evolution": 50,
    "handoff": 100,
    "search": 180,
    "tool": 120,
}


def _audit_hash(value: Any) -> str:
    try:
        return public_observation_hash(value)
    except (CabtTreeHashError, TypeError, ValueError, RecursionError):
        return ""


def _resource_claim(
    effect_kind: str,
    current_facts: list[dict[str, Any]],
    offset: int,
    declared_claim: Any,
) -> str:
    if declared_claim in {"none", "supporter", "manual_attachment", "retreat", "unknown"}:
        return str(declared_claim)
    kinds = {str(fact.get("kind", "")) for fact in current_facts} if offset == 0 else set()
    if effect_kind in {"draw", "disruption"}:
        return "supporter"
    if effect_kind == "energy" and "attach_energy" in kinds:
        return "manual_attachment"
    if effect_kind == "handoff" and "retreat" in kinds:
        return "retreat"
    if effect_kind == "search" and "play_trainer" in kinds:
        # A public option alone does not prove whether this is an Item or a
        # Supporter, nor whether a downstream search succeeds.  Fail closed.
        return "unknown"
    return "none"


def _public_metrics(frame: dict[str, Any]) -> dict[str, int]:
    state = frame.get("public_state", {})
    own = state.get("self", {})
    opponent = state.get("opponent", {})
    own_board = [*own.get("active", []), *own.get("bench", [])]
    opposing_board = [*opponent.get("active", []), *opponent.get("bench", [])]
    return {
        "own_board_count": len(own_board),
        "own_energy_count": sum(
            int(card.get("attached_energy_count", 0) or 0) for card in own_board
        ),
        "own_hand_count": len(own.get("hand", [])),
        "own_prizes_remaining": int(own.get("prizes_remaining", 0) or 0),
        "opponent_hand_count": int(opponent.get("hand_count", 0) or 0),
        "opponent_damage_count": sum(
            max(0, int(card.get("damage", 0) or 0) // 10) for card in opposing_board
        ),
    }


class TurnProgramTransitionEvaluator:
    """Evaluate one normalized Turn Program using public facts only."""

    @staticmethod
    def evaluate(
        frame: Any,
        candidate: Any,
        *,
        visible_debt_count: int,
        max_uncertainty_milli: int = 400,
    ) -> dict[str, Any]:
        if (
            type(frame) is not dict
            or type(candidate) is not dict
            or type(visible_debt_count) is not int
            or visible_debt_count < 0
            or type(max_uncertainty_milli) is not int
            or not 0 <= max_uncertainty_milli <= 1000
            or type(candidate.get("semantic_steps")) is not list
            or not candidate.get("semantic_steps")
            or type(candidate.get("current_option_facts")) is not list
            or type(frame.get("source")) is not dict
        ):
            return TurnProgramTransitionEvaluator._error("invalid_transition_request")

        steps: list[dict[str, Any]] = candidate["semantic_steps"]
        seen: set[str] = set()
        claims: set[str] = set()
        step_audit: list[dict[str, Any]] = []
        delta = {
            "board_development_milli": 0,
            "attack_pressure_milli": 0,
            "next_turn_continuity_milli": 0,
            "hand_quality_milli": 0,
            "disruption_milli": 0,
        }
        uncertainty = 0
        dependency_debt = 0
        resource_conflicts = 0
        executed_prefix = 0
        turn = frame.get("public_state", {}).get("self", {}).get("turn", {})
        availability = {
            "supporter": bool(turn.get("supporter_available", True)),
            "manual_attachment": bool(turn.get("manual_attachment_available", True)),
            "retreat": bool(turn.get("retreat_available", True)),
        }
        current_facts = candidate["current_option_facts"]

        for offset, step in enumerate(steps):
            if type(step) is not dict or type(step.get("step_id")) is not str:
                return TurnProgramTransitionEvaluator._error("invalid_transition_step")
            step_id = step["step_id"]
            dependencies = step.get("depends_on", [])
            dependency_ok = (
                type(dependencies) is list
                and all(type(item) is str and item in seen for item in dependencies)
            )
            if not dependency_ok:
                dependency_debt += 1
            effect_kind = str(step.get("effect_kind", ""))
            claim = _resource_claim(
                effect_kind, current_facts, offset, step.get("resource_claim")
            )
            conflict = False
            if claim == "unknown":
                uncertainty += 600
            elif claim != "none":
                conflict = claim in claims or not availability.get(claim, False)
                if conflict:
                    resource_conflicts += 1
                claims.add(claim)
                availability[claim] = False

            step_uncertainty = _BASE_UNCERTAINTY.get(effect_kind, 400)
            if offset > 0:
                step_uncertainty += 20
            uncertainty += step_uncertainty
            if dependency_ok:
                executed_prefix += 1
                for feature, amount in _DELTA_BY_EFFECT.get(effect_kind, {}).items():
                    delta[feature] = min(1000, delta[feature] + amount)
            seen.add(step_id)
            step_audit.append(
                {
                    "step_id": step_id,
                    "effect_kind": effect_kind,
                    "dependency_satisfied": dependency_ok,
                    "resource_claim": claim,
                    "resource_conflict": conflict,
                    "uncertainty_milli": min(1000, step_uncertainty + (600 if claim == "unknown" else 0)),
                }
            )

        unresolved_debt = max(0, visible_debt_count - sum(
            1 for step in steps if step.get("terminal_kind") == "none"
        ))
        terminal_reached = bool(steps[-1].get("terminal_kind") in {"attack", "end_turn"})
        uncertainty = min(1000, uncertainty)
        commit_safe = bool(
            dependency_debt == 0
            and resource_conflicts == 0
            and uncertainty <= max_uncertainty_milli
        )
        payload = {
            "accepted": True,
            "error_code": "",
            "profile_id": PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "source": copy.deepcopy(frame["source"]),
            "program_id": candidate.get("program_id"),
            "executed_prefix_length": executed_prefix,
            "terminal_reached": terminal_reached,
            "unresolved_dependency_count": dependency_debt,
            "resource_conflict_count": resource_conflicts,
            "uncertainty_milli": uncertainty,
            "unresolved_debt_milli": min(1000, unresolved_debt * 250),
            "commit_safe": commit_safe,
            "resource_ledger_after": availability,
            "predicted_public_delta": delta,
            "baseline_public_metrics": _public_metrics(frame),
            "step_audit": step_audit,
        }
        return {**payload, "audit_hash": _audit_hash(payload)}

    @staticmethod
    def _error(code: str) -> dict[str, Any]:
        return {
            "accepted": False,
            "error_code": code,
            "profile_id": PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "source": None,
            "program_id": None,
            "executed_prefix_length": 0,
            "terminal_reached": False,
            "unresolved_dependency_count": 0,
            "resource_conflict_count": 0,
            "uncertainty_milli": 1000,
            "unresolved_debt_milli": 1000,
            "commit_safe": False,
            "resource_ledger_after": {},
            "predicted_public_delta": {},
            "baseline_public_metrics": {},
            "step_audit": [],
            "audit_hash": "",
        }


class TurnProgramOutcomeGate:
    """Label public transition predictions after a fresh observation."""

    @staticmethod
    def label(prediction: Any, observed_frame: Any) -> dict[str, Any]:
        if type(prediction) is not dict or type(observed_frame) is not dict:
            return TurnProgramOutcomeGate._error("invalid_transition_label")
        old_source = prediction.get("source")
        new_source = observed_frame.get("source")
        if type(old_source) is not dict or type(new_source) is not dict:
            return TurnProgramOutcomeGate._error("invalid_transition_label")
        if old_source == new_source:
            return TurnProgramOutcomeGate._error("stale_transition_observation")

        before = prediction.get("baseline_public_metrics", {})
        if type(before) is not dict:
            before = {}
        after = _public_metrics(observed_frame)
        effect = str(prediction.get("effect_kind", ""))
        if not effect and type(prediction.get("step_audit")) is list and prediction["step_audit"]:
            effect = str(prediction["step_audit"][0].get("effect_kind", ""))
        evidence = False
        contradicted = False
        if effect in {"evolution", "bench"}:
            evidence = after["own_board_count"] > int(before.get("own_board_count", 0))
        elif effect == "energy":
            evidence = after["own_energy_count"] > int(before.get("own_energy_count", 0))
        elif effect in {"draw", "search"}:
            evidence = after["own_hand_count"] > int(before.get("own_hand_count", 0))
        elif effect == "disruption":
            prior = int(before.get("opponent_hand_count", after["opponent_hand_count"] + 1))
            evidence = after["opponent_hand_count"] < prior
        elif effect == "damage_transfer":
            evidence = after["opponent_damage_count"] > int(before.get("opponent_damage_count", 0))
        elif effect == "attack":
            prior = int(before.get("own_prizes_remaining", after["own_prizes_remaining"] + 1))
            evidence = after["own_prizes_remaining"] < prior
        else:
            contradicted = True
        status = "confirmed" if evidence else "contradicted" if contradicted else "unresolved"
        payload = {
            "accepted": True,
            "error_code": "",
            "profile_id": OUTCOME_GATE_PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "program_id": prediction.get("program_id"),
            "effect_kind": effect,
            "status": status,
            "confirmed": status == "confirmed",
            "contradicted": status == "contradicted",
            "promotion_eligible": False,
            "observed_source": copy.deepcopy(new_source),
        }
        return {**payload, "audit_hash": _audit_hash(payload)}

    @staticmethod
    def summarize(labels: Any, *, minimum_confirmed: int = 8) -> dict[str, Any]:
        rows = labels if type(labels) is list else []
        accepted = [row for row in rows if type(row) is dict and row.get("accepted")]
        confirmed = sum(row.get("status") == "confirmed" for row in accepted)
        contradicted = sum(row.get("status") == "contradicted" for row in accepted)
        unresolved = sum(row.get("status") == "unresolved" for row in accepted)
        eligible = bool(
            confirmed >= minimum_confirmed
            and contradicted == 0
            and unresolved <= max(2, confirmed // 4)
        )
        payload = {
            "accepted": bool(accepted),
            "error_code": "" if accepted else "no_transition_labels",
            "profile_id": OUTCOME_GATE_PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "label_count": len(accepted),
            "confirmed_count": confirmed,
            "contradicted_count": contradicted,
            "unresolved_count": unresolved,
            "promotion_eligible": eligible,
        }
        return {**payload, "audit_hash": _audit_hash(payload)}

    @staticmethod
    def _error(code: str) -> dict[str, Any]:
        return {
            "accepted": False,
            "error_code": code,
            "profile_id": OUTCOME_GATE_PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "program_id": None,
            "effect_kind": "",
            "status": "rejected",
            "confirmed": False,
            "contradicted": False,
            "promotion_eligible": False,
            "observed_source": None,
            "audit_hash": "",
        }


__all__ = [
    "OUTCOME_GATE_PROFILE_ID",
    "PROFILE_ID",
    "TurnProgramOutcomeGate",
    "TurnProgramTransitionEvaluator",
]
