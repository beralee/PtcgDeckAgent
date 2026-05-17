class_name EffectAcademyAtNight
extends BaseEffect

const STEP_ID := "academy_at_night_card"


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[state.current_player_index]
	return not player.hand.is_empty()


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	if player.hand.is_empty():
		return []
	var labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		labels.append(hand_card.card_data.name if hand_card.card_data != null else "")
	return [{
		"id": STEP_ID,
		"title": "Choose 1 card from your hand to put on top of your deck",
		"items": player.hand.duplicate(),
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
		"presentation": "cards",
	}]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var player_index: int = state.current_player_index
	var player: PlayerState = state.players[player_index]
	var selected := _resolve_selected_card(player, get_interaction_context(targets))
	if selected == null:
		return
	player.remove_from_hand(selected)
	selected.face_up = false
	player.deck.push_front(selected)


func get_description() -> String:
	return "Once during each player's turn, that player may put a card from their hand on top of their deck."


func _resolve_selected_card(player: PlayerState, ctx: Dictionary) -> CardInstance:
	var selected_raw: Array = ctx.get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.hand:
			return entry
	return null if player.hand.is_empty() else player.hand[0]
