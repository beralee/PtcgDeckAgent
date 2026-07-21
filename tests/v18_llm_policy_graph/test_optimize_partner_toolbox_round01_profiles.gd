extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const ProfilePolicyScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGProfilePolicy.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const CyclePivotScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCyclePivot.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const EnergyBurstScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")

const DECK_IDS: Array[int] = [
	800016834,
	800017407,
	800018500,
	800018502,
	800018539,
	800018543,
	800018880,
]
const FIXTURE_ROOT := "res://tests/v18_llm_policy_graph/fixtures/optimization21_partner_toolbox"

var _failures: Array[String] = []


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for deck_id: int in DECK_IDS:
		var fixture := _load_fixture(deck_id)
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		_validate_profile_identity(deck_id, fixture, profile)
		_validate_policy_shape(deck_id, fixture, profile)
		_validate_module_parameters(deck_id, fixture, profile)
		_validate_profiled_attack_cost_certificate(deck_id, fixture, profile)
		_validate_energy_burst_mode(deck_id, fixture, profile)
		rows.append({
			"deck_id": deck_id,
			"seed_base": int(fixture.get("seed_base", 0)),
			"profile_version": int(profile.get("profile_version", 0)),
			"module_count": (profile.get("modules", []) as Array).size(),
			"typed_attachment_checked": "cycle_pivot" in (profile.get("modules", []) as Array),
		})
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"round": 1,
		"deck_count": rows.size(),
		"all_passed": _failures.is_empty() and rows.size() == DECK_IDS.size(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg/optimization21/partner_toolbox"))
	var output := FileAccess.open("res://tmp/v18cpg/optimization21/partner_toolbox/round01_profile_fixtures.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty():
		print("optimization21 partner/toolbox round01 profiles: PASS (7/7)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 partner/toolbox round01 profiles: FAIL (%d)" % _failures.size())
	quit(1)


func _load_fixture(deck_id: int) -> Dictionary:
	var path := "%s/%d_round01_profile.json" % [FIXTURE_ROOT, deck_id]
	_check(FileAccess.file_exists(path), "%d fixture must exist" % deck_id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%d fixture must be valid JSON" % deck_id)
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_profile_identity(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	_check(not profile.is_empty(), "%d merged profile must load" % deck_id)
	_check(int(profile.get("deck_id", 0)) == deck_id, "%d deck identity must remain immutable" % deck_id)
	_check(str(profile.get("strategy_id", "")).begins_with("v18cpg_%d_" % deck_id), "%d strategy identity must remain V18CPG" % deck_id)
	_check(str(profile.get("base_strategy_id", "")).begins_with("v18_%d_" % deck_id), "%d exact Rule floor must remain bound" % deck_id)
	var expected_profile_version := int(fixture.get("expected_profile_version", 2))
	_check(int(profile.get("profile_version", 0)) >= expected_profile_version, \
		"%d profile_version must be at least round01 version %d" % [deck_id, expected_profile_version])
	_check(int(profile.get("semantic_version", 0)) == 1, "%d semantic_version must remain frozen at 1" % deck_id)
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "%d wait budget must remain 6500ms" % deck_id)
	_check(int(profile.get("initial_response_token_budget", 0)) == 420, "%d initial token budget must be 420" % deck_id)
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "%d delta token budget must be 170" % deck_id)
	_check(int(profile.get("max_policy_nodes", 0)) == 7, "%d policy graph must stay bounded to 7 nodes" % deck_id)
	var current_modules: Array = profile.get("modules", []) if profile.get("modules", []) is Array else []
	var round01_modules: Array = fixture.get("expected_modules", []) if fixture.get("expected_modules", []) is Array else []
	for raw_module: Variant in round01_modules:
		_check(str(raw_module) in current_modules, "%d round01 capability %s must remain present" % [deck_id, str(raw_module)])
	_check(int(fixture.get("deck_id", 0)) == deck_id, "%d fixture identity must match" % deck_id)
	_check(int(fixture.get("seed_base", 0)) > 0, "%d fixture must predeclare its deterministic seed block" % deck_id)


func _validate_policy_shape(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var policy := ProfilePolicyScript.new().sanitize(profile, StrategyScript.REGISTERED_ROUTE_IDS)
	var priorities: Array = policy.get("strategic_priorities", []) if policy.get("strategic_priorities", []) is Array else []
	_check(priorities.size() == 5, "%d all five strategic priorities must survive sanitization" % deck_id)
	for priority: Dictionary in priorities:
		_check(not (priority.get("when_all", []) as Array).is_empty(), "%d priority guard must remain registered" % deck_id)
		_check(not (priority.get("prefer_routes", []) as Array).is_empty(), "%d priority must retain an executable preferred route" % deck_id)
	var preferences: Dictionary = policy.get("route_preferences", {}) if policy.get("route_preferences", {}) is Dictionary else {}
	var biases: Dictionary = preferences.get("route_biases", {}) if preferences.get("route_biases", {}) is Dictionary else {}
	_check(float(preferences.get("model_consideration_margin", 0.0)) >= 320.0, "%d must expose the tuned model consideration window" % deck_id)
	_check(float(biases.get("route:attack_ko", 0.0)) >= 260.0, "%d must retain the KO route bias" % deck_id)
	_check(float(biases.get("route:end_turn", 0.0)) <= -220.0, "%d must retain the anti-idle bias" % deck_id)
	var expected_roles: Array = fixture.get("expected_protected_roles", []) if fixture.get("expected_protected_roles", []) is Array else []
	for raw_role: Variant in expected_roles:
		_check(str(raw_role) in (profile.get("protected_roles", []) as Array), "%d must protect role %s" % [deck_id, str(raw_role)])
	var encoded := JSON.stringify(profile)
	_check(not encoded.contains("FORBIDDEN_SECRET"), "%d profile must not carry hidden-zone sentinels" % deck_id)
	# A numeric opponent hand count is public game state.  Keep the older
	# hidden-zone substring guard after removing only the explicitly approved
	# profile key; card identities and deck order must still fail closed.
	var hidden_zone_encoded := encoded.replace("required_opponent_hand_count", "")
	_check(not hidden_zone_encoded.contains("opponent_hand") and not hidden_zone_encoded.contains("deck_order"), \
		"%d profile must remain public-information-only" % deck_id)


func _validate_module_parameters(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var modules: Array = profile.get("modules", []) if profile.get("modules", []) is Array else []
	var module_parameters: Dictionary = profile.get("module_parameters", {}) if profile.get("module_parameters", {}) is Dictionary else {}
	var expected_symbol := str(fixture.get("expected_energy_symbol", ""))
	var expected_attacker := str(fixture.get("expected_primary_attacker_uid", ""))
	var expected_generic_attacker := str(fixture.get("expected_generic_attachment_uid", expected_attacker))
	if "energy_burst" in modules:
		var burst: Dictionary = module_parameters.get("energy_burst", {}) if module_parameters.get("energy_burst", {}) is Dictionary else {}
		_check(expected_symbol in (burst.get("primary_attack_required_types", []) as Array), "%d energy_burst must retain typed energy %s" % [deck_id, expected_symbol])
		if expected_generic_attacker == "":
			_check((burst.get("primary_attacker_uids", []) as Array).is_empty(), "%d generic energy certificate must be disabled for multi-cost attackers" % deck_id)
		else:
			_check(expected_generic_attacker in (burst.get("primary_attacker_uids", []) as Array), "%d energy_burst must retain its exact one-step attacker" % deck_id)
	if "cycle_pivot" not in modules:
		return
	var cycle: Dictionary = module_parameters.get("cycle_pivot", {}) if module_parameters.get("cycle_pivot", {}) is Dictionary else {}
	_check(expected_symbol in (cycle.get("primary_required_energy", []) as Array), "%d cycle_pivot must retain typed energy %s" % [deck_id, expected_symbol])
	if expected_generic_attacker == "":
		_check((cycle.get("primary_attacker_uids", []) as Array).is_empty(), "%d cycle certificate must be disabled for multi-cost attackers" % deck_id)
	else:
		_check(expected_generic_attacker in (cycle.get("primary_attacker_uids", []) as Array), "%d cycle_pivot must retain its exact one-step attacker" % deck_id)
	_check(cycle.get("attacker_root_uids", []) == fixture.get("expected_attacker_root_uids", []), "%d cycle_pivot roots must match the fixture" % deck_id)
	_check(bool(cycle.get("block_optional_engine_when_attack_ready", false)), "%d cycle_pivot must stop optional draw after attack readiness" % deck_id)
	_check(bool(cycle.get("block_optional_engine_when_energy_attachment_open", false)), "%d cycle_pivot must preserve the open typed attachment" % deck_id)
	_check(bool(cycle.get("block_off_color_primary_attachment", false)), "%d cycle_pivot must block off-color primary attachment" % deck_id)
	if expected_generic_attacker != "":
		_validate_typed_attachment_annotation(deck_id, expected_generic_attacker, expected_symbol, profile)


func _validate_typed_attachment_annotation(deck_id: int, attacker_uid: String, energy_symbol: String, profile: Dictionary) -> void:
	var action_id := "attach:%d" % deck_id
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:%d" % deck_id,
		"route_id": "route:energy_commit",
		"safe_prefix_action_id": action_id,
		"action_kind": "attach_energy",
		"action_semantic_roles": ["typed_energy"],
	}]
	var observation := {
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": {"slot_id": "active", "pokemon": {"uid": attacker_uid}, "energy": []},
			"bench": [],
		},
		"opponent": {
			"active": {},
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"legal_actions": [{
			"id": action_id,
			"kind": "attach_energy",
			"target": "active",
			"card": {"uid": "basic_energy:%s" % energy_symbol, "energy_type": energy_symbol},
		}],
		"stadium": {},
	}
	var facts := {
		"attack": {"ready": false, "ko_available": false},
		"turn": {"energy_available": true},
		"resources": {"deck_low": false, "hand_size": 4},
		"board": {"bench_full": false},
	}
	var annotated := CyclePivotScript.new().annotate_frontier(frontier, observation, facts, profile)
	_check(annotated.size() == 1, "%d cycle_pivot must preserve the exact candidate" % deck_id)
	if annotated.is_empty():
		return
	var annotations: Dictionary = annotated[0].get("module_annotations", {}) if annotated[0].get("module_annotations", {}) is Dictionary else {}
	var cycle_annotation: Dictionary = annotations.get("cycle_pivot", {}) if annotations.get("cycle_pivot", {}) is Dictionary else {}
	var attachment: Dictionary = cycle_annotation.get("attachment", {}) if cycle_annotation.get("attachment", {}) is Dictionary else {}
	_check(str(attachment.get("energy_symbol", "")) == energy_symbol, "%d must canonicalize typed energy %s" % [deck_id, energy_symbol])
	_check(bool(attachment.get("target_is_primary_attacker", false)), "%d attachment must target the declared primary attacker" % deck_id)
	_check(bool(attachment.get("adds_missing_required_type", false)), "%d attachment must close a public typed-energy gap" % deck_id)
	_check(bool(attachment.get("completes_required_types", false)), "%d generic certificate fixture must complete the full declared cost" % deck_id)
	_check(not JSON.stringify(cycle_annotation).contains("FORBIDDEN_SECRET"), "%d module annotation must not copy hidden-zone sentinels" % deck_id)


func _validate_profiled_attack_cost_certificate(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var expected: Variant = fixture.get("expected_profiled_attack_cost", {})
	if not (expected is Dictionary) or (expected as Dictionary).is_empty():
		return
	var module_id := str((expected as Dictionary).get("module", ""))
	var attacker_uid := str((expected as Dictionary).get("uid", ""))
	var expected_cost: Array = (expected as Dictionary).get("cost", []) \
		if (expected as Dictionary).get("cost", []) is Array else []
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = module_parameters.get(module_id, {}) \
		if module_parameters.get(module_id, {}) is Dictionary else {}
	var cost_by_uid: Dictionary = parameters.get("attack_cost_by_uid", {}) \
		if parameters.get("attack_cost_by_uid", {}) is Dictionary else {}
	_check(cost_by_uid.get(attacker_uid, []) == expected_cost, "%d exact attack cost fixture must survive profile merge" % deck_id)
	if expected_cost.is_empty():
		return
	var final_required_symbol := str(expected_cost[expected_cost.size() - 1])
	var attached_symbol := "D" if final_required_symbol == "C" else final_required_symbol
	var pre_attached_energy: Array = []
	for index: int in maxi(0, expected_cost.size() - 1):
		var required_symbol := str(expected_cost[index])
		var paid_symbol := "D" if required_symbol == "C" else required_symbol
		pre_attached_energy.append({"type": "Basic Energy", "energy_type": paid_symbol})
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule:%d" % deck_id,
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "slot:utility", "card": {"energy_type": attached_symbol}},
		"base_score": 100.0,
	}, {
		"candidate_id": "candidate:profiled:%d" % deck_id,
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "slot:attacker", "card": {"energy_type": attached_symbol}},
		"base_score": 90.0,
	}]
	var observation := {
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": {"slot_id": "slot:attacker", "pokemon": {"uid": attacker_uid}, "energy": pre_attached_energy},
			"bench": [{"slot_id": "slot:utility", "pokemon": {"uid": "UTILITY"}, "energy": []}],
			"discard": [],
		},
		"opponent": {
			"active": {},
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
		},
	}
	var registry := CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(frontier, observation, {"turn": {"energy_available": true}}, profile, {})
	_check(annotated.size() == 2, "%d strategic module must preserve both exact candidates" % deck_id)
	if annotated.size() != 2:
		return
	var certificate := registry.verify_route_advantage(annotated[1], annotated[0], {"turn": {"energy_available": true}}, profile)
	_check(bool(certificate.get("verified", false)), "%d profiled attack-cost attachment must mint a public certificate" % deck_id)
	_check(str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion", "%d certificate kind must remain explicit" % deck_id)
	_check(str(certificate.get("module", "")) == module_id, "%d certificate must be owned by %s" % [deck_id, module_id])
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), "%d strategic annotation must not copy hidden-zone sentinels" % deck_id)
	if expected_cost.size() > 1:
		var partial_observation: Dictionary = observation.duplicate(true)
		var partial_own: Dictionary = partial_observation.get("own", {}) \
			if partial_observation.get("own", {}) is Dictionary else {}
		partial_own["active"] = {
			"slot_id": "slot:attacker",
			"pokemon": {"uid": attacker_uid},
			"energy": [],
		}
		partial_observation["own"] = partial_own
		var partial := registry.annotate_frontier(frontier, partial_observation, {"turn": {"energy_available": true}}, profile, {})
		_check(partial.size() == 2, "%d partial-cost fixture must preserve both candidates" % deck_id)
		if partial.size() == 2:
			var partial_certificate := registry.verify_route_advantage(partial[1], partial[0], {"turn": {"energy_available": true}}, profile)
			_check(not bool(partial_certificate.get("verified", false)), "%d merely advancing an incomplete multi-energy cost must not mint a certificate" % deck_id)


func _validate_energy_burst_mode(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var expected: Variant = fixture.get("expected_energy_burst", {})
	if not (expected is Dictionary) or (expected as Dictionary).is_empty():
		return
	var own_hand: Array = [
		{"uid": "energy:1", "type": "Basic Energy", "energy_type": "M"},
		{"uid": "energy:2", "type": "Basic Energy", "energy_type": "G"},
		{"uid": "energy:3", "type": "Basic Energy", "energy_type": "R"},
	]
	var bench: Array = [
		{"slot_id": "b1", "pokemon": {"uid": "P1"}, "energy": [{"type": "Basic Energy", "energy_type": "G"}]},
		{"slot_id": "b2", "pokemon": {"uid": "P2"}, "energy": [{"type": "Basic Energy", "energy_type": "G"}]},
		{"slot_id": "b3", "pokemon": {"uid": "P3"}, "energy": [{"type": "Basic Energy", "energy_type": "G"}]},
	]
	var observation := {
		"own": {"hand": own_hand, "active": {}, "bench": bench, "deck_count": 20},
		"opponent": {"active": {"slot_id": "oa", "remaining_hp": 200}, "bench": []},
	}
	var resource: Dictionary = EnergyBurstScript.new().damage_resource_snapshot(observation, profile, {}, 200)
	_check(str(resource.get("mode", "")) == str((expected as Dictionary).get("mode", "")), "%d burst mode must be explicit" % deck_id)
	_check(str(resource.get("resource_zone", "")) == str((expected as Dictionary).get("resource_zone", "")), "%d burst resource zone must match the real card text" % deck_id)
	_check(int(resource.get("raw_units", -1)) == int((expected as Dictionary).get("raw_units", -2)), "%d burst unit count must use the correct public zone" % deck_id)
	_check(int(resource.get("projected_public_damage", -1)) == int((expected as Dictionary).get("projected_public_damage", -2)), "%d burst damage projection must match the fixture" % deck_id)
	if str((expected as Dictionary).get("mode", "")) == "none":
		var annotation: Dictionary = EnergyBurstScript.new().route_annotation(
			{"route_id": "route:attack_ko", "macro_action": "attack_ko"},
			{},
			observation,
			{"attack": {"ready": true, "ko_available": true}},
			profile
		)
		_check(not bool(annotation.get("damage_math_enabled", true)), "%d non-burst deck must disable discard-damage math" % deck_id)
		_check(str(annotation.get("route_warning", "")) != "ko_breaks_next_turn_reserve", "%d non-burst deck must not receive a false reserve warning" % deck_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
