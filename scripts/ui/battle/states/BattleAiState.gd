class_name BattleAiState
extends RefCounted

var running: bool = false
var step_scheduled: bool = false
var followup_requested: bool = false
var turn_marker: String = ""
var actions_this_turn: int = 0
var action_pause_seconds: float = 0.0
var llm_waiting: bool = false
var llm_turn_requested: int = -1
var latest_opponent_action_text: String = ""
var latest_opponent_action_turn_number: int = -1


func reset() -> void:
	running = false
	step_scheduled = false
	followup_requested = false
	turn_marker = ""
	actions_this_turn = 0
	action_pause_seconds = 0.0
	llm_waiting = false
	llm_turn_requested = -1
	latest_opponent_action_text = ""
	latest_opponent_action_turn_number = -1


func is_waiting() -> bool:
	return llm_waiting
