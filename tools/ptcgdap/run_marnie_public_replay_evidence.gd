extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var card_database := root.get_node_or_null("CardDatabase")
	var acceptance_script := load(
		"res://scripts/ai/ptcgdap/acceptance/MarniePublicReplayAcceptance.gd"
	) as GDScript
	var report: Dictionary = acceptance_script.new().run(card_database, {
		"seed": int(options.get("seed", 84590)),
		"max_steps": int(options.get("max_steps", 700)),
	})
	var output_path := str(options.get("output", ""))
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			report["is_clean"] = false
			report["failure"] = "evidence_output_unavailable"
		else:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("CSP_WP1_PUBLIC_REPLAY_EVIDENCE=" + JSON.stringify({
		"is_clean": report.get("is_clean", false),
		"failure": report.get("failure", ""),
		"steps": report.get("steps", 0),
		"frame_count": report.get("artifact", {}).get("frames", []).size(),
		"output": output_path,
	}))
	quit(0 if bool(report.get("is_clean", false)) else 1)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg: String in args:
		if arg.begins_with("--seed="):
			parsed["seed"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--output="):
			parsed["output"] = arg.get_slice("=", 1)
	return parsed
