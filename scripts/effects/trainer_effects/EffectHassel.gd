class_name EffectHassel
extends EffectLookTopCards


func _init() -> void:
	super(8, "", 3)


func can_execute(card: CardInstance, state: GameState) -> bool:
	return _had_own_pokemon_knocked_out_last_turn(card, state) and super.can_execute(card, state)


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return _had_own_pokemon_knocked_out_last_turn(card, state) and super.can_headless_execute(card, state)


func _had_own_pokemon_knocked_out_last_turn(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null:
		return false
	var player_index := card.owner_index
	return state.was_knocked_out_during_opponents_previous_turn(player_index)


func get_description() -> String:
	return "If one of your Pokemon was Knocked Out during your opponent's last turn, look at the top 8 cards of your deck and put up to 3 into your hand."
