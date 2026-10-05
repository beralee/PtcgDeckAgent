extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const StrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ROOT := "res://data/bundled_user/decks"
const PLAYER_ONLY_PATH := "res://tests/fixtures/bundled_player_only_decks.json"


func test_ai_catalog_and_visible_picker_follow_bundled_import_dates() -> String:
	var inventory := _read_inventory()
	var expected_ids := _expected_ai_ids(inventory)
	# Independent oracle from shipped metadata, not the runtime comparator.
	expected_ids.sort_custom(func(a: int, b: int) -> bool:
		var a_date := str(inventory[_deck_path(a)].get("import_date", ""))
		var b_date := str(inventory[_deck_path(b)].get("import_date", ""))
		return a > b if a_date == b_date else a_date > b_date
	)
	var checks: Array[String] = []
	for deck_id: int in expected_ids:
		checks.append(assert_true(str(inventory[_deck_path(deck_id)].get("import_date", "")) != "", "AI bundle must declare its original import date: %d" % deck_id))
	var loaded_ids: Array[int] = []
	for deck: DeckData in CardDatabase.get_all_ai_decks():
		loaded_ids.append(deck.id)
	checks.append(assert_eq(loaded_ids, expected_ids, "AI catalog must be newest-import-first, without strength or version pinning"))
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	var mode := scene.find_child("ModeOption", true, false) as OptionButton
	mode.select(1)
	scene.call("_on_mode_changed", 1)
	var options := scene.find_child("Deck2Option", true, false) as OptionButton
	var option_ids: Array[int] = []
	for index: int in options.item_count:
		option_ids.append(int(options.get_item_metadata(index)))
	checks.append(assert_eq(option_ids, expected_ids, "AI dropdown must preserve original import chronology"))
	scene.call("_on_deck_picker_pressed", 1)
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var rendered_ids: Array[int] = []
	for child: Node in grid.get_children():
		if child is Button and child.has_meta("deck_id"):
			rendered_ids.append(int(child.get_meta("deck_id")))
	checks.append(assert_eq(rendered_ids, expected_ids, "Actual AI buttons must render newest imports first"))
	for category: String in ["all", "recent"]:
		var filtered_ids: Array[int] = []
		for deck: DeckData in scene.call("_decks_for_picker", 1, category, ""):
			filtered_ids.append(deck.id)
		checks.append(assert_eq(filtered_ids, expected_ids, "AI %s category must preserve chronology" % category))
	scene.free()
	return run_checks(checks)


func test_ai_import_order_ignores_strength_version_and_later_edits() -> String:
	var older := DeckData.from_dict({"id": 800018500, "deck_name": "18.0 Ranked deck", "import_date": "2026-09-18T23:59:59", "updated_at": 9999999999999})
	var newer := DeckData.from_dict({"id": 675899, "deck_name": "19.0 Future import", "import_date": "2026-09-19T00:00:01", "updated_at": 1})
	var same_time := DeckData.from_dict({"id": 675834, "import_date": newer.import_date})
	var undated := DeckData.from_dict({"id": 800018501, "deck_name": "18.0 Undated deck", "updated_at": 9999999999999})
	var db := CardDatabaseScript.new()
	db._ai_deck_cache = {older.id: older, newer.id: newer, same_time.id: same_time, undated.id: undated}
	db._ai_deck_cache_complete = true
	var ids: Array[int] = []
	for deck: DeckData in db.get_all_ai_decks():
		ids.append(deck.id)
	db.free()
	return assert_eq(ids, [675899, 675834, 800018500, 800018501], "Import date owns ordering; equal dates use descending ID and missing dates sort last")


func test_unregistered_bundled_decks_cannot_inherit_llm_from_card_names() -> String:
	var registry := StrategyRegistryScript.new()
	var checks: Array[String] = []
	for deck: DeckData in CardDatabase.get_all_ai_decks():
		if StrategyRegistryScript.strategy_id_for_deck_id(deck.id) != "":
			continue
		var inferred_base := registry.resolve_strategy_id_for_deck(deck)
		checks.append(assert_eq(StrategyRegistryScript.llm_strategy_id_for_deck(deck.id, inferred_base), "", "No explicit adaptation: inferred family must not grant LLM support to %d" % deck.id))
	checks.append(assert_eq(StrategyRegistryScript.llm_strategy_id_for_deck(990018501, "gardevoir"), "", "A future unregistered deck must not inherit a known LLM family"))
	checks.append(assert_eq(StrategyRegistryScript.llm_strategy_id_for_deck(575716, "gardevoir"), "", "A registered deck must not acquire another family's LLM strategy"))
	checks.append(assert_eq(StrategyRegistryScript.llm_strategy_id_for_deck(578647, "gardevoir"), "gardevoir_llm", "Explicitly registered adaptations must remain available"))
	return run_checks(checks)


func test_every_bundled_deck_has_manifest_entry_and_explicit_ai_scope() -> String:
	return "\n".join(_catalog_errors(
		_read_inventory(), _manifest(), CardDatabase.get_supported_ai_deck_ids(), _player_only()
	))


func test_every_declared_ai_deck_loads_its_exact_bundled_list() -> String:
	var inventory := _read_inventory()
	var expected_ids := _expected_ai_ids(inventory)
	var db := CardDatabaseScript.new()
	var loaded := db.get_all_ai_decks()
	var loaded_ids: Array[int] = []
	var checks: Array[String] = []
	for deck: DeckData in loaded:
		loaded_ids.append(deck.id)
		var path := _deck_path(deck.id)
		checks.append(assert_true(inventory.has(path), "AI deck must come from a bundled file: %s" % path))
		if not inventory.has(path) or not inventory[path] is Dictionary:
			continue
		var bundled := DeckData.from_dict(inventory[path])
		checks.append(assert_eq(deck.to_dict(), bundled.to_dict(), "AI loader must preserve the exact bundled list: %s" % path))
		checks.append(assert_eq(db.build_deck_instances(deck, 1).size(), 60, "AI deck must materialize 60 cards: %s" % path))
	loaded_ids.sort()
	checks.append(assert_eq(loaded_ids, expected_ids, "The AI loader must include every bundled deck except explicit player-only exceptions"))
	db.free()
	return run_checks(checks)


func test_every_declared_ai_deck_has_a_selectable_opponent_button() -> String:
	# Derive expectations from files and explicit exceptions, never from the
	# shortlist being tested. This covers future IDs and release-name prefixes.
	var expected_ids := _expected_ai_ids(_read_inventory())
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	var mode := scene.find_child("ModeOption", true, false) as OptionButton
	mode.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_on_deck_picker_pressed", 1)
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var buttons := {}
	var rendered_ids: Array[int] = []
	for child: Node in grid.get_children() if grid != null else []:
		if child is Button and child.has_meta("deck_id"):
			var deck_id := int(child.get_meta("deck_id"))
			rendered_ids.append(deck_id)
			buttons[deck_id] = child
	rendered_ids.sort()
	var checks: Array[String] = [
		assert_eq(rendered_ids, expected_ids, "AI opponent buttons must cover the complete declared bundle, without duplicates or a display cutoff"),
	]
	for deck_id: int in expected_ids:
		if not buttons.has(deck_id):
			continue
		var button := buttons[deck_id] as Button
		button.pressed.emit()
		var selected := scene.call("_selected_deck_for_slot", 1) as DeckData
		checks.append(assert_eq(selected.id if selected != null else -1, deck_id, "AI opponent button must select deck %d" % deck_id))
	scene.free()
	return run_checks(checks)


func test_guard_rejects_removing_any_registered_ai_deck() -> String:
	var ai_ids: Array[int] = CardDatabase.get_supported_ai_deck_ids()
	var inventory := _read_inventory()
	var manifest := _manifest()
	var player_only := _player_only()
	for deck_id: int in ai_ids:
		var incomplete := ai_ids.duplicate()
		incomplete.erase(deck_id)
		var errors := "\n".join(_catalog_errors(inventory, manifest, incomplete, player_only))
		if not errors.contains("unclassified_deck: %s" % _deck_path(deck_id)):
			return "Guard failed to reject omitted AI registration %d: %s" % [deck_id, errors]
	return ""


func test_guard_rejects_new_bundle_file_even_when_manifest_and_ai_both_omit_it() -> String:
	var inventory := _read_inventory()
	var future_id := 990018501
	while inventory.has(_deck_path(future_id)):
		future_id += 1
	var path := _deck_path(future_id)
	inventory[path] = {"id": future_id, "deck_name": "Future bundled deck"}
	var errors := "\n".join(_catalog_errors(inventory, _manifest(), CardDatabase.get_supported_ai_deck_ids(), _player_only()))
	return run_checks([
		assert_str_contains(errors, "deck_missing_manifest: %s" % path),
		assert_str_contains(errors, "unclassified_deck: %s" % path),
	])


func test_guard_rejects_missing_files_duplicate_ids_and_stale_exceptions() -> String:
	var path := _deck_path(101)
	var inventory := {path: {"id": 101, "deck_name": "Fixture"}}
	var manifest: Array[String] = [path, _deck_path(202)]
	var ai_ids: Array[int] = [101, 101, 202]
	var exceptions := {"101": {"reason": ""}, "303": {"reason": "Removed player-only fixture"}}
	var errors := "\n".join(_catalog_errors(inventory, manifest, ai_ids, exceptions))
	return run_checks([
		assert_str_contains(errors, "manifest_missing_deck: %s" % _deck_path(202)),
		assert_str_contains(errors, "duplicate_ai_id: 101"),
		assert_str_contains(errors, "ai_missing_bundle: 202"),
		assert_str_contains(errors, "conflicting_scope: %s" % path),
		assert_str_contains(errors, "player_only_reason_missing: 101"),
		assert_str_contains(errors, "stale_player_only_exception: 303"),
	])


func test_guard_rejects_missing_manifest_entries_and_mismatched_file_identity() -> String:
	var path := _deck_path(101)
	var nested_path := DECK_ROOT.path_join("nested/202.json")
	var inventory := {path: {"id": 999}, nested_path: {"id": 202}}
	var manifest: Array[String] = [nested_path, nested_path]
	var ai_ids: Array[int] = [101, 202]
	var errors := "\n".join(_catalog_errors(inventory, manifest, ai_ids, {}))
	return run_checks([
		assert_str_contains(errors, "deck_missing_manifest: %s" % path),
		assert_str_contains(errors, "deck_identity_mismatch: %s" % path),
		assert_str_contains(errors, "deck_identity_mismatch: %s" % nested_path),
		assert_str_contains(errors, "duplicate_manifest_deck: %s" % nested_path),
	])


func _read_inventory() -> Dictionary:
	var inventory := {}
	var db := CardDatabaseScript.new()
	var paths: Array[String] = db._scan_bundled_dir_recursive(DECK_ROOT)
	db.free()
	for path: String in paths:
		if path.ends_with(".json"):
			inventory[path] = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix("\uFEFF"))
	return inventory


func _manifest() -> Array[String]:
	assert(FileAccess.file_exists(CardDatabaseScript.BUNDLED_MANIFEST), "Bundled deck verification requires the real export manifest, not the editor fallback")
	var db := CardDatabaseScript.new()
	var entries: Array[String] = db._load_bundled_manifest()
	db.free()
	return entries


func _player_only() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAYER_ONLY_PATH))
	assert(parsed is Dictionary, "Explicit player-only exceptions must be readable JSON")
	return parsed as Dictionary


func _expected_ai_ids(inventory: Dictionary) -> Array[int]:
	var player_only := _player_only()
	var result: Array[int] = []
	for path: String in inventory:
		var deck_id := int(path.get_file().trim_suffix(".json"))
		if not player_only.has(str(deck_id)):
			result.append(deck_id)
	result.sort()
	return result


func _deck_path(deck_id: int) -> String:
	return DECK_ROOT.path_join("%d.json" % deck_id)


func _catalog_errors(inventory: Dictionary, manifest: Array[String], ai_ids: Array[int], player_only: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if inventory.is_empty():
		errors.append("empty_bundle: cannot verify deck discovery")
	var manifest_decks := {}
	for path: String in manifest:
		if not path.begins_with(DECK_ROOT + "/"):
			continue
		if manifest_decks.has(path):
			errors.append("duplicate_manifest_deck: %s" % path)
		manifest_decks[path] = true
		if not inventory.has(path):
			errors.append("manifest_missing_deck: %s" % path)
	for path: String in inventory:
		var payload: Variant = inventory[path]
		if not payload is Dictionary:
			errors.append("invalid_deck_json: %s" % path)
			continue
		var deck_id := int(path.get_file().trim_suffix(".json"))
		if deck_id <= 0 or path != _deck_path(deck_id) or int(payload.get("id", 0)) != deck_id:
			errors.append("deck_identity_mismatch: %s" % path)
		if not manifest_decks.has(path):
			errors.append("deck_missing_manifest: %s" % path)
		var is_ai := deck_id in ai_ids
		var is_player_only := player_only.has(str(deck_id))
		if not is_ai and not is_player_only:
			errors.append("unclassified_deck: %s (%s); register in CardDatabase.SUPPORTED_AI_DECK_IDS or document an explicit player-only reason in %s" % [path, payload.get("deck_name", ""), PLAYER_ONLY_PATH])
		if is_ai and is_player_only:
			errors.append("conflicting_scope: %s" % path)
	var seen_ai := {}
	for deck_id: int in ai_ids:
		if seen_ai.has(deck_id):
			errors.append("duplicate_ai_id: %d" % deck_id)
		seen_ai[deck_id] = true
		if not inventory.has(_deck_path(deck_id)):
			errors.append("ai_missing_bundle: %d" % deck_id)
	for id_text: String in player_only:
		var exception: Variant = player_only[id_text]
		if not id_text.is_valid_int() or str(int(id_text)) != id_text or not inventory.has(_deck_path(int(id_text))):
			errors.append("stale_player_only_exception: %s" % id_text)
		if not exception is Dictionary or str(exception.get("reason", "")).strip_edges() == "":
			errors.append("player_only_reason_missing: %s" % id_text)
	return errors
