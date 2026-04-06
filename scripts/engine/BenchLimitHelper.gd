class_name BenchLimitHelper
extends RefCounted

const DEFAULT_BENCH_LIMIT := 5
const EffectCollapsedStadiumScript = preload("res://scripts/effects/stadium_effects/EffectCollapsedStadium.gd")


static func get_bench_limit(state: GameState) -> int:
	if state == null or state.stadium_card == null or state.stadium_card.card_data == null:
		return DEFAULT_BENCH_LIMIT
	var effect_id: String = str(state.stadium_card.card_data.effect_id)
	if effect_id == EffectCollapsedStadiumScript.EFFECT_ID:
		return int(EffectCollapsedStadiumScript.BENCH_LIMIT)
	return DEFAULT_BENCH_LIMIT


static func get_available_bench_space(state: GameState, player: PlayerState) -> int:
	if player == null:
		return 0
	return maxi(0, get_bench_limit(state) - player.bench.size())


static func is_bench_full(state: GameState, player: PlayerState) -> bool:
	if player == null:
		return true
	return player.bench.size() >= get_bench_limit(state)
