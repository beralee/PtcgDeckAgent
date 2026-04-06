class_name BattleReplaySnapshotLoader
extends RefCounted


func load_turn(match_dir: String, turn_number: int) -> Dictionary:
	var raw_event := _find_turn_snapshot(match_dir, turn_number)
	var raw_state_variant: Variant = raw_event.get("state", {})
	var raw_state: Dictionary = raw_state_variant if raw_state_variant is Dictionary else {}
	var view_player_index := int(raw_state.get("current_player_index", raw_event.get("player_index", -1)))
	return {
		"turn_number": turn_number,
		"snapshot_reason": str(raw_event.get("snapshot_reason", "")),
		"raw_snapshot": raw_event.duplicate(true),
		"view_snapshot": _filter_for_view_player(raw_event, view_player_index),
		"view_player_index": view_player_index,
	}


func _find_turn_snapshot(match_dir: String, turn_number: int) -> Dictionary:
	var first_in_turn: Dictionary = {}
	for event: Dictionary in _read_json_lines(match_dir.path_join("detail.jsonl")):
		if str(event.get("event_type", "")) != "state_snapshot":
			continue
		if int(event.get("turn_number", 0)) != turn_number:
			continue
		if first_in_turn.is_empty():
			first_in_turn = event.duplicate(true)
		if str(event.get("snapshot_reason", "")) == "turn_start":
			return event.duplicate(true)
	return first_in_turn


func _filter_for_view_player(raw_event: Dictionary, view_player_index: int) -> Dictionary:
	var filtered := raw_event.duplicate(true)
	var state_variant: Variant = filtered.get("state", {})
	if not (state_variant is Dictionary):
		return filtered
	var state: Dictionary = state_variant
	var players_variant: Variant = state.get("players", [])
	if not (players_variant is Array):
		return filtered
	var filtered_players: Array[Dictionary] = []
	for player_variant: Variant in players_variant:
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = (player_variant as Dictionary).duplicate(true)
		if int(player.get("player_index", -1)) != view_player_index:
			player["hand"] = []
			player["deck"] = []
		filtered_players.append(player)
	state["players"] = filtered_players
	filtered["state"] = state
	return filtered


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
