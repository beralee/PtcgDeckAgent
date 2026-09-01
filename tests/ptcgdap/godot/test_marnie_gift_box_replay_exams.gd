class_name TestMarnieGiftBoxReplayExams
extends TestBase

const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)

const PACKAGE_SHA256 := "863EE8C8FA093B67863C5C60754A3BF4DF9796C7557084191A0C2A581E94A3A3"
const DETAIL_SHA256 := "7EEBADA7BC5A42F532B42D504BE46DB8161C31CA2ED97409F3EB8048A8AD6347"
const CHAIN_ROOT_SHA256 := "76E360C91BC01578C6F10A5A16C0CD854051DC35E75CC69E2568032E8666A416"


func test_exam_corpus_pins_the_verified_match_package_and_all_five_issues() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus()
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
		assert_eq(corpus.get("status"), "r43_promoted_gate"),
		assert_eq(corpus.get("exams", []).size(), 9),
		assert_eq(issues.keys().size(), 5),
		assert_true(issues.has(1) and issues.has(2) and issues.has(3) and issues.has(4) and issues.has(5)),
		assert_eq(invalid_case, ""),
		assert_eq(source.get("match_id"), "match_20260828_215722_938052"),
		assert_eq(source.get("record_count"), 411),
		assert_eq(source.get("detail_file_sha256"), DETAIL_SHA256),
		assert_eq(source.get("chain_root_sha256"), CHAIN_ROOT_SHA256),
		assert_eq(
			source.get("decision_frame_provenance"),
			"reconstructed_from_verified_public_state_and_choice_context"
		),
		assert_eq(package.get("package_id"), "dev.bodao-yongzhe.marnies-gift-box"),
		assert_eq(package.get("package_version"), "5.3.0"),
		assert_eq(package.get("archive_sha256"), PACKAGE_SHA256),
	])


func test_promoted_5_3_0_target_behavior_passes_every_exam_on_every_run() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus()
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 5
	)
	return run_checks([
		assert_true(bool(report.get("ok", false)), "target runner failed: %s" % report),
		assert_eq(report.get("total_exams"), 9),
		assert_eq(report.get("passed_exams"), 9, "target exam mismatch: %s" % report),
		assert_eq(report.get("passed_runs"), 45),
		assert_eq(report.get("total_runs"), 45),
		assert_eq(report.get("pass_percent"), 100.0),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_promoted_target_choices_are_deterministic_across_repetitions() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus()
	var target_report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 5
	)
	var deterministic := true
	for result_value: Variant in target_report.get("results", []):
		if not result_value is Dictionary:
			deterministic = false
			continue
		var result: Dictionary = result_value
		var expected: Array = result.get("expected_selected_indexes", [])
		for run_value: Variant in result.get("runs", []):
			if (
				not run_value is Dictionary
				or (run_value as Dictionary).get("selected_indexes", []) != expected
			):
				deterministic = false
	return run_checks([
		assert_true(bool(target_report.get("ok", false)), "target runner failed: %s" % target_report),
		assert_true(bool(target_report.get("all_passed", false))),
		assert_true(deterministic, "promoted target choices changed across repetitions"),
	])


func test_reconstructed_frames_are_public_only_and_hash_bound() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus()
	var checks: Array[String] = []
	var sequence := 2000
	for exam_value: Variant in corpus.get("exams", []):
		var exam: Dictionary = exam_value
		var frame: Dictionary = HarnessScript.build_frame(exam, sequence)
		sequence += 1
		checks.append(assert_false(frame.get("public_state", {}).get("opponent", {}).has("hand")))
		checks.append(assert_false(_contains_forbidden_key(frame)))
		checks.append(assert_eq(frame.get("options", []).size(), exam.get("options", []).size()))
		checks.append(assert_eq(
			frame.get("select_semantics", {}).get("max_count"),
			exam.get("select_semantics", {}).get("max_count")
		))
		checks.append(assert_eq(str(frame.get("source", {}).get("public_observation_hash", "")).length(), 64))
		checks.append(assert_eq(str(frame.get("source", {}).get("window_id", "")).length(), 64))
	return run_checks(checks)


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value.keys():
			if str(key) in [
				"deck_order", "private_state", "search_begin_input", "callback", "binding",
				"ticket", "command", "object_ref", "instance_id", "raw_private_hash",
			]:
				return true
			if _contains_forbidden_key(value.get(key)):
				return true
	elif value is Array:
		for item: Variant in value:
			if _contains_forbidden_key(item):
				return true
	return false
