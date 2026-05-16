class_name BattlePromptRequest
extends RefCounted

var choice: String = ""
var title: String = ""
var items: Array = []
var data: Dictionary = {}


func configure(next_choice: String, next_title: String, next_items: Array, next_data: Dictionary = {}) -> void:
	choice = next_choice
	title = next_title
	items = next_items.duplicate()
	data = next_data.duplicate(true)


func reset() -> void:
	choice = ""
	title = ""
	items.clear()
	data.clear()
