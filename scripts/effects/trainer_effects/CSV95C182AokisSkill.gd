class_name CSV95C182AokisSkill
extends BaseEffect

const POKEMON_STEP_ID := "csv95c182_pokemon"
const SUPPORTER_STEP_ID := "csv95c182_supporter"
const ENERGY_STEP_ID := "csv95c182_basic_energy"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var steps: Array[Dictionary] = []
	var step_defs: Array[Dictionary] = [
		{"id": POKEMON_STEP_ID, "title": "从牌库选择1张宝可梦"},
		{"id": SUPPORTER_STEP_ID, "title": "从牌库选择1张支援者"},
		{"id": ENERGY_STEP_ID, "title": "从牌库选择1张基本能量"},
	]
	for step_def: Dictionary in step_defs:
		var items := _get_matching_deck_cards(player, str(step_def["id"]))
		if items.is_empty():
			continue
		steps.append(build_full_library_search_step(
			str(step_def["id"]),
			str(step_def["title"]),
			player.deck,
			items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			1,
			{"allow_cancel": true}
		))
	if steps.is_empty():
		steps.append(build_empty_search_resolution_step("牌库里没有可选择的宝可梦、支援者或基本能量。你仍可以使用这张卡。"))
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var hand_to_discard: Array[CardInstance] = []
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			hand_to_discard.append(hand_card)
	_discard_cards_from_hand_with_log(state, card.owner_index, hand_to_discard, card, "trainer")

	var revealed_cards: Array[CardInstance] = []
	var public_labels: Array[String] = []
	_add_selected_card(player, ctx, POKEMON_STEP_ID, "宝可梦", revealed_cards, public_labels)
	_add_selected_card(player, ctx, SUPPORTER_STEP_ID, "支援者", revealed_cards, public_labels)
	_add_selected_card(player, ctx, ENERGY_STEP_ID, "基本能量", revealed_cards, public_labels)

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


func _add_selected_card(
	player: PlayerState,
	ctx: Dictionary,
	step_id: String,
	public_label: String,
	revealed_cards: Array[CardInstance],
	public_labels: Array[String]
) -> void:
	var selected := _resolve_selected_card(player, ctx, step_id)
	if selected == null or selected in revealed_cards:
		return
	revealed_cards.append(selected)
	public_labels.append(public_label)


func _resolve_selected_card(player: PlayerState, ctx: Dictionary, step_id: String) -> CardInstance:
	var raw: Array = ctx.get(step_id, [])
	var has_explicit_selection := ctx.has(step_id)
	for entry: Variant in raw:
		if entry is CardInstance and entry in player.deck and _matches_step(entry, step_id):
			return entry
	if has_explicit_selection:
		return null
	var matching := _get_matching_deck_cards(player, step_id)
	return matching[0] if not matching.is_empty() else null


func _get_matching_deck_cards(player: PlayerState, step_id: String) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _matches_step(deck_card, step_id):
			result.append(deck_card)
	return result


func _matches_step(card: CardInstance, step_id: String) -> bool:
	if card == null or card.card_data == null:
		return false
	var cd: CardData = card.card_data
	match step_id:
		POKEMON_STEP_ID:
			return cd.is_pokemon()
		SUPPORTER_STEP_ID:
			return cd.card_type == "Supporter"
		ENERGY_STEP_ID:
			return cd.card_type == "Basic Energy"
	return false


func get_description() -> String:
	return "将自己的手牌全部放于弃牌区，选择牌库中的宝可梦、支援者、基本能量各1张加入手牌。"
