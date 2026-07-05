class_name AbilityExplodingNeedles
extends BaseEffect

var counter_count: int = 6


func _init(count: int = 6) -> void:
	counter_count = count


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func on_knocked_out_by_attack_damage(source: PokemonSlot, attacker: PokemonSlot, state: GameState) -> void:
	if source == null or attacker == null or state == null:
		return
	var source_owner := _owner_index_for_slot(source, state)
	var attacker_owner := _owner_index_for_slot(attacker, state)
	if source_owner < 0 or attacker_owner != 1 - source_owner:
		return
	if state.players[source_owner].active_pokemon != source:
		return
	attacker.damage_counters += counter_count * 10


func _owner_index_for_slot(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return -1
	for player_index: int in state.players.size():
		if slot in state.players[player_index].get_all_pokemon():
			return player_index
	return -1


func get_description() -> String:
	return "When this Active Pokemon is Knocked Out by attack damage, put damage counters on the Attacking Pokemon."
