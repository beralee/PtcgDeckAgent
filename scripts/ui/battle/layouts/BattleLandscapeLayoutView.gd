class_name BattleLandscapeLayoutView
extends "res://scripts/ui/battle/layouts/BattleLayoutView.gd"

const BENCH_SIZE := 5
const CARD_ASPECT := 0.716
const HAND_SCROLL_PANEL_PADDING := 18.0
const BENCH_SLOT_GAP := 1
const LANDSCAPE_VSTAR_LOST_HUD_HEIGHT_SCALE := 0.7
const VSTAR_HUD_HEIGHT_MULTIPLIER := 2.0
const VSTAR_LOST_HUD_WIDTH_RATIO := 2.4


func mode() -> String:
	return "landscape"


func apply(context: Dictionary) -> void:
	if _scene == null or _metrics_controller == null:
		return
	var viewport_size: Vector2 = context.get("logical_size", context.get("viewport_size", Vector2.ZERO))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	apply_scene_layout(viewport_size)


func apply_scene_layout(viewport_size: Vector2) -> void:
	if not _has_scene_property("_battle_layout_coordinator") and _has_scene_method("_apply_landscape_layout_impl"):
		_call_scene("_apply_landscape_layout_impl", [viewport_size])
		return
	_set_scene_var("_active_battle_layout_mode", "landscape")
	_call_scene("_set_portrait_top_status_compact", [false])
	prepare_layout({
		"viewport_size": viewport_size,
	})

	var left_panel := _node("MainArea/LeftPanel") as VBoxContainer
	var right_panel := _node("MainArea/RightPanel") as VBoxContainer
	var log_panel := _node("MainArea/LogPanel") as PanelContainer
	var main_area := _node("MainArea") as HBoxContainer
	var hand_area := _node("MainArea/CenterField/HandArea") as PanelContainer
	var opp_hand_bar := _node("MainArea/CenterField/OppHandBar") as PanelContainer
	var field_area := _node("MainArea/CenterField/FieldArea") as VBoxContainer
	var stadium_bar := _node("MainArea/CenterField/FieldArea/StadiumBar") as PanelContainer
	var stadium_sections := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections") as HBoxContainer
	var lost_zone_section := _get_scene_var("_lost_zone_section") as PanelContainer
	if lost_zone_section == null:
		lost_zone_section = _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/LostZoneSection") as PanelContainer
	var stadium_center_section := _get_scene_var("_stadium_center_section") as PanelContainer
	if stadium_center_section == null:
		stadium_center_section = _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection") as PanelContainer
	var vstar_section := _get_scene_var("_vstar_section") as PanelContainer
	if vstar_section == null:
		vstar_section = _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection") as PanelContainer
	var stadium_action_row := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin/StadiumCenterVBox/StadiumActionRow") as HBoxContainer
	var stadium_center_margin := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin") as MarginContainer
	var vstar_margin := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin") as MarginContainer
	var vstar_vbox := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox") as VBoxContainer
	var enemy_info_column := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn") as VBoxContainer
	var my_info_column := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn") as VBoxContainer
	var enemy_vstar_margin := _find("EnemyVstarMargin", true, false) as MarginContainer
	var enemy_lost_margin := _find("EnemyLostMargin", true, false) as MarginContainer
	var my_vstar_margin := _find("MyVstarMargin", true, false) as MarginContainer
	var my_lost_margin := _find("MyLostMargin", true, false) as MarginContainer
	var turn_action_column := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/TurnActionColumn") as VBoxContainer
	if turn_action_column == null:
		turn_action_column = _find("TurnActionColumn", true, false) as VBoxContainer
	var opp_field_inner := _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner") as VBoxContainer
	var my_field_inner := _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner") as VBoxContainer
	var opp_active_row := _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner/OppActiveRow") as HBoxContainer
	var my_active_row := _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner/MyActiveRow") as HBoxContainer
	var opp_bench_box := _get_scene_var("_opp_bench") as HBoxContainer
	if opp_bench_box == null:
		opp_bench_box = _node("%OppBench") as HBoxContainer
	var my_bench_box := _get_scene_var("_my_bench") as HBoxContainer
	if my_bench_box == null:
		my_bench_box = _node("%MyBench") as HBoxContainer
	var opp_active_panel := _get_scene_var("_opp_active") as PanelContainer
	if opp_active_panel == null:
		opp_active_panel = _node("%OppActive") as PanelContainer
	var my_active_panel := _get_scene_var("_my_active") as PanelContainer
	if my_active_panel == null:
		my_active_panel = _node("%MyActive") as PanelContainer
	var opp_prize_hud := _get_scene_var("_opp_hud_left") as PanelContainer
	if opp_prize_hud == null:
		opp_prize_hud = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft") as PanelContainer
	var my_prize_hud := _get_scene_var("_my_hud_left") as PanelContainer
	if my_prize_hud == null:
		my_prize_hud = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft") as PanelContainer
	var hud_end_turn_btn := _get_scene_var("_hud_end_turn_btn") as Button
	if hud_end_turn_btn == null:
		hud_end_turn_btn = _node("%HudEndTurnBtn") as Button
	var hand_scroll := _get_scene_var("_hand_scroll") as ScrollContainer
	if hand_scroll == null:
		hand_scroll = _node("%HandScroll") as ScrollContainer
	var hand_container := _get_scene_var("_hand_container") as HBoxContainer
	if hand_container == null:
		hand_container = _node("%HandContainer") as HBoxContainer
	var top_bar := _node("TopBar") as PanelContainer
	var opp_field_shell := _get_scene_var("_opp_field_shell") as HBoxContainer
	if opp_field_shell == null:
		opp_field_shell = _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell") as HBoxContainer
	var my_field_shell := _get_scene_var("_my_field_shell") as HBoxContainer
	if my_field_shell == null:
		my_field_shell = _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell") as HBoxContainer
	if top_bar == null or main_area == null or left_panel == null or right_panel == null or log_panel == null:
		return

	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE, false)
	top_bar.offset_left = 6.0
	top_bar.offset_top = 4.0
	top_bar.offset_right = -6.0
	main_area.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	main_area.offset_left = 0.0
	main_area.offset_right = 0.0
	main_area.offset_bottom = 0.0
	if lost_zone_section != null:
		lost_zone_section.visible = true
		lost_zone_section.custom_minimum_size = Vector2.ZERO
		lost_zone_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if stadium_center_section != null:
		stadium_center_section.custom_minimum_size = Vector2.ZERO
		stadium_center_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if vstar_section != null:
		vstar_section.visible = true
		vstar_section.custom_minimum_size = Vector2.ZERO
		vstar_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var side_width: float = 0.0 if not left_panel.visible else clampf(viewport_size.x * 0.05, 72.0, 108.0)
	var right_width: float = 0.0 if not right_panel.visible else side_width + 6.0
	var log_width: float = clampf(viewport_size.x * 0.125, 124.0, 204.0)
	left_panel.custom_minimum_size = Vector2(side_width, 0)
	right_panel.custom_minimum_size = Vector2(right_width, 0)
	log_panel.custom_minimum_size = Vector2(log_width, 0)

	if opp_hand_bar != null:
		opp_hand_bar.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.032, 24.0, 34.0))
	if field_area != null:
		field_area.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.004), 2, 6))
	if stadium_sections != null:
		stadium_sections.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.006), 6, 14))
	if stadium_action_row != null:
		stadium_action_row.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.004), 6, 12))
	if opp_field_shell != null:
		opp_field_shell.alignment = BoxContainer.ALIGNMENT_BEGIN
		opp_field_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opp_field_shell.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.006), 8, 16))
	if my_field_shell != null:
		my_field_shell.alignment = BoxContainer.ALIGNMENT_BEGIN
		my_field_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		my_field_shell.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.006), 8, 16))
	if opp_field_inner != null:
		opp_field_inner.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.003), 1, 4))
	if my_field_inner != null:
		my_field_inner.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.003), 1, 4))
	_call_scene("_apply_battle_axis_field_alignment")
	if opp_active_row != null:
		opp_active_row.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.002), 2, 4))
	if my_active_row != null:
		my_active_row.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.002), 2, 4))
	if my_bench_box != null:
		my_bench_box.add_theme_constant_override("separation", BENCH_SLOT_GAP)
		my_bench_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if opp_bench_box != null:
		opp_bench_box.add_theme_constant_override("separation", BENCH_SLOT_GAP)
		opp_bench_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var center_width := maxf(0.0, viewport_size.x - side_width - right_width - log_width)
	var bench_size := _as_int(_call_scene("_current_bench_display_size"), BENCH_SIZE)
	var bench_spacing: float = float(BENCH_SLOT_GAP)
	var measured_variant: Variant = _metrics_controller.call(
		"measure_card_layout",
		viewport_size,
		center_width,
		bench_spacing,
		bench_size,
		CARD_ASPECT
	)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var play_card_size: Vector2 = measured.get("play_card_size", _get_scene_var("_play_card_size"))
	var dialog_card_size: Vector2 = measured.get("dialog_card_size", _get_scene_var("_dialog_card_size"))
	var detail_card_size: Vector2 = measured.get("detail_card_size", _get_scene_var("_detail_card_size"))
	_set_scene_var("_play_card_size", play_card_size)
	_set_scene_var("_field_active_card_size", play_card_size)
	_set_scene_var("_dialog_card_size", dialog_card_size)
	_set_scene_var("_detail_card_size", detail_card_size)
	_call_scene("_sync_battle_layout_state_from_scene")
	var preview_card_size: Vector2 = measured.get("preview_card_size", Vector2(roundf(play_card_size.x * 0.9), roundf(play_card_size.y * 0.9)))
	var prize_slot_size: Vector2 = measured.get("prize_slot_size", preview_card_size)

	var hand_scroll_height := _as_float(_call_scene("_hand_scroll_height_with_scrollbar", [play_card_size.y]), play_card_size.y)
	if hand_area != null:
		hand_area.custom_minimum_size = Vector2(0, hand_scroll_height + HAND_SCROLL_PANEL_PADDING)
	if hand_scroll != null:
		hand_scroll.custom_minimum_size = Vector2(0, hand_scroll_height)
	if hand_container != null:
		hand_container.custom_minimum_size = Vector2(0, play_card_size.y)
		hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var stadium_height: float = float(measured.get("stadium_height", roundf(clampf(viewport_size.y * 0.082, 54.0, 72.0) * (4.0 / 9.0))))
	var stadium_inner_vpad: int = int(measured.get("stadium_inner_vpad", clampi(int(stadium_height * 0.08), 1, 3)))
	var vstar_stack_gap: int = int(measured.get("vstar_stack_gap", clampi(int(stadium_height * 0.08), 1, 2)))
	var vstar_panel_vpad: int = int(measured.get("vstar_panel_vpad", clampi(int(stadium_height * 0.06), 1, 2)))
	var prize_panel_height: float = float(measured.get("prize_panel_height", roundf((preview_card_size.y * 2.0 + 24.0) * 0.95)))
	var hud_action_button_height: float = _as_float(_call_scene("_resolve_hud_action_button_height", [stadium_height, stadium_inner_vpad, true]), stadium_height)
	var top_action_button_height: float = _as_float(_call_scene("_resolve_hud_action_button_height", [stadium_height, stadium_inner_vpad, false]), stadium_height)
	stadium_height = maxf(stadium_height, hud_action_button_height + float(stadium_inner_vpad * 2))
	var top_bar_height: float = _as_float(_call_scene("_resolve_top_bar_height", [viewport_size, stadium_height, top_action_button_height, stadium_inner_vpad]), top_action_button_height)
	top_bar.offset_bottom = top_bar.offset_top + top_bar_height
	main_area.offset_top = top_bar.offset_bottom + 4.0
	_call_scene("_apply_top_action_button_metrics", [top_action_button_height, viewport_size])
	if stadium_bar != null:
		stadium_bar.custom_minimum_size = Vector2(0, stadium_height)
	var end_turn_hud_width := _as_float(_call_scene("_landscape_pile_lost_panel_width", [preview_card_size]), preview_card_size.x)
	var stadium_center_width := clampf(viewport_size.x * 0.24, 280.0, 420.0)
	var stadium_section_gap := stadium_sections.get_theme_constant("separation") if stadium_sections != null else 0
	var stadium_left_anchor_width := _as_float(_call_scene("_resolve_landscape_stadium_left_spacer_width", [
		prize_slot_size,
		opp_prize_hud,
		my_prize_hud,
		center_width,
		stadium_center_width,
		end_turn_hud_width,
		float(stadium_section_gap)
	]), 0.0)
	var landscape_stadium_left_spacer := _call_scene("_ensure_landscape_stadium_left_spacer", [stadium_sections]) as Control
	if stadium_sections != null:
		stadium_sections.alignment = BoxContainer.ALIGNMENT_BEGIN
		stadium_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stadium_sections.offset_top = float(stadium_inner_vpad)
		stadium_sections.offset_bottom = -float(stadium_inner_vpad)
	if landscape_stadium_left_spacer != null:
		landscape_stadium_left_spacer.visible = true
		landscape_stadium_left_spacer.custom_minimum_size = Vector2(stadium_left_anchor_width, 0)
		landscape_stadium_left_spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		landscape_stadium_left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_call_scene("_move_control_to_container", [landscape_stadium_left_spacer, stadium_sections, 0])
	if lost_zone_section != null:
		lost_zone_section.visible = true
		lost_zone_section.custom_minimum_size = Vector2.ZERO
		lost_zone_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if stadium_center_section != null:
		stadium_center_section.custom_minimum_size = Vector2(stadium_center_width, 0)
		stadium_center_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if stadium_sections != null:
			_call_scene("_move_control_to_container", [stadium_center_section, stadium_sections, 1])
	if lost_zone_section != null and stadium_sections != null:
		_call_scene("_move_control_to_container", [lost_zone_section, stadium_sections, 2])
	if vstar_section != null:
		vstar_section.visible = false
		vstar_section.custom_minimum_size = Vector2.ZERO
		vstar_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var portrait_stadium_spacer := _find("PortraitStadiumSpacer", true, false) as Control
	if portrait_stadium_spacer != null:
		portrait_stadium_spacer.visible = false
		portrait_stadium_spacer.custom_minimum_size = Vector2.ZERO
	if stadium_center_margin != null:
		stadium_center_margin.offset_top = float(stadium_inner_vpad)
		stadium_center_margin.offset_bottom = -float(stadium_inner_vpad)
	if vstar_margin != null:
		vstar_margin.offset_top = float(stadium_inner_vpad)
		vstar_margin.offset_bottom = -float(stadium_inner_vpad)
	if vstar_vbox != null:
		vstar_vbox.add_theme_constant_override("separation", vstar_stack_gap)
	if enemy_info_column != null:
		enemy_info_column.add_theme_constant_override("separation", vstar_stack_gap * 2)
	if my_info_column != null:
		my_info_column.add_theme_constant_override("separation", vstar_stack_gap * 2)
	for margin_variant in [enemy_vstar_margin, enemy_lost_margin, my_vstar_margin, my_lost_margin]:
		var margin := margin_variant as MarginContainer
		if margin == null:
			continue
		margin.offset_top = float(vstar_panel_vpad)
		margin.offset_bottom = -float(vstar_panel_vpad)
	if turn_action_column != null:
		turn_action_column.custom_minimum_size = Vector2(end_turn_hud_width, hud_action_button_height)
		turn_action_column.size_flags_horizontal = Control.SIZE_SHRINK_END
		turn_action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if stadium_sections != null and turn_action_column != null:
		_call_scene("_move_control_to_container", [turn_action_column, stadium_sections, stadium_sections.get_child_count()])
	if hud_end_turn_btn != null:
		hud_end_turn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud_end_turn_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hud_end_turn_btn.custom_minimum_size = Vector2(end_turn_hud_width, hud_action_button_height)
	_call_scene("_apply_landscape_stadium_action_text_metrics", [hud_action_button_height])
	_call_scene("_apply_stadium_card_view_metrics", [play_card_size.x, play_card_size.y])
	if opp_prize_hud != null:
		opp_prize_hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		opp_prize_hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		opp_prize_hud.custom_minimum_size = Vector2(0, prize_panel_height)
	if my_prize_hud != null:
		my_prize_hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		my_prize_hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		my_prize_hud.custom_minimum_size = Vector2(0, prize_panel_height)
	var backdrop := _node("BattleBackdrop") as TextureRect
	if backdrop != null:
		_metrics_controller.call("apply_backdrop_rect", backdrop, viewport_size, log_width)
	if hand_container != null:
		hand_container.add_theme_constant_override("separation", clampi(int(play_card_size.x * 0.08), 4, 10))
	if my_active_panel != null:
		my_active_panel.custom_minimum_size = play_card_size
		my_active_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		my_active_panel.clip_contents = false
	if opp_active_panel != null:
		opp_active_panel.custom_minimum_size = play_card_size
		opp_active_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		opp_active_panel.clip_contents = false
	apply_status_huds_beside_active(play_card_size, stadium_height, vstar_stack_gap)
	if my_bench_box != null:
		my_bench_box.custom_minimum_size = Vector2(0, play_card_size.y)
		for panel_variant in my_bench_box.get_children():
			var panel := panel_variant as PanelContainer
			if panel == null:
				continue
			panel.custom_minimum_size = play_card_size
			panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			panel.clip_contents = false
	if opp_bench_box != null:
		opp_bench_box.custom_minimum_size = Vector2(0, play_card_size.y)
		for panel_variant in opp_bench_box.get_children():
			var panel := panel_variant as PanelContainer
			if panel == null:
				continue
			panel.custom_minimum_size = play_card_size
			panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			panel.clip_contents = false
	for prize_view_variant in _as_array(_get_scene_var("_opp_prize_slots")):
		var prize_view := prize_view_variant as BattleCardView
		if prize_view == null:
			continue
		prize_view.custom_minimum_size = prize_slot_size
		prize_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prize_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for prize_view_variant in _as_array(_get_scene_var("_my_prize_slots")):
		var prize_view := prize_view_variant as BattleCardView
		if prize_view == null:
			continue
		prize_view.custom_minimum_size = prize_slot_size
		prize_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prize_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for preview_variant in [
		_get_scene_var("_opp_deck_preview"),
		_get_scene_var("_my_deck_preview"),
		_get_scene_var("_opp_discard_preview"),
		_get_scene_var("_my_discard_preview")
	]:
		var preview := preview_variant as BattleCardView
		if preview != null:
			preview.visible = true
			preview.custom_minimum_size = preview_card_size
			preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_pile_hud_metrics(preview_card_size)

	var dialog_box := _get_scene_var("_dialog_box") as PanelContainer
	if dialog_box == null:
		dialog_box = _find("DialogBox", true, false) as PanelContainer
	if dialog_box != null:
		dialog_box.custom_minimum_size = Vector2(
			clampf(viewport_size.x * 0.62, 640.0, 1120.0), 0
		)
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

	var detail_box := _node("DetailOverlay/DetailCenter/DetailBox") as PanelContainer
	var detail_gap := clampi(int(viewport_size.x * 0.008), 10, 16)
	var detail_text_width := clampf(viewport_size.x * 0.25, 300.0, 420.0)
	var preferred_detail_width := detail_card_size.x + detail_text_width + float(detail_gap) + 42.0
	var preferred_detail_height := detail_card_size.y + 84.0
	if detail_box != null:
		detail_box.custom_minimum_size = Vector2(
			minf(maxf(preferred_detail_width, 620.0), maxf(viewport_size.x - 32.0, 300.0)),
			minf(maxf(preferred_detail_height, 460.0), maxf(viewport_size.y - 32.0, 300.0))
		)
	var detail_body := _node("DetailOverlay/DetailCenter/DetailBox/DetailVBox/DetailBody") as HBoxContainer
	if detail_body != null:
		detail_body.add_theme_constant_override("separation", detail_gap)
	var detail_card_view := _get_scene_var("_detail_card_view") as Control
	if detail_card_view != null:
		detail_card_view.custom_minimum_size = detail_card_size
	var detail_content := _get_scene_var("_detail_content") as Control
	if detail_content != null:
		detail_content.custom_minimum_size = Vector2(detail_text_width - 28.0, maxf(detail_card_size.y - 24.0, 220.0))
	var detail_text_panel := _node("DetailOverlay/DetailCenter/DetailBox/DetailVBox/DetailBody/DetailTextPanel") as PanelContainer
	if detail_text_panel != null:
		detail_text_panel.custom_minimum_size = Vector2(detail_text_width, detail_card_size.y)

	if dialog_card_row != null:
		for child in dialog_card_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = dialog_card_size
	if dialog_assignment_source_row != null:
		for child in dialog_assignment_source_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = dialog_card_size
	if dialog_assignment_target_row != null:
		for child in dialog_assignment_target_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = dialog_card_size
	_call_scene("_apply_discard_collection_metrics", [viewport_size])
	_call_scene("_update_field_interaction_panel_metrics", [viewport_size])

	if _get_scene_var("_gsm") != null:
		_call_scene("_refresh_hand")
	_call_scene("_request_stadium_hud_debug_overlay_refresh")


func prepare_layout(context: Dictionary) -> void:
	_call_scene("_restore_portrait_popup_text_metrics")
	_call_scene("_restore_portrait_scrollbar_metrics")
	_call_scene("_close_portrait_prize_dialog")
	_call_scene("_set_portrait_layout_frame", [Rect2(), Vector2.ZERO])
	_call_scene("_set_portrait_huds_on_field_edges", [false])
	_call_scene("_set_portrait_panel_collapsed", [_node("MainArea/LeftPanel") as Control, false])
	_call_scene("_set_portrait_panel_collapsed", [_node("MainArea/RightPanel") as Control, false])
	_call_scene("_set_portrait_panel_collapsed", [_node("MainArea/LogPanel") as Control, false])
	_call_scene("_set_portrait_bench_grid_enabled", [false, Vector2.ZERO, 0.0])
	_call_scene("_set_field_card_status_text_scale", [0.8])
	_call_scene("_set_field_card_portrait_status_metrics", [true])
	_call_scene("_sync_portrait_prize_hud_visibility", [false])
	_call_scene("_sync_portrait_top_action_visibility", [false])
	_call_scene("_restore_landscape_overlay_z_order")

	var viewport_size: Vector2 = context.get("viewport_size", Vector2.ZERO)
	var backdrop := _node("BattleBackdrop") as TextureRect
	if backdrop != null and _metrics_controller != null:
		_metrics_controller.call("apply_backdrop_rect", backdrop, viewport_size, 0.0)


func apply_status_huds_beside_active(card_size: Vector2, stadium_height: float, row_gap: int) -> void:
	var base_panel_height := clampf(
		minf(maxf(stadium_height, card_size.y * 0.18), card_size.y * 0.36),
		28.0,
		44.0
	)
	var old_panel_height := clampf(roundf(base_panel_height * LANDSCAPE_VSTAR_LOST_HUD_HEIGHT_SCALE), 20.0, 31.0)
	var panel_height := roundf(old_panel_height * VSTAR_HUD_HEIGHT_MULTIPLIER)
	var gap := maxi(row_gap, 4)
	var panel_width := _as_float(
		_call_scene("_vstar_hud_width_for_height", [panel_height]),
		roundf(maxf(panel_height, 1.0) * VSTAR_LOST_HUD_WIDTH_RATIO)
	)
	var status_stack_height := panel_height
	var side_column_width := maxf(roundf(card_size.x * 2.6), panel_width + roundf(card_size.x * 1.75))
	move_status_stack_to_active_row(
		"OppLandscapeStatusStack",
		"OppLandscapeStatusLeftSpacer",
		"OppLandscapeStatusSlot",
		_call_scene("_find_hbox_by_name", ["OppActiveRow"]) as HBoxContainer,
		_call_scene("_find_control_by_name", ["OppActive"]) as Control,
		_call_scene("_find_panel_by_name", ["InfoEnemyVstar"]) as PanelContainer,
		_call_scene("_find_panel_by_name", ["InfoEnemyLost"]) as PanelContainer,
		panel_width,
		panel_height,
		status_stack_height,
		side_column_width,
		gap
	)
	move_status_stack_to_active_row(
		"MyLandscapeStatusStack",
		"MyLandscapeStatusLeftSpacer",
		"MyLandscapeStatusSlot",
		_call_scene("_find_hbox_by_name", ["MyActiveRow"]) as HBoxContainer,
		_call_scene("_find_control_by_name", ["MyActive"]) as Control,
		_call_scene("_find_panel_by_name", ["InfoMyVstar"]) as PanelContainer,
		_call_scene("_find_panel_by_name", ["InfoMyLost"]) as PanelContainer,
		panel_width,
		panel_height,
		status_stack_height,
		side_column_width,
		gap
	)

	var info_columns := _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns") as HBoxContainer
	var enemy_info_column := _call_scene("_find_vbox_by_name", ["EnemyInfoColumn"]) as VBoxContainer
	var my_info_column := _call_scene("_find_vbox_by_name", ["MyInfoColumn"]) as VBoxContainer
	var turn_action_column := _find("TurnActionColumn", true, false) as VBoxContainer
	if enemy_info_column != null:
		enemy_info_column.visible = false
		enemy_info_column.custom_minimum_size = Vector2.ZERO
	if my_info_column != null:
		my_info_column.visible = false
		my_info_column.custom_minimum_size = Vector2.ZERO
	if info_columns != null:
		info_columns.alignment = BoxContainer.ALIGNMENT_CENTER
		info_columns.add_theme_constant_override("separation", gap)
	if turn_action_column != null:
		turn_action_column.visible = true
		turn_action_column.size_flags_horizontal = Control.SIZE_SHRINK_END
		turn_action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL


func move_status_stack_to_active_row(
	stack_name: String,
	left_spacer_name: String,
	right_slot_name: String,
	active_row: HBoxContainer,
	active_card: Control,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer,
	panel_width: float,
	panel_height: float,
	stack_height: float,
	side_column_width: float,
	gap: int
) -> void:
	if active_row == null:
		return
	active_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_row.alignment = BoxContainer.ALIGNMENT_CENTER
	active_row.add_theme_constant_override("separation", gap)
	var left_spacer := _call_scene("_ensure_landscape_status_spacer", [left_spacer_name, active_row]) as Control
	var right_slot := _call_scene("_ensure_landscape_status_slot", [right_slot_name, active_row]) as CenterContainer
	if left_spacer != null:
		left_spacer.visible = true
		left_spacer.custom_minimum_size = Vector2(side_column_width, stack_height)
		left_spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		left_spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if active_card != null:
		active_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		active_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if right_slot == null:
		return
	right_slot.visible = true
	right_slot.custom_minimum_size = Vector2(side_column_width, stack_height)
	right_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stack := _call_scene("_ensure_landscape_status_stack", [stack_name, right_slot]) as VBoxContainer
	if stack == null:
		return
	stack.visible = true
	stack.custom_minimum_size = Vector2(panel_width, stack_height)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", gap)
	if active_card != null and active_card.get_parent() == active_row:
		_call_scene("_move_control_to_container", [left_spacer, active_row, 0])
		_call_scene("_move_control_to_container", [active_card, active_row, 1])
		_call_scene("_move_control_to_container", [right_slot, active_row, 2])
	else:
		_call_scene("_move_control_to_container", [left_spacer, active_row, 0])
		_call_scene("_move_control_to_container", [right_slot, active_row, 1])
	_call_scene("_move_control_to_container", [stack, right_slot, 0])
	_call_scene("_move_control_to_container", [vstar_panel, stack, 0])
	if vstar_panel != null:
		vstar_panel.visible = true
		vstar_panel.custom_minimum_size = Vector2(panel_width, panel_height)
		vstar_panel.set_meta("_vstar_lost_exact_minimum_size", vstar_panel.custom_minimum_size)
		vstar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vstar_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_call_scene("_ensure_vstar_hud_image", [vstar_panel])
	_call_scene("_move_lost_hud_to_pile", [lost_panel, 0.0, true])


func apply_pile_hud_metrics(preview_card_size: Vector2) -> void:
	_call_scene("_apply_pile_hud_row_orientation", [false])
	var row_gap := _as_int(_call_scene("_landscape_pile_row_gap", [preview_card_size]), clampi(int(preview_card_size.x * 0.10), 6, 10))
	var panel_width := _as_float(_call_scene("_landscape_pile_panel_width", [preview_card_size]), maxf(preview_card_size.x + 8.0, 54.0))
	var panel_height := maxf(preview_card_size.y + 28.0, 78.0)
	var lost_panel_height := _as_float(_call_scene("_pile_lost_panel_height", [panel_height]), clampf(roundf(panel_height * 0.32), 24.0, 46.0))
	var row_width := _as_float(_call_scene("_landscape_pile_lost_panel_width", [preview_card_size]), panel_width * 2.0 + float(row_gap))
	var hud_width := row_width + 8.0
	var hud_height := panel_height + lost_panel_height + float(row_gap) + 12.0
	for row_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow"
	]:
		var row := _node(row_path) as BoxContainer
		if row == null:
			continue
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.custom_minimum_size = Vector2(row_width, panel_height)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", row_gap)
	for hud_variant: Variant in [
		_get_scene_var("_opp_hud_right") if _get_scene_var("_opp_hud_right") != null else _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight"),
		_get_scene_var("_my_hud_right") if _get_scene_var("_my_hud_right") != null else _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight")
	]:
		var hud := hud_variant as PanelContainer
		if hud == null:
			continue
		hud.visible = true
		hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hud.custom_minimum_size = Vector2(hud_width, hud_height)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel"
	]:
		var panel := _node(panel_path) as PanelContainer
		if panel == null:
			continue
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.custom_minimum_size = Vector2(panel_width, panel_height)
	for preview_variant: Variant in [
		_get_scene_var("_opp_deck_preview"),
		_get_scene_var("_my_deck_preview"),
		_get_scene_var("_opp_discard_preview"),
		_get_scene_var("_my_discard_preview"),
	]:
		var preview := preview_variant as BattleCardView
		if preview == null:
			continue
		preview.visible = true
		preview.custom_minimum_size = preview_card_size
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for box_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox"
	]:
		var box := _node(box_path) as BoxContainer
		if box == null:
			continue
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudCaption",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudCaption"
	]:
		var caption := _node(caption_path) as Label
		if caption != null:
			caption.add_theme_font_size_override("font_size", 14)
	for value_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudValue",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudValue"
	]:
		var value_label := _node(value_path) as Label
		if value_label != null:
			value_label.add_theme_font_size_override("font_size", 14)
	for label_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue"
	]:
		var label := _node(label_path) as Label
		if label != null:
			label.visible = false
	_call_scene("_move_lost_huds_to_pile_huds", [lost_panel_height, true])
