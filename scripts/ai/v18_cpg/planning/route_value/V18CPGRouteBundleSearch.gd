class_name V18CPGRouteBundleSearch
extends RefCounted

const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)
const TransitionStateScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionState.gd"
)
const TransitionEvaluatorScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGCandidateTransitionEvaluator.gd"
)
const TransitionRegistryScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionRegistry.gd"
)
const ContinuityDemandScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGContinuityDemandSolver.gd"
)
const ResponseEnvelopeScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGOpponentResponseEnvelopeV2.gd"
)
const OutcomeEvaluatorScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteOutcomeEvaluator.gd"
)
const RagingExtensionScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltRouteBundleExtension.gd"
)

var _transition_state = TransitionStateScript.new()
var _transition_evaluator = TransitionEvaluatorScript.new()
var _transition_registry = TransitionRegistryScript.new()
var _continuity_demand = ContinuityDemandScript.new()
var _response_envelope = ResponseEnvelopeScript.new()
var _outcome_evaluator = OutcomeEvaluatorScript.new()
var _raging_extension = RagingExtensionScript.new()
var _last_metrics: Dictionary = {}


func build(
	candidate_pool: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	resource_ledger: Dictionary,
	profile: Dictionary,
	prize_clock: Dictionary
) -> Array[Dictionary]:
	var started_usec := Time.get_ticks_usec()
	var config: Dictionary = profile.get("route_value_graph_v3", {}) \
		if profile.get("route_value_graph_v3", {}) is Dictionary else {}
	var max_depth := clampi(int(config.get("max_bundle_depth", 4)), 1, 4)
	var state_started_usec := Time.get_ticks_usec()
	var state := _transition_state.build(
		observation,
		resource_ledger,
		facts,
		prize_clock
	)
	var state_elapsed_usec := Time.get_ticks_usec() - state_started_usec
	var demand_started_usec := Time.get_ticks_usec()
	var demand := _continuity_demand.solve(
		observation,
		facts,
		prize_clock,
		profile
	)
	var demand_elapsed_usec := Time.get_ticks_usec() - demand_started_usec
	var response_started_usec := Time.get_ticks_usec()
	var response := _response_envelope.solve(observation, profile)
	var response_elapsed_usec := Time.get_ticks_usec() - response_started_usec
	var result: Array[Dictionary] = []
	var transition_elapsed_usec := 0
	for candidate: Dictionary in candidate_pool:
		var transition_started_usec := Time.get_ticks_usec()
		var transition := _transition_evaluator.evaluate(
			candidate,
			state,
			observation,
			profile
		)
		transition_elapsed_usec += Time.get_ticks_usec() - transition_started_usec
		var bundle := _bundle_for_candidate(
			candidate,
			transition,
			observation,
			facts,
			demand,
			response,
			profile,
			max_depth
		)
		result.append(bundle)
	_last_metrics = {
		"transition_state_ms": float(state_elapsed_usec) / 1000.0,
		"continuity_demand_ms": float(demand_elapsed_usec) / 1000.0,
		"response_ms": float(response_elapsed_usec) / 1000.0,
		"transition_ms": float(transition_elapsed_usec) / 1000.0,
		"bundle_total_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
	}
	return result


func last_metrics() -> Dictionary:
	return _last_metrics.duplicate(true)


func _bundle_for_candidate(
	candidate: Dictionary,
	transition: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	demand: Dictionary,
	response: Dictionary,
	profile: Dictionary,
	max_depth: int
) -> Dictionary:
	var action_id := str(
		candidate.get(
			"safe_prefix_action_id",
			candidate.get("action_ref", {}).get("id", "")
		)
	)
	var steps: Array[Dictionary] = [{
		"step_index": 0,
		"route_id": str(candidate.get("route_id", "")),
		"action_id": action_id,
		"operator": str(transition.get("operator", "")),
		"exact_now": action_id != "",
		"requires_reobservation": bool(
			transition.get("requires_reobservation", false)
		),
		"prediction_class": str(
			transition.get("prediction_class", "transition_unsupported")
		),
	}]
	var information_boundary := _transition_registry.is_information_boundary(
		candidate
	)
	if not information_boundary \
			and not _transition_registry.is_terminal(str(transition.get("operator", ""))):
		var followups := _projected_followups(
			candidate,
			observation,
			demand,
			profile,
			max_depth - 1
		)
		for raw_followup: Variant in followups:
			if steps.size() >= max_depth or not (raw_followup is Dictionary):
				break
			var followup: Dictionary = raw_followup
			var route_id := str(followup.get("route_id", ""))
			if route_id == "":
				continue
			steps.append({
				"step_index": steps.size(),
				"route_id": route_id,
				"action_id": "",
				"operator": "PROJECTED_TYPED_INTENT",
				"exact_now": false,
				"requires_reobservation": true,
				"prediction_class": "projected_after_reobservation",
				"dependency": str(followup.get("dependency", "")),
				"origin": str(followup.get("origin", "conditional_suffix")),
			})
	var bundle := {
		"schema_version": ContractsScript.BUNDLE_SCHEMA_VERSION,
		"route_value_graph_version": ContractsScript.ROUTE_VALUE_GRAPH_VERSION,
		"bundle_id": "bundle:%s" % ContractsScript.stable_hash({
			"candidate_id": str(candidate.get("candidate_id", "")),
			"state_hash": str(
				transition.get("transition_certificate", {}).get(
					"source_state_hash",
					""
				)
			),
			"steps": steps,
		}).substr(0, 20),
		"root_candidate_id": str(candidate.get("candidate_id", "")),
		"root_route_id": str(candidate.get("route_id", "")),
		"root_action_id": action_id,
		"rule_score": float(candidate.get("base_score", 0.0)),
		"bundle_depth": steps.size(),
		"steps": steps,
		"checkpoint_after": str(
			candidate.get("checkpoint_after", "action_resolved")
		),
		"requires_reobservation": (
			information_boundary
			or bool(transition.get("requires_reobservation", false))
			or steps.size() > 1
		),
		"transition_state_hash": str(
			transition.get("transition_certificate", {}).get(
				"source_state_hash",
				""
			)
		),
		"predicted_state_hash": str(
			transition.get("transition_certificate", {}).get(
				"predicted_state_hash",
				""
			)
		),
		"transition_prediction_class": str(
			transition.get("prediction_class", "")
		),
		"response_envelope_hash": str(
			response.get("response_envelope_hash", "")
		),
		"continuity_demand_hash": str(demand.get("demand_hash", "")),
		"continuity_demand": demand,
		"verified_rescue": _has_verified_rescue(candidate),
	}
	bundle["outcome_vector"] = _outcome_evaluator.evaluate(
		candidate,
		transition,
		demand,
		response,
		facts
	)
	if int(profile.get("deck_id", 0)) == 800018509:
		bundle["deck_extension"] = _raging_extension.annotate_bundle(
			bundle,
			candidate,
			observation,
			facts,
			demand,
			profile
		)
	return bundle


func _projected_followups(
	candidate: Dictionary,
	observation: Dictionary,
	demand: Dictionary,
	profile: Dictionary,
	max_count: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if max_count <= 0:
		return result
	var suffix: Dictionary = candidate.get("conditional_suffix", {}) \
		if candidate.get("conditional_suffix", {}) is Dictionary else {}
	var configured: Variant = suffix.get("guarded_followups", [])
	if configured is Array:
		for raw: Variant in configured:
			if result.size() >= max_count:
				break
			if raw is Dictionary and str((raw as Dictionary).get("route_id", "")) != "":
				result.append((raw as Dictionary).duplicate(true))
			elif str(raw).begins_with("route:"):
				result.append({"route_id": str(raw)})
	if int(profile.get("deck_id", 0)) == 800018509 \
			and result.size() < max_count:
		for followup: Dictionary in _raging_extension.projected_followups(
			candidate,
			observation,
			demand,
			max_count - result.size()
		):
			if not _has_route(result, str(followup.get("route_id", ""))):
				result.append(followup)
	return result


func _has_route(routes: Array[Dictionary], route_id: String) -> bool:
	for route: Dictionary in routes:
		if str(route.get("route_id", "")) == route_id:
			return true
	return false


func _has_verified_rescue(candidate: Dictionary) -> bool:
	var certificates: Dictionary = candidate.get("local_certificates", {}) \
		if candidate.get("local_certificates", {}) is Dictionary else {}
	if not certificates.is_empty():
		return true
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw: Variant in annotations.values():
		if raw is Dictionary and bool((raw as Dictionary).get("verified_advantage", false)):
			return true
	return false
