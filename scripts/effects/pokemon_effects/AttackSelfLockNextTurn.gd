class_name AttackSelfLockNextTurn
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	attacker.effects.append({
		"type": "attack_lock",
		"attack_name": _get_attack_name(attacker, attack_index),
		"attack_index": attack_index,
		"turn": state.turn_number,
	})


func _get_attack_name(slot: PokemonSlot, index: int) -> String:
	if slot == null:
		return ""
	var attacks: Array = slot.get_attacks()
	if attacks.is_empty() or index < 0 or index >= attacks.size():
		return ""
	var atk: Variant = attacks[index]
	if atk is Dictionary:
		return str((atk as Dictionary).get("name", ""))
	return ""


func get_description() -> String:
	return "After using this attack, this Pokemon cannot use the same attack during your next turn."
