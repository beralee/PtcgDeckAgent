class_name AttackOpponentRetreatCostReduction
extends BaseEffect

var damage_reduction_per_retreat: int = 50
var attack_index_to_match: int = -1


func _init(per_retreat: int = 50, match_attack_index: int = -1) -> void:
	damage_reduction_per_retreat = per_retreat
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner := attacker.get_top_card().owner_index
	var opponent_index := 1 - owner
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var defender: PokemonSlot = state.players[opponent_index].active_pokemon
	if defender == null:
		return 0
	return -(defender.get_retreat_cost() * damage_reduction_per_retreat)


func get_description() -> String:
	return "This attack does less damage for each Colorless in the opponent Active Pokemon's Retreat Cost."
