class_name AbilitySwellingFlash
extends BaseEffect


func can_play_from_hand_to_bench(card: CardInstance, state: GameState, player_index: int) -> bool:
	if card == null or card.card_data == null or state == null:
		return false
	if player_index < 0 or player_index >= state.players.size():
		return false
	if state.current_player_index != player_index or state.phase != GameState.GamePhase.MAIN:
		return false
	var player: PlayerState = state.players[player_index]
	if card not in player.hand:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	return player.prizes.size() > state.players[opponent_index].prizes.size()


func get_hand_to_bench_unusable_reason(card: CardInstance, state: GameState, player_index: int) -> String:
	if can_play_from_hand_to_bench(card, state, player_index):
		return ""
	return "Swelling Flash can be used only from your hand while you have more Prize cards remaining than your opponent."


func get_description() -> String:
	return "Once during your turn, if this Pokemon is in your hand and you have more Prize cards remaining than your opponent, put it onto your Bench."
