extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const INPUT_ROOT := "res://tmp/v18cpg/smoke24"
const OUTPUT_PATH := "res://tmp/v18cpg/v18cpg_24_no_model_smoke_summary.json"

var _failures: Array[String] = []


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	var total_games := 0
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var path := "%s/%d.json" % [INPUT_ROOT, deck_id]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not (parsed is Dictionary):
			_failures.append("%d: missing or invalid smoke artifact" % deck_id)
			continue
		var root: Dictionary = parsed
		var reports: Array = root.get("reports", []) if root.get("reports", []) is Array else []
		if reports.size() != 1:
			_failures.append("%d: expected exactly one report" % deck_id)
			continue
		var report: Dictionary = reports[0]
		var games := int(report.get("games", 0))
		var per_game: Array = report.get("per_game", []) if report.get("per_game", []) is Array else []
		_check(int(report.get("deck_id", 0)) == deck_id, "%d: artifact deck id mismatch" % deck_id)
		_check(games > 0 and per_game.size() == games, "%d: incomplete per-game evidence" % deck_id)
		_check(int(report.get("rule_clean_games", 0)) == games, "%d: Rule smoke contains dirty games" % deck_id)
		_check(int(report.get("v18cpg_clean_games", 0)) == games, "%d: V18CPG smoke contains dirty games" % deck_id)
		_check(int(report.get("model_calls", -1)) == 0, "%d: no-model smoke made a model call" % deck_id)
		_check(is_equal_approx(float(report.get("paired_improvement", 99.0)), 0.0), "%d: no-model paired outcome changed" % deck_id)
		var exact_games := 0
		var max_own_decision_turns := 0
		for game_variant: Variant in per_game:
			if not (game_variant is Dictionary):
				continue
			var game: Dictionary = game_variant
			var rule: Dictionary = game.get("rule", {}) if game.get("rule", {}) is Dictionary else {}
			var cpg: Dictionary = game.get("v18cpg", {}) if game.get("v18cpg", {}) is Dictionary else {}
			var exact: bool = (
				str(rule.get("failure_reason", "")) != ""
				and str(rule.get("failure_reason", "")) == str(cpg.get("failure_reason", ""))
				and not bool(rule.get("stalled", true))
				and not bool(cpg.get("stalled", true))
				and not bool(rule.get("terminated_by_cap", true))
				and not bool(cpg.get("terminated_by_cap", true))
				and str(rule.get("outcome", "")) == str(cpg.get("outcome", ""))
				and int(rule.get("winner_index", -2)) == int(cpg.get("winner_index", -3))
				and int(rule.get("steps", -2)) == int(cpg.get("steps", -3))
				and int(rule.get("turns", -2)) == int(cpg.get("turns", -3))
				and JSON.stringify(rule.get("decision_log", [])) == JSON.stringify(cpg.get("decision_log", []))
			)
			if exact:
				exact_games += 1
			var own_turns: Dictionary = {}
			var tracked_player := int(game.get("tracked_player", -1))
			var decision_log: Array = cpg.get("decision_log", []) if cpg.get("decision_log", []) is Array else []
			for decision_variant: Variant in decision_log:
				if decision_variant is Dictionary and int((decision_variant as Dictionary).get("player", -2)) == tracked_player:
					own_turns[int((decision_variant as Dictionary).get("turn", -1))] = true
			max_own_decision_turns = maxi(max_own_decision_turns, own_turns.size())
		_check(exact_games == games, "%d: Rule and V18CPG decision logs are not exactly equal" % deck_id)
		_check(max_own_decision_turns >= 3, "%d: smoke did not cover three own decision turns" % deck_id)
		total_games += games
		rows.append({
			"deck_id": deck_id,
			"strategy_id": str(report.get("strategy_id", "")),
			"games": games,
			"exact_rule_floor_games": exact_games,
			"max_own_decision_turns": max_own_decision_turns,
			"model_calls": int(report.get("model_calls", -1)),
			"status": "smoke-ready" if exact_games == games and max_own_decision_turns >= 3 else "failed",
		})
	var summary := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"mode": "no-model-exact-rule-floor",
		"deck_count": rows.size(),
		"total_games": total_games,
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
		print("V18CPG 24-deck no-model smoke: PASS (24/24 decks, %d exact Rule-floor games)" % total_games)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 24-deck no-model smoke: FAIL (%d)" % _failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
