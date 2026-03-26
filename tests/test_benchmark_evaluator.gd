class_name TestBenchmarkEvaluator
extends TestBase

const BenchmarkEvaluatorScript = preload("res://scripts/ai/BenchmarkEvaluator.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")


func _make_identity_hits(
	miraidon_bench_developed: bool,
	electric_generator_resolved: bool,
	miraidon_attack_ready: bool,
	gardevoir_stage2_online: bool,
	psychic_embrace_resolved: bool,
	gardevoir_energy_loop_online: bool,
	charizard_stage2_online: bool = false,
	charizard_evolution_support_used: bool = false,
	charizard_attack_ready: bool = false
) -> Dictionary:
	return {
		"miraidon_bench_developed": miraidon_bench_developed,
		"electric_generator_resolved": electric_generator_resolved,
		"miraidon_attack_ready": miraidon_attack_ready,
		"gardevoir_stage2_online": gardevoir_stage2_online,
		"psychic_embrace_resolved": psychic_embrace_resolved,
		"gardevoir_energy_loop_online": gardevoir_energy_loop_online,
		"charizard_stage2_online": charizard_stage2_online,
		"charizard_evolution_support_used": charizard_evolution_support_used,
		"charizard_attack_ready": charizard_attack_ready,
	}


func _make_match(
	seed: int,
	winner_index: int,
	turn_count: int,
	failure_reason: String,
	stalled: bool,
	terminated_by_cap: bool,
	identity_hits: Dictionary,
	player_0_deck_id: int = 575720,
	player_1_deck_id: int = 578647
) -> Dictionary:
	return {
		"deck_a": {"deck_id": 575720, "deck_key": "miraidon"},
		"deck_b": {"deck_id": 578647, "deck_key": "gardevoir"},
		"seed": seed,
		"winner_index": winner_index,
		"turn_count": turn_count,
		"steps": turn_count,
		"terminated_by_cap": terminated_by_cap,
		"stalled": stalled,
		"failure_reason": failure_reason,
		"event_counters": {},
		"identity_hits": identity_hits,
		"player_0_deck_id": player_0_deck_id,
		"player_1_deck_id": player_1_deck_id,
	}


func _make_sample_matches() -> Array[Dictionary]:
	return [
		_make_match(11, 0, 10, "normal_game_end", false, false, _make_identity_hits(true, true, false, true, true, false)),
		_make_match(29, 1, 20, "action_cap_reached", false, true, _make_identity_hits(false, true, true, false, true, true)),
		_make_match(47, 0, 30, "stalled_no_progress", true, false, _make_identity_hits(true, false, false, true, false, true)),
		_make_match(83, 1, 40, "normal_game_end", false, false, _make_identity_hits(false, false, false, false, false, false)),
	]


func test_benchmark_evaluator_emits_full_pairing_summary_shape() -> String:
	var evaluator := BenchmarkEvaluatorScript.new()
	var summary: Dictionary = evaluator.summarize_pairing(_make_sample_matches(), "miraidon_vs_gardevoir")
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	return run_checks([
		assert_eq(summary.get("pairing", ""), "miraidon_vs_gardevoir", "Summary should preserve the pairing name"),
		assert_eq(summary.get("total_matches", -1), 4, "Summary should report total matches"),
		assert_eq(summary.get("wins_a", -1), 2, "Summary should count deck A wins"),
		assert_eq(summary.get("wins_b", -1), 2, "Summary should count deck B wins"),
		assert_eq(summary.get("win_rate_a", -1.0), 0.5, "Deck A win rate should be normalized by total matches"),
		assert_eq(summary.get("win_rate_b", -1.0), 0.5, "Deck B win rate should be normalized by total matches"),
		assert_eq(summary.get("average_turn_count", -1.0), 25.0, "Average turn count should be computed from all matches"),
		assert_eq(summary.get("avg_turn_count", -1.0), 25.0, "Legacy average turn count alias should stay coherent"),
		assert_eq(summary.get("stall_rate", -1.0), 0.25, "Stall rate should be derived from stalled matches"),
		assert_eq(summary.get("cap_termination_rate", -1.0), 0.25, "Cap termination rate should be derived from capped matches"),
		assert_true(summary.has("failure_breakdown"), "Summary should expose failure_breakdown"),
		assert_true(summary.has("identity_check_pass_rate"), "Summary should expose identity_check_pass_rate"),
		assert_true(summary.has("identity_event_breakdown"), "Summary should expose identity_event_breakdown"),
		assert_eq(identity_breakdown.size(), 9, "Identity breakdown should include the exact nine spec events"),
		assert_true(identity_breakdown.has("miraidon_bench_developed"), "Identity breakdown should include the Miraidon bench event"),
		assert_true(identity_breakdown.has("electric_generator_resolved"), "Identity breakdown should include the Electric Generator event"),
		assert_true(identity_breakdown.has("miraidon_attack_ready"), "Identity breakdown should include the Miraidon attack event"),
		assert_true(identity_breakdown.has("gardevoir_stage2_online"), "Identity breakdown should include the Gardevoir stage 2 event"),
		assert_true(identity_breakdown.has("psychic_embrace_resolved"), "Identity breakdown should include the Psychic Embrace event"),
		assert_true(identity_breakdown.has("gardevoir_energy_loop_online"), "Identity breakdown should include the Gardevoir energy loop event"),
		assert_true(identity_breakdown.has("charizard_stage2_online"), "Identity breakdown should include the Charizard stage 2 event"),
		assert_true(identity_breakdown.has("charizard_evolution_support_used"), "Identity breakdown should include the Charizard support event"),
		assert_true(identity_breakdown.has("charizard_attack_ready"), "Identity breakdown should include the Charizard attack event"),
	])


func test_benchmark_evaluator_aggregates_identity_event_breakdown() -> String:
	var evaluator := BenchmarkEvaluatorScript.new()
	var summary: Dictionary = evaluator.summarize_pairing(_make_sample_matches(), "miraidon_vs_gardevoir")
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	var failure_breakdown: Dictionary = summary.get("failure_breakdown", {})
	var miraidon_bench: Dictionary = identity_breakdown.get("miraidon_bench_developed", {})
	var miraidon_attack: Dictionary = identity_breakdown.get("miraidon_attack_ready", {})
	var gardevoir_loop: Dictionary = identity_breakdown.get("gardevoir_energy_loop_online", {})
	var charizard_attack: Dictionary = identity_breakdown.get("charizard_attack_ready", {})
	return run_checks([
		assert_eq(miraidon_bench.get("applicable_matches", -1), 4, "Miraidon events should apply to all matches in the pairing"),
		assert_eq(miraidon_bench.get("hit_matches", -1), 2, "Miraidon bench development should be counted twice"),
		assert_eq(miraidon_bench.get("hit_rate", -1.0), 0.5, "Miraidon bench development should have a 50% hit rate"),
		assert_eq(miraidon_attack.get("applicable_matches", -1), 4, "Miraidon attack readiness should apply to all matches in the pairing"),
		assert_eq(miraidon_attack.get("hit_matches", -1), 1, "Miraidon attack readiness should be counted once"),
		assert_eq(miraidon_attack.get("hit_rate", -1.0), 0.25, "Miraidon attack readiness should use the full match divisor"),
		assert_eq(gardevoir_loop.get("applicable_matches", -1), 4, "Gardevoir loop events should apply to all matches in the pairing"),
		assert_eq(gardevoir_loop.get("hit_matches", -1), 2, "Gardevoir loop readiness should be counted twice"),
		assert_eq(gardevoir_loop.get("hit_rate", -1.0), 0.5, "Gardevoir loop readiness should have a 50% hit rate"),
		assert_eq(charizard_attack.get("applicable_matches", -1), 0, "Unpaired deck identities should not be marked applicable"),
		assert_eq(charizard_attack.get("hit_matches", -1), 0, "Unpaired deck identities should not count hits"),
		assert_eq(charizard_attack.get("hit_rate", -1.0), 0.0, "Unpaired deck identities should stay at zero hit rate"),
		assert_eq(summary.get("identity_check_pass_rate", -1.0), 5.0 / 6.0, "Identity pass rate should be derived from applicable per-event hit rates"),
		assert_eq(failure_breakdown.get("action_cap_reached", 0), 1, "Failure breakdown should count capped matches"),
		assert_eq(failure_breakdown.get("stalled_no_progress", 0), 1, "Failure breakdown should count stalled matches"),
		assert_false(failure_breakdown.has("normal_game_end"), "Normal game ends should not appear in the failure breakdown"),
	])


func test_benchmark_evaluator_text_summary_includes_pairing_win_rate_and_failure_counts() -> String:
	var evaluator := BenchmarkEvaluatorScript.new()
	var summary: Dictionary = evaluator.summarize_pairing(_make_sample_matches(), "miraidon_vs_gardevoir")
	var text_summary := evaluator.build_text_summary(summary)
	return run_checks([
		assert_str_contains(text_summary, "miraidon_vs_gardevoir", "Text summary should include the pairing name"),
		assert_str_contains(text_summary, "win_rate_a=50.0%", "Text summary should include deck A win rate"),
		assert_str_contains(text_summary, "win_rate_b=50.0%", "Text summary should include deck B win rate"),
		assert_str_contains(text_summary, "stalls=1", "Text summary should include stall counts"),
		assert_str_contains(text_summary, "caps=1", "Text summary should include cap counts"),
		assert_str_contains(text_summary, "identity_check_pass_rate=83.3%", "Text summary should include the identity pass rate"),
	])


func test_benchmark_evaluator_attributes_wins_correctly_when_seats_swap() -> String:
	var evaluator := BenchmarkEvaluatorScript.new()
	var summary: Dictionary = evaluator.summarize_pairing([
		_make_match(11, 0, 10, "normal_game_end", false, false, _make_identity_hits(true, false, false, true, false, false), 578647, 575720),
		_make_match(29, 1, 12, "normal_game_end", false, false, _make_identity_hits(false, true, true, false, true, true), 578647, 575720),
	], "miraidon_vs_gardevoir")
	return run_checks([
		assert_eq(summary.get("wins_a", -1), 1, "Deck A should get credit when it wins from player 1 after a seat swap"),
		assert_eq(summary.get("wins_b", -1), 1, "Deck B should get credit when it wins from player 0 after a seat swap"),
		assert_eq(summary.get("win_rate_a", -1.0), 0.5, "Deck A win rate should stay normalized under seat-swapped attribution"),
		assert_eq(summary.get("win_rate_b", -1.0), 0.5, "Deck B win rate should stay normalized under seat-swapped attribution"),
	])


func test_benchmark_runner_surfaces_structured_summary_and_text_summary() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var benchmark_case = DeckBenchmarkCaseScript.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.seed_set = [11]
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.resolve_decks()
	var result: Dictionary = runner.run_and_summarize_case(benchmark_case)
	var summary: Dictionary = result.get("summary", {})
	var text_summary: String = str(result.get("text_summary", ""))
	var raw_result: Dictionary = result.get("raw_result", {})
	return run_checks([
		assert_true(result.has("raw_result"), "Structured benchmark runs should retain the raw result payload"),
		assert_true(result.has("summary"), "Structured benchmark runs should include a summary payload"),
		assert_true(result.has("text_summary"), "Structured benchmark runs should include a text summary payload"),
		assert_eq(raw_result.get("match_count", -1), 2, "A single seed should expand to two seat-swapped matches"),
		assert_eq(summary.get("pairing", ""), "miraidon_vs_gardevoir", "Structured summaries should preserve the pairing name"),
		assert_eq(summary.get("total_matches", -1), 2, "Structured summaries should reflect the executed match count"),
		assert_str_contains(text_summary, "miraidon_vs_gardevoir", "Structured text summaries should include the pairing name"),
		assert_str_contains(text_summary, "stalls=", "Structured text summaries should include failure counts"),
		assert_str_contains(text_summary, "caps=", "Structured text summaries should include cap counts"),
	])


func test_benchmark_runner_surfaces_errors_without_fake_empty_summary() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var benchmark_case = DeckBenchmarkCaseScript.new()
	benchmark_case.deck_a_id = 0
	benchmark_case.deck_b_id = 578647
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	var result: Dictionary = runner.run_and_summarize_case(benchmark_case)
	var errors_variant: Variant = result.get("errors", PackedStringArray())
	var errors: PackedStringArray = errors_variant if errors_variant is PackedStringArray else PackedStringArray()
	return run_checks([
		assert_false(errors.is_empty(), "Structured benchmark runs should surface raw benchmark errors"),
		assert_eq(result.get("summary", {}), {}, "Structured benchmark runs should not emit a normal-looking empty summary when the raw run fails"),
		assert_eq(str(result.get("text_summary", "")), "", "Structured benchmark runs should not emit a text summary when the raw run fails"),
	])
