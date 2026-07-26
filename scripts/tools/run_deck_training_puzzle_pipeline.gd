extends SceneTree


const PipelineScript := preload("res://scripts/training/pipeline/DeckTrainingPuzzlePipeline.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var report := PipelineScript.new().run(options)
	var output_path := str(options.get("output", "user://deck_training_pipeline/latest.json"))
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write deck-training pipeline report: %s" % output_path)
		quit(73)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	var summary: Dictionary = report.get("summary", {})
	print("[DeckTrainingPipeline] ok=%s targets=%d/%d tactics=%d/%d recipes=%d candidates=%d playable=%d proven=%d shortcut=%d release=%d output=%s" % [
		str(report.get("ok", false)),
		int(summary.get("identity_passed", 0)),
		int(summary.get("target_count", 0)),
		int(summary.get("tactic_targets_passed", 0)),
		int(summary.get("target_count", 0)),
		int(summary.get("tactic_recipe_count", 0)),
		int(summary.get("candidate_count", 0)),
		int(summary.get("playable", 0)),
		int(summary.get("proven", 0)),
		int(summary.get("shortcut_audited", 0)),
		int(summary.get("release_ready", 0)),
		absolute_path,
	])
	for error: Variant in report.get("errors", []):
		printerr("[DeckTrainingPipeline] %s" % str(error))
	quit(0 if bool(report.get("ok", false)) else 1)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	for raw: String in args:
		if raw.begins_with("--deck-key="):
			options["deck_key"] = raw.trim_prefix("--deck-key=")
		elif raw.begins_with("--targets="):
			options["targets_path"] = raw.trim_prefix("--targets=")
		elif raw.begins_with("--probes="):
			options["probes_path"] = raw.trim_prefix("--probes=")
		elif raw.begins_with("--catalog="):
			options["catalog_path"] = raw.trim_prefix("--catalog=")
		elif raw.begins_with("--proof-dir="):
			options["proof_dir"] = raw.trim_prefix("--proof-dir=")
		elif raw.begins_with("--tactics="):
			options["tactics_path"] = raw.trim_prefix("--tactics=")
		elif raw.begins_with("--output="):
			options["output"] = raw.trim_prefix("--output=")
	return options
