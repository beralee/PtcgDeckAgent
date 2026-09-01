class_name EffectPokePad
extends BaseEffect

const STEP_ID := "search_pokemon"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_non_rule_box_pokemon(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items := _get_non_rule_box_pokemon(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("Poké Pad: no non-Rule Box Pokemon found.")]
	return [build_full_library_search_step(
		STEP_ID,
		"Choose 1 non-Rule Box Pokemon to put into your hand",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		1,
		{"allow_cancel": true, "force_confirm": true}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("Poké Pad: view deck", player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var context := get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var selected_raw: Array = context.get(STEP_ID, [])
	var has_explicit_selection := context.has(STEP_ID)
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_non_rule_box_pokemon(entry):
			selected.append(entry)
			break
	if selected.is_empty() and not has_explicit_selection:
		var candidates := _get_non_rule_box_pokemon(player)
		if not candidates.is_empty():
			selected.append(candidates[0])

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected,
		card,
		"trainer",
		"search_to_hand",
		["non-Rule Box Pokemon"]
	)
	player.shuffle_deck()


func get_description() -> String:
	return "Search your deck for a Pokemon that does not have a Rule Box, reveal it, put it into your hand, then shuffle your deck."


func _get_non_rule_box_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_non_rule_box_pokemon(deck_card):
			result.append(deck_card)
	return result


func _is_non_rule_box_pokemon(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_pokemon():
		return false
	return not _has_rule_box(card.card_data)


func _has_rule_box(card_data: CardData) -> bool:
	if card_data.is_rule_box_pokemon():
		return true
	for tag: String in card_data.is_tags:
		if tag in ["Rule Box", "ex", "V", "VSTAR", "VMAX", "Radiant"]:
			return true
	return false
