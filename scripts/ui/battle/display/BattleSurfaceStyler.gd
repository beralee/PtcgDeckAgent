class_name BattleSurfaceStyler
extends RefCounted

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const VSTAR_LOST_HUD_VALUE_FONT_RATIO := 0.55

var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func apply_battle_surface_styles() -> void:
	_style_panel(_get_scene_var("_opp_prizes_box") as Control, Color(0.05, 0.09, 0.13, 0.82), Color(0.37, 0.47, 0.64), 16)
	_style_panel(_get_scene_var("_my_prizes_box") as Control, Color(0.05, 0.09, 0.13, 0.82), Color(0.35, 0.6, 0.5), 16)
	_style_panel(_get_scene_var("_opp_deck_box") as Control, Color(0.05, 0.09, 0.13, 0.82), Color(0.37, 0.47, 0.64), 16)
	_style_panel(_get_scene_var("_my_deck_box") as Control, Color(0.05, 0.09, 0.13, 0.82), Color(0.35, 0.6, 0.5), 16)
	_style_panel(_node("MainArea/CenterField/FieldArea/OppField") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0))
	_style_panel(_node("MainArea/CenterField/FieldArea/MyField") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0))
	_style_panel(_get_scene_var("_opp_hud_left") as Control, Color(0.02, 0.1, 0.16, 0.7), Color(0.22, 0.68, 0.84, 0.92), 16)
	_style_panel(_get_scene_var("_my_hud_left") as Control, Color(0.03, 0.11, 0.15, 0.7), Color(0.27, 0.86, 0.7, 0.92), 16)
	_style_panel(_get_scene_var("_opp_hud_right") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 16)
	_style_panel(_get_scene_var("_my_hud_right") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 16)
	_style_panel(_get_scene_var("_opp_hand_bar") as Control, Color(0.01, 0.11, 0.18, 0.72), Color(0.16, 0.62, 0.76, 0.9), 10)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel",
	]:
		_style_panel(_node(panel_path) as Control, Color(0.02, 0.1, 0.16, 0.64), Color(0.22, 0.68, 0.84, 0.78), 12)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel",
	]:
		_style_panel(_node(panel_path) as Control, Color(0.03, 0.11, 0.15, 0.64), Color(0.27, 0.86, 0.7, 0.74), 12)
	_style_panel(_node("MainArea/CenterField/HandArea") as Control, Color(0.05, 0.09, 0.13, 0.88), Color(0.42, 0.58, 0.74))
	_style_panel(_get_scene_var("_top_bar") as Control, Color(0.01, 0.08, 0.13, 0.78), Color(0.19, 0.66, 0.8, 0.9), 14)
	_style_panel(_node("MainArea/CenterField/FieldArea/StadiumBar") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 14)
	_style_panel(_get_scene_var("_lost_zone_section") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 12)
	_style_panel(_get_scene_var("_stadium_center_section") as Control, Color(0.11, 0.16, 0.12, 0.82), Color(0.73, 0.87, 0.62), 12)
	_style_panel(_get_scene_var("_vstar_section") as Control, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 12)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost",
	]:
		_style_panel(_node(panel_path) as Control, Color(0.01, 0.11, 0.18, 0.72), Color(0.16, 0.62, 0.76, 0.9), 10)
	style_vstar_lost_huds()
	var lost_zone_section := _get_scene_var("_lost_zone_section") as CanvasItem
	if lost_zone_section != null:
		lost_zone_section.self_modulate = Color(1, 1, 1, 0)
	var stadium_lbl := _get_scene_var("_stadium_lbl") as Label
	if stadium_lbl != null:
		stadium_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stadium_lbl.add_theme_font_size_override("font_size", 12)
	var stadium_action := _get_scene_var("_btn_stadium_action") as Button
	if stadium_action != null:
		stadium_action.add_theme_color_override("font_color", Color(0.93, 0.96, 0.88))
		stadium_action.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.94))
		stadium_action.add_theme_color_override("font_disabled_color", Color(0.5, 0.53, 0.49))
		stadium_action.add_theme_font_size_override("font_size", 12)
	for button_variant: Variant in [
		_get_scene_var("_hud_end_turn_btn"),
		_get_scene_var("_btn_opponent_hand"),
		_get_scene_var("_btn_attack_vfx_preview"),
		_get_scene_var("_btn_ai_advice"),
		_get_scene_var("_btn_battle_discuss_ai"),
		_get_scene_var("_btn_zeus_help"),
		_get_scene_var("_btn_battle_more"),
		_get_scene_var("_btn_battle_layout"),
		_get_scene_var("_btn_replay_prev_turn"),
		_get_scene_var("_btn_replay_next_turn"),
		_get_scene_var("_btn_replay_continue"),
		_get_scene_var("_btn_replay_back_to_list"),
		_get_scene_var("_btn_back"),
	]:
		_call("_style_hud_button", [button_variant])
	_call("_style_end_turn_hud_buttons")
	_call("_request_stadium_hud_debug_overlay_refresh")
	for label_variant: Variant in [_get_scene_var("_lbl_phase"), _get_scene_var("_lbl_turn")]:
		var label := label_variant as Label
		if label != null:
			label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.12, 0.9))
			label.add_theme_constant_override("outline_size", 1)
	_apply_caption_colors()
	_apply_value_label_colors()
	_apply_side_hud_caption_colors()
	_apply_side_hud_value_colors()
	_apply_side_hud_labels()
	_apply_prize_count_fonts()
	_apply_pile_caption_fonts()
	_apply_opponent_hand_label_style()
	_apply_log_panel_style()
	_hide_legacy_side_hud_text()
	_style_panel(_get_scene_var("_dialog_box") as Control, Color(0.05, 0.08, 0.11, 0.98), Color(0.38, 0.55, 0.72), 20)
	_call("_style_card_detail_overlay")
	style_discard_collection_overlay()
	_style_panel(_node("CoinFlipOverlay/CoinCenter/CoinBox") as Control, Color(0.05, 0.08, 0.11, 0.98), Color(0.89, 0.78, 0.34), 18)
	_call("_style_handover_overlay")
	_style_panel(_get_scene_var("_my_active") as Control, Color(0.04, 0.07, 0.1, 0.88), Color(0.52, 0.72, 0.58), 18)
	_style_panel(_get_scene_var("_opp_active") as Control, Color(0.04, 0.07, 0.1, 0.88), Color(0.63, 0.68, 0.79), 18)
	_style_bench_panels(_get_scene_var("_my_bench") as HBoxContainer, Color(0.04, 0.07, 0.1, 0.76), Color(0.32, 0.5, 0.44), 16)
	_style_bench_panels(_get_scene_var("_opp_bench") as HBoxContainer, Color(0.04, 0.07, 0.1, 0.76), Color(0.33, 0.39, 0.5), 16)
	var hand_scroll := _get_scene_var("_hand_scroll") as ScrollContainer
	if hand_scroll != null:
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _scene != null:
		HudThemeScript.apply_scrollbars_recursive(_scene)


func _apply_caption_colors() -> void:
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudCaption",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar/EnemyVstarMargin/EnemyVstarVBox/EnemyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar/MyVstarMargin/MyVstarVBox/MyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost/EnemyLostMargin/EnemyLostVBox/EnemyLostCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost/MyLostMargin/MyLostVBox/MyLostCaption",
	]:
		var caption := _node(caption_path) as Label
		if caption != null:
			caption.add_theme_color_override("font_color", Color(0.54, 0.9, 0.94, 0.9))


func style_discard_collection_overlay() -> void:
	var discard_overlay := _get_scene_var("_discard_overlay") as Panel
	if discard_overlay != null:
		discard_overlay.self_modulate = Color(1, 1, 1, 1)
		var overlay_style := StyleBoxFlat.new()
		overlay_style.bg_color = Color(0.0, 0.02, 0.04, 0.70)
		discard_overlay.add_theme_stylebox_override("panel", overlay_style)

	var discard_box := _node("DiscardOverlay/DiscardCenter/DiscardBox") as PanelContainer
	if discard_box != null:
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = Color(0.05, 0.08, 0.11, 0.98)
		box_style.border_color = Color(0.38, 0.55, 0.72, 1.0)
		box_style.set_border_width_all(2)
		box_style.set_corner_radius_all(20)
		box_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		box_style.shadow_size = 24
		box_style.shadow_offset = Vector2(0, 10)
		box_style.content_margin_left = 18
		box_style.content_margin_top = 14
		box_style.content_margin_right = 18
		box_style.content_margin_bottom = 16
		discard_box.add_theme_stylebox_override("panel", box_style)

	var discard_vbox := _node("DiscardOverlay/DiscardCenter/DiscardBox/DiscardVBox") as VBoxContainer
	if discard_vbox != null:
		discard_vbox.add_theme_constant_override("separation", 10)

	var discard_title := _get_scene_var("_discard_title") as Label
	if discard_title != null:
		discard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		discard_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		discard_title.add_theme_font_size_override("font_size", 18)
		discard_title.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
		discard_title.add_theme_color_override("font_outline_color", Color(0.0, 0.06, 0.10, 0.92))
		discard_title.add_theme_constant_override("outline_size", 2)

	var discard_list := _get_scene_var("_discard_list") as ItemList
	if discard_list != null:
		discard_list.add_theme_font_size_override("font_size", 16)
		discard_list.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
		discard_list.add_theme_color_override("font_selected_color", Color(0.98, 1.0, 1.0))

	var discard_close_btn := _get_scene_var("_discard_close_btn") as Button
	if discard_close_btn != null:
		_call("_style_hud_button", [discard_close_btn])
		discard_close_btn.custom_minimum_size = Vector2(220, 54)
		discard_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		discard_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		discard_close_btn.add_theme_font_size_override("font_size", 17)


func style_vstar_lost_huds() -> void:
	for config: Dictionary in _vstar_lost_hud_configs():
		_style_vstar_lost_hud(config)
	_call("_refresh_vstar_lost_hud_values")


func _vstar_lost_hud_configs() -> Array[Dictionary]:
	return [
		{
			"panel": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar",
			"panel_name": "InfoEnemyVstar",
			"caption": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar/EnemyVstarMargin/EnemyVstarVBox/EnemyVstarCaption",
			"caption_name": "EnemyVstarCaption",
			"value": _get_scene_var("_enemy_vstar_value"),
			"kind": "vstar",
		},
		{
			"panel": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar",
			"panel_name": "InfoMyVstar",
			"caption": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar/MyVstarMargin/MyVstarVBox/MyVstarCaption",
			"caption_name": "MyVstarCaption",
			"value": _get_scene_var("_my_vstar_value"),
			"kind": "vstar",
		},
		{
			"panel": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost",
			"panel_name": "InfoEnemyLost",
			"caption": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost/EnemyLostMargin/EnemyLostVBox/EnemyLostCaption",
			"caption_name": "EnemyLostCaption",
			"value": _get_scene_var("_enemy_lost_value"),
			"kind": "lost",
		},
		{
			"panel": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost",
			"panel_name": "InfoMyLost",
			"caption": "MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost/MyLostMargin/MyLostVBox/MyLostCaption",
			"caption_name": "MyLostCaption",
			"value": _get_scene_var("_my_lost_value"),
			"kind": "lost",
		},
	]


func _style_vstar_lost_hud(config: Dictionary) -> void:
	var panel := _call("_find_panel_by_path_or_name", [str(config.get("panel", "")), str(config.get("panel_name", ""))]) as PanelContainer
	if panel == null:
		return
	var kind := str(config.get("kind", ""))
	if kind == "vstar":
		_call("_ensure_vstar_hud_image", [panel])
	else:
		var texture_rect := panel.find_child("HudImageTexture", true, false) as TextureRect
		if texture_rect != null:
			var texture_parent := texture_rect.get_parent()
			if texture_parent != null:
				texture_parent.remove_child(texture_rect)
			texture_rect.queue_free()
	panel.clip_contents = true
	_call("_apply_vstar_lost_hud_metrics", [panel])
	_call("_style_vstar_lost_hud_panel", [panel, kind, false])

	var caption := _call("_find_label_by_path_or_name", [str(config.get("caption", "")), str(config.get("caption_name", ""))]) as Label
	if caption != null:
		caption.visible = false
	var value_label := config.get("value", null) as Label
	if value_label != null:
		value_label.visible = kind != "vstar"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var label_font_size := clampi(roundi(panel.custom_minimum_size.y * VSTAR_LOST_HUD_VALUE_FONT_RATIO), 14, 28)
		value_label.add_theme_font_size_override("font_size", label_font_size)
		value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
		value_label.add_theme_constant_override("outline_size", 2)

	var content := _call("_first_control_child", [panel]) as Control
	if content != null:
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if content is MarginContainer:
			var margin := content as MarginContainer
			margin.offset_left = 0.0
			margin.offset_top = 0.0
			margin.offset_right = 0.0
			margin.offset_bottom = 0.0
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _call("_first_vbox_descendant", [content]) as VBoxContainer
	if box != null:
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
	if kind == "vstar":
		_call("_sync_vstar_hud_image_metrics", [panel])


func _apply_value_label_colors() -> void:
	for value_variant: Variant in [
		_get_scene_var("_enemy_vstar_value"),
		_get_scene_var("_my_vstar_value"),
		_get_scene_var("_enemy_lost_value"),
		_get_scene_var("_my_lost_value"),
	]:
		var value_label := value_variant as Label
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
	for value_variant: Variant in [
		_get_scene_var("_opp_prize_hud_count"),
		_get_scene_var("_opp_deck_hud_value"),
		_get_scene_var("_opp_discard_hud_value"),
		_get_scene_var("_my_prize_hud_count"),
		_get_scene_var("_my_deck_hud_value"),
		_get_scene_var("_my_discard_hud_value"),
	]:
		var value_label := value_variant as Label
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0))


func _apply_side_hud_caption_colors() -> void:
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle",
	]:
		var caption := _node(caption_path) as Label
		if caption != null:
			caption.add_theme_color_override("font_color", Color(0.55, 0.89, 0.96, 0.9))


func _apply_side_hud_value_colors() -> void:
	for value_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftValue",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue",
	]:
		var value_label := _node(value_path) as Label
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))


func _apply_side_hud_labels() -> void:
	for label_text: Dictionary in [
		{"path": "MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle", "text": "对方奖赏"},
		{"path": "MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle", "text": ""},
		{"path": "MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue", "text": ""},
		{"path": "MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle", "text": "己方奖赏"},
		{"path": "MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle", "text": ""},
		{"path": "MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue", "text": ""},
	]:
		var label := _node(str(label_text["path"])) as Label
		if label != null:
			label.text = str(label_text["text"])


func _apply_prize_count_fonts() -> void:
	for label_variant: Variant in [_get_scene_var("_opp_prize_hud_count"), _get_scene_var("_my_prize_hud_count")]:
		var label := label_variant as Label
		if label != null:
			label.add_theme_font_size_override("font_size", 18)


func _apply_pile_caption_fonts() -> void:
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudCaption",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudCaption",
	]:
		var caption := _node(caption_path) as Label
		if caption != null:
			caption.add_theme_font_size_override("font_size", 14)


func _apply_opponent_hand_label_style() -> void:
	var label := _get_scene_var("_opp_hand_lbl") as Label
	if label == null:
		return
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.12, 0.9))
	label.add_theme_constant_override("outline_size", 1)


func _apply_log_panel_style() -> void:
	var log_panel := _node("MainArea/LogPanel") as PanelContainer
	if log_panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.018, 0.043, 0.064, 0.94)
		panel_style.border_color = Color(0.30, 0.78, 0.92, 0.86)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(18)
		panel_style.shadow_color = Color(0.04, 0.36, 0.48, 0.28)
		panel_style.shadow_size = 16
		panel_style.shadow_offset = Vector2(0, 3)
		panel_style.content_margin_left = 10
		panel_style.content_margin_right = 10
		panel_style.content_margin_top = 8
		panel_style.content_margin_bottom = 10
		log_panel.add_theme_stylebox_override("panel", panel_style)
	var log_vbox := _node("MainArea/LogPanel/LogPanelVBox") as VBoxContainer
	if log_vbox != null:
		log_vbox.add_theme_constant_override("separation", 8)
	var log_title := _get_scene_var("_log_title") as Label
	if log_title == null:
		log_title = _node("MainArea/LogPanel/LogPanelVBox/LogTitle") as Label
	if log_title != null:
		log_title.add_theme_font_size_override("font_size", 16)
		log_title.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0))
		log_title.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.92))
		log_title.add_theme_constant_override("outline_size", 1)
		log_title.add_theme_color_override("font_shadow_color", Color(0.10, 0.80, 0.98, 0.32))
		log_title.add_theme_constant_override("shadow_offset_y", 1)
		log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var log_list := _get_scene_var("_log_list") as RichTextLabel
	if log_list == null:
		log_list = _node("MainArea/LogPanel/LogPanelVBox/LogList") as RichTextLabel
	if log_list != null:
		log_list.bbcode_enabled = true
		log_list.fit_content = false
		log_list.scroll_following = true
		log_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_list.add_theme_font_size_override("normal_font_size", 15)
		log_list.add_theme_color_override("default_color", Color(0.88, 0.95, 0.98))
		log_list.add_theme_constant_override("line_separation", 4)
		var log_list_bg := StyleBoxFlat.new()
		log_list_bg.bg_color = Color(0.006, 0.018, 0.030, 0.76)
		log_list_bg.border_color = Color(0.23, 0.63, 0.78, 0.38)
		log_list_bg.set_border_width_all(1)
		log_list_bg.set_corner_radius_all(12)
		log_list_bg.content_margin_left = 10
		log_list_bg.content_margin_right = 8
		log_list_bg.content_margin_top = 8
		log_list_bg.content_margin_bottom = 8
		log_list.add_theme_stylebox_override("normal", log_list_bg)
		log_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		HudThemeScript.style_scrollable_control(log_list, "compact")


func _hide_legacy_side_hud_text() -> void:
	for label_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue",
	]:
		var label := _node(label_path) as Label
		if label != null:
			label.visible = false


func _style_bench_panels(bench: HBoxContainer, bg_color: Color, border_color: Color, radius: int) -> void:
	if bench == null:
		return
	for child: Node in bench.get_children():
		_style_panel(child as Control, bg_color, border_color, radius)


func _style_panel(panel: Control, bg_color: Color, border_color: Color, radius: int = 18) -> void:
	_call("_style_panel", [panel, bg_color, border_color, radius])


func _call(method_name: String, args: Array = []) -> Variant:
	if _scene == null or not _scene.has_method(method_name):
		return null
	return _scene.callv(method_name, args)


func _node(path: String) -> Node:
	if _scene == null:
		return null
	return _scene.get_node_or_null(path)


func _get_scene_var(name: String) -> Variant:
	if _scene == null:
		return null
	return _scene.get(name)
