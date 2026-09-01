from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Final, Mapping, Sequence


MAX_OPTIONS: Final = 1024
FRAME_WIDTH: Final = 24
OPTION_WIDTH: Final = 16
TENSOR_PROFILE_ID: Final = "competitive_public_actor_i32_v1"

_OPTION_FIELDS: Final = (
    "type",
    "number",
    "area",
    "index",
    "playerIndex",
    "toolIndex",
    "energyIndex",
    "count",
    "inPlayArea",
    "inPlayIndex",
    "attackId",
    "cardId",
    "serial",
    "specialConditionType",
)
_OPTION_SHAPES: Final = {
    0: ("type", "number"),
    1: ("type",),
    2: ("type",),
    3: ("type", "area", "index", "playerIndex"),
    4: ("type", "area", "index", "playerIndex", "toolIndex"),
    5: ("type", "area", "index", "playerIndex", "energyIndex"),
    6: ("type", "area", "index", "playerIndex", "energyIndex", "count"),
    7: ("type", "index"),
    8: ("type", "area", "index", "inPlayArea", "inPlayIndex"),
    9: ("type", "area", "index", "inPlayArea", "inPlayIndex"),
    10: ("type", "area", "index"),
    11: ("type", "area", "index"),
    12: ("type",),
    13: ("type", "attackId"),
    14: ("type",),
    15: ("type", "cardId", "serial"),
    16: ("type", "specialConditionType"),
}
_FORBIDDEN_KEYS: Final = frozenset(
    {
        "private_state",
        "raw_private_hash",
        "token_free_callback_hash",
        "search_begin_input",
        "session",
        "callback",
        "binding",
        "ticket",
        "command",
        "object_ref",
        "pokemon_entity_serial",
        "credentials",
        "deck_order",
        "face_down_prizes",
        "rng",
    }
)
_CLOCK_FIELDS: Final = (
    "turn",
    "turn_action_count",
    "remaining_overage_time",
    "acting_prizes_remaining",
    "opponent_prizes_remaining",
    "acting_deck_count",
    "opponent_deck_count",
    "acting_hand_count",
    "opponent_hand_count",
)
_FLAG_FIELDS: Final = (
    "first_player",
    "result",
    "supporter_played",
    "stadium_played",
    "energy_attached",
    "retreated",
)


class ModelActorError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _raise(code: str) -> None:
    raise ModelActorError(code)


def _contains_forbidden_key(value: Any) -> bool:
    stack = [value]
    while stack:
        current = stack.pop()
        if type(current) is dict:
            for key, child in current.items():
                if type(key) is not str:
                    return True
                folded = key.casefold()
                if folded in _FORBIDDEN_KEYS or "private" in folded or "hidden" in folded:
                    return True
                stack.append(child)
        elif type(current) is list:
            stack.extend(current)
    return False


def _i32(value: Any, code: str) -> int:
    if type(value) is bool:
        return int(value)
    if type(value) is not int or not -(2**31) <= value < 2**31:
        _raise(code)
    return value


def _optional_i32(value: Any) -> tuple[int, int]:
    if value is None:
        return 0, 0
    return _i32(value, "model_feature_range_invalid"), 1


def _uid_feature(uid: str) -> int:
    digest = hashlib.sha256(b"PTCGDAP\0MODEL_UID_V1\0" + uid.encode("ascii")).digest()
    unsigned = int.from_bytes(digest[:4], "big")
    return unsigned - 2**32 if unsigned >= 2**31 else unsigned


@dataclass(frozen=True, slots=True)
class PublicActorTensors:
    profile_id: str
    frame_i32: tuple[int, ...]
    frame_presence_i32: tuple[int, ...]
    option_i32: tuple[tuple[int, ...], ...]
    option_presence_i32: tuple[tuple[int, ...], ...]
    option_mask_i32: tuple[int, ...]
    semantic_keys: tuple[str, ...]
    row_to_current_index: tuple[int, ...]
    current_index_to_row: Mapping[int, int]
    min_count: int
    max_count: int


class PublicActorTensorizer:
    __slots__ = ()

    @staticmethod
    def tensorize(
        context: Any,
        *,
        local_option_uids: Mapping[int, str] | None = None,
        allowed_card_uids: set[str] | frozenset[str] | None = None,
    ) -> PublicActorTensors:
        if type(context) is not dict:
            _raise("model_public_frame_invalid")
        if _contains_forbidden_key(context):
            _raise("model_hidden_field")
        clocks = context.get("clocks")
        state = context.get("public_state")
        semantics = context.get("select_semantics")
        if type(clocks) is not dict or type(state) is not dict or type(semantics) is not dict:
            _raise("model_public_frame_invalid")
        flags = state.get("turn_flags")
        options = semantics.get("options")
        if type(flags) is not dict or type(options) is not list or len(options) > MAX_OPTIONS:
            _raise("model_public_frame_invalid")

        frame_values: list[int] = []
        frame_presence: list[int] = []
        for key in _CLOCK_FIELDS:
            if key not in clocks:
                _raise("model_public_frame_invalid")
            value, present = _optional_i32(clocks[key])
            frame_values.append(value)
            frame_presence.append(present)
        for key in _FLAG_FIELDS:
            if key not in flags:
                _raise("model_public_frame_invalid")
            value, present = _optional_i32(flags[key])
            frame_values.append(value)
            frame_presence.append(present)
        for key in (
            "select_type_raw",
            "select_context_raw",
            "min_count",
            "max_count",
            "remain_damage_counter",
            "remain_energy_cost",
        ):
            if key not in semantics:
                _raise("model_public_frame_invalid")
            value, present = _optional_i32(semantics[key])
            frame_values.append(value)
            frame_presence.append(present)
        frame_values.append(len(options))
        frame_presence.append(1)
        while len(frame_values) < FRAME_WIDTH:
            frame_values.append(0)
            frame_presence.append(0)

        local_uids = {} if local_option_uids is None else dict(local_option_uids)
        allowed_uids = None if allowed_card_uids is None else frozenset(allowed_card_uids)
        if any(type(key) is not int or type(value) is not str for key, value in local_uids.items()):
            _raise("model_unknown_uid")
        rows: list[tuple[tuple[int, ...], tuple[int, ...], str, int]] = []
        for current_index, wrapper in enumerate(options):
            if type(wrapper) is not dict or set(wrapper) != {"index", "fingerprint", "raw"}:
                _raise("model_unknown_option_shape")
            if wrapper["index"] != current_index or type(wrapper["raw"]) is not dict:
                _raise("model_unknown_option_shape")
            raw = wrapper["raw"]
            option_type = raw.get("type")
            if type(option_type) is not int or option_type not in _OPTION_SHAPES:
                _raise("model_unknown_option_shape")
            if tuple(raw) != _OPTION_SHAPES[option_type]:
                _raise("model_unknown_option_shape")
            values: list[int] = []
            presence: list[int] = []
            for field in _OPTION_FIELDS:
                value, present = _optional_i32(raw.get(field)) if field in raw else (0, 0)
                if field == "cardId" and present and value <= 0:
                    _raise("model_unknown_uid")
                values.append(value)
                presence.append(present)
            uid = local_uids.get(current_index)
            if uid is not None:
                try:
                    uid.encode("ascii")
                except UnicodeEncodeError:
                    _raise("model_unknown_uid")
                if allowed_uids is None or uid not in allowed_uids:
                    _raise("model_unknown_uid")
                values.append(_uid_feature(uid))
                presence.append(1)
            else:
                values.append(0)
                presence.append(0)
            values.append(0)
            presence.append(0)
            semantic_payload = {"option": raw, "local_card_uid": uid}
            semantic_bytes = json.dumps(
                semantic_payload,
                ensure_ascii=True,
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            ).encode("ascii")
            semantic_key = hashlib.sha256(b"PTCGDAP\0MODEL_OPTION_V1\0" + semantic_bytes).hexdigest().upper()
            rows.append((tuple(values), tuple(presence), semantic_key, current_index))
        rows.sort(key=lambda row: (row[0], row[1], row[2], row[3]))

        option_values = [row[0] for row in rows]
        option_presence = [row[1] for row in rows]
        semantic_keys = [row[2] for row in rows]
        row_to_index = [row[3] for row in rows]
        option_mask = [1] * len(rows)
        while len(option_values) < MAX_OPTIONS:
            option_values.append((0,) * OPTION_WIDTH)
            option_presence.append((0,) * OPTION_WIDTH)
            option_mask.append(0)
        inverse = {current_index: row for row, current_index in enumerate(row_to_index)}
        return PublicActorTensors(
            profile_id=TENSOR_PROFILE_ID,
            frame_i32=tuple(frame_values),
            frame_presence_i32=tuple(frame_presence),
            option_i32=tuple(option_values),
            option_presence_i32=tuple(option_presence),
            option_mask_i32=tuple(option_mask),
            semantic_keys=tuple(semantic_keys),
            row_to_current_index=tuple(row_to_index),
            current_index_to_row=inverse,
            min_count=_i32(semantics["min_count"], "model_public_frame_invalid"),
            max_count=_i32(semantics["max_count"], "model_public_frame_invalid"),
        )


@dataclass(frozen=True, slots=True)
class ModelAdjudication:
    selected_indexes: tuple[int, ...]
    model_used: bool
    diagnostic_code: str


class ModelAdjudicator:
    __slots__ = ()

    @staticmethod
    def adjudicate(
        *,
        tensors: PublicActorTensors,
        rule_selected_indexes: Sequence[int],
        mandatory_indexes: Sequence[int],
        terminal_indexes: Sequence[int],
        base_hard_tiers: Sequence[Mapping[str, Any]],
        base_vetoed_indexes: Sequence[int],
        option_scores: Any,
        desired_count: Any,
    ) -> ModelAdjudication:
        fallback = tuple(rule_selected_indexes)
        if mandatory_indexes:
            return ModelAdjudication(fallback, False, "model_bypassed_mandatory")
        if terminal_indexes:
            return ModelAdjudication(fallback, False, "model_bypassed_terminal")
        if not fallback:
            return ModelAdjudication(fallback, False, "model_bypassed_empty_rule_result")
        if (
            type(option_scores) is not list
            or len(option_scores) != MAX_OPTIONS
            or any(type(score) is not int or not -(2**31) <= score < 2**31 for score in option_scores)
        ):
            return ModelAdjudication(fallback, False, "model_output_shape_invalid")
        if (
            type(desired_count) is not list
            or len(desired_count) != 1
            or type(desired_count[0]) is not int
        ):
            return ModelAdjudication(fallback, False, "model_output_shape_invalid")
        count = desired_count[0]
        if not tensors.min_count <= count <= tensors.max_count:
            return ModelAdjudication(fallback, False, "model_desired_count_invalid")
        try:
            tier_by_index = {
                entry["index"]: tuple(entry["tier"])
                for entry in base_hard_tiers
                if set(entry) == {"index", "tier"}
            }
            if set(tier_by_index) != set(tensors.current_index_to_row):
                raise ValueError
            rule_tier = tier_by_index[fallback[0]]
            if any(tier_by_index[index] != rule_tier for index in fallback):
                raise ValueError
            vetoed = set(base_vetoed_indexes)
            eligible = [
                index
                for index in tensors.row_to_current_index
                if index not in vetoed and tier_by_index[index] == rule_tier
            ]
        except (KeyError, TypeError, ValueError):
            return ModelAdjudication(fallback, False, "model_authority_input_invalid")
        if count > len(eligible):
            return ModelAdjudication(fallback, False, "model_desired_count_invalid")
        ranked = sorted(
            eligible,
            key=lambda index: (
                -option_scores[tensors.current_index_to_row[index]],
                tensors.semantic_keys[tensors.current_index_to_row[index]],
                index,
            ),
        )
        return ModelAdjudication(tuple(ranked[:count]), True, "")


__all__ = [
    "FRAME_WIDTH",
    "MAX_OPTIONS",
    "ModelActorError",
    "ModelAdjudication",
    "ModelAdjudicator",
    "OPTION_WIDTH",
    "PublicActorTensorizer",
    "PublicActorTensors",
    "TENSOR_PROFILE_ID",
]

