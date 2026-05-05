class_name TestFullLibrarySearchTrainerUI
extends TestBase

const EffectSearchBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectSearchBasicEnergy.gd")
const EffectLookTopCardsEffect = preload("res://scripts/effects/trainer_effects/EffectLookTopCards.gd")


func _make_pokemon_data(name: String, hp: int = 100, stage: String = "Basic") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = "C"
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_energy_data(name: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = "R"
	return cd


func _make_state_with_deck(deck_cards: Array[CardInstance]) -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	state.players[0].deck.append_array(deck_cards)
	return state


func _full_deck_step_checks(
	step: Dictionary,
	expected_card_items: Array,
	expected_items: Array,
	expected_indices: Array,
	step_id: String
) -> Array[String]:
	var card_items: Array = step.get("card_items", [])
	var labels: Array = step.get("labels", [])
	var choice_labels: Array = step.get("choice_labels", [])
	var disabled_label := ""
	var card_indices: Array = step.get("card_indices", [])
	for idx: int in card_indices.size():
		if int(card_indices[idx]) < 0 and idx < choice_labels.size():
			disabled_label = str(choice_labels[idx])
			break
	return [
		assert_eq(str(step.get("id", "")), step_id, "step id should remain stable"),
		assert_eq(step.get("items", []), expected_items, "items must contain only legal selectable cards"),
		assert_eq(labels.size(), expected_items.size(), "labels should describe only legal selectable items"),
		assert_eq(card_items, expected_card_items, "card_items must show the complete own deck"),
		assert_gt(card_items.size(), expected_items.size(), "visible deck should include disabled non-candidates"),
		assert_eq(card_indices, expected_indices, "card_indices must map non-candidates to -1"),
		assert_eq(str(step.get("visible_scope", "")), "own_full_deck", "own full-deck searches must declare visible_scope"),
		assert_eq(choice_labels.size(), expected_card_items.size(), "choice labels should describe every visible card"),
		assert_str_contains(disabled_label, "不可选", "disabled visible cards should be labeled as not selectable"),
	]


func _slot_names(player: PlayerState) -> Array[String]:
	var names: Array[String] = []
	for slot: PokemonSlot in player.bench:
		names.append(slot.get_pokemon_name())
	return names


func test_nest_ball_full_deck_visible_and_execution_ignores_non_candidate() -> String:
	var basic_a := CardInstance.create(_make_pokemon_data("Nest Basic A", 80), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var stage_one := CardInstance.create(_make_pokemon_data("Stage One", 90, "Stage 1"), 0)
	var basic_b := CardInstance.create(_make_pokemon_data("Nest Basic B", 70), 0)
	var state := _make_state_with_deck([basic_a, deck_item, stage_one, basic_b])
	var player: PlayerState = state.players[0]
	var effect := EffectNestBall.new()
	var card := CardInstance.create(_make_trainer_data("Nest Ball"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{"basic_pokemon": [deck_item, basic_b]}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [basic_a, basic_b], [0, -1, -1, 1], "basic_pokemon")
	checks.append(assert_true("Nest Basic A" in _slot_names(player), "Nest Ball should only bench a legal Basic Pokemon"))
	checks.append(assert_true(deck_item in player.deck, "Nest Ball must ignore disabled non-candidate selections"))
	checks.append(assert_false("Deck Item" in _slot_names(player), "Nest Ball must never bench a disabled card"))
	return run_checks(checks)


func test_buddy_buddy_poffin_full_deck_visible_and_execution_ignores_big_basic() -> String:
	var poffin_a := CardInstance.create(_make_pokemon_data("Poffin Basic A", 60), 0)
	var big_basic := CardInstance.create(_make_pokemon_data("Big Basic", 120), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var poffin_b := CardInstance.create(_make_pokemon_data("Poffin Basic B", 70), 0)
	var state := _make_state_with_deck([poffin_a, big_basic, deck_item, poffin_b])
	var player: PlayerState = state.players[0]
	var effect := EffectBuddyPoffin.new()
	var card := CardInstance.create(_make_trainer_data("Buddy-Buddy Poffin"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{"buddy_poffin_pokemon": [big_basic, poffin_b]}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [poffin_a, poffin_b], [0, -1, -1, 1], "buddy_poffin_pokemon")
	checks.append(assert_true("Poffin Basic B" in _slot_names(player), "Poffin should place the legal selected Basic Pokemon"))
	checks.append(assert_true(big_basic in player.deck, "Poffin must ignore HP-over-70 non-candidates"))
	checks.append(assert_false("Big Basic" in _slot_names(player), "Poffin must never bench HP-over-70 Pokemon"))
	return run_checks(checks)


func test_ultra_ball_full_deck_visible_and_execution_ignores_non_pokemon() -> String:
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var pokemon_a := CardInstance.create(_make_pokemon_data("Ultra Target A", 90), 0)
	var energy := CardInstance.create(_make_energy_data("Deck Fire"), 0)
	var pokemon_b := CardInstance.create(_make_pokemon_data("Ultra Target B", 120, "Stage 1"), 0)
	var state := _make_state_with_deck([deck_item, pokemon_a, energy, pokemon_b])
	var player: PlayerState = state.players[0]
	var discard_a := CardInstance.create(_make_trainer_data("Discard A"), 0)
	var discard_b := CardInstance.create(_make_trainer_data("Discard B"), 0)
	player.hand.append_array([discard_a, discard_b])
	var effect := EffectUltraBall.new()
	var card := CardInstance.create(_make_trainer_data("Ultra Ball"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var search_step: Dictionary = steps[1] if steps.size() > 1 else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{
		"discard_cards": [discard_a, discard_b],
		"search_pokemon": [deck_item, pokemon_b],
	}], state)

	var checks := _full_deck_step_checks(search_step, visible_deck, [pokemon_a, pokemon_b], [-1, 0, -1, 1], "search_pokemon")
	checks.append(assert_true(pokemon_a in player.hand, "Ultra Ball should add only a legal Pokemon to hand"))
	checks.append(assert_true(deck_item in player.deck, "Ultra Ball must ignore disabled non-Pokemon selections"))
	checks.append(assert_false(deck_item in player.hand, "Ultra Ball must never move a disabled card to hand"))
	return run_checks(checks)


func test_earthen_vessel_full_deck_visible_and_execution_ignores_special_energy() -> String:
	var special_energy := CardInstance.create(_make_energy_data("Special Fire", "Special Energy"), 0)
	var basic_a := CardInstance.create(_make_energy_data("Basic Fire A"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var basic_b := CardInstance.create(_make_energy_data("Basic Fire B"), 0)
	var state := _make_state_with_deck([special_energy, basic_a, deck_item, basic_b])
	var player: PlayerState = state.players[0]
	var discard_cost := CardInstance.create(_make_trainer_data("Discard Cost"), 0)
	player.hand.append(discard_cost)
	var effect := EffectSearchBasicEnergyEffect.new(2, 1)
	var card := CardInstance.create(_make_trainer_data("Earthen Vessel"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var search_step: Dictionary = steps[1] if steps.size() > 1 else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{
		"discard_cards": [discard_cost],
		"search_energy": [special_energy, basic_a, basic_b],
	}], state)

	var checks := _full_deck_step_checks(search_step, visible_deck, [basic_a, basic_b], [-1, 0, -1, 1], "search_energy")
	checks.append(assert_true(basic_a in player.hand, "Earthen Vessel should move legal Basic Energy to hand"))
	checks.append(assert_true(basic_b in player.hand, "Earthen Vessel should move a second legal Basic Energy to hand"))
	checks.append(assert_true(special_energy in player.deck, "Earthen Vessel must ignore Special Energy non-candidates"))
	return run_checks(checks)


func test_energy_search_full_deck_visible_and_execution_ignores_non_basic_energy() -> String:
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var basic_energy := CardInstance.create(_make_energy_data("Basic Lightning"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Special Lightning", "Special Energy"), 0)
	var state := _make_state_with_deck([deck_item, basic_energy, special_energy])
	var player: PlayerState = state.players[0]
	var effect := EffectSearchBasicEnergyEffect.new(1, 0)
	var card := CardInstance.create(_make_trainer_data("Energy Search"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{"search_energy": [deck_item, basic_energy]}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [basic_energy], [-1, 0, -1], "search_energy")
	checks.append(assert_true(basic_energy in player.hand, "Energy Search should move the legal Basic Energy to hand"))
	checks.append(assert_true(deck_item in player.deck, "Energy Search must ignore disabled non-Energy selections"))
	checks.append(assert_true(special_energy in player.deck, "Energy Search must ignore Special Energy non-candidates"))
	return run_checks(checks)


func test_top_n_search_is_not_upgraded_to_full_deck_visibility() -> String:
	var top_item := CardInstance.create(_make_trainer_data("Top Item"), 0)
	var top_pokemon := CardInstance.create(_make_pokemon_data("Top Pokemon", 80), 0)
	var hidden_item := CardInstance.create(_make_trainer_data("Hidden Item"), 0)
	var hidden_pokemon := CardInstance.create(_make_pokemon_data("Hidden Pokemon", 80), 0)
	var state := _make_state_with_deck([top_item, top_pokemon, hidden_item, hidden_pokemon])
	var effect := EffectLookTopCardsEffect.new(2, "Item", 1)
	var card := CardInstance.create(_make_trainer_data("Top Two Item Search"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_cards: Array = step.get("card_items", step.get("items", []))

	return run_checks([
		assert_eq(step.get("items", []), [top_item], "top-N legal pool should only include matching cards in the looked range"),
		assert_eq(visible_cards, [top_item], "top-N effects must not expose the full deck through card_items"),
		assert_false(hidden_item in visible_cards, "top-N effects must not reveal matching cards below the looked range"),
		assert_false(hidden_pokemon in visible_cards, "top-N effects must not reveal non-matching hidden cards below the looked range"),
		assert_false(str(step.get("visible_scope", "")) == "own_full_deck", "top-N effects must not be marked as own_full_deck"),
	])
