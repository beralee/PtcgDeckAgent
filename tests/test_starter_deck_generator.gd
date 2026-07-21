class_name TestStarterDeckGenerator
extends TestBase

const StarterDeckGeneratorScript := preload("res://scripts/deck_builder/StarterDeckGenerator.gd")

var _generator: RefCounted = null
var _catalog: Array[Dictionary] = []


func _get_generator() -> RefCounted:
	if _generator == null:
		_generator = StarterDeckGeneratorScript.new()
	return _generator


func _get_catalog() -> Array[Dictionary]:
	if _catalog.is_empty():
		_catalog = _get_generator().call("build_bundled_catalog", Callable(CardDatabase, "get_card"))
	return _catalog


func test_bundled_catalog_only_contains_complete_legal_templates() -> String:
	var catalog := _get_catalog()
	var every_template_valid := not catalog.is_empty()
	var every_template_has_basic := not catalog.is_empty()
	for entry: Dictionary in catalog:
		var deck := entry.get("deck") as DeckData
		var analysis: Dictionary = entry.get("analysis", {})
		if deck == null or not deck.validate().is_empty() or int(analysis.get("missing_cards", 0)) != 0:
			every_template_valid = false
		if int(analysis.get("basic_pokemon", 0)) <= 0:
			every_template_has_basic = false
	return run_checks([
		assert_gte(catalog.size(), 50, "Starter generator should have a broad bundled template pool"),
		assert_true(every_template_valid, "Starter generator must exclude incomplete or illegal bundled templates"),
		assert_true(every_template_has_basic, "Every starter template must be able to provide an opening Basic Pokemon"),
	])


func test_every_pokemon_type_can_generate_a_legal_sixty_card_deck() -> String:
	var catalog := _get_catalog()
	var failures := PackedStringArray()
	var serial := 0
	for energy_type: String in ["R", "W", "G", "L", "P", "F", "D", "M", "N", "C"]:
		serial += 1
		var result: Dictionary = _get_generator().call("generate_deck", catalog, {
			"energy_type": energy_type,
			"axis": "auto",
			"pace": "balanced",
			"deck_name": "属性测试 %s" % energy_type,
		}, [], 1784300000000 + serial)
		var deck := result.get("deck") as DeckData
		var analysis: Dictionary = result.get("analysis", {})
		if not bool(result.get("ok", false)) or deck == null:
			failures.append("%s: no deck" % energy_type)
			continue
		var validation: PackedStringArray = _get_generator().call("validate_generated_deck", deck, Callable(CardDatabase, "get_card"))
		var type_scores: Dictionary = analysis.get("type_scores", {})
		var selected_type_score := float(type_scores.get(energy_type, 0.0))
		var maximum_type_score := 0.0
		for score_raw: Variant in type_scores.values():
			maximum_type_score = maxf(maximum_type_score, float(score_raw))
		var type_is_main_axis := selected_type_score > 0.0 and selected_type_score >= maximum_type_score * 0.45
		if deck.total_cards != 60 or not validation.is_empty() or not type_is_main_axis:
			failures.append("%s: total=%d errors=%s score=%s" % [energy_type, deck.total_cards, str(validation), str(type_scores.get(energy_type, 0.0))])
	return assert_eq(failures.size(), 0, "Every selectable Pokemon type should produce a matching legal deck: %s" % str(failures))


func test_axis_selection_prefers_the_requested_evolution_structure() -> String:
	var catalog := _get_catalog()
	var basic_result: Dictionary = _get_generator().call("select_template", catalog, {
		"energy_type": "L",
		"axis": "basic",
		"pace": "fast",
	})
	var stage_two_result: Dictionary = _get_generator().call("select_template", catalog, {
		"energy_type": "P",
		"axis": "stage2",
		"pace": "balanced",
	})
	var basic_analysis: Dictionary = basic_result.get("analysis", {})
	var stage_two_analysis: Dictionary = stage_two_result.get("analysis", {})
	return run_checks([
		assert_true(bool(basic_result.get("ok", false)), "Basic-axis selection should find a matching template"),
		assert_eq(int(basic_analysis.get("stage2_pokemon", -1)), 0, "Basic-axis lightning selection should prefer a deck without Stage 2 Pokemon"),
		assert_true(bool(stage_two_result.get("ok", false)), "Stage-2 selection should find a matching template"),
		assert_gt(int(stage_two_analysis.get("stage2_pokemon", 0)), 0, "Stage-2 selection should contain a Stage 2 line"),
	])


func test_generated_deck_is_independent_and_gets_unique_identity() -> String:
	var catalog := _get_catalog()
	var selected: Dictionary = _get_generator().call("select_template", catalog, {
		"energy_type": "R",
		"axis": "stage2",
		"pace": "balanced",
	})
	var source_deck := selected.get("deck") as DeckData
	if source_deck == null or source_deck.cards.is_empty():
		return "Expected a source template"
	var source_first_count := int(source_deck.cards[0].get("count", 0))
	var existing := DeckData.new()
	existing.id = 1030000001
	existing.deck_name = "我的火属性卡组"
	var result: Dictionary = _get_generator().call("generate_deck", catalog, {
		"energy_type": "R",
		"axis": "stage2",
		"pace": "balanced",
		"deck_name": "我的火属性卡组",
	}, [existing], 1784300000001)
	var generated := result.get("deck") as DeckData
	if generated != null and not generated.cards.is_empty():
		generated.cards[0]["count"] = source_first_count + 10
	return run_checks([
		assert_true(bool(result.get("ok", false)) and generated != null, "Generator should create a deck from the selected template"),
		assert_true(generated != null and generated.id != existing.id and generated.id != source_deck.id, "Generated deck id must be independent from existing and template ids"),
		assert_eq(generated.deck_name if generated != null else "", "我的火属性卡组 2", "Generated name should avoid collisions without asking the player again"),
		assert_eq(int(source_deck.cards[0].get("count", 0)), source_first_count, "Editing the generated deck must not mutate the bundled template"),
		assert_eq(generated.source_provider if generated != null else "", "starter_generator", "Generated decks should keep local provenance metadata"),
	])


func test_generated_deck_loads_in_existing_deck_editor() -> String:
	var catalog := _get_catalog()
	var result: Dictionary = _get_generator().call("generate_deck", catalog, {
		"energy_type": "P",
		"axis": "stage2",
		"pace": "balanced",
		"deck_name": "生成器编辑器集成测试",
	}, CardDatabase.get_all_decks(), 1784300000099)
	var generated := result.get("deck") as DeckData
	if generated == null:
		return "Expected a generated deck"
	if CardDatabase.has_deck(generated.id):
		CardDatabase.delete_deck(generated.id)
	CardDatabase.save_deck(generated)
	GameManager.call("set_scene_navigation_suppressed_for_tests", true)
	GameManager.call("consume_last_requested_scene_path")
	GameManager.call("consume_deck_editor_id")
	GameManager.goto_deck_editor(generated.id)

	var packed_editor := load("res://scenes/deck_editor/DeckEditor.tscn") as PackedScene
	var editor := packed_editor.instantiate() as Control if packed_editor != null else null
	var tree := Engine.get_main_loop() as SceneTree
	if editor != null:
		tree.root.add_child(editor)
		await tree.process_frame
	var loaded := editor.get("_deck") as DeckData if editor != null else null
	var loaded_id := loaded.id if loaded != null else -1
	var loaded_total := loaded.total_cards if loaded != null else -1
	var loaded_entries := loaded.cards.size() if loaded != null else 0

	if editor != null:
		editor.queue_free()
	CardDatabase.delete_deck(generated.id)
	GameManager.call("set_scene_navigation_suppressed_for_tests", false)
	return run_checks([
		assert_not_null(packed_editor, "Existing DeckEditor scene should load"),
		assert_not_null(loaded, "Existing DeckEditor should read the generated deck from CardDatabase"),
		assert_eq(loaded_id, generated.id, "DeckEditor should preserve the generated deck id"),
		assert_eq(loaded_total, 60, "DeckEditor should receive all 60 generated cards"),
		assert_gt(loaded_entries, 0, "DeckEditor should receive editable card entries"),
	])
