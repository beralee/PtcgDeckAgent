class_name AbilityPoisonOpponentActiveIfStadium
extends BaseEffect


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.current_player_index != owner_index or pokemon.has_ability_used(state.turn_number):
		return false
	if state.stadium_card == null:
		return false
	return state.players[1 - owner_index].active_pokemon != null


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := pokemon.get_top_card().owner_index
	_apply_special_status(state.players[1 - owner_index].active_pokemon, "poisoned", state)
	pokemon.mark_ability_used(state.turn_number)


func get_description() -> String:
	return "Once during your turn, if a Stadium is in play, your opponent's Active Pokemon is now Poisoned."
