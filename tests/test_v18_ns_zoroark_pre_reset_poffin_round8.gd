class_name TestV18NsZoroarkPreResetPoffinRound8
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyNsZoroark.gd")


func test_searched_poffin_is_played_before_iono_resets_the_zorua_route() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var live := _state(1)
	var poffin: CardInstance = live.players[0].hand[0]
	var iono: CardInstance = live.players[0].hand[1]
	var poffin_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": poffin, "productive": true,
	}, live, 0))
	var iono_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": iono, "productive": true,
	}, live, 0))
	var retired := _state(2)
	var retired_iono_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": retired.players[0].hand[1], "productive": true,
	}, retired, 0))
	return run_checks([
		assert_true(iono_score <= -2500.0, "Iono must not shuffle away the freshly searched Poffin before the second Zorua is established (score=%f)" % iono_score),
		assert_true(poffin_score >= iono_score + 2500.0, "Poffin must resolve before the hand reset (poffin=%f iono=%f)" % [poffin_score, iono_score]),
		assert_true(retired_iono_score >= iono_score + 2000.0, "The reset guard must retire once two Zorua lanes exist (retired=%f live=%f)" % [retired_iono_score, iono_score]),
	])


func _state(zorua_count: int) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Cleffa", "Basic"))
	for index: int in zorua_count:
		state.players[0].bench.append(_slot(_pokemon("N's Zorua", "Basic")))
	state.players[0].hand.assign([_trainer("Buddy-Buddy Poffin", "Item"), _trainer("Iono", "Supporter")])
	state.players[0].deck.append(CardInstance.create(_pokemon("N's Zorua", "Basic"), 0))
	state.players[0].deck.append(CardInstance.create(_pokemon("N's Zoroark ex", "Stage 1"), 0))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic"), 1)
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 280 if stage == "Stage 1" else 70
	card.attacks = [{"name": "Test", "cost": "DC", "damage": "70"}]
	return card


func _trainer(name: String, card_type: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = card_type
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
