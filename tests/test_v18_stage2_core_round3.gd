class_name TestV18Stage2CoreRound3
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_live_blaziken_route_searches_fighting_then_fire() -> String:
	var strategy := _load_strategy()
	var torchic: CardData = CardDatabase.get_card("CSV7C", "036")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks := _load_checks(strategy, torchic, fighting, fire)
	if strategy == null or torchic == null or fighting == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(torchic)
	var picked := _pick_energy(strategy, state, fighting, fire)
	checks.append(assert_eq(_energy_types(picked), ["F", "R"], "A live Blaziken route should secure Fighting first and the singleton Fire second"))
	return run_checks(checks)


func test_swinub_only_search_preserves_two_fighting_order() -> String:
	var strategy := _load_strategy()
	var swinub: CardData = CardDatabase.get_card("CSV10C", "102")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks := _load_checks(strategy, swinub, fighting, fire)
	if strategy == null or swinub == null or fighting == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(swinub)
	var picked := _pick_energy(strategy, state, fighting, fire)
	checks.append(assert_eq(_energy_types(picked), ["F", "F"], "A Swinub-only board should preserve the existing Earthen Vessel order"))
	return run_checks(checks)


func test_secured_fire_preserves_two_fighting_order() -> String:
	var strategy := _load_strategy()
	var torchic: CardData = CardDatabase.get_card("CSV7C", "036")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks := _load_checks(strategy, torchic, fighting, fire)
	if strategy == null or torchic == null or fighting == null or fire == null:
		return run_checks(checks)

	var hand_state := _make_state()
	hand_state.players[0].active_pokemon = _make_slot(torchic)
	hand_state.players[0].hand.append(CardInstance.create(fire, 0))
	var hand_picked := _pick_energy(strategy, hand_state, fighting, fire)
	checks.append(assert_eq(_energy_types(hand_picked), ["F", "F"], "Fire already secured in hand should preserve the existing Earthen Vessel order"))

	var attached_state := _make_state()
	var torchic_slot := _make_slot(torchic)
	torchic_slot.attached_energy.append(CardInstance.create(fire, 0))
	attached_state.players[0].active_pokemon = torchic_slot
	var attached_picked := _pick_energy(strategy, attached_state, fighting, fire)
	checks.append(assert_eq(_energy_types(attached_picked), ["F", "F"], "Fire already attached should preserve the existing Earthen Vessel order"))
	return run_checks(checks)


func test_production_registry_resolves_mamoswine_blaziken_stage2_core() -> String:
	var strategy := _load_strategy()
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return run_checks([
		assert_not_null(strategy, "Deck 800017047 should resolve through the production registry"),
		assert_not_null(delegate, "Deck 800017047 should expose its Stage2Core delegate"),
		assert_eq(str(delegate.call("get_strategy_id")) if delegate != null else "", "v18_stage2_core_800017047", "The production registry should retain the deck-scoped Stage2Core delegate"),
	])


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck) if deck != null else null


func _load_checks(strategy: RefCounted, route_card: CardData, fighting: CardData, fire: CardData) -> Array[String]:
	return [
		assert_not_null(strategy, "Deck 800017047 should resolve its production strategy"),
		assert_not_null(route_card, "The route Pokemon should load"),
		assert_not_null(fighting, "Fighting Energy should load"),
		assert_not_null(fire, "Fire Energy should load"),
	]


func _pick_energy(strategy: RefCounted, state: GameState, fighting: CardData, fire: CardData) -> Array:
	return strategy.call(
		"pick_interaction_items",
		[
			CardInstance.create(fighting, 0),
			CardInstance.create(fighting, 0),
			CardInstance.create(fire, 0),
		],
		{"id": "search_energy", "max_select": 2},
		{"game_state": state, "player_index": 0}
	)


func _energy_types(cards: Array) -> Array[String]:
	var types: Array[String] = []
	for item: Variant in cards:
		if item is CardInstance and (item as CardInstance).card_data != null:
			types.append(str((item as CardInstance).card_data.energy_provides))
	return types


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
