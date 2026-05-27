class_name BattleInvalidActionHintController
extends RefCounted

const OVERLAY_NAME := "InvalidActionOverlay"
const PORTRAIT_BASE_TEXT_SCALE := 1.35
const PORTRAIT_METRIC_GROWTH := 1.30

var _scene: Control = null


func setup(scene: Control) -> void:
	_scene = scene


func show_reason(reason: String, title: String = "当前无法执行") -> void:
	show_hint({
		"title": title,
		"reason": reason,
	})


func show_hint(payload: Variant) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	var data := _normalize_payload(payload)
	if str(data.get("reason", "")).strip_edges() == "":
		return
	_ensure_overlay()
	_apply_payload(data)
	_apply_metrics()
	var overlay := _overlay()
	if overlay != null:
		overlay.visible = true
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.z_index = 620
		overlay.z_as_relative = false
		var parent := overlay.get_parent()
		if parent != null:
			parent.move_child(overlay, parent.get_child_count() - 1)


func hide_hint() -> void:
	var overlay := _overlay()
	if overlay == null:
		return
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _normalize_payload(payload: Variant) -> Dictionary:
	if payload is Dictionary:
		var dict := (payload as Dictionary).duplicate(true)
		if not dict.has("title") or str(dict.get("title", "")).strip_edges() == "":
			dict["title"] = "当前无法执行"
		return dict
	return {
		"title": "当前无法执行",
		"reason": str(payload),
	}


func _ensure_overlay() -> void:
	if _overlay() != null:
		return
	var overlay := Panel.new()
	overlay.name = OVERLAY_NAME
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", _overlay_style())
	_scene.add_child(overlay)

	var center := CenterContainer.new()
	center.name = "InvalidActionCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var box := PanelContainer.new()
	box.name = "InvalidActionBox"
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", _box_style())
	center.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.name = "InvalidActionVBox"
	vbox.add_theme_constant_override("separation", 12)
	box.add_child(vbox)

	var title := _make_label("InvalidActionTitle", 22, Color(1.0, 0.92, 0.68, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var reason := _make_label("InvalidActionReason", 24, Color(1.0, 0.68, 0.30, 1.0))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reason)

	var detail := _make_label("InvalidActionDetail", 18, Color(0.82, 0.94, 1.0, 1.0))
	vbox.add_child(detail)

	var hint := _make_label("InvalidActionHint", 17, Color(0.58, 0.86, 1.0, 1.0))
	vbox.add_child(hint)

	var footer := HBoxContainer.new()
	footer.name = "InvalidActionFooter"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	var close_button := Button.new()
	close_button.name = "InvalidActionCloseButton"
	close_button.text = "知道了"
	close_button.custom_minimum_size = Vector2(220, 58)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(hide_hint)
	footer.add_child(close_button)
	_style_button(close_button)


func _apply_payload(data: Dictionary) -> void:
	_set_label_text("InvalidActionTitle", str(data.get("title", "")))
	_set_label_text("InvalidActionReason", str(data.get("reason", "")))
	_set_label_text("InvalidActionDetail", str(data.get("detail", "")))
	_set_label_text("InvalidActionHint", str(data.get("hint", "")))


func _apply_metrics() -> void:
	var box := _node("InvalidActionCenter/InvalidActionBox") as PanelContainer
	if box == null:
		return
	var portrait := _is_portrait_layout()
	var viewport_size := _hint_viewport_size(portrait)
	var metric_scale := PORTRAIT_METRIC_GROWTH if portrait else 1.0
	var content_margin_x := 24.0 * metric_scale
	var content_margin_y := 20.0 * metric_scale
	if portrait:
		var old_portrait_width := maxf(320.0, viewport_size.x - 36.0)
		var max_portrait_width := maxf(0.0, viewport_size.x - 16.0)
		var box_width := minf(old_portrait_width * metric_scale, max_portrait_width)
		box.custom_minimum_size = Vector2(box_width, 0)
		content_margin_x = minf(content_margin_x, maxf(18.0, box_width * 0.16))
	else:
		box.custom_minimum_size = Vector2(minf(maxf(viewport_size.x * 0.42, 520.0), 720.0), 0)
	box.add_theme_stylebox_override("panel", _box_style(metric_scale, content_margin_x, content_margin_y))
	var vbox := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox") as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", int(round(12.0 * metric_scale)))
	var footer := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionFooter") as HBoxContainer
	if footer != null:
		footer.add_theme_constant_override("separation", int(round(12.0 * metric_scale)))
	var title := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var detail := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionDetail") as Label
	var hint := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionHint") as Label
	var close_button := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionFooter/InvalidActionCloseButton") as Button
	var scale := PORTRAIT_BASE_TEXT_SCALE * metric_scale if portrait else 1.0
	if title != null:
		title.add_theme_font_size_override("font_size", int(round(22.0 * scale)))
	if reason != null:
		reason.add_theme_font_size_override("font_size", int(round(24.0 * scale)))
	if detail != null:
		detail.add_theme_font_size_override("font_size", int(round(18.0 * scale)))
	if hint != null:
		hint.add_theme_font_size_override("font_size", int(round(17.0 * scale)))
	if close_button != null:
		var inner_width := maxf(160.0, box.custom_minimum_size.x - content_margin_x * 2.0)
		close_button.custom_minimum_size = Vector2(
			minf(ceilf(260.0 * metric_scale), inner_width),
			ceilf(78.0 * metric_scale)
		) if portrait else Vector2(220, 58)
		close_button.add_theme_font_size_override("font_size", int(round(24.0 * metric_scale)) if portrait else 18)


func _is_portrait_layout() -> bool:
	if _scene == null:
		return false
	if _scene.has_method("_is_portrait_battle_layout_active"):
		return bool(_scene.call("_is_portrait_battle_layout_active"))
	var value: Variant = _scene.get("_is_portrait_layout")
	if value is bool:
		return bool(value)
	if _scene.has_method("_is_portrait_layout"):
		return bool(_scene.call("_is_portrait_layout"))
	return false


func _hint_viewport_size(portrait: bool) -> Vector2:
	if _scene == null:
		return Vector2(900, 1600) if portrait else Vector2(1280, 720)
	if portrait and _scene.has_method("_portrait_dialog_viewport_size"):
		var portrait_size: Variant = _scene.call("_portrait_dialog_viewport_size")
		if portrait_size is Vector2 and (portrait_size as Vector2).x > 0.0 and (portrait_size as Vector2).y > 0.0:
			return portrait_size
	if _scene.is_inside_tree() and _scene.get_viewport() != null:
		return _scene.get_viewport_rect().size
	if _scene.size.x > 0.0 and _scene.size.y > 0.0:
		return _scene.size
	return Vector2(900, 1600) if portrait else Vector2(1280, 720)


func _set_label_text(node_name: String, text: String) -> void:
	var label := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox/%s" % node_name) as Label
	if label == null:
		return
	label.text = text.strip_edges()
	label.visible = label.text != ""


func _make_label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _style_button(button: Button) -> void:
	if _scene != null and _scene.has_method("_style_hud_button"):
		_scene.call("_style_hud_button", button)
		return
	button.add_theme_stylebox_override("normal", _button_style(Color(0.36, 0.86, 1.0, 1.0), false, false))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.36, 0.86, 1.0, 1.0), true, false))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.36, 0.86, 1.0, 1.0), true, true))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))


func _overlay_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.018, 0.035, 0.54)
	return style


func _box_style(scale: float = 1.0, horizontal_margin: float = -1.0, vertical_margin: float = -1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var margin_x := 24.0 * scale if horizontal_margin < 0.0 else horizontal_margin
	var margin_y := 20.0 * scale if vertical_margin < 0.0 else vertical_margin
	style.bg_color = Color(0.018, 0.038, 0.058, 0.98)
	style.border_color = Color(0.36, 0.86, 1.0, 0.95)
	style.set_border_width_all(maxi(2, int(round(2.0 * scale))))
	style.set_corner_radius_all(int(round(18.0 * scale)))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = int(round(24.0 * scale))
	style.shadow_offset = Vector2(0, 10.0 * scale)
	style.content_margin_left = int(round(margin_x))
	style.content_margin_top = int(round(margin_y))
	style.content_margin_right = int(round(margin_x))
	style.content_margin_bottom = int(round(margin_y))
	return style


func _button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.28) if pressed else Color(0.025, 0.075, 0.105, 0.95)
	if hover and not pressed:
		style.bg_color = Color(0.045, 0.13, 0.17, 0.98)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _overlay() -> Panel:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(OVERLAY_NAME) as Panel


func _node(path: NodePath) -> Node:
	var overlay := _overlay()
	if overlay == null:
		return null
	return overlay.get_node_or_null(path)
