class_name EffectSecretBox
extends BaseEffect

const DISCARD_COUNT := 3


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player)


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and _has_search_targets(player)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if not _can_pay_discard_cost(card, player):
		return []

	var steps: Array[Dictionary] = []
	var hand_items: Array = []
	var hand_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if hand_card == card:
			continue
		hand_items.append(hand_card)
		hand_labels.append(hand_card.card_data.name if hand_card.card_data != null else "Unknown Card")
	steps.append({
		"id": "discard_cards",
		"title": "选择3张手牌放入弃牌区",
		"items": hand_items,
		"labels": hand_labels,
		"min_select": DISCARD_COUNT,
		"max_select": DISCARD_COUNT,
		"allow_cancel": true,
	})

	var search_types: Array[Array] = [
		["search_item", "Item", "选择1张物品卡"],
		["search_tool", "Tool", "选择1张宝可梦道具"],
		["search_supporter", "Supporter", "选择1张支援者卡"],
		["search_stadium", "Stadium", "选择1张竞技场卡"],
	]
	var added_search_step := false
	for search_def: Array in search_types:
		var items: Array = []
		var labels: Array[String] = []
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data != null and deck_card.card_data.card_type == search_def[1]:
				items.append(deck_card)
				labels.append(deck_card.card_data.name)
		if items.is_empty():
			continue
		added_search_step = true
		steps.append({
			"id": search_def[0],
			"title": search_def[2],
			"items": items,
			"labels": labels,
			"min_select": 0,
			"max_select": 1,
			"allow_cancel": true,
		})
	if not added_search_step:
		steps.append(build_empty_search_resolution_step("牌库里没有可检索的物品、道具、支援者或竞技场卡。你仍可以使用这张卡。"))
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var discard_raw: Array = ctx.get("discard_cards", [])
	var discarded: int = 0
	for entry: Variant in discard_raw:
		if not (entry is CardInstance):
			continue
		var discard_card: CardInstance = entry
		if discard_card in player.hand:
			player.remove_from_hand(discard_card)
			player.discard_card(discard_card)
			discarded += 1
			if discarded >= DISCARD_COUNT:
				break
	while discarded < DISCARD_COUNT and not player.hand.is_empty():
		var fallback_card: CardInstance = player.hand[0]
		player.remove_from_hand(fallback_card)
		player.discard_card(fallback_card)
		discarded += 1

	var search_keys: Array[String] = ["search_item", "search_tool", "search_supporter", "search_stadium"]
	var search_types: Array[String] = ["Item", "Tool", "Supporter", "Stadium"]
	for i: int in search_keys.size():
		var raw: Array = ctx.get(search_keys[i], [])
		if raw.is_empty() or not (raw[0] is CardInstance):
			continue
		var found_card: CardInstance = raw[0]
		if found_card in player.deck and found_card.card_data != null and found_card.card_data.card_type == search_types[i]:
			player.deck.erase(found_card)
			found_card.face_up = true
			player.hand.append(found_card)

	player.shuffle_deck()


func get_description() -> String:
	return "弃掉3张手牌，然后从牌库检索物品、道具、支援者、竞技场各1张加入手牌。"


func _can_pay_discard_cost(card: CardInstance, player: PlayerState) -> bool:
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	return other_hand_cards >= DISCARD_COUNT


func _has_search_targets(player: PlayerState) -> bool:
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data == null:
			continue
		if deck_card.card_data.card_type in ["Item", "Tool", "Supporter", "Stadium"]:
			return true
	return false
