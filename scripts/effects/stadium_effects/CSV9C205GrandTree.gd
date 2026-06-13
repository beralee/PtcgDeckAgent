class_name CSV9C205GrandTree
extends BaseEffect

const STAGE1_STEP_ID := "csv9c205_stage1_assignment"
const STAGE2_STEP_ID := "csv9c205_stage2_assignment"
const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	if state.is_first_turn_for_player(state.current_player_index):
		return false
	return not _build_stage1_pairs(state.players[state.current_player_index], state).is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	var pairs := _build_stage1_pairs(player, state)
	if pairs.is_empty():
		return []
	var source_items := _unique_sources(pairs)
	var target_items := _eligible_basic_targets(player, state)
	var source_labels: Array[String] = []
	for source: CardInstance in source_items:
		source_labels.append(source.card_data.name)
	var target_labels: Array[String] = []
	for target: PokemonSlot in target_items:
		target_labels.append(H.slot_label(target, state))
	var step := build_full_library_card_assignment_step(
		STAGE1_STEP_ID,
		"选择牌库中1张1阶进化宝可梦，使场上基础宝可梦进化",
		player.deck,
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		true
	)
	step["source_exclude_targets"] = _build_source_exclude_targets(source_items, target_items)
	step["requires_followup_interaction"] = true
	step["compact_field_assignment_after_source"] = true
	return [step]


func get_followup_interaction_steps(_card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	var assignment := _resolve_stage1_assignment(player, state, resolved_context)
	if assignment.is_empty():
		return []
	var stage1_card: CardInstance = assignment.get("source")
	var target_slot: PokemonSlot = assignment.get("target")
	if stage1_card == null or target_slot == null:
		return []
	var stage2_items := _get_stage2_for_stage1(player, stage1_card)
	if stage2_items.is_empty():
		return []
	var labels: Array[String] = []
	for stage2_card: CardInstance in stage2_items:
		labels.append(stage2_card.card_data.name)
	var target_label := "%s -> %s" % [target_slot.get_pokemon_name(), stage1_card.card_data.name]
	var step := build_full_library_card_assignment_step(
		STAGE2_STEP_ID,
		"可继续选择1张2阶进化宝可梦进化",
		player.deck,
		stage2_items,
		labels,
		[target_slot],
		[target_label],
		0,
		1,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		true
	)
	step["compact_field_assignment_after_source"] = true
	return [step]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[state.current_player_index]
	if state.is_first_turn_for_player(state.current_player_index):
		return
	var ctx := get_interaction_context(targets)
	var stage1_assignment := _resolve_stage1_assignment(player, state, ctx)
	if stage1_assignment.is_empty() and not ctx.has(STAGE1_STEP_ID):
		var pairs := _build_stage1_pairs(player, state)
		stage1_assignment = pairs[0] if not pairs.is_empty() else {}
	if stage1_assignment.is_empty():
		player.shuffle_deck()
		return

	var stage1_card: CardInstance = stage1_assignment.get("source")
	var target_slot: PokemonSlot = stage1_assignment.get("target")
	if not _evolve_from_deck(player, target_slot, stage1_card, state):
		player.shuffle_deck()
		return

	var stage2_assignment := _resolve_stage2_assignment(player, target_slot, stage1_card, ctx)
	var stage2_card: CardInstance = stage2_assignment.get("source", null)
	if stage2_card != null:
		_evolve_from_deck(player, target_slot, stage2_card, state)
	player.shuffle_deck()


func _resolve_stage1_assignment(player: PlayerState, state: GameState, ctx: Dictionary) -> Dictionary:
	for entry: Variant in ctx.get(STAGE1_STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var source: Variant = (entry as Dictionary).get("source")
		var target: Variant = (entry as Dictionary).get("target")
		if source is CardInstance and target is PokemonSlot and _is_valid_stage1_pair(player, state, source, target):
			return {"source": source, "target": target}
	return {}


func _resolve_stage2_assignment(player: PlayerState, target_slot: PokemonSlot, stage1_card: CardInstance, ctx: Dictionary) -> Dictionary:
	for entry: Variant in ctx.get(STAGE2_STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var source: Variant = (entry as Dictionary).get("source")
		var target: Variant = (entry as Dictionary).get("target")
		if source is CardInstance and target == target_slot and source in _get_stage2_for_stage1(player, stage1_card):
			return {"source": source, "target": target_slot}
	return {}


func _evolve_from_deck(player: PlayerState, target_slot: PokemonSlot, evolution_card: CardInstance, state: GameState) -> bool:
	if target_slot == null or evolution_card == null or evolution_card not in player.deck:
		return false
	player.deck.erase(evolution_card)
	evolution_card.face_up = true
	target_slot.pokemon_stack.append(evolution_card)
	target_slot.turn_evolved = state.turn_number
	target_slot.clear_all_status()
	return true


func _build_stage1_pairs(player: PlayerState, state: GameState) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for source: CardInstance in player.deck:
		if source.card_data == null or source.card_data.stage != "Stage 1":
			continue
		for target: PokemonSlot in _eligible_basic_targets(player, state):
			if _stage_evolves_from_slot(source.card_data, target):
				pairs.append({"source": source, "target": target})
	return pairs


func _eligible_basic_targets(player: PlayerState, state: GameState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		if not slot.get_card_data().is_basic_pokemon():
			continue
		if slot.turn_played == state.turn_number:
			continue
		if slot.turn_evolved == state.turn_number:
			continue
		result.append(slot)
	return result


func _unique_sources(pairs: Array[Dictionary]) -> Array:
	var result: Array = []
	for pair: Dictionary in pairs:
		var source: CardInstance = pair.get("source")
		if source != null and source not in result:
			result.append(source)
	return result


func _build_source_exclude_targets(source_items: Array, target_items: Array) -> Dictionary:
	var exclude_map := {}
	for source_index: int in source_items.size():
		var source: CardInstance = source_items[source_index]
		var excluded: Array[int] = []
		for target_index: int in target_items.size():
			var target: PokemonSlot = target_items[target_index]
			if source == null or source.card_data == null or not _stage_evolves_from_slot(source.card_data, target):
				excluded.append(target_index)
		exclude_map[source_index] = excluded
	return exclude_map


func _is_valid_stage1_pair(player: PlayerState, state: GameState, source: CardInstance, target: PokemonSlot) -> bool:
	return source in player.deck and source.card_data != null and source.card_data.stage == "Stage 1" and target in _eligible_basic_targets(player, state) and _stage_evolves_from_slot(source.card_data, target)


func _get_stage2_for_stage1(player: PlayerState, stage1_card: CardInstance) -> Array:
	var result: Array = []
	if stage1_card == null or stage1_card.card_data == null:
		return result
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data == null or deck_card.card_data.stage != "Stage 2":
			continue
		if _name_matches(deck_card.card_data.evolves_from, stage1_card.card_data):
			result.append(deck_card)
	return result


func _stage_evolves_from_slot(evolution_data: CardData, target_slot: PokemonSlot) -> bool:
	if evolution_data == null or target_slot == null:
		return false
	return _name_matches(evolution_data.evolves_from, target_slot.get_card_data())


func _name_matches(evolves_from: String, base_data: CardData) -> bool:
	if base_data == null:
		return false
	var wanted := evolves_from.strip_edges()
	if wanted == "":
		return false
	return wanted == base_data.name or (base_data.name_en != "" and wanted == base_data.name_en)


func get_description() -> String:
	return "每回合1次，从牌库让场上一只可进化的基础宝可梦进化为1阶，之后可继续进化为2阶。"
