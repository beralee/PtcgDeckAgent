class_name BattleSceneRefs
extends RefCounted

var replay_prev_turn_button: Button = null
var replay_next_turn_button: Button = null
var replay_continue_button: Button = null
var replay_back_to_list_button: Button = null


func bind_replay_buttons(
	prev_turn_button: Button,
	next_turn_button: Button,
	continue_button: Button,
	back_to_list_button: Button
) -> void:
	replay_prev_turn_button = prev_turn_button
	replay_next_turn_button = next_turn_button
	replay_continue_button = continue_button
	replay_back_to_list_button = back_to_list_button


func replay_buttons() -> Array[Button]:
	return [
		replay_prev_turn_button,
		replay_next_turn_button,
		replay_continue_button,
		replay_back_to_list_button,
	]
