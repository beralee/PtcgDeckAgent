extends SceneTree
## Ordinary menu -> setup -> battle, using Viewport input and isolated preferences.

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	# Deferred menu/gallery layout must settle before sampling pointer coordinates.
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	var at := control.get_global_rect().get_center()
	print("ARENA_PRODUCT_CLICK ", control.get_path(), " at=", at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await create_timer(.3).timeout

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://%s.png" % label)

func wait_scene(path: String) -> bool:
	var manager := root.get_node("GameManager")
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and str(manager.get("_pending_scene_change_path")).is_empty():
			await process_frame
			return true
	return false

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	root.set_meta("performance_bench_offline", true)
	var manager := root.get_node("GameManager")
	manager.selected_battle_background = "res://assets/arena3d/previews/league.png"
	manager.goto_main_menu()
	assert(await wait_scene(manager.SCENE_MAIN_MENU), "Main menu becomes ready")
	await capture("arena-product-main-menu")
	await click(current_scene.get_node("%BtnStartBattle"))
	assert(await wait_scene(manager.SCENE_BATTLE_SETUP), "Battle setup becomes ready")
	assert(current_scene.find_child("BattlePresentationButton", true, false) == null)
	var field_path := "res://assets/arena3d/previews/grove.png"
	var row := current_scene.get_node("%BackgroundGalleryRow")
	assert(row.get_child_count() == 6, "Windows setup retains grove and all five classic backgrounds")
	var field := row.get_child(0) as Control
	assert(field.get_meta("background_path") == field_path)
	assert(current_scene.get("_selected_background_path") == field_path, "Removed selections resolve to the visible field")
	var badge := field.find_child("Field3DBadge", true, false) as Label
	var caption := field.find_child("FieldName", true, false) as Label
	assert(badge != null and badge.is_visible_in_tree())
	assert(caption != null and caption.text == "林间道馆")
	assert(field.get_global_rect().encloses(badge.get_global_rect()), "3D badge stays inside its field card")
	assert(field.get_global_rect().encloses(caption.get_global_rect()), "Field name stays inside its thumbnail")
	await click(field)
	# Old theme/toggle preferences must never override the selected field.
	var theme_script = load("res://scenes/arena3d/ArenaTheme.gd")
	var old_preferences := ConfigFile.new()
	old_preferences.set_value("visuals", "theme", "league")
	old_preferences.save("user://arena_visuals.cfg")
	theme_script.save_option("battle_3d", false)
	await capture("arena-field-setup-grove")
	await click(current_scene.get_node("%BtnStart"))
	assert(await wait_scene(manager.SCENE_BATTLE), "Battle becomes ready")
	assert(current_scene.has_node("Arena3DPresenter"), "The selected field opens 3D")
	var presenter := current_scene.get_node("Arena3DPresenter")
	assert(presenter.theme_id == "grove" and presenter.world.theme_id == "grove", "Both HUD and table use the retained field")
	for button: Button in presenter.ui_buttons:
		assert(not button.text.contains("⇄") and not button.text.contains("切换场景"), "The removed theme has no battle switch")
	await create_timer(.5).timeout
	await capture("arena-field-battle-grove")
	manager.goto_battle_setup()
	assert(await wait_scene(manager.SCENE_BATTLE_SETUP), "Setup reopens after battle")
	assert(current_scene.get("_selected_background_path") == field_path, "Reopening setup restores the saved field")
	assert(current_scene.get_node("%BackgroundGalleryRow").get_child_count() == 6)
	# The original first 2D field follows grove; stale 3D preferences cannot override it.
	var classic := current_scene.get_node("%BackgroundGalleryRow").get_child(1) as Control
	assert(classic.get_meta("background_path") == "res://assets/ui/background.png")
	assert(classic.find_child("Field3DBadge", true, false) == null)
	await click(classic)
	assert(current_scene.get("_selected_background_path") == "res://assets/ui/background.png")
	theme_script.save_option("battle_3d", true)
	await click(current_scene.get_node("%BtnStart"))
	assert(await wait_scene(manager.SCENE_BATTLE), "Classic battle becomes ready")
	assert(not current_scene.has_node("Arena3DPresenter"), "Selecting a classic background opens a 2D battle")
	# Finish the classic background's opening transition before navigating away.
	await create_timer(.6).timeout
	await capture("arena-integrated-2d")
	manager.goto_battle_setup()
	assert(await wait_scene(manager.SCENE_BATTLE_SETUP), "Setup reopens after classic battle")
	assert(current_scene.get("_selected_background_path") == "res://assets/ui/background.png", "Reopening setup preserves the selected 2D background")
	print("ARENA_PRODUCT_ENTRY_PASS: grove and five classic fields, real thumbnail, saved selections, actual 3D and 2D battles")
	current_scene.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await create_timer(.5).timeout
	quit()
