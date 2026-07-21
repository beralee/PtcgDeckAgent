class_name TestCSV10C236To240
extends TestBase


func test_csv10c_236_240_bundle_metadata_and_assets() -> String:
	var expected := {
		"236": ["电击魔兽ex", "104442f76485b0b3e62a3f5ec7c1a73d"],
		"237": ["奇树的电肚蛙ex", "945599a057164c3c735c59a7f34461db"],
		"238": ["莉莉艾的皮皮ex", "c82dc9185c27908490f8a00cfdc75765"],
		"239": ["火箭队的超梦ex", "103a8775a94d6e7d8f151cbf680bd860"],
		"240": ["雷吉洛克ex", "a368ab722e082899d1e3c82c61e7efcf"],
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


func test_csv10c_236_electivire_hits_two_distinct_targets_and_checks_two_excess_energy() -> String:
	var card := _load_card("236")
	if card == null:
		return "CSV10C_236 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var electivire := _slot_from_card(card, 0)
	state.players[0].active_pokemon = electivire
	var first := processor.get_attack_effects_for_slot(electivire, 0)
	var second := processor.get_attack_effects_for_slot(electivire, 1)
	var target_a := state.players[1].active_pokemon
	var target_b := state.players[1].bench[0]
	var steps: Array[Dictionary] = first[0].call("get_attack_interaction_steps", electivire.get_top_card(), card.attacks[0], state) if not first.is_empty() else []
	if not first.is_empty():
		first[0].set_attack_interaction_context([{"electivire_two_targets": [target_a, target_b]}])
		first[0].call("execute_attack", electivire, target_a, 0, state)
	var damage_after_complete := [target_a.damage_counters, target_b.damage_counters]
	if not first.is_empty():
		first[0].set_attack_interaction_context([{"electivire_two_targets": [target_a]}])
		first[0].call("execute_attack", electivire, target_a, 0, state)
	for i: int in 5:
		electivire.attached_energy.append(_energy("Lightning %d" % i, "L", 0))
	var five_energy_bonus := int(second[0].call("get_damage_bonus", electivire, state)) if not second.is_empty() else -999
	electivire.attached_energy.pop_back()
	var four_energy_bonus := int(second[0].call("get_damage_bonus", electivire, state)) if not second.is_empty() else -999
	return run_checks([
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 2, "CSV10C_236 should require 2 distinct opponent Pokemon"),
		assert_eq(target_a.damage_counters, 50, "CSV10C_236 should deal 50 to the first target"),
		assert_eq(target_b.damage_counters, 50, "CSV10C_236 should deal 50 to the second target"),
		assert_eq([target_a.damage_counters, target_b.damage_counters], damage_after_complete, "CSV10C_236 should reject an incomplete explicit two-target selection"),
		assert_eq(five_energy_bonus, 100, "CSV10C_236 should add 100 with 2 Energy above its 3-Energy cost"),
		assert_eq(four_energy_bonus, 0, "CSV10C_236 should not add damage with only 1 excess Energy"),
	])


func test_csv10c_237_bellibolt_attaches_repeatedly_to_ionos_pokemon_and_locks_attack() -> String:
	var card := _load_card("237")
	if card == null:
		return "CSV10C_237 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var bellibolt := _slot_from_card(card, 0)
	var iono_target := _slot("奇树的电海燕", "L", 0)
	state.players[0].active_pokemon = bellibolt
	state.players[0].bench = [iono_target]
	var energy_a := _energy("Lightning A", "L", 0)
	var energy_b := _energy("Lightning B", "L", 0)
	state.players[0].hand = [energy_a, energy_b]
	var ability := processor.get_effect(card.effect_id)
	ability.call("execute_ability", bellibolt, 0, [{"iono_lightning_energy": [energy_a], "iono_energy_target": [iono_target]}], state)
	var usable_again := bool(ability.call("can_use_ability", bellibolt, state))
	ability.call("execute_ability", bellibolt, 0, [{"iono_lightning_energy": [energy_b], "iono_energy_target": [iono_target]}], state)
	for i: int in 4:
		bellibolt.attached_energy.append(_energy("Attack Energy %d" % i, "L", 0))
	var attack_effects := processor.get_attack_effects_for_slot(bellibolt, 0)
	attack_effects[0].call("execute_attack", bellibolt, state.players[1].active_pokemon, 0, state)
	state.turn_number += 2
	var lock_reason := RuleValidator.new().get_attack_unusable_reason(state, 0, 0, processor)
	return run_checks([
		assert_true(bool(usable_again), "CSV10C_237 Ability should remain usable again in the same turn"),
		assert_eq(iono_target.attached_energy, [energy_a, energy_b], "CSV10C_237 should attach both selected Basic Lightning Energy across repeated uses"),
		assert_true(lock_reason.contains("cannot use attacks"), "CSV10C_237 should be unable to attack during its next turn"),
	])


func test_csv10c_238_clefairy_overrides_dragon_weakness_and_counts_both_benches() -> String:
	var card := _load_card("238")
	if card == null:
		return "CSV10C_238 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var clefairy := _slot_from_card(card, 0)
	state.players[0].active_pokemon = clefairy
	state.players[0].bench = [_slot("Own Bench A", "C", 0), _slot("Own Bench B", "C", 0)]
	state.players[1].bench = [_slot("Opponent Bench", "C", 1)]
	var dragon := state.players[1].active_pokemon
	dragon.get_card_data().energy_type = "N"
	var attacks := processor.get_attack_effects_for_slot(clefairy, 0)
	var bonus := int(attacks[0].call("get_damage_bonus", clefairy, state)) if not attacks.is_empty() else -999
	return run_checks([
		assert_eq(processor.get_weakness_energy_override(clefairy, dragon, state), "P", "CSV10C_238 should change opposing Dragon Weakness to Psychic"),
		assert_eq(processor.get_weakness_value_override(clefairy, dragon, state), "x2", "CSV10C_238 should make that Weakness x2"),
		assert_eq(bonus, 60, "CSV10C_238 should add 20 for each Pokemon on both Benches"),
	])


func test_csv10c_239_mewtwo_requires_four_rocket_pokemon_and_discards_two_bench_energy() -> String:
	var card := _load_card("239")
	if card == null:
		return "CSV10C_239 bundled card is required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var mewtwo := _slot_from_card(card, 0)
	var rocket_a := _slot("火箭队的喵喵", "C", 0)
	var rocket_b := _slot("火箭队的小拉达", "C", 0)
	state.players[0].active_pokemon = mewtwo
	state.players[0].bench = [rocket_a, rocket_b]
	for i: int in 3:
		mewtwo.attached_energy.append(_energy("Psychic %d" % i, "P", 0))
	var blocked_reason := RuleValidator.new().get_attack_unusable_reason(state, 0, 0, processor)
	var rocket_c := _slot("火箭队的瓦斯弹", "C", 0)
	state.players[0].bench.append(rocket_c)
	var allowed_reason := RuleValidator.new().get_attack_unusable_reason(state, 0, 0, processor)
	var bench_energy_a := _energy("Bench A", "D", 0)
	var bench_energy_b := _energy("Bench B", "P", 0)
	rocket_a.attached_energy.append(bench_energy_a)
	rocket_b.attached_energy.append(bench_energy_b)
	var attacks := processor.get_attack_effects_for_slot(mewtwo, 0)
	if not attacks.is_empty():
		attacks[0].set_attack_interaction_context([{"mewtwo_discard_bench_energy": [bench_energy_a, bench_energy_b]}])
	var bonus := int(attacks[0].call("get_damage_bonus", mewtwo, state)) if not attacks.is_empty() else -999
	if not attacks.is_empty():
		attacks[0].call("execute_attack", mewtwo, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_true(blocked_reason.contains("4"), "CSV10C_239 should block attacking with fewer than 4 Team Rocket Pokemon"),
		assert_eq(allowed_reason, "", "CSV10C_239 should allow attacking with 4 Team Rocket Pokemon"),
		assert_eq(bonus, 120, "CSV10C_239 should add 60 per selected Benched Energy"),
		assert_true(bench_energy_a in state.players[0].discard_pile and bench_energy_b in state.players[0].discard_pile, "CSV10C_239 should discard both selected Benched Energy"),
	])


func test_csv10c_240_regirock_reuses_base_print_effect_id_once() -> String:
	var card := _load_card("240")
	var base := _load_card("110")
	if card == null or base == null:
		return "CSV10C_240 and CSV10C_110 bundled cards are required"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var slot := _slot_from_card(card, 0)
	return run_checks([
		assert_eq(card.effect_id, base.effect_id, "CSV10C_240 should share CSV10C_110's effect id"),
		assert_eq(processor.get_attack_effects_for_slot(slot, 0).size(), 1, "CSV10C_240 first attack should resolve once"),
		assert_eq(processor.get_attack_effects_for_slot(slot, 1).size(), 1, "CSV10C_240 second attack should resolve once"),
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


func _energy(name: String, energy_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Basic Energy"
	data.energy_type = energy_type
	data.energy_provides = energy_type
	return CardInstance.create(data, owner)
