class_name EffectLuckyHelmet
extends BaseEffect


func on_damaged_by_attack(
	defender: PokemonSlot,
	attacker: PokemonSlot,
	damage: int,
	state: GameState
) -> void:
	if defender == null or attacker == null or damage <= 0 or state == null:
		return
	if defender.get_top_card() == null or attacker.get_top_card() == null:
		return
	var owner := defender.get_top_card().owner_index
	if state.players[owner].active_pokemon != defender or attacker.get_top_card().owner_index == owner:
		return
	_draw_cards_with_log(state, owner, 2, defender.attached_tool, "tool")


func get_description() -> String:
	return "If the Active holder is damaged by an opponent's attack, draw 2 cards."
