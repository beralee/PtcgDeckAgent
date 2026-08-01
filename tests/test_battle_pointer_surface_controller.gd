class_name TestBattlePointerSurfaceController
extends TestBase

const RouterScript := preload(
	"res://scripts/ui/battle/interactions/BattlePointerInputRouter.gd"
)
const SurfaceControllerScript := preload(
	"res://scripts/ui/battle/interactions/BattlePointerSurfaceController.gd"
)


func test_generation_change_cancels_missing_release_and_next_tap_commits_once() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 0}
	controller.reconcile_surface(
		"hand",
		"cards:101",
		_surface_config(101, activations, scroll_state, false)
	)

	var down := _touch(true, Vector2(120, 180))
	var down_observation: Dictionary = router.observe(down, 1000)
	var handled_down: bool = bool(controller.handle_event(down, down_observation))
	var first_generation: int = controller.surface_generation("hand")

	controller.reconcile_surface(
		"hand",
		"cards:202",
		_surface_config(202, activations, scroll_state, false)
	)
	var second_generation: int = controller.surface_generation("hand")
	var stale_up := _touch(false, Vector2(120, 180))
	var handled_stale_up: bool = bool(
		controller.handle_event(stale_up, router.observe(stale_up, 1010))
	)

	var next_down := _touch(true, Vector2(120, 180))
	controller.handle_event(next_down, router.observe(next_down, 1020))
	var next_up := _touch(false, Vector2(120, 180))
	var handled_next_up: bool = bool(
		controller.handle_event(next_up, router.observe(next_up, 1030))
	)

	return run_checks([
		assert_true(handled_down, "The hand surface must own a touch that begins inside it"),
		assert_true(second_generation > first_generation, "A semantic hand change must advance the surface generation"),
		assert_true(handled_stale_up, "The release tail from the cancelled generation must stay swallowed"),
		assert_true(handled_next_up, "The next complete touch must be handled immediately"),
		assert_eq(activations, [{"key": 202, "generation": second_generation}], "Only the new generation may activate"),
		assert_eq(controller.active_gesture_count(), 0, "No gesture may remain active after release"),
	])


func test_same_signature_keeps_generation_and_pending_tap_alive() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 0}
	var config := _surface_config(77, activations, scroll_state, false)
	controller.reconcile_surface("hand", "cards:77", config)
	var generation_before: int = controller.surface_generation("hand")

	var down := _touch(true, Vector2(80, 90))
	controller.handle_event(down, router.observe(down, 2000))
	controller.reconcile_surface("hand", "cards:77", config)
	var generation_after: int = controller.surface_generation("hand")
	var up := _touch(false, Vector2(80, 90))
	controller.handle_event(up, router.observe(up, 2010))

	return run_checks([
		assert_eq(generation_after, generation_before, "A visual-only refresh must not replace the hand generation"),
		assert_eq(activations.size(), 1, "The matching release should still commit the pending tap"),
		assert_eq(int(activations[0].get("key", -1)), 77, "The stable semantic target key must be preserved"),
	])


func test_touch_jitter_is_tap_when_surface_does_not_overflow() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 0}
	controller.reconcile_surface(
		"hand",
		"cards:88",
		_surface_config(88, activations, scroll_state, false)
	)

	var down := _touch(true, Vector2(100, 100))
	controller.handle_event(down, router.observe(down, 3000))
	var drag := _drag(Vector2(126, 118), Vector2(26, 18))
	controller.handle_event(drag, router.observe(drag, 3010))
	var up := _touch(false, Vector2(126, 118))
	controller.handle_event(up, router.observe(up, 3020))

	return run_checks([
		assert_eq(activations.size(), 1, "Finger jitter must remain a tap when there is nothing to scroll"),
		assert_eq(int(scroll_state.get("value", -1)), 0, "A non-overflowing surface must not scroll"),
	])


func test_horizontal_overflow_drag_scrolls_without_activating_card() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 120}
	controller.reconcile_surface(
		"hand",
		"cards:99",
		_surface_config(99, activations, scroll_state, true)
	)

	var down := _touch(true, Vector2(160, 120))
	controller.handle_event(down, router.observe(down, 4000))
	var drag := _drag(Vector2(100, 124), Vector2(-60, 4))
	var handled_drag: bool = bool(
		controller.handle_event(drag, router.observe(drag, 4010))
	)
	var up := _touch(false, Vector2(100, 124))
	controller.handle_event(up, router.observe(up, 4020))

	return run_checks([
		assert_true(handled_drag, "The surface must own a horizontal overflow drag"),
		assert_eq(activations.size(), 0, "A scrolling gesture must never activate its starting card"),
		assert_eq(int(scroll_state.get("value", -1)), 180, "Horizontal drag must update the registered scroll value"),
		assert_eq(controller.active_gesture_count(), 0, "The drag must release all gesture state"),
	])


func test_cancel_all_releases_every_surface_owner() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 0}
	controller.reconcile_surface(
		"hand",
		"cards:1",
		_surface_config(1, activations, scroll_state, false)
	)
	var down := _touch(true, Vector2(20, 20))
	controller.handle_event(down, router.observe(down, 5000))
	var cancelled: int = controller.cancel_all("browser_blur")

	return run_checks([
		assert_eq(cancelled, 1, "Browser lifecycle cancellation must close the active surface gesture"),
		assert_eq(controller.active_gesture_count(), 0, "Cancellation must leave no active gesture"),
		assert_eq(activations.size(), 0, "Cancellation must never commit a tap"),
	])


func test_mouse_first_touch_compatibility_sequence_commits_once() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 0}
	controller.reconcile_surface(
		"hand",
		"cards:303",
		_surface_config(303, activations, scroll_state, false)
	)

	var mouse_down := _mouse_button(true, Vector2(140, 100))
	var mouse_down_observation: Dictionary = router.observe(mouse_down, 6000)
	var handled_down: bool = bool(
		controller.handle_event(mouse_down, mouse_down_observation)
	)
	var touch_echo_down := _touch(true, Vector2(140, 100))
	var echo_observation: Dictionary = router.observe(touch_echo_down, 6001)
	var touch_echo_up := _touch(false, Vector2(140, 100))
	router.observe(touch_echo_up, 6002)
	var mouse_up := _mouse_button(false, Vector2(140, 100))
	var handled_up: bool = bool(
		controller.handle_event(mouse_up, router.observe(mouse_up, 6003))
	)

	return run_checks([
		assert_true(handled_down, "A mouse-first browser compatibility sequence must own the surface"),
		assert_true(bool(echo_observation.get("synthetic_echo", false)), "The following touch must be recognized as the same sequence"),
		assert_true(handled_up, "The mouse tail must complete the owned surface gesture"),
		assert_eq(activations.size(), 1, "A mouse-first touch sequence must activate exactly once"),
		assert_eq(int(activations[0].get("key", -1)), 303, "The semantic card key must survive compatibility events"),
		assert_eq(controller.active_gesture_count(), 0, "The compatibility sequence must leave no gesture state"),
	])


func _surface_config(
	target_key: int,
	activations: Array,
	scroll_state: Dictionary,
	overflow: bool
) -> Dictionary:
	return {
		"contains": func(position: Vector2) -> bool:
			return Rect2(Vector2.ZERO, Vector2(400, 260)).has_point(position),
		"target_at": func(_position: Vector2) -> Variant:
			return target_key,
		"activate": func(key: Variant, generation: int) -> void:
			activations.append({"key": key, "generation": generation}),
		"has_horizontal_overflow": func() -> bool:
			return overflow,
		"get_horizontal_scroll": func() -> int:
			return int(scroll_state.get("value", 0)),
		"set_horizontal_scroll": func(value: int) -> void:
			scroll_state["value"] = value,
		"horizontal_tap_tolerance": 36.0,
		"vertical_tap_tolerance": 48.0,
		"horizontal_drag_threshold": 36.0,
	}


func _touch(
	pressed: bool,
	position: Vector2,
	index: int = 0
) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = index
	return event


func _drag(
	position: Vector2,
	relative: Vector2,
	index: int = 0
) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.relative = relative
	event.index = index
	return event


func _mouse_button(
	pressed: bool,
	position: Vector2
) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.device = 0
	return event
