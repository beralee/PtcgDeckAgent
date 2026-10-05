extends RefCounted
## All rectangles below use one logical content space. The modal converts the
## physical keyboard height once; only the transcript scrolls, never the composer.
const Palette := preload("res://scripts/ui/decks/DeckCenterTheme.gd")

static func apply(dialog: Control) -> void:
	var viewport_size := dialog.get_viewport_rect().size
	var unit: float = display_unit(dialog)
	var screen_scale := window_scale(dialog)
	var inset := maxf(0, dialog.get("_keyboard_height")) / maxf(0.01, screen_scale)
	var available := Vector2(viewport_size.x, maxf(1, viewport_size.y - inset))
	var portrait := viewport_size.y > viewport_size.x
	dialog.set("_layout_profile", "portrait_touch" if portrait else "desktop")
	dialog.set("_portrait_touch_scale", 1.0)
	dialog.set("content_zoom", unit)
	dialog.set("content_min_height", 0.0)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := 12.0 * unit
	var target := Vector2(minf(980 * unit, available.x - margin * 2), minf(760 * unit, available.y - margin * 2)).max(Vector2.ONE)
	var panel := dialog.get_panel() as PanelContainer
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE, Palette.LINE_STRONG, roundi(14 * unit), 12 * unit))
	dialog.get("_header").hide()
	dialog.get_footer().hide()
	dialog.get("_message").hide()
	dialog.get_column().add_theme_constant_override("separation", 0)
	var scroll := dialog.get_scroll() as ScrollContainer
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.get("_surface").custom_minimum_size = Vector2.ZERO
	var content := dialog.get_content() as Control
	content.scale = Vector2.ONE * unit
	content.size = (target / unit - Vector2(24, 24)).max(Vector2.ONE)
	panel.size = target
	panel.position = (available - target) * 0.5
	var root := content.get_node("Root") as Control
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var width := content.size.x
	var height := content.size.y
	var compact := height < 440
	var narrow := width < 580
	var title := dialog.get_node("%TitleLabel") as Label
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 20)
	place(title, Rect2(0, 0, maxf(1, width - 52), 44))
	var close := dialog.get_node("%CloseButton") as Button
	close.custom_minimum_size = Vector2(44, 44)
	close.text = "×"
	close.tooltip_text = "关闭对话"
	close.add_theme_font_size_override("font_size", 26)
	place(close, Rect2(width - 44, 0, 44, 44))
	var header := dialog.get_node("%HeaderPanel") as PanelContainer
	header.visible = not compact
	header.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE, Color.TRANSPARENT, 0, 0))
	place(header, Rect2(0, 48, width, 28))
	var deck_name := dialog.get_node("%DeckNameLabel") as Label
	deck_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	deck_name.clip_text = true
	deck_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	deck_name.tooltip_text = deck_name.text
	deck_name.add_theme_font_size_override("font_size", 16)
	dialog.get_node("%SummaryLabel").hide()
	var status := dialog.get_node("%StatusLabel") as Label
	if status.get_parent() != root:
		status.reparent(root, false)
	status.show()
	status.add_theme_font_size_override("font_size", 13)
	status.max_lines_visible = 2
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var status_top := 48.0 if compact else 80.0
	place(status, Rect2(0, status_top, width, 38))
	var transcript_top := status_top + 42
	var input_height := (104.0 if compact else 152.0) if narrow else (80.0 if compact else 136.0)
	var input_top := height - input_height
	var suggestions := dialog.get_node("%SuggestionsPanel") as Control
	suggestions.visible = not compact and not dialog.get("_latest_suggestions").is_empty()
	var suggestion_height := 48.0 if suggestions.visible else 0.0
	place(suggestions, Rect2(0, input_top - suggestion_height - 8, width, suggestion_height))
	var transcript := dialog.get_node("%TranscriptScroll") as ScrollContainer
	transcript.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	place(transcript, Rect2(0, transcript_top, width, maxf(1, input_top - suggestion_height - 16 - transcript_top)))
	var input_panel := dialog.get_node("%InputPanel") as PanelContainer
	input_panel.custom_minimum_size = Vector2.ZERO
	input_panel.add_theme_stylebox_override("panel", Palette.box(Palette.BG, Palette.LINE_STRONG, 10, 6))
	place(input_panel, Rect2(0, input_top, width, input_height))
	dialog.get_node("%AttachButton").hide() # No attachment action is implemented.
	var hint := dialog.get_node("%InputLabel") as Label
	hint.visible = not compact
	hint.text = "Enter 发送 · Shift+Enter 换行" if dialog.call("_should_auto_focus_question_input") else "输入问题，点击发送"
	hint.add_theme_font_size_override("font_size", 12)
	hint.clip_text = true
	dialog.call("_set_portrait_composer_stack", narrow)
	var actions := dialog.call("_actions_container") as HBoxContainer
	actions.custom_minimum_size = Vector2.ZERO
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 8)
	dialog.get_node("%ComposerRow").add_theme_constant_override("separation", 8)
	dialog.get_node("%ComposerRow").get_parent().add_theme_constant_override("separation", 6)
	var input := dialog.get_node("%QuestionInput") as TextEdit
	input.custom_minimum_size = Vector2(0, 40 if compact else 64)
	input.add_theme_font_size_override("font_size", 17)
	for id: String in ["ResetButton", "SendButton"]:
		var button := dialog.get_node("%" + id) as Button
		Palette.button(button, 1.0, id == "SendButton")
		button.text = "发送" if id == "SendButton" else "清空对话"
		button.custom_minimum_size = Vector2(84, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_END
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for child: Node in dialog.get_node("%SuggestionButtons").get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(0, 44)
			child.add_theme_font_size_override("font_size", 14)
	dialog.call("_refresh_existing_message_metrics")
	dialog.call("_apply_discussion_scrollbar_policy", portrait)
	transcript.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

static func display_unit(dialog: Control) -> float:
	var fallback: float = Palette.for_control(dialog).scale
	if OS.has_feature("web"):
		# Screen transforms use backing pixels, while browser hit targets use CSS
		# pixels. Retina landscape otherwise reduces a 44px button to about 17px.
		var css_width: Variant = JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');return c ? c.getBoundingClientRect().width : 0;})()", true)
		if css_width is float or css_width is int:
			if float(css_width) > 0:
				return dialog.get_viewport_rect().size.x / float(css_width)
	return fallback

static func window_scale(dialog: Control) -> float:
	# Offscreen render/test viewports have no screen embedding transform.
	return dialog.get_viewport().get_screen_transform().get_scale().y if dialog.get_viewport() is Window else 1.0

static func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
