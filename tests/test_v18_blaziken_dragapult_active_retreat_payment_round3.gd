class_name TestV18BlazikenDragapultActiveRetreatPaymentRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_fire_completes_active_blaziken_retreat_before_overinvesting_bench_dragapult() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var blaziken := _slot(_pokemon("Blaziken ex", "Stage 2", 2, "RRC"))
	blaziken.attached_energy.append(_energy("Darkness Energy", "D"))
	var dragapult := _slot(_pokemon("Dragapult ex", "Stage 2", 1, "RP"))
	dragapult.attached_energy.assign([_energy("Psychic Energy", "P"), _energy("Psychic Energy", "P")])
	player.active_pokemon = blaziken
	player.bench.append(dragapult)
	var fire := _energy("Fire Energy", "R")
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var bridge_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": blaziken,
	}, state, 0, plan))
	var overinvest_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": dragapult,
	}, state, 0, plan))
	return run_checks([
		assert_true(bridge_score >= 6000.0, "Fire should complete the Active Blaziken retreat payment (score=%f)" % bridge_score),
		assert_true(bridge_score >= overinvest_score + 500.0, "Retreat payment must precede a third Energy on Bench Dragapult (bridge=%f bench=%f)" % [bridge_score, overinvest_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", 1, "C"), 1)
	return state


func _pokemon(name: String, stage: String, retreat: int, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 320
	card.retreat_cost = retreat
	card.attacks = [{"name": "Test", "cost": cost, "damage": "200"}]
	return card


func _energy(name: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
