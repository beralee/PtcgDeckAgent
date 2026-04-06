class_name TestBattleReviewPromptBuilder
extends TestBase

const PromptBuilderPath := "res://scripts/engine/BattleReviewPromptBuilder.gd"


func _load_builder_script() -> Variant:
	if not ResourceLoader.exists(PromptBuilderPath):
		return null
	return load(PromptBuilderPath)


func _new_builder() -> Variant:
	var script: Variant = _load_builder_script()
	if script == null:
		return {"ok": false, "error": "BattleReviewPromptBuilder script is missing"}

	var builder = (script as GDScript).new()
	if builder == null:
		return {"ok": false, "error": "BattleReviewPromptBuilder could not be instantiated"}

	return {"ok": true, "value": builder}


func test_stage1_payload_contains_version_and_match() -> String:
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewPromptBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("build_stage1_payload"):
		return "BattleReviewPromptBuilder is missing build_stage1_payload"

	var payload: Variant = builder.call("build_stage1_payload", {"winner_index": 0})
	if not payload is Dictionary:
		return "build_stage1_payload should return a Dictionary"

	return run_checks([
		assert_eq(String((payload as Dictionary).get("system_prompt_version", "")), "battle_review_stage1_v3", "Stage 1 payload should expose the upgraded prompt version"),
		assert_true((payload as Dictionary).has("response_format"), "Stage 1 payload should include a response_format schema"),
		assert_eq((payload as Dictionary).get("match", {}), {"winner_index": 0}, "Stage 1 payload should preserve the compact match payload"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("使用双方完整隐藏信息进行赛后分析。"), "Stage 1 instructions should enable hindsight analysis"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("每方恰好选择一个关键回合。"), "Stage 1 instructions should cap the review to one turn per side"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("保持理由简洁具体。"), "Stage 1 instructions should demand concise turn reasons"),
		assert_false(bool(((payload as Dictionary).get("response_format", {}) as Dictionary).get("additionalProperties", true)), "Stage 1 schema should forbid additional top-level properties"),
		assert_true((((payload as Dictionary).get("response_format", {}) as Dictionary).get("required", []) as Array).has("matchup_summary"), "Stage 1 schema should require a matchup summary"),
		assert_false((((payload as Dictionary).get("response_format", {}) as Dictionary).get("required", []) as Array).has("winner_gameplan"), "Stage 1 schema should drop verbose gameplan fields"),
		assert_false((((payload as Dictionary).get("response_format", {}) as Dictionary).get("required", []) as Array).has("loser_gameplan"), "Stage 1 schema should drop verbose gameplan fields"),
		assert_false((((payload as Dictionary).get("response_format", {}) as Dictionary).get("required", []) as Array).has("swing_turns"), "Stage 1 schema should drop explicit swing-turn arrays"),
		assert_eq(int(((((payload as Dictionary).get("response_format", {}) as Dictionary).get("properties", {}) as Dictionary).get("winner_turns", {}) as Dictionary).get("minItems", 0)), 1, "Stage 1 schema should require at least one winner turn"),
		assert_eq(int(((((payload as Dictionary).get("response_format", {}) as Dictionary).get("properties", {}) as Dictionary).get("winner_turns", {}) as Dictionary).get("maxItems", 0)), 1, "Stage 1 schema should cap winner turns at one"),
		assert_eq(int(((((payload as Dictionary).get("response_format", {}) as Dictionary).get("properties", {}) as Dictionary).get("loser_turns", {}) as Dictionary).get("minItems", 0)), 1, "Stage 1 schema should require at least one loser turn"),
		assert_eq(int(((((payload as Dictionary).get("response_format", {}) as Dictionary).get("properties", {}) as Dictionary).get("loser_turns", {}) as Dictionary).get("maxItems", 0)), 1, "Stage 1 schema should cap loser turns at one"),
	])


func test_stage2_payload_contains_turn_packet_and_schema() -> String:
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewPromptBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("build_stage2_payload"):
		return "BattleReviewPromptBuilder is missing build_stage2_payload"

	var payload: Variant = builder.call("build_stage2_payload", {"turn_number": 8})
	if not payload is Dictionary:
		return "build_stage2_payload should return a Dictionary"
	var response_format: Dictionary = (payload as Dictionary).get("response_format", {}) as Dictionary
	var required: Array = response_format.get("required", [])
	var properties: Dictionary = response_format.get("properties", {}) as Dictionary
	var best_line_schema: Dictionary = properties.get("best_line", {}) as Dictionary
	var best_line_properties: Dictionary = best_line_schema.get("properties", {}) as Dictionary
	var best_line_steps_schema: Dictionary = best_line_properties.get("steps", {}) as Dictionary

	return run_checks([
		assert_eq(String((payload as Dictionary).get("system_prompt_version", "")), "battle_review_stage2_v3", "Stage 2 payload should expose the upgraded prompt version"),
		assert_true((payload as Dictionary).has("response_format"), "Stage 2 payload should include a response_format schema"),
		assert_eq((payload as Dictionary).get("turn_packet", {}), {"turn_number": 8}, "Stage 2 payload should preserve the turn packet"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("你是一名世界级PTCG赛后教练，用中文回答。"), "Stage 2 instructions should establish a top-player review frame"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("使用双方完整隐藏信息找出真正最强的实战路线。"), "Stage 2 instructions should allow hindsight analysis"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("在推荐更优路线前，验证对手最早的现实威胁回合，拒绝依赖虚假时机假设的路线。"), "Stage 2 instructions should force timing-window validation"),
		assert_true((payload as Dictionary).get("instructions", PackedStringArray()).has("保持回答简洁：一句总结、最多两个失误、最多四个步骤、一条教训。"), "Stage 2 instructions should enforce brevity"),
		assert_false(bool(response_format.get("additionalProperties", true)), "Stage 2 schema should forbid additional top-level properties"),
		assert_true(required.has("turn_goal"), "Stage 2 schema should require an explicit turn goal"),
		assert_true(required.has("timing_window"), "Stage 2 schema should require timing-window validation"),
		assert_true(required.has("best_line"), "Stage 2 schema should require a best_line object"),
		assert_true(required.has("coach_takeaway"), "Stage 2 schema should require a coach takeaway"),
		assert_false(required.has("root_causes"), "Stage 2 schema should drop verbose root-cause arrays"),
		assert_false(required.has("why_this_is_best_in_matchup"), "Stage 2 schema should drop verbose matchup arrays"),
		assert_false(required.has("expected_opponent_response"), "Stage 2 schema should drop verbose opponent-response arrays"),
		assert_false(required.has("tradeoffs_and_risks"), "Stage 2 schema should drop verbose tradeoff arrays"),
		assert_false(required.has("fallback_line_if_goal_misses"), "Stage 2 schema should drop verbose fallback arrays"),
		assert_false(required.has("better_line"), "Stage 2 schema should drop the duplicate legacy better_line field"),
		assert_false(required.has("why_better"), "Stage 2 schema should drop the duplicate legacy why_better field"),
		assert_eq(int(best_line_steps_schema.get("maxItems", 0)), 4, "Stage 2 best_line steps should cap at four"),
		assert_false(bool(best_line_schema.get("additionalProperties", true)), "Stage 2 best_line schema should forbid additional properties"),
	])
