extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const INPUT_ROOT := "res://tmp/v18cpg/enabled_fake24"
const OUTPUT_PATH := "res://tmp/v18cpg/v18cpg_24_enabled_fake_smoke_summary.json"

var _failures: Array[String] = []


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	var total_games := 0
	var total_calls := 0
	var total_positive_flips := 0
	var total_negative_flips := 0
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var path := "%s/%d.json" % [INPUT_ROOT, deck_id]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) \
			if FileAccess.file_exists(path) else null
		if not (parsed is Dictionary):
			_failures.append("%d: missing or invalid enabled-path artifact" % deck_id)
			continue
		var root: Dictionary = parsed
		_check(bool(root.get("model_enabled", false)), "%d: model path was not enabled" % deck_id)
		_check(bool(root.get("fake_model_rule_root", false)), "%d: wrong deterministic fixture mode" % deck_id)
		_check(
			str(root.get("model", "")) == "deterministic_rule_root_fixture",
			"%d: unexpected fixture transport" % deck_id
		)
		var reports: Array = root.get("reports", []) if root.get("reports", []) is Array else []
		if reports.size() != 1 or not (reports[0] is Dictionary):
			_failures.append("%d: expected exactly one report" % deck_id)
			continue
		var report: Dictionary = reports[0]
		var games := int(report.get("games", 0))
		var calls := int(report.get("model_calls", 0))
		var accepted := int(report.get("model_accepted", -1))
		var rejected := int(report.get("model_rejected", -1))
		var per_game: Array = report.get("per_game", []) if report.get("per_game", []) is Array else []
		_check(int(report.get("deck_id", 0)) == deck_id, "%d: artifact deck id mismatch" % deck_id)
		_check(games > 0 and per_game.size() == games, "%d: incomplete per-game evidence" % deck_id)
		_check(int(report.get("rule_clean_games", 0)) == games, "%d: Rule reference contains dirty games" % deck_id)
		_check(int(report.get("v18cpg_clean_games", 0)) == games, "%d: enabled V18CPG contains dirty games" % deck_id)
		_check(calls > 0, "%d: enabled smoke never entered the model path" % deck_id)
		_check(accepted == calls and rejected == 0, "%d: a deterministic Rule-root response was rejected" % deck_id)
		_check(
			is_equal_approx(float(report.get("model_acceptance_rate", -1.0)), 1.0),
			"%d: model acceptance rate is not 100%%" % deck_id
		)
		_check(float(report.get("visible_wait_p95_ms", 999999.0)) <= 1.0, "%d: fixture added visible wait" % deck_id)
		var fallbacks: Dictionary = report.get("fallbacks", {}) if report.get("fallbacks", {}) is Dictionary else {}
		var fallback_reasons: Dictionary = report.get("fallback_reasons", {}) \
			if report.get("fallback_reasons", {}) is Dictionary else {}
		_check(fallbacks.is_empty() and fallback_reasons.is_empty(), "%d: enabled model path fell back" % deck_id)
		var min_paired_delta := 1
		var positive_flips := 0
		var negative_flips := 0
		var max_own_decision_turns := 0
		var isolated_games := 0
		for game_variant: Variant in per_game:
			if not (game_variant is Dictionary):
				continue
			var game: Dictionary = game_variant
			var paired_delta := int(game.get("paired_delta", -999))
			min_paired_delta = mini(min_paired_delta, paired_delta)
			if paired_delta > 0:
				positive_flips += 1
			elif paired_delta < 0:
				negative_flips += 1
			var cpg: Dictionary = game.get("v18cpg", {}) if game.get("v18cpg", {}) is Dictionary else {}
			_check(not bool(cpg.get("stalled", true)), "%d: enabled game stalled" % deck_id)
			_check(not bool(cpg.get("terminated_by_cap", true)), "%d: enabled game hit the step cap" % deck_id)
			var audit: Dictionary = game.get("audit", {}) if game.get("audit", {}) is Dictionary else {}
			var metrics: Dictionary = audit.get("last_request_metrics", {}) \
				if audit.get("last_request_metrics", {}) is Dictionary else {}
			if bool(metrics.get("rng_isolated_transport", false)):
				isolated_games += 1
			var own_turns: Dictionary = {}
			var tracked_player := int(game.get("tracked_player", -1))
			var decision_log: Array = cpg.get("decision_log", []) if cpg.get("decision_log", []) is Array else []
			for decision_variant: Variant in decision_log:
				if decision_variant is Dictionary \
						and int((decision_variant as Dictionary).get("player", -2)) == tracked_player:
					own_turns[int((decision_variant as Dictionary).get("turn", -1))] = true
			max_own_decision_turns = maxi(max_own_decision_turns, own_turns.size())
		_check(isolated_games == games, "%d: transport did not prove RNG isolation" % deck_id)
		_check(max_own_decision_turns >= 1, "%d: no tracked-seat decision turn was exercised" % deck_id)
		total_games += games
		total_calls += calls
		total_positive_flips += positive_flips
		total_negative_flips += negative_flips
		rows.append({
			"deck_id": deck_id,
			"strategy_id": str(report.get("strategy_id", "")),
			"games": games,
			"model_calls": calls,
			"model_accepted": accepted,
			"model_rejected": rejected,
			"min_paired_delta": min_paired_delta,
			"positive_flips": positive_flips,
			"negative_flips": negative_flips,
			"max_own_decision_turns": max_own_decision_turns,
			"visible_wait_p95_ms": float(report.get("visible_wait_p95_ms", -1.0)),
			"status": "enabled-path-ready" if accepted == calls and calls > 0 else "failed",
		})
	var summary := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"mode": "feature-enabled-deterministic-rule-root-fixture",
		"deck_count": rows.size(),
		"total_games": total_games,
		"total_model_calls": total_calls,
		"positive_paired_flips": total_positive_flips,
		"negative_paired_flips": total_negative_flips,
		"all_passed": _failures.is_empty() and rows.size() == ProfileCatalogScript.ALL_DECK_IDS.size(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(summary, "  "))
		output.close()
	if bool(summary.get("all_passed", false)):
		print("V18CPG 24-deck enabled fake smoke: PASS (24/24 decks, %d accepted calls)" % total_calls)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 24-deck enabled fake smoke: FAIL (%d)" % _failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
