class_name TestMarnieGiftBoxCoreDevelopmentExams
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_IDS := [
	"t2_fund_active_budew_before_arven_tm_chain",
	"t6_evolve_second_froslass_before_nonterminal_grimmsnarl_attack",
]
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_tm_funding_and_second_froslass_complete_before_attacking() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var selected_exams: Array = []
	for exam_value: Variant in corpus.get("exams", []):
		if exam_value is Dictionary and exam_value.get("exam_id") in EXAM_IDS:
			selected_exams.append(exam_value)
	corpus["exams"] = selected_exams
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_eq(selected_exams.size(), EXAM_IDS.size()),
		assert_true(bool(report.get("ok", false)), "exam runner failed: %s" % report),
		assert_true(bool(report.get("all_passed", false)), "core development mismatch: %s" % report),
	])
