class_name TestTunerRunnerArgs
extends TestBase

const TunerRunnerScript = preload("res://scenes/tuner/TunerRunner.gd")


class FakeAgentStore extends RefCounted:
	var loaded_version_path := ""
	var load_latest_calls := 0
	var version_records := {}
	var latest_record := {}

	func load_version(path: String) -> Dictionary:
		loaded_version_path = path
		return (version_records.get(path, {}) as Dictionary).duplicate(true)

	func load_latest() -> Dictionary:
		load_latest_calls += 1
		return latest_record.duplicate(true)


func test_parse_args_reads_agent_config_and_from_latest() -> String:
	var runner = TunerRunnerScript.new()
	if not runner.has_method("parse_args"):
		return "TunerRunner should expose parse_args for deterministic testing"
	var parsed: Dictionary = runner.parse_args([
		"--generations=12",
		"--sigma-w=0.22",
		"--sigma-m=0.18",
		"--max-steps=333",
		"--from-latest",
		"--agent-config=user://ai_agents/agent_v123.json",
		"--value-net=user://models/value_net_v9.json",
		"--progress-output=user://training_data/runs/run_01/status.json",
		"--export-data",
	])
	return run_checks([
		assert_eq(int(parsed.get("generations", 0)), 12, "parse_args should capture generations"),
		assert_eq(float(parsed.get("sigma_weights", 0.0)), 0.22, "parse_args should capture sigma-w"),
		assert_eq(float(parsed.get("sigma_mcts", 0.0)), 0.18, "parse_args should capture sigma-m"),
		assert_eq(int(parsed.get("max_steps", 0)), 333, "parse_args should capture max-steps"),
		assert_true(bool(parsed.get("from_latest", false)), "parse_args should capture from-latest"),
		assert_eq(str(parsed.get("agent_config_path", "")), "user://ai_agents/agent_v123.json", "parse_args should capture explicit agent config"),
		assert_eq(str(parsed.get("value_net_path", "")), "user://models/value_net_v9.json", "parse_args should capture value net"),
		assert_eq(str(parsed.get("progress_output_path", "")), "user://training_data/runs/run_01/status.json", "parse_args should capture progress-output"),
		assert_true(bool(parsed.get("export_data", false)), "parse_args should capture export-data"),
	])


func test_build_initial_config_prefers_explicit_agent_config_over_latest() -> String:
	var runner = TunerRunnerScript.new()
	if not runner.has_method("build_initial_config"):
		return "TunerRunner should expose build_initial_config for deterministic testing"
	var store := FakeAgentStore.new()
	store.version_records["user://ai_agents/explicit.json"] = {
		"heuristic_weights": {"attack_base": 123.0},
		"mcts_config": {"branch_factor": 2, "rollouts_per_sequence": 9, "rollout_max_steps": 111, "time_budget_ms": 3001},
	}
	store.latest_record = {
		"heuristic_weights": {"attack_base": 999.0},
		"mcts_config": {"branch_factor": 5, "rollouts_per_sequence": 50, "rollout_max_steps": 200, "time_budget_ms": 9999},
	}
	var config: Dictionary = runner.build_initial_config({
		"agent_config_path": "user://ai_agents/explicit.json",
		"from_latest": true,
	}, store)
	return run_checks([
		assert_eq(store.loaded_version_path, "user://ai_agents/explicit.json", "explicit agent config should be loaded from the provided path"),
		assert_eq(store.load_latest_calls, 0, "explicit agent config should bypass latest-store lookup"),
		assert_eq(float(config.get("heuristic_weights", {}).get("attack_base", 0.0)), 123.0, "explicit config should win over latest config"),
		assert_eq(int(config.get("mcts_config", {}).get("branch_factor", 0)), 2, "explicit MCTS config should win over latest config"),
	])


func test_build_initial_config_uses_latest_when_requested_without_explicit_path() -> String:
	var runner = TunerRunnerScript.new()
	if not runner.has_method("build_initial_config"):
		return "TunerRunner should expose build_initial_config for deterministic testing"
	var store := FakeAgentStore.new()
	store.latest_record = {
		"heuristic_weights": {"attack_base": 777.0},
		"mcts_config": {"branch_factor": 4, "rollouts_per_sequence": 12, "rollout_max_steps": 99, "time_budget_ms": 4444},
	}
	var config: Dictionary = runner.build_initial_config({
		"from_latest": true,
	}, store)
	return run_checks([
		assert_eq(store.load_latest_calls, 1, "from-latest should load from the store when no explicit path is present"),
		assert_eq(float(config.get("heuristic_weights", {}).get("attack_base", 0.0)), 777.0, "latest heuristic config should be used"),
		assert_eq(int(config.get("mcts_config", {}).get("branch_factor", 0)), 4, "latest MCTS config should be used"),
	])
