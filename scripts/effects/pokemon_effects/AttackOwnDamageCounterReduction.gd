class_name AttackOwnDamageCounterReduction
extends BaseEffect

var damage_reduction_per_counter: int = 20
var attack_index_to_match: int = -1


func _init(per_counter: int = 20, match_attack_index: int = -1) -> void:
	damage_reduction_per_counter = per_counter
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	if attacker == null:
		return 0
	return -((attacker.damage_counters / 10) * damage_reduction_per_counter)


func get_description() -> String:
	return "This attack does less damage for each damage counter on this Pokemon."
