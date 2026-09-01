extends SceneTree

const OUTPUT_ROOT := "res://artifacts/ptcgdap/d118_strategy_hub_hud"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var requested_capture := ""
	var reset_report := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			requested_capture = arg.trim_prefix("--capture=").strip_edges()
		elif arg == "--reset-report":
			reset_report = true
	var requests: Array[Dictionary] = [
		{"name": "landscape-local", "size": Vector2i(1600, 900), "mode": "landscape", "workspace": "local"},
		{"name": "landscape-replays", "size": Vector2i(1600, 900), "mode": "landscape", "workspace": "replays"},
		{"name": "landscape-catalog", "size": Vector2i(1600, 900), "mode": "landscape", "workspace": "catalog"},
		{"name": "portrait-local", "size": Vector2i(600, 1000), "mode": "portrait", "workspace": "local"},
		{"name": "portrait-catalog", "size": Vector2i(600, 1000), "mode": "portrait", "workspace": "catalog"},
	]
	if not requested_capture.is_empty():
		requests = requests.filter(func(request: Dictionary) -> bool: return str(request.name) == requested_capture)
	if requests.is_empty():
		_finish_with_error("capture_request_unknown")
		return
	var capture_viewport: Viewport = root
	var isolated_viewport: SubViewport = null
	if requests.size() == 1:
		var initial_request: Dictionary = requests[0]
		isolated_viewport = SubViewport.new()
		isolated_viewport.size = initial_request.size
		isolated_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(isolated_viewport)
		capture_viewport = isolated_viewport
		var initial_game_manager := root.get_node_or_null("GameManager")
		if initial_game_manager != null:
			initial_game_manager.call("set_non_battle_layout_mode", str(initial_request.mode), false, false)
		for _initial_frame: int in 4:
			await process_frame
	var hub_scene := load("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn") as PackedScene
	if hub_scene == null:
		_finish_with_error("strategy_hub_scene_unavailable")
		return
	var hub: Control = hub_scene.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	capture_viewport.add_child(hub)
	for _frame: int in 8:
		await process_frame
	hub.apply_local_package_catalog_for_test({
		"metadata_records": [
			{
				"package_id": "visual.cynthia",
				"package_version": "1.0.0",
				"archive_sha256": "A".repeat(64),
				"install_source": "user",
				"install_sources": ["user"],
				"author": {"display_name": "PtcgDAP Strategy Lab"},
				"strategy": {"display_name": "竹兰烈咬陆鲨 Windows 本地候选 v1"},
				"deck": {"display_name": "18.0 竹兰烈咬陆鲨"},
				"status": "metadata_only",
			},
			{
				"package_id": "visual.marnie",
				"package_version": "0.1.0",
				"archive_sha256": "B".repeat(64),
				"install_source": "builtin",
				"install_sources": ["builtin"],
				"author": {"display_name": "PtcgDAP"},
				"strategy": {"display_name": "Marnie 18.0 长毛巨魔 Windows 本地策略"},
				"deck": {"display_name": "18.0 玛俐的长毛巨魔"},
				"status": "metadata_only",
			},
		],
		"ready_records": [],
		"diagnostics": [],
	})
	hub.call("_render_local_replays", [{
		"match_id": "visual-native-replay",
		"match_dir": "user://match_records/visual-native-replay",
		"turn_count": 8,
		"winner_index": 0,
		"player_labels": ["玩家", "竹兰 AI"],
		"recorded_at": "2026-08-23 18:36",
	}], [], 0)
	hub.apply_catalog_for_test([
		{"strategy_id": "cynthia-public", "display_name": "竹兰烈咬陆鲨", "author_display_name": "PtcgDAP Strategy Lab"},
		{"strategy_id": "marnie-public", "display_name": "玛俐长毛巨魔", "author_display_name": "PtcgDAP"},
	])
	hub.apply_detail_for_test({
		"strategy_id": "cynthia-public",
		"display_name": "竹兰烈咬陆鲨",
		"summary": "以稳定展开和中后盘资源调度为核心的公开策略版本。",
		"author": {"display_name": "PtcgDAP Strategy Lab"},
		"releases": [{"release_id": "cynthia-r1", "package_version": "1.0.0", "release_state": "verified", "player_start_allowed": true}],
		"representative_replays": [{"replay_id": "cynthia-showcase-01", "frame_count": 84, "release_id": "cynthia-r1", "share_uri": "ptcgdap://replay/cynthia-showcase-01"}],
	})
	hub.apply_statistics_for_test({
		"official": {"available": true, "summary": {"counts": {"wins": 17, "valid": 25}}},
		"shadow": {"available": true, "summary": {"counts": {"wins": 42, "valid": 60}}},
		"community": {"active_replay_count": 12},
	})
	var output_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	if DirAccess.make_dir_recursive_absolute(output_root) not in [OK, ERR_ALREADY_EXISTS]:
		_finish_with_error("output_directory_failed")
		return
	var captures: Array[Dictionary] = []
	for request: Dictionary in requests:
		var game_manager := root.get_node_or_null("GameManager")
		if game_manager != null:
			game_manager.call("set_non_battle_layout_mode", str(request.mode), false, false)
		if isolated_viewport != null:
			isolated_viewport.size = request.size
		else:
			root.size = request.size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
			root.content_scale_size = request.size
		for _settle_frame: int in 5:
			await process_frame
		hub.apply_non_battle_layout_for_test(Vector2(request.size), str(request.mode))
		hub.select_workspace_for_test(str(request.workspace))
		for _frame: int in 8:
			if isolated_viewport == null:
				root.content_scale_size = request.size
			await process_frame
		var viewport_texture := capture_viewport.get_texture()
		var image := viewport_texture.get_image() if viewport_texture != null else null
		if image == null:
			_finish_with_error("viewport_image_unavailable_%s" % request.name)
			return
		var image_path := "%s/%s.png" % [output_root, request.name]
		if image.save_png(image_path) != OK:
			_finish_with_error("screenshot_write_failed_%s" % request.name)
			return
		captures.append({
			"name": request.name,
			"viewport": {"width": image.get_width(), "height": image.get_height()},
			"workspace": request.workspace,
			"tab_widths": [
				(hub.get_node("%LocalStrategyTab") as Button).size.x,
				(hub.get_node("%ReplayTab") as Button).size.x,
				(hub.get_node("%CatalogTab") as Button).size.x,
			],
			"sha256": _sha256(FileAccess.get_file_as_bytes(image_path)),
		})
	var merged_captures := {}
	var report_path := "%s/visual_acceptance.json" % output_root
	if not reset_report and FileAccess.file_exists(report_path):
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if decoded is Dictionary:
			for prior: Variant in (decoded as Dictionary).get("captures", []):
				if prior is Dictionary:
					merged_captures[str((prior as Dictionary).get("name", ""))] = (prior as Dictionary).duplicate(true)
	for capture: Dictionary in captures:
		merged_captures[str(capture.get("name", ""))] = capture.duplicate(true)
	var ordered_captures: Array[Dictionary] = []
	for name: String in ["landscape-local", "landscape-replays", "landscape-catalog", "portrait-local", "portrait-catalog"]:
		if merged_captures.has(name):
			ordered_captures.append(merged_captures[name])
	var report := {
		"document_type": "ptcgdap_strategy_hub_hud_visual_acceptance_v1",
		"captures": ordered_captures,
		"mock_data": true,
		"functional_authority": false,
		"official_cabt_validation": false,
		"workspace_tabs": ["local", "replays", "catalog"],
		"layout_modes": ["landscape", "portrait"],
	}
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		_finish_with_error("report_write_failed")
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("PTCGDAP_STRATEGY_HUB_HUD_VISUAL_ACCEPTANCE %s" % JSON.stringify(report))
	hub.queue_free()
	await process_frame
	quit(0)


func _finish_with_error(code: String) -> void:
	push_error("PTCGDAP strategy hub HUD capture failed: %s" % code)
	quit(1)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
