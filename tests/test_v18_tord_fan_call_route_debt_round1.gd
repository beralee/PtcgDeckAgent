class_name TestV18TordFanCallRouteDebtRound1
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18TeraNoctowl.gd")
const CSV9C_EFFECTS = preload("res://scripts/effects/CSV9CEffects.gd")
const DECK_PATH := "res://data/bundled_user/decks/800015934.json"
const FAN_CALL_STEP := {"id": "csv9c_fan_call_cards", "max_select": 3}


func test_complete_two_line_shell_skips_fan_call_without_shuffling() -> String:
	var strategy := _strategy()
	var state := _state()
	var fan_rotom := _slot("CSV9C", "161")
	var field_line := _evolved_line("CSV9C", "154")
	var hand_hoothoot := _card("CSV9.5C", "141")
	var hand_noctowl := _card("CSV9C", "155")
	var deck_hoothoot := _card("CSV9C", "154")
	var deck_noctowl := _card("CSV9C", "155")
	var deck_rotom := _card("CSV9C", "161")
	if strategy == null or fan_rotom == null or field_line == null or hand_hoothoot == null \
			or hand_noctowl == null or deck_hoothoot == null or deck_noctowl == null \
			or deck_rotom == null:
		return assert_true(false, "Tord Fan Call complete-shell fixtures should load")
	state.players[0].active_pokemon = fan_rotom
	state.players[0].bench = [field_line]
	state.players[0].hand = [hand_hoothoot, hand_noctowl]
	state.players[0].deck = [deck_rotom, deck_hoothoot, deck_noctowl]
	var deck_before: Array[int] = _instance_ids(state.players[0].deck)
	var fan_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability",
		"source_slot": fan_rotom,
		"ability_index": 0,
	}, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	var response: Variant = strategy.call(
		"_pick_fan_call_targets",
		state.players[0].deck,
		FAN_CALL_STEP,
		{"game_state": state, "player_index": 0}
	)
	var envelope: Dictionary = response if response is Dictionary else {}
	if fan_score > end_score:
		var effect := CSV9C_EFFECTS.AbilityFanCall.new()
		effect.execute_ability(fan_rotom, 0, [], state)
	return run_checks([
		assert_true(fan_score <= -5000.0, "A complete Tord shell must hard-demote Fan Rotom's Fan Call"),
		assert_true(fan_score < end_score, "A complete Tord shell must choose ending the turn over Fan Call"),
		assert_true(bool(envelope.get("handled", false)), "Zero route debt must explicitly handle the Fan Call interaction"),
		assert_true((envelope.get("items", []) as Array).is_empty(), "Zero route debt must return an explicit empty target list"),
		assert_eq(_instance_ids(state.players[0].deck), deck_before, "Skipping Fan Call must preserve deck order instead of shuffling"),
	])


func test_single_noctowl_debt_selects_exactly_one_noctowl() -> String:
	var strategy := _strategy()
	var state := _state()
	var fan_rotom := _slot("CSV9C", "161")
	var field_hoothoot_a := _slot("CSV9C", "154")
	var field_hoothoot_b := _slot("CSV9.5C", "141")
	var hand_noctowl := _card("CSV9C", "155")
	var target_noctowl := _card("CSV9C", "155")
	var extra_hoothoot := _card("CSV9C", "154")
	var extra_rotom := _card("CSV9C", "161")
	if strategy == null or fan_rotom == null or field_hoothoot_a == null \
			or field_hoothoot_b == null or hand_noctowl == null or target_noctowl == null \
			or extra_hoothoot == null or extra_rotom == null:
		return assert_true(false, "Tord Fan Call one-Noctowl-debt fixtures should load")
	state.players[0].active_pokemon = fan_rotom
	state.players[0].bench = [field_hoothoot_a, field_hoothoot_b]
	state.players[0].hand = [hand_noctowl]
	var response: Variant = strategy.call("_pick_fan_call_targets", [
		extra_rotom, extra_hoothoot, target_noctowl,
	], FAN_CALL_STEP, {"game_state": state, "player_index": 0})
	var envelope: Dictionary = response if response is Dictionary else {}
	var picked: Array = envelope.get("items", [])
	return run_checks([
		assert_true(bool(envelope.get("handled", false)), "Tord Fan Call debt selection must suppress fallback picks"),
		assert_eq(picked.size(), 1, "One missing Noctowl component must consume exactly one Fan Call slot"),
		assert_true(target_noctowl in picked, "The one-card route debt must select Noctowl"),
		assert_false(extra_hoothoot in picked or extra_rotom in picked, "A one-Noctowl debt must not add unrelated targets"),
	])


func test_two_missing_lines_select_components_without_duplicate_rotom() -> String:
	var strategy := _strategy()
	var state := _state()
	var fan_rotom := _slot("CSV9C", "161")
	var rotom_a := _card("CSV9C", "161")
	var rotom_b := _card("CSV9C", "161")
	var hoothoot_a := _card("CSV9C", "154")
	var hoothoot_b := _card("CSV9.5C", "141")
	var noctowl_a := _card("CSV9C", "155")
	var noctowl_b := _card("CSV9C", "155")
	if strategy == null or fan_rotom == null or rotom_a == null or rotom_b == null \
			or hoothoot_a == null or hoothoot_b == null or noctowl_a == null \
			or noctowl_b == null:
		return assert_true(false, "Tord Fan Call two-line-debt fixtures should load")
	state.players[0].active_pokemon = fan_rotom
	var response: Variant = strategy.call("_pick_fan_call_targets", [
		rotom_a, rotom_b, hoothoot_a, hoothoot_b, noctowl_a, noctowl_b,
	], FAN_CALL_STEP, {"game_state": state, "player_index": 0})
	var envelope: Dictionary = response if response is Dictionary else {}
	var picked: Array = envelope.get("items", [])
	return run_checks([
		assert_true(bool(envelope.get("handled", false)), "Tord's missing-line route must explicitly own Fan Call selection"),
		assert_eq(picked.size(), 3, "Two empty evolution lines should use all three available Fan Call slots"),
		assert_eq(_count_identity(strategy, picked, "hoothoot"), 2, "Two empty lines should first recover both missing Hoothoot components"),
		assert_eq(_count_identity(strategy, picked, "noctowl"), 1, "The remaining slot should recover one missing Noctowl component"),
		assert_eq(_count_identity(strategy, picked, "uid:csv9c_161"), 0, "Tord must not search either duplicate Fan Rotom when route components are missing"),
	])


func _strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", DeckData.from_dict(parsed))
	return strategy


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	return state


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _slot(set_code: String, card_index: String) -> PokemonSlot:
	var card := _card(set_code, card_index)
	if card == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _evolved_line(hoothoot_set: String, hoothoot_index: String) -> PokemonSlot:
	var hoothoot := _card(hoothoot_set, hoothoot_index)
	var noctowl := _card("CSV9C", "155")
	if hoothoot == null or noctowl == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack = [hoothoot, noctowl]
	return slot


func _instance_ids(cards: Array) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


func _count_identity(strategy: RefCounted, items: Array, identity: String) -> int:
	var count := 0
	for item: Variant in items:
		if str(strategy.call("_fan_call_identity", item)) == identity:
			count += 1
	return count
