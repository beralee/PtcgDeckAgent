extends RefCounted
## Scoped to the deck workspace; never changes battle or global HUD metrics.
const BG := Color("080f20")
const SURFACE := Color("101e34")
const RAISED := Color("172b46")
const LINE := Color("2a4263")
const LINE_STRONG := Color("3d709b")
const TEXT := Color("edf6ff")
const MUTED := Color("a0b6d0")
const ACCENT := Color("69d8ff")
const BLUE := Color("438fff")
const VIOLET := Color("999bff")
const INK := Color("071a30")
const DANGER := Color("ffa6b4")
const DISCOVERY := Color("10243e")
const DISCOVERY_LINE := Color("39658d")
const POSTER_BG := Color("080f1c")
const SLIDE_TINTS := [Color("204c78"), Color("223b70"), Color("333568"), Color("194c68")]
const Touch := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

static func profile(viewport_size: Vector2, screen_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var portrait := viewport_size.y > viewport_size.x
	var physical := screen_size if screen_size.x > 0 and screen_size.y > 0 else viewport_size
	var pixel_scale := maxf(viewport_size.x / physical.x, viewport_size.y / physical.y)
	var scale := maxf(1.0, pixel_scale)
	if portrait:
		scale = maxf(scale, viewport_size.x / 430.0)
	var compact := not portrait and viewport_size.y / scale < 580.0
	var width := viewport_size.x / scale
	return {"scale": scale, "portrait": portrait, "compact": compact,
		"columns": 1 if portrait else (2 if width < 1100 else 3),
		"sidebar": not portrait and width >= 1050, "margin": (14.0 if portrait or compact else 28.0) * scale,
		"button": 48.0 * scale, "font": roundi(16 * scale), "size": viewport_size}

static func for_control(control: Control, override_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var viewport_size := override_size if override_size.x > 0 else (control.get_viewport_rect().size if control.is_inside_tree() else control.size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = control.size if control.size.x > 0 and control.size.y > 0 else Vector2(1600, 900)
	var screen := Vector2.ZERO
	if override_size == Vector2.ZERO and control.is_inside_tree() and control.get_viewport() is Window and DisplayServer.get_name() != "headless":
		var transform := control.get_viewport().get_screen_transform()
		screen = viewport_size * transform.get_scale()
	return profile(viewport_size, screen)

static func box(fill: Color = SURFACE, border: Color = LINE, radius: int = 12, padding: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func button(node: Button, scale: float = 1.0, primary: bool = false, danger: bool = false) -> void:
	node.custom_minimum_size = Vector2(0, 48 * scale)
	node.add_theme_font_size_override("font_size", roundi(16 * scale))
	node.add_theme_color_override("font_color", INK if primary else (DANGER if danger else TEXT))
	node.add_theme_color_override("font_hover_color", INK if primary else (DANGER if danger else TEXT))
	node.add_theme_color_override("font_pressed_color", INK if primary else (DANGER if danger else TEXT))
	node.add_theme_color_override("font_focus_color", INK if primary else (DANGER if danger else TEXT))
	node.add_theme_color_override("font_disabled_color", MUTED.darkened(0.28))
	var edge := DANGER if danger else ACCENT
	var normal := box(ACCENT if primary else RAISED, ACCENT.lightened(0.18) if primary else (DANGER.darkened(0.5) if danger else LINE_STRONG), roundi(9 * scale), 10 * scale)
	normal.shadow_color = Color(ACCENT if primary else BG, 0.16 if primary else 0.3)
	normal.shadow_size = roundi((6 if primary else 3) * scale)
	normal.shadow_offset = Vector2(0, 2 * scale)
	node.add_theme_stylebox_override("normal", normal)
	var hover := box(ACCENT.lightened(0.15) if primary else RAISED.lerp(BLUE, 0.16), edge, roundi(9 * scale), 10 * scale)
	hover.shadow_color = Color(edge, 0.2)
	hover.shadow_size = roundi(8 * scale)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.16) if primary else RAISED.lerp(BLUE, 0.25), edge, roundi(9 * scale), 10 * scale))
	node.add_theme_stylebox_override("hover_pressed", node.get_theme_stylebox("pressed"))
	node.add_theme_stylebox_override("disabled", box(SURFACE, LINE, roundi(9 * scale), 10 * scale))
	var focus := box(Color.TRANSPARENT, TEXT, roundi(9 * scale), 0)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(3 * scale)
	node.add_theme_stylebox_override("focus", focus)
	Touch.bind_button_touch(node)

static func tonal_button(node: Button, scale: float = 1.0) -> void:
	button(node, scale)
	node.add_theme_color_override("font_color", ACCENT)
	node.add_theme_stylebox_override("normal", box(RAISED.lerp(BLUE, 0.1), LINE_STRONG, roundi(9 * scale), 10 * scale))

static func card_surface(scale: float, selected: bool = false, compact: bool = false) -> StyleBoxFlat:
	var style := box(SURFACE, ACCENT if selected else LINE, roundi(12 * scale), (8 if compact else 12) * scale)
	style.border_width_top = maxi(1, roundi(2 * scale))
	style.shadow_color = Color(BG, 0.4)
	style.shadow_size = roundi(5 * scale)
	style.shadow_offset = Vector2(0, 3 * scale)
	return style

static func popup(node: PopupMenu, scale: float = 1.0) -> void:
	node.add_theme_stylebox_override("panel", box(SURFACE, LINE_STRONG, roundi(10 * scale), 8 * scale))
	node.add_theme_stylebox_override("hover", box(RAISED, ACCENT, roundi(6 * scale), 6 * scale))
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", ACCENT)
	node.add_theme_font_size_override("font_size", roundi(17 * scale))

static func action(text: String, callback: Callable, scale: float = 1.0, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	button(node, scale, primary)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node

static func label(text: String, font_size: float = 16, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", roundi(font_size))
	node.add_theme_color_override("font_color", color)
	return node

static func input(node: LineEdit, scale: float = 1.0, persistent: bool = true) -> void:
	node.custom_minimum_size = Vector2(0, 48 * scale)
	node.add_theme_font_size_override("font_size", roundi(16 * scale))
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_placeholder_color", MUTED)
	node.add_theme_color_override("caret_color", ACCENT)
	node.add_theme_color_override("selection_color", BLUE.darkened(0.35))
	node.add_theme_color_override("font_selected_color", TEXT)
	node.add_theme_stylebox_override("normal", box(BG, LINE, roundi(9 * scale), 10 * scale))
	node.add_theme_stylebox_override("focus", box(BG, ACCENT, roundi(9 * scale), 10 * scale))
	if persistent:
		Touch.configure_persistent_native_line_edit(node)
	else:
		node.remove_meta(Touch.PERSISTENT_TEXT_INPUT_META)
		Touch.configure_native_line_edit(node)
		Touch.bind_line_edit_select_all(node)

static func scroll(node: ScrollContainer, input_profile: String = "auto") -> void:
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	node.follow_focus = true
	# Window shape is not an input capability: a narrow Windows/macOS window
	# still needs a mouse-operated scrollbar. Touch scrolling works in either mode.
	var touch_only := input_profile == "touch" or (input_profile == "auto" and (
		OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
		or OS.has_feature("web_android") or OS.has_feature("web_ios")))
	if touch_only:
		Touch.configure_hidden_vertical_drag_scroll(node)
		node.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	else:
		Touch.configure_visible_vertical_scroll(node)
		# The bridge restores visibility deferred; let AUTO resolve overflow after it.
		node.call_deferred("queue_sort")
	var bar := node.get_v_scroll_bar()
	bar.focus_mode = Control.FOCUS_NONE if touch_only else Control.FOCUS_ALL
	node.focus_mode = Control.FOCUS_ALL
	bar.add_theme_stylebox_override("scroll", box(BG, BG, 3, 3))
	bar.add_theme_stylebox_override("scroll_focus", box(BG, ACCENT, 3, 3))
	bar.add_theme_stylebox_override("grabber", box(LINE_STRONG, LINE_STRONG, 3, 3))
	bar.add_theme_stylebox_override("grabber_highlight", box(ACCENT.darkened(0.25), ACCENT, 3, 3))
	bar.add_theme_stylebox_override("grabber_pressed", box(ACCENT, ACCENT, 3, 3))
	var fit := _fit_scrollbar.bind(node)
	if not node.resized.is_connected(fit):
		node.resized.connect(fit)
	fit.call()
	_fit_scrollbar_if_alive.call_deferred(weakref(node))
	var keyboard := _scroll_key_input.bind(node)
	if not node.gui_input.is_connected(keyboard):
		node.gui_input.connect(keyboard)
	if not bar.gui_input.is_connected(keyboard):
		bar.gui_input.connect(keyboard)

static func _fit_scrollbar_if_alive(reference: WeakRef) -> void:
	var node := reference.get_ref() as ScrollContainer
	if is_instance_valid(node) and not node.is_queued_for_deletion():
		_fit_scrollbar(node)

static func _fit_scrollbar(node: ScrollContainer) -> void:
	var pixel_scale := 1.0
	if node.is_inside_tree():
		var screen_scale := node.get_viewport().get_screen_transform().get_scale()
		pixel_scale = maxf(1.0, 1.0 / maxf(0.01, minf(screen_scale.x, screen_scale.y)))
	var bar := node.get_v_scroll_bar()
	bar.custom_minimum_size.x = 0 if node.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER else 22 * pixel_scale
	bar.add_theme_constant_override("padding_left", roundi(2 * pixel_scale))
	bar.add_theme_constant_override("padding_right", roundi(2 * pixel_scale))
	# ScrollContainer reserves the theme minimum, not custom_minimum_size. Keep
	# both widths aligned so a scaled scrollbar cannot overlap wrapped content.
	for style_name: String in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		var style := bar.get_theme_stylebox(style_name)
		var half_width := 0.0 if node.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER else 11 * pixel_scale
		style.content_margin_left = half_width
		style.content_margin_right = half_width
	# Godot derives thumb length from the StyleBox. Keep at least 48 screen
	# pixels even when the project canvas is scaled down in a narrow window.
	for style_name: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var style := bar.get_theme_stylebox(style_name)
		style.content_margin_top = 24 * pixel_scale
		style.content_margin_bottom = 24 * pixel_scale

static func _scroll_key_input(event: InputEvent, node: ScrollContainer) -> void:
	if not event is InputEventKey or not event.pressed or event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return
	var focused := node.get_viewport().gui_get_focus_owner()
	# Text editing owns navigation keys, including nested import/name fields.
	if focused is LineEdit or focused is TextEdit or focused is SpinBox:
		return
	var bar := node.get_v_scroll_bar()
	var page := maxi(1, roundi(bar.page * 0.9))
	match event.keycode:
		KEY_PAGEDOWN:
			node.scroll_vertical += page
		KEY_PAGEUP:
			node.scroll_vertical -= page
		KEY_HOME:
			node.scroll_vertical = 0
		KEY_END:
			node.scroll_vertical = roundi(bar.max_value - bar.page)
		_:
			return
	node.accept_event()

static func summary(deck: DeckData) -> String:
	var counts := [0, 0, 0]
	for entry: Dictionary in deck.cards:
		var kind := str(entry.get("card_type", ""))
		var category := 0 if kind == "Pokemon" else (2 if kind.contains("Energy") else 1)
		counts[category] += int(entry.get("count", 0))
	return "宝可梦 %d   训练家 %d   能量 %d" % counts

static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
