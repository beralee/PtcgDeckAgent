extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const CONFIG_PATH := "res://scripts/tools/v18cpg/optimization21_manifest.json"
const LEDGER_ROOT := "res://scripts/tools/v18cpg/iterations/optimization21"
const ARTIFACT_ROOT := "res://tmp/v18cpg/optimization21"
const SEMANTIC_MANIFEST_ROOT := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests"
const OUTPUT_PATH := "res://tmp/v18cpg/v18cpg_21_deck_10_round_summary.json"
const FAILURE_CATEGORIES: Array[String] = [
	"visibility_violation", "belief_error", "semantic_gap", "fact_or_solver_error",
	"frontier_gap", "outcome_or_threat_error", "policy_graph_error",
	"model_selection_error", "route_synthesis_error", "compiler_error",
	"interaction_error", "event_or_version_error", "engine_error", "latency_budget",
]

var _failures: Array[String] = []


func _initialize() -> void:
	var config := _load_dictionary(CONFIG_PATH)
	if config.is_empty():
		push_error("missing optimization manifest")
		quit(1)
		return
	_check(
		JSON.stringify(config.get("failure_categories", [])) == JSON.stringify(FAILURE_CATEGORIES),
		"optimization manifest failure categories must match verifier enum exactly"
	)
	var deck_ids := _configured_deck_ids(config)
	var expected_ids := ProfileCatalogScript.ALL_DECK_IDS.duplicate()
	for pilot_id: int in ProfileCatalogScript.PILOT_DECK_IDS:
		expected_ids.erase(pilot_id)
	deck_ids.sort()
	expected_ids.sort()
	_check(deck_ids == expected_ids, "optimization manifest must contain exactly the 21 non-pilot deck ids")
	var rows: Array[Dictionary] = []
	for deck_id: int in deck_ids:
		rows.append(_verify_deck(deck_id, config))
	var passed := 0
	for row: Dictionary in rows:
		if str(row.get("status", "")) == "passed":
			passed += 1
	var summary := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"deck_count": rows.size(),
		"passed_decks": passed,
		"required_rounds_per_deck": int(config.get("rounds", 10)),
		"games_per_round": int(config.get("games_per_round", 5)),
		"acceptance": config.get("acceptance", {}).duplicate(true) \
			if config.get("acceptance", {}) is Dictionary else {},
		"all_passed": _failures.is_empty() and passed == 21,
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(summary, "  "))
		output.close()
	if bool(summary.get("all_passed", false)):
		print("V18CPG 21-deck optimization: PASS (21/21 decks, 10 rounds each)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 21-deck optimization: FAIL (%d issues, %d/21 decks passed)" % [_failures.size(), passed])
	quit(1)


func _verify_deck(deck_id: int, config: Dictionary) -> Dictionary:
	var before_failures := _failures.size()
	var expected_rounds := int(config.get("rounds", 10))
	var games_per_round := int(config.get("games_per_round", 5))
	var anchor_id := int(config.get("anchor_id", 575720))
	var model := str(config.get("model", "deepseek-v4-flash"))
	var seed_base := _seed_base_for_deck(deck_id, config)
	var ledger_path := "%s/%d_10_rounds.json" % [LEDGER_ROOT, deck_id]
	var ledger := _load_dictionary(ledger_path)
	_check(not ledger.is_empty(), "%d: missing structured ten-round ledger" % deck_id)
	if not ledger.is_empty():
		_check(int(ledger.get("deck_id", 0)) == deck_id, "%d: ledger deck id mismatch" % deck_id)
		_check(int(ledger.get("anchor_id", 0)) == anchor_id, "%d: ledger anchor mismatch" % deck_id)
		_check(int(ledger.get("seed_base", -1)) == seed_base, "%d: ledger seed base mismatch" % deck_id)
		_check(int(ledger.get("games_per_round", 0)) == games_per_round, "%d: ledger game count mismatch" % deck_id)
		_check(str(ledger.get("model", "")) == model, "%d: ledger model mismatch" % deck_id)
	var ledger_rounds: Array = ledger.get("rounds", []) if ledger.get("rounds", []) is Array else []
	_check(ledger_rounds.size() == expected_rounds, "%d: ledger must contain exactly ten retained rounds" % deck_id)
	var ledger_by_round: Dictionary = {}
	for round_variant: Variant in ledger_rounds:
		if not (round_variant is Dictionary):
			continue
		var entry: Dictionary = round_variant
		var round_number := int(entry.get("round", 0))
		_check(round_number >= 1 and round_number <= expected_rounds, "%d: invalid ledger round" % deck_id)
		_check(not ledger_by_round.has(round_number), "%d: duplicate ledger round %d" % [deck_id, round_number])
		ledger_by_round[round_number] = entry
		_check(str(entry.get("failure_category", "")) in FAILURE_CATEGORIES, "%d round %d: invalid failure category" % [deck_id, round_number])
		_check(str(entry.get("diagnosis", "")).strip_edges() != "", "%d round %d: missing diagnosis" % [deck_id, round_number])
		_check(str(entry.get("change_summary", "")).strip_edges() != "", "%d round %d: missing change summary" % [deck_id, round_number])
		_check(entry.has("retained") and entry.get("retained") is bool, "%d round %d: missing retained decision" % [deck_id, round_number])
	var baseline := _load_and_validate_artifact(deck_id, 0, games_per_round, anchor_id, model, seed_base)
	var baseline_rule_signature := _rule_signature(baseline)
	var timestamps: Dictionary = {}
	if not baseline.is_empty():
		timestamps[str(baseline.get("timestamp", ""))] = true
	var final_artifact: Dictionary = {}
	for round_number: int in range(1, expected_rounds + 1):
		var artifact := _load_and_validate_artifact(deck_id, round_number, games_per_round, anchor_id, model, seed_base)
		if artifact.is_empty():
			continue
		var expected_path := "%s/%d/round%02d.json" % [ARTIFACT_ROOT, deck_id, round_number]
		if ledger_by_round.has(round_number):
			_check(str((ledger_by_round[round_number] as Dictionary).get("artifact", "")) == expected_path, "%d round %d: ledger artifact path mismatch" % [deck_id, round_number])
		_check(_rule_signature(artifact) == baseline_rule_signature, "%d round %d: Rule replay changed despite fixed seeds" % [deck_id, round_number])
		var timestamp := str(artifact.get("timestamp", ""))
		_check(timestamp != "" and not timestamps.has(timestamp), "%d round %d: artifact timestamp is missing or duplicated" % [deck_id, round_number])
		timestamps[timestamp] = true
		if round_number == expected_rounds:
			final_artifact = artifact
	var final_report := _single_report(final_artifact)
	var rule_wins := int(final_report.get("rule_wins", -1))
	var cpg_wins := int(final_report.get("v18cpg_wins", -1))
	var net_wins := cpg_wins - rule_wins
	var paired_improvement := float(final_report.get("paired_improvement", -99.0))
	var acceptance: Dictionary = config.get("acceptance", {}) \
		if config.get("acceptance", {}) is Dictionary else {}
	var minimum_net_wins := int(acceptance.get("minimum_net_wins_at_five_games", 0))
	var minimum_paired_improvement := float(acceptance.get("minimum_paired_improvement", 0.0))
	var excellent_net_wins := int(acceptance.get("excellent_net_wins_at_five_games", 1))
	var excellent_paired_improvement := float(acceptance.get("excellent_paired_improvement", 0.1))
	_check(int(final_report.get("rule_clean_games", 0)) == games_per_round, "%d: final Rule games are not all clean" % deck_id)
	_check(int(final_report.get("v18cpg_clean_games", 0)) == games_per_round, "%d: final V18CPG games are not all clean" % deck_id)
	_check(int(final_report.get("model_calls", 0)) > 0, "%d: final benchmark made no model calls" % deck_id)
	_check(int(final_report.get("model_accepted", 0)) > 0, "%d: final benchmark accepted no model response" % deck_id)
	_check(
		net_wins >= minimum_net_wins and paired_improvement >= minimum_paired_improvement,
		"%d: final five-game benchmark is worse than the configured Rule floor" % deck_id
	)
	var strict_improvement_achieved := net_wins >= excellent_net_wins \
		and paired_improvement >= excellent_paired_improvement
	var expected_final_path := "%s/%d/round10.json" % [ARTIFACT_ROOT, deck_id]
	if not ledger.is_empty():
		_check(str(ledger.get("final_artifact", "")) == expected_final_path, "%d: final artifact pointer mismatch" % deck_id)
	return {
		"deck_id": deck_id,
		"strategy_id": str(ProfileCatalogScript.get_profile_for_deck(deck_id).get("strategy_id", "")),
		"rounds_present": maxi(0, timestamps.size() - 1),
		"rule_wins": rule_wins,
		"v18cpg_wins": cpg_wins,
		"net_wins": net_wins,
		"paired_improvement": paired_improvement,
		"non_inferiority_achieved": net_wins >= minimum_net_wins \
			and paired_improvement >= minimum_paired_improvement,
		"strict_improvement_achieved": strict_improvement_achieved,
		"model_calls": int(final_report.get("model_calls", 0)),
		"model_accepted": int(final_report.get("model_accepted", 0)),
		"model_rejected": int(final_report.get("model_rejected", 0)),
		"model_owned_action_results": int(final_report.get("model_owned_action_results", -1)),
		"zero_model_action_reference_mismatches": int(final_report.get("zero_model_action_reference_mismatches", -1)),
		"zero_acceptance_reference_mismatches": int(final_report.get("zero_acceptance_reference_mismatches", -1)),
		"verified_reference_gate": "model_action_ownership" \
			if final_report.has("zero_model_action_reference_mismatches") else "legacy_zero_acceptance",
		"verified_reference_mismatches": _verified_reference_mismatches(final_report),
		"visible_wait_p95_ms": float(final_report.get("visible_wait_p95_ms", -1.0)),
		"status": "passed" if _failures.size() == before_failures else "failed",
	}


func _load_and_validate_artifact(
	deck_id: int,
	round_number: int,
	games: int,
	anchor_id: int,
	model: String,
	seed_base: int
) -> Dictionary:
	var path := "%s/%d/round%02d.json" % [ARTIFACT_ROOT, deck_id, round_number]
	var root := _load_dictionary(path)
	if root.is_empty():
		_failures.append("%d round %02d: missing or invalid benchmark artifact" % [deck_id, round_number])
		return {}
	_check(str(root.get("architecture", "")) == "V18CPG", "%d round %d: wrong architecture" % [deck_id, round_number])
	_check(int(root.get("anchor_id", 0)) == anchor_id, "%d round %d: wrong anchor" % [deck_id, round_number])
	_check(int(root.get("games_per_deck", 0)) == games, "%d round %d: wrong game count" % [deck_id, round_number])
	_check(int(root.get("seed_base", -1)) == seed_base, "%d round %d: wrong seed base" % [deck_id, round_number])
	_check(bool(root.get("model_enabled", false)), "%d round %d: model path disabled" % [deck_id, round_number])
	_check(not bool(root.get("fake_model_rule_root", true)), "%d round %d: fake model is not optimization evidence" % [deck_id, round_number])
	_check(str(root.get("model", "")) == model, "%d round %d: wrong model" % [deck_id, round_number])
	_check(str(root.get("run_id", "")) == "opt21_%d_round%02d" % [deck_id, round_number], "%d round %d: wrong run id" % [deck_id, round_number])
	var report := _single_report(root)
	_check(str(report.get("deck_source", "")) == "bundled_ai", "%d round %d: benchmark did not use the bundled AI deck" % [deck_id, round_number])
	_check(str(report.get("anchor_source", "")) == "bundled_ai", "%d round %d: benchmark anchor did not use the bundled AI deck" % [deck_id, round_number])
	var semantic_manifest := _load_dictionary("%s/%d.json" % [SEMANTIC_MANIFEST_ROOT, deck_id])
	var expected_deck_fingerprint := str(semantic_manifest.get("deck_content_fingerprint", ""))
	_check(expected_deck_fingerprint != "", "%d round %d: semantic manifest has no deck fingerprint" % [deck_id, round_number])
	_check(
		str(report.get("deck_content_fingerprint", "")) == expected_deck_fingerprint,
		"%d round %d: benchmark deck content diverged from the semantic manifest" % [deck_id, round_number]
	)
	_check(str(report.get("anchor_content_fingerprint", "")) != "", "%d round %d: anchor fingerprint is missing" % [deck_id, round_number])
	if round_number >= 1:
		_check(bool(root.get("profile_overrides_enabled", false)), "%d round %d: optimization profile override was disabled" % [deck_id, round_number])
		_check(int(report.get("profile_version", 0)) >= 2, "%d round %d: optimization profile version missing" % [deck_id, round_number])
		_check(str(report.get("profile_fingerprint", "")) != "", "%d round %d: profile fingerprint missing" % [deck_id, round_number])
		_check(bool(root.get("compare_verified_reference", false)), "%d round %d: rejected-response reference arm was disabled" % [deck_id, round_number])
		_check(int(report.get("model_calls", 0)) > 0, "%d round %d: benchmark did not exercise the real model path" % [deck_id, round_number])
		_check(
			_verified_reference_mismatches(report) == 0,
			"%d round %d: execution without a model-owned action diverged from verified-local reference" % [deck_id, round_number]
		)
		_check(
			float(report.get("visible_wait_p95_ms", 999999.0)) <= 6500.0,
			"%d round %d: visible-wait p95 exceeded the frozen 6500ms budget" % [deck_id, round_number]
		)
	elif _baseline_ignores_profile_override(deck_id):
		_check(root.has("profile_overrides_enabled") and not bool(root.get("profile_overrides_enabled", true)), "%d round 0: ceiling rebaseline must ignore the existing optimization override" % deck_id)
		_check(int(report.get("profile_version", 0)) == 1, "%d round 0: ceiling rebaseline must use default profile v1" % deck_id)
	_check(int(report.get("deck_id", 0)) == deck_id, "%d round %d: report deck mismatch" % [deck_id, round_number])
	_check(int(report.get("games", 0)) == games, "%d round %d: incomplete report" % [deck_id, round_number])
	_check(int(report.get("rule_clean_games", 0)) == games, "%d round %d: Rule arm is not fully clean" % [deck_id, round_number])
	_check(int(report.get("v18cpg_clean_games", 0)) == games, "%d round %d: V18CPG arm is not fully clean" % [deck_id, round_number])
	var per_game: Array = report.get("per_game", []) if report.get("per_game", []) is Array else []
	_check(per_game.size() == games, "%d round %d: incomplete per-game evidence" % [deck_id, round_number])
	for game_index: int in per_game.size():
		var game: Dictionary = per_game[game_index] if per_game[game_index] is Dictionary else {}
		_check(int(game.get("seed", -1)) == seed_base + game_index, "%d round %d game %d: seed mismatch" % [deck_id, round_number, game_index + 1])
		_check(int(game.get("tracked_player", -1)) == game_index % 2, "%d round %d game %d: seat mismatch" % [deck_id, round_number, game_index + 1])
		for result_key: String in ["rule", "v18cpg"]:
			var result: Dictionary = game.get(result_key, {}) if game.get(result_key, {}) is Dictionary else {}
			_check(not bool(result.get("stalled", true)), "%d round %d game %d: %s stalled" % [deck_id, round_number, game_index + 1, result_key])
			_check(not bool(result.get("terminated_by_cap", true)), "%d round %d game %d: %s hit cap" % [deck_id, round_number, game_index + 1, result_key])
	return root


static func _verified_reference_mismatches(report: Dictionary) -> int:
	# New artifacts gate on actual model-owned action results.  Retained artifacts
	# created before this field existed continue to use the legacy zero-acceptance
	# evidence instead of becoming unreadable solely because of a schema extension.
	if report.has("zero_model_action_reference_mismatches"):
		return int(report.get("zero_model_action_reference_mismatches", -1))
	return int(report.get("zero_acceptance_reference_mismatches", -1))


func _rule_signature(root: Dictionary) -> String:
	var report := _single_report(root)
	var signature: Array[Dictionary] = []
	var per_game: Array = report.get("per_game", []) if report.get("per_game", []) is Array else []
	for game_variant: Variant in per_game:
		if not (game_variant is Dictionary):
			continue
		var game: Dictionary = game_variant
		var rule: Dictionary = game.get("rule", {}) if game.get("rule", {}) is Dictionary else {}
		signature.append({
			"seed": int(game.get("seed", -1)),
			"tracked_player": int(game.get("tracked_player", -1)),
			"winner_index": int(rule.get("winner_index", -2)),
			"outcome": str(rule.get("outcome", "")),
			"failure_reason": str(rule.get("failure_reason", "")),
			"steps": int(rule.get("steps", -1)),
			"turns": int(rule.get("turns", -1)),
			"decision_log": rule.get("decision_log", []),
		})
	return JSON.stringify(signature)


func _single_report(root: Dictionary) -> Dictionary:
	var reports: Array = root.get("reports", []) if root.get("reports", []) is Array else []
	return reports[0] if reports.size() == 1 and reports[0] is Dictionary else {}


func _configured_deck_ids(config: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var groups: Array = config.get("groups", []) if config.get("groups", []) is Array else []
	for group_variant: Variant in groups:
		if not (group_variant is Dictionary):
			continue
		var decks: Array = (group_variant as Dictionary).get("decks", []) \
			if (group_variant as Dictionary).get("decks", []) is Array else []
		for raw_id: Variant in decks:
			var deck_id := int(raw_id)
			_check(not result.has(deck_id), "optimization manifest contains duplicate deck id %d" % deck_id)
			result.append(deck_id)
	return result


func _seed_base_for_deck(deck_id: int, config: Dictionary) -> int:
	var policy: Dictionary = config.get("seed_policy", {}) if config.get("seed_policy", {}) is Dictionary else {}
	var overrides: Dictionary = policy.get("overrides", {}) if policy.get("overrides", {}) is Dictionary else {}
	return int(overrides.get(str(deck_id), deck_id))


func _baseline_ignores_profile_override(deck_id: int) -> bool:
	var config := _load_dictionary(CONFIG_PATH)
	var policy: Dictionary = config.get("seed_policy", {}) if config.get("seed_policy", {}) is Dictionary else {}
	var ids: Array = policy.get("baseline_ignore_profile_overrides", []) \
		if policy.get("baseline_ignore_profile_overrides", []) is Array else []
	return deck_id in ids


func _load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
