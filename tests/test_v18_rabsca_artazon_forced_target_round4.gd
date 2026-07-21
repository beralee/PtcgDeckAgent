class_name TestV18RabscaArtazonForcedTargetRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018105.json"


func test_registry_forces_rellor_over_all_basic_artazon_targets_and_direct_bench_plays() -> String:
	var strategy := _registry_strategy()
	var state := _state_with_pressure()
	var rellor := _real_card("CSV7C_030")
	var ralts := _real_card("CSV2C_053")
	var munkidori := _real_card("CSV8C_094")
	var raikou := _real_card("CS4DaC_137")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800018105 should resolve through DeckStrategyRegistry"),
		assert_not_null(rellor, "Rellor should load"),
		assert_not_null(ralts, "Ralts should load"),
		assert_not_null(munkidori, "Munkidori should load"),
		assert_not_null(raikou, "Raikou should load"),
	]
	if strategy == null or rellor == null or ralts == null or munkidori == null or raikou == null:
		return run_checks(checks)
	var rellor_instance := CardInstance.create(rellor, 0)
	var artazon_items := [
		CardInstance.create(ralts, 0),
		rellor_instance,
		CardInstance.create(munkidori, 0),
		CardInstance.create(raikou, 0),
	]
	var picked: Array = strategy.call("pick_interaction_items", artazon_items, {
		"id": "artazon_pokemon", "min_select": 1, "max_select": 1,
	}, {"game_state": state, "player_index": 0})
	var delegate: RefCounted = strategy.get("_delegate")
	var non_rellor_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(ralts, 0)}
	var rellor_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(rellor, 0)}
	checks.append(assert_eq(picked, [rellor_instance], "Artazon should select Rellor over every other Basic"))
	checks.append(assert_true(float(delegate.call("score_action_absolute", non_rellor_action, state, 0)) < -90000.0, "Direct non-Rellor bench play should be suppressed while Rellor setup is available"))
	checks.append(assert_true(float(delegate.call("score_action_absolute", rellor_action, state, 0)) > 2000.0, "Direct Rellor bench play should remain preferred"))
	return run_checks(checks)


func test_registry_releases_force_when_guard_online_pressure_absent_or_rellor_unavailable() -> String:
	var strategy := _registry_strategy()
	var checks: Array[String] = [assert_not_null(strategy, "Deck 800018105 should resolve through DeckStrategyRegistry")]
	if strategy == null:
		return run_checks(checks)
	var delegate: RefCounted = strategy.get("_delegate")
	var ralts := _real_card("CSV2C_053")
	var rellor := _real_card("CSV7C_030")
	if delegate == null or ralts == null or rellor == null:
		return run_checks([assert_not_null(delegate, "Registry should expose the production delegate"), assert_not_null(ralts, "Ralts should load"), assert_not_null(rellor, "Rellor should load")])
	var released_no_target := _state_with_pressure()
	released_no_target.players[0].hand.clear()
	var released_no_pressure := _state_with_pressure(false)
	var released_online := _state_with_pressure()
	released_online.players[0].bench.append(_slot(rellor, 0))
	released_online.players[0].bench.append(_slot(_real_card("CSV7C_031"), 0))
	var action := {"kind": "play_basic_to_bench", "card": CardInstance.create(ralts, 0)}
	checks.append(assert_true(float(delegate.call("score_action_absolute", action, released_no_target, 0)) > -90000.0, "No Rellor target should release direct bench plays"))
	checks.append(assert_true(float(delegate.call("score_action_absolute", action, released_no_pressure, 0)) > -90000.0, "No genuine Bench pressure should release direct bench plays"))
	checks.append(assert_true(float(delegate.call("score_action_absolute", action, released_online, 0)) > -90000.0, "Online Rabsca should release direct bench plays"))
	return run_checks(checks)


func _registry_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(parsed)) if parsed is Dictionary else null


func _state_with_pressure(with_pressure: bool = true) -> GameState:
	var state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	state.players[0].active_pokemon = _slot(_pokemon("Pivot", []), 0)
	state.players[0].hand.append(CardInstance.create(_real_card("CSV7C_030"), 0))
	state.players[0].hand.append(CardInstance.create(_real_card("CSV2C_053"), 0))
	state.players[1].active_pokemon = _slot(_pokemon("Bench Sniper", [{
		"name": "Bench Shot", "cost": "L", "damage": "30",
		"text": "Do 30 damage to 1 of your opponent's Benched Pokemon.",
	}]) if with_pressure else _pokemon("Raikou", [{
		"name": "Dynamic Spark", "cost": "L", "damage": "30+",
		"text": "This attack does 30 more damage for each Benched Pokemon in play.",
	}]), 1)
	return state


func _real_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon(card_name: String, attacks: Array) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	var typed_attacks: Array[Dictionary] = []
	for attack: Variant in attacks:
		if attack is Dictionary:
			typed_attacks.append(attack)
	card.attacks = typed_attacks
	return card
