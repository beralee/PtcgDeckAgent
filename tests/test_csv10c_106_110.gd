class_name TestCSV10C106To110
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, stage: String = "Basic", evolves_from: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.hp = 160
	card.attacks = [{"name": "Fixture Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return card


func _energy(name: String, symbol: String, card_type: String = "Basic Energy") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_provides = symbol
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_106_to_110_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(106, 111):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["106"].effect_id), "CSV10C_106 should register 20 recoil"),
		assert_true(processor.has_attack_effect(cards["107"].effect_id), "CSV10C_107 should register opponent mill 1"),
		assert_true(processor.has_attack_effect(cards["108"].effect_id), "CSV10C_108 should register deck evolution"),
		assert_true(processor.has_effect(cards["109"].effect_id), "CSV10C_109 should register Sand Stream"),
		assert_true(processor.has_attack_effect(cards["109"].effect_id), "CSV10C_109 should register Energy discard"),
		assert_true(processor.has_attack_effect(cards["110"].effect_id), "CSV10C_110 should register both scripted attacks"),
	])


func test_csv10c_106_recoil_and_107_mill() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card106 := _load_card("106")
	var card107 := _load_card("107")
	var attacker106 := _slot(card106)
	var attacker107 := _slot(card107)
	var top_card := CardInstance.create(_pokemon("Milled Top"), 1)
	var bottom_card := CardInstance.create(_pokemon("Deck Bottom"), 1)
	state.players[1].deck = [top_card, bottom_card]
	processor.register_pokemon_card(card106)
	processor.register_pokemon_card(card107)
	processor.execute_attack_effect(attacker106, 0, state.players[1].active_pokemon, state)
	processor.execute_attack_effect(attacker107, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(attacker106.damage_counters, 20, "CSV10C_106 Take Down should deal 20 recoil"),
		assert_true(top_card in state.players[1].discard_pile, "CSV10C_107 should discard the opponent deck's top card"),
		assert_eq(state.players[1].deck, [bottom_card], "CSV10C_107 should leave the rest of the opponent deck intact"),
	])


func test_csv10c_108_evolves_only_from_a_legal_full_deck_candidate() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("108")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	var legal := CardInstance.create(_pokemon("火箭队的班基拉斯", "Stage 2", card.name), 0)
	var illegal := CardInstance.create(_pokemon("Unrelated Evolution", "Stage 2", "Someone Else"), 0)
	state.players[0].deck = [legal, illegal]
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state) if not effects.is_empty() else []
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{"csv9c_evolution_card": [legal]}])
	return run_checks([
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1], "CSV10C_108 should reveal the full deck while enabling only a legal evolution"),
		assert_eq(attacker.get_card_data().name, "火箭队的班基拉斯", "CSV10C_108 should evolve into the selected legal card"),
		assert_true(illegal in state.players[0].deck, "CSV10C_108 should leave unrelated evolutions in deck"),
	])


func test_csv10c_109_sand_stream_and_energy_discard() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("109")
	var tyranitar := _slot(card)
	state.players[0].active_pokemon = tyranitar
	var opponent_basic_bench := _slot(_pokemon("Opponent Basic"), 1)
	var opponent_evolution := _slot(_pokemon("Opponent Stage One", "Stage 1"), 1)
	state.players[1].bench = [opponent_basic_bench, opponent_evolution]
	var energy_a := CardInstance.create(_energy("Energy A", "F"), 1)
	var energy_b := CardInstance.create(_energy("Energy B", "D"), 1)
	state.players[1].active_pokemon.attached_energy = [energy_a, energy_b]
	processor.register_pokemon_card(card)
	var ability := processor.get_effect(card.effect_id)
	var damaged: Array[PokemonSlot] = []
	if ability != null:
		ability.call("process_pokemon_check", tyranitar, state, damaged)
	processor.execute_attack_effect(tyranitar, 0, state.players[1].active_pokemon, state, [{"discard_opponent_active_energy": [energy_b]}])
	return run_checks([
		assert_eq(state.players[1].active_pokemon.damage_counters, 20, "CSV10C_109 Sand Stream should place 2 counters on the opponent Active Basic"),
		assert_eq(opponent_basic_bench.damage_counters, 20, "CSV10C_109 Sand Stream should place 2 counters on opponent Benched Basics"),
		assert_eq(opponent_evolution.damage_counters, 0, "CSV10C_109 Sand Stream should not affect evolved Pokemon"),
		assert_false(energy_b in state.players[1].active_pokemon.attached_energy, "CSV10C_109 should discard the selected opponent Active Energy"),
		assert_true(energy_a in state.players[1].active_pokemon.attached_energy, "CSV10C_109 should preserve unselected Energy"),
	])


func test_csv10c_110_attaches_fighting_energy_and_only_bonuses_against_stage_two() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("110")
	var regirock := _slot(card)
	state.players[0].active_pokemon = regirock
	var fighting_a := CardInstance.create(_energy("Fighting A", "F"), 0)
	var fighting_b := CardInstance.create(_energy("Fighting B", "F"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	state.players[0].discard_pile = [fighting_a, water, fighting_b]
	processor.register_pokemon_card(card)
	var charge_effects := processor.get_attack_effects_for_slot(regirock, 0)
	var charge_steps: Array[Dictionary] = charge_effects[0].get_attack_interaction_steps(regirock.get_top_card(), card.attacks[0], state) if not charge_effects.is_empty() else []
	processor.execute_attack_effect(regirock, 0, state.players[1].active_pokemon, state, [{"discard_energy": []}])
	var explicit_zero_attached := regirock.attached_energy.size()
	processor.execute_attack_effect(regirock, 0, state.players[1].active_pokemon, state, [{
		"discard_energy": [fighting_a, fighting_b],
		"attach_target": [regirock],
	}])
	state.players[1].active_pokemon = _slot(_pokemon("Stage Two Defender", "Stage 2"), 1)
	var stage_two_bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(regirock, 1):
		if effect.has_method("get_damage_bonus"):
			stage_two_bonus += int(effect.call("get_damage_bonus", regirock, state))
	state.players[1].active_pokemon = _slot(_pokemon("Stage One Defender", "Stage 1"), 1)
	var stage_one_bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(regirock, 1):
		if effect.has_method("get_damage_bonus"):
			stage_one_bonus += int(effect.call("get_damage_bonus", regirock, state))
	return run_checks([
		assert_eq(charge_steps.size(), 1, "CSV10C_110 self-attachment UI should not ask the player to reselect Regirock as the only target"),
		assert_eq(explicit_zero_attached, 0, "CSV10C_110 should attach no Energy when the player explicitly chooses zero"),
		assert_eq(regirock.attached_energy.size(), 2, "CSV10C_110 Regi Charge should attach up to 2 selected Basic Fighting Energy"),
		assert_true(water in state.players[0].discard_pile, "CSV10C_110 should leave non-Fighting Energy in discard"),
		assert_eq(stage_two_bonus, 140, "CSV10C_110 Giant Rock should add 140 against Stage 2 Pokemon"),
		assert_eq(stage_one_bonus, 0, "CSV10C_110 Giant Rock should not bonus against Stage 1 Pokemon"),
	])
