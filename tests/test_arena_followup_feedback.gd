extends "res://tests/test_arena_live_entry.gd"

func test_hotseat_discard_buttons_follow_current_view_and_piles() -> String:
	var scene := await _open(false)
	var gs := _position()
	gs.players[0].discard_pile.append(gs.players[0].deck.pop_back())
	for i in 3: gs.players[1].discard_pile.append(gs.players[1].deck.pop_back())
	_install_position(scene,gs)
	var p: Control = scene.get_node("Arena3DPresenter")
	var checks: Array[String] = []
	for view in [0,1,0]:
		scene.set("_view_player",view)
		p.motion.clear()
		p._refresh()
		for side in ["my","opp"]:
			var owner: int = view if side == "my" else 1-view
			scene.get("_discard_overlay").hide()
			p.zone_buttons[side+"_discard"].pressed.emit()
			checks.append(assert_eq(scene.get("_discard_collection_current_player_index"),owner,"Hotseat discard must resolve the current visual side"))
			checks.append(assert_eq(p.world.side_zones.piles[side+"_deck"].count,gs.players[owner].deck.size(),"Deck pile follows the current seat"))
			checks.append(assert_eq(p.world.side_zones.piles[side+"_discard"].count,gs.players[owner].discard_pile.size(),"Discard pile follows the current seat"))
			scene.call("_close_discard_collection_viewer","test")
			await (Engine.get_main_loop() as SceneTree).create_timer(.4).timeout
	await _close(scene)
	return run_checks(checks)

func test_prize_picker_shows_six_card_backs_not_text_tiles() -> String:
	var scene := await _open(false)
	_install_position(scene,_position())
	var p: Control = scene.get_node("Arena3DPresenter")
	var checks: Array[String] = [assert_eq(p.prize_buttons.size(),6,"Keep all six stable prize slots")]
	for button: Button in p.prize_buttons:
		checks.append(assert_true(button.icon != null,"Each prize selection must show a card back"))
	await _close(scene)
	return run_checks(checks)

func test_hotseat_handover_never_keeps_the_previous_seat_piles_during_a_hold() -> String:
	var scene := await _open(false)
	var gs := _position()
	for i in 4: gs.players[1].discard_pile.append(gs.players[1].deck.pop_back())
	_install_position(scene,gs)
	var p: Control = scene.get_node("Arena3DPresenter")
	p.motion.hold = 3.0
	scene.set("_view_player",1)
	p._refresh()
	var result := run_checks([assert_eq(p.board_hud.frame.view,1,"Visual ownership changes atomically with the hotseat viewer"),assert_eq(p.world.side_zones.piles.my_discard.count,4,"A presentation hold cannot leave the previous seat's discard visible")])
	await _close(scene)
	return result

func test_home_modal_guards_native_mouse_as_well_as_touch() -> String:
	var menu: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	menu.size = Vector2(1080,1920)
	menu.call("_apply_non_battle_layout_for_tests",menu.size,"portrait")
	menu.call("_show_hud_modal","设置","Test",[])
	var button: Button = menu.get("_share_button")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	var result := assert_true(menu.call("_should_block_button_input_for_active_modal",button,mouse),"A native desktop/web mouse must not activate a covered footer action")
	menu.free()
	return result

func test_deepseek_bubble_expires_after_four_seconds() -> String:
	var bubble := preload("res://scripts/commentary/OpponentTalkBubble.gd").new()
	bubble.present("准备好了吗？",{})
	bubble._process(3.9)
	var before: bool = bubble.visible
	bubble._process(.2)
	var result := run_checks([assert_true(before,"Dialogue stays readable for four seconds"),assert_false(bubble.visible,"Dialogue lifetime is half of the old eight seconds")])
	bubble.free()
	return result

func test_web_v2_modal_keeps_its_native_mouse_controls_usable() -> String:
	var bridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
	var previous: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch",true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch",false)
	bridge.set_test_web_input_adapter_mode("v2")
	var menu: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	menu.call("_apply_non_battle_layout_for_tests",Vector2(1080,1920),"portrait")
	menu.call("_show_hud_modal","关于","Mouse controls",[])
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	var result := assert_false(menu.call("_handle_active_modal_input",mouse),"Unsuppressed Web v2 mouse input must reach the modal native GUI")
	menu.free()
	bridge.reset_test_web_input_adapter_mode()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch",previous)
	return result

func test_named_and_update_modals_remove_covered_buttons_from_native_hit_testing() -> String:
	var menu: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	menu.call("_apply_non_battle_layout_for_tests",Vector2(1080,1920),"portrait")
	var behind: Button = menu.get("_share_button")
	var original: int = behind.mouse_filter
	var update := Control.new()
	update.name = "AppUpdateDialog"
	menu.add_child(update)
	menu.set("_hud_modal_overlay",update)
	menu.call("_sync_modal_input_scope")
	var blocked: bool = behind.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var recognized: bool = menu.call("_active_modal_overlay") == update
	update.hide()
	menu.call("_sync_modal_input_scope")
	var drained: bool = behind.mouse_filter == Control.MOUSE_FILTER_IGNORE
	# Headless frame time may advance faster than the wall-clock echo guard.
	var deadline := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < deadline:
		await (Engine.get_main_loop() as SceneTree).process_frame
	menu.call("_sync_modal_input_scope")
	var restored: bool = behind.mouse_filter == original
	menu.free()
	return run_checks([assert_true(recognized,"Update dialogs own input even with a different node name"),assert_true(blocked,"Covered footer buttons cannot receive native GUI activation"),assert_true(drained,"Self-dismissed dialogs also drain their release echo"),assert_true(restored,"Home controls recover their original input mode after close")])
