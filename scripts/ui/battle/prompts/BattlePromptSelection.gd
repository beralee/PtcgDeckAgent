class_name BattlePromptSelection
extends RefCounted

var indices: PackedInt32Array = PackedInt32Array()


func configure(next_indices: PackedInt32Array) -> void:
	indices = next_indices.duplicate()


func first_index(default_value: int = -1) -> int:
	return indices[0] if not indices.is_empty() else default_value


func reset() -> void:
	indices = PackedInt32Array()
