extends SceneTree
var battle: Control
var attack_captured := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(180 if "--arena-full-match" in OS.get_cmdline_user_args() else 35).timeout.connect(func(): quit(2))
	var gm = root.get_node("GameManager")
	gm.current_mode = gm.GameMode.VS_AI
	gm.selected_deck_ids.assign([575720,575720])
	gm.first_player_choice = 0
	gm.battle_effects_enabled = false
	gm.ai_deck_strategy = "generic"
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await create_timer(1).timeout
	# Use the existing bounded classic greedy lane for the long smoke, so MCTS
	# thinking time and strategic quality do not dominate a renderer acceptance.
	var opponent = battle.get("_ai_opponent")
	if opponent != null: opponent.use_mcts = false
	for step in range(60):
		var choice: String = battle.get("_pending_choice")
		print("ARENA_SETUP_STEP ",step," ",choice)
		if choice.begins_with("setup_active"):
			battle.call("_on_dialog_card_chosen",0)
		elif choice.begins_with("setup_bench"):
			battle.call("_on_dialog_card_chosen",0)
		elif choice.begins_with("mulligan"):
			battle.call("_on_dialog_card_chosen",0)
		var gs: GameState = battle.get("_gsm").game_state
		if gs.phase == GameState.GamePhase.MAIN and gs.current_player_index == 0: break
		await create_timer(.25).timeout
	var presenter = battle.get_node("Arena3DPresenter")
	battle.get("_gsm").action_logged.connect(_capture_attack)
	assert(presenter.world != null)
	await create_timer(.5).timeout
	var screen_point: Vector2 = presenter.world.camera.unproject_position(presenter.world.cards.my_active.node.position)
	assert(presenter.world.hit_slot(screen_point) == "my_active", "3D pick must match visible card")
	# Adapter-level coverage; full Viewport GUI dispatch is tested by test_arena3d_hud_input.gd.
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen_point
		presenter._on_input(event)
	assert(battle.get("_pending_choice") == "pokemon_action", "3D click opens actual Pokemon actions")
	battle.call("_on_dialog_cancel")
	await create_timer(.35).timeout
	# Blocked modal clicks cannot activate another card.
	battle.get("_detail_overlay").visible = true
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen_point
		presenter._on_input(event)
	assert(battle.get("_pending_choice") != "pokemon_action")
	battle.get("_detail_overlay").visible = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://arena-battle.png")
	var gs: GameState = battle.get("_gsm").game_state
	var turn: int = gs.turn_number
	presenter.end_button.pressed.emit()
	await create_timer(2).timeout
	assert(gs.turn_number > turn or gs.current_player_index == 1, "3D end-turn reaches rules and AI")
	print("ARENA3D LIVE PASS: real setup, perspective pick, action dialog, end-turn and AI; turn=",gs.turn_number)
	if "--arena-full-match" in OS.get_cmdline_user_args():
		for step in range(700):
			if gs.phase == GameState.GamePhase.GAME_OVER: break
			var choice: String = battle.get("_pending_choice")
			if step % 50 == 0:
				print("ARENA_FULL_MATCH_PROGRESS ",JSON.stringify({"step":step,"turn":gs.turn_number,"phase":gs.phase,"player":gs.current_player_index,"choice":choice,"animation_busy":presenter.motion.is_busy(),"can_act":battle.call("_can_view_player_start_turn_action")}))
			if gs.current_player_index == 0 and choice == "" and gs.phase == GameState.GamePhase.MAIN:
				presenter.end_button.pressed.emit()
			elif choice == "send_out" and gs.current_player_index == 0:
				battle.call("_on_dialog_card_chosen",0)
			elif choice == "take_prize" and battle.get("_pending_prize_player_index") == 0:
				for button: Button in presenter.prize_buttons:
					if button.visible and not button.disabled:
						button.pressed.emit()
						break
			await create_timer(.2).timeout
		assert(gs.phase == GameState.GamePhase.GAME_OVER,"Full rendered match must reach terminal")
		print("ARENA3D FULL MATCH PASS: winner=",gs.winner_index," turn=",gs.turn_number)
	print("ARENA3D RENDER fps=",Performance.get_monitor(Performance.TIME_FPS)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await process_frame
	await process_frame
	quit()

func _capture_attack(action: GameAction) -> void:
	if attack_captured or action.action_type != GameAction.ActionType.ATTACK or DisplayServer.get_name() == "headless": return
	attack_captured = true
	await create_timer(.13).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://arena-attack.png")
