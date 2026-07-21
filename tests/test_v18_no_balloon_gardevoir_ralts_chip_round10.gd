class_name TestV18NoBalloonGardevoirRaltsChipRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800017097.json"


func test_nonlethal_confuse_ray_does_not_claim_the_second_psychic() -> String:
	var strategy := _strategy()
	var state := _state(6)
	var ralts := _slot(_card("CSV2C_053"), 0)
	ralts.attached_energy.append(_energy("P"))
	state.players[0].active_pokemon = ralts
	state.players[1].active_pokemon = _slot(_defender(220), 1)
	var proposed := _energy("P")
	state.players[0].hand.append(proposed)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": proposed, "target_slot": ralts,
	}, state, 0, plan))
	return assert_true(score <= -3000.0,
		"A nonlethal 30-damage Ralts chip must reserve the second Psychic for the real attacker (score=%f)" % score)


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(raw))


func _state(prize_count: int) -> GameState:
	var state := GameState.new()
	for i: int in 2:
		var player := PlayerState.new()
		player.player_index = i
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for i: int in prize_count:
		state.players[0].prizes.append(_filler("Own prize %d" % i, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % i, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _energy(symbol: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _defender(hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = "Chip defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _filler(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Item"
	return CardInstance.create(card, owner)
