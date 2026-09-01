extends SceneTree

const SOURCE_PATH := "res://artifacts/ptcgdap/csp_wp1/marnie_public_replay_acceptance.json"
const OUTPUT_ROOT := "res://artifacts/ptcgdap/d087_battle_ui_replay_autoplay"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
	if not decoded is Dictionary or not decoded.get("artifact") is Dictionary:
		_finish_with_error("source_decode_failed")
		return
	var service_contract_script: GDScript = load(
		"res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd"
	) as GDScript
	var contracts_script: GDScript = load(
		"res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
	) as GDScript
	var viewer_scene: PackedScene = load(
		"res://scenes/ptcgdap_public_replay/PublicReplayViewer.tscn"
	) as PackedScene
	if service_contract_script == null or contracts_script == null or viewer_scene == null:
		_finish_with_error("runtime_resource_load_failed")
		return
	var artifact: Dictionary = service_contract_script.coerce_integral_numbers(decoded.artifact)
	var loaded: Dictionary = contracts_script.load_default()
	if not bool(loaded.get("accepted", false)):
		_finish_with_error(str(loaded.get("error_code", "contract_load_failed")))
		return
	var viewer: Control = viewer_scene.instantiate()
	root.add_child(viewer)
	await process_frame
	var opened: Dictionary = viewer.load_public_replay(
		loaded.get("owner"), artifact.manifest, artifact.frames, artifact.match_envelope
	)
	if not bool(opened.get("accepted", false)):
		_finish_with_error(str(opened.get("error_code", "viewer_open_failed")))
		return
	# Frame 42 is the densest stadium-present moment in the locked 156-frame fixture.
	viewer.set_playback_speed(4.0)
	viewer.play()
	viewer.advance_playback(0.65 / 4.0 * 41.0 + 0.001)
	viewer.pause()
	await process_frame
	await process_frame
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
	var image_path := "%s/public_replay_battle_scene_frame_042.png" % absolute_root
	var image_error := image.save_png(image_path)
	if image_error != OK:
		_finish_with_error("screenshot_write_failed")
		return
	var image_bytes := FileAccess.get_file_as_bytes(image_path)
	var report := {
		"document_type": "ptcgdap_public_replay_battle_scene_visual_acceptance_v2",
		"source_fixture": SOURCE_PATH,
		"source_frame_count": artifact.frames.size(),
		"captured_ordinal": int(viewer.current_view().get("ordinal", -1)),
		"viewports": [
			{"mode": "landscape", "width": image.get_width(), "height": image.get_height()},
		],
		"battle_scene_visual_source": viewer.get_meta("battle_scene_visual_source", ""),
		"battle_ui_mode": viewer.get_meta("battle_ui_mode", ""),
		"navigation_policy": "timeline_autoplay_manual_step",
		"player_snapshot": viewer.player_snapshot(),
		"visual_snapshot": viewer.visual_snapshot(),
		"presentation_audit": viewer.presentation_audit(),
		"screenshot_sha256": _sha256(image_bytes),
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
	print("PTCGDAP_PUBLIC_REPLAY_VISUAL_ACCEPTANCE %s" % JSON.stringify(report))
	viewer.queue_free()
	await process_frame
	quit(0)


func _finish_with_error(code: String) -> void:
	push_error("PTCGDAP public replay visual capture failed: %s" % code)
	quit(1)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
