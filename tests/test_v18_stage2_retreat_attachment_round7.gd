class_name TestV18Stage2RetreatAttachmentRound7
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_ready_mamoswine_retreat_bridge_outranks_off_route_pidgeot_attachment() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var pidgeot: CardData = CardDatabase.get_card("CSV4C", "101")
	var checks := _load_checks(strategy, mamoswine, fighting, pidgeot)
	if strategy == null or mamoswine == null or fighting == null or pidgeot == null:
		return run_checks(checks)

	var state := _make_state()
	var active := _make_active("Active Pivot", 2)
	active.attached_energy.append(CardInstance.create(fighting, 0))
	var ready_mamoswine := _make_slot(mamoswine)
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	var off_route_pidgeot := _make_slot(pidgeot)
	state.players[0].active_pokemon = active
	state.players[0].bench = [ready_mamoswine, off_route_pidgeot]

	var bridge_score := _score(strategy, _attach_action(active, fighting), state)
	var pidgeot_score := _score(strategy, _attach_action(off_route_pidgeot, fighting), state)
	checks.append_array([
		assert_true(bridge_score >= 5200.0, "A live retreat bridge should receive the dedicated state-scoped score"),
		assert_true(bridge_score > pidgeot_score, "The retreat bridge must outrank an off-route Pidgeot attachment"),
	])
	return run_checks(checks)


func test_mamoswine_retreat_bridge_has_no_boost_without_a_complete_live_state() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, fighting, CardDatabase.get_card("CSV4C", "101"))
	if strategy == null or mamoswine == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var active := _make_active("Active Pivot", 2)
	active.attached_energy.append(CardInstance.create(fighting, 0))
	var ready_mamoswine := _make_slot(mamoswine)
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	state.players[0].active_pokemon = active
	state.players[0].bench = [ready_mamoswine]
	var live_score := _score(strategy, _attach_action(active, fighting), state)

	active.attached_energy.clear()
	var insufficient_score := _score(strategy, _attach_action(active, fighting), state)
	active.attached_energy.append(CardInstance.create(fighting, 0))
	ready_mamoswine.attached_energy.pop_back()
	var not_ready_score := _score(strategy, _attach_action(active, fighting), state)
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	active.attached_energy.append(CardInstance.create(fighting, 0))
	var already_retreatable_score := _score(strategy, _attach_action(active, fighting), state)
	checks.append_array([
		assert_true(live_score >= 5200.0, "The complete state should activate the retreat bridge"),
		assert_true(insufficient_score < 5200.0, "An attachment that still leaves retreat cost unpaid must not boost"),
		assert_true(not_ready_score < 5200.0, "A Mamoswine without two Fighting Energy must not activate the bridge"),
		assert_true(already_retreatable_score < 5200.0, "An already-retreatable active must not activate the bridge"),
	])
	return run_checks(checks)


func test_mamoswine_retreat_bridge_rejects_active_mamoswine_and_non_energy_cards() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, fighting, CardDatabase.get_card("CSV4C", "101"))
	if strategy == null or mamoswine == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var active_mamoswine := _make_slot(mamoswine)
	active_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	state.players[0].active_pokemon = active_mamoswine
	var ready_mamoswine := _make_slot(mamoswine)
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	state.players[0].bench = [ready_mamoswine]
	var active_mamoswine_score := _score(strategy, _attach_action(active_mamoswine, fighting), state)

	var non_energy := CardData.new()
	non_energy.name = "Not Energy"
	non_energy.card_type = "Trainer"
	var non_energy_score := _score(strategy, _attach_action(active_mamoswine, non_energy), state)
	checks.append_array([
		assert_true(active_mamoswine_score < 5200.0, "An active Mamoswine must not trigger the support retreat bridge"),
		assert_true(non_energy_score < 5200.0, "A non-Energy card must not trigger the retreat bridge"),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck) if deck != null else null


func _load_checks(strategy: RefCounted, mamoswine: CardData, fighting: CardData, pidgeot: CardData) -> Array[String]:
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return [
		assert_not_null(strategy, "Deck 800017047 should resolve through the production V18 registry"),
		assert_not_null(delegate, "Deck 800017047 should retain a Stage2Core delegate"),
		assert_not_null(mamoswine, "Mamoswine ex should load"),
		assert_not_null(fighting, "Fighting Energy should load"),
		assert_not_null(pidgeot, "Pidgeot ex should load"),
	]


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var delegate: RefCounted = strategy.get("_delegate")
	return float(delegate.call("score_action_absolute", action, state, 0))


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
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_active(name: String, retreat_cost: int) -> PokemonSlot:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.retreat_cost = retreat_cost
	card.attacks = [{"name": "Attack", "cost": "C", "damage": "30"}]
	return _make_slot(card)


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
