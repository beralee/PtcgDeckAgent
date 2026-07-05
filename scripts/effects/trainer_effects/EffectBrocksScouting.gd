class_name EffectBrocksScouting
extends BaseEffect

const MODE_STEP_ID := "brocks_scouting_mode"
const BASIC_STEP_ID := "brocks_scouting_basic"
const EVOLUTION_STEP_ID := "brocks_scouting_evolution"
const MODE_BASIC := "basic"
const MODE_EVOLUTION := "evolution"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return card != null and state != null and not state.players[card.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null:
		return false
	var player: PlayerState = state.players[card.owner_index]
	return not _get_basic_pokemon(player).is_empty() or not _get_evolution_pokemon(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var has_basic := not _get_basic_pokemon(player).is_empty()
	var has_evolution := not _get_evolution_pokemon(player).is_empty()
	if not has_basic and not has_evolution:
		return [build_empty_search_resolution_step("Brock's Scouting: no Basic or Evolution Pokemon found.")]
	var items: Array = []
	var labels: Array[String] = []
	if has_basic:
		items.append(MODE_BASIC)
		labels.append("Basic Pokemon")
	if has_evolution:
		items.append(MODE_EVOLUTION)
		labels.append("Evolution Pokemon")
	return [{
		"id": MODE_STEP_ID,
		"title": "Choose Brock's Scouting search mode",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
		"requires_followup_interaction": true,
	}]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if should_preview_empty_search_deck(resolved_context):
		return [build_readonly_deck_preview_step("Brock's Scouting: view deck", state.players[card.owner_index].deck)]
	var mode := _resolve_mode(resolved_context)
	var player: PlayerState = state.players[card.owner_index]
	if mode == MODE_BASIC:
		return [_build_basic_step(player)]
	if mode == MODE_EVOLUTION:
		return [_build_evolution_step(player)]
	return []


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var context: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	if context.has(BASIC_STEP_ID):
		selected = _resolve_selected_basic(player, context.get(BASIC_STEP_ID, []), 2)
	elif context.has(EVOLUTION_STEP_ID):
		selected = _resolve_selected_evolution(player, context.get(EVOLUTION_STEP_ID, []), 1)
	else:
		var mode := _resolve_mode(context)
		if mode == MODE_EVOLUTION:
			selected = _get_first(_get_evolution_pokemon(player), 1)
		else:
			selected = _get_first(_get_basic_pokemon(player), 2)
			if selected.is_empty() and mode == "":
				selected = _get_first(_get_evolution_pokemon(player), 1)
	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected,
		card,
		"trainer",
		"search_to_hand",
		["Pokemon"]
	)
	player.shuffle_deck()


func _build_basic_step(player: PlayerState) -> Dictionary:
	var items: Array = _get_basic_pokemon(player)
	if items.is_empty():
		return build_empty_search_resolution_step("Brock's Scouting: no Basic Pokemon found.")
	return build_full_library_search_step(
		BASIC_STEP_ID,
		"Choose up to 2 Basic Pokemon to put into your hand",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(2, items.size()),
		{"allow_cancel": true, "force_confirm": true}
	)


func _build_evolution_step(player: PlayerState) -> Dictionary:
	var items: Array = _get_evolution_pokemon(player)
	if items.is_empty():
		return build_empty_search_resolution_step("Brock's Scouting: no Evolution Pokemon found.")
	return build_full_library_search_step(
		EVOLUTION_STEP_ID,
		"Choose 1 Evolution Pokemon to put into your hand",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		1,
		{"allow_cancel": true, "force_confirm": true}
	)


func _resolve_mode(context: Dictionary) -> String:
	var selected_raw: Array = context.get(MODE_STEP_ID, [])
	if selected_raw.is_empty():
		return ""
	var raw := str(selected_raw[0]).strip_edges().to_lower()
	if raw == MODE_BASIC or raw.contains("basic"):
		return MODE_BASIC
	if raw == MODE_EVOLUTION or raw.contains("evolution"):
		return MODE_EVOLUTION
	return ""


func _resolve_selected_basic(player: PlayerState, selected_raw: Array, max_count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_basic_pokemon(entry) and entry not in result:
			result.append(entry)
			if result.size() >= max_count:
				break
	return result


func _resolve_selected_evolution(player: PlayerState, selected_raw: Array, max_count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_evolution_pokemon(entry) and entry not in result:
			result.append(entry)
			if result.size() >= max_count:
				break
	return result


func _get_basic_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_basic_pokemon(deck_card):
			result.append(deck_card)
	return result


func _get_evolution_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_evolution_pokemon(deck_card):
			result.append(deck_card)
	return result


func _get_first(cards: Array, max_count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		result.append(card)
		if result.size() >= max_count:
			break
	return result


func _is_basic_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_basic_pokemon()


func _is_evolution_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_evolution_pokemon()


func get_description() -> String:
	return "Search your deck for up to 2 Basic Pokemon or 1 Evolution Pokemon, reveal them, put them into your hand, then shuffle your deck."
