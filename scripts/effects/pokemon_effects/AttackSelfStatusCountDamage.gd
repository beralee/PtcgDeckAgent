class_name AttackSelfStatusCountDamage
extends BaseEffect

var damage_per_status: int = 100
var printed_base_damage: int = 100
var attack_index_to_match: int = -1


func _init(per_status: int = 100, printed_base: int = 100, match_attack_index: int = -1) -> void:
	damage_per_status = per_status
	printed_base_damage = printed_base
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	if attacker == null:
		return -printed_base_damage
	var status_count := 0
	for active: Variant in attacker.status_conditions.values():
		if bool(active):
			status_count += 1
	return status_count * damage_per_status - printed_base_damage


func get_description() -> String:
	return "This attack does %d damage for each Special Condition affecting this Pokemon." % damage_per_status

