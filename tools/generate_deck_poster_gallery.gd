extends SceneTree

const DeckPosterComposerScript := preload("res://scripts/deck_share/DeckPosterComposer.gd")
const DeckShareImageScannerScript := preload("res://scripts/deck_share/DeckShareImageScanner.gd")

const OUTPUT_DIR := "res://tmp/deck_poster_gallery"
const DECKS := [
	{"id": "610080", "slug": "gardevoir"},
	{"id": "1700009", "slug": "dragapult_charizard"},
	{"id": "620753", "slug": "gholdengo"},
	{"id": "1750001", "slug": "archaludon"},
	{"id": "620761", "slug": "raging_bolt"},
	{"id": "1750005", "slug": "slowking_box"},
	{"id": "800018502", "slug": "ns_zoroark"},
	{"id": "1750003", "slug": "miraidon"},
]


func _initialize() -> void:
	call_deferred("_generate_gallery")


func _generate_gallery() -> void:
	var card_database := root.get_node_or_null("CardDatabase")
	var absolute_output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	var failed := false
	for spec: Dictionary in DECKS:
		var deck_path := "res://data/bundled_user/decks/%s.json" % str(spec.get("id", ""))
		var file := FileAccess.open(deck_path, FileAccess.READ)
		if file == null:
			push_error("Missing deck fixture: %s" % deck_path)
			failed = true
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is not Dictionary:
			push_error("Invalid deck fixture: %s" % deck_path)
			failed = true
			continue
		var deck := DeckData.from_dict(parsed)
		var result: Dictionary = await DeckPosterComposerScript.compose_desktop_overview_image(deck, "PTCG Train", card_database)
		var image: Image = result.get("image", null)
		if not bool(result.get("ok", false)) or image == null:
			push_error("Desktop overview export failed for %s: %s" % [deck.deck_name, result.get("errors", [])])
			failed = true
			continue
		var output_path := "%s/%s_desktop.png" % [OUTPUT_DIR, str(spec.get("slug", "deck"))]
		var save_error := image.save_png(output_path)
		var scanned := DeckShareImageScannerScript.scan_image(image)
		var profile := DeckPosterComposerScript._poster_visual_profile_for_tests(deck, card_database)
		var hero_names := PackedStringArray()
		for raw: Variant in profile.get("hero_entries", []):
			hero_names.append(CardData.dictionary_display_name(raw as Dictionary))
		print("DECK_IMAGE_GALLERY ", output_path, " | ", deck.deck_name, " | ", profile.get("composition", ""), " | ", ", ".join(hero_names), " | size=", image.get_size(), " | scan=", bool(scanned.get("ok", false)))
		if save_error != OK or image.get_size() != DeckPosterComposerScript.DESKTOP_OVERVIEW_OUTPUT_SIZE or bool(scanned.get("ok", false)):
			failed = true

		var mobile_result: Dictionary = await DeckPosterComposerScript.compose_image(deck, "PTCG Train", "", "0.5.0", "gallery", card_database)
		var mobile_image: Image = mobile_result.get("image", null)
		if not bool(mobile_result.get("ok", false)) or mobile_image == null:
			push_error("Mobile share export failed for %s: %s" % [deck.deck_name, mobile_result.get("errors", [])])
			failed = true
			continue
		var mobile_output_path := "%s/%s_mobile.png" % [OUTPUT_DIR, str(spec.get("slug", "deck"))]
		var mobile_save_error := mobile_image.save_png(mobile_output_path)
		var mobile_scanned := DeckShareImageScannerScript.scan_image(mobile_image)
		print("DECK_IMAGE_GALLERY ", mobile_output_path, " | ", deck.deck_name, " | size=", mobile_image.get_size(), " | scan=", bool(mobile_scanned.get("ok", false)))
		if mobile_save_error != OK or not bool(mobile_scanned.get("ok", false)):
			failed = true
	quit(1 if failed else 0)
