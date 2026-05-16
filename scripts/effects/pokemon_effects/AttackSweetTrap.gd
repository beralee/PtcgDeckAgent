class_name AttackSweetTrap
extends BaseEffect

const DAMAGE_BONUS_EFFECT_TYPE := "sweet_trap_damage_bonus"
const DAMAGE_BONUS := 90

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if defender == null or not applies_to_attack_index(attack_index):
		return
	if EffectMistEnergy.has_mist_energy(defender):
		return
	var owner_index := -1
	if attacker != null and attacker.get_top_card() != null:
		owner_index = attacker.get_top_card().owner_index
	defender.effects.append({
		"type": "retreat_lock",
		"turn": state.turn_number,
	})
	defender.effects.append({
		"type": DAMAGE_BONUS_EFFECT_TYPE,
		"turn": state.turn_number,
		"source_player_index": owner_index,
		"amount": DAMAGE_BONUS,
	})


func get_description() -> String:
	return "The Defending Pokemon cannot retreat next turn. During your next turn, it takes +90 damage from attacks."
