class_name AbilityOpponentBenchColorlessReduction
extends BaseEffect


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func is_cost_modifier_ability() -> bool:
	return true


func get_attack_colorless_cost_modifier(
	pokemon: PokemonSlot,
	attack: Dictionary,
	state: GameState
) -> int:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return 0
	var owner_index := pokemon.get_top_card().owner_index
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var colorless_count := 0
	var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
	for symbol: String in cost:
		if symbol == "C":
			colorless_count += 1
	return -mini(state.players[opponent_index].bench.size(), colorless_count)
