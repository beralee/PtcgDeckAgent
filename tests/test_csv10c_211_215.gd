class_name TestCSV10C211To215
extends TestBase


func test_csv10c_211_215_bundle_metadata_and_assets() -> String:
	var expected := {
		"211": ["火箭队的坂木", "f567109551b79471a196f605ba549be8"],
		"212": ["火箭队的拉姆达", "ffc8153bc60e336eee4c6c5c74a3d95f"],
		"213": ["火箭队的兰斯", "c73f4fde5f12bf1f6c1e8866492ef4b3"],
		"214": ["石之洞窟", "da4dac3550078557c6d4b378eefbb783"],
		"215": ["N的城堡", "36e665b638c0c5d082a96f11552121ad"],
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


func test_csv10c_211_giovanni_switches_only_rocket_then_gusts_opponent() -> String:
	var card := _load_card("211")
	if card == null:
		return "CSV10C_211 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_211 should register a Supporter effect"
	var state := _make_state()
	var old_active := _slot("火箭队的超梦ex", 0)
	var rocket_bench := _slot("火箭队的喵喵", 0)
	var ordinary_bench := _slot("普通喵喵", 0)
	state.players[0].active_pokemon = old_active
	state.players[0].bench = [rocket_bench, ordinary_bench]
	var old_opponent_active := state.players[1].active_pokemon
	var opponent_target := state.players[1].bench[0]
	var supporter := CardInstance.create(card, 0)
	var protected := PokemonSlot.new()
	protected.pokemon_stack.append(CardInstance.create(_load_card("234"), 1))
	state.players[1].bench[1] = protected
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(protected.get_card_data())
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	effect.execute(supporter, [{"own_rocket_bench": [rocket_bench], "opponent_bench": [opponent_target]}], state)
	return run_checks([
		assert_eq(steps.size(), 2, "CSV10C_211 should expose both required switch choices"),
		assert_true(rocket_bench in (steps[0].get("items", []) as Array) and ordinary_bench not in (steps[0].get("items", []) as Array), "CSV10C_211 should only offer Team Rocket's Pokemon for the own switch"),
		assert_eq(state.players[0].active_pokemon, rocket_bench, "CSV10C_211 should promote the selected own Team Rocket's Pokemon"),
		assert_true(old_active in state.players[0].bench, "CSV10C_211 should move the old Active Pokemon to the Bench"),
		assert_eq(state.players[1].active_pokemon, opponent_target, "CSV10C_211 should gust the selected opposing Bench Pokemon"),
		assert_true(old_opponent_active in state.players[1].bench, "CSV10C_211 should move the opponent's old Active Pokemon to the Bench"),
		assert_true(protected not in (steps[1].get("items", []) as Array) if steps.size() > 1 else false, "CSV10C_211 UI should omit a Cetitan ex protected from opponent Supporters"),
	])


func test_csv10c_212_lambda_searches_any_trainer_with_full_library_visibility() -> String:
	var card := _load_card("212")
	if card == null:
		return "CSV10C_212 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_212 should register a Supporter effect"
	var state := _make_state()
	var item := _card("Item", "Item", 0)
	var tool := _card("Tool", "Tool", 0)
	var supporter_card := _card("Supporter", "Supporter", 0)
	var stadium := _card("Stadium", "Stadium", 0)
	var energy := _card("Energy", "Basic Energy", 0)
	var pokemon := _pokemon_card("Pokemon", "Basic", 0)
	state.players[0].deck = [energy, item, pokemon, tool, supporter_card, stadium]
	var source := CardInstance.create(card, 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(source, state)
	effect.execute(source, [{"search_cards": [stadium]}], state)
	return run_checks([
		assert_eq(steps.size(), 1, "CSV10C_212 should expose one Trainer search step"),
		assert_eq(str(steps[0].get("visible_scope", "")) if not steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_212 should show the complete own library"),
		assert_true(item in (steps[0].get("items", []) as Array) and tool in (steps[0].get("items", []) as Array) and supporter_card in (steps[0].get("items", []) as Array) and stadium in (steps[0].get("items", []) as Array), "CSV10C_212 should accept every Trainer subtype"),
		assert_true(energy in (steps[0].get("card_items", []) as Array) and energy not in (steps[0].get("items", []) as Array), "CSV10C_212 should show but disable non-Trainer cards"),
		assert_true(stadium in state.players[0].hand, "CSV10C_212 should move the selected Trainer to hand"),
	])


func test_csv10c_213_lance_is_first_player_turn_exception_and_searches_three_basic_rocket() -> String:
	var card := _load_card("213")
	if card == null:
		return "CSV10C_213 bundled card is required"
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_213 should register a Supporter effect"
	var state := _make_state()
	state.turn_number = 1
	state.first_player_index = 0
	state.current_player_index = 0
	var source := CardInstance.create(card, 0)
	var rocket_a := _pokemon_card("火箭队的喵喵", "Basic", 0)
	var rocket_b := _pokemon_card("火箭队的小拉达", "Basic", 0)
	var rocket_c := _pokemon_card("火箭队的超梦ex", "Basic", 0)
	var rocket_evolution := _pokemon_card("火箭队的拉达", "Stage 1", 0)
	var ordinary := _pokemon_card("普通喵喵", "Basic", 0)
	state.players[0].deck = [ordinary, rocket_a, rocket_evolution, rocket_b, rocket_c]
	var reason := RuleValidator.new().get_play_supporter_unusable_reason(state, 0, source, processor)
	var steps: Array[Dictionary] = effect.get_interaction_steps(source, state)
	effect.execute(source, [{"search_basic_rocket": [rocket_a, rocket_b, rocket_c]}], state)
	var empty_search_followup: Array[Dictionary] = effect.get_followup_interaction_steps(
		source,
		state,
		{"empty_search_resolution": [BaseEffect.EMPTY_SEARCH_VIEW_DECK]}
	)
	return run_checks([
		assert_eq(reason, "", "CSV10C_213 should be playable during the first player's first turn"),
		assert_eq(steps.size(), 1, "CSV10C_213 should expose one search step"),
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 3, "CSV10C_213 should allow up to 3 Basic Team Rocket's Pokemon"),
		assert_true(rocket_evolution not in (steps[0].get("items", []) as Array) and ordinary not in (steps[0].get("items", []) as Array), "CSV10C_213 should reject Evolutions and unrelated Basic Pokemon"),
		assert_true(rocket_a in state.players[0].hand and rocket_b in state.players[0].hand and rocket_c in state.players[0].hand, "CSV10C_213 should move the selected Basic Team Rocket's Pokemon to hand"),
		assert_eq(empty_search_followup.size(), 1, "CSV10C_213 should offer the full-deck preview after an empty search"),
	])


func test_csv10c_214_stone_cave_reduces_damage_to_stevens_pokemon() -> String:
	var card := _load_card("214")
	if card == null:
		return "CSV10C_214 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	state.stadium_card = CardInstance.create(card, 0)
	var steven := _slot("大吾的巨金怪ex", 0)
	var ordinary := _slot("巨金怪ex", 0)
	return run_checks([
		assert_eq(processor.get_defender_modifier(steven, state, state.players[1].active_pokemon), -30, "CSV10C_214 should reduce attack damage to Steven's Pokemon by 30"),
		assert_eq(processor.get_defender_modifier(ordinary, state, state.players[1].active_pokemon), 0, "CSV10C_214 should not protect unrelated Pokemon"),
	])


func test_csv10c_215_ns_castle_removes_retreat_cost_from_ns_pokemon() -> String:
	var card := _load_card("215")
	if card == null:
		return "CSV10C_215 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	state.stadium_card = CardInstance.create(card, 0)
	var ns_pokemon := _slot("N的索罗亚克ex", 0, 3)
	var ordinary := _slot("索罗亚克ex", 0, 3)
	return run_checks([
		assert_eq(processor.get_effective_retreat_cost(ns_pokemon, state), 0, "CSV10C_215 should remove the Retreat Cost of N's Pokemon"),
		assert_eq(processor.get_effective_retreat_cost(ordinary, state), 3, "CSV10C_215 should not modify unrelated Pokemon"),
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
		player.bench = [_slot("Bench %d A" % pi, pi), _slot("Bench %d B" % pi, pi)]
		state.players.append(player)
	return state


func _slot(name: String, owner: int, retreat_cost: int = 1) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 100
	data.retreat_cost = retreat_cost
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _pokemon_card(name: String, stage: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.hp = 100
	return CardInstance.create(data, owner)


func _card(name: String, card_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)
