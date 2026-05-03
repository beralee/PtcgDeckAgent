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
	return assert_true(damaged_score > healthy_score, "Spread counter scoring should prefer a damaged multi-prize bench conversion target")


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
	var bad_crystal := {
		"action_id": "attach_tool:test_bad_crystal",
		"id": "attach_tool:test_bad_crystal",
		"kind": "attach_tool",
		"card": crystal,
		"target_slot": fezandipiti,
	}
	var bad_energy := {"kind": "attach_energy", "card": psychic, "target_slot": duskull}
	_activate_llm_queue(llm, int(gs.turn_number), [bad_crystal])
	var queued_bad_crystal_score: float = float(llm.call("score_action_absolute", bad_crystal, gs, 0))
	llm.set("_llm_queue_turn", -1)
	llm.set("_llm_action_queue", [])
	llm.set("_llm_action_catalog", {})
	var fallback_bad_crystal_absolute: float = float(llm.call("score_action_absolute", bad_crystal, gs, 0))
	var fallback_bad_crystal_score: float = float(llm.call("score_action", bad_crystal, {"game_state": gs, "player_index": 0}))
	var fallback_bad_energy_score: float = float(llm.call("score_action", bad_energy, {"game_state": gs, "player_index": 0}))
	var compact_bad_crystal := {"kind": "attach_tool", "card": {"name_en": "Sparkling Crystal"}, "target": {"name_en": "Fezandipiti ex"}}
	var compact_bad_energy := {"kind": "attach_energy", "card": {"name_en": "Psychic Energy"}, "target": {"name_en": "Duskull"}}
	var compact_bad_crystal_score: float = float(llm.call("score_action", compact_bad_crystal, {"game_state": gs, "player_index": 0}))
	var compact_bad_energy_score: float = float(llm.call("score_action", compact_bad_energy, {"game_state": gs, "player_index": 0}))
	return run_checks([
		assert_true(queued_bad_crystal_score <= -1000.0, "Bad tool targets should be blocked before a matching active LLM queue can force them"),
		assert_true(fallback_bad_crystal_absolute <= -1000.0, "Bad tool targets should remain blocked after the LLM queue has cleared"),
		assert_true(fallback_bad_crystal_score <= -1000.0, "Fallback score_action should not re-enable bad Sparkling Crystal targets"),
		assert_true(fallback_bad_energy_score <= -1000.0, "Fallback score_action should not re-enable Duskull/Dusclops/Dusknoir energy targets when Dragapult line exists"),
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
