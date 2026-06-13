class_name AttackSelfDamageCounterBonus
extends BaseEffect

var damage_per_counter: int = 10
var attack_index_to_match: int = -1


func _init(per_counter: int = 10, match_attack_index: int = -1) -> void:
	damage_per_counter = max(0, per_counter)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	if attacker == null:
		return 0
	var counter_count := int(attacker.damage_counters / 10)
	return counter_count * damage_per_counter


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "This attack does extra damage for each damage counter on this Pokemon."
