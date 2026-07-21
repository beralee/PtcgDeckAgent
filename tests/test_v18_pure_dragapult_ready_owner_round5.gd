class_name TestV18PureDragapultReadyOwnerRound5
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018499.json"


func test_ready_active_dragapult_converts_before_retreating_to_an_unready_copy() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production registry")
	var state := _state()
	var player: PlayerState = state.players[0]
	var active := _slot(_card("CSV8C_159"), 0)
	active.attached_energy.assign([_energy("R"), _energy("P")])
	var bench_copy := _slot(_card("CSV8C_159"), 0)
	player.active_pokemon = active
	player.bench.append(bench_copy)
	state.players[1].active_pokemon = _slot(_defender(), 1)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var retreat_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": bench_copy,
		"energy_to_discard": [active.attached_energy[0]],
	}, state, 0, plan))
	var attack_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": active,
		"attack_index": 1,
		"projected_damage": 200,
		"projected_knockout": false,
	}, state, 0, plan))
	return run_checks([
		assert_true(retreat_score <= -3200.0,
			"A Phantom Dive-ready route owner must not retreat into an unfunded copy (score=%f)" % retreat_score),
		assert_true(attack_score > retreat_score,
			"The ready conversion attack must outrank the wasteful handoff"),
	])


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(raw)) \
		if raw is Dictionary else null


func _state() -> GameState:
	var state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	for index: int in 4:
		state.players[0].prizes.append(_filler("Own prize %d" % index, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % index, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _energy(symbol: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy" if symbol == "R" else "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Conversion defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 330
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _filler(card_name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)
