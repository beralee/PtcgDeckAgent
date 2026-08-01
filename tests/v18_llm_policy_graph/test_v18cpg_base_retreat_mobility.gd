extends SceneTree

const ObservationGatewayScript = preload(
	"res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd"
)
const FactBuilderScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd"
)
const RouteSearchScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd"
)
const StrategyScript = preload(
	"res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd"
)

const LATIAS_EX_UID := "CSV9C_078"
const LATIAS_EX_EFFECT_ID := "f8c2715403e3f4ea9783c46be2de832b"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_gateway_preserves_exact_zero_payment_proof()
	_test_latias_basic_active_exposes_global_zero_retreat_fact()
	_test_latias_does_not_mint_zero_retreat_for_evolution()
	_test_visible_provider_without_legal_action_is_not_execution_proof()
	_test_non_latias_zero_retreat_is_still_understood_by_base()
	_test_route_candidate_carries_zero_retreat_resource_semantics()
	_test_compact_model_wire_keeps_zero_retreat_proof()
	if _failures.is_empty():
		print("V18CPG Base retreat mobility: PASS (7 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG Base retreat mobility: FAIL (%d)" % _failures.size())
	quit(1)


func _test_gateway_preserves_exact_zero_payment_proof() -> void:
	var action_ref := ObservationGatewayScript.new().action_ref({
		"kind": "retreat",
		"energy_to_discard": [],
	})
	_check(
		bool(action_ref.get("engine_legal_retreat_proof", false))
			and bool(action_ref.get("zero_energy_retreat", false))
			and int(action_ref.get("retreat_payment_energy_count", -1)) == 0,
		"ObservationGateway must preserve the engine-authoritative empty retreat payment"
	)


func _test_latias_basic_active_exposes_global_zero_retreat_fact() -> void:
	var observation := _observation(
		_slot("own:active", "BASIC_ATTACKER", "Basic", 3),
		[_slot("own:bench:latias", LATIAS_EX_UID, "Basic", 2, LATIAS_EX_EFFECT_ID)],
		[_retreat_action("retreat:latias:free", "own:bench:latias", 0)]
	)
	var mobility: Dictionary = FactBuilderScript.new().build(observation).get("mobility", {})
	_check(
		bool(mobility.get("provider_visible", false))
			and mobility.get("provider_uids", []) == [LATIAS_EX_UID]
			and str(mobility.get("provider_scope", "")) == "own_basic_pokemon"
			and bool(mobility.get("active_is_basic", false)),
		"Base facts must identify Latias ex as a board-wide Basic retreat provider"
	)
	_check(
		bool(mobility.get("zero_retreat_available_now", false))
			and bool(mobility.get("engine_legal_proof", false))
			and mobility.get("zero_retreat_action_ids", []) == ["retreat:latias:free"],
		"Base facts must bind zero retreat to the exact currently legal action"
	)


func _test_latias_does_not_mint_zero_retreat_for_evolution() -> void:
	var observation := _observation(
		_slot("own:active", "STAGE_ONE_ATTACKER", "Stage 1", 2),
		[_slot("own:bench:latias", LATIAS_EX_UID, "Basic", 2, LATIAS_EX_EFFECT_ID)],
		[_retreat_action("retreat:evolution:paid", "own:bench:latias", 2)]
	)
	var mobility: Dictionary = FactBuilderScript.new().build(observation).get("mobility", {})
	_check(
		bool(mobility.get("provider_visible", false))
			and not bool(mobility.get("active_is_basic", true))
			and not bool(mobility.get("zero_retreat_available_now", true)),
		"Latias visibility must not turn an Evolution Pokemon's retreat into zero"
	)


func _test_visible_provider_without_legal_action_is_not_execution_proof() -> void:
	var observation := _observation(
		_slot("own:active", "BASIC_ATTACKER", "Basic", 3),
		[_slot("own:bench:latias", LATIAS_EX_UID, "Basic", 2, LATIAS_EX_EFFECT_ID)],
		[]
	)
	observation["turn"]["quotas"]["retreat_available"] = false
	var mobility: Dictionary = FactBuilderScript.new().build(observation).get("mobility", {})
	_check(
		bool(mobility.get("provider_visible", false))
			and not bool(mobility.get("engine_legal_proof", true))
			and not bool(mobility.get("zero_retreat_available_now", true)),
		"a visible provider must not fabricate an executable retreat after the quota is spent"
	)


func _test_non_latias_zero_retreat_is_still_understood_by_base() -> void:
	var observation := _observation(
		_slot("own:active", "PRINTED_FREE_RETREATER", "Basic", 0),
		[_slot("own:bench:target", "BENCH_TARGET", "Basic", 1)],
		[_retreat_action("retreat:printed:free", "own:bench:target", 0)]
	)
	var mobility: Dictionary = FactBuilderScript.new().build(observation).get("mobility", {})
	_check(
		not bool(mobility.get("provider_visible", true))
			and bool(mobility.get("zero_retreat_available_now", false))
			and mobility.get("zero_retreat_action_ids", []) == ["retreat:printed:free"],
		"Base mobility must understand every engine-confirmed zero retreat, not only Latias"
	)


func _test_route_candidate_carries_zero_retreat_resource_semantics() -> void:
	var observation := _observation(
		_slot("own:active", "BASIC_ATTACKER", "Basic", 3),
		[_slot("own:bench:latias", LATIAS_EX_UID, "Basic", 2, LATIAS_EX_EFFECT_ID)],
		[_retreat_action("retreat:latias:free", "own:bench:latias", 0)]
	)
	var facts := FactBuilderScript.new().build(observation)
	var frontier := RouteSearchScript.new().build_candidate_pool(
		observation,
		{"retreat:latias:free": 10.0},
		{},
		facts
	)
	var candidate: Dictionary = frontier[0] if not frontier.is_empty() else {}
	var action_ref: Dictionary = candidate.get("action_ref", {})
	var outcome: Dictionary = candidate.get("outcome", {})
	_check(
		bool(action_ref.get("zero_energy_retreat", false))
			and int(action_ref.get("retreat_payment_energy_count", -1)) == 0
			and bool(outcome.get("zero_energy_retreat", false))
			and bool(outcome.get("preserves_attached_energy", false)),
		"the exact retreat candidate must tell every deck that pivoting spends no attached Energy"
	)


func _test_compact_model_wire_keeps_zero_retreat_proof() -> void:
	var strategy := StrategyScript.new()
	var compact_action: Dictionary = strategy._compact_action_ref_for_model({
		"kind": "retreat",
		"target": "own:bench:latias",
		"retreat_payment_energy_count": 0,
		"zero_energy_retreat": true,
		"engine_legal_retreat_proof": true,
	})
	var compact_outcome: Dictionary = strategy._compact_outcome_for_model({
		"zero_energy_retreat": true,
		"preserves_attached_energy": true,
		"retreat_payment_energy_count": 0,
	})
	_check(
		bool(compact_action.get("zero_energy_retreat", false))
			and bool(compact_action.get("engine_legal_retreat_proof", false))
			and int(compact_action.get("retreat_payment_energy_count", -1)) == 0
			and bool(compact_outcome.get("zero_energy_retreat", false))
			and bool(compact_outcome.get("preserves_attached_energy", false)),
		"compact model payload must not erase the exact zero-retreat proof"
	)


func _observation(
	active: Dictionary,
	bench: Array,
	legal_actions: Array
) -> Dictionary:
	return {
		"turn": {
			"number": 6,
			"quotas": {
				"energy_available": true,
				"supporter_available": true,
				"retreat_available": true,
			},
		},
		"own": {
			"hand": [],
			"hand_count": 0,
			"deck_count": 30,
			"prizes_remaining": 4,
			"active": active,
			"bench": bench,
		},
		"opponent": {
			"active": _slot("opponent:active", "TARGET", "Basic", 1),
			"bench": [],
			"prizes_remaining": 4,
		},
		"legal_actions": legal_actions,
	}


func _slot(
	slot_id: String,
	uid: String,
	stage: String,
	printed_retreat_cost: int,
	effect_id: String = ""
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {
			"uid": uid,
			"effect_id": effect_id,
			"stage": stage,
		},
		"stage": stage,
		"energy": [],
		"energy_count": 0,
		"damage": 0,
		"remaining_hp": 200,
		"max_hp": 200,
		"prize_count": 2 if uid.ends_with("EX") else 1,
		"retreat_cost": printed_retreat_cost,
		"printed_retreat_cost": printed_retreat_cost,
	}


func _retreat_action(action_id: String, target_slot_id: String, payment_count: int) -> Dictionary:
	return {
		"id": action_id,
		"kind": "retreat",
		"target": target_slot_id,
		"retreat_payment_energy_count": payment_count,
		"zero_energy_retreat": payment_count == 0,
		"engine_legal_retreat_proof": true,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
