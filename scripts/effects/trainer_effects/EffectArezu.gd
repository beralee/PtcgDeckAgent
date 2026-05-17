class_name EffectArezu
extends BaseEffect

const STEP_ID := "search_pokemon"
const MAX_SEARCH_COUNT := 3


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_valid_evolution_pokemon(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _get_valid_evolution_pokemon(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("Arezu: no non-Rule Box Evolution Pokemon found.")]
	return [build_full_library_search_step(
		STEP_ID,
		"Choose up to 3 non-Rule Box Evolution Pokemon to put into your hand",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(MAX_SEARCH_COUNT, items.size()),
		{"allow_cancel": true, "force_confirm": true}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("Arezu: view deck", player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var found: Array[CardInstance] = []
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_valid_evolution_pokemon(entry) and entry not in found:
			found.append(entry)
			if found.size() >= MAX_SEARCH_COUNT:
				break
	if found.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in _get_valid_evolution_pokemon(player):
			found.append(deck_card)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		found,
		card,
		"trainer",
		"search_to_hand",
		["non-Rule Box Evolution Pokemon"]
	)
	player.shuffle_deck()


func get_description() -> String:
	return "Search your deck for up to 3 Evolution Pokemon that do not have a Rule Box, reveal them, put them into your hand, then shuffle your deck."


func _get_valid_evolution_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_valid_evolution_pokemon(deck_card):
			result.append(deck_card)
	return result


func _is_valid_evolution_pokemon(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var data: CardData = card.card_data
	return data.is_evolution_pokemon() and not _has_rule_box(data)


func _has_rule_box(data: CardData) -> bool:
	if data.is_rule_box_pokemon() or data.is_radiant():
		return true
	for tag: String in data.is_tags:
		if tag in ["Rule Box", "ex", "V", "VSTAR", "VMAX", "Radiant"]:
			return true
	return false
