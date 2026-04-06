class_name BattleReplayLocator
extends RefCounted


func locate(match_dir: String) -> Dictionary:
	var review := _read_json(match_dir.path_join("review/review.json"))
	var loser_review_turn := _loser_turn_from_review(review)
	var entry_turn := loser_review_turn
	var entry_source := "loser_key_turn"
	if entry_turn <= 0:
		entry_turn = _loser_last_full_turn(match_dir)
		entry_source = "loser_last_full_turn"
	return {
		"entry_turn_number": entry_turn,
		"entry_source": entry_source,
		"turn_numbers": _replayable_turn_numbers(match_dir),
	}


func _loser_turn_from_review(review: Dictionary) -> int:
	var turns: Array = review.get("selected_turns", [])
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		if str(turn.get("side", "")) == "loser":
			return int(turn.get("turn_number", 0))
	return 0


func _loser_last_full_turn(match_dir: String) -> int:
	var match_payload := _read_json(match_dir.path_join("match.json"))
	var result_variant: Variant = match_payload.get("result", {})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var loser_index := 1 - int(result.get("winner_index", 0))
	var detail_events := _read_json_lines(match_dir.path_join("detail.jsonl"))
	var last_turn := 0
	var last_turn_any := 0
	for event_variant: Variant in detail_events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		if str(event.get("event_type", "")) != "state_snapshot":
			continue
		var state_variant: Variant = event.get("state", {})
		var state: Dictionary = state_variant if state_variant is Dictionary else {}
		var acting_player := int(state.get("current_player_index", event.get("player_index", -1)))
		var turn := int(event.get("turn_number", 0))
		if acting_player == loser_index:
			last_turn_any = max(last_turn_any, turn)
			if str(event.get("snapshot_reason", "")) == "turn_start":
				last_turn = max(last_turn, turn)
	return last_turn if last_turn > 0 else last_turn_any


func _replayable_turn_numbers(match_dir: String) -> Array[int]:
	var turns_payload := _read_json(match_dir.path_join("turns.json"))
	var turns: Array = turns_payload.get("turns", [])
	var numbers: Array[int] = []
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		var snapshot_reasons: Array = turn.get("snapshot_reasons", [])
		var has_snapshot := bool(turn.get("has_turn_start_snapshot", false))
		if not has_snapshot:
			has_snapshot = not snapshot_reasons.is_empty()
		if not has_snapshot:
			continue
		numbers.append(int(turn.get("turn_number", 0)))
	return numbers


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _read_json_lines(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			rows.append(parsed)
	file.close()
	return rows
