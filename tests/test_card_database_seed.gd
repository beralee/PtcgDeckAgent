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
		if leading_ids.size() < 7:
			leading_ids.append(deck.id)
	ids.sort()
	var expected_ids := [
		569061, 575657, 575716, 575718, 575720, 575723, 578647, 579502,
		1700002, 1700003, 1700004, 1700005, 1700007, 1700008, 1700011,
	]
	var expected_leading_ids := [
		1700002, 1700003, 1700004, 1700005, 1700007, 1700008, 1700011,
	]
	leading_ids.sort()
	expected_leading_ids.sort()
	return run_checks([
		assert_eq(ai_decks.size(), expected_ids.size(), "AI deck list should expose exactly the backed-up AI deck set"),
		assert_eq(ids, expected_ids, "AI deck list should match the backed-up AI deck set"),
		assert_eq(leading_ids, expected_leading_ids, "AI deck list should sort the seven 17.0 supported AI decks first"),
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


func test_existing_install_backfills_new_poison_box_card_resources_on_startup() -> String:
	var db := CardDatabaseScript.new()
	var missing_paths := [
		"user://cards/CS5aC_079.json",
		"user://cards/CSV6C_080.json",
		"user://cards/images/CS5aC/079.png",
		"user://cards/images/CSV6C/080.png",
	]
	for path: String in missing_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	db._ensure_directories()
	db._seed_bundled_user_data()

	return run_checks([
		assert_true(FileAccess.file_exists("user://cards/CS5aC_079.json"), "Upgrade seed should backfill Radiant Hisuian Sneasler card JSON for existing installs"),
		assert_true(FileAccess.file_exists("user://cards/CSV6C_080.json"), "Upgrade seed should backfill Klawf card JSON for existing installs"),
		assert_true(CardData.is_valid_card_image_file("user://cards/images/CS5aC/079.png"), "Upgrade seed should backfill Radiant Hisuian Sneasler image for existing installs"),
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
