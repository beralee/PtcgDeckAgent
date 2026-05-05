class_name TestFullLibrarySearchPokemonUI
extends TestBase

const AbilityOnBenchEnterScript = preload("res://scripts/effects/pokemon_effects/AbilityOnBenchEnter.gd")
const AbilitySearchAnyScript = preload("res://scripts/effects/pokemon_effects/AbilitySearchAny.gd")
const AbilitySearchBasicWaterEnergyActiveScript = preload("res://scripts/effects/pokemon_effects/AbilitySearchBasicWaterEnergyActive.gd")
const AbilitySearchPokemonToBenchScript = preload("res://scripts/effects/pokemon_effects/AbilitySearchPokemonToBench.gd")


func test_miraidon_tandem_unit_shows_full_deck_with_disabled_non_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.hand.clear()
	player.deck.clear()
	var legal_a := CardInstance.create(_make_basic_pokemon_data("Lightning Basic A", "L"), 0)
	var wrong_type := CardInstance.create(_make_basic_pokemon_data("Colorless Basic", "C"), 0)
	var wrong_stage := CardInstance.create(_make_pokemon_data("Lightning Stage 1", "L", "Stage 1"), 0)
	var wrong_card_type := CardInstance.create(_make_energy_data("Lightning Energy", "L"), 0)
	var legal_b := CardInstance.create(_make_basic_pokemon_data("Lightning Basic B", "L"), 0)
	player.deck.append_array([legal_a, wrong_type, wrong_stage, wrong_card_type, legal_b])

	var effect := AbilitySearchPokemonToBenchScript.new("L", 2)
	var steps: Array[Dictionary] = effect.get_interaction_steps(player.active_pokemon.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_ability(player.active_pokemon, 0, [{
		"bench_pokemon": [legal_b, wrong_type, legal_a],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Tandem Unit should expose one search step"),
		_assert_full_deck_step_shape(step, 5, 2, [0, -1, -1, -1, 1], "Tandem Unit"),
		assert_eq(_pokemon_names(player.bench), ["Lightning Basic B", "Lightning Basic A"], "Only selected legal Lightning Basic Pokemon should be benched"),
		assert_true(wrong_type in player.deck, "Disabled non-Lightning Pokemon must remain in the deck"),
		assert_true(wrong_stage in player.deck, "Disabled non-Basic Pokemon must remain in the deck"),
		assert_true(wrong_card_type in player.deck, "Disabled non-Pokemon card must remain in the deck"),
	])


func test_chien_pao_shivery_chill_shows_full_deck_with_disabled_non_water_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var water_a := CardInstance.create(_make_energy_data("Water Energy A", "W"), 0)
	var lightning := CardInstance.create(_make_energy_data("Lightning Energy", "L"), 0)
	var pokemon := CardInstance.create(_make_basic_pokemon_data("Water Pokemon", "W"), 0)
	var water_b := CardInstance.create(_make_energy_data("Water Energy B", "W"), 0)
	player.deck.append_array([water_a, lightning, pokemon, water_b])

	var effect := AbilitySearchBasicWaterEnergyActiveScript.new(2)
	var steps: Array[Dictionary] = effect.get_interaction_steps(player.active_pokemon.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_ability(player.active_pokemon, 0, [{
		"search_water_energy": [water_b, lightning, water_a],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Shivery Chill should expose one search step"),
		_assert_full_deck_step_shape(step, 4, 2, [0, -1, -1, 1], "Shivery Chill"),
		assert_true(water_a in player.hand and water_b in player.hand, "Selected legal Water Energy should move to hand"),
		assert_true(lightning in player.deck, "Disabled non-Water Energy must remain in the deck"),
		assert_true(pokemon in player.deck, "Disabled non-Energy card must remain in the deck"),
	])


func test_lumineon_luminous_sign_shows_full_deck_with_disabled_non_supporters() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var item := CardInstance.create(_make_trainer_data("Nest Ball", "Item"), 0)
	var supporter_a := CardInstance.create(_make_trainer_data("Arven", "Supporter"), 0)
	var pokemon := CardInstance.create(_make_basic_pokemon_data("Bench Pokemon", "W"), 0)
	var supporter_b := CardInstance.create(_make_trainer_data("Boss Orders", "Supporter"), 0)
	player.deck.append_array([item, supporter_a, pokemon, supporter_b])

	var effect := AbilityOnBenchEnterScript.new("search_supporter")
	var steps: Array[Dictionary] = effect.get_interaction_steps(player.active_pokemon.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_ability(player.active_pokemon, 0, [{
		"supporter_card": [supporter_b, item],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Luminous Sign should expose one search step"),
		_assert_full_deck_step_shape(step, 4, 2, [-1, 0, -1, 1], "Luminous Sign"),
		assert_true(supporter_b in player.hand, "Selected legal Supporter should move to hand"),
		assert_true(item in player.deck, "Disabled Item must remain in the deck"),
		assert_true(pokemon in player.deck, "Disabled Pokemon must remain in the deck"),
		assert_true(supporter_a in player.deck, "Unselected legal Supporter should remain in the deck"),
	])


func test_pidgeot_quick_search_marks_any_card_search_as_own_full_deck() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var item := CardInstance.create(_make_trainer_data("Rare Candy", "Item"), 0)
	var pokemon := CardInstance.create(_make_basic_pokemon_data("Charmander", "R"), 0)
	var energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.deck.append_array([item, pokemon, energy])

	var effect := AbilitySearchAnyScript.new(1, true, false, "ability_search_any_quick_search")
	var steps: Array[Dictionary] = effect.get_interaction_steps(player.active_pokemon.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_ability(player.active_pokemon, 0, [{
		"search_cards": [pokemon],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Quick Search should expose one search step"),
		_assert_full_deck_step_shape(step, 3, 3, [0, 1, 2], "Quick Search"),
		assert_eq(int(step.get("max_select", -1)), 1, "Quick Search should still select only one card"),
		assert_true(pokemon in player.hand, "Selected legal card should move to hand"),
		assert_true(item in player.deck and energy in player.deck, "Unselected legal cards should remain in the deck"),
		assert_eq(int(state.shared_turn_flags.get("ability_search_any_quick_search_0", -1)), state.turn_number, "Quick Search should keep its shared once-per-turn flag"),
	])


func test_arceus_starbirth_marks_any_card_search_as_own_full_deck_and_filters_off_deck_cards() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var trainer := CardInstance.create(_make_trainer_data("Ultra Ball", "Item"), 0)
	var pokemon := CardInstance.create(_make_basic_pokemon_data("Arceus V", "C"), 0)
	var energy := CardInstance.create(_make_energy_data("Double Turbo Energy", "C", "Special Energy"), 0)
	var supporter := CardInstance.create(_make_trainer_data("Professor Research", "Supporter"), 0)
	var off_deck_card := CardInstance.create(_make_trainer_data("Off Deck Card", "Item"), 0)
	player.deck.append_array([trainer, pokemon, energy, supporter])

	var effect := AbilitySearchAnyScript.new(2, true, true)
	var steps: Array[Dictionary] = effect.get_interaction_steps(player.active_pokemon.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_ability(player.active_pokemon, 0, [{
		"search_cards": [energy, off_deck_card, trainer],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Starbirth should expose one search step"),
		_assert_full_deck_step_shape(step, 4, 4, [0, 1, 2, 3], "Starbirth"),
		assert_eq(int(step.get("max_select", -1)), 2, "Starbirth should still select at most two cards"),
		assert_true(energy in player.hand and trainer in player.hand, "Selected legal deck cards should move to hand"),
		assert_false(off_deck_card in player.hand, "Off-deck cards injected into the context must be ignored"),
		assert_true(pokemon in player.deck and supporter in player.deck, "Unselected legal cards should remain in the deck"),
		assert_true(state.vstar_power_used[0], "Starbirth should still consume the VSTAR power"),
	])


func _assert_full_deck_step_shape(
	step: Dictionary,
	visible_count: int,
	selectable_count: int,
	card_indices: Array,
	card_name: String
) -> String:
	var visible_cards: Array = step.get("card_items", [])
	var legal_items: Array = step.get("items", [])
	var actual_indices: Array = step.get("card_indices", [])
	var labels: Array = step.get("choice_labels", [])
	return run_checks([
		assert_eq(str(step.get("visible_scope", "")), "own_full_deck", "%s should declare own_full_deck visibility" % card_name),
		assert_eq(visible_cards.size(), visible_count, "%s should show every card in the searched deck" % card_name),
		assert_eq(legal_items.size(), selectable_count, "%s should keep legal selectable items separate" % card_name),
		assert_eq(actual_indices, card_indices, "%s should map visible cards to legal item indices and disable illegal cards" % card_name),
		assert_eq(labels.size(), visible_count, "%s should label every visible card" % card_name),
		assert_eq(str(step.get("card_disabled_badge", "")), "不可选", "%s should mark disabled visible cards" % card_name),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = 0
	state.turn_number = 2
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Active %d" % pi, "C"), pi))
		active.turn_played = 0
		player.active_pokemon = active
		state.players.append(player)
	return state


func _make_pokemon_data(name: String, energy_type: String, stage: String = "Basic", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	return cd


func _make_basic_pokemon_data(name: String, energy_type: String, hp: int = 100) -> CardData:
	return _make_pokemon_data(name, energy_type, "Basic", hp)


func _make_energy_data(
	name: String,
	energy_type: String,
	card_type: String = "Basic Energy"
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.energy_type = energy_type
	return cd


func _make_trainer_data(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _pokemon_names(slots: Array) -> Array[String]:
	var names: Array[String] = []
	for slot: PokemonSlot in slots:
		names.append(slot.get_pokemon_name())
	return names
