class_name AbilityMoveBasicEnergyToOwnPokemon
extends BaseEffect

const USED_FLAG_TYPE := "ability_move_basic_energy_to_own_pokemon_used"
const STEP_ID := "energy_assignment"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card() if pokemon != null else null
	if top == null or state == null:
		return false
	if top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if pokemon not in player.get_all_pokemon():
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	if player.get_all_pokemon().size() < 2:
		return false
	return _has_valid_source(player)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var all_pokemon := player.get_all_pokemon()

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	var source_groups: Array[Dictionary] = []
	for slot: PokemonSlot in all_pokemon:
		if slot == null:
			continue
		var group_indices: Array[int] = []
		for energy: CardInstance in slot.attached_energy:
			if not _is_basic_energy(energy):
				continue
			group_indices.append(energy_items.size())
			energy_items.append(energy)
			energy_labels.append(energy.card_data.name)
		if not group_indices.is_empty():
			source_groups.append({"slot": slot, "energy_indices": group_indices})
	if energy_items.is_empty():
		return []

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in all_pokemon:
		if slot == null:
			continue
		target_items.append(slot)
		target_labels.append(slot.get_pokemon_name())
	if target_items.size() < 2:
		return []

	var step := build_card_assignment_step(
		STEP_ID,
		"Choose 1 Basic Energy to move to another of your Pokemon",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		1,
		true
	)
	step["source_groups"] = source_groups
	step["source_exclude_targets"] = _build_source_exclude_targets(source_groups, target_items)
	step["compact_field_assignment_after_source"] = true
	step["field_assignment_require_confirm"] = true
	step["compact_field_assignment_title"] = "Happy Switch"
	return [step]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top := pokemon.get_top_card()
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments: Array = ctx.get(STEP_ID, [])
	if assignments.is_empty():
		return
	var assignment_raw: Variant = assignments[0]
	if not (assignment_raw is Dictionary):
		return
	var assignment: Dictionary = assignment_raw
	var source_raw: Variant = assignment.get("source")
	var target_raw: Variant = assignment.get("target")
	if not (source_raw is CardInstance) or not (target_raw is PokemonSlot):
		return
	var energy: CardInstance = source_raw as CardInstance
	var target: PokemonSlot = target_raw as PokemonSlot
	if not _is_basic_energy(energy):
		return
	if target not in player.get_all_pokemon():
		return
	var source := _find_slot_for_energy(player, energy)
	if source == null or source == target:
		return
	source.attached_energy.erase(energy)
	target.attached_energy.append(energy)
	pokemon.effects.append({
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number,
	})


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"


func _find_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and energy in slot.attached_energy:
			return slot
	return null


func _has_valid_source(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if _is_basic_energy(energy):
				return true
	return false


func _build_source_exclude_targets(source_groups: Array[Dictionary], target_items: Array) -> Dictionary:
	var exclude_map := {}
	for group: Dictionary in source_groups:
		var source_slot: PokemonSlot = group.get("slot")
		var source_target_index := target_items.find(source_slot)
		if source_target_index < 0:
			continue
		for energy_index: Variant in group.get("energy_indices", []):
			exclude_map[int(energy_index)] = [source_target_index]
	return exclude_map


func get_description() -> String:
	return "Once during your turn, move a Basic Energy from 1 of your Pokemon to another of your Pokemon."
