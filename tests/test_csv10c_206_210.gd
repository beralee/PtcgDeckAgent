class_name TestCSV10C206To210
extends TestBase


func test_csv10c_206_210_bundle_metadata_and_assets() -> String:
	var expected := {
		"206": ["裁判", "0a9bdf265647461dd5c6c827ffc19e61"],
		"207": ["小刚的发掘", "8d9b3076693b9f692bae94d057498720"],
		"208": ["阿响的冒险", "3b03f59349002f02a731b531dbdb4358"],
		"209": ["火箭队的雅典娜", "e3b38149675a6f8f0e606ddbe321e094"],
		"210": ["火箭队的阿波罗", "e905f4430cb382552e052cf8d926f890"],
	}
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for index: String in expected:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var card := _load_card(index)
		checks.append(assert_not_null(card, "CSV10C_%s should load from bundled JSON" % index))
		if card == null:
			continue
		checks.append(assert_eq(card.name, expected[index][0], "CSV10C_%s should preserve the API card name" % index))
		checks.append(assert_eq(card.effect_id, expected[index][1], "CSV10C_%s should preserve the API effect id" % index))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "CSV10C_%s should bundle a valid PNG" % index))
		checks.append(assert_true(card_path in manifest and image_path in manifest, "CSV10C_%s resources should be listed in the manifest" % index))
	return run_checks(checks)


func test_csv10c_206_judge_shuffles_both_hands_and_draws_four() -> String:
	var card := _load_card("206")
	if card == null:
		return "CSV10C_206 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_206 should reuse the Judge effect"
	var state := _make_state()
	_fill_hand_and_deck(state.players[0], 6, 8, 0, "Self")
	_fill_hand_and_deck(state.players[1], 5, 8, 1, "Opponent")
	effect.execute(CardInstance.create(card, 0), [], state)
	return run_checks([
		assert_eq(state.players[0].hand.size(), 4, "CSV10C_206 should leave its player with 4 cards"),
		assert_eq(state.players[1].hand.size(), 4, "CSV10C_206 should leave the opponent with 4 cards"),
	])


func test_csv10c_207_brocks_scouting_exposes_mode_and_full_library_search() -> String:
	var card := _load_card("207")
	if card == null:
		return "CSV10C_207 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_207 should register Brock's Scouting"
	var state := _make_state()
	var basic_a := _pokemon_card("Basic A", "Basic", 0)
	var basic_b := _pokemon_card("Basic B", "Basic", 0)
	var evolution := _pokemon_card("Evolution", "Stage 1", 0)
	var illegal := _card("Illegal Item", "Item", 0)
	state.players[0].deck = [basic_a, illegal, basic_b, evolution]
	var supporter := CardInstance.create(card, 0)
	var mode_steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	var search_steps: Array[Dictionary] = effect.get_followup_interaction_steps(supporter, state, {"brocks_scouting_mode": ["basic"]})
	effect.execute(supporter, [{"brocks_scouting_mode": ["basic"], "brocks_scouting_basic": [basic_a, basic_b]}], state)
	return run_checks([
		assert_eq(mode_steps.size(), 1, "CSV10C_207 should expose a Basic-or-Evolution mode choice"),
		assert_eq(search_steps.size(), 1, "CSV10C_207 should expose a follow-up search step"),
		assert_eq(str(search_steps[0].get("visible_scope", "")) if not search_steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_207 should show the complete own library"),
		assert_true(illegal in (search_steps[0].get("card_items", []) as Array) if not search_steps.is_empty() else false, "CSV10C_207 should show illegal cards as disabled"),
		assert_true(basic_a in state.players[0].hand and basic_b in state.players[0].hand, "CSV10C_207 should move up to 2 selected Basic Pokemon to hand"),
		assert_true(evolution in state.players[0].deck, "CSV10C_207 Basic mode should leave Evolution Pokemon in the deck"),
	])


func test_csv10c_208_ethans_adventure_searches_three_matching_cards() -> String:
	var card := _load_card("208")
	if card == null:
		return "CSV10C_208 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_208 should register a Supporter effect"
	var state := _make_state()
	var ethan := _pokemon_card("阿响的火球鼠", "Basic", 0)
	var fire := _energy("基本火能量", "R", 0)
	var second_fire := _energy("基本火能量2", "R", 0)
	var ordinary := _pokemon_card("火球鼠", "Basic", 0)
	var water := _energy("基本水能量", "W", 0)
	state.players[0].deck = [ordinary, ethan, water, fire, second_fire]
	var supporter := CardInstance.create(card, 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	effect.execute(supporter, [{"search_cards": [ethan, fire, second_fire]}], state)
	return run_checks([
		assert_eq(steps.size(), 1, "CSV10C_208 should expose one combined search step"),
		assert_eq(str(steps[0].get("visible_scope", "")) if not steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_208 should show the complete own library"),
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 3, "CSV10C_208 should allow up to 3 total cards"),
		assert_true(ordinary in (steps[0].get("card_items", []) as Array) and ordinary not in (steps[0].get("items", []) as Array) if not steps.is_empty() else false, "CSV10C_208 should show but disable unrelated Pokemon"),
		assert_true(ethan in state.players[0].hand and fire in state.players[0].hand and second_fire in state.players[0].hand, "CSV10C_208 should move the selected matching cards to hand"),
		assert_true(ordinary in state.players[0].deck and water in state.players[0].deck, "CSV10C_208 should preserve illegal search cards"),
	])


func test_csv10c_209_ariana_draws_to_five_or_eight_for_all_rocket_field() -> String:
	var card := _load_card("209")
	if card == null:
		return "CSV10C_209 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_209 should register a Supporter effect"
	var rocket := _make_state()
	rocket.players[0].active_pokemon = _slot("火箭队的超梦ex", 0)
	rocket.players[0].bench = [_slot("火箭队的喵喵", 0)]
	_fill_hand_and_deck(rocket.players[0], 1, 10, 0, "Rocket")
	effect.execute(CardInstance.create(card, 0), [], rocket)
	var mixed := _make_state()
	mixed.players[0].active_pokemon = _slot("火箭队的超梦ex", 0)
	mixed.players[0].bench = [_slot("普通喵喵", 0)]
	_fill_hand_and_deck(mixed.players[0], 1, 10, 0, "Mixed")
	effect.execute(CardInstance.create(card, 0), [], mixed)
	return run_checks([
		assert_eq(rocket.players[0].hand.size(), 8, "CSV10C_209 should draw to 8 when every Pokemon in play is a Team Rocket's Pokemon"),
		assert_eq(mixed.players[0].hand.size(), 5, "CSV10C_209 should draw only to 5 when an unrelated Pokemon is in play"),
	])


func test_csv10c_210_archer_requires_rocket_knockout_then_draws_five_three() -> String:
	var card := _load_card("210")
	if card == null:
		return "CSV10C_210 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_210 should register a Supporter effect"
	var state := _make_state()
	var supporter := CardInstance.create(card, 0)
	state.last_knockout_turn_against[0] = state.turn_number - 1
	state.shared_turn_flags["attack_damage_knockout_names:0:1"] = ["普通喵喵"]
	var ordinary_allowed := effect.can_execute(supporter, state)
	state.shared_turn_flags["attack_damage_knockout_names:0:1"] = ["火箭队的喵喵"]
	var rocket_allowed := effect.can_execute(supporter, state)
	var any_knockout_state := _make_state()
	var knocked_out := _slot("火箭队的小拉达", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = any_knockout_state
	gsm.call("_record_knockout_identity", 0, knocked_out)
	any_knockout_state.last_knockout_turn_against[0] = any_knockout_state.turn_number
	any_knockout_state.turn_number += 1
	var non_attack_damage_knockout_allowed := effect.can_execute(CardInstance.create(card, 0), any_knockout_state)
	gsm.prepare_for_disposal()
	_fill_hand_and_deck(state.players[0], 6, 8, 0, "Self")
	_fill_hand_and_deck(state.players[1], 6, 8, 1, "Opponent")
	effect.execute(supporter, [], state)
	return run_checks([
		assert_false(ordinary_allowed, "CSV10C_210 should reject a previous-turn knockout of a non-Team-Rocket Pokemon"),
		assert_true(rocket_allowed, "CSV10C_210 should be usable after a Team Rocket's Pokemon was Knocked Out during the opponent's last turn"),
		assert_true(non_attack_damage_knockout_allowed, "CSV10C_210 should also accept a Team Rocket Pokemon Knocked Out by a non-attack-damage cause during the opponent's turn"),
		assert_eq(state.players[0].hand.size(), 5, "CSV10C_210 should shuffle and draw 5 cards for its player"),
		assert_eq(state.players[1].hand.size(), 3, "CSV10C_210 should shuffle and draw 3 cards for the opponent"),
	])


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot("Active %d" % pi, pi)
		player.bench = [_slot("Bench %d" % pi, pi)]
		state.players.append(player)
	return state


func _fill_hand_and_deck(player: PlayerState, hand_count: int, deck_count: int, owner: int, prefix: String) -> void:
	player.hand.clear()
	player.deck.clear()
	for i: int in hand_count:
		player.hand.append(_card("%s Hand %d" % [prefix, i], "Item", owner))
	for i: int in deck_count:
		player.deck.append(_card("%s Deck %d" % [prefix, i], "Item", owner))


func _slot(name: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_pokemon_card(name, "Basic", owner))
	return slot


func _pokemon_card(name: String, stage: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.hp = 100
	return CardInstance.create(data, owner)


func _energy(name: String, energy_type: String, owner: int) -> CardInstance:
	var card := _card(name, "Basic Energy", owner)
	card.card_data.energy_type = energy_type
	card.card_data.energy_provides = energy_type
	return card


func _card(name: String, card_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)
