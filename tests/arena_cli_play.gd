extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: Node = load("res://tests/ArenaCliPlayer.gd").new()
	root.add_child(player)
