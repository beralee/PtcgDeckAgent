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


func test_overflow_surface_keeps_sub_slop_jitter_as_tap() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 120}
	var config := _surface_config(89, activations, scroll_state, true)
	config["horizontal_drag_threshold"] = 12.0
	controller.reconcile_surface("gallery", "cards:89", config)

	var down := _touch(true, Vector2(100, 100))
	controller.handle_event(down, router.observe(down, 3500))
	var drag := _drag(Vector2(108, 102), Vector2(8, 2))
	controller.handle_event(drag, router.observe(drag, 3510))
	var up := _touch(false, Vector2(108, 102))
	controller.handle_event(up, router.observe(up, 3520))

	return run_checks([
		assert_eq(activations.size(), 1, "Movement below the horizontal drag slop must remain a tap"),
		assert_eq(int(scroll_state.get("value", -1)), 120, "Movement below the drag slop must not scroll an overflowing surface"),
	])


func test_overflow_surface_drag_past_slop_commits_without_release_rollback() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 120}
	var config := _surface_config(90, activations, scroll_state, true)
	config["horizontal_drag_threshold"] = 12.0
	controller.reconcile_surface("gallery", "cards:90", config)

	var down := _touch(true, Vector2(100, 100))
	controller.handle_event(down, router.observe(down, 3600))
	var drag := _drag(Vector2(84, 102), Vector2(-16, 2))
	controller.handle_event(drag, router.observe(drag, 3610))
	var scroll_during_drag := int(scroll_state.get("value", -1))
	var up := _touch(false, Vector2(84, 102))
	controller.handle_event(up, router.observe(up, 3620))

	return run_checks([
		assert_eq(scroll_during_drag, 124, "A horizontal swipe should begin after 12px and apply only movement beyond that slop, without a jump"),
		assert_eq(int(scroll_state.get("value", -1)), 124, "Releasing a committed horizontal drag must preserve its scroll position"),
		assert_eq(activations.size(), 0, "A committed horizontal drag must never activate the starting card"),
	])


func test_horizontal_overflow_drag_scrolls_without_activating_card() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var activations: Array = []
	var scroll_state := {"value": 120}
	var config := _surface_config(99, activations, scroll_state, true)
	config["horizontal_drag_threshold"] = 12.0
	controller.reconcile_surface(
		"hand",
		"cards:99",
		config
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
		assert_eq(int(scroll_state.get("value", -1)), 168, "Horizontal drag must apply movement beyond the 12px drag slop without an entry jump"),
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
	var handled_echo_down: bool = bool(
		controller.handle_event(touch_echo_down, echo_observation)
	)
	var mouse_up := _mouse_button(false, Vector2(140, 100))
	var handled_up: bool = bool(
		controller.handle_event(mouse_up, router.observe(mouse_up, 6002))
	)
	var touch_echo_up := _touch(false, Vector2(140, 100))
	var handled_echo_up: bool = bool(
		controller.handle_event(touch_echo_up, router.observe(touch_echo_up, 6003))
	)

	return run_checks([
		assert_true(handled_down, "A mouse-first browser compatibility sequence must own the surface"),
		assert_true(bool(echo_observation.get("synthetic_echo", false)), "The following touch must be recognized as the same sequence"),
		assert_true(handled_echo_down, "The touch echo must remain swallowed by the existing surface owner"),
		assert_true(handled_up, "The mouse tail must complete the owned surface gesture"),
		assert_true(handled_echo_up, "The touch release echo must remain swallowed after the canonical release"),
		assert_eq(activations.size(), 1, "A mouse-first touch sequence must activate exactly once"),
		assert_eq(int(activations[0].get("key", -1)), 303, "The semantic card key must survive compatibility events"),
		assert_eq(controller.active_gesture_count(), 0, "The compatibility sequence must leave no gesture state"),
	])


func test_completed_hand_surface_does_not_swallow_next_hud_mouse_first_press() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var controller = SurfaceControllerScript.new()
	controller.configure(router, true)
	var surface_visible := {"value": true}
	var activations: Array = []
	var scroll_state := {"value": 0}
	var config := _surface_config(404, activations, scroll_state, false)
	config["contains"] = func(position: Vector2) -> bool:
		return bool(surface_visible.get("value", false)) and Rect2(Vector2.ZERO, Vector2(400, 260)).has_point(position)
	config["activate"] = func(key: Variant, generation: int) -> void:
		activations.append({"key": key, "generation": generation})
		surface_visible["value"] = false
	controller.reconcile_surface("hand", "cards:404", config)

	var position := Vector2(140, 100)
	var touch_down := _touch(true, position)
	controller.handle_event(touch_down, router.observe(touch_down, 7000))
	var touch_up := _touch(false, position)
	controller.handle_event(touch_up, router.observe(touch_up, 7010))
	var use_button_mouse_down := _mouse_button(true, position)
	var next_observation: Dictionary = router.observe(use_button_mouse_down, 7160)
	var swallowed_by_old_surface := controller.handle_event(use_button_mouse_down, next_observation)

	return run_checks([
		assert_eq(activations.size(), 1, "The first tap must open the card action HUD"),
		assert_true(bool(next_observation.get("deliver", false)), "The next Android mouse-first tap must be canonical"),
		assert_false(swallowed_by_old_surface, "The hidden hand surface must not consume the first Use-button press"),
	])


func test_android_touch_mouse_event_order_matrix_commits_each_physical_tap_once() -> String:
	var orderings: Array[Array] = [
		["touch_down", "mouse_down", "touch_up", "mouse_up"],
		["touch_down", "mouse_down", "mouse_up", "touch_up"],
		["mouse_down", "touch_down", "mouse_up", "touch_up"],
		["mouse_down", "touch_down", "touch_up", "mouse_up"],
		["touch_down", "touch_up"],
		["mouse_down", "mouse_up"],
	]
	var checks: Array[String] = []
	for repetition: int in 20:
		for ordering_index: int in orderings.size():
			var router = RouterScript.new()
			router.configure(true)
			var controller = SurfaceControllerScript.new()
			controller.configure(router, true)
			var activations: Array = []
			var scroll_state := {"value": 0}
			controller.reconcile_surface(
				"android_gallery",
				"cards:%d:%d" % [repetition, ordering_index],
				_surface_config(7000 + repetition * 10 + ordering_index, activations, scroll_state, false)
			)
			var press_position := Vector2(140, 100)
			var release_position := press_position + Vector2(float((repetition % 7) - 3), float(repetition % 3))
			var timestamp := 10_000 + repetition * 100 + ordering_index * 10
			for phase: String in orderings[ordering_index]:
				var event: InputEvent
				match phase:
					"touch_down":
						event = _touch(true, press_position)
					"touch_up":
						event = _touch(false, release_position)
					"mouse_down":
						event = _mouse_button(true, press_position)
					_:
						event = _mouse_button(false, release_position)
				var observation: Dictionary = router.observe(event, timestamp)
				controller.handle_event(event, observation)
				timestamp += 1
			checks.append(assert_eq(
				activations.size(),
				1,
				"Android ordering %s repetition %d must activate exactly once" % [str(orderings[ordering_index]), repetition]
			))
			checks.append(assert_eq(
				controller.active_gesture_count(),
				0,
				"Android ordering %s repetition %d must release all gesture state" % [str(orderings[ordering_index]), repetition]
			))
	return run_checks(checks)


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
