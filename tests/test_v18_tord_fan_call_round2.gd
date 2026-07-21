class_name TestV18TordFanCallRound2
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18TeraNoctowl.gd")
const DECK_PATH := "res://data/bundled_user/decks/800015934.json"


func test_live_jewel_search_keeps_legal_fan_call_above_route_debt_penalty() -> String:
	var strategy := _strategy()
	var state := _state()
	var fan_rotom := _slot("CSV9C", "161")
	var tera := _slot("CSV9C", "175")
	var field_line := _evolved_line("CSV9C", "154")
	var second_hoothoot := _slot("CSV9.5C", "141")
	var hand_noctowl := _card("CSV9C", "155")
	var target_noctowl := _card("CSV9C", "155")
	if strategy == null or fan_rotom == null or tera == null or field_line == null \
			or second_hoothoot == null or hand_noctowl == null or target_noctowl == null:
		return assert_true(false, "Tord Fan Call round2 fixtures should load")
	state.players[0].active_pokemon = fan_rotom
	state.players[0].bench = [tera, field_line, second_hoothoot]
	state.players[0].hand = [hand_noctowl]
	var action := {
		"kind": "use_ability",
		"source_slot": fan_rotom,
		"ability_index": 0,
		"targets": [{"csv9c_fan_call_cards": [target_noctowl]}],
	}
	var score_with_target := float(strategy.call("score_action_absolute", action, state, 0))
	var no_target_action: Dictionary = action.duplicate(true)
	no_target_action["targets"] = []
	var score_without_target := float(strategy.call("score_action_absolute", no_target_action, state, 0))
	return run_checks([
		assert_gt(score_with_target, -5000.0, "Live Jewel Search must not apply the -5000 Fan Call penalty while a legal target remains"),
		assert_true(score_without_target <= -5000.0, "Zero-debt Fan Call without a legal target must retain its penalty"),
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
