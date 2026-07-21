class_name TestV18Stage2CoreRound1
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_mamoswine_is_the_only_stage2_route_that_retires_opening_debt() -> String:
	var deck := _load_deck()
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	var strategy: RefCounted = registry.call("resolve_strategy_for_deck", deck) if deck != null else null
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	var pidgeot: CardData = CardDatabase.get_card("CSV4C", "101")
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks: Array[String] = [
		assert_not_null(deck, "Deck 800017047 should load"),
		assert_not_null(delegate, "Deck 800017047 should expose its Stage2Core delegate"),
		assert_not_null(pidgeot, "Pidgeot ex should load"),
		assert_not_null(swinub, "Swinub should load"),
		assert_not_null(mamoswine, "Mamoswine ex should load"),
		assert_not_null(fighting, "Fighting Energy should load"),
	]
	if delegate == null or pidgeot == null or swinub == null or mamoswine == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(pidgeot)
	player.bench = [_make_slot(swinub)]
	var setup_plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var setup_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, setup_plan)
	checks.append(assert_true(str(setup_plan.get("phase", "")) != "attack", "Pidgeot ex must not put the Mamoswine route into attack phase"))
	checks.append(assert_false(bool(setup_plan.get("flags", {}).get("stage2_online", false)), "Pidgeot ex must not mark the Mamoswine Stage 2 route online"))
	checks.append(assert_true(int(setup_plan.get("flags", {}).get("setup_debt", 0)) > 0, "Pidgeot ex must not retire the Mamoswine setup debt"))
	checks.append(assert_true(_continuity_debt(setup_continuity) > 0, "Pidgeot ex must leave the Mamoswine continuity debt live"))
	checks.append(assert_eq(_turn_owner(setup_plan), _primary_name(swinub), "The live Swinub chain should remain the route owner"))

	var mamoswine_slot := _make_slot(mamoswine)
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	player.active_pokemon = mamoswine_slot
	var attack_plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var attack_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, attack_plan)
	checks.append(assert_eq(str(attack_plan.get("phase", "")), "attack", "A Mamoswine ex with two Fighting Energy should enter attack phase"))
	checks.append(assert_true(bool(attack_plan.get("flags", {}).get("stage2_online", false)), "A funded Mamoswine ex should mark the Stage 2 route online"))
	checks.append(assert_eq(int(attack_plan.get("flags", {}).get("setup_debt", -1)), 0, "Mamoswine ex should retire its own setup debt"))
	checks.append(assert_eq(_continuity_debt(attack_continuity), 0, "Mamoswine ex should retire the Mamoswine continuity debt"))
	checks.append(assert_eq(_turn_owner(attack_plan), _primary_name(mamoswine), "Mamoswine ex should own the funded attack route"))
	return run_checks(checks)


func _load_deck() -> DeckData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


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


func _turn_owner(plan: Dictionary) -> String:
	return str(plan.get("owner", {}).get("turn_owner_name", ""))


func _continuity_debt(contract: Dictionary) -> int:
	var debt: Dictionary = contract.get("setup_debt", {})
	var delegate: Dictionary = debt.get("delegate", {})
	return int(delegate.get("missing_mamoswine_route", -1))


func _primary_name(card: CardData) -> String:
	return str(card.name_en) if not str(card.name_en).is_empty() else str(card.name)
