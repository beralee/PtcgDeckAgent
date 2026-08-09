class_name TestCardCatalogIndex
extends TestBase

const CardCatalogIndexScript := preload("res://scripts/card_catalog/CardCatalogIndex.gd")


func test_default_catalog_loads_and_searches_without_materializing_sets() -> String:
	var catalog := CardCatalogIndexScript.new()
	var before_sets := catalog.materialized_set_count_for_tests()
	var results: Array[Dictionary] = catalog.search_cards("CS5aC", {}, 10, 0)
	var after_sets := catalog.materialized_set_count_for_tests()

	return run_checks([
		assert_true(catalog.is_ready(), "Bundled card catalog should load"),
		assert_eq(catalog.get_catalog_version(), "2026.08.02.1", "Bundled catalog version should match the generated snapshot"),
		assert_true(catalog.has_card("CS5aC", "107"), "Bundled catalog should include existing bundled cards"),
		assert_true(results.size() > 0, "Catalog search should return index rows"),
		assert_eq(before_sets, 0, "Catalog should not materialize set files on construction"),
		assert_eq(after_sets, 0, "Catalog search should not materialize full CardData set files"),
	])


func test_catalog_search_entry_keeps_tera_marker_without_materializing_set() -> String:
	var catalog := CardCatalogIndexScript.new()
	var before_sets := catalog.materialized_set_count_for_tests()
	var entry := catalog.get_entry("CSV8C", "028")
	var after_sets := catalog.materialized_set_count_for_tests()

	return run_checks([
		assert_eq(str(entry.get("name", "")), "厄诡椪 碧草面具ex", "Fixture should resolve the expected Tera Pokemon ex"),
		assert_eq(str(entry.get("ancient_trait", "")), "Tera", "Search index rows must preserve the Tera marker"),
		assert_eq(before_sets, 0, "Tera metadata check should start without materialized set files"),
		assert_eq(after_sets, 0, "Tera metadata must be available directly from the search index"),
	])


func test_catalog_lazy_loads_full_card_data_from_set_file() -> String:
	var catalog := CardCatalogIndexScript.new()
	var before_sets := catalog.materialized_set_count_for_tests()
	var card: CardData = catalog.get_card_data("CS5aC", "107")
	var after_sets := catalog.materialized_set_count_for_tests()

	return run_checks([
		assert_eq(before_sets, 0, "Fixture should start without loaded set files"),
		assert_not_null(card, "Catalog should lazily load a full CardData record"),
		assert_eq(card.get_uid() if card != null else "", "CS5aC_107", "Lazy-loaded card should keep uid"),
		assert_eq(after_sets, 1, "Loading one card should materialize only its set file"),
	])


func test_catalog_finds_entries_by_source_ref_without_materializing_sets() -> String:
	var bundled_root := "res://.godot_test_user/catalog_source_bundled"
	var user_root := "res://.godot_test_user/catalog_source_user"
	_remove_dir_recursive(bundled_root)
	_remove_dir_recursive(user_root)
	_write_catalog_fixture(bundled_root, "catalog_manifest.json", "1.0.0", "Bundled Card", true)

	var catalog := CardCatalogIndexScript.new(bundled_root, user_root)
	var before_sets := catalog.materialized_set_count_for_tests()
	var entries: Array[Dictionary] = catalog.find_entries_by_source_ref("SRC", "123")
	var after_sets := catalog.materialized_set_count_for_tests()

	_remove_dir_recursive(bundled_root)
	_remove_dir_recursive(user_root)

	return run_checks([
		assert_eq(entries.size(), 1, "Catalog should find source-print index rows"),
		assert_eq(str(entries[0].get("uid", "")) if not entries.is_empty() else "", "TCAT_001", "Source ref should resolve to the expected card uid"),
		assert_eq(before_sets, 0, "Source ref search should start without materialized set files"),
		assert_eq(after_sets, 0, "Source ref search should not materialize set files"),
	])


func test_newer_remote_catalog_cache_overrides_bundled_and_bad_remote_rolls_back() -> String:
	var bundled_root := "res://.godot_test_user/catalog_bundled"
	var user_root := "res://.godot_test_user/catalog_user"
	_remove_dir_recursive(bundled_root)
	_remove_dir_recursive(user_root)
	_write_catalog_fixture(bundled_root, "catalog_manifest.json", "1.0.0", "Bundled Card", true)
	_write_catalog_fixture(user_root, "remote_manifest.json", "2.0.0", "Remote Card", true)

	var remote_catalog := CardCatalogIndexScript.new(bundled_root, user_root)
	var remote_card: CardData = remote_catalog.get_card_data("TCAT", "001")

	_write_catalog_fixture(user_root, "remote_manifest.json", "3.0.0", "Broken Remote", false)
	var fallback_catalog := CardCatalogIndexScript.new(bundled_root, user_root)
	var fallback_card: CardData = fallback_catalog.get_card_data("TCAT", "001")

	_remove_dir_recursive(bundled_root)
	_remove_dir_recursive(user_root)

	return run_checks([
		assert_eq(remote_catalog.get_active_root_for_tests(), user_root, "Newer valid remote cache should be selected"),
		assert_eq(str(remote_card.name if remote_card != null else ""), "Remote Card", "Remote catalog card should be loaded"),
		assert_eq(fallback_catalog.get_active_root_for_tests(), bundled_root, "Invalid remote cache should fall back to bundled catalog"),
		assert_eq(str(fallback_card.name if fallback_card != null else ""), "Bundled Card", "Fallback catalog should load bundled card"),
	])


func test_legacy_remote_catalog_without_tera_search_schema_falls_back() -> String:
	var bundled_root := "res://.godot_test_user/catalog_schema_bundled"
	var user_root := "res://.godot_test_user/catalog_schema_user"
	_remove_dir_recursive(bundled_root)
	_remove_dir_recursive(user_root)
	_write_catalog_fixture(bundled_root, "catalog_manifest.json", "1.0.0", "Bundled Card", true, 2)
	_write_catalog_fixture(user_root, "remote_manifest.json", "2.0.0", "Legacy Remote", true, 1)

	var catalog := CardCatalogIndexScript.new(bundled_root, user_root)
	var card: CardData = catalog.get_card_data("TCAT", "001")

	_remove_dir_recursive(bundled_root)
	_remove_dir_recursive(user_root)
	return run_checks([
		assert_eq(catalog.get_active_root_for_tests(), bundled_root, "A remote catalog without Tera search metadata must be ignored"),
		assert_eq(str(card.name if card != null else ""), "Bundled Card", "Schema fallback should keep the bundled card searchable"),
	])


func _write_catalog_fixture(root: String, manifest_name: String, version: String, card_name: String, valid_index: bool, schema_version: int = 2) -> void:
	_make_dir_recursive(root.path_join("sets"))
	var card_dict := {
		"name": card_name,
		"name_en": card_name,
		"name_zh": card_name,
		"card_type": "Pokemon",
		"ancient_trait": "",
		"stage": "Basic",
		"hp": 70,
		"set_code": "TCAT",
		"card_index": "001",
		"set_code_en": "SRC",
		"card_index_en": "123",
		"source_prints": ["SRC/123"],
		"attacks": [{"name": "Test", "text": "", "cost": "", "damage": "10"}],
	}
	var set_payload := {"schema_version": 1, "set_code": "TCAT", "cards": [card_dict]}
	_write_text(root.path_join("sets/TCAT.json"), JSON.stringify(set_payload, "\t"))
	var cards := [] if not valid_index else [{
		"uid": "TCAT_001",
		"set_code": "TCAT",
		"card_index": "001",
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
		"set_file": "sets/TCAT.json",
	}]
	var index_payload := {"schema_version": schema_version, "catalog_version": version, "cards": cards}
	_write_text(root.path_join("index.json"), JSON.stringify(index_payload, "\t"))
	var manifest := {
		"schema_version": schema_version,
		"catalog_version": version,
		"card_count": cards.size(),
		"index_file": {"path": "index.json", "sha256": ""},
		"sets": [{"set_code": "TCAT", "path": "sets/TCAT.json", "card_count": 1, "sha256": ""}],
		"sources": [],
	}
	_write_text(root.path_join(manifest_name), JSON.stringify(manifest, "\t"))


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
