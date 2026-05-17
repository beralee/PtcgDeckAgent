class_name AttackBruteBonnetDamageCounterBonus
extends BaseEffect

var damage_per_counter: int = 50
var attack_index_to_match: int = -1


func _init(per_counter: int = 50, match_attack_index: int = 1) -> void:
	damage_per_counter = max(0, per_counter)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var opponent_index := 1 - attacker.get_top_card().owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var defender := state.players[opponent_index].active_pokemon
	if defender == null:
		return 0
	return (defender.damage_counters / 10) * damage_per_counter


func get_description() -> String:
	return "This attack does extra damage for each damage counter on the opponent's Active Pokemon."
