extends SceneTree

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	root.add_child(load("res://tests/ai/ptcgdap/AndroidStrategyParityRunner.gd").new())
