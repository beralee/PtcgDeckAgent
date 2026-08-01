class_name TestIosWebHudTouchAdapter
extends TestBase

const AdapterScript := preload("res://scripts/ui/battle/interactions/IosWebHudTouchAdapter.gd")
const RuntimeProfileScript := preload("res://scripts/ui/runtime/UiRuntimeProfile.gd")


class CanonicalHitTestHost:
	extends Control

	var logical_offset := Vector2.ZERO
	var canonical_hit_test_calls := 0

	func _battle_hud_control_contains_touch(control: Control, screen_position: Vector2) -> bool:
		canonical_hit_test_calls += 1
		return control.get_global_rect().has_point(screen_position + logical_offset)


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


func test_ios_web_touch_delegates_rotated_portrait_geometry_to_battle_host() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var host := CanonicalHitTestHost.new()
	host.size = Vector2(430, 932)
	host.logical_offset = Vector2(170, 290)
	tree.root.add_child(host)
	var button := Button.new()
	button.position = Vector2(190, 520)
	button.size = Vector2(180, 90)
	host.add_child(button)
	AdapterScript.mark_hud_root(host)
	await tree.process_frame

	var activation_count := {"value": 0}
	button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var adapter := AdapterScript.new()
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var logical_center := button.get_global_rect().get_center()
	var physical_center := logical_center - host.logical_offset
	var default_geometry_would_miss := not button.get_global_rect().has_point(physical_center)
	var press_handled := adapter.handle_event(host, _touch(true, physical_center))
	var release_handled := adapter.handle_event(host, _touch(false, physical_center))
	var result := run_checks([
		assert_true(default_geometry_would_miss, "The fixture must require the host-owned portrait coordinate mapping"),
		assert_true(press_handled and release_handled, "The iOS adapter must use the battle host's canonical portrait hit-test"),
		assert_true(host.canonical_hit_test_calls >= 2, "Both touch edges should be resolved through the shared battle geometry contract"),
		assert_eq(int(activation_count.get("value", 0)), 1, "The remapped portrait HUD button should activate exactly once"),
	])
	host.queue_free()
	await tree.process_frame
	return result


func test_ios_web_mouse_compatibility_sequence_activates_rotated_hud_once() -> String:
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
	var press_handled := adapter.handle_event(host, _mouse_button(true, center))
	var release_handled := adapter.handle_event(host, _mouse_button(false, center))
	var result := run_checks([
		assert_true(press_handled and release_handled, "WebKit's mouse-only compatibility sequence must stay on the iOS HUD path"),
		assert_eq(int(activation_count.get("value", 0)), 1, "A mouse-only WebKit compatibility click should activate once"),
	])
	host.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	return result


func test_ios_web_touch_hit_test_uses_viewport_space_under_canvas_transform() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var canvas_layer := CanvasLayer.new()
	var canvas_transform := Transform2D.IDENTITY.scaled(Vector2(1.7, 1.7))
	canvas_transform.origin = Vector2(180, 120)
	canvas_layer.transform = canvas_transform
	tree.root.add_child(canvas_layer)
	var host := Control.new()
	host.size = Vector2(430, 932)
	host.position = Vector2(36, 28)
	host.scale = Vector2(1.08, 1.08)
	canvas_layer.add_child(host)
	var button := Button.new()
	button.position = Vector2(90, 220)
	button.size = Vector2(210, 100)
	host.add_child(button)
	AdapterScript.mark_hud_root(host)
	await tree.process_frame

	var activation_count := {"value": 0}
	button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var adapter := AdapterScript.new()
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	var logical_center := button.get_global_transform() * (button.size * 0.5)
	var canvas_center := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var press_handled := adapter.handle_event(host, _touch(true, logical_center))
	var release_handled := adapter.handle_event(host, _touch(false, logical_center))
	var result := run_checks([
		assert_false(
			logical_center.is_equal_approx(canvas_center),
			"The fixture must separate Godot viewport input from the browser-rendered canvas position"
		),
		assert_true(
			press_handled and release_handled,
			"iOS Web HUD hit-testing must use InputEvent viewport coordinates and ignore canvas_items render scaling"
		),
		assert_eq(int(activation_count.get("value", 0)), 1, "The transformed HUD button should activate exactly once"),
	])
	canvas_layer.queue_free()
	await tree.process_frame
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


func test_real_pokemon_action_hud_cancel_completes_from_ios_web_touch() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var pokemon_data := _make_basic_pokemon_card("iOS Skill HUD Pokemon")
	var pokemon := CardInstance.create(pokemon_data, 0)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(pokemon)
	state.players[0].active_pokemon = active_slot
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_show_pokemon_action_dialog", 0, active_slot, false)
	await tree.process_frame

	var overlay := scene.find_child("DialogOverlay", true, false) as Control
	var cancel_button := scene.find_child("DialogCancel", true, false) as Button
	var activation_count := {"value": 0}
	cancel_button.pressed.connect(func() -> void:
		activation_count["value"] = int(activation_count.get("value", 0)) + 1
	)
	var pending_before := str(scene.get("_pending_choice"))
	var overlay_before := overlay.visible
	var center := cancel_button.get_global_rect().get_center()
	scene.call("_input", _touch(true, center))
	scene.call("_input", _touch(false, center))
	var result := run_checks([
		assert_eq(pending_before, "pokemon_action", "The real Pokemon skill/action HUD must be open before the iOS touch"),
		assert_true(overlay_before and cancel_button.visible, "The Pokemon skill/action HUD Cancel button must be visible"),
		assert_eq(int(activation_count.get("value", 0)), 1, "One iOS Web touch should activate the Pokemon HUD Cancel button exactly once"),
		assert_eq(str(scene.get("_pending_choice")), "", "Cancel should finish the Pokemon action choice instead of leaving a stale HUD state"),
		assert_false(overlay.visible, "Cancel should close the Pokemon skill/action HUD"),
		assert_true(adapter.current_candidate_button() == null, "The Pokemon HUD touch owner should be released after Cancel"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_real_card_detail_hud_cancel_and_use_complete_from_ios_web_touch() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)
	var overlay := scene.find_child("DetailOverlay", true, false) as Control
	var coordinator := scene.get("_battle_card_detail_coordinator") as RefCounted
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var cancel_button := scene.find_child("DetailCancelButton", true, false) as Button
	var use_count := {"value": 0}
	var cancel_count := {"value": 0}
	use_button.pressed.connect(func() -> void:
		use_count["value"] = int(use_count.get("value", 0)) + 1
	)
	cancel_button.pressed.connect(func() -> void:
		cancel_count["value"] = int(cancel_count.get("value", 0)) + 1
	)

	var card := CardInstance.create(_make_basic_pokemon_card("iOS Card Detail Pokemon"), 0)
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].hand.append(card)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_selected_hand_card", card)
	coordinator.call("show_card_instance_detail", card)
	coordinator.call("set_detail_action_mode", "selected_pokemon", card)
	await tree.process_frame
	var cancel_center := cancel_button.get_global_rect().get_center()
	scene.call("_input", _touch(true, cancel_center))
	scene.call("_input", _touch(false, cancel_center))
	var cancel_closed := not overlay.visible
	var cancel_cleared_selection: bool = scene.get("_selected_hand_card") == null

	scene.set("_selected_hand_card", card)
	coordinator.call("show_card_instance_detail", card)
	coordinator.call("set_detail_action_mode", "selected_pokemon", card)
	await tree.process_frame
	var use_center := use_button.get_global_rect().get_center()
	scene.call("_input", _touch(true, use_center))
	scene.call("_input", _touch(false, use_center))
	var result := run_checks([
		assert_eq(int(cancel_count.get("value", 0)), 1, "The card HUD Cancel button should fire once from one iOS Web touch"),
		assert_true(cancel_closed, "The card HUD Cancel button should close the detail overlay"),
		assert_true(cancel_cleared_selection, "Cancel should preserve the production behavior of clearing the selected hand Pokemon"),
		assert_eq(int(use_count.get("value", 0)), 1, "The card HUD primary bottom button should fire once from one iOS Web touch"),
		assert_false(overlay.visible, "The card HUD primary bottom button should close the detail overlay"),
		assert_true(scene.get("_selected_hand_card") == card, "The Place/Use path should preserve the selected Pokemon for the board action"),
		assert_true(adapter.current_candidate_button() == null, "The card HUD touch owner should be released after both bottom actions"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_real_hand_card_opens_from_ios_web_scene_touch_bridge() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var item_data := CardData.new()
	item_data.name = "Ultra Ball"
	item_data.name_zh = "高级球"
	item_data.card_type = "Item"
	item_data.set_code = "CSV1C"
	item_data.card_index = "112"
	var item := CardInstance.create(item_data, 0)
	state.players[0].hand.append(item)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_refresh_hand")
	await tree.process_frame

	var hand_container := scene.get("_hand_container") as HBoxContainer
	var card_view := hand_container.get_child(0) as BattleCardView
	var detail_overlay := scene.get("_detail_overlay") as Control
	var center := card_view.get_global_rect().get_center()
	scene.call("_input", _touch(true, center))
	scene.call("_input", _touch(false, center))
	var result := run_checks([
		assert_true(
			bool(card_view.get_meta("_ios_web_hand_touch_profile", false)),
			"The production hand card should be marked with the isolated iOS Web touch profile"
		),
		assert_true(
			detail_overlay.visible,
			"One scene-level iOS Web touch on a real hand Item must open its card detail HUD"
		),
		assert_true(
			scene.get("_ios_web_hand_touch_active_card") == null,
			"The hand-card bridge must release pointer ownership after touch-up"
		),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_rebuilt_hand_card_after_turn_cycle_uses_viewport_touch_coordinates() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var canvas_layer := CanvasLayer.new()
	var canvas_transform := Transform2D.IDENTITY.scaled(Vector2(1.65, 1.65))
	canvas_transform.origin = Vector2(170, 110)
	canvas_layer.transform = canvas_transform
	tree.root.add_child(canvas_layer)
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	canvas_layer.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var item_data := CardData.new()
	item_data.name = "Ultra Ball"
	item_data.name_zh = "高级球"
	item_data.card_type = "Item"
	item_data.set_code = "CSV1C"
	item_data.card_index = "112"
	var item := CardInstance.create(item_data, 0)
	state.players[0].hand.append(item)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	# Reproduce the production lifecycle: the opponent turn replaces the hand row
	# with a waiting label, then the next player turn rebuilds every card view.
	scene.call("_refresh_hand")
	await tree.process_frame
	state.current_player_index = 1
	scene.call("_refresh_hand")
	await tree.process_frame
	state.current_player_index = 0
	scene.call("_refresh_hand")
	await tree.process_frame

	var hand_container := scene.get("_hand_container") as HBoxContainer
	var card_view := hand_container.get_child(0) as BattleCardView
	var detail_overlay := scene.get("_detail_overlay") as Control
	var logical_center := card_view.get_global_transform() * (card_view.size * 0.5)
	var rendered_canvas_center := card_view.get_global_transform_with_canvas() * (card_view.size * 0.5)
	scene.call("_input", _touch(true, logical_center))
	scene.call("_input", _touch(false, logical_center + Vector2(20, 14)))
	var result := run_checks([
		assert_false(
			logical_center.is_equal_approx(rendered_canvas_center),
			"The fixture must separate viewport input coordinates from canvas render coordinates"
		),
		assert_true(
			bool(card_view.get_meta("_ios_web_hand_touch_profile", false)),
			"A hand rebuilt for the next player turn must retain the iOS Web touch profile"
		),
		assert_true(
			detail_overlay.visible,
			"The rebuilt hand card must tolerate normal finger jitter and open from the viewport-space iOS touch after a full turn cycle"
		),
	])
	canvas_layer.queue_free()
	await tree.process_frame
	return result


func test_turn_cycle_hand_rebuild_cancels_missing_ios_touch_release() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var item_data := CardData.new()
	item_data.name = "Ultra Ball"
	item_data.name_zh = "高级球"
	item_data.card_type = "Item"
	item_data.set_code = "CSV1C"
	item_data.card_index = "112"
	var item := CardInstance.create(item_data, 0)
	state.players[0].hand.append(item)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_refresh_hand")
	await tree.process_frame

	var hand_container := scene.get("_hand_container") as HBoxContainer
	var first_card := hand_container.get_child(0) as BattleCardView
	var first_center := first_card.get_global_rect().get_center()
	# Safari can drop touch-up while the turn handover/layout refresh replaces
	# the hand row. Reproduce the dangling press instead of sending a release.
	scene.call("_input", _touch(true, first_center))
	var pointer_router := scene.get("_battle_pointer_input_router") as BattlePointerInputRouter
	var captured_before_rebuild: bool = (
		scene.get("_ios_web_hand_touch_active_card") == first_card
		and bool(scene.get("_hand_drag_active"))
		and pointer_router.active_sequence_count() == 1
	)

	state.current_player_index = 1
	scene.call("_refresh_hand")
	await tree.process_frame
	var released_for_opponent_turn: bool = (
		scene.get("_ios_web_hand_touch_active_card") == null
		and not bool(scene.get("_hand_drag_active"))
		and pointer_router.active_sequence_count() == 0
	)

	state.current_player_index = 0
	scene.call("_refresh_hand")
	await tree.process_frame
	hand_container = scene.get("_hand_container") as HBoxContainer
	var rebuilt_card := hand_container.get_child(0) as BattleCardView
	var rebuilt_center := rebuilt_card.get_global_rect().get_center()
	scene.call("_input", _touch(true, rebuilt_center))
	scene.call("_input", _touch(false, rebuilt_center + Vector2(18, 12)))
	var detail_overlay := scene.get("_detail_overlay") as Control

	var result := run_checks([
		assert_true(captured_before_rebuild, "The fixture must begin with a genuinely incomplete iOS hand touch"),
		assert_true(released_for_opponent_turn, "Replacing the hand row must atomically cancel the old card, drag, and pointer ownership"),
		assert_true(detail_overlay.visible, "The first normal tap after returning from the opponent turn must open the rebuilt hand card"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_hand_rebuild_input_reset_is_isolated_from_non_ios_platforms() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"android": true, "mobile": true}, true))
	scene.set("_hand_drag_active", true)
	var pointer_router := scene.get("_battle_pointer_input_router") as BattlePointerInputRouter
	pointer_router.observe(_touch(true, Vector2(120, 120)))

	scene.call("_prepare_ios_web_hand_rebuild", "platform_isolation_test")
	var result := run_checks([
		assert_false(adapter.is_enabled(), "Native Android must not enable the iOS Web hand bridge"),
		assert_true(bool(scene.get("_hand_drag_active")), "The iOS Web rebuild reset must not mutate native-platform hand state"),
		assert_eq(pointer_router.active_sequence_count(), 1, "The iOS Web rebuild reset must not cancel native-platform pointer ownership"),
	])
	scene.call("_cancel_transient_platform_input", "test_cleanup")
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
	var match_end_controller := scene.get("_battle_overlay_controller") as RefCounted
	match_end_controller.call("_ensure_match_end_screen", scene)
	scene.call("_ensure_portrait_actions_popup")
	await tree.process_frame
	var unregistered: Array[String] = []
	for node: Node in scene.find_children("*", "", true, false):
		var button := node as BaseButton
		if button != null and not _has_ios_web_hud_scope(button, scene):
			unregistered.append(str(button.get_path()))

	var late_button := CheckButton.new()
	late_button.name = "LateRuntimeHudButton"
	late_button.position = Vector2(420, 260)
	late_button.size = Vector2(220, 84)
	late_button.z_as_relative = false
	late_button.z_index = 4000
	scene.add_child(late_button)
	await tree.process_frame
	var late_activation_count := {"value": 0}
	late_button.pressed.connect(func() -> void:
		late_activation_count["value"] = int(late_activation_count.get("value", 0)) + 1
	)
	var adapter := scene.get("_ios_web_hud_touch_adapter") as IosWebHudTouchAdapter
	adapter.configure(_profile({"web": true, "web_ios": true}, true))
	_hide_ios_web_modal_hud_roots(scene)
	var late_center := late_button.get_global_transform_with_canvas() * (late_button.size * 0.5)
	var unregistered_press := adapter.handle_event(scene, _touch(true, late_center))
	var unregistered_release := adapter.handle_event(scene, _touch(false, late_center))
	scene.call("_register_ios_web_hud_touch_surface", late_button)
	adapter.handle_event(scene, _touch(true, late_center))
	adapter.handle_event(scene, _touch(false, late_center))

	var known_modal_roots: Array[Node] = [
		scene.find_child("DialogOverlay", true, false),
		scene.find_child("HandoverPanel", true, false),
		scene.find_child("CoinFlipOverlay", true, false),
		scene.find_child("DetailOverlay", true, false),
		scene.find_child("DiscardOverlay", true, false),
		scene.find_child("ReviewOverlay", true, false),
		scene.get("_field_interaction_overlay") as Node,
		draw_reveal_overlay,
		scene.find_child("InvalidActionOverlay", true, false),
		scene.get("_match_end_overlay") as Node,
		scene.get("_portrait_actions_popup") as Node,
	]
	var modal_root_failures: Array[String] = []
	for root: Node in known_modal_roots:
		if (
			root == null
			or not bool(root.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false))
			or not bool(root.get_meta(AdapterScript.HUD_TOUCH_MODAL_META, true))
		):
			modal_root_failures.append("<missing>" if root == null else str(root.get_path()))
	var result := assert_eq(
		unregistered,
		[],
		"Every existing battle BaseButton must inherit the battle fallback scope or a modal HUD root"
	)
	result = run_checks([
		result,
		assert_false(
			bool(scene.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false)),
			"BattleScene must not become a catch-all touch root that steals board input"
		),
		assert_false(
			unregistered_press or unregistered_release,
			"A runtime button must opt into the isolated iOS Web compatibility path"
		),
		assert_true(
			bool(late_button.get_meta(AdapterScript.HUD_TOUCH_ROOT_META, false)),
			"The explicit runtime registration contract must support every BaseButton subtype"
		),
		assert_eq(
			int(late_activation_count.get("value", 0)),
			1,
			"An explicitly registered runtime BaseButton should work on iOS Web exactly once"
		),
		assert_eq(
			modal_root_failures,
			[],
			"Every known modal HUD factory must register a blocking root so background buttons cannot click through"
		),
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


func _mouse_button(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = position
	mouse.global_position = position
	mouse.pressed = pressed
	return mouse


func _make_basic_pokemon_card(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_zh = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 70
	card.energy_type = "C"
	card.attacks = []
	card.abilities = []
	return card
