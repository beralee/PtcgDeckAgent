class_name TestV18HoOhLowDeckResearchRound10
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_professors_research_does_not_convert_a_low_deck_into_deck_out() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var low := _state(6)
	var safe := _state(12)
	var research := _supporter("Professor's Research")
	var low_score := _score(strategy, low, research)
	var safe_score := _score(strategy, safe, research)
	return run_checks([
		assert_true(low_score <= -2500.0, "Professor's Research must not be played with seven or fewer cards left in deck (score=%f)" % low_score),
		assert_true(safe_score >= low_score + 2000.0, "Research must return outside the deck-out window (safe=%f low=%f)" % [safe_score, low_score]),
	])


func _score(strategy: RefCounted, state: GameState, research: CardInstance) -> float:
	return float(strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": research,
		"productive": true,
		"targets": [],
	}, state, 0))


func _state(deck_size: int) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 25
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Ethan's Ho-Oh ex", "Basic"))
	for index: int in deck_size:
		state.players[0].deck.append(_item("Deck Card %d" % index))
	state.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic"), 1)
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 230
	card.attacks = [{"name": "Test", "cost": "RRRR", "damage": "160"}]
	return card


func _supporter(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Supporter"
	return CardInstance.create(card, 0)


func _item(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
