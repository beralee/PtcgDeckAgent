class_name AbilityOpponentDragonWeaknessToPsychic
extends BaseEffect


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_weakness_energy_override_for_target(source: PokemonSlot, target: PokemonSlot, state: GameState) -> String:
	return "P" if _applies_to_target(source, target, state) else ""


func get_weakness_value_override_for_target(source: PokemonSlot, target: PokemonSlot, state: GameState) -> String:
	return "x2" if _applies_to_target(source, target, state) else ""


func _applies_to_target(source: PokemonSlot, target: PokemonSlot, state: GameState) -> bool:
	if source == null or target == null or state == null:
		return false
	var source_owner := _owner_index_for_slot(source, state)
	var target_owner := _owner_index_for_slot(target, state)
	if source_owner < 0 or target_owner != 1 - source_owner:
		return false
	var target_data := target.get_card_data()
	if target_data == null or not target_data.is_pokemon():
		return false
	return target_data.energy_type == "N"


func _owner_index_for_slot(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return -1
	for player_index: int in state.players.size():
		if slot in state.players[player_index].get_all_pokemon():
			return player_index
	return -1


func get_description() -> String:
	return "Opponent Dragon Pokemon in play have Psychic Weakness."
