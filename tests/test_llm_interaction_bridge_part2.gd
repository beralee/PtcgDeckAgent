extends "res://tests/helpers/LLMInteractionBridgeShared.gd"

func test_llm_route_candidate_builder_low_deck_lock_excludes_schema_draw_abilities() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var current_actions: Array[Dictionary] = [
		{
			"id": "use_ability:bench_0:0",
			"action_id": "use_ability:bench_0:0",
			"type": "use_ability",
			"pokemon": "Radiant Greninja",
			"requires_interaction": true,
			"interaction_schema": {"discard_card": {"type": "string"}},
		},
		{
			"id": "use_ability:bench_1:0",
			"action_id": "use_ability:bench_1:0",
			"type": "use_ability",
			"pokemon": "Teal Mask Ogerpon ex",
			"requires_interaction": true,
			"interaction_schema": {"basic_energy_from_hand": {"type": "string", "note": "Then draw a card."}},
		},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var routes: Array = builder.call("build_candidate_routes", current_actions, [], {
		"no_deck_draw_lock": true,
	})
	var route_ids: Array[String] = []
	for raw_route: Variant in routes:
		if raw_route is Dictionary:
			for raw_action: Variant in (raw_route as Dictionary).get("actions", []):
				if raw_action is Dictionary:
					route_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(route_ids.has("use_ability:bench_0:0"), "Low-deck candidate routes must not expose discard-to-draw abilities"),
		assert_false(route_ids.has("use_ability:bench_1:0"), "Low-deck candidate routes must not expose charge-and-draw abilities"),
		assert_true(route_ids.has("end_turn"), "Low-deck candidate builder should still preserve the safe end-turn fallback"),
	])


func test_llm_route_candidate_builder_skips_low_value_active_attach_route() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var attach := {
		"id": "attach_energy:c21:active",
		"action_id": "attach_energy:c21:active",
		"type": "attach_energy",
		"card": "Grass Energy",
		"energy_type": "Grass",
		"position": "active",
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [attach, end_turn], [], {
		"manual_attach_enables_best_active_attack": true,
		"best_manual_attach_to_best_active_attack_action_id": "attach_energy:c21:active",
		"best_active_attack_after_manual_attach": {
			"attack_name": "Bursting Roar",
			"attack_index": 0,
			"estimated_damage_after_best_manual_attach": 0,
			"kos_opponent_active_after_best_manual_attach": false,
			"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
		},
	})
	var saw_low_attach_route := false
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "manual_attach_to_active_attack":
			saw_low_attach_route = true
	return run_checks([
		assert_false(saw_low_attach_route, "Candidate builder should not spend manual attach just to enable low-value redraw attack"),
	])


func test_llm_route_candidate_materializes_into_exact_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var catalog := {
		"use_ability:bench_0:0": {
			"id": "use_ability:bench_0:0",
			"action_id": "use_ability:bench_0:0",
			"type": "use_ability",
			"pokemon": "Teal Mask Ogerpon ex",
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	strategy.call("_register_payload_candidate_routes", {
		"candidate_routes": [{
			"id": "primary_visible_engine",
			"route_action_id": "route:primary_visible_engine",
			"actions": [
				{"id": "use_ability:bench_0:0"},
				{"id": "play_trainer:c52"},
				{"id": "end_turn"},
			],
		}],
	})
	var materialized: Array = strategy.call("_materialize_action_ref_array", [{"id": "route:primary_visible_engine"}])
	var ids: Array[String] = []
	for raw: Variant in materialized:
		if raw is Dictionary:
			ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_eq(materialized.size(), 3, "Route action should expand into its exact executable action refs"),
		assert_eq(ids[0], "use_ability:bench_0:0", "Expanded route should preserve first action order"),
		assert_eq(ids[1], "play_trainer:c52", "Expanded route should preserve search action order"),
		assert_eq(ids[2], "end_turn", "Expanded route should preserve terminal action"),
	])


func test_llm_candidate_route_fallback_skips_low_value_active_attach_when_primary_route_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var active_attach_route := {
		"id": "route:manual_attach_to_active_attack",
		"action_id": "route:manual_attach_to_active_attack",
		"type": "route",
		"candidate_route": true,
		"priority": 975,
		"goal": "manual_attach_to_active_attack",
		"actions": [
			{"id": "attach_energy:c21:active", "action_id": "attach_energy:c21:active", "type": "attach_energy", "position": "active"},
			{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
		],
		"future_goals": [{
			"id": "goal:manual_attach_best_active_attack",
			"type": "goal",
			"attack_name": "Bursting Roar",
			"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
		}],
	}
	var primary_route := {
		"id": "route:primary_visible_engine",
		"action_id": "route:primary_visible_engine",
		"type": "route",
		"candidate_route": true,
		"priority": 900,
		"goal": "setup_to_primary_attack",
		"actions": [
			{"id": "use_ability:bench_0:0", "action_id": "use_ability:bench_0:0", "type": "use_ability"},
			{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
		],
		"future_goals": [{
			"id": "future:attack_after_visible_engine:active:1:Thundering Bolt",
			"type": "attack",
			"future": true,
			"attack_name": "Thundering Bolt",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		}],
	}
	strategy.set("_llm_route_candidates_by_id", {
		"route:manual_attach_to_active_attack": active_attach_route,
		"route:primary_visible_engine": primary_route,
	})
	strategy.set("_llm_action_catalog", {
		"route:manual_attach_to_active_attack": active_attach_route,
		"route:primary_visible_engine": primary_route,
		"attach_energy:c21:active": {"id": "attach_energy:c21:active", "action_id": "attach_energy:c21:active", "type": "attach_energy", "position": "active"},
		"use_ability:bench_0:0": {"id": "use_ability:bench_0:0", "action_id": "use_ability:bench_0:0", "type": "use_ability"},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	})
	var tree: Dictionary = strategy.call("_candidate_route_fallback_tree")
	var branches: Array = tree.get("branches", []) if tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_eq(str(first_action.get("id", "")), "route:primary_visible_engine", "Response-error fallback should prefer primary engine over low-value active attach"),
	])


func test_llm_priority_candidate_route_repair_forces_pivot_attack_over_end() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var attach := {
		"id": "attach_energy:c31:bench_1",
		"action_id": "attach_energy:c31:bench_1",
		"type": "attach_energy",
		"position": "bench_1",
		"energy_type": "F",
	}
	var retreat := {
		"id": "retreat:active:bench_1",
		"action_id": "retreat:active:bench_1",
		"type": "retreat",
		"bench_position": "bench_1",
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var pivot_route := {
		"id": "route:pivot_to_primary_attack",
		"action_id": "route:pivot_to_primary_attack",
		"type": "route",
		"candidate_route": true,
		"priority": 970,
		"goal": "pivot_to_attack",
		"actions": [attach, retreat, end_turn],
		"future_goals": [{
			"id": "future:attack_after_pivot:bench_1:1:Thundering Bolt",
			"type": "attack",
			"future": true,
			"attack_name": "Thundering Bolt",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		}],
	}
	strategy.set("_llm_route_candidates_by_id", {"route:pivot_to_primary_attack": pivot_route})
	strategy.set("_llm_action_catalog", {
		"route:pivot_to_primary_attack": pivot_route,
		"attach_energy:c31:bench_1": attach,
		"retreat:active:bench_1": retreat,
		"end_turn": end_turn,
	})
	var weak_tree := {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [end_turn],
		}],
		"fallback_actions": [end_turn],
	}
	var repair: Dictionary = strategy.call("_repair_to_priority_candidate_route_in_tree", weak_tree)
	var repaired_tree: Dictionary = repair.get("tree", {}) if repair.get("tree", {}) is Dictionary else {}
	var branches: Array = repaired_tree.get("branches", []) if repaired_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var ids: Array[String] = []
	for raw: Variant in actions:
		if raw is Dictionary:
			ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_true(bool(repair.get("changed", false)), "Priority candidate repair should override a weak end-turn tree when a primary pivot attack route exists"),
		assert_eq(ids.size(), 3, "Repaired tree should expand the route into exact executable actions"),
		assert_eq(ids[0], "attach_energy:c31:bench_1", "Repaired pivot route should preserve the bench attach first"),
		assert_eq(ids[1], "retreat:active:bench_1", "Repaired pivot route should preserve the pivot second"),
		assert_eq(ids[2], "end_turn", "Repaired pivot route should keep conversion terminal"),
	])


func test_llm_priority_candidate_route_repair_ignores_unselected_branch_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var sada := {
		"id": "play_trainer:c28",
		"action_id": "play_trainer:c28",
		"type": "play_trainer",
		"card": "Professor Sada's Vitality",
		"capability": "supporter_acceleration",
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var route := {
		"id": "route:raging_bolt_primary_visible_engine",
		"action_id": "route:raging_bolt_primary_visible_engine",
		"type": "route",
		"candidate_route": true,
		"priority": 988,
		"goal": "setup_to_primary_attack",
		"actions": [sada, end_turn],
		"future_goals": [{
			"id": "future:attack_after_visible_engine:active:1:Thundering Bolt",
			"type": "attack",
			"future": true,
			"attack_name": "Thundering Bolt",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		}],
	}
	strategy.set("_llm_route_candidates_by_id", {"route:raging_bolt_primary_visible_engine": route})
	strategy.set("_llm_action_catalog", {
		"route:raging_bolt_primary_visible_engine": route,
		"play_trainer:c28": sada,
		"end_turn": end_turn,
	})
	var weak_tree := {
		"branches": [
			{
				"when": [{"fact": "always"}],
				"actions": [end_turn],
			},
			{
				"when": [{"fact": "hand_has_card", "card": "Nonexistent Setup Card"}],
				"actions": [sada, end_turn],
			},
		],
		"fallback_actions": [end_turn],
	}
	var repair: Dictionary = strategy.call("_repair_to_priority_candidate_route_in_tree", weak_tree, gs, 0)
	var repaired_tree: Dictionary = repair.get("tree", {}) if repair.get("tree", {}) is Dictionary else {}
	var branches: Array = repaired_tree.get("branches", []) if repaired_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var ids: Array[String] = []
	for raw: Variant in actions:
		if raw is Dictionary:
			ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_true(bool(repair.get("changed", false)), "Priority route repair should ignore candidate actions in a branch whose conditions are not selected"),
		assert_eq(ids, ["play_trainer:c28", "end_turn"], "Selected always branch should be replaced by the visible-engine route"),
	])


func test_llm_priority_candidate_route_repair_forces_gust_ko_over_plain_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var gust := {
		"id": "play_trainer:c9",
		"action_id": "play_trainer:c9",
		"type": "play_trainer",
		"card": "Boss's Orders",
		"capability": "gust",
		"selection_policy": {"target_position": "bench_1"},
	}
	var attack := {
		"id": "attack:1:Thundering Bolt",
		"action_id": "attack:1:Thundering Bolt",
		"type": "attack",
		"attack_index": 1,
		"attack_name": "Thundering Bolt",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	var route := {
		"id": "route:gust_ko",
		"action_id": "route:gust_ko",
		"type": "route",
		"candidate_route": true,
		"priority": 990,
		"goal": "gust_ko",
		"actions": [gust, attack],
	}
	strategy.set("_llm_route_candidates_by_id", {"route:gust_ko": route})
	strategy.set("_llm_action_catalog", {
		"route:gust_ko": route,
		"play_trainer:c9": gust,
		"attack:1:Thundering Bolt": attack,
	})
	var weak_tree := {
		"branches": [{
			"when": [{"fact": "active_attack_ready", "attack_name": "Thundering Bolt"}],
			"actions": [attack],
		}],
		"fallback_actions": [{"id": "end_turn"}],
	}
	var repair: Dictionary = strategy.call("_repair_to_priority_candidate_route_in_tree", weak_tree, gs, 0)
	var repaired_tree: Dictionary = repair.get("tree", {}) if repair.get("tree", {}) is Dictionary else {}
	var branches: Array = repaired_tree.get("branches", []) if repaired_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var ids: Array[String] = []
	for raw: Variant in actions:
		if raw is Dictionary:
			ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_true(bool(repair.get("changed", false)), "Gust KO route should override a plain high-pressure attack because the attack target matters"),
		assert_eq(ids, ["play_trainer:c9", "attack:1:Thundering Bolt"], "Repaired gust route should execute gust before the same attack"),
	])


func test_llm_priority_candidate_route_repair_keeps_defensive_gust_capability() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gust := {
		"id": "play_trainer:c19",
		"action_id": "play_trainer:c19",
		"type": "play_trainer",
		"card": "Prime Catcher",
		"capability": "defensive_gust",
		"selection_policy": {"opponent_switch_target": "bench_3", "switch_target": "bench_0"},
		"card_rules": {"tags": ["gust"]},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var route := {
		"id": "route:defensive_gust_stall",
		"action_id": "route:defensive_gust_stall",
		"type": "route",
		"candidate_route": true,
		"priority": 975,
		"goal": "defensive_gust",
		"actions": [gust, end_turn],
	}
	var pal_pad := {
		"id": "play_trainer:c46",
		"action_id": "play_trainer:c46",
		"type": "play_trainer",
		"card": "Pal Pad",
	}
	strategy.set("_llm_route_candidates_by_id", {"route:defensive_gust_stall": route})
	strategy.set("_llm_action_catalog", {
		"route:defensive_gust_stall": route,
		"play_trainer:c19": {"id": "play_trainer:c19", "action_id": "play_trainer:c19", "type": "play_trainer", "card": "Prime Catcher", "capability": "gust", "card_rules": {"tags": ["gust"]}},
		"play_trainer:c46": pal_pad,
		"end_turn": end_turn,
	})
	var weak_tree := {
		"actions": [
			{"id": "play_trainer:c19", "interactions": {"opponent_switch_target": "bench_3", "switch_target": "bench_0"}},
			{"id": "play_trainer:c46"},
			{"id": "end_turn"},
		],
	}
	var repair: Dictionary = strategy.call("_repair_to_priority_candidate_route_in_tree", weak_tree)
	var repaired_tree: Dictionary = repair.get("tree", {}) if repair.get("tree", {}) is Dictionary else {}
	var branches: Array = repaired_tree.get("branches", []) if repaired_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_true(bool(repair.get("changed", false)), "Defensive gust route should replace a raw gust action so compiler preserves defensive intent"),
		assert_eq(str(first_action.get("id", "")), "play_trainer:c19", "Repaired defensive route should still execute the same gust card"),
		assert_eq(str(first_action.get("capability", "")), "defensive_gust", "Repaired defensive route must carry defensive_gust capability"),
		assert_eq(actions.size(), 2, "Repaired defensive route should not keep unrelated filler actions like Pal Pad"),
	])


func test_llm_priority_candidate_route_repair_forces_attach_ko_over_ready_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var attach := {
		"id": "attach_energy:c44:active",
		"action_id": "attach_energy:c44:active",
		"type": "attach_energy",
		"card": "Fighting Energy",
		"position": "active",
		"capability": "manual_attach",
	}
	var attack := {
		"id": "attack:1:Thundering Bolt",
		"action_id": "attack:1:Thundering Bolt",
		"type": "attack",
		"attack_index": 1,
		"attack_name": "Thundering Bolt",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var route := {
		"id": "route:manual_attach_to_attack",
		"action_id": "route:manual_attach_to_attack",
		"type": "route",
		"candidate_route": true,
		"priority": 980,
		"goal": "manual_attach_to_primary_attack",
		"actions": [attach, end_turn],
	}
	strategy.set("_llm_route_candidates_by_id", {"route:manual_attach_to_attack": route})
	strategy.set("_llm_action_catalog", {
		"route:manual_attach_to_attack": route,
		"attach_energy:c44:active": attach,
		"attack:1:Thundering Bolt": attack,
		"end_turn": end_turn,
	})
	var weak_tree := {
		"branches": [{
			"when": [{"fact": "active_attack_ready", "attack_name": "Thundering Bolt"}],
			"actions": [attack],
		}],
		"fallback_actions": [end_turn],
	}
	var repair: Dictionary = strategy.call("_repair_to_priority_candidate_route_in_tree", weak_tree, gs, 0)
	var repaired_tree: Dictionary = repair.get("tree", {}) if repair.get("tree", {}) is Dictionary else {}
	var branches: Array = repaired_tree.get("branches", []) if repaired_tree.get("branches", []) is Array else []
	var first_branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var actions: Array = first_branch.get("actions", []) if first_branch.get("actions", []) is Array else []
	var ids: Array[String] = []
	for raw: Variant in actions:
		if raw is Dictionary:
			ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_true(bool(repair.get("changed", false)), "Manual attach KO route should override a ready but lower-damage current attack"),
		assert_eq(ids, ["attach_energy:c44:active", "end_turn"], "Repaired route should preserve attach then conversion terminal"),
	])


func test_raging_bolt_llm_productive_engine_repair_respects_deck_draw_risk() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var shoes := {
		"id": "play_trainer:c32",
		"action_id": "play_trainer:c32",
		"type": "play_trainer",
		"card": "Trekking Shoes",
		"card_rules": {"tags": ["draw", "discard", "filter_engine"]},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	strategy.set("_llm_action_catalog", {
		"play_trainer:c32": shoes,
		"end_turn": end_turn,
	})
	var tree := {"actions": [end_turn]}
	var risky_gs := _make_game_state(10)
	for i: int in 12:
		risky_gs.players[0].deck.append(CardInstance.create(_make_trainer_cd("Risk deck %d" % i), 0))
	var safe_gs := _make_game_state(10)
	for i: int in 13:
		safe_gs.players[0].deck.append(CardInstance.create(_make_trainer_cd("Safe deck %d" % i), 0))
	var risky_repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", tree, risky_gs, 0)
	var safe_repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", tree, safe_gs, 0)
	var safe_added: Array = safe_repair.get("added_actions", []) if safe_repair.get("added_actions", []) is Array else []
	var safe_first_id := ""
	if not safe_added.is_empty() and safe_added[0] is Dictionary:
		safe_first_id = str((safe_added[0] as Dictionary).get("id", ""))
	return run_checks([
		assert_eq(int(risky_repair.get("added_count", 0)), 0, "Productive-engine repair must not insert draw/filter actions once deck_draw_risk is active"),
		assert_eq(int(safe_repair.get("added_count", 0)), 1, "Productive-engine repair should still insert safe draw/filter above the risk threshold"),
		assert_eq(safe_first_id, "play_trainer:c32", "Safe-threshold repair should insert the visible Trekking Shoes action"),
	])


func test_raging_bolt_llm_low_deck_rules_fallback_blocks_unplanned_draw_ability() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	player.deck.clear()
	for i: int in 5:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon_slot := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon_slot)
	var score := float(strategy.call("score_action_absolute", {
		"kind": "use_ability",
		"source_slot": ogerpon_slot,
		"ability_index": 0,
	}, gs, 0))
	return assert_true(score <= -1000.0, "Raging Bolt LLM rules fallback must block unplanned Ogerpon draw ability once deck is locked")


func test_raging_bolt_llm_retargets_core_energy_from_doomed_active_to_backup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.damage_counters = 160
	var backup := _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.append(backup)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var active_attach := {"kind": "attach_energy", "card": lightning, "target_slot": player.active_pokemon}
	var backup_attach := {"kind": "attach_energy", "card": lightning, "target_slot": backup}
	var active_score := float(strategy.call("score_action_absolute", active_attach, gs, 0))
	var backup_score := float(strategy.call("score_action_absolute", backup_attach, gs, 0))
	return run_checks([
		assert_true(active_score <= -1000.0, "Do not spend a lone core Energy on a doomed active Raging Bolt when it still cannot attack (score=%f)" % active_score),
		assert_true(backup_score >= 88000.0, "The same core Energy should be retargeted to a backup Raging Bolt handoff attacker (score=%f)" % backup_score),
	])


func test_raging_bolt_llm_allows_doomed_active_attach_when_it_enables_burst() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.damage_counters = 160
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var active_attach := {"kind": "attach_energy", "card": lightning, "target_slot": player.active_pokemon}
	var active_score := float(strategy.call("score_action_absolute", active_attach, gs, 0))
	return assert_true(active_score > -1000.0, "A doomed active may still receive the missing core Energy when that attach completes Thundering Bolt (score=%f)" % active_score)


func test_raging_bolt_llm_payload_exposes_ready_backup_handoff_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.damage_counters = 230
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var backup := _make_slot(_make_raging_bolt_cd(), 0)
	backup.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	backup.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.bench.append(backup)
	var prime_cd := _make_trainer_cd("Prime Catcher", "Item")
	prime_cd.name_en = "Prime Catcher"
	var prime := CardInstance.create(prime_cd, 0)
	player.hand.append(prime)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": prime, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var route: Dictionary = {}
	for raw_route: Variant in payload.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:raging_bolt_ready_backup_handoff":
			route = raw_route
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	var policy: Dictionary = first_action.get("selection_policy", {}) if first_action.get("selection_policy", {}) is Dictionary else {}
	var fallback_tree: Dictionary = strategy.call("_candidate_route_fallback_tree")
	var branches: Array = fallback_tree.get("branches", []) if fallback_tree.get("branches", []) is Array else []
	var fallback_actions: Array = (branches[0] as Dictionary).get("actions", []) if not branches.is_empty() and branches[0] is Dictionary and (branches[0] as Dictionary).get("actions", []) is Array else []
	var fallback_first: Dictionary = fallback_actions[0] if not fallback_actions.is_empty() and fallback_actions[0] is Dictionary else {}
	return run_checks([
		assert_true(not route.is_empty(), "Payload should expose a ready-backup Raging Bolt handoff route when Prime Catcher can pivot to it"),
		assert_true(str(first_action.get("id", "")).begins_with("play_trainer:"), "Ready-backup handoff route should start from the exact Prime Catcher action"),
		assert_eq(str(policy.get("own_bench_target", "")), "bench_0", "Ready-backup handoff route should specify the own bench target for switch effects"),
		assert_eq(str(fallback_first.get("id", "")), "route:raging_bolt_ready_backup_handoff", "Fallback repair should prefer ready-backup handoff over active setup/end routes"),
	])


func test_raging_bolt_llm_visible_engine_route_skips_future_sada_ref() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var payload := {
		"legal_actions": [
			{"id": "play_trainer:c54", "action_id": "play_trainer:c54", "type": "play_trainer", "card": "Earthen Vessel"},
			{"id": "attach_energy:c15:active", "action_id": "attach_energy:c15:active", "type": "attach_energy", "card": "Lightning Energy", "target": "Raging Bolt ex"},
			{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
			{"id": "play_trainer:c28", "action_id": "play_trainer:c28", "type": "play_trainer", "card": "Professor Sada's Vitality", "summary": "future: play Professor Sada's Vitality after this turn creates basic Energy in discard"},
		],
		"future_actions": [{
			"id": "future:attack_after_attach:active:1:Thundering Bolt",
			"action_id": "future:attack_after_attach:active:1:Thundering Bolt",
			"type": "attack",
			"future": true,
			"attack_index": 1,
			"attack_name": "Thundering Bolt",
			"source_pokemon": "Raging Bolt ex",
		}],
		"turn_tactical_facts": {
			"primary_attack_name": "Thundering Bolt",
			"primary_attack_reachable_after_visible_engine": true,
			"primary_attack_route": ["energy_search", "discard_energy_acceleration_supporter", "manual_attach", "Thundering Bolt"],
			"best_manual_attach_to_primary_attack_action_id": "attach_energy:c15:active",
			"deck_count": 15,
		},
		"candidate_routes": [{"route_action_id": "route:preserve_end", "goal": "fallback", "actions": [{"id": "end_turn"}]}],
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var route: Dictionary = {}
	for raw_route: Variant in augmented.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:raging_bolt_primary_visible_engine":
			route = raw_route
			break
	var ids: Array[String] = []
	for raw_action: Variant in route.get("actions", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_true(not route.is_empty(), "Visible-engine route should still be generated"),
		assert_false(ids.has("play_trainer:c28"), "Visible-engine route must not enqueue a future-only Sada ref as an immediate action"),
		assert_true(ids.has("play_trainer:c54"), "Visible-engine route should keep the executable Earthen Vessel action"),
		assert_true(ids.has("attach_energy:c15:active"), "Visible-engine route should keep the executable missing Lightning attach"),
	])


func test_llm_route_action_registry_registers_and_expands_routes_generically() -> String:
	var registry := _new_route_action_registry()
	if registry == null:
		return "LLMRouteActionRegistry.gd should exist"
	var catalog := {
		"use_ability:bench_0:0": {
			"id": "use_ability:bench_0:0",
			"action_id": "use_ability:bench_0:0",
			"type": "use_ability",
			"pokemon": "Teal Mask Ogerpon ex",
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var registered: Dictionary = registry.call("register_payload_candidate_routes", {
		"candidate_routes": [{
			"id": "primary_visible_engine",
			"route_action_id": "route:primary_visible_engine",
			"priority": 900,
			"actions": [
				{"id": "use_ability:bench_0:0"},
				{
					"id": "play_trainer:c52",
					"selection_policy": {"search": ["Fighting Energy"]},
					"allow_deck_draw_lock": true,
					"deck_draw_lock_exception": "primary_attack_unlock",
				},
				{"id": "end_turn"},
			],
		}],
	}, catalog)
	var registered_catalog: Dictionary = registered.get("catalog", {})
	var routes_by_id: Dictionary = registered.get("routes_by_id", {})
	var expanded: Array = registry.call("materialize_action_ref_array", [{"id": "route:primary_visible_engine"}], registered_catalog)
	var second_policy: Dictionary = {}
	var second_action: Dictionary = {}
	if expanded.size() >= 2 and expanded[1] is Dictionary:
		second_action = expanded[1] as Dictionary
		second_policy = second_action.get("selection_policy", {})
	return run_checks([
		assert_true(registered_catalog.has("route:primary_visible_engine"), "Shared registry should add route id to action catalog"),
		assert_true(routes_by_id.has("route:primary_visible_engine"), "Shared registry should return route map"),
		assert_eq(expanded.size(), 3, "Shared registry should expand route into exact actions"),
		assert_eq(str((expanded[0] as Dictionary).get("id", "")), "use_ability:bench_0:0", "Expanded route should preserve order"),
		assert_false(second_policy.is_empty(), "Shared registry should preserve route action selection_policy"),
		assert_true(bool(second_action.get("allow_deck_draw_lock", false)), "Shared registry should preserve route action deck-draw-lock metadata"),
		assert_eq(str(second_action.get("deck_draw_lock_exception", "")), "primary_attack_unlock", "Shared registry should preserve deck-draw-lock exception reason"),
		assert_eq(str(registry.call("best_route_action_id", routes_by_id)), "route:primary_visible_engine", "Shared registry should expose best route id"),
	])


func test_llm_route_compiler_inserts_safe_engine_before_end_turn() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var ogerpon_id := "use_ability:bench_0:0"
	var catalog := {
		ogerpon_id: {
			"id": ogerpon_id,
			"action_id": ogerpon_id,
			"type": "use_ability",
			"pokemon": "Teal Mask Ogerpon ex",
			"requires_interaction": true,
			"card_rules": {"tags": ["energy_related", "draw", "charge_engine", "productive_engine"]},
			"interaction_schema": {"basic_energy_from_hand": {"type": "string"}},
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"card_rules": {"tags": ["search_deck", "energy_related", "discard", "productive_engine"]},
			"interaction_schema": {"discard_cards": {"type": "array"}, "search_energy": {"type": "array"}},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var first: Dictionary = queue[0] if not queue.is_empty() and queue[0] is Dictionary else {}
	return run_checks([
		assert_false(queue.is_empty(), "Route compiler should return a queue"),
		assert_eq(str(first.get("action_id", "")), ogerpon_id, "Route compiler should insert a charge/draw engine before premature end_turn"),
		assert_eq(str(first.get("capability", "")), "charge_and_draw", "Inserted Ogerpon ability should be tagged as charge_and_draw"),
		assert_true(int((result.get("inserted_actions", []) as Array).size()) > 0, "Compile result should report inserted actions"),
	])


func test_llm_route_compiler_removes_gust_without_attack_goal() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var boss_id := "play_trainer:c41"
	var attach_id := "attach_energy:c16:active"
	var catalog := {
		boss_id: {
			"id": boss_id,
			"action_id": boss_id,
			"type": "play_trainer",
			"card": "Boss's Orders",
			"card_rules": {"tags": ["gust"]},
		},
		attach_id: {
			"id": attach_id,
			"action_id": attach_id,
			"type": "attach_energy",
			"card": "Lightning Energy",
			"position": "active",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": boss_id, "action_id": boss_id, "type": "play_trainer", "card": "Boss's Orders", "card_rules": {"tags": ["gust"]}},
		{"id": attach_id, "action_id": attach_id, "type": "attach_energy", "card": "Lightning Energy", "position": "active"},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_false(ids.has(boss_id), "Compiler must remove gust-only resource spend when the route has no attack or future attack goal"),
		assert_true(ids.has(attach_id), "Compiler should preserve non-gust setup actions in the same route"),
		assert_true((result.get("notes", []) as Array).has("removed_gust_without_attack_goal"), "Compile result should audit removed gust-only actions"),
	])


func test_llm_route_compiler_preserves_defensive_gust_capability() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var boss_id := "play_trainer:c41"
	var catalog := {
		boss_id: {
			"id": boss_id,
			"action_id": boss_id,
			"type": "play_trainer",
			"card": "Boss's Orders",
			"capability": "defensive_gust",
			"card_rules": {"tags": ["gust"]},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": boss_id, "action_id": boss_id, "type": "play_trainer", "card": "Boss's Orders", "capability": "defensive_gust", "card_rules": {"tags": ["gust"]}},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has(boss_id), "Compiler should preserve a defensive gust route even without a current attack"),
		assert_false((result.get("notes", []) as Array).has("removed_gust_without_attack_goal"), "Defensive gust routes should not be audited as removed gust-only actions"),
	])


func test_llm_route_compiler_does_not_auto_insert_hand_reset_supporter() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var catalog := {
		"play_trainer:c49": {
			"id": "play_trainer:c49",
			"action_id": "play_trainer:c49",
			"type": "play_trainer",
			"card": "Iono",
			"card_rules": {"name_en": "Iono", "tags": ["draw"]},
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"card_rules": {"name_en": "Earthen Vessel", "tags": ["search_deck", "energy_related", "discard"]},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_false(ids.has("play_trainer:c49"), "Compiler must not auto-insert Iono/Research hand reset into a visible setup route"),
		assert_true(ids.has("play_trainer:c52"), "Compiler should still insert deterministic visible setup engines"),
	])


func test_llm_route_compiler_removes_selected_hand_reset_when_setup_is_visible() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var gs := _make_game_state(0)
	for i: int in 5:
		gs.players[0].hand.append(CardInstance.create(_make_trainer_cd("Hand card %d" % i), 0))
	var catalog := {
		"play_trainer:c49": {
			"id": "play_trainer:c49",
			"action_id": "play_trainer:c49",
			"type": "play_trainer",
			"card": "Iono",
			"card_rules": {"name_en": "Iono", "tags": ["draw"]},
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"card_rules": {"name_en": "Earthen Vessel", "tags": ["search_deck", "energy_related", "discard"]},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "play_trainer:c49", "action_id": "play_trainer:c49", "type": "play_trainer", "card": "Iono", "card_rules": {"name_en": "Iono", "tags": ["draw"]}},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog, gs, 0)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_false(ids.has("play_trainer:c49"), "Compiler should strip selected Iono/Research when deterministic setup is visible and hand is not dead"),
		assert_true(ids.has("play_trainer:c52"), "Compiler should replace the hand reset with deterministic setup when available"),
		assert_true((result.get("notes", []) as Array).has("removed_hand_reset_before_visible_setup"), "Compile result should audit removed hand-reset actions"),
	])


func test_llm_route_compiler_inserts_at_most_one_manual_attach() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var catalog := {
		"attach_energy:c44:active": {
			"id": "attach_energy:c44:active",
			"action_id": "attach_energy:c44:active",
			"type": "attach_energy",
			"card": "Fighting Energy",
			"position": "active",
		},
		"attach_energy:c45:active": {
			"id": "attach_energy:c45:active",
			"action_id": "attach_energy:c45:active",
			"type": "attach_energy",
			"card": "Fighting Energy",
			"position": "active",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var manual_attach_count := 0
	for raw: Variant in queue:
		if raw is Dictionary and str((raw as Dictionary).get("type", "")) == "attach_energy":
			manual_attach_count += 1
	return run_checks([
		assert_eq(manual_attach_count, 1, "Route compiler must not insert more than one manual attach into a turn queue"),
	])


func test_llm_route_compiler_inserts_draw_and_recovery_before_end_turn() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var catalog := {
		"use_ability:bench_3:0": {
			"id": "use_ability:bench_3:0",
			"action_id": "use_ability:bench_3:0",
			"type": "use_ability",
			"pokemon": "Fezandipiti ex",
			"card_rules": {"name_en": "Fezandipiti ex", "effect_id": "ab6c3357e2b8a8385a68da738f41e0c1"},
		},
		"play_trainer:c27": {
			"id": "play_trainer:c27",
			"action_id": "play_trainer:c27",
			"type": "play_trainer",
			"card": "Night Stretcher",
			"card_rules": {"tags": ["recover_to_hand", "energy_related", "pokemon_related"]},
			"interaction_schema": {"night_stretcher_choice": {"type": "string"}},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var ids: Array[String] = []
	var capabilities: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
			capabilities.append(str((raw_action as Dictionary).get("capability", "")))
	return run_checks([
		assert_true(ids.has("use_ability:bench_3:0"), "Route compiler should insert Fezandipiti draw ability before end_turn"),
		assert_true(ids.has("play_trainer:c27"), "Route compiler should insert Night Stretcher recovery before end_turn"),
		assert_true(capabilities.has("draw_ability"), "Fezandipiti should be classified as draw_ability"),
		assert_true(capabilities.has("resource_recovery"), "Night Stretcher should be classified as resource_recovery"),
	])


func test_llm_route_compiler_does_not_insert_turn_ending_draw_before_setup() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var catalog := {
		"use_ability:active:0": {
			"id": "use_ability:active:0",
			"action_id": "use_ability:active:0",
			"type": "use_ability",
			"pokemon": "Rotom V",
			"ability": "Quick Charge",
			"card_rules": {"effect_id": "8ef5ff61fd97838af568f00fe3b0e3ea", "tags": ["draw", "ability_engine", "ends_turn"]},
			"ability_rules": {"tags": ["draw", "ends_turn"]},
		},
		"play_trainer:c12": {
			"id": "play_trainer:c12",
			"action_id": "play_trainer:c12",
			"type": "play_trainer",
			"card": "Buddy-Buddy Poffin",
			"card_rules": {"tags": ["search_deck", "bench_related", "pokemon_related"]},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var ids: Array[String] = []
	var capabilities: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
			capabilities.append(str((raw_action as Dictionary).get("capability", "")))
	return run_checks([
		assert_false(ids.has("use_ability:active:0"), "Compiler must not auto-insert Rotom-like turn-ending draw before end_turn"),
		assert_true(ids.has("play_trainer:c12"), "Compiler should still insert visible setup search before end_turn"),
		assert_false(capabilities.has("terminal_draw_ability"), "Terminal draw abilities should not be treated as safe insertions"),
	])


func test_llm_route_compiler_skips_future_actions_as_insertions() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var future_attack_id := "future:attack_after_search_attach:active:1:thundering bolt"
	var catalog := {
		future_attack_id: {
			"id": future_attack_id,
			"action_id": future_attack_id,
			"type": "attack",
			"future": true,
			"attack_name": "Thundering Bolt",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"card_rules": {"tags": ["search_deck", "energy_related", "discard", "productive_engine"]},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var ids: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_false(ids.has(future_attack_id), "Route compiler must not insert future actions as immediately executable steps"),
		assert_true(ids.has("play_trainer:c52"), "Route compiler should still insert executable setup action before end_turn"),
	])


func test_llm_route_compiler_does_not_insert_churn_before_future_attack_goal() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var future_attack_id := "future:attack_after_visible_engine:active:1:thundering_bolt"
	var catalog := {
		"play_trainer:c29": {
			"id": "play_trainer:c29",
			"action_id": "play_trainer:c29",
			"type": "play_trainer",
			"card": "Professor Sada's Vitality",
			"card_rules": {"name_en": "Professor Sada's Vitality"},
		},
		"use_ability:bench_1:0": {
			"id": "use_ability:bench_1:0",
			"action_id": "use_ability:bench_1:0",
			"type": "use_ability",
			"pokemon": "Radiant Greninja",
			"ability_rules": {"name": "Concealed Cards", "text": "Discard an Energy card from your hand. Draw 2 cards."},
			"card_rules": {"tags": ["discard", "draw"]},
		},
		"play_trainer:c32": {
			"id": "play_trainer:c32",
			"action_id": "play_trainer:c32",
			"type": "play_trainer",
			"card": "Trekking Shoes",
			"card_rules": {"tags": ["draw", "discard", "filter_engine"]},
		},
		"play_trainer:c33": {
			"id": "play_trainer:c33",
			"action_id": "play_trainer:c33",
			"type": "play_trainer",
			"card": "Energy Retrieval",
			"card_rules": {"tags": ["recover_to_hand", "energy_related"]},
		},
		future_attack_id: {
			"id": future_attack_id,
			"action_id": future_attack_id,
			"type": "attack",
			"future": true,
			"attack_name": "Thundering Bolt",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reachable_with_known_resources": true,
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "play_trainer:c29", "action_id": "play_trainer:c29", "type": "play_trainer", "card": "Professor Sada's Vitality"},
		{"id": future_attack_id, "action_id": future_attack_id, "type": "attack", "future": true, "attack_name": "Thundering Bolt"},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var ids: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true((result.get("future_goals", []) as Array).size() == 1, "Future attack should be retained as a goal, not executable action"),
		assert_false(ids.has("use_ability:bench_1:0"), "Compiler must not insert Greninja discard-draw before an exposed future attack goal"),
		assert_false(ids.has("play_trainer:c32"), "Compiler must not insert Trekking Shoes before an exposed future attack goal"),
		assert_false(ids.has("play_trainer:c33"), "Compiler must not insert recovery churn before an exposed future attack goal"),
	])


func test_llm_route_compiler_removes_low_value_redraw_attack_when_deck_is_risky() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var gs := _make_game_state(7)
	for i: int in 10:
		gs.players[0].deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	for i: int in 5:
		gs.players[0].hand.append(CardInstance.create(_make_trainer_cd("Hand card %d" % i), 0))
	var low_attack_id := "attack:0:bursting_roar"
	var ogerpon_id := "use_ability:bench_0:0"
	var catalog := {
		low_attack_id: {
			"id": low_attack_id,
			"action_id": low_attack_id,
			"type": "attack",
			"attack_index": 0,
			"attack_name": "Bursting Roar",
			"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
		},
		ogerpon_id: {
			"id": ogerpon_id,
			"action_id": ogerpon_id,
			"type": "use_ability",
			"pokemon": "Teal Mask Ogerpon ex",
			"card_rules": {"tags": ["energy_related", "draw", "charge_engine", "productive_engine"]},
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": low_attack_id, "action_id": low_attack_id, "type": "attack", "attack_index": 0, "attack_name": "Bursting Roar", "attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"}},
	], catalog, gs, 0)
	var queue: Array = result.get("queue", [])
	var ids: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_false(ids.has(low_attack_id), "Deck-risk compiler must remove low-value redraw attacks instead of forcing deckout pressure"),
		assert_false(ids.has(ogerpon_id), "Low-deck compiler must not replace risky redraw with another deck-draw engine"),
		assert_true((result.get("notes", []) as Array).has("removed_low_value_attack_for_deck_or_hand_risk"), "Compile result should audit why the redraw attack was removed"),
	])


func test_llm_route_compiler_removes_explicit_draw_actions_when_deck_is_locked() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var gs := _make_game_state(7)
	for i: int in 4:
		gs.players[0].deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	var shoes_id := "play_trainer:c31"
	var greninja_id := "use_ability:bench_0:0"
	var ogerpon_id := "use_ability:bench_1:0"
	var fez_id := "use_ability:bench_2:0"
	var catalog := {
		shoes_id: {
			"id": shoes_id,
			"action_id": shoes_id,
			"type": "play_trainer",
			"card": "Trekking Shoes",
			"card_rules": {"tags": ["draw", "discard", "filter_engine"]},
		},
		greninja_id: {
			"id": greninja_id,
			"action_id": greninja_id,
			"type": "use_ability",
			"pokemon": "Radiant Greninja",
			"requires_interaction": true,
			"interaction_schema": {"discard_card": {"type": "string"}},
		},
		ogerpon_id: {
			"id": ogerpon_id,
			"action_id": ogerpon_id,
			"type": "use_ability",
			"pokemon": "厄诡椪 碧草面具ex",
			"ability": "碧草之舞",
		},
		fez_id: {
			"id": fez_id,
			"action_id": fez_id,
			"type": "use_ability",
			"pokemon": "吉雉鸡ex",
			"ability": "化危为吉",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": shoes_id, "action_id": shoes_id, "type": "play_trainer", "card": "Trekking Shoes", "card_rules": {"tags": ["draw", "discard", "filter_engine"]}},
		{"id": greninja_id, "action_id": greninja_id, "type": "use_ability", "pokemon": "Radiant Greninja", "interaction_schema": {"discard_card": {"type": "string"}}},
		{"id": ogerpon_id, "action_id": ogerpon_id, "type": "use_ability", "pokemon": "厄诡椪 碧草面具ex", "ability": "碧草之舞"},
		{"id": fez_id, "action_id": fez_id, "type": "use_ability", "pokemon": "吉雉鸡ex", "ability": "化危为吉"},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog, gs, 0)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_false(ids.has(shoes_id), "Low-deck compiler must remove explicit Trekking Shoes from the LLM route"),
		assert_false(ids.has(greninja_id), "Low-deck compiler must remove explicit discard-to-draw abilities from the LLM route"),
		assert_false(ids.has(ogerpon_id), "Low-deck compiler must remove explicit Ogerpon charge-and-draw abilities from the LLM route"),
		assert_false(ids.has(fez_id), "Low-deck compiler must remove explicit Fezandipiti draw abilities from the LLM route"),
		assert_true(ids.has("end_turn"), "Low-deck compiler should preserve terminal end_turn after removing risky draw actions"),
		assert_true((result.get("notes", []) as Array).has("removed_deck_draw_risk_actions"), "Compile result should audit deck-draw risk removals"),
	])


func test_llm_route_compiler_preserves_attack_unlock_supporter_under_deck_lock() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var gs := _make_game_state(16)
	for i: int in 8:
		gs.players[0].deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	var sada_id := "play_trainer:c30"
	var catalog := {
		sada_id: {
			"id": sada_id,
			"action_id": sada_id,
			"type": "play_trainer",
			"card": "Professor Sada's Vitality",
			"capability": "supporter_acceleration",
			"allow_deck_draw_lock": true,
			"deck_draw_lock_exception": "primary_attack_unlock",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{
			"id": sada_id,
			"action_id": sada_id,
			"type": "play_trainer",
			"card": "Professor Sada's Vitality",
			"capability": "supporter_acceleration",
			"allow_deck_draw_lock": true,
			"deck_draw_lock_exception": "primary_attack_unlock",
		},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog, gs, 0)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has(sada_id), "Low-deck compiler should preserve a marked Sada action when it unlocks the primary attack"),
		assert_false((result.get("notes", []) as Array).has("removed_deck_draw_risk_actions"), "Preserved attack-unlock Sada should not be audited as removed draw risk"),
	])


func test_llm_route_compiler_inherits_route_deck_lock_exception_for_exact_action() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var gs := _make_game_state(18)
	for i: int in 8:
		gs.players[0].deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	var sada_id := "play_trainer:c27"
	var route_id := "route:raging_bolt_primary_visible_engine"
	var catalog := {
		sada_id: {
			"id": sada_id,
			"action_id": sada_id,
			"type": "play_trainer",
			"card": "Professor Sada's Vitality",
			"capability": "supporter_acceleration",
		},
		route_id: {
			"id": route_id,
			"action_id": route_id,
			"type": "route",
			"candidate_route": true,
			"goal": "setup_to_primary_attack",
			"priority": 988,
			"actions": [{
				"id": sada_id,
				"action_id": sada_id,
				"type": "play_trainer",
				"card": "Professor Sada's Vitality",
				"capability": "supporter_acceleration",
				"allow_deck_draw_lock": true,
				"deck_draw_lock_exception": "primary_attack_unlock",
			}, {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}],
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": sada_id, "action_id": sada_id, "type": "play_trainer", "card": "Professor Sada's Vitality", "capability": "supporter_acceleration"},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog, gs, 0)
	var ids: Array[String] = []
	for raw_action: Variant in result.get("queue", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has(sada_id), "Low-deck compiler should inherit route metadata when LLM outputs the exact Sada action instead of the route id"),
		assert_false((result.get("notes", []) as Array).has("removed_deck_draw_risk_actions"), "Inherited route metadata should prevent false deck-draw-risk removal"),
	])


func test_llm_route_compiler_resolves_virtual_and_removes_future_from_queue() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var real_ogerpon_id := "use_ability:bench_1:0"
	var future_attack_id := "future:attack_after_pivot:bench_0:0:setup attack"
	var catalog := {
		real_ogerpon_id: {
			"id": real_ogerpon_id,
			"action_id": real_ogerpon_id,
			"type": "use_ability",
			"pokemon": "厄诡椪 碧草面具ex",
			"card_rules": {
				"name": "厄诡椪 碧草面具ex",
				"name_en": "Teal Mask Ogerpon ex",
				"tags": ["energy_related", "draw", "charge_engine", "productive_engine"],
			},
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"card_rules": {"tags": ["search_deck", "energy_related", "discard", "productive_engine"]},
		},
		future_attack_id: {
			"id": future_attack_id,
			"action_id": future_attack_id,
			"type": "attack",
			"future": true,
			"attack_name": "setup attack",
			"reachable_with_known_resources": false,
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "virtual:teal_mask_ogerpon_ability", "action_id": "virtual:teal_mask_ogerpon_ability", "type": "use_ability", "pokemon": "Teal Mask Ogerpon ex"},
		{"id": future_attack_id, "action_id": future_attack_id, "type": "attack", "future": true, "attack_name": "setup attack"},
	], catalog)
	var queue: Array = result.get("queue", [])
	var ids: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has(real_ogerpon_id), "Virtual Ogerpon action should resolve to a real legal ability action"),
		assert_false(ids.has("virtual:teal_mask_ogerpon_ability"), "Virtual actions must not remain in the executable queue"),
		assert_false(ids.has(future_attack_id), "Future actions must not remain in the executable queue"),
		assert_true(ids.has("end_turn"), "Compiler should close the route after removing a future terminal"),
		assert_true((result.get("future_goals", []) as Array).size() == 1, "Removed future action should be retained as a non-executable future goal for audit"),
	])


func test_llm_route_compiler_reports_premature_end_turn_when_it_cannot_insert() -> String:
	var compiler := _new_route_compiler()
	if compiler == null:
		return "LLMRouteCompiler.gd should exist"
	var catalog := {
		"attach_energy:c20:active": {
			"id": "attach_energy:c20:active",
			"action_id": "attach_energy:c20:active",
			"type": "attach_energy",
			"card": "Basic Grass Energy",
			"resource_conflicts": ["play_trainer:c52"],
		},
		"play_trainer:c52": {
			"id": "play_trainer:c52",
			"action_id": "play_trainer:c52",
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"card_rules": {"tags": ["search_deck", "energy_related", "discard", "productive_engine"]},
			"resource_conflicts": ["attach_energy:c20:active"],
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	var result: Dictionary = compiler.call("compile_queue", [
		{"id": "attach_energy:c20:active", "action_id": "attach_energy:c20:active", "type": "attach_energy", "resource_conflicts": ["play_trainer:c52"]},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	], catalog)
	return run_checks([
		assert_true(bool(result.get("blocked_end_turn", false)), "Premature end_turn should be blocked when a high-value action was missed but could not be inserted safely"),
		assert_true((result.get("inserted_actions", []) as Array).is_empty(), "Conflicting high-value action should not be inserted"),
	])


func test_raging_bolt_llm_repairs_missing_safe_engine_before_terminal() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.abilities = [{"name": "Teal Dance", "text": "Attach a Grass Energy from your hand to this Pokemon. Draw a card."}]
	player.bench.clear()
	player.bench.append(_make_slot(ogerpon_cd, 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	])
	var attack_id := ""
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("type", "")) == "attack":
			attack_id = str((raw as Dictionary).get("id", ""))
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {"actions": [{"id": attack_id}]})
	var repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", materialized)
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.size() >= 2, "Productive engine repair should add Ogerpon before terminal attack"),
		assert_eq(ids[0], "use_ability:bench_0:0", "Ogerpon charge+draw should be inserted before attacking when it does not conflict"),
		assert_eq(ids[ids.size() - 1], attack_id, "Terminal attack should remain last after productive engine repair"),
	])


func test_raging_bolt_llm_repairs_missing_filter_engine_before_end_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var shoes_cd := _make_trainer_cd("Trekking Shoes", "Item")
	shoes_cd.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	shoes_cd.description = "Look at the top card of your deck. You may put it into your hand or discard it and draw a card."
	var shoes := CardInstance.create(shoes_cd, 0)
	player.hand.append(shoes)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {"actions": [{"id": "end_turn"}]})
	var repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", materialized)
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has("play_trainer:c%d" % int(shoes.instance_id)), "Productive engine repair should add Trekking Shoes before ending a no-attack route"),
		assert_eq(ids[ids.size() - 1], "end_turn", "End turn should remain last after filter engine repair"),
	])


func test_llm_rejects_shallow_setup_branch_when_visible_engine_attack_is_reachable() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	greninja_cd.abilities = [{"name": "Concealed Cards", "text": "Discard an Energy card from your hand. Draw 2 cards."}]
	player.bench.clear()
	player.bench.append(_make_slot(greninja_cd, 0))
	var vessel_cd := _make_trainer_cd("Earthen Vessel", "Item")
	vessel_cd.effect_id = "e366f56ecd3f805a28294109a1a37453"
	vessel_cd.description = "Discard 1 card from your hand. Search your deck for up to 2 Basic Energy cards."
	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter")
	sada_cd.description = "Choose up to 2 Basic Energy cards from your discard pile and attach them to your Ancient Pokemon in any way you like. Draw 3 cards."
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var vessel := CardInstance.create(vessel_cd, 0)
	var sada := CardInstance.create(sada_cd, 0)
	player.hand.append(nest)
	player.hand.append(vessel)
	player.hand.append(sada)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": nest, "targets": [], "requires_interaction": true},
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var nest_id := ""
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("card", "")) == "Nest Ball":
			nest_id = str((raw as Dictionary).get("id", ""))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "hand_has_card", "card": "Nest Ball"}],
				"actions": [{"id": nest_id}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	var vessel_score: float = float(strategy.call("score_action_absolute", {"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true}, gs, 0))
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Shallow setup rejection should keep the turn usable"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Rejected shallow Nest Ball route should fall back to a candidate route when available"),
		assert_true(vessel_score > 0.0, "Candidate fallback should prefer the visible engine route over shallow Nest Ball"),
	])


func test_llm_payload_marks_hand_energy_resource_conflicts() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.abilities = [{"name": "Teal Dance", "text": "Attach a Grass Energy from your hand to this Pokemon. Draw a card."}]
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass)
	var ability_action := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability_index": 0, "requires_interaction": true}
	var attach_action := {"kind": "attach_energy", "card": grass, "target_slot": player.active_pokemon}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [ability_action, attach_action, {"kind": "end_turn"}])
	var current_actions: Array = _current_legal_actions_from_payload(payload)
	var ability_ref: Dictionary = {}
	var attach_ref: Dictionary = {}
	for raw: Variant in current_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", "")) == "use_ability":
			ability_ref = ref
		elif str(ref.get("type", "")) == "attach_energy":
			attach_ref = ref
	var ability_conflicts: Array = ability_ref.get("resource_conflicts", [])
	var attach_conflicts: Array = attach_ref.get("resource_conflicts", [])
	var instructions_text := "\n".join(payload.get("instructions", PackedStringArray()))
	var contract_check: Dictionary = strategy.call("_validate_decision_tree_contract", {
		"actions": [
			{"id": str(ability_ref.get("id", ""))},
			{"id": str(attach_ref.get("id", ""))},
		],
	})
	return run_checks([
		assert_false(ability_ref.is_empty(), "Ability legal action should be present"),
		assert_false(attach_ref.is_empty(), "Manual attach legal action should be present"),
		assert_true((ability_ref.get("may_consume_hand_energy_symbols", []) as Array).has("G"), "Ability should expose possible Grass hand-energy consumption"),
		assert_true((attach_ref.get("consumes_hand_card_ids", []) as Array).has("c%d" % int(grass.instance_id)), "Attach should expose exact consumed hand card id"),
		assert_true(ability_conflicts.has(str(attach_ref.get("id", ""))), "Ability should conflict with attaching the same only Grass resource"),
		assert_true(attach_conflicts.has(str(ability_ref.get("id", ""))), "Attach should conflict with ability using that Grass resource"),
		assert_false(bool(contract_check.get("valid", true)), "Contract validator should reject same-route resource conflicts"),
		assert_str_contains(instructions_text, "resource_conflicts", "Prompt should instruct LLM to respect resource conflicts"),
	])


func test_llm_post_processing_removes_resource_conflicting_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.abilities = [{"name": "Teal Dance", "text": "Attach a Grass Energy from your hand to this Pokemon. Draw a card."}]
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass)
	var ability_action := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability_index": 0, "requires_interaction": true}
	var attach_action := {"kind": "attach_energy", "card": grass, "target_slot": player.active_pokemon}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [ability_action, attach_action, {"kind": "end_turn"}])
	var current_actions: Array = _current_legal_actions_from_payload(payload)
	var ability_id := ""
	var attach_id := ""
	for raw_ref: Variant in current_actions:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		if str(ref.get("type", "")) == "use_ability":
			ability_id = str(ref.get("id", ""))
		elif str(ref.get("type", "")) == "attach_energy":
			attach_id = str(ref.get("id", ""))
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {
		"actions": [
			{"id": ability_id},
			{"id": attach_id},
			{"id": "end_turn"},
		],
	})
	var repair: Dictionary = strategy.call("_repair_resource_conflicts_in_tree", materialized)
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has(ability_id), "Earlier Ogerpon ability should remain"),
		assert_false(ids.has(attach_id), "Later manual attach that consumes the same only Grass should be pruned"),
		assert_true(ids.has("end_turn"), "Terminal action should remain after conflict pruning"),
		assert_eq(int(repair.get("removed_count", 0)), 1, "Resource repair should report one removed action"),
	])


func test_llm_post_processing_removes_exact_interaction_card_reuse() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.abilities = [{"name": "Teal Dance", "text": "Attach a Grass Energy from your hand to this Pokemon. Draw a card."}]
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	var grass_a := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var grass_b := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass_a)
	player.hand.append(grass_b)
	var ability_action := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability_index": 0, "requires_interaction": true}
	var attach_action := {"kind": "attach_energy", "card": grass_a, "target_slot": player.active_pokemon}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [ability_action, attach_action, {"kind": "end_turn"}])
	var current_actions: Array = _current_legal_actions_from_payload(payload)
	var ability_id := ""
	var attach_id := ""
	for raw_ref: Variant in current_actions:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		var ref_id := str(ref.get("id", ""))
		if str(ref.get("type", "")) == "use_ability":
			ability_id = ref_id
		elif str(ref.get("type", "")) == "attach_energy" and ref_id.contains("c%d" % int(grass_a.instance_id)):
			attach_id = ref_id
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {
		"actions": [
			{"id": ability_id, "interactions": {"energy_card_id": "c%d" % int(grass_a.instance_id)}},
			{"id": attach_id},
			{"id": "end_turn"},
		],
	})
	var repair: Dictionary = strategy.call("_repair_resource_conflicts_in_tree", materialized)
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ability_id != "", "Ogerpon ability legal action should be present"),
		assert_true(attach_id != "", "Manual attach legal action should be present for the exact Grass Energy"),
		assert_true(ids.has(ability_id), "Earlier exact-energy ability should remain"),
		assert_false(ids.has(attach_id), "Later attach reusing the exact interaction energy should be pruned"),
		assert_true(ids.has("end_turn"), "Terminal action should remain after exact-card conflict pruning"),
		assert_eq(int(repair.get("removed_count", 0)), 1, "Exact-card repair should report one removed action"),
	])


func test_llm_post_processing_removes_exact_discard_card_reuse() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	strategy.set("_llm_action_catalog", {
		"play_trainer:c38": {
			"id": "play_trainer:c38",
			"action_id": "play_trainer:c38",
			"type": "play_trainer",
			"card": "Ultra Ball",
			"consumes_hand_card_ids": ["c38"],
		},
		"attach_energy:c20:active": {
			"id": "attach_energy:c20:active",
			"action_id": "attach_energy:c20:active",
			"type": "attach_energy",
			"consumes_hand_card_ids": ["c20"],
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	})
	var repair: Dictionary = strategy.call("_repair_resource_conflicts_in_tree", {
		"actions": [
			{"id": "play_trainer:c38", "interactions": {"discard_cards": ["c5", "c20"]}},
			{"id": "attach_energy:c20:active"},
			{"id": "end_turn"},
		],
	})
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", (raw_action as Dictionary).get("id", ""))))
	return run_checks([
		assert_true(ids.has("play_trainer:c38"), "Earlier Ultra Ball action should remain"),
		assert_false(ids.has("attach_energy:c20:active"), "Later attach reusing an exact discarded energy should be pruned"),
		assert_true(ids.has("end_turn"), "Terminal action should remain after discard conflict pruning"),
		assert_eq(int(repair.get("removed_count", 0)), 1, "Discard-card repair should report one removed action"),
	])


func test_llm_sanitize_strips_interactions_from_no_schema_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	strategy.set("_llm_action_catalog", {
		"play_trainer:c7": {
			"id": "play_trainer:c7",
			"action_id": "play_trainer:c7",
			"type": "play_trainer",
			"card": "Energy Switch",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	})
	var sanitize: Dictionary = strategy.call("_sanitize_decision_tree_contract", {
		"actions": [
			{
				"id": "play_trainer:c7",
				"interactions": {
					"source_pokemon": "Teal Mask Ogerpon ex",
					"target_pokemon": "Regidrago VSTAR",
				},
				"selection_policy": {
					"source_pokemon": {"prefer": ["Teal Mask Ogerpon ex"]},
					"target_pokemon": {"prefer": ["Regidrago VSTAR"]},
				},
			},
			{"id": "end_turn"},
		],
	})
	var actions: Array = (sanitize.get("tree", {}) as Dictionary).get("actions", [])
	var first: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_true(bool(sanitize.get("valid", false)), "No-schema interaction sanitizer should preserve an otherwise valid plan"),
		assert_false(first.has("interactions"), "Low-level interactions should be stripped when legal action exposes no interaction_schema"),
		assert_true(first.has("selection_policy"), "Selection policy should be preserved for fallback interaction scoring"),
		assert_eq(int(sanitize.get("repaired_count", 0)), 1, "Sanitizer should report one repaired action"),
	])


func test_v17_regidrago_llm_treats_apex_dragon_as_high_pressure_terminal() -> String:
	var strategy := _new_v17_regidrago_llm_strategy()
	if strategy == null:
		return "DeckStrategy17RegidragoLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var regidrago_vstar := _make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280)
	regidrago_vstar.name_en = "Regidrago VSTAR"
	regidrago_vstar.attacks = [{"name": "Apex Dragon", "cost": "GGR", "damage": ""}]
	player.active_pokemon = _make_slot(regidrago_vstar, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var dragapult := _make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320)
	dragapult.name_en = "Dragapult ex"
	dragapult.attacks = [{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	player.discard_pile.append(CardInstance.create(dragapult, 0))
	var attack_action := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"source_slot": player.active_pokemon,
		"projected_damage": 0,
	}
	var end_turn_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	return run_checks([
		assert_true(bool(strategy.call("_is_current_action_high_pressure_attack_ref", attack_action, gs, 0)), "Apex Dragon should be high pressure even though its printed damage is blank"),
		assert_true(bool(strategy.call("_queue_item_matches", end_turn_ref, attack_action, gs, 0)), "An end_turn queue slot should be replaceable by ready Apex Dragon"),
	])


func test_v17_regidrago_prefers_goodra_copy_to_survive_charizard_ex() -> String:
	var strategy := _new_v17_regidrago_rules_strategy()
	if strategy == null:
		return "DeckStrategy17Regidrago.gd should exist"
	var gs := _make_game_state(12)
	var opponent := gs.players[1]
	var charizard := _make_pokemon_cd("Charizard ex", "Stage 2", "D", 330)
	charizard.name_en = "Charizard ex"
	opponent.active_pokemon = _make_slot(charizard, 1)
	var goodra_cd := _make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270)
	goodra_cd.name_en = "Hisuian Goodra VSTAR"
	var goodra := CardInstance.create(goodra_cd, 0)
	var dragapult_cd := _make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320)
	dragapult_cd.name_en = "Dragapult ex"
	var dragapult := CardInstance.create(dragapult_cd, 0)
	var context := {"game_state": gs, "player_index": 0}
	var goodra_score := float(strategy.call("score_interaction_target", {
		"source_card": goodra,
		"attack": {"name": "Rolling Iron", "damage": "200"},
	}, {"id": "copied_attack"}, context))
	var dragapult_score := float(strategy.call("score_interaction_target", {
		"source_card": dragapult,
		"attack": {"name": "Phantom Dive", "damage": "200"},
	}, {"id": "copied_attack"}, context))
	return assert_true(goodra_score > dragapult_score, "Against bulky Charizard ex, Regidrago should prefer Goodra's damage reduction over Dragapult chip")


func test_v17_regidrago_preserves_energy_switch_when_it_reloads_apex() -> String:
	var strategy := _new_v17_regidrago_rules_strategy()
	if strategy == null:
		return "DeckStrategy17Regidrago.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_cd := _make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280)
	active_cd.name_en = "Regidrago VSTAR"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	ogerpon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.bench.append(ogerpon)
	var energy_switch := CardInstance.create(_make_trainer_cd("Energy Switch", "Item"), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var switch_priority := int(strategy.call("get_discard_priority_contextual", energy_switch, gs, 0))
	var grass_priority := int(strategy.call("get_discard_priority_contextual", grass, gs, 0))
	return run_checks([
		assert_true(switch_priority <= 10, "Energy Switch should be protected when it reloads active Regidrago VSTAR"),
		assert_true(grass_priority > switch_priority, "Vessel/Ultra Ball discard fallback should discard filler before the route-critical Energy Switch"),
	])


func test_v17_regidrago_prioritizes_goodra_fuel_against_charizard_pressure() -> String:
	var strategy := _new_v17_regidrago_rules_strategy()
	if strategy == null:
		return "DeckStrategy17Regidrago.gd should exist"
	var gs := _make_game_state(4)
	var opponent := gs.players[1]
	var charizard := _make_pokemon_cd("Charizard ex", "Stage 2", "D", 330)
	charizard.name_en = "Charizard ex"
	opponent.active_pokemon = _make_slot(charizard, 1)
	var goodra_cd := _make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270)
	goodra_cd.name_en = "Hisuian Goodra VSTAR"
	var dragapult_cd := _make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320)
	dragapult_cd.name_en = "Dragapult ex"
	var goodra := CardInstance.create(goodra_cd, 0)
	var dragapult := CardInstance.create(dragapult_cd, 0)
	var goodra_priority := int(strategy.call("get_discard_priority_contextual", goodra, gs, 0))
	var dragapult_priority := int(strategy.call("get_discard_priority_contextual", dragapult, gs, 0))
	return assert_true(goodra_priority > dragapult_priority, "Charizard pressure should make Hisuian Goodra VSTAR the preferred new dragon fuel")


func test_raging_bolt_llm_blocks_end_turn_when_non_attacker_can_recover_line() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 0))
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	player.hand.append(nest)
	player.hand.append(lightning)
	_inject_llm_queue(strategy, 12, [
		{"type": "end_turn", "id": "end_turn", "action_id": "end_turn"},
	])
	var end_action := {"kind": "end_turn"}
	var end_score: float = float(strategy.call("score_action_absolute", end_action, gs, 0))
	return run_checks([
		assert_true(end_score < 90000.0, "LLM end_turn should not dominate when a non-attacker active still has recovery/setup pieces"),
	])


func test_llm_queue_clears_after_terminal_attack_execution() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	strategy.set("_llm_queue_turn", 14)
	strategy.set("_llm_action_queue", [
		{"type": "attack", "action_id": "attack:0:bursting roar"},
		{"type": "play_trainer", "action_id": "play_trainer:c1", "card": "Nest Ball"},
	])
	strategy.call("_consume_llm_queue_after_action", {"kind": "attack", "attack_index": 0}, 0, 14, gs, 0)
	return run_checks([
		assert_eq(strategy.call("get_llm_action_queue").size(), 0, "Terminal attack execution should clear unreachable post-attack queue actions"),
		assert_false(strategy.call("has_llm_plan_for_turn", 14), "Terminal attack execution should mark this turn's LLM queue completed"),
	])


func test_raging_bolt_llm_does_not_skip_complex_attack_ready_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item"), 0)
	player.hand.append(nest_ball)
	player.hand.append(shoes)
	var skip: bool = bool(strategy.call("_should_skip_llm_for_local_rules", gs, 0, [
		{"kind": "play_trainer", "card": nest_ball, "targets": [], "requires_interaction": true},
		{"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true},
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	]))
	return assert_false(skip, "Raging Bolt LLM should not skip planning just because attack is already legal when setup cards are playable")


func test_llm_prompt_action_selection_covers_playable_hand_cards() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var actions: Array[Dictionary] = []
	for i: int in 12:
		var trainer := CardInstance.create(_make_trainer_cd("Playable Trainer %d" % i, "Item"), 0)
		player.hand.append(trainer)
		actions.append({"kind": "play_trainer", "card": trainer, "targets": [], "requires_interaction": false})
	actions.append({"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false})
	actions.append({"kind": "end_turn"})
	var selected: Array = strategy.call("_select_llm_prompt_actions", actions, gs, 0)
	var trainer_count := 0
	for action: Dictionary in selected:
		if str(action.get("kind", "")) == "play_trainer":
			trainer_count += 1
	return run_checks([
		assert_true(trainer_count >= 10, "LLM prompt should expose broad playable-hand coverage, not only top five trainers"),
		assert_true(selected.size() <= 33, "LLM prompt should remain bounded after adding hand-card coverage"),
	])


func test_llm_request_skips_trivial_single_productive_action() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var actions: Array[Dictionary] = [
		{"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	]
	strategy.call("ensure_llm_request_fired", gs, 0, actions)
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_eq(int(stats.get("requests", -1)), 0, "Trivial turns should not send an LLM request"),
		assert_eq(int(stats.get("skipped_by_local_rules", -1)), 1, "Trivial turns should be counted as local-rule skips"),
		assert_false(strategy.call("has_llm_plan_for_turn", 8), "Skipping LLM should leave rules in control"),
	])


func test_llm_request_does_not_skip_attack_only_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var skip: bool = bool(strategy.call("_should_skip_llm_for_local_rules", gs, 0, [
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	]))
	return assert_false(skip, "Attack-only turns should still let LLM choose attack vs preserve resources/end-turn semantics")


func test_llm_request_does_not_skip_single_interactive_trainer_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	player.hand.append(vessel)
	var skip: bool = bool(strategy.call("_should_skip_llm_for_local_rules", gs, 0, [
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	]))
	return assert_false(skip, "Single interactive resource trainer turns should not be skipped because interaction intent matters")


func test_llm_response_error_candidate_fallback_counts_as_failure_not_success() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_cached_turn_number", 8)
	strategy.set("_llm_request_count", 1)
	strategy.set("_llm_action_catalog", {
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	})
	strategy.call("_register_payload_candidate_routes", {
		"candidate_routes": [{
			"id": "preserve_end",
			"route_action_id": "route:preserve_end",
			"goal": "fallback",
			"actions": [{"id": "end_turn"}],
			"base_priority": 100,
		}],
	})
	strategy.call("_on_llm_response", {"status": "error", "message": "tls failed"}, 8, gs, 0)
	var stats: Dictionary = strategy.call("get_llm_stats")

	return run_checks([
		assert_eq(int(stats.get("requests", -1)), 1, "The failed transport still counts as an attempted request"),
		assert_eq(int(stats.get("successes", -1)), 0, "Candidate-route fallback after response error must not be counted as an LLM success"),
		assert_eq(int(stats.get("failures", -1)), 1, "Candidate-route fallback after response error should count as an LLM failure"),
		assert_true(str(stats.get("last_error", "")).contains("tls failed"), "The transport error should remain visible in LLM health"),
		assert_true(strategy.call("has_llm_plan_for_turn", 8), "Runtime may still use a candidate-route fallback to keep the game moving"),
	])


func test_llm_request_still_runs_after_turn_plan_cache_refresh() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var backup := CardInstance.create(_make_raging_bolt_cd(), 0)
	player.hand.append(energy)
	player.hand.append(backup)
	strategy.call("build_turn_plan", gs, 0, {"prompt_kind": "action_selection"})
	strategy.call("ensure_llm_request_fired", gs, 0, [
		{"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon},
		{"kind": "play_basic_to_bench", "card": backup},
		{"kind": "end_turn"},
	])
	return run_checks([
		assert_eq(int(strategy.get("_cached_turn_number")), 8, "Turn-plan cache should still mark the current turn"),
		assert_eq(int(strategy.get("_llm_request_attempt_turn")), 8, "LLM request attempt should not be blocked by the turn-plan cache"),
	])


func test_llm_turn_zero_skips_all_llm_requests() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(0)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	strategy.call("ensure_llm_request_fired", gs, 0, [
		{"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	strategy.call("ensure_fast_choice_request_fired", "setup_active", gs, 0)
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_eq(int(stats.get("requests", -1)), 0, "Turn 0 should not start a main-turn LLM request"),
		assert_false(strategy.call("is_llm_pending"), "Turn 0 should leave no pending LLM request"),
		assert_false(strategy.call("is_fast_choice_pending"), "Turn 0 setup choice should not start fast-choice LLM"),
		assert_false(strategy.call("has_llm_plan_for_turn", 0), "Turn 0 should leave rules in control"),
	])


func test_llm_decision_tree_switches_branch_without_replanning() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var iono_cd: CardData = CardDatabase.get_card("CSV3C", "123")
	if iono_cd == null:
		return "CSV3C_123 Iono/濂囨爲 card JSON should exist"
	var iono := CardInstance.create(iono_cd, 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(iono)
	player.hand.append(energy)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	_inject_llm_tree(strategy, 3, {
		"branches": [
			{
				"when": [{"fact": "supporter_not_used"}, {"fact": "hand_has_card", "card": "Iono"}],
				"actions": [{"type": "play_trainer", "card": "Iono"}],
			},
			{
				"when": [{"fact": "energy_not_attached"}],
				"actions": [{"type": "attach_energy", "energy_type": "Lightning", "target": "Raging Bolt ex", "position": "active"}],
			},
		],
		"fallback_actions": [{"type": "end_turn"}],
	})
	var iono_action := {"kind": "play_trainer", "card": iono, "targets": [], "requires_interaction": false}
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var before_iono_score: float = float(strategy.call("score_action_absolute", iono_action, gs, 0))
	var before_attach_score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	gs.supporter_used_this_turn = true
	var after_iono_score: float = float(strategy.call("score_action_absolute", iono_action, gs, 0))
	var after_attach_score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	return run_checks([
		assert_true(before_iono_score > before_attach_score, "Tree should choose supporter branch before supporter is used"),
		assert_true(after_attach_score > after_iono_score, "Tree should switch to attach branch after supporter is used"),
		assert_eq(int(strategy.call("get_llm_replan_count")), 0, "Decision tree execution must not trigger in-turn LLM replanning"),
	])


func test_llm_response_materializes_selected_action_queue_for_logging() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	strategy.set("_cached_turn_number", 6)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"actions": [
				{"type": "attach_energy", "energy_type": "Lightning", "target": "Raging Bolt ex", "position": "active"},
			],
		},
		"reasoning": "attach first",
	}, 6, gs, 0)
	var queue: Array = strategy.call("get_llm_action_queue")
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_true(strategy.call("has_llm_plan_for_turn", 6), "A non-empty selected queue should keep the LLM plan active"),
		assert_eq(queue.size(), 2, "LLM response should materialize the selected queue plus automatic end_turn"),
		assert_eq(str((queue[0] as Dictionary).get("type", "")), "attach_energy", "Selected queue should expose the first executable action"),
		assert_eq(str((queue[1] as Dictionary).get("action_id", "")), "end_turn", "Short selected queue should close with end_turn"),
		assert_eq(int(stats.get("successes", -1)), 1, "Materialized non-empty tree should count as success"),
	])


func test_llm_replans_after_large_hand_change_from_effect() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	gs.energy_attached_this_turn = true
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn"}])
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "effect_interaction",
		"pending_choice_after": "",
	})
	var replan_context_by_turn: Dictionary = strategy.get("_llm_replan_context_by_turn")
	var replan_context: Dictionary = replan_context_by_turn.get(6, {})
	var current_turn_flags: Dictionary = replan_context.get("current_turn_flags", {})
	return run_checks([
		assert_eq(int(strategy.call("get_llm_replan_count")), 1, "Large draw/search hand changes should request one same-turn replan"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Replan request should clear the stale decision tree"),
		assert_true(bool(after.get("energy_attached_this_turn", false)), "Runtime snapshot should preserve current manual attach flag"),
		assert_true(bool(after.get("supporter_used_this_turn", false)), "Runtime snapshot should preserve current Supporter-used flag"),
		assert_true(bool(current_turn_flags.get("energy_attached_this_turn", false)), "Replan context should expose manual attach flag"),
		assert_true(bool(current_turn_flags.get("supporter_used_this_turn", false)), "Replan context should expose Supporter-used flag"),
	])


func test_llm_suppresses_minor_replan_when_terminal_burst_attack_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	player.hand.append(grass)
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn", "capability": "end_turn"}])
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.erase(grass)
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "effect_interaction",
		"pending_choice_after": "",
	})
	return run_checks([
		assert_true(bool(after.get("raging_bolt_burst_ready", false)), "Runtime snapshot should know the primary burst attack is already ready"),
		assert_eq(int(strategy.call("get_llm_replan_count")), 0, "Minor one-card churn should not interrupt a ready terminal attack queue"),
		assert_true(strategy.call("has_llm_plan_for_turn", 6), "Suppressed replan should keep the existing conversion queue"),
	])


func test_llm_replans_after_major_hand_refresh_even_when_terminal_burst_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn", "capability": "end_turn"}])
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.clear()
	for i: int in 7:
		player.hand.append(CardInstance.create(_make_trainer_cd("Drawn Card %d" % i, "Item"), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "play_trainer",
		"pending_choice_after": "",
	})
	var replan_context_by_turn: Dictionary = strategy.get("_llm_replan_context_by_turn")
	var replan_context: Dictionary = replan_context_by_turn.get(6, {})
	return run_checks([
		assert_true(bool(after.get("raging_bolt_burst_ready", false)), "Runtime snapshot should still know the burst attack is ready"),
		assert_eq(int(strategy.call("get_llm_replan_count")), 1, "Professor/Iono-style hand refresh should force a same-turn replan even when a terminal attack is ready"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Major hand refresh replan should clear the stale queue"),
		assert_eq(str((replan_context.get("trigger", {}) as Dictionary).get("reason", "")), "hand_gained_7_cards", "Replan context should record the major hand refresh trigger"),
	])


func test_llm_supporter_hand_refresh_ignores_replan_limit() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn", "capability": "end_turn"}])
	strategy.set("_llm_replan_counts", {6: 3})
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.clear()
	for i: int in 6:
		player.hand.append(CardInstance.create(_make_trainer_cd("Fresh Card %d" % i, "Item"), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "play_trainer",
		"action_card_name": "Professor's Research",
		"action_card_type": "Supporter",
		"pending_choice_after": "",
	})
	var replan_context_by_turn: Dictionary = strategy.get("_llm_replan_context_by_turn")
	var replan_context: Dictionary = replan_context_by_turn.get(6, {})
	var trigger: Dictionary = replan_context.get("trigger", {})
	return run_checks([
		assert_eq(int(strategy.call("get_llm_replan_count")), 4, "Supporter hand refresh should ignore the ordinary per-turn replan budget"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Forced Supporter refresh replan should still clear stale decisions"),
		assert_eq(str(trigger.get("reason", "")), "supporter_changed_9_cards", "Trigger should explicitly record the Supporter hand-refresh reason"),
		assert_true(bool(trigger.get("ignore_replan_limit", false)), "Supporter hand-refresh trigger should bypass the replan limit"),
	])


func test_llm_allows_second_replan_after_second_large_hand_change() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn"}])
	var before_first: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	var after_first: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before_first, after_first, {
		"success": true,
		"step_kind": "effect_interaction",
		"pending_choice_after": "",
	})
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn"}])
	var before_second: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0))
	var after_second: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before_second, after_second, {
		"success": true,
		"step_kind": "effect_interaction",
		"pending_choice_after": "",
	})
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn"}])
	var before_third: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var after_third: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before_third, after_third, {
		"success": true,
		"step_kind": "effect_interaction",
		"pending_choice_after": "",
	})
	return run_checks([
		assert_eq(int(strategy.call("get_llm_replan_count")), 3, "Three large same-turn hand changes should be allowed under the generic replan budget"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "The third large hand change should clear the stale plan under the generic budget"),
	])


func test_llm_does_not_replan_after_plain_manual_attach() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn"}])
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.erase(energy)
	player.active_pokemon.attached_energy.append(energy)
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "attach_energy",
		"pending_choice_after": "",
	})
	return run_checks([
		assert_eq(int(strategy.call("get_llm_replan_count")), 0, "Plain manual attach should not trigger another LLM request"),
		assert_true(strategy.call("has_llm_plan_for_turn", 6), "Non-draw actions should keep the current decision tree"),
	])


func test_llm_clears_stale_queue_after_escape_action() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum", "Item"), 0)
	player.hand.append(vacuum)
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_request_attempt_turn", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "use_ability:active:0"}, {"id": "end_turn"}]})
	var stale_queue: Array[Dictionary] = [
		{"type": "use_ability", "action_id": "use_ability:active:0"},
		{"type": "end_turn", "action_id": "end_turn"},
	]
	strategy.set("_llm_action_queue", stale_queue)
	strategy.call("_consume_llm_queue_after_action", {
		"kind": "play_trainer",
		"card": vacuum,
		"targets": [],
		"requires_interaction": true,
	}, -1, 6, gs, 0)
	var replan_eligible: Dictionary = strategy.get("_llm_replan_eligible_after_reject")
	return run_checks([
		assert_eq(strategy.call("get_llm_action_queue").size(), 0, "Stale LLM queue should be cleared after a runtime escape action"),
		assert_eq(int(strategy.get("_llm_queue_turn")), -1, "Escaped queue should release LLM queue ownership"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Escaped queue should not keep fighting future rule-selected actions"),
		assert_eq(int(strategy.get("_llm_request_attempt_turn")), -1, "Non-terminal escape should permit a fresh same-turn LLM request"),
		assert_true(bool(replan_eligible.get(6, false)), "Non-terminal escape should mark the turn eligible for bounded replanning"),
	])


func test_llm_contract_rejection_still_allows_replan_after_draw() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 6)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "hand_has_card"}],
				"actions": [{"id": attach_id}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 6, gs, 0)
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "play_trainer",
		"pending_choice_after": "",
	})
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 6), "Contract rejection should not disable the whole turn"),
		assert_eq(int(strategy.call("get_llm_replan_count")), 1, "Large hand changes after a rejected plan should still trigger same-turn replan"),
	])


func test_action_id_replan_prompt_uses_current_turn_flags() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	gs.energy_attached_this_turn = true
	gs.supporter_used_this_turn = true
	gs.retreat_used_this_turn = true
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(lightning)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "attach_energy", "card": lightning, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	var prompt_state: Dictionary = payload.get("game_state", {})
	return run_checks([
		assert_true(bool(prompt_state.get("energy_attached_this_turn", false)), "Second prompt state should expose that manual energy was already attached"),
		assert_true(bool(prompt_state.get("supporter_used_this_turn", false)), "Second prompt state should expose that Supporter was already used"),
		assert_true(bool(prompt_state.get("retreat_used_this_turn", false)), "Second prompt state should expose that retreat was already used"),
	])


func test_action_id_tree_locks_selected_queue_after_first_selection() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(iono)
	player.hand.append(energy)
	var iono_action := {"kind": "play_trainer", "card": iono, "targets": [], "requires_interaction": false}
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var iono_id: String = str(strategy.call("_action_id_for_action", iono_action, gs, 0))
	var attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [iono_action, attach_action], gs, 0))
	strategy.set("_cached_turn_number", 6)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [
				{"when": [{"fact": "supporter_not_used"}, {"fact": "hand_has_card", "card": "Iono"}], "actions": [{"id": iono_id}]},
				{"when": [{"fact": "energy_not_attached"}], "actions": [{"id": attach_id}]},
			],
		},
	}, 6, gs, 0)
	var initial_queue: Array = strategy.call("get_llm_action_queue")
	gs.supporter_used_this_turn = true
	var after_fact_change_queue: Array = strategy.call("_select_current_action_queue", gs, 0)
	var iono_score: float = float(strategy.call("score_action_absolute", iono_action, gs, 0))
	var attach_score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	return run_checks([
		assert_eq(str((initial_queue[0] as Dictionary).get("action_id", "")), iono_id, "Initial selected queue should choose the first matching branch"),
		assert_eq(str((after_fact_change_queue[0] as Dictionary).get("action_id", "")), iono_id, "Action-id queue should stay locked after selection instead of branch-hopping"),
		assert_true(iono_score > attach_score, "Locked queue should keep scoring the selected route over newly matching branches"),
	])


func test_llm_plan_does_not_leak_across_new_game_state_same_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs1 := _make_game_state(6)
	gs1.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var gs2 := _make_game_state(6)
	gs2.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_llm_game_state_instance_id", int(gs1.get_instance_id()))
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"action_id": "end_turn", "kind": "end_turn"}])
	var stale_queue: Array = strategy.call("_select_current_action_queue", gs2, 0)
	return run_checks([
		assert_eq(stale_queue.size(), 0, "A new GameState with the same turn number must not reuse the previous match's LLM queue"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "New match context should clear stale LLM plan ownership"),
		assert_eq(strategy.call("get_llm_action_queue").size(), 0, "New match context should clear stale action queue"),
	])


func test_llm_plan_clears_when_same_game_state_turn_rolls_back() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_llm_game_state_instance_id", int(gs.get_instance_id()))
	strategy.set("_llm_last_seen_turn_number", 12)
	strategy.set("_cached_turn_number", 2)
	strategy.set("_llm_queue_turn", 2)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"action_id": "end_turn", "type": "end_turn"}])
	var stale_queue: Array = strategy.call("_select_current_action_queue", gs, 0)
	return run_checks([
		assert_eq(stale_queue.size(), 0, "A reused GameState whose turn number rolls back must not reuse the previous match's queue"),
		assert_false(strategy.call("has_llm_plan_for_turn", 2), "Turn rollback should clear stale LLM plan ownership"),
		assert_eq(strategy.call("get_llm_action_queue").size(), 0, "Turn rollback should clear stale action queue"),
	])


func test_llm_queue_requires_exact_action_id_for_duplicate_card_names() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	var catcher_cd := _make_trainer_cd("Pok茅mon Catcher", "Item")
	var catcher_1 := CardInstance.create(catcher_cd, 0)
	var catcher_2 := CardInstance.create(catcher_cd, 0)
	player.hand.append(catcher_1)
	player.hand.append(catcher_2)
	var action_1 := {"kind": "play_trainer", "card": catcher_1, "requires_interaction": true}
	var action_2 := {"kind": "play_trainer", "card": catcher_2, "requires_interaction": true}
	var id_1: String = str(strategy.call("_action_id_for_action", action_1, gs, 0))
	var queue: Array[Dictionary] = [{"action_id": id_1, "type": "play_trainer", "card": "Pok茅mon Catcher"}]
	var score_1: float = float(strategy.call("_score_from_queue", action_1, queue, gs, 0))
	var score_2: float = float(strategy.call("_score_from_queue", action_2, queue, gs, 0))
	return run_checks([
		assert_true(score_1 > 0.0, "The exact queued card instance should match the LLM queue"),
		assert_eq(score_2, 0.0, "A duplicate card name with a different action id must not match the queued action"),
	])


func test_llm_queue_consumes_head_and_forces_end_turn_after_short_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	var catcher := CardInstance.create(_make_trainer_cd("Pok茅mon Catcher", "Item"), 0)
	player.hand.append(catcher)
	var catcher_action := {"kind": "play_trainer", "card": catcher, "requires_interaction": true}
	var catcher_id: String = str(strategy.call("_action_id_for_action", catcher_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [catcher_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 6)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "always"}],
				"actions": [{"id": catcher_id}],
			}],
		},
	}, 6, gs, 0)
	var initial_queue: Array = strategy.call("get_llm_action_queue")
	strategy.call("log_runtime_action_result", catcher_action, true, gs, 0, 6)
	var remaining_queue: Array = strategy.call("get_llm_action_queue")
	player.active_pokemon.attached_energy.clear()
	var initial_first_id := str((initial_queue[0] as Dictionary).get("action_id", "")) if initial_queue.size() > 0 and initial_queue[0] is Dictionary else ""
	var remaining_first_id := str((remaining_queue[0] as Dictionary).get("action_id", "")) if remaining_queue.size() > 0 and remaining_queue[0] is Dictionary else ""
	return run_checks([
		assert_eq(initial_queue.size(), 1, "A gust-only route without an attack goal should be reduced to the safe end_turn"),
		assert_eq(initial_first_id, "end_turn", "The reduced route should preserve end_turn"),
		assert_eq(remaining_queue.size(), 0, "Logging the removed gust action should clear the reduced one-step fallback queue"),
		assert_eq(remaining_first_id, "", "No queued action should remain after the reduced fallback is cleared"),
	])


func test_llm_queue_removes_internal_end_turn_before_later_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	player.hand.append(energy)
	player.hand.append(vessel)
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var vessel_action := {"kind": "play_trainer", "card": vessel, "requires_interaction": true}
	var attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	var vessel_id: String = str(strategy.call("_action_id_for_action", vessel_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_action, vessel_action, {"kind": "end_turn"}], gs, 0))
	var queue: Array = strategy.call("_normalize_selected_action_queue", [
		{"type": "attach_energy", "action_id": attach_id},
		{"type": "end_turn", "action_id": "end_turn"},
		{"type": "play_trainer", "action_id": vessel_id},
		{"type": "end_turn", "action_id": "end_turn"},
	])
	return run_checks([
		assert_eq(queue.size(), 3, "Internal end_turn should be removed when later planned actions exist"),
		assert_eq(str((queue[0] as Dictionary).get("action_id", "")), attach_id, "Attach should remain first"),
		assert_eq(str((queue[1] as Dictionary).get("action_id", "")), vessel_id, "Later planned Vessel should not be blocked by end_turn"),
		assert_eq(str((queue[2] as Dictionary).get("action_id", "")), "end_turn", "Only the final end_turn should remain"),
	])


func test_llm_plan_repair_expands_short_non_attack_route_before_end_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	var greninja_slot := _make_slot(greninja_cd, 0)
	player.bench.append(greninja_slot)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	player.hand.append(vessel)
	var greninja_action := {"kind": "use_ability", "source_slot": greninja_slot, "ability_index": 0, "requires_interaction": false}
	var vessel_action := {"kind": "play_trainer", "card": vessel, "requires_interaction": true}
	var greninja_id: String = str(strategy.call("_action_id_for_action", greninja_action, gs, 0))
	var vessel_id: String = str(strategy.call("_action_id_for_action", vessel_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [greninja_action, vessel_action, {"kind": "end_turn"}], gs, 0))
	var repair: Dictionary = strategy.call("_repair_premature_short_routes_in_tree", {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [
				{"type": "use_ability", "action_id": greninja_id},
				{"type": "end_turn", "action_id": "end_turn"},
			],
		}],
	})
	var repaired_tree: Dictionary = repair.get("tree", {})
	var branches: Array = repaired_tree.get("branches", [])
	var queue: Array = (branches[0] as Dictionary).get("actions", []) if not branches.is_empty() else []
	var action_ids: Array[String] = []
	for raw_action: Variant in queue:
		action_ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(action_ids.has(greninja_id), "Original short-route action should remain"),
		assert_true(action_ids.has(vessel_id), "Plan repair should add obvious resource followups before ending"),
		assert_eq(action_ids[action_ids.size() - 1], "end_turn", "Repaired short route should still end explicitly"),
		assert_true(int(repair.get("added_count", 0)) > 0, "Plan repair should report added actions for audit"),
	])


func test_llm_plan_repair_inserts_survival_tool_before_terminal_action() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var charm_cd := _make_trainer_cd("Bravery Charm", "Tool")
	charm_cd.effect_id = "d1c2f018a644e662f2b6895fdfc29281"
	charm_cd.description = "The Basic Pokemon this card is attached to gets +50 HP."
	var charm := CardInstance.create(charm_cd, 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	player.hand.append(charm)
	player.hand.append(vessel)
	var charm_action := {"kind": "attach_tool", "card": charm, "target_slot": player.active_pokemon}
	var vessel_action := {"kind": "play_trainer", "card": vessel, "requires_interaction": true}
	var charm_id: String = str(strategy.call("_action_id_for_action", charm_action, gs, 0))
	var vessel_id: String = str(strategy.call("_action_id_for_action", vessel_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [charm_action, vessel_action, {"kind": "end_turn"}], gs, 0))
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [
				{"id": vessel_id},
				{"id": "end_turn"},
			],
		}],
	})
	var repair: Dictionary = strategy.call("_repair_missing_survival_tools_in_tree", materialized)
	var branches: Array = (repair.get("tree", {}) as Dictionary).get("branches", [])
	var actions: Array = (branches[0] as Dictionary).get("actions", []) if not branches.is_empty() else []
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_true(ids.has(vessel_id), "Original route action should remain"),
		assert_true(ids.has(charm_id), "Survival tool should be inserted before the terminal action"),
		assert_true(ids.find(charm_id) < ids.find("end_turn"), "Survival tool should be before end_turn"),
		assert_eq(int(repair.get("added_count", 0)), 1, "Survival tool repair should report one inserted action"),
	])


func test_llm_plan_repair_adds_greninja_before_non_attack_end_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	var ogerpon_slot := _make_slot(ogerpon_cd, 0)
	var greninja_slot := _make_slot(greninja_cd, 0)
	player.bench.append(ogerpon_slot)
	player.bench.append(greninja_slot)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(lightning)
	var ogerpon_action := {"kind": "use_ability", "source_slot": ogerpon_slot, "ability_index": 0, "requires_interaction": false}
	var greninja_action := {"kind": "use_ability", "source_slot": greninja_slot, "ability_index": 0, "requires_interaction": false}
	var attach_action := {"kind": "attach_energy", "card": lightning, "target_slot": player.active_pokemon}
	var ogerpon_id: String = str(strategy.call("_action_id_for_action", ogerpon_action, gs, 0))
	var greninja_id: String = str(strategy.call("_action_id_for_action", greninja_action, gs, 0))
	var attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [ogerpon_action, greninja_action, attach_action, {"kind": "end_turn"}], gs, 0))
	var repair: Dictionary = strategy.call("_repair_premature_short_routes_in_tree", {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [
				{"type": "use_ability", "action_id": ogerpon_id},
				{"type": "attach_energy", "action_id": attach_id},
				{"type": "end_turn", "action_id": "end_turn"},
			],
		}],
	})
	var repaired_tree: Dictionary = repair.get("tree", {})
	var branches: Array = repaired_tree.get("branches", [])
	var queue: Array = (branches[0] as Dictionary).get("actions", []) if not branches.is_empty() else []
	var action_ids: Array[String] = []
	var greninja_interactions: Dictionary = {}
	for raw_action: Variant in queue:
		var queued_action: Dictionary = raw_action
		var action_id := str(queued_action.get("action_id", ""))
		action_ids.append(action_id)
		if action_id == greninja_id:
			greninja_interactions = queued_action.get("interactions", {})
	return run_checks([
		assert_true(action_ids.has(ogerpon_id), "Original Ogerpon action should remain"),
		assert_true(action_ids.has(attach_id), "Original attach action should remain"),
		assert_true(action_ids.has(greninja_id), "Plan repair should add Radiant Greninja before non-attack end_turn"),
		assert_true(action_ids.find(greninja_id) < action_ids.find("end_turn"), "Greninja should be inserted before end_turn"),
		assert_true(greninja_interactions.has("discard_card"), "Inserted Greninja action should carry discard-energy intent"),
	])


func test_llm_response_with_empty_selected_queue_falls_back_to_rules() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_cached_turn_number", 6)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [
				{
					"when": [{"fact": "hand_has_card", "card": "Missing Card"}],
					"actions": [{"type": "play_trainer", "card": "Missing Card"}],
				},
			],
		},
		"reasoning": "no current branch",
	}, 6, gs, 0)
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Empty selected queue should disable the LLM plan for this turn"),
		assert_eq(strategy.call("get_llm_action_queue").size(), 0, "Empty selected queue should not leave stale actions behind"),
		assert_eq(int(stats.get("failures", -1)), 1, "Empty selected queue should count as LLM failure so runtime falls back to rules"),
		assert_eq(int(stats.get("successes", -1)), 0, "Empty selected queue should not count as a successful LLM plan"),
	])


func test_llm_rejects_qwen_style_non_contract_tree() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"condition": "can_attack_and_ko_or_high_pressure", "value": true}],
				"actions": [{"id": "attach_energy:c15:active"}, {"id": "attack_active_index_1"}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Unsupported condition and invented ids should reject the current plan without disabling later same-turn replans"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Rejected non-contract tree should not leave an active plan"),
		assert_eq(int(stats.get("failures", -1)), 1, "Rejected non-contract tree should count as one LLM failure"),
	])


func test_llm_rejects_route_with_multiple_manual_attach_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	player.hand.append(lightning)
	player.hand.append(fighting)
	var attach_l := {"kind": "attach_energy", "card": lightning, "target_slot": player.active_pokemon}
	var attach_f := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	var id_l: String = str(strategy.call("_action_id_for_action", attach_l, gs, 0))
	var id_f: String = str(strategy.call("_action_id_for_action", attach_f, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_l, attach_f, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "always"}],
				"actions": [{"id": id_l}, {"id": id_f}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "A route with two manual attach actions should reject only the bad plan so later draw/search can replan"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Rejected illegal attach route should not leave an active plan"),
	])


func test_llm_prunes_invalid_branch_and_keeps_valid_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	player.hand.append(lightning)
	player.hand.append(fighting)
	var attach_l := {"kind": "attach_energy", "card": lightning, "target_slot": player.active_pokemon}
	var attach_f := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	var id_l: String = str(strategy.call("_action_id_for_action", attach_l, gs, 0))
	var id_f: String = str(strategy.call("_action_id_for_action", attach_f, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_l, attach_f, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [
				{
					"when": [{"fact": "always"}],
					"actions": [{"id": id_l}, {"id": id_f}],
				},
				{
					"when": [{"fact": "energy_not_attached"}],
					"actions": [{"id": id_l}],
				},
			],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	var queue: Array = strategy.call("get_llm_action_queue")
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "A bad sibling branch should be pruned instead of disabling the whole turn"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Valid surviving branch should remain executable"),
		assert_eq(queue.size(), 2, "Selected queue should come from the valid surviving route and close with end_turn"),
		assert_eq(str((queue[0] as Dictionary).get("action_id", "")), id_l, "Pruned tree should keep the legal attach route"),
		assert_eq(str((queue[1] as Dictionary).get("action_id", "")), "end_turn", "Pruned short route should close with end_turn"),
		assert_eq(int(stats.get("successes", -1)), 1, "Pruned-but-valid tree should count as an LLM success"),
		assert_eq(int(stats.get("failures", -1)), 0, "Pruned-but-valid tree should not count as an LLM failure"),
	])


func test_llm_rejects_sada_search_interaction_contract_error() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter")
	var sada := CardInstance.create(sada_cd, 0)
	player.hand.append(sada)
	var sada_action := {"kind": "play_trainer", "card": sada, "targets": [], "requires_interaction": true}
	var sada_id: String = str(strategy.call("_action_id_for_action", sada_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [sada_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "always"}],
				"actions": [{"id": sada_id, "interactions": {"search_targets": ["Lightning Energy"]}}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Sada with search_targets should reject the current plan but keep later same-turn replans available"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Rejected Sada interaction should not leave an active plan"),
	])


func test_llm_rejects_broad_can_attack_attack_first_branch() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var bolt_cd := _make_raging_bolt_cd()
	bolt_cd.attacks = [{"name": "椋炴簠鍜嗗摦", "cost": "", "damage": "70"}]
	player.active_pokemon = _make_slot(bolt_cd, 0)
	var attack_action := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var attack_id: String = str(strategy.call("_action_id_for_action", attack_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attack_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "can_attack"}],
				"actions": [{"id": attack_id}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Attack-first branch using only can_attack should reject the current plan but not disable later replans"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Rejected broad attack branch should not leave an active plan"),
	])


func test_llm_rejects_unparameterized_hand_has_card_fact() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item"), 0)
	player.hand.append(shoes)
	var shoes_action := {"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true}
	var shoes_id: String = str(strategy.call("_action_id_for_action", shoes_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [shoes_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "hand_has_card"}],
				"actions": [{"id": shoes_id}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "hand_has_card without a card/name parameter should reject only the bad plan"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Rejected unparameterized condition should not leave an active plan"),
	])


func test_llm_repairs_active_attack_ready_route_without_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var bolt_cd := _make_raging_bolt_cd()
	bolt_cd.attacks = [{"name": "Burst Roar", "cost": "", "damage": "280"}]
	player.active_pokemon = _make_slot(bolt_cd, 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var attack_action := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	var attack_id: String = str(strategy.call("_action_id_for_action", attack_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_action, attack_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "active_attack_ready", "attack_name": "Burst Roar"}],
				"actions": [{"id": attach_id}, {"id": "end_turn"}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	var queue: Array = strategy.call("get_llm_action_queue")
	var last_action_id := ""
	if not queue.is_empty() and queue[queue.size() - 1] is Dictionary:
		last_action_id = str((queue[queue.size() - 1] as Dictionary).get("action_id", ""))
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "active_attack_ready route without attack should be repaired when a legal attack exists"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Repaired no-attack ready route should keep an active plan"),
		assert_true(queue.size() >= 1, "Repaired route should leave at least the legal attack"),
		assert_eq(last_action_id, attack_id, "Repaired route should end with the matching attack id"),
	])


func test_llm_rejects_attack_setup_route_that_ends_turn_when_attack_legal() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(vessel)
	player.hand.append(energy)
	var vessel_action := {"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true}
	var attack_action := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var vessel_id: String = str(strategy.call("_action_id_for_action", vessel_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [vessel_action, attack_action, {"kind": "end_turn"}], gs, 0))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "hand_has_card", "card": "Earthen Vessel"}],
				"actions": [{"id": vessel_id}, {"id": "end_turn"}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Attack setup route that ends turn while attack is legal should reject only the current plan"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Rejected non-closing setup route should not leave an active plan"),
	])


func test_llm_does_not_treat_future_attack_as_current_legal_attack_for_contract() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var sada := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)
	player.hand.append(sada)
	var sada_action := {"kind": "play_trainer", "card": sada, "targets": [], "requires_interaction": true}
	var sada_id: String = str(strategy.call("_action_id_for_action", sada_action, gs, 0))
	var catalog: Dictionary = strategy.call("_build_action_catalog", [sada_action, {"kind": "end_turn"}], gs, 0)
	catalog["future:attack_after_sada:active:1:burst"] = {
		"id": "future:attack_after_sada:active:1:burst",
		"action_id": "future:attack_after_sada:active:1:burst",
		"type": "attack",
		"future": true,
		"attack_index": 1,
		"attack_name": "Thundering Bolt",
	}
	strategy.set("_llm_action_catalog", catalog)
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "always"}],
				"actions": [{"id": sada_id}, {"id": "end_turn"}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Future-only attack refs should not make the contract treat attack as currently legal"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Sada setup route may remain valid when only future attack refs exist"),
	])


func test_invalid_llm_json_error_disables_turn_for_rules_fallback() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"status": "error",
		"error_type": "invalid_content_json",
		"message": "ZenMux message content was not valid JSON",
	}, 9, gs, 0)
	strategy.call("ensure_llm_request_fired", gs, 0, [{"kind": "end_turn"}])
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_true(strategy.call("is_llm_disabled_for_turn", 9), "Invalid JSON should disable LLM for this turn"),
		assert_false(strategy.call("is_llm_pending"), "Invalid JSON should clear the pending LLM state"),
		assert_false(strategy.call("has_llm_plan_for_turn", 9), "Invalid JSON should not leave an active LLM plan"),
		assert_eq(int(stats.get("requests", -1)), 0, "Disabled turn should not retry the LLM request"),
		assert_eq(int(stats.get("failures", -1)), 1, "Invalid JSON should count as one LLM failure"),
	])


func test_invalid_llm_json_uses_candidate_route_when_available() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	strategy.set("_cached_turn_number", 9)
	var catalog: Dictionary = strategy.call("_build_action_catalog", [attach_action, {"kind": "end_turn"}], gs, 0)
	var attach_id := ""
	for raw_key: Variant in catalog.keys():
		var action_id := str(raw_key)
		if action_id.begins_with("attach_energy:"):
			attach_id = action_id
			break
	strategy.set("_llm_action_catalog", catalog)
	strategy.call("_register_payload_candidate_routes", {
		"candidate_routes": [{
			"id": "manual_attach_setup",
			"route_action_id": "route:manual_attach_setup",
			"priority": 600,
			"actions": [
				{"id": attach_id},
				{"id": "end_turn"},
			],
		}],
	})
	strategy.call("_on_llm_response", {
		"status": "error",
		"error_type": "invalid_content_json",
		"message": "ZenMux message content was not valid JSON",
	}, 9, gs, 0)
	var score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Candidate route fallback should keep LLM route control when response JSON is invalid"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Candidate route fallback should create a plan for the turn"),
		assert_true(score > 0.0, "Candidate route fallback should score the route action"),
		assert_eq(int(stats.get("failures", -1)), 1, "Candidate route fallback keeps play moving but still records the failed LLM response"),
		assert_eq(int(stats.get("successes", -1)), 0, "A fallback plan created after invalid JSON must not be counted as a successful LLM decision"),
	])


func test_contract_rejection_uses_candidate_route_when_available() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var catalog: Dictionary = strategy.call("_build_action_catalog", [attach_action, {"kind": "end_turn"}], gs, 0)
	var attach_id := ""
	for raw_key: Variant in catalog.keys():
		var action_id := str(raw_key)
		if action_id.begins_with("attach_energy:"):
			attach_id = action_id
			break
	strategy.set("_cached_turn_number", 9)
	strategy.set("_llm_action_catalog", catalog)
	strategy.call("_register_payload_candidate_routes", {
		"candidate_routes": [{
			"id": "manual_attach_setup",
			"route_action_id": "route:manual_attach_setup",
			"priority": 600,
			"actions": [
				{"id": attach_id},
				{"id": "end_turn"},
			],
		}],
	})
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "can_attack"}],
				"actions": [{"id": "attack:0:made_up"}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	var score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Contract rejection should use candidate route fallback when available"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Contract fallback should leave an active plan"),
		assert_true(score > 0.0, "Contract fallback should score the candidate route action"),
	])


func test_llm_soft_timeout_disables_turn_for_rules_fallback() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	strategy.set("_llm_pending", true)
	strategy.set("_llm_request_turn", 10)
	strategy.set("_llm_request_started_msec", 1)
	strategy.set("_llm_soft_timeout_seconds", 0.001)
	var timed_out: bool = bool(strategy.call("is_llm_soft_timed_out_for_turn", 10))
	strategy.call("force_rules_for_turn", 10, "soft timeout")
	var stats: Dictionary = strategy.call("get_llm_stats")
	return run_checks([
		assert_true(timed_out, "Pending request older than the soft timeout should be considered timed out"),
		assert_true(strategy.call("is_llm_disabled_for_turn", 10), "Soft timeout should disable LLM for this turn"),
		assert_false(strategy.call("is_llm_pending"), "Soft timeout fallback should clear the pending request"),
		assert_false(strategy.call("has_llm_plan_for_turn", 10), "Soft timeout should not leave an active plan"),
		assert_eq(int(stats.get("failures", -1)), 1, "Soft timeout should count as one LLM failure"),
	])


func test_llm_queue_controls_earthen_vessel_discard_choice() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Earthen Vessel", "discard_choice": "Basic Grass Energy", "search_target": "Basic Lightning Energy,Basic Fighting Energy"},
	])
	var picked: Array = strategy.call("pick_interaction_items", [lightning, grass, fighting], {"id": "discard_cards", "max_select": 1}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	})
	return run_checks([
		assert_eq(picked.size(), 1, "LLM discard_choice should pick exactly one card"),
		assert_true(picked[0] == grass, "LLM discard_choice should select the requested Grass Energy"),
	])


func test_llm_queue_matches_json_name_en_before_later_attach() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var iono_cd: CardData = CardDatabase.get_card("CSV3C", "123")
	if iono_cd == null:
		return "CSV3C_123 Iono/濂囨爲 card JSON should exist"
	var iono := CardInstance.create(iono_cd, 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(iono)
	player.hand.append(energy)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Iono"},
		{"type": "attach_energy", "energy_type": "Lightning", "target": "Raging Bolt ex", "position": "active"},
	])
	var iono_action := {"kind": "play_trainer", "card": iono, "targets": [], "requires_interaction": false}
	var attach_action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var iono_score: float = float(strategy.call("score_action_absolute", iono_action, gs, 0))
	var attach_score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	return run_checks([
		assert_eq(str(iono_cd.name), "奇树", "Test should use the real localized card JSON name"),
		assert_eq(str(iono_cd.name_en), "Iono", "Test should use the real English card JSON name"),
		assert_true(iono_score > attach_score, "JSON name_en should match LLM English card name before attach"),
		assert_true(iono_score >= 90000.0, "JSON name_en match should receive the first queue score"),
	])


func test_llm_queue_controls_earthen_vessel_search_targets() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var second_lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Earthen Vessel", "search_target": "Basic Lightning Energy,Basic Fighting Energy"},
	])
	var picked: Array = strategy.call("pick_interaction_items", [lightning, second_lightning, fighting, grass], {"id": "search_energy", "max_select": 2}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	})
	return run_checks([
		assert_eq(picked.size(), 2, "LLM search_target should pick two requested energies"),
		assert_true(picked[0] == lightning, "LLM search_target should preserve requested Lightning first"),
		assert_true(picked[1] == fighting, "LLM search_target should preserve requested Fighting second"),
	])


func test_llm_bridge_raging_bolt_burst_discards_enough_energy_for_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	gs.players[1].active_pokemon.damage_counters = 0
	var fighting_active := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning_active := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var fighting_bench := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	_inject_llm_queue(strategy, 9, [
		{"type": "attack", "card": "Raging Bolt ex", "attack_index": 1, "attack_name": "Thundering Bolt"},
	])
	var picked: Array = strategy.call("pick_interaction_items", [fighting_active, lightning_active, fighting_bench], {"id": "discard_basic_energy", "max_select": 3}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "attack",
		"pending_effect_card": player.active_pokemon.get_top_card(),
	})
	return run_checks([
		assert_eq(picked.size(), 3, "Raging Bolt burst should discard enough visible basic Energy to KO a 200 HP active"),
		assert_true(picked.has(fighting_active), "Burst discard should include active Fighting Energy"),
		assert_true(picked.has(lightning_active), "Burst discard should include active Lightning Energy"),
		assert_true(picked.has(fighting_bench), "Burst discard should include the third board Energy when it is needed for KO"),
	])


func test_llm_raging_bolt_burst_discards_grass_then_backup_surplus_energy() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var backup_bolt := _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	player.bench.append(backup_bolt)
	player.bench.append(ogerpon)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 280), 1)
	var active_lightning := CardInstance.create(_make_energy_cd("Active Lightning Energy", "L"), 0)
	var active_fighting := CardInstance.create(_make_energy_cd("Active Fighting Energy", "F"), 0)
	var backup_core_lightning := CardInstance.create(_make_energy_cd("Backup Core Lightning Energy", "L"), 0)
	var backup_core_fighting := CardInstance.create(_make_energy_cd("Backup Core Fighting Energy", "F"), 0)
	var backup_extra_lightning := CardInstance.create(_make_energy_cd("Backup Extra Lightning Energy", "L"), 0)
	var backup_extra_fighting := CardInstance.create(_make_energy_cd("Backup Extra Fighting Energy", "F"), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.active_pokemon.attached_energy.append_array([active_lightning, active_fighting])
	backup_bolt.attached_energy.append_array([
		backup_core_lightning,
		backup_core_fighting,
		backup_extra_lightning,
		backup_extra_fighting,
	])
	ogerpon.attached_energy.append(grass)
	_inject_llm_queue(strategy, 9, [
		{
			"type": "attack",
			"card": "Raging Bolt ex",
			"attack_index": 1,
			"attack_name": "Thundering Bolt",
			"interactions": {"discard_basic_energy": ["Active Lightning Energy", "Active Fighting Energy"]},
		},
	])
	var picked: Array = strategy.call("pick_interaction_items", [
		backup_core_lightning,
		active_lightning,
		backup_extra_fighting,
		active_fighting,
		backup_extra_lightning,
		backup_core_fighting,
		grass,
	], {"id": "discard_basic_energy", "max_select": 7}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "attack",
		"pending_effect_card": player.active_pokemon.get_top_card(),
	})
	return run_checks([
		assert_eq(picked.size(), 4, "280 HP should require exactly 4 Energy discarded for Bellowing Thunder"),
		assert_true(picked.has(grass), "Burst discard should always spend Grass Energy before core Raging Bolt Energy"),
		assert_true(picked.has(backup_extra_lightning), "Burst discard should use surplus Lightning on backup Raging Bolt before protected core Energy"),
		assert_true(picked.has(backup_extra_fighting), "Burst discard should use surplus Fighting on backup Raging Bolt before protected core Energy"),
		assert_false(picked.has(backup_core_lightning), "Burst discard should preserve one Lightning on backup Raging Bolt for the next turn"),
		assert_false(picked.has(backup_core_fighting), "Burst discard should preserve one Fighting on backup Raging Bolt for the next turn"),
	])


func test_llm_pending_interaction_keeps_consumed_earthen_vessel_intent() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var vessel_action := {
		"kind": "play_trainer",
		"card": vessel,
		"requires_interaction": true,
	}
	var vessel_action_id: String = str(strategy.call("_action_id_for_action", vessel_action, gs, 0))
	strategy.set("_cached_turn_number", 3)
	strategy.set("_llm_queue_turn", 3)
	strategy.set("_llm_decision_tree", {"actions": [{"id": vessel_action_id}]})
	strategy.set("_llm_action_queue", [])
	var completed_turns := {}
	completed_turns[3] = true
	strategy.set("_llm_completed_queue_turns", completed_turns)
	strategy.set("_llm_pending_interaction_turn", 3)
	strategy.set("_llm_pending_interaction_queue_item", {
		"action_id": vessel_action_id,
		"kind": "play_trainer",
		"card": "Earthen Vessel",
		"interactions": {"discard_card": "Basic Grass Energy", "search_energy": ["Basic Lightning Energy", "Basic Fighting Energy"]},
	})
	var search_picked: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {"id": "search_energy", "max_select": 2}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	})
	var discard_picked: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {"id": "discard_cards", "max_select": 1}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	})
	strategy.call("observe_llm_runtime_state_change", strategy.call("make_llm_runtime_snapshot", gs, 0), strategy.call("make_llm_runtime_snapshot", gs, 0), {
		"success": true,
		"step_kind": "effect_interaction",
		"pending_choice_after": "",
	})
	var pending_item: Dictionary = strategy.get("_llm_pending_interaction_queue_item")
	var search_first_is_lightning: bool = search_picked.size() > 0 and search_picked[0] == lightning
	var search_second_is_fighting: bool = search_picked.size() > 1 and search_picked[1] == fighting
	var discard_first_is_grass: bool = discard_picked.size() > 0 and discard_picked[0] == grass
	return run_checks([
		assert_eq(strategy.call("get_llm_action_queue").size(), 0, "Main action queue may be consumed before its effect interaction resolves"),
		assert_eq(search_picked.size(), 2, "Consumed queue head should still drive the pending Earthen Vessel search"),
		assert_true(search_first_is_lightning, "Pending Earthen Vessel intent should preserve Lightning as first search target"),
		assert_true(search_second_is_fighting, "Pending Earthen Vessel intent should preserve Fighting as second search target"),
		assert_eq(discard_picked.size(), 1, "Consumed queue head should still drive the pending Earthen Vessel discard"),
		assert_true(discard_first_is_grass, "Pending Earthen Vessel intent should preserve Grass as discard fuel"),
		assert_true(pending_item.is_empty(), "Pending interaction intent should clear after effect interaction finishes"),
	])


func test_llm_tree_nested_interactions_control_search_targets() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	_inject_llm_tree(strategy, 3, {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [{
				"type": "play_trainer",
				"card": "Earthen Vessel",
				"interactions": {
					"search_energy": {"prefer": ["Basic Lightning Energy", "Basic Fighting Energy"]},
				},
			}],
		}],
	})
	var picked: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {"id": "search_energy", "max_select": 2}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	})
	return run_checks([
		assert_eq(picked.size(), 2, "Nested interaction search intent should pick two requested energies"),
		assert_true(picked[0] == lightning, "Nested interaction should preserve requested Lightning first"),
		assert_true(picked[1] == fighting, "Nested interaction should preserve requested Fighting second"),
	])


func test_deck_capability_extractor_identifies_gardevoir_and_miraidon_engines() -> String:
	var script := _load_script(LLM_DECK_CAPABILITY_EXTRACTOR_SCRIPT_PATH)
	if script == null:
		return "LLMDeckCapabilityExtractor.gd should exist"
	var extractor: RefCounted = script.new()
	var player := PlayerState.new()
	var gardevoir_cd: CardData = CardDatabase.get_card("CSV2C", "055")
	var miraidon_cd: CardData = CardDatabase.get_card("CSV1C", "050")
	var generator_cd: CardData = CardDatabase.get_card("CSV1C", "107")
	var rare_candy_cd: CardData = CardDatabase.get_card("CSVH1C", "045")
	var tm_evo_cd: CardData = CardDatabase.get_card("CSV5C", "119")
	if gardevoir_cd == null or miraidon_cd == null or generator_cd == null or rare_candy_cd == null or tm_evo_cd == null:
		return "Required real card JSON should exist for capability extraction"
	player.deck.append(CardInstance.create(gardevoir_cd, 0))
	player.deck.append(CardInstance.create(miraidon_cd, 0))
	player.deck.append(CardInstance.create(generator_cd, 0))
	player.deck.append(CardInstance.create(rare_candy_cd, 0))
	player.deck.append(CardInstance.create(tm_evo_cd, 0))
	var capabilities: Dictionary = extractor.call("extract_for_player", player)
	var interaction_ids: Array = capabilities.get("interaction_ids", [])
	var roles: Array = capabilities.get("strategic_roles", [])
	return run_checks([
		assert_true("embrace_energy" in interaction_ids, "Gardevoir capabilities should expose the real Psychic Embrace energy step"),
		assert_true("embrace_target" in interaction_ids, "Gardevoir capabilities should expose the real Psychic Embrace target step"),
		assert_true("psychic_embrace_assignments" in interaction_ids, "Gardevoir capabilities should expose the strategic Psychic Embrace assignment alias"),
		assert_true("search_to_bench" in interaction_ids, "Miraidon/TM Evolution capabilities should expose search-to-bench interactions"),
		assert_true("energy_assignments" in interaction_ids, "Miraidon Electric Generator should expose energy assignment interactions"),
		assert_true("stage2_card" in interaction_ids, "Rare Candy should expose stage2_card interaction"),
		assert_true("target_pokemon" in interaction_ids, "Rare Candy should expose target_pokemon interaction"),
		assert_true("energy_acceleration" in roles, "Gardevoir should be recognized as an energy acceleration engine"),
		assert_true("bench_setup_engine" in roles, "Miraidon should be recognized as a bench setup engine"),
	])


func test_llm_nested_psychic_embrace_alias_controls_real_steps() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var gardevoir_cd: CardData = CardDatabase.get_card("CSV2C", "055")
	var drifloon_cd: CardData = CardDatabase.get_card("CSV2C", "060")
	var psychic_cd: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	if gardevoir_cd == null or drifloon_cd == null or psychic_cd == null:
		return "Required Gardevoir card JSON should exist"
	var player := gs.players[0]
	var gardevoir_slot := _make_slot(gardevoir_cd, 0)
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	player.active_pokemon = gardevoir_slot
	player.bench.append(drifloon_slot)
	var psychic := CardInstance.create(psychic_cd, 0)
	_inject_llm_tree(strategy, 3, {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [{
				"type": "use_ability",
				"pokemon": "Gardevoir ex",
				"interactions": {
					"psychic_embrace_assignments": {"prefer": ["Psychic Energy", "Drifloon"]},
				},
			}],
		}],
	})
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": gardevoir_slot.get_top_card(),
	}
	var picked_energy: Array = strategy.call("pick_interaction_items", [psychic], {"id": "embrace_energy", "max_select": 1}, context)
	var target_score: float = float(strategy.call("score_interaction_target", drifloon_slot, {"id": "embrace_target"}, context))
	var active_score: float = float(strategy.call("score_interaction_target", gardevoir_slot, {"id": "embrace_target"}, context))
	return run_checks([
		assert_eq(picked_energy.size(), 1, "Psychic Embrace alias should select the real embrace_energy source"),
		assert_true(picked_energy[0] == psychic, "Psychic Embrace alias should pick Psychic Energy"),
		assert_true(target_score > active_score, "Psychic Embrace alias should prefer the requested Drifloon target"),
	])


func test_llm_queue_controls_sada_assignment_sources() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var sada := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Professor Sada's Vitality", "search_target": "Basic Fighting Energy,Basic Lightning Energy", "target": "Raging Bolt ex", "position": "active"},
	])
	var picked: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {"id": "sada_assignments", "max_select": 2}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": sada,
	})
	return run_checks([
		assert_eq(picked.size(), 2, "LLM Sada source intent should pick two energies"),
		assert_true(picked[0] == fighting, "LLM Sada source intent should pick Fighting first"),
		assert_true(picked[1] == lightning, "LLM Sada source intent should pick Lightning second"),
	])


func test_llm_queue_scores_sada_assignment_target_by_position() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_bolt := _make_slot(_make_raging_bolt_cd(), 0)
	var bench_bolt := _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon = active_bolt
	player.bench.append(bench_bolt)
	var sada := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Professor Sada's Vitality", "target": "Raging Bolt ex", "position": "active"},
	])
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": sada,
	}
	var active_score: float = float(strategy.call("score_interaction_target", active_bolt, {"id": "sada_assignments"}, context))
	var bench_score: float = float(strategy.call("score_interaction_target", bench_bolt, {"id": "sada_assignments"}, context))
	return run_checks([
		assert_true(active_score > bench_score, "LLM target position should prefer active Raging Bolt"),
		assert_true(active_score >= 90000.0, "LLM target match should receive a dominant interaction score"),
	])


func test_llm_bridge_scores_opponent_bench_gust_target_by_position() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(4)
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_pokemon_cd("Low HP Target", "Basic", "C", 120), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Game Winning Target", "Basic", "C", 120), 1))
	var boss_cd := _make_trainer_cd("Boss's Orders", "Supporter")
	boss_cd.effect_id = "8e1fa2c9018db938084c94c7c970d419"
	var boss := CardInstance.create(boss_cd, 0)
	_inject_llm_queue(strategy, 4, [
		{
			"type": "play_trainer",
			"card": "Boss's Orders",
			"selection_policy": {
				"opponent_bench_target": "bench_1",
				"gust_target": "bench_1",
			},
		},
	])
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": boss,
	}
	var bench0_score: float = float(strategy.call("score_interaction_target", opponent.bench[0], {"id": "opponent_bench_target"}, context))
	var bench1_score: float = float(strategy.call("score_interaction_target", opponent.bench[1], {"id": "opponent_bench_target"}, context))
	return run_checks([
		assert_true(bench1_score > bench0_score, "LLM selection_policy.opponent_bench_target should control Boss target selection"),
		assert_true(bench1_score >= 90000.0, "Requested opponent bench target should receive dominant score"),
	])


func test_llm_bridge_sada_fills_missing_attack_energy_before_extra_energy() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter")
	sada_cd.effect_id = "651276c51911345aa091c1c7b87f3f4f"
	var sada := CardInstance.create(sada_cd, 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	_inject_llm_queue(strategy, 4, [
		{
			"type": "play_trainer",
			"card": "Professor Sada's Vitality",
			"search_target": "Basic Grass Energy,Basic Lightning Energy",
			"target": "Raging Bolt ex",
			"position": "active",
		},
	])
	var picked: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {"id": "sada_assignments", "max_select": 2}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": sada,
	})
	var target_score: float = float(strategy.call("score_interaction_target", player.active_pokemon, {"id": "sada_assignments"}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": sada,
		"assignment_source": fighting,
	}))
	return run_checks([
		assert_eq(picked.size(), 1, "Sada fallback should only pick cost-filling Energy when a real attack-cost gap exists"),
		assert_true(picked[0] == fighting, "Sada fallback should prefer Fighting to complete Raging Bolt's Lightning+Fighting cost"),
		assert_true(target_score >= 90000.0, "Sada target fallback should strongly prefer the active attacker needing that Energy"),
	])


func test_llm_prompt_exposes_gust_ko_opportunity_and_route() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	for i: int in 2:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i, "Item"), 0))
	var target_cd := _make_pokemon_cd("Damaged Bench ex", "Basic", "C", 180)
	target_cd.mechanic = "ex"
	var bench_target := _make_slot(target_cd, 1)
	bench_target.damage_counters = 60
	opponent.bench.append(bench_target)
	var boss_cd := _make_trainer_cd("Boss's Orders", "Supporter")
	boss_cd.effect_id = "8e1fa2c9018db938084c94c7c970d419"
	var boss := CardInstance.create(boss_cd, 0)
	player.hand.append(boss)
	var legal_actions := [
		{"kind": "play_trainer", "card": boss, "targets": [], "requires_interaction": true},
		{"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	]
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, legal_actions)
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var opportunities: Array = facts.get("gust_ko_opportunities", [])
	var routes: Array = payload.get("candidate_routes", [])
	var has_gust_route := false
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "gust_ko":
			has_gust_route = true
			break
	return run_checks([
		assert_false(opportunities.is_empty(), "Prompt facts should expose Boss/Catcher bench KO opportunities"),
		assert_eq(str((opportunities[0] as Dictionary).get("target_position", "")), "bench_0", "Gust KO fact should name the opponent bench position"),
		assert_true(bool((opportunities[0] as Dictionary).get("game_winning", false)), "Gust KO fact should flag game-winning prize routes"),
		assert_true(has_gust_route, "Candidate route builder should expose a route:gust_ko wrapper"),
	])


func test_llm_prompt_sorts_deterministic_gust_before_coin_flip_catcher() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	for i: int in 2:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i, "Item"), 0))
	var target_cd := _make_pokemon_cd("Low Bench ex", "Basic", "C", 180)
	target_cd.mechanic = "ex"
	var bench_target := _make_slot(target_cd, 1)
	bench_target.damage_counters = 120
	opponent.bench.append(bench_target)
	var catcher_cd := _make_trainer_cd("Pokemon Catcher", "Item")
	catcher_cd.name_en = "Pokemon Catcher"
	catcher_cd.effect_id = "3a6d419769778b40091e69fbd76737ec"
	var catcher := CardInstance.create(catcher_cd, 0)
	var boss_cd := _make_trainer_cd("Boss's Orders", "Supporter")
	boss_cd.effect_id = "8e1fa2c9018db938084c94c7c970d419"
	var boss := CardInstance.create(boss_cd, 0)
	player.hand.append(catcher)
	player.hand.append(boss)
	var legal_actions := [
		{"kind": "play_trainer", "card": catcher, "targets": [], "requires_interaction": true},
		{"kind": "play_trainer", "card": boss, "targets": [], "requires_interaction": true},
		{"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	]
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, legal_actions)
	var legal_refs: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var boss_action_id := ""
	var catcher_action_id := ""
	for raw: Variant in legal_refs:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("card", "")) == "Boss's Orders":
			boss_action_id = str(ref.get("id", ""))
		if str(ref.get("card", "")) == "Pokemon Catcher":
			catcher_action_id = str(ref.get("id", ""))
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var opportunities: Array = facts.get("gust_ko_opportunities", []) if facts.get("gust_ko_opportunities", []) is Array else []
	var first_opp: Dictionary = opportunities[0] if not opportunities.is_empty() and opportunities[0] is Dictionary else {}
	return run_checks([
		assert_true(boss_action_id != "", "Prompt legal refs should include Boss's Orders"),
		assert_true(catcher_action_id != "", "Prompt legal refs should include Pokemon Catcher"),
		assert_eq(str(first_opp.get("gust_action_id", "")), boss_action_id, "Deterministic Boss gust should be the first KO opportunity"),
		assert_true(bool(first_opp.get("gust_deterministic", false)), "First gust KO opportunity should be marked deterministic"),
	])


func test_llm_prompt_exposes_defensive_gust_when_no_attack_and_opponent_active_is_loaded() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var boss_cd := _make_trainer_cd("Boss's Orders", "Supporter")
	boss_cd.effect_id = "8e1fa2c9018db938084c94c7c970d419"
	var boss := CardInstance.create(boss_cd, 0)
	player.hand.append(boss)
	var raikou_cd := _make_pokemon_cd("Raikou V", "Basic", "L", 200)
	raikou_cd.retreat_cost = 1
	opponent.active_pokemon = _make_slot(raikou_cd, 1)
	opponent.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 1))
	opponent.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 1))
	var iron_hands_cd := _make_pokemon_cd("Iron Hands ex", "Basic", "L", 230)
	iron_hands_cd.retreat_cost = 4
	opponent.bench.append(_make_slot(iron_hands_cd, 1))
	var mew_cd := _make_pokemon_cd("Mew ex", "Basic", "P", 180)
	mew_cd.retreat_cost = 0
	opponent.bench.append(_make_slot(mew_cd, 1))
	var legal_actions := [
		{"kind": "play_trainer", "card": boss, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	]
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, legal_actions)
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var opportunities: Array = facts.get("defensive_gust_opportunities", []) if facts.get("defensive_gust_opportunities", []) is Array else []
	var routes: Array = payload.get("candidate_routes", []) if payload.get("candidate_routes", []) is Array else []
	var has_route := false
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "defensive_gust_stall":
			has_route = true
			break
	var first_opp: Dictionary = opportunities[0] if not opportunities.is_empty() and opportunities[0] is Dictionary else {}
	return run_checks([
		assert_false(opportunities.is_empty(), "Prompt should expose defensive gust when no attack is legal and opponent active is energized"),
		assert_eq(str(first_opp.get("target_name", "")), "Iron Hands ex", "Defensive gust should prefer a low-energy high-retreat stall target"),
		assert_true(has_route, "Candidate routes should include the defensive gust stall wrapper"),
	])


func test_llm_runtime_end_turn_conversion_respects_future_attack_goal_source() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160)
	squawk_cd.name_en = "Squawkabilly ex"
	squawk_cd.mechanic = "ex"
	squawk_cd.attacks = [{"name": "Motivate", "cost": "C", "damage": "20"}]
	player.active_pokemon = _make_slot(squawk_cd, 0)
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Low HP Opponent", "Basic", "C", 20), 1)
	var future_goal := {
		"id": "future:attack_after_pivot:bench_0:1:Thundering Bolt",
		"action_id": "future:attack_after_pivot:bench_0:1:Thundering Bolt",
		"type": "attack",
		"future": true,
		"attack_index": 1,
		"attack_name": "Thundering Bolt",
		"source_pokemon": "Raging Bolt ex",
		"reachable_with_known_resources": true,
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	strategy.set("_llm_decision_tree", {"branches": [{"when": [{"fact": "always"}], "actions": [{"id": "end_turn"}]}]})
	strategy.set("_llm_action_queue", [{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "capability": "end_turn"}])
	strategy.set("_llm_queue_turn", 7)
	var catalog := {
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	catalog[str(future_goal.get("id"))] = future_goal
	strategy.set("_llm_action_catalog", catalog)
	var raw_queue: Array[Dictionary] = [
		future_goal,
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var compiled_queue: Array = strategy.call("_compile_selected_action_queue", raw_queue, gs, 0)
	strategy.set("_llm_action_queue", compiled_queue)
	var squawk_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Motivate", "requires_interaction": true}
	var score: float = float(strategy.call("score_action_absolute", squawk_attack, gs, 0))
	var has_future_goals: bool = bool(strategy.call("_route_compiler_has_future_attack_goals", gs))
	return run_checks([
		assert_true(has_future_goals, "Test setup should expose route compiler future attack goals"),
		assert_true(score < 10000.0,
			"end_turn must not convert a future Raging Bolt attack goal into the current support Pokemon attack (score=%f)" % score),
	])


func test_llm_runtime_blocks_end_turn_score_when_compiler_blocks_terminal() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	strategy.set("_llm_decision_tree", {"branches": [{"when": [{"fact": "always"}], "actions": [{"id": "end_turn"}]}]})
	strategy.set("_llm_action_queue", [{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "capability": "end_turn"}])
	strategy.set("_llm_queue_turn", 7)
	var compiler_results := {}
	compiler_results[7] = {"blocked_end_turn": true}
	strategy.set("_llm_route_compiler_results_by_turn", compiler_results)
	var end_turn_score: float = float(strategy.call("score_action_absolute", {"kind": "end_turn"}, gs, 0))
	return assert_true(end_turn_score <= -1000.0,
		"Blocked compiler terminal must be actively negative-scored, not merely ignored by queue matching (score=%f)" % end_turn_score)


func test_raging_bolt_llm_blocks_greninja_when_only_core_energy_would_be_discarded() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	player.bench.append(_make_slot(greninja_cd, 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	var greninja_action := {
		"kind": "use_ability",
		"source_slot": player.bench[1],
		"ability_index": 0,
		"requires_interaction": true,
	}
	var blocked: bool = bool(strategy.call("_is_core_energy_preservation_risk_action", greninja_action, gs, 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var allowed_with_grass: bool = bool(strategy.call("_is_core_energy_preservation_risk_action", greninja_action, gs, 0))
	return run_checks([
		assert_true(blocked, "Greninja draw must be blocked when it can only discard the unique Lightning/Fighting needed for Raging Bolt's next attack"),
		assert_false(allowed_with_grass, "Greninja draw should remain available when Grass Energy can be discarded instead of route-critical core Energy"),
	])


func test_raging_bolt_llm_blocks_hand_reset_that_shuffles_missing_core_energy() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var iono_cd := _make_named_trainer_cd("奇树", "Iono", "Supporter")
	var iono := CardInstance.create(iono_cd, 0)
	player.hand.append(iono)
	player.hand.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Pal Pad"), 0))
	var iono_action := {
		"kind": "play_trainer",
		"card": iono,
		"requires_interaction": false,
	}
	var blocked: bool = bool(strategy.call("_is_core_energy_preservation_risk_action", iono_action, gs, 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var allowed_when_ready: bool = bool(strategy.call("_is_core_energy_preservation_risk_action", iono_action, gs, 0))
	return run_checks([
		assert_true(blocked, "Iono/Research-style hand reset must be blocked while hand contains the missing Fighting Energy for Raging Bolt"),
		assert_false(allowed_when_ready, "Hand reset should not be blocked by core preservation once Raging Bolt already has Lightning + Fighting"),
	])


func test_llm_runtime_end_turn_conversion_allows_matching_future_attack_goal() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var future_goal := {
		"id": "future:attack_after_pivot:active:1:Thundering Bolt",
		"action_id": "future:attack_after_pivot:active:1:Thundering Bolt",
		"type": "attack",
		"future": true,
		"attack_index": 1,
		"attack_name": "Thundering Bolt",
		"source_pokemon": "Raging Bolt ex",
		"reachable_with_known_resources": true,
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	strategy.set("_llm_decision_tree", {"branches": [{"when": [{"fact": "always"}], "actions": [{"id": "end_turn"}]}]})
	strategy.set("_llm_action_queue", [{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "capability": "end_turn"}])
	strategy.set("_llm_queue_turn", 7)
	var catalog := {
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	}
	catalog[str(future_goal.get("id"))] = future_goal
	strategy.set("_llm_action_catalog", catalog)
	var raw_queue: Array[Dictionary] = [
		future_goal,
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var compiled_queue: Array = strategy.call("_compile_selected_action_queue", raw_queue, gs, 0)
	strategy.set("_llm_action_queue", compiled_queue)
	var burst_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Thundering Bolt", "requires_interaction": true}
	var score: float = float(strategy.call("score_action_absolute", burst_attack, gs, 0))
	return assert_true(score >= 90000.0,
		"end_turn may convert to the matching future Raging Bolt attack goal after setup (score=%f)" % score)


func test_raging_bolt_llm_handoff_prefers_backup_bolt_over_charged_support() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Knocked Out Placeholder", "Basic", "C", 50), 0)
	var bolt := _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon := _make_slot(ogerpon_cd, 0)
	ogerpon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	player.bench.append(ogerpon)
	player.bench.append(bolt)
	var context := {"game_state": gs, "player_index": 0}
	var bolt_score: float = float(strategy.call("score_handoff_target", bolt, {"id": "send_out"}, context))
	var ogerpon_score: float = float(strategy.call("score_handoff_target", ogerpon, {"id": "send_out"}, context))
	return assert_true(bolt_score > ogerpon_score,
		"send_out should preserve prize-race attack continuity by preferring backup Raging Bolt over a charged support pivot (bolt=%f ogerpon=%f)" % [bolt_score, ogerpon_score])


func test_raging_bolt_llm_blocks_switch_cart_when_only_support_targets_exist() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	player.bench.append(_make_slot(greninja_cd, 0))
	var switch_cart_cd := _make_named_trainer_cd("Switch Cart", "Switch Cart", "Item")
	var switch_cart := CardInstance.create(switch_cart_cd, 0)
	var switch_action := {"kind": "play_trainer", "card": switch_cart, "requires_interaction": true}
	var blocked_score: float = float(strategy.call("score_action_absolute", switch_action, gs, 0))
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	var allowed_score: float = float(strategy.call("score_action_absolute", switch_action, gs, 0))
	return run_checks([
		assert_true(blocked_score <= -1000.0,
			"Switch Cart should be blocked when it can only promote fragile support engines (score=%f)" % blocked_score),
		assert_true(allowed_score > -1000.0,
			"Switch Cart should remain available when a Raging Bolt or real pivot target exists (score=%f)" % allowed_score),
	])


func test_raging_bolt_llm_switch_target_prefers_attacker_over_support_engine() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	var greninja := _make_slot(greninja_cd, 0)
	var bolt := _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.append(greninja)
	player.bench.append(bolt)
	var context := {"game_state": gs, "player_index": 0}
	var bolt_score: float = float(strategy.call("score_interaction_target", bolt, {"id": "switch_target"}, context))
	var greninja_score: float = float(strategy.call("score_interaction_target", greninja, {"id": "switch_target"}, context))
	return run_checks([
		assert_true(bolt_score > greninja_score,
			"Switch target should prefer the attacker/pivot over Radiant Greninja (bolt=%f greninja=%f)" % [bolt_score, greninja_score]),
		assert_true(greninja_score <= -1000.0,
			"Radiant Greninja should not be selected as a casual active pivot target (score=%f)" % greninja_score),
	])


func test_raging_bolt_llm_pick_switch_target_prefers_attacker_without_llm_low_level_target() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160)
	squawk_cd.name_en = "Squawkabilly ex"
	squawk_cd.mechanic = "ex"
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	player.active_pokemon = _make_slot(squawk_cd, 0)
	var greninja := _make_slot(greninja_cd, 0)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon := _make_slot(ogerpon_cd, 0)
	ogerpon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bolt := _make_slot(_make_raging_bolt_cd(), 0)
	bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.bench.append(greninja)
	player.bench.append(ogerpon)
	player.bench.append(bolt)
	var picked: Array = strategy.call("pick_interaction_items", [greninja, ogerpon, bolt], {"id": "switch_target", "max_select": 1}, {
		"game_state": gs,
		"player_index": 0,
	})
	var picked_slot: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_eq(picked.size(), 1, "Switch Cart target picker should choose one pivot target"),
		assert_true(picked_slot == bolt, "Switch Cart without a low-level LLM target should still promote Raging Bolt over Radiant Greninja"),
	])


func test_raging_bolt_llm_payload_exposes_continuity_route_before_nonfinal_attack() -> String:
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
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon := CardInstance.create(ogerpon_cd, 0)
	var nest_cd := _make_trainer_cd("Nest Ball", "Item")
	nest_cd.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	var nest := CardInstance.create(nest_cd, 0)
	player.hand.append(backup_bolt)
	player.hand.append(ogerpon)
	player.hand.append(nest)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_basic_to_bench", "card": backup_bolt},
		{"kind": "play_basic_to_bench", "card": ogerpon},
		{"kind": "play_trainer", "card": nest, "requires_interaction": true},
		{"kind": "attack", "attack_index": 1, "source_slot": player.active_pokemon, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {}) if payload.get("turn_tactical_facts", {}) is Dictionary else {}
	var continuity: Dictionary = facts.get("continuity_contract", {}) if facts.get("continuity_contract", {}) is Dictionary else {}
	var route: Dictionary = {}
	for raw_route: Variant in payload.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:continuity_before_attack":
			route = raw_route
			break
	var route_action_ids: Array[String] = []
	for raw_action: Variant in route.get("actions", []):
		if raw_action is Dictionary:
			route_action_ids.append(str((raw_action as Dictionary).get("id", "")))
	var first_action := route_action_ids[0] if not route_action_ids.is_empty() else ""
	var last_action := route_action_ids[route_action_ids.size() - 1] if not route_action_ids.is_empty() else ""
	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "Continuity contract should be visible in LLM tactical facts before a non-final attack"),
		assert_true(not route.is_empty(), "Payload should expose route:continuity_before_attack as a selectable route action"),
		assert_true(first_action.begins_with("play_basic_to_bench:"), "Continuity route should start by filling backup board before attacking: %s" % JSON.stringify(route_action_ids)),
		assert_true(last_action.begins_with("attack:1"), "Continuity route should still close with Raging Bolt's primary attack: %s" % JSON.stringify(route_action_ids)),
		assert_true(strategy.get("_llm_route_candidates_by_id").has("route:continuity_before_attack"), "Runtime route registry should register the continuity route id"),
	])


