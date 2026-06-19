class_name AIDecisionTrace
extends RefCounted

var turn_number: int = -1
var phase: String = ""
var player_index: int = -1
var state_features: Array = []
var legal_actions: Array = []
var scored_actions: Array = []
var chosen_action: Dictionary = {}
var reason_tags: Array = []
var used_mcts: bool = false
var runtime_mode: String = ""
var turn_contract: Dictionary = {}


func clone():
	var copy: Object = get_script().new()
	copy.turn_number = turn_number
	copy.phase = phase
	copy.player_index = player_index
	copy.state_features = _freeze_array(state_features)
	copy.legal_actions = _freeze_array(legal_actions)
	copy.scored_actions = _freeze_array(scored_actions)
	copy.chosen_action = _freeze_dictionary(chosen_action)
	copy.reason_tags = _freeze_array(reason_tags)
	copy.used_mcts = used_mcts
	copy.runtime_mode = runtime_mode
	copy.turn_contract = _freeze_dictionary(turn_contract)
	return copy


func to_dictionary() -> Dictionary:
	return {
		"turn_number": turn_number,
		"phase": phase,
		"player_index": player_index,
		"state_features": _freeze_array(state_features),
		"legal_actions": _freeze_array(legal_actions),
		"scored_actions": _freeze_array(scored_actions),
		"chosen_action": _freeze_dictionary(chosen_action),
		"reason_tags": _freeze_array(reason_tags),
		"used_mcts": used_mcts,
		"runtime_mode": runtime_mode,
		"turn_contract": _freeze_dictionary(turn_contract),
	}


func _freeze_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return _freeze_dictionary(value)
	if value is Array:
		return _freeze_array(value)
	if value is CardInstance:
		return _snapshot_card_instance(value as CardInstance)
	if value is PokemonSlot:
		return _snapshot_pokemon_slot(value as PokemonSlot)
	if value is CardData:
		return _snapshot_card_data(value as CardData)
	if value is Object:
		return str(value)
	return value


func _freeze_dictionary(values: Dictionary) -> Dictionary:
	var frozen := {}
	for key: Variant in values.keys():
		frozen[key] = _freeze_variant(values.get(key))
	return frozen


func _freeze_array(values: Array) -> Array:
	var frozen: Array = []
	for value: Variant in values:
		frozen.append(_freeze_variant(value))
	return frozen


func _snapshot_card_instance(card: CardInstance) -> Dictionary:
	var snapshot := {
		"trace_ref_type": "card",
		"instance_id": int(card.instance_id),
		"owner_index": int(card.owner_index),
		"face_up": bool(card.face_up),
	}
	if card.card_data != null:
		snapshot.merge(_snapshot_card_data(card.card_data), true)
	snapshot["trace_ref_type"] = "card"
	return snapshot


func _snapshot_card_data(card_data: CardData) -> Dictionary:
	return {
		"trace_ref_type": "card_data",
		"name": str(card_data.name),
		"name_en": str(card_data.name_en),
		"card_type": str(card_data.card_type),
		"set_code": str(card_data.set_code),
		"card_index": str(card_data.card_index),
		"stage": str(card_data.stage),
		"hp": int(card_data.hp),
	}


func _snapshot_pokemon_slot(slot: PokemonSlot) -> Dictionary:
	var data := slot.get_card_data()
	var top_card := slot.get_top_card()
	var snapshot := {
		"trace_ref_type": "pokemon_slot",
		"pokemon_name": str(slot.get_pokemon_name()),
		"name": str(slot.get_pokemon_name()),
		"remaining_hp": int(slot.get_remaining_hp()),
		"max_hp": int(slot.get_max_hp()),
		"damage_counters": int(slot.damage_counters),
		"knocked_out": bool(slot.is_knocked_out()),
		"energy_count": int(slot.get_total_energy_count()),
		"retreat_cost": int(slot.get_retreat_cost()),
		"status_conditions": _freeze_dictionary(slot.status_conditions),
		"owner_index": int(top_card.owner_index) if top_card != null else -1,
	}
	if data != null:
		snapshot["name_en"] = str(data.name_en)
		snapshot["card_type"] = str(data.card_type)
		snapshot["set_code"] = str(data.set_code)
		snapshot["card_index"] = str(data.card_index)
		snapshot["stage"] = str(data.stage)
	var energy_names: Array = []
	for energy: CardInstance in slot.attached_energy:
		energy_names.append(energy.get_name())
	snapshot["attached_energy_names"] = energy_names
	if slot.attached_tool != null:
		snapshot["attached_tool_name"] = slot.attached_tool.get_name()
	else:
		snapshot["attached_tool_name"] = ""
	return snapshot
