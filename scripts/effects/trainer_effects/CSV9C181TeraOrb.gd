class_name CSV9C181TeraOrb
extends BaseEffect

const STEP_ID := "csv9c181_tera_pokemon"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_tera_pokemon(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items := _get_tera_pokemon(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有太晶宝可梦。你仍可以使用太晶珠。")]
	return [build_full_library_search_step(
		STEP_ID,
		"选择1张太晶宝可梦加入手牌",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, state.players[card.owner_index].deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx := get_interaction_context(targets)
	var selected: CardInstance = null
	var raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in raw:
		if entry is CardInstance and entry in player.deck and _is_tera_pokemon((entry as CardInstance).card_data):
			selected = entry
			break
	if selected == null and not has_explicit_selection:
		var items := _get_tera_pokemon(player)
		selected = items[0] if not items.is_empty() else null
	if selected != null:
		_move_public_cards_to_hand_with_log(state, card.owner_index, [selected], card, "trainer", "search_to_hand", ["太晶宝可梦"])
	player.shuffle_deck()


func _get_tera_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_tera_pokemon(deck_card.card_data):
			result.append(deck_card)
	return result


func _is_tera_pokemon(cd: CardData) -> bool:
	if cd == null or not cd.is_pokemon():
		return false
	return cd.is_tera_pokemon()


func get_description() -> String:
	return "从牌库选择1张太晶宝可梦加入手牌。"
