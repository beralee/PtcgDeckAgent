class_name TestT3178Top64MissingCardsStatus
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")

const TARGET_CARDS := [
	"151C_081",
	"CSV6C_118",
	"CSV6C_080",
	"CS5aC_079",
	"CS5bC_113",
	"CS5.5C_003",
	"CS5aC_118",
	"CSV7C_159",
	"CSV6C_095",
	"151C_016",
	"CSV8C_161",
	"CSV8C_205",
	"CS6bC_035",
	"CSV2C_036",
	"CS5aC_116",
	"CSV7C_142",
	"SVP_144",
	"CSV9C_055",
	"CS5DC_147",
	"CSV8C_119",
	"CSV5C_009",
	"CS5.5C_054",
	"CSVL1C_045",
]


func test_t3178_top64_missing_cards_are_bundled_and_implemented() -> String:
	CardImplementationStatus.clear_cache()
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var checks: Array[String] = []
	var seen := {}

	for uid_variant: Variant in TARGET_CARDS:
		var uid := str(uid_variant)
		var parts := uid.split("_", true, 1)
		checks.append(assert_eq(parts.size(), 2, "%s should use set_index uid format" % uid))
		if parts.size() != 2:
			continue

		var set_code := str(parts[0])
		var card_index := str(parts[1])
		var json_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		seen[uid] = true

		checks.append(assert_true(json_path in manifest, "%s JSON should be listed in bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(json_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled image should exist" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase from bundled install data" % uid))
		if card == null:
			continue

		checks.append(assert_eq(card.get_uid(), uid, "%s should preserve set/index identity after load" % uid))
		checks.append(assert_false(
			CardImplementationStatus.is_unimplemented(card),
			"%s should not show unimplemented badge: %s" % [uid, CardImplementationStatus.get_reason(card)]
		))

	checks.append(assert_eq(seen.size(), TARGET_CARDS.size(), "Target card list should not contain duplicates"))
	return run_checks(checks)
