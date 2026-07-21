class_name BattleActionIntentOverlay
extends Control

const ACTION_COLOR := Color(0.21, 0.92, 0.82, 0.95)
const TARGET_COLOR := Color(1.0, 0.78, 0.24, 1.0)
const PATH_COLOR := Color(1.0, 0.86, 0.38, 0.82)
const VfxCatalog := preload("res://scripts/ui/battle/intent/BattleInteractionVfxCatalog.gd")
const MAX_TRANSIENT_EVENTS := 28
const TARGET_OUTLINE_WIDTH := 2.0
const GUIDE_LINE_WIDTH := 1.5
const GUIDE_ARROW_LENGTH := 10.0
const GUIDE_ARROW_HALF_WIDTH := 4.0
const REJECTION_TOAST_HOLD_SECONDS := 2.2
const REJECTION_TOAST_FADE_SECONDS := 0.18

var _actionables: Array = []
var _targets: Array = []
var _source_rect := Rect2()
var _phase := 0.0
var _toast: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null
var _context: Dictionary = {}
var _low_hp_hazards: Array = []
var _events: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 2.5, TAU)
	for event_index: int in range(_events.size() - 1, -1, -1):
		var event: Dictionary = _events[event_index]
		event["age"] = float(event.get("age", 0.0)) + delta
		if float(event.get("age", 0.0)) >= float(event.get("duration", 0.5)):
			_events.remove_at(event_index)
	if not _actionables.is_empty() or not _targets.is_empty() or not _low_hp_hazards.is_empty() or not _events.is_empty():
		queue_redraw()


func set_visuals(
	actionables: Array,
	source_rect: Rect2,
	targets: Array,
	context: Dictionary = {}
) -> void:
	_actionables = actionables.duplicate(true)
	_source_rect = source_rect
	_targets = targets.duplicate(true)
	_context = context.duplicate(true)
	queue_redraw()


func set_low_hp_hazards(hazards: Array) -> void:
	_low_hp_hazards = hazards.duplicate(true)
	queue_redraw()


func play_event(event_kind: String, payload: Dictionary = {}) -> bool:
	if not VfxCatalog.has_effect(event_kind):
		return false
	var duration := VfxCatalog.duration(event_kind)
	if duration <= 0.0:
		return false
	var event := payload.duplicate(true)
	event["kind"] = event_kind
	event["age"] = 0.0
	event["duration"] = duration
	_events.append(event)
	while _events.size() > MAX_TRANSIENT_EVENTS:
		_events.pop_front()
	queue_redraw()
	return true


func clear_visuals() -> void:
	clear_intents()
	_events.clear()
	queue_redraw()


func clear_intents() -> void:
	_actionables.clear()
	_targets.clear()
	_source_rect = Rect2()
	_context.clear()
	_low_hp_hazards.clear()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	if _toast != null:
		_toast.visible = false
	queue_redraw()


func visual_snapshot() -> Dictionary:
	var event_kinds: Array[String] = []
	for event: Dictionary in _events:
		var event_kind := str(event.get("kind", ""))
		if event_kind != "" and event_kind not in event_kinds:
			event_kinds.append(event_kind)
	var attribute_glow_count := 0
	var attack_ready_count := 0
	for entry: Dictionary in _actionables:
		if entry.get("attribute_color", null) is Color:
			attribute_glow_count += 1
		if "attack" in (entry.get("action_kinds", []) as Array):
			attack_ready_count += 1
	return {
		"actionable_count": _actionables.size(),
		"target_count": _targets.size(),
		"path_count": _targets.size() if _source_rect.has_area() else 0,
		"flow_path_count": _targets.size() if _source_rect.has_area() else 0,
		"flow_particle_count": _targets.size() * 3 if _source_rect.has_area() else 0,
		"fanout_count": _targets.size() if _targets.size() > 1 and _source_rect.has_area() else 0,
		"source_magnet_visible": false,
		"source_center": _source_rect.get_center() if _source_rect.has_area() else Vector2.ZERO,
		"target_label_count": 0,
		"guide_line_width": GUIDE_LINE_WIDTH,
		"attribute_glow_count": attribute_glow_count,
		"attack_ready_count": attack_ready_count,
		"low_hp_count": _low_hp_hazards.size(),
		"low_hp_outline_mode": "card_perimeter",
		"active_event_count": _events.size(),
		"event_kinds": event_kinds,
		"toast_visible": _toast != null and _toast.visible,
	}


func show_rejection(anchor_rect: Rect2, title: String, reason: String) -> void:
	_ensure_toast()
	if _toast == null or _toast_label == null:
		return
	var clean_title := title.strip_edges()
	var clean_reason := reason.strip_edges()
	if clean_reason == "":
		clean_reason = "当前无法执行该操作。"
	_toast_label.text = ("%s\n" % clean_title if clean_title != "" else "") + clean_reason
	var viewport_size := size
	var portrait := viewport_size.y > viewport_size.x
	var portrait_max_width := maxf(1.0, viewport_size.x - 24.0)
	var portrait_min_width := minf(520.0, portrait_max_width)
	var toast_width := clampf(viewport_size.x * 0.86, portrait_min_width, portrait_max_width) if portrait else clampf(viewport_size.x * 0.52, 280.0, 560.0)
	var toast_height := (184.0 if clean_title != "" else 142.0) if portrait else (104.0 if clean_title != "" else 78.0)
	var text_margin := 48.0 if portrait else 36.0
	var vertical_margin := 36.0 if portrait else 24.0
	_toast_label.add_theme_font_size_override("font_size", 34 if portrait else 18)
	_toast_label.max_lines_visible = 4 if portrait else 3
	_toast_label.custom_minimum_size = Vector2(toast_width - text_margin, toast_height - vertical_margin)
	_toast.custom_minimum_size = Vector2(toast_width, toast_height)
	_toast.size = Vector2(toast_width, toast_height)
	var anchor_center := anchor_rect.get_center() if anchor_rect.has_area() else viewport_size * 0.5
	var desired := Vector2(anchor_center.x - toast_width * 0.5, anchor_rect.position.y - toast_height - 16.0)
	if desired.y < 12.0:
		desired.y = anchor_rect.end.y + 16.0
	desired.x = clampf(desired.x, 12.0, maxf(12.0, viewport_size.x - toast_width - 12.0))
	desired.y = clampf(desired.y, 12.0, maxf(12.0, viewport_size.y - toast_height - 12.0))
	_toast.position = desired
	_toast.modulate = Color(1, 1, 1, 0)
	_toast.scale = Vector2(0.96, 0.96)
	_toast.pivot_offset = _toast.size * 0.5
	_toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.12)
	_toast_tween.tween_interval(REJECTION_TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, REJECTION_TOAST_FADE_SECONDS)
	_toast_tween.tween_callback(_hide_rejection_toast)
	play_event("invalid_recoil", {"to_rect": anchor_rect, "point": anchor_rect.get_center()})


func dismiss_rejection() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	_hide_rejection_toast()


func _hide_rejection_toast() -> void:
	if _toast != null and is_instance_valid(_toast):
		_toast.visible = false


func _ensure_toast() -> void:
	if _toast != null and is_instance_valid(_toast):
		return
	_toast = PanelContainer.new()
	_toast.name = "BattleActionIntentToast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.105, 0.96)
	style.border_color = Color(1.0, 0.67, 0.25, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_toast.add_theme_stylebox_override("panel", style)
	_toast_label = Label.new()
	_toast_label.name = "BattleActionIntentToastLabel"
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.max_lines_visible = 3
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast.add_child(_toast_label)
	add_child(_toast)


func _draw() -> void:
	var pulse := 0.72 + 0.22 * (sin(_phase) * 0.5 + 0.5)
	for entry: Dictionary in _actionables:
		var rect: Rect2 = entry.get("rect", Rect2())
		if not rect.has_area():
			continue
		var action_color: Color = entry.get("attribute_color", ACTION_COLOR) as Color
		_draw_intent_rect(rect.grow(5.0), action_color * Color(1, 1, 1, pulse), 3.0)
		_draw_intent_rect(rect.grow(10.0 + sin(_phase) * 2.0), Color(action_color.r, action_color.g, action_color.b, 0.18), 2.0)
		_draw_label(rect, str(entry.get("label", "可操作")), action_color)
		if "attack" in (entry.get("action_kinds", []) as Array):
			_draw_attack_ready(rect, action_color)
	for entry: Dictionary in _targets:
		var rect: Rect2 = entry.get("rect", Rect2())
		if not rect.has_area():
			continue
		_draw_intent_rect(rect.grow(5.0), TARGET_COLOR, TARGET_OUTLINE_WIDTH)
		if _source_rect.has_area():
			_draw_guide_path(_source_rect.get_center(), rect.get_center(), int(entry.get("index", 0)))
	for hazard: Dictionary in _low_hp_hazards:
		_draw_low_hp_pulse(hazard)
	for event: Dictionary in _events:
		_draw_transient_event(event)


func _draw_intent_rect(rect: Rect2, color: Color, width: float) -> void:
	draw_style_box(_outline_style(color, width), rect)


func _outline_style(color: Color, width: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.055)
	style.border_color = color
	style.set_border_width_all(int(ceilf(width)))
	style.set_corner_radius_all(13)
	return style


func _draw_label(rect: Rect2, label: String, color: Color) -> void:
	if label.strip_edges() == "":
		return
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var badge := Rect2(rect.position + Vector2(4, -text_size.y - 9), text_size + Vector2(16, 8))
	if badge.position.y < 2:
		badge.position.y = rect.position.y + 5
	draw_style_box(_badge_style(color), badge)
	draw_string(font, badge.position + Vector2(8, badge.size.y - 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.02, 0.05, 0.07, 1))


func _badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	return style


func _draw_guide_path(from: Vector2, to: Vector2, branch_index: int = 0) -> void:
	var lift := minf(150.0, absf(to.y - from.y) * 0.28 + 48.0)
	var branch_offset := float(branch_index) * 18.0
	var control_a := from + Vector2(branch_offset, -lift)
	var control_b := to + Vector2(-branch_offset, lift * 0.45)
	var previous := from
	for segment: int in range(1, 25):
		var t := float(segment) / 24.0
		var point := _cubic_bezier(from, control_a, control_b, to, t)
		if segment % 2 == 0:
			draw_line(previous, point, PATH_COLOR, GUIDE_LINE_WIDTH, true)
		previous = point
	var tangent := (to - control_b).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	draw_colored_polygon(PackedVector2Array([
		to,
		to - tangent * GUIDE_ARROW_LENGTH + normal * GUIDE_ARROW_HALF_WIDTH,
		to - tangent * GUIDE_ARROW_LENGTH - normal * GUIDE_ARROW_HALF_WIDTH,
	]), PATH_COLOR)
	for particle_index: int in 3:
		var particle_t := fmod(_phase / TAU + float(particle_index) / 3.0 - float(branch_index) * 0.07, 1.0)
		var particle_point := _cubic_bezier(from, control_a, control_b, to, particle_t)
		draw_circle(particle_point, 2.0 + float(particle_index) * 0.5, Color(1.0, 0.94, 0.58, 0.82))


func _draw_attack_ready(rect: Rect2, color: Color) -> void:
	for particle_index: int in 5:
		var angle := _phase + TAU * float(particle_index) / 5.0
		var radius := maxf(rect.size.x, rect.size.y) * 0.48 + sin(_phase * 1.7 + particle_index) * 4.0
		var point := rect.get_center() + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(point, 2.6, Color(color.r, color.g, color.b, 0.72))


func _draw_low_hp_pulse(hazard: Dictionary) -> void:
	var rect: Rect2 = hazard.get("rect", Rect2())
	if not rect.has_area():
		return
	var pulse := 0.2 + 0.22 * (sin(_phase * 0.72) * 0.5 + 0.5)
	var perimeter_style := _outline_style(Color(1.0, 0.12, 0.08, pulse), 2.0)
	perimeter_style.bg_color = Color.TRANSPARENT
	draw_style_box(perimeter_style, rect.grow(4.0))


func _draw_transient_event(event: Dictionary) -> void:
	var duration := maxf(0.001, float(event.get("duration", 0.5)))
	var progress := clampf(float(event.get("age", 0.0)) / duration, 0.0, 1.0)
	match str(event.get("kind", "")):
		"touch_ripple":
			_draw_touch_ripple(event, progress)
		"invalid_recoil":
			_draw_invalid_recoil(event, progress)
		"success_converge":
			_draw_success_converge(event, progress)
		"energy_orbit":
			_draw_energy_orbit(event, progress)
		"tool_lock":
			_draw_tool_lock(event, progress)
		"retreat_swap":
			_draw_retreat_swap(event, progress)
		"ability_ripple":
			_draw_ability_ripple(event, progress)
		"phase_sweep":
			_draw_phase_sweep(progress)
		"combo_cadence":
			_draw_combo_cadence(event, progress)


func _draw_touch_ripple(event: Dictionary, progress: float) -> void:
	var point: Vector2 = event.get("point", Vector2.ZERO)
	draw_arc(point, 8.0 + 42.0 * progress, 0, TAU, 36, Color(0.38, 0.92, 1.0, (1.0 - progress) * 0.8), 3.0, true)


func _draw_invalid_recoil(event: Dictionary, progress: float) -> void:
	var rect: Rect2 = event.get("to_rect", Rect2())
	if not rect.has_area():
		return
	var offset := sin(progress * PI * 7.0) * (1.0 - progress) * 10.0
	var recoil_rect := Rect2(rect.position + Vector2(offset, 0), rect.size).grow(5.0)
	_draw_intent_rect(recoil_rect, Color(1.0, 0.2, 0.08, 0.86 * (1.0 - progress)), 4.0)
	draw_arc(rect.get_center(), 18.0 + 70.0 * progress, 0, TAU, 40, Color(1.0, 0.35, 0.08, 0.7 * (1.0 - progress)), 4.0, true)


func _draw_success_converge(event: Dictionary, progress: float) -> void:
	var from_rect: Rect2 = event.get("from_rect", Rect2())
	var to_rect: Rect2 = event.get("to_rect", Rect2())
	if not to_rect.has_area():
		return
	if from_rect.has_area():
		var moving_point := from_rect.get_center().lerp(to_rect.get_center(), _ease_out_cubic(progress))
		draw_circle(moving_point, 9.0 * (1.0 - progress) + 3.0, Color(1.0, 0.9, 0.35, 0.9))
	draw_arc(to_rect.get_center(), maxf(to_rect.size.x, to_rect.size.y) * (0.6 - 0.25 * progress), 0, TAU, 40, Color(1.0, 0.88, 0.28, 1.0 - progress), 5.0, true)


func _draw_energy_orbit(event: Dictionary, progress: float) -> void:
	var from_rect: Rect2 = event.get("from_rect", Rect2())
	var to_rect: Rect2 = event.get("to_rect", Rect2())
	if not to_rect.has_area():
		return
	var from := from_rect.get_center() if from_rect.has_area() else to_rect.get_center() + Vector2(-140, 120)
	var center := from.lerp(to_rect.get_center(), minf(1.0, progress * 1.35))
	if progress > 0.55:
		var orbit_angle := (progress - 0.55) / 0.45 * TAU * 1.5
		center = to_rect.get_center() + Vector2(cos(orbit_angle), sin(orbit_angle)) * minf(to_rect.size.x, to_rect.size.y) * 0.42
	draw_circle(center, 9.0, Color(1.0, 0.76, 0.16, 1.0 - progress * 0.45))
	draw_circle(center, 4.0, Color.WHITE)


func _draw_tool_lock(event: Dictionary, progress: float) -> void:
	var rect: Rect2 = event.get("to_rect", Rect2())
	if not rect.has_area():
		return
	var inset := (1.0 - _ease_out_cubic(progress)) * 42.0 + 8.0
	var lock_rect := rect.grow(inset)
	var corner := minf(lock_rect.size.x, lock_rect.size.y) * 0.22
	var color := Color(0.48, 0.92, 1.0, 1.0 - progress * 0.55)
	for point: Vector2 in [lock_rect.position, Vector2(lock_rect.end.x, lock_rect.position.y), lock_rect.end, Vector2(lock_rect.position.x, lock_rect.end.y)]:
		var sx := 1.0 if point.x == lock_rect.position.x else -1.0
		var sy := 1.0 if point.y == lock_rect.position.y else -1.0
		draw_line(point, point + Vector2(sx * corner, 0), color, 5.0, true)
		draw_line(point, point + Vector2(0, sy * corner), color, 5.0, true)


func _draw_retreat_swap(event: Dictionary, progress: float) -> void:
	var from_rect: Rect2 = event.get("from_rect", Rect2())
	var to_rect: Rect2 = event.get("to_rect", Rect2())
	if not from_rect.has_area() or not to_rect.has_area():
		return
	var from := from_rect.get_center()
	var to := to_rect.get_center()
	var normal := Vector2(-(to - from).normalized().y, (to - from).normalized().x) * 48.0
	var point_a := _quadratic_bezier(from, (from + to) * 0.5 + normal, to, progress)
	var point_b := _quadratic_bezier(to, (from + to) * 0.5 - normal, from, progress)
	draw_circle(point_a, 8.0, Color(0.25, 0.9, 1.0, 1.0 - progress * 0.4))
	draw_circle(point_b, 8.0, Color(1.0, 0.74, 0.24, 1.0 - progress * 0.4))


func _draw_ability_ripple(event: Dictionary, progress: float) -> void:
	var rect: Rect2 = event.get("to_rect", Rect2())
	if not rect.has_area():
		return
	var color: Color = event.get("color", Color(0.66, 0.38, 1.0, 1.0)) as Color
	for ring_index: int in 3:
		var ring_progress := clampf(progress * 1.4 - float(ring_index) * 0.16, 0.0, 1.0)
		draw_arc(rect.get_center(), 14.0 + ring_progress * maxf(rect.size.x, rect.size.y) * 0.68, 0, TAU, 40, Color(color.r, color.g, color.b, (1.0 - ring_progress) * 0.75), 4.0, true)


func _draw_phase_sweep(progress: float) -> void:
	var y := size.y * (0.92 - 0.74 * _ease_out_cubic(progress))
	var color := Color(0.28, 0.92, 0.84, sin(progress * PI) * 0.38)
	draw_rect(Rect2(0, y - 26, size.x, 52), color)
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.66, 1.0, 0.92, sin(progress * PI) * 0.8), 4.0, true)


func _draw_combo_cadence(event: Dictionary, progress: float) -> void:
	var rect: Rect2 = event.get("to_rect", Rect2())
	var point: Vector2 = rect.get_center() if rect.has_area() else event.get("point", size * 0.5)
	var level := clampi(int(event.get("level", 1)), 1, 4)
	for ring_index: int in level:
		var radius := 18.0 + (progress * 54.0) + ring_index * 9.0
		draw_arc(point, radius, 0, TAU, 32, Color(1.0, 0.82, 0.24, (1.0 - progress) * 0.68), 3.0, true)


func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * b + t * t * c


func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 3.0)


func _cubic_bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * a + 3.0 * u * u * t * b + 3.0 * u * t * t * c + t * t * t * d
