extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018543
const PROVENANCE_SEED := 800018543
const PROVENANCE_TURN := 21
const PROVENANCE_OBSERVATION_HASH := "6c9a53af6f59f1f19c887cea0306776694f5cceca1e67ae3d71d4243a2f75480"
const RULE_CANDIDATE_ID := "candidate:c939e45d6ddf01a9d7a2"
const ATTACK_CANDIDATE_ID := "candidate:52d364823d3080641269"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_test_exact_round02_seed543_turn21(profile)
	_test_fail_closed_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018543 round03 Munkidori before secured KO: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_round02_seed543_turn21(profile: Dictionary) -> void:
	_check(int(profile.get("profile_version", 0)) >= 4, "round03 certificate requires profile version 4 or newer")
	_check("damage_counter_control" in profile.get("modules", []), "Cynthia profile must compose damage-counter control")
	var facts := _facts()
	var annotated := _annotated(profile, _observation(), facts, _frontier())
	var prefix := _counter_prefix(annotated[0])
	_check(bool(prefix.get("preserves_secured_prize_suffix", false)), "exact Rule Munkidori must preserve the public prize suffix")
	_check(bool(prefix.get("preserves_secured_ko", false)), "non-KO counter transfer must leave the same Active KO secured")
	_check(str(prefix.get("prefix_stage", "")) == "move_counters", "ready mover prefix stage changed")
	_check(str(prefix.get("target_slot_id", "")) == "slot:16", "Munkidori ability source slot drifted")
	_check(str(prefix.get("source_slot_id", "")) == "slot:6", "damaged Active Garchomp must remain the counter source")
	_check(str(prefix.get("source_uid", "")) == "CSV10C_113", "damage-invariant source UID changed")
	_check(int(prefix.get("transfer_points", 0)) == 30, "full Adrena-Brain transfer must remain thirty damage")
	_check(not bool(prefix.get("forced_sendout", true)), "non-KO transfer must not invent a forced send-out")
	_check(str(prefix.get("opponent_target_scope", "")) == "any_public_live_slot", "Rule interaction must retain target ownership over the public live board")
	_check(int(prefix.get("attack_damage", 0)) == 200, "Cynthia Garchomp attack damage drifted")
	_check(int(prefix.get("opponent_active_hp", 0)) == 120, "Zapdos public HP drifted")
	_check(int(prefix.get("prizes_floor", 0)) == 1, "same-turn attack must bind the one-prize floor")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(annotated[0], annotated[1], facts, profile)
	_check(str(certificate.get("certificate_kind", "")) == "public_counter_mover_before_secured_ko", "public suffix certificate changed")
	_check(str(certificate.get("interaction_owner", "")) == "rules_fallback", "Rule must retain counter source/target interaction ownership")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var safety := strategy._validate_model_route_safety(
		"route:attack_ko", annotated, facts, ATTACK_CANDIDATE_ID
	)
	_check(not bool(safety.get("valid", true)), "direct attack must not truncate the exact Rule ability prefix")
	_check(str(safety.get("reason", "")) == "verified_rule_suffix_dominates_terminal_switch", "reverse Rule-prefix protection reason changed")
	_check(str(safety.get("advantage", {}).get("certificate_kind", "")) == "public_counter_mover_before_secured_ko", "rejection lost its suffix certificate")
	_check(strategy._find_module_verified_upgrade(annotated, facts).is_empty(), "direct attack must not autonomously replace the exact Rule ability")
	var higher_prize := _frontier()
	higher_prize[1]["outcome"]["prizes_now"] = 2
	var higher_annotated := _annotated(profile, _observation(), facts, higher_prize)
	var higher_safety := strategy._validate_model_route_safety(
		"route:attack_ko", higher_annotated, facts, ATTACK_CANDIDATE_ID
	)
	_check(bool(higher_safety.get("valid", false)), "a real higher-prize terminal must remain admissible")


func _test_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var ability_used := _observation()
	ability_used["own"]["bench"][2]["ability_used"] = true
	cases.append({"label": "ability already used", "observation": ability_used, "facts": _facts(), "frontier": _frontier()})
	var no_darkness := _observation()
	no_darkness["own"]["bench"][2]["energy"] = []
	cases.append({"label": "mover lacks Darkness", "observation": no_darkness, "facts": _facts(), "frontier": _frontier()})
	var no_source_damage := _observation()
	no_source_damage["own"]["active"]["damage"] = 20
	cases.append({"label": "source cannot transfer thirty", "observation": no_source_damage, "facts": _facts(), "frontier": _frontier()})
	var ambiguous_source := _observation()
	ambiguous_source["own"]["bench"][1]["damage"] = 30
	cases.append({"label": "damaged non-invariant source", "observation": ambiguous_source, "facts": _facts(), "frontier": _frontier()})
	var wrong_ability := _frontier()
	wrong_ability[0]["action_ref"]["ability_index"] = 1
	cases.append({"label": "ability index changed", "observation": _observation(), "facts": _facts(), "frontier": wrong_ability})
	var no_interaction_owner := _frontier()
	no_interaction_owner[0]["action_ref"]["requires_interaction"] = false
	cases.append({"label": "ability interaction ownership missing", "observation": _observation(), "facts": _facts(), "frontier": no_interaction_owner})
	var wrong_uid := _frontier()
	wrong_uid[0]["action_ref"]["source_card"]["uid"] = "CSV10C_113"
	cases.append({"label": "ability source UID changed", "observation": _observation(), "facts": _facts(), "frontier": wrong_uid})
	var not_exact := _frontier()
	not_exact[0]["engine_rule_floor_exact"] = false
	cases.append({"label": "ability is not exact Rule floor", "observation": _observation(), "facts": _facts(), "frontier": not_exact})
	var no_ko := _facts()
	no_ko["attack"]["ko_available"] = false
	cases.append({"label": "attack KO not secured", "observation": _observation(), "facts": no_ko, "frontier": _frontier()})
	var win_now := _facts()
	win_now["prize"]["win_now"] = true
	cases.append({"label": "attack already wins now", "observation": _observation(), "facts": win_now, "frontier": _frontier()})
	var counter_ko_target := _observation()
	counter_ko_target["opponent"]["bench"][0]["remaining_hp"] = 20
	counter_ko_target["opponent"]["bench"][0]["damage"] = 200
	cases.append({"label": "counter transfer can cross a KO boundary", "observation": counter_ko_target, "facts": _facts(), "frontier": _frontier()})
	for invalid: Dictionary in cases:
		var annotated := _annotated(
			profile,
			invalid.get("observation", {}),
			invalid.get("facts", {}),
			invalid.get("frontier", [])
		)
		var prefix := _counter_prefix(annotated[0]) if not annotated.is_empty() else {}
		_check(not bool(prefix.get("preserves_secured_prize_suffix", false)), "%s must fail closed" % str(invalid.get("label", "invalid")))


func _annotated(profile: Dictionary, observation: Dictionary, facts: Dictionary, raw_frontier: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for raw_candidate: Variant in raw_frontier:
		if raw_candidate is Dictionary:
			typed.append(raw_candidate as Dictionary)
	return CapabilityRegistryScript.new().annotate_frontier(typed, observation, facts, profile, {})


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": RULE_CANDIDATE_ID,
			"route_id": "route:information",
			"action_kind": "use_ability",
			"action_ref": {
				"source": "slot:16",
				"ability_index": 0,
				"requires_interaction": true,
				"source_card": {"uid": "CSV8C_094", "type": "Pokemon"},
			},
			"base_score": 4276.28,
			"local_score": 4276.28,
			"checkpoint_after": "information_result",
			"engine_rule_floor_exact": true,
			"outcome": {"information_gain": 0.2, "future_flexibility": 0.8},
		},
		{
			"candidate_id": ATTACK_CANDIDATE_ID,
			"route_id": "route:attack_ko",
			"action_kind": "attack",
			"action_ref": {
				"source": "slot:6",
				"attack_index": 0,
				"projected_damage": 200,
				"projected_knockout": true,
				"source_card": {"uid": "CSV10C_113", "type": "Pokemon"},
			},
			"base_score": 3450.4,
			"local_score": 3450.4,
			"checkpoint_after": "terminal",
			"engine_rule_floor_exact": false,
			"outcome": {"prizes_now": 1, "win_now": false, "terminal": true},
		},
	]


func _observation() -> Dictionary:
	return {
		"observation_hash": PROVENANCE_OBSERVATION_HASH,
		"turn": {"number": PROVENANCE_TURN, "current_player": 0, "viewer": 0, "first_player": 0, "deterministic_attack_window_open": true},
		"own": {
			"active": _slot("slot:6", "CSV10C_113", 230, 100, 330, [_special_energy()], false, 2),
			"bench": [
				_slot("slot:4", "CSV10C_113", 0, 330, 330, [_energy("F")], false, 2),
				_slot("slot:18", "CSV9.5C_004", 0, 30, 30, [], false),
				_slot("slot:16", "CSV8C_094", 0, 110, 110, [_energy("D")], false),
				_slot("slot:2", "CSV10C_111", 0, 70, 70, [_energy("F"), _energy("F"), _energy("D")], false),
				_slot("slot:15", "CSV8C_094", 0, 110, 110, [], false),
			],
			"prizes_remaining": 2,
			"deck_count": 29,
			"hand": [{"uid": "CSV1C_123", "type": "Supporter"}],
		},
		"opponent": {
			"active": _slot("slot:0", "CS6aC_057", 0, 120, 120, [_energy("L"), _energy("L")], false),
			"bench": [
				_slot("slot:13", "CSV1C_050", 0, 220, 220, [], false, 2),
				_slot("slot:34", "CS5aC_019", 0, 200, 200, [], false, 2),
				_slot("slot:58", "CSV6C_051", 50, 180, 230, [_energy("L")], false, 2),
			],
			"prizes_remaining": 6,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": true, "max_damage": 200},
		"prize": {"win_now": false, "current_swing": 1},
		"resources": {"prizes_remaining": 2},
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


func _energy(symbol: String) -> Dictionary:
	return {
		"uid": "CSVE1C_%s" % ("FIG" if symbol == "F" else "LIG" if symbol == "L" else "DAR"),
		"type": "Basic Energy",
		"energy_provides": symbol,
	}


func _special_energy() -> Dictionary:
	return {"uid": "CSV1C_127", "type": "Special Energy"}


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
