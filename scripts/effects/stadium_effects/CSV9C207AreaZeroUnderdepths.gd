class_name CSV9C207AreaZeroUnderdepths
extends BaseEffect

const H = preload("res://scripts/effects/CSV9CHelpers.gd")

const EFFECT_ID := "701eb0ccb34fe3d319ea1307bc36c1ef"
const REMOTE_EFFECT_ID := "cf3124da3d7bf217f7969b6ae4e60e38"
const EXPANDED_BENCH_LIMIT := 8
const DEFAULT_BENCH_LIMIT := 5
const STEP_ID_PREFIX := "csv9c207_zero_area_discard_p"


static func matches_effect_id(effect_id: String) -> bool:
	return effect_id == EFFECT_ID or effect_id == REMOTE_EFFECT_ID


static func is_area_zero_active(state: GameState) -> bool:
	return (
		state != null
		and state.stadium_card != null
		and state.stadium_card.card_data != null
		and matches_effect_id(str(state.stadium_card.card_data.effect_id))
	)


func get_bench_limit_for_player(player: PlayerState, _state: GameState) -> int:
	return EXPANDED_BENCH_LIMIT if player_has_tera(player) else DEFAULT_BENCH_LIMIT


static func static_bench_limit_for_player(player: PlayerState, state: GameState) -> int:
	if not is_area_zero_active(state):
		return DEFAULT_BENCH_LIMIT
	return EXPANDED_BENCH_LIMIT if player_has_tera(player) else DEFAULT_BENCH_LIMIT


func execute_on_play(_card: CardInstance, _state: GameState, _targets: Array = []) -> void:
	# Playing Area Zero itself never forces a trim; it only expands players that
	# currently have Tera Pokemon in play.
	pass


static func build_cleanup_interaction_steps(
	state: GameState,
	start_player_index: int = 0,
	override_limit: int = DEFAULT_BENCH_LIMIT
) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if state == null:
		return steps
	for pi: int in _cleanup_order(state, start_player_index):
		var player: PlayerState = state.players[pi]
		var limit := override_limit
		if is_area_zero_active(state):
			limit = static_bench_limit_for_player(player, state)
		var excess := player.bench.size() - limit
		if excess <= 0:
			continue
		var labels: Array[String] = []
		for slot: PokemonSlot in player.bench:
			labels.append(H.slot_label(slot, state))
		steps.append({
			"id": "%s%d" % [STEP_ID_PREFIX, pi],
			"title": "选择玩家%d要弃掉的%d只备战宝可梦" % [pi + 1, excess],
			"items": player.bench.duplicate(),
			"labels": labels,
			"min_select": excess,
			"max_select": excess,
			"allow_cancel": false,
			"presentation": "cards",
			"force_dialog": true,
			"chooser_player_index": pi,
		})
	return steps


static func enforce_bench_limits(
	state: GameState,
	targets: Array = [],
	start_player_index: int = 0
) -> Array[Dictionary]:
	var discarded_by_player: Array[Dictionary] = []
	if state == null:
		return discarded_by_player
	var ctx := _interaction_context(targets)
	for pi: int in _cleanup_order(state, start_player_index):
		var player: PlayerState = state.players[pi]
		var limit := static_bench_limit_for_player(player, state)
		var excess := player.bench.size() - limit
		if excess <= 0:
			continue
		var slots_to_discard := resolve_discarded_slots(player, ctx, pi, excess)
		var discarded_cards: Array[CardInstance] = []
		var discarded_names: Array[String] = []
		for slot: PokemonSlot in slots_to_discard:
			if slot == null or slot not in player.bench:
				continue
			player.bench.erase(slot)
			discarded_names.append(slot.get_pokemon_name())
			for card: CardInstance in slot.collect_all_cards():
				player.discard_card(card)
				discarded_cards.append(card)
		if not discarded_cards.is_empty():
			discarded_by_player.append({
				"player_index": pi,
				"limit": limit,
				"discarded_cards": discarded_cards,
				"discarded_names": discarded_names,
			})
	return discarded_by_player


static func player_has_tera(player: PlayerState) -> bool:
	return H.player_has_tera(player)


static func _is_tera_slot(slot: PokemonSlot) -> bool:
	return H.is_tera_slot(slot)


static func resolve_discarded_slots(
	player: PlayerState,
	ctx: Dictionary,
	player_index: int,
	excess: int
) -> Array[PokemonSlot]:
	var chosen: Array[PokemonSlot] = []
	var step_id := "%s%d" % [STEP_ID_PREFIX, player_index]
	var selected_raw: Array = ctx.get(step_id, [])
	for entry: Variant in selected_raw:
		if not (entry is PokemonSlot):
			continue
		var slot: PokemonSlot = entry as PokemonSlot
		if slot in player.bench and slot not in chosen:
			chosen.append(slot)
			if chosen.size() >= excess:
				return chosen

	for idx: int in range(player.bench.size() - 1, -1, -1):
		var fallback_slot: PokemonSlot = player.bench[idx]
		if fallback_slot in chosen:
			continue
		chosen.append(fallback_slot)
		if chosen.size() >= excess:
			break
	return chosen


static func _interaction_context(targets: Array) -> Dictionary:
	if targets.is_empty():
		return {}
	var ctx: Variant = targets[0]
	return ctx.duplicate(false) if ctx is Dictionary else {}


static func _cleanup_order(state: GameState, start_player_index: int) -> Array[int]:
	if state == null or state.players.is_empty():
		return []
	if start_player_index >= 0 and start_player_index < state.players.size():
		var order: Array[int] = [start_player_index]
		for pi: int in state.players.size():
			if pi != start_player_index:
				order.append(pi)
		return order
	var fallback: Array[int] = []
	for pi: int in state.players.size():
		fallback.append(pi)
	return fallback


func get_description() -> String:
	return "自己场上有太晶宝可梦的玩家备战区上限变为8；失效时弃到5只。"
