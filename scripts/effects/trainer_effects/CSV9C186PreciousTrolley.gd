class_name CSV9C186PreciousTrolley
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")

const STEP_ID := "csv9c186_basic_pokemon"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not BenchLimit.is_bench_full(state, player) and not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not BenchLimit.is_bench_full(state, player) and not _get_basic_pokemon(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if BenchLimit.is_bench_full(state, player):
		return []
	var items := _get_basic_pokemon(player)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有基础宝可梦。你仍可以使用贵重推车。")]
	var open_slots: int = BenchLimit.get_available_bench_space(state, player)
	return [build_full_library_search_step(
		STEP_ID,
		"选择任意数量基础宝可梦放到备战区",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(open_slots, items.size()),
		{"allow_cancel": true}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, state.players[card.owner_index].deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx := get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in player.deck and (entry as CardInstance).card_data.is_basic_pokemon() and entry not in selected:
			selected.append(entry)
	if selected.is_empty() and not has_explicit_selection:
		selected = _get_basic_pokemon(player)
	for pokemon_card: CardInstance in selected:
		if BenchLimit.is_bench_full(state, player):
			break
		if pokemon_card not in player.deck or not pokemon_card.card_data.is_basic_pokemon():
			continue
		player.deck.erase(pokemon_card)
		pokemon_card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(pokemon_card)
		slot.turn_played = state.turn_number
		player.bench.append(slot)
	player.shuffle_deck()


func _get_basic_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data != null and deck_card.card_data.is_basic_pokemon():
			result.append(deck_card)
	return result


func get_description() -> String:
	return "从牌库选择任意数量基础宝可梦放到备战区。"
