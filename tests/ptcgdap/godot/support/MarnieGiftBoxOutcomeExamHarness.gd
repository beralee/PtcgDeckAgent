class_name MarnieGiftBoxOutcomeExamHarness
extends RefCounted

const DEFAULT_CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_outcome_exams_r43.json"
)
const ComparatorScript = preload(
	"res://scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd"
)
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)


static func load_corpus(path: String = DEFAULT_CORPUS_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func run_corpus(corpus: Dictionary, repetitions_override: int = 0) -> Dictionary:
	var package: Variant = corpus.get("strategy_package")
	var exams: Variant = corpus.get("exams")
	if not package is Dictionary or not exams is Array or exams.is_empty():
		return _error_report("invalid_exam_corpus")
	var repetitions := repetitions_override
	if repetitions <= 0:
		repetitions = maxi(1, int(corpus.get("repetitions_per_exam", 1)))
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": package.get("package_id"),
			"package_version": package.get("package_version"),
			"archive_sha256": package.get("archive_sha256"),
			"install_source": package.get("install_source"),
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return _error_report(str(requested.get("error_code", "package_handle_rejected")))
	var results: Array[Dictionary] = []
	var passed_exams := 0
	var passed_runs := 0
	var total_runs := 0
	for exam_value: Variant in exams:
		if not exam_value is Dictionary:
			catalog.free()
			return _error_report("invalid_exam_case")
		var exam: Dictionary = exam_value
		var case_runs: Array[Dictionary] = []
		var case_passed := true
		for repetition: int in repetitions:
			total_runs += 1
			var verdict: Dictionary = ComparatorScript.compare(
				exam.get("candidate_end_state", {}) as Dictionary,
				exam.get("expected_end_state", {}) as Dictionary,
				exam.get("approved_alternatives", []) as Array
			)
			var passed := str(verdict.get("status", "")) == "PASS"
			if passed:
				passed_runs += 1
			else:
				case_passed = false
			case_runs.append({
				"repetition": repetition,
				"passed": passed,
				"status": verdict.get("status"),
				"reason": verdict.get("reason"),
				"diff": verdict.get("diff", []).duplicate(true),
			})
		if case_passed:
			passed_exams += 1
		results.append({
			"exam_id": str(exam.get("exam_id", "")),
			"issue_number": int(exam.get("issue_number", 0)),
			"turn_number": int(exam.get("turn_number", 0)),
			"passed": case_passed,
			"runs": case_runs,
		})
	catalog.free()
	return {
		"ok": true,
		"error_code": "",
		"corpus_id": str(corpus.get("corpus_id", "")),
		"repetitions_per_exam": repetitions,
		"passed_exams": passed_exams,
		"total_exams": exams.size(),
		"passed_runs": passed_runs,
		"total_runs": total_runs,
		"pass_percent": 100.0 * float(passed_runs) / float(total_runs),
		"all_passed": passed_exams == exams.size(),
		"results": results,
	}


static func _error_report(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"all_passed": false,
		"passed_exams": 0,
		"total_exams": 0,
		"passed_runs": 0,
		"total_runs": 0,
		"pass_percent": 0.0,
		"results": [],
	}
