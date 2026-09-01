extends SceneTree

const OUTPUT_ROOT := "res://artifacts/ptcgdap/d088_native_battle_scene_replay"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var packed := load("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn") as PackedScene
	if packed == null:
		_finish_with_error("strategy_hub_missing")
		return
	var hub: Control = packed.instantiate()
	root.add_child(hub)
	for _frame: int in 30:
		await process_frame
	var local_list := hub.get_node_or_null("%LocalReplayList") as VBoxContainer
	if local_list == null:
		_finish_with_error("local_replay_list_missing")
		return
	var native_count := 0
	var incomplete_public_count := 0
	for child: Node in local_list.find_children("*", "", true, false):
		if child is Button and child.name == "NativeReplayWatchButton":
			native_count += 1
		elif child is Button and child.name == "PublicReplayIncompleteButton":
			incomplete_public_count += 1
	if native_count <= 0:
		_finish_with_error("native_history_not_discoverable")
		return
	if incomplete_public_count <= 0:
		_finish_with_error("legacy_public_history_not_distinguished")
		return
	var viewport_texture := root.get_texture()
	var image := viewport_texture.get_image() if viewport_texture != null else null
	if image == null:
		_finish_with_error("rendering_driver_no_viewport_image")
		return
	var absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var image_path := absolute_root.path_join("native_replay_history.png")
	if image.save_png(image_path) != OK:
		_finish_with_error("screenshot_write_failed")
		return
	var report := {
		"document_type": "ptcgdap_native_replay_history_visual_acceptance_v1",
		"native_complete_replay_count": native_count,
		"legacy_public_incomplete_count": incomplete_public_count,
		"native_button_label": "用正式战斗场景回放",
		"legacy_public_button_disabled": true,
		"viewport": {"width": image.get_width(), "height": image.get_height()},
		"screenshot_sha256": _sha256(FileAccess.get_file_as_bytes(image_path)),
	}
	var file := FileAccess.open(absolute_root.path_join("history_visual_acceptance.json"), FileAccess.WRITE)
	if file == null:
		_finish_with_error("report_write_failed")
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PTCGDAP_NATIVE_REPLAY_HISTORY_ACCEPTANCE %s" % JSON.stringify(report))
	hub.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _finish_with_error(code: String) -> void:
	push_error("PTCGDAP native replay history visual capture failed: %s" % code)
	quit(1)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
