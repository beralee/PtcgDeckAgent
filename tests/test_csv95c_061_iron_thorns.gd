class_name TestCSV95C061IronThorns
extends TestBase

const IronThornsEffect := preload("res://scripts/effects/pokemon_effects/AttackTopDeckFutureCountDamage.gd")

const EFFECT_ID := "793ffbeb1f3e933adc889d8784f85cf1"


func test_csv95c_061_registers_first_attack_by_effect_id() -> String:
	var processor := EffectProcessor.new()
	var card := _iron_thorns()
	var slot := _make_slot(card, 0)

	processor.register_pokemon_card(card)
	var first_attack_effects := processor.get_attack_effects_for_slot(slot, 0)
	var second_attack_effects := processor.get_attack_effects_for_slot(slot, 1)
	var first_is_future_count := not first_attack_effects.is_empty() and is_instance_of(first_attack_effects[0], IronThornsEffect)

	return run_checks([
		assert_true(processor.has_attack_effect(EFFECT_ID), "CSV9.5C_061 should register Fatal Grind by API effect_id"),
		assert_eq(first_attack_effects.size(), 1, "Fatal Grind should have one top-deck Future count effect"),
		assert_true(first_is_future_count, "Fatal Grind should use AttackTopDeckFutureCountDamage"),
		assert_eq(second_attack_effects.size(), 0, "Megaton Lariat should not receive Fatal Grind's effect"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV9.5C_061 should not be marked unimplemented after registration"),
	])


func test_csv95c_061_fatal_grind_deals_70_per_future_card_revealed() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var attacker := _make_slot(_iron_thorns(), 0)
	var defender := _make_slot(_pokemon("Defender", "C", 300), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(attacker, 0, "L", 1)
	_attach_energy(attacker, 0, "C", 1)
	var future_a := CardInstance.create(_future_pokemon("Future A"), 0)
	var item := CardInstance.create(_trainer("Non Future Item"), 0)
	var future_b := CardInstance.create(_future_trainer("Future Booster Energy Capsule"), 0)
	var basic_energy := CardInstance.create(_energy("Lightning Energy", "L"), 0)
	var future_c := CardInstance.create(_future_pokemon("Future C"), 0)
	player.deck.append_array([future_a, item, future_b, basic_energy, future_c])
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var bonus := gsm.effect_processor.get_attack_damage_modifier(attacker, defender, attacker.get_attacks()[0], gsm.game_state, [], 0)
	var resolved_damage := gsm._calculate_attack_damage(attacker, defender, attacker.get_attacks()[0], 0)
	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(bonus, 140, "Fatal Grind should add the delta from printed 70 to three Future cards"),
		assert_eq(resolved_damage, 210, "Fatal Grind should preview 70 damage per Future card revealed"),
		assert_true(used, "Fatal Grind should be usable with LC attached"),
		assert_eq(defender.damage_counters, 210, "Fatal Grind should deal 210 damage for three revealed Future cards"),
		assert_true(future_a in player.discard_pile, "Revealed Future Pokemon should be discarded"),
		assert_true(future_b in player.discard_pile, "Revealed Future Trainer cards should be discarded"),
		assert_true(future_c in player.discard_pile, "All revealed Future cards should be discarded"),
		assert_false(item in player.discard_pile, "Non-Future revealed cards should not be discarded"),
		assert_false(basic_energy in player.discard_pile, "Non-Future Energy should not be discarded"),
		assert_eq(player.deck.size(), 2, "Non-Future revealed cards should return to the shuffled deck"),
		assert_true(item in player.deck, "The revealed non-Future Item should return to deck"),
		assert_true(basic_energy in player.deck, "The revealed non-Future Energy should return to deck"),
		assert_eq(player.shuffle_count, 1, "Fatal Grind should shuffle the returned non-Future cards into the deck"),
	])


func test_csv95c_061_fatal_grind_zero_future_revealed_deals_no_damage() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var attacker := _make_slot(_iron_thorns(), 0)
	var defender := _make_slot(_pokemon("Defender", "C", 300), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(attacker, 0, "L", 1)
	_attach_energy(attacker, 0, "C", 1)
	var item := CardInstance.create(_trainer("Item A"), 0)
	var supporter := CardInstance.create(_trainer("Supporter A", "Supporter"), 0)
	var energy := CardInstance.create(_energy("Lightning Energy", "L"), 0)
	player.deck.append_array([item, supporter, energy])
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var resolved_damage := gsm._calculate_attack_damage(attacker, defender, attacker.get_attacks()[0], 0)
	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(resolved_damage, 0, "Fatal Grind should not keep the parsed printed 70 when no Future cards are revealed"),
		assert_true(used, "Fatal Grind should still resolve when no Future cards are revealed"),
		assert_eq(defender.damage_counters, 0, "Fatal Grind should deal 0 damage with zero Future cards"),
		assert_eq(player.discard_pile.size(), 0, "No non-Future revealed cards should be discarded"),
		assert_eq(player.deck.size(), 3, "All revealed non-Future cards should return to deck"),
		assert_true(item in player.deck, "The Item should return to deck"),
		assert_true(supporter in player.deck, "The Supporter should return to deck"),
		assert_true(energy in player.deck, "The Energy should return to deck"),
		assert_eq(player.shuffle_count, 1, "Fatal Grind should still shuffle after revealing only non-Future cards"),
	])


func test_csv95c_061_fatal_grind_only_counts_top_five_cards() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var attacker := _make_slot(_iron_thorns(), 0)
	var defender := _make_slot(_pokemon("Defender", "C", 300), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(attacker, 0, "L", 1)
	_attach_energy(attacker, 0, "C", 1)
	var future_a := CardInstance.create(_future_pokemon("Future A"), 0)
	var item := CardInstance.create(_trainer("Non Future Item"), 0)
	var future_b := CardInstance.create(_future_trainer("Future Tool"), 0)
	var energy := CardInstance.create(_energy("Lightning Energy", "L"), 0)
	var supporter := CardInstance.create(_trainer("Supporter A", "Supporter"), 0)
	var sixth_future := CardInstance.create(_future_pokemon("Sixth Future"), 0)
	player.deck.append_array([future_a, item, future_b, energy, supporter, sixth_future])
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var resolved_damage := gsm._calculate_attack_damage(attacker, defender, attacker.get_attacks()[0], 0)
	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(resolved_damage, 140, "Fatal Grind should count only Future cards among the top five cards"),
		assert_true(used, "Fatal Grind should be usable with LC attached"),
		assert_eq(defender.damage_counters, 140, "Fatal Grind should not count the sixth deck card"),
		assert_true(future_a in player.discard_pile, "Top-five Future Pokemon should be discarded"),
		assert_true(future_b in player.discard_pile, "Top-five Future Trainer cards should be discarded"),
		assert_false(sixth_future in player.discard_pile, "The sixth Future card should not be revealed or discarded"),
		assert_true(sixth_future in player.deck, "The sixth Future card should remain in deck"),
		assert_eq(player.deck.size(), 4, "Only the two revealed Future cards should leave the deck"),
		assert_eq(player.shuffle_count, 1, "Fatal Grind should shuffle after returning non-Future revealed cards"),
	])


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state.players.clear()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func _iron_thorns() -> CardData:
	var cd := _pokemon("Iron Thorns", "L", 140)
	cd.name = "铁荆棘"
	cd.name_en = "Iron Thorns"
	cd.set_code = "CSV9.5C"
	cd.card_index = "061"
	cd.effect_id = EFFECT_ID
	cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	cd.weakness_energy = "F"
	cd.weakness_value = "x2"
	cd.retreat_cost = 3
	cd.attacks = [
		{"name": "致命碾压", "cost": "LC", "damage": "70x", "text": "Reveal the top 5 cards of your deck. This attack does 70 damage for each Future card you find there. Discard those Future cards and shuffle the other cards back into your deck.", "is_vstar_power": false},
		{"name": "百万吨金勾臂", "cost": "LLLC", "damage": "140", "text": "", "is_vstar_power": false},
	]
	return cd


func _pokemon(name: String, energy_type: String, hp: int) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = hp
	return cd


func _future_pokemon(name: String) -> CardData:
	var cd := _pokemon(name, "L", 100)
	cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	return cd


func _trainer(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	return cd


func _future_trainer(name: String) -> CardData:
	var cd := _trainer(name, "Tool")
	cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	return cd


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))
