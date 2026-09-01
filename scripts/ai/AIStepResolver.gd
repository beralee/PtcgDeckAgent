class_name AIStepResolver
extends RefCounted

const AIInteractionPlannerScript = preload("res://scripts/ai/AIInteractionPlanner.gd")
const AIInteractionFeatureEncoderScript = preload("res://scripts/ai/AIInteractionFeatureEncoder.gd")
const AIHandoffScoringScript = preload("res://scripts/ai/AIHandoffScoring.gd")
const UcisCompilerScript = preload("res://scripts/engine/ucis/UcisInteractionCompiler.gd")

## Optional injected deck strategy that guides interaction target choices.
var deck_strategy: RefCounted = null
var interaction_scorer: RefCounted = null
var decision_exporter: RefCounted = null
var _matchup_context: Dictionary = {}

var _interaction_planner = AIInteractionPlannerScript.new()
var _interaction_feature_encoder = AIInteractionFeatureEncoderScript.new()
var _external_assignment_plans: Dictionary = {}


func set_deck_strategy(strategy: RefCounted) -> void:
	deck_strategy = strategy
	_external_assignment_plans.clear()


func set_matchup_context(matchup_context: Dictionary) -> void:
	_matchup_context = matchup_context.duplicate(true)


func _build_turn_plan(game_state: GameState, player_index: int, extra_context: Dictionary = {}) -> Dictionary:
	if deck_strategy == null:
		return {}
	if game_state == null:
		return {}
	var plan_context: Dictionary = extra_context.duplicate(true)
	var turn_contract: Dictionary = {}
	if deck_strategy.has_method("build_turn_contract"):
		turn_contract = deck_strategy.call("build_turn_contract", game_state, player_index, plan_context)
	elif deck_strategy.has_method("build_turn_plan"):
		turn_contract = deck_strategy.call("build_turn_plan", game_state, player_index, plan_context)
	var matchup_context: Dictionary = plan_context.get("matchup_context", {}) \
		if plan_context.get("matchup_context", {}) is Dictionary else {}
	if deck_strategy.has_method("apply_matchup_overlay_to_turn_contract"):
		turn_contract = deck_strategy.call(
			"apply_matchup_overlay_to_turn_contract",
			turn_contract,
			game_state,
			player_index,
			matchup_context
		)
	return turn_contract


func resolve_pending_step(
	battle_scene: Control,
	_gsm: GameStateMachine,
	player_index: int,
	state_features: Array[float] = []
) -> bool:
	if battle_scene == null:
		return false
	if str(battle_scene.get("_pending_choice")) != "effect_interaction":
		return false
	var steps: Array[Dictionary] = battle_scene.get("_pending_effect_steps")
	var step_index: int = int(battle_scene.get("_pending_effect_step_index"))
	if step_index < 0 or step_index >= steps.size():
		return false
	var step: Dictionary = steps[step_index]
	var chooser_player: int = int(battle_scene.call("_resolve_effect_step_chooser_player", step))
	if chooser_player != player_index:
		return false
	var interaction_context: Dictionary = battle_scene.get("_pending_effect_context")
	var pending_ability_index_variant: Variant = battle_scene.get("_pending_effect_ability_index")
	var pending_ability_index: int = int(pending_ability_index_variant) if pending_ability_index_variant != null else -1
	var strategy_context := {
		"game_state": _gsm.game_state if _gsm != null else null,
		"player_index": player_index,
		"pending_effect_kind": str(battle_scene.get("_pending_effect_kind")),
		"pending_effect_card": battle_scene.get("_pending_effect_card"),
		"pending_effect_slot": battle_scene.get("_pending_effect_slot"),
		"pending_effect_ability_index": pending_ability_index,
	}
	var matchup_context := _matchup_context.duplicate(true)
	if matchup_context.is_empty() and deck_strategy != null and deck_strategy.has_method("build_matchup_context"):
		var resolved_matchup: Variant = deck_strategy.call(
			"build_matchup_context",
			_gsm.game_state if _gsm != null else null,
			player_index
		)
		if resolved_matchup is Dictionary:
			matchup_context = (resolved_matchup as Dictionary).duplicate(true)
	strategy_context["matchup_context"] = matchup_context.duplicate(true)
	var turn_contract := _build_turn_plan(
		_gsm.game_state if _gsm != null else null,
		player_index,
		{
			"step_id": str(step.get("id", "")),
			"prompt_kind": "effect_interaction",
			"interaction_context": interaction_context,
			"matchup_context": matchup_context,
		}
	)
	strategy_context["turn_plan"] = turn_contract
	strategy_context["turn_contract"] = turn_contract
	var require_progress_evidence := battle_scene.has_method("_ai_effect_resolution_progress_token")
	var progress_before := (
		str(battle_scene.call("_ai_effect_resolution_progress_token"))
		if require_progress_evidence
		else ""
	)
	var handled := false
	if bool(battle_scene.call("_effect_step_uses_counter_distribution_ui", step)):
		handled = _resolve_counter_distribution_step(battle_scene, step, strategy_context, state_features)
	elif bool(battle_scene.call("_effect_step_uses_field_assignment_ui", step)):
		handled = _resolve_field_assignment_step(battle_scene, step, strategy_context, state_features)
	elif bool(battle_scene.call("_effect_step_uses_field_slot_ui", step)):
		handled = _resolve_field_slot_step(battle_scene, step, strategy_context, interaction_context, state_features)
	elif str(step.get("ui_mode", "")) == "card_assignment":
		handled = _resolve_dialog_assignment_step(battle_scene, step, strategy_context, state_features)
	else:
		handled = _resolve_dialog_step(battle_scene, step, strategy_context, interaction_context, state_features)
	if not handled or not require_progress_evidence:
		return handled
	var progress_after := str(battle_scene.call("_ai_effect_resolution_progress_token"))
	if progress_after != progress_before:
		return true
	return _abort_unresolvable_effect_step(
		battle_scene,
		step,
		"handler_reported_success_without_progress"
	)


func _resolve_dialog_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	interaction_context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var items: Array = step.get("items", [])
	var legal_pool: Dictionary = _build_legal_item_pool(items, step, interaction_context)
	var legal_items: Array = legal_pool.get("items", [])
	var legal_indices: Array = legal_pool.get("indices", [])
	var min_select: int = int(step.get("min_select", 1))
	var max_select: int = int(step.get("max_select", 1))
	if max_select <= 0:
		# Read-only galleries are a local presentation affordance, not an agent
		# decision in the official callback contract.
		battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())
		return true
	if not legal_items.is_empty() and deck_strategy != null and deck_strategy.has_method("pick_interaction_items"):
		var explicit: Dictionary = _pick_explicit_interaction_items_with_empty_support(
			legal_items, step, max_select, context
		)
		if bool(explicit.get("decision_pending", false)):
			return false
		if bool(explicit.get("has_plan", false)):
			var explicit_indices := PackedInt32Array()
			var seen_legal := {}
			for picked_item: Variant in explicit.get("items", []):
				var legal_idx: int = legal_items.find(picked_item)
				if legal_idx >= 0 and legal_idx < legal_indices.size() and not seen_legal.has(legal_idx):
					explicit_indices.append(int(legal_indices[legal_idx]))
					seen_legal[legal_idx] = true
			if explicit_indices.size() >= min_select and explicit_indices.size() <= max_select:
				battle_scene.call("_handle_effect_interaction_choice", explicit_indices)
				return true
	var selected_count: int = _baseline_pick_count(legal_items.size(), min_select, max_select)
	if legal_items.is_empty() or selected_count <= 0:
		if min_select > 0:
			return _abort_unresolvable_effect_step(
				battle_scene,
				step,
				"required_dialog_without_legal_items"
			)
		battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())
		return true
	var picked_legal_indices: PackedInt32Array = _pick_item_indices(
		legal_items,
		step,
		selected_count,
		context,
		state_features
	)
	var selected_indices := PackedInt32Array()
	for legal_index: int in picked_legal_indices:
		if legal_index >= 0 and legal_index < legal_indices.size():
			selected_indices.append(int(legal_indices[legal_index]))
	_record_interaction_decision(
		legal_items,
		step,
		context,
		state_features,
		picked_legal_indices,
		"dialog"
	)
	battle_scene.call("_handle_effect_interaction_choice", selected_indices)
	return true


func _resolve_field_slot_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	interaction_context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var initial_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var initial_step_id := str(step.get("id", ""))
	var items: Array = step.get("items", [])
	var legal_pool: Dictionary = _build_legal_item_pool(items, step, interaction_context)
	var legal_items: Array = legal_pool.get("items", [])
	var legal_indices: Array = legal_pool.get("indices", [])
	var min_select: int = int(step.get("min_select", 1))
	var max_select: int = int(step.get("max_select", 1))
	if not legal_items.is_empty() and deck_strategy != null \
			and deck_strategy.has_method("pick_interaction_items"):
		# Field-slot effects such as Prime Catcher's self switch are the same
		# immutable current-option contract as dialog interactions. Give an
		# explicit author policy the first legal proposal, then retain the
		# existing scorer as the audited fallback for classic strategies.
		var explicit: Dictionary = _pick_explicit_interaction_items_with_empty_support(
			legal_items, step, max_select, context
		)
		if bool(explicit.get("decision_pending", false)):
			return false
		if bool(explicit.get("has_plan", false)):
			var explicit_legal_indices := PackedInt32Array()
			var seen_legal := {}
			for picked_item: Variant in explicit.get("items", []):
				var legal_index: int = legal_items.find(picked_item)
				if legal_index >= 0 and legal_index < legal_indices.size() \
						and not seen_legal.has(legal_index):
					explicit_legal_indices.append(legal_index)
					seen_legal[legal_index] = true
			if explicit_legal_indices.size() >= min_select \
					and explicit_legal_indices.size() <= max_select:
				for legal_index: int in explicit_legal_indices:
					battle_scene.call(
						"_handle_field_slot_select_index", int(legal_indices[legal_index])
					)
				_record_interaction_decision(
					legal_items,
					step,
					context,
					state_features,
					explicit_legal_indices,
					"field_slot_explicit",
				)
				if (
					str(battle_scene.get("_field_interaction_mode")) == "slot_select"
					and _is_still_resolving_step(
						battle_scene, initial_step_index, initial_step_id
					)
				):
					battle_scene.call("_finalize_field_slot_selection")
				return true
	var selected_count: int = _baseline_pick_count(
		legal_items.size(),
		min_select,
		max_select
	)
	if legal_items.is_empty() or selected_count <= 0:
		if int(step.get("min_select", 1)) > 0:
			return _abort_unresolvable_effect_step(
				battle_scene,
				step,
				"required_field_slot_without_legal_items"
			)
		if str(battle_scene.get("_field_interaction_mode")) == "slot_select":
			battle_scene.call("_finalize_field_slot_selection")
		return true
	var picked_legal_indices: PackedInt32Array = _pick_item_indices(
		legal_items,
		step,
		selected_count,
		context,
		state_features
	)
	for legal_index: int in picked_legal_indices:
		if legal_index >= 0 and legal_index < legal_indices.size():
			battle_scene.call("_handle_field_slot_select_index", int(legal_indices[legal_index]))
	_record_interaction_decision(
		legal_items,
		step,
		context,
		state_features,
		picked_legal_indices,
		"field_slot"
	)
	if (
		str(battle_scene.get("_field_interaction_mode")) == "slot_select"
		and _is_still_resolving_step(battle_scene, initial_step_index, initial_step_id)
	):
		battle_scene.call("_finalize_field_slot_selection")
	return true


func _resolve_counter_distribution_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var total_counters: int = int(step.get("total_counters", 0))
	var target_items: Array = step.get("target_items", [])
	if total_counters <= 0:
		if battle_scene.has_method("_finalize_counter_distribution"):
			battle_scene.call("_finalize_counter_distribution")
		return true
	if target_items.is_empty():
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			"required_counter_distribution_without_targets"
		)
	if (
		deck_strategy != null
		and deck_strategy.has_method("uses_external_decision_port")
		and bool(deck_strategy.call("uses_external_decision_port"))
	):
		return _resolve_external_counter_distribution_step(
			battle_scene, step, context, target_items, total_counters, state_features
		)
	var assignments: Array[Dictionary] = _build_counter_distribution_assignments(
		target_items,
		total_counters,
		step,
		context,
		state_features
	)
	if assignments.is_empty():
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			"required_counter_distribution_without_assignments"
		)
	var picked := PackedInt32Array()
	for assignment: Dictionary in assignments:
		var target_index := int(assignment.get("target_index", -1))
		if target_index >= 0:
			picked.append(target_index)
	_record_interaction_decision(
		target_items,
		step,
		context,
		state_features,
		picked,
		"counter_distribution"
	)
	for assignment: Dictionary in assignments:
		var target_index := int(assignment.get("target_index", -1))
		var counters := int(assignment.get("counters", 0))
		if target_index < 0 or counters <= 0:
			continue
		battle_scene.call("_on_counter_distribution_amount_chosen", counters)
		battle_scene.call("_handle_counter_distribution_target", target_index)
	return true


func _resolve_external_counter_distribution_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary,
	target_items: Array,
	total_counters: int,
	state_features: Array[float] = []
) -> bool:
	var entries: Array = battle_scene.get("_field_interaction_assignment_entries")
	var assigned := 0
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			assigned += maxi(0, int((entry_value as Dictionary).get("amount", 0)) / 10)
	var remaining := total_counters - assigned
	if remaining <= 0:
		if battle_scene.has_method("_finalize_counter_distribution"):
			battle_scene.call("_finalize_counter_distribution")
		return true
	var max_assignments := int(step.get("max_assignments", 0))
	if max_assignments > 0 and entries.size() >= max_assignments:
		if bool(step.get("allow_partial", false)):
			battle_scene.call("_finalize_counter_distribution")
			return true
		return _abort_unresolvable_effect_step(
			battle_scene, step, "required_counter_distribution_assignment_limit"
		)
	var count_window_metadata: Dictionary = step.get("ucis_counter_count_window", {})
	var target_window_metadata: Dictionary = step.get("ucis_counter_target_window", {})
	var uses_count_then_target_windows := (
		not count_window_metadata.is_empty()
		and not target_window_metadata.is_empty()
	)
	var selected_amount := int(
		battle_scene.get("_field_interaction_assignment_selected_source_index")
	)
	if uses_count_then_target_windows and selected_amount <= 0:
		var count_items: Array = []
		for count: int in range(1, remaining + 1):
			count_items.append({"number": count})
		var count_step := step.duplicate(true)
		count_step.erase("__ucis")
		count_step["ui_mode"] = ""
		count_step["items"] = count_items
		count_step["min_select"] = 1
		count_step["max_select"] = 1
		for metadata_key: Variant in count_window_metadata:
			count_step[metadata_key] = count_window_metadata[metadata_key]
		count_step = _compile_derived_ucis_step(count_step, "counter_count")
		if count_step.is_empty():
			return _abort_unresolvable_effect_step(
				battle_scene, step, "ucis_counter_count_compile_failed"
			)
		var count_plan: Dictionary = _pick_explicit_interaction_items_with_empty_support(
			count_items, count_step, 1, context
		)
		if bool(count_plan.get("decision_pending", false)):
			return false
		if not bool(count_plan.get("has_plan", false)):
			return false
		var selected_counts: Array = count_plan.get("items", [])
		if selected_counts.size() != 1:
			return _abort_unresolvable_effect_step(
				battle_scene, step, "counter_distribution_count_cardinality_invalid"
			)
		var selected_count_item: Variant = selected_counts[0]
		var count_index := count_items.find(selected_count_item)
		if count_index < 0 or not (selected_count_item is Dictionary):
			return _abort_unresolvable_effect_step(
				battle_scene, step, "counter_distribution_count_rebind_failed"
			)
		var chosen_count := int((selected_count_item as Dictionary).get("number", 0))
		if chosen_count < 1 or chosen_count > remaining:
			return _abort_unresolvable_effect_step(
				battle_scene, step, "counter_distribution_count_out_of_range"
			)
		_record_interaction_decision(
			count_items,
			count_step,
			context,
			state_features,
			PackedInt32Array([count_index]),
			"counter_distribution_count"
		)
		battle_scene.call("_on_counter_distribution_amount_chosen", chosen_count)
		return true
	if uses_count_then_target_windows and selected_amount > remaining:
		return _abort_unresolvable_effect_step(
			battle_scene, step, "counter_distribution_selected_count_became_illegal"
		)
	var legal_items: Array = []
	var source_indexes: Array[int] = []
	var max_per_target := int(step.get("max_assignments_per_target", 0))
	for target_index: int in target_items.size():
		var target: Variant = target_items[target_index]
		if not (target is PokemonSlot) or (target as PokemonSlot).get_top_card() == null:
			continue
		var prior_count := 0
		for entry_value: Variant in entries:
			if entry_value is Dictionary \
					and int((entry_value as Dictionary).get("target_index", -1)) == target_index:
				prior_count += 1
		if max_per_target > 0 and prior_count >= max_per_target:
			continue
		legal_items.append(target)
		source_indexes.append(target_index)
	if legal_items.is_empty():
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			"required_counter_distribution_without_legal_target"
		)
	var window_step := step.duplicate(true)
	window_step.erase("__ucis")
	window_step["ui_mode"] = ""
	window_step["min_select"] = 1
	window_step["max_select"] = 1
	if uses_count_then_target_windows:
		for metadata_key: Variant in target_window_metadata:
			window_step[metadata_key] = target_window_metadata[metadata_key]
	else:
		window_step["ucis_context_name"] = "DAMAGE_COUNTER_ANY"
		window_step["ucis_remain_damage_counter"] = remaining
	window_step = _compile_derived_ucis_step(window_step, "counter_target")
	if window_step.is_empty():
		return _abort_unresolvable_effect_step(
			battle_scene, step, "ucis_counter_target_compile_failed"
		)
	var target_plan: Dictionary = _pick_explicit_interaction_items_with_empty_support(
		legal_items, window_step, 1, context
	)
	if bool(target_plan.get("decision_pending", false)):
		return false
	if not bool(target_plan.get("has_plan", false)):
		return false
	var selected: Array = target_plan.get("items", [])
	if selected.size() != 1:
		return _abort_unresolvable_effect_step(
			battle_scene, step, "counter_distribution_target_cardinality_invalid"
		)
	var local_index := legal_items.find(selected[0])
	if local_index < 0 or local_index >= source_indexes.size():
		return _abort_unresolvable_effect_step(
			battle_scene, step, "counter_distribution_target_rebind_failed"
		)
	# Generic CABT DamageCounterAny effects publish one fresh target window per
	# counter. Munkidori first publishes NUMBER/REMOVE_DAMAGE_COUNTER_COUNT and
	# carries that accepted amount into its fresh CARD/DAMAGE_COUNTER target.
	if not uses_count_then_target_windows:
		battle_scene.call("_on_counter_distribution_amount_chosen", 1)
	_record_interaction_decision(
		legal_items,
		window_step,
		context,
		state_features,
		PackedInt32Array([local_index]),
		"counter_distribution_target"
	)
	battle_scene.call("_handle_counter_distribution_target", source_indexes[local_index])
	return true


func _compile_derived_ucis_step(step: Dictionary, entrypoint: String) -> Dictionary:
	var compiled := UcisCompilerScript.compile_steps([step], entrypoint, self)
	if not bool(compiled.get("ok", false)):
		return {}
	var steps: Array = compiled.get("steps", [])
	return (steps[0] as Dictionary) if steps.size() == 1 and steps[0] is Dictionary else {}


func _build_counter_distribution_assignments(
	target_items: Array,
	total_counters: int,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> Array[Dictionary]:
	if total_counters <= 0 or target_items.is_empty():
		return []
	var candidates: Array[Dictionary] = []
	for i: int in target_items.size():
		var item: Variant = target_items[i]
		if not (item is PokemonSlot):
			continue
		var slot := item as PokemonSlot
		var remaining_hp := _effective_remaining_hp(slot, context)
		if slot.get_top_card() == null or remaining_hp <= 0:
			continue
		var counters_needed := int(ceil(float(remaining_hp) / 10.0))
		candidates.append({
			"index": i,
			"slot": slot,
			"counters_needed": counters_needed,
			"score": _score_interaction_candidate(slot, step, context, state_features),
			"prizes": slot.get_prize_count(),
		})
	if candidates.is_empty():
		return []

	var max_assignments: int = int(step.get("max_assignments", 0))
	if max_assignments == 1:
		return _build_single_counter_distribution_assignment(candidates, target_items, total_counters, step)

	var remaining := total_counters
	var allocations: Dictionary = {}
	var knocked_out: Dictionary = {}
	var ko_candidates := candidates.duplicate(true)
	ko_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var value_a := float(a.get("score", 0.0)) + float(a.get("prizes", 1)) * 520.0 - float(a.get("counters_needed", 99)) * 35.0
		var value_b := float(b.get("score", 0.0)) + float(b.get("prizes", 1)) * 520.0 - float(b.get("counters_needed", 99)) * 35.0
		if is_equal_approx(value_a, value_b):
			var need_a := int(a.get("counters_needed", 99))
			var need_b := int(b.get("counters_needed", 99))
			if need_a == need_b:
				return int(a.get("index", -1)) < int(b.get("index", -1))
			return need_a < need_b
		return value_a > value_b
	)
	for candidate: Dictionary in ko_candidates:
		var target_index := int(candidate.get("index", -1))
		var counters_needed := int(candidate.get("counters_needed", 99))
		if counters_needed <= 0 or counters_needed > remaining:
			continue
		allocations[target_index] = int(allocations.get(target_index, 0)) + counters_needed
		knocked_out[target_index] = true
		remaining -= counters_needed
		if remaining <= 0:
			break

	if remaining > 0:
		var pressure_target: Dictionary = {}
		for candidate: Dictionary in candidates:
			var target_index := int(candidate.get("index", -1))
			if knocked_out.has(target_index) and candidates.size() > knocked_out.size():
				continue
			if pressure_target.is_empty() or _counter_pressure_value(candidate) > _counter_pressure_value(pressure_target):
				pressure_target = candidate
		if not pressure_target.is_empty():
			var target_index := int(pressure_target.get("index", -1))
			allocations[target_index] = int(allocations.get(target_index, 0)) + remaining

	var result: Array[Dictionary] = []
	for target_index_variant: Variant in allocations.keys():
		var target_index := int(target_index_variant)
		var counters := int(allocations.get(target_index, 0))
		if counters <= 0:
			continue
		result.append({
			"target_index": target_index,
			"target": target_items[target_index],
			"counters": counters,
			"amount": counters * 10,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("target_index", -1)) < int(b.get("target_index", -1))
	)
	return result


func _effective_remaining_hp(slot: PokemonSlot, context: Dictionary) -> int:
	if slot == null:
		return 0
	var state: Variant = context.get("game_state", null)
	if state is GameState:
		var processor: Variant = (state as GameState).shared_turn_flags.get(
			"_draw_effect_processor", null
		)
		if processor != null and processor.has_method("get_effective_remaining_hp"):
			return int(processor.call("get_effective_remaining_hp", slot, state))
	return slot.get_remaining_hp()


func _build_single_counter_distribution_assignment(
	candidates: Array[Dictionary],
	target_items: Array,
	total_counters: int,
	step: Dictionary
) -> Array[Dictionary]:
	if total_counters <= 0 or candidates.is_empty():
		return []
	var allow_partial := bool(step.get("allow_partial", false))
	var best_target: Dictionary = {}
	var best_is_ko := false
	for candidate: Dictionary in candidates:
		var counters_needed := int(candidate.get("counters_needed", 99))
		var can_ko := counters_needed > 0 and counters_needed <= total_counters
		if best_target.is_empty():
			best_target = candidate
			best_is_ko = can_ko
			continue
		if can_ko != best_is_ko:
			if can_ko:
				best_target = candidate
				best_is_ko = true
			continue
		if can_ko:
			var current_value := float(candidate.get("score", 0.0)) + float(candidate.get("prizes", 1)) * 520.0 - float(counters_needed) * 35.0
			var best_needed := int(best_target.get("counters_needed", 99))
			var best_value := float(best_target.get("score", 0.0)) + float(best_target.get("prizes", 1)) * 520.0 - float(best_needed) * 35.0
			if current_value > best_value or (is_equal_approx(current_value, best_value) and counters_needed < best_needed):
				best_target = candidate
		elif _counter_pressure_value(candidate) > _counter_pressure_value(best_target):
			best_target = candidate
	if best_target.is_empty():
		return []
	var target_index := int(best_target.get("index", -1))
	if target_index < 0 or target_index >= target_items.size():
		return []
	var counters := total_counters
	var counters_needed_for_ko := int(best_target.get("counters_needed", 99))
	if allow_partial and counters_needed_for_ko > 0 and counters_needed_for_ko <= total_counters:
		counters = counters_needed_for_ko
	return [{
		"target_index": target_index,
		"target": target_items[target_index],
		"counters": counters,
		"amount": counters * 10,
	}]


func _counter_pressure_value(candidate: Dictionary) -> float:
	return float(candidate.get("score", 0.0)) + float(candidate.get("prizes", 1)) * 160.0 - float(candidate.get("counters_needed", 99)) * 10.0


func _resolve_field_assignment_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var initial_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var initial_step_id := str(step.get("id", ""))
	var plan_key := _assignment_plan_key(battle_scene, step, "field")
	var existing_value: Variant = battle_scene.get("_field_interaction_assignment_entries")
	var existing_assignments: Array = existing_value if existing_value is Array else []
	var assignment_plan: Dictionary = _build_assignment_source_plan(
		step.get("source_items", []),
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step,
		context,
		state_features,
		plan_key,
		existing_assignments
	)
	if bool(assignment_plan.get("decision_pending", false)):
		return false
	if bool(assignment_plan.get("unresolvable", false)):
		_clear_external_assignment_plan(plan_key)
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			str(assignment_plan.get("reason", "external_assignment_source_rebind_failed"))
		)
	var assignments_made: int = _assign_sources_to_targets(
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step.get("source_items", []),
		step.get("target_items", []),
		step.get("source_exclude_targets", {}),
		func(source_index: int, target_index: int) -> void:
			battle_scene.call("_on_field_assignment_source_chosen", source_index)
			battle_scene.call("_handle_field_assignment_target_index", target_index),
		step,
		context,
		state_features,
		assignment_plan
	)
	if assignments_made < 0:
		return false
	if bool(assignment_plan.get("external_sequential", false)):
		if bool(assignment_plan.get("sequential_complete", false)):
			_clear_external_assignment_plan(plan_key)
			if (
				str(battle_scene.get("_field_interaction_mode")) == "assignment"
				and _is_still_resolving_step(battle_scene, initial_step_index, initial_step_id)
			):
				battle_scene.call("_finalize_field_assignment_selection")
			return true
		if assignments_made > 0:
			return true
	if assignments_made <= 0 and not bool(assignment_plan.get("handled", false)):
		_clear_external_assignment_plan(plan_key)
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			"required_field_assignment_without_targets"
		)
	if (
		str(battle_scene.get("_field_interaction_mode")) == "assignment"
		and _is_still_resolving_step(battle_scene, initial_step_index, initial_step_id)
	):
		battle_scene.call("_finalize_field_assignment_selection")
	return true


func _resolve_dialog_assignment_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var plan_key := _assignment_plan_key(battle_scene, step, "dialog")
	var existing_value: Variant = battle_scene.get("_dialog_assignment_assignments")
	var existing_assignments: Array = existing_value if existing_value is Array else []
	var assignment_plan: Dictionary = _build_assignment_source_plan(
		step.get("source_items", []),
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step,
		context,
		state_features,
		plan_key,
		existing_assignments
	)
	if bool(assignment_plan.get("decision_pending", false)):
		return false
	if bool(assignment_plan.get("unresolvable", false)):
		_clear_external_assignment_plan(plan_key)
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			str(assignment_plan.get("reason", "external_assignment_source_rebind_failed"))
		)
	var assignments_made: int = _assign_sources_to_targets(
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step.get("source_items", []),
		step.get("target_items", []),
		step.get("source_exclude_targets", {}),
		func(source_index: int, target_index: int) -> void:
			battle_scene.call("_on_assignment_source_chosen", source_index)
			battle_scene.call("_on_assignment_target_chosen", target_index),
		step,
		context,
		state_features,
		assignment_plan
	)
	if assignments_made < 0:
		return false
	if bool(assignment_plan.get("external_sequential", false)):
		if bool(assignment_plan.get("sequential_complete", false)):
			_clear_external_assignment_plan(plan_key)
			battle_scene.call("_confirm_assignment_dialog")
			return true
		if assignments_made > 0:
			return true
	if assignments_made <= 0 and not bool(assignment_plan.get("handled", false)):
		_clear_external_assignment_plan(plan_key)
		return _abort_unresolvable_effect_step(
			battle_scene,
			step,
			"required_assignment_without_targets"
		)
	battle_scene.call("_confirm_assignment_dialog")
	return true


func _abort_unresolvable_effect_step(battle_scene: Control, step: Dictionary, reason: String) -> bool:
	if battle_scene == null:
		return false
	_clear_external_assignment_plans_for_scene(battle_scene)
	if battle_scene.has_method("_runtime_log"):
		battle_scene.call(
			"_runtime_log",
			"effect_step_unresolvable",
			"step=%s reason=%s" % [str(step.get("id", "")), reason]
		)
	if battle_scene.has_method("_reset_effect_interaction"):
		battle_scene.call("_reset_effect_interaction")
	else:
		battle_scene.set("_pending_choice", "")
	var reconciled_authoritative := false
	if battle_scene.has_method("_ai_watchdog_reconcile_authoritative_decision"):
		reconciled_authoritative = bool(battle_scene.call("_ai_watchdog_reconcile_authoritative_decision"))
	if battle_scene.has_method("_refresh_ui"):
		battle_scene.call("_refresh_ui")
	if not reconciled_authoritative and battle_scene.has_method("_maybe_run_ai"):
		battle_scene.call("_maybe_run_ai")
	return true


func _is_still_resolving_step(battle_scene: Control, initial_step_index: int, initial_step_id: String) -> bool:
	if battle_scene == null:
		return false
	var current_step_index := int(battle_scene.get("_pending_effect_step_index"))
	if current_step_index != initial_step_index:
		return false
	var steps: Array = battle_scene.get("_pending_effect_steps")
	if current_step_index < 0 or current_step_index >= steps.size():
		return false
	var current_step: Variant = steps[current_step_index]
	if not (current_step is Dictionary):
		return false
	return str((current_step as Dictionary).get("id", "")) == initial_step_id


func _build_assignment_source_plan(
	source_items: Array,
	min_assignments: int,
	max_assignments: int,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = [],
	plan_key: String = "",
	existing_assignments: Array = []
) -> Dictionary:
	var uses_external_port := _uses_external_decision_port()
	if uses_external_port and not plan_key.is_empty() and _external_assignment_plans.has(plan_key):
		var stored_plan: Dictionary = _external_assignment_plans[plan_key]
		var source_refs: Array = stored_plan.get("source_refs", [])
		var cursor: int = int(stored_plan.get("cursor", 0))
		if cursor >= source_refs.size():
			return {
				"handled": true,
				"has_explicit_plan": true,
				"selected_source_indices": [],
				"external_sequential": true,
				"sequential_complete": true,
				"plan_key": plan_key,
				"existing_assignments": existing_assignments,
			}
		var rebound_index := _find_assignment_item_index(source_items, source_refs[cursor])
		if rebound_index < 0:
			return {
				"handled": false,
				"has_explicit_plan": true,
				"selected_source_indices": [],
				"external_sequential": true,
				"unresolvable": true,
				"reason": "external_assignment_source_rebind_failed",
				"plan_key": plan_key,
			}
		return {
			"handled": true,
			"has_explicit_plan": true,
			"selected_source_indices": [rebound_index],
			"external_sequential": true,
			"sequential_complete": false,
			"plan_key": plan_key,
			"existing_assignments": existing_assignments,
		}
	var explicit_plan: Dictionary = _pick_explicit_interaction_items_with_empty_support(
		source_items,
		step,
		max_assignments,
		context
	)
	if bool(explicit_plan.get("decision_pending", false)):
		return {
			"handled": false,
			"has_explicit_plan": false,
			"selected_source_indices": [],
			"decision_pending": true,
		}
	if bool(explicit_plan.get("has_plan", false)):
		var selected_items: Array = explicit_plan.get("items", [])
		var selected_indices: Array[int] = []
		for wanted: Variant in selected_items:
			var source_index: int = source_items.find(wanted)
			if source_index >= 0 and not selected_indices.has(source_index):
				selected_indices.append(source_index)
		if uses_external_port and not plan_key.is_empty():
			var source_refs: Array[Dictionary] = []
			for source_index: int in selected_indices:
				source_refs.append(_assignment_item_reference(source_items, source_index))
			_external_assignment_plans[plan_key] = {
				"source_refs": source_refs,
				"cursor": 0,
			}
			if selected_indices.is_empty():
				return {
					"handled": min_assignments <= 0,
					"has_explicit_plan": true,
					"selected_source_indices": [],
					"external_sequential": true,
					"sequential_complete": true,
					"plan_key": plan_key,
					"existing_assignments": existing_assignments,
				}
			return {
				"handled": true,
				"has_explicit_plan": true,
				"selected_source_indices": [selected_indices[0]],
				"external_sequential": true,
				"sequential_complete": false,
				"plan_key": plan_key,
				"existing_assignments": existing_assignments,
			}
		if selected_indices.is_empty():
			return {
				"handled": min_assignments <= 0,
				"has_explicit_plan": true,
				"selected_source_indices": selected_indices,
			}
		return {
			"handled": true,
			"has_explicit_plan": true,
			"selected_source_indices": selected_indices,
		}
	return {
		"handled": false,
		"has_explicit_plan": false,
		"selected_source_indices": [],
		"selected_count": _baseline_pick_count(source_items.size(), min_assignments, max_assignments),
	}


func _assign_sources_to_targets(
	min_assignments: int,
	max_assignments: int,
	source_items: Array,
	target_items: Array,
	source_exclude_targets: Dictionary,
	apply_assignment: Callable,
	step: Dictionary = {},
	context: Dictionary = {},
	state_features: Array[float] = [],
	assignment_plan: Dictionary = {}
) -> int:
	if source_items.is_empty() or target_items.is_empty() or not apply_assignment.is_valid():
		return 0
	var explicit_source_indices: Array = assignment_plan.get("selected_source_indices", [])
	var has_explicit_plan: bool = bool(assignment_plan.get("has_explicit_plan", false))
	var target_assignment_count: int = explicit_source_indices.size() if has_explicit_plan else int(assignment_plan.get("selected_count", _baseline_pick_count(source_items.size(), min_assignments, max_assignments)))
	if target_assignment_count <= 0:
		return 0
	var assignments_made: int = 0
	var picked_targets := PackedInt32Array()
	var pending_assignment_counts: Dictionary = {}
	var pending_assignments: Array[Dictionary] = []
	var existing_assignments: Array = assignment_plan.get("existing_assignments", [])
	for existing_assignment_variant: Variant in existing_assignments:
		if not (existing_assignment_variant is Dictionary):
			continue
		var existing_assignment: Dictionary = existing_assignment_variant
		pending_assignments.append(existing_assignment.duplicate(true))
		var existing_target: Variant = existing_assignment.get("target")
		var existing_target_key := _assignment_value_key(existing_target)
		pending_assignment_counts[existing_target_key] = int(
			pending_assignment_counts.get(existing_target_key, 0)
		) + 1
	var source_indices: Array = explicit_source_indices if has_explicit_plan else range(source_items.size())
	var max_assignments_per_target := int(step.get("max_assignments_per_target", 0))
	var single_target_only := bool(step.get("single_target_only", false))
	var locked_target_index := -1
	if single_target_only and not pending_assignments.is_empty():
		locked_target_index = _find_assignment_value_index(
			target_items,
			pending_assignments[0].get("target")
		)
		if locked_target_index < 0:
			assignment_plan["unresolvable"] = true
			assignment_plan["reason"] = "external_assignment_target_rebind_failed"
			return 0
	for source_index_variant: Variant in source_indices:
		var source_index: int = int(source_index_variant)
		if assignments_made >= target_assignment_count:
			break
		var excluded_targets: Array = (source_exclude_targets.get(source_index, []) as Array).duplicate()
		if single_target_only and locked_target_index >= 0:
			for target_index: int in target_items.size():
				if target_index != locked_target_index and not (target_index in excluded_targets):
					excluded_targets.append(target_index)
		if max_assignments_per_target > 0:
			for target_index: int in target_items.size():
				var candidate: Variant = target_items[target_index]
				var candidate_key := _assignment_value_key(candidate)
				if int(pending_assignment_counts.get(candidate_key, 0)) >= max_assignments_per_target and not (target_index in excluded_targets):
					excluded_targets.append(target_index)
		var assignment_context: Dictionary = context.duplicate(true)
		assignment_context["assignment_source"] = source_items[source_index]
		assignment_context["assignment_source_index"] = source_index
		assignment_context["source_card"] = source_items[source_index]
		assignment_context["pending_assignment_counts"] = pending_assignment_counts.duplicate()
		assignment_context["pending_assignments"] = pending_assignments.duplicate(true)
		var chosen_target_index: int = _best_legal_target_index(
			target_items,
			excluded_targets,
			step,
			assignment_context,
			state_features
		)
		if chosen_target_index == -2:
			return -1
		if chosen_target_index < 0:
			continue
		apply_assignment.call(source_index, chosen_target_index)
		if single_target_only and locked_target_index < 0:
			locked_target_index = chosen_target_index
		picked_targets.append(chosen_target_index)
		var chosen_target: Variant = target_items[chosen_target_index]
		var target_key := _assignment_value_key(chosen_target)
		pending_assignment_counts[target_key] = int(pending_assignment_counts.get(target_key, 0)) + 1
		pending_assignments.append({
			"source": source_items[source_index],
			"target": chosen_target,
		})
		assignments_made += 1
		if bool(assignment_plan.get("external_sequential", false)):
			var plan_key := str(assignment_plan.get("plan_key", ""))
			if not plan_key.is_empty() and _external_assignment_plans.has(plan_key):
				var stored_plan: Dictionary = _external_assignment_plans[plan_key]
				stored_plan["cursor"] = int(stored_plan.get("cursor", 0)) + 1
				_external_assignment_plans[plan_key] = stored_plan
				assignment_plan["sequential_complete"] = int(stored_plan["cursor"]) >= (stored_plan.get("source_refs", []) as Array).size()
		_record_interaction_decision(
			target_items,
			step,
			assignment_context,
			state_features,
			PackedInt32Array([chosen_target_index]),
			"assignment"
		)
	return assignments_made


func _uses_external_decision_port() -> bool:
	return (
		deck_strategy != null
		and deck_strategy.has_method("uses_external_decision_port")
		and bool(deck_strategy.call("uses_external_decision_port"))
	)


func _assignment_plan_key(battle_scene: Control, step: Dictionary, mode: String) -> String:
	if battle_scene == null:
		return ""
	return "%d|%s|%d|%s" % [
		int(battle_scene.get_instance_id()),
		mode,
		int(battle_scene.get("_pending_effect_step_index")),
		str(step.get("id", "")),
	]


func _assignment_value_key(value: Variant) -> String:
	if value is Object:
		return "object:%d" % int((value as Object).get_instance_id())
	return "value:%d:%s" % [typeof(value), var_to_str(value)]


func _assignment_item_reference(items: Array, item_index: int) -> Dictionary:
	if item_index < 0 or item_index >= items.size():
		return {}
	var key := _assignment_value_key(items[item_index])
	var occurrence := 0
	for index: int in item_index:
		if _assignment_value_key(items[index]) == key:
			occurrence += 1
	return {"key": key, "occurrence": occurrence}


func _find_assignment_item_index(items: Array, reference: Variant) -> int:
	if not (reference is Dictionary):
		return -1
	var wanted_key := str((reference as Dictionary).get("key", ""))
	var wanted_occurrence := int((reference as Dictionary).get("occurrence", 0))
	var occurrence := 0
	for index: int in items.size():
		if _assignment_value_key(items[index]) != wanted_key:
			continue
		if occurrence == wanted_occurrence:
			return index
		occurrence += 1
	return -1


func _find_assignment_value_index(items: Array, value: Variant) -> int:
	var wanted_key := _assignment_value_key(value)
	for index: int in items.size():
		if _assignment_value_key(items[index]) == wanted_key:
			return index
	return -1


func _clear_external_assignment_plan(plan_key: String) -> void:
	if not plan_key.is_empty():
		_external_assignment_plans.erase(plan_key)


func _clear_external_assignment_plans_for_scene(battle_scene: Control) -> void:
	if battle_scene == null:
		return
	var prefix := "%d|" % int(battle_scene.get_instance_id())
	for plan_key_variant: Variant in _external_assignment_plans.keys():
		var plan_key := str(plan_key_variant)
		if plan_key.begins_with(prefix):
			_external_assignment_plans.erase(plan_key)


func _pick_explicit_interaction_items_with_empty_support(
	items: Array,
	step: Dictionary,
	max_select: int,
	context: Dictionary = {}
) -> Dictionary:
	if deck_strategy == null or not deck_strategy.has_method("pick_interaction_items"):
		return {"has_plan": false, "items": []}
	var public_step := step.duplicate(true)
	public_step["max_select"] = max_select
	var planned: Variant = deck_strategy.call("pick_interaction_items", items, public_step, context)
	if (
		deck_strategy.has_method("has_pending_external_decision")
		and bool(deck_strategy.call("has_pending_external_decision"))
	):
		return {"has_plan": false, "items": [], "decision_pending": true}
	if not (planned is Array):
		return {"has_plan": false, "items": []}
	var planned_items: Array = planned
	if not planned_items.is_empty():
		return {"has_plan": true, "items": planned_items}
	if _should_preserve_empty_interaction_selection(step, context):
		return {"has_plan": true, "items": []}
	return {"has_plan": false, "items": []}


func _should_preserve_empty_interaction_selection(step: Dictionary, context: Dictionary = {}) -> bool:
	if deck_strategy == null or not deck_strategy.has_method("should_preserve_empty_interaction_selection"):
		return false
	return bool(deck_strategy.call("should_preserve_empty_interaction_selection", step, context))


func _first_legal_target_index(target_count: int, excluded_targets: Array) -> int:
	for target_index: int in target_count:
		if target_index in excluded_targets:
			continue
		return target_index
	return -1


func _best_legal_target_index(
	target_items: Array,
	excluded_targets: Array,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> int:
	if target_items.is_empty():
		return -1
	if deck_strategy != null and deck_strategy.has_method("pick_interaction_target_index"):
		var planned: Variant = deck_strategy.call(
			"pick_interaction_target_index",
			target_items,
			excluded_targets.duplicate(),
			step.duplicate(true),
			context.duplicate(true)
		)
		if (
			deck_strategy.has_method("has_pending_external_decision")
			and bool(deck_strategy.call("has_pending_external_decision"))
		):
			return -2
		if (
			typeof(planned) == TYPE_INT
			and int(planned) >= 0
			and int(planned) < target_items.size()
			and int(planned) not in excluded_targets
		):
			return int(planned)
	var best_index: int = -1
	var best_score: float = -INF
	for i: int in target_items.size():
		if i in excluded_targets:
			continue
		var score: float = _score_interaction_candidate(target_items[i], step, context, state_features)
		if best_index < 0 or score > best_score:
			best_index = i
			best_score = score
	if best_index < 0:
		return _first_legal_target_index(target_items.size(), excluded_targets)
	return best_index


func _pick_item_indices(
	items: Array,
	step: Dictionary,
	selected_count: int,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if items.is_empty() or selected_count <= 0:
		return result
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		scored.append({
			"index": i,
			"score": _score_interaction_candidate(items[i], step, context, state_features),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("score", 0.0))
		var score_b: float = float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", -1)) < int(b.get("index", -1))
		return score_a > score_b
	)
	for i: int in mini(selected_count, scored.size()):
		result.append(int(scored[i].get("index", -1)))
	return result


func _score_interaction_candidate(
	item: Variant,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> float:
	var strategy_score: float = _score_strategy_target(item, step, context)
	var learned_score: float = _score_with_interaction_scorer(item, step, context, state_features, strategy_score)
	return strategy_score + learned_score


func _score_with_interaction_scorer(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	state_features: Array[float],
	strategy_score: float
) -> float:
	if interaction_scorer == null or not interaction_scorer.has_method("score_delta"):
		return 0.0
	var feature_context := _build_interaction_feature_context(context, strategy_score)
	var interaction_vector: Array[float] = _interaction_feature_encoder.build_vector(item, step, feature_context)
	return float(interaction_scorer.call("score_delta", state_features, interaction_vector))


func _build_interaction_feature_context(context: Dictionary, strategy_score: float) -> Dictionary:
	var feature_context: Dictionary = context.duplicate(true)
	feature_context["strategy_score"] = strategy_score
	return feature_context


func _record_interaction_decision(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	state_features: Array[float],
	chosen_indices: PackedInt32Array,
	resolution_kind: String
) -> void:
	if decision_exporter == null or not decision_exporter.has_method("record_interaction_decision"):
		return
	var candidates: Array[Dictionary] = []
	for item_index: int in items.size():
		var item_context: Dictionary = context.duplicate(true)
		item_context["all_items"] = items
		var strategy_score: float = _score_strategy_target(items[item_index], step, item_context)
		var feature_context := _build_interaction_feature_context(context, strategy_score)
		feature_context["all_items"] = items
		var interaction_features: Dictionary = _interaction_feature_encoder.build_features(items[item_index], step, feature_context)
		candidates.append({
			"index": item_index,
			"chosen": item_index in chosen_indices,
			"item_name": _item_name(items[item_index]),
			"strategy_score": strategy_score,
			"interaction_features": interaction_features,
			"interaction_vector": _interaction_feature_encoder.build_vector(items[item_index], step, feature_context),
		})
	decision_exporter.call("record_interaction_decision", {
		"player_index": int(context.get("player_index", -1)),
		"turn_number": int(context.get("game_state").turn_number if context.get("game_state", null) != null else -1),
		"state_features": state_features,
		"resolution_kind": resolution_kind,
		"step_id": str(step.get("id", "")),
		"step_type": str(step.get("type", step.get("ui_mode", ""))),
		"step_label": str(step.get("title", step.get("prompt", ""))),
		"candidates": candidates,
		"chosen_indices": Array(chosen_indices),
		"deck_strategy_id": str(deck_strategy.call("get_strategy_id")) \
			if deck_strategy != null and deck_strategy.has_method("get_strategy_id") else "",
		"matchup_context": context.get("matchup_context", {}).duplicate(true) \
			if context.get("matchup_context", {}) is Dictionary else {},
	})


func _score_strategy_target(
	item: Variant,
	step: Dictionary,
	context: Dictionary = {}
) -> float:
	if deck_strategy == null:
		return 0.0
	var score_context: Dictionary = context.duplicate(true)
	score_context["all_items"] = context.get("all_items", [])
	var score := AIHandoffScoringScript.score_strategy_target(deck_strategy, item, step, score_context)
	var matchup_context: Dictionary = score_context.get("matchup_context", {}) \
		if score_context.get("matchup_context", {}) is Dictionary else {}
	if bool(matchup_context.get("is_unique", false)) \
			and deck_strategy.has_method("score_matchup_interaction_target"):
		score += float(deck_strategy.call(
			"score_matchup_interaction_target",
			item,
			step,
			score_context,
			matchup_context
		))
	return score


func _item_name(item: Variant) -> String:
	if item is CardInstance and (item as CardInstance).card_data != null:
		return str((item as CardInstance).card_data.name)
	if item is PokemonSlot:
		return (item as PokemonSlot).get_pokemon_name()
	if item == null:
		return ""
	return str(item)


func _baseline_pick_count(item_count: int, min_select: int, max_select: int) -> int:
	if item_count <= 0:
		return 0
	var target_count: int = item_count
	if max_select > 0:
		target_count = mini(target_count, max_select)
	if min_select > 0:
		target_count = maxi(target_count, min_select)
	return clampi(target_count, 1, item_count)


func _build_legal_item_pool(items: Array, step: Dictionary, interaction_context: Dictionary) -> Dictionary:
	var legal_items: Array = []
	var legal_indices: Array = []
	var excluded_items: Array = _collect_excluded_step_items(step, interaction_context)
	for index: int in items.size():
		var item: Variant = items[index]
		if item in excluded_items:
			continue
		legal_items.append(item)
		legal_indices.append(index)
	return {
		"items": legal_items,
		"indices": legal_indices,
	}


func _collect_excluded_step_items(step: Dictionary, interaction_context: Dictionary) -> Array:
	if interaction_context.is_empty():
		return []
	var excluded: Array = []
	var step_ids: Array[String] = []
	var single_step_id: String = str(step.get("exclude_selected_from_step_id", "")).strip_edges()
	if single_step_id != "":
		step_ids.append(single_step_id)
	for key_variant: Variant in step.get("exclude_selected_from_step_ids", []):
		var key: String = str(key_variant).strip_edges()
		if key != "" and not step_ids.has(key):
			step_ids.append(key)
	for step_id: String in step_ids:
		var selected_items: Variant = interaction_context.get(step_id, [])
		if not selected_items is Array:
			continue
		for item: Variant in selected_items:
			if not excluded.has(item):
				excluded.append(item)
	return excluded
