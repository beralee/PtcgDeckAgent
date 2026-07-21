class_name TestCSV10C111To115
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, stage: String = "Basic") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 160
	card.attacks = [{"name": "Fixture Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return card


func _energy(name: String, card_type: String = "Special Energy") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	card.energy_provides = "F"
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 4
	state.current_player_index = 0
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_111_to_115_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(111, 116):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["111"].effect_id), "CSV10C_111 should register resistance bypass"),
		assert_true(processor.has_effect(cards["112"].effect_id), "CSV10C_112 should register Cynthia's Pokemon search"),
		assert_true(processor.has_attack_effect(cards["113"].effect_id), "CSV10C_113 should register both scripted attacks"),
		assert_true(processor.has_attack_effect(cards["114"].effect_id), "CSV10C_114 should register top-card keep/discard"),
		assert_true(processor.has_effect(cards["115"].effect_id), "CSV10C_115 should register Spiky Knuckle"),
		assert_true(processor.has_attack_effect(cards["115"].effect_id), "CSV10C_115 should register damage-counter scaling"),
	])


func test_csv10c_111_ignores_resistance_only() -> String:
	var processor := EffectProcessor.new()
	var card := _load_card("111")
	var attacker := _slot(card)
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var ignores_resistance := false
	var ignores_weakness := false
	for effect: BaseEffect in effects:
		if effect.has_method("ignores_resistance"):
			ignores_resistance = bool(effect.call("ignores_resistance", attacker, _state(), 0))
		if effect.has_method("ignores_weakness"):
			ignores_weakness = bool(effect.call("ignores_weakness", attacker, _state(), 0))
	return run_checks([
		assert_true(ignores_resistance, "CSV10C_111 Rock Throw should ignore Resistance"),
		assert_false(ignores_weakness, "CSV10C_111 Rock Throw should still calculate Weakness"),
	])


func test_csv10c_112_searches_only_cynthias_pokemon_once_per_turn() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("112")
	var gabite := _slot(card)
	state.players[0].active_pokemon = gabite
	var cynthia := CardInstance.create(_pokemon("竹兰的花岩怪"), 0)
	var generic := CardInstance.create(_pokemon("Generic Pokemon"), 0)
	var trainer_data := CardData.new()
	trainer_data.name = "竹兰的支援者"
	trainer_data.card_type = "Supporter"
	var named_trainer := CardInstance.create(trainer_data, 0)
	state.players[0].deck = [cynthia, generic, named_trainer]
	processor.register_pokemon_card(card)
	var ability := processor.get_effect(card.effect_id)
	var steps: Array[Dictionary] = []
	if ability != null:
		steps = ability.get_interaction_steps(gabite.get_top_card(), state)
	if ability != null:
		ability.execute_ability(gabite, 0, [{"csv10c_named_pokemon_search": [cynthia]}], state)
	return run_checks([
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1, -1], "CSV10C_112 should show the full deck and enable only Cynthia's Pokemon"),
		assert_true(cynthia in state.players[0].hand, "CSV10C_112 should put the selected Cynthia's Pokemon into hand"),
		assert_false(ability.can_use_ability(gabite, state) if ability != null else true, "CSV10C_112 should be usable only once per turn"),
	])


func test_csv10c_113_optional_draw_and_discard_all_energy() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("113")
	var garchomp := _slot(card)
	state.players[0].active_pokemon = garchomp
	for index: int in 5:
		state.players[0].deck.append(CardInstance.create(_pokemon("Draw %d" % index), 0))
	state.players[0].hand.append(CardInstance.create(_pokemon("Held"), 0))
	var energy_a := CardInstance.create(_energy("Energy A", "Basic Energy"), 0)
	var energy_b := CardInstance.create(_energy("Energy B", "Basic Energy"), 0)
	garchomp.attached_energy = [energy_a, energy_b]
	processor.register_pokemon_card(card)
	processor.execute_attack_effect(garchomp, 0, state.players[1].active_pokemon, state, [{"draw_to_hand_size_choice": ["draw"]}])
	var hand_after_draw := state.players[0].hand.size()
	processor.execute_attack_effect(garchomp, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(hand_after_draw, 6, "CSV10C_113 Spiral Dive should optionally draw until hand size 6"),
		assert_true(garchomp.attached_energy.is_empty(), "CSV10C_113 Draconic Buster should discard all attached Energy"),
		assert_true(energy_a in state.players[0].discard_pile and energy_b in state.players[0].discard_pile, "CSV10C_113 should move every attached Energy to discard"),
	])


func test_csv10c_114_reveals_top_card_and_optionally_discards_it() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("114")
	var rockruff := _slot(card)
	state.players[0].active_pokemon = rockruff
	var top_card := CardInstance.create(_pokemon("Seen Top"), 0)
	state.players[0].deck = [top_card]
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(rockruff, 0)
	var steps: Array[Dictionary] = []
	if not effects.is_empty():
		steps = effects[0].get_attack_interaction_steps(rockruff.get_top_card(), card.attacks[0], state)
	processor.execute_attack_effect(rockruff, 0, state.players[1].active_pokemon, state, [{"csv10c_top_card_choice": ["discard"]}])
	return run_checks([
		assert_eq(steps[0].get("card_items", []) if not steps.is_empty() else [], [top_card], "CSV10C_114 Dig Up should privately reveal the deck's top card"),
		assert_true(top_card in state.players[0].discard_pile, "CSV10C_114 should discard the revealed card when chosen"),
		assert_true(state.players[0].deck.is_empty(), "CSV10C_114 should remove the discarded top card from deck"),
	])


func test_csv10c_115_attaches_spiky_energy_and_scales_from_defender_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("115")
	var lycanroc := _slot(card)
	lycanroc.turn_evolved = state.turn_number
	state.players[0].active_pokemon = lycanroc
	var spiky_a := CardInstance.create(_energy("尖钉能量"), 0)
	var spiky_b := CardInstance.create(_energy("Spiky Energy"), 0)
	var other := CardInstance.create(_energy("Other Energy"), 0)
	state.players[0].discard_pile = [spiky_a, other, spiky_b]
	state.players[1].active_pokemon.damage_counters = 30
	processor.register_pokemon_card(card)
	var ability := processor.get_effect(card.effect_id)
	var steps: Array[Dictionary] = []
	if ability != null:
		steps = ability.get_interaction_steps(lycanroc.get_top_card(), state)
	if ability != null:
		ability.execute_ability(lycanroc, 0, [{"csv10c_spiky_energy": [spiky_a, spiky_b]}], state)
	var bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(lycanroc, 0):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", lycanroc, state))
	return run_checks([
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [spiky_a, spiky_b], "CSV10C_115 should enable only Spiky Energy in discard"),
		assert_eq(lycanroc.attached_energy.size(), 2, "CSV10C_115 should attach up to 2 selected Spiky Energy to itself"),
		assert_true(other in state.players[0].discard_pile, "CSV10C_115 should leave non-Spiky Energy in discard"),
		assert_eq(bonus, 120, "CSV10C_115 Spiked Fang should add 40 per damage counter on the opponent Active"),
	])
