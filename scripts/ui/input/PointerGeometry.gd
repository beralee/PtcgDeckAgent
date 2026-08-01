class_name PointerGeometry
extends RefCounted


static func screen_to_control_local(control: Control, screen_position: Vector2) -> Vector2:
	if control == null:
		return screen_position
	var transform := control.get_global_transform_with_canvas() if control.is_inside_tree() else control.get_global_transform()
	if absf(transform.determinant()) <= 0.000001:
		return screen_position
	return transform.affine_inverse() * screen_position


static func control_contains_screen_point(control: Control, screen_position: Vector2) -> bool:
	if not control_is_pointer_visible(control):
		return false
	var local_rect := control_local_rect(control)
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return false
	return local_rect.has_point(screen_to_control_local(control, screen_position))


static func control_visible_point(control: Control, screen_position: Vector2) -> bool:
	if not control_contains_screen_point(control, screen_position):
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if not control_is_pointer_visible(ancestor_control):
				return false
			if (ancestor_control is ScrollContainer or ancestor_control.clip_contents) and not control_contains_screen_point(ancestor_control, screen_position):
				return false
		ancestor = ancestor.get_parent()
	return true


static func viewport_to_control_local(control: Control, viewport_position: Vector2) -> Vector2:
	if control == null:
		return viewport_position
	# InputEventScreenTouch/InputEventScreenDrag positions are already expressed
	# in Godot viewport space. The canvas transform is render-only; applying it a
	# second time shifts iOS Web hit targets after layout/scroll rebuilds.
	var transform := control.get_global_transform()
	if absf(transform.determinant()) <= 0.000001:
		return viewport_position
	return transform.affine_inverse() * viewport_position


static func control_contains_viewport_point(control: Control, viewport_position: Vector2) -> bool:
	if not control_is_pointer_visible(control):
		return false
	var local_rect := control_local_rect(control)
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return false
	return local_rect.has_point(viewport_to_control_local(control, viewport_position))


static func control_visible_viewport_point(control: Control, viewport_position: Vector2) -> bool:
	if not control_contains_viewport_point(control, viewport_position):
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if not control_is_pointer_visible(ancestor_control):
				return false
			if (
				(ancestor_control is ScrollContainer or ancestor_control.clip_contents)
				and not control_contains_viewport_point(ancestor_control, viewport_position)
			):
				return false
		ancestor = ancestor.get_parent()
	return true


static func control_local_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var control_size := control.size
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		var minimum := control.custom_minimum_size
		control_size.x = minimum.x if control_size.x <= 0.0 else control_size.x
		control_size.y = minimum.y if control_size.y <= 0.0 else control_size.y
	return Rect2(Vector2.ZERO, control_size)


static func control_is_pointer_visible(control: Control) -> bool:
	if control == null or not control.visible:
		return false
	return not control.is_inside_tree() or control.is_visible_in_tree()
