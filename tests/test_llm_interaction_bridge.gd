class_name TestLLMInteractionBridge
extends TestBase

const RAGING_BOLT_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRagingBoltLLM.gd"
const DRAGAPULT_CHARIZARD_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd"
const MIRAIDON_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyMiraidonLLM.gd"
const LUGIA_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd"
const LLM_DECK_STRATEGY_BASE_SCRIPT_PATH := "res://scripts/ai/LLMDeckStrategyBase.gd"
const LLM_INTERACTION_BRIDGE_SCRIPT_PATH := "res://scripts/ai/LLMInteractionIntentBridge.gd"
const LLM_DECISION_TREE_EXECUTOR_SCRIPT_PATH := "res://scripts/ai/LLMDecisionTreeExecutor.gd"
const LLM_DECK_CAPABILITY_EXTRACTOR_SCRIPT_PATH := "res://scripts/ai/LLMDeckCapabilityExtractor.gd"
const LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMTurnPlanPromptBuilder.gd"
const LLM_ROUTE_COMPILER_SCRIPT_PATH := "res://scripts/ai/LLMRouteCompiler.gd"
const LLM_ROUTE_CANDIDATE_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMRouteCandidateBuilder.gd"
const LLM_ROUTE_ACTION_REGISTRY_SCRIPT_PATH := "res://scripts/ai/LLMRouteActionRegistry.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _make_pokemon_cd(pname: String, stage: String = "Basic", energy_type: String = "C", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	return cd


func _make_raging_bolt_cd() -> CardData:
	var cd := _make_pokemon_cd("Raging Bolt ex", "Basic", "L", 240)
	cd.name_en = "Raging Bolt ex"
	cd.mechanic = "ex"
	cd.is_tags = ["Ancient"]
	cd.attacks = [
		{"name": "Bursting Roar", "cost": "C", "damage": ""},
		{"name": "Thundering Bolt", "cost": "LF", "damage": "70x"},
	]
	return cd


func _make_miraidon_cd() -> CardData:
	var cd := _make_pokemon_cd("Miraidon ex", "Basic", "L", 220)
	cd.name_en = "Miraidon ex"
	cd.mechanic = "ex"
	cd.attacks = [
		{"name": "Tandem Unit", "cost": "", "damage": ""},
		{"name": "Photon Blaster", "cost": "LLC", "damage": "220"},
	]
	return cd


func _make_lugia_v_cd() -> CardData:
	var cd := _make_pokemon_cd("Lugia V", "Basic", "C", 220)
	cd.name_en = "Lugia V"
	cd.mechanic = "V"
	cd.attacks = [
		{"name": "Read the Wind", "cost": "C", "damage": ""},
		{"name": "Aero Dive", "cost": "CCCC", "damage": "130"},
	]
	return cd


func _make_lugia_vstar_cd() -> CardData:
	var cd := _make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280)
	cd.name_en = "Lugia VSTAR"
	cd.mechanic = "VSTAR"
	cd.abilities = [{"name": "Summoning Star", "text": "Put up to 2 Colorless Pokemon from your discard pile onto your Bench."}]
	cd.attacks = [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
	return cd


func _make_archeops_cd() -> CardData:
	var cd := _make_pokemon_cd("Archeops", "Stage2", "C", 150)
	cd.name_en = "Archeops"
	cd.abilities = [{"name": "Primal Turbo", "text": "Search your deck for up to 2 Special Energy cards and attach them to 1 of your Pokemon."}]
	return cd


func _make_minccino_cd() -> CardData:
	var cd := _make_pokemon_cd("Minccino", "Basic", "C", 70)
	cd.name_en = "Minccino"
	return cd


func _make_cinccino_cd() -> CardData:
	var cd := _make_pokemon_cd("Cinccino", "Stage1", "C", 110)
	cd.name_en = "Cinccino"
	cd.attacks = [{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.description = "%s rule text" % pname
	return cd


func _make_named_trainer_cd(pname: String, name_en: String, card_type: String = "Item") -> CardData:
	var cd := _make_trainer_cd(pname, card_type)
	cd.name_en = name_en
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_game_state(turn: int = 3) -> GameState:
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % player_index), player_index)
		gs.players.append(player)
	return gs


func _fill_player_deck(player: PlayerState, count: int = 30) -> void:
	if player == null:
		return
	for i: int in count:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), player.player_index))


func _set_prizes_remaining(player: PlayerState, count: int) -> void:
	if player == null:
		return
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize filler %d" % i), player.player_index))


func _new_llm_strategy() -> RefCounted:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_dragapult_charizard_llm_strategy() -> RefCounted:
	var script := _load_script(DRAGAPULT_CHARIZARD_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_miraidon_llm_strategy() -> RefCounted:
	var script := _load_script(MIRAIDON_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_lugia_llm_strategy() -> RefCounted:
	var script := _load_script(LUGIA_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_route_compiler() -> RefCounted:
	var script := _load_script(LLM_ROUTE_COMPILER_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_route_candidate_builder() -> RefCounted:
	var script := _load_script(LLM_ROUTE_CANDIDATE_BUILDER_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_route_action_registry() -> RefCounted:
	var script := _load_script(LLM_ROUTE_ACTION_REGISTRY_SCRIPT_PATH)
	return script.new() if script != null else null


func _current_legal_actions_from_payload(payload: Dictionary) -> Array:
	var result: Array = []
	for raw: Variant in payload.get("legal_actions", []):
		if not (raw is Dictionary):
			continue
		if bool((raw as Dictionary).get("future", false)):
			continue
		result.append(raw)
	return result


func _inject_llm_queue(strategy: RefCounted, turn: int, actions: Array) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"actions": actions, "reasoning": "test"}
	strategy.call("_on_llm_response", mock_response, turn)


func _inject_llm_tree(strategy: RefCounted, turn: int, decision_tree: Dictionary) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"decision_tree": decision_tree, "reasoning": "tree test"}
	strategy.call("_on_llm_response", mock_response, turn)


func _unique_count_for_test(values: Array) -> int:
	var seen := {}
	for raw: Variant in values:
		seen[str(raw)] = true
	return seen.size()


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
	return run_checks([
		assert_false(attach_route.is_empty(), "Candidate builder should expose direct manual attach into primary attack"),
		assert_eq(str(attach_route.get("route_action_id", "")), "route:manual_attach_to_attack", "Manual attach route should be selectable by route_action_id"),
		assert_eq(str(first_action.get("id", "")), "attach_energy:c44:active", "Manual attach attack route should start with the exact cost-filling attach id"),
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
		assert_eq(int(stats.get("failures", -1)), 0, "Candidate route fallback should not count as a runtime failure when it produces a usable plan"),
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

