## BattleScene board action, card detail, prize, and match-end runtime.
extends "res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd"

func _ensure_portrait_actions_popup() -> VBoxContainer:
	if _portrait_actions_popup == null:
		_portrait_actions_popup = PopupPanel.new()
		_portrait_actions_popup.name = "PortraitActionsPopup"
		_portrait_actions_popup.exclusive = false
		_portrait_actions_popup.transient = true
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.02, 0.07, 0.10, 0.96)
		panel_style.border_color = Color(0.26, 0.82, 0.95, 0.90)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(18)
		_portrait_actions_popup.add_theme_stylebox_override("panel", panel_style)
		add_child(_portrait_actions_popup)
		var margin := MarginContainer.new()
		margin.name = "PortraitActionsMargin"
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_bottom", 18)
		_portrait_actions_popup.add_child(margin)
		var scroll := ScrollContainer.new()
		scroll.name = "PortraitActionsScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		HudThemeScript.style_scroll_container(scroll, "touch")
		margin.add_child(scroll)
		var list := VBoxContainer.new()
		list.name = "PortraitActionsList"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 10)
		scroll.add_child(list)
	var existing := _portrait_actions_popup.get_node_or_null("PortraitActionsMargin/PortraitActionsScroll/PortraitActionsList") as VBoxContainer
	if existing == null:
		existing = _portrait_actions_popup.get_node_or_null("PortraitActionsMargin/PortraitActionsList") as VBoxContainer
	return existing



func _popup_portrait_panel() -> void:
	if _portrait_actions_popup == null:
		return
	var frame_rect := _portrait_layout_frame_rect
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	if frame_rect.size == Vector2.ZERO:
		var logical_size := size
		if logical_size == Vector2.ZERO and viewport_size != Vector2.ZERO:
			logical_size = _battle_layout_logical_viewport_size(viewport_size, "portrait")
		if logical_size == Vector2.ZERO:
			logical_size = Vector2(390, 844)
		frame_rect = Rect2(Vector2.ZERO, logical_size)
	var ui_scale := _portrait_layout_ui_scale(frame_rect.size)
	var margin := maxf(PORTRAIT_ACTION_POPUP_MARGIN * ui_scale, frame_rect.size.x * 0.035)
	var margin_node := _portrait_actions_popup.get_node_or_null("PortraitActionsMargin") as MarginContainer
	if margin_node != null:
		var margin_px := roundi(margin)
		margin_node.add_theme_constant_override("margin_left", margin_px)
		margin_node.add_theme_constant_override("margin_right", margin_px)
		margin_node.add_theme_constant_override("margin_top", margin_px)
		margin_node.add_theme_constant_override("margin_bottom", margin_px)
	var available_width := maxf(frame_rect.size.x - margin * 2.0, 1.0)
	var available_height := maxf(frame_rect.size.y - margin * 2.0, 1.0)
	var popup_width := clampf(frame_rect.size.x * 0.92, minf(320.0 * ui_scale, available_width), minf(560.0 * ui_scale, available_width))
	var list := _portrait_actions_popup.get_node_or_null("PortraitActionsMargin/PortraitActionsScroll/PortraitActionsList") as VBoxContainer
	var desired_content_height := _portrait_actions_popup_content_height(list)
	var popup_height := minf(desired_content_height + margin * 2.0, available_height)
	var popup_position := Vector2(
		frame_rect.position.x + (frame_rect.size.x - popup_width) * 0.5,
		frame_rect.position.y + (frame_rect.size.y - popup_height) * 0.5
	)
	var popup_rect := Rect2i(
		Vector2i(roundi(popup_position.x), roundi(popup_position.y)),
		Vector2i(roundi(popup_width), roundi(popup_height))
	)
	var popup_size := Vector2i(roundi(popup_width), roundi(popup_height))
	_portrait_actions_popup.size = popup_size
	var scroll := _portrait_actions_popup.get_node_or_null("PortraitActionsMargin/PortraitActionsScroll") as ScrollContainer
	if scroll != null:
		scroll.custom_minimum_size = Vector2(0, maxf(popup_height - margin * 2.0, 1.0))
		HudThemeScript.style_scroll_container(scroll, _portrait_scrollbar_profile())
	if not is_inside_tree():
		return
	_portrait_actions_popup.popup(popup_rect)
	_portrait_actions_popup.size = popup_size



func _apply_portrait_popup_text_metrics() -> void:
	if not _is_portrait_popup_text_profile_active():
		_restore_portrait_popup_text_metrics()
		_restore_portrait_scrollbar_metrics()
		return
	_apply_portrait_dialog_width_metrics()
	_apply_portrait_overlay_box_metrics()
	for root: Node in _portrait_popup_text_roots():
		_apply_popup_text_scale(root, PORTRAIT_POPUP_FONT_SCALE)
	_apply_portrait_scrollbar_metrics()



func _style_hud_button(button: Button) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.01, 0.11, 0.18, 0.72)
	normal.border_color = Color(0.16, 0.62, 0.76, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.04, 0.18, 0.28, 0.82)
	hover.border_color = Color(0.37, 0.91, 0.98, 0.96)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.03, 0.14, 0.22, 0.9)
	pressed.border_color = Color(0.56, 0.94, 1.0, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.04, 0.08, 0.12, 0.45)
	disabled.border_color = Color(0.22, 0.31, 0.38, 0.6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.58, 0.63))






func _clear_container_children(container: Node) -> void:
	_battle_display_controller.call("clear_container_children", container)



func _sync_battle_layout_state_from_scene() -> void:
	if _battle_layout_state == null:
		return
	_battle_layout_state.set("play_card_size", _play_card_size)
	_battle_layout_state.set("dialog_card_size", _dialog_card_size)
	_battle_layout_state.set("detail_card_size", _detail_card_size)
	_battle_layout_state.set("portrait_layout_frame_rect", _portrait_layout_frame_rect)
	_battle_layout_state.set("portrait_layout_full_size", _portrait_layout_full_size)
	_battle_layout_state.set("rotated_portrait_canvas_active", _rotated_portrait_canvas_active)
	_battle_layout_state.set("rotated_portrait_physical_viewport_size", _rotated_portrait_physical_viewport_size)
	_battle_layout_state.set("active_battle_layout_mode", _active_battle_layout_mode)



func _pile_lost_panel_height(pile_panel_height: float) -> float:
	return clampf(roundf(pile_panel_height * 0.32), 24.0, 46.0)



func _move_control_to_container(control: Control, target: Container, insert_index: int) -> void:
	_move_control_to_node(control, target, insert_index)



func _bind_lost_zone_open_control(control: Control, enemy: bool) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.tooltip_text = "点击查看对方 LOST 区" if enemy else "点击查看己方 LOST 区"
	var callback := Callable(self, "_on_lost_zone_open_control_input").bind(enemy)
	if not control.gui_input.is_connected(callback):
		control.gui_input.connect(callback)



func _hide_empty_status_stack(stack_name: String) -> void:
	var stack := find_child(stack_name, true, false) as VBoxContainer
	if stack == null:
		return
	stack.visible = false
	stack.custom_minimum_size = Vector2.ZERO



func _dialog_card_scroll_height() -> float:
	return _card_scroll_height_with_scrollbar(_dialog_card_size.y)



func _bench_panel_children_recursive(host: Node) -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	if host == null:
		return panels
	for child: Node in host.get_children():
		if child is PanelContainer:
			panels.append(child as PanelContainer)
		else:
			panels.append_array(_bench_panel_children_recursive(child))
	return panels



func _reparent_bench_panel(panel: PanelContainer, target: Container) -> void:
	if panel == null or target == null or panel.get_parent() == target:
		return
	var parent := panel.get_parent()
	if parent != null:
		parent.remove_child(panel)
	var previous_owner := panel.owner
	panel.owner = null
	target.add_child(panel)
	if target.owner != null:
		panel.owner = target.owner
	else:
		panel.owner = previous_owner



func _portrait_bench_grid_hit_slot_id_for_screen_position(screen_position: Vector2) -> String:
	var grid := _portrait_my_bench_grid if _portrait_my_bench_grid != null else get_node_or_null("PortraitMyBenchGrid") as Container
	if grid == null or not grid.visible:
		return ""
	var local_position := _screen_position_to_battle_local(screen_position)
	var grid_rect := _control_rect_in_battle_local(grid)
	if grid_rect.size == Vector2.ZERO:
		return ""
	if not grid_rect.grow(28.0).has_point(local_position):
		return ""
	return _first_empty_own_bench_slot_id()



func _consume_modal_slot_input_if_needed(event: InputEvent, source: String = "") -> bool:
	if _modal_input_slot_suppress_until_msec <= 0:
		return false
	if Time.get_ticks_msec() > _modal_input_slot_suppress_until_msec:
		_modal_input_slot_suppress_until_msec = 0
		return false
	if not _is_slot_followup_click_event(event):
		return false
	_cancel_slot_touch_long_press(false)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_runtime_log("modal_slot_input_consumed", "source=%s event=%s" % [source, event.get_class()])
	return true



func _consume_modal_hud_input_if_needed(event: InputEvent, source: String = "") -> bool:
	if _consume_modal_slot_input_if_needed(event, source):
		return true
	if _modal_input_finished_at_msec <= 0:
		return false
	if Time.get_ticks_msec() > _modal_input_finished_at_msec + MODAL_HAND_RELEASE_FALLBACK_WINDOW_MSEC:
		return false
	if not _is_slot_followup_click_event(event):
		return false
	_cancel_slot_touch_long_press(false)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_runtime_log("modal_hud_input_consumed", "source=%s event=%s" % [source, event.get_class()])
	return true



func _suppress_action_hud_open_input(source: String = "action_hud_open", duration_msec: int = -1, origin_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var resolved_duration := duration_msec if duration_msec >= 0 else ACTION_HUD_OPEN_INPUT_SUPPRESS_MSEC
	_action_hud_open_input_suppress_until_msec = Time.get_ticks_msec() + resolved_duration
	_action_hud_open_input_suppress_has_position = origin_position.x >= 0.0 and origin_position.y >= 0.0
	_action_hud_open_input_suppress_position = origin_position if _action_hud_open_input_suppress_has_position else Vector2.ZERO
	_action_hud_open_position_guard_until_msec = Time.get_ticks_msec() + ACTION_HUD_OPEN_POSITION_GUARD_MSEC if _action_hud_open_input_suppress_has_position else 0
	_runtime_log("action_hud_open_input_suppressed", "source=%s duration=%d" % [source, resolved_duration])



func _consume_action_hud_open_input_if_needed(event: InputEvent, source: String = "") -> bool:
	var now := Time.get_ticks_msec()
	var in_time_guard := _action_hud_open_input_suppress_until_msec > 0 and now <= _action_hud_open_input_suppress_until_msec
	var in_position_guard := _action_hud_open_input_suppress_has_position \
		and _action_hud_open_position_guard_until_msec > 0 \
		and now <= _action_hud_open_position_guard_until_msec
	if not in_time_guard and not in_position_guard:
		_clear_action_hud_open_input_guard()
		return false
	if _pending_choice != "pokemon_action":
		_clear_action_hud_open_input_guard()
		return false
	if not _is_slot_followup_click_event(event):
		return false
	if not in_time_guard and not _action_hud_open_event_matches_suppress_position(event):
		return false
	_cancel_slot_touch_long_press(false)
	_clear_action_hud_open_input_guard()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_runtime_log("action_hud_open_input_consumed", "source=%s event=%s" % [source, event.get_class()])
	return true



func _clear_action_hud_open_input_guard() -> void:
	_action_hud_open_input_suppress_until_msec = 0
	_action_hud_open_position_guard_until_msec = 0
	_action_hud_open_input_suppress_position = Vector2.ZERO
	_action_hud_open_input_suppress_has_position = false



func _action_hud_open_event_matches_suppress_position(event: InputEvent) -> bool:
	if not _action_hud_open_input_suppress_has_position:
		return false
	var event_position := _action_hud_open_input_screen_position(event)
	if event_position.x < 0.0 or event_position.y < 0.0:
		return false
	return event_position.distance_to(_action_hud_open_input_suppress_position) <= ACTION_HUD_OPEN_POSITION_GUARD_TOLERANCE



func _action_hud_open_input_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		var mouse := event as InputEventMouse
		if mouse.global_position.x >= 0.0 and mouse.global_position.y >= 0.0:
			return mouse.global_position
		return mouse.position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2(-1.0, -1.0)



func _resolve_top_action_button_width(viewport_size: Vector2, action_gap: int = -1, ui_scale: float = 1.0) -> float:
	var resolved_gap := action_gap if action_gap >= 0 else _resolve_top_action_gap(viewport_size)
	var top_bar_inner_width := maxf(viewport_size.x - 12.0, 0.0)
	var right_column_width := floorf((top_bar_inner_width - float(_resolve_top_row_gap(viewport_size) * 2)) / 3.0)
	var available_action_width := right_column_width - float(resolved_gap * 3)
	var budgeted_button_width := floorf(available_action_width / 4.0)
	var preferred_width := clampf(viewport_size.x * 0.062, 76.0 * ui_scale, 108.0 * ui_scale)
	return clampf(minf(preferred_width, budgeted_button_width), 58.0 * ui_scale, 108.0 * ui_scale)



func _top_action_button_or_null(button: Button, path: String) -> Button:
	return button if button != null else get_node_or_null(path) as Button



func _vstar_lost_hud_size_matches(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= 0.5 and absf(a.y - b.y) <= 0.5



func _format_action_description_for_display(description: String) -> String:
	var rendered := description
	for player_index: int in 2:
		var display_name := GameManager.resolve_battle_player_display_name(player_index)
		rendered = rendered.replace("玩家%d" % (player_index + 1), display_name)
		rendered = rendered.replace("玩家 %d" % (player_index + 1), display_name)
	return rendered



func _record_battle_state_snapshot(snapshot_reason: String, extra_data: Dictionary = {}) -> void:
	_battle_recording_controller.call("record_battle_state_snapshot", self, snapshot_reason, extra_data)



func _hide_field_interaction() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("hide_field_interaction")
	_sync_battle_interaction_state_from_scene()



func _show_send_out_dialog(pi: int) -> void:
	_battle_dialog_controller.call("show_send_out_dialog", self, pi)



func _show_slot_card_detail(slot_id: String) -> bool:
	var detail_card := _slot_card_data_for_detail(slot_id)
	if detail_card == null:
		return false
	_show_card_detail(detail_card)
	return true



func _handle_slot_left_click(slot_id: String) -> void:
	_runtime_log(
		"slot_left_click",
		"slot=%s selected=%s %s" % [slot_id, _card_instance_label(_selected_hand_card), _state_snapshot()]
	)

	var cp: int = _gsm.game_state.current_player_index if _gsm != null else 0
	var gs: GameState = _gsm.game_state if _gsm != null else null
	if gs == null:
		return

	var target_slot: PokemonSlot = _slot_from_id(slot_id, gs)
	if _is_field_interaction_active():
		_suppress_slot_followup_click(slot_id, "field_interaction_target")
		_try_handle_field_interaction_slot_click(slot_id, target_slot)
		return
	if target_slot == null and not slot_id.begins_with("opp"):
		if _selected_hand_card != null and _selected_hand_card.card_data.is_basic_pokemon():
			_try_play_to_bench(cp, _selected_hand_card, slot_id)
		return

	if target_slot == null:
		return

	if _selected_hand_card != null:
		# 进化、能量、道具只能操作自己的宝可梦
		if slot_id.begins_with("opp"):
			_show_invalid_action_message({
				"title": "目标不合法",
				"reason": "不能对对方的宝可梦使用手牌。",
				"detail": "从手牌进化、附着能量或附着道具时，请选择己方场上的宝可梦。",
				"kind": "target",
			})
			return
		var card := _selected_hand_card
		var cd := card.card_data
		if cd.is_pokemon() and cd.stage != "Basic":
			if _gsm.evolve_pokemon(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui()
				_suppress_slot_followup_click(slot_id, "evolve_target")
				_try_start_evolve_trigger_ability_interaction(cp, target_slot)
				_maybe_run_ai()
			else:
				_show_invalid_action_message({
					"title": "%s 现在不能进化" % cd.name,
					"reason": _gsm.rule_validator.get_evolve_unusable_reason(gs, cp, target_slot, card, _gsm.effect_processor),
					"detail": "进化需要满足回合、进化链和目标宝可梦状态要求。",
					"kind": "evolve",
				})
		elif cd.card_type == "Basic Energy" or cd.card_type == "Special Energy":
			if _gsm.attach_energy(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui_after_successful_action(false, cp)
				_suppress_slot_followup_click(slot_id, "attach_energy_target")
			else:
				var energy_reason: String = _gsm.rule_validator.get_attach_energy_unusable_reason(gs, cp, card, _gsm.effect_processor)
				if energy_reason == "":
					energy_reason = "这张能量当前不能附着到这个目标。"
				_show_invalid_action_message({
					"title": "%s 现在不能附着" % cd.name,
					"reason": energy_reason,
					"detail": "通常每回合只能从手牌附着 1 次能量，并且只能附着给己方宝可梦。",
					"kind": "energy",
				})
		elif cd.card_type == "Tool":
			if _gsm.attach_tool(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui_after_successful_action(false, cp)
				_suppress_slot_followup_click(slot_id, "attach_tool_target")
			else:
				_show_invalid_action_message({
					"title": "%s 现在不能附着" % cd.name,
					"reason": _gsm.rule_validator.get_attach_tool_unusable_reason(gs, cp, target_slot, _gsm.effect_processor, card),
					"detail": "宝可梦道具需要附着到有效目标上，且目标通常不能已经有道具。",
					"kind": "tool",
				})
		return

	if slot_id.begins_with("my_"):
		_show_pokemon_action_dialog(cp, target_slot, slot_id == "my_active")



func _start_slot_touch_action_press(slot_id: String, position: Vector2, touch_index: int) -> void:
	_cancel_slot_touch_long_press(false)
	_slot_touch_long_press_active = true
	_slot_touch_long_press_slot_id = slot_id
	_slot_touch_long_press_index = touch_index
	_slot_touch_long_press_start = position
	_slot_touch_long_press_consumed = false



func _show_setup_bench_dialog(pi: int) -> void:
	_battle_dialog_controller.call("show_setup_bench_dialog", self, pi)



func _setup_player_active(pi: int) -> void:
	var target_view_player := _preferred_live_view_player(pi)
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != 0:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "setup_active_follow_up")
			_view_player = target_view_player
			_refresh_ui()
			_show_setup_active_dialog(pi)
		)
	else:
		_view_player = target_view_player
		_refresh_ui()
		_show_setup_active_dialog(pi)



func _can_use_granted_attack(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	return _gsm.rule_validator.can_use_granted_attack(
		_gsm.game_state,
		player_index,
		slot,
		granted_attack,
		_gsm.effect_processor
	)



func _get_granted_attack_unusable_reason(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> String:
	if _gsm == null or _gsm.game_state == null:
		return "当前无法执行该操作"
	return _gsm.rule_validator.get_granted_attack_unusable_reason(
		_gsm.game_state,
		player_index,
		slot,
		granted_attack,
		_gsm.effect_processor
	)



func _retreat_requires_energy_choice(active: PokemonSlot, retreat_cost: int) -> bool:
	if active == null or retreat_cost <= 0:
		return false
	if active.attached_energy.size() <= 1:
		return false
	return _retreat_has_valid_partial_subset(active.attached_energy, retreat_cost, 0, 0, 0)



func _show_retreat_energy_dialog(cp: int, active: PokemonSlot, retreat_cost: int) -> void:
	if _gsm == null or _gsm.game_state == null or active == null:
		return
	var player: PlayerState = _gsm.game_state.players[cp]
	var energy_options: Array[CardInstance] = active.attached_energy.duplicate()
	var choice_labels: Array[String] = []
	for energy: CardInstance in energy_options:
		var label := energy.card_data.name
		var provided := _gsm.effect_processor.get_energy_colorless_count(energy, _gsm.game_state)
		if provided > 1:
			label += " (%d)" % provided
		choice_labels.append(label)
	_pending_choice = "retreat_energy"
	_show_dialog("选择要弃掉的能量", choice_labels, {
		"player": cp,
		"bench": player.bench,
		"energy_options": energy_options,
		"retreat_cost": retreat_cost,
		"allow_cancel": true,
		"min_select": 1,
		"max_select": energy_options.size(),
		"presentation": "cards",
		"card_items": energy_options,
		"choice_labels": choice_labels,
		"prompt_type": "retreat_energy",
	})



func _show_retreat_bench_choice(cp: int, energy_discard: Array[CardInstance]) -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	var player: PlayerState = _gsm.game_state.players[cp]
	_pending_choice = "retreat_bench"
	_dialog_data = {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard.duplicate(),
		"allow_cancel": true,
		"min_select": 1,
		"max_select": 1,
		"prompt_type": "retreat_bench",
	}
	_show_field_slot_choice("选择接替撤退的备战宝可梦", player.bench, _dialog_data)



func _default_retreat_energy_selection(active: PokemonSlot, retreat_cost: int) -> Array[CardInstance]:
	if active == null or retreat_cost <= 0:
		return []
	return active.attached_energy.duplicate()



func _match_end_quick_review_configured() -> bool:
	var config := GameManager.get_battle_review_api_config()
	return str(config.get("endpoint", "")).strip_edges() != "" and str(config.get("api_key", "")).strip_edges() != ""



func _match_end_quick_review_model_label() -> String:
	var config := GameManager.get_battle_review_api_config()
	return GameManager.get_battle_review_model_label(str(config.get("model", "")))



func _ensure_match_end_quick_review_service() -> void:
	if _match_end_quick_review_service != null:
		return
	var service: RefCounted = MatchEndQuickReviewServiceScript.new()
	_match_end_quick_review_service = service
	if service == null:
		return
	if service.has_signal("status_changed") and not service.status_changed.is_connected(Callable(self, "_on_match_end_quick_review_status_changed")):
		service.status_changed.connect(Callable(self, "_on_match_end_quick_review_status_changed"))
	if service.has_signal("quick_review_completed") and not service.quick_review_completed.is_connected(Callable(self, "_on_match_end_quick_review_completed")):
		service.quick_review_completed.connect(Callable(self, "_on_match_end_quick_review_completed"))



func _build_match_end_quick_review_payload() -> Dictionary:
	return _match_end_quick_review_builder.call("build_payload", _match_end_stats, _view_player, _battle_review_match_dir)



func _on_match_end_quick_review_completed(result: Dictionary) -> void:
	var display_result := result.duplicate(true)
	if str(display_result.get("status", "")) == "failed":
		display_result = _match_end_quick_review_fallback_from_failure(display_result)
	_match_end_quick_review_result = display_result
	_match_end_quick_review_busy = false
	_match_end_quick_review_progress_text = ""
	_match_end_quick_review_requested = true
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("refresh_match_end_screen")



func _local_match_end_quick_review() -> Dictionary:
	var review: Variant = _match_end_quick_review_builder.call("local_review", _match_end_stats, _battle_review_winner_index, _view_player, _battle_review_match_dir)
	return review if review is Dictionary else {}



func _ensure_battle_advice_coordinator() -> void:
	if _battle_advice_coordinator == null:
		_battle_advice_coordinator = BattleAdviceCoordinatorScript.new()
	if not bool(_battle_advice_coordinator.call("is_configured")):
		_battle_advice_coordinator.call("setup", _battle_scene_context, _battle_advice_controller, self)



func _show_match_end_dialog(winner_index: int, reason: String) -> void:
	_restore_non_battle_orientation_for_match_end()
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("show_match_end_screen", winner_index, reason)
	_sync_battle_overlay_state_from_scene()



func _battle_discussion_popup_frame_rect() -> Rect2:
	var frame_rect := _portrait_layout_frame_rect
	if frame_rect.size != Vector2.ZERO:
		return frame_rect
	var viewport_size := _portrait_dialog_viewport_size()
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(390, 844)
	return Rect2(Vector2.ZERO, viewport_size)



func _build_battle_state_snapshot() -> Dictionary:
	var snapshot_variant: Variant = _battle_recording_controller.call("build_battle_state_snapshot", self)
	return snapshot_variant if snapshot_variant is Dictionary else {}



func _stop_battle_discussion_flash() -> void:
	if _battle_discussion_flash_tween != null:
		_battle_discussion_flash_tween.kill()
		_battle_discussion_flash_tween = null
	if _btn_battle_discuss_ai != null and is_instance_valid(_btn_battle_discuss_ai):
		_btn_battle_discuss_ai.self_modulate = Color(1.0, 1.0, 1.0, 1.0)



func _can_accept_live_action() -> bool:
	return not _is_review_mode() and not _draw_reveal_active and not _ai_llm_waiting and not _is_ai_action_pause_active() and _pending_choice != "take_prize"



func _refresh_hand() -> void:
	_trace_portrait_layout_stage("scene.refresh_hand.before_display")
	_ensure_battle_display_coordinator()
	_battle_display_coordinator.call("refresh_hand")
	_trace_portrait_layout_stage("scene.refresh_hand.after_display")
	_finalize_portrait_layout_constraints()
	_trace_portrait_layout_stage("scene.refresh_hand.after_finalize")
	call_deferred("_deferred_finalize_portrait_layout_constraints")



func _start_llm_wait_hud(turn_number: int) -> void:
	_ai_llm_wait_started_msec = Time.get_ticks_msec()
	_ai_llm_wait_anim_token += 1
	_ensure_llm_wait_label()
	_update_llm_wait_hud(turn_number)
	_schedule_llm_wait_hud_tick(_ai_llm_wait_anim_token, turn_number)



func _stop_llm_wait_hud() -> void:
	_ai_llm_wait_anim_token += 1
	_ai_llm_wait_started_msec = 0
	if _ai_llm_wait_label != null and is_instance_valid(_ai_llm_wait_label):
		_ai_llm_wait_label.visible = false
	_set_llm_wait_turn_label_suppressed(false)



func _set_pending_handover_action(action: Callable, reason: String) -> void:
	var was_valid: bool = _pending_handover_action.is_valid()
	var is_valid: bool = action.is_valid()
	_pending_handover_action = action
	_runtime_log(
		"handover_action",
		"reason=%s valid=%s was_valid=%s %s" % [reason, str(is_valid), str(was_valid), _state_snapshot()]
	)



func _show_next_effect_interaction_step() -> void:
	_battle_effect_interaction_controller.call("show_next_effect_interaction_step", self)



func _ensure_battle_recording_coordinator() -> void:
	if _battle_recording_coordinator == null:
		_battle_recording_coordinator = BattleRecordingCoordinatorScript.new()
	if not bool(_battle_recording_coordinator.call("is_configured")):
		_battle_recording_coordinator.call("setup", _battle_scene_context, _battle_recording_controller, self)



func _update_battle_layout_button() -> void:
	if _btn_battle_layout == null:
		return
	match GameManager.sanitize_battle_layout_mode(str(GameManager.get("battle_layout_mode"))):
		GameManager.BATTLE_LAYOUT_PORTRAIT:
			_btn_battle_layout.text = "竖屏"
		GameManager.BATTLE_LAYOUT_LANDSCAPE:
			_btn_battle_layout.text = "横屏"
		_:
			_btn_battle_layout.text = "自动"



func _request_portrait_layout_debug_overlay_refresh() -> void:
	_ensure_battle_layout_debug_reporter()
	_battle_layout_debug_reporter.call("request_portrait_layout_debug_overlay_refresh")



func _style_vstar_lost_huds() -> void:
	_ensure_battle_surface_styler()
	_battle_surface_styler.call("style_vstar_lost_huds")



func _style_end_turn_hud_buttons() -> void:
	_style_end_turn_hud_button(_hud_end_turn_btn if _hud_end_turn_btn != null else find_child("HudEndTurnBtn", true, false) as Button, true)
	_style_end_turn_hud_button(_btn_end_turn if _btn_end_turn != null else find_child("BtnEndTurn", true, false) as Button, false)
	_refresh_end_turn_hud_button_state()



func _load_battle_backdrop_texture() -> Texture2D:
	return _battle_layout_controller.call(
		"load_battle_backdrop_texture",
		GameManager.selected_battle_background,
		BATTLE_BACKDROP_RESOURCE
	)


func _ensure_battle_stadium_backdrop_coordinator() -> void:
	if _battle_stadium_backdrop_coordinator == null:
		_battle_stadium_backdrop_coordinator = BattleStadiumBackdropCoordinatorScript.new()
	_battle_stadium_backdrop_coordinator.call("setup", self)


func _sync_stadium_backdrop(gs: GameState = null, immediate: bool = false) -> void:
	_ensure_battle_stadium_backdrop_coordinator()
	var live_state := gs
	if live_state == null and _gsm != null:
		live_state = _gsm.game_state
	_battle_stadium_backdrop_coordinator.call("sync_stadium_backdrop", live_state, immediate)



func _bench_display_size_for_player(player_index: int) -> int:
	var display_size := BENCH_SIZE
	if _gsm != null and _gsm.game_state != null and player_index >= 0 and player_index < _gsm.game_state.players.size():
		var gs: GameState = _gsm.game_state
		var player: PlayerState = gs.players[player_index]
		if player != null:
			display_size = maxi(display_size, player.bench.size())
			display_size = maxi(display_size, BenchLimit.get_bench_limit_for_player(gs, player))
	return clampi(display_size, BENCH_SIZE, MAX_BENCH_SIZE)


func _current_bench_display_sizes() -> Dictionary:
	var my_player_index := clampi(_view_player, 0, 1)
	var opp_player_index := 1 - my_player_index
	return {
		"my": _bench_display_size_for_player(my_player_index),
		"opp": _bench_display_size_for_player(opp_player_index),
	}


func _current_bench_display_size() -> int:
	var display_sizes := _current_bench_display_sizes()
	return maxi(int(display_sizes.get("my", BENCH_SIZE)), int(display_sizes.get("opp", BENCH_SIZE)))



func _set_bench_panel_visible(panel: Control, visible: bool) -> void:
	if panel == null:
		return
	panel.visible = visible
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE



func _schedule_responsive_layout_stabilization(frames: int = RESPONSIVE_LAYOUT_STABILIZATION_FRAMES) -> void:
	if frames <= 0:
		return
	_responsive_layout_stabilization_frames_remaining = maxi(
		_responsive_layout_stabilization_frames_remaining,
		frames
	)
	if is_inside_tree():
		set_process(true)



func _ensure_bench_container_panel_capacity(
	bench: HBoxContainer,
	panel_prefix: String,
	label_prefix: String,
	capacity: int
) -> void:
	if bench == null:
		return
	while bench.get_child_count() < capacity:
		var index := bench.get_child_count()
		var panel := PanelContainer.new()
		panel.name = "%s%d" % [panel_prefix, index]
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.clip_contents = false
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var label := RichTextLabel.new()
		label.name = "%s%d" % [label_prefix, index]
		label.fit_content = true
		label.scroll_active = false
		label.bbcode_enabled = true
		label.text = ""
		label.visible = false
		panel.add_child(label)
		bench.add_child(panel)
		if bench.owner != null:
			panel.owner = bench.owner
			label.owner = bench.owner

func _ensure_battle_deck_shuffle_animator() -> void:
	if _battle_deck_shuffle_animator == null:
		_battle_deck_shuffle_animator = BattleDeckShuffleAnimatorScript.new()
	_battle_deck_shuffle_animator.call("setup", self)



func _try_take_prize_from_slot(player_index: int, slot_index: int) -> void:
	if _gsm == null:
		return
	if _pending_choice != "take_prize" or _pending_prize_player_index != player_index:
		return
	if _pending_prize_animating:
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	var prize_card: CardInstance = player.get_prize_at_slot(slot_index)
	if prize_card == null:
		return
	var prize_view: BattleCardView = _get_prize_slot_view(player_index, slot_index)
	if prize_view == null:
		return
	_pending_prize_animating = true
	_animate_prize_flip(prize_view, prize_card, func() -> void:
		_pending_choice = ""
		_pending_prize_player_index = -1
		_pending_prize_remaining = 0
		var resolved: bool = _gsm.resolve_take_prize(player_index, slot_index)
		_pending_prize_animating = false
		if resolved and _pending_choice == "take_prize":
			_focus_prize_panel(_pending_prize_player_index)
		elif resolved:
			_clear_prize_selection()
		_refresh_ui()
		_check_two_player_handover()
		_maybe_run_ai()
	)



func _show_prize_cards(player_index: int, title: String) -> void:
	_battle_display_controller.call("show_prize_cards", self, player_index, title)



func _ensure_game_state_machine() -> void:
	if _gsm == null:
		_gsm = _build_game_state_machine()
		_sync_battle_scene_context_runtime()



func _refresh_replay_controls() -> void:
	_battle_replay_controller.call(
		"refresh_controls",
		_battle_scene_refs,
		_battle_mode,
		_replay_current_turn_index,
		_replay_turn_numbers,
		_replay_loaded_raw_snapshot
	)



func _append_portrait_button_action(actions: Array[Dictionary], source_button: Button, fallback_text: String) -> void:
	if source_button == null or not _portrait_top_action_was_visible(source_button):
		return
	var label := source_button.text if source_button.text != "" else fallback_text
	actions.append({
		"text": label,
		"disabled": source_button.disabled,
		"callback": Callable(self, "_press_top_action_button").bind(source_button),
	})



func _portrait_actions_popup_content_height(list: VBoxContainer) -> float:
	if list == null:
		return 0.0
	var height := 0.0
	var visible_controls := 0
	for child: Node in list.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var child_height := control.custom_minimum_size.y
		if child_height <= 0.0:
			child_height = control.get_combined_minimum_size().y
		height += child_height
		visible_controls += 1
	if visible_controls > 1:
		height += float(list.get_theme_constant("separation")) * float(visible_controls - 1)
	return height



func _restore_portrait_popup_text_metrics() -> void:
	for root: Node in _portrait_popup_text_roots():
		_apply_popup_text_scale(root, 1.0)



func _apply_portrait_dialog_width_metrics() -> void:
	var dialog_box := _dialog_box if _dialog_box != null else find_child("DialogBox", true, false) as PanelContainer
	if dialog_box == null:
		return
	dialog_box.custom_minimum_size = Vector2(_portrait_dialog_width(_portrait_dialog_viewport_size()), dialog_box.custom_minimum_size.y)



func _apply_portrait_overlay_box_metrics() -> void:
	if not _is_portrait_popup_text_profile_active():
		return
	var viewport_size := _portrait_dialog_viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var near_width := _portrait_popup_near_width()
	var compact_width := _portrait_popup_compact_width()
	_apply_portrait_collection_box_metrics(viewport_size, near_width)
	_apply_portrait_detail_box_metrics(viewport_size, near_width)
	_apply_portrait_review_box_metrics(viewport_size, near_width)
	_apply_portrait_compact_modal_metrics(viewport_size, compact_width)
	_apply_portrait_match_end_box_metrics(near_width)



func _apply_portrait_scrollbar_metrics() -> void:
	if not _is_portrait_popup_text_profile_active():
		_restore_portrait_scrollbar_metrics()
		return
	var hand_scroll := _hand_scroll if _hand_scroll != null else find_child("HandScroll", true, false) as ScrollContainer
	if hand_scroll != null:
		_configure_hand_drag_scroll(hand_scroll)
	for root: Node in _portrait_popup_text_roots():
		HudThemeScript.apply_scrollbars_recursive(root, _portrait_scrollbar_profile())
	_refresh_card_gallery_scrollbar_visibility()



func _card_scroll_height_with_scrollbar(card_height: float) -> float:
	return maxf(0.0, card_height) + _card_scrollbar_clearance_height()



func _screen_position_to_battle_local(screen_position: Vector2) -> Vector2:
	if not _rotated_portrait_canvas_active:
		return screen_position
	var physical_size := _rotated_portrait_physical_viewport_size
	if physical_size == Vector2.ZERO:
		physical_size = get_viewport_rect().size
	return Vector2(screen_position.y, physical_size.x - screen_position.x)



func _control_rect_in_battle_local(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var control_size := control.size
	if control_size == Vector2.ZERO:
		control_size = control.custom_minimum_size
	if control_size == Vector2.ZERO:
		return Rect2()
	var local_transform := control.get_global_transform()
	if control != self:
		local_transform = get_global_transform().affine_inverse() * control.get_global_transform()
	return Rect2(local_transform.origin, control_size)



func _first_empty_own_bench_slot_id() -> String:
	if _gsm == null or _gsm.game_state == null:
		return ""
	var player_index: int = _gsm.game_state.current_player_index
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return ""
	var player: PlayerState = _gsm.game_state.players[player_index]
	if player == null:
		return ""
	if player_index != _view_player:
		return ""
	var bench_limit := _current_player_bench_limit()
	for index: int in bench_limit:
		if index >= player.bench.size():
			return "my_bench_%d" % index
		var slot: PokemonSlot = player.bench[index]
		if slot == null or slot.pokemon_stack.is_empty():
			return "my_bench_%d" % index
	return ""



func _is_slot_followup_click_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return true
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		return mbe.button_index == MOUSE_BUTTON_LEFT
	return false



func _resolve_top_row_gap(viewport_size: Vector2) -> int:
	return clampi(int(viewport_size.x * 0.004), 4, 8)



func _resolve_top_action_gap(viewport_size: Vector2) -> int:
	return clampi(int(viewport_size.x * 0.003), 3, 6)



func _slot_card_data_for_detail(slot_id: String) -> CardData:
	var detail_state: GameState = _gsm.game_state if _gsm != null else null
	if detail_state == null:
		return null
	var detail_slot: PokemonSlot = _slot_from_id(slot_id, detail_state)
	if detail_slot == null or detail_slot.pokemon_stack.is_empty():
		return null
	return detail_slot.get_card_data()



func _show_card_detail(cd: CardData) -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("show_card_detail", cd)



func _try_play_to_bench(player_index: int, card: CardInstance, _slot_id: String) -> void:
	var gs: GameState = _gsm.game_state
	var bench_reason: String = _gsm.rule_validator.get_play_basic_to_bench_unusable_reason(gs, player_index, card)
	if bench_reason != "":
		_show_invalid_action_message({
			"title": "%s 现在不能放到备战区" % card.card_data.name,
			"reason": bench_reason,
			"detail": "基础宝可梦只能在主要阶段放到己方备战区，并且备战区需要有空位。",
			"kind": "pokemon",
		})
		return
	var bench_effect: BaseEffect = _gsm.effect_processor.get_effect(card.card_data.effect_id)
	var bench_steps: Array[Dictionary] = []
	var is_bench_enter_ability := bench_effect != null and bench_effect.has_method("is_bench_enter_ability") and bool(bench_effect.call("is_bench_enter_ability"))
	if is_bench_enter_ability:
		bench_steps = bench_effect.get_interaction_steps(card, gs)
	var auto_trigger_bench_ability: bool = is_bench_enter_ability and bench_steps.is_empty()
	var should_start_bench_interaction: bool = is_bench_enter_ability and not bench_steps.is_empty()
	if _gsm.play_basic_to_bench(player_index, card, auto_trigger_bench_ability):
		if should_start_bench_interaction:
			var player: PlayerState = _gsm.game_state.players[player_index]
			var bench_slot: PokemonSlot = player.bench.back() if not player.bench.is_empty() else null
			if bench_slot != null:
				_start_effect_interaction("ability", player_index, bench_steps, bench_slot.get_top_card(), bench_slot, 0)
		_selected_hand_card = null
		_refresh_ui_after_successful_action(false, player_index)
		_suppress_slot_followup_click(_slot_id, "bench_basic_target", BENCH_PLAY_FOLLOWUP_CLICK_SUPPRESS_MSEC)
	else:
		_show_invalid_action_message({
			"title": "%s 现在不能放到备战区" % card.card_data.name,
			"reason": "无法将这只宝可梦放到备战区。",
			"detail": "请检查当前阶段、备战区空位和场上效果限制。",
			"kind": "pokemon",
		})



func _try_handle_field_interaction_slot_click(slot_id: String, _target_slot: PokemonSlot) -> void:
	if not _is_field_interaction_active():
		return
	if not _field_interaction_slot_index_by_id.has(slot_id):
		return
	var target_index: int = int(_field_interaction_slot_index_by_id.get(slot_id, -1))
	if target_index < 0:
		return
	match _field_interaction_mode:
		"slot_select":
			_handle_field_slot_select_index(target_index)
		"assignment":
			_handle_field_assignment_target_index(target_index)
		"counter_distribution":
			_handle_counter_distribution_target(target_index)



func _show_pokemon_action_dialog(cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	_battle_dialog_controller.call("show_pokemon_action_dialog", self, cp, slot, include_attacks)



func _try_start_evolve_trigger_ability_interaction(player_index: int, slot: PokemonSlot) -> void:
	if _gsm == null or slot == null or slot.get_top_card() == null:
		return
	var steps: Array[Dictionary] = _gsm.get_evolve_ability_interaction_steps(slot)
	if steps.is_empty():
		return
	_start_effect_interaction("ability", player_index, steps, slot.get_top_card(), slot, 0)



func _card_instance_label(card: CardInstance) -> String:
	return str(_battle_runtime_log_controller.call("card_instance_label", card))



func _cancel_slot_touch_long_press(clear_suppression: bool = true) -> void:
	if _slot_touch_long_press_timer != null:
		_slot_touch_long_press_timer.stop()
	_slot_touch_long_press_active = false
	_slot_touch_long_press_slot_id = ""
	_slot_touch_long_press_index = -1
	_slot_touch_long_press_consumed = false
	if clear_suppression:
		_suppress_next_slot_left_click_id = ""



func _show_setup_active_dialog(pi: int) -> void:
	_battle_dialog_controller.call("show_setup_active_dialog", self, pi)



func _preferred_live_view_player(target_player: int) -> int:
	if GameManager.current_mode == GameManager.GameMode.VS_AI:
		return 0
	return target_player



func _show_handover_prompt(target_player: int, follow_up: Callable = Callable()) -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("show_handover_prompt", target_player, follow_up)
	_sync_battle_overlay_state_from_scene()



func _set_handover_panel_visible(visible_state: bool, reason: String) -> void:
	if _handover_panel == null:
		return
	if _handover_panel.visible == visible_state:
		_runtime_log(
			"handover_visibility_noop",
			"visible=%s reason=%s %s" % [str(visible_state), reason, _state_snapshot()]
		)
		return
	_handover_panel.visible = visible_state
	_runtime_log(
		"handover_visibility",
		"visible=%s reason=%s %s" % [str(visible_state), reason, _state_snapshot()]
	)



func _retreat_has_valid_partial_subset(
	attached_energy: Array[CardInstance],
	retreat_cost: int,
	index: int,
	provided: int,
	used_count: int
) -> bool:
	if provided >= retreat_cost:
		return used_count > 0 and used_count < attached_energy.size()
	if index >= attached_energy.size():
		return false
	var next_provided := provided + _gsm.effect_processor.get_energy_colorless_count(attached_energy[index], _gsm.game_state)
	if _retreat_has_valid_partial_subset(attached_energy, retreat_cost, index + 1, next_provided, used_count + 1):
		return true
	return _retreat_has_valid_partial_subset(attached_energy, retreat_cost, index + 1, provided, used_count)

func _show_dialog(title: String, items: Array, extra_data: Dictionary = {}) -> void:
	_battle_dialog_controller.call("show_dialog", self, title, items, extra_data)


func _show_field_slot_choice(title: String, items: Array, data: Dictionary = {}) -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("show_field_slot_choice", title, items, data)
	_sync_battle_interaction_state_from_scene()



func _match_end_quick_review_fallback_from_failure(failed_result: Dictionary) -> Dictionary:
	if _match_end_stats.is_empty():
		_match_end_stats = _build_match_end_stats(_battle_review_winner_index, _battle_review_reason)
	var fallback: Variant = _match_end_quick_review_builder.call("fallback_from_failure", failed_result, _match_end_stats, _battle_review_winner_index, _view_player, _battle_review_match_dir)
	return fallback if fallback is Dictionary else {}



func _restore_non_battle_orientation_for_match_end() -> void:
	if _match_end_non_battle_orientation_restored:
		return
	if not _should_restore_non_battle_orientation_for_match_end():
		return
	_match_end_non_battle_orientation_restored = true
	GameManager.apply_non_battle_orientation()



func _is_review_mode() -> bool:
	return _battle_mode == "review_readonly"



func _ensure_llm_wait_label() -> void:
	if _ai_llm_wait_label != null and is_instance_valid(_ai_llm_wait_label):
		if _ai_llm_wait_label.get_parent() != self:
			var old_parent := _ai_llm_wait_label.get_parent()
			if old_parent != null:
				old_parent.remove_child(_ai_llm_wait_label)
			add_child(_ai_llm_wait_label)
		_layout_llm_wait_label()
		return
	var label := Label.new()
	label.name = "LlmThinkingHudLabel"
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _hand_title != null:
		label.theme_type_variation = _hand_title.theme_type_variation
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 1.0))
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.z_index = 85
	add_child(label)
	_ai_llm_wait_label = label
	_layout_llm_wait_label()



func _schedule_llm_wait_hud_tick(token: int, turn_number: int) -> void:
	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		if token != _ai_llm_wait_anim_token:
			return
		if not _ai_llm_waiting or _ai_llm_turn_requested != turn_number:
			return
		_update_llm_wait_hud(turn_number)
		_schedule_llm_wait_hud_tick(token, turn_number)
	)



func _ensure_battle_surface_styler() -> void:
	if _battle_surface_styler == null:
		_battle_surface_styler = BattleSurfaceStylerScript.new()
	_battle_surface_styler.call("setup", self)



func _style_end_turn_hud_button(button: Button, prominent: bool) -> void:
	if button == null:
		return
	var texture_rect := button.get_node_or_null("EndTurnImage") as TextureRect
	if texture_rect != null:
		button.remove_child(texture_rect)
		texture_rect.queue_free()
	button.text = "结束我的回合" if prominent else "结束回合"
	button.tooltip_text = "结束我的回合"
	button.clip_contents = false
	button.clip_text = true
	button.icon = null
	button.add_theme_stylebox_override("normal", _end_turn_hud_button_style(false, false, false))
	button.add_theme_stylebox_override("hover", _end_turn_hud_button_style(true, false, false))
	button.add_theme_stylebox_override("pressed", _end_turn_hud_button_style(true, true, false))
	button.add_theme_stylebox_override("disabled", _end_turn_hud_button_style(false, false, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.97, 0.98, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.94, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.56, 0.48, 0.88))
	if prominent:
		var min_font_size := maxi(16, roundi(12.0 * LANDSCAPE_STADIUM_ACTION_FONT_SCALE))
		button.add_theme_font_size_override("font_size", maxi(button.get_theme_font_size("font_size"), min_font_size))



func _clear_prize_selection() -> void:
	_close_portrait_prize_dialog()
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("clear_prize_selection")
	_sync_battle_dialog_state_from_scene()
	_sync_battle_overlay_state_from_scene()
	_sync_portrait_prize_hud_visibility()



func _focus_prize_panel(player_index: int) -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("focus_prize_panel", player_index)



func _get_prize_slot_view(player_index: int, slot_index: int) -> BattleCardView:
	var slots: Array[BattleCardView] = _my_prize_slots if player_index == _view_player else _opp_prize_slots
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]



func _animate_prize_flip(prize_view: BattleCardView, prize_card: CardInstance, on_complete: Callable) -> void:
	if prize_view == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	if not is_inside_tree():
		prize_view.setup_from_instance(prize_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
		prize_view.set_face_down(false)
		if on_complete.is_valid():
			on_complete.call()
		return
	prize_view.pivot_offset = prize_view.size * 0.5
	var tween := create_tween()
	tween.tween_property(prize_view, "scale:x", 0.05, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		prize_view.setup_from_instance(prize_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
		prize_view.set_face_down(false)
		prize_view.set_selected(true)
	)
	tween.tween_property(prize_view, "scale:x", 1.0, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.08)
	tween.finished.connect(func() -> void:
		prize_view.scale = Vector2.ONE
		if on_complete.is_valid():
			on_complete.call()
	)



func _sync_battle_scene_context_runtime() -> void:
	if _battle_scene_context == null:
		return
	_battle_scene_context.call("set_game_state_machine", _gsm)
	_battle_scene_context.call("set_view_player", _view_player)
	_battle_scene_context.call("set_battle_mode", _battle_mode)
	_sync_battle_dialog_state_from_scene()
	_sync_battle_interaction_state_from_scene()
	_sync_battle_replay_state_from_scene()
	_sync_battle_overlay_state_from_scene()
	_sync_battle_ai_state_from_scene()
	_sync_battle_advice_state_from_scene()
	_sync_battle_recording_state_from_scene()
	_sync_battle_effect_state_from_scene()



func _build_game_state_machine() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.state_changed.connect(Callable(self, "_on_state_changed"))
	gsm.action_logged.connect(Callable(self, "_on_action_logged"))
	gsm.player_choice_required.connect(Callable(self, "_on_player_choice_required"))
	gsm.game_over.connect(Callable(self, "_on_game_over"))
	gsm.coin_flipper.coin_flipped.connect(Callable(self, "_on_coin_flipped"))
	return gsm



func _portrait_top_action_was_visible(button: Button) -> bool:
	if button == null:
		return false
	if button.has_meta("_portrait_previous_top_action_visible"):
		return bool(button.get_meta("_portrait_previous_top_action_visible"))
	return button.visible



func _apply_popup_text_scale(node: Node, scale_factor: float) -> void:
	if _battle_popup_text_scaler == null:
		_battle_popup_text_scaler = BattlePopupTextScalerScript.new()
	_battle_popup_text_scaler.call("apply_popup_text_scale", node, scale_factor)



func _portrait_dialog_width(viewport_size: Vector2) -> float:
	return _portrait_popup_width_for_ratio(PORTRAIT_POPUP_NEAR_WIDTH_RATIO, viewport_size)



func _portrait_popup_compact_width() -> float:
	return _portrait_popup_width_for_ratio(PORTRAIT_POPUP_COMPACT_WIDTH_RATIO, _portrait_dialog_viewport_size())



func _apply_portrait_collection_box_metrics(viewport_size: Vector2, near_width: float) -> void:
	_apply_discard_collection_metrics(viewport_size, near_width)



func _apply_portrait_detail_box_metrics(viewport_size: Vector2, near_width: float) -> void:
	var detail_box := get_node_or_null("DetailOverlay/DetailCenter/DetailBox") as PanelContainer
	if detail_box == null:
		return
	var detail_gap := clampi(int(viewport_size.x * 0.012), 10, 18)
	var detail_card_size := _detail_card_size
	var available_for_text := near_width - detail_card_size.x - float(detail_gap) - 72.0
	if available_for_text < 160.0:
		var reduced_card_width := clampf(near_width * 0.40, 118.0, _detail_card_size.x)
		detail_card_size = Vector2(roundf(reduced_card_width), roundf(reduced_card_width / CARD_ASPECT))
		available_for_text = near_width - detail_card_size.x - float(detail_gap) - 72.0
	var detail_text_width := maxf(available_for_text + 28.0, 170.0)
	var target_height := maxf(detail_card_size.y + 96.0, viewport_size.y * 0.46)
	var max_height := maxf(viewport_size.y * PORTRAIT_POPUP_DETAIL_MAX_HEIGHT_RATIO, 360.0)
	detail_box.custom_minimum_size = Vector2(near_width, minf(target_height, max_height))
	var detail_body := get_node_or_null("DetailOverlay/DetailCenter/DetailBox/DetailVBox/DetailBody") as HBoxContainer
	if detail_body != null:
		detail_body.add_theme_constant_override("separation", detail_gap)
	if _detail_card_view != null:
		_detail_card_view.custom_minimum_size = detail_card_size
	if _detail_content != null:
		_detail_content.custom_minimum_size = Vector2(maxf(detail_text_width - 28.0, 142.0), maxf(detail_card_size.y - 24.0, 200.0))
	var detail_text_panel := get_node_or_null("DetailOverlay/DetailCenter/DetailBox/DetailVBox/DetailBody/DetailTextPanel") as PanelContainer
	if detail_text_panel != null:
		detail_text_panel.custom_minimum_size = Vector2(detail_text_width, detail_card_size.y)



func _apply_portrait_review_box_metrics(viewport_size: Vector2, near_width: float) -> void:
	var review_box := get_node_or_null("ReviewOverlay/ReviewCenter/ReviewBox") as PanelContainer
	if review_box == null:
		return
	review_box.custom_minimum_size = Vector2(near_width, clampf(viewport_size.y * 0.70, 420.0, maxf(viewport_size.y - 24.0, 420.0)))



func _apply_portrait_compact_modal_metrics(viewport_size: Vector2, compact_width: float) -> void:
	var handover_box := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox") as PanelContainer
	if handover_box != null:
		handover_box.custom_minimum_size = Vector2(compact_width, maxf(220.0, viewport_size.y * 0.22))
	var handover_label := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox/HandoverVBox/HandoverLbl") as Label
	if handover_label != null:
		handover_label.custom_minimum_size = Vector2(maxf(compact_width - 48.0, 220.0), 72.0)
	var handover_button := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox/HandoverVBox/HandoverBtn") as Button
	if handover_button != null:
		handover_button.custom_minimum_size = Vector2(maxf(compact_width - 96.0, 180.0), maxf(PORTRAIT_POPUP_MIN_BUTTON_HEIGHT, 68.0))
	var coin_box := get_node_or_null("CoinFlipOverlay/CoinCenter/CoinBox") as PanelContainer
	if coin_box != null:
		coin_box.custom_minimum_size = Vector2(compact_width, maxf(150.0, viewport_size.y * 0.16))
	var coin_button := get_node_or_null("CoinFlipOverlay/CoinCenter/CoinBox/CoinVBox/CoinOkBtn") as Button
	if coin_button != null:
		coin_button.custom_minimum_size = Vector2(maxf(compact_width - 112.0, 160.0), PORTRAIT_POPUP_MIN_BUTTON_HEIGHT)



func _apply_portrait_match_end_box_metrics(_near_width: float) -> void:
	var match_end_overlay := get("_match_end_overlay") as Panel
	if match_end_overlay == null:
		return
	var viewport_size := _portrait_dialog_viewport_size()
	var near_width := _near_width if _near_width > 0.0 else _portrait_popup_near_width()
	var target_height := _portrait_match_end_review_modal_height(viewport_size)
	var match_end_box := match_end_overlay.get_node_or_null("MatchEndCenter/MatchEndBox") as PanelContainer
	if match_end_box != null:
		match_end_box.custom_minimum_size = Vector2(near_width, target_height)
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = Color(0.035, 0.065, 0.09, 0.98)
		box_style.border_color = Color(0.36, 0.86, 1.0, 0.92)
		box_style.set_border_width_all(2)
		box_style.set_corner_radius_all(22)
		match_end_box.add_theme_stylebox_override("panel", box_style)
	var return_button := get("_match_end_return_button") as Button
	if return_button != null:
		_style_hud_button(return_button)
		return_button.custom_minimum_size = Vector2(maxf(near_width - 96.0, 180.0), maxf(PORTRAIT_POPUP_MIN_BUTTON_HEIGHT, 68.0))
		return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return_button.add_theme_font_size_override("font_size", 20)


func _portrait_match_end_review_modal_height(viewport_size: Vector2) -> float:
	return minf(maxf(520.0, viewport_size.y * 0.62), maxf(viewport_size.y - 24.0, 520.0))



func _restore_portrait_scrollbar_metrics() -> void:
	var hand_scroll := _hand_scroll if _hand_scroll != null else find_child("HandScroll", true, false) as ScrollContainer
	if hand_scroll != null:
		_configure_hand_drag_scroll(hand_scroll)
	for root: Node in _portrait_popup_text_roots():
		HudThemeScript.apply_scrollbars_recursive(root, "auto")
	_refresh_card_gallery_scrollbar_visibility()



func _card_scrollbar_clearance_height() -> float:
	return float(HudThemeScript.scrollbar_thickness_for_profile(_active_card_scrollbar_profile()) + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING)



func _current_player_bench_limit() -> int:
	if _gsm == null or _gsm.game_state == null:
		return BENCH_SIZE
	var gs: GameState = _gsm.game_state
	var player_index: int = gs.current_player_index
	if player_index < 0 or player_index >= gs.players.size():
		return BENCH_SIZE
	return clampi(BenchLimit.get_bench_limit_for_player(gs, gs.players[player_index]), BENCH_SIZE, MAX_BENCH_SIZE)



func _slot_from_id(slot_id: String, gs: GameState) -> PokemonSlot:
	return _battle_display_controller.call("slot_from_id", self, slot_id, gs)



func _ensure_battle_card_detail_coordinator() -> void:
	if _battle_card_detail_coordinator == null:
		_battle_card_detail_coordinator = BattleCardDetailCoordinatorScript.new()
	_battle_card_detail_coordinator.call("setup", self)



func _suppress_slot_followup_click(slot_id: String, reason: String, duration_msec: int = -1) -> void:
	var resolved_duration := duration_msec if duration_msec >= 0 else SLOT_FOLLOWUP_CLICK_SUPPRESS_MSEC
	_suppress_slot_followup_click_id = slot_id
	_suppress_slot_followup_click_until_msec = Time.get_ticks_msec() + resolved_duration
	_runtime_log("slot_followup_click_suppressed", "slot=%s reason=%s duration=%d" % [slot_id, reason, resolved_duration])



func _refresh_ui_after_successful_action(check_handover: bool = false, action_player_index: int = -1) -> void:
	if has_method("_clear_hand_drag_click_suppression"):
		call("_clear_hand_drag_click_suppression", "successful_action")
	if has_method("_arm_hand_primary_release_fallback_window"):
		call("_arm_hand_primary_release_fallback_window", "successful_action")
	_hide_invalid_action_hint()
	_refresh_ui()
	if check_handover:
		_check_two_player_handover()
	if _should_pause_after_ai_action(action_player_index):
		_start_ai_action_pause()
		return
	_maybe_run_ai()



func _log(msg: String) -> void:
	if _log_list != null:
		if _log_list.get_parsed_text().length() > 12000:
			var full := _log_list.text
			var cut := full.find("\n", full.length() / 3)
			if cut >= 0:
				_log_list.text = full.substr(cut + 1)
		_log_list.append_text(msg + "\n")
	_runtime_log("ui_log", msg)


func _show_invalid_action_hint(payload: Variant) -> void:
	if _battle_invalid_action_hint_controller == null:
		_battle_invalid_action_hint_controller = BattleInvalidActionHintControllerScript.new()
	_battle_invalid_action_hint_controller.call("setup", self)
	_battle_invalid_action_hint_controller.call("show_hint", payload)


func _show_invalid_action_message(payload: Dictionary) -> void:
	var reason := str(payload.get("reason", "")).strip_edges()
	if reason == "":
		reason = "当前无法执行该操作。"
		payload["reason"] = reason
	_show_invalid_action_hint(payload)
	_log(reason)


func _hide_invalid_action_hint() -> void:
	if _battle_invalid_action_hint_controller == null:
		return
	_battle_invalid_action_hint_controller.call("hide_hint")



func _is_field_interaction_active() -> bool:
	_ensure_battle_interaction_coordinator()
	return bool(_battle_interaction_coordinator.call("is_field_interaction_active"))



func _handle_field_slot_select_index(target_index: int) -> void:
	_battle_interaction_controller.call("handle_field_slot_select_index", self, target_index)



func _handle_field_assignment_target_index(target_index: int) -> void:
	_battle_interaction_controller.call("handle_field_assignment_target_index", self, target_index)



func _handle_counter_distribution_target(target_index: int) -> void:
	_battle_interaction_controller.call("handle_counter_distribution_target", self, target_index)



func _start_effect_interaction(
	kind: String,
	player_index: int,
	steps: Array[Dictionary],
	card: CardInstance,
	slot: PokemonSlot = null,
	ability_index: int = -1,
	attack_data: Dictionary = {},
	attack_effects: Array[BaseEffect] = []
) -> void:
	_battle_effect_interaction_controller.call(
		"start_effect_interaction",
		self,
		kind,
		player_index,
		steps,
		card,
		slot,
		ability_index,
		attack_data,
		attack_effects
	)

func _state_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("state_snapshot", self))



func _build_match_end_stats(winner_index: int, reason: String) -> Dictionary:
	_ensure_battle_overlay_coordinator()
	var stats_variant: Variant = _battle_overlay_coordinator.call("build_match_end_stats", winner_index, reason)
	return stats_variant if stats_variant is Dictionary else {}



func _should_restore_non_battle_orientation_for_match_end() -> bool:
	# The result overlay is still rendered inside BattleScene; portrait mode must
	# keep the battle orientation until scene navigation exits the battle screen.
	return not _is_portrait_battle_layout_active()



func _update_llm_wait_hud(turn_number: int) -> void:
	if _ai_llm_wait_label == null or not is_instance_valid(_ai_llm_wait_label):
		return
	var elapsed_sec := 0
	if _ai_llm_wait_started_msec > 0:
		elapsed_sec = maxi(0, int((Time.get_ticks_msec() - _ai_llm_wait_started_msec) / 1000))
	var dot_count := (elapsed_sec % 4) + 1
	_ai_llm_wait_label.text = _llm_wait_hud_text_for_model(_current_llm_wait_model_id(), turn_number, elapsed_sec, dot_count)
	_ai_llm_wait_label.visible = true
	_set_llm_wait_turn_label_suppressed(true)
	_layout_llm_wait_label()



func _end_turn_hud_button_style(hover: bool, pressed: bool, disabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if disabled:
		style.bg_color = Color(0.05, 0.075, 0.07, 0.48)
		style.border_color = Color(0.32, 0.38, 0.32, 0.66)
	elif pressed:
		style.bg_color = Color(0.18, 0.24, 0.13, 0.92)
		style.border_color = Color(0.98, 0.88, 0.44, 1.0)
	elif hover:
		style.bg_color = Color(0.14, 0.22, 0.13, 0.9)
		style.border_color = Color(0.93, 1.0, 0.64, 0.98)
	else:
		style.bg_color = Color(0.11, 0.16, 0.12, 0.82)
		style.border_color = Color(0.73, 0.87, 0.62, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(style.border_color.r, style.border_color.g, style.border_color.b, 0.22 if hover else 0.12)
	style.shadow_size = 10 if hover else 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style



func _sync_battle_dialog_state_from_scene() -> void:
	if _battle_dialog_state == null:
		return
	_battle_dialog_state.set("pending_choice", _pending_choice)
	_battle_dialog_state.set("multi_selected_indices", _dialog_multi_selected_indices.duplicate())
	_battle_dialog_state.set("card_selected_indices", _dialog_card_selected_indices.duplicate())
	_battle_dialog_state.set("card_page", _dialog_card_page)
	_battle_dialog_state.set("card_page_size", _dialog_card_page_size)
	_battle_dialog_state.set("card_mode", _dialog_card_mode)
	_battle_dialog_state.set("assignment_mode", _dialog_assignment_mode)
	_battle_dialog_state.set("assignment_selected_source_index", _dialog_assignment_selected_source_index)
	_battle_dialog_state.set("assignment_assignments", _dialog_assignment_assignments.duplicate(true))
	_battle_dialog_state.set("items_data", _dialog_items_data.duplicate())
	_battle_dialog_state.set("data", _dialog_data.duplicate(true))



func _sync_battle_interaction_state_from_scene() -> void:
	if _battle_interaction_state == null:
		return
	_battle_interaction_state.set("mode", _field_interaction_mode)
	_battle_interaction_state.set("data", _field_interaction_data.duplicate(true))
	_battle_interaction_state.set("slot_index_by_id", _field_interaction_slot_index_by_id.duplicate())
	_battle_interaction_state.set("selected_indices", _field_interaction_selected_indices.duplicate())
	_battle_interaction_state.set("assignment_selected_source_index", _field_interaction_assignment_selected_source_index)
	_battle_interaction_state.set("assignment_entries", _field_interaction_assignment_entries.duplicate(true))
	_battle_interaction_state.set("position", _field_interaction_position)



func _sync_battle_replay_state_from_scene() -> void:
	if _battle_replay_state == null:
		return
	_battle_replay_state.set("match_dir", _replay_match_dir)
	_battle_replay_state.set("turn_numbers", _replay_turn_numbers.duplicate())
	_battle_replay_state.set("current_turn_index", _replay_current_turn_index)
	_battle_replay_state.set("entry_source", _replay_entry_source)
	_battle_replay_state.set("loaded_raw_snapshot", _replay_loaded_raw_snapshot.duplicate(true))
	_battle_replay_state.set("loaded_view_snapshot", _replay_loaded_view_snapshot.duplicate(true))



func _sync_battle_ai_state_from_scene() -> void:
	if _battle_ai_state == null:
		return
	_battle_ai_state.set("running", _ai_running)
	_battle_ai_state.set("step_scheduled", _ai_step_scheduled)
	_battle_ai_state.set("followup_requested", _ai_followup_requested)
	_battle_ai_state.set("turn_marker", _ai_turn_marker)
	_battle_ai_state.set("actions_this_turn", _ai_actions_this_turn)
	_battle_ai_state.set("action_pause_seconds", _ai_action_pause_seconds)
	_battle_ai_state.set("llm_waiting", _ai_llm_waiting)
	_battle_ai_state.set("llm_turn_requested", _ai_llm_turn_requested)
	_battle_ai_state.set("latest_opponent_action_text", _latest_opponent_action_text)
	_battle_ai_state.set("latest_opponent_action_turn_number", _latest_opponent_action_turn_number)



func _sync_battle_advice_state_from_scene() -> void:
	if _battle_advice_state == null:
		return
	_battle_advice_state.set("last_result", _battle_advice_last_result.duplicate(true))
	_battle_advice_state.set("busy", _battle_advice_busy)
	_battle_advice_state.set("progress_text", _battle_advice_progress_text)
	_battle_advice_state.set("initial_snapshot", _battle_advice_initial_snapshot.duplicate(true))
	_battle_advice_state.set("pinned", _battle_advice_pinned)
	_battle_advice_state.set("panel_collapsed", _battle_advice_panel_collapsed)
	_battle_advice_state.set("review_match_dir", _battle_review_match_dir)
	_battle_advice_state.set("review_last_review", _battle_review_last_review.duplicate(true))
	_battle_advice_state.set("review_busy", _battle_review_busy)
	_battle_advice_state.set("review_progress_text", _battle_review_progress_text)
	_battle_advice_state.set("review_winner_index", _battle_review_winner_index)
	_battle_advice_state.set("review_reason", _battle_review_reason)



func _sync_battle_recording_state_from_scene() -> void:
	if _battle_recording_state == null:
		return
	_battle_recording_state.set("output_root", _battle_recording_output_root)
	_battle_recording_state.set("started", _battle_recording_started)
	_battle_recording_state.set("context_captured", _battle_recording_context_captured)
	_battle_recording_state.set("match_dir", _battle_review_match_dir)



func _sync_battle_effect_state_from_scene() -> void:
	if _battle_effect_state == null:
		return
	_battle_effect_state.set("kind", _pending_effect_kind)
	_battle_effect_state.set("player_index", _pending_effect_player_index)
	_battle_effect_state.set("ability_index", _pending_effect_ability_index)
	_battle_effect_state.set("attack_data", _pending_effect_attack_data.duplicate(true))
	_battle_effect_state.set("steps", _pending_effect_steps.duplicate(true))
	_battle_effect_state.set("step_index", _pending_effect_step_index)
	_battle_effect_state.set("context", _pending_effect_context.duplicate(true))
	_battle_effect_state.set("coin_animation_resume_effect_step", _coin_animation_resume_effect_step)



func _apply_discard_collection_metrics(viewport_size: Vector2 = Vector2.ZERO, forced_width: float = 0.0) -> void:
	if viewport_size == Vector2.ZERO:
		if _is_portrait_popup_text_profile_active():
			viewport_size = _portrait_dialog_viewport_size()
		elif is_inside_tree():
			viewport_size = get_viewport_rect().size
		else:
			viewport_size = Vector2(1280, 720)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280, 720)
	var discard_box := get_node_or_null("DiscardOverlay/DiscardCenter/DiscardBox") as PanelContainer
	var target_width := forced_width
	if target_width <= 0.0:
		if _is_portrait_popup_text_profile_active():
			target_width = _portrait_popup_near_width()
		else:
			target_width = clampf(viewport_size.x * 0.62, 640.0, 1120.0)
	var show_visible_scrollbar := _is_portrait_popup_text_profile_active()
	var scroll_profile := _active_card_scrollbar_profile() if show_visible_scrollbar else "touch"
	var scroll_height := _card_scroll_height_with_scrollbar(_dialog_card_size.y) if show_visible_scrollbar else _card_gallery_scroll_height(_dialog_card_size.y)
	if discard_box != null:
		discard_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		discard_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		discard_box.custom_minimum_size = Vector2(target_width, 0.0)
	if _discard_card_scroll != null:
		_discard_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_discard_card_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_discard_card_scroll.custom_minimum_size = Vector2(0, scroll_height)
		_discard_card_scroll.set_meta("card_gallery_drag_keep_scrollbars_visible", show_visible_scrollbar)
		HudThemeScript.style_scroll_container(_discard_card_scroll, scroll_profile)
		if show_visible_scrollbar:
			_restore_card_gallery_scrollbars_for(_discard_card_scroll)
		else:
			_hide_card_gallery_scrollbars_for(_discard_card_scroll)
	if _discard_utility_row != null:
		_discard_utility_row.custom_minimum_size = Vector2(0, 0)
	if _discard_card_row != null:
		_discard_card_row.custom_minimum_size = Vector2(0, _dialog_card_size.y)
		_discard_card_row.size = Vector2(_discard_card_row.size.x, _dialog_card_size.y)
		for child: Node in _discard_card_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = _dialog_card_size



func _configure_hand_drag_scroll(hand_scroll: ScrollContainer) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("configure_hand_drag_scroll", hand_scroll)



func _refresh_card_gallery_scrollbar_visibility() -> void:
	for scroll_value: Variant in [_dialog_card_scroll, _discard_card_scroll]:
		var scroll := scroll_value as ScrollContainer
		if scroll == null:
			continue
		if bool(scroll.get_meta("card_gallery_drag_scroll_active", false)) and not bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false)):
			_hide_card_gallery_scrollbars_for(scroll)
		elif bool(scroll.get_meta("card_gallery_scrollbar_hidden", false)):
			_restore_card_gallery_scrollbars_for(scroll)



func _portrait_popup_text_roots() -> Array[Node]:
	var roots: Array[Node] = []
	var candidates: Array[Variant] = [
		_dialog_overlay if _dialog_overlay != null else find_child("DialogOverlay", true, false),
		_detail_overlay if _detail_overlay != null else find_child("DetailOverlay", true, false),
		_discard_overlay if _discard_overlay != null else find_child("DiscardOverlay", true, false),
		_review_overlay if _review_overlay != null else find_child("ReviewOverlay", true, false),
		_handover_panel if _handover_panel != null else find_child("HandoverPanel", true, false),
		_coin_overlay if _coin_overlay != null else find_child("CoinFlipOverlay", true, false),
		_field_interaction_overlay,
		_draw_reveal_overlay,
		_portrait_actions_popup,
		get("_match_end_overlay"),
	]
	for candidate: Variant in candidates:
		if candidate is Node:
			roots.append(candidate as Node)
	return roots



func _check_two_player_handover() -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("check_two_player_handover")
	_sync_battle_overlay_state_from_scene()
	if _battle_draw_reveal_controller != null and _battle_draw_reveal_controller.has_method("resume_if_ready"):
		_battle_draw_reveal_controller.call("resume_if_ready", self)



func _should_pause_after_ai_action(action_player_index: int) -> bool:
	if action_player_index < 0:
		return false
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _battle_mode != "live":
		return false
	_ensure_ai_opponent()
	return _ai_opponent != null and action_player_index == _ai_opponent.player_index



func _start_ai_action_pause() -> void:
	_ai_action_pause_timer = null
	if _ai_action_pause_seconds <= 0.0:
		_on_ai_action_pause_finished()
		return
	if not is_inside_tree():
		_ai_action_pause_timer = true
		return
	var timer: SceneTreeTimer = get_tree().create_timer(_ai_action_pause_seconds)
	_ai_action_pause_timer = timer
	timer.timeout.connect(func() -> void:
		if _ai_action_pause_timer != timer:
			return
		_on_ai_action_pause_finished()
	)



func _refresh_ui() -> void:
	_trace_portrait_layout_stage("scene.refresh_ui.before_display")
	_ensure_battle_display_coordinator()
	_battle_display_coordinator.call("refresh_all")
	_sync_stadium_backdrop()
	_trace_portrait_layout_stage("scene.refresh_ui.after_display")
	_refresh_vstar_lost_hud_values()
	_refresh_end_turn_hud_button_state()
	_sync_portrait_prize_hud_visibility()
	_sync_portrait_top_action_visibility()
	_show_portrait_prize_dialog_if_needed()
	_trace_portrait_layout_stage("scene.refresh_ui.before_finalize")
	_finalize_portrait_layout_constraints()
	_trace_portrait_layout_stage("scene.refresh_ui.after_finalize")
	call_deferred("_deferred_finalize_portrait_layout_constraints")
