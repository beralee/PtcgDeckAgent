class_name EffectNeoUpperEnergy
extends BaseEffect


func get_energy_type_for(energy: CardInstance, state: GameState) -> String:
	return "ANY" if _is_attached_to_stage2(energy, state) else "C"


func get_energy_count_for(energy: CardInstance, state: GameState) -> int:
	return 2 if _is_attached_to_stage2(energy, state) else 1


func get_description() -> String:
	return "Provides 1 Colorless Energy, or 2 Energy of any type while attached to a Stage 2 Pokemon."


func _is_attached_to_stage2(energy: CardInstance, state: GameState) -> bool:
	var attached_slot := _find_attached_slot(energy, state)
	if attached_slot == null:
		return false
	var card_data := attached_slot.get_card_data()
	return card_data != null and card_data.stage == "Stage 2"


func _find_attached_slot(energy: CardInstance, state: GameState) -> PokemonSlot:
	if energy == null or state == null:
		return null
	for player: PlayerState in state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot != null and energy in slot.attached_energy:
				return slot
	return null
