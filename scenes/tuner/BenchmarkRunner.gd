extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")
const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
const TrainingRunRegistryScript = preload("res://scripts/ai/TrainingRunRegistry.gd")
const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")

const DEFAULT_SUMMARY_OUTPUT := "user://benchmark_summary.json"
const DEFAULT_GATE_THRESHOLD := 0.55


func _ready() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	var summary := run_benchmark_from_args(args)
	_write_json(str(args.get("summary-output", DEFAULT_SUMMARY_OUTPUT)), summary)
	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_with_summary", summary)


func parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in args:
		if not raw_arg.begins_with("--"):
			continue
		var arg := raw_arg.trim_prefix("--")
		var separator := arg.find("=")
		if separator == -1:
			parsed[arg] = true
			continue
		parsed[arg.substr(0, separator)] = arg.substr(separator + 1)
	return parsed


func run_benchmark_from_args(args: Dictionary) -> Dictionary:
	var candidate_agent_path := str(args.get("agent-a-config", ""))
	var baseline_agent_path := str(args.get("agent-b-config", ""))
	var candidate_config := _load_agent_config(candidate_agent_path)
	var baseline_config := _load_agent_config(baseline_agent_path)

	candidate_config["agent_id"] = str(args.get("agent-id", candidate_config.get("agent_id", "trained-ai")))
	baseline_config["agent_id"] = str(args.get("agent-id", baseline_config.get("agent_id", "trained-ai")))
	candidate_config["version_tag"] = str(args.get("version-a-tag", "candidate"))
	baseline_config["version_tag"] = str(args.get("version-b-tag", "current-best"))

	var candidate_value_net := str(args.get("value-net-a", candidate_config.get("value_net_path", "")))
	var baseline_value_net := str(args.get("value-net-b", baseline_config.get("value_net_path", "")))
	candidate_config["value_net_path"] = candidate_value_net
	baseline_config["value_net_path"] = baseline_value_net

	var runner := AIBenchmarkRunnerScript.new()
	var case_results: Array[Dictionary] = []
	for benchmark_case: Variant in build_fixed_three_deck_cases(candidate_config, baseline_config):
		if benchmark_case == null:
			continue
		var case_result: Dictionary = runner.run_and_summarize_case(benchmark_case)
		case_results.append({
			"pairing_name": benchmark_case.get_pairing_name(),
			"summary": case_result.get("summary", {}),
			"text_summary": str(case_result.get("text_summary", "")),
			"errors": case_result.get("errors", PackedStringArray()),
			"regression_gate_passed": bool(case_result.get("regression_gate_passed", false)),
		})

	var threshold := float(args.get("gate-threshold", DEFAULT_GATE_THRESHOLD))
	var summary := aggregate_case_results(case_results, threshold)
	summary["candidate_agent_config_path"] = candidate_agent_path
	summary["baseline_agent_config_path"] = baseline_agent_path
	summary["candidate_value_net_path"] = candidate_value_net
	summary["baseline_value_net_path"] = baseline_value_net
	summary["summary_output"] = str(args.get("summary-output", DEFAULT_SUMMARY_OUTPUT))

	_publish_and_record(args, summary)
	return summary


func build_fixed_three_deck_cases(candidate_config: Dictionary, baseline_config: Dictionary) -> Array:
	var cases: Array = DeckBenchmarkCaseScript.make_phase2_default_cases()
	for benchmark_case: Variant in cases:
		benchmark_case.comparison_mode = "version_regression"
		benchmark_case.agent_a_config = candidate_config.duplicate(true)
		benchmark_case.agent_b_config = baseline_config.duplicate(true)
	return cases


func aggregate_case_results(case_results: Array, gate_threshold: float = DEFAULT_GATE_THRESHOLD) -> Dictionary:
	var total_matches := 0
	var version_a_wins := 0
	var version_b_wins := 0
	var timeouts := 0
	var failures := 0
	var all_cases_passed := true
	var pairing_results: Array[Dictionary] = []

	for case_variant: Variant in case_results:
		if not case_variant is Dictionary:
			continue
		var case_result: Dictionary = case_variant
		var summary: Dictionary = case_result.get("summary", {})
		var total_case_matches := int(summary.get("total_matches", 0))
		total_matches += total_case_matches
		version_a_wins += int(summary.get("version_a_wins", 0))
		version_b_wins += int(summary.get("version_b_wins", 0))
		timeouts += int(round(float(summary.get("cap_termination_rate", 0.0)) * float(total_case_matches)))
		failures += _count_case_failures(case_result)

		var errors_variant: Variant = case_result.get("errors", PackedStringArray())
		var errors: Array[String] = []
		if errors_variant is PackedStringArray:
			for entry: String in errors_variant:
				errors.append(entry)
		elif errors_variant is Array:
			for entry_variant: Variant in errors_variant:
				errors.append(str(entry_variant))
		var pairing_gate_passed: bool = bool(case_result.get("regression_gate_passed", false)) and errors.is_empty()
		if not pairing_gate_passed:
			all_cases_passed = false

		pairing_results.append({
			"pairing_name": str(case_result.get("pairing_name", "")),
			"summary": summary.duplicate(true),
			"text_summary": str(case_result.get("text_summary", "")),
			"errors": errors,
			"gate_passed": pairing_gate_passed,
		})

	var version_a_win_rate := 0.0 if total_matches <= 0 else float(version_a_wins) / float(total_matches)
	var version_b_win_rate := 0.0 if total_matches <= 0 else float(version_b_wins) / float(total_matches)
	var gate_passed := all_cases_passed and total_matches > 0 and version_a_win_rate >= gate_threshold
	return {
		"pairing_results": pairing_results,
		"total_matches": total_matches,
		"version_a_wins": version_a_wins,
		"version_b_wins": version_b_wins,
		"version_a_win_rate": version_a_win_rate,
		"version_b_win_rate": version_b_win_rate,
		"win_rate_vs_current_best": version_a_win_rate,
		"gate_threshold": gate_threshold,
		"all_cases_passed": all_cases_passed,
		"gate_passed": gate_passed,
		"timeouts": timeouts,
		"failures": failures,
	}


func _count_case_failures(case_result: Dictionary) -> int:
	var summary: Dictionary = case_result.get("summary", {})
	var failure_breakdown: Dictionary = summary.get("failure_breakdown", {})
	var failure_count := 0
	for value: Variant in failure_breakdown.values():
		failure_count += int(value)
	if failure_count > 0:
		return failure_count
	var errors_variant: Variant = case_result.get("errors", PackedStringArray())
	if errors_variant is PackedStringArray:
		return 1 if not (errors_variant as PackedStringArray).is_empty() else 0
	if errors_variant is Array:
		return 1 if not (errors_variant as Array).is_empty() else 0
	return 0


func _load_agent_config(path: String) -> Dictionary:
	if path == "":
		return EvolutionEngineScript.get_default_config().duplicate(true)
	var store := AgentVersionStoreScript.new()
	var loaded := store.load_version(path)
	if loaded.is_empty():
		return EvolutionEngineScript.get_default_config().duplicate(true)
	return loaded.duplicate(true)


func _publish_and_record(args: Dictionary, summary: Dictionary) -> void:
	var run_id := str(args.get("run-id", ""))
	if run_id == "":
		return

	var run_registry := TrainingRunRegistryScript.new()
	if args.has("run-registry-dir"):
		run_registry.base_dir = str(args.get("run-registry-dir", run_registry.base_dir))
	var run_record := run_registry.create_run(run_id, str(args.get("pipeline-name", "fixed_three_deck_training")), {
		"run_dir": str(args.get("run-dir", "")),
		"lane_recipe_id": str(args.get("lane-recipe-id", "")),
		"parent_approved_baseline_id": str(args.get("baseline-version-id", "")),
		"baseline_source": str(args.get("baseline-source", "")),
		"baseline_version_id": str(args.get("baseline-version-id", "")),
		"baseline_display_name": str(args.get("baseline-display-name", "")),
		"baseline_agent_config_path": str(summary.get("baseline_agent_config_path", str(args.get("baseline-agent-config", "")))),
		"baseline_value_net_path": str(summary.get("baseline_value_net_path", str(args.get("baseline-value-net", "")))),
		"candidate_agent_config_path": str(summary.get("candidate_agent_config_path", "")),
		"candidate_value_net_path": str(summary.get("candidate_value_net_path", "")),
		"benchmark_quality_summary": _build_version_benchmark_summary(summary),
	})
	if run_record.is_empty():
		return

	var patch := {
		"benchmark_summary_path": str(args.get("summary-output", DEFAULT_SUMMARY_OUTPUT)),
		"benchmark_summary": _build_version_benchmark_summary(summary),
		"benchmark_gate_passed": bool(summary.get("gate_passed", false)),
		"benchmark_decision": "benchmark_failed",
		"status": "benchmark_failed",
	}

	if bool(summary.get("gate_passed", false)):
		var version_registry := AIVersionRegistryScript.new()
		if args.has("version-registry-dir"):
			version_registry.base_dir = str(args.get("version-registry-dir", version_registry.base_dir))
		var version_id := str(args.get("publish-version-id", ""))
		if version_id == "":
			version_id = version_registry.generate_version_id(str(args.get("version-date", "")))
		var display_name := str(args.get("publish-display-name", ""))
		if display_name == "":
			display_name = version_id
		var version_record := {
			"version_id": version_id,
			"display_name": display_name,
			"agent_config_path": str(summary.get("candidate_agent_config_path", "")),
			"value_net_path": str(summary.get("candidate_value_net_path", "")),
			"source_run_id": run_id,
			"lane_recipe_id": str(args.get("lane-recipe-id", "")),
			"parent_approved_baseline_id": str(args.get("baseline-version-id", "")),
			"parent_baseline_version_id": str(args.get("baseline-version-id", "")),
			"parent_baseline_agent_config_path": str(summary.get("baseline_agent_config_path", "")),
			"parent_baseline_value_net_path": str(summary.get("baseline_value_net_path", "")),
			"benchmark_summary": _build_version_benchmark_summary(summary),
			"benchmark_quality_summary": _build_version_benchmark_summary(summary),
		}
		if version_registry.publish_playable_version(version_record):
			patch["status"] = "published"
			patch["benchmark_decision"] = "published"
			patch["published_version_id"] = version_id
			patch["published_version_record"] = version_record
		else:
			patch["status"] = "publish_failed"
			patch["benchmark_decision"] = "publish_failed"

	run_registry.complete_run(run_id, patch)


func _build_version_benchmark_summary(summary: Dictionary) -> Dictionary:
	return {
		"win_rate_vs_current_best": float(summary.get("win_rate_vs_current_best", 0.0)),
		"total_matches": int(summary.get("total_matches", 0)),
		"timeouts": int(summary.get("timeouts", 0)),
		"failures": int(summary.get("failures", 0)),
	}


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir_path := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("BenchmarkRunner: failed to write summary to %s" % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()


func _quit_with_summary(summary: Dictionary) -> void:
	get_tree().quit(0 if bool(summary.get("gate_passed", false)) else 1)
