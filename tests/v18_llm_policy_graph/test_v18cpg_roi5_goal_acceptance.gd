extends SceneTree

const MANIFEST_PATH := "res://scripts/tools/v18cpg/roi5_precision_manifest.json"
const OUTPUT_PATH := "res://tmp/v18cpg/v18cpg_roi5_goal_acceptance.json"
const EXPECTED_ORDER: Array[int] = [800018502, 800018501, 800018499, 800018509, 800015934]
const ALLOWED_ITERATION_DECISIONS: Array[String] = [
	"retained",
	"retained_noninferior",
	"validated_and_frozen",
	"rejected_and_rolled_back",
	"rejected_before_implementation",
]

var _failures: Array[String] = []


func _initialize() -> void:
	var manifest := _load_dictionary(MANIFEST_PATH)
	_check(str(manifest.get("architecture", "")) == "V18CPG", "ROI5 acceptance must stay on V18CPG")
	_check(int(manifest.get("required_deep_rounds", 0)) == 5, "ROI5 acceptance requires exactly five deep rounds")
	_check(int(manifest.get("games_per_round", 0)) == 5, "ROI5 final benchmark must use five paired games")
	var acceptance: Dictionary = manifest.get("acceptance", {}) if manifest.get("acceptance", {}) is Dictionary else {}
	var decks: Array = manifest.get("decks", []) if manifest.get("decks", []) is Array else []
	var actual_order: Array[int] = []
	var rows: Array[Dictionary] = []
	for raw_deck: Variant in decks:
		var deck: Dictionary = raw_deck if raw_deck is Dictionary else {}
		var deck_id := int(deck.get("deck_id", 0))
		actual_order.append(deck_id)
		var iteration_result := _verify_deep_iterations(deck_id, str(deck.get("evidence_ledger", "")))
		var scenario_result := _verify_scenarios(deck_id, str(deck.get("scenario_artifact", "")))
		var benchmark_result := _verify_benchmark(
			deck_id,
			str(deck.get("final_benchmark_artifact", "")),
			int(manifest.get("anchor_id", 0)),
			int(manifest.get("games_per_round", 0)),
			acceptance
		)
		rows.append({
			"priority": int(deck.get("priority", 0)),
			"deck_id": deck_id,
			"display_name": str(deck.get("display_name", "")),
			"deep_iterations": int(iteration_result.get("count", 0)),
			"complex_scenarios": int(scenario_result.get("count", 0)),
			"rule_wins": int(benchmark_result.get("rule_wins", 0)),
			"v18cpg_wins": int(benchmark_result.get("v18cpg_wins", 0)),
			"model_calls": int(benchmark_result.get("model_calls", 0)),
			"model_accepted": int(benchmark_result.get("model_accepted", 0)),
			"verified_reference_action_checks": int(benchmark_result.get("verified_reference_action_checks", 0)),
			"turn_visible_wait_p95_ms": float(benchmark_result.get("turn_visible_wait_p95_ms", 0.0)),
			"passed": bool(iteration_result.get("passed", false)) and bool(scenario_result.get("passed", false)) and bool(benchmark_result.get("passed", false)),
		})
	_check(actual_order == EXPECTED_ORDER, "ROI5 final acceptance deck order changed")

	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"program_id": "roi5_precision",
		"acceptance_rule": "same_opponent_same_seed_five_game_noninferiority",
		"deck_count": rows.size(),
		"passed_decks": rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg"))
	var output := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty():
		print("V18CPG ROI5 goal acceptance: PASS (5/5 decks)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG ROI5 goal acceptance: FAIL (%d)" % _failures.size())
	quit(1)


func _verify_deep_iterations(deck_id: int, path: String) -> Dictionary:
	var before := _failures.size()
	var ledger := _load_dictionary(path)
	_check(int(ledger.get("deck_id", 0)) == deck_id, "%d iteration ledger deck id mismatch" % deck_id)
	_check(str(ledger.get("architecture", "")) == "V18CPG", "%d iteration ledger architecture mismatch" % deck_id)
	var iterations: Array = ledger.get("deep_iterations", []) if ledger.get("deep_iterations", []) is Array else []
	_check(iterations.size() >= 5, "%d must record at least five deep iterations" % deck_id)
	var seen_rounds: Dictionary = {}
	for raw_iteration: Variant in iterations:
		var iteration: Dictionary = raw_iteration if raw_iteration is Dictionary else {}
		var round_id := int(iteration.get("round", 0))
		_check(round_id > 0, "%d deep iteration must have a positive round" % deck_id)
		_check(not seen_rounds.has(round_id), "%d deep iteration rounds must be unique" % deck_id)
		seen_rounds[round_id] = true
		_check(not str(iteration.get("failure_category", "")).is_empty(), "%d round %d needs a failure category" % [deck_id, round_id])
		_check(str(iteration.get("decision", "")) in ALLOWED_ITERATION_DECISIONS, "%d round %d has an invalid decision" % [deck_id, round_id])
		_check(not str(iteration.get("proof_reason", "")).is_empty(), "%d round %d needs a proof reason" % [deck_id, round_id])
		var evidence := str(iteration.get("evidence", ""))
		_check(not evidence.is_empty(), "%d round %d needs evidence" % [deck_id, round_id])
		if evidence.begins_with("res://"):
			_check(FileAccess.file_exists(evidence), "%d round %d evidence is missing: %s" % [deck_id, round_id, evidence])
	return {"count": iterations.size(), "passed": _failures.size() == before}


func _verify_scenarios(deck_id: int, path: String) -> Dictionary:
	var before := _failures.size()
	var artifact := _load_dictionary(path)
	_check(int(artifact.get("deck_id", 0)) == deck_id, "%d scenario artifact deck id mismatch" % deck_id)
	_check(str(artifact.get("architecture", "")) == "V18CPG", "%d scenario artifact architecture mismatch" % deck_id)
	_check(bool(artifact.get("all_passed", false)), "%d complex scenario suite must pass" % deck_id)
	var scenarios: Array = artifact.get("scenarios", []) if artifact.get("scenarios", []) is Array else []
	_check(scenarios.size() >= 3, "%d needs at least three complex decision scenarios" % deck_id)
	_check(int(artifact.get("scenario_count", 0)) == scenarios.size(), "%d scenario count mismatch" % deck_id)
	for raw_scenario: Variant in scenarios:
		var scenario: Dictionary = raw_scenario if raw_scenario is Dictionary else {}
		_check(bool(scenario.get("passed", false)), "%d scenario %s failed" % [deck_id, str(scenario.get("id", "unknown"))])
		_check(not str(scenario.get("category", "")).is_empty(), "%d scenario needs a category" % deck_id)
		_check(not str(scenario.get("expected_choice", "")).is_empty(), "%d scenario needs an expected decision sequence" % deck_id)
		_check(not str(scenario.get("proof_reason", "")).is_empty(), "%d scenario needs a public proof reason" % deck_id)
	return {"count": scenarios.size(), "passed": _failures.size() == before}


func _verify_benchmark(deck_id: int, path: String, anchor_id: int, games: int, acceptance: Dictionary) -> Dictionary:
	var before := _failures.size()
	var artifact := _load_dictionary(path)
	_check(str(artifact.get("architecture", "")) == "V18CPG", "%d final benchmark architecture mismatch" % deck_id)
	_check(int(artifact.get("anchor_id", 0)) == anchor_id, "%d final benchmark anchor mismatch" % deck_id)
	_check(int(artifact.get("games_per_deck", 0)) == games, "%d final benchmark must contain five paired games" % deck_id)
	_check(int(artifact.get("seed_base", 0)) == deck_id, "%d final benchmark must use the deck id as its fixed seed base" % deck_id)
	_check(bool(artifact.get("compare_verified_reference", false)), "%d final benchmark must compare the verified reference" % deck_id)
	_check(bool(artifact.get("model_enabled", false)), "%d final benchmark must run the enabled real-model path" % deck_id)
	var reports: Array = artifact.get("reports", []) if artifact.get("reports", []) is Array else []
	_check(reports.size() == 1, "%d final benchmark must contain exactly one deck report" % deck_id)
	var row: Dictionary = reports[0] if reports.size() == 1 and reports[0] is Dictionary else {}
	_check(int(row.get("deck_id", 0)) == deck_id, "%d final benchmark report deck mismatch" % deck_id)
	_check(str(row.get("deck_source", "")) == "bundled_ai", "%d final benchmark must use the bundled AI deck" % deck_id)
	var required_clean := int(acceptance.get("require_clean_games", games))
	_check(int(row.get("rule_clean_games", 0)) == required_clean, "%d Rule arm is not 5/5 clean" % deck_id)
	_check(int(row.get("v18cpg_clean_games", 0)) == required_clean, "%d V18CPG arm is not 5/5 clean" % deck_id)
	_check(int(row.get("v18cpg_wins", -1)) >= int(row.get("rule_wins", 0)), "%d V18CPG is weaker than Rule on the paired five-game batch" % deck_id)
	_check(int(row.get("model_calls", 0)) > 0, "%d final benchmark must make real model calls" % deck_id)
	_check(int(row.get("model_accepted", 0)) > 0, "%d final benchmark must accept at least one model response" % deck_id)
	_check(float(row.get("turn_visible_wait_p95_ms", INF)) <= float(acceptance.get("turn_visible_wait_p95_ms_max", 6500)), "%d final benchmark exceeds the visible-wait p95 gate" % deck_id)
	_check(int(row.get("zero_acceptance_reference_mismatches", -1)) == 0, "%d final benchmark has acceptance reference mismatches" % deck_id)
	_check(int(row.get("zero_model_action_reference_checks", 0)) > 0, "%d final benchmark must exercise verified-reference action checks" % deck_id)
	_check(int(row.get("zero_model_action_reference_mismatches", -1)) == 0, "%d final benchmark has model-action reference mismatches" % deck_id)
	return {
		"passed": _failures.size() == before,
		"rule_wins": int(row.get("rule_wins", 0)),
		"v18cpg_wins": int(row.get("v18cpg_wins", 0)),
		"model_calls": int(row.get("model_calls", 0)),
		"model_accepted": int(row.get("model_accepted", 0)),
		"verified_reference_action_checks": int(row.get("zero_model_action_reference_checks", 0)),
		"turn_visible_wait_p95_ms": float(row.get("turn_visible_wait_p95_ms", 0.0)),
	}


func _load_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		_failures.append("missing dictionary: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("cannot open dictionary: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_failures.append("invalid dictionary: %s" % path)
		return {}
	return parsed


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
