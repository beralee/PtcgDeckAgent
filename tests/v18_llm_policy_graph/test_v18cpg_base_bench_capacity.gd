extends SceneTree

const ObservationGatewayScript = preload(
	"res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd"
)
const FactBuilderScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd"
)
const ResourceLedgerScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGResourceLedger.gd"
)
const RouteSearchScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd"
)
const MaterialDeltaScript = preload(
	"res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd"
)
const StrategyScript = preload(
	"res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd"
)
const TransitionStateScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionState.gd"
)
const TransitionEvaluatorScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGCandidateTransitionEvaluator.gd"
)

const AREA_ZERO_EFFECT_ID := "701eb0ccb34fe3d319ea1307bc36c1ef"
const COLLAPSED_STADIUM_EFFECT_ID := "fb3628071280487676f79281696ffbd9"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_area_zero_capacity_is_exact_and_per_player()
	_test_no_tera_keeps_default_capacity_under_area_zero()
	_test_collapsed_stadium_capacity_is_four()
	_test_fact_ledger_and_compact_wire_share_one_capacity()
	_test_capacity_change_is_a_material_delta()
	_test_development_candidate_knows_last_dynamic_slot()
	_test_transition_accepts_the_eighth_dynamic_slot()
	_test_stadium_replacement_exposes_overflow_risk()
	if _failures.is_empty():
		print("V18CPG Base bench capacity: PASS (8 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG Base bench capacity: FAIL (%d)" % _failures.size())
	quit(1)


func _test_area_zero_capacity_is_exact_and_per_player() -> void:
	var state := _state_with_stadium(AREA_ZERO_EFFECT_ID)
	state.players[0].active_pokemon = _pokemon_slot("OWN_TERA", true, 0)
	state.players[1].active_pokemon = _pokemon_slot("OPPONENT_BASIC", false, 1)
	_fill_bench(state.players[0], 5)
	_fill_bench(state.players[1], 5)
	var observation := ObservationGatewayScript.new().build(
		state,
		0,
		[{"kind": "end_turn"}]
	)
	var own: Dictionary = observation.get("own", {})
	var opponent: Dictionary = observation.get("opponent", {})
	_check(
		int(own.get("bench_capacity", -1)) == 8
			and int(own.get("bench_slots_free", -1)) == 3
			and not bool(own.get("bench_full", true)),
		"Area Zero must expose eight slots only for the side with a Tera Pokemon"
	)
	_check(
		int(opponent.get("bench_capacity", -1)) == 5
			and int(opponent.get("bench_slots_free", -1)) == 0
			and bool(opponent.get("bench_full", false)),
		"the opponent without a Tera Pokemon must remain at the default five slots"
	)


func _test_no_tera_keeps_default_capacity_under_area_zero() -> void:
	var state := _state_with_stadium(AREA_ZERO_EFFECT_ID)
	state.players[0].active_pokemon = _pokemon_slot("OWN_BASIC", false, 0)
	_fill_bench(state.players[0], 4)
	var own: Dictionary = ObservationGatewayScript.new().build(
		state,
		0,
		[]
	).get("own", {})
	_check(
		int(own.get("bench_capacity", -1)) == 5
			and int(own.get("bench_slots_free", -1)) == 1,
		"Area Zero visibility alone must not grant eight slots without a Tera Pokemon"
	)


func _test_collapsed_stadium_capacity_is_four() -> void:
	var state := _state_with_stadium(COLLAPSED_STADIUM_EFFECT_ID)
	state.players[0].active_pokemon = _pokemon_slot("OWN_TERA", true, 0)
	_fill_bench(state.players[0], 4)
	var own: Dictionary = ObservationGatewayScript.new().build(
		state,
		0,
		[]
	).get("own", {})
	_check(
		int(own.get("bench_capacity", -1)) == 4
			and int(own.get("bench_slots_free", -1)) == 0
			and bool(own.get("bench_full", false)),
		"Base observation must use the current engine limit even when it is below five"
	)


func _test_fact_ledger_and_compact_wire_share_one_capacity() -> void:
	var state := _state_with_stadium(AREA_ZERO_EFFECT_ID)
	state.players[0].active_pokemon = _pokemon_slot("OWN_TERA", true, 0)
	_fill_bench(state.players[0], 6)
	var observation := ObservationGatewayScript.new().build(state, 0, [])
	var facts := FactBuilderScript.new().build(observation)
	var ledger := ResourceLedgerScript.new().build(observation, {}, {})
	var compact: Dictionary = StrategyScript.new()._compact_observation_for_model(
		observation
	)
	var compact_own: Dictionary = compact.get("own", {})
	_check(
		int(facts.get("board", {}).get("bench_capacity", -1)) == 8
			and int(facts.get("resources", {}).get("bench_slots_free", -1)) == 2
			and int(ledger.get("available_now", {}).get("bench_slots", -1)) == 2
			and int(compact_own.get("bench_capacity", -1)) == 8
			and int(compact_own.get("bench_slots_free", -1)) == 2,
		"FactBuilder, ResourceLedger, and compact model wire must share the observed capacity"
	)


func _test_capacity_change_is_a_material_delta() -> void:
	var state := _state_with_stadium(AREA_ZERO_EFFECT_ID)
	state.players[0].active_pokemon = _pokemon_slot("OWN_TERA", true, 0)
	_fill_bench(state.players[0], 5)
	var gateway := ObservationGatewayScript.new()
	var before := gateway.build(state, 0, [{"kind": "end_turn"}])
	var before_facts := FactBuilderScript.new().build(before)
	state.stadium_card = null
	var after := gateway.build(state, 0, [{"kind": "end_turn"}])
	var after_facts := FactBuilderScript.new().build(after)
	var delta := MaterialDeltaScript.new().compare(
		before,
		after,
		before_facts,
		after_facts
	)
	_check(
		bool(delta.get("material", false))
			and "board.bench_capacity" in delta.get("changed_facts", [])
			and "resources.bench_slots_free" in delta.get("changed_facts", []),
		"losing an expanded Bench must invalidate stale graph branches as a material delta"
	)


func _test_development_candidate_knows_last_dynamic_slot() -> void:
	var observation := _synthetic_observation(8, 7)
	observation["legal_actions"] = [{
		"id": "action:bench:last",
		"kind": "play_basic_to_bench",
		"card": {
			"instance_id": 99,
			"uid": "BASIC_ROOT",
			"type": "Pokemon",
			"stage": "Basic",
		},
	}]
	var facts := FactBuilderScript.new().build(observation)
	var candidates := RouteSearchScript.new().build_candidate_pool(
		observation,
		{"action:bench:last": 10.0},
		{},
		facts
	)
	var outcome: Dictionary = candidates[0].get("outcome", {}) \
		if not candidates.is_empty() else {}
	var compact_outcome := StrategyScript.new()._compact_outcome_for_model(
		outcome
	)
	_check(
		int(outcome.get("bench_capacity", -1)) == 8
			and int(outcome.get("bench_slots_before", -1)) == 1
			and int(outcome.get("bench_slots_after", -1)) == 0
			and bool(outcome.get("consumes_last_bench_slot", false))
			and int(compact_outcome.get("bench_capacity", -1)) == 8
			and int(compact_outcome.get("bench_slots_before", -1)) == 1
			and bool(
				compact_outcome.get("consumes_last_bench_slot", false)
			),
		"a Bench-development candidate must account for the exact current capacity"
	)


func _test_stadium_replacement_exposes_overflow_risk() -> void:
	var observation := _synthetic_observation(8, 7)
	observation["opponent"]["bench_capacity"] = 8
	observation["opponent"]["bench_count"] = 6
	observation["opponent"]["bench_slots_free"] = 2
	observation["opponent"]["overflow_if_default_capacity"] = 1
	observation["legal_actions"] = [{
		"id": "action:replace:stadium",
		"kind": "play_stadium",
		"card": {
			"instance_id": 100,
			"uid": "OTHER_STADIUM",
			"effect_id": "OTHER_EFFECT",
			"type": "Stadium",
		},
	}]
	var facts := FactBuilderScript.new().build(observation)
	var candidates := RouteSearchScript.new().build_candidate_pool(
		observation,
		{"action:replace:stadium": 10.0},
		{},
		facts
	)
	var outcome: Dictionary = candidates[0].get("outcome", {}) \
		if not candidates.is_empty() else {}
	var compact_outcome := StrategyScript.new()._compact_outcome_for_model(
		outcome
	)
	_check(
		bool(outcome.get("bench_capacity_drop_risk", false))
			and int(outcome.get("own_bench_overflow_if_default", 0)) == 2
			and int(outcome.get("opponent_bench_overflow_if_default", 0)) == 1,
		"replacing an expansion Stadium must expose both sides' public cleanup risk"
	)
	_check(
		bool(compact_outcome.get("bench_capacity_drop_risk", false))
			and int(
				compact_outcome.get("own_bench_overflow_if_default", 0)
			) == 2
			and int(
				compact_outcome.get(
					"opponent_bench_overflow_if_default",
					0
				)
			) == 1,
		"Bench-capacity risk must survive compact model transport"
	)


func _test_transition_accepts_the_eighth_dynamic_slot() -> void:
	var observation := _synthetic_observation(8, 7)
	observation["legal_actions"] = [{
		"id": "action:bench:eighth",
		"kind": "play_basic_to_bench",
		"card": {
			"instance_id": 101,
			"uid": "EIGHTH_BASIC",
			"type": "Pokemon",
			"stage": "Basic",
			"hp": 100,
		},
	}]
	var facts := FactBuilderScript.new().build(observation)
	var ledger := ResourceLedgerScript.new().build(observation, {}, {})
	var candidates := RouteSearchScript.new().build_candidate_pool(
		observation,
		{"action:bench:eighth": 10.0},
		{},
		facts
	)
	var transition_state := TransitionStateScript.new().build(
		observation,
		ledger,
		facts,
		{}
	)
	var transition := TransitionEvaluatorScript.new().evaluate(
		candidates[0] if not candidates.is_empty() else {},
		transition_state,
		observation
	)
	var predicted_own: Dictionary = transition.get(
		"predicted_state",
		{}
	).get("own", {})
	_check(
		bool(transition.get("supported", false))
			and int(predicted_own.get("bench_count", -1)) == 8
			and int(predicted_own.get("bench_slots_free", -1)) == 0
			and bool(predicted_own.get("bench_full", false)),
		"route-value transition search must accept and account for the eighth slot"
	)


func _state_with_stadium(effect_id: String) -> GameState:
	var state := GameState.new()
	state.players = [_player(0), _player(1)]
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	var data := CardData.new()
	data.name = "Fixture Stadium"
	data.name_en = "Fixture Stadium"
	data.card_type = "Stadium"
	data.effect_id = effect_id
	data.set_code = "TEST"
	data.card_index = effect_id.left(6)
	state.stadium_card = CardInstance.create(data, 0)
	return state


func _player(index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = index
	return player


func _fill_bench(player: PlayerState, count: int) -> void:
	for index: int in count:
		player.bench.append(
			_pokemon_slot("BENCH_%d_%d" % [player.player_index, index], false, player.player_index)
		)


func _pokemon_slot(name: String, tera: bool, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 100
	data.ancient_trait = "Tera" if tera else ""
	data.set_code = "TEST"
	data.card_index = name
	var slot := PokemonSlot.new()
	slot.pokemon_stack = [CardInstance.create(data, owner)]
	return slot


func _synthetic_observation(capacity: int, bench_count: int) -> Dictionary:
	var bench: Array[Dictionary] = []
	for index: int in bench_count:
		bench.append({
			"slot_id": "own:bench:%d" % index,
			"pokemon": {"uid": "BENCH_%d" % index, "stage": "Basic"},
			"energy": [],
			"energy_count": 0,
			"remaining_hp": 100,
			"max_hp": 100,
			"prize_count": 1,
		})
	return {
		"turn": {
			"number": 4,
			"quotas": {
				"energy_available": true,
				"supporter_available": true,
				"stadium_available": true,
				"retreat_available": true,
			},
		},
		"own": {
			"hand": [],
			"hand_count": 0,
			"deck_count": 30,
			"prizes_remaining": 4,
			"active": {
				"slot_id": "own:active",
				"pokemon": {"uid": "ACTIVE", "stage": "Basic"},
				"energy": [],
				"energy_count": 0,
				"remaining_hp": 100,
				"max_hp": 100,
				"prize_count": 1,
			},
			"bench": bench,
			"bench_count": bench_count,
			"bench_capacity": capacity,
			"bench_slots_free": maxi(0, capacity - bench_count),
			"bench_full": bench_count >= capacity,
			"overflow_count": maxi(0, bench_count - capacity),
			"overflow_if_default_capacity": maxi(0, bench_count - 5),
		},
		"opponent": {
			"active": {
				"slot_id": "opponent:active",
				"pokemon": {"uid": "TARGET", "stage": "Basic"},
				"remaining_hp": 100,
				"max_hp": 100,
				"prize_count": 1,
			},
			"bench": [],
			"bench_count": 0,
			"bench_capacity": 5,
			"bench_slots_free": 5,
			"bench_full": false,
			"overflow_count": 0,
			"overflow_if_default_capacity": 0,
			"prizes_remaining": 4,
		},
		"stadium": {
			"uid": "CSV9C_207",
			"effect_id": AREA_ZERO_EFFECT_ID,
			"type": "Stadium",
		},
		"legal_actions": [],
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
