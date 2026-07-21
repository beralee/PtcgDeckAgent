extends SceneTree

const MANIFEST_PATH := "res://scripts/tools/v18cpg/roi5_precision_manifest.json"
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RuleProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")

const EXPECTED_ORDER: Array[int] = [800018502, 800018501, 800018499, 800018509, 800015934]
const EXPECTED_PRIMARY_MODULES := {
	800018502: "copy_attack_toolbox",
	800018501: "stage2_chain",
	800018499: "dragapult_spread",
	800018509: "energy_burst",
	800015934: "tera_noctowl_search",
}

var _failures: Array[String] = []


func _initialize() -> void:
	var manifest := _load_dictionary(MANIFEST_PATH)
	_check(int(manifest.get("schema_version", 0)) == 1, "ROI5 manifest schema must be version 1")
	_check(str(manifest.get("architecture", "")) == "V18CPG", "ROI5 manifest must stay on V18CPG")
	_check(str(manifest.get("program_id", "")) == "roi5_precision", "ROI5 program id must be stable")
	_check(int(manifest.get("games_per_round", 0)) == 5, "ROI5 must retain five paired games per round")
	_check(int(manifest.get("required_deep_rounds", 0)) == 5, "ROI5 must require five deep iteration rounds per deck")

	var decks: Array = manifest.get("decks", []) if manifest.get("decks", []) is Array else []
	var actual_order: Array[int] = []
	var rows: Array[Dictionary] = []
	for index: int in range(decks.size()):
		var row: Dictionary = decks[index] if decks[index] is Dictionary else {}
		var deck_id := int(row.get("deck_id", 0))
		actual_order.append(deck_id)
		_check(int(row.get("priority", 0)) == index + 1, "%d priority must match ROI5 order" % deck_id)
		_check(not RuleProfileCatalogScript.get_profile_for_deck(deck_id).is_empty(), "%d must be a built-in 18.0 Rule deck" % deck_id)
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		_check(not profile.is_empty(), "%d must have a V18CPG profile" % deck_id)
		_check(str(row.get("strategy_id", "")) == str(profile.get("strategy_id", "")), "%d strategy id must match the profile catalog" % deck_id)
		_check(str(row.get("primary_module", "")) == str(EXPECTED_PRIMARY_MODULES.get(deck_id, "")), "%d must represent its selected ROI module" % deck_id)
		_check(str(row.get("primary_module", "")) == str(profile.get("primary_module", "")), "%d primary module must match the runtime profile" % deck_id)
		var reasons: Array = row.get("roi_reasons", []) if row.get("roi_reasons", []) is Array else []
		_check(reasons.size() >= 3, "%d must record at least three ROI reasons" % deck_id)
		var ledger_path := str(row.get("evidence_ledger", ""))
		_check(ledger_path.begins_with("res://scripts/tools/v18cpg/iterations/optimization21/"), \
			"%d must use the isolated ROI5 evidence ledger" % deck_id)
		_check(FileAccess.file_exists(ledger_path), "%d ROI5 evidence ledger must exist" % deck_id)
		rows.append({
			"priority": index + 1,
			"deck_id": deck_id,
			"display_name": str(row.get("display_name", "")),
			"strategy_id": str(row.get("strategy_id", "")),
			"primary_module": str(row.get("primary_module", "")),
			"starting_formal_rounds": int(row.get("starting_formal_rounds", 0)),
		})
	_check(actual_order == EXPECTED_ORDER, "ROI5 order must remain N Zoroark, Marnie Grimmsnarl, Dragapult, Raging Bolt, Tord")

	var phases: Array = manifest.get("phases", []) if manifest.get("phases", []) is Array else []
	var phased_ids: Array[int] = []
	for phase_raw: Variant in phases:
		var phase: Dictionary = phase_raw if phase_raw is Dictionary else {}
		var phase_ids: Array = phase.get("deck_ids", []) if phase.get("deck_ids", []) is Array else []
		for raw_id: Variant in phase_ids:
			phased_ids.append(int(raw_id))
	_check(phased_ids == EXPECTED_ORDER, "ROI5 phases must cover each selected deck exactly once in priority order")

	var acceptance: Dictionary = manifest.get("acceptance", {}) if manifest.get("acceptance", {}) is Dictionary else {}
	_check(float(acceptance.get("minimum_paired_improvement", -1.0)) == 0.0, "ROI5 minimum paired improvement must be non-negative")
	_check(int(acceptance.get("require_clean_games", 0)) == 5, "ROI5 must require five clean Rule and V18CPG games")
	_check(bool(acceptance.get("require_model_calls", false)), "ROI5 must require real model calls")
	_check(bool(acceptance.get("require_accepted_response", false)), "ROI5 must require accepted model responses")
	_check(bool(acceptance.get("require_exact_rule_replay_across_rounds", false)), "ROI5 must freeze exact Rule replay")
	_check(bool(acceptance.get("require_zero_model_action_reference_mismatches", false)), "ROI5 must require zero reference mismatches")
	_check(int(acceptance.get("turn_visible_wait_p95_ms_max", 0)) == 6500, "ROI5 p95 visible-wait ceiling must remain 6500 ms")

	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"program_id": "roi5_precision",
		"deck_count": rows.size(),
		"all_passed": _failures.is_empty(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg"))
	var output := FileAccess.open(ProjectSettings.globalize_path("res://tmp/v18cpg/v18cpg_roi5_manifest_summary.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty():
		print("V18CPG ROI5 precision manifest: PASS (5/5 decks)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG ROI5 precision manifest: FAIL (%d)" % _failures.size())
	quit(1)


func _load_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		_failures.append("missing dictionary: %s" % path)
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
