extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	_check(int(profile.get("profile_version", 0)) >= 6, "round05 profile must be active")
	_test_opening_preserves_psychic(profile)
	_test_damaged_gardevoir_enables_immediate_move(profile)
	_test_exact_negative_boundaries(profile)
	_test_certificate_is_not_inherited_by_academy_profile()
	if _failures.is_empty():
		print("V18CPG 800018497 round03 profiled counter activation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_opening_preserves_psychic(profile: Dictionary) -> void:
	var frontier := _opening_frontier()
	var observation := _opening_observation()
	var facts := _facts(false)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
	var activation := _activation(annotated[1])
	_check(str(activation.get("activation_stage", "")) == "opening_preserve_psychic", "Darkness on the opening Active Munkidori must preserve visible Psychic fuel")
	_check(int(activation.get("preserved_hand_psychic", 0)) == 1, "the paired certificate must record the preserved Psychic Energy")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "candidate:dark_active", "opening paired evidence must select Darkness over the 1640-point Rule Psychic root")
	_check(str(upgrade.get("verified_advantage", {}).get("evidence_kind", "")) == "paired_evaluation", "opening activation must not be mislabeled as deterministic proof")


func _test_damaged_gardevoir_enables_immediate_move(profile: Dictionary) -> void:
	var frontier: Array[Dictionary] = [
		_attach_candidate("candidate:dark_gardevoir", "slot:active", "D", 682.56),
		_attach_candidate("candidate:dark_mover", "slot:mover", "D", 606.528),
	]
	var observation := _opening_observation()
	observation["own"]["active"] = _slot("slot:active", "CSV2C_055", 140, 170)
	observation["own"]["bench"] = [_slot("slot:mover", "CSV8C_094", 110, 0), _slot("slot:ralts", "CSV2C_053", 70, 0)]
	observation["own"]["discard"] = [
		{"uid": "discard:p1", "type": "Basic Energy", "energy_type": "P"},
		{"uid": "discard:p2", "type": "Basic Energy", "energy_type": "P"},
	]
	var facts := _facts(false)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
	var activation := _activation(annotated[1])
	_check(str(activation.get("activation_stage", "")) == "immediate_counter_move", "Darkness on a Benched Munkidori must expose the immediate 30-point move from damaged Gardevoir")
	_check(int(activation.get("movable_damage", 0)) >= 30, "the public certificate must count visible movable damage")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "candidate:dark_mover", "damaged-Gardevoir paired evidence must activate the counter mover")


func _test_exact_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var no_ralts := _opening_observation()
	no_ralts["own"]["bench"] = [_slot("slot:mover2", "CSV8C_094", 110, 0)]
	no_ralts["own"]["hand"] = [
		{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"},
		{"uid": "CSVE1C_DAR", "type": "Basic Energy", "energy_type": "D"},
	]
	cases.append({"label": "no visible or hand-access foundation", "observation": no_ralts, "facts": _facts(false), "index": 1})
	var no_psychic := _opening_observation()
	no_psychic["own"]["hand"] = [{"uid": "CSVE1C_DAR", "type": "Basic Energy", "energy_type": "D"}]
	cases.append({"label": "no Psychic to preserve", "observation": no_psychic, "facts": _facts(false), "index": 1})
	var prizes_taken := _opening_observation()
	prizes_taken["own"]["prizes_remaining"] = 5
	cases.append({"label": "outside opening prize tier", "observation": prizes_taken, "facts": _facts(false), "index": 1})
	cases.append({"label": "attack already ready", "observation": _opening_observation(), "facts": _facts(true), "index": 1})
	var wrong_active := _opening_observation()
	wrong_active["own"]["active"] = _slot("slot:active", "CSV6C_065", 90, 0)
	cases.append({"label": "wrong opening Active", "observation": wrong_active, "facts": _facts(false), "index": 1})
	for invalid: Dictionary in cases:
		var annotated := CapabilityRegistryScript.new().annotate_frontier(
			_opening_frontier(), invalid.get("observation", {}), invalid.get("facts", {}), profile, {}
		)
		_check(not bool(_activation(annotated[int(invalid.get("index", 1))]).get("advances_profiled_activation", false)), "%s must not mint paired activation evidence" % str(invalid.get("label", "invalid")))

	var damaged := _opening_observation()
	damaged["own"]["active"] = _slot("slot:active", "CSV2C_055", 310, 0)
	damaged["own"]["bench"] = [_slot("slot:mover", "CSV8C_094", 110, 0), _slot("slot:ralts", "CSV2C_053", 70, 0)]
	damaged["own"]["discard"] = [{"uid": "discard:p1", "type": "Basic Energy", "energy_type": "P"}]
	var damaged_frontier: Array[Dictionary] = [
		_attach_candidate("candidate:dark_gardevoir", "slot:active", "D", 682.56),
		_attach_candidate("candidate:dark_mover", "slot:mover", "D", 606.528),
	]
	var damaged_annotated := CapabilityRegistryScript.new().annotate_frontier(damaged_frontier, damaged, _facts(false), profile, {})
	_check(not bool(_activation(damaged_annotated[1]).get("advances_profiled_activation", false)), "no visible damage and insufficient Psychic discard must block the damaged-Gardevoir stage")


func _test_certificate_is_not_inherited_by_academy_profile() -> void:
	var academy := ProfileCatalogScript.get_profile_for_deck(800018498)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_opening_frontier(), _opening_observation(), _facts(false), academy, {}
	)
	_check(not bool(_activation(annotated[1]).get("advances_profiled_activation", false)), "800018498 must not inherit the standard-deck paired activation evidence")


func _opening_frontier() -> Array[Dictionary]:
	return [
		_attach_candidate("candidate:psychic_active", "slot:active", "P", 1986.528),
		_attach_candidate("candidate:dark_active", "slot:active", "D", 346.528),
		_attach_candidate("candidate:dark_bench", "slot:mover2", "D", 166.528),
	]


func _opening_observation() -> Dictionary:
	return {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 45,
			"hand": [
				{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"},
				{"uid": "CSVE1C_DAR", "type": "Basic Energy", "energy_type": "D"},
				{"uid": "CSV2C_055", "type": "Pokemon"},
				{"uid": "CSV2C_127", "type": "Stadium"},
			],
			"discard": [],
			"active": _slot("slot:active", "CSV8C_094", 110, 0),
			"bench": [_slot("slot:mover2", "CSV8C_094", 110, 0), _slot("slot:ralts", "CSV2C_053", 70, 0)],
		},
		"opponent": {
			"deck_count": 47,
			"active": _slot("slot:opponent", "CSV8C_135", 210, 0, 2),
			"bench": [],
		},
	}


func _attach_candidate(candidate_id: String, target: String, symbol: String, score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": "route:energy_commit",
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"action_kind": "attach_energy",
		"action_ref": {
			"kind": "attach_energy",
			"card": {"uid": "energy:%s" % symbol, "type": "Basic Energy", "energy_type": symbol},
			"target": target,
		},
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _slot(slot_id: String, uid: String, remaining_hp: int, damage: int, prize_count: int = 1) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": [],
		"damage": damage,
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp + damage,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _facts(attack_ready: bool) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _activation(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("damage_counter_control", {}).get("profiled_counter_activation", {})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
