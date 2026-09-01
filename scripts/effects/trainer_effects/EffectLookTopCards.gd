class_name EffectLookTopCards
extends BaseEffect

var look_count: int = 7
var card_filter: String = ""
var pick_count: int = 1


func _init(look: int = 7, filter: String = "", pick: int = 1) -> void:
	look_count = look
	card_filter = filter
	pick_count = pick


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_matching_cards(player).is_empty()


func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var visible_cards: Array[CardInstance] = _get_looked_cards(player)
	var items: Array = _get_matching_cards(player)
	var max_select: int = mini(pick_count, items.size())
	var title := "从牌库上方%d张中选择最多%d张%s" % [visible_cards.size(), pick_count, _get_filter_label()]
	var options := {
		"allow_cancel": max_select > 0,
		"card_disabled_badge": "不可选",
		"card_selectable_hint": "可选",
		"show_selectable_hints": true,
	}
	if max_select == 0:
		title = "%s：查看到的卡牌里没有符合条件的%s" % [card.card_data.name, _get_filter_label()]
		options["utility_actions"] = [build_empty_dialog_utility_action("关闭并继续")]
	return [build_full_library_search_step(
		"look_top_cards",
		title,
		visible_cards,
		items,
		"own_top_%d_cards" % visible_cards.size(),
		1 if max_select > 0 else 0,
		max_select,
		options
	)]


func build_ucis_followup_interaction_steps_spec_steps(_card: CardInstance, _state: GameState, _resolved_context: Dictionary) -> Array[Dictionary]:
	return []


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var picked: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("look_top_cards", [])
	var has_explicit_selection: bool = ctx.has("look_top_cards")
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _matches_filter(entry):
			picked.append(entry)
			if picked.size() >= pick_count:
				break

	if picked.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in _get_matching_cards(player):
			picked.append(deck_card)
			if picked.size() >= pick_count:
				break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		picked,
		card,
		"trainer",
		"toplook_to_hand",
		[_get_filter_label()]
	)

	player.shuffle_deck()


func _matches_filter(card: CardInstance) -> bool:
	if card_filter == "":
		return true
	var cd: CardData = card.card_data
	match card_filter:
		"Pokemon":
			return cd.is_pokemon()
		"Supporter":
			return cd.card_type == "Supporter"
		"Evolution":
			return cd.is_evolution_pokemon()
		"Basic":
			return cd.is_basic_pokemon()
		"Item":
			return cd.card_type == "Item"
		"Tool":
			return cd.card_type == "Tool"
		"Energy":
			return cd.is_energy()
		_:
			return cd.card_type == card_filter


func get_description() -> String:
	var filter_name := "card"
	match card_filter:
		"Pokemon":
			filter_name = "Pokemon"
		"Supporter":
			filter_name = "Supporter"
		"Evolution":
			filter_name = "Evolution Pokemon"
		"Basic":
			filter_name = "Basic Pokemon"
		"Item":
			filter_name = "Item"
		"Tool":
			filter_name = "Pokemon Tool"
		"Energy":
			filter_name = "Energy"
		_:
			if card_filter != "":
				filter_name = card_filter

	if look_count > 0:
		return "Look at the top %d cards of your deck, then choose up to %d %s card(s)." % [
			look_count,
			pick_count,
			filter_name,
		]
	return "Search your deck for up to %d %s card(s)." % [pick_count, filter_name]


func _get_looked_cards(player: PlayerState) -> Array[CardInstance]:
	var looked_cards: Array[CardInstance] = []
	var check_count: int = mini(look_count, player.deck.size()) if look_count > 0 else player.deck.size()
	for idx: int in check_count:
		looked_cards.append(player.deck[idx])
	return looked_cards


func _get_matching_cards(player: PlayerState) -> Array:
	var matches: Array = []
	for deck_card: CardInstance in _get_looked_cards(player):
		if _matches_filter(deck_card):
			matches.append(deck_card)
	return matches


func _get_filter_label() -> String:
	match card_filter:
		"Pokemon":
			return "宝可梦"
		"Supporter":
			return "支援者"
		"Evolution":
			return "进化宝可梦"
		"Basic":
			return "基础宝可梦"
		"Item":
			return "物品"
		"Tool":
			return "宝可梦道具"
		"Energy":
			return "能量"
		_:
			return "卡牌" if card_filter == "" else card_filter
