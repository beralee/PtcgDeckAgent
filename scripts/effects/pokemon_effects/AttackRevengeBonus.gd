class_name AttackRevengeBonus
extends BaseEffect

var bonus_damage: int = 120
var attack_index_to_match: int = -1


func _init(bonus: int = 120, match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null:
		return 0
	var top_card := attacker.get_top_card()
	if top_card == null:
		return 0
	var owner_index := top_card.owner_index
	if owner_index < 0 or owner_index >= state.last_knockout_turn_against.size():
		return 0
	return bonus_damage if int(state.last_knockout_turn_against[owner_index]) == state.turn_number - 1 else 0


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "Deal extra damage if one of your Pokemon was KO'd last turn."
