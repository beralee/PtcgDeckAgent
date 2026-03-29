## This attack cannot be used again until the Pokemon leaves the Active Spot.
class_name AttackSelfLockUntilLeaveActive
extends BaseEffect

const EFFECT_TYPE := "attack_lock_until_leave_active"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	_state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	clear_for_slot(attacker)
	attacker.effects.append({
		"type": EFFECT_TYPE,
		"attack_name": _get_attack_name(attacker, attack_index),
		"attack_index": attack_index,
	})


static func clear_for_slot(slot: PokemonSlot) -> void:
	if slot == null:
		return
	var kept_effects: Array[Dictionary] = []
	for effect_data: Dictionary in slot.effects:
		if effect_data.get("type", "") == EFFECT_TYPE:
			continue
		kept_effects.append(effect_data)
	slot.effects = kept_effects


func _get_attack_name(slot: PokemonSlot, index: int) -> String:
	if slot == null:
		return ""
	var attacks: Array = slot.get_attacks()
	if index < 0 or index >= attacks.size():
		return ""
	var attack: Variant = attacks[index]
	return str(attack.get("name", "")) if attack is Dictionary else ""


func get_description() -> String:
	return "This attack can't be used again until this Pokemon leaves the Active Spot."
