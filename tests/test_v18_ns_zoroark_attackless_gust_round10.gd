class_name TestV18NsZoroarkAttacklessGustRound10
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyNsZoroark.gd")


func test_gust_waits_until_the_active_pokemon_can_attack() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var stalled := _state(false)
	var ready := _state(true)
	var boss := _supporter("Boss's Orders")
	var catcher := _item("Counter Catcher")
	var boss_stalled := _score(strategy, stalled, boss)
	var catcher_stalled := _score(strategy, stalled, catcher)
	var boss_ready := _score(strategy, ready, boss)
	var catcher_ready := _score(strategy, ready, catcher)
	return run_checks([
		assert_true(boss_stalled <= -2500.0, "Boss's Orders must not be spent before the active Pokemon can attack (score=%f)" % boss_stalled),
		assert_true(catcher_stalled <= -2500.0, "Counter Catcher must not overwrite an attackless gust turn (score=%f)" % catcher_stalled),
		assert_true(boss_ready >= boss_stalled + 2000.0, "Boss's Orders must return when the active Pokemon can attack (ready=%f stalled=%f)" % [boss_ready, boss_stalled]),
		assert_true(catcher_ready >= catcher_stalled + 2000.0, "Counter Catcher must return when the active Pokemon can attack (ready=%f stalled=%f)" % [catcher_ready, catcher_stalled]),
	])


func _score(strategy: RefCounted, state: GameState, card: CardInstance) -> float:
	return float(strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": card,
		"productive": true,
		"targets": [{"opponent_bench_target": [state.players[1].bench[0]]}],
	}, state, 0))


func _state(can_attack: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var active := _slot(_pokemon("N's Zorua", "Basic"))
	if can_attack:
		active.attached_energy.append(_darkness_energy())
	state.players[0].active_pokemon = active
	state.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic"), 1)
	state.players[1].bench.append(_slot(_pokemon("Lumineon V", "Basic"), 1))
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 120
	card.attacks = [{"name": "Test", "cost": "D", "damage": "20"}]
	return card


func _darkness_energy() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "D"
	card.energy_provides = "D"
	return CardInstance.create(card, 0)


func _supporter(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Supporter"
	return CardInstance.create(card, 0)


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
