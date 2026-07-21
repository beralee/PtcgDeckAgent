class_name TestV18MunkidoriBlazikenDarkCycleRound9
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15306_does_not_recycle_the_only_dark_munkidori() -> String:
	var strategy := _load_strategy()
	var munkidori: CardData = CardDatabase.get_card("CSV8C", "094")
	var fezandipiti: CardData = CardDatabase.get_card("CSV8C", "135")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var darkness: CardData = CardDatabase.get_card("CSVE1C", "DAR")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
		assert_not_null(munkidori, "Munkidori should load"),
		assert_not_null(fezandipiti, "Fezandipiti ex should load"),
		assert_not_null(blaziken, "Blaziken ex should load"),
		assert_not_null(darkness, "Darkness Energy should load"),
		assert_not_null(fire, "Fire Energy should load"),
	]
	if strategy == null or munkidori == null or fezandipiti == null or blaziken == null \
			or darkness == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var powered_active := _make_slot(munkidori)
	powered_active.attached_energy.append(CardInstance.create(darkness, 0))
	var empty_munkidori := _make_slot(munkidori)
	var empty_fezandipiti := _make_slot(fezandipiti)
	var developing_blaziken := _make_slot(blaziken)
	developing_blaziken.attached_energy.append(CardInstance.create(fire, 0))
	player.active_pokemon = powered_active
	player.bench = [empty_munkidori, empty_fezandipiti, developing_blaziken]

	var cycle_score := _score(strategy, _retreat(empty_munkidori), state)
	var fez_cycle_score := _score(strategy, _retreat(empty_fezandipiti), state)
	empty_munkidori.attached_energy.append(CardInstance.create(darkness, 0))
	var powered_cycle_score := _score(strategy, _retreat(empty_munkidori), state)
	var stay_score := _score(strategy, {"kind": "end_turn"}, state)

	developing_blaziken.attached_energy.append(CardInstance.create(darkness, 0))
	var ready_handoff_score := _score(strategy, _retreat(developing_blaziken), state)
	checks.append_array([
		assert_true(cycle_score <= -3000.0, "The only powered Munkidori must not discard Dark merely to hand off to an empty Munkidori (score=%f)" % cycle_score),
		assert_true(fez_cycle_score <= -3000.0, "The powered active Munkidori must not discard Dark merely to expose an unready Fezandipiti ex (score=%f)" % fez_cycle_score),
		assert_true(powered_cycle_score <= -3000.0, "Two powered but attackless Munkidori must not trade the active spot without progress (score=%f)" % powered_cycle_score),
		assert_true(cycle_score < stay_score, "A no-progress Dark recycle must lose to keeping the powered active in place (cycle=%f stay=%f)" % [cycle_score, stay_score]),
		assert_true(ready_handoff_score >= 4500.0, "Retreating the powered Munkidori into a ready Blaziken ex must remain strongly preferred (score=%f)" % ready_handoff_score),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _retreat(target: PokemonSlot) -> Dictionary:
	return {
		"kind": "retreat",
		"bench_target": target,
	}


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
