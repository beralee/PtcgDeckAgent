## 友好宝芬 - 从牌库选择最多 2 张 HP70 以下的基础宝可梦放入备战区。
class_name EffectBuddyPoffin
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var bench_space: int = BenchLimit.get_available_bench_space(state, player)
	if bench_space <= 0:
		return []
	var items: Array = _get_poffin_targets(player)
	var labels: Array[String] = []
	for c: CardInstance in items:
		labels.append("%s (HP %d)" % [c.card_data.name, c.card_data.hp])
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有 HP70 以下的基础宝可梦。你仍可以使用友好宝芬。")]
	return [{
		"id": "buddy_poffin_pokemon",
		"title": "选择最多 2 张 HP 不高于 70 的基础宝可梦放入备战区",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(2, bench_space),
		"allow_cancel": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not BenchLimit.is_bench_full(state, player)


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	if BenchLimit.is_bench_full(state, player):
		return false
	return not _get_poffin_targets(player).is_empty()


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("友好宝芬：查看剩余牌库", player.deck)]


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var bench_space: int = BenchLimit.get_available_bench_space(state, player)
	var to_place: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("buddy_poffin_pokemon", [])
	var has_explicit_selection: bool = ctx.has("buddy_poffin_pokemon")
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.deck and c.card_data.is_basic_pokemon() and c.card_data.hp <= 70:
			to_place.append(c)
			if to_place.size() >= bench_space or to_place.size() >= 2:
				break

	if to_place.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			var cd: CardData = deck_card.card_data
			if cd.is_basic_pokemon() and cd.hp <= 70:
				to_place.append(deck_card)
				if to_place.size() >= bench_space or to_place.size() >= 2:
					break

	for pokemon: CardInstance in to_place:
		player.deck.erase(pokemon)

	for pokemon: CardInstance in to_place:
		if BenchLimit.is_bench_full(state, player):
			player.deck.append(pokemon)
			continue
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(pokemon)
		slot.turn_played = state.turn_number
		player.bench.append(slot)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库选择最多 2 张 HP70 以下的基础宝可梦放入备战区，然后重洗牌库。"


func _get_poffin_targets(player: PlayerState) -> Array:
	var items: Array = []
	for c: CardInstance in player.deck:
		if c.card_data.is_basic_pokemon() and c.card_data.hp <= 70:
			items.append(c)
	return items
