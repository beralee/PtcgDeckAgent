class_name BattleAdviceCoordinator
extends RefCounted

var context: RefCounted = null
var legacy_advice_controller: RefCounted = null
var legacy_scene: Node = null


func setup(next_context: RefCounted, next_legacy_controller: RefCounted, next_legacy_scene: Node) -> void:
	context = next_context
	legacy_advice_controller = next_legacy_controller
	legacy_scene = next_legacy_scene


func is_configured() -> bool:
	return legacy_advice_controller != null and legacy_scene != null


func ensure_battle_review_service() -> void:
	_call_legacy("ensure_battle_review_service", [])


func begin_battle_review_generation() -> void:
	var state := _advice_state()
	if state != null:
		state.set("review_busy", true)
	_call_legacy("begin_battle_review_generation", [])


func on_battle_review_status_changed(status: String, status_context: Dictionary) -> void:
	var state := _advice_state()
	if state != null:
		state.set("review_busy", status != "completed")
	_call_legacy("on_battle_review_status_changed", [status, status_context])


func on_battle_review_completed(review: Dictionary) -> void:
	var state := _advice_state()
	if state != null:
		state.set("review_last_review", review.duplicate(true))
		state.set("review_busy", false)
	_call_legacy("on_battle_review_completed", [review])


func format_battle_review(review: Dictionary) -> String:
	return str(_call_legacy("format_battle_review", [review]))


func on_review_regenerate_pressed() -> void:
	_call_legacy("on_review_regenerate_pressed", [])


func setup_battle_advice_ui() -> void:
	_call_legacy("setup_battle_advice_ui", [])


func should_offer_battle_advice() -> bool:
	return bool(_call_legacy("should_offer_battle_advice", []))


func current_battle_advice_match_dir() -> String:
	return str(_call_legacy("current_battle_advice_match_dir", []))


func ensure_battle_advice_service() -> void:
	_call_legacy("ensure_battle_advice_service", [])


func on_ai_advice_pressed() -> void:
	var state := _advice_state()
	if state != null:
		state.set("busy", true)
	_call_legacy("on_ai_advice_pressed", [])


func on_battle_advice_status_changed(status: String, status_context: Dictionary) -> void:
	var state := _advice_state()
	if state != null:
		state.set("busy", status != "completed")
	_call_legacy("on_battle_advice_status_changed", [status, status_context])


func on_battle_advice_completed(result: Dictionary) -> void:
	var state := _advice_state()
	if state != null:
		state.set("last_result", result.duplicate(true))
		state.set("busy", false)
	_call_legacy("on_battle_advice_completed", [result])


func show_battle_advice_overlay(result: Dictionary) -> void:
	_call_legacy("show_battle_advice_overlay", [result])


func format_battle_advice(result: Dictionary) -> String:
	return str(_call_legacy("format_battle_advice", [result]))


func on_review_pin_pressed() -> void:
	_call_legacy("on_review_pin_pressed", [])


func on_battle_advice_panel_toggle_pressed() -> void:
	_call_legacy("on_battle_advice_panel_toggle_pressed", [])


func refresh_battle_advice_panel() -> void:
	_call_legacy("refresh_battle_advice_panel", [])


func build_battle_advice_initial_snapshot() -> Dictionary:
	var snapshot: Variant = _call_legacy("build_battle_advice_initial_snapshot", [])
	return snapshot if snapshot is Dictionary else {}


func _call_legacy(method_name: String, args: Array) -> Variant:
	if not is_configured():
		return null
	var call_args: Array = [legacy_scene]
	call_args.append_array(args)
	return legacy_advice_controller.callv(method_name, call_args)


func _advice_state() -> RefCounted:
	if context == null or not context.has_method("state"):
		return null
	return context.call("state", "advice") as RefCounted
