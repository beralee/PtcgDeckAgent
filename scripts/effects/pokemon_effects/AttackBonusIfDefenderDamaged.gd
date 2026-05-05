class_name AttackBonusIfDefenderDamaged
extends BaseEffect

var bonus_damage: int = 110
var attack_index_to_match: int = -1


func _init(bonus: int = 110, match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var defender: PokemonSlot = state.players[1 - attacker.get_top_card().owner_index].active_pokemon
	if defender == null:
		return 0
	return bonus_damage if defender.damage_counters > 0 else 0


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "If the opponent's Active Pokemon has any damage counters on it, this attack does %d more damage." % bonus_damage
