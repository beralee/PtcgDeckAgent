class_name AbilityDustField
extends BaseEffect

const EFFECT_ID := "ea9a967a89789870e4495d6b26f9c8a2"
const BENCH_LIMIT := 3


static func matches_effect_id(effect_id: String) -> bool:
	return effect_id == EFFECT_ID


static func is_active_source(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return matches_effect_id(str(slot.get_card_data().effect_id))


func get_description() -> String:
	return "只要这只宝可梦在战斗场上，对手的备战区上限变为3只。"
