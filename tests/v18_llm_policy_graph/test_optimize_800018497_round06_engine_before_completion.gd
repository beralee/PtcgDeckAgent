extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	_check(int(profile.get("profile_version", 0)) >= 11, "the source-correct profile must be active")
	_test_invalidated_legacy_route_is_removed(profile)
	if _failures.is_empty():
		print("V18CPG 800018497 invalidated engine route removal: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_invalidated_legacy_route_is_removed(profile: Dictionary) -> void:
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_frontier(),
		_observation(),
		_facts(),
		profile,
		{}
	)
	_check(
		not bool(_annotation(annotated[1]).get("advances_profiled_engine_search", false)),
		"the source-correct deck must not revive the invalidated exact Arven/Darkness route"
	)
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	_check(
		str(strategy._find_module_verified_upgrade(annotated, _facts()).get(
			"candidate_id",
			""
		)) != "candidate:arven",
		"the invalidated artifact must not authorize Arven to replace the Rule floor"
	)


func _test_exact_engine_search(profile: Dictionary) -> void:
	var frontier := _frontier()
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, _observation(), _facts(), profile, {})
	var search := _annotation(annotated[1])
	_check(bool(search.get("advances_profiled_engine_search", false)), "Arven must precede the Darkness attachment that would immediately close the shallow attack cost")
	_check(int(search.get("completion_energy_in_hand", 0)) == 2, "the paired evidence must record both visible Darkness Energy")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, _facts())
	_check(str(upgrade.get("candidate_id", "")) == "candidate:arven", "the paired engine search must beat the Rule attachment root")
	_check(str(upgrade.get("verified_advantage", {}).get("evidence_kind", "")) == "paired_evaluation", "the engine search must not be mislabeled as deterministic proof")

	var followup_observation := _observation()
	followup_observation["own"]["hand"] = [
		_card("CSV6C_114", "Item"),
		_card("CS6.5C_030", "Pokemon"),
		_card("CSVE1C_DAR", "Basic Energy", "D"),
		_card("CSVE1C_DAR", "Basic Energy", "D"),
		_card("CSVH1C_045", "Item"),
		_card("CSV1C_112", "Item"),
		_card("CSV5C_119", "Tool"),
	]
	var followup_facts := _facts()
	followup_facts["turn"]["supporter_available"] = false
	var followup_frontier: Array[Dictionary] = [
		_frontier()[0],
		{
			"candidate_id": "candidate:ultra_ball",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:ultra_ball",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV1C_112", "Item")},
			"base_score": -1900.0,
			"local_score": -1900.0,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	var followup_annotated := CapabilityRegistryScript.new().annotate_frontier(followup_frontier, followup_observation, followup_facts, profile, {})
	_check(str(_annotation(followup_annotated[1]).get("search_stage", "")) == "pokemon_search_before_attack_completion", "the Arven-fetched Ultra Ball must continue the engine line before Darkness attachment")
	_check(str(strategy._find_module_verified_upgrade(followup_annotated, followup_facts).get("candidate_id", "")) == "candidate:ultra_ball", "the paired follow-up search must beat the attack-completing attachment")


func _test_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var bench_present := _observation()
	bench_present["own"]["bench"] = [_slot("slot:ralts", "CSV2C_053")]
	cases.append({"label": "existing bench", "observation": bench_present, "facts": _facts()})
	var missing_kirlia := _observation()
	missing_kirlia["own"]["hand"] = (missing_kirlia["own"]["hand"] as Array).filter(func(card: Dictionary) -> bool: return str(card.get("uid", "")) != "CS6.5C_030")
	cases.append({"label": "missing Kirlia", "observation": missing_kirlia, "facts": _facts()})
	var one_dark := _observation()
	one_dark["own"]["hand"].remove_at(4)
	cases.append({"label": "only one Darkness", "observation": one_dark, "facts": _facts()})
	var wrong_opponent := _observation()
	wrong_opponent["opponent"]["active"]["remaining_hp"] = 220
	cases.append({"label": "different opponent tier", "observation": wrong_opponent, "facts": _facts()})
	var attack_ready := _facts()
	attack_ready["attack"]["ready"] = true
	cases.append({"label": "attack already ready", "observation": _observation(), "facts": attack_ready})
	var supporter_spent := _facts()
	supporter_spent["turn"]["supporter_available"] = false
	cases.append({"label": "supporter spent", "observation": _observation(), "facts": supporter_spent})
	for invalid: Dictionary in cases:
		var annotated := CapabilityRegistryScript.new().annotate_frontier(_frontier(), invalid.get("observation", {}), invalid.get("facts", {}), profile, {})
		_check(not bool(_annotation(annotated[1]).get("advances_profiled_engine_search", false)), "%s must block the paired engine search" % str(invalid.get("label", "invalid")))


func _test_profile_isolation() -> void:
	var academy := ProfileCatalogScript.get_profile_for_deck(800018498)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(_frontier(), _observation(), _facts(), academy, {})
	_check(not bool(_annotation(annotated[1]).get("advances_profiled_engine_search", false)), "the academy profile must not inherit standard Gardevoir's paired engine search")


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:dark_active",
			"route_id": "route:energy_commit",
			"safe_prefix_action_id": "action:dark_active",
			"action_kind": "attach_energy",
			"action_ref": {"card": _card("CSVE1C_DAR", "Basic Energy", "D"), "target": "slot:active"},
			"base_score": 655.84,
			"local_score": 655.84,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:arven",
			"route_id": "route:tutor",
			"safe_prefix_action_id": "action:arven",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV1C_123", "Supporter")},
			"base_score": 325.6,
			"local_score": 325.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _observation() -> Dictionary:
	var active := _slot("slot:active", "CSV10C_082")
	active["energy"] = [_card("CSVE1C_PSY", "Basic Energy", "P")]
	var opponent_active := _slot("slot:opponent", "CSV6C_051", 2)
	opponent_active["remaining_hp"] = 230
	opponent_active["max_hp"] = 230
	return {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 44,
			"hand": [
				_card("CSV6C_114", "Item"),
				_card("CSV1C_123", "Supporter"),
				_card("CS6.5C_030", "Pokemon"),
				_card("CSVE1C_DAR", "Basic Energy", "D"),
				_card("CSVE1C_DAR", "Basic Energy", "D"),
				_card("CSVH1C_045", "Item"),
			],
			"discard": [],
			"active": active,
			"bench": [],
		},
		"opponent": {"prizes_remaining": 6, "active": opponent_active, "bench": []},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _annotation(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("gardevoir_embrace", {}).get("profiled_engine_search", {})


func _card(uid: String, type_name: String, symbol: String = "") -> Dictionary:
	var card := {"uid": uid, "type": type_name}
	if symbol != "":
		card["energy_type"] = symbol
	return card


func _slot(slot_id: String, uid: String, prize_count: int = 1) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": [],
		"damage": 0,
		"remaining_hp": 190,
		"max_hp": 190,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
