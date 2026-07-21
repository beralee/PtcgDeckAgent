extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800017097)
	_check(int(profile.get("profile_version", 0)) >= 7, "round06 profile must be active")
	_test_six_stage_single_prize_closeout(profile)
	_test_embrace_target(profile)
	_test_negative_boundary(profile)
	if _failures.is_empty():
		print("V18CPG 800017097 round06 single-prize closeout: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_six_stage_single_prize_closeout(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var expected := {
		"attach": "bank_active_energy_for_drif_pivot",
		"embrace1": "load_drifloon_embrace1",
		"embrace2": "load_drifloon_embrace2",
		"embrace3": "load_drifloon_embrace3",
		"pivot": "pivot_to_loaded_drifloon",
		"attack": "attack_with_loaded_drifloon",
	}
	for state_name: String in expected.keys():
		var facts := _facts(state_name)
		var annotated := CapabilityRegistryScript.new().annotate_frontier(
			_frontier(state_name), _observation(state_name), facts, profile, {}
		)
		_check(
			str(_hold(annotated[1]).get("stage", "")) == str(expected.get(state_name, "")),
			"%s must expose its exact single-prize closeout stage" % state_name
		)
		_check(
			str(strategy._find_module_verified_upgrade(annotated, facts).get("candidate_id", "")) == "candidate:%s" % state_name,
			"%s must beat the Rule counter-move or premature attachment" % state_name
		)


func _test_embrace_target(profile: Dictionary) -> void:
	var gardevoir := _pokemon_slot("Gardevoir ex", "CSV2C", "055")
	var drifloon := _pokemon_slot("Drifloon", "CSV2C", "060")
	for state_name: String in ["embrace1", "embrace2", "embrace3"]:
		var override := CapabilityRegistryScript.new().pick_verified_interaction_override(
			[gardevoir, drifloon],
			{"id": "embrace_target", "min_select": 1, "max_select": 1},
			[gardevoir],
			{"v18cpg_observation": _observation(state_name), "v18cpg_facts": _facts(state_name)},
			profile,
			"profiled_visible_engine_hold"
		)
		_check(
			bool(override.get("handled", false)) and override.get("items", []) == [drifloon],
			"%s must assign Psychic to Drifloon" % state_name
		)


func _test_negative_boundary(profile: Dictionary) -> void:
	var changed := _observation("embrace2")
	changed["own"]["bench"][0]["damage"] = 40
	changed["own"]["bench"][0]["remaining_hp"] = 30
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_frontier("embrace2"), changed, _facts("embrace2"), profile, {}
	)
	_check(
		not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)),
		"the closeout must reject a changed Drifloon damage budget"
	)


func _frontier(state_name: String) -> Array[Dictionary]:
	var selected_kind := "attach_energy" if state_name == "attach" else "use_ability"
	var selected_route := "route:energy_commit" if state_name == "attach" else "route:information"
	var selected_ref: Dictionary = {
		"ability_index": 0,
		"source": "slot:gardevoir",
		"source_card": _card("CSV2C_055", "Pokemon"),
	}
	if state_name == "attach":
		selected_ref = {"card": _card("CSVE1C_PSY", "Basic Energy", "P"), "target": "slot:gardevoir"}
	elif state_name == "pivot":
		selected_kind = "retreat"
		selected_route = "route:pivot"
		selected_ref = {"target": "slot:drifloon"}
	elif state_name == "attack":
		selected_kind = "attack"
		selected_route = "route:attack_ko"
		selected_ref = {
			"attack_index": 1,
			"source": "slot:drifloon",
			"source_card": _card("CSV2C_060", "Pokemon"),
			"projected_damage": 180,
			"projected_knockout": true,
		}
	return [
		{
			"candidate_id": "candidate:rule_top",
			"route_id": "route:information" if state_name != "attach" else "route:energy_commit",
			"safe_prefix_action_id": "action:rule_top",
			"action_kind": "use_ability" if state_name != "attach" else "attach_energy",
			"action_ref": {
				"ability_index": 0,
				"source": "slot:munkidori",
				"source_card": _card("CSV8C_094", "Pokemon"),
			} if state_name != "attach" else {"card": _card("CSVE1C_PSY", "Basic Energy", "P"), "target": "slot:drifloon"},
			"base_score": 6464.176 if state_name != "attach" else 890.4,
			"local_score": 6464.176 if state_name != "attach" else 890.4,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:%s" % state_name,
			"route_id": selected_route,
			"safe_prefix_action_id": "action:%s" % state_name,
			"action_kind": selected_kind,
			"action_ref": selected_ref,
			"checkpoint_after": "terminal" if state_name == "attack" else "action_resolved" if state_name in ["attach", "pivot"] else "information_result",
			"base_score": 350.0,
			"local_score": 350.0,
			"outcome": {"win_now": false, "prizes_now": 2 if state_name == "attack" else 0, "estimated_damage": 180 if state_name == "attack" else 0},
		},
	]


func _observation(state_name: String) -> Dictionary:
	var active_uid := "CSV2C_060" if state_name == "attack" else "CSV2C_055"
	var active_symbols: Array[String] = []
	var active_damage := 0
	var active_hp := 310
	if state_name == "attach":
		active_symbols = ["P"]
	elif state_name == "attack":
		active_symbols = ["P", "P", "P"]
		active_damage = 60
		active_hp = 10
	else:
		active_symbols = ["P", "P"]
	var active := _slot("slot:%s" % ("drifloon" if state_name == "attack" else "gardevoir"), active_uid, active_symbols, 1 if state_name == "attack" else 2)
	active["damage"] = active_damage
	active["remaining_hp"] = active_hp
	active["max_hp"] = 70 if state_name == "attack" else 310
	var drif_energy_count := int({"attach": 0, "embrace1": 0, "embrace2": 1, "embrace3": 2, "pivot": 3}.get(state_name, 0))
	var drif_symbols: Array[String] = []
	for index: int in drif_energy_count:
		drif_symbols.append("P")
	var drifloon := _slot("slot:drifloon", "CSV2C_060", drif_symbols)
	drifloon["damage"] = int({"attach": 0, "embrace1": 0, "embrace2": 20, "embrace3": 40, "pivot": 60}.get(state_name, 0))
	drifloon["remaining_hp"] = int({"attach": 70, "embrace1": 70, "embrace2": 50, "embrace3": 30, "pivot": 10}.get(state_name, 70))
	drifloon["max_hp"] = 70
	var bench: Array[Dictionary] = []
	if state_name == "attack":
		bench.append(_slot("slot:gardevoir", "CSV2C_055", [], 2))
	else:
		bench.append(drifloon)
	bench.append_array([
		_slot("slot:munkidori", "CSV8C_094", ["D"]),
		_slot("slot:munkidori2", "CSV8C_094"),
		_slot("slot:cleffa", "CSV4C_044"),
		_slot("slot:budew", "CSV9.5C_004"),
	])
	var hand: Array[Dictionary] = [_card("CSV1C_112", "Item")]
	if state_name == "attach":
		hand.append(_card("CSVE1C_PSY", "Basic Energy", "P"))
	var discard_count := int({"attach": 3, "embrace1": 3, "embrace2": 2, "embrace3": 1, "pivot": 0, "attack": 0}.get(state_name, 0))
	return {
		"own": {
			"active": active,
			"bench": bench,
			"hand": hand,
			"discard": _psychic_discard(discard_count),
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


func _facts(state_name: String) -> Dictionary:
	return {
		"attack": {"ready": state_name == "attack", "ko_available": state_name == "attack", "max_damage": 180 if state_name == "attack" else 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": state_name == "attach", "supporter_available": true},
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
