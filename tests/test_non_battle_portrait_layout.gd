class_name TestNonBattlePortraitLayout
extends TestBase

const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const MainMenuScene := preload("res://scenes/main_menu/MainMenu.tscn")
const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")
const DeckManagerScene := preload("res://scenes/deck_manager/DeckManager.tscn")
const ReplayBrowserScene := preload("res://scenes/replay_browser/ReplayBrowser.tscn")
const SettingsScene := preload("res://scenes/settings/Settings.tscn")
const TournamentDeckSelectScene := preload("res://scenes/tournament/TournamentDeckSelect.tscn")
const TournamentSetupScene := preload("res://scenes/tournament/TournamentSetup.tscn")
const TournamentOverviewScene := preload("res://scenes/tournament/TournamentOverview.tscn")
const TournamentStandingsScene := preload("res://scenes/tournament/TournamentStandings.tscn")


class FakeReplayIndex extends RefCounted:
	func list_rows() -> Array[Dictionary]:
		return [{
			"match_id": "portrait_match",
			"match_dir": "user://match_records/portrait_match",
			"recorded_at": "2026-06-15 21:00",
			"player_labels": ["Player A", "Player B"],
			"winner_index": 0,
			"first_player_index": 1,
			"turn_count": 8,
			"final_prize_counts": [0, 2],
		}]


func _snapshot_battle_review_config_file() -> Dictionary:
	var path: String = GameManager.get_battle_review_api_config_path()
	if not FileAccess.file_exists(path):
		return {"exists": false, "text": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "text": ""}
	var text := file.get_as_text()
	file.close()
	return {"exists": true, "text": text}


func _restore_battle_review_config_file(snapshot: Dictionary) -> void:
	var path: String = GameManager.get_battle_review_api_config_path()
	if bool(snapshot.get("exists", false)):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(str(snapshot.get("text", "")))
			file.close()
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_battle_review_config_for_test() -> void:
	var file := FileAccess.open(GameManager.get_battle_review_api_config_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k2.6",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	}, "\t"))
	file.close()


func _dispose_scene(scene: Node) -> void:
	if scene == null:
		return
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.free()


func test_non_battle_layout_controller_mobile_defaults_to_portrait() -> String:
	var controller: RefCounted = NonBattleLayoutControllerScript.new()
	var portrait_context: Dictionary = controller.call("build_context", Vector2(390, 844), "portrait", true)
	var high_density_portrait_context: Dictionary = controller.call("build_context", Vector2(1080, 2400), "portrait", true)
	var landscape_context: Dictionary = controller.call("build_context", Vector2(1600, 900), "landscape", false)
	var mobile_default := str(controller.call("default_layout_mode_for_runtime", "Android", {}, "", Vector2(390, 844), ""))
	var desktop_default := str(controller.call("default_layout_mode_for_runtime", "Windows", {}, "windows", Vector2(1600, 900), ""))
	var mobile_web_default := str(controller.call("default_layout_mode_for_runtime", "Web", {"web": true}, "web", Vector2(390, 844), "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148"))
	return run_checks([
		assert_eq(str(portrait_context.get("resolved_mode", "")), "portrait", "Forced portrait non-battle context should resolve to portrait"),
		assert_gte(float(portrait_context.get("primary_button_height", 0.0)), 116.0, "Portrait primary buttons should be comfortably thumb-sized on phones"),
		assert_gte(float(portrait_context.get("secondary_button_height", 0.0)), 104.0, "Portrait secondary buttons should not regress to small desktop touch targets"),
		assert_gte(float(portrait_context.get("input_height", 0.0)), 98.0, "Portrait inputs should be large enough for phone text entry"),
		assert_gte(int(portrait_context.get("button_font_size", 0)), 33, "Portrait buttons should use readable mobile text"),
		assert_gte(int(portrait_context.get("body_font_size", 0)), 27, "Portrait body copy should be readable on phone screens"),
		assert_gte(float(high_density_portrait_context.get("content_width", 0.0)), 1000.0, "High-density Android portrait content should use most of the physical phone width"),
		assert_gte(float(high_density_portrait_context.get("primary_button_height", 0.0)), 185.0, "High-density Android portrait buttons should scale beyond logical-phone minimums"),
		assert_gte(float(high_density_portrait_context.get("input_height", 0.0)), 155.0, "High-density Android portrait inputs should scale beyond desktop-sized fields"),
		assert_gte(int(high_density_portrait_context.get("button_font_size", 0)), 53, "High-density Android portrait button text should scale for physical pixels"),
		assert_eq(float(landscape_context.get("primary_button_height", 0.0)), 52.0, "Landscape button height should stay on its desktop token"),
		assert_eq(int(landscape_context.get("button_font_size", 0)), 18, "Landscape button font should not inherit portrait scaling"),
		assert_eq(mobile_default, "portrait", "Android first-run non-battle default should be portrait"),
		assert_eq(mobile_web_default, "portrait", "Mobile browser first-run non-battle default should be portrait"),
		assert_eq(desktop_default, "landscape", "Desktop first-run non-battle default should stay landscape"),
	])


func test_non_battle_touch_bridge_activates_nested_buttons_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var root := Control.new()
	root.name = "TouchBridgeRoot"
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 24)
	panel.size = Vector2(220, 120)
	root.add_child(panel)
	var button := Button.new()
	button.name = "NestedTouchButton"
	button.position = Vector2(20, 24)
	button.size = Vector2(160, 72)
	panel.add_child(button)
	var pressed_count := [0]
	button.pressed.connect(func() -> void:
		pressed_count[0] += 1
	)
	var center := button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = center
	var handled_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, press))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = center
	var handled_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, release))
	var release_only_button := Button.new()
	release_only_button.name = "RootReleaseOnlyTouchButton"
	release_only_button.position = Vector2(980, 24)
	release_only_button.size = Vector2(160, 72)
	root.add_child(release_only_button)
	var release_only_pressed := [false]
	release_only_button.pressed.connect(func() -> void:
		release_only_pressed[0] = true
	)
	var release_only := InputEventScreenTouch.new()
	release_only.pressed = false
	release_only.position = release_only_button.get_global_rect().get_center()
	var handled_release_only := bool(NonBattleTouchBridgeScript.handle_root_touch(root, release_only))
	var mouse_button := Button.new()
	mouse_button.name = "MouseEchoButton"
	mouse_button.position = Vector2(620, 24)
	mouse_button.size = Vector2(160, 72)
	root.add_child(mouse_button)
	var mouse_pressed := [false]
	mouse_button.pressed.connect(func() -> void:
		mouse_pressed[0] = true
	)
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = mouse_button.get_global_rect().get_center()
	var handled_mouse_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, mouse_press))
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	mouse_release.position = mouse_button.get_global_rect().get_center()
	var handled_mouse_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, mouse_release))
	var bound_button := Button.new()
	bound_button.name = "BoundTouchButton"
	bound_button.position = Vector2(260, 24)
	bound_button.size = Vector2(160, 72)
	root.add_child(bound_button)
	var bound_pressed := [false]
	bound_button.pressed.connect(func() -> void:
		bound_pressed[0] = true
	)
	NonBattleTouchBridgeScript.bind_button_touch(bound_button)
	var bound_press := InputEventScreenTouch.new()
	bound_press.pressed = true
	bound_button.gui_input.emit(bound_press)
	var bound_release := InputEventScreenTouch.new()
	bound_release.pressed = false
	bound_button.gui_input.emit(bound_release)
	var bound_release_only_button := Button.new()
	bound_release_only_button.name = "BoundReleaseOnlyButton"
	bound_release_only_button.position = Vector2(440, 24)
	bound_release_only_button.size = Vector2(160, 72)
	root.add_child(bound_release_only_button)
	var bound_release_only_pressed := [false]
	bound_release_only_button.pressed.connect(func() -> void:
		bound_release_only_pressed[0] = true
	)
	NonBattleTouchBridgeScript.bind_button_touch(bound_release_only_button)
	var bound_release_only := InputEventScreenTouch.new()
	bound_release_only.pressed = false
	bound_release_only_button.gui_input.emit(bound_release_only)
	var bound_mouse_button := Button.new()
	bound_mouse_button.name = "BoundMouseEchoButton"
	bound_mouse_button.position = Vector2(800, 24)
	bound_mouse_button.size = Vector2(160, 72)
	root.add_child(bound_mouse_button)
	var bound_mouse_pressed := [false]
	bound_mouse_button.pressed.connect(func() -> void:
		bound_mouse_pressed[0] = true
	)
	NonBattleTouchBridgeScript.bind_button_touch(bound_mouse_button)
	var bound_mouse_press := InputEventMouseButton.new()
	bound_mouse_press.button_index = MOUSE_BUTTON_LEFT
	bound_mouse_press.pressed = true
	bound_mouse_button.gui_input.emit(bound_mouse_press)
	var bound_mouse_release := InputEventMouseButton.new()
	bound_mouse_release.button_index = MOUSE_BUTTON_LEFT
	bound_mouse_release.pressed = false
	bound_mouse_button.gui_input.emit(bound_mouse_release)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	var result := run_checks([
		assert_true(handled_press, "Non-battle touch bridge should claim a press on a nested button"),
		assert_true(handled_release, "Non-battle touch bridge should claim a release on the same nested button"),
		assert_true(handled_release_only, "Non-battle touch bridge should recover when Android only bubbles release over a nested button"),
		assert_eq(int(pressed_count[0]), 1, "Non-battle touch bridge should emit Button.pressed once for one normal Android ScreenTouch tap"),
		assert_true(bool(release_only_pressed[0]), "Non-battle touch bridge should emit Button.pressed for a release-only Android ScreenTouch on a fresh button"),
		assert_true(handled_mouse_press and handled_mouse_release, "Non-battle touch bridge should also claim Android MouseButton tap echoes when touch-to-mouse emulation is unavailable"),
		assert_true(bool(mouse_pressed[0]), "Non-battle touch bridge should activate buttons from Android MouseButton tap echoes"),
		assert_true(bool(bound_pressed[0]), "Non-battle touch bridge should bind Button.gui_input for nested Android touch activation"),
		assert_true(bool(bound_release_only_pressed[0]), "Bound non-battle buttons should also recover when Android only bubbles release"),
		assert_true(bool(bound_mouse_pressed[0]), "Bound non-battle buttons should activate when Android sends MouseButton directly to Button.gui_input"),
	])
	root.queue_free()
	return result


func test_non_battle_touch_bridge_updates_ranges_and_scrollbars_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var root := Control.new()
	root.name = "TouchRangeRoot"
	root.position = Vector2.ZERO
	root.size = Vector2(720, 720)
	var slider := HSlider.new()
	slider.name = "TouchVolumeSlider"
	slider.position = Vector2(80, 84)
	slider.size = Vector2(420, 96)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 12.0
	root.add_child(slider)
	var slider_press := InputEventScreenTouch.new()
	slider_press.pressed = true
	slider_press.position = slider.get_global_rect().position + Vector2(slider.size.x * 0.78, slider.size.y * 0.5)
	var handled_slider_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, slider_press))
	var slider_drag := InputEventScreenDrag.new()
	slider_drag.position = slider.get_global_rect().position + Vector2(slider.size.x * 0.92, slider.size.y * 0.5)
	var handled_slider_drag := bool(NonBattleTouchBridgeScript.handle_root_touch(root, slider_drag))
	var slider_release := InputEventScreenTouch.new()
	slider_release.pressed = false
	slider_release.position = slider_drag.position
	var handled_slider_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, slider_release))

	var vbar := VScrollBar.new()
	vbar.name = "TouchDeckScrollbar"
	vbar.position = Vector2(612, 72)
	vbar.size = Vector2(80, 420)
	vbar.min_value = 0.0
	vbar.max_value = 1000.0
	vbar.page = 200.0
	vbar.value = 0.0
	root.add_child(vbar)
	var bar_press := InputEventScreenTouch.new()
	bar_press.pressed = true
	bar_press.position = vbar.get_global_rect().position + Vector2(vbar.size.x * 0.5, vbar.size.y * 0.70)
	var handled_bar_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, bar_press))
	var bar_release := InputEventScreenTouch.new()
	bar_release.pressed = false
	bar_release.position = bar_press.position
	var handled_bar_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, bar_release))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	var result := run_checks([
		assert_true(handled_slider_press, "Non-battle touch bridge should claim ScreenTouch presses on HSlider controls"),
		assert_true(handled_slider_drag, "Non-battle touch bridge should claim ScreenDrag updates on active HSlider controls"),
		assert_true(handled_slider_release, "Non-battle touch bridge should claim ScreenTouch releases on active HSlider controls"),
		assert_true(slider.value >= 88.0, "Android ScreenTouch/ScreenDrag should update HSlider value without mouse emulation"),
		assert_true(handled_bar_press and handled_bar_release, "Non-battle touch bridge should claim ScreenTouch events on visible scrollbars"),
		assert_true(vbar.value >= 520.0, "Android ScreenTouch should move a vertical scrollbar instead of leaving it inert"),
	])
	root.queue_free()
	return result


func test_non_battle_touch_bridge_scrolls_scroll_container_surface_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var root := Control.new()
	root.name = "TouchScrollRoot"
	root.position = Vector2.ZERO
	root.size = Vector2(720, 720)
	var scroll := ScrollContainer.new()
	scroll.name = "TouchDeckScroll"
	scroll.position = Vector2(80, 72)
	scroll.size = Vector2(460, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "TouchDeckScrollContent"
	content.custom_minimum_size = Vector2(420, 1400)
	scroll.add_child(content)
	var vbar := scroll.get_v_scroll_bar()
	vbar.max_value = 1400.0
	vbar.page = 420.0
	scroll.scroll_vertical = 120

	var start_scroll := scroll.scroll_vertical
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = scroll.get_global_rect().position + Vector2(220, 330)
	var handled_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, press))
	var drag := InputEventScreenDrag.new()
	drag.position = press.position - Vector2(0, 170)
	var handled_drag := bool(NonBattleTouchBridgeScript.handle_root_touch(root, drag))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = drag.position
	var handled_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, release))
	var final_scroll := scroll.scroll_vertical

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	var result := run_checks([
		assert_true(handled_press, "Non-battle touch bridge should claim ScreenTouch presses on scrollable ScrollContainer content"),
		assert_true(handled_drag, "Non-battle touch bridge should claim ScreenDrag on scrollable ScrollContainer content"),
		assert_true(handled_release, "Non-battle touch bridge should claim release after a ScrollContainer drag"),
		assert_true(final_scroll > start_scroll, "Dragging upward on a non-battle ScrollContainer surface should move vertical scroll without mouse emulation"),
	])
	root.queue_free()
	return result


func test_non_battle_touch_bridge_scrolls_when_drag_starts_on_focus_control() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var root := Control.new()
	root.name = "TouchScrollFocusRoot"
	root.position = Vector2.ZERO
	root.size = Vector2(720, 720)
	var scroll := ScrollContainer.new()
	scroll.name = "TouchSettingsScroll"
	scroll.position = Vector2(80, 72)
	scroll.size = Vector2(460, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "TouchSettingsScrollContent"
	content.custom_minimum_size = Vector2(420, 1600)
	scroll.add_child(content)
	var input := LineEdit.new()
	input.name = "TouchSettingsInput"
	input.custom_minimum_size = Vector2(380, 120)
	content.add_child(input)
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(380, 1400)
	content.add_child(filler)
	var vbar := scroll.get_v_scroll_bar()
	vbar.max_value = 1600.0
	vbar.page = 420.0
	scroll.scroll_vertical = 120

	var start_scroll := scroll.scroll_vertical
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = scroll.get_global_rect().position + Vector2(220, 70)
	var handled_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, press))
	var drag := InputEventScreenDrag.new()
	drag.position = press.position - Vector2(0, 190)
	var handled_drag := bool(NonBattleTouchBridgeScript.handle_root_touch(root, drag))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = drag.position
	var handled_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, release))
	var final_scroll := scroll.scroll_vertical

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	var result := run_checks([
		assert_true(handled_press, "Non-battle touch bridge should claim ScreenTouch presses on focus controls inside scroll content"),
		assert_true(handled_drag, "Dragging from a LineEdit should scroll the parent ScrollContainer instead of dying as a focus drag"),
		assert_true(handled_release, "Release after a focus-originated scroll drag should be consumed by the bridge"),
		assert_true(final_scroll > start_scroll, "Dragging upward from an input field should move vertical scroll without mouse emulation"),
	])
	root.queue_free()
	return result


func test_non_battle_touch_bridge_opens_option_buttons_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		return "SceneTree root should be available for the option button touch test"
	var root := Control.new()
	root.name = "TouchOptionRoot"
	root.position = Vector2.ZERO
	root.size = Vector2(720, 480)
	tree.root.add_child(root)
	var option := OptionButton.new()
	option.name = "TouchBgmOption"
	option.position = Vector2(80, 90)
	option.size = Vector2(420, 110)
	option.add_item("No music")
	option.add_item("Battle track")
	root.add_child(option)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = option.get_global_rect().get_center()
	var handled_press := bool(NonBattleTouchBridgeScript.handle_root_touch(root, press))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	var handled_release := bool(NonBattleTouchBridgeScript.handle_root_touch(root, release))
	var popup := option.get_popup()
	var popup_visible := popup != null and popup.visible
	if popup != null:
		popup.hide()
	root.queue_free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	return run_checks([
		assert_true(handled_press and handled_release, "Touch bridge should claim OptionButton taps when mouse emulation is disabled"),
		assert_true(popup_visible, "Touch bridge should open OptionButton popups instead of only emitting a plain Button press"),
	])


func test_main_menu_portrait_layout_reflows_buttons_immediately() -> String:
	var scene: Control = MainMenuScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "MainMenu should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_apply_main_menu_hud")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	var menu := scene.get_node_or_null("VBoxContainer") as VBoxContainer
	var start_button := scene.get_node_or_null("%BtnStartBattle") as Button
	var orientation_button := scene.get_node_or_null("NonBattleOrientationButton") as Button
	var portrait_top := menu.offset_top if menu != null else 0.0
	var portrait_group_height := menu.offset_bottom - menu.offset_top if menu != null else 0.0
	var portrait_menu_center_y := 844.0 * 0.5 + portrait_top + portrait_group_height * 0.5
	var portrait_button_height := start_button.custom_minimum_size.y if start_button != null else 0.0
	var portrait_title := scene.get_node_or_null("PortraitHomeTitle") as Label
	var portrait_subtitle := scene.get_node_or_null("PortraitHomeSubtitle") as Label
	var portrait_title_visible := portrait_title != null and portrait_title.visible
	var portrait_subtitle_visible := portrait_subtitle != null and portrait_subtitle.visible
	var portrait_background := scene.get_node_or_null("Background") as TextureRect
	var portrait_background_path := portrait_background.texture.resource_path if portrait_background != null and portrait_background.texture != null else ""
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	var landscape_top := menu.offset_top if menu != null else 0.0
	var expected_portrait_center_y := 844.0 * 0.595 + portrait_button_height
	var result := run_checks([
		assert_true(scene.get_meta("non_battle_layout_mode", "") == "landscape", "Landscape reapply should leave test metadata on the scene"),
		assert_true(start_button != null and portrait_button_height >= 94.0, "Portrait main menu buttons should grow to comfortable phone-sized touch targets"),
		assert_true(menu != null and absf(portrait_top - landscape_top) > 20.0, "Toggling non-battle mode should visibly reflow the current main menu"),
		assert_true(orientation_button != null and orientation_button.custom_minimum_size.x >= 58.0, "Orientation toggle should remain touch-sized"),
		assert_false(portrait_title_visible, "Portrait main menu should not show the PTCG Deck title text over the background art"),
		assert_false(portrait_subtitle_visible, "Portrait main menu should not show the smart deck practice subtitle text over the background art"),
		assert_true(absf(portrait_menu_center_y - expected_portrait_center_y) < 0.75, "Portrait main menu button group should move down by one portrait button height"),
		assert_str_contains(portrait_background_path, "title_portrait", "Portrait main menu should use a vertical title background derived from the landscape home art"),
	])
	scene.queue_free()
	return result


func test_main_menu_portrait_secondary_actions_modals_and_budew_are_phone_sized() -> String:
	var scene: Control = MainMenuScene.instantiate()
	scene.size = Vector2(1080, 2400)
	scene.call("_apply_main_menu_hud")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var orientation_button := scene.get_node_or_null("NonBattleOrientationButton") as Button
	var feedback_button := scene.get_node_or_null("FeedbackButton") as Button
	var about_button := scene.get_node_or_null("AboutButton") as Button
	var update_button := scene.get_node_or_null("ManualUpdateButton") as Button
	var share_button := scene.get_node_or_null("ShareButton") as Button
	var budew := scene.get_node_or_null("BudewMascotLayer/BudewMascotSprite") as TextureRect
	scene.call("_show_update_status_dialog", "Probe", "The portrait modal body should be readable and touchable on Android.")
	var hud_panel := scene.get_node_or_null("HudModalOverlay/HudModalCenter/HudModalPanel") as PanelContainer
	var hud_body := scene.find_child("HudModalBody", true, false) as Label
	var hud_footer := scene.find_child("HudModalFooter", true, false) as HBoxContainer
	var hud_action := hud_footer.get_child(0) as Button if hud_footer != null and hud_footer.get_child_count() > 0 else null
	scene.call("_hide_hud_modal")
	scene.call("_show_feedback_dialog")
	var feedback_panel := scene.get_node_or_null("FeedbackOverlay/FeedbackCenter/FeedbackPanel") as PanelContainer
	var feedback_text := scene.find_child("FeedbackText", true, false) as TextEdit
	var feedback_submit := scene.get("_feedback_submit_button") as Button
	var result := run_checks([
		assert_true(orientation_button != null and orientation_button.custom_minimum_size.x >= 110.0, "Portrait home orientation button should be large enough for Android thumbs"),
		assert_true(feedback_button != null and feedback_button.custom_minimum_size.x >= 110.0, "Portrait home feedback button should be large enough for Android thumbs"),
		assert_true(about_button != null and about_button.custom_minimum_size.x >= 110.0, "Portrait home about button should be large enough for Android thumbs"),
		assert_true(update_button != null and update_button.custom_minimum_size.x >= 110.0, "Portrait home update button should be large enough for Android thumbs"),
		assert_true(share_button != null and share_button.custom_minimum_size.x >= 110.0, "Portrait home share button should be large enough for Android thumbs"),
		assert_true(share_button != null and share_button.text == "分享", "Portrait home share button should show the direct share label"),
		assert_true(budew != null and budew.custom_minimum_size.x >= 170.0, "Portrait home Budew mascot should scale beyond the desktop corner decoration size"),
		assert_true(hud_panel != null and hud_panel.custom_minimum_size.x >= 1000.0, "Portrait home HUD modal should use nearly the full phone width"),
		assert_true(hud_panel != null and hud_panel.custom_minimum_size.y >= 720.0, "Portrait home HUD modal should be tall enough for readable content"),
		assert_true(hud_body != null and hud_body.get_theme_font_size("font_size") >= 43, "Portrait home HUD modal body text should be phone-readable"),
		assert_true(hud_action != null and hud_action.custom_minimum_size.y >= 145.0, "Portrait home HUD modal footer buttons should be touch-sized"),
		assert_true(feedback_panel != null and feedback_panel.custom_minimum_size.x >= 1000.0, "Portrait feedback modal should use nearly the full phone width"),
		assert_true(feedback_panel != null and feedback_panel.custom_minimum_size.y >= 1800.0, "Portrait feedback modal should use enough phone height for the form"),
		assert_true(feedback_text != null and feedback_text.custom_minimum_size.y >= 360.0, "Portrait feedback text area should be much larger than the desktop form"),
		assert_true(feedback_text != null and feedback_text.get_theme_font_size("font_size") >= 38, "Portrait feedback text should be phone-readable"),
		assert_true(feedback_submit != null and feedback_submit.custom_minimum_size.y >= 145.0, "Portrait feedback submit action should be touch-sized"),
	])
	scene.queue_free()
	return result


func test_main_menu_android_touch_input_activates_portrait_buttons_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var emulation_disabled := not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	var scene: Control = MainMenuScene.instantiate()
	scene.call("_apply_main_menu_hud")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	var deck_button := Button.new()
	deck_button.name = "AndroidTouchProbe"
	deck_button.position = Vector2(24, 40)
	deck_button.size = Vector2(180, 72)
	scene.add_child(deck_button)
	var pressed := [false]
	deck_button.pressed.connect(func() -> void:
		pressed[0] = true
	)
	var center := Vector2(80, 80)
	var hit: bool = scene.call("_main_menu_button_at_position", center) == deck_button
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = center
	scene.call("_handle_main_menu_touch_gui_input", press)
	var candidate_recorded: bool = scene.get("_main_menu_touch_button_candidate") == deck_button
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = center
	scene.call("_handle_main_menu_touch_gui_input", release)
	var bound_mouse_button := Button.new()
	bound_mouse_button.name = "AndroidMouseEchoProbe"
	bound_mouse_button.position = Vector2(260, 40)
	bound_mouse_button.size = Vector2(180, 72)
	scene.add_child(bound_mouse_button)
	var bound_mouse_pressed := [false]
	bound_mouse_button.pressed.connect(func() -> void:
		bound_mouse_pressed[0] = true
	)
	scene.call("_enable_button_touch_activation", bound_mouse_button)
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	bound_mouse_button.gui_input.emit(mouse_press)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	bound_mouse_button.gui_input.emit(mouse_release)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	var result := run_checks([
		assert_true(emulation_disabled, "Test should disable touch-to-mouse emulation before sending Android ScreenTouch"),
		assert_true(hit, "Main menu touch hit testing should find a visible button at the touch point"),
		assert_true(candidate_recorded, "Main menu touch press should remember the button candidate until release"),
		assert_true(bool(pressed[0]), "Main menu portrait buttons should activate from Android ScreenTouch when mouse emulation is disabled"),
		assert_true(bool(bound_mouse_pressed[0]), "Main menu bound buttons should activate from Android MouseButton gui_input echoes"),
	])
	scene.queue_free()
	return result


func test_battle_setup_portrait_layout_stacks_columns_and_keeps_battle_default_portrait() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "BattleSetup should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_ready")
	var default_mode := str(scene.call("_default_battle_layout_mode_for_first_run", "Android", {}, "", Vector2(390, 844)))
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	var stack := scene.find_child("PortraitSetupStack", true, false) as VBoxContainer
	var left_column := scene.find_child("LeftColumn", true, false) as Control
	var right_column := scene.find_child("RightColumn", true, false) as Control
	var action_row := scene.find_child("ActionRow", true, false) as HBoxContainer
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var deck1_picker := scene.find_child("Deck1PickerButton", true, false) as Button
	var deck1_row := scene.find_child("Deck1Row", true, false) as HBoxContainer
	var deck1_view := scene.find_child("Deck1ViewButton", true, false) as Button
	var left_vbox := scene.find_child("LeftVBox", true, false) as VBoxContainer
	var footer_spacer := scene.find_child("PortraitSetupFooterSpacer", true, false) as Control
	var back_pressed := [false]
	if back_button != null:
		back_button.pressed.connect(func() -> void:
			back_pressed[0] = true
		)
	var previous_suppressed := bool(GameManager.get("suppress_scene_navigation_for_tests"))
	GameManager.call("set_scene_navigation_suppressed_for_tests", true)
	var footer_release := InputEventScreenTouch.new()
	footer_release.pressed = false
	footer_release.position = back_button.get_global_rect().get_center() if back_button != null else Vector2.ZERO
	scene.call("_input", footer_release)
	GameManager.call("set_scene_navigation_suppressed_for_tests", previous_suppressed)
	var result := run_checks([
		assert_eq(default_mode, GameManager.BATTLE_LAYOUT_PORTRAIT, "Android first-run battle setup should default battle layout to portrait"),
		assert_not_null(stack, "Battle setup portrait layout should create a vertical stack"),
		assert_true(left_column != null and left_column.get_parent() == stack, "Battle setup left column should move into portrait stack"),
		assert_true(right_column != null and right_column.get_parent() == stack, "Battle setup right column should move into portrait stack"),
		assert_eq(action_row.get_parent() if action_row != null else null, scene, "Battle setup portrait action row should be a fixed footer outside the scrollable setup body"),
		assert_true(start_button != null and start_button.custom_minimum_size.y >= 116.0, "Battle setup start button should be large enough for confident phone use"),
		assert_true(start_button != null and start_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Battle setup portrait start action should expand across the action row"),
		assert_true(back_button != null and back_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Battle setup portrait back action should expand across the action row"),
		assert_true(deck1_picker != null and deck1_picker.get_parent() == left_vbox, "Battle setup portrait deck picker should be split into its own full-width row"),
		assert_true(deck1_row != null and deck1_view != null and deck1_view.custom_minimum_size.y >= 104.0, "Battle setup portrait deck view/edit actions should become large secondary buttons"),
		assert_true(footer_spacer != null and footer_spacer.custom_minimum_size.y >= 150.0, "Battle setup portrait scroll body should reserve space above the fixed footer"),
		assert_true(bool(back_pressed[0]), "Battle setup portrait fixed footer should activate Back from an Android release event"),
	])
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	result = run_checks([
		result,
		assert_true(action_row != null and action_row.get_parent() != scene, "Battle setup landscape should return the action row to the setup content"),
		assert_true(start_button != null and start_button.custom_minimum_size.y <= 45.0, "Battle setup landscape should not retain portrait footer height"),
		assert_true(deck1_picker != null and deck1_row != null and deck1_picker.get_parent() == deck1_row, "Battle setup landscape should restore deck picker to the original row"),
	])
	scene.queue_free()
	return result


func test_battle_setup_portrait_ai_mode_refresh_keeps_dynamic_controls_touch_sized() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "BattleSetup should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var player_deck := DeckData.new()
	player_deck.id = 960301
	player_deck.deck_name = "Portrait Player Probe"
	player_deck.total_cards = 60
	var ai_deck := DeckData.new()
	ai_deck.id = 575720
	ai_deck.deck_name = "Miraidon AI Probe"
	ai_deck.total_cards = 60
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [ai_deck])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	if deck1_option != null:
		deck1_option.clear()
		deck1_option.add_item(player_deck.deck_name)
		deck1_option.set_item_metadata(0, player_deck.id)
		deck1_option.select(0)
	if deck2_option != null:
		deck2_option.clear()
		deck2_option.add_item(ai_deck.deck_name)
		deck2_option.set_item_metadata(0, ai_deck.id)
		deck2_option.select(0)
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	var context: Dictionary = scene.get("_current_non_battle_layout_context")
	var min_button_height := float(context.get("secondary_button_height", 104.0))
	var min_button_font := int(context.get("button_font_size", 33))
	var min_body_font := int(context.get("body_font_size", 27))
	var dynamic_label := scene.find_child("DynamicStadiumBackgroundLabel", true, false) as Label
	var dynamic_on := scene.find_child("DynamicStadiumBackgroundOnButton", true, false) as Button
	var ai_status_title := scene.find_child("AIModeStatusTitle", true, false) as Label
	var ai_status_body := scene.find_child("AIModeStatusBody", true, false) as Label
	var ai_strategy_label := scene.find_child("AIStrategyLabel", true, false) as Label
	var ai_strategy_segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var ai_strategy_button := ai_strategy_segment.get_child(0) as Button if ai_strategy_segment != null and ai_strategy_segment.get_child_count() > 0 else null
	var result := run_checks([
		assert_true(dynamic_label != null and dynamic_label.get_theme_font_size("font_size") >= min_body_font, "Portrait AI refresh should keep dynamic stadium label phone-readable"),
		assert_true(dynamic_on != null and dynamic_on.custom_minimum_size.y >= min_button_height, "Portrait AI refresh should keep dynamic stadium buttons touch-sized"),
		assert_true(dynamic_on != null and dynamic_on.get_theme_font_size("font_size") >= min_button_font, "Portrait AI refresh should keep dynamic stadium button text phone-readable"),
		assert_true(ai_status_title != null and ai_status_title.visible and ai_status_title.get_theme_font_size("font_size") >= min_body_font, "Portrait AI refresh should keep AI status title phone-readable"),
		assert_true(ai_status_body != null and ai_status_body.visible and ai_status_body.get_theme_font_size("font_size") >= min_body_font, "Portrait AI refresh should keep AI status body phone-readable"),
		assert_true(ai_strategy_label != null and ai_strategy_label.visible and ai_strategy_label.get_theme_font_size("font_size") >= min_body_font, "Portrait AI refresh should keep AI strategy label phone-readable"),
		assert_true(ai_strategy_button != null and ai_strategy_button.custom_minimum_size.y >= min_button_height, "Portrait AI refresh should size newly rebuilt AI strategy buttons for touch"),
		assert_true(ai_strategy_button != null and ai_strategy_button.get_theme_font_size("font_size") >= min_button_font, "Portrait AI refresh should size newly rebuilt AI strategy button text for phones"),
	])
	scene.queue_free()
	return result


func test_battle_setup_landscape_ai_mode_refresh_keeps_deck_names_compact() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "BattleSetup should expose _apply_non_battle_layout_for_tests for landscape verification"
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	var player_deck := DeckData.new()
	player_deck.id = 960401
	player_deck.deck_name = "Landscape Player Probe"
	player_deck.total_cards = 60
	var ai_deck := DeckData.new()
	ai_deck.id = 575720
	ai_deck.deck_name = "Landscape Miraidon AI Probe"
	ai_deck.total_cards = 60
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [ai_deck])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	if deck1_option != null:
		deck1_option.clear()
		deck1_option.add_item(player_deck.deck_name)
		deck1_option.set_item_metadata(0, player_deck.id)
		deck1_option.select(0)
	if deck2_option != null:
		deck2_option.clear()
		deck2_option.add_item(ai_deck.deck_name)
		deck2_option.set_item_metadata(0, ai_deck.id)
		deck2_option.select(0)
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	var deck1_picker := scene.find_child("Deck1PickerButton", true, false) as Button
	var deck2_picker := scene.find_child("Deck2PickerButton", true, false) as Button
	var result := run_checks([
		assert_true(deck1_picker != null and deck1_picker.custom_minimum_size.y <= 68.0, "Landscape AI refresh should keep player deck picker compact"),
		assert_true(deck2_picker != null and deck2_picker.custom_minimum_size.y <= 68.0, "Landscape AI refresh should keep AI deck picker compact"),
		assert_true(deck1_picker != null and deck1_picker.get_theme_font_size("font_size") <= 20, "Landscape AI refresh should not enlarge player deck names"),
		assert_true(deck2_picker != null and deck2_picker.get_theme_font_size("font_size") <= 20, "Landscape AI refresh should not enlarge AI deck names"),
	])
	scene.queue_free()
	return result


func test_battle_setup_portrait_deck_button_opens_large_picker_after_reparenting() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		_dispose_scene(scene)
		return "BattleSetup should expose _apply_non_battle_layout_for_tests for portrait verification"
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		_dispose_scene(scene)
		return "SceneTree root should be available for the deck picker input test"
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var deck1 := DeckData.new()
	deck1.id = 950201
	deck1.deck_name = "Charizard Pidgeot Entry Probe"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 950202
	deck2.deck_name = "Lugia Entry Probe"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])
	var deck_option := scene.find_child("Deck1Option", true, false) as OptionButton
	if deck_option != null:
		deck_option.clear()
		deck_option.add_item(deck1.deck_name)
		deck_option.set_item_metadata(0, deck1.id)
		deck_option.select(0)
	scene.call("_sync_deck_picker_button", 0)
	var setup_deck_button := scene.find_child("Deck1PickerButton", true, false) as Button
	if setup_deck_button != null:
		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.position = setup_deck_button.get_global_rect().get_center()
		setup_deck_button.gui_input.emit(release)
	var overlay := scene.get("_deck_picker_overlay") as Control
	var panel := scene.get("_deck_picker_panel") as PanelContainer
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var action_row := scene.find_child("ActionRow", true, false) as Control
	var result := run_checks([
		assert_true(setup_deck_button != null and setup_deck_button.get_parent() == scene.find_child("LeftVBox", true, false), "Portrait deck button should stay in the full-width reparented slot"),
		assert_true(overlay != null and overlay.visible, "Pressing the reparented portrait deck button should open the deck picker"),
		assert_true(overlay != null and action_row != null and overlay.z_index > action_row.z_index, "Deck picker overlay should render above the fixed portrait footer"),
		assert_true(panel != null and panel.custom_minimum_size.x >= 1000.0, "Deck picker opened from the portrait deck button should be phone-width"),
		assert_true(panel != null and panel.custom_minimum_size.y >= 2300.0, "Deck picker opened from the portrait deck button should be phone-height"),
		assert_true(grid != null and grid.columns == 1, "Deck picker opened from the portrait deck button should use a one-column phone list"),
	])
	_dispose_scene(scene)
	return result


func test_battle_setup_portrait_deck_picker_uses_large_mobile_controls() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "BattleSetup should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var deck1 := DeckData.new()
	deck1.id = 950101
	deck1.deck_name = "Charizard Pidgeot Portrait Probe"
	deck1.total_cards = 60
	deck1.updated_at = 3000
	var deck2 := DeckData.new()
	deck2.id = 950102
	deck2.deck_name = "Lugia Portrait Probe"
	deck2.total_cards = 60
	deck2.updated_at = 2000
	scene.set("_deck_list", [deck1, deck2])
	scene.set("_deck_usage_stats", {
		str(deck1.id): {"use_count": 1, "last_used": "2026-06-16T12:00:00"},
	})
	var deck_option := scene.find_child("Deck1Option", true, false) as OptionButton
	if deck_option != null:
		deck_option.clear()
		deck_option.add_item(deck1.deck_name)
		deck_option.set_item_metadata(0, deck1.id)
		deck_option.select(0)
	scene.call("_sync_deck_picker_button", 0)
	var setup_deck_button := scene.find_child("Deck1PickerButton", true, false) as Button
	scene.set("_deck_picker_slot_index", 0)
	scene.set("_deck_picker_category", "all")
	scene.set("_deck_picker_search", "")
	scene.call("_ensure_deck_picker_overlay")
	scene.call("_refresh_deck_picker")
	scene.call("_resize_deck_picker_panel")
	var panel := scene.get("_deck_picker_panel") as PanelContainer
	var search_input := scene.get("_deck_picker_search_input") as LineEdit
	var tabs := scene.get("_deck_picker_tabs") as Dictionary
	var all_tab := tabs.get("all", null) as Button
	var recent_tab := tabs.get("recent", null) as Button
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var first_card_button := grid.get_child(0) as Button if grid != null and grid.get_child_count() > 0 else null
	var close_button := panel.find_child("DeckPickerCloseButton", true, false) as Button if panel != null else null
	var scroll := panel.find_child("DeckPickerScroll", true, false) as ScrollContainer if panel != null else null
	scene.call("_close_deck_picker")
	var post_close_release := InputEventScreenTouch.new()
	post_close_release.pressed = false
	post_close_release.position = Vector2(540, 520)
	var suppresses_release_tail := bool(scene.call("_handle_deck_picker_modal_input", post_close_release))
	var result := run_checks([
		assert_true(panel != null and panel.custom_minimum_size.x >= 1000.0, "Battle setup portrait deck picker should use nearly the full Android portrait width"),
		assert_true(panel != null and panel.size.x >= 1000.0, "Battle setup portrait deck picker should explicitly lay out near full width instead of relying on desktop centering"),
		assert_true(panel != null and panel.custom_minimum_size.y >= 2300.0, "Battle setup portrait deck picker should be a tall mobile selector instead of a desktop dialog"),
		assert_true(setup_deck_button != null and setup_deck_button.custom_minimum_size.y >= 185.0, "Battle setup portrait selected deck button should stay large after syncing the deck name"),
		assert_true(setup_deck_button != null and setup_deck_button.get_theme_font_size("font_size") >= 53, "Battle setup portrait selected deck button text should stay large after selecting a deck"),
		assert_true(search_input != null and search_input.custom_minimum_size.y >= 155.0, "Battle setup portrait deck picker search should be large enough for phone typing"),
		assert_true(search_input != null and search_input.get_theme_font_size("font_size") >= 45, "Battle setup portrait deck picker search text should scale for Android"),
		assert_true(all_tab != null and all_tab.custom_minimum_size.y >= 165.0, "Battle setup portrait deck picker tabs should be large touch targets"),
		assert_true(recent_tab != null and recent_tab.get_theme_font_size("font_size") >= 53, "Battle setup portrait deck picker tab text should be readable on phones"),
		assert_true(grid != null and grid.columns == 1, "Battle setup portrait deck picker should use a single-column phone list"),
		assert_true(scroll != null and scroll.custom_minimum_size.y >= 720.0, "Battle setup portrait deck picker should reserve enough height for the deck list"),
		assert_true(first_card_button != null and first_card_button.custom_minimum_size.y >= 275.0, "Battle setup portrait deck picker deck rows should be large touch targets"),
		assert_true(first_card_button != null and first_card_button.get_theme_font_size("font_size") >= 53, "Battle setup portrait deck picker deck names should be phone-readable"),
		assert_true(first_card_button != null and bool(first_card_button.get_meta("_non_battle_touch_bound", false)), "Battle setup portrait deck picker dynamic deck rows should use the Android touch bridge"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 165.0, "Battle setup portrait deck picker close button should be touch-sized"),
		assert_true(suppresses_release_tail, "Battle setup portrait deck picker should swallow the release tail after closing so it cannot tap the deck button underneath"),
	])
	scene.queue_free()
	return result


func test_battle_setup_portrait_bgm_slider_footer_and_strategy_dialog_are_touch_sized() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test()
	var previous_track := GameManager.selected_battle_music_id
	var previous_volume := int(GameManager.battle_bgm_volume_percent)
	var previous_non_battle_mode := str(GameManager.non_battle_layout_mode)
	GameManager.selected_battle_music_id = "none"
	GameManager.battle_bgm_volume_percent = 20
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_PORTRAIT
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = BattleSetupScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		_dispose_scene(scene)
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		GameManager.selected_battle_music_id = previous_track
		GameManager.battle_bgm_volume_percent = previous_volume
		GameManager.non_battle_layout_mode = previous_non_battle_mode
		_restore_battle_review_config_file(snapshot)
		return "BattleSetup should expose _apply_non_battle_layout_for_tests for portrait verification"
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		_dispose_scene(scene)
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		GameManager.selected_battle_music_id = previous_track
		GameManager.battle_bgm_volume_percent = previous_volume
		GameManager.non_battle_layout_mode = previous_non_battle_mode
		_restore_battle_review_config_file(snapshot)
		return "SceneTree root should be available for the battle setup portrait test"
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var available_decks: Array = scene.get("_deck_list")
	if available_decks.size() < 2:
		scene.call("_refresh_deck_options")
		available_decks = scene.get("_deck_list")
	if available_decks.size() < 2:
		_dispose_scene(scene)
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		GameManager.selected_battle_music_id = previous_track
		GameManager.battle_bgm_volume_percent = previous_volume
		GameManager.non_battle_layout_mode = previous_non_battle_mode
		_restore_battle_review_config_file(snapshot)
		return "Battle setup portrait strategy discussion test needs at least two loaded decks"
	var deck1 := available_decks[0] as DeckData
	var deck2 := available_decks[1] as DeckData
	scene.set("_deck_list", [deck1, deck2])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	if deck1_option != null and deck2_option != null:
		deck1_option.clear()
		deck2_option.clear()
		deck1_option.add_item(deck1.deck_name)
		deck1_option.set_item_metadata(0, deck1.id)
		deck1_option.select(0)
		deck2_option.add_item(deck2.deck_name)
		deck2_option.set_item_metadata(0, deck2.id)
		deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")
	var slider := scene.find_child("BgmVolumeSlider", true, false) as HSlider
	var slider_default_value := int(round(slider.value)) if slider != null else -1
	if slider != null:
		slider.value = 8.0
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.position = slider.get_global_rect().position + Vector2(slider.size.x * 0.84, slider.size.y * 0.5)
		scene.call("_input", press)
		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.position = press.position
		scene.call("_input", release)
	scene.call("_on_discuss_strategy_ai_pressed")
	var dialog := scene.get("_strategy_discussion_dialog") as AcceptDialog
	var send_button := dialog.get_node_or_null("%SendButton") as Button if dialog != null else null
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit if dialog != null else null
	var footer_spacer := scene.find_child("PortraitSetupFooterSpacer", true, false) as Control
	var action_row := scene.find_child("ActionRow", true, false) as Control
	var bgm_option := scene.find_child("BgmOption", true, false) as OptionButton
	var selected_deck1: Variant = scene.call("_selected_deck_for_slot", 0) if scene.has_method("_selected_deck_for_slot") else null
	var selected_deck2: Variant = scene.call("_selected_deck_for_slot", 1) if scene.has_method("_selected_deck_for_slot") else null
	var strategy_dialog_size_message := "Strategy discussion popup opened from battle setup should use phone width in portrait (dialog=%s scene=%s meta=%s)" % [
		str(dialog.size if dialog != null else Vector2i.ZERO),
		str(scene.size),
		str(scene.get_meta("non_battle_layout_mode", "")),
	]
	var result := run_checks([
		assert_true(bgm_option != null and bgm_option.item_count > 1, "Battle setup portrait BGM selector should expose bundled battle tracks beyond no music"),
		assert_eq(slider_default_value, 20, "Battle setup portrait BGM volume should keep the shared 20% default before touch changes"),
		assert_true(slider != null and slider.value >= 78.0, "Battle setup BGM volume slider should update from Android ScreenTouch when mouse emulation is disabled"),
		assert_true(selected_deck1 != null and selected_deck2 != null, "Battle setup portrait reparented deck options should still resolve selected decks"),
		assert_true(footer_spacer != null and footer_spacer.custom_minimum_size.y >= 250.0, "High-density portrait battle setup should reserve enough scroll space above the fixed footer"),
		assert_true(action_row != null and action_row.global_position.y + action_row.size.y <= 2360.0, "Battle setup fixed footer should stay at the bottom without covering the content edge"),
		assert_true(dialog != null and dialog.size.x >= 1000, strategy_dialog_size_message),
		assert_true(dialog != null and dialog.size.y >= 1600, "Strategy discussion popup opened from battle setup should use phone height in portrait"),
		assert_true(send_button != null and send_button.custom_minimum_size.y >= 220.0, "Strategy discussion send button should be touch-sized in portrait"),
		assert_true(send_button != null and send_button.get_theme_font_size("font_size") >= 50, "Strategy discussion send button text should be phone-readable"),
		assert_true(question_input != null and question_input.get_theme_font_size("font_size") >= 46, "Strategy discussion input text should be phone-readable"),
	])
	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	GameManager.selected_battle_music_id = previous_track
	GameManager.battle_bgm_volume_percent = previous_volume
	GameManager.non_battle_layout_mode = previous_non_battle_mode
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_portrait_bgm_touch_opens_hud_picker_instead_of_native_popup() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var previous_non_battle_mode := str(GameManager.non_battle_layout_mode)
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		_dispose_scene(scene)
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		GameManager.non_battle_layout_mode = previous_non_battle_mode
		return "SceneTree root should be available for the battle setup BGM picker test"
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	scene.call("_ensure_battle_music_options_ready")
	var bgm_option := scene.find_child("BgmOption", true, false) as OptionButton
	if bgm_option == null or bgm_option.item_count < 2:
		_dispose_scene(scene)
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		GameManager.non_battle_layout_mode = previous_non_battle_mode
		return "Battle setup BGM picker test needs bundled battle music options"
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = bgm_option.get_global_rect().get_center()
	bgm_option.gui_input.emit(press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	bgm_option.gui_input.emit(release)

	var overlay := scene.get_node_or_null("BattleMusicPickerOverlay") as Control
	var scroll := scene.find_child("BattleMusicPickerScroll", true, false) as ScrollContainer
	var list := scene.find_child("BattleMusicPickerList", true, false) as VBoxContainer
	var vbar := scroll.get_v_scroll_bar() if scroll != null else null
	var native_popup_visible := bgm_option.get_popup().visible if bgm_option.get_popup() != null else false
	var overlay_visible_before_select := overlay != null and overlay.visible
	var target_button := scene.find_child("BattleMusicPickerItem1", true, false) as Button
	if target_button != null:
		var item_press := InputEventScreenTouch.new()
		item_press.pressed = true
		item_press.position = target_button.get_global_rect().get_center()
		target_button.gui_input.emit(item_press)
		var item_release := InputEventScreenTouch.new()
		item_release.pressed = false
		item_release.position = item_press.position
		target_button.gui_input.emit(item_release)
	var selected_index := bgm_option.selected
	var overlay_hidden_after_select := overlay != null and not overlay.visible

	var result := run_checks([
		assert_true(overlay_visible_before_select, "Battle setup portrait BGM touch should open the HUD music picker"),
		assert_false(native_popup_visible, "Battle setup portrait BGM touch should not open Godot's native OptionButton popup"),
		assert_true(scroll != null and str(scroll.get_meta("hud_scrollbar_profile", "")) == "portrait_touch", "Battle setup portrait BGM picker should use the large touch scrollbar profile"),
		assert_true(vbar != null and vbar.custom_minimum_size.x >= 104.0, "Battle setup portrait BGM picker scrollbar should be wide enough to drag"),
		assert_true(list != null and list.get_child_count() == bgm_option.item_count, "Battle setup portrait BGM picker should mirror every music option"),
		assert_true(selected_index == 1, "Selecting a BGM picker row should update the underlying BGM option"),
		assert_true(overlay_hidden_after_select, "Selecting a BGM picker row should hide the picker overlay"),
	])
	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	GameManager.non_battle_layout_mode = previous_non_battle_mode
	return result


func test_deck_manager_portrait_layout_uses_vertical_deck_cards_without_editor_changes() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "DeckManager should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	var import_button := scene.get_node_or_null("%BtnImport") as Button
	var deck := DeckData.new()
	deck.id = 909001
	deck.deck_name = "Portrait Test Deck"
	deck.total_cards = 60
	var row := scene.call("_create_deck_item", deck) as Control
	var button_grid := row.find_child("DeckRowButtonGrid", true, false) as GridContainer
	var result := run_checks([
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 84.0, "Deck center portrait import button should be comfortably phone-sized"),
		assert_not_null(button_grid, "Deck center portrait deck row should put actions into a vertical-friendly grid"),
		assert_true(button_grid != null and button_grid.columns == 2, "Deck center portrait deck row should use a 2x2 action grid"),
		assert_true(row != null and row.custom_minimum_size.y >= 220.0, "Deck center portrait deck rows should allocate enough height for large 2x2 actions"),
	])
	row.queue_free()
	scene.queue_free()
	return result


func test_deck_manager_portrait_deck_scroll_accepts_android_drag_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = DeckManagerScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		return "DeckManager should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var deck_scroll := scene.find_child("DeckScroll", true, false) as ScrollContainer
	var deck_list := scene.get_node("%DeckList") as VBoxContainer
	for i: int in 12:
		var row := PanelContainer.new()
		row.name = "PortraitScrollableDeckProbe%d" % i
		row.custom_minimum_size = Vector2(0, 260)
		deck_list.add_child(row)
	if deck_scroll != null:
		deck_scroll.position = Vector2(40, 220)
		deck_scroll.size = Vector2(1000, 1200)
		deck_scroll.custom_minimum_size = Vector2(1000, 1200)
	var vbar := deck_scroll.get_v_scroll_bar() if deck_scroll != null else null
	if vbar != null:
		vbar.visible = true
		vbar.position = Vector2(916, 0)
		vbar.size = Vector2(84, 1200)
		vbar.custom_minimum_size = Vector2(84, 1200)
		vbar.min_value = 0.0
		vbar.max_value = 3200.0
		vbar.page = 1200.0

	var handled_bar_press := false
	var handled_bar_drag := false
	var handled_bar_release := false
	if vbar != null:
		var bar_press := InputEventScreenTouch.new()
		bar_press.pressed = true
		bar_press.position = vbar.get_global_rect().position + Vector2(42, 780)
		handled_bar_press = bool(NonBattleTouchBridgeScript.handle_root_touch(scene, bar_press))
		var bar_drag := InputEventScreenDrag.new()
		bar_drag.position = vbar.get_global_rect().position + Vector2(42, 960)
		handled_bar_drag = bool(NonBattleTouchBridgeScript.handle_root_touch(scene, bar_drag))
		var bar_release := InputEventScreenTouch.new()
		bar_release.pressed = false
		bar_release.position = bar_drag.position
		handled_bar_release = bool(NonBattleTouchBridgeScript.handle_root_touch(scene, bar_release))
	var bar_value_after_drag := vbar.value if vbar != null else 0.0

	if deck_scroll != null:
		deck_scroll.scroll_vertical = 120
	var start_scroll := deck_scroll.scroll_vertical if deck_scroll != null else 0
	var handled_surface_press := false
	var handled_surface_drag := false
	var handled_surface_release := false
	if deck_scroll != null:
		var surface_press := InputEventScreenTouch.new()
		surface_press.pressed = true
		surface_press.position = deck_scroll.get_global_rect().position + Vector2(420, 900)
		handled_surface_press = bool(NonBattleTouchBridgeScript.handle_root_touch(scene, surface_press))
		var surface_drag := InputEventScreenDrag.new()
		surface_drag.position = surface_press.position - Vector2(0, 260)
		handled_surface_drag = bool(NonBattleTouchBridgeScript.handle_root_touch(scene, surface_drag))
		var surface_release := InputEventScreenTouch.new()
		surface_release.pressed = false
		surface_release.position = surface_drag.position
		handled_surface_release = bool(NonBattleTouchBridgeScript.handle_root_touch(scene, surface_release))
	var final_scroll := deck_scroll.scroll_vertical if deck_scroll != null else 0

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	var result := run_checks([
		assert_true(deck_scroll != null, "Deck center portrait should expose its main DeckScroll container"),
		assert_true(vbar != null, "Deck center portrait should keep a right-side vertical scrollbar"),
		assert_true(handled_bar_press and handled_bar_drag and handled_bar_release, "Deck center portrait right scrollbar should respond to Android ScreenTouch drag without mouse emulation"),
		assert_true(bar_value_after_drag > 0.0, "Dragging the DeckScroll right scrollbar should update its value"),
		assert_true(handled_surface_press and handled_surface_drag and handled_surface_release, "Deck center portrait list surface should respond to Android ScreenTouch drag without mouse emulation"),
		assert_true(final_scroll > start_scroll, "Dragging upward on the Deck center list should move the vertical scroll"),
	])
	scene.queue_free()
	return result


func test_deck_manager_portrait_recommendation_card_and_detail_are_phone_readable() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "DeckManager should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var recommendation := {
		"id": "portrait-recommendation-probe",
		"deck_id": 990101,
		"deck_name": "Portrait Recommendation Probe",
		"title": "A readable deck recommendation for phone users",
		"style_summary": "Short summary text that should not render at desktop sizes on Android portrait.",
		"why_play": ["The card should be readable without zooming.", "Actions should be large enough to tap."],
		"best_for": "Players testing the portrait deck center.",
		"pilot_tip": "Keep the recommendation detail readable.",
		"import_url": "https://tcg.mik.moe/decks/list/990101",
		"source": {"label": "Test", "event": "Portrait"},
		"detail": {
			"sections": [{
				"heading": "Plan",
				"body": "The recommendation detail overlay should use phone-scale text and buttons.",
				"bullets": ["Avoid compact desktop body copy.", "Reserve room for the large scrollbar."],
			}],
		},
	}
	scene.set("_current_recommendation", recommendation)
	scene.call("_ensure_recommendation_section")
	scene.call("_refresh_recommendation_cards")
	var card := scene.find_child("RecommendationFeedCard", true, false) as PanelContainer
	var deck_label := scene.find_child("RecommendationDeckName", true, false) as Label
	var read_button := scene.find_child("RecommendationDetailButton", true, false) as Button
	var import_button := scene.find_child("RecommendationImportButton", true, false) as Button
	scene.call("_show_recommendation_article_dialog", recommendation)
	var detail_panel := scene.find_child("RecommendationDetailPanel", true, false) as PanelContainer
	var detail_scroll := scene.find_child("RecommendationDetailScroll", true, false) as ScrollContainer
	var detail_content := scene.find_child("RecommendationDetailContent", true, false) as VBoxContainer
	var first_detail_label := detail_content.get_child(0) as Label if detail_content != null and detail_content.get_child_count() > 0 else null
	var detail_footer_button := scene.find_child("RecommendationDetailCloseButton", true, false) as Button
	var result := run_checks([
		assert_true(card != null and card.custom_minimum_size.y >= 420.0, "Portrait deck recommendation card should grow beyond the desktop compact height"),
		assert_true(deck_label != null and deck_label.get_theme_font_size("font_size") >= 50, "Portrait deck recommendation title should be phone-readable"),
		assert_true(read_button != null and read_button.custom_minimum_size.y >= 145.0, "Portrait recommendation read button should be touch-sized"),
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 145.0, "Portrait recommendation import button should be touch-sized"),
		assert_true(detail_panel != null and detail_panel.custom_minimum_size.x >= 1000.0, "Portrait recommendation detail should use nearly the full phone width"),
		assert_true(detail_panel != null and detail_panel.custom_minimum_size.y >= 2240.0, "Portrait recommendation detail should use nearly the full phone height"),
		assert_true(detail_scroll != null and str(detail_scroll.get_meta("hud_scrollbar_profile", "")) == "portrait_touch", "Portrait recommendation detail should use a large touch scrollbar"),
		assert_true(first_detail_label != null and first_detail_label.get_theme_font_size("font_size") >= 44, "Portrait recommendation detail text should be phone-readable"),
		assert_true(detail_footer_button != null and detail_footer_button.custom_minimum_size.y >= 145.0, "Portrait recommendation detail footer buttons should be touch-sized"),
	])
	scene.queue_free()
	return result


func test_tournament_pages_portrait_layouts_are_single_column() -> String:
	var scenes: Array[Control] = [
		TournamentDeckSelectScene.instantiate(),
		TournamentSetupScene.instantiate(),
		TournamentOverviewScene.instantiate(),
		TournamentStandingsScene.instantiate(),
	]
	var checks: Array[String] = []
	for scene: Control in scenes:
		if not scene.has_method("_apply_non_battle_layout_for_tests"):
			checks.append("%s should expose _apply_non_battle_layout_for_tests for portrait verification" % scene.name)
			scene.queue_free()
			continue
		scene.call("_ready")
		scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
		var panel := scene.find_child("Panel", true, false) as Control
		var primary_button := scene.find_child("BtnNext", true, false) as Button
		if primary_button == null:
			primary_button = scene.find_child("BtnStart", true, false) as Button
		if primary_button == null:
			primary_button = scene.find_child("BtnStartRound", true, false) as Button
		if primary_button == null:
			primary_button = scene.find_child("BtnPrimary", true, false) as Button
		checks.append(assert_true(panel != null and panel.custom_minimum_size.x <= 430.0, "%s portrait panel should fit a phone-width viewport" % scene.name))
		checks.append(assert_true(primary_button != null and primary_button.custom_minimum_size.y >= 84.0, "%s portrait primary action should be comfortably phone-sized" % scene.name))
		if scene.name == "TournamentOverview":
			var stack := scene.find_child("PortraitTournamentStack", true, false) as VBoxContainer
			checks.append(assert_not_null(stack, "TournamentOverview portrait layout should replace the horizontal middle row with a vertical stack"))
		scene.queue_free()
	return run_checks(checks)


func test_tournament_deck_picker_portrait_dialog_uses_phone_dimensions() -> String:
	var scene: Control = TournamentDeckSelectScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1080, 2400)
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	scene.call("_ensure_deck_picker_overlay")
	scene.call("_resize_deck_picker_panel")
	var panel := scene.find_child("DeckPickerPanel", true, false) as PanelContainer
	var search := scene.find_child("DeckPickerSearchInput", true, false) as LineEdit
	var title := scene.find_child("DeckPickerTitle", true, false) as Label
	var result := run_checks([
		assert_true(panel != null and panel.custom_minimum_size.x >= 1000.0, "Tournament deck picker should use nearly the full high-density portrait width"),
		assert_true(panel != null and panel.custom_minimum_size.y >= 2200.0, "Tournament deck picker should use nearly the full high-density portrait height"),
		assert_true(search != null and search.custom_minimum_size.y >= 145.0, "Tournament deck picker search input should be phone-sized"),
		assert_true(search != null and search.get_theme_font_size("font_size") >= 50, "Tournament deck picker search text should be phone-readable"),
		assert_true(title != null and title.get_theme_font_size("font_size") >= 60, "Tournament deck picker title should be phone-readable"),
	])
	scene.queue_free()
	return result


func test_tournament_setup_portrait_name_input_accepts_android_touch() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		return "SceneTree root should be available for the tournament setup touch regression"
	var scene: Control = TournamentSetupScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var name_edit := scene.find_child("NameEdit", true, false) as LineEdit
	if name_edit != null:
		var press := InputEventScreenTouch.new()
		press.pressed = true
		name_edit.gui_input.emit(press)
		var release := InputEventScreenTouch.new()
		release.pressed = false
		name_edit.gui_input.emit(release)
	var name_edit_focused_after_touch := name_edit != null and (name_edit.has_focus() or bool(name_edit.get_meta("_non_battle_touch_focus_requested", false)))
	var result := run_checks([
		assert_true(name_edit != null and name_edit.custom_minimum_size.y >= 145.0, "Tournament setup portrait name input should be large enough to tap"),
		assert_true(name_edit != null and name_edit.get_theme_font_size("font_size") >= 50, "Tournament setup portrait name input text should be phone-readable"),
		assert_true(name_edit_focused_after_touch, "Tournament setup NameEdit should focus from Android ScreenTouch without mouse emulation"),
	])
	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	return result


func test_tournament_setup_portrait_panel_and_hint_fill_phone_width() -> String:
	var scene: Control = TournamentSetupScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1080, 2400)
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var panel := scene.find_child("Panel", true, false) as Control
	var hint := scene.find_child("HintLabel", true, false) as Label
	var button_row := scene.find_child("ButtonRow", true, false) as BoxContainer
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var result := run_checks([
		assert_true(panel != null and panel.custom_minimum_size.x >= 1000.0, "Tournament setup portrait HUD should use nearly the full phone width"),
		assert_true(panel != null and panel.custom_minimum_size.y >= 2250.0, "Tournament setup portrait HUD should use nearly the full phone height"),
		assert_true(hint != null and hint.autowrap_mode != TextServer.AUTOWRAP_OFF, "Tournament setup hint copy should wrap inside the HUD"),
		assert_true(hint != null and hint.get_theme_font_size("font_size") >= 44, "Tournament setup hint copy should be phone-readable"),
		assert_true(button_row is VBoxContainer, "Tournament setup portrait actions should stack vertically instead of squeezing into a narrow row"),
		assert_true(start_button != null and start_button.custom_minimum_size.y >= 145.0, "Tournament setup primary action should be large enough for portrait touch"),
	])
	scene.queue_free()
	return result


func test_tournament_overview_portrait_text_panels_are_phone_readable() -> String:
	var scene: Control = TournamentOverviewScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1080, 2400)
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var meta := scene.find_child("MetaLabel", true, false) as RichTextLabel
	var distribution := scene.find_child("DistributionText", true, false) as TextEdit
	var roster := scene.find_child("RosterText", true, false) as TextEdit
	var stack := scene.find_child("PortraitTournamentStack", true, false) as VBoxContainer
	var result := run_checks([
		assert_not_null(stack, "Tournament overview high-density portrait should keep details in a vertical stack"),
		assert_true(meta != null and meta.get_theme_font_size("normal_font_size") >= 44, "Tournament overview meta text should be phone-readable"),
		assert_true(distribution != null and distribution.get_theme_font_size("font_size") >= 44, "Tournament overview distribution text should be phone-readable"),
		assert_true(roster != null and roster.get_theme_font_size("font_size") >= 44, "Tournament overview roster text should be phone-readable"),
		assert_true(distribution != null and distribution.custom_minimum_size.y >= 420.0, "Tournament overview distribution panel should allocate enough portrait height"),
		assert_true(roster != null and roster.custom_minimum_size.y >= 420.0, "Tournament overview roster panel should allocate enough portrait height"),
	])
	scene.queue_free()
	return result


func test_tournament_standings_portrait_text_panels_are_phone_readable() -> String:
	var scene: Control = TournamentStandingsScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1080, 2400)
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var summary := scene.find_child("SummaryText", true, false) as RichTextLabel
	var standings := scene.find_child("StandingsText", true, false) as TextEdit
	var primary := scene.find_child("BtnPrimary", true, false) as Button
	var result := run_checks([
		assert_true(summary != null and summary.get_theme_font_size("normal_font_size") >= 44, "Tournament standings summary text should be phone-readable"),
		assert_true(standings != null and standings.get_theme_font_size("font_size") >= 44, "Tournament standings table text should be phone-readable"),
		assert_true(standings != null and standings.custom_minimum_size.y >= 420.0, "Tournament standings table should allocate enough portrait height"),
		assert_true(primary != null and primary.custom_minimum_size.y >= 145.0, "Tournament standings primary action should stay touch-sized"),
	])
	scene.queue_free()
	return result


func test_replay_browser_portrait_rows_are_vertical_and_readable() -> String:
	var scene: Control = ReplayBrowserScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "ReplayBrowser should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.set("_record_index", FakeReplayIndex.new())
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_render_rows")
	var row_panel := scene.find_child("ReplayRowPanel", true, false) as PanelContainer
	var actions := scene.find_child("ReplayRowActions", true, false) as BoxContainer
	var replay_button := scene.find_child("ReplayButton", true, false) as Button
	var result := run_checks([
		assert_not_null(row_panel, "Replay browser portrait should render named row cards"),
		assert_true(actions is VBoxContainer, "Replay browser portrait row actions should stack vertically or full-width"),
		assert_true(replay_button != null and replay_button.custom_minimum_size.y >= 84.0, "Replay browser portrait replay button should be comfortably phone-sized"),
	])
	scene.queue_free()
	return result


func test_ai_settings_portrait_layout_stacks_form_and_guide_with_large_inputs() -> String:
	var scene: Control = SettingsScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "Settings should expose _apply_non_battle_layout_for_tests for portrait verification"
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	var stack := scene.find_child("PortraitSettingsStack", true, false) as VBoxContainer
	var endpoint := scene.find_child("EndpointInput", true, false) as LineEdit
	var save := scene.find_child("BtnSave", true, false) as Button
	var first_result := run_checks([
		assert_not_null(stack, "AI settings portrait layout should stack form and ZenMux guide vertically"),
		assert_true(endpoint != null and endpoint.custom_minimum_size.y >= 80.0, "AI settings portrait inputs should be large enough for phone typing"),
		assert_true(save != null and save.custom_minimum_size.y >= 92.0, "AI settings portrait save button should be comfortably phone-sized"),
	])
	if first_result != "":
		scene.queue_free()
		return first_result
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var root := scene.get_node_or_null("VBoxContainer") as Control
	var action_row := scene.find_child("HBox", true, false) as HBoxContainer
	var test_button := scene.find_child("BtnTest", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var back_pressed := [false]
	if back_button != null:
		back_button.pressed.connect(func() -> void:
			back_pressed[0] = true
		)
	var footer_release := InputEventScreenTouch.new()
	footer_release.pressed = false
	footer_release.position = back_button.get_global_rect().get_center() if back_button != null else Vector2.ZERO
	scene.call("_input", footer_release)
	var result := run_checks([
		assert_true(root != null and root.custom_minimum_size.x >= 1000.0, "AI settings high-density portrait panel should use most of the phone width"),
		assert_true(root != null and root.custom_minimum_size.y >= 2250.0, "AI settings high-density portrait panel should be tall enough for readable mobile content"),
		assert_true(action_row != null and action_row.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "AI settings portrait action row should fill the available width"),
		assert_eq(action_row.get_parent() if action_row != null else null, scene, "AI settings portrait action row should be a fixed footer outside the scrollable form"),
		assert_true(save != null and save.size_flags_horizontal == Control.SIZE_EXPAND_FILL and save.custom_minimum_size.y >= 145.0, "AI settings portrait save button should be wide and tall on Android portrait"),
		assert_true(test_button != null and test_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL and test_button.custom_minimum_size.y >= 145.0, "AI settings portrait test button should be wide and tall on Android portrait"),
		assert_true(back_button != null and back_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL and back_button.custom_minimum_size.y >= 145.0, "AI settings portrait back button should be wide and tall on Android portrait"),
		assert_true(endpoint != null and endpoint.custom_minimum_size.y >= 125.0, "AI settings high-density portrait inputs should scale up with the Android viewport"),
		assert_true(bool(back_pressed[0]), "AI settings fixed portrait footer should activate Back from an Android release event"),
	])
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	result = run_checks([
		result,
		assert_true(root != null and root.custom_minimum_size.y <= 600.0, "AI settings landscape panel should return to compact desktop height"),
		assert_true(back_button != null and back_button.custom_minimum_size.y <= 45.0, "AI settings landscape buttons should not retain portrait touch height"),
		assert_eq(action_row.get_parent() if action_row != null else null, root, "AI settings action row should return to the desktop form in landscape"),
	])
	scene.queue_free()
	return result


func test_ai_settings_portrait_scrollbar_is_visible_and_touch_sized() -> String:
	var scene: Control = SettingsScene.instantiate()
	if not scene.has_method("_apply_non_battle_layout_for_tests"):
		scene.queue_free()
		return "Settings should expose _apply_non_battle_layout_for_tests for portrait scrollbar verification"
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var scroll := scene.find_child("PortraitSettingsScroll", true, false) as ScrollContainer
	var vbar := scroll.get_v_scroll_bar() if scroll != null else null
	var visible_text_nodes: Array[Control] = []
	for node: Node in scene.find_children("*", "Control", true, false):
		if node is Label or node is LineEdit or node is Button or node is OptionButton:
			visible_text_nodes.append(node as Control)
	var has_null_instance_text := false
	for control: Control in visible_text_nodes:
		var text := ""
		if control is Label:
			text = (control as Label).text
		elif control is LineEdit:
			text = "%s %s" % [(control as LineEdit).text, (control as LineEdit).placeholder_text]
		elif control is Button:
			text = (control as Button).text
		elif control is OptionButton:
			text = (control as OptionButton).text
		if text.to_lower().find("instance base is null") >= 0:
			has_null_instance_text = true
			break
	var result := run_checks([
		assert_not_null(scroll, "AI settings portrait should expose a dedicated ScrollContainer"),
		assert_eq(scroll.vertical_scroll_mode if scroll != null else -1, ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "AI settings portrait should keep the right vertical scrollbar visible"),
		assert_true(scroll != null and str(scroll.get_meta("hud_scrollbar_profile", "")) == "portrait_touch", "AI settings portrait scroll should use the large touch scrollbar profile"),
		assert_true(vbar != null and int(vbar.get_meta("hud_scrollbar_thickness", 0)) >= 80, "AI settings portrait vertical scrollbar should be wide enough for touch"),
		assert_false(has_null_instance_text, "AI settings visible labels and inputs should never show 'instance base is null'"),
	])
	scene.queue_free()
	return result


func test_ai_settings_portrait_form_controls_accept_android_touch_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = SettingsScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	scene.call("_ready")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var endpoint := scene.find_child("EndpointInput", true, false) as LineEdit
	var model := scene.find_child("ModelOption", true, false) as OptionButton
	var default_endpoint_button := scene.find_child("BtnUseZenMuxDefault", true, false) as Button
	if endpoint != null:
		endpoint.global_position = Vector2(120, 320)
		endpoint.size = Vector2(760, 150)
	if model != null:
		model.global_position = Vector2(120, 520)
		model.size = Vector2(760, 150)
	if default_endpoint_button != null:
		default_endpoint_button.global_position = Vector2(120, 720)
		default_endpoint_button.size = Vector2(760, 150)
	var default_endpoint_pressed := [false]
	if default_endpoint_button != null:
		default_endpoint_button.pressed.connect(func() -> void:
			default_endpoint_pressed[0] = true
		)

	if endpoint != null:
		var endpoint_tap_position := endpoint.get_global_rect().get_center()
		var endpoint_press := InputEventScreenTouch.new()
		endpoint_press.pressed = true
		endpoint_press.position = endpoint_tap_position
		scene.call("_input", endpoint_press)
		var endpoint_release := InputEventScreenTouch.new()
		endpoint_release.pressed = false
		endpoint_release.position = endpoint_tap_position
		scene.call("_input", endpoint_release)
	var endpoint_focused_after_touch := endpoint != null and (endpoint.has_focus() or bool(endpoint.get_meta("_non_battle_touch_focus_requested", false)))

	var popup_visible_after_touch := false
	if model != null:
		var model_tap_position := model.get_global_rect().get_center()
		var model_press := InputEventScreenTouch.new()
		model_press.pressed = true
		model_press.position = model_tap_position
		scene.call("_input", model_press)
		var model_release := InputEventScreenTouch.new()
		model_release.pressed = false
		model_release.position = model_tap_position
		scene.call("_input", model_release)
		var immediate_popup := model.get_popup()
		popup_visible_after_touch = immediate_popup != null and immediate_popup.visible

	if default_endpoint_button != null:
		var button_tap_position := default_endpoint_button.get_global_rect().get_center()
		var button_press := InputEventScreenTouch.new()
		button_press.pressed = true
		button_press.position = button_tap_position
		scene.call("_input", button_press)
		var button_release := InputEventScreenTouch.new()
		button_release.pressed = false
		button_release.position = button_tap_position
		scene.call("_input", button_release)

	var popup := model.get_popup() if model != null else null
	if popup != null:
		popup.hide()
	var result := run_checks([
		assert_true(endpoint_focused_after_touch, "AI settings portrait EndpointInput should focus from Android ScreenTouch when mouse emulation is disabled"),
		assert_true(model != null and popup_visible_after_touch, "AI settings portrait ModelOption should open from Android ScreenTouch when mouse emulation is disabled"),
		assert_true(bool(default_endpoint_pressed[0]), "AI settings portrait helper buttons above the fixed footer should activate from Android ScreenTouch"),
	])
	scene.queue_free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	return result
