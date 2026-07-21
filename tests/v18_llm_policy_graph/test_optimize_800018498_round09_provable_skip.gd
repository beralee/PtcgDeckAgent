extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 9, "round09 profile must be active")
	_check(int(profile.get("max_policy_nodes", 0)) == 8, "round09 must not enlarge the policy graph")
	_check(int(profile.get("initial_response_token_budget", 0)) == 400, "round09 initial token budget must stay frozen")
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "round09 delta token budget must stay frozen")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "round09 visible wait budget must stay frozen")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	_test_all_alternatives_provably_invalid(strategy)
	_test_safe_alternative_keeps_model_eligible(strategy)
	_test_terminal_improvement_keeps_model_eligible(strategy)
	_test_module_certificate_keeps_model_eligible(strategy)
	_test_information_and_recovery_roots_never_skip(strategy)
	_test_full_pool_prevents_pruned_terminal_false_proof(strategy)
	_test_skip_installs_one_shot_rule_ownership(strategy)
	_test_gate_is_stateless_across_decision_windows(strategy)
	if _failures.is_empty():
		print("V18CPG 800018498 round09 provable terminal skip: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800018498 round09 provable terminal skip: FAIL (%d)" % _failures.size())
	quit(1)


func _test_all_alternatives_provably_invalid(strategy: RefCounted) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:attack", "route:attack_pressure", 1000.0),
		_candidate("bad:develop", "route:develop", 0.0),
		_candidate("bad:search", "route:information", -500.0),
	]
	var result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	_check(bool(result.get("skip", false)), "terminal root with only below-margin alternatives must skip the model")
	_check(int(result.get("checked_alternatives", 0)) == 2, "the proof must inspect every non-Rule alternative")


func _test_safe_alternative_keeps_model_eligible(strategy: RefCounted) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:attack", "route:attack_pressure", 500.0),
		_candidate("safe:evolve", "route:evolve", 300.0),
	]
	var result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	_check(not bool(result.get("skip", false)), "a production-safe alternative inside the switch margin must preserve the model call")


func _test_terminal_improvement_keeps_model_eligible(strategy: RefCounted) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:pressure", "route:attack_pressure", 1000.0),
		_candidate("win:now", "route:attack_ko", 0.0, {"win_now": true, "prizes_now": 2}),
	]
	var win_result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	_check(not bool(win_result.get("skip", false)), "a deterministic win must preserve the model path even beyond the score margin")
	frontier[1] = _candidate("take:prizes", "route:attack_ko", 0.0, {"win_now": false, "prizes_now": 1})
	var prize_result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	_check(not bool(prize_result.get("skip", false)), "a deterministic prize gain must preserve the model path even beyond the score margin")


func _test_module_certificate_keeps_model_eligible(strategy: RefCounted) -> void:
	var certified := _candidate("certified:mover", "route:develop", 0.0)
	certified["module_annotations"] = {
		"damage_counter_control": {
			"counter_engine_setup": {"advances_profiled_setup": true},
		}
	}
	var frontier: Array[Dictionary] = [
		_candidate("rule:attack", "route:attack_pressure", 1000.0),
		certified,
	]
	var result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	_check(not bool(result.get("skip", false)), "a verified module advantage must preserve the model path beyond the score margin")


func _test_information_and_recovery_roots_never_skip(strategy: RefCounted) -> void:
	for route_id: String in ["route:information", "route:tutor", "route:opening_search", "route:noctowl_search", "route:recover"]:
		var frontier: Array[Dictionary] = [
			_candidate("rule:root", route_id, 1000.0),
			_candidate("bad:end", "route:end_turn", 0.0),
		]
		var result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
		_check(not bool(result.get("skip", false)), "%s root must never be classified as a terminal no-gain window" % route_id)


func _test_full_pool_prevents_pruned_terminal_false_proof(strategy: RefCounted) -> void:
	var pool: Array[Dictionary] = [_candidate("rule:attack", "route:attack_pressure", 1000.0)]
	for index: int in 10:
		pool.append(_candidate("bad:%02d" % index, "route:develop", -1000.0 - index))
	pool.append(_candidate("late:win", "route:develop", -5000.0, {"win_now": true, "prizes_now": 2}))
	var pruned := RouteSearchScript.new().prune_frontier(pool, 10)
	_check(_find_candidate(pruned, "late:win").is_empty(), "adversarial fixture must place the deterministic win outside the model frontier")
	var result: Dictionary = strategy._should_skip_terminal_without_admissible_switch(pool, _facts())
	_check(not bool(result.get("skip", false)), "the proof must inspect the full annotated pool, including candidate 12")


func _test_skip_installs_one_shot_rule_ownership(strategy: RefCounted) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:attack", "route:attack_pressure", 1000.0),
		_candidate("bad:develop", "route:develop", 0.0),
	]
	strategy._install_one_shot_rules_floor(frontier)
	var graph: Dictionary = strategy.get_policy_snapshot()
	_check(graph.is_empty() or str(graph.get("current_node_id", "")) == "", "terminal skip must not leave a reusable fallback graph")
	_check(str(strategy.get("_current_action_owner")) == "rules_fallback", "terminal skip must preserve strict Rule ownership")
	_check(str(strategy.get("_preferred_candidate_id")) == "rule:attack", "terminal skip must bind the exact Rule-floor candidate")


func _test_gate_is_stateless_across_decision_windows(strategy: RefCounted) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:attack", "route:attack_pressure", 500.0),
		_candidate("safe:evolve", "route:evolve", 300.0),
	]
	var first: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	var second: Dictionary = strategy._should_skip_terminal_without_admissible_switch(frontier, _facts())
	_check(
		not bool(first.get("skip", false)) and not bool(second.get("skip", false)),
		"separate eligible windows must not be suppressed by a hidden per-turn call cap"
	)


func _candidate(candidate_id: String, route_id: String, score: float, outcome: Dictionary = {}) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"base_score": score,
		"local_score": score,
		"outcome": outcome.duplicate(true),
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": false, "max_damage": 100},
		"resources": {"prizes_remaining": 3, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _find_candidate(candidates: Array[Dictionary], candidate_id: String) -> Dictionary:
	for candidate: Dictionary in candidates:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
