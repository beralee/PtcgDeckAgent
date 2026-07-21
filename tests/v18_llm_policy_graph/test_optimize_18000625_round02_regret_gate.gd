extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 18000625

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 4, "round02 requires profile version 4 or newer")
	_check(float(profile.get("expected_regret_threshold", 0.0)) >= 271.0, \
		"later rounds must not reopen the audited 271 regret boundary")
	var round02_profile := profile.duplicate(true)
	round02_profile["expected_regret_threshold"] = 271.0
	var strategy := StrategyScript.new()
	strategy.set("_profile", round02_profile)

	var exact_boundary: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:energy_commit", 1000.0),
			_candidate("route:evolve", 1000.0),
		]),
		_facts()
	)
	_check(bool(exact_boundary.get("use_local", false)), \
		"one tied non-information alternative has regret 270 and must stay local")
	_check(is_equal_approx(float(exact_boundary.get("expected_regret", -1.0)), 270.0), \
		"the audited tied frontier must retain regret 270")

	var two_alternatives: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:develop", 1000.0),
			_candidate("route:evolve", 1000.0),
			_candidate("route:energy_commit", 1000.0),
		]),
		_facts()
	)
	_check(not bool(two_alternatives.get("use_local", true)), \
		"two tied alternatives have regret 315 and must retain model review")
	_check(is_equal_approx(float(two_alternatives.get("expected_regret", -1.0)), 315.0), \
		"the two-alternative frontier must retain regret 315")

	var information_frontier: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:information", 1000.0),
			_candidate("route:evolve", 1000.0),
		]),
		_facts()
	)
	_check(not bool(information_frontier.get("use_local", true)), \
		"information-root regret 380 must retain model review")
	_check(is_equal_approx(float(information_frontier.get("expected_regret", -1.0)), 380.0), \
		"information-root frontier must retain regret 380")

	var clear_rule_lead: Dictionary = strategy.call(
		"_should_use_local",
		_frontier([
			_candidate("route:energy_commit", 1000.0),
			_candidate("route:develop", 700.0),
		]),
		_facts()
	)
	_check(bool(clear_rule_lead.get("use_local", false)), \
		"a Rule lead beyond the consideration margin must remain deterministic")
	_check(str(clear_rule_lead.get("reason", "")) == "no_switchable_alternative", \
		"clear Rule lead must close through the no-switchable gate")

	if _failures.is_empty():
		print("V18CPG 18000625 round02 regret gate: PASS")
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
