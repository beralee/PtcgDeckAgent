class_name V18CPGCyclePivot
extends RefCounted

const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")

const MODULE_ID := "cycle_pivot"


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var maximum_bench := 8 if _area_zero_visible(observation) else 5
	var has_live_attacker_root := _has_visible_uid(observation, _parameters(profile).get("attacker_root_uids", []))
	var top_route_id := str(frontier[0].get("route_id", "")) if not frontier.is_empty() else ""
	for route: Dictionary in frontier:
		var annotated := route.duplicate(true)
		var action := _action_for_route(route, observation)
		var action_card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
		var action_uid := str(action_card.get("uid", ""))
		# RouteSearch already resolved the versioned semantic manifest.  Raw action
		# card refs intentionally do not carry ad-hoc semantic_roles, so never
		# overwrite the compiled route roles with an empty array here.
		var action_roles: Array = route.get("action_semantic_roles", []) \
			if route.get("action_semantic_roles", []) is Array else []
		if action_roles.is_empty() and action_card.get("semantic_roles", []) is Array:
			action_roles = (action_card.get("semantic_roles", []) as Array).duplicate()
		var optional_draw_engine := _is_optional_engine(action_uid, action_roles, _parameters(profile))
		var target_uid := _target_pokemon_uid(action, observation)
		var attachment := _attachment_snapshot(action, observation, profile)
		var pivot := _pivot_snapshot(action, observation)
		var same_ko_attack_resource := _same_ko_attack_resource_snapshot(
			route,
			action,
			observation,
			profile
		)
		var development_rank := _development_rank(action_roles, profile)
		var fallback_uids: Array = _parameters(profile).get("fallback_chip_attacker_uids", []) \
			if _parameters(profile).get("fallback_chip_attacker_uids", []) is Array else []
		var target_is_fallback_chip: bool = fallback_uids.has(target_uid)
		var route_id := str(route.get("route_id", ""))
		annotated["action_card_uid"] = action_uid
		annotated["action_semantic_roles"] = action_roles.duplicate()
		annotated["optional_draw_engine"] = optional_draw_engine
		var warning := _annotation_warning(
			route,
			action,
			top_route_id,
			facts,
			profile,
			bench.size(),
			maximum_bench
		)
		var annotations: Dictionary = annotated.get("module_annotations", {}) \
			if annotated.get("module_annotations", {}) is Dictionary else {}
		annotations[MODULE_ID] = {
			"module": MODULE_ID,
			"route_id": route_id,
			"card_uid": action_uid,
			"card_roles": action_roles.duplicate(),
			"optional_draw_engine": optional_draw_engine,
			"has_live_attacker_root": has_live_attacker_root,
			"target_pokemon_uid": target_uid,
			"attachment": attachment,
			"pivot": pivot,
			"same_ko_attack_resource": same_ko_attack_resource,
			"development_rank": development_rank,
			"target_is_fallback_chip_attacker": target_is_fallback_chip,
			"fallback_chip_energy_allowed": not target_is_fallback_chip or can_use_fallback_chip(has_live_attacker_root, profile),
			"attack_ready": bool(facts.get("attack", {}).get("ready", false)),
			"ko_available": bool(facts.get("attack", {}).get("ko_available", false)),
			"deck_low": bool(facts.get("resources", {}).get("deck_low", false)),
			"energy_attachment_open": bool(facts.get("turn", {}).get("energy_available", false)),
			"available_bench_slots": maxi(0, maximum_bench - bench.size()),
			"functional_bench_reserve_met": preserves_functional_bench_space(bench.size(), maximum_bench, profile),
			"profile_route_bias": route_bias(route_id, profile),
			"fan_call_development_order": _parameters(profile).get("fan_call_development_order", []),
			"jewel_seeker_pair_order": pair_roles(profile),
			"route_warning": warning,
		}
		annotated["module_annotations"] = annotations
		result.append(annotated)
	return result


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var selected_annotation := _module_annotation(selected)
	var top_annotation := _module_annotation(local_top)
	var selected_attachment: Dictionary = selected_annotation.get("attachment", {}) \
		if selected_annotation.get("attachment", {}) is Dictionary else {}
	var top_attachment: Dictionary = top_annotation.get("attachment", {}) \
		if top_annotation.get("attachment", {}) is Dictionary else {}
	var selected_resource: Dictionary = selected_annotation.get("same_ko_attack_resource", {}) \
		if selected_annotation.get("same_ko_attack_resource", {}) is Dictionary else {}
	var top_resource: Dictionary = top_annotation.get("same_ko_attack_resource", {}) \
		if top_annotation.get("same_ko_attack_resource", {}) is Dictionary else {}
	if bool(local_top.get("engine_rule_floor_exact", false)) \
			and str(selected_resource.get("role", "")) == "preserving" \
			and str(top_resource.get("role", "")) == "consuming" \
			and bool(selected_resource.get("eligible", false)) \
			and bool(top_resource.get("eligible", false)) \
			and str(selected_resource.get("source_slot_id", "")) \
				== str(top_resource.get("source_slot_id", "")) \
			and str(selected_resource.get("target_slot_id", "")) \
				== str(top_resource.get("target_slot_id", "")) \
			and int(selected_resource.get("prizes_now", 0)) \
				== int(top_resource.get("prizes_now", -1)) \
			and int(selected_resource.get("attached_energy_after", 0)) \
				> int(top_resource.get("attached_energy_after", 0)):
		return {
			"verified": true,
			"reason": "same_public_knockout_preserves_attached_energy",
			"certificate_kind": "public_same_ko_preserve_attached_energy",
			"interaction_owner": "not_required",
			"prizes_floor": int(selected_resource.get("prizes_now", 0)),
			"win_now": false,
			"preserved_attached_energy": int(selected_resource.get("attached_energy_after", 0)) \
				- int(top_resource.get("attached_energy_after", 0)),
		}
	if str(selected.get("route_id", "")) == "route:energy_commit" \
			and bool(facts.get("turn", {}).get("energy_available", false)) \
			and bool(selected_attachment.get("target_is_primary_attacker", false)) \
			and bool(selected_attachment.get("completes_required_types", false)) \
			and not bool(top_attachment.get("completes_required_types", false)):
		return {
			"verified": true,
			"reason": "flareon_public_typed_energy_gap",
			"certificate_kind": "public_typed_attack_cost_completion",
			"interaction_owner": "not_required",
		}
	var selected_pivot: Dictionary = selected_annotation.get("pivot", {}) \
		if selected_annotation.get("pivot", {}) is Dictionary else {}
	if str(selected.get("route_id", "")) == "route:pivot" \
			and str(local_top.get("route_id", "")) in ["route:end_turn", "route:information", "route:develop"] \
			and bool(selected_pivot.get("active_locked", false)) \
			and not bool(selected_pivot.get("active_attack_ready", false)) \
			and int(selected_pivot.get("target_damage", 0)) > int(selected_pivot.get("active_damage", 0)):
		return {
			"verified": true,
			"reason": "locked_attackless_active_has_stronger_public_pivot",
			"certificate_kind": "public_attack_damage_gain",
			"interaction_owner": "not_required",
		}
	var selected_rank := int(selected_annotation.get("development_rank", 999))
	var top_rank := int(top_annotation.get("development_rank", 999))
	if str(selected.get("route_id", "")) == "route:develop" \
			and str(local_top.get("route_id", "")) == "route:develop" \
			and selected_rank < top_rank \
			and bool(selected_annotation.get("functional_bench_reserve_met", false)):
		return {
			"verified": true,
			"reason": "required_evolution_root_before_optional_engine",
			"certificate_kind": "public_required_development_lane",
			"interaction_owner": "not_required",
		}
	return {"verified": false}


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var params := _parameters(profile)
	var selected_id := str(selected.get("route_id", ""))
	var top_id := str(local_top.get("route_id", ""))
	var attack: Dictionary = facts.get("attack", {}) if facts.get("attack", {}) is Dictionary else {}
	var resources: Dictionary = facts.get("resources", {}) if facts.get("resources", {}) is Dictionary else {}
	var board: Dictionary = facts.get("board", {}) if facts.get("board", {}) is Dictionary else {}
	var turn: Dictionary = facts.get("turn", {}) if facts.get("turn", {}) is Dictionary else {}
	if _guard_enabled(profile, "ready_ko") and bool(attack.get("ko_available", false)) \
			and selected_id not in ["route:attack_ko", "route:pivot"]:
		return _reject("flareon_ko_before_cycle")
	if _guard_enabled(profile, "low_deck") and bool(resources.get("deck_low", false)) and selected_id in [
		"route:information", "route:opening_search", "route:noctowl_search", "route:develop"
	] and top_id not in ["route:information", "route:opening_search", "route:noctowl_search", "route:develop"]:
		return _reject("flareon_low_deck_blocks_cycle")
	if _guard_enabled(profile, "bench_reserve") and bool(board.get("bench_full", false)) and selected_id == "route:develop":
		return _reject("flareon_full_bench_blocks_develop")
	if _guard_enabled(profile, "optional_engine") and selected_id == "route:develop" and _route_is_optional_engine(selected, params):
		if bool(attack.get("ready", false)) and bool(params.get("block_optional_engine_when_attack_ready", true)):
			return _reject("flareon_ready_attack_blocks_optional_engine")
		if _guard_enabled(profile, "typed_energy") and bool(turn.get("energy_available", false)) \
				and bool(params.get("block_optional_engine_when_energy_attachment_open", true)) \
				and top_id == "route:energy_commit":
			return _reject("flareon_energy_continuity_before_optional_engine")
		if int(resources.get("hand_size", 0)) >= int(params.get("minimum_hand_for_optional_engine", 3)):
			return _reject("flareon_optional_engine_not_required")
	return {"valid": true, "reason": "cycle_pivot_valid"}


func route_bias(route_id: String, profile: Dictionary) -> float:
	var preferences: Dictionary = profile.get("route_preferences", {}) \
		if profile.get("route_preferences", {}) is Dictionary else {}
	var biases: Dictionary = preferences.get("route_biases", {}) \
		if preferences.get("route_biases", {}) is Dictionary else {}
	return float(biases.get(route_id, 0.0))


func typed_energy_priority(symbol: String, attached_symbols: Array, profile: Dictionary) -> float:
	var required: Array = _parameters(profile).get("primary_required_energy", ["R", "W", "L"])
	var normalized := symbol.strip_edges().to_upper()
	if normalized not in required:
		return -1000.0
	var unique_attached: Array[String] = []
	for raw_symbol: Variant in attached_symbols:
		var existing := str(raw_symbol).strip_edges().to_upper()
		if existing != "" and existing not in unique_attached:
			unique_attached.append(existing)
	return 900.0 if normalized not in unique_attached else 180.0


func rank_fan_call_role(role: String, profile: Dictionary) -> int:
	var order: Array = _parameters(profile).get("fan_call_development_order", [
		"attacker_evolution_root", "noctowl_evolution_root", "opening_search_engine"
	])
	var normalized := role.strip_edges().to_lower()
	for index: int in order.size():
		if normalized == str(order[index]).strip_edges().to_lower():
			return index
	return order.size() + 1


func pair_roles(profile: Dictionary) -> Array:
	var params := _parameters(profile)
	var pairs: Variant = params.get("jewel_seeker_pair_order", profile.get("noctowl_pair_roles", []))
	return (pairs as Array).duplicate(true) if pairs is Array else []


func can_use_fallback_chip(has_live_attacker_root: bool, profile: Dictionary) -> bool:
	if not bool(_parameters(profile).get("fallback_chip_requires_no_live_attacker_root", true)):
		return true
	return not has_live_attacker_root


func should_pivot_from_locked_primary(
	active_locked: bool,
	active_attack_ready: bool,
	best_bench_damage: int,
	active_damage: int
) -> bool:
	return active_locked and not active_attack_ready and best_bench_damage > active_damage


func verified_role_pair_upgrade(
	selected_roles: Array,
	rule_roles: Array,
	profile: Dictionary,
	facts: Dictionary = {}
) -> Dictionary:
	var selected_rank := _pair_role_rank(selected_roles, profile)
	var rule_rank := _pair_role_rank(rule_roles, profile)
	return {
		"verified": selected_rank < rule_rank,
		"selected_rank": selected_rank,
		"rule_rank": rule_rank,
		"certificate_kind": "public_complementary_search_pair",
		"facts_hash_input": facts.duplicate(true),
	}


func preserves_functional_bench_space(current_bench_size: int, maximum_bench_size: int, profile: Dictionary) -> bool:
	var reserve := int(_parameters(profile).get("reserve_bench_slots", 2))
	return maximum_bench_size - current_bench_size >= reserve


func _parameters(profile: Dictionary) -> Dictionary:
	var modules: Variant = profile.get("module_parameters", {})
	if not (modules is Dictionary):
		return {}
	var params: Variant = (modules as Dictionary).get("cycle_pivot", {})
	return params as Dictionary if params is Dictionary else {}


func _module_annotation(route: Dictionary) -> Dictionary:
	var annotations: Dictionary = route.get("module_annotations", {}) \
		if route.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(MODULE_ID, {}) if annotations.get(MODULE_ID, {}) is Dictionary else {}


func _development_rank(action_roles: Array, profile: Dictionary) -> int:
	var best := 999
	for raw_role: Variant in action_roles:
		best = mini(best, rank_fan_call_role(str(raw_role), profile))
	return best


func _pair_role_rank(roles: Array, profile: Dictionary) -> int:
	var wanted: Dictionary = {}
	for raw_role: Variant in roles:
		wanted[str(raw_role)] = true
	var pairs := pair_roles(profile)
	for index: int in pairs.size():
		var raw_pair: Variant = pairs[index]
		if not (raw_pair is Array):
			continue
		var complete := true
		for raw_role: Variant in raw_pair:
			if not wanted.has(str(raw_role)):
				complete = false
				break
		if complete:
			return index
	return 999


func _attachment_snapshot(action: Dictionary, observation: Dictionary, profile: Dictionary) -> Dictionary:
	if str(action.get("kind", "")) != "attach_energy":
		return {}
	var target := _own_slot(str(action.get("target", "")), observation)
	if target.is_empty():
		return {}
	var pokemon: Dictionary = target.get("pokemon", {}) if target.get("pokemon", {}) is Dictionary else {}
	var pokemon_roles: Array = pokemon.get("semantic_roles", []) if pokemon.get("semantic_roles", []) is Array else []
	var params := _parameters(profile)
	var attacker_uids := _upper_string_array(params.get("primary_attacker_uids", []))
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var target_slot_id := str(target.get("slot_id", ""))
	var target_is_primary := str(pokemon.get("uid", "")).to_upper() in attacker_uids \
		or "primary_attacker" in pokemon_roles or "attacker" in pokemon_roles
	var attached_symbols: Array[String] = []
	for raw_energy: Variant in target.get("energy", []):
		if raw_energy is Dictionary:
			attached_symbols.append(_energy_symbol(raw_energy as Dictionary))
	var card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	var symbol := _energy_symbol(card)
	var required: Array = params.get("primary_required_energy", ["R", "W", "L"]) \
		if params.get("primary_required_energy", ["R", "W", "L"]) is Array else ["R", "W", "L"]
	var missing: Array[String] = []
	for raw_required: Variant in required:
		var required_symbol := str(raw_required).to_upper()
		if required_symbol not in attached_symbols:
			missing.append(required_symbol)
	return {
		"energy_symbol": symbol,
		"target_slot_id": target_slot_id,
		"target_is_active": target_slot_id != "" \
			and target_slot_id == str(active.get("slot_id", "")),
		"target_is_primary_attacker": target_is_primary,
		"missing_required_types_before": missing,
		"adds_missing_required_type": target_is_primary and symbol in missing,
		"completes_required_types": target_is_primary and missing.size() == 1 and symbol in missing,
	}


func _pivot_snapshot(action: Dictionary, observation: Dictionary) -> Dictionary:
	if str(action.get("kind", "")) != "retreat":
		return {}
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var target := _own_slot(str(action.get("target", "")), observation)
	return {
		"active_locked": bool(active.get("attack_locked", false)),
		"active_attack_ready": bool(active.get("attack_ready", false)),
		"active_damage": int(active.get("max_damage", 0)),
		"target_damage": int(target.get("max_damage", 0)),
	}


func _same_ko_attack_resource_snapshot(
	route: Dictionary,
	action: Dictionary,
	observation: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var raw_config: Variant = _parameters(profile).get("same_ko_attack_resource_preservation", {})
	if not (raw_config is Dictionary):
		return {}
	var config: Dictionary = raw_config
	if not bool(config.get("enabled", false)) \
			or int(config.get("owner_deck_id", 0)) != int(profile.get("deck_id", 0)) \
			or str(action.get("kind", "")) != "attack":
		return {}
	var source_card: Dictionary = action.get("source_card", {}) \
		if action.get("source_card", {}) is Dictionary else {}
	var source_uid := str(source_card.get("uid", "")).strip_edges().to_upper()
	var source_effect_id := str(source_card.get("effect_id", "")).strip_edges()
	if source_uid != str(config.get("attacker_uid", "")).strip_edges().to_upper() \
			or source_effect_id != str(config.get("attacker_effect_id", "")).strip_edges():
		return {}
	var attack_index := int(action.get("attack_index", -1))
	var preserving_index := int(config.get("preserving_attack_index", -2))
	var consuming_index := int(config.get("consuming_attack_index", -3))
	var role := "preserving" if attack_index == preserving_index \
		else "consuming" if attack_index == consuming_index else ""
	if role == "":
		return {}
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var active_pokemon: Dictionary = active.get("pokemon", {}) \
		if active.get("pokemon", {}) is Dictionary else {}
	var source_slot_id := str(action.get("source", ""))
	var active_slot_id := str(active.get("slot_id", ""))
	var active_uid := str(active_pokemon.get("uid", "")).strip_edges().to_upper()
	var energies: Array = active.get("energy", []) if active.get("energy", []) is Array else []
	var required_energy_count := int(config.get("required_attached_energy_count", 0))
	var required_symbol := str(config.get("required_energy_symbol", "F")).strip_edges().to_upper()
	var typed_energy_count := 0
	for raw_energy: Variant in energies:
		if raw_energy is Dictionary and _energy_symbol(raw_energy as Dictionary) == required_symbol:
			typed_energy_count += 1
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var opponent_bench: Array = opponent.get("bench", []) \
		if opponent.get("bench", []) is Array else []
	var target_hp := int(opponent_active.get("remaining_hp", 0))
	var target_prizes := int(opponent_active.get("prize_count", 0))
	var prizes_remaining := int(own.get("prizes_remaining", 0))
	var projected_damage := int(action.get("projected_damage", 0))
	var projected_knockout := bool(action.get("projected_knockout", false)) \
		and target_hp > 0 and projected_damage >= target_hp
	var exact_hand_size := int(config.get("required_visible_hand_size", -1))
	var visible_hand: Array = own.get("hand", []) if own.get("hand", []) is Array else []
	var requires_nonterminal := bool(config.get("require_nonterminal_prize_state", true))
	var requires_replacement := bool(config.get("require_live_opponent_replacement", true))
	var post_energy := int(config.get("preserved_attached_energy_count", required_energy_count)) \
		if role == "preserving" else maxi(
			0,
			energies.size() - int(config.get("consumed_attached_energy_count", required_energy_count))
		)
	var eligible := source_slot_id != "" \
		and source_slot_id == active_slot_id \
		and active_uid == source_uid \
		and energies.size() == required_energy_count \
		and typed_energy_count == required_energy_count \
		and exact_hand_size >= 0 and visible_hand.size() == exact_hand_size \
		and projected_knockout \
		and target_prizes > 0 \
		and (not requires_nonterminal or target_prizes < prizes_remaining) \
		and (not requires_replacement or not opponent_bench.is_empty())
	return {
		"eligible": eligible,
		"role": role,
		"source_uid": source_uid,
		"source_effect_id": source_effect_id,
		"source_slot_id": source_slot_id,
		"target_slot_id": str(opponent_active.get("slot_id", "opponent:active")),
		"attack_index": attack_index,
		"projected_damage": projected_damage,
		"projected_knockout": projected_knockout,
		"attached_energy_before": energies.size(),
		"attached_energy_after": post_energy,
		"visible_hand_size": visible_hand.size(),
		"target_remaining_hp": target_hp,
		"prizes_now": target_prizes if projected_knockout else 0,
		"prizes_remaining": prizes_remaining,
		"live_opponent_replacement": not opponent_bench.is_empty(),
		"certificate_kind": str(config.get(
			"certificate_kind",
			"public_same_ko_preserve_attached_energy"
		)),
		"route_id": str(route.get("route_id", "")),
	}


func _own_slot(slot_id: String, observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == slot_id:
			return raw_slot as Dictionary
	return {}


func _energy_symbol(card: Dictionary) -> String:
	return EnergySymbolsScript.from_card(card)


func _upper_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var item := str(raw).strip_edges().to_upper()
			if item != "" and item not in result:
				result.append(item)
	return result


func _annotation_warning(
	route: Dictionary,
	action: Dictionary,
	top_route_id: String,
	facts: Dictionary,
	profile: Dictionary,
	bench_size: int,
	maximum_bench: int
) -> String:
	var action_card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	var route_for_validation := route.duplicate(true)
	route_for_validation["action_card_uid"] = str(action_card.get("uid", ""))
	route_for_validation["action_semantic_roles"] = action_card.get("semantic_roles", []) \
		if action_card.get("semantic_roles", []) is Array else []
	route_for_validation["optional_draw_engine"] = _is_optional_engine(
		str(route_for_validation.get("action_card_uid", "")),
		route_for_validation.get("action_semantic_roles", []),
		_parameters(profile)
	)
	var validation := validate_route_switch(route_for_validation, {"route_id": top_route_id}, facts, profile)
	if not bool(validation.get("valid", false)):
		return str(validation.get("reason", "cycle_pivot_rejected"))
	var route_id := str(route.get("route_id", ""))
	if _guard_enabled(profile, "bench_reserve") and route_id == "route:develop" \
			and bool(route_for_validation.get("optional_draw_engine", false)) \
			and not preserves_functional_bench_space(bench_size + 1, maximum_bench, profile):
		return "flareon_optional_engine_consumes_functional_bench_reserve"
	return ""


func _action_for_route(route: Dictionary, observation: Dictionary) -> Dictionary:
	var wanted := str(route.get("safe_prefix_action_id", ""))
	for raw_action: Variant in observation.get("legal_actions", []):
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == wanted:
			return raw_action as Dictionary
	return {}


func _area_zero_visible(observation: Dictionary) -> bool:
	var stadium: Dictionary = observation.get("stadium", {}) if observation.get("stadium", {}) is Dictionary else {}
	var roles: Array = stadium.get("semantic_roles", []) if stadium.get("semantic_roles", []) is Array else []
	return str(stadium.get("uid", "")) == "CSV9C_207" or "bench_expansion" in roles


func _has_visible_uid(observation: Dictionary, stable_uids: Variant) -> bool:
	if not (stable_uids is Array):
		return false
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var pokemon: Dictionary = (raw_slot as Dictionary).get("pokemon", {}) \
			if (raw_slot as Dictionary).get("pokemon", {}) is Dictionary else {}
		if str(pokemon.get("uid", "")) in stable_uids:
			return true
	return false


func _target_pokemon_uid(action: Dictionary, observation: Dictionary) -> String:
	var wanted := str(action.get("target", ""))
	if wanted == "":
		return ""
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == wanted:
			var pokemon: Dictionary = (raw_slot as Dictionary).get("pokemon", {}) \
				if (raw_slot as Dictionary).get("pokemon", {}) is Dictionary else {}
			return str(pokemon.get("uid", ""))
	return ""


func _route_is_optional_engine(route: Dictionary, params: Dictionary) -> bool:
	if bool(route.get("optional_draw_engine", false)):
		return true
	var annotations: Dictionary = route.get("module_annotations", {}) \
		if route.get("module_annotations", {}) is Dictionary else {}
	var cycle: Dictionary = annotations.get(MODULE_ID, {}) if annotations.get(MODULE_ID, {}) is Dictionary else {}
	if bool(cycle.get("optional_draw_engine", false)):
		return true
	return _is_optional_engine(
		str(route.get("action_card_uid", cycle.get("card_uid", ""))),
		route.get("action_semantic_roles", cycle.get("card_roles", [])),
		params
	)


func _is_optional_engine(card_uid: String, roles: Variant, params: Dictionary) -> bool:
	if roles is Array and "optional_draw_engine" in roles:
		return true
	var stable_uids: Variant = params.get("optional_draw_engine_uids", [])
	return stable_uids is Array and card_uid in stable_uids


func _guard_enabled(profile: Dictionary, guard_id: String) -> bool:
	var guards: Variant = _parameters(profile).get("enabled_guards", [])
	return guards is Array and guard_id in guards


func _reject(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
