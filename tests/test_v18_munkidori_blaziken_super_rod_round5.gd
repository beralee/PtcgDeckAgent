class_name TestV18MunkidoriBlazikenSuperRodRound5
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_super_rod_waits_when_only_redundant_route_bodies_are_discarded() -> String:
	var strategy := _load_strategy()
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
	]
	if strategy == null:
		return run_checks(checks)

	var redundant := _state(12)
	var redundant_player: PlayerState = redundant.players[0]
	redundant_player.active_pokemon = _slot(_pokemon("Pecharunt", "Basic"))
	redundant_player.bench = [
		_slot(_pokemon("Blaziken ex", "Stage 2")),
		_slot(_pokemon("Munkidori", "Basic")),
	]
	for _copy: int in 3:
		redundant_player.discard_pile.append(_instance(_pokemon("Munkidori", "Basic")))
	var redundant_score := _score(strategy, _super_rod(), redundant)

	var broken := _state(12)
	var broken_player: PlayerState = broken.players[0]
	broken_player.active_pokemon = _slot(_pokemon("Pecharunt", "Basic"))
	broken_player.bench = [_slot(_pokemon("Torchic", "Basic"))]
	broken_player.discard_pile.append(_instance(_pokemon("Combusken", "Stage 1")))
	var broken_score := _score(strategy, _super_rod(), broken)

	var low_deck := _state(4)
	var low_player: PlayerState = low_deck.players[0]
	low_player.active_pokemon = _slot(_pokemon("Pecharunt", "Basic"))
	low_player.bench = [
		_slot(_pokemon("Blaziken ex", "Stage 2")),
		_slot(_pokemon("Munkidori", "Basic")),
	]
	low_player.discard_pile.append(_instance(_pokemon("Munkidori", "Basic")))
	var low_score := _score(strategy, _super_rod(), low_deck)

	checks.append_array([
		assert_true(redundant_score <= -1000.0, "A healthy deck must not spend Super Rod on duplicate Munkidori after both engines are already live (score=%f)" % redundant_score),
		assert_true(broken_score >= redundant_score + 4000.0, "A discarded Combusken that repairs a live Torchic lane must keep Super Rod available (broken=%f redundant=%f)" % [broken_score, redundant_score]),
		assert_true(low_score >= redundant_score + 4000.0, "The duplicate guard must retire near deck-out so Super Rod can refill the deck (low=%f redundant=%f)" % [low_score, redundant_score]),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, card: CardInstance, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": card,
		"productive": true,
	}, state, 0, plan))


func _state(deck_size: int) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 21
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	for index: int in deck_size:
		state.players[0].deck.append(_instance(_item("Deck filler %d" % index)))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic"), 1)
	return state


func _pokemon(card_name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 320 if stage == "Stage 2" else 90
	card.attacks = [{"name": "Test", "cost": "RC", "damage": "200"}]
	return card


func _item(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Item"
	return card


func _super_rod() -> CardInstance:
	return _instance(_item("Super Rod"))


func _instance(card: CardData, owner: int = 0) -> CardInstance:
	return CardInstance.create(card, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_instance(card, owner))
	return slot
