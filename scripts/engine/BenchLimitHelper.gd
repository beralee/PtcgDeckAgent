class_name BenchLimitHelper
extends RefCounted

const DEFAULT_BENCH_LIMIT := 5
const EffectCollapsedStadiumScript = preload("res://scripts/effects/stadium_effects/EffectCollapsedStadium.gd")
const EffectAreaZeroUnderdepthsScript = preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")
const AbilityDustFieldScript = preload("res://scripts/effects/pokemon_effects/AbilityDustField.gd")


static func get_bench_limit(
	state: GameState,
	player: PlayerState = null,
	effect_processor: EffectProcessor = null
) -> int:
	if state == null:
		return DEFAULT_BENCH_LIMIT
	var limit := _stadium_bench_limit(state, player)
	if player != null and _opponent_has_active_dust_field(state, player, effect_processor):
		limit = mini(limit, int(AbilityDustFieldScript.BENCH_LIMIT))
	return limit


static func get_bench_limit_for_player(
	state: GameState,
	player: PlayerState,
	effect_processor: EffectProcessor = null
) -> int:
	return get_bench_limit(state, player, effect_processor)


static func get_available_bench_space(
	state: GameState,
	player: PlayerState,
	effect_processor: EffectProcessor = null
) -> int:
	if player == null:
		return 0
	return maxi(0, get_bench_limit_for_player(state, player, effect_processor) - player.bench.size())


static func is_bench_full(
	state: GameState,
	player: PlayerState,
	effect_processor: EffectProcessor = null
) -> bool:
	if player == null:
		return true
	return player.bench.size() >= get_bench_limit_for_player(state, player, effect_processor)


static func _stadium_bench_limit(state: GameState, player: PlayerState) -> int:
	if state.stadium_card == null or state.stadium_card.card_data == null:
		return DEFAULT_BENCH_LIMIT
	var effect_id: String = str(state.stadium_card.card_data.effect_id)
	if effect_id == EffectCollapsedStadiumScript.EFFECT_ID:
		return int(EffectCollapsedStadiumScript.BENCH_LIMIT)
	if EffectAreaZeroUnderdepthsScript.matches_effect_id(effect_id):
		if player == null:
			return int(EffectAreaZeroUnderdepthsScript.EXPANDED_BENCH_LIMIT)
		return int(EffectAreaZeroUnderdepthsScript.static_bench_limit_for_player(player, state))
	return DEFAULT_BENCH_LIMIT


static func _opponent_has_active_dust_field(
	state: GameState,
	player: PlayerState,
	effect_processor: EffectProcessor
) -> bool:
	var player_index := state.players.find(player)
	if player_index < 0:
		player_index = player.player_index
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	var source: PokemonSlot = state.players[opponent_index].active_pokemon
	if not AbilityDustFieldScript.is_active_source(source):
		return false
	var processor: Variant = effect_processor
	if processor == null:
		processor = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_ability_disabled"):
		return not bool(processor.call("is_ability_disabled", source, state))
	return true
