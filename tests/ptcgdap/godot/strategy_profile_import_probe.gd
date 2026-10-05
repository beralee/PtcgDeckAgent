extends SceneTree

const Loader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")

func _initialize() -> void:
	var rows := []
	var failed := false
	for path: String in OS.get_cmdline_user_args():
		var result: Dictionary = Loader.new().inspect_path(path)
		rows.append({"path": path, "ok": result.get("ok", false), "error_code": result.get("error_code", ""), "runtime_compatibility": result.get("metadata", {}).get("runtime_compatibility", result.get("runtime_compatibility", {}))})
		failed = failed or not result.get("ok", false)
	print("PROFILE_IMPORT_RESULT=" + JSON.stringify(rows))
	quit(1 if failed else 0)
