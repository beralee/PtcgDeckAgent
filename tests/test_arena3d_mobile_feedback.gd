extends SceneTree

func _initialize() -> void:
	root.set_meta("performance_bench_offline",true)
	call_deferred("_launch")

func _launch() -> void:
	var probe = load("res://scripts/performance/ArenaAndroidFeedbackAcceptance.gd").new()
	probe.output = "user://feedback-result.json"
	root.add_child(probe)
