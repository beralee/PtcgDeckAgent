class_name AttackSelfSleep
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	_apply_special_status(attacker, "asleep", state)


func get_description() -> String:
	return "This Pokemon becomes Asleep after using the attack."
