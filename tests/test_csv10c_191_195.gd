class_name TestCSV10C191To195
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon_card(name: String, owner: int = 0, stage: String = "Basic") -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.hp = 100
	return CardInstance.create(data, owner)


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	return _slot(_pokemon_card(name, owner).card_data, owner)


func _card(name: String, card_type: String = "Item", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _energy(name: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Basic Energy"
	data.energy_type = "C"
	data.energy_provides = "C"
	return CardInstance.create(data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 30
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_191_to_195_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for number: int in range(191, 196):
		var card := _load_card("%03d" % number)
		checks.append(assert_true(processor.has_effect(card.effect_id), "CSV10C_%03d should register its Item effect" % number))
	return run_checks(checks)


func test_csv10c_191_returns_up_to_five_selected_basic_energy_to_deck() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var item := CardInstance.create(_load_card("191"), 0)
	var energies: Array[CardInstance] = []
	for index: int in 6:
		energies.append(_energy("Energy %d" % index))
	var pokemon := _pokemon_card("Discard Pokemon")
	state.players[0].discard_pile.assign(energies + [pokemon])
	var selected: Array = energies.slice(0, 5)
	processor.execute_card_effect(item, [{"csv10c_recycle_discard_cards": selected}], state)
	return run_checks([
		assert_eq(state.players[0].deck.size(), 5, "CSV10C_191 should return at most 5 cards"),
		assert_true(_contains_all(state.players[0].deck, selected), "CSV10C_191 should return every selected Basic Energy"),
		assert_true(energies[5] in state.players[0].discard_pile, "CSV10C_191 should leave an unselected sixth Energy in discard"),
		assert_true(pokemon in state.players[0].discard_pile, "CSV10C_191 should not return Pokemon"),
	])


func test_csv10c_192_returns_only_selected_pokemon_to_deck() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var item := CardInstance.create(_load_card("192"), 0)
	var first := _pokemon_card("First Pokemon")
	var second := _pokemon_card("Second Pokemon")
	var energy := _energy("Energy")
	state.players[0].discard_pile = [first, second, energy]
	processor.execute_card_effect(item, [{"csv10c_recycle_discard_cards": [second]}], state)
	return run_checks([
		assert_true(second in state.players[0].deck and second not in state.players[0].discard_pile, "CSV10C_192 should return the selected Pokemon"),
		assert_true(first in state.players[0].discard_pile, "CSV10C_192 should preserve an unselected Pokemon"),
		assert_true(energy in state.players[0].discard_pile, "CSV10C_192 should not return Energy"),
	])


func test_csv10c_193_replaces_all_prizes_from_deck_top_and_puts_old_prizes_on_bottom_face_down() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var item := CardInstance.create(_load_card("193"), 0)
	var new_one := _card("New Prize 1")
	var new_two := _card("New Prize 2")
	var deck_tail := _card("Deck Tail")
	var old_one := _card("Old Prize 1")
	var old_two := _card("Old Prize 2")
	old_one.face_up = true
	old_two.face_up = true
	state.players[0].deck = [new_one, new_two, deck_tail]
	state.players[0].set_prizes([old_one, old_two])
	processor.execute_card_effect(item, [], state)
	var prize_layout := state.players[0].get_prize_layout()
	return run_checks([
		assert_eq(state.players[0].prizes, [new_one, new_two], "CSV10C_193 should make the former deck top the new prizes"),
		assert_eq(state.players[0].prizes.size(), 2, "CSV10C_193 should preserve prize count"),
		assert_eq(prize_layout, [new_one, new_two], "CSV10C_193 should rebuild prize slots with the replacement Prize cards"),
		assert_true(old_one in state.players[0].deck and old_two in state.players[0].deck, "CSV10C_193 should move every old prize to the deck bottom"),
		assert_eq(state.players[0].deck[0], deck_tail, "CSV10C_193 should preserve the remaining deck ahead of returned prizes"),
		assert_false(old_one.face_up or old_two.face_up or new_one.face_up or new_two.face_up, "CSV10C_193 should keep both old and new prizes face down"),
	])


func test_csv10c_194_heals_arvens_active_100_and_other_active_30() -> String:
	var processor := EffectProcessor.new()
	var named_state := _state()
	var named := _pokemon("派帕的獒教父ex")
	named.damage_counters = 130
	named_state.players[0].active_pokemon = named
	processor.execute_card_effect(CardInstance.create(_load_card("194"), 0), [], named_state)
	var plain_state := _state()
	plain_state.players[0].active_pokemon.damage_counters = 80
	processor.execute_card_effect(CardInstance.create(_load_card("194"), 0), [], plain_state)
	return run_checks([
		assert_eq(named.damage_counters, 30, "CSV10C_194 should heal an Arven Pokemon by 100"),
		assert_eq(plain_state.players[0].active_pokemon.damage_counters, 50, "CSV10C_194 should heal another Active Pokemon by 30"),
	])


func test_csv10c_195_puts_up_to_two_selected_basic_hop_pokemon_on_bench() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var item := CardInstance.create(_load_card("195"), 0)
	var first := _pokemon_card("赫普的毛辫羊")
	var second := _pokemon_card("Hop's Snorlax")
	var evolution := _pokemon_card("赫普的毛毛角羊", 0, "Stage 1")
	var unrelated := _pokemon_card("Unrelated")
	state.players[0].deck = [unrelated, first, evolution, second]
	var effect := processor.get_effect(item.card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(item, state) if effect != null else []
	processor.execute_card_effect(item, [{"csv10c_hop_bag_targets": [second, first]}], state)
	return run_checks([
		assert_eq(state.players[0].bench.size(), 2, "CSV10C_195 should Bench up to 2 Pokemon"),
		assert_eq(state.players[0].bench[0].get_top_card(), second, "CSV10C_195 should preserve selected placement order"),
		assert_eq(state.players[0].bench[1].get_top_card(), first, "CSV10C_195 should Bench the second selected Basic Hop Pokemon"),
		assert_true(evolution in state.players[0].deck and unrelated in state.players[0].deck, "CSV10C_195 should leave evolutions and unrelated Pokemon in deck"),
		assert_eq(steps[0].get("visible_scope", "") if not steps.is_empty() else "", "own_full_deck", "CSV10C_195 should show the full deck in its search UI"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [-1, 0, -1, 1], "CSV10C_195 should enable only Basic Hop Pokemon in the full-deck view"),
	])


func _contains_all(haystack: Array, needles: Array) -> bool:
	for item: Variant in needles:
		if item not in haystack:
			return false
	return true
