class_name NonBattleTouchBridge
extends RefCounted

const WebTextInputBridgeScript := preload("res://scripts/ui/non_battle/WebTextInputBridge.gd")

const TOUCH_CANDIDATE_META := "_non_battle_touch_button_candidate"
const TOUCH_DRAG_START_META := "_non_battle_touch_drag_start"
const RANGE_CANDIDATE_META := "_non_battle_touch_range_candidate"
const FOCUS_CANDIDATE_META := "_non_battle_touch_focus_candidate"
const FOCUS_REQUESTED_META := "_non_battle_touch_focus_requested"
const SCROLL_CANDIDATE_META := "_non_battle_touch_scroll_candidate"
const SCROLL_DRAG_START_VALUE_META := "_non_battle_touch_scroll_start_value"
const SCROLL_DRAG_ACTIVE_META := "_non_battle_touch_scroll_drag_active"
const TOUCH_DRAG_CANCEL_DISTANCE := 24.0
const SCROLL_DRAG_START_DISTANCE := 10.0
const SCROLL_DRAG_SENSITIVITY := 1.35
const BUTTON_TOUCH_BOUND_META := "_non_battle_touch_bound"
const BUTTON_TOUCH_PRESSED_META := "_non_battle_touch_pressed"
const BUTTON_LAST_BRIDGE_PRESS_MSEC_META := "_non_battle_last_bridge_press_msec"
const BUTTON_BRIDGE_DUPLICATE_SUPPRESS_MSEC := 180
const BUTTON_RELEASE_AFTER_SCROLL_SUPPRESS_MSEC := 220
const OPTION_PRESS_SIGNAL_ONLY_META := "_non_battle_option_press_signal_only"
const OPTION_POPUP_BOUNDS_META := "_non_battle_popup_bounds"
const FOCUS_TOUCH_BOUND_META := "_non_battle_focus_touch_bound"
const FOCUS_TOUCH_PRESSED_META := "_non_battle_focus_touch_pressed"
const NATIVE_TEXT_INPUT_META := "_non_battle_native_text_input"
const NATIVE_TEXT_INPUT_CANDIDATE_META := "_non_battle_native_text_input_candidate"
const RANGE_TOUCH_BOUND_META := "_non_battle_range_touch_bound"
const RANGE_TOUCH_ACTIVE_META := "_non_battle_range_touch_active"
const HIDDEN_VERTICAL_DRAG_SCROLL_META := "_non_battle_hidden_vertical_drag_scroll"
const HIDDEN_VERTICAL_DRAG_SCROLLABLE_CONTROL_META := "_non_battle_hidden_vertical_drag_scrollable_control"
const HIDDEN_SCROLLBAR_META := "_non_battle_hidden_scrollbar"
const TOUCH_BRIDGE_ENABLED_META := "_non_battle_touch_bridge_enabled"

static var _last_scroll_drag_release_msec := -1000000


static func set_test_web_text_input_enabled(enabled: bool) -> void:
	WebTextInputBridgeScript.set_test_force_web(enabled)


static func reset_test_web_text_input_state() -> void:
	WebTextInputBridgeScript.reset_test_state()


static func get_test_web_text_input_request_count() -> int:
	return WebTextInputBridgeScript.get_test_request_count()


static func get_test_web_text_input_last_payload() -> Dictionary:
	return WebTextInputBridgeScript.get_test_last_payload()


static func request_test_web_text_input(control: Control) -> bool:
	return WebTextInputBridgeScript.request_focus(control)


static func commit_test_web_text_input_value(value: String, finished: bool = true) -> void:
	WebTextInputBridgeScript.commit_active_value(value, finished)


static func set_touch_bridge_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	node.set_meta(TOUCH_BRIDGE_ENABLED_META, enabled)


static func is_touch_bridge_enabled_for(node: Node) -> bool:
	var current := node
	while current != null:
		if current.has_meta(TOUCH_BRIDGE_ENABLED_META):
			return bool(current.get_meta(TOUCH_BRIDGE_ENABLED_META, true))
		current = current.get_parent()
	return true


static func handle_root_touch(host: Control, event: InputEvent) -> bool:
	if host == null:
		return false
	if not is_touch_bridge_enabled_for(host):
		_clear_host_touch_state(host)
		return false
	if event is InputEventMouseButton:
		return _handle_mouse_button(host, event as InputEventMouseButton)
	if event is InputEventScreenDrag:
		if not _should_bridge_screen_touch():
			return false
		if _should_bypass_bridge_for_native_text_input(host, (event as InputEventScreenDrag).position, false, false):
			return false
		if _handle_range_drag(host, (event as InputEventScreenDrag).position):
			return true
		if _handle_scroll_drag(host, (event as InputEventScreenDrag).position):
			return true
		return _handle_drag(host, event as InputEventScreenDrag)
	if not (event is InputEventScreenTouch):
		return false
	if not _should_bridge_screen_touch():
		return false
	var touch := event as InputEventScreenTouch
	if _should_bypass_bridge_for_native_text_input(host, touch.position, touch.pressed, not touch.pressed):
		return false
	if touch.pressed:
		var range := range_at_position(host, touch.position)
		if range != null:
			_store_range_candidate(host, range)
			_set_range_value_from_position(range, touch.position)
			_accept_event(host)
			return true
		var button := button_at_position(host, touch.position)
		_store_candidate(host, button, touch.position)
		if button != null:
			_store_scroll_candidate(host, scroll_target_at_position(host, touch.position), touch.position)
			_accept_event(host)
			return true
		var focus_control := focus_control_at_position(host, touch.position)
		if focus_control != null:
			_store_focus_candidate(host, focus_control, touch.position)
			_store_scroll_candidate(host, scroll_target_at_position(host, touch.position), touch.position)
			_accept_event(host)
			return true
		var scroll_target := scroll_target_at_position(host, touch.position)
		if scroll_target != null:
			_store_scroll_candidate(host, scroll_target, touch.position)
			_accept_event(host)
			return true
		return false

	if host.has_meta(RANGE_CANDIDATE_META):
		var release_range := host.get_meta(RANGE_CANDIDATE_META) as Range
		_clear_range_candidate(host)
		if release_range != null:
			_set_range_value_from_position(release_range, touch.position)
			_accept_event(host)
			return true
	var release_only_range := range_at_position(host, touch.position)
	if release_only_range != null:
		_set_range_value_from_position(release_only_range, touch.position)
		_accept_event(host)
		return true
	if _handle_scroll_release(host):
		return true
	if host.has_meta(FOCUS_CANDIDATE_META):
		var release_focus := host.get_meta(FOCUS_CANDIDATE_META) as Control
		_clear_focus_candidate(host)
		var focus_at_release := focus_control_at_position(host, touch.position)
		if release_focus != null and release_focus == focus_at_release:
			_focus_control(release_focus)
			_accept_event(host)
			return true
	var button_at_release := button_at_position(host, touch.position)
	var candidate := host.get_meta(TOUCH_CANDIDATE_META) as Button if host.has_meta(TOUCH_CANDIDATE_META) else null
	if candidate != null or button_at_release != null:
		_clear_candidate(host)
		if candidate == null:
			candidate = button_at_release
		if candidate == null or candidate != button_at_release:
			return false
		if candidate.disabled:
			return false
		if candidate.is_inside_tree() and not candidate.is_visible_in_tree():
			return false
		_emit_button_pressed(candidate)
		_accept_event(host)
		return true
	var release_only_focus := focus_control_at_position(host, touch.position)
	if release_only_focus != null:
		_focus_control(release_only_focus)
		_accept_event(host)
		return true
	return false


static func _handle_mouse_button(host: Control, mouse_button: InputEventMouseButton) -> bool:
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not _should_bridge_mouse_button_tap_echo():
		return false
	var pointer_position := mouse_button.global_position if mouse_button.global_position != Vector2.ZERO else mouse_button.position
	if _should_bypass_bridge_for_native_text_input(host, pointer_position, mouse_button.pressed, not mouse_button.pressed):
		return false
	if mouse_button.pressed:
		var range := range_at_position(host, pointer_position)
		if range != null:
			_store_range_candidate(host, range)
			_set_range_value_from_position(range, pointer_position)
			_accept_event(host)
			return true
		var button := button_at_position(host, pointer_position)
		_store_candidate(host, button, pointer_position)
		if button != null:
			_store_scroll_candidate(host, scroll_target_at_position(host, pointer_position), pointer_position)
			_accept_event(host)
			return true
		var focus_control := focus_control_at_position(host, pointer_position)
		if focus_control != null:
			_store_focus_candidate(host, focus_control, pointer_position)
			_store_scroll_candidate(host, scroll_target_at_position(host, pointer_position), pointer_position)
			_accept_event(host)
			return true
		var scroll_target := scroll_target_at_position(host, pointer_position)
		if scroll_target != null:
			_store_scroll_candidate(host, scroll_target, pointer_position)
			_accept_event(host)
			return true
		return false

	if host.has_meta(RANGE_CANDIDATE_META):
		var release_range := host.get_meta(RANGE_CANDIDATE_META) as Range
		_clear_range_candidate(host)
		if release_range != null:
			_set_range_value_from_position(release_range, pointer_position)
			_accept_event(host)
			return true
	var release_only_range := range_at_position(host, pointer_position)
	if release_only_range != null:
		_set_range_value_from_position(release_only_range, pointer_position)
		_accept_event(host)
		return true
	if _handle_scroll_release(host):
		return true
	if host.has_meta(FOCUS_CANDIDATE_META):
		var release_focus := host.get_meta(FOCUS_CANDIDATE_META) as Control
		_clear_focus_candidate(host)
		var focus_at_release := focus_control_at_position(host, pointer_position)
		if release_focus != null and release_focus == focus_at_release:
			_focus_control(release_focus)
			_accept_event(host)
			return true
	var button_at_release := button_at_position(host, pointer_position)
	var candidate := host.get_meta(TOUCH_CANDIDATE_META) as Button if host.has_meta(TOUCH_CANDIDATE_META) else null
	if candidate != null or button_at_release != null:
		_clear_candidate(host)
		if candidate == null:
			candidate = button_at_release
		if candidate == null or candidate != button_at_release:
			return false
		if candidate.disabled:
			return false
		if candidate.is_inside_tree() and not candidate.is_visible_in_tree():
			return false
		_emit_button_pressed(candidate)
		_accept_event(host)
		return true
	var release_only_focus := focus_control_at_position(host, pointer_position)
	if release_only_focus != null:
		_focus_control(release_only_focus)
		_accept_event(host)
		return true
	return false


static func _should_bridge_mouse_button_tap_echo() -> bool:
	if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		return true
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func _should_bridge_screen_touch() -> bool:
	if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		return true
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func button_at_position(host: Control, global_position: Vector2) -> Button:
	return _button_at_position_recursive(host, global_position)


static func range_at_position(host: Control, global_position: Vector2) -> Range:
	return _range_at_position_recursive(host, global_position)


static func focus_control_at_position(host: Control, global_position: Vector2) -> Control:
	return _focus_control_at_position_recursive(host, global_position)


static func native_text_input_at_position(host: Control, global_position: Vector2) -> Control:
	return _native_text_input_at_position_recursive(host, global_position)


static func scroll_container_at_position(host: Control, global_position: Vector2) -> ScrollContainer:
	return _scroll_container_at_position_recursive(host, global_position)


static func scroll_target_at_position(host: Control, global_position: Vector2) -> Control:
	return _scroll_target_at_position_recursive(host, global_position)


static func configure_hidden_vertical_drag_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.set_meta(HIDDEN_VERTICAL_DRAG_SCROLL_META, true)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_internal_scrollbar(scroll, "get_v_scroll_bar")
	_hide_internal_scrollbar(scroll, "get_h_scroll_bar")


static func configure_visible_vertical_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	if scroll.has_meta(HIDDEN_VERTICAL_DRAG_SCROLL_META):
		scroll.remove_meta(HIDDEN_VERTICAL_DRAG_SCROLL_META)
	var vbar := _internal_scrollbar(scroll, "get_v_scroll_bar")
	if vbar != null:
		if vbar.has_meta(HIDDEN_SCROLLBAR_META):
			vbar.remove_meta(HIDDEN_SCROLLBAR_META)
		vbar.visible = true
		vbar.mouse_filter = Control.MOUSE_FILTER_STOP
		vbar.set_deferred("visible", true)
		vbar.set_deferred("mouse_filter", Control.MOUSE_FILTER_STOP)


static func configure_hidden_vertical_drag_scrollable_control(control: Control) -> void:
	if control == null:
		return
	control.set_meta(HIDDEN_VERTICAL_DRAG_SCROLLABLE_CONTROL_META, true)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_internal_scrollbar(control, "get_v_scroll_bar")
	_hide_internal_scrollbar(control, "get_h_scroll_bar")


static func configure_visible_vertical_scrollable_control(control: Control) -> void:
	if control == null:
		return
	if control.has_meta(HIDDEN_VERTICAL_DRAG_SCROLLABLE_CONTROL_META):
		control.remove_meta(HIDDEN_VERTICAL_DRAG_SCROLLABLE_CONTROL_META)
	var vbar := _internal_scrollbar(control, "get_v_scroll_bar")
	if vbar != null:
		if vbar.has_meta(HIDDEN_SCROLLBAR_META):
			vbar.remove_meta(HIDDEN_SCROLLBAR_META)
		vbar.visible = true
		vbar.mouse_filter = Control.MOUSE_FILTER_STOP
		vbar.set_deferred("visible", true)
		vbar.set_deferred("mouse_filter", Control.MOUSE_FILTER_STOP)


static func bind_buttons_recursive(node: Node) -> void:
	if node is Button:
		bind_button_touch(node as Button)
	elif node is Range and not node is SpinBox:
		bind_range_touch(node as Range)
	elif (node is LineEdit or node is TextEdit or node is SpinBox) and not bool((node as Control).get_meta(NATIVE_TEXT_INPUT_META, false)):
		bind_focus_control_touch(node as Control)
	for child: Node in node.get_children():
		bind_buttons_recursive(child)


static func mark_native_text_input(control: Control) -> void:
	if control == null:
		return
	control.set_meta(NATIVE_TEXT_INPUT_META, true)


static func configure_native_line_edit(input: LineEdit, keyboard_type: int = LineEdit.KEYBOARD_TYPE_DEFAULT) -> void:
	if input == null:
		return
	input.focus_mode = Control.FOCUS_ALL
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.context_menu_enabled = true
	input.virtual_keyboard_enabled = true
	input.virtual_keyboard_show_on_focus = true
	input.virtual_keyboard_type = keyboard_type
	input.set("shortcut_keys_enabled", true)
	input.set("middle_mouse_paste_enabled", true)
	mark_native_text_input(input)
	if input.has_meta(FOCUS_TOUCH_BOUND_META):
		input.remove_meta(FOCUS_TOUCH_BOUND_META)


static func bind_button_touch(button: Button) -> void:
	if button == null or bool(button.get_meta(BUTTON_TOUCH_BOUND_META, false)):
		return
	button.set_meta(BUTTON_TOUCH_BOUND_META, true)
	button.gui_input.connect(func(event: InputEvent) -> void:
		handle_button_touch(button, event)
	)


static func bind_range_touch(range_control: Range) -> void:
	if range_control == null or bool(range_control.get_meta(RANGE_TOUCH_BOUND_META, false)):
		return
	if not range_control is Control:
		return
	range_control.set_meta(RANGE_TOUCH_BOUND_META, true)
	(range_control as Control).gui_input.connect(func(event: InputEvent) -> void:
		handle_range_touch(range_control, event)
	)


static func handle_range_touch(range_control: Range, event: InputEvent) -> bool:
	if range_control == null or not range_control is Control:
		return false
	var control := range_control as Control
	if not is_touch_bridge_enabled_for(control):
		if range_control.has_meta(RANGE_TOUCH_ACTIVE_META):
			range_control.remove_meta(RANGE_TOUCH_ACTIVE_META)
		return false
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if not _should_bridge_mouse_button_tap_echo():
			return false
		var position := _event_position_for_control(control, event)
		if mouse_button.pressed:
			range_control.set_meta(RANGE_TOUCH_ACTIVE_META, true)
			_set_range_value_from_position(range_control, position)
			_accept_event(control)
			return true
		if bool(range_control.get_meta(RANGE_TOUCH_ACTIVE_META, false)):
			range_control.remove_meta(RANGE_TOUCH_ACTIVE_META)
			_set_range_value_from_position(range_control, position)
			_accept_event(control)
			return true
		return false
	if event is InputEventMouseMotion:
		if not bool(range_control.get_meta(RANGE_TOUCH_ACTIVE_META, false)):
			return false
		_set_range_value_from_position(range_control, _event_position_for_control(control, event))
		_accept_event(control)
		return true
	if event is InputEventScreenTouch:
		if not _should_bridge_screen_touch():
			return false
		var touch := event as InputEventScreenTouch
		var position := _event_position_for_control(control, event)
		if touch.pressed:
			range_control.set_meta(RANGE_TOUCH_ACTIVE_META, true)
			_set_range_value_from_position(range_control, position)
			_accept_event(control)
			return true
		if bool(range_control.get_meta(RANGE_TOUCH_ACTIVE_META, false)):
			range_control.remove_meta(RANGE_TOUCH_ACTIVE_META)
			_set_range_value_from_position(range_control, position)
			_accept_event(control)
			return true
		return false
	if event is InputEventScreenDrag:
		if not _should_bridge_screen_touch() or not bool(range_control.get_meta(RANGE_TOUCH_ACTIVE_META, false)):
			return false
		_set_range_value_from_position(range_control, _event_position_for_control(control, event))
		_accept_event(control)
		return true
	return false


static func handle_button_touch(button: Button, event: InputEvent) -> bool:
	if button == null:
		return false
	if not is_touch_bridge_enabled_for(button):
		if button.has_meta(BUTTON_TOUCH_PRESSED_META):
			button.remove_meta(BUTTON_TOUCH_PRESSED_META)
		return false
	if event is InputEventMouseButton:
		return _handle_bound_mouse_button(button, event as InputEventMouseButton)
	if event is InputEventScreenDrag:
		if not _should_bridge_screen_touch():
			return false
		if button.has_meta(BUTTON_TOUCH_PRESSED_META):
			button.remove_meta(BUTTON_TOUCH_PRESSED_META)
		return false
	if not (event is InputEventScreenTouch):
		return false
	if not _should_bridge_screen_touch():
		return false
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		button.set_meta(BUTTON_TOUCH_PRESSED_META, true)
		_accept_event(button)
		return true
	var had_pressed_meta := button.has_meta(BUTTON_TOUCH_PRESSED_META)
	if had_pressed_meta:
		button.remove_meta(BUTTON_TOUCH_PRESSED_META)
	elif _should_suppress_release_after_scroll():
		_accept_event(button)
		return true
	if button.disabled:
		return false
	if button.is_inside_tree() and not button.is_visible_in_tree():
		return false
	_emit_button_pressed(button)
	_accept_event(button)
	return true


static func bind_focus_control_touch(control: Control) -> void:
	if control == null or bool(control.get_meta(FOCUS_TOUCH_BOUND_META, false)):
		return
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(FOCUS_TOUCH_BOUND_META, true)
	control.gui_input.connect(func(event: InputEvent) -> void:
		handle_focus_control_touch(control, event)
	)


static func handle_focus_control_touch(control: Control, event: InputEvent) -> bool:
	if control == null:
		return false
	if not is_touch_bridge_enabled_for(control):
		if control.has_meta(FOCUS_TOUCH_PRESSED_META):
			control.remove_meta(FOCUS_TOUCH_PRESSED_META)
		return false
	if bool(control.get_meta(NATIVE_TEXT_INPUT_META, false)):
		return false
	if event is InputEventMouseButton:
		return _handle_bound_focus_mouse_button(control, event as InputEventMouseButton)
	if event is InputEventScreenDrag:
		if control.has_meta(FOCUS_TOUCH_PRESSED_META):
			control.remove_meta(FOCUS_TOUCH_PRESSED_META)
		return false
	if not (event is InputEventScreenTouch):
		return false
	if not _should_bridge_screen_touch():
		return false
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		control.set_meta(FOCUS_TOUCH_PRESSED_META, true)
		if _focusable_control_is_available(control):
			_focus_control(control)
		_accept_event(control)
		return true
	if control.has_meta(FOCUS_TOUCH_PRESSED_META):
		control.remove_meta(FOCUS_TOUCH_PRESSED_META)
	if not _focusable_control_is_available(control):
		return false
	_focus_control(control)
	_accept_event(control)
	return true


static func _handle_bound_mouse_button(button: Button, mouse_button: InputEventMouseButton) -> bool:
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not _should_bridge_mouse_button_tap_echo():
		return false
	if mouse_button.pressed:
		button.set_meta(BUTTON_TOUCH_PRESSED_META, true)
		_accept_event(button)
		return true
	var had_pressed_meta := button.has_meta(BUTTON_TOUCH_PRESSED_META)
	if had_pressed_meta:
		button.remove_meta(BUTTON_TOUCH_PRESSED_META)
	elif _should_suppress_release_after_scroll():
		_accept_event(button)
		return true
	if button.disabled:
		return false
	if button.is_inside_tree() and not button.is_visible_in_tree():
		return false
	_emit_button_pressed(button)
	_accept_event(button)
	return true


static func _handle_bound_focus_mouse_button(control: Control, mouse_button: InputEventMouseButton) -> bool:
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not _should_bridge_mouse_button_tap_echo():
		return false
	if mouse_button.pressed:
		control.set_meta(FOCUS_TOUCH_PRESSED_META, true)
		if _focusable_control_is_available(control):
			_focus_control(control)
		_accept_event(control)
		return true
	if control.has_meta(FOCUS_TOUCH_PRESSED_META):
		control.remove_meta(FOCUS_TOUCH_PRESSED_META)
	if not _focusable_control_is_available(control):
		return false
	_focus_control(control)
	_accept_event(control)
	return true


static func emit_button_pressed_once(button: Button) -> bool:
	return _emit_button_pressed(button)


static func _emit_button_pressed(button: Button) -> bool:
	var now := Time.get_ticks_msec()
	var previous := int(button.get_meta(BUTTON_LAST_BRIDGE_PRESS_MSEC_META, -1000000))
	if now - previous >= 0 and now - previous < BUTTON_BRIDGE_DUPLICATE_SUPPRESS_MSEC:
		return false
	button.set_meta(BUTTON_LAST_BRIDGE_PRESS_MSEC_META, now)
	if button is OptionButton:
		if bool(button.get_meta(OPTION_PRESS_SIGNAL_ONLY_META, false)):
			button.pressed.emit()
			return true
		_show_option_button_popup(button as OptionButton)
		return true
	button.pressed.emit()
	return true


static func _handle_drag(host: Control, drag: InputEventScreenDrag) -> bool:
	var candidate := host.get_meta(TOUCH_CANDIDATE_META) as Button if host.has_meta(TOUCH_CANDIDATE_META) else null
	var focus_candidate := host.get_meta(FOCUS_CANDIDATE_META) as Control if host.has_meta(FOCUS_CANDIDATE_META) else null
	if candidate == null and focus_candidate == null:
		return false
	var start_position: Vector2 = host.get_meta(TOUCH_DRAG_START_META) if host.has_meta(TOUCH_DRAG_START_META) else drag.position
	if start_position.distance_to(drag.position) > TOUCH_DRAG_CANCEL_DISTANCE:
		_clear_candidate(host)
		_clear_focus_candidate(host)
		return false
	_accept_event(host)
	return true


static func _should_bypass_bridge_for_native_text_input(host: Control, position: Vector2, pressed: bool, released: bool) -> bool:
	if host == null:
		return false
	if pressed:
		var native_input := native_text_input_at_position(host, position)
		if native_input == null:
			if host.has_meta(NATIVE_TEXT_INPUT_CANDIDATE_META):
				_clear_native_text_input_candidate(host)
			return false
		if WebTextInputBridgeScript.is_web_runtime():
			_store_native_text_input_candidate(host, native_input)
			WebTextInputBridgeScript.request_focus(native_input)
			_accept_event(host)
			return true
		_store_native_text_input_candidate(host, native_input)
		return true
	if host.has_meta(NATIVE_TEXT_INPUT_CANDIDATE_META):
		if released:
			var release_native_input := host.get_meta(NATIVE_TEXT_INPUT_CANDIDATE_META) as Control
			if release_native_input != null and WebTextInputBridgeScript.is_web_runtime():
				WebTextInputBridgeScript.request_focus(release_native_input)
				_accept_event(host)
			_clear_native_text_input_candidate(host)
		return true
	var hover_native_input := native_text_input_at_position(host, position)
	if hover_native_input != null:
		if WebTextInputBridgeScript.is_web_runtime():
			WebTextInputBridgeScript.request_focus(hover_native_input)
			_accept_event(host)
		return true
	return false


static func _handle_range_drag(host: Control, position: Vector2) -> bool:
	if not host.has_meta(RANGE_CANDIDATE_META):
		return false
	var range := host.get_meta(RANGE_CANDIDATE_META) as Range
	if range == null:
		_clear_range_candidate(host)
		return false
	_set_range_value_from_position(range, position)
	_accept_event(host)
	return true


static func _handle_scroll_drag(host: Control, position: Vector2) -> bool:
	if not host.has_meta(SCROLL_CANDIDATE_META):
		return false
	var scroll_target := host.get_meta(SCROLL_CANDIDATE_META) as Control
	if scroll_target == null:
		_clear_scroll_candidate(host)
		return false
	var start_position: Vector2 = host.get_meta(TOUCH_DRAG_START_META) if host.has_meta(TOUCH_DRAG_START_META) else position
	var drag_delta := position - start_position
	var active := bool(host.get_meta(SCROLL_DRAG_ACTIVE_META)) if host.has_meta(SCROLL_DRAG_ACTIVE_META) else false
	if not active and drag_delta.length() < SCROLL_DRAG_START_DISTANCE:
		_accept_event(host)
		return true
	host.set_meta(SCROLL_DRAG_ACTIVE_META, true)
	_clear_candidate(host)
	_clear_focus_candidate(host)
	var start_value := int(host.get_meta(SCROLL_DRAG_START_VALUE_META, _scroll_target_vertical_value(scroll_target)))
	var scroll_delta := (start_position.y - position.y) * SCROLL_DRAG_SENSITIVITY
	_set_scroll_target_vertical_value(scroll_target, roundi(float(start_value) + scroll_delta))
	_accept_event(host)
	return true


static func _handle_scroll_release(host: Control) -> bool:
	if not host.has_meta(SCROLL_CANDIDATE_META):
		return false
	var active := bool(host.get_meta(SCROLL_DRAG_ACTIVE_META)) if host.has_meta(SCROLL_DRAG_ACTIVE_META) else false
	var has_button_candidate := host.has_meta(TOUCH_CANDIDATE_META)
	var has_focus_candidate := host.has_meta(FOCUS_CANDIDATE_META)
	_clear_scroll_candidate(host)
	if active:
		_last_scroll_drag_release_msec = Time.get_ticks_msec()
		_clear_candidate(host)
		_clear_focus_candidate(host)
		_accept_event(host)
		return true
	if not has_button_candidate and not has_focus_candidate:
		_accept_event(host)
		return true
	return false


static func _should_suppress_release_after_scroll() -> bool:
	var elapsed := Time.get_ticks_msec() - _last_scroll_drag_release_msec
	return elapsed >= 0 and elapsed < BUTTON_RELEASE_AFTER_SCROLL_SUPPRESS_MSEC


static func _store_candidate(host: Control, button: Button, position: Vector2) -> void:
	if button == null:
		_clear_candidate(host)
		return
	host.set_meta(TOUCH_CANDIDATE_META, button)
	host.set_meta(TOUCH_DRAG_START_META, position)


static func _store_range_candidate(host: Control, range: Range) -> void:
	if range == null:
		_clear_range_candidate(host)
		return
	host.set_meta(RANGE_CANDIDATE_META, range)


static func _store_scroll_candidate(host: Control, scroll_target: Control, position: Vector2) -> void:
	if scroll_target == null or not _scroll_target_can_scroll_vertically(scroll_target):
		_clear_scroll_candidate(host)
		return
	host.set_meta(SCROLL_CANDIDATE_META, scroll_target)
	host.set_meta(TOUCH_DRAG_START_META, position)
	host.set_meta(SCROLL_DRAG_START_VALUE_META, _scroll_target_vertical_value(scroll_target))
	host.set_meta(SCROLL_DRAG_ACTIVE_META, false)


static func _store_focus_candidate(host: Control, control: Control, position: Vector2) -> void:
	if control == null:
		_clear_focus_candidate(host)
		return
	host.set_meta(FOCUS_CANDIDATE_META, control)
	host.set_meta(TOUCH_DRAG_START_META, position)


static func _store_native_text_input_candidate(host: Control, control: Control) -> void:
	_clear_candidate(host)
	_clear_range_candidate(host)
	_clear_scroll_candidate(host)
	_clear_focus_candidate(host)
	host.set_meta(NATIVE_TEXT_INPUT_CANDIDATE_META, control)


static func _clear_candidate(host: Control) -> void:
	if host.has_meta(TOUCH_CANDIDATE_META):
		host.remove_meta(TOUCH_CANDIDATE_META)
	if host.has_meta(TOUCH_DRAG_START_META) and not host.has_meta(SCROLL_CANDIDATE_META):
		host.remove_meta(TOUCH_DRAG_START_META)


static func _clear_range_candidate(host: Control) -> void:
	if host.has_meta(RANGE_CANDIDATE_META):
		host.remove_meta(RANGE_CANDIDATE_META)


static func _clear_scroll_candidate(host: Control) -> void:
	if host.has_meta(SCROLL_CANDIDATE_META):
		host.remove_meta(SCROLL_CANDIDATE_META)
	if host.has_meta(SCROLL_DRAG_START_VALUE_META):
		host.remove_meta(SCROLL_DRAG_START_VALUE_META)
	if host.has_meta(SCROLL_DRAG_ACTIVE_META):
		host.remove_meta(SCROLL_DRAG_ACTIVE_META)
	if not host.has_meta(TOUCH_CANDIDATE_META) and not host.has_meta(FOCUS_CANDIDATE_META) and host.has_meta(TOUCH_DRAG_START_META):
		host.remove_meta(TOUCH_DRAG_START_META)


static func _clear_focus_candidate(host: Control) -> void:
	if host.has_meta(FOCUS_CANDIDATE_META):
		host.remove_meta(FOCUS_CANDIDATE_META)
	if not host.has_meta(TOUCH_CANDIDATE_META) and not host.has_meta(SCROLL_CANDIDATE_META) and host.has_meta(TOUCH_DRAG_START_META):
		host.remove_meta(TOUCH_DRAG_START_META)


static func _clear_native_text_input_candidate(host: Control) -> void:
	if host.has_meta(NATIVE_TEXT_INPUT_CANDIDATE_META):
		host.remove_meta(NATIVE_TEXT_INPUT_CANDIDATE_META)


static func _clear_host_touch_state(host: Control) -> void:
	_clear_candidate(host)
	_clear_range_candidate(host)
	_clear_scroll_candidate(host)
	_clear_focus_candidate(host)
	_clear_native_text_input_candidate(host)


static func _button_at_position_recursive(node: Node, global_position: Vector2) -> Button:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_button := _button_at_position_recursive(child, global_position)
		if child_button != null:
			return child_button
	if not (node is Button):
		return null
	var button := node as Button
	if button.disabled or not button.visible:
		return null
	if button.is_inside_tree() and not button.is_visible_in_tree():
		return null
	return button if _control_has_point(button, global_position) else null


static func _range_at_position_recursive(node: Node, global_position: Vector2) -> Range:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_range := _range_at_position_recursive(child, global_position)
		if child_range != null:
			return child_range
	if node is ScrollContainer:
		var scroll := node as ScrollContainer
		var vbar := scroll.get_v_scroll_bar()
		if vbar != null and vbar.visible and _control_has_point(vbar, global_position):
			return vbar
		var hbar := scroll.get_h_scroll_bar()
		if hbar != null and hbar.visible and _control_has_point(hbar, global_position):
			return hbar
	if not (node is Range) or node is SpinBox:
		return null
	if not (node is Control):
		return null
	var control := node as Control
	if not control.visible:
		return null
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return null
	return node as Range if _control_has_point(control, global_position) else null


static func _focus_control_at_position_recursive(node: Node, global_position: Vector2) -> Control:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_control := _focus_control_at_position_recursive(child, global_position)
		if child_control != null:
			return child_control
	if not (node is LineEdit or node is TextEdit or node is SpinBox):
		return null
	var control := node as Control
	if control == null or not control.visible:
		return null
	if bool(control.get_meta(NATIVE_TEXT_INPUT_META, false)):
		return null
	if control is LineEdit and not (control as LineEdit).editable:
		return null
	if control is TextEdit and not (control as TextEdit).editable:
		return null
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return null
	return control if _control_has_point(control, global_position) else null


static func _native_text_input_at_position_recursive(node: Node, global_position: Vector2) -> Control:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_control := _native_text_input_at_position_recursive(child, global_position)
		if child_control != null:
			return child_control
	if not (node is Control):
		return null
	var control := node as Control
	if not bool(control.get_meta(NATIVE_TEXT_INPUT_META, false)):
		return null
	if not (control is LineEdit or control is TextEdit):
		return null
	if not control.visible:
		return null
	if control is LineEdit and not (control as LineEdit).editable:
		return null
	if control is TextEdit and not (control as TextEdit).editable:
		return null
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return null
	return control if _control_has_point(control, global_position) else null


static func _scroll_container_at_position_recursive(node: Node, global_position: Vector2) -> ScrollContainer:
	var target := _scroll_target_at_position_recursive(node, global_position)
	if target is ScrollContainer:
		return target as ScrollContainer
	return null


static func _scroll_target_at_position_recursive(node: Node, global_position: Vector2) -> Control:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_scroll_target := _scroll_target_at_position_recursive(child, global_position)
		if child_scroll_target != null:
			return child_scroll_target
	if not (node is Control):
		return null
	var control := node as Control
	if not control.visible:
		return null
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return null
	if not _scroll_target_can_scroll_vertically(control):
		return null
	return control if _control_has_point(control, global_position) else null


static func _scroll_container_can_scroll_vertically(scroll: ScrollContainer) -> bool:
	return _scroll_target_can_scroll_vertically(scroll)


static func _scroll_target_can_scroll_vertically(control: Control) -> bool:
	if control == null:
		return false
	if control is ScrollContainer:
		var scroll := control as ScrollContainer
		if scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and not bool(scroll.get_meta(HIDDEN_VERTICAL_DRAG_SCROLL_META, false)):
			return false
	elif not bool(control.get_meta(HIDDEN_VERTICAL_DRAG_SCROLLABLE_CONTROL_META, false)):
		return false
	var vbar := _internal_scrollbar(control, "get_v_scroll_bar")
	if vbar != null and float(vbar.max_value) - float(vbar.page) > 1.0:
		return true
	if control is ScrollContainer:
		var max_scroll := _scroll_container_content_vertical_extent(control as ScrollContainer) - maxf(control.size.y, 1.0)
		return max_scroll > 1.0
	return false


static func _scroll_target_vertical_value(control: Control) -> int:
	if control == null:
		return 0
	if control is ScrollContainer:
		return int((control as ScrollContainer).scroll_vertical)
	var vbar := _internal_scrollbar(control, "get_v_scroll_bar")
	return roundi(vbar.value) if vbar != null else 0


static func _set_scroll_target_vertical_value(control: Control, value: int) -> void:
	if control == null:
		return
	var target := maxi(0, value)
	var max_scroll := _scroll_target_max_vertical_scroll(control)
	if max_scroll > 0:
		target = mini(target, max_scroll)
	if control is ScrollContainer:
		(control as ScrollContainer).scroll_vertical = target
		return
	var vbar := _internal_scrollbar(control, "get_v_scroll_bar")
	if vbar != null:
		vbar.value = target


static func _scroll_target_max_vertical_scroll(control: Control) -> int:
	if control == null:
		return 0
	var vbar := _internal_scrollbar(control, "get_v_scroll_bar")
	if vbar != null:
		var range_max := roundi(float(vbar.max_value) - float(vbar.page))
		if range_max > 0:
			return range_max
	if control is ScrollContainer:
		return maxi(0, roundi(_scroll_container_content_vertical_extent(control as ScrollContainer) - maxf(control.size.y, 1.0)))
	return 0


static func _scroll_container_content_vertical_extent(scroll: ScrollContainer) -> float:
	if scroll == null:
		return 0.0
	var extent := 0.0
	for child: Node in scroll.get_children():
		if child is VScrollBar or child is HScrollBar:
			continue
		if not child is Control:
			continue
		var control := child as Control
		var child_height := maxf(control.size.y, control.custom_minimum_size.y)
		child_height = maxf(child_height, control.get_combined_minimum_size().y)
		extent = maxf(extent, control.position.y + child_height)
	return extent


static func _hide_internal_scrollbar(control: Control, method_name: String) -> void:
	var bar := _internal_scrollbar(control, method_name)
	if bar == null:
		return
	bar.set_meta(HIDDEN_SCROLLBAR_META, true)
	bar.visible = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2.ZERO
	bar.set_deferred("visible", false)
	bar.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)


static func _internal_scrollbar(control: Control, method_name: String) -> ScrollBar:
	if control == null or not control.has_method(method_name):
		return null
	var value: Variant = control.call(method_name)
	if value is ScrollBar:
		return value as ScrollBar
	return null


static func _focusable_control_is_available(control: Control) -> bool:
	if control == null or not control.visible:
		return false
	if control is LineEdit and not (control as LineEdit).editable:
		return false
	if control is TextEdit and not (control as TextEdit).editable:
		return false
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return false
	return true


static func _focus_control(control: Control) -> void:
	if control == null:
		return
	control.set_meta(FOCUS_REQUESTED_META, true)
	if not control.is_inside_tree():
		return
	control.focus_mode = Control.FOCUS_ALL
	if WebTextInputBridgeScript.request_focus(control):
		return
	control.grab_focus()
	if control is SpinBox:
		var line_edit := (control as SpinBox).get_line_edit()
		if line_edit != null and line_edit.is_inside_tree():
			line_edit.focus_mode = Control.FOCUS_ALL
			if WebTextInputBridgeScript.request_focus(line_edit):
				return
			line_edit.grab_focus()


static func _show_option_button_popup(option: OptionButton) -> void:
	if option == null:
		return
	var popup := option.get_popup()
	if popup == null:
		option.show_popup()
		popup = option.get_popup()
	if popup == null:
		return
	var rect := _control_global_rect_with_minimum(option)
	var popup_rect := _bounded_option_popup_rect(option, rect)
	option.set_meta(OPTION_POPUP_BOUNDS_META, popup_rect)
	popup.set_meta(OPTION_POPUP_BOUNDS_META, popup_rect)
	if popup.visible:
		popup.hide()
	if popup.is_inside_tree():
		popup.popup(popup_rect)
		popup.size = popup_rect.size
	else:
		popup.position = popup_rect.position
		popup.size = popup_rect.size
		popup.visible = true


static func _bounded_option_popup_rect(option: OptionButton, rect: Rect2) -> Rect2i:
	var viewport_size := _viewport_size_for_control(option)
	var margin := 12.0
	var max_width := maxf(1.0, viewport_size.x - margin * 2.0)
	var width := minf(maxf(1.0, rect.size.x), max_width)
	var x := clampf(rect.position.x, margin, maxf(margin, viewport_size.x - width - margin))
	var row_height := clampf(maxf(44.0, rect.size.y * 0.72), 44.0, 96.0)
	var visible_items := clampi(option.get_item_count(), 1, 6)
	var desired_height := row_height * float(visible_items)
	var below_y := rect.position.y + rect.size.y
	var available_below := viewport_size.y - below_y - margin
	var available_above := rect.position.y - margin
	var use_above := available_below < row_height * 2.0 and available_above > available_below
	var available_height := available_above if use_above else available_below
	if available_height < row_height:
		available_height = maxf(row_height, viewport_size.y - margin * 2.0)
	var height := minf(minf(desired_height, available_height), 720.0)
	var y := rect.position.y - height if use_above else below_y
	y = clampf(y, margin, maxf(margin, viewport_size.y - height - margin))
	return Rect2i(Vector2i(roundi(x), roundi(y)), Vector2i(maxi(1, roundi(width)), maxi(1, roundi(height))))


static func _viewport_size_for_control(control: Control) -> Vector2:
	var viewport_size := Vector2.ZERO
	if control != null and control.is_inside_tree():
		viewport_size = control.get_viewport_rect().size
	var cursor: Node = control
	while cursor != null:
		if cursor is Control:
			var rect := _control_global_rect_with_minimum(cursor as Control)
			viewport_size.x = maxf(viewport_size.x, rect.end.x)
			viewport_size.y = maxf(viewport_size.y, rect.end.y)
		cursor = cursor.get_parent()
	if viewport_size.x <= 0.0:
		viewport_size.x = maxf(1.0, control.size.x if control != null else 1.0)
	if viewport_size.y <= 0.0:
		viewport_size.y = maxf(1.0, control.size.y if control != null else 1.0)
	return viewport_size


static func _control_has_point(control: Control, global_position: Vector2) -> bool:
	if control == null:
		return false
	var actual_rect := control.get_global_rect()
	if control.is_inside_tree() and (actual_rect.size.x <= 0.0 or actual_rect.size.y <= 0.0):
		return false
	return _control_global_rect_with_minimum(control).has_point(global_position)


static func _control_global_rect_with_minimum(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		return rect
	var fallback_size := control.custom_minimum_size
	if fallback_size.x <= 0.0:
		fallback_size.x = maxf(control.size.x, 1.0)
	if fallback_size.y <= 0.0:
		fallback_size.y = maxf(control.size.y, 1.0)
	rect.size = fallback_size
	return rect


static func _event_position_for_control(control: Control, event: InputEvent) -> Vector2:
	var raw := Vector2.ZERO
	if event is InputEventMouse:
		var mouse_event := event as InputEventMouse
		raw = mouse_event.global_position if mouse_event.global_position != Vector2.ZERO else mouse_event.position
	elif event is InputEventScreenTouch:
		raw = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		raw = (event as InputEventScreenDrag).position
	if control == null:
		return raw
	var global_rect := _control_global_rect_with_minimum(control)
	if global_rect.has_point(raw):
		return raw
	var local_as_global := global_rect.position + raw
	if global_rect.has_point(local_as_global):
		return local_as_global
	return raw


static func _set_range_value_from_position(range_control: Range, global_position: Vector2) -> void:
	if range_control == null or not (range_control is Control):
		return
	var control := range_control as Control
	var rect := _control_global_rect_with_minimum(control)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		var fallback_size := control.custom_minimum_size
		if fallback_size.x > 0.0 and fallback_size.y > 0.0:
			rect.size = fallback_size
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var ratio := 0.0
	if range_control is VSlider or range_control is VScrollBar:
		ratio = clampf((global_position.y - rect.position.y) / rect.size.y, 0.0, 1.0)
	else:
		ratio = clampf((global_position.x - rect.position.x) / rect.size.x, 0.0, 1.0)
	var min_value := float(range_control.min_value)
	var max_value := float(range_control.max_value)
	if range_control is ScrollBar:
		max_value = maxf(min_value, max_value - float((range_control as ScrollBar).page))
	range_control.value = lerpf(min_value, max_value, ratio)


static func _accept_event(host: Control) -> void:
	var viewport := host.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
