class_name AbilityNoEnergyFreeRetreat
extends BaseEffect


func get_retreat_cost_modifier(slot: PokemonSlot, _state: GameState) -> int:
	if slot == null or slot.get_top_card() == null:
		return 0
	return -999 if slot.attached_energy.is_empty() else 0


func get_description() -> String:
	return "This Pokemon's Retreat Cost is zero while it has no Energy attached."
