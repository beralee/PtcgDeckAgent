extends SceneTree

const EnergyBurstScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const FactBuilderScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd")

var _module = EnergyBurstScript.new()
var _profile: Dictionary = {}
var _failures: Array[String] = []


func _init() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(800018509)
	_round_01_minimum_ko_discard()
	_round_02_preserve_next_attacker_energy()
	_round_03_typed_attack_cost()
	_round_04_sada_acceleration_liveness()
	_round_05_optional_draw_churn_guard()
	_round_06_low_deck_guard()
	_round_07_bench_slot_reservation()
	_round_08_payable_gust_closeout()
	_round_09_frontier_annotation_identity()
	_round_10_hidden_information_firewall()
	if _failures.is_empty():
		print("Raging Bolt V18CPG 10-round fixtures: PASS (10/10)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _round_01_minimum_ko_discard() -> void:
	var plan := _module.discard_plan(280, 7, 2, 70)
	_check(int(plan.get("discard_count", -1)) == 4, "round01: 280 HP must consume exactly four energy")
	_check(int(plan.get("remaining_energy", -1)) == 3, "round01: minimum KO must leave three attached energy")


func _round_02_preserve_next_attacker_energy() -> void:
	var plan := _module.discard_plan(280, 5, 2, 70)
	_check(not bool(plan.get("payable", true)), "round02: a KO that breaks the two-energy reserve is not safely payable")
	_check(int(plan.get("discard_count", -1)) == 3, "round02: the reserve-aware plan must never over-discard")
	_check(not bool(_module.discard_plan(0, 5, 2, 70).get("payable", true)), "round02: an unknown or absent target is never a payable KO")


func _round_03_typed_attack_cost() -> void:
	var observation := _observation(20, [_slot("slot:bolt", "Raging Bolt ex", [_energy("L"), _energy("F")])], 230)
	var snapshot := _module.visible_energy_snapshot(observation, _profile)
	_check(bool(snapshot.get("primary_cost_ready", false)), "round03: lightning plus fighting must satisfy the typed attack cost")
	var missing_fighting := _observation(20, [_slot("slot:bolt", "Raging Bolt ex", [_energy("L"), _energy("G")])], 230)
	_check(not bool(_module.visible_energy_snapshot(missing_fighting, _profile).get("primary_cost_ready", true)), "round03: grass cannot replace fighting in the attack cost")
	var split_cost := _observation(20, [
		_slot("slot:active_bolt", "Raging Bolt ex", [_energy("L")]),
		_slot("slot:bench_bolt", "Raging Bolt ex", [_energy("F")]),
	], 230)
	_check(not bool(_module.visible_energy_snapshot(split_cost, _profile).get("primary_cost_ready", true)), "round03: attack cost energy cannot be assembled across two Pokemon")
	var localized := _observation(20, [_slot("slot:localized", "任意本地化显示名", [])], 230)
	localized["own"]["active"]["pokemon"]["effect_id"] = "e96bb407c5f18bb9eec55487e70395fd"
	_check(int(_module.visible_energy_snapshot(localized, _profile).get("ancient_acceleration_targets", 0)) == 1, "round03: stable effect identity must survive localization changes")
	var special_energy := {"name": "Jet Energy", "type": "Special Energy", "energy_provides": "C"}
	var mixed := _observation(20, [_slot("slot:mixed", "Raging Bolt ex", [_energy("L"), _energy("F"), special_energy])], 230)
	_check(int(_module.visible_energy_snapshot(mixed, _profile).get("total_basic_attached", -1)) == 2, "round03: special energy cannot be counted as burst discard fuel")


func _round_04_sada_acceleration_liveness() -> void:
	var observation := _observation(20, [_slot("slot:bolt", "Raging Bolt ex", [])], 230)
	observation["own"]["discard"] = [_energy("F")]
	_check(bool(_module.acceleration_status(observation, _profile).get("sada_live", false)), "round04: Sada is live with a discarded basic energy and an Ancient target")
	observation["own"]["discard"] = []
	_check(not bool(_module.acceleration_status(observation, _profile).get("sada_live", true)), "round04: Sada is dead without discard energy")


func _round_05_optional_draw_churn_guard() -> void:
	var facts := {"attack": {"ready": true, "ko_available": true}}
	_check(not _module.should_take_optional_information(facts, 30, _profile), "round05: optional draw must stop once a KO is secured")


func _round_06_low_deck_guard() -> void:
	var facts := {"attack": {"ready": false, "ko_available": false}}
	_check(not _module.should_take_optional_information(facts, 8, _profile), "round06: optional draw is unsafe below the deck threshold")
	_check(_module.should_take_optional_information(facts, 20, _profile), "round06: information remains available with a healthy deck")
	var builder = FactBuilderScript.new()
	_check(bool(builder.build(_observation(10, [], 230), "", _profile).get("resources", {}).get("deck_low", false)), "round06: shared facts must honor the profile threshold at ten cards")
	_check(not bool(builder.build(_observation(11, [], 230), "", _profile).get("resources", {}).get("deck_low", true)), "round06: eleven cards must remain outside the low-deck band")


func _round_07_bench_slot_reservation() -> void:
	var slots := [
		_slot("slot:a", "Raging Bolt ex", [_energy("L"), _energy("F")]),
		_slot("slot:b", "Teal Mask Ogerpon ex", [_energy("G")]),
		_slot("slot:c", "Hoothoot", []),
		_slot("slot:d", "Mew ex", []),
		_slot("slot:e", "Fezandipiti ex", []),
	]
	var observation := _observation(20, slots, 230)
	var route := _route("route:develop", "action:bench")
	var action := {"id": "action:bench", "kind": "play_basic_to_bench", "card": {"name": "Fezandipiti ex"}}
	observation["legal_actions"] = [action]
	var annotation := _module.route_annotation(route, action, observation, {"attack": {"ready": false, "ko_available": false}}, _profile)
	_check(not bool(annotation.get("bench_reserve_met", true)), "round07: the last bench slot is reserved for the attacker/engine chain")


func _round_08_payable_gust_closeout() -> void:
	var slots := [
		_slot("slot:bolt", "Raging Bolt ex", [_energy("L"), _energy("F")]),
		_slot("slot:ogerpon", "Teal Mask Ogerpon ex", [_energy("G"), _energy("G"), _energy("G")]),
		_slot("slot:reserve", "Raging Bolt ex", [_energy("L"), _energy("F")]),
	]
	var observation := _observation(20, slots, 210)
	observation["opponent"]["bench"] = [_slot("slot:two_prize", "Bench ex", [], 210)]
	var route := _route("route:gust", "action:gust")
	var action := {"id": "action:gust", "kind": "play_trainer", "card": {"name": "Boss's Orders"}, "target": "slot:two_prize"}
	observation["legal_actions"] = [action]
	var annotation := _module.route_annotation(route, action, observation, {"attack": {"ready": true, "ko_available": true}}, _profile)
	_check(bool(annotation.get("target_known", false)), "round08: a bound gust target must be explicit")
	_check(bool(annotation.get("ko_payable_with_reserve", false)), "round08: gust closeout is payable when three discards leave the two-energy reserve")
	var unresolved := action.duplicate(true)
	unresolved.erase("target")
	var unresolved_annotation := _module.route_annotation(route, unresolved, observation, {"attack": {"ready": true, "ko_available": true}}, _profile)
	_check(not bool(unresolved_annotation.get("ko_payable_with_reserve", true)), "round08: an unresolved gust target cannot claim a payable KO")


func _round_09_frontier_annotation_identity() -> void:
	var observation := _observation(20, [_slot("slot:bolt", "Raging Bolt ex", [_energy("L"), _energy("F"), _energy("G"), _energy("G"), _energy("G")])], 140)
	observation["legal_actions"] = [{
		"id": "action:attack",
		"kind": "attack",
		"source_card": {"name": "Raging Bolt ex"},
		"projected_damage": 140,
		"projected_knockout": true,
	}]
	var annotated := _module.annotate_frontier([_route("route:attack_ko", "action:attack")], observation, {"attack": {"ready": true, "ko_available": true}}, _profile)
	var energy_burst: Dictionary = annotated[0].get("module_annotations", {}).get("energy_burst", {})
	_check(str(energy_burst.get("source_pokemon", "")) == "Raging Bolt ex", "round09: frontier annotation must retain the visible source identity")
	_check(int(energy_burst.get("minimum_discards_for_active_ko", -1)) == 2, "round09: route annotation must expose the exact KO tier")
	_check(str(energy_burst.get("decision_hint", "")) == "commit_minimum_resource_ko", "round09: a payable KO must expose a typed minimum-resource decision hint")


func _round_10_hidden_information_firewall() -> void:
	var sentinel := "HIDDEN_PRIZE_SENTINEL"
	var observation := _observation(20, [_slot("slot:bolt", "Raging Bolt ex", [_energy("L"), _energy("F")])], 140)
	# Sentinel is deliberately placed outside the ObservationEnvelope.  A pure
	# module cannot discover it and its annotation must remain sentinel-free.
	var hidden_engine_state := {"own_prize_identities": [sentinel], "deck_order": [sentinel]}
	var annotation := _module.route_annotation(_route("route:attack_ko", "action:attack"), {}, observation, {"attack": {"ready": true, "ko_available": true}}, _profile)
	_check(not JSON.stringify(annotation).contains(sentinel), "round10: energy module leaked a hidden sentinel")
	_check(JSON.stringify(hidden_engine_state).contains(sentinel), "round10: sentinel fixture itself is invalid")
	var five_energy := _observation(20, [_slot("slot:reserve", "Raging Bolt ex", [_energy("L"), _energy("F"), _energy("G"), _energy("G"), _energy("G")])], 140)
	var reserve_annotation := _module.route_annotation(_route("route:attack_ko", "action:attack"), {}, five_energy, {"attack": {"ready": true, "ko_available": true}}, _profile)
	_check(int(reserve_annotation.get("max_safe_discards", -1)) == 2, "round10: non-default three-energy reserve must be consumed, not silently replaced by the module default")


func _observation(deck_count: int, own_slots: Array, opponent_hp: int) -> Dictionary:
	var active: Dictionary = own_slots[0] if not own_slots.is_empty() else {}
	var bench: Array = own_slots.slice(1)
	return {
		"own": {
			"deck_count": deck_count,
			"active": active,
			"bench": bench,
			"discard": [],
		},
		"opponent": {
			"active": _slot("slot:opponent", "Miraidon ex", [], opponent_hp),
			"bench": [],
		},
		"legal_actions": [],
	}


func _slot(slot_id: String, name: String, energy: Array, remaining_hp: int = 230) -> Dictionary:
	var effect_ids := {
		"Raging Bolt ex": "e96bb407c5f18bb9eec55487e70395fd",
		"Slither Wing": "29f94ee004e4c312dbea4a7930d33544",
		"Teal Mask Ogerpon ex": "409898a79b38fe8ca279e7bdaf4fd52e",
	}
	return {
		"slot_id": slot_id,
		"pokemon": {"name": name, "effect_id": str(effect_ids.get(name, ""))},
		"energy": energy,
		"remaining_hp": remaining_hp,
	}


func _energy(symbol: String) -> Dictionary:
	var names := {"L": "Lightning Energy", "F": "Fighting Energy", "G": "Grass Energy"}
	return {
		"name": str(names.get(symbol, "Basic Energy")),
		"type": "Basic Energy",
		"energy_provides": symbol,
	}


func _route(route_id: String, action_id: String) -> Dictionary:
	return {
		"route_id": route_id,
		"macro_action": route_id.trim_prefix("route:"),
		"safe_prefix_action_id": action_id,
		"module_annotations": {},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
