class_name BattleEffectInteractionController
extends RefCounted


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func start_effect_interaction(
	scene: Object,
	kind: String,
	player_index: int,
	steps: Array[Dictionary],
	card: CardInstance,
	slot: PokemonSlot = null,
	ability_index: int = -1,
	attack_data: Dictionary = {},
	attack_effects: Array[BaseEffect] = []
) -> void:
	scene.call("_reset_effect_interaction")
	scene.set("_pending_effect_kind", kind)
	scene.set("_pending_effect_player_index", player_index)
	scene.set("_pending_effect_card", card)
	scene.set("_pending_effect_slot", slot)
	scene.set("_pending_effect_ability_index", ability_index)
	scene.set("_pending_effect_attack_data", attack_data.duplicate(true))
	scene.set("_pending_effect_attack_effects", attack_effects.duplicate())
	scene.set("_pending_effect_steps", steps)
	scene.set("_pending_effect_step_index", 0)
	scene.set("_pending_effect_context", {})
	scene.call(
		"_runtime_log",
		"start_effect_interaction",
		"kind=%s player=%d card=%s steps=%d" % [
			kind,
			player_index,
			scene.call("_card_instance_label", card),
			steps.size(),
		]
	)
	show_next_effect_interaction_step(scene)


func effect_step_uses_counter_distribution_ui(_scene: Object, step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) != "counter_distribution":
		return false
	var target_items: Array = step.get("target_items", [])
	if target_items.is_empty():
		return false
	for item: Variant in target_items:
		if not (item is PokemonSlot):
			return false
	return true


func effect_step_uses_field_slot_ui(_scene: Object, step: Dictionary) -> bool:
	if bool(step.get("force_dialog", false)):
		return false
	if str(step.get("ui_mode", "")) in ["card_assignment", "counter_distribution"]:
		return false
	var items: Array = step.get("items", [])
	if items.is_empty():
		return false
	for item: Variant in items:
		if not (item is PokemonSlot):
			return false
	return true


func effect_step_uses_field_assignment_ui(_scene: Object, step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) != "card_assignment":
		return false
	var target_items: Array = step.get("target_items", [])
	if target_items.is_empty():
		return false
	for item: Variant in target_items:
		if not (item is PokemonSlot):
			return false
	return true


func resolve_effect_step_chooser_player(scene: Object, step: Dictionary) -> int:
	if step.has("chooser_player_index"):
		var chooser_index: int = int(step.get("chooser_player_index", -1))
		if chooser_index >= 0:
			return chooser_index
	if bool(step.get("opponent_chooses", false)) and int(scene.get("_pending_effect_player_index")) >= 0:
		return 1 - int(scene.get("_pending_effect_player_index"))
	return int(scene.get("_pending_effect_player_index"))


func hide_ai_owned_effect_step_ui(scene: Object, chooser_player: int) -> void:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	if ai_opponent == null or chooser_player != ai_opponent.player_index:
		return
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	var field_interaction_overlay: Control = scene.get("_field_interaction_overlay")
	if scene.has_method("_cancel_card_gallery_drag_scroll"):
		scene.call("_cancel_card_gallery_drag_scroll", "ai_owned_effect_step_hidden")
	if dialog_overlay != null:
		dialog_overlay.visible = false
	if dialog_cancel != null:
		dialog_cancel.visible = false
	if field_interaction_overlay != null:
		field_interaction_overlay.visible = false


func _apply_contextual_step_exclusions(
	scene: Object,
	step_index: int,
	pending_effect_steps: Array[Dictionary],
	step: Dictionary
) -> Dictionary:
	var pending_effect_context: Dictionary = scene.get("_pending_effect_context")
	var filtered_step := _effect_step_with_contextual_item_exclusions(step, pending_effect_context)
	if filtered_step != step:
		pending_effect_steps[step_index] = filtered_step
		scene.set("_pending_effect_steps", pending_effect_steps)
	return filtered_step


func _effect_step_with_contextual_item_exclusions(step: Dictionary, context: Dictionary) -> Dictionary:
	var exclude_step_ids: Array = step.get("exclude_selected_from_step_ids", [])
	if exclude_step_ids.is_empty():
		return step
	var excluded_items: Array = []
	for key_variant: Variant in exclude_step_ids:
		var selected_variant: Variant = context.get(str(key_variant), [])
		if selected_variant is Array:
			for selected_item: Variant in selected_variant:
				if selected_item != null and selected_item not in excluded_items:
					excluded_items.append(selected_item)
		elif selected_variant != null and selected_variant not in excluded_items:
			excluded_items.append(selected_variant)
	if excluded_items.is_empty():
		return step
	var items: Array = step.get("items", [])
	if items.is_empty():
		return step
	var filtered_items: Array = []
	var kept_indices: Array = []
	for i: int in items.size():
		var item: Variant = items[i]
		if item in excluded_items:
			continue
		filtered_items.append(item)
		kept_indices.append(i)
	if kept_indices.size() == items.size():
		return step
	var filtered_step := step.duplicate(true)
	filtered_step["items"] = filtered_items
	for key: String in ["labels", "choice_labels", "card_items", "card_indices", "action_items"]:
		_copy_filtered_parallel_step_array(step, filtered_step, key, kept_indices, items.size())
	return filtered_step


func _copy_filtered_parallel_step_array(
	source_step: Dictionary,
	filtered_step: Dictionary,
	key: String,
	kept_indices: Array,
	expected_size: int
) -> void:
	if not source_step.has(key):
		return
	var values_variant: Variant = source_step.get(key)
	if not (values_variant is Array):
		return
	var values: Array = values_variant
	if values.size() != expected_size:
		return
	var filtered_values: Array = []
	for kept_index_variant: Variant in kept_indices:
		var kept_index := int(kept_index_variant)
		if kept_index >= 0 and kept_index < values.size():
			filtered_values.append(values[kept_index])
	filtered_step[key] = filtered_values


func show_next_effect_interaction_step(scene: Object) -> void:
	var pending_effect_card: CardInstance = scene.get("_pending_effect_card")
	var pending_effect_kind: String = str(scene.get("_pending_effect_kind"))
	if pending_effect_card == null and pending_effect_kind != "bench_limit_cleanup":
		scene.call("_runtime_log", "effect_step_skipped", "pending card missing")
		return

	var pending_effect_step_index: int = int(scene.get("_pending_effect_step_index"))
	var pending_effect_steps: Array[Dictionary] = scene.get("_pending_effect_steps")
	if pending_effect_step_index >= pending_effect_steps.size():
		_finish_effect_interaction(scene)
		return

	var step: Dictionary = pending_effect_steps[pending_effect_step_index]
	if bool(step.get("wait_for_coin_animation", false)) and bool(scene.call("_has_pending_coin_animation")):
		scene.call("_delay_effect_step_until_coin_animation_finishes")
		return
	step = _apply_contextual_step_exclusions(scene, pending_effect_step_index, pending_effect_steps, step)
	var chooser_player: int = resolve_effect_step_chooser_player(scene, step)
	if (
		GameManager.current_mode == GameManager.GameMode.TWO_PLAYER
		and chooser_player >= 0
		and chooser_player != int(scene.get("_view_player"))
	):
		scene.set("_pending_choice", "effect_interaction")
		if scene.has_method("_defer_two_player_handover_until_attack_vfx_finished"):
			var deferred_for_attack_vfx := bool(scene.call("_defer_two_player_handover_until_attack_vfx_finished", "effect_step", func() -> void:
				show_next_effect_interaction_step(scene)
			))
			if deferred_for_attack_vfx:
				scene.call("_runtime_log", "effect_step_waiting_for_attack_vfx", scene.call("_state_snapshot"))
				return
		scene.call("_show_handover_prompt", chooser_player, func() -> void:
			scene.call("_set_handover_panel_visible", false, "effect_step_handover_%d" % int(scene.get("_pending_effect_step_index")))
			scene.set("_view_player", chooser_player)
			scene.call("_refresh_ui")
			show_next_effect_interaction_step(scene)
		)
		return
	if effect_step_uses_counter_distribution_ui(scene, step):
		scene.set("_pending_choice", "effect_interaction")
		scene.call(
			"_runtime_log",
			"effect_step",
			"step=%d/%d title=%s counters=%d mode=counter_distribution" % [
				pending_effect_step_index + 1,
				pending_effect_steps.size(),
				_step_title(scene, step),
				int(step.get("total_counters", 0)),
			]
		)
		scene.call("_show_field_counter_distribution", step)
		hide_ai_owned_effect_step_ui(scene, chooser_player)
		return
	if effect_step_uses_field_assignment_ui(scene, step):
		scene.set("_pending_choice", "effect_interaction")
		scene.call(
			"_runtime_log",
			"effect_step",
			"step=%d/%d title=%s options=%d mode=field_assignment" % [
				pending_effect_step_index + 1,
				pending_effect_steps.size(),
				_step_title(scene, step),
				int((step.get("source_items", []) as Array).size()),
			]
		)
		scene.call("_show_field_assignment_interaction", step)
		hide_ai_owned_effect_step_ui(scene, chooser_player)
		return
	if effect_step_uses_field_slot_ui(scene, step):
		scene.set("_pending_choice", "effect_interaction")
		scene.call(
			"_runtime_log",
			"effect_step",
			"step=%d/%d title=%s options=%d mode=field_slots" % [
				pending_effect_step_index + 1,
				pending_effect_steps.size(),
				_step_title(scene, step),
				int((step.get("items", []) as Array).size()),
			]
		)
		scene.call("_show_field_slot_choice", _step_title(scene, step), step.get("items", []), step)
		hide_ai_owned_effect_step_ui(scene, chooser_player)
		return
	if str(step.get("ui_mode", "")) == "card_assignment":
		scene.set("_pending_choice", "effect_interaction")
		scene.call(
			"_runtime_log",
			"effect_step",
			"step=%d/%d title=%s options=%d mode=assignment" % [
				pending_effect_step_index + 1,
				pending_effect_steps.size(),
				_step_title(scene, step),
				int((step.get("source_items", []) as Array).size()),
			]
		)
		scene.call("_show_dialog", _step_title(scene, step), [], step)
		hide_ai_owned_effect_step_ui(scene, chooser_player)
		return

	var labels: Array[String] = []
	for label: Variant in step.get("labels", []):
		labels.append(str(label))
	var items_raw: Array = step.get("items", [])
	var presentation: String = str(step.get("presentation", "auto"))
	var use_card_presentation := presentation == "cards"
	var use_action_hud_presentation := presentation == "action_hud"
	if presentation == "auto":
		use_card_presentation = true
		for item: Variant in items_raw:
			if not bool(scene.call("_dialog_item_has_card_visual", item)):
				use_card_presentation = false
				break

	scene.set("_pending_choice", "effect_interaction")
	scene.call(
		"_runtime_log",
		"effect_step",
		"step=%d/%d title=%s options=%d" % [
			pending_effect_step_index + 1,
			pending_effect_steps.size(),
			_step_title(scene, step),
			items_raw.size(),
		]
	)
	var dialog_data := {
		"min_select": int(step.get("min_select", 1)),
		"max_select": int(step.get("max_select", 1)),
		"allow_cancel": step.get("allow_cancel", true),
		"presentation": "action_hud" if use_action_hud_presentation else ("cards" if use_card_presentation else "list"),
		"card_items": step.get("card_items", items_raw),
		"card_indices": step.get("card_indices", []),
		"card_click_selectable": step.get("card_click_selectable", true),
		"choice_labels": step.get("choice_labels", labels),
	}
	for passthrough_key: String in [
		"action_items",
		"card_groups",
		"card_disabled_badge",
		"show_selectable_hints",
		"card_selectable_hint",
		"pokemon_card",
		"pokemon_card_data",
		"visible_scope",
		"force_confirm",
		"cancel_resolves_empty",
	]:
		if step.has(passthrough_key):
			dialog_data[passthrough_key] = step.get(passthrough_key)
	if not dialog_data.has("card_disabled_badge") and str(dialog_data.get("visible_scope", "")) == "own_full_deck":
		dialog_data["card_disabled_badge"] = "不可选"
	if step.has("utility_actions"):
		dialog_data["utility_actions"] = step.get("utility_actions", [])
	scene.call("_show_dialog", _step_title(scene, step), labels, dialog_data)
	hide_ai_owned_effect_step_ui(scene, chooser_player)


func handle_effect_interaction_choice(scene: Object, selected_indices: PackedInt32Array) -> void:
	var pending_effect_card: CardInstance = scene.get("_pending_effect_card")
	var pending_effect_kind: String = str(scene.get("_pending_effect_kind"))
	var pending_effect_step_index: int = int(scene.get("_pending_effect_step_index"))
	var pending_effect_steps: Array[Dictionary] = scene.get("_pending_effect_steps")
	if (
		(pending_effect_card == null and pending_effect_kind != "bench_limit_cleanup")
		or pending_effect_step_index < 0
		or pending_effect_step_index >= pending_effect_steps.size()
	):
		scene.call("_runtime_log", "effect_choice_ignored", "invalid pending state")
		scene.call("_reset_effect_interaction")
		return

	var step: Dictionary = pending_effect_steps[pending_effect_step_index]
	var items_raw: Array = step.get("items", [])
	var selected_items: Array = []
	for selected_idx: int in selected_indices:
		if selected_idx >= 0 and selected_idx < items_raw.size():
			selected_items.append(items_raw[selected_idx])

	var pending_effect_context: Dictionary = scene.get("_pending_effect_context")
	pending_effect_context[step.get("id", "step_%d" % pending_effect_step_index)] = selected_items
	scene.set("_pending_effect_context", pending_effect_context)
	scene.call(
		"_runtime_log",
		"effect_choice",
		"step=%s selected=%s" % [str(step.get("id", "step_%d" % pending_effect_step_index)), JSON.stringify(selected_indices)]
	)
	scene.set("_pending_effect_step_index", pending_effect_step_index + 1)
	inject_followup_steps(scene)
	show_next_effect_interaction_step(scene)
	scene.call("_maybe_run_ai")


func inject_followup_steps(scene: Object) -> void:
	var pending_effect_card: CardInstance = scene.get("_pending_effect_card")
	if pending_effect_card == null:
		return
	var pending_effect_kind: String = str(scene.get("_pending_effect_kind"))
	var pending_effect_attack_effects: Array[BaseEffect] = scene.get("_pending_effect_attack_effects")
	var gsm: Variant = scene.get("_gsm")
	var pending_effect_context: Dictionary = scene.get("_pending_effect_context")
	var followup_steps: Array[Dictionary] = []
	match pending_effect_kind:
		"attack":
			if pending_effect_attack_effects.is_empty():
				return
			var attack_index: int = int(scene.get("_pending_effect_ability_index"))
			if pending_effect_card.card_data == null or attack_index < 0 or attack_index >= pending_effect_card.card_data.attacks.size():
				return
			var attack: Dictionary = pending_effect_card.card_data.attacks[attack_index]
			for effect: BaseEffect in pending_effect_attack_effects:
				followup_steps.append_array(effect.get_followup_attack_interaction_steps(pending_effect_card, attack, gsm.game_state, pending_effect_context))
		"trainer", "play_stadium", "stadium":
			var trainer_effect: BaseEffect = gsm.effect_processor.get_effect(pending_effect_card.card_data.effect_id)
			if trainer_effect != null:
				followup_steps.append_array(trainer_effect.get_followup_interaction_steps(pending_effect_card, gsm.game_state, pending_effect_context))
		"ability":
			var pending_effect_slot: PokemonSlot = scene.get("_pending_effect_slot")
			var ability_index: int = int(scene.get("_pending_effect_ability_index"))
			if pending_effect_slot == null or ability_index < 0:
				return
			var ability_effect: BaseEffect = gsm.effect_processor.get_ability_effect(pending_effect_slot, ability_index, gsm.game_state)
			if ability_effect != null:
				followup_steps.append_array(ability_effect.get_followup_interaction_steps(pending_effect_card, gsm.game_state, pending_effect_context))
		"granted_attack":
			var granted_effect_slot: PokemonSlot = scene.get("_pending_effect_slot")
			var granted_effect_attack_data: Dictionary = scene.get("_pending_effect_attack_data")
			if granted_effect_slot == null or gsm == null or gsm.effect_processor == null:
				return
			followup_steps.append_array(
				gsm.effect_processor.get_granted_attack_followup_interaction_steps(
					granted_effect_slot,
					granted_effect_attack_data,
					gsm.game_state,
					pending_effect_context
				)
			)
		_:
			return
	if followup_steps.is_empty():
		return
	var pending_effect_step_index: int = int(scene.get("_pending_effect_step_index"))
	var pending_effect_steps: Array[Dictionary] = scene.get("_pending_effect_steps")
	var existing_step_ids: Dictionary = {}
	for i: int in range(pending_effect_step_index, pending_effect_steps.size()):
		var existing_id: String = str(pending_effect_steps[i].get("id", ""))
		if existing_id != "":
			existing_step_ids[existing_id] = true
	var unique_followup_steps: Array[Dictionary] = []
	for step: Dictionary in followup_steps:
		var step_id: String = str(step.get("id", ""))
		if step_id != "" and (pending_effect_context.has(step_id) or existing_step_ids.has(step_id)):
			continue
		unique_followup_steps.append(step)
		if step_id != "":
			existing_step_ids[step_id] = true
	if unique_followup_steps.is_empty():
		return
	var insert_pos: int = pending_effect_step_index
	for i: int in unique_followup_steps.size():
		pending_effect_steps.insert(insert_pos + i, unique_followup_steps[i])
	scene.set("_pending_effect_steps", pending_effect_steps)
	scene.call(
		"_runtime_log",
		"followup_steps_injected",
		"count=%d total_steps=%d" % [unique_followup_steps.size(), pending_effect_steps.size()]
	)


func reset_effect_interaction(scene: Object) -> void:
	scene.call("_runtime_log", "reset_effect_interaction", scene.call("_effect_state_snapshot"))
	var clearing_effect_dialog: bool = str(scene.get("_pending_choice")) == "effect_interaction"
	var clearing_field_interaction: bool = bool(scene.call("_is_field_interaction_active"))
	scene.set("_pending_effect_kind", "")
	scene.set("_pending_effect_player_index", -1)
	scene.set("_pending_effect_card", null)
	scene.set("_pending_effect_slot", null)
	scene.set("_pending_effect_ability_index", -1)
	(scene.get("_pending_effect_attack_data") as Dictionary).clear()
	(scene.get("_pending_effect_attack_effects") as Array).clear()
	(scene.get("_pending_effect_steps") as Array).clear()
	scene.set("_pending_effect_step_index", -1)
	(scene.get("_pending_effect_context") as Dictionary).clear()
	scene.set("_coin_animation_resume_effect_step", false)
	if clearing_field_interaction:
		scene.call("_hide_field_interaction")
	if clearing_effect_dialog:
		if scene.has_method("_finish_modal_input_interaction"):
			scene.call("_finish_modal_input_interaction", "effect_interaction_reset", "preserve")
		else:
			if scene.has_method("_cancel_card_gallery_drag_scroll"):
				scene.call("_cancel_card_gallery_drag_scroll", "effect_interaction_reset")
			if scene.has_method("_clear_hand_drag_click_suppression"):
				scene.call("_clear_hand_drag_click_suppression", "effect_interaction_reset")
		scene.set("_pending_choice", "")
		(scene.get("_dialog_data") as Dictionary).clear()
		(scene.get("_dialog_items_data") as Array).clear()
		(scene.get("_dialog_multi_selected_indices") as Array).clear()
		(scene.get("_dialog_card_selected_indices") as Array).clear()
		scene.call("_reset_dialog_assignment_state")
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		if dialog_overlay != null:
			dialog_overlay.visible = false


func _finish_effect_interaction(scene: Object) -> void:
	var gsm: Variant = scene.get("_gsm")
	var pending_effect_kind: String = str(scene.get("_pending_effect_kind"))
	var pending_effect_player_index: int = int(scene.get("_pending_effect_player_index"))
	var pending_effect_card: CardInstance = scene.get("_pending_effect_card")
	var pending_effect_slot: PokemonSlot = scene.get("_pending_effect_slot")
	var pending_effect_ability_index: int = int(scene.get("_pending_effect_ability_index"))
	var pending_effect_attack_data: Dictionary = scene.get("_pending_effect_attack_data")
	var pending_effect_context: Dictionary = scene.get("_pending_effect_context")
	var success := false
	var resolved_player_index := pending_effect_player_index
	var followup_evolve_slot: PokemonSlot = null
	match pending_effect_kind:
		"trainer":
			success = gsm.play_trainer(pending_effect_player_index, pending_effect_card, [pending_effect_context])
			if success:
				followup_evolve_slot = scene.call("_get_trainer_followup_evolve_slot")
		"play_stadium":
			success = gsm.play_stadium(pending_effect_player_index, pending_effect_card, [pending_effect_context])
		"ability":
			success = gsm.use_ability(pending_effect_player_index, pending_effect_slot, pending_effect_ability_index, [pending_effect_context])
		"stadium":
			success = gsm.use_stadium_effect(pending_effect_player_index, [pending_effect_context])
		"attack":
			success = gsm.use_attack(pending_effect_player_index, pending_effect_ability_index, [pending_effect_context])
		"granted_attack":
			success = gsm.use_granted_attack(pending_effect_player_index, pending_effect_slot, pending_effect_attack_data, [pending_effect_context])
		"bench_limit_cleanup":
			success = gsm.enforce_current_bench_limits("bench_limit_cleanup", pending_effect_player_index, "", -1, [pending_effect_context])
		"powerglass_end_turn":
			success = gsm.resolve_powerglass_end_turn_choice(pending_effect_player_index, [pending_effect_context])
	if not success and pending_effect_card != null:
		scene.call("_log", _bt(scene, "battle.log.cannot_use_card", {"name": pending_effect_card.card_data.name}))
	scene.call("_runtime_log", "effect_interaction_complete", "success=%s %s" % [str(success), scene.call("_state_snapshot")])
	reset_effect_interaction(scene)
	if success:
		var ready_action_kind := "use_ability" if pending_effect_kind == "ability" else ""
		if scene.has_method("_mark_ready_vfx_action_source"):
			scene.call("_mark_ready_vfx_action_source", resolved_player_index, ready_action_kind)
		else:
			scene.set("_ready_vfx_trigger_source_player_index", resolved_player_index)
			scene.set("_ready_vfx_trigger_action_kind", ready_action_kind)
		if scene.has_method("_restore_pending_engine_prize_choice_if_needed"):
			scene.call("_restore_pending_engine_prize_choice_if_needed", "effect_interaction_complete")
	scene.call("_refresh_ui")
	if success:
		if followup_evolve_slot != null:
			scene.call("_try_start_evolve_trigger_ability_interaction", resolved_player_index, followup_evolve_slot)
			if str(scene.get("_pending_choice")) == "effect_interaction":
				return
		scene.call("_check_two_player_handover")
		scene.call("_maybe_run_ai")


func _step_title(scene: Object, step: Dictionary) -> String:
	var title := str(step.get("title", "")).strip_edges()
	return title if title != "" else _bt(scene, "battle.field.title_default")
