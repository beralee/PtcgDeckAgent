class_name TestCardProxyRenderer
extends TestBase

const CardImageOrProxyViewScript := preload("res://scripts/ui/cards/CardImageOrProxyView.gd")


func test_proxy_text_contains_card_identity_and_summary() -> String:
	var card := CardData.new()
	card.name = "Proxy Test"
	card.name_en = "Proxy Test EN"
	card.card_type = "Pokemon"
	card.mechanic = "ex"
	card.stage = "Basic"
	card.hp = 180
	card.energy_type = "P"
	card.set_code = "PROXY"
	card.card_index = "001"
	card.attacks = [{"name": "Mind Shot", "damage": "60", "text": "Deal damage."}]
	var lines: PackedStringArray = CardImageOrProxyViewScript.proxy_lines_for_card(card, "missing")
	var joined := "\n".join(Array(lines))

	return run_checks([
		assert_true(joined.contains("代卡"), "Proxy should clearly mark missing art"),
		assert_true(joined.contains("Proxy Test"), "Proxy should show card name"),
		assert_true(joined.contains("Pokemon"), "Proxy should show card type"),
		assert_true(joined.contains("HP 180"), "Proxy should show HP"),
		assert_true(joined.contains("PROXY 001"), "Proxy should show set and card index"),
		assert_true(joined.contains("Mind Shot"), "Proxy should show ability or attack summary"),
	])


func test_proxy_view_uses_large_portrait_fonts_for_missing_image() -> String:
	var view: Control = CardImageOrProxyViewScript.new()
	var entry := {
		"name": "Portrait Proxy",
		"card_type": "Item",
		"set_code": "PROXY",
		"card_index": "002",
		"description": "Search your deck.",
	}
	view.call("setup_from_entry", entry, null, {"portrait": true})
	var name_label := view.find_child("CardProxyLine1", true, false) as Label
	var summary_label := view.find_child("CardProxyLine4", true, false) as Label

	var result := run_checks([
		assert_not_null(name_label, "Proxy view should render a stable card-name label"),
		assert_true(name_label != null and name_label.get_theme_font_size("font_size") >= 24, "Portrait proxy card names should be phone-readable"),
		assert_true(summary_label != null and summary_label.get_theme_font_size("font_size") >= 16, "Portrait proxy summaries should be readable"),
	])
	view.free()
	return result


func test_proxy_view_uses_texture_when_local_image_exists() -> String:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var card_database: Object = scene_tree.root.get_node_or_null("CardDatabase") if scene_tree != null else null
	var card: CardData = card_database.get_card("CS5aC", "107") if card_database != null else null
	var view: Control = CardImageOrProxyViewScript.new()
	view.call("setup_from_card", card)
	var texture := view.find_child("CardImageTexture", true, false) as TextureRect
	var proxy := view.find_child("CardProxyBox", true, false) as VBoxContainer

	var result := run_checks([
		assert_not_null(card, "Fixture card should exist"),
		assert_not_null(texture, "Proxy component should render a texture when an image is cached or bundled"),
		assert_null(proxy, "Proxy component should not render text proxy when a real image exists"),
	])
	view.free()
	return result
