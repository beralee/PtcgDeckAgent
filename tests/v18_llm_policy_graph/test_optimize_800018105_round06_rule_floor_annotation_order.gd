extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 106
const PROVENANCE_TURN := 28
const RULE_ACTION_ID := "action:seed106-turn28-rule-munkidori"
const ATTACK_ACTION_ID := "action:seed106-turn28-direct-attack"
const RULE_CANDIDATE_ID := "candidate:897edde70ca6f855459b"
const ATTACK_CANDIDATE_ID := "candidate:52d364823d3080641269"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 8, "round06 production-order fix requires profile version 8")
	_test_production_annotation_order(profile)
	_test_missing_or_wrong_rule_floor_fails_closed(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round06 Rule-floor annotation order: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_production_annotation_order(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var raw := _raw_candidate_pool()
	_check(not raw[0].has("engine_rule_floor_exact"), "raw production candidates must not be pre-certified by the fixture")
	var annotated := strategy._annotate_candidate_pool_with_engine_rule_floor(
		raw,
		RULE_ACTION_ID,
		_observation(),
		_facts()
	)
	_check(annotated.size() == 2, "production annotation helper changed candidate count")
	_check(str(annotated[0].get("candidate_id", "")) == RULE_CANDIDATE_ID, "exact host Rule candidate must be promoted before annotation")
	_check(bool(annotated[0].get("engine_rule_floor_exact", false)), "exact host Rule candidate must be certified before capability annotation")
	_check(not bool(annotated[1].get("engine_rule_floor_exact", true)), "non-Rule candidate must remain uncertified")
	var exact_count := 0
	for candidate: Dictionary in annotated:
		if bool(candidate.get("engine_rule_floor_exact", false)):
			exact_count += 1
	_check(exact_count == 1, "production candidate pool must contain exactly one exact Rule floor")
	var prefix := _counter_prefix(annotated[0])
	_check(bool(prefix.get("preserves_secured_prize_suffix", false)), "production-ordered annotation must mint the ready-Munkidori public suffix")
	_check(str(prefix.get("prefix_stage", "")) == "move_counters", "production certificate prefix stage drifted")
	_check(str(prefix.get("source_slot_id", "")) == "slot:6", "production certificate source binding drifted")
	_check(str(prefix.get("opponent_target_slot_id", "")) == "slot:57", "production certificate target binding drifted")
	_check(int(prefix.get("transfer_points", 0)) == 20, "production certificate must bind the exact twenty-counter transfer")
	_check(bool(prefix.get("forced_sendout", false)), "production certificate must retain the forced-sendout boundary")
	_check(int(prefix.get("prizes_floor", 0)) == 2, "production certificate must retain the public two-prize floor")
	var compact := strategy._compact_frontier_for_model(annotated)
	_check(bool(compact[0].get("rule_floor_exact", false)), "compact model wire lost the exact Rule floor")
	_check(not _counter_prefix(compact[0]).is_empty(), "compact model wire lost the candidate-specific counter suffix")
	var safety := strategy._validate_model_route_safety(
		"route:attack_ko",
		annotated,
		_facts(),
		ATTACK_CANDIDATE_ID
	)
	_check(not bool(safety.get("valid", true)), "production safety must reject direct attack that truncates the Rule suffix")
	_check(str(safety.get("reason", "")) == "verified_rule_suffix_dominates_terminal_switch", "production rejection reason changed")
	_check(str(safety.get("advantage", {}).get("certificate_kind", "")) == "public_counter_mover_before_secured_ko", "production rejection lost its suffix certificate")


func _test_missing_or_wrong_rule_floor_fails_closed(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	for action_id: String in ["", "action:missing", ATTACK_ACTION_ID]:
		var annotated := strategy._annotate_candidate_pool_with_engine_rule_floor(
			_raw_candidate_pool(),
			action_id,
			_observation(),
			_facts()
		)
		var rule_candidate := _candidate_by_id(annotated, RULE_CANDIDATE_ID)
		_check(not bool(_counter_prefix(rule_candidate).get("preserves_secured_prize_suffix", false)), "%s must not mint a Rule suffix certificate" % ("missing Rule action" if action_id == "" else action_id))


func _raw_candidate_pool() -> Array[Dictionary]:
	# Deliberately keep the lower-scored direct attack first. The host Rule action
	# id, not fixture ordering or an injected boolean, must establish the floor.
	return [
		{
			"candidate_id": ATTACK_CANDIDATE_ID,
			"safe_prefix_action_id": ATTACK_ACTION_ID,
			"route_id": "route:attack_ko",
			"action_kind": "attack",
			"action_ref": {"source": "slot:6", "attack_index": 0, "projected_damage": 190, "projected_knockout": true},
			"base_score": 2657.08,
			"local_score": 2657.08,
			"outcome": {"prizes_now": 2, "win_now": false, "terminal": true},
		},
		{
			"candidate_id": RULE_CANDIDATE_ID,
			"safe_prefix_action_id": RULE_ACTION_ID,
			"route_id": "route:information",
			"action_kind": "use_ability",
			"action_ref": {"source": "slot:8", "ability_index": 0, "requires_interaction": true, "source_card": {"uid": "CSV8C_094"}},
			"base_score": 6456.28,
			"local_score": 6456.28,
			"outcome": {"information_gain": 0.2, "future_flexibility": 0.8},
		},
	]


func _observation() -> Dictionary:
	return {
		"observation_hash": "88b41f147e3d20477729462681e334cc3a329ca6a0d6655a7a5c585c9ac5b4ae",
		"turn": {"number": PROVENANCE_TURN, "current_player": 1, "viewer": 1, "first_player": 0, "deterministic_attack_window_open": true},
		"own": {
			"active": _slot("slot:6", "CSV2C_055", 210, 100, 310, [_energy("P"), _energy("P"), _energy("P")], false, 2),
			"bench": [
				_slot("slot:5", "CSV2C_055", 0, 310, 310, [], false, 2),
				_slot("slot:12", "151C_151", 0, 180, 180, [], false, 2),
				_slot("slot:11", "CSV10C_082", 0, 190, 190, [], false, 2),
				_slot("slot:8", "CSV8C_094", 0, 110, 110, [_energy("D")], false),
			],
			"prizes_remaining": 4,
			"deck_count": 14,
			"hand": [{"uid": "CSV7C_031", "type": "Pokemon"}],
		},
		"opponent": {
			"active": _opponent_slot("slot:57", "CSV6C_051", 210, 20, 2),
			"bench": [
				_opponent_slot("slot:58", "CSV6C_051", 0, 230, 2),
				_opponent_slot("slot:0", "CS6aC_057", 0, 120, 1),
				_opponent_slot("slot:1", "CS6.5C_020", 0, 130, 1),
				_opponent_slot("slot:34", "CS5aC_019", 240, 0, 2),
			],
			"prizes_remaining": 1,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": true, "max_damage": 190},
		"prize": {"win_now": false, "current_swing": 2},
		"resources": {"prizes_remaining": 4},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _slot(slot_id: String, uid: String, damage: int, remaining_hp: int, max_hp: int, energy: Array, ability_used: bool, prize_count: int = 1) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"damage": damage,
		"damage_counters": int(damage / 10),
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"ability_used": ability_used,
		"prize_count": prize_count,
	}


func _opponent_slot(slot_id: String, uid: String, damage: int, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"damage": damage,
		"remaining_hp": remaining_hp,
		"energy": [],
		"energy_count": 0,
		"ability_used": false,
		"prize_count": prize_count,
	}


func _energy(symbol: String) -> Dictionary:
	return {
		"uid": "CSVE1C_%s" % ("PSY" if symbol == "P" else "DAR"),
		"type": "Basic Energy",
		"energy_provides": symbol,
	}


func _candidate_by_id(frontier: Array[Dictionary], candidate_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func _counter_prefix(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var annotation: Dictionary = annotations.get("damage_counter_control", {}) \
		if annotations.get("damage_counter_control", {}) is Dictionary else {}
	return annotation.get("counter_mover_before_secured_ko", {}) \
		if annotation.get("counter_mover_before_secured_ko", {}) is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
