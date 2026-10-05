extends "res://scripts/tools/ArenaKnockoutAcceptance.gd"
## Rendered, paired presentation benchmark. Synthetic fixture, no AI/network.
## Never accepts a headless result as a performance pass.
const Stats = preload("res://scripts/performance/PerformanceStatistics.gd")
const ATTACK_ROSTER := [["CSV8C","159"],["CSV5C","075"],["CSV7C","154"]]
var output := "user://arena-performance.json"
var mode := "3d"
var seconds := 12.0
var mobile := false
var exit_on_finish := true
var last_report: Dictionary = {}
var dimensions := Vector2i(390,844)
var rows: Array[Dictionary] = []
var presenter: Control
var vfx := preload("res://scripts/ui/battle/BattleAttackVfxController.gd").new()
var process_started_usec := 0
var render_started_usec := 0
var profile_cpu := false

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--arena-perf-output="): output = arg.trim_prefix("--arena-perf-output=")
		if arg.begins_with("--arena-perf-mode="): mode = arg.trim_prefix("--arena-perf-mode=")
		if arg.begins_with("--arena-perf-seconds="): seconds = maxf(5,float(arg.trim_prefix("--arena-perf-seconds=")))
		if arg == "--arena-perf-mobile": mobile = true
		if arg == "--arena-profile-cpu": profile_cpu = true
		if arg.begins_with("--arena-perf-size="):
			var pair := arg.trim_prefix("--arena-perf-size=").split("x")
			dimensions = Vector2i(int(pair[0]),int(pair[1]))
	get_tree().root.set_meta("performance_bench_offline",true)
	if get_tree().current_scene != null:
		var old_scene := get_tree().current_scene
		get_tree().current_scene = null
		old_scene.queue_free()
		await get_tree().process_frame
	get_tree().create_timer(seconds*3+60).timeout.connect(func():
		if not last_report.is_empty(): return
		push_error("Arena performance timed out")
		get_tree().quit(2)
	)
	if DisplayServer.get_name() == "headless" or mode not in ["2d","3d"]:
		push_error("Arena performance requires a rendered display and 2d/3d mode")
		get_tree().quit(1)
		return
	# A simulated touch profile is always recorded separately from the real OS.
	if mobile:
		var values := GameManager.get_ui_runtime_profile().to_dictionary()
		values.merge({"pointer_mode":"touch","mobile_like":true,"performance_tier":"low"},true)
		GameManager.ui_runtime_profile = UiRuntimeProfile.new(values)
	preload("res://scenes/arena3d/ArenaTheme.gd").save_option("quality_high","--arena-reference" in OS.get_cmdline_user_args())
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	GameManager.battle_effects_enabled = true
	GameManager.battle_3d_enabled = mode == "3d"
	GameManager.selected_battle_background = "res://assets/arena3d/previews/grove.png" if mode == "3d" else "res://assets/ui/background.png"
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT if dimensions.y > dimensions.x else GameManager.BATTLE_LAYOUT_LANDSCAPE
	seed(84590)
	var started := Time.get_ticks_usec()
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	await _settle(1)
	if not OS.get_name() in ["Android","Web","iOS"]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = preload("res://scenes/arena3d/ArenaPlatform.gd").canvas_size(dimensions)
		await _settle(.5)
		if mobile:
			var profile_values := GameManager.get_ui_runtime_profile().to_dictionary()
			profile_values.merge({"pointer_mode":"touch","mobile_like":true,"performance_tier":"low"},true)
			GameManager.ui_runtime_profile = UiRuntimeProfile.new(profile_values)
			battle.call("_configure_battle_pointer_runtime",GameManager.ui_runtime_profile)
			battle.get("_ios_web_hud_touch_adapter").configure(GameManager.ui_runtime_profile)
			battle.call("_apply_responsive_layout")
	presenter = battle.get_node_or_null("Arena3DPresenter")
	if (presenter != null) != (mode == "3d") or (presenter != null and presenter.world == null):
		push_error("Requested arena mode was not installed")
		get_tree().quit(1)
		return
	var startup_ms := float(Time.get_ticks_usec()-started)/1000.0
	var gs := _public_fixture()
	gs.stadium_card = CardInstance.create(CardDatabase.get_card("CSV9C","207"),0)
	for pi in range(2):
		gs.players[pi].active_pokemon = _slot("CSV8C","159",pi)
		while gs.players[pi].bench.size() < 8: gs.players[pi].bench.append(_slot("CSV8C","135",pi))
	battle.get("_gsm").game_state = gs
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	battle.get("_handover_panel").hide()
	if presenter != null:
		battle.get("_arena_hand_observer").prime(gs,0)
		presenter.motion.clear()
	battle.call("_refresh_ui")
	await _settle(2)
	await _sample("idle",gs)
	await _sample("updates_and_attacks",gs)
	await _settle(2)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	get_viewport().get_texture().get_image().save_png(output.get_basename()+".png")
	var report := {"schema_version":1,"kind":"arena_process_diagnostic" if profile_cpu else "arena_render_performance","fixture":"public-eight-bench-signature-v4","mode":mode,
		"attack_roster":ATTACK_ROSTER,
		"seconds_per_case":seconds,"simulated_touch":mobile,"setup_wall_ms":startup_ms,"cases":rows,
		"platform":{"os":OS.get_name(),"model":OS.get_model_name(),"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),
			"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),
			"editor_binary":OS.has_feature("editor"),"debug_build":OS.is_debug_build(),"window":[get_tree().root.size.x,get_tree().root.size.y]},
		"render_size": [presenter.viewport.size.x,presenter.viewport.size.y] if presenter != null else [],
		"table_fit_diagnostics":presenter.world.fit_diagnostics if presenter != null else [],
		"touch_profile": GameManager.get_ui_runtime_profile().prefers_touch(),
		"signature_attacks": presenter.world.signature_vfx.played if presenter != null else 0,
		"claims":{"physical_device_acceptance":false,"thermal_soak":false}}
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	last_report = report
	print("ARENA_PERFORMANCE_REPORT "+JSON.stringify({"output":output,"mode":mode,"cases":rows.size()}))
	if not exit_on_finish: return
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _sample(label: String, gs: GameState) -> void:
	var process_probe: Node
	if profile_cpu:
		process_probe = preload("res://scripts/performance/ArenaProcessProfiler.gd").new()
		process_probe.install(battle)
		get_tree().root.add_child(process_probe)
	var gaps: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var process_ms: Array[float] = []
	var scene_work_ms: Array[float] = []
	var render_submit_ms: Array[float] = []
	process_started_usec = 0
	render_started_usec = 0
	get_tree().process_frame.connect(_mark_process_start)
	RenderingServer.frame_pre_draw.connect(_mark_render_start)
	var updates := 0
	var update_timings: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec()-started < seconds*1000000:
		if label != "idle" and float(Time.get_ticks_usec()-started)/1000000 >= updates*4.0:
			updates += 1
			var printing: Array = ATTACK_ROSTER[(updates-1)%ATTACK_ROSTER.size()]
			gs.players[0].active_pokemon = _slot(printing[0],printing[1],0)
			gs.players[1].active_pokemon.damage_counters = (updates%5)*10
			var update_started := Time.get_ticks_usec()
			battle.call("_refresh_ui")
			var refresh_ms := float(Time.get_ticks_usec()-update_started)/1000.0
			if presenter != null:
				presenter._refresh()
				var targets: Array[String] = ["opp_active"]
				presenter.motion.start_attack(true,str(presenter.last_frame.slots.my_active.type),"基准攻击",targets,10)
			else:
				var action := GameAction.new()
				action.action_type = GameAction.ActionType.ATTACK
				action.player_index = 0
				action.data = {"attack_name":"基准攻击","damage":10,"targets":[{"player_index":1,"slot_kind":"active"}]}
				vfx.play_attack_vfx(battle,action)
			update_timings.append({"printing":printing,"refresh_ms":refresh_ms,"total_ms":float(Time.get_ticks_usec()-update_started)/1000.0})
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		gaps.append(float(now-last)/1000.0)
		if process_started_usec > 0 and render_started_usec >= process_started_usec:
			scene_work_ms.append(float(render_started_usec-process_started_usec)/1000.0)
			render_submit_ms.append(float(now-render_started_usec)/1000.0)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	var over50 := 0
	for gap in gaps:
		if gap > 50: over50 += 1
	get_tree().process_frame.disconnect(_mark_process_start)
	RenderingServer.frame_pre_draw.disconnect(_mark_render_start)
	rows.append({"case":label,"frame_gaps_ms":gaps,"frames":Stats.summarize(gaps),"process_ms":Stats.summarize(process_ms),
		"scene_work_ms":Stats.summarize(scene_work_ms),"render_submit_ms":Stats.summarize(render_submit_ms),
		"draw_calls":Stats.summarize(draws),"primitives":Stats.summarize(primitives),"over_50ms":over50,"updates":updates,"update_timings":update_timings})
	if profile_cpu:
		rows[-1]["instrumented_process_owners"] = process_probe.finish()
		get_tree().root.remove_child(process_probe)
		process_probe.queue_free()

func _mark_process_start() -> void:
	process_started_usec = Time.get_ticks_usec()

func _mark_render_start() -> void:
	# Includes driver submission/waits, not an isolated GPU hardware duration.
	render_started_usec = Time.get_ticks_usec()
