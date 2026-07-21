class_name TestCSV10C231To235
extends TestBase


func test_csv10c_231_235_bundle_metadata_and_assets() -> String:
	var expected := {
		"231": ["火箭队的火焰鸟ex", "453285d9bb2986c6603cbae746502b97"],
		"232": ["阿响的凤王ex", "23d228f7053a7314a2ee5f651f38a3cb"],
		"233": ["波尔凯尼恩ex", "075fe490ef98a74bc6f880be9ebd75de"],
		"234": ["浩大鲸ex", "f8a7ab601e5eba8d038f5ae262fb69f3"],
		"235": ["吃吼霸ex", "7dc748893391fd983b4e889222c7e7fe"],
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


func test_csv10c_231_233_reuse_base_print_effect_ids_once() -> String:
	var alternates := [_load_card("231"), _load_card("232"), _load_card("233")]
	var bases := [_load_card("027"), _load_card("035"), _load_card("042")]
	if alternates.has(null) or bases.has(null):
		return "CSV10C base and alternate-art cards 231-233 are required"
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for i: int in alternates.size():
		var alternate: CardData = alternates[i]
		var base: CardData = bases[i]
		processor.register_pokemon_card(alternate)
		var slot := _slot_from_card(alternate, 0)
		checks.append(assert_eq(alternate.effect_id, base.effect_id, "CSV10C_%d should share its base print effect id" % (231 + i)))
		if not alternate.abilities.is_empty():
			checks.append(assert_not_null(processor.get_effect(alternate.effect_id), "CSV10C_%d should resolve its shared Ability once" % (231 + i)))
		for attack_index: int in alternate.attacks.size():
			checks.append(assert_eq(processor.get_attack_effects_for_slot(slot, attack_index).size(), 1, "CSV10C_%d attack %d should resolve exactly one shared scripted effect" % [231 + i, attack_index]))
	return run_checks(checks)


func test_csv10c_234_cetitan_blocks_opponent_item_supporter_effects_and_discards_stadium() -> String:
	var card := _load_card("234")
	if card == null:
		return "CSV10C_234 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var cetitan := _slot_from_card(card, 0)
	state.players[0].active_pokemon = cetitan
	var opponent_item := _card("Opponent Item", "Item", 1)
	var opponent_supporter := _card("Opponent Supporter", "Supporter", 1)
	var own_item := _card("Own Item", "Item", 0)
	var opponent_stadium := _card("Opponent Stadium", "Stadium", 1)
	var ordinary_target := state.players[0].bench[0]
	var sanitized_targets := processor.sanitize_opponent_hand_trainer_targets(opponent_item, [{"targets": [cetitan, ordinary_target]}], state)
	var attack_effects := processor.get_attack_effects_for_slot(cetitan, 0)
	var stadium := _card("Stadium in play", "Stadium", 1)
	state.stadium_card = stadium
	state.stadium_owner_index = 1
	if not attack_effects.is_empty():
		attack_effects[0].set_attack_interaction_context([{"discard_stadium_bonus": ["discard"]}])
	var bonus := int(attack_effects[0].call("get_damage_bonus", cetitan, state)) if not attack_effects.is_empty() else -999
	if not attack_effects.is_empty():
		attack_effects[0].call("execute_attack", cetitan, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_true(processor.is_protected_from_opponent_hand_trainer_effect(cetitan, opponent_item, state), "CSV10C_234 should ignore an opponent Item played from hand"),
		assert_true(processor.is_protected_from_opponent_hand_trainer_effect(cetitan, opponent_supporter, state), "CSV10C_234 should ignore an opponent Supporter played from hand"),
		assert_false(processor.is_protected_from_opponent_hand_trainer_effect(cetitan, own_item, state), "CSV10C_234 should not ignore its owner's Item"),
		assert_false(processor.is_protected_from_opponent_hand_trainer_effect(cetitan, opponent_stadium, state), "CSV10C_234 should not extend protection to Stadium cards"),
		assert_eq(sanitized_targets, [{"targets": [ordinary_target]}], "CSV10C_234 should be removed from opponent Item/Supporter target contexts"),
		assert_eq(bonus, 140, "CSV10C_234 should add 140 damage when the Stadium is discarded"),
		assert_null(state.stadium_card, "CSV10C_234 should discard the Stadium when that option is selected"),
		assert_true(stadium in state.players[1].discard_pile, "CSV10C_234 should send the Stadium to its owner's discard pile"),
	])


func test_csv10c_235_dondozo_counts_damage_and_optional_recoil_bonus() -> String:
	var card := _load_card("235")
	if card == null:
		return "CSV10C_235 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var dondozo := _slot_from_card(card, 0)
	dondozo.damage_counters = 40
	var first := processor.get_attack_effects_for_slot(dondozo, 0)
	var second := processor.get_attack_effects_for_slot(dondozo, 1)
	var first_bonus := int(first[0].call("get_damage_bonus", dondozo, state)) if not first.is_empty() else -999
	if not second.is_empty():
		second[0].set_attack_interaction_context([{"optional_bonus_self_damage": ["yes"]}])
	var second_bonus := int(second[0].call("get_damage_bonus", dondozo, state)) if not second.is_empty() else -999
	if not second.is_empty():
		second[0].call("execute_attack", dondozo, state.players[1].active_pokemon, 1, state)
	return run_checks([
		assert_eq(first.size(), 1, "CSV10C_235 first attack should have one scripted effect"),
		assert_eq(first_bonus, 40, "CSV10C_235 should add 10 damage per damage counter"),
		assert_eq(second.size(), 1, "CSV10C_235 second attack should have one scripted effect"),
		assert_eq(second_bonus, 120, "CSV10C_235 optional branch should add 120 damage"),
		assert_eq(dondozo.damage_counters, 90, "CSV10C_235 optional branch should add exactly 50 self-damage"),
	])


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 3
	state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot("Active %d" % pi, "C", pi)
		player.bench = [_slot("Bench %d" % pi, "C", pi)]
		state.players.append(player)
	return state


func _slot(name: String, energy_type: String, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 300
	data.energy_type = energy_type
	return _slot_from_card(data, owner)


func _slot_from_card(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _card(name: String, card_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)
