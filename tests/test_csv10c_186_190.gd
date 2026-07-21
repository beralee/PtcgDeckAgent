class_name TestCSV10C186To190
extends TestBase


const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 300
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _card(name: String, card_type: String = "Item", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _energy(owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = "Basic Energy"
	data.card_type = "Basic Energy"
	data.energy_type = "C"
	data.energy_provides = "C"
	return CardInstance.create(data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 29
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_186_to_190_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(186, 191):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		if cards[index].card_type == "Pokemon":
			processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_false(processor.has_effect(cards["186"].effect_id) or processor.has_attack_effect(cards["186"].effect_id), "CSV10C_186 should remain numeric-only"),
		assert_true(processor.has_effect(cards["187"].effect_id), "CSV10C_187 should register its evolve-triggered gust Ability"),
		assert_true(processor.has_attack_effect(cards["188"].effect_id), "CSV10C_188 should register its prize-count failure gate"),
		assert_true(processor.has_effect(cards["189"].effect_id), "CSV10C_189 should register heal-then-discard-Energy"),
		assert_true(processor.has_effect(cards["190"].effect_id), "CSV10C_190 should alias the existing N's PP Up implementation"),
	])


func test_csv10c_187_gusts_the_explicit_opponent_bench_target_only_after_hand_evolution() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var dubwool := _slot(_load_card("187"))
	state.players[0].active_pokemon = dubwool
	var old_active := state.players[1].active_pokemon
	var first := _pokemon("First Bench", 1)
	var selected := _pokemon("Selected Bench", 1)
	state.players[1].bench = [first, selected]
	processor.register_pokemon_card(dubwool.get_card_data())
	var blocked_before_evolution := not processor.can_use_ability(dubwool, state)
	H.mark_evolved_from_hand(dubwool, state)
	var used := processor.execute_ability_effect(dubwool, 0, [{"csv10c_challenge_horn_target": [selected]}], state)
	var zero_state := _state()
	var zero_dubwool := _slot(_load_card("187"))
	zero_state.players[0].active_pokemon = zero_dubwool
	zero_state.players[1].bench = [_pokemon("Optional Target", 1)]
	H.mark_evolved_from_hand(zero_dubwool, zero_state)
	processor.execute_ability_effect(zero_dubwool, 0, [{"csv10c_challenge_horn_target": []}], zero_state)
	return run_checks([
		assert_true(blocked_before_evolution, "CSV10C_187 should not trigger without hand evolution"),
		assert_true(used, "CSV10C_187 should resolve after evolving from hand"),
		assert_eq(state.players[1].active_pokemon, selected, "CSV10C_187 should promote the selected opposing Bench Pokemon"),
		assert_eq(state.players[1].bench[1], old_active, "CSV10C_187 should move the old Active into the selected Bench slot"),
		assert_true(zero_dubwool.has_ability_used(zero_state.turn_number), "CSV10C_187 should consume its once-only evolve trigger after declining the optional switch"),
	])


func test_csv10c_188_attack_succeeds_only_with_three_or_four_opponent_prizes() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var cramorant := _slot(_load_card("188"))
	state.players[0].active_pokemon = cramorant
	processor.register_pokemon_card(cramorant.get_card_data())
	state.players[1].prizes = [_card("P1", "Item", 1), _card("P2", "Item", 1), _card("P3", "Item", 1), _card("P4", "Item", 1)]
	var canceled_at_four := processor.attack_damage_cancelled(cramorant, 0, state.players[1].active_pokemon, state)
	state.players[1].prizes.resize(3)
	var canceled_at_three := processor.attack_damage_cancelled(cramorant, 0, state.players[1].active_pokemon, state)
	state.players[1].prizes.resize(2)
	var canceled_at_two := processor.attack_damage_cancelled(cramorant, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_false(canceled_at_four, "CSV10C_188 should deal damage when opponent has 4 prizes"),
		assert_false(canceled_at_three, "CSV10C_188 should deal damage when opponent has 3 prizes"),
		assert_true(canceled_at_two, "CSV10C_188 should fail at every other prize count"),
	])


func test_csv10c_189_heals_selected_pokemon_60_then_discards_energy_from_that_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var medicine := CardInstance.create(_load_card("189"), 0)
	var selected := state.players[0].active_pokemon
	selected.damage_counters = 90
	var selected_energy := _energy()
	selected.attached_energy = [selected_energy]
	var other := _pokemon("Other")
	other.damage_counters = 100
	var other_energy := _energy()
	other.attached_energy = [other_energy]
	state.players[0].bench = [other]
	var effect := processor.get_effect(medicine.card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(medicine, state) if effect != null else []
	var source_indices := {}
	if not steps.is_empty():
		for source_index: int in steps[0].get("source_items", []).size():
			source_indices[steps[0]["source_items"][source_index]] = source_index
	var selected_source_index := int(source_indices.get(selected_energy, -1))
	var other_source_index := int(source_indices.get(other_energy, -1))
	var excluded: Dictionary = steps[0].get("source_exclude_targets", {}) if not steps.is_empty() else {}
	var used := processor.execute_card_effect(medicine, [{"csv10c_heal_energy_assignment": [{"source": selected_energy, "target": selected}]}], state)
	return run_checks([
		assert_true(used, "CSV10C_189 should be playable with a damaged Pokemon that has Energy"),
		assert_eq(selected.damage_counters, 30, "CSV10C_189 should heal exactly 60 damage"),
		assert_true(selected.attached_energy.is_empty() and selected_energy in state.players[0].discard_pile, "CSV10C_189 should discard the selected target's Energy"),
		assert_eq(other.damage_counters, 100, "CSV10C_189 should not heal another Pokemon"),
		assert_eq(other.attached_energy, [other_energy], "CSV10C_189 should not discard Energy from another Pokemon"),
		assert_eq(excluded.get(selected_source_index, []), [1], "CSV10C_189 UI should prevent assigning the Active Pokemon's Energy to the Bench target"),
		assert_eq(excluded.get(other_source_index, []), [0], "CSV10C_189 UI should prevent assigning the Bench Pokemon's Energy to the Active target"),
	])


func test_csv10c_190_attaches_basic_energy_to_benched_chinese_n_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var pp_up := CardInstance.create(_load_card("190"), 0)
	var energy := _energy()
	state.players[0].discard_pile = [energy]
	var target := _pokemon("N的索罗亚")
	state.players[0].bench = [target]
	var used := processor.execute_card_effect(pp_up, [{"ns_pp_up_assignment": [{"source": energy, "target": target}]}], state)
	return run_checks([
		assert_true(used, "CSV10C_190 should be playable for a Chinese-named N Pokemon"),
		assert_eq(target.attached_energy, [energy], "CSV10C_190 should attach the selected Basic Energy"),
		assert_false(energy in state.players[0].discard_pile, "CSV10C_190 should remove the attached Energy from discard"),
	])
