class_name BattleCardDetailCoordinator
extends RefCounted

const BATTLE_CARD_VIEW := preload("res://scenes/battle/BattleCardView.gd")
const DETAIL_OVERLAY_Z_INDEX := 500

var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func setup_detail_preview(detail_card_size: Vector2) -> void:
	var detail_box := _node("DetailOverlay/DetailCenter/DetailBox") as PanelContainer
	if detail_box == null:
		return
	detail_box.custom_minimum_size = Vector2(760, 560)

	var detail_vbox := _node("DetailOverlay/DetailCenter/DetailBox/DetailVBox") as VBoxContainer
	if detail_vbox == null:
		return
	detail_vbox.add_theme_constant_override("separation", 12)

	var detail_header := detail_vbox.get_node_or_null("DetailHeader") as HBoxContainer
	if detail_header == null:
		detail_header = HBoxContainer.new()
		detail_header.name = "DetailHeader"
		detail_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_header.add_theme_constant_override("separation", 10)
		detail_vbox.add_child(detail_header)
		detail_vbox.move_child(detail_header, 0)
	_inherit_owner(detail_header, detail_vbox)

	var detail_title := _get_scene_var("_detail_title") as Label
	if detail_title != null:
		_reparent_detail_child(detail_title, detail_header)
		detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_close_btn := _get_scene_var("_detail_close_btn") as Button
	if detail_close_btn != null:
		_reparent_detail_child(detail_close_btn, detail_header)
		detail_close_btn.text = "X"
		detail_close_btn.tooltip_text = "Close"
		detail_close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		detail_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		_connect_detail_close_button(detail_close_btn)

	var detail_body := detail_vbox.get_node_or_null("DetailBody") as HBoxContainer
	if detail_body == null:
		detail_body = HBoxContainer.new()
		detail_body.name = "DetailBody"
		detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		detail_body.add_theme_constant_override("separation", 18)
		detail_vbox.add_child(detail_body)
	else:
		detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inherit_owner(detail_body, detail_vbox)

	var detail_card_view := _get_scene_var("_detail_card_view") as BattleCardView
	if detail_card_view == null:
		detail_card_view = BATTLE_CARD_VIEW.new()
		detail_card_view.name = "DetailCardPreview"
		detail_card_view.set_clickable(false)
		detail_card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
		_set_scene_var("_detail_card_view", detail_card_view)
	if detail_card_view.get_parent() != detail_body:
		_reparent_detail_child(detail_card_view, detail_body, 0)
	detail_card_view.custom_minimum_size = detail_card_size
	detail_card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var detail_text_panel := detail_body.get_node_or_null("DetailTextPanel") as PanelContainer
	if detail_text_panel == null:
		detail_text_panel = PanelContainer.new()
		detail_text_panel.name = "DetailTextPanel"
		detail_text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_text_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		detail_body.add_child(detail_text_panel)
	else:
		detail_text_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inherit_owner(detail_text_panel, detail_body)

	var detail_text_margin := detail_text_panel.get_node_or_null("DetailTextMargin") as MarginContainer
	if detail_text_margin == null:
		detail_text_margin = MarginContainer.new()
		detail_text_margin.name = "DetailTextMargin"
		detail_text_margin.add_theme_constant_override("margin_left", 14)
		detail_text_margin.add_theme_constant_override("margin_top", 12)
		detail_text_margin.add_theme_constant_override("margin_right", 14)
		detail_text_margin.add_theme_constant_override("margin_bottom", 12)
		detail_text_panel.add_child(detail_text_margin)
	_inherit_owner(detail_text_margin, detail_text_panel)

	var detail_content := _get_scene_var("_detail_content") as RichTextLabel
	if detail_content != null:
		_reparent_detail_child(detail_content, detail_text_margin)
		detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var detail_action_bar := detail_vbox.get_node_or_null("DetailActionBar") as HBoxContainer
	if detail_action_bar == null:
		detail_action_bar = HBoxContainer.new()
		detail_action_bar.name = "DetailActionBar"
		detail_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_action_bar.size_flags_vertical = Control.SIZE_SHRINK_END
		detail_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		detail_action_bar.add_theme_constant_override("separation", 14)
		detail_vbox.add_child(detail_action_bar)
	_inherit_owner(detail_action_bar, detail_vbox)
	_set_scene_var("_detail_action_bar", detail_action_bar)

	var detail_cancel_btn := detail_action_bar.get_node_or_null("DetailCancelButton") as Button
	if detail_cancel_btn == null:
		detail_cancel_btn = Button.new()
		detail_cancel_btn.name = "DetailCancelButton"
		detail_cancel_btn.text = "取消"
		detail_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_action_bar.add_child(detail_cancel_btn)
	_set_scene_var("_detail_cancel_btn", detail_cancel_btn)
	var cancel_callable := Callable(_scene, "_on_detail_cancel_pressed")
	if not detail_cancel_btn.pressed.is_connected(cancel_callable):
		detail_cancel_btn.pressed.connect(cancel_callable)

	var detail_use_btn := detail_action_bar.get_node_or_null("DetailUseButton") as Button
	if detail_use_btn == null:
		detail_use_btn = Button.new()
		detail_use_btn.name = "DetailUseButton"
		detail_use_btn.text = "使用"
		detail_use_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_action_bar.add_child(detail_use_btn)
	_set_scene_var("_detail_use_btn", detail_use_btn)
	var use_callable := Callable(_scene, "_on_detail_use_pressed")
	if not detail_use_btn.pressed.is_connected(use_callable):
		detail_use_btn.pressed.connect(use_callable)

	style_detail_action_buttons()
	set_detail_action_mode("readonly", null)


func style_card_detail_overlay() -> void:
	var detail_overlay := _get_scene_var("_detail_overlay") as Panel
	if detail_overlay != null:
		detail_overlay.self_modulate = Color(1, 1, 1, 1)
		var overlay_style := StyleBoxFlat.new()
		overlay_style.bg_color = Color(0.0, 0.02, 0.04, 0.74)
		detail_overlay.add_theme_stylebox_override("panel", overlay_style)

	var detail_box := _node("DetailOverlay/DetailCenter/DetailBox") as PanelContainer
	if detail_box != null:
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = Color(0.018, 0.038, 0.058, 0.98)
		box_style.border_color = Color(0.94, 0.74, 0.34, 0.95)
		box_style.set_border_width_all(2)
		box_style.set_corner_radius_all(18)
		box_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		box_style.shadow_size = 28
		box_style.shadow_offset = Vector2(0, 12)
		box_style.content_margin_left = 18
		box_style.content_margin_top = 14
		box_style.content_margin_right = 18
		box_style.content_margin_bottom = 16
		detail_box.add_theme_stylebox_override("panel", box_style)

	var detail_title := _get_scene_var("_detail_title") as Label
	if detail_title != null:
		detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail_title.add_theme_font_size_override("font_size", 20)
		detail_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
		detail_title.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.07, 0.95))
		detail_title.add_theme_constant_override("outline_size", 2)
		var title_font := FontVariation.new()
		title_font.base_font = ThemeDB.fallback_font
		title_font.variation_embolden = 1.25
		detail_title.add_theme_font_override("font", title_font)

	var detail_content := _get_scene_var("_detail_content") as RichTextLabel
	if detail_content != null:
		detail_content.bbcode_enabled = true
		detail_content.scroll_active = true
		detail_content.selection_enabled = true
		detail_content.add_theme_font_size_override("normal_font_size", 14)
		detail_content.add_theme_color_override("default_color", Color(0.86, 0.94, 0.98))
		detail_content.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.4))
		detail_content.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		detail_content.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var detail_text_panel := _node("DetailOverlay/DetailCenter/DetailBox/DetailVBox/DetailBody/DetailTextPanel") as PanelContainer
	if detail_text_panel != null:
		var text_panel_style := StyleBoxFlat.new()
		text_panel_style.bg_color = Color(0.03, 0.07, 0.09, 0.78)
		text_panel_style.border_color = Color(0.19, 0.56, 0.68, 0.58)
		text_panel_style.set_border_width_all(1)
		text_panel_style.set_corner_radius_all(12)
		text_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
		text_panel_style.shadow_size = 10
		text_panel_style.shadow_offset = Vector2(0, 4)
		detail_text_panel.add_theme_stylebox_override("panel", text_panel_style)

	var detail_close_btn := _get_scene_var("_detail_close_btn") as Button
	if detail_close_btn != null:
		_call("_style_hud_button", [detail_close_btn])
		detail_close_btn.custom_minimum_size = Vector2(42, 32)
		detail_close_btn.add_theme_font_size_override("font_size", 14)
	style_detail_action_buttons()


func style_detail_action_buttons() -> void:
	var detail_action_bar := _get_scene_var("_detail_action_bar") as HBoxContainer
	if detail_action_bar != null:
		detail_action_bar.add_theme_constant_override("separation", 14)
	for button: Button in [_get_scene_var("_detail_cancel_btn") as Button, _get_scene_var("_detail_use_btn") as Button]:
		if button == null:
			continue
		_call("_style_hud_button", [button])
		button.custom_minimum_size = Vector2(220, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 18)
	var detail_use_btn := _get_scene_var("_detail_use_btn") as Button
	if detail_use_btn == null:
		return
	var normal := detail_use_btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	var hover := detail_use_btn.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
	var pressed := detail_use_btn.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	if normal != null:
		normal.bg_color = Color(0.22, 0.11, 0.02, 0.78)
		normal.border_color = Color(1.0, 0.55, 0.10, 0.96)
		detail_use_btn.add_theme_stylebox_override("normal", normal)
	if hover != null:
		hover.bg_color = Color(0.34, 0.16, 0.03, 0.88)
		hover.border_color = Color(1.0, 0.72, 0.25, 1.0)
		detail_use_btn.add_theme_stylebox_override("hover", hover)
	if pressed != null:
		pressed.bg_color = Color(0.42, 0.18, 0.02, 0.95)
		pressed.border_color = Color(1.0, 0.82, 0.38, 1.0)
		detail_use_btn.add_theme_stylebox_override("pressed", pressed)


func card_type_cn(cd: CardData) -> String:
	var emap := _energy_name_map()
	match cd.card_type:
		"Pokemon":
			return "%s宝可梦 / HP%d" % [cd.stage, cd.hp]
		"Item":
			return "物品"
		"Supporter":
			return "支援者"
		"Tool":
			return "宝可梦道具"
		"Stadium":
			return "竞技场"
		"Basic Energy":
			return "基本能量 / %s" % emap.get(cd.energy_provides, "")
		"Special Energy":
			return "特殊能量"
		_:
			return cd.card_type


func show_hand_card_detail(inst: CardInstance) -> void:
	if inst == null or inst.card_data == null:
		return
	if bool(_call("_is_hand_drag_click_suppressed")):
		return
	if should_hand_card_click_select_directly(inst):
		_call("_on_hand_card_clicked", [inst, null])
		return
	var can_use := can_show_hand_detail_action(inst)
	show_card_detail(inst.card_data)
	if can_use:
		set_detail_action_mode("hand_action", inst)
		var detail_use_btn := _get_scene_var("_detail_use_btn") as Button
		if detail_use_btn != null:
			detail_use_btn.text = detail_use_label_for_current_context()
	else:
		set_detail_action_mode("readonly", null)


func should_hand_card_click_select_directly(inst: CardInstance) -> bool:
	if inst == null or inst.card_data == null:
		return false
	var cd: CardData = inst.card_data
	return cd.is_pokemon() or cd.card_type == "Basic Energy" or cd.card_type == "Special Energy"


func can_show_hand_detail_action(inst: CardInstance) -> bool:
	if inst == null or inst.card_data == null:
		return false
	if not bool(_call("_can_accept_live_action")):
		return false
	var gsm = _get_scene_var("_gsm")
	if gsm == null or gsm.game_state == null:
		return false
	var gs: GameState = gsm.game_state
	if gs.phase != GameState.GamePhase.MAIN:
		return false
	if gs.current_player_index != int(_get_scene_var("_view_player")):
		return false
	if str(_get_scene_var("_pending_choice")) != "":
		return false
	if bool(_call("_is_field_interaction_active")):
		return false
	var handover_panel := _get_scene_var("_handover_panel") as Control
	if handover_panel != null and handover_panel.visible:
		return false
	if bool(_get_scene_var("_draw_reveal_active")) or bool(_get_scene_var("_ai_llm_waiting")) or bool(_call("_is_ai_action_pause_active")):
		return false
	return hand_contains_card(gs.current_player_index, inst)


func hand_contains_card(player_index: int, inst: CardInstance) -> bool:
	var gsm = _get_scene_var("_gsm")
	if gsm == null or gsm.game_state == null:
		return false
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return false
	return gsm.game_state.players[player_index].hand.has(inst)


func detail_use_label_for_current_context() -> String:
	var pending_choice := str(_get_scene_var("_pending_choice"))
	if pending_choice.begins_with("setup_active_") or pending_choice.begins_with("setup_bench_"):
		return "选择"
	return "使用"


func set_detail_action_mode(mode: String, inst: CardInstance) -> void:
	_set_scene_var("_detail_mode", mode)
	_set_scene_var("_detail_hand_action_card", inst if mode == "hand_action" else null)
	var show_actions := mode == "hand_action" and inst != null
	var detail_action_bar := _get_scene_var("_detail_action_bar") as Control
	var detail_use_btn := _get_scene_var("_detail_use_btn") as Button
	var detail_cancel_btn := _get_scene_var("_detail_cancel_btn") as Button
	if detail_action_bar != null:
		detail_action_bar.visible = show_actions
	if detail_use_btn != null:
		detail_use_btn.visible = show_actions
		detail_use_btn.disabled = not show_actions
	if detail_cancel_btn != null:
		detail_cancel_btn.visible = show_actions
		detail_cancel_btn.disabled = not show_actions


func on_detail_use_pressed() -> void:
	var inst := _get_scene_var("_detail_hand_action_card") as CardInstance
	hide_card_detail()
	if inst == null:
		return
	if not can_show_hand_detail_action(inst):
		if inst.card_data != null:
			show_card_detail(inst.card_data)
		return
	_call("_on_hand_card_clicked", [inst, null])


func on_detail_cancel_pressed() -> void:
	hide_card_detail()


func show_card_detail(cd: CardData) -> void:
	if cd == null:
		return
	raise_card_detail_overlay()
	set_detail_action_mode("readonly", null)
	var detail_title := _get_scene_var("_detail_title") as Label
	if detail_title != null:
		detail_title.text = cd.name
	var detail_card_view := _get_scene_var("_detail_card_view") as BattleCardView
	if detail_card_view != null:
		detail_card_view.setup_from_card_data(cd, BATTLE_CARD_VIEW.MODE_PREVIEW)
		detail_card_view.set_badges("", "")
		detail_card_view.set_info("", "")
	var lines := detail_lines(cd)
	var detail_content := _get_scene_var("_detail_content") as RichTextLabel
	if detail_content != null:
		detail_content.text = "[color=#dceff8]%s[/color]" % "\n".join(lines)
	_call("_apply_portrait_popup_text_metrics")
	var detail_overlay := _get_scene_var("_detail_overlay") as Control
	if detail_overlay != null:
		detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		detail_overlay.visible = true
	play_card_detail_open_animation()


func detail_lines(cd: CardData) -> Array[String]:
	var emap := _energy_name_map()
	var lines: Array[String] = []
	if cd.is_pokemon():
		lines.append("[b]%s[/b]  %s宝可梦" % [cd.name, cd.stage])
		if cd.mechanic != "":
			lines.append("机制：%s" % cd.mechanic)
		lines.append("属性：%s  HP：%d" % [emap.get(cd.energy_type, cd.energy_type), cd.hp])
		var weak := "无"
		if cd.weakness_energy != "":
			weak = "%s %s" % [emap.get(cd.weakness_energy, cd.weakness_energy), cd.weakness_value]
		var resist := "无"
		if cd.resistance_energy != "":
			resist = "%s %s" % [emap.get(cd.resistance_energy, cd.resistance_energy), cd.resistance_value]
		lines.append("弱点：%s  抵抗：%s" % [weak, resist])
		lines.append("撤退：%d" % cd.retreat_cost)
		if cd.evolves_from != "":
			lines.append("由 %s 进化" % cd.evolves_from)
		for ab: Dictionary in cd.abilities:
			lines.append("")
			lines.append("[b]特性：%s[/b]" % ab.get("name", ""))
			var ab_text: String = ab.get("text", "")
			if ab_text != "":
				lines.append(ab_text)
		for atk: Dictionary in cd.attacks:
			lines.append("")
			var cost_str: String = atk.get("cost", "")
			var cost_display := ""
			for c: String in cost_str:
				cost_display += emap.get(c, c)
			var dmg: String = atk.get("damage", "")
			lines.append("[b]招式：%s[/b]  [%s]  %s" % [atk.get("name", ""), cost_display, dmg])
			var atk_text: String = atk.get("text", "")
			if atk_text != "":
				lines.append(atk_text)
	else:
		lines.append("[b]%s[/b]  %s" % [cd.name, card_type_cn(cd)])
		if cd.description != "":
			lines.append("")
			lines.append(cd.description)
	return lines


func raise_card_detail_overlay() -> void:
	var detail_overlay := _get_scene_var("_detail_overlay") as Control
	if detail_overlay == null:
		return
	detail_overlay.z_index = DETAIL_OVERLAY_Z_INDEX
	detail_overlay.z_as_relative = false
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var parent := detail_overlay.get_parent()
	if parent != null:
		parent.move_child(detail_overlay, parent.get_child_count() - 1)


func hide_card_detail() -> void:
	var detail_overlay := _get_scene_var("_detail_overlay") as Control
	if detail_overlay == null or not detail_overlay.visible:
		set_detail_action_mode("readonly", null)
		return
	set_detail_action_mode("readonly", null)
	var detail_box := _node("DetailOverlay/DetailCenter/DetailBox") as Control
	var detail_reveal_tween := _get_scene_var("_detail_reveal_tween") as Tween
	if detail_reveal_tween != null:
		detail_reveal_tween.kill()
		_set_scene_var("_detail_reveal_tween", null)
	detail_overlay.visible = false
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if detail_box != null:
		detail_box.modulate = Color(1, 1, 1, 1)
		detail_box.scale = Vector2.ONE
		detail_box.pivot_offset = detail_box.size * 0.5


func play_card_detail_open_animation() -> void:
	var detail_box := _node("DetailOverlay/DetailCenter/DetailBox") as Control
	if detail_box == null or _scene == null or not _scene.is_inside_tree():
		return
	var detail_reveal_tween := _get_scene_var("_detail_reveal_tween") as Tween
	if detail_reveal_tween != null:
		detail_reveal_tween.kill()
		_set_scene_var("_detail_reveal_tween", null)
	detail_box.pivot_offset = detail_box.size * 0.5
	detail_box.modulate = Color(1, 1, 1, 0)
	detail_box.scale = Vector2(0.94, 0.94)
	var tween := _scene.create_tween()
	_set_scene_var("_detail_reveal_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(detail_box, "modulate", Color(1, 1, 1, 1), 0.14)
	tween.tween_property(detail_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _energy_name_map() -> Dictionary:
	return {
		"R": "火",
		"W": "水",
		"G": "草",
		"L": "雷",
		"P": "超",
		"F": "斗",
		"D": "恶",
		"M": "钢",
		"N": "龙",
		"C": "无",
	}


func _inherit_owner(node: Node, parent: Node) -> void:
	if node == null or parent == null or parent.owner == null:
		return
	node.owner = parent.owner


func _reparent_detail_child(child: Node, parent: Node, insert_index: int = -1) -> void:
	if child == null or parent == null:
		return
	if child.get_parent() != parent:
		var old_parent := child.get_parent()
		if old_parent != null:
			old_parent.remove_child(child)
		child.owner = null
		parent.add_child(child)
	if insert_index >= 0:
		parent.move_child(child, clampi(insert_index, 0, maxi(parent.get_child_count() - 1, 0)))
	_inherit_owner(child, parent)


func _get_scene_var(property_name: StringName) -> Variant:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get(property_name)


func _set_scene_var(property_name: StringName, value: Variant) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_scene.set(property_name, value)


func _call(method_name: StringName, args: Array = []) -> Variant:
	if _scene == null or not is_instance_valid(_scene) or not _scene.has_method(method_name):
		return null
	return _scene.callv(method_name, args)


func _connect_detail_close_button(button: Button) -> void:
	if button == null or _scene == null or not is_instance_valid(_scene) or not _scene.has_method("_hide_card_detail"):
		return
	var close_callable := Callable(_scene, "_hide_card_detail")
	if not button.pressed.is_connected(close_callable):
		button.pressed.connect(close_callable)
	if not button.button_down.is_connected(close_callable):
		button.button_down.connect(close_callable)


func _node(path: NodePath) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(path)
