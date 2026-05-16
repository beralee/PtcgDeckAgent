class_name BenchLimitHelper
extends RefCounted

const DEFAULT_BENCH_LIMIT := 5
const EffectCollapsedStadiumScript = preload("res://scripts/effects/stadium_effects/EffectCollapsedStadium.gd")
const EffectAreaZeroUnderdepthsScript = preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")


static func get_bench_limit(state: GameState, player: PlayerState = null) -> int:
	if state == null or state.stadium_card == null or state.stadium_card.card_data == null:
		return DEFAULT_BENCH_LIMIT
	var effect_id: String = str(state.stadium_card.card_data.effect_id)
	if effect_id == EffectCollapsedStadiumScript.EFFECT_ID:
		return int(EffectCollapsedStadiumScript.BENCH_LIMIT)
	if EffectAreaZeroUnderdepthsScript.matches_effect_id(effect_id):
		if player == null:
			return int(EffectAreaZeroUnderdepthsScript.EXPANDED_BENCH_LIMIT)
		return int(EffectAreaZeroUnderdepthsScript.static_bench_limit_for_player(player, state))
	return DEFAULT_BENCH_LIMIT


static func get_bench_limit_for_player(state: GameState, player: PlayerState) -> int:
	return get_bench_limit(state, player)


static func get_available_bench_space(state: GameState, player: PlayerState) -> int:
	if player == null:
		return 0
	return maxi(0, get_bench_limit_for_player(state, player) - player.bench.size())


static func is_bench_full(state: GameState, player: PlayerState) -> bool:
	if player == null:
		return true
	return player.bench.size() >= get_bench_limit_for_player(state, player)
