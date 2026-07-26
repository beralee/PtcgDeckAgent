extends RefCounted

## Parameterized public-state annotations for the nine non-pilot strategic
## shapes.  One implementation keeps the batch rollout compositional: module
## identity changes the typed facts exposed to the policy graph, never engine
## ownership or hidden-zone access.

const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")

# These public effects make "more non-KO damage" non-monotonic: the extra
# damage can draw cards, move Energy, or damage the attacker.  Keep the list
# local to this isolated V18CPG certificate instead of changing legacy Rule or
# LLM strategy behavior.
const DAMAGE_REACTIVE_ACTIVE_EFFECT_IDS: Array[String] = [
	"0c65d1d9705ccf735d3780b072e3924d", # Team Rocket's Koffing
	"08e4abe39ce058b6724cf68c1e9828e4", # Zamazenta Power Slam reflection
	"76ed73e869ac742e97ea521f200a360e", # Lucky Helmet
	"1bc2bed91258ca0ecfb69e5ee8dc0c79", # Handheld Fan
	"f9db949f369ecead569fb8e3adc4eaee", # Spikemuth Energy
]

const SUPPORTED_IDS: Array[String] = [
	"stage2_chain",
	"dragapult_spread",
	"damage_counter_control",
	"gardevoir_embrace",
	"control_recycle",
	"copy_attack_toolbox",
	"partner_chain",
	"grass_spread",
	"fire_toolbox",
]

var _module_id: String = ""


func configure(module_id: String) -> void:
	_module_id = module_id if module_id in SUPPORTED_IDS else ""


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
	if _module_id == "":
		return frontier.duplicate(true)
	var snapshot := _public_snapshot(observation, facts, semantic_manifest)
	var second_gust_state := _attackless_second_gust_public_state(observation, semantic_manifest) \
		if _module_id == "damage_counter_control" else {}
	var active_gardevoir_state := _attackless_second_gust_public_state(observation, semantic_manifest) \
		if _module_id == "gardevoir_embrace" else {}
	for route: Dictionary in frontier:
		var annotated := route.duplicate(true)
		var annotations: Dictionary = annotated.get("module_annotations", {}) \
			if annotated.get("module_annotations", {}) is Dictionary else {}
		var module_annotation := _annotation_for(
			route,
			snapshot,
			profile,
			second_gust_state,
			active_gardevoir_state
		)
		annotations[_module_id] = module_annotation
		annotated["module_annotations"] = annotations
		result.append(annotated)
	return result


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	# Strategic-shape annotations inform the model and the shared safety shield.
	# They do not mint a dominance certificate until a dedicated exact fixture
	# proves a public monotonic invariant for that shape.
	return {"valid": true, "reason": "%s_public_shape_valid" % _module_id}


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var dragon_weakness_field := _dragon_weakness_field_annotation(selected)
	var top_dragon_weakness_field := _dragon_weakness_field_annotation(local_top)
	if _module_id == "gardevoir_embrace" \
			and bool(dragon_weakness_field.get("advances_immediate_dragon_ko", false)) \
			and not bool(top_dragon_weakness_field.get("advances_immediate_dragon_ko", false)) \
			and bool(local_top.get("engine_rule_floor_exact", false)) \
			and str(dragon_weakness_field.get("context_key", "")) != "":
		return {
			"verified": true,
			"reason": "public_field_weakness_turns_ready_attack_into_immediate_dragon_ko",
			"certificate_kind": "public_dragon_weakness_field_immediate_ko",
			"evidence_kind": "public_exact_same_turn_field_effect_and_attack",
			"interaction_owner": "not_required",
			"context_key": str(dragon_weakness_field.get("context_key", "")),
			"field_uid": str(dragon_weakness_field.get("field_uid", "")),
			"attacker_uid": str(dragon_weakness_field.get("attacker_uid", "")),
			"opponent_uid": str(dragon_weakness_field.get("opponent_uid", "")),
			"base_damage": int(dragon_weakness_field.get("base_damage", 0)),
			"weakness_damage": int(dragon_weakness_field.get("weakness_damage", 0)),
			"opponent_remaining_hp": int(
				dragon_weakness_field.get("opponent_remaining_hp", 0)
			),
		}
	var active_gardevoir_completion := _active_gardevoir_completion_annotation(selected)
	var top_active_gardevoir_completion := _active_gardevoir_completion_annotation(local_top)
	if _module_id == "gardevoir_embrace" \
			and bool(active_gardevoir_completion.get("advances_active_gardevoir_ko_completion", false)) \
			and not bool(top_active_gardevoir_completion.get("advances_active_gardevoir_ko_completion", false)):
		return {
			"verified": true,
			"reason": "public_psychic_embrace_completes_active_gardevoir_ko_cost",
			"certificate_kind": "public_active_gardevoir_attack_completion",
			"evidence_kind": "public_exact_repeated_single_step_reobserve",
			"interaction_owner": "public_active_gardevoir_completion_target",
			"assignments_needed": int(
				active_gardevoir_completion.get("assignments_needed", 0)
			),
			"psychic_energy_in_discard": int(
				active_gardevoir_completion.get("psychic_energy_in_discard", 0)
			),
			"opponent_remaining_hp": int(
				active_gardevoir_completion.get("opponent_remaining_hp", 0)
			),
		}
	var visible_stage2_hold := _preserve_visible_stage2_setup_annotation(selected)
	var top_visible_stage2_hold := _preserve_visible_stage2_setup_annotation(local_top)
	if _module_id == "damage_counter_control" \
			and bool(visible_stage2_hold.get("advances_visible_stage2_setup_hold", false)) \
			and bool(top_visible_stage2_hold.get("is_exact_destructive_hand_reset_floor", false)) \
			and str(visible_stage2_hold.get("context_key", "")) != "" \
			and str(visible_stage2_hold.get("context_key", "")) \
				== str(top_visible_stage2_hold.get("context_key", "")) \
			and _visible_stage2_setup_binding_is_valid(visible_stage2_hold) \
			and _visible_stage2_setup_binding_is_valid(top_visible_stage2_hold) \
			and not bool(facts.get("attack", {}).get("ready", false)) \
			and not bool(facts.get("attack", {}).get("ko_available", false)) \
			and not bool(facts.get("prize", {}).get("win_now", false)):
		return {
			"verified": true,
			"reason": "public_exact_stage2_pair_survives_while_research_irreversibly_discards_it",
			"certificate_kind": "public_visible_stage2_setup_preserved_before_destructive_hand_reset",
			"evidence_kind": "public_exact_hand_board_and_opponent_attack_deficit",
			"interaction_owner": "not_required",
			"stage": str(visible_stage2_hold.get("stage", "")),
			"context_key": str(visible_stage2_hold.get("context_key", "")),
			"deck_id": int(visible_stage2_hold.get("deck_id", 0)),
			"deck_content_fingerprint": str(
				visible_stage2_hold.get("deck_content_fingerprint", "")
			),
			"selected_action_id": str(visible_stage2_hold.get("selected_action_id", "")),
			"rule_action_id": str(top_visible_stage2_hold.get("rule_action_id", "")),
			"opponent_attack_energy_deficit": int(
				visible_stage2_hold.get("opponent_attack_energy_deficit", 0)
			),
			"guaranteed_next_turn_pair": bool(
				visible_stage2_hold.get("guaranteed_next_turn_pair", false)
			),
		}
	var active_gardevoir_suffix := _profiled_active_gardevoir_ko_suffix_annotation(selected)
	var top_active_gardevoir_suffix := _profiled_active_gardevoir_ko_suffix_annotation(local_top)
	if _module_id == "gardevoir_embrace" \
			and bool(active_gardevoir_suffix.get("advances_profiled_active_gardevoir_ko_suffix", false)) \
			and bool(top_active_gardevoir_suffix.get("is_exact_rule_floor", false)) \
			and str(active_gardevoir_suffix.get("context_key", "")) != "" \
			and str(active_gardevoir_suffix.get("context_key", "")) \
				== str(top_active_gardevoir_suffix.get("context_key", "")):
		return {
			"verified": true,
			"reason": "public_exact_active_gardevoir_retreat_fuel_ko_suffix",
			"certificate_kind": "profiled_visible_engine_hold",
			"evidence_kind": "public_action_bound_single_step_reobserve",
			"interaction_owner": "profiled_active_gardevoir_ko_suffix_target",
			"stage": str(active_gardevoir_suffix.get("stage", "")),
			"context_key": str(active_gardevoir_suffix.get("context_key", "")),
			"continuation_key": str(active_gardevoir_suffix.get("continuation_key", "")),
			"observation_hash_provenance": str(active_gardevoir_suffix.get(
				"observation_hash_provenance", ""
			)),
		}
	var duplicate_gust_hold := _attackless_duplicate_gust_hold_annotation(selected)
	var top_duplicate_gust_hold := _attackless_duplicate_gust_hold_annotation(local_top)
	if _module_id == "damage_counter_control" \
			and bool(duplicate_gust_hold.get("advances_attackless_duplicate_gust_hold", false)) \
			and bool(top_duplicate_gust_hold.get("is_exact_duplicate_gust_rule_floor", false)) \
			and str(duplicate_gust_hold.get("context_key", "")) != "" \
			and str(duplicate_gust_hold.get("context_key", "")) \
				== str(top_duplicate_gust_hold.get("context_key", "")) \
			and not bool(facts.get("attack", {}).get("ready", false)) \
			and not bool(facts.get("attack", {}).get("ko_available", false)) \
			and not bool(facts.get("prize", {}).get("win_now", false)):
		return {
			"verified": true,
			"reason": "public_exact_duplicate_gust_has_zero_payoff_and_consumes_reserved_gust",
			"certificate_kind": "public_attackless_duplicate_gust_hold",
			"evidence_kind": "public_action_bound_single_step_reobserve",
			"interaction_owner": "not_required",
			"requires_model_graph": true,
			"graph_only": true,
			"stage": str(duplicate_gust_hold.get("stage", "")),
			"context_key": str(duplicate_gust_hold.get("context_key", "")),
			"deck_id": int(duplicate_gust_hold.get("deck_id", 0)),
			"deck_content_fingerprint": str(duplicate_gust_hold.get("deck_content_fingerprint", "")),
			"selected_action_id": str(duplicate_gust_hold.get("selected_action_id", "")),
			"selected_candidate_id": str(duplicate_gust_hold.get("selected_candidate_id", "")),
			"rule_gust_action_id": str(top_duplicate_gust_hold.get("rule_gust_action_id", "")),
			"rule_gust_candidate_id": str(top_duplicate_gust_hold.get("rule_gust_candidate_id", "")),
			"held_card_instance_id": int(duplicate_gust_hold.get("held_card_instance_id", -1)),
			"checkpoint_after": str(duplicate_gust_hold.get("checkpoint_after", "")),
		}
	var second_gust_hold := _attackless_second_gust_hold_annotation(selected)
	var top_second_gust_hold := _attackless_second_gust_hold_annotation(local_top)
	if _module_id == "damage_counter_control" \
			and bool(second_gust_hold.get("advances_attackless_second_gust_hold", false)) \
			and bool(top_second_gust_hold.get("is_exact_harmful_second_gust_floor", false)) \
			and str(second_gust_hold.get("context_key", "")) != "" \
			and str(second_gust_hold.get("context_key", "")) == str(top_second_gust_hold.get("context_key", "")) \
			and not bool(facts.get("attack", {}).get("ready", false)) \
			and not bool(facts.get("attack", {}).get("ko_available", false)):
		return {
			"verified": true,
			"reason": "public_exact_second_gust_releases_ready_attacker_while_hold_preserves_lock",
			"certificate_kind": "public_attackless_second_gust_releases_ready_attacker",
			"evidence_kind": "public_action_bound_single_step_reobserve",
			"interaction_owner": "rules_fallback",
			"stage": str(second_gust_hold.get("stage", "")),
			"deck_id": int(second_gust_hold.get("deck_id", 0)),
			"deck_content_fingerprint": str(second_gust_hold.get("deck_content_fingerprint", "")),
			"selected_action_id": str(second_gust_hold.get("selected_action_id", "")),
			"selected_candidate_id": str(second_gust_hold.get("selected_candidate_id", "")),
			"rule_gust_action_id": str(top_second_gust_hold.get("rule_gust_action_id", "")),
			"rule_gust_candidate_id": str(top_second_gust_hold.get("rule_gust_candidate_id", "")),
			"held_card_instance_id": int(second_gust_hold.get("held_card_instance_id", -1)),
			"released_attacker_slot_id": str(second_gust_hold.get("released_attacker_slot_id", "")),
			"checkpoint_after": str(second_gust_hold.get("checkpoint_after", "")),
		}
	var partner_breakpoint := _verify_partner_damage_breakpoint(selected, local_top, profile)
	if bool(partner_breakpoint.get("verified", false)):
		return partner_breakpoint
	var stage2_search_prefix := _profiled_stage2_search_before_pivot_annotation(selected)
	if bool(stage2_search_prefix.get("advances_profiled_stage2_search_before_pivot", false)) \
			and bool(local_top.get("engine_rule_floor_exact", false)) \
			and str(local_top.get("action_kind", "")) == "retreat" \
			and str(local_top.get("route_id", "")) == "route:pivot":
		var snapshot: Dictionary = stage2_search_prefix.get("public_snapshot", {}) \
			if stage2_search_prefix.get("public_snapshot", {}) is Dictionary else {}
		var states: Dictionary = snapshot.get("slot_state", {}) \
			if snapshot.get("slot_state", {}) is Dictionary else {}
		var top_ref: Dictionary = local_top.get("action_ref", {}) \
			if local_top.get("action_ref", {}) is Dictionary else {}
		var target_slot_id := str(top_ref.get("target", ""))
		var target_state: Dictionary = states.get(target_slot_id, {}) \
			if states.get(target_slot_id, {}) is Dictionary else {}
		var target_energy: Dictionary = (snapshot.get("slot_energy", {}) as Dictionary).get(target_slot_id, {}) \
			if snapshot.get("slot_energy", {}) is Dictionary \
			and (snapshot.get("slot_energy", {}) as Dictionary).get(target_slot_id, {}) is Dictionary else {}
		if str(target_state.get("pokemon_uid", "")).strip_edges().to_upper() \
				== str(stage2_search_prefix.get("deferred_pivot_target_uid", "")) \
				and (target_energy.get("attached_symbols", []) as Array).is_empty() \
					if target_energy.get("attached_symbols", []) is Array else false:
			return {
				"verified": true,
				"reason": "paired_evaluation_reorders_visible_stage2_search_before_irreversible_pivot",
				"certificate_kind": "profiled_stage2_search_before_pivot",
				"evidence_kind": "paired_evaluation_public_same_turn_prefix",
				"interaction_owner": "rules_fallback",
				"deferred_pivot_target_uid": str(stage2_search_prefix.get("deferred_pivot_target_uid", "")),
			}
	var profiled_engine_hold := _profiled_engine_hold_annotation(selected)
	var top_profiled_engine_hold := _profiled_engine_hold_annotation(local_top)
	if bool(profiled_engine_hold.get("advances_profiled_engine_hold", false)) \
			and not bool(top_profiled_engine_hold.get("advances_profiled_engine_hold", false)):
		return {
			"verified": true,
			"reason": "paired_evaluation_preserves_visible_engine_hand_over_information_churn",
			"certificate_kind": "profiled_visible_engine_hold",
			"evidence_kind": "paired_evaluation",
			"interaction_owner": "not_required",
		}
	var profiled_retreat_bridge := _profiled_retreat_bridge_annotation(selected)
	var top_profiled_retreat_bridge := _profiled_retreat_bridge_annotation(local_top)
	if bool(profiled_retreat_bridge.get("advances_profiled_retreat_bridge", false)) \
			and not bool(top_profiled_retreat_bridge.get("advances_profiled_retreat_bridge", false)):
		return {
			"verified": true,
			"reason": "paired_evaluation_builds_same_turn_retreat_bridge",
			"certificate_kind": "profiled_same_turn_retreat_bridge",
			"evidence_kind": "paired_evaluation",
			"interaction_owner": "profiled_embrace_active_target",
		}
	var profiled_engine_search := _profiled_engine_search_annotation(selected)
	var top_profiled_engine_search := _profiled_engine_search_annotation(local_top)
	if bool(profiled_engine_search.get("advances_profiled_engine_search", false)) \
			and not bool(top_profiled_engine_search.get("advances_profiled_engine_search", false)):
		return {
			"verified": true,
			"reason": "paired_evaluation_searches_engine_before_attack_completion",
			"certificate_kind": "profiled_engine_search_before_attack_completion",
			"evidence_kind": "paired_evaluation",
			"interaction_owner": "rules_fallback",
		}
	var profiled_attacker_setup := _profiled_attacker_setup_annotation(selected)
	var top_profiled_attacker_setup := _profiled_attacker_setup_annotation(local_top)
	if bool(profiled_attacker_setup.get("advances_profiled_attacker_setup", false)) \
			and not bool(top_profiled_attacker_setup.get("advances_profiled_attacker_setup", false)):
		return {
			"verified": true,
			"reason": "paired_evaluation_prefers_search_before_attacker_attachment",
			"certificate_kind": "profiled_search_before_attachment_sequence",
			"evidence_kind": "paired_evaluation",
			"interaction_owner": "rules_fallback",
		}
	var profiled_activation := _profiled_counter_activation_annotation(selected)
	var top_profiled_activation := _profiled_counter_activation_annotation(local_top)
	if bool(profiled_activation.get("advances_profiled_activation", false)) \
			and not bool(top_profiled_activation.get("advances_profiled_activation", false)):
		return {
			"verified": true,
			"reason": "paired_evaluation_prefers_profiled_counter_activation",
			"certificate_kind": "profiled_counter_activation",
			"evidence_kind": "paired_evaluation",
			"interaction_owner": "not_required",
		}
	var profiled_reset := _profiled_hand_reset_annotation(selected)
	var top_profiled_reset := _profiled_hand_reset_annotation(local_top)
	if bool(profiled_reset.get("advances_profiled_reset", false)) \
			and not bool(top_profiled_reset.get("advances_profiled_reset", false)):
		return {
			"verified": true,
			"reason": "paired_evaluation_prefers_double_counter_engine_hand_reset",
			"certificate_kind": "profiled_double_counter_engine_hand_reset",
			"evidence_kind": "paired_evaluation",
			"interaction_owner": "not_required",
		}
	var counter_setup := _counter_engine_setup_annotation(selected)
	var top_counter_setup := _counter_engine_setup_annotation(local_top)
	if bool(counter_setup.get("advances_profiled_setup", false)) \
			and not bool(top_counter_setup.get("advances_profiled_setup", false)):
		return {
			"verified": true,
			"reason": "profiled_low_pressure_turn_builds_counter_engine",
			"certificate_kind": "public_profiled_low_pressure_counter_engine_setup",
			"interaction_owner": "not_required",
		}
	var counter_closeout := _counter_mover_closeout_annotation(selected)
	var top_counter_closeout := _counter_mover_closeout_annotation(local_top)
	if bool(counter_closeout.get("advances_final_prize_closeout", false)) \
			and not bool(top_counter_closeout.get("advances_final_prize_closeout", false)):
		return {
			"verified": true,
			"reason": "second_counter_mover_completes_public_final_prize_sequence",
			"certificate_kind": "public_second_counter_mover_final_prize_closeout",
			"interaction_owner": "rule_verified_counter_mover_sequence",
		}
	var counter_before_ko := _counter_mover_before_secured_ko_annotation(selected)
	var top_counter_before_ko := _counter_mover_before_secured_ko_annotation(local_top)
	if bool(counter_before_ko.get("preserves_secured_prize_suffix", false)) \
			and not bool(top_counter_before_ko.get("preserves_secured_prize_suffix", false)):
		return {
			"verified": true,
			"reason": "counter_mover_activation_preserves_public_secured_ko_suffix",
			"certificate_kind": "public_counter_mover_before_secured_ko",
			"evidence_kind": "public_same_turn_suffix",
			"interaction_owner": "rules_fallback",
			"prefix_stage": str(counter_before_ko.get("prefix_stage", "")),
			"prizes_floor": int(counter_before_ko.get("prizes_floor", 0)),
			"win_now": bool(counter_before_ko.get("win_now", false)),
			"target_slot_id": str(counter_before_ko.get("opponent_target_slot_id", "")),
			"move_points": int(counter_before_ko.get("transfer_points", 0)),
		}
	var attack_dominance := _deterministic_attack_dominance_annotation(selected)
	var top_attack_dominance := _deterministic_attack_dominance_annotation(local_top)
	if str(attack_dominance.get("pair_role", "")) == "preferred" \
			and str(top_attack_dominance.get("pair_role", "")) == "dominated" \
			and bool(local_top.get("engine_rule_floor_exact", false)) \
			and str(attack_dominance.get("pair_key", "")) == str(top_attack_dominance.get("pair_key", "")) \
			and str(attack_dominance.get("source_slot_id", "")) == str(top_attack_dominance.get("source_slot_id", "")) \
			and int(attack_dominance.get("projected_damage", 0)) > int(top_attack_dominance.get("projected_damage", 0)):
		return {
			"verified": true,
			"reason": "profiled_same_attacker_fixed_damage_strictly_dominates",
			"certificate_kind": "public_same_attacker_damage_dominance",
			"evidence_kind": "public_same_turn_terminal",
			"interaction_owner": "not_required",
			"damage_floor": int(attack_dominance.get("projected_damage", 0)),
			"dominated_damage": int(top_attack_dominance.get("projected_damage", 0)),
		}
	# Repeated Psychic Embrace is an interaction-bearing future sequence, not a
	# monotonic property of the current single use_ability action. Until the
	# interaction bridge binds the exact target and recomputes the immediate
	# post-action KO, its projection remains diagnostic and cannot mint authority.
	var scaler_tool := _prize_scaler_tool_annotation(selected)
	var top_scaler_tool := _prize_scaler_tool_annotation(local_top)
	if bool(scaler_tool.get("wins_now_after_public_embrace_sequence", false)) \
			and not bool(top_scaler_tool.get("wins_now_after_public_embrace_sequence", false)):
		return {
			"verified": true,
			"reason": "hp_expansion_tool_unlocks_public_final_prize_sequence",
			"certificate_kind": "public_prize_scaler_tool_closeout",
			"interaction_owner": "not_required",
		}
	var selected_attachment := _typed_attachment_annotation(selected)
	var top_attachment := _typed_attachment_annotation(local_top)
	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) \
		if local_top.get("outcome", {}) is Dictionary else {}
	if str(selected.get("route_id", "")) == "route:energy_commit" \
			and bool(selected_attachment.get("target_is_profiled_attacker", false)) \
			and bool(selected_attachment.get("target_is_active", false)) \
			and bool(selected_attachment.get("adds_missing_required_type", false)) \
			and bool(selected_attachment.get("deterministic_attack_window_open", false)) \
			and bool(selected_attachment.get("completes_required_types", false)) \
			and not bool(top_attachment.get("completes_required_types", false)) \
			and (
				not bool(facts.get("attack", {}).get("ready", false))
				or bool(selected_attachment.get("upgrades_public_ko", false))
			) \
			and not bool(facts.get("attack", {}).get("ko_available", false)) \
			and str(local_top.get("route_id", "")) not in ["route:attack_ko", "route:attack_pressure"] \
			and not bool(top_outcome.get("win_now", false)) \
			and int(top_outcome.get("prizes_now", 0)) <= int(selected_outcome.get("prizes_now", 0)):
		var selected_ref: Dictionary = selected.get("action_ref", {}) \
			if selected.get("action_ref", {}) is Dictionary else {}
		var top_ref: Dictionary = local_top.get("action_ref", {}) \
			if local_top.get("action_ref", {}) is Dictionary else {}
		var selected_target := str(selected_ref.get("target", ""))
		var top_target := str(top_ref.get("target", ""))
		if _module_id == "stage2_chain" \
				and bool(selected_attachment.get("upgrades_public_ko", false)) \
				and bool(local_top.get("engine_rule_floor_exact", false)) \
				and str(local_top.get("route_id", "")) == "route:evolve" \
				and str(local_top.get("action_kind", "")) == "evolve" \
				and selected_target != "" \
				and top_target != "" \
				and selected_target != top_target:
			return {
				"verified": true,
				"reason": "public_active_ko_cost_completion_commutes_before_independent_bench_evolve",
				"certificate_kind": "public_active_ko_cost_before_independent_bench_evolve",
				"evidence_kind": "public_exact_same_turn_ko_and_independent_action",
				"interaction_owner": "not_required",
				"selected_target_slot_id": selected_target,
				"independent_evolve_target_slot_id": top_target,
				"projected_damage": int(selected_attachment.get("projected_damage_after_completion", 0)),
				"opponent_remaining_hp": int(selected_attachment.get("opponent_active_remaining_hp", 0)),
			}
		return {
			"verified": true,
			"reason": "profiled_typed_attachment_closes_public_attack_cost_gap",
			"certificate_kind": "public_typed_attack_cost_completion",
			"interaction_owner": "not_required",
		}
	return {"verified": false}


func _verify_partner_damage_breakpoint(
	selected: Dictionary,
	local_top: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "partner_chain" \
			or str(selected.get("route_id", "")) != "route:stadium" \
			or str(selected.get("action_kind", "")) != "play_stadium" \
			or not bool(local_top.get("engine_rule_floor_exact", false)) \
			or str(local_top.get("route_id", "")) not in ["route:attack_ko", "route:attack_pressure"] \
			or str(local_top.get("action_kind", "")) != "attack":
		return {"verified": false}
	var local_certificates: Variant = selected.get("local_certificates", {})
	if not (local_certificates is Dictionary):
		return {"verified": false}
	var raw_certificate: Variant = (local_certificates as Dictionary).get("partner_damage_breakpoint", {})
	if not (raw_certificate is Dictionary):
		return {"verified": false}
	var certificate: Dictionary = raw_certificate
	var certificate_kind := str(certificate.get("certificate_kind", ""))
	if int(certificate.get("schema_version", 0)) != 1 \
			or certificate_kind not in [
				"public_partner_same_turn_prize_breakpoint",
				"public_partner_same_turn_damage_upgrade",
			] \
			or str(certificate.get("evidence_kind", "")) != "engine_public_same_turn_suffix":
		return {"verified": false}
	var prefix: Dictionary = certificate.get("prefix", {}) if certificate.get("prefix", {}) is Dictionary else {}
	var suffix: Dictionary = certificate.get("suffix", {}) if certificate.get("suffix", {}) is Dictionary else {}
	var before: Dictionary = certificate.get("before", {}) if certificate.get("before", {}) is Dictionary else {}
	var after: Dictionary = certificate.get("after", {}) if certificate.get("after", {}) is Dictionary else {}
	var guards: Dictionary = certificate.get("guards", {}) if certificate.get("guards", {}) is Dictionary else {}
	var all_local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = all_local_parameters.get("partner_chain", {}) \
		if all_local_parameters.get("partner_chain", {}) is Dictionary else {}
	var config: Dictionary = parameters.get("same_turn_stadium_attack_breakpoint", {}) \
		if parameters.get("same_turn_stadium_attack_breakpoint", {}) is Dictionary else {}
	var selected_ref: Dictionary = selected.get("action_ref", {}) if selected.get("action_ref", {}) is Dictionary else {}
	var selected_card: Dictionary = selected_ref.get("card", {}) if selected_ref.get("card", {}) is Dictionary else {}
	var top_ref: Dictionary = local_top.get("action_ref", {}) if local_top.get("action_ref", {}) is Dictionary else {}
	var top_source_card: Dictionary = top_ref.get("source_card", {}) if top_ref.get("source_card", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) if local_top.get("outcome", {}) is Dictionary else {}
	if str(prefix.get("card_uid", "")) != str(config.get("booster_uid", "")).strip_edges().to_upper() \
			or str(prefix.get("replaced_stadium_uid", "")) != str(config.get("replaced_stadium_uid", "")).strip_edges().to_upper() \
			or str(suffix.get("attacker_uid", "")) != str(config.get("attacker_uid", "")).strip_edges().to_upper() \
			or int(suffix.get("attack_index", -1)) != int(config.get("attack_index", -2)):
		return {"verified": false}
	if str(selected_card.get("uid", "")) != str(prefix.get("card_uid", "")) \
			or str(top_source_card.get("uid", "")) != str(suffix.get("attacker_uid", "")) \
			or str(top_ref.get("source", "")) != str(suffix.get("attacker_slot_id", "")) \
			or int(top_ref.get("attack_index", -1)) != int(suffix.get("attack_index", -2)):
		return {"verified": false}
	if bool(top_ref.get("projected_knockout", true)) \
			or not bool(top_outcome.get("terminal", false)) \
			or int(top_ref.get("projected_damage", -1)) != int(before.get("effective_damage", -2)) \
			or bool(before.get("knockout", true)) \
			or int(before.get("target_effective_hp", -1)) != int(after.get("target_effective_hp", -2)) \
			or int(after.get("effective_damage", 0)) <= int(before.get("effective_damage", 0)):
		return {"verified": false}
	if certificate_kind == "public_partner_same_turn_prize_breakpoint":
		if not bool(after.get("knockout", false)) \
				or int(after.get("effective_damage", 0)) < int(after.get("target_effective_hp", 1)) \
				or int(after.get("prizes", 0)) <= int(before.get("prizes", 0)):
			return {"verified": false}
	else:
		var minimum_damage_gain := maxi(1, int(config.get("minimum_damage_gain", 1)))
		if not bool(config.get("allow_non_ko_damage_upgrade", false)) \
				or bool(after.get("knockout", true)) \
				or int(after.get("effective_damage", 0)) >= int(after.get("target_effective_hp", 0)) \
				or int(after.get("effective_damage", 0)) - int(before.get("effective_damage", 0)) < minimum_damage_gain \
				or int(before.get("prizes", -1)) != 0 \
				or int(after.get("prizes", -1)) != 0:
			return {"verified": false}
	if not bool(before.get("attack_payable", false)) \
			or bool(before.get("damage_cancelled", true)) \
			or not bool(after.get("attack_payable", false)) \
			or bool(after.get("damage_cancelled", true)) \
			or not bool(suffix.get("active_damage_invariant_under_interaction", false)):
		return {"verified": false}
	if not bool(guards.get("attack_window_open", false)) \
			or not bool(guards.get("target_stable", false)) \
			or bool(guards.get("survival_hook", true)) \
			or bool(guards.get("damage_reactive_hook", true)) \
			or bool(guards.get("random", true)) \
			or bool(guards.get("hidden_info", true)) \
			or not bool(guards.get("interaction_suffix_bound", false)) \
			or bool(guards.get("displaced_suffix_dominates", true)):
		return {"verified": false}
	return {
		"verified": true,
		"reason": "engine_proved_partner_stadium_crosses_same_turn_prize_breakpoint" \
			if certificate_kind == "public_partner_same_turn_prize_breakpoint" \
			else "engine_proved_partner_stadium_same_turn_damage_upgrade",
		"certificate_kind": certificate_kind,
		"evidence_kind": "engine_public_same_turn_suffix",
		"interaction_owner": "rules_fallback",
		"damage_floor": int(after.get("effective_damage", 0)),
		"dominated_damage": int(before.get("effective_damage", 0)),
		"prizes_now": int(after.get("prizes", 0)),
	}


func module_id() -> String:
	return _module_id


func pick_verified_interaction_override(
	items: Array,
	step: Dictionary,
	_rule_selection: Array,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	if _module_id == "damage_counter_control" \
			and certificate_kind == "public_second_counter_mover_final_prize_closeout":
		var counter_override := _counter_closeout_source_interaction_override(
			items, step, context, profile
		)
		if bool(counter_override.get("handled", false)):
			return counter_override
	if _module_id == "partner_chain":
		var poffin_override := _profiled_poffin_distinct_roots_interaction_override(
			items, step, _rule_selection, context, profile, certificate_kind
		)
		if bool(poffin_override.get("handled", false)):
			return poffin_override
	if _module_id == "grass_spread":
		return _profiled_iron_leaves_prize_suffix_interaction_override(
			items, step, context, profile, certificate_kind
		)
	if _module_id == "gardevoir_embrace":
		var active_completion_override := _active_gardevoir_completion_interaction_override(
			items,
			step,
			context,
			profile,
			certificate_kind
		)
		if bool(active_completion_override.get("handled", false)):
			return active_completion_override
		var engine_hold_override := _profiled_engine_hold_interaction_override(
			items, step, context, profile, certificate_kind
		)
		if bool(engine_hold_override.get("handled", false)):
			return engine_hold_override
		return _profiled_retreat_bridge_interaction_override(items, step, context, profile)
	if _module_id != "damage_counter_control" \
			or certificate_kind != "profiled_search_before_attachment_sequence" \
			or str(step.get("id", "")).strip_edges().to_lower() != "basic_pokemon" \
			or int(step.get("max_select", 0)) != 1:
		return {"handled": false, "items": []}
	var parameters := _module_parameters(profile)
	var attacker_uid := str(parameters.get("profiled_setup_attacker_uid", "")).strip_edges().to_upper()
	if attacker_uid == "":
		return {"handled": false, "items": []}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var belief: Dictionary = facts.get("belief", {}) if facts.get("belief", {}) is Dictionary else {}
	var known: Dictionary = belief.get("known_in_deck_uid_counts", {}) \
		if belief.get("known_in_deck_uid_counts", {}) is Dictionary else {}
	if str(belief.get("evidence_kind", "")) != "public_hand_reset_transition" \
			or int(known.get(attacker_uid, 0)) <= 0:
		return {"handled": false, "items": []}
	var selected: Variant = null
	for item: Variant in items:
		if _interaction_item_uid(item) == attacker_uid:
			selected = item
			break
	if selected == null:
		return {"handled": false, "items": []}
	return {
		"handled": true,
		"items": [selected],
		"reason": "public_hand_reset_proves_profiled_attacker_in_deck",
		"certificate_kind": certificate_kind,
	}


func verified_interaction_target_score(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Variant:
	if _module_id == "gardevoir_embrace" \
			and certificate_kind == "profiled_visible_engine_hold" \
			and str(step.get("id", "")).strip_edges().to_lower() == "embrace_target" \
			and int(step.get("min_select", 1)) == 1 \
			and int(step.get("max_select", 0)) == 1 \
			and item is PokemonSlot:
		var observation: Dictionary = context.get("v18cpg_observation", {}) \
			if context.get("v18cpg_observation", {}) is Dictionary else {}
		var facts: Dictionary = context.get("v18cpg_facts", {}) \
			if context.get("v18cpg_facts", {}) is Dictionary else {}
		var semantic_manifest: Dictionary = context.get("v18cpg_semantic_manifest", {}) \
			if context.get("v18cpg_semantic_manifest", {}) is Dictionary else {}
		var parameters := _module_parameters(profile)
		var exact_config: Dictionary = parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {}) \
			if parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {}) is Dictionary else {}
		var exact_state := _attackless_second_gust_public_state(observation, semantic_manifest)
		var exact_stage := _profiled_active_gardevoir_ko_stage(exact_state, exact_config)
		if exact_stage == "":
			var annotated_stage := str(context.get("v18cpg_profiled_gardevoir_stage", ""))
			if annotated_stage in ["first_embrace_to_active", "second_embrace_to_active"]:
				exact_stage = annotated_stage
		var snapshot := _public_snapshot(observation, facts, {})
		if exact_stage in ["first_embrace_to_active", "second_embrace_to_active"] \
				and _profiled_active_gardevoir_ko_config_matches(exact_config, profile, exact_state) \
				and _profiled_active_gardevoir_ko_public_context_matches(
					exact_state, snapshot, exact_config, exact_stage
				):
			var is_exact_active := _interaction_item_uid(item) \
					== str(exact_config.get("active_uid", "")).to_upper() \
				and _interaction_item_effect_id(item) \
					== str(exact_config.get("active_effect_id", "")).to_lower()
			return 1000000.0 if is_exact_active else -1000000.0
		return null
	if _module_id != "damage_counter_control" \
			or certificate_kind != "public_second_counter_mover_final_prize_closeout" \
			or str(step.get("id", "")).strip_edges().to_lower() != "target_damage_counters" \
			or not bool(step.get("use_counter_distribution_ui", false)) \
			or not (item is PokemonSlot):
		return null
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var active_card: Dictionary = active.get("pokemon", {}) \
		if active.get("pokemon", {}) is Dictionary else {}
	var parameters := _module_parameters(profile)
	var move_points := maxi(1, int(parameters.get("move_points_per_use", 0)))
	var attack_damage := int((context.get("v18cpg_facts", {}) as Dictionary).get("attack", {}).get("max_damage", 0)) \
		if context.get("v18cpg_facts", {}) is Dictionary \
		and (context.get("v18cpg_facts", {}) as Dictionary).get("attack", {}) is Dictionary else 0
	var damage_gap := int(active.get("remaining_hp", 0)) - attack_damage
	if damage_gap <= 0 or damage_gap > move_points \
			or int(active.get("prize_count", 0)) < int((observation.get("own", {}) as Dictionary).get("prizes_remaining", 0)) \
				if observation.get("own", {}) is Dictionary else true:
		return null
	var target := item as PokemonSlot
	var top := target.get_top_card()
	if top == null \
			or int(top.instance_id) != int(active_card.get("instance_id", -1)) \
			or target.get_remaining_hp() != int(active.get("remaining_hp", -1)):
		return null
	return 1000000.0


func _counter_closeout_source_interaction_override(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if str(step.get("id", "")).strip_edges().to_lower() != "source_pokemon" \
			or int(step.get("max_select", 0)) != 1:
		return {"handled": false, "items": []}
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var active_card: Dictionary = active.get("pokemon", {}) \
		if active.get("pokemon", {}) is Dictionary else {}
	var parameters := _module_parameters(profile)
	var invariant_attackers: Array[String] = []
	for raw_uid: Variant in parameters.get("damage_invariant_attackers", []):
		invariant_attackers.append(str(raw_uid).strip_edges().to_upper())
	var move_points := maxi(1, int(parameters.get("move_points_per_use", 0)))
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var attack: Dictionary = facts.get("attack", {}) if facts.get("attack", {}) is Dictionary else {}
	var damage_gap := int(opponent_active.get("remaining_hp", 0)) - int(attack.get("max_damage", 0))
	if str(active_card.get("uid", "")).strip_edges().to_upper() not in invariant_attackers \
			or not bool(attack.get("ready", false)) \
			or bool(attack.get("ko_available", false)) \
			or damage_gap <= 0 or damage_gap > move_points \
			or int(opponent_active.get("prize_count", 0)) < int(own.get("prizes_remaining", 0)):
		return {"handled": false, "items": []}
	var active_instance_id := int(active_card.get("instance_id", -1))
	var selected: PokemonSlot = null
	for item: Variant in items:
		if not (item is PokemonSlot):
			continue
		var slot := item as PokemonSlot
		var top := slot.get_top_card()
		if top != null \
				and int(top.instance_id) == active_instance_id \
				and slot.damage_counters >= damage_gap:
			selected = slot
			break
	if selected == null:
		return {"handled": false, "items": []}
	return {
		"handled": true,
		"items": [selected],
		"reason": "public_same_turn_counter_closeout_uses_active_attacker_damage",
		"certificate_kind": "public_second_counter_mover_final_prize_closeout",
	}


func _profiled_poffin_distinct_roots_interaction_override(
	items: Array,
	step: Dictionary,
	rule_selection: Array,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	var parameters := _module_parameters(profile)
	var config: Dictionary = parameters.get("profiled_poffin_distinct_evolution_roots", {}) \
		if parameters.get("profiled_poffin_distinct_evolution_roots", {}) is Dictionary else {}
	var expected_certificate := str(config.get("certificate_kind", "")).strip_edges()
	if not bool(config.get("enabled", false)) \
			or int(config.get("owner_deck_id", 0)) != int(profile.get("deck_id", 0)) \
			or int(profile.get("deck_id", 0)) <= 0 \
			or expected_certificate == "" \
			or certificate_kind not in ["", expected_certificate] \
			or str(step.get("id", "")).strip_edges().to_lower() != str(config.get("step_id", "")).strip_edges().to_lower() \
			or int(step.get("max_select", 0)) != int(config.get("max_select", 0)):
		return {"handled": false, "items": []}
	var root_groups: Array = config.get("root_groups", []) if config.get("root_groups", []) is Array else []
	var preferred_uids: Array = config.get("preferred_basic_uids", []) \
		if config.get("preferred_basic_uids", []) is Array else []
	if root_groups.size() != 2 or preferred_uids.size() != 2:
		return {"handled": false, "items": []}
	var preferred_group_ids: Dictionary = {}
	for raw_uid: Variant in preferred_uids:
		var group_index := _profiled_uid_group_index(str(raw_uid), root_groups)
		if group_index < 0 or preferred_group_ids.has(group_index):
			return {"handled": false, "items": []}
		preferred_group_ids[group_index] = true
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	if own.is_empty():
		return {"handled": false, "items": []}
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	if 5 - bench.size() < int(config.get("minimum_bench_slots_free", 2)):
		return {"handled": false, "items": []}
	var visible_uids: Dictionary = {}
	for raw_slot: Variant in _visible_slots(own):
		if not (raw_slot is Dictionary):
			continue
		var pokemon: Dictionary = (raw_slot as Dictionary).get("pokemon", {}) \
			if (raw_slot as Dictionary).get("pokemon", {}) is Dictionary else {}
		var visible_uid := str(pokemon.get("uid", "")).strip_edges().to_upper()
		if visible_uid != "":
			visible_uids[visible_uid] = true
	if bool(config.get("require_both_groups_absent", false)):
		for raw_group: Variant in root_groups:
			if not (raw_group is Array):
				return {"handled": false, "items": []}
			for raw_uid: Variant in raw_group as Array:
				if visible_uids.has(str(raw_uid).strip_edges().to_upper()):
					return {"handled": false, "items": []}
	var public_hand_uids: Dictionary = {}
	for raw_card: Variant in own.get("hand", []):
		if not (raw_card is Dictionary):
			continue
		var hand_uid := str((raw_card as Dictionary).get("uid", "")).strip_edges().to_upper()
		if hand_uid != "":
			public_hand_uids[hand_uid] = true
	for raw_required_uid: Variant in config.get("required_public_hand_uids", []):
		if not public_hand_uids.has(str(raw_required_uid).strip_edges().to_upper()):
			return {"handled": false, "items": []}
	var required_symbol := str(config.get("required_active_energy_symbol", "")).strip_edges().to_upper()
	if required_symbol != "":
		var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
		var active_has_symbol := false
		for raw_energy: Variant in active.get("energy", []):
			if raw_energy is Dictionary and EnergySymbolsScript.from_card(raw_energy as Dictionary) == required_symbol:
				active_has_symbol = true
				break
		if not active_has_symbol:
			return {"handled": false, "items": []}
	var selected: Array = []
	for raw_preferred_uid: Variant in preferred_uids:
		var preferred_uid := str(raw_preferred_uid).strip_edges().to_upper()
		var selected_item: Variant = null
		for item: Variant in items:
			if _interaction_item_uid(item) == preferred_uid:
				selected_item = item
				break
		if selected_item == null:
			return {"handled": false, "items": []}
		selected.append(selected_item)
	var rule_group_ids: Dictionary = {}
	for item: Variant in rule_selection:
		var rule_group := _profiled_uid_group_index(_interaction_item_uid(item), root_groups)
		if rule_group >= 0:
			rule_group_ids[rule_group] = true
	if rule_group_ids.size() >= 2:
		return {"handled": false, "items": []}
	return {
		"handled": true,
		"items": selected,
		"reason": "public_tm_evolution_suffix_requires_two_distinct_roots",
		"certificate_kind": expected_certificate,
	}


func _profiled_uid_group_index(uid: String, root_groups: Array) -> int:
	var normalized := uid.strip_edges().to_upper()
	if normalized == "":
		return -1
	for group_index: int in root_groups.size():
		var raw_group: Variant = root_groups[group_index]
		if not (raw_group is Array):
			continue
		for raw_uid: Variant in raw_group as Array:
			if str(raw_uid).strip_edges().to_upper() == normalized:
				return group_index
	return -1


func _profiled_iron_leaves_prize_suffix_interaction_override(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	var parameters := _module_parameters(profile)
	var config: Dictionary = parameters.get(
		"profiled_iron_leaves_same_turn_prize_suffix", {}
	) if parameters.get("profiled_iron_leaves_same_turn_prize_suffix", {}) is Dictionary else {}
	var expected_certificate := str(config.get("certificate_kind", "")).strip_edges()
	var owner_deck_id := int(config.get("owner_deck_id", 0))
	if not bool(config.get("enabled", false)) \
			or expected_certificate == "" \
			or owner_deck_id <= 0 \
			or int(profile.get("deck_id", 0)) != owner_deck_id \
			or certificate_kind not in ["", expected_certificate]:
		return {"handled": false, "items": []}

	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	var expected_step_id := str(config.get("interaction_step_id", "")).strip_edges().to_lower()
	var moved_count := int(config.get("required_moved_energy_count", 0))
	var moved_symbol := EnergySymbolsScript.canonical(config.get("moved_energy_symbol", ""))
	if expected_step_id == "" \
			or step_id != expected_step_id \
			or int(step.get("min_select", -1)) != 0 \
			or int(step.get("max_select", -1)) != moved_count \
			or not bool(step.get("allow_cancel", false)) \
			or moved_count <= 0 \
			or items.size() != moved_count \
			or moved_symbol == "other":
		return {"handled": false, "items": []}
	var selected: Array = []
	var selected_instance_ids: Dictionary = {}
	for item: Variant in items:
		if not (item is CardInstance) \
				or _interaction_item_energy_symbol(item) != moved_symbol:
			return {"handled": false, "items": []}
		var instance_id := int((item as CardInstance).instance_id)
		if instance_id <= 0 or selected_instance_ids.has(instance_id):
			return {"handled": false, "items": []}
		selected_instance_ids[instance_id] = true
		selected.append(item)

	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	if observation.is_empty() or facts.is_empty():
		return {"handled": false, "items": []}
	var snapshot := _public_snapshot(observation, facts, {})
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) \
		if turn.get("quotas", {}) is Dictionary else {}
	if not bool(snapshot.get("turn_energy_available", false)) \
			or not bool(quotas.get("energy_available", false)) \
			or not bool(snapshot.get("deterministic_attack_window_open", false)) \
			or bool(snapshot.get("attack_ready", true)) \
			or bool(snapshot.get("ko_available", true)):
		return {"handled": false, "items": []}

	var source_uid := str(config.get("source_pokemon_uid", "")).strip_edges().to_upper()
	var source_action_kind := str(config.get("source_action_kind", "")).strip_edges()
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var hand_energy: Dictionary = snapshot.get("hand_energy_by_symbol", {}) \
		if snapshot.get("hand_energy_by_symbol", {}) is Dictionary else {}
	var manual_symbol := EnergySymbolsScript.canonical(config.get("manual_attach_symbol", ""))
	if source_uid == "" \
			or source_action_kind != "play_basic_to_bench" \
			or int(hand_uid_counts.get(source_uid, 0)) != int(config.get("source_in_hand_count", 1)) \
			or manual_symbol == "other" \
			or int(hand_energy.get(manual_symbol, 0)) != int(config.get("manual_energy_in_hand_count", 1)):
		return {"handled": false, "items": []}

	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var active_uid := str(active.get("pokemon_uid", "")).strip_edges().to_upper()
	var expected_active_uid := str(config.get("pre_action_active_uid", "")).strip_edges().to_upper()
	if states.size() != int(config.get("visible_own_slot_count", -1)) \
			or active_uid == "" \
			or active_uid != expected_active_uid \
			or not (active_energy.get("attached_symbols", []) as Array).is_empty():
		return {"handled": false, "items": []}

	var expected_source_uids: Array[String] = []
	for raw_uid: Variant in config.get("exact_energy_source_uids", []):
		expected_source_uids.append(str(raw_uid).strip_edges().to_upper())
	if expected_source_uids.size() != moved_count \
			or expected_source_uids.has("") \
			or source_uid in _snapshot_pokemon_uids(states):
		return {"handled": false, "items": []}
	var seen_source_uids: Array[String] = []
	var board_energy_count := 0
	var grass_energy_count := 0
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		var slot_state: Dictionary = states.get(slot_id, {}) \
			if states.get(slot_id, {}) is Dictionary else {}
		var slot_energy: Dictionary = energy_states.get(slot_id, {}) \
			if energy_states.get(slot_id, {}) is Dictionary else {}
		var pokemon_uid := str(slot_state.get("pokemon_uid", "")).strip_edges().to_upper()
		var symbols: Array = slot_energy.get("attached_symbols", []) \
			if slot_energy.get("attached_symbols", []) is Array else []
		board_energy_count += symbols.size()
		for raw_symbol: Variant in symbols:
			if EnergySymbolsScript.canonical(raw_symbol) == moved_symbol:
				grass_energy_count += 1
		if pokemon_uid not in expected_source_uids:
			continue
		if pokemon_uid in seen_source_uids \
				or symbols.size() != 1 \
				or EnergySymbolsScript.canonical(symbols[0]) != moved_symbol:
			return {"handled": false, "items": []}
		seen_source_uids.append(pokemon_uid)
	if seen_source_uids.size() != moved_count \
			or board_energy_count != moved_count \
			or grass_energy_count != moved_count:
		return {"handled": false, "items": []}

	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var target_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var target_uid := str(target_pokemon.get("uid", "")).strip_edges().to_upper()
	var target_hp := int(opponent_active.get("remaining_hp", 0))
	var target_prizes := int(opponent_active.get("prize_count", 0))
	var attack_damage := int(config.get("attack_damage", 0))
	if int(snapshot.get("own_prizes_remaining", 0)) != int(config.get("own_prizes_remaining", -1)) \
			or int(snapshot.get("opponent_prizes_remaining", 0)) != int(config.get("opponent_prizes_remaining", -1)) \
			or target_uid != str(config.get("target_pokemon_uid", "")).strip_edges().to_upper() \
			or target_hp != int(config.get("target_remaining_hp", -1)) \
			or target_prizes != int(config.get("target_prize_count", -1)) \
			or attack_damage <= 0 \
			or attack_damage < target_hp:
		return {"handled": false, "items": []}

	var attack_cost := str(config.get("attack_cost", "")).strip_edges().to_upper()
	var post_attach_symbols: Array[String] = []
	for _index: int in moved_count:
		post_attach_symbols.append(moved_symbol)
	post_attach_symbols.append(manual_symbol)
	if int(config.get("attack_index", -1)) < 0 \
			or attack_cost == "" \
			or not _energy_symbols_pay_printed_cost(post_attach_symbols, attack_cost):
		return {"handled": false, "items": []}

	return {
		"handled": true,
		"items": selected,
		"reason": "public_iron_leaves_transfer_plus_manual_attach_secures_two_prizes",
		"certificate_kind": expected_certificate,
		"evidence": {
			"source_action_kind": source_action_kind,
			"source_pokemon_uid": source_uid,
			"step_id": step_id,
			"movable_grass_count": moved_count,
			"selected_energy_count": selected.size(),
			"manual_attach_symbol": manual_symbol,
			"post_attach_energy_count": post_attach_symbols.size(),
			"attack_index": int(config.get("attack_index", -1)),
			"attack_cost": attack_cost,
			"projected_damage": attack_damage,
			"target_pokemon_uid": target_uid,
			"target_remaining_hp": target_hp,
			"prizes_now": target_prizes,
			"attack_window_open": true,
			"target_stable": true,
			"hidden_info": false,
			"random": false,
		},
	}


func _snapshot_pokemon_uids(states: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_state: Variant in states.values():
		if not (raw_state is Dictionary):
			continue
		var uid := str((raw_state as Dictionary).get("pokemon_uid", "")).strip_edges().to_upper()
		if uid != "":
			result.append(uid)
	return result


func _energy_symbols_pay_printed_cost(symbols: Array[String], cost: String) -> bool:
	var available := symbols.duplicate()
	var colorless_required := 0
	for index: int in cost.length():
		var required := EnergySymbolsScript.canonical(cost.substr(index, 1))
		if required == "other":
			return false
		if required == "C":
			colorless_required += 1
			continue
		var match_index := available.find(required)
		if match_index < 0:
			return false
		available.remove_at(match_index)
	return available.size() >= colorless_required


func _profiled_engine_hold_interaction_override(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	if certificate_kind != "profiled_visible_engine_hold":
		return {"handled": false, "items": []}
	var parameters := _module_parameters(profile)
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var snapshot := _public_snapshot(observation, facts, {})
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	var max_select := int(step.get("max_select", 0))
	var exact_config: Dictionary = parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {}) \
		if parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {}) is Dictionary else {}
	var semantic_manifest: Dictionary = context.get("v18cpg_semantic_manifest", {}) \
		if context.get("v18cpg_semantic_manifest", {}) is Dictionary else {}
	var exact_state := _attackless_second_gust_public_state(observation, semantic_manifest)
	var exact_stage := _profiled_active_gardevoir_ko_stage(exact_state, exact_config)
	# The action-result event is intentionally one-shot and may be consumed before
	# the engine asks for the ability target. The strategy only supplies this
	# checkpoint after binding the current annotated candidate to the current
	# observation_version; every material public invariant is revalidated below.
	if exact_stage == "":
		var annotated_stage := str(context.get("v18cpg_profiled_gardevoir_stage", ""))
		if annotated_stage in ["first_embrace_to_active", "second_embrace_to_active"]:
			exact_stage = annotated_stage
	if step_id == "embrace_target" and int(step.get("min_select", 1)) == 1 \
			and max_select == 1 \
			and exact_stage in ["first_embrace_to_active", "second_embrace_to_active"] \
			and _profiled_active_gardevoir_ko_config_matches(exact_config, profile, exact_state) \
			and _profiled_active_gardevoir_ko_public_context_matches(
				exact_state, snapshot, exact_config, exact_stage
			):
		for item: Variant in items:
			if item is PokemonSlot \
					and _interaction_item_uid(item) == str(exact_config.get("active_uid", "")).to_upper() \
					and _interaction_item_effect_id(item) == str(exact_config.get("active_effect_id", "")).to_lower():
				return {
					"handled": true,
					"items": [item],
					"reason": "public_exact_embrace_targets_active_gardevoir_ko_suffix",
					"certificate_kind": str(exact_config.get("interaction_certificate_kind", "")),
					"stage": exact_stage,
				}
		return {"handled": false, "items": []}
	if step_id == "discard_cards" and max_select == 1 \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "resource_order"):
		var psychic_uid := str(parameters.get(
			"profiled_engine_hold_resource_order_discard_uid", ""
		)).strip_edges().to_upper()
		for item: Variant in items:
			if _interaction_item_uid(item) == psychic_uid:
				return {
					"handled": true,
					"items": [item],
					"reason": "refinement_banks_psychic_before_manual_attachment",
					"certificate_kind": "profiled_visible_engine_hold_resource_order",
				}
		return {"handled": false, "items": []}
	if step_id == "embrace_target" and max_select == 1:
		for drif_state: String in ["drif_embrace1", "drif_embrace2", "drif_embrace3"]:
			if not _profiled_engine_hold_matches_state(snapshot, parameters, drif_state):
				continue
			var drif_uid := str(parameters.get(
				"profiled_engine_hold_%s_target_uid" % drif_state, ""
			)).strip_edges().to_upper()
			for item: Variant in items:
				if item is PokemonSlot and _interaction_item_uid(item) == drif_uid:
					return {
						"handled": true,
						"items": [item],
						"reason": "embrace_loads_single_prize_drifloon_before_pivot",
						"certificate_kind": "profiled_visible_engine_hold_drif_closeout",
					}
			return {"handled": false, "items": []}
	if step_id == "embrace_target" and max_select == 1 \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "damage_step"):
		var damage_target_uid := str(parameters.get(
			"profiled_engine_hold_damage_step_target_uid", ""
		)).strip_edges().to_upper()
		for item: Variant in items:
			if item is PokemonSlot and _interaction_item_uid(item) == damage_target_uid:
				return {
					"handled": true,
					"items": [item],
					"reason": "second_embrace_raises_public_drifloon_damage_tier",
					"certificate_kind": "profiled_visible_engine_hold_damage_step",
				}
		return {"handled": false, "items": []}
	if step_id == "embrace_target" and max_select == 1 \
			and (_profiled_engine_hold_matches_state(snapshot, parameters, "active_closeout_first") \
				or _profiled_engine_hold_matches_state(snapshot, parameters, "active_closeout_second")):
		var active_closeout_uid := str(parameters.get(
			"profiled_engine_hold_active_closeout_first_source_uid", ""
		)).strip_edges().to_upper()
		for item: Variant in items:
			if item is PokemonSlot and _interaction_item_uid(item) == active_closeout_uid:
				return {
					"handled": true,
					"items": [item],
					"reason": "embrace_completes_active_gardevoir_public_ko",
					"certificate_kind": "profiled_visible_engine_hold_active_closeout",
				}
		return {"handled": false, "items": []}
	if step_id == "discard_cards" and max_select == 2 \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_gust"):
		var wanted_discards := _uid_counts(parameters.get("profiled_engine_hold_attacker_search_discard_uids", []))
		var selected_discards: Array = []
		for item: Variant in items:
			var uid := _interaction_item_uid(item)
			if int(wanted_discards.get(uid, 0)) <= 0:
				continue
			selected_discards.append(item)
			wanted_discards[uid] = int(wanted_discards.get(uid, 0)) - 1
		if selected_discards.size() == 2:
			return {
				"handled": true,
				"items": selected_discards,
				"reason": "ultra_ball_preserves_charm_and_hand_lock",
				"certificate_kind": "profiled_visible_engine_hold_discard_cost",
			}
		return {"handled": false, "items": []}
	# The exact post-gust certificate was minted before Ultra Ball began.  Its
	# discard step mutates the live hand before the full-deck search callback,
	# so the original snapshot no longer matches byte-for-byte at this second
	# interaction even though ownership is still the same audited action.
	if step_id == "search_pokemon" and max_select == 1:
		var attacker_uid := str(parameters.get("profiled_engine_hold_attacker_uid", "")).strip_edges().to_upper()
		for item: Variant in items:
			if _interaction_item_uid(item) == attacker_uid:
				return {
					"handled": true,
					"items": [item],
					"reason": "ultra_ball_fetches_charmed_damage_scaler",
					"certificate_kind": "profiled_visible_engine_hold_attacker_target",
				}
		return {"handled": false, "items": []}
	if max_select != 1:
		return {"handled": false, "items": []}
	var wanted_uid := ""
	var reason := ""
	var interaction_certificate := ""
	if step_id == "search_item" \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "pre"):
		wanted_uid = str(parameters.get("profiled_engine_hold_search_item_uid", "")).strip_edges().to_upper()
		reason = "secret_box_fetches_public_attack_denial_item"
		interaction_certificate = "profiled_visible_engine_hold_item_target"
	elif step_id == "opponent_bench_target" \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_box"):
		wanted_uid = str(parameters.get("profiled_engine_hold_gust_target_uid", "")).strip_edges().to_upper()
		reason = "counter_catcher_isolates_zero_energy_retreat_target"
		interaction_certificate = "profiled_visible_engine_hold_gust_target"
	if wanted_uid == "":
		return {"handled": false, "items": []}
	for item: Variant in items:
		if _interaction_item_uid(item) == wanted_uid:
			return {
				"handled": true,
				"items": [item],
				"reason": reason,
				"certificate_kind": interaction_certificate,
			}
	return {"handled": false, "items": []}


func _profiled_retreat_bridge_interaction_override(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if str(step.get("id", "")).strip_edges().to_lower() != "embrace_target" \
			or int(step.get("max_select", 0)) != 1:
		return {"handled": false, "items": []}
	var parameters := _module_parameters(profile)
	var engine_uid := str(parameters.get("profiled_retreat_bridge_engine_uid", "")).strip_edges().to_upper()
	var attacker_uid := str(parameters.get("profiled_retreat_bridge_attacker_uid", "")).strip_edges().to_upper()
	var bridge_symbol := str(parameters.get("profiled_retreat_bridge_manual_symbol", "D")).strip_edges().to_upper()
	var required_prizes := maxi(0, int(parameters.get("profiled_retreat_bridge_own_prizes_remaining", 0)))
	var required_opponent_prizes := maxi(0, int(parameters.get("profiled_retreat_bridge_opponent_prizes_remaining", 0)))
	var opponent_uid_required := str(parameters.get("profiled_retreat_bridge_opponent_active_uid", "")).strip_edges().to_upper()
	var opponent_hp_required := maxi(0, int(parameters.get("profiled_retreat_bridge_opponent_active_remaining_hp", 0)))
	if engine_uid == "" or attacker_uid == "" or required_prizes <= 0 \
			or required_opponent_prizes <= 0 or opponent_uid_required == "" \
			or opponent_hp_required <= 0:
		return {"handled": false, "items": []}
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var snapshot := _public_snapshot(observation, facts, {})
	var states: Dictionary = snapshot.get("slot_state", {}) if snapshot.get("slot_state", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var attacker_ready := false
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		if slot_id == active_slot_id:
			continue
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		var slot_energy: Dictionary = energy_states.get(slot_id, {}) if energy_states.get(slot_id, {}) is Dictionary else {}
		if str(state.get("pokemon_uid", "")).strip_edges().to_upper() == attacker_uid \
				and "P" in (slot_energy.get("attached_symbols", []) as Array):
			attacker_ready = true
			break
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	if str(active.get("pokemon_uid", "")).strip_edges().to_upper() != engine_uid \
			or states.size() != 5 \
			or bridge_symbol not in (active_energy.get("attached_symbols", []) as Array) \
			or not attacker_ready \
			or int(snapshot.get("own_prizes_remaining", 0)) != required_prizes \
			or int(snapshot.get("opponent_prizes_remaining", 0)) != required_opponent_prizes \
			or str(opponent_pokemon.get("uid", "")).strip_edges().to_upper() != opponent_uid_required \
			or int(opponent_active.get("remaining_hp", 0)) != opponent_hp_required \
			or int(snapshot.get("psychic_energy_in_discard", 0)) <= 0 \
			or bool(snapshot.get("attack_ready", false)):
		return {"handled": false, "items": []}
	for item: Variant in items:
		if item is PokemonSlot and _interaction_item_uid(item) == engine_uid:
			return {
				"handled": true,
				"items": [item],
				"reason": "psychic_embrace_completes_active_retreat_bridge",
				"certificate_kind": "profiled_same_turn_retreat_bridge_target",
			}
	return {"handled": false, "items": []}


func _interaction_item_data(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is CardData:
		return item as CardData
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	return null


func _interaction_item_uid(item: Variant) -> String:
	var data := _interaction_item_data(item)
	return data.get_uid().strip_edges().to_upper() if data != null else ""


func _interaction_item_effect_id(item: Variant) -> String:
	var data := _interaction_item_data(item)
	return str(data.effect_id).strip_edges().to_lower() if data != null else ""


func _interaction_item_energy_symbol(item: Variant) -> String:
	var data := _interaction_item_data(item)
	if data == null:
		return "other"
	return EnergySymbolsScript.from_card({
		"type": str(data.card_type),
		"energy_type": str(data.energy_provides) if str(data.energy_provides) != "" else str(data.energy_type),
	})


func _public_snapshot(
	observation: Dictionary,
	facts: Dictionary,
	semantic_manifest: Dictionary
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var slots := _visible_slots(own)
	var opponent_slots := _visible_slots(opponent)
	var role_counts: Dictionary = {}
	var energy_by_symbol := {"G": 0, "R": 0, "W": 0, "L": 0, "P": 0, "F": 0, "D": 0, "M": 0, "C": 0, "N": 0, "other": 0}
	var slot_energy: Dictionary = {}
	var slot_state: Dictionary = {}
	var opponent_slot_state: Dictionary = {}
	var hand_uid_counts: Dictionary = {}
	var discard_uid_counts: Dictionary = {}
	var hand_energy_by_symbol := {"G": 0, "R": 0, "W": 0, "L": 0, "P": 0, "F": 0, "D": 0, "M": 0, "C": 0, "N": 0, "other": 0}
	var damage_counters := 0
	var psychic_discard_energy := 0
	for raw_card: Variant in own.get("hand", []):
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		var uid := str(card.get("uid", "")).strip_edges().to_upper()
		if uid != "":
			hand_uid_counts[uid] = int(hand_uid_counts.get(uid, 0)) + 1
		if str(card.get("type", "")) == "Basic Energy":
			var hand_symbol := _energy_symbol(card)
			hand_energy_by_symbol[hand_symbol] = int(hand_energy_by_symbol.get(hand_symbol, 0)) + 1
	var visible_discard_counts: Variant = own.get("discard_counts", {})
	if visible_discard_counts is Dictionary and not (visible_discard_counts as Dictionary).is_empty():
		for raw_uid: Variant in (visible_discard_counts as Dictionary).keys():
			discard_uid_counts[str(raw_uid).strip_edges().to_upper()] = int(
				(visible_discard_counts as Dictionary).get(raw_uid, 0)
			)
	elif own.get("discard", []) is Array:
		for raw_card: Variant in own.get("discard", []):
			if not (raw_card is Dictionary):
				continue
			var uid := str((raw_card as Dictionary).get("uid", "")).strip_edges().to_upper()
			if uid != "":
				discard_uid_counts[uid] = int(discard_uid_counts.get(uid, 0)) + 1
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
		var attached_symbols: Array[String] = []
		var attached_cards: Array[Dictionary] = []
		for raw_role: Variant in _roles_for_ref(pokemon, semantic_manifest):
			var role := str(raw_role)
			role_counts[role] = int(role_counts.get(role, 0)) + 1
		for raw_energy: Variant in slot.get("energy", []):
			if raw_energy is Dictionary:
				var symbol := _energy_symbol(raw_energy as Dictionary)
				energy_by_symbol[symbol] = int(energy_by_symbol.get(symbol, 0)) + 1
				attached_symbols.append(symbol)
				attached_cards.append(_exact_public_card(raw_energy as Dictionary))
		slot_energy[str(slot.get("slot_id", ""))] = {
			"pokemon_uid": str(pokemon.get("uid", "")).strip_edges().to_upper(),
			"attached_symbols": attached_symbols,
			"attached_cards": attached_cards,
		}
		slot_state[str(slot.get("slot_id", ""))] = {
			"pokemon_uid": str(pokemon.get("uid", "")).strip_edges().to_upper(),
			"tool_uid": str((slot.get("tool", {}) as Dictionary).get("uid", "")).strip_edges().to_upper() \
				if slot.get("tool", {}) is Dictionary else "",
			"remaining_hp": int(slot.get("remaining_hp", 0)),
			"max_hp": int(slot.get("max_hp", 0)),
			"damage_points": int(slot.get("damage", 0)),
			"prize_count": int(slot.get("prize_count", 1)),
			"ability_used": bool(slot.get("ability_used", false)),
		}
		damage_counters += int(slot.get("damage_counters", int(slot.get("damage", 0)) / 10))
	for raw_card: Variant in own.get("discard", []):
		if raw_card is Dictionary \
				and str((raw_card as Dictionary).get("type", "")) == "Basic Energy" \
				and _energy_symbol(raw_card as Dictionary) == "P":
			psychic_discard_energy += 1
	var opponent_active_slot_id := str((opponent.get("active", {}) as Dictionary).get("slot_id", "")) \
		if opponent.get("active", {}) is Dictionary else ""
	for raw_slot: Variant in opponent_slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
		var slot_id := str(slot.get("slot_id", ""))
		opponent_slot_state[slot_id] = {
			"pokemon_uid": str(pokemon.get("uid", "")).strip_edges().to_upper(),
			"remaining_hp": int(slot.get("remaining_hp", 0)),
			"damage_points": int(slot.get("damage", 0)),
			"prize_count": int(slot.get("prize_count", 1)),
			"is_active": slot_id == opponent_active_slot_id,
		}
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	return {
		"own_active_slot_id": str((own.get("active", {}) as Dictionary).get("slot_id", "")) \
			if own.get("active", {}) is Dictionary else "",
		"own_deck_count": int(own.get("deck_count", 0)),
		"opponent_deck_count": int(opponent.get("deck_count", -1)),
		"own_discard_count": (own.get("discard", []) as Array).size() if own.get("discard", []) is Array else 0,
		"bench_slots_free": maxi(0, 5 - ((own.get("bench", []) as Array).size() if own.get("bench", []) is Array else 0)),
		"visible_own_slots": slots.size(),
		"visible_opponent_slots": opponent_slots.size(),
		"visible_role_counts": role_counts,
		"energy_by_symbol": energy_by_symbol,
		"slot_energy": slot_energy,
		"slot_state": slot_state,
		"opponent_slot_state": opponent_slot_state,
		"hand_uid_counts": hand_uid_counts,
		"discard_uid_counts": discard_uid_counts,
		"own_hand_count": int(own.get("hand_count", (own.get("hand", []) as Array).size() \
			if own.get("hand", []) is Array else 0)),
		"hand_energy_by_symbol": hand_energy_by_symbol,
		"own_prizes_remaining": int(own.get("prizes_remaining", 0)),
		"opponent_prizes_remaining": int(opponent.get("prizes_remaining", 0)),
		"known_in_deck_uid_counts": ((facts.get("belief", {}) as Dictionary).get("known_in_deck_uid_counts", {}) as Dictionary).duplicate(true) \
			if facts.get("belief", {}) is Dictionary and (facts.get("belief", {}) as Dictionary).get("known_in_deck_uid_counts", {}) is Dictionary else {},
		"belief_evidence_kind": str((facts.get("belief", {}) as Dictionary).get("evidence_kind", "")) \
			if facts.get("belief", {}) is Dictionary else "",
		"opponent_active": (opponent.get("active", {}) as Dictionary).duplicate(true) \
			if opponent.get("active", {}) is Dictionary else {},
		"own_damage_counters": damage_counters,
		"psychic_energy_in_discard": psychic_discard_energy,
		"attack_ready": bool(facts.get("attack", {}).get("ready", false)),
		"ko_available": bool(facts.get("attack", {}).get("ko_available", false)),
		"attack_max_damage": int(facts.get("attack", {}).get("max_damage", 0)),
		"win_now": bool(facts.get("prize", {}).get("win_now", false)),
		"turn_energy_available": bool(facts.get("turn", {}).get("energy_available", false)),
		"turn_supporter_available": bool(facts.get("turn", {}).get("supporter_available", false)),
		# Missing proof must fail closed. Production observations always supply
		# this bit through ObservationGateway; explicit fixtures opt in when the
		# printed-cost completion is meant to represent an actionable attack.
		"deterministic_attack_window_open": bool(
			turn.get("deterministic_attack_window_open", false)
		),
		"deck_low": bool(facts.get("resources", {}).get("deck_low", false)),
		"deck_critical": bool(facts.get("resources", {}).get("deck_critical", false)),
	}


func _annotation_for(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary,
	second_gust_state: Dictionary = {},
	active_gardevoir_state: Dictionary = {}
) -> Dictionary:
	var route_id := str(route.get("route_id", ""))
	var roles: Array = route.get("action_semantic_roles", []) \
		if route.get("action_semantic_roles", []) is Array else []
	var annotation := {
		"module": _module_id,
		"route_id": route_id,
		"action_kind": str(route.get("action_kind", "")),
		"action_roles": roles.duplicate(),
		"public_snapshot": snapshot.duplicate(true),
		"route_warning": "",
		"decision_hints": [],
		"typed_attachment": _typed_attachment_for_route(route, snapshot, profile),
	}
	match _module_id:
		"stage2_chain":
			annotation["evolution_progress"] = route_id == "route:evolve"
			annotation["setup_debt"] = not bool(snapshot.get("attack_ready", false))
			annotation["decision_hints"] = ["preserve_evolution_roots", "resolve_stage2_dependency_order"]
			var typed_attachment: Dictionary = annotation.get("typed_attachment", {}) \
				if annotation.get("typed_attachment", {}) is Dictionary else {}
			if bool(typed_attachment.get("target_is_active", false)) \
					and bool(typed_attachment.get("completes_required_types", false)) \
					and bool(typed_attachment.get("deterministic_attack_window_open", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = \
					"public_active_ko_cost_before_independent_bench_evolve" \
					if bool(typed_attachment.get("upgrades_public_ko", false)) \
					else "public_typed_attack_cost_completion"
				annotation["verified_evidence_kind"] = "public_exact_active_typed_cost"
				annotation["decision_hints"] = [
					"complete_public_ko_before_independent_development" \
						if bool(typed_attachment.get("upgrades_public_ko", false)) \
						else "complete_active_attack_cost_before_independent_development",
					"preserve_evolution_roots",
					"resolve_stage2_dependency_order",
				]
			var search_before_pivot := _profiled_stage2_search_before_pivot_for_route(route, snapshot, profile)
			annotation["profiled_stage2_search_before_pivot"] = search_before_pivot
			if bool(search_before_pivot.get("advances_profiled_stage2_search_before_pivot", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_stage2_search_before_pivot"
				annotation["verified_evidence_kind"] = "paired_evaluation_public_same_turn_prefix"
		"dragapult_spread":
			annotation["spread_target_count"] = maxi(0, int(snapshot.get("visible_opponent_slots", 0)) - 1)
			annotation["decision_hints"] = ["solve_two_turn_prize_map", "avoid_wasted_spread"]
		"damage_counter_control":
			annotation["movable_counter_budget"] = int(snapshot.get("own_damage_counters", 0))
			var profiled_attacker_setup := _profiled_attacker_setup_for_route(route, snapshot, profile)
			var profiled_activation := _profiled_counter_activation_for_route(route, snapshot, profile)
			var profiled_reset := _profiled_hand_reset_for_route(route, snapshot, profile)
			var counter_setup := _counter_engine_setup_for_route(route, snapshot, profile)
			var counter_closeout := _counter_mover_closeout_for_route(route, snapshot, profile)
			var counter_before_ko := _counter_mover_before_secured_ko_for_route(route, snapshot, profile)
			var attack_dominance := _deterministic_attack_dominance_for_route(route, snapshot, profile)
			var duplicate_gust_hold := _attackless_duplicate_gust_hold_for_route(
				route,
				snapshot,
				profile,
				second_gust_state
			)
			var second_gust_hold := _attackless_second_gust_hold_for_route(
				route,
				snapshot,
				profile,
				second_gust_state
			)
			var preserve_visible_stage2_setup := _preserve_visible_stage2_setup_for_route(
				route,
				snapshot,
				profile,
				second_gust_state
			)
			annotation["profiled_attacker_setup"] = profiled_attacker_setup
			annotation["profiled_counter_activation"] = profiled_activation
			annotation["profiled_hand_reset"] = profiled_reset
			annotation["counter_engine_setup"] = counter_setup
			annotation["counter_mover_closeout"] = counter_closeout
			annotation["counter_mover_before_secured_ko"] = counter_before_ko
			annotation["deterministic_attack_dominance"] = attack_dominance
			annotation["attackless_duplicate_gust_hold"] = duplicate_gust_hold
			annotation["attackless_second_gust_hold"] = second_gust_hold
			if not preserve_visible_stage2_setup.is_empty():
				annotation["preserve_visible_stage2_setup"] = preserve_visible_stage2_setup
			if bool(preserve_visible_stage2_setup.get("advances_visible_stage2_setup_hold", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = \
					"public_visible_stage2_setup_preserved_before_destructive_hand_reset"
				annotation["verified_evidence_kind"] = \
					"public_exact_hand_board_and_opponent_attack_deficit"
			elif bool(profiled_attacker_setup.get("advances_profiled_attacker_setup", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_search_before_attachment_sequence"
				annotation["verified_evidence_kind"] = "paired_evaluation"
			elif bool(profiled_activation.get("advances_profiled_activation", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_counter_activation"
				annotation["verified_evidence_kind"] = "paired_evaluation"
			elif bool(profiled_reset.get("advances_profiled_reset", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_double_counter_engine_hand_reset"
				annotation["verified_evidence_kind"] = "paired_evaluation"
			elif bool(counter_setup.get("advances_profiled_setup", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_profiled_low_pressure_counter_engine_setup"
			elif bool(counter_closeout.get("advances_final_prize_closeout", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_second_counter_mover_final_prize_closeout"
			elif bool(counter_before_ko.get("preserves_secured_prize_suffix", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_counter_mover_before_secured_ko"
				annotation["verified_evidence_kind"] = "public_same_turn_suffix"
			elif str(attack_dominance.get("pair_role", "")) == "preferred":
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_same_attacker_damage_dominance"
				annotation["verified_evidence_kind"] = "public_same_turn_terminal"
			elif bool(duplicate_gust_hold.get("advances_attackless_duplicate_gust_hold", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_attackless_duplicate_gust_hold"
				annotation["verified_evidence_kind"] = "public_action_bound_single_step_reobserve"
			elif bool(second_gust_hold.get("advances_attackless_second_gust_hold", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_attackless_second_gust_releases_ready_attacker"
				annotation["verified_evidence_kind"] = "public_action_bound_single_step_reobserve"
			annotation["decision_hints"] = ["bind_counter_source_and_target", "preserve_counter_engine", "build_profiled_counter_engine_before_trivial_attack", "complete_public_counter_mover_final_prizes", "preserve_safe_counter_mover_prefix_before_secured_ko", "hold_harmful_second_gust"]
		"gardevoir_embrace":
			annotation["psychic_energy_in_discard"] = int(snapshot.get("psychic_energy_in_discard", 0))
			var dragon_weakness_field := _dragon_weakness_field_for_route(
				route,
				snapshot,
				profile
			)
			var active_gardevoir_completion := _active_gardevoir_completion_for_route(
				route,
				snapshot,
				profile
			)
			var active_gardevoir_suffix := _profiled_active_gardevoir_ko_suffix_for_route(
				route,
				snapshot,
				profile,
				active_gardevoir_state
			)
			var profiled_engine_hold := _profiled_engine_hold_for_route(route, snapshot, profile)
			var profiled_retreat_bridge := _profiled_retreat_bridge_for_route(route, snapshot, profile)
			var profiled_engine_search := _profiled_engine_search_for_route(route, snapshot, profile)
			var tool_closeout := _prize_scaler_tool_for_route(route, snapshot, profile)
			var embrace_closeout := _prize_scaler_embrace_for_route(route, snapshot, profile)
			annotation["dragon_weakness_field"] = dragon_weakness_field
			annotation["active_gardevoir_completion"] = active_gardevoir_completion
			annotation["profiled_active_gardevoir_ko_suffix"] = active_gardevoir_suffix
			annotation["profiled_engine_hold"] = profiled_engine_hold
			annotation["profiled_retreat_bridge"] = profiled_retreat_bridge
			annotation["profiled_engine_search"] = profiled_engine_search
			annotation["prize_scaler_tool"] = tool_closeout
			annotation["prize_scaler_embrace"] = embrace_closeout
			if bool(dragon_weakness_field.get("advances_immediate_dragon_ko", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = \
					"public_dragon_weakness_field_immediate_ko"
				annotation["verified_evidence_kind"] = \
					"public_exact_same_turn_field_effect_and_attack"
			elif bool(active_gardevoir_completion.get(
				"advances_active_gardevoir_ko_completion",
				false
			)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = \
					"public_active_gardevoir_attack_completion"
				annotation["verified_evidence_kind"] = \
					"public_exact_repeated_single_step_reobserve"
			elif bool(active_gardevoir_suffix.get("advances_profiled_active_gardevoir_ko_suffix", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_visible_engine_hold"
				annotation["verified_evidence_kind"] = "public_action_bound_single_step_reobserve"
			elif bool(profiled_engine_hold.get("advances_profiled_engine_hold", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_visible_engine_hold"
				annotation["verified_evidence_kind"] = "paired_evaluation"
			elif bool(profiled_retreat_bridge.get("advances_profiled_retreat_bridge", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_same_turn_retreat_bridge"
				annotation["verified_evidence_kind"] = "paired_evaluation"
			elif bool(profiled_engine_search.get("advances_profiled_engine_search", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "profiled_engine_search_before_attack_completion"
				annotation["verified_evidence_kind"] = "paired_evaluation"
			elif bool(tool_closeout.get("wins_now_after_public_embrace_sequence", false)):
				annotation["verified_advantage"] = true
				annotation["verified_advantage_kind"] = "public_prize_scaler_tool_closeout"
			elif bool(embrace_closeout.get("diagnostic_projected_future_sequence", false)):
				annotation["route_warning"] = "unbound_future_embrace_sequence_is_diagnostic_only"
			annotation["decision_hints"] = [
				"respect_damage_budget",
				"complete_attack_cost_exactly",
				"bench_dragon_weakness_field_before_attacking_when_it_creates_a_ko",
				"tutor_hp_expansion_before_embrace_when_it_unlocks_final_prizes",
			]
		"control_recycle":
			annotation["non_damage_victory_live"] = bool(snapshot.get("deck_low", false))
			annotation["decision_hints"] = ["measure_both_deck_clocks", "preserve_recovery_loop"]
		"copy_attack_toolbox":
			annotation["copy_source_count"] = int((snapshot.get("visible_role_counts", {}) as Dictionary).get("copy_source", 0)) if snapshot.get("visible_role_counts", {}) is Dictionary else 0
			annotation["decision_hints"] = ["bind_copy_source", "verify_copied_cost_and_effect"]
		"partner_chain":
			annotation["partner_piece_count"] = int((snapshot.get("visible_role_counts", {}) as Dictionary).get("partner_piece", 0)) if snapshot.get("visible_role_counts", {}) is Dictionary else 0
			annotation["decision_hints"] = ["preserve_named_partner_chain", "bind_partner_tool_and_supporter"]
		"grass_spread":
			annotation["grass_energy_on_board"] = int((snapshot.get("energy_by_symbol", {}) as Dictionary).get("G", 0)) if snapshot.get("energy_by_symbol", {}) is Dictionary else 0
			annotation["decision_hints"] = ["spread_grass_energy_across_attackers", "preserve_energy_mover"]
		"fire_toolbox":
			annotation["fire_energy_on_board"] = int((snapshot.get("energy_by_symbol", {}) as Dictionary).get("R", 0)) if snapshot.get("energy_by_symbol", {}) is Dictionary else 0
			annotation["decision_hints"] = ["bank_fire_energy", "select_attacker_before_moving_energy"]
	return annotation


func _visible_slots(side: Dictionary) -> Array:
	var result: Array = []
	if side.get("active", {}) is Dictionary and not (side.get("active", {}) as Dictionary).is_empty():
		result.append(side.get("active", {}))
	if side.get("bench", []) is Array:
		result.append_array(side.get("bench", []))
	return result


func _attackless_second_gust_public_state(
	observation: Dictionary,
	semantic_manifest: Dictionary
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) if turn.get("quotas", {}) is Dictionary else {}
	var event: Dictionary = observation.get("event", {}) if observation.get("event", {}) is Dictionary else {}
	var discard_cards: Array[Dictionary] = _exact_public_cards(own.get("discard", []))
	var discard_counts: Dictionary = (own.get("discard_counts", {}) as Dictionary).duplicate(true) \
		if own.get("discard_counts", {}) is Dictionary else {}
	if discard_counts.is_empty() and not discard_cards.is_empty():
		discard_counts = _uid_counts_from_public_cards(discard_cards)
	var own_bench: Dictionary = {}
	for raw_slot: Variant in own.get("bench", []):
		if raw_slot is Dictionary:
			var slot_id := str((raw_slot as Dictionary).get("slot_id", ""))
			if slot_id != "":
				own_bench[slot_id] = _exact_public_slot(raw_slot as Dictionary)
	var opponent_bench: Dictionary = {}
	for raw_slot: Variant in opponent.get("bench", []):
		if raw_slot is Dictionary:
			var slot_id := str((raw_slot as Dictionary).get("slot_id", ""))
			if slot_id != "":
				opponent_bench[slot_id] = _exact_public_slot(raw_slot as Dictionary)
	return {
		"deck_id": int(semantic_manifest.get("deck_id", 0)),
		"deck_content_fingerprint": str(semantic_manifest.get("deck_content_fingerprint", "")),
		"manifest_hash": str(semantic_manifest.get("manifest_hash", "")),
		"observation_version": int(observation.get("observation_version", -1)),
		"observation_hash": str(observation.get("observation_hash", "")),
		"event_kind": str(event.get("kind", "")),
		"event_success": bool(event.get("success", false)),
		"event_action_id": str(event.get("action_id", "")),
		"event_action_kind": str(event.get("action_kind", "")),
		"event_route_id": str(event.get("route_id", "")),
		"event_candidate_id": str(event.get("candidate_id", "")),
		"event_card_instance_id": int(event.get("card_instance_id", -1)),
		"event_target_slot_id": str(event.get("target_slot_id", "")),
		"event_target_instance_id": int(event.get("target_instance_id", -1)),
		"event_previous_active_slot_id": str(event.get("previous_active_slot_id", "")),
		"event_result_active_slot_id": str(event.get("result_active_slot_id", "")),
		"turn_number": int(turn.get("number", -1)),
		"current_player": int(turn.get("current_player", -1)),
		"viewer": int(turn.get("viewer", -1)),
		"phase": int(turn.get("phase", -1)),
		"retreat_available": bool(quotas.get("retreat_available", false)),
		"energy_available": bool(quotas.get("energy_available", false)),
		"supporter_available": bool(quotas.get("supporter_available", false)),
		"deterministic_attack_window_open": bool(turn.get("deterministic_attack_window_open", false)),
		"own_deck_count": int(own.get("deck_count", 0)),
		"own_hand_count": int(own.get("hand_count", (own.get("hand", []) as Array).size() \
			if own.get("hand", []) is Array else 0)),
		"opponent_deck_count": int(opponent.get("deck_count", 0)),
		"opponent_hand_count": int(opponent.get("hand_count", -1)),
		"own_prizes_remaining": int(own.get("prizes_remaining", 0)),
		"opponent_prizes_remaining": int(opponent.get("prizes_remaining", 0)),
		"own_active": _exact_public_slot(own.get("active", {}) as Dictionary) \
			if own.get("active", {}) is Dictionary else {},
		"own_bench": own_bench,
		"opponent_active": _exact_public_slot(opponent.get("active", {}) as Dictionary) \
			if opponent.get("active", {}) is Dictionary else {},
		"opponent_bench": opponent_bench,
		"hand": _exact_public_cards(own.get("hand", [])),
		"discard": discard_cards,
		"discard_counts": discard_counts,
		"public_outcome": (observation.get("public_outcome", {}) as Dictionary).duplicate(true) \
			if observation.get("public_outcome", {}) is Dictionary else {},
		"public_passive": (observation.get("public_passive", {}) as Dictionary).duplicate(true) \
			if observation.get("public_passive", {}) is Dictionary else {},
	}


func _exact_public_slot(slot: Dictionary) -> Dictionary:
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	var slot_id := str(slot.get("slot_id", ""))
	var attacks: Array[String] = []
	var attack_definitions: Array[Dictionary] = []
	var ability_effect_ids: Array[String] = []
	for raw_attack: Variant in pokemon.get("attacks", []):
		if raw_attack is Dictionary:
			attacks.append(str((raw_attack as Dictionary).get("cost", "")))
			attack_definitions.append({
				"index": int((raw_attack as Dictionary).get("index", attack_definitions.size())),
				"cost": _normalized_energy_cost((raw_attack as Dictionary).get("cost", [])),
				"damage": int(str((raw_attack as Dictionary).get("damage", "0"))),
			})
	for raw_ability: Variant in pokemon.get("abilities", []):
		if raw_ability is Dictionary:
			var ability_effect_id := str((raw_ability as Dictionary).get("effect_id", "")).to_lower()
			if ability_effect_id != "":
				ability_effect_ids.append(ability_effect_id)
	var energy_symbols: Array[String] = []
	var energy_cards: Array[Dictionary] = []
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary:
			energy_symbols.append(_energy_symbol(raw_energy as Dictionary))
			energy_cards.append(_exact_public_card(raw_energy as Dictionary))
	var remaining_hp := int(slot.get("remaining_hp", 0))
	var max_hp := int(slot.get("max_hp", pokemon.get("hp", 0)))
	var damage_points := maxi(0, max_hp - remaining_hp) if max_hp > 0 \
		else int(slot.get("damage", int(slot.get("damage_counters", 0)) * 10))
	return {
		"slot_id": slot_id,
		"slot_instance_id": _slot_instance_id(slot_id),
		"pokemon": _exact_public_card(pokemon),
		"attack_costs": attacks,
		"attack_definitions": attack_definitions,
		"ability_effect_ids": ability_effect_ids,
		"energy_symbols": energy_symbols,
		"energy": energy_cards,
		"tool": _exact_public_card(slot.get("tool", {}) as Dictionary) \
			if slot.get("tool", {}) is Dictionary else {},
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"damage_points": damage_points,
		"energy_count": int(slot.get("energy_count", energy_symbols.size())),
		"ability_used": bool(slot.get("ability_used", false)),
		"special_conditions": (slot.get("special_conditions", []) as Array).duplicate() \
			if slot.get("special_conditions", []) is Array else [],
		"public_effects": (slot.get("public_effects", []) as Array).duplicate() \
			if slot.get("public_effects", []) is Array else [],
		"reaction_effects": (slot.get("reaction_effects", []) as Array).duplicate() \
			if slot.get("reaction_effects", []) is Array else [],
		"prize_count": int(slot.get("prize_count", 1)),
		"printed_retreat_cost": int(slot.get("printed_retreat_cost", slot.get("retreat_cost", -1))),
		"effective_retreat_cost": int(slot.get("effective_retreat_cost", -1)),
	}


func _normalized_energy_cost(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw_symbol: Variant in value as Array:
			result.append(str(raw_symbol))
		return result
	for index: int in str(value).length():
		result.append(str(value).substr(index, 1))
	return result


func _exact_public_cards(cards_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (cards_value is Array):
		return result
	for raw_card: Variant in cards_value as Array:
		if raw_card is Dictionary:
			result.append(_exact_public_card(raw_card as Dictionary))
	return result


func _exact_public_card(card: Dictionary) -> Dictionary:
	return {
		"uid": str(card.get("uid", "")).strip_edges().to_upper(),
		"effect_id": str(card.get("effect_id", "")).strip_edges().to_lower(),
		"instance_id": int(card.get("instance_id", -1)),
		"type": str(card.get("type", "")),
		"energy_type": str(card.get("energy_type", "")),
		"energy_provides": str(card.get("energy_provides", "")),
	}


func _active_gardevoir_completion_interaction_override(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	if certificate_kind != "public_active_gardevoir_attack_completion" \
			or str(step.get("id", "")).strip_edges().to_lower() != "embrace_target" \
			or int(step.get("min_select", 1)) != 1 \
			or int(step.get("max_select", 0)) != 1:
		return {"handled": false, "items": []}
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var snapshot := _public_snapshot(observation, facts, {})
	var route := {
		"action_kind": "use_ability",
		"action_ref": {
			"source_card": {
				"uid": str(
					_module_parameters(profile).get(
						"active_gardevoir_public_ko",
						{}
					).get("attacker_uid", "")
				)
			}
		}
	}
	var certificate := _active_gardevoir_completion_for_route(route, snapshot, profile)
	if not bool(certificate.get("advances_active_gardevoir_ko_completion", false)):
		return {"handled": false, "items": []}
	var attacker_uid := str(certificate.get("attacker_uid", "")).strip_edges().to_upper()
	var visible_attacker_count := 0
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	for raw_state: Variant in states.values():
		if raw_state is Dictionary \
				and str((raw_state as Dictionary).get("pokemon_uid", "")).to_upper() \
					== attacker_uid:
			visible_attacker_count += 1
	if visible_attacker_count != 1:
		return {"handled": false, "items": []}
	for item: Variant in items:
		if item is PokemonSlot and _interaction_item_uid(item) == attacker_uid:
			return {
				"handled": true,
				"items": [item],
				"reason": "public_active_gardevoir_attack_completion_target",
				"certificate_kind": certificate_kind,
			}
	return {"handled": false, "items": []}


func _slot_instance_id(slot_id: String) -> int:
	if not slot_id.begins_with("slot:"):
		return -1
	var suffix := slot_id.trim_prefix("slot:")
	return int(suffix) if suffix.is_valid_int() else -1


func _roles_for_ref(card: Dictionary, semantic_manifest: Dictionary) -> Array:
	var uid := str(card.get("uid", ""))
	for raw_card: Variant in semantic_manifest.get("cards", []):
		if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == uid:
			return ((raw_card as Dictionary).get("roles", []) as Array).duplicate() \
				if (raw_card as Dictionary).get("roles", []) is Array else []
	return (card.get("semantic_roles", []) as Array).duplicate() if card.get("semantic_roles", []) is Array else []


func _energy_symbol(card: Dictionary) -> String:
	return EnergySymbolsScript.from_card(card)


func _typed_attachment_for_route(route: Dictionary, snapshot: Dictionary, profile: Dictionary) -> Dictionary:
	if str(route.get("route_id", "")) != "route:energy_commit" \
			or str(route.get("action_kind", "")) != "attach_energy":
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) if route.get("action_ref", {}) is Dictionary else {}
	var target_slot_id := str(action_ref.get("target", ""))
	var slots: Dictionary = snapshot.get("slot_energy", {}) if snapshot.get("slot_energy", {}) is Dictionary else {}
	var target: Dictionary = slots.get(target_slot_id, {}) if slots.get(target_slot_id, {}) is Dictionary else {}
	var target_uid := str(target.get("pokemon_uid", "")).strip_edges().to_upper()
	var parameters := _module_parameters(profile)
	var attack_costs: Dictionary = parameters.get("attack_cost_by_uid", {}) \
		if parameters.get("attack_cost_by_uid", {}) is Dictionary else {}
	var raw_required: Variant = attack_costs.get(target_uid, [])
	var required := EnergySymbolsScript.canonical_array(raw_required)
	var autonomous_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("autonomous_same_quota_completion_uids", []):
		autonomous_uids.append(str(raw_uid).strip_edges().to_upper())
	var attached_cards: Array[Dictionary] = []
	for raw_card: Variant in target.get("attached_cards", []):
		if raw_card is Dictionary:
			attached_cards.append((raw_card as Dictionary).duplicate(true))
	var attached := _typed_payment_symbols(attached_cards, parameters)
	var missing_before := _missing_required_symbols(required, attached)
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var after_cards := attached_cards.duplicate(true)
	after_cards.append(_exact_public_card(card))
	var after := _typed_payment_symbols(after_cards, parameters)
	var attached_symbol := _typed_energy_symbol(
		_exact_public_card(card),
		_count_special_energy_cards(after_cards),
		parameters
	)
	var missing_after := _missing_required_symbols(required, after)
	var fixed_damage_by_uid: Dictionary = parameters.get(
		"fixed_damage_after_cost_completion_by_uid",
		{}
	) if parameters.get("fixed_damage_after_cost_completion_by_uid", {}) is Dictionary else {}
	var projected_damage := maxi(0, int(fixed_damage_by_uid.get(target_uid, 0)))
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var opponent_uid := str(opponent_pokemon.get("uid", "")).strip_edges().to_upper()
	var opponent_hp := maxi(0, int(opponent_active.get("remaining_hp", 0)))
	var allowed_ko_targets: Array[String] = []
	for raw_uid: Variant in parameters.get("cost_completion_ko_target_uids", []):
		var allowed_uid := str(raw_uid).strip_edges().to_upper()
		if allowed_uid != "" and allowed_uid not in allowed_ko_targets:
			allowed_ko_targets.append(allowed_uid)
	var completes_cost := not required.is_empty() and missing_after.is_empty()
	var upgrades_public_ko := target_slot_id != "" \
		and target_slot_id == str(snapshot.get("own_active_slot_id", "")) \
		and completes_cost \
		and bool(snapshot.get("deterministic_attack_window_open", false)) \
		and not bool(snapshot.get("ko_available", false)) \
		and projected_damage > int(snapshot.get("attack_max_damage", 0)) \
		and opponent_hp > 0 \
		and projected_damage >= opponent_hp \
		and opponent_uid in allowed_ko_targets
	return {
		"target_slot_id": target_slot_id,
		"target_uid": target_uid,
		"target_is_active": target_slot_id != "" \
			and target_slot_id == str(snapshot.get("own_active_slot_id", "")),
		"energy_symbol": attached_symbol,
		"required_symbols": required,
		"missing_before": missing_before,
		"missing_after": missing_after,
		"target_is_profiled_attacker": not required.is_empty(),
		"autonomous_same_quota_completion": target_uid in autonomous_uids,
		"deterministic_attack_window_open": bool(
			snapshot.get("deterministic_attack_window_open", false)
		),
		"projected_damage_after_completion": projected_damage,
		"opponent_active_uid": opponent_uid,
		"opponent_active_remaining_hp": opponent_hp,
		"upgrades_public_ko": upgrades_public_ko,
		"adds_missing_required_type": missing_after.size() < missing_before.size(),
		"completes_required_types": completes_cost,
	}


func _missing_required_symbols(required: Array[String], attached: Array[String]) -> Array[String]:
	var available := attached.duplicate()
	var missing: Array[String] = []
	for symbol: String in required:
		if symbol == "C":
			if available.is_empty():
				missing.append(symbol)
			else:
				available.remove_at(0)
			continue
		var index := available.find(symbol)
		if index < 0:
			index = available.find("ANY")
		if index < 0:
			missing.append(symbol)
		else:
			available.remove_at(index)
	return missing


func _typed_payment_symbols(
	cards: Array[Dictionary],
	parameters: Dictionary
) -> Array[String]:
	var result: Array[String] = []
	var special_count := _count_special_energy_cards(cards)
	for card: Dictionary in cards:
		var symbol := _typed_energy_symbol(card, special_count, parameters)
		if symbol != "other":
			result.append(symbol)
	return result


func _typed_energy_symbol(
	card: Dictionary,
	attached_special_count: int,
	parameters: Dictionary
) -> String:
	var uid := str(card.get("uid", "")).strip_edges().to_upper()
	var conditional_any_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("conditional_any_type_energy_uids", []):
		var configured_uid := str(raw_uid).strip_edges().to_upper()
		if configured_uid != "" and configured_uid not in conditional_any_uids:
			conditional_any_uids.append(configured_uid)
	if uid in conditional_any_uids:
		return "ANY" if attached_special_count == 1 else "C"
	return EnergySymbolsScript.from_card(card)


func _count_special_energy_cards(cards: Array[Dictionary]) -> int:
	var count := 0
	for card: Dictionary in cards:
		if str(card.get("type", "")).strip_edges().to_lower() == "special energy":
			count += 1
	return count


func _attackless_duplicate_gust_hold_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get("damage_counter_control", {}) \
		if annotations.get("damage_counter_control", {}) is Dictionary else {}
	return module_annotation.get("attackless_duplicate_gust_hold", {}) \
		if module_annotation.get("attackless_duplicate_gust_hold", {}) is Dictionary else {}


func _attackless_duplicate_gust_hold_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> Dictionary:
	var all_local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var module_parameters: Dictionary = all_local_parameters.get("damage_counter_control", {}) \
		if all_local_parameters.get("damage_counter_control", {}) is Dictionary else {}
	var config: Dictionary = module_parameters.get("attackless_duplicate_gust_hold", {}) \
		if module_parameters.get("attackless_duplicate_gust_hold", {}) is Dictionary else {}
	if not _attackless_duplicate_gust_config_matches(config, profile, state) \
			or bool(snapshot.get("attack_ready", false)) \
			or bool(snapshot.get("ko_available", false)) \
			or bool(snapshot.get("win_now", false)) \
			or not _attackless_duplicate_gust_public_context_matches(state, config):
		return {}

	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var candidate_id := str(route.get("candidate_id", ""))
	var action_id := _attackless_duplicate_gust_bound_action_id(route, candidate_id, config)
	var stage := _attackless_duplicate_gust_stage(state, config)
	var advances := false
	if stage == "attach_tool":
		advances = str(route.get("route_id", "")) == "route:develop" \
			and str(route.get("action_kind", "")) == "attach_tool" \
			and str(route.get("checkpoint_after", "")) == "action_resolved" \
			and action_id == str(config.get("tool_action_id", "")) \
			and candidate_id == str(config.get("tool_candidate_id", "")) \
			and _attackless_duplicate_tool_action_matches(action_ref, config)
	elif stage == "end_after_tool_reobserve":
		advances = str(route.get("route_id", "")) == "route:end_turn" \
			and str(route.get("action_kind", "")) == "end_turn" \
			and str(route.get("checkpoint_after", "")) == "terminal" \
			and action_id == str(config.get("end_action_id", "")) \
			and candidate_id == str(config.get("end_candidate_id", ""))

	var harmful_rule_floor := str(route.get("route_id", "")) == "route:gust" \
		and str(route.get("action_kind", "")) == "play_trainer" \
		and str(route.get("checkpoint_after", "")) == "action_resolved" \
		and bool(route.get("engine_rule_floor_exact", false)) \
		and action_id == str(config.get("rule_gust_action_id", "")) \
		and candidate_id == str(config.get("rule_gust_candidate_id", "")) \
		and _attackless_duplicate_rule_action_matches(action_ref, config)
	var context_key := "%d:%s:%s:%s:%s:%d" % [
		int(state.get("deck_id", 0)),
		str(state.get("deck_content_fingerprint", "")),
		stage,
		str(config.get("opponent_active_slot_id", "")),
		str(config.get("opponent_bench_slot_id", "")),
		int(config.get("second_counter_catcher_instance_id", -1)),
	]
	return {
		"advances_attackless_duplicate_gust_hold": advances,
		"is_exact_duplicate_gust_rule_floor": harmful_rule_floor,
		"stage": stage,
		"context_key": context_key,
		"deck_id": int(state.get("deck_id", 0)),
		"deck_content_fingerprint": str(state.get("deck_content_fingerprint", "")),
		"selected_action_id": action_id,
		"selected_candidate_id": candidate_id,
		"rule_gust_action_id": str(config.get("rule_gust_action_id", "")),
		"rule_gust_candidate_id": str(config.get("rule_gust_candidate_id", "")),
		"held_card_instance_id": int(config.get("second_counter_catcher_instance_id", -1)),
		"checkpoint_after": "action_resolved" if stage == "attach_tool" else "terminal",
	}


func _attackless_duplicate_gust_config_matches(
	config: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> bool:
	if int(config.get("schema_version", 0)) != 1 \
			or str(config.get("certificate_kind", "")) != "public_attackless_duplicate_gust_hold" \
			or int(config.get("deck_id", 0)) != int(profile.get("deck_id", -1)) \
			or int(config.get("deck_id", 0)) != int(state.get("deck_id", -2)) \
			or str(config.get("deck_content_fingerprint", "")) == "" \
			or str(config.get("deck_content_fingerprint", "")) \
				!= str(state.get("deck_content_fingerprint", "")):
		return false
	for key: String in [
		"counter_catcher_uid", "counter_catcher_effect_id",
		"first_gust_action_id", "first_gust_candidate_id",
		"first_gust_target_slot_id", "first_gust_previous_active_slot_id",
		"rule_gust_action_id", "rule_gust_candidate_id", "rule_gust_target_slot_id",
		"interaction_step_id", "own_active_uid", "own_active_effect_id",
		"own_active_slot_id", "own_bench_uid", "own_bench_effect_id",
		"own_bench_slot_id", "opponent_active_uid", "opponent_active_effect_id",
		"opponent_active_slot_id", "opponent_bench_uid", "opponent_bench_effect_id",
		"opponent_bench_slot_id", "tool_uid", "tool_effect_id", "tool_action_id",
		"tool_candidate_id", "tool_target_slot_id", "end_action_id", "end_candidate_id",
		"required_action_result_kind",
	]:
		if str(config.get(key, "")).strip_edges() == "":
			return false
	for key: String in [
		"turn_number", "own_prizes_remaining", "opponent_prizes_remaining",
		"own_deck_count", "opponent_deck_count", "opponent_hand_count",
		"root_hand_count", "post_tool_hand_count", "first_counter_catcher_instance_id",
		"first_gust_target_instance_id", "second_counter_catcher_instance_id",
		"rule_gust_target_instance_id", "own_active_instance_id",
		"own_bench_instance_id", "opponent_active_instance_id",
		"opponent_bench_instance_id", "tool_instance_id", "tool_target_instance_id",
	]:
		if int(config.get(key, -1)) < 0:
			return false
	return config.get("own_active_attack_costs", []) is Array \
		and config.get("own_bench_attack_costs", []) is Array \
		and config.get("opponent_active_attack_costs", []) is Array \
		and config.get("opponent_bench_attack_costs", []) is Array


func _attackless_duplicate_gust_stage(state: Dictionary, config: Dictionary) -> String:
	if str(state.get("event_kind", "")) != str(config.get("required_action_result_kind", "")) \
			or not bool(state.get("event_success", false)):
		return ""
	var action_id := str(state.get("event_action_id", ""))
	if action_id == str(config.get("first_gust_action_id", "")):
		if not _optional_public_string_matches(state, "event_action_kind", "play_trainer") \
				or not _optional_public_string_matches(state, "event_route_id", "route:gust") \
				or not _optional_public_string_matches(
					state, "event_candidate_id", str(config.get("first_gust_candidate_id", ""))
				) \
				or not _optional_public_string_matches(
					state, "event_target_slot_id", str(config.get("first_gust_target_slot_id", ""))
				) \
				or not _optional_public_string_matches(
					state, "event_previous_active_slot_id", str(config.get("first_gust_previous_active_slot_id", ""))
				) \
				or not _optional_public_string_matches(
					state, "event_result_active_slot_id", str(config.get("first_gust_target_slot_id", ""))
				) \
				or not _optional_public_int_matches(
					state, "event_card_instance_id", int(config.get("first_counter_catcher_instance_id", -1))
				) \
				or not _optional_public_int_matches(
					state, "event_target_instance_id", int(config.get("first_gust_target_instance_id", -1))
				):
			return ""
		return "attach_tool"
	if action_id == str(config.get("tool_action_id", "")):
		if not _optional_public_string_matches(state, "event_action_kind", "attach_tool") \
				or not _optional_public_string_matches(state, "event_route_id", "route:develop") \
				or not _optional_public_string_matches(
					state, "event_candidate_id", str(config.get("tool_candidate_id", ""))
				):
			return ""
		return "end_after_tool_reobserve"
	return ""


func _attackless_duplicate_gust_public_context_matches(
	state: Dictionary,
	config: Dictionary
) -> bool:
	var stage := _attackless_duplicate_gust_stage(state, config)
	if stage == "" \
			or int(state.get("turn_number", -1)) != int(config.get("turn_number", -2)) \
			or int(state.get("current_player", -1)) != 0 \
			or int(state.get("viewer", -1)) != 0 \
			or int(state.get("own_prizes_remaining", -1)) != int(config.get("own_prizes_remaining", -2)) \
			or int(state.get("opponent_prizes_remaining", -1)) != int(config.get("opponent_prizes_remaining", -2)) \
			or int(state.get("own_deck_count", -1)) != int(config.get("own_deck_count", -2)) \
			or int(state.get("opponent_deck_count", -1)) != int(config.get("opponent_deck_count", -2)) \
			or int(state.get("opponent_hand_count", -1)) != int(config.get("opponent_hand_count", -2)) \
			or not bool(state.get("energy_available", false)) \
			or not bool(state.get("retreat_available", false)) \
			or not bool(state.get("supporter_available", false)):
		return false
	var expected_hand_count := int(config.get(
		"root_hand_count" if stage == "attach_tool" else "post_tool_hand_count", -1
	))
	var hand: Array[Dictionary] = state.get("hand", []) if state.get("hand", []) is Array else []
	var discard: Array[Dictionary] = state.get("discard", []) if state.get("discard", []) is Array else []
	if int(state.get("own_hand_count", -1)) != expected_hand_count \
			or hand.size() != expected_hand_count \
			or not _public_zone_has_exact_or_compact_card(
				hand, {}, str(config.get("counter_catcher_uid", "")),
				str(config.get("counter_catcher_effect_id", "")),
				int(config.get("second_counter_catcher_instance_id", -1)), 1
			) \
			or not _public_zone_has_exact_or_compact_card(
				discard, state.get("discard_counts", {}) if state.get("discard_counts", {}) is Dictionary else {},
				str(config.get("counter_catcher_uid", "")),
				str(config.get("counter_catcher_effect_id", "")),
				int(config.get("first_counter_catcher_instance_id", -1)), 1
			):
		return false
	var own_active: Dictionary = state.get("own_active", {}) if state.get("own_active", {}) is Dictionary else {}
	var own_bench: Dictionary = state.get("own_bench", {}) if state.get("own_bench", {}) is Dictionary else {}
	var opponent_active: Dictionary = state.get("opponent_active", {}) if state.get("opponent_active", {}) is Dictionary else {}
	var opponent_bench: Dictionary = state.get("opponent_bench", {}) if state.get("opponent_bench", {}) is Dictionary else {}
	if own_bench.size() != 1 or opponent_bench.size() != 1:
		return false
	if not _attackless_duplicate_slot_matches(own_active, "own_active", config, true) \
			or not _attackless_duplicate_slot_matches(
				own_bench.get(str(config.get("own_bench_slot_id", "")), {}), "own_bench", config, false
			) \
			or not _attackless_duplicate_slot_matches(opponent_active, "opponent_active", config, true) \
			or not _attackless_duplicate_slot_matches(
				opponent_bench.get(str(config.get("opponent_bench_slot_id", "")), {}),
				"opponent_bench", config, false
			):
		return false
	var tool: Dictionary = own_active.get("tool", {}) if own_active.get("tool", {}) is Dictionary else {}
	var visible_tool_present := str(tool.get("uid", "")) != "" \
		or str(tool.get("effect_id", "")) != "" \
		or int(tool.get("instance_id", -1)) >= 0
	if stage == "attach_tool" and visible_tool_present:
		return false
	if stage == "end_after_tool_reobserve" and not _public_card_binding_matches(
		tool, str(config.get("tool_uid", "")), str(config.get("tool_effect_id", "")),
		int(config.get("tool_instance_id", -1)), true
	):
		return false
	return _attackless_duplicate_optional_outcome_matches(state.get("public_outcome", {})) \
		and _attackless_duplicate_optional_passive_matches(state.get("public_passive", {}), config)


func _attackless_duplicate_slot_matches(
	raw_slot: Variant,
	prefix: String,
	config: Dictionary,
	requires_printed_ability: bool
) -> bool:
	if not (raw_slot is Dictionary):
		return false
	var slot: Dictionary = raw_slot as Dictionary
	if not _public_slot_binding_matches(
		slot, str(config.get("%s_uid" % prefix, "")),
		str(config.get("%s_effect_id" % prefix, "")),
		str(config.get("%s_slot_id" % prefix, "")),
		int(config.get("%s_instance_id" % prefix, -1))
	):
		return false
	if int(slot.get("remaining_hp", -1)) != int(config.get("%s_remaining_hp" % prefix, -2)) \
			or int(slot.get("damage_points", -1)) != int(config.get("%s_damage_points" % prefix, -2)) \
			or int(slot.get("prize_count", -1)) != int(config.get("%s_prize_count" % prefix, -2)) \
			or not (slot.get("energy_symbols", []) as Array).is_empty():
		return false
	var observed_costs: Variant = slot.get("attack_costs", [])
	var expected_costs: Variant = config.get("%s_attack_costs" % prefix, [])
	if observed_costs is Array and not (observed_costs as Array).is_empty() \
			and observed_costs != expected_costs:
		return false
	var abilities: Array = slot.get("ability_effect_ids", []) \
		if slot.get("ability_effect_ids", []) is Array else []
	if not abilities.is_empty():
		var expected_effect := str(config.get("%s_effect_id" % prefix, "")).to_lower()
		if requires_printed_ability and abilities != [expected_effect]:
			return false
		if not requires_printed_ability:
			return false
	return true


func _attackless_duplicate_rule_action_matches(action_ref: Dictionary, config: Dictionary) -> bool:
	if not _rule_gust_action_binding_matches(action_ref, config):
		return false
	for key: String in [
		"projected_prizes", "projected_damage", "check_damage_delta",
	]:
		if action_ref.has(key) and int(action_ref.get(key, -1)) != 0:
			return false
	for key: String in ["changes_attack_readiness", "active_dependent_payoff"]:
		if action_ref.has(key) and bool(action_ref.get(key, true)):
			return false
	var steps: Variant = action_ref.get("interaction_steps", [])
	if steps is Array and not (steps as Array).is_empty():
		var step: Dictionary = (steps as Array)[0] as Dictionary
		if step.get("public_items", []) is Array \
				and (step.get("public_items", []) as Array) != [str(config.get("rule_gust_target_slot_id", ""))]:
			return false
	return true


func _attackless_duplicate_tool_action_matches(action_ref: Dictionary, config: Dictionary) -> bool:
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	return _public_card_binding_matches(
		card, str(config.get("tool_uid", "")), str(config.get("tool_effect_id", "")),
		int(config.get("tool_instance_id", -1)), true
	) \
		and (not action_ref.has("card_instance_id") \
			or int(action_ref.get("card_instance_id", -1)) == int(config.get("tool_instance_id", -2))) \
		and str(action_ref.get("target", "")) == str(config.get("tool_target_slot_id", "")) \
		and (not action_ref.has("target_instance_id") \
			or int(action_ref.get("target_instance_id", -1)) == int(config.get("tool_target_instance_id", -2)))


func _attackless_duplicate_gust_bound_action_id(
	route: Dictionary,
	candidate_id: String,
	config: Dictionary
) -> String:
	var action_ref: Dictionary = route.get("action_ref", {}) if route.get("action_ref", {}) is Dictionary else {}
	var observed := str(route.get("safe_prefix_action_id", action_ref.get("id", "")))
	if observed != "":
		return observed
	if candidate_id == str(config.get("rule_gust_candidate_id", "")):
		return str(config.get("rule_gust_action_id", ""))
	if candidate_id == str(config.get("tool_candidate_id", "")):
		return str(config.get("tool_action_id", ""))
	if candidate_id == str(config.get("end_candidate_id", "")):
		return str(config.get("end_action_id", ""))
	return ""


func _attackless_duplicate_optional_outcome_matches(raw_value: Variant) -> bool:
	if not (raw_value is Dictionary) or (raw_value as Dictionary).is_empty():
		return true
	var value: Dictionary = raw_value as Dictionary
	return not bool(value.get("attack_ready", true)) \
		and not bool(value.get("own_ko_available", true)) \
		and not bool(value.get("win_now", true)) \
		and int(value.get("current_prize_swing", -1)) == 0 \
		and int(value.get("gust_immediate_prizes", -1)) == 0 \
		and int(value.get("gust_immediate_damage", -1)) == 0 \
		and not bool(value.get("gust_changes_attack_readiness", true)) \
		and not bool(value.get("gust_active_dependent_payoff", true)) \
		and int(value.get("gust_check_damage_delta", -1)) == 0


func _attackless_duplicate_optional_passive_matches(
	raw_value: Variant,
	config: Dictionary
) -> bool:
	if not (raw_value is Dictionary) or (raw_value as Dictionary).is_empty():
		return true
	var value: Dictionary = raw_value as Dictionary
	return str(value.get("source_uid", "")).to_upper() == str(config.get("own_active_uid", "")).to_upper() \
		and str(value.get("source_effect_id", "")).to_lower() == str(config.get("own_active_effect_id", "")).to_lower() \
		and str(value.get("scope", "")) == "both_fields_all_pokemon" \
		and bool(value.get("requires_ability", false)) \
		and bool(value.get("position_independent", false)) \
		and int(value.get("damage_per_source", 0)) == 10 \
		and str(value.get("excluded_uid", "")).to_upper() == str(config.get("own_active_uid", "")).to_upper()


func _optional_public_string_matches(state: Dictionary, key: String, expected: String) -> bool:
	var observed := str(state.get(key, ""))
	return observed == "" or observed == expected


func _optional_public_int_matches(state: Dictionary, key: String, expected: int) -> bool:
	var observed := int(state.get(key, -1))
	return observed < 0 or observed == expected


func _preserve_visible_stage2_setup_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get("damage_counter_control", {}) \
		if annotations.get("damage_counter_control", {}) is Dictionary else {}
	return module_annotation.get("preserve_visible_stage2_setup", {}) \
		if module_annotation.get("preserve_visible_stage2_setup", {}) is Dictionary else {}


func _preserve_visible_stage2_setup_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> Dictionary:
	var all_local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var module_parameters: Dictionary = all_local_parameters.get("damage_counter_control", {}) \
		if all_local_parameters.get("damage_counter_control", {}) is Dictionary else {}
	var config: Dictionary = module_parameters.get(
		"preserve_visible_stage2_setup_before_hand_reset", {}
	) if module_parameters.get(
		"preserve_visible_stage2_setup_before_hand_reset", {}
	) is Dictionary else {}
	if not _visible_stage2_setup_config_matches(config, profile, state) \
			or bool(snapshot.get("attack_ready", false)) \
			or bool(snapshot.get("ko_available", false)) \
			or bool(snapshot.get("win_now", false)) \
			or not _visible_stage2_setup_public_context_matches(state, config):
		return {}

	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var action_id := str(route.get("safe_prefix_action_id", action_ref.get("id", "")))
	var advances := str(route.get("route_id", "")) == "route:end_turn" \
		and str(route.get("action_kind", "")) == "end_turn" \
		and str(route.get("checkpoint_after", "")) == "terminal" \
		and not bool(route.get("engine_rule_floor_exact", false)) \
		and action_id != ""
	var action_card: Dictionary = action_ref.get("card", {}) \
		if action_ref.get("card", {}) is Dictionary else {}
	var destructive_floor := str(route.get("route_id", "")) == "route:information" \
		and str(route.get("action_kind", "")) == "play_trainer" \
		and str(route.get("checkpoint_after", "")) == "information_result" \
		and bool(route.get("engine_rule_floor_exact", false)) \
		and action_id != "" \
		and _public_card_identity_matches_without_instance(
			action_card,
			str(config.get("destructive_supporter_uid", "")),
			str(config.get("destructive_supporter_effect_id", ""))
		)
	if not advances and not destructive_floor:
		return {}
	var own_bench: Dictionary = state.get("own_bench", {}) \
		if state.get("own_bench", {}) is Dictionary else {}
	var root_slot: Dictionary = own_bench.values()[0] as Dictionary
	var own_active: Dictionary = state.get("own_active", {}) as Dictionary
	var opponent_active: Dictionary = state.get("opponent_active", {}) as Dictionary
	var public_context := {
		"deck_id": int(state.get("deck_id", 0)),
		"deck_content_fingerprint": str(state.get("deck_content_fingerprint", "")),
		"turn_number": int(state.get("turn_number", -1)),
		"phase": int(state.get("phase", -1)),
		"own_deck_count": int(state.get("own_deck_count", -1)),
		"own_prizes_remaining": int(state.get("own_prizes_remaining", -1)),
		"opponent_deck_count": int(state.get("opponent_deck_count", -1)),
		"opponent_hand_count": int(state.get("opponent_hand_count", -1)),
		"opponent_prizes_remaining": int(state.get("opponent_prizes_remaining", -1)),
		"hand_uid_counts": _uid_counts_from_public_cards(state.get("hand", []) as Array),
		"discard_uid_counts": _normalized_uid_counts_from_dictionary(
			state.get("discard_counts", {}) as Dictionary
		),
		"own_active_slot_id": str(own_active.get("slot_id", "")),
		"root_slot_id": str(root_slot.get("slot_id", "")),
		"opponent_active_slot_id": str(opponent_active.get("slot_id", "")),
		"opponent_attack_energy_deficit": int(config.get("opponent_attack_cost", 0)) \
			- int(opponent_active.get("energy_count", 0)),
	}
	var proof := {
		"verified": advances or destructive_floor,
		"advances_visible_stage2_setup_hold": advances,
		"is_exact_destructive_hand_reset_floor": destructive_floor,
		"stage": "hold_candy_stage2_pair",
		"context_key": JSON.stringify(public_context).sha256_text(),
		"deck_id": int(state.get("deck_id", 0)),
		"deck_content_fingerprint": str(state.get("deck_content_fingerprint", "")),
		"selected_action_id": action_id if advances else "",
		"rule_action_id": action_id if destructive_floor else "",
		"candidate_id": str(route.get("candidate_id", "")),
		"own_active_slot_id": str(own_active.get("slot_id", "")),
		"evolution_root_slot_id": str(root_slot.get("slot_id", "")),
		"opponent_active_slot_id": str(opponent_active.get("slot_id", "")),
		"opponent_attack_energy_deficit": int(config.get("opponent_attack_cost", 0)) \
			- int(opponent_active.get("energy_count", 0)),
		"guaranteed_next_turn_pair": true,
		"checkpoint_after": str(route.get("checkpoint_after", "")),
	}
	proof["binding_hash"] = _visible_stage2_setup_binding_hash(proof)
	return proof


func _visible_stage2_setup_config_matches(
	config: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> bool:
	if int(config.get("schema_version", 0)) != 1 \
			or not bool(config.get("enabled", false)) \
			or int(config.get("deck_id", 0)) != int(profile.get("deck_id", -1)) \
			or int(config.get("deck_id", 0)) != int(state.get("deck_id", -2)) \
			or str(config.get("deck_content_fingerprint", "")) == "" \
			or str(config.get("deck_content_fingerprint", "")) \
				!= str(state.get("deck_content_fingerprint", "")):
		return false
	for key: String in [
		"destructive_supporter_uid", "destructive_supporter_effect_id",
		"own_active_uid", "own_active_effect_id", "evolution_root_uid",
		"evolution_root_effect_id", "opponent_active_uid", "opponent_active_effect_id",
	]:
		if str(config.get(key, "")).strip_edges() == "":
			return false
	return config.get("required_hand_cards", []) is Array \
		and (config.get("required_hand_cards", []) as Array).size() == 4 \
		and config.get("required_discard_uid_counts", {}) is Dictionary \
		and int(config.get("opponent_attack_cost", 0)) > 0 \
		and int(config.get("opponent_attack_energy_deficit", 0)) > 0


func _visible_stage2_setup_public_context_matches(
	state: Dictionary,
	config: Dictionary
) -> bool:
	if int(state.get("turn_number", -1)) != int(config.get("turn_number", -2)) \
			or int(state.get("current_player", -1)) != int(state.get("viewer", -2)) \
			or int(state.get("phase", -1)) != int(config.get("phase", -2)) \
			or not bool(state.get("deterministic_attack_window_open", false)) \
			or bool(state.get("energy_available", true)) \
			or not bool(state.get("supporter_available", false)) \
			or int(state.get("own_deck_count", -1)) != int(config.get("own_deck_count", -2)) \
			or int(state.get("own_hand_count", -1)) != 4 \
			or int(state.get("own_prizes_remaining", -1)) != int(config.get("own_prizes_remaining", -2)) \
			or int(state.get("opponent_deck_count", -1)) != int(config.get("opponent_deck_count", -2)) \
			or int(state.get("opponent_hand_count", -1)) != int(config.get("opponent_hand_count", -2)) \
			or int(state.get("opponent_prizes_remaining", -1)) != int(config.get("opponent_prizes_remaining", -2)):
		return false
	var hand: Array[Dictionary] = state.get("hand", []) \
		if state.get("hand", []) is Array else []
	if not _public_cards_match_exact_uid_effect_multiset(
		hand,
		config.get("required_hand_cards", [])
	):
		return false
	var discard_counts := _normalized_uid_counts_from_dictionary(
		state.get("discard_counts", {}) if state.get("discard_counts", {}) is Dictionary else {}
	)
	var expected_discard := _normalized_uid_counts_from_dictionary(
		config.get("required_discard_uid_counts", {}) as Dictionary
	)
	if discard_counts != expected_discard:
		return false
	var own_active: Dictionary = state.get("own_active", {}) \
		if state.get("own_active", {}) is Dictionary else {}
	if not _public_slot_uid_shape_matches(
		own_active,
		str(config.get("own_active_uid", "")),
		str(config.get("own_active_effect_id", "")),
		int(config.get("own_active_remaining_hp", -1)),
		int(config.get("own_active_prize_count", -1)),
		config.get("own_active_energy_symbols", [])
	):
		return false
	var own_bench: Dictionary = state.get("own_bench", {}) \
		if state.get("own_bench", {}) is Dictionary else {}
	if own_bench.size() != 1 or not (own_bench.values()[0] is Dictionary):
		return false
	var root_slot: Dictionary = own_bench.values()[0] as Dictionary
	if not _public_slot_uid_shape_matches(
		root_slot,
		str(config.get("evolution_root_uid", "")),
		str(config.get("evolution_root_effect_id", "")),
		int(config.get("evolution_root_remaining_hp", -1)),
		int(config.get("evolution_root_prize_count", -1)),
		config.get("evolution_root_energy_symbols", [])
	):
		return false
	var opponent_bench: Dictionary = state.get("opponent_bench", {}) \
		if state.get("opponent_bench", {}) is Dictionary else {}
	if not opponent_bench.is_empty():
		return false
	var opponent_active: Dictionary = state.get("opponent_active", {}) \
		if state.get("opponent_active", {}) is Dictionary else {}
	if not _public_slot_uid_shape_matches(
		opponent_active,
		str(config.get("opponent_active_uid", "")),
		str(config.get("opponent_active_effect_id", "")),
		int(config.get("opponent_active_remaining_hp", -1)),
		int(config.get("opponent_active_prize_count", -1)),
		config.get("opponent_active_energy_symbols", [])
	):
		return false
	return int(config.get("opponent_attack_cost", 0)) \
		- int(opponent_active.get("energy_count", 0)) \
		== int(config.get("opponent_attack_energy_deficit", -1))


func _public_cards_match_exact_uid_effect_multiset(
	cards: Array[Dictionary],
	configured_value: Variant
) -> bool:
	if not (configured_value is Array):
		return false
	var expected: Dictionary = {}
	var expected_total := 0
	for raw_spec: Variant in configured_value as Array:
		if not (raw_spec is Dictionary):
			return false
		var spec: Dictionary = raw_spec
		var uid := str(spec.get("uid", "")).strip_edges().to_upper()
		var effect_id := str(spec.get("effect_id", "")).strip_edges().to_lower()
		if uid == "" or effect_id == "" or int(spec.get("count", 0)) <= 0:
			return false
		expected["%s:%s" % [uid, effect_id]] = int(spec.get("count", 0))
		expected_total += int(spec.get("count", 0))
	if cards.size() != expected_total:
		return false
	var observed: Dictionary = {}
	for card: Dictionary in cards:
		var uid := str(card.get("uid", "")).strip_edges().to_upper()
		var effect_id := str(card.get("effect_id", "")).strip_edges().to_lower()
		var matched_key := ""
		for key: Variant in expected.keys():
			var key_text := str(key)
			if key_text.begins_with("%s:" % uid) \
					and (effect_id == "" or key_text == "%s:%s" % [uid, effect_id]):
				matched_key = key_text
				break
		if matched_key == "":
			return false
		observed[matched_key] = int(observed.get(matched_key, 0)) + 1
	return observed == expected


func _public_slot_uid_shape_matches(
	slot: Dictionary,
	uid: String,
	effect_id: String,
	remaining_hp: int,
	prize_count: int,
	energy_symbols: Variant
) -> bool:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return str(slot.get("slot_id", "")) != "" \
		and _public_card_identity_matches_without_instance(pokemon, uid, effect_id) \
		and int(slot.get("remaining_hp", -1)) == remaining_hp \
		and int(slot.get("prize_count", -1)) == prize_count \
		and energy_symbols is Array \
		and slot.get("energy_symbols", []) == energy_symbols \
		and int(slot.get("energy_count", -1)) == (energy_symbols as Array).size()


func _public_card_identity_matches_without_instance(
	card: Dictionary,
	uid: String,
	effect_id: String
) -> bool:
	if str(card.get("uid", "")).strip_edges().to_upper() != uid.strip_edges().to_upper():
		return false
	var observed_effect := str(card.get("effect_id", "")).strip_edges().to_lower()
	return observed_effect == "" or observed_effect == effect_id.strip_edges().to_lower()


func _visible_stage2_setup_binding_hash(annotation: Dictionary) -> String:
	var bound := annotation.duplicate(true)
	bound.erase("binding_hash")
	return JSON.stringify(bound).sha256_text()


func _visible_stage2_setup_binding_is_valid(annotation: Dictionary) -> bool:
	var observed := str(annotation.get("binding_hash", ""))
	return observed != "" and observed == _visible_stage2_setup_binding_hash(annotation)


func _attackless_second_gust_hold_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get("damage_counter_control", {}) \
		if annotations.get("damage_counter_control", {}) is Dictionary else {}
	return module_annotation.get("attackless_second_gust_hold", {}) \
		if module_annotation.get("attackless_second_gust_hold", {}) is Dictionary else {}


func _attackless_second_gust_hold_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> Dictionary:
	var all_local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var module_parameters: Dictionary = all_local_parameters.get("damage_counter_control", {}) \
		if all_local_parameters.get("damage_counter_control", {}) is Dictionary else {}
	var config: Dictionary = module_parameters.get("attackless_second_gust_hold", {}) \
		if module_parameters.get("attackless_second_gust_hold", {}) is Dictionary else {}
	if not _attackless_second_gust_config_matches(config, profile, state):
		return {}
	if bool(snapshot.get("attack_ready", false)) \
			or bool(snapshot.get("ko_available", false)) \
			or bool(snapshot.get("win_now", false)):
		return {}
	if not _attackless_second_gust_public_context_matches(state, config):
		return {}

	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var candidate_id := str(route.get("candidate_id", ""))
	var action_id := _attackless_second_gust_bound_action_id(route, candidate_id, config)
	# Observation versions are request-loop provenance, not semantic game state.
	# A real model wait can increase them without changing a single public card.
	# Bind each stage to the exact, already-audited action result instead.
	var stage := _attackless_second_gust_action_result_stage(state, config)
	var advances := false
	if stage == "retreat":
		advances = str(route.get("route_id", "")) == "route:pivot" \
			and str(route.get("action_kind", "")) == "retreat" \
			and str(route.get("checkpoint_after", "")) == "action_resolved" \
			and action_id == str(config.get("retreat_action_id", "")) \
			and candidate_id == str(config.get("retreat_candidate_id", "")) \
			and str(action_ref.get("target", "")) == str(config.get("retreat_target_slot_id", "")) \
			and int(action_ref.get("target_instance_id", config.get("retreat_target_instance_id", -1))) \
				== int(config.get("retreat_target_instance_id", -2)) \
			and int(action_ref.get("effective_cost", 0)) == 0 \
			and (action_ref.get("payment_instance_ids", []) as Array).is_empty() \
				if action_ref.get("payment_instance_ids", []) is Array else false
	elif stage == "end_after_retreat_reobserve":
		advances = str(route.get("route_id", "")) == "route:end_turn" \
			and str(route.get("action_kind", "")) == "end_turn" \
			and str(route.get("checkpoint_after", "")) == "terminal" \
			and action_id == str(config.get("end_action_id", "")) \
			and candidate_id == str(config.get("end_candidate_id", "")) \
			and str(state.get("event_kind", "")) == str(config.get("required_action_result_kind", "")) \
			and bool(state.get("event_success", false)) \
			and str(state.get("event_action_id", "")) == str(config.get("retreat_action_id", "")) \
			and str(state.get("event_action_kind", "")) == "retreat" \
			and str(state.get("event_route_id", "")) == "route:pivot" \
			and str(state.get("event_candidate_id", "")) == str(config.get("retreat_candidate_id", "")) \
			and not bool(state.get("retreat_available", true))

	var harmful_rule_floor := str(route.get("route_id", "")) == "route:gust" \
		and str(route.get("action_kind", "")) == "play_trainer" \
		and str(route.get("checkpoint_after", "")) == "action_resolved" \
		and bool(route.get("engine_rule_floor_exact", false)) \
		and action_id == str(config.get("rule_gust_action_id", "")) \
		and candidate_id == str(config.get("rule_gust_candidate_id", "")) \
		and _rule_gust_action_binding_matches(action_ref, config)
	var context_key := "%d:%s:%s:%s:%s:%d" % [
		int(state.get("deck_id", 0)),
		str(state.get("deck_content_fingerprint", "")),
		stage,
		str(config.get("opponent_active_slot_id", "")),
		str(config.get("released_attacker_slot_id", "")),
		int(config.get("second_counter_catcher_instance_id", -1)),
	]
	return {
		"advances_attackless_second_gust_hold": advances,
		"is_exact_harmful_second_gust_floor": harmful_rule_floor,
		"stage": stage,
		"context_key": context_key,
		"deck_id": int(state.get("deck_id", 0)),
		"deck_content_fingerprint": str(state.get("deck_content_fingerprint", "")),
		"selected_action_id": action_id,
		"selected_candidate_id": candidate_id,
		"rule_gust_action_id": str(config.get("rule_gust_action_id", "")),
		"rule_gust_candidate_id": str(config.get("rule_gust_candidate_id", "")),
		"held_card_instance_id": int(config.get("second_counter_catcher_instance_id", -1)),
		"released_attacker_slot_id": str(config.get("released_attacker_slot_id", "")),
		"observation_version_provenance": int(state.get("observation_version", -1)),
		"checkpoint_after": "action_resolved" if stage == "retreat" else "terminal",
	}


func _attackless_second_gust_config_matches(
	config: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> bool:
	if int(config.get("schema_version", 0)) != 1 \
			or int(config.get("deck_id", 0)) != int(profile.get("deck_id", -1)) \
			or int(config.get("deck_id", 0)) != int(state.get("deck_id", -2)) \
			or str(config.get("deck_content_fingerprint", "")) == "" \
			or str(config.get("deck_content_fingerprint", "")) != str(state.get("deck_content_fingerprint", "")):
		return false
	for key: String in [
		"counter_catcher_uid", "counter_catcher_effect_id", "first_gust_action_id",
		"first_gust_candidate_id", "rule_gust_action_id",
		"rule_gust_candidate_id", "rule_gust_target_slot_id", "interaction_step_id",
		"own_active_uid", "own_active_effect_id", "own_active_slot_id",
		"own_active_energy_uid", "own_active_energy_effect_id", "own_active_tool_uid",
		"own_active_tool_effect_id", "retreat_target_uid", "retreat_target_effect_id",
		"retreat_target_slot_id", "retreat_action_id", "retreat_candidate_id",
		"opponent_active_uid", "opponent_active_effect_id", "opponent_active_slot_id",
		"released_attacker_uid", "released_attacker_effect_id", "released_attacker_slot_id",
		"end_action_id", "end_candidate_id", "required_action_result_kind",
	]:
		if str(config.get(key, "")).strip_edges() == "":
			return false
	for key: String in [
		"first_counter_catcher_instance_id", "second_counter_catcher_instance_id",
		"rule_gust_target_instance_id", "own_active_instance_id",
		"retreat_target_instance_id", "opponent_active_instance_id",
		"released_attacker_instance_id",
	]:
		if int(config.get(key, -1)) < 0:
			return false
	return config.get("opponent_active_attack_costs", []) is Array \
		and not (config.get("opponent_active_attack_costs", []) as Array).is_empty() \
		and config.get("opponent_active_energy_symbols", []) is Array \
		and config.get("released_attacker_attack_costs", []) is Array \
		and not (config.get("released_attacker_attack_costs", []) as Array).is_empty() \
		and config.get("released_attacker_energy_symbols", []) is Array


func _attackless_second_gust_action_result_stage(
	state: Dictionary,
	config: Dictionary
) -> String:
	if str(state.get("event_kind", "")) != str(config.get("required_action_result_kind", "")) \
			or not bool(state.get("event_success", false)):
		return ""
	var action_id := str(state.get("event_action_id", ""))
	var action_kind := str(state.get("event_action_kind", ""))
	var route_id := str(state.get("event_route_id", ""))
	var candidate_id := str(state.get("event_candidate_id", ""))
	if action_id == str(config.get("first_gust_action_id", "")) \
			and action_kind == "play_trainer" \
			and route_id == "route:gust" \
			and candidate_id == str(config.get("first_gust_candidate_id", "")):
		return "retreat"
	if action_id == str(config.get("retreat_action_id", "")) \
			and action_kind == "retreat" \
			and route_id == "route:pivot" \
			and candidate_id == str(config.get("retreat_candidate_id", "")):
		return "end_after_retreat_reobserve"
	return ""


func _attackless_second_gust_public_context_matches(
	state: Dictionary,
	config: Dictionary
) -> bool:
	if int(state.get("turn_number", -1)) != int(config.get("turn_number", -2)) \
			or int(state.get("current_player", -1)) != 0 \
			or int(state.get("viewer", -1)) != 0 \
			or int(state.get("own_prizes_remaining", 0)) <= int(state.get("opponent_prizes_remaining", 0)):
		return false
	var stage := _attackless_second_gust_action_result_stage(state, config)
	var root_stage := stage == "retreat"
	var post_stage := stage == "end_after_retreat_reobserve"
	if not root_stage and not post_stage:
		return false
	var hand: Array[Dictionary] = state.get("hand", []) \
		if state.get("hand", []) is Array else []
	var discard: Array[Dictionary] = state.get("discard", []) \
		if state.get("discard", []) is Array else []
	if not _public_zone_has_exact_or_compact_card(
		hand,
		{},
		str(config.get("counter_catcher_uid", "")),
		str(config.get("counter_catcher_effect_id", "")),
		int(config.get("second_counter_catcher_instance_id", -1)),
		1
	):
		return false
	if not _public_zone_has_exact_or_compact_card(
		discard,
		state.get("discard_counts", {}) if state.get("discard_counts", {}) is Dictionary else {},
		str(config.get("counter_catcher_uid", "")),
		str(config.get("counter_catcher_effect_id", "")),
		int(config.get("first_counter_catcher_instance_id", -1)),
		1
	):
		return false

	var own_active: Dictionary = state.get("own_active", {}) \
		if state.get("own_active", {}) is Dictionary else {}
	var own_bench: Dictionary = state.get("own_bench", {}) \
		if state.get("own_bench", {}) is Dictionary else {}
	var expected_active_uid := str(config.get("own_active_uid", "")) if root_stage \
		else str(config.get("retreat_target_uid", ""))
	var expected_active_effect := str(config.get("own_active_effect_id", "")) if root_stage \
		else str(config.get("retreat_target_effect_id", ""))
	var expected_active_slot := str(config.get("own_active_slot_id", "")) if root_stage \
		else str(config.get("retreat_target_slot_id", ""))
	var expected_active_instance := int(config.get("own_active_instance_id", -1)) if root_stage \
		else int(config.get("retreat_target_instance_id", -1))
	if not _public_slot_binding_matches(
		own_active, expected_active_uid, expected_active_effect,
		expected_active_slot, expected_active_instance
	):
		return false
	var mover_slot: Dictionary = own_active if root_stage else (
		own_bench.get(str(config.get("own_active_slot_id", "")), {}) \
			if own_bench.get(str(config.get("own_active_slot_id", "")), {}) is Dictionary else {}
	)
	if not _public_slot_binding_matches(
		mover_slot,
		str(config.get("own_active_uid", "")),
		str(config.get("own_active_effect_id", "")),
		str(config.get("own_active_slot_id", "")),
		int(config.get("own_active_instance_id", -1))
	) \
			or not _public_slot_has_bound_card_or_omitted(
				mover_slot,
				"tool",
				str(config.get("own_active_tool_uid", "")),
				str(config.get("own_active_tool_effect_id", ""))
			) \
			or not _public_slot_has_exact_energy(
				mover_slot,
				str(config.get("own_active_energy_uid", "")),
				str(config.get("own_active_energy_effect_id", ""))
			):
		return false
	if root_stage:
		var retreat_target: Dictionary = own_bench.get(str(config.get("retreat_target_slot_id", "")), {}) \
			if own_bench.get(str(config.get("retreat_target_slot_id", "")), {}) is Dictionary else {}
		var observed_mover_retreat_cost := int(mover_slot.get("effective_retreat_cost", -1))
		if not bool(state.get("retreat_available", false)) \
				or (observed_mover_retreat_cost >= 0 and observed_mover_retreat_cost != 0) \
				or not _public_slot_binding_matches(
					retreat_target,
					str(config.get("retreat_target_uid", "")),
					str(config.get("retreat_target_effect_id", "")),
					str(config.get("retreat_target_slot_id", "")),
					int(config.get("retreat_target_instance_id", -1))
				):
			return false
	else:
		if bool(state.get("retreat_available", true)) \
				or str(state.get("event_kind", "")) != str(config.get("required_action_result_kind", "")) \
				or not bool(state.get("event_success", false)) \
				or str(state.get("event_action_id", "")) != str(config.get("retreat_action_id", "")) \
				or str(state.get("event_action_kind", "")) != "retreat" \
				or str(state.get("event_route_id", "")) != "route:pivot" \
				or str(state.get("event_candidate_id", "")) != str(config.get("retreat_candidate_id", "")):
			return false

	var opponent_active: Dictionary = state.get("opponent_active", {}) \
		if state.get("opponent_active", {}) is Dictionary else {}
	var opponent_bench: Dictionary = state.get("opponent_bench", {}) \
		if state.get("opponent_bench", {}) is Dictionary else {}
	var released: Dictionary = opponent_bench.get(str(config.get("released_attacker_slot_id", "")), {}) \
		if opponent_bench.get(str(config.get("released_attacker_slot_id", "")), {}) is Dictionary else {}
	var observed_active_retreat_cost := int(opponent_active.get("effective_retreat_cost", -1))
	var active_retreat_cost := observed_active_retreat_cost if observed_active_retreat_cost >= 0 \
		else int(config.get("opponent_active_printed_retreat_cost", -1))
	var observed_printed_retreat_cost := int(opponent_active.get("printed_retreat_cost", -1))
	var printed_retreat_cost := observed_printed_retreat_cost if observed_printed_retreat_cost >= 0 \
		else int(config.get("opponent_active_printed_retreat_cost", -1))
	return _public_slot_binding_matches(
		opponent_active,
		str(config.get("opponent_active_uid", "")),
		str(config.get("opponent_active_effect_id", "")),
		str(config.get("opponent_active_slot_id", "")),
		int(config.get("opponent_active_instance_id", -1))
	) \
		and printed_retreat_cost == int(config.get("opponent_active_printed_retreat_cost", -2)) \
		and _public_attack_costs_match_or_bound(
			opponent_active.get("attack_costs", []),
			config.get("opponent_active_attack_costs", [])
		) \
		and _public_energy_symbols_match(
			opponent_active.get("energy_symbols", []),
			config.get("opponent_active_energy_symbols", [])
		) \
		and not _public_costs_payable(
			config.get("opponent_active_attack_costs", []),
			config.get("opponent_active_energy_symbols", [])
		) \
		and active_retreat_cost > (opponent_active.get("energy_symbols", []) as Array).size() \
		and _public_slot_binding_matches(
			released,
			str(config.get("released_attacker_uid", "")),
			str(config.get("released_attacker_effect_id", "")),
			str(config.get("released_attacker_slot_id", "")),
			int(config.get("released_attacker_instance_id", -1))
		) \
		and _public_attack_costs_match_or_bound(
			released.get("attack_costs", []),
			config.get("released_attacker_attack_costs", [])
		) \
		and _public_energy_symbols_match(
			released.get("energy_symbols", []),
			config.get("released_attacker_energy_symbols", [])
		) \
		and _public_costs_payable(
			config.get("released_attacker_attack_costs", []),
			config.get("released_attacker_energy_symbols", [])
		)


func _rule_gust_action_binding_matches(action_ref: Dictionary, config: Dictionary) -> bool:
	var card: Dictionary = action_ref.get("card", {}) \
		if action_ref.get("card", {}) is Dictionary else {}
	if not _public_card_binding_matches(
		card,
		str(config.get("counter_catcher_uid", "")),
		str(config.get("counter_catcher_effect_id", "")),
		int(config.get("second_counter_catcher_instance_id", -1)),
		true
	):
		return false
	if action_ref.has("card_instance_id") \
			and int(action_ref.get("card_instance_id", -1)) != int(config.get("second_counter_catcher_instance_id", -2)):
		return false
	if action_ref.has("rule_selected_target_slot_id") \
			and str(action_ref.get("rule_selected_target_slot_id", "")) != str(config.get("rule_gust_target_slot_id", "")):
		return false
	if action_ref.has("rule_selected_target_instance_id") \
			and int(action_ref.get("rule_selected_target_instance_id", -1)) != int(config.get("rule_gust_target_instance_id", -2)):
		return false
	var steps: Variant = action_ref.get("interaction_steps", [])
	if steps is Array and not (steps as Array).is_empty():
		if (steps as Array).size() != 1 or not ((steps as Array)[0] is Dictionary):
			return false
		var step: Dictionary = (steps as Array)[0]
		if str(step.get("id", "")) != str(config.get("interaction_step_id", "")) \
				or int(step.get("min_select", -1)) != 1 \
				or int(step.get("max_select", -1)) != 1:
			return false
	return true


func _attackless_second_gust_bound_action_id(
	route: Dictionary,
	candidate_id: String,
	config: Dictionary
) -> String:
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var observed := str(route.get("safe_prefix_action_id", action_ref.get("id", "")))
	if observed != "":
		return observed
	if candidate_id == str(config.get("rule_gust_candidate_id", "")):
		return str(config.get("rule_gust_action_id", ""))
	if candidate_id == str(config.get("retreat_candidate_id", "")):
		return str(config.get("retreat_action_id", ""))
	if candidate_id == str(config.get("end_candidate_id", "")):
		return str(config.get("end_action_id", ""))
	return ""


func _public_zone_has_exact_or_compact_card(
	cards: Array[Dictionary],
	compact_counts: Dictionary,
	uid: String,
	effect_id: String,
	instance_id: int,
	required_count: int
) -> bool:
	var exact_count := 0
	var uid_count := 0
	var metadata_mismatch := false
	for card: Dictionary in cards:
		if str(card.get("uid", "")).to_upper() != uid.to_upper():
			continue
		uid_count += 1
		var observed_effect := str(card.get("effect_id", ""))
		var observed_instance := int(card.get("instance_id", -1))
		if (observed_effect != "" and observed_effect.to_lower() != effect_id.to_lower()) \
				or (observed_instance >= 0 and observed_instance != instance_id):
			metadata_mismatch = true
		elif _public_card_binding_matches(card, uid, effect_id, instance_id, true):
			exact_count += 1
	if not cards.is_empty():
		return not metadata_mismatch and uid_count == required_count and exact_count == required_count
	return int(compact_counts.get(uid, compact_counts.get(uid.to_upper(), 0))) == required_count


func _public_slot_binding_matches(
	slot: Dictionary,
	uid: String,
	effect_id: String,
	slot_id: String,
	instance_id: int
) -> bool:
	return str(slot.get("slot_id", "")) == slot_id \
		and int(slot.get("slot_instance_id", -1)) == instance_id \
		and _public_card_binding_matches(
			slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {},
			uid,
			effect_id,
			instance_id,
			true
		)


func _public_slot_has_bound_card_or_omitted(
	slot: Dictionary,
	key: String,
	uid: String,
	effect_id: String
) -> bool:
	var card: Dictionary = slot.get(key, {}) if slot.get(key, {}) is Dictionary else {}
	if card.is_empty():
		return true
	return _public_card_binding_matches(card, uid, effect_id, int(card.get("instance_id", -1)), true)


func _public_slot_has_exact_energy(slot: Dictionary, uid: String, effect_id: String) -> bool:
	var matches := 0
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary \
				and _public_card_binding_matches(raw_energy as Dictionary, uid, effect_id, int((raw_energy as Dictionary).get("instance_id", -1)), true):
			matches += 1
	return matches == 1


func _public_card_binding_matches(
	card: Dictionary,
	uid: String,
	effect_id: String,
	instance_id: int,
	allow_missing_runtime_metadata: bool
) -> bool:
	if str(card.get("uid", "")).to_upper() != uid.to_upper():
		return false
	var observed_effect := str(card.get("effect_id", "")).to_lower()
	if observed_effect != "" and observed_effect != effect_id.to_lower():
		return false
	var observed_instance := int(card.get("instance_id", -1))
	if observed_instance >= 0 and observed_instance != instance_id:
		return false
	return allow_missing_runtime_metadata or (observed_effect != "" and observed_instance >= 0)


func _public_attack_costs_match_or_bound(observed: Variant, configured: Variant) -> bool:
	if not (configured is Array) or (configured as Array).is_empty():
		return false
	if not (observed is Array) or (observed as Array).is_empty():
		return true
	return observed == configured


func _public_energy_symbols_match(observed: Variant, configured: Variant) -> bool:
	return observed is Array and configured is Array and observed == configured


func _public_costs_payable(costs_value: Variant, energy_value: Variant) -> bool:
	if not (costs_value is Array) or not (energy_value is Array):
		return false
	var energy: Array[String] = []
	for raw_symbol: Variant in energy_value as Array:
		energy.append(str(raw_symbol))
	for raw_cost: Variant in costs_value as Array:
		var remaining := energy.duplicate()
		var colorless := 0
		var payable := true
		for symbol: String in str(raw_cost):
			if symbol == "C":
				colorless += 1
				continue
			var index := remaining.find(symbol)
			if index < 0:
				payable = false
				break
			remaining.remove_at(index)
		if payable and remaining.size() >= colorless:
			return true
	return false


func _typed_attachment_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("typed_attachment", {}) \
		if own_annotation.get("typed_attachment", {}) is Dictionary else {}


func _counter_mover_closeout_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("counter_mover_closeout", {}) \
		if own_annotation.get("counter_mover_closeout", {}) is Dictionary else {}


func _counter_mover_before_secured_ko_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("counter_mover_before_secured_ko", {}) \
		if own_annotation.get("counter_mover_before_secured_ko", {}) is Dictionary else {}


func _deterministic_attack_dominance_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("deterministic_attack_dominance", {}) \
		if own_annotation.get("deterministic_attack_dominance", {}) is Dictionary else {}


func _counter_engine_setup_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("counter_engine_setup", {}) \
		if own_annotation.get("counter_engine_setup", {}) is Dictionary else {}


func _profiled_hand_reset_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_hand_reset", {}) \
		if own_annotation.get("profiled_hand_reset", {}) is Dictionary else {}


func _profiled_stage2_search_before_pivot_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_stage2_search_before_pivot", {}) \
		if own_annotation.get("profiled_stage2_search_before_pivot", {}) is Dictionary else {}


func _profiled_stage2_search_before_pivot_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "stage2_chain" \
			or str(route.get("action_kind", "")) != "play_trainer" \
			or str(route.get("route_id", "")) != "route:information" \
			or str(route.get("checkpoint_after", "")) != "information_result":
		return {}
	var parameters := _module_parameters(profile)
	var config: Dictionary = parameters.get("profiled_search_before_pivot", {}) \
		if parameters.get("profiled_search_before_pivot", {}) is Dictionary else {}
	if not bool(config.get("enabled", false)) \
			or int(config.get("owner_deck_id", 0)) != int(profile.get("deck_id", 0)) \
			or int(profile.get("deck_id", 0)) <= 0 \
			or str(config.get("certificate_kind", "")) != "profiled_stage2_search_before_pivot":
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var action_card: Dictionary = action_ref.get("card", {}) \
		if action_ref.get("card", {}) is Dictionary else {}
	var search_uid := str(config.get("search_uid", "")).strip_edges().to_upper()
	if search_uid == "" or str(action_card.get("uid", "")).strip_edges().to_upper() != search_uid:
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active_state: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var active_symbols: Array = active_energy.get("attached_symbols", []) \
		if active_energy.get("attached_symbols", []) is Array else []
	var active_uid := str(config.get("active_uid", "")).strip_edges().to_upper()
	var root_uid := str(config.get("evolution_root_uid", "")).strip_edges().to_upper()
	var attacker_uid := str(config.get("attacker_hand_uid", "")).strip_edges().to_upper()
	var deferred_uid := str(config.get("deferred_pivot_target_uid", "")).strip_edges().to_upper()
	if active_uid == "" or root_uid == "" or attacker_uid == "" or deferred_uid == "":
		return {}
	var visible_uid_counts: Dictionary = {}
	var root_energy_exact := false
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		var uid := str(state.get("pokemon_uid", "")).strip_edges().to_upper()
		if uid != "":
			visible_uid_counts[uid] = int(visible_uid_counts.get(uid, 0)) + 1
		if uid == root_uid:
			var slot_energy: Dictionary = energy_states.get(slot_id, {}) \
				if energy_states.get(slot_id, {}) is Dictionary else {}
			var symbols: Array = slot_energy.get("attached_symbols", []) \
				if slot_energy.get("attached_symbols", []) is Array else []
			root_energy_exact = _same_symbol_multiset(symbols, config.get("root_energy_exact", []))
	var required_visible: Dictionary = config.get("required_visible_uid_counts", {}) \
		if config.get("required_visible_uid_counts", {}) is Dictionary else {}
	var visible_exact := not required_visible.is_empty() and visible_uid_counts.size() == required_visible.size()
	for raw_uid: Variant in required_visible.keys():
		var uid := str(raw_uid).strip_edges().to_upper()
		if int(visible_uid_counts.get(uid, 0)) != int(required_visible.get(raw_uid, 0)):
			visible_exact = false
			break
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var discard_uid_counts: Dictionary = snapshot.get("discard_uid_counts", {}) \
		if snapshot.get("discard_uid_counts", {}) is Dictionary else {}
	var discard_ready := true
	var required_discard: Dictionary = config.get("minimum_discard_uid_counts", {}) \
		if config.get("minimum_discard_uid_counts", {}) is Dictionary else {}
	for raw_uid: Variant in required_discard.keys():
		if int(discard_uid_counts.get(str(raw_uid).strip_edges().to_upper(), 0)) < int(required_discard.get(raw_uid, 0)):
			discard_ready = false
			break
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_card: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var guards := {
		"active_uid_exact": str(active_state.get("pokemon_uid", "")).strip_edges().to_upper() == active_uid,
		"active_energy_exact": _same_symbol_multiset(active_symbols, config.get("active_energy_exact", [])),
		"root_energy_exact": root_energy_exact,
		"visible_board_exact": visible_exact,
		"search_in_hand_exact": int(hand_uid_counts.get(search_uid, 0)) == 1,
		"attacker_in_hand_exact": int(hand_uid_counts.get(attacker_uid, 0)) == 1,
		"hand_count_exact": int(snapshot.get("own_hand_count", -1)) == int(config.get("own_hand_count", -2)),
		"bench_space_exact": int(snapshot.get("bench_slots_free", -1)) == int(config.get("bench_slots_free", -2)),
		"own_prizes_exact": int(snapshot.get("own_prizes_remaining", 0)) == int(config.get("own_prizes_remaining", -1)),
		"opponent_prizes_exact": int(snapshot.get("opponent_prizes_remaining", 0)) == int(config.get("opponent_prizes_remaining", -1)),
		"opponent_uid_exact": str(opponent_card.get("uid", "")).strip_edges().to_upper() \
			== str(config.get("opponent_active_uid", "")).strip_edges().to_upper(),
		"opponent_hp_exact": int(opponent_active.get("remaining_hp", 0)) == int(config.get("opponent_active_remaining_hp", -1)),
		"opponent_prizes_value_exact": int(opponent_active.get("prize_count", 0)) == int(config.get("opponent_active_prize_count", -1)),
		"discard_fuel_ready": discard_ready,
		"attack_window_open": bool(snapshot.get("deterministic_attack_window_open", false)),
		"active_attackless": not bool(snapshot.get("attack_ready", false)),
		"no_current_ko": not bool(snapshot.get("ko_available", false)),
	}
	var advances := true
	for value: Variant in guards.values():
		if not bool(value):
			advances = false
			break
	return {
		"advances_profiled_stage2_search_before_pivot": advances,
		"search_uid": search_uid,
		"active_uid": active_uid,
		"deferred_pivot_target_uid": deferred_uid,
		"guards": guards,
		"public_snapshot": snapshot.duplicate(true),
	}


func _same_symbol_multiset(left: Array, right_raw: Variant) -> bool:
	if not (right_raw is Array) or left.size() != (right_raw as Array).size():
		return false
	var left_symbols: Array[String] = []
	var right_symbols: Array[String] = []
	for symbol: Variant in left:
		left_symbols.append(str(symbol).strip_edges().to_upper())
	for symbol: Variant in right_raw:
		right_symbols.append(str(symbol).strip_edges().to_upper())
	left_symbols.sort()
	right_symbols.sort()
	return left_symbols == right_symbols


func _profiled_counter_activation_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_counter_activation", {}) \
		if own_annotation.get("profiled_counter_activation", {}) is Dictionary else {}


func _profiled_attacker_setup_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_attacker_setup", {}) \
		if own_annotation.get("profiled_attacker_setup", {}) is Dictionary else {}


func _profiled_engine_search_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_engine_search", {}) \
		if own_annotation.get("profiled_engine_search", {}) is Dictionary else {}


func _profiled_active_gardevoir_ko_suffix_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get("gardevoir_embrace", {}) \
		if annotations.get("gardevoir_embrace", {}) is Dictionary else {}
	return own_annotation.get("profiled_active_gardevoir_ko_suffix", {}) \
		if own_annotation.get("profiled_active_gardevoir_ko_suffix", {}) is Dictionary else {}


func _dragon_weakness_field_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get("gardevoir_embrace", {}) \
		if annotations.get("gardevoir_embrace", {}) is Dictionary else {}
	return own_annotation.get("dragon_weakness_field", {}) \
		if own_annotation.get("dragon_weakness_field", {}) is Dictionary else {}


func _active_gardevoir_completion_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get("gardevoir_embrace", {}) \
		if annotations.get("gardevoir_embrace", {}) is Dictionary else {}
	return own_annotation.get("active_gardevoir_completion", {}) \
		if own_annotation.get("active_gardevoir_completion", {}) is Dictionary else {}


func _active_gardevoir_completion_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" \
			or str(route.get("action_kind", "")) != "use_ability":
		return {}
	var parameters := _module_parameters(profile)
	var config: Dictionary = parameters.get("active_gardevoir_public_ko", {}) \
		if parameters.get("active_gardevoir_public_ko", {}) is Dictionary else {}
	var attacker_uid := str(config.get("attacker_uid", "")).strip_edges().to_upper()
	var attack_cost: Array[String] = []
	for raw_symbol: Variant in config.get("attack_cost", []):
		attack_cost.append(EnergySymbolsScript.canonical(raw_symbol))
	var attack_damage := maxi(0, int(config.get("attack_damage", 0)))
	var damage_per_assignment := maxi(0, int(config.get("damage_per_assignment", 20)))
	if attacker_uid == "" or attack_cost.is_empty() or attack_damage <= 0 \
			or damage_per_assignment <= 0:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	var source_uid := str(source_card.get("uid", "")).strip_edges().to_upper()
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var energies: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energies.get(active_slot_id, {}) \
		if energies.get(active_slot_id, {}) is Dictionary else {}
	var attached_symbols: Array[String] = []
	for raw_symbol: Variant in active_energy.get("attached_symbols", []):
		attached_symbols.append(EnergySymbolsScript.canonical(raw_symbol))
	var assignments_needed := _psychic_assignments_to_pay_cost(
		attached_symbols,
		attack_cost
	)
	var psychic_discard := maxi(0, int(snapshot.get("psychic_energy_in_discard", 0)))
	var remaining_hp := maxi(0, int(active.get("remaining_hp", 0)))
	var safe_assignments := maxi(
		0,
		int(floor(float(remaining_hp - 1) / float(damage_per_assignment)))
	)
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_remaining_hp := maxi(0, int(opponent_active.get("remaining_hp", 0)))
	var advances := source_uid == attacker_uid \
		and str(active.get("pokemon_uid", "")).strip_edges().to_upper() == attacker_uid \
		and assignments_needed > 0 \
		and psychic_discard >= assignments_needed \
		and safe_assignments >= assignments_needed \
		and opponent_remaining_hp > 0 \
		and opponent_remaining_hp <= attack_damage \
		and bool(snapshot.get("deterministic_attack_window_open", false)) \
		and not bool(snapshot.get("attack_ready", false))
	return {
		"attacker_uid": attacker_uid,
		"active_slot_id": active_slot_id,
		"attack_cost": attack_cost,
		"attack_damage": attack_damage,
		"attached_symbols": attached_symbols,
		"assignments_needed": assignments_needed,
		"psychic_energy_in_discard": psychic_discard,
		"safe_assignments": safe_assignments,
		"opponent_remaining_hp": opponent_remaining_hp,
		"advances_active_gardevoir_ko_completion": advances,
	}


func _psychic_assignments_to_pay_cost(
	attached_symbols: Array[String],
	attack_cost: Array[String]
) -> int:
	var available := attached_symbols.duplicate()
	var specific_missing := 0
	var colorless_required := 0
	for required: String in attack_cost:
		if required == "C":
			colorless_required += 1
			continue
		var match_index := available.find(required)
		if match_index >= 0:
			available.remove_at(match_index)
		elif required == "P":
			specific_missing += 1
		else:
			return 999
	var psychic_after_specific := specific_missing
	var leftover_after_specific := maxi(0, available.size())
	var colorless_missing := maxi(0, colorless_required - leftover_after_specific)
	return psychic_after_specific + colorless_missing


func _dragon_weakness_field_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" \
			or str(route.get("action_kind", "")) != "play_basic_to_bench":
		return {}
	var parameters := _module_parameters(profile)
	var config: Dictionary = parameters.get("dragon_weakness_field", {}) \
		if parameters.get("dragon_weakness_field", {}) is Dictionary else {}
	var field_uid := str(config.get("field_uid", "")).strip_edges().to_upper()
	var weakness_multiplier := maxi(1, int(config.get("weakness_multiplier", 2)))
	var attacker_uids := _uid_counts(config.get("attacker_uids", []))
	var target_uids := _uid_counts(config.get("dragon_target_uids", []))
	if field_uid == "" or attacker_uids.is_empty() or target_uids.is_empty() \
			or weakness_multiplier <= 1:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) \
		if action_ref.get("card", {}) is Dictionary else {}
	var action_uid := str(card.get("uid", "")).strip_edges().to_upper()
	var own_states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var own_active: Dictionary = own_states.get(str(snapshot.get("own_active_slot_id", "")), {}) \
		if own_states.get(str(snapshot.get("own_active_slot_id", "")), {}) is Dictionary else {}
	var attacker_uid := str(own_active.get("pokemon_uid", "")).strip_edges().to_upper()
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var opponent_uid := str(opponent_pokemon.get("uid", "")).strip_edges().to_upper()
	var base_damage := maxi(0, int(snapshot.get("attack_max_damage", 0)))
	var weakness_damage := base_damage * weakness_multiplier
	var opponent_remaining_hp := maxi(0, int(opponent_active.get("remaining_hp", 0)))
	var exact_breakpoint := base_damage > 0 \
		and opponent_remaining_hp > base_damage \
		and opponent_remaining_hp <= weakness_damage
	var advances := action_uid == field_uid \
		and int(snapshot.get("bench_slots_free", 0)) > 0 \
		and attacker_uids.has(attacker_uid) \
		and target_uids.has(opponent_uid) \
		and bool(snapshot.get("attack_ready", false)) \
		and not bool(snapshot.get("ko_available", false)) \
		and exact_breakpoint
	return {
		"field_uid": field_uid,
		"attacker_uid": attacker_uid,
		"opponent_uid": opponent_uid,
		"base_damage": base_damage,
		"weakness_multiplier": weakness_multiplier,
		"weakness_damage": weakness_damage,
		"opponent_remaining_hp": opponent_remaining_hp,
		"context_key": "%s|%s|%s|%d|%d" % [
			field_uid,
			attacker_uid,
			opponent_uid,
			base_damage,
			opponent_remaining_hp,
		],
		"advances_immediate_dragon_ko": advances,
	}


func _profiled_active_gardevoir_ko_suffix_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> Dictionary:
	var parameters := _module_parameters(profile)
	var config: Dictionary = parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {}) \
		if parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {}) is Dictionary else {}
	if not _profiled_active_gardevoir_ko_config_matches(config, profile, state):
		return {}
	var stage := _profiled_active_gardevoir_ko_stage(state, config)
	var context_matches := stage != "" and _profiled_active_gardevoir_ko_public_context_matches(
		state, snapshot, config, stage
	)
	if stage == "" or not context_matches:
		return {}
	var pair_role := _profiled_active_gardevoir_ko_pair_role(route, config, stage)
	if pair_role == "":
		return {}
	var context_key := "%d:%s:%s:%s:%s:%s" % [
		int(state.get("deck_id", 0)),
		str(state.get("deck_content_fingerprint", "")),
		str(config.get("root_observation_hash", "")),
		stage,
		str(config.get("active_slot_id", "")),
		str((config.get("opponent_active", {}) as Dictionary).get("slot_id", "")) \
		if config.get("opponent_active", {}) is Dictionary else "",
	]
	# This identity deliberately excludes the checkpoint stage.  The strategy
	# uses it to continue only the exact multi-observation suffix whose root was
	# certified; every candidate still has to independently re-prove its current
	# stage and public observation hash before execution ownership can advance.
	var continuation_key := "%d:%s:%s:%s:%s" % [
		int(state.get("deck_id", 0)),
		str(state.get("deck_content_fingerprint", "")),
		str(config.get("root_observation_hash", "")),
		str(config.get("active_slot_id", "")),
		str((config.get("opponent_active", {}) as Dictionary).get("slot_id", "")) \
			if config.get("opponent_active", {}) is Dictionary else "",
	]
	return {
		"advances_profiled_active_gardevoir_ko_suffix": pair_role == "preferred",
		"is_exact_rule_floor": pair_role == "dominated",
		"pair_role": pair_role,
		"stage": stage,
		"context_key": context_key,
		"continuation_key": continuation_key,
		"certificate_kind": str(config.get("certificate_kind", "")),
		"interaction_certificate_kind": str(config.get("interaction_certificate_kind", "")),
		"active_slot_id": str(config.get("active_slot_id", "")),
		"observation_hash_provenance": str(state.get("observation_hash", "")),
		"observation_version_provenance": int(state.get("observation_version", -1)),
	}


func _profiled_active_gardevoir_ko_config_matches(
	config: Dictionary,
	profile: Dictionary,
	state: Dictionary
) -> bool:
	if not bool(config.get("enabled", false)) \
			or int(config.get("schema_version", 0)) != 1 \
			or int(config.get("owner_deck_id", 0)) != int(profile.get("deck_id", -1)) \
			or int(config.get("owner_deck_id", 0)) != int(state.get("deck_id", -2)) \
			or str(config.get("deck_content_fingerprint", "")) == "" \
			or str(config.get("deck_content_fingerprint", "")) != str(state.get("deck_content_fingerprint", "")) \
			or str(config.get("manifest_hash", "")) == "" \
			or str(config.get("manifest_hash", "")) != str(state.get("manifest_hash", "")) \
			or str(config.get("certificate_kind", "")) != "profiled_visible_engine_hold" \
			or str(config.get("interaction_certificate_kind", "")) == "" \
			or str(config.get("root_observation_hash", "")) == "":
		return false
	for key: String in [
		"attach_active_action_id", "rule_attach_action_id", "embrace_action_id",
		"rule_munkidori_action_id", "attack_action_id", "active_uid",
		"active_effect_id", "active_slot_id", "psychic_uid", "psychic_effect_id",
		"ultra_ball_uid", "ultra_ball_effect_id", "required_action_result_kind",
		"prior_evolve_action_id", "prior_evolve_action_kind", "prior_evolve_route_id",
		"prior_evolve_candidate_id", "prior_evolve_target_slot_id",
	]:
		if str(config.get(key, "")).strip_edges() == "":
			return false
	for key: String in [
		"required_own_bench", "required_opponent_bench", "active_psychic_by_stage",
		"active_damage_by_stage", "active_remaining_hp_by_stage",
		"discard_psychic_by_stage", "attack_cost",
	]:
		if not (config.get(key, []) is Array) or (config.get(key, []) as Array).is_empty():
			return false
	return (config.get("required_own_bench", []) as Array).size() == 5 \
		and (config.get("required_opponent_bench", []) as Array).size() == 4 \
		and (config.get("active_psychic_by_stage", []) as Array).size() == 4 \
		and (config.get("active_damage_by_stage", []) as Array).size() == 4 \
		and (config.get("active_remaining_hp_by_stage", []) as Array).size() == 4 \
		and (config.get("discard_psychic_by_stage", []) as Array).size() == 4 \
		and config.get("opponent_active", {}) is Dictionary


func _profiled_active_gardevoir_ko_stage(state: Dictionary, config: Dictionary) -> String:
	var active: Dictionary = state.get("own_active", {}) \
		if state.get("own_active", {}) is Dictionary else {}
	var psychic_by_stage: Array = config.get("active_psychic_by_stage", [])
	var damage_by_stage: Array = config.get("active_damage_by_stage", [])
	var hp_by_stage: Array = config.get("active_remaining_hp_by_stage", [])
	var discard_by_stage: Array = config.get("discard_psychic_by_stage", [])
	var labels := [
		"manual_psychic_to_active",
		"first_embrace_to_active",
		"second_embrace_to_active",
		"active_gardevoir_190_ko",
	]
	for index: int in 4:
		if _count_string(active.get("energy_symbols", []), "P") != int(psychic_by_stage[index]) \
				or int(active.get("energy_count", -1)) != int(psychic_by_stage[index]) \
				or int(active.get("damage_points", -1)) != int(damage_by_stage[index]) \
				or int(active.get("remaining_hp", -1)) != int(hp_by_stage[index]) \
				or int((state.get("discard_counts", {}) as Dictionary).get(
					str(config.get("psychic_uid", "")), 0
				)) != int(discard_by_stage[index]) \
					if state.get("discard_counts", {}) is Dictionary else true:
			continue
		if index == 0:
			if str(state.get("observation_hash", "")) != str(config.get("root_observation_hash", "")) \
					or str(state.get("event_kind", "")) != str(config.get("required_action_result_kind", "")) \
					or not bool(state.get("event_success", false)) \
					or str(state.get("event_action_id", "")) != str(config.get("prior_evolve_action_id", "")) \
					or str(state.get("event_action_kind", "")) != str(config.get("prior_evolve_action_kind", "")) \
					or str(state.get("event_route_id", "")) != str(config.get("prior_evolve_route_id", "")) \
					or str(state.get("event_candidate_id", "")) != str(config.get("prior_evolve_candidate_id", "")) \
					or str(state.get("event_target_slot_id", "")) != str(config.get("prior_evolve_target_slot_id", "")):
				continue
		else:
			var expected_result_action := str(config.get(
				"attach_active_action_id" if index == 1 else "embrace_action_id", ""
			))
			if str(state.get("event_kind", "")) != str(config.get("required_action_result_kind", "")) \
					or not bool(state.get("event_success", false)) \
					or str(state.get("event_action_id", "")) != expected_result_action:
				continue
			var event_target := str(state.get("event_target_slot_id", ""))
			if event_target != "" and event_target != str(config.get("active_slot_id", "")):
				continue
		return labels[index]
	return ""


func _profiled_active_gardevoir_ko_public_context_matches(
	state: Dictionary,
	snapshot: Dictionary,
	config: Dictionary,
	stage: String
) -> bool:
	var stage_index := [
		"manual_psychic_to_active", "first_embrace_to_active",
		"second_embrace_to_active", "active_gardevoir_190_ko",
	].find(stage)
	if stage_index < 0 \
			or int(state.get("turn_number", -1)) != int(config.get("turn_number", -2)) \
			or int(state.get("current_player", -1)) != int(config.get("current_player", -2)) \
			or int(state.get("viewer", -1)) != int(config.get("viewer", -2)) \
			or int(state.get("phase", -1)) != int(config.get("phase", -2)) \
			or not bool(state.get("deterministic_attack_window_open", false)) \
			or bool(state.get("supporter_available", true)) \
			or bool(state.get("energy_available", false)) != (stage_index == 0) \
			or int(state.get("own_deck_count", -1)) != int(config.get("own_deck_count", -2)) \
			or int(state.get("opponent_deck_count", -1)) != int(config.get("opponent_deck_count", -2)) \
			or int(state.get("opponent_hand_count", -1)) != int(config.get("opponent_hand_count", -2)) \
			or int(state.get("own_prizes_remaining", -1)) != int(config.get("own_prizes_remaining", -2)) \
			or int(state.get("opponent_prizes_remaining", -1)) != int(config.get("opponent_prizes_remaining", -2)):
		return false
	var active: Dictionary = state.get("own_active", {}) \
		if state.get("own_active", {}) is Dictionary else {}
	if not _public_slot_binding_matches(
		active,
		str(config.get("active_uid", "")),
		str(config.get("active_effect_id", "")),
		str(config.get("active_slot_id", "")),
		int(config.get("active_instance_id", -1))
	) \
			or (int(active.get("max_hp", 0)) > 0 \
				and int(active.get("max_hp", 0)) != int(config.get("active_max_hp", -1))) \
			or int(active.get("prize_count", 0)) != int(config.get("active_prize_count", -1)) \
			or int(active.get("remaining_hp", 0)) <= 0:
		return false
	var special_conditions: Variant = active.get("special_conditions", [])
	if not (special_conditions is Array) or not (special_conditions as Array).is_empty():
		return false
	if not _profiled_active_gardevoir_attack_print_matches(active, config):
		return false
	if not _configured_public_slots_match(
		state.get("own_bench", {}) if state.get("own_bench", {}) is Dictionary else {},
		config.get("required_own_bench", [])
	) or not _configured_public_slots_match(
		state.get("opponent_bench", {}) if state.get("opponent_bench", {}) is Dictionary else {},
		config.get("required_opponent_bench", [])
	):
		return false
	var opponent_active: Dictionary = state.get("opponent_active", {}) \
		if state.get("opponent_active", {}) is Dictionary else {}
	if not _configured_public_slot_matches(
		opponent_active,
		config.get("opponent_active", {}) if config.get("opponent_active", {}) is Dictionary else {}
	):
		return false
	var opponent_tool: Variant = opponent_active.get("tool", {})
	if not (opponent_tool is Dictionary) or str((opponent_tool as Dictionary).get("uid", "")) != "":
		return false
	var reaction_effects: Variant = opponent_active.get("reaction_effects", [])
	if not (reaction_effects is Array) or not (reaction_effects as Array).is_empty():
		return false
	var opponent_effects: Array = opponent_active.get("public_effects", []) \
		if opponent_active.get("public_effects", []) is Array else []
	for raw_effect: Variant in opponent_effects:
		if str(raw_effect) in DAMAGE_REACTIVE_ACTIVE_EFFECT_IDS:
			return false
	var hand_counts := _uid_counts_from_public_cards(
		state.get("hand", []) if state.get("hand", []) is Array else []
	)
	var expected_hand: Dictionary = config.get(
		"root_hand_uid_counts" if stage_index == 0 else "post_attach_hand_uid_counts", {}
	) if config.get(
		"root_hand_uid_counts" if stage_index == 0 else "post_attach_hand_uid_counts", {}
	) is Dictionary else {}
	expected_hand = _normalized_uid_counts_from_dictionary(expected_hand)
	if hand_counts != expected_hand:
		return false
	if stage_index == 0:
		if not _public_zone_contains_exact_card_instance(
			state.get("hand", []) as Array[Dictionary],
			str(config.get("psychic_uid", "")), str(config.get("psychic_effect_id", "")),
			int(config.get("manual_psychic_instance_id", -1)),
			int(expected_hand.get(str(config.get("psychic_uid", "")).to_upper(), 0))
		) or not _public_zone_has_exact_or_compact_card(
			state.get("hand", []) as Array[Dictionary], {},
			str(config.get("ultra_ball_uid", "")), str(config.get("ultra_ball_effect_id", "")),
			int(config.get("ultra_ball_instance_id", -1)), 1
		):
			return false
	var expected_discard: Dictionary = config.get("discard_uid_counts_without_psychic", {}).duplicate(true) \
		if config.get("discard_uid_counts_without_psychic", {}) is Dictionary else {}
	expected_discard = _normalized_uid_counts_from_dictionary(expected_discard)
	expected_discard[str(config.get("psychic_uid", ""))] = int(
		(config.get("discard_psychic_by_stage", []) as Array)[stage_index]
	)
	var observed_discard: Dictionary = _normalized_uid_counts_from_dictionary(
		state.get("discard_counts", {}) if state.get("discard_counts", {}) is Dictionary else {}
	)
	if observed_discard != expected_discard:
		return false
	var visible_psychic := int(hand_counts.get(str(config.get("psychic_uid", "")), 0)) \
		+ int(expected_discard.get(str(config.get("psychic_uid", "")), 0)) \
		+ _public_board_symbol_count(state, "P")
	if visible_psychic != int(config.get("visible_psychic_total", -1)):
		return false
	return bool(snapshot.get("attack_ready", false)) == (stage_index == 3) \
		and bool(snapshot.get("ko_available", false)) == (stage_index == 3) \
		and int(snapshot.get("attack_max_damage", 0)) == (int(config.get("attack_damage", 0)) if stage_index == 3 else 0)


func _public_zone_contains_exact_card_instance(
	cards: Array[Dictionary],
	uid: String,
	effect_id: String,
	instance_id: int,
	expected_uid_count: int
) -> bool:
	var matches := 0
	var uid_count := 0
	var has_runtime_metadata := false
	for card: Dictionary in cards:
		if str(card.get("uid", "")).to_upper() != uid.to_upper():
			continue
		uid_count += 1
		var observed_effect := str(card.get("effect_id", ""))
		var observed_instance := int(card.get("instance_id", -1))
		if observed_effect == "" and observed_instance < 0:
			continue
		has_runtime_metadata = true
		if observed_instance != instance_id:
			continue
		if not _public_card_binding_matches(card, uid, effect_id, instance_id, true):
			return false
		matches += 1
	if has_runtime_metadata:
		return matches == 1 and uid_count == expected_uid_count
	return uid_count == expected_uid_count


func _profiled_active_gardevoir_attack_print_matches(active: Dictionary, config: Dictionary) -> bool:
	var pokemon: Dictionary = active.get("pokemon", {}) if active.get("pokemon", {}) is Dictionary else {}
	var definitions: Array = active.get("attack_definitions", []) \
		if active.get("attack_definitions", []) is Array else []
	# The compact production observation may omit printed attack metadata.  The
	# deck/manifest/root hashes and exact public UID still bind the card print;
	# when metadata is present (fixtures or a richer gateway), validate it fully.
	if definitions.is_empty():
		return true
	if definitions.size() != 1 or not (definitions[0] is Dictionary):
		return false
	var attack: Dictionary = definitions[0]
	return int(pokemon.get("instance_id", -1)) == int(config.get("active_instance_id", -2)) \
		and int(attack.get("index", -1)) == int(config.get("attack_index", -2)) \
		and attack.get("cost", []) == config.get("attack_cost", []) \
		and int(attack.get("damage", 0)) == int(config.get("attack_damage", -1))


func _configured_public_slots_match(observed: Dictionary, configured_value: Variant) -> bool:
	if not (configured_value is Array) or observed.size() != (configured_value as Array).size():
		return false
	for raw_spec: Variant in configured_value as Array:
		if not (raw_spec is Dictionary):
			return false
		var spec: Dictionary = raw_spec
		var slot_id := str(spec.get("slot_id", ""))
		if not observed.has(slot_id) or not _configured_public_slot_matches(
			observed.get(slot_id, {}) if observed.get(slot_id, {}) is Dictionary else {}, spec
		):
			return false
	return true


func _configured_public_slot_matches(slot: Dictionary, spec: Dictionary) -> bool:
	return _public_slot_binding_matches(
		slot, str(spec.get("uid", "")), str(spec.get("effect_id", "")),
		str(spec.get("slot_id", "")), int(spec.get("instance_id", -1))
	) \
		and int(slot.get("remaining_hp", -1)) == int(spec.get("remaining_hp", -2)) \
		and int(slot.get("prize_count", 0)) == int(spec.get("prize_count", -1)) \
		and slot.get("energy_symbols", []) == spec.get("energy_symbols", [])


func _uid_counts_from_public_cards(cards: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_card: Variant in cards:
		if raw_card is Dictionary:
			var uid := str((raw_card as Dictionary).get("uid", "")).strip_edges().to_upper()
			if uid != "":
				result[uid] = int(result.get(uid, 0)) + 1
	return result


func _normalized_uid_counts_from_dictionary(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_uid: Variant in value.keys():
		var uid := str(raw_uid).strip_edges().to_upper()
		if uid != "":
			result[uid] = int(value.get(raw_uid, 0))
	return result


func _public_board_symbol_count(state: Dictionary, symbol: String) -> int:
	var count := _count_string(
		(state.get("own_active", {}) as Dictionary).get("energy_symbols", []) \
			if state.get("own_active", {}) is Dictionary else [], symbol
	)
	var bench: Dictionary = state.get("own_bench", {}) \
		if state.get("own_bench", {}) is Dictionary else {}
	for raw_slot: Variant in bench.values():
		if raw_slot is Dictionary:
			count += _count_string((raw_slot as Dictionary).get("energy_symbols", []), symbol)
	return count


func _count_string(values: Variant, wanted: String) -> int:
	if not (values is Array):
		return 0
	var count := 0
	for raw_value: Variant in values as Array:
		if str(raw_value) == wanted:
			count += 1
	return count


func _profiled_active_gardevoir_ko_pair_role(
	route: Dictionary,
	config: Dictionary,
	stage: String
) -> String:
	var action_id := str(route.get("safe_prefix_action_id", ""))
	var action_kind := str(route.get("action_kind", ""))
	var route_id := str(route.get("route_id", ""))
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	if stage == "manual_psychic_to_active":
		if action_kind != "attach_energy" or route_id != "route:energy_commit":
			return ""
		var target := str(action_ref.get("target", ""))
		var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
		if not _public_card_binding_matches(
			card, str(config.get("psychic_uid", "")), str(config.get("psychic_effect_id", "")),
			int(config.get("manual_psychic_instance_id", -1)), true
		):
			return ""
		if action_id == str(config.get("attach_active_action_id", "")) \
				and target == str(config.get("active_slot_id", "")):
			return "preferred"
		if action_id == str(config.get("rule_attach_action_id", "")) \
				and target != str(config.get("active_slot_id", "")):
			return "dominated"
		return ""
	if stage in ["first_embrace_to_active", "second_embrace_to_active"]:
		if action_id == str(config.get("embrace_action_id", "")) \
				and action_kind == "use_ability" \
				and route_id == "route:information" \
				and _profiled_active_gardevoir_embrace_binding_matches(action_ref, config):
			return "preferred"
		if stage == "second_embrace_to_active" \
				and action_id == str(config.get("rule_munkidori_action_id", "")):
			return "dominated"
		return ""
	if stage == "active_gardevoir_190_ko":
		if action_id == str(config.get("attack_action_id", "")) \
				and action_kind == "attack" \
				and route_id == "route:attack_ko" \
				and _profiled_active_gardevoir_attack_binding_matches(action_ref, route, config):
			return "preferred"
		if action_id == str(config.get("rule_munkidori_action_id", "")) \
				and action_kind == "use_ability":
			return "dominated"
	return ""


func _profiled_active_gardevoir_embrace_binding_matches(
	action_ref: Dictionary,
	config: Dictionary
) -> bool:
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	return str(action_ref.get("source", "")) == str(config.get("active_slot_id", "")) \
		and int(action_ref.get("ability_index", -1)) == 0 \
		and _public_card_binding_matches(
			source_card, str(config.get("active_uid", "")), str(config.get("active_effect_id", "")),
			int(config.get("active_instance_id", -1)), true
		)


func _profiled_active_gardevoir_attack_binding_matches(
	action_ref: Dictionary,
	route: Dictionary,
	config: Dictionary
) -> bool:
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	var public_attack_cost: Variant = action_ref.get("attack_cost", [])
	var attack_cost_matches: bool = public_attack_cost is Array \
		and ((public_attack_cost as Array).is_empty() \
			or public_attack_cost == config.get("attack_cost", []))
	return str(action_ref.get("source", "")) == str(config.get("active_slot_id", "")) \
		and int(action_ref.get("attack_index", -1)) == int(config.get("attack_index", -2)) \
		and attack_cost_matches \
		and int(action_ref.get("projected_damage", 0)) == int(config.get("attack_damage", -1)) \
		and bool(action_ref.get("projected_knockout", false)) \
		and bool(route.get("outcome", {}).get("terminal", false)) \
			if route.get("outcome", {}) is Dictionary else false \
		and _public_card_binding_matches(
			source_card, str(config.get("active_uid", "")), str(config.get("active_effect_id", "")),
			int(config.get("active_instance_id", -1)), true
		)


func _profiled_engine_hold_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_engine_hold", {}) \
		if own_annotation.get("profiled_engine_hold", {}) is Dictionary else {}


func _profiled_engine_hold_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" \
			or str(route.get("action_kind", "")) not in ["play_trainer", "play_basic_to_bench", "evolve", "attach_energy", "use_ability", "retreat", "attack"]:
		return {}
	var parameters := _module_parameters(profile)
	var active_uid_required := str(parameters.get("profiled_engine_hold_active_uid", "")).strip_edges().to_upper()
	var preserve_action_uid := str(parameters.get("profiled_engine_hold_preserve_action_uid", "")).strip_edges().to_upper()
	var required_deck_count := maxi(0, int(parameters.get("profiled_engine_hold_deck_count", 0)))
	var required_psychic_discard := maxi(0, int(parameters.get("profiled_engine_hold_psychic_discard", 0)))
	var required_prizes := maxi(0, int(parameters.get("profiled_engine_hold_own_prizes_remaining", 0)))
	var required_opponent_prizes := maxi(0, int(parameters.get("profiled_engine_hold_opponent_prizes_remaining", 0)))
	var opponent_uid_required := str(parameters.get("profiled_engine_hold_opponent_active_uid", "")).strip_edges().to_upper()
	var opponent_hp_required := maxi(0, int(parameters.get("profiled_engine_hold_opponent_active_remaining_hp", 0)))
	if active_uid_required == "" or preserve_action_uid == "" \
			or required_deck_count <= 0 or required_psychic_discard <= 0 \
			or required_prizes <= 0 or required_opponent_prizes <= 0 \
			or opponent_uid_required == "" or opponent_hp_required <= 0:
		return {}
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var visible_hand_count := 0
	for raw_count: Variant in hand_uid_counts.values():
		visible_hand_count += int(raw_count)
	var action_ref: Dictionary = route.get("action_ref", {}) if route.get("action_ref", {}) is Dictionary else {}
	var action_card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var action_uid := str(action_card.get("uid", "")).strip_edges().to_upper()
	var stage := ""
	if action_uid == preserve_action_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "pre"):
		stage = "secret_box_access"
	var gust_action_uid := str(parameters.get("profiled_engine_hold_gust_action_uid", "")).strip_edges().to_upper()
	if stage == "" and action_uid == gust_action_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_box"):
		stage = "counter_catcher_access"
	var attacker_search_action_uid := str(parameters.get("profiled_engine_hold_attacker_search_action_uid", "")).strip_edges().to_upper()
	if stage == "" and action_uid == attacker_search_action_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_gust"):
		stage = "ultra_ball_attacker_search"
	var bench_attacker_action_uid := str(parameters.get("profiled_engine_hold_bench_attacker_action_uid", "")).strip_edges().to_upper()
	if stage == "" and action_uid == bench_attacker_action_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_ultra"):
		stage = "bench_damage_scaler"
	var engine_action_uid := str(parameters.get("profiled_engine_hold_engine_action_uid", "")).strip_edges().to_upper()
	if stage == "" and action_uid == engine_action_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_bench"):
		stage = "evolve_embrace_engine"
	var hand_lock_action_uid := str(parameters.get("profiled_engine_hold_hand_lock_action_uid", "")).strip_edges().to_upper()
	if stage == "" and action_uid == hand_lock_action_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_engine"):
		stage = "iono_hand_lock"
	var pivot_energy_action_uid := str(parameters.get("profiled_engine_hold_pivot_energy_action_uid", "")).strip_edges().to_upper()
	var pivot_energy_target_uid := str(parameters.get("profiled_engine_hold_pivot_energy_target_uid", "")).strip_edges().to_upper()
	var target_slot_id := str(action_ref.get("target", ""))
	var states: Dictionary = snapshot.get("slot_state", {}) if snapshot.get("slot_state", {}) is Dictionary else {}
	var target_state: Dictionary = states.get(target_slot_id, {}) if states.get(target_slot_id, {}) is Dictionary else {}
	if stage == "" and action_uid == pivot_energy_action_uid \
			and str(target_state.get("pokemon_uid", "")).strip_edges().to_upper() == pivot_energy_target_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "post_draw"):
		stage = "bank_active_retreat_energy"
	var source_ref: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	var source_uid := str(source_ref.get("uid", "")).strip_edges().to_upper()
	var source_slot_id := str(action_ref.get("source", ""))
	var source_state: Dictionary = states.get(source_slot_id, {}) \
		if states.get(source_slot_id, {}) is Dictionary else {}
	var drif_attach_uid := str(parameters.get(
		"profiled_engine_hold_drif_attach_action_uid", ""
	)).strip_edges().to_upper()
	var drif_attach_active_uid := str(parameters.get(
		"profiled_engine_hold_drif_attach_active_uid", ""
	)).strip_edges().to_upper()
	if stage == "" and str(route.get("action_kind", "")) == "attach_energy" \
			and action_uid == drif_attach_uid \
			and str(target_state.get("pokemon_uid", "")).strip_edges().to_upper() == drif_attach_active_uid \
			and target_slot_id == str(snapshot.get("own_active_slot_id", "")) \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "drif_attach"):
		stage = "bank_active_energy_for_drif_pivot"
	var resource_order_source_uid := str(parameters.get(
		"profiled_engine_hold_resource_order_source_uid", ""
	)).strip_edges().to_upper()
	if stage == "" and str(route.get("action_kind", "")) == "use_ability" \
			and resource_order_source_uid != "" \
			and source_uid == resource_order_source_uid \
			and source_slot_id != str(snapshot.get("own_active_slot_id", "")) \
			and str(source_state.get("pokemon_uid", "")).strip_edges().to_upper() == resource_order_source_uid \
			and not bool(source_state.get("ability_used", true)) \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "resource_order"):
		stage = "refinement_before_manual_attachment"
	var damage_step_source_uid := str(parameters.get(
		"profiled_engine_hold_damage_step_source_uid", ""
	)).strip_edges().to_upper()
	if stage == "" and str(route.get("action_kind", "")) == "use_ability" \
			and damage_step_source_uid != "" \
			and source_uid == damage_step_source_uid \
			and source_slot_id != str(snapshot.get("own_active_slot_id", "")) \
			and str(source_state.get("pokemon_uid", "")).strip_edges().to_upper() == damage_step_source_uid \
			and not bool(source_state.get("ability_used", true)) \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "damage_step"):
		stage = "second_embrace_before_pivot"
	for closeout_state: String in ["active_closeout_first", "active_closeout_second"]:
		if stage != "":
			break
		var closeout_source_uid := str(parameters.get(
			"profiled_engine_hold_%s_source_uid" % closeout_state, ""
		)).strip_edges().to_upper()
		if str(route.get("action_kind", "")) == "use_ability" \
				and closeout_source_uid != "" \
				and source_uid == closeout_source_uid \
				and source_slot_id == str(snapshot.get("own_active_slot_id", "")) \
				and str(source_state.get("pokemon_uid", "")).strip_edges().to_upper() == closeout_source_uid \
				and not bool(source_state.get("ability_used", true)) \
				and _profiled_engine_hold_matches_state(snapshot, parameters, closeout_state):
			stage = "embrace_active_ko_first" if closeout_state == "active_closeout_first" \
				else "embrace_active_ko_second"
	var active_closeout_attack_uid := str(parameters.get(
		"profiled_engine_hold_active_closeout_attack_source_uid", ""
	)).strip_edges().to_upper()
	if stage == "" and str(route.get("action_kind", "")) == "attack" \
			and active_closeout_attack_uid != "" \
			and source_uid == active_closeout_attack_uid \
			and source_slot_id == str(snapshot.get("own_active_slot_id", "")) \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "active_closeout_attack"):
		stage = "attack_before_counter_move"
	for drif_embrace_state: String in ["drif_embrace1", "drif_embrace2", "drif_embrace3"]:
		if stage != "":
			break
		var drif_embrace_source_uid := str(parameters.get(
			"profiled_engine_hold_%s_source_uid" % drif_embrace_state, ""
		)).strip_edges().to_upper()
		if str(route.get("action_kind", "")) == "use_ability" \
				and source_uid == drif_embrace_source_uid \
				and source_slot_id == str(snapshot.get("own_active_slot_id", "")) \
				and _profiled_engine_hold_matches_state(snapshot, parameters, drif_embrace_state):
			stage = "load_drifloon_%s" % drif_embrace_state.trim_prefix("drif_")
	var drif_pivot_uid := str(parameters.get(
		"profiled_engine_hold_drif_pivot_target_uid", ""
	)).strip_edges().to_upper()
	if stage == "" and str(route.get("action_kind", "")) == "retreat" \
			and str(target_state.get("pokemon_uid", "")).strip_edges().to_upper() == drif_pivot_uid \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "drif_pivot"):
		stage = "pivot_to_loaded_drifloon"
	var drif_attack_uid := str(parameters.get(
		"profiled_engine_hold_drif_attack_source_uid", ""
	)).strip_edges().to_upper()
	if stage == "" and str(route.get("action_kind", "")) == "attack" \
			and source_uid == drif_attack_uid \
			and source_slot_id == str(snapshot.get("own_active_slot_id", "")) \
			and _profiled_engine_hold_matches_state(snapshot, parameters, "drif_attack"):
		stage = "attack_with_loaded_drifloon"
	var state_for_bench: String = str({
		"bench_damage_scaler": "post_ultra",
		"evolve_embrace_engine": "post_bench",
		"iono_hand_lock": "post_engine",
		"bank_active_retreat_energy": "post_draw",
		"refinement_before_manual_attachment": "resource_order",
		"second_embrace_before_pivot": "damage_step",
		"embrace_active_ko_first": "active_closeout_first",
		"embrace_active_ko_second": "active_closeout_second",
		"attack_before_counter_move": "active_closeout_attack",
		"bank_active_energy_for_drif_pivot": "drif_attach",
		"load_drifloon_embrace1": "drif_embrace1",
		"load_drifloon_embrace2": "drif_embrace2",
		"load_drifloon_embrace3": "drif_embrace3",
		"pivot_to_loaded_drifloon": "drif_pivot",
		"attack_with_loaded_drifloon": "drif_attack",
	}.get(stage, ""))
	var bench_key := "profiled_engine_hold_required_bench_uids" if state_for_bench == "" \
		else "profiled_engine_hold_%s_required_bench_uids" % state_for_bench
	var required_bench_counts := _uid_counts(parameters.get(bench_key, []))
	return {
		"active_uid": active_uid_required,
		"preserve_action_uid": preserve_action_uid,
		"required_bench_counts": required_bench_counts,
		"required_hand_ready": stage != "",
		"visible_hand_count": visible_hand_count,
		"psychic_energy_in_discard": int(snapshot.get("psychic_energy_in_discard", 0)),
		"stage": stage,
		"advances_profiled_engine_hold": stage != "",
	}


func _profiled_engine_hold_matches_state(
	snapshot: Dictionary,
	parameters: Dictionary,
	state_name: String
) -> bool:
	var suffix := "" if state_name == "pre" else "_%s" % state_name
	var active_uid_required := str(parameters.get(
		"profiled_engine_hold%s_active_uid" % suffix,
		parameters.get("profiled_engine_hold_active_uid", "")
	)).strip_edges().to_upper()
	var required_deck_count := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_deck_count" % suffix,
		parameters.get("profiled_engine_hold_deck_count", 0)
	)))
	var psychic_discard_key := "profiled_engine_hold%s_psychic_discard" % suffix
	var psychic_discard_is_explicit := parameters.has(psychic_discard_key)
	var required_psychic_discard := maxi(0, int(parameters.get(
		psychic_discard_key,
		parameters.get("profiled_engine_hold_psychic_discard", 0)
	)))
	var required_prizes := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_own_prizes_remaining" % suffix,
		parameters.get("profiled_engine_hold_own_prizes_remaining", 0)
	)))
	var required_opponent_prizes := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_opponent_prizes_remaining" % suffix,
		parameters.get("profiled_engine_hold_opponent_prizes_remaining", 0)
	)))
	var opponent_uid_required := str(parameters.get(
		"profiled_engine_hold%s_opponent_active_uid" % suffix,
		parameters.get("profiled_engine_hold_opponent_active_uid", "")
	)).strip_edges().to_upper()
	var opponent_hp_required := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_opponent_active_remaining_hp" % suffix,
		parameters.get("profiled_engine_hold_opponent_active_remaining_hp", 0)
	)))
	var opponent_energy_required := int(parameters.get(
		"profiled_engine_hold%s_opponent_active_energy_count" % suffix,
		-1
	))
	var energy_available_required := bool(parameters.get(
		"profiled_engine_hold%s_energy_available" % suffix,
		true
	))
	var supporter_available_required := bool(parameters.get(
		"profiled_engine_hold%s_supporter_available" % suffix,
		true
	))
	var require_attack_not_ready := bool(parameters.get(
		"profiled_engine_hold%s_require_attack_not_ready" % suffix,
		true
	))
	var bench_key := "profiled_engine_hold%s_required_bench_uids" % suffix
	var required_bench_counts := _uid_counts(parameters.get(
		bench_key,
		parameters.get("profiled_engine_hold_required_bench_uids", [])
	))
	var required_bench_total := 0
	for raw_required_count: Variant in required_bench_counts.values():
		required_bench_total += int(raw_required_count)
	var hand_key := "profiled_engine_hold%s_required_hand_uids" % suffix
	var required_hand_counts := _uid_counts(parameters.get(hand_key, []))
	if active_uid_required == "" or required_deck_count <= 0 \
			or (required_psychic_discard <= 0 and not psychic_discard_is_explicit) or required_prizes <= 0 \
			or required_opponent_prizes <= 0 or opponent_uid_required == "" \
			or opponent_hp_required <= 0 or required_hand_counts.is_empty():
		return false
	var states: Dictionary = snapshot.get("slot_state", {}) if snapshot.get("slot_state", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var active_symbols: Array = active_energy.get("attached_symbols", []) \
		if active_energy.get("attached_symbols", []) is Array else []
	var active_energy_required := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_active_energy_count" % suffix,
		0
	)))
	var active_psychic_required := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_active_psychic_count" % suffix,
		0
	)))
	var active_psychic_count := 0
	for raw_active_symbol: Variant in active_symbols:
		if str(raw_active_symbol) == "P":
			active_psychic_count += 1
	var active_damage_required := int(parameters.get(
		"profiled_engine_hold%s_active_damage_points" % suffix,
		-1
	))
	var active_hp_required := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_active_remaining_hp" % suffix,
		0
	)))
	var visible_bench_counts: Dictionary = {}
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		if slot_id == active_slot_id:
			continue
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		var uid := str(state.get("pokemon_uid", "")).strip_edges().to_upper()
		visible_bench_counts[uid] = int(visible_bench_counts.get(uid, 0)) + 1
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var target_uid_required := str(parameters.get(
		"profiled_engine_hold%s_target_uid" % suffix,
		""
	)).strip_edges().to_upper()
	var target_energy_key := "profiled_engine_hold%s_target_energy_count" % suffix
	var target_energy_is_explicit := parameters.has(target_energy_key)
	var target_energy_required := maxi(0, int(parameters.get(target_energy_key, 0)))
	var target_psychic_key := "profiled_engine_hold%s_target_psychic_count" % suffix
	var target_psychic_is_explicit := parameters.has(target_psychic_key)
	var target_psychic_required := maxi(0, int(parameters.get(
		target_psychic_key,
		0
	)))
	var target_damage_key := "profiled_engine_hold%s_target_damage_points" % suffix
	var target_damage_is_explicit := parameters.has(target_damage_key)
	var target_damage_required := maxi(0, int(parameters.get(
		target_damage_key,
		0
	)))
	var target_hp_required := maxi(0, int(parameters.get(
		"profiled_engine_hold%s_target_remaining_hp" % suffix,
		0
	)))
	var target_state_matches := target_uid_required == ""
	if target_uid_required != "":
		target_state_matches = false
		for raw_target_slot_id: Variant in states.keys():
			var target_slot_id := str(raw_target_slot_id)
			var candidate_target: Dictionary = states.get(target_slot_id, {}) \
				if states.get(target_slot_id, {}) is Dictionary else {}
			var candidate_energy: Dictionary = energy_states.get(target_slot_id, {}) \
				if energy_states.get(target_slot_id, {}) is Dictionary else {}
			var target_symbols: Array = candidate_energy.get("attached_symbols", []) \
				if candidate_energy.get("attached_symbols", []) is Array else []
			var attached_psychic := 0
			for raw_symbol: Variant in target_symbols:
				if str(raw_symbol) == "P":
					attached_psychic += 1
			if str(candidate_target.get("pokemon_uid", "")).strip_edges().to_upper() == target_uid_required \
					and (not target_energy_is_explicit or target_symbols.size() == target_energy_required) \
					and (not target_psychic_is_explicit or attached_psychic == target_psychic_required) \
					and (not target_damage_is_explicit or int(candidate_target.get("damage_points", 0)) == target_damage_required) \
					and (target_hp_required <= 0 or int(candidate_target.get("remaining_hp", 0)) == target_hp_required):
				target_state_matches = true
				break
	return str(active.get("pokemon_uid", "")).strip_edges().to_upper() == active_uid_required \
		and (active_hp_required <= 0 or int(active.get("remaining_hp", 0)) == active_hp_required) \
		and active_symbols.size() == active_energy_required \
		and active_psychic_count == active_psychic_required \
		and (active_damage_required < 0 or int(active.get("damage_points", 0)) == active_damage_required) \
		and states.size() == required_bench_total + 1 \
		and visible_bench_counts == required_bench_counts \
		and hand_uid_counts == required_hand_counts \
		and int(snapshot.get("own_deck_count", 0)) == required_deck_count \
		and int(snapshot.get("psychic_energy_in_discard", 0)) == required_psychic_discard \
		and int(snapshot.get("own_prizes_remaining", 0)) == required_prizes \
		and int(snapshot.get("opponent_prizes_remaining", 0)) == required_opponent_prizes \
		and str(opponent_pokemon.get("uid", "")).strip_edges().to_upper() == opponent_uid_required \
		and int(opponent_active.get("remaining_hp", 0)) == opponent_hp_required \
		and (opponent_energy_required < 0 or int(opponent_active.get("energy_count", 0)) == opponent_energy_required) \
		and bool(snapshot.get("turn_energy_available", false)) == energy_available_required \
		and bool(snapshot.get("turn_supporter_available", false)) == supporter_available_required \
		and target_state_matches \
		and (not require_attack_not_ready or not bool(snapshot.get("attack_ready", false)))


func _uid_counts(raw_uids: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw_uids is Array:
		return result
	for raw_uid: Variant in raw_uids:
		var uid := str(raw_uid).strip_edges().to_upper()
		if uid != "":
			result[uid] = int(result.get(uid, 0)) + 1
	return result


func _profiled_retreat_bridge_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("profiled_retreat_bridge", {}) \
		if own_annotation.get("profiled_retreat_bridge", {}) is Dictionary else {}


func _profiled_retreat_bridge_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" or str(route.get("action_kind", "")) != "attach_energy":
		return {}
	var parameters := _module_parameters(profile)
	var active_uid_required := str(parameters.get("profiled_retreat_bridge_active_uid", "")).strip_edges().to_upper()
	var attacker_uid := str(parameters.get("profiled_retreat_bridge_attacker_uid", "")).strip_edges().to_upper()
	var manual_symbol := str(parameters.get("profiled_retreat_bridge_manual_symbol", "D")).strip_edges().to_upper()
	var required_prizes := maxi(0, int(parameters.get("profiled_retreat_bridge_own_prizes_remaining", 0)))
	var required_opponent_prizes := maxi(0, int(parameters.get("profiled_retreat_bridge_opponent_prizes_remaining", 0)))
	var opponent_uid_required := str(parameters.get("profiled_retreat_bridge_opponent_active_uid", "")).strip_edges().to_upper()
	var opponent_hp_required := maxi(0, int(parameters.get("profiled_retreat_bridge_opponent_active_remaining_hp", 0)))
	if active_uid_required == "" or attacker_uid == "" or manual_symbol == "" \
			or required_prizes <= 0 or required_opponent_prizes <= 0 \
			or opponent_uid_required == "" or opponent_hp_required <= 0:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var states: Dictionary = snapshot.get("slot_state", {}) if snapshot.get("slot_state", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var active_symbols: Array = active_energy.get("attached_symbols", []) \
		if active_energy.get("attached_symbols", []) is Array else []
	var attacker_ready := false
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		if slot_id == active_slot_id:
			continue
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		var slot_energy: Dictionary = energy_states.get(slot_id, {}) if energy_states.get(slot_id, {}) is Dictionary else {}
		if str(state.get("pokemon_uid", "")).strip_edges().to_upper() == attacker_uid \
				and "P" in (slot_energy.get("attached_symbols", []) as Array):
			attacker_ready = true
			break
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var required_hand_ready := true
	for raw_uid: Variant in parameters.get("profiled_retreat_bridge_required_hand_uids", []):
		if int(hand_uid_counts.get(str(raw_uid).strip_edges().to_upper(), 0)) <= 0:
			required_hand_ready = false
			break
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var advances := str(active.get("pokemon_uid", "")).strip_edges().to_upper() == active_uid_required \
		and states.size() == 5 \
		and active_symbols.is_empty() \
		and attacker_ready \
		and _energy_symbol(card) == manual_symbol \
		and str(action_ref.get("target", "")) == active_slot_id \
		and int(snapshot.get("own_prizes_remaining", 0)) == required_prizes \
		and int(snapshot.get("opponent_prizes_remaining", 0)) == required_opponent_prizes \
		and str(opponent_pokemon.get("uid", "")).strip_edges().to_upper() == opponent_uid_required \
		and int(opponent_active.get("remaining_hp", 0)) == opponent_hp_required \
		and required_hand_ready \
		and bool(snapshot.get("turn_energy_available", false)) \
		and bool(snapshot.get("turn_supporter_available", false)) \
		and not bool(snapshot.get("attack_ready", false))
	return {
		"active_uid": active_uid_required,
		"attacker_uid": attacker_uid,
		"manual_symbol": manual_symbol,
		"required_hand_ready": required_hand_ready,
		"advances_profiled_retreat_bridge": advances,
	}


func _profiled_engine_search_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" or str(route.get("action_kind", "")) != "play_trainer":
		return {}
	var parameters := _module_parameters(profile)
	var search_uid := str(parameters.get("profiled_engine_search_uid", "")).strip_edges().to_upper()
	var followup_search_uid := str(parameters.get("profiled_engine_followup_search_uid", "")).strip_edges().to_upper()
	var followup_tool_uid := str(parameters.get("profiled_engine_followup_required_tool_uid", "")).strip_edges().to_upper()
	var active_uid_required := str(parameters.get("profiled_engine_search_active_uid", "")).strip_edges().to_upper()
	var required_prizes := maxi(0, int(parameters.get("profiled_engine_search_own_prizes_remaining", 0)))
	var required_opponent_prizes := maxi(0, int(parameters.get("profiled_engine_search_opponent_prizes_remaining", 0)))
	var required_bench_free := maxi(0, int(parameters.get("profiled_engine_search_required_bench_free", 0)))
	var completion_symbol := str(parameters.get("profiled_engine_search_completion_symbol", "D")).strip_edges().to_upper()
	var minimum_completion_energy := maxi(0, int(parameters.get("profiled_engine_search_min_hand_completion_energy", 0)))
	var opponent_uid_required := str(parameters.get("profiled_engine_search_opponent_active_uid", "")).strip_edges().to_upper()
	var opponent_hp_required := maxi(0, int(parameters.get("profiled_engine_search_opponent_active_remaining_hp", 0)))
	if search_uid == "" or followup_search_uid == "" or followup_tool_uid == "" \
			or active_uid_required == "" or required_prizes <= 0 \
			or required_opponent_prizes <= 0 or required_bench_free <= 0 \
			or completion_symbol == "" or minimum_completion_energy <= 0 \
			or opponent_uid_required == "" or opponent_hp_required <= 0:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var action_uid := str(card.get("uid", "")).strip_edges().to_upper()
	if action_uid not in [search_uid, followup_search_uid]:
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) if snapshot.get("slot_state", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) if states.get(active_slot_id, {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var attached_symbols: Array = active_energy.get("attached_symbols", []) \
		if active_energy.get("attached_symbols", []) is Array else []
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var hand_energy: Dictionary = snapshot.get("hand_energy_by_symbol", {}) \
		if snapshot.get("hand_energy_by_symbol", {}) is Dictionary else {}
	var required_hand_ready := true
	for raw_uid: Variant in parameters.get("profiled_engine_search_required_hand_uids", []):
		if int(hand_uid_counts.get(str(raw_uid).strip_edges().to_upper(), 0)) <= 0:
			required_hand_ready = false
			break
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var shared_ready := str(active.get("pokemon_uid", "")).strip_edges().to_upper() == active_uid_required \
		and states.size() == 1 \
		and attached_symbols.size() == 1 and "P" in attached_symbols \
		and int(snapshot.get("own_prizes_remaining", 0)) == required_prizes \
		and int(snapshot.get("opponent_prizes_remaining", 0)) == required_opponent_prizes \
		and int(snapshot.get("bench_slots_free", 0)) == required_bench_free \
		and int(hand_energy.get(completion_symbol, 0)) >= minimum_completion_energy \
		and required_hand_ready \
		and str(opponent_pokemon.get("uid", "")).strip_edges().to_upper() == opponent_uid_required \
		and int(opponent_active.get("remaining_hp", 0)) == opponent_hp_required \
		and bool(snapshot.get("turn_energy_available", false)) \
		and not bool(snapshot.get("attack_ready", false))
	var stage := ""
	if shared_ready and action_uid == search_uid and bool(snapshot.get("turn_supporter_available", false)):
		stage = "supporter_tutor_before_attack_completion"
	elif shared_ready and action_uid == followup_search_uid \
			and not bool(snapshot.get("turn_supporter_available", false)) \
			and int(hand_uid_counts.get(followup_tool_uid, 0)) > 0:
		stage = "pokemon_search_before_attack_completion"
	return {
		"search_uid": search_uid,
		"followup_search_uid": followup_search_uid,
		"search_stage": stage,
		"active_uid": active_uid_required,
		"attached_symbols": attached_symbols.duplicate(),
		"completion_symbol": completion_symbol,
		"completion_energy_in_hand": int(hand_energy.get(completion_symbol, 0)),
		"required_hand_ready": required_hand_ready,
		"advances_profiled_engine_search": stage != "",
	}


func _profiled_attacker_setup_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "damage_counter_control":
		return {}
	var parameters := _module_parameters(profile)
	var search_uid := str(parameters.get("profiled_setup_search_uid", "")).strip_edges().to_upper()
	var preserve_search_uid := str(parameters.get("profiled_setup_preserve_search_uid", "")).strip_edges().to_upper()
	var attacker_uid := str(parameters.get("profiled_setup_attacker_uid", "")).strip_edges().to_upper()
	var active_uid_required := str(parameters.get("profiled_setup_active_uid", "")).strip_edges().to_upper()
	var visible_uid_required := str(parameters.get("profiled_setup_required_visible_uid", "")).strip_edges().to_upper()
	var required_visible_count := maxi(0, int(parameters.get("profiled_setup_required_visible_count", 0)))
	var required_prizes := maxi(0, int(parameters.get("profiled_setup_own_prizes_remaining", 0)))
	var required_opponent_prizes := maxi(0, int(parameters.get("profiled_setup_opponent_prizes_remaining", 0)))
	var required_opponent_active_prizes := maxi(0, int(parameters.get("profiled_setup_opponent_active_prize_count", 0)))
	var required_opponent_active_hp := maxi(0, int(parameters.get("profiled_setup_opponent_active_remaining_hp", 0)))
	var minimum_discard_psychic := maxi(0, int(parameters.get("profiled_setup_min_psychic_discard", 0)))
	var search_min_hand_psychic := maxi(0, int(parameters.get("profiled_setup_search_min_hand_psychic", 0)))
	var post_search_min_hand_psychic := maxi(0, int(parameters.get("profiled_setup_post_search_min_hand_psychic", 0)))
	var attachment_symbol := str(parameters.get("profiled_setup_attachment_symbol", "P")).strip_edges().to_upper()
	if search_uid == "" or attacker_uid == "" or active_uid_required == "" \
			or visible_uid_required == "" or required_visible_count <= 0 or required_prizes <= 0 \
			or required_opponent_prizes <= 0 or required_opponent_active_prizes <= 0 \
			or required_opponent_active_hp <= 0 \
			or search_min_hand_psychic <= 0 or post_search_min_hand_psychic <= 0:
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) if states.get(active_slot_id, {}) is Dictionary else {}
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	if str(active.get("pokemon_uid", "")).strip_edges().to_upper() != active_uid_required \
			or int(snapshot.get("own_prizes_remaining", 0)) != required_prizes \
			or int(snapshot.get("opponent_prizes_remaining", 0)) != required_opponent_prizes \
			or int(opponent_active.get("prize_count", 0)) != required_opponent_active_prizes \
			or int(opponent_active.get("remaining_hp", 0)) != required_opponent_active_hp \
			or int(snapshot.get("psychic_energy_in_discard", 0)) < minimum_discard_psychic \
			or bool(snapshot.get("attack_ready", false)):
		return {}
	var visible_required_count := 0
	var visible_attacker_count := 0
	var attacker_slot_id := ""
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		var uid := str(state.get("pokemon_uid", "")).strip_edges().to_upper()
		if uid == visible_uid_required:
			visible_required_count += 1
		if uid == attacker_uid:
			visible_attacker_count += 1
			attacker_slot_id = slot_id
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var hand_energy: Dictionary = snapshot.get("hand_energy_by_symbol", {}) \
		if snapshot.get("hand_energy_by_symbol", {}) is Dictionary else {}
	var known_in_deck: Dictionary = snapshot.get("known_in_deck_uid_counts", {}) \
		if snapshot.get("known_in_deck_uid_counts", {}) is Dictionary else {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var active_energy: Dictionary = energy_states.get(active_slot_id, {}) \
		if energy_states.get(active_slot_id, {}) is Dictionary else {}
	var attacker_energy: Dictionary = energy_states.get(attacker_slot_id, {}) \
		if energy_states.get(attacker_slot_id, {}) is Dictionary else {}
	var active_symbols: Array = active_energy.get("attached_symbols", []) \
		if active_energy.get("attached_symbols", []) is Array else []
	var attacker_symbols: Array = attacker_energy.get("attached_symbols", []) \
		if attacker_energy.get("attached_symbols", []) is Array else []
	var action_ref: Dictionary = route.get("action_ref", {}) if route.get("action_ref", {}) is Dictionary else {}
	var action_card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var action_uid := str(action_card.get("uid", "")).strip_edges().to_upper()
	var action_kind := str(route.get("action_kind", ""))
	var stage := ""
	if action_kind == "play_trainer" and action_uid == search_uid:
		var required_hand_ready := true
		for raw_uid: Variant in parameters.get("profiled_setup_search_required_hand_uids", []):
			if int(hand_uid_counts.get(str(raw_uid).strip_edges().to_upper(), 0)) <= 0:
				required_hand_ready = false
				break
		if visible_required_count == required_visible_count \
				and states.size() == required_visible_count \
				and visible_attacker_count == 0 \
				and int(hand_uid_counts.get(attacker_uid, 0)) == 0 \
				and int(hand_energy.get(attachment_symbol, 0)) >= search_min_hand_psychic \
				and int(known_in_deck.get(attacker_uid, 0)) >= 1 \
				and str(snapshot.get("belief_evidence_kind", "")) == "public_hand_reset_transition" \
				and bool(snapshot.get("turn_energy_available", false)) \
				and int(snapshot.get("bench_slots_free", 0)) > 0 \
				and active_symbols.is_empty() \
				and required_hand_ready:
			stage = "search_attacker_before_attachment"
	elif action_kind == "attach_energy" \
			and _energy_symbol(action_card) == attachment_symbol \
			and str(action_ref.get("target", "")) == attacker_slot_id:
		if visible_required_count == required_visible_count \
				and visible_attacker_count == 1 \
				and states.size() == required_visible_count + 1 \
				and int(hand_energy.get(attachment_symbol, 0)) >= search_min_hand_psychic \
				and bool(snapshot.get("turn_energy_available", false)) \
				and active_symbols.is_empty() and attacker_symbols.is_empty():
			stage = "attach_searched_attacker"
	elif action_kind == "end_turn" \
			and visible_required_count == required_visible_count \
			and visible_attacker_count == 1 \
			and states.size() == required_visible_count + 1 \
			and attachment_symbol in attacker_symbols \
			and active_symbols.is_empty() \
			and not bool(snapshot.get("turn_energy_available", false)) \
			and int(hand_energy.get(attachment_symbol, 0)) >= post_search_min_hand_psychic \
			and preserve_search_uid != "" \
			and int(hand_uid_counts.get(preserve_search_uid, 0)) > 0:
		stage = "preserve_followup_pivot_energy"
	elif action_kind == "retreat" \
			and str(action_ref.get("target", "")) == attacker_slot_id \
			and visible_required_count == required_visible_count \
			and visible_attacker_count == 1 \
			and states.size() == required_visible_count + 1 \
			and attachment_symbol in attacker_symbols \
			and attachment_symbol in active_symbols \
			and not bool(snapshot.get("turn_energy_available", false)):
		stage = "pivot_to_charged_attacker"
	elif action_kind == "attach_energy" \
			and _energy_symbol(action_card) == attachment_symbol \
			and str(action_ref.get("target", "")) == active_slot_id \
			and visible_required_count == required_visible_count \
			and visible_attacker_count == 1 \
			and states.size() == required_visible_count + 1 \
			and attachment_symbol in attacker_symbols \
			and active_symbols.is_empty() \
			and bool(snapshot.get("turn_energy_available", false)) \
			and int(hand_energy.get(attachment_symbol, 0)) >= post_search_min_hand_psychic:
		stage = "attach_active_for_followup_pivot"
	return {
		"setup_stage": stage,
		"search_uid": search_uid,
		"attacker_uid": attacker_uid,
		"active_uid": active_uid_required,
		"attacker_slot_id": attacker_slot_id,
		"visible_required_count": visible_required_count,
		"hand_psychic": int(hand_energy.get(attachment_symbol, 0)),
		"psychic_energy_in_discard": int(snapshot.get("psychic_energy_in_discard", 0)),
		"known_attacker_in_deck": int(known_in_deck.get(attacker_uid, 0)),
		"advances_profiled_attacker_setup": stage != "",
	}


func _profiled_counter_activation_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "damage_counter_control" \
			or str(route.get("action_kind", "")) != "attach_energy":
		return {}
	var parameters := _module_parameters(profile)
	var mover_uid := str(parameters.get("counter_mover_uid", "")).strip_edges().to_upper()
	var activation_symbol := str(parameters.get("activation_symbol", "D")).strip_edges().to_upper()
	var required_prizes := maxi(0, int(parameters.get("profiled_activation_own_prizes_remaining", 0)))
	var min_hand_psychic := maxi(0, int(parameters.get("profiled_activation_min_hand_psychic", 0)))
	if mover_uid == "" or required_prizes <= 0 or min_hand_psychic <= 0:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var target_slot_id := str(action_ref.get("target", ""))
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var target: Dictionary = states.get(target_slot_id, {}) if states.get(target_slot_id, {}) is Dictionary else {}
	if target_slot_id == "" \
			or str(target.get("pokemon_uid", "")).strip_edges().to_upper() != mover_uid \
			or bool(target.get("ability_used", false)) \
			or _energy_symbol(card) != activation_symbol \
			or not bool(snapshot.get("turn_energy_available", false)) \
			or int(snapshot.get("own_prizes_remaining", 0)) != required_prizes:
		return {}
	var energy_states: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var target_energy: Dictionary = energy_states.get(target_slot_id, {}) \
		if energy_states.get(target_slot_id, {}) is Dictionary else {}
	if activation_symbol in (target_energy.get("attached_symbols", []) as Array):
		return {}
	var hand_energy: Dictionary = snapshot.get("hand_energy_by_symbol", {}) \
		if snapshot.get("hand_energy_by_symbol", {}) is Dictionary else {}
	if int(hand_energy.get(activation_symbol, 0)) <= 0 or int(hand_energy.get("P", 0)) < min_hand_psychic:
		return {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active: Dictionary = states.get(active_slot_id, {}) if states.get(active_slot_id, {}) is Dictionary else {}
	var active_uid := str(active.get("pokemon_uid", "")).strip_edges().to_upper()
	var opening_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("profiled_activation_opening_active_uids", []):
		opening_uids.append(str(raw_uid).strip_edges().to_upper())
	var damaged_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("profiled_activation_damaged_active_uids", []):
		damaged_uids.append(str(raw_uid).strip_edges().to_upper())
	var activation_stage := ""
	if active_uid in opening_uids and target_slot_id == active_slot_id \
			and not bool(snapshot.get("attack_ready", false)):
		var required_bench_uid := str(parameters.get("profiled_activation_opening_required_bench_uid", "")).strip_edges().to_upper()
		var required_bench_count := maxi(0, int(parameters.get("profiled_activation_opening_required_bench_count", 0)))
		var visible_required_bench := 0
		for raw_slot_id: Variant in states.keys():
			var slot_id := str(raw_slot_id)
			if slot_id == active_slot_id:
				continue
			var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
			if str(state.get("pokemon_uid", "")).strip_edges().to_upper() == required_bench_uid:
				visible_required_bench += 1
		var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
			if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
		var required_hand_uids: Array[String] = []
		for raw_uid: Variant in parameters.get("profiled_activation_opening_required_hand_uids", []):
			required_hand_uids.append(str(raw_uid).strip_edges().to_upper())
		var hand_access_ready := not required_hand_uids.is_empty()
		for required_uid: String in required_hand_uids:
			if int(hand_uid_counts.get(required_uid, 0)) <= 0:
				hand_access_ready = false
				break
		var visible_foundation_ready := required_bench_uid != "" and required_bench_count > 0 \
			and visible_required_bench >= required_bench_count
		if visible_foundation_ready or hand_access_ready:
			activation_stage = "opening_preserve_psychic"
	elif active_uid in damaged_uids and target_slot_id != active_slot_id \
			and not bool(snapshot.get("attack_ready", false)):
		var minimum_damage := maxi(0, int(parameters.get("profiled_activation_min_movable_damage", 0)))
		var minimum_psychic_discard := maxi(0, int(parameters.get("profiled_activation_min_psychic_discard", 0)))
		if int(snapshot.get("own_damage_counters", 0)) * 10 >= minimum_damage \
				and int(snapshot.get("psychic_energy_in_discard", 0)) >= minimum_psychic_discard:
			activation_stage = "immediate_counter_move"
	return {
		"counter_mover_uid": mover_uid,
		"activation_symbol": activation_symbol,
		"target_slot_id": target_slot_id,
		"active_uid": active_uid,
		"activation_stage": activation_stage,
		"preserved_hand_psychic": int(hand_energy.get("P", 0)),
		"movable_damage": int(snapshot.get("own_damage_counters", 0)) * 10,
		"psychic_energy_in_discard": int(snapshot.get("psychic_energy_in_discard", 0)),
		"advances_profiled_activation": activation_stage != "",
	}


func _profiled_hand_reset_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "damage_counter_control" \
			or str(route.get("action_kind", "")) != "play_trainer":
		return {}
	var parameters := _module_parameters(profile)
	var supporter_uid := str(parameters.get("midgame_reset_supporter_uid", "")).strip_edges().to_upper()
	var mover_uid := str(parameters.get("counter_mover_uid", "")).strip_edges().to_upper()
	var required_movers := maxi(0, int(parameters.get("midgame_reset_required_movers", 0)))
	var required_prizes := maxi(0, int(parameters.get("midgame_reset_own_prizes_remaining", 0)))
	var max_attack_damage := maxi(0, int(parameters.get("midgame_reset_max_attack_damage", 0)))
	var minimum_hand_size := maxi(0, int(parameters.get("midgame_reset_min_hand_size", 0)))
	var required_bench_uid := str(parameters.get("midgame_reset_required_bench_uid", "")).strip_edges().to_upper()
	var required_bench_count := maxi(0, int(parameters.get("midgame_reset_required_bench_count", 0)))
	var active_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("setup_active_uids", []):
		active_uids.append(str(raw_uid).strip_edges().to_upper())
	if supporter_uid == "" or mover_uid == "" or required_movers <= 0 \
			or required_prizes <= 0 or required_bench_uid == "" or required_bench_count <= 0:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	if str(card.get("uid", "")).strip_edges().to_upper() != supporter_uid:
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active_state: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_uid := str(active_state.get("pokemon_uid", "")).strip_edges().to_upper()
	var mover_count := 0
	var bench_piece_count := 0
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		if slot_id == active_slot_id:
			continue
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		var uid := str(state.get("pokemon_uid", "")).strip_edges().to_upper()
		if uid == mover_uid:
			mover_count += 1
		if uid == required_bench_uid:
			bench_piece_count += 1
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var attack_damage := int(snapshot.get("attack_max_damage", 0))
	var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
		if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
	var hand_size := 0
	for raw_count: Variant in hand_uid_counts.values():
		hand_size += int(raw_count)
	var advances := bool(snapshot.get("attack_ready", false)) \
		and not bool(snapshot.get("ko_available", false)) \
		and bool(snapshot.get("turn_supporter_available", false)) \
		and active_uid in active_uids \
		and attack_damage >= 0 and attack_damage <= max_attack_damage \
		and int(snapshot.get("own_prizes_remaining", 0)) == required_prizes \
		and int(snapshot.get("bench_slots_free", 0)) == 0 \
		and mover_count >= required_movers \
		and bench_piece_count >= required_bench_count \
		and hand_size >= minimum_hand_size \
		and int(opponent_active.get("prize_count", 0)) >= 2 \
		and int(opponent_active.get("remaining_hp", 0)) > attack_damage
	return {
		"supporter_uid": supporter_uid,
		"active_uid": active_uid,
		"mover_count": mover_count,
		"bench_piece_count": bench_piece_count,
		"hand_size": hand_size,
		"attack_damage": attack_damage,
		"evidence_kind": "paired_evaluation",
		"advances_profiled_reset": advances,
	}


func _counter_engine_setup_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "damage_counter_control" \
			or str(route.get("action_kind", "")) != "play_basic_to_bench":
		return {}
	var parameters := _module_parameters(profile)
	var mover_uid := str(parameters.get("counter_mover_uid", "")).strip_edges().to_upper()
	var target_count := maxi(0, int(parameters.get("setup_counter_mover_target_count", 0)))
	var setup_prizes := maxi(0, int(parameters.get("setup_own_prizes_remaining", 0)))
	var max_attack_damage := maxi(0, int(parameters.get("setup_max_attack_damage", 0)))
	var min_opponent_prizes := maxi(1, int(parameters.get("setup_min_opponent_prizes", 2)))
	var active_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("setup_active_uids", []):
		active_uids.append(str(raw_uid).strip_edges().to_upper())
	if mover_uid == "" or target_count <= 0 or setup_prizes <= 0 or active_uids.is_empty():
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	if str(card.get("uid", "")).strip_edges().to_upper() != mover_uid:
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var active_state: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_uid := str(active_state.get("pokemon_uid", "")).strip_edges().to_upper()
	var mover_count := 0
	for raw_state: Variant in states.values():
		if raw_state is Dictionary \
				and str((raw_state as Dictionary).get("pokemon_uid", "")).strip_edges().to_upper() == mover_uid:
			mover_count += 1
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var attack_damage := int(snapshot.get("attack_max_damage", 0))
	var bench_slots_free := int(snapshot.get("bench_slots_free", 0))
	var safety: Dictionary = profile.get("safety", {}) if profile.get("safety", {}) is Dictionary else {}
	var preserved_slots := maxi(0, int(safety.get("preserve_bench_slots", 1)))
	var advances := bool(snapshot.get("attack_ready", false)) \
		and not bool(snapshot.get("ko_available", false)) \
		and active_uid in active_uids \
		and attack_damage >= 0 and attack_damage <= max_attack_damage \
		and int(snapshot.get("own_prizes_remaining", 0)) == setup_prizes \
		and int(opponent_active.get("prize_count", 0)) >= min_opponent_prizes \
		and int(opponent_active.get("remaining_hp", 0)) > attack_damage \
		and mover_count < target_count \
		and bench_slots_free - 1 >= preserved_slots
	return {
		"counter_mover_uid": mover_uid,
		"active_uid": active_uid,
		"mover_count_before": mover_count,
		"mover_count_after": mover_count + 1,
		"target_count": target_count,
		"attack_damage": attack_damage,
		"opponent_active_hp": int(opponent_active.get("remaining_hp", 0)),
		"bench_slots_after": bench_slots_free - 1,
		"advances_profiled_setup": advances,
	}


func _counter_mover_closeout_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "damage_counter_control":
		return {}
	var parameters := _module_parameters(profile)
	var mover_uid := str(parameters.get("counter_mover_uid", "")).strip_edges().to_upper()
	var activation_symbol := str(parameters.get("activation_symbol", "D")).strip_edges().to_upper()
	var move_points := maxi(1, int(parameters.get("move_points_per_use", 0)))
	var invariant_attackers: Array[String] = []
	for raw_uid: Variant in parameters.get("damage_invariant_attackers", []):
		invariant_attackers.append(str(raw_uid).strip_edges().to_upper())
	if mover_uid == "" or invariant_attackers.is_empty():
		return {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var active_state: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_uid := str(active_state.get("pokemon_uid", "")).strip_edges().to_upper()
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_hp := int(opponent_active.get("remaining_hp", 0))
	var attack_damage := int(snapshot.get("attack_max_damage", 0))
	var damage_gap := opponent_hp - attack_damage
	var own_prizes := int(snapshot.get("own_prizes_remaining", 0))
	var opponent_prizes := int(opponent_active.get("prize_count", 0))
	if not bool(snapshot.get("attack_ready", false)) \
			or bool(snapshot.get("ko_available", false)) \
			or active_uid not in invariant_attackers \
			or attack_damage <= 0 \
			or damage_gap <= 0 \
			or damage_gap > move_points \
			or own_prizes <= 0 \
			or opponent_prizes < own_prizes:
		return {}
	var movable_capacity := 0
	for raw_state: Variant in states.values():
		if raw_state is Dictionary:
			movable_capacity = maxi(
				movable_capacity,
				mini(move_points, maxi(0, int((raw_state as Dictionary).get("damage_points", 0))))
			)
	if movable_capacity < damage_gap:
		return {}
	var energies: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var ready_mover_slots: Array[String] = []
	var attachable_mover_slots: Array[String] = []
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		var state: Dictionary = states.get(slot_id, {}) if states.get(slot_id, {}) is Dictionary else {}
		if str(state.get("pokemon_uid", "")).strip_edges().to_upper() != mover_uid \
				or bool(state.get("ability_used", false)):
			continue
		var energy_state: Dictionary = energies.get(slot_id, {}) if energies.get(slot_id, {}) is Dictionary else {}
		var attached_symbols: Array = energy_state.get("attached_symbols", []) \
			if energy_state.get("attached_symbols", []) is Array else []
		if activation_symbol in attached_symbols:
			ready_mover_slots.append(slot_id)
		else:
			attachable_mover_slots.append(slot_id)
	var action_kind := str(route.get("action_kind", ""))
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var closeout_stage := ""
	var selected_slot_id := ""
	if action_kind == "use_ability":
		var source_card: Dictionary = action_ref.get("source_card", {}) \
			if action_ref.get("source_card", {}) is Dictionary else {}
		selected_slot_id = str(action_ref.get("source", ""))
		if str(source_card.get("uid", "")).strip_edges().to_upper() == mover_uid \
				and selected_slot_id in ready_mover_slots:
			closeout_stage = "move_final_counters"
	elif action_kind == "attach_energy":
		var energy_card: Dictionary = action_ref.get("card", {}) \
			if action_ref.get("card", {}) is Dictionary else {}
		selected_slot_id = str(action_ref.get("target", ""))
		if ready_mover_slots.is_empty() \
				and selected_slot_id in attachable_mover_slots \
				and bool(snapshot.get("turn_energy_available", false)) \
				and _energy_symbol(energy_card) == activation_symbol:
			closeout_stage = "activate_second_counter_mover"
	elif action_kind == "play_basic_to_bench":
		var pokemon_card: Dictionary = action_ref.get("card", {}) \
			if action_ref.get("card", {}) is Dictionary else {}
		var hand_uid_counts: Dictionary = snapshot.get("hand_uid_counts", {}) \
			if snapshot.get("hand_uid_counts", {}) is Dictionary else {}
		var hand_energy: Dictionary = snapshot.get("hand_energy_by_symbol", {}) \
			if snapshot.get("hand_energy_by_symbol", {}) is Dictionary else {}
		if str(pokemon_card.get("uid", "")).strip_edges().to_upper() == mover_uid \
				and ready_mover_slots.is_empty() \
				and attachable_mover_slots.is_empty() \
				and int(snapshot.get("bench_slots_free", 0)) >= 1 \
				and bool(snapshot.get("turn_energy_available", false)) \
				and int(hand_uid_counts.get(mover_uid, 0)) >= 1 \
				and int(hand_energy.get(activation_symbol, 0)) >= 1:
			closeout_stage = "bench_second_counter_mover"
	var advances := closeout_stage != ""
	return {
		"counter_mover_uid": mover_uid,
		"activation_symbol": activation_symbol,
		"closeout_stage": closeout_stage,
		"selected_slot_id": selected_slot_id,
		"damage_gap": damage_gap,
		"movable_capacity": movable_capacity,
		"attack_damage": attack_damage,
		"opponent_active_hp": opponent_hp,
		"projected_total_damage": attack_damage + mini(move_points, movable_capacity),
		"prizes_now": opponent_prizes,
		"advances_final_prize_closeout": advances,
	}


func _counter_mover_before_secured_ko_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	# A bounded public same-turn proof only.  It covers either (a) activating a
	# counter mover without changing the current KO, or (b) using an activated
	# mover for a uniquely bound active KO that earns the same prize floor before
	# a fixed-damage attacker pressures a known live replacement.
	var action_kind := str(route.get("action_kind", ""))
	if _module_id != "damage_counter_control" \
			or action_kind not in ["attach_energy", "use_ability"] \
			or not bool(route.get("engine_rule_floor_exact", false)):
		return {}
	var parameters := _module_parameters(profile)
	var mover_uid := str(parameters.get("counter_mover_uid", "")).strip_edges().to_upper()
	var mover_ability_index := int(parameters.get("counter_mover_ability_index", 0))
	var activation_symbol := str(parameters.get("activation_symbol", "D")).strip_edges().to_upper()
	var move_points := maxi(1, int(parameters.get("move_points_per_use", 0)))
	var allow_non_ko_prefix := bool(parameters.get(
		"allow_non_ko_counter_prefix_before_secured_ko", false
	))
	var require_no_counter_ko_target := bool(parameters.get(
		"require_no_counter_ko_target", false
	))
	var invariant_attackers: Array[String] = []
	for raw_uid: Variant in parameters.get("damage_invariant_attackers", []):
		invariant_attackers.append(str(raw_uid).strip_edges().to_upper())
	if mover_uid == "" or activation_symbol == "" or invariant_attackers.is_empty():
		return {}
	if not bool(snapshot.get("attack_ready", false)) \
			or not bool(snapshot.get("ko_available", false)) \
			or bool(snapshot.get("win_now", false)):
		return {}
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var opponent_hp := int(opponent_active.get("remaining_hp", 0))
	var attack_damage := int(snapshot.get("attack_max_damage", 0))
	if opponent_hp <= 0 or attack_damage < opponent_hp:
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var active_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var energies: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var target_slot_id := ""
	var prefix_stage := ""
	var transfer_points := move_points
	var opponent_target_slot_id := ""
	var forced_sendout := false
	if action_kind == "attach_energy":
		var energy_card: Dictionary = action_ref.get("card", {}) \
			if action_ref.get("card", {}) is Dictionary else {}
		if not bool(snapshot.get("turn_energy_available", false)) \
				or _energy_symbol(energy_card) != activation_symbol:
			return {}
		target_slot_id = str(action_ref.get("target", ""))
		prefix_stage = "activate_counter_mover"
		# The following counter move cannot replace the current Active before the
		# already-proved attack. Bench counter damage is harmless to that KO.
		if opponent_hp <= move_points:
			return {}
	else:
		var source_card: Dictionary = action_ref.get("source_card", {}) \
			if action_ref.get("source_card", {}) is Dictionary else {}
		if str(source_card.get("uid", "")).strip_edges().to_upper() != mover_uid \
				or int(action_ref.get("ability_index", -1)) != mover_ability_index \
				or not bool(action_ref.get("requires_interaction", false)):
			return {}
		target_slot_id = str(action_ref.get("source", ""))
		prefix_stage = "move_counters"
	var target_state: Dictionary = states.get(target_slot_id, {}) \
		if states.get(target_slot_id, {}) is Dictionary else {}
	if target_state.is_empty() \
			or target_slot_id == active_slot_id \
			or str(target_state.get("pokemon_uid", "")).strip_edges().to_upper() != mover_uid \
			or bool(target_state.get("ability_used", false)):
		return {}
	var target_energy: Dictionary = energies.get(target_slot_id, {}) \
		if energies.get(target_slot_id, {}) is Dictionary else {}
	var attached_symbols: Array = target_energy.get("attached_symbols", []) \
		if target_energy.get("attached_symbols", []) is Array else []
	if action_kind == "attach_energy" and activation_symbol in attached_symbols:
		return {}
	if action_kind == "use_ability" and activation_symbol not in attached_symbols:
		return {}
	var active_state: Dictionary = states.get(active_slot_id, {}) \
		if states.get(active_slot_id, {}) is Dictionary else {}
	var active_uid := str(active_state.get("pokemon_uid", "")).strip_edges().to_upper()
	if action_kind == "use_ability" and active_uid not in invariant_attackers:
		return {}
	if action_kind == "use_ability":
		var opponent_states: Dictionary = snapshot.get("opponent_slot_state", {}) \
			if snapshot.get("opponent_slot_state", {}) is Dictionary else {}
		var ko_targets: Array[String] = []
		var live_replacements := 0
		for raw_slot_id: Variant in opponent_states.keys():
			var slot_id := str(raw_slot_id)
			var state: Dictionary = opponent_states.get(slot_id, {}) \
				if opponent_states.get(slot_id, {}) is Dictionary else {}
			var remaining_hp := int(state.get("remaining_hp", 0))
			if remaining_hp <= 0:
				continue
			if not bool(state.get("is_active", false)):
				live_replacements += 1
			if remaining_hp <= move_points:
				ko_targets.append(slot_id)
		if ko_targets.size() == 1:
			opponent_target_slot_id = ko_targets[0]
			var opponent_target: Dictionary = opponent_states.get(opponent_target_slot_id, {}) \
				if opponent_states.get(opponent_target_slot_id, {}) is Dictionary else {}
			if not bool(opponent_target.get("is_active", false)) or live_replacements <= 0:
				return {}
			transfer_points = ceili(float(int(opponent_target.get("remaining_hp", 0))) / 10.0) * 10
			forced_sendout = true
		elif ko_targets.is_empty() \
				and allow_non_ko_prefix \
				and require_no_counter_ko_target \
				and not opponent_states.is_empty():
			# This opt-in covers the exact Rule interaction without stealing its
			# target choice: every public live target survives the full transfer,
			# so the same Active and the already-secured attack prize remain bound.
			transfer_points = move_points
			forced_sendout = false
		else:
			return {}
	var eligible_source_count := 0
	var source_slot_id := ""
	var source_uid := ""
	for raw_slot_id: Variant in states.keys():
		var slot_id := str(raw_slot_id)
		if slot_id == target_slot_id:
			continue
		var state: Dictionary = states.get(slot_id, {}) \
			if states.get(slot_id, {}) is Dictionary else {}
		var uid := str(state.get("pokemon_uid", "")).strip_edges().to_upper()
		var damage_points := int(state.get("damage_points", 0))
		if damage_points <= 0:
			continue
		# The exact Rule resolver rejects a ready KO attacker's scalable damage as
		# a source. Mirror that public invariant; any other damaged non-invariant
		# source makes interaction ownership ambiguous and fails closed.
		if uid not in invariant_attackers:
			if slot_id == active_slot_id \
					and bool(snapshot.get("attack_ready", false)) \
					and bool(snapshot.get("ko_available", false)):
				continue
			return {}
		if damage_points < transfer_points:
			return {}
		eligible_source_count += 1
		if source_slot_id == "":
			source_slot_id = slot_id
			source_uid = uid
	if source_slot_id == "" or eligible_source_count <= 0:
		return {}
	var prizes_floor := int(opponent_active.get("prize_count", 0))
	if prizes_floor <= 0 or int(snapshot.get("own_prizes_remaining", 0)) <= prizes_floor:
		return {}
	return {
		"counter_mover_uid": mover_uid,
		"activation_symbol": activation_symbol,
		"prefix_stage": prefix_stage,
		"target_slot_id": target_slot_id,
		"source_slot_id": source_slot_id,
		"source_uid": source_uid,
		"move_points": move_points,
		"transfer_points": transfer_points,
		"opponent_target_slot_id": opponent_target_slot_id,
		"opponent_target_scope": "any_public_live_slot" \
			if action_kind == "use_ability" and not forced_sendout else "exact_slot",
		"forced_sendout": forced_sendout,
		"attack_damage": attack_damage,
		"opponent_active_hp": opponent_hp,
		"prizes_now": int(opponent_active.get("prize_count", 0)),
		"prizes_floor": prizes_floor,
		"win_now": false,
		"recoverable_ability_window_gain": 1,
		"preserves_secured_ko": action_kind == "attach_energy" \
			or (action_kind == "use_ability" and not forced_sendout),
		"preserves_secured_prize_suffix": true,
	}


func _deterministic_attack_dominance_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "damage_counter_control" \
			or str(route.get("action_kind", "")) not in ["attack", "granted_attack"] \
			or str(route.get("checkpoint_after", "")) != "terminal":
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	if not action_ref.has("projected_damage") \
			or not action_ref.has("projected_knockout") \
			or bool(action_ref.get("projected_knockout", false)):
		return {}
	if int(action_ref.get("projected_damage", 0)) > 0 \
			and _opponent_active_has_damage_reactive_effect(snapshot):
		return {}
	var source_slot_id := str(action_ref.get("source", ""))
	if source_slot_id == "" or source_slot_id != str(snapshot.get("own_active_slot_id", "")):
		return {}
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	var source_uid := str(source_card.get("uid", "")).strip_edges().to_upper()
	var parameters := _module_parameters(profile)
	var pair_map: Dictionary = parameters.get("deterministic_attack_dominance_pairs_by_uid", {}) \
		if parameters.get("deterministic_attack_dominance_pairs_by_uid", {}) is Dictionary else {}
	var pairs: Array = pair_map.get(source_uid, []) if pair_map.get(source_uid, []) is Array else []
	if pairs.is_empty():
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var source_state: Dictionary = states.get(source_slot_id, {}) \
		if states.get(source_slot_id, {}) is Dictionary else {}
	if str(source_state.get("pokemon_uid", "")).strip_edges().to_upper() != source_uid:
		return {}
	var outcome: Dictionary = route.get("outcome", {}) if route.get("outcome", {}) is Dictionary else {}
	if bool(outcome.get("win_now", false)) or int(outcome.get("prizes_now", 0)) > 0:
		return {}
	var attack_index := int(action_ref.get("attack_index", -1))
	for raw_pair: Variant in pairs:
		if not (raw_pair is Dictionary):
			continue
		var pair: Dictionary = raw_pair
		var required_damage := int(pair.get("requires_source_damage_points", -1))
		if required_damage >= 0 and int(source_state.get("damage_points", 0)) != required_damage:
			continue
		var preferred_index := int(pair.get("preferred_attack_index", -1))
		var dominated_index := int(pair.get("dominated_attack_index", -1))
		var pair_role := "preferred" if attack_index == preferred_index \
			else "dominated" if attack_index == dominated_index else ""
		if pair_role == "":
			continue
		return {
			"pair_key": "%s:%d>%d:%d" % [source_uid, preferred_index, dominated_index, required_damage],
			"pair_role": pair_role,
			"source_slot_id": source_slot_id,
			"source_uid": source_uid,
			"attack_index": attack_index,
			"projected_damage": int(action_ref.get("projected_damage", -1)),
			"requires_source_damage_points": required_damage,
			"no_registered_side_effects": bool(pair.get("no_registered_side_effects", false)),
		} if bool(pair.get("no_registered_side_effects", false)) else {}
	return {}


func _opponent_active_has_damage_reactive_effect(snapshot: Dictionary) -> bool:
	var active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	if active.is_empty():
		return false
	var public_cards: Array = []
	if active.get("pokemon", {}) is Dictionary:
		public_cards.append(active.get("pokemon", {}))
	if active.get("tool", {}) is Dictionary:
		public_cards.append(active.get("tool", {}))
	if active.get("energy", []) is Array:
		public_cards.append_array(active.get("energy", []))
	for raw_card: Variant in public_cards:
		if not (raw_card is Dictionary):
			continue
		var effect_id := str((raw_card as Dictionary).get("effect_id", "")).strip_edges().to_lower()
		if effect_id in DAMAGE_REACTIVE_ACTIVE_EFFECT_IDS:
			return true
	return false


func _prize_scaler_tool_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("prize_scaler_tool", {}) \
		if own_annotation.get("prize_scaler_tool", {}) is Dictionary else {}


func _prize_scaler_embrace_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var own_annotation: Dictionary = annotations.get(_module_id, {}) \
		if annotations.get(_module_id, {}) is Dictionary else {}
	return own_annotation.get("prize_scaler_embrace", {}) \
		if own_annotation.get("prize_scaler_embrace", {}) is Dictionary else {}


func _prize_scaler_embrace_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" or str(route.get("action_kind", "")) != "use_ability":
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	var source_uid := str(source_card.get("uid", "")).strip_edges().to_upper()
	var parameters := _module_parameters(profile)
	var engine_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("embrace_engine_uids", []):
		engine_uids.append(str(raw_uid).strip_edges().to_upper())
	if source_uid not in engine_uids:
		return {}
	var target_slot_id := str(snapshot.get("own_active_slot_id", ""))
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var target: Dictionary = states.get(target_slot_id, {}) if states.get(target_slot_id, {}) is Dictionary else {}
	var target_uid := str(target.get("pokemon_uid", "")).strip_edges().to_upper()
	var scalers: Dictionary = parameters.get("damage_scalers_by_uid", {}) \
		if parameters.get("damage_scalers_by_uid", {}) is Dictionary else {}
	var scaler: Dictionary = scalers.get(target_uid, {}) if scalers.get(target_uid, {}) is Dictionary else {}
	if scaler.is_empty():
		return {}
	var tool_uid := str(target.get("tool_uid", "")).strip_edges().to_upper()
	var tools: Dictionary = parameters.get("prize_scaler_tools", {}) \
		if parameters.get("prize_scaler_tools", {}) is Dictionary else {}
	if not tools.has(tool_uid):
		return {}
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var target_hp := int(opponent_active.get("remaining_hp", 0))
	var damage_per_counter := maxi(1, int(scaler.get("damage_per_counter", 0)))
	var embrace_damage := maxi(1, int(scaler.get("embrace_damage_per_assignment", 20)))
	var counters_per_assignment := maxi(1, int(embrace_damage / 10))
	var current_damage_points := maxi(0, int(target.get("damage_points", 0)))
	var current_counters := int(current_damage_points / 10)
	var needed_counters := ceili(float(target_hp) / float(damage_per_counter)) if target_hp > 0 else 0
	var assignments_for_damage := ceili(float(maxi(0, needed_counters - current_counters)) / float(counters_per_assignment))
	var energies: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var target_energy: Dictionary = energies.get(target_slot_id, {}) \
		if energies.get(target_slot_id, {}) is Dictionary else {}
	var attached_symbols: Array[String] = []
	for raw_symbol: Variant in target_energy.get("attached_symbols", []):
		attached_symbols.append(str(raw_symbol))
	var required := EnergySymbolsScript.canonical_array(scaler.get("attack_cost", []))
	var assignments_for_cost := _missing_required_symbols(required, attached_symbols).size()
	var required_assignments := maxi(assignments_for_damage, assignments_for_cost)
	var remaining_hp := int(target.get("remaining_hp", 0))
	var fuel := int(snapshot.get("psychic_energy_in_discard", 0))
	var safe_sequence := required_assignments > 0 \
		and required_assignments * embrace_damage < remaining_hp
	var projected_damage := (current_counters + required_assignments * counters_per_assignment) * damage_per_counter
	var prizes_now := int(opponent_active.get("prize_count", 1)) if projected_damage >= target_hp and target_hp > 0 else 0
	var own_prizes := int(snapshot.get("own_prizes_remaining", 0))
	var wins_now := prizes_now > 0 and own_prizes > 0 and prizes_now >= own_prizes
	return {
		"source_uid": source_uid,
		"tool_uid": tool_uid,
		"target_slot_id": target_slot_id,
		"target_uid": target_uid,
		"psychic_fuel": fuel,
		"required_assignments": required_assignments,
		"next_assignment_safe": embrace_damage < remaining_hp,
		"full_sequence_safe": safe_sequence,
		"projected_damage": projected_damage,
		"opponent_active_hp": target_hp,
		"prizes_now": prizes_now,
		"current_attack_already_ko": assignments_for_damage == 0 and assignments_for_cost == 0,
		# This projection spans one or more future interaction-bearing actions. It
		# deliberately carries no certificate authority until the exact target and
		# the one-step post-action frontier are bound and recomputed.
		"diagnostic_projected_future_sequence": wins_now and fuel >= required_assignments \
			and safe_sequence and required_assignments > 0,
		"wins_now_after_public_embrace_sequence": false,
		"certificate_authorized": false,
	}


func _prize_scaler_tool_for_route(
	route: Dictionary,
	snapshot: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "gardevoir_embrace" or str(route.get("action_kind", "")) != "attach_tool":
		return {}
	var action_ref: Dictionary = route.get("action_ref", {}) \
		if route.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var tool_uid := str(card.get("uid", "")).strip_edges().to_upper()
	var parameters := _module_parameters(profile)
	var tools: Dictionary = parameters.get("prize_scaler_tools", {}) \
		if parameters.get("prize_scaler_tools", {}) is Dictionary else {}
	var tool: Dictionary = tools.get(tool_uid, {}) if tools.get(tool_uid, {}) is Dictionary else {}
	if tool.is_empty():
		return {}
	var target_slot_id := str(action_ref.get("target", ""))
	if target_slot_id == "" or target_slot_id != str(snapshot.get("own_active_slot_id", "")):
		return {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var target: Dictionary = states.get(target_slot_id, {}) if states.get(target_slot_id, {}) is Dictionary else {}
	var target_uid := str(target.get("pokemon_uid", "")).strip_edges().to_upper()
	var scalers: Dictionary = parameters.get("damage_scalers_by_uid", {}) \
		if parameters.get("damage_scalers_by_uid", {}) is Dictionary else {}
	var scaler: Dictionary = scalers.get(target_uid, {}) if scalers.get(target_uid, {}) is Dictionary else {}
	if scaler.is_empty():
		return {}
	var engine_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("embrace_engine_uids", []):
		engine_uids.append(str(raw_uid).strip_edges().to_upper())
	var engine_online := false
	for raw_state: Variant in states.values():
		if raw_state is Dictionary and str((raw_state as Dictionary).get("pokemon_uid", "")).strip_edges().to_upper() in engine_uids:
			engine_online = true
			break
	var opponent_active: Dictionary = snapshot.get("opponent_active", {}) \
		if snapshot.get("opponent_active", {}) is Dictionary else {}
	var target_hp := int(opponent_active.get("remaining_hp", 0))
	var damage_per_counter := maxi(1, int(scaler.get("damage_per_counter", 0)))
	var embrace_damage := maxi(1, int(scaler.get("embrace_damage_per_assignment", 20)))
	var counters_per_assignment := maxi(1, int(embrace_damage / 10))
	var current_damage_points := maxi(0, int(target.get("damage_points", 0)))
	var current_counters := int(current_damage_points / 10)
	var needed_counters := ceili(float(target_hp) / float(damage_per_counter)) if target_hp > 0 else 0
	var assignments_for_damage := ceili(float(maxi(0, needed_counters - current_counters)) / float(counters_per_assignment))
	var energies: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var target_energy: Dictionary = energies.get(target_slot_id, {}) \
		if energies.get(target_slot_id, {}) is Dictionary else {}
	var attached_symbols: Array[String] = []
	for raw_symbol: Variant in target_energy.get("attached_symbols", []):
		attached_symbols.append(str(raw_symbol))
	var required := EnergySymbolsScript.canonical_array(scaler.get("attack_cost", []))
	var assignments_for_cost := _missing_required_symbols(required, attached_symbols).size()
	var required_assignments := maxi(assignments_for_damage, assignments_for_cost)
	var remaining_hp := int(target.get("remaining_hp", 0))
	var hp_bonus := maxi(0, int(tool.get("hp_bonus", 0)))
	var fuel := int(snapshot.get("psychic_energy_in_discard", 0))
	var safe_without_tool := required_assignments > 0 \
		and required_assignments * embrace_damage < remaining_hp
	var safe_with_tool := required_assignments > 0 \
		and required_assignments * embrace_damage < remaining_hp + hp_bonus
	var projected_damage := (current_counters + required_assignments * counters_per_assignment) * damage_per_counter
	var prizes_now := int(opponent_active.get("prize_count", 1)) if projected_damage >= target_hp and target_hp > 0 else 0
	var own_prizes := int(snapshot.get("own_prizes_remaining", 0))
	var wins_now := prizes_now > 0 and own_prizes > 0 and prizes_now >= own_prizes
	return {
		"tool_uid": tool_uid,
		"target_slot_id": target_slot_id,
		"target_uid": target_uid,
		"engine_online": engine_online,
		"psychic_fuel": fuel,
		"required_assignments": required_assignments,
		"projected_damage": projected_damage,
		"opponent_active_hp": target_hp,
		"prizes_now": prizes_now,
		"safe_without_tool": safe_without_tool,
		"safe_with_tool": safe_with_tool,
		"crosses_public_ko_threshold": projected_damage >= target_hp and not safe_without_tool and safe_with_tool,
		"wins_now_after_public_embrace_sequence": wins_now and engine_online \
			and fuel >= required_assignments and not safe_without_tool and safe_with_tool,
	}


func _module_parameters(profile: Dictionary) -> Dictionary:
	var parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	return parameters.get(_module_id, {}) if parameters.get(_module_id, {}) is Dictionary else {}
