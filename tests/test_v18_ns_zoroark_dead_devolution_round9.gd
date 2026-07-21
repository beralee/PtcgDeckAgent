class_name TestV18NsZoroarkDeadDevolutionRound9
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyNsZoroark.gd")


func test_tm_devolution_waits_for_an_opposing_evolution_target() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var dead := _state(false)
	var tool := _tool("Technical Machine: Devolution")
	var dead_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tool, "target_slot": dead.players[0].active_pokemon,
	}, dead, 0))
	var live := _state(true)
	var live_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tool, "target_slot": live.players[0].active_pokemon,
	}, live, 0))
	return run_checks([
		assert_true(dead_score <= -2500.0, "TM Devolution must not be attached while Miraidon's board has no Evolution Pokemon (score=%f)" % dead_score),
		assert_true(live_score >= dead_score + 2000.0, "The guard must retire once an opposing Evolution Pokemon is in play (live=%f dead=%f)" % [live_score, dead_score]),
	])


func _state(with_opposing_evolution: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("N's Zorua", "Basic"))
	state.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic"), 1)
	if with_opposing_evolution:
		state.players[1].bench.append(_slot(_pokemon("Flaaffy", "Stage 1"), 1))
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 120
	card.attacks = [{"name": "Test", "cost": "C", "damage": "20"}]
	return card


func _tool(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Tool"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
