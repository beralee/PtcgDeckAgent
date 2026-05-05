extends RefCounted

const ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const TEXT := Color(0.92, 0.98, 1.0, 1.0)
const TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)
const SCROLLBAR_COMPACT_THICKNESS := 16
const SCROLLBAR_DESKTOP_THICKNESS := 22
const SCROLLBAR_TOUCH_THICKNESS := 32
const SCROLLBAR_COMPACT_GRAB_MIN := 36
const SCROLLBAR_DESKTOP_GRAB_MIN := 48
const SCROLLBAR_TOUCH_GRAB_MIN := 64
const CARD_SCROLLBAR_CLEARANCE_PADDING := 14


static func apply(root: Node) -> void:
	if root == null:
		return
	var shade := root.get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_apply_recursive(root)


static func _apply_recursive(node: Node) -> void:
	if node is ScrollBar:
		style_scroll_bar(node as ScrollBar)
	elif node is ScrollContainer:
		style_scroll_container(node as ScrollContainer)
	elif node is PanelContainer:
		_style_panel(node as PanelContainer)
	elif node is Button:
		var accent := ACCENT_WARM if node.name in ["BtnStart", "BtnNext", "BtnStartRound", "BtnPrimary"] else ACCENT
		_style_button(node as Button, accent)
	elif node is OptionButton:
		_style_option(node as OptionButton)
	elif node is LineEdit:
		_style_line_edit(node as LineEdit)
	elif node is TextEdit:
		_style_text_edit(node as TextEdit)
	elif node is RichTextLabel:
		_style_rich_text(node as RichTextLabel)
	elif node is Label:
		_style_label(node as Label)

	for child: Node in node.get_children():
		_apply_recursive(child)


static func apply_scrollbars_recursive(root: Node, profile: String = "auto") -> void:
	if root == null:
		return
	_apply_scrollbars_recursive(root, profile)


static func _apply_scrollbars_recursive(node: Node, profile: String) -> void:
	if node is ScrollBar:
		style_scroll_bar(node as ScrollBar, profile)
	elif node is ScrollContainer:
		style_scroll_container(node as ScrollContainer, profile)
	elif node is Control:
		style_scrollable_control(node as Control, profile)
	for child: Node in node.get_children():
		_apply_scrollbars_recursive(child, profile)


static func style_scroll_container(scroll: ScrollContainer, profile: String = "auto") -> void:
	if scroll == null:
		return
	scroll.set_meta("hud_scrollbar_styled", true)
	scroll.set_meta("hud_scrollbar_profile", _resolved_scroll_profile(profile))
	style_scrollable_control(scroll, profile)


static func style_scrollable_control(control: Control, profile: String = "auto") -> void:
	if control == null:
		return
	var vertical_bar := _get_internal_scrollbar(control, "get_v_scroll_bar")
	if vertical_bar != null:
		style_scroll_bar(vertical_bar, profile)
	var horizontal_bar := _get_internal_scrollbar(control, "get_h_scroll_bar")
	if horizontal_bar != null:
		style_scroll_bar(horizontal_bar, profile)


static func style_scroll_bar(bar: ScrollBar, profile: String = "auto") -> void:
	if bar == null:
		return
	var resolved_profile := _resolved_scroll_profile(profile)
	var thickness := _scrollbar_thickness(resolved_profile)
	var minimum_grab := _scrollbar_minimum_grab(resolved_profile)
	var is_vertical := bar is VScrollBar
	bar.set_meta("hud_scrollbar_styled", true)
	bar.set_meta("hud_scrollbar_profile", resolved_profile)
	bar.set_meta("hud_scrollbar_thickness", thickness)
	bar.set_meta("hud_scrollbar_minimum_grab", minimum_grab)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.custom_minimum_size = _scrollbar_minimum_size(bar.custom_minimum_size, thickness, is_vertical)
	bar.add_theme_constant_override("minimum_grab_size", minimum_grab)
	bar.add_theme_stylebox_override("scroll", scrollbar_track_style(is_vertical, false, thickness))
	bar.add_theme_stylebox_override("scroll_focus", scrollbar_track_style(is_vertical, true, thickness))
	bar.add_theme_stylebox_override("grabber", scrollbar_grabber_style(false, false, thickness))
	bar.add_theme_stylebox_override("grabber_highlight", scrollbar_grabber_style(true, false, thickness))
	bar.add_theme_stylebox_override("grabber_pressed", scrollbar_grabber_style(true, true, thickness))
	for icon_name: String in [
		"increment",
		"increment_highlight",
		"increment_pressed",
		"decrement",
		"decrement_highlight",
		"decrement_pressed",
	]:
		bar.add_theme_icon_override(icon_name, empty_scrollbar_icon())


static func _get_internal_scrollbar(control: Control, method_name: String) -> ScrollBar:
	if not control.has_method(method_name):
		return null
	var value: Variant = control.call(method_name)
	if value is ScrollBar:
		return value as ScrollBar
	return null


static func _resolved_scroll_profile(profile: String) -> String:
	var normalized := profile.strip_edges().to_lower()
	if normalized == "" or normalized == "auto":
		return "touch" if _is_touch_runtime() else "default"
	if normalized in ["compact", "default", "touch"]:
		return normalized
	return "default"


static func _is_touch_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func _scrollbar_thickness(profile: String) -> int:
	match profile:
		"compact":
			return SCROLLBAR_COMPACT_THICKNESS
		"touch":
			return SCROLLBAR_TOUCH_THICKNESS
		_:
			return SCROLLBAR_DESKTOP_THICKNESS


static func _scrollbar_minimum_grab(profile: String) -> int:
	match profile:
		"compact":
			return SCROLLBAR_COMPACT_GRAB_MIN
		"touch":
			return SCROLLBAR_TOUCH_GRAB_MIN
		_:
			return SCROLLBAR_DESKTOP_GRAB_MIN


static func _scrollbar_minimum_size(current: Vector2, thickness: int, vertical: bool) -> Vector2:
	var result := current
	if vertical:
		result.x = maxf(result.x, float(thickness))
	else:
		result.y = maxf(result.y, float(thickness))
	return result


static func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(
		Color(0.025, 0.055, 0.085, 0.76),
		Color(0.30, 0.86, 1.0, 0.86),
		24
	))


static func _style_label(label: Label) -> void:
	if label.name in ["TitleLabel", "Title"]:
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", TEXT)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
		label.add_theme_constant_override("shadow_offset_y", 2)
		return
	if label.name.ends_with("Title") or label.name.ends_with("Label") and label.name in ["MetaTitle", "DistributionTitle", "RosterTitle", "StandingsLabel"]:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		return
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_MUTED)


static func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_color_override("font_color", TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_stylebox_override("normal", input_style(false))
	option.add_theme_stylebox_override("hover", input_style(true))
	option.add_theme_stylebox_override("pressed", input_style(true))
	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _style_line_edit(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", ACCENT)
	input.add_theme_stylebox_override("normal", input_style(false))
	input.add_theme_stylebox_override("focus", input_style(true))


static func _style_text_edit(input: TextEdit) -> void:
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("caret_color", ACCENT)
	input.add_theme_stylebox_override("normal", input_style(false))
	input.add_theme_stylebox_override("focus", input_style(true))
	style_scrollable_control(input)


static func _style_rich_text(label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", TEXT_MUTED)
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_stylebox_override("normal", input_style(false))
	style_scrollable_control(label)


static func panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 10
	style.set_content_margin_all(10)
	return style


static func button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92) if pressed else Color(0.035, 0.075, 0.105, 0.92)
	if hover and not pressed:
		style.bg_color = Color(0.055, 0.13, 0.17, 0.96)
	style.border_color = accent
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.12)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func input_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.055, 0.88)
	if hover:
		style.bg_color = Color(0.025, 0.075, 0.105, 0.94)
	style.border_color = Color(0.23, 0.78, 1.0, 0.70 if hover else 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func scrollbar_track_style(vertical: bool, focused: bool, thickness: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.026, 0.038, 0.48)
	style.border_color = Color(0.34, 0.62, 0.72, 0.42 if focused else 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(8, thickness / 2))
	style.shadow_color = Color(0.16, 0.46, 0.58, 0.08 if focused else 0.03)
	style.shadow_size = 6 if focused else 2
	var channel_margin := maxi(4, thickness / 5)
	if vertical:
		style.content_margin_left = channel_margin
		style.content_margin_right = channel_margin
		style.content_margin_top = 4
		style.content_margin_bottom = 4
	else:
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = channel_margin
		style.content_margin_bottom = channel_margin
	return style


static func scrollbar_grabber_style(hover: bool, pressed: bool, thickness: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var accent := Color(0.86, 0.62, 0.36, 1.0) if pressed else Color(0.46, 0.72, 0.80, 1.0)
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.76 if pressed else (0.66 if hover else 0.52))
	style.border_color = Color(0.78, 0.92, 0.96, 0.66 if hover or pressed else 0.46)
	style.set_border_width_all(2 if hover or pressed else 1)
	style.set_corner_radius_all(maxi(8, thickness / 2))
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.14 if hover or pressed else 0.07)
	style.shadow_size = 6 if hover or pressed else 3
	style.set_content_margin_all(4)
	return style


static func empty_scrollbar_icon() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)
