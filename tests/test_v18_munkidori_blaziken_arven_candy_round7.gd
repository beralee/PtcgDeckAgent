class_name TestV18MunkidoriBlazikenArvenCandyRound7
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15300_arven_searches_rare_candy_for_blaziken_in_hand() -> String:
	var strategy := _load_strategy()
	var torchic: CardData = CardDatabase.get_card("CSV10C", "036")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var candy: CardData = CardDatabase.get_card("CSVH1C", "045")
	var ultra_ball: CardData = CardDatabase.get_card("CSV1C", "112")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
		assert_not_null(torchic, "Torchic should load"),
		assert_not_null(blaziken, "Blaziken ex should load"),
		assert_not_null(candy, "Rare Candy should load"),
		assert_not_null(ultra_ball, "Ultra Ball should load"),
	]
	if strategy == null or torchic == null or blaziken == null or candy == null or ultra_ball == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(torchic)
	player.hand.append(CardInstance.create(blaziken, 0))
	var candy_candidate := CardInstance.create(candy, 0)
	var ultra_candidate := CardInstance.create(ultra_ball, 0)
	var step := {"id": "search_item", "max_select": 1}
	var context := {"game_state": state, "player_index": 0}
	var candy_score := float(strategy.call("score_interaction_target", candy_candidate, step, context))
	var ultra_score := float(strategy.call("score_interaction_target", ultra_candidate, step, context))

	player.hand.clear()
	var inactive_score := float(strategy.call("score_interaction_target", candy_candidate, step, context))
	checks.append_array([
		assert_true(candy_score >= 7000.0, "Arven must see the direct Torchic plus hand-Blaziken Rare Candy route (score=%f)" % candy_score),
		assert_true(candy_score >= ultra_score + 1000.0, "Rare Candy must beat the seed15300 Ultra Ball line that discarded both TM Evolution and Blaziken ex (Candy=%f Ultra=%f)" % [candy_score, ultra_score]),
		assert_true(inactive_score <= candy_score - 3000.0, "The Arven override must release when Blaziken ex is no longer in hand (inactive=%f live=%f)" % [inactive_score, candy_score]),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
