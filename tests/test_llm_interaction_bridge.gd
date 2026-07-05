class_name TestLLMInteractionBridge

extends "res://tests/helpers/LLMInteractionBridgeShared.gd"

func test_llm_interaction_bridge_script_loads() -> String:
	return run_checks([
		assert_not_null(_load_script(LLM_DECK_STRATEGY_BASE_SCRIPT_PATH), "LLMDeckStrategyBase.gd should load"),
		assert_not_null(_load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH), "LLMInteractionIntentBridge.gd should load"),
		assert_not_null(_load_script(LLM_DECISION_TREE_EXECUTOR_SCRIPT_PATH), "LLMDecisionTreeExecutor.gd should load"),
		assert_not_null(_load_script(LLM_DECK_CAPABILITY_EXTRACTOR_SCRIPT_PATH), "LLMDeckCapabilityExtractor.gd should load"),
		assert_not_null(_load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH), "LLMTurnPlanPromptBuilder.gd should load"),
		assert_not_null(_load_script(LLM_ROUTE_COMPILER_SCRIPT_PATH), "LLMRouteCompiler.gd should load"),
		assert_not_null(_load_script(LLM_ROUTE_CANDIDATE_BUILDER_SCRIPT_PATH), "LLMRouteCandidateBuilder.gd should load"),
		assert_not_null(_load_script(LLM_ROUTE_ACTION_REGISTRY_SCRIPT_PATH), "LLMRouteActionRegistry.gd should load"),
	])


func test_llm_decision_tree_executor_keeps_granted_attack_actions() -> String:
	var script := _load_script(LLM_DECISION_TREE_EXECUTOR_SCRIPT_PATH)
	if script == null:
		return "LLMDecisionTreeExecutor.gd should exist"
	var executor: RefCounted = script.new()
	var gs := _make_game_state(4)
	var queue: Array = executor.call("select_action_queue", {
		"actions": [{
			"id": "granted_attack:-1:tm_evolution",
			"type": "granted_attack",
			"attack_name": "Evolution",
			"interactions": {"search_targets": ["Kirlia", "Kirlia"]},
		}],
		"fallback_actions": [{"id": "end_turn"}],
	}, gs, 0)
	if queue.is_empty():
		return "Executor should not drop granted_attack actions from the selected queue"
	var first: Dictionary = queue[0] if queue[0] is Dictionary else {}
	return run_checks([
		assert_eq(str(first.get("type", "")), "granted_attack", "Granted attack type should survive normalization"),
		assert_eq(str(first.get("action_id", "")), "granted_attack:-1:tm_evolution", "Granted attack action id should survive normalization"),
		assert_eq(str(first.get("attack_name", "")), "Evolution", "Granted attack metadata should survive normalization"),
	])


func test_llm_prompt_builder_includes_full_battle_context_without_hidden_opponent_hand() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(4)
	gs.first_player_index = 1
	gs.energy_attached_this_turn = true
	gs.stadium_played_this_turn = true
	gs.vstar_power_used = [true, false]
	gs.last_knockout_turn_against = [3, -999]
	var player := gs.players[0]
	var opponent := gs.players[1]
	var bolt_cd := _make_raging_bolt_cd()
	bolt_cd.weakness_energy = "P"
	bolt_cd.weakness_value = "x2"
	var bolt_slot := _make_slot(bolt_cd, 0)
	bolt_slot.damage_counters = 40
	bolt_slot.status_conditions["poisoned"] = true
	bolt_slot.effects.append({"type": "attack_lock", "source": "test", "turn": 4})
	bolt_slot.attached_tool = CardInstance.create(_make_trainer_cd("Ancient Booster Energy Capsule", "Tool"), 0)
	bolt_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon = bolt_slot
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	player.lost_zone.append(CardInstance.create(_make_trainer_cd("Lost Vacuum", "Item"), 0))
	for i: int in 6:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i, "Item"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220), 1)
	opponent.active_pokemon.damage_counters = 70
	opponent.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 1))
	opponent.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 1))
	opponent.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 1))
	for i: int in 4:
		opponent.prizes.append(CardInstance.create(_make_trainer_cd("OpponentPrize%d" % i, "Item"), 1))
	gs.stadium_card = CardInstance.create(_make_trainer_cd("Town Store", "Stadium"), 0)
	gs.stadium_owner_index = 0
	var payload: Dictionary = builder.call("build_request_payload", gs, 0)
	var game_state: Dictionary = payload.get("game_state", {})
	var instruction_text := "\n".join(payload.get("instructions", PackedStringArray()))
	var action_schema: Dictionary = (((payload.get("response_format", {}) as Dictionary).get("properties", {}) as Dictionary).get("decision_tree", {}) as Dictionary)
	var my_field: Dictionary = game_state.get("my_field", {})
	var opponent_field: Dictionary = game_state.get("opponent_field", {})
	var active: Dictionary = my_field.get("active", {})
	var stadium: Dictionary = game_state.get("stadium", {})
	var turn_flags: Dictionary = game_state.get("turn_flags", {})
	return run_checks([
		assert_eq(str(game_state.get("battle_context_schema", "")), "battle_context_v2", "Prompt should mark the rich battle context contract"),
		assert_str_contains(instruction_text, "battle_context_v2", "Prompt instructions should explicitly require using the rich battle context"),
		assert_str_contains(instruction_text, "opponent hand_count", "Prompt instructions should mention opponent hand count"),
		assert_true(not action_schema.is_empty(), "Prompt should still include response schema"),
		assert_eq(str(game_state.get("phase", "")), "MAIN", "Prompt should expose current phase"),
		assert_eq(int(my_field.get("hand_count", -1)), 2, "Prompt should expose exact own hand count"),
		assert_true(my_field.has("hand"), "Prompt should expose own exact hand groups"),
		assert_eq(int(opponent_field.get("hand_count", -1)), 2, "Prompt should expose opponent hand count"),
		assert_false(opponent_field.has("hand"), "Prompt must not leak opponent hidden hand contents"),
		assert_eq(int(active.get("damage_counters", -1)), 40, "Prompt should expose own active damage counters"),
		assert_eq(str((active.get("attached_tool", {}) as Dictionary).get("name", "")), "Ancient Booster Energy Capsule", "Prompt should expose attached tool"),
		assert_true("poisoned" in (active.get("active_statuses", []) as Array), "Prompt should expose active status conditions"),
		assert_eq(str(((active.get("effects", []) as Array)[0] as Dictionary).get("type", "")), "attack_lock", "Prompt should expose persistent slot effects"),
		assert_eq(str(stadium.get("name", "")), "Town Store", "Prompt should expose stadium card"),
		assert_eq(int(stadium.get("owner_index", -1)), 0, "Prompt should expose stadium owner"),
		assert_true(bool(turn_flags.get("energy_attached_this_turn", false)), "Prompt should expose turn energy flag"),
		assert_true(bool(turn_flags.get("my_vstar_power_used", false)), "Prompt should expose my VSTAR usage"),
		assert_eq(int(my_field.get("prizes_remaining", -1)), 6, "Prompt should expose my prizes remaining"),
		assert_eq(int(opponent_field.get("prizes_remaining", -1)), 4, "Prompt should expose opponent prizes remaining"),
	])


func test_action_id_prompt_includes_compact_board_hp_status_and_tools() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var bolt_slot := _make_slot(_make_raging_bolt_cd(), 0)
	bolt_slot.damage_counters = 30
	bolt_slot.status_conditions["burned"] = true
	bolt_slot.attached_tool = CardInstance.create(_make_trainer_cd("Ancient Booster Energy Capsule", "Tool"), 0)
	bolt_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon = bolt_slot
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220), 1)
	opponent.active_pokemon.damage_counters = 90
	opponent.active_pokemon.status_conditions["poisoned"] = true
	opponent.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 1)
	opponent.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 1))
	opponent.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 1))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [{"kind": "end_turn"}])
	var compact_state: Dictionary = payload.get("game_state", {})
	var my_active: Dictionary = (compact_state.get("my", {}) as Dictionary).get("active", {})
	var opponent_state: Dictionary = compact_state.get("opponent", {})
	var opponent_active: Dictionary = opponent_state.get("active", {})
	return run_checks([
		assert_eq(int(my_active.get("hp_remaining", -1)), 210, "Compact action prompt should expose own active remaining HP"),
		assert_eq(str(my_active.get("attached_tool", "")), "Ancient Booster Energy Capsule", "Compact action prompt should expose own attached tool"),
		assert_true((my_active.get("status", []) as Array).has("burned"), "Compact action prompt should expose own status"),
		assert_eq(int(opponent_active.get("hp_remaining", -1)), 130, "Compact action prompt should expose opponent active remaining HP"),
		assert_eq(str(opponent_active.get("attached_tool", "")), "Bravery Charm", "Compact action prompt should expose opponent attached tool"),
		assert_true((opponent_active.get("status", []) as Array).has("poisoned"), "Compact action prompt should expose opponent status"),
		assert_eq(int(opponent_state.get("hand_count", -1)), 2, "Compact action prompt should expose opponent hand count without leaking cards"),
		assert_false(opponent_state.has("hand"), "Compact action prompt must not leak opponent hidden hand contents"),
	])


func test_raging_bolt_llm_payload_includes_deck_strategy_prompt() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	var instructions_text := "\n".join(payload.get("instructions", PackedStringArray()))
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "raging_bolt_ogerpon_llm", "Raging Bolt LLM payload should identify the deck strategy prompt"),
		assert_true(prompt_lines.size() >= 8, "Raging Bolt prompt should be a deck-specific tactical layer, not a token hint"),
		assert_str_contains(prompt_text, "卡组编辑器", "Raging Bolt prompt should explain that deck strategy comes from the editable deck strategy field"),
		assert_str_contains(prompt_text, "猛雷鼓ex", "Raging Bolt prompt should name the main attacker"),
		assert_str_contains(prompt_text, "厄诡椪", "Raging Bolt prompt should include the Ogerpon engine"),
		assert_str_contains(prompt_text, "奥琳博士的气魄", "Raging Bolt prompt should include the Sada acceleration line"),
		assert_str_contains(prompt_text, "3能量=210", "Raging Bolt prompt should teach burst damage math"),
		assert_str_contains(prompt_text, "Thundering Bolt", "Raging Bolt prompt should copy the active second attack name when available"),
		assert_str_contains(prompt_text, "执行边界", "Raging Bolt prompt should keep card execution delegated to the rule/action layer"),
		assert_str_contains(instructions_text, "Read deck_strategy_prompt", "Base instructions should tell the LLM to consume deck-specific prompt"),
	])


func test_raging_bolt_llm_payload_uses_editable_deck_strategy_text() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	strategy.call("set_deck_strategy_text", "【卡组定位】玩家自定义猛雷鼓打法\n- 自定义优先铺第二只猛雷鼓")
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_text := "\n".join(payload.get("deck_strategy_prompt", PackedStringArray()))
	return run_checks([
		assert_str_contains(prompt_text, "玩家自定义猛雷鼓打法", "LLM prompt should include the editable deck strategy text"),
		assert_str_contains(prompt_text, "自定义优先铺第二只猛雷鼓", "LLM prompt should preserve player-authored tactical lines"),
		assert_false(prompt_text.contains("【核心计划】猛雷鼓ex是主要攻击手"), "Custom strategy text should replace the built-in fallback strategy body"),
	])


func test_dragapult_charizard_llm_payload_includes_deck_strategy_prompt() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var raw_payload: Variant = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var payload: Dictionary = raw_payload if raw_payload is Dictionary else {}
	var raw_prompt_lines: Variant = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_lines: PackedStringArray = raw_prompt_lines if raw_prompt_lines is PackedStringArray else PackedStringArray()
	var prompt_text := "\n".join(prompt_lines)
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "dragapult_charizard_llm", "Dragapult Charizard LLM payload should identify its deck strategy prompt"),
		assert_true(prompt_lines.size() >= 8, "Dragapult Charizard LLM prompt should provide deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "Dragapult ex", "Prompt should name the primary spread attacker"),
		assert_str_contains(prompt_text, "Charizard ex", "Prompt should name the acceleration/conversion attacker"),
		assert_str_contains(prompt_text, "Rare Candy", "Prompt should cover Stage 2 conversion resources"),
		assert_str_contains(prompt_text, "Boss", "Prompt should cover gust and prize targeting"),
	])


func test_dragapult_charizard_llm_registry_creates_variant() -> String:
	var registry_script := _load_script("res://scripts/ai/DeckStrategyRegistry.gd")
	if registry_script == null:
		return "DeckStrategyRegistry.gd should load"
	var registry: RefCounted = registry_script.new()
	var strategy: RefCounted = registry.call("create_strategy_by_id", "dragapult_charizard_llm")
	return run_checks([
		assert_not_null(strategy, "Registry should create dragapult_charizard_llm"),
		assert_eq(str(strategy.call("get_strategy_id")), "dragapult_charizard_llm", "LLM variant should report the registered strategy id"),
	])


func test_dragapult_charizard_llm_blocks_stage2_retreat_to_support() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dragapult ex", "Stage2", "P", 320), 0)
	var fez_slot := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210), 0)
	player.bench.append(fez_slot)
	var action := {"kind": "retreat", "bench_target": fez_slot}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, action, gs, 0)), "Dragapult LLM should block retreating a Stage 2 attacker into a support-only Pokemon"),
		assert_true(float(strategy.call("score_action_absolute", action, gs, 0)) <= -1000.0, "Blocked Stage 2 retreat should stay blocked even through rules fallback"),
	])


func test_dragapult_charizard_llm_blocks_off_plan_support_energy_and_bad_tools() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var dragapult_slot := _make_slot(_make_pokemon_cd("Dragapult ex", "Stage2", "P", 320), 0)
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190), 0)
	player.active_pokemon = dragapult_slot
	player.bench.append(rotom_slot)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var forest := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	strategy.set("_llm_action_catalog", {
		"attach_energy:c%d:active" % int(psychic.instance_id): {
			"id": "attach_energy:c%d:active" % int(psychic.instance_id),
			"action_id": "attach_energy:c%d:active" % int(psychic.instance_id),
			"type": "attach_energy",
			"card": "Psychic Energy",
			"position": "active",
		},
	})
	var bad_support_attach := {"kind": "attach_energy", "card": fire, "target_slot": rotom_slot}
	var bad_dragapult_attach := {"kind": "attach_energy", "card": fire, "target_slot": dragapult_slot}
	var bad_tm_attach := {"kind": "attach_tool", "card": tm, "target_slot": dragapult_slot}
	var bad_forest_attach := {"kind": "attach_tool", "card": forest, "target_slot": dragapult_slot}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_support_attach, gs, 0)), "Dragapult LLM should block attaching attack Energy to support-only Pokemon"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_dragapult_attach, gs, 0)), "Dragapult LLM should block Fire attach to Dragapult line while a Psychic attach is visible and no Psychic is attached"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_tm_attach, gs, 0)), "TM Evolution should not be attached to an already-evolved attacker"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_forest_attach, gs, 0)), "Forest Seal Stone should not be attached to non-V Stage 2 attackers"),
		assert_true(float(strategy.call("score_action_absolute", bad_support_attach, gs, 0)) <= -1000.0, "Blocked support Energy attach should stay blocked through rules fallback"),
	])


func test_dragapult_charizard_llm_blocks_opening_energy_to_benched_manaphy() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var manaphy := _make_slot(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	player.bench.append(manaphy)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var active_attach := {"kind": "attach_energy", "card": fire, "target_slot": player.active_pokemon}
	var manaphy_attach := {"kind": "attach_energy", "card": fire, "target_slot": manaphy}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, active_attach, gs, 0)),
			"LLM Dragapult/Charizard should allow opening Fire attachment to active Dreepy"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, manaphy_attach, gs, 0)),
			"LLM Dragapult/Charizard should hard-block opening Fire attachment to benched Manaphy"),
		assert_true(float(strategy.call("score_action_absolute", manaphy_attach, gs, 0)) <= -5000.0,
			"Benched Manaphy Energy attachment should stay blocked even through LLM/rules fallback"),
	])


func test_dragapult_charizard_llm_allows_active_support_energy_for_retreat() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var manaphy_cd := _make_pokemon_cd("Manaphy", "Basic", "W", 70)
	manaphy_cd.retreat_cost = 1
	player.active_pokemon = _make_slot(manaphy_cd, 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var active_attach := {"kind": "attach_energy", "card": fire, "target_slot": player.active_pokemon}
	return assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, active_attach, gs, 0)),
		"LLM Dragapult/Charizard should allow Energy on active support only when it can pay retreat into the attacker lane")


func test_dragapult_charizard_llm_blocks_rotom_terminal_draw_when_deck_is_low() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190), 0)
	player.active_pokemon = rotom_slot
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	var action := {"kind": "use_ability", "source_slot": rotom_slot, "ability_index": 0}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "use_ability", "pokemon": "Rotom V"}, action, gs, 0)), "Rotom terminal draw should be blocked through LLM queue matching when deck is low"),
		assert_true(float(strategy.call("score_action_absolute", action, gs, 0)) <= -1000.0, "Rotom terminal draw should be absolute-negative when deck is low"),
	])


func test_llm_contract_rejects_empty_schema_low_level_interactions() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var vacuum_cd := _make_trainer_cd("Lost Vacuum", "Item")
	vacuum_cd.effect_id = "8f655fea1f90164bfbccb7a95c223e17"
	vacuum_cd.description = "Put 1 card from your hand into the Lost Zone. Choose a Pokemon Tool or Stadium in play and put it into the Lost Zone."
	var vacuum := CardInstance.create(vacuum_cd, 0)
	player.hand.append(vacuum)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": vacuum, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var vacuum_id := ""
	var vacuum_schema: Dictionary = {}
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("card", "")) == "Lost Vacuum":
			vacuum_id = str((raw as Dictionary).get("id", ""))
			vacuum_schema = (raw as Dictionary).get("interaction_schema", {}) if (raw as Dictionary).get("interaction_schema", {}) is Dictionary else {}
	var contract_check: Dictionary = strategy.call("_validate_decision_tree_contract", {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [{"id": vacuum_id, "interactions": {"discard_target": "c%d" % int(vacuum.instance_id)}}],
		}],
		"fallback_actions": [{"id": "end_turn"}],
	})
	var sanitize_check: Dictionary = strategy.call("_sanitize_decision_tree_contract", {
		"branches": [
			{
				"when": [{"fact": "always"}],
				"actions": [{"id": vacuum_id, "interactions": {"discard_target": "c%d" % int(vacuum.instance_id)}}],
			},
			{
				"when": [{"fact": "always"}],
				"actions": [{"id": "end_turn"}],
			},
		],
		"fallback_actions": [{"id": "end_turn"}],
	})
	var kept_branches: Array = (sanitize_check.get("tree", {}) as Dictionary).get("branches", [])
	return run_checks([
		assert_eq(vacuum_schema.size(), 0, "Lost Vacuum fixture should expose no exact low-level interaction schema"),
		assert_false(bool(contract_check.get("valid", true)), "Contract validator should reject invented interactions when schema is empty"),
		assert_true(bool(sanitize_check.get("valid", false)), "Sanitizer should prune the bad branch and keep a safe legal branch"),
		assert_eq(kept_branches.size(), 1, "Only the safe branch should remain after pruning the empty-schema interaction"),
	])


func test_dragapult_charizard_llm_marks_and_blocks_dead_lost_vacuum() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var basin := CardInstance.create(_make_trainer_cd("Magma Basin", "Stadium"), 0)
	gs.stadium_card = basin
	var vacuum_cd := _make_trainer_cd("Lost Vacuum", "Item")
	vacuum_cd.effect_id = "8f655fea1f90164bfbccb7a95c223e17"
	vacuum_cd.description = "Put 1 card from your hand into the Lost Zone. Choose a Pokemon Tool or Stadium in play and put it into the Lost Zone."
	var vacuum := CardInstance.create(vacuum_cd, 0)
	player.hand.append(vacuum)
	var action := {"kind": "play_trainer", "card": vacuum, "targets": [], "requires_interaction": true}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [action, {"kind": "end_turn"}])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var resource_negative: Array = facts.get("resource_negative_actions", []) if facts.get("resource_negative_actions", []) is Array else []
	var found_negative := false
	for raw: Variant in resource_negative:
		if raw is Dictionary and str((raw as Dictionary).get("card", "")) == "Lost Vacuum":
			found_negative = true
	return run_checks([
		assert_true(found_negative, "Prompt facts should mark no-value Lost Vacuum as resource-negative"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "play_trainer", "card": "Lost Vacuum"}, action, gs, 0)), "Runtime queue guard should block dead Lost Vacuum"),
		assert_true(float(strategy.call("score_action_absolute", action, gs, 0)) <= -1000.0, "Dead Lost Vacuum should stay blocked through rules fallback"),
	])


func test_llm_prompt_marks_dead_gust_as_resource_negative_without_damage_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var catcher_cd := _make_trainer_cd("Pokemon Catcher", "Item")
	catcher_cd.description = "Switch 1 of your opponent's Benched Pokemon with their Active Pokemon."
	var catcher := CardInstance.create(catcher_cd, 0)
	player.hand.append(catcher)
	var low_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": true}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": catcher, "targets": [], "requires_interaction": true},
		low_attack,
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {}) if payload.get("turn_tactical_facts", {}) is Dictionary else {}
	var resource_negative: Array = facts.get("resource_negative_actions", []) if facts.get("resource_negative_actions", []) is Array else []
	var found_catcher := false
	for raw: Variant in resource_negative:
		if raw is Dictionary and str((raw as Dictionary).get("card", "")).contains("Catcher"):
			found_catcher = true
	return assert_true(found_catcher, "Prompt facts should mark gust effects as resource-negative when no non-low-value damage attack is available")


func test_dragapult_charizard_llm_preserves_missing_seed_search_cards_from_discard() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum", "Item"), 0)
	player.hand.append(nest)
	player.hand.append(vacuum)
	var nest_priority := int(strategy.call("get_discard_priority_contextual", nest, gs, 0))
	var vacuum_priority := int(strategy.call("get_discard_priority_contextual", vacuum, gs, 0))
	return run_checks([
		assert_true(nest_priority < vacuum_priority, "When Charmander is missing, Nest Ball should be protected while dead Lost Vacuum is discardable"),
	])


func test_dragapult_charizard_llm_discard_bridge_rejects_route_critical_seed_search() -> String:
	var strategy := _new_dragapult_charizard_llm_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum", "Item"), 0)
	var rod := CardInstance.create(_make_trainer_cd("Super Rod", "Item"), 0)
	player.hand.append(nest)
	player.hand.append(vacuum)
	player.hand.append(rod)
	strategy.set("_cached_turn_number", 3)
	strategy.set("_llm_queue_turn", 3)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "play_trainer:c99"}]})
	strategy.set("_llm_action_queue", [{
		"type": "play_trainer",
		"action_id": "play_trainer:c99",
		"card": "Ultra Ball",
		"selection_policy": {"discard": ["Nest Ball", "Lost Vacuum"]},
	}])
	var picked: Array = strategy.call("pick_interaction_items", [nest, vacuum, rod], {"id": "discard_cards", "max_select": 2}, {
		"game_state": gs,
		"player_index": 0,
	})
	return run_checks([
		assert_false(picked.has(nest), "Discard bridge should reject LLM attempts to discard the only seed-search card while Charmander is missing"),
		assert_true(picked.has(vacuum), "Fallback discard policy should prefer dead Lost Vacuum over route-critical Nest Ball"),
		assert_eq(picked.size(), 2, "Fallback discard policy should still satisfy a two-card discard cost"),
	])


func test_miraidon_llm_payload_includes_deck_strategy_prompt() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 0))
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "miraidon_llm", "Miraidon LLM payload should identify its deck strategy prompt"),
		assert_true(prompt_lines.size() >= 8, "Miraidon LLM prompt should provide deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "密勒顿", "Prompt should provide the Miraidon deck plan in Chinese"),
		assert_str_contains(prompt_text, "Miraidon ex", "Prompt should name the setup engine"),
		assert_str_contains(prompt_text, "Electric Generator", "Prompt should cover Generator timing"),
		assert_str_contains(prompt_text, "Iron Hands ex", "Prompt should cover the main prize-race attacker"),
		assert_str_contains(prompt_text, "Double Turbo Energy", "Prompt should cover Iron Hands acceleration policy"),
	])


func test_v17_miraidon_llm_payload_includes_mirror_prize_race_prompt() -> String:
	var strategy := _new_v17_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategy17MiraidonLLM.gd should exist"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 0))
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "v17_miraidon_llm", "v17 Miraidon payload should identify its strategy prompt"),
		assert_str_contains(prompt_text, "Mirror prize race", "v17 prompt should call out the mirror first-attack race"),
		assert_str_contains(prompt_text, "Do not attach Lightning Energy to Mew ex", "v17 prompt should warn against spending manual attach on Mew ex"),
	])


func test_miraidon_llm_registry_creates_variant_without_replacing_rules() -> String:
	var registry_script := _load_script("res://scripts/ai/DeckStrategyRegistry.gd")
	if registry_script == null:
		return "DeckStrategyRegistry.gd should load"
	var registry: RefCounted = registry_script.new()
	var rules_strategy: RefCounted = registry.call("create_strategy_by_id", "miraidon")
	var llm_strategy: RefCounted = registry.call("create_strategy_by_id", "miraidon_llm")
	return run_checks([
		assert_not_null(rules_strategy, "Registry should keep the rules Miraidon strategy"),
		assert_not_null(llm_strategy, "Registry should create miraidon_llm"),
		assert_eq(str(rules_strategy.call("get_strategy_id")), "miraidon", "Rules strategy id should remain unchanged"),
		assert_eq(str(llm_strategy.call("get_strategy_id")), "miraidon_llm", "LLM variant should report the registered strategy id"),
	])


func test_lugia_archeops_llm_payload_includes_deck_strategy_prompt() -> String:
	var strategy := _new_lugia_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should exist"
	strategy.call("set_deck_strategy_text", "custom Lugia player preference: prioritize second Minccino after Lugia V")
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_lugia_v_cd(), 0)
	player.bench.append(_make_slot(_make_minccino_cd(), 0))
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "lugia_archeops_llm", "Lugia LLM payload should identify its deck strategy prompt"),
		assert_true(prompt_lines.size() >= 8, "Lugia LLM prompt should provide deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "Lugia VSTAR", "Prompt should name the primary shell evolution"),
		assert_str_contains(prompt_text, "Summoning Star", "Prompt should cover the VSTAR conversion engine"),
		assert_str_contains(prompt_text, "Archeops", "Prompt should cover the acceleration engine"),
		assert_str_contains(prompt_text, "Special Energy", "Prompt should cover special energy resource policy"),
		assert_str_contains(prompt_text, "custom Lugia player preference", "Prompt should preserve player-authored tactical text"),
	])


func test_lugia_archeops_llm_registry_creates_variant_without_replacing_rules() -> String:
	var registry_script := _load_script("res://scripts/ai/DeckStrategyRegistry.gd")
	if registry_script == null:
		return "DeckStrategyRegistry.gd should load"
	var registry: RefCounted = registry_script.new()
	var rules_strategy: RefCounted = registry.call("create_strategy_by_id", "lugia_archeops")
	var llm_strategy: RefCounted = registry.call("create_strategy_by_id", "lugia_archeops_llm")
	return run_checks([
		assert_not_null(rules_strategy, "Registry should keep the rules Lugia Archeops strategy"),
		assert_not_null(llm_strategy, "Registry should create lugia_archeops_llm"),
		assert_eq(str(rules_strategy.call("get_strategy_id")), "lugia_archeops", "Rules strategy id should remain unchanged"),
		assert_eq(str(llm_strategy.call("get_strategy_id")), "lugia_archeops_llm", "LLM variant should report the registered strategy id"),
	])


func test_lugia_archeops_llm_preserves_rules_turn_contract_for_interaction_scoring() -> String:
	var strategy := _new_lugia_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210), 0)
	var contract: Dictionary = strategy.call("build_turn_plan", gs, 0)
	var lugia_card := CardInstance.create(_make_lugia_v_cd(), 0)
	var lugia_search_score: float = float(strategy.call("score_interaction_target", lugia_card, {"id": "search_pokemon"}, {
		"game_state": gs,
		"player_index": 0,
		"turn_contract": contract,
	}))
	var search_priorities: Dictionary = contract.get("priorities", {}) if contract.get("priorities", {}) is Dictionary else {}
	var search_names: Array = search_priorities.get("search", []) if search_priorities.get("search", []) is Array else []
	return run_checks([
		assert_eq(str(contract.get("intent", "")), "launch_shell", "Lugia wrapper should preserve the rules launch-shell turn plan"),
		assert_true(search_names.size() > 0 and str(search_names[0]) == "Lugia V", "Rules turn contract should prioritize finding Lugia V when the shell owner is missing"),
		assert_true(lugia_search_score >= 255.0, "Wrapper interaction scoring should forward the turn contract into the rules fallback"),
	])


func test_miraidon_llm_prioritizes_bench_setup_before_generator_without_target() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170), 0)
	player.deck.append(CardInstance.create(_make_miraidon_cd(), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	var generator := CardInstance.create(_make_trainer_cd("Electric Generator", "Item"), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var baton := CardInstance.create(_make_trainer_cd("Heavy Baton", "Tool"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "item_search"}
	var generator_search_score: float = float(strategy.call("score_interaction_target", generator, step, context))
	var nest_search_score: float = float(strategy.call("score_interaction_target", nest, step, context))
	var baton_search_score: float = float(strategy.call("score_interaction_target", baton, step, context))
	var generator_action_score: float = float(strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": generator,
		"targets": [],
		"requires_interaction": true,
	}, gs, 0))
	return run_checks([
		assert_true(nest_search_score > generator_search_score, "Nest Ball should outrank Electric Generator when there is no benched Lightning target"),
		assert_true(generator_action_score < 100.0, "Electric Generator should be nearly blocked before a legal bench target exists"),
		assert_true(baton_search_score < nest_search_score, "Heavy Baton should not compete with setup when Iron Hands ex is not on board"),
	])


func test_miraidon_llm_restores_generator_priority_with_benched_lightning_target() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	var generator := CardInstance.create(_make_trainer_cd("Electric Generator", "Item"), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var baton := CardInstance.create(_make_trainer_cd("Heavy Baton", "Tool"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "item_search"}
	var generator_search_score: float = float(strategy.call("score_interaction_target", generator, step, context))
	var nest_search_score: float = float(strategy.call("score_interaction_target", nest, step, context))
	var baton_search_score: float = float(strategy.call("score_interaction_target", baton, step, context))
	var generator_action_score: float = float(strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": generator,
		"targets": [],
		"requires_interaction": true,
	}, gs, 0))
	return run_checks([
		assert_true(generator_search_score > nest_search_score, "Electric Generator should regain priority after Iron Hands ex is benched"),
		assert_true(generator_action_score >= 500.0, "Electric Generator should be a top action when it has a bench target and deck energy"),
		assert_true(baton_search_score >= 300.0, "Heavy Baton should become a valid Arven tool target once Iron Hands ex is on board"),
	])


func test_miraidon_llm_ciphermaniac_empty_bench_tops_board_access_first() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Zapdos", "Basic", "L", 120), 0)
	player.bench.clear()
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var raikou := CardInstance.create(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 0)
	var iron_hands := CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 0)
	var miraidon := CardInstance.create(_make_miraidon_cd(), 0)
	var picked: Array = strategy.call("pick_interaction_items", [lightning, raikou, iron_hands, miraidon], {
		"id": "top_cards",
		"max_select": 2,
	}, {
		"game_state": gs,
		"player_index": 0,
	})
	var first_name := ""
	var second_name := ""
	if picked.size() >= 1 and picked[0] is CardInstance and (picked[0] as CardInstance).card_data != null:
		first_name = str((picked[0] as CardInstance).card_data.name)
	if picked.size() >= 2 and picked[1] is CardInstance and (picked[1] as CardInstance).card_data != null:
		second_name = str((picked[1] as CardInstance).card_data.name)
	var lightning_score: float = float(strategy.call("score_interaction_target", lightning, {"id": "top_cards"}, {"game_state": gs, "player_index": 0}))
	var miraidon_score: float = float(strategy.call("score_interaction_target", miraidon, {"id": "top_cards"}, {"game_state": gs, "player_index": 0}))
	return run_checks([
		assert_eq(first_name, "Miraidon ex", "Ciphermaniac should make the next draw Miraidon ex when the bench is empty"),
		assert_true(second_name in ["Raikou V", "Iron Hands ex"], "Second top card should be another real attacker, not Energy"),
		assert_true(miraidon_score > lightning_score, "Empty-bench Ciphermaniac scoring must rank board access above Lightning Energy"),
	])


func test_miraidon_rules_recognizes_chinese_ciphermaniac_name() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Zapdos", "Basic", "L", 120), 0)
	player.bench.clear()
	var cipher := CardInstance.create(_make_named_trainer_cd("暗码迷的解读", "Ciphermaniac's Codebreaking", "Supporter"), 0)
	var score: float = float(strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": cipher,
		"targets": [],
		"requires_interaction": true,
	}, gs, 0))
	return run_checks([
		assert_true(score >= 300.0, "Rules fallback should recognize 暗码迷的解读 instead of missing it due to the old name typo"),
	])


func test_miraidon_llm_blocks_heavy_baton_queue_match_on_non_iron_hands() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var fez_cd := _make_pokemon_cd("吉雉鸡ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	var fez_slot := _make_slot(fez_cd, 0)
	player.bench.append(fez_slot)
	var baton_cd := _make_trainer_cd("沉重接力棒", "Tool")
	baton_cd.name_en = "Heavy Baton"
	var baton := CardInstance.create(baton_cd, 0)
	var action := {"kind": "attach_tool", "card": baton, "target_slot": fez_slot, "requires_interaction": false}
	var action_id: String = str(strategy.call("_action_id_for_action", action, gs, 0))
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": action_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_tool", "action_id": action_id, "card": "Heavy Baton", "target": "Fezandipiti ex"}])
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(score < 10000.0, "Queued Heavy Baton must not override rules when the target is not Iron Hands ex"),
	])


func test_miraidon_llm_allows_heavy_baton_queue_match_on_iron_hands() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var iron_cd := _make_pokemon_cd("Iron Hands ex", "Basic", "L", 230)
	iron_cd.name_en = "Iron Hands ex"
	var iron_slot := _make_slot(iron_cd, 0)
	player.bench.append(iron_slot)
	var baton_cd := _make_trainer_cd("Heavy Baton", "Tool")
	baton_cd.name_en = "Heavy Baton"
	var baton := CardInstance.create(baton_cd, 0)
	var action := {"kind": "attach_tool", "card": baton, "target_slot": iron_slot, "requires_interaction": false}
	var action_id: String = str(strategy.call("_action_id_for_action", action, gs, 0))
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": action_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_tool", "action_id": action_id, "card": "Heavy Baton", "target": "Iron Hands ex"}])
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(score >= 90000.0, "Queued Heavy Baton should still execute when targeting Iron Hands ex"),
	])


func test_miraidon_llm_blocks_survival_tools_on_support_pokemon() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var greninja_cd := _make_pokemon_cd("光辉甲贺忍蛙", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	var greninja_slot := _make_slot(greninja_cd, 0)
	player.bench.append(greninja_slot)
	var charm := CardInstance.create(_make_named_trainer_cd("勇气护符", "Bravery Charm", "Tool"), 0)
	var charm_action := {"kind": "attach_tool", "card": charm, "target_slot": greninja_slot, "requires_interaction": false}
	var charm_id: String = str(strategy.call("_action_id_for_action", charm_action, gs, 0))
	strategy.set("_llm_queue_turn", 4)
	strategy.set("_llm_decision_tree", {"actions": [{"id": charm_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_tool", "action_id": charm_id, "card": "Bravery Charm", "target": "Radiant Greninja"}])
	var charm_score: float = float(strategy.call("score_action_absolute", charm_action, gs, 0))
	var stone := CardInstance.create(_make_named_trainer_cd("森林封印石", "Forest Seal Stone", "Tool"), 0)
	var stone_action := {"kind": "attach_tool", "card": stone, "target_slot": greninja_slot, "requires_interaction": false}
	var stone_id: String = str(strategy.call("_action_id_for_action", stone_action, gs, 0))
	strategy.set("_llm_queue_turn", 4)
	strategy.set("_llm_decision_tree", {"actions": [{"id": stone_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_tool", "action_id": stone_id, "card": "Forest Seal Stone", "target": "Radiant Greninja"}])
	var stone_score: float = float(strategy.call("score_action_absolute", stone_action, gs, 0))
	return run_checks([
		assert_true(charm_score < 10000.0, "Bravery Charm queue match should be blocked on support Pokemon"),
		assert_true(stone_score < 10000.0, "Forest Seal Stone queue match should be blocked on non-V support Pokemon"),
	])


func test_miraidon_llm_allows_forest_seal_stone_on_raikou_v() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var raikou_cd := _make_pokemon_cd("雷公V", "Basic", "L", 200)
	raikou_cd.name_en = "Raikou V"
	var raikou_slot := _make_slot(raikou_cd, 0)
	player.bench.append(raikou_slot)
	var stone := CardInstance.create(_make_named_trainer_cd("森林封印石", "Forest Seal Stone", "Tool"), 0)
	var stone_action := {"kind": "attach_tool", "card": stone, "target_slot": raikou_slot, "requires_interaction": false}
	var stone_id: String = str(strategy.call("_action_id_for_action", stone_action, gs, 0))
	strategy.set("_llm_queue_turn", 4)
	strategy.set("_llm_decision_tree", {"actions": [{"id": stone_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_tool", "action_id": stone_id, "card": "Forest Seal Stone", "target": "Raikou V"}])
	var score: float = float(strategy.call("score_action_absolute", stone_action, gs, 0))
	return run_checks([
		assert_true(score >= 90000.0, "Forest Seal Stone should remain allowed on Raikou V"),
	])


func test_miraidon_llm_blocks_lightning_energy_queue_match_on_mew_ex() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var mew_cd := _make_pokemon_cd("Mew ex", "Basic", "P", 180)
	var mew_slot := _make_slot(mew_cd, 0)
	player.bench.append(mew_slot)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var action := {"kind": "attach_energy", "card": lightning, "target_slot": mew_slot, "requires_interaction": false}
	var generator_target_score: float = float(strategy.call("score_interaction_target", mew_slot, {"id": "attach_target"}, {
		"game_state": gs,
		"player_index": 0,
	}))
	var action_id: String = str(strategy.call("_action_id_for_action", action, gs, 0))
	strategy.set("_llm_queue_turn", 5)
	strategy.set("_llm_decision_tree", {"actions": [{"id": action_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_energy", "action_id": action_id, "card": "Basic Lightning Energy", "target": "Mew ex"}])
	var llm_score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	var rules_strategy := _new_miraidon_llm_strategy()
	var rules_score: float = float(rules_strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, action, gs, 0)), "Miraidon LLM should block Lightning Energy on Mew ex"),
		assert_true(generator_target_score < 0.0, "Electric Generator target scoring should reject Mew ex instead of treating it as a low-priority target"),
		assert_true(llm_score < 10000.0, "Queued Lightning Energy to Mew ex must not receive forced LLM execution score"),
		assert_true(rules_score < 0.0, "Rules fallback should also penalize Lightning Energy on Mew ex"),
	])


func test_miraidon_llm_blocks_double_turbo_queue_match_on_mew_ex() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var mew_slot := _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180), 0)
	player.bench.append(mew_slot)
	var dte_cd := _make_energy_cd("Double Turbo Energy", "")
	dte_cd.card_type = "Special Energy"
	var dte := CardInstance.create(dte_cd, 0)
	var action := {"kind": "attach_energy", "card": dte, "target_slot": mew_slot, "requires_interaction": false}
	var action_id: String = str(strategy.call("_action_id_for_action", action, gs, 0))
	strategy.set("_llm_queue_turn", 5)
	strategy.set("_llm_decision_tree", {"actions": [{"id": action_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_energy", "action_id": action_id, "card": "Double Turbo Energy", "target": "Mew ex"}])
	var llm_score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	var rules_strategy := _new_miraidon_llm_strategy()
	var rules_score: float = float(rules_strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, action, gs, 0)), "Miraidon LLM should block Double Turbo Energy on Mew ex"),
		assert_true(llm_score < 10000.0, "Queued Double Turbo Energy to Mew ex must not receive forced LLM execution score"),
		assert_true(rules_score < 0.0, "Rules fallback should also penalize Double Turbo Energy on Mew ex"),
	])


func test_miraidon_llm_allows_double_turbo_queue_match_on_iron_hands() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	var iron_slot := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 0)
	player.bench.append(iron_slot)
	var dte_cd := _make_energy_cd("Double Turbo Energy", "")
	dte_cd.card_type = "Special Energy"
	var dte := CardInstance.create(dte_cd, 0)
	var action := {"kind": "attach_energy", "card": dte, "target_slot": iron_slot, "requires_interaction": false}
	var action_id: String = str(strategy.call("_action_id_for_action", action, gs, 0))
	strategy.set("_llm_queue_turn", 5)
	strategy.set("_llm_decision_tree", {"actions": [{"id": action_id}]})
	strategy.set("_llm_action_queue", [{"type": "attach_energy", "action_id": action_id, "card": "Double Turbo Energy", "target": "Iron Hands ex"}])
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, action, gs, 0)), "Miraidon LLM should keep Double Turbo Energy legal on Iron Hands ex"),
		assert_true(score >= 90000.0, "Queued Double Turbo Energy should still execute when targeting Iron Hands ex"),
	])


func test_miraidon_llm_blocks_retreat_to_unready_raichu_or_support() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var raikou_cd := _make_pokemon_cd("Raikou V", "Basic", "L", 200)
	raikou_cd.name_en = "Raikou V"
	raikou_cd.mechanic = "V"
	raikou_cd.attacks = [{"name": "Lightning Rondo", "cost": "LC", "damage": "20+"}]
	player.active_pokemon = _make_slot(raikou_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var raichu_cd := _make_pokemon_cd("Raichu V", "Basic", "L", 200)
	raichu_cd.name_en = "Raichu V"
	raichu_cd.mechanic = "V"
	raichu_cd.attacks = [
		{"name": "Fast Charge", "cost": "L", "damage": ""},
		{"name": "Dynamic Spark", "cost": "LL", "damage": "60x"},
	]
	var raichu_slot := _make_slot(raichu_cd, 0)
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	fez_cd.mechanic = "ex"
	var fez_slot := _make_slot(fez_cd, 0)
	player.bench.append(raichu_slot)
	player.bench.append(fez_slot)
	var raichu_retreat := {"kind": "retreat", "bench_target": raichu_slot, "requires_interaction": false}
	var support_retreat := {"kind": "retreat", "bench_target": fez_slot, "requires_interaction": false}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "retreat"}, raichu_retreat, gs, 0)), "Miraidon LLM should block retreating to unready Raichu V"),
		assert_true(float(strategy.call("score_action_absolute", raichu_retreat, gs, 0)) <= -1000.0, "Unready Raichu retreat should stay blocked outside exact queue scoring"),
		assert_true(float(strategy.call("score_action", raichu_retreat, {"game_state": gs, "player_index": 0})) <= -1000.0, "Unready Raichu retreat should stay blocked through score_action fallback"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "retreat"}, support_retreat, gs, 0)), "Miraidon LLM should block retreating into support padding without an attack closure"),
		assert_true(float(strategy.call("score_action_absolute", support_retreat, gs, 0)) <= -1000.0, "Support retreat should stay blocked outside exact queue scoring"),
	])


func test_miraidon_llm_allows_retreat_to_ready_real_attackers() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180), 0)
	var iron_cd := _make_pokemon_cd("Iron Hands ex", "Basic", "L", 230)
	iron_cd.name_en = "Iron Hands ex"
	iron_cd.mechanic = "ex"
	iron_cd.attacks = [{"name": "Arm Press", "cost": "LLC", "damage": "160"}]
	var iron_slot := _make_slot(iron_cd, 0)
	iron_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	iron_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	iron_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0))
	var raikou_cd := _make_pokemon_cd("Raikou V", "Basic", "L", 200)
	raikou_cd.name_en = "Raikou V"
	raikou_cd.mechanic = "V"
	raikou_cd.attacks = [{"name": "Lightning Rondo", "cost": "LC", "damage": "20+"}]
	var raikou_slot := _make_slot(raikou_cd, 0)
	raikou_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	raikou_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0))
	var miraidon := _make_slot(_make_miraidon_cd(), 0)
	miraidon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	miraidon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	miraidon.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0))
	var raichu_cd := _make_pokemon_cd("Raichu V", "Basic", "L", 200)
	raichu_cd.name_en = "Raichu V"
	raichu_cd.mechanic = "V"
	raichu_cd.attacks = [{"name": "Dynamic Spark", "cost": "LL", "damage": "60x"}]
	var ready_raichu := _make_slot(raichu_cd, 0)
	ready_raichu.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	ready_raichu.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.bench.append(iron_slot)
	player.bench.append(raikou_slot)
	player.bench.append(miraidon)
	player.bench.append(ready_raichu)
	var iron_retreat := {"kind": "retreat", "bench_target": iron_slot, "requires_interaction": false}
	var raikou_retreat := {"kind": "retreat", "bench_target": raikou_slot, "requires_interaction": false}
	var miraidon_retreat := {"kind": "retreat", "bench_target": miraidon, "requires_interaction": false}
	var raichu_retreat := {"kind": "retreat", "bench_target": ready_raichu, "requires_interaction": false}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "retreat"}, iron_retreat, gs, 0)), "Ready Iron Hands ex should remain a legal retreat target"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "retreat"}, raikou_retreat, gs, 0)), "Ready Raikou V should remain a legal retreat target"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "retreat"}, miraidon_retreat, gs, 0)), "Ready Miraidon ex should remain a legal retreat target"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "retreat"}, raichu_retreat, gs, 0)), "Raichu V retreat still needs a separate prize-math finisher hook before it is allowed"),
	])


func test_miraidon_llm_retreat_queue_ref_with_string_target_does_not_crash() -> String:
	var strategy := _new_v17_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategy17MiraidonLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180), 0)
	var raikou_cd := _make_pokemon_cd("Raikou V", "Basic", "L", 200)
	raikou_cd.name_en = "Raikou V"
	raikou_cd.mechanic = "V"
	raikou_cd.attacks = [{"name": "Lightning Rondo", "cost": "LC", "damage": "20+"}]
	var raikou_slot := _make_slot(raikou_cd, 0)
	raikou_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	raikou_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0))
	player.bench.append(raikou_slot)
	var queued_ref := {
		"type": "retreat",
		"action_id": "retreat:bench_0:none",
		"bench_target": "Raikou V",
	}
	var runtime_retreat := {"kind": "retreat", "bench_target": raikou_slot, "requires_interaction": false}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", queued_ref, queued_ref, gs, 0)), "String-only queued retreat refs should not enter PokemonSlot-only retreat guard"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", queued_ref, runtime_retreat, gs, 0)), "Ready Raikou runtime retreat should still be allowed"),
	])


func test_miraidon_llm_blocks_raichu_fast_charge_when_productive_setup_visible() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var raichu_cd := _make_pokemon_cd("Raichu V", "Basic", "L", 200)
	raichu_cd.name_en = "Raichu V"
	raichu_cd.attacks = [
		{"name": "Fast Charge", "cost": "", "damage": ""},
		{"name": "Dynamic Spark", "cost": "L", "damage": "60x"},
	]
	player.active_pokemon = _make_slot(raichu_cd, 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Electric Generator", "Item"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	strategy.set("_llm_queue_turn", 8)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "attack:0:Fast Charge"}]})
	strategy.set("_llm_action_queue", [{"type": "attack", "attack_index": 0, "attack_name": "Fast Charge"}])
	var fast_charge_action := {"kind": "attack", "attack_index": 0, "requires_interaction": false}
	var score: float = float(strategy.call("score_action_absolute", fast_charge_action, gs, 0))
	return run_checks([
		assert_true(score <= -1000.0, "Raichu V Fast Charge should not receive forced LLM execution when the hand has productive setup pieces"),
	])


func test_miraidon_llm_end_turn_queue_can_execute_generator_with_bench_target() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_miraidon_cd(), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230), 0))
	var generator := CardInstance.create(_make_trainer_cd("Electric Generator", "Item"), 0)
	var generator_action := {"kind": "play_trainer", "card": generator, "targets": [], "requires_interaction": true}
	strategy.set("_llm_queue_turn", 9)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn", "id": "end_turn"}])
	var score: float = float(strategy.call("score_action_absolute", generator_action, gs, 0))
	return run_checks([
		assert_true(score >= 90000.0, "A weak end_turn LLM queue should allow Electric Generator when a valid bench Lightning attacker exists"),
	])


func test_miraidon_llm_repairs_productive_engine_before_terminal_attack() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(10)
	strategy.set("_llm_action_catalog", {
		"play_trainer:c11": {
			"id": "play_trainer:c11",
			"action_id": "play_trainer:c11",
			"type": "play_trainer",
			"card": "Electric Generator",
			"card_rules": {"name": "Electric Generator", "name_en": "Electric Generator"},
		},
		"attack:1:Photon Blaster": {
			"id": "attack:1:Photon Blaster",
			"action_id": "attack:1:Photon Blaster",
			"type": "attack",
			"attack_index": 1,
			"attack_name": "Photon Blaster",
		},
	})
	var repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", {
		"actions": [{
			"id": "attack:1:Photon Blaster",
			"action_id": "attack:1:Photon Blaster",
			"type": "attack",
			"attack_index": 1,
			"attack_name": "Photon Blaster",
		}],
	}, gs, 0)
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var first_id := str((actions[0] as Dictionary).get("id", "")) if actions.size() > 0 and actions[0] is Dictionary else ""
	var last_id := str((actions[actions.size() - 1] as Dictionary).get("id", "")) if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else ""
	return run_checks([
		assert_true(int(repair.get("added_count", 0)) >= 1, "Miraidon repair should add productive engines before terminal attacks"),
		assert_eq(first_id, "play_trainer:c11", "Electric Generator should be inserted before attacking when it is visible and non-conflicting"),
		assert_eq(last_id, "attack:1:Photon Blaster", "The terminal attack should remain at the end of the repaired route"),
	])


func test_miraidon_llm_repairs_generator_after_miraidon_bench_branch() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(10)
	var bad_tree := {
		"actions": [{
			"id": "play_trainer:c11",
			"action_id": "play_trainer:c11",
			"type": "play_trainer",
			"card": "Electric Generator",
		}],
		"branches": [{
			"actions": [{
				"id": "play_basic_to_bench:c13",
				"action_id": "play_basic_to_bench:c13",
				"type": "play_basic_to_bench",
				"card": "Miraidon ex",
				"interactions": {"search_targets": ["Raikou V", "Iron Hands ex"]},
				"selection_policy": {"search_targets": ["Raikou V", "Iron Hands ex"]},
			}],
			"then": {
				"actions": [{
					"id": "attach_energy:c28:active",
					"action_id": "attach_energy:c28:active",
					"type": "attach_energy",
					"card": "Lightning Energy",
				}],
			},
		}],
	}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", bad_tree, gs, 0)
	var root_actions: Array = repaired.get("actions", [])
	var branches: Array = repaired.get("branches", [])
	var branch: Dictionary = branches[0] if not branches.is_empty() and branches[0] is Dictionary else {}
	var branch_actions: Array = branch.get("actions", [])
	var first: Dictionary = branch_actions[0] if branch_actions.size() > 0 and branch_actions[0] is Dictionary else {}
	var second: Dictionary = branch_actions[1] if branch_actions.size() > 1 and branch_actions[1] is Dictionary else {}
	return run_checks([
		assert_true(root_actions.is_empty(), "Miraidon repair should move Electric Generator out of the parent pre-setup queue"),
		assert_eq(str(first.get("id", "")), "play_basic_to_bench:c13", "Miraidon ex must be benched before Generator is played"),
		assert_eq(str(second.get("id", "")), "play_trainer:c11", "Electric Generator should execute after the Miraidon bench setup"),
		assert_false(first.has("interactions"), "Benching Miraidon ex must not carry fake Tandem Unit search interactions"),
		assert_false(first.has("selection_policy"), "Benching Miraidon ex must not carry fake Tandem Unit selection policy"),
	])


func test_miraidon_llm_repairs_generator_after_opening_setup_actions() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(2)
	var bad_tree := {
		"actions": [
			{
				"id": "play_trainer:c9",
				"action_id": "play_trainer:c9",
				"type": "play_trainer",
				"card": "Electric Generator",
			},
			{
				"id": "play_trainer:c3",
				"action_id": "play_trainer:c3",
				"type": "play_trainer",
				"card": "Nest Ball",
				"selection_policy": {"search_targets": ["Iron Hands ex"]},
			},
			{
				"id": "use_ability:bench_0:0",
				"action_id": "use_ability:bench_0:0",
				"type": "use_ability",
				"pokemon": "Miraidon ex",
				"ability": "Tandem Unit",
			},
			{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
		],
	}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", bad_tree, gs, 0)
	var actions: Array = repaired.get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_eq(ids[0], "play_trainer:c3", "Nest Ball should happen before Electric Generator so Generator has better bench targets"),
		assert_eq(ids[1], "use_ability:bench_0:0", "Tandem Unit should happen before Electric Generator in the opening setup chain"),
		assert_eq(ids[2], "play_trainer:c9", "Electric Generator should move after direct bench setup actions"),
		assert_eq(ids[ids.size() - 1], "end_turn", "End turn should remain terminal after repair"),
	])


func test_miraidon_llm_repairs_missing_tandem_before_end_turn() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var miraidon_cd := _make_miraidon_cd()
	miraidon_cd.abilities = [{"name": "Tandem Unit", "text": "Search your deck for up to 2 Basic Lightning Pokemon and put them onto your Bench."}]
	player.active_pokemon = _make_slot(miraidon_cd, 0)
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	player.hand.append(lightning)
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_pokemon_cd("Deck Filler %d" % i), 0))
	var attach_id := "attach_energy:c%d:active" % int(lightning.instance_id)
	strategy.set("_llm_action_catalog", {
		"use_ability:active:0": {
			"id": "use_ability:active:0",
			"action_id": "use_ability:active:0",
			"type": "use_ability",
			"pokemon": "Miraidon ex",
			"ability": "Tandem Unit",
		},
		attach_id: {
			"id": attach_id,
			"action_id": attach_id,
			"type": "attach_energy",
			"card": "Lightning Energy",
			"position": "active",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	})
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {"actions": [{"id": attach_id}, {"id": "end_turn"}]})
	var repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", materialized, gs, 0)
	var actions: Array = (repair.get("tree", {}) as Dictionary).get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", (raw_action as Dictionary).get("id", ""))))
	return run_checks([
		assert_true(strategy.get("_llm_action_catalog").has("use_ability:active:0"), "Test catalog should expose the legal Tandem Unit action"),
		assert_true(ids.has("use_ability:active:0"), "Miraidon LLM repair should insert missed Tandem Unit before ending"),
		assert_eq(ids[ids.size() - 1], "end_turn", "End turn should remain terminal after inserting Tandem Unit"),
	])


func test_miraidon_llm_replans_after_benching_miraidon_ex() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180), 0)
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "attach_energy:c28:active"}]})
	strategy.set("_llm_action_queue", [{"type": "attach_energy", "action_id": "attach_energy:c28:active"}])
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.bench.append(_make_slot(_make_miraidon_cd(), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "play_basic_to_bench",
		"pending_choice_after": "",
	})
	var replan_context_by_turn: Dictionary = strategy.get("_llm_replan_context_by_turn")
	var replan_context: Dictionary = replan_context_by_turn.get(6, {})
	var trigger: Dictionary = replan_context.get("trigger", {})
	return run_checks([
		assert_eq(int(before.get("miraidon_count", -1)), 0, "Before snapshot should see no Miraidon ex on board"),
		assert_eq(int(after.get("miraidon_count", -1)), 1, "After snapshot should see Miraidon ex on board"),
		assert_eq(int(strategy.call("get_llm_replan_count")), 1, "Benching Miraidon ex should trigger a same-turn replan for Tandem Unit"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Miraidon replan should clear stale follow-up queue"),
		assert_eq(str(trigger.get("reason", "")), "miraidon_benched_tandem_unit_now_legal", "Replan context should record the Miraidon-specific trigger"),
	])


func test_raging_bolt_llm_replans_after_benching_main_attacker_before_manual_attach() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "attach_energy:c28:active"}, {"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [
		{"type": "attach_energy", "action_id": "attach_energy:c28:active", "capability": "manual_attach"},
		{"type": "end_turn", "action_id": "end_turn", "capability": "end_turn"},
	])
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	strategy.call("observe_llm_runtime_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "play_basic_to_bench",
		"pending_choice_after": "",
	})
	var replan_context_by_turn: Dictionary = strategy.get("_llm_replan_context_by_turn")
	var replan_context: Dictionary = replan_context_by_turn.get(6, {})
	var trigger: Dictionary = replan_context.get("trigger", {})
	return run_checks([
		assert_eq(int(before.get("raging_bolt_count", -1)), 0, "Before snapshot should see no Raging Bolt on board"),
		assert_eq(int(after.get("raging_bolt_count", -1)), 1, "After snapshot should see the newly benched Raging Bolt"),
		assert_false(bool(after.get("active_is_raging_bolt", true)), "The active support Pokemon should force attach-target replanning"),
		assert_eq(int(strategy.call("get_llm_replan_count")), 1, "Benching Raging Bolt behind a support active should clear stale manual-attach routes"),
		assert_false(strategy.call("has_llm_plan_for_turn", 6), "Raging Bolt replan should clear the stale attach-to-active queue"),
		assert_eq(str(trigger.get("reason", "")), "raging_bolt_benched_retarget_attack_energy", "Replan context should record the Raging Bolt retarget trigger"),
	])


func test_raging_bolt_llm_blocks_attack_energy_attach_to_support_active_when_bolt_benched() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	player.bench.append(_make_slot(_make_raging_bolt_cd(), 0))
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	player.hand.append(fighting)
	var attach_action := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	strategy.set("_cached_turn_number", 7)
	strategy.set("_llm_queue_turn", 7)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "attach_energy:c%d:active" % int(fighting.instance_id)}]})
	strategy.set("_llm_action_queue", [{"type": "attach_energy", "action_id": "attach_energy:c%d:active" % int(fighting.instance_id)}])
	var score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, attach_action, gs, 0)), "Queued Fighting attach to support active should not be treated as a valid Raging Bolt plan step"),
		assert_true(score <= -1000.0, "Rules fallback should also reject spending Fighting on support active while Raging Bolt is benched (score=%f)" % score),
	])


func test_raging_bolt_llm_blocks_attack_energy_attach_to_support_active_when_bolt_in_hand() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	player.hand.append(fighting)
	player.hand.append(CardInstance.create(_make_raging_bolt_cd(), 0))
	var attach_action := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	var score: float = float(strategy.call("score_action_absolute", attach_action, gs, 0))
	return assert_true(score <= -1000.0,
		"Core Fighting/Lightning Energy should be preserved for Raging Bolt when the main attacker is still in hand (score=%f)" % score)


func test_raging_bolt_llm_blocks_grass_attach_to_bolt_missing_core_cost() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass)
	var grass_attach := {"kind": "attach_energy", "card": grass, "target_slot": player.active_pokemon}
	var score_missing_cost: float = float(strategy.call("score_action_absolute", grass_attach, gs, 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var score_after_core_ready: float = float(strategy.call("score_action_absolute", grass_attach, gs, 0))
	return run_checks([
		assert_true(score_missing_cost <= -1000.0, "Grass attach to Raging Bolt should be blocked while Lightning/Fighting attack cost is still missing (score=%f)" % score_missing_cost),
		assert_true(score_after_core_ready > -1000.0, "Grass attach may be considered only after Raging Bolt already has Lightning/Fighting core cost (score=%f)" % score_after_core_ready),
	])


func test_llm_queue_exact_action_id_rejects_stale_position_target_after_pivot() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(ogerpon_cd, 0))
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var q := {
		"type": "attach_energy",
		"action_id": "attach_energy:c%d:bench_0" % int(fighting.instance_id),
		"card": "Fighting Energy",
		"position": "bench_0",
		"target": "Raging Bolt ex",
	}
	var stale_action := {"kind": "attach_energy", "card": fighting, "target_slot": player.bench[0]}
	return assert_false(bool(strategy.call("_queue_item_matches", q, stale_action, gs, 0)),
		"Exact action ids must still reject stale position plans when pivoting changed bench_0 from Raging Bolt to Ogerpon")


func test_raging_bolt_llm_queue_retargets_same_energy_attach_to_active_bolt() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var q := {
		"type": "attach_energy",
		"action_id": "attach_energy:c%d:bench_0" % int(fighting.instance_id),
		"card": "Fighting Energy",
		"position": "bench_0",
		"target": "Raging Bolt ex",
	}
	var runtime_action := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	return assert_true(bool(strategy.call("_queue_item_matches", q, runtime_action, gs, 0)),
		"Raging Bolt LLM should treat same-card L/F attach retargeted to active Raging Bolt as queue-consumable")


func test_llm_blocks_end_turn_skipping_position_sensitive_followup_after_pivot() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	var ogerpon := _make_slot(ogerpon_cd, 0)
	var bolt := _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon = ogerpon
	player.bench.clear()
	player.bench.append(bolt)
	strategy.set("_cached_turn_number", 8)
	strategy.set("_llm_queue_turn", 8)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "attach_energy:c44:bench_0"}, {"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [
		{"type": "attach_energy", "action_id": "attach_energy:c44:bench_0", "position": "bench_0", "target": "Raging Bolt ex"},
		{"type": "end_turn", "action_id": "end_turn"},
	])
	strategy.set("_llm_action_catalog", {
		"attach_energy:c44:bench_0": {"type": "attach_energy", "action_id": "attach_energy:c44:bench_0", "position": "bench_0", "target": "Raging Bolt ex"},
		"end_turn": {"type": "end_turn", "action_id": "end_turn"},
	})
	var before: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	player.active_pokemon = bolt
	player.bench[0] = ogerpon
	var after: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	var active_queue: Array[Dictionary] = strategy.call("_select_current_action_queue", gs, 0)
	var prefix_sensitive := bool(strategy.call("_queue_prefix_has_position_sensitive_actions", active_queue, 1))
	var direct_queue_score := float(strategy.call("_score_from_queue", {"kind": "end_turn"}, active_queue, gs, 0))
	var end_turn_score := float(strategy.call("score_action_absolute", {"kind": "end_turn"}, gs, 0))
	return run_checks([
		assert_eq(str(before.get("active_name", "")), "Teal Mask Ogerpon ex", "Before snapshot should capture active identity"),
		assert_eq(str(after.get("active_name", "")), "Raging Bolt ex", "After snapshot should capture switched-in attacker"),
		assert_true(prefix_sensitive, "Queued attach before end_turn should be position-sensitive: %s" % JSON.stringify(active_queue)),
		assert_true(direct_queue_score <= -1000.0, "Direct queue scoring should block terminal skip over position-sensitive prefix (score=%f queue=%s)" % [direct_queue_score, JSON.stringify(active_queue)]),
		assert_true(end_turn_score <= -1000.0, "End turn must not receive queue ownership by skipping a stale position-sensitive attach after pivot (score=%f)" % end_turn_score),
	])


func test_llm_queue_blocks_nonterminal_skip_over_required_prefix() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var stretcher := CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0)
	var queue: Array[Dictionary] = [
		{"id": "attach_energy:c43:active", "action_id": "attach_energy:c43:active", "type": "attach_energy", "card": "Fighting Energy", "target": "Raging Bolt ex"},
		{"type": "play_trainer", "card": "Night Stretcher"},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var stretcher_action := {"kind": "play_trainer", "card": stretcher, "targets": [], "requires_interaction": true}
	var score := float(strategy.call("_score_from_queue", stretcher_action, queue, gs, 0))
	var matched_index := int(strategy.call("_queue_index_for_action", stretcher_action, queue, gs, 0))
	return run_checks([
		assert_true(score <= -1000.0, "Runtime queue scoring must not skip a required manual attach to execute a later trainer (score=%f)" % score),
		assert_eq(matched_index, -1, "Runtime queue consumption must not mark skipped required prefix actions as consumed"),
	])


func test_llm_queue_allows_noncritical_prefix_skip_to_reach_later_action() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var queue: Array[Dictionary] = [
		{"type": "play_trainer", "card": "Switch Cart"},
		{"type": "play_trainer", "card": "Nest Ball", "capability": "bench_search"},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var nest_action := {"kind": "play_trainer", "card": nest_ball, "targets": [], "requires_interaction": true}
	var score := float(strategy.call("_score_from_queue", nest_action, queue, gs, 0))
	var matched_index := int(strategy.call("_queue_index_for_action", nest_action, queue, gs, 0))
	return run_checks([
		assert_true(score > 0.0, "Runtime queue scoring should allow skipping a non-critical setup prefix to continue the route (score=%f)" % score),
		assert_eq(matched_index, 1, "Runtime queue consumption may consume a skipped non-critical prefix once a later setup action executes"),
	])


func test_llm_queue_blocks_unmatched_action_when_attack_head_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var attack_queue: Array[Dictionary] = [{
		"id": "attack:1:Thundering Bolt",
		"action_id": "attack:1:Thundering Bolt",
		"type": "attack",
		"attack_index": 1,
		"attack_name": "Thundering Bolt",
	}]
	var ogerpon := CardInstance.create(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	var unrelated_setup := {"kind": "play_basic_to_bench", "card": ogerpon}
	var blocked := bool(strategy.call("_active_queue_blocks_unmatched_action", attack_queue, unrelated_setup, gs, 0))
	return assert_true(blocked,
		"Runtime ownership must block unrelated setup when the selected queue head is a ready attack")


func test_miraidon_opening_keeps_raichu_v_out_of_active_when_pivot_exists() -> String:
	var strategy := _new_miraidon_llm_strategy()
	if strategy == null:
		return "DeckStrategyMiraidonLLM.gd should exist"
	var player := PlayerState.new()
	player.hand.append(CardInstance.create(_make_pokemon_cd("雷丘V", "Basic", "L", 200), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("怒鹦哥ex", "Basic", "C", 160), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230), 0))
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 1, "Opening setup should prefer Squawkabilly ex over early Raichu V as active"),
	])


func test_raging_bolt_action_id_hints_are_compact_and_complete() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var attack_action := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [attack_action, {"kind": "end_turn"}])
	var hints: PackedStringArray = payload.get("deck_strategy_hints", PackedStringArray())
	var hint_text := "\n".join(hints)
	var instructions_text := "\n".join(payload.get("instructions", PackedStringArray()))
	var supported_facts: Array = payload.get("supported_facts", [])
	return run_checks([
		assert_true(hints.size() <= 18, "Action-id prompt should keep Raging Bolt hints compact while preserving player-edited strategy"),
		assert_str_contains(hint_text, "决策树形状", "Compact hints should include the route template, not only deck flavor"),
		assert_str_contains(hint_text, "勇气护符", "Compact hints should include tactical tool-before-attack guidance"),
		assert_str_contains(hint_text, "card_rules、interaction_hints", "Compact hints should delegate per-card execution to card rules and interaction hints"),
		assert_str_contains(hint_text, "下回合准备", "Compact hints should include resource budget guidance"),
		assert_str_contains(instructions_text, "candidate_routes", "Action-id prompt should make route ids the primary compact planning surface"),
		assert_str_contains(instructions_text, "player-authored play requirements", "Action-id prompt should treat deck hints as player requirements, not flavor text"),
		assert_str_contains(instructions_text, "player-editable tactical preference layer", "Action-id prompt should let player strategy reorder legal candidate routes"),
		assert_str_contains(instructions_text, "base_priority is an engine default, not a hard order", "Candidate route priority should be advisory rather than absolute"),
		assert_str_contains(instructions_text, "selection_policy", "Action-id prompt should prefer compact selection policy over verbose low-level interactions"),
		assert_true(supported_facts.has("active_attack_ready"), "Payload should expose supported decision-tree facts without shipping verbose contract examples"),
	])


func test_action_id_prompt_preserves_player_strategy_lines_without_keyword_filter() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var strategy_lines := PackedStringArray()
	for i: int in 18:
		strategy_lines.append("custom player strategy line %02d" % i)
	builder.call("set_deck_strategy_prompt", "custom_strategy", strategy_lines)
	var gs := _make_game_state(6)
	gs.players[0].active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, [{"kind": "end_turn"}])
	var hints: PackedStringArray = payload.get("deck_strategy_hints", PackedStringArray())
	var hint_text := "\n".join(hints)
	return run_checks([
		assert_eq(hints.size(), 18, "Action-id prompt should preserve the player-requirement preface plus compact strategy lines"),
		assert_str_contains(hint_text, "deck_strategy_hints 来自玩家", "Compact hints should explicitly frame deck strategy as player-authored requirements"),
		assert_true(hints.has("custom player strategy line 00"), "Compact hints should include the first player line"),
		assert_true(hints.has("custom player strategy line 16"), "Compact hints should not require special keywords to preserve player strategy"),
		assert_false(hints.has("custom player strategy line 17"), "Compact hints should still cap player text to protect prompt size"),
	])


func test_compact_candidate_routes_expose_advisory_base_priority() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var routes: Array[Dictionary] = [{
		"id": "engine_before_end",
		"route_action_id": "route:engine_before_end",
		"type": "candidate_route",
		"priority": 700,
		"goal": "engine_setup",
		"description": "Use engine before ending.",
		"actions": [{"id": "use_ability:bench_0:0"}, {"id": "end_turn"}],
	}]
	var compact: Array = builder.call("_compact_candidate_routes", routes)
	var route: Dictionary = compact[0] if compact.size() > 0 and compact[0] is Dictionary else {}
	return run_checks([
		assert_eq(int(route.get("base_priority", 0)), 700, "Compact route should expose engine score as advisory base_priority"),
		assert_false(route.has("priority"), "Compact route should not expose priority as a hard-looking LLM ordering signal"),
		assert_true(bool(route.get("strategy_adjustable", false)), "Compact route should mark route order as adjustable by player strategy"),
	])


func test_raging_bolt_fast_setup_choice_payload_and_consumption() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(0)
	var player := gs.players[0]
	player.hand.clear()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 0))
	player.hand.append(CardInstance.create(_make_raging_bolt_cd(), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0))
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var fast_payload: Dictionary = strategy.get("_prompt_builder").call(
		"build_fast_choice_payload",
		gs,
		0,
		"setup_active",
		strategy.call("_fast_choice_candidates", "setup_active", gs, 0)
	)
	var context: Dictionary = fast_payload.get("fast_choice_context", {})
	var candidates: Array = context.get("candidates", [])
	strategy.set("_fast_choice_cache", {
		"setup_active:0:0": {"selected_index": 1, "bench_indices": [2, 0], "reasoning": "lead attacker"},
	})
	var choice: Dictionary = strategy.call("consume_fast_opening_setup_choice", player, gs, 0)
	return run_checks([
		assert_true(payload.has("deck_strategy_prompt"), "Regular payload should still include deck prompt"),
		assert_eq(str(fast_payload.get("system_prompt_version", "")), "llm_fast_choice_v1", "Fast setup should use fast-choice schema"),
		assert_eq(str(context.get("prompt_kind", "")), "setup_active", "Fast setup prompt kind should be explicit"),
		assert_eq(candidates.size(), 3, "Fast setup should expose only candidate Basic Pokemon"),
		assert_eq(int(choice.get("active_hand_index", -1)), 1, "Fast setup selected_index should become active_hand_index"),
		assert_eq((choice.get("bench_hand_indices", []) as Array).size(), 2, "Fast setup bench_indices should be preserved after validation"),
	])


func test_raging_bolt_fast_send_out_choice_consumes_bench_index() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.bench.clear()
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	var bolt := _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.append(ogerpon)
	player.bench.append(bolt)
	var candidates: Array = strategy.call("_fast_choice_candidates", "send_out", gs, 0)
	strategy.set("_fast_choice_cache", {
		"send_out:0:5": {"selected_index": 1, "bench_indices": [], "reasoning": "ready attacker"},
	})
	var picked: PokemonSlot = strategy.call("consume_fast_send_out_choice", player.bench, gs, 0)
	return run_checks([
		assert_eq(candidates.size(), 2, "Fast send_out should expose bench candidates"),
		assert_eq(str((candidates[1] as Dictionary).get("role_hint", "")), "main_attacker", "Fast send_out should mark Raging Bolt as main attacker"),
		assert_true(picked == bolt, "Fast send_out selected_index should pick the requested bench slot"),
	])


func test_fast_choice_failure_suppresses_same_prompt_retry() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(0)
	var player := gs.players[0]
	player.hand.clear()
	player.hand.append(CardInstance.create(_make_raging_bolt_cd(), 0))
	strategy.call("_on_fast_choice_response", {
		"status": "error",
		"message": "timeout",
	}, "setup_active:0:0", "setup_active", 0)
	strategy.call("ensure_fast_choice_request_fired", "setup_active", gs, 0)
	var failed_keys: Dictionary = strategy.get("_fast_choice_failed_keys")
	return run_checks([
		assert_true(failed_keys.has("setup_active:0:0"), "Fast-choice timeout should mark this prompt as failed"),
		assert_false(strategy.call("is_fast_choice_pending"), "Failed fast-choice prompt should not be re-requested immediately"),
		assert_eq(strategy.call("consume_fast_opening_setup_choice", player, gs, 0).size(), 0, "Failed fast-choice prompt should fall back to rules"),
	])


func test_action_id_prompt_uses_compact_legal_actions() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	builder.call("set_deck_strategy_prompt", "raging_bolt_ogerpon_llm", PackedStringArray(["full deck prompt should not be sent in action-id mode"]))
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var shoes_cd := _make_trainer_cd("Trekking Shoes", "Item")
	shoes_cd.description = "Look at the top card of your deck. You may discard it. If you do not, put it into your hand."
	var shoes := CardInstance.create(shoes_cd, 0)
	player.hand.append(energy)
	player.hand.append(shoes)
	gs.players[1].active_pokemon.get_card_data().attacks = [{"name": "Opponent Attack", "cost": "L", "damage": "90", "text": "Public opponent attack text"}]
	var actions: Array[Dictionary] = [
		{"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon},
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	]
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, actions)
	var legal_actions: Array = payload.get("legal_actions", [])
	var current_actions: Array = _current_legal_actions_from_payload(payload)
	var compact_state: Dictionary = payload.get("game_state", {})
	var tactical_summary: Dictionary = compact_state.get("tactical_summary", {})
	var my_state: Dictionary = compact_state.get("my", {})
	var opponent_state: Dictionary = compact_state.get("opponent", {})
	var my_active: Dictionary = my_state.get("active", {})
	var my_hand: Array = my_state.get("hand", [])
	var opponent_active: Dictionary = opponent_state.get("active", {})
	var action_groups: Dictionary = payload.get("legal_action_groups", {})
	var instruction_text := "\n".join(payload.get("instructions", PackedStringArray()))
	return run_checks([
		assert_eq(str(payload.get("system_prompt_version", "")), "llm_action_id_tree_v1", "Action-id prompt should use the compact schema"),
		assert_false(payload.has("deck_capabilities"), "Action-id prompt should not send full deck capabilities every turn"),
		assert_false(payload.has("deck_strategy_prompt"), "Action-id prompt should not send full deck strategy text every turn"),
		assert_false(payload.has("currently_legal_actions"), "Action-id prompt should not duplicate current actions outside legal_actions"),
		assert_false(payload.has("future_action_groups"), "Action-id prompt should not duplicate future action grouping"),
		assert_false(payload.has("decision_tree_contract"), "Action-id prompt should not ship verbose contract examples in every payload"),
		assert_true(payload.has("deck_strategy_hints"), "Action-id prompt should send compact deck-specific strategy hints"),
		assert_false(payload.has("max_tokens"), "Action-id prompt should not cap output tokens because truncation breaks JSON"),
		assert_eq(str(compact_state.get("battle_context_schema", "")), "battle_context_compact_v1", "Action-id prompt should use compact game state"),
		assert_str_contains(str((my_active.get("attacks", []) as Array)[0]), "Bursting Roar", "Compact state should include own active attack rules"),
		assert_str_contains(str((my_active.get("attacks", []) as Array)[1]), "Thundering Bolt", "Compact state should include own active second attack rules"),
		assert_false(my_active.has("card_rules"), "Compact slot should not duplicate Pokemon attacks inside card_rules"),
		assert_str_contains(str(my_hand), "Look at the top card", "Compact state should include full own hand card descriptions"),
		assert_str_contains(str(opponent_active), "Public opponent attack text", "Compact state should include public opponent board attack text"),
		assert_false(opponent_active.has("card_rules"), "Opponent compact slot should not duplicate public attacks inside card_rules"),
		assert_false(opponent_state.has("hand"), "Compact state must still hide opponent hand contents"),
		assert_true(tactical_summary.has("hand_resources"), "Compact game state should include short hand resource summary"),
		assert_true(tactical_summary.has("attack_pressure"), "Compact game state should include short attack pressure summary"),
		assert_true(not action_groups.is_empty(), "Action-id prompt should include low-token legal action groups"),
		assert_true((action_groups.get("manual_attach", []) as Array).size() >= 1, "Legal action groups should expose manual attach candidates"),
		assert_true((action_groups.get("attack", []) as Array).size() >= 1, "Legal action groups should expose attack candidates"),
		assert_true((payload.get("supported_facts", []) as Array).has("always"), "Prompt should keep a compact supported fact list"),
		assert_false(((payload.get("response_format", {}) as Dictionary).get("required", []) as Array).has("reasoning"), "Action-id schema should not require reasoning/thinking output"),
		assert_eq(current_actions.size(), 3, "Action-id prompt should preserve exact current actions inside legal_actions"),
		assert_true(legal_actions.size() >= current_actions.size(), "Action-id prompt may include generic future_actions alongside current legal actions"),
		assert_str_contains(str((legal_actions[0] as Dictionary).get("id", "")), "attach_energy:", "Legal action id should be semantic and stable"),
		assert_str_contains(instruction_text, "legal_actions", "Instructions should tell the model to choose from legal_actions"),
		assert_str_contains(instruction_text, "future_actions", "Instructions should explain standardized future action ids"),
		assert_str_contains(instruction_text, "deck_strategy_hints", "Instructions should tell the model to consume compact deck hints"),
		assert_str_contains(instruction_text, "route-style priority-ordered decision_tree", "Instructions should require a real prioritized route tree"),
		assert_str_contains(instruction_text, "Do not output reasoning", "Instructions should suppress visible chain-of-thought style output"),
	])


func test_action_id_prompt_includes_json_rule_hints_for_every_playable_card() -> String:
	var script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var nest_cd: CardData = CardDatabase.get_card("CSVH1C", "043")
	var shoes_cd: CardData = CardDatabase.get_card("CSV2aC", "064")
	var vessel_cd: CardData = CardDatabase.get_card("CSV6C", "115")
	var charm_cd: CardData = CardDatabase.get_card("CSV1C", "118")
	if nest_cd == null:
		nest_cd = _make_trainer_cd("Nest Ball", "Item")
		nest_cd.description = "Search your deck for a Basic Pokemon and put it onto your Bench. Then shuffle your deck."
	if shoes_cd == null:
		shoes_cd = _make_trainer_cd("Trekking Shoes", "Item")
		shoes_cd.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
		shoes_cd.description = "Look at the top card of your deck. You may discard it. If you do not, put it into your hand."
	if vessel_cd == null:
		vessel_cd = _make_trainer_cd("Earthen Vessel", "Item")
		vessel_cd.effect_id = "e366f56ecd3f805a28294109a1a37453"
		vessel_cd.description = "Discard 1 card from your hand. Search your deck for up to 2 Basic Energy cards."
	if charm_cd == null:
		charm_cd = _make_trainer_cd("Bravery Charm", "Tool")
		charm_cd.effect_id = "d1c2f018a644e662f2b6895fdfc29281"
		charm_cd.description = "The Basic Pokemon this card is attached to gets +50 HP."
	var nest := CardInstance.create(nest_cd, 0)
	var shoes := CardInstance.create(shoes_cd, 0)
	var vessel := CardInstance.create(vessel_cd, 0)
	var charm := CardInstance.create(charm_cd, 0)
	player.hand.append(nest)
	player.hand.append(shoes)
	player.hand.append(vessel)
	player.hand.append(charm)
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, [
		{"kind": "play_trainer", "card": nest, "targets": [], "requires_interaction": true},
		{"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true},
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "attach_tool", "card": charm, "target_slot": player.active_pokemon},
	])
	var legal_actions: Array = payload.get("legal_actions", [])
	var action_groups: Dictionary = payload.get("legal_action_groups", {})
	var tactical_facts: Dictionary = payload.get("turn_tactical_facts", {})
	var instruction_text := "\n".join(payload.get("instructions", PackedStringArray()))
	if legal_actions.size() < 4:
		return "Expected four legal action summaries"
	var nest_ref: Dictionary = legal_actions[0]
	var shoes_ref: Dictionary = legal_actions[1]
	var vessel_ref: Dictionary = legal_actions[2]
	var charm_ref: Dictionary = legal_actions[3]
	var nest_rules: Dictionary = nest_ref.get("card_rules", {})
	var shoes_rules: Dictionary = shoes_ref.get("card_rules", {})
	var shoes_schema: Dictionary = shoes_ref.get("interaction_schema", {}) if shoes_ref.get("interaction_schema", {}) is Dictionary else {}
	var vessel_rules: Dictionary = vessel_ref.get("card_rules", {})
	var vessel_interaction_schema: Dictionary = vessel_ref.get("interaction_schema", {})
	var charm_rules: Dictionary = charm_ref.get("card_rules", {})
	var nest_rule_text := str(nest_rules.get("text", ""))
	return run_checks([
		assert_true(not nest_rules.is_empty(), "Nest Ball action should include card_rules generated from card JSON"),
		assert_true((nest_rules.get("tags", []) as Array).has("search_deck"), "Nest Ball rule tags should indicate deck search"),
		assert_true((nest_rules.get("tags", []) as Array).has("bench_related"), "Nest Ball rule tags should indicate bench setup"),
		assert_true(nest_rule_text == str(nest_cd.description) or nest_rule_text.contains("Search your deck"), "Nest Ball rule text should come from card JSON description"),
		assert_true(not shoes_rules.is_empty(), "Trekking Shoes action should include card_rules generated from card JSON"),
		assert_true((shoes_rules.get("tags", []) as Array).has("draw"), "Trekking Shoes rule tags should indicate draw/filter behavior"),
		assert_false((shoes_rules.get("tags", []) as Array).has("recover_to_hand"), "Trekking Shoes should not be modeled as discard recovery just because it can put a card into hand"),
		assert_false(shoes_schema.has("night_stretcher_choice"), "Trekking Shoes should not expose recovery interaction schema"),
		assert_false(shoes_rules.has("play_hint"), "Card rule layer should not include per-card tactical play hints"),
		assert_true((vessel_rules.get("tags", []) as Array).has("search_deck"), "Earthen Vessel rule tags should indicate deck search"),
		assert_true((vessel_rules.get("tags", []) as Array).has("energy_related"), "Earthen Vessel rule tags should indicate energy search"),
		assert_true((vessel_rules.get("tags", []) as Array).has("discard"), "Earthen Vessel rule tags should indicate discard cost"),
		assert_true(vessel_interaction_schema.has("discard_cards"), "Earthen Vessel should expose exact discard interaction schema"),
		assert_true(vessel_interaction_schema.has("search_energy"), "Earthen Vessel should expose exact energy search interaction schema"),
		assert_false(vessel_interaction_schema.has("search"), "Interaction schema should not expose vague generic search keys"),
		assert_true((charm_rules.get("tags", []) as Array).has("hp_boost"), "Bravery Charm rule tags should indicate HP boost"),
		assert_true((charm_rules.get("tags", []) as Array).has("basic_pokemon_only"), "Bravery Charm rule tags should indicate Basic-only target"),
		assert_true((action_groups.get("tool_or_modifier", []) as Array).size() >= 1, "Legal action groups should expose tool candidates"),
		assert_true((tactical_facts.get("legal_survival_tool_actions", []) as Array).size() >= 1, "Tactical facts should expose survival tool actions"),
		assert_str_contains(instruction_text, "card_rules", "Action-id instructions should require reading per-card rule summaries"),
		assert_str_contains(instruction_text, "legal_survival_tool_actions", "Action-id instructions should call out safe survival tools"),
	])


func test_action_id_response_materializes_local_action_catalog() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var energy := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(energy)
	var action := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var action_id: String = str(strategy.call("_action_id_for_action", action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [action], gs, 0))
	strategy.set("_cached_turn_number", 7)
	strategy.call("_on_llm_response", {
		"decision_tree": {"actions": [{"id": action_id}]},
	}, 7, gs, 0)
	var queue: Array = strategy.call("get_llm_action_queue")
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_eq(queue.size(), 2, "Action-id response should materialize the queued action plus automatic end_turn"),
		assert_eq(str((queue[0] as Dictionary).get("type", "")), "attach_energy", "Materialized queue should restore the original action type"),
		assert_eq(str((queue[0] as Dictionary).get("action_id", "")), action_id, "Materialized queue should preserve action_id for exact matching"),
		assert_eq(str((queue[1] as Dictionary).get("action_id", "")), "end_turn", "Non-terminal materialized queue should close with end_turn"),
		assert_true(score >= 90000.0, "Materialized action id should score as the selected LLM action"),
	])


func test_raging_bolt_llm_blocks_bravery_charm_on_support_pokemon() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160)
	squawk_cd.name_en = "Squawkabilly ex"
	squawk_cd.mechanic = "ex"
	player.active_pokemon = _make_slot(squawk_cd, 0)
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	var support_action := {"kind": "attach_tool", "card": charm, "target_slot": player.active_pokemon}
	var support_score: float = float(strategy.call("score_action_absolute", support_action, gs, 0))
	var bolt_slot := _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon = bolt_slot
	var bolt_action := {"kind": "attach_tool", "card": charm, "target_slot": bolt_slot}
	var bolt_score: float = float(strategy.call("score_action_absolute", bolt_action, gs, 0))
	return run_checks([
		assert_true(support_score <= -1000.0, "Raging Bolt LLM must not protect two-prize support Pokemon with Bravery Charm"),
		assert_true(bolt_score > -1000.0, "Raging Bolt LLM should still allow Bravery Charm on the main attacker"),
	])


func test_raging_bolt_llm_blocks_early_two_prize_support_bench() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	_set_prizes_remaining(gs.players[1], 6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160)
	squawk_cd.name_en = "Squawkabilly ex"
	squawk_cd.mechanic = "ex"
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	fez_cd.mechanic = "ex"
	var bolt_cd := _make_raging_bolt_cd()
	var squawk := CardInstance.create(squawk_cd, 0)
	var fez := CardInstance.create(fez_cd, 0)
	var bolt := CardInstance.create(bolt_cd, 0)
	var empty_bench_squawk_score: float = float(strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": squawk}, gs, 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0))
	var squawk_score: float = float(strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": squawk}, gs, 0))
	var early_fez_score: float = float(strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": fez}, gs, 0))
	_set_prizes_remaining(gs.players[1], 4)
	var comeback_fez_score: float = float(strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": fez}, gs, 0))
	var bolt_score: float = float(strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": bolt}, gs, 0))
	return run_checks([
		assert_true(empty_bench_squawk_score > -1000.0, "Raging Bolt LLM should allow a support Basic when the bench is empty and losing by no-Basic is the larger risk"),
		assert_true(squawk_score <= -1000.0, "Raging Bolt LLM should not bench Squawkabilly as a passive two-prize liability"),
		assert_true(early_fez_score <= -1000.0, "Raging Bolt LLM should not bench Fezandipiti before the opponent has taken prizes"),
		assert_true(comeback_fez_score > -1000.0, "Raging Bolt LLM should allow Fezandipiti after a knockout enables its comeback role"),
		assert_true(bolt_score > -1000.0, "Raging Bolt LLM should still allow benching backup Raging Bolt attackers"),
	])


func test_raging_bolt_attack_only_llm_plan_prepends_safe_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	var ogerpon := CardInstance.create(ogerpon_cd, 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item"), 0)
	player.hand.append(ogerpon)
	player.hand.append(vessel)
	player.hand.append(charm)
	player.hand.append(nest_ball)
	player.hand.append(shoes)
	var bench_action := {"kind": "play_basic_to_bench", "card": ogerpon}
	var vessel_action := {"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true}
	var charm_action := {"kind": "attach_tool", "card": charm, "target_slot": player.active_pokemon}
	var nest_action := {"kind": "play_trainer", "card": nest_ball, "targets": [], "requires_interaction": true}
	var shoes_action := {"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true}
	var attack_action := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var attack_id: String = str(strategy.call("_action_id_for_action", attack_action, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [bench_action, vessel_action, charm_action, nest_action, shoes_action, attack_action], gs, 0))
	strategy.set("_cached_turn_number", 7)
	strategy.call("_on_llm_response", {
		"decision_tree": {"actions": [{"id": attack_id}]},
	}, 7, gs, 0)
	var queue: Array = strategy.call("get_llm_action_queue")
	var tree: Dictionary = strategy.call("get_llm_decision_tree")
	var branches: Array = tree.get("branches", [])
	var cards_before_attack: Array[String] = []
	var vessel_interactions: Dictionary = {}
	for raw_action: Variant in queue:
		if not (raw_action is Dictionary):
			continue
		var queued_action: Dictionary = raw_action
		if str(queued_action.get("type", "")) == "attack":
			break
		var card_name := str(queued_action.get("card", ""))
		if card_name != "":
			cards_before_attack.append(card_name)
		if card_name == "Earthen Vessel":
			vessel_interactions = queued_action.get("interactions", {})
	return run_checks([
		assert_true(branches.size() >= 5, "Sparse attack-only LLM response should be expanded into a route-style decision tree"),
		assert_true(queue.size() >= 3, "Attack-only LLM plan should be expanded with safe setup before attack"),
		assert_eq(str((queue[0] as Dictionary).get("type", "")), "play_basic_to_bench", "Safe setup should bench Teal Mask Ogerpon before attacking"),
		assert_eq(str((queue[0] as Dictionary).get("card", "")), "Teal Mask Ogerpon ex", "Safe setup should choose the Ogerpon bench action"),
		assert_true(cards_before_attack.has("Nest Ball"), "Safe setup should include Nest Ball before attacking when legal"),
		assert_true(cards_before_attack.has("Bravery Charm"), "Safe setup should include Bravery Charm before attacking when legal"),
		assert_true(cards_before_attack.has("Earthen Vessel"), "Safe setup should include Earthen Vessel before attacking when legal"),
		assert_true(vessel_interactions.has("search_energy"), "Safe setup should carry Earthen Vessel energy search intent"),
		assert_true(vessel_interactions.has("discard_cards"), "Safe setup should carry Earthen Vessel discard intent"),
		assert_eq(str((queue[queue.size() - 1] as Dictionary).get("type", "")), "attack", "The original attack should remain the final action"),
	])


func test_raging_bolt_llm_repairs_mid_route_first_attack_before_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item"), 0)
	var sada := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)
	player.hand.append(fighting)
	player.hand.append(nest_ball)
	player.hand.append(shoes)
	player.hand.append(sada)
	var attach_action := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	var nest_action := {"kind": "play_trainer", "card": nest_ball, "targets": [], "requires_interaction": true}
	var shoes_action := {"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true}
	var sada_action := {"kind": "play_trainer", "card": sada, "targets": [], "requires_interaction": false}
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var burst_attack := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": false}
	var attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	var nest_id: String = str(strategy.call("_action_id_for_action", nest_action, gs, 0))
	var shoes_id: String = str(strategy.call("_action_id_for_action", shoes_action, gs, 0))
	var sada_id: String = str(strategy.call("_action_id_for_action", sada_action, gs, 0))
	var first_attack_id: String = str(strategy.call("_action_id_for_action", first_attack, gs, 0))
	var burst_attack_id: String = str(strategy.call("_action_id_for_action", burst_attack, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [attach_action, first_attack, nest_action, shoes_action, sada_action, burst_attack], gs, 0))
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {
		"actions": [
			{"id": attach_id},
			{"id": first_attack_id},
			{"id": nest_id},
			{"id": shoes_id},
			{"id": sada_id},
			{"id": first_attack_id},
		],
	})
	var repair: Dictionary = strategy.call("_repair_terminal_attack_routes_in_tree", materialized)
	var repaired_tree: Dictionary = repair.get("tree", {})
	var queue: Array = repaired_tree.get("actions", [])
	var ids: Array[String] = []
	for raw_action: Variant in queue:
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("action_id", "")))
	return run_checks([
		assert_eq(ids[0], attach_id, "Manual attach should remain before setup and attack"),
		assert_true(ids.find(nest_id) > ids.find(attach_id), "Post-attack Nest Ball should be moved before the terminal attack"),
		assert_true(ids.find(shoes_id) > ids.find(attach_id), "Post-attack Trekking Shoes should be moved before the terminal attack"),
		assert_true(ids.find(sada_id) > ids.find(attach_id), "Post-attack Sada should be moved before the terminal attack"),
		assert_eq(ids[ids.size() - 1], burst_attack_id, "Ready burst attack should replace Raging Bolt's first hand-discard attack"),
		assert_eq(ids.find(first_attack_id), -1, "Low-value first attack should be removed when burst attack is legal"),
	])


func test_raging_bolt_llm_repairs_chinese_first_attack_to_burst_when_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var bolt_cd := _make_raging_bolt_cd()
	bolt_cd.name = "鐚涢浄榧揺x"
	bolt_cd.name_en = "Raging Bolt ex"
	bolt_cd.attacks = [
		{"name": "椋炴簠鍜嗗摦", "cost": "", "damage": ""},
		{"name": "Thundering Bolt", "cost": "LF", "damage": "70x"},
	]
	player.active_pokemon = _make_slot(bolt_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	ogerpon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	player.bench.append(ogerpon)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Target ex", "Basic", "L", 220), 1)
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var burst_attack := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true}
	var first_attack_id: String = str(strategy.call("_action_id_for_action", first_attack, gs, 0))
	var burst_attack_id: String = str(strategy.call("_action_id_for_action", burst_attack, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [first_attack, burst_attack], gs, 0))
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {
		"actions": [{"id": first_attack_id}],
	})
	var repair: Dictionary = strategy.call("_repair_terminal_attack_routes_in_tree", materialized, gs, 0)
	var repaired_tree: Dictionary = repair.get("tree", {})
	var queue: Array = repaired_tree.get("actions", [])
	return run_checks([
		assert_eq(queue.size(), 1, "Single bad terminal attack should become one legal burst attack"),
		assert_eq(str((queue[0] as Dictionary).get("action_id", "")), burst_attack_id, "Chinese Raging Bolt first attack should be rewritten to the ready burst attack"),
		assert_true(int(repair.get("changed_count", 0)) > 0, "Repair should record the forced attack rewrite"),
	])


func test_raging_bolt_llm_dynamic_guard_scores_burst_after_attach_unlocks_it() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var bolt_cd := _make_raging_bolt_cd()
	bolt_cd.name = "鐚涢浄榧揺x"
	bolt_cd.name_en = "Raging Bolt ex"
	bolt_cd.attacks = [
		{"name": "椋炴簠鍜嗗摦", "cost": "", "damage": ""},
		{"name": "Thundering Bolt", "cost": "LF", "damage": "70x"},
	]
	player.active_pokemon = _make_slot(bolt_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	player.active_pokemon.attached_energy.append(grass)
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var burst_attack := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true}
	var first_attack_id: String = str(strategy.call("_action_id_for_action", first_attack, gs, 0))
	strategy.set("_llm_action_catalog", strategy.call("_build_action_catalog", [first_attack, burst_attack], gs, 0))
	strategy.set("_cached_turn_number", 14)
	strategy.set("_llm_queue_turn", 14)
	strategy.set("_llm_decision_tree", {"actions": [{"id": first_attack_id}]})
	var queued_actions: Array[Dictionary] = [{
		"type": "attack",
		"id": first_attack_id,
		"action_id": first_attack_id,
		"attack_index": 0,
		"attack_name": "Bursting Roar",
	}]
	strategy.set("_llm_action_queue", queued_actions)
	var burst_score := float(strategy.call("score_action_absolute", burst_attack, gs, 0))
	var first_score := float(strategy.call("score_action_absolute", first_attack, gs, 0))
	return run_checks([
		assert_true(burst_score >= 90000.0, "When burst becomes legal after setup, it should inherit the queued first-attack score"),
		assert_true(first_score < burst_score, "Ready burst should suppress the queued first attack"),
	])


func test_raging_bolt_llm_dynamic_guard_attacks_instead_of_end_turn_after_pivot() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var bolt_cd := _make_raging_bolt_cd()
	bolt_cd.name = "Raging Bolt ex"
	bolt_cd.name_en = "Raging Bolt ex"
	bolt_cd.attacks = [
		{"name": "妞嬬偞绨犻崪鍡楁懄", "cost": "", "damage": ""},
		{"name": "Thundering Bolt", "cost": "LF", "damage": "70x"},
	]
	player.active_pokemon = _make_slot(bolt_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	var burst_attack := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true}
	var end_turn := {"kind": "end_turn"}
	strategy.set("_cached_turn_number", 14)
	strategy.set("_llm_queue_turn", 14)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	var queued_actions: Array[Dictionary] = [{"type": "end_turn", "id": "end_turn", "action_id": "end_turn"}]
	strategy.set("_llm_action_queue", queued_actions)
	var burst_score := float(strategy.call("score_action_absolute", burst_attack, gs, 0))
	var end_score := float(strategy.call("score_action_absolute", end_turn, gs, 0))
	return run_checks([
		assert_true(burst_score >= 90000.0, "If a queued route reaches end_turn but active Raging Bolt can burst, score the burst attack instead"),
		assert_true(end_score < burst_score, "Ready burst should suppress the queued end_turn after a pivot/setup route"),
	])


func test_raging_bolt_llm_payload_exposes_generic_future_pivot_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bolt_slot := _make_slot(_make_raging_bolt_cd(), 0)
	bolt_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.bench.clear()
	player.bench.append(bolt_slot)
	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter")
	var sada := CardInstance.create(sada_cd, 0)
	player.hand.append(sada)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": sada, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	])
	var future_actions: Array = payload.get("future_actions", [])
	var future_ids: Array[String] = []
	for raw: Variant in future_actions:
		if raw is Dictionary:
			future_ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_true(future_ids.has("future:retreat_to:bench_0"), "Payload should expose a generic future retreat/pivot to bench_0"),
		assert_true(future_ids.has("future:attack_after_pivot:bench_0:1:thundering_bolt"), "Payload should expose the generic post-pivot second attack"),
	])


func test_llm_end_turn_queue_converts_to_active_ko_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.attacks = [{
		"name": "Myriad Leaf Shower",
		"cost": "GGG",
		"damage": "30+",
		"text": "This attack does 30 more damage for each Energy attached to both Active Pokemon.",
	}]
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	for i: int in 3:
		player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var charizard_cd := _make_pokemon_cd("Charizard ex", "Stage2", "R", 330)
	charizard_cd.name_en = "Charizard ex"
	charizard_cd.weakness_energy = "G"
	charizard_cd.weakness_value = "x2"
	gs.players[1].active_pokemon = _make_slot(charizard_cd, 1)
	gs.players[1].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 1))
	gs.players[1].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 1))
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "end_turn"}]})
	strategy.set("_llm_action_queue", [{"type": "end_turn", "action_id": "end_turn", "capability": "end_turn"}])
	var attack_action := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var end_turn_action := {"kind": "end_turn"}
	var attack_score: float = float(strategy.call("score_action_absolute", attack_action, gs, 0))
	var end_score: float = float(strategy.call("score_action_absolute", end_turn_action, gs, 0))
	return run_checks([
		assert_true(attack_score >= 90000.0, "End-turn placeholder should convert to a now-legal high-pressure active attack"),
		assert_true(end_score <= -1000.0, "Actual end_turn should be hard-blocked while an active KO attack is ready"),
	])


func test_raging_bolt_llm_generic_future_attack_matches_real_attack_later() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var virtual_attack := {"type": "attack", "id": "future:attack_after_pivot:bench_0:1:thundering_bolt", "action_id": "future:attack_after_pivot:bench_0:1:thundering_bolt", "attack_index": 1, "attack_name": "Thundering Bolt", "future": true}
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [virtual_attack]})
	strategy.set("_llm_action_catalog", {"future:attack_after_pivot:bench_0:1:thundering_bolt": virtual_attack})
	strategy.set("_llm_action_queue", [virtual_attack])
	var burst_attack := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true}
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var burst_score: float = float(strategy.call("score_action_absolute", burst_attack, gs, 0))
	var first_matches: bool = bool(strategy.call("_queue_item_matches", virtual_attack, first_attack, gs, 0))
	return run_checks([
		assert_true(burst_score >= 90000.0, "Projected virtual burst action should match the real second attack once it becomes legal"),
		assert_false(first_matches, "Projected burst action must not match the weaker first attack"),
	])


func test_raging_bolt_llm_blocks_low_value_redraw_when_productive_actions_visible() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	for i: int in 4:
		player.hand.append(CardInstance.create(_make_trainer_cd("Hand resource %d" % i), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var low_attack := {
		"id": "attack:0:bursting_roar",
		"action_id": "attack:0:bursting_roar",
		"type": "attack",
		"attack_index": 0,
		"attack_name": "Bursting Roar",
		"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
	}
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [low_attack]})
	strategy.set("_llm_action_catalog", {
		"attack:0:bursting_roar": low_attack,
		"attach_tool:c50:active": {"id": "attach_tool:c50:active", "action_id": "attach_tool:c50:active", "type": "attach_tool", "card": "Bravery Charm"},
	})
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var matches: bool = bool(strategy.call("_queue_item_matches", low_attack, first_attack, gs, 0))
	var score: float = float(strategy.call("score_action_absolute", first_attack, gs, 0))
	return run_checks([
		assert_false(matches, "Runtime queue guard should reject low-value redraw attacks when productive non-terminal actions are visible and hand is not empty"),
		assert_true(score < 0.0, "Runtime score fallback should also veto the low-value redraw attack so rules do not reselect it after queue rejection"),
	])


func test_raging_bolt_llm_allows_dead_hand_redraw_after_safe_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.hand.append(CardInstance.create(_make_named_trainer_cd("Professor Sada's Vitality", "Professor Sada's Vitality", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Energy Retrieval"), 0))
	for i: int in 30:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), 0))
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	var greninja := CardInstance.create(greninja_cd, 0)
	player.hand.append(greninja)
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var low_attack := {
		"type": "attack",
		"attack_index": 0,
		"attack_name": "Bursting Roar",
		"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
	}
	strategy.set("_cached_turn_number", 6)
	strategy.set("_llm_queue_turn", 6)
	strategy.set("_llm_decision_tree", {"actions": [low_attack]})
	strategy.set("_llm_action_catalog", {"low_attack": low_attack})
	strategy.set("_llm_action_queue", [low_attack])
	var allow_dead_hand := bool(strategy.call("_low_value_redraw_dead_hand_fallback_allowed", gs, 0))
	var block_context := bool(strategy.call("_should_block_low_value_runtime_attack_context", gs, 0))
	var matches: bool = bool(strategy.call("_queue_item_matches", low_attack, first_attack, gs, 0))
	var score: float = float(strategy.call("score_action_absolute", first_attack, gs, 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_basic_to_bench", "card": greninja},
		first_attack,
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var attack_route_actions: Array[String] = []
	for raw_route: Variant in payload.get("candidate_routes", []):
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route
		if str(route.get("id", "")) != "attack_now":
			continue
		for raw_action: Variant in route.get("actions", []):
			if raw_action is Dictionary:
				attack_route_actions.append(str((raw_action as Dictionary).get("id", "")))
	var route_has_safe_setup := attack_route_actions.size() >= 2 and str(attack_route_actions[0]).begins_with("play_basic_to_bench:")
	var route_closes_with_redraw := attack_route_actions.size() >= 2 and str(attack_route_actions[attack_route_actions.size() - 1]).begins_with("attack:0")
	return run_checks([
		assert_true(matches, "Dead-hand redraw should remain executable when no Energy or primary route is visible (allow=%s block=%s)" % [str(allow_dead_hand), str(block_context)]),
		assert_true(score > 0.0, "Runtime score should allow low-value redraw as dead-hand fallback (score=%f)" % score),
		assert_true(bool(facts.get("redraw_attack_recommended", false)), "Prompt facts should recommend redraw when only low attack is ready, hand has no Energy, and deck is safe"),
		assert_true(attack_route_actions.size() >= 2, "Candidate attack route should exist for dead-hand redraw"),
		assert_true(route_has_safe_setup, "Dead-hand redraw route should bench safe basics before discarding the hand: %s" % JSON.stringify(attack_route_actions)),
		assert_true(route_closes_with_redraw, "Dead-hand redraw route should close with the listed redraw attack: %s" % JSON.stringify(attack_route_actions)),
	])


func test_raging_bolt_llm_payload_does_not_present_grass_attach_as_primary_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass)
	var attach_action := {"kind": "attach_energy", "card": grass, "target_slot": player.active_pokemon}
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		attach_action,
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var misleading_attach_route := false
	for raw_route: Variant in payload.get("candidate_routes", []):
		if not (raw_route is Dictionary):
			continue
		for raw_action: Variant in (raw_route as Dictionary).get("actions", []):
			if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")).begins_with("attach_energy:"):
				misleading_attach_route = true
	return run_checks([
		assert_eq(str(facts.get("primary_attack_name", "")), "Thundering Bolt", "Raging Bolt primary attack should remain the second attack"),
		assert_true((facts.get("primary_attack_missing_cost", []) as Array).has("Lightning"), "Primary facts should still require Lightning"),
		assert_true((facts.get("primary_attack_missing_cost", []) as Array).has("Fighting"), "Primary facts should still require Fighting"),
		assert_eq(str(facts.get("best_manual_attach_energy_for_active_attack", "")), "", "Grass must not be surfaced as the best attach just because the low redraw attack has Colorless cost"),
		assert_false(misleading_attach_route, "Candidate routes must not teach LLM to attach Grass to Raging Bolt as primary setup while L/F are missing"),
	])


func test_raging_bolt_llm_blocks_low_value_redraw_when_hand_has_productive_piece() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Slither Wing", "Basic", "F", 140), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_raging_bolt_cd(), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var low_attack := {
		"id": "attack:0:bursting_roar",
		"action_id": "attack:0:bursting_roar",
		"type": "attack",
		"attack_index": 0,
		"attack_name": "Bursting Roar",
		"attack_rules": {"name": "Bursting Roar", "damage": "", "text": "Discard your hand and draw 6 cards."},
	}
	strategy.set("_cached_turn_number", 2)
	strategy.set("_llm_queue_turn", 2)
	strategy.set("_llm_decision_tree", {"actions": [low_attack]})
	strategy.set("_llm_action_catalog", {"attack:0:bursting_roar": low_attack})
	strategy.set("_llm_action_queue", [low_attack])
	var first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var matches: bool = bool(strategy.call("_queue_item_matches", low_attack, first_attack, gs, 0))
	var score: float = float(strategy.call("score_action_absolute", first_attack, gs, 0))
	return run_checks([
		assert_false(matches, "Low-value redraw should not match the LLM queue when hand contains productive non-energy pieces"),
		assert_true(score < 0.0, "Score fallback should veto low-value redraw when it would discard productive Pokemon/resources"),
	])


func test_raging_bolt_llm_blocks_queued_support_attack_without_attack_quality() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(22)
	var player := gs.players[0]
	var slither_cd := _make_pokemon_cd("Slither Wing", "Basic", "F", 140)
	slither_cd.name_en = "Slither Wing"
	slither_cd.is_tags = ["Ancient"]
	slither_cd.attacks = [
		{"name": "Tread Flat", "cost": "F", "damage": "", "text": "Discard the top card of your opponent's deck."},
		{"name": "Burning Turbulence", "cost": "FF", "damage": "120", "text": ""},
	]
	player.active_pokemon = _make_slot(slither_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_raging_bolt_cd(), 0))
	var runtime_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var runtime_attack_id := str(strategy.call("_action_id_for_action", runtime_attack, gs, 0))
	var queued_support_attack := {
		"id": runtime_attack_id,
		"action_id": runtime_attack_id,
		"type": "attack",
		"attack_index": 0,
		"attack_name": "Tread Flat",
	}
	strategy.set("_cached_turn_number", 22)
	strategy.set("_llm_queue_turn", 22)
	strategy.set("_llm_decision_tree", {"actions": [queued_support_attack]})
	strategy.set("_llm_action_catalog", {runtime_attack_id: queued_support_attack})
	strategy.set("_llm_action_queue", [queued_support_attack])
	var matches: bool = bool(strategy.call("_queue_item_matches", queued_support_attack, runtime_attack, gs, 0))
	var score: float = float(strategy.call("score_action_absolute", runtime_attack, gs, 0))
	return run_checks([
		assert_true(matches, "Exact id without attack_quality may still match before queue scoring"),
		assert_true(score <= -1000.0, "Queue scoring must still veto low-value support attacks when productive Raging Bolt setup exists (score=%f)" % score),
	])


func test_raging_bolt_llm_blocks_id_only_first_attack_queue_when_burst_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(20)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0))
	var queued_first_attack := {"id": "attack:0:bursting_roar", "action_id": "attack:0:bursting_roar", "type": "attack"}
	var runtime_first_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var runtime_burst_attack := {"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", queued_first_attack, runtime_first_attack, gs, 0)),
			"ID-only queued first attack should still be recognized and blocked when Raging Bolt burst is ready"),
		assert_true(bool(strategy.call("_deck_queue_item_matches_action", queued_first_attack, runtime_burst_attack, gs, 0)),
			"ID-only queued first attack should be allowed to match the stronger ready burst attack"),
	])


func test_raging_bolt_llm_low_value_guard_does_not_block_non_bolt_text_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.attacks = [
		{"name": "Moonlight Shuriken", "cost": "WWC", "damage": "", "text": "This attack does 90 damage to 2 of your opponent's Pokemon."},
	]
	player.active_pokemon = _make_slot(greninja_cd, 0)
	for i: int in 4:
		player.hand.append(CardInstance.create(_make_trainer_cd("Hand resource %d" % i), 0))
	strategy.set("_llm_action_catalog", {
		"use_ability:bench_0:0": {"id": "use_ability:bench_0:0", "action_id": "use_ability:bench_0:0", "type": "use_ability", "pokemon": "Teal Mask Ogerpon ex"},
	})
	var text_attack := {"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false}
	var score: float = float(strategy.call("score_action_absolute", text_attack, gs, 0))
	return assert_true(score > -1000.0, "Low-value redraw guard must not veto non-Raging-Bolt text attacks such as Moonlight Shuriken")


func test_raging_bolt_llm_payload_exposes_not_reachable_attack_facts() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.clear()
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.abilities = [{"name": "Teal Dance", "text": "Attach a Grass Energy from your hand to this Pokemon. Draw a card."}]
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130)
	greninja_cd.name_en = "Radiant Greninja"
	greninja_cd.abilities = [{"name": "Concealed Cards", "text": "Discard an Energy card from your hand. Draw 2 cards."}]
	player.bench.append(_make_slot(ogerpon_cd, 0))
	player.bench.append(_make_slot(greninja_cd, 0))
	var fighting := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(fighting)
	player.hand.append(CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "use_ability", "source_slot": player.bench[1], "ability_index": 0, "requires_interaction": true},
		{"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var after_attach_missing: Array = facts.get("missing_attack_cost_after_best_manual_attach", [])
	var burst_missing_after_attach: Array = []
	for raw_option: Variant in facts.get("active_attack_options", []):
		if raw_option is Dictionary and int((raw_option as Dictionary).get("attack_index", -1)) == 1:
			burst_missing_after_attach = (raw_option as Dictionary).get("missing_cost_after_best_manual_attach", [])
	var supporter_names: Array = facts.get("supporter_names_in_hand", [])
	var legal_supporters: Array = facts.get("legal_supporter_names", [])
	var instructions_text := "\n".join(payload.get("instructions", PackedStringArray()))
	return run_checks([
		assert_false(bool(facts.get("attack_legal_now", true)), "No attack should be legal in this setup state"),
		assert_true(burst_missing_after_attach.has("Lightning"), "After best manual Fighting attach, the burst attack should still miss Lightning"),
		assert_true(supporter_names.has("Professor Sada's Vitality"), "Generic tactical facts should expose Supporters seen in hand"),
		assert_false(legal_supporters.has("Professor Sada's Vitality"), "Generic tactical facts should show Sada is not currently legal without adding card-specific rules"),
		assert_str_contains(instructions_text, "Read turn_tactical_facts before deck_strategy_hints", "Prompt should tell LLM current facts override generic deck template"),
	])


func test_raging_bolt_llm_exposes_primary_attack_reachable_after_energy_search() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var vessel_cd := _make_trainer_cd("Earthen Vessel", "Item")
	vessel_cd.effect_id = "e366f56ecd3f805a28294109a1a37453"
	vessel_cd.description = "Discard 1 card from your hand. Search your deck for up to 2 Basic Energy cards."
	var vessel := CardInstance.create(vessel_cd, 0)
	player.hand.append(vessel)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var future_ids: Array[String] = []
	for raw: Variant in payload.get("future_actions", []):
		if raw is Dictionary:
			future_ids.append(str((raw as Dictionary).get("id", "")))
	return run_checks([
		assert_true(bool(facts.get("attack_legal_now", false)), "The first redraw attack is currently legal"),
		assert_false(bool(facts.get("primary_attack_ready", true)), "The primary damage attack should not be ready yet"),
		assert_eq(str(facts.get("primary_attack_name", "")), "Thundering Bolt", "Tactical facts should identify the primary damage attack"),
		assert_true((facts.get("primary_attack_missing_cost", []) as Array).has("Lightning"), "Primary attack should expose the exact missing Lightning cost"),
		assert_true(bool(facts.get("primary_attack_reachable_after_search", false)), "Energy search plus manual attach should make the primary attack reachable"),
		assert_true(bool(facts.get("primary_attack_reachable_after_visible_engine", false)), "Any reachable visible primary future attack should mark the visible-engine flag"),
		assert_eq(facts.get("primary_attack_route", []), ["energy_search", "manual_attach", "Thundering Bolt"], "Simple visible route should not require discard or Sada when search plus manual attach is enough"),
		assert_true(bool(facts.get("only_ready_attack_is_low_value_redraw", false)), "Ready attack quality should mark the only legal attack as low-value redraw"),
		assert_true(future_ids.has("future:attach_after_search:lightning:active"), "Future actions should expose searched Lightning attach to active"),
		assert_true(future_ids.has("future:attack_after_search_attach:active:1:thundering_bolt"), "Future actions should expose post-search primary attack"),
	])


func test_llm_rejects_low_value_redraw_attack_when_primary_attack_is_search_reachable() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var vessel_cd := _make_trainer_cd("Earthen Vessel", "Item")
	vessel_cd.effect_id = "e366f56ecd3f805a28294109a1a37453"
	vessel_cd.description = "Discard 1 card from your hand. Search your deck for up to 2 Basic Energy cards."
	var vessel := CardInstance.create(vessel_cd, 0)
	player.hand.append(vessel)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	])
	var attack_id := ""
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("type", "")) == "attack":
			attack_id = str((raw as Dictionary).get("id", ""))
	strategy.set("_cached_turn_number", 9)
	strategy.call("_on_llm_response", {
		"decision_tree": {
			"branches": [{
				"when": [{"fact": "active_attack_ready", "attack_name": "Bursting Roar"}],
				"actions": [{"id": attack_id}],
			}],
			"fallback_actions": [{"id": "end_turn"}],
		},
	}, 9, gs, 0)
	var vessel_score: float = float(strategy.call("score_action_absolute", {"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true}, gs, 0))
	return run_checks([
		assert_false(strategy.call("is_llm_disabled_for_turn", 9), "Low-value redraw attack rejection should keep the turn usable"),
		assert_true(strategy.call("has_llm_plan_for_turn", 9), "Rejected redraw-first route should fall back to a candidate route when available"),
		assert_true(vessel_score > 0.0, "Candidate fallback should prefer the searchable primary route over low-value redraw"),
	])


func test_raging_bolt_llm_exposes_visible_engine_sada_attack_chain() -> String:
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
	var vessel := CardInstance.create(vessel_cd, 0)
	var sada := CardInstance.create(sada_cd, 0)
	player.hand.append(vessel)
	player.hand.append(sada)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var future_ids: Array[String] = []
	var future_sada_seen := false
	var future_attack_prereqs: Array = []
	for raw: Variant in payload.get("future_actions", []):
		if raw is Dictionary:
			var ref := raw as Dictionary
			future_ids.append(str(ref.get("id", "")))
			if str(ref.get("type", "")) == "play_trainer" and str(ref.get("card", "")) == "Professor Sada's Vitality":
				future_sada_seen = true
			if str(ref.get("id", "")) == "future:attack_after_visible_engine:active:1:thundering_bolt":
				future_attack_prereqs = ref.get("prerequisite_actions", [])
	return run_checks([
		assert_true(bool(facts.get("primary_attack_reachable_after_visible_engine", false)), "Visible engine facts should recognize Vessel + Greninja + Sada + manual attach as reaching the primary attack"),
		assert_true((facts.get("primary_attack_route", []) as Array).has("discard_energy_acceleration_supporter"), "Primary route should describe the future Sada acceleration step"),
		assert_true(future_sada_seen, "Future actions should expose Professor Sada after the visible discard-energy engine creates discard fuel"),
		assert_true(future_ids.has("future:attach_after_visible_engine:fighting:active"), "Future actions should expose the visible-engine manual attach step before the primary attack"),
		assert_true(future_ids.has("future:attack_after_visible_engine:active:1:thundering_bolt"), "Future actions should expose the complete visible-engine primary attack"),
		assert_true(future_attack_prereqs.has("future:attach_after_visible_engine:fighting:active"), "Visible-engine future attack should require the explicit future manual attach"),
		assert_eq(future_attack_prereqs.size(), _unique_count_for_test(future_attack_prereqs), "Visible-engine future route prerequisites should not contain duplicate action ids"),
	])


func test_raging_bolt_llm_exposes_safe_ogerpon_before_simple_primary_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.abilities = [{"name": "Teal Dance", "text": "Attach a Grass Energy from your hand to this Pokemon. Draw a card."}]
	player.bench.clear()
	player.bench.append(_make_slot(ogerpon_cd, 0))
	var vessel_cd := _make_trainer_cd("Earthen Vessel", "Item")
	vessel_cd.effect_id = "e366f56ecd3f805a28294109a1a37453"
	vessel_cd.description = "Discard 1 card from your hand. Search your deck for up to 2 Basic Energy cards."
	var vessel := CardInstance.create(vessel_cd, 0)
	player.hand.append(vessel)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "attack", "attack_index": 0, "targets": [], "requires_interaction": false},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var safe_actions: Array = facts.get("safe_pre_primary_actions", [])
	var found_ogerpon := false
	for raw: Variant in safe_actions:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "use_ability:bench_0:0":
			found_ogerpon = true
	return run_checks([
		assert_true(bool(facts.get("primary_attack_reachable_after_visible_engine", false)), "Search plus manual attach should set visible-engine reachability"),
		assert_eq(facts.get("primary_attack_route", []), ["energy_search", "manual_attach", "Thundering Bolt"], "The route should stay simple when Sada is unnecessary"),
		assert_true(found_ogerpon, "Safe pre-primary actions should expose Teal Mask Ogerpon's energy+draw ability"),
	])


func test_raging_bolt_llm_exposes_active_ogerpon_manual_attach_ko_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.attacks = [{
		"name": "Myriad Leaf Shower",
		"cost": "GGG",
		"damage": "30+",
		"text": "This attack does 30 more damage for each Energy attached to both Active Pokemon.",
	}]
	player.active_pokemon = _make_slot(ogerpon_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(grass)
	var charizard_cd := _make_pokemon_cd("Charizard ex", "Stage2", "R", 330)
	charizard_cd.name_en = "Charizard ex"
	charizard_cd.weakness_energy = "G"
	charizard_cd.weakness_value = "x2"
	gs.players[1].active_pokemon = _make_slot(charizard_cd, 1)
	gs.players[1].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 1))
	gs.players[1].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 1))
	var attach_action := {"kind": "attach_energy", "card": grass, "target_slot": player.active_pokemon}
	var expected_attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		attach_action,
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var best_attack: Dictionary = facts.get("best_active_attack_after_manual_attach", {}) if facts.get("best_active_attack_after_manual_attach", {}) is Dictionary else {}
	var routes: Array = payload.get("candidate_routes", [])
	var route_seen := false
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "manual_attach_to_active_attack":
			route_seen = true
	return run_checks([
		assert_true(bool(facts.get("manual_attach_enables_best_active_attack", false)), "Tactical facts should expose active attacker one-attach conversion"),
		assert_eq(str(facts.get("best_manual_attach_to_best_active_attack_action_id", "")), expected_attach_id, "The exact active Grass attach id should be provided"),
		assert_eq(str(best_attack.get("attack_name", "")), "Myriad Leaf Shower", "Best active attach route should name the Ogerpon attack"),
		assert_true(bool(best_attack.get("kos_opponent_active_after_best_manual_attach", false)), "Damage projection should know Grass weakness lets Ogerpon KO Charizard ex"),
		assert_true(route_seen, "Candidate routes should expose manual_attach_to_active_attack for the LLM"),
	])


func test_raging_bolt_llm_exposes_extra_manual_attach_for_burst_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var fighting := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	player.hand.append(fighting)
	var raikou_cd := _make_pokemon_cd("Raikou V", "Basic", "L", 200)
	raikou_cd.name_en = "Raikou V"
	gs.players[1].active_pokemon = _make_slot(raikou_cd, 1)
	var attach_action := {"kind": "attach_energy", "card": fighting, "target_slot": player.active_pokemon}
	var expected_attach_id: String = str(strategy.call("_action_id_for_action", attach_action, gs, 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		attach_action,
		{"kind": "attack", "attack_index": 1, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var best_attack: Dictionary = facts.get("best_active_attack_after_manual_attach", {}) if facts.get("best_active_attack_after_manual_attach", {}) is Dictionary else {}
	var routes: Array = payload.get("candidate_routes", [])
	var route_seen := false
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) in ["manual_attach_to_active_attack", "manual_attach_to_attack"]:
			route_seen = true
	return run_checks([
		assert_true(bool(facts.get("manual_attach_enables_best_active_attack", false)), "Ready Raging Bolt should still expose extra manual attach when it turns 140 into 210 KO damage"),
		assert_eq(str(facts.get("best_manual_attach_to_best_active_attack_action_id", "")), expected_attach_id, "The exact extra Fighting attach id should be provided"),
		assert_eq(int(best_attack.get("estimated_damage_after_best_manual_attach", 0)), 210, "Burst damage projection should count board basic Energy plus the extra attach"),
		assert_true(bool(best_attack.get("kos_opponent_active_after_best_manual_attach", false)), "Extra attach should be marked as active KO conversion"),
		assert_true(route_seen, "Candidate routes should expose a manual attach attack route for extra burst damage KO"),
	])


func test_raging_bolt_llm_exposes_productive_engine_actions_from_card_rules() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("厄诡椪 碧草面具ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.effect_id = "409898a79b38fe8ca279e7bdaf4fd52e"
	ogerpon_cd.description = "碧草之舞：选择自己手牌中的1张基本草能量，附着于这只宝可梦身上。然后抽1张卡。"
	ogerpon_cd.abilities = [{"name": "碧草之舞", "text": "选择自己手牌中的1张基本草能量，附着于这只宝可梦身上。然后抽1张卡。"}]
	player.bench.clear()
	player.bench.append(_make_slot(ogerpon_cd, 0))
	var shoes_cd := _make_trainer_cd("健行鞋", "Item")
	shoes_cd.name_en = "Trekking Shoes"
	shoes_cd.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	shoes_cd.description = "查看自己牌库上方1张卡。可以将其加入手牌，或弃掉并抽1张卡。"
	var shoes := CardInstance.create(shoes_cd, 0)
	player.hand.append(shoes)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var productive: Array = facts.get("productive_engine_actions", [])
	var found_ogerpon := false
	var found_shoes := false
	for raw: Variant in productive:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("id", "")) == "use_ability:bench_0:0" and str(ref.get("role", "")) == "charge_and_draw":
			found_ogerpon = true
		if str(ref.get("card", "")) == "Trekking Shoes" and str(ref.get("role", "")) == "draw_filter":
			found_shoes = true
	var instructions_text := "\n".join(payload.get("instructions", PackedStringArray()))
	return run_checks([
		assert_true(found_ogerpon, "Productive engine facts should expose Ogerpon charge+draw ability from real effect_id/card rules"),
		assert_true(found_shoes, "Productive engine facts should expose Trekking Shoes as draw/filter engine from real effect_id/card rules"),
		assert_str_contains(instructions_text, "productive_engine_actions", "Prompt should tell LLM to consume productive engine facts"),
	])


func test_raging_bolt_llm_low_deck_prompt_facts_hide_draw_churn_engines() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	player.deck.clear()
	for i: int in 5:
		player.deck.append(CardInstance.create(_make_trainer_cd("Low deck filler %d" % i), 0))
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("厄诡椪 碧草面具ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.effect_id = "409898a79b38fe8ca279e7bdaf4fd52e"
	ogerpon_cd.abilities = [{"name": "碧草之舞", "text": "Attach a Basic Grass Energy from your hand to this Pokemon. Then draw a card."}]
	var ogerpon := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon)
	var shoes_cd := _make_trainer_cd("Trekking Shoes", "Item")
	shoes_cd.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	shoes_cd.description = "Look at the top card of your deck. Put it into your hand or discard it and draw a card."
	var shoes := CardInstance.create(shoes_cd, 0)
	var stretcher_cd := _make_trainer_cd("Night Stretcher", "Item")
	stretcher_cd.effect_id = "3e6f1daf545dfed48d0588dd50792a2e"
	stretcher_cd.description = "Put a Pokemon or Basic Energy from your discard pile into your hand."
	var stretcher := CardInstance.create(stretcher_cd, 0)
	player.hand.append(shoes)
	player.hand.append(stretcher)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": ogerpon, "ability_index": 0, "requires_interaction": true},
		{"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true},
		{"kind": "play_trainer", "card": stretcher, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var safe: Array = facts.get("safe_pre_primary_actions", [])
	var productive: Array = facts.get("productive_engine_actions", [])
	var saw_ogerpon_safe := false
	var saw_ogerpon_productive := false
	var saw_shoes_productive := false
	var saw_stretcher_productive := false
	var route_has_draw_churn := false
	for raw_safe: Variant in safe:
		if raw_safe is Dictionary and str((raw_safe as Dictionary).get("id", "")) == "use_ability:bench_0:0":
			saw_ogerpon_safe = true
	for raw_productive: Variant in productive:
		if not (raw_productive is Dictionary):
			continue
		var action: Dictionary = raw_productive
		if str(action.get("id", "")) == "use_ability:bench_0:0":
			saw_ogerpon_productive = true
		if str(action.get("card", "")) == "Trekking Shoes":
			saw_shoes_productive = true
		if str(action.get("card", "")) == "Night Stretcher":
			saw_stretcher_productive = true
	for raw_route: Variant in payload.get("candidate_routes", []):
		if not (raw_route is Dictionary):
			continue
		for raw_action: Variant in (raw_route as Dictionary).get("actions", []):
			if not (raw_action is Dictionary):
				continue
			var action_id := str((raw_action as Dictionary).get("id", ""))
			if action_id == "use_ability:bench_0:0" or action_id.begins_with("play_trainer:c%d" % int(shoes.instance_id)):
				route_has_draw_churn = true
	return run_checks([
		assert_true(bool(facts.get("no_deck_draw_lock", false)), "Test payload should enable low-deck draw lock"),
		assert_false(saw_ogerpon_safe, "Low-deck prompt facts must not advertise Ogerpon charge-and-draw as safe setup"),
		assert_false(saw_ogerpon_productive, "Low-deck prompt facts must not advertise Ogerpon charge-and-draw as productive setup"),
		assert_false(saw_shoes_productive, "Low-deck prompt facts must not advertise Trekking Shoes as productive setup"),
		assert_true(saw_stretcher_productive, "Low-deck prompt facts should still expose non-draw recovery actions"),
		assert_false(route_has_draw_churn, "Low-deck candidate routes must not include optional draw/churn actions"),
	])


func test_raging_bolt_llm_empty_deck_prompt_keeps_draw_lock() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	player.deck.clear()
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var shoes_cd := _make_trainer_cd("Trekking Shoes", "Item")
	shoes_cd.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	shoes_cd.description = "Look at the top card of your deck. Put it into your hand or discard it and draw a card."
	var shoes := CardInstance.create(shoes_cd, 0)
	player.hand.append(shoes)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": shoes, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var route_has_shoes := false
	for raw_route: Variant in payload.get("candidate_routes", []):
		if not (raw_route is Dictionary):
			continue
		for raw_action: Variant in (raw_route as Dictionary).get("actions", []):
			if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == "play_trainer:c%d" % int(shoes.instance_id):
				route_has_shoes = true
	return run_checks([
		assert_true(bool(facts.get("no_deck_draw_lock", false)), "Empty deck must still enable no-deck-draw lock"),
		assert_true(bool(facts.get("deck_draw_risk", false)), "Empty deck is maximum draw risk"),
		assert_false(route_has_shoes, "Empty-deck candidate routes must not include optional Trekking Shoes"),
	])


func test_raging_bolt_llm_exposes_recovery_and_fezandipiti_as_productive_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var fez_cd := _make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210)
	fez_cd.name_en = "Fezandipiti ex"
	fez_cd.effect_id = "ab6c3357e2b8a8385a68da738f41e0c1"
	fez_cd.abilities = [{"name": "Flip the Script", "text": "If any of your Pokemon were Knocked Out during your opponent's last turn, draw 3 cards."}]
	player.bench.clear()
	player.bench.append(_make_slot(fez_cd, 0))
	var stretcher_cd := _make_trainer_cd("Night Stretcher", "Item")
	stretcher_cd.effect_id = "3e6f1daf545dfed48d0588dd50792a2e"
	stretcher_cd.description = "Put a Pokemon or Basic Energy card from your discard pile into your hand."
	var stretcher := CardInstance.create(stretcher_cd, 0)
	player.hand.append(stretcher)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": false},
		{"kind": "play_trainer", "card": stretcher, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var productive: Array = facts.get("productive_engine_actions", [])
	var found_fez := false
	var found_stretcher := false
	var stretcher_schema: Dictionary = {}
	for raw_ref: Variant in _current_legal_actions_from_payload(payload):
		if raw_ref is Dictionary and str((raw_ref as Dictionary).get("card", "")) == "Night Stretcher":
			stretcher_schema = (raw_ref as Dictionary).get("interaction_schema", {})
	for raw_action: Variant in productive:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		if str(action.get("card", "")) == "Fezandipiti ex" and str(action.get("role", "")) == "draw_ability":
			found_fez = true
		if str(action.get("card", "")) == "Night Stretcher" and str(action.get("role", "")) == "resource_recovery":
			found_stretcher = true
	return run_checks([
		assert_true(found_fez, "Fezandipiti ex should be exposed as a productive draw ability before ending the turn"),
		assert_true(found_stretcher, "Night Stretcher should be exposed as productive resource recovery when legal"),
		assert_true(stretcher_schema.has("night_stretcher_choice"), "Night Stretcher should expose its real recovery choice step"),
		assert_false(stretcher_schema.has("search_targets"), "Night Stretcher should not be modeled as deck search"),
	])


func test_ogerpon_ability_schema_uses_hand_energy_not_search() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	_fill_player_deck(player)
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("厄诡椪 碧草面具ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.effect_id = "409898a79b38fe8ca279e7bdaf4fd52e"
	ogerpon_cd.description = "特性: 碧草之舞 选择自己手牌中的1张基本草能量，附着于这只宝可梦身上。然后抽1张卡。"
	ogerpon_cd.abilities = [{"name": "碧草之舞", "text": "选择自己手牌中的1张基本草能量，附着于这只宝可梦身上。然后抽1张卡。"}]
	player.bench.clear()
	player.bench.append(_make_slot(ogerpon_cd, 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.bench[0], "ability_index": 0, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var ability_ref: Dictionary = {}
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "use_ability:bench_0:0":
			ability_ref = raw
	var schema: Dictionary = ability_ref.get("interaction_schema", {}) if ability_ref.get("interaction_schema", {}) is Dictionary else {}
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var productive: Array = facts.get("productive_engine_actions", [])
	var productive_interactions: Dictionary = {}
	for raw_action: Variant in productive:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == "use_ability:bench_0:0":
			productive_interactions = (raw_action as Dictionary).get("interactions", {})
	var false_energy_search_future := false
	for raw_future: Variant in payload.get("future_actions", []):
		if not (raw_future is Dictionary):
			continue
		var prerequisite_actions: Array = (raw_future as Dictionary).get("prerequisite_actions", []) if (raw_future as Dictionary).get("prerequisite_actions", []) is Array else []
		if prerequisite_actions.has("use_ability:bench_0:0") and str((raw_future as Dictionary).get("prerequisite", "")) == "energy_search_then_manual_attach":
			false_energy_search_future = true
	return run_checks([
		assert_true(schema.has("basic_energy_from_hand"), "Ogerpon ability should expose a hand-energy selection schema"),
		assert_true(schema.has("energy_card_id"), "Ogerpon ability should allow exact hand energy card id selection"),
		assert_false(schema.has("search_energy"), "Ogerpon ability should not be modeled as deck energy search"),
		assert_false(schema.has("search_targets"), "Ogerpon ability should not expose search target schema"),
		assert_true(productive_interactions.has("basic_energy_from_hand"), "Productive facts should include an executable hand-energy interaction template"),
		assert_false(false_energy_search_future, "Future attack projection must not treat Ogerpon hand-energy ability as a deck Energy search"),
	])


func test_ogerpon_bench_action_is_not_modeled_as_deck_search() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	ogerpon_cd.effect_id = "409898a79b38fe8ca279e7bdaf4fd52e"
	ogerpon_cd.description = "Ability: Teal Dance. Attach a Basic Grass Energy from your hand to this Pokemon. Then draw a card from the top of your deck."
	var ogerpon := CardInstance.create(ogerpon_cd, 0)
	player.hand.append(ogerpon)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_basic_to_bench", "card": ogerpon},
		{"kind": "end_turn"},
	])
	var bench_ref: Dictionary = {}
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "play_basic_to_bench:c0":
			bench_ref = raw
	var rules: Dictionary = bench_ref.get("card_rules", {}) if bench_ref.get("card_rules", {}) is Dictionary else {}
	var tags: Array = rules.get("tags", []) if rules.get("tags", []) is Array else []
	var schema: Dictionary = bench_ref.get("interaction_schema", {}) if bench_ref.get("interaction_schema", {}) is Dictionary else {}
	var future_actions: Array = payload.get("future_actions", []) if payload.get("future_actions", []) is Array else []
	var false_search_future := false
	for raw_future: Variant in future_actions:
		if raw_future is Dictionary:
			var prerequisite_actions: Array = (raw_future as Dictionary).get("prerequisite_actions", []) if (raw_future as Dictionary).get("prerequisite_actions", []) is Array else []
			if prerequisite_actions.has("play_basic_to_bench:c0"):
				false_search_future = true
	return run_checks([
		assert_false(tags.has("search_deck"), "Benching Teal Mask Ogerpon must not be exposed as deck search just because its ability draws from deck top"),
		assert_false(bool(bench_ref.get("requires_interaction", false)), "Benching Teal Mask Ogerpon should be a direct action without search interaction"),
		assert_false(schema.has("search_energy"), "Benching Teal Mask Ogerpon should not expose energy-search schema"),
		assert_false(false_search_future, "Future attack projection must not treat benching Ogerpon as a deterministic Energy search prerequisite"),
	])


func test_llm_queue_controls_ogerpon_hand_energy_choice() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.clear()
	var ogerpon_slot := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon_slot)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(lightning)
	player.hand.append(grass)
	var result: Dictionary = bridge.call("pick_interaction_items", [lightning, grass], {
		"id": "basic_energy_from_hand",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": ogerpon_slot.get_top_card(),
	}, [{
		"type": "use_ability",
		"pokemon": "Teal Mask Ogerpon ex",
		"action_id": "use_ability:bench_0:0",
		"interactions": {"basic_energy_from_hand": "c%d" % int(grass.instance_id)},
	}])
	var picked: Array = result.get("items", [])
	var picked_card: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_true(bool(result.get("has_plan", false)), "Interaction bridge should honor Ogerpon hand-energy interaction intent"),
		assert_eq(picked.size(), 1, "Ogerpon hand-energy step should pick one Energy"),
		assert_true(picked_card == grass, "Ogerpon hand-energy interaction should pick the exact requested Grass card id"),
	])


func test_llm_selection_policy_controls_ogerpon_hand_energy_choice() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210)
	ogerpon_cd.name_en = "Teal Mask Ogerpon ex"
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.clear()
	var ogerpon_slot := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon_slot)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	player.hand.append(lightning)
	player.hand.append(grass)
	var result: Dictionary = bridge.call("pick_interaction_items", [lightning, grass], {
		"id": "basic_energy_from_hand",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": ogerpon_slot.get_top_card(),
	}, [{
		"type": "use_ability",
		"pokemon": "Teal Mask Ogerpon ex",
		"action_id": "use_ability:bench_0:0",
		"selection_policy": {
			"resource": "basic_grass_energy_from_hand",
			"prefer": ["lowest_future_value_energy"],
		},
	}])
	var picked: Array = result.get("items", [])
	var picked_card: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_true(bool(result.get("has_plan", false)), "Selection policy should compile to Ogerpon hand-energy interaction intent"),
		assert_eq(picked.size(), 1, "Selection policy should pick one hand Energy for Ogerpon"),
		assert_true(picked_card == grass, "Selection policy should choose Grass Energy for Ogerpon even without low-level interactions"),
	])


func test_llm_selection_policy_controls_earthen_vessel_search_and_discard() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var grass := CardInstance.create(_make_energy_cd("Basic Grass Energy", "G"), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand.append(vessel)
	player.hand.append(grass)
	var queue := [{
		"type": "play_trainer",
		"card": "Earthen Vessel",
		"action_id": "play_trainer:c%d" % int(vessel.instance_id),
		"selection_policy": {
			"discard": "expendable_energy_or_duplicate_basic",
			"search": ["Fighting Energy"],
		},
	}]
	var discard_result: Dictionary = bridge.call("pick_interaction_items", [grass, lightning], {
		"id": "discard_cards",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	}, queue)
	var search_result: Dictionary = bridge.call("pick_interaction_items", [lightning, fighting], {
		"id": "search_energy",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": vessel,
	}, queue)
	var discarded: Array = discard_result.get("items", [])
	var searched: Array = search_result.get("items", [])
	var searched_card: Variant = searched[0] if not searched.is_empty() else null
	return run_checks([
		assert_true(bool(discard_result.get("has_plan", false)), "Selection policy should compile to Vessel discard intent"),
		assert_true(bool(search_result.get("has_plan", false)), "Selection policy should compile to Vessel search intent"),
		assert_eq(discarded.size(), 1, "Vessel discard policy should choose one card"),
		assert_eq(searched.size(), 1, "Vessel search policy should choose one Energy"),
		assert_true(searched_card == fighting, "Vessel search policy should choose the requested Fighting Energy"),
	])


func test_llm_selection_policy_controls_regidrago_copied_attack_choice() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var regidrago := _make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280)
	regidrago.name_en = "Regidrago VSTAR"
	gs.players[0].active_pokemon = _make_slot(regidrago, 0)
	var goodra_cd := _make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270)
	goodra_cd.name_en = "Hisuian Goodra VSTAR"
	var giratina_cd := _make_pokemon_cd("Giratina VSTAR", "VSTAR", "N", 280)
	giratina_cd.name_en = "Giratina VSTAR"
	var goodra := CardInstance.create(goodra_cd, 0)
	var giratina := CardInstance.create(giratina_cd, 0)
	var goodra_option := {
		"source_card": goodra,
		"attack_index": 0,
		"attack": {"name": "Rolling Iron", "damage": "200"},
	}
	var giratina_option := {
		"source_card": giratina,
		"attack_index": 0,
		"attack": {"name": "Lost Impact", "damage": "280"},
	}
	var result: Dictionary = bridge.call("pick_interaction_items", [goodra_option, giratina_option], {
		"id": "copied_attack",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "attack",
		"pending_effect_card": gs.players[0].active_pokemon.get_top_card(),
	}, [{
		"type": "attack",
		"pokemon": "Regidrago VSTAR",
		"attack_name": "Apex Dragon",
		"action_id": "attack:0:apex dragon",
		"selection_policy": {"attack_name": "Lost Impact"},
	}])
	var picked: Array = result.get("items", [])
	var picked_option: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_true(bool(result.get("has_plan", false)), "Selection policy should compile to Regidrago copied-attack intent"),
		assert_eq(picked.size(), 1, "Copied-attack bridge should pick one attack option"),
		assert_true(picked_option == giratina_option, "Copied-attack bridge should choose the requested Lost Impact option"),
	])


func test_llm_bridge_maps_legacy_regidrago_discard_hint_to_copied_attack_choice() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var regidrago := _make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280)
	regidrago.name_en = "Regidrago VSTAR"
	gs.players[0].active_pokemon = _make_slot(regidrago, 0)
	var goodra_cd := _make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270)
	goodra_cd.name_en = "Hisuian Goodra VSTAR"
	var giratina_cd := _make_pokemon_cd("Giratina VSTAR", "VSTAR", "N", 280)
	giratina_cd.name_en = "Giratina VSTAR"
	var goodra := CardInstance.create(goodra_cd, 0)
	var giratina := CardInstance.create(giratina_cd, 0)
	var goodra_option := {
		"source_card": goodra,
		"attack_index": 0,
		"attack": {"name": "Rolling Iron", "damage": "200"},
	}
	var giratina_option := {
		"source_card": giratina,
		"attack_index": 0,
		"attack": {"name": "Lost Impact", "damage": "280"},
	}
	var result: Dictionary = bridge.call("pick_interaction_items", [goodra_option, giratina_option], {
		"id": "copied_attack",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "attack",
		"pending_effect_card": gs.players[0].active_pokemon.get_top_card(),
	}, [{
		"type": "attack",
		"pokemon": "Regidrago VSTAR",
		"attack_name": "Apex Dragon",
		"action_id": "attack:0:apex dragon",
		"interactions": {"discard_cards": {"items": ["Giratina VSTAR"]}},
	}])
	var picked: Array = result.get("items", [])
	var picked_option: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_true(bool(result.get("has_plan", false)), "Legacy Regidrago discard hint should be interpreted as copied-attack source intent"),
		assert_eq(picked.size(), 1, "Legacy copied-attack bridge should pick one option"),
		assert_true(picked_option == giratina_option, "Legacy copied-attack bridge should choose Giratina VSTAR from the option pool"),
	])


func test_llm_prompt_schema_exposes_regidrago_apex_as_copied_attack() -> String:
	var builder_script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if builder_script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = builder_script.new()
	var schema: Dictionary = builder.call("_interaction_schema_for_ref", {
		"type": "attack",
		"card_rules": {"effect_id": "749d2f12d33057c8cc20e52c1b11bcbf"},
		"attack_rules": {
			"name": "Apex Dragon",
			"text": "Choose an attack from a Dragon Pokemon in your discard pile and use it as this attack.",
			"tags": ["pokemon_related", "discard"],
		},
	})
	return run_checks([
		assert_true(schema.has("copied_attack"), "Regidrago Apex Dragon should expose a copied_attack interaction schema"),
		assert_false(schema.has("discard_cards"), "Regidrago Apex Dragon should not be described as a hand-discard interaction"),
	])


func test_llm_prompt_schema_exposes_chinese_regidrago_apex_as_copied_attack() -> String:
	var builder_script := _load_script(LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH)
	if builder_script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = builder_script.new()
	var schema: Dictionary = builder.call("_interaction_schema_for_ref", {
		"type": "attack",
		"id": "attack:0:巨龙无双",
		"attack_name": "巨龙无双",
		"summary": "attack with 巨龙无双",
		"attack_rules": {
			"name": "巨龙无双",
			"text": "选择自己弃牌区中的【龙】宝可梦所拥有的1个招式，作为这个招式使用。",
			"tags": ["discard", "attack"],
		},
	})
	return run_checks([
		assert_true(schema.has("copied_attack"), "Chinese Regidrago Apex should expose copied_attack in action-id prompts"),
		assert_false(schema.has("discard_cards"), "Chinese Regidrago Apex should not expose discard_cards as if it discarded from hand"),
	])


func test_llm_selection_policy_controls_generic_deck_search_targets() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var iron_bundle := CardInstance.create(_make_pokemon_cd("Iron Bundle", "Basic", "W", 100), 0)
	var raging_bolt := CardInstance.create(_make_raging_bolt_cd(), 0)
	var ogerpon := CardInstance.create(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	player.hand.append(nest)
	player.deck.append(iron_bundle)
	player.deck.append(raging_bolt)
	player.deck.append(ogerpon)
	var result: Dictionary = bridge.call("pick_interaction_items", [iron_bundle, raging_bolt, ogerpon], {
		"id": "search_cards",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": nest,
	}, [{
		"type": "play_trainer",
		"card": "Nest Ball",
		"action_id": "play_trainer:c%d" % int(nest.instance_id),
		"interactions": {
			"search_targets": {"items": ["Raging Bolt ex", "Teal Mask Ogerpon ex"]},
		},
		"selection_policy": {
			"prefer": "Raging Bolt ex",
		},
	}])
	var picked: Array = result.get("items", [])
	var picked_card: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_true(bool(result.get("has_plan", false)), "Generic deck search should honor search_targets/prefer intent from queued LLM routes"),
		assert_eq(picked.size(), 1, "Nest Ball search should pick exactly one Basic Pokemon"),
		assert_true(picked_card == raging_bolt, "Nest Ball should pick the route-critical Raging Bolt instead of the first legal Basic"),
	])


func test_llm_selection_policy_controls_night_stretcher_recovery_choice() -> String:
	var bridge_script := _load_script(LLM_INTERACTION_BRIDGE_SCRIPT_PATH)
	if bridge_script == null:
		return "LLMInteractionIntentBridge.gd should exist"
	var bridge: RefCounted = bridge_script.new()
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var stretcher := CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0)
	var raging_bolt := CardInstance.create(_make_raging_bolt_cd(), 0)
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	player.hand.append(stretcher)
	player.discard_pile.append(raging_bolt)
	player.discard_pile.append(lightning)
	var result: Dictionary = bridge.call("pick_interaction_items", [raging_bolt, lightning], {
		"id": "night_stretcher_choice",
		"max_select": 1,
	}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "trainer",
		"pending_effect_card": stretcher,
	}, [{
		"type": "play_trainer",
		"card": "Night Stretcher",
		"action_id": "play_trainer:c%d" % int(stretcher.instance_id),
		"selection_policy": {
			"recover_target": "Lightning Energy",
		},
	}])
	var picked: Array = result.get("items", [])
	var picked_card: Variant = picked[0] if not picked.is_empty() else null
	return run_checks([
		assert_true(bool(result.get("has_plan", false)), "Selection policy should compile to Night Stretcher recovery intent"),
		assert_eq(picked.size(), 1, "Night Stretcher should pick one recovery target"),
		assert_true(picked_card == lightning, "Night Stretcher should recover the exact requested Energy"),
	])


func test_llm_materialization_preserves_selection_policy() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	player.hand.append(vessel)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": vessel, "targets": [], "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var vessel_id := ""
	for raw: Variant in _current_legal_actions_from_payload(payload):
		if raw is Dictionary and str((raw as Dictionary).get("card", "")) == "Earthen Vessel":
			vessel_id = str((raw as Dictionary).get("id", ""))
	var materialized: Dictionary = strategy.call("_materialize_action_refs_in_tree", {
		"actions": [{
			"id": vessel_id,
			"selection_policy": {
				"discard": "expendable_energy_or_duplicate_basic",
				"search": ["Fighting Energy"],
			},
		}],
	})
	var actions: Array = materialized.get("actions", [])
	var policy: Dictionary = {}
	if not actions.is_empty() and actions[0] is Dictionary:
		policy = (actions[0] as Dictionary).get("selection_policy", {})
	return run_checks([
		assert_false(policy.is_empty(), "Materialized action refs should preserve LLM selection_policy"),
		assert_eq(str(policy.get("discard", "")), "expendable_energy_or_duplicate_basic", "Selection policy discard intent should survive materialization"),
	])


func test_llm_route_candidate_builder_exposes_primary_engine_route() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var ogerpon := {
		"id": "use_ability:bench_0:0",
		"action_id": "use_ability:bench_0:0",
		"type": "use_ability",
		"pokemon": "Teal Mask Ogerpon ex",
		"card_rules": {"tags": ["energy_related", "draw", "charge_engine", "productive_engine"]},
	}
	var vessel := {
		"id": "play_trainer:c52",
		"action_id": "play_trainer:c52",
		"type": "play_trainer",
		"card": "Earthen Vessel",
		"card_rules": {"tags": ["search_deck", "energy_related", "discard", "productive_engine"]},
	}
	var attach := {
		"id": "attach_energy:c25:active",
		"action_id": "attach_energy:c25:active",
		"type": "attach_energy",
		"position": "active",
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var future_attack := {
		"id": "future:attack_after_search_attach:active:1:thundering_bolt",
		"action_id": "future:attack_after_search_attach:active:1:thundering_bolt",
		"type": "attack",
		"future": true,
		"attack_name": "Thundering Bolt",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		"reachable_with_known_resources": true,
	}
	var routes: Array = builder.call("build_candidate_routes", [ogerpon, vessel, attach, end_turn], [future_attack], {
		"primary_attack_reachable_after_visible_engine": true,
		"primary_attack_route": ["energy_search", "manual_attach", "Thundering Bolt"],
	})
	var route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "primary_visible_engine":
			route = raw
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var route_ids: Array[String] = []
	for raw_action: Variant in route_actions:
		if raw_action is Dictionary:
			route_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(route.is_empty(), "Candidate builder should expose a primary visible engine route"),
		assert_eq(str(route.get("route_action_id", "")), "route:primary_visible_engine", "Route should expose a selectable route action id"),
		assert_true(route_ids.has("use_ability:bench_0:0"), "Route should include charge/draw ability before ending"),
		assert_true(route_ids.has("play_trainer:c52"), "Route should include visible energy search"),
		assert_true(route_ids.has("end_turn"), "Setup route should have a terminal end_turn for executor safety"),
	])


func test_llm_route_candidate_attack_now_prefers_primary_attack_over_first_attack() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var weak_attack := {
		"id": "attack:0:gust",
		"action_id": "attack:0:gust",
		"type": "attack",
		"attack_index": 0,
		"attack_name": "Gust",
		"damage": "10",
		"attack_quality": {"role": "chip_damage", "terminal_priority": "medium"},
	}
	var strong_attack := {
		"id": "attack:1:balloon_blast",
		"action_id": "attack:1:balloon_blast",
		"type": "attack",
		"attack_index": 1,
		"attack_name": "Balloon Blast",
		"damage": "120",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	var routes: Array = builder.call("build_candidate_routes", [weak_attack, strong_attack, {"id": "end_turn", "type": "end_turn"}], [], {})
	var attack_route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "attack_now":
			attack_route = raw
			break
	var ids: Array[String] = []
	for raw_action: Variant in attack_route.get("actions", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("id", "")))
	var terminal_id := ids[ids.size() - 1] if not ids.is_empty() else ""
	return run_checks([
		assert_false(attack_route.is_empty(), "Attack-now route should be available when legal attacks exist"),
		assert_eq(terminal_id, "attack:1:balloon_blast", "Attack-now route should choose the high-priority primary attack, not the first listed chip attack"),
	])


func test_llm_route_candidate_attack_now_prefers_damage_counter_scaling_attack() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var slap := {
		"id": "attack:0:巴掌",
		"action_id": "attack:0:巴掌",
		"type": "attack",
		"attack_index": 0,
		"attack_name": "巴掌",
		"damage": "30",
		"attack_quality": {"role": "chip_damage", "terminal_priority": "medium"},
	}
	var roar := {
		"id": "attack:1:凶暴吼叫",
		"action_id": "attack:1:凶暴吼叫",
		"type": "attack",
		"attack_index": 1,
		"attack_name": "凶暴吼叫",
		"damage": "",
		"attack_rules": {
			"name": "凶暴吼叫",
			"text": "给对手的1只宝可梦，造成这只宝可梦身上放置的伤害指示物数量×20伤害。",
			"damage": "",
		},
		"attack_quality": {"role": "utility_attack", "terminal_priority": "medium"},
	}
	var routes: Array = builder.call("build_candidate_routes", [slap, roar, {"id": "end_turn", "type": "end_turn"}], [], {})
	var attack_route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "attack_now":
			attack_route = raw
			break
	var ids: Array[String] = []
	for raw_action: Variant in attack_route.get("actions", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("id", "")))
	var terminal_id := ids[ids.size() - 1] if not ids.is_empty() else ""
	return run_checks([
		assert_eq(terminal_id, "attack:1:凶暴吼叫", "Damage-counter scaling attacks should outrank first-slot chip attacks in attack_now routes"),
	])


func test_llm_route_candidate_primary_engine_excludes_hand_reset_draw() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var iono := {
		"id": "play_trainer:c49",
		"action_id": "play_trainer:c49",
		"type": "play_trainer",
		"card": "Iono",
		"card_rules": {"name_en": "Iono", "tags": ["draw"]},
	}
	var vessel := {
		"id": "play_trainer:c52",
		"action_id": "play_trainer:c52",
		"type": "play_trainer",
		"card": "Earthen Vessel",
		"card_rules": {"name_en": "Earthen Vessel", "tags": ["search_deck", "energy_related", "discard"]},
	}
	var attach := {
		"id": "attach_energy:c16:active",
		"action_id": "attach_energy:c16:active",
		"type": "attach_energy",
		"card": "Lightning Energy",
		"position": "active",
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var future_attack := {
		"id": "future:attack_after_visible_engine:active:1:thundering_bolt",
		"action_id": "future:attack_after_visible_engine:active:1:thundering_bolt",
		"type": "attack",
		"future": true,
		"attack_name": "Thundering Bolt",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	var routes: Array = builder.call("build_candidate_routes", [iono, vessel, attach, end_turn], [future_attack], {
		"primary_attack_reachable_after_visible_engine": true,
		"primary_attack_route": ["energy_search", "manual_attach", "Thundering Bolt"],
		"best_manual_attach_to_primary_attack_action_id": "attach_energy:c16:active",
	})
	var primary_ids: Array[String] = []
	for raw_route: Variant in routes:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route
		if str(route.get("id", "")) != "primary_visible_engine":
			continue
		for raw_action: Variant in route.get("actions", []):
			if raw_action is Dictionary:
				primary_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_true(primary_ids.has("play_trainer:c52"), "Primary route should keep deterministic energy search"),
		assert_true(primary_ids.has("attach_energy:c16:active"), "Primary route should keep the cost-filling manual attach"),
		assert_false(primary_ids.has("play_trainer:c49"), "Primary route must not reset a playable hand with Iono before visible setup"),
	])


func test_llm_route_candidate_builder_treats_pokemon_search_ability_as_setup() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var tandem := {
		"id": "use_ability:active:0",
		"action_id": "use_ability:active:0",
		"type": "use_ability",
		"pokemon": "Miraidon ex",
		"ability": "Tandem Unit",
		"card_rules": {"tags": ["search_deck", "pokemon_related", "bench_related"]},
		"ability_rules": {"tags": ["search_deck", "pokemon_related", "bench_related"]},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [tandem, end_turn], [], {})
	var engine_route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "engine_before_end":
			engine_route = raw
			break
	var route_ids: Array[String] = []
	for raw_action: Variant in engine_route.get("actions", []):
		if raw_action is Dictionary:
			route_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(engine_route.is_empty(), "Pokemon-search abilities should create a productive setup route"),
		assert_true(route_ids.has("use_ability:active:0"), "Tandem Unit should be exposed before end_turn instead of being hidden as a generic ability"),
		assert_true(route_ids.has("end_turn"), "Setup route should still terminate safely"),
	])


func test_llm_route_candidate_builder_demotes_turn_ending_draw_ability() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var rotom := {
		"id": "use_ability:active:0",
		"action_id": "use_ability:active:0",
		"type": "use_ability",
		"pokemon": "Rotom V",
		"ability": "Quick Charge",
		"card_rules": {"effect_id": "8ef5ff61fd97838af568f00fe3b0e3ea", "tags": ["draw", "ability_engine", "ends_turn"]},
		"ability_rules": {"tags": ["draw", "ends_turn"]},
	}
	var poffin := {
		"id": "play_trainer:c12",
		"action_id": "play_trainer:c12",
		"type": "play_trainer",
		"card": "Buddy-Buddy Poffin",
		"card_rules": {"tags": ["search_deck", "bench_related", "pokemon_related"]},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [rotom, poffin, end_turn], [], {})
	var engine_route: Dictionary = {}
	var terminal_route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary:
			var route := raw as Dictionary
			if str(route.get("id", "")) == "engine_before_end":
				engine_route = route
			if str(route.get("id", "")) == "terminal_draw_fallback":
				terminal_route = route
	var engine_ids: Array[String] = []
	for raw_action: Variant in engine_route.get("actions", []):
		if raw_action is Dictionary:
			engine_ids.append(str((raw_action as Dictionary).get("id", "")))
	var terminal_actions: Array = terminal_route.get("actions", []) if terminal_route.get("actions", []) is Array else []
	var first_terminal: Dictionary = terminal_actions[0] if not terminal_actions.is_empty() and terminal_actions[0] is Dictionary else {}
	return run_checks([
		assert_false(engine_ids.has("use_ability:active:0"), "Turn-ending draw ability must not be treated as a productive engine action"),
		assert_true(engine_ids.has("play_trainer:c12"), "Non-terminal setup search should remain a productive engine action"),
		assert_false(terminal_route.is_empty(), "Turn-ending draw ability should still be exposed as a low-priority fallback route"),
		assert_eq(str(first_terminal.get("id", "")), "use_ability:active:0", "Fallback route should contain the terminal draw ability"),
	])


func test_llm_route_candidate_builder_exposes_manual_attach_to_attack_route() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var attach := {
		"id": "attach_energy:c44:active",
		"action_id": "attach_energy:c44:active",
		"type": "attach_energy",
		"card": "Fighting Energy",
		"energy_type": "Fighting",
		"position": "active",
	}
	var low_attack := {
		"id": "attack:0:bursting_roar",
		"action_id": "attack:0:bursting_roar",
		"type": "attack",
		"attack_name": "Bursting Roar",
		"attack_index": 0,
		"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var future_attack := {
		"id": "future:attack_after_attach:active:1:thundering_bolt",
		"action_id": "future:attack_after_attach:active:1:thundering_bolt",
		"type": "attack",
		"future": true,
		"attack_name": "Thundering Bolt",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		"prerequisite": "manual_attach_to_active",
		"reachable_with_known_resources": true,
	}
	var routes: Array = builder.call("build_candidate_routes", [attach, low_attack, end_turn], [future_attack], {
		"only_ready_attack_is_low_value_redraw": true,
		"primary_attack_reachable_after_manual_attach": true,
		"best_manual_attach_to_primary_attack_action_id": "attach_energy:c44:active",
		"primary_attack_route": ["manual_attach", "Thundering Bolt"],
	})
	var attach_route: Dictionary = {}
	var attack_now_seen := false
	for raw: Variant in routes:
		if raw is Dictionary:
			var route := raw as Dictionary
			if str(route.get("id", "")) == "manual_attach_to_attack":
				attach_route = route
			if str(route.get("id", "")) == "attack_now":
				attack_now_seen = true
	var route_actions: Array = attach_route.get("actions", []) if attach_route.get("actions", []) is Array else []
	var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	var route_action_ids: Array[String] = []
	for raw_action: Variant in route_actions:
		if raw_action is Dictionary:
			route_action_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(attach_route.is_empty(), "Candidate builder should expose direct manual attach into primary attack"),
		assert_eq(str(attach_route.get("route_action_id", "")), "route:manual_attach_to_attack", "Manual attach route should be selectable by route_action_id"),
		assert_eq(str(first_action.get("id", "")), "attach_energy:c44:active", "Manual attach attack route should start with the exact cost-filling attach id"),
		assert_true(route_action_ids.has("future:attack_after_attach:active:1:thundering_bolt"), "Manual attach attack route should close with the resulting future primary attack, not only end_turn"),
		assert_eq(route_action_ids[route_action_ids.size() - 1], "end_turn", "Manual attach attack route should keep terminal end_turn as executor safety after the future attack goal"),
		assert_false(attack_now_seen, "Low-value redraw attack-now route should not outrank a direct primary attach route"),
	])


func test_llm_route_candidate_builder_adds_basic_before_attack_when_bench_empty() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var bench_basic := {
		"id": "play_basic_to_bench:c58",
		"action_id": "play_basic_to_bench:c58",
		"type": "play_basic_to_bench",
		"card": "Raging Bolt ex",
	}
	var attack := {
		"id": "attack:1:Thundering Bolt",
		"action_id": "attack:1:Thundering Bolt",
		"type": "attack",
		"attack_name": "Thundering Bolt",
		"attack_index": 1,
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [bench_basic, attack, end_turn], [], {
		"own_bench_count": 0,
	})
	var attack_route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "attack_now":
			attack_route = raw
			break
	var ids: Array[String] = []
	for raw_action: Variant in attack_route.get("actions", []):
		if raw_action is Dictionary:
			ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(attack_route.is_empty(), "Attack route should still exist"),
		assert_eq(ids[0], "play_basic_to_bench:c58", "When the bench is empty, attack routes should bench a Basic before attacking to avoid no-Basic loss"),
		assert_eq(ids[1], "attack:1:Thundering Bolt", "Attack should remain terminal after the survival bench action"),
	])


func test_llm_route_candidate_builder_prefers_deterministic_gust_over_coin_flip_catcher() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var catcher := {
		"id": "play_trainer:c8",
		"action_id": "play_trainer:c8",
		"type": "play_trainer",
		"card": "Pokemon Catcher",
		"card_rules": {"name_en": "Pokemon Catcher", "effect_id": "3a6d419769778b40091e69fbd76737ec", "tags": ["gust"]},
	}
	var boss := {
		"id": "play_trainer:c41",
		"action_id": "play_trainer:c41",
		"type": "play_trainer",
		"card": "Boss's Orders",
		"card_rules": {"name_en": "Boss's Orders", "effect_id": "8e1fa2c9018db938084c94c7c970d419", "tags": ["gust"]},
	}
	var attack := {
		"id": "attack:1:Thundering Bolt",
		"action_id": "attack:1:Thundering Bolt",
		"type": "attack",
		"attack_name": "Thundering Bolt",
		"attack_index": 1,
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [catcher, boss, attack, end_turn], [], {
		"gust_ko_opportunities": [
			{
				"gust_action_id": "play_trainer:c8",
				"attack_action_id": "attack:1:Thundering Bolt",
				"gust_reliability": "coin_flip",
				"gust_deterministic": false,
				"target_position": "bench_3",
				"target_name": "Mew ex",
				"target_hp_remaining": 60,
				"target_prize_count": 2,
				"game_winning": true,
			},
			{
				"gust_action_id": "play_trainer:c41",
				"attack_action_id": "attack:1:Thundering Bolt",
				"gust_reliability": "deterministic",
				"gust_deterministic": true,
				"target_position": "bench_3",
				"target_name": "Mew ex",
				"target_hp_remaining": 60,
				"target_prize_count": 2,
				"game_winning": true,
			},
		],
	})
	var gust_route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "gust_ko":
			gust_route = raw
			break
	var route_actions: Array = gust_route.get("actions", []) if gust_route.get("actions", []) is Array else []
	var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	return run_checks([
		assert_false(gust_route.is_empty(), "Candidate builder should expose a gust KO route"),
		assert_eq(str(first_action.get("id", "")), "play_trainer:c41", "Deterministic Boss gust should outrank coin-flip Pokemon Catcher for the same KO"),
		assert_true(bool(first_action.get("gust_deterministic", false)), "Route action should preserve deterministic gust metadata for prompt/runtime repair"),
		assert_eq(int(gust_route.get("priority", 0)), 990, "Deterministic gust KO routes should remain hard-preference candidates"),
	])


func test_llm_route_candidate_builder_exposes_defensive_gust_stall_route() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var boss := {
		"id": "play_trainer:c41",
		"action_id": "play_trainer:c41",
		"type": "play_trainer",
		"card": "Boss's Orders",
		"card_rules": {"name_en": "Boss's Orders", "effect_id": "8e1fa2c9018db938084c94c7c970d419", "tags": ["gust"]},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [boss, end_turn], [], {
		"defensive_gust_opportunities": [{
			"gust_action_id": "play_trainer:c41",
			"target_position": "bench_2",
			"target_name": "Iron Hands ex",
			"opponent_active_name": "Raikou V",
			"selection_policy": {
				"opponent_bench_target": "bench_2",
			},
		}],
	})
	var route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "defensive_gust_stall":
			route = raw
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	return run_checks([
		assert_false(route.is_empty(), "Candidate builder should expose a defensive gust route when no attack route is available"),
		assert_eq(str(first_action.get("id", "")), "play_trainer:c41", "Defensive gust route should use the deterministic gust action"),
		assert_eq(str(first_action.get("capability", "")), "defensive_gust", "Defensive gust should survive route compilation without requiring an attack goal"),
		assert_eq(int(route.get("priority", 0)), 975, "Defensive gust should be strong enough for hard route repair when it is generated"),
	])


func test_llm_route_candidate_builder_suppresses_low_value_attack_when_productive_setup_exists() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var low_attack := {
		"id": "attack:0:bursting_roar",
		"action_id": "attack:0:bursting_roar",
		"type": "attack",
		"attack_name": "Bursting Roar",
		"attack_index": 0,
		"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
	}
	var vessel := {
		"id": "play_trainer:c52",
		"action_id": "play_trainer:c52",
		"type": "play_trainer",
		"card": "Earthen Vessel",
		"card_rules": {"tags": ["search_deck", "energy_related", "discard", "productive_engine"]},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [low_attack, vessel, end_turn], [], {
		"only_ready_attack_is_low_value_redraw": true,
	})
	var saw_attack_now := false
	var saw_engine_route := false
	for raw: Variant in routes:
		if raw is Dictionary:
			var route := raw as Dictionary
			saw_attack_now = saw_attack_now or str(route.get("id", "")) == "attack_now"
			saw_engine_route = saw_engine_route or str(route.get("id", "")) == "engine_before_end"
	return run_checks([
		assert_false(saw_attack_now, "Candidate builder must not expose low-value redraw attack-now when productive setup exists"),
		assert_true(saw_engine_route, "Productive setup route should remain available after suppressing redraw attack"),
	])


func test_llm_route_candidate_builder_suppresses_low_value_attack_when_deck_draw_is_risky() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var low_attack := {
		"id": "attack:0:bursting_roar",
		"action_id": "attack:0:bursting_roar",
		"type": "attack",
		"attack_name": "Bursting Roar",
		"attack_index": 0,
		"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
	}
	var end_turn := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
	var routes: Array = builder.call("build_candidate_routes", [low_attack, end_turn], [], {
		"deck_draw_risk": true,
	})
	var saw_attack_now := false
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "attack_now":
			saw_attack_now = true
	return assert_false(saw_attack_now, "Low-deck candidate builder must not offer redraw attack-now even when no other route exists")


func test_llm_route_candidate_builder_exposes_generic_active_attach_attack_route() -> String:
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
			"attack_name": "Myriad Leaf Shower",
			"attack_index": 0,
			"estimated_damage_after_best_manual_attach": 360,
			"kos_opponent_active_after_best_manual_attach": true,
			"attack_quality": {"role": "chip_damage", "terminal_priority": "medium"},
		},
	})
	var route: Dictionary = {}
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "manual_attach_to_active_attack":
			route = raw
			break
	var route_actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var goals: Array = route.get("future_goals", []) if route.get("future_goals", []) is Array else []
	var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
	var first_goal: Dictionary = goals[0] if not goals.is_empty() and goals[0] is Dictionary else {}
	return run_checks([
		assert_false(route.is_empty(), "Candidate builder should expose generic active manual attach attack route"),
		assert_eq(str(route.get("route_action_id", "")), "route:manual_attach_to_active_attack", "Generic active attack route should be selectable"),
		assert_eq(str(first_action.get("id", "")), "attach_energy:c21:active", "Generic route should start with the exact cost-filling attach"),
		assert_true(bool(first_goal.get("kos_opponent_active", false)), "Route goal should preserve the active KO projection"),
	])


func test_llm_route_candidate_builder_exposes_pivot_attack_route() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var current_actions: Array[Dictionary] = [
		{
			"id": "use_ability:bench_4:0",
			"action_id": "use_ability:bench_4:0",
			"type": "use_ability",
			"pokemon": "Localized Ogerpon",
			"card_rules": {"name_en": "Teal Mask Ogerpon ex", "tags": ["energy_related", "draw", "charge_engine"]},
		},
		{
			"id": "attach_energy:c43:bench_1",
			"action_id": "attach_energy:c43:bench_1",
			"type": "attach_energy",
			"card": "Fighting Energy",
			"energy_type": "Fighting",
			"position": "bench_1",
			"target": "Raging Bolt ex",
		},
		{
			"id": "retreat:bench_1:c21",
			"action_id": "retreat:bench_1:c21",
			"type": "retreat",
			"bench_position": "bench_1",
			"bench_target": "Raging Bolt ex",
		},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var future_actions: Array[Dictionary] = [
		{
			"id": "future:attack_after_pivot:bench_1:1:thundering_bolt",
			"action_id": "future:attack_after_pivot:bench_1:1:thundering_bolt",
			"type": "attack",
			"future": true,
			"prerequisite": "pivot_to_bench_attacker",
			"position": "bench_1",
			"attack_name": "Thundering Bolt",
			"reachable_with_known_resources": true,
			"best_manual_attach_energy": "Fighting",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		},
	]
	var routes: Array = builder.call("build_candidate_routes", current_actions, future_actions, {
		"no_deck_draw_lock": false,
		"safe_pre_primary_actions": [{"id": "use_ability:bench_4:0"}],
	})
	var route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("id", "")) == "pivot_to_primary_attack":
			route = raw_route
			break
	var action_ids: Array[String] = []
	for raw_action: Variant in route.get("actions", []):
		if raw_action is Dictionary:
			action_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(route.is_empty(), "Candidate builder should expose a same-turn pivot-to-attack route"),
		assert_true(action_ids.has("use_ability:bench_4:0"), "Pivot attack route should keep safe pre-primary charge actions"),
		assert_true(action_ids.has("attach_energy:c43:bench_1"), "Pivot attack route should attach the missing Energy to the bench attacker"),
		assert_true(action_ids.has("retreat:bench_1:c21"), "Pivot attack route should include the exact pivot action"),
		assert_true(action_ids.has("end_turn"), "Pivot attack route should close with end_turn so runtime can replace it with the now-legal attack"),
	])


func test_llm_route_candidate_builder_prefers_attack_cost_energy_for_setup_attach() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var current_actions: Array[Dictionary] = [
		{
			"id": "attach_energy:c10:active",
			"action_id": "attach_energy:c10:active",
			"type": "attach_energy",
			"card": "Grass Energy",
			"energy_type": "Grass",
			"position": "active",
			"target": "Raging Bolt ex",
		},
		{
			"id": "attach_energy:c11:active",
			"action_id": "attach_energy:c11:active",
			"type": "attach_energy",
			"card": "Lightning Energy",
			"energy_type": "Lightning",
			"position": "active",
			"target": "Raging Bolt ex",
		},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var routes: Array = builder.call("build_candidate_routes", current_actions, [], {
		"primary_attack_missing_cost": ["Lightning", "Fighting"],
	})
	var setup_route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("id", "")) == "manual_attach_setup":
			setup_route = raw_route
			break
	var action_ids: Array[String] = []
	for raw_action: Variant in setup_route.get("actions", []):
		if raw_action is Dictionary:
			action_ids.append(str((raw_action as Dictionary).get("id", "")))
	return run_checks([
		assert_false(setup_route.is_empty(), "Manual attach setup route should be exposed when attach actions exist"),
		assert_eq(action_ids[0], "attach_energy:c11:active", "Setup attach should prefer Energy that reduces the primary attack cost over off-plan Energy"),
	])


func test_llm_route_candidate_builder_skips_off_cost_active_setup_attach_when_primary_needs_specific_energy() -> String:
	var builder := _new_route_candidate_builder()
	if builder == null:
		return "LLMRouteCandidateBuilder.gd should exist"
	var current_actions: Array[Dictionary] = [
		{
			"id": "attach_energy:c10:active",
			"action_id": "attach_energy:c10:active",
			"type": "attach_energy",
			"card": "Grass Energy",
			"energy_type": "Grass",
			"position": "active",
			"target": "Raging Bolt ex",
		},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	var routes: Array = builder.call("build_candidate_routes", current_actions, [], {
		"primary_attack_missing_cost": ["Lightning", "Fighting"],
	})
	var saw_setup_route := false
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("id", "")) == "manual_attach_setup":
			saw_setup_route = true
			break
	return assert_false(
		saw_setup_route,
		"Manual attach setup route must not expose off-cost active attach when the primary attack still needs specific Energy"
	)


