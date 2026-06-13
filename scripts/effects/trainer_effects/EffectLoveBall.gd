class_name EffectLoveBall
extends BaseEffect

const STEP_ID := "love_ball_pokemon"


func can_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return false
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty() and not _get_opponent_field_name_keys(card.owner_index, state).is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items := _get_matching_pokemon(card.owner_index, player, state)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有与对手场上宝可梦同名的宝可梦。你仍可以使用甜蜜球。")]
	return [build_full_library_search_step(
		STEP_ID,
		"选择1张与对手场上宝可梦同名的宝可梦加入手牌",
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
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: CardInstance = null
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_matching_pokemon(card.owner_index, entry, state):
			selected = entry
			break
	if selected == null and not has_explicit_selection:
		var matching := _get_matching_pokemon(card.owner_index, player, state)
		if not matching.is_empty():
			selected = matching[0]

	var found: Array[CardInstance] = []
	if selected != null:
		found.append(selected)
	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		found,
		card,
		"trainer",
		"search_to_hand",
		["宝可梦"]
	)
	player.shuffle_deck()


func _get_matching_pokemon(owner_index: int, player: PlayerState, state: GameState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_matching_pokemon(owner_index, deck_card, state):
			result.append(deck_card)
	return result


func _is_matching_pokemon(owner_index: int, card: CardInstance, state: GameState) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_pokemon():
		return false
	var opponent_keys := _get_opponent_field_name_keys(owner_index, state)
	for key: String in _card_name_keys(card.card_data):
		if key in opponent_keys:
			return true
	return false


func _get_opponent_field_name_keys(owner_index: int, state: GameState) -> Dictionary:
	var names := {}
	if state == null:
		return names
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return names
	var opponent: PlayerState = state.players[opponent_index]
	_add_slot_name_keys(names, opponent.active_pokemon)
	for slot: PokemonSlot in opponent.bench:
		_add_slot_name_keys(names, slot)
	return names


func _add_slot_name_keys(names: Dictionary, slot: PokemonSlot) -> void:
	if slot == null:
		return
	var top := slot.get_top_card()
	if top == null or top.card_data == null:
		return
	for key: String in _card_name_keys(top.card_data):
		names[key] = true


func _card_name_keys(card_data: CardData) -> Array[String]:
	var result: Array[String] = []
	_add_name_key(result, card_data.name)
	_add_name_key(result, card_data.name_en)
	return result


func _add_name_key(result: Array[String], raw_name: String) -> void:
	var key := raw_name.strip_edges().to_lower()
	if key != "" and key not in result:
		result.append(key)


func get_description() -> String:
	return "从牌库选择1张与对手场上宝可梦同名的宝可梦给对手看后加入手牌，然后重洗牌库。"
