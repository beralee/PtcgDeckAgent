class_name AttackPlaceDamageCountersOnOpponentActive
extends BaseEffect

const AbilityIgnoreEffects = preload("res://scripts/effects/pokemon_effects/AbilityIgnoreEffects.gd")

var damage_amount: int = 70


func _init(amount: int = 70) -> void:
	damage_amount = amount


func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if attacker == null or defender == null:
		return
	if state != null and state.shared_turn_flags.get("_draw_effect_processor", null) != null:
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		if processor != null and processor.has_method("has_mist_energy_protection") and bool(processor.call("has_mist_energy_protection", defender, state)):
			return
	if AbilityIgnoreEffects.has_ignore_effects(defender):
		return
	defender.damage_counters += damage_amount
	_mark_attack_damage_counter_placement(defender, state)


func get_description() -> String:
	return "给对手的战斗宝可梦身上放置伤害指示物。"
