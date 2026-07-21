extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 18000625
const CERTIFICATE := "profiled_stage2_search_before_pivot"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 3, "round01 requires profile version 3")
	_test_exact_public_epoch(profile)
	_test_fail_closed_boundaries(profile)
	_test_strategy_ownership(profile)
	_test_final_prize_counter_interaction(profile)
	if _failures.is_empty():
		print("V18CPG 18000625 round01 search-before-pivot: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_public_epoch(profile: Dictionary) -> void:
	var result := _certificate(profile, _observation(), _frontier())
	_check(bool(result.get("verified", false)), "exact seed-18000627 public epoch must verify")
	_check(str(result.get("certificate_kind", "")) == CERTIFICATE, "certificate kind changed")
	_check(str(result.get("interaction_owner", "")) == "rules_fallback", "Secret Box choices must remain Rule-owned")
	_check(str(result.get("deferred_pivot_target_uid", "")) == "CSV8C_094", "certificate must bind the dominated Munkidori pivot")


func _test_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var wrong_active := _observation()
	wrong_active["own"]["active"]["pokemon"]["uid"] = "CSV8C_135"
	cases.append({"name": "wrong active", "observation": wrong_active, "frontier": _frontier()})
	var missing_fire := _observation()
	missing_fire["own"]["discard_counts"]["CSVE1C_FIR"] = 1
	cases.append({"name": "missing public Fire fuel", "observation": missing_fire, "frontier": _frontier()})
	var missing_attacker := _observation()
	missing_attacker["own"]["hand"].pop_back()
	missing_attacker["own"]["hand_count"] = 8
	cases.append({"name": "missing Blaziken", "observation": missing_attacker, "frontier": _frontier()})
	var wrong_hp := _observation()
	wrong_hp["opponent"]["active"]["remaining_hp"] = 170
	cases.append({"name": "wrong opponent HP", "observation": wrong_hp, "frontier": _frontier()})
	var wrong_prizes := _observation()
	wrong_prizes["own"]["prizes_remaining"] = 3
	cases.append({"name": "wrong prize epoch", "observation": wrong_prizes, "frontier": _frontier()})
	var closed_window := _observation()
	closed_window["turn"]["deterministic_attack_window_open"] = false
	cases.append({"name": "closed attack window", "observation": closed_window, "frontier": _frontier()})
	var not_rule_exact := _frontier()
	not_rule_exact[1].erase("engine_rule_floor_exact")
	cases.append({"name": "unbound Rule floor", "observation": _observation(), "frontier": not_rule_exact})
	var wrong_rule_target := _frontier()
	wrong_rule_target[1]["action_ref"]["target"] = "slot:torchic"
	cases.append({"name": "wrong deferred pivot", "observation": _observation(), "frontier": wrong_rule_target})
	for fixture: Dictionary in cases:
		var result := _certificate(profile, fixture["observation"], fixture["frontier"])
		_check(not bool(result.get("verified", false)), "%s must fail closed" % fixture["name"])


func _test_strategy_ownership(profile: Dictionary) -> void:
	var annotated := _annotated(profile, _observation(), _frontier())
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(annotated[0], annotated[1], _facts(), profile)
	var upgrade := annotated[0].duplicate(true)
	upgrade["verified_advantage"] = certificate
	var strategy := StrategyScript.new()
	strategy.set("_profile", profile)
	var safety := {"advantage": certificate, "score_gap": 159.2}
	_check(bool(strategy.call("_can_apply_autonomous_module_upgrade", annotated[0], annotated[1], _facts(), safety)), \
		"exact deck-scoped search prefix must be eligible for autonomous ownership")
	_check(bool(strategy.call("_can_apply_initial_module_upgrade", upgrade)), \
		"search prefix must run before the first model request")


func _test_final_prize_counter_interaction(profile: Dictionary) -> void:
	var blaziken := _engine_slot("CSV7C_038", 0, 60)
	var munkidori := _engine_slot("CSV8C_094", 0, 0)
	var iron_hands := _engine_slot("CSV6C_051", 1, 0)
	var raikou := _engine_slot("CS4DaC_137", 1, 30)
	var observation := {
		"turn": {"number": 25, "current_player": 0, "viewer": 0, "deterministic_attack_window_open": true},
		"own": {
			"active": _engine_observation_slot("slot:blaziken", blaziken, 260, 2, [_energy("R"), _energy("R")]),
			"bench": [_engine_observation_slot("slot:munkidori", munkidori, 110, 1, [_energy("D")])],
			"hand": [], "hand_count": 0, "discard_counts": {}, "deck_count": 20, "prizes_remaining": 2,
		},
		"opponent": {
			"active": _engine_observation_slot("slot:iron-hands", iron_hands, 230, 2, []),
			"bench": [_engine_observation_slot("slot:raikou", raikou, 170, 2, [])],
			"prizes_remaining": 3,
		},
	}
	var facts := {
		"attack": {"ready": true, "ko_available": false, "max_damage": 200},
		"prize": {"win_now": false, "current_swing": 0},
		"resources": {"prizes_remaining": 2, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:munkidori",
		"route_id": "route:information",
		"action_kind": "use_ability",
		"action_ref": {
			"source": "slot:munkidori", "source_card": _card("CSV8C_094", "Pokemon"),
			"ability_index": 0, "requires_interaction": true,
		},
		"checkpoint_after": "information_result",
		"base_score": 5802.208,
		"engine_rule_floor_exact": true,
	}, {
		"candidate_id": "candidate:attack",
		"route_id": "route:attack_pressure",
		"action_kind": "attack",
		"action_ref": {"source": "slot:blaziken", "source_card": _card("CSV7C_038", "Pokemon"), "attack_index": 0},
		"checkpoint_after": "terminal",
		"base_score": 3536.4,
	}]
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
	var counter_annotation: Dictionary = annotated[0].get("module_annotations", {}).get("damage_counter_control", {}).get("counter_mover_closeout", {})
	_check(bool(counter_annotation.get("advances_final_prize_closeout", false)), \
		"30 counters plus Blaziken's 200 damage must expose the final two-prize closeout")
	var strategy := StrategyScript.new()
	_check(str(strategy.call("_verified_module_certificate_kind", annotated[0])) \
		== "public_second_counter_mover_final_prize_closeout", \
		"Rule-owned Munkidori root must activate the exact interaction certificate")
	var context := {"v18cpg_observation": observation, "v18cpg_facts": facts}
	var source_step := {"id": "source_pokemon", "min_select": 1, "max_select": 1}
	var registry := CapabilityRegistryScript.new()
	var source_override := registry.pick_verified_interaction_override(
		[blaziken], source_step, [blaziken], context, profile,
		"public_second_counter_mover_final_prize_closeout"
	)
	_check(bool(source_override.get("handled", false)) and source_override.get("items", []).size() == 1 \
		and source_override.get("items", [])[0] == blaziken, \
		"counter closeout must move damage from the active Blaziken")
	var target_step := {
		"id": "target_damage_counters", "ui_mode": "counter_distribution",
		"use_counter_distribution_ui": true, "total_counters": 3,
	}
	var active_score: Variant = registry.verified_interaction_target_score(
		iron_hands, target_step, context, profile, "public_second_counter_mover_final_prize_closeout"
	)
	var bench_score: Variant = registry.verified_interaction_target_score(
		raikou, target_step, context, profile, "public_second_counter_mover_final_prize_closeout"
	)
	_check(active_score != null and float(active_score) >= 1000000.0, \
		"counter distribution must bind the opponent Active with the exact 30-point attack gap")
	_check(bench_score == null, "the damaged Raikou Bench target must not inherit closeout authority")
	var wrong_hp := observation.duplicate(true)
	wrong_hp["opponent"]["active"]["remaining_hp"] = 240
	var blocked_context := {"v18cpg_observation": wrong_hp, "v18cpg_facts": facts}
	_check(registry.verified_interaction_target_score(
		iron_hands, target_step, blocked_context, profile,
		"public_second_counter_mover_final_prize_closeout"
	) == null, "a 40-point gap must fail closed")


func _certificate(profile: Dictionary, observation: Dictionary, frontier: Array) -> Dictionary:
	var annotated := _annotated(profile, observation, frontier)
	if annotated.size() != 2:
		return {"verified": false}
	return CapabilityRegistryScript.new().verify_route_advantage(annotated[0], annotated[1], _facts(), profile)


func _annotated(profile: Dictionary, observation: Dictionary, frontier: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for candidate: Variant in frontier:
		if candidate is Dictionary:
			typed.append(candidate as Dictionary)
	return CapabilityRegistryScript.new().annotate_frontier(typed, observation, _facts(), profile, {})


func _frontier() -> Array:
	return [{
		"candidate_id": "candidate:secret-box",
		"route_id": "route:information",
		"action_kind": "play_trainer",
		"action_ref": {"card": _card("CSV8C_176", "Item")},
		"checkpoint_after": "information_result",
		"base_score": 501.6,
	}, {
		"candidate_id": "candidate:rule-retreat",
		"route_id": "route:pivot",
		"action_kind": "retreat",
		"action_ref": {"target": "slot:backup-munkidori"},
		"checkpoint_after": "action_resolved",
		"base_score": 660.8,
		"engine_rule_floor_exact": true,
	}]


func _observation() -> Dictionary:
	return {
		"turn": {"number": 21, "current_player": 0, "viewer": 0, "deterministic_attack_window_open": true},
		"own": {
			"active": _slot("slot:active", "CSV8C_094", [_energy("D")], 110, 1),
			"bench": [
				_slot("slot:torchic", "CSV10C_036", [_energy("R")], 70, 1),
				_slot("slot:fez", "CSV8C_135", [], 210, 2),
				_slot("slot:pecharunt", "CSV9C_127", [], 80, 1),
				_slot("slot:backup-munkidori", "CSV8C_094", [], 110, 1),
			],
			"hand": [
				_card("CSV8C_176", "Item"), _card("CSV7C_177", "Item"),
				_card("CSV5C_119", "Tool"), _card("CSV9C_127", "Pokemon"),
				_card("CSV8C_094", "Pokemon"), _card("CSV6C_114", "Item"),
				_card("CSV2C_127", "Stadium"), _card("CSV3C_123", "Supporter"),
				_card("CSV7C_038", "Pokemon"),
			],
			"hand_count": 9,
			"discard_counts": {"CSVE1C_FIR": 2, "CSV1C_109": 1},
			"deck_count": 32,
			"prizes_remaining": 4,
		},
		"opponent": {
			"active": _slot("slot:iron-hands", "CSV6C_051", [_energy("L"), _energy("L"), _energy("C")], 160, 2),
			"bench": [],
			"prizes_remaining": 4,
		},
	}


func _slot(slot_id: String, uid: String, energy: Array, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid, "Pokemon"),
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"remaining_hp": remaining_hp,
		"damage": 0,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _card(uid: String, type: String) -> Dictionary:
	return {"uid": uid, "type": type}


func _energy(symbol: String) -> Dictionary:
	return {"uid": "ENERGY_%s" % symbol, "type": "Basic Energy", "energy_type": symbol}


func _engine_slot(uid: String, owner: int, damage: int) -> PokemonSlot:
	var data_path := "res://data/bundled_user/cards/%s.json" % uid
	var data: CardData
	if FileAccess.file_exists(data_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		data = CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()
	else:
		data = CardData.new()
		data.name = uid
		data.name_en = uid
		data.card_type = "Pokemon"
		data.set_code = uid.get_slice("_", 0)
		data.card_index = uid.get_slice("_", 1)
		data.hp = 200
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	slot.damage_counters = damage
	return slot


func _engine_observation_slot(
	slot_id: String,
	slot: PokemonSlot,
	remaining_hp: int,
	prize_count: int,
	energy: Array
) -> Dictionary:
	var top := slot.get_top_card()
	return {
		"slot_id": slot_id,
		"pokemon": {
			"uid": top.card_data.get_uid(), "instance_id": top.instance_id,
			"type": "Pokemon",
		},
		"energy": energy.duplicate(true), "energy_count": energy.size(),
		"remaining_hp": remaining_hp, "damage": slot.damage_counters,
		"prize_count": prize_count, "ability_used": false,
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"prize": {"win_now": false, "current_swing": 0},
		"resources": {"prizes_remaining": 4, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
