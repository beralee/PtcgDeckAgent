extends TestBase

const ArenaTheme := preload("res://scenes/arena3d/ArenaTheme.gd")

class DeferredBattle extends "res://scenes/battle/BattleScene.gd":
	var installed_before_engine := false
	func _prepare_battle() -> void:
		# Author package verification yields before constructing the real GSM.
		await get_tree().process_frame
		await get_tree().process_frame
		installed_before_engine = has_node("Arena3DPresenter") and _gsm == null
		await super._prepare_battle()

var saved: Dictionary

func _open(deferred: bool) -> Control:
	saved = {"mode":GameManager.current_mode,"decks":GameManager.selected_deck_ids.duplicate(),"arena":GameManager.battle_3d_enabled,"effects":GameManager.battle_effects_enabled,"profile":GameManager.ui_runtime_profile,"motion":ArenaTheme.option("motion")}
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.battle_3d_enabled = true
	GameManager.battle_effects_enabled = true
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":"native","native_os":"android","mobile_like":true,"pointer_mode":"touch","performance_tier":"low"})
	ArenaTheme.save_option("motion",true)
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	if deferred: scene.set_script(DeferredBattle)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	for i in range(8): await tree.process_frame
	return scene

func _position() -> GameState:
	var gs := GameState.new()
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 8
	gs.current_player_index = 0
	gs.first_player_index = 1
	for pi in range(2):
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = PokemonSlot.new()
		player.active_pokemon.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV8C","159"),pi))
		player.active_pokemon.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		player.set_prizes(prizes)
		for i in range(52): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		gs.players.append(player)
	return gs

func _install_position(scene: Control, gs: GameState) -> void:
	scene.get("_gsm").game_state = gs
	scene.set("_view_player",0)
	scene.set("_pending_choice","")
	scene.get("_dialog_overlay").hide()
	scene.get("_handover_panel").hide()
	scene.get("_arena_hand_observer").prime(gs,0)
	scene.get_node("Arena3DPresenter").motion.clear()
	scene.call("_refresh_ui")
	scene.get_node("Arena3DPresenter")._process(0)

func _close(scene: Control) -> void:
	scene.call("_release_battle_runtime_resources")
	scene.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	GameManager.current_mode = saved.mode
	GameManager.selected_deck_ids.assign(saved.decks)
	GameManager.battle_3d_enabled = saved.arena
	GameManager.battle_effects_enabled = saved.effects
	GameManager.ui_runtime_profile = saved.profile
	ArenaTheme.save_option("motion",saved.motion)

func test_deferred_engine_commits_reach_supporter_and_pokemon_directors() -> String:
	return await _check_commits(true)

func test_synchronous_engine_commits_are_presented_once() -> String:
	return await _check_commits(false)

func test_replacement_engine_retains_presentation() -> String:
	return await _check_commits(false,true)

func _check_commits(deferred: bool, replace_engine: bool = false) -> String:
	var scene := await _open(deferred)
	if replace_engine:
		scene.call("_release_game_state_machine")
		scene.set("_gsm",scene.call("_build_game_state_machine"))
		scene.call("_sync_battle_scene_context_runtime")
	var p: Control = scene.get_node("Arena3DPresenter")
	var gs := _position()
	gs.players[0].deck.pop_back()
	var card := CardInstance.create(CardDatabase.get_card("CSV1C","121"),0)
	gs.players[0].hand.append(card)
	_install_position(scene,gs)
	var checks: Array[String] = []
	if deferred: checks.append(assert_true(scene.installed_before_engine,"Exercise a presenter installed before asynchronous engine creation"))
	checks.append(assert_true(scene.get("_gsm").play_trainer(0,card,[]),"Commit a real Supporter through the engine"))
	checks.append(assert_eq(p.world.supporter_vfx.played,1,"Every committed Supporter must reach presentation exactly once"))
	_install_position(scene,_position())
	checks.append(assert_true(scene.get("_gsm").use_attack(0,0),"Commit a real attack through the engine"))
	await (Engine.get_main_loop() as SceneTree).process_frame
	checks.append(assert_eq(p.world.signature_vfx.played,1,"Every committed Pokemon attack must reach presentation exactly once"))
	await _close(scene)
	return run_checks(checks)

func test_visible_setup_switch_recovers_saved_disabled_3d_motion() -> String:
	var previous_motion := ArenaTheme.option("motion")
	var previous_effects := GameManager.battle_effects_enabled
	ArenaTheme.save_option("motion",false)
	GameManager.battle_effects_enabled = false
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(setup)
	setup.call("_select_background_path",preload("res://scripts/ui/battle/BattlePresentation.gd").GROVE_FIELD)
	setup.get_node("%BattleEffectsOnButton").pressed.emit()
	var checks: Array[String] = [assert_true(ArenaTheme.option("motion"),"The visible 3D effects switch must enable the persisted 3D preference")]
	checks.append(assert_false(GameManager.battle_effects_enabled,"Changing 3D motion must preserve the separate 2D preference"))
	setup.get_node("%BattleEffectsOffButton").pressed.emit()
	checks.append(assert_false(ArenaTheme.option("motion"),"The visible 3D effects switch must also disable motion"))
	setup.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	ArenaTheme.save_option("motion",previous_motion)
	GameManager.battle_effects_enabled = previous_effects
	return run_checks(checks)

func test_mobile_opponent_speech_is_large_and_centered_over_opponent_bench() -> String:
	var scene := await _open(false)
	_install_position(scene,_position())
	var p: Control = scene.get_node("Arena3DPresenter")
	var talk := preload("res://scripts/commentary/OpponentTalkController.gd").new()
	scene.add_child(talk)
	talk.setup(scene,p,{})
	talk.panel.present("别急，我的多龙巴鲁托ex已经准备好了。就决定是你了，幻影潜袭！",{"mood_id":"confident"})
	talk._layout()
	# Headless Camera3D has no rendered projection. Supply measured phone board
	# bounds here; the Android probe checks the actual rendered card rectangles.
	var active := Rect2(435,560,210,260)
	talk._layout_mobile(Rect2(0,125,1080,1420),active,Vector2.ZERO)
	var rect: Rect2 = talk.panel.get_global_rect()
	var metrics := preload("res://scenes/arena3d/ArenaPlatform.gd").metrics(scene.get_viewport_rect().size,GameManager.ui_runtime_profile)
	var checks: Array[String] = [assert_true(talk.panel.body.get_theme_font_size("font_size") >= roundi(22*metrics.scale),"Mobile speech must scale with the touch UI instead of fixed 18px text")]
	checks.append(assert_true(absf(rect.get_center().x-540) < 12,"Mobile speech is centered across the board"))
	checks.append(assert_true(rect.end.y <= active.position.y,"Speech occupies the opponent bench area above the active Pokemon"))
	talk.close()
	await _close(scene)
	return run_checks(checks)

func test_landscape_mobile_speech_fits_above_active_at_high_touch_scale() -> String:
	var scene := await _open(false)
	_install_position(scene,_position())
	var presenter: Control = scene.get_node("Arena3DPresenter")
	var talk := preload("res://scripts/commentary/OpponentTalkController.gd").new()
	scene.add_child(talk)
	talk.setup(scene,presenter,{})
	talk.set_process(false)
	talk.panel.configure_mobile(2.4,true)
	talk.panel.present("别急，我的多龙巴鲁托ex已经准备好了。就决定是你了，幻影潜袭！",{"mood_id":"confident"})
	# Actual 2400 x 1080 Android projection: the touch-scaled status bar leaves
	# less vertical space above the active card than the portrait bubble needs.
	var bounds := Rect2(8,132.8,2384,680)
	var active := Rect2(1139.094,320.2275,121.811,155.8956)
	talk._layout_mobile(bounds,active,Vector2.ZERO)
	for i in range(3): await (Engine.get_main_loop() as SceneTree).process_frame
	talk._layout_mobile(bounds,active,Vector2.ZERO)
	var rect: Rect2 = talk.panel.get_global_rect()
	var checks: Array[String] = [
		assert_true(talk.panel.visible,"Landscape speech remains available at the real phone geometry"),
		assert_true(absf(rect.get_center().x-bounds.get_center().x) < 12,"Landscape speech stays centered"),
		assert_true(rect.position.y >= bounds.position.y and rect.end.y <= active.position.y-8,"Speech must clear the active card without moving the board"),
		assert_true(talk.panel.body.get_theme_font_size("font_size") >= 53,"Fitting the bubble must preserve readable touch-scaled text"),
		assert_true(rect.encloses(talk.panel.body.get_global_rect()) and talk.panel.body.get_line_count() == talk.panel.body.get_visible_line_count(),"The entire long line remains visible")]
	talk._layout_mobile(Rect2(8,310,2384,20),active,Vector2.ZERO)
	checks.append(assert_false(talk.panel.visible,"If no readable pocket exists, speech must not cover the active card"))
	talk.close()
	await _close(scene)
	return run_checks(checks)
