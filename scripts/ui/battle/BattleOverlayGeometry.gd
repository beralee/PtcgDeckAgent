class_name BattleOverlayGeometry
extends RefCounted


static func control_rect_in_overlay(overlay: Control, control: Control) -> Rect2:
	if overlay == null or control == null:
		return Rect2()
	var control_size := control.size
	if control_size == Vector2.ZERO:
		control_size = control.custom_minimum_size
	if control_size == Vector2.ZERO:
		return Rect2()
	return local_rect_in_overlay(overlay, control, Rect2(Vector2.ZERO, control_size))


static func local_rect_in_overlay(overlay: Control, control: Control, local_rect: Rect2) -> Rect2:
	if overlay == null or control == null or local_rect.size == Vector2.ZERO:
		return Rect2()
	var relative_transform := _relative_transform(overlay, control)
	var corners: Array[Vector2] = [
		relative_transform * local_rect.position,
		relative_transform * Vector2(local_rect.end.x, local_rect.position.y),
		relative_transform * local_rect.end,
		relative_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var min_point := corners[0]
	var max_point := corners[0]
	for point: Vector2 in corners:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


static func control_point_in_overlay(overlay: Control, control: Control, local_point: Vector2) -> Vector2:
	if overlay == null or control == null:
		return Vector2.ZERO
	return _relative_transform(overlay, control) * local_point


static func screen_point_to_overlay(overlay: Control, screen_point: Vector2) -> Vector2:
	if overlay == null:
		return screen_point
	if not overlay.is_inside_tree():
		return overlay.get_global_transform().affine_inverse() * screen_point
	return overlay.get_screen_transform().affine_inverse() * screen_point


static func control_point_on_screen(control: Control, local_point: Vector2) -> Vector2:
	if control == null:
		return Vector2.ZERO
	if not control.is_inside_tree():
		return control.get_global_transform() * local_point
	return control.get_screen_transform() * local_point


static func _relative_transform(overlay: Control, control: Control) -> Transform2D:
	if overlay.is_inside_tree() and control.is_inside_tree():
		return overlay.get_screen_transform().affine_inverse() * control.get_screen_transform()
	return overlay.get_global_transform().affine_inverse() * control.get_global_transform()
