class_name TestV18YanmegaScoopHandoffRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800033475


func test_scoop_up_cyclone_removes_the_active_pivot_for_yanmega() -> String:
	var strategy := _strategy()
	var live := _state(true)
	var inactive := _state(false)
	var step := {"id": "scoop_up_cyclone_target"}
	var live_context := {"game_state": live, "player_index": 0}
	var inactive_context := {"game_state": inactive, "player_index": 0}
	var active_score := float(strategy.call("score_interaction_target", live.players[0].active_pokemon, step, live_context))
	var bench_score := float(strategy.call("score_interaction_target", live.players[0].bench[1], step, live_context))
	var inactive_score := float(strategy.call("score_interaction_target", inactive.players[0].active_pokemon, step, inactive_context))
	return run_checks([
		assert_true(active_score >= 5000.0, "Scoop Up Cyclone must lift the active pivot when Yanmega is waiting on the Bench (score=%f)" % active_score),
		assert_true(active_score >= bench_score + 2500.0, "The active pivot must beat cycling an unrelated Bench Pokemon (active=%f bench=%f)" % [active_score, bench_score]),
		assert_true(inactive_score < 5000.0, "The forced Scoop handoff must retire when no benched Yanmega exists (score=%f)" % inactive_score),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state(with_yanmega: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 19
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Dunsparce", "Basic", "C"))
	if with_yanmega:
		state.players[0].bench.append(_slot(_pokemon("Yanmega ex", "Stage 1", "GGG")))
	else:
		state.players[0].bench.append(_slot(_pokemon("Yanma", "Basic", "G")))
	state.players[0].bench.append(_slot(_pokemon("Budew", "Basic", "")))
	state.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "LLLC"), 1)
	return state


func _pokemon(name: String, stage: String, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if name.ends_with(" ex") else ""
	card.hp = 280 if stage == "Stage 1" else 70
	card.attacks = [{"name": "Test", "cost": cost, "damage": "100"}]
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
