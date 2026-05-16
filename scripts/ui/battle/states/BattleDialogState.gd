class_name BattleDialogState
extends RefCounted

var pending_choice: String = ""
var multi_selected_indices: Array = []
var card_selected_indices: Array = []
var card_page: int = 0
var card_page_size: int = 0
var card_mode: bool = false
var assignment_mode: bool = false
var assignment_selected_source_index: int = -1
var assignment_assignments: Array = []
var items_data: Array = []
var data: Dictionary = {}


func reset() -> void:
	pending_choice = ""
	multi_selected_indices.clear()
	card_selected_indices.clear()
	card_page = 0
	card_page_size = 0
	card_mode = false
	assignment_mode = false
	assignment_selected_source_index = -1
	assignment_assignments.clear()
	items_data.clear()
	data.clear()
