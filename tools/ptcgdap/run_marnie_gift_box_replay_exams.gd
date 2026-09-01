extends SceneTree

const HARNESS_PATH := "res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
const REPLAY_LOADER_PATH := "res://scripts/engine/NativeReplayDiagnosticLoader.gd"


func _initialize() -> void:
	var harness: GDScript = ResourceLoader.load(
		HARNESS_PATH, "GDScript", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as GDScript
	var replay_loader: GDScript = ResourceLoader.load(
		REPLAY_LOADER_PATH, "GDScript", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as GDScript
	if harness == null or replay_loader == null:
		_finish({"ok": false, "error_code": "exam_runtime_load_failed"}, 2)
		return
	var args := _parse_args(OS.get_cmdline_user_args())
	var corpus_path := str(args.get("corpus", harness.DEFAULT_CORPUS_PATH))
	var mode := str(args.get("mode", "report"))
	var repetitions := int(args.get("repetitions", 0))
	if mode not in ["report", "baseline", "target"]:
		_finish({"ok": false, "error_code": "invalid_mode"}, 2)
		return
	var corpus: Dictionary = harness.load_corpus(corpus_path)
	if corpus.is_empty():
		_finish({"ok": false, "error_code": "exam_corpus_invalid"}, 2)
		return
	var replay_report: Dictionary = {"accepted": false, "error_codes": ["replay_dir_required"]}
	var replay_dir := str(args.get("replay-dir", ""))
	if not replay_dir.is_empty():
		replay_report = replay_loader.new().inspect_match_dir(replay_dir)
	var output := {
		"schema_version": 1,
		"document_type": "marnie_gift_box_replay_exam_report_v1",
		"corpus_id": corpus.get("corpus_id"),
		"corpus_status": corpus.get("status"),
		"replay": replay_report,
	}
	var exit_code := 0
	if mode in ["report", "baseline"]:
		var baseline: Dictionary = harness.run_corpus(
			corpus, "observed_baseline_selected_indexes", repetitions
		)
		output["baseline"] = baseline
		if not bool(baseline.get("all_passed", false)):
			exit_code = 2
	if mode in ["report", "target"]:
		var target: Dictionary = harness.run_corpus(
			corpus, "target_selected_indexes", repetitions
		)
		output["target"] = target
		if mode == "target" and not bool(target.get("all_passed", false)):
			exit_code = 3
	if not bool(replay_report.get("accepted", false)):
		exit_code = 4
	_finish(output, exit_code)


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
