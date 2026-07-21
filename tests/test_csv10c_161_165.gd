class_name TestCSV10C161To165
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "M"
	data.hp = 500
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _energy(name: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Basic Energy"
	data.energy_type = "M"
	data.energy_provides = "M"
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 22
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_161_to_165_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(161, 166):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["161"].effect_id), "CSV10C_161 should register Bench damage and Brave Blade lock"),
		assert_true(processor.has_attack_effect(cards["162"].effect_id), "CSV10C_162 should register retaliatory reflection"),
		assert_true(processor.has_attack_effect(cards["163"].effect_id), "CSV10C_163 should register recoil"),
		assert_true(processor.has_attack_effect(cards["164"].effect_id), "CSV10C_164 should register damage reduction"),
		assert_true(processor.has_attack_effect(cards["165"].effect_id), "CSV10C_165 should register all-Bench damage and selected Energy discard"),
	])


func test_csv10c_161_selected_bench_damage_and_second_attack_specific_lock() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var zacian := _slot(_load_card("161"))
	state.players[0].active_pokemon = zacian
	var first := _pokemon("First Bench", 1)
	var selected := _pokemon("Selected Bench", 1)
	state.players[1].bench = [first, selected]
	processor.register_pokemon_card(zacian.get_card_data())
	processor.execute_attack_effect(zacian, 0, state.players[1].active_pokemon, state, [{"bench_target": [selected]}])
	processor.execute_attack_effect(zacian, 1, state.players[1].active_pokemon, state)
	var lock: Dictionary = {}
	for entry: Dictionary in zacian.effects:
		if entry.get("type", "") == "attack_lock":
			lock = entry
	return run_checks([
		assert_eq(first.damage_counters, 0, "CSV10C_161 should honor the selected Bench target"),
		assert_eq(selected.damage_counters, 30, "CSV10C_161 should deal 30 to the selected Bench Pokemon"),
		assert_eq(lock.get("attack_index", -1), 1, "CSV10C_161 should lock only Brave Blade"),
	])


func test_csv10c_162_reflects_exact_attack_damage_during_next_opponent_turn_only() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var zamazenta := _slot(_load_card("162"))
	state.players[0].active_pokemon = zamazenta
	var opponent := state.players[1].active_pokemon
	processor.register_pokemon_card(zamazenta.get_card_data())
	processor.execute_attack_effect(zamazenta, 0, opponent, state)
	processor.process_after_attack_damage(zamazenta, opponent, 60, state)
	var same_turn_damage := opponent.damage_counters
	state.turn_number += 1
	state.current_player_index = 1
	processor.process_after_attack_damage(zamazenta, opponent, 70, state)
	var protected_state := _state()
	var protected_processor := EffectProcessor.new()
	var protected_zamazenta := _slot(_load_card("162"))
	protected_state.players[0].active_pokemon = protected_zamazenta
	var protected_attacker := protected_state.players[1].active_pokemon
	var mist_data := CardData.new()
	mist_data.name = "Mist Energy"
	mist_data.card_type = "Special Energy"
	mist_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected_attacker.attached_energy = [CardInstance.create(mist_data, 1)]
	protected_processor.register_pokemon_card(protected_zamazenta.get_card_data())
	protected_processor.execute_attack_effect(protected_zamazenta, 0, protected_attacker, protected_state)
	protected_state.turn_number += 1
	protected_state.current_player_index = 1
	protected_processor.process_after_attack_damage(protected_zamazenta, protected_attacker, 70, protected_state)
	return run_checks([
		assert_eq(same_turn_damage, 0, "CSV10C_162 should not reflect before the opponent's next turn"),
		assert_eq(opponent.damage_counters, 70, "CSV10C_162 should place damage equal to the received attack damage"),
		assert_eq(protected_attacker.damage_counters, 0, "CSV10C_162 reflected counter placement should respect Mist Energy"),
	])


func test_csv10c_163_second_attack_recoil_and_164_first_attack_reduction() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var bagon := _slot(_load_card("163"))
	state.players[0].active_pokemon = bagon
	processor.register_pokemon_card(bagon.get_card_data())
	processor.execute_attack_effect(bagon, 1, state.players[1].active_pokemon, state)
	var shelgon := _slot(_load_card("164"))
	state.players[0].active_pokemon = shelgon
	processor.register_pokemon_card(shelgon.get_card_data())
	processor.execute_attack_effect(shelgon, 0, state.players[1].active_pokemon, state)
	var reduction: Dictionary = {}
	for entry: Dictionary in shelgon.effects:
		if entry.get("type", "") == "reduce_damage_next_turn":
			reduction = entry
	return run_checks([
		assert_eq(bagon.damage_counters, 10, "CSV10C_163 second attack should deal 10 recoil"),
		assert_eq(reduction.get("amount", 0), 30, "CSV10C_164 first attack should reduce incoming damage by 30"),
	])


func test_csv10c_165_hits_all_opponent_bench_and_discards_two_selected_attached_energy() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var salamence := _slot(_load_card("165"))
	state.players[0].active_pokemon = salamence
	var first_bench := _pokemon("First Bench", 1)
	var second_bench := _pokemon("Second Bench", 1)
	state.players[1].bench = [first_bench, second_bench]
	var keep := _energy("Keep")
	var discard_one := _energy("Discard One")
	var discard_two := _energy("Discard Two")
	salamence.attached_energy = [keep, discard_one, discard_two]
	processor.register_pokemon_card(salamence.get_card_data())
	processor.execute_attack_effect(salamence, 0, state.players[1].active_pokemon, state)
	processor.execute_attack_effect(salamence, 1, state.players[1].active_pokemon, state, [{"csv10c_self_energy_discard": [discard_one]}])
	var incomplete_selection_kept_all := salamence.attached_energy.size() == 3
	processor.execute_attack_effect(salamence, 1, state.players[1].active_pokemon, state, [{"csv10c_self_energy_discard": [discard_one, discard_two]}])
	return run_checks([
		assert_eq(first_bench.damage_counters, 50, "CSV10C_165 should deal 50 to every opposing Bench Pokemon"),
		assert_eq(second_bench.damage_counters, 50, "CSV10C_165 should not stop after the first Bench Pokemon"),
		assert_true(incomplete_selection_kept_all, "CSV10C_165 should reject an incomplete explicit two-Energy discard"),
		assert_eq(salamence.attached_energy, [keep], "CSV10C_165 should keep the unselected attached Energy"),
		assert_true(discard_one in state.players[0].discard_pile and discard_two in state.players[0].discard_pile, "CSV10C_165 should discard exactly the 2 selected Energy"),
	])
