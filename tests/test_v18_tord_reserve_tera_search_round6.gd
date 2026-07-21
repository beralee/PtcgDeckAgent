class_name TestV18TordReserveTeraSearchRound6
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800015934.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15370_nest_ball_rebuilds_reserve_tera_before_fan_rotom() -> String:
	var strategy := _load_strategy()
	var hoothoot: CardData = CardDatabase.get_card("CSV9C", "154")
	var fan_rotom: CardData = CardDatabase.get_card("CSV9C", "161")
	var teal_ogerpon: CardData = CardDatabase.get_card("CSV8C", "028")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800015934 should resolve through the production registry"),
		assert_not_null(hoothoot, "Hoothoot should load"),
		assert_not_null(fan_rotom, "Fan Rotom should load"),
		assert_not_null(teal_ogerpon, "Teal Mask Ogerpon ex should load"),
	]
	if strategy == null or hoothoot == null or fan_rotom == null or teal_ogerpon == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(hoothoot)
	player.bench = [_make_slot(fan_rotom)]
	var reserve_tera := CardInstance.create(teal_ogerpon, 0)
	var support := CardInstance.create(fan_rotom, 0)
	player.deck.append_array([support, reserve_tera])
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "basic_pokemon", "max_select": 1}
	var tera_score := float(strategy.call("score_interaction_target", reserve_tera, step, context))
	var support_score := float(strategy.call("score_interaction_target", support, step, context))
	checks.append_array([
		assert_true(tera_score >= 7200.0, "Nest Ball should reserve the dedicated Tera rebuild score after the first attacker is gone (score=%f)" % tera_score),
		assert_true(tera_score > support_score + 4000.0, "A reserve Tera attacker must outrank another Fan Rotom during rebuild (tera=%f fan=%f)" % [tera_score, support_score]),
	])
	return run_checks(checks)


func test_reserve_tera_search_override_releases_when_tera_is_already_in_play() -> String:
	var strategy := _load_strategy()
	var teal_ogerpon: CardData = CardDatabase.get_card("CSV8C", "028")
	var fan_rotom: CardData = CardDatabase.get_card("CSV9C", "161")
	if strategy == null or teal_ogerpon == null or fan_rotom == null:
		return assert_true(false, "The production strategy and Tord search fixtures should load")
	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(teal_ogerpon)
	var reserve_tera := CardInstance.create(teal_ogerpon, 0)
	state.players[0].deck.append(reserve_tera)
	var score := float(strategy.call("score_interaction_target", reserve_tera, {"id": "basic_pokemon"}, {
		"game_state": state,
		"player_index": 0,
	}))
	return assert_true(score < 7200.0, "The emergency Nest Ball override must release once a Tera attacker is already in play (score=%f)" % score)


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
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
