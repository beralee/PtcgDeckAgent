class_name TestWebInputAdapter
extends TestBase

const WebInputAdapterScript := preload("res://scripts/ui/input/WebInputAdapter.gd")


func test_touch_and_synthetic_mouse_echo_form_one_sequence() -> String:
	var adapter: WebInputAdapter = WebInputAdapterScript.new()
	var down := _touch(true, Vector2(50, 80), 2)
	var up := _touch(false, Vector2(50, 80), 2)
	var touch_down := adapter.ingest(down, 1000)
	var mouse_echo := adapter.ingest(_mouse(true, Vector2(51, 81)), 1010)
	var touch_up := adapter.ingest(up, 1020)
	var mouse_up_echo := adapter.ingest(_mouse(false, Vector2(51, 81)), 1030)
	return run_checks([
		assert_true(bool(touch_down.get("deliver", false)), "Touch down should start a sequence"),
		assert_true(bool(mouse_echo.get("suppressed", false)), "Synthetic mouse down should be suppressed"),
		assert_true(bool(touch_up.get("deliver", false)), "Touch up should finish the touch sequence"),
		assert_true(bool(mouse_up_echo.get("suppressed", false)), "Synthetic mouse up should be suppressed after touch completion"),
		assert_eq(adapter.active_sequence_count(), 0, "The physical gesture should leave no active pointer"),
	])


func test_cancelled_sequence_never_turns_late_release_into_click() -> String:
	var adapter: WebInputAdapter = WebInputAdapterScript.new()
	adapter.ingest(_touch(true, Vector2(20, 30)), 2000)
	var cancelled := adapter.cancel_all("visibility_hidden", 2010)
	var late_release := adapter.ingest(_touch(false, Vector2(20, 30)), 2020)
	return run_checks([
		assert_eq(cancelled, 1, "Lifecycle cancellation should terminate the active touch"),
		assert_false(bool(late_release.get("deliver", true)), "A release after cancellation must be ignored"),
		assert_eq(str(late_release.get("phase", "")), "orphan_release", "The ignored release should be diagnosable"),
	])


func test_next_touch_is_not_blocked_by_previous_sequence_time_window() -> String:
	var adapter: WebInputAdapter = WebInputAdapterScript.new()
	adapter.ingest(_touch(true, Vector2(10, 10)), 3000)
	adapter.ingest(_touch(false, Vector2(10, 10)), 3010)
	var next_down := adapter.ingest(_touch(true, Vector2(10, 10), 1), 3020)
	return run_checks([
		assert_true(bool(next_down.get("deliver", false)), "A new physical touch must be accepted immediately"),
		assert_eq(adapter.active_sequence_count(), 1, "The new touch should own its own active sequence"),
	])


func test_hybrid_mouse_far_from_touch_remains_independent() -> String:
	var adapter: WebInputAdapter = WebInputAdapterScript.new()
	adapter.ingest(_touch(true, Vector2(10, 10)), 4000)
	var mouse_down := adapter.ingest(_mouse(true, Vector2(200, 200)), 4010)
	return run_checks([
		assert_true(bool(mouse_down.get("deliver", false)), "A distant mouse press should not be mistaken for a touch echo"),
		assert_false(bool(mouse_down.get("suppressed", true)), "Independent hybrid mouse input must remain available"),
		assert_eq(adapter.active_sequence_count(), 2, "Touch and mouse can coexist on hybrid hardware"),
	])


func _touch(pressed: bool, position: Vector2, index: int = 0) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = index
	return event


func _mouse(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

