class_name V18CPGTeraNoctowlSearch
extends RefCounted

const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")

const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const MODULE_ID := "tera_noctowl_search"
const DEFAULT_LOW_DECK_THRESHOLD := 8
const DEFAULT_CRITICAL_DECK_THRESHOLD := 5
const REGISTERED_STEP_IDS: Array[String] = ["csv9c_noctowl_trainers", "jewel_seeker_cards"]
const REGISTERED_SOURCE_UIDS: Array[String] = ["CSV9C_155", "LEN_SCR_115"]

var _semantic_compiler = SemanticCompilerScript.new()


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	return annotate_frontier_v2(frontier, observation, facts, profile, {})


func annotate_frontier_v2(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	semantic_manifest: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var snapshot := visible_typed_snapshot(observation, facts, profile, semantic_manifest)
	for route: Dictionary in frontier:
		var annotated := route.duplicate(true)
		var annotations: Dictionary = annotated.get("module_annotations", {}) if annotated.get("module_annotations", {}) is Dictionary else {}
		annotations[MODULE_ID] = route_annotation(route, snapshot, profile, _action_for_route(route, observation))
		annotated["module_annotations"] = annotations
		result.append(annotated)
	return result


func visible_typed_snapshot(
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary = {},
	semantic_manifest: Dictionary = {}
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) if turn.get("quotas", {}) is Dictionary else {}
	var parameters := _parameters(profile)
	var typed_energy := {"G": 0, "W": 0, "P": 0, "M": 0, "L": 0, "F": 0, "D": 0, "other": 0}
	var slots: Array = []
	if own.get("active", {}) is Dictionary and not (own.get("active", {}) as Dictionary).is_empty():
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		for raw_energy: Variant in (raw_slot as Dictionary).get("energy", []):
			if not (raw_energy is Dictionary):
				continue
			var symbol := _energy_symbol(raw_energy as Dictionary)
			typed_energy[symbol] = int(typed_energy.get(symbol, 0)) + 1
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var low_threshold := int(parameters.get("low_deck_threshold", DEFAULT_LOW_DECK_THRESHOLD))
	var critical_threshold := int(parameters.get("critical_deck_threshold", DEFAULT_CRITICAL_DECK_THRESHOLD))
	var energy_handoff := _energy_handoff_snapshot(observation, parameters, semantic_manifest)
	var stadium: Dictionary = observation.get("stadium", {}) \
		if observation.get("stadium", {}) is Dictionary else {}
	var visible_basic_develop_uids: Array[String] = []
	for raw_action: Variant in observation.get("legal_actions", []):
		if not (raw_action is Dictionary) \
				or str((raw_action as Dictionary).get("kind", "")) != "play_basic_to_bench":
			continue
		var action_card: Dictionary = (raw_action as Dictionary).get("card", {}) \
			if (raw_action as Dictionary).get("card", {}) is Dictionary else {}
		var basic_uid := str(action_card.get("uid", "")).to_upper()
		if basic_uid != "" and basic_uid not in visible_basic_develop_uids:
			visible_basic_develop_uids.append(basic_uid)
	return {
		"tera_ready": bool(facts.get("board", {}).get("has_tera", false)),
		"fan_call_available": bool(facts.get("fan_call", {}).get("available", false)),
		"attack_ready": bool(facts.get("attack", {}).get("ready", false)),
		"ko_available": bool(facts.get("attack", {}).get("ko_available", false)),
		"typed_energy_on_board": typed_energy,
		"distinct_energy_symbols": _distinct_symbol_count(typed_energy),
		"total_energy_on_board": _sum_counts(typed_energy),
		"bench_slots_free": maxi(0, 5 - bench.size()),
		"supporter_available": bool(quotas.get("supporter_available", facts.get("turn", {}).get("supporter_available", false))),
		"energy_attachment_available": bool(quotas.get("energy_available", facts.get("turn", {}).get("energy_available", false))),
		"deck_count": int(own.get("deck_count", 0)),
		"deck_low": int(own.get("deck_count", 0)) <= low_threshold,
		"deck_critical": int(own.get("deck_count", 0)) <= critical_threshold,
		"energy_handoff_live": bool(energy_handoff.get("live", false)),
		"energy_bank_count": int(energy_handoff.get("bank_count", 0)),
		"energy_handoff_target_count": int(energy_handoff.get("target_count", 0)),
		"threatened_energy_source_count": int(energy_handoff.get("threatened_source_count", 0)),
		"stadium_uid": str(stadium.get("uid", "")).to_upper(),
		"visible_basic_develop_uids": visible_basic_develop_uids,
	}


func route_annotation(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary = {},
	action: Dictionary = {}
) -> Dictionary:
	var route_id := str(route.get("route_id", ""))
	var pair_roles := _pair_roles_for_route(route_id, profile)
	var parameters := _parameters(profile)
	var action_card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	var action_roles: Array = route.get("action_semantic_roles", []) \
		if route.get("action_semantic_roles", []) is Array else []
	var verified_mover_uids: Array = parameters.get("verified_energy_mover_uids", []) \
		if parameters.get("verified_energy_mover_uids", []) is Array else []
	var action_uid := str(action_card.get("uid", "")).to_upper()
	var verified_energy_handoff := bool(parameters.get("verify_energy_handoff_from_end_turn", false)) \
		and route_id == "route:accelerate" \
		and "energy_mover" in action_roles \
		and (verified_mover_uids.is_empty() or action_uid in verified_mover_uids) \
		and bool(snapshot.get("energy_handoff_live", false)) \
		and not bool(snapshot.get("attack_ready", false)) \
		and not bool(snapshot.get("ko_available", false))
	var expansion_stadium_uids := _upper_string_array(parameters.get("tera_expansion_stadium_uids", []))
	var expansion_target_uids := _upper_string_array(parameters.get("tera_expansion_target_priority", []))
	var visible_basic_uids: Array = snapshot.get("visible_basic_develop_uids", []) \
		if snapshot.get("visible_basic_develop_uids", []) is Array else []
	var followup_basic_count := 0
	for basic_uid: Variant in visible_basic_uids:
		if str(basic_uid) != action_uid:
			followup_basic_count += 1
	var verified_tera_capacity := bool(parameters.get("verify_tera_expansion_from_hand", false)) \
		and route_id == "route:develop" \
		and str(action.get("kind", "")) == "play_basic_to_bench" \
		and action_uid in expansion_target_uids \
		and str(snapshot.get("stadium_uid", "")) in expansion_stadium_uids \
		and not bool(snapshot.get("tera_ready", false)) \
		and int(snapshot.get("bench_slots_free", 0)) == 1 \
		and followup_basic_count > 0 \
		and not bool(snapshot.get("attack_ready", false)) \
		and not bool(snapshot.get("ko_available", false))
	var commit_symbol := _energy_symbol(action_card) if str(action.get("kind", "")) == "attach_energy" else ""
	var board_counts: Dictionary = snapshot.get("typed_energy_on_board", {}) if snapshot.get("typed_energy_on_board", {}) is Dictionary else {}
	var priority: Array = parameters.get("typed_energy_priority", []) if parameters.get("typed_energy_priority", []) is Array else []
	var executable := true
	var warning := ""
	if route_id == "route:noctowl_search":
		executable = bool(snapshot.get("tera_ready", false)) and bool(snapshot.get("fan_call_available", false))
		if not bool(snapshot.get("tera_ready", false)):
			warning = "tera_condition_missing"
		elif not bool(snapshot.get("fan_call_available", false)):
			warning = "fan_call_unavailable"
		elif bool(snapshot.get("attack_ready", false)) and bool(snapshot.get("ko_available", false)):
			warning = "optional_search_after_ko_ready"
		elif bool(snapshot.get("deck_low", false)):
			warning = "low_deck_search_risk"
	return {
		"module": MODULE_ID,
		"route_id": route_id,
		"executable": executable,
		"warning": warning,
		"route_pair_roles": pair_roles,
		"tera_ready": bool(snapshot.get("tera_ready", false)),
		"fan_call_available": bool(snapshot.get("fan_call_available", false)),
		"attack_ready": bool(snapshot.get("attack_ready", false)),
		"ko_available": bool(snapshot.get("ko_available", false)),
		"typed_energy_on_board": snapshot.get("typed_energy_on_board", {}),
		"distinct_energy_symbols": int(snapshot.get("distinct_energy_symbols", 0)),
		"commit_energy_symbol": commit_symbol,
		"adds_distinct_energy_symbol": commit_symbol != "" and int(board_counts.get(commit_symbol, 0)) == 0,
		"typed_energy_priority_rank": priority.find(commit_symbol) if commit_symbol != "" else -1,
		"total_energy_on_board": int(snapshot.get("total_energy_on_board", 0)),
		"bench_slots_free": int(snapshot.get("bench_slots_free", 0)),
		"supporter_available": bool(snapshot.get("supporter_available", false)),
		"energy_attachment_available": bool(snapshot.get("energy_attachment_available", false)),
		"deck_low": bool(snapshot.get("deck_low", false)),
		"deck_critical": bool(snapshot.get("deck_critical", false)),
		"energy_handoff_live": bool(snapshot.get("energy_handoff_live", false)),
		"energy_bank_count": int(snapshot.get("energy_bank_count", 0)),
		"energy_handoff_target_count": int(snapshot.get("energy_handoff_target_count", 0)),
		"threatened_energy_source_count": int(snapshot.get("threatened_energy_source_count", 0)),
		"visible_basic_followup_count": followup_basic_count,
		"verified_advantage": verified_energy_handoff or verified_tera_capacity,
		"verified_advantage_kind": "banked_energy_handoff" if verified_energy_handoff \
			else "tera_capacity_from_hand" if verified_tera_capacity else "",
		"verified_interaction_owner": "module_verified" if verified_energy_handoff \
			else "not_required" if verified_tera_capacity else "",
	}


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var parameters := _parameters(profile)
	var outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	if bool(outcome.get("terminal", false)) \
		or str(selected.get("checkpoint_after", "")) == "terminal":
		return {"verified": false}
	var all_annotations: Dictionary = selected.get("module_annotations", {}) \
		if selected.get("module_annotations", {}) is Dictionary else {}
	var annotation: Dictionary = all_annotations.get(MODULE_ID, {}) \
		if all_annotations.get(MODULE_ID, {}) is Dictionary else {}
	var advantage_kind := str(annotation.get("verified_advantage_kind", ""))
	if advantage_kind == "banked_energy_handoff":
		if not bool(parameters.get("verify_energy_handoff_from_end_turn", false)) \
				or str(local_top.get("route_id", "")) not in ["route:end_turn", "route:information", "route:develop"] \
				or str(selected.get("route_id", "")) != "route:accelerate" \
				or bool(facts.get("attack", {}).get("ready", false)) \
				or bool(facts.get("attack", {}).get("ko_available", false)) \
				or int(facts.get("resources", {}).get("energy_on_board", 0)) <= 0 \
				or str(annotation.get("verified_interaction_owner", "")) != "module_verified":
			return {"verified": false}
		return {
			"verified": true,
			"reason": "banked_energy_handoff_before_end_turn",
			"certificate_kind": "public_board_energy_handoff",
			"interaction_owner": "module_verified",
		}
	if advantage_kind == "tera_capacity_from_hand":
		if not bool(parameters.get("verify_tera_expansion_from_hand", false)) \
				or str(local_top.get("route_id", "")) not in ["route:end_turn", "route:information", "route:develop"] \
				or str(selected.get("route_id", "")) != "route:develop" \
				or bool(facts.get("board", {}).get("has_tera", false)) \
				or int(facts.get("resources", {}).get("bench_slots_free", 0)) != 1 \
				or int(annotation.get("visible_basic_followup_count", 0)) <= 0 \
				or str(annotation.get("verified_interaction_owner", "")) != "not_required":
			return {"verified": false}
		return {
			"verified": true,
			"reason": "tera_from_hand_unlocks_immediate_bench_capacity",
			"certificate_kind": "public_stadium_immediate_capacity",
			"interaction_owner": "not_required",
		}
	if bool(parameters.get("verify_distinct_typed_energy_attachment", false)) \
			and str(selected.get("route_id", "")) == "route:energy_commit" \
			and bool(facts.get("turn", {}).get("energy_available", false)):
		var top_annotations: Dictionary = local_top.get("module_annotations", {}) \
			if local_top.get("module_annotations", {}) is Dictionary else {}
		var top_annotation: Dictionary = top_annotations.get(MODULE_ID, {}) \
			if top_annotations.get(MODULE_ID, {}) is Dictionary else {}
		var selected_rank := int(annotation.get("typed_energy_priority_rank", -1))
		var top_rank := int(top_annotation.get("typed_energy_priority_rank", -1))
		var selected_adds := bool(annotation.get("adds_distinct_energy_symbol", false))
		var top_adds := bool(top_annotation.get("adds_distinct_energy_symbol", false))
		if selected_adds and not top_adds \
				and selected_rank >= 0 \
				and (top_rank < 0 or selected_rank < top_rank):
			return {
				"verified": true,
				"reason": "distinct_public_typed_energy_before_duplicate",
				"certificate_kind": "public_distinct_energy_coverage",
				"interaction_owner": "not_required",
			}
	return {"verified": false}


func verified_pair_role_upgrade(
	selected_roles: Array,
	rule_roles: Array,
	profile: Dictionary,
	current_route_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var selected_combo := _role_only_combo(selected_roles)
	var rule_combo := _role_only_combo(rule_roles)
	var selected_score := _combination_score(selected_combo, profile, current_route_id, context)
	var rule_score := _combination_score(rule_combo, profile, current_route_id, context)
	var margin := float(_parameters(profile).get("verified_pair_switch_margin", 120.0))
	return {
		"verified": selected_score >= rule_score + margin,
		"selected_score": selected_score,
		"rule_score": rule_score,
		"certificate_kind": "public_complementary_search_pair",
	}


func handles_step(step: Dictionary, context: Dictionary = {}) -> bool:
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	if step_id in REGISTERED_STEP_IDS:
		return true
	var pending_card: Variant = context.get("pending_effect_card", null)
	if pending_card is CardInstance and (pending_card as CardInstance).card_data != null:
		var data := (pending_card as CardInstance).card_data
		return data.get_uid().to_upper() in REGISTERED_SOURCE_UIDS
	return false


func pick_pair(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	semantic_manifest: Dictionary,
	current_route_id: String
) -> Array:
	var min_select := int(step.get("min_select", 0))
	var max_select := mini(int(step.get("max_select", 2)), 2)
	var typed_facts: Dictionary = context.get("v18cpg_facts", {}) if context.get("v18cpg_facts", {}) is Dictionary else {}
	var resource_facts: Dictionary = typed_facts.get("resources", {}) if typed_facts.get("resources", {}) is Dictionary else {}
	var parameters := _parameters(profile)
	if min_select == 0 \
		and bool(resource_facts.get("deck_critical", false)) \
		and bool(parameters.get("allow_explicit_empty_when_deck_critical", true)):
		return []
	if items.is_empty() or max_select <= 0:
		return []
	var candidates: Array[Dictionary] = []
	for index: int in items.size():
		var data := _card_data(items[index])
		if data == null:
			continue
		candidates.append({
			"item": items[index],
			"index": index,
			"stable_id": _stable_id(items[index]),
			"roles": _semantic_compiler.roles_for_card_data(data, semantic_manifest),
		})
	if candidates.is_empty():
		return []
	var best: Array = []
	var best_score := -INF
	for first_index: int in candidates.size():
		var single: Array = [candidates[first_index]]
		var single_score := _combination_score(single, profile, current_route_id, context)
		if min_select <= 1 and single_score > best_score:
			best_score = single_score
			best = single
		if max_select < 2:
			continue
		for second_index: int in range(first_index + 1, candidates.size()):
			var pair: Array = [candidates[first_index], candidates[second_index]]
			var pair_score := _combination_score(pair, profile, current_route_id, context)
			if pair_score > best_score or (is_equal_approx(pair_score, best_score) and _combo_key(pair) < _combo_key(best)):
				best_score = pair_score
				best = pair
	var result: Array = []
	for candidate: Dictionary in best:
		result.append(candidate.get("item"))
	if result.size() < min_select:
		for candidate: Dictionary in candidates:
			var item: Variant = candidate.get("item")
			if item not in result:
				result.append(item)
			if result.size() >= min_select:
				break
	return result


func verify_pair_override(
	proposed: Array,
	rule_selection: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	semantic_manifest: Dictionary,
	current_route_id: String
) -> bool:
	if _selection_key(proposed) == _selection_key(rule_selection):
		return true
	var parameters := _parameters(profile)
	var typed_facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var resources: Dictionary = typed_facts.get("resources", {}) \
		if typed_facts.get("resources", {}) is Dictionary else {}
	if proposed.is_empty():
		return int(step.get("min_select", 0)) == 0 \
			and bool(resources.get("deck_critical", false)) \
			and bool(parameters.get("allow_explicit_empty_when_deck_critical", true))
	var proposed_candidates := _selection_candidates(proposed, semantic_manifest)
	var rule_candidates := _selection_candidates(rule_selection, semantic_manifest)
	if proposed_candidates.is_empty():
		return false
	var proposed_score := _combination_score(proposed_candidates, profile, current_route_id, context)
	var rule_score := _combination_score(rule_candidates, profile, current_route_id, context) \
		if not rule_candidates.is_empty() else 0.0
	return proposed_score >= rule_score + float(parameters.get("verified_pair_switch_margin", 120.0))


func pick_verified_basic_search_override(
	items: Array,
	step: Dictionary,
	rule_selection: Array,
	context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var parameters := _parameters(profile)
	if not bool(parameters.get("verify_tera_expansion_basic_search", false)) \
			or str(step.get("id", "")).strip_edges().to_lower() != "basic_pokemon" \
			or int(step.get("max_select", 1)) <= 0:
		return {"handled": false, "items": []}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	if bool(facts.get("board", {}).get("has_tera", false)) \
			or int(facts.get("resources", {}).get("bench_slots_free", 0)) != 1:
		return {"handled": false, "items": []}
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var stadium: Dictionary = observation.get("stadium", {}) \
		if observation.get("stadium", {}) is Dictionary else {}
	var stadium_uids := _upper_string_array(parameters.get("tera_expansion_stadium_uids", []))
	if str(stadium.get("uid", "")).to_upper() not in stadium_uids:
		return {"handled": false, "items": []}
	var target_priority := _upper_string_array(parameters.get("tera_expansion_target_priority", []))
	var selected: Variant = null
	for wanted_uid: String in target_priority:
		for item: Variant in items:
			if _item_uid(item) == wanted_uid and _item_is_basic_pokemon(item):
				selected = item
				break
		if selected != null:
			break
	if selected == null:
		return {"handled": false, "items": []}
	if rule_selection.size() == 1 and _stable_id(rule_selection[0]) == _stable_id(selected):
		return {"handled": false, "items": []}
	return {
		"handled": true,
		"items": [selected],
		"reason": "tera_expansion_adds_three_bench_slots",
		"certificate_kind": "public_stadium_board_capacity",
	}


func verified_energy_handoff_target_score(
	item: Variant,
	step: Dictionary,
	profile: Dictionary
) -> Variant:
	if str(step.get("id", "")).strip_edges().to_lower() != "energy_assignment" \
			or not (item is PokemonSlot):
		return null
	var priority := _upper_string_array(
		_parameters(profile).get("energy_rescue_target_priority", [])
	)
	var uid := _item_uid(item)
	var rank := priority.find(uid)
	if rank < 0:
		return -2400.0
	return 12000.0 - float(rank) * 900.0


func _selection_candidates(items: Array, semantic_manifest: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in items.size():
		var data := _card_data(items[index])
		if data == null:
			continue
		result.append({
			"item": items[index],
			"index": index,
			"stable_id": _stable_id(items[index]),
			"roles": _semantic_compiler.roles_for_card_data(data, semantic_manifest),
		})
	return result


func _role_only_combo(roles: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in roles.size():
		var raw_roles: Variant = roles[index]
		result.append({
			"item": null,
			"index": index,
			"stable_id": "role:%d" % index,
			"roles": (raw_roles as Array).duplicate() if raw_roles is Array else [str(raw_roles)],
		})
	return result


func _selection_key(items: Array) -> String:
	var ids: Array[String] = []
	for item: Variant in items:
		ids.append(_stable_id(item))
	ids.sort()
	return "|".join(ids)


func _combination_score(
	combo: Array,
	profile: Dictionary,
	current_route_id: String,
	context: Dictionary
) -> float:
	var score := float(combo.size()) * 10.0
	var union_roles: Array[String] = []
	for raw_candidate: Variant in combo:
		if not (raw_candidate is Dictionary):
			continue
		for raw_role: Variant in (raw_candidate as Dictionary).get("roles", []):
			var role := str(raw_role)
			if role != "" and not union_roles.has(role):
				union_roles.append(role)
	var pair_preferences: Variant = _pair_roles_for_route(current_route_id, profile)
	if pair_preferences is Array:
		for preference_index: int in (pair_preferences as Array).size():
			var raw_pair: Variant = (pair_preferences as Array)[preference_index]
			if not (raw_pair is Array):
				continue
			var complete := true
			for raw_role: Variant in raw_pair as Array:
				if str(raw_role) not in union_roles:
					complete = false
					break
			if complete:
				score += 900.0 - float(preference_index) * 80.0
				if (raw_pair as Array).size() == 2 and _roles_are_distributed(combo, str((raw_pair as Array)[0]), str((raw_pair as Array)[1])):
					score += 180.0
				elif (raw_pair as Array).size() == 2:
					score -= 110.0
	var route_roles := _route_required_roles(current_route_id)
	for role: String in route_roles:
		if role in union_roles:
			score += 260.0
		else:
			score -= 80.0
	var turn_contract: Variant = context.get("turn_contract", {})
	if turn_contract is Dictionary:
		var constraints: Variant = (turn_contract as Dictionary).get("constraints", {})
		if constraints is Dictionary and bool((constraints as Dictionary).get("forbid_engine_churn", false)) and "draw_engine" in union_roles:
			score -= 120.0
	var typed_facts: Dictionary = context.get("v18cpg_facts", {}) if context.get("v18cpg_facts", {}) is Dictionary else {}
	var turn_facts: Dictionary = typed_facts.get("turn", {}) if typed_facts.get("turn", {}) is Dictionary else {}
	var attack_facts: Dictionary = typed_facts.get("attack", {}) if typed_facts.get("attack", {}) is Dictionary else {}
	var board_facts: Dictionary = typed_facts.get("board", {}) if typed_facts.get("board", {}) is Dictionary else {}
	var parameters := _parameters(profile)
	if not bool(turn_facts.get("supporter_available", true)) and "supporter" in union_roles:
		score -= float(parameters.get("supporter_unavailable_penalty", 800.0))
	if bool(attack_facts.get("ready", false)) and bool(attack_facts.get("ko_available", false)):
		var churn_roles: Array = parameters.get("secured_attack_churn_roles", ["energy_access", "energy_mover", "draw_engine", "pokemon_search"])
		var preserve_roles: Array = parameters.get("secured_attack_preserve_roles", ["gust", "recovery", "pivot"])
		for raw_role: Variant in churn_roles:
			if str(raw_role) in union_roles:
				score -= float(parameters.get("secured_attack_churn_penalty", 600.0))
		for raw_role: Variant in preserve_roles:
			if str(raw_role) in union_roles:
				score += float(parameters.get("secured_attack_preserve_bonus", 400.0))
	if bool(board_facts.get("bench_full", false)) and "pokemon_search" in union_roles:
		if "stadium" in union_roles:
			score += float(parameters.get("full_bench_expansion_pair_bonus", 700.0))
		else:
			score -= float(parameters.get("full_bench_dead_search_penalty", 900.0))
	var resource_facts: Dictionary = typed_facts.get("resources", {}) if typed_facts.get("resources", {}) is Dictionary else {}
	if bool(resource_facts.get("deck_low", false)):
		for role: String in ["draw_engine", "pokemon_search", "energy_access"]:
			if role in union_roles:
				score -= float(parameters.get("low_deck_search_role_penalty", 360.0))
		for role: String in ["recovery", "pivot", "gust"]:
			if role in union_roles:
				score += float(parameters.get("low_deck_preserve_role_bonus", 260.0))
	var typed_observation: Dictionary = context.get("v18cpg_observation", {}) if context.get("v18cpg_observation", {}) is Dictionary else {}
	if not typed_observation.is_empty() \
		and "energy_mover" in union_roles \
		and bool(parameters.get("energy_mover_requires_board_energy", true)) \
		and _visible_board_energy_count(typed_observation) <= 0:
		score -= float(parameters.get("dead_energy_mover_penalty", 1000.0))
	if combo.size() == 2:
		var first_roles: Array = (combo[0] as Dictionary).get("roles", []) if combo[0] is Dictionary else []
		var second_roles: Array = (combo[1] as Dictionary).get("roles", []) if combo[1] is Dictionary else []
		if first_roles == second_roles:
			score -= 90.0
	return score


func _roles_are_distributed(combo: Array, first_role: String, second_role: String) -> bool:
	for first_index: int in combo.size():
		if not (combo[first_index] is Dictionary):
			continue
		var first_roles: Array = (combo[first_index] as Dictionary).get("roles", [])
		if first_role not in first_roles:
			continue
		for second_index: int in combo.size():
			if second_index == first_index or not (combo[second_index] is Dictionary):
				continue
			var second_roles: Array = (combo[second_index] as Dictionary).get("roles", [])
			if second_role in second_roles:
				return true
	return false


func _route_required_roles(route_id: String) -> Array[String]:
	match route_id:
		"route:attack_ko", "route:attack_pressure", "route:energy_commit", "route:accelerate":
			return ["energy_access", "supporter_acceleration"]
		"route:pivot":
			return ["pivot"]
		"route:develop", "route:evolve", "route:stadium":
			return ["pokemon_search", "stadium"]
	return ["search_engine"]


func _pair_roles_for_route(route_id: String, profile: Dictionary) -> Array:
	var parameters := _parameters(profile)
	var by_route: Variant = parameters.get("pair_roles_by_route", {})
	if by_route is Dictionary and (by_route as Dictionary).get(route_id, []) is Array:
		return ((by_route as Dictionary).get(route_id, []) as Array).duplicate(true)
	var defaults: Variant = profile.get("noctowl_pair_roles", [])
	return (defaults as Array).duplicate(true) if defaults is Array else []


func _parameters(profile: Dictionary) -> Dictionary:
	var all_parameters: Variant = profile.get("module_parameters", {})
	if not (all_parameters is Dictionary):
		return {}
	var parameters: Variant = (all_parameters as Dictionary).get(MODULE_ID, {})
	return parameters as Dictionary if parameters is Dictionary else {}


func _energy_symbol(card: Dictionary) -> String:
	return EnergySymbolsScript.from_card(card)


func _sum_counts(counts: Dictionary) -> int:
	var total := 0
	for value: Variant in counts.values():
		total += int(value)
	return total


func _distinct_symbol_count(counts: Dictionary) -> int:
	var result := 0
	for key: Variant in counts.keys():
		if str(key) != "other" and int(counts.get(key, 0)) > 0:
			result += 1
	return result


func _action_for_route(route: Dictionary, observation: Dictionary) -> Dictionary:
	var wanted := str(route.get("safe_prefix_action_id", ""))
	for raw_action: Variant in observation.get("legal_actions", []):
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == wanted:
			return raw_action as Dictionary
	return {}


func _energy_handoff_snapshot(
	observation: Dictionary,
	parameters: Dictionary,
	semantic_manifest: Dictionary
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var bank_uids := _upper_string_array(parameters.get("energy_bank_uids", []))
	var target_uids := _upper_string_array(parameters.get("energy_handoff_target_uids", []))
	var rescue_source_uids := _upper_string_array(parameters.get("energy_rescue_source_uids", []))
	if target_uids.is_empty() or bank_uids.is_empty() and rescue_source_uids.is_empty():
		return {
			"live": false,
			"bank_count": 0,
			"target_count": 0,
			"threatened_source_count": 0,
		}
	var slots: Array = []
	if own.get("active", {}) is Dictionary and not (own.get("active", {}) as Dictionary).is_empty():
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	var bank_count := 0
	var target_count := 0
	var threatened_source_count := 0
	var minimum_bank_energy := int(parameters.get("energy_handoff_min_bank_energy", 1))
	var maximum_target_energy := int(parameters.get("energy_handoff_max_target_energy", 0))
	var active_hp_threshold := int(parameters.get("energy_rescue_active_hp_threshold", 60))
	var minimum_opponent_energy := int(parameters.get("energy_rescue_min_opponent_energy", 2))
	var opponent_energy := _visible_side_energy_count(opponent)
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
		var uid := str(pokemon.get("uid", "")).to_upper()
		var energy_count := int(slot.get("energy_count", 0))
		if uid in bank_uids and energy_count >= minimum_bank_energy:
			bank_count += 1
		if raw_slot == own.get("active", {}) \
				and uid in rescue_source_uids \
				and energy_count >= minimum_bank_energy \
				and int(slot.get("remaining_hp", 0)) <= active_hp_threshold \
				and opponent_energy >= minimum_opponent_energy:
			threatened_source_count += 1
		if uid in target_uids and energy_count <= maximum_target_energy:
			# The bounded profile UID list is the typed target contract.  Requiring
			# the generic semantic compiler to rediscover every toolbox attacker
			# would incorrectly exclude cards such as Bloodmoon Ursaluna ex.
			target_count += 1
	return {
		"live": (bank_count > 0 or threatened_source_count > 0) and target_count > 0,
		"bank_count": bank_count,
		"target_count": target_count,
		"threatened_source_count": threatened_source_count,
	}


func _upper_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var item := str(raw).strip_edges().to_upper()
			if item != "" and not result.has(item):
				result.append(item)
	return result


func _visible_side_energy_count(side: Dictionary) -> int:
	var total := 0
	if side.get("active", {}) is Dictionary:
		total += int((side.get("active", {}) as Dictionary).get("energy_count", 0))
	if side.get("bench", []) is Array:
		for raw_slot: Variant in side.get("bench", []):
			if raw_slot is Dictionary:
				total += int((raw_slot as Dictionary).get("energy_count", 0))
	return total


func _visible_board_energy_count(observation: Dictionary) -> int:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var total := 0
	if own.get("active", {}) is Dictionary:
		total += int((own.get("active", {}) as Dictionary).get("energy_count", ((own.get("active", {}) as Dictionary).get("energy", []) as Array).size() if (own.get("active", {}) as Dictionary).get("energy", []) is Array else 0))
	for raw_slot: Variant in own.get("bench", []):
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		total += int(slot.get("energy_count", (slot.get("energy", []) as Array).size() if slot.get("energy", []) is Array else 0))
	return total


func _card_data(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is CardData:
		return item as CardData
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	if item is Dictionary:
		var card: Variant = (item as Dictionary).get("card", null)
		if card is CardInstance:
			return (card as CardInstance).card_data
		if card is CardData:
			return card as CardData
	return null


func _item_uid(item: Variant) -> String:
	var data := _card_data(item)
	return data.get_uid().to_upper() if data != null else ""


func _item_is_basic_pokemon(item: Variant) -> bool:
	var data := _card_data(item)
	return data != null and data.is_basic_pokemon()


func _stable_id(item: Variant) -> String:
	if item is CardInstance:
		var card := item as CardInstance
		return "%s:%d" % [card.card_data.get_uid() if card.card_data != null else "", card.instance_id]
	var data := _card_data(item)
	return data.get_uid() if data != null else str(item)


func _combo_key(combo: Array) -> String:
	var ids: Array[String] = []
	for raw_candidate: Variant in combo:
		if raw_candidate is Dictionary:
			ids.append(str((raw_candidate as Dictionary).get("stable_id", "")))
	ids.sort()
	return "|".join(ids)
