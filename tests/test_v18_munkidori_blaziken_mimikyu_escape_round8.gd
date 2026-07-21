class_name TestV18MunkidoriBlazikenMimikyuEscapeRound8
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/18000625.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15300_manual_attachment_releases_stranded_mimikyu() -> String:
	var strategy := _load_strategy()
	var mimikyu: CardData = CardDatabase.get_card("CSV3C", "062")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var darkness: CardData = CardDatabase.get_card("CSVE1C", "DAR")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 18000625 should resolve through the production registry"),
		assert_not_null(mimikyu, "Mimikyu should load"),
		assert_not_null(blaziken, "Blaziken ex should load"),
		assert_not_null(darkness, "Darkness Energy should load"),
		assert_not_null(fire, "Fire Energy should load"),
	]
	if strategy == null or mimikyu == null or blaziken == null \
			or darkness == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var stranded_mimikyu := _make_slot(mimikyu)
	var ready_blaziken := _make_slot(blaziken)
	ready_blaziken.attached_energy.append_array([
		CardInstance.create(fire, 0),
		CardInstance.create(darkness, 0),
	])
	var developing_blaziken := _make_slot(blaziken)
	developing_blaziken.attached_energy.append(CardInstance.create(fire, 0))
	player.active_pokemon = stranded_mimikyu
	player.bench = [ready_blaziken, developing_blaziken]
	var escape_score := _score(strategy, _attach(fire, stranded_mimikyu), state)
	var bench_score := _score(strategy, _attach(fire, developing_blaziken), state)

	ready_blaziken.attached_energy.clear()
	var no_handoff_score := _score(strategy, _attach(fire, stranded_mimikyu), state)
	checks.append_array([
		assert_true(escape_score >= 5500.0, "A one-Energy retreat must release Mimikyu when a ready Blaziken ex can take over (score=%f)" % escape_score),
		assert_true(escape_score >= bench_score + 800.0, "Escaping the active lock must beat adding redundant readiness to a bench attacker (escape=%f bench=%f)" % [escape_score, bench_score]),
		assert_true(no_handoff_score <= escape_score - 4000.0, "The manual escape override must retire without a ready bench handoff (inactive=%f live=%f)" % [no_handoff_score, escape_score]),
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
	state.turn_number = 9
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
