class_name TestCSV10C221To225
extends TestBase


func test_csv10c_221_225_bundle_metadata_and_assets() -> String:
	var expected := {
		"221": ["尖钉能量", "f9db949f369ecead569fb8e3adc4eaee"],
		"222": ["火箭队能量", "53341530fef1494fe72b335f06038205"],
		"223": ["蜻蜻蜓", "2027075ee9baee2e2a52bd1e1a477153"],
		"224": ["沙铃仙人掌", "a5b32602f9c443a038fef288059aeb43"],
		"225": ["小霞的可达鸭", "77717753a8889b9fc190f4b2de0e649a"],
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


func test_csv10c_221_spikemuth_energy_is_colorless_and_retaliates_from_active() -> String:
	var card := _load_card("221")
	if card == null:
		return "CSV10C_221 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	var attacker := state.players[1].active_pokemon
	var defender := state.players[0].active_pokemon
	var energy := CardInstance.create(card, 0)
	defender.attached_energy.append(energy)
	processor.apply_attack_damage_energy_reactive_effects(attacker, defender, 30, state)
	var after_active := attacker.damage_counters
	var bench_defender := state.players[0].bench[0]
	bench_defender.attached_energy.append(CardInstance.create(card, 0))
	processor.apply_attack_damage_energy_reactive_effects(attacker, bench_defender, 30, state)
	return run_checks([
		assert_eq(processor.get_energy_type(energy, state), "C", "CSV10C_221 should provide Colorless Energy"),
		assert_eq(processor.get_energy_colorless_count(energy, state), 1, "CSV10C_221 should provide exactly 1 Energy"),
		assert_eq(after_active, 20, "CSV10C_221 should place 2 damage counters on an opposing attacker after Active damage"),
		assert_eq(attacker.damage_counters, 20, "CSV10C_221 should not trigger while attached to a Benched Pokemon"),
	])


func test_csv10c_222_rocket_energy_restricts_attachment_and_pays_psychic_dark_costs() -> String:
	var card := _load_card("222")
	if card == null:
		return "CSV10C_222 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	var rocket := _slot("火箭队的超梦ex", "P", 0)
	state.players[0].active_pokemon = rocket
	var energy := CardInstance.create(card, 0)
	rocket.attached_energy.append(energy)
	var validator := RuleValidator.new()
	var pays_pd := validator.has_enough_energy(rocket, "PD", processor, state)
	var pays_pp := validator.has_enough_energy(rocket, "PP", processor, state)
	var pays_ll := validator.has_enough_energy(rocket, "LL", processor, state)
	var ordinary := state.players[0].bench[0]
	var illegal_energy := CardInstance.create(card, 0)
	ordinary.attached_energy.append(illegal_energy)
	var effect := processor.get_effect(card.effect_id)
	effect.execute(illegal_energy, [ordinary], state)
	return run_checks([
		assert_eq(processor.get_energy_colorless_count(energy, state), 2, "CSV10C_222 should provide exactly 2 Energy"),
		assert_eq(processor.get_energy_types(energy, state), PackedStringArray(["P", "D"]), "CSV10C_222 should provide Psychic or Darkness Energy"),
		assert_true(pays_pd and pays_pp, "CSV10C_222 should pay any combination of 2 Psychic/Darkness requirements"),
		assert_false(pays_ll, "CSV10C_222 should not pay Lightning requirements"),
		assert_true(illegal_energy in state.players[0].discard_pile and illegal_energy not in ordinary.attached_energy, "CSV10C_222 should discard itself when attached to a non-Team-Rocket Pokemon"),
	])


func test_csv10c_223_and_224_reuse_same_name_effects_without_duplicates() -> String:
	var yanma := _load_card("223")
	var maractus := _load_card("224")
	if yanma == null or maractus == null:
		return "CSV10C_223 and CSV10C_224 bundled cards are required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(yanma)
	processor.register_pokemon_card(maractus)
	var state := _make_state()
	var yanma_slot := _slot_from_card(yanma, 0)
	state.players[0].active_pokemon = yanma_slot
	var switch_effects := processor.get_attack_effects_for_slot(yanma_slot, 0)
	var selected := state.players[1].bench[0]
	var old_active := state.players[1].active_pokemon
	var switch_steps: Array[Dictionary] = switch_effects[0].get_attack_interaction_steps(yanma_slot.get_top_card(), yanma.attacks[0], state) if not switch_effects.is_empty() else []
	if not switch_effects.is_empty():
		switch_effects[0].set_attack_interaction_context([{"opponent_switch_target": [selected]}])
		switch_effects[0].call("execute_attack", yanma_slot, old_active, 0, state)
	var switch_succeeded := state.players[1].active_pokemon == selected
	var maractus_slot := _slot_from_card(maractus, 0)
	state.players[0].active_pokemon = maractus_slot
	var reactive := processor.get_effect(maractus.effect_id)
	if reactive != null:
		reactive.call("on_knocked_out_by_attack_damage", maractus_slot, state.players[1].active_pokemon, state)
	var retreat_effects := processor.get_attack_effects_for_slot(maractus_slot, 0)
	var protected_defender := _slot("Mist Protected", "C", 1)
	var mist := _energy("Mist Energy", "Special Energy", "C", 1)
	mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected_defender.attached_energy = [mist]
	state.players[1].active_pokemon = protected_defender
	processor.execute_attack_effect(maractus_slot, 0, protected_defender, state)
	return run_checks([
		assert_false(switch_effects.is_empty(), "CSV10C_223 should reuse the Yanma Whirlwind effect id"),
		assert_true(bool(switch_steps[0].get("opponent_chooses", false)) if not switch_steps.is_empty() else false, "CSV10C_223 switch UI must assign the choice to the defending player"),
		assert_true(switch_succeeded, "CSV10C_223 should preserve the opponent-selected switch behavior"),
		assert_not_null(reactive, "CSV10C_224 should reuse the Maractus reactive Ability effect id"),
		assert_eq(selected.damage_counters, 60, "CSV10C_224 should preserve the six-counter knockout retaliation"),
		assert_false(protected_defender.effects.any(func(entry: Dictionary) -> bool: return entry.get("type", "") == "retreat_lock"), "CSV10C_224 retreat lock should respect Mist Energy attack-effect protection"),
	])


func test_csv10c_225_psyduck_discards_bottom_then_returns_only_itself_to_deck_top() -> String:
	var card := _load_card("225")
	if card == null:
		return "CSV10C_225 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var effect := processor.get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_225 should register its Bench Ability"
	var state := _make_state()
	var psyduck := _slot_from_card(card, 0)
	var psyduck_card := psyduck.get_top_card()
	var attached_energy := _energy("Water", "Basic Energy", "W", 0)
	var attached_tool := _card("Tool", "Tool", 0)
	psyduck.attached_energy.append(attached_energy)
	psyduck.attached_tool = attached_tool
	state.players[0].bench = [psyduck]
	var top_before := _card("Old Top", "Item", 0)
	var bottom_before := _card("Old Bottom", "Item", 0)
	state.players[0].deck = [top_before, bottom_before]
	effect.call("execute_ability", psyduck, 0, [], state)
	return run_checks([
		assert_true(bottom_before in state.players[0].discard_pile, "CSV10C_225 should discard the bottom card of the deck"),
		assert_true(attached_energy in state.players[0].discard_pile and attached_tool in state.players[0].discard_pile, "CSV10C_225 should discard all attached cards"),
		assert_eq(state.players[0].deck[0], psyduck_card, "CSV10C_225 should put itself on top of the deck"),
		assert_eq(state.players[0].deck[0].card_data.name, "小霞的可达鸭", "CSV10C_225 should be the new top card"),
		assert_true(psyduck not in state.players[0].bench, "CSV10C_225 should leave the Bench"),
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
	data.hp = 100
	data.energy_type = energy_type
	return _slot_from_card(data, owner)


func _slot_from_card(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _energy(name: String, card_type: String, energy_type: String, owner: int) -> CardInstance:
	var result := _card(name, card_type, owner)
	result.card_data.energy_type = energy_type
	result.card_data.energy_provides = energy_type
	return result


func _card(name: String, card_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)
