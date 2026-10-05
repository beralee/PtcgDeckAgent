extends "res://tests/commentary/CommentaryArenaAcceptance.gd"
## Same production scene and mouse/raw-touch/keyboard harness; model is always
## a sub-agent-authored offline double, including its real response envelope.
func _run() -> void:
	output = "res://.godot_test_user/opponent_emotion_floating"
	get_tree().create_timer(65).timeout.connect(func(): get_tree().quit(2))
	Preferences.save_enabled(false)
	get_tree().root.size = Vector2i(1440, 1000)
	rig = preload("res://scripts/tools/ArenaSignatureScenario.gd").new()
	add_child(rig)
	await rig.mount_combat("grimmsnarl")
	var battle: Control = rig.battle
	var presenter: Control = battle.get_node("Arena3DPresenter")
	var original_button_count: int = presenter.ui_buttons.size()
	_check(not battle.has_node("OpponentTalk"), "default_off_creates_no_agent")
	var model := CommentatorDouble.new()
	commentary = preload("res://scripts/commentary/OpponentTalkController.gd").new()
	battle.add_child(commentary)
	# Author strategy preparation can yield while the scene is already mounted.
	# Install speech first, then supply the actual GSM just as that path does.
	var delayed_gsm: GameStateMachine = battle.get("_gsm")
	battle.set("_gsm", null)
	commentary.setup(battle, presenter, {"api_key": "OFFLINE_FIXTURE_ONLY", "ai_personality": "逗比臭牌篓子"}, model)
	battle.set("_gsm", delayed_gsm)
	await _wait(0.8)
	_check(commentary.gsm == delayed_gsm, "binds_gsm_after_async_author_strategy_startup")
	_check(model.requests.size() == 1, "personality_prepared_once_off_the_game_clock")
	if model.requests.is_empty(): return _finish(false)
	var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/opponent_emotion_bank_simulation.json"))
	var spoken: int = commentary.session.history.size()
	model.deliver(0, bank)
	_check(commentary.session.model_ready, "sub_agent_model_bank_validated")
	_check(commentary.session.history.size() == spoken, "network_reply_cannot_invent_a_live_reaction")
	commentary.session.last_spoken = -100.0
	var before_hp: int = rig.gsm.game_state.players[0].active_pokemon.get_remaining_hp()
	_check(rig.perform_combat(), "real_attack_submitted_through_interaction_owner")
	var after_hp: int = rig.gsm.game_state.players[0].active_pokemon.get_remaining_hp()
	_check(before_hp - after_hp == 180, "real_engine_resolves_180_damage_without_waiting_for_model")
	_check(commentary.session.history.back().trigger == "attack_call", "committed_attack_immediately_has_first_person_shout")
	_check(commentary.session.history.back().source == "model_bank", "mock_generated_personality_reaches_live_bubble")
	_check(commentary.panel.body.text.contains(rig.combat_move_name()), "shout_binds_the_actual_attack_name")
	_check(commentary.panel.current_mood_id == commentary.session.history.back().mood_id, "portrait_text_and_history_share_one_mood")
	_check(commentary.panel.emote.texture != null, "generated_portrait_loaded")
	_check(commentary.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "bubble_body_does_not_intercept_board_input")
	var displayed_cue: Dictionary = commentary.session.history.back()
	var displayed_line: String = commentary.panel.body.text
	var wait_until := Time.get_ticks_msec() + 12000
	while presenter.motion.is_busy() and Time.get_ticks_msec() < wait_until: await _wait(0.1)
	commentary.panel.present(displayed_line, displayed_cue)
	await _wait(0.3)
	await _geometry_and_capture("wide")
	commentary.panel.present("别急，我的多龙巴鲁托ex已经准备好了。就决定是你了，幻影潜袭！这一回合我要认真找回节奏。", displayed_cue)
	await _wait(0.2)
	await _geometry_and_capture("long_line")
	commentary.panel.present(displayed_line, displayed_cue)
	get_tree().root.size = Vector2i(1600, 900)
	await _wait(0.4)
	await _geometry_and_capture("landscape")
	get_tree().root.size = Vector2i(1024, 768)
	await _wait(0.4)
	await _geometry_and_capture("small_window")
	get_tree().root.size = Vector2i(720, 1280)
	await _wait(0.6)
	await _geometry_and_capture("portrait")
	_check(commentary.panel.get_global_rect().encloses(commentary.panel.emote.get_global_rect()), "portrait_stays_inside_bubble")
	commentary.panel._process(9.0)
	_check(not commentary.panel.visible, "speech_disappears_when_finished")
	commentary.panel.present(displayed_line, displayed_cue)
	await _wait(0.15)
	await _click(commentary.panel.history_button)
	_check(is_instance_valid(commentary.history_dialog) and commentary.history_dialog.visible, "mouse_history_uses_in_game_modal")
	if is_instance_valid(commentary.history_dialog): commentary.history_dialog.request_cancel()
	await _wait(0.25)
	var previous_emulation: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	await _touch(commentary.panel.history_button)
	_check(is_instance_valid(commentary.history_dialog) and commentary.history_dialog.visible, "raw_touch_history_without_mouse_emulation")
	if is_instance_valid(commentary.history_dialog): commentary.history_dialog.request_cancel()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	await _wait(0.25)
	commentary.panel.close_button.grab_focus()
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	get_tree().root.push_input(enter)
	enter = enter.duplicate()
	enter.pressed = false
	get_tree().root.push_input(enter)
	await _wait(0.15)
	_check(commentary.closed and model.canceled, "keyboard_mute_cancels_agent")
	_check(float(battle.get_meta("commentary_reserved_height", 0.0)) == 0.0, "mute_restores_board_space")
	_check(float(battle.get_meta("opponent_talk_reserved_width", 0.0)) == 0.0, "mute_releases_right_sidebar")
	_check(presenter.ui_buttons.size() == original_button_count, "mute_unregisters_floating_touch_targets")
	await _wait(0.15)
	_check(not battle.has_node("OpponentTalkRail"), "mute_removes_sidebar_background")
	await rig.close()
	rig.queue_free()
	await _two_dimensional_scene()
	await _setup_scene()
	_finish(true)

func _geometry_and_capture(label: String) -> void:
	var scene: Control = rig.battle
	var field: Control = scene.get_node("MainArea/CenterField/FieldArea")
	var safe := preload("res://scenes/arena3d/ArenaPlatform.gd").safe_rect(scene)
	var metrics := preload("res://scenes/arena3d/ArenaPlatform.gd").metrics(scene.get_viewport_rect().size, GameManager.ui_runtime_profile)
	var rect: Rect2 = commentary.panel.get_global_rect()
	print("FLOATING_GEOMETRY ", label, " ", rect, " available=", commentary.panel.placement_available)
	_check(commentary.panel.visible or (label == "small_window" and not commentary.panel.placement_available), label + "_visible_or_safely_suppressed_if_cramped")
	_check(absf(field.get_global_rect().position.y - safe.position.y - (0 if metrics.compact else 58)) < 2.0, label + "_battle_keeps_full_height")
	_check(not commentary.panel.visible or safe.encloses(rect), label + "_bubble_stays_in_safe_area")
	_check(absf(field.size.x - safe.size.x) < 2.0, label + "_battle_keeps_full_width")
	_check(rect.size.x <= 400 and rect.size.y <= 180, label + "_small_speech_bubble")
	_check(rect.encloses(commentary.panel.emote.get_global_rect()), label + "_portrait_is_inside_bubble")
	_check(rect.encloses(commentary.panel.body.get_global_rect()) and commentary.panel.body.get_visible_line_count() == commentary.panel.body.get_line_count(), label + "_whole_line_is_readable")
	var presenter: Control = scene.get_node("Arena3DPresenter")
	var active: Rect2 = presenter.world.card_screen_rect("opp_active")
	active.position += presenter.global_position
	_check(not commentary.panel.visible or rect.position.x > active.end.x, label + "_stays_on_opponents_right")
	for id: String in presenter.world.cards:
		if not presenter.world.cards[id].node.visible: continue
		var card: Rect2 = presenter.world.card_screen_rect(id)
		card.position += presenter.global_position
		_check(not commentary.panel.visible or not rect.intersects(card), label + "_does_not_cover_" + id)
	_check(not rect.intersects(scene.get_node("MainArea/CenterField/HandArea").get_global_rect()), label + "_does_not_cover_hand")
	if not presenter.world.compact_board:
		for kind: String in ["deck", "discard"]:
			var pile: Rect2 = presenter.world.side_zones.screen_rect("opp", kind)
			pile.position += presenter.global_position
			_check(not commentary.panel.visible or not rect.intersects(pile), label + "_does_not_cover_opponent_" + kind)
	for button: Control in [presenter.settings_button, presenter.log_button, presenter.end_button]:
		_check(not rect.intersects(button.get_global_rect()), label + "_no_overlap_" + str(button.text))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		get_viewport().get_texture().get_image().save_png(output + "/" + label + ".png")

func _two_dimensional_scene() -> void:
	Preferences.save_enabled(true)
	GameManager.battle_3d_enabled = false
	ProjectSettings.set_setting("arena3d/enabled", false)
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.set_script(preload("res://scripts/tools/ArenaSignatureScenario.gd").Scene)
	get_tree().root.add_child(scene)
	await _wait(0.2)
	_check(not scene.has_node("Arena3DPresenter") and not scene.has_node("OpponentTalk"), "2d_with_opt_in_allocates_no_agent")
	Preferences.save_enabled(false)
	scene.queue_free()
	await get_tree().process_frame
