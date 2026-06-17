## BattleScene shared HUD, coordinator, and AI prompt helper runtime.
extends "res://scenes/battle/runtime/BattleSceneRuntimeFoundation.gd"

const LLM_WAIT_LANDSCAPE_FONT_SIZE := 12
const LLM_WAIT_PORTRAIT_FONT_SIZE := 56

func _ensure_battle_interaction_coordinator() -> void:
	if _battle_interaction_coordinator == null:
		_battle_interaction_coordinator = BattleInteractionCoordinatorScript.new()
	if not bool(_battle_interaction_coordinator.call("is_configured")):
		_battle_interaction_coordinator.call("setup", _battle_scene_context, _battle_interaction_controller, self)



func _layout_llm_wait_label() -> void:
	if _ai_llm_wait_label == null or not is_instance_valid(_ai_llm_wait_label):
		return
	_apply_llm_wait_label_text_metrics()
	var anchor_rect := _llm_wait_hud_anchor_rect()
	if anchor_rect.size.x <= 0.0 or anchor_rect.size.y <= 0.0:
		_ai_llm_wait_label.position = Vector2.ZERO
		_ai_llm_wait_label.size = Vector2.ZERO
		return
	var scene_rect := get_global_rect()
	var local_pos := anchor_rect.position - scene_rect.position
	var inset := 6.0
	_ai_llm_wait_label.position = local_pos + Vector2(inset, 0.0)
	_ai_llm_wait_label.size = Vector2(maxf(anchor_rect.size.x - inset * 2.0, 0.0), maxf(anchor_rect.size.y, 22.0))
	_ai_llm_wait_label.custom_minimum_size = Vector2.ZERO
	if _ai_llm_wait_label.visible:
		_set_llm_wait_turn_label_suppressed(true)



func _llm_wait_hud_anchor_rect() -> Rect2:
	if _is_portrait_battle_layout_active():
		var hand_anchor := _llm_wait_portrait_hand_hud_rect()
		if hand_anchor.size.x > 0.0 and hand_anchor.size.y > 0.0:
			return hand_anchor
	return _llm_wait_top_center_hud_rect()



func _llm_wait_portrait_hand_hud_rect() -> Rect2:
	var hand_area := find_child("HandArea", true, false) as Control
	if hand_area == null:
		return Rect2()
	var local_hand_rect := _llm_wait_control_rect_in_battle_local(hand_area)
	var scene_rect := get_global_rect()
	var hand_rect := Rect2(scene_rect.position + local_hand_rect.position, local_hand_rect.size)
	if hand_rect.size.x <= 0.0 or hand_rect.size.y <= 0.0:
		return Rect2()
	var label_height := 28.0
	if _ai_llm_wait_label != null and is_instance_valid(_ai_llm_wait_label):
		label_height = maxf(float(_ai_llm_wait_label.get_theme_font_size("font_size")) + 14.0, label_height)
	label_height = minf(label_height, maxf(hand_rect.size.y * 0.35, 24.0))
	var width := minf(maxf(hand_rect.size.x * 0.82, 240.0), hand_rect.size.x)
	var x := hand_rect.position.x + (hand_rect.size.x - width) * 0.5
	var y := hand_rect.position.y + 4.0
	return Rect2(Vector2(x, y), Vector2(width, label_height))



func _llm_wait_control_rect_in_battle_local(control: Control) -> Rect2:
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



func _llm_wait_top_center_hud_rect() -> Rect2:
	var top_bar_center := get_node_or_null("TopBar/TopBarRow/TopBarCenter") as Control
	if top_bar_center != null and top_bar_center.visible:
		var center_rect := top_bar_center.get_global_rect()
		if center_rect.size.x > 0.0 and center_rect.size.y > 0.0:
			return center_rect
	var top_bar := get_node_or_null("TopBar") as Control
	if top_bar != null:
		var top_rect := top_bar.get_global_rect()
		if top_rect.size.x > 0.0 and top_rect.size.y > 0.0:
			var width := minf(maxf(top_rect.size.x * 0.46, 220.0), top_rect.size.x)
			return Rect2(Vector2(top_rect.position.x + (top_rect.size.x - width) * 0.5, top_rect.position.y), Vector2(width, top_rect.size.y))
	var scene_rect := get_global_rect()
	if scene_rect.size.x <= 0.0 or scene_rect.size.y <= 0.0:
		return Rect2()
	var fallback_width := minf(maxf(scene_rect.size.x * 0.46, 220.0), scene_rect.size.x)
	return Rect2(Vector2(scene_rect.position.x + (scene_rect.size.x - fallback_width) * 0.5, scene_rect.position.y + 4.0), Vector2(fallback_width, 26.0))



func _set_llm_wait_turn_label_suppressed(suppressed: bool) -> void:
	if _lbl_turn == null or not is_instance_valid(_lbl_turn):
		_lbl_turn = find_child("LblTurn", true, false) as Label
	if _lbl_turn == null or not is_instance_valid(_lbl_turn):
		return
	var meta_key := "_llm_wait_previous_visible"
	if suppressed:
		if not _lbl_turn.has_meta(meta_key):
			_lbl_turn.set_meta(meta_key, _lbl_turn.visible)
		_lbl_turn.visible = false
		return
	if _lbl_turn.has_meta(meta_key):
		_lbl_turn.visible = bool(_lbl_turn.get_meta(meta_key))
		_lbl_turn.remove_meta(meta_key)



func _current_llm_wait_model_id() -> String:
	var config: Dictionary = GameManager.get_llm_opponent_battle_review_api_config()
	return str(config.get("model", "")).strip_edges()



func _llm_wait_hud_text_for_model(model_id: String, turn_number: int, elapsed_sec: int, dot_count: int) -> String:
	var model_name := _llm_wait_model_display_name(model_id)
	var action := _llm_wait_action_text_for_model(model_id)
	return "%s %s%s  第 %d 回合 (%ds)" % [
		model_name,
		action,
		".".repeat(maxi(1, dot_count)),
		turn_number,
		maxi(0, elapsed_sec),
	]



func _portrait_popup_near_width() -> float:
	return _portrait_popup_width_for_ratio(PORTRAIT_POPUP_NEAR_WIDTH_RATIO, _portrait_dialog_viewport_size())



func _active_card_scrollbar_profile() -> String:
	return _portrait_scrollbar_profile() if _is_portrait_popup_text_profile_active() else "touch"



func _card_gallery_scroll_height(card_height: float) -> float:
	return maxf(0.0, card_height)



func _hide_card_gallery_scrollbars_for(scroll: ScrollContainer) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("hide_card_gallery_scrollbars_for", scroll)



func _restore_card_gallery_scrollbars_for(scroll: ScrollContainer) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("restore_card_gallery_scrollbars_for", scroll)



func _ensure_battle_overlay_coordinator() -> void:
	if _battle_overlay_coordinator == null:
		_battle_overlay_coordinator = BattleOverlayCoordinatorScript.new()
	if not bool(_battle_overlay_coordinator.call("is_configured")):
		_battle_overlay_coordinator.call("setup", _battle_scene_context, _battle_overlay_controller, self)



func _sync_battle_overlay_state_from_scene() -> void:
	if _battle_overlay_state == null:
		return
	_battle_overlay_state.set("pending_prize_player_index", _pending_prize_player_index)
	_battle_overlay_state.set("pending_prize_remaining", _pending_prize_remaining)
	_battle_overlay_state.set("pending_prize_animating", _pending_prize_animating)
	_battle_overlay_state.set("portrait_prize_dialog_active", _portrait_prize_dialog_active)
	_battle_overlay_state.set("handover_visible", _handover_panel != null and _handover_panel.visible)
	_battle_overlay_state.set("match_end_visible", _match_end_overlay != null and _match_end_overlay.visible)
	_battle_overlay_state.set("match_end_winner_index", _battle_review_winner_index)
	_battle_overlay_state.set("match_end_reason", _battle_review_reason)



func _on_ai_action_pause_finished() -> void:
	_ai_action_pause_timer = null
	_maybe_run_ai()



func _ensure_battle_display_coordinator() -> void:
	if _battle_display_coordinator == null:
		_battle_display_coordinator = BattleDisplayCoordinatorScript.new()
	if not bool(_battle_display_coordinator.call("is_configured")):
		_battle_display_coordinator.call("setup", _battle_scene_context, _battle_display_controller, self)



func _sync_portrait_prize_hud_visibility(is_portrait: Variant = null) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("sync_portrait_prize_hud_visibility", is_portrait)


func _has_human_portrait_prize_prompt_pending() -> bool:
	return _pending_choice == "take_prize" \
		and _pending_prize_remaining > 0 \
		and _pending_prize_player_index == _view_player \
		and _is_portrait_battle_layout_active()



func _show_portrait_prize_dialog_if_needed() -> void:
	if not _has_human_portrait_prize_prompt_pending():
		_close_portrait_prize_dialog()
		return
	var host_name := "MyPrizeHudHost" if _pending_prize_player_index == _view_player else "OppPrizeHudHost"
	var cached_host: VBoxContainer = _my_prize_hud_host if _pending_prize_player_index == _view_player else _opp_prize_hud_host
	if cached_host != null and not is_instance_valid(cached_host):
		cached_host = null
	var live_host := find_child(host_name, true, false) as VBoxContainer
	var host := live_host if live_host != null else cached_host
	if live_host != null:
		if _pending_prize_player_index == _view_player:
			_my_prize_hud_host = live_host
		else:
			_opp_prize_hud_host = live_host
	var cached_dialog_overlay := _dialog_overlay
	if cached_dialog_overlay != null and not is_instance_valid(cached_dialog_overlay):
		cached_dialog_overlay = null
	var live_dialog_overlay := find_child("DialogOverlay", true, false) as Panel
	var dialog_overlay := live_dialog_overlay if live_dialog_overlay != null else cached_dialog_overlay
	if live_dialog_overlay != null:
		_dialog_overlay = live_dialog_overlay
	var cached_dialog_vbox := _dialog_vbox
	if cached_dialog_vbox != null and not is_instance_valid(cached_dialog_vbox):
		cached_dialog_vbox = null
	var live_dialog_vbox := find_child("DialogVBox", true, false) as VBoxContainer
	var dialog_vbox := live_dialog_vbox if live_dialog_vbox != null else cached_dialog_vbox
	if live_dialog_vbox != null:
		_dialog_vbox = live_dialog_vbox
	if host == null or dialog_overlay == null or dialog_vbox == null:
		return
	if _portrait_prize_dialog_active and _portrait_prize_dialog_host != host:
		_close_portrait_prize_dialog()
	if not _portrait_prize_dialog_active:
		_portrait_prize_dialog_active = true
		_portrait_prize_dialog_player_index = _pending_prize_player_index
		_portrait_prize_dialog_host = host
		_portrait_prize_dialog_original_parent = host.get_parent()
		_portrait_prize_dialog_original_index = host.get_index()
		_portrait_prize_dialog_original_visible = host.visible
		_portrait_prize_dialog_original_minimum_size = host.custom_minimum_size
	var cached_dialog_confirm := _dialog_confirm
	if cached_dialog_confirm != null and not is_instance_valid(cached_dialog_confirm):
		cached_dialog_confirm = null
	var live_dialog_confirm := find_child("DialogConfirm", true, false) as Button
	var dialog_confirm := live_dialog_confirm if live_dialog_confirm != null else cached_dialog_confirm
	if live_dialog_confirm != null:
		_dialog_confirm = live_dialog_confirm
	var buttons_row := (dialog_confirm.get_parent() as Control) if dialog_confirm != null else null
	var insert_index := buttons_row.get_index() if buttons_row != null and buttons_row.get_parent() == dialog_vbox else dialog_vbox.get_child_count()
	_move_control_to_node(host, dialog_vbox, insert_index)
	host.visible = true
	host.custom_minimum_size = Vector2.ZERO
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_prize_dialog_slot_metrics(_pending_prize_player_index)
	_prepare_dialog_overlay_for_prize_selection()



func _finalize_portrait_layout_constraints() -> void:
	if _active_battle_layout_mode != "portrait" and not _rotated_portrait_canvas_active:
		return
	_trace_portrait_layout_stage("scene.finalize.enter")
	var frame_rect := _portrait_layout_frame_rect
	if frame_rect.size == Vector2.ZERO:
		var fallback_size := size
		if fallback_size == Vector2.ZERO and is_inside_tree():
			fallback_size = _battle_layout_logical_viewport_size(get_viewport_rect().size, "portrait")
		if fallback_size == Vector2.ZERO:
			return
		frame_rect = Rect2(Vector2.ZERO, fallback_size)
	var safe_x := _portrait_horizontal_safe_inset(frame_rect.size)
	var safe_width := maxf(frame_rect.size.x - safe_x * 2.0, 1.0)
	var safe_left := frame_rect.position.x + safe_x
	_set_portrait_top_status_compact(true)
	_enforce_portrait_field_axis_width(safe_width)
	_trace_portrait_layout_stage("scene.finalize.after_axis_width")
	_enforce_portrait_render_safe_width(safe_left, safe_width)
	_trace_portrait_layout_stage("scene.finalize.after_render_safe_width")
	_position_portrait_edge_hud_overlay(Vector2(safe_width, frame_rect.size.y), 0.0, 0.0)
	_trace_portrait_layout_stage("scene.finalize.after_edge_hud_position")



func _sync_portrait_top_action_visibility(is_portrait: Variant = null) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("sync_portrait_top_action_visibility", is_portrait)



func _refresh_end_turn_hud_button_state() -> void:
	var hud_button := _hud_end_turn_btn if _hud_end_turn_btn != null else find_child("HudEndTurnBtn", true, false) as Button
	var side_button := _btn_end_turn if _btn_end_turn != null else find_child("BtnEndTurn", true, false) as Button
	for button: Button in [hud_button, side_button]:
		if button == null:
			continue
		button.modulate = Color.WHITE



func _refresh_vstar_lost_hud_values() -> void:
	if _gsm == null or _gsm.game_state == null:
		_set_vstar_hud_value(_enemy_vstar_value, false)
		_set_vstar_hud_value(_my_vstar_value, false)
		_set_lost_zone_hud_value(_enemy_lost_value, 0)
		_set_lost_zone_hud_value(_my_lost_value, 0)
		return
	var gs: GameState = _gsm.game_state
	if gs.players.size() < 2 or gs.vstar_power_used.size() < 2:
		return
	var opponent_player := 1 - _view_player
	var my_player := _view_player
	_set_vstar_hud_value(_enemy_vstar_value, bool(gs.vstar_power_used[opponent_player]), opponent_player)
	_set_vstar_hud_value(_my_vstar_value, bool(gs.vstar_power_used[my_player]), my_player)
	_set_lost_zone_hud_value(_enemy_lost_value, gs.players[opponent_player].lost_zone.size())
	_set_lost_zone_hud_value(_my_lost_value, gs.players[my_player].lost_zone.size())



func _apply_llm_wait_label_text_metrics() -> void:
	if _ai_llm_wait_label == null or not is_instance_valid(_ai_llm_wait_label):
		return
	_ai_llm_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ai_llm_wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ai_llm_wait_label.clip_text = true
	_ai_llm_wait_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ai_llm_wait_label.add_theme_font_size_override(
		"font_size",
		LLM_WAIT_PORTRAIT_FONT_SIZE if _is_portrait_battle_layout_active() else LLM_WAIT_LANDSCAPE_FONT_SIZE
	)
	_ai_llm_wait_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_ai_llm_wait_label.max_lines_visible = 1



func _llm_wait_model_display_name(model_id: String) -> String:
	var normalized := GameManager.normalize_battle_review_model(model_id)
	var lower := normalized.to_lower()
	if lower.contains("grok"):
		return "Grok 4.2"
	if lower.contains("deepseek-v4-pro"):
		return "DeepSeek V4 Pro"
	if lower.contains("deepseek-v4-flash"):
		return "DeepSeek V4 Flash"
	if lower.contains("deepseek"):
		return "DeepSeek"
	if lower.contains("glm"):
		return "GLM 5.2"
	if lower.contains("qwen3.7-max"):
		return "Qwen 3.7 Max"
	if lower.contains("qwen"):
		return "Qwen 3.7 Plus"
	if lower.contains("kimi"):
		return "Kimi K2.6"
	if lower.contains("claude"):
		return "Claude Sonnet 4.6"
	if lower.contains("gpt-5.5"):
		return "GPT-5.5"
	var label := GameManager.get_battle_review_model_label(normalized).strip_edges()
	return label if label != "" else "AI"



func _llm_wait_action_text_for_model(model_id: String) -> String:
	var normalized := GameManager.normalize_battle_review_model(model_id).to_lower()
	if normalized.contains("grok"):
		return "正在挠头中"
	if normalized.contains("deepseek"):
		return "正在思考中"
	if normalized.contains("kimi"):
		return "正在翻牌谱"
	if normalized.contains("qwen"):
		return "正在排兵布阵"
	if normalized.contains("glm"):
		return "正在计算胜线"
	if normalized.contains("claude"):
		return "正在整理思路"
	if normalized.contains("gpt"):
		return "正在读场面"
	return "正在思考中"



func _portrait_popup_width_for_ratio(ratio: float, viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0:
		return 0.0
	var margin := float(HudThemeScript.TOUCH_DIALOG_MARGIN)
	var max_width := maxf(viewport_size.x - margin * 2.0, 1.0)
	var target_width := roundf(viewport_size.x * ratio)
	return minf(maxf(target_width, minf(320.0, max_width)), max_width)



func _portrait_dialog_viewport_size() -> Vector2:
	if _portrait_layout_frame_rect.size != Vector2.ZERO:
		return _portrait_layout_frame_rect.size
	if size != Vector2.ZERO:
		return size
	if _rotated_portrait_canvas_active and _rotated_portrait_physical_viewport_size != Vector2.ZERO:
		return _battle_layout_logical_viewport_size(_rotated_portrait_physical_viewport_size, "portrait")
	if is_inside_tree():
		return _battle_layout_logical_viewport_size(get_viewport_rect().size, "portrait")
	return Vector2(900, 1600)



func _is_portrait_popup_text_profile_active() -> bool:
	return _is_portrait_battle_layout_active()



func _portrait_scrollbar_profile() -> String:
	return "portrait_touch"



func _ensure_battle_drag_scroll_coordinator() -> void:
	if _battle_drag_scroll_coordinator == null:
		_battle_drag_scroll_coordinator = BattleDragScrollCoordinatorScript.new()
	_battle_drag_scroll_coordinator.call("setup", self)



func _maybe_run_ai() -> void:
	if _try_auto_continue_ai_draw_reveal():
		return
	if _ai_running:
		if _is_ai_turn_ready():
			_ai_followup_requested = true
		return
	if _ai_step_scheduled or not _is_ai_turn_ready():
		return
	_ai_step_scheduled = true
	call_deferred("_run_ai_step")



func _prepare_dialog_overlay_for_prize_selection() -> void:
	var dialog_overlay := _dialog_overlay if _dialog_overlay != null else find_child("DialogOverlay", true, false) as Panel
	if dialog_overlay == null:
		return
	var player_label := "己方" if _pending_prize_player_index == _view_player else "对方"
	var dialog_title := _dialog_title if _dialog_title != null else find_child("DialogTitle", true, false) as Label
	var dialog_list := _dialog_list if _dialog_list != null else find_child("DialogList", true, false) as ItemList
	var dialog_confirm := _dialog_confirm if _dialog_confirm != null else find_child("DialogConfirm", true, false) as Button
	var dialog_box := _dialog_box if _dialog_box != null else find_child("DialogBox", true, false) as PanelContainer
	if dialog_title != null:
		dialog_title.text = "%s奖赏：请选择%d张" % [player_label, _pending_prize_remaining]
	if dialog_list != null:
		dialog_list.visible = false
	if _dialog_card_scroll != null:
		_dialog_card_scroll.visible = false
	if _dialog_assignment_panel != null:
		_dialog_assignment_panel.visible = false
	if _dialog_status_lbl != null:
		_dialog_status_lbl.visible = false
	if _dialog_utility_row != null:
		_dialog_utility_row.visible = false
	var buttons_row := (dialog_confirm.get_parent() as Control) if dialog_confirm != null else null
	if buttons_row != null:
		buttons_row.visible = false
	if dialog_box != null:
		var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(900, 1600)
		var max_width := minf(maxf(viewport_size.x * 0.88, 340.0), 760.0)
		dialog_box.custom_minimum_size = Vector2(max_width, 0)
	dialog_overlay.z_index = DIALOG_OVERLAY_Z_INDEX
	dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_overlay.visible = true



func _apply_prize_dialog_slot_metrics(player_index: int) -> void:
	var slots: Array[BattleCardView] = _my_prize_slots if player_index == _view_player else _opp_prize_slots
	var card_size := _dialog_card_size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = Vector2(122, 170)
	for prize_view: BattleCardView in slots:
		if prize_view == null:
			continue
		prize_view.visible = true
		prize_view.custom_minimum_size = card_size
		prize_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prize_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER



func _close_portrait_prize_dialog() -> void:
	if not _portrait_prize_dialog_active:
		return
	var host := _portrait_prize_dialog_host
	var original_parent := _portrait_prize_dialog_original_parent
	var original_index := _portrait_prize_dialog_original_index
	var original_visible := _portrait_prize_dialog_original_visible
	var original_minimum_size := _portrait_prize_dialog_original_minimum_size
	_portrait_prize_dialog_active = false
	_portrait_prize_dialog_player_index = -1
	_portrait_prize_dialog_host = null
	_portrait_prize_dialog_original_parent = null
	_portrait_prize_dialog_original_index = -1
	_portrait_prize_dialog_original_visible = false
	_portrait_prize_dialog_original_minimum_size = Vector2.ZERO
	if host != null and original_parent != null:
		_move_control_to_node(host, original_parent, original_index)
		host.visible = original_visible
		host.custom_minimum_size = original_minimum_size
	var dialog_confirm := _dialog_confirm if _dialog_confirm != null else find_child("DialogConfirm", true, false) as Button
	var buttons_row := (dialog_confirm.get_parent() as Control) if dialog_confirm != null else null
	if buttons_row != null:
		buttons_row.visible = true
	var dialog_overlay := _dialog_overlay if _dialog_overlay != null else find_child("DialogOverlay", true, false) as Panel
	if dialog_overlay != null:
		dialog_overlay.visible = false



func _portrait_horizontal_safe_inset(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0:
		return 0.0
	var ui_scale := _portrait_layout_ui_scale(viewport_size)
	return clampf(viewport_size.x * 0.018, 6.0 * ui_scale, 18.0 * ui_scale)



func _enforce_portrait_field_axis_width(safe_width: float) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("enforce_portrait_field_axis_width", safe_width)



func _enforce_portrait_render_safe_width(safe_left: float, safe_width: float) -> void:
	if safe_width <= 0.0:
		return
	var top_bar := get_node_or_null("TopBar") as Control
	if top_bar != null:
		_apply_portrait_root_safe_width(top_bar, safe_left, safe_width)
	var main_area := get_node_or_null("MainArea") as Control
	if main_area != null:
		_apply_portrait_root_safe_width(main_area, safe_left, safe_width)
	for control_path: String in [
		"MainArea/CenterField",
		"MainArea/CenterField/FieldArea",
		"MainArea/CenterField/FieldArea/StadiumBar",
		"MainArea/CenterField/FieldArea/OppField",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner/OppActiveRow",
		"MainArea/CenterField/FieldArea/MyField",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner/MyActiveRow",
		"MainArea/CenterField/HandArea",
		"MainArea/CenterField/HandArea/HandScroll",
	]:
		_apply_portrait_child_safe_width(get_node_or_null(control_path) as Control, safe_width)
	var stadium_sections := get_node_or_null("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections") as Control
	if stadium_sections != null:
		stadium_sections.clip_contents = true
		stadium_sections.custom_minimum_size.x = 0.0
		stadium_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL



func _position_portrait_edge_hud_overlay(viewport_size: Vector2, status_width: float, row_gap: float) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("position_portrait_edge_hud_overlay", viewport_size, status_width, row_gap)



func _trace_portrait_layout_stage(stage: String) -> void:
	_ensure_battle_layout_debug_reporter()
	_battle_layout_debug_reporter.call("trace_portrait_layout_stage", stage)



func _set_portrait_top_status_compact(enabled: bool) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("set_portrait_top_status_compact", enabled)



func _set_vstar_hud_value(label: Label, used: bool, player_index: int = -1) -> void:
	if label == null:
		return
	label.visible = false
	label.text = "VStar"
	var panel := _nearest_panel_container(label)
	if panel != null:
		if player_index >= 0:
			panel.set_meta("_vstar_hud_player_index", player_index)
		_style_vstar_lost_hud_panel(panel, "vstar", used)
		_sync_vstar_hud_image_metrics(panel)



func _set_lost_zone_hud_value(label: Label, count: int) -> void:
	if label == null:
		return
	label.visible = true
	label.text = "LOST 区：%d张" % maxi(count, 0)
	label.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0))
	_apply_lost_hud_font_size(label)
	var panel := _nearest_panel_container(label)
	if panel != null:
		_style_vstar_lost_hud_panel(panel, "lost", false)



func _battle_layout_logical_viewport_size(viewport_size: Vector2, resolved_mode: String) -> Vector2:
	if _should_rotate_battle_canvas(viewport_size, resolved_mode):
		return Vector2(viewport_size.y, viewport_size.x)
	return viewport_size


func _should_rotate_battle_canvas(viewport_size: Vector2, resolved_mode: String) -> bool:
	var preferred_mode := GameManager.sanitize_battle_layout_mode(str(GameManager.get("battle_layout_mode"))) if GameManager != null else "auto"
	if resolved_mode == "portrait":
		if viewport_size.x <= viewport_size.y:
			return false
		return preferred_mode == GameManager.BATTLE_LAYOUT_PORTRAIT
	if resolved_mode == "landscape":
		if viewport_size.y <= viewport_size.x:
			return false
		return preferred_mode == GameManager.BATTLE_LAYOUT_LANDSCAPE
	return false



func _is_portrait_battle_layout_active() -> bool:
	if _active_battle_layout_mode == "landscape":
		return false
	if _rotated_portrait_canvas_active:
		return true
	if _active_battle_layout_mode == "portrait":
		return true
	if _portrait_layout_frame_rect.size.x > 0.0 and _portrait_layout_frame_rect.size.y > 0.0:
		return true
	return _current_resolved_battle_layout_mode() == "portrait"



func _is_ai_turn_ready() -> bool:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _gsm == null:
		return false
	_ensure_ai_opponent()
	if _gsm.game_state != null and _gsm.game_state.phase == GameState.GamePhase.SETUP and not _is_ai_setup_prompt():
		return false
	if _is_ai_setup_prompt():
		if _is_ui_blocking_ai():
			return false
		return _get_ai_prompt_player_index() == _ai_opponent.player_index
	if _pending_choice == "take_prize":
		if _is_ui_blocking_ai():
			return false
		return _is_ai_prize_prompt()
	if _pending_choice == "send_out":
		if _is_ui_blocking_ai():
			return false
		return _is_ai_send_out_prompt()
	if _pending_choice == "heavy_baton_target":
		if _is_ui_blocking_ai():
			return false
		return _is_ai_heavy_baton_prompt()
	if _pending_choice == "effect_interaction":
		if _is_ui_blocking_ai():
			return false
		return _get_effect_interaction_prompt_player_index() == _ai_opponent.player_index
	return _ai_opponent.should_control_turn(_gsm.game_state, _is_ui_blocking_ai())



func _try_auto_continue_ai_draw_reveal() -> bool:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _draw_reveal_active != true or _draw_reveal_auto_continue_pending != true:
		return false
	if self is Node and (self as Node).is_inside_tree():
		return false
	_ensure_ai_opponent()
	if _ai_opponent == null or _draw_reveal_current_action == null:
		return false
	if _draw_reveal_current_action.player_index != _ai_opponent.player_index:
		return false
	if _battle_draw_reveal_controller == null or not _battle_draw_reveal_controller.has_method("run_auto_continue"):
		return false
	_battle_draw_reveal_controller.call("run_auto_continue", self)
	return true



func _move_control_to_node(control: Control, target: Node, insert_index: int) -> void:
	if control == null or target == null:
		return
	var previous_owner := control.owner
	var parent := control.get_parent()
	if parent != target:
		control.owner = null
		if parent != null:
			parent.remove_child(control)
		target.add_child(control)
		if target.owner != null:
			control.owner = target.owner
		else:
			control.owner = previous_owner
	var max_index := maxi(target.get_child_count() - 1, 0)
	target.move_child(control, clampi(insert_index, 0, max_index))



func _portrait_layout_ui_scale(viewport_size: Vector2) -> float:
	return float(_battle_layout_controller.call("portrait_layout_scale", viewport_size))



func _apply_portrait_root_safe_width(control: Control, safe_left: float, safe_width: float) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	control.position.x = safe_left
	control.size.x = safe_width
	control.custom_minimum_size.x = safe_width
	control.clip_contents = true
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if control is Container:
		(control as Container).queue_sort()



func _apply_portrait_child_safe_width(control: Control, safe_width: float) -> void:
	if control == null:
		return
	control.clip_contents = true
	control.custom_minimum_size.x = safe_width
	control.size.x = safe_width
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control is Container:
		(control as Container).queue_sort()



func _ensure_battle_layout_debug_reporter() -> void:
	if _battle_layout_debug_reporter == null:
		_battle_layout_debug_reporter = BattleLayoutDebugReporterScript.new()
	_battle_layout_debug_reporter.call("setup", self)



func _ensure_battle_layout_coordinator() -> void:
	if _battle_layout_coordinator == null:
		_battle_layout_coordinator = BattleLayoutCoordinatorScript.new()
	if not bool(_battle_layout_coordinator.call("is_configured", self, _battle_layout_controller)):
		_battle_layout_coordinator.call("setup", self, _battle_layout_controller)



func _style_vstar_lost_hud_panel(panel: PanelContainer, kind: String, used: bool) -> void:
	if panel == null:
		return
	if kind == "vstar":
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var texture_rect := _ensure_vstar_hud_image(panel)
		if texture_rect != null:
			texture_rect.modulate = Color(0.58, 0.60, 0.62, 0.72) if used else Color(1.0, 1.0, 1.0, 1.0)
		return
	var accent := Color(1.0, 0.3, 0.26, 1.0) if used else (Color(0.78, 0.9, 1.0, 0.94) if kind == "vstar" else Color(0.16, 0.62, 0.76, 0.92))
	var fill := Color(0.2, 0.03, 0.04, 0.82) if used else (Color(0.08, 0.12, 0.17, 0.82) if kind == "vstar" else Color(0.01, 0.11, 0.18, 0.72))
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	style.shadow_size = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)



func _nearest_panel_container(node: Node) -> PanelContainer:
	var current := node
	while current != null:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null



func _apply_lost_hud_font_size(label: Label) -> void:
	if label == null:
		return
	var deck_value_name := "OppDeckHudValue" if str(label.name).contains("Enemy") else "MyDeckHudValue"
	var deck_value := find_child(deck_value_name, true, false) as Label
	if deck_value != null:
		label.add_theme_font_size_override("font_size", deck_value.get_theme_font_size("font_size"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL



func _should_rotate_portrait_canvas(viewport_size: Vector2, resolved_mode: String) -> bool:
	return _should_rotate_battle_canvas(viewport_size, resolved_mode)



func _current_resolved_battle_layout_mode(viewport_size: Vector2 = Vector2.ZERO) -> String:
	var size := viewport_size
	if size == Vector2.ZERO:
		if not is_inside_tree():
			var detached_mode := GameManager.sanitize_battle_layout_mode(str(GameManager.get("battle_layout_mode"))) if GameManager != null else "auto"
			return detached_mode if detached_mode != "auto" else "landscape"
		size = get_viewport_rect().size
	var preferred_mode := str(GameManager.get("battle_layout_mode")) if GameManager != null else "auto"
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return str(_battle_layout_controller.call("resolve_layout_mode", size, preferred_mode, is_mobile))



func _get_ai_prompt_player_index() -> int:
	if _pending_choice == "mulligan_extra_draw":
		return int(_dialog_data.get("beneficiary", -1))
	if _pending_choice.begins_with("setup_active_") or _pending_choice.begins_with("setup_bench_"):
		return int(_pending_choice.split("_")[-1])
	return -1



func _is_ai_send_out_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return (
		_pending_choice == "send_out"
		and int(_dialog_data.get("player", -1)) == _ai_opponent.player_index
	)



func _is_ui_blocking_ai() -> bool:
	var dialog_blocks_ai := _dialog_overlay != null and _dialog_overlay.visible and not (_is_ai_setup_prompt() or _is_ai_effect_prompt() or _is_ai_heavy_baton_prompt())
	return (
		_draw_reveal_active
		or _is_ai_action_pause_active()
		or dialog_blocks_ai
		or (_handover_panel != null and _handover_panel.visible)
		or _has_pending_coin_animation()
		or (_pending_choice == "take_prize" and not _is_ai_prize_prompt())
		or _pending_prize_animating
		or (_field_interaction_overlay != null and _field_interaction_overlay.visible and not (_is_ai_effect_prompt() or _is_ai_heavy_baton_prompt()))
	)



func _ensure_ai_opponent() -> void:
	if _ai_opponent == null:
		_ai_opponent = _build_selected_ai_opponent()
		_log_ai_loaded(
			str(_ai_opponent.get_meta("ai_source", "default")),
			str(_ai_opponent.get_meta("ai_version_id", "")),
			str(_ai_opponent.get_meta("ai_display_name", "Default AI"))
		)



func _ensure_vstar_hud_image(panel: PanelContainer) -> TextureRect:
	if panel == null:
		return null
	_set_descendant_labels_visible(panel, false)
	var texture_rect := panel.find_child("HudImageTexture", true, false) as TextureRect
	if texture_rect == null:
		texture_rect = TextureRect.new()
		texture_rect.name = "HudImageTexture"
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := _first_control_child(panel)
	var box := _first_vbox_descendant(content)
	var target_parent: Node = box if box != null else panel
	if texture_rect.get_parent() != target_parent:
		var current_parent := texture_rect.get_parent()
		if current_parent != null:
			current_parent.remove_child(texture_rect)
		target_parent.add_child(texture_rect)
	if target_parent is Container:
		(target_parent as Container).move_child(texture_rect, 0)
	texture_rect.texture = _vstar_hud_texture_for_panel(panel)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.visible = true
	_sync_vstar_hud_image_metrics(panel)
	return texture_rect



func _is_ai_setup_prompt(pending_choice: String = _pending_choice) -> bool:
	return (
		pending_choice == "mulligan_extra_draw"
		or pending_choice.begins_with("setup_active_")
		or pending_choice.begins_with("setup_bench_")
	)



func _is_ai_prize_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return (
		_pending_choice == "take_prize"
		and _pending_prize_player_index == _ai_opponent.player_index
		and _pending_prize_remaining > 0
	)



func _is_ai_heavy_baton_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return (
		_pending_choice == "heavy_baton_target"
		and int(_dialog_data.get("player", -1)) == _ai_opponent.player_index
	)



func _is_ai_effect_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return _get_effect_interaction_prompt_player_index() == _ai_opponent.player_index



func _is_ai_action_pause_active() -> bool:
	return _ai_action_pause_timer != null



func _has_pending_coin_animation() -> bool:
	return _coin_animating or not _coin_flip_queue.is_empty()



func _build_selected_ai_opponent() -> AIOpponent:
	return _battle_ai_opponent_factory.call("build_selected_ai_opponent", _deck_strategy_registry, _ai_version_registry, _agent_version_store, self)



func _log_ai_loaded(source: String, version_id: String, display_name: String) -> void:
	_runtime_log("ai_loaded", "source=%s version=%s display=%s" % [source, version_id, display_name])
	if GameManager.current_mode == GameManager.GameMode.VS_AI:
		print("[AI] %s" % display_name)


func _vstar_hud_texture_for_panel(panel: PanelContainer) -> Texture2D:
	var variant_count := VSTAR_HUD_TEXTURE_VARIANTS.size()
	if variant_count <= 0:
		return VSTAR_HUD_TEXTURE
	if panel != null and panel.has_meta("_vstar_hud_player_index"):
		return _vstar_hud_texture_for_player(int(panel.get_meta("_vstar_hud_player_index")))
	var index := 0
	if panel != null and panel.has_meta("_vstar_hud_texture_index"):
		index = int(panel.get_meta("_vstar_hud_texture_index"))
	else:
		index = randi() % variant_count
		if panel != null:
			panel.set_meta("_vstar_hud_texture_index", index)
	index = posmod(index, variant_count)
	var texture_variant: Variant = VSTAR_HUD_TEXTURE_VARIANTS[index]
	if texture_variant is Texture2D:
		return texture_variant as Texture2D
	return VSTAR_HUD_TEXTURE



func _set_descendant_labels_visible(root: Node, visible: bool) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child is Label:
			(child as Label).visible = visible
		_set_descendant_labels_visible(child, visible)



func _sync_vstar_hud_image_metrics(panel: PanelContainer) -> void:
	if panel == null or not _is_vstar_hud_panel(panel):
		return
	var texture_rect := panel.find_child("HudImageTexture", true, false) as TextureRect
	if texture_rect == null:
		return
	var target_size := panel.custom_minimum_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = _vstar_hud_size_for_height(40.0)
	texture_rect.custom_minimum_size = target_size
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL



func _first_control_child(root: Node) -> Control:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is Control:
			return child as Control
	return null



func _first_vbox_descendant(root: Node) -> VBoxContainer:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is VBoxContainer:
			return child as VBoxContainer
		var nested := _first_vbox_descendant(child)
		if nested != null:
			return nested
	return null



func _get_effect_interaction_prompt_player_index() -> int:
	if _pending_choice != "effect_interaction":
		return -1
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return -1
	return _resolve_effect_step_chooser_player(_pending_effect_steps[_pending_effect_step_index])



func _runtime_log(event: String, detail: String = "") -> void:
	_battle_runtime_log_controller.call("runtime_log", self, event, detail)



func _vstar_hud_texture_for_player(player_index: int) -> Texture2D:
	var variant_count := VSTAR_HUD_TEXTURE_VARIANTS.size()
	if variant_count <= 0 or player_index < 0:
		return VSTAR_HUD_TEXTURE
	_ensure_vstar_hud_texture_index_for_player(player_index)
	var index := int(_vstar_hud_texture_indices_by_player[player_index])
	index = posmod(index, variant_count)
	var texture_variant: Variant = VSTAR_HUD_TEXTURE_VARIANTS[index]
	if texture_variant is Texture2D:
		return texture_variant as Texture2D
	return VSTAR_HUD_TEXTURE



func _is_vstar_hud_panel(panel: Node) -> bool:
	return panel != null and str(panel.name).to_lower().contains("vstar")



func _vstar_hud_size_for_height(height: float) -> Vector2:
	return Vector2(_vstar_hud_width_for_height(height), height)



func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
	return int(_battle_effect_interaction_controller.call("resolve_effect_step_chooser_player", self, step))



func _ensure_vstar_hud_texture_index_for_player(player_index: int) -> void:
	if player_index < 0:
		return
	var variant_count := VSTAR_HUD_TEXTURE_VARIANTS.size()
	if variant_count <= 0:
		return
	while _vstar_hud_texture_indices_by_player.size() <= player_index:
		var index := randi() % variant_count
		if variant_count > 1 and _vstar_hud_texture_indices_by_player.size() == 1:
			var first_index := int(_vstar_hud_texture_indices_by_player[0])
			if index == first_index:
				index = (index + 1 + (randi() % (variant_count - 1))) % variant_count
		_vstar_hud_texture_indices_by_player.append(index)



func _vstar_hud_width_for_height(height: float) -> float:
	return roundf(maxf(height, 1.0) * _vstar_hud_aspect())



func _vstar_hud_aspect() -> float:
	if VSTAR_HUD_TEXTURE != null:
		var texture_size := VSTAR_HUD_TEXTURE.get_size()
		if texture_size.y > 0.0:
			return texture_size.x / texture_size.y
	return VSTAR_LOST_HUD_WIDTH_RATIO
