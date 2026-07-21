class_name TestV18Stage2FightingOverinvestmentRound9
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15301_combusken_evolution_outranks_third_fighting_on_swinub() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var torchic: CardData = CardDatabase.get_card("CSV7C", "036")
	var combusken: CardData = CardDatabase.get_card("CSV7C", "037")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800017047 should resolve through the production registry"),
		assert_not_null(swinub, "Swinub should load"),
		assert_not_null(torchic, "Torchic should load"),
		assert_not_null(combusken, "Combusken should load"),
		assert_not_null(fighting, "Fighting Energy should load"),
	]
	if strategy == null or swinub == null or torchic == null or combusken == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var swinub_slot := _make_slot(swinub)
	swinub_slot.attached_energy.append(CardInstance.create(fighting, 0))
	swinub_slot.attached_energy.append(CardInstance.create(fighting, 0))
	var torchic_slot := _make_slot(torchic)
	state.players[0].active_pokemon = swinub_slot
	state.players[0].bench = [torchic_slot]
	var third_fighting_score := _score(strategy, {
		"kind": "attach_energy",
		"target_slot": swinub_slot,
		"card": CardInstance.create(fighting, 0),
	}, state)
	var evolve_score := _score(strategy, {
		"kind": "evolve",
		"target_slot": torchic_slot,
		"card": CardInstance.create(combusken, 0),
	}, state)
	checks.append_array([
		assert_true(third_fighting_score < 500.0, "A Swinub already preserving FF must not receive another route-completion boost (score=%f)" % third_fighting_score),
		assert_true(evolve_score > third_fighting_score, "Combusken evolution must outrank over-investing a third Fighting Energy (evolve=%f attach=%f)" % [evolve_score, third_fighting_score]),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
