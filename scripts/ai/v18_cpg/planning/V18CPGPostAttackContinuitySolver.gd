class_name V18CPGPostAttackContinuitySolver
extends RefCounted

## Projects the public board through an already-payable attack and one credible
## opponent answer.  It deliberately does not inspect hidden zones or assume a
## future draw.  Profiles only declare floors and stable role/effect identities;
## this shared solver owns the cross-deck debt vocabulary and action ordering.

const ANNOTATION_KEY := "post_attack_continuity"
const DEFAULT_CRITICAL_DECK := 6


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	var snapshot := _snapshot(observation, facts, frontier, profile)
	var result: Array[Dictionary] = []
	for raw_candidate: Dictionary in frontier:
		var candidate := raw_candidate.duplicate(true)
		var effect := _candidate_effect(
			candidate,
			observation,
			snapshot,
			profile
		)
		candidate[ANNOTATION_KEY] = effect
		var outcome: Dictionary = candidate.get("outcome", {}) \
			if candidate.get("outcome", {}) is Dictionary else {}
		outcome["attack_uptime_next_turn"] = bool(snapshot.get("floor_met", true))
		outcome["continuity_debt_reduction"] = int(
			effect.get("debt_reduction_count", 0)
		)
		candidate["outcome"] = outcome
		if bool(effect.get("reduces_debt", false)) \
				or bool(effect.get("progresses_debt", false)):
			_rewrite_conflicting_module_warnings(candidate, effect)
		result.append(candidate)
	return result


func build(
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary],
	profile: Dictionary
) -> Dictionary:
	var annotated := annotate_frontier(frontier, observation, facts, profile)
	return build_from_annotated_frontier(
		observation,
		facts,
		annotated,
		profile
	)


func build_from_annotated_frontier(
	observation: Dictionary,
	facts: Dictionary,
	annotated: Array[Dictionary],
	profile: Dictionary
) -> Dictionary:
	var snapshot := _snapshot(observation, facts, annotated, profile)
	var safe_prefix_count := 0
	var candidate_effects: Array[Dictionary] = []
	for candidate: Dictionary in annotated:
		var effect: Dictionary = candidate.get(ANNOTATION_KEY, {}) \
			if candidate.get(ANNOTATION_KEY, {}) is Dictionary else {}
		if not bool(effect.get("reduces_debt", false)) \
				and not bool(effect.get("progresses_debt", false)):
			continue
		var item := effect.duplicate(true)
		item["candidate_id"] = str(candidate.get("candidate_id", ""))
		item["action_id"] = str(candidate.get("safe_prefix_action_id", ""))
		item["route_id"] = str(candidate.get("route_id", ""))
		item["action_kind"] = str(candidate.get("action_kind", ""))
		candidate_effects.append(item)
		if bool(effect.get("force_before_terminal", false)):
			safe_prefix_count += 1
	candidate_effects.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_force := bool(left.get("force_before_terminal", false))
		var right_force := bool(right.get("force_before_terminal", false))
		if left_force != right_force:
			return left_force
		var left_priority := int(left.get("priority", 1000))
		var right_priority := int(right.get("priority", 1000))
		if left_priority != right_priority:
			return left_priority < right_priority
		return str(left.get("candidate_id", "")) \
			< str(right.get("candidate_id", ""))
	)
	snapshot["candidate_effects"] = candidate_effects
	snapshot["safe_prefix_count"] = safe_prefix_count
	snapshot["safe_prefix_available"] = safe_prefix_count > 0
	snapshot["review_before_terminal"] = bool(snapshot.get("active", false)) \
		and not bool(snapshot.get("floor_met", true)) \
		and safe_prefix_count > 0
	return snapshot


func _snapshot(
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary],
	profile: Dictionary
) -> Dictionary:
	var config := _config(profile)
	var enabled := bool(config.get("enabled", false))
	var attack: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var prize: Dictionary = facts.get("prize", {}) \
		if facts.get("prize", {}) is Dictionary else {}
	var attack_ready := bool(attack.get("ready", false))
	var ko_available := bool(attack.get("ko_available", false))
	var win_now := bool(prize.get("win_now", false))
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var bench: Array = own.get("bench", []) \
		if own.get("bench", []) is Array else []
	var attack_candidate := _attack_ko_candidate(frontier)
	var burst := _module_annotation(attack_candidate, "energy_burst")
	var raw_units := int(burst.get(
		"damage_raw_units",
		_board_basic_energy_count(own)
	))
	var required_units := int(burst.get(
		"minimum_damage_units_for_active_ko",
		burst.get("minimum_discards_for_active_ko", 0)
	))
	var damage_per_unit := int(burst.get(
		"damage_per_unit",
		burst.get("damage_per_discard", 0)
	))
	var consumptive := str(burst.get("damage_mode", "")) \
		in ["attached_discard", "hand_discard"]
	var engine_uids := _upper_strings(config.get("engine_uids", []))
	var engine_effect_ids := _strings(config.get("engine_effect_ids", []))
	var search_root_uids := _upper_strings(
		config.get("search_engine_root_uids", [])
	)
	var search_engine_uids := _upper_strings(
		config.get("search_engine_uids", [])
	)
	var tera_enabler_uids := _upper_strings(
		config.get("tera_enabler_uids", engine_uids)
	)
	var search_root_search_uids := _upper_strings(
		config.get("search_engine_root_search_uids", [])
	)
	var next_attacker_uids := _upper_strings(
		config.get("next_attacker_uids", [])
	)
	var engine_symbols := _upper_strings(
		config.get("engine_energy_symbols", ["G"])
	)
	var required_attack_types := _upper_strings(
		config.get("required_attack_types", [])
	)
	var live_engine_count := 0
	var energized_engine_count := 0
	var largest_engine_basic_energy_count := 0
	var search_engine_roots := 0
	var live_search_engines := 0
	var available_live_search_engines := 0
	var next_attacker_roots := 0
	var ready_next_attacker_roots := 0
	var active_is_engine := _slot_matches(
		active,
		engine_uids,
		engine_effect_ids
	)
	var active_is_energized_engine := active_is_engine \
		and _slot_has_any_energy_symbol(active, engine_symbols)
	var all_slots: Array = [active]
	all_slots.append_array(bench)
	for raw_slot: Variant in all_slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		if _slot_matches(slot, engine_uids, engine_effect_ids):
			live_engine_count += 1
			if _slot_has_any_energy_symbol(slot, engine_symbols):
				energized_engine_count += 1
			largest_engine_basic_energy_count = maxi(
				largest_engine_basic_energy_count,
				_slot_basic_energy_count(slot)
			)
		var slot_uid := _slot_uid(slot)
		if slot_uid in search_root_uids:
			search_engine_roots += 1
		if slot_uid in search_engine_uids:
			live_search_engines += 1
			if not bool(slot.get("ability_used", false)):
				available_live_search_engines += 1
	for raw_slot: Variant in bench:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		if _slot_uid(slot) in next_attacker_uids:
			next_attacker_roots += 1
			if _slot_has_all_energy_symbols(slot, required_attack_types):
				ready_next_attacker_roots += 1
	var response_mode := str(config.get(
		"credible_response_mode",
		"active_ko_or_engine_loss"
	))
	var active_basic_energy_count := _slot_basic_energy_count(active)
	var bench_basic_energy_count := _slots_basic_energy_count(bench)
	var normal_post_payment_units := maxi(
		0,
		raw_units - required_units
	) if consumptive and ko_available else raw_units
	var active_removed_banked_units := normal_post_payment_units
	var engine_removed_banked_units := normal_post_payment_units
	if str(burst.get("damage_mode", "")) == "attached_discard":
		var payment_spill_to_bench := maxi(
			0,
			required_units - active_basic_energy_count
		) if ko_available else 0
		active_removed_banked_units = maxi(
			0,
			bench_basic_energy_count - payment_spill_to_bench
		)
		engine_removed_banked_units = maxi(
			0,
			normal_post_payment_units - largest_engine_basic_energy_count
		) if live_engine_count > 0 else active_removed_banked_units
	var active_removed_live_engines := maxi(
		0,
		live_engine_count - (1 if active_is_engine else 0)
	)
	var active_removed_energized_engines := maxi(
		0,
		energized_engine_count - (1 if active_is_energized_engine else 0)
	)
	var engine_removed_live_engines := maxi(
		0,
		live_engine_count - (1 if live_engine_count > 0 else 0)
	)
	var engine_removed_energized_engines := maxi(
		0,
		energized_engine_count - (1 if energized_engine_count > 0 else 0)
	)
	var post_payment_units := normal_post_payment_units
	var projected_live_engine_count := live_engine_count
	var projected_energized_engine_count := energized_engine_count
	match response_mode:
		"current_active_removed":
			post_payment_units = active_removed_banked_units
			projected_live_engine_count = active_removed_live_engines
			projected_energized_engine_count = active_removed_energized_engines
		"highest_energy_engine_removed":
			post_payment_units = engine_removed_banked_units
			projected_live_engine_count = engine_removed_live_engines
			projected_energized_engine_count = engine_removed_energized_engines
		"active_ko_or_engine_loss":
			post_payment_units = mini(
				active_removed_banked_units,
				engine_removed_banked_units
			)
			projected_live_engine_count = mini(
				active_removed_live_engines,
				engine_removed_live_engines
			)
			projected_energized_engine_count = mini(
				active_removed_energized_engines,
				engine_removed_energized_engines
			)
	var minimum_banked_units := maxi(
		0,
		int(config.get("minimum_banked_damage_units", 0))
	)
	var minimum_live_engines := maxi(
		0,
		int(config.get("minimum_live_engine_count", 0))
	)
	var minimum_energized_engines := maxi(
		0,
		int(config.get("minimum_energized_engine_count", 0))
	)
	var minimum_next_attackers := maxi(
		0,
		int(config.get("minimum_next_attacker_roots", 0))
	)
	var minimum_current_live_engines := maxi(
		0,
		int(config.get("minimum_current_live_engine_count", 0))
	)
	var minimum_current_energized_engines := maxi(
		0,
		int(config.get("minimum_current_energized_engine_count", 0))
	)
	var minimum_search_engine_roots := maxi(
		0,
		int(config.get("minimum_search_engine_roots", 0))
	)
	var minimum_future_search_engine_roots := maxi(
		0,
		int(config.get("minimum_future_search_engine_roots", 0))
	)
	var expansion_stadium_uids := _upper_strings(
		config.get("expansion_stadium_uids", [])
	)
	var base_bench_capacity := maxi(
		1,
		int(config.get("base_bench_capacity", 5))
	)
	var expanded_bench_capacity := maxi(
		base_bench_capacity,
		int(config.get("expanded_bench_capacity", 8))
	)
	var board_has_tera := _board_has_tera(observation, facts)
	var active_stadium_uid := _card_uid(observation.get("stadium", {}))
	var configured_expansion_active := board_has_tera \
		and active_stadium_uid in expansion_stadium_uids
	var configured_bench_capacity := expanded_bench_capacity \
		if configured_expansion_active else base_bench_capacity
	var bench_capacity := int(
		own.get(
			"bench_capacity",
			facts.get(
				"board",
				{}
			).get("bench_capacity", configured_bench_capacity)
		)
	)
	var expansion_active := bench_capacity > base_bench_capacity
	var bench_slots_free := int(
		own.get(
			"bench_slots_free",
			maxi(0, bench_capacity - bench.size())
		)
	)
	var productive_basic_uids := _upper_strings(
		config.get("productive_basic_uids", [])
	)
	var productive_basic_in_hand_count := _hand_uid_count(
		own.get("hand", []),
		productive_basic_uids
	)
	var search_engine_in_hand_count := _hand_uid_count(
		own.get("hand", []),
		search_engine_uids
	)
	var search_root_in_hand_count := _hand_uid_count(
		own.get("hand", []),
		search_root_uids
	)
	var energy_engine_in_hand_count := _hand_card_match_count(
		own.get("hand", []),
		engine_uids,
		engine_effect_ids
	)
	var hand_has_engine_energy := _hand_has_energy_symbol(
		own.get("hand", []),
		engine_symbols
	)
	var search_engine_evolution_available := _legal_action_card_uid_exists(
		observation,
		"evolve",
		search_engine_uids
	)
	var tera_enabler_development_available := \
		_legal_action_card_uid_exists(
			observation,
			"play_basic_to_bench",
			tera_enabler_uids
		)
	# A Noctowl whose Ability is already spent cannot provide another search
	# checkpoint. An unused Noctowl is the current lane, while an unevolved root
	# is a future lane. Keeping these two time horizons separate prevents the
	# graph from treating today's activation as tomorrow's engine.
	var search_engine_lane_count := search_engine_roots \
		+ available_live_search_engines
	var search_engine_root_search_available := \
		_legal_action_card_uid_exists(
			observation,
			"play_trainer",
			search_root_search_uids
		)
	var own_prizes_remaining := int(own.get("prizes_remaining", 6))
	var sustain_search_engine_until := maxi(
		0,
		int(config.get(
			"sustain_search_engine_until_own_prizes_at_most",
			0
		))
	)
	var future_search_lane_required := own_prizes_remaining \
		> sustain_search_engine_until \
		and available_live_search_engines > 0
	var required_search_engine_lanes := minimum_search_engine_roots \
		+ (
			minimum_future_search_engine_roots
			if future_search_lane_required else 0
		)
	var search_root_force_window_open := own_prizes_remaining >= int(
		config.get("force_search_root_only_when_own_prizes_at_least", 0)
	)
	var visible_search_chain_ready := search_root_force_window_open \
		and search_engine_in_hand_count > 0 \
		and (
			search_root_in_hand_count > 0 \
			or search_engine_root_search_available
		)
	var visible_energy_chain_ready := energy_engine_in_hand_count > 0 \
		and hand_has_engine_energy
	var immediate_engine_chain_ready := visible_search_chain_ready \
		or visible_energy_chain_ready
	var debt_types: Array[String] = []
	var review_non_terminal_attack := bool(
		config.get("review_before_non_terminal_attack", false)
	)
	var review_during_main_phase := bool(
		config.get("review_during_main_phase", false)
	)
	var main_phase_commitment_available := _has_main_phase_commitment(
		frontier
	)
	var continuity_active := enabled \
		and not win_now \
		and (
			ko_available \
			or (review_non_terminal_attack and attack_ready) \
			or (
				review_during_main_phase \
				and main_phase_commitment_available
			)
		)
	if continuity_active:
		if post_payment_units < minimum_banked_units:
			debt_types.append("banked_damage_units")
		if projected_live_engine_count < minimum_live_engines:
			debt_types.append("live_energy_engine")
		if projected_energized_engine_count < minimum_energized_engines:
			debt_types.append("energized_energy_engine")
		if live_engine_count < minimum_current_live_engines:
			debt_types.append("energy_engine_width")
		if energized_engine_count < minimum_current_energized_engines:
			debt_types.append("energized_engine_width")
		if search_engine_lane_count < required_search_engine_lanes:
			debt_types.append("search_engine_root")
		if (
				search_engine_evolution_available \
				or available_live_search_engines > 0
			) \
				and not board_has_tera \
				and tera_enabler_development_available:
			debt_types.append("tera_enabler_for_search_activation")
		if search_engine_evolution_available and board_has_tera:
			debt_types.append("search_engine_activation")
		if next_attacker_roots < minimum_next_attackers:
			debt_types.append("next_attacker_root")
		elif bool(config.get("require_next_attacker_cost_ready", false)) \
				and ready_next_attacker_roots < minimum_next_attackers:
			debt_types.append("next_attacker_attack_cost")
		var preserve_slots := maxi(
			0,
			int(config.get("preserve_bench_slots", 1))
		)
		var has_development_debt := _has_any_debt(debt_types, [
			"live_energy_engine",
			"energized_energy_engine",
			"energy_engine_width",
			"energized_engine_width",
			"search_engine_root",
			"next_attacker_root",
		])
		var capacity_followup_ready := immediate_engine_chain_ready \
			if bool(config.get(
				"force_capacity_only_for_immediate_engine_chain",
				false
			)) \
			else (
				productive_basic_in_hand_count > 0 \
				or live_search_engines > 0 \
				or search_engine_root_search_available
			)
		if has_development_debt \
				and not expansion_active \
				and board_has_tera \
				and not expansion_stadium_uids.is_empty() \
				and bench_slots_free <= preserve_slots \
				and capacity_followup_ready:
			debt_types.push_front("bench_capacity_for_engines")
	var floor_met := debt_types.is_empty()
	var desired_search_role_pairs := _desired_search_role_pairs(debt_types)
	var desired_search_roles: Array[String] = []
	for pair: Array[String] in desired_search_role_pairs:
		for role: String in pair:
			if role not in desired_search_roles:
				desired_search_roles.append(role)
	return {
		"schema_version": 1,
		"enabled": enabled,
		"active": continuity_active,
		"attack_ready": attack_ready,
		"ko_available": ko_available,
		"main_phase_commitment_available": (
			main_phase_commitment_available
		),
		"win_now_override": win_now,
		"floor_met": floor_met,
		"attack_uptime_next_turn": floor_met,
		"credible_response_mode": response_mode,
		"opponent_response_assumption": response_mode,
		"damage_per_unit": damage_per_unit,
		"minimum_lethal_units": required_units,
		"raw_damage_units": raw_units,
		"current_board_basic_energy_units": _board_basic_energy_count(own),
		"active_removed_banked_units": active_removed_banked_units,
		"engine_removed_banked_units": engine_removed_banked_units,
		"post_payment_banked_units": post_payment_units,
		"minimum_banked_damage_units": minimum_banked_units,
		"projected_next_turn_damage": post_payment_units * damage_per_unit,
		"current_live_engine_count": live_engine_count,
		"live_engine_count": projected_live_engine_count,
		"minimum_live_engine_count": minimum_live_engines,
		"current_energized_engine_count": energized_engine_count,
		"energized_engine_count": projected_energized_engine_count,
		"minimum_energized_engine_count": minimum_energized_engines,
		"minimum_current_live_engine_count": minimum_current_live_engines,
		"minimum_current_energized_engine_count": (
			minimum_current_energized_engines
		),
		"search_engine_roots": search_engine_roots,
		"live_search_engines": live_search_engines,
		"available_live_search_engines": available_live_search_engines,
		"search_engine_lane_count": search_engine_lane_count,
		"minimum_search_engine_roots": minimum_search_engine_roots,
		"minimum_future_search_engine_roots": (
			minimum_future_search_engine_roots
		),
		"required_search_engine_lanes": required_search_engine_lanes,
		"future_search_lane_required": future_search_lane_required,
		"search_engine_evolution_available": (
			search_engine_evolution_available
		),
		"tera_enabler_development_available": (
			tera_enabler_development_available
		),
		"search_engine_root_search_available": (
			search_engine_root_search_available
		),
		"next_attacker_roots": next_attacker_roots,
		"ready_next_attacker_roots": ready_next_attacker_roots,
		"minimum_next_attacker_roots": minimum_next_attackers,
		"debt_count": debt_types.size(),
		"debt_types": debt_types,
		"desired_search_roles": desired_search_roles,
		"desired_search_role_pairs": desired_search_role_pairs,
		"bench_capacity": bench_capacity,
		"bench_slots_free": bench_slots_free,
		"expansion_active": expansion_active,
		"board_has_tera": board_has_tera,
		"active_stadium_uid": active_stadium_uid,
		"productive_basic_in_hand_count": productive_basic_in_hand_count,
		"search_engine_in_hand_count": search_engine_in_hand_count,
		"search_root_in_hand_count": search_root_in_hand_count,
		"search_root_force_window_open": search_root_force_window_open,
		"energy_engine_in_hand_count": energy_engine_in_hand_count,
		"hand_has_engine_energy": hand_has_engine_energy,
		"visible_search_chain_ready": visible_search_chain_ready,
		"visible_energy_chain_ready": visible_energy_chain_ready,
		"immediate_engine_chain_ready": immediate_engine_chain_ready,
		"opponent_prizes_remaining": int(
			observation.get("opponent", {}).get("prizes_remaining", 6)
		),
		"deck_critical": int(own.get("deck_count", 0)) <= int(
			config.get("critical_deck_threshold", DEFAULT_CRITICAL_DECK)
		),
	}


func _candidate_effect(
	candidate: Dictionary,
	observation: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _config(profile)
	var debt_types: Array = snapshot.get("debt_types", []) \
		if snapshot.get("debt_types", []) is Array else []
	var result := {
		"schema_version": 1,
		"active": bool(snapshot.get("active", false)),
		"reduces_debt": false,
		"progresses_debt": false,
		"debt_reduction_count": 0,
		"debt_types": [],
		"planned_debt_types": [],
		"requires_reobservation": false,
		"force_before_terminal": false,
		"frontier_priority": false,
		"priority": 1000,
		"reason": "",
	}
	if debt_types.is_empty() or not bool(snapshot.get("active", false)):
		return result
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var route_id := str(candidate.get("route_id", ""))
	var action_kind := str(candidate.get("action_kind", ""))
	var roles: Array = candidate.get("action_semantic_roles", []) \
		if candidate.get("action_semantic_roles", []) is Array else []
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	var action_card: Dictionary = action_ref.get("card", {}) \
		if action_ref.get("card", {}) is Dictionary else {}
	var engine_uids := _upper_strings(config.get("engine_uids", []))
	var engine_effect_ids := _strings(config.get("engine_effect_ids", []))
	var search_root_uids := _upper_strings(
		config.get("search_engine_root_uids", [])
	)
	var search_engine_uids := _upper_strings(
		config.get("search_engine_uids", [])
	)
	var tera_enabler_uids := _upper_strings(
		config.get("tera_enabler_uids", engine_uids)
	)
	var search_root_search_uids := _upper_strings(
		config.get("search_engine_root_search_uids", [])
	)
	var expansion_stadium_uids := _upper_strings(
		config.get("expansion_stadium_uids", [])
	)
	var engine_symbols := _upper_strings(
		config.get("engine_energy_symbols", ["G"])
	)
	var hand_has_engine_energy := _hand_has_energy_symbol(
		own.get("hand", []),
		engine_symbols
	)
	var reductions: Array[String] = []
	var planned_reductions: Array[String] = []
	var progresses := false
	var force := false
	var priority := 1000
	var reason := ""
	var source_is_engine := _card_matches(
		source_card,
		engine_uids,
		engine_effect_ids
	)
	var card_is_engine := _card_matches(
		action_card,
		engine_uids,
		engine_effect_ids
	)
	var action_uid := _card_uid(action_card)
	var search_root_force_ready := not bool(config.get(
		"require_visible_search_engine_followup_for_forced_root",
		false
	)) or (
		int(snapshot.get("search_engine_in_hand_count", 0)) > 0 \
		and bool(snapshot.get("search_root_force_window_open", true))
	)
	if action_kind == "play_stadium" \
			and action_uid in expansion_stadium_uids \
			and "bench_capacity_for_engines" in debt_types \
			and bool(snapshot.get("board_has_tera", false)) \
			and not bool(snapshot.get("expansion_active", false)) \
			and not bool(snapshot.get("deck_critical", false)) \
			and _setup_window_is_safe(snapshot, config):
		reductions.append("bench_capacity_for_engines")
		force = bool(config.get(
			"force_expansion_stadium_when_blocked",
			false
		))
		priority = int(config.get("expansion_stadium_priority", 0))
		reason = "public_engine_bench_capacity_expansion"
	elif route_id == "route:noctowl_search" \
			and not bool(snapshot.get("deck_critical", false)):
		# The Ability only opens a typed information checkpoint. Its Trainers
		# still have to be selected and executed, so this node may prioritize the
		# route but must not claim that any continuity debt is already closed.
		planned_reductions.assign(debt_types)
		progresses = not planned_reductions.is_empty()
		force = bool(config.get("force_noctowl_search_when_debt", false)) \
			and (
				not bool(snapshot.get("ko_available", false)) \
				or _setup_window_is_safe(snapshot, config)
			)
		priority = int(config.get("noctowl_search_priority", 5))
		reason = "profiled_noctowl_continuity_search"
	elif action_kind == "play_basic_to_bench" \
			and action_uid in tera_enabler_uids \
			and "tera_enabler_for_search_activation" in debt_types \
			and _development_is_safe(snapshot, config) \
			and _setup_window_is_safe(snapshot, config):
		reductions.append("tera_enabler_for_search_activation")
		force = bool(config.get(
			"force_tera_enabler_before_search_evolution",
			false
		))
		priority = int(config.get("tera_enabler_priority", 8))
		reason = "public_tera_enabler_before_search_evolution"
	elif action_kind == "evolve" \
			and action_uid in search_engine_uids \
			and "search_engine_activation" in debt_types \
			and bool(snapshot.get("board_has_tera", false)) \
			and not bool(snapshot.get("deck_critical", false)) \
			and _setup_window_is_safe(snapshot, config):
		reductions.append("search_engine_activation")
		force = bool(config.get(
			"force_search_engine_evolution_when_ready",
			false
		))
		priority = int(config.get("search_engine_evolution_priority", 10))
		reason = "public_search_engine_evolution"
	elif action_kind == "play_trainer" \
			and action_uid in search_root_search_uids \
			and search_root_force_ready \
			and _search_root_development_is_safe(snapshot, config) \
			and _setup_window_is_safe(snapshot, config):
		for debt: String in [
			"live_energy_engine",
			"energy_engine_width",
			"search_engine_root",
			"next_attacker_root",
		]:
			if debt in debt_types:
				planned_reductions.append(debt)
		progresses = not planned_reductions.is_empty()
		var repairs_non_search_continuity := _has_any_debt(
			planned_reductions,
			[
				"live_energy_engine",
				"energy_engine_width",
				"next_attacker_root",
			]
		)
		force = (
			bool(config.get(
				"force_search_root_acquisition_when_attack_unready",
				false
			)) and not bool(snapshot.get("ko_available", false))
		) or (
			repairs_non_search_continuity \
			and bool(config.get(
				"force_continuity_basic_search_when_debt",
				false
			))
		)
		priority = int(config.get("search_root_acquisition_priority", 15))
		reason = "public_continuity_basic_search_checkpoint"
	elif action_kind == "play_basic_to_bench" \
			and action_uid in search_root_uids \
			and "search_engine_root" in debt_types \
			and search_root_force_ready \
			and _search_root_development_is_safe(snapshot, config) \
			and _setup_window_is_safe(snapshot, config):
		reductions.append("search_engine_root")
		force = bool(config.get(
			"force_search_root_setup_when_missing",
			false
		))
		priority = int(config.get("search_root_setup_priority", 20))
		reason = "public_search_engine_root_setup"
	elif action_kind == "use_ability" \
			and source_is_engine \
			and "energy_accelerator" in roles \
			and hand_has_engine_energy \
			and not bool(snapshot.get("deck_critical", false)):
		for debt: String in [
			"banked_damage_units",
			"energized_energy_engine",
			"energized_engine_width",
		]:
			if debt in debt_types:
				reductions.append(debt)
		force = bool(config.get(
			"force_existing_engine_ability_when_debt",
			false
		)) and _setup_window_is_safe(snapshot, config)
		priority = int(config.get("existing_engine_ability_priority", 30))
		reason = "public_existing_engine_energy_bank"
	elif action_kind == "play_basic_to_bench" \
			and card_is_engine \
			and hand_has_engine_energy \
			and _engine_development_is_safe(observation, snapshot, config):
		for debt: String in [
			"live_energy_engine",
			"energized_energy_engine",
			"banked_damage_units",
			"energy_engine_width",
			"energized_engine_width",
		]:
			if debt in debt_types:
				reductions.append(debt)
		force = bool(config.get("force_engine_setup_when_missing", false))
		priority = int(config.get("engine_setup_priority", 40))
		reason = "public_engine_bench_then_energy_bank"
	elif route_id == "route:energy_commit":
		var burst := _module_annotation(candidate, "energy_burst")
		var attachment: Dictionary = burst.get("attachment", {}) \
			if burst.get("attachment", {}) is Dictionary else {}
		if bool(attachment.get("adds_missing_required_type", false)) \
				and "next_attacker_attack_cost" in debt_types:
			reductions.append("next_attacker_attack_cost")
			priority = 50
			reason = "public_next_attacker_cost_completion"
	elif route_id == "route:accelerate" \
			and (
				"supporter_acceleration" in roles \
				or "energy_mover" in roles
			):
		for debt: String in [
			"banked_damage_units",
			"next_attacker_attack_cost",
		]:
			if debt in debt_types:
				reductions.append(debt)
		priority = 60
		reason = "public_continuity_acceleration"
	result["reduces_debt"] = not reductions.is_empty()
	result["progresses_debt"] = progresses
	result["debt_reduction_count"] = reductions.size()
	result["debt_types"] = reductions
	result["planned_debt_types"] = planned_reductions
	result["requires_reobservation"] = progresses \
		and str(candidate.get("checkpoint_after", "")) \
			== "information_result"
	result["force_before_terminal"] = force \
		and (not reductions.is_empty() or progresses)
	result["frontier_priority"] = not reductions.is_empty() or progresses
	result["priority"] = priority
	result["reason"] = reason
	result["information_checkpoint"] = str(
		candidate.get("checkpoint_after", "")
	) == "information_result"
	result["desired_search_roles"] = snapshot.get(
		"desired_search_roles",
		[]
	)
	return result


func _rewrite_conflicting_module_warnings(
	candidate: Dictionary,
	effect: Dictionary
) -> void:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var relevant_debt_types: Array = effect.get(
		"planned_debt_types",
		effect.get("debt_types", [])
	) if effect.get(
		"planned_debt_types",
		effect.get("debt_types", [])
	) is Array else []
	var burst: Dictionary = annotations.get("energy_burst", {}) \
		if annotations.get("energy_burst", {}) is Dictionary else {}
	if not burst.is_empty():
		burst["route_warning"] = "post_attack_continuity_debt"
		burst["decision_hint"] = "close_post_attack_continuity_then_reobserve"
		burst["optional_information_safe"] = true
		burst["continuity_debt_types"] = relevant_debt_types
		annotations["energy_burst"] = burst
	var noctowl: Dictionary = annotations.get("tera_noctowl_search", {}) \
		if annotations.get("tera_noctowl_search", {}) is Dictionary else {}
	if not noctowl.is_empty() \
			and str(candidate.get("route_id", "")) == "route:noctowl_search":
		noctowl["warning"] = "post_attack_continuity_search"
		noctowl["continuity_opportunity"] = true
		noctowl["continuity_debt_types"] = relevant_debt_types
		annotations["tera_noctowl_search"] = noctowl
	candidate["module_annotations"] = annotations


func _engine_development_is_safe(
	observation: Dictionary,
	snapshot: Dictionary,
	config: Dictionary
) -> bool:
	if bool(snapshot.get("deck_critical", false)):
		return false
	var bench_slots_free := int(snapshot.get("bench_slots_free", 0))
	if bench_slots_free <= int(config.get("preserve_bench_slots", 1)):
		if bench_slots_free <= 0 \
				or not bool(config.get(
					"allow_last_bench_slot_for_immediate_energy_engine",
					false
				)):
			return false
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_prizes := int(opponent.get("prizes_remaining", 6))
	return opponent_prizes > int(
		config.get("avoid_engine_setup_when_opponent_prizes_at_most", 2)
	)


func _development_is_safe(
	snapshot: Dictionary,
	config: Dictionary
) -> bool:
	if bool(snapshot.get("deck_critical", false)):
		return false
	return int(snapshot.get("bench_slots_free", 0)) \
		> int(config.get("preserve_bench_slots", 1))


func _search_root_development_is_safe(
	snapshot: Dictionary,
	_config: Dictionary
) -> bool:
	if bool(snapshot.get("deck_critical", false)):
		return false
	# The reserved normal-bench slot exists specifically for the next engine
	# root.  Let Hoothoot (or the search checkpoint that acquires it) consume
	# that slot; unrelated engine widening still obeys its own safety policy.
	return int(snapshot.get("bench_slots_free", 0)) > 0


func _setup_window_is_safe(
	snapshot: Dictionary,
	config: Dictionary
) -> bool:
	return int(snapshot.get("opponent_prizes_remaining", 6)) \
		> int(config.get(
			"avoid_engine_setup_when_opponent_prizes_at_most",
			2
		))


func _has_main_phase_commitment(frontier: Array[Dictionary]) -> bool:
	for candidate: Dictionary in frontier:
		if str(candidate.get("action_kind", "")) in [
			"attach_energy",
			"attack",
			"granted_attack",
			"end_turn",
		] or str(candidate.get("route_id", "")) in [
			"route:accelerate",
			"route:energy_commit",
			"route:attack_ko",
			"route:attack_pressure",
			"route:end_turn",
		]:
			return true
	return false


func _desired_search_role_pairs(debt_types: Array[String]) -> Array[Array]:
	var pairs: Array[Array] = []
	if "bench_capacity_for_engines" in debt_types:
		pairs.append(["stadium", "pokemon_search"])
	if "next_attacker_root" in debt_types \
			or "live_energy_engine" in debt_types \
			or "energy_engine_width" in debt_types \
			or "search_engine_root" in debt_types:
		pairs.append(["pokemon_search", "energy_access"])
	if "next_attacker_attack_cost" in debt_types:
		pairs.append(["energy_access", "supporter_acceleration"])
	if "banked_damage_units" in debt_types \
			or "energized_energy_engine" in debt_types \
			or "energized_engine_width" in debt_types:
		pairs.append(["energy_access", "supporter_acceleration"])
		pairs.append(["energy_access", "energy_mover"])
	return pairs


func _attack_ko_candidate(frontier: Array[Dictionary]) -> Dictionary:
	var fallback: Dictionary = {}
	for candidate: Dictionary in frontier:
		if str(candidate.get("route_id", "")) != "route:attack_ko":
			continue
		if fallback.is_empty():
			fallback = candidate
		if bool(candidate.get("engine_rule_floor_exact", false)):
			return candidate
	return fallback


func _module_annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) \
		if annotations.get(module_id, {}) is Dictionary else {}


func _board_basic_energy_count(own: Dictionary) -> int:
	var result := 0
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	return _slots_basic_energy_count(slots)


func _slots_basic_energy_count(slots: Array) -> int:
	var result := 0
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		result += _slot_basic_energy_count(raw_slot as Dictionary)
	return result


func _slot_basic_energy_count(slot: Dictionary) -> int:
	var result := 0
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary \
				and str((raw_energy as Dictionary).get("type", "")).to_lower() \
					== "basic energy":
			result += 1
	return result


func _slot_matches(
	slot: Dictionary,
	uids: Array[String],
	effect_ids: Array[String]
) -> bool:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return _card_matches(pokemon, uids, effect_ids)


func _card_matches(
	card: Dictionary,
	uids: Array[String],
	effect_ids: Array[String]
) -> bool:
	return str(card.get("uid", "")).to_upper() in uids \
		or str(card.get("effect_id", "")) in effect_ids


func _slot_uid(slot: Dictionary) -> String:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return str(pokemon.get("uid", "")).to_upper()


func _card_uid(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	return str((value as Dictionary).get("uid", "")).strip_edges().to_upper()


func _board_has_tera(
	observation: Dictionary,
	facts: Dictionary
) -> bool:
	if bool(facts.get("board", {}).get("has_tera", false)):
		return true
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if raw_slot is Dictionary and bool(
			(raw_slot as Dictionary).get("tera", false)
		):
			return true
	return false


func _hand_uid_count(value: Variant, uids: Array[String]) -> int:
	if not (value is Array) or uids.is_empty():
		return 0
	var result := 0
	for raw_card: Variant in value as Array:
		if _card_uid(raw_card) in uids:
			result += 1
	return result


func _hand_card_match_count(
	value: Variant,
	uids: Array[String],
	effect_ids: Array[String]
) -> int:
	if not (value is Array):
		return 0
	var result := 0
	for raw_card: Variant in value as Array:
		if raw_card is Dictionary \
				and _card_matches(raw_card as Dictionary, uids, effect_ids):
			result += 1
	return result


func _legal_action_card_uid_exists(
	observation: Dictionary,
	action_kind: String,
	uids: Array[String]
) -> bool:
	if uids.is_empty():
		return false
	for raw_action: Variant in observation.get("legal_actions", []):
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		if str(action.get("kind", "")) == action_kind \
				and _card_uid(action.get("card", {})) in uids:
			return true
	return false


func _has_any_debt(
	debt_types: Array[String],
	targets: Array[String]
) -> bool:
	for debt: String in targets:
		if debt in debt_types:
			return true
	return false


func _slot_has_any_energy_symbol(
	slot: Dictionary,
	symbols: Array[String]
) -> bool:
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary \
				and _energy_symbol(raw_energy as Dictionary) in symbols:
			return true
	return false


func _slot_has_all_energy_symbols(
	slot: Dictionary,
	symbols: Array[String]
) -> bool:
	if symbols.is_empty():
		return true
	var available: Dictionary = {}
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary:
			var symbol := _energy_symbol(raw_energy as Dictionary)
			if symbol != "":
				available[symbol] = int(available.get(symbol, 0)) + 1
	for symbol: String in symbols:
		var remaining := int(available.get(symbol, 0))
		if remaining <= 0:
			return false
		available[symbol] = remaining - 1
	return true


func _hand_has_energy_symbol(value: Variant, symbols: Array[String]) -> bool:
	if not (value is Array):
		return false
	for raw_card: Variant in value as Array:
		if raw_card is Dictionary \
				and str((raw_card as Dictionary).get("type", "")).to_lower() \
					== "basic energy" \
				and _energy_symbol(raw_card as Dictionary) in symbols:
			return true
	return false


func _energy_symbol(card: Dictionary) -> String:
	return str(
		card.get("energy_provides", card.get("energy_type", ""))
	).strip_edges().to_upper()


func _config(profile: Dictionary) -> Dictionary:
	var value: Variant = profile.get("post_attack_continuity", {})
	return value as Dictionary if value is Dictionary else {}


func _upper_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var text := str(raw).strip_edges().to_upper()
			if text != "" and text not in result:
				result.append(text)
	return result


func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var text := str(raw).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	return result
