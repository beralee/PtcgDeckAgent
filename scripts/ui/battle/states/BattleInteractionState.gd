class_name BattleInteractionState
extends RefCounted

var mode: String = ""
var data: Dictionary = {}
var slot_index_by_id: Dictionary = {}
var selected_indices: Array = []
var assignment_selected_source_index: int = -1
var assignment_entries: Array = []
var position: String = "center"


func reset() -> void:
	mode = ""
	data.clear()
	slot_index_by_id.clear()
	selected_indices.clear()
	assignment_selected_source_index = -1
	assignment_entries.clear()
	position = "center"


func is_active() -> bool:
	return mode.strip_edges() != ""
