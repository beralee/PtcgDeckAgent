class_name EffectReversalEnergy
extends BaseEffect


func get_energy_type_for(energy: CardInstance, state: GameState) -> String:
	return "ANY" if _is_reversal_active(energy, state) else "C"


func get_energy_count_for(energy: CardInstance, state: GameState) -> int:
	return 3 if _is_reversal_active(energy, state) else 1


func get_description() -> String:
	return "Provides 1 Colorless Energy, or 3 Energy of any type while attached to an evolved non-rule-box Pokemon if its owner has more Prize cards remaining."


func _is_reversal_active(energy: CardInstance, state: GameState) -> bool:
	var attached_slot := _find_attached_slot(energy, state)
	if attached_slot == null:
		return false
	var card_data := attached_slot.get_card_data()
	if card_data == null:
		return false
	if not card_data.is_evolution_pokemon() or card_data.is_rule_box_pokemon():
		return false
	var owner_index := _slot_owner_index(attached_slot)
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	return state.players[owner_index].prizes.size() > state.players[opponent_index].prizes.size()


func _find_attached_slot(energy: CardInstance, state: GameState) -> PokemonSlot:
	if energy == null or state == null:
		return null
	for player: PlayerState in state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot != null and energy in slot.attached_energy:
				return slot
	return null


func _slot_owner_index(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return int(slot.get_top_card().owner_index)
