class_name TestCardImageCacheService
extends TestBase

const CardImageCacheServiceScript := preload("res://scripts/card_images/CardImageCacheService.gd")


class FakeCardDatabase:
	var cards := {}
	var get_card_calls := 0
	var get_all_cards_calls := 0
	var decks: Array[DeckData] = []

	func get_card(set_code: String, card_index: String) -> CardData:
		get_card_calls += 1
		return cards.get("%s_%s" % [set_code, card_index], null)

	func get_all_cards() -> Array:
		get_all_cards_calls += 1
		return []

	func get_all_decks() -> Array[DeckData]:
		return decks


func test_image_cache_manifest_sidecar_does_not_write_card_json() -> String:
	var root := "res://.godot_test_user/image_cache_sidecar"
	_remove_dir_recursive(root)
	var card := _make_card("CATIMG", "001")
	var service: Node = CardImageCacheServiceScript.new()
	service.call("set_manifest_path_for_tests", root.path_join("image_cache_manifest.json"))
	var user_card_path := "user://cards/CATIMG_001.json"
	if FileAccess.file_exists(user_card_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(user_card_path))
	var err: int = service.call("save_image_bytes_for_tests", card, _valid_png_bytes())
	var manifest: Dictionary = service.call("manifest_for_tests")
	var entries: Dictionary = manifest.get("entries", {})
	var image_exists := CardData.is_valid_card_image_file(card.image_local_path)
	var user_json_exists := FileAccess.file_exists(user_card_path)

	service.free()
	_remove_file(card.image_local_path)
	_remove_dir_recursive(root)

	return run_checks([
		assert_eq(err, OK, "Service should accept a valid card image"),
		assert_true(image_exists, "Service should save a readable local image"),
		assert_true(entries.has("CATIMG_001"), "Service should record image state in the sidecar manifest"),
		assert_false(user_json_exists, "Image cache should not materialize card JSON into user://cards"),
	])


func test_invalid_image_bytes_are_rejected_without_final_file() -> String:
	var root := "res://.godot_test_user/image_cache_bad_bytes"
	_remove_dir_recursive(root)
	var card := _make_card("CATIMG", "002")
	var service: Node = CardImageCacheServiceScript.new()
	service.call("set_manifest_path_for_tests", root.path_join("image_cache_manifest.json"))
	var err: int = service.call("save_image_bytes_for_tests", card, PackedByteArray([0x48, 0x54, 0x4D, 0x4C]))
	var image_exists := FileAccess.file_exists(card.image_local_path)
	var status := str(service.call("get_status", card.set_code, card.card_index))

	service.free()
	_remove_file(card.image_local_path)
	_remove_dir_recursive(root)

	return run_checks([
		assert_eq(err, ERR_INVALID_DATA, "Service should reject non-image bytes"),
		assert_false(image_exists, "Service should not leave a final file after invalid bytes"),
		assert_eq(status, "missing", "Rejected bytes should not mark the card ready"),
	])


func test_url_policy_requires_https_and_trusted_host() -> String:
	return run_checks([
		assert_true(CardImageCacheServiceScript.is_trusted_image_url("https://ptcg.skillserver.cn/card-images/CSV9C/123.png"), "Project CDN should be trusted"),
		assert_true(CardImageCacheServiceScript.is_trusted_image_url("https://tcg.mik.moe/static/img/CSV9C/123.png"), "tcg.mik.moe image source should remain compatible"),
		assert_true(CardImageCacheServiceScript.is_trusted_image_url("https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/JTG/JTG_153_R_EN.png"), "Limitless CDN should remain compatible"),
		assert_false(CardImageCacheServiceScript.is_trusted_image_url("http://tcg.mik.moe/static/img/CSV9C/123.png"), "HTTP image URLs should be rejected"),
		assert_false(CardImageCacheServiceScript.is_trusted_image_url("https://example.com/CSV9C/123.png"), "Unknown domains should be rejected"),
	])


func test_ensure_deck_images_dedupes_unique_cards_without_get_all_cards() -> String:
	var root := "res://.godot_test_user/image_cache_dedupe"
	_remove_dir_recursive(root)
	var service: Node = CardImageCacheServiceScript.new()
	service.call("set_manifest_path_for_tests", root.path_join("image_cache_manifest.json"))
	var fake := FakeCardDatabase.new()
	fake.cards["DEDUPE_001"] = _make_card("DEDUPE", "001")
	fake.cards["DEDUPE_002"] = _make_card("DEDUPE", "002")
	var deck := DeckData.new()
	deck.cards = [
		{"set_code": "DEDUPE", "card_index": "001", "count": 4},
		{"set_code": "DEDUPE", "card_index": "001", "count": 1},
		{"set_code": "DEDUPE", "card_index": "002", "count": 2},
	]
	var job_id := str(service.call("ensure_deck_images", deck, {"card_database": fake, "skip_remote": true}))
	var stats: Dictionary = service.call("get_job_stats_for_tests", job_id)

	service.free()
	_remove_dir_recursive(root)

	return run_checks([
		assert_eq(int(stats.get("total", -1)), 2, "Deck image jobs should dedupe by unique card uid"),
		assert_eq(fake.get_card_calls, 2, "Deck image jobs should resolve only unique card ids"),
		assert_eq(fake.get_all_cards_calls, 0, "Deck image jobs must not call get_all_cards and accidentally sync the full library"),
		assert_eq(int(stats.get("skipped", -1)), 2, "skip_remote test mode should complete without network requests"),
	])


func test_runtime_policy_matches_platform_budget_and_concurrency() -> String:
	return run_checks([
		assert_eq(CardImageCacheServiceScript.max_concurrency_for_runtime("Windows", {}, ""), 3, "Windows should allow three concurrent image requests"),
		assert_eq(CardImageCacheServiceScript.max_concurrency_for_runtime("Android", {"android": true}, ""), 2, "Android should use lower image request concurrency"),
		assert_false(CardImageCacheServiceScript.should_auto_download_for_runtime("Web", {}, "web"), "Web should not auto-download card images by default"),
		assert_true(CardImageCacheServiceScript.cache_budget_bytes_for_runtime("Android", {"android": true}, "") < CardImageCacheServiceScript.cache_budget_bytes_for_runtime("Windows", {}, ""), "Android cache budget should be lower than Windows"),
	])


func test_lru_budget_keeps_protected_deck_images() -> String:
	var root := "res://.godot_test_user/image_cache_lru"
	_remove_dir_recursive(root)
	var service: Node = CardImageCacheServiceScript.new()
	service.call("set_manifest_path_for_tests", root.path_join("image_cache_manifest.json"))
	var keep := _make_card("LRU", "001")
	var old := _make_card("LRU", "002")
	var newer := _make_card("LRU", "003")
	var bytes := _valid_png_bytes()
	service.call("save_image_bytes_for_tests", keep, bytes)
	service.call("save_image_bytes_for_tests", old, bytes)
	service.call("save_image_bytes_for_tests", newer, bytes)
	var budget := bytes.size() * 2
	service.call("enforce_cache_budget", {"budget_bytes": budget, "protected_uids": PackedStringArray([keep.get_uid()])})
	var keep_exists := CardData.is_valid_card_image_file(keep.image_local_path)
	var manifest: Dictionary = service.call("manifest_for_tests")
	var entries: Dictionary = manifest.get("entries", {})

	service.free()
	_remove_file(keep.image_local_path)
	_remove_file(old.image_local_path)
	_remove_file(newer.image_local_path)
	_remove_dir_recursive(root)

	return run_checks([
		assert_true(keep_exists, "LRU cleanup should keep protected deck images"),
		assert_true(entries.has(keep.get_uid()), "Protected image should stay in manifest"),
		assert_true(entries.size() <= 2, "LRU cleanup should reduce cache entries under the configured budget"),
	])


func _make_card(set_code: String, card_index: String) -> CardData:
	var card := CardData.new()
	card.name = "%s %s" % [set_code, card_index]
	card.name_en = card.name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 70
	card.set_code = set_code
	card.card_index = card_index
	card.image_url = "https://tcg.mik.moe/static/img/%s/%s.png" % [set_code, card_index]
	card.image_local_path = CardData.build_local_image_path(set_code, card_index)
	return card


func _valid_png_bytes() -> PackedByteArray:
	var source := "res://data/bundled_user/cards/images/CS5aC/107.png.bin"
	return FileAccess.get_file_as_bytes(source)


func _remove_file(path: String) -> void:
	if path == "":
		return
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _make_dir_recursive(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _remove_dir_recursive(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir := DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := absolute_path.path_join(entry)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)
