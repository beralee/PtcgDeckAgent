extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 106
const PROVENANCE_TURN := 28
const PROVENANCE_OBSERVATION_HASH := "88b41f147e3d20477729462681e334cc3a329ca6a0d6655a7a5c585c9ac5b4ae"
const RULE_ID := "candidate:897edde70ca6f855459b"
const ATTACK_ID := "candidate:52d364823d3080641269"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_test_exact_seed106_turn28(profile)
	_test_fail_closed_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round04 ready counter mover before secured KO: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_seed106_turn28(profile: Dictionary) -> void:
	_check(int(profile.get("profile_version", 0)) >= 6, "round04 certificate requires profile version 6 or newer")
	var facts := _facts()
	var annotated := _annotated(profile, _observation(), facts, _frontier())
	var prefix := _counter_prefix(annotated[0])
	_check(bool(prefix.get("preserves_secured_prize_suffix", false)), "ready Munkidori ability must preserve the public prize floor")
	_check(not bool(prefix.get("preserves_secured_ko", true)), "ability KO must not claim the pre-ability Active remains the attack target")
	_check(str(prefix.get("prefix_stage", "")) == "move_counters", "ready mover prefix stage changed")
	_check(str(prefix.get("target_slot_id", "")) == "slot:8", "Munkidori source slot drifted")
	_check(str(prefix.get("source_slot_id", "")) == "slot:6", "damaged Active Gardevoir must be the safe counter source")
	_check(str(prefix.get("source_uid", "")) == "CSV2C_055", "damage-invariant source UID changed")
	_check(int(prefix.get("attack_damage", 0)) == 190, "Gardevoir attack damage drifted")
	_check(int(prefix.get("opponent_active_hp", 0)) == 20, "Iron Hands public HP drifted")
	_check(str(prefix.get("opponent_target_slot_id", "")) == "slot:57", "unique counter target must remain the Active Iron Hands")
	_check(int(prefix.get("transfer_points", 0)) == 20, "allow-partial resolver must move exactly twenty damage")
	_check(bool(prefix.get("forced_sendout", false)), "counter KO must record the forced send-out boundary")
	_check(int(prefix.get("prizes_floor", 0)) == 2, "counter KO must bind the same two-prize floor")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(annotated[0], annotated[1], facts, profile)
	_check(str(certificate.get("certificate_kind", "")) == "public_counter_mover_before_secured_ko", "ready mover certificate changed")
	_check(str(certificate.get("interaction_owner", "")) == "rules_fallback", "Rule must retain source/target interaction ownership")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var safety := strategy._validate_model_route_safety("route:attack_ko", annotated, facts, ATTACK_ID)
	_check(not bool(safety.get("valid", true)), "direct attack must not discard the ready mover window")
	_check(str(safety.get("reason", "")) == "verified_rule_suffix_dominates_terminal_switch", "ready mover reverse-protection reason changed")
	_check(strategy._find_module_verified_upgrade(annotated, facts).is_empty(), "direct KO must not autonomously replace the exact Rule ability")
	var spent_quota := facts.duplicate(true)
	spent_quota["turn"]["energy_available"] = false
	var quota_annotated := _annotated(profile, _observation(), spent_quota, _frontier())
	_check(bool(_counter_prefix(quota_annotated[0]).get("preserves_secured_prize_suffix", false)), "ready ability must not depend on the attachment quota")
	var higher_prize_frontier := _frontier()
	higher_prize_frontier[1]["outcome"]["prizes_now"] = 3
	var higher_prize_annotated := _annotated(profile, _observation(), facts, higher_prize_frontier)
	var higher_prize_safety := strategy._validate_model_route_safety("route:attack_ko", higher_prize_annotated, facts, ATTACK_ID)
	_check(bool(higher_prize_safety.get("valid", false)), "a real higher-prize terminal must not be blocked by the Rule suffix floor")
	var win_frontier := _frontier()
	win_frontier[1]["outcome"]["win_now"] = true
	var win_annotated := _annotated(profile, _observation(), facts, win_frontier)
	var win_safety := strategy._validate_model_route_safety("route:attack_ko", win_annotated, facts, ATTACK_ID)
	_check(bool(win_safety.get("valid", false)), "a win-now alternative must not be blocked by a non-winning Rule suffix")


func _test_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var used := _observation()
	used["own"]["bench"][3]["ability_used"] = true
	cases.append({"label": "ability already used", "observation": used, "facts": _facts(), "frontier": _frontier()})
	var no_darkness := _observation()
	no_darkness["own"]["bench"][3]["energy"] = []
	cases.append({"label": "mover lacks Darkness", "observation": no_darkness, "facts": _facts(), "frontier": _frontier()})
	var no_source_damage := _observation()
	no_source_damage["own"]["active"]["damage"] = 10
	cases.append({"label": "source cannot pay exact twenty damage", "observation": no_source_damage, "facts": _facts(), "frontier": _frontier()})
	var no_replacement := _observation()
	no_replacement["opponent"]["bench"] = []
	cases.append({"label": "active counter KO has no live replacement", "observation": no_replacement, "facts": _facts(), "frontier": _frontier()})
	var ambiguous_target := _observation()
	ambiguous_target["opponent"]["bench"][1]["remaining_hp"] = 20
	cases.append({"label": "multiple counter KO targets", "observation": ambiguous_target, "facts": _facts(), "frontier": _frontier()})
	var wrong_source := _frontier()
	wrong_source[0]["action_ref"]["source_card"]["uid"] = "CSV2C_055"
	cases.append({"label": "ability source UID changed", "observation": _observation(), "facts": _facts(), "frontier": wrong_source})
	var missing_slot := _frontier()
	missing_slot[0]["action_ref"]["source"] = "slot:missing"
	cases.append({"label": "ability source slot missing", "observation": _observation(), "facts": _facts(), "frontier": missing_slot})
	var active_mover := _observation()
	active_mover["own"]["active"] = _slot("slot:8", "CSV8C_094", 0, 110, 110, [_energy("D")], false)
	active_mover["own"]["bench"][3] = _slot("slot:6", "CSV2C_055", 210, 100, 310, [_energy("P"), _energy("P"), _energy("P")], false, 2)
	cases.append({"label": "mover is Active", "observation": active_mover, "facts": _facts(), "frontier": _frontier()})
	var not_exact := _frontier()
	not_exact[0]["engine_rule_floor_exact"] = false
	cases.append({"label": "ability is not exact Rule floor", "observation": _observation(), "facts": _facts(), "frontier": not_exact})
	var no_ko := _facts()
	no_ko["attack"]["ko_available"] = false
	cases.append({"label": "KO not secured", "observation": _observation(), "facts": no_ko, "frontier": _frontier()})
	var insufficient := _facts()
	insufficient["attack"]["max_damage"] = 10
	cases.append({"label": "damage below public HP", "observation": _observation(), "facts": insufficient, "frontier": _frontier()})
	var final_win := _facts()
	final_win["prize"]["win_now"] = true
	cases.append({"label": "attack wins immediately", "observation": _observation(), "facts": final_win, "frontier": _frontier()})
	for invalid: Dictionary in cases:
		var annotated := _annotated(profile, invalid.get("observation", {}), invalid.get("facts", {}), invalid.get("frontier", []))
		var prefix := _counter_prefix(annotated[0]) if not annotated.is_empty() else {}
		_check(not bool(prefix.get("preserves_secured_ko", false)), "%s must fail closed" % str(invalid.get("label", "invalid")))


func _annotated(profile: Dictionary, observation: Dictionary, facts: Dictionary, frontier: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary:
			typed.append(raw_candidate as Dictionary)
	return CapabilityRegistryScript.new().annotate_frontier(typed, observation, facts, profile, {})


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": RULE_ID,
			"route_id": "route:information",
			"action_kind": "use_ability",
			"action_ref": {"source": "slot:8", "ability_index": 0, "requires_interaction": true, "source_card": {"uid": "CSV8C_094"}},
			"base_score": 6456.28,
			"local_score": 6456.28,
			"engine_rule_floor_exact": true,
			"outcome": {"information_gain": 0.2, "future_flexibility": 0.8},
		},
		{
			"candidate_id": ATTACK_ID,
			"route_id": "route:attack_ko",
			"action_kind": "attack",
			"action_ref": {"source": "slot:6", "attack_index": 0, "projected_damage": 190, "projected_knockout": true},
			"base_score": 2657.08,
			"local_score": 2657.08,
			"engine_rule_floor_exact": false,
			"outcome": {"prizes_now": 2, "win_now": false, "terminal": true},
		},
	]


func _observation() -> Dictionary:
	return {
		"observation_hash": PROVENANCE_OBSERVATION_HASH,
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
			"active": _opponent_slot("slot:57", "CSV6C_051", 210, 20, 2, [_energy("L"), _energy("L"), _energy("L"), _special_energy()]),
			"bench": [
				_opponent_slot("slot:58", "CSV6C_051", 0, 230, 2, [_energy("L"), _energy("L"), _energy("L"), _special_energy()]),
				_opponent_slot("slot:0", "CS6aC_057", 0, 120, 1, []),
				_opponent_slot("slot:1", "CS6.5C_020", 0, 130, 1, []),
				_opponent_slot("slot:34", "CS5aC_019", 240, 0, 2, []),
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


func _opponent_slot(slot_id: String, uid: String, damage: int, remaining_hp: int, prize_count: int, energy: Array) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"damage": damage,
		"remaining_hp": remaining_hp,
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"ability_used": false,
		"prize_count": prize_count,
	}


func _energy(symbol: String) -> Dictionary:
	return {
		"uid": "CSVE1C_%s" % ("PSY" if symbol == "P" else "LIG" if symbol == "L" else "DAR"),
		"type": "Basic Energy",
		"energy_provides": symbol,
	}


func _special_energy() -> Dictionary:
	return {"uid": "CSNC_024", "type": "Special Energy"}


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
