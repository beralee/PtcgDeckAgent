extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 106
const PROVENANCE_TURN := 22
const PROVENANCE_OBSERVATION_HASH := "eb647c9c5541eece167c5832165477bb7b1c2a7679b8def59ce6d02fb978064b"
const RULE_ID := "candidate:b6bc2cb9793aa3f945e5"
const ATTACK_ID := "candidate:8359ba3981a3dd09aecc"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_test_exact_seed106_rule_suffix(profile)
	_test_fail_closed_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round03 counter mover before secured KO: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_seed106_rule_suffix(profile: Dictionary) -> void:
	_check(int(profile.get("profile_version", 0)) >= 5, "round03 certificate requires profile version 5 or newer")
	var annotated := _annotated(profile, _observation(), _facts(), _frontier())
	var prefix := _counter_prefix(annotated[0])
	_check(bool(prefix.get("preserves_secured_ko", false)), "exact Rule D -> Munkidori must preserve the secured KO suffix")
	_check(bool(prefix.get("preserves_secured_prize_suffix", false)), "exact Rule prefix must preserve the public prize floor")
	_check(str(prefix.get("target_slot_id", "")) == "slot:8", "counter mover target slot drifted")
	_check(str(prefix.get("source_slot_id", "")) == "slot:6", "safe Gardevoir source slot drifted")
	_check(str(prefix.get("source_uid", "")) == "CSV2C_055", "safe source must remain Gardevoir ex")
	_check(int(prefix.get("recoverable_ability_window_gain", 0)) == 1, "Rule prefix must recover one expiring ability window")
	_check(int(prefix.get("attack_damage", 0)) == 120, "secured Drifloon attack damage drifted")
	_check(int(prefix.get("opponent_active_hp", 0)) == 70, "Miraidon public HP drifted")
	_check(int(prefix.get("prizes_floor", 0)) == 2, "same-turn attack must bind the two-prize floor")
	var registry := CapabilityRegistryScript.new()
	var certificate := registry.verify_route_advantage(annotated[0], annotated[1], _facts(), profile)
	_check(str(certificate.get("certificate_kind", "")) == "public_counter_mover_before_secured_ko", "public same-turn suffix certificate changed")
	_check(str(certificate.get("evidence_kind", "")) == "public_same_turn_suffix", "certificate must remain public same-turn evidence")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var safety := strategy._validate_model_route_safety("route:attack_ko", annotated, _facts(), ATTACK_ID)
	_check(not bool(safety.get("valid", true)), "direct attack must not truncate the exact Rule prefix")
	_check(str(safety.get("reason", "")) == "verified_rule_suffix_dominates_terminal_switch", "reverse Rule-prefix protection reason changed")
	_check(str(safety.get("advantage", {}).get("certificate_kind", "")) == "public_counter_mover_before_secured_ko", "rejection must retain the suffix certificate")
	_check(strategy._find_module_verified_upgrade(annotated, _facts()).is_empty(), "direct KO must not be promoted over the stronger Rule suffix")


func _test_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var used := _observation()
	used["own"]["bench"][3]["ability_used"] = true
	cases.append({"label": "mover ability already used", "observation": used, "facts": _facts(), "frontier": _frontier()})
	var already_active := _observation()
	already_active["own"]["bench"][3]["energy"] = [_energy("D")]
	cases.append({"label": "mover already activated", "observation": already_active, "facts": _facts(), "frontier": _frontier()})
	var no_safe_source := _observation()
	no_safe_source["own"]["bench"][4]["damage"] = 20
	cases.append({"label": "no invariant thirty-damage source", "observation": no_safe_source, "facts": _facts(), "frontier": _frontier()})
	var only_active_damaged := _observation()
	only_active_damaged["own"]["bench"][4]["damage"] = 0
	cases.append({"label": "only the Active attacker is damaged", "observation": only_active_damaged, "facts": _facts(), "frontier": _frontier()})
	var target_active := _observation()
	target_active["own"]["active"] = _slot("slot:8", "CSV8C_094", 0, 110, 110, [], false)
	target_active["own"]["bench"][3] = _slot("slot:9", "CSV2C_060", 40, 30, 70, [_energy("P"), _energy("P"), _energy("P"), _energy("P")], false)
	cases.append({"label": "counter mover is Active", "observation": target_active, "facts": _facts(), "frontier": _frontier()})
	var wrong_target := _frontier()
	wrong_target[0]["action_ref"]["target"] = "slot:6"
	cases.append({"label": "attachment target is not mover", "observation": _observation(), "facts": _facts(), "frontier": wrong_target})
	var missing_target := _frontier()
	missing_target[0]["action_ref"]["target"] = "slot:missing"
	cases.append({"label": "attachment target missing", "observation": _observation(), "facts": _facts(), "frontier": missing_target})
	var wrong_energy := _frontier()
	wrong_energy[0]["action_ref"]["card"] = _energy("P")
	cases.append({"label": "attachment does not activate mover", "observation": _observation(), "facts": _facts(), "frontier": wrong_energy})
	var not_exact := _frontier()
	not_exact[0]["engine_rule_floor_exact"] = false
	cases.append({"label": "prefix is not exact Rule floor", "observation": _observation(), "facts": _facts(), "frontier": not_exact})
	var no_quota := _facts()
	no_quota["turn"]["energy_available"] = false
	cases.append({"label": "turn attachment quota spent", "observation": _observation(), "facts": no_quota, "frontier": _frontier()})
	var no_ko := _facts()
	no_ko["attack"]["ko_available"] = false
	cases.append({"label": "KO is not secured", "observation": _observation(), "facts": no_ko, "frontier": _frontier()})
	var ambiguous_source := _observation()
	ambiguous_source["own"]["bench"][2]["damage"] = 40
	cases.append({"label": "damaged non-invariant Bench source is selectable", "observation": ambiguous_source, "facts": _facts(), "frontier": _frontier()})
	var counter_ko_active := _observation()
	counter_ko_active["opponent"]["active"]["remaining_hp"] = 20
	cases.append({"label": "counter move would replace the secured attack target", "observation": counter_ko_active, "facts": _facts(), "frontier": _frontier()})
	var short_damage := _facts()
	short_damage["attack"]["max_damage"] = 60
	cases.append({"label": "attack damage below public HP", "observation": _observation(), "facts": short_damage, "frontier": _frontier()})
	var final_win := _facts()
	final_win["prize"]["win_now"] = true
	cases.append({"label": "attack already wins the game", "observation": _observation(), "facts": final_win, "frontier": _frontier()})
	for invalid: Dictionary in cases:
		var annotated := _annotated(
			profile,
			invalid.get("observation", {}),
			invalid.get("facts", {}),
			invalid.get("frontier", [])
		)
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
			"route_id": "route:energy_commit",
			"action_kind": "attach_energy",
			"action_ref": {"target": "slot:8", "card": _energy("D")},
			"base_score": 2579.76,
			"local_score": 2579.76,
			"engine_rule_floor_exact": true,
			"outcome": {"prizes_now": 0, "win_now": false},
		},
		{
			"candidate_id": ATTACK_ID,
			"route_id": "route:attack_ko",
			"action_kind": "attack",
			"action_ref": {"source": "slot:9", "attack_index": 1, "projected_damage": 120, "knockout": true},
			"base_score": 2559.52,
			"local_score": 2559.52,
			"engine_rule_floor_exact": false,
			"outcome": {"prizes_now": 2, "win_now": false, "terminal": true},
		},
	]


func _observation() -> Dictionary:
	return {
		"observation_hash": PROVENANCE_OBSERVATION_HASH,
		"turn": {"number": PROVENANCE_TURN, "current_player": 1, "viewer": 1, "first_player": 0, "deterministic_attack_window_open": true},
		"own": {
			"active": _slot("slot:9", "CSV2C_060", 40, 30, 70, [_energy("P"), _energy("P"), _energy("P"), _energy("P")], false),
			"bench": [
				_slot("slot:4", "CSV2C_054", 0, 90, 90, [], false),
				_slot("slot:12", "151C_151", 0, 180, 180, [], false, 2),
				_slot("slot:11", "CSV10C_082", 0, 190, 190, [], false, 2),
				_slot("slot:8", "CSV8C_094", 0, 110, 110, [], false),
				_slot("slot:6", "CSV2C_055", 60, 250, 310, [_energy("P")], false, 2),
			],
			"prizes_remaining": 6,
			"deck_count": 19,
			"hand": [{"uid": "CSV3C_123", "type": "Supporter"}, _energy("D"), {"uid": "CSV1C_112", "type": "Item"}],
		},
		"opponent": {
			"active": _opponent_slot("slot:14", "CSV1C_050", 150, 70, 2, []),
			"bench": [
				_opponent_slot("slot:57", "CSV6C_051", 0, 230, 2, [_energy("L"), _energy("L"), _energy("L"), _special_energy()]),
				_opponent_slot("slot:58", "CSV6C_051", 0, 230, 2, [_energy("L"), _energy("L"), _energy("L"), _special_energy()]),
				_opponent_slot("slot:0", "CS6aC_057", 0, 120, 1, []),
				_opponent_slot("slot:1", "CS6.5C_020", 0, 130, 1, []),
				_opponent_slot("slot:34", "CS5aC_019", 90, 110, 2, []),
			],
			"prizes_remaining": 5,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": true, "max_damage": 120},
		"prize": {"win_now": false, "current_swing": 2},
		"resources": {"prizes_remaining": 6},
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
	return {"slot_id": slot_id, "pokemon": {"uid": uid}, "damage": damage, "remaining_hp": remaining_hp, "energy": energy.duplicate(true), "energy_count": energy.size(), "ability_used": false, "prize_count": prize_count}


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
