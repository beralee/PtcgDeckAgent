class_name TestMarnieGiftBoxOutcomeExams
extends TestBase

const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxOutcomeExamHarness.gd"
)
const ComparatorScript = preload(
	"res://scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd"
)
const PACKAGE_SHA256 := "863EE8C8FA093B67863C5C60754A3BF4DF9796C7557084191A0C2A581E94A3A3"


func test_outcome_corpus_pins_promoted_package_and_all_five_issues() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus()
	var issues := {}
	for exam_value: Variant in corpus.get("exams", []):
		if exam_value is Dictionary:
			issues[int((exam_value as Dictionary).get("issue_number", 0))] = true
	var package: Dictionary = corpus.get("strategy_package", {})
	var contract: Dictionary = corpus.get("comparison_contract", {})
	return run_checks([
		assert_eq(corpus.get("document_type"), "ptcgdap_strategy_outcome_exam_corpus_v1"),
		assert_eq(corpus.get("status"), "promoted_gate"),
		assert_eq(corpus.get("exams", []).size(), 5),
		assert_true(issues.has(1) and issues.has(2) and issues.has(3) and issues.has(4) and issues.has(5)),
		assert_eq(package.get("package_id"), "dev.bodao-yongzhe.marnies-gift-box"),
		assert_eq(package.get("package_version"), "5.3.0"),
		assert_eq(package.get("archive_sha256"), PACKAGE_SHA256),
		assert_eq(contract.get("board"), "active exact; bench unordered multiset"),
		assert_eq(contract.get("hand"), "unordered card-name multiset"),
		assert_eq(contract.get("discard"), "unordered card-name multiset"),
		assert_eq(contract.get("action_order"), "not compared"),
	])


func test_all_final_state_outcomes_pass_five_repetitions() -> String:
	var report: Dictionary = HarnessScript.run_corpus(HarnessScript.load_corpus(), 5)
	return run_checks([
		assert_true(bool(report.get("ok", false)), "outcome runner failed: %s" % report),
		assert_eq(report.get("passed_exams"), 5, "outcome exam mismatch: %s" % report),
		assert_eq(report.get("total_exams"), 5),
		assert_eq(report.get("passed_runs"), 25),
		assert_eq(report.get("total_runs"), 25),
		assert_eq(report.get("pass_percent"), 100.0),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_missing_discard_card_fails_the_final_state_gate() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus()
	var exam: Dictionary = (corpus.get("exams", []) as Array)[0]
	var candidate: Dictionary = (exam.get("candidate_end_state", {}) as Dictionary).duplicate(true)
	var secondary: Dictionary = candidate.get("secondary", {})
	var tracked: Dictionary = secondary.get("tracked_player", {})
	var discard: Array = tracked.get("discard_card_names", [])
	discard.pop_back()
	var verdict: Dictionary = ComparatorScript.compare(
		candidate,
		exam.get("expected_end_state", {}) as Dictionary,
		[]
	)
	return run_checks([
		assert_eq(verdict.get("status"), "DIVERGE"),
		assert_str_contains(JSON.stringify(verdict.get("diff", [])), "discard_card_names"),
	])
