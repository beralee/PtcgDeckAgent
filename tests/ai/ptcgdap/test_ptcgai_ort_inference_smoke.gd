extends SceneTree


func _initialize() -> void:
	var actor_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--actor="):
			actor_path = argument.trim_prefix("--actor=")
	var report := _run(actor_path)
	print(JSON.stringify(report))
	quit(0 if report.get("status") == "passed" else 1)


func _run(actor_path: String) -> Dictionary:
	if not ClassDB.class_exists("PtcgOrtActor"):
		return _failure("model_runtime_unavailable")
	if actor_path.is_empty():
		return _failure("model_artifact_missing")
	var file := FileAccess.open(actor_path, FileAccess.READ)
	if file == null:
		return _failure("model_artifact_missing")
	var actor: Variant = ClassDB.instantiate("PtcgOrtActor")
	var loaded: Variant = actor.load_actor(file.get_buffer(file.get_length()))
	file.close()
	if not loaded is Dictionary or not bool(loaded.get("ok", false)):
		return _failure(str(loaded.get("error_code", "model_unavailable")) if loaded is Dictionary else "model_unavailable")
	var frame := PackedInt32Array()
	var frame_presence := PackedInt32Array()
	var options := PackedInt32Array()
	var option_presence := PackedInt32Array()
	var mask := PackedInt32Array()
	frame.resize(24)
	frame_presence.resize(24)
	options.resize(1024 * 16)
	option_presence.resize(1024 * 16)
	mask.resize(1024)
	frame[17] = 1
	frame_presence[17] = 1
	options[0] = 13
	option_presence[0] = 1
	mask[0] = 1
	var inferred: Variant = actor.run(frame, frame_presence, options, option_presence, mask)
	if not inferred is Dictionary or not bool(inferred.get("ok", false)):
		return _failure(str(inferred.get("error_code", "model_inference_failed")) if inferred is Dictionary else "model_inference_failed")
	var scores: Variant = inferred.get("option_scores")
	if not scores is PackedInt32Array or scores.size() != 1024 or inferred.get("desired_count") != 1:
		return _failure("model_output_shape_invalid")
	return {
		"document_type": "ptcgai_ort_inference_smoke_v1",
		"status": "passed",
		"error_code": "",
		"runtime": loaded.get("runtime"),
		"execution_provider": loaded.get("execution_provider"),
		"score_count": scores.size(),
		"desired_count": inferred.get("desired_count"),
		"elapsed_us": inferred.get("elapsed_us"),
		"cpu_only": true,
		"external_process": false,
	}


func _failure(code: String) -> Dictionary:
	return {
		"document_type": "ptcgai_ort_inference_smoke_v1",
		"status": "failed",
		"error_code": code,
	}
