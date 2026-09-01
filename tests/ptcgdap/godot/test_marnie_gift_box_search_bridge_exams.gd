class_name TestMarnieGiftBoxSearchBridgeExams
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_IDS := [
	"t5_spikemuth_takes_grimmsnarl_when_morgrem_is_already_in_hand",
	"t15_night_stretcher_recovers_impidimp_bridge_instead_of_late_budew",
	"t4_send_out_munkidori_to_protect_funded_impidimp_bridge",
]
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_searches_and_send_out_preserve_the_grimmsnarl_evolution_bridge() -> String:
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
		assert_true(bool(report.get("all_passed", false)), "evolution bridge mismatch: %s" % report),
	])
