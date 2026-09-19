extends TestBase

func test_tournament_opponent_picker_and_start_remain_reachable_on_pc_and_phone() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame
	var scene = load("res://scenes/tournament/TournamentSetup.tscn")
	var errors: Array[String] = []
	var previous_mode: String = GameManager.non_battle_layout_mode
	const EMULATION := "input_devices/pointing/emulate_mouse_from_touch"
	var previous_emulation: bool = ProjectSettings.get_setting(EMULATION, true)
	ProjectSettings.set_setting(EMULATION, false)
	for dimensions: Vector2i in [Vector2i(1600, 900), Vector2i(900, 1800), Vector2i(390, 844)]:
		GameManager.non_battle_layout_mode = "landscape" if dimensions.x == 1600 else "portrait"
		var viewport := SubViewport.new()
		viewport.size = dimensions
		tree.root.add_child(viewport)
		var setup: Control = scene.instantiate()
		viewport.add_child(setup)
		for frame: int in 4: await tree.process_frame
		setup.call("_apply_non_battle_layout_for_tests", Vector2(dimensions), "landscape" if dimensions.x == 1600 else "portrait")
		for frame: int in 4: await tree.process_frame
		var scroll := setup.get_node("SetupScroll") as ScrollContainer
		for name: String in ["%OpponentSourceGroup", "%BtnStart"]:
			var target := setup.get_node(name) as Control
			scroll.ensure_control_visible(target)
			for frame: int in 3: await tree.process_frame
			var rect := target.get_global_rect()
			if rect.position.x < 0 or rect.end.x > dimensions.x + 1 or rect.position.y < 0 or rect.end.y > dimensions.y + 1:
				errors.append("Unreachable %s on %s: %s" % [name, dimensions, rect])
		if dimensions.x != 1600 and not scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false): errors.append("Phone touch scrolling not configured")
		if dimensions.x != 1600:
			scroll.scroll_vertical = 0
			await tree.process_frame
			var touch_bridge = load("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
			var press := InputEventScreenTouch.new()
			press.pressed = true
			press.position = Vector2(8, dimensions.y * 0.75)
			var handled: bool = touch_bridge.handle_root_touch(setup, press)
			var drag := InputEventScreenDrag.new()
			drag.position = press.position - Vector2(0, 200)
			handled = touch_bridge.handle_root_touch(setup, drag) and handled
			var release := InputEventScreenTouch.new()
			release.position = drag.position
			handled = touch_bridge.handle_root_touch(setup, release) and handled
			if not handled or scroll.scroll_vertical <= 0: errors.append("Phone surface swipe did not scroll the form")
		viewport.queue_free()
		await tree.process_frame
	GameManager.non_battle_layout_mode = previous_mode
	ProjectSettings.set_setting(EMULATION, previous_emulation)
	return "\n".join(errors)
