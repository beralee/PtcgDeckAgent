class_name TestCardImageFallback
extends TestBase

const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const ContentManifestScript = preload("res://scripts/card_content/ContentManifest.gd")


func test_signed_update_preserves_bundled_images_in_all_card_views() -> String:
	var bytes := FileAccess.get_file_as_bytes(CardData.build_bundled_image_path("CS5aC", "107"))
	var previous: Variant = Engine.get_meta("ptcg_card_content_snapshot", {})
	var target := _signed_image_snapshot("CS5aC_107", bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	var card := CardData.from_dict({"set_code": "CS5aC", "card_index": "107"})
	var view = BattleCardViewScript.new()
	var result := assert_not_null(view.call("_load_texture", card), "Content activation must keep the bundled battle card visible before any download")
	view.free()
	for path: String in ["res://scenes/deck_editor/DeckEditor.gd", "res://scenes/deck_manager/DeckManager.gd", "res://scripts/ui/decks/DeckViewDialog.gd"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
		var consumer = load(path).new()
		var check := assert_not_null(consumer.call("_load_card_texture", "CS5aC", "107"), "Content activation must preserve images in " + path)
		if result == "": result = check
		if consumer is Node: consumer.free()
		consumer = null
	var digest_check := assert_eq(FileAccess.get_sha256(target), ContentManifestScript.hash_bytes(bytes), "Reused image keeps the signed digest cache identity")
	if result == "": result = digest_check
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	Engine.set_meta("ptcg_card_content_snapshot", previous)
	BattleCardViewScript.clear_texture_cache_for_tests()
	return result


func test_signed_update_reuses_exact_old_download_without_network() -> String:
	var previous: Variant = Engine.get_meta("ptcg_card_content_snapshot", {})
	var image := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	var bytes := image.save_png_to_buffer()
	var legacy := "user://cards/images/SIGNED_REUSE/001.png"
	_write_bytes(legacy, bytes)
	var target := _signed_image_snapshot("SIGNED_REUSE_001", bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	var resolved := CardData.resolve_existing_image_path(CardData.get_image_candidate_paths("SIGNED_REUSE", "001"))
	var service := CardImageCacheService.new()
	var result := run_checks([
		assert_true(resolved != "", "Exact previously downloaded pixels must remain usable offline"),
		assert_eq(FileAccess.get_sha256(target), ContentManifestScript.hash_bytes(bytes), "Old cache must be verified and copied to the digest path"),
		assert_eq(service.get_status("SIGNED_REUSE", "001"), CardImageCacheService.STATUS_READY, "Download service and direct views must agree on readiness"),
	])
	service.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy))
	Engine.set_meta("ptcg_card_content_snapshot", previous)
	return result


func test_signed_image_rejects_valid_but_wrong_pixels_in_digest_cache() -> String:
	var previous: Variant = Engine.get_meta("ptcg_card_content_snapshot", {})
	var image := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.AQUA)
	var target := _signed_image_snapshot("SIGNED_WRONG_001", image.save_png_to_buffer())
	image.fill(Color.RED)
	var wrong := image.save_png_to_buffer()
	_write_bytes(target, wrong)
	var legacy := "user://cards/images/SIGNED_WRONG/001.png"
	_write_bytes(legacy, wrong)
	var resolved := CardData.resolve_existing_image_path(CardData.get_image_candidate_paths("SIGNED_WRONG", "001"))
	var result := assert_eq(resolved, "", "PNG signature alone cannot authorize stale pixels for a signed image revision")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy))
	Engine.set_meta("ptcg_card_content_snapshot", previous)
	return result


func test_signed_image_repairs_corrupt_digest_from_exact_bundle() -> String:
	var previous: Variant = Engine.get_meta("ptcg_card_content_snapshot", {})
	var bytes := FileAccess.get_file_as_bytes(CardData.build_bundled_image_path("CS5aC", "107"))
	var target := _signed_image_snapshot("CS5aC_107", bytes)
	_write_bytes(target, "broken".to_utf8_buffer())
	var resolved := CardData.resolve_existing_image_path(CardData.get_image_candidate_paths("CS5aC", "107"))
	var result := run_checks([
		assert_true(resolved != "", "Corrupt digest cache should recover from exact bundled bytes"),
		assert_eq(FileAccess.get_sha256(target), ContentManifestScript.hash_bytes(bytes), "Repair must preserve exact signed bytes"),
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	Engine.set_meta("ptcg_card_content_snapshot", previous)
	return result


func _signed_image_snapshot(uid: String, bytes: PackedByteArray) -> String:
	var sha := ContentManifestScript.hash_bytes(bytes)
	Engine.set_meta("ptcg_card_content_snapshot", {"manifest": {"cards": {uid: {"image": {"sha256": sha, "size": bytes.size()}}}}})
	return "user://card_content/objects/%s.img" % sha


func test_card_data_resolves_bundled_image_path_when_user_cache_is_missing() -> String:
	var paths := CardData.get_image_candidate_paths("CS5aC", "107", "user://cards/images/__missing__/107.png")
	var resolved := CardData.resolve_existing_image_path(paths)

	return run_checks([
		assert_true(resolved.begins_with("res://data/bundled_user/cards/images/CS5aC/107.png.bin"), "Bundled card image path should resolve when user cache is missing"),
	])


func test_miraidon_165_new_cards_resolve_bundled_images_when_user_cache_is_missing() -> String:
	var magneton_paths := CardData.get_image_candidate_paths("CBB5C", "0301", "user://cards/images/__missing__/0301.png")
	var magnemite_paths := CardData.get_image_candidate_paths("CSV1C", "042", "user://cards/images/__missing__/042.png")
	var magneton_resolved := CardData.resolve_existing_image_path(magneton_paths)
	var magnemite_resolved := CardData.resolve_existing_image_path(magnemite_paths)

	return run_checks([
		assert_true(magneton_resolved.begins_with("res://data/bundled_user/cards/images/CBB5C/0301.png.bin"), "Bundled Magneton image path should resolve when user cache is missing"),
		assert_true(magnemite_resolved.begins_with("res://data/bundled_user/cards/images/CSV1C/042.png.bin"), "Bundled Magnemite image path should resolve when user cache is missing"),
	])


func test_invalid_user_image_is_skipped_for_bundled_fallback() -> String:
	var corrupt_path := "res://.godot_test_user/corrupt_card_image.png"
	_write_bytes(corrupt_path, PackedByteArray([0x4E, 0x4F, 0x54, 0x50, 0x4E, 0x47]))
	var paths := CardData.get_image_candidate_paths("CS5aC", "079", corrupt_path)
	var resolved := CardData.resolve_existing_image_path(paths)
	var local_valid := CardData.is_valid_png_file(corrupt_path)
	var bundled_valid := CardData.is_valid_png_file("res://data/bundled_user/cards/images/CS5aC/079.png.bin")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))

	return run_checks([
		assert_false(local_valid, "Corrupt user image should not be treated as a usable card image"),
		assert_true(bundled_valid, "Bundled Radiant Hisuian Sneasler image should be a valid PNG"),
		assert_true(resolved.begins_with("res://data/bundled_user/cards/images/CS5aC/079.png.bin"), "Resolver should skip corrupt user image and use bundled fallback"),
	])


func test_battle_card_view_loads_texture_from_bundled_fallback() -> String:
	var card: CardData = CardDatabase.get_card("CS5aC", "107")
	if card == null:
		return "Expected CardDatabase to provide CS5aC_107 for bundled image fallback test"
	var cloned: CardData = card.duplicate(true) as CardData
	cloned.image_local_path = "user://cards/images/__missing__/107.png"
	var view = BattleCardViewScript.new()
	var texture: Texture2D = view.call("_load_texture", cloned) as Texture2D

	return run_checks([
		assert_not_null(texture, "BattleCardView should load the bundled fallback texture when user cache is missing"),
	])


func test_battle_card_view_texture_cache_is_bounded() -> String:
	BattleCardViewScript.clear_texture_cache_for_tests()
	var max_entries: int = BattleCardViewScript.texture_cache_max_entries_for_tests()
	for i: int in range(max_entries + 12):
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color(float(i % 7) / 7.0, 0.2, 0.4, 1.0))
		var texture := ImageTexture.create_from_image(image)
		BattleCardViewScript.store_texture_in_cache_for_tests("res://fake/card_%03d.png" % i, texture)

	var newest_path := "res://fake/card_%03d.png" % (max_entries + 11)
	var result := run_checks([
		assert_eq(BattleCardViewScript.texture_cache_size_for_tests(), max_entries, "BattleCardView card image cache should stay bounded across matches"),
		assert_false(BattleCardViewScript.texture_cache_has_path_for_tests("res://fake/card_000.png"), "Oldest card texture should be evicted when cache exceeds its limit"),
		assert_true(BattleCardViewScript.texture_cache_has_path_for_tests(newest_path), "Newest card texture should remain cached"),
	])
	BattleCardViewScript.clear_texture_cache_for_tests()
	return result


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("TestCardImageFallback: failed to write %s" % path)
		return
	file.store_buffer(bytes)
	file.close()
