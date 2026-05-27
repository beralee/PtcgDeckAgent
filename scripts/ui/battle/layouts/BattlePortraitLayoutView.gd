class_name BattlePortraitLayoutView
extends "res://scripts/ui/battle/layouts/BattleLayoutView.gd"

const BENCH_SIZE := 5
const CARD_ASPECT := 0.716
const DIALOG_OVERLAY_Z_INDEX := 220
const HAND_SCROLL_PANEL_PADDING := 18.0
const TOP_BAR_HEIGHT := 104.0
const TOP_BAR_GAP := 4.0
const TOP_BAR_TEXT_SCALE := 2.0
const PORTRAIT_VSTAR_HUD_HEIGHT_SCALE := 0.7
const VSTAR_LOST_HUD_WIDTH_RATIO := 2.4


func mode() -> String:
	return "portrait"


func apply(context: Dictionary) -> void:
	if _scene == null or _metrics_controller == null:
		return
	var content_rect: Rect2 = context.get("content_rect", Rect2())
	var logical_size: Vector2 = context.get("logical_size", content_rect.size)
	_call_scene("_set_portrait_layout_frame", [content_rect, logical_size])

	var viewport_size: Vector2 = content_rect.size
	if viewport_size == Vector2.ZERO:
		viewport_size = logical_size
	if viewport_size == Vector2.ZERO:
		viewport_size = context.get("viewport_size", Vector2.ZERO)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if _has_scene_property("portrait_apply_size"):
		_set_scene_var("portrait_apply_size", viewport_size)

	var ui_scale := _as_float(_call_scene("_portrait_layout_ui_scale", [viewport_size]), 1.0)
	var frame_rect := content_rect
	if frame_rect.size == Vector2.ZERO:
		frame_rect = Rect2(Vector2.ZERO, viewport_size)
	var full_size := logical_size
	if full_size == Vector2.ZERO:
		full_size = viewport_size
	var frame_top := frame_rect.position.y
	var frame_bottom_gap := maxf(full_size.y - frame_rect.position.y - frame_rect.size.y, 0.0)
	var safe_x := _as_float(_call_scene("_portrait_horizontal_safe_inset", [frame_rect.size]), 0.0)
	var frame_left := frame_rect.position.x + safe_x
	var frame_right_gap := maxf(full_size.x - frame_rect.position.x - frame_rect.size.x + safe_x, 0.0)
	var safe_viewport_size := Vector2(maxf(viewport_size.x - safe_x * 2.0, 1.0), viewport_size.y)

	var bench_sizes_variant: Variant = _call_scene("_current_bench_display_sizes")
	var my_bench_size := BENCH_SIZE
	var opp_bench_size := BENCH_SIZE
	if bench_sizes_variant is Dictionary:
		var bench_sizes: Dictionary = bench_sizes_variant
		my_bench_size = clampi(int(bench_sizes.get("my", BENCH_SIZE)), BENCH_SIZE, 8)
		opp_bench_size = clampi(int(bench_sizes.get("opp", BENCH_SIZE)), BENCH_SIZE, 8)
	else:
		var legacy_bench_size := _as_int(_call_scene("_current_bench_display_size"), BENCH_SIZE)
		my_bench_size = clampi(legacy_bench_size, BENCH_SIZE, 8)
		opp_bench_size = my_bench_size
	var bench_size := maxi(my_bench_size, opp_bench_size)
	var measured_variant: Variant = _metrics_controller.call("measure_portrait_card_layout", safe_viewport_size, bench_size, CARD_ASPECT)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var my_measured_variant: Variant = _metrics_controller.call("measure_portrait_card_layout", safe_viewport_size, my_bench_size, CARD_ASPECT)
	var my_measured: Dictionary = my_measured_variant if my_measured_variant is Dictionary else measured
	var opp_measured_variant: Variant = _metrics_controller.call("measure_portrait_card_layout", safe_viewport_size, opp_bench_size, CARD_ASPECT)
	var opp_measured: Dictionary = opp_measured_variant if opp_measured_variant is Dictionary else measured
	var active_card_size: Vector2 = measured.get("active_card_size", Vector2(118, 164))
	var bench_card_size: Vector2 = measured.get("bench_card_size", Vector2(86, 120))
	var hand_card_size: Vector2 = measured.get("hand_card_size", Vector2(124, 174))
	var hand_area_height := float(measured.get("hand_area_height", -1.0))
	var hand_scroll_height := float(measured.get("hand_scroll_height", -1.0))
	var bench_gap: float = float(measured.get("bench_gap", 8.0))
	var bench_columns := int(measured.get("bench_columns", BENCH_SIZE))
	var bench_rows := int(measured.get("bench_rows", 1))
	var my_bench_columns := int(my_measured.get("bench_columns", bench_columns))
	var my_bench_rows := int(my_measured.get("bench_rows", bench_rows))
	var opp_bench_columns := int(opp_measured.get("bench_columns", bench_columns))
	var opp_bench_rows := int(opp_measured.get("bench_rows", bench_rows))
	_set_scene_var("_play_card_size", hand_card_size)
	_set_scene_var("_field_active_card_size", active_card_size)
	_set_scene_var("_dialog_card_size", measured.get("dialog_card_size", _get_scene_var("_dialog_card_size")))
	_set_scene_var("_detail_card_size", measured.get("detail_card_size", _get_scene_var("_detail_card_size")))
	_call_scene("_sync_battle_layout_state_from_scene")

	apply_base_layout({
		"viewport_size": viewport_size,
		"frame_rect": frame_rect,
		"full_size": full_size,
		"safe_viewport_size": safe_viewport_size,
		"ui_scale": ui_scale,
		"safe_x": safe_x,
		"frame_top": frame_top,
		"frame_bottom_gap": frame_bottom_gap,
		"frame_left": frame_left,
		"frame_right_gap": frame_right_gap,
		"active_card_size": active_card_size,
		"bench_card_size": bench_card_size,
		"hand_card_size": hand_card_size,
		"hand_area_height": hand_area_height,
		"hand_scroll_height": hand_scroll_height,
		"bench_gap": bench_gap,
		"bench_capacity": bench_size,
		"bench_columns": bench_columns,
		"bench_rows": bench_rows,
		"my_bench_capacity": my_bench_size,
		"my_bench_columns": my_bench_columns,
		"my_bench_rows": my_bench_rows,
		"opp_bench_capacity": opp_bench_size,
		"opp_bench_columns": opp_bench_columns,
		"opp_bench_rows": opp_bench_rows,
		"dialog_overlay_z_index": DIALOG_OVERLAY_Z_INDEX,
		"hand_scroll_panel_padding": HAND_SCROLL_PANEL_PADDING,
	})
	_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply.after_base_layout"])
	apply_stadium_hud_metrics(safe_viewport_size, ui_scale)
	_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply.after_stadium_metrics"])
	var portrait_hud_metrics := apply_field_hud_metrics(safe_viewport_size, bench_card_size, active_card_size)
	sync_prize_hud_visibility(true)
	set_huds_on_field_edges(
		true,
		float(portrait_hud_metrics.get("side_width", 0.0)),
		float(portrait_hud_metrics.get("status_panel_height", 0.0)),
		float(portrait_hud_metrics.get("row_gap", 0.0)),
		safe_viewport_size
	)
	_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply.after_field_edge_huds"])
	enforce_field_axis_width(safe_viewport_size.x)
	_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply.after_axis_width"])
	_call_scene("_apply_portrait_hud_font_metrics", [_as_int(_call_scene("_portrait_hud_font_size", [safe_viewport_size]), 16)])
	_call_scene("_apply_top_action_button_metrics", [TOP_BAR_HEIGHT * ui_scale, safe_viewport_size, ui_scale, TOP_BAR_TEXT_SCALE])
	_call_scene("_apply_portrait_top_action_pair_metrics", [safe_viewport_size, ui_scale])
	_apply_top_label_clipping()
	set_top_status_compact(true)
	sync_prize_hud_visibility(true)
	_call_scene("_show_portrait_prize_dialog_if_needed")
	_call_scene("_update_portrait_overlay_metrics", [safe_viewport_size])
	apply_dialog_gallery_metrics(measured.get("dialog_card_size", _get_scene_var("_dialog_card_size")))
	_call_scene("_apply_portrait_popup_text_metrics")
	if _get_scene_var("_gsm") != null:
		_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply.before_refresh_hand"])
		_call_scene("_refresh_hand")
		_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply.after_refresh_hand"])


func apply_dialog_gallery_metrics(dialog_card_size: Vector2) -> void:
	var dialog_card_scroll := _get_scene_var("_dialog_card_scroll") as ScrollContainer
	var dialog_assignment_source_scroll := _get_scene_var("_dialog_assignment_source_scroll") as ScrollContainer
	var dialog_assignment_target_scroll := _get_scene_var("_dialog_assignment_target_scroll") as ScrollContainer
	var dialog_card_row := _get_scene_var("_dialog_card_row") as HBoxContainer
	var dialog_assignment_source_row := _get_scene_var("_dialog_assignment_source_row") as HBoxContainer
	var dialog_assignment_target_row := _get_scene_var("_dialog_assignment_target_row") as HBoxContainer
	if dialog_card_scroll != null:
		dialog_card_scroll.custom_minimum_size = Vector2(0, _as_float(_call_scene("_effective_dialog_card_scroll_height"), dialog_card_size.y))
	if dialog_assignment_source_scroll != null:
		dialog_assignment_source_scroll.custom_minimum_size = Vector2(0, _as_float(_call_scene("_dialog_card_scroll_height"), dialog_card_size.y))
	if dialog_assignment_target_scroll != null:
		dialog_assignment_target_scroll.custom_minimum_size = Vector2(0, _as_float(_call_scene("_dialog_card_scroll_height"), dialog_card_size.y))
	var dialog_controller := _get_scene_var("_battle_dialog_controller") as RefCounted
	if dialog_controller != null and dialog_card_scroll != null and dialog_card_row != null:
		dialog_controller.call("reset_dialog_card_row_metrics", dialog_card_scroll, dialog_card_row, dialog_card_size)
	if dialog_controller != null and dialog_assignment_source_scroll != null and dialog_assignment_source_row != null:
		dialog_controller.call("reset_dialog_card_row_metrics", dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size)
	if dialog_controller != null and dialog_assignment_target_scroll != null and dialog_assignment_target_row != null:
		dialog_controller.call("reset_dialog_card_row_metrics", dialog_assignment_target_scroll, dialog_assignment_target_row, dialog_card_size)
	var dialog_overlay := _get_scene_var("_dialog_overlay") as Control
	if dialog_overlay != null and dialog_overlay.visible and dialog_controller != null:
		dialog_controller.call("compact_dialog_box_to_content", _scene)


func sync_prize_hud_visibility(is_portrait: Variant = null) -> void:
	var opp_hud_left := _get_scene_var("_opp_hud_left") as PanelContainer
	if opp_hud_left == null:
		opp_hud_left = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft") as PanelContainer
	var my_hud_left := _get_scene_var("_my_hud_left") as PanelContainer
	if my_hud_left == null:
		my_hud_left = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft") as PanelContainer
	var opp_prize_title := _get_scene_var("_opp_prize_hud_title") as Label
	if opp_prize_title == null:
		opp_prize_title = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle") as Label
	var my_prize_title := _get_scene_var("_my_prize_hud_title") as Label
	if my_prize_title == null:
		my_prize_title = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle") as Label
	var opp_prize_count := _get_scene_var("_opp_prize_hud_count") as Label
	if opp_prize_count == null:
		opp_prize_count = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftValue") as Label
	var my_prize_count := _get_scene_var("_my_prize_hud_count") as Label
	if my_prize_count == null:
		my_prize_count = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftValue") as Label
	var opp_prize_host := _get_scene_var("_opp_prize_hud_host") as VBoxContainer
	if opp_prize_host == null:
		opp_prize_host = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppPrizeHudHost") as VBoxContainer
	var my_prize_host := _get_scene_var("_my_prize_hud_host") as VBoxContainer
	if my_prize_host == null:
		my_prize_host = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyPrizeHudHost") as VBoxContainer
	if opp_hud_left == null or my_hud_left == null:
		return
	var portrait := bool(is_portrait) if is_portrait != null else str(_call_scene("_current_resolved_battle_layout_mode")) == "portrait"
	if not portrait:
		opp_hud_left.visible = true
		my_hud_left.visible = true
		if opp_prize_title != null:
			opp_prize_title.visible = true
		if my_prize_title != null:
			my_prize_title.visible = true
		if opp_prize_count != null:
			opp_prize_count.visible = false
		if my_prize_count != null:
			my_prize_count.visible = false
		if opp_prize_host != null:
			opp_prize_host.visible = true
		if my_prize_host != null:
			my_prize_host.visible = true
		return
	opp_hud_left.visible = true
	my_hud_left.visible = true
	if opp_prize_title != null:
		opp_prize_title.visible = false
	if my_prize_title != null:
		my_prize_title.visible = false
	if opp_prize_count != null:
		opp_prize_count.visible = true
	if my_prize_count != null:
		my_prize_count.visible = true
	var prize_dialog_active := _as_bool(_get_scene_var("_portrait_prize_dialog_active"), false)
	var prize_dialog_host := _get_scene_var("_portrait_prize_dialog_host") as VBoxContainer
	if opp_prize_host != null:
		opp_prize_host.visible = prize_dialog_active and opp_prize_host == prize_dialog_host
	if my_prize_host != null:
		my_prize_host.visible = prize_dialog_active and my_prize_host == prize_dialog_host


func sync_top_action_visibility(is_portrait: Variant = null) -> void:
	var portrait := bool(is_portrait) if is_portrait != null else str(_call_scene("_current_resolved_battle_layout_mode")) == "portrait"
	var layout_button := _top_action_button_or_null(_get_scene_var("_btn_battle_layout") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleLayout")
	var more_button := _top_action_button_or_null(_get_scene_var("_btn_battle_more") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleMore")
	var portrait_direct_buttons := _as_array(_call_scene("_portrait_direct_top_action_buttons"))
	var live_direct_buttons: Array[Button] = [
		_top_action_button_or_null(_get_scene_var("_btn_opponent_hand") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnOpponentHand"),
		_top_action_button_or_null(_get_scene_var("_btn_battle_discuss_ai") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleDiscussAI"),
		_top_action_button_or_null(_get_scene_var("_btn_zeus_help") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnZeusHelp"),
	]
	var secondary_buttons: Array[Button] = [
		_top_action_button_or_null(_get_scene_var("_btn_attack_vfx_preview") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnAttackVfxPreview"),
		_top_action_button_or_null(_get_scene_var("_btn_ai_advice") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnAiAdvice"),
		_top_action_button_or_null(_get_scene_var("_btn_replay_prev_turn") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPrevTurn"),
		_top_action_button_or_null(_get_scene_var("_btn_replay_next_turn") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayNextTurn"),
		_top_action_button_or_null(_get_scene_var("_btn_replay_continue") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayContinue"),
		_top_action_button_or_null(_get_scene_var("_btn_replay_back_to_list") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayBackToList"),
	]
	if layout_button != null:
		layout_button.visible = false
	if more_button != null:
		more_button.visible = false
	var back_button := _top_action_button_or_null(_get_scene_var("_btn_back") as Button, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBack")
	if back_button != null:
		_call_scene("_restore_portrait_top_action", [back_button])
		back_button.visible = true
	if portrait:
		var actions_popup := _get_scene_var("_portrait_actions_popup") as PopupPanel
		if actions_popup != null:
			actions_popup.hide()
		if _as_bool(_call_scene("_is_review_mode"), false):
			for button: Button in live_direct_buttons:
				if button == null:
					continue
				_call_scene("_restore_portrait_top_action_label", [button])
				_call_scene("_store_and_hide_portrait_top_action", [button])
		for raw_button: Variant in portrait_direct_buttons:
			var button := raw_button as Button
			if button == null:
				continue
			var was_visible := _as_bool(_call_scene("_portrait_top_action_was_visible", [button]), false)
			var should_show := button == back_button or button.visible or was_visible
			if should_show:
				if button.has_meta("_portrait_previous_top_action_visible"):
					button.remove_meta("_portrait_previous_top_action_visible")
				button.visible = true
				_call_scene("_apply_portrait_top_action_compact_label", [button])
			else:
				_call_scene("_store_and_hide_portrait_top_action", [button])
		for button: Button in secondary_buttons:
			if button == null:
				continue
			if button in portrait_direct_buttons:
				continue
			_call_scene("_restore_portrait_top_action_label", [button])
			_call_scene("_store_and_hide_portrait_top_action", [button])
		return
	for raw_button: Variant in portrait_direct_buttons + secondary_buttons:
		var button := raw_button as Button
		if button == null:
			continue
		_call_scene("_restore_portrait_top_action_label", [button])
		_call_scene("_restore_portrait_top_action", [button])


func set_top_status_compact(enabled: bool) -> void:
	var top_bar_row := _node("TopBar/TopBarRow") as HBoxContainer
	var top_bar_left := _node("TopBar/TopBarRow/TopBarLeft") as Control
	var top_bar_center := _node("TopBar/TopBarRow/TopBarCenter") as Control
	if top_bar_row != null:
		top_bar_row.clip_contents = enabled
	if top_bar_left != null:
		top_bar_left.visible = true
		top_bar_left.clip_contents = true
		top_bar_left.custom_minimum_size.x = 0.0
		top_bar_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if top_bar_center != null:
		top_bar_center.visible = not enabled
		top_bar_center.clip_contents = true
		top_bar_center.custom_minimum_size.x = 0.0
		top_bar_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_phase := _get_scene_var("_lbl_phase") as Label
	if lbl_phase == null:
		lbl_phase = _find("LblPhase", true, false) as Label
	var lbl_turn := _get_scene_var("_lbl_turn") as Label
	if lbl_turn == null:
		lbl_turn = _find("LblTurn", true, false) as Label
	if lbl_phase != null:
		lbl_phase.visible = true
		lbl_phase.custom_minimum_size.x = 0.0
		lbl_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_phase.clip_text = true
		lbl_phase.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if enabled else TextServer.OVERRUN_NO_TRIMMING
		lbl_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_phase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_phase.autowrap_mode = TextServer.AUTOWRAP_OFF
	if lbl_turn != null:
		lbl_turn.visible = not enabled
		lbl_turn.custom_minimum_size.x = 0.0
		lbl_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_turn.clip_text = true
		lbl_turn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if enabled else TextServer.OVERRUN_NO_TRIMMING
		lbl_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_turn.autowrap_mode = TextServer.AUTOWRAP_OFF
	if top_bar_row != null:
		top_bar_row.queue_sort()


func apply_stadium_hud_metrics(viewport_size: Vector2, ui_scale: float) -> void:
	var stadium_sections := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections") as HBoxContainer
	var stadium_bar := _node("MainArea/CenterField/FieldArea/StadiumBar") as PanelContainer
	var lost_zone_section := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/LostZoneSection") as PanelContainer
	var stadium_center_section := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection") as PanelContainer
	var vstar_section := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection") as PanelContainer
	var stadium_action_row := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin/StadiumCenterVBox/StadiumActionRow") as HBoxContainer
	var stadium_label := _node("%StadiumLbl") as Label
	var stadium_button := _node("%BtnStadiumAction") as Button
	var info_columns := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns") as HBoxContainer
	var enemy_info_column := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn") as VBoxContainer
	var my_info_column := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn") as VBoxContainer
	var turn_action_column := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/TurnActionColumn") as VBoxContainer
	var gap := maxi(2, roundi(4.0 * ui_scale))
	if turn_action_column == null:
		turn_action_column = _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/TurnActionColumn") as VBoxContainer
	var stadium_hud_height := _as_float(_call_scene("_portrait_stadium_hud_height", [viewport_size, ui_scale]), maxf(64.0 * ui_scale, 56.0))
	var safe_width := maxf(viewport_size.x - 2.0 * float(gap), 1.0)
	var end_width := clampf(safe_width * 0.23, 78.0 * ui_scale, minf(132.0 * ui_scale, safe_width * 0.3))
	var stadium_max_width := maxf(safe_width - end_width - float(gap * 3), 80.0 * ui_scale)
	var stadium_width := clampf(safe_width * 0.36, 118.0 * ui_scale, minf(190.0 * ui_scale, stadium_max_width))
	var info_width := maxf(end_width, 60.0 * ui_scale)
	if stadium_bar != null:
		stadium_bar.clip_contents = true
		stadium_bar.custom_minimum_size.y = stadium_hud_height
		stadium_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if stadium_sections != null:
		stadium_sections.alignment = BoxContainer.ALIGNMENT_BEGIN
		stadium_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stadium_sections.custom_minimum_size = Vector2.ZERO
		stadium_sections.clip_contents = true
		stadium_sections.add_theme_constant_override("separation", gap)
	if lost_zone_section != null:
		lost_zone_section.visible = false
		lost_zone_section.custom_minimum_size = Vector2.ZERO
		lost_zone_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var landscape_stadium_left_spacer := _find("LandscapeStadiumLeftSpacer", true, false) as Control
	if landscape_stadium_left_spacer != null:
		landscape_stadium_left_spacer.visible = false
		landscape_stadium_left_spacer.custom_minimum_size = Vector2.ZERO
		landscape_stadium_left_spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	set_turn_action_in_stadium(true, end_width, gap, stadium_hud_height)
	if stadium_center_section != null:
		stadium_center_section.visible = true
		stadium_center_section.clip_contents = true
		stadium_center_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stadium_center_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if vstar_section != null:
		vstar_section.visible = false
		vstar_section.custom_minimum_size = Vector2.ZERO
		vstar_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if stadium_center_section != null:
		stadium_center_section.custom_minimum_size = Vector2(stadium_width, 0)
	if stadium_action_row != null:
		stadium_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stadium_action_row.add_theme_constant_override("separation", 2)
	if stadium_label != null:
		stadium_label.custom_minimum_size = Vector2.ZERO
		stadium_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stadium_label.clip_text = true
	if stadium_button != null:
		stadium_button.custom_minimum_size = Vector2.ZERO
		stadium_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stadium_button.clip_text = true
	if info_columns != null:
		info_columns.alignment = BoxContainer.ALIGNMENT_CENTER
		info_columns.add_theme_constant_override("separation", gap)
	for column_variant: Variant in [enemy_info_column, my_info_column]:
		var column := column_variant as VBoxContainer
		if column == null:
			continue
		column.custom_minimum_size = Vector2(info_width, 0)
		column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_theme_constant_override("separation", 2)
	if turn_action_column != null:
		turn_action_column.custom_minimum_size = Vector2(end_width, stadium_hud_height)
		turn_action_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		turn_action_column.clip_contents = true
	var hud_end_turn_button := _get_scene_var("_hud_end_turn_btn") as Button
	if hud_end_turn_button == null:
		hud_end_turn_button = _find("HudEndTurnBtn", true, false) as Button
	if hud_end_turn_button != null:
		hud_end_turn_button.custom_minimum_size = Vector2(end_width, stadium_hud_height)
		hud_end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud_end_turn_button.clip_text = true
	var field_active_size_variant: Variant = _get_scene_var("_field_active_card_size")
	var field_active_size: Vector2 = field_active_size_variant if field_active_size_variant is Vector2 else Vector2.ZERO
	var stadium_card_size := field_active_size if field_active_size != Vector2.ZERO else Vector2(stadium_width, stadium_hud_height)
	_call_scene("_apply_stadium_card_view_metrics", [stadium_card_size.x, stadium_card_size.y])


func set_turn_action_in_stadium(enabled: bool, action_width: float = 0.0, row_gap: int = 4, action_height: float = 0.0) -> void:
	var turn_action_column := _find("TurnActionColumn", true, false) as VBoxContainer
	if turn_action_column == null:
		return
	if enabled:
		var stadium_sections := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections") as HBoxContainer
		if stadium_sections == null:
			return
		var spacer := _call_scene("_ensure_portrait_stadium_spacer", [stadium_sections]) as Control
		if spacer != null:
			spacer.visible = true
			spacer.custom_minimum_size = Vector2.ZERO
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		turn_action_column.visible = true
		turn_action_column.custom_minimum_size = Vector2(action_width, 0)
		turn_action_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		turn_action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if spacer != null:
			_call_scene("_move_control_to_container", [spacer, stadium_sections, maxi(stadium_sections.get_child_count() - 1, 0)])
		_call_scene("_move_control_to_container", [turn_action_column, stadium_sections, stadium_sections.get_child_count()])
		var hud_end_turn_btn := _get_scene_var("_hud_end_turn_btn") as Button
		var existing_action_height := hud_end_turn_btn.custom_minimum_size.y if hud_end_turn_btn != null else 44.0
		var resolved_action_height := action_height if action_height > 0.0 else maxf(44.0, existing_action_height)
		turn_action_column.custom_minimum_size.y = resolved_action_height
		if hud_end_turn_btn != null:
			hud_end_turn_btn.custom_minimum_size = Vector2(action_width, resolved_action_height)
			hud_end_turn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hud_end_turn_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stadium_sections.add_theme_constant_override("separation", row_gap)
		return
	var info_columns := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns") as HBoxContainer
	if info_columns == null:
		return
	_call_scene("_move_control_to_container", [turn_action_column, info_columns, info_columns.get_child_count()])
	turn_action_column.custom_minimum_size = Vector2.ZERO
	turn_action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hud_end_turn_btn := _get_scene_var("_hud_end_turn_btn") as Button
	if hud_end_turn_btn != null:
		hud_end_turn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud_end_turn_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer := _find("PortraitStadiumSpacer", true, false) as Control
	if spacer != null:
		spacer.visible = false
		spacer.custom_minimum_size = Vector2.ZERO


func set_huds_on_field_edges(
	enabled: bool,
	status_width: float = 0.0,
	status_panel_height: float = 0.0,
	row_gap: float = 0.0,
	viewport_size: Vector2 = Vector2.ZERO
) -> void:
	var opp_left := _call_scene("_find_panel_by_name", ["OppHudLeft"]) as PanelContainer
	var opp_right := _call_scene("_find_panel_by_name", ["OppHudRight"]) as PanelContainer
	var my_left := _call_scene("_find_panel_by_name", ["MyHudLeft"]) as PanelContainer
	var my_right := _call_scene("_find_panel_by_name", ["MyHudRight"]) as PanelContainer
	if enabled:
		move_hud_pair_to_field_edges(
			"OppPortraitLeftHudGroup",
			"OppPortraitStatusStack",
			opp_left,
			opp_right,
			_call_scene("_find_hbox_by_name", ["OppFieldShell"]) as HBoxContainer,
			_call_scene("_find_control_by_name", ["OppFieldInner"]) as Control,
			_call_scene("_find_hbox_by_name", ["OppActiveRow"]) as HBoxContainer,
			_call_scene("_find_control_by_name", ["OppActive"]) as Control,
			_call_scene("_find_panel_by_name", ["InfoEnemyVstar"]) as PanelContainer,
			_call_scene("_find_panel_by_name", ["InfoEnemyLost"]) as PanelContainer,
			status_width,
			status_panel_height,
			row_gap
		)
		move_hud_pair_to_field_edges(
			"MyPortraitLeftHudGroup",
			"MyPortraitStatusStack",
			my_left,
			my_right,
			_call_scene("_find_hbox_by_name", ["MyFieldShell"]) as HBoxContainer,
			_call_scene("_find_control_by_name", ["MyFieldInner"]) as Control,
			_call_scene("_find_hbox_by_name", ["MyActiveRow"]) as HBoxContainer,
			_call_scene("_find_control_by_name", ["MyActive"]) as Control,
			_call_scene("_find_panel_by_name", ["InfoMyVstar"]) as PanelContainer,
			_call_scene("_find_panel_by_name", ["InfoMyLost"]) as PanelContainer,
			status_width,
			status_panel_height,
			row_gap
		)
		if viewport_size.x > 0.0:
			enforce_field_axis_width(viewport_size.x)
		position_edge_hud_overlay(viewport_size, status_width, row_gap)
		if _scene != null and is_instance_valid(_scene) and _scene.has_method("_position_portrait_edge_hud_overlay"):
			_scene.call_deferred("_position_portrait_edge_hud_overlay", viewport_size, status_width, row_gap)
		return
	_call_scene("_restore_portrait_status_huds_to_info_columns")
	set_turn_action_in_stadium(false)
	var vstar_section := _get_scene_var("_vstar_section") as PanelContainer
	if vstar_section != null:
		vstar_section.visible = true
	else:
		vstar_section = _find("VstarSection", true, false) as PanelContainer
		if vstar_section != null:
			vstar_section.visible = true
	_call_scene("_restore_portrait_hud_pair_to_shell", [
		opp_left,
		opp_right,
		_call_scene("_find_hbox_by_name", ["OppFieldShell"]) as HBoxContainer,
		_call_scene("_find_control_by_name", ["OppFieldInner"]) as Control
	])
	_call_scene("_restore_portrait_hud_pair_to_shell", [
		my_left,
		my_right,
		_call_scene("_find_hbox_by_name", ["MyFieldShell"]) as HBoxContainer,
		_call_scene("_find_control_by_name", ["MyFieldInner"]) as Control
	])
	_call_scene("_hide_portrait_edge_hud_groups")


func move_hud_pair_to_field_edges(
	left_group_name: String,
	status_stack_name: String,
	left_hud: PanelContainer,
	right_hud: PanelContainer,
	field_shell: HBoxContainer,
	field_inner: Control,
	active_row: HBoxContainer,
	active_card: Control,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer,
	status_width: float,
	status_panel_height: float,
	row_gap: float
) -> void:
	var overlay := _call_scene("_ensure_portrait_edge_hud_overlay") as Control
	if overlay == null:
		return
	var resolved_width := status_width if status_width > 0.0 else 76.0
	var resolved_panel_height := status_panel_height if status_panel_height > 0.0 else 40.0
	var resolved_vstar_height := resolved_panel_height * PORTRAIT_VSTAR_HUD_HEIGHT_SCALE
	var resolved_status_width := _as_float(
		_call_scene("_vstar_hud_width_for_height", [resolved_vstar_height]),
		roundf(maxf(resolved_vstar_height, 1.0) * VSTAR_LOST_HUD_WIDTH_RATIO)
	)
	var resolved_gap := row_gap if row_gap > 0.0 else 6.0
	if field_shell != null:
		field_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field_shell.alignment = BoxContainer.ALIGNMENT_CENTER
		field_shell.add_theme_constant_override("separation", 0)
	if field_inner != null and field_shell != null:
		field_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_call_scene("_move_control_to_container", [field_inner, field_shell, 0])

	var left_group := _call_scene("_ensure_portrait_edge_hud_group", [left_group_name, overlay, true]) as BoxContainer
	if left_group != null:
		left_group.visible = true
		var left_group_width := resolved_width
		if vstar_panel != null:
			left_group_width += resolved_gap + resolved_status_width
		left_group.custom_minimum_size = Vector2(left_group_width, 0)
		left_group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		left_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		left_group.alignment = BoxContainer.ALIGNMENT_CENTER
		left_group.add_theme_constant_override("separation", int(round(resolved_gap)))
		_call_scene("_move_control_to_container", [left_hud, left_group, 0])
		_call_scene("_move_control_to_container", [vstar_panel, left_group, 1])
		var status_stack := _call_scene("_ensure_portrait_status_stack", [status_stack_name, left_group]) as VBoxContainer
		if status_stack != null:
			status_stack.visible = false
			status_stack.custom_minimum_size = Vector2.ZERO
			status_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			status_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			status_stack.alignment = BoxContainer.ALIGNMENT_CENTER
			status_stack.add_theme_constant_override("separation", int(round(resolved_gap)))

	if vstar_panel != null:
		vstar_panel.visible = true
		vstar_panel.custom_minimum_size = Vector2(resolved_status_width, resolved_vstar_height)
		vstar_panel.set_meta("_vstar_lost_exact_minimum_size", vstar_panel.custom_minimum_size)
		vstar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vstar_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_call_scene("_ensure_vstar_hud_image", [vstar_panel])
	if left_hud != null:
		left_hud.custom_minimum_size = Vector2(resolved_width, left_hud.custom_minimum_size.y)
		left_hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		left_hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if active_row != null:
		active_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		active_row.alignment = BoxContainer.ALIGNMENT_CENTER
		active_row.add_theme_constant_override("separation", 0)
	if active_card != null:
		active_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		active_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right_group_name := left_group_name.replace("Left", "Right")
	var right_group := _call_scene("_ensure_portrait_edge_hud_group", [right_group_name, overlay, true]) as BoxContainer
	var right_width := right_hud.custom_minimum_size.x if right_hud != null and right_hud.custom_minimum_size.x > 0.0 else resolved_width
	if right_group != null:
		right_group.visible = true
		right_group.custom_minimum_size = Vector2(right_width, 0)
		right_group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		right_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right_group.alignment = BoxContainer.ALIGNMENT_CENTER
		right_group.add_theme_constant_override("separation", int(round(resolved_gap)))
	if right_hud != null:
		right_hud.custom_minimum_size = Vector2(right_width, right_hud.custom_minimum_size.y)
		right_hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		right_hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_call_scene("_move_control_to_container", [right_hud, right_group, 0])
	_call_scene("_move_lost_hud_to_pile", [lost_panel])


func enforce_field_axis_width(safe_width: float) -> void:
	if safe_width <= 0.0:
		return
	var expand_paths: Array[String] = [
		"MainArea/CenterField",
		"MainArea/CenterField/FieldArea",
		"MainArea/CenterField/FieldArea/OppField",
		"MainArea/CenterField/FieldArea/MyField",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner/OppActiveRow",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner/MyActiveRow",
	]
	for control_path: String in expand_paths:
		_apply_axis_width_to_control(_node(control_path) as Control, safe_width, true)
	for row_name: String in ["OppActiveRow", "MyActiveRow"]:
		var active_row := _find(row_name, true, false) as HBoxContainer
		if active_row == null:
			continue
		active_row.alignment = BoxContainer.ALIGNMENT_CENTER
		active_row.add_theme_constant_override("separation", 0)
	for shell_name: String in ["OppFieldShell", "MyFieldShell"]:
		var field_shell := _find(shell_name, true, false) as HBoxContainer
		if field_shell == null:
			continue
		field_shell.alignment = BoxContainer.ALIGNMENT_CENTER
		field_shell.add_theme_constant_override("separation", 0)
	for grid_variant: Variant in [_get_scene_var("_portrait_opp_bench_grid"), _get_scene_var("_portrait_my_bench_grid")]:
		var grid := grid_variant as Container
		if grid == null:
			continue
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.clip_contents = false
		grid.size = grid.get_combined_minimum_size()
		if grid is BoxContainer:
			(grid as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		var parent := grid.get_parent() as Container
		if parent != null:
			parent.queue_sort()
	_call_scene("_apply_battle_axis_field_alignment")


func position_edge_hud_overlay(viewport_size: Vector2, status_width: float, row_gap: float) -> void:
	var overlay := _find("PortraitEdgeHudOverlay", true, false) as Control
	if overlay == null:
		return
	var frame_rect_variant: Variant = _get_scene_var("_portrait_layout_frame_rect")
	var frame_rect: Rect2 = frame_rect_variant if frame_rect_variant is Rect2 else Rect2()
	if frame_rect.size == Vector2.ZERO:
		frame_rect = Rect2(Vector2.ZERO, viewport_size)
	var full_size_variant: Variant = _get_scene_var("_portrait_layout_full_size")
	var full_size: Vector2 = full_size_variant if full_size_variant is Vector2 else Vector2.ZERO
	if full_size == Vector2.ZERO:
		full_size = frame_rect.size
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.position = Vector2.ZERO
	overlay.size = full_size
	overlay.visible = true

	var ui_scale := _as_float(_call_scene("_portrait_layout_ui_scale", [frame_rect.size]), 1.0)
	var margin := maxf(4.0 * ui_scale, frame_rect.size.x * 0.012)
	var safe_x := _as_float(_call_scene("_portrait_horizontal_safe_inset", [frame_rect.size]), 0.0)
	var content_left := frame_rect.position.x + safe_x
	var content_right := frame_rect.position.x + frame_rect.size.x - safe_x
	var opp_center_y := _as_float(_call_scene("_portrait_active_center_y", ["OppActive", frame_rect.position.y + frame_rect.size.y * 0.315]), frame_rect.position.y + frame_rect.size.y * 0.315)
	var my_center_y := _as_float(_call_scene("_portrait_active_center_y", ["MyActive", frame_rect.position.y + frame_rect.size.y * 0.565]), frame_rect.position.y + frame_rect.size.y * 0.565)
	position_edge_hud_group("OppPortraitLeftHudGroup", Vector2(content_left + margin, opp_center_y), true)
	position_edge_hud_group("MyPortraitLeftHudGroup", Vector2(content_left + margin, my_center_y), true)
	position_edge_hud_group("OppPortraitRightHudGroup", Vector2(content_right - margin, opp_center_y), false)
	position_edge_hud_group("MyPortraitRightHudGroup", Vector2(content_right - margin, my_center_y), false)
	_clamp_edge_huds_away_from_bench(frame_rect, margin)

	for group_name: String in ["OppPortraitLeftHudGroup", "MyPortraitLeftHudGroup", "OppPortraitRightHudGroup", "MyPortraitRightHudGroup"]:
		var group := _find(group_name, true, false) as Control
		if group != null:
			var max_x := content_right - margin - group.size.x
			group.position.x = clampf(group.position.x, content_left + margin, max_x)
			group.position.y = clampf(
				group.position.y,
				frame_rect.position.y + margin,
				frame_rect.position.y + frame_rect.size.y - margin - group.size.y
			)


func position_edge_hud_group(group_name: String, anchor: Vector2, from_left: bool) -> void:
	var group := _find(group_name, true, false) as Control
	if group == null:
		return
	group.reset_size()
	var group_size := group.get_combined_minimum_size()
	if group_size == Vector2.ZERO:
		group_size = group.custom_minimum_size
	group.size = group_size
	var x := anchor.x if from_left else anchor.x - group_size.x
	var y := anchor.y - group_size.y * 0.5
	group.position = Vector2(x, y)


func _clamp_edge_huds_away_from_bench(frame_rect: Rect2, margin: float) -> void:
	var opp_bench_rect := _rect_in_battle_local(_find("PortraitOppBenchGrid", true, false) as Control)
	var my_bench_rect := _rect_in_battle_local(_find("PortraitMyBenchGrid", true, false) as Control)
	var frame_top := frame_rect.position.y + margin
	var frame_bottom := frame_rect.position.y + frame_rect.size.y - margin
	var opp_min_y := frame_top
	if opp_bench_rect.size.y > 0.0:
		opp_min_y = maxf(opp_min_y, opp_bench_rect.position.y + opp_bench_rect.size.y + margin)
	var my_max_y := frame_bottom
	if my_bench_rect.size.y > 0.0:
		my_max_y = minf(my_max_y, my_bench_rect.position.y - margin)
	for group_name: String in ["OppPortraitLeftHudGroup", "OppPortraitRightHudGroup"]:
		_clamp_edge_hud_group_vertical(group_name, opp_min_y, frame_bottom)
	for group_name: String in ["MyPortraitLeftHudGroup", "MyPortraitRightHudGroup"]:
		_clamp_edge_hud_group_vertical(group_name, frame_top, my_max_y)


func _clamp_edge_hud_group_vertical(group_name: String, min_top: float, max_bottom: float) -> void:
	var group := _find(group_name, true, false) as Control
	if group == null:
		return
	if group.size == Vector2.ZERO:
		var group_size := group.get_combined_minimum_size()
		if group_size == Vector2.ZERO:
			group_size = group.custom_minimum_size
		group.size = group_size
	var max_top := max_bottom - group.size.y
	if max_top < min_top:
		return
	group.position.y = clampf(group.position.y, min_top, max_top)


func _rect_in_battle_local(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var rect_variant: Variant = _call_scene("_control_rect_in_battle_local", [control])
	return rect_variant if rect_variant is Rect2 else Rect2()


func apply_field_hud_metrics(viewport_size: Vector2, bench_card_size: Vector2, active_card_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var ui_scale := _as_float(_call_scene("_portrait_layout_ui_scale", [viewport_size]), 1.0)
	var row_gap := clampf(viewport_size.x * 0.01, 3.0 * ui_scale, 6.0 * ui_scale)
	var active_width := active_card_size.x if active_card_size.x > 0.0 else bench_card_size.x
	var fit_side_width := (viewport_size.x - active_width - row_gap * 3.0) / 3.0
	var side_width := clampf(
		minf(clampf(viewport_size.x * 0.105, 68.0 * ui_scale, 104.0 * ui_scale), fit_side_width),
		56.0 * ui_scale,
		104.0 * ui_scale
	)
	side_width *= 1.3
	var pile_gap := roundi(clampf(bench_card_size.x * 0.06, 4.0 * ui_scale, 8.0 * ui_scale))
	var pile_preview_size := Vector2(roundf(bench_card_size.x * 0.5), roundf(bench_card_size.y * 0.5))
	var pile_panel_width := maxf(pile_preview_size.x + 14.0 * ui_scale, 68.0 * ui_scale) * 1.3
	var pile_panel_height := maxf(pile_preview_size.y + 38.0 * ui_scale, 78.0 * ui_scale)
	var pile_lost_height := _as_float(_call_scene("_pile_lost_panel_height", [pile_panel_height]), pile_panel_height)
	var pile_row_width := pile_panel_width * 2.0 + float(pile_gap)
	var pile_hud_width := pile_row_width + 8.0 * ui_scale
	var pile_hud_height := pile_panel_height + pile_lost_height + float(pile_gap) + 12.0 * ui_scale
	var status_panel_height := _as_float(_call_scene("_portrait_stadium_hud_height", [viewport_size, ui_scale]), 0.0)
	var status_stack_height := status_panel_height * 2.0 + row_gap
	var left_height := maxf(clampf(viewport_size.y * 0.07, 66.0 * ui_scale, 102.0 * ui_scale), status_stack_height)
	var hud_font_size := _as_int(_call_scene("_portrait_hud_font_size", [viewport_size]), 16)
	var caption_font_size := hud_font_size
	var value_font_size := hud_font_size
	var prize_value_font_size := hud_font_size
	var prize_height := left_height
	var opp_hud_left := _get_scene_var("_opp_hud_left") as PanelContainer
	if opp_hud_left == null:
		opp_hud_left = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft") as PanelContainer
	var my_hud_left := _get_scene_var("_my_hud_left") as PanelContainer
	if my_hud_left == null:
		my_hud_left = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft") as PanelContainer
	var opp_hud_right := _get_scene_var("_opp_hud_right") as PanelContainer
	if opp_hud_right == null:
		opp_hud_right = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight") as PanelContainer
	var my_hud_right := _get_scene_var("_my_hud_right") as PanelContainer
	if my_hud_right == null:
		my_hud_right = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight") as PanelContainer
	_call_scene("_apply_pile_hud_row_orientation", [false])
	for hud_variant: Variant in [opp_hud_left, my_hud_left, opp_hud_right, my_hud_right]:
		var hud := hud_variant as PanelContainer
		if hud == null:
			continue
		var is_prize_hud := hud == opp_hud_left or hud == my_hud_left
		hud.visible = true
		hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hud_width: float = side_width if is_prize_hud else pile_hud_width
		var hud_height: float = prize_height if is_prize_hud else pile_hud_height
		hud.custom_minimum_size = Vector2(hud_width, hud_height)
	var opp_field_shell := _get_scene_var("_opp_field_shell") as HBoxContainer
	if opp_field_shell == null:
		opp_field_shell = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell") as HBoxContainer
	var my_field_shell := _get_scene_var("_my_field_shell") as HBoxContainer
	if my_field_shell == null:
		my_field_shell = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell") as HBoxContainer
	for shell_variant: Variant in [opp_field_shell, my_field_shell]:
		var shell := shell_variant as HBoxContainer
		if shell != null:
			shell.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.008), roundi(4.0 * ui_scale), roundi(8.0 * ui_scale)))
			shell.alignment = BoxContainer.ALIGNMENT_CENTER
	for field_inner_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner",
	]:
		var field_inner := _node(field_inner_path) as VBoxContainer
		if field_inner != null:
			field_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_call_scene("_apply_battle_axis_field_alignment")
	for row_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow",
	]:
		var pile_row := _node(row_path) as BoxContainer
		if pile_row != null:
			pile_row.add_theme_constant_override("separation", pile_gap)
			pile_row.custom_minimum_size = Vector2(pile_row_width, pile_panel_height)
			pile_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pile_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for preview_variant: Variant in [
		_get_scene_var("_opp_deck_preview"),
		_get_scene_var("_my_deck_preview"),
		_get_scene_var("_opp_discard_preview"),
		_get_scene_var("_my_discard_preview"),
	]:
		var preview := preview_variant as BattleCardView
		if preview != null:
			preview.visible = true
			preview.custom_minimum_size = pile_preview_size
			preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel",
	]:
		var panel := _node(panel_path) as PanelContainer
		if panel == null:
			continue
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.custom_minimum_size = Vector2(pile_panel_width, pile_panel_height)
	for box_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox",
	]:
		var box := _node(box_path) as BoxContainer
		if box == null:
			continue
		box.custom_minimum_size = Vector2(pile_panel_width, pile_panel_height)
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	for header_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader",
	]:
		var header := _node(header_path) as BoxContainer
		if header == null:
			continue
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.size_flags_vertical = Control.SIZE_EXPAND_FILL
		header.alignment = BoxContainer.ALIGNMENT_CENTER
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudCaption",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudCaption",
	]:
		var caption := _node(caption_path) as Label
		if caption == null:
			continue
		caption.visible = true
		caption.add_theme_font_size_override("font_size", caption_font_size)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for value_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudValue",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudValue",
	]:
		var value_label := _node(value_path) as Label
		if value_label == null:
			continue
		value_label.visible = true
		value_label.add_theme_font_size_override("font_size", value_font_size)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for prize_label_variant: Variant in [_get_scene_var("_opp_prize_hud_title"), _get_scene_var("_my_prize_hud_title")]:
		var prize_label := prize_label_variant as Label
		if prize_label != null:
			prize_label.add_theme_font_size_override("font_size", caption_font_size)
			prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for prize_count_variant: Variant in [_get_scene_var("_opp_prize_hud_count"), _get_scene_var("_my_prize_hud_count")]:
		var prize_count := prize_count_variant as Label
		if prize_count != null:
			prize_count.add_theme_font_size_override("font_size", prize_value_font_size)
			prize_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			prize_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var opp_prize_host := _get_scene_var("_opp_prize_hud_host") as VBoxContainer
	if opp_prize_host == null:
		opp_prize_host = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppPrizeHudHost") as VBoxContainer
	var my_prize_host := _get_scene_var("_my_prize_hud_host") as VBoxContainer
	if my_prize_host == null:
		my_prize_host = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyPrizeHudHost") as VBoxContainer
	for host_variant: Variant in [opp_prize_host, my_prize_host]:
		var host := host_variant as VBoxContainer
		if host != null:
			host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_call_scene("_move_lost_huds_to_pile_huds", [pile_lost_height])
	_call_scene("_apply_portrait_hud_font_metrics", [hud_font_size])
	return {
		"side_width": side_width,
		"status_panel_height": status_panel_height,
		"row_gap": row_gap,
	}


func apply_base_layout(context: Dictionary) -> void:
	var viewport_size: Vector2 = context.get("viewport_size", Vector2.ZERO)
	var frame_rect: Rect2 = context.get("frame_rect", Rect2(Vector2.ZERO, viewport_size))
	var full_size: Vector2 = context.get("full_size", viewport_size)
	var safe_viewport_size: Vector2 = context.get("safe_viewport_size", viewport_size)
	var ui_scale := float(context.get("ui_scale", 1.0))
	var safe_x := float(context.get("safe_x", 0.0))
	var frame_top := float(context.get("frame_top", 0.0))
	var frame_right_gap := float(context.get("frame_right_gap", safe_x))
	var frame_bottom_gap := float(context.get("frame_bottom_gap", 0.0))
	var frame_left := frame_rect.position.x + safe_x
	var active_card_size: Vector2 = context.get("active_card_size", Vector2(118, 164))
	var bench_card_size: Vector2 = context.get("bench_card_size", Vector2(86, 120))
	var hand_card_size: Vector2 = context.get("hand_card_size", Vector2(124, 174))
	var context_hand_area_height := float(context.get("hand_area_height", -1.0))
	var context_hand_scroll_height := float(context.get("hand_scroll_height", -1.0))
	var bench_gap := float(context.get("bench_gap", 8.0))
	var bench_capacity := int(context.get("bench_capacity", BENCH_SIZE))
	var bench_columns := int(context.get("bench_columns", BENCH_SIZE))
	var bench_rows := int(context.get("bench_rows", 1))
	var my_bench_capacity := int(context.get("my_bench_capacity", bench_capacity))
	var my_bench_columns := int(context.get("my_bench_columns", bench_columns))
	var my_bench_rows := int(context.get("my_bench_rows", bench_rows))
	var opp_bench_capacity := int(context.get("opp_bench_capacity", bench_capacity))
	var opp_bench_columns := int(context.get("opp_bench_columns", bench_columns))
	var opp_bench_rows := int(context.get("opp_bench_rows", bench_rows))
	var dialog_overlay_z_index := int(context.get("dialog_overlay_z_index", 220))
	var hand_scroll_panel_padding := float(context.get("hand_scroll_panel_padding", 18.0))

	var dialog_overlay := _get_scene_var("_dialog_overlay") as Panel
	if dialog_overlay == null:
		dialog_overlay = _find("DialogOverlay", true, false) as Panel
	if dialog_overlay != null:
		dialog_overlay.z_index = dialog_overlay_z_index
		dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_call_scene("_set_portrait_panel_collapsed", [_node("MainArea/LeftPanel") as Control, true])
	_call_scene("_set_portrait_panel_collapsed", [_node("MainArea/RightPanel") as Control, true])
	_call_scene("_set_portrait_panel_collapsed", [_node("MainArea/LogPanel") as Control, true])

	var backdrop := _node("BattleBackdrop") as TextureRect
	if backdrop != null and _metrics_controller != null:
		_metrics_controller.call("apply_portrait_backdrop_rect", backdrop, full_size)

	var main_area := _node("MainArea") as HBoxContainer
	var center_field := _node("MainArea/CenterField") as VBoxContainer
	var top_bar := _node("TopBar") as PanelContainer
	var top_bar_height := TOP_BAR_HEIGHT * ui_scale
	var top_bar_gap := TOP_BAR_GAP * ui_scale
	var safe_width := maxf(frame_rect.size.x - safe_x * 2.0, 1.0)
	var top_bar_top := frame_top + 4.0 * ui_scale
	var top_bar_rect := Rect2(Vector2(frame_left, top_bar_top), Vector2(safe_width, top_bar_height))
	var main_top := top_bar_rect.position.y + top_bar_rect.size.y + top_bar_gap
	var main_bottom := frame_rect.position.y + frame_rect.size.y
	var main_rect := Rect2(Vector2(frame_left, main_top), Vector2(safe_width, maxf(main_bottom - main_top, 1.0)))
	if main_area != null:
		_apply_explicit_portrait_rect(main_area, main_rect)
		main_area.clip_contents = true
		main_area.add_theme_constant_override("separation", 0)
	if center_field != null:
		center_field.custom_minimum_size.x = safe_width
		center_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_field.clip_contents = true
		center_field.add_theme_constant_override("separation", maxi(3, roundi(3.0 * ui_scale)))
	if top_bar != null:
		_apply_explicit_portrait_rect(top_bar, top_bar_rect)
		top_bar.clip_contents = true

	var action_width := _as_float(_call_scene("_resolve_top_action_button_width", [safe_viewport_size, -1, ui_scale]), 80.0 * ui_scale)
	var action_gap := _as_int(_call_scene("_resolve_top_action_gap", [safe_viewport_size]), maxi(3, roundi(4.0 * ui_scale)))
	_call_scene("_apply_top_action_button_metrics", [top_bar_height, safe_viewport_size, ui_scale, TOP_BAR_TEXT_SCALE])
	_call_scene("_apply_portrait_top_action_pair_metrics", [safe_viewport_size, ui_scale])
	_call_scene("_apply_top_bar_space_metrics", [safe_viewport_size, action_width, action_gap])
	sync_top_action_visibility(true)
	_call_scene("_apply_portrait_top_action_pair_metrics", [safe_viewport_size, ui_scale])

	_apply_top_label_clipping()
	_call_scene("_set_portrait_top_status_compact", [true])

	var field_area := _node("MainArea/CenterField/FieldArea") as VBoxContainer
	var stadium_bar := _node("MainArea/CenterField/FieldArea/StadiumBar") as PanelContainer
	if field_area != null:
		field_area.custom_minimum_size.x = safe_width
		field_area.clip_contents = true
		field_area.add_theme_constant_override("separation", 0)
	if stadium_bar != null:
		stadium_bar.clip_contents = true
		stadium_bar.custom_minimum_size = Vector2(safe_width, 64.0 * ui_scale)

	var opp_active := _find("OppActive", true, false) as PanelContainer
	var my_active := _find("MyActive", true, false) as PanelContainer
	if opp_active != null:
		opp_active.custom_minimum_size = active_card_size
	if my_active != null:
		my_active.custom_minimum_size = active_card_size
	_call_scene("_set_field_card_status_text_scale", [1.0])
	_call_scene("_set_field_card_portrait_status_metrics", [true])

	var my_bench := _find("MyBench", true, false) as HBoxContainer
	var opp_bench := _find("OppBench", true, false) as HBoxContainer
	_call_scene("_set_portrait_bench_grid_enabled", [
		true,
		bench_card_size,
		bench_gap,
		bench_capacity,
		bench_columns,
		bench_rows,
		my_bench_capacity,
		my_bench_columns,
		my_bench_rows,
		opp_bench_capacity,
		opp_bench_columns,
		opp_bench_rows,
	])
	_apply_bench_panel_metrics(_call_scene("_portrait_bench_panels", [my_bench, _get_scene_var("_portrait_my_bench_grid")]), bench_card_size)
	_apply_bench_panel_metrics(_call_scene("_portrait_bench_panels", [opp_bench, _get_scene_var("_portrait_opp_bench_grid")]), bench_card_size)
	enforce_field_axis_width(safe_width)

	var hand_area := _node("MainArea/CenterField/HandArea") as PanelContainer
	var hand_scroll := _find("HandScroll", true, false) as ScrollContainer
	var hand_container := _find("HandContainer", true, false) as HBoxContainer
	var hand_scroll_height := context_hand_scroll_height
	if hand_scroll_height <= 0.0:
		hand_scroll_height = _as_float(_call_scene("_hand_scroll_height_with_scrollbar", [hand_card_size.y]), hand_card_size.y + 20.0 * ui_scale)
	var hand_area_height := context_hand_area_height
	if hand_area_height <= 0.0:
		hand_area_height = hand_scroll_height + hand_scroll_panel_padding * ui_scale
	if hand_area != null:
		hand_area.clip_contents = true
		hand_area.custom_minimum_size = Vector2(safe_width, hand_area_height)
	if hand_scroll != null:
		hand_scroll.clip_contents = true
		hand_scroll.custom_minimum_size = Vector2(safe_width, hand_scroll_height)
		_call_scene("_configure_hand_drag_scroll", [hand_scroll])
	if hand_container != null:
		hand_container.clip_contents = true
		hand_container.custom_minimum_size = Vector2(0, hand_card_size.y)
		hand_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hand_container.add_theme_constant_override("separation", clampi(int(hand_card_size.x * 0.08), 6, 12))
		hand_container.alignment = BoxContainer.ALIGNMENT_BEGIN

	_enforce_portrait_safe_width_contract()
	_apply_portrait_overlay_z_order()
	_call_scene("_trace_portrait_layout_stage", ["portrait_view.apply_base_layout.end"])


func _enforce_portrait_safe_width_contract() -> void:
	for control_path: NodePath in ["TopBar", "MainArea"]:
		var control := _node(control_path) as Control
		if control == null:
			continue
		control.clip_contents = true
		control.custom_minimum_size.x = 0.0
	for control_name: String in ["HandArea", "HandScroll", "StadiumBar", "StadiumSections"]:
		var control := _find(control_name, true, false) as Control
		if control == null:
			continue
		control.clip_contents = true
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if control_name == "StadiumSections":
			control.custom_minimum_size.x = 0.0


func _apply_explicit_portrait_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	control.position = rect.position
	control.size = rect.size


func _apply_axis_width_to_control(control: Control, width: float, expand: bool) -> void:
	if control == null:
		return
	control.clip_contents = true
	control.custom_minimum_size.x = width
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_CENTER
	if control.size.x > 0.0:
		control.size = Vector2(width, control.size.y)
	if control is Container:
		(control as Container).queue_sort()


func _top_action_button_or_null(button: Button, path: String) -> Button:
	return button if button != null else _node(path) as Button


func _apply_portrait_overlay_z_order() -> void:
	var overlay_z: Dictionary = {
		"PortraitEdgeHudOverlay": 30,
		"FieldInteractionOverlay": 300,
		"DiscardOverlay": 230,
		"DialogOverlay": 240,
		"CoinFlipOverlay": 250,
		"HandoverPanel": 260,
		"DetailOverlay": 500,
	}
	for node_name: String in overlay_z.keys():
		var control := _find(node_name, true, false) as Control
		if control == null:
			continue
		control.z_index = int(overlay_z[node_name])
		if node_name == "FieldInteractionOverlay":
			control.z_as_relative = false


func _apply_bench_panel_metrics(panels_variant: Variant, bench_card_size: Vector2) -> void:
	var panels: Array = panels_variant if panels_variant is Array else []
	for panel_variant: Variant in panels:
		var panel := panel_variant as PanelContainer
		if panel == null:
			continue
		panel.custom_minimum_size = bench_card_size
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _apply_top_label_clipping() -> void:
	for top_slot_name: String in ["TopBarLeft", "TopBarCenter"]:
		var top_slot := _find(top_slot_name, true, false) as Control
		if top_slot == null:
			continue
		top_slot.clip_contents = true
		top_slot.custom_minimum_size.x = 0.0
		top_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for top_label_variant: Variant in [
		_get_scene_var("_lbl_phase") if _get_scene_var("_lbl_phase") != null else _find("LblPhase", true, false),
		_get_scene_var("_lbl_turn") if _get_scene_var("_lbl_turn") != null else _find("LblTurn", true, false),
	]:
		var top_label := top_label_variant as Label
		if top_label == null:
			continue
		top_label.custom_minimum_size.x = 0.0
		top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_label.clip_text = true
		top_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _as_float(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback


func _as_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	return fallback
