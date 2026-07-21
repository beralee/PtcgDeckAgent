class_name TestV18AcademyGardevoirArtazonPaddingRound8
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018498.json"


func test_developed_four_bench_shell_reserves_final_slot_from_artazon() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_card("CSV6C_065"), 0)
	player.bench.assign([
		_slot(_card("CSV2C_053"), 0),
		_slot(_card("CSV2C_053"), 0),
		_slot(_card("CSV8C_094"), 0),
		_slot(_card("CSV2C_060"), 0),
	])
	state.players[1].active_pokemon = _slot(_defender(), 1)
	var artazon := CardInstance.create(_card("CSV2C_127"), 0)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "use_stadium_effect", "card": artazon,
	}, state, 0, plan))
	return assert_true(score <= -3500.0,
		"A developed Academy shell must reserve its final bench slot (score=%f)" % score)


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
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	for i: int in 6:
		state.players[0].prizes.append(_filler("Own prize %d" % i, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % i, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Academy padding defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 260
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
