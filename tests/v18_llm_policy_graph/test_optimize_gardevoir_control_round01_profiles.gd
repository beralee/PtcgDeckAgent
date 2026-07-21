extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const ProfilePolicyScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGProfilePolicy.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")

const DECK_IDS: Array[int] = [
	800017097,
	800018105,
	800018497,
	800018498,
	800017631,
	800018359,
	800033475,
]
const FIXTURE_ROOT := "res://tests/v18_llm_policy_graph/fixtures/optimization21_gardevoir_control"

var _failures: Array[String] = []


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for deck_id: int in DECK_IDS:
		var fixture := _load_fixture(deck_id)
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		_validate_profile(deck_id, fixture, profile)
		_validate_attack_cost_certificate(deck_id, fixture, profile)
		rows.append({
			"deck_id": deck_id,
			"profile_version": int(profile.get("profile_version", 0)),
			"modules": (profile.get("modules", []) as Array).duplicate(),
			"failure_category": str(fixture.get("failure_category", "")),
		})
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"group": "gardevoir_control",
		"round": 1,
		"deck_count": rows.size(),
		"all_passed": _failures.is_empty() and rows.size() == DECK_IDS.size(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg/optimization21/gardevoir_control"))
	var output := FileAccess.open("res://tmp/v18cpg/optimization21/gardevoir_control/round01_profile_fixtures.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty():
		print("optimization21 gardevoir/control round01 profiles: PASS (7/7)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _load_fixture(deck_id: int) -> Dictionary:
	var path := "%s/%d_round01_profile.json" % [FIXTURE_ROOT, deck_id]
	_check(FileAccess.file_exists(path), "%d fixture must exist" % deck_id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%d fixture must be valid JSON" % deck_id)
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_profile(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	_check(int(fixture.get("deck_id", 0)) == deck_id, "%d fixture identity must match" % deck_id)
	_check(int(fixture.get("seed_base", 0)) == deck_id, "%d seed base must remain fixed" % deck_id)
	_check(not (fixture.get("target_flip_seeds", []) as Array).is_empty(), "%d fixture must pin at least one target flip seed" % deck_id)
	_check(int(profile.get("deck_id", 0)) == deck_id, "%d merged profile identity must remain immutable" % deck_id)
	_check(str(profile.get("strategy_id", "")).begins_with("v18cpg_%d_" % deck_id), "%d strategy must stay on V18CPG" % deck_id)
	_check(str(profile.get("base_strategy_id", "")).begins_with("v18_%d_" % deck_id), "%d exact Rule floor must remain bound" % deck_id)
	_check(int(profile.get("profile_version", 0)) >= 2, "%d profile_version must retain or advance round01" % deck_id)
	_check(int(profile.get("profile_version", 0)) >= int(fixture.get("expected_profile_version", 2)), "%d profile version must meet its fixture" % deck_id)
	_check(int(profile.get("semantic_version", 0)) == int(fixture.get("expected_semantic_version", 1)), "%d semantic version must match its fixture" % deck_id)
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "%d visible wait budget must remain 6500ms" % deck_id)
	_check(int(profile.get("initial_response_token_budget", 0)) == 400, "%d initial token budget must remain compact" % deck_id)
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "%d delta token budget must remain compact" % deck_id)
	_check(int(profile.get("max_policy_nodes", 0)) in [5, 6, 7, 8], "%d policy graph must remain bounded" % deck_id)
	_check(profile.get("modules", []) == fixture.get("expected_modules", []), "%d module composition must remain immutable" % deck_id)
	var policy := ProfilePolicyScript.new().sanitize(profile, StrategyScript.REGISTERED_ROUTE_IDS)
	var priorities: Array = policy.get("strategic_priorities", []) if policy.get("strategic_priorities", []) is Array else []
	_check(priorities.size() == 4, "%d four guarded priorities must survive sanitization" % deck_id)
	for priority: Dictionary in priorities:
		_check(not (priority.get("when_all", []) as Array).is_empty(), "%d priority guard must be explicit" % deck_id)
		_check(not (priority.get("prefer_routes", []) as Array).is_empty(), "%d priority must retain executable routes" % deck_id)
	var expected_roles: Array = fixture.get("expected_protected_roles", []) if fixture.get("expected_protected_roles", []) is Array else []
	for raw_role: Variant in expected_roles:
		_check(str(raw_role) in (profile.get("protected_roles", []) as Array), "%d must protect role %s" % [deck_id, str(raw_role)])
	var encoded := JSON.stringify(profile)
	_check(not encoded.contains("opponent_hand") and not encoded.contains("deck_order"), "%d profile must remain public-information-only" % deck_id)


func _validate_attack_cost_certificate(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var expected: Dictionary = fixture.get("expected_profiled_attack_cost", {}) \
		if fixture.get("expected_profiled_attack_cost", {}) is Dictionary else {}
	var module_id := str(expected.get("module", ""))
	var attacker_uid := str(expected.get("uid", ""))
	var cost: Array = expected.get("cost", []) if expected.get("cost", []) is Array else []
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = module_parameters.get(module_id, {}) \
		if module_parameters.get(module_id, {}) is Dictionary else {}
	var attack_costs: Dictionary = parameters.get("attack_cost_by_uid", {}) \
		if parameters.get("attack_cost_by_uid", {}) is Dictionary else {}
	_check(attack_costs.get(attacker_uid, []) == cost, "%d exact public attack cost must survive profile merge" % deck_id)
	if cost.is_empty():
		return
	var attached: Array = []
	for index: int in range(cost.size() - 1):
		attached.append({"energy_type": str(cost[index])})
	var attach_symbol := str(cost[cost.size() - 1])
	if attach_symbol == "C":
		attach_symbol = "D"
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule:%d" % deck_id,
		"route_id": "route:information",
		"action_kind": "play_trainer",
		"action_ref": {"card": {"uid": "PUBLIC_DRAW"}},
		"base_score": 100.0,
	}, {
		"candidate_id": "candidate:profiled:%d" % deck_id,
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "slot:attacker", "card": {"energy_type": attach_symbol}},
		"base_score": 90.0,
	}]
	var observation := {
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": {"slot_id": "slot:attacker", "pokemon": {"uid": attacker_uid}, "energy": attached},
			"bench": [],
			"discard": [],
		},
		"opponent": {"active": {}, "bench": [], "hand": [{"uid": "FORBIDDEN_SECRET"}]},
	}
	var registry := CapabilityRegistryScript.new()
	var facts := {"turn": {"energy_available": true}, "attack": {"ready": false, "ko_available": false}, "resources": {"deck_low": false}}
	var annotated := registry.annotate_frontier(frontier, observation, facts, profile, {})
	_check(annotated.size() == 2, "%d modules must preserve exact candidates" % deck_id)
	if annotated.size() != 2:
		return
	var certificate := registry.verify_route_advantage(annotated[1], annotated[0], facts, profile)
	_check(bool(certificate.get("verified", false)), "%d exact attack-cost completion must mint a public certificate" % deck_id)
	_check(str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion", "%d certificate kind must remain explicit" % deck_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), "%d annotations must never copy opponent hidden state" % deck_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
