extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 18000625

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 5, "round03 requires profile version 5 or newer")
	_check(float(profile.get("expected_regret_threshold", 0.0)) >= 386.0, \
		"later rounds must not reopen the audited 386 deterministic-root boundary")
	var route_preferences: Dictionary = profile.get("route_preferences", {})
	var route_thresholds: Dictionary = route_preferences.get("model_review_regret_threshold_by_route", {})
	for route_id: String in ["route:information", "route:noctowl_search", "route:opening_search", "route:tutor"]:
		_check(is_equal_approx(float(route_thresholds.get(route_id, 0.0)), 271.0), \
			"%s must retain the Round02 model-review boundary" % route_id)
	var round03_profile := profile.duplicate(true)
	round03_profile["expected_regret_threshold"] = 386.0
	var strategy := StrategyScript.new()
	strategy.set("_profile", round03_profile)

	var clear_information_lead: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:information", 1000.0),
			_candidate("route:evolve", 821.4),
			_candidate("route:develop", 821.4),
			_candidate("route:energy_commit", 821.4),
		]),
		_facts()
	)
	_check(not bool(clear_information_lead.get("use_local", true)), \
		"the audited 291.4 information frontier must retain model review")
	_check(is_equal_approx(float(clear_information_lead.get("expected_regret", -1.0)), 291.4), \
		"clear information lead must retain regret 291.4")

	var clear_tutor_lead: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:tutor", 1000.0),
			_candidate("route:energy_commit", 907.0),
		]),
		_facts()
	)
	_check(not bool(clear_tutor_lead.get("use_local", true)), \
		"the audited 287 tutor frontier must retain model review")
	_check(is_equal_approx(float(clear_tutor_lead.get("expected_regret", -1.0)), 287.0), \
		"clear tutor lead must retain regret 287")

	var tied_information: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:information", 1000.0),
			_candidate("route:evolve", 1000.0),
		]),
		_facts()
	)
	_check(not bool(tied_information.get("use_local", true)), \
		"a tied information frontier has regret 380 and must retain model review")

	var low_uncertainty_recovery: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:recover", 1000.0),
			_candidate("route:evolve", 1000.0),
		]),
		_facts()
	)
	_check(bool(low_uncertainty_recovery.get("use_local", false)), \
		"the audited low-uncertainty recovery deadline must close locally")
	_check(is_equal_approx(float(low_uncertainty_recovery.get("expected_regret", -1.0)), 380.0), \
		"recovery frontier must retain regret 380")

	var clear_energy_commit: Array[Dictionary] = [_candidate("route:energy_commit", 1000.0)]
	for index: int in range(4):
		clear_energy_commit.append(_candidate("route:develop", 980.736 - float(index)))
	var deterministic_energy: Dictionary = strategy.call(
		"_should_use_local",
		clear_energy_commit,
		_facts()
	)
	_check(bool(deterministic_energy.get("use_local", false)), \
		"the audited 385.736 energy-commit shadow must close locally")
	_check(is_equal_approx(float(deterministic_energy.get("expected_regret", -1.0)), 385.736), \
		"energy-commit frontier must retain regret 385.736")

	var five_way_development: Array[Dictionary] = [_candidate("route:develop", 1000.0)]
	for index: int in range(5):
		five_way_development.append(_candidate("route:energy_commit", 1000.0 - float(index)))
	var contested_development: Dictionary = strategy.call(
		"_should_use_local",
		five_way_development,
		_facts()
	)
	_check(not bool(contested_development.get("use_local", true)), \
		"the audited five-alternative development frontier must retain model review")

	if _failures.is_empty():
		print("V18CPG 18000625 round03 regret gate: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _candidate(route_id: String, score: float) -> Dictionary:
	return {
		"route_id": route_id,
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _frontier(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in values:
		result.append(value as Dictionary)
	return result


func _facts() -> Dictionary:
	return {"resources": {"deck_low": false}}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
