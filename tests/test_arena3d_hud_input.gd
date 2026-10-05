extends SceneTree
## Shares the exact viewport-dispatched GUI regression used by the Windows EXE.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var regression: Node = load("res://scripts/tools/Arena3DSmoke.gd").new()
	root.add_child(regression)
