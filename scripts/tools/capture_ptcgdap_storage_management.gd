extends SceneTree

const OUTPUT_ROOT := "res://artifacts/ptcgdap/d125_replay_delete_and_storage_paths"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = root.size
	var packed := load("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn") as PackedScene
	if packed == null:
		quit(2)
		return
	var hub: Control = packed.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	root.add_child(hub)
	for _frame: int in 8:
		await process_frame
	hub.apply_local_package_catalog_for_test({
		"metadata_records": [{
			"package_id": "visual.storage.strategy",
			"package_version": "1.0.0",
			"archive_sha256": "A".repeat(64),
			"install_source": "built_in",
			"install_sources": ["built_in"],
			"author": {"display_name": "PtcgDAP"},
			"strategy": {"display_name": "录像与路径管理验收策略"},
			"deck": {"display_name": "18.0 验收卡组"},
			"status": "ready",
		}],
		"ready_records": [],
		"diagnostics": [],
	})
	hub.call("_render_local_replays", [{
		"match_id": "visual-native-replay",
		"match_dir": "user://match_records/visual-native-replay",
		"mode": "vs_ai",
		"turn_count": 8,
		"winner_index": 0,
		"player_labels": ["玩家", "AI"],
		"recorded_at": "2026-08-23T19:34:12",
		"started_at_utc": "2026-08-23T11:34:12Z",
	}], [{
		"source": "local",
		"replay_id": "visual-public-only",
		"match_id": "public-visual",
		"frame_count": 40,
		"started_at_utc": "2026-08-23T10:00:00Z",
	}], 0)
	var output_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	if DirAccess.make_dir_recursive_absolute(output_root) not in [OK, ERR_ALREADY_EXISTS]:
		quit(3)
		return
	var captures: Array[Dictionary] = []
	var requests: Array[Dictionary] = [
		{"name": "landscape-local", "workspace": "local", "mode": "landscape", "size": Vector2i(1600, 900)},
		{"name": "landscape-replays", "workspace": "replays", "mode": "landscape", "size": Vector2i(1600, 900)},
		{"name": "portrait-local", "workspace": "local", "mode": "portrait", "size": Vector2i(600, 1000)},
		{"name": "portrait-replays", "workspace": "replays", "mode": "portrait", "size": Vector2i(600, 1000)},
	]
	for request: Dictionary in requests:
		root.size = request.size
		root.content_scale_size = request.size
		var game_manager := root.get_node_or_null("GameManager")
		if game_manager != null:
			game_manager.call(
				"set_non_battle_layout_mode", str(request.mode), false, false
			)
		hub.apply_non_battle_layout_for_test(Vector2(request.size), str(request.mode))
		hub.select_workspace_for_test(str(request.workspace))
		for _frame: int in 8:
			await process_frame
		var texture := root.get_texture()
		var image := texture.get_image() if texture != null else null
		if image == null:
			quit(4)
			return
		var path := "%s/%s.png" % [output_root, str(request.name)]
		if image.save_png(path) != OK:
			quit(5)
			return
		captures.append({
			"name": request.name,
			"workspace": request.workspace,
			"viewport": {"width": image.get_width(), "height": image.get_height()},
			"path": ProjectSettings.localize_path(path),
			"sha256": _sha256(FileAccess.get_file_as_bytes(path)),
		})
	var report := {
		"document_type": "ptcgdap_storage_management_visual_acceptance_v1",
		"viewports": ["1600x900", "600x1000"],
		"captures": captures,
		"storage_paths": hub.storage_paths_snapshot(),
		"native_delete_button_count": hub.get_node("%LocalReplayList").find_children(
			"NativeReplayDeleteButton", "Button", true, false
		).size(),
		"public_delete_button_count": hub.get_node("%LocalReplayList").find_children(
			"PublicReplayDeleteButton", "Button", true, false
		).size(),
		"package_copy_button": hub.get_node_or_null("%CopyLocalPackageFolderButton") != null,
		"native_copy_button": hub.get_node_or_null("%CopyNativeReplayFolderButton") != null,
		"public_copy_button": hub.get_node_or_null("%CopyPublicReplayFolderButton") != null,
		"mock_data": true,
		"filesystem_mutation": false,
	}
	var report_file := FileAccess.open(
		OUTPUT_ROOT.path_join("visual_acceptance.json"), FileAccess.WRITE
	)
	if report_file == null:
		quit(6)
		return
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	report_file.close()
	print("PTCGDAP_STORAGE_MANAGEMENT_VISUAL_ACCEPTANCE %s" % JSON.stringify(report))
	hub.queue_free()
	await process_frame
	quit(0)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
