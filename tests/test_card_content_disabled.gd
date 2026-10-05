extends TestBase

const Bootstrap := preload("res://scripts/card_content/ContentBootstrap.gd")
const Paths := preload("res://scripts/card_content/ContentPaths.gd")
const MainMenuScene := preload("res://scenes/main_menu/MainMenu.tscn")

class CountingClient extends "res://scripts/card_content/ContentUpdater.gd":
	var requests := 0
	func _fetch(_path: String, _limit: int, _headers: PackedStringArray = PackedStringArray()) -> Dictionary:
		requests += 1
		return {"code": 404, "body": PackedByteArray(), "headers": PackedStringArray()}


func test_release_defaults_to_bundled_content() -> String:
	return run_checks([
		assert_false(bool(ProjectSettings.get_setting("ptcgdap/card_content/enabled", true)), "The current release must explicitly disable downloadable card content"),
		assert_eq(Paths.release_id(), "bundled", "Default startup must use the tested bundled rules"),
	])


func test_home_has_no_card_content_entry_or_overlay() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = MainMenuScene.instantiate()
	tree.root.add_child(scene)
	scene.set("_navigation_started", true)
	await tree.process_frame
	var result := run_checks([
		assert_null(scene.get_node_or_null("CardContentUpdates"), "Do not create the top-right card content button in this release"),
		assert_null(scene.get_node_or_null("CardContentUpdateOverlay"), "No card content dialog should appear at startup"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_disabled_updater_blocks_manual_and_automatic_requests() -> String:
	var client := CountingClient.new()
	client._store = preload("res://scripts/card_content/ContentStore.gd").new("user://disabled_updater_test")
	client._candidate = {"manifest": {"packs": [{"sha256": "a".repeat(64), "size": 1, "files": {}}]}}
	await client.check_for_updates(false)
	await client.check_for_updates(true)
	await client.download_update()
	var result := assert_eq(client.requests, 0, "Hidden content updates must not send requests even through direct calls")
	client.free()
	return result


func test_disabled_boot_does_not_activate_or_rewrite_downloaded_updates() -> String:
	var previous: Variant = Engine.get_meta("ptcg_card_content_snapshot", {})
	var directory := "user://card_content"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var backup := {}
	var expected := {}
	for name: String in ["state.json", "pending.json", "trial.json"]:
		var path := directory.path_join(name)
		backup[name] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		expected[name] = JSON.stringify({"active": "a".repeat(64), "release_id": "b".repeat(64), "previous": "c".repeat(64), "candidate": "d".repeat(64)}).to_utf8_buffer()
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(expected[name])
		file.close()
	Engine.set_meta("ptcg_card_content_snapshot", {"release_id": "old-installed-snapshot"})
	var bootstrap := Bootstrap.new()
	bootstrap.confirm_boot()
	var result := assert_eq(Paths.release_id(), "bundled", "Disabled startup cannot retain a previously selected content snapshot")
	for name: String in expected:
		var path := directory.path_join(name)
		var actual := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		var check := assert_eq(actual, expected[name], "Disabled startup must preserve downloaded state: " + name)
		if result == "": result = check
		if backup[name] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backup[name])
			file.close()
	bootstrap.free()
	Engine.set_meta("ptcg_card_content_snapshot", previous)
	return result
