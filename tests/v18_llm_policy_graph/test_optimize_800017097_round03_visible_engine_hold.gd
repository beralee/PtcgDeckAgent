extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800017097)
	_check(int(profile.get("profile_version", 0)) >= 4, "round03 profile must be active")
	_test_exact_engine_hold(profile)
	_test_secret_box_interaction_and_gust_stage(profile)
	_test_negative_boundaries(profile)
	_test_profile_isolation()
	if _failures.is_empty():
		print("V18CPG 800017097 round03 visible engine hold: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_engine_hold(profile: Dictionary) -> void:
	var facts := _facts()
	var annotated := CapabilityRegistryScript.new().annotate_frontier(_frontier(), _observation(), facts, profile, {})
	var hold := _hold(annotated[1])
	_check(bool(hold.get("advances_profiled_engine_hold", false)), "the exact visible engine hand must use Secret Box to find the public attack-denial line before redundant churn")
	_check(int(hold.get("psychic_energy_in_discard", 0)) == 5, "the certificate must record the exact public Psychic fuel")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "candidate:secret_box", "the paired preservation route must beat the Ultra Ball Rule root")
	_check(str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "profiled_visible_engine_hold", "the route must expose the exact round03 certificate")
	_check(str(upgrade.get("verified_advantage", {}).get("evidence_kind", "")) == "paired_evaluation", "the hold must not be mislabeled as deterministic proof")


func _test_secret_box_interaction_and_gust_stage(profile: Dictionary) -> void:
	var counter_catcher := _card_instance("Counter Catcher", "Item", "CSV6C", "114")
	var ultra_ball := _card_instance("Ultra Ball", "Item", "CSV1C", "112")
	var context := {
		"v18cpg_observation": _observation(),
		"v18cpg_facts": _facts(),
	}
	var registry := CapabilityRegistryScript.new()
	var item_override := registry.pick_verified_interaction_override(
		[ultra_ball, counter_catcher],
		{"id": "search_item", "min_select": 1, "max_select": 1},
		[ultra_ball],
		context,
		profile,
		"profiled_visible_engine_hold"
	)
	_check(bool(item_override.get("handled", false)) and item_override.get("items", []) == [counter_catcher], "Secret Box must fetch Counter Catcher directly instead of the Rule Ultra Ball")

	var post_box := _post_box_observation()
	var post_box_frontier: Array[Dictionary] = [
		{
			"candidate_id": "candidate:iono",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:iono",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV3C_123", "Supporter")},
			"base_score": 35.6,
			"local_score": 35.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:counter_catcher",
			"route_id": "route:gust",
			"safe_prefix_action_id": "action:counter_catcher",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV6C_114", "Item")},
			"base_score": -55.2,
			"local_score": -55.2,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	var annotated := registry.annotate_frontier(post_box_frontier, post_box, _facts(), profile, {})
	_check(str(_hold(annotated[1]).get("stage", "")) == "counter_catcher_access", "the exact post-Box hand must advance to the gust stage")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	_check(str(strategy._find_module_verified_upgrade(annotated, _facts()).get("candidate_id", "")) == "candidate:counter_catcher", "Counter Catcher must execute before Iono changes the public hand")

	var miraidon := _pokemon_slot("Miraidon ex", "CSV1C", "050")
	var bloodmoon := _pokemon_slot("Bloodmoon Ursaluna ex", "CSV8C", "172")
	context["v18cpg_observation"] = post_box
	var gust_override := registry.pick_verified_interaction_override(
		[miraidon, bloodmoon],
		{"id": "opponent_bench_target", "min_select": 1, "max_select": 1},
		[miraidon],
		context,
		profile,
		"profiled_visible_engine_hold"
	)
	_check(bool(gust_override.get("handled", false)) and gust_override.get("items", []) == [bloodmoon], "Counter Catcher must isolate the zero-Energy Bloodmoon instead of a free-pivot target")

	var post_gust := _post_gust_observation()
	var attacker_search_frontier: Array[Dictionary] = [
		{
			"candidate_id": "candidate:iono_lock",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:iono_lock",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV3C_123", "Supporter")},
			"base_score": 35.6,
			"local_score": 35.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:ultra_attacker",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:ultra_attacker",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV1C_112", "Item")},
			"base_score": -20.0,
			"local_score": -20.0,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	annotated = registry.annotate_frontier(attacker_search_frontier, post_gust, _facts(), profile, {})
	_check(str(_hold(annotated[1]).get("stage", "")) == "ultra_ball_attacker_search", "the post-gust checkpoint must identify the protected Drifloon search")
	_check(str(strategy._find_module_verified_upgrade(annotated, _facts()).get("candidate_id", "")) == "candidate:ultra_attacker", "the protected Ultra Ball line must build Drifloon before Iono")

	var artazon := _card_instance("Artazon", "Stadium", "CSV2C", "127")
	var iono := _card_instance("Iono", "Supporter", "CSV3C", "123")
	var charm := _card_instance("Bravery Charm", "Tool", "CSV1C", "118")
	var gardevoir := _card_instance("Gardevoir ex", "Pokemon", "CSV2C", "055")
	context["v18cpg_observation"] = post_gust
	var discard_override := registry.pick_verified_interaction_override(
		[gardevoir, artazon, iono, charm],
		{"id": "discard_cards", "min_select": 2, "max_select": 2},
		[iono, charm],
		context,
		profile,
		"profiled_visible_engine_hold"
	)
	_check(bool(discard_override.get("handled", false)) and discard_override.get("items", []) == [artazon, charm], "Ultra Ball must preserve Gardevoir and Iono while paying its exact cost")
	var clefairy := _card_instance("Lillie's Clefairy ex", "Pokemon", "CSV10C", "082")
	var drifloon := _card_instance("Drifloon", "Pokemon", "CSV2C", "060")
	var search_override := registry.pick_verified_interaction_override(
		[drifloon, clefairy],
		{"id": "search_pokemon", "min_select": 0, "max_select": 1},
		[drifloon],
		context,
		profile,
		"profiled_visible_engine_hold"
	)
	_check(bool(search_override.get("handled", false)) and search_override.get("items", []) == [clefairy], "Ultra Ball must fetch the public in-deck Clefairy attacker")

	var post_ultra := _post_ultra_observation()
	var bench_frontier: Array[Dictionary] = [
		{
			"candidate_id": "candidate:iono_before_bench",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:iono_before_bench",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV3C_123", "Supporter")},
			"base_score": 35.6,
			"local_score": 35.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:bench_clefairy",
			"route_id": "route:develop",
			"safe_prefix_action_id": "action:bench_clefairy",
			"action_kind": "play_basic_to_bench",
			"action_ref": {"card": _card("CSV10C_082", "Pokemon")},
			"base_score": 195.56,
			"local_score": 195.56,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	annotated = registry.annotate_frontier(bench_frontier, post_ultra, _facts(), profile, {})
	_check(str(_hold(annotated[1]).get("stage", "")) == "bench_damage_scaler", "the searched Clefairy must reach the Bench before Iono")

	var post_bench := _post_bench_observation()
	var engine_frontier: Array[Dictionary] = [
		bench_frontier[0],
		{
			"candidate_id": "candidate:evolve_gardevoir",
			"route_id": "route:evolve",
			"safe_prefix_action_id": "action:evolve_gardevoir",
			"action_kind": "evolve",
			"action_ref": {"card": _card("CSV2C_055", "Pokemon"), "target": "slot:kirlia"},
			"base_score": 1480.0,
			"local_score": 1480.0,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	annotated = registry.annotate_frontier(engine_frontier, post_bench, _facts(), profile, {})
	_check(str(_hold(annotated[1]).get("stage", "")) == "evolve_embrace_engine", "Gardevoir must evolve before the hand lock")

	var post_engine := _post_engine_observation()
	var lock_frontier: Array[Dictionary] = [
		{
			"candidate_id": "candidate:fez_before_lock",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:fez_before_lock",
			"action_kind": "use_ability",
			"action_ref": {},
			"base_score": 71.58,
			"local_score": 71.58,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:iono_lock",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:iono_lock",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV3C_123", "Supporter")},
			"base_score": 35.6,
			"local_score": 35.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	annotated = registry.annotate_frontier(lock_frontier, post_engine, _facts(), profile, {})
	_check(str(_hold(annotated[1]).get("stage", "")) == "iono_hand_lock", "Iono must lock the seven-card opponent hand after the attacker and engine are public")
	_check(str(strategy._find_module_verified_upgrade(annotated, _facts()).get("candidate_id", "")) == "candidate:iono_lock", "Iono must execute before Fezandipiti draw")

	var post_draw := _post_draw_observation()
	var post_draw_facts := _facts()
	post_draw_facts["turn"]["supporter_available"] = false
	var pivot_frontier: Array[Dictionary] = [
		{
			"candidate_id": "candidate:dark_clefairy",
			"route_id": "route:energy_commit",
			"safe_prefix_action_id": "action:dark_clefairy",
			"action_kind": "attach_energy",
			"action_ref": {"card": _card("CSVE1C_DAR", "Basic Energy", "D"), "target": "slot:clefairy"},
			"base_score": 554.4,
			"local_score": 554.4,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:dark_active",
			"route_id": "route:energy_commit",
			"safe_prefix_action_id": "action:dark_active",
			"action_kind": "attach_energy",
			"action_ref": {"card": _card("CSVE1C_DAR", "Basic Energy", "D"), "target": "slot:active"},
			"base_score": 346.528,
			"local_score": 346.528,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]
	annotated = registry.annotate_frontier(pivot_frontier, post_draw, post_draw_facts, profile, {})
	_check(str(_hold(annotated[1]).get("stage", "")) == "bank_active_retreat_energy", "the manual Darkness must pay half of Active Munkidori's next-turn retreat")
	_check(str(strategy._find_module_verified_upgrade(annotated, post_draw_facts).get("candidate_id", "")) == "candidate:dark_active", "the retreat Energy must beat an unrelated Clefairy attachment")


func _test_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var wrong_deck := _observation()
	wrong_deck["own"]["deck_count"] = 17
	cases.append({"label": "deck count differs", "observation": wrong_deck, "facts": _facts()})
	var missing_engine := _observation()
	missing_engine["own"]["hand"] = (missing_engine["own"]["hand"] as Array).filter(func(card: Dictionary) -> bool: return str(card.get("uid", "")) != "CSV2C_055")
	cases.append({"label": "Gardevoir missing", "observation": missing_engine, "facts": _facts()})
	var extra_hand := _observation()
	extra_hand["own"]["hand"].append(_card("CSV3C_123", "Supporter"))
	cases.append({"label": "extra hand card", "observation": extra_hand, "facts": _facts()})
	var wrong_bench := _observation()
	wrong_bench["own"]["bench"][0] = _slot("slot:cleffa", "CSV2C_053")
	cases.append({"label": "bench identity differs", "observation": wrong_bench, "facts": _facts()})
	var active_charged := _observation()
	active_charged["own"]["active"]["energy"] = [_card("CSVE1C_DAR", "Basic Energy", "D")]
	cases.append({"label": "Active already charged", "observation": active_charged, "facts": _facts()})
	var wrong_discard := _observation()
	wrong_discard["own"]["discard"].remove_at(0)
	cases.append({"label": "Psychic fuel differs", "observation": wrong_discard, "facts": _facts()})
	var wrong_prizes := _observation()
	wrong_prizes["opponent"]["prizes_remaining"] = 2
	cases.append({"label": "opponent prize clock differs", "observation": wrong_prizes, "facts": _facts()})
	var attack_ready := _facts()
	attack_ready["attack"]["ready"] = true
	cases.append({"label": "attack already ready", "observation": _observation(), "facts": attack_ready})
	for invalid: Dictionary in cases:
		var annotated := CapabilityRegistryScript.new().annotate_frontier(_frontier(), invalid.get("observation", {}), invalid.get("facts", {}), profile, {})
		_check(not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)), "%s must block the paired hold" % str(invalid.get("label", "invalid")))


func _test_profile_isolation() -> void:
	for deck_id: int in [800018497, 800018498]:
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		var annotated := CapabilityRegistryScript.new().annotate_frontier(_frontier(), _observation(), _facts(), profile, {})
		_check(not bool(_hold(annotated[1]).get("advances_profiled_engine_hold", false)), "%d must not inherit the no-balloon paired hold" % deck_id)


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:ultra_ball",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:ultra_ball",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV1C_112", "Item")},
			"base_score": 639.2,
			"local_score": 639.2,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:secret_box",
			"route_id": "route:information",
			"safe_prefix_action_id": "action:secret_box",
			"action_kind": "play_trainer",
			"action_ref": {"card": _card("CSV8C_176", "Item")},
			"base_score": 231.6,
			"local_score": 231.6,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _observation() -> Dictionary:
	return {
		"own": {
			"prizes_remaining": 4,
			"deck_count": 18,
			"hand": [
				_card("CSV8C_094", "Pokemon"),
				_card("CSV2C_055", "Pokemon"),
				_card("CSV1C_121", "Supporter"),
				_card("CSV8C_176", "Item"),
				_card("CSV1C_112", "Item"),
				_card("CSV6C_125", "Supporter"),
			],
			"discard": _psychic_discard(5),
			"active": _slot("slot:active", "CSV8C_094"),
			"bench": [
				_slot("slot:cleffa", "CSV4C_044"),
				_slot("slot:fez", "CSV8C_135", 2, ["P"]),
				_slot("slot:kirlia", "CS6.5C_030"),
			],
		},
		"opponent": {
			"prizes_remaining": 1,
			"active": _opponent_active(),
			"bench": [],
		},
	}


func _post_box_observation() -> Dictionary:
	var observation := _observation()
	observation["own"]["deck_count"] = 14
	observation["own"]["hand"] = [
		_card("CSV2C_055", "Pokemon"),
		_card("CSV1C_112", "Item"),
		_card("CSV6C_114", "Item"),
		_card("CSV1C_118", "Tool"),
		_card("CSV3C_123", "Supporter"),
		_card("CSV2C_127", "Stadium"),
	]
	return observation


func _post_gust_observation() -> Dictionary:
	var observation := _post_box_observation()
	observation["own"]["hand"] = [
		_card("CSV2C_055", "Pokemon"),
		_card("CSV1C_112", "Item"),
		_card("CSV1C_118", "Tool"),
		_card("CSV3C_123", "Supporter"),
		_card("CSV2C_127", "Stadium"),
	]
	observation["opponent"]["active"] = _opponent_active_with("CSV8C_172", 260, 0)
	return observation


func _post_ultra_observation() -> Dictionary:
	var observation := _post_gust_observation()
	observation["own"]["deck_count"] = 13
	observation["own"]["hand"] = [
		_card("CSV2C_055", "Pokemon"),
		_card("CSV3C_123", "Supporter"),
		_card("CSV10C_082", "Pokemon"),
	]
	return observation


func _post_bench_observation() -> Dictionary:
	var observation := _post_ultra_observation()
	observation["own"]["hand"] = [
		_card("CSV2C_055", "Pokemon"),
		_card("CSV3C_123", "Supporter"),
	]
	observation["own"]["bench"].append(_slot("slot:clefairy", "CSV10C_082"))
	return observation


func _post_engine_observation() -> Dictionary:
	var observation := _post_bench_observation()
	observation["own"]["hand"] = [_card("CSV3C_123", "Supporter")]
	for index: int in (observation["own"]["bench"] as Array).size():
		if str(observation["own"]["bench"][index]["pokemon"].get("uid", "")) == "CS6.5C_030":
			observation["own"]["bench"][index]["pokemon"] = {"uid": "CSV2C_055"}
			break
	return observation


func _post_draw_observation() -> Dictionary:
	var observation := _post_bench_observation()
	observation["own"]["deck_count"] = 9
	observation["own"]["hand"] = [
		_card("CSVE1C_DAR", "Basic Energy", "D"),
		_card("CSV2C_055", "Pokemon"),
	]
	observation["own"]["discard"] = _psychic_discard(6)
	return observation


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 4, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _hold(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("gardevoir_embrace", {}).get("profiled_engine_hold", {})


func _opponent_active() -> Dictionary:
	return _opponent_active_with("CSV6C_051", 230, 3)


func _opponent_active_with(uid: String, hp: int, energy_count: int) -> Dictionary:
	var active := _slot("slot:opponent", uid, 2)
	active["remaining_hp"] = hp
	active["max_hp"] = hp
	for index: int in energy_count:
		active["energy"].append(_card("energy:l%d" % index, "Basic Energy", "L"))
	active["energy_count"] = energy_count
	return active


func _psychic_discard(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in count:
		result.append({"uid": "discard:p%d" % index, "type": "Basic Energy", "energy_type": "P"})
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


func _slot(slot_id: String, uid: String, prize_count: int = 1, symbols: Array[String] = []) -> Dictionary:
	var energy: Array[Dictionary] = []
	for symbol: String in symbols:
		energy.append(_card("energy:%s" % symbol, "Basic Energy", symbol))
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": energy,
		"damage": 0,
		"remaining_hp": 110,
		"max_hp": 110,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
