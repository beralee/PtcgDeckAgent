class_name TestSwissTournament
extends TestBase

const SwissTournamentScript = preload("res://scripts/tournament/SwissTournament.gd")


func test_round_count_matches_supported_sizes() -> String:
	var tournament := SwissTournamentScript.new()
	return run_checks([
		assert_eq(tournament.rounds_for_size(16), 4, "16 人瑞士轮应为 4 轮"),
		assert_eq(tournament.rounds_for_size(32), 5, "32 人瑞士轮应为 5 轮"),
		assert_eq(tournament.rounds_for_size(64), 6, "64 人瑞士轮应为 6 轮"),
		assert_eq(tournament.rounds_for_size(128), 7, "128 人瑞士轮应为 7 轮"),
	])


func test_prepare_next_round_creates_player_pairing_and_full_tables() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	var pairing: Dictionary = tournament.prepare_next_round()
	return run_checks([
		assert_false(pairing.is_empty(), "准备第一轮后应返回玩家配对"),
		assert_eq(int(tournament.current_round), 1, "准备第一轮后 current_round 应为 1"),
		assert_eq(tournament.current_pairings.size(), 8, "16 人赛事第一轮应生成 8 桌配对"),
		assert_true(int(pairing.get("player_a_id", -1)) == 0 or int(pairing.get("player_b_id", -1)) == 0, "玩家配对应包含玩家本人"),
	])


func test_record_player_match_updates_points_and_summary() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	tournament.prepare_next_round()
	var summary: Dictionary = tournament.record_player_match(true, "normal")
	var player := tournament._participant_by_id(0)
	return run_checks([
		assert_eq(str(summary.get("result", "")), "win", "玩家获胜后 summary 结果应为 win"),
		assert_eq(int(player.get("wins", 0)), 1, "玩家获胜后胜场应加 1"),
		assert_eq(int(player.get("points", 0)), 3, "玩家获胜后积分应为 3"),
		assert_true(bool(summary.get("is_final_round", false)) == false, "第一轮结束后不应被标为最终轮"),
	])


func test_field_uses_supported_ai_decks_and_random_modes() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	var supported_ids := CardDatabase.get_supported_ai_deck_ids()
	var invalid_deck_count := 0
	var valid_mode_count := 0
	for participant: Dictionary in tournament.participants:
		if bool(participant.get("is_player", false)):
			continue
		if not supported_ids.has(int(participant.get("deck_id", 0))):
			invalid_deck_count += 1
		var ai_mode := str(participant.get("ai_mode", ""))
		if ai_mode in ["strong", "weak"]:
			valid_mode_count += 1
	return run_checks([
		assert_eq(invalid_deck_count, 0, "比赛模式 AI 参赛者只能使用 BattleSetup 短名单里的 AI 卡组"),
		assert_eq(valid_mode_count, tournament.participants.size() - 1, "所有 AI 参赛者都应被标记为 strong 或 weak"),
	])


func test_field_can_include_all_llm_deck_variants_when_enabled() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345, true)
	var supported_ids := CardDatabase.get_supported_ai_deck_ids()
	var llm_deck_pool: Array = tournament.call("get_llm_deck_pool")
	llm_deck_pool.sort()
	var llm_pool_not_supported := 0
	var llm_pool_missing_strategy := 0
	for deck_id_variant: Variant in llm_deck_pool:
		var pool_deck_id := int(deck_id_variant)
		if not supported_ids.has(pool_deck_id):
			llm_pool_not_supported += 1
		if str(tournament.call("llm_strategy_id_for_deck_id", pool_deck_id)) == "":
			llm_pool_missing_strategy += 1
	var llm_count := 0
	var llm_deck_not_supported := 0
	var missing_strategy_count := 0
	for participant: Dictionary in tournament.participants:
		if str(participant.get("ai_mode", "")) != "llm":
			continue
		llm_count += 1
		var deck_id := int(participant.get("deck_id", 0))
		if not supported_ids.has(deck_id):
			llm_deck_not_supported += 1
		if str(tournament.call("llm_strategy_id_for_deck_id", deck_id)) == "":
			missing_strategy_count += 1
	var expected_v17_llm := {
		1700002: "v17_archaludon_dialga_llm",
		1700003: "v17_water_turtle_llm",
		1700004: "v17_palkia_gholdengo_llm",
		1700005: "v17_bomb_charizard_llm",
		1700007: "v17_miraidon_llm",
		1700008: "v17_dragapult_dusknoir_llm",
		1700011: "v17_regidrago_llm",
		609431: "v175_lugia_archeops_llm",
		1750002: "v175_pure_dragapult_llm",
		610080: "v175_gardevoir_llm",
	}
	var checks: Array[String] = [
		assert_true(llm_deck_pool.size() >= 15, "LLM pool should keep all old and v17 strategy-backed LLM deck variants"),
		assert_eq(llm_pool_not_supported, 0, "LLM pool should stay inside the supported AI deck list"),
		assert_eq(llm_pool_missing_strategy, 0, "Every LLM pool deck should map to an LLM strategy id"),
		assert_true(llm_count >= 1, "AI 设置测试通过后，比赛参赛池应至少引入一个 LLM 对手"),
		assert_eq(llm_deck_not_supported, 0, "LLM 对手只能使用 AI 可选卡组"),
		assert_eq(missing_strategy_count, 0, "每个 LLM 对手卡组都必须能映射到对应 LLM strategy id"),
	]
	for deck_id: int in expected_v17_llm.keys():
		checks.append(assert_true(deck_id in llm_deck_pool, "LLM pool should include v17/v17.5 deck %d" % deck_id))
		checks.append(assert_eq(str(tournament.call("llm_strategy_id_for_deck_id", deck_id)), str(expected_v17_llm[deck_id]), "v17/v17.5 deck %d should map to its LLM strategy" % deck_id))
	return run_checks(checks)


func test_strong_ai_always_beats_weak_ai_in_simulation() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	tournament.participants = [
		{
			"id": 1,
			"name": "强AI",
			"deck_id": 575720,
			"is_player": false,
			"ai_mode": "strong",
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"points": 0,
			"opponent_points": 0.0,
			"opponents": [],
			"rounds": [],
		},
		{
			"id": 2,
			"name": "弱AI",
			"deck_id": 575716,
			"is_player": false,
			"ai_mode": "weak",
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"points": 0,
			"opponent_points": 0.0,
			"opponents": [],
			"rounds": [],
		},
	]
	var result: Dictionary = tournament._simulate_match(1, 2)
	return run_checks([
		assert_eq(int(result.get("winner_id", -1)), 1, "AI 对 AI 时，strong 对 weak 应固定由 strong 获胜"),
	])


func test_llm_ai_simulation_rates_match_contract() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345, true)
	return run_checks([
		assert_eq(float(tournament._llm_win_probability_against_mode("strong")), 0.60, "LLM 对手遇到规则版强 AI 应按 60% 胜率模拟"),
		assert_eq(float(tournament._llm_win_probability_against_mode("weak")), 1.0, "LLM 对手遇到弱 AI 应按 100% 胜率模拟"),
	])
