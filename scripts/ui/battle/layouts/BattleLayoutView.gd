class_name BattleLayoutView
extends RefCounted

var _scene: Node = null
var _metrics_controller: RefCounted = null


func setup(scene: Node, metrics_controller: RefCounted) -> void:
	_scene = scene
	_metrics_controller = metrics_controller


func mode() -> String:
	return ""


func apply(_context: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func _has_scene_method(method_name: StringName) -> bool:
	return _scene != null and is_instance_valid(_scene) and _scene.has_method(method_name)


func _call_scene(method_name: StringName, args: Array = []) -> Variant:
	if not _has_scene_method(method_name):
		return null
	return _scene.callv(method_name, args)


func _get_scene_var(property_name: StringName) -> Variant:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get(property_name)


func _set_scene_var(property_name: StringName, value: Variant) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_scene.set(property_name, value)


func _has_scene_property(property_name: StringName) -> bool:
	if _scene == null or not is_instance_valid(_scene):
		return false
	for property: Dictionary in _scene.get_property_list():
		if StringName(str(property.get("name", ""))) == property_name:
			return true
	return false


func _node(path: NodePath) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(path)


func _find(name: String, recursive: bool = true, owned: bool = false) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.find_child(name, recursive, owned)


func _as_float(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	return float(value)


func _as_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	return int(value)


func _as_bool(value: Variant, fallback: bool = false) -> bool:
	if value == null:
		return fallback
	return bool(value)


func _as_array(value: Variant) -> Array:
	return value if value is Array else []
