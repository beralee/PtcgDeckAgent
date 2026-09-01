extends SceneTree


func _initialize() -> void:
	var available := ClassDB.class_exists("PtcgOrtActor")
	var scripts_loaded := true
	for path: String in [
		"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd",
		"res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd",
		"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd",
		"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
		"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd",
		"res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd",
	]:
		if load(path) == null:
			scripts_loaded = false
	var report := {
		"document_type": "ptcgai_ort_extension_smoke_v1",
		"status": "passed" if available and scripts_loaded else "failed",
		"class_available": available,
		"scripts_loaded": scripts_loaded,
		"cpu_only": true,
	}
	print(JSON.stringify(report))
	quit(0 if available and scripts_loaded else 1)
