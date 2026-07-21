class_name TestV18BlazikenFullBenchArtazonRound7
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_artazon_is_not_donated_to_the_opponent_with_a_full_bench() -> String:
	var strategy := _strategy()
	var full := _state(5)
	var open := _state(4)
	var artazon := _stadium("Artazon")
	var full_score := _score(strategy, full, artazon)
	var open_score := _score(strategy, open, artazon)
	return run_checks([
		assert_true(full_score <= -2500.0, "Artazon must not be placed into an empty Stadium zone when our Bench is already full (score=%f)" % full_score),
		assert_true(open_score >= full_score + 2000.0, "Artazon must return while our Bench still has a usable slot (open=%f full=%f)" % [open_score, full_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, state: GameState, stadium: CardInstance) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_stadium",
		"card": stadium,
		"productive": true,
		"targets": [],
	}, state, 0, plan))


func _state(bench_size: int) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 13
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Dragapult ex", "Stage 2", "RP"))
	var bench_names := ["Drakloak", "Blaziken ex", "Dreepy", "Munkidori", "Fezandipiti ex"]
	for index: int in bench_size:
		state.players[0].bench.append(_slot(_pokemon(str(bench_names[index]), "Basic", "C")))
	state.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic", "LL"), 1)
	return state


func _pokemon(name: String, stage: String, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if name.ends_with(" ex") else ""
	card.hp = 320 if stage == "Stage 2" else 120
	card.attacks = [{"name": "Test", "cost": cost, "damage": "100"}]
	return card


func _stadium(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Stadium"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
