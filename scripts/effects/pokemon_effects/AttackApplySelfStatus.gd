class_name AttackApplySelfStatus
extends BaseEffect

var status_name: String = "burned"
var attack_index_to_match: int = -1


func _init(status: String = "burned", match_attack_index: int = -1) -> void:
	status_name = status
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(attack_index):
		return
	_apply_special_status(attacker, status_name, state)


func get_description() -> String:
	return "This Pokemon is now %s." % status_name
