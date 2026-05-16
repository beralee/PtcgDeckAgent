class_name AttackDefenderActionCostIncreaseNextTurn
extends BaseEffect

const EFFECT_TYPE := "defender_action_cost_increase"

var cost_increase: int = 1
var attack_index_to_match: int = -1


func _init(amount: int = 1, match_attack_index: int = -1) -> void:
	cost_increase = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if defender == null or not applies_to_attack_index(attack_index):
		return
	if EffectMistEnergy.has_mist_energy(defender):
		return
	defender.effects.append({
		"type": EFFECT_TYPE,
		"turn": state.turn_number,
		"amount": cost_increase,
	})


static func get_active_modifier(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return 0
	var total := 0
	for effect_data: Dictionary in slot.effects:
		if effect_data.get("type", "") != EFFECT_TYPE:
			continue
		if int(effect_data.get("turn", -999)) == state.turn_number - 1:
			total += int(effect_data.get("amount", 1))
	return total


func get_description() -> String:
	return "During the opponent's next turn, the Defending Pokemon's attacks and retreat cost increase."
