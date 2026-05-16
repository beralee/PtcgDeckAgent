class_name BattleRecordingState
extends RefCounted

var output_root: String = ""
var started: bool = false
var context_captured: bool = false
var match_dir: String = ""


func reset() -> void:
	output_root = ""
	started = false
	context_captured = false
	match_dir = ""


func is_active() -> bool:
	return started
