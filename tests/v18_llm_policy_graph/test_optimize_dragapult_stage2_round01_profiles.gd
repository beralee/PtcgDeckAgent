extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const ProfilePolicyScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGProfilePolicy.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")

const DECK_IDS: Array[int] = [
	18000230,
	18000625,
	800015734,
	800017047,
	800018499,
	800018501,
	800019125,
]
const FIXTURE_ROOT := "res://tests/v18_llm_policy_graph/fixtures/optimization21_dragapult_stage2"

var _failures: Array[String] = []


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for deck_id: int in DECK_IDS:
		var fixture := _load_fixture(deck_id)
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		_validate_profile_identity(deck_id, fixture, profile)
		_validate_policy_shape(deck_id, fixture, profile)
		_validate_parameter_contract(deck_id, fixture, profile)
		_validate_attack_cost_certificates(deck_id, fixture, profile)
		rows.append({
			"deck_id": deck_id,
			"evidence_kind": str(fixture.get("evidence_kind", "")),
			"profile_version": int(profile.get("profile_version", 0)),
			"profiled_attack_costs": (fixture.get("expected_profiled_attack_costs", []) as Array).size(),
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg/optimization21/dragapult_stage2"))
	var output := FileAccess.open(
		"res://tmp/v18cpg/optimization21/dragapult_stage2/round01_profile_fixtures.json",
		FileAccess.WRITE
	)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty():
		print("optimization21 dragapult/stage2 round01 profiles: PASS (7/7)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 dragapult/stage2 round01 profiles: FAIL (%d)" % _failures.size())
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
	_check(int(profile.get("deck_id", 0)) == deck_id, "%d immutable deck identity changed" % deck_id)
	_check(str(profile.get("strategy_id", "")).begins_with("v18cpg_%d_" % deck_id), "%d must remain V18CPG" % deck_id)
	_check(str(profile.get("base_strategy_id", "")).begins_with("v18_%d_" % deck_id), "%d exact Rule floor must remain bound" % deck_id)
	# This suite freezes the Round01 semantic floor, not later retained profile
	# revisions.  Deep-iteration decks may advance their profile version while
	# preserving every identity, module, budget, and parameter contract below.
	_check(int(profile.get("profile_version", 0)) >= 2, "%d profile_version must retain the Round01 floor" % deck_id)
	_check(int(profile.get("semantic_version", 0)) == 1, "%d semantic_version must remain 1" % deck_id)
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "%d wait budget must remain 6500ms" % deck_id)
	_check(int(profile.get("initial_response_token_budget", 0)) <= 420, "%d initial token budget regressed" % deck_id)
	_check(int(profile.get("delta_response_token_budget", 0)) <= 180, "%d delta token budget regressed" % deck_id)
	_check(int(profile.get("max_policy_nodes", 0)) <= 8, "%d policy graph node bound regressed" % deck_id)
	_check(profile.get("modules", []) == fixture.get("expected_modules", []), "%d module composition changed" % deck_id)
	_check(int(fixture.get("deck_id", 0)) == deck_id, "%d fixture identity mismatch" % deck_id)
	_check(int(fixture.get("seed_base", 0)) == deck_id, "%d deterministic seed base mismatch" % deck_id)
	_check(str(fixture.get("evidence_kind", "")) in ["real_model_round00", "prebenchmark_static"], "%d evidence kind must be explicit" % deck_id)
	_check(FileAccess.file_exists(str(fixture.get("derived_from", ""))), "%d declared evidence source must exist" % deck_id)


func _validate_policy_shape(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var policy := ProfilePolicyScript.new().sanitize(profile, StrategyScript.REGISTERED_ROUTE_IDS)
	var priorities: Array = policy.get("strategic_priorities", []) if policy.get("strategic_priorities", []) is Array else []
	_check(priorities.size() >= 5, "%d must retain at least five bounded priorities" % deck_id)
	for priority: Dictionary in priorities:
		_check(not (priority.get("when_all", []) as Array).is_empty(), "%d priority guard was sanitized away" % deck_id)
		_check(not (priority.get("prefer_routes", []) as Array).is_empty(), "%d priority lost executable routes" % deck_id)
	var preferences: Dictionary = policy.get("route_preferences", {}) if policy.get("route_preferences", {}) is Dictionary else {}
	var biases: Dictionary = preferences.get("route_biases", {}) if preferences.get("route_biases", {}) is Dictionary else {}
	_check(float(preferences.get("model_consideration_margin", 0.0)) >= 200.0, "%d tuned model window is missing" % deck_id)
	_check(float(biases.get("route:attack_ko", 0.0)) >= 300.0, "%d KO route bias is missing" % deck_id)
	_check(float(biases.get("route:end_turn", 0.0)) <= -180.0, "%d anti-idle route bias is missing" % deck_id)
	for raw_role: Variant in fixture.get("expected_protected_roles", []):
		_check(str(raw_role) in (profile.get("protected_roles", []) as Array), "%d must protect role %s" % [deck_id, str(raw_role)])
	var encoded := JSON.stringify(profile)
	_check(not encoded.contains("opponent_hand") and not encoded.contains("deck_order"), "%d profile must remain public-information-only" % deck_id)


func _validate_parameter_contract(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var expected_modules: Variant = fixture.get("expected_parameter_values", {})
	if not (expected_modules is Dictionary):
		_check(false, "%d expected_parameter_values must be a dictionary" % deck_id)
		return
	for raw_module_id: Variant in (expected_modules as Dictionary).keys():
		var module_id := str(raw_module_id)
		var actual: Variant = module_parameters.get(module_id, {})
		var expected: Variant = (expected_modules as Dictionary).get(raw_module_id)
		_check_subset(expected, actual, "%d module_parameters.%s" % [deck_id, module_id])


func _check_subset(expected: Variant, actual: Variant, path: String) -> void:
	if expected is Dictionary:
		if not (actual is Dictionary):
			_check(false, "%s must be a dictionary" % path)
			return
		for raw_key: Variant in (expected as Dictionary).keys():
			var key := str(raw_key)
			_check((actual as Dictionary).has(key), "%s.%s is missing" % [path, key])
			if (actual as Dictionary).has(key):
				_check_subset((expected as Dictionary).get(raw_key), (actual as Dictionary).get(key), "%s.%s" % [path, key])
		return
	_check(actual == expected, "%s changed: expected %s, got %s" % [path, str(expected), str(actual)])


func _validate_attack_cost_certificates(deck_id: int, fixture: Dictionary, profile: Dictionary) -> void:
	var expected_costs: Variant = fixture.get("expected_profiled_attack_costs", [])
	_check(expected_costs is Array and not (expected_costs as Array).is_empty(), "%d needs at least one exact public attack cost" % deck_id)
	if not (expected_costs is Array):
		return
	for raw_expected: Variant in expected_costs as Array:
		if not (raw_expected is Dictionary):
			_check(false, "%d attack cost fixture must be a dictionary" % deck_id)
			continue
		_validate_one_attack_cost(deck_id, raw_expected as Dictionary, profile)


func _validate_one_attack_cost(deck_id: int, expected: Dictionary, profile: Dictionary) -> void:
	var module_id := str(expected.get("module", ""))
	var attacker_uid := str(expected.get("uid", ""))
	var cost: Array = expected.get("cost", []) if expected.get("cost", []) is Array else []
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = module_parameters.get(module_id, {}) \
		if module_parameters.get(module_id, {}) is Dictionary else {}
	var cost_by_uid: Dictionary = parameters.get("attack_cost_by_uid", {}) \
		if parameters.get("attack_cost_by_uid", {}) is Dictionary else {}
	_check(cost_by_uid.get(attacker_uid, []) == cost, "%d %s exact cost did not survive profile merge" % [deck_id, attacker_uid])
	if cost.is_empty():
		return
	var pending_index := 0
	for index: int in cost.size():
		if str(cost[index]) != "C":
			pending_index = index
			break
	var pending_symbol := str(cost[pending_index])
	var attached_symbol := "D" if pending_symbol == "C" else pending_symbol
	var preattached_energy: Array[Dictionary] = []
	for index: int in cost.size():
		if index == pending_index:
			continue
		var existing_symbol := str(cost[index])
		# Colorless is paid by an ordinary typed energy in real games.
		if existing_symbol == "C":
			existing_symbol = "W"
		preattached_energy.append({
			"uid": "fixture_energy:%d:%s:%d" % [deck_id, attacker_uid, index],
			"energy_type": existing_symbol,
		})
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule:%d:%s" % [deck_id, attacker_uid],
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "slot:utility", "card": {"energy_type": attached_symbol}},
		"base_score": 100.0,
	}, {
		"candidate_id": "candidate:profiled:%d:%s" % [deck_id, attacker_uid],
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "slot:attacker", "card": {"energy_type": attached_symbol}},
		"base_score": 90.0,
	}]
	var observation := {
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": {"slot_id": "slot:attacker", "pokemon": {"uid": attacker_uid}, "energy": preattached_energy},
			"bench": [{"slot_id": "slot:utility", "pokemon": {"uid": "UTILITY"}, "energy": []}],
			"discard": [],
		},
		"opponent": {
			"active": {},
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"legal_actions": [],
		"stadium": {},
	}
	var facts := {
		"attack": {"ready": false, "ko_available": false},
		"turn": {"energy_available": true},
		"resources": {"deck_low": false},
	}
	var registry := CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(frontier, observation, facts, profile, {})
	_check(annotated.size() == 2, "%d %s annotation changed frontier cardinality" % [deck_id, attacker_uid])
	if annotated.size() != 2:
		return
	var certificate := registry.verify_route_advantage(annotated[1], annotated[0], facts, profile)
	_check(bool(certificate.get("verified", false)), "%d %s attachment must mint a public certificate" % [deck_id, attacker_uid])
	_check(str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion", "%d %s certificate kind changed" % [deck_id, attacker_uid])
	_check(str(certificate.get("module", "")) == module_id, "%d %s certificate owner must be %s" % [deck_id, attacker_uid, module_id])
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), "%d %s annotation leaked hidden-zone data" % [deck_id, attacker_uid])
	_validate_partial_cost_progress_not_certified(deck_id, attacker_uid, module_id, frontier, observation, facts, profile)
	_validate_off_cost_attachment_rejected(deck_id, attacker_uid, cost, frontier, observation, facts, profile)


func _validate_partial_cost_progress_not_certified(
	deck_id: int,
	attacker_uid: String,
	module_id: String,
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> void:
	var partial_observation := observation.duplicate(true)
	var own: Dictionary = partial_observation.get("own", {})
	var active: Dictionary = own.get("active", {})
	active["energy"] = []
	own["active"] = active
	partial_observation["own"] = own
	var registry := CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(frontier, partial_observation, facts, profile, {})
	_check(annotated.size() == 2, "%d %s partial-cost annotation changed frontier cardinality" % [deck_id, attacker_uid])
	if annotated.size() != 2:
		return
	var annotations: Dictionary = annotated[1].get("module_annotations", {}) \
		if annotated[1].get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(module_id, {}) \
		if annotations.get(module_id, {}) is Dictionary else {}
	var attachment: Dictionary = module_annotation.get("typed_attachment", {}) \
		if module_annotation.get("typed_attachment", {}) is Dictionary else {}
	_check(bool(attachment.get("adds_missing_required_type", false)), "%d %s partial attachment must record public progress" % [deck_id, attacker_uid])
	_check(not bool(attachment.get("completes_required_types", false)), "%d %s partial attachment must remain incomplete" % [deck_id, attacker_uid])
	var certificate := registry.verify_route_advantage(annotated[1], annotated[0], facts, profile)
	_check(not bool(certificate.get("verified", false)), "%d %s partial attack-cost progress must not mint a certificate" % [deck_id, attacker_uid])


func _validate_off_cost_attachment_rejected(
	deck_id: int,
	attacker_uid: String,
	cost: Array,
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> void:
	# Any typed energy legitimately pays a remaining Colorless symbol, so an
	# "off-color" negative case only exists for fully typed costs.
	if "C" in cost:
		return
	var off_symbol := "W"
	for candidate: String in ["W", "L", "P", "R", "F", "D", "M", "G"]:
		if candidate not in cost:
			off_symbol = candidate
			break
	var off_frontier := frontier.duplicate(true)
	(off_frontier[1] as Dictionary)["action_ref"] = {
		"target": "slot:attacker",
		"card": {"energy_type": off_symbol},
	}
	var registry := CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(off_frontier, observation, facts, profile, {})
	_check(annotated.size() == 2, "%d %s off-cost annotation changed frontier cardinality" % [deck_id, attacker_uid])
	if annotated.size() != 2:
		return
	var certificate := registry.verify_route_advantage(annotated[1], annotated[0], facts, profile)
	_check(not bool(certificate.get("verified", false)), "%d %s off-cost %s attachment must not be certified" % [deck_id, attacker_uid, off_symbol])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
