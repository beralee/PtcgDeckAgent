class_name TestCardDatabaseSeed
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")


func test_copy_missing_files_recursive_copies_nested_files_without_overwriting() -> String:
	var db := CardDatabaseScript.new()
	var source_root := "res://.godot_test_user/utest_bundled_source"
	var target_root := "res://.godot_test_user/utest_bundled_target"
	_remove_dir_recursive(source_root)
	_remove_dir_recursive(target_root)

	var source_cards_dir := source_root.path_join("cards")
	var source_images_dir := source_cards_dir.path_join("images/UTEST")
	var target_cards_dir := target_root.path_join("cards")
	var copied_json_path := target_cards_dir.path_join("sample.json")
	var copied_image_path := target_cards_dir.path_join("images/UTEST/sample.png")

	_make_dir_recursive(source_images_dir)
	_write_text(source_cards_dir.path_join("sample.json"), "{\"id\":1,\"name\":\"Preset Deck Card\"}")
	_write_text(source_images_dir.path_join("sample.png.bin"), "image-bytes")
	_write_text(source_images_dir.path_join("sample.png.import"), "import-metadata")

	db._copy_missing_files_recursive(source_cards_dir, target_cards_dir)
	var first_copy_json := FileAccess.get_file_as_string(copied_json_path)
	var first_copy_image := FileAccess.get_file_as_string(copied_image_path)
	var copied_json_exists := FileAccess.file_exists(copied_json_path)
	var copied_image_exists := FileAccess.file_exists(copied_image_path)
	var copied_import_exists := FileAccess.file_exists(target_cards_dir.path_join("images/UTEST/sample.png.import"))

	_write_text(copied_json_path, "user-customized")
	db._copy_missing_files_recursive(source_cards_dir, target_cards_dir)
	var second_copy_json := FileAccess.get_file_as_string(copied_json_path)

	_remove_dir_recursive(source_root)
	_remove_dir_recursive(target_root)

	return run_checks([
		assert_true(copied_json_exists, "Bundled JSON should be copied into user:// target"),
		assert_true(copied_image_exists, "Nested bundled file should be copied recursively"),
		assert_false(copied_import_exists, "Godot import metadata should not be copied into user:// target"),
		assert_eq(first_copy_json, "{\"id\":1,\"name\":\"Preset Deck Card\"}", "Copied JSON content should match bundled source"),
		assert_eq(first_copy_image, "image-bytes", "Nested bundled file content should match bundled source"),
		assert_eq(second_copy_json, "user-customized", "Existing user file should not be overwritten by bundled seed"),
	])


func test_bundled_seed_replaces_corrupt_local_card_image() -> String:
	var db := CardDatabaseScript.new()
	var source_root := "res://.godot_test_user/utest_bundled_png_source"
	var target_root := "res://.godot_test_user/utest_bundled_png_target"
	_remove_dir_recursive(source_root)
	_remove_dir_recursive(target_root)

	var source_image := source_root.path_join("cards/images/UTEST/001.png.bin")
	var target_image := target_root.path_join("cards/images/UTEST/001.png")
	_write_bytes(source_image, _minimal_png_bytes())
	_write_bytes(target_image, PackedByteArray([0x42, 0x41, 0x44]))

	db._copy_missing_files_recursive(source_root.path_join("cards"), target_root.path_join("cards"))
	var target_valid := CardData.is_valid_png_file(target_image)
	var target_bytes := _read_bytes(target_image)

	_remove_dir_recursive(source_root)
	_remove_dir_recursive(target_root)

	return run_checks([
		assert_true(target_valid, "Bundled seed should repair corrupt local card images"),
		assert_eq(target_bytes.size(), _minimal_png_bytes().size(), "Repaired local image should be copied from bundled source"),
	])


func test_save_card_image_rejects_non_png_response() -> String:
	var db := CardDatabaseScript.new()
	var card := CardData.new()
	card.set_code = "UTESTPNG"
	card.card_index = "001"
	card.image_local_path = CardData.build_local_image_path(card.set_code, card.card_index)
	var target_path := card.image_local_path
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))

	var err := db.save_card_image(card, PackedByteArray([0x48, 0x54, 0x4D, 0x4C]))
	var exists_after_bad_save := FileAccess.file_exists(target_path)

	return run_checks([
		assert_eq(err, ERR_INVALID_DATA, "Card image sync should reject non-PNG HTTP responses"),
		assert_false(exists_after_bad_save, "Rejected image response should not leave a corrupt local file"),
	])


func test_save_card_image_accepts_existing_bundled_webp_bytes() -> String:
	var db := CardDatabaseScript.new()
	var card := CardData.new()
	card.set_code = "UTESTWEBP"
	card.card_index = "001"
	card.image_local_path = CardData.build_local_image_path(card.set_code, card.card_index)
	var target_path := card.image_local_path
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))

	var source_bytes := _read_bytes("res://data/bundled_user/cards/images/CS5aC/107.png.bin")
	var err := db.save_card_image(card, source_bytes)
	var exists_after_save := FileAccess.file_exists(target_path)
	var saved_valid := CardData.is_valid_card_image_file(target_path)
	if exists_after_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))

	return run_checks([
		assert_true(CardData.has_webp_signature(source_bytes), "Regression fixture should be a WebP-backed bundled card image"),
		assert_eq(err, OK, "Card image sync should accept supported WebP card images"),
		assert_true(exists_after_save, "Accepted WebP image response should be written to local cache"),
		assert_true(saved_valid, "Saved WebP card image should be treated as a usable local image"),
	])


func test_supported_ai_deck_ignores_user_override_and_reads_bundled_source() -> String:
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db._deck_cache = {}
	db._ai_deck_cache = {}
	var bundled_ai: DeckData = db._load_bundled_ai_deck(575720)
	if bundled_ai == null:
		return "Expected bundled AI deck 575720 to exist"
	var fake_ai := DeckData.new()
	fake_ai.id = 575720
	fake_ai.deck_name = "Fake Override Miraidon"
	fake_ai.total_cards = 60
	db.save_ai_deck(fake_ai)
	var resolved: DeckData = db.get_ai_deck(575720)
	return run_checks([
		assert_not_null(resolved, "Supported AI deck should still resolve"),
		assert_eq(str(resolved.deck_name if resolved != null else ""), str(bundled_ai.deck_name), "Supported AI decks should resolve from bundled source, not user overrides"),
		assert_str_contains(str(resolved.strategy if resolved != null else ""), "【玩家打法要求】", "Supported AI decks should expose the bundled player-requirement strategy text"),
	])


func test_get_all_ai_decks_returns_supported_bundled_shortlist() -> String:
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db._deck_cache = {}
	db._ai_deck_cache = {}
	var ai_decks: Array[DeckData] = db.get_all_ai_decks()
	var ids: Array[int] = []
	var leading_ids: Array[int] = []
	for deck: DeckData in ai_decks:
		ids.append(deck.id)
		if leading_ids.size() < 3:
			leading_ids.append(deck.id)
	ids.sort()
	var expected_ids := [
		569061, 575657, 575716, 575718, 575720, 575723, 578647, 579502, 609431, 610080,
		1700002, 1700003, 1700004, 1700005, 1700007, 1700008, 1700011,
		1750002,
	]
	var expected_leading_ids := [
		1750002, 609431, 610080,
	]
	leading_ids.sort()
	expected_leading_ids.sort()
	return run_checks([
		assert_eq(ai_decks.size(), expected_ids.size(), "AI deck list should expose exactly the backed-up AI deck set"),
		assert_eq(ids, expected_ids, "AI deck list should match the backed-up AI deck set"),
		assert_eq(leading_ids, expected_leading_ids, "AI deck list should sort the supported 17.5 AI decks first"),
	])


func test_bundled_ai_deck_default_strategies_are_player_requirement_seed_text() -> String:
	var db := CardDatabaseScript.new()
	var expected_keywords := {
		569061: "星星诞生",
		575657: "捕获香氛",
		575716: "大比鸟ex",
		575720: "串联装置",
		575723: "咒怨炸弹",
		578647: "精神拥抱",
		579502: "幻影潜袭",
	}
	var checks: Array[String] = []
	for deck_id_variant: Variant in expected_keywords.keys():
		var deck_id := int(deck_id_variant)
		var deck: DeckData = db._load_bundled_ai_deck(deck_id)
		checks.append(assert_not_null(deck, "Bundled AI deck %d should load from install seed data" % deck_id))
		if deck == null:
			continue
		var strategy_text := str(deck.strategy)
		checks.append(assert_str_contains(strategy_text, "【玩家打法要求】", "Bundled AI deck %d should frame default strategy as player play requirements" % deck_id))
		checks.append(assert_str_contains(strategy_text, str(expected_keywords[deck_id_variant]), "Bundled AI deck %d should contain its updated deck-specific plan" % deck_id))
	return run_checks(checks)


func test_miraidon_165_is_bundled_as_default_install_deck() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var deck_path := "res://data/bundled_user/decks/599947.json"
	var checks: Array[String] = [
		assert_true(deck_path in manifest, "Miraidon 16.5 deck should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/CBB5C_0301.json" in manifest, "Miraidon 16.5 Magneton should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/CSV1C_042.json" in manifest, "Miraidon 16.5 Magnemite should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/images/CBB5C/0301.png.bin" in manifest, "Miraidon 16.5 Magneton image should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/images/CSV1C/042.png.bin" in manifest, "Miraidon 16.5 Magnemite image should be listed in the bundled seed manifest"),
	]
	var raw := FileAccess.get_file_as_string(deck_path)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		checks.append("Miraidon 16.5 bundled deck JSON should parse")
		return run_checks(checks)
	var deck := parsed as Dictionary
	var seen_magneton := false
	var seen_magnemite := false
	var missing_card_data: Array[String] = []
	var missing_images: Array[String] = []
	for entry: Dictionary in deck.get("cards", []):
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		var card_id := "%s_%s" % [set_code, card_index]
		if card_id == "CBB5C_0301":
			seen_magneton = true
		elif card_id == "CSV1C_042":
			seen_magnemite = true
		if not FileAccess.file_exists("res://data/bundled_user/cards/%s.json" % card_id):
			missing_card_data.append(card_id)
		if not FileAccess.file_exists("res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]):
			missing_images.append(card_id)
	checks.append(assert_eq(int(deck.get("id", -1)), 599947, "Bundled Miraidon 16.5 deck id should match the imported deck"))
	checks.append(assert_eq(str(deck.get("deck_name", "")), "密勒顿16.5", "Bundled Miraidon 16.5 deck name should match the imported deck"))
	checks.append(assert_true(seen_magneton, "Bundled Miraidon 16.5 deck should include CBB5C_0301 Magneton"))
	checks.append(assert_true(seen_magnemite, "Bundled Miraidon 16.5 deck should include CSV1C_042 Magnemite"))
	checks.append(assert_eq(missing_card_data.size(), 0, "All Miraidon 16.5 deck cards should have bundled card JSON: %s" % str(missing_card_data)))
	checks.append(assert_eq(missing_images.size(), 0, "All Miraidon 16.5 deck cards should have bundled images: %s" % str(missing_images)))
	return run_checks(checks)


func test_festival_lead_box_is_bundled_as_default_install_deck() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var deck_path := "res://data/bundled_user/decks/602769.json"
	var checks: Array[String] = [
		assert_true(deck_path in manifest, "Festival Lead Box deck should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/CSV8C_020.json" in manifest, "Festival Lead Box Grookey should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/CSV8C_024.json" in manifest, "Festival Lead Box Dipplin should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/CSV8C_201.json" in manifest, "Festival Lead Box Festival Grounds should be listed in the bundled seed manifest"),
		assert_true("res://data/bundled_user/cards/images/CSV8C/020.png.bin" in manifest, "Festival Lead Box Grookey image should be listed in the bundled seed manifest"),
	]
	var raw := FileAccess.get_file_as_string(deck_path)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		checks.append("Festival Lead Box bundled deck JSON should parse")
		return run_checks(checks)
	var deck := parsed as Dictionary
	var seen_grookey := false
	var seen_dipplin := false
	var seen_festival_grounds := false
	var missing_card_data: Array[String] = []
	var missing_images: Array[String] = []
	for entry: Dictionary in deck.get("cards", []):
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		var card_id := "%s_%s" % [set_code, card_index]
		if card_id == "CSV8C_020":
			seen_grookey = true
		elif card_id == "CSV8C_024":
			seen_dipplin = true
		elif card_id == "CSV8C_201":
			seen_festival_grounds = true
		if not FileAccess.file_exists("res://data/bundled_user/cards/%s.json" % card_id):
			missing_card_data.append(card_id)
		if not FileAccess.file_exists("res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]):
			missing_images.append(card_id)
	checks.append(assert_eq(int(deck.get("id", -1)), 602769, "Bundled Festival Lead Box deck id should match the imported deck"))
	checks.append(assert_eq(str(deck.get("deck_name", "")), "祭典乐舞Box", "Bundled Festival Lead Box deck name should match the imported deck"))
	checks.append(assert_true(seen_grookey, "Bundled Festival Lead Box should include CSV8C_020 Grookey"))
	checks.append(assert_true(seen_dipplin, "Bundled Festival Lead Box should include CSV8C_024 Dipplin"))
	checks.append(assert_true(seen_festival_grounds, "Bundled Festival Lead Box should include CSV8C_201 Festival Grounds"))
	checks.append(assert_eq(missing_card_data.size(), 0, "All Festival Lead Box deck cards should have bundled card JSON: %s" % str(missing_card_data)))
	checks.append(assert_eq(missing_images.size(), 0, "All Festival Lead Box deck cards should have bundled images: %s" % str(missing_images)))
	return run_checks(checks)


func test_version_170_user_decks_are_bundled_with_generated_ids() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var generated_to_source := {
		1700001: 544317,
		1700002: 561444,
		1700003: 569061,
		1700004: 575479,
		1700005: 575716,
		1700006: 575718,
		1700007: 575720,
		1700008: 575723,
		1700009: 579502,
		1700010: 580091,
		1700011: 581056,
		1700012: 591123,
	}
	var checks: Array[String] = []
	for deck_id_variant: Variant in generated_to_source.keys():
		var deck_id := int(deck_id_variant)
		var source_id := int(generated_to_source[deck_id_variant])
		var deck_path := "res://data/bundled_user/decks/%d.json" % deck_id
		checks.append(assert_true(deck_path in manifest, "17.0 deck %d should be listed in the bundled seed manifest" % deck_id))
		checks.append(assert_true(FileAccess.file_exists(deck_path), "17.0 deck %d bundled JSON should exist" % deck_id))
		checks.append(assert_false(deck_id == source_id, "17.0 deck %d should use a generated id instead of its source id" % deck_id))

		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(deck_path))
		if not parsed is Dictionary:
			checks.append("17.0 deck %d bundled JSON should parse" % deck_id)
			continue
		var deck := parsed as Dictionary
		var total_count := 0
		for entry_variant: Variant in deck.get("cards", []):
			if entry_variant is Dictionary:
				total_count += int((entry_variant as Dictionary).get("count", 0))
		checks.append(assert_eq(int(deck.get("id", -1)), deck_id, "17.0 deck file %d should keep its generated id in JSON" % deck_id))
		checks.append(assert_true(str(deck.get("deck_name", "")).begins_with("17.0 "), "17.0 deck %d should keep the versioned display name" % deck_id))
		checks.append(assert_eq(str(deck.get("source_url", "")), "https://tcg.mik.moe/decks/list/%d" % source_id, "17.0 deck %d should keep source traceability" % deck_id))
		checks.append(assert_eq(int(deck.get("total_cards", -1)), 60, "17.0 deck %d total_cards should be 60" % deck_id))
		checks.append(assert_eq(total_count, 60, "17.0 deck %d card counts should add up to 60" % deck_id))
	return run_checks(checks)


func test_version_175_configured_decks_are_bundled() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var expected := {
		1750001: "17.5 铝钢桥龙",
		1750002: "17.5纯多龙",
		1750003: "17.5密勒顿",
		1750005: "17.5呆呆王",
		606452: "17.5苍炎刃鬼",
		609431: "17.5洛奇亚",
		610080: "17.5沙奈朵",
		620753: "17.5赛富豪",
		620761: "17.5猛雷鼓",
		620880: "17.5毒龟v2",
		620909: "17.5恶喷v2",
	}
	var one_ace_deck_ids := [620753, 620761, 620880, 620909]
	var removed_two_ace_deck_ids := [1750004, 606972, 611607]
	var checks: Array[String] = []
	for deck_id_variant: Variant in expected.keys():
		var deck_id := int(deck_id_variant)
		var deck_path := "res://data/bundled_user/decks/%d.json" % deck_id
		var deck: DeckData = db._load_deck_from_file(deck_path)
		checks.append(assert_true(deck_path in manifest, "17.5 deck %d should be listed in the bundled seed manifest" % deck_id))
		checks.append(assert_true(FileAccess.file_exists(deck_path), "17.5 deck %d bundled JSON should exist" % deck_id))
		checks.append(assert_not_null(deck, "17.5 deck %d should load from bundled JSON" % deck_id))
		if deck == null:
			continue
		checks.append(assert_eq(int(deck.id), deck_id, "17.5 deck %d should keep its unique bundled id" % deck_id))
		checks.append(assert_eq(str(deck.deck_name), str(expected[deck_id_variant]), "17.5 deck %d should keep the configured deck name" % deck_id))
		checks.append(assert_eq(int(deck.total_cards), 60, "17.5 deck %d should keep 60 cards" % deck_id))
		var instances := db.build_deck_instances(deck, 0)
		checks.append(assert_eq(instances.size(), 60, "17.5 deck %d should build all 60 card instances from bundled cards" % deck_id))
		if deck_id in one_ace_deck_ids:
			checks.append(assert_eq(_ace_spec_copy_count(db, deck), 1, "17.5 deck %d should contain exactly one ACE SPEC card" % deck_id))
	for removed_id: int in removed_two_ace_deck_ids:
		var removed_path := "res://data/bundled_user/decks/%d.json" % removed_id
		checks.append(assert_false(removed_path in manifest, "Removed two-ACE 17.5 deck %d should not be listed in the bundled seed manifest" % removed_id))
		checks.append(assert_false(FileAccess.file_exists(removed_path), "Removed two-ACE 17.5 deck %d bundled JSON should not exist" % removed_id))
	var imported_cards := {
		"151C_005": "火恐龙",
		"151C_017": "比比鸟",
	}
	for uid_variant: Variant in imported_cards.keys():
		var uid := str(uid_variant)
		var parts := uid.split("_")
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [parts[0], parts[1]]
		var card: CardData = db.get_card(str(parts[0]), str(parts[1]))
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % uid))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled card image should be valid" % uid))
		checks.append(assert_not_null(card, "%s should load from bundled cards" % uid))
		if card != null:
			checks.append(assert_eq(str(card.name), str(imported_cards[uid_variant]), "%s should keep the expected card name" % uid))
	var regenerated_from_legacy := {
		1750001: 1700002,
		1750002: 575723,
		1750003: 599947,
	}
	for generated_id_variant: Variant in regenerated_from_legacy.keys():
		var generated_id := int(generated_id_variant)
		var legacy_id := int(regenerated_from_legacy[generated_id_variant])
		var generated_deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/%d.json" % generated_id)
		var legacy_deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/%d.json" % legacy_id)
		checks.append(assert_not_null(generated_deck, "Generated 17.5 deck %d should exist for legacy deck %d" % [generated_id, legacy_id]))
		checks.append(assert_not_null(legacy_deck, "Legacy source deck %d should still exist beside generated 17.5 deck %d" % [legacy_id, generated_id]))
		if generated_deck != null:
			checks.append(assert_true(str(generated_deck.deck_name).begins_with("17.5"), "Generated deck %d should be the 17.5 copy" % generated_id))
		if legacy_deck != null:
			checks.append(assert_false(str(legacy_deck.deck_name).begins_with("17.5"), "Legacy deck %d should not be overwritten as the 17.5 copy" % legacy_id))
	return run_checks(checks)


func test_get_all_decks_sorts_player_modified_decks_first() -> String:
	var db := CardDatabaseScript.new()
	var expected_v175_ids := [
		1750001, 1750002, 1750003, 1750005,
		606452, 609431, 610080, 620753, 620761, 620880, 620909,
	]
	var cache := {}
	for deck_id: int in expected_v175_ids + [1700001]:
		var deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/%d.json" % deck_id)
		if deck != null:
			cache[deck.id] = deck
	var player_created_deck := DeckData.new()
	player_created_deck.id = 99000001
	player_created_deck.deck_name = "player created deck"
	player_created_deck.import_date = "2099-01-01T00:00:00"
	player_created_deck.updated_at = 1000000000001
	player_created_deck.total_cards = 60
	cache[player_created_deck.id] = player_created_deck
	var modified_specs := [
		{"id": 1700001, "name": "player modified baseline deck", "updated_at": 1000000000000},
		{"id": 1700002, "name": "17.5 stale legacy Archaludon", "updated_at": 999999999999},
		{"id": 575723, "name": "17.5 stale legacy Dragapult", "updated_at": 999999999998},
		{"id": 599947, "name": "17.5 stale legacy Miraidon", "updated_at": 999999999997},
	]
	for spec: Dictionary in modified_specs:
		var modified_id := int(spec["id"])
		var modified_deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/%d.json" % modified_id)
		if modified_deck != null:
			modified_deck.deck_name = str(spec["name"])
			modified_deck.updated_at = int(spec["updated_at"])
			cache[modified_deck.id] = modified_deck
	var sorted: Array[DeckData] = db._sorted_deck_values(cache)
	var leading_ids: Array[int] = []
	var expected_modified_ids := [
		99000001, 1700001, 1700002, 575723, 599947,
	]
	for i: int in mini(expected_modified_ids.size(), sorted.size()):
		var deck := sorted[i] as DeckData
		leading_ids.append(int(deck.id))
	var checks: Array[String] = [
		assert_eq(leading_ids, expected_modified_ids, "CardDatabase.get_all_decks should put player-created or player-modified decks before bundled defaults"),
	]
	for i: int in range(expected_modified_ids.size(), sorted.size()):
		var trailing_deck := sorted[i] as DeckData
		checks.append(assert_false(int(trailing_deck.id) in expected_modified_ids, "Modified deck %d should not appear after bundled defaults" % int(trailing_deck.id)))
		break
	return run_checks(checks)


func test_175_slowking_deck_matches_screenshot_counts() -> String:
	var db := CardDatabaseScript.new()
	var deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/1750005.json")
	if deck == null:
		return "17.5 Slowking bundled deck should load from bundled JSON"
	var expected_counts := {
		"CSV9.5C_031": 4,
		"CSV9C_072": 3,
		"CSV5C_053": 2,
		"CSV5C_054": 2,
		"CSV9C_147": 2,
		"CSV9.5C_004": 2,
		"CSV2C_105": 1,
		"CSV9C_078": 1,
		"CSV8C_121": 1,
		"CSV8C_160": 1,
		"CS5.5C_056": 1,
		"CSV8C_135": 1,
		"CSV8C_172": 1,
		"CSV7C_191": 4,
		"CSV1C_121": 4,
		"CSV3C_123": 1,
		"CSV8C_183": 4,
		"CSV1C_112": 4,
		"CSV7C_177": 4,
		"CSV9.5C_163": 1,
		"CSV8C_205": 4,
		"CSVE1C_PSY": 6,
		"CSV4C_129": 4,
		"CSV2C_128": 2,
	}
	var actual_counts := {}
	var total_count := 0
	for entry: Dictionary in deck.cards:
		var card_id := "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
		var count := int(entry.get("count", 0))
		actual_counts[card_id] = int(actual_counts.get(card_id, 0)) + count
		total_count += count
	var checks: Array[String] = [
		assert_eq(int(deck.id), 1750005, "17.5 Slowking deck should keep its unique bundled id"),
		assert_eq(str(deck.deck_name), "17.5呆呆王", "17.5 Slowking deck should keep the configured display name"),
		assert_eq(deck.cards.size(), expected_counts.size(), "17.5 Slowking deck should contain the screenshot card rows"),
		assert_eq(total_count, 60, "17.5 Slowking deck card counts should add up to 60"),
	]
	for card_id_variant: Variant in expected_counts.keys():
		var card_id := str(card_id_variant)
		checks.append(assert_eq(int(actual_counts.get(card_id, 0)), int(expected_counts[card_id_variant]), "%s count should match the screenshot" % card_id))
	for card_id_variant: Variant in actual_counts.keys():
		var card_id := str(card_id_variant)
		checks.append(assert_true(expected_counts.has(card_id), "%s should be part of the screenshot deck list" % card_id))
	return run_checks(checks)


func test_runtime_bundled_card_json_loads_through_card_database_deserializer() -> String:
	var db := CardDatabaseScript.new()
	var card_path := "res://data/bundled_user/cards/CSV8C_136.json"
	var direct_card: CardData = db._load_card_from_file(card_path)
	var cached_card: CardData = db.get_card("CSV8C", "136")
	return run_checks([
		assert_true(FileAccess.file_exists(card_path), "Regression fixture CSV8C_136 should exist in bundled cards"),
		assert_not_null(direct_card, "CardDatabase should deserialize bundled JSON with CardData.from_dict"),
		assert_not_null(cached_card, "CardDatabase.get_card should load bundled fallback cards"),
		assert_eq(str(direct_card.get_uid()) if direct_card != null else "", "CSV8C_136", "Directly loaded card should keep its uid"),
		assert_eq(str(cached_card.stage) if cached_card != null else "", "Basic", "Cached CSV8C_136 should be a Basic Pokemon for setup checks"),
	])


func test_cbb5c_1501_joltik_is_bundled_with_existing_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CBB5C_1501.json"
	var image_path := "res://data/bundled_user/cards/images/CBB5C/1501.png.bin"
	var card: CardData = db.get_card("CBB5C", "1501")
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CBB5C_1501 Joltik card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CBB5C_1501 Joltik image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CBB5C_1501 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CBB5C_1501 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CBB5C_1501 bundled card image should be valid"),
		assert_not_null(card, "CBB5C_1501 should load through CardDatabase bundled fallback"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name), "电电虫", "CBB5C_1501 should keep the imported Chinese card name"))
		checks.append(assert_eq(str(card.effect_id), "76ce94424f53e8a93cfb2c2008a84a86", "CBB5C_1501 should reuse the existing Joltik charge effect"))
		checks.append(assert_eq(str(card.attacks[0].get("name", "")) if card.attacks.size() > 0 else "", "电电充能", "CBB5C_1501 should expose the Joltik attack"))
	return run_checks(checks)


func test_607807_joltik_box_galvantula_is_bundled_with_image_and_deck() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV8C_010.json"
	var image_path := "res://data/bundled_user/cards/images/CSV8C/010.png.bin"
	var deck_path := "res://data/bundled_user/decks/607807.json"
	var card: CardData = db.get_card("CSV8C", "010")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var deck: DeckData = db._load_deck_from_file(deck_path)
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV8C_010 Galvantula card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV8C_010 Galvantula image should be listed in bundled manifest"),
		assert_true(deck_path in manifest, "607807 Joltik Box deck should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV8C_010 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV8C_010 bundled card image should exist"),
		assert_true(FileAccess.file_exists(deck_path), "607807 bundled deck JSON should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV8C_010 bundled image should be a supported card image"),
		assert_not_null(direct_card, "CSV8C_010 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV8C_010 should load through CardDatabase bundled fallback"),
		assert_not_null(deck, "607807 Joltik Box deck should load from bundled JSON"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Galvantula", "CSV8C_010 should keep the imported English card name"))
		checks.append(assert_eq(str(card.effect_id), "4aa937bbc437cbfd7b64597b7bcee0d2", "CSV8C_010 should keep the implemented effect id"))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "CSV8C_010 should not show the unimplemented badge"))
	if deck != null:
		var galvantula_count := 0
		for entry: Dictionary in deck.cards:
			if str(entry.get("set_code", "")) == "CSV8C" and str(entry.get("card_index", "")) == "010":
				galvantula_count += int(entry.get("count", 0))
		checks.append(assert_eq(int(deck.total_cards), 60, "607807 Joltik Box should keep 60 cards"))
		checks.append(assert_eq(galvantula_count, 1, "607807 Joltik Box should include one CSV8C_010 Galvantula"))
	return run_checks(checks)


func test_csv8c_188_powerglass_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV8C_188.json"
	var image_path := "res://data/bundled_user/cards/images/CSV8C/188.png.bin"
	var card: CardData = db.get_card("CSV8C", "188")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV8C_188 Powerglass card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV8C_188 Powerglass image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV8C_188 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV8C_188 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV8C_188 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV8C_188 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV8C_188 should load through CardDatabase bundled fallback"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Powerglass", "CSV8C_188 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Tool", "CSV8C_188 should be imported as a Pokemon Tool"))
		checks.append(assert_eq(str(card.effect_id), "1dc38c46be0951b2b135e1df2e5e7767", "CSV8C_188 should keep the Powerglass effect id"))
	return run_checks(checks)


func test_csv1c_028_armarouge_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV1C_028.json"
	var image_path := "res://data/bundled_user/cards/images/CSV1C/028.png.bin"
	var card: CardData = db.get_card("CSV1C", "028")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var found_in_pool := false
	for pooled: CardData in db.get_all_cards():
		if pooled.get_uid() == "CSV1C_028":
			found_in_pool = true
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV1C_028 Armarouge card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV1C_028 Armarouge image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV1C_028 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV1C_028 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV1C_028 bundled image should be valid"),
		assert_not_null(direct_card, "CSV1C_028 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV1C_028 should load through CardDatabase bundled fallback"),
		assert_true(found_in_pool, "CSV1C_028 should appear in CardDatabase.get_all_cards for deck editor pools"),
		assert_true(db.has_card("CSV1C", "028"), "CardDatabase.has_card should recognize bundled CSV1C_028"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name), "红莲铠骑", "CSV1C_028 should keep the source Chinese name"))
		checks.append(assert_eq(str(card.name_en), "Armarouge", "CSV1C_028 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CSV1C_028 should be imported as Pokemon"))
		checks.append(assert_eq(str(card.stage), "Stage 1", "CSV1C_028 should keep source evolution stage"))
		checks.append(assert_eq(str(card.evolves_from), "炭小侍", "CSV1C_028 should keep source evolution line"))
		checks.append(assert_eq(str(card.effect_id), "4f4c17fe9f3429419f9e344fbecb140d", "CSV1C_028 should keep the API effect id"))
		checks.append(assert_eq(card.abilities.size(), 1, "CSV1C_028 should import Armarouge's Ability"))
		checks.append(assert_eq(card.attacks.size(), 1, "CSV1C_028 should import Armarouge's attack"))
	return run_checks(checks)


func test_csv4c_118_defiance_vest_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV4C_118.json"
	var image_path := "res://data/bundled_user/cards/images/CSV4C/118.png.bin"
	var card: CardData = db.get_card("CSV4C", "118")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var found_in_pool := false
	for pooled: CardData in db.get_all_cards():
		if pooled.get_uid() == "CSV4C_118":
			found_in_pool = true
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV4C_118 Defiance Vest card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV4C_118 Defiance Vest image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV4C_118 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV4C_118 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV4C_118 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV4C_118 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV4C_118 should load through CardDatabase bundled fallback"),
		assert_true(found_in_pool, "CSV4C_118 should appear in CardDatabase.get_all_cards for deck editor pools"),
		assert_true(db.has_card("CSV4C", "118"), "CardDatabase.has_card should recognize bundled CSV4C_118"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Defiance Vest", "CSV4C_118 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Tool", "CSV4C_118 should be imported as a Pokemon Tool"))
		checks.append(assert_eq(str(card.effect_id), "8661d78f9695838cee64d65fb73ddf58", "CSV4C_118 should keep the Defiance Vest effect id"))
	return run_checks(checks)


func test_cs4dac_313_zamazenta_v_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CS4DaC_313.json"
	var image_path := "res://data/bundled_user/cards/images/CS4DaC/313.png.bin"
	var card: CardData = db.get_card("CS4DaC", "313")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var found_in_pool := false
	for pooled: CardData in db.get_all_cards():
		if pooled.get_uid() == "CS4DaC_313":
			found_in_pool = true
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CS4DaC_313 Zamazenta V card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CS4DaC_313 Zamazenta V image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CS4DaC_313 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CS4DaC_313 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CS4DaC_313 bundled card image should be valid"),
		assert_not_null(direct_card, "CS4DaC_313 bundled JSON should deserialize directly"),
		assert_not_null(card, "CS4DaC_313 should load through CardDatabase bundled fallback"),
		assert_true(found_in_pool, "CS4DaC_313 should appear in CardDatabase.get_all_cards for deck editor pools"),
		assert_true(db.has_card("CS4DaC", "313"), "CardDatabase.has_card should recognize bundled CS4DaC_313"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Zamazenta V", "CS4DaC_313 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CS4DaC_313 should be imported as Pokemon"))
		checks.append(assert_eq(str(card.effect_id), "f3543bd547e44612b034263374aa0ef1", "CS4DaC_313 should keep the Zamazenta V effect id"))
	return run_checks(checks)


func test_csv95c_004_006_023_031_are_bundled_with_images_and_effect_ids() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var expected := {
		"CSV9.5C_004": {
			"index": "004",
			"type": "Pokemon",
			"stage": "Basic",
			"effect_id": "28505a8ad6e07e74382c1b5e09737932",
		},
		"CSV9.5C_006": {
			"index": "006",
			"type": "Pokemon",
			"stage": "Stage 1",
			"effect_id": "930f07ef177d44b0e1084343b66b13af",
		},
		"CSV9.5C_023": {
			"index": "023",
			"type": "Pokemon",
			"stage": "Stage 1",
			"effect_id": "313cc7781c8489ce8c45d3597dfce241",
		},
		"CSV9.5C_031": {
			"index": "031",
			"type": "Pokemon",
			"stage": "Basic",
			"effect_id": "26d4511ab7a84d662387e992b44f130a",
		},
	}
	var checks: Array[String] = []
	for uid_variant: Variant in expected.keys():
		var uid := str(uid_variant)
		var meta: Dictionary = expected[uid_variant]
		var index := str(meta.get("index", ""))
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/CSV9.5C/%s.png.bin" % index
		var card: CardData = db.get_card("CSV9.5C", index)
		var found_in_pool := false
		for pooled: CardData in db.get_all_cards():
			if pooled.get_uid() == uid:
				found_in_pool = true
				break
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % uid))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled card image should be valid" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % uid))
		checks.append(assert_true(found_in_pool, "%s should appear in CardDatabase.get_all_cards for deck editor pools" % uid))
		if card != null:
			checks.append(assert_eq(str(card.card_type), str(meta.get("type", "")), "%s should keep imported card type" % uid))
			checks.append(assert_eq(str(card.stage), str(meta.get("stage", "")), "%s should keep imported stage" % uid))
			checks.append(assert_eq(str(card.effect_id), str(meta.get("effect_id", "")), "%s should keep imported effect id" % uid))
	return run_checks(checks)


func test_csv95c_029_hearthflame_ogerpon_ex_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV9.5C_029.json"
	var image_path := "res://data/bundled_user/cards/images/CSV9.5C/029.png.bin"
	var card: CardData = db.get_card("CSV9.5C", "029")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var found_in_pool := false
	for pooled: CardData in db.get_all_cards():
		if pooled.get_uid() == "CSV9.5C_029":
			found_in_pool = true
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV9.5C_029 Hearthflame Mask Ogerpon ex card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV9.5C_029 Hearthflame Mask Ogerpon ex image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV9.5C_029 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV9.5C_029 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV9.5C_029 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV9.5C_029 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV9.5C_029 should load through CardDatabase bundled fallback"),
		assert_true(found_in_pool, "CSV9.5C_029 should appear in CardDatabase.get_all_cards for deck editor pools"),
		assert_true(db.has_card("CSV9.5C", "029"), "CardDatabase.has_card should recognize bundled CSV9.5C_029"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Hearthflame Mask Ogerpon ex", "CSV9.5C_029 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CSV9.5C_029 should be imported as Pokemon"))
		checks.append(assert_eq(str(card.stage), "Basic", "CSV9.5C_029 should keep Basic stage"))
		checks.append(assert_eq(int(card.hp), 210, "CSV9.5C_029 should keep 210 HP"))
		checks.append(assert_eq(str(card.energy_type), "R", "CSV9.5C_029 should keep Fire typing"))
		checks.append(assert_eq(str(card.mechanic), "ex", "CSV9.5C_029 should keep ex mechanic"))
		checks.append(assert_eq(str(card.ancient_trait), "Tera", "CSV9.5C_029 should keep Tera marker"))
		checks.append(assert_eq(str(card.effect_id), "afe6e5fb7931c8c529e43134ef264885", "CSV9.5C_029 should keep the API effect id"))
		checks.append(assert_eq(card.attacks.size(), 2, "CSV9.5C_029 should import both attacks"))
	return run_checks(checks)


func test_csv9c_099_annihilape_uses_remote_import_metadata() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV9C_099.json"
	var image_path := "res://data/bundled_user/cards/images/CSV9C/099.png.bin"
	var direct_card: CardData = db._load_card_from_file(card_path)
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV9C_099 card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV9C_099 card image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV9C_099 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV9C_099 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV9C_099 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV9C_099 bundled JSON should deserialize directly"),
		assert_true(db.has_card("CSV9C", "099"), "CardDatabase.has_card should recognize bundled CSV9C_099"),
	]
	if direct_card != null:
		checks.append(assert_eq(str(direct_card.name), "弃世猴", "CSV9C_099 should keep the imported Chinese name"))
		checks.append(assert_eq(str(direct_card.name_en), "Annihilape", "CSV9C_099 should keep the imported English card name"))
		checks.append(assert_eq(str(direct_card.set_code_en), "SSP", "CSV9C_099 should keep the imported English set code"))
		checks.append(assert_eq(str(direct_card.card_index_en), "100", "CSV9C_099 should keep the imported English card index"))
		checks.append(assert_eq(str(direct_card.effect_id), "293b8c882a550600a395e3c82b58f833", "CSV9C_099 should keep the API effect id"))
	return run_checks(checks)


func test_csv9c_180_scramble_switch_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV9C_180.json"
	var image_path := "res://data/bundled_user/cards/images/CSV9C/180.png.bin"
	var card: CardData = db.get_card("CSV9C", "180")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var found_in_pool := false
	for pooled: CardData in db.get_all_cards():
		if pooled.get_uid() == "CSV9C_180":
			found_in_pool = true
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV9C_180 Scramble Switch card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV9C_180 Scramble Switch image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV9C_180 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV9C_180 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV9C_180 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV9C_180 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV9C_180 should load through CardDatabase bundled fallback"),
		assert_true(found_in_pool, "CSV9C_180 should appear in CardDatabase.get_all_cards for deck editor pools"),
		assert_true(db.has_card("CSV9C", "180"), "CardDatabase.has_card should recognize bundled CSV9C_180"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Scramble Switch", "CSV9C_180 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Item", "CSV9C_180 should be imported as an Item"))
		checks.append(assert_eq(str(card.mechanic), "ACE SPEC", "CSV9C_180 should keep the ACE SPEC mechanic"))
		checks.append(assert_eq(str(card.effect_id), "1da701b43813d6ddb1238e54bce95811", "CSV9C_180 should keep the API effect id"))
	return run_checks(checks)


func test_csv95c_126_140_149_are_bundled_with_images_and_effect_ids() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var expected := {
		"CSV9.5C_126": {
			"index": "126",
			"type": "Pokemon",
			"stage": "Basic",
			"mechanic": "",
			"ancient_trait": "",
			"effect_id": "62bbe4c45b6f0406104dc382a620e017",
		},
		"CSV9.5C_140": {
			"index": "140",
			"type": "Pokemon",
			"stage": "Basic",
			"mechanic": "ex",
			"ancient_trait": "Tera",
			"effect_id": "efa5883e7d648ebc984f161b2c7d8fe9",
		},
		"CSV9.5C_149": {
			"index": "149",
			"type": "Pokemon",
			"stage": "Basic",
			"mechanic": "",
			"ancient_trait": "",
			"effect_id": "d5ab8efe3bcad6f39e9a434ae6d8de7a",
		},
	}
	var checks: Array[String] = []
	for uid_variant: Variant in expected.keys():
		var uid := str(uid_variant)
		var meta: Dictionary = expected[uid_variant]
		var index := str(meta.get("index", ""))
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/CSV9.5C/%s.png.bin" % index
		var card: CardData = db.get_card("CSV9.5C", index)
		var found_in_pool := false
		for pooled: CardData in db.get_all_cards():
			if pooled.get_uid() == uid:
				found_in_pool = true
				break
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % uid))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled card image should be valid" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % uid))
		checks.append(assert_true(found_in_pool, "%s should appear in CardDatabase.get_all_cards for deck editor pools" % uid))
		if card != null:
			checks.append(assert_eq(str(card.card_type), str(meta.get("type", "")), "%s should keep imported card type" % uid))
			checks.append(assert_eq(str(card.stage), str(meta.get("stage", "")), "%s should keep imported stage" % uid))
			checks.append(assert_eq(str(card.mechanic), str(meta.get("mechanic", "")), "%s should keep imported mechanic" % uid))
			checks.append(assert_eq(str(card.ancient_trait), str(meta.get("ancient_trait", "")), "%s should keep imported ancient trait" % uid))
			checks.append(assert_eq(str(card.effect_id), str(meta.get("effect_id", "")), "%s should keep imported effect id" % uid))
	return run_checks(checks)


func test_csv95c_104_umbreon_ex_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV9.5C_104.json"
	var image_path := "res://data/bundled_user/cards/images/CSV9.5C/104.png.bin"
	var card: CardData = db.get_card("CSV9.5C", "104")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var found_in_pool := false
	for pooled: CardData in db.get_all_cards():
		if pooled.get_uid() == "CSV9.5C_104":
			found_in_pool = true
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV9.5C_104 Umbreon ex card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV9.5C_104 Umbreon ex image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV9.5C_104 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV9.5C_104 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV9.5C_104 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV9.5C_104 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV9.5C_104 should load through CardDatabase bundled fallback"),
		assert_true(found_in_pool, "CSV9.5C_104 should appear in CardDatabase.get_all_cards for deck editor pools"),
		assert_true(db.has_card("CSV9.5C", "104"), "CardDatabase.has_card should recognize bundled CSV9.5C_104"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Umbreon ex", "CSV9.5C_104 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CSV9.5C_104 should be imported as Pokemon"))
		checks.append(assert_eq(str(card.stage), "Stage 1", "CSV9.5C_104 should keep Stage 1 metadata"))
		checks.append(assert_eq(str(card.evolves_from), "伊布", "CSV9.5C_104 should keep Eevee as its evolution source"))
		checks.append(assert_eq(int(card.hp), 280, "CSV9.5C_104 should keep 280 HP"))
		checks.append(assert_eq(str(card.energy_type), "D", "CSV9.5C_104 should keep Darkness typing"))
		checks.append(assert_eq(str(card.mechanic), "ex", "CSV9.5C_104 should keep ex mechanic"))
		checks.append(assert_eq(str(card.ancient_trait), "Tera", "CSV9.5C_104 should keep Tera marker"))
		checks.append(assert_eq(str(card.effect_id), "233350ffecdbfac2a8fab27e7f7da282", "CSV9.5C_104 should keep the API effect id"))
		checks.append(assert_eq(card.attacks.size(), 2, "CSV9.5C_104 should import both attacks"))
	return run_checks(checks)


func test_csv95c_188_black_belts_training_is_bundled_with_image_and_effect_id() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV9.5C_188.json"
	var image_path := "res://data/bundled_user/cards/images/CSV9.5C/188.png.bin"
	var card: CardData = db.get_card("CSV9.5C", "188")
	var direct_card: CardData = db._load_card_from_file(card_path)
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV9.5C_188 Black Belt's Training card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CSV9.5C_188 Black Belt's Training image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV9.5C_188 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV9.5C_188 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV9.5C_188 bundled card image should be valid"),
		assert_not_null(direct_card, "CSV9.5C_188 bundled JSON should deserialize directly"),
		assert_not_null(card, "CSV9.5C_188 should load through CardDatabase bundled fallback"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Black Belt's Training", "CSV9.5C_188 should keep the imported English card name"))
		checks.append(assert_eq(str(card.card_type), "Supporter", "CSV9.5C_188 should be imported as a Supporter"))
		checks.append(assert_eq(str(card.effect_id), "a444b83881df9e2a0225aee95bbc853a", "CSV9.5C_188 should keep the Black Belt's Training effect id"))
	return run_checks(checks)


func test_has_card_checks_bundled_powerglass_even_without_user_copy() -> String:
	var db := CardDatabaseScript.new()
	var user_path := "user://cards/CSV8C_188.json"
	var absolute_user_path := ProjectSettings.globalize_path(user_path)
	var had_user_copy := FileAccess.file_exists(user_path)
	var user_copy_text := FileAccess.get_file_as_string(user_path) if had_user_copy else ""
	if had_user_copy:
		DirAccess.remove_absolute(absolute_user_path)

	var has_powerglass := db.has_card("CSV8C", "188")

	if had_user_copy:
		_write_text(user_path, user_copy_text)

	return run_checks([
		assert_true(has_powerglass, "CardDatabase.has_card should recognize bundled CSV8C_188 even before seeding it into user://cards"),
	])


func test_get_all_cards_includes_bundle_only_powerglass_for_deck_editor_pool() -> String:
	var db := CardDatabaseScript.new()
	var found: CardData = null
	for card: CardData in db.get_all_cards():
		if card.get_uid() == "CSV8C_188":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "Deck editor card pool should include bundle-only CSV8C_188 from CardDatabase.get_all_cards"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name_en), "Powerglass", "get_all_cards should expose Powerglass metadata"))
		checks.append(assert_eq(str(found.card_type), "Tool", "Powerglass should appear in the Tool category"))
	return run_checks(checks)


func test_get_all_cards_includes_bundle_only_black_belts_training_for_deck_editor_pool() -> String:
	var db := CardDatabaseScript.new()
	var found: CardData = null
	for card: CardData in db.get_all_cards():
		if card.get_uid() == "CSV9.5C_188":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "Deck editor card pool should include bundle-only CSV9.5C_188 from CardDatabase.get_all_cards"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name_en), "Black Belt's Training", "get_all_cards should expose Black Belt's Training metadata"))
		checks.append(assert_eq(str(found.card_type), "Supporter", "Black Belt's Training should appear in the Supporter category"))
	return run_checks(checks)


func test_version_170_bundled_decks_do_not_start_as_empty_card_database_game_over() -> String:
	var db := CardDatabaseScript.new()
	var player_deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/1700012.json")
	var opponent_deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/1700001.json")
	var player_basic := _first_basic_pokemon_entry(db, player_deck)
	var opponent_basic := _first_basic_pokemon_entry(db, opponent_deck)
	if player_deck == null or opponent_deck == null:
		return "17.0 bundled decks should load before startup smoke"
	if player_basic.is_empty() or opponent_basic.is_empty():
		return "17.0 bundled decks should expose at least one loadable Basic Pokemon"

	var gsm := GameStateMachine.new()
	gsm.set_deck_order_override(0, [player_basic])
	gsm.set_deck_order_override(1, [opponent_basic])
	gsm.start_game(player_deck, opponent_deck, 0)
	var player_has_basic := gsm.game_state.players[0].has_basic_pokemon_in_hand()
	var opponent_has_basic := gsm.game_state.players[1].has_basic_pokemon_in_hand()
	var checks: Array[String] = [
		assert_false(gsm.game_state.phase == GameState.GamePhase.GAME_OVER, "17.0 real decks must not immediately end as an empty/no-Basic startup"),
		assert_eq(gsm.game_state.players[0].hand.size(), 7, "Player should draw an opening hand from loaded deck cards"),
		assert_eq(gsm.game_state.players[1].hand.size(), 7, "Opponent should draw an opening hand from loaded deck cards"),
		assert_true(player_has_basic, "Player opening hand should contain the forced Basic Pokemon"),
		assert_true(opponent_has_basic, "Opponent opening hand should contain the forced Basic Pokemon"),
		assert_gt(gsm.count_player_total_cards(0), 0, "Player loaded deck must not collapse to an empty card database"),
		assert_gt(gsm.count_player_total_cards(1), 0, "Opponent loaded deck must not collapse to an empty card database"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_recent_card_audit_batch_is_bundled_as_default_install_cards() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_ids := [
		"CSNC_020",
		"CSV8C_050",
		"CSV7C_030",
		"CSV3C_086",
	]
	var expected_effect_ids := {
		"CSNC_020": "2e5819cd4e1c354b8a9945525c54ec71",
		"CSV8C_050": "7580acd5669bac12cb1af8007d2e6a6a",
		"CSV7C_030": "c2d6b5ec0bc365112105fea079a22fd7",
		"CSV3C_086": "f189ac39dca6332f0b3af7b65cea8220",
	}
	var checks: Array[String] = []
	for card_id: String in card_ids:
		var parts := card_id.split("_", false, 1)
		var set_code := str(parts[0])
		var card_index := str(parts[1])
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		checks.append(assert_true(card_path in manifest, "%s should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % card_id))
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % card_id))
		if card != null:
			checks.append(assert_eq(str(card.effect_id), str(expected_effect_ids[card_id]), "%s should keep the implemented effect id" % card_id))
	return run_checks(checks)


func test_csv8c_057_milotic_ex_is_bundled_with_image_and_effect_metadata() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV8C_057.json"
	var image_path := "res://data/bundled_user/cards/images/CSV8C/057.png.bin"
	var card: CardData = db.get_card("CSV8C", "057")
	var found_in_pool := false
	for pool_card: CardData in db.get_all_cards():
		if pool_card != null and pool_card.get_uid() == "CSV8C_057":
			found_in_pool = true
			break
	return run_checks([
		assert_true(card_path in manifest, "CSV8C_057 should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CSV8C_057 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV8C_057 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV8C_057 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV8C_057 bundled card image should be readable"),
		assert_not_null(card, "CSV8C_057 should load through CardDatabase bundled fallback"),
		assert_true(db.has_card("CSV8C", "057"), "CardDatabase.has_card should recognize CSV8C_057"),
		assert_true(found_in_pool, "CardDatabase.get_all_cards should expose CSV8C_057 to DeckEditor"),
		assert_eq(str(card.name_en if card != null else ""), "Milotic ex", "CSV8C_057 should keep imported English name"),
		assert_eq(str(card.card_type if card != null else ""), "Pokemon", "CSV8C_057 should keep imported card type"),
		assert_eq(str(card.effect_id if card != null else ""), "57e95f8cb1129f6b45b7bbbc1a45b643", "CSV8C_057 should keep imported effect id"),
	])


func test_csv95c_141_163_182_are_bundled_with_images_and_effects() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var expected := {
		"CSV9.5C_141": {"effect_id": "76f4e0d39348c21f1f1a4be4d653b6a5", "card_type": "Pokemon"},
		"CSV9.5C_163": {"effect_id": "6a7fe7ec3f22c435f50b49909e85b3d3", "card_type": "Item"},
		"CSV9.5C_182": {"effect_id": "60efb96839df10bb78737047da1c4fb1", "card_type": "Supporter"},
	}
	var checks: Array[String] = []
	for card_id: String in expected.keys():
		var parts := card_id.split("_", false, 1)
		var set_code := str(parts[0])
		var card_index := str(parts[1])
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		var spec: Dictionary = expected[card_id]
		checks.append(assert_true(card_path in manifest, "%s should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % card_id))
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % card_id))
		if card != null:
			checks.append(assert_eq(str(card.effect_id), str(spec["effect_id"]), "%s should keep source effect id" % card_id))
			checks.append(assert_eq(str(card.card_type), str(spec["card_type"]), "%s should keep source card type" % card_id))
			if card_id == "CSV9.5C_163":
				checks.append(assert_true(card.is_ace_spec(), "CSV9.5C_163 should be recognized as ACE SPEC"))
	return run_checks(checks)


func test_csv7c_182_love_ball_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV7C_182.json"
	var image_path := "res://data/bundled_user/cards/images/CSV7C/182.png.bin"
	var card: CardData = db.get_card("CSV7C", "182")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CSV7C_182":
			found = candidate
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV7C_182 should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CSV7C_182 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV7C_182 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV7C_182 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV7C_182 bundled image should be valid"),
		assert_not_null(card, "CSV7C_182 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "Deck editor card pool should include bundle-only CSV7C_182 from CardDatabase.get_all_cards"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Love Ball", "CSV7C_182 should keep source English name"))
		checks.append(assert_eq(str(card.card_type), "Item", "CSV7C_182 should keep source card type"))
		checks.append(assert_eq(str(card.effect_id), "ee2e1cc534d39f1710b1c590bf585ae5", "CSV7C_182 should keep source effect id"))
	return run_checks(checks)


func test_csv3c_117_picnic_basket_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV3C_117.json"
	var image_path := "res://data/bundled_user/cards/images/CSV3C/117.png.bin"
	var card: CardData = db.get_card("CSV3C", "117")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CSV3C_117":
			found = candidate
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV3C_117 should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CSV3C_117 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV3C_117 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV3C_117 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV3C_117 bundled image should be valid"),
		assert_not_null(card, "CSV3C_117 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "Deck editor card pool should include bundle-only CSV3C_117 from CardDatabase.get_all_cards"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Picnic Basket", "CSV3C_117 should keep source English name"))
		checks.append(assert_eq(str(card.card_type), "Item", "CSV3C_117 should keep source card type"))
		checks.append(assert_eq(str(card.effect_id), "276cc8e3fd9a7b7c18f5da7715fe8460", "CSV3C_117 should keep source effect id"))
	return run_checks(checks)


func test_csv2c_011_floragato_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV2C_011.json"
	var image_path := "res://data/bundled_user/cards/images/CSV2C/011.png.bin"
	var card: CardData = db.get_card("CSV2C", "011")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CSV2C_011":
			found = candidate
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV2C_011 should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CSV2C_011 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV2C_011 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV2C_011 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV2C_011 bundled image should be valid"),
		assert_not_null(card, "CSV2C_011 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "Deck editor card pool should include bundle-only CSV2C_011 from CardDatabase.get_all_cards"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Floragato", "CSV2C_011 should keep source English name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CSV2C_011 should keep source card type"))
		checks.append(assert_eq(str(card.stage), "Stage 1", "CSV2C_011 should keep source evolution stage"))
		checks.append(assert_eq(str(card.evolves_from), "新叶喵", "CSV2C_011 should keep source evolution line"))
		checks.append(assert_eq(str(card.effect_id), "b49466f5df9dfcef38331df65187f068", "CSV2C_011 should keep source effect id"))
	return run_checks(checks)


func test_csv2c_114_rigid_band_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV2C_114.json"
	var image_path := "res://data/bundled_user/cards/images/CSV2C/114.png.bin"
	var card: CardData = db.get_card("CSV2C", "114")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CSV2C_114":
			found = candidate
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV2C_114 should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CSV2C_114 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV2C_114 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV2C_114 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV2C_114 bundled image should be valid"),
		assert_not_null(card, "CSV2C_114 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "Deck editor card pool should include bundle-only CSV2C_114 from CardDatabase.get_all_cards"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Rigid Band", "CSV2C_114 should keep source English name"))
		checks.append(assert_eq(str(card.card_type), "Tool", "CSV2C_114 should keep source card type"))
		checks.append(assert_eq(str(card.effect_id), "6ec876cf4467166edf6e90fa1cc321eb", "CSV2C_114 should keep source effect id"))
	return run_checks(checks)


func test_csv5c_053_054_and_csv9c_072_source_cards_are_bundled_with_images_and_effect_ids() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var specs := [
		{
			"uid": "CSV5C_053",
			"set": "CSV5C",
			"index": "053",
			"name_en": "Natu",
			"card_type": "Pokemon",
			"effect_id": "2317be04afe1bd94899a29fe09b84d96",
		},
		{
			"uid": "CSV5C_054",
			"set": "CSV5C",
			"index": "054",
			"name_en": "Xatu",
			"card_type": "Pokemon",
			"effect_id": "bcd9644ea935ce567829f4a76756059b",
		},
		{
			"uid": "CSV9C_072",
			"set": "CSV9C",
			"index": "072",
			"name_en": "Slowking",
			"card_type": "Pokemon",
			"effect_id": "59d3af627f14b4a65ab4d589f6cb52db",
		},
	]
	var checks: Array[String] = []
	for spec: Dictionary in specs:
		var uid := str(spec["uid"])
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [str(spec["set"]), str(spec["index"])]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(card_path))
		var card: CardData = null
		if parsed is Dictionary:
			var payload: Dictionary = parsed
			card = CardData.from_dict(payload)
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled seed manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled seed manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % uid))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % uid))
		checks.append(assert_not_null(card, "%s bundled card JSON should parse into CardData" % uid))
		if card != null:
			checks.append(assert_eq(card.get_uid(), uid, "%s should keep source uid" % uid))
			checks.append(assert_eq(str(card.name_en), str(spec["name_en"]), "%s should keep source English name" % uid))
			checks.append(assert_eq(str(card.card_type), str(spec["card_type"]), "%s should keep source card type" % uid))
			checks.append(assert_eq(str(card.effect_id), str(spec["effect_id"]), "%s should keep source effect id" % uid))
	return run_checks(checks)


func test_cs5ac_068_crobat_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CS5aC_068.json"
	var image_path := "res://data/bundled_user/cards/images/CS5aC/068.png.bin"
	var card: CardData = db.get_card("CS5aC", "068")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CS5aC_068":
			found = candidate
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CS5aC_068 card JSON should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CS5aC_068 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CS5aC_068 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CS5aC_068 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CS5aC_068 bundled image should be valid"),
		assert_not_null(card, "CS5aC_068 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "Deck editor card pool should include bundle-only CS5aC_068 from CardDatabase.get_all_cards"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Crobat", "CS5aC_068 should keep source English name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CS5aC_068 should keep source card type"))
		checks.append(assert_eq(str(card.stage), "Stage 2", "CS5aC_068 should keep source evolution stage"))
		checks.append(assert_eq(str(card.evolves_from), "大嘴蝠", "CS5aC_068 should keep source evolution line"))
		checks.append(assert_eq(str(card.effect_id), "930008a5b5f22ceabca6767aafd93a35", "CS5aC_068 should keep source effect id"))
	return run_checks(checks)


func test_cs6ac_099_zamazenta_vstar_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CS6aC_099.json"
	var image_path := "res://data/bundled_user/cards/images/CS6aC/099.png.bin"
	var card: CardData = db.get_card("CS6aC", "099")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CS6aC_099":
			found = candidate
			break
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CS6aC_099 card JSON should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CS6aC_099 card image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CS6aC_099 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CS6aC_099 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CS6aC_099 bundled image should be valid"),
		assert_not_null(card, "CS6aC_099 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "Deck editor card pool should include bundle-only CS6aC_099 from CardDatabase.get_all_cards"),
	]
	if card != null:
		checks.append(assert_eq(str(card.name_en), "Zamazenta VSTAR", "CS6aC_099 should keep source English name"))
		checks.append(assert_eq(str(card.card_type), "Pokemon", "CS6aC_099 should keep source card type"))
		checks.append(assert_eq(str(card.stage), "VSTAR", "CS6aC_099 should keep source evolution stage"))
		checks.append(assert_eq(str(card.evolves_from), "藏玛然特V", "CS6aC_099 should keep source evolution line"))
		checks.append(assert_eq(str(card.effect_id), "00d90ff674296941a9da9d9a0255aa2d", "CS6aC_099 should keep source effect id"))
	return run_checks(checks)


func test_scoop_up_cyclone_is_bundled_as_default_install_card() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CSV8C_181.json"
	var image_path := "res://data/bundled_user/cards/images/CSV8C/181.png.bin"
	var card: CardData = db.get_card("CSV8C", "181")
	var checks: Array[String] = [
		assert_true(card_path in manifest, "CSV8C_181 should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CSV8C_181 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CSV8C_181 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CSV8C_181 bundled card image should exist"),
		assert_not_null(card, "CSV8C_181 should load through CardDatabase bundled fallback"),
	]
	if card != null:
		checks.append(assert_eq(str(card.effect_id), "c1acc32f6333793f261c9c132435fdfa", "CSV8C_181 should keep Scoop Up Cyclone effect id"))
		checks.append(assert_true(card.is_ace_spec(), "CSV8C_181 should be recognized as ACE SPEC from bundled card data"))
	return run_checks(checks)


func test_poison_box_key_cards_are_bundled_with_images() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var deck_path := "res://data/bundled_user/decks/1700010.json"
	var required_cards := [
		{"id": "CS5aC_079", "set": "CS5aC", "index": "079"},
		{"id": "CSV6C_080", "set": "CSV6C", "index": "080"},
	]
	var raw := FileAccess.get_file_as_string(deck_path)
	var parsed: Variant = JSON.parse_string(raw)
	var deck_cards: Array[String] = []
	if parsed is Dictionary:
		for entry: Dictionary in (parsed as Dictionary).get("cards", []):
			deck_cards.append("%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))])

	var checks: Array[String] = [
		assert_true(deck_path in manifest, "17.0 Poison Box deck should be listed in bundled seed manifest"),
		assert_true(parsed is Dictionary, "17.0 Poison Box bundled deck JSON should parse"),
	]
	for card_ref: Dictionary in required_cards:
		var card_id := str(card_ref["id"])
		var set_code := str(card_ref["set"])
		var card_index := str(card_ref["index"])
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(card_id in deck_cards, "17.0 Poison Box should include %s" % card_id))
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled card image should be a supported image file" % card_id))
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % card_id))
	return run_checks(checks)


func test_2026_05_24_new_cards_and_requested_decks_are_bundled() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_ids := [
		"CS5aC_079",
		"CSV2C_128",
		"CSV6C_078",
		"CSV6C_080",
		"CSV7C_052",
		"CSV7C_053",
		"CSV7C_054",
		"CSV7C_065",
		"CSV7C_118",
		"CSV7C_131",
		"CSV7C_195",
		"CSV7C_200",
		"CSV7C_203",
		"CSV8C_110",
		"CSV8C_111",
		"CSV8C_112",
	]
	var deck_ids := [607805, 608194, 610403, 606676]
	var checks: Array[String] = []
	for card_id: String in card_ids:
		var parts := card_id.split("_", false, 1)
		var set_code := str(parts[0])
		var card_index := str(parts[1])
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % card_id))
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % card_id))
	for deck_id: int in deck_ids:
		var deck_path := "res://data/bundled_user/decks/%d.json" % deck_id
		var deck: DeckData = db._load_deck_from_file(deck_path)
		checks.append(assert_true(deck_path in manifest, "Deck %d should be listed in bundled manifest" % deck_id))
		checks.append(assert_true(FileAccess.file_exists(deck_path), "Deck %d bundled JSON should exist" % deck_id))
		checks.append(assert_not_null(deck, "Deck %d should load from bundled JSON" % deck_id))
		if deck != null:
			checks.append(assert_eq(int(deck.total_cards), 60, "Deck %d should keep 60 cards" % deck_id))
	return run_checks(checks)


func test_cs5bc_040_slowbro_is_bundled_for_deck_editor_visibility() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CS5bC_040.json"
	var image_path := "res://data/bundled_user/cards/images/CS5bC/040.png.bin"
	var card: CardData = db.get_card("CS5bC", "040")
	var all_cards := db.get_all_cards()
	var found_in_all := false
	for candidate: CardData in all_cards:
		if candidate != null and candidate.set_code == "CS5bC" and candidate.card_index == "040":
			found_in_all = true
			break
	return run_checks([
		assert_true(card_path in manifest, "CS5bC_040 card JSON should be listed in bundled manifest"),
		assert_true(image_path in manifest, "CS5bC_040 card image should be listed in bundled manifest"),
		assert_true(FileAccess.file_exists(card_path), "CS5bC_040 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CS5bC_040 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CS5bC_040 bundled image should be valid"),
		assert_not_null(card, "CS5bC_040 should load through CardDatabase bundled fallback"),
		assert_eq(str(card.name_en) if card != null else "", "Slowbro", "CS5bC_040 should keep API English name"),
		assert_eq(str(card.card_type) if card != null else "", "Pokemon", "CS5bC_040 should stay in the Pokemon card pool"),
		assert_eq(str(card.effect_id) if card != null else "", "24f6629cb78fa8e4a940f49f67736afa", "CS5bC_040 should keep its API effect id"),
		assert_true(db.has_card("CS5bC", "040"), "CardDatabase.has_card should recognize bundled CS5bC_040"),
		assert_true(found_in_all, "CardDatabase.get_all_cards should include bundled CS5bC_040 for DeckEditor"),
	])


func test_17_0_regigigas_deck_missing_regi_cards_are_bundled() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_ids := [
		"CS4.5C_018",
		"CS5.5C_021",
		"CS5.5C_047",
		"CS5.5C_051",
		"CS5.5C_056",
	]
	var expected_effect_ids := {
		"CS4.5C_018": "2976780d606bf72db47d00825db85124",
		"CS5.5C_021": "873e6ea15bc769061eda7a433d95e9d6",
		"CS5.5C_047": "399668227ca75416c9e72e83d1810457",
		"CS5.5C_051": "db12f1eb552377de4cda107fbb6e1eb4",
		"CS5.5C_056": "d699ab2122b5617fe5a5c97e60ae4dac",
	}
	var deck: DeckData = db._load_deck_from_file("res://data/bundled_user/decks/1700001.json")
	var checks: Array[String] = [
		assert_not_null(deck, "17.0 Regigigas bundled deck should load"),
	]
	for card_id: String in card_ids:
		var parts := card_id.split("_", false, 1)
		var set_code := str(parts[0])
		var card_index := str(parts[1])
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s card image should be listed in bundled manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % card_id))
		checks.append(assert_not_null(card, "%s should load through CardDatabase bundled fallback" % card_id))
		if card != null:
			checks.append(assert_eq(str(card.effect_id), str(expected_effect_ids[card_id]), "%s should keep the implemented effect id" % card_id))
	if deck != null:
		var instances := db.build_deck_instances(deck, 0)
		checks.append(assert_eq(instances.size(), 60, "17.0 Regigigas bundled deck should build all 60 card instances"))
	return run_checks(checks)


func test_existing_install_backfills_new_poison_box_card_resources_on_startup() -> String:
	var db := CardDatabaseScript.new()
	var missing_paths := [
		"user://cards/CS5aC_079.json",
		"user://cards/CSV2C_011.json",
		"user://cards/CSV2C_114.json",
		"user://cards/CSV3C_117.json",
		"user://cards/CSV5C_053.json",
		"user://cards/CSV5C_054.json",
		"user://cards/CSV6C_080.json",
		"user://cards/images/CS5aC/079.png",
		"user://cards/images/CSV2C/011.png",
		"user://cards/images/CSV2C/114.png",
		"user://cards/images/CSV3C/117.png",
		"user://cards/images/CSV5C/053.png",
		"user://cards/images/CSV5C/054.png",
		"user://cards/images/CSV6C/080.png",
	]
	for path: String in missing_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	db._ensure_directories()
	db._seed_bundled_user_data()

	return run_checks([
		assert_true(FileAccess.file_exists("user://cards/CS5aC_079.json"), "Upgrade seed should backfill Radiant Hisuian Sneasler card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV2C_011.json"), "Upgrade seed should backfill Floragato card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV2C_114.json"), "Upgrade seed should backfill Rigid Band card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV3C_117.json"), "Upgrade seed should backfill Picnic Basket card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV5C_053.json"), "Upgrade seed should backfill Natu card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV5C_054.json"), "Upgrade seed should backfill Xatu card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV6C_080.json"), "Upgrade seed should backfill Klawf card JSON for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CS5aC/079.png"), "Upgrade seed should backfill Radiant Hisuian Sneasler image for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CSV2C/011.png"), "Upgrade seed should backfill Floragato image for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CSV2C/114.png"), "Upgrade seed should backfill Rigid Band image for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CSV3C/117.png"), "Upgrade seed should backfill Picnic Basket image for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CSV5C/053.png"), "Upgrade seed should backfill Natu image for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CSV5C/054.png"), "Upgrade seed should backfill Xatu image for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CSV6C/080.png"), "Upgrade seed should backfill Klawf image for existing installs"),
	])


func _write_text(path: String, content: String) -> void:
	var parent_dir := path.get_base_dir()
	if not _dir_exists(parent_dir):
		_make_dir_recursive(parent_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("TestCardDatabaseSeed: failed to write %s" % path)
		return
	file.store_string(content)
	file.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var parent_dir := path.get_base_dir()
	if not _dir_exists(parent_dir):
		_make_dir_recursive(parent_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("TestCardDatabaseSeed: failed to write %s" % path)
		return
	file.store_buffer(bytes)
	file.close()


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _minimal_png_bytes() -> PackedByteArray:
	return PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])


func _remove_dir_recursive(path: String) -> void:
	var absolute_path := _to_absolute_path(path)
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


func _make_dir_recursive(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(_to_absolute_path(path))


func _dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(_to_absolute_path(path))


func _to_absolute_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _first_basic_pokemon_entry(db: Object, deck: DeckData) -> Dictionary:
	if deck == null:
		return {}
	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		var card: CardData = db.get_card(set_code, card_index)
		if card != null and card.is_basic_pokemon():
			return {
				"set_code": set_code,
				"card_index": card_index,
			}
	return {}


func _ace_spec_copy_count(db: Object, deck: DeckData) -> int:
	if deck == null:
		return 0
	var total := 0
	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		var card: CardData = db.get_card(set_code, card_index)
		if card != null and card.is_ace_spec():
			total += int(entry.get("count", 0))
	return total
