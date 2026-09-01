class_name TestMarnieGiftBoxTurnOrderR54Exams
extends TestBase

const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const PACKAGE_SHA256 := "E0F575511DD29CBBBC5ABD9354BB67C78010DFC7C7CA8BD90E196630AD1A21B4"
const DETAIL_SHA256 := "30C555C873590F03981B9398CEEEB91AFAC78818D6148F02F057209889251246"
const CHAIN_ROOT_SHA256 := "32A2921B52E628B1E84323A96D4E117447FEE4A59C6C80B4647812C152C935AE"


func test_corpus_pins_verified_match_and_all_turn_order_issues() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var issues := {}
	var invalid_case := ""
	for exam_value: Variant in corpus.get("exams", []):
		if not exam_value is Dictionary:
			invalid_case = "non_dictionary_exam"
			break
		var exam: Dictionary = exam_value
		issues[int(exam.get("issue_number", 0))] = true
		if (
			str(exam.get("exam_id", "")).is_empty()
			or int(exam.get("turn_number", 0)) <= 0
			or not exam.get("observed_baseline_selected_indexes") is Array
			or not exam.get("target_selected_indexes") is Array
			or str(exam.get("root_owner", "")).is_empty()
		):
			invalid_case = str(exam.get("exam_id", "missing_exam_id"))
			break
	var source: Dictionary = corpus.get("source_match", {})
	var package: Dictionary = corpus.get("strategy_package", {})
	return run_checks([
		assert_eq(corpus.get("document_type"), "ptcgdap_directed_strategy_exam_corpus_v1"),
		assert_eq(corpus.get("status"), "r54_candidate_gate"),
		assert_eq(corpus.get("exams", []).size(), 103),
		assert_eq(issues.keys().size(), 6),
		assert_true(
			issues.has(1) and issues.has(2) and issues.has(3)
			and issues.has(4) and issues.has(5) and issues.has(6)
		),
		assert_eq(invalid_case, ""),
		assert_eq(source.get("match_id"), "match_20260829_165713_715386"),
		assert_eq(source.get("record_count"), 505),
		assert_eq(source.get("detail_file_sha256"), DETAIL_SHA256),
		assert_eq(source.get("chain_root_sha256"), CHAIN_ROOT_SHA256),
		assert_eq(package.get("package_id"), "dev.bodao-yongzhe.marnies-gift-box"),
		assert_eq(package.get("package_version"), "5.14.0"),
		assert_eq(package.get("archive_sha256"), PACKAGE_SHA256),
	])


func test_candidate_behavior_passes_every_latest_match_exam() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_true(bool(report.get("ok", false)), "target runner failed: %s" % report),
		assert_eq(report.get("total_exams"), 103),
		assert_eq(report.get("passed_exams"), 103, "target exam mismatch: %s" % report),
		assert_eq(report.get("passed_runs"), 103),
		assert_eq(report.get("total_runs"), 103),
		assert_eq(report.get("pass_percent"), 100.0),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_latest_match_choices_are_deterministic_public_and_current_window_only() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var all_exams: Array = corpus.get("exams", []).duplicate(true)
	var first_exam_by_issue := {}
	for exam_value: Variant in all_exams:
		if exam_value is Dictionary:
			var issue_number := int(exam_value.get("issue_number", 0))
			if issue_number > 0 and not first_exam_by_issue.has(issue_number):
				first_exam_by_issue[issue_number] = exam_value
	var deterministic_samples: Array[Dictionary] = []
	var issue_numbers: Array = first_exam_by_issue.keys()
	issue_numbers.sort()
	for issue_number: Variant in issue_numbers:
		deterministic_samples.append(first_exam_by_issue[issue_number])
	corpus["exams"] = deterministic_samples
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 2
	)
	var checks: Array[String] = [
		assert_true(bool(report.get("ok", false)), "target runner failed: %s" % report),
		assert_true(bool(report.get("all_passed", false))),
		assert_eq(deterministic_samples.size(), 6),
		assert_eq(report.get("total_runs"), 12),
	]
	var sequence := 5400
	for exam_value: Variant in all_exams:
		var exam: Dictionary = exam_value
		var frame: Dictionary = HarnessScript.build_frame(exam, sequence)
		sequence += 1
		checks.append(assert_false(frame.get("public_state", {}).get("opponent", {}).has("hand")))
		checks.append(assert_eq(frame.get("options", []).size(), exam.get("options", []).size()))
		checks.append(assert_eq(str(frame.get("source", {}).get("public_observation_hash", "")).length(), 64))
		checks.append(assert_eq(str(frame.get("source", {}).get("window_id", "")).length(), 64))
	for result_value: Variant in report.get("results", []):
		var result: Dictionary = result_value
		var expected: Array = result.get("expected_selected_indexes", [])
		for run_value: Variant in result.get("runs", []):
			var actual: Array = (run_value as Dictionary).get("selected_indexes", []).duplicate()
			if bool(result.get("selection_order_insensitive", false)):
				actual.sort()
				expected = expected.duplicate()
				expected.sort()
			checks.append(assert_eq(actual, expected))
	return run_checks(checks)
