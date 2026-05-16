class_name CSV9C183PerfectMixer
extends BaseEffect

const STEP_ID := "csv9c183_discard_from_deck"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []
	return [build_full_library_search_step(
		STEP_ID,
		"选择牌库中最多5张任意卡牌放入弃牌区",
		player.deck,
		player.deck,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(5, player.deck.size()),
		{"allow_cancel": true}
	)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx := get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in player.deck and entry not in selected:
			selected.append(entry)
			if selected.size() >= 5:
				break
	if selected.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			selected.append(deck_card)
			if selected.size() >= 5:
				break
	for deck_card: CardInstance in selected:
		player.deck.erase(deck_card)
		deck_card.face_up = true
		player.discard_pile.append(deck_card)
	player.shuffle_deck()


func get_description() -> String:
	return "选择牌库中最多5张任意卡牌放入弃牌区。"
