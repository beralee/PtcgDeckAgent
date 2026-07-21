class_name EffectSpikemuthGym
extends BaseEffect

const STEP_ID := "spikemuth_gym_marnies_pokemon"


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	if state == null or state.current_player_index < 0 or state.current_player_index >= state.players.size():
		return false
	return not state.players[state.current_player_index].deck.is_empty()


func can_headless_execute(_card: CardInstance, state: GameState) -> bool:
	if state == null or state.current_player_index < 0 or state.current_player_index >= state.players.size():
		return false
	return not _get_marnies_pokemon(state.players[state.current_player_index]).is_empty()


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	var items: Array = _get_marnies_pokemon(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("Spikemuth Gym: no Marnie's Pokemon found.")]
	return [build_full_library_search_step(
		STEP_ID,
		"Choose a Marnie's Pokemon to put into your hand",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		1,
		{"allow_cancel": true, "force_confirm": true}
	)]


func get_followup_interaction_steps(_card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[state.current_player_index]
	return [build_readonly_deck_preview_step("Spikemuth Gym: view deck", player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player_index := state.current_player_index
	var player: PlayerState = state.players[player_index]
	var context: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = context.get(STEP_ID, [])
	var has_explicit_selection := context.has(STEP_ID)
	var chosen: CardInstance = null
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_marnies_pokemon(entry):
			chosen = entry
			break
	if chosen == null and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if _is_marnies_pokemon(deck_card):
				chosen = deck_card
				break
	if chosen != null:
		_move_public_cards_to_hand_with_log(
			state,
			player_index,
			[chosen],
			card,
			"stadium",
			"search_to_hand",
			["Marnie's Pokemon"]
		)
	player.shuffle_deck()


func _get_marnies_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_marnies_pokemon(deck_card):
			result.append(deck_card)
	return result


func _is_marnies_pokemon(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_pokemon():
		return false
	var names: Array[String] = [card.card_data.name, card.card_data.name_en, card.card_data.name_zh]
	for raw_name: String in names:
		var normalized := raw_name.strip_edges().to_lower()
		if normalized.begins_with("marnie's ") or normalized.begins_with("marnies ") or normalized.begins_with("玛俐的"):
			return true
	return false


func get_description() -> String:
	return "Once during each player's turn, that player may search their deck for a Marnie's Pokemon and put it into their hand."
