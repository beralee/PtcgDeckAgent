class_name TestDeckStrategyRegistryExpansion
extends TestBase


const STRATEGY_REGISTRY_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRegistry.gd"
const EXPANDED_STRATEGIES := {
	"charizard_ex": "res://scripts/ai/DeckStrategyCharizardEx.gd",
	"dragapult_dusknoir": "res://scripts/ai/DeckStrategyDragapultDusknoir.gd",
	"dragapult_banette": "res://scripts/ai/DeckStrategyDragapultBanette.gd",
	"dragapult_charizard": "res://scripts/ai/DeckStrategyDragapultCharizard.gd",
	"regidrago": "res://scripts/ai/DeckStrategyRegidrago.gd",
	"lugia_archeops": "res://scripts/ai/DeckStrategyLugiaArcheops.gd",
	"dialga_metang": "res://scripts/ai/DeckStrategyDialgaMetang.gd",
	"arceus_giratina": "res://scripts/ai/DeckStrategyArceusGiratina.gd",
	"palkia_gholdengo": "res://scripts/ai/DeckStrategyPalkiaGholdengo.gd",
	"palkia_dusknoir": "res://scripts/ai/DeckStrategyPalkiaDusknoir.gd",
	"lost_box": "res://scripts/ai/DeckStrategyLostBox.gd",
	"future_box": "res://scripts/ai/DeckStrategyFutureBox.gd",
	"iron_thorns": "res://scripts/ai/DeckStrategyIronThorns.gd",
	"raging_bolt_ogerpon": "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd",
	"blissey_tank": "res://scripts/ai/DeckStrategyBlisseyTank.gd",
	"gouging_fire_ancient": "res://scripts/ai/DeckStrategyGougingFireAncient.gd",
}

const V17_STRATEGIES := {
	"v17_archaludon_dialga": "res://scripts/ai/DeckStrategy17ArchaludonDialga.gd",
	"v17_water_turtle": "res://scripts/ai/DeckStrategy17WaterTurtle.gd",
	"v17_palkia_gholdengo": "res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd",
	"v17_bomb_charizard": "res://scripts/ai/DeckStrategy17BombCharizard.gd",
	"v17_miraidon": "res://scripts/ai/DeckStrategy17Miraidon.gd",
	"v17_dragapult_dusknoir": "res://scripts/ai/DeckStrategy17DragapultDusknoir.gd",
	"v17_regidrago": "res://scripts/ai/DeckStrategy17Regidrago.gd",
}

const V17_DECK_STRATEGIES := {
	1700002: "v17_archaludon_dialga",
	1700003: "v17_water_turtle",
	1700004: "v17_palkia_gholdengo",
	1700005: "v17_bomb_charizard",
	1700007: "v17_miraidon",
	1700008: "v17_dragapult_dusknoir",
	1700011: "v17_regidrago",
}


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _make_pokemon_cd(pname: String, energy_type: String = "C") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = 100
	return cd


func _make_player_with_hand(names: Array[String]) -> PlayerState:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.player_index = 0
	for name: String in names:
		player.hand.append(CardInstance.create(_make_pokemon_cd(name), 0))
	return player


func test_expanded_strategy_scripts_exist() -> String:
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGIES.keys():
		var script_path: String = str(EXPANDED_STRATEGIES[strategy_id])
		checks.append(assert_not_null(
			_load_script(script_path),
			"%s should load from %s" % [strategy_id, script_path]
		))
	return run_checks(checks)


func test_expanded_strategy_scripts_report_matching_strategy_ids() -> String:
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGIES.keys():
		var script_path: String = str(EXPANDED_STRATEGIES[strategy_id])
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s script should load" % strategy_id))
		if script == null:
			continue
		var strategy = script.new()
		checks.append(assert_eq(
			strategy.get_strategy_id(),
			strategy_id,
			"%s strategy should report its registry id" % strategy_id
		))
	return run_checks(checks)


func test_registry_detects_expanded_families_from_signature_cards() -> String:
	var registry_script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	if registry_script == null:
		return "DeckStrategyRegistry.gd should exist before expanded family detection can be tested"
	var registry = registry_script.new()
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGIES.keys():
		var script_path: String = str(EXPANDED_STRATEGIES[strategy_id])
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s script should load for registry detection" % strategy_id))
		if script == null:
			continue
		var strategy = script.new()
		var signature_names: Array[String] = strategy.get_signature_names()
		checks.append(assert_true(signature_names.size() > 0, "%s should expose at least one signature card" % strategy_id))
		if signature_names.is_empty():
			continue
		var player := _make_player_with_hand(signature_names)
		var detected_id: String = str(registry.detect_strategy_id_for_player(player))
		checks.append(assert_eq(
			detected_id,
			strategy_id,
			"Registry should detect %s from its signature cards" % strategy_id
		))
	return run_checks(checks)


func test_v17_strategy_scripts_report_matching_strategy_ids() -> String:
	var checks: Array[String] = []
	for strategy_id: String in V17_STRATEGIES.keys():
		var script_path: String = str(V17_STRATEGIES[strategy_id])
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s script should load" % strategy_id))
		if script == null:
			continue
		var strategy = script.new()
		checks.append(assert_eq(
			strategy.get_strategy_id(),
			strategy_id,
			"%s strategy should report its registry id" % strategy_id
		))
		checks.append(assert_true(
			strategy.get_signature_names().size() > 0,
			"%s should expose signatures for diagnostics" % strategy_id
		))
	return run_checks(checks)


func test_v17_targeted_strategies_use_mature_rule_configs() -> String:
	var expected_min_budget := {
		"v17_miraidon": 1000,
		"v17_dragapult_dusknoir": 1000,
		"v17_regidrago": 1000,
	}
	var checks: Array[String] = []
	for strategy_id: String in expected_min_budget.keys():
		var script := _load_script(str(V17_STRATEGIES[strategy_id]))
		checks.append(assert_not_null(script, "%s script should load for mature config check" % strategy_id))
		if script == null:
			continue
		var strategy = script.new()
		var config: Dictionary = strategy.call("get_mcts_config")
		checks.append(assert_true(
			int(config.get("time_budget_ms", 0)) >= int(expected_min_budget[strategy_id]),
			"%s should reuse its mature deck-local rules configuration instead of the thin v17 bootstrap config" % strategy_id
		))
	return run_checks(checks)


func test_registry_resolves_v17_bundled_deck_ids_to_initial_rule_strategies() -> String:
	var registry_script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	if registry_script == null:
		return "DeckStrategyRegistry.gd should load before v17 deck id resolution can be tested"
	var registry = registry_script.new()
	var checks: Array[String] = []
	for deck_id: int in V17_DECK_STRATEGIES.keys():
		var expected_strategy_id := str(V17_DECK_STRATEGIES[deck_id])
		var deck := DeckData.new()
		deck.id = deck_id
		deck.deck_name = "v17 test deck"
		deck.total_cards = 60
		var resolved_id := str(registry.call("resolve_strategy_id_for_deck", deck))
		var strategy = registry.call("resolve_strategy_for_deck", deck)
		checks.append(assert_eq(
			resolved_id,
			expected_strategy_id,
			"Deck %d should resolve by deck id before signature matching" % deck_id
		))
		checks.append(assert_not_null(strategy, "Deck %d should instantiate its v17 strategy" % deck_id))
		if strategy != null:
			checks.append(assert_eq(
				str(strategy.call("get_strategy_id")),
				expected_strategy_id,
				"Deck %d strategy instance should report the v17 strategy id" % deck_id
			))
	return run_checks(checks)


func test_registry_resolves_real_v17_ai_decks_from_card_database() -> String:
	var registry_script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	if registry_script == null:
		return "DeckStrategyRegistry.gd should load before real v17 AI deck resolution can be tested"
	var registry = registry_script.new()
	var checks: Array[String] = []
	for deck_id: int in V17_DECK_STRATEGIES.keys():
		var expected_strategy_id := str(V17_DECK_STRATEGIES[deck_id])
		var deck: DeckData = CardDatabase.get_ai_deck(deck_id)
		checks.append(assert_not_null(deck, "Bundled AI deck %d should load through CardDatabase" % deck_id))
		if deck == null:
			continue
		var strategy = registry.call("resolve_strategy_for_deck", deck)
		checks.append(assert_not_null(strategy, "Bundled AI deck %d should resolve to an initial rules strategy" % deck_id))
		if strategy != null:
			checks.append(assert_eq(
				str(strategy.call("get_strategy_id")),
				expected_strategy_id,
				"Bundled AI deck %d should use %s" % [deck_id, expected_strategy_id]
			))
	return run_checks(checks)


func test_v17_ai_decks_can_start_a_game_with_initial_rule_strategies() -> String:
	var registry_script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	if registry_script == null:
		return "DeckStrategyRegistry.gd should load before v17 start-game smoke can be tested"
	var registry = registry_script.new()
	var anchor_deck: DeckData = CardDatabase.get_ai_deck(575720)
	if anchor_deck == null:
		return "Miraidon anchor AI deck should load for v17 start-game smoke"
	var checks: Array[String] = []
	for deck_id: int in V17_DECK_STRATEGIES.keys():
		var deck: DeckData = CardDatabase.get_ai_deck(deck_id)
		checks.append(assert_not_null(deck, "Bundled AI deck %d should load for start-game smoke" % deck_id))
		if deck == null:
			continue
		var strategy = registry.call("resolve_strategy_for_deck", deck)
		checks.append(assert_not_null(strategy, "Bundled AI deck %d should resolve strategy before start-game smoke" % deck_id))
		var gsm := GameStateMachine.new()
		gsm.start_game(deck, anchor_deck, 0)
		checks.append(assert_not_null(gsm.game_state, "Deck %d should create a game state" % deck_id))
		if gsm.game_state == null:
			continue
		checks.append(assert_eq(gsm.game_state.players.size(), 2, "Deck %d should start with two players" % deck_id))
		checks.append(assert_eq(gsm.game_state.players[0].deck.size() + gsm.game_state.players[0].hand.size(), 60, "Deck %d should materialize 60 player cards before setup" % deck_id))
	return run_checks(checks)
