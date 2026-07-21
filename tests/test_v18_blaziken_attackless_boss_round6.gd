class_name TestV18BlazikenAttacklessBossRound6
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_boss_waits_for_a_live_dragapult_attack_window() -> String:
	var strategy := _strategy()
	var stalled := _state(false)
	var ready := _state(true)
	var boss := _supporter("Boss's Orders")
	var stalled_score := _score(strategy, stalled, boss)
	var ready_score := _score(strategy, ready, boss)
	return run_checks([
		assert_true(stalled_score <= -2500.0, "Boss's Orders must not be spent when the active Pokemon has no legal attack window (score=%f)" % stalled_score),
		assert_true(ready_score >= stalled_score + 2000.0, "Boss's Orders must return when Dragapult can attack (ready=%f stalled=%f)" % [ready_score, stalled_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, state: GameState, boss: CardInstance) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": boss,
		"productive": true,
		"targets": [{"opponent_bench_target": [state.players[1].bench[0]]}],
	}, state, 0, plan))


func _state(can_attack: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 35
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var active := _slot(_pokemon("Dragapult ex", "Stage 2", "RP"))
	if can_attack:
		active.attached_energy.assign([_energy("Fire Energy", "R"), _energy("Psychic Energy", "P")])
	state.players[0].active_pokemon = active
	state.players[0].bench.append(_slot(_pokemon("Blaziken ex", "Stage 2", "RR")))
	state.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "LLLC"), 1)
	state.players[1].bench.append(_slot(_pokemon("Fezandipiti ex", "Basic", "C"), 1))
	return state


func _pokemon(name: String, stage: String, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if name.ends_with(" ex") else ""
	card.hp = 320 if stage == "Stage 2" else 230
	card.attacks = [{"name": "Test", "cost": cost, "damage": "200"}]
	return card


func _energy(name: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return CardInstance.create(card, 0)


func _supporter(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Supporter"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
