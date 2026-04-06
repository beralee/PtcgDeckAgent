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
		steps.append({
			"id": "search_stadium",
			"title": "选择1张竞技场卡加入手牌",
			"items": stadium_items,
			"labels": stadium_labels,
			"min_select": 0,
			"max_select": 1,
			"allow_cancel": true,
		})
	if not energy_items.is_empty():
		steps.append({
			"id": "search_energy",
			"title": "选择1张能量卡加入手牌",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 0,
			"max_select": 1,
			"allow_cancel": true,
		})
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

	var stadium_raw: Array = ctx.get("search_stadium", [])
	if not stadium_raw.is_empty() and stadium_raw[0] is CardInstance:
		var selected_stadium: CardInstance = stadium_raw[0]
		if selected_stadium in player.deck and selected_stadium.card_data.card_type == "Stadium":
			player.deck.erase(selected_stadium)
			player.hand.append(selected_stadium)

	var energy_raw: Array = ctx.get("search_energy", [])
	if not energy_raw.is_empty() and energy_raw[0] is CardInstance:
		var selected_energy: CardInstance = energy_raw[0]
		if selected_energy in player.deck and selected_energy.card_data.is_energy():
			player.deck.erase(selected_energy)
			player.hand.append(selected_energy)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库搜索1张竞技场卡和1张能量卡加入手牌。"
