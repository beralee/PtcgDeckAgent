class_name AttackReduceDamageNextTurn
extends BaseEffect

var reduction_amount: int = 80
var attack_index_to_match: int = -1


func _init(amount: int = 80, match_attack_index: int = -1) -> void:
	reduction_amount = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	attacker.effects.append({
		"type": "reduce_damage_next_turn",
		"amount": reduction_amount,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "During your opponent's next turn, this Pokemon takes less damage."
