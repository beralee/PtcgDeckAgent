class_name AbilityMoveFireEnergyFromBenchToActive
extends BaseEffect

const STEP_ID := "move_fire_energy_from_bench_to_active"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.current_player_index != owner_index:
		return false
	var player: PlayerState = state.players[owner_index]
	if not (pokemon in player.get_all_pokemon()):
		return false
	if player.active_pokemon == null:
		return false
	return not _movable_fire_energy(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var source_items := _movable_fire_energy(player)
	if source_items.is_empty():
		return []
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append("%s - %s" % [_energy_owner_name(player, energy), _energy_name(energy)])
	return [{
		"id": STEP_ID,
		"title": "选择备战宝可梦身上的1个火能量，转附给战斗宝可梦",
		"items": source_items,
		"labels": source_labels,
		"card_groups": build_attached_card_groups(player, source_items),
		"transparent_battlefield_dialog": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := pokemon.get_top_card().owner_index
	var player: PlayerState = state.players[owner_index]
	var active := player.active_pokemon
	if active == null:
		return
	var energy := _selected_energy(player, targets)
	if energy == null:
		energy = _movable_fire_energy(player)[0]
	var source := _source_slot_for_energy(player, energy)
	if source == null or source == active or not _is_fire_energy(energy):
		return
	source.attached_energy.erase(energy)
	active.attached_energy.append(energy)


func _selected_energy(player: PlayerState, targets: Array) -> CardInstance:
	var ctx := get_interaction_context(targets)
	var raw: Array = ctx.get(STEP_ID, [])
	if raw.is_empty():
		return null
	var entry: Variant = raw[0]
	if entry is CardInstance and _is_movable_from_bench(player, entry):
		return entry
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		var instance_id := int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
		for energy: CardInstance in _movable_fire_energy(player):
			if energy.instance_id == instance_id:
				return energy
	return null


func _movable_fire_energy(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if player == null:
		return result
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if _is_fire_energy(energy):
				result.append(energy)
	return result


func _is_movable_from_bench(player: PlayerState, energy: CardInstance) -> bool:
	var source := _source_slot_for_energy(player, energy)
	return source != null and source != player.active_pokemon


func _source_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	if player == null or energy == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and energy in slot.attached_energy:
			return slot
	return null


func _is_fire_energy(energy: CardInstance) -> bool:
	if energy == null or energy.card_data == null:
		return false
	var provides := str(energy.card_data.energy_provides)
	if provides.strip_edges() == "":
		provides = str(energy.card_data.energy_type)
	return provides == "R" or "R" in provides


func _energy_owner_name(player: PlayerState, energy: CardInstance) -> String:
	var source := _source_slot_for_energy(player, energy)
	return source.get_pokemon_name() if source != null else ""


func _energy_name(energy: CardInstance) -> String:
	if energy == null or energy.card_data == null:
		return ""
	return energy.card_data.name


func get_description() -> String:
	return "Move 1 Fire Energy from your Benched Pokemon to your Active Pokemon."
