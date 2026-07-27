class_name IosWebHudTouchAdapter
extends RefCounted

const PointerGeometryScript := preload("res://scripts/ui/input/PointerGeometry.gd")

const HUD_TOUCH_ROOT_META := "_ios_web_hud_touch_root"
const HUD_TOUCH_MODAL_META := "_ios_web_hud_touch_modal"
const TOUCH_MOVE_CANCEL_DISTANCE := 32.0

var _enabled := false
var _touch_active := false
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _candidate_ref: WeakRef = null
var _gesture_owned := false


func configure(profile: UiRuntimeProfile) -> void:
	_enabled = should_enable_for_profile(profile)
	if not _enabled:
		cancel_all()


func is_enabled() -> bool:
	return _enabled


func current_candidate_button() -> Button:
	return _candidate_button()


static func should_enable_for_profile(profile: UiRuntimeProfile) -> bool:
	if profile == null or not profile.is_web():
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
		return _handle_touch(host, event as InputEventScreenTouch)
	if event is InputEventScreenDrag:
		return _handle_drag(event as InputEventScreenDrag)
	return false


func cancel_all() -> void:
	_touch_active = false
	_touch_index = -1
	_touch_start = Vector2.ZERO
	_candidate_ref = null
	_gesture_owned = false


func _handle_touch(host: Control, touch: InputEventScreenTouch) -> bool:
	if touch.pressed:
		var button := _marked_button_at_position(host, touch.position)
		if button == null:
			cancel_all()
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
	cancel_all()
	if should_activate:
		candidate.pressed.emit()
	return gesture_owned


func _handle_drag(drag: InputEventScreenDrag) -> bool:
	if not _touch_active or drag.index != _touch_index:
		return false
	if _touch_start.distance_to(drag.position) > TOUCH_MOVE_CANCEL_DISTANCE:
		_candidate_ref = null
	return true


func _candidate_button() -> Button:
	if _candidate_ref == null:
		return null
	var candidate: Variant = _candidate_ref.get_ref()
	return candidate as Button if candidate is Button and is_instance_valid(candidate) else null


func _marked_button_at_position(host: Control, screen_position: Vector2) -> Button:
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
		var button := _find_button_in_root(root, screen_position)
		if button != null:
			return button
	return null


func _collect_visible_hud_roots(node: Node, roots: Array[Node]) -> void:
	if bool(node.get_meta(HUD_TOUCH_ROOT_META, false)) and _hud_root_is_visible(node):
		roots.append(node)
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		_collect_visible_hud_roots(node.get_child(child_index), roots)


func _find_button_in_root(node: Node, screen_position: Vector2) -> Button:
	if node is Control:
		var control := node as Control
		if not PointerGeometryScript.control_is_pointer_visible(control):
			return null
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		var child_button := _find_button_in_root(node.get_child(child_index), screen_position)
		if child_button != null:
			return child_button
	if not (node is Button):
		return null
	var button := node as Button
	if not _button_can_activate(button):
		return null
	return button if PointerGeometryScript.control_visible_point(button, screen_position) else null


func _hud_root_is_visible(root: Node) -> bool:
	if root is Control:
		return PointerGeometryScript.control_is_pointer_visible(root as Control)
	if root is Window:
		return (root as Window).visible
	return root.is_inside_tree()


func _hud_root_priority(root: Node) -> int:
	if root is Window:
		return 100000
	if root is Control:
		var control := root as Control
		var priority := control.z_index
		var cursor := control.get_parent()
		while cursor is Control:
			priority += (cursor as Control).z_index
			cursor = cursor.get_parent()
		return priority
	return 0


func _button_can_activate(button: Button) -> bool:
	return (
		button != null
		and not button.disabled
		and button.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and PointerGeometryScript.control_is_pointer_visible(button)
	)
