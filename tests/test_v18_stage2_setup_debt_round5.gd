class_name TestV18Stage2SetupDebtRound5
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_bare_mamoswine_keeps_one_setup_debt_and_safe_setup_window() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, fighting)
	if strategy == null or mamoswine == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(mamoswine)
	state.players[0].bench.append(_make_ready_backup(fighting))
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	checks.append_array([
		assert_eq(str(plan.get("phase", "")), "evolve", "Bare Mamoswine ex should remain in setup phase"),
		assert_false(bool(plan.get("flags", {}).get("stage2_online", true)), "Bare Mamoswine ex must not mark the route online"),
		assert_eq(_plan_debt(plan), 1, "Bare Mamoswine ex should keep exactly one setup debt"),
		assert_eq(_continuity_debt(continuity), 1, "Bare Mamoswine ex should keep continuity debt live"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "A ready backup should preserve safe setup before attacking while bare Mamoswine debt remains"),
	])
	return run_checks(checks)


func test_one_fighting_mamoswine_keeps_one_setup_debt_and_safe_setup_window() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, fighting)
	if strategy == null or mamoswine == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var mamoswine_slot := _make_slot(mamoswine)
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	state.players[0].active_pokemon = mamoswine_slot
	state.players[0].bench.append(_make_ready_backup(fighting))
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	checks.append_array([
		assert_eq(str(plan.get("phase", "")), "evolve", "One-Fighting Mamoswine ex should remain in setup phase"),
		assert_false(bool(plan.get("flags", {}).get("stage2_online", true)), "One-Fighting Mamoswine ex must not mark the route online"),
		assert_eq(_plan_debt(plan), 1, "One-Fighting Mamoswine ex should keep exactly one setup debt"),
		assert_eq(_continuity_debt(continuity), 1, "One-Fighting Mamoswine ex should keep continuity debt live"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "A ready backup should preserve safe setup before attacking while one-Fighting Mamoswine debt remains"),
	])
	return run_checks(checks)


func test_two_fighting_mamoswine_is_the_only_stage2_state_that_clears_debt() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, fighting)
	if strategy == null or mamoswine == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var mamoswine_slot := _make_slot(mamoswine)
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	state.players[0].active_pokemon = mamoswine_slot
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	checks.append_array([
		assert_eq(str(plan.get("phase", "")), "attack", "Two-Fighting Mamoswine ex should enter attack phase"),
		assert_true(bool(plan.get("flags", {}).get("stage2_online", false)), "Two-Fighting Mamoswine ex should mark the route online"),
		assert_eq(_plan_debt(plan), 0, "Two-Fighting Mamoswine ex should clear setup debt"),
		assert_eq(_continuity_debt(continuity), 0, "Two-Fighting Mamoswine ex should clear continuity debt"),
		assert_false(bool(continuity.get("safe_setup_before_attack", true)), "An online Mamoswine route should not retain safe setup debt"),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck) if deck != null else null


func _load_checks(strategy: RefCounted, mamoswine: CardData, fighting: CardData) -> Array[String]:
	return [
		assert_not_null(strategy, "Deck 800017047 should resolve through the production V18 registry"),
		assert_not_null(mamoswine, "Mamoswine ex should load"),
		assert_not_null(fighting, "Fighting Energy should load"),
	]


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


func _make_ready_backup(fighting: CardData) -> PokemonSlot:
	var card := CardData.new()
	card.name = "Ready Backup"
	card.name_en = "Ready Backup"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.attacks = [{"name": "Backup Attack", "cost": "C", "damage": "30"}]
	var slot := _make_slot(card)
	slot.attached_energy.append(CardInstance.create(fighting, 0))
	return slot


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot


func _plan_debt(plan: Dictionary) -> int:
	return int(plan.get("flags", {}).get("setup_debt", -1))


func _continuity_debt(contract: Dictionary) -> int:
	var merged: Dictionary = contract.get("setup_debt", {}) if contract.get("setup_debt", {}) is Dictionary else {}
	var delegate: Dictionary = merged.get("delegate", merged) if merged.get("delegate", merged) is Dictionary else {}
	return int(delegate.get("missing_mamoswine_route", -1))
