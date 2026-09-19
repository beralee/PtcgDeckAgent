extends Node

## Diagnostic export only. All player gates, HTTPS, installers and match owners
## are real. UI signals are programmatic; this is not physical mouse evidence.
const HUB := "res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn"
const SETUP := "res://scenes/battle_setup/BattleSetup.tscn"
const BATTLE := "res://scenes/battle/BattleScene.tscn"
const RELEASE := "release-9abe532ad39fa6c2a04385382a7eb3826642497e"
var output := ""
var offline_receipt := ""
var captured: Dictionary = {}
var download_events := 0
var report := {"physical_mouse_input": false, "diagnostic_export": true, "checks": []}
var error_gate = preload("res://tests/SharedSuiteRunner.gd").ScriptErrorGate.new()

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--macos-acceptance-output="):
			output = arg.trim_prefix("--macos-acceptance-output=")
		if arg.begins_with("--macos-offline-receipt="):
			offline_receipt = arg.trim_prefix("--macos-offline-receipt=")
	if not output.is_empty():
		OS.add_logger(error_gate)
		_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	report.merge({"os": OS.get_name(), "arch": Engine.get_architecture_name(),
		"standalone_export": OS.has_feature("template"), "user_data": OS.get_user_data_dir()})
	if OS.get_name() != "macOS" or not OS.get_user_data_dir().contains("PtcgDAP-macOS-acceptance-"):
		_finish("isolated_mac_test_profile_required")
		return
	await get_tree().process_frame
	await _capture("01-main-menu")
	var hub_button := get_tree().current_scene.find_child("BtnStrategyHub", true, false) as Button
	if hub_button == null or hub_button.disabled:
		_finish("main_menu_hub_button_unavailable")
		return
	hub_button.pressed.emit()
	if not await _wait_scene(HUB):
		_finish("hub_not_opened")
		return
	if not offline_receipt.is_empty():
		await _run_offline()
		return
	var hub := get_tree().current_scene
	var client: Node = hub.get("_client")
	if client == null:
		_finish("hub_client_missing")
		return
	client.connect("request_completed", _received)
	var deadline := Time.get_ticks_msec() + 45000
	var download: Button = null
	while download == null and Time.get_ticks_msec() < deadline:
		for button: Node in hub.find_children("LadderDownloadButton*", "Button", true, false):
			if button.get_meta("ladder_listing", {}).get("release_id") == RELEASE:
				download = button
		await get_tree().process_frame
	if download == null:
		_finish("live_rules_release_not_listed")
		return
	if not download.get_meta("start_strategy_ref", {}).is_empty():
		_finish("fresh_diagnostic_export_required_for_online_download")
		return
	if not await _reveal(download):
		_finish("download_button_not_visible_after_scroll")
		return
	await _capture("02-live-ladder")
	download.pressed.emit()
	# A second click while resolving the exact release must not start two requests.
	download.pressed.emit()
	deadline = Time.get_ticks_msec() + 60000
	while captured.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if captured.is_empty():
		report["hub_status"] = hub.get("_workspace_statuses")
		_finish("live_download_failed")
		return
	for frame: int in 5: await get_tree().process_frame
	var reference: Dictionary = captured.get("expected_release", {})
	var path := output.path_join("downloaded.ptcgai")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(captured.package_bytes)
	file.close()
	report["download"] = {"release": reference, "sha256": FileAccess.get_sha256(path).to_upper(),
		"button_text": download.text, "disabled": download.disabled, "download_events": download_events}
	if FileAccess.get_sha256(path).to_upper() != reference.get("archive_sha256") \
			or download_events != 1 or download.disabled or download.get_meta("start_strategy_ref", {}).get("archive_sha256") != reference.get("archive_sha256"):
		_finish("installed_package_not_startable")
		return
	report.checks.append("HTTPS download, exact hash, strict install, button becomes battle")
	await _capture("03-installed")
	download.pressed.emit()
	await _play_selection(reference)

func _run_offline() -> void:
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(offline_receipt))
	if not previous is Dictionary or not previous.get("ok", false):
		_finish("successful_online_receipt_required")
		return
	var reference: Dictionary = previous.get("download", {}).get("release", {})
	report["download"] = previous.download
	report["offline_restart"] = true
	var hub := get_tree().current_scene
	var local_tab := hub.find_child("LocalStrategyTab", true, false) as Button
	local_tab.pressed.emit()
	for frame: int in 4: await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 15000
	var start: Button = null
	while start == null and Time.get_ticks_msec() < deadline:
		for button: Node in hub.find_children("LocalPackageStartButton*", "Button", true, false):
			for connection: Dictionary in button.get_signal_connection_list("pressed"):
				var args: Array = connection.callable.get_bound_arguments()
				if not args.is_empty() and args[0] is Dictionary and args[0].get("archive_sha256") == reference.get("archive_sha256"):
					start = button
		await get_tree().process_frame
	if start == null or start.disabled:
		_finish("installed_rules_not_available_after_offline_restart")
		return
	if not await _reveal(start):
		_finish("local_start_button_not_visible_after_scroll")
		return
	await _capture("02-offline-library")
	report.checks.append("offline restart rediscovers exact installed package in local library")
	start.pressed.emit()
	await _play_selection(reference)

func _play_selection(reference: Dictionary) -> void:
	if not await _wait_scene(SETUP):
		_finish("download_to_setup_navigation_failed")
		return
	var setup := get_tree().current_scene
	var start: Button = setup.find_child("BtnStart", true, false)
	await _capture("04-battle-setup")
	if start == null or start.disabled or GameManager.get_author_strategy_selection().get("archive_sha256") != reference.get("archive_sha256"):
		_finish("exact_download_not_selected_in_setup")
		return
	report.checks.append("installed strategy navigates to setup with exact identity")
	start.pressed.emit()
	if not await _wait_scene(BATTLE):
		_finish("battle_scene_not_started")
		return
	var battle := get_tree().current_scene
	var gsm: Variant = battle.get("_gsm")
	var author: Variant = battle.get("_author_player_owner")
	if gsm == null or author == null:
		_finish("real_author_owner_missing")
		return
	# Supply a test opponent for the human seat. The downloaded strategy retains
	# its unmodified production admission, owner and scene scheduling.
	var rules := AIOpponent.new()
	rules.configure(0, 1)
	DeckStrategyRegistry.new().apply_strategy_for_deck(rules, GameManager.resolve_selected_battle_deck(0))
	rules.use_mcts = false
	rules.decision_runtime_mode = AIOpponent.DECISION_RUNTIME_RULES_ONLY
	battle.set("_development_player_rules_owner", rules)
	battle.set("_author_development_ui_match_active", true)
	battle.set("_ai_action_pause_seconds", 0.02)
	GameManager.battle_effects_enabled = false
	battle.call("_maybe_run_ai")
	await _capture("05-battle")
	var deadline := Time.get_ticks_msec() + 240000
	while not gsm.game_state.is_game_over() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var audit: Dictionary = author.audit_snapshot()
	report["ui_match"] = {"game_over": gsm.game_state.is_game_over(),
		"winner": gsm.game_state.winner_index, "turn": gsm.game_state.turn_number,
		"reason": gsm.game_state.win_reason, "audit": audit}
	await _capture("06-terminal")
	if not gsm.game_state.is_game_over() or int(audit.get("policy_successes", 0)) <= 0:
		_finish("ui_match_not_completed")
		return
	for key: String in ["policy_errors", "invalid_outputs", "same_window_fallbacks", "engine_rejections"]:
		if int(audit.get(key, 0)) != 0:
			_finish("dirty_ui_match_" + key)
			return
	report.checks.append("real BattleScene completes with downloaded rules, zero failure counters")
	author = null
	rules = null
	gsm = null
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	battle = null
	await get_tree().process_frame
	await get_tree().process_frame
	_finish("")

func _wait_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path:
			for frame: int in 4: await get_tree().process_frame
			return true
	return false

func _received(result: Dictionary) -> void:
	if result.get("accepted", false) and result.get("package_bytes") is PackedByteArray:
		download_events += 1
		captured = result

func _reveal(control: Control) -> bool:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			for frame: int in 3: await get_tree().process_frame
		ancestor = ancestor.get_parent()
	if not control.is_visible_in_tree() or not get_viewport().get_visible_rect().encloses(control.get_global_rect()):
		return false
	ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().encloses(control.get_global_rect()):
			return false
		ancestor = ancestor.get_parent()
	return true

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null: image.save_png(output.path_join(name + ".png"))

func _finish(error: String) -> void:
	report["error"] = error
	report["script_errors"] = error_gate.take_script_errors()
	report["ok"] = error.is_empty() and report.script_errors.is_empty()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "  "))
	print("MACOS_RULES_ACCEPTANCE " + JSON.stringify(report))
	OS.remove_logger(error_gate)
	get_tree().quit(0 if report.ok else 1)
