class_name WebUiE2EBridge
extends Node

const CALLBACK_NAME := "__ptcgDeckAgentE2ECallback"
const BRIDGE_NAME := "__PTCG_TEST__"

var _callback: Variant = null
var _installed: bool = false


func _ready() -> void:
	if not OS.has_feature("web_ui_e2e"):
		queue_free()
		return
	_install()


func _exit_tree() -> void:
	_uninstall()


func _install() -> void:
	if _installed or not (OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_callback = JavaScriptBridge.create_callback(_on_command)
	window.set(CALLBACK_NAME, _callback)
	_installed = bool(JavaScriptBridge.eval(build_install_script(), true))


func _uninstall() -> void:
	if _installed and (OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		JavaScriptBridge.eval(build_uninstall_script(), true)
	_installed = false
	_callback = null


static func build_install_script() -> String:
	return """
(function() {
  var nextId = 1;
  var results = Object.create(null);
  window.__PTCG_TEST__ = {
    version: 1,
    request: function(command, payload) {
      var id = nextId++;
      results[id] = { done: false };
      var callback = window.__ptcgDeckAgentE2ECallback;
      if (typeof callback !== 'function') {
        results[id] = { done: true, ok: false, error: 'Godot E2E callback unavailable' };
        return id;
      }
      callback(JSON.stringify({ request_id: id, command: String(command || ''), payload: payload || {} }));
      return id;
    },
    result: function(id) { return results[id] || null; },
    consume: function(id) { var value = results[id] || null; delete results[id]; return value; },
    _resolve: function(id, value) { results[id] = value; }
  };
  return true;
})();
"""


static func build_uninstall_script() -> String:
	return """
(function() {
  try { delete window.__PTCG_TEST__; } catch (_error) { window.__PTCG_TEST__ = null; }
  try { delete window.__ptcgDeckAgentE2ECallback; } catch (_error) { window.__ptcgDeckAgentE2ECallback = null; }
  return true;
})();
"""


func _on_command(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var request := parsed as Dictionary
	var request_id := int(request.get("request_id", -1))
	var payload_variant: Variant = request.get("payload", {})
	var payload: Dictionary = payload_variant as Dictionary if payload_variant is Dictionary else {}
	var result := _execute_command(str(request.get("command", "")), payload)
	_resolve_javascript_request(request_id, result)


func _execute_command(command: String, payload: Dictionary) -> Dictionary:
	match command:
		"snapshot":
			return {"done": true, "ok": true, "value": _snapshot()}
		"find_control":
			var control := _find_control(str(payload.get("id", "")))
			return {
				"done": true,
				"ok": control != null,
				"value": _control_snapshot(control) if control != null else {},
				"error": "" if control != null else "control not found",
			}
		"list_controls":
			return {"done": true, "ok": true, "value": _visible_control_snapshots()}
		_:
			return {"done": true, "ok": false, "error": "unsupported command: %s" % command}


func _snapshot() -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	var session: Dictionary = {}
	var pointers: Array = []
	if scene != null:
		var registry_variant: Variant = _property_or(scene, "_ui_interaction_sessions", null)
		if registry_variant is UiInteractionSessionRegistry:
			session = (registry_variant as UiInteractionSessionRegistry).current_snapshot()
		var adapter_variant: Variant = _property_or(scene, "_web_battle_input_adapter", null)
		if adapter_variant is WebInputAdapter:
			pointers = (adapter_variant as WebInputAdapter).active_snapshots()
		else:
			var non_battle_adapter := _find_non_battle_input_adapter(scene)
			if non_battle_adapter != null:
				pointers = non_battle_adapter.active_snapshots()
	var profile: Dictionary = {}
	if GameManager != null and GameManager.has_method("get_ui_runtime_profile"):
		var runtime_profile: UiRuntimeProfile = GameManager.get_ui_runtime_profile()
		if runtime_profile != null:
			profile = runtime_profile.to_dictionary()
			profile["viewport_size"] = {
				"x": runtime_profile.viewport_size.x,
				"y": runtime_profile.viewport_size.y,
			}
	return {
		"scene": scene.name if scene != null else "",
		"scene_path": scene.scene_file_path if scene != null else "",
		"runtime_profile": profile,
		"interaction_session": session,
		"active_pointers": pointers,
		"pending_choice": str(_property_or(scene, "_pending_choice", "")) if scene != null else "",
		"draw_reveal_active": bool(_property_or(scene, "_draw_reveal_active", false)) if scene != null else false,
	}


func _property_or(object: Object, property_name: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property: Dictionary in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return object.get(property_name)
	return fallback


func _find_non_battle_input_adapter(node: Node) -> WebInputAdapter:
	if node == null:
		return null
	if node.has_meta("_non_battle_web_input_adapter"):
		var adapter := node.get_meta("_non_battle_web_input_adapter") as WebInputAdapter
		if adapter != null:
			return adapter
	for child: Node in node.get_children():
		var nested := _find_non_battle_input_adapter(child)
		if nested != null:
			return nested
	return null


func _find_control(identifier: String) -> Control:
	if identifier.strip_edges() == "":
		return null
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene == null:
		return null
	return _find_control_recursive(scene, identifier)


func _find_control_recursive(node: Node, identifier: String) -> Control:
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		var found := _find_control_recursive(node.get_child(child_index), identifier)
		if found != null:
			return found
	if not (node is Control):
		return null
	var control := node as Control
	if not control.visible or (control.is_inside_tree() and not control.is_visible_in_tree()):
		return null
	if control.name == identifier or str(control.get_meta("ui_test_id", "")) == identifier or str(control.get_path()) == identifier:
		return control
	return null


func _visible_control_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene != null:
		_collect_controls(scene, snapshots)
	return snapshots


func _collect_controls(node: Node, snapshots: Array[Dictionary]) -> void:
	if node is Control:
		var control := node as Control
		if control.visible and (not control.is_inside_tree() or control.is_visible_in_tree()) and (control is BaseButton or control.has_meta("ui_test_id")):
			snapshots.append(_control_snapshot(control))
	for child: Node in node.get_children():
		_collect_controls(child, snapshots)


func _control_snapshot(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	return {
		"id": str(control.get_meta("ui_test_id", control.name)),
		"name": str(control.name),
		"path": str(control.get_path()),
		"visible": control.visible and (not control.is_inside_tree() or control.is_visible_in_tree()),
		"disabled": bool(control.disabled) if control is BaseButton else false,
		"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y},
	}


func _resolve_javascript_request(request_id: int, result: Dictionary) -> void:
	if request_id < 0:
		return
	var encoded_result := JSON.stringify(result)
	JavaScriptBridge.eval(
		"(function(){var b=window.__PTCG_TEST__;if(b&&typeof b._resolve==='function')b._resolve(%d,%s);})();" % [request_id, encoded_result],
		true
	)
