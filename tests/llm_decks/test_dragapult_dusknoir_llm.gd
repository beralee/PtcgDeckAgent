class_name TestDragapultDusknoirLLM
extends TestBase

const RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultDusknoir.gd"
const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd"
const RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"
const RouteBuilderScript = preload("res://scripts/ai/LLMRouteCandidateBuilder.gd")
const PromptBuilderScript = preload("res://scripts/ai/LLMTurnPlanPromptBuilder.gd")


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy(script_path: String) -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(script_path)
	return script.new() if script != null else null


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
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_energy_cd(pname: String, provides: String) -> CardData:
	var cd := _make_trainer_cd(pname, "Basic Energy")
	cd.energy_provides = provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = pi
	return player


func _make_game_state(turn: int = 3) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := _make_player(pi)
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Basic", "C", 100), pi)
		gs.players.append(player)
	return gs


func _activate_llm_end_turn_queue(strategy: RefCounted, turn: int) -> void:
	var end_queued := {"action_id": "end_turn", "id": "end_turn", "type": "end_turn"}
	_activate_llm_queue(strategy, turn, [end_queued])


func _activate_llm_queue(strategy: RefCounted, turn: int, queued_actions: Array) -> void:
	var catalog := {}
	for action: Dictionary in queued_actions:
		var action_id := str(action.get("id", action.get("action_id", "")))
		if action_id != "":
			catalog[action_id] = action
	strategy.set("_llm_queue_turn", turn)
	strategy.set("_llm_decision_tree", {"actions": queued_actions})
	strategy.set("_llm_action_queue", queued_actions)
	strategy.set("_llm_action_catalog", catalog)


func _attached_energy(name: String, provides: String) -> CardInstance:
	return CardInstance.create(_make_energy_cd(name, provides), 0)


func _set_prize_count(player: PlayerState, count: int, owner: int = 0) -> void:
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i), owner))


func _make_dragapult_ex_cd() -> CardData:
	return _make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"N",
		320,
		"Drakloak",
		"ex",
		[],
		[
			{"name": "Jet Head", "cost": "C", "damage": "70"},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
		]
	)


func test_script_loads_and_reports_stable_strategy_id() -> String:
	var runtime_script := _load_script(RUNTIME_SCRIPT_PATH)
	var rules_script := _load_script(RULES_SCRIPT_PATH)
	var llm_script := _load_script(LLM_SCRIPT_PATH)
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var source := FileAccess.get_file_as_string(LLM_SCRIPT_PATH)
	return run_checks([
		assert_not_null(runtime_script, "DeckStrategyLLMRuntimeBase.gd should load"),
		assert_not_null(rules_script, "DeckStrategyDragapultDusknoir.gd should load"),
		assert_not_null(llm_script, "DeckStrategyDragapultDusknoirLLM.gd should load"),
		assert_not_null(llm_instance, "DeckStrategyDragapultDusknoirLLM.gd should instantiate"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null else "", "dragapult_dusknoir_llm", "LLM wrapper should report the target strategy id"),
		assert_true(source.contains("DeckStrategyLLMRuntimeBase.gd"), "Wrapper should extend the generic LLM runtime"),
		assert_true(source.contains("DeckStrategyDragapultDusknoir.gd"), "Wrapper should compose the rules strategy"),
	])


func test_rules_fallback_delegates_opening_and_action_scores() -> String:
	var rules := _new_strategy(RULES_SCRIPT_PATH)
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if rules == null or llm == null:
		return "Rules and LLM strategies should instantiate"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var rules_setup: Dictionary = rules.call("plan_opening_setup", player)
	var llm_setup: Dictionary = llm.call("plan_opening_setup", player)
	var gs := _make_game_state(3)
	var action := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Rare Candy"), 0)}
	var rules_score: float = float(rules.call("score_action_absolute", action, gs, 0))
	var llm_score: float = float(llm.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_eq(llm_setup, rules_setup, "LLM wrapper should delegate opening setup to rules fallback"),
		assert_eq(llm_score, rules_score, "LLM wrapper should delegate ordinary action scores when no LLM plan is active"),
	])


func test_prompt_and_setup_hooks_cover_dragapult_dusknoir_plan() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	llm.call("set_deck_strategy_text", "custom player note: keep Dragapult pressure before spending Dusknoir")
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var payload: Dictionary = llm.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	var dreepy_hint := str(llm.call("get_llm_setup_role_hint", _make_pokemon_cd("Dreepy", "Basic", "P", 70)))
	var dusknoir_hint := str(llm.call("get_llm_setup_role_hint", _make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops")))
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "dragapult_dusknoir_llm", "Payload should identify the Dragapult Dusknoir LLM strategy"),
		assert_true(prompt_lines.size() >= 10, "Prompt should provide deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "Dreepy -> Drakloak -> Dragapult ex", "Prompt should cover the main Stage 2 setup line"),
		assert_str_contains(prompt_text, "Dusknoir", "Prompt should cover the Dusknoir conversion lane"),
		assert_str_contains(prompt_text, "Spread targeting policy", "Prompt should include spread target policy"),
		assert_str_contains(prompt_text, "self-KO", "Prompt should gate Dusknoir self-KO conversion"),
		assert_str_contains(prompt_text, "Technical Machine: Devolution", "Prompt should cover TM lines for Arven searches"),
		assert_str_contains(prompt_text, "custom player note", "Prompt should include editable strategy text"),
		assert_str_contains(dreepy_hint, "priority opener", "Dreepy setup hint should mark the main opener role"),
		assert_str_contains(dusknoir_hint, "self-KO conversion", "Dusknoir setup hint should warn about conversion gating"),
	])


func test_stage2_setup_intent_delegates_rules_turn_plan() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	var plan: Dictionary = llm.call("build_turn_plan", gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = plan.get("flags", {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "force_first_dragapult", "LLM wrapper should preserve rules intent to force the first Dragapult ex"),
		assert_true(bool(flags.get("shell_ready", false)), "Rules setup facts should survive wrapper delegation"),
	])


func test_spread_target_policy_prefers_damaged_bench_prize_map() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var opponent: PlayerState = gs.players[1]
	var damaged_two_prizer := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	damaged_two_prizer.damage_counters = 150
	var healthy_basic := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 1)
	opponent.bench.clear()
	opponent.bench.append(damaged_two_prizer)
	opponent.bench.append(healthy_basic)
	var damaged_score: float = float(llm.call("score_interaction_target", damaged_two_prizer, {"id": "bench_damage_counters"}, {"game_state": gs, "player_index": 0}))
	var healthy_score: float = float(llm.call("score_interaction_target", healthy_basic, {"id": "bench_damage_counters"}, {"game_state": gs, "player_index": 0}))
	var picked: Array = llm.call("pick_interaction_items", [healthy_basic, damaged_two_prizer], {"id": "bench_damage_counters", "max_select": 1}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(damaged_score > healthy_score, "Spread counter scoring should prefer a damaged multi-prize bench conversion target"),
		assert_true(picked.size() == 1 and picked[0] == damaged_two_prizer, "Spread counter fallback should pick the conversion target from actual options"),
	])


func test_spread_target_policy_marks_loaded_followup_attacker_for_next_phantom_dive_ko() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	var opponent: PlayerState = gs.players[1]
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	iron_hands.attached_energy.append(_attached_energy("Double Turbo Energy", "C"))
	var squawkabilly := _make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(squawkabilly)
	opponent.bench.append(iron_hands)
	var context := {"game_state": gs, "player_index": 0}
	var iron_score: float = float(llm.call("score_interaction_target", iron_hands, {"id": "bench_damage_counters"}, context))
	var squawk_score: float = float(llm.call("score_interaction_target", squawkabilly, {"id": "bench_damage_counters"}, context))
	var picked: Array = llm.call("pick_interaction_items", [squawkabilly, iron_hands], {"id": "bench_damage_counters", "max_select": 1}, context)
	return run_checks([
		assert_true(iron_score > squawk_score, "Phantom Dive spread should pre-mark a loaded 230 HP follow-up attacker so the next 200 damage attack can KO it"),
		assert_true(picked.size() == 1 and picked[0] == iron_hands, "Spread counter fallback should choose the loaded follow-up attacker over a low-impact support ex"),
	])


func test_dusknoir_self_ko_target_selection_prefers_high_value_conversion() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	var dusknoir := _make_slot(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops", "", [{"name": "Cursed Blast"}]), 0)
	player.active_pokemon = dragapult
	player.bench.clear()
	player.bench.append(dusknoir)
	var opponent: PlayerState = gs.players[1]
	var low_prize_active := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 1)
	low_prize_active.damage_counters = 20
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	iron_hands.damage_counters = 120
	var low_prize_bench := _make_slot(_make_pokemon_cd("Tynamo", "Basic", "L", 40), 1)
	opponent.active_pokemon = low_prize_active
	opponent.bench.clear()
	opponent.bench.append(low_prize_bench)
	opponent.bench.append(iron_hands)
	var context := {"game_state": gs, "player_index": 0, "source_slot": dusknoir}
	var iron_score: float = float(llm.call("score_interaction_target", iron_hands, {"id": "self_ko_target"}, context))
	var low_score: float = float(llm.call("score_interaction_target", low_prize_active, {"id": "self_ko_target"}, context))
	var picked: Array = llm.call("pick_interaction_items", [low_prize_active, low_prize_bench, iron_hands], {"id": "self_ko_target", "max_select": 1}, context)
	return run_checks([
		assert_true(iron_score > low_score, "Dusknoir self-KO target scoring should prefer a damaged two-prize conversion"),
		assert_true(picked.size() == 1 and picked[0] == iron_hands, "Dusknoir self-KO fallback should pick the high-value target from actual options"),
	])


func test_dusknoir_self_ko_conversion_gating_blocks_empty_damage_plan() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var dusknoir := _make_slot(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops", "", [{"name": "Cursed Blast"}]), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.clear()
	player.bench.append(dusknoir)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	var action := {"kind": "use_ability", "source_slot": dusknoir, "ability_index": 0}
	var blocked_without_conversion := bool(llm.call("_deck_should_block_exact_queue_match", action, action, gs, 0))
	opponent.active_pokemon.damage_counters = 100
	var blocked_with_conversion := bool(llm.call("_deck_should_block_exact_queue_match", action, action, gs, 0))
	var dusclops := _make_slot(_make_pokemon_cd("Dusclops", "Stage 1", "P", 90, "Duskull", "", [{"name": "Cursed Blast"}]), 0)
	var dusclops_action := {"kind": "use_ability", "source_slot": dusclops, "ability_index": 0}
	var blocked_dusclops_against_120_hp := bool(llm.call("_deck_should_block_exact_queue_match", dusclops_action, dusclops_action, gs, 0))
	return run_checks([
		assert_true(blocked_without_conversion, "Dusknoir self-KO ability should be blocked when no prize conversion exists"),
		assert_false(blocked_with_conversion, "Dusknoir self-KO ability should be allowed when damage creates a clear active KO conversion"),
		assert_true(blocked_dusclops_against_120_hp, "Dusclops self-KO should stay blocked when 50 counters do not create the same KO conversion"),
	])


func test_active_llm_queue_blocks_bad_dragapult_dusknoir_escape_actions() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var dusclops := _make_slot(_make_pokemon_cd("Dusclops", "Stage 1", "P", 90, "Duskull", "", [{"name": "Cursed Blast"}]), 0)
	var fezandipiti := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.active_pokemon = dreepy
	player.bench.clear()
	player.bench.append(dusclops)
	player.bench.append(fezandipiti)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	_activate_llm_end_turn_queue(llm, int(gs.turn_number))
	var dusclops_action := {"kind": "use_ability", "source_slot": dusclops, "ability_index": 0}
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var bad_energy := {"kind": "attach_energy", "card": fire, "target_slot": dusclops}
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var bad_crystal := {"kind": "attach_tool", "card": crystal, "target_slot": fezandipiti}
	var good_crystal := {"kind": "attach_tool", "card": crystal, "target_slot": dreepy}
	var dusclops_score: float = float(llm.call("score_action_absolute", dusclops_action, gs, 0))
	var bad_energy_score: float = float(llm.call("score_action_absolute", bad_energy, gs, 0))
	var bad_crystal_score: float = float(llm.call("score_action_absolute", bad_crystal, gs, 0))
	var good_crystal_score: float = float(llm.call("score_action_absolute", good_crystal, gs, 0))
	return run_checks([
		assert_true(dusclops_score <= -1000.0, "Active LLM plan should not let rules escape into non-converting Dusclops self-KO"),
		assert_true(bad_energy_score <= -1000.0, "Active LLM plan should block Fire/Psychic attachments to the Dusknoir line while Dragapult is available"),
		assert_true(bad_crystal_score <= -1000.0, "Active LLM plan should block Sparkling Crystal on non-Dragapult support targets"),
		assert_true(good_crystal_score > -1000.0, "Sparkling Crystal should remain legal for the Dreepy/Drakloak/Dragapult line"),
	])


func test_opening_resource_investment_avoids_exposed_active_dreepy_when_backup_exists() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var active_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var bench_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.active_pokemon = active_dreepy
	player.bench.clear()
	player.bench.append(bench_dreepy)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var fire_to_active := {"action_id": "attach_energy:fire:active", "id": "attach_energy:fire:active", "type": "attach_energy", "kind": "attach_energy", "card": fire, "target_slot": active_dreepy}
	var fire_to_bench := {"action_id": "attach_energy:fire:bench_0", "id": "attach_energy:fire:bench_0", "type": "attach_energy", "kind": "attach_energy", "card": fire, "target_slot": bench_dreepy}
	var crystal_to_active := {"action_id": "attach_tool:crystal:active", "id": "attach_tool:crystal:active", "type": "attach_tool", "kind": "attach_tool", "card": crystal, "target_slot": active_dreepy}
	var crystal_to_bench := {"action_id": "attach_tool:crystal:bench_0", "id": "attach_tool:crystal:bench_0", "type": "attach_tool", "kind": "attach_tool", "card": crystal, "target_slot": bench_dreepy}
	var serialized_fire_to_active := {"action_id": "attach_energy:fire:active", "id": "attach_energy:fire:active", "type": "attach_energy", "kind": "attach_energy", "card": fire, "position": "active"}
	var serialized_crystal_to_active := {"action_id": "attach_tool:crystal:active", "id": "attach_tool:crystal:active", "type": "attach_tool", "kind": "attach_tool", "card": crystal, "position": "active"}
	var fire_active_score: float = float(llm.call("score_action_absolute", fire_to_active, gs, 0))
	var fire_bench_score: float = float(llm.call("score_action_absolute", fire_to_bench, gs, 0))
	var crystal_active_score: float = float(llm.call("score_action_absolute", crystal_to_active, gs, 0))
	var crystal_bench_score: float = float(llm.call("score_action_absolute", crystal_to_bench, gs, 0))
	_activate_llm_queue(llm, int(gs.turn_number), [fire_to_active])
	var redirected_fire_bench_score: float = float(llm.call("score_action_absolute", fire_to_bench, gs, 0))
	var llm_crystal := _new_strategy(LLM_SCRIPT_PATH)
	_activate_llm_queue(llm_crystal, int(gs.turn_number), [crystal_to_active])
	var redirected_crystal_bench_score: float = float(llm_crystal.call("score_action_absolute", crystal_to_bench, gs, 0))
	var direct_crystal_redirect := bool(llm_crystal.call("_deck_queue_item_matches_action", crystal_to_active, crystal_to_bench, gs, 0))
	var serialized_llm := _new_strategy(LLM_SCRIPT_PATH)
	_activate_llm_queue(serialized_llm, int(gs.turn_number), [serialized_fire_to_active])
	var serialized_fire_redirect_score: float = float(serialized_llm.call("score_action_absolute", fire_to_bench, gs, 0))
	var serialized_crystal_llm := _new_strategy(LLM_SCRIPT_PATH)
	_activate_llm_queue(serialized_crystal_llm, int(gs.turn_number), [serialized_crystal_to_active])
	var serialized_crystal_redirect_score: float = float(serialized_crystal_llm.call("score_action_absolute", crystal_to_bench, gs, 0))
	return run_checks([
		assert_true(fire_active_score <= -1000.0, "Opening Fire/Psychic attach should not invest in an exposed active Dreepy when a benched Dreepy can become the attacker"),
		assert_true(fire_bench_score > -1000.0, "Opening Fire/Psychic attach should remain available on the benched Dreepy line"),
		assert_true(crystal_active_score <= -1000.0, "Sparkling Crystal should not be attached to the exposed active Dreepy when a benched Dreepy can carry the route"),
		assert_true(crystal_bench_score > -1000.0, "Sparkling Crystal should remain available on the benched Dreepy line"),
		assert_true(redirected_fire_bench_score >= 10000.0, "An LLM queue that named exposed active Dreepy should redirect the same Energy to a benched Dreepy instead of escaping to end_turn"),
		assert_true(direct_crystal_redirect, "Deck hook should allow Sparkling Crystal redirection from exposed active Dreepy to benched Dreepy"),
		assert_true(redirected_crystal_bench_score >= 10000.0, "An LLM queue that named exposed active Dreepy should redirect Sparkling Crystal to a benched Dreepy instead of escaping to end_turn; score=%s" % redirected_crystal_bench_score),
		assert_true(serialized_fire_redirect_score >= 10000.0, "Serialized active-position Energy refs should also redirect to the benched Dreepy route line"),
		assert_true(serialized_crystal_redirect_score >= 10000.0, "Serialized active-position Sparkling Crystal refs should also redirect to the benched Dreepy route line"),
	])


func test_midgame_resource_investment_avoids_exposed_active_drakloak_when_backup_exists() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var active_drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy"), 0)
	var bench_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.active_pokemon = active_drakloak
	player.bench.clear()
	player.bench.append(bench_dreepy)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var psychic_to_active := {"action_id": "attach_energy:psychic:active", "id": "attach_energy:psychic:active", "type": "attach_energy", "kind": "attach_energy", "card": psychic, "target_slot": active_drakloak}
	var psychic_to_bench := {"action_id": "attach_energy:psychic:bench_0", "id": "attach_energy:psychic:bench_0", "type": "attach_energy", "kind": "attach_energy", "card": psychic, "target_slot": bench_dreepy}
	var crystal_to_active := {"action_id": "attach_tool:crystal:active", "id": "attach_tool:crystal:active", "type": "attach_tool", "kind": "attach_tool", "card": crystal, "target_slot": active_drakloak}
	var crystal_to_bench := {"action_id": "attach_tool:crystal:bench_0", "id": "attach_tool:crystal:bench_0", "type": "attach_tool", "kind": "attach_tool", "card": crystal, "target_slot": bench_dreepy}
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", psychic_to_active, gs, 0)) <= -1000.0, "Midgame Energy attach should not invest in exposed active Drakloak when a benched Dreepy can become the attacker"),
		assert_true(float(llm.call("score_action_absolute", psychic_to_bench, gs, 0)) > -1000.0, "Midgame Energy attach should remain available on the benched Dreepy line"),
		assert_true(float(llm.call("score_action_absolute", crystal_to_active, gs, 0)) <= -1000.0, "Sparkling Crystal should not be attached to exposed active Drakloak when a benched Dreepy can carry the route"),
		assert_true(float(llm.call("score_action_absolute", crystal_to_bench, gs, 0)) > -1000.0, "Sparkling Crystal should remain available on the benched Dreepy line"),
	])


func test_dragapult_resource_investment_keeps_energy_and_crystal_on_same_line() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	var energized_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var empty_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	energized_dreepy.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.bench.clear()
	player.bench.append(empty_dreepy)
	player.bench.append(energized_dreepy)
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var crystal_to_empty := {"kind": "attach_tool", "card": crystal, "target_slot": empty_dreepy}
	var crystal_to_energized := {"kind": "attach_tool", "card": crystal, "target_slot": energized_dreepy}
	var crystal_empty_score: float = float(llm.call("score_action_absolute", crystal_to_empty, gs, 0))
	var crystal_energized_score: float = float(llm.call("score_action_absolute", crystal_to_energized, gs, 0))
	var crystal_holder := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var no_crystal_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	crystal_holder.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	player.bench.clear()
	player.bench.append(crystal_holder)
	player.bench.append(no_crystal_dreepy)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var fire_to_crystal := {"kind": "attach_energy", "card": fire, "target_slot": crystal_holder}
	var fire_to_no_crystal := {"kind": "attach_energy", "card": fire, "target_slot": no_crystal_dreepy}
	return run_checks([
		assert_true(crystal_empty_score <= -1000.0, "Sparkling Crystal should not split away from an existing Fire/Psychic Dragapult line"),
		assert_true(crystal_energized_score > -1000.0, "Sparkling Crystal should remain available on the Dreepy line that already has route Energy"),
		assert_true(float(llm.call("score_action_absolute", fire_to_no_crystal, gs, 0)) <= -1000.0, "Fire/Psychic Energy should not split away from an existing Sparkling Crystal Dragapult line"),
		assert_true(float(llm.call("score_action_absolute", fire_to_crystal, gs, 0)) > -1000.0, "Fire/Psychic Energy should remain available on the Sparkling Crystal Dreepy line"),
	])


func test_duplicate_backup_energy_does_not_consume_attach_before_missing_energy_draw() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var crystal_line := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	crystal_line.attached_energy.append(_attached_energy("Fire Energy", "R"))
	crystal_line.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var empty_backup := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.bench.clear()
	player.bench.append(crystal_line)
	player.bench.append(empty_backup)
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	for i in range(6):
		player.deck.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var duplicate_fire_to_backup := {"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0), "target_slot": empty_backup}
	var iono := {"kind": "play_trainer", "card": player.hand[0]}
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", duplicate_fire_to_backup, gs, 0)) <= -1000.0, "Do not spend the manual attach on duplicate backup Fire while a Sparkling Crystal line needs Psychic and Iono can dig first"),
		assert_true(float(llm.call("score_action_absolute", iono, gs, 0)) > -1000.0, "Iono should remain available when the only visible attach is a low-priority duplicate backup Energy"),
	])


func test_basic_setup_route_includes_arven_search_before_end_turn() -> String:
	var builder := RouteBuilderScript.new()
	var actions: Array[Dictionary] = [
		{"id": "play_trainer:poffin", "action_id": "play_trainer:poffin", "kind": "play_trainer", "type": "play_trainer", "card": "Buddy-Buddy Poffin", "card_rules": {"name": "Buddy-Buddy Poffin", "tags": ["search_deck", "pokemon_related"]}},
		{"id": "play_trainer:nest", "action_id": "play_trainer:nest", "kind": "play_trainer", "type": "play_trainer", "card": "Nest Ball", "card_rules": {"name": "Nest Ball", "tags": ["search_deck", "pokemon_related"]}},
		{"id": "play_trainer:arven", "action_id": "play_trainer:arven", "kind": "play_trainer", "type": "play_trainer", "card": "Arven", "card_rules": {"name": "Arven", "tags": ["search_deck", "tool_or_modifier"]}},
		{"id": "end_turn", "action_id": "end_turn", "kind": "end_turn", "type": "end_turn"},
	]
	var routes: Array = builder.call("build_candidate_routes", actions, [], {})
	var setup_route: Dictionary = {}
	for raw_route: Variant in routes:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route as Dictionary
		var candidate_ids: Array[String] = []
		for raw_action: Variant in route.get("actions", []):
			if raw_action is Dictionary:
				candidate_ids.append(str((raw_action as Dictionary).get("action_id", (raw_action as Dictionary).get("id", ""))))
		if candidate_ids.has("play_trainer:arven") and candidate_ids.has("end_turn"):
			setup_route = route
			break
	var route_ids: Array[String] = []
	for raw_action: Variant in setup_route.get("actions", []):
		if raw_action is Dictionary:
			route_ids.append(str((raw_action as Dictionary).get("action_id", (raw_action as Dictionary).get("id", ""))))
	return run_checks([
		assert_false(setup_route.is_empty(), "A setup candidate route should include Arven-style setup search before preserving the turn"),
		assert_true(route_ids.has("play_trainer:arven"), "Setup route should include Arven-style setup search before preserving the turn"),
		assert_true(not route_ids.is_empty() and route_ids[route_ids.size() - 1] == "end_turn", "Setup route should still end only after setup/search actions"),
	])


func test_dragapult_llm_replaces_ready_jet_head_with_phantom_dive() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var jet_head := {
		"action_id": "attack:0",
		"id": "attack:0",
		"type": "attack",
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Jet Head",
		"projected_damage": 70,
	}
	var phantom_dive := {
		"action_id": "attack:1",
		"id": "attack:1",
		"type": "attack",
		"kind": "attack",
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
	}
	_activate_llm_queue(llm, int(gs.turn_number), [jet_head])
	llm.set("_llm_action_catalog", {
		"attack:0": jet_head,
		"attack:1": phantom_dive,
	})
	var jet_score: float = float(llm.call("score_action_absolute", jet_head, gs, 0))
	var phantom_score: float = float(llm.call("score_action_absolute", phantom_dive, gs, 0))
	var preferred: Dictionary = llm.call("_deck_preferred_terminal_attack_for", jet_head, gs, 0)
	return run_checks([
		assert_true(jet_score <= -1000.0, "A queued Jet Head should be blocked when Phantom Dive is ready"),
		assert_true(phantom_score >= 10000.0, "A queued Jet Head plan should allow the ready Phantom Dive replacement to own execution"),
		assert_eq(int(preferred.get("attack_index", -1)), 1, "Terminal attack repair should replace Jet Head with Phantom Dive"),
	])


func test_energy_ready_dragapult_blocks_jet_head_without_active_queue() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var jet_head := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Jet Head",
		"projected_damage": 70,
	}
	var phantom_dive := {
		"kind": "attack",
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
	}
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", jet_head, gs, 0)) <= -1000.0, "Jet Head should be blocked whenever Phantom Dive is fully powered"),
		assert_true(float(llm.call("score_action_absolute", phantom_dive, gs, 0)) > -1000.0, "Phantom Dive should remain available as the primary terminal attack"),
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", jet_head, jet_head, gs, 0)), "Queue-level guard should also reject exact Jet Head ids"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", phantom_dive, phantom_dive, gs, 0)), "Queue-level guard should not reject the ready Phantom Dive action"),
	])


func test_dragapult_uses_draw_supporter_before_fallback_jet_head_when_missing_psychic() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.active_pokemon = dragapult
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_trainer_cd("DeckCard%d" % i), 0))
	var jet_head := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Jet Head",
		"projected_damage": 70,
	}
	gs.supporter_used_this_turn = false
	var blocked_score: float = float(llm.call("score_action_absolute", jet_head, gs, 0))
	gs.supporter_used_this_turn = true
	var fallback_score: float = float(llm.call("score_action_absolute", jet_head, gs, 0))
	return run_checks([
		assert_true(blocked_score <= -1000.0, "Jet Head should wait for a live Iono route when Phantom Dive only misses Psychic"),
		assert_true(fallback_score > -1000.0, "Jet Head should remain a fallback after the supporter draw window is gone"),
	])


func test_dragapult_requires_real_fire_and_psychic_for_phantom_dive_pressure() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.active_pokemon = dragapult
	var phantom_dive := {
		"kind": "attack",
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
	}
	return run_checks([
		assert_false(bool(llm.call("_active_dragapult_pressure_ready", gs, 0)), "Two Fire Energy should not be treated as a ready R/P Phantom Dive cost"),
		assert_false(bool(llm.call("_is_dragapult_phantom_dive_attack_action", phantom_dive, gs, 0)), "Phantom Dive action repair should require the exact Fire plus Psychic energy mix"),
	])


func test_sparkling_crystal_counts_as_missing_phantom_dive_cost() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	dragapult.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	player.active_pokemon = dragapult
	var phantom_dive := {
		"kind": "attack",
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
	}
	var jet_head := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Jet Head",
		"projected_damage": 70,
	}
	return run_checks([
		assert_true(bool(llm.call("_active_dragapult_pressure_ready", gs, 0)), "Sparkling Crystal plus one Psychic Energy should count as ready for Phantom Dive"),
		assert_true(bool(llm.call("_is_dragapult_phantom_dive_attack_action", phantom_dive, gs, 0)), "Phantom Dive repair should honor Sparkling Crystal cost reduction"),
		assert_true(float(llm.call("score_action_absolute", jet_head, gs, 0)) <= -1000.0, "Jet Head should be blocked when Sparkling Crystal makes Phantom Dive ready"),
	])


func test_rotom_terminal_draw_blocked_when_dragapult_line_can_attach_energy() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon = dragapult
	player.bench.clear()
	player.bench.append(rotom)
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var rotom_draw := {
		"id": "use_ability:bench_0:0",
		"action_id": "use_ability:bench_0:0",
		"type": "use_ability",
		"kind": "use_ability",
		"source_slot": rotom,
		"ability_index": 0,
	}
	var fire_attach := {
		"kind": "attach_energy",
		"card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0),
		"target_slot": dragapult,
	}
	return run_checks([
		assert_true(bool(llm.call("_dragapult_line_manual_attach_available", gs, 0)), "A Dragapult line with missing Fire/Psychic and hand Energy should expose a manual attach obligation"),
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", rotom_draw, rotom_draw, gs, 0)), "Rotom terminal draw should not consume the turn before a visible Dragapult-line manual attach"),
		assert_true(float(llm.call("score_action_absolute", rotom_draw, gs, 0)) <= -1000.0, "The absolute scorer should suppress terminal Rotom draw before the attach window is used"),
		assert_true(bool(llm.call("_deck_can_replace_end_turn_with_action", fire_attach, gs, 0)), "Runtime repair should be allowed to replace an end-turn queue with the missing manual attach"),
	])


func test_serialized_rotom_draw_ref_blocked_before_missing_psychic_attach() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	dreepy.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.active_pokemon = dreepy
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var serialized_rotom_draw := {
		"id": "use_ability:bench_0:0",
		"action_id": "use_ability:bench_0:0",
		"type": "use_ability",
		"kind": "use_ability",
		"source_slot": {
			"pokemon_name": "洛托姆V",
			"pokemon_stack": [{"card_name": "洛托姆V", "name_en": "Rotom V"}],
		},
		"ability_index": 0,
	}
	return run_checks([
		assert_true(bool(llm.call("_dragapult_line_manual_attach_available", gs, 0)), "A Fire-attached Dreepy with Psychic in hand should expose a missing-cost manual attach"),
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", serialized_rotom_draw, serialized_rotom_draw, gs, 0)), "Serialized Rotom refs from action traces should still be recognized and blocked"),
		assert_true(float(llm.call("score_action_absolute", serialized_rotom_draw, gs, 0)) <= -1000.0, "Serialized Rotom terminal draw should be suppressed before attaching missing Psychic"),
	])


func test_iono_blocked_when_dragapult_line_can_attach_missing_energy() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	drakloak.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.active_pokemon = drakloak
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var iono := {
		"id": "play_trainer:c10",
		"action_id": "play_trainer:c10",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0),
	}
	return run_checks([
		assert_true(bool(llm.call("_dragapult_line_manual_attach_available", gs, 0)), "Missing Psychic on the active Drakloak should be attachable before shuffle-draw"),
		assert_true(float(llm.call("score_action_absolute", iono, gs, 0)) <= -1000.0, "Iono should not shuffle away the visible missing Psychic before manual attach"),
	])


func test_iono_blocked_when_crystal_can_complete_dragapult_route() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	player.hand.append(CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0))
	var iono := {
		"id": "play_trainer:c10",
		"action_id": "play_trainer:c10",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0),
	}
	return run_checks([
		assert_true(bool(llm.call("_dragapult_crystal_attach_available", gs, 0)), "Sparkling Crystal in hand should expose a route-critical tool attach before shuffle-draw"),
		assert_true(float(llm.call("score_action_absolute", iono, gs, 0)) <= -1000.0, "Iono should not shuffle away Sparkling Crystal before it completes the Dragapult attack route"),
	])


func test_earthen_vessel_energy_search_prefers_missing_fire_for_active_dragapult() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var psychic_a := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var psychic_b := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var picked: Array = llm.call("pick_interaction_items", [psychic_a, psychic_b, fire], {"id": "search_energy", "max_select": 2}, {"game_state": gs, "player_index": 0})
	var first_name := ""
	if not picked.is_empty() and picked[0] is CardInstance and (picked[0] as CardInstance).card_data != null:
		first_name = (picked[0] as CardInstance).card_data.name_en
	return run_checks([
		assert_eq(first_name, "Fire Energy", "Earthen Vessel should search the missing Fire before duplicate Psychic when active Dragapult already has Psychic"),
		assert_true(picked.has(fire), "Missing Fire Energy should be included in the search picks"),
	])


func test_send_out_prefers_powered_dragapult_over_rotom_support() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(14)
	var player: PlayerState = gs.players[0]
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = null
	player.bench.clear()
	player.bench.append(rotom)
	player.bench.append(duskull)
	player.bench.append(dragapult)
	var step := {"id": "send_out", "use_slot_selection_ui": true}
	var context := {"game_state": gs, "player_index": 0, "all_items": player.bench}
	var dragapult_score: float = float(llm.call("score_handoff_target", dragapult, step, context))
	var rotom_score: float = float(llm.call("score_handoff_target", rotom, step, context))
	var duskull_score: float = float(llm.call("score_handoff_target", duskull, step, context))
	return run_checks([
		assert_true(dragapult_score > rotom_score, "Send-out scoring should not promote Rotom V over a powered Phantom Dive attacker"),
		assert_true(dragapult_score > duskull_score, "Send-out scoring should choose the powered Dragapult before low-value Duskull shielding"),
	])


func test_send_out_uses_rotom_to_cover_unready_dragapult_seeds() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	player.active_pokemon = null
	player.bench.clear()
	player.bench.append(rotom)
	player.bench.append(dreepy)
	player.bench.append(drakloak)
	player.bench.append(duskull)
	var step := {"id": "send_out", "use_slot_selection_ui": true}
	var context := {"game_state": gs, "player_index": 0, "all_items": player.bench}
	var rotom_score: float = float(llm.call("score_handoff_target", rotom, step, context))
	var dreepy_score: float = float(llm.call("score_handoff_target", dreepy, step, context))
	var drakloak_score: float = float(llm.call("score_handoff_target", drakloak, step, context))
	var duskull_score: float = float(llm.call("score_handoff_target", duskull, step, context))
	return run_checks([
		assert_true(rotom_score > dreepy_score, "After a seed KO, send-out should use Rotom V as a pressure buffer instead of exposing unready Dreepy"),
		assert_true(rotom_score > drakloak_score, "After a seed KO, send-out should protect unready Drakloak from being promoted into a free prize"),
		assert_true(rotom_score > duskull_score, "Rotom V buffer should still outrank low-value Duskull send-out when preserving the Dragapult line"),
	])


func test_switch_action_blocks_serialized_support_only_target() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0))
	var bad_switch := {
		"id": "play_trainer:c30",
		"action_id": "play_trainer:c30",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": {"card_name": "宝可梦交替", "name_en": "Switch", "card_type": "Item"},
		"targets": [{
			"self_switch_target": [{
				"pokemon_name": "洛托姆V",
				"pokemon_stack": [{"card_name": "洛托姆V", "name_en": "Rotom V"}],
			}],
		}],
	}
	var good_switch := bad_switch.duplicate(true)
	good_switch["targets"] = [{
		"self_switch_target": [{
			"pokemon_name": "多龙奇",
			"pokemon_stack": [{"card_name": "多龙奇", "name_en": "Drakloak"}],
		}],
	}]
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", bad_switch, gs, 0)) <= -1000.0, "Switch should not promote Rotom V while a Dragapult line exists"),
		assert_true(float(llm.call("score_action_absolute", good_switch, gs, 0)) > -1000.0, "Switch should remain available when it promotes the Dragapult line"),
	])


func test_switch_blocks_empty_dragapult_line_when_route_resource_line_exists() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var active_dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	active_dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	var empty_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var resource_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	resource_dreepy.attached_energy.append(_attached_energy("Fire Energy", "R"))
	resource_dreepy.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	player.active_pokemon = active_dragapult
	player.bench.clear()
	player.bench.append(empty_dreepy)
	player.bench.append(resource_dreepy)
	var switch_to_empty := {
		"id": "play_trainer:switch",
		"action_id": "play_trainer:switch",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": CardInstance.create(_make_trainer_cd("Switch", "Item"), 0),
		"targets": [{"self_switch_target": [empty_dreepy]}],
	}
	var switch_to_resource := switch_to_empty.duplicate(true)
	switch_to_resource["targets"] = [{"self_switch_target": [resource_dreepy]}]
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", switch_to_empty, gs, 0)) <= -1000.0, "Switch should not move from a route-resource Dragapult line into an empty Dreepy line"),
		assert_true(float(llm.call("score_action_absolute", switch_to_resource, gs, 0)) > -1000.0, "Switch should remain available when it promotes the Dragapult line carrying route resources"),
	])


func test_gust_resources_blocked_without_attack_or_dusknoir_conversion_window() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_dragapult_ex_cd(), 0)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var boss := {
		"id": "play_trainer:boss",
		"action_id": "play_trainer:boss",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0),
	}
	var blocked_score: float = float(llm.call("score_action_absolute", boss, gs, 0))
	player.active_pokemon.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var ready_score: float = float(llm.call("score_action_absolute", boss, gs, 0))
	return run_checks([
		assert_true(blocked_score <= -1000.0, "Boss should be preserved when there is no active attack or Dusknoir conversion window"),
		assert_true(ready_score > -1000.0, "Boss should remain available once Phantom Dive is ready through Sparkling Crystal"),
	])


func test_setup_repair_inserts_poffin_before_terminal_attack() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	player.hand.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0))
	var poffin_ref := {
		"id": "play_trainer:poffin",
		"action_id": "play_trainer:poffin",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Buddy-Buddy Poffin",
	}
	var attack_ref := {
		"id": "attack:1",
		"action_id": "attack:1",
		"type": "attack",
		"kind": "attack",
		"attack_index": 1,
		"attack_name": "Phantom Dive",
	}
	llm.set("_llm_action_catalog", {
		"play_trainer:poffin": poffin_ref,
		"attack:1": attack_ref,
	})
	var repair: Dictionary = llm.call("_repair_missing_productive_engine_in_tree", {"actions": [attack_ref]}, gs, 0)
	var repaired_tree: Dictionary = repair.get("tree", {})
	var actions: Array = repaired_tree.get("actions", [])
	return run_checks([
		assert_true(actions.size() >= 2, "Repair should add a setup action before the terminal attack"),
		assert_eq(str((actions[0] as Dictionary).get("action_id", "")), "play_trainer:poffin", "Poffin should be inserted before attacking when it is a visible safe setup action"),
		assert_eq(str((actions[actions.size() - 1] as Dictionary).get("action_id", "")), "attack:1", "The terminal Phantom Dive should remain last after setup repair"),
	])


func test_bad_dragapult_dusknoir_targets_block_before_queue_or_fallback_scores() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var fezandipiti := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.active_pokemon = dreepy
	player.bench.clear()
	player.bench.append(duskull)
	player.bench.append(fezandipiti)
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var bad_crystal := {
		"action_id": "attach_tool:test_bad_crystal",
		"id": "attach_tool:test_bad_crystal",
		"kind": "attach_tool",
		"card": crystal,
		"target_slot": fezandipiti,
	}
	var bad_energy := {"kind": "attach_energy", "card": psychic, "target_slot": duskull}
	var bad_lightning_to_dragapult_line := {"kind": "attach_energy", "card": lightning, "target_slot": dreepy}
	var good_fire_to_dragapult_line := {"kind": "attach_energy", "card": fire, "target_slot": dreepy}
	_activate_llm_queue(llm, int(gs.turn_number), [bad_crystal])
	var queued_bad_crystal_score: float = float(llm.call("score_action_absolute", bad_crystal, gs, 0))
	llm.set("_llm_queue_turn", -1)
	llm.set("_llm_action_queue", [])
	llm.set("_llm_action_catalog", {})
	var fallback_bad_crystal_absolute: float = float(llm.call("score_action_absolute", bad_crystal, gs, 0))
	var fallback_bad_crystal_score: float = float(llm.call("score_action", bad_crystal, {"game_state": gs, "player_index": 0}))
	var fallback_bad_energy_score: float = float(llm.call("score_action", bad_energy, {"game_state": gs, "player_index": 0}))
	var fallback_bad_lightning_score: float = float(llm.call("score_action", bad_lightning_to_dragapult_line, {"game_state": gs, "player_index": 0}))
	var fallback_good_fire_score: float = float(llm.call("score_action_absolute", good_fire_to_dragapult_line, gs, 0))
	var compact_bad_crystal := {"kind": "attach_tool", "card": {"name_en": "Sparkling Crystal"}, "target": {"name_en": "Fezandipiti ex"}}
	var compact_bad_energy := {"kind": "attach_energy", "card": {"name_en": "Psychic Energy"}, "target": {"name_en": "Duskull"}}
	var compact_bad_crystal_score: float = float(llm.call("score_action", compact_bad_crystal, {"game_state": gs, "player_index": 0}))
	var compact_bad_energy_score: float = float(llm.call("score_action", compact_bad_energy, {"game_state": gs, "player_index": 0}))
	return run_checks([
		assert_true(queued_bad_crystal_score <= -1000.0, "Bad tool targets should be blocked before a matching active LLM queue can force them"),
		assert_true(fallback_bad_crystal_absolute <= -1000.0, "Bad tool targets should remain blocked after the LLM queue has cleared"),
		assert_true(fallback_bad_crystal_score <= -1000.0, "Fallback score_action should not re-enable bad Sparkling Crystal targets"),
		assert_true(fallback_bad_energy_score <= -1000.0, "Fallback score_action should not re-enable Duskull/Dusclops/Dusknoir energy targets when Dragapult line exists"),
		assert_true(fallback_bad_lightning_score <= -1000.0, "Fallback score_action should block off-type energy on the Dragapult line"),
		assert_true(fallback_good_fire_score > -1000.0, "Fallback score_action should still allow Fire energy on the Dragapult line"),
		assert_true(compact_bad_crystal_score <= -1000.0, "Compact fallback actions should still block Sparkling Crystal on support Pokemon"),
		assert_true(compact_bad_energy_score <= -1000.0, "Compact fallback actions should still block energy on the Dusknoir line"),
	])


func test_tool_assignment_blocks_forest_seal_and_sparkling_crystal_bad_targets() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var tatsugiri := _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var dragapult := _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.active_pokemon = tatsugiri
	player.bench.clear()
	player.bench.append(dreepy)
	player.bench.append(dragapult)
	player.bench.append(duskull)
	player.bench.append(rotom)
	player.bench.append(lumineon)
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var forest_seal := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var forest_to_rotom := {"kind": "attach_tool", "card": forest_seal, "target_slot": rotom}
	return run_checks([
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": crystal, "target_slot": duskull}, gs, 0)), "Sparkling Crystal should not attach to Duskull"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": crystal, "target_slot": dreepy}, gs, 0)), "Sparkling Crystal should be allowed on Dreepy"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": crystal, "target_slot": dragapult}, gs, 0)), "Sparkling Crystal should be allowed on Dragapult ex"),
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": forest_seal, "target_slot": dragapult}, gs, 0)), "Forest Seal Stone should not attach to Dragapult ex"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": forest_seal, "target_slot": rotom}, gs, 0)), "Forest Seal Stone should be allowed on Rotom V"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": forest_seal, "target_slot": lumineon}, gs, 0)), "Forest Seal Stone should be allowed on Lumineon V"),
		assert_true(bool(llm.call("_deck_can_replace_end_turn_with_action", forest_to_rotom, gs, 0)), "Forest Seal Stone on a V carrier should remain a non-terminal setup replacement before end_turn"),
	])


func test_tm_devolution_requires_real_opponent_devolution_window() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.active_pokemon = dreepy
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	var tm_dev := CardInstance.create(_make_trainer_cd("Technical Machine: Devolution", "Tool"), 0)
	var attach_tm := {"kind": "attach_tool", "card": tm_dev, "target_slot": dreepy}
	var blocked_without_window := bool(llm.call("_deck_should_block_exact_queue_match", {}, attach_tm, gs, 0))
	var damaged_stage1 := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy"), 1)
	damaged_stage1.damage_counters = 40
	opponent.bench.append(damaged_stage1)
	var blocked_with_window := bool(llm.call("_deck_should_block_exact_queue_match", {}, attach_tm, gs, 0))
	var can_replace_end_with_tm := bool(llm.call("_deck_can_replace_end_turn_with_action", attach_tm, gs, 0))
	return run_checks([
		assert_true(blocked_without_window, "TM Devolution should not attach early when the opponent has no evolved damaged target"),
		assert_false(blocked_with_window, "TM Devolution should remain available once a real devolution prize window exists"),
		assert_false(can_replace_end_with_tm, "TM Devolution is a tactical tool and should not be injected as generic setup before end_turn"),
	])


func test_dusknoir_self_ko_does_not_give_opponent_final_prize() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var dusknoir := _make_slot(_make_pokemon_cd(
		"Dusknoir",
		"Stage 2",
		"P",
		160,
		"Dusclops",
		"",
		[{"name": "Cursed Blast", "text": "Place 13 damage counters."}]
	), 0)
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	player.bench.clear()
	player.bench.append(dusknoir)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	iron_hands.damage_counters = 120
	opponent.bench.clear()
	opponent.bench.append(iron_hands)
	var blast_action := {"kind": "use_ability", "source_slot": dusknoir, "ability_index": 0}
	_set_prize_count(player, 3, 0)
	_set_prize_count(opponent, 1, 1)
	var blocked_when_not_closing := bool(llm.call("_deck_should_block_exact_queue_match", {}, blast_action, gs, 0))
	_set_prize_count(player, 2, 0)
	var blocked_when_closing := bool(llm.call("_deck_should_block_exact_queue_match", {}, blast_action, gs, 0))
	return run_checks([
		assert_true(blocked_when_not_closing, "Dusknoir self-KO should be blocked when it gives the opponent their final prize and does not win immediately"),
		assert_false(blocked_when_closing, "Dusknoir self-KO should remain allowed when the blast takes enough prizes to win first"),
	])


func test_ready_dragapult_allows_second_line_but_blocks_support_padding() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon = dragapult
	player.bench.clear()
	player.bench.append(duskull)
	player.bench.append(rotom)
	player.hand.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0))
	var poffin := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 0)}
	var nest := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)}
	var dreepy_card := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var dreepy_setup := {"kind": "play_basic_to_bench", "card": dreepy_card}
	var fez_setup := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)}
	var rotom_draw := {"kind": "use_ability", "source_slot": rotom, "ability_index": 0}
	var poffin_score: float = float(llm.call("score_action_absolute", poffin, gs, 0))
	var nest_score: float = float(llm.call("score_action_absolute", nest, gs, 0))
	var dreepy_setup_score: float = float(llm.call("score_action_absolute", dreepy_setup, gs, 0))
	var fez_setup_score: float = float(llm.call("score_action_absolute", fez_setup, gs, 0))
	var rotom_draw_score: float = float(llm.call("score_action_absolute", rotom_draw, gs, 0))
	var dreepy_slot := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.bench.append(dreepy_slot)
	var drakloak_evolve := {"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy"), 0), "target_slot": dreepy_slot}
	var drakloak_evolve_score: float = float(llm.call("score_action_absolute", drakloak_evolve, gs, 0))
	return run_checks([
		assert_true(poffin_score > -1000.0, "Poffin should remain available when ready Dragapult still lacks a backup Dreepy line"),
		assert_true(nest_score > -1000.0, "Nest Ball should remain available when it can establish the backup line"),
		assert_true(dreepy_setup_score > -1000.0, "Direct Dreepy bench should remain a high-value second-line action"),
		assert_true(drakloak_evolve_score > -1000.0, "Drakloak evolution should remain allowed to mature the second line"),
		assert_true(fez_setup_score <= -1000.0, "Low-value support benching should be blocked even while the backup line is still missing"),
		assert_true(rotom_draw_score <= -1000.0, "Rotom terminal draw should not steal the turn from attack or second-line setup"),
	])


func test_ready_dragapult_blocks_extra_setup_and_rotom_draw() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	var drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy"), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon = dragapult
	player.bench.clear()
	player.bench.append(drakloak)
	player.bench.append(duskull)
	player.bench.append(rotom)
	player.hand.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var poffin := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 0)}
	var nest := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)}
	var extra_dreepy := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)}
	var extra_fez := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)}
	var rotom_draw := {"kind": "use_ability", "source_slot": rotom, "ability_index": 0}
	var drakloak_draw := {"kind": "use_ability", "source_slot": drakloak, "ability_index": 0}
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", poffin, gs, 0)) <= -1000.0, "Poffin should be blocked after ready Dragapult already has a backup line"),
		assert_true(float(llm.call("score_action_absolute", nest, gs, 0)) <= -1000.0, "Nest Ball should be blocked after ready Dragapult already has a backup line"),
		assert_true(float(llm.call("score_action_absolute", extra_dreepy, gs, 0)) <= -1000.0, "Extra Dreepy should be blocked once the second line is already present"),
		assert_true(float(llm.call("score_action_absolute", extra_fez, gs, 0)) <= -1000.0, "Extra support Pokemon should be blocked once the attacker and backup are online"),
		assert_true(float(llm.call("score_action_absolute", rotom_draw, gs, 0)) <= -1000.0, "Rotom draw should not replace attacking once Phantom Dive is ready"),
		assert_true(float(llm.call("score_action_absolute", drakloak_draw, gs, 0)) > -1000.0, "Drakloak draw remains a valid engine action"),
	])


func test_ready_dragapult_blocks_nonterminal_setup_but_allows_prize_gust() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	var opponent: PlayerState = gs.players[1]
	var full_miraidon := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var raichu := _make_slot(_make_pokemon_cd("Raichu V", "Basic", "L", 200, "", "V"), 1)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(full_miraidon)
	opponent.bench.append(raichu)
	var arven := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)}
	var end_turn := {"kind": "end_turn"}
	var bad_gust := {
		"kind": "play_trainer",
		"card": CardInstance.create(_make_trainer_cd("Counter Catcher", "Item"), 0),
		"targets": [{"opponent_bench_target": [full_miraidon]}],
	}
	var prize_gust := {
		"kind": "play_trainer",
		"card": CardInstance.create(_make_trainer_cd("Counter Catcher", "Item"), 0),
		"targets": [{"opponent_bench_target": [raichu]}],
	}
	return run_checks([
		assert_true(float(llm.call("score_action_absolute", arven, gs, 0)) <= -1000.0, "Arven should not replace a ready Phantom Dive attack window"),
		assert_true(float(llm.call("score_action_absolute", end_turn, gs, 0)) <= -1000.0, "End turn should be blocked while Phantom Dive is ready"),
		assert_true(float(llm.call("score_action_absolute", bad_gust, gs, 0)) <= -1000.0, "Gust should be blocked when it does not create a Phantom Dive prize target"),
		assert_true(float(llm.call("score_action_absolute", prize_gust, gs, 0)) > -1000.0, "Gust remains allowed when it pulls a 200 HP multi-prize Phantom Dive target"),
	])


func test_rare_candy_interaction_scores_finish_dragapult_before_dusknoir_without_conversion() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	player.active_pokemon = dreepy
	player.bench.clear()
	player.bench.append(duskull)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var dragapult_card := CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var dusknoir_card := CardInstance.create(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops"), 0)
	player.hand.append(dragapult_card)
	player.hand.append(dusknoir_card)
	var context := {"game_state": gs, "player_index": 0}
	var dragapult_score: float = float(llm.call("score_interaction_target", dragapult_card, {"id": "stage2_card"}, context))
	var dusknoir_setup_score: float = float(llm.call("score_interaction_target", dusknoir_card, {"id": "stage2_card"}, context))
	var dreepy_target_score: float = float(llm.call("score_interaction_target", dreepy, {"id": "target_pokemon"}, context))
	var duskull_target_score: float = float(llm.call("score_interaction_target", duskull, {"id": "target_pokemon"}, context))
	opponent.active_pokemon.damage_counters = 100
	var dusknoir_conversion_score: float = float(llm.call("score_interaction_target", dusknoir_card, {"id": "stage2_card"}, context))
	return run_checks([
		assert_true(dragapult_score > dusknoir_setup_score, "Rare Candy should prefer first Dragapult ex before Dusknoir when no conversion exists"),
		assert_true(dreepy_target_score > duskull_target_score, "Rare Candy target selection should prefer Dreepy for the main Stage 2 line"),
		assert_true(dusknoir_conversion_score > dragapult_score, "Dusknoir may outrank Dragapult when Rare Candy creates an immediate prize conversion"),
	])


func test_rare_candy_targets_dragapult_line_with_existing_route_resources() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var exposed_empty_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var routed_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	routed_dreepy.attached_energy.append(_attached_energy("Fire Energy", "R"))
	routed_dreepy.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	routed_dreepy.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	player.active_pokemon = exposed_empty_dreepy
	player.bench.clear()
	player.bench.append(routed_dreepy)
	var dragapult_card := CardInstance.create(_make_dragapult_ex_cd(), 0)
	var context := {
		"game_state": gs,
		"player_index": 0,
		"stage2_card": [dragapult_card],
	}
	var exposed_score: float = float(llm.call("score_interaction_target", exposed_empty_dreepy, {"id": "target_pokemon"}, context))
	var routed_score: float = float(llm.call("score_interaction_target", routed_dreepy, {"id": "target_pokemon"}, context))
	return run_checks([
		assert_true(routed_score > exposed_score, "Rare Candy target selection should keep Dragapult ex on the Fire/Psychic/Sparkling Crystal line"),
		assert_true(exposed_score < 1200.0, "An exposed empty Dreepy should be downgraded when another Dragapult line already carries route resources"),
	])


func test_forest_seal_search_prefers_dragapult_for_ready_rare_candy_attack_route() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	dreepy.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dreepy.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	player.active_pokemon = dreepy
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0))
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 0)
	var fire_energy := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var dragapult := CardInstance.create(_make_dragapult_ex_cd(), 0)
	var items: Array = [poffin, fire_energy, dragapult]
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = llm.call("pick_interaction_items", items, {"id": "search_cards", "max_select": 1}, context)
	var dragapult_score: float = float(llm.call("score_interaction_target", dragapult, {"id": "search_cards"}, context))
	var poffin_score: float = float(llm.call("score_interaction_target", poffin, {"id": "search_cards"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Forest Seal Stone search should select exactly one card"),
		assert_true(picked[0] == dragapult, "Forest Seal Stone should fetch Dragapult ex when Rare Candy plus Sparkling Crystal creates an immediate Phantom Dive route"),
		assert_true(dragapult_score > poffin_score, "Immediate Dragapult ex conversion should outrank extra setup Pokemon search"),
	])


func test_basic_search_prefers_forest_seal_carrier_when_star_search_completes_dragapult() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	dreepy.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dreepy.attached_tool = CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	player.active_pokemon = dreepy
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0))
	var extra_dreepy := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var items: Array = [extra_dreepy, duskull, rotom]
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = llm.call("pick_interaction_items", items, {"id": "basic_pokemon", "max_select": 1}, context)
	var rotom_score: float = float(llm.call("score_interaction_target", rotom, {"id": "basic_pokemon"}, context))
	var dreepy_score: float = float(llm.call("score_interaction_target", extra_dreepy, {"id": "basic_pokemon"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Basic Pokemon search should select one Forest Seal carrier"),
		assert_true(picked[0] == rotom, "Nest Ball-style search should fetch Rotom V when Forest Seal Stone can complete Rare Candy Dragapult ex"),
		assert_true(rotom_score > dreepy_score, "Forest Seal Stone carrier should outrank extra Dreepy when the current line is already live"),
	])


func test_basic_search_anticipates_arven_forest_seal_carrier_opening() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0))
	var extra_dreepy := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var items: Array = [extra_dreepy, duskull, rotom]
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = llm.call("pick_interaction_items", items, {"id": "basic_pokemon", "max_select": 1}, context)
	return run_checks([
		assert_eq(picked.size(), 1, "Opening basic Pokemon search should pick one target"),
		assert_true(picked[0] == rotom, "Nest Ball before Arven should anticipate Rotom V as the Forest Seal Stone carrier when the Dragapult line is already seeded"),
	])


func test_basic_search_prefers_rotom_buffer_over_fezandipiti_under_miraidon_pressure() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	opponent.active_pokemon.attached_energy.append(_attached_energy("Lightning Energy", "L"))
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var fezandipiti := CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var items: Array = [fezandipiti, duskull, rotom]
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = llm.call("pick_interaction_items", items, {"id": "basic_pokemon", "max_select": 1}, context)
	var rotom_score: float = float(llm.call("score_interaction_target", rotom, {"id": "basic_pokemon"}, context))
	var fez_score: float = float(llm.call("score_interaction_target", fezandipiti, {"id": "basic_pokemon"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Basic search should still select a single Pokemon under pressure"),
		assert_true(picked[0] == rotom, "Nest Ball-style search should find Rotom V as a buffer instead of Fezandipiti ex while Dreepy is exposed to Miraidon pressure"),
		assert_true(rotom_score > fez_score, "Rotom V buffer should outrank Fezandipiti ex comeback draw when the Dragapult seed needs protection"),
	])


func test_arven_item_search_prefers_nest_ball_when_forest_seal_needs_carrier() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0))
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var nest_score: float = float(llm.call("score_interaction_target", nest_ball, {"id": "search_item"}, context))
	var rare_candy_score: float = float(llm.call("score_interaction_target", rare_candy, {"id": "search_item"}, context))
	return run_checks([
		assert_true(nest_score > rare_candy_score, "Arven should fetch Nest Ball before Rare Candy when Forest Seal Stone still needs a V carrier"),
	])


func test_bad_prefix_attach_does_not_block_later_forest_carrier_search() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var active_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var backup_dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.active_pokemon = active_dreepy
	player.bench.append(backup_dreepy)
	player.hand.append(CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy", "Item"), 0))
	var fire_energy := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var nest_card := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	var bad_attach := {
		"id": "attach_energy:fire:active",
		"action_id": "attach_energy:fire:active",
		"kind": "attach_energy",
		"type": "attach_energy",
		"card": fire_energy,
		"target_slot": active_dreepy,
	}
	var serialized_bad_attach := {
		"id": "attach_energy:fire:active",
		"action_id": "attach_energy:fire:active",
		"kind": "attach_energy",
		"type": "attach_energy",
		"card": "Fire Energy",
		"position": "active",
		"target": "Dreepy",
	}
	var nest_action := {
		"id": "play_trainer:nest",
		"action_id": "play_trainer:nest",
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": nest_card,
		"card_rules": {"name": "Nest Ball", "tags": ["search_deck", "pokemon_related"]},
	}
	var queue: Array[Dictionary] = [bad_attach, nest_action, {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}]
	var serialized_queue: Array[Dictionary] = [serialized_bad_attach, nest_action, {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}]
	var nest_score := float(llm.call("_score_from_queue", nest_action, queue, gs, 0))
	var serialized_nest_score := float(llm.call("_score_from_queue", nest_action, serialized_queue, gs, 0))
	return run_checks([
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", bad_attach, bad_attach, gs, 0)), "The exposed active Dreepy attach is intentionally blocked by the deck hook"),
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", serialized_bad_attach, serialized_bad_attach, gs, 0)), "Serialized active-position attach refs should resolve to the exposed active Dreepy"),
		assert_true(nest_score > 0.0, "A blocked bad attach prefix should not prevent executing the later Nest Ball carrier-search action"),
		assert_true(serialized_nest_score > 0.0, "Serialized bad attach prefixes should not block later carrier-search actions either"),
	])


func test_forest_seal_attach_replans_for_star_search_action_surface() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var before := {"turn": 2, "hand_count": 5, "deck_count": 40, "discard_count": 0, "hand_ids": ["forest"], "hand_names": ["Forest Seal Stone"]}
	var after := {"turn": 2, "hand_count": 4, "deck_count": 40, "discard_count": 0, "hand_ids": [], "hand_names": []}
	var trigger: Dictionary = llm.call("_deck_replan_trigger_after_state_change", before, after, {
		"success": true,
		"step_kind": "main_action",
		"action_kind": "attach_tool",
		"action_card_name": "Forest Seal Stone",
		"action_card_type": "Tool",
	})
	return run_checks([
		assert_true(bool(trigger.get("should_replan", false)), "Forest Seal Stone attach should immediately replan because it unlocks Star Alchemy"),
		assert_true(bool(trigger.get("ignore_replan_limit", false)), "Forest Seal replan should bypass the normal same-turn limit"),
		assert_eq(str(trigger.get("reason", "")), "forest_seal_unlocked_star_search", "Forest Seal replan reason should be explicit"),
	])


func test_forest_seal_blocks_rotom_quick_search_until_star_search_used() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	rotom.attached_tool = CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	player.bench.append(rotom)
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0))
	var quick_search := {
		"id": "use_ability:bench_0:0",
		"action_id": "use_ability:bench_0:0",
		"kind": "use_ability",
		"type": "use_ability",
		"pokemon": "Rotom V",
		"ability_index": 0,
	}
	var star_search := {
		"id": "use_ability:bench_0:1",
		"action_id": "use_ability:bench_0:1",
		"kind": "use_ability",
		"type": "use_ability",
		"pokemon": "Rotom V",
		"ability_index": 1,
	}
	var queue: Array[Dictionary] = [quick_search, star_search, {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}]
	var prefix_blocks_star := bool(llm.call("_queue_prefix_blocks_skip", queue, 1, gs, 0))
	return run_checks([
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", quick_search, quick_search, gs, 0)), "Rotom Quick Search should not consume the turn before Forest Seal Star Search"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", star_search, star_search, gs, 0)), "Forest Seal Star Search should remain executable"),
		assert_true(bool(llm.call("_deck_queue_item_matches_action", quick_search, star_search, gs, 0)), "Forest Seal Star Search should be allowed to replace a queued Rotom Quick Search"),
		assert_false(prefix_blocks_star, "Blocked Quick Search should not prevent the later Star Search queue item from matching"),
		])


func test_prompt_builder_describes_forest_seal_star_search_as_tool_search() -> String:
	var builder = PromptBuilderScript.new()
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var rotom := _make_slot(_make_pokemon_cd(
		"Rotom V",
		"Basic",
		"L",
		190,
		"",
		"V",
		[{"name": "Fast Charge", "text": "Draw 3 cards. Your turn ends."}]
	), 0)
	player.active_pokemon = rotom
	var forest_cd := _make_trainer_cd("Forest Seal Stone", "Tool")
	forest_cd.effect_id = "9fa9943ccda36f417ac3cb675177c216"
	forest_cd.description = "The Pokemon V this card is attached to may use this VSTAR Power. [Ability] Star Alchemy: Search your deck for a card and put it into your hand."
	var forest := CardInstance.create(forest_cd, 0)
	rotom.attached_tool = forest
	var ref: Dictionary = builder.legal_action_reference({
		"kind": "use_ability",
		"source_slot": rotom,
		"ability_index": 1,
		"ability_source_card": forest,
		"ability_name": "Star Alchemy",
		"ability_text": forest_cd.description,
		"requires_interaction": true,
	}, gs, 0)
	var card_rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	var ability_rules: Dictionary = ref.get("ability_rules", {}) if ref.get("ability_rules", {}) is Dictionary else {}
	var schema: Dictionary = ref.get("interaction_schema", {}) if ref.get("interaction_schema", {}) is Dictionary else {}
	var route_builder = RouteBuilderScript.new()
	var routes: Array[Dictionary] = route_builder.build_candidate_routes([ref, {"id": "end_turn", "type": "end_turn"}], [], {})
	var route_action_ids: Array[String] = []
	for route: Dictionary in routes:
		for action: Dictionary in route.get("actions", []):
			route_action_ids.append(str(action.get("id", "")))
	return run_checks([
		assert_eq(str(ref.get("ability", "")), "Star Alchemy", "Prompt ref should expose Forest Seal Stone's granted ability name"),
		assert_eq(str(ref.get("card", "")), "Forest Seal Stone", "Prompt ref should use Forest Seal Stone as the ability source card"),
		assert_true((card_rules.get("tags", []) as Array).has("search_deck"), "Forest Seal Stone card rules should carry search_deck tags"),
		assert_true((ability_rules.get("tags", []) as Array).has("search_deck"), "Forest Seal Stone ability rules should carry search_deck tags"),
		assert_true(schema.has("search_targets"), "Star Search should expose a search schema, not Rotom's discard draw schema"),
		assert_false(schema.has("discard_cards"), "Star Search should not inherit Rotom Quick Search discard schema"),
		assert_true(route_action_ids.has("use_ability:active:1"), "Route builder should include Star Search as productive setup before end_turn"),
	])


func test_ultra_ball_discard_protects_missing_dragapult_energy() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var tm_devolution := CardInstance.create(_make_trainer_cd("Technical Machine: Devolution", "Tool"), 0)
	var items: Array = [fire, iono, tm_devolution]
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = llm.call("pick_interaction_items", items, {"id": "discard_cards", "max_select": 1}, context)
	var fire_score: float = float(llm.call("score_interaction_target", fire, {"id": "discard_cards"}, context))
	var iono_score: float = float(llm.call("score_interaction_target", iono, {"id": "discard_cards"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Discard interaction should choose one card"),
		assert_true(picked[0] != fire, "Ultra Ball discard should preserve Fire Energy when active Dragapult ex already has Psychic and needs Fire"),
		assert_true(fire_score < iono_score, "Route-critical missing Dragapult Energy should score lower than expendable supporter discard"),
	])


func test_dragapult_dusknoir_llm_runtime_snapshot_exposes_deck_facts() -> String:
	var llm := _new_strategy(LLM_SCRIPT_PATH)
	if llm == null:
		return "DeckStrategyDragapultDusknoirLLM.gd should instantiate"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var dragapult := _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"N",
		320,
		"Drakloak",
		"ex",
		[],
		[
			{"name": "Jet Head", "cost": "C", "damage": "70"},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
		]
	), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	opponent.bench.clear()
	var bench_target := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	bench_target.damage_counters = 150
	opponent.bench.append(bench_target)
	var snapshot: Dictionary = llm.call("make_llm_runtime_snapshot", gs, 0)
	return run_checks([
		assert_eq(int(snapshot.get("dragapult_ex_count", 0)), 1, "Snapshot should expose Dragapult ex count"),
		assert_eq(int(snapshot.get("dusknoir_line_count", 0)), 1, "Snapshot should expose Dusknoir line count"),
		assert_true(bool(snapshot.get("dragapult_attack_ready", false)), "Snapshot should expose ready Dragapult pressure"),
		assert_true(bool(snapshot.get("phantom_dive_pickoff_visible", false)), "Snapshot should expose visible Phantom Dive bench prize map"),
	])
