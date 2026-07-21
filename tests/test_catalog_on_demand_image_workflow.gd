class_name TestCatalogOnDemandImageWorkflow
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const CardImageOrProxyViewScript := preload("res://scripts/ui/cards/CardImageOrProxyView.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const DeckViewDialogScript := preload("res://scripts/ui/decks/DeckViewDialog.gd")


class FakeImageCacheService:
	extends Node

	signal image_ready(uid: String, local_path: String)
	signal image_failed(uid: String, reason: String)

	var requested_cards: Array[CardData] = []
	var requested_options: Array[Dictionary] = []

	func get_status(_set_code: String, _card_index: String) -> String:
		return "missing"

	func get_local_path_if_ready(_set_code: String, _card_index: String) -> String:
		return ""

	func ensure_image(card: CardData, priority: int = 0, reason: String = "") -> String:
		requested_cards.append(card)
		requested_options.append({"priority": priority, "reason": reason})
		return "fake_auto_job"

	func ensure_image_with_options(card: CardData, options: Dictionary = {}) -> String:
		requested_cards.append(card)
		requested_options.append(options.duplicate(true))
		return "fake_manual_job"


func test_csv4c_015_keeps_catalog_only_data_but_bundles_its_card_image() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV4C", "015")
	var search_results: Array[Dictionary] = db.search_catalog_cards("CSV4C 015", {}, 20, 0)
	var found_in_search := false
	for entry: Dictionary in search_results:
		if str(entry.get("uid", "")) == "CSV4C_015":
			found_in_search = true
			break
	db.free()

	return run_checks([
		assert_not_null(card, "CSV4C_015 should resolve from the full text catalog"),
		assert_eq(card.name if card != null else "", "九尾", "CSV4C_015 should preserve its Chinese name"),
		assert_eq(card.effect_id if card != null else "", "b540fb36a187e1d05008e3be61084e81", "CSV4C_015 should preserve the source effect id"),
		assert_true(found_in_search, "CSV4C_015 should be searchable in the catalog index"),
		assert_false(FileAccess.file_exists("res://data/bundled_user/cards/CSV4C_015.json"), "Catalog-only cards should not be copied into the curated bundled card directory"),
		assert_true(FileAccess.file_exists("res://data/bundled_user/cards/images/CSV4C/015.png.bin"), "CSV4C_015 should bundle its image so every platform can display the card"),
		assert_true(CardData.is_valid_card_image_file("res://data/bundled_user/cards/images/CSV4C/015.png.bin"), "CSV4C_015 bundled image should be a valid supported card image"),
		assert_false(FileAccess.file_exists("res://data/bundled_user/cards/images/CSV4C/015.png"), "CSV4C_015 must not bundle a raw image"),
	])


func test_deck_center_renders_csv4c_015_bundled_image_without_download() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV4C", "015")
	db.free()
	if card == null:
		return assert_not_null(card, "CSV4C_015 is required for the deck-center download test")

	var host := Control.new()
	host.size = Vector2(1600, 900)
	var deck := DeckData.new()
	deck.id = 915
	deck.deck_name = "Catalog Image Test"
	deck.total_cards = 1
	deck.cards = [{
		"name": card.name,
		"card_type": card.card_type,
		"set_code": card.set_code,
		"card_index": card.card_index,
		"count": 1,
	}]

	DeckViewDialogScript.new().show_deck(host, deck)
	var texture_rect := host.find_child("CardImageTexture", true, false) as TextureRect
	var download_button := host.find_child("DeckViewCardImageDownloadButton", true, false) as Button
	var rendered_texture := texture_rect != null and texture_rect.texture != null
	host.free()

	return run_checks([
		assert_true(rendered_texture, "Deck center should render the bundled CSV4C_015 image immediately"),
		assert_null(download_button, "A bundled CSV4C_015 image should not show a download control"),
	])


func test_replacing_a_card_in_deck_queues_the_added_card_image() -> String:
	var db := CardDatabaseScript.new()
	var added_card: CardData = db.get_card("CSV4C", "015")
	db.free()
	if added_card == null:
		return assert_not_null(added_card, "CSV4C_015 is required for the deck-editor auto-download test")

	var old_card := CardData.new()
	old_card.name = "Old Card"
	old_card.name_en = "Old Card"
	old_card.card_type = "Pokemon"
	old_card.set_code = "AUTO"
	old_card.card_index = "001"
	var deck := DeckData.new()
	deck.cards = [{
		"name": old_card.name,
		"card_type": old_card.card_type,
		"set_code": old_card.set_code,
		"card_index": old_card.card_index,
		"count": 1,
	}]
	deck.total_cards = 1
	var service := FakeImageCacheService.new()
	var editor := DeckEditorScript.new()
	editor.set("_deck", deck)
	editor.set("_image_cache_service", service)
	editor.call("_do_replace", 0, added_card)
	var requested_uid := service.requested_cards[0].get_uid() if not service.requested_cards.is_empty() else ""
	var options: Dictionary = service.requested_options[0] if not service.requested_options.is_empty() else {}
	editor.free()
	service.free()

	return run_checks([
		assert_eq(requested_uid, "CSV4C_015", "Adding a card to a deck should queue that card image automatically"),
		assert_eq(int(options.get("priority", -1)), 8, "Deck-editor downloads should use foreground priority"),
		assert_eq(str(options.get("reason", "")), "deck_editor_add", "Deck-editor download should expose its trigger reason"),
	])


func test_proxy_view_can_render_manual_download_control_without_a_texture() -> String:
	var card := CardData.new()
	card.name = "Proxy Card"
	card.name_en = "Proxy Card"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 70
	card.set_code = "PROXY"
	card.card_index = "999"
	card.image_url = "https://tcg.mik.moe/static/img/PROXY/999.png"
	card.image_local_path = "user://cards/images/PROXY/999.png"
	var service := FakeImageCacheService.new()
	var view := CardImageOrProxyViewScript.new()
	service.add_child(view)
	view.setup_from_card(card, service, {"show_download_button": true})
	var button := view.find_child("DeckViewCardImageDownloadButton", true, false) as Button
	var button_exists := button != null
	service.free()

	return assert_true(button_exists, "The shared card proxy should own the single-image download control")
