extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 107
const PROVENANCE_TURN := 27
const PROVENANCE_OBSERVATION_HASH := "42373c78"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 9, "round07 fail-closed boundary requires profile version 9")
	_test_exact_false_closeout_shape(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round07 unbound Embrace fail-closed: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_false_closeout_shape(profile: Dictionary) -> void:
	var registry := CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(
		_frontier(),
		_observation(),
		_facts(),
		profile,
		{}
	)
	var attack: Dictionary = annotated[0]
	var embrace: Dictionary = annotated[1]
	var projection := _embrace_projection(embrace)
	_check(int(projection.get("required_assignments", 0)) == 2, "faithful replay shape must require two future Embrace assignments")
	_check(int(projection.get("projected_damage", 0)) == 180, "diagnostic multi-action projection drifted")
	_check(bool(projection.get("diagnostic_projected_future_sequence", false)), "future-sequence arithmetic should remain available for diagnosis")
	_check(not bool(projection.get("wins_now_after_public_embrace_sequence", true)), "one current ability must not claim a multi-action win")
	_check(not bool(projection.get("certificate_authorized", true)), "unbound interaction target must revoke certificate authority")
	var embrace_module := _module_annotation(embrace)
	_check(not bool(embrace_module.get("verified_advantage", false)), "diagnostic projection must not be advertised as a verified advantage")
	_check(str(embrace_module.get("route_warning", "")) == "unbound_future_embrace_sequence_is_diagnostic_only", "model wire must expose the fail-closed warning")
	var certificate := registry.verify_route_advantage(embrace, attack, _facts(), profile)
	_check(not bool(certificate.get("verified", false)), "unbound repeated Embrace must not mint a capability certificate")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	_check(strategy._find_module_verified_upgrade(annotated, _facts()).is_empty(), "unbound repeated Embrace must not autonomously postpone the legal attack")
	var compact := strategy._compact_frontier_for_model(annotated)
	var compact_embrace := _candidate_by_id(compact, "candidate:embrace")
	var compact_projection := _embrace_projection(compact_embrace)
	_check(not bool(compact_projection.get("wins_now_after_public_embrace_sequence", false)), "compact payload must not revive the revoked win claim")
	_check(str(_module_annotation(compact_embrace).get("route_warning", "")) == "unbound_future_embrace_sequence_is_diagnostic_only", "compact payload lost the fail-closed warning")


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:attack",
			"route_id": "route:attack_pressure",
			"safe_prefix_action_id": "action:attack:-:9:-:1:-1",
			"action_kind": "attack",
			"action_ref": {"source": "slot:9", "attack_index": 1, "projected_damage": 60, "projected_knockout": false},
			"action_semantic_roles": ["attacker"],
			"base_score": 665.52,
			"local_score": 665.52,
			"engine_rule_floor_exact": true,
			"outcome": {"win_now": false, "prizes_now": 0, "terminal": true},
		},
		{
			"candidate_id": "candidate:embrace",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:use_ability:-:5:-:-1:0",
			"action_kind": "use_ability",
			"action_ref": {"source": "slot:5", "ability_index": 0, "source_card": {"uid": "CSV2C_055"}, "requires_interaction": true},
			"action_semantic_roles": ["ability_engine", "energy_accelerator"],
			"base_score": 539.4,
			"local_score": 539.4,
			"engine_rule_floor_exact": false,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _observation() -> Dictionary:
	return {
		"observation_hash": PROVENANCE_OBSERVATION_HASH,
		"turn": {"number": PROVENANCE_TURN, "current_player": 0, "viewer": 0, "first_player": 1, "deterministic_attack_window_open": true},
		"own": {
			"prizes_remaining": 1,
			"deck_count": 10,
			"discard": [_energy("discard:0"), _energy("discard:1")],
			# Production Gateway reports base HP here; Bravery Charm is a separate
			# public field. The revoked proof must stay closed on this exact shape.
			"active": _slot("slot:9", "CSV2C_060", 20, 50, 70, [_energy("attached:0"), _energy("attached:1")], "CSV1C_118", 1),
			"bench": [_slot("slot:5", "CSV2C_055", 0, 310, 310, [], "", 2)],
			"hand": [],
		},
		"opponent": {
			"prizes_remaining": 3,
			"deck_count": 12,
			"active": _slot("slot:58", "CSV6C_051", 60, 170, 230, [], "", 2),
			"bench": [],
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": false, "max_damage": 60},
		"prize": {"win_now": false, "current_swing": 0},
		"resources": {"prizes_remaining": 1, "deck_low": false},
		"turn": {"energy_available": false, "supporter_available": false},
	}


func _slot(slot_id: String, uid: String, damage: int, remaining_hp: int, max_hp: int, energy: Array, tool_uid: String, prize_count: int) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {"uid": tool_uid} if tool_uid != "" else {},
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"damage": damage,
		"damage_counters": int(damage / 10),
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"ability_used": false,
		"prize_count": prize_count,
	}


func _energy(uid_suffix: String) -> Dictionary:
	return {"uid": "energy:%s" % uid_suffix, "type": "Basic Energy", "energy_type": "P", "energy_provides": "P"}


func _candidate_by_id(frontier: Array[Dictionary], candidate_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func _module_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get("gardevoir_embrace", {}) \
		if annotations.get("gardevoir_embrace", {}) is Dictionary else {}


func _embrace_projection(candidate: Dictionary) -> Dictionary:
	var annotation := _module_annotation(candidate)
	return annotation.get("prize_scaler_embrace", {}) \
		if annotation.get("prize_scaler_embrace", {}) is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
