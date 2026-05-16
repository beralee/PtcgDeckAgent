class_name CSV9C198Cilan
extends BaseEffect

const STEP_ID := "csv9c198_pokemon_ex"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_pokemon_ex(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items := _get_pokemon_ex(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有宝可梦ex。你仍可以使用席蓝。")]
	return [build_full_library_search_step(
		STEP_ID,
		"选择最多3张宝可梦ex加入手牌",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(3, items.size()),
		{"allow_cancel": true}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, state.players[card.owner_index].deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx := get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in player.deck and _is_pokemon_ex((entry as CardInstance).card_data) and entry not in selected:
			selected.append(entry)
			if selected.size() >= 3:
				break
	if selected.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in _get_pokemon_ex(player):
			selected.append(deck_card)
			if selected.size() >= 3:
				break
	_move_public_cards_to_hand_with_log(state, card.owner_index, selected, card, "trainer", "search_to_hand", ["宝可梦ex"])
	player.shuffle_deck()


func _get_pokemon_ex(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_pokemon_ex(deck_card.card_data):
			result.append(deck_card)
	return result


func _is_pokemon_ex(cd: CardData) -> bool:
	if cd == null or not cd.is_pokemon():
		return false
	return cd.mechanic == "ex" or cd.has_tag("ex")


func get_description() -> String:
	return "从牌库选择最多3张宝可梦ex加入手牌。"
