class_name IosWebHudTouchAdapter
extends RefCounted

## Direct touch dispatcher for marked battle HUD controls.
##
## The class name is retained for compatibility with the original iOS Web
## workaround, but native Android uses the same path so modal buttons do not
## depend on Godot's delayed touch-to-mouse compatibility events.

const PointerGeometryScript := preload("res://scripts/ui/input/PointerGeometry.gd")

const HUD_TOUCH_ROOT_META := "_ios_web_hud_touch_root"
const HUD_TOUCH_MODAL_META := "_ios_web_hud_touch_modal"
const TOUCH_MOVE_CANCEL_DISTANCE := 32.0
const TOUCH_MOUSE_ECHO_MAX_DISTANCE := 32.0
const TOUCH_MOUSE_ECHO_MAX_AGE_MSEC := 700
const MOUSE_POINTER_INDEX := -2

var _enabled := false
var _touch_active := false
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _candidate_ref: WeakRef = null
var _gesture_owned := false
var _last_touch_position := Vector2.ZERO
var _last_touch_event_msec := -1000000
var _last_touch_was_owned := false


func configure(profile: UiRuntimeProfile) -> void:
	_enabled = should_enable_for_profile(profile)
	if not _enabled:
		cancel_all()


func is_enabled() -> bool:
	return _enabled


func current_candidate_button() -> BaseButton:
	return _candidate_button()


static func should_enable_for_profile(profile: UiRuntimeProfile) -> bool:
	if profile == null:
		return false
	if profile.is_native():
		return (
			profile.native_os == UiRuntimeProfile.OS_ANDROID
			and profile.mobile_like
			and profile.prefers_touch()
		)
	if not profile.is_web():
		return false
	if bool(profile.feature_flags.get("web_ios", false)):
		return true
	var user_agent := profile.user_agent.strip_edges().to_lower()
	return (
		profile.native_os == UiRuntimeProfile.OS_IOS
		or user_agent.contains("iphone")
		or user_agent.contains("ipad")
		or user_agent.contains("ipod")
		or user_agent.contains("mobile safari")
	)


static func mark_hud_root(root: Node, modal: bool = true) -> void:
	if root != null:
		root.set_meta(HUD_TOUCH_ROOT_META, true)
		root.set_meta(HUD_TOUCH_MODAL_META, modal)


static func mark_hud_surface(root: Node) -> void:
	mark_hud_root(root, false)


func handle_event(host: Control, event: InputEvent) -> bool:
	if not _enabled or host == null:
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var handled := _handle_touch(host, touch)
		_remember_touch_edge(touch.position, handled)
		return handled
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var handled := _handle_drag(drag)
		_remember_touch_edge(drag.position, handled)
		return handled
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if _is_recent_touch_mouse_echo(_mouse_position(mouse_button)):
			return _last_touch_was_owned
		return _handle_mouse_button(host, mouse_button)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion)
	return false


func cancel_all() -> void:
	_reset_active_gesture()
	_last_touch_position = Vector2.ZERO
	_last_touch_event_msec = -1000000
	_last_touch_was_owned = false


func _reset_active_gesture() -> void:
	_touch_active = false
	_touch_index = -1
	_touch_start = Vector2.ZERO
	_candidate_ref = null
	_gesture_owned = false


func _handle_touch(host: Control, touch: InputEventScreenTouch) -> bool:
	if touch.pressed:
		var button := _marked_button_at_position(host, touch.position)
		if button == null:
			_reset_active_gesture()
			return false
		_touch_active = true
		_touch_index = touch.index
		_touch_start = touch.position
		_candidate_ref = weakref(button)
		_gesture_owned = true
		return true
	if not _touch_active or touch.index != _touch_index:
		return false
	var candidate := _candidate_button()
	var gesture_owned := _gesture_owned
	var release_button := _marked_button_at_position(host, touch.position) if candidate != null else null
	var should_activate := (
		gesture_owned
		and candidate == release_button
		and _touch_start.distance_to(touch.position) <= TOUCH_MOVE_CANCEL_DISTANCE
		and _button_can_activate(candidate)
	)
	_reset_active_gesture()
	if should_activate:
		candidate.pressed.emit()
	return gesture_owned


func _handle_drag(drag: InputEventScreenDrag) -> bool:
	if not _touch_active or drag.index != _touch_index:
		return false
	if _touch_start.distance_to(drag.position) > TOUCH_MOVE_CANCEL_DISTANCE:
		_candidate_ref = null
	return true


func _handle_mouse_button(host: Control, mouse_button: InputEventMouseButton) -> bool:
	var position := _mouse_position(mouse_button)
	if mouse_button.pressed:
		var button := _marked_button_at_position(host, position)
		if button == null:
			_reset_active_gesture()
			return false
		_touch_active = true
		_touch_index = MOUSE_POINTER_INDEX
		_touch_start = position
		_candidate_ref = weakref(button)
		_gesture_owned = true
		return true
	if not _touch_active or _touch_index != MOUSE_POINTER_INDEX:
		return false
	var candidate := _candidate_button()
	var gesture_owned := _gesture_owned
	var release_button := _marked_button_at_position(host, position) if candidate != null else null
	var should_activate := (
		gesture_owned
		and candidate == release_button
		and _touch_start.distance_to(position) <= TOUCH_MOVE_CANCEL_DISTANCE
		and _button_can_activate(candidate)
	)
	_reset_active_gesture()
	if should_activate:
		candidate.pressed.emit()
	return gesture_owned


func _handle_mouse_motion(mouse_motion: InputEventMouseMotion) -> bool:
	if not _touch_active or _touch_index != MOUSE_POINTER_INDEX:
		return false
	var position := mouse_motion.global_position \
		if mouse_motion.global_position != Vector2.ZERO else mouse_motion.position
	if _touch_start.distance_to(position) > TOUCH_MOVE_CANCEL_DISTANCE:
		_candidate_ref = null
	return true


func _remember_touch_edge(position: Vector2, handled: bool) -> void:
	_last_touch_position = position
	_last_touch_event_msec = Time.get_ticks_msec()
	_last_touch_was_owned = handled or _gesture_owned


func _is_recent_touch_mouse_echo(position: Vector2) -> bool:
	var age := Time.get_ticks_msec() - _last_touch_event_msec
	return (
		age >= 0
		and age <= TOUCH_MOUSE_ECHO_MAX_AGE_MSEC
		and _last_touch_position.distance_to(position) <= TOUCH_MOUSE_ECHO_MAX_DISTANCE
	)


func _mouse_position(mouse_button: InputEventMouseButton) -> Vector2:
	return mouse_button.global_position \
		if mouse_button.global_position != Vector2.ZERO else mouse_button.position


func _candidate_button() -> BaseButton:
	if _candidate_ref == null:
		return null
	var candidate: Variant = _candidate_ref.get_ref()
	return candidate as BaseButton if candidate is BaseButton and is_instance_valid(candidate) else null


func _marked_button_at_position(host: Control, screen_position: Vector2) -> BaseButton:
	var roots: Array[Node] = []
	_collect_visible_hud_roots(host, roots)
	var has_modal_root := false
	for root: Node in roots:
		if bool(root.get_meta(HUD_TOUCH_MODAL_META, true)):
			has_modal_root = true
			break
	roots.sort_custom(func(left: Node, right: Node) -> bool:
		return _hud_root_priority(left) > _hud_root_priority(right)
	)
	for root: Node in roots:
		if bool(root.get_meta(HUD_TOUCH_MODAL_META, true)) != has_modal_root:
			continue
		var button := _find_button_in_root(host, root, screen_position)
		if button != null:
			return button
	return null


func _collect_visible_hud_roots(node: Node, roots: Array[Node]) -> void:
	if bool(node.get_meta(HUD_TOUCH_ROOT_META, false)) and _hud_root_is_visible(node):
		roots.append(node)
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		_collect_visible_hud_roots(node.get_child(child_index), roots)


func _find_button_in_root(host: Control, node: Node, screen_position: Vector2) -> BaseButton:
	if node is Control:
		var control := node as Control
		if not PointerGeometryScript.control_is_pointer_visible(control):
			return null
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		var child_button := _find_button_in_root(host, node.get_child(child_index), screen_position)
		if child_button != null:
			return child_button
	if not (node is BaseButton):
		return null
	var button := node as BaseButton
	if not _button_can_activate(button):
		return null
	return button if _control_visible_point_in_viewport(host, button, screen_position) else null


func _control_visible_point_in_viewport(host: Control, control: Control, viewport_position: Vector2) -> bool:
	if not _host_control_contains_touch(host, control, viewport_position):
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if not PointerGeometryScript.control_is_pointer_visible(ancestor_control):
				return false
			if (
				(ancestor_control is ScrollContainer or ancestor_control.clip_contents)
				and not _host_control_contains_touch(host, ancestor_control, viewport_position)
			):
				return false
		ancestor = ancestor.get_parent()
	return true


func _host_control_contains_touch(host: Control, control: Control, viewport_position: Vector2) -> bool:
	# BattleScene owns the mapping between viewport input and its logical board.
	# In forced portrait it rotates a landscape board by 90 degrees, so a raw
	# Control global transform and a screen-space touch do not share one basis.
	# Reuse the host's canonical hit-test contract instead of duplicating that
	# platform/layout conversion in every compatibility adapter.
	if host != null and host.has_method("_battle_hud_control_contains_touch"):
		return bool(host.call("_battle_hud_control_contains_touch", control, viewport_position))
	return _control_contains_viewport_point(control, viewport_position)


func _control_contains_viewport_point(control: Control, viewport_position: Vector2) -> bool:
	if control == null or not PointerGeometryScript.control_is_pointer_visible(control):
		return false
	var local_rect := PointerGeometryScript.control_local_rect(control)
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return false
	# InputEventScreenTouch.position is expressed in Godot viewport space.
	# CanvasItem's canvas transform is render-only, so including it here makes
	# Safari taps drift whenever canvas_items stretch or devicePixelRatio scales
	# the HTML canvas. The Control global transform still includes every actual
	# scene/layout transform, including a rotated battle root.
	var transform := control.get_global_transform()
	if absf(transform.determinant()) <= 0.000001:
		return false
	return local_rect.has_point(transform.affine_inverse() * viewport_position)


func _hud_root_is_visible(root: Node) -> bool:
	if root is Control:
		return PointerGeometryScript.control_is_pointer_visible(root as Control)
	if root is Window:
		return (root as Window).visible
	return root.is_inside_tree()


func _hud_root_priority(root: Node) -> int:
	if root is Window:
		return 1000000000
	if root is Control:
		var control := root as Control
		var priority := control.z_index
		var depth := 0
		var cursor := control.get_parent()
		while cursor is Control:
			priority += (cursor as Control).z_index
			depth += 1
			cursor = cursor.get_parent()
		return priority * 10000 + depth
	return 0


func _button_can_activate(button: BaseButton) -> bool:
	return (
		button != null
		and not button.disabled
		and button.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and PointerGeometryScript.control_is_pointer_visible(button)
	)
