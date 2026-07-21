class_name TestV18PidgeotOpeningTrolleyDualSeedRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018359


func test_precious_trolley_dual_seed_bonus_is_opening_only() -> String:
	var strategy := _strategy()
	var pidgey_data: CardData = CardDatabase.get_card("151C", "016")
	var nacli_data: CardData = CardDatabase.get_card("SVP", "080")
	var trolley_data: CardData = CardDatabase.get_card("CSV9C", "186")
	if strategy == null or pidgey_data == null or nacli_data == null or trolley_data == null:
		return "Exact strategy, Pidgey, Nacli, and Precious Trolley must load"
	var state := _state()
	var player: PlayerState = state.players[0]
	player.deck.assign([
		CardInstance.create(pidgey_data, 0),
		CardInstance.create(nacli_data, 0),
	])
	var trolley := CardInstance.create(trolley_data, 0)
	var action := {
		"kind": "play_trainer",
		"card": trolley,
		"productive": true,
		"requires_interaction": true,
	}
	var opening_score := _score(strategy, action, state)
	state.turn_number = 3
	var rebuild_score := _score(strategy, action, state)
	return run_checks([
		assert_true(opening_score >= 5000.0, "Opening Trolley must decisively launch both missing seeds (score=%f)" % opening_score),
		assert_true(opening_score >= rebuild_score + 2500.0, "The bonus must retire before midgame rebuilds (opening=%f rebuild=%f)" % [opening_score, rebuild_score]),
	])


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_basic("Opening Pivot", 70))
	state.players[1].active_pokemon = _slot(_basic("Opponent", 220), 1)
	return state


func _basic(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
