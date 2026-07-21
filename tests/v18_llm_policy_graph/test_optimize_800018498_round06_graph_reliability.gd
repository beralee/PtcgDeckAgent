extends SceneTree

const DecisionClientScript = preload("res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd")
const PolicyGraphScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyGraph.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 6, "round06 profile must be active")
	_check(int(profile.get("max_policy_nodes", 0)) == 8, "round06 must not expand the policy-node budget")
	_check(int(profile.get("initial_response_token_budget", 0)) == 400, "round06 must preserve the initial token budget")
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "round06 must preserve the delta token budget")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "round06 must preserve the visible-wait ceiling")
	_test_compact_grammar()
	_test_information_checkpoint_graph_reuse(profile)
	if _failures.is_empty():
		print("V18CPG 800018498 round06 graph reliability: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800018498 round06 graph reliability: FAIL (%d)" % _failures.size())
	quit(1)


func _test_compact_grammar() -> void:
	var client := DecisionClientScript.new()
	var payload := client._build_payload({
		"limits": {"max_policy_nodes": 8},
		"lifecycle": {"request_id": "request:round06"},
		"profile": {"deck_id": 800018498},
		"observation": {},
		"belief": {},
		"match_agenda": {},
		"facts": {},
		"resource_ledger": {},
		"prize_graph": {},
		"threat_response": {},
		"capability_context": {},
		"frontier": [],
		"allowed_follow_route_ids": [],
	}, 400, false)
	var messages: Array = payload.get("messages", []) if payload.get("messages", []) is Array else []
	var system := str((messages[0] as Dictionary).get("content", "")) if not messages.is_empty() else ""
	_check(system.contains("propose_typed_route is root-only"), "prompt must forbid typed macros behind checkpoints")
	_check(system.contains("exactly 2, 3, or 4 items"), "prompt must state the compact typed-macro bound unambiguously")
	_check(system.contains("point only to a node listed later"), "prompt must express the acyclic edge rule constructively")
	_check(system.contains("may appear only as the final macro action"), "prompt must stop typed cursors at information boundaries")


func _test_information_checkpoint_graph_reuse(profile: Dictionary) -> void:
	var information_frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:tutor",
		"route_id": "route:tutor",
		"checkpoint_after": "information_result",
	}]
	var completed_information := {
		"success": true,
		"route_id": "route:tutor",
		"candidate_id": "candidate:tutor",
	}
	var material_result := {
		"material": true,
		"legal_actions_changed": true,
		"changed_facts": ["attack.ready"],
	}
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	strategy.configure_verified_local_only_for_benchmark()
	_check(
		not strategy._should_reopen_information_epoch(
			"model_synthesized_route", completed_information, material_result, information_frontier
		),
		"an accepted model graph must retain its declared information checkpoint instead of forcing a second call"
	)
	_check(
		strategy._should_reopen_information_epoch(
			"local_gate", completed_information, material_result, information_frontier
		),
		"a local graph without declared model branches must still reopen the new information epoch"
	)
	var graph := PolicyGraphScript.new()
	var policy := {
		"root_node_id": "node:root",
		"nodes": [{
			"node_id": "node:root",
			"kind": "route",
			"route_ref": {
				"mode": "select_candidate",
				"route_id": "route:tutor",
				"candidate_id": "candidate:tutor",
			},
			"next_node_id": "node:after_tutor",
		}, {
			"node_id": "node:after_tutor",
			"kind": "checkpoint",
			"branches": [{
				"when_all": [{"fact": "attack.ready", "op": "==", "value": true}],
				"next_node_id": "node:attack",
			}],
			"otherwise": "replan",
		}, {
			"node_id": "node:attack",
			"kind": "route",
			"route_ref": {"mode": "follow_route", "route_id": "route:attack_pressure"},
		}],
	}
	graph.install(policy, "model_synthesized_route")
	var transition := graph.advance_after_observation(
		{"attack": {"ready": true}},
		["route:attack_pressure"],
		[]
	)
	_check(str(transition.get("status", "")) == "route", "the accepted graph must absorb the information result locally")
	_check(str(transition.get("route_id", "")) == "route:attack_pressure", "the information checkpoint must select its declared legal continuation")
	_check(graph.origin() == "model_synthesized_route", "local checkpoint evaluation must preserve model ownership")
	graph.install(policy, "model_synthesized_route")
	var unavailable := graph.advance_after_observation({"attack": {"ready": true}}, [], [])
	_check(str(unavailable.get("status", "")) == "replan", "an unavailable declared continuation must fail closed to one compact replan")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
