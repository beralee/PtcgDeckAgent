class_name TestV18AcademyGardevoirDarkOwnerRound5
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018498.json"


func test_darkness_waits_for_munkidori_in_hand_instead_of_attaching_to_kirlia() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var kirlia := _slot(_card("CS6.5C_030"), 0)
	player.active_pokemon = kirlia
	player.hand.append(CardInstance.create(_card("CSV8C_094"), 0))
	var darkness := _energy("D")
	player.hand.append(darkness)
	state.players[1].active_pokemon = _slot(_defender(), 1)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": darkness, "target_slot": kirlia,
	}, state, 0, plan))
	return assert_true(score <= -3800.0,
		"Academy Darkness must wait for the Munkidori owner already in hand (score=%f)" % score)


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(raw))


func _state() -> GameState:
	var state := GameState.new()
	for i: int in 2:
		var player := PlayerState.new()
		player.player_index = i
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for i: int in 6:
		state.players[0].prizes.append(_filler("Own prize %d" % i, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % i, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _energy(symbol: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Darkness Energy" if symbol == "D" else "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Darkness owner defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 220
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
