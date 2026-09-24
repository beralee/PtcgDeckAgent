extends SceneTree

const PREF_PATH := "user://desktop_display.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Desktop display runtime test needs a native Windows window")
		quit(2)
		return
	var previous_file := FileAccess.get_file_as_string(PREF_PATH) if FileAccess.file_exists(PREF_PATH) else ""
	var had_file := FileAccess.file_exists(PREF_PATH)
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		printerr("GameManager was not loaded")
		quit(2)
		return
	var original_size := DisplayServer.window_get_size()
	var original_position := DisplayServer.window_get_position()
	var original_mode := DisplayServer.window_get_mode()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var test_size := Vector2i(mini(usable.size.x - 40, original_size.x + 160), mini(usable.size.y - 40, original_size.y + 90))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(test_size)
	await process_frame
	await process_frame
	manager.call("apply_non_battle_orientation_for_scene", "res://scenes/battle_setup/BattleSetup.tscn")
	manager.call("apply_battle_layout_orientation", "landscape")
	await process_frame
	await process_frame
	var same_size := DisplayServer.window_get_size() == test_size
	var native_canvas := root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_size == test_size
	var controller := manager.call("get_desktop_display_controller") as Node
	var initial_percent := int(controller.get("user_scale_percent")) if controller != null else -1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await process_frame
	await process_frame
	var normal_preserved: bool = controller != null and bool(controller.get("_normal_size") == test_size)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await process_frame
	var menu := load("res://scenes/main_menu/MainMenu.tscn").instantiate() as Control
	root.add_child(menu)
	menu.call("_show_display_settings")
	var choices := menu.find_child("DisplayScaleChoices", true, false) as OptionButton
	var popup_visible := choices != null and choices.item_count == 4
	if choices != null:
		choices.item_selected.emit(2)
	var setting_applied := controller != null and int(controller.get("user_scale_percent")) == 125
	if controller != null and initial_percent > 0:
		controller.call("set_user_scale", initial_percent)
	root.remove_child(menu)
	menu.queue_free()
	DisplayServer.window_set_size(original_size)
	DisplayServer.window_set_position(original_position)
	DisplayServer.window_set_mode(original_mode)
	await process_frame
	if controller != null:
		controller.set("_initialized", false)
	if had_file:
		var file := FileAccess.open(PREF_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(previous_file)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREF_PATH))
	if same_size and native_canvas and normal_preserved and popup_visible and setting_applied:
		print("PASS desktop window, native canvas, maximize restore, and display setting; screens=%d dpi=%d" % [DisplayServer.get_screen_count(), DisplayServer.screen_get_dpi(DisplayServer.window_get_current_screen())])
		quit(0)
	else:
		printerr("FAIL size=%s canvas=%s maximize=%s popup=%s setting=%s" % [same_size, native_canvas, normal_preserved, popup_visible, setting_applied])
		quit(1)
