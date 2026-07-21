class_name TestV18BlazikenOfflineMunkidoriPaddingRound9
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_offline_munkidori_does_not_take_the_last_low_deck_bench_slot() -> String:
	var strategy := _strategy()
	var offline := _state(3, false)
	var fueled := _state(3, true)
	var early := _state(12, false)
	var munkidori := _pokemon_instance("Munkidori", "Basic")
	var offline_score := _score(strategy, offline, munkidori)
	var fueled_score := _score(strategy, fueled, munkidori)
	var early_score := _score(strategy, early, munkidori)
	return run_checks([
		assert_true(offline_score <= -2500.0, "An offline Munkidori must not take the final Bench slot with three cards left in deck (score=%f)" % offline_score),
		assert_true(fueled_score >= offline_score + 2000.0, "Munkidori must return when Blaziken can attach a discarded Darkness Energy (fueled=%f offline=%f)" % [fueled_score, offline_score]),
		assert_true(early_score >= offline_score + 2000.0, "The padding guard must retire outside the low-deck window (early=%f offline=%f)" % [early_score, offline_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, state: GameState, card: CardInstance) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_basic_to_bench",
		"card": card,
	}, state, 0, plan))


func _state(deck_size: int, darkness_in_discard: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 37
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var dragapult := _slot(_pokemon("Dragapult ex", "Stage 2"))
	dragapult.attached_energy.assign([_energy("Fire Energy", "R"), _energy("Psychic Energy", "P")])
	dragapult.damage_counters = 30
	state.players[0].active_pokemon = dragapult
	state.players[0].bench.assign([
		_slot(_pokemon("Drakloak", "Stage 1")),
		_slot(_pokemon("Blaziken ex", "Stage 2")),
		_slot(_pokemon("Dragapult ex", "Stage 2")),
		_slot(_pokemon("Dreepy", "Basic")),
	])
	for index: int in deck_size:
		state.players[0].deck.append(_item("Deck Card %d" % index))
	if darkness_in_discard:
		state.players[0].discard_pile.append(_energy("Darkness Energy", "D"))
	state.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic"), 1)
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if name.ends_with(" ex") else ""
	card.hp = 320 if stage == "Stage 2" else 110
	card.attacks = [{"name": "Test", "cost": "RP", "damage": "200"}]
	return card


func _pokemon_instance(name: String, stage: String) -> CardInstance:
	return CardInstance.create(_pokemon(name, stage), 0)


func _energy(name: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
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
