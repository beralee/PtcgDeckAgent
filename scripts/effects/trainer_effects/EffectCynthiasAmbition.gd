class_name EffectCynthiasAmbition
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null:
		return false
	var player: PlayerState = state.players[card.owner_index]
	var hand_size_after_play: int = player.hand.size()
	if card in player.hand:
		hand_size_after_play -= 1
	return hand_size_after_play < _target_hand_size(card.owner_index, state) and not player.deck.is_empty()


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	if card == null or state == null:
		return
	var player: PlayerState = state.players[card.owner_index]
	var target_size: int = _target_hand_size(card.owner_index, state)
	var draw_count: int = max(0, target_size - player.hand.size())
	_draw_cards_with_log(state, card.owner_index, draw_count, card, "trainer")


func _target_hand_size(player_index: int, state: GameState) -> int:
	if player_index >= 0 and player_index < state.last_knockout_turn_against.size():
		if int(state.last_knockout_turn_against[player_index]) == state.turn_number - 1:
			return 8
	return 5


func get_description() -> String:
	return "Draw cards until you have 5 cards in hand, or 8 if one of your Pokemon was Knocked Out during your opponent's last turn."
