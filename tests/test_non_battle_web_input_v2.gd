class_name TestNonBattleWebInputV2
extends TestBase

const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")


func test_web_v2_touch_and_mouse_echo_press_button_exactly_once() -> String:
	NonBattleTouchBridgeScript.set_test_web_input_adapter_mode("v2")
	var tree := Engine.get_main_loop() as SceneTree
	var root := Control.new()
	root.size = Vector2(640, 480)
	tree.root.add_child(root)
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(180, 80)
	root.add_child(button)
	var pressed_count := [0]
	button.pressed.connect(func() -> void: pressed_count[0] += 1)
	var center := button.get_global_rect().get_center()
	var handled_down := NonBattleTouchBridgeScript.handle_root_touch(root, _touch(true, center))
	var handled_up := NonBattleTouchBridgeScript.handle_root_touch(root, _touch(false, center))
	var suppressed_mouse_down := NonBattleTouchBridgeScript.handle_root_touch(root, _mouse(true, center))
	var suppressed_mouse_up := NonBattleTouchBridgeScript.handle_root_touch(root, _mouse(false, center))
	var result := run_checks([
		assert_true(handled_down and handled_up, "Web v2 should own the physical touch sequence"),
		assert_true(suppressed_mouse_down and suppressed_mouse_up, "Web v2 should consume the synthetic mouse echo"),
		assert_eq(pressed_count[0], 1, "Touch plus synthetic mouse must emit one button intent"),
	])
	root.queue_free()
	NonBattleTouchBridgeScript.reset_test_web_input_adapter_mode()
	return result


func test_web_v2_lifecycle_cancel_clears_candidate_and_ignores_late_release() -> String:
	NonBattleTouchBridgeScript.set_test_web_input_adapter_mode("v2")
	var tree := Engine.get_main_loop() as SceneTree
	var root := Control.new()
	root.size = Vector2(640, 480)
	tree.root.add_child(root)
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(180, 80)
	root.add_child(button)
	var pressed_count := [0]
	button.pressed.connect(func() -> void: pressed_count[0] += 1)
	var center := button.get_global_rect().get_center()
	var handled_down := NonBattleTouchBridgeScript.handle_root_touch(root, _touch(true, center))
	NonBattleTouchBridgeScript.clear_transient_input_state(root, "visibility_hidden")
	var handled_late_up := NonBattleTouchBridgeScript.handle_root_touch(root, _touch(false, center))
	var result := run_checks([
		assert_true(handled_down, "The initial touch should be owned before suspension"),
		assert_false(handled_late_up, "A release arriving after lifecycle cancellation must be ignored"),
		assert_eq(pressed_count[0], 0, "Lifecycle cancellation must not synthesize a press"),
	])
	root.queue_free()
	NonBattleTouchBridgeScript.reset_test_web_input_adapter_mode()
	return result


func test_web_v2_disables_per_control_touch_bridge_but_keeps_root_owner() -> String:
	NonBattleTouchBridgeScript.set_test_web_input_adapter_mode("v2")
	var button := Button.new()
	button.size = Vector2(180, 80)
	var handled_by_control := NonBattleTouchBridgeScript.handle_button_touch(button, _touch(true, Vector2(40, 40)))
	var result := run_checks([
		assert_false(handled_by_control, "Per-control compatibility handlers must yield to the Web v2 root owner"),
	])
	button.free()
	NonBattleTouchBridgeScript.reset_test_web_input_adapter_mode()
	return result


func _touch(pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = 0
	return event


func _mouse(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

