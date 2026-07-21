class_name TestV18HoOhEarlyUrsalunaPaddingRound8
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_bloodmoon_does_not_take_the_last_early_backup_bench_slot() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var early := _state(6, false)
	var bloodmoon := _pokemon_instance("Bloodmoon Ursaluna ex", "Basic")
	var early_score := float(strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": bloodmoon,
	}, early, 0))
	var late := _state(2, false)
	var late_score := float(strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": bloodmoon,
	}, late, 0))
	var online := _state(6, true)
	var online_score := float(strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": bloodmoon,
	}, online, 0))
	return run_checks([
		assert_true(early_score <= -2500.0, "Bloodmoon must not fill the last Bench slot before the first Ho-Oh is ready (score=%f)" % early_score),
		assert_true(late_score >= early_score + 2000.0, "Bloodmoon must become available in its late-prize window (late=%f early=%f)" % [late_score, early_score]),
		assert_true(online_score >= early_score + 2000.0, "The opening guard must retire after a ready Ho-Oh exists (online=%f early=%f)" % [online_score, early_score]),
	])


func _state(prize_count: int, ready_ho_oh: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Latias ex", "Basic"))
	var ho_oh := _slot(_pokemon("Ethan's Ho-Oh ex", "Basic"))
	if ready_ho_oh:
		for index: int in 4:
			ho_oh.attached_energy.append(_fire())
	state.players[0].bench.assign([
		ho_oh,
		_slot(_pokemon("Charcadet", "Basic")),
		_slot(_pokemon("Squawkabilly ex", "Basic")),
		_slot(_pokemon("Hearthflame Mask Ogerpon ex", "Basic")),
	])
	for index: int in prize_count:
		state.players[0].prizes.append(_item("Prize %d" % index))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic"), 1)
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


func _pokemon_instance(name: String, stage: String) -> CardInstance:
	return CardInstance.create(_pokemon(name, stage), 0)


func _fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
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
