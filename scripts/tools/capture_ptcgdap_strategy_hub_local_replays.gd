extends SceneTree

const OUTPUT_ROOT := "res://artifacts/ptcgdap/local_replay_history_20260822"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var hub_scene := load("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn") as PackedScene
	if hub_scene == null:
		_finish_with_error("strategy_hub_scene_unavailable")
		return
	var hub: Control = hub_scene.instantiate()
	root.add_child(hub)
	for _frame: int in 20:
		await process_frame
	var local_list := hub.get_node_or_null("%LocalReplayList") as VBoxContainer
	if local_list == null:
		_finish_with_error("local_replay_list_unavailable")
		return
	var replay_ids: Array[String] = []
	var watch_button_count := 0
	for child: Node in local_list.find_children("*", "", true, false):
		if child is Button and str(child.name) == "LocalReplayWatchButton":
			watch_button_count += 1
		elif child is Label and not child.tooltip_text.is_empty():
			replay_ids.append(child.tooltip_text)
	replay_ids.sort()
	var expected_ids: Array[String] = []
	for value: String in OS.get_environment("PTCGDAP_EXPECT_LOCAL_REPLAY_IDS").split(",", false):
		expected_ids.append(value.strip_edges())
	expected_ids.sort()
	if not expected_ids.is_empty() and replay_ids != expected_ids:
		_finish_with_error("installed_replay_ids_mismatch")
		return
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_finish_with_error("rendering_driver_no_viewport_texture")
		return
	var image := viewport_texture.get_image()
	if image == null:
		_finish_with_error("rendering_driver_no_viewport_image")
		return
	var absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	if dir_error not in [OK, ERR_ALREADY_EXISTS]:
		_finish_with_error("output_directory_failed")
		return
	var image_path := "%s/strategy_hub_local_history.png" % absolute_root
	if image.save_png(image_path) != OK:
		_finish_with_error("screenshot_write_failed")
		return
	var report := {
		"document_type": "ptcgdap_local_replay_history_visual_acceptance_v1",
		"viewport": {"width": root.size.x, "height": root.size.y},
		"replay_ids": replay_ids,
		"watch_button_count": watch_button_count,
		"status_text": str((hub.get_node("%StatusLabel") as Label).text),
		"local_replay_root": "user://ptcgdap/public_replays/live-community",
		"screenshot_sha256": _sha256(FileAccess.get_file_as_bytes(image_path)),
		"platform_service_required": false,
		"authoritative": false,
		"execution_authority": false,
		"private_replay_used": false,
		"grants": [],
	}
	var report_file := FileAccess.open("%s/visual_acceptance.json" % absolute_root, FileAccess.WRITE)
	if report_file == null:
		_finish_with_error("report_write_failed")
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("PTCGDAP_LOCAL_REPLAY_HISTORY_VISUAL_ACCEPTANCE %s" % JSON.stringify(report))
	hub.queue_free()
	await process_frame
	quit(0)


func _finish_with_error(code: String) -> void:
	push_error("PTCGDAP local replay history visual capture failed: %s" % code)
	quit(1)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
