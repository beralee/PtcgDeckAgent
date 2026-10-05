extends SceneTree
## Isolate inherited UI regression behavior without mutating project settings on disk.
func _initialize() -> void:
	ProjectSettings.set_setting("arena3d/enabled",false)
	call_deferred("_run")

func _run() -> void:
	var runner: Control = load("res://tests/TestRunner.tscn").instantiate()
	root.add_child(runner)
	current_scene = runner
