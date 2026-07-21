class_name TestV18MunkidoriBlazikenBeltRound6
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15303_reserves_maximum_belt_for_blaziken_ex() -> String:
	var strategy := _load_strategy()
	var mimikyu: CardData = CardDatabase.get_card("CSV3C", "062")
	var munkidori: CardData = CardDatabase.get_card("CSV8C", "094")
	var torchic: CardData = CardDatabase.get_card("CSV10C", "036")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var belt: CardData = CardDatabase.get_card("CSV7C", "189")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
		assert_not_null(mimikyu, "Mimikyu should load"),
		assert_not_null(munkidori, "Munkidori should load"),
		assert_not_null(torchic, "Torchic should load"),
		assert_not_null(blaziken, "Blaziken ex should load"),
		assert_not_null(belt, "Maximum Belt should load"),
	]
	if strategy == null or mimikyu == null or munkidori == null or torchic == null \
			or blaziken == null or belt == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(mimikyu)
	var empty_munkidori := _make_slot(munkidori)
	var torchic_lane := _make_slot(torchic)
	var blaziken_attacker := _make_slot(blaziken)
	player.bench = [empty_munkidori, torchic_lane, blaziken_attacker]
	player.deck.append(CardInstance.create(blaziken, 0))
	var belt_instance := CardInstance.create(belt, 0)
	var wasted_score := _score(strategy, _attach_tool(belt_instance, empty_munkidori), state)
	var seed_score := _score(strategy, _attach_tool(belt_instance, torchic_lane), state)
	var attacker_score := _score(strategy, _attach_tool(belt_instance, blaziken_attacker), state)
	var end_score := _score(strategy, {"kind": "end_turn"}, state)
	checks.append_array([
		assert_true(wasted_score < end_score, "An unpowered Munkidori must not consume Maximum Belt merely to avoid ending the turn (belt=%f end=%f)" % [wasted_score, end_score]),
		assert_true(seed_score >= 2000.0, "A Torchic with Blaziken ex still accessible must carry Maximum Belt through evolution (score=%f)" % seed_score),
		assert_true(attacker_score >= 2000.0, "Blaziken ex must remain a positive Maximum Belt target (score=%f)" % attacker_score),
		assert_true(attacker_score >= wasted_score + 6000.0, "Maximum Belt must be reserved for the real two-Prize attacker (Blaziken=%f Munkidori=%f)" % [attacker_score, wasted_score]),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _attach_tool(tool: CardInstance, target: PokemonSlot) -> Dictionary:
	return {
		"kind": "attach_tool",
		"card": tool,
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
	state.turn_number = 8
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
