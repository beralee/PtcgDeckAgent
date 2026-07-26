class_name AttackFailIfSelfDamageCounters
extends BaseEffect

var minimum_damage: int = 40
var attack_index_to_match: int = -1


func _init(damage_threshold: int = 40, match_attack_index: int = -1) -> void:
	minimum_damage = maxi(0, damage_threshold)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func cancels_attack_damage(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	_state: GameState
) -> bool:
	return attacker != null and applies_to_attack_index(attack_index) and attacker.damage_counters >= minimum_damage


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "This attack fails if this Pokemon has %d or more damage on it." % minimum_damage
