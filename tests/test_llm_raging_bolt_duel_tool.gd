class_name TestLLMRagingBoltDuelTool
extends TestBase

const DuelToolPath := "res://scripts/ai/LLMRagingBoltDuelTool.gd"
const SelfPlayToolPath := "res://scripts/tools/RagingBoltLLMSelfPlayTool.gd"
const SelfPlayRunnerPath := "res://scripts/tools/run_raging_bolt_llm_self_play.gd"
const DuelRunnerPath := "res://scripts/tools/run_llm_raging_bolt_duel.gd"


func test_duel_tool_loads_and_exposes_default_matchup() -> String:
	if not ResourceLoader.exists(DuelToolPath):
		return "LLMRagingBoltDuelTool script should exist"
	var script: Variant = load(DuelToolPath)
	if not script is GDScript:
		return "LLMRagingBoltDuelTool should load as GDScript"
	var tool: Node = (script as GDScript).new()
	var options: Dictionary = tool.call("build_default_options")
	tool.queue_free()
	return run_checks([
		assert_eq(int(options.get("miraidon_deck_id", -1)), 575720, "Tool should default player 0 to Miraidon"),
		assert_eq(int(options.get("raging_bolt_deck_id", -1)), 575718, "Tool should default player 1 to Raging Bolt"),
		assert_eq(int(options.get("rule_deck_id", -1)), 575720, "Generic rule-vs-LLM options should default rules side to Miraidon"),
		assert_eq(int(options.get("llm_deck_id", -1)), 575718, "Generic rule-vs-LLM options should default LLM side to Raging Bolt"),
		assert_eq(str(options.get("rule_strategy_id", "")), "miraidon", "Generic rule side should use the rules strategy id"),
		assert_eq(str(options.get("llm_strategy_id", "")), "raging_bolt_ogerpon_llm", "Generic LLM side should use the LLM strategy id"),
		assert_eq(str(options.get("output_root", "")), "user://match_records/ai_duels", "Tool should record AI-vs-AI duel logs under a dedicated root"),
		assert_true(options.has("max_game_seconds"), "Tool should expose a per-game wall-clock cap for parallel LLM validation"),
		assert_true(options.has("strong_fixed_opening"), "Tool should expose strong fixed opening validation mode"),
		assert_true(options.has("rule_strong_fixed_opening"), "Tool should allow rules-side fixed opening validation"),
		assert_true(options.has("llm_strong_fixed_opening"), "Tool should allow LLM-side fixed opening validation"),
		assert_true(bool(options.get("record_match", false)), "Tool should record match logs by default"),
		assert_true(tool.has_method("run_rule_vs_llm"), "Tool should expose the generic rule-vs-LLM runner method"),
		assert_true(tool.has_method("run_rule_miraidon_vs_llm_raging_bolt"), "Tool should keep the legacy Raging Bolt duel method for compatibility"),
	])


func test_duel_tool_exposes_llm_raging_bolt_self_play_options() -> String:
	if not ResourceLoader.exists(DuelToolPath):
		return "LLMRagingBoltDuelTool script should exist"
	var script: Variant = load(DuelToolPath)
	if not script is GDScript:
		return "LLMRagingBoltDuelTool should load as GDScript"
	var tool: Node = (script as GDScript).new()
	var options: Dictionary = tool.call("build_self_play_options")
	tool.queue_free()
	return run_checks([
		assert_eq(str(options.get("mode", "")), "llm_raging_bolt_self_play", "Tool should expose a dedicated self-play mode"),
		assert_eq(int(options.get("player_0_deck_id", -1)), 575718, "Self-play player 0 should use Raging Bolt"),
		assert_eq(int(options.get("player_1_deck_id", -1)), 575718, "Self-play player 1 should use Raging Bolt"),
		assert_eq(str(options.get("player_0_strategy_id", "")), "raging_bolt_ogerpon_llm", "Self-play player 0 should use the LLM strategy"),
		assert_eq(str(options.get("player_1_strategy_id", "")), "raging_bolt_ogerpon_llm", "Self-play player 1 should use the LLM strategy"),
		assert_true(tool.has_method("run_llm_self_play"), "Tool should expose the generic LLM self-play runner method"),
		assert_true(tool.has_method("run_llm_raging_bolt_self_play"), "Tool should expose the self-play runner method"),
	])


func test_duel_tool_make_ai_accepts_generic_llm_strategy_ids() -> String:
	if not ResourceLoader.exists(DuelToolPath):
		return "LLMRagingBoltDuelTool script should exist"
	var script: Variant = load(DuelToolPath)
	if not script is GDScript:
		return "LLMRagingBoltDuelTool should load as GDScript"
	var tool: Node = (script as GDScript).new()
	var dragapult_ai: AIOpponent = tool.call("_make_ai", 1, "dragapult_charizard_llm", null, true)
	var charizard_ai: AIOpponent = tool.call("_make_ai", 1, "charizard_ex_llm", null, true)
	var arceus_ai: AIOpponent = tool.call("_make_ai", 1, "arceus_giratina_llm", null, true)
	var dragapult_strategy: Variant = dragapult_ai.get("_deck_strategy") if dragapult_ai != null else null
	var charizard_strategy: Variant = charizard_ai.get("_deck_strategy") if charizard_ai != null else null
	var arceus_strategy: Variant = arceus_ai.get("_deck_strategy") if arceus_ai != null else null
	tool.queue_free()
	return run_checks([
		assert_not_null(dragapult_strategy, "Generic duel tool should install Dragapult Charizard LLM strategy"),
		assert_true(dragapult_strategy != null and dragapult_strategy.has_method("get_llm_stats"), "Dragapult Charizard strategy should expose LLM runtime stats"),
		assert_not_null(charizard_strategy, "Generic duel tool should install Charizard ex LLM strategy"),
		assert_true(charizard_strategy != null and charizard_strategy.has_method("get_llm_stats"), "Charizard ex strategy should expose LLM runtime stats"),
		assert_not_null(arceus_strategy, "Generic duel tool should install Arceus Giratina LLM strategy"),
		assert_true(arceus_strategy != null and arceus_strategy.has_method("get_llm_stats"), "Arceus Giratina strategy should expose LLM runtime stats"),
	])


func test_standalone_self_play_runner_scripts_load() -> String:
	if not ResourceLoader.exists(SelfPlayToolPath):
		return "RagingBoltLLMSelfPlayTool script should exist"
	if not ResourceLoader.exists(SelfPlayRunnerPath):
		return "run_raging_bolt_llm_self_play script should exist"
	if not ResourceLoader.exists(DuelRunnerPath):
		return "run_llm_raging_bolt_duel script should exist"
	var tool_script: Variant = load(SelfPlayToolPath)
	var runner_script: Variant = load(SelfPlayRunnerPath)
	var duel_runner_script: Variant = load(DuelRunnerPath)
	if not tool_script is GDScript:
		return "RagingBoltLLMSelfPlayTool should load as GDScript"
	var tool: RefCounted = (tool_script as GDScript).new()
	return run_checks([
		assert_not_null(tool, "RagingBoltLLMSelfPlayTool should instantiate"),
		assert_true(tool.has_method("run"), "Standalone self-play tool should expose run(options, tree)"),
		assert_true(runner_script is GDScript, "Standalone self-play CLI runner should load as GDScript"),
		assert_true(duel_runner_script is GDScript, "LLMRagingBoltDuelTool CLI runner should load as GDScript"),
	])
