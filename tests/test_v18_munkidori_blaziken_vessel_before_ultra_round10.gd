class_name TestV18MunkidoriBlazikenVesselBeforeUltraRound10
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15303_banks_attack_energy_before_ultra_ball() -> String:
	var strategy := _load_strategy()
	var combusken: CardData = CardDatabase.get_card("CSV10C", "037")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var ultra_ball: CardData = CardDatabase.get_card("CSV1C", "112")
	var earthen_vessel: CardData = CardDatabase.get_card("CSV6C", "115")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
		assert_not_null(combusken, "Combusken should load"),
		assert_not_null(blaziken, "Blaziken ex should load"),
		assert_not_null(ultra_ball, "Ultra Ball should load"),
		assert_not_null(earthen_vessel, "Earthen Vessel should load"),
		assert_not_null(fire, "Fire Energy should load"),
	]
	if strategy == null or combusken == null or blaziken == null \
			or ultra_ball == null or earthen_vessel == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(combusken)
	player.hand.append_array([
		CardInstance.create(ultra_ball, 0),
		CardInstance.create(earthen_vessel, 0),
	])
	player.deck.append_array([
		CardInstance.create(blaziken, 0),
		CardInstance.create(fire, 0),
	])
	player.discard_pile.append(CardInstance.create(fire, 0))

	var vessel_score := _score(strategy, _play(earthen_vessel), state)
	var ultra_score := _score(strategy, _play(ultra_ball), state)

	player.hand.append(CardInstance.create(fire, 0))
	var already_banked_score := _score(strategy, _play(earthen_vessel), state)
	player.hand.pop_back()
	player.discard_pile.clear()
	var no_acceleration_score := _score(strategy, _play(earthen_vessel), state)
	checks.append_array([
		assert_true(vessel_score >= 5000.0, "Earthen Vessel must bank the manual attachment before Ultra Ball closes the Blaziken ex route (score=%f)" % vessel_score),
		assert_true(vessel_score >= ultra_score + 600.0, "The attack-enabling Vessel must precede Ultra Ball instead of being discarded by it (Vessel=%f Ultra=%f)" % [vessel_score, ultra_score]),
		assert_true(already_banked_score <= ultra_score, "The ordering override must retire once a basic Energy is already in hand (banked=%f Ultra=%f)" % [already_banked_score, ultra_score]),
		assert_true(no_acceleration_score <= ultra_score, "The ordering override must retire without discard Energy for Boiling Spirit (inactive=%f Ultra=%f)" % [no_acceleration_score, ultra_score]),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _play(card: CardData) -> Dictionary:
	return {
		"kind": "play_trainer",
		"card": CardInstance.create(card, 0),
	}


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 12
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
