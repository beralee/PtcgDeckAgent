class_name DesktopDisplayController
extends Node

signal display_metrics_changed

const SETTINGS_PATH := "user://desktop_display.json"
const DESIGN_SIZE := Vector2i(1600, 900)
const USER_SCALES := [80, 100, 125, 150]
const SAVE_DELAY_MSEC := 500

var user_scale_percent := 100
var _root: Window
var _initialized := false
var _normal_size := Vector2i.ZERO
var _normal_position := Vector2i.ZERO
var _last_size := Vector2i.ZERO
var _last_mode := -1
var _last_screen := -1
var _last_dpi := -1
var _save_at_msec := 0


static func system_scale_for_dpi(dpi: int) -> float:
	return float(dpi) / 96.0 if dpi > 0 else 1.0


static func initial_window_size(design_size: Vector2i, dpi: int, usable_size: Vector2i) -> Vector2i:
	var desired := Vector2(design_size) * system_scale_for_dpi(dpi)
	if usable_size.x <= 0 or usable_size.y <= 0:
		return Vector2i(desired.round())
	var limit := Vector2(usable_size) * 0.9
	var fit := minf(1.0, minf(limit.x / desired.x, limit.y / desired.y))
	return Vector2i((desired * fit).round())


static func visible_window_rect(saved_position: Vector2i, saved_size: Vector2i, usable: Rect2i) -> Rect2i:
	var size := Vector2i(
		clampi(saved_size.x, mini(640, maxi(1, usable.size.x)), maxi(1, usable.size.x)),
		clampi(saved_size.y, mini(360, maxi(1, usable.size.y)), maxi(1, usable.size.y))
	)
	var position := Vector2i(
		clampi(saved_position.x, usable.position.x, usable.end.x - size.x),
		clampi(saved_position.y, usable.position.y, usable.end.y - size.y)
	)
	return Rect2i(position, size)


static func effective_ui_scale(dpi: int, percent: int, window_size: Vector2i) -> float:
	var wanted := system_scale_for_dpi(dpi) * float(percent) / 100.0
	var fit := minf(float(window_size.x) / 900.0, float(window_size.y) / 520.0)
	return maxf(0.5, minf(wanted, fit))


func initialize(root: Window) -> void:
	if _initialized or root == null:
		return
	_root = root
	var saved := _load_settings()
	user_scale_percent = int(saved.get("ui_scale_percent", 100))
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var dpi := DisplayServer.screen_get_dpi(screen)
	var saved_size := _read_vector(saved.get("normal_size", null))
	var saved_position := _read_vector(saved.get("normal_position", null))
	if saved_position.x != -2147483648 and saved_size.x > 0 and saved_size.y > 0:
		for candidate: int in DisplayServer.get_screen_count():
			var candidate_rect := DisplayServer.screen_get_usable_rect(candidate)
			if candidate_rect.has_point(saved_position + saved_size / 2):
				screen = candidate
				usable = candidate_rect
				dpi = DisplayServer.screen_get_dpi(candidate)
				break
	if saved_size.x <= 0 or saved_size.y <= 0 or saved_position.x == -2147483648:
		_normal_size = initial_window_size(DESIGN_SIZE, dpi, usable.size)
		_normal_position = usable.position + (usable.size - _normal_size) / 2
	else:
		var rect := visible_window_rect(saved_position, saved_size, usable)
		_normal_size = rect.size
		_normal_position = rect.position
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_normal_size)
	DisplayServer.window_set_position(_normal_position)
	if bool(saved.get("maximized", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	_root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_initialized = true
	_sample_window()
	_apply_scale(true)


func _process(_delta: float) -> void:
	if not _initialized:
		return
	_sample_window()
	if _save_at_msec > 0 and Time.get_ticks_msec() >= _save_at_msec:
		_save_at_msec = 0
		_save_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _initialized:
		_sample_window()
		_save_settings()


func _exit_tree() -> void:
	if _initialized:
		_sample_window()
		_save_settings()


func set_user_scale(percent: int) -> void:
	if not USER_SCALES.has(percent):
		return
	if user_scale_percent == percent:
		return
	user_scale_percent = percent
	_apply_scale(true)
	_schedule_save()


func restore_default() -> void:
	set_user_scale(100)


func _sample_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var dpi := DisplayServer.screen_get_dpi(screen)
	var size := DisplayServer.window_get_size()
	var position := DisplayServer.window_get_position()
	var mode := DisplayServer.window_get_mode()
	if screen != _last_screen and mode == DisplayServer.WINDOW_MODE_WINDOWED and not _window_intersects_any_screen(position, size):
		var rescued := visible_window_rect(position, size, DisplayServer.screen_get_usable_rect(screen))
		DisplayServer.window_set_size(rescued.size)
		DisplayServer.window_set_position(rescued.position)
		size = rescued.size
		position = rescued.position
	if screen != _last_screen or dpi != _last_dpi or size != _last_size:
		_last_screen = screen
		_last_dpi = dpi
		_last_size = size
		_apply_scale(true)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		if size != _normal_size or position != _normal_position:
			_normal_size = size
			_normal_position = position
			_schedule_save()
	if mode != _last_mode:
		_last_mode = mode
		_schedule_save()


func _window_intersects_any_screen(position: Vector2i, size: Vector2i) -> bool:
	var rect := Rect2i(position, size)
	for screen: int in DisplayServer.get_screen_count():
		var overlap := rect.intersection(DisplayServer.screen_get_usable_rect(screen))
		if overlap.size.x >= 64 and overlap.size.y >= 64:
			return true
	return false


func _apply_scale(force_notify: bool = false) -> void:
	if _root == null:
		return
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return
	# Keep a usable logical area when an old saved window is moved to a denser screen.
	var actual := effective_ui_scale(DisplayServer.screen_get_dpi(DisplayServer.window_get_current_screen()), user_scale_percent, window_size)
	var changed := _root.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS or _root.content_scale_size != window_size or not is_equal_approx(_root.content_scale_factor, actual)
	_root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_root.content_scale_size = window_size
	_root.content_scale_factor = actual
	if changed or force_notify:
		display_metrics_changed.emit()


func _schedule_save() -> void:
	_save_at_msec = Time.get_ticks_msec() + SAVE_DELAY_MSEC


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"ui_scale_percent": user_scale_percent,
		"normal_size": [_normal_size.x, _normal_size.y],
		"normal_position": [_normal_position.x, _normal_position.y],
		"maximized": _last_mode == DisplayServer.WINDOW_MODE_MAXIMIZED,
	}))
	file.close()


func _load_settings() -> Dictionary:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return {}
	if not USER_SCALES.has(int(parsed.get("ui_scale_percent", 100))):
		return {}
	return parsed


func _read_vector(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i(-2147483648, -2147483648)
	if not (value[0] is int or value[0] is float) or not (value[1] is int or value[1] is float):
		return Vector2i(-2147483648, -2147483648)
	return Vector2i(int(value[0]), int(value[1]))
