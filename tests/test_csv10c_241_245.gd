class_name TestCSV10C241To245
extends TestBase


func test_csv10c_241_245_bundle_metadata_and_assets() -> String:
	var expected := {
		"241": ["竹兰的烈咬陆鲨ex", "b494c15a64405edbc24ed017733ad8a5"],
		"242": ["象牙猪ex", "e81894ba20ba5db44d8a4133f78564c2"],
		"243": ["火箭队的尼多王ex", "54a2289d69bc02af78261838357cbb6e"],
		"244": ["火箭队的叉字蝠ex", "c4cf39844b70f177c0f202f57e1f0841"],
		"245": ["N的索罗亚克ex", "a1742becbf9fdc6a66ddfb1b306c4bc0"],
	}
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for index: String in expected:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var card := _load_card(index)
		checks.append(assert_not_null(card, "CSV10C_%s should load from bundled JSON" % index))
		if card == null:
			continue
		checks.append(assert_eq(card.name, expected[index][0], "CSV10C_%s should preserve the API card name" % index))
		checks.append(assert_eq(card.effect_id, expected[index][1], "CSV10C_%s should preserve the API effect id" % index))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "CSV10C_%s should bundle a valid PNG" % index))
		checks.append(assert_true(card_path in manifest and image_path in manifest, "CSV10C_%s resources should be listed in the manifest" % index))
	return run_checks(checks)


func test_csv10c_241_245_share_base_effect_ids_and_register_once() -> String:
	var alternate_indices := ["241", "242", "243", "244", "245"]
	var base_indices := ["113", "104", "127", "130", "145"]
	var expected_attack_counts := [[1, 1], [1], [1, 0], [1], [1]]
	var expected_abilities := [false, true, false, true, true]
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for i: int in alternate_indices.size():
		var alternate := _load_card(alternate_indices[i])
		var base := _load_card(base_indices[i])
		checks.append(assert_not_null(alternate, "CSV10C_%s should load" % alternate_indices[i]))
		checks.append(assert_not_null(base, "CSV10C_%s base print should load" % base_indices[i]))
		if alternate == null or base == null:
			continue
		checks.append(assert_eq(alternate.effect_id, base.effect_id, "CSV10C_%s should share its base print effect id" % alternate_indices[i]))
		processor.register_pokemon_card(alternate)
		var slot := _slot_from_card(alternate, 0)
		if expected_abilities[i]:
			checks.append(assert_not_null(processor.get_effect(alternate.effect_id), "CSV10C_%s should resolve the shared Ability" % alternate_indices[i]))
		for attack_index: int in expected_attack_counts[i].size():
			checks.append(assert_eq(processor.get_attack_effects_for_slot(slot, attack_index).size(), expected_attack_counts[i][attack_index], "CSV10C_%s attack %d should resolve the shared scripted effects exactly once" % [alternate_indices[i], attack_index]))
	return run_checks(checks)


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot_from_card(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot
