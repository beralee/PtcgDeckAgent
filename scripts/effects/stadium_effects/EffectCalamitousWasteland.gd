class_name EffectCalamitousWasteland
extends BaseEffect


func get_retreat_cost_modifier(slot: PokemonSlot, _state: GameState) -> int:
	if slot == null:
		return 0
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return 0
	if cd.stage != "Basic":
		return 0
	return 0 if cd.energy_type == "F" else 1


func get_description() -> String:
	return "Each Basic Pokemon in play, except Fighting Pokemon, has 1 more retreat cost."
