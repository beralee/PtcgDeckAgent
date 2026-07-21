extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 4, "round04 margin must remain present in later profiles")
	_check(
		is_equal_approx(float(profile.get("safety", {}).get("max_switch_gap", 0.0)), 225.0),
		"round04 max switch gap must be exactly 225"
	)
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "visible wait budget must not increase")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var low_pressure_frontier: Array[Dictionary] = [
		_candidate("candidate:rule", "route:attack_pressure", "attack", 516.32),
		_candidate("candidate:nest", "route:information", "play_trainer", 365.2),
		_candidate("candidate:research", "route:information", "play_trainer", 125.6),
	]
	var nest_result := strategy._validate_model_route_safety(
		"route:information", low_pressure_frontier, {"resources": {"deck_low": false}}, "candidate:nest"
	)
	_check(
		bool(nest_result.get("valid", false)) \
			and str(nest_result.get("reason", "")) == "validated_switch" \
			and float(nest_result.get("score_gap", 999.0)) <= 225.0,
		"visible Nest Ball setup must fit the declared 225-point boundary"
	)
	var research_result := strategy._validate_model_route_safety(
		"route:information", low_pressure_frontier, {"resources": {"deck_low": false}}, "candidate:research"
	)
	_check(
		not bool(research_result.get("valid", true)) \
			and str(research_result.get("reason", "")) == "model_route_below_switch_margin" \
			and float(research_result.get("score_gap", 0.0)) > 225.0,
		"large Professor's Research commitment must remain outside the boundary"
	)
	if _failures.is_empty():
		print("optimization21 800018498 round04 margin: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _candidate(candidate_id: String, route_id: String, action_kind: String, base_score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"action_kind": action_kind,
		"base_score": base_score,
		"local_score": base_score,
		"checkpoint_after": "terminal" if action_kind == "attack" else "information_result",
		"outcome": {
			"win_now": false,
			"prizes_now": 0,
			"information_gain": 0.8 if route_id == "route:information" else 0.0,
		},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
