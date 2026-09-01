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


func load_timeline(match_dir: String, view_player_index: int) -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	var pending_action: Dictionary = {}
	for event: Dictionary in _read_json_lines(match_dir.path_join("detail.jsonl")):
		var event_type := str(event.get("event_type", ""))
		if event_type == "action_resolved":
			pending_action = event.duplicate(true)
			continue
		if event_type != "state_snapshot":
			continue
		var raw_snapshot := event.duplicate(true)
		timeline.append({
			"frame_index": timeline.size(),
			"event_index": int(event.get("event_index", timeline.size())),
			"turn_number": int(event.get("turn_number", 0)),
			"snapshot_reason": str(event.get("snapshot_reason", "")),
			"raw_snapshot": raw_snapshot,
			"view_snapshot": _filter_for_view_player(raw_snapshot, view_player_index),
			"view_player_index": view_player_index,
			"action": pending_action.duplicate(true),
		})
		pending_action = {}
	return timeline


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
			player["hand"] = _redact_hidden_cards(player.get("hand", []))
			player["deck"] = _redact_hidden_cards(player.get("deck", []))
		filtered_players.append(player)
	state["players"] = filtered_players
	filtered["state"] = state
	return filtered


func _redact_hidden_cards(cards_variant: Variant) -> Array[Dictionary]:
	var redacted: Array[Dictionary] = []
	if not (cards_variant is Array):
		return redacted
	for card_variant: Variant in cards_variant:
		var card: Dictionary = card_variant if card_variant is Dictionary else {}
		redacted.append({
			"instance_id": int(card.get("instance_id", -1)),
			"owner_index": int(card.get("owner_index", -1)),
			"face_up": false,
		})
	return redacted


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
