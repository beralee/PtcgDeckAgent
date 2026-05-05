class_name TestFullLibrarySearchTrainerItemsUI
extends TestBase


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


func _make_state_with_deck(deck_cards: Array) -> GameState:
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


func _make_pokemon_data(
	name: String,
	stage: String = "Basic",
	energy_type: String = "C",
	tags: PackedStringArray = PackedStringArray()
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = 90
	cd.energy_type = energy_type
	cd.is_tags = tags
	return cd


func _make_trainer_data(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _make_energy_data(name: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = "R"
	return cd


func _full_deck_step_checks(
	step: Dictionary,
	expected_card_items: Array,
	expected_items: Array,
	expected_indices: Array,
	step_id: String,
	card_name: String
) -> Array[String]:
	return [
		assert_eq(str(step.get("id", "")), step_id, "%s should keep the search step id stable" % card_name),
		assert_eq(step.get("items", []), expected_items, "%s items must contain only legal selectable candidates" % card_name),
		assert_eq(step.get("card_items", []), expected_card_items, "%s card_items must expose the complete own deck" % card_name),
		assert_gt((step.get("card_items", []) as Array).size(), (step.get("items", []) as Array).size(), "%s should show more cards than are selectable" % card_name),
		assert_eq(step.get("card_indices", []), expected_indices, "%s card_indices must map non-candidates to -1" % card_name),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "%s must declare own_full_deck visibility" % card_name),
		assert_eq((step.get("labels", []) as Array).size(), expected_items.size(), "%s labels should describe only legal selectable candidates" % card_name),
		assert_eq((step.get("choice_labels", []) as Array).size(), expected_card_items.size(), "%s choice_labels should describe every visible deck card" % card_name),
	]


func _append_search_step_checks(
	checks: Array[String],
	step: Dictionary,
	expected_card_items: Array,
	expected_items: Array,
	expected_indices: Array,
	step_id: String,
	card_name: String
) -> void:
	checks.append_array(_full_deck_step_checks(
		step,
		expected_card_items,
		expected_items,
		expected_indices,
		step_id,
		card_name
	))


func _find_step(steps: Array[Dictionary], step_id: String) -> Dictionary:
	for step: Dictionary in steps:
		if str(step.get("id", "")) == step_id:
			return step
	return {}


func test_capturing_aroma_tails_full_deck_visible_and_execution_ignores_evolution() -> String:
	var evolution := CardInstance.create(_make_pokemon_data("Aroma Stage 1", "Stage 1"), 0)
	var basic := CardInstance.create(_make_pokemon_data("Aroma Basic", "Basic"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Aroma Item"), 0)
	var state := _make_state_with_deck([evolution, basic, deck_item])
	var player: PlayerState = state.players[0]
	var effect := EffectCapturingAroma.new(RiggedCoinFlipper.new([false]))
	var card := CardInstance.create(_make_trainer_data("Capturing Aroma"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{
		"searched_pokemon": [basic, evolution],
	}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [basic], [-1, 0, -1], "searched_pokemon", "Capturing Aroma")
	checks.append(assert_eq(bool(step.get("wait_for_coin_animation", false)), true, "Capturing Aroma must preserve the coin animation wait flag"))
	checks.append(assert_true(basic in player.hand, "Capturing Aroma tails should move the selected Basic Pokemon to hand"))
	checks.append(assert_true(evolution in player.deck, "Capturing Aroma tails must ignore the visible-only Evolution Pokemon"))
	checks.append(assert_false(evolution in player.hand, "Capturing Aroma must never move a disabled visible-only Evolution Pokemon"))
	return run_checks(checks)


func test_hyper_aroma_full_deck_visible_and_execution_ignores_non_stage_one() -> String:
	var basic := CardInstance.create(_make_pokemon_data("Hyper Basic", "Basic"), 0)
	var stage_one_a := CardInstance.create(_make_pokemon_data("Hyper Stage 1 A", "Stage 1"), 0)
	var stage_two := CardInstance.create(_make_pokemon_data("Hyper Stage 2", "Stage 2"), 0)
	var stage_one_b := CardInstance.create(_make_pokemon_data("Hyper Stage 1 B", "Stage 1"), 0)
	var state := _make_state_with_deck([basic, stage_one_a, stage_two, stage_one_b])
	var player: PlayerState = state.players[0]
	var effect := EffectHyperAroma.new()
	var card := CardInstance.create(_make_trainer_data("Hyper Aroma"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{
		"search_cards": [basic, stage_one_b, stage_two],
	}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [stage_one_a, stage_one_b], [-1, 0, -1, 1], "search_cards", "Hyper Aroma")
	checks.append(assert_true(stage_one_b in player.hand, "Hyper Aroma should move the legal Stage 1 selected after visible-only cards"))
	checks.append(assert_true(basic in player.deck, "Hyper Aroma must ignore the visible-only Basic Pokemon"))
	checks.append(assert_true(stage_two in player.deck, "Hyper Aroma must ignore the visible-only Stage 2 Pokemon"))
	return run_checks(checks)


func test_techno_radar_full_deck_visible_and_execution_ignores_non_future() -> String:
	var normal_pokemon := CardInstance.create(_make_pokemon_data("Radar Normal", "Basic"), 0)
	var future_a := CardInstance.create(_make_pokemon_data("Radar Future A", "Basic", "L", PackedStringArray([CardData.FUTURE_TAG])), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Radar Item"), 0)
	var future_b := CardInstance.create(_make_pokemon_data("Radar Future B", "Basic", "P", PackedStringArray([CardData.FUTURE_TAG])), 0)
	var state := _make_state_with_deck([normal_pokemon, future_a, deck_item, future_b])
	var player: PlayerState = state.players[0]
	var radar_card := CardInstance.create(_make_trainer_data("Techno Radar"), 0)
	var discard_card := CardInstance.create(_make_trainer_data("Radar Discard"), 0)
	player.hand.append_array([radar_card, discard_card])
	var effect := EffectTechnoRadar.new()

	var steps: Array[Dictionary] = effect.get_interaction_steps(radar_card, state)
	var step: Dictionary = _find_step(steps, "search_future_pokemon")
	var visible_deck := player.deck.duplicate()

	effect.execute(radar_card, [{
		"discard_cards": [discard_card],
		"search_future_pokemon": [normal_pokemon, future_b, deck_item],
	}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [future_a, future_b], [-1, 0, -1, 1], "search_future_pokemon", "Techno Radar")
	checks.append(assert_true(discard_card in player.discard_pile, "Techno Radar should still pay its one-card discard cost"))
	checks.append(assert_true(future_b in player.hand, "Techno Radar should move the legal Future Pokemon"))
	checks.append(assert_true(normal_pokemon in player.deck, "Techno Radar must ignore visible-only non-Future Pokemon"))
	checks.append(assert_true(deck_item in player.deck, "Techno Radar must ignore visible-only non-Pokemon cards"))
	return run_checks(checks)


func test_secret_box_full_deck_visible_and_execution_ignores_wrong_categories() -> String:
	var item := CardInstance.create(_make_trainer_data("Secret Item", "Item"), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Secret Pokemon", "Basic"), 0)
	var tool := CardInstance.create(_make_trainer_data("Secret Tool", "Tool"), 0)
	var energy := CardInstance.create(_make_energy_data("Secret Energy"), 0)
	var supporter := CardInstance.create(_make_trainer_data("Secret Supporter", "Supporter"), 0)
	var stadium := CardInstance.create(_make_trainer_data("Secret Stadium", "Stadium"), 0)
	var state := _make_state_with_deck([item, pokemon, tool, energy, supporter, stadium])
	var player: PlayerState = state.players[0]
	var box_card := CardInstance.create(_make_trainer_data("Secret Box"), 0)
	var discard_a := CardInstance.create(_make_trainer_data("Discard A"), 0)
	var discard_b := CardInstance.create(_make_trainer_data("Discard B"), 0)
	var discard_c := CardInstance.create(_make_trainer_data("Discard C"), 0)
	player.hand.append_array([box_card, discard_a, discard_b, discard_c])
	var effect := EffectSecretBox.new()

	var steps: Array[Dictionary] = effect.get_interaction_steps(box_card, state)
	var visible_deck := player.deck.duplicate()

	effect.execute(box_card, [{
		"discard_cards": [discard_a, discard_b, discard_c],
		"search_item": [item, pokemon],
		"search_tool": [tool, energy],
		"search_supporter": [supporter, item],
		"search_stadium": [stadium, pokemon],
	}], state)

	var checks: Array[String] = []
	_append_search_step_checks(checks, _find_step(steps, "search_item"), visible_deck, [item], [0, -1, -1, -1, -1, -1], "search_item", "Secret Box item")
	_append_search_step_checks(checks, _find_step(steps, "search_tool"), visible_deck, [tool], [-1, -1, 0, -1, -1, -1], "search_tool", "Secret Box tool")
	_append_search_step_checks(checks, _find_step(steps, "search_supporter"), visible_deck, [supporter], [-1, -1, -1, -1, 0, -1], "search_supporter", "Secret Box supporter")
	_append_search_step_checks(checks, _find_step(steps, "search_stadium"), visible_deck, [stadium], [-1, -1, -1, -1, -1, 0], "search_stadium", "Secret Box stadium")
	checks.append(assert_true(item in player.hand and tool in player.hand and supporter in player.hand and stadium in player.hand, "Secret Box should move selected legal category cards"))
	checks.append(assert_true(pokemon in player.deck, "Secret Box must ignore visible-only Pokemon cards"))
	checks.append(assert_true(energy in player.deck, "Secret Box must ignore visible-only Energy cards"))
	checks.append(assert_eq(player.discard_pile.size(), 3, "Secret Box should still pay its three-card discard cost"))
	return run_checks(checks)


func test_arven_full_deck_visible_and_execution_ignores_wrong_categories() -> String:
	var item := CardInstance.create(_make_trainer_data("Arven Item", "Item"), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Arven Pokemon", "Basic"), 0)
	var tool := CardInstance.create(_make_trainer_data("Arven Tool", "Tool"), 0)
	var energy := CardInstance.create(_make_energy_data("Arven Energy"), 0)
	var state := _make_state_with_deck([item, pokemon, tool, energy])
	var player: PlayerState = state.players[0]
	var effect := EffectArven.new()
	var card := CardInstance.create(_make_trainer_data("Arven", "Supporter"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var visible_deck := player.deck.duplicate()

	effect.execute(card, [{
		"search_item": [item, pokemon],
		"search_tool": [tool, energy],
	}], state)

	var checks: Array[String] = []
	_append_search_step_checks(checks, _find_step(steps, "search_item"), visible_deck, [item], [0, -1, -1, -1], "search_item", "Arven item")
	_append_search_step_checks(checks, _find_step(steps, "search_tool"), visible_deck, [tool], [-1, -1, 0, -1], "search_tool", "Arven tool")
	checks.append(assert_true(item in player.hand and tool in player.hand, "Arven should move selected legal Item and Tool cards"))
	checks.append(assert_true(pokemon in player.deck, "Arven must ignore visible-only Pokemon cards"))
	checks.append(assert_true(energy in player.deck, "Arven must ignore visible-only Energy cards"))
	return run_checks(checks)
