class_name V18CPGEnergyBurst
extends RefCounted

## Pure, visibility-safe capability module for decks that need typed-energy
## routing.  Damage math is explicitly profiled because the supported decks do
## not share one mechanic: some discard attached energy, some discard energy
## from hand, some count energized Bench Pokemon, and some have no energy-based
## damage scaling at all.  It never reads engine objects, hidden zones, prize
## identities, or deck order.

const MODULE_ID := "energy_burst"
const DEFAULT_DAMAGE_PER_DISCARD := 70
const DEFAULT_RESERVE_TOTAL := 2
const DEFAULT_RESERVE_ENGINE := 1
const DEFAULT_LOW_DECK := 10
const DEFAULT_CRITICAL_DECK := 6
const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")
const PrizeGraphSolverScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGPrizeGraphSolver.gd")


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var snapshot := visible_energy_snapshot(observation, profile)
	for route: Dictionary in frontier:
		var annotated := route.duplicate(true)
		var action := _action_for_route(route, observation)
		var module_annotation := route_annotation(route, action, observation, facts, profile, snapshot)
		var annotations: Dictionary = annotated.get("module_annotations", {}) if annotated.get("module_annotations", {}) is Dictionary else {}
		annotations[MODULE_ID] = module_annotation
		annotated["module_annotations"] = annotations
		result.append(annotated)
	return _annotate_extra_prize_closeout(result, observation, profile)


func _annotate_extra_prize_closeout(
	frontier: Array[Dictionary],
	observation: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	var result := frontier.duplicate(true)
	var config: Dictionary = _parameters(profile).get("extra_prize_closeout", {}) \
		if _parameters(profile).get("extra_prize_closeout", {}) is Dictionary else {}
	if config.is_empty() or int(config.get("deck_id", 0)) != int(profile.get("deck_id", 0)):
		return result
	var bonus_matches: Array[int] = []
	var rule_matches: Array[int] = []
	for index: int in result.size():
		var candidate: Dictionary = result[index]
		var action_ref: Dictionary = candidate.get("action_ref", {}) \
			if candidate.get("action_ref", {}) is Dictionary else {}
		var source_card: Dictionary = action_ref.get("source_card", {}) \
			if action_ref.get("source_card", {}) is Dictionary else {}
		if str(source_card.get("uid", "")).strip_edges().to_upper() \
				!= str(config.get("attacker_uid", "")).strip_edges().to_upper() \
				or str(source_card.get("effect_id", "")) != str(config.get("attacker_effect_id", "")):
			continue
		var attack_index := int(action_ref.get("attack_index", -1))
		if attack_index == int(config.get("bonus_attack_index", -1)):
			bonus_matches.append(index)
		if attack_index == int(config.get("comparison_attack_index", -1)) \
				and bool(candidate.get("engine_rule_floor_exact", false)):
			rule_matches.append(index)
	# Ambiguous public action binding must never manufacture an outcome.
	if bonus_matches.size() != 1 or rule_matches.size() != 1:
		return result
	var bonus_index := bonus_matches[0]
	var certificate := PrizeGraphSolverScript.new().public_extra_prize_attack_terminal_certificate(
		result[bonus_index],
		result[rule_matches[0]],
		observation,
		config
	)
	var annotations: Dictionary = result[bonus_index].get("module_annotations", {}) \
		if result[bonus_index].get("module_annotations", {}) is Dictionary else {}
	var energy_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	energy_annotation["extra_prize_closeout"] = certificate
	annotations[MODULE_ID] = energy_annotation
	result[bonus_index]["module_annotations"] = annotations
	if not bool(certificate.get("verified", false)):
		return result
	var outcome: Dictionary = result[bonus_index].get("outcome", {}) \
		if result[bonus_index].get("outcome", {}) is Dictionary else {}
	outcome["prizes_now"] = int(certificate.get("prizes_now", 0))
	outcome["win_now"] = bool(certificate.get("win_now", false))
	result[bonus_index]["outcome"] = outcome
	return result


func route_annotation(
	route: Dictionary,
	action: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	snapshot: Dictionary = {}
) -> Dictionary:
	var state := snapshot if not snapshot.is_empty() else visible_energy_snapshot(observation, profile)
	var parameters := _parameters(profile)
	var category := str(route.get("macro_action", str(route.get("route_id", "")).trim_prefix("route:")))
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var target_hp := _target_remaining_hp(action.get("target", ""), observation) if category == "gust" else int(opponent_active.get("remaining_hp", 0))
	var target_known := target_hp > 0
	var damage_resource := damage_resource_snapshot(observation, profile, state, target_hp)
	var damage_mode := str(damage_resource.get("mode", "none"))
	var damage_math_enabled := bool(damage_resource.get("enabled", false))
	var required_units := int(damage_resource.get("required_units", 0))
	var available_units := int(damage_resource.get("available_units", 0))
	var damage_per_unit := int(damage_resource.get("damage_per_unit", 0))
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var available_bench_slots := maxi(0, 5 - bench.size())
	var safety := _safety(profile)
	var low_deck_threshold := int(parameters.get("low_deck_threshold", safety.get("low_deck_threshold", DEFAULT_LOW_DECK)))
	var critical_deck_threshold := int(parameters.get("critical_deck_threshold", safety.get("critical_deck_threshold", DEFAULT_CRITICAL_DECK)))
	var deck_count := int(own.get("deck_count", 0))
	var attack_ready := bool(facts.get("attack", {}).get("ready", false))
	var ko_available := bool(facts.get("attack", {}).get("ko_available", false))
	var is_information := category in ["information", "opening_search", "noctowl_search"]
	var ko_payable := target_known and damage_math_enabled and required_units <= available_units
	var attachment := _attachment_snapshot(action, observation, parameters)
	var acceleration := acceleration_status(observation, profile)
	var warning := _route_warning(
		category,
		attack_ready,
		ko_available,
		deck_count,
		low_deck_threshold,
		target_known,
		damage_resource
	)
	return {
		"module": MODULE_ID,
		"category": category,
		"source_pokemon": _card_name(action.get("source_card", {})),
		"target_pokemon": _slot_pokemon_name(action.get("target", {}), observation),
		"card": _card_name(action.get("card", {})),
		"board_energy": state,
		"opponent_active_hp": target_hp,
		"damage_mode": damage_mode,
		"damage_math_enabled": damage_math_enabled,
		"damage_resource": damage_resource,
		"damage_resource_zone": str(damage_resource.get("resource_zone", "none")),
		"damage_raw_units": int(damage_resource.get("raw_units", 0)),
		"projected_public_damage": int(damage_resource.get("projected_public_damage", 0)),
		"damage_per_unit": damage_per_unit,
		"minimum_damage_units_for_active_ko": required_units,
		"available_damage_units": available_units,
		# Compatibility fields remain truthful only for discard-based attacks.
		"damage_per_discard": damage_per_unit if damage_mode in ["attached_discard", "hand_discard"] else 0,
		"minimum_discards_for_active_ko": required_units if damage_mode in ["attached_discard", "hand_discard"] else 0,
		"max_safe_discards": available_units if damage_mode in ["attached_discard", "hand_discard"] else 0,
		"target_known": target_known,
		"ko_payable_with_reserve": ko_payable,
		"attack_ready": attack_ready,
		"ko_available": ko_available,
		"typed_attack_cost_ready": bool(state.get("primary_cost_ready", false)),
		"next_turn_reserve_met": bool(damage_resource.get("reserve_met_after_required_units", true)),
		"available_bench_slots": available_bench_slots,
		"bench_reserve_met": available_bench_slots > int(parameters.get("bench_slots_to_reserve", safety.get("preserve_bench_slots", 1))),
		"deck_low": deck_count <= low_deck_threshold,
		"deck_critical": deck_count <= critical_deck_threshold,
		"optional_information_safe": not is_information or not attack_ready or not ko_available and deck_count > low_deck_threshold,
		"attachment": attachment,
		"acceleration": acceleration,
		"route_warning": warning,
		"decision_hint": _decision_hint(category, warning, ko_payable, damage_mode),
	}


func damage_resource_snapshot(
	observation: Dictionary,
	profile: Dictionary = {},
	board_snapshot: Dictionary = {},
	target_hp: int = 0
) -> Dictionary:
	var parameters := _parameters(profile)
	var mode := str(parameters.get("burst_damage_mode", "attached_discard")).strip_edges().to_lower()
	if mode not in ["attached_discard", "hand_discard", "energized_bench_count", "none"]:
		mode = "none"
	var state := board_snapshot if not board_snapshot.is_empty() else visible_energy_snapshot(observation, profile)
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var base_damage := 0
	var damage_per_unit := 0
	var raw_units := 0
	var reserve_units := 0
	var resource_zone := "none"
	var consumptive := false
	match mode:
		"attached_discard":
			damage_per_unit = maxi(1, int(parameters.get("damage_per_discard", DEFAULT_DAMAGE_PER_DISCARD)))
			raw_units = int(state.get("total_basic_attached", 0))
			reserve_units = maxi(0, int(parameters.get("reserve_total_energy_next_turn", DEFAULT_RESERVE_TOTAL)))
			resource_zone = "board_attached_basic_energy"
			consumptive = true
		"hand_discard":
			damage_per_unit = maxi(1, int(parameters.get("damage_per_discard", 50)))
			raw_units = _basic_energy_count(own.get("hand", []))
			reserve_units = maxi(0, int(parameters.get("reserve_hand_energy_next_turn", 0)))
			resource_zone = "own_hand_basic_energy"
			consumptive = true
		"energized_bench_count":
			base_damage = maxi(0, int(parameters.get("base_damage", 80)))
			damage_per_unit = maxi(1, int(parameters.get("damage_per_energized_bench", 40)))
			var required_symbol := EnergySymbolsScript.canonical(parameters.get("bench_energy_type", "G"))
			raw_units = _energized_bench_count(own.get("bench", []), required_symbol)
			resource_zone = "own_bench_pokemon_with_%s_energy" % required_symbol
		"none":
			pass
	var enabled := mode != "none"
	var available_units := maxi(0, raw_units - reserve_units) if consumptive else raw_units
	var remaining_damage := maxi(0, target_hp - base_damage)
	var required_units := ceili(float(remaining_damage) / float(damage_per_unit)) \
		if enabled and damage_per_unit > 0 else 0
	return {
		"mode": mode,
		"enabled": enabled,
		"resource_zone": resource_zone,
		"consumptive": consumptive,
		"base_damage": base_damage,
		"damage_per_unit": damage_per_unit,
		"raw_units": raw_units,
		"reserve_units": reserve_units,
		"available_units": available_units,
		"required_units": required_units,
		"projected_public_damage": base_damage + raw_units * damage_per_unit if enabled else 0,
		"reserve_met_after_required_units": not consumptive or raw_units - required_units >= reserve_units,
	}


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
	if str(selected.get("route_id", "")) == "route:energy_commit" \
			and bool(facts.get("turn", {}).get("energy_available", false)) \
			and bool(selected_attachment.get("target_is_primary_attacker", false)) \
			and bool(selected_attachment.get("completes_required_types", false)) \
			and not bool(top_attachment.get("completes_required_types", false)):
		return {
			"verified": true,
			"reason": "typed_attachment_closes_public_attack_cost_gap",
			"certificate_kind": "public_typed_attack_cost_completion",
			"interaction_owner": "not_required",
		}
	var acceleration: Dictionary = selected_annotation.get("acceleration", {}) \
		if selected_annotation.get("acceleration", {}) is Dictionary else {}
	if str(selected.get("route_id", "")) == "route:accelerate" \
			and str(local_top.get("route_id", "")) in ["route:end_turn", "route:information", "route:develop"] \
			and "supporter_acceleration" in selected.get("action_semantic_roles", []) \
			and bool(acceleration.get("sada_live", false)) \
			and not bool(facts.get("attack", {}).get("ready", false)):
		return {
			"verified": true,
			"reason": "public_discard_energy_acceleration_before_nonprogress",
			"certificate_kind": "public_energy_acceleration",
			"interaction_owner": "module_verified",
		}
	return {"verified": false}


func visible_energy_snapshot(observation: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var counts := _empty_energy_counts()
	var active_counts := _empty_energy_counts()
	var total := 0
	var basic_total := 0
	var ancient_targets := 0
	var engine_targets := 0
	var parameters := _parameters(profile)
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var active_slot_id := str((own.get("active", {}) as Dictionary).get("slot_id", "")) if own.get("active", {}) is Dictionary else ""
	var slots: Array = []
	if own.get("active", {}) is Dictionary and not (own.get("active", {}) as Dictionary).is_empty():
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
		if _card_has_role_or_effect(pokemon, "ancient_acceleration_target", parameters.get("ancient_effect_ids", [])):
			ancient_targets += 1
		if _card_has_role_or_effect(pokemon, "energy_engine", parameters.get("teal_mask_engine_effect_ids", [])):
			engine_targets += 1
		var energies: Array = slot.get("energy", []) if slot.get("energy", []) is Array else []
		for raw_energy: Variant in energies:
			if not (raw_energy is Dictionary):
				continue
			var energy_type := _normalize_energy_type(raw_energy as Dictionary)
			counts[energy_type] = int(counts.get(energy_type, 0)) + 1
			if str(slot.get("slot_id", "")) == active_slot_id:
				active_counts[energy_type] = int(active_counts.get(energy_type, 0)) + 1
			total += 1
			if _is_basic_energy(raw_energy as Dictionary):
				basic_total += 1
	var required_types: Array[String] = EnergySymbolsScript.canonical_array(
		_parameters(profile).get("primary_attack_required_types", ["L", "F"])
	)
	var cost_ready := true
	var board_cost_present := true
	for raw_required: Variant in required_types:
		if int(active_counts.get(str(raw_required), 0)) <= 0:
			cost_ready = false
		if int(counts.get(str(raw_required), 0)) <= 0:
			board_cost_present = false
	return {
		"total_attached": total,
		"total_basic_attached": basic_total,
		"by_type": counts,
		"active_by_type": active_counts,
		"primary_cost_ready": cost_ready,
		"board_required_types_present": board_cost_present,
		"ancient_acceleration_targets": ancient_targets,
		"teal_mask_engine_targets": engine_targets,
		"reserve_engine_energy": int(_parameters(profile).get("reserve_engine_energy", DEFAULT_RESERVE_ENGINE)),
	}


func minimum_discards_for_damage(target_hp: int, damage_per_discard: int = DEFAULT_DAMAGE_PER_DISCARD) -> int:
	if target_hp <= 0:
		return 0
	return ceili(float(target_hp) / float(maxi(1, damage_per_discard)))


func discard_plan(target_hp: int, total_attached: int, reserve_total: int, damage_per_discard: int = DEFAULT_DAMAGE_PER_DISCARD) -> Dictionary:
	var required := minimum_discards_for_damage(target_hp, damage_per_discard)
	var available := maxi(0, total_attached - maxi(0, reserve_total))
	return {
		"required": required,
		"available_with_reserve": available,
		"payable": target_hp > 0 and required <= available,
		"discard_count": mini(required, available),
		"remaining_energy": total_attached - mini(required, available),
	}


func verified_minimum_discard_choice(
	rule_discard_count: int,
	target_hp: int,
	total_basic_attached: int,
	reserve_total: int,
	damage_per_discard: int = DEFAULT_DAMAGE_PER_DISCARD
) -> Dictionary:
	var plan := discard_plan(target_hp, total_basic_attached, reserve_total, damage_per_discard)
	var minimum_count := int(plan.get("discard_count", 0))
	return {
		"verified": bool(plan.get("payable", false)) and rule_discard_count > minimum_count,
		"rule_choice": rule_discard_count,
		"selected_choice": minimum_count,
		"preserved_basic_energy": maxi(0, rule_discard_count - minimum_count),
		"certificate_kind": "public_minimum_resource_ko",
	}


func acceleration_status(observation: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var snapshot := visible_energy_snapshot(observation, profile)
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var discard: Array = own.get("discard", []) if own.get("discard", []) is Array else []
	var basic_energy_in_discard := 0
	for raw_card: Variant in discard:
		if raw_card is Dictionary and _is_basic_energy(raw_card as Dictionary):
			basic_energy_in_discard += 1
	var minimum_targets := int(_parameters(profile).get("ancient_acceleration_min_targets", 1))
	return {
		"basic_energy_in_discard": basic_energy_in_discard,
		"ancient_targets": int(snapshot.get("ancient_acceleration_targets", 0)),
		"sada_live": basic_energy_in_discard > 0 and int(snapshot.get("ancient_acceleration_targets", 0)) >= minimum_targets,
	}


func should_take_optional_information(facts: Dictionary, deck_count: int, profile: Dictionary = {}) -> bool:
	var safety := _safety(profile)
	var threshold := int(_parameters(profile).get("low_deck_threshold", safety.get("low_deck_threshold", DEFAULT_LOW_DECK)))
	var ready := bool(facts.get("attack", {}).get("ready", false))
	var ko := bool(facts.get("attack", {}).get("ko_available", false))
	if ready and ko and bool(safety.get("stop_optional_draw_when_attack_ready", true)):
		return false
	return deck_count > threshold


func _route_warning(
	category: String,
	attack_ready: bool,
	ko_available: bool,
	deck_count: int,
	low_deck_threshold: int,
	target_known: bool,
	damage_resource: Dictionary
) -> String:
	if category == "gust" and not target_known:
		return "gust_target_unresolved"
	if category in ["information", "opening_search", "noctowl_search"] and attack_ready and ko_available:
		return "optional_churn_after_ko_secured"
	if category in ["information", "opening_search", "noctowl_search"] and deck_count <= low_deck_threshold:
		return "low_deck_information_risk"
	var enabled := bool(damage_resource.get("enabled", false))
	var required_units := int(damage_resource.get("required_units", 0))
	var available_units := int(damage_resource.get("available_units", 0))
	if category in ["attack_ko", "gust"] and target_known and enabled and required_units > available_units:
		if not bool(damage_resource.get("consumptive", false)):
			return "public_damage_units_insufficient"
		return "ko_breaks_next_turn_reserve"
	return ""


func _decision_hint(category: String, warning: String, ko_payable: bool, damage_mode: String = "attached_discard") -> String:
	if category == "attack_ko" and ko_payable:
		return "take_publicly_payable_ko" if damage_mode == "energized_bench_count" else "commit_minimum_resource_ko"
	if category == "gust" and ko_payable:
		return "take_payable_prize_closeout"
	if warning in ["optional_churn_after_ko_secured", "low_deck_information_risk"]:
		return "skip_optional_information"
	if warning == "gust_target_unresolved":
		return "bind_gust_target_before_commitment"
	if warning == "ko_breaks_next_turn_reserve":
		return "preserve_next_attacker_continuity"
	if warning == "public_damage_units_insufficient":
		return "develop_public_damage_units"
	return "evaluate_normally"


func _basic_energy_count(value: Variant) -> int:
	var count := 0
	if value is Array:
		for raw_card: Variant in value as Array:
			if raw_card is Dictionary and _is_basic_energy(raw_card as Dictionary):
				count += 1
	return count


func _energized_bench_count(value: Variant, required_symbol: String) -> int:
	var count := 0
	if not (value is Array):
		return count
	for raw_slot: Variant in value as Array:
		if not (raw_slot is Dictionary):
			continue
		var energies: Array = (raw_slot as Dictionary).get("energy", []) \
			if (raw_slot as Dictionary).get("energy", []) is Array else []
		for raw_energy: Variant in energies:
			if raw_energy is Dictionary and _normalize_energy_type(raw_energy as Dictionary) == required_symbol:
				count += 1
				break
	return count


func _action_for_route(route: Dictionary, observation: Dictionary) -> Dictionary:
	var wanted := str(route.get("safe_prefix_action_id", ""))
	for raw_action: Variant in observation.get("legal_actions", []):
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == wanted:
			return raw_action as Dictionary
	return {}


func _module_annotation(route: Dictionary) -> Dictionary:
	var annotations: Dictionary = route.get("module_annotations", {}) \
		if route.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(MODULE_ID, {}) if annotations.get(MODULE_ID, {}) is Dictionary else {}


func _attachment_snapshot(action: Dictionary, observation: Dictionary, parameters: Dictionary) -> Dictionary:
	if str(action.get("kind", "")) != "attach_energy":
		return {}
	var target := _own_slot(str(action.get("target", "")), observation)
	if target.is_empty():
		return {}
	var pokemon: Dictionary = target.get("pokemon", {}) if target.get("pokemon", {}) is Dictionary else {}
	var primary_uids := _upper_string_array(parameters.get("primary_attacker_uids", []))
	var pokemon_roles: Array = pokemon.get("semantic_roles", []) if pokemon.get("semantic_roles", []) is Array else []
	var target_uid := str(pokemon.get("uid", "")).to_upper()
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var target_slot_id := str(target.get("slot_id", ""))
	var target_is_primary := target_uid in primary_uids or "energy_burst" in pokemon_roles or "primary_attacker" in pokemon_roles
	var attached_symbols: Array[String] = []
	for raw_energy: Variant in target.get("energy", []):
		if raw_energy is Dictionary:
			attached_symbols.append(_normalize_energy_type(raw_energy as Dictionary))
	var card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	var symbol := _normalize_energy_type(card)
	var required: Array[String] = EnergySymbolsScript.canonical_array(
		parameters.get("primary_attack_required_types", ["L", "F"])
	)
	var missing_before: Array[String] = []
	for raw_required: Variant in required:
		var required_symbol := str(raw_required).to_upper()
		if required_symbol not in attached_symbols:
			missing_before.append(required_symbol)
	return {
		"energy_symbol": symbol,
		"target_slot_id": target_slot_id,
		"target_uid": target_uid,
		"target_is_active": target_slot_id != "" \
			and target_slot_id == str(active.get("slot_id", "")),
		"target_is_primary_attacker": target_is_primary,
		"missing_required_types_before": missing_before,
		"adds_missing_required_type": target_is_primary and symbol in missing_before,
		"completes_required_types": target_is_primary and missing_before.size() == 1 and symbol in missing_before,
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


func _upper_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var item := str(raw).strip_edges().to_upper()
			if item != "" and item not in result:
				result.append(item)
	return result


func _parameters(profile: Dictionary) -> Dictionary:
	var all_parameters: Dictionary = profile.get("module_parameters", {}) if profile.get("module_parameters", {}) is Dictionary else {}
	return all_parameters.get(MODULE_ID, {}) if all_parameters.get(MODULE_ID, {}) is Dictionary else {}


func _safety(profile: Dictionary) -> Dictionary:
	return profile.get("safety", {}) if profile.get("safety", {}) is Dictionary else {}


func _normalize_energy_type(card: Dictionary) -> String:
	return EnergySymbolsScript.from_card(card)


func _empty_energy_counts() -> Dictionary:
	var result := {"other": 0}
	for symbol: String in EnergySymbolsScript.SYMBOLS:
		result[symbol] = 0
	return result


func _is_basic_energy(card: Dictionary) -> bool:
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	return "basic_energy" in roles or str(card.get("type", "")).to_lower() == "basic energy"


func _card_has_role_or_effect(card: Dictionary, role: String, effect_ids: Variant) -> bool:
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if role in roles:
		return true
	if effect_ids is Array:
		return str(card.get("effect_id", "")) in effect_ids
	return false


func _slot_card_name(slot: Dictionary) -> String:
	return _card_name(slot.get("pokemon", {}))


func _slot_pokemon_name(slot_id: Variant, observation: Dictionary) -> String:
	var wanted := str(slot_id)
	if wanted == "":
		return ""
	for side_key: String in ["own", "opponent"]:
		var side: Dictionary = observation.get(side_key, {}) if observation.get(side_key, {}) is Dictionary else {}
		var candidates: Array = []
		if side.get("active", {}) is Dictionary:
			candidates.append(side.get("active", {}))
		if side.get("bench", []) is Array:
			candidates.append_array(side.get("bench", []))
		for raw_slot: Variant in candidates:
			if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == wanted:
				return _slot_card_name(raw_slot as Dictionary)
	return ""


func _target_remaining_hp(slot_id: Variant, observation: Dictionary) -> int:
	var wanted := str(slot_id)
	if wanted == "":
		return 0
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var candidates: Array = []
	if opponent.get("active", {}) is Dictionary:
		candidates.append(opponent.get("active", {}))
	if opponent.get("bench", []) is Array:
		candidates.append_array(opponent.get("bench", []))
	for raw_slot: Variant in candidates:
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == wanted:
			return int((raw_slot as Dictionary).get("remaining_hp", 0))
	return 0


func _card_name(value: Variant) -> String:
	return str((value as Dictionary).get("name", "")) if value is Dictionary else ""
