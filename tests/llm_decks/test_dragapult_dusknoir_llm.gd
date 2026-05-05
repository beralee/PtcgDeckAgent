class_name TestDragapultDusknoirLLM
extends TestBase

const RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultDusknoir.gd"
const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd"
const RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"


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
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	var dragapult := _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.active_pokemon = dreepy
	player.bench.clear()
	player.bench.append(dragapult)
	player.bench.append(duskull)
	player.bench.append(rotom)
	player.bench.append(lumineon)
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var forest_seal := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	return run_checks([
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": crystal, "target_slot": duskull}, gs, 0)), "Sparkling Crystal should not attach to Duskull"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": crystal, "target_slot": dreepy}, gs, 0)), "Sparkling Crystal should be allowed on Dreepy"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": crystal, "target_slot": dragapult}, gs, 0)), "Sparkling Crystal should be allowed on Dragapult ex"),
		assert_true(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": forest_seal, "target_slot": dragapult}, gs, 0)), "Forest Seal Stone should not attach to Dragapult ex"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": forest_seal, "target_slot": rotom}, gs, 0)), "Forest Seal Stone should be allowed on Rotom V"),
		assert_false(bool(llm.call("_deck_should_block_exact_queue_match", {}, {"kind": "attach_tool", "card": forest_seal, "target_slot": lumineon}, gs, 0)), "Forest Seal Stone should be allowed on Lumineon V"),
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
	return run_checks([
		assert_true(blocked_without_window, "TM Devolution should not attach early when the opponent has no evolved damaged target"),
		assert_false(blocked_with_window, "TM Devolution should remain available once a real devolution prize window exists"),
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
