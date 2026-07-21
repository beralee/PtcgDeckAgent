extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 107
const PROVENANCE_TURN := 27
const PROVENANCE_OBSERVATION_HASH := "2256f5a8e17cc928096070722f211f4e69be0d6bd84562b1a27f3be8e6620744"
const ATTACH_ID := "candidate:c0cbbec5c024895ac1c5"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 11, "round09 typed dependency guard requires profile version 11")
	_test_exact_seed107_typed_ko_rejected(profile)
	_test_typed_route_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round09 typed attack dependency: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_seed107_typed_ko_rejected(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var result := strategy.install_policy_response_for_test(
		_response(["route:energy_commit", "route:attack_ko"]),
		_frontier(["P"], false)
	)
	_check(not bool(result.get("valid", true)), "seed107 energy_commit-to-KO macro must be rejected before attachment")
	_check(str(result.get("reason", "")) == "typed_route_attack_dependency_unproven", "seed107 typed dependency rejection reason changed")
	var snapshot := strategy.get_policy_snapshot()
	_check((snapshot.get("policy", {}) as Dictionary).is_empty(), "rejected typed macro must install no partial policy")
	_check(str(snapshot.get("current_node_id", "")) == "", "rejected typed macro must leave no active node")


func _test_typed_route_boundaries(profile: Dictionary) -> void:
	var completing_pressure := StrategyScript.new()
	completing_pressure.configure_profile(profile)
	_check(
		bool(completing_pressure.install_policy_response_for_test(
			_response(["route:energy_commit", "route:attack_pressure"]),
			_frontier([], true)
		).get("valid", false)),
		"exact Active cost completion may lead directly to attack_pressure"
	)

	var completing_ko := StrategyScript.new()
	completing_ko.configure_profile(profile)
	_check(
		not bool(completing_ko.install_policy_response_for_test(
			_response(["route:energy_commit", "route:attack_ko"]),
			_frontier([], true)
		).get("valid", true)),
		"cost completion alone must not invent an immediate KO postcondition"
	)

	var intermediate := StrategyScript.new()
	intermediate.configure_profile(profile)
	_check(
		not bool(intermediate.install_policy_response_for_test(
			_response(["route:energy_commit", "route:evolve", "route:attack_pressure"]),
			_frontier([], true)
		).get("valid", true)),
		"an unbound intermediate macro must not bridge attachment to attack"
	)

	var end_turn := StrategyScript.new()
	end_turn.configure_profile(profile)
	_check(
		bool(end_turn.install_policy_response_for_test(
			_response(["route:energy_commit", "route:end_turn"]),
			_frontier(["P"], false)
		).get("valid", false)),
		"a non-attack typed attachment plan must remain legal"
	)

	var no_annotation := _frontier(["P"], false)
	no_annotation[0].erase("module_annotations")
	var unknown := StrategyScript.new()
	unknown.configure_profile(profile)
	_check(
		not bool(unknown.install_policy_response_for_test(
			_response(["route:energy_commit", "route:attack_pressure"]),
			no_annotation
		).get("valid", true)),
		"missing candidate postcondition must fail closed for an attack macro"
	)


func _response(macros: Array[String]) -> Dictionary:
	return {
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "propose_typed_route",
					"route_id": "route:energy_commit",
					"first_candidate_id": ATTACH_ID,
					"macro_actions": macros.duplicate(),
				},
			}],
		},
	}


func _frontier(missing_after: Array, completes: bool) -> Array[Dictionary]:
	var attachment := {
		"target_slot_id": "slot:5",
		"target_uid": "CSV2C_055",
		"target_is_profiled_attacker": true,
		"target_is_active": true,
		"energy_symbol": "D",
		"required_symbols": ["P", "P", "C"],
		"missing_before": ["P", "C"],
		"missing_after": missing_after.duplicate(),
		"adds_missing_required_type": true,
		"completes_required_types": completes,
		"deterministic_attack_window_open": true,
	}
	return [{
		"candidate_id": ATTACH_ID,
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"safe_prefix_action_id": "action:attach_energy:59:-:5:-1:-1",
		"base_score": 914.0,
		"local_score": 914.0,
		"module_annotations": {
			"damage_counter_control": {"typed_attachment": attachment.duplicate(true)},
			"gardevoir_embrace": {"typed_attachment": attachment.duplicate(true)},
		},
		"outcome": {"future_flexibility": 0.3, "resource_commitment": 0.7, "uncertainty": 0.2},
	}]


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
