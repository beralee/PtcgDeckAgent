class_name TestMarnieGiftBoxFundPreservedMorgremExam
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_ID := "t5_attach_munkidori_before_hand_evolving_preserved_morgrem_bridge"
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_attach_munkidori_before_evolving_preserved_bridge() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var selected_exam: Dictionary = {}
	for exam_value: Variant in corpus.get("exams", []):
		if exam_value is Dictionary and exam_value.get("exam_id") == EXAM_ID:
			selected_exam = exam_value
			break
	corpus["exams"] = [selected_exam] if not selected_exam.is_empty() else []
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_false(selected_exam.is_empty()),
		assert_true(bool(report.get("ok", false)), "exam runner failed: %s" % report),
		assert_true(
			bool(report.get("all_passed", false)),
			"preserved Morgrem bridge funding mismatch: %s" % report
		),
	])
