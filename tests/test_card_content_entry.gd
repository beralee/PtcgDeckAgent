extends TestBase

const MainMenuScene := preload("res://scenes/main_menu/MainMenu.tscn")

func test_content_bootstrap_starts_before_card_database() -> String:
	var root := (Engine.get_main_loop() as SceneTree).root
	var bootstrap := root.get_node_or_null("CardContentBootstrap")
	var updater := root.get_node_or_null("CardContentUpdater")
	var database := root.get_node_or_null("CardDatabase")
	return run_checks([
		assert_not_null(bootstrap, "The player application must register the content bootstrap"),
		assert_not_null(updater, "The player application must register the content updater"),
		assert_true(bootstrap != null and database != null and bootstrap.get_index() < database.get_index(), "Content must mount before card classes load"),
	])

func test_explicitly_enabled_development_home_can_open_content_entry() -> String:
	var previous: Variant = ProjectSettings.get_setting("ptcgdap/card_content/enabled", false)
	ProjectSettings.set_setting("ptcgdap/card_content/enabled", true)
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = MainMenuScene.instantiate()
	tree.root.add_child(scene)
	# No startup telemetry/update network task is needed for a UI contract test.
	scene.set("_navigation_started", true)
	await tree.process_frame
	var result := ""
	var button := scene.get_node_or_null("CardContentUpdates") as Button
	if button == null:
		result = "The real main menu is missing its persistent card update entry"
	else:
		scene.call("_on_card_content_changed", {"state": "current"})
		for viewport_size: Vector2 in [Vector2(720, 1280), Vector2(1080, 2400), Vector2(1600, 900)]:
			scene.size = viewport_size
			scene.call("_apply_non_battle_layout_for_tests", viewport_size, "portrait" if viewport_size.y > viewport_size.x else "landscape")
			var rect := button.get_rect()
			if not button.visible or button.disabled or not Rect2(Vector2.ZERO, viewport_size).encloses(rect):
				result = "The card update entry is hidden or outside the home viewport: %s / %s" % [rect, viewport_size]
			if viewport_size.y > viewport_size.x and (button.custom_minimum_size.y < 100.0 or button.get_theme_font_size("font_size") < 27):
				result = "Phone card updates need readable text and a thumb-sized touch target, not the desktop defaults"
		button.pressed.emit()
		await tree.process_frame
		var panel := scene.get_node_or_null("CardContentUpdateOverlay") as Control
		if panel == null or not panel.visible:
			result = "The actual main menu button did not open the content panel"
		elif not panel.get("_check").visible or panel.get("_check").disabled:
			result = "The update panel must allow checking when no update is available"
		if panel != null:
			for name: String in ["_deck_center_new_badge", "_deck_training_new_badge"]:
				var badge := scene.get(name) as CanvasItem
				if is_instance_valid(badge) and panel.z_index <= badge.z_index:
					result = "Home notification badges must not draw above the content modal"
		scene.call("_sync_modal_input_scope", true)
		if panel != null and scene.call("_active_modal_overlay") != panel:
			result = "The content panel must own the main menu input while open"
	tree.root.remove_child(scene)
	scene.queue_free()
	await tree.process_frame
	ProjectSettings.set_setting("ptcgdap/card_content/enabled", previous)
	return result
