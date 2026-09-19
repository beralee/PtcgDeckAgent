extends SceneTree

## Source startup regression: real scenes/resources and UI signals, no AI-seat
## injection, disabled effects, or direct GameStateMachine mutations.
var output := ""
var mode := "practice"
var report := {"physical_mouse_input": false, "checks": []}
var error_gate = preload("res://tests/SharedSuiteRunner.gd").ScriptErrorGate.new()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	OS.add_logger(error_gate)
	_run.call_deferred()

func _run() -> void:
	if output.is_empty() or not OS.get_user_data_dir().contains("PtcgDAP-macOS-startup-"):
		push_error("Isolated startup profile required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	report.merge({"mode": mode, "godot": Engine.get_version_info().string, "user_data": OS.get_user_data_dir()})
	change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	if not await _wait_scene("res://scenes/main_menu/MainMenu.tscn"):
		_finish("main_menu_missing")
		return
	await _capture("01-menu")
	(current_scene.find_child("BtnStartBattle", true, false) as Button).pressed.emit()
	if not await _wait_scene("res://scenes/battle_setup/BattleSetup.tscn"):
		_finish("battle_setup_missing")
		return
	var mode_button := "ModeTwoPlayerButton" if mode == "practice" else "ModeAIButton"
	(current_scene.find_child(mode_button, true, false) as Button).pressed.emit()
	(current_scene.find_child("BattleEffectsOnButton", true, false) as Button).pressed.emit()
	await _capture("02-setup")
	(current_scene.find_child("BtnStart", true, false) as Button).pressed.emit()
	if not await _wait_scene("res://scenes/battle/BattleScene.tscn"):
		_finish("battle_scene_missing")
		return
	var battle := current_scene
	if not battle.has_method("_state_snapshot") or battle.get("_gsm") == null:
		await _capture("03-broken-battle")
		_finish("battle_runtime_not_loaded")
		return
	var backdrop := battle.get_node_or_null("BattleBackdrop") as TextureRect
	if backdrop == null or backdrop.texture == null:
		_finish("battle_background_missing")
		return
	report.checks.append("battle runtime and background loaded")
	await _capture("03-opening")
	var gsm: Variant = battle.get("_gsm")
	var deadline := Time.get_ticks_msec() + 90000
	var reached_human_turn := false
	while Time.get_ticks_msec() < deadline:
		if int(gsm.game_state.phase) == 4 and str(battle.get("_pending_choice")).is_empty() \
				and (mode == "practice" or int(gsm.game_state.current_player_index) == 0) \
				and _input_ready(battle):
			reached_human_turn = true
			break
		await _opening_ui_step(battle)
		await create_timer(0.15).timeout
	if not reached_human_turn:
		report["state"] = battle.call("_state_snapshot")
		await _capture("03-opening-stalled")
		_finish("opening_did_not_reach_human_turn")
		return
	var hand := battle.get("_hand_container") as Control
	var images := 0
	for card: Node in hand.get_children():
		if card is BattleCardView and card.card_data != null:
			var art := card.get("_texture_rect") as TextureRect
			if art != null and art.texture != null: images += 1
	report["hand_images"] = images
	report["effects_enabled"] = root.get_node("GameManager").get("battle_effects_enabled")
	report["log_characters"] = (battle.get("_log_list") as RichTextLabel).get_parsed_text().length()
	if images <= 0 or not report.effects_enabled or int(report.log_characters) == 0:
		_finish("hand_images_effects_or_log_missing")
		return
	report.checks.append("opening UI choices reach human turn with card images and effects enabled")
	await _capture("03-playable-battle")
	var turn_before := int(gsm.game_state.turn_number)
	var end_turn := battle.get("_hud_end_turn_btn") as Button
	if end_turn.disabled or not end_turn.is_visible_in_tree():
		_finish("end_turn_button_not_available")
		return
	end_turn.pressed.emit()
	deadline = Time.get_ticks_msec() + 90000
	var next_turn_ready := false
	while Time.get_ticks_msec() < deadline:
		if int(gsm.game_state.turn_number) > turn_before and int(gsm.game_state.phase) == 4 \
				and (mode == "practice" or int(gsm.game_state.current_player_index) == 0) \
				and str(battle.get("_pending_choice")).is_empty() and _input_ready(battle):
			next_turn_ready = true
			break
		await _opening_ui_step(battle)
		await create_timer(0.15).timeout
	report["turn_before"] = turn_before
	report["turn_after"] = int(gsm.game_state.turn_number)
	if not next_turn_ready:
		report["state"] = battle.call("_state_snapshot")
		_finish("end_turn_button_did_not_advance_game")
		return
	report.checks.append("normal end-turn button advances the real match")
	await _capture("04-next-turn")
	gsm = null
	change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	battle = null
	await _wait_scene("res://scenes/main_menu/MainMenu.tscn")
	await create_timer(1.0).timeout
	_finish("")

func _input_ready(battle: Node) -> bool:
	if bool(battle.call("_has_pending_coin_animation")) or bool(battle.call("_is_ai_action_pause_active")):
		return false
	for field: String in ["_draw_reveal_active", "_battle_visual_input_blocked", "_pending_prize_animating", "_ai_running"]:
		if bool(battle.get(field)): return false
	for field: String in ["_handover_panel", "_coin_overlay", "_dialog_overlay"]:
		if (battle.get(field) as Control).is_visible_in_tree(): return false
	return true

func _opening_ui_step(battle: Node) -> void:
	if bool(battle.call("_has_pending_coin_animation")): return
	var handover := battle.get("_handover_panel") as Control
	if handover.is_visible_in_tree():
		(battle.get("_handover_btn") as Button).pressed.emit()
		return
	var coin := battle.get("_coin_overlay") as Control
	if coin.is_visible_in_tree():
		(battle.get("_coin_ok_btn") as Button).pressed.emit()
		return
	var dialog := battle.get("_dialog_overlay") as Control
	if not dialog.is_visible_in_tree(): return
	var gallery := battle.get("_dialog_card_row") as Control
	if gallery != null and gallery.is_visible_in_tree():
		for choice: Node in gallery.find_children("*", "PanelContainer", true, false):
			if choice.has_meta("dialog_text_choice_index") and choice.is_visible_in_tree():
				_emit_pointer_press(choice)
				return
		for card: Node in gallery.get_children():
			if card is BattleCardView and card.is_visible_in_tree():
				card.left_clicked.emit(card.card_instance, card.card_data)
				await process_frame
				break
	else:
		var choices := battle.get("_dialog_list") as ItemList
		if choices.is_visible_in_tree() and choices.item_count > 0:
			choices.select(0)
			choices.item_selected.emit(0)
	var confirm := battle.get("_dialog_confirm") as Button
	if confirm.is_visible_in_tree() and not confirm.disabled:
		_emit_pointer_press(confirm)
		confirm.button_down.emit()
		confirm.pressed.emit()

func _emit_pointer_press(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = control.size / 2.0
	event.global_position = control.get_global_rect().get_center()
	control.gui_input.emit(event)

func _wait_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			for frame: int in 5: await process_frame
			return true
	return false

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _finish(error: String) -> void:
	report["error"] = error
	report["script_errors"] = error_gate.take_script_errors()
	report["ok"] = error.is_empty() and report.script_errors.is_empty()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	OS.remove_logger(error_gate)
	quit(0 if report.ok else 1)
