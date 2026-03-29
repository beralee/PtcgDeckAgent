class_name AbilityPreventDamageFromBasicEx
extends BaseEffect

const EFFECT_ID := "fd252ce877c709e9e3161c56ef98aff8"


func prevents_damage_from(attacker: PokemonSlot, _defender: PokemonSlot, _state: GameState) -> bool:
	return _is_basic_ex(attacker)


static func prevents_target_damage(attacker: PokemonSlot, target: PokemonSlot, _state: GameState) -> bool:
	if target == null:
		return false
	var target_data: CardData = target.get_card_data()
	if target_data == null or target_data.effect_id != EFFECT_ID:
		return false
	return _is_basic_ex(attacker)


static func _is_basic_ex(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var attacker_data: CardData = slot.get_card_data()
	return attacker_data != null and attacker_data.stage == "Basic" and attacker_data.mechanic == "ex"
