class_name TestCardDatabaseCatalogFallback
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const CardCatalogIndexScript := preload("res://scripts/card_catalog/CardCatalogIndex.gd")


func test_card_database_resolves_catalog_only_card_without_writing_user_card_json() -> String:
	var root := "res://.godot_test_user/db_catalog_only"
	_remove_dir_recursive(root)
	_write_catalog_fixture(root, "CATONLY", "900", "Catalog Only Card")
	var user_path := "user://cards/CATONLY_900.json"
	if FileAccess.file_exists(user_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(user_path))

	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db.set_card_catalog_index_for_tests(CardCatalogIndexScript.new(root, "res://.godot_test_user/unused_user_catalog"))
	db.clear_card_cache_for_tests()

	var has_card := db.has_card("CATONLY", "900")
	var card: CardData = db.get_card("CATONLY", "900")
	var user_file_exists := FileAccess.file_exists(user_path)

	db.free()
	_remove_dir_recursive(root)

	return run_checks([
		assert_true(has_card, "CardDatabase.has_card should recognize catalog-only cards"),
		assert_not_null(card, "CardDatabase.get_card should load catalog-only cards"),
		assert_eq(str(card.name if card != null else ""), "Catalog Only Card", "Catalog fallback should preserve full card data"),
		assert_false(user_file_exists, "Catalog fallback should not materialize card JSON into user://cards"),
	])


func test_card_database_user_card_overrides_catalog_card() -> String:
	var root := "res://.godot_test_user/db_catalog_user_priority"
	_remove_dir_recursive(root)
	_write_catalog_fixture(root, "CATPRI", "001", "Catalog Card")
	var user_path := "user://cards/CATPRI_001.json"
	var user_payload := {
		"name": "User Card",
		"name_en": "User Card",
		"card_type": "Pokemon",
		"ancient_trait": "",
		"stage": "Basic",
		"hp": 80,
		"set_code": "CATPRI",
		"card_index": "001",
	}

	var db := CardDatabaseScript.new()
	db._ensure_directories()
	_write_text(user_path, JSON.stringify(user_payload, "\t"))
	db.set_card_catalog_index_for_tests(CardCatalogIndexScript.new(root, "res://.godot_test_user/unused_user_catalog"))
	db.clear_card_cache_for_tests()
	var card: CardData = db.get_card("CATPRI", "001")

	if FileAccess.file_exists(user_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(user_path))
	db.free()
	_remove_dir_recursive(root)

	return run_checks([
		assert_not_null(card, "Priority fixture should resolve a card"),
		assert_eq(str(card.name if card != null else ""), "User Card", "User card JSON should override catalog records"),
	])


func test_card_database_bundled_card_overrides_catalog_card() -> String:
	var root := "res://.godot_test_user/db_catalog_bundled_priority"
	_remove_dir_recursive(root)
	_write_catalog_fixture(root, "CS5aC", "107", "Catalog Override")
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db.set_card_catalog_index_for_tests(CardCatalogIndexScript.new(root, "res://.godot_test_user/unused_user_catalog"))
	db.clear_card_cache_for_tests()

	var card: CardData = db.get_card("CS5aC", "107")
	db.free()
	_remove_dir_recursive(root)

	return run_checks([
		assert_not_null(card, "Bundled priority fixture should resolve a card"),
		assert_true(str(card.name if card != null else "") != "Catalog Override", "Bundled/user seed card should override catalog fallback for same uid"),
	])


func test_get_all_cards_does_not_load_all_catalog_records() -> String:
	var root := "res://.godot_test_user/db_catalog_get_all"
	_remove_dir_recursive(root)
	_write_catalog_fixture(root, "CATALL", "777", "Catalog All Card")
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db.set_card_catalog_index_for_tests(CardCatalogIndexScript.new(root, "res://.godot_test_user/unused_user_catalog"))
	db.clear_card_cache_for_tests()

	var found_catalog_only := false
	for card: CardData in db.get_all_cards():
		if card != null and card.get_uid() == "CATALL_777":
			found_catalog_only = true
			break
	db.free()
	_remove_dir_recursive(root)

	return assert_false(found_catalog_only, "CardDatabase.get_all_cards should not materialize the full catalog by default")


func test_find_cards_by_source_ref_uses_catalog_without_full_materialization() -> String:
	var root := "res://.godot_test_user/db_catalog_source_ref"
	_remove_dir_recursive(root)
	_write_catalog_fixture(root, "CATSRC", "123", "Catalog Source Card")
	var catalog := CardCatalogIndexScript.new(root, "res://.godot_test_user/unused_user_catalog")
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db.set_card_catalog_index_for_tests(catalog)
	db.clear_card_cache_for_tests()

	var before_sets := catalog.materialized_set_count_for_tests()
	var cards: Array[CardData] = db.find_cards_by_source_ref("SRC", "123")
	var after_sets := catalog.materialized_set_count_for_tests()

	db.free()
	_remove_dir_recursive(root)

	return run_checks([
		assert_eq(before_sets, 0, "Source-ref lookup should start without loaded set files"),
		assert_eq(cards.size(), 1, "Source-ref lookup should resolve the catalog card"),
		assert_eq(cards[0].get_uid() if not cards.is_empty() else "", "CATSRC_123", "Resolved source-ref card uid"),
		assert_eq(after_sets, 1, "Source-ref lookup should materialize only the matched set"),
	])


func _write_catalog_fixture(root: String, set_code: String, card_index: String, card_name: String) -> void:
	_make_dir_recursive(root.path_join("sets"))
	var uid := "%s_%s" % [set_code, card_index]
	var card_dict := {
		"name": card_name,
		"name_en": card_name,
		"name_zh": card_name,
		"card_type": "Pokemon",
		"stage": "Basic",
		"hp": 70,
		"set_code": set_code,
		"card_index": card_index,
		"set_code_en": "SRC",
		"card_index_en": "123",
		"source_prints": ["SRC/123"],
		"attacks": [{"name": "Test", "text": "", "cost": "", "damage": "10"}],
	}
	var set_payload := {"schema_version": 1, "set_code": set_code, "cards": [card_dict]}
	_write_text(root.path_join("sets/%s.json" % set_code), JSON.stringify(set_payload, "\t"))
	var index_payload := {
		"schema_version": 2,
		"catalog_version": "1.0.0",
		"cards": [{
			"uid": uid,
			"set_code": set_code,
			"card_index": card_index,
			"set_code_en": "SRC",
			"card_index_en": "123",
			"source_prints": ["SRC/123"],
			"name": card_name,
			"name_en": card_name,
			"name_zh": card_name,
			"card_type": "Pokemon",
			"ancient_trait": "",
			"stage": "Basic",
			"hp": 70,
			"implementation_status": "implemented",
			"set_file": "sets/%s.json" % set_code,
		}],
	}
	_write_text(root.path_join("index.json"), JSON.stringify(index_payload, "\t"))
	var manifest := {
		"schema_version": 2,
		"catalog_version": "1.0.0",
		"card_count": 1,
		"index_file": {"path": "index.json", "sha256": ""},
		"sets": [{"set_code": set_code, "path": "sets/%s.json" % set_code, "card_count": 1, "sha256": ""}],
		"sources": [],
	}
	_write_text(root.path_join("catalog_manifest.json"), JSON.stringify(manifest, "\t"))


func _write_text(path: String, content: String) -> void:
	_make_dir_recursive(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


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
