## 深钵镇 - 竞技场
## 双方每回合1次，可从牌库中检索1只基础宝可梦（非规则宝可梦）放到备战区。洗牌。
class_name EffectArtazon
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	return not BenchLimit.is_bench_full(state, player)


func can_headless_execute(_card: CardInstance, state: GameState) -> bool:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	if BenchLimit.is_bench_full(state, player):
		return false
	return not _get_valid_pokemon(player).is_empty()


func build_ucis_interaction_steps_spec_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	if BenchLimit.is_bench_full(state, player):
		return []
	var items: Array = _get_valid_pokemon(player)
	var labels: Array[String] = []
	for deck_card: CardInstance in items:
		labels.append(deck_card.card_data.name)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有可放到备战区的非规则基础宝可梦。你仍可以使用深钵镇。")]
	return [build_full_library_search_step(
		"artazon_pokemon",
		"选择1只基础宝可梦放到备战区",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true}
	)]


func build_ucis_followup_interaction_steps_spec_steps(_card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[state.current_player_index]
	return [build_readonly_deck_preview_step("深钵镇：查看剩余牌库", player.deck)]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("artazon_pokemon", [])
	var has_explicit_selection: bool = ctx.has("artazon_pokemon")

	var chosen: CardInstance = null
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var candidate: CardInstance = entry
		if candidate in player.deck and _is_valid_pokemon(candidate):
			chosen = candidate
			break
	if chosen == null and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if _is_valid_pokemon(deck_card):
				chosen = deck_card
				break
	if chosen == null:
		return
	if BenchLimit.is_bench_full(state, player):
		return

	player.deck.erase(chosen)
	chosen.face_up = true
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(chosen)
	slot.turn_played = state.turn_number
	player.bench.append(slot)
	player.shuffle_deck()


func _is_valid_pokemon(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if not card.card_data.is_pokemon():
		return false
	if card.card_data.stage != "Basic":
		return false
	var mechanic: String = card.card_data.mechanic
	if mechanic != "" and mechanic != "none":
		return false
	return true


func _get_valid_pokemon(player: PlayerState) -> Array:
	var items: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_valid_pokemon(deck_card):
			items.append(deck_card)
	return items


func get_description() -> String:
	return "竞技场【深钵镇】：每回合1次，从牌库检索1只基础宝可梦（非规则宝可梦）放到备战区。"
