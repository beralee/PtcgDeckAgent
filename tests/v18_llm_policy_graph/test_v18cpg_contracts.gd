extends SceneTree

## Keep capability modules as static dependencies of the acceptance entrypoint.
## Dynamic load failures can otherwise be reported after this suite prints PASS,
## and Godot may still exit with status 0.
const _EnergyBurstModule = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")
const _CyclePivotModule = preload("res://scripts/ai/v18_cpg/modules/V18CPGCyclePivot.gd")
const _TeraNoctowlModule = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const ObservationGatewayScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd")
const BeliefStateScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGBeliefState.gd")
const PolicyValidatorScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyValidator.gd")
const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const ProfilePolicyScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGProfilePolicy.gd")
const FactBuilderScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd")
const ExecutionCursorScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGExecutionCursor.gd")
const InteractionPolicyScript = preload("res://scripts/ai/v18_cpg/execution/V18CPGInteractionPolicy.gd")
const InformationValueScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGInformationValueSolver.gd")
const VisibleWaitBudgetScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGVisibleWaitBudget.gd")
const DecisionClientScript = preload("res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd")
const RngIsolatedTransportScript = preload(
	"res://scripts/ai/v18_cpg/network/V18CPGRngIsolatedZenMuxClient.gd"
)

var _failures: Array[String] = []


class RuleFloorPlanProbe:
	extends RefCounted

	var build_calls := 0
	var last_plan: Dictionary = {}

	func build_turn_plan(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
		build_calls += 1
		return {"id": "rebuilt_plan"}

	func score_action(
		_action: Dictionary,
		_game_state: GameState,
		_player_index: int,
		turn_plan: Dictionary = {}
	) -> float:
		last_plan = turn_plan.duplicate(true)
		return 913.0 if str(turn_plan.get("id", "")) == "host_exact_plan" else -431.0


func _initialize() -> void:
	_test_profiles()
	_test_hidden_information_firewall()
	_test_belief_replay()
	_test_policy_graph_contract()
	_test_noctowl_pair_search()
	_test_rule_floor_and_route_safety()
	_test_rule_floor_turn_contract_applied_once()
	_test_exact_candidate_frontier()
	_test_execution_cursor_and_typed_route()
	_test_typed_interaction_policy()
	_test_information_value()
	_test_information_epoch_reopening()
	_test_typed_profile_policy()
	_test_compact_wire_contract()
	_test_strict_compact_response_validation()
	_test_transport_rng_isolation()
	_test_isolation_scan()
	if _failures.is_empty():
		print("V18CPG fixture suite: PASS (17 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG fixture suite: FAIL (%d)" % _failures.size())
	quit(1)


func _test_rule_floor_turn_contract_applied_once() -> void:
	var strategy := StrategyScript.new()
	var probe := RuleFloorPlanProbe.new()
	strategy.set("_rules_fallback", probe)
	var host_plan := {
		"id": "host_exact_plan",
		"intent": "preserve_rule_retreat",
		"continuity": {"owner": "Blaziken ex"},
	}
	var score := strategy.score_action_absolute_with_plan(
		{"kind": "retreat", "target": "slot:9"},
		GameState.new(),
		0,
		host_plan
	)
	_check(is_equal_approx(score, 913.0), \
		"V18 host scoring must delegate the exact supplied Rule turn contract once")
	_check(probe.build_calls == 0 and probe.last_plan == host_plan, \
		"V18 host scoring must not rebuild the Rule plan or reapply base continuity/retreat guards")


func _test_compact_wire_contract() -> void:
	var client := DecisionClientScript.new()
	var envelope := {
		"limits": {"max_policy_nodes": 6},
		"lifecycle": {"request_id": "request:test"},
		"profile": {"deck_id": 1},
		"observation": {"own": {"hand": []}},
		"belief": {},
		"match_agenda": {},
		"facts": {"attack": {"ready": false}},
		"resource_ledger": {"reserved_next_turn": []},
		"prize_graph": {},
		"threat_response": {},
		"capability_context": {"energy_burst": {"decision_hints": ["preserve_energy"]}},
		"frontier": [{
			"candidate_id": "candidate:root",
			"route_id": "route:information",
			"action_kind": "play_trainer",
		}],
		"current_root_route_ids": ["route:information"],
		"current_root_candidate_bindings": [{
			"candidate_id": "candidate:root",
			"route_id": "route:information",
		}],
		"allowed_follow_route_ids": ["route:information", "route:attack_pressure"],
		"allowed_candidate_ids": ["candidate:root"],
		"allowed_fact_paths": ["attack.ready"],
		"allowed_guard_operators": ["=="],
		"current_policy_cursor": {"current_node_id": "node:root"},
		"material_delta": {"material": true, "changed_facts": ["attack.ready"]},
	}
	var payload: Dictionary = client._build_payload(envelope, 400, false)
	_check(
		int(payload.get("max_tokens", 0)) == 400 \
			and not payload.has("response_format"),
		"V18 compact transport must retain the response budget without appending the full JSON Schema"
	)
	var messages: Array = payload.get("messages", []) if payload.get("messages", []) is Array else []
	_check(messages.size() == 2, "compact transport must contain one system and one user message")
	var system_text := str((messages[0] as Dictionary).get("content", "")) if messages.size() >= 1 else ""
	_check(
		not system_text.contains("$defs") \
			and not system_text.contains("V18CPG exact conditional policy graph response v2"),
		"compact transport must not inline the full response schema"
	)
	_check(
		system_text.contains("root_node_id and nodes inside policy") \
			and system_text.contains("limits.max_policy_nodes is the absolute node maximum") \
			and system_text.contains("macro_actions[0] must both exactly equal") \
			and system_text.contains("propose_typed_route is root-only") \
			and system_text.contains("point only to a node listed later"),
		"compact grammar must pin the outer policy wrapper and active profile node limit"
	)
	var user_variant: Variant = JSON.parse_string(
		str((messages[1] as Dictionary).get("content", "")) if messages.size() >= 2 else ""
	)
	var user_payload: Dictionary = user_variant if user_variant is Dictionary else {}
	_check(
		int(user_payload.get("transport_contract_version", 0)) == 3 \
			and int(user_payload.get("limits", {}).get("max_policy_nodes", 0)) == 6 \
			and user_payload.has("frontier") \
			and user_payload.has("capability_context") \
			and user_payload.has("allowed_follow_route_ids"),
		"compact transport must preserve exact candidates, common capability context, and future macro allowlist"
	)
	for redundant_key: String in [
		"current_root_route_ids", "current_root_candidate_bindings",
		"allowed_candidate_ids", "allowed_fact_paths", "allowed_guard_operators",
	]:
		_check(not user_payload.has(redundant_key), "compact transport duplicated %s" % redundant_key)
	var delta_transport: Dictionary = client._build_payload(envelope, 170, true)
	var delta_messages: Array = delta_transport.get("messages", []) \
		if delta_transport.get("messages", []) is Array else []
	var delta_variant: Variant = JSON.parse_string(
		str((delta_messages[1] as Dictionary).get("content", "")) if delta_messages.size() >= 2 else ""
	)
	var delta_payload: Dictionary = delta_variant if delta_variant is Dictionary else {}
	for required_delta_key: String in [
		"profile", "observation", "belief", "match_agenda", "prize_graph",
		"threat_response", "current_policy_cursor", "material_delta", "facts",
		"resource_ledger", "capability_context", "frontier", "allowed_follow_route_ids",
	]:
		_check(delta_payload.has(required_delta_key), "stateless compact delta omitted %s" % required_delta_key)
	var strategy := StrategyScript.new()
	var factored := strategy._factor_common_capability_context([{
		"candidate_id": "candidate:a",
		"module_annotations": {"energy_burst": {
			"decision_hints": ["preserve_energy"],
			"verified_advantage": true,
		}},
	}, {
		"candidate_id": "candidate:b",
		"module_annotations": {"energy_burst": {
			"decision_hints": ["preserve_energy"],
			"warning": "reserve_shortfall",
		}},
	}])
	_check(
		factored.get("capability_context", {}).get("energy_burst", {}).get("decision_hints", []) \
			== ["preserve_energy"],
		"candidate-invariant capability facts must be hoisted exactly once"
	)
	var factored_candidates: Array = factored.get("frontier", []) \
		if factored.get("frontier", []) is Array else []
	_check(
		factored_candidates.size() == 2 \
			and bool(factored_candidates[0].get("module_annotations", {}).get("energy_burst", {}).get("verified_advantage", false)) \
			and str(factored_candidates[1].get("module_annotations", {}).get("energy_burst", {}).get("warning", "")) == "reserve_shortfall",
		"factoring must preserve every candidate-specific certificate and warning"
	)
	var sparse_outcome := strategy._compact_outcome_for_model({
		"win_now": false,
		"prizes_now": 0,
		"estimated_damage": 120,
		"attack_ready": true,
		"terminal": false,
	})
	_check(
		sparse_outcome == {"estimated_damage": 120, "attack_ready": true},
		"sparse outcomes must omit only false/zero defaults while preserving positive strategy evidence"
	)

	var validator := PolicyValidatorScript.new()
	var minimal_response := {
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": "route:information",
					"candidate_id": "candidate:root",
				},
			}],
		},
	}
	var minimal_validation := validator.validate_response(
		minimal_response,
		["route:information"],
		8,
		["candidate:root"],
		true
	)
	_check(bool(minimal_validation.get("valid", false)), "minimal compact response must pass the full local validator")
	var normalized_policy: Dictionary = minimal_validation.get("policy", {}) \
		if minimal_validation.get("policy", {}) is Dictionary else {}
	_check(
		normalized_policy.get("reservations", null) == [] \
			and normalized_policy.get("interaction_policy_refs", null) == {} \
			and normalized_policy.get("interaction_policies", null) == [] \
			and normalized_policy.get("replan_if", null) == [],
		"minimal response defaults must canonicalize before policy installation"
	)
	var legacy_full := minimal_response.duplicate(true)
	legacy_full["agenda_patch"] = {}
	legacy_full["policy"]["reservations"] = []
	legacy_full["policy"]["interaction_policy_refs"] = {}
	legacy_full["policy"]["interaction_policies"] = []
	legacy_full["policy"]["replan_if"] = []
	var full_validation := validator.validate_response(
		legacy_full,
		["route:information"],
		8,
		["candidate:root"],
		true
	)
	_check(
		bool(full_validation.get("valid", false)) \
			and full_validation.get("policy", {}) == normalized_policy,
		"legacy-full and compact-minimal responses must canonicalize identically"
	)


func _test_strict_compact_response_validation() -> void:
	var validator := PolicyValidatorScript.new()
	var allowed_routes: Array[String] = [
		"route:information", "route:develop", "route:attack_ko", "route:end_turn",
	]
	var allowed_candidates: Array[String] = ["candidate:root", "candidate:develop"]
	var base := {
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": "route:information",
					"candidate_id": "candidate:root",
				},
			}],
		},
		"transport": "python_fallback",
		"http_code": 200,
		"request_result": 0,
		"rng_isolated_transport": true,
		"rng_isolated_request_sequence": 1,
	}
	_check(
		bool(validator.validate_response(base, allowed_routes, 8, allowed_candidates, true).get("valid", false)),
		"strict semantic validation must allow known transport metadata around a compact response"
	)
	var extra_top := base.duplicate(true)
	extra_top["model_note"] = "ignored"
	_expect_invalid_response(validator, extra_top, allowed_routes, allowed_candidates, "response_additional_property")
	var extra_agenda := base.duplicate(true)
	extra_agenda["agenda_patch"] = {"victory_mode": "prize_race", "hidden_plan": true}
	_expect_invalid_response(validator, extra_agenda, allowed_routes, allowed_candidates, "agenda_additional_property")
	var extra_policy := base.duplicate(true)
	extra_policy["policy"]["commentary"] = []
	_expect_invalid_response(validator, extra_policy, allowed_routes, allowed_candidates, "policy_additional_property")
	var extra_route_node := base.duplicate(true)
	extra_route_node["policy"]["nodes"][0]["branches"] = []
	_expect_invalid_response(validator, extra_route_node, allowed_routes, allowed_candidates, "route_node_shape")
	var extra_route_ref := base.duplicate(true)
	extra_route_ref["policy"]["nodes"][0]["route_ref"]["explanation"] = "free text"
	_expect_invalid_response(validator, extra_route_ref, allowed_routes, allowed_candidates, "candidate_ref_shape")

	var short_typed := base.duplicate(true)
	short_typed["policy"]["nodes"][0]["route_ref"] = {
		"mode": "propose_typed_route",
		"route_id": "route:information",
		"first_candidate_id": "candidate:root",
		"macro_actions": ["route:information"],
	}
	_expect_invalid_response(validator, short_typed, allowed_routes, allowed_candidates, "typed_route_macro_count")
	var long_typed := short_typed.duplicate(true)
	long_typed["policy"]["nodes"][0]["route_ref"]["macro_actions"] = [
		"route:information", "route:develop", "route:information", "route:develop", "route:end_turn",
	]
	_expect_invalid_response(validator, long_typed, allowed_routes, allowed_candidates, "typed_route_macro_count")
	var non_root_typed := base.duplicate(true)
	non_root_typed["policy"]["nodes"][0]["next_node_id"] = "node:later"
	non_root_typed["policy"]["nodes"].append({
		"node_id": "node:later",
		"kind": "route",
		"route_ref": {
			"mode": "propose_typed_route",
			"route_id": "route:develop",
			"first_candidate_id": "candidate:develop",
			"macro_actions": ["route:develop", "route:end_turn"],
		},
	})
	_expect_invalid_response(validator, non_root_typed, allowed_routes, allowed_candidates, "typed_route_non_root")
	var crosses_information := short_typed.duplicate(true)
	crosses_information["policy"]["nodes"][0]["route_ref"]["macro_actions"] = [
		"route:information", "route:develop", "route:end_turn",
	]
	_expect_invalid_response(
		validator,
		crosses_information,
		allowed_routes,
		allowed_candidates,
		"typed_route_crosses_information_checkpoint"
	)
	var ends_at_information := short_typed.duplicate(true)
	ends_at_information["policy"]["nodes"][0]["route_ref"] = {
		"mode": "propose_typed_route",
		"route_id": "route:develop",
		"first_candidate_id": "candidate:develop",
		"macro_actions": ["route:develop", "route:information"],
	}
	_check(
		bool(validator.validate_response(
			ends_at_information, allowed_routes, 8, allowed_candidates, true
		).get("valid", false)),
		"a typed macro may finish at an information boundary"
	)

	var bad_reservations := base.duplicate(true)
	bad_reservations["policy"]["reservations"] = [{}, {}, {}, {}, {}, {}, {}]
	_expect_invalid_response(validator, bad_reservations, allowed_routes, allowed_candidates, "reservations_count")
	var bad_replan := base.duplicate(true)
	bad_replan["policy"]["replan_if"] = ["read_hidden_prize"]
	_expect_invalid_response(validator, bad_replan, allowed_routes, allowed_candidates, "replan_if")

	var valid_interaction := base.duplicate(true)
	valid_interaction["policy"]["interaction_policy_refs"] = {"default": "policy:test"}
	valid_interaction["policy"]["interaction_policies"] = [{
		"policy_id": "policy:test",
		"rank_by": ["route_completion", "stable_id"],
		"desired_roles": ["next_attacker", "energy_access"],
		"must_preserve": ["next_attacker"],
		"target_position": "own_bench",
		"energy_symbols": ["L"],
		"prize_goal": "shortest_safe_path",
		"min_select": 1,
		"max_select": 2,
		"allow_explicit_empty": false,
		"tie_breakers": ["stable_id"],
	}]
	_check(
		bool(validator.validate_response(valid_interaction, allowed_routes, 8, allowed_candidates, true).get("valid", false)),
		"a complete typed interaction policy must pass strict local validation"
	)
	var missing_interaction_field := valid_interaction.duplicate(true)
	missing_interaction_field["policy"]["interaction_policies"][0].erase("desired_roles")
	_expect_invalid_response(
		validator, missing_interaction_field, allowed_routes, allowed_candidates,
		"interaction_policy_missing_field"
	)
	var extra_interaction_field := valid_interaction.duplicate(true)
	extra_interaction_field["policy"]["interaction_policies"][0]["natural_language"] = "pick the best"
	_expect_invalid_response(
		validator, extra_interaction_field, allowed_routes, allowed_candidates,
		"interaction_policy_additional_property"
	)
	var invalid_interaction_role := valid_interaction.duplicate(true)
	invalid_interaction_role["policy"]["interaction_policies"][0]["desired_roles"] = ["hidden_card"]
	_expect_invalid_response(
		validator, invalid_interaction_role, allowed_routes, allowed_candidates,
		"interaction_desired_roles"
	)

	var multi_checkpoint := {
		"agenda_patch": {"victory_mode": "prize_race", "attacker_chain": ["primary", "next_attacker"]},
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": "route:information",
					"candidate_id": "candidate:root",
				},
				"next_node_id": "node:check_one",
			}, {
				"node_id": "node:check_one",
				"kind": "checkpoint",
				"branches": [{
					"when_all": [{"fact": "attack.ready", "op": "==", "value": true}],
					"next_node_id": "node:attack_one",
				}, {
					"when_all": [{"fact": "attack.ready", "op": "==", "value": false}],
					"next_node_id": "node:develop",
				}],
				"otherwise": "node:check_two",
			}, {
				"node_id": "node:attack_one",
				"kind": "route",
				"route_ref": {"mode": "follow_route", "route_id": "route:attack_ko"},
				"next_node_id": "node:check_two",
			}, {
				"node_id": "node:develop",
				"kind": "route",
				"route_ref": {"mode": "follow_route", "route_id": "route:develop"},
				"next_node_id": "node:check_two",
			}, {
				"node_id": "node:check_two",
				"kind": "checkpoint",
				"branches": [{
					"when_all": [{"fact": "attack.ko_available", "op": "==", "value": true}],
					"next_node_id": "node:finish",
				}, {
					"when_all": [{"fact": "resources.deck_low", "op": "==", "value": true}],
					"next_node_id": "node:end",
				}],
				"otherwise": "node:terminal",
			}, {
				"node_id": "node:finish",
				"kind": "route",
				"route_ref": {"mode": "follow_route", "route_id": "route:attack_ko"},
			}, {
				"node_id": "node:end",
				"kind": "route",
				"route_ref": {"mode": "follow_route", "route_id": "route:end_turn"},
			}, {
				"node_id": "node:terminal",
				"kind": "terminal",
			}],
			"reservations": [],
			"interaction_policy_refs": {},
			"interaction_policies": [],
			"replan_if": ["no_branch_matches", "current_route_invalid"],
		},
	}
	var multi_validation := validator.validate_response(
		multi_checkpoint, allowed_routes, 8, allowed_candidates, true
	)
	_check(bool(multi_validation.get("valid", false)), "an 8-node graph with two checkpoints and two branches each must remain valid")
	var multi_nodes: Array = multi_validation.get("policy", {}).get("nodes", []) \
		if multi_validation.get("policy", {}).get("nodes", []) is Array else []
	var checkpoint_count := 0
	for raw_node: Variant in multi_nodes:
		if raw_node is Dictionary and str((raw_node as Dictionary).get("kind", "")) == "checkpoint":
			checkpoint_count += 1
	_check(multi_nodes.size() == 8 and checkpoint_count == 2, "strict validation must preserve multi-checkpoint graph capacity")
	var disconnected_graph := multi_checkpoint.duplicate(true)
	disconnected_graph["policy"]["nodes"][0].erase("next_node_id")
	var disconnected_validation := validator.validate_response(
		disconnected_graph, allowed_routes, 8, allowed_candidates, true
	)
	_check(
		bool(disconnected_validation.get("valid", false)) \
			and int(disconnected_validation.get("canonicalized_unreachable_nodes", 0)) == 7 \
			and (disconnected_validation.get("policy", {}).get("nodes", []) as Array).size() == 1,
		"strict validation must remove semantically dead nodes without inventing graph edges"
	)

	var extra_checkpoint := multi_checkpoint.duplicate(true)
	extra_checkpoint["policy"]["nodes"][1]["summary"] = "free text"
	_expect_invalid_response(validator, extra_checkpoint, allowed_routes, allowed_candidates, "checkpoint_node_shape")
	var extra_branch := multi_checkpoint.duplicate(true)
	extra_branch["policy"]["nodes"][1]["branches"][0]["weight"] = 1
	_expect_invalid_response(validator, extra_branch, allowed_routes, allowed_candidates, "branch_shape")
	var extra_guard := multi_checkpoint.duplicate(true)
	extra_guard["policy"]["nodes"][1]["branches"][0]["when_all"][0]["expression"] = "hidden"
	_expect_invalid_response(validator, extra_guard, allowed_routes, allowed_candidates, "guard_shape")
	var terminal_edge := multi_checkpoint.duplicate(true)
	terminal_edge["policy"]["nodes"][7]["next_node_id"] = "node:root"
	_expect_invalid_response(validator, terminal_edge, allowed_routes, allowed_candidates, "terminal_node_shape")

	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:root",
		"route_id": "route:information",
	}, {
		"candidate_id": "candidate:develop",
		"route_id": "route:develop",
	}]
	var non_root_mismatch := multi_checkpoint.duplicate(true)
	non_root_mismatch["policy"]["nodes"][3]["route_ref"] = {
		"mode": "select_candidate",
		"route_id": "route:attack_ko",
		"candidate_id": "candidate:develop",
	}
	var mismatch_validation := validator.validate_response(
		non_root_mismatch, allowed_routes, 8, allowed_candidates, true
	)
	var mismatch_binding := validator.bind_root_to_frontier(
		mismatch_validation.get("policy", {}) if bool(mismatch_validation.get("valid", false)) else {},
		frontier
	)
	var bound_nodes: Array = mismatch_binding.get("policy", {}).get("nodes", []) \
		if mismatch_binding.get("policy", {}).get("nodes", []) is Array else []
	_check(
		bool(mismatch_binding.get("valid", false)) \
			and bound_nodes.size() == 8 \
			and str(bound_nodes[3].get("route_ref", {}).get("route_id", "")) == "route:develop",
		"every non-root exact candidate must be rebound to its engine-owned frontier route"
	)
	var missing_non_root := non_root_mismatch.duplicate(true)
	missing_non_root["policy"]["nodes"][3]["route_ref"]["candidate_id"] = "candidate:missing"
	var missing_validation := validator.validate_response(
		missing_non_root,
		allowed_routes,
		8,
		["candidate:root", "candidate:develop", "candidate:missing"],
		true
	)
	var missing_binding := validator.bind_root_to_frontier(
		missing_validation.get("policy", {}) if bool(missing_validation.get("valid", false)) else {},
		frontier
	)
	_check(
		not bool(missing_binding.get("valid", true)) \
			and str(missing_binding.get("reason", "")) == "unknown_candidate",
		"every non-root exact candidate must exist in the engine-owned frontier"
	)


func _test_profiles() -> void:
	var profiles := ProfileCatalogScript.list_profiles()
	_check(profiles.size() == 24, "profile catalog must contain all 24 built-in 18.0 decks")
	var ids: Dictionary = {}
	for profile: Dictionary in profiles:
		ids[str(profile.get("strategy_id", ""))] = true
		_check(str(profile.get("runtime_kind", "")) == ContractsScript.RUNTIME_KIND, "profile runtime kind must be V18CPG")
		_check(not (profile.get("rule_profile", {}) as Dictionary).is_empty(), "profile must have an independent rule fallback profile")
		_check(not (profile.get("modules", []) as Array).is_empty(), "every profile must compose at least one capability module")
	_check(ids.size() == 24, "all 24 V18CPG strategy ids must be unique")
	_check(ProfileCatalogScript.get_profile_for_deck(800018509).get("modules", []) == [
		"energy_burst", "tera_noctowl_search", "cycle_pivot"
	], "Raging Bolt must compose its three declared strategic shapes")
	_check(ProfileCatalogScript.get_profile_for_deck(800017643).get("modules", []) == [
		"tera_noctowl_search", "energy_burst", "cycle_pivot"
	], "Flareon must compose its three declared strategic shapes")
	_check(ProfileCatalogScript.get_profile_for_deck(800015934).get("modules", []) == [
		"tera_noctowl_search", "energy_burst", "cycle_pivot"
	], "Tord toolbox must compose search, energy, and pivot shapes")
	_check(ProfileCatalogScript.list_variant_metadata(false).is_empty(), "feature flag off must expose no V18CPG variants")


func _test_hidden_information_firewall() -> void:
	var state := GameState.new()
	state.players = [_player(0), _player(1)]
	state.current_player_index = 0
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	state.players[0].deck.append(_card("OWN_DECK_SENTINEL", 0))
	state.players[0].prizes.append(_card("OWN_PRIZE_SENTINEL", 0))
	state.players[1].hand.append(_card("OPPONENT_HAND_SENTINEL", 1))
	state.players[1].prizes.append(_card("OPPONENT_PRIZE_SENTINEL", 1))
	var gateway := ObservationGatewayScript.new()
	var envelope := gateway.build(state, 0, [{"kind": "end_turn"}])
	var serialized := JSON.stringify(envelope)
	_check(not serialized.contains("OWN_DECK_SENTINEL"), "own raw deck identity leaked")
	_check(not serialized.contains("OWN_PRIZE_SENTINEL"), "own prize identity leaked")
	_check(not serialized.contains("OPPONENT_HAND_SENTINEL"), "opponent hand identity leaked")
	_check(not serialized.contains("OPPONENT_PRIZE_SENTINEL"), "opponent prize identity leaked")
	var active := PokemonSlot.new()
	active.pokemon_stack = [_pokemon("Attack Window Fixture", "TEST", "ATTACK_WINDOW")]
	state.players[0].active_pokemon = active
	var open_window := gateway.build(state, 0, [{"kind": "end_turn"}])
	_check(
		bool(open_window.get("turn", {}).get("deterministic_attack_window_open", false)),
		"a normal public MAIN-phase attack window must be open"
	)
	active.effects = [{"type": "attack_lock_all", "turn": 0}]
	var locked_window := gateway.build(state, 0, [{"kind": "end_turn"}])
	_check(
		not bool(locked_window.get("turn", {}).get("deterministic_attack_window_open", true)),
		"a live public attack_lock_all effect must close the deterministic attack window"
	)
	active.effects = [{"type": "attack_lock_until_leave_active", "attack_name": "Fixture Attack"}]
	locked_window = gateway.build(state, 0, [{"kind": "end_turn"}])
	_check(
		not bool(locked_window.get("turn", {}).get("deterministic_attack_window_open", true)),
		"attack_lock_until_leave_active must fail closed without an attack-name binding"
	)
	active.effects.clear()
	state.turn_number = 1
	state.first_player_index = 0
	locked_window = gateway.build(state, 0, [{"kind": "end_turn"}])
	_check(
		not bool(locked_window.get("turn", {}).get("deterministic_attack_window_open", true)),
		"the first player's first turn must close cost-completion takeover"
	)
	state.turn_number = 2
	var visible := _card("LEGAL_FULL_DECK_VISIBLE", 0)
	var search_envelope := gateway.build(state, 0, [], {
		"id": "test_search",
		"visible_scope": "own_full_deck",
		"items": [visible],
		"min_select": 0,
		"max_select": 1,
	})
	var search_text := JSON.stringify(search_envelope)
	_check(search_text.contains("LEGAL_FULL_DECK_VISIBLE"), "authorized full-deck item should be visible")
	_check(not search_text.contains("OWN_DECK_SENTINEL"), "gateway must not supplement a search with raw deck cards")


func _test_belief_replay() -> void:
	var events: Array[Dictionary] = [{
		"type": "FULL_DECK_VIEW_OPENED",
		"turn": 3,
		"visible_cards": [{"uid": "A"}, {"uid": "A"}, {"uid": "B"}],
		"expected_counts": {"A": 3, "B": 1},
	}, {
		"type": "PRIZE_TAKEN",
		"opponent_revealed_cards": [{"uid": "C"}],
	}]
	var first := BeliefStateScript.new().replay(events)
	var second := BeliefStateScript.new().replay(events)
	_check(str(first.get("belief_hash", "")) == str(second.get("belief_hash", "")), "belief replay must be deterministic")
	_check(first.get("own", {}).get("possible_prized", {}).get("A", []) == [0, 1], "full-deck view should update a bounded prized belief")


func _test_policy_graph_contract() -> void:
	var validator := PolicyValidatorScript.new()
	var response := {
		"agenda_patch": {"victory_mode": "prize_race"},
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {"mode": "select_existing", "route_id": "route:noctowl_search"},
				"next_node_id": "node:check",
			}, {
				"node_id": "node:check",
				"kind": "checkpoint",
				"branches": [{
					"when_all": [{"fact": "attack.ko_available", "op": "==", "value": true}],
					"next_node_id": "node:attack",
				}],
				"otherwise": "local_best",
			}, {
				"node_id": "node:attack",
				"kind": "route",
				"route_ref": {"mode": "select_existing", "route_id": "route:attack_ko"},
			}],
			"reservations": [],
			"interaction_policy_refs": {},
			"replan_if": [],
		},
	}
	var valid := validator.validate_response(response, ["route:noctowl_search", "route:attack_ko"], 8)
	_check(bool(valid.get("valid", false)), "valid policy graph should pass")
	var bad := response.duplicate(true)
	bad["policy"]["nodes"][1]["branches"][0]["when_all"][0]["fact"] = "opponent.hidden_hand"
	var invalid := validator.validate_response(bad, ["route:noctowl_search", "route:attack_ko"], 8)
	_check(not bool(invalid.get("valid", false)) and str(invalid.get("reason", "")) == "unknown_fact", "unregistered hidden fact must be rejected")


func _test_noctowl_pair_search() -> void:
	var module := NoctowlSearchScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(800015934)
	var vessel := _trainer("Earthen Vessel", "Search your deck for up to 2 Basic Energy cards.")
	var energy_switch := _trainer("Energy Switch", "Move a basic Energy from 1 of your Pokemon to another.")
	var boss := _supporter("Boss's Orders", "Switch in 1 of your opponent's Benched Pokemon.")
	var nest := _trainer("Nest Ball", "Search your deck for a Basic Pokemon and put it onto your Bench.")
	var noctowl := _pokemon("Noctowl", "LEN_SCR", "115")
	var picked := module.pick_pair(
		[vessel, energy_switch, boss, nest],
		{"id": "jewel_seeker_cards", "min_select": 0, "max_select": 2, "visible_scope": "own_full_deck"},
		{"pending_effect_card": noctowl},
		profile,
		{},
		"route:energy_commit"
	)
	_check(picked.size() == 2, "Noctowl search should choose a pair")
	_check(vessel in picked and energy_switch in picked, "Tord Noctowl pair should jointly complete energy access plus movement")
	_check(
		module.verify_pair_override(
			picked,
			[boss, nest],
			{"id": "jewel_seeker_cards", "min_select": 0, "max_select": 2},
			{"v18cpg_facts": {"resources": {"deck_critical": false}}},
			profile,
			{},
			"route:energy_commit"
		),
		"Noctowl may override Rule only when the typed pair score clears an independent margin"
	)
	var tera_target := _pokemon("Teal Mask Ogerpon ex", "CSV8C", "028")
	tera_target.card_data.stage = "Basic"
	var rule_fan_rotom := _pokemon("Fan Rotom", "CSV9C", "161")
	rule_fan_rotom.card_data.stage = "Basic"
	var expansion_context := {
		"v18cpg_facts": {
			"board": {"has_tera": false},
			"resources": {"bench_slots_free": 1},
		},
		"v18cpg_observation": {"stadium": {"uid": "CSV9C_207"}},
	}
	var expansion_override := module.pick_verified_basic_search_override(
		[rule_fan_rotom, tera_target],
		{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
		[rule_fan_rotom],
		expansion_context,
		profile
	)
	_check(
		bool(expansion_override.get("handled", false)) \
			and expansion_override.get("items", []) == [tera_target],
		"with Area Zero and one bench slot left, a verified Tera basic must replace a non-Tera search target"
	)
	var already_tera_context := expansion_context.duplicate(true)
	already_tera_context["v18cpg_facts"]["board"]["has_tera"] = true
	_check(
		not bool(module.pick_verified_basic_search_override(
			[rule_fan_rotom, tera_target],
			{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
			[rule_fan_rotom],
			already_tera_context,
			profile
		).get("handled", false)),
		"the Tera expansion override must switch off once board expansion is already active"
	)
	var interaction_strategy := StrategyScript.new()
	interaction_strategy.configure_profile(profile)
	interaction_strategy.set("_runtime_configured", true)
	interaction_strategy.set("_current_action_owner", "local_gate")
	interaction_strategy.set("_last_facts", expansion_context.get("v18cpg_facts", {}))
	interaction_strategy.set("_last_observation", expansion_context.get("v18cpg_observation", {}))
	var strategy_expansion_pick := interaction_strategy.pick_interaction_items(
		[rule_fan_rotom, tera_target],
		{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
		{}
	)
	_check(
		strategy_expansion_pick == [tera_target],
		"the strategy bridge must apply a certified Tera expansion pick even when the root action stayed Rule-owned"
	)
	interaction_strategy.set("_current_action_owner", "deadline_fallback")
	var rejected_response_pick := interaction_strategy.pick_interaction_items(
		[rule_fan_rotom, tera_target],
		{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
		{}
	)
	_check(
		rejected_response_pick == [rule_fan_rotom],
		"a rejected model response must not activate local-only interaction overrides"
	)
	var bloodmoon_slot := PokemonSlot.new()
	bloodmoon_slot.pokemon_stack.append(_pokemon("Bloodmoon Ursaluna ex", "CSV8C", "172"))
	var wellspring_slot := PokemonSlot.new()
	wellspring_slot.pokemon_stack.append(_pokemon("Wellspring Mask Ogerpon ex", "CSV8C", "067"))
	interaction_strategy.set("_current_action_owner", "policy_graph_branch")
	interaction_strategy.set("_current_route_id", "route:accelerate")
	interaction_strategy.set("_active_module_certificate_kind", "banked_energy_handoff")
	var bloodmoon_score := interaction_strategy.score_interaction_target(
		bloodmoon_slot,
		{"id": "energy_assignment"},
		{}
	)
	var wellspring_score := interaction_strategy.score_interaction_target(
		wellspring_slot,
		{"id": "energy_assignment"},
		{}
	)
	_check(
		bloodmoon_score > wellspring_score,
		"a model-owned certified rescue route must retain the module-verified Bloodmoon target"
	)


func _test_rule_floor_and_route_safety() -> void:
	var route_search := RouteSearchScript.new()
	var frontier := route_search.build_frontier({
		"legal_actions": [
			{"id": "attack", "kind": "attack", "projected_knockout": true, "projected_damage": 300},
			{"id": "end", "kind": "end_turn"},
		],
	}, {"attack": 100.0, "end": 200.0}, {}, {"resources": {"prizes_remaining": 6}}, 8)
	_check(str(frontier[0].get("route_id", "")) == "route:end_turn", "local frontier must preserve the rules strategy ordering")
	_check(float(frontier[0].get("base_score", 0.0)) == 200.0, "frontier must expose the rules-floor score")
	var localized_sentinel := "Jewel Seeker 宝石搜寻 Fan Call 风扇呼唤"
	var typed_frontier := route_search.build_frontier({
		"legal_actions": [
			{"id": "noctowl", "kind": "use_ability", "ability_name": localized_sentinel, "source_card": {"uid": "CSV9C_155"}},
			{"id": "fan", "kind": "use_ability", "ability_name": localized_sentinel, "source_card": {"uid": "LEN_SCR_118"}},
			{"id": "unknown", "kind": "use_ability", "ability_name": localized_sentinel, "source_card": {"uid": "TEST_001"}},
		],
	}, {"noctowl": 300.0, "fan": 200.0, "unknown": 100.0}, {}, {"resources": {"prizes_remaining": 6}}, 8)
	_check(not route_search.find_route(typed_frontier, "route:noctowl_search").is_empty(), "Noctowl route must use exact source UID")
	_check(not route_search.find_route(typed_frontier, "route:opening_search").is_empty(), "Fan Call route must use exact source UID")
	var unknown_route := route_search.find_route(typed_frontier, "route:information")
	_check(not unknown_route.is_empty(), "ability text alone must remain generic information")
	_check(not JSON.stringify(typed_frontier).contains(localized_sentinel), "model-visible route summary must exclude localized action text")
	var strategy := StrategyScript.new()
	strategy.configure_profile(ProfileCatalogScript.get_profile_for_deck(800018509))
	var safety_frontier: Array[Dictionary] = [{
		"route_id": "route:attack_pressure",
		"base_score": 500.0,
		"local_score": 500.0,
		"outcome": {"win_now": false, "prizes_now": 0},
	}, {
		"route_id": "route:information",
		"base_score": 300.0,
		"local_score": 300.0,
		"outcome": {"win_now": false, "prizes_now": 0},
	}]
	var low_deck := strategy._validate_model_route_safety("route:information", safety_frontier, {"resources": {"deck_low": true}})
	_check(not bool(low_deck.get("valid", true)) and str(low_deck.get("reason", "")) == "deckout_margin_blocks_search", "low-deck model search must be blocked when the rule floor has a safe route")
	var margin := strategy._validate_model_route_safety("route:information", safety_frontier, {"resources": {"deck_low": false}})
	_check(not bool(margin.get("valid", true)) and str(margin.get("reason", "")) == "model_route_below_switch_margin", "model route below the configured switch margin must be rejected")
	var neutral_same_route: Array[Dictionary] = [{
		"candidate_id": "candidate:rule_top",
		"route_id": "route:information",
		"base_score": 100.0,
		"local_score": 100.0,
		"checkpoint_after": "information_result",
		"outcome": {"information_gain": 0.8, "expected_route_improvement": 0.5, "resource_commitment": 0.0},
	}, {
		"candidate_id": "candidate:arbitrary_tie",
		"route_id": "route:information",
		"base_score": 100.0,
		"local_score": 100.0,
		"checkpoint_after": "information_result",
		"outcome": {"information_gain": 0.8, "expected_route_improvement": 0.5, "resource_commitment": 0.0},
	}]
	var neutral_switch := strategy._validate_model_route_safety(
		"route:information",
		neutral_same_route,
		{"resources": {"deck_low": false}},
		"candidate:arbitrary_tie"
	)
	_check(
		not bool(neutral_switch.get("valid", true)) \
			and str(neutral_switch.get("reason", "")) == "same_route_switch_without_verified_advantage",
		"model must not replace the Rule tie-break with an unsupported same-route guess"
	)
	var ambiguous_top := strategy._validate_model_route_safety(
		"route:information",
		neutral_same_route,
		{"resources": {"deck_low": false}},
		"candidate:rule_top"
	)
	_check(
		not bool(ambiguous_top.get("valid", true)) \
			and str(ambiguous_top.get("reason", "")) == "ambiguous_rule_tie_without_verified_advantage",
		"frontier order alone must not claim an exact Rule action when host-only intent scoring can break the tie"
	)
	_check(
		strategy._can_defer_ambiguous_root_to_rule(neutral_same_route[0], neutral_same_route),
		"same-route reversible information ties may execute on the Rule floor while retaining only the future graph"
	)
	var terminal_tie := neutral_same_route.duplicate(true)
	terminal_tie[0]["route_id"] = "route:attack_pressure"
	terminal_tie[1]["route_id"] = "route:attack_pressure"
	terminal_tie[0]["checkpoint_after"] = "terminal"
	terminal_tie[1]["checkpoint_after"] = "terminal"
	_check(
		not strategy._can_defer_ambiguous_root_to_rule(terminal_tie[0], terminal_tie),
		"terminal ties must never be hidden behind a Rule-owned shadow root"
	)
	var fact_builder := FactBuilderScript.new()
	var custom_threshold := fact_builder.build({
		"legal_actions": [{"kind": "use_ability", "ability_name": "localized text does not matter", "source_card": {"uid": "CSV9C_155"}}],
		"own": {"deck_count": 9, "hand_count": 3, "prizes_remaining": 6, "active": {}, "bench": []},
		"turn": {"quotas": {}},
	}, "", {"safety": {"low_deck_threshold": 10}})
	_check(bool(custom_threshold.get("resources", {}).get("deck_low", false)), "profile low-deck threshold must drive registered facts")
	_check(bool(custom_threshold.get("fan_call", {}).get("available", false)), "Fan Call fact must use stable source UID")
	var name_only := fact_builder.build({
		"legal_actions": [{"kind": "use_ability", "ability_name": "Jewel Seeker", "source_card": {"uid": "TEST_001"}}],
		"own": {"deck_count": 30, "hand_count": 3, "prizes_remaining": 6, "active": {}, "bench": []},
		"turn": {"quotas": {}},
	})
	_check(not bool(name_only.get("fan_call", {}).get("available", false)), "localized ability text must not activate a typed Fan Call fact")

	var tord_profile := ProfileCatalogScript.get_profile_for_deck(800015934)
	var handoff_facts := {
		"attack": {"ready": false, "ko_available": false},
		"resources": {"deck_low": false, "energy_on_board": 1},
	}
	var handoff_frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:end",
		"route_id": "route:end_turn",
		"action_kind": "end_turn",
		"checkpoint_after": "terminal",
		"base_score": -1024.0,
		"local_score": -1024.0,
		"outcome": {"terminal": true},
	}, {
		"candidate_id": "candidate:energy_switch",
		"route_id": "route:accelerate",
		"safe_prefix_action_id": "action:energy_switch",
		"action_kind": "play_trainer",
		"action_ref": {"card": {"uid": "CSVH1aC_008"}},
		"action_semantic_roles": ["item", "energy_mover"],
		"checkpoint_after": "action_resolved",
		"base_score": -2150.0,
		"local_score": -2150.0,
		"outcome": {"terminal": false},
	}]
	var handoff_observation := {
		"own": {
			"deck_count": 20,
			"active": {
				"pokemon": {"uid": "CSV9C_175"},
				"energy_count": 1,
				"energy": [{"uid": "CSVE1C_PSY", "energy_type": "P"}],
				"remaining_hp": 20,
			},
			"bench": [{
				"pokemon": {"uid": "CSV8C_172"},
				"energy_count": 0,
				"energy": [],
			}],
		},
		"opponent": {
			"active": {"energy_count": 2},
			"bench": [],
		},
		"turn": {"quotas": {}},
		"legal_actions": [{
			"id": "action:energy_switch",
			"kind": "play_trainer",
			"card": {"uid": "CSVH1aC_008"},
		}],
	}
	var handoff_module := NoctowlSearchScript.new()
	handoff_frontier = handoff_module.annotate_frontier_v2(
		handoff_frontier,
		handoff_observation,
		handoff_facts,
		tord_profile,
		{"cards": [{"uid": "CSV8C_172", "roles": ["pokemon"]}]}
	)
	_check(
		bool(handoff_frontier[1].get("module_annotations", {}).get("tera_noctowl_search", {}).get("verified_advantage", false)),
		"a live bank-to-empty-attacker Energy Switch must carry a public-state advantage certificate"
	)
	_check(
		int(handoff_frontier[1].get("module_annotations", {}).get("tera_noctowl_search", {}).get("threatened_energy_source_count", 0)) == 1,
		"a damaged active attacker facing visible powered pressure must be recognized as a rescue source"
	)
	var tord_strategy := StrategyScript.new()
	tord_strategy.configure_profile(tord_profile)
	var handoff_safety := tord_strategy._validate_model_route_safety(
		"route:accelerate",
		handoff_frontier,
		handoff_facts,
		"candidate:energy_switch"
	)
	_check(
		bool(handoff_safety.get("valid", false)) \
			and str(handoff_safety.get("reason", "")) == "module_verified_advantage",
		"a certified Energy Switch handoff may replace end_turn despite the Rule score gap"
	)
	var tera_facts := {
		"attack": {"ready": false, "ko_available": false},
		"board": {"has_tera": false},
		"resources": {"bench_slots_free": 1, "energy_on_board": 2},
	}
	var tera_frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:end_after_draw",
		"route_id": "route:end_turn",
		"safe_prefix_action_id": "action:end",
		"action_kind": "end_turn",
		"checkpoint_after": "terminal",
		"base_score": -1024.0,
		"local_score": -1024.0,
		"outcome": {"terminal": true},
	}, {
		"candidate_id": "candidate:teal_from_hand",
		"route_id": "route:develop",
		"safe_prefix_action_id": "action:teal",
		"action_kind": "play_basic_to_bench",
		"checkpoint_after": "action_resolved",
		"base_score": -100000.0,
		"local_score": -100000.0,
		"outcome": {"terminal": false},
	}, {
		"candidate_id": "candidate:mew_followup",
		"route_id": "route:develop",
		"safe_prefix_action_id": "action:mew",
		"action_kind": "play_basic_to_bench",
		"checkpoint_after": "action_resolved",
		"base_score": -100000.0,
		"local_score": -100000.0,
		"outcome": {"terminal": false},
	}]
	var tera_observation := {
		"own": {
			"deck_count": 30,
			"active": {},
			"bench": [{}, {}, {}, {}],
		},
		"opponent": {"active": {}, "bench": []},
		"stadium": {"uid": "CSV9C_207"},
		"turn": {"quotas": {}},
		"legal_actions": [{
			"id": "action:end",
			"kind": "end_turn",
		}, {
			"id": "action:teal",
			"kind": "play_basic_to_bench",
			"card": {"uid": "CSV8C_028"},
		}, {
			"id": "action:mew",
			"kind": "play_basic_to_bench",
			"card": {"uid": "151C_151"},
		}],
	}
	tera_frontier = handoff_module.annotate_frontier_v2(
		tera_frontier, tera_observation, tera_facts, tord_profile, {}
	)
	var tera_safety := tord_strategy._validate_model_route_safety(
		"route:develop", tera_frontier, tera_facts, "candidate:teal_from_hand"
	)
	_check(
		bool(tera_safety.get("valid", false)) \
			and str(tera_safety.get("reason", "")) == "module_verified_advantage",
		"a visible Tera in hand may replace end_turn only when Area Zero immediately unlocks another Basic deployment"
	)
	var no_followup_observation := tera_observation.duplicate(true)
	no_followup_observation["legal_actions"] = [
		tera_observation["legal_actions"][0],
		tera_observation["legal_actions"][1],
	]
	var no_followup_frontier := handoff_module.annotate_frontier_v2(
		tera_frontier, no_followup_observation, tera_facts, tord_profile, {}
	)
	var no_followup_safety := tord_strategy._validate_model_route_safety(
		"route:develop", no_followup_frontier, tera_facts, "candidate:teal_from_hand"
	)
	_check(
		not bool(no_followup_safety.get("valid", true)),
		"Area Zero capacity alone must not justify benching a two-prize Tera without an immediate visible follow-up"
	)
	_check(
		tord_strategy._required_selection_bonus(tera_frontier[1], tera_frontier) > 98000.0,
		"an approved exact candidate must receive enough execution authority to clear a Rule sentinel score"
	)
	var verified_upgrade := tord_strategy._find_module_verified_upgrade(
		handoff_frontier,
		handoff_facts
	)
	_check(
		str(verified_upgrade.get("candidate_id", "")) == "candidate:energy_switch",
		"an active model graph must be able to consume a newly verified post-checkpoint upgrade locally"
	)
	_check(
		tord_strategy._should_shadow_exact_rule_root({"valid": true, "reason": "matches_rules_floor"}),
		"a model response that selects the exact Rule root must retain only its future graph"
	)
	_check(
		not tord_strategy._has_model_execution_certificate({"valid": true, "reason": "validated_switch"}) \
			and tord_strategy._has_model_execution_certificate({"valid": true, "reason": "module_verified_advantage"}),
		"strict monotonic mode must execute only independently certified model routes"
	)
	_check(
		not tord_strategy._strict_certificate_blocks_route(
			{"valid": true, "reason": "matches_rules_floor"}, true
		),
		"strict monotonic mode must allow an exact Rule-root response to install only its shadow graph"
	)
	_check(
		tord_strategy._strict_certificate_blocks_route(
			{"valid": true, "reason": "validated_switch"}, false
		),
		"strict monotonic mode must still block an uncertified model-owned root"
	)
	var ready_handoff_facts := handoff_facts.duplicate(true)
	ready_handoff_facts["attack"]["ready"] = true
	var blocked_handoff := tord_strategy._validate_model_route_safety(
		"route:accelerate",
		handoff_frontier,
		ready_handoff_facts,
		"candidate:energy_switch"
	)
	_check(
		not bool(blocked_handoff.get("valid", true)),
		"the Energy Switch certificate must not override an already-ready attack"
	)


func _test_exact_candidate_frontier() -> void:
	var route_search := RouteSearchScript.new()
	var frontier := route_search.build_frontier({
		"legal_actions": [
			{"id": "attach:best", "kind": "attach_energy", "card": {"uid": "ENERGY_L"}, "target": "slot:1"},
			{"id": "attach:next", "kind": "attach_energy", "card": {"uid": "ENERGY_L"}, "target": "slot:2"},
			{"id": "attach:third", "kind": "attach_energy", "card": {"uid": "ENERGY_L"}, "target": "slot:3"},
			{"id": "attack", "kind": "attack", "projected_damage": 120},
		],
	}, {
		"attach:best": 500.0,
		"attach:next": 490.0,
		"attach:third": 480.0,
		"attack": 450.0,
	}, {}, {"resources": {"prizes_remaining": 6}}, 8)
	var energy_candidates: Array[Dictionary] = []
	for candidate: Dictionary in frontier:
		if str(candidate.get("route_id", "")) == "route:energy_commit":
			energy_candidates.append(candidate)
	_check(energy_candidates.size() >= 2, "frontier must preserve multiple exact targets in the same macro route")
	_check(str(frontier[0].get("safe_prefix_action_id", "")) == "attach:best", "diversified frontier must preserve the exact Rule top action")
	var candidate_ids: Dictionary = {}
	for candidate: Dictionary in frontier:
		var candidate_id := str(candidate.get("candidate_id", ""))
		_check(candidate_id.begins_with("candidate:"), "every frontier entry must have a stable typed candidate id")
		candidate_ids[candidate_id] = true
	_check(candidate_ids.size() == frontier.size(), "candidate ids must be unique inside an observation")
	var tied_frontier := route_search.build_frontier({
		"legal_actions": [
			{"id": "rule:first", "kind": "use_ability", "source_card": {"uid": "FIRST"}},
			{"id": "rule:second", "kind": "use_ability", "source_card": {"uid": "SECOND"}},
		],
	}, {"rule:first": 55.2, "rule:second": 55.2}, {}, {"resources": {"prizes_remaining": 6}}, 8)
	_check(
		str(tied_frontier[0].get("safe_prefix_action_id", "")) == "rule:first",
		"frontier ties must preserve the engine legal-action order used by the Rule scorer"
	)
	var certified_frontier := StrategyScript.new()._bind_engine_rule_floor(tied_frontier, "rule:second")
	_check(
		str(certified_frontier[0].get("safe_prefix_action_id", "")) == "rule:second" \
			and bool(certified_frontier[0].get("engine_rule_floor_exact", false)),
		"an engine-provided Rule certificate must override any projected-score tie ordering"
	)
	var certified_strategy := StrategyScript.new()
	certified_strategy.configure_profile(ProfileCatalogScript.get_profile_for_deck(800018509))
	var certified_safety := certified_strategy._validate_model_route_safety(
		str(certified_frontier[0].get("route_id", "")),
		certified_frontier,
		{"resources": {"deck_low": false}},
		str(certified_frontier[0].get("candidate_id", ""))
	)
	_check(bool(certified_safety.get("valid", false)), "the certified exact Rule candidate must pass without projected tie ambiguity")
	var semantic_frontier := route_search.build_frontier({
		"legal_actions": [{
			"id": "ability:engine",
			"kind": "use_ability",
			"source_card": {"uid": "TEST_ENGINE", "name": "Stable Engine"},
		}],
	}, {"ability:engine": 10.0}, {
		"cards": [{"uid": "TEST_ENGINE", "roles": ["draw_engine", "search_engine"]}],
	}, {"resources": {"prizes_remaining": 6}}, 8)
	var semantic_roles: Array = semantic_frontier[0].get("action_semantic_roles", []) \
		if semantic_frontier[0].get("action_semantic_roles", []) is Array else []
	_check(
		"draw_engine" in semantic_roles and "search_engine" in semantic_roles,
		"exact candidates must expose typed source-card affordances instead of asking the model to infer an effect id"
	)
	_check(
		str(semantic_frontier[0].get("action_ref", {}).get("source_card", {}).get("name", "")) == "Stable Engine",
		"exact candidate refs should retain the stable English card name when available"
	)
	var mover_frontier := route_search.build_frontier({
		"legal_actions": [{
			"id": "trainer:energy_switch",
			"kind": "play_trainer",
			"card": {"uid": "CSVH1aC_008", "name": "Energy Switch", "type": "Item"},
		}],
	}, {"trainer:energy_switch": 10.0}, {
		"cards": [{
			"uid": "CSVH1aC_008",
			"roles": ["item", "energy_mover", "pivot"],
		}],
	}, {"resources": {"prizes_remaining": 6}}, 8)
	_check(
		str(mover_frontier[0].get("route_id", "")) == "route:accelerate",
		"the exact energy_mover role must outrank the broad lexical pivot role for Energy Switch"
	)


func _test_execution_cursor_and_typed_route() -> void:
	var cursor := ExecutionCursorScript.new()
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:search",
		"route_id": "route:noctowl_search",
		"safe_prefix_action_id": "action:search",
	}, {
		"candidate_id": "candidate:attach",
		"route_id": "route:energy_commit",
		"safe_prefix_action_id": "action:attach",
	}]
	cursor.install({
		"mode": "propose_typed_route",
		"route_id": "route:noctowl_search",
		"first_candidate_id": "candidate:search",
		"macro_actions": ["route:noctowl_search", "route:energy_commit", "route:attack_ko"],
	}, {"policy_id": "p1", "revision_id": "r1"}, 4, "model_synthesized_route")
	var initial := cursor.resolve(frontier, 4)
	_check(str(initial.get("candidate_id", "")) == "candidate:search", "typed route must bind its exact first candidate")
	cursor.on_action_result("action:search", true)
	var continuation := cursor.resolve(frontier, 5)
	_check(str(continuation.get("candidate_id", "")) == "candidate:attach", "cursor must continue the next macro step after a new observation")
	_check(int(cursor.snapshot().get("step_index", -1)) == 1, "cursor must persist route progress across observations")

	var validator := PolicyValidatorScript.new()
	var response := {
		"agenda_patch": {},
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": "route:energy_commit",
					"candidate_id": "candidate:attach",
				},
			}],
			"reservations": [],
			"interaction_policy_refs": {},
			"interaction_policies": [],
			"replan_if": [],
		},
	}
	var valid := validator.validate_response(response, ["route:energy_commit"], 8, ["candidate:attach"], true)
	_check(bool(valid.get("valid", false)), "exact root candidate must pass the v2 policy contract")
	var invalid := validator.validate_response(response, ["route:energy_commit"], 8, ["candidate:other"], true)
	_check(not bool(invalid.get("valid", true)) and str(invalid.get("reason", "")) == "unknown_candidate", "unknown exact candidate must be rejected")
	var mismatched := response.duplicate(true)
	mismatched["policy"]["nodes"][0]["route_ref"]["route_id"] = "route:develop"
	var bound := validator.bind_root_to_frontier(mismatched.get("policy", {}), frontier)
	_check(bool(bound.get("valid", false)), "a legal exact candidate should be bindable even when the model repeats the wrong redundant macro id")
	_check(
		str(bound.get("root_ref", {}).get("route_id", "")) == "route:energy_commit",
		"candidate binding must canonicalize the root route from the engine-owned frontier"
	)


func _test_typed_interaction_policy() -> void:
	var policy := InteractionPolicyScript.new()
	var lightning := _energy("Lightning Energy", "L")
	var grass := _energy("Grass Energy", "G")
	var picked := policy.pick_items(
		[grass, lightning],
		{"id": "energy_search", "min_select": 1, "max_select": 1},
		{},
		{
			"rank_by": ["energy_fit", "stable_id"],
			"energy_symbols": ["L"],
			"min_select": 1,
			"max_select": 1,
		},
		{},
		{},
		"route:energy_commit"
	)
	_check(picked == [lightning], "typed interaction policy must own exact energy selection")
	var optional := policy.pick_items(
		[grass],
		{"id": "optional_search", "min_select": 0, "max_select": 1},
		{},
		{
			"rank_by": ["energy_fit"],
			"energy_symbols": ["L"],
			"allow_explicit_empty": true,
		},
		{},
		{},
		"route:energy_commit"
	)
	_check(optional.is_empty(), "typed policy must preserve an explicitly allowed strategic whiff")


func _test_information_value() -> void:
	var solver := InformationValueScript.new()
	var information := solver.evaluate_action(
		{"kind": "use_ability", "requires_interaction": true},
		{"own": {"hand_count": 3, "deck_count": 24}},
		{"attack": {"ko_available": false}},
		{}
	)
	_check(float(information.get("information_gain", 0.0)) > 0.0, "information action must expose positive information value")
	_check(not bool(information.get("terminal", true)), "information action must remain non-terminal")
	var attack := solver.evaluate_action(
		{"kind": "attack", "projected_knockout": true},
		{"own": {"hand_count": 3, "deck_count": 24}},
		{"attack": {"ko_available": true}},
		{}
	)
	_check(bool(attack.get("terminal", false)), "attack must be classified as a terminal commitment")
	_check(float(attack.get("information_gain", 1.0)) == 0.0, "terminal attack must not pretend to gain route information")
	var wait_budget := VisibleWaitBudgetScript.new()
	var first := wait_budget.may_request(0, [], 0, 12000, 6500)
	_check(bool(first.get("allowed", false)), "the first valuable request of a turn must remain available")
	var blocked := wait_budget.may_request(7200, [6800.0, 7200.0], 1, 12000, 6500)
	_check(
		not bool(blocked.get("allowed", true)) and str(blocked.get("reason", "")) == "visible_wait_budget_exhausted",
		"a second revision must fall back locally when its expected wait exceeds the remaining visible budget"
	)
	var fast := wait_budget.may_request(1800, [700.0, 900.0], 2, 12000, 6500)
	_check(bool(fast.get("allowed", false)), "fast or cached models may still replan repeatedly inside the same budget")


func _test_information_epoch_reopening() -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(ProfileCatalogScript.get_profile_for_deck(800015934))
	strategy.configure_verified_local_only_for_benchmark()
	var information_frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:draw",
		"route_id": "route:information",
		"checkpoint_after": "information_result",
	}]
	var completed_information := {
		"success": true,
		"route_id": "route:information",
		"candidate_id": "candidate:draw",
	}
	var new_choices := {
		"material": false,
		"legal_actions_changed": true,
		"changed_facts": ["resources.hand_size"],
	}
	_check(
		strategy._should_reopen_information_epoch(
			"local_gate", completed_information, new_choices, information_frontier
		),
		"a successful local information action must reopen planning when new choices appear"
	)
	var same_size_search := {
		"material": false,
		"legal_actions_changed": false,
		"changed_facts": [],
	}
	_check(
		strategy._should_reopen_information_epoch(
			"local_gate", completed_information, same_size_search, information_frontier
		),
		"a successful search must reopen planning when card identities change but hand size does not"
	)
	var shadowed_information := completed_information.duplicate(true)
	shadowed_information["owner"] = "local_gate"
	_check(
		strategy._should_reopen_information_epoch(
			"model_shadow_rule_root", shadowed_information, same_size_search, information_frontier
		),
		"an exact Rule-root shadow must checkpoint from its actual local action owner"
	)
	var failed_information := completed_information.duplicate(true)
	failed_information["success"] = false
	_check(
		not strategy._should_reopen_information_epoch(
			"local_gate", failed_information, new_choices, information_frontier
		),
		"a failed information action must not open a phantom planning epoch"
	)
	var ordinary_action := completed_information.duplicate(true)
	ordinary_action["route_id"] = "route:energy_commit"
	ordinary_action["candidate_id"] = "candidate:attach"
	_check(
		not strategy._should_reopen_information_epoch(
			"local_gate", ordinary_action, new_choices, [],
		),
		"ordinary actions must not add replans merely because their legal action disappears"
	)
	var completed_gust := {
		"success": true,
		"route_id": "route:gust",
		"candidate_id": "candidate:gust",
	}
	_check(
		strategy._should_reopen_information_epoch(
			"local_gate", completed_gust, new_choices, [],
		),
		"a local gust must expose its material public Active change before unrelated continuation"
	)
	var module_frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:profiled_stage",
		"route_id": "route:develop",
		"checkpoint_after": "action_resolved",
		"module_annotations": {
			"gardevoir_embrace": {
				"verified_advantage": true,
				"verified_advantage_kind": "profiled_visible_engine_hold",
			},
		},
	}]
	var completed_profiled_stage := {
		"success": true,
		"route_id": "route:develop",
		"candidate_id": "candidate:profiled_stage",
	}
	_check(
		strategy._should_reopen_information_epoch(
			"local_gate", completed_profiled_stage, new_choices, module_frontier,
		),
		"a verified multi-stage public route must checkpoint after its material board action"
	)
	_check(
		not strategy._should_reopen_information_epoch(
			"model_synthesized_route",
			completed_information.merged({"owner": "model_synthesized_route"}, true),
			new_choices,
			information_frontier
		),
		"model graphs must retain ownership of their typed information checkpoint"
	)
	strategy.set("_pending_request_id", "request:test")
	strategy.set("_pending_request_started_msec", 1000)
	strategy.set("_pending_request_visible_budget_ms", 11750)
	_check(
		not strategy._request_deadline_due(12749),
		"an in-flight request must remain eligible immediately before its visible-wait deadline"
	)
	_check(
		strategy._request_deadline_due(12750),
		"the visible-wait budget must become a hard in-flight deadline"
	)


func _test_typed_profile_policy() -> void:
	var policy := ProfilePolicyScript.new().sanitize({
		"strategic_priorities": [{
			"priority": 1,
			"goal": "minimum_resource_ko",
			"when_all": [{"fact": "attack.ko_available", "op": "==", "value": true}],
			"prefer_routes": ["attack_ko"],
		}, {
			"priority": 2,
			"objective": "free form must be rejected",
			"condition": "hidden hand",
		}],
		"route_preferences": {"route_biases": {"attack_ko": 40, "invented": 9999}},
		"safety": {"block_search_when_deck_low": true, "free_text": "reject"},
	}, StrategyScript.REGISTERED_ROUTE_IDS)
	_check((policy.get("strategic_priorities", []) as Array).size() == 1, "free-form strategic priorities must be rejected")
	_check(str(policy.get("strategic_priorities", [])[0].get("prefer_routes", [])[0]) == "route:attack_ko", "typed route ids should be normalized")
	_check(not (policy.get("route_preferences", {}).get("route_biases", {}) as Dictionary).has("route:invented"), "unregistered route bias must be rejected")
	_check(not (policy.get("safety", {}) as Dictionary).has("free_text"), "free-form safety fields must be rejected")


func _test_isolation_scan() -> void:
	var denylist := [
		"DeckStrategyLLMRuntimeBase",
		"LLMTurnPlanPromptBuilder",
		"LLMRouteCandidateBuilder",
		"LLMRouteCompiler",
		"LLMRouteActionRegistry",
		"LLMInteractionIntentBridge",
		"DeckStrategyRagingBoltLLM",
		"AgentRuntime",
		"AgentService",
		"AgentAdapter",
	]
	var paths: Array[String] = []
	_collect_files("res://scripts/ai/v18_cpg", paths)
	for path: String in paths:
		if not path.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for denied: String in denylist:
			_check(not text.contains(denied), "forbidden import/reference %s in %s" % [denied, path])
		for random_call: String in ["randi(", "randf(", "randomize("]:
			_check(not text.contains(random_call), "V18CPG must not consume gameplay RNG via %s in %s" % [random_call, path])


func _test_transport_rng_isolation() -> void:
	var transport := RngIsolatedTransportScript.new()
	transport.set_timeout_seconds(1.0)
	seed(24681357)
	var expected_first := randi()
	var expected_second := randi()
	seed(24681357)
	var actual_first := randi()
	var paths: Dictionary = transport.call(
		"_write_python_fallback_request",
		"https://example.invalid/api/v1",
		"fixture-secret",
		{"model": "fixture"}
	)
	var actual_second := randi()
	_check(not paths.is_empty(), "V18 RNG-isolated fallback fixture must create request paths")
	_check(
		actual_first == expected_first and actual_second == expected_second,
		"creating a V18 model fallback request must not advance the gameplay RNG"
	)
	_check(
		str(paths.get("input_path", "")).replace("\\", "/").contains("/v18cpg/zenmux/"),
		"V18 model fallback files must stay in the isolated V18 user directory"
	)
	for key: String in ["input_path", "output_path"]:
		var path := str(paths.get(key, ""))
		if path != "":
			DirAccess.remove_absolute(path)


func _collect_files(directory: String, output: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		output.append(directory.path_join(file_name))
	for child: String in DirAccess.get_directories_at(directory):
		_collect_files(directory.path_join(child), output)


func _player(index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = index
	return player


func _card(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	data.set_code = "TEST"
	data.card_index = name
	return CardInstance.create(data, owner)


func _trainer(name: String, description: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	data.description = description
	data.set_code = "TEST"
	data.card_index = name.replace(" ", "_")
	return CardInstance.create(data, 0)


func _supporter(name: String, description: String) -> CardInstance:
	var card := _trainer(name, description)
	card.card_data.card_type = "Supporter"
	return card


func _energy(name: String, symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	data.set_code = "TEST"
	data.card_index = name.replace(" ", "_")
	return CardInstance.create(data, 0)


func _pokemon(name: String, set_code: String, card_index: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Stage 1"
	data.hp = 100
	data.set_code = set_code
	data.card_index = card_index
	return CardInstance.create(data, 0)


func _expect_invalid_response(
	validator: RefCounted,
	response: Dictionary,
	allowed_routes: Array[String],
	allowed_candidates: Array[String],
	expected_reason: String
) -> void:
	var result: Dictionary = validator.call(
		"validate_response",
		response,
		allowed_routes,
		8,
		allowed_candidates,
		true
	)
	_check(
		not bool(result.get("valid", true)) and str(result.get("reason", "")) == expected_reason,
		"strict validator must reject %s (got %s)" % [expected_reason, str(result.get("reason", "valid"))]
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
