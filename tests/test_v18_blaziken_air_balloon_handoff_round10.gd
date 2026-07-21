class_name TestV18BlazikenAirBalloonHandoffRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_air_balloon_unlocks_the_active_blaziken_handoff() -> String:
	var strategy := _strategy()
	var state := _state()
	var balloon := _tool("Air Balloon")
	var active_action := {
		"kind": "attach_tool",
		"card": balloon,
		"target_slot": state.players[0].active_pokemon,
	}
	var bench_action := {
		"kind": "attach_tool",
		"card": balloon,
		"target_slot": state.players[0].bench[0],
	}
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var active_score := float(strategy.call("score_action_absolute_with_plan", active_action, state, 0, plan))
	var bench_score := float(strategy.call("score_action_absolute_with_plan", bench_action, state, 0, plan))
	return run_checks([
		assert_true(active_score >= 4500.0, "Air Balloon on the stranded active Blaziken must unlock the ready Dragapult handoff (score=%f)" % active_score),
		assert_true(active_score >= bench_score + 2500.0, "Active Blaziken must beat parking Air Balloon on the ready Bench Dragapult (active=%f bench=%f)" % [active_score, bench_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 37
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var blaziken := _slot(_pokemon("Blaziken ex", "Stage 2", "RC", 2))
	blaziken.damage_counters = 140
	state.players[0].active_pokemon = blaziken
	var dragapult := _slot(_pokemon("Dragapult ex", "Stage 2", "RP", 1))
	dragapult.attached_energy.assign([_energy("Fire Energy", "R"), _energy("Psychic Energy", "P")])
	state.players[0].bench.append(dragapult)
	state.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "LLLC", 4), 1)
	return state


func _pokemon(name: String, stage: String, cost: String, retreat_cost: int) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if name.ends_with(" ex") else ""
	card.hp = 320 if stage == "Stage 2" else 230
	card.retreat_cost = retreat_cost
	card.attacks = [{"name": "Test", "cost": cost, "damage": "200"}]
	return card


func _energy(name: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return CardInstance.create(card, 0)


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
