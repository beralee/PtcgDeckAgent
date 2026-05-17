class_name EffectFeatherBall
extends BaseEffect

const STEP_ID := "search_pokemon"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_free_retreat_pokemon(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _get_free_retreat_pokemon(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("Feather Ball: no Pokemon with no Retreat Cost found.")]
	return [build_full_library_search_step(
		STEP_ID,
		"Choose 1 Pokemon with no Retreat Cost to put into your hand",
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
	return [build_readonly_deck_preview_step("Feather Ball: view deck", player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_free_retreat_pokemon(entry):
			selected.append(entry)
			break
	if selected.is_empty() and not has_explicit_selection:
		var candidates := _get_free_retreat_pokemon(player)
		if not candidates.is_empty():
			selected.append(candidates[0])

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected,
		card,
		"trainer",
		"search_to_hand",
		["Pokemon with no Retreat Cost"]
	)
	player.shuffle_deck()


func get_description() -> String:
	return "Search your deck for a Pokemon with no Retreat Cost, reveal it, put it into your hand, then shuffle your deck."


func _get_free_retreat_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_free_retreat_pokemon(deck_card):
			result.append(deck_card)
	return result


func _is_free_retreat_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_pokemon() and card.card_data.retreat_cost == 0
