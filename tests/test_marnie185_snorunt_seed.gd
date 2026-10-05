extends TestBase

const Database = preload("res://scripts/autoload/CardDatabase.gd")
const DECK_PATH := "res://data/bundled_user/decks/675700.json"
const NEW_UID := "CSV9.5C_043"
const OLD_UID := "CSV6C_032"


func _bundled() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH)) as Dictionary


func _count(deck: Dictionary, uid: String) -> int:
	var result := 0
	for entry: Dictionary in deck.get("cards", []):
		if str(entry.get("set_code", "")) + "_" + str(entry.get("card_index", "")) == uid:
			result += int(entry.get("count", 0))
	return result


func _legacy() -> Dictionary:
	var deck := _bundled().duplicate(true)
	for entry: Dictionary in deck["cards"]:
		if str(entry.get("name", "")) == "雪童子":
			entry["set_code"] = "CSV6C"
			entry["card_index"] = "032"
			entry["effect_id"] = "5e06feeca2c0f59fc31f10534bce6844"
	return deck


func test_bundled_exact_requested_print_and_sixty_cards() -> String:
	var deck := _bundled()
	var total := 0
	for entry: Dictionary in deck["cards"]:
		total += int(entry["count"])
	return run_checks([
		assert_eq(_count(deck, NEW_UID), 3, "675700 must contain three CSV9.5C/043 Snorunt"),
		assert_eq(_count(deck, OLD_UID), 0, "The old printing must leave this deck"),
		assert_eq(_count(deck, "CSV7C_057"), 0, "The superseded user correction must not be applied"),
		assert_eq(total, 60, "The corrected deck must remain 60 cards"),
		assert_eq(deck["import_date"], "2026-09-19T21:26:44", "Original list ordering must be retained"),
	])


func test_untouched_existing_seed_migrates_and_is_idempotent() -> String:
	var db := Database.new()
	var deck := _legacy()
	var original_date: String = deck["import_date"]
	deck["strategy"] = "user-authored notes"
	var changed: bool = db._merge_bundled_deck_migrations(_bundled(), deck)
	var result := run_checks([
		assert_true(changed, "Existing untouched 675700 seeds must migrate"),
		assert_eq(_count(deck, NEW_UID), 3, "Migration must replace the exact three entries"),
		assert_eq(_count(deck, OLD_UID), 0, "Migration must remove the old printing"),
		assert_eq(deck["strategy"], "user-authored notes", "User notes must survive"),
		assert_eq(deck["import_date"], original_date, "Migration must not reorder the deck list"),
		assert_false(db._merge_bundled_deck_migrations(_bundled(), deck), "Migration must be idempotent"),
	])
	db.free()
	return result


func test_migration_uses_print_identity_after_card_reordering() -> String:
	var db := Database.new()
	var deck := _legacy()
	(deck["cards"] as Array).reverse()
	var changed: bool = db._merge_bundled_deck_migrations(_bundled(), deck)
	var result := run_checks([
		assert_true(changed, "List order must not determine migration"),
		assert_eq(_count(deck, NEW_UID), 3, "Reordered entries retain the replacement count"),
	])
	db.free()
	return result


func test_newer_player_saved_deck_is_preserved() -> String:
	var db := Database.new()
	var deck := _legacy()
	deck["updated_at"] = int(deck["updated_at"]) + 1
	var before := deck.duplicate(true)
	var changed: bool = db._merge_bundled_deck_migrations(_bundled(), deck)
	var result := run_checks([
		assert_false(changed, "A newer player-selected printing must be preserved"),
		assert_eq(deck, before, "Player deck must remain byte-semantically unchanged"),
	])
	db.free()
	return result


func test_other_deck_ids_and_other_printings_are_not_replaced() -> String:
	var db := Database.new()
	var deck := _legacy()
	deck["id"] = 646600
	var before := deck.duplicate(true)
	var checks: Array[String] = [
		assert_false(db._merge_bundled_deck_migrations(_bundled(), deck), "Another deck is not this migration"),
		assert_eq(deck, before, "Another deck's cards must be preserved"),
	]
	deck = _legacy()
	for entry: Dictionary in deck["cards"]:
		if str(entry.get("name", "")) == "雪童子":
			entry["set_code"] = "CSV7C"
			entry["card_index"] = "057"
	before = deck.duplicate(true)
	checks.append(assert_false(db._merge_bundled_deck_migrations(_bundled(), deck), "Other Snorunt printings are not matched by name"))
	checks.append(assert_eq(deck, before, "Wrong-print negative gate must preserve the original deck"))
	db.free()
	return run_checks(checks)


func test_missing_replacement_does_not_drop_cards() -> String:
	var db := Database.new()
	var deck := _legacy()
	var missing := _legacy()
	var before := deck.duplicate(true)
	var result := run_checks([
		assert_false(db._merge_bundled_deck_migrations(missing, deck), "Missing target printing must fail closed"),
		assert_eq(deck, before, "Failed migration must not consume cards"),
	])
	db.free()
	return result


func test_fresh_player_and_ai_catalog_use_requested_print() -> String:
	var db := Database.new()
	db._ensure_directories()
	db._seed_bundled_user_data()
	var checks: Array[String] = []
	for deck: DeckData in [db.get_deck(675700), db.get_ai_deck(675700)]:
		checks.append(assert_not_null(deck, "Player and AI catalog entries must resolve"))
		if deck == null:
			continue
		checks.append(assert_eq(_count({"cards": deck.cards}, NEW_UID), 3, "Player/AI deck must use the exact new printing"))
		var instances: Array[CardInstance] = db.build_deck_instances(deck, 0)
		var snorunt_count := 0
		for instance: CardInstance in instances:
			if instance.card_data.get_uid() == NEW_UID:
				snorunt_count += 1
		checks.append(assert_eq(instances.size(), 60, "Both catalogs must build complete battle decks"))
		checks.append(assert_eq(snorunt_count, 3, "Battle instances must use the requested printing"))
	var card: CardData = db.get_card("CSV9.5C", "043")
	checks.append(assert_not_null(card, "Requested printing must resolve from the offline card catalog"))
	if card != null:
		checks.append(assert_eq(card.hp, 60, "Printed HP"))
		checks.append(assert_eq(card.retreat_cost, 1, "Printed retreat cost"))
		checks.append(assert_eq(str(card.attacks[0].cost), "WC", "Printed attack cost must include Water"))
	db.free()
	return run_checks(checks)
