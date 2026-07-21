class_name TestV18YanmegaBrokenLaneSearchRound5
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Yanmega.gd")


func test_ultra_ball_immediately_repairs_yanma_without_yanmega_access() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var broken := _state(false)
	var ultra_ball := _item("Ultra Ball")
	var broken_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": ultra_ball, "productive": true,
	}, broken, 0))
	var repaired := _state(true)
	var repaired_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": ultra_ball, "productive": true,
	}, repaired, 0))
	return run_checks([
		assert_true(broken_score >= 4500.0, "Ultra Ball must repair a stranded Yanma immediately (score=%f)" % broken_score),
		assert_true(broken_score >= repaired_score + 2500.0, "The repair bonus must retire once Yanmega is already in hand (broken=%f repaired=%f)" % [broken_score, repaired_score]),
	])


func _state(has_yanmega_in_hand: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Yanma", "Basic"))
	state.players[0].deck.append(CardInstance.create(_pokemon("Yanmega ex", "Stage 1"), 0))
	if has_yanmega_in_hand:
		state.players[0].hand.append(CardInstance.create(_pokemon("Yanmega ex", "Stage 1"), 0))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic"), 1)
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 280 if stage == "Stage 1" else 70
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _item(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
