class_name TestV175PureDragapultStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategy175PureDragapult.gd"
const LLM_STRATEGY_PATH := "res://scripts/ai/DeckStrategy175PureDragapultLLM.gd"
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const BUDUW_EFFECT_ID := "28505a8ad6e07e74382c1b5e09737932"


func test_1750002_is_supported_ai_deck() -> String:
	var supported_ids: Array[int] = CardDatabase.get_supported_ai_deck_ids()
	return assert_true(
		1750002 in supported_ids,
		"17.5 pure Dragapult should be selectable from the built-in AI deck pool"
	)


func test_registry_maps_1750002_to_v175_strategy() -> String:
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var strategy = registry.call("resolve_strategy_for_deck", _make_deck_1750002()) if registry != null else null
	return run_checks([
		assert_not_null(registry, "DeckStrategyRegistry.gd should load and instantiate"),
		assert_not_null(strategy, "Registry should resolve a dedicated strategy for 17.5 pure Dragapult"),
		assert_eq(
			str(strategy.call("get_strategy_id")) if strategy != null and strategy.has_method("get_strategy_id") else "",
			"v175_pure_dragapult",
			"Deck 1750002 should not fall back to the old dragapult_dusknoir strategy"
		),
	])


func test_registry_keeps_rules_default_and_exposes_llm_variant() -> String:
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var default_strategy = registry.call("resolve_strategy_for_deck", _make_deck_1750002()) if registry != null else null
	var llm_strategy = registry.call("create_strategy_by_id", "v175_pure_dragapult_llm") if registry != null else null
	return run_checks([
		assert_not_null(registry, "DeckStrategyRegistry.gd should load and instantiate"),
		assert_eq(
			str(default_strategy.call("get_strategy_id")) if default_strategy != null and default_strategy.has_method("get_strategy_id") else "",
			"v175_pure_dragapult",
			"Deck 1750002 should keep the proven rules strategy as its default"
		),
		assert_not_null(llm_strategy, "Registry should expose the opt-in v175 pure Dragapult LLM strategy"),
		assert_eq(
			str(llm_strategy.call("get_strategy_id")) if llm_strategy != null and llm_strategy.has_method("get_strategy_id") else "",
			"v175_pure_dragapult_llm",
			"Registry-created LLM strategy should report the v175 pure Dragapult LLM id"
		),
		assert_true(llm_strategy != null and llm_strategy.has_method("get_llm_stats"), "LLM variant should expose runtime stats for audit logs"),
	])


func test_opening_setup_prefers_budew_active_and_benches_dreepy() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var player := PlayerState.new()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_budew_cd(), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))

	var setup: Dictionary = strategy.call("plan_opening_setup", player)
	var active_index := int(setup.get("active_hand_index", -1))
	var bench_indices: Array = setup.get("bench_hand_indices", []) if setup.get("bench_hand_indices", []) is Array else []
	var bench_names: Array[String] = []
	for index_variant: Variant in bench_indices:
		bench_names.append(_card_name(player.hand[int(index_variant)]))

	return run_checks([
		assert_eq(_card_name(player.hand[active_index]) if active_index >= 0 else "", "Budew", "Budew should be the preferred opening active buffer"),
		assert_true("Dreepy" in bench_names, "Dreepy should develop behind Budew on turn 1 setup"),
	])


func test_poffin_targets_budew_and_first_dreepy_before_duskull() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var budew := CardInstance.create(_make_budew_cd(), 0)
	var dreepy := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)

	var picked: Array = strategy.call(
		"pick_interaction_items",
		[budew, dreepy, duskull],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))
	names.sort()

	return run_checks([
		assert_eq(names.size(), 2, "Buddy-Buddy Poffin should pick two opening basics when available"),
		assert_true("Budew" in names, "Buddy-Buddy Poffin should find Budew for the active stall plan"),
		assert_true("Dreepy" in names, "Buddy-Buddy Poffin should also seed the first Dreepy line"),
		assert_false("Duskull" in names, "17.5 pure Dragapult should not take Duskull before Budew plus Dreepy"),
	])


func test_poffin_takes_two_dragapult_backups_before_duskull_in_first_budew_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	var dreepy_one := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var dreepy_two := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)

	var picked: Array = strategy.call(
		"pick_interaction_items",
		[dreepy_one, duskull, dreepy_two],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))

	return run_checks([
		assert_eq(names.size(), 2, "Buddy-Buddy Poffin should still take two basics when bench space is open"),
		assert_eq(names.count("Dreepy"), 2, "In the first Budew pressure window, Poffin should protect two backup Dragapult lines before Duskull"),
		assert_false("Duskull" in names, "Duskull should wait behind the third Dreepy only in the first Budew pressure window"),
	])


func test_poffin_takes_first_duskull_after_first_budew_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	var dreepy_one := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var dreepy_two := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)

	var picked: Array = strategy.call(
		"pick_interaction_items",
		[dreepy_one, duskull, dreepy_two],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))

	return run_checks([
		assert_eq(names.size(), 2, "Buddy-Buddy Poffin should still take two basics when bench space is open"),
		assert_eq(names.count("Dreepy"), 1, "After the first Budew window, Poffin should add only one backup Dreepy before branching"),
		assert_true("Duskull" in names, "After the first Budew window, the first Duskull line should not be delayed behind a third Dreepy"),
	])


func test_poffin_takes_dragapult_backup_lines_before_spare_duskull_when_duskull_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var dreepy_one := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var dreepy_two := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var spare_duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)

	var picked: Array = strategy.call(
		"pick_interaction_items",
		[dreepy_one, spare_duskull, dreepy_two],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))

	return run_checks([
		assert_eq(names.size(), 2, "Buddy-Buddy Poffin should still take two basics when bench space is open"),
		assert_eq(names.count("Dreepy"), 2, "Once Duskull is already online, Poffin should protect Dragapult backup lines before a spare Duskull"),
		assert_false("Duskull" in names, "A spare Duskull should wait behind backup Dreepy lines"),
	])


func test_handoff_uses_budew_buffer_until_dragapult_is_ready() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var budew := _make_slot(_make_budew_cd(), 0)
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var ready_dragapult := _make_slot(_make_dragapult_cd(), 0)
	ready_dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	ready_dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(budew)
	player.bench.append(dreepy)
	var context := {"game_state": gs, "player_index": 0}

	var budew_score: float = float(strategy.call("score_handoff_target", budew, {"id": "send_out"}, context))
	var dreepy_score: float = float(strategy.call("score_handoff_target", dreepy, {"id": "send_out"}, context))
	player.bench.append(ready_dragapult)
	var ready_dragapult_score: float = float(strategy.call("score_handoff_target", ready_dragapult, {"id": "send_out"}, context))

	return run_checks([
		assert_true(budew_score > dreepy_score + 150.0, "Before Dragapult is online, send-out should preserve Dreepy by promoting Budew"),
		assert_true(ready_dragapult_score > budew_score + 150.0, "Once Dragapult ex is ready, it should take over from the Budew buffer"),
	])


func test_budew_item_lock_attack_scores_as_stall_action() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))

	var attack_score: float = float(strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}, gs, 0))

	return assert_true(
		attack_score >= 620.0,
		"Budew's item-lock attack should be a premium stall action while Dragapult develops behind it"
	)


func test_lance_search_takes_drakloak_for_ready_dreepy_before_extra_basics() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0))
	var drakloak_a := CardInstance.create(_make_drakloak_cd(), 0)
	var drakloak_b := CardInstance.create(_make_drakloak_cd(), 0)
	var dragapult := CardInstance.create(_make_dragapult_cd(), 0)
	var dreepy := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)

	var picked: Array = strategy.call(
		"pick_interaction_items",
		[dragapult, dreepy, drakloak_a, drakloak_b],
		{"id": "dragon_pokemon", "max_select": 3},
		{"game_state": gs, "player_index": 0}
	)
	var names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))

	return run_checks([
		assert_eq(names.size(), 3, "Lance should take the full three-card Dragon search when useful targets exist"),
		assert_eq(names[0] if names.size() > 0 else "", "Drakloak", "Lance should first take Drakloak when an old Dreepy can evolve immediately"),
		assert_true("Dragapult ex" in names, "Lance should also take Dragapult ex to complete the evolution line"),
	])


func test_lance_followup_evolve_scores_above_budew_attack() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var dreepy_slot := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.bench.append(dreepy_slot)
	var drakloak := CardInstance.create(_make_drakloak_cd(), 0)
	player.hand.append(drakloak)

	var evolve_score: float = float(strategy.call("score_action_absolute", {
		"kind": "evolve",
		"card": drakloak,
		"target_slot": dreepy_slot,
	}, gs, 0))
	var attack_score: float = float(strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}, gs, 0))

	return assert_true(
		evolve_score > attack_score + 80.0,
		"When Lance has found Drakloak, the AI should safely evolve Dreepy before ending the turn with Budew's attack"
	)


func test_lance_followup_legal_action_ranking_picks_evolve_before_budew_attack() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var dreepy_slot := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.bench.append(dreepy_slot)
	player.hand.append(CardInstance.create(_make_drakloak_cd(), 0))
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)

	var actions := builder.build_actions(gsm, 0)
	var best_action: Dictionary = {}
	var best_score := -INF
	for action: Dictionary in actions:
		var kind := str(action.get("kind", ""))
		if kind not in ["evolve", "attack", "granted_attack"]:
			continue
		var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
		if score > best_score:
			best_score = score
			best_action = action

	return run_checks([
		assert_eq(str(best_action.get("kind", "")), "evolve", "The real legal-action ranking should evolve before Budew's turn-ending attack"),
		assert_eq(_card_name(best_action.get("card", null)), "Drakloak", "The selected evolution should be Drakloak"),
		assert_true(best_action.get("target_slot", null) == dreepy_slot, "Drakloak should target the ready Dreepy slot"),
	])


func test_budew_buffer_continuity_lifts_opening_setup_before_item_lock() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var dreepy_slot := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.bench.append(dreepy_slot)
	player.hand.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lance", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	player.deck.append(CardInstance.create(_make_drakloak_cd(), 0))
	player.deck.append(CardInstance.create(_make_dragapult_cd(), 0))
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.call("build_continuity_contract", gs, 0, turn_contract)
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}
	var attack_score := -INF
	var poffin_score := -INF
	var lance_score := -INF
	var attach_score := -INF
	for scored: Dictionary in best.get("scored_actions", []):
		var kind := str(scored.get("kind", ""))
		var card_name := _card_name(scored.get("card", null))
		if kind == "attack" and scored.get("source_slot", null) == player.active_pokemon:
			attack_score = maxf(attack_score, float(scored.get("score", -INF)))
		elif kind == "play_trainer" and card_name == "Buddy-Buddy Poffin":
			poffin_score = maxf(poffin_score, float(scored.get("score", -INF)))
		elif kind == "play_trainer" and card_name == "Lance":
			lance_score = maxf(lance_score, float(scored.get("score", -INF)))
		elif kind == "attach_energy" and scored.get("target_slot", null) == dreepy_slot:
			attach_score = maxf(attach_score, float(scored.get("score", -INF)))

	return run_checks([
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "Budew buffer turns should keep continuity open while setup actions remain"),
		assert_true(poffin_score > attack_score, "Poffin should outrank Budew's terminal item-lock attack while backup basics are still in deck"),
		assert_true(lance_score > attack_score, "Lance should outrank Budew's terminal item-lock attack while evolution search is still useful"),
		assert_true(attach_score > attack_score, "Manual Fire/Psychic attachments to Dreepy should happen before ending with Budew"),
		assert_true(str(best_action.get("kind", "")) in ["play_trainer", "attach_energy"], "Real AI ordering should start with safe setup instead of the Budew terminal attack"),
	])


func test_lance_found_drakloak_real_action_order_evolves_old_dreepy_before_arven() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	var dreepy_slot := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	dreepy_slot.turn_played = 1
	player.bench.append(dreepy_slot)
	player.hand.append(CardInstance.create(_make_drakloak_cd(), 0))
	player.hand.append(CardInstance.create(_make_drakloak_cd(), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0))
	player.deck.append(CardInstance.create(_make_dragapult_cd(), 0))
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var legal_drakloak_evolves := 0
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "evolve" and _card_name(action.get("card", null)) == "Drakloak":
			legal_drakloak_evolves += 1
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}

	return run_checks([
		assert_true(legal_drakloak_evolves > 0, "An old Dreepy should have a legal Drakloak evolution action"),
		assert_eq(str(best_action.get("kind", "")), "evolve", "After Lance has supplied Drakloak, real AI ordering should evolve an old Dreepy before more search setup"),
		assert_eq(_card_name(best_action.get("card", null)), "Drakloak", "The selected evolution should be Drakloak"),
		assert_true(best_action.get("target_slot", null) == dreepy_slot, "Drakloak should target the old Dreepy slot"),
	])


func test_budew_attack_waits_for_real_drakloak_ability_in_action_order() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var budew_cd: CardData = CardDatabase.get_card("CSV9.5C", "004")
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	if budew_cd == null or drakloak_cd == null:
		return "Bundled Budew CSV9.5C_004 and Drakloak CSV8C_158 card data should load"
	player.active_pokemon = _make_slot(budew_cd, 0)
	player.bench.clear()
	var drakloak_slot := _make_slot(drakloak_cd, 0)
	player.bench.append(drakloak_slot)
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_dragapult_cd(), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var legal_drakloak_abilities := 0
	var legal_budew_attacks := 0
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "use_ability" and action.get("source_slot", null) == drakloak_slot:
			legal_drakloak_abilities += 1
		if str(action.get("kind", "")) == "attack" and action.get("source_slot", null) == player.active_pokemon:
			legal_budew_attacks += 1
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}

	return run_checks([
		assert_true(legal_drakloak_abilities > 0, "Real Drakloak should expose a legal Recon Directive ability action"),
		assert_true(legal_budew_attacks > 0, "Budew's Itchy Pollen should remain a legal terminal attack"),
		assert_eq(str(best_action.get("kind", "")), "use_ability", "Budew's attack should wait until Drakloak's safe ability has been used"),
		assert_true(best_action.get("source_slot", null) == drakloak_slot, "The selected pre-attack ability should come from the benched Drakloak"),
	])


func test_budew_drakloak_order_is_encoded_as_continuity_contract() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var budew_cd: CardData = CardDatabase.get_card("CSV9.5C", "004")
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	if budew_cd == null or drakloak_cd == null:
		return "Bundled Budew CSV9.5C_004 and Drakloak CSV8C_158 card data should load"
	player.active_pokemon = _make_slot(budew_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(drakloak_cd, 0))
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_dragapult_cd(), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))

	var turn_contract: Dictionary = strategy.call("build_turn_contract", gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.call("build_continuity_contract", gs, 0, turn_contract)
	var action_bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var found_recon_bonus := false
	for raw_rule: Variant in action_bonuses:
		if not (raw_rule is Dictionary):
			continue
		var rule: Dictionary = raw_rule
		var target_names: Array = rule.get("target_names", []) if rule.get("target_names", []) is Array else []
		if str(rule.get("kind", "")) == "use_ability" and "Drakloak" in target_names and str(rule.get("reason", "")) == "use_drakloak_recon_before_budew_terminal_attack":
			found_recon_bonus = true
			break

	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "Budew buffer turns should use the shared continuity contract path"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "Budew's attack should be treated as terminal while safe development remains"),
		assert_true(float(continuity.get("attack_penalty", 0.0)) > 0.0, "Terminal Budew attack should receive a continuity penalty while Drakloak Recon is pending"),
		assert_true(found_recon_bonus, "The contract should explicitly route Drakloak Recon before Budew's terminal attack"),
	])


func test_budew_attack_remains_terminal_after_drakloak_ability_is_used() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var budew_cd: CardData = CardDatabase.get_card("CSV9.5C", "004")
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	if budew_cd == null or drakloak_cd == null:
		return "Bundled Budew CSV9.5C_004 and Drakloak CSV8C_158 card data should load"
	player.active_pokemon = _make_slot(budew_cd, 0)
	player.bench.clear()
	var drakloak_slot := _make_slot(drakloak_cd, 0)
	drakloak_slot.effects.append({"type": "ability_look_top_to_hand_used", "turn": gs.turn_number})
	player.bench.append(drakloak_slot)
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_dragapult_cd(), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var legal_drakloak_abilities := 0
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "use_ability" and action.get("source_slot", null) == drakloak_slot:
			legal_drakloak_abilities += 1
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}

	return run_checks([
		assert_eq(legal_drakloak_abilities, 0, "Used Drakloak should not expose another Recon Directive action this turn"),
		assert_eq(str(best_action.get("kind", "")), "attack", "After safe pre-attack ability use is exhausted, Budew should still make the terminal item-lock attack"),
		assert_true(best_action.get("source_slot", null) == player.active_pokemon, "The terminal attack should come from active Budew"),
	])


func test_jet_head_only_dragapult_does_not_create_conversion_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var active_dragapult := _make_slot(_make_dragapult_cd(), 0)
	active_dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	active_dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_dragapult
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var attack_indices: Array[int] = []
	for action: Dictionary in builder.build_actions(gsm, 0):
		if str(action.get("kind", "")) == "attack":
			attack_indices.append(int(action.get("attack_index", -1)))
	var contract: Dictionary = strategy.call("build_turn_contract", gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}

	return run_checks([
		assert_true(0 in attack_indices, "Jet Head should remain legal with two Psychic Energy"),
		assert_false(1 in attack_indices, "Phantom Dive should not be legal without Fire Energy or Sparkling Crystal cost reduction"),
		assert_true(str(contract.get("intent", "")) != "convert_attack", "Jet Head-only Dragapult should keep routing toward Phantom Dive or a rebuild instead of entering conversion"),
		assert_false(bool(flags.get("convert_attack", false)), "Jet Head-only Dragapult should not set convert_attack"),
		assert_false(bool(flags.get("immediate_attack_window", false)), "Jet Head-only Dragapult should not count as the deck's immediate pressure window"),
	])


func test_jet_head_waits_for_drakloak_recon_when_phantom_energy_is_findable() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	if drakloak_cd == null:
		return "Bundled Drakloak CSV8C_158 card data should load"
	var active_dragapult := _make_slot(_make_dragapult_cd(), 0)
	active_dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_dragapult
	player.bench.clear()
	var drakloak_slot := _make_slot(drakloak_cd, 0)
	player.bench.append(drakloak_slot)
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 70, "", "ex"), 1)
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.call("build_continuity_contract", gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var action_bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var found_recon_bonus := false
	for raw_rule: Variant in action_bonuses:
		if not (raw_rule is Dictionary):
			continue
		var rule: Dictionary = raw_rule
		if str(rule.get("kind", "")) == "use_ability" and str(rule.get("reason", "")) == "use_drakloak_recon_to_find_phantom_energy_before_jet_head":
			found_recon_bonus = true
			break
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}
	var jet_head_score := -INF
	var recon_score := -INF
	for scored: Dictionary in best.get("scored_actions", []):
		if str(scored.get("kind", "")) == "attack" and scored.get("source_slot", null) == active_dragapult:
			jet_head_score = maxf(jet_head_score, float(scored.get("score", -INF)))
		if str(scored.get("kind", "")) == "use_ability" and scored.get("source_slot", null) == drakloak_slot:
			recon_score = maxf(recon_score, float(scored.get("score", -INF)))

	return run_checks([
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "Jet Head should be terminal while a legal Drakloak Recon can still find Phantom Dive Energy"),
		assert_true(bool(setup_debt.get("active_dragapult_needs_phantom_energy", false)), "Continuity debt should name the missing active Dragapult Phantom Dive Energy"),
		assert_true(found_recon_bonus, "The contract should explicitly route Drakloak Recon before a low-value Jet Head"),
		assert_true(recon_score > jet_head_score, "Drakloak Recon should outrank the premature Jet Head when Fire Energy is findable"),
		assert_eq(str(best_action.get("kind", "")), "use_ability", "Real action ordering should use Drakloak Recon before ending the turn with Jet Head"),
		assert_true(best_action.get("source_slot", null) == drakloak_slot, "The selected bridge action should be the benched Drakloak"),
	])


func test_jet_head_remains_terminal_after_drakloak_recon_is_used() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	if drakloak_cd == null:
		return "Bundled Drakloak CSV8C_158 card data should load"
	var active_dragapult := _make_slot(_make_dragapult_cd(), 0)
	active_dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_dragapult
	player.bench.clear()
	var drakloak_slot := _make_slot(drakloak_cd, 0)
	drakloak_slot.effects.append({"type": "ability_look_top_to_hand_used", "turn": gs.turn_number})
	player.bench.append(drakloak_slot)
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 70, "", "ex"), 1)
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.call("build_continuity_contract", gs, 0, turn_contract)
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}

	return run_checks([
		assert_false(bool(continuity.get("safe_setup_before_attack", false)), "After Drakloak Recon is spent and no executable search remains, continuity debt should clear"),
		assert_eq(str(best_action.get("kind", "")), "attack", "With safe setup exhausted, Jet Head should remain the terminal action"),
		assert_true(best_action.get("source_slot", null) == active_dragapult, "The terminal attack should come from active Dragapult ex"),
	])


func test_low_prize_iono_disruption_outranks_immediate_dragapult_attack() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.prizes.clear()
	opponent.prizes.clear()
	for i: int in 4:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Player Prize %d" % i), 0))
	for i: int in 2:
		opponent.prizes.append(CardInstance.create(_make_trainer_cd("Opponent Prize %d" % i), 1))
	var dragapult := _make_slot(_make_dragapult_cd(), 0)
	dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = dragapult
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)

	var iono_score: float = float(strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": iono,
	}, gs, 0))
	var attack_score: float = float(strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
	}, gs, 0))

	return assert_true(
		iono_score > attack_score + 50.0,
		"When Charizard is close to winning, 17.5 pure Dragapult should play Iono before its non-closing Phantom Dive attack (Iono %.1f vs attack %.1f)" % [iono_score, attack_score]
	)


func test_earthen_vessel_search_prioritizes_missing_fire_for_backup_dragapult() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy175PureDragapult.gd should load"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var backup := _make_slot(_make_drakloak_cd(), 0)
	backup.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(backup)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var picked: Array = strategy.call(
		"pick_interaction_items",
		[psychic, fire],
		{"id": "search_energy", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var names := _picked_names(picked)

	return run_checks([
		assert_eq(names.size(), 2, "Earthen Vessel should still take both relevant basic energies when available"),
		assert_eq(names[0] if names.size() > 0 else "", "Fire Energy", "When the backup Drakloak already has Psychic, Earthen Vessel should take Fire first"),
	])


func test_llm_rules_fallback_delegates_opening_and_action_scores() -> String:
	var rules := _new_strategy()
	var llm := _new_llm_strategy()
	if rules == null or llm == null:
		return "Rules and LLM strategies should instantiate"
	var player := PlayerState.new()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_budew_cd(), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var rules_setup: Dictionary = rules.call("plan_opening_setup", player)
	var llm_setup: Dictionary = llm.call("plan_opening_setup", player)
	var gs := _make_game_state(3)
	var action := {
		"kind": "attack",
		"source_slot": gs.players[0].active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}
	var rules_score: float = float(rules.call("score_action_absolute", action, gs, 0))
	var llm_score: float = float(llm.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_eq(llm_setup, rules_setup, "LLM wrapper should delegate opening setup to the 17.5 rules fallback"),
		assert_eq(llm_score, rules_score, "LLM wrapper should delegate ordinary action scores when no LLM plan is active"),
	])


func test_llm_prompt_profile_and_setup_hooks_cover_17_5_plan() -> String:
	var llm := _new_llm_strategy()
	if llm == null:
		return "DeckStrategy175PureDragapultLLM.gd should instantiate"
	llm.call("set_deck_strategy_text", "custom player note: Lance should finish the current Dragapult line before extra basics")
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_budew_cd(), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	var payload: Dictionary = llm.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	var budew_hint := str(llm.call("get_llm_setup_role_hint", _make_budew_cd()))
	var lance_hint := str(llm.call("get_llm_setup_role_hint", _make_trainer_cd("Lance", "Supporter")))
	var profile: Dictionary = llm.call("get_intent_planner_profile")
	var support_only: Array = profile.get("support_only", []) if profile.get("support_only", []) is Array else []
	var setup_attacks: Array = profile.get("setup_draw_attacks", []) if profile.get("setup_draw_attacks", []) is Array else []
	var found_budew_attack := false
	for raw: Variant in setup_attacks:
		if raw is Dictionary and str((raw as Dictionary).get("pokemon", "")) == "Budew" and str((raw as Dictionary).get("attack", "")) == "Itchy Pollen":
			found_budew_attack = true
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "v175_pure_dragapult_llm", "Payload should identify the 17.5 pure Dragapult LLM strategy"),
		assert_true(prompt_lines.size() >= 8, "Prompt should provide enough deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "17.5", "Prompt should identify the 17.5 plan family"),
		assert_str_contains(prompt_text, "Itchy Pollen", "Prompt should cover the Budew item-lock buffer"),
		assert_str_contains(prompt_text, "Dragapult ex", "Prompt should cover the main attacker"),
		assert_str_contains(prompt_text, "legal_actions", "Prompt should preserve legal-action constraints"),
		assert_str_contains(prompt_text, "interaction_schema", "Prompt should preserve interaction-schema constraints"),
		assert_str_contains(prompt_text, "custom player note", "Prompt should include editable strategy text"),
		assert_str_contains(budew_hint, "item-lock buffer", "Budew setup hint should mark the opening buffer role"),
		assert_str_contains(lance_hint, "Dragon search", "Lance setup hint should mark the Dragon search role"),
		assert_true("Budew" in support_only, "Intent profile should classify Budew as support-only"),
		assert_true(found_budew_attack, "Intent profile should expose Budew's Itchy Pollen as a setup attack"),
	])


func test_llm_interaction_fallback_uses_lance_search_order() -> String:
	var rules := _new_strategy()
	var llm := _new_llm_strategy()
	if rules == null or llm == null:
		return "Rules and LLM strategies should instantiate"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0))
	var items := [
		CardInstance.create(_make_dragapult_cd(), 0),
		CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0),
		CardInstance.create(_make_drakloak_cd(), 0),
		CardInstance.create(_make_drakloak_cd(), 0),
	]
	var step := {"id": "dragon_pokemon", "max_select": 3}
	var context := {"game_state": gs, "player_index": 0}
	var rules_picked: Array = rules.call("pick_interaction_items", items, step, context)
	var llm_picked: Array = llm.call("pick_interaction_items", items, step, context)
	var rules_names := _picked_names(rules_picked)
	var llm_names := _picked_names(llm_picked)
	return run_checks([
		assert_eq(llm_names, rules_names, "LLM wrapper should use 17.5 Lance search fallback when no LLM plan is active"),
		assert_eq(llm_names[0] if llm_names.size() > 0 else "", "Drakloak", "Lance fallback should first take Drakloak for the ready Dreepy"),
		assert_true("Dragapult ex" in llm_names, "Lance fallback should also take Dragapult ex"),
	])


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(STRATEGY_PATH)
	return script.new() if script is GDScript else null


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(LLM_STRATEGY_PATH)
	return script.new() if script is GDScript else null


func _make_deck_1750002() -> DeckData:
	var deck := DeckData.new()
	deck.id = 1750002
	deck.deck_name = "17.5 pure Dragapult"
	deck.total_cards = 60
	deck.cards = [
		{"name": "Budew", "name_en": "", "card_type": "Pokemon", "effect_id": BUDUW_EFFECT_ID, "count": 1},
		{"name": "Dreepy", "name_en": "Dreepy", "card_type": "Pokemon", "count": 4},
		{"name": "Drakloak", "name_en": "Drakloak", "card_type": "Pokemon", "count": 4},
		{"name": "Dragapult ex", "name_en": "Dragapult ex", "card_type": "Pokemon", "count": 3},
		{"name": "Duskull", "name_en": "Duskull", "card_type": "Pokemon", "count": 3},
	]
	return deck


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Basic", "C"), pi)
		gs.players.append(player)
	return gs


func _make_budew_cd() -> CardData:
	var cd := _make_pokemon_cd("Budew", "Basic", "G", 30, "", "", [], [
		{"name": "Itchy Pollen", "cost": "0", "damage": "10"},
	], 0)
	cd.effect_id = BUDUW_EFFECT_ID
	cd.name_en = ""
	return cd


func _make_dragapult_cd() -> CardData:
	return _make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex", [], [
		{"name": "Jet Head", "cost": "C", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	])


func _make_drakloak_cd() -> CardData:
	return _make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy", "", [
		{"name": "Recon Directive"},
	], [
		{"name": "Dragon Headbutt", "cost": "PC", "damage": "70"},
	])


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _card_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if str(card.card_data.effect_id) == BUDUW_EFFECT_ID:
		return "Budew"
	return str(card.card_data.name_en) if str(card.card_data.name_en) != "" else str(card.card_data.name)


func _picked_names(cards: Array) -> Array[String]:
	var names: Array[String] = []
	for item: Variant in cards:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))
	return names
