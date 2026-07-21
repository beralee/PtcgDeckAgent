class_name TestDeckBenchmarkProvenance
extends TestBase

const BenchmarkScript = preload("res://scripts/training/run_deck_benchmark.gd")


func test_benchmark_provenance_fingerprints_source_strategy_and_fixed_opening() -> String:
	var runner = BenchmarkScript.new()
	var required_methods := [
		"_build_source_provenance",
		"_build_strategy_provenance",
		"_build_file_provenance",
		"_attach_trace_provenance",
	]
	var checks: Array[String] = []
	for method_name: String in required_methods:
		checks.append(assert_true(runner.has_method(method_name), "Benchmark runner should expose %s" % method_name))
	if not checks.all(func(result: String) -> bool: return result == ""):
		return run_checks(checks)

	var source: Dictionary = runner.call("_build_source_provenance")
	var source_again: Dictionary = runner.call("_build_source_provenance")
	var deck := DeckData.new()
	deck.id = 800018499
	var strategy: Dictionary = runner.call("_build_strategy_provenance", deck)
	var fixed: Dictionary = runner.call(
		"_build_file_provenance",
		"res://data/bundled_user/ai_fixed_deck_orders/800018499.json"
	)
	var trace_payload := {"chosen_action": {"kind": "end_turn"}}
	var trace_provenance := {
		"schema_version": 1,
		"seed": 15300,
		"tracked_player": 0,
	}
	var decorated: Dictionary = runner.call("_attach_trace_provenance", trace_payload, trace_provenance)

	checks.append_array([
		assert_eq(str(source.get("algorithm", "")), "sha256", "Source provenance should name its digest algorithm"),
		assert_eq(str(source.get("fingerprint", "")).length(), 64, "AI source fingerprint should be a SHA-256 digest"),
		assert_eq(source_again.get("fingerprint", ""), source.get("fingerprint", ""), "Unchanged source trees should produce a deterministic fingerprint"),
		assert_true(int(source.get("file_count", 0)) > 1, "Source fingerprint should cover the AI tree and benchmark runner"),
		assert_true(int(source.get("latest_mtime_unix", 0)) > 0, "Source provenance should record the latest source modification time"),
		assert_eq(str(strategy.get("strategy_id", "")), "v18_800018499_pure_dragapult", "Strategy provenance should resolve the exact deck strategy"),
		assert_eq(str(strategy.get("script_path", "")), "res://scripts/ai/DeckStrategyV18Rules.gd", "Strategy provenance should record the instantiated wrapper script"),
		assert_eq(str(strategy.get("delegate", {}).get("path", "")), "res://scripts/ai/DeckStrategy175PureDragapult.gd", "V18 strategy provenance should record the actual delegate script"),
		assert_eq(str(fixed.get("sha256", "")).length(), 64, "Fixed opening provenance should fingerprint the order file"),
		assert_true(int(fixed.get("mtime_unix", 0)) > 0, "Fixed opening provenance should record file modification time"),
		assert_eq(int(decorated.get("provenance", {}).get("seed", -1)), 15300, "Trace payload should carry the exact benchmark seed"),
		assert_false(trace_payload.has("provenance"), "Decorating a trace should not mutate the frozen decision payload"),
	])
	return run_checks(checks)
