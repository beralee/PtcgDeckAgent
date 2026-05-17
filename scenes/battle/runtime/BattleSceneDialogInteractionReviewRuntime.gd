## BattleScene dialog, field interaction, match review, and advice runtime.
extends "res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd"

func _on_slot_input(event: InputEvent, slot_id: String) -> void:
	if _consume_modal_slot_input_if_needed(event, slot_id):
		return
	if _pending_choice == "take_prize":
		_runtime_log("slot_input_blocked", "slot=%s reason=take_prize %s" % [slot_id, _state_snapshot()])
		var prize_viewport := get_viewport()
		if prize_viewport != null:
			prize_viewport.set_input_as_handled()
		return
	if _handover_panel.visible:
		_runtime_log("slot_input_blocked", "slot=%s reason=handover %s" % [slot_id, _state_snapshot()])
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _consume_recent_slot_followup_click(event, slot_id):
		return
	if _try_show_opponent_slot_detail_input(event, slot_id):
		return
	if not _can_accept_live_action():
		return

	if _handle_slot_touch_detail_input(event, slot_id):
		return

	if not event is InputEventMouseButton:
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return

	if mbe.button_index == MOUSE_BUTTON_RIGHT:
		_runtime_log("slot_right_click_action", "slot=%s %s" % [slot_id, _state_snapshot()])
		_show_slot_pokemon_action_if_available(slot_id)
		return

	if mbe.button_index != MOUSE_BUTTON_LEFT:
		return
	if _slot_touch_long_press_active and _slot_touch_long_press_slot_id == slot_id:
		var touch_viewport := get_viewport()
		if touch_viewport != null:
			touch_viewport.set_input_as_handled()
		return
	if _consume_suppressed_slot_left_click(slot_id):
		var suppressed_viewport := get_viewport()
		if suppressed_viewport != null:
			suppressed_viewport.set_input_as_handled()
		return
	_handle_slot_left_click(slot_id)



func _start_slot_touch_long_press(slot_id: String, position: Vector2, touch_index: int) -> bool:
	if _slot_card_data_for_detail(slot_id) == null:
		return false
	_ensure_slot_touch_long_press_timer()
	_slot_touch_long_press_active = true
	_slot_touch_long_press_slot_id = slot_id
	_slot_touch_long_press_index = touch_index
	_slot_touch_long_press_start = position
	_slot_touch_long_press_consumed = false
	if _slot_touch_long_press_timer.is_inside_tree():
		_slot_touch_long_press_timer.start()
	return true



func _on_slot_touch_long_press_timeout() -> void:
	_cancel_slot_touch_long_press(false)



func _finish_modal_input_interaction(reason: String = "modal", slot_suppression_mode: String = "arm") -> void:
	_ensure_battle_drag_scroll_coordinator()
	if _battle_drag_scroll_coordinator != null:
		_battle_drag_scroll_coordinator.call("clear_transient_input_capture", reason)
	_arm_hand_primary_release_fallback_window(reason)
	match slot_suppression_mode:
		"arm":
			_modal_input_slot_suppress_until_msec = Time.get_ticks_msec() + MODAL_INPUT_SLOT_SUPPRESS_MSEC
		"clear":
			_modal_input_slot_suppress_until_msec = 0
		"preserve":
			pass
		_:
			_modal_input_slot_suppress_until_msec = Time.get_ticks_msec() + MODAL_INPUT_SLOT_SUPPRESS_MSEC
	_cancel_slot_touch_long_press(false)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_runtime_log("modal_input_finished", "reason=%s slot_mode=%s" % [reason, slot_suppression_mode])


func _mark_modal_input_consumed(reason: String = "modal") -> void:
	_finish_modal_input_interaction(reason, "arm")


func _mark_modal_input_consumed_without_slot_suppression(reason: String = "modal") -> void:
	_finish_modal_input_interaction(reason, "clear")


func _should_arm_hand_primary_release_fallback() -> bool:
	return (
		_modal_input_finished_at_msec > 0
		and Time.get_ticks_msec() <= _modal_input_finished_at_msec + MODAL_HAND_RELEASE_FALLBACK_WINDOW_MSEC
	)


func _arm_hand_primary_release_fallback_window(reason: String = "transient_input") -> void:
	_modal_input_finished_at_msec = Time.get_ticks_msec()
	_arm_current_hand_cards_primary_release_fallback(reason)


func _arm_current_hand_cards_primary_release_fallback(reason: String = "modal") -> void:
	if _hand_container == null:
		return
	_arm_primary_release_fallback_recursive(_hand_container, "hand_after_%s" % reason)


func _arm_primary_release_fallback_recursive(node: Node, reason: String) -> void:
	if node == null:
		return
	if node is BattleCardView:
		(node as BattleCardView).arm_primary_release_fallback(reason)
	for child: Node in node.get_children():
		_arm_primary_release_fallback_recursive(child, reason)



func _hand_scroll_height_with_scrollbar(card_height: float) -> float:
	if _is_portrait_popup_text_profile_active():
		return maxf(0.0, card_height) + _card_scrollbar_clearance_height()
	return maxf(0.0, card_height) + float(HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING)



func _ensure_field_interaction_panel() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("ensure_field_interaction_panel")
	_sync_battle_interaction_state_from_scene()



func _update_field_interaction_panel_metrics(viewport_size: Vector2 = Vector2.ZERO) -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("update_field_interaction_panel_metrics", viewport_size)



func _field_interaction_target_owner(slot: PokemonSlot) -> int:
	return _battle_interaction_controller.call("field_interaction_target_owner", self, slot)



func _resolve_field_interaction_position(slots: Array) -> String:
	return _battle_interaction_controller.call("resolve_field_interaction_position", self, slots)



func _apply_field_interaction_position(panel_position: String) -> void:
	_battle_interaction_controller.call("apply_field_interaction_position", self, panel_position)



func _show_field_assignment_interaction(step: Dictionary) -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("show_field_assignment_interaction", step)
	_sync_battle_interaction_state_from_scene()



func _rebuild_field_slot_index_map(items: Array) -> void:
	_battle_interaction_controller.call("rebuild_field_slot_index_map", self, items)



func _build_field_assignment_source_cards() -> void:
	_battle_interaction_controller.call("build_field_assignment_source_cards", self)



func _add_field_assignment_source_card(source_items: Array, source_labels: Array, source_index: int) -> void:
	_battle_interaction_controller.call("add_field_assignment_source_card", self, source_items, source_labels, source_index)



func _on_field_assignment_source_chosen(source_index: int) -> void:
	_battle_interaction_controller.call("on_field_assignment_source_chosen", self, source_index)



func _find_field_assignment_index_for_source(source_index: int) -> int:
	return _battle_interaction_controller.call("find_field_assignment_index_for_source", self, source_index)



func _field_interaction_selected_slot_ids() -> Array[String]:
	return _battle_interaction_controller.call("field_interaction_selected_slot_ids", self)



func _refresh_field_interaction_status() -> void:
	_battle_interaction_controller.call("refresh_field_interaction_status", self)



func _refresh_field_assignment_source_views() -> void:
	_battle_interaction_controller.call("refresh_field_assignment_source_views", self)



func _on_field_interaction_clear_pressed() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("clear_selection")
	_sync_battle_interaction_state_from_scene()



func _on_field_interaction_cancel_pressed() -> void:
	_cancel_field_interaction()



func _on_field_interaction_confirm_pressed() -> void:
	if _field_interaction_mode == "slot_select":
		_finalize_field_slot_selection()
	elif _field_interaction_mode == "counter_distribution":
		_ensure_battle_interaction_coordinator()
		_battle_interaction_coordinator.call("confirm_counter_distribution")
		_sync_battle_interaction_state_from_scene()
	else:
		_finalize_field_assignment_selection()



func _slot_id_from_slot(slot: PokemonSlot) -> String:
	if slot == null or _gsm == null or _gsm.game_state == null:
		return ""
	var gs: GameState = _gsm.game_state
	if gs.players.size() < 2:
		return ""
	var vp: int = _view_player
	var op: int = 1 - vp
	if gs.players[vp].active_pokemon == slot:
		return "my_active"
	if gs.players[op].active_pokemon == slot:
		return "opp_active"
	for i: int in MAX_BENCH_SIZE:
		if i < gs.players[vp].bench.size() and gs.players[vp].bench[i] == slot:
			return "my_bench_%d" % i
		if i < gs.players[op].bench.size() and gs.players[op].bench[i] == slot:
			return "opp_bench_%d" % i
	return ""


func _dialog_should_use_card_mode(items: Array, extra_data: Dictionary) -> bool:
	return _battle_dialog_controller.call("dialog_should_use_card_mode", items, extra_data)



func _show_text_dialog(items: Array, extra_data: Dictionary) -> void:
	_battle_dialog_controller.call("show_text_dialog", self, items, extra_data)



func _show_card_dialog(items: Array, extra_data: Dictionary) -> void:
	_battle_dialog_controller.call("show_card_dialog", self, items, extra_data)



func _show_assignment_dialog(extra_data: Dictionary) -> void:
	_battle_dialog_controller.call("show_assignment_dialog", self, extra_data)



func _populate_grouped_source_items(
	source_items: Array,
	source_labels: Array,
	source_groups: Array
) -> void:
	_battle_dialog_controller.call("populate_grouped_source_items", self, source_items, source_labels, source_groups)

func _add_assignment_source_card(source_items: Array, source_labels: Array, i: int) -> void:
	_battle_dialog_controller.call("add_assignment_source_card", self, source_items, source_labels, i)



func _on_assignment_source_chosen(source_index: int) -> void:
	_battle_dialog_controller.call("on_assignment_source_chosen", self, source_index)



func _on_assignment_target_chosen(target_index: int) -> void:
	_battle_dialog_controller.call("on_assignment_target_chosen", self, target_index)



func _refresh_assignment_dialog_views() -> void:
	_battle_dialog_controller.call("refresh_assignment_dialog_views", self)



func _update_assignment_dialog_state() -> void:
	_battle_dialog_controller.call("update_assignment_dialog_state", self)



func _find_assignment_index_for_source(source_index: int) -> int:
	return _battle_dialog_controller.call("find_assignment_index_for_source", self, source_index)



func _dialog_assignment_last_target_index() -> int:
	return _battle_dialog_controller.call("dialog_assignment_last_target_index", self)



func _reset_dialog_assignment_state() -> void:
	_battle_dialog_controller.call("reset_dialog_assignment_state", self)



func _setup_dialog_card_view(card_view: BattleCardView, item: Variant, label: String) -> void:
	_battle_dialog_controller.call("setup_dialog_card_view", self, card_view, item, label)



func _dialog_choice_subtitle(item: Variant, label: String) -> String:
	return _battle_dialog_controller.call("dialog_choice_subtitle", self, item, label)



func _dialog_item_has_card_visual(item: Variant) -> bool:
	return _battle_dialog_controller.call("dialog_item_has_card_visual", item)



func _selected_dialog_labels(sel_items: PackedInt32Array) -> Array[String]:
	return _battle_dialog_controller.call("selected_dialog_labels", self, sel_items)



func _selected_field_slot_labels(sel_items: PackedInt32Array) -> Array[String]:
	var labels: Array[String] = []
	var items: Array = _field_interaction_data.get("items", [])
	for idx: int in sel_items:
		if idx < 0 or idx >= items.size():
			continue
		labels.append(_selection_label_from_item(items[idx]))
	return labels



func _selected_assignment_labels(assignments: Array[Dictionary]) -> Array[String]:
	return _battle_dialog_controller.call("selected_assignment_labels", assignments)



func _on_dialog_card_left_signal(_ci: CardInstance, _cd: CardData, real_index: int) -> void:
	if _is_card_gallery_drag_click_suppressed():
		return
	_on_dialog_card_chosen(real_index)



func _on_dialog_card_right_signal(_ci: CardInstance, cd: CardData) -> void:
	if _is_card_gallery_drag_click_suppressed():
		return
	if cd != null:
		_show_card_detail(cd)



func _toggle_dialog_card_choice(real_index: int, max_select: int) -> bool:
	if real_index in _dialog_card_selected_indices:
		_dialog_card_selected_indices.erase(real_index)
		return true
	if max_select > 0 and _dialog_card_selected_indices.size() >= max_select:
		return false
	_dialog_card_selected_indices.append(real_index)
	return true



func _sync_dialog_card_selection() -> void:
	_battle_dialog_controller.call("sync_dialog_card_selection", self)



func _update_dialog_confirm_state() -> void:
	_battle_dialog_controller.call("update_dialog_confirm_state", self)



func _update_dialog_status_text() -> void:
	_battle_dialog_controller.call("update_dialog_status_text", self)



func _confirm_dialog_selection(sel_items: PackedInt32Array) -> void:
	_battle_dialog_controller.call("confirm_dialog_selection", self, sel_items)



func _on_dialog_item_selected(idx: int) -> void:
	_battle_dialog_controller.call("on_dialog_item_selected", self, idx)



func _on_dialog_item_multi_selected(idx: int, selected: bool) -> void:
	_battle_dialog_controller.call("on_dialog_item_multi_selected", self, idx, selected)


func _on_dialog_confirm() -> void:
	_battle_dialog_controller.call("on_dialog_confirm", self)


func _on_dialog_cancel() -> void:
	_battle_dialog_controller.call("on_dialog_cancel", self)



func _confirm_assignment_dialog() -> void:
	_battle_dialog_controller.call("confirm_assignment_dialog", self)



func _commit_effect_assignment_selection(stored_assignments: Array[Dictionary]) -> void:
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return
	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	_pending_effect_context[step.get("id", "step_%d" % _pending_effect_step_index)] = stored_assignments
	_runtime_log(
		"effect_assignment_choice",
		"step=%s assignments=%d" % [str(step.get("id", "step_%d" % _pending_effect_step_index)), stored_assignments.size()]
	)
	_pending_effect_step_index += 1
	_inject_followup_steps()
	_show_next_effect_interaction_step()



func _commit_heavy_baton_assignment(stored_assignments: Array[Dictionary]) -> void:
	var consumed_choice := _pending_choice
	var pi_hb: int = int(_dialog_data.get("player", -1))
	var target_slot: PokemonSlot = null
	var selected_energy: Array[CardInstance] = []
	for assignment: Dictionary in stored_assignments:
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if source is CardInstance and source not in selected_energy:
			selected_energy.append(source)
		if target_slot == null and target is PokemonSlot:
			target_slot = target
	if target_slot == null:
		_log("Invalid Heavy Baton target")
		return
	var resolved := false
	if selected_energy.is_empty():
		resolved = _gsm.resolve_heavy_baton_choice(pi_hb, target_slot)
	else:
		resolved = _gsm.resolve_heavy_baton_choice_with_energy(pi_hb, target_slot, selected_energy)
	if resolved:
		if _pending_choice == consumed_choice:
			_pending_choice = ""
		_refresh_ui()
		_maybe_run_ai()
	else:
		_log("Invalid Heavy Baton target")



func _commit_exp_share_assignment(stored_assignments: Array[Dictionary]) -> void:
	var consumed_choice := _pending_choice
	var pi_exp: int = int(_dialog_data.get("player", -1))
	var target_slot: PokemonSlot = null
	var selected_energy: CardInstance = null
	for assignment: Dictionary in stored_assignments:
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if selected_energy == null and source is CardInstance:
			selected_energy = source
		if target_slot == null and target is PokemonSlot:
			target_slot = target
	if target_slot == null:
		_log("Invalid Exp. Share target")
		return
	if _gsm.resolve_exp_share_choice(pi_exp, target_slot, selected_energy):
		if _pending_choice == consumed_choice:
			_pending_choice = ""
		_refresh_ui()
		_maybe_run_ai()
	else:
		_log("Invalid Exp. Share target")



func _handle_dialog_choice(selected_indices: PackedInt32Array) -> void:
	_sync_battle_dialog_state_from_scene()
	_ensure_battle_prompt_router()
	_battle_prompt_router.call("route_choice", selected_indices, Callable(self, "_handle_dialog_choice_legacy"))
	_sync_battle_scene_context_runtime()



func _handle_dialog_choice_legacy(selected_indices: PackedInt32Array) -> void:
	var idx: int = selected_indices[0] if not selected_indices.is_empty() else -1
	var handled_choice := _pending_choice
	_pending_choice = ""
	_runtime_log(
		"handle_dialog_choice",
		"handled=%s idx=%d selected=%s" % [handled_choice, idx, JSON.stringify(selected_indices)]
	)
	match handled_choice:
		"attack_vfx_preview":
			var preview_entries: Array = _dialog_data.get("entries", [])
			if idx >= 0 and idx < preview_entries.size():
				var entry: Variant = preview_entries[idx]
				if entry is Dictionary:
					var preview_profile: Variant = (entry as Dictionary).get("profile", null)
					if preview_profile is RefCounted:
						_battle_attack_vfx_controller.call("play_preview_vfx", self, preview_profile)
		"mulligan_extra_draw":
			var beneficiary: int = _dialog_data.get("beneficiary", 0)
			_gsm.resolve_mulligan_choice(beneficiary, true)
			# resolve_mulligan_choice handles mulligan follow-up and may return to setup_ready
		"attack":
			var cp: int = _dialog_data.get("player", 0)
			if idx < _dialog_data.get("attack_count", 0):
				if _gsm.use_attack(cp, idx):
					_refresh_ui()
					_check_two_player_handover()
				else:
					_log(_gsm.get_attack_unusable_reason(cp, idx))
		"pokemon_action":
			var cp_action: int = _dialog_data.get("player", 0)
			var actions: Array = _dialog_data.get("actions", [])
			if idx >= 0 and idx < actions.size():
				var action: Variant = actions[idx]
				if action is Dictionary:
					var action_data: Dictionary = action
					var action_slot: Variant = action_data.get("slot", null)
					var action_type: String = str(action_data.get("type", ""))
					if not bool(action_data.get("enabled", true)):
						_log(str(action_data.get("reason", "当前无法执行该操作")))
						return
					if action_slot is PokemonSlot and action_type == "ability":
						_try_use_ability_with_interaction(
							cp_action,
							action_slot,
							int(action_data.get("ability_index", 0))
						)
					elif action_slot is PokemonSlot and action_type == "attack":
						_try_use_attack_with_interaction(
							cp_action,
							action_slot,
							int(action_data.get("attack_index", 0))
						)
					elif action_slot is PokemonSlot and action_type == "granted_attack":
						_try_use_granted_attack_with_interaction(
							cp_action,
							action_slot,
							action_data.get("granted_attack", {})
						)
					elif action_type == "stadium_ability":
						_try_use_stadium_with_interaction(cp_action)
					elif action_type == "retreat":
						if _gsm.rule_validator.can_retreat(_gsm.game_state, cp_action):
							_show_retreat_dialog(cp_action)
						else:
							_log("当前无法撤退")
		"send_out":
			var pi: int = _dialog_data.get("player", 0)
			var bench_raw: Array = _dialog_data.get("bench", [])
			var bench_so: Array[PokemonSlot] = []
			for s: Variant in bench_raw:
				if s is PokemonSlot:
					bench_so.append(s)
			if idx < bench_so.size():
				if _gsm.send_out_pokemon(pi, bench_so[idx]):
					_view_player = _preferred_live_view_player(_gsm.game_state.current_player_index)
					_refresh_ui()
					_check_two_player_handover()
				else:
					_log("无法让这只宝可梦进化")
		"heavy_baton_target":
			var pi_hb: int = _dialog_data.get("player", 0)
			var bench_raw_hb: Array = _dialog_data.get("bench", [])
			var bench_hb: Array[PokemonSlot] = []
			for s: Variant in bench_raw_hb:
				if s is PokemonSlot:
					bench_hb.append(s)
			if idx < bench_hb.size():
				if _gsm.resolve_heavy_baton_choice(pi_hb, bench_hb[idx]):
					_refresh_ui()
				else:
					_log("Invalid Heavy Baton target")
		"retreat_energy":
			var cp_energy: int = _dialog_data.get("player", 0)
			var retreat_cost: int = int(_dialog_data.get("retreat_cost", 0))
			var energy_options_raw: Array = _dialog_data.get("energy_options", [])
			var energy_options: Array[CardInstance] = []
			for option: Variant in energy_options_raw:
				if option is CardInstance:
					energy_options.append(option)
			var chosen_energy: Array[CardInstance] = _resolve_retreat_energy_selection(selected_indices, energy_options)
			var active_slot: PokemonSlot = null
			if _gsm != null and _gsm.game_state != null and cp_energy >= 0 and cp_energy < _gsm.game_state.players.size():
				active_slot = _gsm.game_state.players[cp_energy].active_pokemon
			if active_slot == null or not _retreat_selection_is_valid(active_slot, chosen_energy, retreat_cost):
				_log("当前选择的能量不符合撤退费用")
				_show_retreat_energy_dialog(cp_energy, active_slot, retreat_cost)
				return
			if not _gsm.rule_validator.has_enough_energy_to_retreat(
				active_slot,
				chosen_energy,
				retreat_cost,
				_gsm.effect_processor,
				_gsm.game_state
			):
				_log("当前选择的能量不足以支付撤退费用")
				_show_retreat_energy_dialog(cp_energy, active_slot, retreat_cost)
				return
			_show_retreat_bench_choice(cp_energy, chosen_energy)
		"retreat_bench":
			var cp: int = _dialog_data.get("player", 0)
			var bench_raw2: Array = _dialog_data.get("bench", [])
			var bench_rb: Array[PokemonSlot] = []
			for s: Variant in bench_raw2:
				if s is PokemonSlot:
					bench_rb.append(s)
			var energy_raw: Array = _dialog_data.get("energy_discard", [])
			var energy_discard: Array[CardInstance] = []
			for e: Variant in energy_raw:
				if e is CardInstance:
					energy_discard.append(e)
			if idx < bench_rb.size():
				if _gsm.retreat(cp, energy_discard, bench_rb[idx]):
					_refresh_ui_after_successful_action(false, cp)
		"confirm_exit":
			if idx == 0:
				if GameManager.is_tournament_battle_active():
					GameManager.forfeit_current_tournament_battle("技术负（退出对局）")
					GameManager.goto_tournament_standings()
				else:
					GameManager.goto_battle_setup()
		"zeus_help":
			var zeus_player_index: int = int(_dialog_data.get("player", _view_player))
			var zeus_dialog_cards: Array = _dialog_data.get("deck_cards", [])
			var selected_cards: Array[CardInstance] = _resolve_zeus_help_selected_cards(
				zeus_player_index,
				zeus_dialog_cards,
				selected_indices
			)
			_apply_zeus_help(zeus_player_index, selected_cards)
		"game_over":
			var review_action_kind: String = str(_dialog_data.get("review_action", ""))
			var review_action_index: int = int(_dialog_data.get("review_action_index", -1))
			var learning_action_kind: String = str(_dialog_data.get("learning_action", ""))
			var learning_action_index: int = int(_dialog_data.get("learning_action_index", -1))
			var return_action_index: int = int(_dialog_data.get("return_action_index", -1))
			if idx == review_action_index and review_action_kind != "":
				match review_action_kind:
					"generate", "retry":
						_begin_battle_review_generation()
					"view":
						_open_cached_battle_review()
			elif idx == learning_action_index and learning_action_kind != "":
				match learning_action_kind:
					"mark":
						_mark_current_match_for_learning()
					"marked":
						_log("该对局已在学习池中")
			elif idx == return_action_index:
				_on_match_end_return_pressed()
		"effect_interaction":
			_handle_effect_interaction_choice(selected_indices)
		_:
			if handled_choice.begins_with("setup_active_"):
				var pi: int = int(handled_choice.split("_")[-1])
				var basics_raw: Array = _dialog_data.get("basics", [])
				var basics: Array[CardInstance] = []
				for c: Variant in basics_raw:
					if c is CardInstance:
						basics.append(c)
				if idx < basics.size():
					_gsm.setup_place_active_pokemon(pi, basics[idx])
					_after_setup_active(pi)
			elif handled_choice.begins_with("setup_bench_"):
				var pi: int = int(handled_choice.split("_")[-1])
				if idx == 0:
					# Stop placing bench Pokemon and finish the setup bench step
					_after_setup_bench(pi)
				else:
					var cards_raw: Array = _dialog_data.get("cards", [])
					var cards: Array[CardInstance] = []
					for c: Variant in cards_raw:
						if c is CardInstance:
							cards.append(c)
					var card_idx: int = idx - 1
					if card_idx < cards.size():
						_gsm.setup_place_bench_pokemon(pi, cards[card_idx])
						_refresh_ui()
						_show_setup_bench_dialog(pi)



func _show_heavy_baton_dialog(
	pi: int,
	bench_targets: Array[PokemonSlot],
	energy_count: int,
	source_name: String,
	source_slot: PokemonSlot = null,
	source_energy: Array[CardInstance] = []
) -> void:
	_battle_dialog_controller.call("show_heavy_baton_dialog", self, pi, bench_targets, energy_count, source_name, source_slot, source_energy)

func _show_exp_share_dialog(
	pi: int,
	bench_targets: Array[PokemonSlot],
	source_slot: PokemonSlot,
	source_energy: Array[CardInstance]
) -> void:
	_battle_dialog_controller.call("show_exp_share_dialog", self, pi, bench_targets, source_slot, source_energy)

func _show_field_counter_distribution(step: Dictionary) -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("show_field_counter_distribution", step)
	_sync_battle_interaction_state_from_scene()



func _on_counter_distribution_amount_chosen(amount: int) -> void:
	_battle_interaction_controller.call("on_counter_distribution_amount_chosen", self, amount)



func _show_attack_dialog(cp: int, active_slot: PokemonSlot) -> void:
	_show_pokemon_action_dialog(cp, active_slot, true)



func _on_handover_confirmed() -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("on_handover_confirmed")
	_sync_battle_scene_context_runtime()



func _setup_ai_for_tests() -> void:
	if _dialog_overlay != null:
		_dialog_overlay.visible = false
	if _handover_panel != null:
		_handover_panel.visible = false
	if _field_interaction_overlay != null:
		_field_interaction_overlay.visible = false
	_pending_prize_animating = false
	_ai_running = false
	_ai_step_scheduled = false
	_ai_followup_requested = false
	_ai_action_pause_timer = null
	_ai_action_pause_seconds = AI_ACTION_PAUSE_SECONDS
	_coin_animation_resume_effect_step = false
	_ai_opponent = null
	_ai_turn_marker = ""
	_ai_actions_this_turn = 0



func _set_battle_recording_output_root(root_path: String) -> void:
	_ensure_battle_recording_coordinator()
	_battle_recording_coordinator.call("set_output_root", root_path)
	_sync_battle_recording_state_from_scene()



func _should_record_local_battle() -> bool:
	_ensure_battle_recording_coordinator()
	return bool(_battle_recording_coordinator.call("should_record_local_battle"))



func _can_capture_battle_recording_context() -> bool:
	_ensure_battle_recording_coordinator()
	return bool(_battle_recording_coordinator.call("can_capture_context"))



func _match_end_summary_text(winner_index: int, reason: String) -> String:
	return _battle_dialog_controller.call("match_end_summary_text", winner_index, reason)



func _should_offer_battle_review() -> bool:
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER



func _should_offer_match_learning() -> bool:
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and _battle_review_match_dir.strip_edges() != ""



func _is_current_match_marked_for_learning() -> bool:
	if _battle_review_match_dir.strip_edges() == "" or _battle_learning_store == null:
		return false
	if not _battle_learning_store.has_method("is_marked_for_learning"):
		return false
	return bool(_battle_learning_store.call("is_marked_for_learning", _battle_review_match_dir))



func _load_cached_battle_review() -> Dictionary:
	if _battle_review_match_dir.strip_edges() == "" or _battle_review_store == null:
		return {}
	if not _battle_review_store.has_method("read_review"):
		return {}
	var review: Variant = _battle_review_store.call("read_review", _battle_review_match_dir)
	return review if review is Dictionary else {}



func _ensure_battle_review_service() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("ensure_battle_review_service")



func _on_battle_review_status_changed(status: String, context: Dictionary) -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_battle_review_status_changed", status, context)
	_sync_battle_advice_state_from_scene()



func _on_battle_review_completed(review: Dictionary) -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_battle_review_completed", review)
	_sync_battle_advice_state_from_scene()



func _normalize_match_end_quick_review_stats(stats: Dictionary) -> void:
	_match_end_quick_review_builder.call("normalize_stats", stats, _view_player)



func _match_end_quick_review_subject_player_index(stats: Dictionary = {}) -> int:
	return int(_match_end_quick_review_builder.call("subject_player_index", stats, _view_player))



func _match_end_quick_review_subject(stats: Dictionary) -> Dictionary:
	var subject: Variant = _match_end_quick_review_builder.call("subject", stats, _view_player)
	return subject if subject is Dictionary else {}



func _match_end_quick_review_deck_name(player_index: int) -> String:
	return str(_match_end_quick_review_builder.call("deck_name", player_index))



func _match_end_quick_review_digest_context() -> Dictionary:
	var context: Variant = _match_end_quick_review_builder.call("digest_context", _battle_review_match_dir)
	return context if context is Dictionary else {}



func _read_match_end_quick_review_digest() -> Dictionary:
	var digest: Variant = _match_end_quick_review_builder.call("read_digest", _battle_review_match_dir)
	return digest if digest is Dictionary else {}



func _quick_review_key_moments_from_digest(digest: Dictionary) -> Array[Dictionary]:
	var moments: Variant = _match_end_quick_review_builder.call("key_moments_from_digest", digest)
	return moments if moments is Array[Dictionary] else []



func _quick_review_compact_sequences(sequences_variant: Variant, max_items: int) -> Array[Dictionary]:
	var compact: Variant = _match_end_quick_review_builder.call("compact_sequences", sequences_variant, max_items)
	return compact if compact is Array[Dictionary] else []



func _quick_review_recent_turns(turns_variant: Variant, max_items: int) -> Array[Dictionary]:
	var recent: Variant = _match_end_quick_review_builder.call("recent_turns", turns_variant, max_items)
	return recent if recent is Array[Dictionary] else []



func _quick_review_last_turn(turns_variant: Variant) -> Dictionary:
	var turn: Variant = _match_end_quick_review_builder.call("last_turn", turns_variant)
	return turn if turn is Dictionary else {}



func _quick_review_compact_turn(turn: Dictionary) -> Dictionary:
	var compact: Variant = _match_end_quick_review_builder.call("compact_turn", turn)
	return compact if compact is Dictionary else {}



func _quick_review_compact_action_summaries(actions_variant: Variant, max_items: int) -> Array[Dictionary]:
	var compact: Variant = _match_end_quick_review_builder.call("compact_action_summaries", actions_variant, max_items)
	return compact if compact is Array[Dictionary] else []



func _quick_review_compact_choice_summaries(choices_variant: Variant, max_items: int) -> Array[Dictionary]:
	var compact: Variant = _match_end_quick_review_builder.call("compact_choice_summaries", choices_variant, max_items)
	return compact if compact is Array[Dictionary] else []



func _quick_review_compact_string_array(values_variant: Variant, max_items: int) -> Array[String]:
	var compact: Variant = _match_end_quick_review_builder.call("compact_string_array", values_variant, max_items)
	return compact if compact is Array[String] else []



func _match_end_quick_review_deck_strategies() -> Array[Dictionary]:
	var strategies: Variant = _match_end_quick_review_builder.call("deck_strategies")
	return strategies if strategies is Array[Dictionary] else []



func _on_match_end_quick_review_status_changed(status: String, _context: Dictionary) -> void:
	if status == "running":
		_match_end_quick_review_busy = true
		if _match_end_quick_review_progress_text == "":
			_match_end_quick_review_progress_text = "正在生成赛后快评..."
	else:
		_match_end_quick_review_busy = false
		_match_end_quick_review_progress_text = ""
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("refresh_match_end_screen")



func _match_end_quick_review_error_message(result: Dictionary) -> String:
	return str(_match_end_quick_review_builder.call("error_message", result))



func _quick_review_primary_key_moment_text(moments_variant: Variant) -> String:
	return str(_match_end_quick_review_builder.call("primary_key_moment_text", moments_variant))



func _match_end_grade_for_score(score: int) -> String:
	return str(_match_end_quick_review_builder.call("grade_for_score", score))



func _on_match_end_quick_review_pressed() -> void:
	_begin_match_end_quick_review(true)



func _on_match_end_review_pressed() -> void:
	var review_action := _current_match_end_review_action()
	match str(review_action.get("kind", "")):
		"generate", "retry":
			_begin_battle_review_generation()
		"view":
			_open_cached_battle_review()



func _on_match_end_learning_pressed() -> void:
	var learning_action := _current_match_end_learning_action()
	match str(learning_action.get("kind", "")):
		"mark":
			_mark_current_match_for_learning()
		"marked":
			_log("该对局已在学习池中")



func _refresh_match_end_dialog_if_visible() -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("refresh_match_end_dialog_if_visible")



func _show_battle_review_overlay(review: Dictionary) -> void:
	_battle_overlay_controller.call("show_battle_review_overlay", self, review)



func _format_battle_review(review: Dictionary) -> String:
	_ensure_battle_advice_coordinator()
	return str(_battle_advice_coordinator.call("format_battle_review", review))



func _on_review_regenerate_pressed() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_review_regenerate_pressed")



func _should_offer_battle_advice() -> bool:
	_ensure_battle_advice_coordinator()
	return bool(_battle_advice_coordinator.call("should_offer_battle_advice"))



func _current_battle_advice_match_dir() -> String:
	_ensure_battle_advice_coordinator()
	return str(_battle_advice_coordinator.call("current_battle_advice_match_dir"))



func _ensure_battle_advice_service() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("ensure_battle_advice_service")



func _on_ai_advice_pressed() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_ai_advice_pressed")
	_sync_battle_advice_state_from_scene()



func _on_battle_discuss_ai_pressed() -> void:
	var view_deck := _battle_discussion_view_deck()
	if view_deck == null:
		return
	if _battle_discussion_dialog == null or not is_instance_valid(_battle_discussion_dialog):
		_battle_discussion_dialog = DeckDiscussionDialogScene.instantiate() as AcceptDialog
		add_child(_battle_discussion_dialog)
		if _battle_discussion_dialog.has_signal("assistant_response_finished"):
			_battle_discussion_dialog.connect("assistant_response_finished", Callable(self, "_on_battle_discussion_response_finished"))
	_stop_battle_discussion_flash()
	var context := _build_battle_discussion_context()
	var signature := _battle_discussion_current_signature()
	var reset_session := signature != _battle_discussion_signature
	_battle_discussion_signature = signature
	_battle_discussion_dialog.call(
		"setup_for_battle_context",
		view_deck,
		context,
		_battle_discussion_session_id(),
		reset_session,
		Callable(self, "_build_battle_discussion_context")
	)
	_popup_battle_discussion_dialog_for_current_layout()



func _on_battle_discussion_response_finished() -> void:
	_start_battle_discussion_flash()



func _visible_player_context(player: Dictionary, include_hand: bool) -> Dictionary:
	var context_variant: Variant = _battle_discussion_context_builder.call("visible_player_context", player, include_hand)
	return context_variant if context_variant is Dictionary else {}



func _prizes_taken_from_remaining(prize_remaining: int) -> int:
	return int(_battle_discussion_context_builder.call("prizes_taken_from_remaining", prize_remaining))



func _knockout_projection_from_visible_state(my_player: Dictionary, opponent_player: Dictionary) -> Dictionary:
	var projection_variant: Variant = _battle_discussion_context_builder.call("knockout_projection_from_visible_state", my_player, opponent_player)
	return projection_variant if projection_variant is Dictionary else {}



func _public_slot_array(slots_variant: Variant) -> Array[Dictionary]:
	var slots: Variant = _battle_discussion_context_builder.call("public_slot_array", slots_variant)
	return slots if slots is Array[Dictionary] else []



func _public_slot_detail(slot_variant: Variant) -> Dictionary:
	var slot: Variant = _battle_discussion_context_builder.call("public_slot_detail", slot_variant)
	return slot if slot is Dictionary else {}



func _public_card_array(cards_variant: Variant) -> Array[Dictionary]:
	var cards: Variant = _battle_discussion_context_builder.call("public_card_array", cards_variant)
	return cards if cards is Array[Dictionary] else []



func _public_card_detail(card_variant: Variant) -> Dictionary:
	var card: Variant = _battle_discussion_context_builder.call("public_card_detail", card_variant)
	return card if card is Dictionary else {}



func _decklist_context(deck: DeckData) -> Dictionary:
	var deck_context: Variant = _battle_discussion_context_builder.call("decklist_context", deck)
	return deck_context if deck_context is Dictionary else {}



func _card_data_detail(card: CardData) -> Dictionary:
	var detail: Variant = _battle_discussion_context_builder.call("card_data_detail", card)
	return detail if detail is Dictionary else {}


func _on_attack_vfx_preview_pressed() -> void:
	var entries_variant: Variant = _battle_attack_vfx_registry.call("get_preview_entries")
	var entries: Array = entries_variant if entries_variant is Array else []
	var labels: Array = []
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary:
			labels.append(str((entry_variant as Dictionary).get("label", "未命名特效")))
	_pending_choice = "attack_vfx_preview"
	_show_dialog("放烟花：选择特效", labels, {"entries": entries})



func _on_battle_advice_status_changed(status: String, _context: Dictionary) -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_battle_advice_status_changed", status, _context)
	_sync_battle_advice_state_from_scene()



func _on_battle_advice_completed(result: Dictionary) -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_battle_advice_completed", result)
	_sync_battle_advice_state_from_scene()



func _show_battle_advice_overlay(result: Dictionary) -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("show_battle_advice_overlay", result)



func _format_battle_advice(result: Dictionary) -> String:
	_ensure_battle_advice_coordinator()
	return str(_battle_advice_coordinator.call("format_battle_advice", result))



func _on_review_pin_pressed() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_review_pin_pressed")
	_sync_battle_advice_state_from_scene()



func _on_battle_advice_panel_toggle_pressed() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("on_battle_advice_panel_toggle_pressed")
	_sync_battle_advice_state_from_scene()



func _refresh_battle_advice_panel() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("refresh_battle_advice_panel")



func _build_battle_record_meta() -> Dictionary:
	var meta_variant: Variant = _battle_recording_controller.call("build_battle_record_meta", self)
	return meta_variant if meta_variant is Dictionary else {}



func _build_battle_initial_state() -> Dictionary:
	var state_variant: Variant = _battle_recording_controller.call("build_battle_initial_state", self)
	return state_variant if state_variant is Dictionary else {}



func _build_battle_advice_initial_snapshot() -> Dictionary:
	_ensure_battle_advice_coordinator()
	var snapshot_variant: Variant = _battle_advice_coordinator.call("build_battle_advice_initial_snapshot")
	return snapshot_variant if snapshot_variant is Dictionary else {}



func _build_battle_initial_player_state(player: PlayerState) -> Dictionary:
	var state_variant: Variant = _battle_recording_controller.call("build_battle_initial_player_state", player)
	return state_variant if state_variant is Dictionary else {}



func _slot_record_names(slots: Array) -> Array[String]:
	var names_variant: Variant = _battle_recording_controller.call("slot_record_names", slots)
	return names_variant if names_variant is Array[String] else []



func _slot_record_name(slot: PokemonSlot) -> String:
	return str(_battle_recording_controller.call("slot_record_name", slot))



func _serialize_slot_list(slots: Array) -> Array[Dictionary]:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_slot_list", slots)
	return serialized_variant if serialized_variant is Array[Dictionary] else []



func _serialize_card_list(cards: Array) -> Array[Dictionary]:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_card_list", cards)
	return serialized_variant if serialized_variant is Array[Dictionary] else []



func _serialize_pokemon_slot(slot: PokemonSlot) -> Dictionary:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_pokemon_slot", slot)
	return serialized_variant if serialized_variant is Dictionary else {}



func _serialize_card_instance(card: CardInstance) -> Dictionary:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_card_instance", card)
	return serialized_variant if serialized_variant is Dictionary else {}



func _sanitize_recording_value(value: Variant) -> Variant:
	return _battle_recording_controller.call("sanitize_recording_value", self, value)



func set_ai_version_registry_for_test(registry: RefCounted) -> void:
	_ai_version_registry = registry



func set_agent_version_store_for_test(store: RefCounted) -> void:
	_agent_version_store = store



func _build_default_ai_opponent() -> AIOpponent:
	return _battle_ai_opponent_factory.call("build_default_ai_opponent", _deck_strategy_registry, self)



func _is_strong_fixed_opening_mode() -> bool:
	return bool(_battle_ai_opponent_factory.call("is_strong_fixed_opening_mode"))



func _resolve_selected_ai_version_record(selection: Dictionary) -> Dictionary:
	var record: Variant = _battle_ai_opponent_factory.call("resolve_selected_ai_version_record", selection, _deck_strategy_registry, _ai_version_registry)
	return record if record is Dictionary else {}



func _resolve_selected_ai_deck_strategy() -> RefCounted:
	return _battle_ai_opponent_factory.call("resolve_selected_ai_deck_strategy", _deck_strategy_registry) as RefCounted



func _resolve_strategy_variant_override(strategy: RefCounted) -> RefCounted:
	return _battle_ai_opponent_factory.call("resolve_strategy_variant_override", strategy, _deck_strategy_registry, self) as RefCounted



func _selected_ai_strategy_id() -> String:
	return str(_battle_ai_opponent_factory.call("selected_ai_strategy_id", _deck_strategy_registry))



func _is_version_record_compatible_with_selected_ai(version_record: Dictionary) -> bool:
	return bool(_battle_ai_opponent_factory.call("is_version_record_compatible_with_selected_ai", version_record, _deck_strategy_registry))



func _load_selected_agent_config(agent_config_path: String) -> Dictionary:
	var loaded: Variant = _battle_ai_opponent_factory.call("load_selected_agent_config", agent_config_path, _agent_version_store)
	return loaded if loaded is Dictionary else {}



func _ai_path_exists(path: String) -> bool:
	return bool(_battle_ai_opponent_factory.call("ai_path_exists", path))



func _connect_llm_strategy_signals(strategy: RefCounted) -> void:
	if strategy == null:
		return
	var started_cb := Callable(self, "_on_llm_thinking_started")
	var finished_cb := Callable(self, "_on_llm_thinking_finished")
	var failed_cb := Callable(self, "_on_llm_thinking_failed")
	if strategy.has_signal("llm_thinking_started") and not strategy.is_connected("llm_thinking_started", started_cb):
		strategy.connect("llm_thinking_started", started_cb)
	if strategy.has_signal("llm_thinking_finished") and not strategy.is_connected("llm_thinking_finished", finished_cb):
		strategy.connect("llm_thinking_finished", finished_cb)
	if strategy.has_signal("llm_thinking_failed") and not strategy.is_connected("llm_thinking_failed", failed_cb):
		strategy.connect("llm_thinking_failed", failed_cb)



func _on_llm_thinking_started(turn_number: int) -> void:
	_ai_llm_waiting = true
	_ai_llm_turn_requested = turn_number
	_start_llm_wait_hud(turn_number)
	_log("[LLM] turn %d: planning..." % turn_number)
	if _ai_opponent == null:
		return
	var strategy: Variant = _ai_opponent.get("_deck_strategy")
	var soft_timeout := 10.0
	if strategy != null and strategy.has_method("get_llm_soft_timeout_seconds"):
		soft_timeout = float(strategy.call("get_llm_soft_timeout_seconds"))
	if soft_timeout <= 0.0 or not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(soft_timeout)
	timer.timeout.connect(func() -> void:
		if _ai_llm_waiting and _ai_llm_turn_requested == turn_number:
			_maybe_run_ai()
	)



func _on_llm_thinking_finished(turn_number: int, plan: Dictionary, reasoning: String) -> void:
	_ai_llm_waiting = false
	_stop_llm_wait_hud()
	if plan.has("fast_choice"):
		var fast_choice: Dictionary = plan.get("fast_choice", {}) if plan.get("fast_choice", {}) is Dictionary else {}
		var msg_fast := "[LLM] turn %d fast choice: kind=%s selected=%d" % [
			turn_number,
			str(plan.get("prompt_kind", "")),
			int(fast_choice.get("selected_index", -1)),
		]
		_log(msg_fast)
		_maybe_run_ai()
		return
	var msg_clean := "[LLM] turn %d selected action queue:" % turn_number
	var clean_queue: Array = plan.get("action_queue", []) if plan.get("action_queue", []) is Array else []
	if not clean_queue.is_empty():
		var clean_summaries: PackedStringArray = PackedStringArray()
		for i: int in mini(clean_queue.size(), 10):
			var clean_item: Dictionary = clean_queue[i] if clean_queue[i] is Dictionary else {}
			var clean_label: String = str(clean_item.get("type", "?"))
			var clean_detail: String = str(clean_item.get("card", clean_item.get("pokemon", clean_item.get("target", ""))))
			if clean_detail != "":
				clean_label += "(%s)" % clean_detail
			clean_summaries.append("%d.%s" % [i + 1, clean_label])
		msg_clean += " " + ", ".join(clean_summaries)
	else:
		msg_clean += " empty; rules fallback will continue"
	_log(msg_clean)
	_maybe_run_ai()



func _on_llm_thinking_failed(turn_number: int, reason: String) -> void:
	_ai_llm_waiting = false
	_stop_llm_wait_hud()
	_log("[LLM] turn %d: planning failed, using rules (%s)" % [turn_number, reason])
	_maybe_run_ai()



func _run_ai_step() -> void:
	if _ai_running:
		return
	if _try_auto_continue_ai_draw_reveal():
		_ai_step_scheduled = false
		return
	_ai_step_scheduled = false
	if not _is_ai_turn_ready():
		return
	if _should_wait_for_llm():
		return
	_reset_ai_action_counter_if_needed()
	if _ai_actions_this_turn >= AI_MAX_ACTIONS_PER_TURN:
		if _pending_choice == "" and _gsm != null and _gsm.game_state != null and _gsm.game_state.phase == GameState.GamePhase.MAIN:
			_on_end_turn()
		return
	var starting_pending_choice: String = _pending_choice
	_ai_running = true
	_ai_followup_requested = false
	_ensure_ai_opponent()
	var handled: bool = _ai_opponent.run_single_step(self, _gsm)
	_ai_running = false
	if handled:
		_ai_actions_this_turn += 1
	var started_in_setup_prompt: bool = starting_pending_choice.begins_with("setup_active_") \
		or starting_pending_choice.begins_with("setup_bench_")
	if started_in_setup_prompt \
		and not _ai_step_scheduled \
		and _pending_choice == "" \
		and _gsm != null \
		and _gsm.game_state != null \
		and _gsm.game_state.phase != GameState.GamePhase.SETUP \
		and _ai_opponent != null \
		and _gsm.game_state.current_player_index == _ai_opponent.player_index:
		_ai_step_scheduled = true
		call_deferred("_run_ai_step")
	if _ai_followup_requested and not _ai_step_scheduled and _is_ai_turn_ready():
		_ai_step_scheduled = true
		call_deferred("_run_ai_step")
	_ai_followup_requested = false



func _on_hand_card_clicked(inst: CardInstance, _panel: PanelContainer) -> void:
	if not _can_accept_live_action():
		return
	_battle_action_controller.call("on_hand_card_clicked", self, inst, _panel)



func _try_play_trainer_with_interaction(player_index: int, card: CardInstance) -> void:
	_battle_action_controller.call("try_play_trainer_with_interaction", self, player_index, card)



func _try_play_stadium_with_interaction(player_index: int, card: CardInstance) -> void:
	_battle_action_controller.call("try_play_stadium_with_interaction", self, player_index, card)



func _effect_step_uses_field_slot_ui(step: Dictionary) -> bool:
	return bool(_battle_effect_interaction_controller.call("effect_step_uses_field_slot_ui", self, step))



func _effect_step_uses_field_assignment_ui(step: Dictionary) -> bool:
	return bool(_battle_effect_interaction_controller.call("effect_step_uses_field_assignment_ui", self, step))



func _effect_step_uses_counter_distribution_ui(step: Dictionary) -> bool:
	return bool(_battle_effect_interaction_controller.call("effect_step_uses_counter_distribution_ui", self, step))



func _hide_ai_owned_effect_step_ui(chooser_player: int) -> void:
	_battle_effect_interaction_controller.call("hide_ai_owned_effect_step_ui", self, chooser_player)



func _reset_effect_interaction() -> void:
	_battle_effect_interaction_controller.call("reset_effect_interaction", self)



func _get_trainer_followup_evolve_slot() -> PokemonSlot:
	if _gsm == null or _pending_effect_card == null or _pending_effect_card.card_data == null:
		return null
	var effect: BaseEffect = _gsm.effect_processor.get_effect(_pending_effect_card.card_data.effect_id)
	if not effect is EffectRareCandy:
		return null
	var target_raw: Array = _pending_effect_context.get("target_pokemon", [])
	if target_raw.is_empty():
		return null
	var candidate: Variant = target_raw[0]
	if candidate is PokemonSlot:
		return candidate as PokemonSlot
	return null



func _on_replay_prev_turn_pressed() -> void:
	var step_variant: Variant = _battle_replay_controller.call(
		"step_previous_turn",
		_replay_current_turn_index,
		_replay_turn_numbers
	)
	if not (step_variant is Dictionary):
		return
	var step: Dictionary = step_variant
	_replay_current_turn_index = int(step.get("current_turn_index", _replay_current_turn_index))
	_load_replay_turn(int(step.get("turn_number", 0)))



func _on_replay_next_turn_pressed() -> void:
	var step_variant: Variant = _battle_replay_controller.call(
		"step_next_turn",
		_replay_current_turn_index,
		_replay_turn_numbers
	)
	if not (step_variant is Dictionary):
		return
	var step: Dictionary = step_variant
	_replay_current_turn_index = int(step.get("current_turn_index", _replay_current_turn_index))
	_load_replay_turn(int(step.get("turn_number", 0)))



func _on_replay_continue_pressed() -> void:
	var restored_game_state: Variant = _battle_replay_controller.call(
		"restore_live_game_state",
		_battle_replay_state_restorer,
		_replay_loaded_raw_snapshot
	)
	if restored_game_state == null:
		return
	_ensure_game_state_machine()
	_gsm.game_state = restored_game_state
	_register_effects_from_game_state(_gsm.game_state)
	_clear_replay_ui_state()
	_battle_mode = "live"
	# 将 phase 推进到 MAIN 让玩家可以操作
	if _gsm.game_state.phase != GameState.GamePhase.MAIN and _gsm.game_state.phase != GameState.GamePhase.GAME_OVER:
		_gsm.game_state.phase = GameState.GamePhase.MAIN
	_refresh_replay_controls()
	_refresh_ui()
	_check_two_player_handover()
	_maybe_run_ai()



func _on_replay_back_to_list_pressed() -> void:
	if _is_review_mode():
		GameManager.goto_replay_browser()



func _get_selected_deck_name(player_index: int) -> String:
	return str(_battle_display_controller.call("get_selected_deck_name", player_index))



func _update_side_previews(opp: PlayerState, my: PlayerState) -> void:
	_battle_display_controller.call("update_side_previews", self, opp, my)



func _refresh_stadium_area(gs: GameState, current_player: int, is_my_turn: bool) -> void:
	_battle_display_controller.call("refresh_stadium_area", self, gs, current_player, is_my_turn)



func _refresh_info_hud(gs: GameState, view_player: int, opponent_player: int) -> void:
	_battle_display_controller.call("refresh_info_hud", self, gs, view_player, opponent_player)



func _apply_info_metric(label: Label, is_used: bool, ready_text: String, used_text: String) -> void:
	_battle_display_controller.call("apply_info_metric", label, is_used, ready_text, used_text)



func _update_prize_slots(slots: Array[BattleCardView], prize_layout: Array, is_selectable: bool) -> void:
	_battle_display_controller.call("update_prize_slots", self, slots, prize_layout, is_selectable)


func _update_pile_preview(preview: BattleCardView, card: CardInstance, face_down: bool) -> void:
	_battle_display_controller.call("update_pile_preview", preview, card, face_down)



func _refresh_field_card_views(gs: GameState) -> void:
	_battle_display_controller.call("refresh_field_card_views", self, gs)



func _refresh_slot_card_view(slot_id: String, slot: PokemonSlot, is_active: bool) -> void:
	_battle_display_controller.call("refresh_slot_card_view", self, slot_id, slot, is_active)


func _apply_field_slot_style(panel: PanelContainer, slot_id: String, occupied: bool, is_active: bool) -> void:
	_battle_display_controller.call("apply_field_slot_style", self, panel, slot_id, occupied, is_active)


func _slot_overlay_text(slot: PokemonSlot) -> String:
	return str(_battle_display_controller.call("slot_overlay_text", self, slot))



func _build_battle_status(slot: PokemonSlot) -> Dictionary:
	var status_variant: Variant = _battle_display_controller.call("build_battle_status", self, slot)
	return status_variant if status_variant is Dictionary else {}



func _slot_used_ability_this_turn(slot: PokemonSlot) -> bool:
	return bool(_battle_display_controller.call("slot_used_ability_this_turn", self, slot))



func _get_display_max_hp(slot: PokemonSlot) -> int:
	return int(_battle_display_controller.call("get_display_max_hp", self, slot))



func _get_display_remaining_hp(slot: PokemonSlot) -> int:
	return int(_battle_display_controller.call("get_display_remaining_hp", self, slot))



func _battle_card_mode_for_slot(slot: PokemonSlot) -> String:
	return str(_battle_display_controller.call("battle_card_mode_for_slot", self, slot))



func _slot_energy_icon_codes(slot: PokemonSlot) -> Array[String]:
	var codes_variant: Variant = _battle_display_controller.call("slot_energy_icon_codes", self, slot)
	return codes_variant if codes_variant is Array[String] else []



func _slot_energy_summary(slot: PokemonSlot) -> String:
	return str(_battle_display_controller.call("slot_energy_summary", self, slot))



func _refresh_slot_label(lbl: RichTextLabel, slot: PokemonSlot) -> void:
	_battle_display_controller.call("refresh_slot_label", self, lbl, slot)



func _refresh_bench(container: HBoxContainer, bench: Array[PokemonSlot]) -> void:
	_battle_display_controller.call("refresh_bench", container, bench)



func _build_hand_card(inst: CardInstance) -> PanelContainer:
	return _battle_display_controller.call("build_hand_card", self, inst)



func _hand_card_subtext(cd: CardData) -> String:
	return str(_battle_display_controller.call("hand_card_subtext", cd))



func _bt(key: String, params: Dictionary = {}) -> String:
	return BattleI18nScript.t(key, params)



func _on_coin_flipped(result: bool) -> void:
	var text: String = "正面" if result else "反面"
	_runtime_log("coin_flipped", text)
	_coin_flip_queue.append(result)
	if not _coin_animating:
		_play_next_coin_animation()



func _delay_effect_step_until_coin_animation_finishes() -> void:
	_coin_animation_resume_effect_step = true
	_pending_choice = "effect_interaction"
	_runtime_log("effect_step_waiting_for_coin_animation", _effect_state_snapshot())



func _on_coin_animation_finished() -> void:
	_play_next_coin_animation()



func _on_discard_open_control_input(event: InputEvent, player_index: int, title: String) -> void:
	if _consume_modal_slot_input_if_needed(event, "discard_hud"):
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	_show_discard_pile(player_index, title)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()



func _on_lost_zone_open_control_input(event: InputEvent, enemy: bool) -> void:
	if _consume_modal_slot_input_if_needed(event, "lost_zone_hud"):
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	if _gsm == null or _gsm.game_state == null:
		return
	var player_index := 1 - _view_player if enemy else _view_player
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return
	_show_lost_zone(player_index, "对方 LOST 区" if enemy else "己方 LOST 区")
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()



func _on_discard_list_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	if _discard_list == null or index < 0 or index >= _discard_list.item_count:
		return
	var metadata: Variant = _discard_list.get_item_metadata(index)
	var card_data: CardData = metadata as CardData if metadata is CardData else null
	if card_data == null:
		return
	_show_card_detail(card_data)



func _runtime_log_ui_state_if_changed() -> void:
	_battle_runtime_log_controller.call("runtime_log_ui_state_if_changed", self)



func _dialog_state_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("dialog_state_snapshot", self))



func _overlay_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("overlay_snapshot", self))



func _card_type_cn(cd: CardData) -> String:
	_ensure_battle_card_detail_coordinator()
	return str(_battle_card_detail_coordinator.call("card_type_cn", cd))



func _show_hand_card_detail(inst: CardInstance) -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("show_hand_card_detail", inst)



func _should_hand_card_click_select_directly(inst: CardInstance) -> bool:
	_ensure_battle_card_detail_coordinator()
	return bool(_battle_card_detail_coordinator.call("should_hand_card_click_select_directly", inst))



func _can_show_hand_detail_action(inst: CardInstance) -> bool:
	_ensure_battle_card_detail_coordinator()
	return bool(_battle_card_detail_coordinator.call("can_show_hand_detail_action", inst))



func _hand_contains_card(player_index: int, inst: CardInstance) -> bool:
	_ensure_battle_card_detail_coordinator()
	return bool(_battle_card_detail_coordinator.call("hand_contains_card", player_index, inst))



func _detail_use_label_for_current_context() -> String:
	_ensure_battle_card_detail_coordinator()
	return str(_battle_card_detail_coordinator.call("detail_use_label_for_current_context"))



func _set_detail_action_mode(mode: String, inst: CardInstance) -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("set_detail_action_mode", mode, inst)



func _on_detail_use_pressed() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("on_detail_use_pressed")



func _on_detail_cancel_pressed() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("on_detail_cancel_pressed")



func _raise_card_detail_overlay() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("raise_card_detail_overlay")



func _hide_card_detail() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("hide_card_detail")



func _play_card_detail_open_animation() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("play_card_detail_open_animation")
