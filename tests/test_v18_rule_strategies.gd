class_name TestV18RuleStrategies
extends TestBase

const PROFILE_CATALOG_PATH := "res://scripts/ai/DeckStrategyV18ProfileCatalog.gd"
const STRATEGY_REGISTRY_PATH := "res://scripts/ai/DeckStrategyRegistry.gd"
const FIXED_ORDER_REGISTRY_PATH := "res://scripts/ai/AIFixedDeckOrderRegistry.gd"
const BATTLE_SETUP_PATH := "res://scenes/battle_setup/BattleSetup.gd"
const AI_TRAINING_RUNNER_PATH := "res://tests/AITrainingTestRunner.gd"
const DECK_DIR := "res://data/bundled_user/decks"
const HEADLESS_MATCH_BRIDGE_SCRIPT = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AI_STEP_RESOLVER_SCRIPT = preload("res://scripts/ai/AIStepResolver.gd")

const V18_DECK_IDS: Array[int] = [
	18000230,
	18000625,
	800015734,
	800015934,
	800016834,
	800017047,
	800017097,
	800017407,
	800017631,
	800017643,
	800018105,
	800018359,
	800018497,
	800018498,
	800018499,
	800018500,
	800018501,
	800018502,
	800018509,
	800018539,
	800018543,
	800018880,
	800019125,
	800033475,
]


func test_v18_profile_catalog_covers_every_deck_with_unique_complete_profiles() -> String:
	var catalog_script: Variant = load(PROFILE_CATALOG_PATH)
	var checks: Array[String] = [
		assert_true(catalog_script is GDScript, "The V18 rule profile catalog should exist and compile"),
	]
	if not catalog_script is GDScript:
		return run_checks(checks)
	var catalog: RefCounted = (catalog_script as GDScript).new()
	var profiles: Array[Dictionary] = catalog.call("all_profiles")
	checks.append(assert_eq(profiles.size(), V18_DECK_IDS.size(), "The catalog should contain exactly one profile for every V18 deck"))
	var seen_deck_ids: Dictionary = {}
	var seen_strategy_ids: Dictionary = {}
	for profile: Dictionary in profiles:
		var deck_id := int(profile.get("deck_id", 0))
		var strategy_id := str(profile.get("strategy_id", ""))
		seen_deck_ids[deck_id] = true
		seen_strategy_ids[strategy_id] = int(seen_strategy_ids.get(strategy_id, 0)) + 1
		checks.append(assert_true(deck_id in V18_DECK_IDS, "Profile deck id %d should be a known V18 deck" % deck_id))
		checks.append(assert_true(strategy_id.begins_with("v18_"), "Deck %d should have a stable V18 strategy id" % deck_id))
		checks.append(assert_false(str(profile.get("deck_name", "")).is_empty(), "Deck %d should have a profile name" % deck_id))
		checks.append(assert_false((profile.get("signatures", []) as Array).is_empty(), "Deck %d should declare signatures" % deck_id))
		checks.append(assert_false((profile.get("opening_active", []) as Array).is_empty(), "Deck %d should declare opening Active priorities" % deck_id))
		checks.append(assert_false((profile.get("bench_priority", []) as Array).is_empty(), "Deck %d should declare Bench priorities" % deck_id))
		checks.append(assert_false((profile.get("energy_priority", []) as Array).is_empty(), "Deck %d should declare attacker or Energy priorities" % deck_id))
		checks.append(assert_false((profile.get("evolution_priority", []) as Array).is_empty(), "Deck %d should declare evolution priorities" % deck_id))
		checks.append(assert_false((profile.get("search_priority", []) as Array).is_empty(), "Deck %d should declare search priorities" % deck_id))
	for deck_id: int in V18_DECK_IDS:
		checks.append(assert_true(seen_deck_ids.has(deck_id), "V18 deck %d should have a profile" % deck_id))
	for strategy_id: String in seen_strategy_ids:
		checks.append(assert_eq(int(seen_strategy_ids[strategy_id]), 1, "Strategy id %s should belong to exactly one deck" % strategy_id))
	return run_checks(checks)


func test_registry_resolves_every_v18_deck_exactly_and_instantiates_its_profile() -> String:
	var registry_script: Variant = load(STRATEGY_REGISTRY_PATH)
	if not registry_script is GDScript:
		return assert_true(false, "DeckStrategyRegistry should compile")
	var registry: RefCounted = (registry_script as GDScript).new()
	var checks: Array[String] = []
	var resolved_ids: Dictionary = {}
	for deck_id: int in V18_DECK_IDS:
		var deck := _load_deck(deck_id)
		checks.append(assert_not_null(deck, "V18 deck %d should load" % deck_id))
		if deck == null:
			continue
		var strategy_id := str(registry.call("resolve_strategy_id_for_deck", deck))
		var strategy: RefCounted = registry.call("resolve_strategy_for_deck", deck)
		resolved_ids[strategy_id] = int(resolved_ids.get(strategy_id, 0)) + 1
		checks.append(assert_true(strategy_id.begins_with("v18_"), "Deck %d should resolve by exact V18 id instead of signature guessing" % deck_id))
		checks.append(assert_not_null(strategy, "Deck %d should instantiate its rule strategy" % deck_id))
		if strategy != null:
			checks.append(assert_eq(str(strategy.call("get_strategy_id")), strategy_id, "Deck %d strategy instance should preserve the resolved id" % deck_id))
			checks.append(assert_true(strategy.has_method("build_turn_contract"), "Deck %d strategy should expose turn contracts" % deck_id))
			checks.append(assert_true(strategy.has_method("score_action_absolute_with_plan"), "Deck %d strategy should use the shared plan-aware scoring contract" % deck_id))
	checks.append(assert_eq(resolved_ids.size(), V18_DECK_IDS.size(), "Every V18 deck should resolve to a unique strategy id"))
	return run_checks(checks)


func test_every_v18_deck_has_a_legal_strong_mode_fixed_order() -> String:
	var registry_script: Variant = load(FIXED_ORDER_REGISTRY_PATH)
	if not registry_script is GDScript:
		return assert_true(false, "AIFixedDeckOrderRegistry should compile")
	var registry: RefCounted = (registry_script as GDScript).new()
	var checks: Array[String] = []
	for deck_id: int in V18_DECK_IDS:
		var deck := _load_deck(deck_id)
		var path := str(registry.call("get_fixed_order_path", deck_id))
		var order: Array[Dictionary] = registry.call("load_fixed_order", deck_id)
		checks.append(assert_false(path.is_empty(), "V18 deck %d should have a fixed order for strong mode" % deck_id))
		checks.append(assert_true(order.size() >= 19, "V18 deck %d fixed order should cover opening hand, prizes, and bridge draws" % deck_id))
		if deck == null or order.is_empty():
			continue
		var deck_counts := _deck_card_counts(deck)
		var order_counts: Dictionary = {}
		var opening_has_basic := false
		var opening_has_trainer := false
		var opening_has_energy := false
		var opening_energy_count := 0
		var opening_has_dead_evolution := false
		var opening_has_stage2 := false
		var opening_cards: Array[CardData] = []
		var opening_has_rare_candy := false
		var opening_has_ultra_ball := false
		var opening_has_secret_box := false
		var bridge_starts_with_evolution := false
		var bridge_starts_with_declared_engine_seed := false
		var second_bridge_is_evolution := false
		var deck_has_evolution := false
		for deck_entry: Dictionary in deck.cards:
			var deck_card: CardData = CardDatabase.get_card(str(deck_entry.get("set_code", "")), str(deck_entry.get("card_index", "")))
			if deck_card != null and deck_card.is_pokemon() and not deck_card.is_basic_pokemon():
				deck_has_evolution = true
		for index: int in order.size():
			var entry: Dictionary = order[index]
			var uid := _entry_uid(entry)
			order_counts[uid] = int(order_counts.get(uid, 0)) + 1
			checks.append(assert_true(deck_counts.has(uid), "V18 deck %d fixed order card %s should exist in the deck" % [deck_id, uid]))
			checks.append(assert_true(int(order_counts[uid]) <= int(deck_counts.get(uid, 0)), "V18 deck %d fixed order should not overuse %s" % [deck_id, uid]))
			if index < 7:
				var card: CardData = CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
				if card != null:
					opening_cards.append(card)
				if card != null and card.is_basic_pokemon():
					opening_has_basic = true
				if card != null and card.is_trainer():
					opening_has_trainer = true
				if card != null and card.is_energy():
					opening_has_energy = true
					opening_energy_count += 1
				if card != null and card.matches_rule_identity_name("Rare Candy"):
					opening_has_rare_candy = true
				if card != null and card.matches_rule_identity_name("Ultra Ball"):
					opening_has_ultra_ball = true
				if card != null and card.matches_rule_identity_name("Secret Box"):
					opening_has_secret_box = true
				if card != null and card.is_pokemon() and not card.is_basic_pokemon():
					opening_has_dead_evolution = true
					opening_has_stage2 = str(card.stage).to_lower().contains("2")
			if index == 13:
				var bridge_card: CardData = CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
				bridge_starts_with_evolution = bridge_card != null and bridge_card.is_pokemon() and not bridge_card.is_basic_pokemon()
				bridge_starts_with_declared_engine_seed = deck_id == 800018880 \
					and bridge_card != null \
					and bridge_card.is_basic_pokemon() \
					and bridge_card.matches_rule_identity_name("Pidgey")
			if index == 14:
				var second_bridge_card: CardData = CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
				second_bridge_is_evolution = second_bridge_card != null and second_bridge_card.is_pokemon() and not second_bridge_card.is_basic_pokemon()
		checks.append(assert_true(opening_has_basic, "V18 deck %d fixed opening hand should contain a Basic Pokemon" % deck_id))
		checks.append(assert_true(opening_has_energy, "V18 deck %d fixed opening hand should contain Energy" % deck_id))
		checks.append(assert_true(opening_energy_count >= 2, "V18 deck %d fixed opening hand should fund setup movement and its first attack with two Energy" % deck_id))
		var opening_has_direct_candy_route := opening_has_rare_candy and opening_has_stage2
		var opening_has_direct_stage1_route := false
		for evolution: CardData in opening_cards:
			if evolution.is_basic_pokemon() or str(evolution.stage).to_lower().contains("2"):
				continue
			for seed: CardData in opening_cards:
				if seed.is_basic_pokemon() and evolution.evolves_from_matches(seed):
					opening_has_direct_stage1_route = true
					break
		checks.append(assert_true(
			opening_has_trainer or opening_has_direct_stage1_route,
			"V18 deck %d fixed opening hand should contain either an immediate Trainer route or a live Basic-to-Stage-1 route" % deck_id
		))
		checks.append(assert_true(
			not opening_has_dead_evolution or opening_has_direct_candy_route or opening_has_direct_stage1_route,
			"V18 deck %d fixed opening hand should not waste a slot on an unplayable Evolution" % deck_id
		))
		if deck_has_evolution:
			checks.append(assert_true(
				bridge_starts_with_evolution \
					or (bridge_starts_with_declared_engine_seed and second_bridge_is_evolution) \
					or opening_has_direct_candy_route \
					or (opening_has_rare_candy and opening_has_ultra_ball) \
					or (opening_has_secret_box and second_bridge_is_evolution),
				"V18 deck %d should expose its Evolution directly, behind its declared engine seed, or through an opening search route" % deck_id
			))
	return run_checks(checks)


func test_v18_strong_mode_prizes_preserve_every_resource_line() -> String:
	var registry_script: GDScript = load(FIXED_ORDER_REGISTRY_PATH)
	var registry: RefCounted = registry_script.new()
	var checks: Array[String] = []
	for deck_id: int in V18_DECK_IDS:
		var deck := _load_deck(deck_id)
		var order: Array[Dictionary] = registry.call("load_fixed_order", deck_id)
		if deck == null or order.size() < 13:
			continue
		var deck_counts := _deck_card_counts(deck)
		var prize_counts: Dictionary = {}
		for index: int in range(7, 13):
			var uid := _entry_uid(order[index])
			prize_counts[uid] = int(prize_counts.get(uid, 0)) + 1
		for uid: String in prize_counts:
			checks.append(assert_eq(
				int(prize_counts[uid]),
				1,
				"V18 deck %d strong prizes should not stack duplicate copies of %s" % [deck_id, uid]
			))
			checks.append(assert_true(
				int(prize_counts[uid]) < int(deck_counts.get(uid, 0)),
				"V18 deck %d strong prizes must leave an accessible copy of %s" % [deck_id, uid]
			))
	return run_checks(checks)


func test_v18_yanmega_strong_opening_declares_the_tm_evolution_route() -> String:
	var registry_script: GDScript = load(FIXED_ORDER_REGISTRY_PATH)
	var registry: RefCounted = registry_script.new()
	var order: Array[Dictionary] = registry.call("load_fixed_order", 800033475)
	var opening_names: Array[String] = []
	for index: int in mini(7, order.size()):
		var entry: Dictionary = order[index]
		var card: CardData = CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
		opening_names.append(str(card.name) if card != null else "")
	return run_checks([
		assert_true("含羞苞" in opening_names, "Yanmega strong mode should open the TM Evolution route with Budew Active"),
		assert_true("蜻蜻蜓" in opening_names, "Yanmega strong mode should expose its first evolution seed in the opening hand"),
		assert_true("友好宝芬" in opening_names, "Yanmega strong mode should be able to establish the second Yanma before attacking"),
		assert_true("招式学习器 进化" in opening_names, "Yanmega strong mode should carry TM Evolution in the opening hand"),
	])


func test_v18_raging_bolt_strong_opening_declares_the_t2_bellowing_thunder_route() -> String:
	var catalog_script: Variant = load(PROFILE_CATALOG_PATH)
	if not catalog_script is GDScript:
		return assert_true(false, "The V18 profile catalog should compile")
	var profile: Dictionary = (catalog_script as GDScript).call("get_profile_for_deck", 800018509)
	var strong_order: Dictionary = profile.get("strong_order", {})
	var opening: Array = strong_order.get("opening_cards", [])
	var bridge: Array = strong_order.get("bridge_cards", [])
	return run_checks([
		assert_eq(opening.size(), 7, "Raging Bolt strong mode should pin a complete seven-card setup hand"),
		assert_true(opening.has("猛雷鼓ex"), "The strong setup hand must contain the primary attacker"),
		assert_true(opening.has("厄诡椪 碧草面具ex"), "The strong setup hand must contain the Energy engine"),
		assert_true(opening.has("咕咕"), "The strong setup hand must establish the Noctowl search lane"),
		assert_true(opening.has("基本斗能量") and opening.has("基本雷能量"), "The strong setup hand must contain the LF attack core"),
		assert_eq(str(bridge[0]) if not bridge.is_empty() else "", "猫头夜鹰", "The first live draw must complete the Noctowl search route"),
		assert_true(bridge.has("猛雷鼓ex"), "The bridge must establish a second Bellowing Thunder attacker"),
		assert_true(bridge.has("奥琳博士的气魄"), "The bridge must preserve a second Ancient Energy acceleration turn"),
	])


func test_v18_generated_strong_openings_derive_energy_from_primary_attack_costs() -> String:
	var registry_script: GDScript = load(FIXED_ORDER_REGISTRY_PATH)
	var registry: RefCounted = registry_script.new()
	var blaziken_order: Array[Dictionary] = registry.call("load_fixed_order", 18000625)
	var blaziken_symbols := _opening_energy_symbols(blaziken_order)
	var mixed_order: Array[Dictionary] = registry.call("load_fixed_order", 800019125)
	var mixed_symbols := _opening_energy_symbols(mixed_order)
	return run_checks([
		assert_eq(blaziken_symbols, ["R", "R"], "Blaziken strong mode should open Fire Energy instead of unrelated Darkness Energy"),
		assert_true("R" in mixed_symbols and "P" in mixed_symbols, "Dragapult/Blaziken strong mode should open the RP route required by Phantom Dive"),
	])


func test_battle_setup_uses_registry_as_the_single_strategy_mapping_source() -> String:
	var source := FileAccess.get_file_as_string(BATTLE_SETUP_PATH)
	var runner_source := FileAccess.get_file_as_string(AI_TRAINING_RUNNER_PATH)
	return run_checks([
		assert_false(source.contains("AI_DECK_STRATEGY_ID_BY_DECK_ID"), "BattleSetup should not maintain a second deck-to-strategy map"),
		assert_true(source.contains("DeckStrategyRegistryScript"), "BattleSetup should load the shared DeckStrategyRegistry"),
		assert_true(source.contains("resolve_strategy_id_for_deck"), "BattleSetup strategy selection should delegate to the registry"),
		assert_false(runner_source.contains("DECK_ID_TO_STRATEGY_ID"), "AITrainingTestRunner should not maintain a benchmark-only strategy map"),
		assert_true(runner_source.contains("DeckStrategyRegistryScript"), "AITrainingTestRunner should query the shared strategy registry"),
	])


func test_v18_shared_scoring_prefers_energy_that_pays_the_attack_cost() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(20)
	var gholdengo := _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×"))
	state.players[0].active_pokemon = gholdengo
	var metal := CardInstance.create(_make_energy("基本钢能量", "M"), 0)
	var lightning := CardInstance.create(_make_energy("基本雷能量", "L"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var metal_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": metal,
		"target_slot": gholdengo,
	}, state, 0, contract)
	var lightning_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": lightning,
		"target_slot": gholdengo,
	}, state, 0, contract)
	return assert_true(
		metal_score >= lightning_score + 300.0,
		"V18 shared scoring should strongly prefer Energy that satisfies a typed attack cost (metal=%f lightning=%f)" % [metal_score, lightning_score]
	)


func test_v18_shared_scoring_suppresses_draw_churn_when_attack_ready_and_deck_is_low() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(4)
	var gholdengo := _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×", [{"name": "嘉奖硬币", "text": "从自己的牌库抽取2张卡牌。"}]))
	gholdengo.attached_energy.append(CardInstance.create(_make_energy("基本钢能量", "M"), 0))
	state.players[0].active_pokemon = gholdengo
	var sada := CardInstance.create(_make_trainer("奥琳博士的气魄", "从自己的牌库抽取3张卡牌。"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var ability_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": gholdengo,
		"ability_index": 0,
	}, state, 0, contract)
	var sada_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": sada,
		"productive": true,
	}, state, 0, contract)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": gholdengo,
		"projected_damage": 150,
		"projected_knockout": false,
	}, state, 0, contract)
	return run_checks([
		assert_true(ability_score <= attack_score - 1000.0, "Low-deck Gholdengo draw should stay far below an available attack (ability=%f attack=%f)" % [ability_score, attack_score]),
		assert_true(sada_score <= attack_score - 1000.0, "Low-deck Professor Sada draw should stay far below an available attack (sada=%f attack=%f)" % [sada_score, attack_score]),
	])


func test_v18_shared_scoring_suppresses_draw_attacks_when_deck_is_low() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(4)
	var raging_bolt_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_bolt_data.mechanic = "ex"
	raging_bolt_data.attacks = [
		{
			"name": "Bursting Roar",
			"cost": "C",
			"damage": "",
			"text": "Discard your hand and draw 6 cards.",
		},
		{
			"name": "Bellowing Thunder",
			"cost": "LF",
			"damage": "70x",
			"text": "Discard any amount of Basic Energy from your Pokemon in play.",
		},
	]
	var raging_bolt := _make_slot(raging_bolt_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Basic Colorless Energy", "C"), 0))
	state.players[0].active_pokemon = raging_bolt
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var draw_attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": raging_bolt,
		"attack_index": 0,
		"projected_damage": 0,
		"projected_knockout": false,
	}, state, 0, contract)
	var end_turn_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "end_turn",
	}, state, 0, contract)
	return run_checks([
		assert_true(draw_attack_score <= -1800.0, "A draw attack must be hard-blocked when the turn started with a low deck (score=%f)" % draw_attack_score),
		assert_true(end_turn_score > draw_attack_score, "Passing must be safer than drawing six from a four-card deck (draw=%f end=%f)" % [draw_attack_score, end_turn_score]),
	])


func test_v18_low_deck_draw_attack_does_not_trigger_retreat_into_an_unready_bench() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(4)
	var raging_bolt_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_bolt_data.mechanic = "ex"
	raging_bolt_data.attacks = [{
		"name": "Bursting Roar",
		"cost": "C",
		"damage": "",
		"text": "Discard your hand and draw 6 cards.",
	}]
	var raging_bolt := _make_slot(raging_bolt_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Basic Colorless Energy", "C"), 0))
	var unready_target := _make_slot(_make_basic_pokemon("Hoothoot", "C"))
	state.players[0].active_pokemon = raging_bolt
	state.players[0].bench.append(unready_target)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": unready_target,
	}, state, 0, contract)
	var end_turn_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "end_turn",
	}, state, 0, contract)
	return assert_true(
		retreat_score <= end_turn_score - 300.0,
		"Low-deck safety must prefer passing over retreating from a usable Active into an unready bench (retreat=%f end=%f)" % [retreat_score, end_turn_score]
	)


func test_v18_low_deck_end_turn_remains_a_safe_option_without_a_ready_attacker() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(4)
	state.players[0].active_pokemon = _make_slot(_make_basic_pokemon("Raging Bolt ex", "N"))
	state.players[0].bench.append(_make_slot(_make_basic_pokemon("Teal Mask Ogerpon ex", "G")))
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	if hoothoot_data == null:
		return "Expected CSV9C_154 Hoothoot to exist"
	state.players[0].bench.append(_make_slot(hoothoot_data))
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var end_turn_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "end_turn",
	}, state, 0, contract)
	return assert_true(
		end_turn_score >= -300.0,
		"A low-deck rebuild turn must be allowed to pass instead of forcing optional churn (score=%f)" % end_turn_score
	)


func test_v18_low_deck_hand_reset_does_not_draw_the_last_cards_without_a_ready_attacker() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(3)
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.attacks = [
		{"name": "Bursting Roar", "cost": "C", "damage": ""},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	state.players[0].active_pokemon = raging_bolt
	var iono := CardInstance.create(_make_trainer("Iono"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var iono_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": iono, "productive": true,
	}, state, 0, contract)
	var end_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "end_turn",
	}, state, 0, contract)
	return assert_true(
		iono_score <= -1800.0 and iono_score <= end_score - 1000.0,
		"With only three cards left and no ready attacker, Iono must not create a forced deck-out (iono=%f end=%f)" % [iono_score, end_score]
	)


func test_v18_shared_absolute_scale_protects_real_attacks_from_generic_intent_noise() -> String:
	var strategy := _strategy_for_deck(800017407)
	var state := _make_scoring_state(24)
	var profile: Dictionary = strategy.call("_profile")
	var attacker_name := str((profile.get("energy_priority", []) as Array)[0])
	var attacker := _make_slot(_make_pokemon(attacker_name, "M", "C", "150"))
	attacker.attached_energy.append(CardInstance.create(_make_energy("Basic Colorless Energy", "C"), 0))
	state.players[0].active_pokemon = attacker
	for bench_name_variant: Variant in (profile.get("bench_priority", []) as Array).slice(0, 2):
		state.players[0].bench.append(_make_slot(_make_basic_pokemon(str(bench_name_variant), "C")))
	var unrelated_trainer := CardInstance.create(_make_trainer("Unrelated Trainer"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": attacker,
		"attack_index": 0,
		"projected_damage": 150,
		"projected_knockout": false,
	}, state, 0, contract)
	var trainer_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": unrelated_trainer,
		"productive": true,
	}, state, 0, contract)
	return assert_true(
		attack_score >= trainer_score + 600.0,
		"The shared absolute scale must keep a real attack above unrelated generic intent bonuses (attack=%f trainer=%f)" % [attack_score, trainer_score]
	)


func test_v18_teal_mask_ogerpon_uses_teal_dance_before_manual_grass_attachment() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var ogerpon_data: CardData = CardDatabase.get_card("CSV8C", "028")
	if ogerpon_data == null:
		return "Expected CSV8C_028 Teal Mask Ogerpon ex to exist"
	var ogerpon := _make_slot(ogerpon_data)
	state.players[0].active_pokemon = ogerpon
	var grass := CardInstance.create(_make_energy("Basic Grass Energy", "G"), 0)
	state.players[0].hand.append(grass)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var ability_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": ogerpon,
		"ability_index": 0,
	}, state, 0, contract)
	var attach_before_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": ogerpon,
	}, state, 0, contract)
	ogerpon.effects.append({
		"type": "ability_attach_basic_energy_from_hand_draw_used",
		"turn": state.turn_number,
	})
	var attach_after_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": ogerpon,
	}, state, 0, contract)
	return run_checks([
		assert_true(
			ability_score >= attach_before_score + 300.0,
			"Teal Dance must consume the available Grass before the once-per-turn manual attachment (ability=%f attach=%f)" % [ability_score, attach_before_score]
		),
		assert_true(
			attach_after_score >= attach_before_score + 500.0,
			"Manual attachment must recover its normal value immediately after Teal Dance is used (before=%f after=%f)" % [attach_before_score, attach_after_score]
		),
	])


func test_v18_low_deck_turn_contract_survives_mid_turn_super_rod_replenishment() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(4)
	var gholdengo := _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×", [{"name": "嘉奖硬币", "text": "从自己的牌库抽取2张卡牌。"}]))
	gholdengo.attached_energy.append(CardInstance.create(_make_energy("基本钢能量", "M"), 0))
	state.players[0].active_pokemon = gholdengo
	state.players[0].hand.append(CardInstance.create(_make_energy("基本水能量", "W"), 0))
	state.players[0].hand.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	for index: int in 8:
		state.players[0].deck.append(CardInstance.create(_make_trainer("Recycled card %d" % index), 0))
	var ability_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": gholdengo,
		"ability_index": 0,
	}, state, 0, contract)
	return assert_true(
		ability_score <= -1800.0,
		"A low-deck turn must keep draw churn hard-blocked after Super Rod temporarily replenishes the live deck (score=%f)" % ability_score
	)


func test_v18_shared_scoring_suppresses_deck_search_when_attack_ready_and_only_two_cards_remain() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(2)
	var raging_bolt := _make_slot(_make_pokemon("猛雷鼓ex", "N", "FC", "70"))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("基本斗能量", "F"), 0))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	state.players[0].active_pokemon = raging_bolt
	var nest_ball := CardInstance.create(_make_trainer("巢穴球", "从自己的牌库中选择1只基础宝可梦。"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var search_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": nest_ball,
		"productive": true,
		"targets": [{"search_pokemon": [state.players[0].deck[0]]}],
	}, state, 0, contract)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": raging_bolt,
		"projected_damage": 70,
		"projected_knockout": false,
	}, state, 0, contract)
	return assert_true(
		search_score <= attack_score - 300.0,
		"With only two cards left, deck search should not outrank an available attack (search=%f attack=%f)" % [search_score, attack_score]
	)


func test_v18_shared_scoring_never_delays_a_final_prize_knockout_for_draw_churn() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(4)
	var gholdengo := _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×", [{"name": "嘉奖硬币", "text": "从自己的牌库抽取2张卡牌。"}]))
	gholdengo.attached_energy.append(CardInstance.create(_make_energy("基本钢能量", "M"), 0))
	state.players[0].active_pokemon = gholdengo
	state.players[0].set_prizes([CardInstance.create(_make_trainer("Prize"), 0)])
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var ability_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": gholdengo,
		"ability_index": 0,
	}, state, 0, contract)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": gholdengo,
		"projected_damage": 300,
		"projected_knockout": true,
	}, state, 0, contract)
	return assert_true(attack_score >= ability_score + 5000.0, "A final-prize knockout must remain terminal even when draw actions are legal")


func test_v18_search_scoring_prefers_the_next_live_evolution_stage() -> String:
	var strategy := _strategy_for_deck(18000625)
	var state := _make_scoring_state(30)
	var torchic := _make_slot(_make_basic_pokemon("火稚鸡", "R"))
	state.players[0].active_pokemon = _make_slot(_make_basic_pokemon("含羞苞", "G"))
	state.players[0].bench.append(torchic)
	var combusken := CardInstance.create(_make_stage1_pokemon("力壮鸡", "火稚鸡", "R", "RC", "60"), 0)
	var blaziken := CardInstance.create(_make_stage2_pokemon("火焰鸡ex", "力壮鸡", "R", "RCC", "200"), 0)
	var context := {"game_state": state, "player_index": 0}
	var combusken_score: float = strategy.call("score_interaction_target", combusken, {"id": "search_pokemon"}, context)
	var blaziken_score: float = strategy.call("score_interaction_target", blaziken, {"id": "search_pokemon"}, context)
	return assert_true(
		combusken_score >= blaziken_score + 500.0,
		"With only Torchic in play and no Rare Candy, search should take Combusken before Blaziken ex (combusken=%f blaziken=%f)" % [combusken_score, blaziken_score]
	)


func test_v18_search_repays_a_missing_basic_primary_attacker_before_optional_engine_evolution() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	var hoothoot_data: CardData = CardDatabase.get_card("CSV9C", "154")
	var ogerpon_data: CardData = CardDatabase.get_card("CSV8C", "028")
	var raging_bolt_data: CardData = CardDatabase.get_card("CSV7C", "154")
	var noctowl_data: CardData = CardDatabase.get_card("CSV9C", "155")
	if hoothoot_data == null or ogerpon_data == null or raging_bolt_data == null or noctowl_data == null:
		return "Expected the Raging Bolt and Noctowl search-route cards to exist"
	state.players[0].active_pokemon = _make_slot(hoothoot_data)
	state.players[0].bench.append(_make_slot(ogerpon_data))
	var raging_bolt := CardInstance.create(raging_bolt_data, 0)
	var noctowl := CardInstance.create(noctowl_data, 0)
	var context := {"game_state": state, "player_index": 0}
	var raging_score: float = strategy.call("score_interaction_target", raging_bolt, {"id": "search_pokemon"}, context)
	var noctowl_score: float = strategy.call("score_interaction_target", noctowl, {"id": "search_pokemon"}, context)
	return assert_true(
		raging_score >= noctowl_score + 500.0,
		"A missing Basic primary attacker must outrank an optional live engine evolution (raging=%f noctowl=%f)" % [raging_score, noctowl_score]
	)


func test_v18_search_returns_to_live_engine_evolution_after_primary_attacker_is_established() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	var hoothoot_data: CardData = CardDatabase.get_card("CSV9C", "154")
	var raging_bolt_data: CardData = CardDatabase.get_card("CSV7C", "154")
	var noctowl_data: CardData = CardDatabase.get_card("CSV9C", "155")
	if hoothoot_data == null or raging_bolt_data == null or noctowl_data == null:
		return "Expected the Raging Bolt and Noctowl search-route cards to exist"
	state.players[0].active_pokemon = _make_slot(hoothoot_data)
	state.players[0].bench.append(_make_slot(raging_bolt_data))
	var raging_bolt := CardInstance.create(raging_bolt_data, 0)
	var noctowl := CardInstance.create(noctowl_data, 0)
	var context := {"game_state": state, "player_index": 0}
	var raging_score: float = strategy.call("score_interaction_target", raging_bolt, {"id": "search_pokemon"}, context)
	var noctowl_score: float = strategy.call("score_interaction_target", noctowl, {"id": "search_pokemon"}, context)
	return assert_true(
		noctowl_score >= raging_score + 300.0,
		"Once the primary attacker exists, a live Noctowl evolution should outrank a duplicate attacker (raging=%f noctowl=%f)" % [raging_score, noctowl_score]
	)


func test_v18_missing_basic_primary_preserves_manual_energy_from_filler_targets() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	var hoothoot_data: CardData = CardDatabase.get_card("CSV9C", "154")
	var ogerpon_data: CardData = CardDatabase.get_card("CSV8C", "028")
	var raging_bolt_data: CardData = CardDatabase.get_card("CSV7C", "154")
	if hoothoot_data == null or ogerpon_data == null or raging_bolt_data == null:
		return "Expected the Raging Bolt energy-route cards to exist"
	var hoothoot := _make_slot(hoothoot_data)
	state.players[0].active_pokemon = hoothoot
	state.players[0].bench.append(_make_slot(ogerpon_data))
	state.players[0].deck.append(CardInstance.create(raging_bolt_data, 0))
	var fighting := CardInstance.create(_make_energy("Fighting Energy", "F"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var filler_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": fighting,
		"target_slot": hoothoot,
	}, state, 0, contract)
	var raging_bolt := _make_slot(raging_bolt_data)
	state.players[0].bench.append(raging_bolt)
	var attacker_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": fighting,
		"target_slot": raging_bolt,
	}, state, 0, contract)
	return run_checks([
		assert_true(filler_score <= -1500.0, "Typed Energy must be held while the Basic primary attacker is still missing (score=%f)" % filler_score),
		assert_true(attacker_score >= filler_score + 2000.0, "The preserved Energy must become valuable as soon as the primary attacker enters play (attacker=%f filler=%f)" % [attacker_score, filler_score]),
	])


func test_v18_tord_tera_box_reuses_the_mature_terapagos_noctowl_engine() -> String:
	var catalog_script: GDScript = load(PROFILE_CATALOG_PATH)
	var profile: Dictionary = catalog_script.new().call("get_profile_for_deck", 800015934)
	return assert_eq(
		str(profile.get("delegate_script_path", "")),
		"res://scripts/ai/DeckStrategyV18TeraNoctowl.gd",
		"Tord Tera Box should use the V18 Terapagos/Noctowl family delegate"
	)


func test_v18_tera_attacker_prediction_applies_sparkling_crystal_discount() -> String:
	var strategy := _strategy_for_deck(800015934)
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if terapagos_data == null or crystal_data == null:
		return "Terapagos ex and Sparkling Crystal should load from the bundled card pool"
	var terapagos := _make_slot(terapagos_data)
	terapagos.attached_energy.append(CardInstance.create(_make_energy("Grass Energy", "G"), 0))
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	var prediction: Dictionary = strategy.call("predict_attacker_damage", terapagos)
	return run_checks([
		assert_true(bool(prediction.get("can_attack", false)), "Sparkling Crystal should reduce Terapagos Alliance Strike from two Energy to one"),
		assert_true(int(prediction.get("damage", 0)) >= 30, "A discounted ready Terapagos should expose non-zero projected damage"),
	])


func test_v18_tera_noctowl_strong_openings_expose_a_direct_turn_three_attack_route() -> String:
	var registry_script: GDScript = load(FIXED_ORDER_REGISTRY_PATH)
	var registry: RefCounted = registry_script.new()
	var checks: Array[String] = []
	for case: Dictionary in [
		{
			"deck_id": 800015934,
			"route_energy_uid": "CSVE1C_GRA",
			"opening_route_uids": ["CSV9C_175", "CSV9C_155"],
		},
		{
			"deck_id": 800017643,
			"route_energy_uid": "CSVE1C_FIR",
			"opening_route_uids": ["CSV9C_153", "CSV9.5C_023"],
		},
	]:
		var deck_id := int(case.get("deck_id", 0))
		var order: Array[Dictionary] = registry.call("load_fixed_order", deck_id)
		var opening_uids: Array[String] = []
		for index: int in mini(7, order.size()):
			opening_uids.append(_entry_uid(order[index]))
		for route_uid: String in case.get("opening_route_uids", []):
			checks.append(assert_true(route_uid in opening_uids, "V18 Tera/Noctowl %d should open direct route card %s" % [deck_id, route_uid]))
		checks.append(assert_true("CSV9C_154" in opening_uids and "CSV9.5C_141" in opening_uids, "V18 Tera/Noctowl %d should open both Hoothoot bodies" % deck_id))
		checks.append(assert_false("CSV1C_112" in opening_uids, "V18 Tera/Noctowl %d should not open Ultra Ball that discards its route Energy" % deck_id))
		checks.append(assert_eq(_entry_uid(order[13]) if order.size() > 13 else "", "CSV9C_155", "V18 Tera/Noctowl %d should draw the second Noctowl on turn one" % deck_id))
		checks.append(assert_eq(_entry_uid(order[14]) if order.size() > 14 else "", str(case.get("route_energy_uid", "")), "V18 Tera/Noctowl %d should draw its second attack Energy on turn three" % deck_id))
	return run_checks(checks)


func test_v18_raging_bolt_opening_prefers_ogerpon_over_hoothoot_without_a_bolt() -> String:
	var strategy := _strategy_for_deck(800018509)
	var hoothoot_data: CardData = CardDatabase.get_card("CSV9C", "154")
	var ogerpon_data: CardData = CardDatabase.get_card("CSV8C", "028")
	if hoothoot_data == null or ogerpon_data == null:
		return "Expected the Raging Bolt opening cards to exist"
	var player := PlayerState.new()
	player.player_index = 0
	player.hand = [
		CardInstance.create(hoothoot_data, 0),
		CardInstance.create(ogerpon_data, 0),
	]
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active_index := int(plan.get("active_hand_index", -1))
	if active_index < 0 or active_index >= player.hand.size():
		return "Raging Bolt opening strategy did not choose a legal Active"
	return assert_eq(
		str(player.hand[active_index].card_data.name_en),
		"Teal Mask Ogerpon ex",
		"Without Raging Bolt ex, Teal Mask Ogerpon ex should be Active ahead of Hoothoot"
	)


func test_v18_raging_bolt_opening_uses_ditto_instead_of_stranding_slither_wing() -> String:
	var strategy := _strategy_for_deck(800018509)
	var slither_wing_data := CardDatabase.get_card("CSV6C", "082")
	var bloodmoon_data := CardDatabase.get_card("CSV8C", "172")
	var ditto_data := CardDatabase.get_card("151C", "132")
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if slither_wing_data == null or bloodmoon_data == null or ditto_data == null or raging_data == null:
		return "Expected the Raging Bolt opening pivot cards to exist"
	var player := PlayerState.new()
	player.player_index = 0
	player.hand = [
		CardInstance.create(slither_wing_data, 0),
		CardInstance.create(bloodmoon_data, 0),
		CardInstance.create(ditto_data, 0),
	]
	player.deck.append(CardInstance.create(raging_data, 0))
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 2, "Ditto should start Active and transform into Raging Bolt instead of stranding Slither Wing"),
		assert_true(0 in plan.get("bench_hand_indices", []), "Slither Wing should remain available as a later single-prize attacker"),
	])


func test_v18_raging_bolt_opening_does_not_bench_a_missed_ditto() -> String:
	var strategy := _strategy_for_deck(800018509)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	var ditto_data := CardDatabase.get_card("151C", "132")
	if raging_data == null or ditto_data == null:
		return "Expected Raging Bolt ex and Ditto to exist"
	var player := PlayerState.new()
	player.player_index = 0
	player.hand = [
		CardInstance.create(raging_data, 0),
		CardInstance.create(ditto_data, 0),
	]
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 0, "Raging Bolt ex should remain the direct Active"),
		assert_false(1 in plan.get("bench_hand_indices", []), "Ditto must stay in hand when it cannot use Transform Start from the Bench"),
	])


func test_v18_flareon_strong_opening_uses_the_fast_evolution_eevee_as_active() -> String:
	var strategy := _strategy_for_deck(800017643)
	var player := PlayerState.new()
	var eevee := CardDatabase.get_card("CSV9C", "153")
	var fan_rotom := CardDatabase.get_card("CSV9C", "161")
	var hoothoot := CardDatabase.get_card("CSV9C", "154")
	var flareon := CardDatabase.get_card("CSV9.5C", "023")
	if eevee == null or fan_rotom == null or hoothoot == null or flareon == null:
		return assert_true(false, "The V18 Flareon direct opening route should load")
	player.hand = [
		CardInstance.create(fan_rotom, 0),
		CardInstance.create(hoothoot, 0),
		CardInstance.create(eevee, 0),
		CardInstance.create(flareon, 0),
	]
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 2, "Fast Evolution Eevee should start Active so Flareon ex can evolve on turn one"),
		assert_true(0 in plan.get("bench_hand_indices", []), "Fan Rotom should remain on the Bench for Fan Call"),
	])


func test_v18_noctowl_search_prioritizes_area_zero_and_energy_setup_for_direct_attackers() -> String:
	var tord_strategy := _strategy_for_deck(800015934)
	var flareon_strategy := _strategy_for_deck(800017643)
	var nest_ball := CardInstance.create(CardDatabase.get_card("CSVH1C", "043"), 0)
	var area_zero := CardInstance.create(CardDatabase.get_card("CSV9C", "207"), 0)
	var crispin := CardInstance.create(CardDatabase.get_card("CSV9C", "196"), 0)
	var switch_card := CardInstance.create(CardDatabase.get_card("CSV1C", "113"), 0)
	var kieran := CardInstance.create(CardDatabase.get_card("CSV8C", "198"), 0)
	if nest_ball.card_data == null or area_zero.card_data == null or crispin.card_data == null or switch_card.card_data == null or kieran.card_data == null:
		return assert_true(false, "The V18 Noctowl direct-attack setup Trainers should load")
	var step := {"id": "csv9c_noctowl_trainers", "max_select": 2}
	var tord_picks: Array = tord_strategy.call("pick_interaction_items", [nest_ball, area_zero, crispin], step, {})
	var flareon_picks: Array = flareon_strategy.call("pick_interaction_items", [switch_card, kieran, area_zero, crispin], step, {})
	return run_checks([
		assert_true(area_zero in tord_picks and nest_ball in tord_picks, "Tord Tera Box should search Area Zero and a bench extender before its direct Terapagos attack"),
		assert_true(area_zero in flareon_picks and crispin in flareon_picks, "Flareon Noctowl should search Area Zero and Crispin before its direct Flareon attack"),
	])


func test_v18_flareon_second_jewel_search_converts_the_first_pair_into_a_pivot() -> String:
	var strategy := _strategy_for_deck(800017643)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var hoothoot := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	var flareon := _make_slot(CardDatabase.get_card("CSV9.5C", "023"))
	flareon.attached_energy = [CardInstance.create(_make_energy("Fire Energy", "R"), 0)]
	var area_in_hand := CardInstance.create(CardDatabase.get_card("CSV9C", "207"), 0)
	var crispin_in_hand := CardInstance.create(CardDatabase.get_card("CSV9C", "196"), 0)
	var duplicate_area := CardInstance.create(CardDatabase.get_card("CSV9C", "207"), 0)
	var duplicate_crispin := CardInstance.create(CardDatabase.get_card("CSV9C", "196"), 0)
	var switch_card := CardInstance.create(CardDatabase.get_card("CSV1C", "113"), 0)
	player.active_pokemon = hoothoot
	player.bench = [flareon]
	player.hand = [area_in_hand, crispin_in_hand]
	player.deck = [duplicate_area, duplicate_crispin, switch_card]
	var picked: Array = strategy.call("pick_interaction_items", player.deck, {
		"id": "csv9c_noctowl_trainers",
		"max_select": 2,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(switch_card in picked, "The second Jewel Search should fetch Switch when the first pair can fund a benched Flareon but the Active is stranded"),
		assert_false(duplicate_area in picked, "The second Jewel Search should not fetch another Area Zero already held in hand"),
		assert_false(duplicate_crispin in picked, "The second Jewel Search should not fetch another Crispin already held in hand"),
	])


func test_v18_flareon_kieran_switches_a_stranded_active_into_a_ready_attacker() -> String:
	var strategy := _strategy_for_deck(800017643)
	var state := _make_scoring_state(5)
	var player := state.players[0]
	var hoothoot := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	var flareon := _make_slot(CardDatabase.get_card("CSV9.5C", "023"))
	flareon.attached_energy = [
		CardInstance.create(_make_energy("Fire Energy", "R"), 0),
		CardInstance.create(_make_energy("Water Energy", "W"), 0),
		CardInstance.create(_make_energy("Lightning Energy", "L"), 0),
	]
	player.active_pokemon = hoothoot
	player.bench = [flareon]
	var context := {"game_state": state, "player_index": 0}
	var switch_score: float = strategy.call("score_interaction_target", "switch_active", {"id": "kieran_mode"}, context)
	var damage_score: float = strategy.call("score_interaction_target", "damage_boost", {"id": "kieran_mode"}, context)
	return assert_true(
		switch_score > damage_score,
		"Kieran should switch a stranded Active into the ready benched Flareon (switch=%f damage=%f)" % [switch_score, damage_score]
	)


func test_v18_flareon_kieran_does_not_pivot_an_attack_lock_into_an_unready_engine() -> String:
	var strategy := _strategy_for_deck(800017643)
	var state := _make_scoring_state(5)
	var player := state.players[0]
	var flareon := _make_slot(CardDatabase.get_card("CSV9.5C", "023"))
	flareon.effects.append({"type": "attack_lock_all", "turn": 3})
	var hoothoot := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	player.active_pokemon = flareon
	player.bench = [hoothoot]
	var context := {"game_state": state, "player_index": 0}
	var switch_score: float = strategy.call("score_interaction_target", "switch_active", {"id": "kieran_mode"}, context)
	var damage_score: float = strategy.call("score_interaction_target", "damage_boost", {"id": "kieran_mode"}, context)
	return assert_true(
		damage_score >= switch_score,
		"Kieran must not spend its switch mode to replace an attack-locked Flareon with an unready engine Pokemon (switch=%f damage=%f)" % [switch_score, damage_score]
	)


func test_v18_flareon_ultra_ball_searches_the_live_eevee_evolution_before_dead_noctowl() -> String:
	var strategy := _strategy_for_deck(800017643)
	var state := _make_scoring_state(24)
	var player := state.players[0]
	var wellspring := _make_slot(CardDatabase.get_card("CSV8C", "067"))
	var eevee_ex := _make_slot(CardDatabase.get_card("CSV9.5C", "140"))
	var flareon := CardInstance.create(CardDatabase.get_card("CSV9.5C", "023"), 0)
	var noctowl := CardInstance.create(CardDatabase.get_card("CSV9C", "155"), 0)
	player.active_pokemon = wellspring
	player.bench = [eevee_ex]
	player.deck = [noctowl, flareon]
	var picked: Array = strategy.call("pick_interaction_items", [noctowl, flareon], {
		"id": "search_pokemon",
		"max_select": 1,
	}, {
		"game_state": state,
		"player_index": 0,
		"target_items": [noctowl, flareon],
	})
	return assert_true(
		picked == [flareon],
		"Ultra Ball should complete the live Eevee lane before taking an unplayable Noctowl (picked=%s)" % str(picked)
	)


func test_v18_headless_kieran_switch_resolves_the_ready_flareon_followup_target() -> String:
	var strategy := _strategy_for_deck(800017643)
	var state := _make_scoring_state(5)
	var player := state.players[0]
	var hoothoot := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	var flareon := _make_slot(CardDatabase.get_card("CSV9.5C", "023"))
	flareon.attached_energy = [
		CardInstance.create(_make_energy("Fire Energy", "R"), 0),
		CardInstance.create(_make_energy("Water Energy", "W"), 0),
		CardInstance.create(_make_energy("Lightning Energy", "L"), 0),
	]
	var engine_hoothoot := _make_slot(CardDatabase.get_card("CSV9.5C", "141"))
	var kieran := CardInstance.create(CardDatabase.get_card("CSV8C", "198"), 0)
	player.active_pokemon = hoothoot
	player.bench = [engine_hoothoot, flareon]
	player.hand = [kieran]
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	var kieran_action: Dictionary = {}
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "play_trainer" and action.get("card", null) == kieran:
			kieran_action = action
			break
	var target_context: Dictionary = {}
	if not kieran_action.is_empty():
		var targets: Variant = kieran_action.get("targets", [])
		if targets is Array and not (targets as Array).is_empty() and (targets as Array)[0] is Dictionary:
			target_context = (targets as Array)[0]
	var switch_targets: Variant = target_context.get("kieran_switch_target", [])
	return run_checks([
		assert_false(kieran_action.is_empty(), "The headless builder should expose Kieran as a playable Supporter"),
		assert_true(target_context.get("kieran_mode", []) == ["switch_active"], "Kieran should choose switch mode for a stranded Active and ready Flareon"),
		assert_true(switch_targets is Array and (switch_targets as Array).size() == 1 and (switch_targets as Array)[0] == flareon, "The headless builder must resolve Kieran's follow-up target to the ready Flareon"),
	])


func test_v18_tera_noctowl_runs_its_first_jewel_search_before_a_non_knockout_attack() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var terapagos := _make_slot(CardDatabase.get_card("CSV9C", "175"))
	terapagos.attached_energy = [
		CardInstance.create(_make_energy("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy("Water Energy", "W"), 0),
	]
	var hoothoot := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	hoothoot.turn_played = 1
	var noctowl := CardInstance.create(CardDatabase.get_card("CSV9C", "155"), 0)
	player.active_pokemon = terapagos
	player.bench = [hoothoot]
	player.hand = [noctowl]
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var evolve_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "evolve",
		"card": noctowl,
		"target_slot": hoothoot,
	}, state, 0, plan)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": terapagos,
		"attack_index": 0,
		"projected_damage": 60,
		"projected_knockout": false,
	}, state, 0, plan)
	return assert_true(
		evolve_score > attack_score,
		"The first Jewel Seeker should resolve before a non-KO Terapagos attack (evolve=%f attack=%f)" % [evolve_score, attack_score]
	)


func test_v18_flareon_search_establishes_hoothoot_after_the_eevee_route_is_live() -> String:
	var strategy := _strategy_for_deck(800017643)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var flareon := _make_slot(CardDatabase.get_card("CSV9.5C", "023"))
	var ogerpon := _make_slot(CardDatabase.get_card("CSV8C", "028"))
	var hoothoot := CardInstance.create(CardDatabase.get_card("CSV9C", "154"), 0)
	var rotom := CardInstance.create(CardDatabase.get_card("CSV9C", "161"), 0)
	var duplicate_eevee := CardInstance.create(CardDatabase.get_card("CSV9.5C", "022"), 0)
	player.active_pokemon = flareon
	player.bench = [ogerpon]
	player.deck = [hoothoot, rotom, duplicate_eevee]
	var picked: Array = strategy.call("pick_interaction_items", player.deck, {
		"id": "basic_pokemon",
		"max_select": 1,
	}, {"game_state": state, "player_index": 0})
	return assert_true(
		picked.size() == 1 and picked[0] == hoothoot,
		"Once the Eevee attacker and Tera condition are live, Flareon should search Hoothoot before duplicate setup Pokemon"
	)


func test_v18_tord_search_recognizes_the_alternate_hoothoot_printing() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var terapagos := _make_slot(CardDatabase.get_card("CSV9C", "175"))
	var ogerpon := _make_slot(CardDatabase.get_card("CSV8C", "028"))
	var alternate_hoothoot := CardInstance.create(CardDatabase.get_card("CSV9.5C", "141"), 0)
	var rotom := CardInstance.create(CardDatabase.get_card("CSV9C", "161"), 0)
	var duplicate_ogerpon := CardInstance.create(CardDatabase.get_card("CSV8C", "028"), 0)
	player.active_pokemon = terapagos
	player.bench = [ogerpon]
	player.deck = [alternate_hoothoot, rotom, duplicate_ogerpon]
	var picked: Array = strategy.call("pick_interaction_items", player.deck, {
		"id": "basic_pokemon",
		"max_select": 1,
	}, {"game_state": state, "player_index": 0})
	return assert_true(
		picked.size() == 1 and picked[0] == alternate_hoothoot,
		"With two Tera Pokemon established, Tord Tera Box should recognize the alternate Hoothoot printing as its missing engine Basic"
	)


func test_v18_tord_uses_area_zero_and_bench_extension_before_non_knockout_alliance_strike() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var terapagos := _make_slot(CardDatabase.get_card("CSV9C", "175"))
	terapagos.attached_energy = [
		CardInstance.create(_make_energy("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy("Water Energy", "W"), 0),
	]
	var noctowl := _make_slot(CardDatabase.get_card("CSV9C", "155"))
	var rotom := _make_slot(CardDatabase.get_card("CSV9C", "161"))
	var hoothoot := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	player.active_pokemon = terapagos
	player.bench = [noctowl, rotom, hoothoot]
	var area_zero := CardInstance.create(CardDatabase.get_card("CSV9C", "207"), 0)
	var nest_ball := CardInstance.create(CardDatabase.get_card("CSVH1C", "043"), 0)
	var bench_basic := CardInstance.create(CardDatabase.get_card("CSV8C", "028"), 0)
	player.deck.append(bench_basic)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var attack := {
		"kind": "attack",
		"source_slot": terapagos,
		"attack_index": 0,
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var attack_score: float = strategy.call("score_action_absolute_with_plan", attack, state, 0, plan)
	var area_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_stadium",
		"card": area_zero,
		"productive": true,
	}, state, 0, plan)
	var nest_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": nest_ball,
		"productive": true,
	}, state, 0, plan)
	var bench_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_basic_to_bench",
		"card": bench_basic,
	}, state, 0, plan)
	return run_checks([
		assert_true(area_score > attack_score, "Area Zero should precede a non-KO Alliance Strike (area=%f attack=%f)" % [area_score, attack_score]),
		assert_true(nest_score > attack_score, "Nest Ball should extend the bench before a non-KO Alliance Strike (nest=%f attack=%f)" % [nest_score, attack_score]),
		assert_true(bench_score > attack_score, "A searched Basic should enter the bench before a non-KO Alliance Strike (bench=%f attack=%f)" % [bench_score, attack_score]),
	])


func test_v18_tord_does_not_force_fan_rotom_off_active_while_engine_debt_remains() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(24)
	var player := state.players[0]
	var fan_rotom_data := CardDatabase.get_card("CSV9C", "161")
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if fan_rotom_data == null or terapagos_data == null or crystal_data == null:
		return "Fan Rotom, Terapagos ex, and Sparkling Crystal should load from the bundled card pool"
	var fan_rotom := _make_slot(fan_rotom_data)
	var terapagos := _make_slot(terapagos_data)
	terapagos.attached_energy.append(CardInstance.create(_make_energy("Water Energy", "W"), 0))
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	player.active_pokemon = fan_rotom
	player.bench = [terapagos]
	var retreat_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": terapagos,
	}, state, 0)
	return assert_true(
		retreat_score < 4000.0,
		"Tord must not force Fan Rotom off Active while the Hoothoot/Noctowl setup debt remains (score=%f)" % retreat_score
	)


func test_v18_tord_attaches_to_a_stranded_active_to_unlock_a_ready_tera_attacker() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(24)
	var player := state.players[0]
	var pikachu_data := CardDatabase.get_card("CSV9C", "054")
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if pikachu_data == null or terapagos_data == null or crystal_data == null:
		return "Pikachu ex, Terapagos ex, and Sparkling Crystal should load from the bundled card pool"
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var pikachu := _make_slot(pikachu_data)
	var terapagos := _make_slot(terapagos_data)
	terapagos.attached_energy.append(CardInstance.create(_make_energy("Water Energy", "W"), 0))
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	player.active_pokemon = pikachu
	player.bench = [terapagos]
	var pivot_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": pikachu,
	}, state, 0)
	var ready_bench_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": terapagos,
	}, state, 0)
	return run_checks([
		assert_true(
			pivot_score >= 4000.0,
			"Tord should attach to a stranded Active when that pays retreat into a ready Tera attacker (score=%f)" % pivot_score
		),
		assert_true(
			pivot_score >= ready_bench_score + 1000.0,
			"The retreat-unlocking attachment must outrank overfeeding the already-ready Bench attacker (pivot=%f bench=%f)" % [pivot_score, ready_bench_score]
		),
	])


func test_v18_energy_switch_does_not_break_a_ready_attacker() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(30)
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if terapagos_data == null or crystal_data == null:
		return "Terapagos ex and Sparkling Crystal should load from the bundled card pool"
	var ditto := _make_slot(_make_basic_pokemon("百变怪", "C"))
	var terapagos := _make_slot(terapagos_data)
	terapagos.attached_energy.append(CardInstance.create(_make_energy("Grass Energy", "G"), 0))
	state.players[0].active_pokemon = ditto
	state.players[0].bench.append(terapagos)
	var energy_switch := CardInstance.create(_make_trainer("能量转移"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var near_ready_switch_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": energy_switch,
		"productive": true,
	}, state, 0, contract)
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	var ready_switch_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": energy_switch,
		"productive": true,
	}, state, 0, contract)
	return run_checks([
		assert_true(near_ready_switch_score <= -1800.0, "Energy Switch should be hard-blocked from trading a one-Energy Terapagos route for Ditto's 10 damage (score=%f)" % near_ready_switch_score),
		assert_true(ready_switch_score <= -1800.0, "Energy Switch should be hard-blocked when every move breaks the only ready attacker (score=%f)" % ready_switch_score),
	])


func test_v18_energy_switch_targets_the_highest_value_attack_route() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(30)
	var pikachu_data := CardDatabase.get_card("CSV9C", "054")
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if pikachu_data == null or terapagos_data == null or crystal_data == null:
		return "Pikachu ex, Terapagos ex, and Sparkling Crystal should load from the bundled card pool"
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var pikachu := _make_slot(pikachu_data)
	pikachu.attached_energy.append(grass)
	pikachu.attached_energy.append(CardInstance.create(_make_energy("Metal Energy", "M"), 0))
	var terapagos := _make_slot(terapagos_data)
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	var ditto := _make_slot(_make_basic_pokemon("百变怪", "C"))
	state.players[0].active_pokemon = pikachu
	state.players[0].bench.assign([terapagos, ditto])
	var context := {
		"game_state": state,
		"player_index": 0,
		"source_card": grass,
	}
	var step := {"id": "energy_assignment"}
	var terapagos_score: float = strategy.call("score_interaction_target", terapagos, step, context)
	var ditto_score: float = strategy.call("score_interaction_target", ditto, step, context)
	return assert_true(
		terapagos_score >= ditto_score + 300.0,
		"Energy Switch should move Grass Energy to crystal-ready Terapagos instead of Ditto (terapagos=%f ditto=%f)" % [terapagos_score, ditto_score]
	)


func test_v18_energy_switch_can_unlock_a_pivot_into_a_ready_bench_attacker() -> String:
	var strategy := _strategy_for_deck(800015934)
	var state := _make_scoring_state(30)
	var pikachu_data := CardDatabase.get_card("CSV9C", "054")
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if pikachu_data == null or terapagos_data == null or crystal_data == null:
		return "Pikachu ex, Terapagos ex, and Sparkling Crystal should load from the bundled card pool"
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var pikachu := _make_slot(pikachu_data)
	var terapagos := _make_slot(terapagos_data)
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	terapagos.attached_energy.append(grass)
	terapagos.attached_energy.append(CardInstance.create(_make_energy("Metal Energy", "M"), 0))
	var ditto := _make_slot(_make_basic_pokemon("百变怪", "C"))
	state.players[0].active_pokemon = pikachu
	state.players[0].bench.assign([terapagos, ditto])
	var context := {
		"game_state": state,
		"player_index": 0,
		"source_card": grass,
	}
	var step := {"id": "energy_assignment"}
	var pivot_score: float = strategy.call("score_interaction_target", pikachu, step, context)
	var ditto_score: float = strategy.call("score_interaction_target", ditto, step, context)
	return assert_true(
		pivot_score >= ditto_score + 300.0,
		"An extra Energy should pay the Active retreat cost and unlock a ready benched attacker before feeding Ditto (pivot=%f ditto=%f)" % [pivot_score, ditto_score]
	)


func test_v18_discard_search_does_not_replace_an_evolution_with_the_same_identity() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var yanmega_data := CardDatabase.get_card("CSV10C", "003")
	if yanmega_data == null:
		return "Yanmega ex should load from the bundled card pool"
	var discarded_yanmega := CardInstance.create(yanmega_data, 0)
	var searched_yanmega := CardInstance.create(yanmega_data, 0)
	var ultra_ball := CardInstance.create(_make_trainer("高级球"), 0)
	var action := {
		"kind": "play_trainer",
		"card": ultra_ball,
		"productive": true,
		"targets": [{
			"discard_cards": [discarded_yanmega, CardInstance.create(_make_trainer("巢穴球"), 0)],
			"search_pokemon": [searched_yanmega],
		}],
	}
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var score: float = strategy.call("score_action_absolute_with_plan", action, state, 0, contract)
	return assert_true(
		score <= -1800.0,
		"Discard-search should not throw away Yanmega ex merely to fetch another Yanmega ex (score=%f)" % score
	)


func test_v18_wrapper_preserves_delegate_continuity_rules() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(30)
	var gholdengo := _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×"))
	gholdengo.attached_energy.append(CardInstance.create(_make_energy("Metal Energy", "M"), 0))
	state.players[0].active_pokemon = gholdengo
	state.players[0].hand.append(CardInstance.create(_make_energy("Water Energy", "W"), 0))
	state.players[0].hand.append(CardInstance.create(_make_energy("Grass Energy", "G"), 0))
	state.players[0].hand.append(CardInstance.create(_make_trainer("Nest Ball"), 0))
	var turn_contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, turn_contract)
	var has_delegate_nest_rule := false
	for rule_variant: Variant in continuity.get("action_bonuses", []):
		if not rule_variant is Dictionary:
			continue
		var rule: Dictionary = rule_variant
		if "Nest Ball" in (rule.get("card_names", []) as Array):
			has_delegate_nest_rule = true
			break
	return assert_true(has_delegate_nest_rule, "The V18 wrapper must preserve delegate continuity bonuses for backup attacker setup")


func test_v18_pure_gholdengo_uses_a_dedicated_core_without_palkia_identity() -> String:
	var strategy := _strategy_for_deck(800016834)
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	var state := _make_scoring_state(30)
	state.players[0].active_pokemon = _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×"))
	var plan: Dictionary = delegate.call("build_turn_plan", state, 0, {}) if delegate != null else {}
	return run_checks([
		assert_not_null(delegate, "Pure Gholdengo should configure a dedicated delegate"),
		assert_eq(str(delegate.call("get_strategy_id")) if delegate != null else "", "v18_pure_gholdengo_core", "Pure Gholdengo must not resolve to the Palkia/Gholdengo identity"),
		assert_false(JSON.stringify(plan).to_lower().contains("palkia"), "Pure Gholdengo turn plans must not contain a phantom Palkia owner, bridge, or priority"),
	])


func test_v18_pure_gholdengo_two_lanes_clear_opening_and_palkia_debt() -> String:
	var strategy := _strategy_for_deck(800016834)
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	if delegate == null:
		return "Pure Gholdengo should configure a dedicated delegate"
	var state := _make_scoring_state(30)
	var player := state.players[0]
	player.active_pokemon = _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×"))
	var gimmighoul_data: CardData = CardDatabase.get_card("CSV9C", "096")
	player.bench.append(_make_slot(gimmighoul_data))
	var debt: Dictionary = delegate.call("_build_palkia_gholdengo_continuity_setup_debt", player, state, 0)
	return run_checks([
		assert_false(bool(delegate.call("_needs_opening_basics", player)), "Two Gholdengo lanes should satisfy the pure deck's opening floor"),
		assert_false(bool(debt.get("need_palkia_bridge", true)), "Pure Gholdengo must never carry Palkia bridge debt"),
		assert_false(bool(debt.get("need_backup_gholdengo_seed", true)), "An Active Gholdengo plus Bench Gimmighoul should satisfy backup-lane continuity"),
	])


func test_v18_pure_gholdengo_uses_ciphermaniac_before_its_draw_ability() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(20)
	var player := state.players[0]
	var gholdengo := _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×", [{"name": "嘉奖硬币", "text": "从自己的牌库抽取2张卡牌。"}]))
	player.active_pokemon = gholdengo
	player.bench.append(_make_slot(CardDatabase.get_card("CSV9C", "096")))
	var cipher_data := _make_trainer("暗码迷的解读")
	cipher_data.name_en = "Ciphermaniac's Codebreaking"
	var cipher := CardInstance.create(cipher_data, 0)
	player.hand.append(cipher)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var cipher_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": cipher, "productive": true,
	}, state, 0, contract)
	var ability_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability", "source_slot": gholdengo, "ability_index": 0,
	}, state, 0, contract)
	return assert_true(
		cipher_score >= ability_score + 1000.0,
		"Ciphermaniac must stack missing route pieces before Gholdengo consumes its draw ability (cipher=%f ability=%f)" % [cipher_score, ability_score]
	)


func test_v18_pure_gholdengo_ciphermaniac_stacks_metal_and_evolution_over_extra_seed() -> String:
	var strategy := _strategy_for_deck(800016834)
	var state := _make_scoring_state(20)
	var player := state.players[0]
	player.active_pokemon = _make_slot(_make_pokemon("赛富豪ex", "M", "M", "50×"))
	player.bench.append(_make_slot(CardDatabase.get_card("CSV9C", "096")))
	var metal := CardInstance.create(_make_energy("基本钢能量", "M"), 0)
	var second_metal := CardInstance.create(_make_energy("基本钢能量", "M"), 0)
	var evolution := CardInstance.create(_make_stage1_pokemon("赛富豪ex", "索财灵", "M", "M", "50×"), 0)
	evolution.card_data.name_en = "Gholdengo ex"
	var second_evolution := CardInstance.create(_make_stage1_pokemon("赛富豪ex", "索财灵", "M", "M", "50×"), 0)
	second_evolution.card_data.name_en = "Gholdengo ex"
	var extra_seed := CardInstance.create(CardDatabase.get_card("CSV9C", "096"), 0)
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "top_cards", "max_select": 2}
	var metal_score: float = strategy.call("score_interaction_target", metal, step, context)
	var evolution_score: float = strategy.call("score_interaction_target", evolution, step, context)
	var seed_score: float = strategy.call("score_interaction_target", extra_seed, step, context)
	var selected: Array = strategy.call(
		"pick_interaction_items",
		[metal, second_metal, evolution, second_evolution, extra_seed],
		step,
		context
	)
	var selected_metal := 0
	var selected_evolution := 0
	for card: CardInstance in selected:
		if card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "M":
			selected_metal += 1
		if card.card_data != null and str(card.card_data.name_en) == "Gholdengo ex":
			selected_evolution += 1
	return run_checks([
		assert_true(metal_score >= seed_score + 1000.0, "Ciphermaniac should stack the missing Metal Energy before a redundant third seed"),
		assert_true(evolution_score >= seed_score + 1000.0, "Ciphermaniac should stack the backup Gholdengo evolution before a redundant third seed"),
		assert_eq(selected.size(), 2, "Ciphermaniac should place exactly two cards on top when two are allowed"),
		assert_eq(selected_metal, 1, "Ciphermaniac should stack one Metal Energy rather than two copies of the same route role"),
		assert_eq(selected_evolution, 1, "Ciphermaniac should stack one Gholdengo evolution rather than two copies of the same route role"),
	])


func test_v18_ethans_ho_oh_uses_a_dedicated_fire_acceleration_core() -> String:
	var strategy := _strategy_for_deck(800018539)
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return run_checks([
		assert_not_null(delegate, "Ethan's Ho-Oh should configure a dedicated delegate"),
		assert_eq(
			str(delegate.call("get_strategy_id")) if delegate != null else "",
			"v18_ethans_ho_oh_core",
			"Ethan's Ho-Oh must use its own fire-acceleration identity"
		),
	])


func test_v18_ethans_ho_oh_preserves_fire_energy_for_golden_flame() -> String:
	var strategy := _strategy_for_deck(800018539)
	var fire := CardInstance.create(_make_energy("基本火能量", "R"), 0)
	var off_route := CardInstance.create(_make_basic_pokemon("Wellspring Mask Ogerpon ex", "W"), 0)
	return run_checks([
		assert_true(
			int(strategy.call("get_discard_priority", fire)) <= 10,
			"Basic Fire Energy should be protected while it is Golden Flame fuel"
		),
		assert_true(
			int(strategy.call("get_discard_priority", off_route)) >= 60,
			"Off-route one-of attackers should be discarded before Golden Flame fuel"
		),
	])


func test_v18_ethans_ho_oh_preserves_recovery_until_backup_attacker_exists() -> String:
	var strategy := _strategy_for_deck(800018539)
	var state := _make_scoring_state(24)
	state.players[0].active_pokemon = _make_slot(_make_basic_pokemon("阿响的凤王ex", "R"))
	state.players[0].deck.push_front(CardInstance.create(_make_basic_pokemon("阿响的凤王ex", "R"), 0))
	var super_rod := CardInstance.create(_make_trainer("Super Rod"), 0)
	var boss := CardInstance.create(_make_trainer("Boss's Orders"), 0)
	var step := {"id": "discard_cards", "min_select": 2, "max_select": 2}
	var context := {"game_state": state, "player_index": 0}
	var rod_score: float = strategy.call("score_interaction_target", super_rod, step, context)
	var boss_score: float = strategy.call("score_interaction_target", boss, step, context)
	return assert_true(
		boss_score >= rod_score + 1000.0,
		"The only recovery reserve must survive discard costs until a second Ho-Oh is established (rod=%f boss=%f)" % [rod_score, boss_score]
	)


func test_v18_ethans_ho_oh_routes_rainbow_energy_to_ho_oh_before_side_attackers() -> String:
	var strategy := _strategy_for_deck(800018539)
	var state := _make_scoring_state(30)
	var player := state.players[0]
	var side_attacker := _make_slot(_make_basic_pokemon("Wellspring Mask Ogerpon ex", "W"))
	var ho_oh := _make_slot(_make_basic_pokemon("阿响的凤王ex", "R"))
	player.active_pokemon = side_attacker
	player.bench.append(ho_oh)
	var rainbow := CardInstance.create(CardDatabase.get_card("CSV8C", "207"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var ho_oh_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": rainbow, "target_slot": ho_oh,
	}, state, 0, contract)
	var side_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": rainbow, "target_slot": side_attacker,
	}, state, 0, contract)
	return assert_true(
		ho_oh_score >= side_score + 1200.0,
		"Rainbow Energy should help Ho-Oh reach four Fire before funding a side attacker (ho_oh=%f side=%f)" % [ho_oh_score, side_score]
	)


func test_v18_ethans_ho_oh_blocks_armarouge_from_fueling_a_non_attacker() -> String:
	var strategy := _strategy_for_deck(800018539)
	var state := _make_scoring_state(30)
	var player := state.players[0]
	player.active_pokemon = _make_slot(_make_basic_pokemon("Squawkabilly ex", "C"))
	var ho_oh := _make_slot(_make_basic_pokemon("阿响的凤王ex", "R"))
	ho_oh.attached_energy.append(CardInstance.create(_make_energy("基本火能量", "R"), 0))
	var armarouge := _make_slot(_make_stage1_pokemon("红莲铠骑", "炭小侍", "R", "RC", "90"))
	player.bench = [ho_oh, armarouge]
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var move_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": armarouge,
		"ability_index": 0,
	}, state, 0, contract)
	return assert_true(
		move_score <= -1200.0,
		"Armarouge must not strip Fire Energy from a Ho-Oh just to power an active support Pokemon (score=%f)" % move_score
	)


func test_v18_ethans_ho_oh_armarouge_moves_fire_to_an_active_ho_oh_route() -> String:
	var strategy := _strategy_for_deck(800018539)
	var state := _make_scoring_state(30)
	var player := state.players[0]
	var active_ho_oh := _make_slot(_make_basic_pokemon("阿响的凤王ex", "R"))
	active_ho_oh.get_card_data().attacks = [{"name": "Shining Feather", "cost": "RRRR", "damage": "160"}]
	for _index: int in 3:
		active_ho_oh.attached_energy.append(CardInstance.create(_make_energy("基本火能量", "R"), 0))
	player.active_pokemon = active_ho_oh
	var source := _make_slot(_make_basic_pokemon("阿响的凤王ex", "R"))
	source.attached_energy.append(CardInstance.create(_make_energy("基本火能量", "R"), 0))
	var armarouge := _make_slot(_make_stage1_pokemon("红莲铠骑", "炭小侍", "R", "RC", "90"))
	player.bench = [source, armarouge]
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var move_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": armarouge,
		"ability_index": 0,
	}, state, 0, contract)
	return assert_true(
		move_score >= 2500.0,
		"Armarouge should complete an active Ho-Oh's four-Fire attack route (score=%f)" % move_score
	)


func test_v18_mamoswine_blaziken_keeps_the_shared_stage2_chain_core() -> String:
	var strategy := _strategy_for_deck(800017047)
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return run_checks([
		assert_not_null(delegate, "Mamoswine/Blaziken should configure the remaining shared Stage 2 delegate"),
		assert_eq(
			str(delegate.call("get_strategy_id")) if delegate != null else "",
			"v18_stage2_core_800017047",
			"Mamoswine/Blaziken should retain its deck-scoped shared-core identity"
		),
	])


func test_v18_stage2_core_searches_the_playable_middle_stage_before_a_dead_stage2() -> String:
	var strategy := _strategy_for_deck(800017047)
	var deck := _load_deck(800017047)
	if deck == null:
		return assert_true(false, "The Mamoswine/Blaziken deck should load")
	var deck_counts := _deck_card_counts(deck)
	if not deck_counts.has("CSV7C_036") or not deck_counts.has("CSV7C_037") or not deck_counts.has("CSV7C_038"):
		return assert_true(false, "The Mamoswine/Blaziken deck should contain its real Torchic evolution line")
	var state := _make_scoring_state(30)
	var player := state.players[0]
	player.active_pokemon = _make_slot(CardDatabase.get_card("CSV7C", "036"))
	var middle := CardInstance.create(CardDatabase.get_card("CSV7C", "037"), 0)
	var stage2 := CardInstance.create(CardDatabase.get_card("CSV7C", "038"), 0)
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "search_pokemon", "max_select": 1}
	var middle_score: float = strategy.call("score_interaction_target", middle, step, context)
	var stage2_score: float = strategy.call("score_interaction_target", stage2, step, context)
	return assert_true(
		middle_score >= stage2_score + 500.0,
		"A live Torchic should search Combusken before an immediately dead Blaziken ex (middle=%f stage2=%f)" % [middle_score, stage2_score]
	)


func test_v18_stage2_core_protects_middle_stages_from_generic_discard() -> String:
	var strategy := _strategy_for_deck(800017047)
	var deck := _load_deck(800017047)
	if deck == null:
		return assert_true(false, "The Mamoswine/Blaziken deck should load")
	var deck_counts := _deck_card_counts(deck)
	if not deck_counts.has("CSV7C_037") or not deck_counts.has("CSV8C_135"):
		return assert_true(false, "The Mamoswine/Blaziken deck should contain Combusken and Fezandipiti ex")
	var middle := CardInstance.create(CardDatabase.get_card("CSV7C", "037"), 0)
	var off_route := CardInstance.create(CardDatabase.get_card("CSV8C", "135"), 0)
	return run_checks([
		assert_true(
			int(strategy.call("get_discard_priority", middle)) <= 15,
			"The only bridge into a Stage 2 attacker should be protected from generic discard"
		),
		assert_true(
			int(strategy.call("get_discard_priority", off_route)) > int(strategy.call("get_discard_priority", middle)),
			"A support Basic should be discarded before the required Stage 1 bridge"
		),
	])


func test_v18_stage2_core_acceleration_targets_the_advanced_attack_route() -> String:
	var strategy := _strategy_for_deck(800017047)
	var deck := _load_deck(800017047)
	if deck == null:
		return assert_true(false, "The Mamoswine/Blaziken deck should load")
	var deck_counts := _deck_card_counts(deck)
	if not deck_counts.has("CSV10C_104") or not deck_counts.has("CSV8C_135"):
		return assert_true(false, "The Mamoswine/Blaziken deck should contain Mamoswine ex and Fezandipiti ex")
	var state := _make_scoring_state(30)
	var player := state.players[0]
	var mamoswine := _make_slot(CardDatabase.get_card("CSV10C", "104"))
	var support := _make_slot(CardDatabase.get_card("CSV8C", "135"))
	player.active_pokemon = support
	player.bench.append(mamoswine)
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "attach_basic_energy_from_discard", "max_select": 1}
	var mamoswine_score: float = strategy.call("score_interaction_target", mamoswine, step, context)
	var support_score: float = strategy.call("score_interaction_target", support, step, context)
	return assert_true(
		mamoswine_score >= support_score + 1000.0,
		"Stage 2 acceleration should fund Mamoswine ex before a support Pokemon (stage2=%f support=%f)" % [mamoswine_score, support_score]
	)


func test_v18_gardevoir_preserves_its_only_ralts_behind_a_low_retreat_pivot() -> String:
	var strategy := _strategy_for_deck(800018497)
	var player := PlayerState.new()
	var ralts: CardData = CardDatabase.get_card("CSV2C", "053")
	var munkidori: CardData = CardDatabase.get_card("CSV8C", "094")
	var clefairy: CardData = CardDatabase.get_card("CSV10C", "082")
	if ralts == null or munkidori == null or clefairy == null:
		return assert_true(false, "The V18 Gardevoir opening cards should load")
	player.hand = [
		CardInstance.create(ralts, 0),
		CardInstance.create(munkidori, 0),
		CardInstance.create(clefairy, 0),
	]
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active_index: int = int(plan.get("active_hand_index", -1))
	var bench_indices: Array = plan.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(active_index, 1, "A one-Ralts V18 Gardevoir hand should use Munkidori as its low-retreat Active pivot"),
		assert_true(0 in bench_indices, "The only Ralts must remain on the Bench so it can evolve without trapping Gardevoir Active"),
	])


func test_v18_gardevoir_strong_openings_declare_the_turn_three_candy_route() -> String:
	var registry_script: GDScript = load(FIXED_ORDER_REGISTRY_PATH)
	var registry: RefCounted = registry_script.new()
	var checks: Array[String] = []
	for deck_id: int in [800017097, 800018105, 800018497, 800018498]:
		var order: Array[Dictionary] = registry.call("load_fixed_order", deck_id)
		var opening_names: Array[String] = []
		var opening_psychic_count := 0
		for index: int in mini(7, order.size()):
			var entry: Dictionary = order[index]
			var card: CardData = CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
			opening_names.append(str(card.name_en) if card != null and str(card.name_en) != "" else str(card.name) if card != null else "")
			if card != null and str(card.name_en) == "Psychic Energy":
				opening_psychic_count += 1
		var first_bridge: CardData = null
		var second_bridge: CardData = null
		var third_bridge: CardData = null
		if order.size() > 13:
			first_bridge = CardDatabase.get_card(str(order[13].get("set_code", "")), str(order[13].get("card_index", "")))
		if order.size() > 14:
			second_bridge = CardDatabase.get_card(str(order[14].get("set_code", "")), str(order[14].get("card_index", "")))
		if order.size() > 15:
			third_bridge = CardDatabase.get_card(str(order[15].get("set_code", "")), str(order[15].get("card_index", "")))
		checks.append(assert_true("Ralts" in opening_names, "V18 Gardevoir %d should expose its only evolution seed" % deck_id))
		checks.append(assert_true("Munkidori" in opening_names, "V18 Gardevoir %d should expose a one-retreat pivot" % deck_id))
		checks.append(assert_true("Scream Tail" in opening_names, "V18 Gardevoir %d should expose its first one-prize attacker" % deck_id))
		checks.append(assert_true("Gardevoir ex" in opening_names, "V18 Gardevoir %d should hold its Stage 2 before any deck shuffle" % deck_id))
		checks.append(assert_true("Rare Candy" in opening_names, "V18 Gardevoir %d should hold Rare Candy before any deck shuffle" % deck_id))
		checks.append(assert_eq(opening_psychic_count, 2, "V18 Gardevoir %d should expose one retreat fuel and one manual attacker attachment" % deck_id))
		checks.append(assert_eq(str(first_bridge.name_en) if first_bridge != null else "", "Bravery Charm", "V18 Gardevoir %d should draw Scream Tail protection before the launch" % deck_id))
		checks.append(assert_eq(str(second_bridge.name_en) if second_bridge != null else "", "Psychic Energy", "V18 Gardevoir %d should draw deterministic turn-three energy without searching" % deck_id))
		checks.append(assert_eq(str(third_bridge.name_en) if third_bridge != null else "", "Artazon", "V18 Gardevoir %d should preserve its first post-launch Stadium route" % deck_id))
	return run_checks(checks)


func test_v18_gardevoir_candy_route_precharges_the_active_pivot() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_scoring_state(1)
	var player := state.players[0]
	var munkidori := _make_slot(CardDatabase.get_card("CSV8C", "094"))
	var scream_tail := _make_slot(CardDatabase.get_card("CSV6C", "065"))
	var gardevoir: CardData = CardDatabase.get_card("CSV2C", "055")
	var rare_candy: CardData = CardDatabase.get_card("CSVH1C", "045")
	var psychic: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	if munkidori == null or scream_tail == null or gardevoir == null or rare_candy == null or psychic == null:
		return assert_true(false, "The V18 Gardevoir deterministic Candy route cards should load")
	player.active_pokemon = munkidori
	player.bench = [scream_tail]
	player.hand = [
		CardInstance.create(gardevoir, 0),
		CardInstance.create(rare_candy, 0),
	]
	var energy := CardInstance.create(psychic, 0)
	var active_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": energy, "target_slot": munkidori}, state, 0)
	var attacker_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": energy, "target_slot": scream_tail}, state, 0)
	return assert_true(
		active_score >= attacker_score + 1000.0,
		"The deterministic Candy route must discard its first Psychic by retreating the Active pivot (active=%f attacker=%f)" % [active_score, attacker_score]
	)


func test_v18_gardevoir_candy_route_attaches_bravery_charm_to_scream_tail() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_scoring_state(1)
	var player := state.players[0]
	var munkidori := _make_slot(CardDatabase.get_card("CSV8C", "094"))
	var scream_tail := _make_slot(CardDatabase.get_card("CSV6C", "065"))
	var gardevoir: CardData = CardDatabase.get_card("CSV2C", "055")
	var rare_candy: CardData = CardDatabase.get_card("CSVH1C", "045")
	var bravery_charm: CardData = CardDatabase.get_card("CSV1C", "118")
	if munkidori == null or scream_tail == null or gardevoir == null or rare_candy == null or bravery_charm == null:
		return assert_true(false, "The V18 Gardevoir Charm launch cards should load")
	player.active_pokemon = scream_tail
	player.bench = [munkidori]
	player.hand = [
		CardInstance.create(gardevoir, 0),
		CardInstance.create(rare_candy, 0),
	]
	var charm := CardInstance.create(bravery_charm, 0)
	var attacker_score: float = strategy.call("score_action_absolute", {"kind": "attach_tool", "card": charm, "target_slot": scream_tail}, state, 0)
	var pivot_score: float = strategy.call("score_action_absolute", {"kind": "attach_tool", "card": charm, "target_slot": munkidori}, state, 0)
	return assert_true(
		attacker_score >= pivot_score + 1000.0,
		"The launch Charm must protect Scream Tail instead of the spent retreat pivot (attacker=%f pivot=%f)" % [attacker_score, pivot_score]
	)


func test_v18_gardevoir_candy_route_retreats_into_scream_tail() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_scoring_state(1)
	var player := state.players[0]
	var munkidori := _make_slot(CardDatabase.get_card("CSV8C", "094"))
	var scream_tail := _make_slot(CardDatabase.get_card("CSV6C", "065"))
	var ralts := _make_slot(CardDatabase.get_card("CSV2C", "053"))
	var gardevoir: CardData = CardDatabase.get_card("CSV2C", "055")
	var rare_candy: CardData = CardDatabase.get_card("CSVH1C", "045")
	var psychic: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	if munkidori == null or scream_tail == null or ralts == null or gardevoir == null or rare_candy == null or psychic == null:
		return assert_true(false, "The V18 Gardevoir retreat handoff cards should load")
	munkidori.attached_energy = [CardInstance.create(psychic, 0)]
	player.active_pokemon = munkidori
	player.bench = [ralts, scream_tail]
	player.hand = [
		CardInstance.create(gardevoir, 0),
		CardInstance.create(rare_candy, 0),
	]
	var attacker_score: float = strategy.call("score_action_absolute", {"kind": "retreat", "bench_target": scream_tail}, state, 0)
	var seed_score: float = strategy.call("score_action_absolute", {"kind": "retreat", "bench_target": ralts}, state, 0)
	return assert_true(
		attacker_score >= seed_score + 1000.0,
		"The launch retreat must hand Active to Scream Tail without trapping the only Ralts seed (attacker=%f seed=%f)" % [attacker_score, seed_score]
	)


func test_v18_gardevoir_recovers_when_the_only_ralts_is_gusted_before_candy() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var gardevoir := _make_slot(CardDatabase.get_card("CSV2C", "055"))
	var scream_tail := _make_slot(CardDatabase.get_card("CSV6C", "065"))
	var munkidori := _make_slot(CardDatabase.get_card("CSV8C", "094"))
	var psychic: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	if gardevoir == null or scream_tail == null or munkidori == null or psychic == null:
		return assert_true(false, "The V18 Gardevoir gust recovery cards should load")
	player.active_pokemon = gardevoir
	player.bench = [scream_tail, munkidori]
	player.discard_pile = [CardInstance.create(psychic, 0)]
	var manual_energy := CardInstance.create(psychic, 0)
	player.hand = [manual_energy]
	var engine_attach_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": manual_energy, "target_slot": gardevoir}, state, 0)
	var attacker_attach_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": manual_energy, "target_slot": scream_tail}, state, 0)

	gardevoir.attached_energy = [manual_energy]
	player.hand = []
	var context := {"game_state": state, "player_index": 0, "all_items": [gardevoir, scream_tail]}
	var embrace_pick: Array = strategy.call("pick_interaction_items", [gardevoir, scream_tail], {"id": "embrace_target", "max_select": 1}, context)

	gardevoir.attached_energy.append(CardInstance.create(psychic, 0))
	player.discard_pile = []
	var turn_contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var retreat_energy: Array[CardInstance] = gardevoir.attached_energy.duplicate()
	var attacker_retreat_score: float = strategy.call("score_action_absolute_with_plan", {"kind": "retreat", "bench_target": scream_tail, "energy_to_discard": retreat_energy, "productive": true}, state, 0, turn_contract)
	var support_retreat_score: float = strategy.call("score_action_absolute_with_plan", {"kind": "retreat", "bench_target": munkidori, "energy_to_discard": retreat_energy, "productive": true}, state, 0, turn_contract)
	return run_checks([
		assert_true(
			engine_attach_score >= attacker_attach_score + 1000.0,
			"A gusted Active Gardevoir must receive the manual retreat attachment before its Bench attacker (engine=%f attacker=%f)" % [engine_attach_score, attacker_attach_score]
		),
		assert_true(not embrace_pick.is_empty() and embrace_pick[0] == gardevoir, "Psychic Embrace must finish funding the gusted Active Gardevoir's retreat"),
		assert_true(
			attacker_retreat_score >= 1000.0 and attacker_retreat_score >= support_retreat_score + 1000.0,
			"After funding retreat, Gardevoir must hand Active to Scream Tail so the discarded Energy can rebuild it (attacker=%f support=%f)" % [attacker_retreat_score, support_retreat_score]
		),
	])


func test_v18_gardevoir_secret_box_search_preserves_the_candy_charm_combo() -> String:
	var strategy := _strategy_for_deck(800018497)
	var secret_box := CardInstance.create(CardDatabase.get_card("CSV8C", "176"), 0)
	var rare_candy := CardInstance.create(CardDatabase.get_card("CSVH1C", "045"), 0)
	var ultra_ball := CardInstance.create(CardDatabase.get_card("CSV1C", "112"), 0)
	var bravery_charm := CardInstance.create(CardDatabase.get_card("CSV1C", "118"), 0)
	var tm_evolution := CardInstance.create(CardDatabase.get_card("CSV5C", "119"), 0)
	var boss := CardInstance.create(CardDatabase.get_card("CSVH1aC", "023"), 0)
	var research := CardInstance.create(CardDatabase.get_card("CSV1C", "121"), 0)
	var artazon := CardInstance.create(CardDatabase.get_card("CSV2C", "127"), 0)
	var context := {"pending_effect_card": secret_box}
	var item_pick: Array = strategy.call("pick_interaction_items", [ultra_ball, rare_candy], {"id": "search_item", "max_select": 1}, context)
	var tool_pick: Array = strategy.call("pick_interaction_items", [tm_evolution, bravery_charm], {"id": "search_tool", "max_select": 1}, context)
	var supporter_pick: Array = strategy.call("pick_interaction_items", [research, boss], {"id": "search_supporter", "max_select": 1}, context)
	var stadium_pick: Array = strategy.call("pick_interaction_items", [artazon], {"id": "search_stadium", "max_select": 1}, context)
	return run_checks([
		assert_true(not item_pick.is_empty() and item_pick[0] == rare_candy, "Secret Box should search Rare Candy instead of opening extra discard churn"),
		assert_true(not tool_pick.is_empty() and tool_pick[0] == bravery_charm, "Secret Box should search Bravery Charm instead of diverting into TM Evolution"),
		assert_true(not supporter_pick.is_empty() and supporter_pick[0] == boss, "Secret Box should preserve the combo with a non-hand-reset Supporter"),
		assert_true(not stadium_pick.is_empty() and stadium_pick[0] == artazon, "Secret Box should keep the declared Artazon Stadium route"),
	])


func test_v18_gardevoir_precharges_gust_insurance_after_its_attacker_is_ready() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_scoring_state(3)
	var player := state.players[0]
	var scream_tail := _make_slot(CardDatabase.get_card("CSV6C", "065"))
	var gardevoir := _make_slot(CardDatabase.get_card("CSV2C", "055"))
	var psychic: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	if scream_tail == null or gardevoir == null or psychic == null:
		return assert_true(false, "The V18 Gardevoir continuity cards should load")
	player.active_pokemon = scream_tail
	player.bench = [gardevoir]
	scream_tail.attached_energy = [
		CardInstance.create(psychic, 0),
		CardInstance.create(psychic, 0),
	]
	scream_tail.damage_counters = 20
	var step := {"id": "embrace_target"}
	var context := {"game_state": state, "player_index": 0, "all_items": [scream_tail, gardevoir]}
	var attacker_score: float = strategy.call("score_interaction_target", scream_tail, step, context)
	var engine_score: float = strategy.call("score_interaction_target", gardevoir, step, context)
	var picked: Array = strategy.call("pick_interaction_items", [scream_tail, gardevoir], step, context)
	return run_checks([
		assert_true(
			engine_score >= attacker_score + 100.0,
			"Once Scream Tail can attack, Gardevoir gust insurance should outrank extra attacker damage (engine=%f attacker=%f)" % [engine_score, attacker_score]
		),
		assert_true(not picked.is_empty() and picked[0] == gardevoir, "The V18 wrapper must preserve the delegate's final Psychic Embrace target choice"),
	])


func test_v18_yanmega_opening_keeps_yanma_on_the_bench_for_buzzing_rush() -> String:
	var strategy := _strategy_for_deck(800033475)
	var player := PlayerState.new()
	player.hand = [
		CardInstance.create(_make_basic_pokemon("蜻蜻蜓", "G"), 0),
		CardInstance.create(_make_basic_pokemon("含羞苞", "G"), 0),
		CardInstance.create(_make_basic_pokemon("土龙弟弟", "C"), 0),
	]
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var bench_indices: Array = plan.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 1, "Yanmega should open with Budew as the pivot when available"),
		assert_true(0 in bench_indices, "Yanma must start on the Bench so evolved Yanmega can enter Active and trigger Buzzing Rush"),
	])


func test_v18_yanmega_card_cost_requires_one_manual_attachment_after_acceleration() -> String:
	var yanmega: CardData = CardDatabase.get_card("CSV10C", "003")
	return run_checks([
		assert_not_null(yanmega, "The V18 Yanmega card should load"),
		assert_eq(
			str(yanmega.attacks[0].get("cost", "")) if yanmega != null and not yanmega.attacks.is_empty() else "",
			"GGGC",
			"Buzzing Rush supplies three Grass Energy; Jet Cyclone still requires one additional attachment"
		),
	])


func test_v18_yanmega_prioritizes_bench_evolution_and_handoff_over_active_evolution() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var active_yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	var bench_yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	state.players[0].active_pokemon = active_yanma
	state.players[0].bench.append(bench_yanma)
	var yanmega := CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var active_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "evolve",
		"card": yanmega,
		"target_slot": active_yanma,
	}, state, 0, contract)
	var bench_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "evolve",
		"card": yanmega,
		"target_slot": bench_yanma,
	}, state, 0, contract)
	bench_yanma.pokemon_stack.append(yanmega)
	var handoff_score: float = strategy.call("score_handoff_target", bench_yanma, {"id": "self_switch_target"}, {"game_state": state, "player_index": 0})
	var support_score: float = strategy.call("score_handoff_target", active_yanma, {"id": "self_switch_target"}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(bench_score >= active_score + 500.0, "Yanmega should evolve on the Bench to preserve its enter-Active trigger"),
		assert_true(handoff_score >= support_score + 500.0, "An evolved Bench Yanmega should be the dominant switch target"),
	])


func test_v18_yanmega_establishes_and_funds_its_backup_before_the_first_attack() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var active_yanmega := _make_slot(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"))
	for _index: int in 4:
		active_yanmega.attached_energy.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	var bench_yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	var dunsparce := _make_slot(_make_basic_pokemon("土龙弟弟", "C"))
	state.players[0].active_pokemon = active_yanmega
	state.players[0].bench.assign([bench_yanma, dunsparce])
	var backup_yanmega := CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var evolve_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "evolve",
		"card": backup_yanmega,
		"target_slot": bench_yanma,
	}, state, 0, contract)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": active_yanmega,
		"attack_index": 0,
		"projected_damage": 210,
	}, state, 0, contract)
	bench_yanma.pokemon_stack.append(backup_yanmega)
	var backup_transfer_score: float = strategy.call("score_interaction_target", bench_yanma, {"id": "move_energy_target"}, {"game_state": state, "player_index": 0})
	var support_transfer_score: float = strategy.call("score_interaction_target", dunsparce, {"id": "move_energy_target"}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(evolve_score >= attack_score + 300.0, "Yanmega should establish its second attacker before taking the first 210-damage attack (evolve=%f attack=%f)" % [evolve_score, attack_score]),
		assert_true(backup_transfer_score >= support_transfer_score + 1000.0, "Jet Cyclone should transfer its three Energy to the backup Yanmega instead of a support Pokemon"),
	])


func test_v18_yanmega_attaches_tm_evolution_to_the_powered_active_pivot() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var budew := _make_slot(_make_basic_pokemon("含羞苞", "G"))
	budew.attached_energy.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	var yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	state.players[0].active_pokemon = budew
	state.players[0].bench.append(yanma)
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	var tm_data := _make_trainer("招式学习器 进化")
	tm_data.card_type = "Tool"
	var tm := CardInstance.create(tm_data, 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var active_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool",
		"card": tm,
		"target_slot": budew,
	}, state, 0, contract)
	var bench_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool",
		"card": tm,
		"target_slot": yanma,
	}, state, 0, contract)
	return assert_true(
		active_score >= bench_score + 2000.0,
		"TM Evolution must attach to the powered Active pivot that can declare the attack this turn (active=%f bench=%f)" % [active_score, bench_score]
	)


func test_v18_yanmega_powers_and_preserves_the_active_tm_evolution_carrier() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	state.turn_number = 1
	state.first_player_index = 0
	var budew := _make_slot(_make_basic_pokemon("含羞苞", "G"))
	var tm_data := _make_trainer("招式学习器 进化")
	tm_data.card_type = "Tool"
	budew.attached_tool = CardInstance.create(tm_data, 0)
	var yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	state.players[0].active_pokemon = budew
	state.players[0].bench.assign([yanma, _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))])
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	var grass := CardInstance.create(_make_energy("基本草能量", "G"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var active_energy_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": budew,
	}, state, 0, contract)
	var bench_energy_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": yanma,
	}, state, 0, contract)
	budew.attached_energy.append(grass)
	var retreat_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": yanma,
		"energy_to_discard": [],
	}, state, 0, contract)
	return run_checks([
		assert_true(active_energy_score >= bench_energy_score + 2000.0, "The Active TM carrier must receive the Colorless attack cost before Yanma is funded (active=%f bench=%f)" % [active_energy_score, bench_energy_score]),
		assert_true(retreat_score <= -1800.0, "The TM carrier must not retreat before declaring Evolution, including a first-player turn where attacking is not yet legal (retreat=%f)" % retreat_score),
	])


func test_v18_yanmega_hands_off_after_tm_builds_the_first_bench_attacker() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var carrier := _make_slot(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"))
	var tm_data := _make_trainer("招式学习器 进化")
	tm_data.card_type = "Tool"
	carrier.attached_tool = CardInstance.create(tm_data, 0)
	carrier.attached_energy.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	var ready_handoff := _make_slot(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"))
	var remaining_seed := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	state.players[0].active_pokemon = carrier
	state.players[0].bench.assign([ready_handoff, remaining_seed])
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": ready_handoff,
		"energy_to_discard": [carrier.attached_energy[0]],
	}, state, 0, contract)
	return assert_true(
		retreat_score >= 500.0,
		"Once TM Evolution has built a Bench Yanmega, the pivot must hand off instead of blocking the Buzzing Rush trigger (score=%f)" % retreat_score
	)


func test_v18_yanmega_first_player_defers_tm_until_it_can_attack() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	state.turn_number = 1
	state.first_player_index = 0
	var budew := _make_slot(_make_basic_pokemon("含羞苞", "G"))
	var funded_yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	var plain_yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	state.players[0].active_pokemon = budew
	state.players[0].bench.assign([funded_yanma, plain_yanma])
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	var tm_data := _make_trainer("招式学习器 进化")
	tm_data.card_type = "Tool"
	var tm := CardInstance.create(tm_data, 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var active_tool_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": budew,
	}, state, 0, contract)
	var bench_tool_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": funded_yanma,
	}, state, 0, contract)
	var grass := CardInstance.create(_make_energy("基本草能量", "G"), 0)
	var budew_energy_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": grass, "target_slot": budew,
	}, state, 0, contract)
	var yanma_energy_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": grass, "target_slot": funded_yanma,
	}, state, 0, contract)
	return run_checks([
		assert_true(active_tool_score <= -1800.0, "A first player must not expose its single-use TM on Active Budew before attacking is legal (score=%f)" % active_tool_score),
		assert_true(bench_tool_score <= -1800.0, "A first player must not preload TM on a Bench Yanma that can be gusted and Knocked Out (score=%f)" % bench_tool_score),
		assert_true(yanma_energy_score >= budew_energy_score + 500.0, "The attack-locked first turn should still fund a Yanma while preserving TM in hand (yanma=%f budew=%f)" % [yanma_energy_score, budew_energy_score]),
	])


func test_v18_yanmega_tm_evolution_attack_outranks_opening_chip_and_end_turn() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var budew := _make_slot(_make_basic_pokemon("含羞苞", "G"))
	budew.attached_energy.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	state.players[0].active_pokemon = budew
	state.players[0].bench.assign([
		_make_slot(_make_basic_pokemon("蜻蜻蜓", "G")),
		_make_slot(_make_basic_pokemon("蜻蜻蜓", "G")),
	])
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var tm_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "granted_attack",
		"source_slot": budew,
		"granted_attack_data": {"id": "tm_evolution", "name": "进化", "cost": "C", "damage": ""},
	}, state, 0, contract)
	var chip_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": budew,
		"attack_index": 0,
		"projected_damage": 10,
	}, state, 0, contract)
	var end_score: float = strategy.call("score_action_absolute_with_plan", {"kind": "end_turn"}, state, 0, contract)
	return run_checks([
		assert_true(tm_score >= chip_score + 3000.0, "TM Evolution must replace Budew's chip attack while two Yanma can evolve (tm=%f chip=%f)" % [tm_score, chip_score]),
		assert_true(tm_score >= end_score + 3000.0, "TM Evolution must be terminally preferred over ending the setup turn (tm=%f end=%f)" % [tm_score, end_score]),
	])


func test_v18_yanmega_establishes_the_second_seed_before_using_tm_evolution() -> String:
	var strategy := _strategy_for_deck(800033475)
	var state := _make_scoring_state(30)
	var budew := _make_slot(_make_basic_pokemon("含羞苞", "G"))
	budew.attached_energy.append(CardInstance.create(_make_energy("基本草能量", "G"), 0))
	state.players[0].active_pokemon = budew
	state.players[0].bench.append(_make_slot(_make_basic_pokemon("蜻蜻蜓", "G")))
	state.players[0].deck.push_front(CardInstance.create(_make_basic_pokemon("蜻蜻蜓", "G"), 0))
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	state.players[0].deck.push_front(CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0))
	var poffin := CardInstance.create(_make_trainer("友好宝芬"), 0)
	state.players[0].hand.append(poffin)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var poffin_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": poffin,
		"productive": true,
	}, state, 0, contract)
	var tm_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "granted_attack",
		"source_slot": budew,
		"granted_attack_data": {"id": "tm_evolution", "name": "进化", "cost": "C", "damage": ""},
	}, state, 0, contract)
	return assert_true(
		poffin_score >= tm_score + 500.0,
		"Yanmega must use Poffin to establish its second seed before the terminal TM Evolution attack (poffin=%f tm=%f)" % [poffin_score, tm_score]
	)


func test_v18_yanmega_tm_evolution_interaction_selects_yanma_and_yanmega() -> String:
	var strategy := _strategy_for_deck(800033475)
	var yanma := _make_slot(_make_basic_pokemon("蜻蜻蜓", "G"))
	var dunsparce := _make_slot(_make_basic_pokemon("土龙弟弟", "C"))
	var yanmega := CardInstance.create(_make_stage1_pokemon("远古巨蜓ex", "蜻蜻蜓", "G", "GGGC", "210"), 0)
	var dudunsparce := CardInstance.create(_make_stage1_pokemon("土龙节节", "土龙弟弟", "C", "C", "30"), 0)
	var yanma_score: float = strategy.call("score_interaction_target", yanma, {"id": "evolution_bench"}, {})
	var dunsparce_score: float = strategy.call("score_interaction_target", dunsparce, {"id": "evolution_bench"}, {})
	var yanmega_score: float = strategy.call("score_interaction_target", yanmega, {"id": "evolution_cards"}, {})
	var dudunsparce_score: float = strategy.call("score_interaction_target", dudunsparce, {"id": "evolution_cards"}, {})
	return run_checks([
		assert_true(yanma_score >= dunsparce_score + 1000.0, "TM Evolution should select Yanma before support evolution targets"),
		assert_true(yanmega_score >= dudunsparce_score + 300.0, "TM Evolution should fetch Yanmega ex before support evolutions"),
	])


func test_v18_raging_bolt_bellowing_thunder_selects_enough_field_energy_for_knockout() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_bolt := _make_slot(_make_basic_pokemon("Raging Bolt ex", "N"))
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var fighting := CardInstance.create(_make_energy("Fighting Energy", "F"), 0)
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	raging_bolt.attached_energy.assign([lightning, fighting])
	var ogerpon := _make_slot(_make_basic_pokemon("Teal Mask Ogerpon ex", "G"))
	ogerpon.attached_energy.append(grass)
	state.players[0].active_pokemon = raging_bolt
	state.players[0].bench.append(ogerpon)
	var defender := _make_slot(_make_basic_pokemon("Defender", "L"))
	defender.get_top_card().card_data.hp = 220
	defender.damage_counters = 20
	state.players[1].active_pokemon = defender
	var picked: Array = strategy.call("pick_interaction_items", [lightning, fighting, grass], {
		"id": "discard_basic_energy",
		"min_select": 0,
		"max_select": 3,
	}, {
		"game_state": state,
		"player_index": 0,
		"pending_effect_kind": "attack",
		"pending_effect_slot": raging_bolt,
	})
	return run_checks([
		assert_eq(picked.size(), 3, "Bellowing Thunder should discard three Energy to cover 200 remaining HP"),
		assert_true(grass in picked, "Bellowing Thunder should consume Ogerpon Grass fuel before its LF core"),
	])


func test_v18_raging_bolt_rejects_bellowing_thunder_without_expendable_fuel() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.hp = 240
	raging_data.effect_id = "e96bb407c5f18bb9eec55487e70395fd"
	raging_data.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": ""},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.assign([
		CardInstance.create(_make_energy("Lightning Energy", "L"), 0),
		CardInstance.create(_make_energy("Fighting Energy", "F"), 0),
	])
	state.players[0].active_pokemon = raging_bolt
	var defender := _make_slot(_make_basic_pokemon("Defender", "L"))
	defender.get_top_card().card_data.hp = 280
	state.players[1].active_pokemon = defender
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": raging_bolt,
		"attack_index": 1,
		"attack_name": "Bellowing Thunder",
		"projected_damage": 0,
		"projected_knockout": false,
	}, state, 0, contract)
	return assert_true(
		score <= -500.0,
		"Bellowing Thunder must be rejected when the only field Energy is the protected LF attack core (score=%f)" % score
	)


func test_v18_raging_bolt_preserves_next_turn_core_instead_of_bursting_roar() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.hp = 240
	raging_data.attacks = [
		{
			"name": "Bursting Roar",
			"cost": "C",
			"damage": "",
			"text": "Discard your hand and draw 6 cards.",
		},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	state.players[0].active_pokemon = raging_bolt
	state.players[0].hand.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var roar_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": raging_bolt,
		"attack_index": 0,
		"attack_name": "Bursting Roar",
		"attack_data": raging_data.attacks[0],
		"projected_damage": 0,
		"projected_knockout": false,
	}, state, 0, contract)
	var end_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "end_turn",
	}, state, 0, contract)
	return assert_true(
		roar_score <= end_score - 300.0,
		"Bursting Roar must not discard the Fighting Energy that completes next turn's LF core (roar=%f end=%f)" % [roar_score, end_score]
	)


func test_v18_raging_bolt_energy_switch_rejects_support_chip_route() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.attacks = [
		{"name": "Bursting Roar", "cost": "C", "damage": ""},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	var ogerpon := _make_slot(_make_basic_pokemon("Teal Mask Ogerpon ex", "G"))
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	ogerpon.attached_energy.append(grass)
	var hoothoot_data := _make_basic_pokemon("Hoothoot", "C")
	hoothoot_data.attacks = [{"name": "Peck", "cost": "C", "damage": "10"}]
	var hoothoot := _make_slot(hoothoot_data)
	state.players[0].active_pokemon = raging_bolt
	state.players[0].bench.assign([ogerpon, hoothoot])
	var energy_switch := CardInstance.create(_make_trainer("Energy Switch"), 0)
	var action := {
		"kind": "play_trainer",
		"card": energy_switch,
		"productive": true,
		"targets": [{
			"energy_assignment": [{"source": grass, "target": hoothoot}],
		}],
	}
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var action_score: float = strategy.call("score_action_absolute_with_plan", action, state, 0, contract)
	var target_score: float = strategy.call("score_interaction_target", hoothoot, {
		"id": "energy_assignment",
	}, {
		"game_state": state,
		"player_index": 0,
		"source_card": grass,
	})
	return run_checks([
		assert_true(action_score <= -1800.0, "Energy Switch must not strip Ogerpon to enable Hoothoot chip damage (score=%f)" % action_score),
		assert_true(target_score <= -1500.0, "The support target itself must be rejected by Energy Switch interaction scoring (score=%f)" % target_score),
	])


func test_v18_raging_bolt_keeps_a_ready_active_over_an_incomplete_backup() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.hp = 240
	raging_data.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": ""},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var active := _make_slot(raging_data)
	active.attached_energy.assign([
		CardInstance.create(_make_energy("Lightning Energy", "L"), 0),
		CardInstance.create(_make_energy("Fighting Energy", "F"), 0),
	])
	var backup := _make_slot(raging_data)
	backup.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	state.players[0].active_pokemon = active
	state.players[0].bench.append(backup)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": backup,
		"energy_to_discard": [],
	}, state, 0, contract)
	return assert_true(
		retreat_score <= -500.0,
		"A free-retreat effect must not hand the turn from a ready Raging Bolt to an incomplete backup (score=%f)" % retreat_score
	)


func test_v18_raging_bolt_completes_the_active_lf_core_before_parallel_attachment() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.hp = 240
	raging_data.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": ""},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var active := _make_slot(raging_data)
	active.attached_energy.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	var backup := _make_slot(raging_data)
	state.players[0].active_pokemon = active
	state.players[0].bench.append(backup)
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var active_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": lightning, "target_slot": active,
	}, state, 0, contract)
	var backup_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": lightning, "target_slot": backup,
	}, state, 0, contract)
	return assert_true(
		active_score >= backup_score + 800.0,
		"Manual attachment must complete the Active LF core before splitting Energy onto a blank backup (active=%f backup=%f)" % [active_score, backup_score]
	)


func test_v18_raging_bolt_completes_benched_lf_core_before_bloodmoon_attachment() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(36)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	var bloodmoon_data := CardDatabase.get_card("CSV8C", "172")
	var slither_wing_data := CardDatabase.get_card("CSV6C", "082")
	if raging_data == null or bloodmoon_data == null or slither_wing_data == null:
		return "Expected Raging Bolt ex, Bloodmoon Ursaluna ex, and Slither Wing to exist"
	var active := _make_slot(slither_wing_data)
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	var bloodmoon := _make_slot(bloodmoon_data)
	state.players[0].active_pokemon = active
	state.players[0].bench.assign([bloodmoon, raging_bolt])
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var raging_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": lightning, "target_slot": raging_bolt,
	}, state, 0, contract)
	var bloodmoon_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": lightning, "target_slot": bloodmoon,
	}, state, 0, contract)
	return assert_true(
		raging_score >= bloodmoon_score + 1800.0,
		"Lightning must complete the benched Raging Bolt LF core instead of funding Bloodmoon manually (raging=%f bloodmoon=%f)" % [raging_score, bloodmoon_score]
	)


func test_v18_raging_bolt_noctowl_searches_the_vessel_sada_combo_without_duplicates() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var nest_a := CardInstance.create(_make_trainer("巢穴球"), 0)
	var nest_b := CardInstance.create(_make_trainer("巢穴球"), 0)
	var vessel := CardInstance.create(_make_trainer("大地容器"), 0)
	var sada := CardInstance.create(_make_trainer("奥琳博士的气魄"), 0)
	var picked: Array = strategy.call("pick_interaction_items", [nest_a, nest_b, vessel, sada], {
		"id": "csv9c_noctowl_trainers",
		"min_select": 0,
		"max_select": 2,
	}, {
		"game_state": state,
		"player_index": 0,
	})
	var picked_names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance and (item as CardInstance).card_data != null:
			picked_names.append(str((item as CardInstance).card_data.name))
	return run_checks([
		assert_eq(picked.size(), 2, "Noctowl should take both complementary Trainer pieces"),
		assert_true("大地容器" in picked_names, "Noctowl should establish Energy in the discard pile with Earthen Vessel"),
		assert_true("奥琳博士的气魄" in picked_names, "Noctowl should pair Earthen Vessel with Professor Sada's Vitality"),
	])


func test_v18_raging_bolt_night_stretcher_recovers_the_missing_attack_energy() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(7)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if raging_data == null:
		return "Expected CSV7C_154 Raging Bolt ex to exist"
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	state.players[0].active_pokemon = raging_bolt
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	if hoothoot_data == null:
		return "Expected CSV9C_154 Hoothoot to exist"
	state.players[0].bench.append(_make_slot(hoothoot_data))
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var noctowl_data := CardDatabase.get_card("CSV9C", "155")
	if noctowl_data == null:
		return "Expected CSV9C_155 Noctowl to exist"
	var noctowl := CardInstance.create(noctowl_data, 0)
	var step := {
		"id": "night_stretcher_choice",
		"min_select": 1,
		"max_select": 1,
	}
	var context := {"game_state": state, "player_index": 0}
	var lightning_score: float = strategy.call("score_interaction_target", lightning, step, context)
	var noctowl_score: float = strategy.call("score_interaction_target", noctowl, step, context)
	var picked: Array = strategy.call("pick_interaction_items", [lightning, noctowl], {
		"id": "night_stretcher_choice",
		"min_select": 1,
		"max_select": 1,
	}, {
		"game_state": state,
		"player_index": 0,
	})
	return assert_true(
		picked.size() == 1 and picked[0] == lightning,
		"Night Stretcher must recover Lightning Energy that completes Bellowing Thunder before optional Noctowl recovery (lightning=%f noctowl=%f)" % [lightning_score, noctowl_score]
	)


func test_v18_raging_bolt_defers_duplicate_attachment_for_night_stretcher_core_completion() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(8)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if raging_data == null:
		return "Expected CSV7C_154 Raging Bolt ex to exist"
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	state.players[0].active_pokemon = raging_bolt
	var support := _make_slot(CardDatabase.get_card("CSV9C", "154"))
	state.players[0].bench.append(support)
	var duplicate_lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var stretcher := CardInstance.create(_make_trainer("Night Stretcher"), 0)
	state.players[0].hand = [duplicate_lightning, stretcher]
	state.players[0].discard_pile.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var attach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": duplicate_lightning,
		"target_slot": support,
	}, state, 0, plan)
	return assert_true(
		attach_score <= -1800.0,
		"Raging Bolt should recover the missing Fighting Energy before spending its manual attachment on support Lightning (score=%f)" % attach_score
	)


func test_v18_raging_bolt_keeps_early_parallel_attachment_before_stretcher_completion() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	if raging_data == null or hoothoot_data == null:
		return "Expected Raging Bolt ex and Hoothoot to exist"
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	var support := _make_slot(hoothoot_data)
	state.players[0].active_pokemon = raging_bolt
	state.players[0].bench.append(support)
	var duplicate_lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	state.players[0].hand = [duplicate_lightning, CardInstance.create(_make_trainer("Night Stretcher"), 0)]
	state.players[0].discard_pile.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var attach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": duplicate_lightning,
		"target_slot": support,
	}, state, 0, plan)
	return assert_true(
		attach_score > -1800.0,
		"With a healthy deck, Raging Bolt may develop parallel Energy before spending Night Stretcher (score=%f)" % attach_score
	)


func test_v18_raging_bolt_crispin_completes_the_current_lf_core() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(18)
	state.energy_attached_this_turn = true
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	var non_ex_data := CardDatabase.get_card("CSV8C", "161")
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	var ogerpon_data := CardDatabase.get_card("CSV8C", "028")
	if raging_data == null or non_ex_data == null or hoothoot_data == null or ogerpon_data == null:
		return "Expected the Raging Bolt Crispin route cards to exist"
	var active := _make_slot(raging_data)
	active.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	var non_ex := _make_slot(non_ex_data)
	var hoothoot := _make_slot(hoothoot_data)
	var ogerpon := _make_slot(ogerpon_data)
	state.players[0].active_pokemon = active
	state.players[0].bench.assign([ogerpon, non_ex, hoothoot])
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var fighting := CardInstance.create(_make_energy("Fighting Energy", "F"), 0)
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var context := {"game_state": state, "player_index": 0}
	var hand_pick: Array = strategy.call("pick_interaction_items", [lightning, fighting, grass], {
		"id": "csv9c196_energy_to_hand",
		"max_select": 1,
	}, context)
	var attach_pick: Array = strategy.call("pick_interaction_items", [lightning, fighting], {
		"id": "csv9c196_energy_attachment",
		"max_select": 1,
	}, context)
	var active_score: float = strategy.call("score_interaction_target", active, {
		"id": "csv9c196_energy_attachment",
	}, context.merged({"source_card": fighting}))
	var non_ex_score: float = strategy.call("score_interaction_target", non_ex, {
		"id": "csv9c196_energy_attachment",
	}, context.merged({"source_card": fighting}))
	var hoothoot_score: float = strategy.call("score_interaction_target", hoothoot, {
		"id": "csv9c196_energy_attachment",
	}, context.merged({"source_card": fighting}))
	return run_checks([
		assert_true(hand_pick.size() == 1 and hand_pick[0] == grass, "Crispin should keep useful Grass in hand so the distinct Fighting attachment can complete LF"),
		assert_true(attach_pick.size() == 1 and attach_pick[0] == fighting, "Crispin should attach the missing Fighting Energy instead of duplicate Lightning"),
		assert_true(active_score >= non_ex_score + 1500.0, "Crispin must attach to Raging Bolt ex, not the similarly named non-ex attacker"),
		assert_true(active_score >= hoothoot_score + 1500.0, "Crispin must attach to Raging Bolt ex, not Hoothoot support"),
	])


func test_v18_raging_bolt_crispin_uses_both_lf_types_when_manual_attach_is_live() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(18)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if raging_data == null:
		return "Expected CSV7C_154 Raging Bolt ex to exist"
	var active := _make_slot(raging_data)
	state.players[0].active_pokemon = active
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy("Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var context := {"game_state": state, "player_index": 0}
	var hand_pick: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {
		"id": "csv9c196_energy_to_hand",
		"max_select": 1,
	}, context)
	if hand_pick.size() != 1:
		return "Crispin should choose exactly one Energy for hand"
	var hand_type := str((hand_pick[0] as CardInstance).card_data.energy_provides)
	var attach_candidates: Array = []
	for energy: CardInstance in [grass, fighting, lightning]:
		if str(energy.card_data.energy_provides) != hand_type:
			attach_candidates.append(energy)
	var attach_pick: Array = strategy.call("pick_interaction_items", attach_candidates, {
		"id": "csv9c196_energy_attachment",
		"max_select": 1,
	}, context)
	var attach_type := str((attach_pick[0] as CardInstance).card_data.energy_provides) if attach_pick.size() == 1 else ""
	return run_checks([
		assert_true(hand_type in ["L", "F"], "Crispin should put one LF attack type in hand while the manual attachment is still available"),
		assert_true(attach_type in ["L", "F"] and attach_type != hand_type, "Crispin should attach the other LF type and create a complete two-Energy route"),
	])


func test_v18_raging_bolt_uses_opening_ditto_transform_before_attaching() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	state.turn_number = 1
	var ditto_data := CardDatabase.get_card("151C", "132")
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if ditto_data == null or raging_data == null:
		return "Expected Ditto and Raging Bolt ex to exist"
	var ditto := _make_slot(ditto_data)
	state.players[0].active_pokemon = ditto
	state.players[0].deck.append(CardInstance.create(raging_data, 0))
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var transform_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": ditto,
		"ability_index": 0,
		"ability_name": "Transform Start",
	}, state, 0, contract)
	var attach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": ditto,
	}, state, 0, contract)
	return assert_true(
		transform_score >= attach_score + 1200.0,
		"Opening Ditto must transform into a real route owner before an attachment can strand it Active (transform=%f attach=%f)" % [transform_score, attach_score]
	)


func test_v18_raging_bolt_never_manual_attaches_to_benched_ditto() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	state.turn_number = 1
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	var ditto_data := CardDatabase.get_card("151C", "132")
	if raging_data == null or ditto_data == null:
		return "Expected Ditto and Raging Bolt ex to exist"
	state.players[0].active_pokemon = _make_slot(raging_data)
	var ditto := _make_slot(ditto_data)
	state.players[0].bench.append(ditto)
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var attach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": ditto,
	}, state, 0, contract)
	return assert_true(
		attach_score <= -1500.0,
		"A benched Ditto has missed Transform Start and must never absorb manual Energy (score=%f)" % attach_score
	)


func test_v18_raging_bolt_preserves_grass_for_teal_dance_instead_of_manual_bolt_attach() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(30)
	state.turn_number = 1
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if raging_data == null:
		return "Expected Raging Bolt ex to exist"
	var raging_bolt := _make_slot(raging_data)
	state.players[0].active_pokemon = raging_bolt
	var grass := CardInstance.create(_make_energy("Grass Energy", "G"), 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var attach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": raging_bolt,
	}, state, 0, contract)
	return assert_true(
		attach_score <= -1500.0,
		"Grass must stay in hand for a searched Teal Mask Ogerpon and Teal Dance instead of becoming dead LF-core fuel (score=%f)" % attach_score
	)


func test_v18_headless_builder_exposes_opening_ditto_transform() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(0)
	state.turn_number = 1
	state.first_player_index = 0
	var ditto_data := CardDatabase.get_card("151C", "132")
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	if ditto_data == null or raging_data == null:
		return "Expected Ditto and Raging Bolt ex to exist"
	state.players[0].active_pokemon = _make_slot(ditto_data)
	state.players[0].deck.append(CardInstance.create(raging_data, 0))
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	var transform_action: Dictionary = {}
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "use_ability" and int(action.get("ability_index", -1)) == 0:
			transform_action = action
			break
	return run_checks([
		assert_false(transform_action.is_empty(), "The headless legal-action builder must expose Ditto's first-turn Transform Start ability"),
		assert_true(not transform_action.is_empty() and not bool(transform_action.get("requires_interaction", true)), "Ditto transform should resolve a legal replacement target headlessly"),
	])


func test_v18_raging_bolt_ultra_ball_does_not_discard_both_lf_completion_cards_for_noctowl() -> String:
	var strategy := _strategy_for_deck(800018509)
	var state := _make_scoring_state(24)
	var raging_data := CardDatabase.get_card("CSV7C", "154")
	var noctowl_data := CardDatabase.get_card("CSV9C", "155")
	if raging_data == null or noctowl_data == null:
		return "Expected Raging Bolt ex and Noctowl to exist"
	var active := _make_slot(raging_data)
	active.attached_energy.append(CardInstance.create(_make_energy("Fighting Energy", "F"), 0))
	var backup := _make_slot(raging_data)
	backup.attached_energy.append(CardInstance.create(_make_energy("Lightning Energy", "L"), 0))
	state.players[0].active_pokemon = active
	state.players[0].bench.append(backup)
	var lightning := CardInstance.create(_make_energy("Lightning Energy", "L"), 0)
	var fighting := CardInstance.create(_make_energy("Fighting Energy", "F"), 0)
	var ultra_ball := CardInstance.create(CardDatabase.get_card("CSV1C", "112"), 0)
	var noctowl := CardInstance.create(noctowl_data, 0)
	state.players[0].hand.assign([ultra_ball, lightning, fighting])
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var ultra_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": ultra_ball,
		"productive": true,
		"targets": [{
			"discard_cards": [lightning, fighting],
			"search_pokemon": [noctowl],
		}],
	}, state, 0, contract)
	return assert_true(
		ultra_score <= -1500.0,
		"Ultra Ball must not destroy both visible LF completion routes for a delayed Noctowl evolution (score=%f)" % ultra_score
	)


func test_v18_raging_bolt_headless_nonlethal_interaction_preserves_the_lf_core() -> String:
	var strategy := _strategy_for_deck(800018509)
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_scoring_state(24)
	gsm.game_state.turn_number = 5
	var raging_data := _make_basic_pokemon("Raging Bolt ex", "N")
	raging_data.hp = 240
	raging_data.effect_id = "e96bb407c5f18bb9eec55487e70395fd"
	raging_data.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": ""},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
	]
	var raging_bolt := _make_slot(raging_data)
	raging_bolt.attached_energy.assign([
		CardInstance.create(_make_energy("Lightning Energy", "L"), 0),
		CardInstance.create(_make_energy("Fighting Energy", "F"), 0),
	])
	var ogerpon := _make_slot(_make_basic_pokemon("Teal Mask Ogerpon ex", "G"))
	ogerpon.attached_energy.append(CardInstance.create(_make_energy("Grass Energy", "G"), 0))
	gsm.game_state.players[0].active_pokemon = raging_bolt
	gsm.game_state.players[0].bench.append(ogerpon)
	var defender := _make_slot(_make_basic_pokemon("Defender", "L"))
	defender.get_top_card().card_data.hp = 280
	gsm.game_state.players[1].active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(raging_data)
	var bridge := HEADLESS_MATCH_BRIDGE_SCRIPT.new()
	bridge.bind(gsm)
	var resolver := AI_STEP_RESOLVER_SCRIPT.new()
	resolver.set_deck_strategy(strategy)
	var started: bool = bridge._try_use_attack_with_interaction(0, raging_bolt, 1)
	var resolved: bool = resolver.resolve_pending_step(bridge, gsm, 0)
	return run_checks([
		assert_true(started, "Headless Bellowing Thunder should enter its field-Energy interaction"),
		assert_true(resolved, "The V18 strategy should resolve the optional Energy selection"),
		assert_eq(defender.damage_counters, 70, "A nonlethal attack should spend only the expendable Grass fuel"),
		assert_eq(raging_bolt.attached_energy.size(), 2, "A nonlethal attack must preserve the active LF core"),
		assert_eq(ogerpon.attached_energy.size(), 0, "The expendable Ogerpon Grass Energy should be discarded first"),
	])


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _opening_energy_symbols(order: Array[Dictionary]) -> Array[String]:
	var symbols: Array[String] = []
	for index: int in mini(7, order.size()):
		var entry: Dictionary = order[index]
		var card: CardData = CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
		if card != null and card.is_energy():
			symbols.append(str(card.energy_provides))
	return symbols


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var registry_script: GDScript = load(STRATEGY_REGISTRY_PATH)
	var registry: RefCounted = registry_script.new()
	return registry.call("resolve_strategy_for_deck", _load_deck(deck_id))


func _make_scoring_state(deck_size: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	for index: int in deck_size:
		player.deck.append(CardInstance.create(_make_trainer("Deck card %d" % index), 0))
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, 0))
	return slot


func _make_pokemon(
	name: String,
	energy_type: String,
	attack_cost: String,
	damage: String,
	abilities: Array[Dictionary] = []
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = "Gholdengo ex" if name == "赛富豪ex" else name
	card.card_type = "Pokemon"
	card.stage = "Stage 1"
	card.mechanic = "ex"
	card.energy_type = energy_type
	card.hp = 260
	card.attacks = [{"name": "Test attack", "cost": attack_cost, "damage": damage}]
	card.abilities = abilities
	return card


func _make_basic_pokemon(name: String, energy_type: String) -> CardData:
	var card := _make_pokemon(name, energy_type, "C", "10")
	card.stage = "Basic"
	card.mechanic = ""
	return card


func _make_stage1_pokemon(
	name: String,
	evolves_from: String,
	energy_type: String,
	attack_cost: String,
	damage: String
) -> CardData:
	var card := _make_pokemon(name, energy_type, attack_cost, damage)
	card.stage = "Stage 1"
	card.evolves_from = evolves_from
	return card


func _make_stage2_pokemon(
	name: String,
	evolves_from: String,
	energy_type: String,
	attack_cost: String,
	damage: String
) -> CardData:
	var card := _make_pokemon(name, energy_type, attack_cost, damage)
	card.stage = "Stage 2"
	card.evolves_from = evolves_from
	return card


func _make_energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _make_trainer(name: String, description: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Supporter"
	card.description = description
	return card


func _deck_card_counts(deck: DeckData) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in deck.cards:
		var uid := _entry_uid(entry)
		counts[uid] = int(counts.get(uid, 0)) + int(entry.get("count", 0))
	return counts


func _entry_uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
