class_name AttackOpponentFuturePokemonBonusDamage
extends BaseEffect

var bonus_damage: int = 120
var attack_index_to_match: int = -1


func _init(amount: int = 120, match_attack_index: int = 0) -> void:
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
	for slot: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		var cd := slot.get_card_data() if slot != null else null
		if cd != null and cd.is_future_pokemon():
			return bonus_damage
	return 0


func get_description() -> String:
	return "This attack does extra damage if the opponent has any Future Pokemon in play."
