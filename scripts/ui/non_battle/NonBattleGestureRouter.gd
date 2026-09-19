extends RefCounted
## One touch owner for an entire workspace, including its outer scroll container.
## Mouse/trackpad events stay in Godot's native GUI pipeline.
const Bridge = preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const DEADZONE := 24.0
var _scope: Control
var _finger := -1
var _origin := Vector2.ZERO
var _scroll: Control
var _scroll_value := 0
var _button: Button
var _field: Control
var _range: Range
var _dragging := false
var _axis := ""
var _last_touch_msec := -10000

func cancel() -> void:
	_finger = -1
	_scroll = null
	_button = null
	_field = null
	_range = null
	_dragging = false
	_axis = ""

func handle(scope: Control, event: InputEvent) -> bool:
	if scope != _scope:
		cancel()
		_scope = scope
	if scope == null or not scope.is_visible_in_tree():
		cancel()
		return false
	if event is InputEventMouse:
		# A touch may generate a second mouse stream. Never suppress a real mouse.
		if event.device == -1 and Time.get_ticks_msec() - _last_touch_msec < 500:
			_accept(scope)
			return true
		return false
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false
	_last_touch_msec = Time.get_ticks_msec()
	_accept(scope)
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == _finger:
				cancel()
			return true
		if event.pressed:
			if _finger != -1:
				return true
			_finger = event.index
			_origin = event.position
			_scroll = Bridge.scroll_target_at_position(scope, _origin)
			_scroll_value = Bridge._scroll_target_vertical_value(_scroll) if _scroll != null else 0
			_button = Bridge.button_at_position(scope, _origin)
			_range = Bridge.range_at_position(scope, _origin)
			_field = Bridge.native_text_input_at_position(scope, _origin)
			if _field == null:
				_field = Bridge.focus_control_at_position(scope, _origin)
			return true
		if event.index != _finger:
			return true
		# Copy and clear before a signal can change scenes or open another modal.
		var button := _button
		var field := _field
		var range_control := _range
		var tap := not _dragging and _origin.distance_to(event.position) < DEADZONE
		if "--ptcgdap-ui-input-probe" in OS.get_cmdline_user_args():
			print("UI_COMPAT_GESTURE=" + JSON.stringify({
				"scope": str(scope.name), "dragged": _dragging,
				"scroll": str(_scroll.name) if is_instance_valid(_scroll) else "",
				"scroll_delta": Bridge._scroll_target_vertical_value(_scroll) - _scroll_value if is_instance_valid(_scroll) else 0,
				"button": str(button.name) if is_instance_valid(button) and tap else "",
			}))
		cancel()
		if tap:
			if is_instance_valid(button) and button == Bridge.button_at_position(scope, event.position) and not button.disabled:
				if button.toggle_mode:
					button.button_pressed = not button.button_pressed if button.button_group == null else true
				if button is OptionButton:
					Bridge._emit_button_pressed(button)
				else:
					button.pressed.emit()
			elif is_instance_valid(field) and Bridge._control_has_point(field, event.position):
				if bool(field.get_meta(Bridge.NATIVE_TEXT_INPUT_META, false)):
					Bridge._focus_native_text_input_from_pointer(field)
					if Bridge.WebTextInputBridgeScript.is_web_runtime():
						Bridge.request_web_text_input(field)
				else:
					Bridge._focus_control(field)
			elif is_instance_valid(range_control):
				Bridge._set_range_value_from_position(range_control, event.position)
		return true
	if event.index != _finger:
		return true
	var delta: Vector2 = event.position - _origin
	if not _dragging:
		if delta.length() < DEADZONE:
			return true
		_dragging = true
		_axis = "vertical" if absf(delta.y) >= absf(delta.x) else "horizontal"
	if _axis == "vertical" and is_instance_valid(_scroll) and not (_range is VSlider or _range is VScrollBar):
		Bridge._set_scroll_target_vertical_value(_scroll, _scroll_value - roundi(delta.y))
	elif is_instance_valid(_range):
		Bridge._set_range_value_from_position(_range, event.position)
	return true

func _accept(scope: Control) -> void:
	scope.get_viewport().set_input_as_handled()
