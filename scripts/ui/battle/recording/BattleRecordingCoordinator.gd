class_name BattleRecordingCoordinator
extends RefCounted

var context: RefCounted = null
var legacy_recording_controller: RefCounted = null
var legacy_scene: Node = null


func setup(next_context: RefCounted, next_legacy_controller: RefCounted, next_legacy_scene: Node) -> void:
	context = next_context
	legacy_recording_controller = next_legacy_controller
	legacy_scene = next_legacy_scene


func is_configured() -> bool:
	return legacy_recording_controller != null and legacy_scene != null


func set_output_root(root_path: String) -> void:
	var state := _recording_state()
	if state != null:
		state.set("output_root", root_path)
	_call_legacy("set_battle_recording_output_root", [root_path])


func should_record_local_battle() -> bool:
	var result: Variant = _call_legacy("should_record_local_battle", [])
	return bool(result)


func can_capture_context() -> bool:
	var result: Variant = _call_legacy("can_capture_battle_recording_context", [])
	return bool(result)


func capture_context_if_ready() -> void:
	_call_legacy("capture_battle_recording_context_if_ready", [])
	var state := _recording_state()
	if state != null:
		state.set("context_captured", true)


func ensure_started() -> void:
	_call_legacy("ensure_battle_recording_started", [])
	var state := _recording_state()
	if state != null:
		state.set("started", true)


func record_event(event_data: Dictionary) -> void:
	_call_legacy("record_battle_event", [event_data])


func finalize(result_data: Dictionary) -> void:
	_call_legacy("finalize_battle_recording", [result_data])
	var state := _recording_state()
	if state != null:
		state.set("started", false)
		state.set("context_captured", false)


func _call_legacy(method_name: String, args: Array) -> Variant:
	if not is_configured():
		return null
	var call_args: Array = [legacy_scene]
	call_args.append_array(args)
	return legacy_recording_controller.callv(method_name, call_args)


func _recording_state() -> RefCounted:
	if context == null or not context.has_method("state"):
		return null
	return context.call("state", "recording") as RefCounted
