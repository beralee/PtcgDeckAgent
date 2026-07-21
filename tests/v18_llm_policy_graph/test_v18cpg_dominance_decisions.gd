extends SceneTree

const FIXTURE_PATH := "res://tests/v18_llm_policy_graph/fixtures/dominance_decisions_v1.json"
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if not (parsed is Dictionary):
		_fail("fixture JSON must parse as an object")
		_finish([])
		return
	var fixture: Dictionary = parsed
	var cases: Array = fixture.get("cases", []) if fixture.get("cases", []) is Array else []
	var provenance: Dictionary = fixture.get("provenance", {}) if fixture.get("provenance", {}) is Dictionary else {}
	if cases.size() != 20:
		_fail("dominance set must stay frozen at exactly 20 cases, got %d" % cases.size())
	if provenance.size() != 20:
		_fail("dominance set must have exactly one historical provenance record per case")
	var seen: Dictionary = {}
	var results: Array[Dictionary] = []
	for raw_case: Variant in cases:
		if not (raw_case is Dictionary):
			_fail("every dominance case must be an object")
			continue
		var case: Dictionary = raw_case
		var result := _run_case(case)
		results.append(result)
		var case_id := str(case.get("id", ""))
		if case_id == "" or seen.has(case_id):
			_fail("case ids must be non-empty and unique: %s" % case_id)
		seen[case_id] = true
		_validate_provenance(case_id, provenance.get(case_id, {}))
	_finish(results)


func _validate_provenance(case_id: String, raw_provenance: Variant) -> void:
	if not (raw_provenance is Dictionary):
		_fail("%s: missing historical provenance" % case_id)
		return
	var source: Dictionary = raw_provenance
	var ledger := str(source.get("ledger", ""))
	var round_number := int(source.get("round", 0))
	var failure_category := str(source.get("failure_category", ""))
	var valid_categories: Array[String] = [
		"visibility_violation", "belief_error", "semantic_gap", "fact_or_solver_error",
		"frontier_gap", "outcome_or_threat_error", "policy_graph_error",
		"model_selection_error", "route_synthesis_error", "compiler_error",
		"interaction_error", "event_or_version_error", "engine_error",
	]
	if ledger == "" or not FileAccess.file_exists(ledger):
		_fail("%s: provenance ledger does not exist: %s" % [case_id, ledger])
	if round_number < 1 or round_number > 10:
		_fail("%s: provenance round must be within the ten-round evolution ledger" % case_id)
	if failure_category not in valid_categories:
		_fail("%s: provenance failure category is not registered: %s" % [case_id, failure_category])
	if str(source.get("derivation", "")).strip_edges() == "":
		_fail("%s: provenance must explain how the case was derived" % case_id)


func _run_case(case: Dictionary) -> Dictionary:
	var case_id := str(case.get("id", "unnamed"))
	var deck_id := int(case.get("deck_id", 0))
	var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
	if profile.is_empty():
		_fail("%s: missing V18CPG profile for deck %d" % [case_id, deck_id])
		return {"id": case_id, "passed": false}
	var observation: Dictionary = case.get("observation", {}) if case.get("observation", {}) is Dictionary else {}
	var facts: Dictionary = case.get("facts", {}) if case.get("facts", {}) is Dictionary else {}
	var rule_scores: Dictionary = case.get("rule_scores", {}) if case.get("rule_scores", {}) is Dictionary else {}
	var semantic_manifest: Dictionary = case.get("semantic_manifest", {}) if case.get("semantic_manifest", {}) is Dictionary else {}
	var route_search := RouteSearchScript.new()
	var frontier: Array[Dictionary] = route_search.build_frontier(
		observation,
		rule_scores,
		semantic_manifest,
		facts,
		10
	)
	var registry := CapabilityRegistryScript.new()
	frontier = registry.annotate_frontier(frontier, observation, facts, profile, semantic_manifest)
	var rule_action_id := str(case.get("rule_action_id", ""))
	var actual_rule_action := str(frontier[0].get("safe_prefix_action_id", "")) if not frontier.is_empty() else ""
	if actual_rule_action != rule_action_id:
		_fail("%s: frozen Rule choice changed; expected %s got %s" % [case_id, rule_action_id, actual_rule_action])
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile, semantic_manifest)
	var selected := strategy._find_module_verified_upgrade(frontier, facts)
	var selection_owner := "autonomous_upgrade"
	var expected_action := str(case.get("expected_action_id", ""))
	# A deterministic attack or typed attack-cost completion remains a valid
	# model switch certificate, but neither is a general autonomous Rule rewrite
	# when a non-terminal Rule action may safely precede it. Historical cases of
	# that shape therefore validate the same frozen superior action through the
	# model-owned safety path.
	if selected.is_empty():
		var model_candidate := _find_candidate_by_action(frontier, expected_action)
		if not model_candidate.is_empty():
			var model_safety := strategy._validate_model_route_safety(
				str(model_candidate.get("route_id", "")), frontier, facts,
				str(model_candidate.get("candidate_id", ""))
			)
			var model_advantage: Dictionary = model_safety.get("advantage", {}) \
				if model_safety.get("advantage", {}) is Dictionary else {}
			var model_reason := str(model_safety.get("reason", ""))
			var deterministic_certificate := model_reason in [
				"deterministic_win_now",
				"deterministic_prize_gain",
			]
			var typed_completion_certificate := model_reason == "module_verified_advantage" \
				and str(model_advantage.get("certificate_kind", "")) == "public_typed_attack_cost_completion"
			if bool(model_safety.get("valid", false)) \
					and (deterministic_certificate or typed_completion_certificate):
				selected = model_candidate.duplicate(true)
				selected["verified_reason"] = model_reason
				selected["verified_advantage"] = model_advantage.duplicate(true)
				selection_owner = "model_switch_certificate"
	var selected_action := str(selected.get("safe_prefix_action_id", ""))
	var reason := str(selected.get("verified_reason", ""))
	var expected_reason := str(case.get("expected_reason", ""))
	if selected_action != expected_action:
		var expected_candidate: Dictionary = {}
		for candidate: Dictionary in frontier:
			if str(candidate.get("safe_prefix_action_id", "")) == expected_action:
				expected_candidate = candidate
				break
		var diagnostic := strategy._validate_model_route_safety(
			str(expected_candidate.get("route_id", "")), frontier, facts,
			str(expected_candidate.get("candidate_id", ""))
		) if not expected_candidate.is_empty() else {"reason": "expected_candidate_missing"}
		var module_diagnostic := registry.verify_route_advantage(expected_candidate, frontier[0], facts, profile) \
			if not expected_candidate.is_empty() and not frontier.is_empty() else {}
		_fail("%s: expected superior action %s got %s; diagnostic=%s module=%s selected_annotations=%s top_annotations=%s" % [case_id, expected_action, selected_action, JSON.stringify(diagnostic), JSON.stringify(module_diagnostic), JSON.stringify(expected_candidate.get("module_annotations", {})), JSON.stringify(frontier[0].get("module_annotations", {}))])
	if reason != expected_reason:
		_fail("%s: expected proof reason %s got %s" % [case_id, expected_reason, reason])
	if selected_action == rule_action_id:
		_fail("%s: case does not replace the Rule decision" % case_id)
	var passed := actual_rule_action == rule_action_id \
		and selected_action == expected_action \
		and reason == expected_reason \
		and selected_action != rule_action_id
	return {
		"id": case_id,
		"deck_id": deck_id,
		"title": str(case.get("title", "")),
		"proof_class": str(case.get("proof_class", "")),
		"rule_action_id": actual_rule_action,
		"selected_action_id": selected_action,
		"selection_owner": selection_owner,
		"verification_reason": reason,
		"passed": passed,
	}


func _find_candidate_by_action(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	return {}


func _finish(results: Array[Dictionary]) -> void:
	var passed := 0
	for result: Dictionary in results:
		if bool(result.get("passed", false)):
			passed += 1
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"evaluation_set": "dominance_decisions_v1",
		"case_count": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"all_passed": _failures.is_empty() and passed == 20,
		"results": results,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg"))
	var output_path := ProjectSettings.globalize_path("res://tmp/v18cpg/v18cpg_dominance_decisions_v1.json")
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty() and passed == 20:
		print("V18CPG dominance decision set: PASS (20/20)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG dominance decision set: FAIL (%d/20)" % passed)
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
