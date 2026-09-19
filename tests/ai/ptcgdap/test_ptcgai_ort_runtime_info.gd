extends SceneTree


func _initialize() -> void:
	var result := {"document_type": "ptcgai_ort_runtime_info_v1", "status": "failed"}
	var expected_unavailable := "--expect-unavailable" in OS.get_cmdline_user_args()
	if not ClassDB.class_exists("PtcgOrtActor"):
		result["error_code"] = "model_runtime_unavailable"
		result["status"] = "passed" if expected_unavailable else "failed"
	else:
		var actor: Object = ClassDB.instantiate("PtcgOrtActor")
		if not actor.has_method("get_runtime_info"):
			result["error_code"] = "model_runtime_info_missing"
		else:
			var info: Dictionary = actor.call("get_runtime_info")
			result["runtime_info"] = info
			if expected_unavailable:
				result["status"] = "passed" if not bool(info.get("available", true)) and not str(info.get("error_code", "")).is_empty() else "failed"
			elif bool(info.get("available", false)) and info.get("execution_provider") == "CPUExecutionProvider" and not str(info.get("version", "")).is_empty():
				# Invalid models must return a recoverable result, never terminate Godot.
				var invalid: Dictionary = actor.call("load_actor", PackedByteArray([1, 2, 3, 4]))
				result["invalid_model"] = invalid
				result["status"] = "passed" if not bool(invalid.get("ok", true)) and invalid.get("error_code") == "model_unavailable" else "failed"
	print(JSON.stringify(result))
	quit(0 if result["status"] == "passed" else 1)
