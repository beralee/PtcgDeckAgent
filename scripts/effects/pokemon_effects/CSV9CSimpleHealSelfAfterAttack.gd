class_name CSV9CSimpleHealSelfAfterAttack
extends BaseEffect

var heal_amount: int = 30
var attack_index_to_match: int = -1


func _init(amount: int = 30, match_attack_index: int = -1) -> void:
	heal_amount = max(0, amount)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	_state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(attack_index):
		return
	attacker.damage_counters = maxi(0, attacker.damage_counters - heal_amount)


func get_description() -> String:
	return "Heal damage from this Pokemon after attacking."
