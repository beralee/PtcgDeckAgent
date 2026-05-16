class_name BattleReplayState
extends RefCounted

var match_dir: String = ""
var turn_numbers: Array = []
var current_turn_index: int = -1
var entry_source: String = ""
var loaded_raw_snapshot: Dictionary = {}
var loaded_view_snapshot: Dictionary = {}


func reset() -> void:
	match_dir = ""
	turn_numbers.clear()
	current_turn_index = -1
	entry_source = ""
	loaded_raw_snapshot.clear()
	loaded_view_snapshot.clear()


func is_replay_loaded() -> bool:
	return match_dir.strip_edges() != "" and not turn_numbers.is_empty()
