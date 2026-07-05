class_name AbilityFroslassFreezingShroud
extends BaseEffect


func process_pokemon_check(
	_source: PokemonSlot,
	state: GameState,
	damaged_slots: Array[PokemonSlot]
) -> void:
	if state == null:
		return
	for pi: int in 2:
		for slot: PokemonSlot in state.players[pi].get_all_pokemon():
			if slot == null or _is_froslass(slot) or not _has_ability(slot):
				continue
			slot.damage_counters += 10
			if slot not in damaged_slots:
				damaged_slots.append(slot)


func _has_ability(slot: PokemonSlot) -> bool:
	var card_data := slot.get_card_data()
	return card_data != null and not card_data.abilities.is_empty()


func _is_froslass(slot: PokemonSlot) -> bool:
	var card_data := slot.get_card_data()
	if card_data == null:
		return false
	return str(card_data.name_en).to_lower() == "froslass"
