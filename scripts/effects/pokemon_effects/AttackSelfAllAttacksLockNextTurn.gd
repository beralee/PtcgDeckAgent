class_name AttackSelfAllAttacksLockNextTurn
extends BaseEffect

const EFFECT_TYPE := "attack_lock_all"

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
	clear_for_slot(attacker)
	attacker.effects.append({
		"type": EFFECT_TYPE,
		"source_attack_name": _get_attack_name(attacker, attack_index),
		"source_attack_index": attack_index,
		"turn": state.turn_number,
	})


static func clear_for_slot(slot: PokemonSlot) -> void:
	if slot == null:
		return
	var kept_effects: Array[Dictionary] = []
	for effect_data: Dictionary in slot.effects:
		if str(effect_data.get("type", "")) == EFFECT_TYPE:
			continue
		kept_effects.append(effect_data)
	slot.effects = kept_effects


func _get_attack_name(slot: PokemonSlot, index: int) -> String:
	if slot == null:
		return ""
	var attacks: Array = slot.get_attacks()
	if attacks.is_empty() or index < 0 or index >= attacks.size():
		return ""
	var attack: Variant = attacks[index]
	return str((attack as Dictionary).get("name", "")) if attack is Dictionary else ""


func get_description() -> String:
	return "After using this attack, this Pokemon cannot use any attacks during your next turn."
