class_name TestV18StandardGardevoirRetreatReservationRound9
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018497.json"


func test_seed15301_reserves_one_embrace_for_the_active_pivot() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var active := _slot(CardDatabase.get_card("CSV2C", "053"))
	var gardevoir := _slot(CardDatabase.get_card("CSV2C", "055"))
	var scream_tail := _slot(CardDatabase.get_card("CSV6C", "065"))
	player.active_pokemon = active
	player.bench.assign([gardevoir, scream_tail])
	for index: int in 3:
		player.discard_pile.append(_psychic())
	var reservation_score: float = strategy.call(
		"_score_standard_retreat_bridge_reservation",
		active,
		state,
		player,
		0
	)
	var picked: Variant = strategy.call("pick_embrace_target", [scream_tail, active], state, 0)
	return run_checks([
		assert_true(reservation_score >= 1240.0,
			"Three discard Energy must be split 1+2 so the rebuilt Scream Tail can actually attack"),
		assert_true(picked == active,
			"Psychic Embrace should reserve the Active retreat payment before charging the bench"),
	])


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", DeckData.from_dict(raw))
	return strategy


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 12
	state.phase = GameState.GamePhase.MAIN
	return state


func _psychic() -> CardInstance:
	var card := CardData.new()
	card.name = "Psychic Energy"
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "P"
	return CardInstance.create(card, 0)


func _slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
