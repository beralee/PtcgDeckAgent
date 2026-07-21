class_name TestDeckPosterComposer
extends TestBase

const DeckPosterComposerScript := preload("res://scripts/deck_share/DeckPosterComposer.gd")
const DeckShareImageScannerScript := preload("res://scripts/deck_share/DeckShareImageScanner.gd")
const DeckSharePayloadCodecScript := preload("res://scripts/deck_share/DeckSharePayloadCodec.gd")
const DeckSharePlatformAdapterScript := preload("res://scripts/deck_share/DeckSharePlatformAdapter.gd")


class FakeCardDatabase:
	extends RefCounted

	var cards: Dictionary = {}

	func add_card(card: CardData) -> void:
		cards["%s_%s" % [card.set_code, card.card_index]] = card

	func get_card(set_code: String, card_index: String) -> CardData:
		return cards.get("%s_%s" % [set_code, card_index], null)


func _make_card(set_code: String, card_index: String, card_type: String = "Basic Energy") -> CardData:
	var card := CardData.new()
	card.set_code = set_code
	card.card_index = card_index
	card.card_type = card_type
	card.name = "%s_%s" % [set_code, card_index]
	card.name_zh = card.name
	return card


func _make_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 990201
	deck.deck_name = "Poster Test"
	deck.total_cards = 60
	deck.cards.append({
		"set_code": "UTEST",
		"card_index": "001",
		"count": 30,
		"card_type": "Pokemon",
		"name": "Poster One",
	})
	deck.cards.append({
		"set_code": "UTEST",
		"card_index": "002",
		"count": 30,
		"card_type": "Basic Energy",
		"name": "Poster Two",
	})
	return deck


func _make_gardevoir_order_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 610080
	deck.deck_name = "17.5 Gardevoir"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "UTEST", "card_index": "001", "count": 1, "card_type": "Pokemon", "name_en": "Manaphy"},
		{"set_code": "UTEST", "card_index": "002", "count": 2, "card_type": "Item", "name_en": "Ultra Ball"},
		{"set_code": "UTEST", "card_index": "003", "count": 4, "card_type": "Pokemon", "name_en": "Ralts"},
		{"set_code": "UTEST", "card_index": "004", "count": 2, "card_type": "Pokemon", "name_en": "Gardevoir ex"},
		{"set_code": "UTEST", "card_index": "005", "count": 7, "card_type": "Basic Energy", "name_en": "Psychic Energy"},
		{"set_code": "UTEST", "card_index": "006", "count": 4, "card_type": "Pokemon", "name_en": "Kirlia"},
		{"set_code": "UTEST", "card_index": "007", "count": 4, "card_type": "Supporter", "name_en": "Arven"},
		{"set_code": "UTEST", "card_index": "008", "count": 36, "card_type": "Basic Energy", "name_en": "Psychic Energy"},
	]
	return deck


func _make_dual_archetype_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 990203
	deck.deck_name = "多龙巴鲁托 喷火龙"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "UTEST", "card_index": "011", "count": 3, "card_type": "Pokemon", "name": "多龙巴鲁托ex", "name_en": "Dragapult ex"},
		{"set_code": "UTEST", "card_index": "012", "count": 2, "card_type": "Pokemon", "name": "喷火龙ex", "name_en": "Charizard ex"},
		{"set_code": "UTEST", "card_index": "013", "count": 4, "card_type": "Pokemon", "name": "多龙梅西亚", "name_en": "Dreepy"},
		{"set_code": "UTEST", "card_index": "014", "count": 1, "card_type": "Pokemon", "name": "光辉喷火龙", "name_en": "Radiant Charizard"},
		{"set_code": "UTEST", "card_index": "015", "count": 4, "card_type": "Item", "name": "高级球", "name_en": "Ultra Ball"},
	]
	return deck


func _make_dense_overview_deck(unique_count: int = 28) -> DeckData:
	var deck := DeckData.new()
	deck.id = 990204
	deck.deck_name = "Desktop Overview"
	deck.total_cards = 60
	for index: int in unique_count:
		deck.cards.append({
			"set_code": "OVERVIEW",
			"card_index": "%03d" % (index + 1),
			"count": 1,
			"card_type": "Pokemon" if index < 8 else "Item",
			"name": "Overview Card %02d" % (index + 1),
		})
	return deck


func test_deck_poster_composer_outputs_dynamic_height_image() -> String:
	var db := FakeCardDatabase.new()
	db.add_card(_make_card("UTEST", "001", "Pokemon"))
	db.add_card(_make_card("UTEST", "002", "Basic Energy"))
	var result: Dictionary = await DeckPosterComposerScript.compose_image(_make_deck(), "Tester", "Poster note", "0.5.0", "test-db", db)
	var image: Image = result.get("image", null)
	var expected_layout: Dictionary = DeckPosterComposerScript._poster_layout_for_tests(2)
	var expected_size: Vector2i = expected_layout.get("output_size", Vector2i.ZERO)
	var code_rect: Rect2i = result.get("code_rect", Rect2i())
	return run_checks([
		assert_true(bool(result.get("ok", false)), "poster should compose"),
		assert_not_null(image, "poster image should exist"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, expected_size, "poster size should be calculated from the card rows and footer"),
		assert_eq(code_rect.size.x, DeckPosterComposerScript.OUTPUT_WIDTH, "poster code should span the image width"),
		assert_true(expected_size.y < DeckPosterComposerScript.LEGACY_OUTPUT_SIZE.y, "short deck posters should not keep the legacy fixed height"),
	])


func test_deck_poster_composer_desktop_overview_is_four_by_three_without_share_payload() -> String:
	var result: Dictionary = await DeckPosterComposerScript.compose_desktop_overview_image(
		_make_dense_overview_deck(21),
		"Tester",
		FakeCardDatabase.new()
	)
	var image := result.get("image", null) as Image
	return run_checks([
		assert_true(bool(result.get("ok", false)), "desktop overview should compose"),
		assert_not_null(image, "desktop overview image should exist"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(1600, 1200), "desktop overview should use a fixed 4:3 landscape canvas"),
		assert_eq(str(result.get("encoded_text", "__missing__")), "", "desktop overview should not embed a deck-share payload"),
		assert_eq(result.get("code_rect", Rect2i(-1, -1, 1, 1)), Rect2i(), "desktop overview should not reserve a QR/data-strip region"),
	])


func test_deck_poster_composer_desktop_overview_places_site_url_below_author() -> String:
	var root := Control.new()
	DeckPosterComposerScript._build_desktop_overview_template(
		root,
		_make_dense_overview_deck(21),
		"Tester",
		FakeCardDatabase.new()
	)
	var author_label := _find_label_containing(root, "Tester")
	var site_label := _find_label_by_meta(root, "deck_share_text_role", "desktop_overview_site_url")
	var checks: Array[String] = [
		assert_not_null(author_label, "desktop overview should render its author"),
		assert_not_null(site_label, "desktop overview should render the site URL"),
	]
	if author_label != null and site_label != null:
		checks.append(assert_eq(site_label.text, DeckPosterComposerScript.SITE_URL_TEXT, "desktop overview site URL text"))
		checks.append(assert_eq(int(site_label.position.x), int(author_label.position.x), "site URL should align with the author"))
		checks.append(assert_gte(int(site_label.position.y), int(author_label.position.y + author_label.size.y), "site URL should sit below the author"))
		checks.append(assert_true(int(site_label.position.y + site_label.size.y) < DeckPosterComposerScript.DESKTOP_OVERVIEW_HEADER_HEIGHT, "site URL should stay inside the header"))
	root.free()
	return run_checks(checks)


func test_deck_poster_composer_desktop_overview_fits_dense_deck_at_readable_size() -> String:
	var layout: Dictionary = DeckPosterComposerScript._desktop_overview_layout_for_tests(28)
	var metrics: Dictionary = layout.get("metrics", {})
	var image_size: Vector2i = metrics.get("image_size", Vector2i.ZERO)
	var origin: Vector2i = metrics.get("origin", Vector2i.ZERO)
	var columns := int(metrics.get("columns", 0))
	var rows := int(metrics.get("rows", 0))
	var grid_end := origin + Vector2i(
		columns * image_size.x + maxi(0, columns - 1) * int(metrics.get("column_gap", 0)),
		rows * image_size.y + maxi(0, rows - 1) * int(metrics.get("row_gap", 0))
	)
	var grid_rect: Rect2i = layout.get("grid_rect", Rect2i())
	return run_checks([
		assert_eq(columns, 7, "desktop overview should use seven columns for a full deck scan"),
		assert_eq(rows, 4, "twenty-eight unique cards should fit in four rows"),
		assert_gte(image_size.x, 145, "desktop overview cards should remain readable at dense deck counts"),
		assert_true(grid_rect.has_point(origin), "desktop card grid should begin inside its safe region"),
		assert_true(grid_end.x <= grid_rect.end.x, "desktop card grid should fit horizontally"),
		assert_true(grid_end.y <= grid_rect.end.y, "desktop card grid should fit vertically"),
	])


func test_deck_poster_composer_uses_five_column_unique_card_layout() -> String:
	var entries: Array[Dictionary] = DeckPosterComposerScript._unique_card_entries_for_tests(_make_deck())
	var metrics: Dictionary = DeckPosterComposerScript._card_grid_metrics_for_tests(entries.size())
	var image_size: Vector2i = metrics.get("image_size", Vector2i.ZERO)
	var cell_size: Vector2i = metrics.get("cell_size", Vector2i.ZERO)
	return run_checks([
		assert_eq(entries.size(), 2, "duplicate copies should collapse into unique card entries"),
		assert_eq(int(entries[0].get("count", 0)), 30, "first unique entry count"),
		assert_eq(int(entries[1].get("count", 0)), 30, "second unique entry count"),
		assert_gte(image_size.x, 200, "unique-card poster images should nearly fill the five-column phone width"),
		assert_eq(image_size.x, cell_size.x, "single-row poster cards should fill each horizontal cell"),
		assert_gte(image_size.y, 280, "unique-card poster images should be readable on phone"),
	])


func test_deck_poster_composer_orders_gardevoir_core_line_first_for_display() -> String:
	var entries: Array[Dictionary] = DeckPosterComposerScript._poster_card_entries_for_tests(_make_gardevoir_order_deck())
	var names := PackedStringArray()
	for entry: Dictionary in entries:
		names.append(str(entry.get("name_en", "")))
	return run_checks([
		assert_eq(entries.size(), 8, "poster display entries should keep unique card rows"),
		assert_eq(names[0], "Gardevoir ex", "Gardevoir ex should lead the poster for the Gardevoir archetype"),
		assert_eq(names[1], "Kirlia", "Kirlia should follow the stage-2 engine"),
		assert_eq(names[2], "Ralts", "Ralts should complete the evolution line before support cards"),
		assert_gt(names.find("Psychic Energy"), names.find("Ultra Ball"), "basic energy should stay after trainer cards in poster display order"),
	])


func test_deck_poster_composer_adaptive_visual_selects_named_main_pokemon() -> String:
	var profile: Dictionary = DeckPosterComposerScript._poster_visual_profile_for_tests(_make_gardevoir_order_deck(), FakeCardDatabase.new())
	var heroes: Array = profile.get("hero_entries", [])
	return run_checks([
		assert_gte(heroes.size(), 1, "adaptive poster should select a hero Pokemon"),
		assert_eq(str((heroes[0] as Dictionary).get("name_en", "")) if not heroes.is_empty() else "", "Gardevoir ex", "deck-name matched final evolution should become the hero"),
		assert_eq(str(profile.get("composition", "")), "single", "single-archetype deck should use one focused hero"),
		assert_true(profile.has("accent"), "adaptive poster should always provide a stable accent color"),
	])


func test_deck_poster_composer_adaptive_visual_supports_dual_archetypes() -> String:
	var profile: Dictionary = DeckPosterComposerScript._poster_visual_profile_for_tests(_make_dual_archetype_deck(), FakeCardDatabase.new())
	var heroes: Array = profile.get("hero_entries", [])
	var names := PackedStringArray()
	for raw: Variant in heroes:
		var entry: Dictionary = raw
		names.append(str(entry.get("name_en", "")))
	return run_checks([
		assert_eq(str(profile.get("composition", "")), "dual", "two named archetypes should use a dual-hero composition"),
		assert_eq(heroes.size(), 2, "dual composition should keep exactly two visual heroes"),
		assert_eq(names[0] if names.size() > 0 else "", "Dragapult ex", "dual poster should respect archetype order in the deck name"),
		assert_true(names.has("Dragapult ex"), "dual poster should include Dragapult ex"),
		assert_true(names.has("Charizard ex"), "dual poster should include Charizard ex"),
	])


func test_deck_poster_composer_places_adaptive_heroes_first_in_card_grid() -> String:
	var entries: Array[Dictionary] = DeckPosterComposerScript._poster_card_entries_for_tests(_make_dual_archetype_deck())
	return run_checks([
		assert_eq(str(entries[0].get("name_en", "")), "Dragapult ex", "primary adaptive hero should lead the card grid"),
		assert_eq(str(entries[1].get("name_en", "")), "Charizard ex", "secondary adaptive hero should follow the primary hero"),
	])


func test_deck_poster_composer_all_bundled_decks_receive_adaptive_visuals() -> String:
	var checks: Array[String] = []
	var directory := DirAccess.open("res://data/bundled_user/decks")
	if directory == null:
		return "bundled deck directory should exist"
	var files := directory.get_files()
	var deck_count := 0
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://data/bundled_user/decks/%s" % file_name, FileAccess.READ)
		if file == null:
			checks.append("unable to open bundled deck %s" % file_name)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is not Dictionary:
			checks.append("unable to parse bundled deck %s" % file_name)
			continue
		var deck := DeckData.from_dict(parsed)
		var profile: Dictionary = DeckPosterComposerScript._poster_visual_profile_for_tests(deck, FakeCardDatabase.new())
		var heroes: Array = profile.get("hero_entries", [])
		deck_count += 1
		checks.append(assert_gte(heroes.size(), 1, "%s should receive at least one Pokemon hero" % deck.deck_name))
		checks.append(assert_true(heroes.size() <= 2, "%s should keep the banner focused on at most two heroes" % deck.deck_name))
	checks.append(assert_gte(deck_count, 50, "adaptive visual coverage should include the complete bundled deck pool"))
	return run_checks(checks)


func test_deck_poster_composer_renders_duplicate_count_labels() -> String:
	var root := Control.new()
	var missing_image_count: int = DeckPosterComposerScript._add_card_grid(root, _make_deck(), FakeCardDatabase.new())
	var count_labels := PackedStringArray()
	_collect_count_labels(root, count_labels)
	root.free()
	return run_checks([
		assert_gte(missing_image_count, 1, "placeholder card images should still render count labels"),
		assert_eq(count_labels.size(), 2, "duplicate count labels"),
		assert_true(count_labels.has("X30"), "count label should use uppercase X prefix"),
	])


func test_deck_poster_composer_placeholder_uses_text_proxy_details() -> String:
	var root := Control.new()
	var db := FakeCardDatabase.new()
	var deck := DeckData.new()
	deck.deck_name = "Proxy Poster"
	deck.cards = [{
		"set_code": "PXPOSTER",
		"card_index": "901",
		"count": 2,
		"card_type": "Pokemon",
		"name": "Poster Proxy One",
	}]
	var card := _make_card("PXPOSTER", "901", "Pokemon")
	card.hp = 120
	card.energy_type = "D"
	card.attacks = [{"name": "Proxy Blow", "damage": "40", "text": "Test attack."}]
	db.add_card(card)
	var missing_image_count: int = DeckPosterComposerScript._add_card_grid(root, deck, db)
	var proxy_name := root.find_child("CardProxyLine1", true, false) as Label
	var proxy_summary := _find_label_containing(root, "Proxy Blow")
	var checks: Array[String] = [
		assert_gte(missing_image_count, 1, "missing poster images should still create placeholders"),
		assert_not_null(proxy_name, "poster placeholder should use the shared text proxy card name node"),
		assert_not_null(proxy_summary, "poster placeholder should include a readable summary line"),
	]
	if proxy_name != null:
		checks.append(assert_true(proxy_name.text.contains("PXPOSTER_901"), "poster proxy should include the resolved card display name"))
	if proxy_summary != null:
		checks.append(assert_true(proxy_summary.text.contains("Proxy Blow"), "poster proxy should include attack or ability summary"))
	root.free()
	return run_checks(checks)


func test_deck_poster_composer_places_site_url_right_of_author_with_full_width_bottom_strip() -> String:
	var root := Control.new()
	var strip_image := Image.create(860, 156, false, Image.FORMAT_RGBA8)
	strip_image.fill(Color.WHITE)
	var layout: Dictionary = DeckPosterComposerScript._poster_layout_for_tests(2)
	var code_rect: Rect2i = layout.get("code_rect", Rect2i())
	DeckPosterComposerScript._build_template(root, _make_deck(), "Tester", strip_image, FakeCardDatabase.new(), layout)
	var title_label := _find_label_by_meta(root, "deck_share_text_role", "generic_title")
	var author_label := _find_label_containing(root, "Tester")
	var site_label := _find_label_by_meta(root, "deck_share_text_role", "site_url")
	var checks: Array[String] = [
		assert_not_null(title_label, "deck title should render"),
		assert_not_null(author_label, "author line should render"),
		assert_not_null(site_label, "site URL should render in the banner"),
		assert_eq(code_rect.position.x, 0, "data strip should start at the page left edge"),
		assert_eq(code_rect.size.x, DeckPosterComposerScript.OUTPUT_WIDTH, "data strip should span the page width"),
		assert_eq(code_rect.end.y + DeckPosterComposerScript.DATA_STRIP_BOTTOM_QUIET_ZONE + DeckPosterComposerScript.BOTTOM_PADDING, int(layout.get("output_size", Vector2i.ZERO).y), "poster height should retain the data-strip scan quiet zone"),
	]
	if title_label != null:
		checks.append(assert_true(int(title_label.position.y) < DeckPosterComposerScript.BANNER_HEIGHT, "deck title should sit inside the banner"))
		checks.append(assert_eq(Vector2i(title_label.position), DeckPosterComposerScript.GENERIC_TITLE_TEXT_RECT.position, "plain deck title should use the banner title-frame anchor"))
		checks.append(assert_eq(Vector2i(title_label.size), DeckPosterComposerScript.GENERIC_TITLE_TEXT_RECT.size, "plain deck title should fit inside the banner title-frame rect"))
		checks.append(assert_eq(title_label.pivot_offset, title_label.size * 0.5, "art title scale should pivot from the text box center"))
	if author_label != null:
		checks.append(assert_true(int(author_label.position.y) < DeckPosterComposerScript.BANNER_HEIGHT, "author line should sit inside the banner"))
		checks.append(assert_gt(int(author_label.position.y), int(title_label.position.y) if title_label != null else 0, "author line should sit below the title"))
		checks.append(assert_true(int(author_label.position.y) < DeckPosterComposerScript.CARD_GRID_ORIGIN.y, "author line should stay above the card grid"))
	if site_label != null:
		checks.append(assert_eq(site_label.text, DeckPosterComposerScript.SITE_URL_TEXT, "site URL text"))
		checks.append(assert_eq(Vector2i(site_label.position), DeckPosterComposerScript.SITE_URL_TEXT_RECT.position, "site URL should use the banner URL anchor"))
		checks.append(assert_eq(site_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "site URL should align toward the page edge"))
	if author_label != null and site_label != null:
		checks.append(assert_eq(int(site_label.position.y), int(author_label.position.y), "site URL should share the author baseline"))
		checks.append(assert_gt(int(site_label.position.x), int(author_label.position.x), "site URL should sit to the author's right"))
	root.free()
	return run_checks(checks)


func test_deck_poster_composer_no_longer_exposes_manual_banner_choices() -> String:
	return run_checks([
		assert_eq(DeckPosterComposerScript.share_background_options().size(), 0, "poster styling should be automatic instead of player-selected"),
		assert_eq(DeckPosterComposerScript.default_background_id(), "auto", "automatic styling should be the only background mode"),
		assert_eq(DeckPosterComposerScript.normalize_background_id("charizard"), "auto", "legacy manual choices should normalize to automatic styling"),
		assert_false(DeckPosterComposerScript._uses_precomposed_banner("18.0 N的索罗亚克", "z"), "one-off precomposed banners should no longer bypass adaptive styling"),
		assert_eq(DeckPosterComposerScript._banner_title_parts("18.0 N的索罗亚克"), {"prefix": "18.0", "title": "N的索罗亚克"}, "18.0 deck names should keep the series prefix in the competitive banner"),
	])


func _collect_count_labels(node: Node, labels: PackedStringArray) -> void:
	for child: Node in node.get_children():
		if child is Label:
			var label := child as Label
			if label.text.begins_with("X"):
				labels.append(label.text)
		_collect_count_labels(child, labels)


func _find_label_by_text(node: Node, text: String) -> Label:
	for child: Node in node.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var nested := _find_label_by_text(child, text)
		if nested != null:
			return nested
	return null


func _find_label_containing(node: Node, needle: String) -> Label:
	for child: Node in node.get_children():
		if child is Label and (child as Label).text.contains(needle):
			return child as Label
		var nested := _find_label_containing(child, needle)
		if nested != null:
			return nested
	return null


func _find_label_by_meta(node: Node, key: StringName, expected: Variant) -> Label:
	for child: Node in node.get_children():
		if child is Label and child.has_meta(key) and child.get_meta(key) == expected:
			return child as Label
		var nested := _find_label_by_meta(child, key, expected)
		if nested != null:
			return nested
	return null


func test_deck_poster_composer_missing_images_do_not_block_export() -> String:
	var db := FakeCardDatabase.new()
	db.add_card(_make_card("UTEST", "001", "Pokemon"))
	db.add_card(_make_card("UTEST", "002", "Basic Energy"))
	var result: Dictionary = await DeckPosterComposerScript.compose_image(_make_deck(), "Tester", "", "0.5.0", "test-db", db)
	return run_checks([
		assert_true(bool(result.get("ok", false)), "missing card images should not block poster export"),
		assert_gt(int(result.get("missing_image_count", -1)), 0, "missing slots should use placeholders"),
	])


func test_deck_poster_composer_embeds_decodable_payload() -> String:
	var db := FakeCardDatabase.new()
	db.add_card(_make_card("UTEST", "001", "Pokemon"))
	db.add_card(_make_card("UTEST", "002", "Basic Energy"))
	var result: Dictionary = await DeckPosterComposerScript.compose_image(_make_deck(), "Tester", "Poster note", "0.5.0", "test-db", db)
	var image: Image = result.get("image", null)
	if image == null:
		return "poster image should exist"
	var scanned := DeckShareImageScannerScript.scan_image(image)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	var decoded := DeckSharePayloadCodecScript.decode_text(texts[0] if texts.size() > 0 else "")
	var payload: Dictionary = decoded.get("payload", {})
	var deck_payload: Dictionary = payload.get("deck", {})
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "poster code should scan"),
		assert_true(bool(decoded.get("ok", false)), "scanned payload should decode"),
		assert_eq(str(deck_payload.get("name", "")), "Poster Test", "payload deck name"),
		assert_eq(str(deck_payload.get("author", "")), "Tester", "payload author"),
	])


func test_deck_poster_composer_default_saved_png_roundtrips_through_scanner() -> String:
	var db := FakeCardDatabase.new()
	db.add_card(_make_card("UTEST", "001", "Pokemon"))
	db.add_card(_make_card("UTEST", "002", "Basic Energy"))
	var result: Dictionary = await DeckPosterComposerScript.compose_image(_make_deck(), "Tester", "Saved file", "0.5.0", "test-db", db)
	var image: Image = result.get("image", null)
	if image == null:
		return "poster image should exist"
	var saved: Dictionary = DeckSharePlatformAdapterScript.save_png_to_default_path(image, "windows_roundtrip.png")
	var path := str(saved.get("path", ""))
	var loaded := Image.new()
	var load_err := loaded.load(path) if path != "" else ERR_FILE_NOT_FOUND
	var scanned := DeckShareImageScannerScript.scan_image(loaded) if load_err == OK else {"ok": false, "texts": PackedStringArray()}
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	var decoded := DeckSharePayloadCodecScript.decode_text(texts[0] if texts.size() > 0 else "")
	var payload: Dictionary = decoded.get("payload", {})
	var deck_payload: Dictionary = payload.get("deck", {})
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return run_checks([
		assert_true(bool(saved.get("ok", false)), "default save should write poster PNG"),
		assert_eq(load_err, OK, "saved poster PNG should reload"),
		assert_true(bool(scanned.get("ok", false)), "saved poster PNG should scan"),
		assert_true(bool(decoded.get("ok", false)), "saved poster payload should decode"),
		assert_eq(str(deck_payload.get("name", "")), "Poster Test", "saved poster deck name"),
	])


func test_deck_poster_composer_ns_zoroark_height_ends_after_data_strip() -> String:
	var file := FileAccess.open("res://data/bundled_user/decks/800018502.json", FileAccess.READ)
	if file == null:
		return "18.0 N's Zoroark deck fixture should exist"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return "18.0 N's Zoroark deck fixture should parse"
	var deck := DeckData.from_dict(parsed)
	var result: Dictionary = await DeckPosterComposerScript.compose_image(deck, "z", "", "0.5.0", "test-db", FakeCardDatabase.new())
	var image: Image = result.get("image", null)
	if image == null:
		return "poster image should exist: %s" % ", ".join(result.get("errors", PackedStringArray()))
	var code_rect: Rect2i = result.get("code_rect", Rect2i())
	var expected_height := code_rect.end.y + DeckPosterComposerScript.DATA_STRIP_BOTTOM_QUIET_ZONE + DeckPosterComposerScript.BOTTOM_PADDING
	var scanned := DeckShareImageScannerScript.scan_image(image)
	return run_checks([
		assert_true(bool(result.get("ok", false)), "N's Zoroark poster should compose"),
		assert_true(image.get_height() > DeckPosterComposerScript.LEGACY_OUTPUT_SIZE.y, "N's Zoroark poster should grow beyond the legacy fixed height"),
		assert_eq(image.get_height(), expected_height, "poster height should include the data-strip scan quiet zone"),
		assert_true(bool(scanned.get("ok", false)), "dynamic-height N's Zoroark poster should scan"),
	])


func test_deck_poster_composer_v18_limitless_payload_fits_and_decodes() -> String:
	var file := FileAccess.open("res://data/bundled_user/decks/800018509.json", FileAccess.READ)
	if file == null:
		return "18.0 deck fixture should exist"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return "18.0 deck fixture should parse"
	var deck := DeckData.from_dict(parsed)
	var result: Dictionary = await DeckPosterComposerScript.compose_image(deck, "Tester", "", "0.5.0", "test-db", FakeCardDatabase.new())
	var image: Image = result.get("image", null)
	if image == null:
		return "poster image should exist: %s" % ", ".join(result.get("errors", PackedStringArray()))
	var scanned := DeckShareImageScannerScript.scan_image(image)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	var decoded := DeckSharePayloadCodecScript.decode_text(texts[0] if texts.size() > 0 else "")
	var payload: Dictionary = decoded.get("payload", {})
	var deck_payload: Dictionary = payload.get("deck", {})
	return run_checks([
		assert_true(bool(result.get("ok", false)), "18.0 poster should compose"),
		assert_true(bool(scanned.get("ok", false)), "18.0 poster code should scan"),
		assert_true(bool(decoded.get("ok", false)), "18.0 poster payload should decode"),
		assert_eq(str(deck_payload.get("name", "")), "18.0 猛雷鼓厄诡椪", "payload deck name"),
	])
