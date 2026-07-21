extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 5, "round05 closeout contract must remain present in later profiles")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "closeout repair must not add model latency")
	_test_recovery_and_tutor_are_distinct_routes()
	_test_post_evolve_tutor_safety_boundary(profile)
	_test_public_charm_closeout_certificate(profile)
	_test_repeated_embrace_closeout_certificate(profile)
	if _failures.is_empty():
		print("optimization21 800018498 round05 closeout: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_recovery_and_tutor_are_distinct_routes() -> void:
	var compiler := SemanticCompilerScript.new()
	_check(
		"trainer_tutor" in compiler.roles_for_card_ref({"name": "Arven", "type": "Supporter"}, {}),
		"Arven must compile to a typed trainer-tutor role"
	)
	_check(
		"hp_expansion_tool" in compiler.roles_for_card_ref({"name": "Bravery Charm", "type": "Tool"}, {}),
		"Bravery Charm must compile to a typed HP-expansion role"
	)
	var observation := {
		"own": {"prizes_remaining": 2},
		"opponent": {"active": {"prize_count": 2}},
		"legal_actions": [
			{"id": "action:night", "kind": "play_trainer", "card": {"uid": "CSV8C_183", "name": "Night Stretcher", "type": "Item"}},
			{"id": "action:arven", "kind": "play_trainer", "card": {"uid": "CSV1C_123", "name": "Arven", "type": "Supporter"}},
			{"id": "action:research", "kind": "play_trainer", "card": {"uid": "CSV1C_121", "name": "Professor's Research", "type": "Supporter"}},
		],
	}
	var manifest := {"cards": [
		{"uid": "CSV8C_183", "roles": ["item", "recovery"]},
		{"uid": "CSV1C_123", "roles": ["supporter", "trainer_tutor"]},
		{"uid": "CSV1C_121", "roles": ["supporter", "draw_engine"]},
	]}
	var frontier: Array[Dictionary] = RouteSearchScript.new().build_frontier(
		observation,
		{"action:night": 5630.4, "action:arven": 330.0, "action:research": 495.6},
		manifest,
		{"resources": {"prizes_remaining": 2}},
		10
	)
	var routes: Array[String] = []
	for candidate: Dictionary in frontier:
		routes.append(str(candidate.get("route_id", "")))
	_check("route:recover" in routes, "public-discard recovery must stay visible as route:recover")
	_check("route:tutor" in routes, "Arven must stay visible as route:tutor despite a much higher Rule recovery score")
	_check("route:information" in routes, "generic draw must remain a separate information route")


func _test_public_charm_closeout_certificate(profile: Dictionary) -> void:
	var frontier: Array[Dictionary] = [
		{
			"candidate_id": "candidate:evolve",
			"route_id": "route:evolve",
			"safe_prefix_action_id": "action:evolve",
			"action_kind": "evolve",
			"action_ref": {"kind": "evolve"},
			"action_semantic_roles": ["evolution_piece"],
			"base_score": 4580.0,
			"local_score": 4580.0,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:charm",
			"route_id": "route:develop",
			"safe_prefix_action_id": "action:charm",
			"action_kind": "attach_tool",
			"action_ref": {
				"kind": "attach_tool",
				"card": {"uid": "CSV1C_118", "name": "Bravery Charm", "type": "Tool"},
				"target": "slot:active",
			},
			"action_semantic_roles": ["item", "hp_expansion_tool"],
			"base_score": -4600.0,
			"local_score": -4600.0,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	var observation := {
		"own": {
			"prizes_remaining": 2,
			"deck_count": 18,
			"discard": [
				{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"},
				{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"},
				{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"},
				{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"},
				{"uid": "CSV2C_053", "type": "Pokemon", "energy_type": "P"},
				{"uid": "CSV8C_094", "type": "Pokemon", "energy_type": "P"},
			],
			"active": {
				"slot_id": "slot:active",
				"pokemon": {"uid": "CSV2C_060"},
				"energy": [],
				"damage": 0,
				"remaining_hp": 70,
				"max_hp": 70,
				"prize_count": 1,
			},
			"bench": [{
				"slot_id": "slot:engine",
				"pokemon": {"uid": "CSV2C_055"},
				"energy": [],
				"damage": 0,
				"remaining_hp": 310,
				"max_hp": 310,
				"prize_count": 2,
			}],
		},
		"opponent": {
			"deck_count": 12,
			"active": {
				"slot_id": "slot:iron_hands",
				"pokemon": {"uid": "CSV6C_051"},
				"energy": [],
				"damage": 0,
				"remaining_hp": 230,
				"max_hp": 230,
				"prize_count": 2,
			},
			"bench": [],
		},
	}
	var facts := {
		"attack": {"ready": false, "ko_available": false},
		"resources": {"prizes_remaining": 2, "deck_low": false},
	}
	var registry := CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(frontier, observation, facts, profile, {})
	var charm: Dictionary = annotated[1]
	var certificate: Dictionary = charm.get("module_annotations", {}).get("gardevoir_embrace", {}).get("prize_scaler_tool", {})
	_check(int(certificate.get("psychic_fuel", -1)) == 4, "Psychic Pokemon in discard must not inflate the four Basic Psychic Energy fuel count")
	_check(int(certificate.get("required_assignments", 0)) == 4, "230 HP must require four public Embrace assignments for Drifloon")
	_check(int(certificate.get("projected_damage", 0)) == 240, "four assignments must project exactly 240 Drifloon damage")
	_check(not bool(certificate.get("safe_without_tool", true)), "untooled 70 HP Drifloon must not survive four assignments")
	_check(bool(certificate.get("safe_with_tool", false)), "Bravery Charm Drifloon must survive four assignments")
	_check(bool(certificate.get("wins_now_after_public_embrace_sequence", false)), "the public sequence must be certified as a two-prize win-now closeout")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "candidate:charm", "zero-latency local gate must select the certified Charm closeout")
	_check(
		str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "public_prize_scaler_tool_closeout",
		"closeout must carry the exact deterministic certificate kind"
	)
	strategy._select_route("route:develop", annotated, "module_verified_upgrade", "candidate:charm")
	_check(
		str(strategy.get("_active_module_certificate_kind")) == "public_prize_scaler_tool_closeout",
		"selected Charm action must retain its auditable certificate kind"
	)


func _test_post_evolve_tutor_safety_boundary(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var frontier: Array[Dictionary] = [
		_candidate("candidate:embrace", "route:information", "use_ability", 539.4),
		_candidate("candidate:arven", "route:tutor", "play_trainer", 285.6),
		_candidate("candidate:research", "route:information", "play_trainer", 125.6),
	]
	var arven := strategy._validate_model_route_safety(
		"route:tutor", frontier, {"resources": {"deck_low": false}}, "candidate:arven"
	)
	_check(
		bool(arven.get("valid", false)) and float(arven.get("score_gap", 999.0)) <= 225.0,
		"after Gardevoir evolves, the profiled Arven continuation must fit the unchanged 225 margin"
	)
	var research := strategy._validate_model_route_safety(
		"route:information", frontier, {"resources": {"deck_low": false}}, "candidate:research"
	)
	_check(
		not bool(research.get("valid", true)) \
			and str(research.get("reason", "")) in ["same_route_switch_without_verified_advantage", "model_route_below_switch_margin"],
		"the same boundary must still block the much weaker Research commitment"
	)


func _test_repeated_embrace_closeout_certificate(profile: Dictionary) -> void:
	for stage: Dictionary in [
		{"damage": 40, "energy": 2, "fuel": 2, "expected_remaining": 2},
		{"damage": 60, "energy": 3, "fuel": 1, "expected_remaining": 1},
	]:
		var frontier := _embrace_frontier(false)
		var observation := _embrace_observation(
			int(stage.get("damage", 0)),
			int(stage.get("energy", 0)),
			int(stage.get("fuel", 0)),
			true
		)
		var facts := {
			"attack": {"ready": true, "ko_available": false},
			"resources": {"prizes_remaining": 2, "deck_low": false},
		}
		var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
		var embrace: Dictionary = annotated[1]
		var certificate: Dictionary = embrace.get("module_annotations", {}).get("gardevoir_embrace", {}).get("prize_scaler_embrace", {})
		_check(
			int(certificate.get("required_assignments", 0)) == int(stage.get("expected_remaining", -1)),
			"the certificate must track the exact remaining Embrace count at damage %d" % int(stage.get("damage", 0))
		)
		_check(bool(certificate.get("diagnostic_projected_future_sequence", false)), "the diagnostic projection must retain the remaining public Embrace count")
		_check(not bool(certificate.get("wins_now_after_public_embrace_sequence", true)), "an unbound future sequence must not claim current-action win authority")
		_check(not bool(certificate.get("certificate_authorized", true)), "an unbound future sequence must remain diagnostic-only")
		var strategy := StrategyScript.new()
		strategy.configure_profile(profile)
		var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
		_check(upgrade.is_empty(), "diagnostic repeated Embrace must not override a currently legal attack")

	var ko_frontier := _embrace_frontier(true)
	var ko_observation := _embrace_observation(80, 4, 0, true)
	var ko_facts := {
		"attack": {"ready": true, "ko_available": true},
		"resources": {"prizes_remaining": 2, "deck_low": false},
	}
	var ko_annotated := CapabilityRegistryScript.new().annotate_frontier(ko_frontier, ko_observation, ko_facts, profile, {})
	var ko_strategy := StrategyScript.new()
	ko_strategy.configure_profile(profile)
	_check(
		ko_strategy._find_module_verified_upgrade(ko_annotated, ko_facts).is_empty(),
		"once 240 KO is live, the certificate must stop and preserve the terminal attack"
	)

	for invalid: Dictionary in [
		{"label": "no Charm", "observation": _embrace_observation(40, 2, 2, false), "source_uid": "CSV2C_055"},
		{"label": "insufficient Basic Psychic fuel", "observation": _embrace_observation(40, 2, 1, true), "source_uid": "CSV2C_055"},
		{"label": "wrong ability source", "observation": _embrace_observation(40, 2, 2, true), "source_uid": "CS6.5C_030"},
	]:
		var invalid_frontier := _embrace_frontier(false, str(invalid.get("source_uid", "")))
		var invalid_annotated := CapabilityRegistryScript.new().annotate_frontier(
			invalid_frontier,
			invalid.get("observation", {}),
			{"attack": {"ready": true, "ko_available": false}, "resources": {"prizes_remaining": 2}},
			profile,
			{}
		)
		var invalid_certificate: Dictionary = invalid_annotated[1].get("module_annotations", {}).get("gardevoir_embrace", {}).get("prize_scaler_embrace", {})
		_check(
			not bool(invalid_certificate.get("wins_now_after_public_embrace_sequence", false)),
			"%s must not mint an Embrace closeout certificate" % str(invalid.get("label", "invalid state"))
		)


func _embrace_frontier(ko_ready: bool, source_uid: String = "CSV2C_055") -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:attack",
			"route_id": "route:attack_ko" if ko_ready else "route:attack_pressure",
			"safe_prefix_action_id": "action:attack",
			"action_kind": "attack",
			"action_ref": {"kind": "attack", "projected_damage": 240 if ko_ready else 120, "projected_knockout": ko_ready},
			"action_semantic_roles": ["attacker"],
			"base_score": 9155.0 if ko_ready else 8175.52,
			"local_score": 9155.0 if ko_ready else 8175.52,
			"outcome": {"win_now": ko_ready, "prizes_now": 2 if ko_ready else 0},
		},
		{
			"candidate_id": "candidate:embrace",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:embrace",
			"action_kind": "use_ability",
			"action_ref": {
				"kind": "use_ability",
				"source": "slot:engine",
				"source_card": {"uid": source_uid},
			},
			"action_semantic_roles": ["ability_engine"],
			"base_score": 799.4,
			"local_score": 799.4,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _embrace_observation(damage: int, energy_count: int, fuel: int, has_charm: bool) -> Dictionary:
	var attached: Array[Dictionary] = []
	for index: int in energy_count:
		attached.append({"uid": "energy:attached:%d" % index, "type": "Basic Energy", "energy_type": "P"})
	var discard: Array[Dictionary] = []
	for index: int in fuel:
		discard.append({"uid": "energy:discard:%d" % index, "type": "Basic Energy", "energy_type": "P"})
	return {
		"own": {
			"prizes_remaining": 2,
			"deck_count": 18,
			"discard": discard,
			"active": {
				"slot_id": "slot:active",
				"pokemon": {"uid": "CSV2C_060"},
				"tool": {"uid": "CSV1C_118"} if has_charm else {},
				"energy": attached,
				"damage": damage,
				"remaining_hp": 120 - damage if has_charm else 70 - damage,
				"max_hp": 120 if has_charm else 70,
				"prize_count": 1,
			},
			"bench": [{
				"slot_id": "slot:engine",
				"pokemon": {"uid": "CSV2C_055"},
				"tool": {},
				"energy": [],
				"damage": 0,
				"remaining_hp": 310,
				"max_hp": 310,
				"prize_count": 2,
			}],
		},
		"opponent": {
			"deck_count": 12,
			"active": {
				"slot_id": "slot:iron_hands",
				"pokemon": {"uid": "CSV6C_051"},
				"tool": {},
				"energy": [],
				"damage": 0,
				"remaining_hp": 230,
				"max_hp": 230,
				"prize_count": 2,
			},
			"bench": [],
		},
	}


func _candidate(candidate_id: String, route_id: String, action_kind: String, base_score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"action_kind": action_kind,
		"base_score": base_score,
		"local_score": base_score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
