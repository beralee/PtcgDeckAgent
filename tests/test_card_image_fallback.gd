class_name TestCardImageFallback
extends TestBase

const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")


func test_card_data_resolves_bundled_image_path_when_user_cache_is_missing() -> String:
	var paths := CardData.get_image_candidate_paths("CS5aC", "107", "user://cards/images/__missing__/107.png")
	var resolved := CardData.resolve_existing_image_path(paths)

	return run_checks([
		assert_true(resolved.begins_with("res://data/bundled_user/cards/images/CS5aC/107.png.bin"), "Bundled card image path should resolve when user cache is missing"),
	])


func test_miraidon_165_new_cards_resolve_bundled_images_when_user_cache_is_missing() -> String:
	var magneton_paths := CardData.get_image_candidate_paths("CBB5C", "0301", "user://cards/images/__missing__/0301.png")
	var magnemite_paths := CardData.get_image_candidate_paths("CSV1C", "042", "user://cards/images/__missing__/042.png")
	var magneton_resolved := CardData.resolve_existing_image_path(magneton_paths)
	var magnemite_resolved := CardData.resolve_existing_image_path(magnemite_paths)

	return run_checks([
		assert_true(magneton_resolved.begins_with("res://data/bundled_user/cards/images/CBB5C/0301.png.bin"), "Bundled Magneton image path should resolve when user cache is missing"),
		assert_true(magnemite_resolved.begins_with("res://data/bundled_user/cards/images/CSV1C/042.png.bin"), "Bundled Magnemite image path should resolve when user cache is missing"),
	])


func test_battle_card_view_loads_texture_from_bundled_fallback() -> String:
	var card: CardData = CardDatabase.get_card("CS5aC", "107")
	if card == null:
		return "Expected CardDatabase to provide CS5aC_107 for bundled image fallback test"
	var cloned: CardData = card.duplicate(true) as CardData
	cloned.image_local_path = "user://cards/images/__missing__/107.png"
	var view = BattleCardViewScript.new()
	var texture: Texture2D = view.call("_load_texture", cloned) as Texture2D

	return run_checks([
		assert_not_null(texture, "BattleCardView should load the bundled fallback texture when user cache is missing"),
	])
