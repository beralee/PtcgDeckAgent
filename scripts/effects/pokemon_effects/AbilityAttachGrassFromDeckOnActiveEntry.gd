class_name AbilityAttachGrassFromDeckOnActiveEntry
extends "res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd"


func _init() -> void:
	super._init("G", 3, "self", false, true)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.current_player_index != owner_index:
		return false
	if state.players[owner_index].active_pokemon != pokemon:
		return false
	if not pokemon.entered_active_from_bench_this_turn(state.turn_number):
		return false
	return super.can_use_ability(pokemon, state)


func get_description() -> String:
	return "When this Pokemon moves from the Bench to the Active Spot, attach up to 3 Basic Grass Energy from your deck to it."
