class_name EffectGrabber
extends BaseEffect

const STEP_ID := "grabber_opponent_pokemon"
const PREVIEW_STEP_ID := "grabber_opponent_hand_preview"
const VISIBLE_SCOPE_OPPONENT_HAND_REVEALED := "opponent_hand_revealed"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opponent := _opponent_for(card, state)
	return opponent != null and not opponent.hand.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_unusable_reason(card: CardInstance, state: GameState) -> String:
	return "" if can_execute(card, state) else "对手的手牌为空。"


func get_empty_interaction_message(card: CardInstance, state: GameState) -> String:
	return get_unusable_reason(card, state)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent := _opponent_for(card, state)
	if opponent == null or opponent.hand.is_empty():
		return []
	var pokemon := _pokemon_in_hand(opponent)
	if pokemon.is_empty():
		var preview := build_readonly_card_preview_step(
			"查看对手的手牌（其中没有宝可梦）",
			opponent.hand,
			"确认并继续"
		)
		preview["id"] = PREVIEW_STEP_ID
		preview["visible_scope"] = VISIBLE_SCOPE_OPPONENT_HAND_REVEALED
		return [preview]
	return [build_full_library_search_step(
		STEP_ID,
		"查看对手的手牌，选择1张宝可梦放回牌库下方",
		opponent.hand,
		pokemon,
		VISIBLE_SCOPE_OPPONENT_HAND_REVEALED,
		1,
		1,
		{
			"allow_cancel": false,
			"force_confirm": true,
			"card_disabled_badge": "非宝可梦",
			"card_selectable_hint": "可选择",
			"show_selectable_hints": true,
		}
	)]


func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
	var opponent := _opponent_for(card, state)
	if opponent == null or opponent.hand.is_empty():
		return interaction_validation_error("opponent hand is empty")
	var pokemon := _pokemon_in_hand(opponent)
	if pokemon.is_empty():
		return interaction_validation_ok()
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		pokemon,
		1,
		1
	)


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent := _opponent_for(card, state)
	if opponent == null:
		return
	var pokemon := _pokemon_in_hand(opponent)
	if pokemon.is_empty():
		return
	var selected_raw := interaction_context_selection(get_interaction_context(targets), STEP_ID)
	if selected_raw.size() != 1 or not (selected_raw[0] is CardInstance):
		return
	var selected := selected_raw[0] as CardInstance
	if selected not in pokemon or not opponent.remove_from_hand(selected):
		return
	selected.face_up = false
	opponent.deck.append(selected)


func get_description() -> String:
	return "查看对手的手牌，选择其中1张宝可梦，放回对手的牌库下方。"


func _opponent_for(card: CardInstance, state: GameState) -> PlayerState:
	if card == null or state == null:
		return null
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return null
	return state.players[opponent_index]


func _pokemon_in_hand(player: PlayerState) -> Array:
	var pokemon: Array = []
	if player == null:
		return pokemon
	for hand_card: CardInstance in player.hand:
		if hand_card != null and hand_card.card_data != null and hand_card.card_data.is_pokemon():
			pokemon.append(hand_card)
	return pokemon
