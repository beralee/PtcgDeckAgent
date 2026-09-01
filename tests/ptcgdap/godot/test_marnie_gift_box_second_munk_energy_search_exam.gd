class_name TestMarnieGiftBoxSecondMunkEnergySearchExam
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_IDS := {
	"t10_arven_energy_search_starts_second_munkidori_transfer": true,
	"t10_play_energy_search_before_stadium_to_fund_second_munkidori": true,
}
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_arven_energy_search_starts_second_munkidori_transfer() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var selected_exams: Array[Dictionary] = []
	for exam_value: Variant in corpus.get("exams", []):
		if exam_value is Dictionary and EXAM_IDS.has(exam_value.get("exam_id")):
			selected_exams.append(exam_value)
	corpus["exams"] = selected_exams
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_eq(selected_exams.size(), 2),
		assert_true(bool(report.get("ok", false)), "exam runner failed: %s" % report),
		assert_true(
			bool(report.get("all_passed", false)),
			"second Munkidori Energy Search mismatch: %s" % report
		),
	])
