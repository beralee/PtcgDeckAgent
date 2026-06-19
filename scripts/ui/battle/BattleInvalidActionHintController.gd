class_name BattleInvalidActionHintController
extends RefCounted

const OVERLAY_NAME := "InvalidActionOverlay"
const PORTRAIT_BASE_TEXT_SCALE := 1.35
const PORTRAIT_METRIC_GROWTH := 1.30
const PORTRAIT_EDGE_MARGIN := 8.0
const PORTRAIT_HAND_GAP := 8.0
const PORTRAIT_MIN_USABLE_HEIGHT := 260.0
const LANDSCAPE_MAX_BOX_HEIGHT := 260.0

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
	if _scene.has_method("_sync_portrait_modal_overlay_rects"):
		_scene.call("_sync_portrait_modal_overlay_rects")
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

	var center := Control.new()
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
	var box_width := 0.0
	if portrait:
		var old_portrait_width := maxf(320.0, viewport_size.x - 36.0)
		var max_portrait_width := maxf(0.0, viewport_size.x - 16.0)
		box_width = minf(old_portrait_width * metric_scale, max_portrait_width)
		box.custom_minimum_size = Vector2(box_width, 0)
		content_margin_x = minf(content_margin_x, maxf(18.0, box_width * 0.16))
	else:
		box_width = minf(maxf(viewport_size.x * 0.42, 520.0), 720.0)
		box.custom_minimum_size = Vector2(box_width, 0)
	box.add_theme_stylebox_override("panel", _box_style(metric_scale, content_margin_x, content_margin_y))
	var vbox := _node("InvalidActionCenter/InvalidActionBox/InvalidActionVBox") as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", int(round(12.0 * metric_scale)))
		vbox.clip_contents = not portrait
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
	_apply_label_bounds(portrait, maxf(1.0, box_width - content_margin_x * 2.0), title, reason, detail, hint)
	_apply_box_rect(box, portrait, viewport_size)


func _apply_label_bounds(
	portrait: bool,
	inner_width: float,
	title: Label,
	reason: Label,
	detail: Label,
	hint: Label
) -> void:
	if not portrait:
		_configure_label_bounds(title, inner_width, 1, true)
		_configure_label_bounds(reason, inner_width, 1, true)
		_configure_label_bounds(detail, inner_width, 1, true)
		_configure_label_bounds(hint, inner_width, 1, true)
		return
	_configure_label_bounds(title, inner_width, 1, true)
	_configure_label_bounds(reason, inner_width, 2, true)
	_configure_label_bounds(detail, inner_width, 1, true)
	_configure_label_bounds(hint, inner_width, 1, true)


func _configure_label_bounds(label: Label, inner_width: float, max_lines: int, clipped: bool) -> void:
	if label == null:
		return
	label.custom_minimum_size.x = inner_width
	label.size.x = inner_width
	label.clip_text = clipped
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if clipped else TextServer.OVERRUN_NO_TRIMMING
	label.max_lines_visible = max_lines
	if clipped and label.visible and label.text.strip_edges() != "":
		var line_count := maxi(max_lines, 1)
		var font_size := label.get_theme_font_size("font_size")
		label.custom_minimum_size.y = ceilf(float(font_size) * 1.28 * float(line_count))
		label.size.y = label.custom_minimum_size.y
	else:
		label.custom_minimum_size.y = 0.0


func _apply_box_rect(box: PanelContainer, portrait: bool, viewport_size: Vector2) -> void:
	if box == null:
		return
	var overlay := _overlay()
	var center := _node("InvalidActionCenter") as Control
	if overlay != null and overlay.size == Vector2.ZERO:
		overlay.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		overlay.position = Vector2.ZERO
		overlay.size = viewport_size
	if center != null:
		center.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		center.position = Vector2.ZERO
		center.size = overlay.size if overlay != null and overlay.size != Vector2.ZERO else viewport_size
	var content_rect := Rect2(Vector2.ZERO, viewport_size)
	if overlay != null and overlay.size.x > 0.0 and overlay.size.y > 0.0:
		content_rect = Rect2(Vector2.ZERO, overlay.size)
	var available_rect := _available_hint_rect(content_rect, portrait)
	var natural_size := box.get_combined_minimum_size()
	var box_width := minf(maxf(box.custom_minimum_size.x, natural_size.x), available_rect.size.x)
	var min_height := 180.0 if portrait else 140.0
	var max_height := available_rect.size.y
	if not portrait:
		max_height = minf(max_height, LANDSCAPE_MAX_BOX_HEIGHT)
	var box_height := minf(maxf(natural_size.y, min_height), max_height)
	box.clip_contents = not portrait
	box.custom_minimum_size = Vector2(box_width, box_height)
	box.size = Vector2(box_width, box_height)
	box.position = Vector2(
		roundf(available_rect.position.x + maxf((available_rect.size.x - box_width) * 0.5, 0.0)),
		roundf(available_rect.position.y + maxf((available_rect.size.y - box_height) * 0.5, 0.0))
	)


func _available_hint_rect(content_rect: Rect2, portrait: bool) -> Rect2:
	var margin := PORTRAIT_EDGE_MARGIN if portrait else 24.0
	var left := content_rect.position.x + margin
	var top := content_rect.position.y + margin
	var right := content_rect.position.x + maxf(content_rect.size.x - margin, margin)
	var bottom := content_rect.position.y + maxf(content_rect.size.y - margin, margin)
	if portrait:
		var hand_top := _portrait_hand_top(content_rect)
		if hand_top > top + PORTRAIT_MIN_USABLE_HEIGHT:
			bottom = minf(bottom, hand_top - PORTRAIT_HAND_GAP)
	if bottom <= top:
		bottom = top + maxf(content_rect.size.y - margin * 2.0, 1.0)
	var width := maxf(right - left, 1.0)
	var height := maxf(bottom - top, 1.0)
	return Rect2(Vector2(left, top), Vector2(width, height))


func _portrait_hand_top(content_rect: Rect2) -> float:
	if _scene == null or not is_instance_valid(_scene):
		return content_rect.position.y + content_rect.size.y
	var hand_area := _scene.find_child("HandArea", true, false) as Control
	if hand_area == null:
		return content_rect.position.y + content_rect.size.y
	var content_bottom := content_rect.position.y + content_rect.size.y
	var resolved_top := -1.0
	var hand_height := maxf(hand_area.size.y, hand_area.custom_minimum_size.y)
	if hand_height > 0.0 and hand_height < content_rect.size.y:
		resolved_top = content_bottom - hand_height
	if _scene.has_method("_control_rect_in_battle_local"):
		var rect_variant: Variant = _scene.call("_control_rect_in_battle_local", hand_area)
		if rect_variant is Rect2 and (rect_variant as Rect2).position.y > 0.0:
			resolved_top = maxf(resolved_top, (rect_variant as Rect2).position.y)
	if hand_area.position.y > 0.0:
		resolved_top = maxf(resolved_top, hand_area.position.y)
	if resolved_top > 0.0:
		return minf(resolved_top, content_bottom)
	return content_bottom


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
