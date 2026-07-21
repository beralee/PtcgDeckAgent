class_name TestCSV10C226To230
extends TestBase


func test_csv10c_226_230_bundle_metadata_and_assets() -> String:
	var expected := {
		"226": ["洛托姆", "e88a648419aa3c1e323c6bd4f66d1dab"],
		"227": ["藏玛然特", "08e4abe39ce058b6724cf68c1e9828e4"],
		"228": ["N的莱希拉姆", "7ee514e3fb601f1f743a3d329b98daab"],
		"229": ["远古巨蜓ex", "88367894eb8e5dc6ae6b2b8350eb75f9"],
		"230": ["奥利瓦ex", "158981f07985a13c7ea6990821377019"],
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


func test_csv10c_226_rotom_hides_opponent_hand_identity_and_counts_all_tools() -> String:
	var card := _load_card("226")
	if card == null:
		return "CSV10C_226 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var rotom := _slot_from_card(card, 0)
	state.players[0].active_pokemon = rotom
	var hidden_a := _card("Hidden A", "Item", 1)
	var hidden_b := _card("Hidden B", "Supporter", 1)
	state.players[1].hand = [hidden_a, hidden_b]
	var astonish := processor.get_attack_effects_for_slot(rotom, 0)
	var accessory := processor.get_attack_effects_for_slot(rotom, 1)
	var steps: Array[Dictionary] = astonish[0].call("get_attack_interaction_steps", rotom.get_top_card(), card.attacks[0], state) if not astonish.is_empty() else []
	if not astonish.is_empty():
		astonish[0].set_attack_interaction_context([{"opponent_hand_card_to_deck": [hidden_b]}])
		astonish[0].call("execute_attack", rotom, state.players[1].active_pokemon, 0, state)
	rotom.attached_tool = _card("Tool A", "Tool", 0)
	state.players[0].bench[0].attached_tool = _card("Tool B", "Tool", 0)
	var bonus := int(accessory[0].call("get_damage_bonus", rotom, state)) if not accessory.is_empty() else -999
	return run_checks([
		assert_false(astonish.is_empty() or accessory.is_empty(), "CSV10C_226 should register both scripted attacks"),
		assert_eq(str(steps[0].get("visible_scope", "")) if not steps.is_empty() else "", "opponent_hand_hidden", "CSV10C_226 should not reveal opponent hand identities before selection"),
		assert_true(hidden_b in state.players[1].deck and hidden_b not in state.players[1].hand, "CSV10C_226 should shuffle the selected hidden hand card into the opponent's deck"),
		assert_eq(bonus, 30, "CSV10C_226 should make printed 30x total 60 when 2 Tools are in play"),
	])


func test_csv10c_227_zamazenta_reflects_exact_attack_damage_next_turn() -> String:
	var card := _load_card("227")
	if card == null:
		return "CSV10C_227 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var zamazenta := _slot_from_card(card, 0)
	state.players[0].active_pokemon = zamazenta
	var effects := processor.get_attack_effects_for_slot(zamazenta, 0)
	if not effects.is_empty():
		effects[0].call("execute_attack", zamazenta, state.players[1].active_pokemon, 0, state)
	state.turn_number += 1
	var opposing_attacker := state.players[1].active_pokemon
	processor.process_after_attack_damage(zamazenta, opposing_attacker, 70, state)
	return run_checks([
		assert_false(effects.is_empty(), "CSV10C_227 should register its delayed retaliation attack effect"),
		assert_eq(opposing_attacker.damage_counters, 70, "CSV10C_227 should place damage counters equal to the damage received"),
	])


func test_csv10c_228_reshiram_counts_its_damage_counters() -> String:
	var card := _load_card("228")
	if card == null:
		return "CSV10C_228 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var reshiram := _slot_from_card(card, 0)
	reshiram.damage_counters = 30
	var effects := processor.get_attack_effects_for_slot(reshiram, 0)
	var bonus := int(effects[0].call("get_damage_bonus", reshiram, _make_state())) if not effects.is_empty() else -999
	return run_checks([
		assert_false(effects.is_empty(), "CSV10C_228 should register Power Rage"),
		assert_eq(bonus, 40, "CSV10C_228 printed 20x plus bonus should total 60 for 3 damage counters"),
	])


func test_csv10c_229_230_reuse_base_print_effect_ids_and_runtime_registration() -> String:
	var yanmega := _load_card("229")
	var arboliva := _load_card("230")
	var base_yanmega := _load_card("003")
	var base_arboliva := _load_card("022")
	if yanmega == null or arboliva == null or base_yanmega == null or base_arboliva == null:
		return "CSV10C base and alternate-art cards are required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(yanmega)
	processor.register_pokemon_card(arboliva)
	var yanmega_slot := _slot_from_card(yanmega, 0)
	var arboliva_slot := _slot_from_card(arboliva, 0)
	var arboliva_first := processor.get_attack_effects_for_slot(arboliva_slot, 0)
	var arboliva_second := processor.get_attack_effects_for_slot(arboliva_slot, 1)
	var first_effect_names: Array[String] = []
	for effect: BaseEffect in arboliva_first:
		first_effect_names.append(effect.get_script().resource_path if effect.get_script() != null else effect.get_class())
	return run_checks([
		assert_eq(yanmega.effect_id, base_yanmega.effect_id, "CSV10C_229 should share CSV10C_003's effect id instead of duplicating implementation"),
		assert_eq(arboliva.effect_id, base_arboliva.effect_id, "CSV10C_230 should share CSV10C_022's effect id instead of duplicating implementation"),
		assert_not_null(processor.get_effect(yanmega.effect_id), "CSV10C_229 should resolve the shared Yanmega ex Ability"),
		assert_false(processor.get_attack_effects_for_slot(yanmega_slot, 0).is_empty(), "CSV10C_229 should resolve the shared Yanmega ex attack"),
		assert_eq(arboliva_first.size(), 1, "CSV10C_230 should resolve the shared Arboliva ex first attack once; got %s" % str(first_effect_names)),
		assert_eq(arboliva_second.size(), 1, "CSV10C_230 should resolve the shared Arboliva ex second attack once"),
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
