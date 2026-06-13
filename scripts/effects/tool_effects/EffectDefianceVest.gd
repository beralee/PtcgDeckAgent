class_name EffectDefianceVest
extends BaseEffect

const DAMAGE_REDUCTION := -40


func get_defense_modifier(defender: PokemonSlot, state: GameState = null, attacker: PokemonSlot = null) -> int:
	if not _applies(defender, state, attacker):
		return 0
	return DAMAGE_REDUCTION


func _applies(defender: PokemonSlot, state: GameState = null, attacker: PokemonSlot = null) -> bool:
	if defender == null or state == null or defender.get_top_card() == null or attacker == null or attacker.get_top_card() == null:
		return false
	var owner_index := defender.get_top_card().owner_index
	var opponent_index := 1 - owner_index
	if owner_index < 0 or opponent_index < 0 or owner_index >= state.players.size() or opponent_index >= state.players.size():
		return false
	if attacker.get_top_card().owner_index != opponent_index:
		return false
	return state.players[owner_index].prizes.size() > state.players[opponent_index].prizes.size()


func get_description() -> String:
	return "If the attached Pokemon's owner has more remaining Prize cards than the opponent, damage taken is reduced by 40."
