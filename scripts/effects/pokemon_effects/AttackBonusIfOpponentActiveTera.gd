class_name AttackBonusIfOpponentActiveTera
extends BaseEffect

const CSV9CEffects := preload("res://scripts/effects/CSV9CEffects.gd")

var bonus_damage: int = 230
var attack_index_to_match: int = 0


func _init(amount: int = 230, match_attack_index: int = 0) -> void:
	bonus_damage = max(0, amount)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var opponent_index := 1 - attacker.get_top_card().owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	return bonus_damage if CSV9CEffects.is_tera_slot(state.players[opponent_index].active_pokemon) else 0


func get_description() -> String:
	return "This attack does extra damage if the opponent Active Pokemon is a Tera Pokemon."
