class_name TestCompetitivePolicyV2
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const PackageLoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/competitive_policy_v2_conformance_vectors.json"


func _vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(
		file.get_buffer(file.get_length())
	)
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


func _vector_case(case_id: String) -> Dictionary:
	for value: Variant in _vectors().get("cases", []):
		if value is Dictionary and value.get("case_id") == case_id:
			return value
	return {}


func test_route_candidate_adjudication_precedes_local_scores_and_yields_to_base() -> String:
	var spec := _vector_case("whole-turn-route-candidate-overrides-local-greedy-score")
	if spec.is_empty():
		return "missing whole-turn route candidate vector"
	var compiled := RuntimeScript.compile_local_uid(
		spec.get("policy", {}).duplicate(true), spec.get("allowed_card_uids", []).duplicate()
	)
	if not bool(compiled.get("accepted", false)):
		return "route candidate compile rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var decision := RuntimeScript.decide(compiled.get("policy"), frame)
	if decision.get("selected_indexes") != [1]:
		return "whole-turn route did not outrank local greedy score: %s" % decision
	var contract: Dictionary = decision.get("audit", {}).get("turn_contract", {})
	if (
		contract.get("route_candidate_adjudication", {}).get("selected_route_id")
		!= "continuity-first"
		or not bool(contract.get("route_authority_applied", false))
	):
		return "route candidate audit is incomplete: %s" % contract
	var reordered := frame.duplicate(true)
	reordered["source"]["window_id"] = "F".repeat(64)
	reordered["options"] = [frame.get("options", [])[1].duplicate(true), frame.get("options", [])[0].duplicate(true)]
	for index: int in reordered.get("options", []).size():
		reordered["options"][index]["index"] = index
	if RuntimeScript.decide(compiled.get("policy"), reordered).get("selected_indexes") != [0]:
		return "route candidate did not survive semantic option reorder"
	var hard_tier := RuntimeScript.decide(
		compiled.get("policy"), frame, [], [],
		[{"index": 0, "tier": [0]}, {"index": 1, "tier": [1]}], []
	)
	if (
		hard_tier.get("selected_indexes") != [0]
		or bool(hard_tier.get("audit", {}).get("turn_contract", {}).get("route_authority_applied", true))
	):
		return "route candidate overrode Base hard tier: %s" % hard_tier
	var terminal := RuntimeScript.decide(compiled.get("policy"), frame, [], [0])
	if terminal.get("selected_indexes") != [0] or terminal.get("audit", {}).get("owner_layer") != "terminal":
		return "route candidate overrode terminal authority: %s" % terminal
	var spent_spec := _vector_case("route-resource-budget-public-fact-flip")
	var spent := RuntimeScript.decide(
		compiled.get("policy"), spent_spec.get("frame", {}).duplicate(true)
	)
	if spent.get("selected_indexes") != [0]:
		return "spent manual attachment did not reject continuity route: %s" % spent
	var considered: Array = spent.get("audit", {}).get("turn_contract", {}).get(
		"route_candidate_adjudication", {}
	).get("considered_routes", [])
	if considered.is_empty() or considered[0].get("rejection_reason") != "manual_attachment_unavailable":
		return "resource rejection reason missing: %s" % considered
	return ""


func test_route_candidate_compiled_path_stays_below_50ms_p95() -> String:
	var spec := _vector_case("whole-turn-route-candidate-overrides-local-greedy-score")
	var compiled := RuntimeScript.compile_local_uid(
		spec.get("policy", {}).duplicate(true), spec.get("allowed_card_uids", []).duplicate()
	)
	if not bool(compiled.get("accepted", false)):
		return "route performance policy rejected: %s" % compiled.get("error_code")
	var policy_hash := str(compiled.get("policy", {}).get("policy_hash", ""))
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	for _warmup: int in 20:
		var warmup: Dictionary = RuntimeScript.decide_compiled(policy_hash, frame)
		if not bool(warmup.get("accepted", false)):
			return "route performance warmup rejected: %s" % warmup
	var samples_usec: Array[int] = []
	for _sample: int in 250:
		var started := Time.get_ticks_usec()
		var decision: Dictionary = RuntimeScript.decide_compiled(policy_hash, frame)
		samples_usec.append(Time.get_ticks_usec() - started)
		if decision.get("selected_indexes") != [1]:
			return "route performance sample changed semantics: %s" % decision
	samples_usec.sort()
	var p95_usec: int = samples_usec[int(floor(float(samples_usec.size() - 1) * 0.95))]
	print("ROUTE_CANDIDATE_COMPILED_PERF samples=250 p95_usec=%d" % p95_usec)
	if p95_usec >= 50000:
		return "route candidate compiled P95 exceeded 50ms: %dus" % p95_usec
	return ""


func test_pinned_python_vectors_match_gdscript_runtime() -> String:
	for value: Variant in _vectors().get("cases", []):
		if not value is Dictionary:
			return "invalid vector row"
		var spec: Dictionary = value
		var compiled: Dictionary = RuntimeScript.compile_local_uid(
			spec.get("policy", {}).duplicate(true),
			spec.get("allowed_card_uids", []).duplicate()
		)
		var actual: Dictionary
		if spec.get("operation") == "compile":
			actual = {
				"accepted": bool(compiled.get("accepted", false)),
				"error_code": str(compiled.get("error_code", "")),
				"selected_indexes": [],
			}
		else:
			if not bool(compiled.get("accepted", false)):
				return "%s compile rejected: %s" % [spec.get("case_id"), compiled.get("error_code")]
			var decision: Dictionary = RuntimeScript.decide(
				compiled.get("policy"), spec.get("frame", {}).duplicate(true)
			)
			actual = {
				"accepted": bool(decision.get("accepted", false)),
				"error_code": str(decision.get("error_code", "")),
				"selected_indexes": decision.get("selected_indexes", []).duplicate(),
			}
			if spec.get("expected", {}).has("audit_hash"):
				actual["audit_hash"] = decision.get("audit", {}).get("audit_hash")
		if actual != spec.get("expected"):
			return "%s mismatch: %s != %s" % [spec.get("case_id"), actual, spec.get("expected")]
	return ""


func test_exact_count_reorder_assignment_and_prize_clock_stay_current_window_only() -> String:
	var vectors := _vectors()
	var exact: Dictionary = vectors.get("cases", [])[0]
	var compiled := RuntimeScript.compile_local_uid(
		exact.get("policy", {}).duplicate(true), exact.get("allowed_card_uids", []).duplicate()
	)
	if not bool(compiled.get("accepted", false)):
		return str(compiled.get("error_code"))
	var frame: Dictionary = exact.get("frame", {}).duplicate(true)
	var moved: Dictionary = frame.options[0]
	frame.options[0] = frame.options[4]
	frame.options[4] = moved
	for index: int in frame.options.size():
		frame.options[index].index = index
	var reordered: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if reordered.get("selected_indexes") != [0, 1, 2]:
		return "reordered semantic subset mismatch: %s" % reordered
	var terminal: Dictionary = RuntimeScript.decide(
		compiled.get("policy"), exact.get("frame", {}).duplicate(true), [], [4], [], [4]
	)
	if terminal.get("selected_indexes") != [4] or terminal.get("audit", {}).get("owner_layer") != "terminal":
		return "terminal authority was overridden"
	return ""


func test_public_turn_route_and_typed_recipe_replan_from_each_window() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	var allowed: Array = spec.get("allowed_card_uids", []).duplicate()
	var source_uid := "CSV8C_183"
	if source_uid not in allowed:
		allowed.append(source_uid)
	var goal_id: String = str(document.get("goals", [])[0].get("goal_id", ""))
	var energy_uid: String = str(spec.get("frame", {}).get("options", [])[0].get("card_uid", ""))
	document["adapter_version"] = 11
	document["turn_routes"] = [{
		"route_id": "typed-energy-route",
		"priority": 900,
		"goal_id": goal_id,
		"owner_goal_id": goal_id,
		"bridge_goal_id": goal_id,
		"pivot_goal_id": goal_id,
		"when": [],
		"steps": [{
			"step_id": "pay-public-debt",
			"prompt_kinds": ["assignment_source"],
			"goal_id": goal_id,
			"when": [
				{"fact": "goal.energy_debt", "op": "gt", "value": 0, "card_uid": null},
				{"fact": "turn.manual_attachment_available", "op": "eq", "value": true, "card_uid": null},
			],
			"option_when": [
				{"fact": "option.card_uid", "op": "eq", "value": energy_uid, "card_uid": null},
			],
			"score_bonus": 100000,
			"selection_count": 3,
			"terminal": false,
			"checkpoint": false,
		}],
	}]
	document["interaction_recipes"] = [{
		"recipe_id": "typed-source-recipe",
		"priority": 1000,
		"route_id": "typed-energy-route",
		"goal_id": goal_id,
		"source_uids": [source_uid],
		"when": [
			{"fact": "goal.energy_debt", "op": "gt", "value": 0, "card_uid": null},
		],
		"steps": [{
			"step_id": "pick-exact-three",
			"prompt_kinds": ["assignment_source"],
			"goal_id": goal_id,
			"when": [],
			"option_when": [
				{"fact": "option.card_uid", "op": "eq", "value": energy_uid, "card_uid": null},
			],
			"score_bonus": 120000,
			"selection_count": 3,
			"terminal": false,
			"checkpoint": true,
		}],
	}]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(document, allowed)
	if not bool(compiled.get("accepted", false)):
		return "turn route policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	frame["public_state"]["self"]["turn"] = {
		"supporter_available": true,
		"manual_attachment_available": true,
		"retreat_available": true,
	}
	for option: Dictionary in frame.get("options", []):
		option["source_uid"] = source_uid
	var exact: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if exact.get("selected_indexes") != [0, 1, 2]:
		return "turn route exact subset mismatch: %s" % exact
	var contract: Dictionary = exact.get("audit", {}).get("turn_contract", {})
	if (
		contract.get("route_id") != "typed-energy-route"
		or contract.get("first_executable_step_id") != "pay-public-debt"
		or contract.get("interaction_recipe_id") != "typed-source-recipe"
		or contract.get("interaction_step_id") != "pick-exact-three"
		or not bool(contract.get("checkpoint", false))
		or bool(contract.get("stale_index_authority", true))
	):
		return "turn contract audit mismatch: %s" % contract
	var wrong_source: Dictionary = frame.duplicate(true)
	wrong_source["source"]["window_id"] = "C".repeat(64)
	for option: Dictionary in wrong_source.get("options", []):
		option["source_uid"] = energy_uid
	var ignored: Dictionary = RuntimeScript.decide(compiled.get("policy"), wrong_source)
	if ignored.get("audit", {}).get("turn_contract", {}).get("interaction_recipe_id") != null:
		return "wrong source activated typed recipe: %s" % ignored
	var settled: Dictionary = frame.duplicate(true)
	settled["source"]["window_id"] = "D".repeat(64)
	settled["public_state"]["self"]["active"][0]["attached_energy_count"] = 2
	settled["public_state"]["self"]["active"][0]["attached_energy_uids"] = [energy_uid, energy_uid]
	settled["public_state"]["self"]["bench"][0]["attached_energy_count"] = 2
	settled["public_state"]["self"]["bench"][0]["attached_energy_uids"] = [energy_uid, energy_uid]
	var replanned: Dictionary = RuntimeScript.decide(compiled.get("policy"), settled)
	if replanned.get("audit", {}).get("turn_contract", {}).get("route_id") != null:
		return "settled debt retained stale route authority: %s" % replanned
	return ""


func test_soft_turn_bonus_rebinds_and_yields_to_terminal_route() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	var allowed: Array = spec.get("allowed_card_uids", []).duplicate()
	var goal_id: String = str(document.get("goals", [])[0].get("goal_id", ""))
	document["adapter_version"] = 17
	document["rules"].append_array([
		{
			"rule_id": "baseline-attach",
			"goal_id": goal_id,
			"goal_stage": "fund",
			"channel": "future",
			"horizon": 1,
			"confidence_milli": 1000,
			"base_score": 2000,
			"when": [
				{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": null},
			],
			"score_terms": [],
		},
		{
			"rule_id": "baseline-play",
			"goal_id": goal_id,
			"goal_stage": "fund",
			"channel": "future",
			"horizon": 1,
			"confidence_milli": 1000,
			"base_score": 1000,
			"when": [
				{"fact": "option.kind", "op": "eq", "value": "play_card", "card_uid": null},
			],
			"score_terms": [],
		},
	])
	document["turn_bonus_contracts"] = [{
		"contract_id": "soft-continuity",
		"priority": 900,
		"goal_id": goal_id,
		"when": [
			{"fact": "self.prizes_remaining", "op": "gte", "value": 3, "card_uid": null},
		],
		"bonuses": [
			{
				"bonus_id": "build-owner",
				"prompt_kinds": ["main"],
				"goal_id": goal_id,
				"when": [],
				"option_when": [
					{"fact": "option.kind", "op": "eq", "value": "play_card", "card_uid": null},
				],
				"score_bonus": 1500,
			},
			{
				"bonus_id": "defer-bridge",
				"prompt_kinds": ["main"],
				"goal_id": goal_id,
				"when": [],
				"option_when": [
					{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": null},
				],
				"score_bonus": -1000,
			},
		],
	}]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(document, allowed)
	if not bool(compiled.get("accepted", false)):
		return "soft contract rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	frame["prompt_kind"] = "main"
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	frame["options"] = frame.get("options", []).slice(0, 2)
	frame["options"][0]["index"] = 0
	frame["options"][0]["kind"] = "attach_energy"
	frame["options"][1]["index"] = 1
	frame["options"][1]["kind"] = "play_card"
	var softened: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if softened.get("selected_indexes") != [1]:
		return "soft bonus did not tip same-tier choice: %s" % softened
	var contract: Dictionary = softened.get("audit", {}).get("turn_contract", {})
	if (
		contract.get("turn_bonus_contract_id") != "soft-continuity"
		or contract.get("turn_bonus_ids") != ["build-owner", "defer-bridge"]
		or bool(contract.get("terminal", true))
		or contract.get("selection_count") != null
	):
		return "soft contract audit mismatch: %s" % contract
	var reordered: Dictionary = frame.duplicate(true)
	reordered["source"]["window_id"] = "C".repeat(64)
	reordered["options"].reverse()
	for index: int in reordered.get("options", []).size():
		reordered["options"][index]["index"] = index
	var rebound: Dictionary = RuntimeScript.decide(compiled.get("policy"), reordered)
	if rebound.get("selected_indexes") != [0]:
		return "soft semantic intent retained stale index: %s" % rebound

	var terminal_document: Dictionary = document.duplicate(true)
	terminal_document["turn_routes"] = [{
		"route_id": "terminal-owner",
		"priority": 1000,
		"goal_id": goal_id,
		"owner_goal_id": goal_id,
		"bridge_goal_id": goal_id,
		"pivot_goal_id": goal_id,
		"when": [],
		"steps": [{
			"step_id": "finish-now",
			"prompt_kinds": ["main"],
			"goal_id": goal_id,
			"when": [],
			"option_when": [
				{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": null},
			],
			"score_bonus": 100000,
			"selection_count": 1,
			"terminal": true,
			"checkpoint": false,
		}],
	}]
	var terminal_compiled: Dictionary = RuntimeScript.compile_local_uid(
		terminal_document, allowed
	)
	if not bool(terminal_compiled.get("accepted", false)):
		return "terminal contract rejected: %s" % terminal_compiled.get("error_code")
	var terminal: Dictionary = RuntimeScript.decide(terminal_compiled.get("policy"), frame)
	var terminal_contract: Dictionary = terminal.get("audit", {}).get("turn_contract", {})
	if (
		terminal.get("selected_indexes") != [0]
		or not bool(terminal_contract.get("terminal", false))
		or terminal_contract.has("turn_bonus_contract_id")
	):
		return "terminal route did not suppress soft bonus: %s" % terminal
	for scorecard_value: Variant in terminal.get("audit", {}).get("scorecards", []):
		for matched_value: Variant in scorecard_value.get("matched_rules", []):
			if str(matched_value.get("rule_id", "")).begins_with("@turn_bonus."):
				return "terminal route retained soft overlay: %s" % terminal
	return ""


func test_goal_relative_continuity_facts_bind_public_debt_and_position() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	var allowed: Array = spec.get("allowed_card_uids", []).duplicate()
	var goal_id: String = str(document.get("goals", [])[0].get("goal_id", ""))
	var owner_uid: String = str(allowed[0])
	var backup_uid: String = str(allowed[1])
	var energy_uid: String = str(allowed[2])
	document["adapter_version"] = 19
	for requirement: Dictionary in document.get("goals", [])[0].get("requirements", []):
		requirement["energy_requirements"] = [{"energy_uid": energy_uid, "count": 2}]
		if requirement.get("card_uid") == owner_uid:
			requirement["ready_target_count"] = 2
		requirement["attack_index"] = 1
		requirement["ability_index"] = null
	document["rules"] = [
		{
			"rule_id": "attack-baseline",
			"goal_id": goal_id,
			"goal_stage": "execute",
			"channel": "tactical",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 1000,
			"when": [{"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": null}],
			"score_terms": [],
		},
		{
			"rule_id": "attach-baseline",
			"goal_id": goal_id,
			"goal_stage": "fund",
			"channel": "future",
			"horizon": 1,
			"confidence_milli": 1000,
			"base_score": 900,
			"when": [{"fact": "option.kind", "op": "eq", "value": "attach_energy", "card_uid": null}],
			"score_terms": [],
		},
	]
	document["count_rules"] = []
	document["turn_bonus_contracts"] = [{
		"contract_id": "public-continuity",
		"priority": 900,
		"goal_id": goal_id,
		"when": [
			{"fact": "goal.active_ready_count_uid", "op": "gte", "value": 1, "card_uid": owner_uid},
			{"fact": "goal.board_energy_count", "op": "lt", "value": 5, "card_uid": null},
			{"fact": "goal.discard_energy_count", "op": "gte", "value": 2, "card_uid": null},
			{"fact": "self.bench_open", "op": "eq", "value": true, "card_uid": null},
		],
		"bonuses": [{
			"bonus_id": "fund-backup",
			"prompt_kinds": ["main"],
			"goal_id": goal_id,
			"when": [
				{"fact": "goal.near_ready_count_uid", "op": "gte", "value": 2, "card_uid": owner_uid},
				{"fact": "goal.ready_count_uid", "op": "eq", "value": 0, "card_uid": backup_uid},
			],
			"option_when": [
				{"fact": "option.target_is_active", "op": "eq", "value": false, "card_uid": null},
				{"fact": "goal.option.funds_target", "op": "eq", "value": true, "card_uid": null},
			],
			"score_bonus": 500,
		}],
	}]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(document, allowed)
	if not bool(compiled.get("accepted", false)):
		return "continuity facts policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	frame["prompt_kind"] = "main"
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	frame["public_state"]["self"]["active"][0]["attached_energy_count"] = 2
	frame["public_state"]["self"]["active"][0]["attached_energy_uids"] = [energy_uid, energy_uid]
	frame["public_state"]["self"]["active"][0]["attack_ready"] = true
	frame["public_state"]["self"]["active"][0]["energy_debt"] = 0
	frame["public_state"]["self"]["bench"][0]["local_card_uid"] = owner_uid
	frame["public_state"]["self"]["bench"][0]["attached_energy_count"] = 1
	frame["public_state"]["self"]["bench"][0]["attached_energy_uids"] = [energy_uid]
	frame["public_state"]["self"]["bench"][0]["energy_debt"] = 1
	for serial in [23, 24, 25, 26]:
		var extra_bench: Dictionary = frame["public_state"]["self"]["bench"][0].duplicate(true)
		extra_bench["serial"] = serial
		extra_bench["local_card_uid"] = backup_uid
		extra_bench["attached_energy_count"] = 0
		extra_bench["attached_energy_uids"] = []
		extra_bench["energy_debt"] = 2
		frame["public_state"]["self"]["bench"].append(extra_bench)
	frame["public_state"]["self"]["bench_capacity"] = 8
	frame["public_state"]["self"]["discard"] = [
		{"serial": 31, "local_card_uid": energy_uid},
		{"serial": 32, "local_card_uid": energy_uid},
	]
	var attack: Dictionary = frame.get("options", [])[0].duplicate(true)
	attack.merge({
		"index": 0, "kind": "attack", "card_uid": null,
		"card_serial": null, "option_type_raw": 13,
		"source_uid": owner_uid, "source_serial": 10, "attack_index": 1,
		"projected_damage": 140,
	}, true)
	var attach: Dictionary = frame.get("options", [])[1].duplicate(true)
	attach.merge({
		"index": 1, "kind": "attach_energy", "card_uid": energy_uid,
		"option_type_raw": 8,
		"target_uid": owner_uid, "target_serial": 11,
		"target_attached_energy_count": 1,
		"target_attached_energy_uids": [energy_uid],
		"target_minimum_attack_energy_count": 2,
		"target_attack_ready": false, "target_energy_debt": 1,
	}, true)
	frame["options"] = [attack, attach]
	var decision: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if decision.get("selected_indexes") != [1]:
		return "public continuity facts did not fund backup: %s" % decision
	frame["source"]["window_id"] = "D".repeat(64)
	frame["options"][1]["target_serial"] = 10
	var active_target: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if active_target.get("selected_indexes") != [0]:
		return "active target received backup-only bonus: %s" % active_target
	return ""


func test_private_unknown_fact_and_mutated_policy_fail_closed() -> String:
	var private_case: Dictionary = _vectors().get("cases", [])[-1]
	var rejected := RuntimeScript.compile_local_uid(
		private_case.get("policy", {}).duplicate(true),
		private_case.get("allowed_card_uids", []).duplicate()
	)
	if bool(rejected.get("accepted", false)) or rejected.get("error_code") != "invalid_public_fact":
		return "private fact did not fail closed: %s" % rejected
	var exact: Dictionary = _vectors().get("cases", [])[0]
	var compiled := RuntimeScript.compile_local_uid(
		exact.get("policy", {}).duplicate(true), exact.get("allowed_card_uids", []).duplicate()
	)
	compiled.get("policy")["document"]["rules"][0]["base_score"] = 999999
	var decision := RuntimeScript.decide(
		compiled.get("policy"), exact.get("frame", {}).duplicate(true)
	)
	if bool(decision.get("accepted", false)) or decision.get("error_code") != "invalid_policy":
		return "mutated policy retained authority"
	return ""


func test_compiled_execution_path_is_sealed_and_semantically_identical() -> String:
	var runtime: Variant = load("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
	if runtime == null:
		return "competitive v2 runtime did not load"
	var has_compiled_path := false
	for method_value: Variant in runtime.get_script_method_list():
		if method_value is Dictionary and method_value.get("name") == "decide_compiled":
			has_compiled_path = true
			break
	if not has_compiled_path:
		return "competitive v2 runtime has no sealed compiled execution path"
	var exact: Dictionary = _vectors().get("cases", [])[0]
	var compiled := RuntimeScript.compile_local_uid(
		exact.get("policy", {}).duplicate(true), exact.get("allowed_card_uids", []).duplicate()
	)
	if not bool(compiled.get("accepted", false)):
		return str(compiled.get("error_code"))
	var policy: Dictionary = compiled.get("policy")
	var policy_hash := str(policy.get("policy_hash", ""))
	var frame: Dictionary = exact.get("frame", {}).duplicate(true)
	var strict: Dictionary = RuntimeScript.decide(policy, frame)
	var sealed: Dictionary = runtime.callv("decide_compiled", [policy_hash, frame])
	if sealed != strict:
		return "sealed compiled decision differs from strict decision: %s != %s" % [sealed, strict]
	policy["document"]["rules"][0]["base_score"] = 999999
	var rejected: Dictionary = RuntimeScript.decide(policy, frame)
	if bool(rejected.get("accepted", false)) or rejected.get("error_code") != "invalid_policy":
		return "strict path accepted a mutated public policy"
	var sealed_after_public_mutation: Dictionary = runtime.callv(
		"decide_compiled", [policy_hash, frame]
	)
	if sealed_after_public_mutation != sealed:
		return "public policy mutation aliased the sealed compiled plan"
	var unknown: Dictionary = runtime.callv("decide_compiled", ["F".repeat(64), frame])
	if bool(unknown.get("accepted", false)) or unknown.get("error_code") != "invalid_compiled_policy":
		return "unknown compiled policy hash did not fail closed: %s" % unknown
	return ""


func test_neutral_unmatched_action_does_not_escape_base_fallback_because_another_option_is_vetoed() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	var allowed: Array = spec.get("allowed_card_uids", []).duplicate()
	document.get("rules", []).append({
		"rule_id": "base-fixture.veto-other-option",
		"goal_id": document.get("goals", [])[0].get("goal_id"),
		"goal_stage": "maintain",
		"channel": "future",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": -1000,
		"when": [{
			"fact": "option.card_uid", "op": "eq", "value": allowed[0], "card_uid": null,
		}],
		"score_terms": [],
	})
	var compiled: Dictionary = RuntimeScript.compile_local_uid(document, allowed)
	if not bool(compiled.get("accepted", false)):
		return str(compiled.get("error_code"))
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var neutral: Dictionary = frame.get("options", [])[0].duplicate(true)
	neutral.merge({
		"index": 0, "kind": "play_trainer", "card_uid": allowed[1],
		"option_type_raw": 7,
		"source_uid": null, "source_serial": null,
	}, true)
	var vetoed: Dictionary = neutral.duplicate(true)
	vetoed.merge({"index": 1, "card_uid": allowed[0]}, true)
	var end_turn: Dictionary = neutral.duplicate(true)
	end_turn.merge({
		"index": 2, "kind": "end_turn", "card_uid": null,
		"card_serial": null, "option_type_raw": 14,
	}, true)
	frame["prompt_kind"] = "main"
	frame["source"]["window_id"] = "D".repeat(64)
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	frame["options"] = [neutral, vetoed, end_turn]
	var decision: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if not bool(decision.get("accepted", false)) or decision.get("selected_indexes") != [2]:
		return "neutral unmatched action escaped Base fallback: %s" % decision
	if not bool(decision.get("audit", {}).get("fallback_used", false)):
		return "neutral end-turn choice was not audited as a Base fallback: %s" % decision
	return ""


func test_base_tactical_floor_attacks_only_with_strictly_positive_public_damage() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var compiled := RuntimeScript.compile_local_uid(
		spec.get("policy", {}).duplicate(true), spec.get("allowed_card_uids", []).duplicate()
	)
	if not bool(compiled.get("accepted", false)):
		return str(compiled.get("error_code"))
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var attack: Dictionary = frame.get("options", [])[0].duplicate(true)
	attack.merge({
		"index": 0,
		"kind": "attack",
		"card_uid": null,
		"card_serial": null,
		"option_type_raw": 13,
		"source_uid": spec.get("allowed_card_uids", [])[0],
		"source_serial": 10,
		"target_uid": null,
		"target_serial": null,
		"target_remaining_hp": null,
		"target_prize_value": null,
		"target_attached_energy_count": null,
		"target_attached_energy_uids": null,
		"target_minimum_attack_energy_count": null,
		"target_attack_ready": null,
		"target_energy_debt": null,
		"projected_damage": 10,
		"projected_knockout": false,
		"requires_interaction": false,
		"attack_index": 0,
		"ability_index": null,
		"pending_assignment_count": 0,
		"tags": ["attack"],
	}, true)
	var end_turn: Dictionary = attack.duplicate(true)
	end_turn.merge({
		"index": 1,
		"kind": "end_turn",
		"card_serial": null,
		"option_type_raw": 14,
		"source_uid": null,
		"source_serial": null,
		"projected_damage": null,
		"attack_index": null,
		"tags": [],
	}, true)
	frame["prompt_kind"] = "main"
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	frame["options"] = [attack, end_turn]
	var productive: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if productive.get("selected_indexes") != [0]:
		return "positive damage did not beat end turn: %s" % productive
	var matched: Array = productive.get("audit", {}).get("scorecards", [])[0].get("matched_rules", [])
	if matched.is_empty() or matched[0].get("rule_id") != "@base.positive-damage-attack":
		return "base floor audit missing: %s" % productive
	if bool(productive.get("audit", {}).get("fallback_used", true)):
		return "productive base floor was mislabeled as fallback"
	var guarded_frame: Dictionary = frame.duplicate(true)
	guarded_frame["source"]["window_id"] = "C".repeat(64)
	guarded_frame["options"][0]["projected_damage"] = 0
	var guarded: Dictionary = RuntimeScript.decide(compiled.get("policy"), guarded_frame)
	if guarded.get("selected_indexes") != [1] or not bool(guarded.get("audit", {}).get("fallback_used", false)):
		return "zero damage escaped adapter ownership: %s" % guarded
	return ""


func test_variable_damage_count_reserves_core_when_lethal_is_unavailable() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_id"] = "dev.beralee.variable-damage-reserve-red"
	document["adapter_version"] = 5
	document["count_rules"] = [{
		"rule_id": "lethal-or-excess-after-core-reserve",
		"priority": 0,
		"goal_id": document.get("goals", [])[0].get("goal_id"),
		"mode": "ceil_public_fact_divisor_with_reserve",
		"fixed_count": 2,
		"fact": "opponent.active.remaining_hp",
		"divisor": 70,
		"when": [{
			"fact": "prompt_kind", "op": "eq", "value": "assignment_source",
			"card_uid": null,
		}],
	}]
	var allowed: Array = spec.get("allowed_card_uids", []).duplicate()
	var compiled: Dictionary = RuntimeScript.compile_local_uid(document, allowed)
	if not bool(compiled.get("accepted", false)):
		return "reserve count policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	frame["select_semantics"]["min_count"] = 0
	frame["select_semantics"]["max_count"] = 3
	frame["public_state"]["opponent"]["active"] = [
		frame["public_state"]["self"]["active"][0].duplicate(true),
	]
	frame["public_state"]["opponent"]["active"][0]["remaining_hp"] = 280
	frame["options"] = frame.get("options", []).slice(0, 3)
	for index: int in frame["options"].size():
		frame["options"][index]["index"] = index
	var nonlethal: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if nonlethal.get("selected_indexes") != [0] \
			or int(nonlethal.get("audit", {}).get("desired_count", -1)) != 1:
		return "reserve count consumed protected core: %s" % nonlethal
	frame["source"]["window_id"] = "C".repeat(64)
	frame["public_state"]["opponent"]["active"][0]["remaining_hp"] = 140
	var lethal: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if lethal.get("selected_indexes") != [0, 1] \
			or int(lethal.get("audit", {}).get("desired_count", -1)) != 2:
		return "available lethal was not paid exactly: %s" % lethal
	return ""


func test_goal_window_progress_selects_best_current_setup_and_survives_reorder() -> String:
	const BOLT := "CSV7C_154"
	const FIGHTING := "CSVE1C_FIG"
	const LIGHTNING := "CSVE1C_LIG"
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_id"] = "dev.beralee.goal-window-progress-red"
	document["adapter_version"] = 5
	document["goals"] = [{
		"goal_id": "bellowing-thunder-route",
		"stage": "execute",
		"priority": 900,
		"requirements": [{
			"card_uid": BOLT,
			"ready_target_count": 1,
			"energy_required": 2,
			"energy_requirements": [
				{"energy_uid": FIGHTING, "count": 1},
				{"energy_uid": LIGHTNING, "count": 1},
			],
			"attack_index": 1,
			"ability_index": null,
		}],
	}]
	document["count_rules"] = []
	document["rules"] = [
		{
			"rule_id": "setup.best-current-progress",
			"goal_id": "bellowing-thunder-route",
			"goal_stage": "fund",
			"channel": "macro",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 5000,
			"when": [
				{"fact": "goal.window.max_progress", "op": "gte", "value": 1, "card_uid": null},
				{"fact": "goal.option.is_max_progress", "op": "eq", "value": true, "card_uid": null},
			],
			"score_terms": [],
		},
		{
			"rule_id": "setup.attack-after-debt",
			"goal_id": "bellowing-thunder-route",
			"goal_stage": "execute",
			"channel": "tactical",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 4000,
			"when": [{"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": null}],
			"score_terms": [],
		},
	]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(
		document, [BOLT, FIGHTING, LIGHTNING]
	)
	if not bool(compiled.get("accepted", false)):
		return "goal window policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var bolt_slot: Dictionary = frame["public_state"]["self"]["active"][0]
	bolt_slot.merge({
		"serial": 20, "local_card_uid": BOLT,
		"attached_energy_count": 1, "attached_energy_uids": [FIGHTING],
		"minimum_attack_energy_count": 1, "attack_ready": true, "energy_debt": 0,
	}, true)
	frame["public_state"]["self"]["active"] = [bolt_slot]
	frame["public_state"]["self"]["bench"] = []
	frame["prompt_kind"] = "main"
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	var template: Dictionary = frame.get("options", [])[0].duplicate(true)
	var attach: Dictionary = template.duplicate(true)
	attach.merge({
		"index": 0, "kind": "attach_energy", "card_uid": LIGHTNING,
		"option_type_raw": 8,
		"source_uid": null, "source_serial": null, "target_uid": BOLT,
		"target_serial": 20, "target_attached_energy_count": 1,
		"target_attached_energy_uids": [FIGHTING],
		"target_minimum_attack_energy_count": 1, "target_attack_ready": true,
		"target_energy_debt": 0, "projected_damage": null, "attack_index": null,
	}, true)
	var attack: Dictionary = template.duplicate(true)
	attack.merge({
		"index": 1, "kind": "attack", "card_uid": null,
		"card_serial": null, "option_type_raw": 13,
		"source_uid": BOLT, "source_serial": 20, "target_uid": null,
		"target_serial": null, "target_attached_energy_count": null,
		"target_attached_energy_uids": null, "target_minimum_attack_energy_count": null,
		"target_attack_ready": null, "target_energy_debt": null,
		"projected_damage": 0, "attack_index": 0,
	}, true)
	var end_turn: Dictionary = template.duplicate(true)
	end_turn.merge({
		"index": 2, "kind": "end_turn", "card_uid": null,
		"card_serial": null, "option_type_raw": 14,
		"source_uid": null, "source_serial": null, "target_uid": null,
		"target_serial": null, "target_attached_energy_count": null,
		"target_attached_energy_uids": null, "target_minimum_attack_energy_count": null,
		"target_attack_ready": null, "target_energy_debt": null,
		"projected_damage": null, "attack_index": null,
	}, true)
	frame["options"] = [attach, attack, end_turn]
	var current: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if current.get("selected_indexes") != [0]:
		return "best current progress was not selected: %s" % current
	frame["source"]["window_id"] = "D".repeat(64)
	end_turn["index"] = 0
	attack["index"] = 1
	attach["index"] = 2
	frame["options"] = [end_turn, attack, attach]
	var reordered: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if reordered.get("selected_indexes") != [2]:
		return "best current progress did not survive reorder: %s" % reordered
	return ""


func test_goal_window_setup_progress_precedes_declared_nonterminal_attack() -> String:
	const BOLT := "CSV7C_154"
	const FIGHTING := "CSVE1C_FIG"
	const LIGHTNING := "CSVE1C_LIG"
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_id"] = "dev.beralee.goal-window-setup-progress-red"
	document["adapter_version"] = 6
	document["goals"] = [{
		"goal_id": "two-bolt-continuity",
		"stage": "maintain",
		"priority": 900,
		"requirements": [{
			"card_uid": BOLT,
			"ready_target_count": 2,
			"energy_required": 2,
			"energy_requirements": [
				{"energy_uid": FIGHTING, "count": 1},
				{"energy_uid": LIGHTNING, "count": 1},
			],
			"attack_index": 1,
			"ability_index": null,
		}],
	}]
	document["count_rules"] = []
	document["rules"] = [
		{
			"rule_id": "continuity.best-current-setup",
			"goal_id": "two-bolt-continuity",
			"goal_stage": "fund",
			"channel": "future",
			"horizon": 1,
			"confidence_milli": 1000,
			"base_score": 5000,
			"when": [
				{"fact": "goal.window.max_setup_progress", "op": "gte", "value": 1, "card_uid": null},
				{"fact": "goal.option.is_max_setup_progress", "op": "eq", "value": true, "card_uid": null},
			],
			"score_terms": [],
		},
		{
			"rule_id": "continuity.nonterminal-attack",
			"goal_id": "two-bolt-continuity",
			"goal_stage": "execute",
			"channel": "tactical",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 4000,
			"when": [
				{"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": null},
				{"fact": "option.projected_knockout", "op": "eq", "value": false, "card_uid": null},
			],
			"score_terms": [],
		},
	]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(
		document, [BOLT, FIGHTING, LIGHTNING]
	)
	if not bool(compiled.get("accepted", false)):
		return "goal setup-window policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var active: Dictionary = frame["public_state"]["self"]["active"][0].duplicate(true)
	active.merge({
		"serial": 20, "local_card_uid": BOLT,
		"attached_energy_count": 2, "attached_energy_uids": [FIGHTING, LIGHTNING],
		"minimum_attack_energy_count": 2, "attack_ready": true, "energy_debt": 0,
	}, true)
	var bench: Dictionary = active.duplicate(true)
	bench.merge({
		"serial": 21, "attached_energy_count": 1, "attached_energy_uids": [FIGHTING],
		"attack_ready": false, "energy_debt": 1,
	}, true)
	frame["public_state"]["self"]["active"] = [active]
	frame["public_state"]["self"]["bench"] = [bench]
	frame["prompt_kind"] = "main"
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	var template: Dictionary = frame.get("options", [])[0].duplicate(true)
	var attach: Dictionary = template.duplicate(true)
	attach.merge({
		"index": 0, "kind": "attach_energy", "card_uid": LIGHTNING,
		"option_type_raw": 8,
		"source_uid": null, "source_serial": null, "target_uid": BOLT,
		"target_serial": 21, "target_attached_energy_count": 1,
		"target_attached_energy_uids": [FIGHTING],
		"target_minimum_attack_energy_count": 2, "target_attack_ready": false,
		"target_energy_debt": 1, "projected_damage": null,
		"projected_knockout": false, "attack_index": null,
	}, true)
	var attack: Dictionary = template.duplicate(true)
	attack.merge({
		"index": 1, "kind": "attack", "card_uid": null,
		"card_serial": null, "option_type_raw": 13,
		"source_uid": BOLT, "source_serial": 20, "target_uid": null,
		"target_serial": null, "target_attached_energy_count": null,
		"target_attached_energy_uids": null, "target_minimum_attack_energy_count": null,
		"target_attack_ready": null, "target_energy_debt": null,
		"projected_damage": 70, "projected_knockout": false, "attack_index": 1,
	}, true)
	frame["options"] = [attach, attack]
	var current: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if current.get("selected_indexes") != [0]:
		return "setup progress did not precede nonterminal attack: %s" % current
	frame["source"]["window_id"] = "E".repeat(64)
	attack["index"] = 0
	attach["index"] = 1
	frame["options"] = [attack, attach]
	var reordered: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if reordered.get("selected_indexes") != [1]:
		return "setup progress did not survive declared-attack reorder: %s" % reordered
	return ""


func test_goal_relative_route_facts_use_declared_attack_not_any_legal_attack() -> String:
	const BOLT := "CSV7C_154"
	const FAN := "CSV9C_161"
	const FIGHTING := "CSVE1C_FIG"
	const LIGHTNING := "CSVE1C_LIG"
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_id"] = "dev.beralee.route-facts-red"
	document["adapter_version"] = 3
	document["goals"] = [{
		"goal_id": "bellowing-thunder-route",
		"stage": "execute",
		"priority": 900,
		"requirements": [{
			"card_uid": BOLT,
			"ready_target_count": 1,
			"energy_required": 2,
			"energy_requirements": [
				{"energy_uid": FIGHTING, "count": 1},
				{"energy_uid": LIGHTNING, "count": 1},
			],
			"attack_index": 1,
			"ability_index": null,
		}],
	}]
	document["count_rules"] = []
	document["rules"] = [
		{
			"rule_id": "route.fund-exact-core",
			"goal_id": "bellowing-thunder-route",
			"goal_stage": "fund",
			"channel": "macro",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 3000,
			"when": [{
				"fact": "goal.option.funds_target", "op": "eq", "value": true,
				"card_uid": null,
			}],
			"score_terms": [],
		},
		{
			"rule_id": "route.pivot-exact-ready",
			"goal_id": "bellowing-thunder-route",
			"goal_stage": "ready",
			"channel": "macro",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 4000,
			"when": [{
				"fact": "goal.option.pivots_ready_target", "op": "eq", "value": true,
				"card_uid": null,
			}],
			"score_terms": [],
		},
		{
			"rule_id": "route.execute-declared-attack",
			"goal_id": "bellowing-thunder-route",
			"goal_stage": "execute",
			"channel": "tactical",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 5000,
			"when": [{
				"fact": "goal.option.executes_requirement", "op": "eq", "value": true,
				"card_uid": null,
			}],
			"score_terms": [],
		},
	]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(
		document, [BOLT, FAN, FIGHTING, LIGHTNING]
	)
	if not bool(compiled.get("accepted", false)):
		return "route policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var fan_slot: Dictionary = frame.get("public_state", {}).get("self", {}).get("active", [])[0]
	var bolt_slot: Dictionary = fan_slot.duplicate(true)
	fan_slot.merge({
		"serial": 20, "local_card_uid": FAN,
		"attached_energy_count": 1, "attached_energy_uids": [FIGHTING],
		"minimum_attack_energy_count": 1, "attack_ready": true, "energy_debt": 0,
	}, true)
	bolt_slot.merge({
		"serial": 21, "local_card_uid": BOLT,
		"attached_energy_count": 1, "attached_energy_uids": [FIGHTING],
		"minimum_attack_energy_count": 1, "attack_ready": true, "energy_debt": 0,
	}, true)
	frame["public_state"]["self"]["active"] = [fan_slot]
	frame["public_state"]["self"]["bench"] = [bolt_slot]
	frame["prompt_kind"] = "main"
	frame["select_semantics"]["min_count"] = 1
	frame["select_semantics"]["max_count"] = 1
	var template: Dictionary = frame.get("options", [])[0].duplicate(true)
	var attach_fan: Dictionary = template.duplicate(true)
	attach_fan.merge({
		"index": 0, "kind": "attach_energy", "card_uid": LIGHTNING,
		"option_type_raw": 8,
		"source_uid": null, "source_serial": null, "target_uid": FAN,
		"target_serial": 20, "target_attached_energy_count": 1,
		"target_attached_energy_uids": [FIGHTING],
		"target_minimum_attack_energy_count": 1, "target_attack_ready": true,
		"target_energy_debt": 0, "projected_damage": null, "attack_index": null,
	}, true)
	var attach_bolt: Dictionary = attach_fan.duplicate(true)
	attach_bolt.merge({"index": 1, "target_uid": BOLT, "target_serial": 21}, true)
	var end_turn: Dictionary = attach_fan.duplicate(true)
	end_turn.merge({
		"index": 2, "kind": "end_turn", "card_uid": null, "target_uid": null,
		"card_serial": null, "option_type_raw": 14,
		"target_serial": null, "target_attached_energy_count": null,
		"target_attached_energy_uids": null, "target_minimum_attack_energy_count": null,
		"target_attack_ready": null, "target_energy_debt": null,
	}, true)
	frame["options"] = [attach_fan, attach_bolt, end_turn]
	var funded: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if funded.get("selected_indexes") != [1]:
		return "typed route funded a non-goal target: %s" % funded
	var pivot: Dictionary = frame.duplicate(true)
	pivot["source"]["window_id"] = "C".repeat(64)
	pivot["prompt_kind"] = "send_out"
	pivot["options"][0].merge({
		"kind": "send_out", "card_uid": FAN, "card_serial": 20,
		"option_type_raw": 3,
	}, true)
	pivot["options"][1].merge({
		"kind": "send_out", "card_uid": BOLT, "card_serial": 21,
		"option_type_raw": 3,
	}, true)
	var not_ready: Dictionary = RuntimeScript.decide(compiled.get("policy"), pivot)
	if not_ready.get("selected_indexes") != [2]:
		return "generic attack-ready incorrectly satisfied declared route: %s" % not_ready
	pivot["source"]["window_id"] = "D".repeat(64)
	pivot["public_state"]["self"]["bench"][0].merge({
		"attached_energy_count": 2,
		"attached_energy_uids": [FIGHTING, LIGHTNING],
	}, true)
	pivot["options"][1].merge({
		"target_attached_energy_count": 2,
		"target_attached_energy_uids": [FIGHTING, LIGHTNING],
	}, true)
	var ready: Dictionary = RuntimeScript.decide(compiled.get("policy"), pivot)
	if ready.get("selected_indexes") != [1]:
		return "declared route did not pivot exact-ready attacker: %s" % ready
	var attack_frame: Dictionary = pivot.duplicate(true)
	attack_frame["source"]["window_id"] = "E".repeat(64)
	attack_frame["prompt_kind"] = "main"
	var first_attack: Dictionary = template.duplicate(true)
	first_attack.merge({
		"index": 0, "kind": "attack", "card_uid": null,
		"card_serial": null, "option_type_raw": 13,
		"source_uid": BOLT, "source_serial": 21, "target_uid": null,
		"target_serial": null, "target_attached_energy_count": null,
		"target_attached_energy_uids": null, "target_minimum_attack_energy_count": null,
		"target_attack_ready": null, "target_energy_debt": null,
		"projected_damage": 0, "attack_index": 0,
	}, true)
	var declared_attack: Dictionary = first_attack.duplicate(true)
	declared_attack.merge({"index": 1, "attack_index": 1}, true)
	attack_frame["options"] = [first_attack, declared_attack, end_turn]
	var executed: Dictionary = RuntimeScript.decide(compiled.get("policy"), attack_frame)
	if executed.get("selected_indexes") != [1]:
		return "declared attack index was not executed: %s" % executed
	return ""


func test_typed_source_count_selects_only_available_missing_energy_quota() -> String:
	const BOLT := "CSV7C_154"
	const FIGHTING := "CSVE1C_FIG"
	const LIGHTNING := "CSVE1C_LIG"
	const GRASS := "CSVE1C_GRA"
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_id"] = "dev.beralee.typed-source-count-red"
	document["adapter_version"] = 4
	document["goals"] = [{
		"goal_id": "bellowing-thunder-route",
		"stage": "fund",
		"priority": 900,
		"requirements": [{
			"card_uid": BOLT,
			"ready_target_count": 1,
			"energy_required": 2,
			"energy_requirements": [
				{"energy_uid": FIGHTING, "count": 1},
				{"energy_uid": LIGHTNING, "count": 1},
			],
			"attack_index": 1,
			"ability_index": null,
		}],
	}]
	document["count_rules"] = [{
		"rule_id": "typed-missing-source-count",
		"priority": 0,
		"goal_id": "bellowing-thunder-route",
		"mode": "goal_missing_energy_sources",
		"fixed_count": null,
		"fact": null,
		"divisor": null,
		"when": [{
			"fact": "prompt_kind", "op": "eq", "value": "assignment_source",
			"card_uid": null,
		}],
	}]
	document["rules"] = [{
		"rule_id": "typed-missing-source",
		"goal_id": "bellowing-thunder-route",
		"goal_stage": "fund",
		"channel": "interaction",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 1000,
		"when": [{
			"fact": "goal.option.supplies_missing_energy", "op": "eq", "value": true,
			"card_uid": null,
		}],
		"score_terms": [],
	}]
	var compiled: Dictionary = RuntimeScript.compile_local_uid(
		document, [BOLT, FIGHTING, LIGHTNING, GRASS]
	)
	if not bool(compiled.get("accepted", false)):
		return "typed source policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	var bolt_slot: Dictionary = frame.get("public_state", {}).get("self", {}).get("active", [])[0]
	bolt_slot.merge({
		"serial": 20, "local_card_uid": BOLT,
		"attached_energy_count": 1, "attached_energy_uids": [GRASS],
		"minimum_attack_energy_count": 1, "attack_ready": true, "energy_debt": 0,
	}, true)
	frame["public_state"]["self"]["active"] = [bolt_slot]
	frame["public_state"]["self"]["bench"] = []
	frame["prompt_kind"] = "assignment_source"
	frame["select_semantics"]["min_count"] = 0
	frame["select_semantics"]["max_count"] = 2
	var template: Dictionary = frame.get("options", [])[0].duplicate(true)
	var fighting_a: Dictionary = template.duplicate(true)
	fighting_a.merge({"index": 0, "kind": "effect_target", "card_uid": FIGHTING}, true)
	var fighting_b: Dictionary = fighting_a.duplicate(true)
	fighting_b.merge({"index": 1}, true)
	var lightning: Dictionary = fighting_a.duplicate(true)
	lightning.merge({"index": 2, "card_uid": LIGHTNING}, true)
	var grass: Dictionary = fighting_a.duplicate(true)
	grass.merge({"index": 3, "card_uid": GRASS}, true)
	frame["options"] = [fighting_a, fighting_b, lightning, grass]
	var exact: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if exact.get("selected_indexes") != [0, 2]:
		return "typed quota selected duplicate or wrong energy: %s" % exact
	var reordered: Dictionary = frame.duplicate(true)
	reordered["source"]["window_id"] = "C".repeat(64)
	lightning["index"] = 0
	grass["index"] = 1
	fighting_a["index"] = 2
	fighting_b["index"] = 3
	reordered["options"] = [lightning, grass, fighting_a, fighting_b]
	var semantic: Dictionary = RuntimeScript.decide(compiled.get("policy"), reordered)
	if semantic.get("selected_indexes") != [0, 2]:
		return "typed quota did not survive reorder: %s" % semantic
	var unavailable: Dictionary = frame.duplicate(true)
	unavailable["source"]["window_id"] = "D".repeat(64)
	grass["index"] = 0
	unavailable["options"] = [grass]
	var no_wrong_type: Dictionary = RuntimeScript.decide(compiled.get("policy"), unavailable)
	if no_wrong_type.get("selected_indexes") != []:
		return "optional typed source selected unavailable wrong type: %s" % no_wrong_type
	return ""


func test_distinct_card_uid_count_uses_each_printing_at_most_once() -> String:
	const FROSLASS := "CSV6C_053"
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_version"] = 5
	document["count_rules"] = [{
		"rule_id": "distinct-evolution-printings",
		"priority": 0,
		"goal_id": document.get("goals", [])[0].get("goal_id"),
		"mode": "distinct_card_uids",
		"fixed_count": null,
		"fact": null,
		"divisor": null,
		"when": [{
			"fact": "prompt_kind", "op": "eq", "value": "search",
			"card_uid": null,
		}],
	}]
	var allowed: Array = spec.get("allowed_card_uids", []).duplicate()
	allowed.append(FROSLASS)
	var compiled: Dictionary = RuntimeScript.compile_local_uid(document, allowed)
	if not bool(compiled.get("accepted", false)):
		return "distinct printing policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	frame["prompt_kind"] = "search"
	frame["select_semantics"]["min_count"] = 0
	frame["select_semantics"]["max_count"] = 2
	var template: Dictionary = frame.get("options", [])[0].duplicate(true)
	var froslass_a: Dictionary = template.duplicate(true)
	froslass_a.merge({"index": 0, "kind": "effect_target", "card_uid": FROSLASS}, true)
	var froslass_b: Dictionary = froslass_a.duplicate(true)
	froslass_b["index"] = 1
	var morgrem_a: Dictionary = froslass_a.duplicate(true)
	morgrem_a.merge({"index": 2, "card_uid": "CSV10C_147"}, true)
	var morgrem_b: Dictionary = morgrem_a.duplicate(true)
	morgrem_b["index"] = 3
	frame["options"] = [froslass_a, froslass_b, morgrem_a, morgrem_b]
	var exact: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if exact.get("selected_indexes") != [0, 2]:
		return "distinct quota selected duplicate printing: %s" % exact
	var reordered: Dictionary = frame.duplicate(true)
	reordered["source"]["window_id"] = "9".repeat(64)
	morgrem_a["index"] = 0
	froslass_a["index"] = 1
	froslass_b["index"] = 2
	morgrem_b["index"] = 3
	reordered["options"] = [morgrem_a, froslass_a, froslass_b, morgrem_b]
	var semantic: Dictionary = RuntimeScript.decide(compiled.get("policy"), reordered)
	if semantic.get("selected_indexes") != [0, 1]:
		return "distinct quota did not survive reorder: %s" % semantic
	return ""


func test_godot_package_loader_accepts_v2_only_for_exact_local_deck_uids() -> String:
	var policy: Dictionary = _vectors().get("cases", [])[0].get("policy", {}).duplicate(true)
	var allowed: Array = _vectors().get("cases", [])[0].get("allowed_card_uids", []).duplicate()
	var cards: Array = []
	for uid: String in allowed:
		cards.append({"local_card_uid": uid})
	var deck := {
		"card_id_domain": "godot_local_card_uid_v1",
		"unique_card_count": cards.size(),
		"cards": cards,
	}
	var loader := PackageLoaderScript.new()
	if not bool(loader.contract_report().get("ok", false)):
		return "loader contract rejected: %s" % loader.contract_report()
	if not bool(loader.call("_valid_adapter_shape", policy)):
		return "v2 adapter shape rejected"
	if not bool(loader.call("_public_adapter_valid", policy, deck)):
		return "v2 exact local deck rejected"
	policy.goals[0].requirements[0].card_uid = "UNKNOWN_999"
	if bool(loader.call("_public_adapter_valid", policy, deck)):
		return "unknown deck uid accepted"
	deck.card_id_domain = "official_cabt_card_id"
	if bool(loader.call("_public_adapter_valid", _vectors().get("cases", [])[0].get("policy", {}), deck)):
		return "v2 non-local deck accepted"
	return ""


func test_public_number_option_fact_selects_exact_counter_amount() -> String:
	var spec: Dictionary = _vectors().get("cases", [])[0]
	var document: Dictionary = spec.get("policy", {}).duplicate(true)
	document["adapter_version"] = 91
	var goal_id: String = str(document.get("goals", [])[0].get("goal_id", ""))
	document["rules"].append({
		"rule_id": "munkidori.public-number",
		"goal_id": goal_id,
		"goal_stage": "execute",
		"channel": "interaction",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 0,
		"when": [{
			"fact": "prompt_kind", "op": "eq", "value": "effect_target", "card_uid": null,
		}],
		"score_terms": [{
			"fact": "option.option_number", "coefficient": 1000,
			"minimum": 1, "maximum": 3,
		}],
	})
	var compiled: Dictionary = RuntimeScript.compile_local_uid(
		document, spec.get("allowed_card_uids", []).duplicate()
	)
	if not bool(compiled.get("accepted", false)):
		return "public number policy rejected: %s" % compiled.get("error_code")
	var frame: Dictionary = spec.get("frame", {}).duplicate(true)
	frame["prompt_kind"] = "effect_target"
	frame["select_semantics"].merge({
		"min_count": 1, "max_count": 1, "select_type_raw": 8, "select_context_raw": 40,
	}, true)
	var template: Dictionary = frame.get("options", [])[0].duplicate(true)
	var options: Array = []
	for row: Dictionary in [
		{"index": 0, "option_number": 1},
		{"index": 1, "option_number": 3},
		{"index": 2, "option_number": 2},
	]:
		var option: Dictionary = template.duplicate(true)
		option.merge({
			"index": row.index, "kind": "effect_target", "option_type_raw": 0,
			"option_number": row.option_number, "card_uid": null, "card_serial": null,
			"source_uid": null, "source_serial": null, "target_uid": null,
			"target_serial": null,
		}, true)
		options.append(option)
	frame["options"] = options
	var decision: Dictionary = RuntimeScript.decide(compiled.get("policy"), frame)
	if decision.get("selected_indexes") != [1]:
		return "public number option was not ranked semantically: %s" % decision
	return ""
