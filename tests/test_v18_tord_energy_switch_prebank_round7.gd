class_name TestV18TordEnergySwitchPrebankRound7
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800015934.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15302_prebanks_energy_on_latias_before_tera_arrives() -> String:
	var strategy := _load_strategy()
	var hoothoot: CardData = CardDatabase.get_card("CSV9C", "154")
	var latias: CardData = CardDatabase.get_card("CSV9C", "078")
	var fezandipiti: CardData = CardDatabase.get_card("CSV8C", "135")
	var grass: CardData = CardDatabase.get_card("CSVE1C", "GRA")
	var energy_switch: CardData = CardDatabase.get_card("CSVH1aC", "008")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800015934 should resolve through the production registry"),
		assert_not_null(hoothoot, "Hoothoot should load"),
		assert_not_null(latias, "Latias ex should load"),
		assert_not_null(fezandipiti, "Fezandipiti ex should load"),
		assert_not_null(grass, "Grass Energy should load"),
		assert_not_null(energy_switch, "Energy Switch should load"),
	]
	if strategy == null or hoothoot == null or latias == null or fezandipiti == null \
			or grass == null or energy_switch == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var active_hoothoot := _make_slot(hoothoot)
	var latias_bank := _make_slot(latias)
	var fez_bank := _make_slot(fezandipiti)
	player.active_pokemon = active_hoothoot
	player.bench = [latias_bank, fez_bank]
	player.deck.append(CardInstance.create(energy_switch, 0))
	var energy := CardInstance.create(grass, 0)
	var latias_score := _score(strategy, _attach(energy, latias_bank), state)
	var fez_score := _score(strategy, _attach(energy, fez_bank), state)
	var hoothoot_score := _score(strategy, _attach(energy, active_hoothoot), state)
	var end_score := _score(strategy, {"kind": "end_turn"}, state)
	checks.append_array([
		assert_true(latias_score >= 2900.0, "A no-Tera opening should prebank one Energy on Latias for Energy Switch (score=%f)" % latias_score),
		assert_true(fez_score >= 2700.0, "Fezandipiti should remain the secondary prebank target (score=%f)" % fez_score),
		assert_true(latias_score > hoothoot_score, "The Energy bank must avoid consuming the evolving Hoothoot lane (latias=%f hoothoot=%f)" % [latias_score, hoothoot_score]),
		assert_true(latias_score > end_score, "Prebanking future Terapagos Energy must beat another empty turn (attach=%f end=%f)" % [latias_score, end_score]),
	])
	return run_checks(checks)


func test_prebank_override_releases_after_tera_enters_play() -> String:
	var strategy := _load_strategy()
	var terapagos: CardData = CardDatabase.get_card("CSV9C", "175")
	var latias: CardData = CardDatabase.get_card("CSV9C", "078")
	var grass: CardData = CardDatabase.get_card("CSVE1C", "GRA")
	var energy_switch: CardData = CardDatabase.get_card("CSVH1aC", "008")
	if strategy == null or terapagos == null or latias == null or grass == null or energy_switch == null:
		return assert_true(false, "The production strategy and Tord prebank fixtures should load")
	var state := _make_state()
	var latias_bank := _make_slot(latias)
	state.players[0].active_pokemon = _make_slot(terapagos)
	state.players[0].bench = [latias_bank]
	state.players[0].deck.append(CardInstance.create(energy_switch, 0))
	var score := _score(strategy, _attach(CardInstance.create(grass, 0), latias_bank), state)
	return assert_true(score < 2900.0, "Once Tera is in play, Energy should return to the direct attacker route (Latias score=%f)" % score)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _attach(energy: CardInstance, target: PokemonSlot) -> Dictionary:
	return {"kind": "attach_energy", "card": energy, "target_slot": target}


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
