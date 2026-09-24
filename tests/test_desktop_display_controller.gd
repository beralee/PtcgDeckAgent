extends TestBase

const ControllerScript := preload("res://scripts/ui/runtime/DesktopDisplayController.gd")


func test_dpi_drives_first_window_without_exceeding_usable_screen() -> String:
	return run_checks([
		assert_eq(ControllerScript.initial_window_size(Vector2i(1600, 900), 96, Vector2i(1920, 1080)), Vector2i(1600, 900), "100% DPI keeps the design window"),
		assert_eq(ControllerScript.initial_window_size(Vector2i(1600, 900), 144, Vector2i(2560, 1440)), Vector2i(2304, 1296), "150% DPI enlarges the window up to 90% of usable screen"),
		assert_eq(ControllerScript.initial_window_size(Vector2i(1600, 900), 192, Vector2i(3840, 2160)), Vector2i(3200, 1800), "4K 200% starts with the design logical canvas"),
		assert_eq(ControllerScript.system_scale_for_dpi(0), 1.0, "Invalid DPI falls back to one"),
	])


func test_saved_window_is_clamped_to_visible_monitor_after_disconnect() -> String:
	var visible: Rect2i = ControllerScript.visible_window_rect(Vector2i(4000, 2500), Vector2i(1800, 1000), Rect2i(Vector2i(0, 0), Vector2i(1920, 1080)))
	return run_checks([
		assert_eq(visible, Rect2i(Vector2i(120, 80), Vector2i(1800, 1000)), "A saved offscreen window should remain full sized and visible"),
	])


func test_user_scale_and_system_dpi_keep_minimum_logical_space() -> String:
	return run_checks([
		assert_eq(ControllerScript.effective_ui_scale(96, 100, Vector2i(1600, 900)), 1.0, "1080p at 100% keeps normal UI"),
		assert_eq(ControllerScript.effective_ui_scale(144, 100, Vector2i(2304, 1296)), 1.5, "1440p at 150% Windows scaling gets crisp 150% UI"),
		assert_eq(ControllerScript.effective_ui_scale(192, 100, Vector2i(3200, 1800)), 2.0, "4K at 200% Windows scaling gets crisp 200% UI"),
		assert_eq(ControllerScript.effective_ui_scale(96, 125, Vector2i(1600, 900)), 1.25, "Manual scale applies on a 100% monitor"),
		assert_true(ControllerScript.effective_ui_scale(192, 150, Vector2i(1600, 900)) < 2.0, "A smaller saved window retains at least 900 by 520 logical pixels"),
	])


func test_invalid_display_settings_fall_back_without_touching_other_preferences() -> String:
	var path := ControllerScript.SETTINGS_PATH
	var existed := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_string(path) if existed else ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Could not open isolated desktop display preference file"
	file.store_string("{broken json")
	file.close()
	var controller: Node = ControllerScript.new()
	var fallback: Dictionary = controller.call("_load_settings")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "ui_scale_percent": 125, "normal_size": [1600, 900], "normal_position": [25, 30], "maximized": false}))
	file.close()
	var restored: Dictionary = controller.call("_load_settings")
	if existed:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	controller.free()
	return run_checks([
		assert_true(fallback.is_empty(), "Corrupt display preferences must use defaults"),
		assert_eq(int(restored.get("ui_scale_percent", 0)), 125, "Valid user scale should load without affecting other settings"),
	])
