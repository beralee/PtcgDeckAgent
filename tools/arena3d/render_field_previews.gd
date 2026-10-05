extends SceneTree
## Capture the actual grove battle viewport after a normal opening.
## Run with an isolated APPDATA; this tool uses ordinary local game preferences.
const OUTPUT := "res://assets/arena3d/previews/grove.png"
var battle: Control

func _initialize() -> void:
	call_deferred("_render_previews")

func _render_previews() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Field previews require the real game renderer")
		quit(1)
		return
	create_timer(60).timeout.connect(func(): quit(2))
	root.set_meta("performance_bench_offline", true)
	var manager := root.get_node("GameManager")
	manager.current_mode = manager.GameMode.VS_AI
	manager.selected_deck_ids.assign([575720, 575720])
	manager.first_player_choice = 0
	manager.ai_deck_strategy = "generic"
	manager.battle_effects_enabled = false
	manager.battle_3d_enabled = true
	manager.selected_battle_background = OUTPUT
	manager.battle_layout_mode = "landscape"
	seed(9272026)
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await create_timer(1).timeout
	root.size = Vector2i(1280, 960)
	var opponent = battle.get("_ai_opponent")
	if opponent != null: opponent.use_mcts = false
	for step in range(90):
		var choice: String = battle.get("_pending_choice")
		if choice.begins_with("setup_bench"):
			battle.call("_on_dialog_card_chosen", 1)
		elif choice.begins_with("setup_active") or choice.begins_with("mulligan"):
			battle.call("_on_dialog_card_chosen", 0)
		var state: GameState = battle.get("_gsm").game_state
		if state.phase == GameState.GamePhase.MAIN and state.current_player_index == 0:
			break
		await create_timer(.15).timeout
	var state: GameState = battle.get("_gsm").game_state
	var presenter := battle.get_node_or_null("Arena3DPresenter")
	if state.phase != GameState.GamePhase.MAIN or presenter == null or presenter.theme_id != "grove":
		push_error("A real grove opening is required before capturing the preview")
		quit(1)
		return
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	# Preserve the live camera, lighting, materials and public card placement.
	# Only scale the viewport image; no substitute scene or retouching.
	var image: Image = presenter.viewport.get_texture().get_image()
	image.resize(960, roundi(960.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_LANCZOS)
	var result := image.save_png(OUTPUT)
	if result != OK:
		push_error("Grove field preview write failed")
		quit(1)
		return
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await process_frame
	await process_frame
	print("ARENA_FIELD_PREVIEWS_PASS: grove, real BattleScene viewport, normal camera, normal opening")
	quit()
