class_name AbilityDiscardHandDrawEndTurn
extends BaseEffect

const END_TURN_KEY := "ability_end_turn_draw_triggered"

var draw_count: int = 5


func _init(count: int = 5) -> void:
	draw_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null or pokemon.get_top_card() == null:
		return false
	var owner := pokemon.get_top_card().owner_index
	if state.current_player_index != owner:
		return false
	return not pokemon.has_ability_used(state.turn_number)


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top := pokemon.get_top_card()
	var owner := top.owner_index
	var player := state.players[owner]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	_discard_cards_from_hand_with_log(state, owner, hand_copy, top, "ability")
	_draw_cards_with_log(state, owner, draw_count, top, "ability")
	pokemon.mark_ability_used(state.turn_number)
	pokemon.effects.append({
		"type": END_TURN_KEY,
		"turn": state.turn_number,
		"player": owner,
	})


func get_description() -> String:
	return "Once during your turn, discard your hand and draw %d cards. If used, your turn ends." % draw_count
