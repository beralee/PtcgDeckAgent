class_name TestV18AcademyGardevoirVisiblePrizeDrawRound9
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018498.json"


func test_visible_scream_tail_prize_stops_draw_supporter_churn() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var scream := _slot(_card("CSV6C_065"), 0)
	scream.damage_counters = 40
	scream.attached_energy.assign([_energy("P"), _energy("P")])
	player.active_pokemon = scream
	state.players[1].active_pokemon = _slot(_defender(70), 1)
	var research := CardInstance.create(_card("CSV1C_121"), 0)
	player.hand.append(research)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var research_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": research,
	}, state, 0, plan))
	var attack_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attack", "source_slot": scream, "projected_knockout": true,
	}, state, 0, plan))
	return run_checks([
		assert_true(research_score <= -3500.0,
			"A visible Scream Tail prize must stop draw churn (score=%f)" % research_score),
		assert_true(attack_score > research_score,
			"The visible prize attack must outrank Professor's Research"),
	])


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
	state.turn_number = 17
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
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _defender(hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = "Visible prize defender"
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
