class_name BattleAdviceState
extends RefCounted

var last_result: Dictionary = {}
var busy: bool = false
var progress_text: String = ""
var initial_snapshot: Dictionary = {}
var pinned: bool = false
var panel_collapsed: bool = false
var review_match_dir: String = ""
var review_last_review: Dictionary = {}
var review_busy: bool = false
var review_progress_text: String = ""
var review_winner_index: int = -1
var review_reason: String = ""


func reset() -> void:
	last_result.clear()
	busy = false
	progress_text = ""
	initial_snapshot.clear()
	pinned = false
	panel_collapsed = false
	review_match_dir = ""
	review_last_review.clear()
	review_busy = false
	review_progress_text = ""
	review_winner_index = -1
	review_reason = ""


func has_cached_review() -> bool:
	return not review_last_review.is_empty()
