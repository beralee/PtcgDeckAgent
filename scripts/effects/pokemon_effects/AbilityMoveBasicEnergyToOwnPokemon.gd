class_name AbilityMoveBasicEnergyToOwnPokemon
extends BaseEffect

const STEP_ID := "energy_assignment"
const USED_FLAG_TYPE := "ability_move_basic_energy_to_own_pokemon_used"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	if state.players[top.owner_index].get_all_pokemon().size() < 2:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	return _has_basic_energy_source(state.players[top.owner_index])


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var all_pokemon: Array = player.get_all_pokemon()
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	var source_groups: Array[Dictionary] = []

	for slot: PokemonSlot in all_pokemon:
		var group_indices: Array[int] = []
		for energy: CardInstance in slot.attached_energy:
			if energy.card_data != null and energy.card_data.card_type == "Basic Energy":
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
		target_items.append(slot)
		target_labels.append(slot.get_pokemon_name())

	var exclude_map: Dictionary = {}
	for group: Dictionary in source_groups:
		var slot: PokemonSlot = group.get("slot")
		var target_idx: int = target_items.find(slot)
		if target_idx < 0:
			continue
		for entry: Variant in group.get("energy_indices", []):
			exclude_map[int(entry)] = [target_idx]

	var step: Dictionary = build_card_assignment_step(
		STEP_ID,
		"Choose 1 Basic Energy to move and another Pokemon to receive it",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		1,
		true
	)
	step["source_groups"] = source_groups
	step["source_exclude_targets"] = exclude_map
	return [step]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments: Array = ctx.get(STEP_ID, [])
	if assignments.is_empty() or not (assignments[0] is Dictionary):
		return

	var assignment: Dictionary = assignments[0]
	var chosen_energy: Variant = assignment.get("source")
	var target_slot: Variant = assignment.get("target")
	if not (chosen_energy is CardInstance) or not (target_slot is PokemonSlot):
		return

	var energy: CardInstance = chosen_energy as CardInstance
	var target: PokemonSlot = target_slot as PokemonSlot
	if energy.card_data == null or energy.card_data.card_type != "Basic Energy":
		return
	if target not in player.get_all_pokemon():
		return

	var source: PokemonSlot = _find_slot_for_energy(player, energy)
	if source == null or source == target:
		return

	source.attached_energy.erase(energy)
	target.attached_energy.append(energy)
	pokemon.effects.append({
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number,
	})


func _has_basic_energy_source(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if energy.card_data != null and energy.card_data.card_type == "Basic Energy":
				return true
	return false


func _find_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if energy in slot.attached_energy:
			return slot
	return null
