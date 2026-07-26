class_name TestBattleMusicManager
extends TestBase

const BattleMusicManagerScript := preload("res://scripts/autoload/BattleMusicManager.gd")
const BattleMusicImportAdapterScript := preload("res://scripts/audio/BattleMusicImportAdapter.gd")


func _make_manager() -> Node:
	var manager: Node = BattleMusicManagerScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(manager)
	manager.call("_ready")
	return manager


func _cleanup_manager(manager: Node) -> void:
	if manager != null and is_instance_valid(manager):
		manager.queue_free()


func _clear_directory(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(absolute_path)
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		DirAccess.remove_absolute("%s/%s" % [absolute_path.trim_suffix("/"), name])
	dir.list_dir_end()


func test_available_battle_tracks_include_none_and_custom_files() -> String:
	var temp_dir := "user://test_custom_bgm_tracks"
	_clear_directory(temp_dir)
	var file := FileAccess.open("%s/sample.ogg" % temp_dir, FileAccess.WRITE)
	if file != null:
		file.store_buffer(PackedByteArray([0]))
		file.close()

	var manager := _make_manager()
	manager.call("set_custom_music_dir_override_for_test", temp_dir)
	var tracks: Array = manager.call("get_available_battle_tracks")
	_cleanup_manager(manager)
	_clear_directory(temp_dir)

	return run_checks([
		assert_eq(str(tracks[0].get("id", "")), "none", "第一项应始终是无音乐"),
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "custom:sample.ogg"), "应扫描到自定义音频文件"),
	])


func test_android_picker_bytes_are_imported_into_managed_custom_music_directory() -> String:
	var temp_dir := "user://test_imported_custom_bgm"
	_clear_directory(temp_dir)
	var manager := _make_manager()
	manager.call("set_custom_music_dir_override_for_test", temp_dir)
	var ogg_bytes := PackedByteArray([
		0x4f, 0x67, 0x67, 0x53,
		0x00, 0x02, 0x00, 0x00,
	])
	var result_variant: Variant = manager.call(
		"import_custom_track_bytes",
		ogg_bytes,
		"android-picked-song"
	)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var imported_path := str(result.get("path", ""))
	var tracks: Array = manager.call("get_available_battle_tracks")
	var imported_bytes := PackedByteArray()
	if imported_path != "" and FileAccess.file_exists(imported_path):
		var imported_file := FileAccess.open(imported_path, FileAccess.READ)
		if imported_file != null:
			imported_bytes = imported_file.get_buffer(imported_file.get_length())
			imported_file.close()
	_cleanup_manager(manager)
	_clear_directory(temp_dir)

	return run_checks([
		assert_true(bool(result.get("ok", false)), "Android SAF bytes should import into the app-managed custom BGM directory"),
		assert_eq(str(result.get("track_id", "")), "custom:android-picked-song.ogg", "Header sniffing should restore a missing OGG extension"),
		assert_eq(imported_bytes, ogg_bytes, "Import must preserve the selected audio bytes exactly"),
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "custom:android-picked-song.ogg"), "An imported Android track should appear after a rescan"),
	])


func test_custom_music_import_rejects_unsupported_file_bytes() -> String:
	var temp_dir := "user://test_rejected_custom_bgm"
	_clear_directory(temp_dir)
	var manager := _make_manager()
	manager.call("set_custom_music_dir_override_for_test", temp_dir)
	var result_variant: Variant = manager.call(
		"import_custom_track_bytes",
		PackedByteArray([0x00, 0x01, 0x02, 0x03]),
		"not-audio.bin"
	)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var tracks: Array = manager.call("get_available_battle_tracks")
	_cleanup_manager(manager)
	_clear_directory(temp_dir)

	return run_checks([
		assert_false(bool(result.get("ok", true)), "Unsupported picker data must not be accepted as battle music"),
		assert_false(tracks.any(func(track: Dictionary) -> bool: return str(track.get("source", "")) == "custom"), "Rejected bytes must not leave a fake custom track behind"),
	])


func test_music_import_adapter_reads_picker_path_and_uses_android_audio_filter() -> String:
	var source_dir := "user://test_bgm_picker_source"
	var destination_dir := "user://test_bgm_picker_destination"
	_clear_directory(source_dir)
	_clear_directory(destination_dir)
	var source_path := "%s/picked-song.mp3" % source_dir
	var mp3_bytes := PackedByteArray([0x49, 0x44, 0x33, 0x04, 0x00, 0x00])
	var source_file := FileAccess.open(source_path, FileAccess.WRITE)
	if source_file != null:
		source_file.store_buffer(mp3_bytes)
		source_file.close()
	BattleMusicManager.set_custom_music_dir_override_for_test(destination_dir)
	var adapter: Variant = BattleMusicImportAdapterScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(adapter)
	var imported: Array[Dictionary] = []
	adapter.track_imported.connect(func(track_id: String, source_name: String) -> void:
		imported.append({"track_id": track_id, "source_name": source_name})
	)
	adapter.call("_import_selected_path", source_path)
	var filters := BattleMusicImportAdapterScript.native_audio_filters_for_tests()
	var destination_exists := FileAccess.file_exists("%s/picked-song.mp3" % destination_dir)
	adapter.queue_free()
	BattleMusicManager.clear_test_overrides()
	_clear_directory(source_dir)
	_clear_directory(destination_dir)

	return run_checks([
		assert_eq(imported.size(), 1, "The picker adapter should emit one imported-track result"),
		assert_eq(str(imported[0].get("track_id", "")) if not imported.is_empty() else "", "custom:picked-song.mp3", "The picker path should be copied into managed custom music"),
		assert_true(destination_exists, "The imported picker file should exist in the app-managed directory"),
		assert_true(not filters.is_empty() and str(filters[0]).contains("audio/mpeg"), "The native Android file picker should advertise audio MIME filters"),
	])


func test_android_content_uri_is_reduced_to_the_real_audio_file_name() -> String:
	var content_uri := "content://com.android.externalstorage.documents/document/primary%3ADownload%2FCodex-Custom-Music-Test.mp3"
	var adapter: Variant = BattleMusicImportAdapterScript.new()
	var display_name: Variant = adapter.call(
		"selected_path_display_name_for_tests",
		content_uri
	)
	adapter.free()

	return run_checks([
		assert_eq(str(display_name), "Codex-Custom-Music-Test.mp3", "Android SAF content URIs must not become long custom-track labels"),
	])


func test_opaque_android_media_uri_uses_a_readable_generated_track_name() -> String:
	var content_uri := "content://com.android.providers.media.documents/document/msf%3A443"
	var adapter: Variant = BattleMusicImportAdapterScript.new()
	var display_name := str(adapter.call("selected_path_display_name_for_tests", content_uri))
	adapter.free()

	return run_checks([
		assert_true(display_name.begins_with("导入音乐-"), "Opaque Android media IDs should use a readable generated track name"),
		assert_false(display_name.contains("msf") or display_name.contains("content://"), "Android media database IDs must not leak into the custom-track label"),
	])


func test_sanitize_track_id_falls_back_to_none_for_missing_tracks() -> String:
	var manager := _make_manager()
	var sanitized := str(manager.call("sanitize_track_id", "missing-track"))
	_cleanup_manager(manager)

	return run_checks([
		assert_eq(sanitized, "none", "不存在的曲目应回退到无音乐"),
	])


func test_builtin_catalog_exposes_registered_tracks() -> String:
	var manager := _make_manager()
	var tracks: Array = manager.call("get_available_battle_tracks")
	_cleanup_manager(manager)

	return run_checks([
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "pokemon_sv_battle_zeiyu"), "内置曲目注册表应暴露已登记的基础音乐"),
	])


func test_builtin_res_tracks_load_from_packed_resource_path() -> String:
	var manager := _make_manager()
	var stream: Variant = manager.call("_load_stream_from_path", "res://assets/audio/bgm/pokemon_sv_battle_zeiyu.mp3")
	_cleanup_manager(manager)

	return run_checks([
		assert_true(stream is AudioStream, "内置对战 BGM 应可直接从 res:// 打包资源加载"),
	])


func test_builtin_tracks_are_mirrored_to_user_music_directory() -> String:
	var temp_dir := "user://test_builtin_bgm_mirror"
	_clear_directory(temp_dir)
	var manager := _make_manager()
	manager.call("set_builtin_music_mirror_dir_override_for_test", temp_dir)
	manager.call("ensure_builtin_music_mirror")
	var mirror_absolute := ProjectSettings.globalize_path(temp_dir)
	var mirrored_zeiyu := FileAccess.file_exists("%s/pokemon_sv_battle_zeiyu.mp3" % mirror_absolute)
	var mirrored_gym := FileAccess.file_exists("%s/pokemon_sv_battle_gym_leader.mp3" % mirror_absolute)
	var mirrored_star := FileAccess.file_exists("%s/pokemon_sv_battle_star_barrage.mp3" % mirror_absolute)
	_cleanup_manager(manager)
	_clear_directory(temp_dir)

	return run_checks([
		assert_true(mirrored_zeiyu, "内置 BGM 应在首次启动时镜像到玩家目录"),
		assert_true(mirrored_gym, "道馆战曲应同步到玩家目录"),
		assert_true(mirrored_star, "天星队战曲应同步到玩家目录"),
	])


func test_volume_percent_maps_to_audio_player_db() -> String:
	var manager := _make_manager()
	manager.call("set_battle_music_volume_percent", 100)
	var audio_player := manager.get_node("BattleMusicPlayer") as AudioStreamPlayer
	var full_volume := float(audio_player.volume_db)
	manager.call("set_battle_music_volume_percent", 0)
	var muted_volume := float(audio_player.volume_db)
	_cleanup_manager(manager)

	return run_checks([
		assert_true(full_volume > -0.2 and full_volume < 0.2, "100% 音量应接近 0 dB"),
		assert_true(muted_volume <= -79.0, "0% 音量应接近静音"),
	])
