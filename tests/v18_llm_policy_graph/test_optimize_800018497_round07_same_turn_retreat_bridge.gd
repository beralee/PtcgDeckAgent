extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	_check(int(profile.get("profile_version", 0)) >= 8, "round07 profile must be active")
	_test_exact_retreat_bridge_route(profile)
	_test_route_negative_boundaries(profile)
	_test_embrace_target_bridge(profile)
	_test_local_gate_interaction_bridge(profile)
	_test_profile_isolation()
	if _failures.is_empty():
		print("V18CPG 800018497 round07 same-turn retreat bridge: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_retreat_bridge_route(profile: Dictionary) -> void:
	var frontier := _frontier()
	var facts := _facts()
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, _route_observation(), facts, profile, {})
	var bridge := _bridge(annotated[1])
	_check(bool(bridge.get("advances_profiled_retreat_bridge", false)), "Darkness must bank one public retreat unit on Active Kirlia before Arven evolves it")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "candidate:dark_active", "the paired retreat bridge must beat the Rule Arven root")
	_check(str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "profiled_same_turn_retreat_bridge", "the route must expose the exact round07 certificate")
	_check(str(upgrade.get("verified_advantage", {}).get("evidence_kind", "")) == "paired_evaluation", "the route is paired evidence rather than a universal proof")


func _test_route_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var tail_empty := _route_observation()
	tail_empty["own"]["bench"][2]["energy"] = []
	cases.append({"label": "Scream Tail lacks Psychic", "observation": tail_empty, "facts": _facts()})
	var wrong_hp := _route_observation()
	wrong_hp["opponent"]["active"]["remaining_hp"] = 100
	cases.append({"label": "opponent HP differs", "observation": wrong_hp, "facts": _facts()})
	var wrong_prizes := _route_observation()
	wrong_prizes["own"]["prizes_remaining"] = 5
	cases.append({"label": "own prizes differ", "observation": wrong_prizes, "facts": _facts()})
	var missing_hand := _route_observation()
	missing_hand["own"]["hand"] = (missing_hand["own"]["hand"] as Array).filter(
		func(card: Dictionary) -> bool: return str(card.get("uid", "")) != "CSV8C_094"
	)
	cases.append({"label": "Munkidori missing", "observation": missing_hand, "facts": _facts()})
	var active_charged := _route_observation()
	active_charged["own"]["active"]["energy"] = [_card("CSVE1C_PSY", "Basic Energy", "P")]
	cases.append({"label": "Active already charged", "observation": active_charged, "facts": _facts()})
	var supporter_spent := _facts()
	supporter_spent["turn"]["supporter_available"] = false
	cases.append({"label": "supporter spent", "observation": _route_observation(), "facts": supporter_spent})
	var attack_ready := _facts()
	attack_ready["attack"]["ready"] = true
	cases.append({"label": "attack already ready", "observation": _route_observation(), "facts": attack_ready})
	for invalid: Dictionary in cases:
		var annotated := CapabilityRegistryScript.new().annotate_frontier(
			_frontier(), invalid.get("observation", {}), invalid.get("facts", {}), profile, {}
		)
		_check(not bool(_bridge(annotated[1]).get("advances_profiled_retreat_bridge", false)), "%s must block the paired retreat bridge" % str(invalid.get("label", "invalid")))


func _test_embrace_target_bridge(profile: Dictionary) -> void:
	var engine := _pokemon_slot("Gardevoir ex", "CSV2C", "055", "D")
	var tail := _pokemon_slot("Scream Tail", "CSV6C", "065", "P")
	var context := {
		"v18cpg_observation": _interaction_observation(),
		"v18cpg_facts": _facts(),
	}
	var override := CapabilityRegistryScript.new().pick_verified_interaction_override(
		[tail, engine],
		{"id": "embrace_target", "min_select": 1, "max_select": 1},
		[tail],
		context,
		profile,
		"profiled_same_turn_retreat_bridge"
	)
	_check(bool(override.get("handled", false)) and override.get("items", []) == [engine], "Psychic Embrace must target Active Gardevoir to finish the same-turn retreat cost")
	_check(str(override.get("certificate_kind", "")) == "profiled_same_turn_retreat_bridge_target", "the interaction must expose its own audited target certificate")

	var no_dark := _interaction_observation()
	no_dark["own"]["active"]["energy"] = []
	context["v18cpg_observation"] = no_dark
	_check(not bool(CapabilityRegistryScript.new().pick_verified_interaction_override(
		[tail, engine], {"id": "embrace_target", "max_select": 1}, [tail], context, profile, ""
	).get("handled", false)), "without the manually banked Darkness the Embrace override must be unavailable")
	var no_discard := _interaction_observation()
	no_discard["own"]["discard"] = []
	context["v18cpg_observation"] = no_discard
	_check(not bool(CapabilityRegistryScript.new().pick_verified_interaction_override(
		[tail, engine], {"id": "embrace_target", "max_select": 1}, [tail], context, profile, ""
	).get("handled", false)), "without public Psychic fuel the Embrace override must be unavailable")
	context["v18cpg_observation"] = _interaction_observation()
	_check(not bool(CapabilityRegistryScript.new().pick_verified_interaction_override(
		[tail, engine], {"id": "switch_target", "max_select": 1}, [tail], context, profile, ""
	).get("handled", false)), "an unrelated interaction step must not inherit the bridge target")


func _test_local_gate_interaction_bridge(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_current_action_owner", "local_gate")
	strategy.set("_last_observation", _interaction_observation())
	strategy.set("_last_facts", _facts())
	var engine := _pokemon_slot("Gardevoir ex", "CSV2C", "055", "D")
	var tail := _pokemon_slot("Scream Tail", "CSV6C", "065", "P")
	var selected := strategy.pick_interaction_items(
		[tail, engine], {"id": "embrace_target", "min_select": 1, "max_select": 1}, {}
	)
	_check(selected == [engine], "a verified-local local_gate action must retain access to the exact strategic interaction bridge")


func _test_profile_isolation() -> void:
	var academy := ProfileCatalogScript.get_profile_for_deck(800018498)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(_frontier(), _route_observation(), _facts(), academy, {})
	_check(not bool(_bridge(annotated[1]).get("advances_profiled_retreat_bridge", false)), "the Academy profile must not inherit standard Gardevoir's retreat bridge")


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:arven",
			"route_id": "route:tutor",
			"safe_prefix_action_id": "action:arven",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV1C_123", "Supporter")},
			"base_score": 787.6,
			"local_score": 787.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:dark_active",
			"route_id": "route:energy_commit",
			"safe_prefix_action_id": "action:dark_active",
			"action_kind": "attach_energy",
			"action_ref": {"card": _card("CSVE1C_DAR", "Basic Energy", "D"), "target": "slot:active"},
			"base_score": 384.384,
			"local_score": 384.384,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _route_observation() -> Dictionary:
	var tail := _slot("slot:tail", "CSV6C_065")
	tail["energy"] = [_card("CSVE1C_PSY", "Basic Energy", "P")]
	return {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 29,
			"hand": [
				_card("CSV1C_123", "Supporter"),
				_card("CSV3C_123", "Supporter"),
				_card("CSVE1C_DAR", "Basic Energy", "D"),
				_card("CSV8C_094", "Pokemon"),
			],
			"discard": [_card("CSVE1C_PSY", "Basic Energy", "P")],
			"active": _slot("slot:active", "CS6.5C_030"),
			"bench": [
				_slot("slot:clefairy", "CSV10C_082"),
				_slot("slot:ralts", "CSV2C_053"),
				tail,
				_slot("slot:mew", "151C_151"),
			],
		},
		"opponent": {
			"prizes_remaining": 6,
			"active": _opponent_active(),
			"bench": [],
		},
	}


func _interaction_observation() -> Dictionary:
	var observation := _route_observation()
	observation["own"]["active"] = _slot("slot:active", "CSV2C_055")
	observation["own"]["active"]["energy"] = [_card("CSVE1C_DAR", "Basic Energy", "D")]
	return observation


func _opponent_active() -> Dictionary:
	var active := _slot("slot:opponent", "CSV6C_051", 2)
	active["remaining_hp"] = 90
	active["max_hp"] = 230
	active["damage"] = 140
	return active


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _bridge(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("gardevoir_embrace", {}).get("profiled_retreat_bridge", {})


func _pokemon_slot(name: String, set_code: String, card_index: String, symbol: String) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card_instance(name, "Pokemon", set_code, card_index))
	slot.attached_energy.append(_energy_instance(symbol))
	return slot


func _card_instance(name: String, type_name: String, set_code: String, card_index: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = type_name
	data.set_code = set_code
	data.card_index = card_index
	return CardInstance.create(data, 0)


func _energy_instance(symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = "%s Energy" % symbol
	data.name_en = data.name
	data.card_type = "Basic Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	data.set_code = "CSVE1C"
	data.card_index = "DAR" if symbol == "D" else "PSY"
	return CardInstance.create(data, 0)


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
		"remaining_hp": 110,
		"max_hp": 110,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
