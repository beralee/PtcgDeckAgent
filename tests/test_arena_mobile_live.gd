extends TestBase

var saved: Dictionary

func _battle(host: Node = null) -> Control:
	saved = {"mode":GameManager.current_mode,"decks":GameManager.selected_deck_ids.duplicate(),"arena":GameManager.battle_3d_enabled,"effects":GameManager.battle_effects_enabled,"profile":GameManager.ui_runtime_profile}
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.battle_3d_enabled = true
	GameManager.battle_effects_enabled = false
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":"native","native_os":"android","mobile_like":true,"pointer_mode":"touch","performance_tier":"low"})
	preload("res://scenes/arena3d/ArenaTheme.gd").save_option("motion",true)
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	(host if host != null else tree.root).add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var gs := GameState.new()
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 4
	gs.current_player_index = 0
	for pi in range(2):
		var player := PlayerState.new()
		player.active_pokemon = PokemonSlot.new()
		player.active_pokemon.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV7C","154"),pi))
		for i in range(59): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		gs.players.append(player)
	scene.get("_gsm").game_state = gs
	scene.set("_view_player",0)
	scene.set("_pending_choice","")
	scene.get("_dialog_overlay").hide()
	scene.get("_handover_panel").hide()
	scene.get_node("Arena3DPresenter").motion.clear()
	scene.call("_refresh_ui")
	return scene

func _finish(scene: Control) -> void:
	scene.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	GameManager.current_mode = saved.mode
	GameManager.selected_deck_ids.assign(saved.decks)
	GameManager.battle_3d_enabled = saved.arena
	GameManager.battle_effects_enabled = saved.effects
	GameManager.ui_runtime_profile = saved.profile

func test_idle_end_turn_unblocks_when_transient_gate_clears_without_board_action() -> String:
	var scene := await _battle()
	var p: Control = scene.get_node("Arena3DPresenter")
	p.world.motion_enabled = false
	scene.set("_ai_llm_waiting",true)
	p._process(0)
	var checks: Array[String] = [assert_true(p.end_button.disabled,"Pending action owner blocks turn control")]
	scene.set("_ai_llm_waiting",false)
	p._process(0)
	checks.append(assert_false(p.end_button.disabled,"An idle board must enable end turn when the transient wait clears"))
	await _finish(scene)
	return run_checks(checks)

func test_portrait_layout_stabilization_preserves_live_arena_width() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var view := SubViewport.new()
	view.size = Vector2i(1080,2400)
	tree.root.add_child(view)
	var scene := await _battle(view)
	var p: Control = scene.get_node("Arena3DPresenter")
	p.world.motion_enabled = false
	for i in range(8): await tree.process_frame
	var expected_width := preload("res://scenes/arena3d/ArenaPlatform.gd").safe_rect(scene).size.x
	var checks: Array[String] = [assert_true(is_equal_approx(p.size.x,expected_width),"Settled 3D board fills its safe viewport")]
	# Android can still be applying orientation stabilization while a live
	# button is pressed. Observe geometry before deferred Container sorting.
	for i in range(3):
		scene.call("_apply_responsive_layout")
		p._process(0)
		checks.append(assert_true(is_equal_approx(p.size.x,expected_width),"Responsive layout must not transiently narrow the touch surface: %s" % p.size.x))
		await tree.process_frame
		p._process(0)
		checks.append(assert_true(is_equal_approx(p.size.x,expected_width),"Deferred layout must preserve the same touch surface"))
	await _finish(scene)
	view.queue_free()
	await tree.process_frame
	return run_checks(checks)

func test_3d_motion_is_independent_of_legacy_2d_effect_preference() -> String:
	var scene := await _battle()
	var p: Control = scene.get_node("Arena3DPresenter")
	var checks: Array[String] = [assert_true(p.world.motion_enabled,"Selecting 3D retains its enabled character choreography even with old 2D effects off"),assert_false(GameManager.battle_effects_enabled,"Do not overwrite the saved 2D preference")]
	await _finish(scene)
	return run_checks(checks)

func test_handover_waits_for_arena_attack_presentation() -> String:
	var scene := await _battle()
	var p: Control = scene.get_node("Arena3DPresenter")
	p.motion.busy_time = .4
	var checks: Array[String] = [assert_true(scene.call("_has_active_attack_vfx"),"The handover owner must observe the active 3D attack")]
	p.motion.busy_time = 0
	checks.append(assert_false(scene.call("_has_active_attack_vfx"),"Completed 3D attacks release the handover gate"))
	await _finish(scene)
	return run_checks(checks)
