extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	_check(int(profile.get("profile_version", 0)) >= 6, "round05 profile must be active")
	_test_public_hand_reset_belief(profile)
	_test_five_stage_public_order(profile)
	_test_nest_ball_interaction(profile)
	_test_exact_negative_boundaries(profile)
	_test_certificate_is_profile_owned()
	if _failures.is_empty():
		print("V18CPG 800018497 round05 search-before-attachment: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_public_hand_reset_belief(profile: Dictionary) -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var before := _search_observation()
	before["own"]["hand"] = [
		_card("CSV3C_123", "Supporter"),
		_card("CSV6C_065", "Pokemon"),
	]
	strategy.set("_last_observation", before)
	strategy.set("_unconsumed_action_result", {
		"success": true,
		"action_kind": "play_trainer",
		"action_card_uid": "CSV3C_123",
	})
	var augmented: Dictionary = strategy._with_public_flow_facts(_facts(true, false), _search_observation())
	_check(int(augmented.get("belief", {}).get("known_in_deck_uid_counts", {}).get("CSV6C_065", 0)) == 1, "a publicly seen Scream Tail removed by Iono must become a one-copy known-in-deck lower bound")
	_check(str(augmented.get("belief", {}).get("evidence_kind", "")) == "public_hand_reset_transition", "the belief must record its public event provenance")


func _test_five_stage_public_order(profile: Dictionary) -> void:
	var search_frontier: Array[Dictionary] = [
		_attach_candidate("candidate:psychic_active", "slot:active", 786.528),
		_card_candidate("candidate:nest_ball", "play_trainer", "route:information", "CSVH1C_043", 383.2),
	]
	var search_facts := _facts(true, true)
	var search_annotated := _annotate(search_frontier, _search_observation(), search_facts, profile)
	_check(str(_setup(search_annotated[1]).get("setup_stage", "")) == "search_attacker_before_attachment", "known-in-deck Scream Tail must make Nest Ball precede the irreversible attachment")
	_check(_upgrade_id(search_annotated, search_facts, profile) == "candidate:nest_ball", "the paired search stage must beat the Rule Active attachment")

	var attach_frontier: Array[Dictionary] = [
		_attach_candidate("candidate:psychic_active", "slot:active", 786.528),
		_attach_candidate("candidate:psychic_tail", "slot:tail", 186.528),
	]
	var benched := _attacker_benched_observation(false)
	var attach_facts := _facts(true, false)
	var attach_annotated := _annotate(attach_frontier, benched, attach_facts, profile)
	_check(str(_setup(attach_annotated[1]).get("setup_stage", "")) == "attach_searched_attacker", "the first Psychic Energy must target the freshly Benched Scream Tail")
	_check(_upgrade_id(attach_annotated, attach_facts, profile) == "candidate:psychic_tail", "the paired attacker attachment must beat the Active Munkidori attachment")

	var preserve_frontier: Array[Dictionary] = [
		_card_candidate("candidate:ultra_ball", "play_trainer", "route:information", "CSV1C_112", 559.2),
		_end_candidate("candidate:end", -924.0),
	]
	var charged := _attacker_benched_observation(true)
	var preserve_facts := _facts(false, false)
	var preserve_annotated := _annotate(preserve_frontier, charged, preserve_facts, profile)
	_check(str(_setup(preserve_annotated[1]).get("setup_stage", "")) == "preserve_followup_pivot_energy", "the sequence must end instead of letting Ultra Ball spend the reserved pivot Energy")
	_check(_upgrade_id(preserve_annotated, preserve_facts, profile) == "candidate:end", "the paired reservation must beat unproven information churn")

	var pivot_frontier: Array[Dictionary] = [
		_attach_candidate("candidate:psychic_other", "slot:mover", 554.4),
		_attach_candidate("candidate:psychic_active", "slot:active", 366.528),
	]
	var pivot_facts := _facts(true, false)
	var pivot_annotated := _annotate(pivot_frontier, charged, pivot_facts, profile)
	_check(str(_setup(pivot_annotated[1]).get("setup_stage", "")) == "attach_active_for_followup_pivot", "the reserved Psychic Energy must pay Active Munkidori's follow-up retreat")
	_check(_upgrade_id(pivot_annotated, pivot_facts, profile) == "candidate:psychic_active", "the paired pivot attachment must beat an unrelated target")

	var retreat_state := charged.duplicate(true)
	retreat_state["own"]["active"]["energy"] = [_card("CSVE1C_PSY", "Basic Energy", "P")]
	var retreat_frontier: Array[Dictionary] = [
		_retreat_candidate("candidate:retreat_mover", "slot:mover", 38.4),
		_retreat_candidate("candidate:retreat_tail", "slot:tail", 38.4),
	]
	var retreat_facts := _facts(false, false)
	var retreat_annotated := _annotate(retreat_frontier, retreat_state, retreat_facts, profile)
	_check(str(_setup(retreat_annotated[1]).get("setup_stage", "")) == "pivot_to_charged_attacker", "the retreat tie must resolve to the charged Scream Tail rather than the empty Munkidori")
	_check(_upgrade_id(retreat_annotated, retreat_facts, profile) == "candidate:retreat_tail", "the paired pivot target must beat the Rule tie order")


func _test_nest_ball_interaction(profile: Dictionary) -> void:
	var scream := _card_instance("Scream Tail", "Pokemon", "CSV6C", "065")
	scream.card_data.stage = "Basic"
	var clefairy := _card_instance("Lillie's Clefairy ex", "Pokemon", "CSV10C", "082")
	clefairy.card_data.stage = "Basic"
	var context := {
		"v18cpg_observation": _search_observation(),
		"v18cpg_facts": _facts(true, true),
	}
	var override := CapabilityRegistryScript.new().pick_verified_interaction_override(
		[clefairy, scream],
		{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
		[clefairy],
		context,
		profile,
		"profiled_search_before_attachment_sequence"
	)
	_check(bool(override.get("handled", false)) and override.get("items", []) == [scream], "Nest Ball must use the same public certificate to put Scream Tail directly on the Bench")
	context["v18cpg_facts"] = _facts(true, false)
	_check(not bool(CapabilityRegistryScript.new().pick_verified_interaction_override(
		[clefairy, scream],
		{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
		[clefairy],
		context,
		profile,
		"profiled_search_before_attachment_sequence"
	).get("handled", false)), "without public known-in-deck evidence the interaction override must be unavailable")


func _test_exact_negative_boundaries(profile: Dictionary) -> void:
	var frontier: Array[Dictionary] = [
		_attach_candidate("candidate:psychic_active", "slot:active", 786.528),
		_card_candidate("candidate:nest_ball", "play_trainer", "route:information", "CSVH1C_043", 383.2),
	]
	var wrong_prizes := _search_observation()
	wrong_prizes["own"]["prizes_remaining"] = 5
	_check(not _advances(frontier, wrong_prizes, _facts(true, true), profile, 1), "the sequence must be restricted to the evaluated six-prize state")
	var wrong_opponent := _search_observation()
	wrong_opponent["opponent"]["active"]["remaining_hp"] = 40
	_check(not _advances(frontier, wrong_opponent, _facts(true, true), profile, 1), "a different public opponent HP tier must block the paired evidence")
	var wrong_active := _search_observation()
	wrong_active["own"]["active"] = _slot("slot:active", "CSV6C_065")
	_check(not _advances(frontier, wrong_active, _facts(true, true), profile, 1), "a non-Munkidori Active must block the sequence")
	var missing_psychic := _search_observation()
	missing_psychic["own"]["hand"] = (missing_psychic["own"]["hand"] as Array).filter(func(card: Dictionary) -> bool: return str(card.get("uid", "")) != "CSVE1C_PSY")
	missing_psychic["own"]["hand"].append(_card("CSVE1C_PSY", "Basic Energy", "P"))
	_check(not _advances(frontier, missing_psychic, _facts(true, true), profile, 1), "two visible Psychic Energy are required for attacker plus next-turn pivot")
	var attack_facts := _facts(true, true)
	attack_facts["attack"]["ready"] = true
	_check(not _advances(frontier, _search_observation(), attack_facts, profile, 1), "an executable attack must block the setup sequence")
	_check(not _advances(frontier, _search_observation(), _facts(true, false), profile, 1), "missing event-derived known-in-deck evidence must block Nest Ball")
	_check(not _advances(frontier, _search_observation(), _facts(false, true), profile, 1), "a spent manual attachment must block the sequence")


func _test_certificate_is_profile_owned() -> void:
	var academy := ProfileCatalogScript.get_profile_for_deck(800018498)
	var frontier: Array[Dictionary] = [
		_attach_candidate("candidate:psychic_active", "slot:active", 786.528),
		_card_candidate("candidate:nest_ball", "play_trainer", "route:information", "CSVH1C_043", 383.2),
	]
	_check(not _advances(frontier, _search_observation(), _facts(true, true), academy, 1), "the academy profile must not inherit standard Gardevoir's paired sequence")


func _search_observation() -> Dictionary:
	var opponent_active := _slot("slot:opponent", "CSV1C_050", 2)
	opponent_active["remaining_hp"] = 30
	opponent_active["max_hp"] = 220
	opponent_active["damage"] = 190
	return {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 31,
			"hand": [
				_card("CSVE1C_PSY", "Basic Energy", "P"),
				_card("CSVH1aC_008", "Item"),
				_card("CSVE1C_PSY", "Basic Energy", "P"),
				_card("CSV1C_112", "Item"),
				_card("CSVH1C_043", "Item"),
				_card("CSV5C_119", "Tool"),
			],
			"discard": _psychic_discard(3),
			"active": _slot("slot:active", "CSV8C_094"),
			"bench": [_slot("slot:mover", "CSV8C_094")],
		},
		"opponent": {"prizes_remaining": 4, "active": opponent_active, "bench": []},
	}


func _attacker_benched_observation(charged: bool) -> Dictionary:
	var observation := _search_observation()
	observation["own"]["hand"] = [
		_card("CSVE1C_PSY", "Basic Energy", "P"),
		_card("CSVH1aC_008", "Item"),
		_card("CSV1C_112", "Item"),
		_card("CSV5C_119", "Tool"),
	]
	if not charged:
		observation["own"]["hand"].insert(0, _card("CSVE1C_PSY", "Basic Energy", "P"))
	var tail := _slot("slot:tail", "CSV6C_065")
	if charged:
		tail["energy"] = [_card("CSVE1C_PSY", "Basic Energy", "P")]
	observation["own"]["bench"].append(tail)
	return observation


func _facts(energy_available: bool, known_attacker: bool) -> Dictionary:
	var facts := {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": energy_available, "supporter_available": false},
	}
	if known_attacker:
		facts["belief"] = {
			"known_in_deck_uid_counts": {"CSV6C_065": 1},
			"evidence_kind": "public_hand_reset_transition",
			"source_action_uid": "CSV3C_123",
		}
	return facts


func _annotate(frontier: Array[Dictionary], observation: Dictionary, facts: Dictionary, profile: Dictionary) -> Array[Dictionary]:
	return CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})


func _advances(frontier: Array[Dictionary], observation: Dictionary, facts: Dictionary, profile: Dictionary, index: int) -> bool:
	return bool(_setup(_annotate(frontier, observation, facts, profile)[index]).get("advances_profiled_attacker_setup", false))


func _upgrade_id(frontier: Array[Dictionary], facts: Dictionary, profile: Dictionary) -> String:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	return str(strategy._find_module_verified_upgrade(frontier, facts).get("candidate_id", ""))


func _setup(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("damage_counter_control", {}).get("profiled_attacker_setup", {})


func _attach_candidate(candidate_id: String, target: String, score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": "route:energy_commit",
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"action_kind": "attach_energy",
		"action_ref": {"card": _card("CSVE1C_PSY", "Basic Energy", "P"), "target": target},
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _card_candidate(candidate_id: String, kind: String, route_id: String, uid: String, score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"action_kind": kind,
		"action_ref": {"card": _card(uid, "Item")},
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _end_candidate(candidate_id: String, score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": "route:end_turn",
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"action_kind": "end_turn",
		"action_ref": {},
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _retreat_candidate(candidate_id: String, target: String, score: float) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": "route:pivot",
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"action_kind": "retreat",
		"action_ref": {"target": target},
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


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


func _psychic_discard(count: int) -> Array:
	var result: Array = []
	for index: int in count:
		result.append({"uid": "discard:p%d" % index, "type": "Basic Energy", "energy_type": "P"})
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
