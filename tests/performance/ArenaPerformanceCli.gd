extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.add_child(load("res://scripts/performance/ArenaPortableReview.gd" if "--arena-review" in OS.get_cmdline_user_args() else "res://scripts/performance/ArenaPerformanceRunner.gd").new())
