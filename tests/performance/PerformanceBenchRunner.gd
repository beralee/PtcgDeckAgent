extends Node

## Runs actual product owners/scenes. Installed only in diagnostic exports.
## Never uploads data; measurements contain timings and fixture identities only.
const Stats = preload("res://scripts/performance/PerformanceStatistics.gd")
const Trace = preload("res://scripts/performance/PerformanceTrace.gd")
const MENU := "res://scenes/main_menu/MainMenu.tscn"
const SETUP := "res://scenes/battle_setup/BattleSetup.tscn"
const BATTLE := "res://scenes/battle/BattleScene.tscn"
const RULES := "res://data/ptcgdap/author_strategy_packages/marnies-gift-box-turn-program-round05-5.21.0.ptcgai"
const MODEL := "res://tests/ai/ptcgdap/fixtures/platform_model.ptcgai"
const DOWNLOADED_RULES := "res://data/ptcgdap/author_strategy_package_backups/reviewed-raging-bolt-ogerpon-1.0.0-round30-20ED94DE.ptcgai"
const PREFIX := "PTCGDAP_PERFORMANCE_BENCH="
var _rows: Array = []
var _gaps: Array = []
var _last_frame_usec := 0
var _output := "user://performance/result.json"
var _group := "all"
var _repeat := 3
var _active := false
var _iteration := 0
var _startup_usec := 0
var _fixture_identities := {}
var _diagnostic_author_ref: Dictionary = {}
var _arena_window := Vector2i.ZERO
var _arena_profile_cpu := false

func _ready() -> void:
	get_tree().root.set_meta("performance_bench_offline", true)
	_startup_usec = Time.get_ticks_usec()
	if OS.get_name() == "Android":
		_output = "/sdcard/Android/data/com.example.ptcgdeckagent.performance/files/performance/result.json"
		DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-output="): _output = arg.trim_prefix("--perf-output=")
		if arg.begins_with("--perf-group="): _group = arg.trim_prefix("--perf-group=")
		if arg.begins_with("--perf-repeat="): _repeat = clampi(int(arg.trim_prefix("--perf-repeat=")), 1, 30)
	get_tree().process_frame.connect(_frame)
	call_deferred("_run")

func _frame() -> void:
	var now := Time.get_ticks_usec()
	if _active and _last_frame_usec > 0:
		_gaps.append(float(now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_record("startup.autoloads", float(_startup_usec) / 1000.0, true)
	if get_tree().current_scene == null:
		await _scene_case("startup.main_menu", MENU)
	_record("startup.first_scene_frame_since_process", float(Time.get_ticks_usec()) / 1000.0, true)
	if OS.get_name() == "Android":
		# Let the app create its own scoped directory before ADB pushes the request.
		# A shell-created directory belongs to shell and can deny app writes.
		var request_path := _output.get_base_dir().path_join("request.json")
		var waiting := Time.get_ticks_msec()
		while not FileAccess.file_exists(request_path) and Time.get_ticks_msec() - waiting < 60000:
			await get_tree().create_timer(0.1).timeout
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path)) if FileAccess.file_exists(request_path) else null
		if not request is Dictionary:
			_record("configuration", 0, false, "request_missing_or_invalid")
			_finish()
			return
		_group = str(request.get("group", _group))
		_repeat = clampi(int(request.get("repeat", _repeat)), 1, 30)
		_arena_profile_cpu = bool(request.get("profile_cpu",false))
		var requested: Array = request.get("window",[])
		if requested.size() == 2:
			_arena_window = Vector2i(int(requested[0]),int(requested[1]))
			GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT if _arena_window.y > _arena_window.x else GameManager.BATTLE_LAYOUT_LANDSCAPE
			GameManager.apply_battle_layout_orientation()
			await get_tree().create_timer(.5).timeout
	if _group in ["arena_input","arena_live","arena_feedback"]:
		if _group == "arena_live": await _install_diagnostic_strategy()
		if get_tree().current_scene != null:
			get_tree().current_scene.queue_free()
			get_tree().current_scene = null
			await get_tree().process_frame
		var probe_path := "res://scripts/performance/ArenaAndroidInputAcceptance.gd"
		if _group == "arena_live": probe_path = "res://scripts/performance/ArenaAndroidLiveEntryAcceptance.gd"
		if _group == "arena_feedback": probe_path = "res://scripts/performance/ArenaAndroidFeedbackAcceptance.gd"
		var input_probe = load(probe_path).new()
		if _group == "arena_feedback": input_probe.requested_window = _arena_window
		if _group == "arena_live":
			input_probe.author_ref = _diagnostic_author_ref
			input_probe.requested_window = _arena_window
		input_probe.output = _output
		get_tree().root.add_child(input_probe)
		return
	if _group in ["arena_2d","arena_3d","arena_review"]:
		var arena = load("res://scripts/performance/ArenaPortableReview.gd" if _group == "arena_review" else "res://scripts/performance/ArenaPerformanceRunner.gd").new()
		arena.mode = "3d" if _group == "arena_review" else _group.trim_prefix("arena_")
		if OS.get_name() == "Android": arena.dimensions = _arena_window if _arena_window != Vector2i.ZERO else get_tree().root.size
		arena.output = _output
		arena.seconds = 20.0
		if _group != "arena_review": arena.profile_cpu = _arena_profile_cpu
		get_tree().root.add_child(arena)
		return
	if _group not in ["all", "components", "navigation", "battle", "author_start", "matches"]:
		_record("configuration", 0, false, "unknown_group")
		_finish()
		return
	if _group in ["all", "battle", "author_start"]:
		await _install_diagnostic_strategy()
	for index: int in _repeat:
		_iteration = index
		if _group in ["all", "components"]:
			await _components()
		if _group in ["all", "navigation"]:
			await _navigation()
		if _group in ["all", "battle"]:
			await _battle(false)
			await _battle(true)
		if _group == "author_start":
			await _battle(true)
		if _group == "matches":
			await _matches()
	_finish()

func _install_diagnostic_strategy() -> void:
	# Replays a fixed downloaded release into isolated diagnostic user data.
	# No network, production account, or metadata-only admission bypass.
	var bytes := FileAccess.get_file_as_bytes(DOWNLOADED_RULES)
	var sha := FileAccess.get_sha256(DOWNLOADED_RULES).to_upper()
	var loader: Variant = load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd").new()
	var inspected: Dictionary = loader.inspect_control_distributed_player_match_bytes(bytes, sha)
	if not inspected.get("ok", false):
		_record("fixture.install", 0, false, str(inspected.get("error_code")))
		return
	var release := {}
	for key: String in ["package_id", "package_version", "archive_sha256", "manifest_canonical_sha256"]:
		release[key] = inspected.metadata[key]
	var installed: Dictionary = await _sync_case("strategy.install", func():
		return AuthorStrategyPackageCatalog.install_from_bytes(bytes, release))
	if not installed.get("ok", false): return
	for record: Dictionary in AuthorStrategyPackageCatalog.list_metadata_records():
		if record.get("archive_sha256") == sha and record.get("install_source") == "user":
			_diagnostic_author_ref = record.duplicate(true)
			break
	_fixture_identities["battle.author"] = release
	_fixture_identities["battle.classic"] = {"player_deck": 575720, "opponent_deck": 575718, "first_player": 0}

func _begin() -> int:
	_gaps.clear()
	_active = true
	_last_frame_usec = Time.get_ticks_usec()
	return _last_frame_usec

func _record(name: String, elapsed: float, ok: bool, reason: String = "", extra: Dictionary = {}) -> void:
	var row := {"case": name, "iteration": _iteration,
		"cache_state": "first_in_process" if _iteration == 0 else "warm_in_process",
		"duration_ms": elapsed, "ok": ok, "error": reason,
		"frame_gaps_ms": _gaps.duplicate(), "frames": Stats.summarize(_gaps)}
	row.merge(extra)
	_rows.append(row)
	print("PERF_CASE " + name + " " + str(snappedf(elapsed, 0.01)) + " ms " + ("ok" if ok else reason))
	_active = false
	_gaps.clear()

func _sync_case(name: String, operation: Callable) -> Variant:
	await get_tree().process_frame
	var started := _begin()
	var result: Variant = operation.call()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	await get_tree().process_frame
	var ok := true
	var reason := ""
	if result is Dictionary and result.has("ok"):
		ok = bool(result.ok)
		reason = str(result.get("error_code", ""))
	_record(name, elapsed, ok, reason, {"measurement": "component", "feedback_ms": null})
	return result

func _components() -> void:
	await _sync_case("cards.search", func(): return CardDatabase.search_catalog_cards("喷火龙", {}, 50))
	await _sync_case("decks.list", func(): return CardDatabase.get_all_decks())
	await _sync_case("catalog.refresh", func(): return AuthorStrategyPackageCatalog.scan_startup())
	for fixture: String in [RULES, MODEL]:
		var label := "model" if fixture == MODEL else "rules"
		var bytes := FileAccess.get_file_as_bytes(fixture)
		if bytes.is_empty():
			_record(label + ".fixture", 0, false, "fixture_missing")
			continue
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		var sha := hash.finish().hex_encode().to_upper()
		_fixture_identities[label] = {"sha256": sha, "bytes": bytes.size()}
		var loader: Variant = await _sync_case(label + ".loader_construct", func():
			return load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd").new())
		var inspected: Dictionary = await _sync_case(label + ".archive_verify", func():
			return loader.inspect_control_distributed_player_match_bytes(bytes, sha))
		if not inspected.get("ok", false): continue
		var mapped: Dictionary = await _sync_case(label + ".deck_validate", func():
			return load("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd").build(inspected.payloads))
		if not mapped.get("ok", false): continue
		var created: Dictionary = await _sync_case(label + ".handle_create", func():
			return load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd").create(inspected.metadata, inspected.payloads, mapped.local_deck))
		if not created.get("ok", false): continue
		var handle: Variant = created.handle
		await _sync_case(label + ".handle_snapshot", func(): return handle.to_public_dict())
		var materialized: Dictionary = await _sync_case(label + ".deck_materialize", func():
			return GameManager.materialize_author_strategy_battle_deck(handle))
		if not materialized.get("ok", false): continue
		var gsm := GameStateMachine.new()
		seed(84590)
		gsm.random_event_port.configure_seed(84590)
		await _sync_case(label + ".engine_start", func():
			gsm.start_game(CardDatabase.get_deck(575720), materialized.deck, 0, false, true)
			return {"ok": gsm.game_state != null})
		var built: Dictionary = await _sync_case(label + ".owner_create", func():
			return load("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd").build_windows_author_owner(
				handle, gsm, 1, "perf-%s-%d" % [label, _iteration], "control_distributed_player"))
		if built.get("ok", false):
			await _sync_case(label + ".worker_prepare", func():
				return {"ok": bool(built.owner.configure_policy_execution_profile("worker_v1"))})
			built.owner.close_match()
		gsm.prepare_for_disposal()

func _clear_scene() -> void:
	if get_tree().current_scene != null:
		var old := get_tree().current_scene
		get_tree().current_scene = null
		old.queue_free()
	await get_tree().process_frame

func _scene_case(name: String, path: String) -> Node:
	await _clear_scene()
	var started := _begin()
	var packed: PackedScene = load(path)
	if packed == null:
		_record(name, float(Time.get_ticks_usec() - started) / 1000.0, false, "scene_missing")
		return null
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	_record(name, float(Time.get_ticks_usec() - started) / 1000.0, true, "", {"measurement": "scene_ready", "feedback_ms": null})
	return scene

func _navigation() -> void:
	for target: Array in [
		["battle_setup", "_on_start_battle", SETUP],
		["deck_manager", "_on_deck_manager", "res://scenes/deck_manager/DeckManager.tscn"],
		["strategy_hub", "_on_strategy_hub", "res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn"],
		["settings", "_on_settings", "res://scenes/settings/Settings.tscn"],
		["deck_training", "_on_deck_training", "res://scenes/deck_training/DeckTrainingBrowser.tscn"],
	]:
		var menu: Node = await _scene_case("menu.return", MENU)
		if menu == null: continue
		var started := _begin()
		if target[0] == "settings":
			GameManager.goto_scene(str(target[2]))
		elif menu.has_method(target[1]):
			menu.call(target[1])
		else:
			_record("navigation." + str(target[0]), 0, false, "handler_missing")
			continue
		var reached := await _wait_scene(target[2], 30000)
		_record("navigation." + str(target[0]), float(Time.get_ticks_usec() - started) / 1000.0, reached,
			"" if reached else "navigation_timeout", {"measurement": "navigation", "feedback_ms": _feedback_since(started)})
		if reached and target[0] == "battle_setup":
			var setup := get_tree().current_scene
			await _sync_case("setup.ai_picker", func(): setup.call("_on_deck_picker_pressed", 1))
			await _sync_case("setup.picker_search", func():
				setup.call("_on_deck_picker_search_changed", "玛俐")
				setup.call("_refresh_deck_picker"))
			setup.call("_close_deck_picker")

func _battle(author: bool) -> void:
	var setup: Node = await _scene_case("setup.open", SETUP)
	if setup == null: return
	if author:
		if _diagnostic_author_ref.is_empty():
			_record("battle.author_start", 0, false, "author_fixture_missing")
			return
		setup.call("_on_deck_picker_author_strategy_selected", _diagnostic_author_ref)
	else:
		setup.call("_on_mode_segment_pressed", 1)
		setup.call("_on_deck_picker_deck_selected", 1, 575718)
	setup.call("_on_deck_picker_deck_selected", 0, 575720)
	(setup.find_child("FirstPlayerOption", true, false) as OptionButton).select(1)
	var started := _begin()
	setup.call("_on_start")
	var reached := await _wait_scene(BATTLE, 60000)
	var scene := get_tree().current_scene
	var error := ""
	if reached:
		error = str(scene.get("_author_runtime_start_error_code")) if author else ""
		if scene.get("_gsm") == null: error = "engine_missing"
	else: error = "battle_start_timeout"
	_record("battle.author_start" if author else "battle.classic_start", float(Time.get_ticks_usec() - started) / 1000.0,
		reached and error.is_empty(), error, {"measurement": "interaction", "feedback_ms": _feedback_since(started)})
	if reached and error.is_empty():
		await _sync_case("battle.ui_refresh", func(): scene.call("_refresh_ui"))
		# Exercise the actual full board refresh repeatedly while the scene is alive.
		var idle := _begin()
		while Time.get_ticks_usec() - idle < 1000000:
			await get_tree().process_frame
		_record("battle.idle_frames", float(Time.get_ticks_usec() - idle) / 1000.0, true, "", {"measurement": "frame_window", "feedback_ms": null})
	await _clear_scene()

func _feedback_since(started: int) -> Variant:
	if not GameManager.has_method("scene_loading_feedback_usec"):
		return null
	var painted := int(GameManager.call("scene_loading_feedback_usec"))
	return float(painted - started) / 1000.0 if DisplayServer.get_name() != "headless" and painted >= started else null

func _wait_scene(path: String, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path:
			var scene := get_tree().current_scene
			if scene.has_method("is_scene_preparation_pending") and scene.is_scene_preparation_pending():
				continue
			await get_tree().process_frame
			return true
	return false

func _matches() -> void:
	for modeled: bool in [false, true]:
		var suite: Variant = load("res://tests/ai/ptcgdap/test_platform_player_matches.gd").new()
		suite.seed_override = 84590
		var started := _begin()
		var error: String = await suite._match(modeled, 1)
		_record("match.model" if modeled else "match.rules", float(Time.get_ticks_usec() - started) / 1000.0,
			error.is_empty(), error, {"measurement": "full_match_logic", "audit": suite.last_report, "feedback_ms": null})
		var label := "match.model" if modeled else "match.rules"
		var audit: Dictionary = suite.last_report.get("audit", {})
		_fixture_identities[label] = {"archive_sha256": audit.get("archive_sha256", ""),
			"seed": suite.last_report.get("seed"), "seat": 1, "opponent_deck": 575720}
		for elapsed_usec: Variant in audit.get("decision_elapsed_usec", []):
			_record(label + ".decision", float(elapsed_usec) / 1000.0, true, "", {"measurement": "policy_decision"})
		for elapsed_usec: Variant in audit.get("model_elapsed_usec", []):
			_record(label + ".inference", float(elapsed_usec) / 1000.0, true, "", {"measurement": "model_inference"})

func _finish() -> void:
	var failed := 0
	for row: Dictionary in _rows:
		if not row.ok: failed += 1
	var report := {"schema_version": 1, "kind": "ptcgdap_performance_bench", "group": _group,
		"platform": {"os": OS.get_name(), "os_version": OS.get_version(),
			"model": OS.get_model_name(), "cpu": OS.get_processor_name(), "cpu_count": OS.get_processor_count(),
			"architecture": Engine.get_architecture_name(), "engine": Engine.get_version_info().string,
			"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"debug_build": OS.is_debug_build(), "editor_binary": OS.has_feature("editor"),
			"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]},
		"fixtures": _fixture_identities, "cases": _rows, "failed_cases": failed, "stages": Trace.snapshot(),
		"memory": OS.get_memory_info(), "static_peak_bytes": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"claims": {"device_acceptance": false, "physical_android": false, "network_measurement": false}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output.get_base_dir()))
	var file := FileAccess.open(_output, FileAccess.WRITE)
	if file == null:
		push_error("Performance report could not be written")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(PREFIX + JSON.stringify({"output": _output, "cases": _rows.size(), "failed": failed}))
	await _clear_scene()
	get_tree().quit(0 if failed == 0 else 1)
