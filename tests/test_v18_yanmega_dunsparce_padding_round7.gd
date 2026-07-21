class_name TestV18YanmegaDunsparcePaddingRound7
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Yanmega.gd")


func test_second_dunsparce_does_not_pad_the_bench_before_yanmega_exists() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var first := _state(false, false)
	var padded := _state(true, false)
	var online := _state(true, true)
	var dunsparce := _pokemon_instance("Dunsparce", "Basic")
	var first_score := _score(strategy, first, dunsparce)
	var padded_score := _score(strategy, padded, dunsparce)
	var online_score := _score(strategy, online, dunsparce)
	return run_checks([
		assert_true(padded_score <= -2500.0, "A second Dunsparce must not consume Yanmega's remaining setup space (score=%f)" % padded_score),
		assert_true(first_score >= padded_score + 2000.0, "The first Dunsparce draw lane must remain available (first=%f padded=%f)" % [first_score, padded_score]),
		assert_true(online_score >= padded_score + 2000.0, "The padding guard must retire after Yanmega is established (online=%f padded=%f)" % [online_score, padded_score]),
	])


func _score(strategy: RefCounted, state: GameState, card: CardInstance) -> float:
	return float(strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": card,
	}, state, 0))


func _state(has_dunsparce: bool, has_yanmega: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Yanma", "Basic"))
	if has_dunsparce:
		state.players[0].bench.append(_slot(_pokemon("Dunsparce", "Basic")))
	if has_yanmega:
		state.players[0].bench.append(_slot(_pokemon("Yanmega ex", "Stage 1")))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic"), 1)
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if name.ends_with(" ex") else ""
	card.hp = 280 if stage == "Stage 1" else 70
	card.attacks = [{"name": "Test", "cost": "G", "damage": "30"}]
	return card


func _pokemon_instance(name: String, stage: String) -> CardInstance:
	return CardInstance.create(_pokemon(name, stage), 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
