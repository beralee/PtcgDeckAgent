class_name TestIosWebHudTouchAdapter
extends TestBase

const AdapterScript := preload("res://scripts/ui/battle/interactions/IosWebHudTouchAdapter.gd")
const RuntimeProfileScript := preload("res://scripts/ui/runtime/UiRuntimeProfile.gd")


func test_ios_web_touch_release_activates_marked_hud_button_once() -> String:
	var fixture := await _make_fixture(true)
	var host := fixture.get("host") as Control
	var button := fixture.get("button") as Button
	var activation_count := {"value": 0}
	button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var adapter := AdapterScript.new()
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var center := button.get_global_rect().get_center()
	var press_handled := adapter.handle_event(host, _touch(true, center))
	var release_handled := adapter.handle_event(host, _touch(false, center))
	var result := run_checks([
		assert_true(press_handled, "iOS Web should claim the marked HUD button touch-down"),
		assert_true(release_handled, "iOS Web should claim the matching HUD button touch-up"),
		assert_eq(int(activation_count.get("value", 0)), 1, "One physical iOS touch should activate the HUD action exactly once"),
	])
	host.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	return result


func test_ios_web_touch_must_start_and_finish_on_the_same_marked_button() -> String:
	var fixture := await _make_fixture(true)
	var host := fixture.get("host") as Control
	var button := fixture.get("button") as Button
	var activation_count := {"value": 0}
	button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var adapter := AdapterScript.new()
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var center := button.get_global_rect().get_center()
	adapter.handle_event(host, _touch(true, center))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(180, 0)
	drag.relative = Vector2(180, 0)
	var drag_handled := adapter.handle_event(host, drag)
	var release_handled := adapter.handle_event(host, _touch(false, drag.position))
	var result := run_checks([
		assert_true(drag_handled, "A gesture claimed by the HUD should keep its drag tail away from the board"),
		assert_true(release_handled, "A cancelled HUD gesture should still consume its release tail"),
		assert_eq(int(activation_count.get("value", 0)), 0, "Dragging away from the HUD button must cancel activation"),
	])
	host.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	return result


func test_ios_web_adapter_ignores_unmarked_controls_and_all_other_platforms() -> String:
	var unmarked_fixture := await _make_fixture(false)
	var unmarked_host := unmarked_fixture.get("host") as Control
	var unmarked_button := unmarked_fixture.get("button") as Button
	var unmarked_count := {"value": 0}
	unmarked_button.pressed.connect(func() -> void:
		unmarked_count["value"] = int(unmarked_count.get("value", 0)) + 1
	)
	var ios_web_adapter := AdapterScript.new()
	ios_web_adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var unmarked_center := unmarked_button.get_global_rect().get_center()
	var unmarked_press := ios_web_adapter.handle_event(unmarked_host, _touch(true, unmarked_center))
	var unmarked_release := ios_web_adapter.handle_event(unmarked_host, _touch(false, unmarked_center))
	unmarked_host.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

	var checks: Array[String] = [
		assert_false(unmarked_press or unmarked_release, "Unmarked battle controls must remain on their existing input path"),
		assert_eq(int(unmarked_count.get("value", 0)), 0, "The iOS Web bridge must not activate unmarked controls"),
	]
	for profile: UiRuntimeProfile in [
		_profile({"web": true, "web_android": true}, true),
		_profile({"ios": true}, true, UiRuntimeProfile.HOST_NATIVE),
		_profile({}, false, UiRuntimeProfile.HOST_NATIVE),
	]:
		var fixture := await _make_fixture(true)
		var host := fixture.get("host") as Control
		var button := fixture.get("button") as Button
		var count := {"value": 0}
		button.pressed.connect(func() -> void:
			count["value"] = int(count.get("value", 0)) + 1
		)
		var adapter := AdapterScript.new()
		adapter.configure(profile)
		var center := button.get_global_rect().get_center()
		var press_handled := adapter.handle_event(host, _touch(true, center))
		var release_handled := adapter.handle_event(host, _touch(false, center))
		checks.append(assert_false(press_handled or release_handled, "Android, native iOS and Windows must keep their established button pipeline"))
		checks.append(assert_eq(int(count.get("value", 0)), 0, "Non-iOS-Web profiles must not be activated by the compatibility adapter"))
		host.queue_free()
		await (Engine.get_main_loop() as SceneTree).process_frame
	return run_checks(checks)


func test_visible_modal_hud_blocks_persistent_battle_surfaces_without_click_through() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	host.size = Vector2(430, 932)
	tree.root.add_child(host)
	var top_button := Button.new()
	top_button.position = Vector2(20, 20)
	top_button.size = Vector2(140, 80)
	host.add_child(top_button)
	AdapterScript.mark_hud_surface(top_button)
	var modal := ColorRect.new()
	modal.size = host.size
	host.add_child(modal)
	AdapterScript.mark_hud_root(modal)
	var modal_button := Button.new()
	modal_button.position = Vector2(210, 700)
	modal_button.size = Vector2(180, 90)
	modal.add_child(modal_button)
	await tree.process_frame

	var activation_count := {"value": 0}
	top_button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var adapter := AdapterScript.new()
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var center := top_button.get_global_rect().get_center()
	var modal_press_handled := adapter.handle_event(host, _touch(true, center))
	var modal_release_handled := adapter.handle_event(host, _touch(false, center))
	modal.visible = false
	await tree.process_frame
	var surface_press_handled := adapter.handle_event(host, _touch(true, center))
	var surface_release_handled := adapter.handle_event(host, _touch(false, center))
	var result := run_checks([
		assert_false(
			modal_press_handled or modal_release_handled,
			"A visible modal HUD must block the persistent surface behind it without claiming an unrelated point"
		),
		assert_true(
			surface_press_handled and surface_release_handled,
			"The persistent battle surface should resume after the modal HUD closes"
		),
		assert_eq(int(activation_count.get("value", 0)), 1, "A modal HUD must never click through to the battle top bar"),
	])
	host.queue_free()
	await tree.process_frame
	return result


func test_real_battle_dialog_ios_touch_records_fresh_input_before_release_commit() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var overlay := scene.find_child("DialogOverlay", true, false) as Control
	var confirm := scene.find_child("DialogConfirm", true, false) as Button
	overlay.visible = true
	confirm.visible = true
	confirm.disabled = false
	scene.set("_dialog_generation", 23)
	scene.set("_dialog_user_input_generation", -1)
	scene.set("_dialog_user_input_source", "")
	await tree.process_frame
	var center := confirm.get_global_rect().get_center()
	var press := _touch(true, center)
	scene.call("_input", press)
	var result := run_checks([
		assert_eq(int(scene.get("_dialog_user_input_generation")), 23, "iOS Web HUD touch-down should satisfy the dialog's fresh-input generation guard"),
		assert_eq(str(scene.get("_dialog_user_input_source")), "dialog_confirm_button", "The iOS adapter must preserve the standard dialog-confirm input source"),
		assert_true(
			adapter.current_candidate_button() == confirm,
			"The real battle dialog confirm should be owned by the iOS Web HUD adapter until release"
		),
	])
	scene.call("_cancel_transient_platform_input", "test_complete")
	scene.queue_free()
	await tree.process_frame
	return result


func test_real_card_detail_hud_use_button_responds_to_ios_web_touch() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var overlay := scene.find_child("DetailOverlay", true, false) as Control
	var action_bar := scene.get("_detail_action_bar") as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var activation_count := {"value": 0}
	use_button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	overlay.visible = true
	action_bar.visible = true
	use_button.visible = true
	use_button.disabled = false
	await tree.process_frame
	var center := use_button.get_global_rect().get_center()
	scene.call("_input", _touch(true, center))
	scene.call("_input", _touch(false, center))
	var result := run_checks([
		assert_eq(int(activation_count.get("value", 0)), 1, "The in-battle card HUD use action should fire once from an iOS Web touch"),
		assert_true(adapter.current_candidate_button() == null, "The card HUD touch owner should be released after confirmation"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_real_counter_distribution_amount_button_responds_to_ios_web_touch() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	scene.call("_show_field_counter_distribution", {
		"title": "选择伤害指示物数量",
		"total_counters": 3,
		"min_select": 1,
		"allow_partial": true,
		"allow_cancel": true,
		"target_items": [],
	})
	await tree.process_frame
	var overlay := scene.get("_field_interaction_overlay") as Control
	var row := scene.get("_field_interaction_row") as HBoxContainer
	var amount_button := row.get_child(1) as Button if row != null and row.get_child_count() >= 2 else null
	var center := amount_button.get_global_rect().get_center() if amount_button != null else Vector2.ZERO
	scene.call("_input", _touch(true, center))
	scene.call("_input", _touch(false, center))
	var result := run_checks([
		assert_true(
			overlay != null
			and bool(overlay.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false)),
			"Munkidori and Dragapult counter-distribution HUD must be registered for iOS Web touch"
		),
		assert_eq(
			int(scene.get("_field_interaction_assignment_selected_source_index")),
			2,
			"The real counter-distribution amount button should accept one raw iOS Web touch"
		),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_real_top_right_battle_hud_button_responds_to_ios_web_touch() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	await tree.process_frame
	var hud_button := scene.find_child("BtnZeusHelp", true, false) as Button
	var activation_count := {"value": 0}
	hud_button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var center := hud_button.get_global_rect().get_center()
	scene.call("_input", _touch(true, center))
	scene.call("_input", _touch(false, center))
	var result := run_checks([
		assert_true(hud_button.visible, "The real portrait top-right HUD button must be visible in this fixture"),
		assert_eq(int(activation_count.get("value", 0)), 1, "The real top-right battle HUD button should accept one raw iOS Web touch"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_all_existing_battle_buttons_belong_to_an_ios_web_hud_scope() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var draw_reveal_controller := scene.get("_battle_draw_reveal_controller") as RefCounted
	var draw_reveal_overlay := draw_reveal_controller.call("_ensure_overlay", scene) as Control
	scene.call("_show_invalid_action_hint", {"reason": "coverage audit"})
	await tree.process_frame
	var unregistered: Array[String] = []
	for node: Node in scene.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and not _has_ios_web_hud_scope(button, scene):
			unregistered.append(str(button.get_path()))
	var result := assert_eq(
		unregistered,
		[],
		"Every existing battle Button must inherit a modal HUD root or own a non-modal HUD surface registration"
	)
	result = run_checks([
		result,
		assert_true(
			draw_reveal_overlay != null
			and bool(draw_reveal_overlay.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false))
			and bool(draw_reveal_overlay.get_meta(AdapterScript.HUD_TOUCH_MODAL_META, false)),
			"The draw/reveal HUD must block persistent battle buttons while it owns the screen"
		),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func _make_fixture(marked: bool) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	host.name = "BattleHost"
	host.size = Vector2(430, 932)
	tree.root.add_child(host)
	var overlay := ColorRect.new()
	overlay.name = "HudOverlay"
	overlay.size = host.size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(overlay)
	if marked:
		AdapterScript.mark_hud_root(overlay)
	var button := Button.new()
	button.name = "ConfirmButton"
	button.position = Vector2(110, 700)
	button.size = Vector2(210, 100)
	button.text = "确认"
	overlay.add_child(button)
	await tree.process_frame
	return {"host": host, "overlay": overlay, "button": button}


func _has_ios_web_hud_scope(node: Node, stop_at: Node) -> bool:
	var cursor := node
	while cursor != null:
		if bool(cursor.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false)):
			return true
		if cursor == stop_at:
			break
		cursor = cursor.get_parent()
	return false


func _hide_ios_web_modal_hud_roots(scene: Node) -> void:
	for node: Node in scene.find_children("*", "", true, false):
		if (
			not bool(node.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false))
			or not bool(node.get_meta(AdapterScript.HUD_TOUCH_MODAL_META, true))
		):
			continue
		if node is Control:
			(node as Control).visible = false
		elif node is Window:
			(node as Window).hide()


func _profile(
	feature_flags: Dictionary,
	mobile_like: bool,
	host_kind: String = UiRuntimeProfile.HOST_WEB
) -> UiRuntimeProfile:
	return RuntimeProfileScript.new({
		"host_kind": host_kind,
		"native_os": UiRuntimeProfile.OS_IOS if bool(feature_flags.get("ios", false)) else UiRuntimeProfile.OS_UNKNOWN,
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH if mobile_like else UiRuntimeProfile.POINTER_MOUSE,
		"mobile_like": mobile_like,
		"feature_flags": feature_flags,
	})


func _touch(pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = position
	touch.pressed = pressed
	return touch
