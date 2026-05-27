## 巢穴球 - 从牌库选择 1 张基础宝可梦放入备战区。
class_name EffectNestBall
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if BenchLimit.is_bench_full(state, player):
		return []
	var items: Array = _get_basic_targets(player)
	var labels: Array[String] = []
	for c: CardInstance in items:
		labels.append("%s (HP %d)" % [c.card_data.name, c.card_data.hp])
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有可放到备战区的基础宝可梦。你仍可以使用巢穴球。")]
	return [build_full_library_search_step(
		"basic_pokemon",
		"选择 1 张基础宝可梦放入备战区",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true}
	)]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not BenchLimit.is_bench_full(state, player)


func get_unusable_reason(card: CardInstance, state: GameState) -> String:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return "巢穴球当前无法使用。"
	var player: PlayerState = state.players[card.owner_index]
	if BenchLimit.is_bench_full(state, player):
		return "你的备战区已经满了，巢穴球无法再放置基础宝可梦。"
	return ""


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	if BenchLimit.is_bench_full(state, player):
		return false
	return not _get_basic_targets(player).is_empty()


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("巢穴球：查看剩余牌库", player.deck)]


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	if BenchLimit.is_bench_full(state, player):
		player.shuffle_deck()
		return
	var ctx: Dictionary = get_interaction_context(_targets)

	var pokemon: CardInstance = null
	var selected_raw: Array = ctx.get("basic_pokemon", [])
	var has_explicit_selection: bool = ctx.has("basic_pokemon")
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected: CardInstance = entry
		if selected in player.deck and selected.card_data.is_basic_pokemon():
			pokemon = selected
			break
	if pokemon == null and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data.is_basic_pokemon():
				pokemon = deck_card
				break

	if pokemon == null:
		player.shuffle_deck()
		return

	player.deck.erase(pokemon)
	if BenchLimit.is_bench_full(state, player):
		player.deck.append(pokemon)
		player.shuffle_deck()
		return

	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(pokemon)
	slot.turn_played = state.turn_number
	player.bench.append(slot)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库选择 1 张基础宝可梦放入备战区，然后重洗牌库。"


func _get_basic_targets(player: PlayerState) -> Array:
	var items: Array = []
	for c: CardInstance in player.deck:
		if c.card_data.is_basic_pokemon():
			items.append(c)
	return items
