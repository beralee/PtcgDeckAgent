class_name TestV18TordCrispinOverchargeRound9
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800015934.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15304_crispin_funds_terapagos_before_manual_attachment() -> String:
	var strategy := _load_strategy()
	var terapagos: CardData = CardDatabase.get_card("CSV9C", "175")
	var crispin: CardData = CardDatabase.get_card("CSV9C", "196")
	var grass: CardData = CardDatabase.get_card("CSVE1C", "GRA")
	var water: CardData = CardDatabase.get_card("CSVE1C", "WAT")
	var lightning: CardData = CardDatabase.get_card("CSVE1C", "LIG")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800015934 should resolve through the production registry"),
		assert_not_null(terapagos, "Terapagos ex should load"),
		assert_not_null(crispin, "Crispin should load"),
		assert_not_null(grass, "Grass Energy should load"),
		assert_not_null(water, "Water Energy should load"),
		assert_not_null(lightning, "Lightning Energy should load"),
	]
	if strategy == null or terapagos == null or crispin == null or grass == null \
			or water == null or lightning == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := _make_slot(terapagos)
	attacker.attached_energy.append(CardInstance.create(grass, 0))
	player.active_pokemon = attacker
	player.deck.append_array([
		CardInstance.create(water, 0),
		CardInstance.create(lightning, 0),
	])
	var crispin_instance := CardInstance.create(crispin, 0)
	var route_score := _score(strategy, _play_crispin(crispin_instance), state)
	var manual_score := _score(strategy, {
		"kind": "attach_energy",
		"card": CardInstance.create(water, 0),
		"target_slot": attacker,
	}, state)

	attacker.attached_energy.append(CardInstance.create(water, 0))
	var overcharge_score := _score(strategy, _play_crispin(crispin_instance), state)
	checks.append_array([
		assert_true(route_score >= 3500.0, "With Terapagos one Energy short, Crispin must be a primary launch action (score=%f)" % route_score),
		assert_true(route_score >= manual_score + 500.0, "Crispin must act before the manual attachment so its accelerated Energy is not wasted (Crispin=%f attach=%f)" % [route_score, manual_score]),
		assert_true(overcharge_score <= -2500.0, "Once a Tera attacker is ready, Crispin must not stack a third Energy onto it (score=%f)" % overcharge_score),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _play_crispin(card: CardInstance) -> Dictionary:
	return {
		"kind": "play_trainer",
		"card": card,
		"productive": true,
		"requires_interaction": true,
	}


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
