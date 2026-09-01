"""Public-only, non-authoritative whole-turn program arbitration.

This layer deliberately does not bind or execute a CABT option.  Deck adapters
may propose several semantic whole-turn programs and a Base-owned proof may
admit their first currently executable semantic step.  The planner compares
fresh public outcome estimates, returns one semantic program in shadow mode,
and requires the normal current-window Base Graph path to rebind every action.
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


MAX_SAFE_INTEGER = 9_007_199_254_740_991
PROFILE_ID = "ptcgdap-turn-program-shadow-v1"
REQUEST_PROFILE_ID = "ptcgdap-turn-program-request-v1"
VALUE_PROFILE_ID = "ptcgdap-turn-program-value-v1"
FRAME_PROFILE_ID = "ptcgdap-competitive-public-frame-v2"
IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
PACKAGE_IDENTITY = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._@+#-]{0,255}$")
SHA256 = re.compile(r"^[0-9A-F]{64}$")

FEATURES = (
    "final_prize_knockout",
    "prize_gain_milli",
    "board_development_milli",
    "attack_pressure_milli",
    "next_turn_continuity_milli",
    "hand_quality_milli",
    "disruption_milli",
    "resource_preservation_milli",
    "risk_milli",
    "unresolved_debt_milli",
)

DEFAULT_VALUE_MODEL: dict[str, Any] = {
    "profile_id": VALUE_PROFILE_ID,
    "model_version": 1,
    "feature_weights_milli": {
        "prize_gain_milli": 4000,
        "board_development_milli": 900,
        "attack_pressure_milli": 1100,
        "next_turn_continuity_milli": 1300,
        "hand_quality_milli": 500,
        "disruption_milli": 700,
        "resource_preservation_milli": 800,
        "risk_milli": -2000,
        "unresolved_debt_milli": -1000,
    },
}

PRIVATE_KEYS = frozenset(
    {
        "deck_order",
        "face_down_prizes",
        "private_state",
        "private_rng_state",
        "search_begin_input",
        "callback",
        "ticket",
        "command",
        "object_ref",
        "instance_id",
        "raw_private_hash",
        "training_oracle_identity",
    }
)

_REQUEST_KEYS = {
    "schema_version",
    "profile_id",
    "source",
    "value_model",
    "programs",
    "base_proofs",
}
_PROGRAM_KEYS = {
    "program_id",
    "goal_id",
    "route_id",
    "deadline_turns",
    "semantic_steps",
    "public_outcome",
}
_CONDITIONED_PROGRAM_KEYS = _PROGRAM_KEYS | {"public_action_context"}
_STEP_KEYS = {
    "step_id",
    "transaction_id",
    "method_id",
    "depends_on",
    "terminal_kind",
}
_PROOF_KEYS = {
    "program_id",
    "admissible",
    "current_step_id",
    "current_step_executable",
    "mandatory_preserved",
    "terminal_preserved",
    "base_vetoed",
}
_MODEL_KEYS = {"profile_id", "model_version", "feature_weights_milli"}
_WEIGHT_FEATURES = frozenset(FEATURES) - {"final_prize_knockout"}


def _identifier(value: Any) -> bool:
    return type(value) is str and IDENTIFIER.fullmatch(value) is not None


def _safe_int(value: Any, *, signed: bool = False) -> bool:
    return type(value) is int and (
        -MAX_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER
        if signed
        else 0 <= value <= MAX_SAFE_INTEGER
    )


def _contains_private(value: Any) -> bool:
    stack = [value]
    while stack:
        current = stack.pop()
        if type(current) is dict:
            for key, child in current.items():
                if type(key) is not str or key.casefold() in PRIVATE_KEYS:
                    return True
                stack.append(child)
        elif type(current) is list:
            stack.extend(current)
    return False


def _source(value: Any) -> bool:
    return (
        type(value) is dict
        and set(value) == {"public_observation_hash", "window_id"}
        and SHA256.fullmatch(value.get("public_observation_hash", "")) is not None
        and SHA256.fullmatch(value.get("window_id", "")) is not None
    )


def _frame_error(frame: Any) -> str | None:
    if type(frame) is not dict:
        return "invalid_turn_program_frame"
    if frame.get("schema_version") != 2 or frame.get("profile_id") != FRAME_PROFILE_ID:
        return "invalid_turn_program_frame"
    if not _source(frame.get("source")):
        return "invalid_turn_program_frame"
    if type(frame.get("seat")) is not int or frame["seat"] not in (0, 1):
        return "invalid_turn_program_frame"
    turn_number = frame.get("public_state", {}).get("turn_number")
    if not _safe_int(turn_number):
        return "invalid_turn_program_frame"
    if type(frame.get("options")) is not list:
        return "invalid_turn_program_frame"
    return None


def _model_error(model: Any) -> str | None:
    if type(model) is dict and model.get("profile_id") == CONDITIONED_VALUE_PROFILE_ID:
        return StateConditionedTransactionValueV2.model_error(model)
    if (
        type(model) is not dict
        or set(model) != _MODEL_KEYS
        or model.get("profile_id") != VALUE_PROFILE_ID
        or not _safe_int(model.get("model_version"))
        or model.get("model_version") < 1
        or type(model.get("feature_weights_milli")) is not dict
        or set(model["feature_weights_milli"]) != _WEIGHT_FEATURES
    ):
        return "invalid_turn_program_value_model"
    if any(
        not _safe_int(weight, signed=True)
        for weight in model["feature_weights_milli"].values()
    ):
        return "invalid_turn_program_value_model"
    return None


def _outcome_error(outcome: Any) -> str | None:
    if type(outcome) is not dict or set(outcome) != set(FEATURES):
        return "invalid_turn_program"
    for feature in FEATURES:
        value = outcome[feature]
        if not _safe_int(value):
            return "invalid_turn_program"
        maximum = 1 if feature == "final_prize_knockout" else (
            3000 if feature == "prize_gain_milli" else 1000
        )
        if value > maximum:
            return "invalid_turn_program"
    return None


def _program_error(program: Any, *, conditioned: bool = False) -> str | None:
    expected_keys = _CONDITIONED_PROGRAM_KEYS if conditioned else _PROGRAM_KEYS
    if (
        type(program) is not dict
        or set(program) != expected_keys
        or not all(_identifier(program.get(key)) for key in ("program_id", "goal_id", "route_id"))
        or not _safe_int(program.get("deadline_turns"))
        or program["deadline_turns"] > 8
        or type(program.get("semantic_steps")) is not list
        or not 1 <= len(program["semantic_steps"]) <= 32
    ):
        return "invalid_turn_program"
    if _outcome_error(program.get("public_outcome")):
        return "invalid_turn_program"
    if conditioned:
        context = program.get("public_action_context")
        if (
            type(context) is not dict
            or set(context) != {
                "card_uids", "source_uids", "target_uids", "kinds", "tags",
                "current_effect_kinds", "current_resource_claims",
            }
            or any(
                type(context[key]) is not list
                or context[key] != sorted(set(context[key]))
                or any(type(item) is not str or len(item) > 128 for item in context[key])
                for key in context
            )
        ):
            return "invalid_turn_program"

    seen: set[str] = set()
    terminal_count = 0
    for offset, step in enumerate(program["semantic_steps"]):
        if (
            type(step) is not dict
            or set(step) != _STEP_KEYS
            or not all(
                _identifier(step.get(key))
                for key in ("step_id", "transaction_id", "method_id")
            )
            or type(step.get("depends_on")) is not list
            or len(step["depends_on"]) > 16
            or len(step["depends_on"]) != len(set(step["depends_on"]))
            or any(not _identifier(value) for value in step["depends_on"])
            or step.get("terminal_kind") not in {"none", "attack", "end_turn"}
        ):
            return "invalid_turn_program"
        step_id = step["step_id"]
        if step_id in seen or any(dependency not in seen for dependency in step["depends_on"]):
            return "invalid_turn_program"
        seen.add(step_id)
        if step["terminal_kind"] != "none":
            terminal_count += 1
            if offset != len(program["semantic_steps"]) - 1:
                return "invalid_turn_program"
    if terminal_count > 1:
        return "invalid_turn_program"
    return None


def _proof_error(proof: Any, programs: dict[str, dict[str, Any]]) -> str | None:
    if (
        type(proof) is not dict
        or set(proof) != _PROOF_KEYS
        or not _identifier(proof.get("program_id"))
        or not _identifier(proof.get("current_step_id"))
        or any(
            type(proof.get(key)) is not bool
            for key in (
                "admissible",
                "current_step_executable",
                "mandatory_preserved",
                "terminal_preserved",
                "base_vetoed",
            )
        )
    ):
        return "invalid_turn_program_base_proof"
    program = programs.get(proof["program_id"])
    if program is None:
        return "invalid_turn_program_base_proof"
    first_step_id = program["semantic_steps"][0]["step_id"]
    if proof["current_step_id"] != first_step_id:
        return "invalid_turn_program_base_proof"
    return None


def _request_error(request: Any) -> str | None:
    if (
        type(request) is not dict
        or set(request) != _REQUEST_KEYS
        or request.get("schema_version") != 1
        or request.get("profile_id") != REQUEST_PROFILE_ID
        or not _source(request.get("source"))
        or type(request.get("programs")) is not list
        or not 1 <= len(request["programs"]) <= 32
        or type(request.get("base_proofs")) is not list
    ):
        return "invalid_turn_program_request"
    model_error = _model_error(request.get("value_model"))
    if model_error:
        return model_error
    programs: dict[str, dict[str, Any]] = {}
    for program in request["programs"]:
        error = _program_error(
            program,
            conditioned=request["value_model"].get("profile_id")
            == CONDITIONED_VALUE_PROFILE_ID,
        )
        if error:
            return error
        program_id = program["program_id"]
        if program_id in programs:
            return "invalid_turn_program"
        programs[program_id] = program
    if len(request["base_proofs"]) != len(programs):
        return "invalid_turn_program_base_proof"
    proof_ids: set[str] = set()
    for proof in request["base_proofs"]:
        error = _proof_error(proof, programs)
        if error:
            return error
        if proof["program_id"] in proof_ids:
            return "invalid_turn_program_base_proof"
        proof_ids.add(proof["program_id"])
    if proof_ids != set(programs):
        return "invalid_turn_program_base_proof"
    return None


def _error(code: str) -> dict[str, Any]:
    return {
        "accepted": False,
        "error_code": code,
        "mode": "shadow",
        "authoritative": False,
        "public_only": True,
        "selected_program_id": None,
        "selected_current_step_id": None,
        "ranked_program_ids": [],
        "candidate_audit": [],
        "reobserve_before_execution": True,
        "stale_plan_has_authority": False,
        "audit_hash": "",
    }


def _utility(
    frame: dict[str, Any], program: dict[str, Any], model: dict[str, Any]
) -> tuple[int, dict[str, Any] | None]:
    if model.get("profile_id") == CONDITIONED_VALUE_PROFILE_ID:
        conditioned = StateConditionedTransactionValueV2.score(
            frame, program, program["public_outcome"], model
        )
        if not conditioned.get("accepted"):
            raise ValueError(
                str(conditioned.get("error_code", "state_conditioned_value_failed"))
            )
        return int(conditioned["total_utility"]), conditioned
    outcome = program["public_outcome"]
    weights = model["feature_weights_milli"]
    return (
        sum(outcome[feature] * weights[feature] for feature in _WEIGHT_FEATURES),
        None,
    )


def _audit_hash(payload: dict[str, Any]) -> str:
    try:
        return public_observation_hash(payload)
    except (CabtTreeHashError, TypeError, ValueError, RecursionError):
        return ""


class TurnProgramShadowPlanner:
    """Deterministic whole-turn comparison with no option execution authority."""

    @staticmethod
    def evaluate(frame: Any, request: Any) -> dict[str, Any]:
        if _contains_private(frame) or _contains_private(request):
            return _error("private_turn_program_input")
        frame_error = _frame_error(frame)
        if frame_error:
            return _error(frame_error)
        request_error = _request_error(request)
        if request_error:
            return _error(request_error)
        if request["source"] != frame["source"]:
            return _error("turn_program_source_mismatch")

        proof_by_id = {proof["program_id"]: proof for proof in request["base_proofs"]}
        ranked: list[tuple[tuple[Any, ...], dict[str, Any], int]] = []
        candidate_audit: list[dict[str, Any]] = []
        for order, program in enumerate(request["programs"]):
            proof = proof_by_id[program["program_id"]]
            status = "eligible"
            if proof["base_vetoed"]:
                status = "base_vetoed"
            elif not proof["admissible"]:
                status = "base_not_admissible"
            elif not proof["mandatory_preserved"]:
                status = "mandatory_not_preserved"
            elif not proof["terminal_preserved"]:
                status = "terminal_not_preserved"
            elif not proof["current_step_executable"]:
                status = "current_step_not_executable"

            try:
                utility_milli, conditioned_value = _utility(
                    frame, program, request["value_model"]
                )
            except ValueError as error:
                return _error(str(error))
            row = {
                "program_id": program["program_id"],
                "status": status,
                "current_step_id": proof["current_step_id"],
                "utility_milli": utility_milli,
                "final_prize_knockout": program["public_outcome"]["final_prize_knockout"],
                "unresolved_debt_milli": program["public_outcome"]["unresolved_debt_milli"],
            }
            if conditioned_value is not None:
                row["conditioned_value"] = copy.deepcopy(conditioned_value)
            candidate_audit.append(row)
            if status != "eligible":
                continue
            rank = (
                -program["public_outcome"]["final_prize_knockout"],
                -utility_milli,
                program["public_outcome"]["unresolved_debt_milli"],
                len(program["semantic_steps"]),
                program["program_id"],
                order,
            )
            ranked.append((rank, program, utility_milli))

        ranked.sort(key=lambda value: value[0])
        selected = ranked[0][1] if ranked else None
        selected_step = selected["semantic_steps"][0] if selected is not None else None
        payload = {
            "accepted": True,
            "error_code": "",
            "schema_version": 1,
            "profile_id": PROFILE_ID,
            "mode": "shadow",
            "authoritative": False,
            "public_only": True,
            "source": copy.deepcopy(frame["source"]),
            "selected_program_id": None if selected is None else selected["program_id"],
            "selected_goal_id": None if selected is None else selected["goal_id"],
            "selected_route_id": None if selected is None else selected["route_id"],
            "selected_current_step_id": None if selected_step is None else selected_step["step_id"],
            "ranked_program_ids": [program["program_id"] for _, program, _ in ranked],
            "candidate_audit": candidate_audit,
            "reobserve_before_execution": True,
            "stale_plan_has_authority": False,
        }
        return {**payload, "audit_hash": _audit_hash(payload)}


class TurnProgramJournal:
    """Match-scoped semantic continuity; every value and proof is recomputed fresh."""

    def __init__(self, match_id: str, seat: int, package_identity: str) -> None:
        if (
            not _identifier(match_id)
            or seat not in (0, 1)
            or type(package_identity) is not str
            or PACKAGE_IDENTITY.fullmatch(package_identity) is None
        ):
            raise ValueError("invalid_turn_program_scope")
        self._scope = {
            "match_id": match_id,
            "seat": seat,
            "package_identity": package_identity,
        }
        self._state: dict[str, Any] = {}

    def snapshot(self) -> dict[str, Any]:
        return {"scope": copy.deepcopy(self._scope), "state": copy.deepcopy(self._state)}

    def clear(self) -> None:
        self._state = {}

    def advance(self, frame: Any, request: Any) -> dict[str, Any]:
        if type(frame) is not dict or frame.get("seat") != self._scope["seat"]:
            return _error("turn_program_scope_mismatch")
        result = TurnProgramShadowPlanner.evaluate(frame, request)
        if not result["accepted"]:
            return result
        selected_id = result["selected_program_id"]
        previous_id = self._state.get("program_id")
        if selected_id is None:
            self.clear()
            event = "idle"
        else:
            selected = next(
                program for program in request["programs"] if program["program_id"] == selected_id
            )
            turn_number = frame["public_state"]["turn_number"]
            event = (
                "started"
                if previous_id is None
                else "continued"
                if previous_id == selected_id
                else "replanned"
            )
            self._state = {
                "program_id": selected["program_id"],
                "goal_id": selected["goal_id"],
                "route_id": selected["route_id"],
                "start_turn": turn_number,
                "deadline_turn": turn_number + selected["deadline_turns"],
            }
        payload = {key: copy.deepcopy(value) for key, value in result.items() if key != "audit_hash"}
        payload["journal_event"] = event
        payload["state"] = copy.deepcopy(self._state)
        return {**payload, "audit_hash": _audit_hash(payload)}


__all__ = [
    "DEFAULT_VALUE_MODEL",
    "FEATURES",
    "PROFILE_ID",
    "REQUEST_PROFILE_ID",
    "TurnProgramJournal",
    "TurnProgramShadowPlanner",
    "VALUE_PROFILE_ID",
]
