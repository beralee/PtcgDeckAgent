class_name TestCSV10C246To250
extends TestBase


func test_csv10c_246_250_bundle_metadata_and_assets() -> String:
	var expected := {
		"246": ["派帕的獒教父ex", "5d6fdb8a31831315e14728bf8d8fe534"],
		"247": ["赫普的苍响ex", "832e8b704b5457781ee7c52adc1a0571"],
		"248": ["暴飞龙ex", "f0c413ebe4cec489e68fdf6afb19f3a2"],
		"249": ["火箭队的猫老大ex", "d7c0c50d9f82eb297d7b6b26850a91a3"],
		"250": ["土龙节节ex", "11ea687ef47b095786562c92afdc67cf"],
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


func test_csv10c_246_250_share_base_effect_ids_and_each_attack_registers_once() -> String:
	var alternate_indices := ["246", "247", "248", "249", "250"]
	var base_indices := ["151", "161", "165", "170", "179"]
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
		for attack_index: int in alternate.attacks.size():
			checks.append(assert_eq(processor.get_attack_effects_for_slot(slot, attack_index).size(), 1, "CSV10C_%s attack %d should resolve exactly one shared scripted effect" % [alternate_indices[i], attack_index]))
	return run_checks(checks)


func test_csv10c_250_counts_only_opposing_pokemon_ex_and_second_attack_ignores_effects() -> String:
	var card := _load_card("250")
	if card == null:
		return "CSV10C_250 should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var attacker := _slot_from_card(card, 0)
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 3
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = _pokemon_slot("Opponent ex", "ex", 1)
	state.players[1].bench = [_pokemon_slot("Second ex", "ex", 1), _pokemon_slot("Ordinary", "", 1)]
	var first := processor.get_attack_effects_for_slot(attacker, 0)[0]
	var second := processor.get_attack_effects_for_slot(attacker, 1)[0]
	return run_checks([
		assert_eq(int(first.call("get_damage_bonus", attacker, state)), 60, "CSV10C_250 printed 60x plus bonus should total 120 for 2 opposing Pokemon ex"),
		assert_false(bool(second.call("ignores_defender_effects", attacker, state, 0)), "CSV10C_250 should not ignore effects for its first attack"),
		assert_true(bool(second.call("ignores_defender_effects", attacker, state, 1)), "CSV10C_250 second attack should ignore effects on the opposing Active Pokemon"),
	])


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


func _pokemon_slot(name: String, mechanic: String, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 200
	data.mechanic = mechanic
	return _slot_from_card(data, owner)
