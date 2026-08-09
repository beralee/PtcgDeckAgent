class_name TestMainMenuStatusHeader
extends TestBase

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")
const MainMenuScene := preload("res://scenes/main_menu/MainMenu.tscn")


func test_portrait_status_header_keeps_version_and_update_above_actions() -> String:
	var scene := _build_main_menu(Vector2(1080, 2400), "portrait", true)
	var status_stack := scene.get_node_or_null("HomeStatusStack") as VBoxContainer
	var version_label := scene.find_child("VersionLabel", true, false) as Label
	var update_button := scene.find_child("UpdateButton", true, false) as Button
	var menu := scene.get_node_or_null("VBoxContainer") as VBoxContainer
	var menu_top := 1200.0 + menu.offset_top if menu != null else 0.0
	var result := run_checks([
		assert_not_null(status_stack, "Portrait home should expose the top status stack"),
		assert_true(status_stack != null and status_stack.anchor_top == 0.0 and status_stack.anchor_bottom == 0.0, "Portrait status content must be top anchored"),
		assert_true(status_stack != null and status_stack.offset_top >= 20.0 and status_stack.offset_bottom < menu_top, "Portrait status content must stay above the action stack"),
		assert_true(version_label != null and version_label.get_parent() == status_stack, "Portrait version should be inside the top status stack"),
		assert_true(update_button != null and update_button.get_parent() == status_stack, "Portrait update reminder should be inside the top status stack"),
		assert_true(update_button != null and update_button.visible, "The mocked available update should be visible"),
	])
	scene.free()
	return result


func test_landscape_status_header_keeps_version_and_update_above_actions() -> String:
	var scene := _build_main_menu(Vector2(1600, 900), "landscape", true)
	var status_stack := scene.get_node_or_null("HomeStatusStack") as VBoxContainer
	var version_label := scene.find_child("VersionLabel", true, false) as Label
	var update_button := scene.find_child("UpdateButton", true, false) as Button
	var menu := scene.get_node_or_null("VBoxContainer") as VBoxContainer
	var menu_top := 450.0 + menu.offset_top if menu != null else 0.0
	var result := run_checks([
		assert_true(status_stack != null and status_stack.anchor_top == 0.0 and status_stack.anchor_bottom == 0.0, "Landscape status content must remain top anchored"),
		assert_true(status_stack != null and status_stack.offset_top >= 20.0 and status_stack.offset_bottom < menu_top, "Landscape status content must stay above the action stack"),
		assert_true(version_label != null and version_label.get_parent() == status_stack, "Landscape version should not return to the footer"),
		assert_true(update_button != null and update_button.get_parent() == status_stack, "Landscape update reminder should share the top status stack"),
		assert_true(update_button != null and update_button.custom_minimum_size.y >= 44.0, "Landscape update reminder must stay clickable"),
	])
	scene.free()
	return result


func test_mock_update_events_show_deduplicate_and_clear_top_reminder() -> String:
	var scene := _build_main_menu(Vector2(1080, 2400), "portrait", false)
	var update_info := {
		"latest_version": "0.5.4",
		"display_version": "v0.5.4",
		"notification_source": "cache",
	}
	scene.call("_on_update_available", update_info)
	var update_button := scene.find_child("UpdateButton", true, false) as Button
	var visible_after_cache := update_button != null and update_button.visible
	var text_after_cache := update_button.text if update_button != null else ""
	scene.call("_on_update_available", update_info.merged({"notification_source": "network"}, true))
	var text_after_duplicate := update_button.text if update_button != null else ""
	scene.call("_on_no_update", {
		"latest_version": AppVersionScript.current_version(),
		"display_version": AppVersionScript.current_display_version(),
		"notification_source": "network",
	})
	var result := run_checks([
		assert_true(visible_after_cache, "A cached mock update should immediately show the top reminder"),
		assert_str_contains(text_after_cache, "v0.5.4", "The reminder should identify the available version"),
		assert_eq(text_after_duplicate, text_after_cache, "The same network result should keep stable reminder copy"),
		assert_true(update_button != null and not update_button.visible, "A mocked current-version response should clear the reminder"),
	])
	scene.free()
	return result


func _build_main_menu(viewport_size: Vector2, mode: String, update_visible: bool) -> Control:
	var scene: Control = MainMenuScene.instantiate()
	scene.size = viewport_size
	scene.call("_apply_main_menu_hud")
	scene.call("_ensure_update_button")
	var update_button := scene.find_child("UpdateButton", true, false) as Button
	if update_button != null:
		update_button.visible = update_visible
	scene.call("_apply_non_battle_layout_for_tests", viewport_size, mode)
	return scene
