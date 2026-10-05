extends SceneTree
func _initialize() -> void:
	root.set_meta("performance_bench_offline", true)
	call_deferred("_launch")
func _launch() -> void:
	root.add_child(load("res://tests/commentary/OpponentTalkArenaAcceptance.gd").new())
