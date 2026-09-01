extends SceneTree

const HARNESS_PATH := (
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxOutcomeExamHarness.gd"
)


func _initialize() -> void:
	var harness: GDScript = ResourceLoader.load(
		HARNESS_PATH, "GDScript", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as GDScript
	if harness == null:
		_finish({"ok": false, "error_code": "exam_runtime_load_failed"}, 2)
		return
	var args := _parse_args(OS.get_cmdline_user_args())
	var corpus_path := str(args.get("corpus", harness.DEFAULT_CORPUS_PATH))
	var repetitions := int(args.get("repetitions", 0))
	var corpus: Dictionary = harness.load_corpus(corpus_path)
	if corpus.is_empty():
		_finish({"ok": false, "error_code": "exam_corpus_invalid"}, 2)
		return
	var report: Dictionary = harness.run_corpus(corpus, repetitions)
	var output := {
		"schema_version": 1,
		"document_type": "marnie_gift_box_outcome_exam_report_v1",
		"corpus_id": corpus.get("corpus_id"),
		"corpus_status": corpus.get("status"),
		"outcomes": report,
	}
	_finish(output, 0 if bool(report.get("all_passed", false)) else 3)


func _parse_args(values: PackedStringArray) -> Dictionary:
	var result := {}
	for value: String in values:
		if not value.begins_with("--") or "=" not in value:
			continue
		var separator := value.find("=")
		result[value.substr(2, separator - 2)] = value.substr(separator + 1)
	return result


func _finish(output: Dictionary, exit_code: int) -> void:
	print(JSON.stringify(output, "\t", false))
	quit(exit_code)
