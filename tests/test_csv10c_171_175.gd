class_name TestCSV10C171To175
extends TestBase


class HeadsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(true)
		return true


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "C"
	data.hp = 500
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _card(name: String, card_type: String = "Item", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 26
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_171_to_175_registry_contract() -> String:
	var processor := EffectProcessor.new(HeadsCoinFlipper.new())
	var cards: Dictionary = {}
	for number: int in range(171, 176):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["171"].effect_id), "CSV10C_171 should register 2 coin flips"),
		assert_true(processor.has_attack_effect(cards["172"].effect_id), "CSV10C_172 should register both-player hand discard"),
		assert_true(processor.has_attack_effect(cards["173"].effect_id), "CSV10C_173 should register Rocket Supporter discard scaling"),
		assert_true(processor.has_effect(cards["174"].effect_id), "CSV10C_174 should register Reconstruct"),
		assert_true(processor.has_attack_effect(cards["174"].effect_id), "CSV10C_174 should share Rocket Supporter discard scaling"),
		assert_true(processor.has_effect(cards["175"].effect_id), "CSV10C_175 should register non-stacking Hop team boost"),
		assert_true(processor.has_attack_effect(cards["175"].effect_id), "CSV10C_175 should register 80 recoil"),
	])


func test_csv10c_171_two_heads_total_180() -> String:
	var state := _state()
	var processor := EffectProcessor.new(HeadsCoinFlipper.new())
	var kangaskhan := _slot(_load_card("171"))
	state.players[0].active_pokemon = kangaskhan
	processor.register_pokemon_card(kangaskhan.get_card_data())
	state.players[1].active_pokemon.damage_counters = 90
	processor.execute_attack_effect(kangaskhan, 1, state.players[1].active_pokemon, state)
	return assert_eq(state.players[1].active_pokemon.damage_counters, 180, "CSV10C_171 should total 180 with 2 heads")


func test_csv10c_172_each_player_discards_their_explicitly_selected_hand_card() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var porygon := _slot(_load_card("172"))
	state.players[0].active_pokemon = porygon
	var own_keep := _card("Own Keep")
	var own_discard := _card("Own Discard")
	var opponent_keep := _card("Opponent Keep", "Item", 1)
	var opponent_discard := _card("Opponent Discard", "Item", 1)
	state.players[0].hand = [own_keep, own_discard]
	state.players[1].hand = [opponent_keep, opponent_discard]
	processor.register_pokemon_card(porygon.get_card_data())
	var effect: BaseEffect = processor.get_attack_effects_for_slot(porygon, 0)[0]
	var steps := effect.get_attack_interaction_steps(porygon.get_top_card(), porygon.get_card_data().attacks[0], state)
	processor.execute_attack_effect(porygon, 0, state.players[1].active_pokemon, state, [{
		"csv10c_own_hand_discard": [own_discard],
		"csv10c_opponent_hand_discard": [opponent_discard],
	}])
	return run_checks([
		assert_false(bool(steps[0].get("opponent_chooses", false)) if steps.size() > 0 else true, "CSV10C_172 first choice should belong to the attacker"),
		assert_true(bool(steps[1].get("opponent_chooses", false)) if steps.size() > 1 else false, "CSV10C_172 second choice should belong to the opponent"),
		assert_eq(state.players[0].hand, [own_keep], "CSV10C_172 should discard the selected own hand card"),
		assert_eq(state.players[1].hand, [opponent_keep], "CSV10C_172 should discard the opponent's selected hand card"),
		assert_true(own_discard in state.players[0].discard_pile and opponent_discard in state.players[1].discard_pile, "CSV10C_172 should place both selections into their owners' discard piles"),
	])


func test_csv10c_173_and_174_count_only_named_rocket_supporters_in_own_discard() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var rocket_one := _card("火箭队的兰斯", "Supporter")
	var rocket_two := _card("Team Rocket's Ariana", "Supporter")
	var rocket_item := _card("火箭队的装置", "Item")
	var plain_supporter := _card("Plain Supporter", "Supporter")
	state.players[0].discard_pile = [rocket_one, rocket_two, rocket_item, plain_supporter]
	var porygon2 := _slot(_load_card("173"))
	state.players[0].active_pokemon = porygon2
	processor.register_pokemon_card(porygon2.get_card_data())
	var porygon2_bonus := _damage_bonus(processor, porygon2, state)
	var porygonz := _slot(_load_card("174"))
	state.players[0].active_pokemon = porygonz
	processor.register_pokemon_card(porygonz.get_card_data())
	var porygonz_bonus := _damage_bonus(processor, porygonz, state)
	return run_checks([
		assert_eq(porygon2_bonus, 20, "CSV10C_173 should add 20 to printed 20 for 2 matching Supporters"),
		assert_eq(porygonz_bonus, 20, "CSV10C_174 should use the same Rocket Supporter count"),
	])


func test_csv10c_174_discards_two_selected_cards_and_draws_one_once_per_turn() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var porygonz := _slot(_load_card("174"))
	state.players[0].active_pokemon = porygonz
	var keep := _card("Keep")
	var discard_one := _card("Discard One")
	var discard_two := _card("Discard Two")
	var drawn := _card("Drawn")
	state.players[0].hand = [keep, discard_one, discard_two]
	state.players[0].deck = [drawn]
	processor.register_pokemon_card(porygonz.get_card_data())
	var used := processor.execute_ability_effect(porygonz, 0, [{"csv10c_reconstruct_discard": [discard_one, discard_two]}], state)
	var can_repeat := processor.can_use_ability(porygonz, state)
	return run_checks([
		assert_true(used, "CSV10C_174 Reconstruct should be usable with 2 hand cards"),
		assert_eq(state.players[0].hand, [keep, drawn], "CSV10C_174 should discard 2 then draw 1"),
		assert_true(discard_one in state.players[0].discard_pile and discard_two in state.players[0].discard_pile, "CSV10C_174 should discard both selected cards"),
		assert_false(can_repeat, "CSV10C_174 should be once per turn"),
	])


func test_csv10c_175_hop_damage_boost_is_30_and_does_not_stack_and_attack_recoils_80() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var first_snorlax := _slot(_load_card("175"))
	var second_snorlax := _slot(_load_card("175"))
	var hop_attacker := _pokemon("赫普的苍响ex")
	state.players[0].active_pokemon = hop_attacker
	state.players[0].bench = [first_snorlax, second_snorlax]
	processor.register_pokemon_card(first_snorlax.get_card_data())
	var boost := processor.get_attacker_modifier(hop_attacker, state, state.players[1].active_pokemon)
	state.players[0].active_pokemon = _pokemon("Unrelated")
	var unrelated_boost := processor.get_attacker_modifier(state.players[0].active_pokemon, state, state.players[1].active_pokemon)
	state.players[0].active_pokemon = first_snorlax
	state.players[0].bench = [second_snorlax]
	processor.execute_attack_effect(first_snorlax, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(boost, 30, "CSV10C_175 should add 30 once even with multiple Generous Snorlax"),
		assert_eq(unrelated_boost, 0, "CSV10C_175 should boost only Hop's Pokemon"),
		assert_eq(first_snorlax.damage_counters, 80, "CSV10C_175 attack should deal 80 recoil"),
	])


func _damage_bonus(processor: EffectProcessor, attacker: PokemonSlot, state: GameState) -> int:
	var total := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 0):
		if effect.has_method("get_damage_bonus"):
			total += int(effect.call("get_damage_bonus", attacker, state))
	return total
