class_name NonBattleTouchBridge
extends RefCounted

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
const OPTION_PRESS_SIGNAL_ONLY_META := "_non_battle_option_press_signal_only"
const FOCUS_TOUCH_BOUND_META := "_non_battle_focus_touch_bound"
const FOCUS_TOUCH_PRESSED_META := "_non_battle_focus_touch_pressed"
const RANGE_TOUCH_BOUND_META := "_non_battle_range_touch_bound"
const RANGE_TOUCH_ACTIVE_META := "_non_battle_range_touch_active"


static func handle_root_touch(host: Control, event: InputEvent) -> bool:
	if host == null:
		return false
	if event is InputEventMouseButton:
		return _handle_mouse_button(host, event as InputEventMouseButton)
	if event is InputEventScreenDrag:
		if not _should_bridge_screen_touch():
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
			_store_scroll_candidate(host, scroll_container_at_position(host, touch.position), touch.position)
			_accept_event(host)
			return true
		var focus_control := focus_control_at_position(host, touch.position)
		if focus_control != null:
			_store_focus_candidate(host, focus_control, touch.position)
			_store_scroll_candidate(host, scroll_container_at_position(host, touch.position), touch.position)
			_accept_event(host)
			return true
		var scroll_container := scroll_container_at_position(host, touch.position)
		if scroll_container != null:
			_store_scroll_candidate(host, scroll_container, touch.position)
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
			_store_scroll_candidate(host, scroll_container_at_position(host, pointer_position), pointer_position)
			_accept_event(host)
			return true
		var focus_control := focus_control_at_position(host, pointer_position)
		if focus_control != null:
			_store_focus_candidate(host, focus_control, pointer_position)
			_store_scroll_candidate(host, scroll_container_at_position(host, pointer_position), pointer_position)
			_accept_event(host)
			return true
		var scroll_container := scroll_container_at_position(host, pointer_position)
		if scroll_container != null:
			_store_scroll_candidate(host, scroll_container, pointer_position)
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


static func scroll_container_at_position(host: Control, global_position: Vector2) -> ScrollContainer:
	return _scroll_container_at_position_recursive(host, global_position)


static func bind_buttons_recursive(node: Node) -> void:
	if node is Button:
		bind_button_touch(node as Button)
	elif node is Range and not node is SpinBox:
		bind_range_touch(node as Range)
	elif node is LineEdit or node is TextEdit or node is SpinBox:
		bind_focus_control_touch(node as Control)
	for child: Node in node.get_children():
		bind_buttons_recursive(child)


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
	if button.has_meta(BUTTON_TOUCH_PRESSED_META):
		button.remove_meta(BUTTON_TOUCH_PRESSED_META)
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
	if button.has_meta(BUTTON_TOUCH_PRESSED_META):
		button.remove_meta(BUTTON_TOUCH_PRESSED_META)
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
	var scroll := host.get_meta(SCROLL_CANDIDATE_META) as ScrollContainer
	if scroll == null:
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
	var start_value := int(host.get_meta(SCROLL_DRAG_START_VALUE_META, int(scroll.get("scroll_vertical"))))
	var scroll_delta := (start_position.y - position.y) * SCROLL_DRAG_SENSITIVITY
	scroll.set("scroll_vertical", maxi(0, roundi(float(start_value) + scroll_delta)))
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
		_clear_candidate(host)
		_clear_focus_candidate(host)
		_accept_event(host)
		return true
	if not has_button_candidate and not has_focus_candidate:
		_accept_event(host)
		return true
	return false


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


static func _store_scroll_candidate(host: Control, scroll: ScrollContainer, position: Vector2) -> void:
	if scroll == null or not _scroll_container_can_scroll_vertically(scroll):
		_clear_scroll_candidate(host)
		return
	host.set_meta(SCROLL_CANDIDATE_META, scroll)
	host.set_meta(TOUCH_DRAG_START_META, position)
	host.set_meta(SCROLL_DRAG_START_VALUE_META, int(scroll.get("scroll_vertical")))
	host.set_meta(SCROLL_DRAG_ACTIVE_META, false)


static func _store_focus_candidate(host: Control, control: Control, position: Vector2) -> void:
	if control == null:
		_clear_focus_candidate(host)
		return
	host.set_meta(FOCUS_CANDIDATE_META, control)
	host.set_meta(TOUCH_DRAG_START_META, position)


static func _clear_candidate(host: Control) -> void:
	if host.has_meta(TOUCH_CANDIDATE_META):
		host.remove_meta(TOUCH_CANDIDATE_META)
	if host.has_meta(TOUCH_DRAG_START_META):
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
	if not host.has_meta(TOUCH_CANDIDATE_META) and host.has_meta(TOUCH_DRAG_START_META):
		host.remove_meta(TOUCH_DRAG_START_META)


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
	if control is LineEdit and not (control as LineEdit).editable:
		return null
	if control is TextEdit and not (control as TextEdit).editable:
		return null
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return null
	return control if _control_has_point(control, global_position) else null


static func _scroll_container_at_position_recursive(node: Node, global_position: Vector2) -> ScrollContainer:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_scroll := _scroll_container_at_position_recursive(child, global_position)
		if child_scroll != null:
			return child_scroll
	if not (node is ScrollContainer):
		return null
	var scroll := node as ScrollContainer
	if not scroll.visible:
		return null
	if scroll.is_inside_tree() and not scroll.is_visible_in_tree():
		return null
	if not _scroll_container_can_scroll_vertically(scroll):
		return null
	return scroll if _control_has_point(scroll, global_position) else null


static func _scroll_container_can_scroll_vertically(scroll: ScrollContainer) -> bool:
	if scroll == null or scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null and float(vbar.max_value) - float(vbar.page) > 1.0:
		return true
	for child: Node in scroll.get_children():
		if child is VScrollBar or child is HScrollBar:
			continue
		if child is Control and (child as Control).custom_minimum_size.y > scroll.size.y + 1.0:
			return true
	return false


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
	control.grab_focus()
	if control is SpinBox:
		var line_edit := (control as SpinBox).get_line_edit()
		if line_edit != null and line_edit.is_inside_tree():
			line_edit.focus_mode = Control.FOCUS_ALL
			line_edit.grab_focus()


static func _show_option_button_popup(option: OptionButton) -> void:
	if option == null:
		return
	option.show_popup()
	var popup := option.get_popup()
	if popup == null or popup.visible:
		return
	var rect := _control_global_rect_with_minimum(option)
	var popup_size := Vector2i(
		maxi(1, roundi(rect.size.x)),
		maxi(1, roundi(rect.size.y))
	)
	var popup_position := Vector2i(
		roundi(rect.position.x),
		roundi(rect.position.y + rect.size.y)
	)
	if popup.is_inside_tree():
		popup.popup(Rect2i(popup_position, popup_size))
	else:
		popup.visible = true


static func _control_has_point(control: Control, global_position: Vector2) -> bool:
	if control == null:
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
