class_name TestV18Stage2FightingRouteAttachmentRound8
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15301_fighting_attachment_prefers_swinub_over_combusken() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var combusken: CardData = CardDatabase.get_card("CSV7C", "037")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, swinub, combusken, fighting)
	if strategy == null or swinub == null or combusken == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var swinub_slot := _make_slot(swinub)
	swinub_slot.attached_energy.append(CardInstance.create(fighting, 0))
	var combusken_slot := _make_slot(combusken)
	combusken_slot.attached_energy.append(CardInstance.create(fighting, 0))
	state.players[0].active_pokemon = swinub_slot
	state.players[0].bench = [combusken_slot]
	var swinub_score := _score(strategy, _attach_action(swinub_slot, fighting), state)
	var combusken_score := _score(strategy, _attach_action(combusken_slot, fighting), state)
	checks.append_array([
		assert_true(swinub_score >= 4000.0, "The second Fighting Energy should advance the active Mamoswine route (score=%f)" % swinub_score),
		assert_true(swinub_score > combusken_score, "Fighting must not receive generic Stage-1 value on Combusken while Mamoswine setup debt remains (Swinub=%f Combusken=%f)" % [swinub_score, combusken_score]),
	])
	return run_checks(checks)


func test_fire_attachment_still_prefers_combusken_route() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var combusken: CardData = CardDatabase.get_card("CSV7C", "037")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks := _load_checks(strategy, swinub, combusken, fighting)
	checks.append(assert_not_null(fire, "Fire Energy should load"))
	if strategy == null or swinub == null or combusken == null or fighting == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	var swinub_slot := _make_slot(swinub)
	var combusken_slot := _make_slot(combusken)
	state.players[0].active_pokemon = swinub_slot
	state.players[0].bench = [combusken_slot]
	var swinub_score := _score(strategy, _attach_action(swinub_slot, fire), state)
	var combusken_score := _score(strategy, _attach_action(combusken_slot, fire), state)
	checks.append(assert_true(combusken_score > swinub_score, "The Fighting-only route guard must preserve Fire attachment to Combusken"))
	return run_checks(checks)


func test_fighting_guard_releases_after_mamoswine_route_is_online() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var combusken: CardData = CardDatabase.get_card("CSV7C", "037")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, combusken, fighting)
	if strategy == null or mamoswine == null or combusken == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var mamoswine_slot := _make_slot(mamoswine)
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	var combusken_slot := _make_slot(combusken)
	state.players[0].active_pokemon = mamoswine_slot
	state.players[0].bench = [combusken_slot]
	var combusken_score := _score(strategy, _attach_action(combusken_slot, fighting), state)
	checks.append(assert_true(combusken_score > -1200.0, "Once Mamoswine is online, generic secondary-route attachments should no longer be hard-suppressed"))
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _load_checks(strategy: RefCounted, first: CardData, second: CardData, energy: CardData) -> Array[String]:
	return [
		assert_not_null(strategy, "Deck 800017047 should resolve through the production registry"),
		assert_not_null(first, "The first fixture Pokemon should load"),
		assert_not_null(second, "The second fixture Pokemon should load"),
		assert_not_null(energy, "Fighting Energy should load"),
	]


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _attach_action(target: PokemonSlot, energy: CardData) -> Dictionary:
	return {"kind": "attach_energy", "target_slot": target, "card": CardInstance.create(energy, 0)}


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
