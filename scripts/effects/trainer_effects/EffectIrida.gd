class_name EffectIrida
extends BaseEffect

const WATER_ENERGY_TYPE: String = "W"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			return true
		if cd.card_type == "Item":
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var found_water_pokemon: CardInstance = null
	var found_item: CardInstance = null
	var water_raw: Array = ctx.get("water_pokemon", [])
	for entry: Variant in water_raw:
		if not (entry is CardInstance):
			continue
		var water_selected: CardInstance = entry
		if water_selected in player.deck and water_selected.card_data.is_pokemon() and water_selected.card_data.energy_type == WATER_ENERGY_TYPE:
			found_water_pokemon = water_selected
			break
	var item_raw: Array = ctx.get("item_card", [])
	for entry: Variant in item_raw:
		if not (entry is CardInstance):
			continue
		var item_selected: CardInstance = entry
		if item_selected in player.deck and item_selected.card_data.card_type == "Item":
			found_item = item_selected
			break

	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if found_water_pokemon == null and cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			found_water_pokemon = deck_card
		if found_item == null and cd.card_type == "Item":
			found_item = deck_card
		if found_water_pokemon != null and found_item != null:
			break

	var revealed_cards: Array[CardInstance] = []
	var public_labels: Array[String] = []
	if found_water_pokemon != null:
		revealed_cards.append(found_water_pokemon)
		public_labels.append("水属性宝可梦")
	if found_item != null:
		revealed_cards.append(found_item)
		public_labels.append("物品")
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


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var pokemon_items: Array = []
	var item_items: Array = []
	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			pokemon_items.append(deck_card)
		elif cd.card_type == "Item":
			item_items.append(deck_card)
	var steps: Array[Dictionary] = []
	if not pokemon_items.is_empty():
		steps.append(build_full_library_search_step(
			"water_pokemon",
		"选择1张水属性宝可梦",
			player.deck,
			pokemon_items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			1,
			1,
			{"allow_cancel": true}
		))
	if not item_items.is_empty():
		steps.append(build_full_library_search_step(
			"item_card",
		"选择1张物品卡",
			player.deck,
			item_items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			1,
			1,
			{"allow_cancel": true}
		))
	if steps.is_empty():
		return [build_empty_search_resolution_step("牌库里没有水属性宝可梦或物品卡。你仍可以使用这张卡。")]
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func get_description() -> String:
	return "Search your deck for a Water Pokemon and an Item card."
