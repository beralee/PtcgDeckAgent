class_name AttackDefenderRetreatLockNextTurn
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	if defender == null:
		return
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if attacker != null and processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
			return
	elif EffectMistEnergy.has_mist_energy(defender):
		return
	defender.effects.append({
		"type": "retreat_lock",
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "The Defending Pokemon can't retreat during your opponent's next turn."
