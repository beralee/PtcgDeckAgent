class_name CSV9C176EnergySearchPro
extends BaseEffect

const STEP_ID := "csv9c176_energy"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_unique_basic_energy(player.deck).is_empty()


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = _get_unique_basic_energy(player.deck)
	if energy_items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有基本能量。你仍可以使用能量输送PRO。")]
	return [build_full_library_search_step(
		STEP_ID,
		"选择任意数量属性各不相同的基本能量加入手牌",
		player.deck,
		energy_items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		energy_items.size(),
		{"allow_cancel": true}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, state.players[card.owner_index].deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var seen_types: Dictionary = {}
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in ctx.get(STEP_ID, []):
		if not (entry is CardInstance):
			continue
		var energy_card: CardInstance = entry
		if energy_card not in player.deck or not _is_basic_energy(energy_card):
			continue
		var energy_type := _energy_type(energy_card)
		if energy_type == "" or seen_types.has(energy_type):
			continue
		seen_types[energy_type] = true
		selected.append(energy_card)
	if selected.is_empty() and not has_explicit_selection:
		selected = _get_unique_basic_energy(player.deck)

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected,
		card,
		"trainer",
		"search_to_hand",
		["属性各不相同的基本能量"]
	)
	player.shuffle_deck()


func _get_unique_basic_energy(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var seen_types: Dictionary = {}
	for deck_card: CardInstance in cards:
		if not _is_basic_energy(deck_card):
			continue
		var energy_type := _energy_type(deck_card)
		if energy_type == "" or seen_types.has(energy_type):
			continue
		seen_types[energy_type] = true
		result.append(deck_card)
	return result


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"


func _energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return card.card_data.energy_provides if card.card_data.energy_provides != "" else card.card_data.energy_type


func get_description() -> String:
	return "从牌库选择任意数量属性各不相同的基本能量加入手牌。"
