class_name BattleLayoutDebugReporter
extends RefCounted

const DEBUG_STADIUM_HUD_LAYOUT_PAINT := false
const DEBUG_PORTRAIT_LAYOUT_PAINT := false
const DEBUG_PORTRAIT_LAYOUT_TRACE := false
const DEBUG_PORTRAIT_LAYOUT_ENV := "PTCG_DEBUG_PORTRAIT_LAYOUT"
const DEBUG_PORTRAIT_LAYOUT_PROJECT_SETTING := "ptcg/debug/portrait_layout_paint"
const DEBUG_PORTRAIT_LAYOUT_TRACE_ENV := "PTCG_TRACE_PORTRAIT_LAYOUT"
const DEBUG_PORTRAIT_LAYOUT_TRACE_PROJECT_SETTING := "ptcg/debug/portrait_layout_trace"
const PORTRAIT_LAYOUT_DEBUG_LOG_PATH := "user://logs/portrait_layout_debug.log"
const PORTRAIT_LAYOUT_TRACE_LOG_PATH := "user://logs/portrait_layout_trace.log"
const PORTRAIT_DEBUG_OVERLAY_Z_INDEX := 495

var _scene: Node = null
var _stadium_hud_debug_overlay: Control = null
var _portrait_layout_debug_overlay: Control = null
var _portrait_layout_debug_last_signature: String = ""
var _portrait_layout_trace_initialized: bool = false
var _portrait_layout_trace_counter: int = 0


func setup(scene: Node) -> void:
	_scene = scene


func request_stadium_hud_debug_overlay_refresh() -> void:
	if not DEBUG_STADIUM_HUD_LAYOUT_PAINT or not _is_inside_tree():
		return
	call_deferred("refresh_stadium_hud_debug_overlay")


func refresh_stadium_hud_debug_overlay() -> void:
	if not DEBUG_STADIUM_HUD_LAYOUT_PAINT or not _is_inside_tree():
		return
	var overlay := _ensure_stadium_hud_debug_overlay()
	if overlay == null:
		return
	for child: Node in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	var stadium_center := _get("_stadium_center_section") as Control
	if stadium_center == null:
		stadium_center = _find("StadiumCenterSection", true, false) as Control
	var lost_zone := _get("_lost_zone_section") as Control
	if lost_zone == null:
		lost_zone = _find("LostZoneSection", true, false) as Control
	var end_turn_btn := _get("_hud_end_turn_btn") as Control
	if end_turn_btn == null:
		end_turn_btn = _find("HudEndTurnBtn", true, false) as Control
	var stadium_card_view := _get("_stadium_card_view") as Control
	if stadium_card_view != null and not is_instance_valid(stadium_card_view):
		stadium_card_view = null
	var targets: Array[Dictionary] = [
		{
			"label": "StadiumBar",
			"control": _node("MainArea/CenterField/FieldArea/StadiumBar") as Control,
			"color": Color(1.0, 0.05, 0.05, 0.22),
		},
		{
			"label": "StadiumSections",
			"control": _node("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections") as Control,
			"color": Color(1.0, 0.45, 0.0, 0.22),
		},
		{
			"label": "LeftSpacer",
			"control": _find("LandscapeStadiumLeftSpacer", true, false) as Control,
			"color": Color(0.7, 0.25, 1.0, 0.34),
		},
		{
			"label": "StadiumCenter",
			"control": stadium_center,
			"color": Color(1.0, 0.95, 0.05, 0.36),
		},
		{
			"label": "Flex/LostZoneSlot",
			"control": lost_zone,
			"color": Color(0.05, 0.7, 1.0, 0.32),
		},
		{
			"label": "EndTurnColumn",
			"control": _find("TurnActionColumn", true, false) as Control,
			"color": Color(0.1, 1.0, 0.25, 0.36),
		},
		{
			"label": "EndTurnButton",
			"control": end_turn_btn,
			"color": Color(0.0, 1.0, 0.75, 0.36),
		},
		{
			"label": "StadiumCardView",
			"control": stadium_card_view,
			"color": Color(1.0, 0.0, 0.95, 0.34),
		},
	]
	for target: Dictionary in targets:
		_add_stadium_hud_debug_rect(
			overlay,
			target.get("control") as Control,
			str(target.get("label", "")),
			target.get("color", Color(1, 1, 1, 0.25))
		)


func trace_portrait_layout_stage(stage: String) -> void:
	if not should_trace_portrait_layout():
		return
	_ensure_portrait_layout_trace_file()
	_portrait_layout_trace_counter += 1
	var viewport_size: Vector2 = _scene.get_viewport_rect().size
	var scene_size := _scene_control_size()
	var frame_rect_variant: Variant = _get("_portrait_layout_frame_rect")
	var frame_rect: Rect2 = frame_rect_variant if frame_rect_variant is Rect2 else Rect2()
	var full_size_variant: Variant = _get("_portrait_layout_full_size")
	var full_size: Vector2 = full_size_variant if full_size_variant is Vector2 else Vector2.ZERO
	if full_size == Vector2.ZERO:
		full_size = scene_size
	if full_size == Vector2.ZERO:
		full_size = viewport_size
	var safe_x := _as_float(_call("_portrait_horizontal_safe_inset", [frame_rect.size]), 0.0) if frame_rect.size != Vector2.ZERO else 0.0
	var safe_rect := Rect2(
		Vector2(frame_rect.position.x + safe_x, frame_rect.position.y),
		Vector2(maxf(frame_rect.size.x - safe_x * 2.0, 0.0), frame_rect.size.y)
	) if frame_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, full_size)
	var resolved_mode := str(_call("_current_resolved_battle_layout_mode")) if _is_inside_tree() else str(_get("_active_battle_layout_mode"))
	var lines: Array[String] = []
	lines.append("")
	lines.append("=== portrait trace #%d stage=%s ticks=%d active=%s resolved=%s rotated=%s ===" % [
		_portrait_layout_trace_counter,
		stage,
		Time.get_ticks_msec(),
		str(_get("_active_battle_layout_mode")),
		resolved_mode,
		str(_as_bool(_get("_rotated_portrait_canvas_active"), false)),
	])
	lines.append("viewport=%s scene_size=%s full=%s frame=%s safe=%s" % [
		_format_vec2(viewport_size),
		_format_vec2(scene_size),
		_format_vec2(full_size),
		_format_rect(frame_rect),
		_format_rect(safe_rect),
	])
	for target: Dictionary in _portrait_layout_trace_targets():
		_append_portrait_layout_trace_control(lines, str(target.get("label", "")), target.get("control") as Control, safe_rect)
	_append_portrait_layout_trace_children(lines, "HandChild", _get("_hand_container") as Control, safe_rect, 8)
	_append_portrait_layout_trace_children(lines, "MyBenchChild", _get("_portrait_my_bench_grid") as Control, safe_rect, 5)
	_append_portrait_layout_trace_children(lines, "OppBenchChild", _get("_portrait_opp_bench_grid") as Control, safe_rect, 5)
	_append_portrait_layout_trace_children(lines, "MyBenchLegacyChild", _get("_my_bench") as Control, safe_rect, 5)
	_append_portrait_layout_trace_children(lines, "OppBenchLegacyChild", _get("_opp_bench") as Control, safe_rect, 5)
	_append_portrait_layout_trace_file(lines)


func should_trace_portrait_layout() -> bool:
	var enabled := DEBUG_PORTRAIT_LAYOUT_TRACE
	if not enabled and bool(ProjectSettings.get_setting(DEBUG_PORTRAIT_LAYOUT_TRACE_PROJECT_SETTING, false)):
		enabled = true
	if not enabled:
		var env_value := OS.get_environment(DEBUG_PORTRAIT_LAYOUT_TRACE_ENV).strip_edges().to_lower()
		enabled = env_value in ["1", "true", "yes", "on"]
	if not enabled or not _is_inside_tree():
		return false
	if str(_get("_active_battle_layout_mode")) == "portrait" or _as_bool(_get("_rotated_portrait_canvas_active"), false):
		return true
	return str(_call("_current_resolved_battle_layout_mode")) == "portrait"


func request_portrait_layout_debug_overlay_refresh() -> void:
	if not _is_inside_tree():
		return
	call_deferred("refresh_portrait_layout_debug_overlay")


func refresh_portrait_layout_debug_overlay() -> void:
	if not is_portrait_layout_debug_paint_enabled() or not _is_inside_tree():
		hide_portrait_layout_debug_overlay()
		return
	if str(_call("_current_resolved_battle_layout_mode")) != "portrait" and not _as_bool(_get("_rotated_portrait_canvas_active"), false):
		hide_portrait_layout_debug_overlay()
		return
	var overlay := _ensure_portrait_layout_debug_overlay()
	if overlay == null:
		return
	for child: Node in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	var root_size_variant: Variant = _get("_portrait_layout_full_size")
	var root_size: Vector2 = root_size_variant if root_size_variant is Vector2 else Vector2.ZERO
	if root_size == Vector2.ZERO:
		root_size = _scene_control_size()
	if root_size == Vector2.ZERO:
		root_size = _scene.get_viewport_rect().size
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.position = Vector2.ZERO
	overlay.size = root_size
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = root_size.x
	overlay.offset_bottom = root_size.y
	overlay.visible = true
	var entries: Array[Dictionary] = []
	_add_portrait_layout_debug_rect_entry(entries, "scene_root", Rect2(Vector2.ZERO, root_size), Color(1.0, 1.0, 1.0, 0.12))
	_add_portrait_layout_debug_rect_entry(entries, "physical_viewport", Rect2(Vector2.ZERO, _scene.get_viewport_rect().size), Color(1.0, 0.0, 0.0, 0.10))
	var frame_rect_variant: Variant = _get("_portrait_layout_frame_rect")
	var frame_rect: Rect2 = frame_rect_variant if frame_rect_variant is Rect2 else Rect2()
	if frame_rect.size != Vector2.ZERO:
		_add_portrait_layout_debug_rect_entry(entries, "portrait_frame", frame_rect, Color(1.0, 0.0, 1.0, 0.16))
		var safe_x := _as_float(_call("_portrait_horizontal_safe_inset", [frame_rect.size]), 0.0)
		var safe_rect := Rect2(
			Vector2(frame_rect.position.x + safe_x, frame_rect.position.y),
			Vector2(maxf(frame_rect.size.x - safe_x * 2.0, 1.0), frame_rect.size.y)
		)
		_add_portrait_layout_debug_rect_entry(entries, "portrait_safe_frame", safe_rect, Color(0.0, 1.0, 1.0, 0.13))
	for target: Dictionary in _portrait_layout_debug_control_targets():
		var control := target.get("control") as Control
		var rect := _control_rect_in_battle_local(control)
		if rect.size.x <= 0.5 or rect.size.y <= 0.5:
			continue
		_add_portrait_layout_debug_rect_entry(
			entries,
			str(target.get("label", "")),
			rect,
			target.get("color", Color(1, 1, 1, 0.18))
		)
	for entry: Dictionary in entries:
		_add_portrait_layout_debug_rect(
			overlay,
			entry.get("rect", Rect2()),
			str(entry.get("label", "")),
			entry.get("color", Color(1, 1, 1, 0.18))
		)
	_write_portrait_layout_debug_snapshot(entries, root_size)


func hide_portrait_layout_debug_overlay() -> void:
	_portrait_layout_debug_last_signature = ""
	if _portrait_layout_debug_overlay != null and is_instance_valid(_portrait_layout_debug_overlay):
		_portrait_layout_debug_overlay.visible = false


func _ensure_stadium_hud_debug_overlay() -> Control:
	if _stadium_hud_debug_overlay != null and is_instance_valid(_stadium_hud_debug_overlay):
		return _stadium_hud_debug_overlay
	if _scene == null:
		return null
	var overlay := Control.new()
	overlay.name = "StadiumHudLayoutDebugOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.z_as_relative = false
	overlay.z_index = 180
	_scene.add_child(overlay)
	_stadium_hud_debug_overlay = overlay
	return overlay


func _add_stadium_hud_debug_rect(overlay: Control, control: Control, label: String, color: Color) -> void:
	if overlay == null or control == null:
		return
	var rect := control.get_global_rect()
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var overlay_rect := overlay.get_global_rect()
	var fill := ColorRect.new()
	fill.name = "Debug%s" % label
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = rect.position - overlay_rect.position
	fill.size = rect.size
	fill.color = color
	overlay.add_child(fill)
	var caption := Label.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = "%s %.0fx%.0f" % [label, rect.size.x, rect.size.y]
	caption.position = Vector2(4.0, 2.0)
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	caption.add_theme_constant_override("outline_size", 2)
	fill.add_child(caption)


func _ensure_portrait_layout_trace_file() -> void:
	if _portrait_layout_trace_initialized:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	var file := FileAccess.open(PORTRAIT_LAYOUT_TRACE_LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("portrait layout trace started ticks=%d" % Time.get_ticks_msec())
		file.close()
	_portrait_layout_trace_initialized = true


func _append_portrait_layout_trace_file(lines: Array[String]) -> void:
	var file := FileAccess.open(PORTRAIT_LAYOUT_TRACE_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	for line: String in lines:
		file.store_line(line)
	file.close()


func _portrait_layout_trace_targets() -> Array[Dictionary]:
	var targets := _portrait_layout_debug_control_targets()
	targets.append_array([
		{"label": "TopBarRow", "control": _find("TopBarRow", true, false) as Control},
		{"label": "TopBarLeft", "control": _find("TopBarLeft", true, false) as Control},
		{"label": "TopBarCenter", "control": _find("TopBarCenter", true, false) as Control},
		{"label": "TopBarRight", "control": _find("TopBarRight", true, false) as Control},
		{"label": "LeftPanel", "control": _get("_left_panel") as Control},
		{"label": "RightPanel", "control": _get("_right_panel") as Control},
		{"label": "LogPanel", "control": _node("MainArea/LogPanel") as Control},
		{"label": "StadiumSections", "control": _find("StadiumSections", true, false) as Control},
		{"label": "BtnStadiumAction", "control": _get("_btn_stadium_action") as Control},
	])
	return targets


func _append_portrait_layout_trace_control(lines: Array[String], label: String, control: Control, safe_rect: Rect2) -> void:
	if control == null:
		lines.append("%s <null>" % label)
		return
	var local_rect := _control_rect_in_battle_local(control)
	var global_rect := control.get_global_rect()
	var parent_control := control.get_parent() as Control
	var parent_desc := "<none>"
	if parent_control != null:
		parent_desc = "%s local=%s min=%s" % [
			parent_control.name,
			_format_rect(_control_rect_in_battle_local(parent_control)),
			_format_vec2(parent_control.get_combined_minimum_size()),
		]
	var overflow := _portrait_layout_trace_overflow(local_rect, safe_rect)
	lines.append("%s name=%s visible=%s parent=%s local=%s global=%s size=%s min=%s combined_min=%s flags=%d/%d clip=%s overflow=%s" % [
		label,
		control.name,
		str(control.visible),
		parent_desc,
		_format_rect(local_rect),
		_format_rect(global_rect),
		_format_vec2(control.size),
		_format_vec2(control.custom_minimum_size),
		_format_vec2(control.get_combined_minimum_size()),
		control.size_flags_horizontal,
		control.size_flags_vertical,
		str(control.clip_contents),
		overflow,
	])


func _append_portrait_layout_trace_children(lines: Array[String], label_prefix: String, parent: Control, safe_rect: Rect2, max_children: int) -> void:
	if parent == null:
		lines.append("%s <parent-null>" % label_prefix)
		return
	var index := 0
	for child: Node in parent.get_children():
		var child_control := child as Control
		if child_control != null:
			_append_portrait_layout_trace_control(lines, "%s%d" % [label_prefix, index], child_control, safe_rect)
			index += 1
			if index >= max_children:
				break
	lines.append("%s_count=%d logged=%d" % [label_prefix, parent.get_child_count(), index])


func _portrait_layout_trace_overflow(rect: Rect2, safe_rect: Rect2) -> String:
	if rect.size == Vector2.ZERO or safe_rect.size == Vector2.ZERO:
		return "unknown"
	var messages: Array[String] = []
	if rect.position.x < safe_rect.position.x - 0.5:
		messages.append("left %.1f" % (safe_rect.position.x - rect.position.x))
	if rect.position.x + rect.size.x > safe_rect.position.x + safe_rect.size.x + 0.5:
		messages.append("right %.1f" % (rect.position.x + rect.size.x - safe_rect.position.x - safe_rect.size.x))
	if messages.is_empty():
		return "ok"
	return ",".join(messages)


func is_portrait_layout_debug_paint_enabled() -> bool:
	if not DEBUG_PORTRAIT_LAYOUT_PAINT:
		return false
	if DEBUG_PORTRAIT_LAYOUT_PAINT:
		return true
	if bool(ProjectSettings.get_setting(DEBUG_PORTRAIT_LAYOUT_PROJECT_SETTING, false)):
		return true
	var env_value := OS.get_environment(DEBUG_PORTRAIT_LAYOUT_ENV).strip_edges().to_lower()
	return env_value in ["1", "true", "yes", "on"]


func _ensure_portrait_layout_debug_overlay() -> Control:
	if _portrait_layout_debug_overlay != null and is_instance_valid(_portrait_layout_debug_overlay):
		return _portrait_layout_debug_overlay
	if _scene == null:
		return null
	var overlay := Control.new()
	overlay.name = "PortraitLayoutDebugOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.z_as_relative = false
	overlay.z_index = PORTRAIT_DEBUG_OVERLAY_Z_INDEX
	_scene.add_child(overlay)
	_portrait_layout_debug_overlay = overlay
	return overlay


func _portrait_layout_debug_control_targets() -> Array[Dictionary]:
	return [
		{"label": "TopBar", "control": _get("_top_bar") as Control, "color": Color(1.0, 0.55, 0.0, 0.20)},
		{"label": "TopBarActions", "control": _find("TopBarActions", true, false) as Control, "color": Color(1.0, 0.85, 0.0, 0.22)},
		{"label": "MainArea", "control": _node("MainArea") as Control, "color": Color(0.1, 1.0, 0.2, 0.14)},
		{"label": "CenterField", "control": _node("MainArea/CenterField") as Control, "color": Color(0.0, 0.8, 1.0, 0.14)},
		{"label": "FieldArea", "control": _node("MainArea/CenterField/FieldArea") as Control, "color": Color(0.8, 1.0, 0.0, 0.15)},
		{"label": "OppField", "control": _node("MainArea/CenterField/FieldArea/OppField") as Control, "color": Color(0.35, 0.45, 1.0, 0.12)},
		{"label": "OppFieldShell", "control": _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell") as Control, "color": Color(0.55, 0.45, 1.0, 0.14)},
		{"label": "OppFieldInner", "control": _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner") as Control, "color": Color(0.75, 0.45, 1.0, 0.16)},
		{"label": "OppActiveRow", "control": _node("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner/OppActiveRow") as Control, "color": Color(0.95, 0.45, 1.0, 0.18)},
		{"label": "MyField", "control": _node("MainArea/CenterField/FieldArea/MyField") as Control, "color": Color(0.1, 0.9, 0.45, 0.12)},
		{"label": "MyFieldShell", "control": _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell") as Control, "color": Color(0.1, 0.9, 0.65, 0.14)},
		{"label": "MyFieldInner", "control": _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner") as Control, "color": Color(0.1, 0.9, 0.85, 0.16)},
		{"label": "MyActiveRow", "control": _node("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner/MyActiveRow") as Control, "color": Color(0.1, 1.0, 1.0, 0.18)},
		{"label": "HandArea", "control": _node("MainArea/CenterField/HandArea") as Control, "color": Color(0.0, 0.25, 1.0, 0.18)},
		{"label": "HandScroll", "control": _get("_hand_scroll") as Control, "color": Color(0.0, 0.55, 1.0, 0.24)},
		{"label": "HandContainer", "control": _get("_hand_container") as Control, "color": Color(0.0, 0.9, 1.0, 0.24)},
		{"label": "PortraitHudOverlay", "control": _find("PortraitEdgeHudOverlay", true, false) as Control, "color": Color(0.75, 0.0, 1.0, 0.12)},
		{"label": "OppLeftHudGroup", "control": _find("OppPortraitLeftHudGroup", true, false) as Control, "color": Color(1.0, 0.0, 0.15, 0.28)},
		{"label": "OppRightHudGroup", "control": _find("OppPortraitRightHudGroup", true, false) as Control, "color": Color(1.0, 0.35, 0.0, 0.28)},
		{"label": "MyLeftHudGroup", "control": _find("MyPortraitLeftHudGroup", true, false) as Control, "color": Color(1.0, 0.0, 0.55, 0.28)},
		{"label": "MyRightHudGroup", "control": _find("MyPortraitRightHudGroup", true, false) as Control, "color": Color(1.0, 0.55, 0.0, 0.28)},
		{"label": "OppBench", "control": _get("_opp_bench") as Control, "color": Color(0.55, 0.65, 1.0, 0.20)},
		{"label": "MyBench", "control": _get("_my_bench") as Control, "color": Color(0.1, 0.95, 0.6, 0.20)},
		{"label": "PortraitOppBenchGrid", "control": _get("_portrait_opp_bench_grid") as Control, "color": Color(0.4, 0.4, 1.0, 0.28)},
		{"label": "PortraitMyBenchGrid", "control": _get("_portrait_my_bench_grid") as Control, "color": Color(0.0, 1.0, 0.55, 0.28)},
		{"label": "OppActive", "control": _get("_opp_active") as Control, "color": Color(0.6, 0.6, 1.0, 0.25)},
		{"label": "MyActive", "control": _get("_my_active") as Control, "color": Color(0.0, 1.0, 0.2, 0.25)},
		{"label": "StadiumBar", "control": _node("MainArea/CenterField/FieldArea/StadiumBar") as Control, "color": Color(0.7, 1.0, 0.0, 0.24)},
		{"label": "StadiumCenter", "control": _get("_stadium_center_section") as Control, "color": Color(0.95, 1.0, 0.0, 0.28)},
		{"label": "TurnActionColumn", "control": _find("TurnActionColumn", true, false) as Control, "color": Color(0.0, 1.0, 0.75, 0.28)},
		{"label": "HudEndTurnBtn", "control": _get("_hud_end_turn_btn") as Control, "color": Color(0.0, 1.0, 0.9, 0.32)},
		{"label": "BtnBattleMore", "control": _get("_btn_battle_more") as Control, "color": Color(1.0, 0.8, 0.0, 0.30)},
		{"label": "BtnBack", "control": _get("_btn_back") as Control, "color": Color(1.0, 0.45, 0.0, 0.30)},
	]


func _add_portrait_layout_debug_rect_entry(entries: Array[Dictionary], label: String, rect: Rect2, color: Color) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	entries.append({"label": label, "rect": rect, "color": color})


func _add_portrait_layout_debug_rect(overlay: Control, rect: Rect2, label: String, color: Color) -> void:
	if overlay == null or rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var panel := PanelContainer.new()
	panel.name = "Debug_%s" % label.replace("/", "_").replace(" ", "_")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	panel.custom_minimum_size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, minf(maxf(color.a, 0.08), 0.30))
	style.border_color = Color(color.r, color.g, color.b, 0.96)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var caption := Label.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = "%s\np %.0f,%.0f\ns %.0fx%.0f" % [label, rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	caption.position = Vector2(4.0, 2.0)
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	caption.add_theme_constant_override("outline_size", 2)
	panel.add_child(caption)


func _write_portrait_layout_debug_snapshot(entries: Array[Dictionary], root_size: Vector2) -> void:
	var viewport_size: Vector2 = _scene.get_viewport_rect().size
	var lines: Array[String] = []
	lines.append("root %.0fx%.0f viewport %.0fx%.0f rotated=%s active_mode=%s" % [
		root_size.x,
		root_size.y,
		viewport_size.x,
		viewport_size.y,
		str(_as_bool(_get("_rotated_portrait_canvas_active"), false)),
		str(_get("_active_battle_layout_mode")),
	])
	for entry: Dictionary in entries:
		var rect: Rect2 = entry.get("rect", Rect2())
		lines.append("%s p=%.0f,%.0f s=%.0fx%.0f" % [
			str(entry.get("label", "")),
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
		])
	var signature := "\n".join(lines)
	if signature == _portrait_layout_debug_last_signature:
		return
	_portrait_layout_debug_last_signature = signature
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	var file := FileAccess.open(PORTRAIT_LAYOUT_DEBUG_LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(signature)
		file.close()


func _control_rect_in_battle_local(control: Control) -> Rect2:
	var rect_variant: Variant = _call("_control_rect_in_battle_local", [control])
	return rect_variant if rect_variant is Rect2 else Rect2()


func _format_vec2(value: Vector2) -> String:
	return "%.1fx%.1f" % [value.x, value.y]


func _format_rect(rect: Rect2) -> String:
	return "p=%.1f,%.1f s=%.1fx%.1f" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _scene_control_size() -> Vector2:
	var control := _scene as Control
	return control.size if control != null else Vector2.ZERO


func _node(path: NodePath) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(path)


func _find(pattern: String, recursive: bool, owned: bool) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.find_child(pattern, recursive, owned)


func _get(property_name: StringName) -> Variant:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get(property_name)


func _call(method_name: StringName, args: Array = []) -> Variant:
	if _scene == null or not is_instance_valid(_scene) or not _scene.has_method(method_name):
		return null
	return _scene.callv(method_name, args)


func _is_inside_tree() -> bool:
	return _scene != null and is_instance_valid(_scene) and _scene.is_inside_tree()


func _as_float(value: Variant, default_value: float = 0.0) -> float:
	if value is float or value is int:
		return float(value)
	return default_value


func _as_bool(value: Variant, default_value: bool = false) -> bool:
	if value == null:
		return default_value
	return bool(value)
