class_name AbilityPokemonCheckHealAllOwn
extends BaseEffect

var heal_amount: int = 20


func _init(amount: int = 20) -> void:
	heal_amount = amount


func process_pokemon_check(
	source: PokemonSlot,
	state: GameState,
	_damaged_slots: Array[PokemonSlot]
) -> void:
	if source == null or source.get_top_card() == null or state == null:
		return
	var owner_index := source.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return
	for slot: PokemonSlot in state.players[owner_index].get_all_pokemon():
		if slot != null and slot.damage_counters > 0:
			slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)


func get_description() -> String:
	return "During Pokemon Checkup, heal damage from each of your Pokemon."
