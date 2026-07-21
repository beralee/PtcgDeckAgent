class_name TestV18PidgeotSaltEnergyRouteRound6
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018359


func test_special_energy_stays_on_incomplete_salt_lane_instead_of_bench_pidgeot() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var nacli := _slot(_pokemon("Nacli", "Basic", 70, 2))
	var pidgeot := _slot(_pokemon("Pidgeot ex", "Stage 2", 280, 2, "8105afde9792c2596166f318a480d041"))
	nacli.attached_energy.append(_energy("Fighting Energy", "Basic Energy", "F"))
	player.active_pokemon = nacli
	player.bench.append(pidgeot)
	var luminous := _energy("Luminous Energy", "Special Energy", "ANY")
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var salt_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": luminous, "target_slot": nacli,
	}, state, 0, plan))
	var pidgeot_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": luminous, "target_slot": pidgeot,
	}, state, 0, plan))
	return run_checks([
		assert_true(pidgeot_score <= -3000.0, "Bench Pidgeot must not consume the salt lane's bridge Energy (score=%f)" % pidgeot_score),
		assert_true(salt_score >= pidgeot_score + 4000.0, "The incomplete Nacli lane must decisively outrank Pidgeot (salt=%f pidgeot=%f)" % [salt_score, pidgeot_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", 220, 1))
	return state


func _pokemon(name: String, stage: String, hp: int, retreat: int, effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.retreat_cost = retreat
	card.effect_id = effect_id
	card.attacks = [{"name": "Test", "cost": "FFC", "damage": "130"}]
	return card


func _energy(name: String, card_type: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = card_type
	card.energy_type = provides
	card.energy_provides = provides
	return CardInstance.create(card, 0)


func _slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
