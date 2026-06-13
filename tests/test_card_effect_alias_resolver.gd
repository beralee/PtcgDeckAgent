class_name TestCardEffectAliasResolver
extends TestBase

const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")
const CardEffectAliasResolverScript := preload("res://scripts/engine/CardEffectAliasResolver.gd")

const SOURCE_SET := "CSV7C"
const SOURCE_INDEX := "051"
const IMPORTED_SET := "CSV9.5C"
const IMPORTED_INDEX := "030"
const IMPORTED_FAKE_EFFECT_ID := "utest_csv95c_030_gouging_fire_duplicate_effect"
const SOURCE_EFFECT_ID := "2d2fed5a4681c1000b070227a730eaff"


func _make_imported_gouging_fire_duplicate() -> CardData:
	var source := CardDatabase.get_card(SOURCE_SET, SOURCE_INDEX)
	assert(source != null)
	var card := CardData.from_dict(source.to_dict())
	card.set_code = IMPORTED_SET
	card.card_index = IMPORTED_INDEX
	card.artist = "PLANETA Mochizuki"
	card.rarity = "RR"
	card.release_date = "2026-06-12T00:00:00+08:00"
	card.effect_id = IMPORTED_FAKE_EFFECT_ID
	card.ensure_image_metadata()
	return card


func test_csv95c_gouging_fire_duplicate_signature_matches_existing_card() -> String:
	var source := CardDatabase.get_card(SOURCE_SET, SOURCE_INDEX)
	var imported := _make_imported_gouging_fire_duplicate()
	var result: Dictionary = CardEffectAliasResolverScript.find_duplicate_effect_alias(imported, [source])

	return run_checks([
		assert_true(bool(result.get("matched", false)), "CSV9.5C/030 duplicate Gouging Fire should match CSV7C/051 by same-name same-effect signature"),
		assert_eq(str(result.get("source_effect_id", "")), SOURCE_EFFECT_ID, "Alias source should be the implemented Gouging Fire effect id"),
		assert_eq(str(result.get("source_set_code", "")), SOURCE_SET, "Alias source set"),
		assert_eq(str(result.get("source_card_index", "")), SOURCE_INDEX, "Alias source index"),
	])


func test_import_fallback_marks_duplicate_gouging_fire_as_implemented_and_runtime_registered() -> String:
	CardDatabase.unregister_effect_alias_for_tests(IMPORTED_FAKE_EFFECT_ID)
	CardImplementationStatusScript.clear_cache()
	var imported := _make_imported_gouging_fire_duplicate()

	var before_unimplemented := CardImplementationStatusScript.is_unimplemented(imported)
	var alias_result := CardDatabase.try_register_duplicate_effect_alias(imported)
	CardImplementationStatusScript.clear_cache()
	var after_unimplemented := CardImplementationStatusScript.is_unimplemented(imported)

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(imported)
	var has_alias_attack := processor.has_attack_effect(IMPORTED_FAKE_EFFECT_ID)
	var has_source_attack := processor.has_attack_effect(SOURCE_EFFECT_ID)
	processor.prepare_for_disposal()
	CardDatabase.unregister_effect_alias_for_tests(IMPORTED_FAKE_EFFECT_ID)
	CardImplementationStatusScript.clear_cache()

	return run_checks([
		assert_true(before_unimplemented, "Imported duplicate with a new unregistered effect id should start as unimplemented"),
		assert_true(bool(alias_result.get("applied", false)), "Import fallback should create an effect alias for the duplicate Gouging Fire"),
		assert_eq(str(alias_result.get("source_effect_id", "")), SOURCE_EFFECT_ID, "Import fallback should map to the implemented source effect id"),
		assert_false(after_unimplemented, "Aliased duplicate card should no longer show as unimplemented"),
		assert_true(has_source_attack, "Source Gouging Fire attack effect should be registered"),
		assert_true(has_alias_attack, "Aliased imported effect id should resolve to the source attack effect"),
	])
