extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 108
const PROVENANCE_TURN := 16
const PRE_EVOLVE_OBSERVATION_HASH := "ec7507bd57a0241a1e09875711fd7f20f7627c8beaa040218e44ff852fb036be"
const POST_EVOLVE_OBSERVATION_HASH := "b09a93a5e6b207a9bedfcfd91d410bc1b51a73e7dc57dfead3f6758f0e5647ef"
const EVOLVE_ID := "candidate:43c6fe5e47f912f7b4f4"
const ZERO_DAMAGE_ID := "candidate:668db0dc6de45cfe2fca"
const TEN_DAMAGE_ID := "candidate:fee4e78363a3a49c7832"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_test_exact_seed108_damage_upgrade(profile)
	_test_fail_closed_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round05 deterministic attack damage dominance: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_seed108_damage_upgrade(profile: Dictionary) -> void:
	_check(int(profile.get("profile_version", 0)) >= 7, "round05 profile version must remain active")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var initial := _annotated(profile, _observation(false), _facts(), [_evolve_candidate(), _attack_candidate(false, false), _attack_candidate(true, false)])
	_check(strategy._find_module_verified_upgrade(initial, _facts()).is_empty(), "damage upgrade must not skip the exact Rule evolution prefix")
	var annotated := _annotated(profile, _observation(true), _facts(), [_attack_candidate(false, true), _attack_candidate(true, false)])
	var preferred := _attack_annotation(annotated[1])
	var dominated := _attack_annotation(annotated[0])
	_check(str(preferred.get("pair_role", "")) == "preferred", "Gust must be the profiled preferred attack")
	_check(str(dominated.get("pair_role", "")) == "dominated", "zero-counter Balloon Bomb must be the dominated attack")
	_check(int(preferred.get("projected_damage", 0)) == 10, "Gust damage drifted")
	_check(int(dominated.get("projected_damage", -1)) == 0, "Balloon Bomb must remain zero with an undamaged Drifloon")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(annotated[1], annotated[0], _facts(), profile)
	_check(str(certificate.get("certificate_kind", "")) == "public_same_attacker_damage_dominance", "attack dominance certificate changed")
	_check(int(certificate.get("damage_floor", 0)) == 10, "certificate must retain the ten-damage floor")
	_check(int(certificate.get("dominated_damage", -1)) == 0, "certificate must retain the zero-damage comparison")
	var safety := strategy._validate_model_route_safety("route:attack_pressure", annotated, _facts(), TEN_DAMAGE_ID)
	_check(bool(safety.get("valid", false)), "strict deterministic damage upgrade must pass safety")
	_check(str(safety.get("reason", "")) == "module_verified_advantage", "damage upgrade must use a module certificate")
	var upgrade := strategy._find_module_verified_upgrade(annotated, _facts())
	_check(str(upgrade.get("candidate_id", "")) == TEN_DAMAGE_ID, "post-evolution local gate must choose ten damage")
	_check(str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "public_same_attacker_damage_dominance", "upgrade must retain the exact certificate")


func _test_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var damaged := _observation(true)
	damaged["own"]["active"]["damage"] = 10
	cases.append({"label": "Drifloon has damage counters", "observation": damaged, "frontier": [_attack_candidate(false, true), _attack_candidate(true, false)]})
	var wrong_uid := _observation(true)
	wrong_uid["own"]["active"]["pokemon"]["uid"] = "CSV2C_055"
	cases.append({"label": "source UID changed", "observation": wrong_uid, "frontier": [_attack_candidate(false, true), _attack_candidate(true, false)]})
	var wrong_slot := [_attack_candidate(false, true), _attack_candidate(true, false)]
	wrong_slot[1]["action_ref"]["source"] = "slot:other"
	cases.append({"label": "attacks use different source slots", "observation": _observation(true), "frontier": wrong_slot})
	var not_exact := [_attack_candidate(false, false), _attack_candidate(true, false)]
	cases.append({"label": "dominated attack is not exact Rule floor", "observation": _observation(true), "frontier": not_exact})
	var not_terminal := [_attack_candidate(false, true), _attack_candidate(true, false)]
	not_terminal[1]["checkpoint_after"] = "action_resolved"
	cases.append({"label": "preferred attack is not terminal", "observation": _observation(true), "frontier": not_terminal})
	var selected_ko := [_attack_candidate(false, true), _attack_candidate(true, false)]
	selected_ko[1]["action_ref"]["projected_knockout"] = true
	cases.append({"label": "preferred attack changes the KO class", "observation": _observation(true), "frontier": selected_ko})
	var no_gain := [_attack_candidate(false, true), _attack_candidate(true, false)]
	no_gain[1]["action_ref"]["projected_damage"] = 0
	cases.append({"label": "preferred attack has no strict damage gain", "observation": _observation(true), "frontier": no_gain})
	var wrong_pair := [_attack_candidate(false, true), _attack_candidate(true, false)]
	wrong_pair[1]["action_ref"]["attack_index"] = 2
	cases.append({"label": "attack indices are not the profiled pair", "observation": _observation(true), "frontier": wrong_pair})
	for invalid: Dictionary in cases:
		var annotated := _annotated(profile, invalid.get("observation", {}), _facts(), invalid.get("frontier", []))
		var certificate := CapabilityRegistryScript.new().verify_route_advantage(annotated[1], annotated[0], _facts(), profile) if annotated.size() >= 2 else {}
		_check(not bool(certificate.get("verified", false)), "%s must fail closed" % str(invalid.get("label", "invalid")))


func _annotated(profile: Dictionary, observation: Dictionary, facts: Dictionary, frontier: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary:
			typed.append(raw_candidate as Dictionary)
	return CapabilityRegistryScript.new().annotate_frontier(typed, observation, facts, profile, {})


func _evolve_candidate() -> Dictionary:
	return {
		"candidate_id": EVOLVE_ID,
		"route_id": "route:evolve",
		"action_kind": "evolve",
		"action_ref": {"target": "slot:2", "card": {"uid": "CSV2C_054", "type": "Pokemon"}},
		"checkpoint_after": "action_resolved",
		"base_score": 887.68,
		"local_score": 887.68,
		"engine_rule_floor_exact": true,
		"outcome": {"board_development": 1.0},
	}


func _attack_candidate(preferred: bool, rule_floor: bool) -> Dictionary:
	return {
		"candidate_id": TEN_DAMAGE_ID if preferred else ZERO_DAMAGE_ID,
		"route_id": "route:attack_pressure",
		"action_kind": "attack",
		"action_ref": {
			"source": "slot:9",
			"source_card": {"uid": "CSV2C_060", "type": "Pokemon"},
			"attack_index": 0 if preferred else 1,
			"projected_damage": 10 if preferred else 0,
			"projected_knockout": false,
		},
		"checkpoint_after": "terminal",
		"base_score": -5931.0 if preferred else 235.68,
		"local_score": -5931.0 if preferred else 235.68,
		"engine_rule_floor_exact": rule_floor,
		"outcome": {"attack_ready": true, "estimated_damage": 10 if preferred else 0, "terminal": true},
	}


func _observation(post_evolve: bool) -> Dictionary:
	return {
		"observation_hash": POST_EVOLVE_OBSERVATION_HASH if post_evolve else PRE_EVOLVE_OBSERVATION_HASH,
		"turn": {"number": PROVENANCE_TURN, "current_player": 1, "viewer": 1, "first_player": 0, "deterministic_attack_window_open": true},
		"own": {
			"active": _slot("slot:9", "CSV2C_060", 0, 70, [_energy("P"), _energy("P")], 1),
			"bench": [
				_slot("slot:8", "CSV8C_094", 0, 110, [_energy("P")], 1),
				_slot("slot:2", "CSV2C_054" if post_evolve else "CSV2C_053", 0, 90 if post_evolve else 70, [_energy("P")], 1),
				_slot("slot:1", "CSV2C_053", 0, 70, [_energy("P")], 1),
				_slot("slot:12", "151C_151", 0, 180, [_energy("D"), _energy("D")], 2),
				_slot("slot:13", "CSV8C_135", 0, 210, [], 2),
			],
			"prizes_remaining": 6,
			"deck_count": 23,
			"hand": [{"uid": "CSV2C_127", "type": "Stadium"}, {"uid": "CSV8C_094", "type": "Pokemon"}, {"uid": "CSV8C_183", "type": "Item"}, {"uid": "CSV3C_123", "type": "Supporter"}],
		},
		"opponent": {
			"active": _slot("slot:8", "CSV2C_105", 0, 160, [], 2),
			"bench": [
				_slot("slot:14", "CSV1C_050", 0, 220, [], 2),
				_slot("slot:58", "CSV6C_051", 0, 230, [], 2),
				_slot("slot:57", "CSV6C_051", 0, 230, [], 2),
				_slot("slot:47", "CS4DaC_137", 0, 200, [_energy("L")], 2),
				_slot("slot:34", "CS5aC_019", 0, 200, [], 2),
			],
			"prizes_remaining": 5,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": false, "max_damage": 10},
		"prize": {"win_now": false, "current_swing": 0},
		"resources": {"prizes_remaining": 6},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _slot(slot_id: String, uid: String, damage: int, remaining_hp: int, energy: Array, prize_count: int) -> Dictionary:
	return {"slot_id": slot_id, "pokemon": {"uid": uid}, "damage": damage, "remaining_hp": remaining_hp, "energy": energy.duplicate(true), "energy_count": energy.size(), "ability_used": false, "prize_count": prize_count}


func _energy(symbol: String) -> Dictionary:
	return {"uid": "CSVE1C_%s" % ("PSY" if symbol == "P" else "LIG" if symbol == "L" else "DAR"), "type": "Basic Energy", "energy_provides": symbol}


func _attack_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) if candidate.get("module_annotations", {}) is Dictionary else {}
	var annotation: Dictionary = annotations.get("damage_counter_control", {}) if annotations.get("damage_counter_control", {}) is Dictionary else {}
	return annotation.get("deterministic_attack_dominance", {}) if annotation.get("deterministic_attack_dominance", {}) is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
