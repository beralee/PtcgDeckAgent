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
	var delegated_raw: Variant = get_attack_interaction_context().get(DELEGATED_ATTACK_CONTEXT_KEY, {})
	var delegated: Dictionary = delegated_raw if delegated_raw is Dictionary else {}
	# A copied Pokemon used its outer copying attack, not the copied attack's
	# name. Official copy-attack rules therefore do not lock the outer attack.
	if str(delegated.get("mode", "")) == "copy":
		return
	var attack_name := _get_attack_name(attacker, attack_index)
	if str(delegated.get("mode", "")) == "granted":
		attack_name = str(delegated.get("name", attack_name))
	attacker.effects.append({
		"type": "attack_lock",
		"attack_name": attack_name,
		"attack_index": attack_index,
		"source_effect_id": str(delegated.get("effect_id", "")),
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
