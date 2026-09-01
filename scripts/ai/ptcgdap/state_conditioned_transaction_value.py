"""Public-only state-conditioned value for Base-admitted Turn Programs.

The model is deliberately a sparse integer artifact.  Python may train and
calibrate the three heads, while Python and GDScript evaluate the same exported
weights locally.  It never owns legality, binding, execution, or terminal
protection; it only scores semantic programs that already carry a fresh Base
proof.
"""

from __future__ import annotations

import copy
import re
from typing import Any

from .cabt_tree_hash import CabtTreeHashError, public_observation_hash


PROFILE_ID = "ptcgdap-state-conditioned-transaction-value-v2"
ENCODER_PROFILE_ID = "ptcgdap-public-state-features-v2"
RESULT_PROFILE_ID = "ptcgdap-state-conditioned-transaction-value-result-v2"
TRAINING_PROFILE_ID = "ptcgdap-joint-decision-training-v2"
FALLBACK_PROFILE_ID = "ptcgdap-turn-program-value-v1"
MAX_SAFE_INTEGER = 9_007_199_254_740_991
MAX_WEIGHT = 100_000
SHA256 = re.compile(r"^[0-9A-F]{64}$")
IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")

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

FALLBACK_FEATURES = (
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

BASE_STATE_FEATURES = (
    "bias_milli",
    "turn.progress_milli",
    "self.hand.count_milli",
    "self.hand.shortage_milli",
    "self.hand.abundance_milli",
    "opponent.hand.count_milli",
    "opponent.hand.shortage_milli",
    "opponent.hand.excess_milli",
    "hand.advantage_milli",
    "self.deck.depletion_milli",
    "opponent.deck.depletion_milli",
    "self.prize.progress_milli",
    "opponent.prize.progress_milli",
    "prize.advantage_milli",
    "self.board.count_milli",
    "opponent.board.count_milli",
    "self.board.bench_space_milli",
    "self.board.energy_milli",
    "self.board.energy_debt_milli",
    "self.board.attack_ready_milli",
    "self.board.damage_milli",
    "opponent.board.energy_milli",
    "opponent.board.energy_debt_milli",
    "opponent.board.attack_ready_milli",
    "opponent.board.damage_milli",
    "self.discard.count_milli",
    "opponent.discard.count_milli",
    "turn.supporter_available_milli",
    "turn.supporter_spent_milli",
    "turn.manual_attachment_available_milli",
    "turn.manual_attachment_spent_milli",
    "turn.retreat_available_milli",
    "turn.retreat_spent_milli",
)

ROLE_ZONES = (
    "self.hand",
    "self.board",
    "self.discard",
    "opponent.board",
    "opponent.discard",
)

ACTION_FEATURES = tuple(f"outcome.{name}" for name in FALLBACK_FEATURES) + (
    "outcome.final_prize_knockout_milli",
    "program.step_count_milli",
    "program.nonterminal_count_milli",
    "program.deadline_milli",
    "program.terminal_attack_milli",
    "program.terminal_end_turn_milli",
)
ACTION_ROLE_CHANNELS = ("card", "source", "target")
ACTION_EFFECT_KINDS = (
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
)
ACTION_RESOURCE_CLAIMS = (
    "none",
    "supporter",
    "manual_attachment",
    "retreat",
    "unknown",
)

_MODEL_KEYS = {
    "profile_id",
    "model_version",
    "feature_schema_version",
    "role_names",
    "uid_roles",
    "fallback_value_model",
    "state_value_weights_milli",
    "action_value_weights_milli",
    "interaction_weights_milli",
    "calibration",
    "training",
}
_CALIBRATION_KEYS = {
    "temperature_milli",
    "bias_utility",
    "clip_abs_utility",
    "minimum_override_margin_utility",
}
_TRAINING_KEYS = {
    "profile_id",
    "run_id",
    "label_profile_id",
    "dataset_sha256",
    "weights_sha256",
}


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


def _hash(value: Any) -> str:
    try:
        return public_observation_hash(value)
    except (CabtTreeHashError, TypeError, ValueError, RecursionError):
        return ""


def _clip(value: int, low: int = -1000, high: int = 1000) -> int:
    return min(high, max(low, value))


def _scaled_count(value: int, maximum: int = 10) -> int:
    return min(maximum, max(0, value)) * (1000 // maximum)


def _trunc_div(numerator: int, denominator: int) -> int:
    if denominator <= 0:
        raise ValueError("invalid denominator")
    sign = -1 if numerator < 0 else 1
    return sign * (abs(numerator) // denominator)


def _fallback_model_valid(value: Any) -> bool:
    return bool(
        type(value) is dict
        and set(value) == {"profile_id", "model_version", "feature_weights_milli"}
        and value.get("profile_id") == FALLBACK_PROFILE_ID
        and _safe_int(value.get("model_version"))
        and value["model_version"] >= 1
        and type(value.get("feature_weights_milli")) is dict
        and set(value["feature_weights_milli"]) == set(FALLBACK_FEATURES)
        and all(
            _safe_int(weight, signed=True) and abs(weight) <= MAX_WEIGHT
            for weight in value["feature_weights_milli"].values()
        )
    )


def _role_feature_names(role_names: list[str]) -> set[str]:
    return {
        f"{zone}.role.{role}_milli"
        for zone in ROLE_ZONES
        for role in role_names
    }


def _available_state_features(model: dict[str, Any]) -> set[str]:
    return set(BASE_STATE_FEATURES) | _role_feature_names(model.get("role_names", []))


def _available_action_features(model: dict[str, Any]) -> set[str]:
    return (
        set(ACTION_FEATURES)
        | {f"program.current_effect.{kind}_milli" for kind in ACTION_EFFECT_KINDS}
        | {
            f"program.current_resource.{claim}_milli"
            for claim in ACTION_RESOURCE_CLAIMS
        }
        | {
        f"action.{channel}.role.{role}_milli"
        for channel in ACTION_ROLE_CHANNELS
        for role in model.get("role_names", [])
        }
    )


def _weights_valid(value: Any, allowed: set[str]) -> bool:
    return bool(
        type(value) is dict
        and set(value).issubset(allowed)
        and all(
            _safe_int(weight, signed=True) and abs(weight) <= MAX_WEIGHT
            for weight in value.values()
        )
    )


def _model_error(value: Any) -> str | None:
    if (
        type(value) is not dict
        or set(value) != _MODEL_KEYS
        or value.get("profile_id") != PROFILE_ID
        or not _safe_int(value.get("model_version"))
        or value["model_version"] < 1
        or value.get("feature_schema_version") != 2
        or type(value.get("role_names")) is not list
        or len(value["role_names"]) > 32
        or len(value["role_names"]) != len(set(value["role_names"]))
        or any(
            type(role) is not str or IDENTIFIER.fullmatch(role) is None
            for role in value["role_names"]
        )
        or type(value.get("uid_roles")) is not dict
    ):
        return "invalid_state_conditioned_value_model"
    roles = set(value["role_names"])
    for uid, assigned in value["uid_roles"].items():
        if (
            type(uid) is not str
            or not uid
            or len(uid) > 128
            or type(assigned) is not list
            or not assigned
            or len(assigned) != len(set(assigned))
            or any(role not in roles for role in assigned)
        ):
            return "invalid_state_conditioned_value_model"
    state_features = _available_state_features(value)
    action_features = _available_action_features(value)
    if (
        not _fallback_model_valid(value.get("fallback_value_model"))
        or not _weights_valid(value.get("state_value_weights_milli"), state_features)
        or not _weights_valid(value.get("action_value_weights_milli"), action_features)
        or type(value.get("interaction_weights_milli")) is not dict
    ):
        return "invalid_state_conditioned_value_model"
    for pair, weight in value["interaction_weights_milli"].items():
        if (
            type(pair) is not str
            or pair.count("::") != 1
            or pair.split("::", 1)[0] not in state_features
            or pair.split("::", 1)[1] not in action_features
            or not _safe_int(weight, signed=True)
            or abs(weight) > MAX_WEIGHT
        ):
            return "invalid_state_conditioned_value_model"
    calibration = value.get("calibration")
    if (
        type(calibration) is not dict
        or set(calibration) != _CALIBRATION_KEYS
        or not _safe_int(calibration.get("temperature_milli"))
        or not 100 <= calibration["temperature_milli"] <= 10_000
        or not _safe_int(calibration.get("bias_utility"), signed=True)
        or not _safe_int(calibration.get("clip_abs_utility"))
        or not 1 <= calibration["clip_abs_utility"] <= 100_000_000
        or not _safe_int(calibration.get("minimum_override_margin_utility"))
        or calibration["minimum_override_margin_utility"] > 10_000_000
    ):
        return "invalid_state_conditioned_value_model"
    training = value.get("training")
    if (
        type(training) is not dict
        or set(training) != _TRAINING_KEYS
        or training.get("profile_id") != TRAINING_PROFILE_ID
        or type(training.get("run_id")) is not str
        or IDENTIFIER.fullmatch(training["run_id"]) is None
        or type(training.get("label_profile_id")) is not str
        or IDENTIFIER.fullmatch(training["label_profile_id"]) is None
        or SHA256.fullmatch(training.get("dataset_sha256", "")) is None
        or SHA256.fullmatch(training.get("weights_sha256", "")) is None
    ):
        return "invalid_state_conditioned_value_model"
    return None


def _cards(value: Any) -> list[dict[str, Any]]:
    return [item for item in value if type(item) is dict] if type(value) is list else []


def _board(player: dict[str, Any]) -> list[dict[str, Any]]:
    return [*_cards(player.get("active", [])), *_cards(player.get("bench", []))]


def _uid(card: dict[str, Any]) -> str:
    value = card.get("local_card_uid", "")
    return value if type(value) is str else ""


def _card_int(card: dict[str, Any], key: str) -> int:
    value = card.get(key, 0)
    return max(0, value) if type(value) is int else 0


def _board_metrics(cards: list[dict[str, Any]]) -> dict[str, int]:
    energy = sum(_card_int(card, "attached_energy_count") for card in cards)
    debt = sum(_card_int(card, "energy_debt") for card in cards)
    ready = sum(card.get("attack_ready") is True for card in cards)
    damage = 0
    for card in cards:
        if type(card.get("damage_counters")) is int:
            damage += max(0, card["damage_counters"])
        elif type(card.get("max_hp")) is int and type(card.get("remaining_hp")) is int:
            damage += max(0, card["max_hp"] - card["remaining_hp"]) // 10
    return {
        "energy_milli": min(1000, energy * 125),
        "energy_debt_milli": min(1000, debt * 125),
        "attack_ready_milli": min(1000, ready * 250),
        "damage_milli": min(1000, damage * 50),
    }


def _error(code: str) -> dict[str, Any]:
    return {
        "accepted": False,
        "error_code": code,
        "profile_id": RESULT_PROFILE_ID,
        "public_only": True,
        "authoritative": False,
        "features_milli": {},
        "audit_hash": "",
    }


class StateConditionedTransactionValueV2:
    """Shared integer encoder and three-head transaction scorer."""

    @staticmethod
    def default_model(
        *,
        uid_roles: dict[str, list[str]] | None = None,
        training_run_id: str = "untrained-default-v2",
    ) -> dict[str, Any]:
        mapping = copy.deepcopy(uid_roles or {})
        role_names = sorted({role for assigned in mapping.values() for role in assigned})
        return {
            "profile_id": PROFILE_ID,
            "model_version": 1,
            "feature_schema_version": 2,
            "role_names": role_names,
            "uid_roles": mapping,
            "fallback_value_model": {
                "profile_id": FALLBACK_PROFILE_ID,
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
            },
            "state_value_weights_milli": {},
            "action_value_weights_milli": {},
            "interaction_weights_milli": {},
            "calibration": {
                "temperature_milli": 1000,
                "bias_utility": 0,
                "clip_abs_utility": 20_000_000,
                "minimum_override_margin_utility": 0,
            },
            "training": {
                "profile_id": TRAINING_PROFILE_ID,
                "run_id": training_run_id,
                "label_profile_id": "ptcgdap-public-better-than-self-v2",
                "dataset_sha256": "0" * 64,
                "weights_sha256": "0" * 64,
            },
        }

    @staticmethod
    def model_error(model: Any) -> str | None:
        return _model_error(model)

    @staticmethod
    def is_model(model: Any) -> bool:
        return _model_error(model) is None

    @staticmethod
    def encode_public_state(frame: Any, model: Any) -> dict[str, Any]:
        error = _model_error(model)
        if error:
            return _error(error)
        if _contains_private(frame):
            return _error("private_state_conditioned_value_input")
        if (
            type(frame) is not dict
            or frame.get("schema_version") != 2
            or frame.get("profile_id") != "ptcgdap-competitive-public-frame-v2"
            or type(frame.get("public_state")) is not dict
        ):
            return _error("invalid_state_conditioned_value_frame")
        state = frame["public_state"]
        own = state.get("self")
        opponent = state.get("opponent")
        if type(own) is not dict or type(opponent) is not dict:
            return _error("invalid_state_conditioned_value_frame")
        own_hand = _cards(own.get("hand", []))
        own_board = _board(own)
        opposing_board = _board(opponent)
        own_discard = _cards(own.get("discard", []))
        opposing_discard = _cards(opponent.get("discard", []))
        opponent_hand_count = opponent.get("hand_count", 0)
        if type(opponent_hand_count) is not int or opponent_hand_count < 0:
            return _error("invalid_state_conditioned_value_frame")
        own_hand_count = len(own_hand)
        own_prizes = own.get("prizes_remaining", 0)
        opponent_prizes = opponent.get("prizes_remaining", 0)
        own_deck = own.get("deck_count", 0)
        opponent_deck = opponent.get("deck_count", 0)
        turn_number = state.get("turn_number", 0)
        if any(
            type(value) is not int or value < 0
            for value in (own_prizes, opponent_prizes, own_deck, opponent_deck, turn_number)
        ):
            return _error("invalid_state_conditioned_value_frame")
        own_metrics = _board_metrics(own_board)
        opponent_metrics = _board_metrics(opposing_board)
        turn = own.get("turn", {}) if type(own.get("turn", {})) is dict else {}
        features: dict[str, int] = {
            "bias_milli": 1000,
            "turn.progress_milli": min(1000, turn_number * 50),
            "self.hand.count_milli": _scaled_count(own_hand_count),
            "self.hand.shortage_milli": min(1000, max(0, 5 - own_hand_count) * 200),
            "self.hand.abundance_milli": min(1000, max(0, own_hand_count - 5) * 200),
            "opponent.hand.count_milli": _scaled_count(opponent_hand_count),
            "opponent.hand.shortage_milli": min(
                1000, max(0, 4 - opponent_hand_count) * 250
            ),
            "opponent.hand.excess_milli": min(
                1000, max(0, opponent_hand_count - 4) * 250
            ),
            "hand.advantage_milli": _clip((own_hand_count - opponent_hand_count) * 125),
            "self.deck.depletion_milli": min(1000, max(0, 60 - own_deck) * 17),
            "opponent.deck.depletion_milli": min(
                1000, max(0, 60 - opponent_deck) * 17
            ),
            "self.prize.progress_milli": min(1000, max(0, 6 - own_prizes) * 167),
            "opponent.prize.progress_milli": min(
                1000, max(0, 6 - opponent_prizes) * 167
            ),
            "prize.advantage_milli": _clip((opponent_prizes - own_prizes) * 167),
            "self.board.count_milli": min(1000, len(own_board) * 167),
            "opponent.board.count_milli": min(1000, len(opposing_board) * 167),
            "self.board.bench_space_milli": min(
                1000, max(0, 5 - len(_cards(own.get("bench", [])))) * 200
            ),
            "self.board.energy_milli": own_metrics["energy_milli"],
            "self.board.energy_debt_milli": own_metrics["energy_debt_milli"],
            "self.board.attack_ready_milli": own_metrics["attack_ready_milli"],
            "self.board.damage_milli": own_metrics["damage_milli"],
            "opponent.board.energy_milli": opponent_metrics["energy_milli"],
            "opponent.board.energy_debt_milli": opponent_metrics["energy_debt_milli"],
            "opponent.board.attack_ready_milli": opponent_metrics["attack_ready_milli"],
            "opponent.board.damage_milli": opponent_metrics["damage_milli"],
            "self.discard.count_milli": _scaled_count(len(own_discard), 20),
            "opponent.discard.count_milli": _scaled_count(len(opposing_discard), 20),
            "turn.supporter_available_milli": 1000
            if turn.get("supporter_available", True) is True
            else 0,
            "turn.supporter_spent_milli": 0
            if turn.get("supporter_available", True) is True
            else 1000,
            "turn.manual_attachment_available_milli": 1000
            if turn.get("manual_attachment_available", True) is True
            else 0,
            "turn.manual_attachment_spent_milli": 0
            if turn.get("manual_attachment_available", True) is True
            else 1000,
            "turn.retreat_available_milli": 1000
            if turn.get("retreat_available", True) is True
            else 0,
            "turn.retreat_spent_milli": 0
            if turn.get("retreat_available", True) is True
            else 1000,
        }
        role_names = model["role_names"]
        for key in _role_feature_names(role_names):
            features[key] = 0
        zones = {
            "self.hand": own_hand,
            "self.board": own_board,
            "self.discard": own_discard,
            "opponent.board": opposing_board,
            "opponent.discard": opposing_discard,
        }
        for zone, cards in zones.items():
            counts = {role: 0 for role in role_names}
            for card in cards:
                for role in model["uid_roles"].get(_uid(card), []):
                    counts[role] += 1
            for role, count in counts.items():
                features[f"{zone}.role.{role}_milli"] = min(1000, count * 250)
        payload = {
            "accepted": True,
            "error_code": "",
            "profile_id": ENCODER_PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "source": copy.deepcopy(frame.get("source")),
            "features_milli": features,
        }
        return {**payload, "audit_hash": _hash(payload)}

    @staticmethod
    def action_features(
        program: Any, outcome: Any, model: Any
    ) -> dict[str, int] | None:
        if type(program) is not dict or type(outcome) is not dict:
            return None
        if any(
            type(outcome.get(feature)) is not int or outcome[feature] < 0
            for feature in FALLBACK_FEATURES
        ):
            return None
        final_prize = outcome.get("final_prize_knockout", 0)
        steps = program.get("semantic_steps")
        deadline = program.get("deadline_turns", 0)
        if (
            final_prize not in (0, 1)
            or type(steps) is not list
            or not steps
            or type(deadline) is not int
            or deadline < 0
        ):
            return None
        terminal = steps[-1].get("terminal_kind") if type(steps[-1]) is dict else None
        result = {f"outcome.{name}": outcome[name] for name in FALLBACK_FEATURES}
        result.update(
            {
                "outcome.final_prize_knockout_milli": final_prize * 1000,
                "program.step_count_milli": min(1000, len(steps) * 100),
                "program.nonterminal_count_milli": min(
                    1000,
                    sum(
                        type(step) is dict and step.get("terminal_kind") == "none"
                        for step in steps
                    )
                    * 100,
                ),
                "program.deadline_milli": min(1000, deadline * 125),
                "program.terminal_attack_milli": 1000 if terminal == "attack" else 0,
                "program.terminal_end_turn_milli": 1000 if terminal == "end_turn" else 0,
            }
        )
        context = program.get("public_action_context", {})
        if context is None:
            context = {}
        if type(context) is not dict:
            return None
        effect_kinds = context.get("current_effect_kinds", [])
        resource_claims = context.get("current_resource_claims", [])
        if (
            type(effect_kinds) is not list
            or any(kind not in ACTION_EFFECT_KINDS for kind in effect_kinds)
            or type(resource_claims) is not list
            or any(claim not in ACTION_RESOURCE_CLAIMS for claim in resource_claims)
        ):
            return None
        for kind in ACTION_EFFECT_KINDS:
            result[f"program.current_effect.{kind}_milli"] = (
                1000 if kind in effect_kinds else 0
            )
        for claim in ACTION_RESOURCE_CLAIMS:
            result[f"program.current_resource.{claim}_milli"] = (
                1000 if claim in resource_claims else 0
            )
        for channel in ACTION_ROLE_CHANNELS:
            values = context.get(f"{channel}_uids", [])
            if type(values) is not list or any(type(uid) is not str for uid in values):
                return None
            counts = {role: 0 for role in model["role_names"]}
            for uid in values:
                for role in model["uid_roles"].get(uid, []):
                    counts[role] += 1
            for role, count in counts.items():
                result[f"action.{channel}.role.{role}_milli"] = min(1000, count * 250)
        return result

    @staticmethod
    def score(
        frame: Any,
        program: Any,
        outcome: Any,
        model: Any,
    ) -> dict[str, Any]:
        encoded = StateConditionedTransactionValueV2.encode_public_state(frame, model)
        if not encoded.get("accepted"):
            return encoded
        action = StateConditionedTransactionValueV2.action_features(program, outcome, model)
        if action is None:
            return _error("invalid_state_conditioned_value_program")
        state = encoded["features_milli"]
        fallback = model["fallback_value_model"]["feature_weights_milli"]
        base = sum(outcome[name] * fallback[name] for name in FALLBACK_FEATURES)
        state_head = sum(
            state[name] * weight
            for name, weight in model["state_value_weights_milli"].items()
        )
        action_head = sum(
            action[name] * weight
            for name, weight in model["action_value_weights_milli"].items()
        )
        interaction_head = sum(
            _trunc_div(state[state_name] * action[action_name] * weight, 1000)
            for pair, weight in model["interaction_weights_milli"].items()
            for state_name, action_name in [pair.split("::", 1)]
        )
        calibration = model["calibration"]
        raw_adjustment = (
            state_head
            + action_head
            + interaction_head
            + calibration["bias_utility"]
        )
        adjustment = _trunc_div(
            raw_adjustment * 1000, calibration["temperature_milli"]
        )
        clip_abs = calibration["clip_abs_utility"]
        adjustment = min(clip_abs, max(-clip_abs, adjustment))
        payload = {
            "accepted": True,
            "error_code": "",
            "profile_id": RESULT_PROFILE_ID,
            "public_only": True,
            "authoritative": False,
            "model_version": model["model_version"],
            "source": copy.deepcopy(frame.get("source")),
            "base_utility": base,
            "state_value": state_head,
            "action_value": action_head,
            "interaction_value": interaction_head,
            "conditioned_adjustment": adjustment,
            "total_utility": base + adjustment,
            "state_feature_hash": encoded["audit_hash"],
            "action_feature_hash": _hash(action),
        }
        return {**payload, "audit_hash": _hash(payload)}


__all__ = [
    "ACTION_FEATURES",
    "BASE_STATE_FEATURES",
    "ENCODER_PROFILE_ID",
    "PROFILE_ID",
    "RESULT_PROFILE_ID",
    "StateConditionedTransactionValueV2",
]
