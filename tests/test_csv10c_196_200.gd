class_name TestCSV10C196To200
extends TestBase


class AlwaysHeads extends CoinFlipper:
	func flip() -> bool:
		return true


func test_csv10c_196_to_200_registry_contract() -> String:
	var processor := EffectProcessor.new(AlwaysHeads.new())
	var checks: Array[String] = []
	for number: int in range(196, 201):
		var card := _load_card("%03d" % number)
		checks.append(assert_true(processor.has_effect(card.effect_id), "CSV10C_%03d should register its Trainer effect" % number))
	return run_checks(checks)


func test_csv10c_196_reveals_and_optionally_swaps_chosen_opponent_prize_and_hidden_hand_card() -> String:
	var state := _state()
	var processor := EffectProcessor.new(AlwaysHeads.new())
	var item := CardInstance.create(_load_card("196"), 0)
	var prize_a := _card("Prize A", "Item", 1)
	var selected_prize := _card("Selected Prize", "Pokemon", 1)
	var hand_a := _card("Hand A", "Item", 1)
	var selected_hand := _card("Selected Hand", "Supporter", 1)
	state.players[1].prizes = [prize_a, selected_prize]
	state.players[1].hand = [hand_a, selected_hand]
	var effect := processor.get_effect(item.card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(item, state) if effect != null else []
	var resolved_context := {
		"csv10c_robot_prize_index": [1],
		"csv10c_robot_hidden_hand": [selected_hand],
	}
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(item, state, resolved_context) if effect != null else []
	var used := processor.execute_card_effect(item, [{
		"csv10c_robot_prize_index": [1],
		"csv10c_robot_hidden_hand": [selected_hand],
		"csv10c_robot_swap": ["swap"],
	}], state)
	return run_checks([
		assert_true(used, "CSV10C_196 should be playable with an opposing hand and face-down Prize"),
		assert_true(selected_prize in state.players[1].hand and selected_hand in state.players[1].prizes, "CSV10C_196 should swap exactly the selected cards"),
		assert_eq(state.players[1].prizes[1], selected_hand, "CSV10C_196 should preserve the selected Prize position"),
		assert_true(selected_hand.face_up, "CSV10C_196 replacement Prize should remain face up for the rest of the game"),
		assert_false(prize_a.face_up, "CSV10C_196 should not reveal another Prize"),
		assert_eq(steps[0].get("visible_scope", "") if not steps.is_empty() else "", "opponent_prizes_hidden", "CSV10C_196 should not reveal Prize faces while choosing"),
		assert_eq(steps[1].get("visible_scope", "") if steps.size() > 1 else "", "opponent_hand_hidden", "CSV10C_196 should not reveal hand faces while choosing"),
		assert_eq(followup[0].get("card_items", []) if not followup.is_empty() else [], [selected_prize, selected_hand], "CSV10C_196 follow-up should reveal only the two selected cards"),
		assert_eq(followup[0].get("private_to_player", -1) if not followup.is_empty() else -1, 0, "CSV10C_196 revealed cards should be private to the Item user"),
	])


func test_csv10c_197_heads_searches_one_evolution_team_rocket_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new(AlwaysHeads.new())
	var item := CardInstance.create(_load_card("197"), 0)
	var evolution := _pokemon_card("火箭队的以欧路普", "Stage 1")
	var basic := _pokemon_card("火箭队的天罩虫", "Basic")
	var unrelated := _pokemon_card("Ordinary Evolution", "Stage 1")
	state.players[0].deck = [basic, unrelated, evolution]
	var effect := processor.get_effect(item.card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(item, state) if effect != null else []
	var used := processor.execute_card_effect(item, [{"csv10c_rocket_ball_search": [evolution]}], state)
	return run_checks([
		assert_false(steps.is_empty(), "CSV10C_197 should expose its heads search after the coin result"),
		assert_true(used, "CSV10C_197 should resolve with an eligible evolution Team Rocket Pokemon"),
		assert_true(evolution in state.players[0].hand and evolution not in state.players[0].deck, "CSV10C_197 heads should add the chosen evolution Team Rocket Pokemon"),
		assert_true(basic in state.players[0].deck and unrelated in state.players[0].deck, "CSV10C_197 heads should reject Basic and unrelated Pokemon"),
	])


func test_csv10c_198_heads_places_two_damage_counters_on_selected_opponent_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new(AlwaysHeads.new())
	var item := CardInstance.create(_load_card("198"), 0)
	var selected := _pokemon("Selected", 1)
	var other := _pokemon("Other", 1)
	state.players[1].bench = [other, selected]
	var used := processor.execute_card_effect(item, [{"csv10c_scare_bomb_target": [selected]}], state)
	return run_checks([
		assert_true(used, "CSV10C_198 should resolve its coin flip"),
		assert_eq(selected.damage_counters, 20, "CSV10C_198 heads should place exactly two damage counters on the selected opposing Pokemon"),
		assert_eq(other.damage_counters, 0, "CSV10C_198 should not damage another opposing Pokemon"),
		assert_eq(state.players[0].active_pokemon.damage_counters, 0, "CSV10C_198 heads should not damage the user's Active Pokemon"),
	])


func test_csv10c_199_searches_only_team_rocket_supporter_to_hand() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var item := CardInstance.create(_load_card("199"), 0)
	var rocket_supporter := _card("火箭队的坂木", "Supporter")
	var ordinary_supporter := _card("Ordinary Supporter", "Supporter")
	var rocket_item := _card("火箭队的道具", "Item")
	state.players[0].deck = [ordinary_supporter, rocket_item, rocket_supporter]
	var effect := processor.get_effect(item.card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(item, state) if effect != null else []
	var used := processor.execute_card_effect(item, [{"csv10c_rocket_receiver_search": [rocket_supporter]}], state)
	return run_checks([
		assert_true(used, "CSV10C_199 should be playable with a matching Supporter"),
		assert_true(rocket_supporter in state.players[0].hand and rocket_supporter not in state.players[0].deck, "CSV10C_199 should add the chosen Team Rocket Supporter"),
		assert_true(ordinary_supporter in state.players[0].deck and rocket_item in state.players[0].deck, "CSV10C_199 should leave nonmatching cards in the deck"),
		assert_eq(steps[0].get("visible_scope", "") if not steps.is_empty() else "", "own_full_deck", "CSV10C_199 should show the full deck in its search UI"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [-1, -1, 0], "CSV10C_199 should enable only Team Rocket Supporters in the full-deck view"),
	])


func test_csv10c_200_adds_seventy_hp_only_to_cynthias_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var tool_data := _load_card("200")
	var cynthia := _pokemon("竹兰的烈咬陆鲨ex")
	var plain := _pokemon("Ordinary Pokemon")
	cynthia.attached_tool = CardInstance.create(tool_data, 0)
	plain.attached_tool = CardInstance.create(tool_data, 0)
	return run_checks([
		assert_eq(processor.get_hp_modifier(cynthia, state), 70, "CSV10C_200 should add 70 HP to a Cynthia's Pokemon"),
		assert_eq(processor.get_hp_modifier(plain, state), 0, "CSV10C_200 should not add HP to an unrelated Pokemon"),
	])


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 31
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func _card(name: String, card_type: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _pokemon_card(name: String, stage: String = "Basic", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.hp = 100
	return CardInstance.create(data, owner)


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_pokemon_card(name, "Basic", owner))
	return slot
