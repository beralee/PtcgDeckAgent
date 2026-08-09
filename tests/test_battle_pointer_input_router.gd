class_name TestBattlePointerInputRouter
extends TestBase

const RouterScript := preload(
	"res://scripts/ui/battle/interactions/BattlePointerInputRouter.gd"
)


func test_modal_owns_touch_tail_and_android_mouse_echo_but_not_next_touch() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var position := Vector2(320, 480)
	var touch_down := _touch(true, position)
	router.observe(touch_down, 1000)
	var claimed: bool = bool(router.claim_current("dialog_cancel", "modal", 1001))
	var touch_up := _touch(false, position)
	var blocks_touch_tail: bool = bool(router.should_block(touch_up, "board", 1010))
	var blocks_mouse_down_echo: bool = bool(router.should_block(
		_mouse(true, position, InputEvent.DEVICE_ID_EMULATION),
		"board",
		1020
	))
	var blocks_mouse_up_echo: bool = bool(router.should_block(
		_mouse(false, position, InputEvent.DEVICE_ID_EMULATION),
		"board",
		1030
	))
	var next_touch := _touch(true, position)
	var blocks_next_touch: bool = bool(router.should_block(next_touch, "board", 1040))
	return run_checks([
		assert_true(claimed, "The modal should claim the active physical touch sequence"),
		assert_true(blocks_touch_tail, "The release belonging to the cancel gesture must not reach the board"),
		assert_true(blocks_mouse_down_echo, "The Android mouse-down echo must remain owned by the modal sequence"),
		assert_true(blocks_mouse_up_echo, "The Android mouse-up echo must remain owned by the modal sequence"),
		assert_false(blocks_next_touch, "A new touch must be accepted immediately even at the same coordinate"),
	])


func test_android_long_press_echo_is_owned_but_physical_mouse_stays_independent() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var position := Vector2(240, 360)
	router.observe(_touch(true, position), 1000)
	var claimed: bool = bool(router.claim_current("dialog_cancel", "modal", 1001))
	var blocks_late_emulated_press: bool = bool(router.should_block(
		_mouse(true, position, InputEvent.DEVICE_ID_EMULATION),
		"board",
		2500
	))
	var blocks_touch_release: bool = bool(router.should_block(
		_touch(false, position),
		"board",
		2510
	))
	var blocks_late_emulated_release: bool = bool(router.should_block(
		_mouse(false, position, InputEvent.DEVICE_ID_EMULATION),
		"board",
		2520
	))
	var blocks_physical_mouse: bool = bool(router.should_block(
		_mouse(true, position, 7),
		"board",
		2530
	))
	return run_checks([
		assert_true(claimed, "The modal should claim the Android touch sequence"),
		assert_true(blocks_late_emulated_press, "A long press must retain ownership of its emulated mouse press"),
		assert_true(blocks_touch_release, "The long-press touch release must remain modal-owned"),
		assert_true(blocks_late_emulated_release, "The emulated release after a long press must remain modal-owned"),
		assert_false(blocks_physical_mouse, "A real mouse on Android must start an independent sequence"),
	])


func test_native_mobile_unlabelled_device_zero_mouse_tail_stays_with_touch() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var position := Vector2(280, 420)
	router.observe(_touch(true, position), 1000)
	var claimed: bool = bool(router.claim_current("dialog_cancel", "modal", 1001))
	var blocks_touch_release: bool = bool(router.should_block(
		_touch(false, position),
		"board",
		1010
	))
	var blocks_unlabelled_press: bool = bool(router.should_block(
		_mouse(true, position, 0),
		"board",
		1020
	))
	var blocks_unlabelled_release: bool = bool(router.should_block(
		_mouse(false, position, 0),
		"board",
		1030
	))
	var blocks_separate_physical_mouse: bool = bool(router.should_block(
		_mouse(true, position, 9),
		"board",
		1040
	))
	return run_checks([
		assert_true(claimed, "The modal should claim the native mobile touch"),
		assert_true(blocks_touch_release, "The touch release should remain modal-owned"),
		assert_true(blocks_unlabelled_press, "A device-zero compatibility mouse press should stay with the touch"),
		assert_true(blocks_unlabelled_release, "A device-zero compatibility mouse release should stay with the touch"),
		assert_false(blocks_separate_physical_mouse, "A non-zero physical mouse device must remain independent"),
	])


func test_native_mobile_next_mouse_first_press_is_not_reused_as_old_touch_echo() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var position := Vector2(280, 420)
	var touch_down := _touch(true, position)
	router.observe(touch_down, 1000)
	router.claim_event(touch_down, "hand_card", "battle_pointer_surface:hand", 1001)
	router.observe(_touch(false, position), 1010)

	# The compatibility tail for the first tap has already had a short delivery
	# window. A later device-zero mouse press at the same coordinate can be the
	# leading half of the player's next Android tap (for example the Use button
	# opened above that card), and must start a fresh sequence.
	var next_press := _mouse(true, position, 0)
	var next_result: Dictionary = router.observe(next_press, 1160)
	var next_sequence := next_result.get("sequence", null) as PointerSequence

	return run_checks([
		assert_true(bool(next_result.get("deliver", false)), "A later Android mouse-first press must reach the newly opened HUD button"),
		assert_false(bool(next_result.get("synthetic_echo", false)), "The next physical tap must not be classified as the previous hand-card echo"),
		assert_true(next_sequence != null and next_sequence.owner == "", "The next tap must start with no stale hand-surface owner"),
	])


func test_native_android_mouse_first_touch_echo_stays_in_one_sequence() -> String:
	var router = RouterScript.new()
	router.configure(true)
	var position := Vector2(280, 420)

	# Android/Godot can deliver the compatibility mouse half before the native
	# ScreenTouch half. The modal opens on that first event, so the following
	# touch must inherit the same ownership instead of becoming a second tap.
	var mouse_down := _mouse(true, position, 0)
	router.observe(mouse_down, 1000)
	var claimed: bool = bool(
		router.claim_event(mouse_down, "discard_hud_open", "modal", 1001)
	)
	var touch_down := _touch(true, position)
	var touch_down_result: Dictionary = router.observe(touch_down, 1002)
	var blocks_touch_down: bool = bool(
		router.should_block(touch_down, "board", 1003)
	)

	# Use index 0 for the actual mirrored release. A later independent touch with
	# the same reused index must immediately create a fresh sequence.
	var blocks_touch_release: bool = bool(
		router.should_block(_touch(false, position), "board", 1010)
	)
	var blocks_mouse_release: bool = bool(
		router.should_block(_mouse(false, position, 0), "board", 1011)
	)
	var blocks_next_touch: bool = bool(
		router.should_block(_touch(true, position), "board", 1020)
	)
	return run_checks([
		assert_true(claimed, "The mouse-first Android pointer sequence should be claimable by the modal"),
		assert_true(
			bool(touch_down_result.get("synthetic_echo", false)),
			"The following native touch-down must be recognized as the mouse-first sequence's echo"
		),
		assert_true(blocks_touch_down, "Every mirrored Android touch-down must retain modal ownership"),
		assert_true(blocks_touch_release, "The mirrored touch release must retain modal ownership"),
		assert_true(blocks_mouse_release, "The compatibility mouse release must retain modal ownership"),
		assert_false(blocks_next_touch, "The next independent touch must not inherit the prior modal ownership"),
	])


func test_mouse_only_modal_sequence_blocks_release_then_allows_next_press() -> String:
	var router = RouterScript.new()
	var position := Vector2(100, 200)
	var mouse_down := _mouse(true, position)
	router.observe(mouse_down, 2000)
	var claimed: bool = bool(router.claim_current("dialog_cancel", "modal", 2001))
	var blocks_release: bool = bool(router.should_block(_mouse(false, position), "board", 2010))
	var blocks_next_press: bool = bool(router.should_block(_mouse(true, position), "board", 2020))
	return run_checks([
		assert_true(claimed, "The modal should claim the active mouse sequence"),
		assert_true(blocks_release, "The matching mouse release must not fall through after the modal closes"),
		assert_false(blocks_next_press, "The next independent mouse press must not inherit modal ownership"),
	])


func _touch(pressed: bool, position: Vector2, index: int = 0) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = index
	return event


func _mouse(pressed: bool, position: Vector2, device: int = 0) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.device = device
	return event
