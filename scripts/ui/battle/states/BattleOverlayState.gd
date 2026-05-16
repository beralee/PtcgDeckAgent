class_name BattleOverlayState
extends RefCounted

var pending_prize_player_index: int = -1
var pending_prize_remaining: int = 0
var pending_prize_animating: bool = false
var portrait_prize_dialog_active: bool = false
var handover_visible: bool = false
var handover_target_player: int = -1
var match_end_visible: bool = false
var match_end_winner_index: int = -1
var match_end_reason: String = ""


func reset() -> void:
	clear_prize_selection()
	handover_visible = false
	handover_target_player = -1
	match_end_visible = false
	match_end_winner_index = -1
	match_end_reason = ""


func start_prize_selection(player_index: int, count: int) -> void:
	if count <= 0:
		clear_prize_selection()
		return
	pending_prize_player_index = player_index
	pending_prize_remaining = count
	pending_prize_animating = false


func clear_prize_selection() -> void:
	pending_prize_player_index = -1
	pending_prize_remaining = 0
	pending_prize_animating = false
	portrait_prize_dialog_active = false


func set_handover(target_player: int, visible_state: bool) -> void:
	handover_target_player = target_player if visible_state else -1
	handover_visible = visible_state


func set_match_end(winner_index: int, reason: String) -> void:
	match_end_visible = true
	match_end_winner_index = winner_index
	match_end_reason = reason


func has_pending_prize() -> bool:
	return pending_prize_player_index >= 0 and pending_prize_remaining > 0
