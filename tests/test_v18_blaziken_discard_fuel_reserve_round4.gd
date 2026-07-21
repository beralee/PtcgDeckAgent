class_name TestV18BlazikenDiscardFuelReserveRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_recovery_items_do_not_remove_live_boiling_spirit_fuel() -> String:
	var strategy := _strategy()
	var live := _state(true)
	var rod := _item("Super Rod")
	var stretcher := _item("Night Stretcher")
	var plan: Dictionary = strategy.call("build_turn_plan", live, 0, {})
	var rod_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": rod, "productive": true,
	}, live, 0, plan))
	var stretcher_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": stretcher, "productive": true,
	}, live, 0, plan))
	var retired := _state(false)
	var retired_plan: Dictionary = strategy.call("build_turn_plan", retired, 0, {})
	var retired_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": rod, "productive": true,
	}, retired, 0, retired_plan))
	return run_checks([
		assert_true(rod_score <= -3000.0, "Super Rod must not shuffle away Fire that Boiling Spirit can attach to Dragapult (score=%f)" % rod_score),
		assert_true(stretcher_score <= -3000.0, "Night Stretcher must not pull the reserved Fire out of the discard pile (score=%f)" % stretcher_score),
		assert_true(retired_score >= rod_score + 2000.0, "The reserve must retire when discard no longer contains a missing Dragapult color (retired=%f live=%f)" % [retired_score, rod_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state(with_fire_fuel: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Cleffa", "Basic", ""))
	state.players[0].bench.append(_slot(_pokemon("Blaziken ex", "Stage 2", "RC")))
	var dragapult := _slot(_pokemon("Dragapult ex", "Stage 2", "RP"))
	dragapult.attached_energy.append(_energy("Psychic Energy", "P"))
	state.players[0].bench.append(dragapult)
	if with_fire_fuel:
		state.players[0].discard_pile.append(_energy("Fire Energy", "R"))
	else:
		state.players[0].discard_pile.append(_energy("Psychic Energy", "P"))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", "C"), 1)
	return state


func _pokemon(name: String, stage: String, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 320 if stage == "Stage 2" else 70
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
