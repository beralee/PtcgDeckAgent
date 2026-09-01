class_name PokemonEvolutionEntryRestriction
extends RefCounted

const PALAFIN_EX_HERO_SPIRIT_EFFECT_ID := "1b97f4552b78e850d48100edf4d82c95"
const PALAFIN_ZERO_TO_HERO_ROUTE := "palafin_zero_to_hero"


static func allows(card_data: CardData, route: String) -> bool:
	if card_data == null:
		return false
	if card_data.effect_id != PALAFIN_EX_HERO_SPIRIT_EFFECT_ID:
		return true
	return route == PALAFIN_ZERO_TO_HERO_ROUTE
