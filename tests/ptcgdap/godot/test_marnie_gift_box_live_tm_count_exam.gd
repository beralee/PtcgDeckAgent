class_name TestMarnieGiftBoxLiveTmCountExam
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_ID := "t5_live_tm_attack_target_selects_two_when_source_is_active_morgrem"
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_live_tm_window_selects_two_targets_with_active_pokemon_source() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var selected_exams: Array = []
	for exam_value: Variant in corpus.get("exams", []):
		if exam_value is Dictionary and exam_value.get("exam_id") == EXAM_ID:
			selected_exams.append(exam_value)
	corpus["exams"] = selected_exams
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_eq(selected_exams.size(), 1),
		assert_true(bool(report.get("ok", false)), "exam runner failed: %s" % report),
		assert_true(bool(report.get("all_passed", false)), "live TM count mismatch: %s" % report),
	])
