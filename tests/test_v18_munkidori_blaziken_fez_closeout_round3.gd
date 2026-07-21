class_name TestV18MunkidoriBlazikenFezCloseoutRound3
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_low_deck_fezandipiti_draw_loses_to_preserving_the_next_draw() -> String:
	var strategy := _load_strategy()
	var pecharunt: CardData = CardDatabase.get_card("CSV9C", "127")
	var fezandipiti: CardData = CardDatabase.get_card("CSV8C", "135")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
		assert_not_null(pecharunt, "Pecharunt should load"),
		assert_not_null(fezandipiti, "Fezandipiti ex should load"),
	]
	if strategy == null or pecharunt == null or fezandipiti == null:
		return run_checks(checks)

	var low_state := _make_state(4)
	var low_player: PlayerState = low_state.players[0]
	low_player.active_pokemon = _make_slot(pecharunt)
	var low_fez := _make_slot(fezandipiti)
	low_player.bench = [low_fez]
	var low_score := _score(strategy, {"kind": "use_ability", "source_slot": low_fez}, low_state)
	var end_score := _score(strategy, {"kind": "end_turn"}, low_state)

	var safe_state := _make_state(5)
	var safe_player: PlayerState = safe_state.players[0]
	safe_player.active_pokemon = _make_slot(pecharunt)
	var safe_fez := _make_slot(fezandipiti)
	safe_player.bench = [safe_fez]
	var safe_score := _score(strategy, {"kind": "use_ability", "source_slot": safe_fez}, safe_state)
	checks.append_array([
		assert_true(low_score < end_score, "At four cards or fewer, optional Fezandipiti draw must lose to preserving the next turn draw (fez=%f end=%f)" % [low_score, end_score]),
		assert_true(safe_score >= 2000.0 and safe_score > end_score, "Above the critical deck floor, Fezandipiti should remain a clearly positive production action after wrapper continuity adjustment (fez=%f end=%f)" % [safe_score, end_score]),
		assert_true(safe_score > low_score + 5000.0, "The critical deck boundary must materially distinguish safe and deck-out-risk Fezandipiti use"),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _make_state(deck_size: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	for index: int in deck_size:
		player.deck.append(CardInstance.create(_item("Deck filler %d" % index), 0))
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 21
	state.phase = GameState.GamePhase.MAIN
	return state


func _item(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Item"
	return card


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
