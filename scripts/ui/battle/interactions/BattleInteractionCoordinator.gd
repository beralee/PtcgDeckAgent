class_name BattleInteractionCoordinator
extends RefCounted

var context: RefCounted = null
var legacy_interaction_controller: RefCounted = null
var legacy_scene: Node = null


func setup(next_context: RefCounted, next_legacy_controller: RefCounted, next_legacy_scene: Node) -> void:
	context = next_context
	legacy_interaction_controller = next_legacy_controller
	legacy_scene = next_legacy_scene


func is_configured() -> bool:
	return legacy_interaction_controller != null and legacy_scene != null


func setup_field_interaction_panel() -> void:
	_call_legacy("setup_field_interaction_panel", [])


func ensure_field_interaction_panel() -> void:
	_call_legacy("ensure_field_interaction_panel", [])


func hide_field_interaction() -> void:
	var state := _interaction_state()
	if state != null:
		state.call("reset")
	_call_legacy("hide_field_interaction", [])


func update_field_interaction_panel_metrics(viewport_size: Vector2 = Vector2.ZERO) -> void:
	_call_legacy("update_field_interaction_panel_metrics", [viewport_size])


func is_field_interaction_active() -> bool:
	var state := _interaction_state()
	var state_active := state != null and bool(state.call("is_active"))
	if not is_configured():
		return state_active
	var legacy_active := bool(legacy_interaction_controller.call("is_field_interaction_active", legacy_scene))
	if not legacy_active and state_active:
		state.call("reset")
	return legacy_active


func show_field_slot_choice(title: String, items: Array, data: Dictionary = {}) -> void:
	var state := _interaction_state()
	if state != null:
		state.set("mode", "slot_select")
		state.set("data", data.duplicate(true))
	_call_legacy("show_field_slot_choice", [title, items, data])


func show_field_assignment_interaction(step: Dictionary) -> void:
	var state := _interaction_state()
	if state != null:
		state.set("mode", "assignment")
		state.set("data", step.duplicate(true))
	_call_legacy("show_field_assignment_interaction", [step])


func show_field_counter_distribution(step: Dictionary) -> void:
	var state := _interaction_state()
	if state != null:
		state.set("mode", "counter_distribution")
		state.set("data", step.duplicate(true))
	_call_legacy("show_field_counter_distribution", [step])


func clear_selection() -> void:
	var state := _interaction_state()
	if state != null:
		(state.get("selected_indices") as Array).clear()
		(state.get("assignment_entries") as Array).clear()
		state.set("assignment_selected_source_index", -1)
	_call_legacy("on_field_interaction_clear_pressed", [])


func cancel() -> void:
	var state := _interaction_state()
	if state != null:
		state.call("reset")
	_call_legacy("cancel_field_interaction", [])


func confirm_slot_selection() -> void:
	_call_legacy("finalize_field_slot_selection", [])


func confirm_assignment_selection() -> void:
	_call_legacy("finalize_field_assignment_selection", [])


func confirm_counter_distribution() -> void:
	_call_legacy("finalize_counter_distribution", [])


func _call_legacy(method_name: String, args: Array) -> Variant:
	if not is_configured():
		return null
	var call_args: Array = [legacy_scene]
	call_args.append_array(args)
	return legacy_interaction_controller.callv(method_name, call_args)


func _interaction_state() -> RefCounted:
	if context == null or not context.has_method("state"):
		return null
	return context.call("state", "interaction") as RefCounted
