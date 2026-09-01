from __future__ import annotations

import copy
from typing import Any, Mapping


class A3OperationContractError(RuntimeError):
    pass


def operation_input_projection(checkpoint: Any) -> dict[str, Any]:
    """Project engine-specific current-window input to the private-ID bridge IR.

    This is not an official raw callback. It is the narrow correspondence
    surface used to prove that the same card operation exposes the same select
    header and ordered semantic frontier while retaining each raw callback as
    separate evidence.
    """
    raw = checkpoint.raw_actor_observation
    select = checkpoint.select
    if checkpoint.kind != "SELECTION" or type(raw) is not dict or type(select) is not dict:
        raise A3OperationContractError("a3_operation_checkpoint_invalid")
    if checkpoint.acting_seat not in (0, 1):
        raise A3OperationContractError("a3_operation_acting_seat_invalid")
    _validate_select_header(select, len(checkpoint.ordered_options))
    header = {
        key: copy.deepcopy(select.get(key))
        for key in (
            "type", "context", "minCount", "maxCount",
            "remainDamageCounter", "remainEnergyCost",
        )
    }
    if checkpoint.source_lane == "godot_private":
        options = [_private_option(option) for option in checkpoint.ordered_options]
        source = "godot_private_current_window"
    elif checkpoint.source_lane == "official_native":
        current = raw.get("current")
        if type(current) is not dict:
            raise A3OperationContractError("a3_operation_official_current_invalid")
        options = [
            _official_option(option, select, current, checkpoint.acting_seat)
            for option in checkpoint.ordered_options
        ]
        source = "official_native_current_window"
    else:
        raise A3OperationContractError("a3_operation_source_lane_invalid")
    return {
        "profile": "ptcgdap_corresponding_card_operation_input_v1",
        "acting_seat": checkpoint.acting_seat,
        "select_header": header,
        "ordered_semantic_options": options,
        "source": source,
    }


def comparable_operation_projection(checkpoint: Any) -> dict[str, Any]:
    value = operation_input_projection(checkpoint)
    value.pop("source", None)
    return value


def _official_entity(card: Any) -> dict[str, Any]:
    if type(card) is not dict:
        raise A3OperationContractError("a3_operation_entity_unavailable")
    card_id = card.get("id")
    serial = card.get("serial")
    if type(card_id) is not int or card_id <= 0 or type(serial) is not int or serial <= 0:
        raise A3OperationContractError("a3_operation_entity_unavailable")
    return {"cardId": card_id, "serial": serial}


def _private_entity(option: Mapping[str, Any], prefix: str) -> dict[str, Any]:
    card_id = option.get(f"{prefix}_uid")
    serial = option.get(f"{prefix}_serial")
    if type(card_id) is not str or not card_id or type(serial) is not int or serial <= 0:
        raise A3OperationContractError("a3_operation_entity_unavailable")
    return {"cardId": card_id, "serial": serial}


def _private_option(option: Mapping[str, Any]) -> dict[str, Any]:
    if type(option) is not dict or type(option.get("option_type_raw")) is not int:
        raise A3OperationContractError("a3_operation_private_option_invalid")
    option_type = option["option_type_raw"]
    if option_type < 0 or option_type > 16:
        raise A3OperationContractError("a3_operation_option_type_unsupported")
    result: dict[str, Any] = {"type": option_type}
    if option_type == 0:
        number = option.get("option_number")
        if type(number) is not int or number < 0:
            raise A3OperationContractError("a3_operation_private_option_invalid")
        result["number"] = number
    elif option_type == 3:
        if option.get("card_uid") is None and option.get("card_serial") is None:
            result["position"] = _private_position(option)
        else:
            result["entity"] = _private_entity(option, "card")
    elif option_type in (4, 5, 7, 11):
        result["entity"] = _private_entity(option, "card")
    elif option_type in (8, 9):
        result["source"] = _private_entity(option, "card")
        result["target"] = _private_entity(option, "target")
    elif option_type == 10:
        result["source"] = _private_entity(option, "source")
    elif option_type == 6:
        result["source"] = _private_entity(option, "source")
        result["energyType"] = _required_private_int(option, "energy_type_raw")
        count = _required_private_int(option, "energy_count")
        if count <= 0:
            raise A3OperationContractError("a3_operation_private_option_invalid")
        result["count"] = count
    elif option_type == 13:
        source_uid = option.get("source_uid")
        attack_index = option.get("attack_index")
        if (
            type(source_uid) is not str or not source_uid
            or type(attack_index) is not int or attack_index < 0
        ):
            raise A3OperationContractError("a3_operation_attack_unavailable")
        result["attackId"] = f"{source_uid}:attack:{attack_index}"
    elif option_type == 15:
        if option.get("card_uid") is None:
            result.update({"cardId": 0, "serial": 0})
        else:
            result.update(_private_entity(option, "card"))
    elif option_type == 16:
        condition = option.get("special_condition_type")
        if type(condition) is not int or condition < 0 or condition > 4:
            raise A3OperationContractError("a3_operation_private_option_invalid")
        result["specialConditionType"] = condition
    elif option_type not in (1, 2, 12, 14):
        raise A3OperationContractError("a3_operation_option_type_unsupported")
    return result


def _official_option(
    option: Mapping[str, Any],
    select: Mapping[str, Any],
    current: Mapping[str, Any],
    acting_seat: int | None,
) -> dict[str, Any]:
    if type(option) is not dict or type(option.get("type")) is not int:
        raise A3OperationContractError("a3_operation_official_option_invalid")
    option_type = option["type"]
    if option_type < 0 or option_type > 16:
        raise A3OperationContractError("a3_operation_option_type_unsupported")
    result: dict[str, Any] = {"type": option_type}
    if option_type == 0:
        result["number"] = _required_nonnegative_int(option, "number")
    elif option_type == 3:
        player_index = _required_int(option, "playerIndex")
        area = _required_int(option, "area")
        area_index = _required_int(option, "index")
        if area == 6:
            result["position"] = {
                "area": area,
                "index": area_index,
                "playerIndex": player_index,
            }
        else:
            result["entity"] = _official_entity(_official_area_entity(
                current, select, player_index, area, area_index,
            ))
    elif option_type == 7:
        if acting_seat not in (0, 1):
            raise A3OperationContractError("a3_operation_official_option_invalid")
        result["entity"] = _official_entity(_official_area_entity(
            current, select, int(acting_seat), 2, _required_int(option, "index")
        ))
    elif option_type in (8, 9):
        if acting_seat not in (0, 1):
            raise A3OperationContractError("a3_operation_official_option_invalid")
        result["source"] = _official_entity(_official_area_entity(
            current, select, int(acting_seat),
            _required_int(option, "area"), _required_int(option, "index"),
        ))
        result["target"] = _official_entity(_official_area_entity(
            current, select, int(acting_seat),
            _required_int(option, "inPlayArea"), _required_int(option, "inPlayIndex"),
        ))
    elif option_type in (4, 5, 6):
        pokemon = _official_area_entity(
            current, select, _required_int(option, "playerIndex"),
            _required_int(option, "area"), _required_int(option, "index"),
        )
        if option_type == 4:
            result["entity"] = _official_entity(_indexed_card(
                pokemon, "tools", _required_int(option, "toolIndex")
            ))
        elif option_type == 5:
            result["entity"] = _official_entity(_indexed_card(
                pokemon, "energyCards", _required_int(option, "energyIndex")
            ))
        else:
            result["source"] = _official_entity(pokemon)
            result["energyType"] = _indexed_int(
                pokemon, "energies", _required_int(option, "energyIndex")
            )
            result["count"] = _required_positive_int(option, "count")
    elif option_type in (10, 11):
        if acting_seat not in (0, 1):
            raise A3OperationContractError("a3_operation_official_option_invalid")
        entity = _official_entity(_official_area_entity(
            current, select, int(acting_seat),
            _required_int(option, "area"), _required_int(option, "index"),
        ))
        result["source" if option_type == 10 else "entity"] = entity
    elif option_type == 13:
        result["attackId"] = _required_positive_int(option, "attackId")
    elif option_type == 15:
        card_id = _required_nonnegative_int(option, "cardId")
        serial = _required_nonnegative_int(option, "serial")
        if (card_id == 0) != (serial == 0):
            raise A3OperationContractError("a3_operation_official_option_invalid")
        result["cardId"] = card_id
        result["serial"] = serial
    elif option_type == 16:
        condition = _required_nonnegative_int(option, "specialConditionType")
        if condition > 4:
            raise A3OperationContractError("a3_operation_official_option_invalid")
        result["specialConditionType"] = condition
    elif option_type not in (1, 2, 12, 14):
        raise A3OperationContractError("a3_operation_option_type_unsupported")
    return result


def _official_area_entity(
    current: Mapping[str, Any],
    select: Mapping[str, Any],
    player_index: int,
    area: int,
    index: int,
) -> Mapping[str, Any]:
    players = current.get("players")
    if type(players) is not list or player_index not in (0, 1) or len(players) != 2:
        raise A3OperationContractError("a3_operation_official_current_invalid")
    player = players[player_index]
    if type(player) is not dict or index < 0:
        raise A3OperationContractError("a3_operation_entity_unavailable")
    if area == 1:
        cards = select.get("deck")
    elif area == 2:
        cards = player.get("hand")
    elif area == 3:
        cards = player.get("discard")
    elif area == 4:
        cards = player.get("active")
    elif area == 5:
        cards = player.get("bench")
    elif area == 7:
        cards = current.get("stadium")
    else:
        raise A3OperationContractError("a3_operation_area_unsupported")
    if type(cards) is not list or index >= len(cards):
        raise A3OperationContractError("a3_operation_entity_unavailable")
    value = cards[index]
    if area in (4, 5):
        if type(value) is not dict:
            raise A3OperationContractError("a3_operation_entity_unavailable")
        # The source-locked official runtime exposes the current top Pokémon
        # directly. Compatibility wrappers are rejected instead of guessed.
        if type(value.get("id")) is not int or type(value.get("serial")) is not int:
            raise A3OperationContractError("a3_operation_entity_unavailable")
    return value


def _required_int(value: Mapping[str, Any], key: str) -> int:
    result = value.get(key)
    if type(result) is not int:
        raise A3OperationContractError("a3_operation_official_option_invalid")
    return result


def _required_nonnegative_int(value: Mapping[str, Any], key: str) -> int:
    result = _required_int(value, key)
    if result < 0:
        raise A3OperationContractError("a3_operation_official_option_invalid")
    return result


def _required_positive_int(value: Mapping[str, Any], key: str) -> int:
    result = _required_int(value, key)
    if result <= 0:
        raise A3OperationContractError("a3_operation_official_option_invalid")
    return result


def _required_private_int(value: Mapping[str, Any], key: str) -> int:
    result = value.get(key)
    if type(result) is not int or result < 0:
        raise A3OperationContractError("a3_operation_private_option_invalid")
    return result


def _private_position(option: Mapping[str, Any]) -> dict[str, int]:
    area = _required_private_int(option, "option_area_raw")
    index = _required_private_int(option, "option_area_index")
    player_index = _required_private_int(option, "option_player_index")
    if area > 11 or player_index not in (0, 1):
        raise A3OperationContractError("a3_operation_private_option_invalid")
    return {"area": area, "index": index, "playerIndex": player_index}


def _validate_select_header(select: Mapping[str, Any], option_count: int) -> None:
    select_type = select.get("type")
    context = select.get("context")
    minimum = select.get("minCount")
    maximum = select.get("maxCount")
    remaining_damage = select.get("remainDamageCounter")
    remaining_energy = select.get("remainEnergyCost")
    if (
        type(select_type) is not int or select_type < 0 or select_type > 10
        or type(context) is not int or context < 0 or context > 48
        or type(minimum) is not int or minimum < 0
        or type(maximum) is not int or maximum < minimum or maximum > option_count
        or type(remaining_damage) is not int or remaining_damage < 0
        or type(remaining_energy) is not int or remaining_energy < 0
    ):
        raise A3OperationContractError("a3_operation_select_header_invalid")


def _indexed_card(value: Mapping[str, Any], key: str, index: int) -> Mapping[str, Any]:
    cards = value.get(key)
    if type(cards) is not list or index < 0 or index >= len(cards):
        raise A3OperationContractError("a3_operation_entity_unavailable")
    card = cards[index]
    if type(card) is not dict:
        raise A3OperationContractError("a3_operation_entity_unavailable")
    return card


def _indexed_int(value: Mapping[str, Any], key: str, index: int) -> int:
    values = value.get(key)
    if type(values) is not list or index < 0 or index >= len(values):
        raise A3OperationContractError("a3_operation_entity_unavailable")
    result = values[index]
    if type(result) is not int:
        raise A3OperationContractError("a3_operation_entity_unavailable")
    return result


__all__ = [
    "A3OperationContractError", "comparable_operation_projection",
    "operation_input_projection",
]
