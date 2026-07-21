extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800017097)
	_check(int(profile.get("profile_version", 0)) >= 6, "round05 profile must be active")
	_test_exact_resource_order(profile)
	_test_psychic_discard_bridge(profile)
	_test_second_embrace_damage_step(profile)
	_test_negative_boundaries(profile)
	_test_profile_isolation()
	if _failures.is_empty():
		print("V18CPG 800017097 round05 resource order: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_resource_order(profile: Dictionary) -> void:
	var facts := _facts()
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_frontier(), _observation(), facts, profile, {}
	)
	var hold := _hold(annotated[1])
	_check(
		str(hold.get("stage", "")) == "refinement_before_manual_attachment",
		"the unused Bench Kirlia must refine the visible Psychic before Drifloon takes the manual attachment"
	)
	_check(
		bool(hold.get("advances_profiled_engine_hold", false)),
		"the exact public resource-order state must mint the paired certificate"
	)
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(
		str(upgrade.get("candidate_id", "")) == "candidate:second_refinement",
		"the certified second Refinement must beat the Rule manual attachment"
	)
	_check(
		str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "profiled_visible_engine_hold",
		"resource ordering must stay inside the isolated visible-engine certificate family"
	)


func _test_psychic_discard_bridge(profile: Dictionary) -> void:
	var gardevoir := _card_instance("Gardevoir ex", "Pokemon", "CSV2C", "055")
	var darkness := _card_instance("Darkness Energy", "Basic Energy", "CSVE1C", "DAR")
	var psychic := _card_instance("Psychic Energy", "Basic Energy", "CSVE1C", "PSY")
	var override := CapabilityRegistryScript.new().pick_verified_interaction_override(
		[gardevoir, darkness, psychic],
		{"id": "discard_cards", "min_select": 1, "max_select": 1},
		[darkness],
		{"v18cpg_observation": _observation(), "v18cpg_facts": _facts()},
		profile,
		"profiled_visible_engine_hold"
	)
	_check(
		bool(override.get("handled", false)) and override.get("items", []) == [psychic],
		"Refinement must bank Psychic fuel while preserving Gardevoir ex and Darkness access"
	)
	_check(
		str(override.get("certificate_kind", "")) == "profiled_visible_engine_hold_resource_order",
		"the discard interaction must remain auditable as the exact resource-order bridge"
	)


func _test_second_embrace_damage_step(profile: Dictionary) -> void:
	var facts := _facts()
	facts["attack"]["ready"] = true
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_damage_step_frontier(), _damage_step_observation(), facts, profile, {}
	)
	_check(
		str(_hold(annotated[1]).get("stage", "")) == "second_embrace_before_pivot",
		"one remaining public Psychic must be assigned before Budew pivots into Drifloon"
	)
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	_check(
		str(strategy._find_module_verified_upgrade(annotated, facts).get("candidate_id", "")) == "candidate:second_embrace",
		"the second safe Embrace must beat the premature Rule retreat"
	)
	var gardevoir := _pokemon_slot("Gardevoir ex", "CSV2C", "055")
	var drifloon := _pokemon_slot("Drifloon", "CSV2C", "060")
	var override := CapabilityRegistryScript.new().pick_verified_interaction_override(
		[gardevoir, drifloon],
		{"id": "embrace_target", "min_select": 1, "max_select": 1},
		[gardevoir],
		{"v18cpg_observation": _damage_step_observation(), "v18cpg_facts": facts},
		profile,
		"profiled_visible_engine_hold"
	)
	_check(
		bool(override.get("handled", false)) and override.get("items", []) == [drifloon],
		"the extra Embrace must raise Drifloon's public damage tier rather than damage the engine"
	)
	var wrong_damage := _damage_step_observation()
	wrong_damage["own"]["bench"][1]["damage"] = 40
	wrong_damage["own"]["bench"][1]["remaining_hp"] = 30
	annotated = CapabilityRegistryScript.new().annotate_frontier(
		_damage_step_frontier(), wrong_damage, facts, profile, {}
	)
	_check(
		not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)),
		"the second-Embrace certificate must reject an already changed damage budget"
	)
func _test_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var wrong_deck := _observation()
	wrong_deck["own"]["deck_count"] = 31
	cases.append({"label": "deck count differs", "observation": wrong_deck, "frontier": _frontier()})
	var no_psychic := _observation()
	no_psychic["own"]["hand"] = [
		_card("CSV2C_055", "Pokemon"),
		_card("CSVE1C_DAR", "Basic Energy", "D"),
	]
	cases.append({"label": "Psychic is absent", "observation": no_psychic, "frontier": _frontier()})
	var active_source_frontier := _frontier()
	active_source_frontier[1]["action_ref"]["source"] = "slot:active"
	cases.append({"label": "only the Active Kirlia is selected", "observation": _observation(), "frontier": active_source_frontier})
	for test_case: Dictionary in cases:
		var annotated := CapabilityRegistryScript.new().annotate_frontier(
			test_case.get("frontier", []), test_case.get("observation", {}), _facts(), profile, {}
		)
		_check(
			not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)),
			"resource-order certificate must reject when %s" % str(test_case.get("label", "state differs"))
		)


func _test_profile_isolation() -> void:
	var other_profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		_frontier(), _observation(), _facts(), other_profile, {}
	)
	_check(
		not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)),
		"the no-balloon Gardevoir resource-order certificate must not leak into standard Gardevoir"
	)


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:manual_psychic",
			"route_id": "route:energy_commit",
			"safe_prefix_action_id": "action:attach_psychic",
			"action_kind": "attach_energy",
			"action_ref": {
				"card": _card("CSVE1C_PSY", "Basic Energy", "P"),
				"target": "slot:drifloon",
			},
			"base_score": 480.64,
			"local_score": 480.64,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:second_refinement",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:second_refinement",
			"action_kind": "use_ability",
			"action_ref": {
				"ability_index": 0,
				"source": "slot:bench_kirlia",
				"source_card": _card("CS6.5C_030", "Pokemon"),
			},
			"checkpoint_after": "information_result",
			"base_score": 352.128,
			"local_score": 352.128,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _damage_step_frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:premature_pivot",
			"route_id": "route:pivot",
			"safe_prefix_action_id": "action:pivot_drifloon",
			"action_kind": "retreat",
			"action_ref": {"target": "slot:drifloon"},
			"base_score": 2438.4,
			"local_score": 2438.4,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:second_embrace",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:second_embrace",
			"action_kind": "use_ability",
			"action_ref": {
				"ability_index": 0,
				"source": "slot:gardevoir",
				"source_card": _card("CSV2C_055", "Pokemon"),
			},
			"checkpoint_after": "information_result",
			"base_score": 537.72,
			"local_score": 537.72,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _observation() -> Dictionary:
	return {
		"own": {
			"active": _slot("slot:active", "CS6.5C_030"),
			"bench": [
				_slot("slot:bench_kirlia", "CS6.5C_030"),
				_slot("slot:drifloon", "CSV2C_060", ["P"]),
			],
			"hand": [
				_card("CSV2C_055", "Pokemon"),
				_card("CSVE1C_DAR", "Basic Energy", "D"),
				_card("CSVE1C_PSY", "Basic Energy", "P"),
			],
			"discard": [_card("discard:psychic", "Basic Energy", "P")],
			"deck_count": 32,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _opponent_active(),
			"bench": [],
			"deck_count": 32,
			"prizes_remaining": 6,
		},
	}


func _damage_step_observation() -> Dictionary:
	var active := _slot("slot:active", "CSV9.5C_004")
	active["remaining_hp"] = 30
	active["max_hp"] = 30
	var drifloon := _slot("slot:drifloon", "CSV2C_060", ["P", "P"])
	drifloon["damage"] = 20
	drifloon["remaining_hp"] = 50
	drifloon["max_hp"] = 70
	return {
		"own": {
			"active": active,
			"bench": [
				_slot("slot:gardevoir", "CSV2C_055", [], 2),
				drifloon,
				_slot("slot:ralts", "CSV2C_053"),
			],
			"hand": [_card("CSV3C_123", "Supporter")],
			"discard": [_card("discard:psychic", "Basic Energy", "P")],
			"deck_count": 28,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _opponent_active(3),
			"bench": [],
			"deck_count": 32,
			"prizes_remaining": 4,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _hold(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("gardevoir_embrace", {}).get("profiled_engine_hold", {})


func _opponent_active(energy_count: int = 2) -> Dictionary:
	var symbols: Array[String] = []
	for index: int in energy_count:
		symbols.append("L" if index != 1 else "C")
	var active := _slot("slot:opponent", "CSV6C_051", symbols, 2)
	active["remaining_hp"] = 230
	active["max_hp"] = 230
	active["energy_count"] = energy_count
	return active


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
		energy.append(_card("energy:%s" % symbol, "Basic Energy", symbol))
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": energy,
		"energy_count": energy.size(),
		"damage": 0,
		"remaining_hp": 80,
		"max_hp": 80,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
