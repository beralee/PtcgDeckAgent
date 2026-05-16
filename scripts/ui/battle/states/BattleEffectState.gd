class_name BattleEffectState
extends RefCounted

var kind: String = ""
var player_index: int = -1
var ability_index: int = -1
var attack_data: Dictionary = {}
var steps: Array[Dictionary] = []
var step_index: int = -1
var context: Dictionary = {}
var coin_animation_resume_effect_step: bool = false


func reset() -> void:
	kind = ""
	player_index = -1
	ability_index = -1
	attack_data.clear()
	steps.clear()
	step_index = -1
	context.clear()
	coin_animation_resume_effect_step = false


func is_active() -> bool:
	return kind.strip_edges() != "" and step_index >= 0
