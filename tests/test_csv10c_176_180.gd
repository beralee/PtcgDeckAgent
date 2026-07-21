class_name TestCSV10C176To180
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon(name: String, mechanic: String = "", owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.mechanic = mechanic
	data.hp = 300
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 27
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, "", owner)
		state.players.append(player)
	return state


func test_csv10c_176_to_180_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(176, 181):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_false(processor.has_effect(cards["176"].effect_id) or processor.has_attack_effect(cards["176"].effect_id), "CSV10C_176 should remain numeric-only"),
		assert_false(processor.has_effect(cards["177"].effect_id) or processor.has_attack_effect(cards["177"].effect_id), "CSV10C_177 should remain numeric-only"),
		assert_true(processor.has_attack_effect(cards["178"].effect_id), "CSV10C_178 should register the self-switch attack"),
		assert_true(processor.has_attack_effect(cards["179"].effect_id), "CSV10C_179 should register both attack effects"),
		assert_true(processor.has_attack_effect(cards["180"].effect_id), "CSV10C_180 should register draw 1"),
	])


func test_csv10c_178_switches_with_the_explicitly_selected_bench_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var dunsparce := _slot(_load_card("178"))
	var first := _pokemon("First Bench")
	var selected := _pokemon("Selected Bench")
	state.players[0].active_pokemon = dunsparce
	state.players[0].bench = [first, selected]
	processor.register_pokemon_card(dunsparce.get_card_data())
	processor.execute_attack_effect(dunsparce, 0, state.players[1].active_pokemon, state, [{"switch_target": [selected]}])
	return run_checks([
		assert_eq(state.players[0].active_pokemon, selected, "CSV10C_178 should promote the selected bench Pokemon"),
		assert_eq(state.players[0].bench[1], dunsparce, "CSV10C_178 should move itself into the selected bench slot"),
	])


func test_csv10c_179_counts_all_opposing_pokemon_ex_and_only_first_attack_scales() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var dudunsparce := _slot(_load_card("179"))
	state.players[0].active_pokemon = dudunsparce
	state.players[1].active_pokemon = _pokemon("Opponent Active ex", "ex", 1)
	state.players[1].bench = [
		_pokemon("Opponent Bench ex", "ex", 1),
		_pokemon("Opponent Plain", "", 1),
	]
	processor.register_pokemon_card(dudunsparce.get_card_data())
	var first_bonus := _damage_bonus(processor, dudunsparce, 0, state)
	var second_bonus := _damage_bonus(processor, dudunsparce, 1, state)
	return run_checks([
		assert_eq(first_bonus, 60, "CSV10C_179 printed 60x should add 60 for the second opposing Pokemon ex"),
		assert_eq(second_bonus, 0, "CSV10C_179 second attack should not inherit the Pokemon ex count"),
		assert_false(processor.attack_ignores_defender_effects(dudunsparce, 0, state), "CSV10C_179 first attack should respect defender effects"),
		assert_true(processor.attack_ignores_defender_effects(dudunsparce, 1, state), "CSV10C_179 second attack should ignore defender effects"),
	])


func test_csv10c_180_draws_exactly_one_card() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var noibat := _slot(_load_card("180"))
	state.players[0].active_pokemon = noibat
	var drawn_data := CardData.new()
	drawn_data.name = "Drawn"
	drawn_data.card_type = "Item"
	var drawn := CardInstance.create(drawn_data, 0)
	state.players[0].deck = [drawn]
	processor.register_pokemon_card(noibat.get_card_data())
	processor.execute_attack_effect(noibat, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(state.players[0].hand, [drawn], "CSV10C_180 should draw the top card"),
		assert_true(state.players[0].deck.is_empty(), "CSV10C_180 should draw exactly one card"),
	])


func _damage_bonus(processor: EffectProcessor, attacker: PokemonSlot, attack_index: int, state: GameState) -> int:
	var total := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, attack_index):
		if effect.has_method("get_damage_bonus"):
			total += int(effect.call("get_damage_bonus", attacker, state))
	return total
