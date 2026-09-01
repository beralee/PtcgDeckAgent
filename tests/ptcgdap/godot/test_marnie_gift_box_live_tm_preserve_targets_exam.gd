class_name TestMarnieGiftBoxLiveTmPreserveTargetsExam
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_IDS := {
	"t5_attach_tm_before_manual_froslass_to_preserve_two_targets": true,
	"t5_arven_energy_search_preserves_tm_evolution_cards_in_deck": true,
	"t4_arven_energy_search_preserves_impidimp_snorunt_tm_chain": true,
	"t2_arven_keeps_night_stretcher_when_ultra_ball_is_absent": true,
	"t7_attach_tm_to_ready_grimmsnarl_before_attacking_with_two_snorunt": true,
}
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_attach_tm_before_manual_froslass_preserves_two_targets() -> String:
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
		assert_eq(selected_exams.size(), 5),
		assert_true(bool(report.get("ok", false)), "exam runner failed: %s" % report),
		assert_true(
			bool(report.get("all_passed", false)),
			"TM target-preservation ordering mismatch: %s" % report
		),
	])
