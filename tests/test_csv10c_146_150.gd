class_name TestCSV10C146To150
extends TestBase

const PunkUp = preload("res://scripts/effects/pokemon_effects/AbilityMarniesGrimmsnarlPunkUp.gd")


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "D"
	data.hp = 300
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _card(name: String, card_type: String = "Item", owner: int = 0, energy_type: String = "") -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	data.energy_provides = energy_type
	data.energy_type = energy_type
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 16
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_146_to_150_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(146, 151):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["146"].effect_id), "CSV10C_146 should register draw 1"),
		assert_false(processor.has_attack_effect(cards["147"].effect_id), "CSV10C_147 is numeric-only"),
		assert_true(processor.has_effect(cards["148"].effect_id), "CSV10C_148 should register Punk Up"),
		assert_true(processor.has_attack_effect(cards["148"].effect_id), "CSV10C_148 should register selected Bench damage"),
		assert_true(processor.has_attack_effect(cards["149"].effect_id), "CSV10C_149 should register attached Darkness Energy scaling"),
		assert_false(processor.has_attack_effect(cards["150"].effect_id), "CSV10C_150 is numeric-only"),
	])


func test_csv10c_146_draws_exactly_one_card() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var impidimp := _slot(_load_card("146"))
	state.players[0].active_pokemon = impidimp
	var first := _card("Draw One")
	var second := _card("Stay In Deck")
	state.players[0].deck = [first, second]
	processor.register_pokemon_card(impidimp.get_card_data())
	processor.execute_attack_effect(impidimp, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(state.players[0].hand, [first], "CSV10C_146 should draw the top card"),
		assert_eq(state.players[0].deck, [second], "CSV10C_146 should draw exactly 1"),
	])


func test_csv10c_148_punk_up_supports_chinese_marnie_identity_and_bench_target_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var grimmsnarl := _slot(_load_card("148"))
	grimmsnarl.turn_evolved = state.turn_number
	state.players[0].active_pokemon = grimmsnarl
	var chinese_target := _pokemon("玛俐的酷豹")
	var unrelated := _pokemon("Unrelated")
	state.players[0].bench = [chinese_target, unrelated]
	var first_energy := _card("Darkness One", "Basic Energy", 0, "D")
	var second_energy := _card("Darkness Two", "Basic Energy", 0, "D")
	var item := _card("Unrelated Item")
	state.players[0].deck = [first_energy, item, second_energy]
	var opponent_target := _pokemon("Opponent Bench", 1)
	state.players[1].bench = [opponent_target]
	processor.register_pokemon_card(grimmsnarl.get_card_data())
	var ability := processor.get_effect(grimmsnarl.get_card_data().effect_id)
	var steps: Array[Dictionary] = []
	if ability != null:
		steps.assign(ability.get_interaction_steps(grimmsnarl.get_top_card(), state))
	var used := processor.execute_ability_effect(grimmsnarl, 0, [{PunkUp.ASSIGNMENT_STEP_ID: [
		{"source": first_energy, "target": chinese_target},
		{"source": second_energy, "target": grimmsnarl},
	]}], state)
	processor.execute_attack_effect(grimmsnarl, 0, state.players[1].active_pokemon, state, [{"opponent_bench_damage_targets": [opponent_target]}])
	return run_checks([
		assert_true(used, "CSV10C_148 Punk Up should recognize Chinese Marnie's Pokemon"),
		assert_eq(steps[0].get("source_card_indices", []) if not steps.is_empty() else [], [0, -1, 1], "CSV10C_148 Punk Up should expose the full deck and only Basic Darkness Energy"),
		assert_eq(chinese_target.attached_energy, [first_energy], "CSV10C_148 should attach to the selected Chinese Marnie's Pokemon"),
		assert_eq(grimmsnarl.attached_energy, [second_energy], "CSV10C_148 should allow attaching to itself"),
		assert_true(item in state.players[0].deck, "CSV10C_148 should leave non-Energy cards in deck"),
		assert_eq(opponent_target.damage_counters, 30, "CSV10C_148 attack should deal 30 to the selected opposing Bench target"),
	])


func test_csv10c_149_adds_40_for_each_attached_darkness_energy_only() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var morpeko := _slot(_load_card("149"))
	state.players[0].active_pokemon = morpeko
	morpeko.attached_energy = [
		_card("Darkness One", "Basic Energy", 0, "D"),
		_card("Darkness Two", "Special Energy", 0, "D"),
		_card("Fire", "Basic Energy", 0, "R"),
	]
	var any_energy := _card("Rainbow", "Special Energy", 0, "ANY")
	morpeko.attached_energy.append(any_energy)
	processor.register_pokemon_card(morpeko.get_card_data())
	processor.execute_attack_effect(morpeko, 0, state.players[1].active_pokemon, state)
	return assert_eq(state.players[1].active_pokemon.damage_counters, 120, "CSV10C_149 should count Darkness and any-type Energy, but not Fire Energy")
