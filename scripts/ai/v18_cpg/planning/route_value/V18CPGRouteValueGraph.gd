class_name V18CPGRouteValueGraph
extends RefCounted

const BundleSearchScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteBundleSearch.gd"
)
const ParetoFrontierScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGParetoFrontier.gd"
)
const PrizeClockSolverScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGPrizeClockSolver.gd"
)

var _bundle_search = BundleSearchScript.new()
var _pareto = ParetoFrontierScript.new()
var _prize_clock = PrizeClockSolverScript.new()
var _last_bundles: Array[Dictionary] = []
var _last_pareto_ids: Array[String] = []
var _last_metrics: Dictionary = {}


func annotate_candidate_pool(
	candidate_pool: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	resource_ledger: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	if not should_compute(profile):
		_last_bundles.clear()
		_last_pareto_ids.clear()
		_last_metrics.clear()
		return candidate_pool.duplicate(true)
	var started_usec := Time.get_ticks_usec()
	var clock := _prize_clock.solve(observation, facts, profile)
	var bundle_started_usec := Time.get_ticks_usec()
	_last_bundles = _bundle_search.build(
		candidate_pool,
		observation,
		facts,
		resource_ledger,
		profile,
		clock
	)
	var bundle_elapsed_usec := Time.get_ticks_usec() - bundle_started_usec
	var rule_id := _rule_root_id(candidate_pool)
	var config: Dictionary = profile.get("route_value_graph_v3", {})
	var frontier_cap := clampi(
		int(config.get("model_frontier_max", 10)),
		1,
		10
	)
	var pareto_started_usec := Time.get_ticks_usec()
	var pareto := _pareto.prune(_last_bundles, frontier_cap, rule_id)
	var pareto_elapsed_usec := Time.get_ticks_usec() - pareto_started_usec
	_last_pareto_ids.clear()
	var bundle_by_candidate: Dictionary = {}
	for bundle: Dictionary in _last_bundles:
		bundle_by_candidate[str(bundle.get("root_candidate_id", ""))] = bundle
	for bundle: Dictionary in pareto:
		_last_pareto_ids.append(str(bundle.get("root_candidate_id", "")))
	_last_metrics = {
		"route_value_graph_version": 3,
		"bundle_count": _last_bundles.size(),
		"pareto_frontier_size": pareto.size(),
		"dominated_bundle_count": maxi(0, _last_bundles.size() - pareto.size()),
		"bundle_local_ms": float(bundle_elapsed_usec) / 1000.0,
		"pareto_ms": float(pareto_elapsed_usec) / 1000.0,
		"total_local_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"shadow_only": not is_enabled(profile),
	}
	_last_metrics.merge(_bundle_search.last_metrics(), true)
	var result: Array[Dictionary] = []
	for candidate: Dictionary in candidate_pool:
		var annotated := candidate.duplicate(true)
		var candidate_id := str(candidate.get("candidate_id", ""))
		if bundle_by_candidate.get(candidate_id) is Dictionary:
			var bundle: Dictionary = bundle_by_candidate[candidate_id]
			annotated["route_value_graph_v3"] = _compact_bundle(
				bundle,
				candidate_id in _last_pareto_ids
			)
		result.append(annotated)
	return result


func prune_model_candidates(
	candidate_pool: Array[Dictionary],
	max_size: int = 10
) -> Array[Dictionary]:
	if _last_pareto_ids.is_empty():
		return candidate_pool.duplicate(true)
	var result: Array[Dictionary] = []
	for candidate: Dictionary in candidate_pool:
		if str(candidate.get("candidate_id", "")) in _last_pareto_ids:
			result.append(candidate)
	# Pareto is a value filter, not an excuse to lose route diversity. Fill any
	# spare transport slots in original Rule order; the downstream route search
	# still owns same-category diversity and verified rescue ordering.
	for candidate: Dictionary in candidate_pool:
		if result.size() >= max_size:
			break
		if not _contains_candidate(result, str(candidate.get("candidate_id", ""))):
			result.append(candidate)
	return result


func last_bundle_snapshot() -> Array[Dictionary]:
	return _last_bundles.duplicate(true)


func last_metrics() -> Dictionary:
	return _last_metrics.duplicate(true)


static func is_enabled(profile: Dictionary) -> bool:
	var config: Dictionary = profile.get("route_value_graph_v3", {}) \
		if profile.get("route_value_graph_v3", {}) is Dictionary else {}
	var environment_override := OS.get_environment(
		"V18CPG_ROUTE_VALUE_GRAPH_V3_ENABLED"
	).strip_edges().to_lower()
	if environment_override != "":
		return environment_override in ["1", "true", "yes", "on"]
	return bool(ProjectSettings.get_setting(
		"ai/route_value_graph_v3_enabled",
		bool(config.get("enabled", false))
	))


static func should_compute(profile: Dictionary) -> bool:
	var config: Dictionary = profile.get("route_value_graph_v3", {}) \
		if profile.get("route_value_graph_v3", {}) is Dictionary else {}
	return is_enabled(profile) or bool(config.get("shadow_enabled", false))


func _rule_root_id(candidate_pool: Array[Dictionary]) -> String:
	for candidate: Dictionary in candidate_pool:
		if bool(candidate.get("engine_rule_floor_exact", false)):
			return str(candidate.get("candidate_id", ""))
	return str(candidate_pool[0].get("candidate_id", "")) \
		if not candidate_pool.is_empty() else ""


func _compact_bundle(bundle: Dictionary, pareto_selected: bool) -> Dictionary:
	var result := {
		"schema_version": int(bundle.get("schema_version", 0)),
		"route_value_graph_version": int(
			bundle.get("route_value_graph_version", 0)
		),
		"bundle_id": str(bundle.get("bundle_id", "")),
		"bundle_depth": int(bundle.get("bundle_depth", 0)),
		"steps": (bundle.get("steps", []) as Array).duplicate(true) \
			if bundle.get("steps", []) is Array else [],
		"checkpoint_after": str(bundle.get("checkpoint_after", "")),
		"requires_reobservation": bool(
			bundle.get("requires_reobservation", false)
		),
		"transition_prediction_class": str(
			bundle.get("transition_prediction_class", "")
		),
		"outcome_vector": (
			bundle.get("outcome_vector", {}) as Dictionary
		).duplicate(true) if bundle.get("outcome_vector", {}) is Dictionary else {},
		"pareto_selected": pareto_selected,
	}
	if bundle.get("deck_extension", {}) is Dictionary \
			and not (bundle.get("deck_extension", {}) as Dictionary).is_empty():
		result["deck_extension"] = (
			bundle.get("deck_extension", {}) as Dictionary
		).duplicate(true)
	return result


func _contains_candidate(
	candidates: Array[Dictionary],
	candidate_id: String
) -> bool:
	for candidate: Dictionary in candidates:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return true
	return false
