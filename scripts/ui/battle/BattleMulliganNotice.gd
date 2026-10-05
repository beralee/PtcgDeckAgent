extends RefCounted

const AUTO_DISMISS_SECONDS := 3.4
const FADE_SECONDS := 0.2


class Toast extends PanelContainer:
	var player_name := ""
	var mulligan_name := ""
	var drawn_count := 0
	var content := Control.new()
	var badge := Panel.new()
	var count_label := Label.new()
	var title := Label.new()
	var reason := Label.new()
	var last_frame := Rect2()
	var last_top := -1.0
	var last_scale := 0.0

	func build() -> void:
		name = "MulliganNotice"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 640
		z_as_relative = false
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142832f5")
		style.border_color = Color("75d6c333")
		style.set_border_width_all(1)
		style.set_corner_radius_all(14)
		style.shadow_color = Color(0, 0, 0, 0.18)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
		# Explicit content geometry prevents transient wrapped-text minimums from
		# expanding the PanelContainer before its first width has settled.
		style.set_content_margin_all(0)
		add_theme_stylebox_override("panel", style)
		content.name = "Content"
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.clip_contents = true
		add_child(content)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("72d8bb1f")
		badge_style.set_corner_radius_all(10)
		badge.add_theme_stylebox_override("panel", badge_style)
		content.add_child(badge)
		count_label.name = "DrawCount"
		count_label.text = "+%d" % drawn_count if drawn_count > 0 else "0"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_color_override("font_color", Color("91e6ce"))
		badge.add_child(count_label)
		title.name = "MulliganNoticeText"
		title.add_theme_color_override("font_color", Color("f1f7f6"))
		reason.name = "MulliganNoticeReason"
		reason.add_theme_color_override("font_color", Color("acbdc5"))
		content.add_child(title)
		content.add_child(reason)
		for label: Label in [count_label, title, reason]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var timer := Timer.new()
		timer.name = "AutoDismissTimer"
		timer.wait_time = AUTO_DISMISS_SECONDS
		timer.one_shot = true
		timer.autostart = true
		timer.timeout.connect(_dismiss)
		add_child(timer)

	func _ready() -> void:
		last_frame = Rect2()
		update_layout()
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)

	func _process(_delta: float) -> void:
		# Battle safe frames can settle several frames after the root resize.
		# This short-lived toast only relayouts when its actual geometry changes.
		update_layout()

	func _dismiss() -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
		tween.tween_callback(queue_free)

	func update_layout() -> void:
		var scene := get_parent() as Control
		if scene == null:
			return
		var frame := Rect2(Vector2.ZERO, scene.size)
		if scene.has_method("_is_portrait_battle_layout_active") and bool(scene.call("_is_portrait_battle_layout_active")):
			var safe_frame: Rect2 = scene.get("_portrait_layout_frame_rect")
			frame = Rect2(safe_frame.position, scene.call("_portrait_dialog_viewport_size"))
		if frame.size.x <= 0 or frame.size.y <= 0:
			frame = scene.get_viewport_rect() if scene.is_inside_tree() else Rect2(0, 0, 1280, 720)
		var ui_scale := clampf(frame.size.x / 900.0, 1.0, 1.85) if frame.size.y > frame.size.x else 1.0
		if scene.is_inside_tree():
			var stretch := scene.get_viewport().get_stretch_transform().get_scale().abs()
			ui_scale = maxf(ui_scale, 1.0 / maxf(minf(stretch.x, stretch.y), 0.1))
		var top := frame.position.y + maxf(16.0 * ui_scale, frame.size.y * 0.08)
		var top_bar := scene.get_node_or_null("TopBar") as Control
		if top_bar != null and top_bar.visible:
			top = maxf(top, top_bar.get_rect().end.y + 10.0 * ui_scale)
		if frame == last_frame and is_equal_approx(top, last_top) and is_equal_approx(ui_scale, last_scale):
			return
		last_frame = frame
		last_top = top
		last_scale = ui_scale
		var width := minf(380.0 * ui_scale, maxf(1.0, frame.size.x - 24.0 * ui_scale))
		var height := 76.0 * ui_scale
		content.custom_minimum_size = Vector2(0, height)
		custom_minimum_size = Vector2.ZERO
		size = Vector2(width, height)
		position = Vector2(frame.position.x + (frame.size.x - width) * 0.5, clampf(top, frame.position.y, maxf(frame.position.y, frame.end.y - height - 12.0 * ui_scale)))
		badge.position = Vector2(14, 16) * ui_scale
		badge.size = Vector2(44, 44) * ui_scale
		count_label.size = badge.size
		count_label.add_theme_font_size_override("font_size", roundi(23 * ui_scale))
		var text_width := maxf(width - 86.0 * ui_scale, 1.0)
		title.position = Vector2(70, 12) * ui_scale
		title.size = Vector2(text_width, 28 * ui_scale)
		reason.position = Vector2(70, 42) * ui_scale
		reason.size = Vector2(text_width, 22 * ui_scale)
		title.add_theme_font_size_override("font_size", roundi(18 * ui_scale))
		reason.add_theme_font_size_override("font_size", roundi(14 * ui_scale))
		_fit_message(title, player_name, " · 补抽 %d 张" % drawn_count if drawn_count > 0 else " · 未能补抽")
		if drawn_count > 0:
			_fit_message(reason, mulligan_name, "起手无基础宝可梦")
		else:
			reason.text = "牌库已空，本次未补抽"

	func _fit_message(label: Label, full_name: String, suffix: String) -> void:
		var clean_name := full_name.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(160)
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var abbreviated := clean_name
		while clean_name.length() > 1 and font.get_string_size(abbreviated + suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
			clean_name = clean_name.left(clean_name.length() - 1)
			abbreviated = clean_name + "…"
		label.text = abbreviated + suffix


static func show_result(scene: Control, beneficiary: int, drawn_count: int) -> void:
	var previous := scene.get_node_or_null("MulliganNotice")
	if previous != null:
		scene.remove_child(previous)
		previous.queue_free()
	var notice := Toast.new()
	notice.player_name = GameManager.resolve_battle_player_display_name(beneficiary)
	notice.mulligan_name = GameManager.resolve_battle_player_display_name(1 - beneficiary)
	notice.drawn_count = drawn_count
	notice.build()
	scene.add_child(notice)
	notice.update_layout()
