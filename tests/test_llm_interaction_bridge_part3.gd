extends "res://tests/helpers/LLMInteractionBridgeShared.gd"

func test_raging_bolt_llm_candidate_fallback_prefers_continuity_route_over_shallow_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	_fill_player_deck(player, 20)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 1)
	var backup_bolt := CardInstance.create(_make_raging_bolt_cd(), 0)
	player.hand.append(backup_bolt)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_basic_to_bench", "card": backup_bolt},
		{"kind": "attack", "attack_index": 1, "source_slot": player.active_pokemon, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var fallback_tree: Dictionary = strategy.call("_candidate_route_fallback_tree")
	var branches: Array = fallback_tree.get("branches", []) if fallback_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_true(not payload.is_empty(), "Payload fixture should build successfully"),
		assert_eq(str(first_action.get("id", "")), "route:continuity_before_attack", "Fallback repair should prefer continuity-before-attack over a shallow attack-only route"),
	])


func test_raging_bolt_llm_payload_exposes_core_attacker_route_before_support_draw() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	player.active_pokemon = _make_slot(fez_cd, 0)
	_fill_player_deck(player, 20)
	var nest_cd := _make_trainer_cd("Nest Ball", "Item")
	nest_cd.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	var nest := CardInstance.create(nest_cd, 0)
	player.hand.append(nest)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": nest, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {}) if payload.get("turn_tactical_facts", {}) is Dictionary else {}
	var core_setup: Dictionary = facts.get("core_attacker_setup", {}) if facts.get("core_attacker_setup", {}) is Dictionary else {}
	var route: Dictionary = {}
	for raw_route: Variant in payload.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:core_attacker_setup":
			route = raw_route
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_route_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	var selection_policy: Dictionary = first_route_action.get("selection_policy", {}) if first_route_action.get("selection_policy", {}) is Dictionary else {}
	var policy_text := JSON.stringify(selection_policy)
	var fallback_tree: Dictionary = strategy.call("_candidate_route_fallback_tree")
	var branches: Array = fallback_tree.get("branches", []) if fallback_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_true(bool(core_setup.get("needs_first_raging_bolt", false)), "Core setup facts should flag missing first Raging Bolt"),
		assert_true(bool(core_setup.get("core_route_available", false)), "Core setup facts should expose a legal Raging Bolt access route"),
		assert_true(not route.is_empty(), "Payload should expose route:core_attacker_setup before support draw routes"),
		assert_str_contains(policy_text, "Raging Bolt ex", "Core search route should carry selection_policy that prefers Raging Bolt ex"),
		assert_eq(str(first_action.get("id", "")), "route:core_attacker_setup", "Fallback repair should prefer first-attacker setup over preserve/end or support draw"),
	])


func test_raging_bolt_llm_blocks_core_energy_attach_to_support_when_bolt_searchable() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	player.active_pokemon = _make_slot(fez_cd, 0)
	var nest_cd := _make_trainer_cd("Nest Ball", "Item")
	nest_cd.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand.append(CardInstance.create(nest_cd, 0))
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	player.hand.append(lightning)
	var attach_to_support := {
		"kind": "attach_energy",
		"card": lightning,
		"target_slot": player.active_pokemon,
	}
	var blocked_score: float = float(strategy.call("score_action_absolute", attach_to_support, gs, 0))
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	var allowed_score: float = float(strategy.call("score_action_absolute", attach_to_support, gs, 0))
	return run_checks([
		assert_true(blocked_score <= -1000.0,
			"Lightning/Fighting should be preserved instead of attached to support active when Raging Bolt is searchable (score=%f)" % blocked_score),
		assert_true(allowed_score <= -1000.0,
			"Lightning/Fighting should still not be attached to support once Raging Bolt exists on bench (score=%f)" % allowed_score),
	])


func test_raging_bolt_llm_blocks_any_energy_attach_to_support_engine_slot() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160)
	squawk_cd.name_en = "Squawkabilly ex"
	var squawk := _make_slot(squawk_cd, 0)
	player.bench.append(squawk)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass)
	var score: float = float(strategy.call("score_action_absolute", {
		"kind": "attach_energy",
		"card": grass,
		"target_slot": squawk,
	}, gs, 0))
	return assert_true(score <= -1000.0, "Raging Bolt LLM should not attach even Grass to passive support engines like Squawkabilly (score=%f)" % score)


func test_raging_bolt_llm_search_fallback_picks_core_attacker_without_pending_queue() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	player.active_pokemon = _make_slot(fez_cd, 0)
	strategy.set("_llm_decision_tree", {"branches": [{"when": [{"fact": "always"}], "actions": [{"id": "play_trainer:c1"}]}]})
	strategy.set("_llm_action_queue", [{"id": "play_trainer:c1", "action_id": "play_trainer:c1", "type": "play_trainer"}])
	strategy.set("_llm_queue_turn", 2)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon := CardInstance.create(ogerpon_cd, 0)
	var bolt := CardInstance.create(_make_raging_bolt_cd(), 0)
	var picked: Array = strategy.call("pick_interaction_items", [ogerpon, bolt], {"id": "search_targets", "max_select": 1}, {
		"game_state": gs,
		"player_index": 0,
	})
	return run_checks([
		assert_eq(picked.size(), 1, "Core search fallback should choose one search target"),
		assert_true(picked[0] == bolt, "When no Raging Bolt is on board, deferred search fallback must pick Raging Bolt over Ogerpon"),
	])


func test_raging_bolt_llm_payload_exposes_core_recovery_route_from_night_stretcher() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	player.active_pokemon = _make_slot(fez_cd, 0)
	player.discard_pile.append(CardInstance.create(_make_raging_bolt_cd(), 0))
	var stretcher_cd := _make_trainer_cd("Night Stretcher", "Item")
	stretcher_cd.effect_id = "3e6f1daf545dfed48d0588dd50792a2e"
	var stretcher := CardInstance.create(stretcher_cd, 0)
	player.hand.append(stretcher)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": stretcher, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var route: Dictionary = {}
	for raw_route: Variant in payload.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:core_attacker_setup":
			route = raw_route
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_route_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	var fallback_tree: Dictionary = strategy.call("_candidate_route_fallback_tree")
	var branches: Array = fallback_tree.get("branches", []) if fallback_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_true(not route.is_empty(), "Night Stretcher should expose a core attacker recovery route when Raging Bolt is in discard"),
		assert_true(str(first_route_action.get("id", "")).begins_with("play_trainer:"), "Core recovery route should start with Night Stretcher"),
		assert_str_contains(JSON.stringify(first_route_action.get("selection_policy", {})), "Raging Bolt ex", "Core recovery route should recover Raging Bolt first"),
		assert_eq(str(first_action.get("id", "")), "route:core_attacker_setup", "Fallback repair should prefer recovering the primary attacker over support draw"),
	])


func test_raging_bolt_llm_payload_adds_visible_engine_attack_route_when_generic_route_is_missing() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(20)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var payload := {
		"legal_actions": [
			{"id": "play_trainer:c30", "action_id": "play_trainer:c30", "type": "play_trainer", "card": "Professor Sada's Vitality"},
			{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
		],
		"future_actions": [{
			"id": "future:attack_after_visible_engine:active:1:Thundering Bolt",
			"action_id": "future:attack_after_visible_engine:active:1:Thundering Bolt",
			"type": "attack",
			"future": true,
			"attack_index": 1,
			"attack_name": "Thundering Bolt",
			"source_pokemon": "Raging Bolt ex",
		}],
		"turn_tactical_facts": {
			"primary_attack_name": "Thundering Bolt",
			"primary_attack_reachable_after_visible_engine": true,
			"primary_attack_route": ["discard_energy_acceleration_supporter", "Thundering Bolt"],
			"deck_count": 8,
		},
		"candidate_routes": [{"route_action_id": "route:preserve_end", "goal": "fallback", "actions": [{"id": "end_turn"}]}],
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var route: Dictionary = {}
	for raw_route: Variant in augmented.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:raging_bolt_primary_visible_engine":
			route = raw_route
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	var last_action: Dictionary = route_actions[route_actions.size() - 1] if not route_actions.is_empty() and route_actions[route_actions.size() - 1] is Dictionary else {}
	var future_goals: Array = route.get("future_goals", []) if route.get("future_goals", []) is Array else []
	var first_goal: Dictionary = future_goals[0] if not future_goals.is_empty() and future_goals[0] is Dictionary else {}
	return run_checks([
		assert_true(not route.is_empty(), "Raging Bolt wrapper should add a deck-specific visible-engine attack route when generic routes miss it"),
		assert_eq(str(first_action.get("id", "")), "play_trainer:c30", "Visible-engine route should start from the legal Sada action"),
		assert_true(bool(first_action.get("allow_deck_draw_lock", false)), "Attack-unlocking Sada route should survive low-deck draw lock"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Visible-engine route should close with end_turn for runtime attack conversion"),
		assert_eq(str(first_goal.get("attack_name", "")), "Thundering Bolt", "Visible-engine route should carry the future burst attack goal"),
	])


func test_raging_bolt_llm_blocks_queued_ogerpon_draw_when_deck_is_low() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon)
	_fill_player_deck(player, 6)
	strategy.set("_llm_decision_tree", {"branches": [{"when": [{"fact": "always"}], "actions": [{"id": "use_ability:bench_0:0"}]}]})
	strategy.set("_llm_action_queue", [{"id": "use_ability:bench_0:0", "action_id": "use_ability:bench_0:0", "type": "use_ability", "pokemon": "Teal Mask Ogerpon ex"}])
	strategy.set("_llm_queue_turn", 18)
	var score: float = float(strategy.call("score_action_absolute", {
		"kind": "use_ability",
		"source_slot": ogerpon,
		"ability_index": 0,
	}, gs, 0))
	return assert_true(score <= -1000.0, "Low-deck draw discipline must block queued Ogerpon draw before LLM queue score wins (score=%f)" % score)


func test_raging_bolt_llm_blocks_non_ko_boss_when_burst_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var iron_hands_cd := _make_pokemon_cd("Iron Hands ex", "Basic", "L", 230)
	iron_hands_cd.name_en = "Iron Hands ex"
	iron_hands_cd.mechanic = "ex"
	gs.players[1].bench.append(_make_slot(iron_hands_cd, 1))
	var boss_cd := _make_trainer_cd("Boss's Orders", "Supporter")
	boss_cd.name_en = "Boss's Orders"
	var boss := CardInstance.create(boss_cd, 0)
	var score: float = float(strategy.call("score_action_absolute", {"kind": "play_trainer", "card": boss}, gs, 0))
	return assert_true(score <= -1000.0, "Boss should be blocked when ready burst cannot KO the gust target (score=%f)" % score)


func test_raging_bolt_llm_allows_boss_when_burst_kos_bench_target() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var iron_hands_cd := _make_pokemon_cd("Iron Hands ex", "Basic", "L", 230)
	iron_hands_cd.name_en = "Iron Hands ex"
	iron_hands_cd.mechanic = "ex"
	gs.players[1].bench.append(_make_slot(iron_hands_cd, 1))
	var boss_cd := _make_trainer_cd("Boss's Orders", "Supporter")
	boss_cd.name_en = "Boss's Orders"
	var boss := CardInstance.create(boss_cd, 0)
	var score: float = float(strategy.call("score_action_absolute", {"kind": "play_trainer", "card": boss}, gs, 0))
	return assert_true(score > -1000.0, "Boss should remain legal when burst can KO a benched prize target (score=%f)" % score)


func test_raging_bolt_llm_prime_catcher_own_target_prefers_ready_bolt() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	var bolt := _make_slot(_make_raging_bolt_cd(), 0)
	bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	var greninja := _make_slot(greninja_cd, 0)
	player.bench.append(greninja)
	player.bench.append(bolt)
	var context := {"game_state": gs, "player_index": 0}
	var bolt_score: float = float(strategy.call("score_interaction_target", bolt, {"id": "own_bench_target"}, context))
	var greninja_score: float = float(strategy.call("score_interaction_target", greninja, {"id": "own_bench_target"}, context))
	return run_checks([
		assert_true(bolt_score > greninja_score, "Prime Catcher own target should prefer ready Raging Bolt (bolt=%f greninja=%f)" % [bolt_score, greninja_score]),
		assert_true(greninja_score <= -1000.0, "Prime Catcher own target should reject Radiant Greninja as casual pivot (score=%f)" % greninja_score),
	])

