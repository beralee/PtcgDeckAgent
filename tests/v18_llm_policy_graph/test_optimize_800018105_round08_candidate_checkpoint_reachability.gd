extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 107
const PROVENANCE_TURN := 27
const PROVENANCE_OBSERVATION_HASH := "2256f5a8e17cc928096070722f211f4e69be0d6bd84562b1a27f3be8e6620744"
const RULE_ID := "candidate:dc9639c1ab4ae5458fc1"
const ATTACH_ID := "candidate:c0cbbec5c024895ac1c5"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 10, "round08 checkpoint reachability requires profile version 10")
	_test_exact_seed107_no_progress_graph(profile)
	_test_replan_and_reachable_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round08 candidate checkpoint reachability: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_seed107_no_progress_graph(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var result := strategy.install_policy_response_for_test(
		_response("node:terminal", "attack.ko_available"),
		_frontier(["P"], true, false),
		_facts()
	)
	_check(not bool(result.get("valid", true)), "seed107 no-progress checkpoint must be rejected before attachment execution")
	_check(str(result.get("reason", "")) == "candidate_checkpoint_dependency_unreachable", "seed107 rejection reason changed")
	_check(str(result.get("candidate_id", "")) == ATTACH_ID, "rejection must bind the exact Darkness attachment candidate")
	_check(result.get("missing_after", []) == ["P"], "rejection must retain the public missing Psychic dependency")
	_check(
		(strategy.get_policy_snapshot().get("policy", {}) as Dictionary).is_empty(),
		"rejected graph must install no partial policy"
	)
	_check(str(strategy.get_policy_snapshot().get("current_node_id", "")) == "", "rejected graph must leave no active node")


func _test_replan_and_reachable_boundaries(profile: Dictionary) -> void:
	var replan_strategy := StrategyScript.new()
	replan_strategy.configure_profile(profile)
	var replan := replan_strategy.install_policy_response_for_test(
		_response("replan", "attack.ko_available"),
		_frontier(["P"], true, false),
		_facts()
	)
	_check(bool(replan.get("valid", false)), "a real replan otherwise path must remain legal")

	var completed_strategy := StrategyScript.new()
	completed_strategy.configure_profile(profile)
	var completed := completed_strategy.install_policy_response_for_test(
		_response("node:terminal", "attack.ko_available"),
		_frontier([], true, true),
		_facts()
	)
	_check(bool(completed.get("valid", false)), "an attachment that publicly completes Active attack cost must not be rejected by the missing-cost guard")

	var alternate_guard_strategy := StrategyScript.new()
	alternate_guard_strategy.configure_profile(profile)
	var alternate_guard := alternate_guard_strategy.install_policy_response_for_test(
		_response("node:terminal", "turn.energy_available", false),
		_frontier(["P"], true, false),
		_facts()
	)
	_check(bool(alternate_guard.get("valid", false)), "a checkpoint with a publicly reachable post-attachment branch must remain legal")

	var bench_strategy := StrategyScript.new()
	bench_strategy.configure_profile(profile)
	var bench := bench_strategy.install_policy_response_for_test(
		_response("node:terminal", "attack.ko_available"),
		_frontier(["P"], false, false),
		_facts()
	)
	_check(bool(bench.get("valid", false)), "the narrow Active dependency guard must not infer a Bench postcondition")

	var conflicting := _frontier(["P"], true, false)
	conflicting[1]["module_annotations"]["gardevoir_embrace"]["typed_attachment"]["missing_after"] = []
	var conflict_strategy := StrategyScript.new()
	conflict_strategy.configure_profile(profile)
	var conflict := conflict_strategy.install_policy_response_for_test(
		_response("node:terminal", "attack.ko_available"),
		conflicting,
		_facts()
	)
	_check(bool(conflict.get("valid", false)), "conflicting module annotations must fail open instead of inventing a proof")

	var already_ready := _facts()
	already_ready["attack"]["ready"] = true
	var ready_strategy := StrategyScript.new()
	ready_strategy.configure_profile(profile)
	var ready := ready_strategy.install_policy_response_for_test(
		_response("node:terminal", "attack.ko_available"),
		_frontier(["P"], true, false),
		already_ready
	)
	_check(bool(ready.get("valid", false)), "an already-ready public attack must not be contradicted by a profile cost annotation")


func _facts() -> Dictionary:
	return {"attack": {"ready": false, "ko_available": false}}


func _response(otherwise: String, branch_fact: String, branch_value: bool = true) -> Dictionary:
	var nodes: Array[Dictionary] = [
		{
			"node_id": "node:root",
			"kind": "route",
			"route_ref": {"mode": "select_candidate", "candidate_id": ATTACH_ID, "route_id": "route:energy_commit"},
			"next_node_id": "node:checkpoint_after_attach",
		},
		{
			"node_id": "node:checkpoint_after_attach",
			"kind": "checkpoint",
			"branches": [{"when_all": [{"fact": branch_fact, "op": "==", "value": branch_value}], "next_node_id": "node:attack"}],
			"otherwise": otherwise,
		},
		{
			"node_id": "node:attack",
			"kind": "route",
			"route_ref": {"mode": "follow_route", "route_id": "route:attack_ko"},
			"next_node_id": "node:terminal",
		},
		{"node_id": "node:terminal", "kind": "terminal"},
	]
	return {"policy": {"root_node_id": "node:root", "nodes": nodes}}


func _frontier(missing_after: Array, target_is_active: bool, completes: bool) -> Array[Dictionary]:
	var typed_attachment := {
		"target_slot_id": "slot:5" if target_is_active else "slot:9",
		"target_uid": "CSV2C_055" if target_is_active else "CSV2C_060",
		"target_is_profiled_attacker": true,
		"target_is_active": target_is_active,
		"energy_symbol": "D",
		"required_symbols": ["P", "P", "C"],
		"missing_before": ["P", "C"],
		"missing_after": missing_after.duplicate(),
		"adds_missing_required_type": true,
		"completes_required_types": completes,
		"deterministic_attack_window_open": true,
	}
	return [
		{
			"candidate_id": RULE_ID,
			"route_id": "route:information",
			"action_kind": "use_ability",
			"safe_prefix_action_id": "action:use_ability:-:5:-:-1:0",
			"base_score": 919.4,
			"local_score": 919.4,
			"engine_rule_floor_exact": true,
			"outcome": {"future_flexibility": 0.8, "uncertainty": 0.7},
		},
		{
			"candidate_id": ATTACH_ID,
			"route_id": "route:energy_commit",
			"action_kind": "attach_energy",
			"safe_prefix_action_id": "action:attach_energy:59:-:5:-1:-1",
			"base_score": 914.0,
			"local_score": 914.0,
			"engine_rule_floor_exact": false,
			"module_annotations": {
				"damage_counter_control": {"typed_attachment": typed_attachment.duplicate(true)},
				"gardevoir_embrace": {"typed_attachment": typed_attachment.duplicate(true)},
			},
			"outcome": {"future_flexibility": 0.3, "resource_commitment": 0.7, "uncertainty": 0.2},
		},
	]


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
