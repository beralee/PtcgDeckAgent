class_name TestCSV10C251To287
extends TestBase


const SHARED_PRINTS := {
	"251": ["203", "4eadb12f43cd50ddec37821f28ce0359"],
	"252": ["204", "2d4c85c2075cb99646ad0e5e34f0f825"],
	"253": ["205", "dacd942c84db0948ced6544bacfa08d7"],
	"254": ["206", "0a9bdf265647461dd5c6c827ffc19e61"],
	"255": ["207", "8d9b3076693b9f692bae94d057498720"],
	"256": ["208", "3b03f59349002f02a731b531dbdb4358"],
	"257": ["209", "e3b38149675a6f8f0e606ddbe321e094"],
	"258": ["210", "e905f4430cb382552e052cf8d926f890"],
	"259": ["211", "f567109551b79471a196f605ba549be8"],
	"260": ["212", "ffc8153bc60e336eee4c6c5c74a3d95f"],
	"261": ["213", "c73f4fde5f12bf1f6c1e8866492ef4b3"],
	"262": ["229", "88367894eb8e5dc6ae6b2b8350eb75f9"],
	"263": ["231", "453285d9bb2986c6603cbae746502b97"],
	"264": ["232", "23d228f7053a7314a2ee5f651f38a3cb"],
	"265": ["233", "075fe490ef98a74bc6f880be9ebd75de"],
	"266": ["237", "945599a057164c3c735c59a7f34461db"],
	"267": ["238", "c82dc9185c27908490f8a00cfdc75765"],
	"268": ["239", "103a8775a94d6e7d8f151cbf680bd860"],
	"269": ["241", "b494c15a64405edbc24ed017733ad8a5"],
	"270": ["243", "54a2289d69bc02af78261838357cbb6e"],
	"271": ["244", "c4cf39844b70f177c0f202f57e1f0841"],
	"272": ["245", "a1742becbf9fdc6a66ddfb1b306c4bc0"],
	"273": ["246", "5d6fdb8a31831315e14728bf8d8fe534"],
	"274": ["247", "832e8b704b5457781ee7c52adc1a0571"],
	"275": ["248", "f0c413ebe4cec489e68fdf6afb19f3a2"],
	"276": ["255", "8d9b3076693b9f692bae94d057498720"],
	"277": ["256", "3b03f59349002f02a731b531dbdb4358"],
	"278": ["257", "e3b38149675a6f8f0e606ddbe321e094"],
	"279": ["259", "f567109551b79471a196f605ba549be8"],
	"280": ["264", "23d228f7053a7314a2ee5f651f38a3cb"],
	"281": ["266", "945599a057164c3c735c59a7f34461db"],
	"282": ["268", "103a8775a94d6e7d8f151cbf680bd860"],
	"283": ["269", "b494c15a64405edbc24ed017733ad8a5"],
	"284": ["271", "c4cf39844b70f177c0f202f57e1f0841"],
	"285": ["272", "a1742becbf9fdc6a66ddfb1b306c4bc0"],
	"286": ["217", "cf88045d66d42c709157d28d64449c64"],
	"287": ["221", "f9db949f369ecead569fb8e3adc4eaee"],
}


func test_csv10c_251_255_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["251", "252", "253", "254", "255"])


func test_csv10c_256_260_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["256", "257", "258", "259", "260"])


func test_csv10c_261_265_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["261", "262", "263", "264", "265"])


func test_csv10c_266_270_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["266", "267", "268", "269", "270"])


func test_csv10c_271_275_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["271", "272", "273", "274", "275"])


func test_csv10c_276_280_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["276", "277", "278", "279", "280"])


func test_csv10c_281_285_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["281", "282", "283", "284", "285"])


func test_csv10c_286_287_bundle_and_shared_effect_ids() -> String:
	return _verify_shared_print_batch(["286", "287"])


func _verify_shared_print_batch(indices: Array[String]) -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for index: String in indices:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var base_index: String = SHARED_PRINTS[index][0]
		var expected_effect_id: String = SHARED_PRINTS[index][1]
		var card := _load_card(index)
		var base := _load_card(base_index)
		checks.append(assert_not_null(card, "CSV10C_%s should load from bundled JSON" % index))
		checks.append(assert_not_null(base, "CSV10C_%s base print should load" % base_index))
		if card == null or base == null:
			continue
		checks.append(assert_eq(card.effect_id, expected_effect_id, "CSV10C_%s should preserve the API effect id" % index))
		checks.append(assert_eq(card.effect_id, base.effect_id, "CSV10C_%s should reuse its same-name print effect id" % index))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "CSV10C_%s should bundle a valid PNG" % index))
		checks.append(assert_true(card_path in manifest and image_path in manifest, "CSV10C_%s resources should be listed in the manifest" % index))
		if card.card_type == "Pokemon":
			processor.register_pokemon_card(card)
			var slot := _slot_from_card(card)
			var scripted_effects := 0
			for attack_index: int in card.attacks.size():
				scripted_effects += processor.get_attack_effects_for_slot(slot, attack_index).size()
			checks.append(assert_true(processor.get_effect(card.effect_id) != null or scripted_effects > 0, "CSV10C_%s should resolve its shared Pokemon behavior" % index))
		else:
			checks.append(assert_not_null(processor.get_effect(card.effect_id), "CSV10C_%s should resolve its shared card effect" % index))
	return run_checks(checks)


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot_from_card(data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 0))
	return slot
