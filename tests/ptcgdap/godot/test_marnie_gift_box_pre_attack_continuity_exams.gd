class_name TestMarnieGiftBoxPreAttackContinuityExams
extends TestBase

const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_093731_374046_r53.json"
)
const PACKAGE_SHA256 := "E7539DB5639B236365A801476F685C22BD45B10F3E9C09A46960EBC60063EBED"
const DETAIL_SHA256 := "52F48F3A8173CE009F5D1E8203C720FBC06A18589CE1E0FF6DAE26BF4EF6AA5D"
const CHAIN_ROOT_SHA256 := "9560525706F869D01490F8498D992B526FDE44D59E6CD19B0785E02912E276FC"


func test_corpus_pins_latest_verified_match_and_promoted_package() -> String:
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
		assert_eq(corpus.get("status"), "r53_promoted_gate"),
		assert_eq(corpus.get("exams", []).size(), 18),
		assert_eq(issues.keys().size(), 5),
		assert_true(
			issues.has(1) and issues.has(2) and issues.has(3)
			and issues.has(4) and issues.has(5)
		),
		assert_eq(invalid_case, ""),
		assert_eq(source.get("match_id"), "match_20260829_093731_374046"),
		assert_eq(source.get("record_count"), 370),
		assert_eq(source.get("detail_file_sha256"), DETAIL_SHA256),
		assert_eq(source.get("chain_root_sha256"), CHAIN_ROOT_SHA256),
		assert_eq(package.get("package_id"), "dev.bodao-yongzhe.marnies-gift-box"),
		assert_eq(package.get("package_version"), "5.13.0"),
		assert_eq(package.get("archive_sha256"), PACKAGE_SHA256),
	])


func test_candidate_5_13_0_behavior_passes_all_latest_match_exams() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 5
	)
	return run_checks([
		assert_true(bool(report.get("ok", false)), "target runner failed: %s" % report),
		assert_eq(report.get("total_exams"), 18),
		assert_eq(report.get("passed_exams"), 18, "target exam mismatch: %s" % report),
		assert_eq(report.get("passed_runs"), 90),
		assert_eq(report.get("total_runs"), 90),
		assert_eq(report.get("pass_percent"), 100.0),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_latest_match_choices_are_deterministic_and_public_only() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 5
	)
	var checks: Array[String] = [
		assert_true(bool(report.get("ok", false)), "target runner failed: %s" % report),
		assert_true(bool(report.get("all_passed", false))),
	]
	var sequence := 4400
	for exam_value: Variant in corpus.get("exams", []):
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
			checks.append(assert_eq((run_value as Dictionary).get("selected_indexes", []), expected))
	return run_checks(checks)
