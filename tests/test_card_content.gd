extends TestBase

const MANIFEST_PATH := "res://scripts/card_content/ContentManifest.gd"
const STORE_PATH := "res://scripts/card_content/ContentStore.gd"
const FIXTURE := "res://tests/fixtures/card_content/"

class CachedUpdateClient extends "res://scripts/card_content/ContentUpdater.gd":
	var response_code := 304
	func _fetch(_path: String, _limit: int, _headers: PackedStringArray = PackedStringArray()) -> Dictionary:
		return {"code": response_code, "body": PackedByteArray(), "headers": PackedStringArray()}

class PanelUpdateClient extends Node:
	signal state_changed(data: Dictionary)
	func snapshot() -> Dictionary:
		return {"state": "available", "available_version": "new", "notes": "更新说明 ".repeat(700)}
	func set_auto_download(_enabled: bool) -> void: pass
	func check_for_updates(_manual: bool) -> void: pass
	func download_update() -> void: pass

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func test_signed_snapshot_and_tampering() -> String:
	if not ResourceLoader.exists(MANIFEST_PATH):
		return "Missing signed content manifest owner"
	var owner = load(MANIFEST_PATH)
	var envelope := _json(FIXTURE + "release.json")
	var trust := _json(FIXTURE + "trust.json")
	var valid: Dictionary = owner.verify(envelope, trust, "0.6.2", "windows")
	var tampered := envelope.duplicate(true)
	tampered.payload = Marshalls.raw_to_base64("{}".to_utf8_buffer())
	return run_checks([
		assert_true(valid.get("ok", false), "Real RSA signature must verify across Python/Godot"),
		assert_false(owner.verify(tampered, trust, "0.6.2", "windows").get("ok", false), "Tampering must fail"),
		assert_false(owner.verify(envelope, {}, "0.6.2", "windows").get("ok", false), "Downloaded keys cannot become trusted"),
		assert_false(owner.verify(envelope, trust, "0.1.0", "windows").get("ok", false), "Minimum client must be enforced"),
	])

func test_staging_is_complete_atomic_and_does_not_activate_live() -> String:
	if not ResourceLoader.exists(STORE_PATH):
		return "Missing transactional content store"
	var store = load(STORE_PATH).new("user://content_test_%d" % Time.get_ticks_usec(), _json(FIXTURE + "trust.json"), "0.6.2", "windows")
	var envelope := _json(FIXTURE + "release.json")
	var checked: Dictionary = load(MANIFEST_PATH).verify(envelope, _json(FIXTURE + "trust.json"), "0.6.2", "windows")
	if not checked.get("ok", false): return "Fixture signature failed"
	if store.stage(envelope).get("ok", false): return "Incomplete snapshot was staged"
	for pack: Dictionary in checked.manifest.packs:
		var bytes := FileAccess.get_file_as_bytes(FIXTURE + pack.sha256 + ".zip")
		if store.put_object(pack, bytes, true) != OK: return "Valid resource pack rejected"
		if store.put_object(pack, "broken".to_utf8_buffer(), true) == OK: return "Corrupt object accepted"
	var staged: Dictionary = store.stage(envelope)
	if not staged.get("ok", false): return "Complete release did not stage: " + str(staged)
	if not store.current().is_empty(): return "Stage changed current process rules"
	var trial: Dictionary = store.prepare_boot()
	if not trial.get("ok", false) or trial.get("release_id", "") == "": return "Boot did not select trial"
	# No health acknowledgement: next process must recover the bundled baseline.
	var restarted = load(STORE_PATH).new(store.root, _json(FIXTURE + "trust.json"), "0.6.2", "windows")
	var recovered: Dictionary = restarted.prepare_boot()
	return run_checks([
		assert_true(recovered.get("ok", false), "Recovery must remain bootable"),
		assert_eq(recovered.get("release_id", ""), "", "Unhealthy trial rolls back to bundled baseline"),
		assert_false(restarted.stage(envelope).get("ok", false), "Failed candidate must not retry automatically forever"),
	])

func test_successful_boot_persists_and_offline_reuses_objects() -> String:
	if not ResourceLoader.exists(STORE_PATH): return "Missing transactional content store"
	var trust := _json(FIXTURE + "trust.json")
	var store = load(STORE_PATH).new("user://content_good_%d" % Time.get_ticks_usec(), trust, "0.6.2", "windows")
	var envelope := _json(FIXTURE + "release.json")
	var checked: Dictionary = load(MANIFEST_PATH).verify(envelope, trust, "0.6.2", "windows")
	for pack: Dictionary in checked.manifest.packs:
		store.put_object(pack, FileAccess.get_file_as_bytes(FIXTURE + pack.sha256 + ".zip"), true)
	store.stage(envelope)
	var boot: Dictionary = store.prepare_boot()
	store.confirm_boot()
	var restart = load(STORE_PATH).new(store.root, trust, "0.6.2", "windows")
	return run_checks([
		assert_eq(restart.prepare_boot().get("release_id"), boot.get("release_id"), "Healthy snapshot survives offline restart"),
		assert_eq(restart.missing_packs(checked.manifest).size(), 0, "Incremental reuse must revalidate local bytes"),
	])

func test_official_snapshot_overrides_stale_import_and_is_searchable() -> String:
	var envelope := _json(FIXTURE + "release.json")
	var checked: Dictionary = load(MANIFEST_PATH).verify(envelope, _json(FIXTURE + "trust.json"), "0.6.2", "windows")
	if not checked.get("ok", false): return "Fixture verification failed"
	var stale := CardData.from_dict({"set_code": "CONTENT", "card_index": "001", "hp": 1, "name": "stale"})
	CardDatabase.cache_card(stale)
	for pack: Dictionary in checked.manifest.packs:
		if not ProjectSettings.load_resource_pack(FIXTURE + pack.sha256 + ".zip", true): return "Fixture pack failed to mount"
	Engine.set_meta("ptcg_card_content_snapshot", checked)
	var actual := CardDatabase.get_card("CONTENT", "001")
	var index := CardCatalogIndex.new()
	index.search_cards("CONTENT_001", {"implemented_only": true}, 10, 0)
	var result := run_checks([
		assert_eq(actual.hp, 100, "Signed snapshot must override stale user and memory caches"),
		assert_true(index.has_card("CONTENT", "001"), "New signed cards must enter search"),
		assert_true(index.get_entry("CONTENT", "001").get("implementation_status", "") != "", "Implemented-only filter must evaluate the current registry"),
	])
	Engine.remove_meta("ptcg_card_content_snapshot")
	return result

func test_image_revision_uses_digest_path_and_rejects_old_pixels() -> String:
	var Paths = load("res://scripts/card_content/ContentPaths.gd")
	var item := {"source_sha256": "a".repeat(64), "image": {"sha256": "b".repeat(64), "size": 4}}
	Engine.set_meta("ptcg_card_content_snapshot", {"manifest": {"cards": {"CONTENT_001": item}}})
	var paths := CardData.get_image_candidate_paths("CONTENT", "001", "user://old.png")
	var card := CardData.from_dict({"set_code": "CONTENT", "card_index": "001"})
	card.ensure_image_metadata()
	var service := CardImageCacheService.new()
	service._status_by_uid["CONTENT_001"] = CardImageCacheService.STATUS_READY
	var result := run_checks([
		assert_eq(paths.size(), 1, "Signed image must not silently fall back to stale UID pixels"),
		assert_true(paths[0].contains("b".repeat(64)), "Texture cache identity includes digest"),
		assert_true(CardImageCacheService.is_trusted_image_url(card.image_url), "Use pinned Control origin"),
		assert_true(service.save_image_bytes_for_tests(card, "old".to_utf8_buffer()) != OK, "Wrong image bytes rejected"),
		assert_true(service.get_status("CONTENT", "001") != CardImageCacheService.STATUS_READY, "Cached READY cannot override a missing or corrupt signed image"),
	])
	service.free()
	Engine.remove_meta("ptcg_card_content_snapshot")
	return result

func test_conditional_check_preserves_manual_download_offer() -> String:
	var enabled: Variant = ProjectSettings.get_setting("ptcgdap/card_content/enabled", false)
	ProjectSettings.set_setting("ptcgdap/card_content/enabled", true)
	var client := CachedUpdateClient.new()
	var trust := _json(FIXTURE + "trust.json")
	client._store = load(STORE_PATH).new("user://content_conditional_%d" % Time.get_ticks_usec(), trust, "0.6.2", "windows")
	client._candidate = load(MANIFEST_PATH).verify(_json(FIXTURE + "release.json"), trust, "0.6.2", "windows")
	client._auto_download = false
	await client.check_for_updates(true)
	var result := assert_eq(client.snapshot().state, "available", "304 means unchanged server version, not that an offered update was installed")
	client.free()
	ProjectSettings.set_setting("ptcgdap/card_content/enabled", enabled)
	return result

func test_game_state_and_recording_bind_content_identity() -> String:
	var previous: Variant = Engine.get_meta("ptcg_card_content_snapshot", {})
	Engine.set_meta("ptcg_card_content_snapshot", {"release_id": "c".repeat(64)})
	var gsm := GameStateMachine.new()
	var recorder := BattleRecorder.new()
	recorder.set_output_root("user://content_recording_%d" % Time.get_ticks_usec())
	recorder.start_match({"mode": "test"})
	Engine.set_meta("ptcg_card_content_snapshot", {"release_id": "d".repeat(64)})
	recorder.update_match_context({"mode": "updated context"})
	var result := run_checks([
		assert_eq(gsm.get("content_release_id"), "c".repeat(64), "A match must bind its initial content identity"),
		assert_eq(recorder.get("_meta").get("content_release_id"), "c".repeat(64), "Later metadata refresh cannot change recording rules identity"),
	])
	Engine.set_meta("ptcg_card_content_snapshot", previous)
	return result

func test_downloaded_update_remains_applicable_after_offline_check() -> String:
	var enabled: Variant = ProjectSettings.get_setting("ptcgdap/card_content/enabled", false)
	ProjectSettings.set_setting("ptcgdap/card_content/enabled", true)
	var client := CachedUpdateClient.new()
	client._store = load(STORE_PATH).new("user://content_offline_check_%d" % Time.get_ticks_usec(), _json(FIXTURE + "trust.json"), "0.6.2", "windows")
	client._store.write_json(client._store.root.path_join("pending.json"), {"release_id": "a".repeat(64)})
	client.response_code = 0
	await client.check_for_updates(true)
	var result := assert_true(client.snapshot().get("restart_available", false), "An offline check must not hide an already downloaded update")
	client.free()
	ProjectSettings.set_setting("ptcgdap/card_content/enabled", enabled)
	return result

func test_long_release_notes_do_not_expand_update_panel() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	tree.root.add_child(host)
	var client := PanelUpdateClient.new()
	host.add_child(client)
	var panel := preload("res://scripts/card_content/ContentUpdatePanel.gd").new()
	host.add_child(panel)
	panel.configure(client)
	var result := ""
	var prior_window_size := tree.root.size
	for viewport_size: Vector2 in [Vector2(600, 900), Vector2(900, 400)]:
		tree.root.size = Vector2i(viewport_size)
		host.size = viewport_size
		await tree.process_frame
		panel._layout()
		await tree.process_frame
		var card_rect: Rect2 = panel._panel.get_rect()
		if card_rect.position.x < 0 or card_rect.position.y < 0 or card_rect.end.x > viewport_size.x or card_rect.end.y > viewport_size.y:
			result = "Long notes expanded the update panel outside the viewport: %s / %s (overlay %s, scale %s)" % [card_rect, viewport_size, panel.size, panel._panel.scale]
		if panel._panel.size.y > 450: result = "Release notes must scroll inside the bounded panel"
	tree.root.size = prior_window_size
	host.queue_free()
	return result
