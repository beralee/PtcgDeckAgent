class_name TestV18Stage2ArvenBeforeChipRound10
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15301_arven_route_outranks_repeated_swinub_chip_attack() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var torchic: CardData = CardDatabase.get_card("CSV7C", "036")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var arven: CardData = CardDatabase.get_card("CSV1C", "123")
	var rare_candy: CardData = CardDatabase.get_card("CSVH1C", "045")
	var tm_evolution: CardData = CardDatabase.get_card("CSV5C", "119")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800017047 should resolve through the production registry"),
		assert_not_null(swinub, "Swinub should load"),
		assert_not_null(torchic, "Torchic should load"),
		assert_not_null(fighting, "Fighting Energy should load"),
		assert_not_null(arven, "Arven should load"),
		assert_not_null(rare_candy, "Rare Candy should load"),
		assert_not_null(tm_evolution, "TM Evolution should load"),
	]
	if strategy == null or swinub == null or torchic == null or fighting == null \
			or arven == null or rare_candy == null or tm_evolution == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var active_swinub := _make_slot(swinub)
	active_swinub.attached_energy.append(CardInstance.create(fighting, 0))
	active_swinub.attached_energy.append(CardInstance.create(fighting, 0))
	player.active_pokemon = active_swinub
	player.bench = [_make_slot(torchic)]
	var rare_candy_instance := CardInstance.create(rare_candy, 0)
	var tm_evolution_instance := CardInstance.create(tm_evolution, 0)
	var arven_action := {
		"kind": "play_trainer",
		"card": CardInstance.create(arven, 0),
		"productive": true,
		"targets": [{"search_item": [rare_candy_instance], "search_tool": [tm_evolution_instance]}],
	}
	var chip_attack := {
		"kind": "attack",
		"source_slot": active_swinub,
		"attack_index": 0,
		"projected_damage": 30,
		"projected_knockout": false,
	}
	var arven_score := _score(strategy, arven_action, state)
	var chip_score := _score(strategy, chip_attack, state)
	checks.append_array([
		assert_true(arven_score >= 2900.0, "The production wrapper should preserve Arven's live route-search priority (score=%f)" % arven_score),
		assert_true(arven_score > chip_score, "Arven must beat another low-damage Swinub attack while Mamoswine setup debt remains (arven=%f chip=%f)" % [arven_score, chip_score]),
	])
	return run_checks(checks)


func test_arven_floor_requires_a_stage2_route_target_in_deck() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var arven: CardData = CardDatabase.get_card("CSV1C", "123")
	if strategy == null or swinub == null or arven == null:
		return assert_true(false, "The production strategy, Swinub, and Arven should load")
	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(swinub)
	var score := _score(strategy, {
		"kind": "play_trainer",
		"card": CardInstance.create(arven, 0),
		"productive": true,
	}, state)
	return assert_true(score < 3900.0, "Arven must not receive the route floor when no Candy, TM, or Vessel remains in deck (score=%f)" % score)


func test_arven_floor_requires_both_resolved_route_halves() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var arven: CardData = CardDatabase.get_card("CSV1C", "123")
	var rare_candy: CardData = CardDatabase.get_card("CSVH1C", "045")
	var tm_evolution: CardData = CardDatabase.get_card("CSV5C", "119")
	if strategy == null or swinub == null or arven == null or rare_candy == null or tm_evolution == null:
		return assert_true(false, "The production strategy and partial Arven route should load")
	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(swinub)
	state.players[0].deck.append(CardInstance.create(rare_candy, 0))
	var score := _score(strategy, {
		"kind": "play_trainer",
		"card": CardInstance.create(arven, 0),
		"productive": true,
		"targets": [{"search_tool": [CardInstance.create(tm_evolution, 0)]}],
	}, state)
	return assert_true(
		score < 2900.0,
		"A partial Arven target must not receive the complete Stage 2 route floor (score=%f)" % score
	)


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
	opponent.active_pokemon = _make_slot(_test_pokemon("Opponent", 220))
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 6
	state.phase = GameState.GamePhase.MAIN
	return state


func _test_pokemon(card_name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
