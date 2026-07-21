class_name TestV18PureDragapultCloseoutReconRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018499.json"


func test_two_prize_closeout_does_not_recon_before_phantom_dive() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var active := _slot(_card("CSV8C_159"), 0)
	active.attached_energy.assign([_energy("R"), _energy("P")])
	var drakloak := _slot(_card("CSV8C_158"), 0)
	player.active_pokemon = active
	player.bench.append(drakloak)
	player.deck.append(_filler("Deck card", 0))
	state.players[1].active_pokemon = _slot(_defender(), 1)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var recon_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability", "source_slot": drakloak,
	}, state, 0, plan))
	var attack_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attack", "source_slot": active, "attack_index": 1,
		"projected_damage": 200, "projected_knockout": false,
	}, state, 0, plan))
	return run_checks([
		assert_true(recon_score <= -3500.0,
			"Two-Prize closeout must not Recon before attacking (score=%f)" % recon_score),
		assert_true(attack_score > recon_score,
			"Ready Phantom Dive must outrank optional Reconnaissance"),
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
	for i: int in 2:
		state.players[0].prizes.append(_filler("Own prize %d" % i, 0))
	for i: int in 4:
		state.players[1].prizes.append(_filler("Opponent prize %d" % i, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _energy(symbol: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy" if symbol == "R" else "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Closeout defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 330
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
