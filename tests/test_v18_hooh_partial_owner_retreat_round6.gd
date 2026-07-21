class_name TestV18HoOhPartialOwnerRetreatRound6
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_partial_ho_oh_does_not_discard_route_energy_to_retreat_into_armarouge() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var partial := _state(1)
	var partial_score := float(strategy.call("score_action_absolute", {"kind": "retreat"}, partial, 0))
	var ready := _state(4)
	var ready_score := float(strategy.call("score_action_absolute", {"kind": "retreat"}, ready, 0))
	return run_checks([
		assert_true(partial_score <= -3000.0, "A partial Ho-Oh must keep its route Energy instead of retreating into Armarouge (score=%f)" % partial_score),
		assert_true(ready_score >= partial_score + 2000.0, "The guard must be scoped away once Ho-Oh reaches four Fire (ready=%f partial=%f)" % [ready_score, partial_score]),
	])


func _state(fire_count: int) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var ho_oh := _slot(_pokemon("Ethan's Ho-Oh ex", "Basic", 2, "RRRR"))
	for index: int in fire_count:
		ho_oh.attached_energy.append(_fire())
	state.players[0].active_pokemon = ho_oh
	state.players[0].bench.append(_slot(_pokemon("Armarouge", "Stage 1", 2, "RRC")))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", 1, "C"), 1)
	return state


func _pokemon(name: String, stage: String, retreat: int, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 230
	card.retreat_cost = retreat
	card.attacks = [{"name": "Test", "cost": cost, "damage": "160"}]
	return card


func _fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
