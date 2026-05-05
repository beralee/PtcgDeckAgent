class_name EffectColressTenacity
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data == null:
			continue
		if deck_card.card_data.card_type == "Stadium" or deck_card.card_data.is_energy():
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var stadium_items: Array = []
	var stadium_labels: Array[String] = []
	var energy_items: Array = []
	var energy_labels: Array[String] = []

	for deck_card: CardInstance in player.deck:
		if deck_card.card_data == null:
			continue
		if deck_card.card_data.card_type == "Stadium":
			stadium_items.append(deck_card)
			stadium_labels.append(deck_card.card_data.name)
		elif deck_card.card_data.is_energy():
			energy_items.append(deck_card)
			energy_labels.append(deck_card.card_data.name)

	var steps: Array[Dictionary] = []
	if not stadium_items.is_empty():
		steps.append(build_full_library_search_step(
			"search_stadium",
			"选择1张竞技场卡加入手牌",
			player.deck,
			stadium_items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			1,
			{"allow_cancel": true}
		))
	if not energy_items.is_empty():
		steps.append(build_full_library_search_step(
			"search_energy",
			"选择1张能量卡加入手牌",
			player.deck,
			energy_items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			1,
			{"allow_cancel": true}
		))
	if steps.is_empty():
		return [build_empty_search_resolution_step("牌库里没有竞技场卡或能量卡。你仍可以使用这张卡。")]
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var revealed_cards: Array[CardInstance] = []
	var public_labels: Array[String] = []
	var stadium_raw: Array = ctx.get("search_stadium", [])
	for entry: Variant in stadium_raw:
		if not (entry is CardInstance):
			continue
		var selected_stadium: CardInstance = entry
		if selected_stadium in player.deck and selected_stadium.card_data.card_type == "Stadium":
			revealed_cards.append(selected_stadium)
			public_labels.append("竞技场卡")
			break

	var energy_raw: Array = ctx.get("search_energy", [])
	for entry: Variant in energy_raw:
		if not (entry is CardInstance):
			continue
		var selected_energy: CardInstance = entry
		if selected_energy in player.deck and selected_energy.card_data.is_energy():
			revealed_cards.append(selected_energy)
			public_labels.append("能量卡")
			break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		revealed_cards,
		card,
		"trainer",
		"search_to_hand",
		public_labels
	)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库搜索1张竞技场卡和1张能量卡加入手牌。"
