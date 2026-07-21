class_name TestV18RabscaBenchPressureSemanticsRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018105.json"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd"


func test_real_raikou_registry_card_creates_no_rabsca_pressure_debt_or_forcing() -> String:
	var strategy := _registry_strategy()
	var raikou := _real_card_data("CS4DaC_137")
	var rellor := _real_card_data("CSV7C_030")
	var rabsca := _real_card_data("CSV7C_031")
	var checks: Array[String] = [
		assert_not_null(strategy, "Rabsca Gardevoir should resolve through DeckStrategyRegistry"),
		assert_not_null(raikou, "The real CS4DaC_137 Raikou V registry card should load"),
		assert_not_null(rellor, "The real Rellor registry card should load"),
		assert_not_null(rabsca, "The real Rabsca registry card should load"),
	]
	if strategy == null or raikou == null or rellor == null or rabsca == null:
		return run_checks(checks)

	var delegate: Variant = strategy.get("_delegate")
	checks.append(assert_not_null(delegate, "Registry strategy should instantiate the Gardevoir variant delegate"))
	if delegate == null:
		return run_checks(checks)

	var state := _state_with_opponent(raikou)
	var rellor_slot := _slot(rellor, 0)
	state.players[0].bench.append(rellor_slot)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	var guard_score: float = delegate.call("score_action_absolute", {
		"kind": "evolve",
		"card": CardInstance.create(rabsca, 0),
		"target_slot": rellor_slot,
	}, state, 0)

	checks.append(assert_eq(str(delegate.get_script().resource_path), DELEGATE_PATH, "Registry should use the deck-owned Gardevoir variants delegate"))
	checks.append(assert_false(bool(delegate.call("_opponent_has_bench_attack_pressure", state, 0)), "Raikou's active damage scaling by Bench count is not Bench-targeting pressure"))
	checks.append(assert_false(bool(plan.get("flags", {}).get("opponent_bench_attack_pressure", false)), "Raikou should not set the turn-plan pressure flag"))
	checks.append(assert_false(bool(plan.get("flags", {}).get("rabsca_guard_debt", false)), "Raikou should not create Rabsca guard debt"))
	checks.append(assert_false(bool(continuity.get("setup_debt", {}).get("need_rabsca_guard", false)), "Raikou should not add Rabsca continuity debt"))
	checks.append(assert_true(guard_score < 3000.0, "Raikou should not force the Rabsca evolution score"))
	return run_checks(checks)


func test_english_bench_count_scaling_words_do_not_create_pressure() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Rabsca Gardevoir should resolve through DeckStrategyRegistry")
	var delegate: Variant = strategy.get("_delegate")
	if delegate == null:
		return assert_true(false, "Registry strategy should instantiate the Gardevoir variant delegate")

	var for_each_state := _state_with_opponent(_pokemon("For Each Scaler", [{
		"name": "Bench Rondo",
		"cost": "LC",
		"damage": "20+",
		"text": "This attack does 20 more damage for each Benched Pokemon in play.",
	}]))
	var number_state := _state_with_opponent(_pokemon("Number Scaler", [{
		"name": "Bench Count",
		"cost": "CC",
		"damage": "10+",
		"text": "This attack does 10 more damage for the number of Benched Pokemon.",
	}]))
	return run_checks([
		assert_false(bool(delegate.call("_opponent_has_bench_attack_pressure", for_each_state, 0)), "For-each Bench scaling should not count as Bench-targeting pressure"),
		assert_false(bool(delegate.call("_opponent_has_bench_attack_pressure", number_state, 0)), "Number-of-Bench scaling should not count as Bench-targeting pressure"),
	])


func test_targeted_bench_damage_and_structured_targets_still_create_pressure() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Rabsca Gardevoir should resolve through DeckStrategyRegistry")
	var delegate: Variant = strategy.get("_delegate")
	if delegate == null:
		return assert_true(false, "Registry strategy should instantiate the Gardevoir variant delegate")

	var targeted_attacker := _pokemon("Bench Sniper", [{
		"name": "Bench Shot",
		"cost": "L",
		"damage": "",
		"text": "This attack does 60 damage to 2 of your opponent's Benched Pokemon.",
	}])
	var targeted_state := _state_with_opponent(targeted_attacker)
	var targeted_plan: Dictionary = strategy.call("build_turn_plan", targeted_state, 0)

	var structured_attacker := _pokemon("Structured Bench Sniper", [{
		"name": "Structured Bench Shot",
		"cost": "L",
		"damage": "30",
		"damage_target": {"side": "opponent", "zone": "bench"},
	}])
	var structured_state := _state_with_opponent(structured_attacker)
	return run_checks([
		assert_true(bool(delegate.call("_opponent_has_bench_attack_pressure", targeted_state, 0)), "Explicit damage to opposing Benched Pokemon should remain pressure"),
		assert_true(bool(targeted_plan.get("flags", {}).get("rabsca_guard_debt", false)), "Targeted Bench damage should create Rabsca guard debt"),
		assert_true(bool(delegate.call("_opponent_has_bench_attack_pressure", structured_state, 0)), "Structured opponent-Bench damage targeting should take precedence over missing text"),
	])


func test_artazon_still_orders_rellor_first_under_targeted_bench_pressure() -> String:
	var strategy := _registry_strategy()
	var ralts := _real_card_data("CSV2C_053")
	var rellor := _real_card_data("CSV7C_030")
	var checks: Array[String] = [
		assert_not_null(strategy, "Rabsca Gardevoir should resolve through DeckStrategyRegistry"),
		assert_not_null(ralts, "The real Ralts registry card should load"),
		assert_not_null(rellor, "The real Rellor registry card should load"),
	]
	if strategy == null or ralts == null or rellor == null:
		return run_checks(checks)

	var attacker := _pokemon("Bench Sniper", [{
		"name": "Counter Drop",
		"cost": "P",
		"damage": "",
		"text": "Put 3 damage counters on 1 of your opponent's Benched Pokemon.",
	}])
	var state := _state_with_opponent(attacker)
	var ralts_instance := CardInstance.create(ralts, 0)
	var rellor_instance := CardInstance.create(rellor, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var picked: Array = strategy.call("pick_interaction_items", [ralts_instance, rellor_instance], {
		"id": "artazon_pokemon", "min_select": 1, "max_select": 1,
	}, {"game_state": state, "player_index": 0})
	checks.append(assert_true(bool(plan.get("flags", {}).get("opponent_bench_attack_pressure", false)), "Damage counters placed on opposing Benched Pokemon should remain pressure"))
	checks.append(assert_eq(picked, [rellor_instance], "Artazon should still establish Rellor before another Ralts under real Bench-targeting pressure"))
	return run_checks(checks)


func _registry_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _state_with_opponent(opponent_card: CardData) -> GameState:
	var state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	state.players[0].active_pokemon = _slot(_pokemon("Pivot", []), 0)
	state.players[1].active_pokemon = _slot(opponent_card, 1)
	return state


func _real_card_data(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
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
	card.hp = 120
	var typed_attacks: Array[Dictionary] = []
	for attack: Variant in attacks:
		if attack is Dictionary:
			typed_attacks.append((attack as Dictionary).duplicate(true))
	card.attacks = typed_attacks
	return card
