class_name EffectPowerglass
extends BaseEffect

const EFFECT_ID := "1dc38c46be0951b2b135e1df2e5e7767"
const STEP_ID := "powerglass_energy"
const RESOLVED_FLAG := "_powerglass_resolved_slot_ids"


func discard_at_end_of_turn(slot: PokemonSlot, state: GameState) -> bool:
	if not can_trigger_end_turn(slot, state):
		return false
	if _is_resolved_this_turn(slot, state):
		return false
	var owner_index: int = slot.get_top_card().owner_index
	var energy: CardInstance = _first_basic_energy(state.players[owner_index])
	if energy == null:
		return false
	_attach_energy(slot, state.players[owner_index], energy)
	return false


func can_trigger_end_turn(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null or slot.get_top_card() == null:
		return false
	var owner_index: int = slot.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.current_player_index != owner_index:
		return false
	if state.players[owner_index].active_pokemon != slot:
		return false
	if _is_tool_suppressed(slot, state):
		return false
	return not _basic_energy_choices(state.players[owner_index]).is_empty()


func get_end_turn_interaction_steps(slot: PokemonSlot, state: GameState) -> Array[Dictionary]:
	if not can_trigger_end_turn(slot, state):
		return []
	if _is_resolved_this_turn(slot, state):
		return []
	var owner_index: int = slot.get_top_card().owner_index
	var energies: Array[CardInstance] = _basic_energy_choices(state.players[owner_index])
	var labels: Array[String] = []
	for energy: CardInstance in energies:
		labels.append(energy.card_data.name if energy != null and energy.card_data != null else "")
	return [{
		"id": STEP_ID,
		"title": "Powerglass: choose 1 Basic Energy from discard",
		"items": energies,
		"labels": labels,
		"presentation": "cards",
		"card_items": energies,
		"choice_labels": labels,
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
		"cancel_resolves_empty": true,
		"force_confirm": true,
		"prompt_type": "powerglass_end_turn",
		"pokemon_card": slot.get_top_card(),
	}]


func resolve_end_turn_choice(slot: PokemonSlot, targets: Array, state: GameState) -> CardInstance:
	if slot == null or state == null or slot.get_top_card() == null:
		return null
	_mark_resolved_this_turn(slot, state)
	if not can_trigger_end_turn(slot, state):
		return null
	var owner_index: int = slot.get_top_card().owner_index
	var selected_energy: CardInstance = _selected_basic_energy(state.players[owner_index], targets)
	if selected_energy == null:
		return null
	_attach_energy(slot, state.players[owner_index], selected_energy)
	return selected_energy


func _first_basic_energy(player: PlayerState) -> CardInstance:
	var choices: Array[CardInstance] = _basic_energy_choices(player)
	return choices[0] if not choices.is_empty() else null


func _basic_energy_choices(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if player == null:
		return result
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			result.append(card)
	return result


func _selected_basic_energy(player: PlayerState, targets: Array) -> CardInstance:
	if player == null:
		return null
	var context := get_interaction_context(targets)
	var selected_raw: Array = context.get(STEP_ID, [])
	if selected_raw.is_empty():
		return null
	for item: Variant in selected_raw:
		if item is CardInstance and item in player.discard_pile:
			var card := item as CardInstance
			if card.card_data != null and card.card_data.card_type == "Basic Energy":
				return card
	return null


func _attach_energy(slot: PokemonSlot, player: PlayerState, energy: CardInstance) -> void:
	if slot == null or player == null or energy == null:
		return
	if not (energy in player.discard_pile):
		return
	player.discard_pile.erase(energy)
	energy.face_up = true
	slot.attached_energy.append(energy)


func _is_resolved_this_turn(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	var resolved: Dictionary = state.shared_turn_flags.get(RESOLVED_FLAG, {})
	var resolved_turn: Variant = resolved.get(int(slot.get_instance_id()), null)
	return resolved_turn is int and int(resolved_turn) == state.turn_number


func _mark_resolved_this_turn(slot: PokemonSlot, state: GameState) -> void:
	if slot == null or state == null:
		return
	var resolved: Dictionary = state.shared_turn_flags.get(RESOLVED_FLAG, {})
	resolved[int(slot.get_instance_id())] = state.turn_number
	state.shared_turn_flags[RESOLVED_FLAG] = resolved


func _is_tool_suppressed(slot: PokemonSlot, state: GameState) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_tool_effect_suppressed"):
		return bool(processor.call("is_tool_effect_suppressed", slot, state))
	return false


func get_description() -> String:
	return "At the end of your turn, if the Pokemon this card is attached to is in the Active Spot, you may attach 1 Basic Energy from your discard pile to it."
