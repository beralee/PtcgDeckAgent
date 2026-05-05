class_name BaseEffect
extends RefCounted

var _attack_interaction_context: Dictionary = {}
var _default_attack_index_to_match: int = -1

const EMPTY_SEARCH_CONTINUE := "continue"
const EMPTY_SEARCH_VIEW_DECK := "view_deck"
const VISIBLE_SCOPE_OWN_FULL_DECK := "own_full_deck"
const DEFAULT_FULL_LIBRARY_DISABLED_BADGE := "不可选"
const DEFAULT_FULL_LIBRARY_SELECTABLE_LABEL := "可选"


enum TargetType {
	NONE,
	OWN_ACTIVE,
	OPP_ACTIVE,
	OWN_BENCH,
	OPP_BENCH,
	OWN_ANY_POKEMON,
	OPP_ANY_POKEMON,
	ANY_POKEMON,
	HAND_CARD,
	DISCARD_CARD,
	ENERGY_ON_POKEMON,
	COIN_FLIP,
	PLAYER_CHOICE,
}


func get_target_type() -> TargetType:
	return TargetType.NONE


func get_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_preview_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return get_interaction_steps(card, state)


func get_empty_interaction_message(_card: CardInstance, _state: GameState) -> String:
	return ""


func get_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_followup_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_followup_interaction_steps(
	_card: CardInstance,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_interaction_context(targets: Array) -> Dictionary:
	if targets.is_empty():
		return {}
	var ctx: Variant = targets[0]
	return ctx.duplicate(false) if ctx is Dictionary else {}


func _draw_cards_with_log(
	state: GameState,
	player_index: int,
	count: int,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null:
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("draw_cards_with_log"):
		return draw_processor.call("draw_cards_with_log", player_index, count, state, source_card, source_kind)
	if count <= 0:
		return []
	return state.players[player_index].draw_cards(count)


func _discard_cards_from_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("discard_cards_from_hand_with_log"):
		return draw_processor.call("discard_cards_from_hand_with_log", player_index, cards, state, source_card, source_kind)
	var player: PlayerState = state.players[player_index]
	var discarded: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card == null or not (card in player.hand):
			continue
		player.remove_from_hand(card)
		player.discard_card(card)
		discarded.append(card)
	return discarded


func _move_public_cards_to_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = "",
	public_result_kind: String = "search_to_hand",
	public_result_labels: Array[String] = []
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("move_public_cards_to_hand_with_log"):
		return draw_processor.call(
			"move_public_cards_to_hand_with_log",
			player_index,
			cards,
			state,
			source_card,
			source_kind,
			public_result_kind,
			public_result_labels
		)
	var player: PlayerState = state.players[player_index]
	var moved: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	for card: CardInstance in cards:
		if card == null or seen_ids.has(card.instance_id) or not (card in player.deck):
			continue
		seen_ids[card.instance_id] = true
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)
		moved.append(card)
	return moved


func set_attack_interaction_context(targets: Array) -> void:
	_attack_interaction_context = get_interaction_context(targets)


func get_attack_interaction_context() -> Dictionary:
	return _attack_interaction_context


func clear_attack_interaction_context() -> void:
	_attack_interaction_context.clear()


func bind_default_attack_index(attack_index: int) -> void:
	_default_attack_index_to_match = attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return _default_attack_index_to_match < 0 or _default_attack_index_to_match == attack_index


func build_full_library_search_step(
	step_id: String,
	title: String,
	visible_cards: Array,
	legal_items: Array,
	visible_scope: String,
	min_select: int = 1,
	max_select: int = 1,
	options: Dictionary = {}
) -> Dictionary:
	var resolved_scope := visible_scope.strip_edges()
	if resolved_scope == "":
		push_error("build_full_library_search_step requires an explicit visible_scope")

	var card_indices: Array[int] = []
	for card: Variant in visible_cards:
		card_indices.append(legal_items.find(card))

	var legal_labels: Array[String] = []
	for item: Variant in legal_items:
		legal_labels.append(_full_library_search_label_for_item(item))

	var disabled_badge := str(options.get("card_disabled_badge", DEFAULT_FULL_LIBRARY_DISABLED_BADGE))
	var selectable_label := str(options.get("selectable_label", DEFAULT_FULL_LIBRARY_SELECTABLE_LABEL))
	var disabled_label := str(options.get("disabled_label", disabled_badge))
	var choice_labels: Array[String] = []
	if options.has("choice_labels"):
		for label: Variant in options.get("choice_labels", []):
			choice_labels.append(str(label))
	else:
		for i: int in visible_cards.size():
			var label := _full_library_search_label_for_item(visible_cards[i])
			var suffix := selectable_label if card_indices[i] >= 0 else disabled_label
			choice_labels.append("%s - %s" % [label, suffix])

	var step := {
		"id": step_id,
		"title": title,
		"items": legal_items.duplicate(),
		"labels": legal_labels,
		"presentation": "cards",
		"card_items": visible_cards.duplicate(),
		"card_indices": card_indices,
		"choice_labels": choice_labels,
		"visible_scope": resolved_scope,
		"card_disabled_badge": disabled_badge,
		"card_selectable_hint": str(options.get("card_selectable_hint", selectable_label)),
		"min_select": min_select,
		"max_select": max_select,
		"allow_cancel": bool(options.get("allow_cancel", true)),
		"visible_count": visible_cards.size(),
		"selectable_count": legal_items.size(),
	}
	if options.has("show_selectable_hints"):
		step["show_selectable_hints"] = bool(options.get("show_selectable_hints", false))
	if options.has("card_click_selectable"):
		step["card_click_selectable"] = bool(options.get("card_click_selectable", true))
	if options.has("utility_actions"):
		step["utility_actions"] = (options.get("utility_actions", []) as Array).duplicate(true)
	if options.has("prompt_type"):
		step["prompt_type"] = str(options.get("prompt_type", ""))
	return step


func _full_library_search_label_for_item(item: Variant) -> String:
	if item is CardInstance:
		var card: CardInstance = item
		return card.card_data.name if card.card_data != null else ""
	if item is CardData:
		return (item as CardData).name
	if item is PokemonSlot:
		return (item as PokemonSlot).get_pokemon_name()
	if item is Dictionary:
		var entry: Dictionary = item
		for key: String in ["card_name", "pokemon_name", "name", "title"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
	return str(item).strip_edges()


func build_card_assignment_step(
	step_id: String,
	title: String,
	source_items: Array,
	source_labels: Array[String],
	target_items: Array,
	target_labels: Array[String],
	min_assignments: int,
	max_assignments: int,
	allow_cancel: bool = true
) -> Dictionary:
	return {
		"id": step_id,
		"title": title,
		"ui_mode": "card_assignment",
		"source_items": source_items,
		"source_labels": source_labels,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": min_assignments,
		"max_select": max_assignments,
		"allow_cancel": allow_cancel,
	}


func build_full_library_card_assignment_step(
	step_id: String,
	title: String,
	visible_source_cards: Array,
	source_items: Array,
	source_labels: Array[String],
	target_items: Array,
	target_labels: Array[String],
	min_assignments: int,
	max_assignments: int,
	visible_scope: String,
	allow_cancel: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	var step := build_card_assignment_step(
		step_id,
		title,
		source_items,
		source_labels,
		target_items,
		target_labels,
		min_assignments,
		max_assignments,
		allow_cancel
	)
	return add_full_library_source_metadata_to_assignment_step(
		step,
		visible_source_cards,
		source_items,
		visible_scope,
		options
	)


func add_full_library_source_metadata_to_assignment_step(
	step: Dictionary,
	visible_source_cards: Array,
	source_items: Array,
	visible_scope: String,
	options: Dictionary = {}
) -> Dictionary:
	var source_step := build_full_library_search_step(
		str(step.get("id", "")),
		str(step.get("title", "")),
		visible_source_cards,
		source_items,
		visible_scope,
		int(step.get("min_select", 0)),
		int(step.get("max_select", source_items.size())),
		options
	)
	step["source_card_items"] = (source_step.get("card_items", []) as Array).duplicate()
	step["source_card_indices"] = (source_step.get("card_indices", []) as Array).duplicate()
	step["source_choice_labels"] = (source_step.get("choice_labels", []) as Array).duplicate()
	step["source_visible_scope"] = str(source_step.get("visible_scope", ""))
	step["source_card_disabled_badge"] = str(source_step.get("card_disabled_badge", ""))
	step["source_card_selectable_hint"] = str(source_step.get("card_selectable_hint", ""))
	step["source_visible_count"] = int(source_step.get("visible_count", visible_source_cards.size()))
	step["source_selectable_count"] = int(source_step.get("selectable_count", source_items.size()))
	if not step.has("visible_scope"):
		step["visible_scope"] = str(source_step.get("visible_scope", ""))
	return step


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func execute(_card: CardInstance, _targets: Array, _state: GameState) -> void:
	pass


func get_on_play_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func execute_on_play(_card: CardInstance, _state: GameState, _targets: Array = []) -> void:
	pass


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return false


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return ""


func build_empty_search_resolution_step(title: String) -> Dictionary:
	return build_empty_search_resolution_step_with_view_label(title, "查看牌库")


func build_empty_search_resolution_step_with_view_label(title: String, view_label: String) -> Dictionary:
	return {
		"id": "empty_search_resolution",
		"title": title,
		"items": [EMPTY_SEARCH_CONTINUE, EMPTY_SEARCH_VIEW_DECK],
		"labels": ["继续消耗", view_label],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}


func should_preview_empty_search_deck(resolved_context: Dictionary) -> bool:
	var selected_raw: Array = resolved_context.get("empty_search_resolution", [])
	if selected_raw.is_empty():
		return false
	return str(selected_raw[0]) == EMPTY_SEARCH_VIEW_DECK


func build_readonly_card_preview_step(
	title: String,
	cards: Array[CardInstance],
	close_label: String = "关闭并继续"
) -> Dictionary:
	var labels: Array[String] = []
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			labels.append("")
			continue
		if card.card_data.is_pokemon():
			labels.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
		else:
			labels.append(card.card_data.name)
	return {
		"id": "empty_search_view_deck",
		"title": title,
		"items": cards.duplicate(),
		"labels": labels,
		"min_select": 0,
		"max_select": 0,
		"allow_cancel": false,
		"presentation": "cards",
		"utility_actions": [{"label": close_label, "index": -1}],
	}


func build_readonly_deck_preview_step(title: String, deck_cards: Array[CardInstance]) -> Dictionary:
	return build_readonly_card_preview_step(title, deck_cards)


func build_attached_card_groups(player: PlayerState, card_items: Array) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	if player == null:
		return groups
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		var group_indices: Array[int] = []
		for i: int in card_items.size():
			var item: Variant = card_items[i]
			if not (item is CardInstance):
				continue
			var card_item := item as CardInstance
			if card_item in slot.attached_energy or slot.attached_tool == card_item:
				group_indices.append(i)
		if not group_indices.is_empty():
			groups.append({
				"slot": slot,
				"card_indices": group_indices,
				"energy_indices": group_indices,
			})
	return groups
