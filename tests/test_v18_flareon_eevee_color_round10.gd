class_name TestV18FlareonEeveeColorRound10
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017643.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15302_eevee_rejects_energy_outside_flareons_rwl_cost() -> String:
	var strategy := _load_strategy()
	var eevee: CardData = CardDatabase.get_card("151C", "133")
	var flareon: CardData = CardDatabase.get_card("CSV9.5C", "023")
	var water: CardData = CardDatabase.get_card("CSVE1C", "WAT")
	var lightning: CardData = CardDatabase.get_card("CSVE1C", "LIG")
	var psychic: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800017643 should resolve through the production registry"),
		assert_not_null(eevee, "The seed15302 Eevee should load"),
		assert_not_null(flareon, "Flareon ex should load"),
		assert_not_null(water, "Water Energy should load"),
		assert_not_null(lightning, "Lightning Energy should load"),
		assert_not_null(psychic, "Psychic Energy should load"),
	]
	if strategy == null or eevee == null or flareon == null or water == null \
			or lightning == null or psychic == null:
		return run_checks(checks)

	var state := _make_state()
	var eevee_lane := _make_slot(eevee)
	eevee_lane.attached_energy.append(CardInstance.create(water, 0))
	state.players[0].active_pokemon = eevee_lane
	state.players[0].deck.append(CardInstance.create(flareon, 0))
	var lightning_score := _score(strategy, _attach(lightning, eevee_lane), state)
	var psychic_score := _score(strategy, _attach(psychic, eevee_lane), state)
	checks.append_array([
		assert_true(lightning_score > 1000.0, "Lightning must remain a positive second attachment toward Flareon's RWL attack (score=%f)" % lightning_score),
		assert_true(psychic_score <= -1000.0, "Psychic does not pay Flareon's RWL cost and must not tie the compatible attachment (score=%f)" % psychic_score),
		assert_true(lightning_score >= psychic_score + 2500.0, "The typed attachment must deterministically beat the seed15302 off-color tie (lightning=%f psychic=%f)" % [lightning_score, psychic_score]),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _attach(energy: CardData, target: PokemonSlot) -> Dictionary:
	return {
		"kind": "attach_energy",
		"card": CardInstance.create(energy, 0),
		"target_slot": target,
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
