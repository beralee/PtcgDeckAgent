class_name TestTournamentSeries59CardContent
extends TestBase

const Database := preload("res://scripts/autoload/CardDatabase.gd")
const FIXTURE := "res://tests/fixtures/tournament_series59_20261004_cards.json"


func test_missing_tournament_printings_are_bundled_and_registered() -> String:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var database := Database.new()
	var manifest := database._load_bundled_manifest()
	var checks: Array[String] = []
	CardImplementationStatus.clear_cache()
	for row: Dictionary in fixture.cards:
		var uid := str(row.uid)
		var parts := uid.split("_", true, 1)
		var card: CardData = database.get_card(parts[0], parts[1])
		checks.append(assert_not_null(card, uid + " must load from the real database"))
		checks.append(assert_true("res://data/bundled_user/cards/%s.json" % uid in manifest, uid + " must be in the bundled manifest"))
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [parts[0], parts[1]]
		checks.append(assert_true(image_path in manifest, uid + " image must be listed"))
		checks.append(assert_true(FileAccess.file_exists(image_path), uid + " image must exist"))
		if card == null:
			continue
		checks.append(assert_eq(card.get_uid(), uid, uid + " exact printing identity"))
		checks.append(assert_eq(card.name, str(row.name), uid + " source name"))
		checks.append(assert_eq(card.effect_id, str(row.effect_id), uid + " source effect ID"))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), uid + ": " + CardImplementationStatus.get_reason(card)))
	database.free()
	return run_checks(checks)
