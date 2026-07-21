extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800017097)
	_check(int(profile.get("profile_version", 0)) >= 7, "round06 profile must be active")
	_test_two_stage_active_closeout(profile)
	_test_interaction_target(profile)
	_test_negative_boundaries(profile)
	_test_profile_isolation()
	if _failures.is_empty():
		print("V18CPG 800017097 round06 active closeout: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_two_stage_active_closeout(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var first := CapabilityRegistryScript.new().annotate_frontier(
		_frontier("first"), _observation("first"), _facts(), profile, {}
	)
	_check(
		str(_hold(first[1]).get("stage", "")) == "embrace_active_ko_first",
		"the first remaining Psychic must charge Active Gardevoir before Munkidori moves damage"
	)
	_check(
		str(strategy._find_module_verified_upgrade(first, _facts()).get("candidate_id", "")) == "candidate:embrace_active_first",
		"the first Active Embrace must beat the high Rule Munkidori score"
	)
	var second := CapabilityRegistryScript.new().annotate_frontier(
		_frontier("second"), _observation("second"), _facts(), profile, {}
	)
	_check(
		str(_hold(second[1]).get("stage", "")) == "embrace_active_ko_second",
		"the second remaining Psychic must complete Active Gardevoir's three-Energy cost"
	)
	_check(
		str(strategy._find_module_verified_upgrade(second, _facts()).get("candidate_id", "")) == "candidate:embrace_active_second",
		"the second Active Embrace must complete the public Squawkabilly ex KO line"
	)
	var attack_facts := _facts()
	attack_facts["attack"] = {"ready": true, "ko_available": true, "max_damage": 190}
	var attack := CapabilityRegistryScript.new().annotate_frontier(
		_frontier("attack"), _observation("attack"), attack_facts, profile, {}
	)
	_check(
		str(_hold(attack[1]).get("stage", "")) == "attack_before_counter_move",
		"the secured Active Gardevoir KO must execute before Munkidori consumes Drifloon's damage"
	)
	_check(
		str(strategy._find_module_verified_upgrade(attack, attack_facts).get("candidate_id", "")) == "candidate:attack_active",
		"the deterministic Squawkabilly ex KO must beat optional counter movement"
	)


func _test_interaction_target(profile: Dictionary) -> void:
	var gardevoir := _pokemon_slot("Gardevoir ex", "CSV2C", "055")
	var drifloon := _pokemon_slot("Drifloon", "CSV2C", "060")
	for state_name: String in ["first", "second"]:
		var override := CapabilityRegistryScript.new().pick_verified_interaction_override(
			[gardevoir, drifloon],
			{"id": "embrace_target", "min_select": 1, "max_select": 1},
			[drifloon],
			{"v18cpg_observation": _observation(state_name), "v18cpg_facts": _facts()},
			profile,
			"profiled_visible_engine_hold"
		)
		_check(
			bool(override.get("handled", false)) and override.get("items", []) == [gardevoir],
			"%s closeout Embrace must target Active Gardevoir" % state_name
		)


func _test_negative_boundaries(profile: Dictionary) -> void:
	var wrong_energy := _observation("first")
	wrong_energy["own"]["active"]["energy"].append(_card("energy:extra", "Basic Energy", "P"))
	wrong_energy["own"]["active"]["energy_count"] = 2
	var wrong_target := _observation("first")
	wrong_target["opponent"]["active"]["remaining_hp"] = 140
	for test_case: Dictionary in [
		{"label": "Active already has two Energy", "observation": wrong_energy},
		{"label": "opponent HP changed", "observation": wrong_target},
	]:
		var annotated := CapabilityRegistryScript.new().annotate_frontier(
			_frontier("first"), test_case.get("observation", {}), _facts(), profile, {}
		)
		_check(
			not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)),
			"active closeout must reject when %s" % str(test_case.get("label", "state differs"))
		)


func _test_profile_isolation() -> void:
	var other_profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_frontier("first"), _observation("first"), _facts(), other_profile, {}
	)
	_check(
		not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)),
		"the no-balloon Active closeout must not leak into standard Gardevoir"
	)


func _frontier(state_name: String) -> Array[Dictionary]:
	var suffix := state_name
	var rule_is_ability := state_name != "second"
	var selected_is_attack := state_name == "attack"
	return [
		{
			"candidate_id": "candidate:munkidori_or_end",
			"route_id": "route:information" if rule_is_ability else "route:end_turn",
			"safe_prefix_action_id": "action:rule_top",
			"action_kind": "use_ability" if rule_is_ability else "end_turn",
			"action_ref": {
				"ability_index": 0,
				"source": "slot:munkidori",
				"source_card": _card("CSV8C_094", "Pokemon"),
			} if rule_is_ability else {},
			"base_score": 6464.176 if rule_is_ability else -144.0,
			"local_score": 6464.176 if rule_is_ability else -144.0,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:attack_active" if selected_is_attack else "candidate:embrace_active_%s" % suffix,
			"route_id": "route:attack_ko" if selected_is_attack else "route:information",
			"safe_prefix_action_id": "action:attack_active" if selected_is_attack else "action:embrace_active_%s" % suffix,
			"action_kind": "attack" if selected_is_attack else "use_ability",
			"action_ref": {
				"ability_index": 0 if not selected_is_attack else -1,
				"attack_index": 0 if selected_is_attack else -1,
				"source": "slot:gardevoir",
				"source_card": _card("CSV2C_055", "Pokemon"),
			},
			"checkpoint_after": "terminal" if selected_is_attack else "information_result",
			"base_score": 2657.08 if selected_is_attack else 539.4,
			"local_score": 2657.08 if selected_is_attack else 539.4,
			"outcome": {"win_now": false, "prizes_now": 2 if selected_is_attack else 0, "estimated_damage": 190 if selected_is_attack else 0},
		},
	]


func _observation(state_name: String) -> Dictionary:
	var active_energy: Array[String] = ["P"]
	if state_name in ["second", "attack"]:
		active_energy.append("P")
	if state_name == "attack":
		active_energy.append("P")
	var active := _slot("slot:gardevoir", "CSV2C_055", active_energy, 2)
	active["damage"] = 0 if state_name == "first" else 20 if state_name == "second" else 40
	active["remaining_hp"] = 310 if state_name == "first" else 290 if state_name == "second" else 270
	active["max_hp"] = 310
	var drifloon := _slot("slot:drifloon", "CSV2C_060", ["P", "P"])
	drifloon["damage"] = 20
	drifloon["remaining_hp"] = 50
	drifloon["max_hp"] = 70
	return {
		"own": {
			"active": active,
			"bench": [
				drifloon,
				_slot("slot:munkidori", "CSV8C_094", ["D"]),
				_slot("slot:munkidori2", "CSV8C_094"),
				_slot("slot:cleffa", "CSV4C_044"),
				_slot("slot:budew", "CSV9.5C_004"),
			],
			"hand": [_card("CSV1C_112", "Item")],
			"discard": _psychic_discard(2 if state_name == "first" else 1 if state_name == "second" else 0),
			"deck_count": 27,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _opponent_active(),
			"bench": [],
			"deck_count": 31,
			"prizes_remaining": 6,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": false, "supporter_available": true},
	}


func _hold(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("gardevoir_embrace", {}).get("profiled_engine_hold", {})


func _opponent_active() -> Dictionary:
	var active := _slot("slot:opponent", "CSV2C_105", [], 2)
	active["remaining_hp"] = 160
	active["max_hp"] = 160
	return active


func _psychic_discard(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in count:
		result.append(_card("discard:p%d" % index, "Basic Energy", "P"))
	return result


func _card(uid: String, type_name: String, symbol: String = "") -> Dictionary:
	var card := {"uid": uid, "type": type_name}
	if symbol != "":
		card["energy_type"] = symbol
	return card


func _card_instance(name: String, type_name: String, set_code: String, card_index: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = type_name
	data.set_code = set_code
	data.card_index = card_index
	return CardInstance.create(data, 0)


func _pokemon_slot(name: String, set_code: String, card_index: String) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card_instance(name, "Pokemon", set_code, card_index))
	return slot


func _slot(slot_id: String, uid: String, symbols: Array[String] = [], prize_count: int = 1) -> Dictionary:
	var energy: Array[Dictionary] = []
	for symbol: String in symbols:
		energy.append(_card("energy:%s:%d" % [symbol, energy.size()], "Basic Energy", symbol))
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": energy,
		"energy_count": energy.size(),
		"damage": 0,
		"remaining_hp": 110,
		"max_hp": 110,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
