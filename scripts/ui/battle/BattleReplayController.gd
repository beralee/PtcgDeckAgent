class_name BattleReplayController
extends RefCounted

const DEFAULT_PLAYBACK_SPEED := 2.0


func refresh_controls(
	refs: RefCounted,
	battle_mode: String,
	current_turn_index: int,
	turn_numbers: Array,
	loaded_raw_snapshot: Dictionary,
	current_frame_index: int = -1,
	timeline_count: int = 0,
	is_playing: bool = false
) -> void:
	if refs == null:
		return

	var in_replay := battle_mode == "review_readonly"
	for replay_button: Button in refs.call("replay_buttons"):
		if replay_button != null:
			replay_button.visible = in_replay

	var replay_prev_turn_button: Button = refs.get("replay_prev_turn_button")
	var replay_next_turn_button: Button = refs.get("replay_next_turn_button")
	var replay_continue_button: Button = refs.get("replay_continue_button")
	var replay_play_pause_button: Button = refs.get("replay_play_pause_button")
	var replay_speed_option: OptionButton = refs.get("replay_speed_option")
	if replay_prev_turn_button != null:
		replay_prev_turn_button.disabled = current_turn_index <= 0
	if replay_next_turn_button != null:
		replay_next_turn_button.disabled = current_turn_index < 0 or current_turn_index >= turn_numbers.size() - 1
	if replay_continue_button != null:
		replay_continue_button.visible = false
		replay_continue_button.disabled = true
	if replay_play_pause_button != null:
		replay_play_pause_button.visible = in_replay
		var replay_finished := timeline_count > 1 and current_frame_index >= timeline_count - 1
		if is_playing:
			replay_play_pause_button.text = "暂停"
		elif replay_finished:
			replay_play_pause_button.text = "重头播放"
		else:
			replay_play_pause_button.text = "播放"
		replay_play_pause_button.disabled = timeline_count <= 1
	if replay_speed_option != null:
		replay_speed_option.visible = in_replay
		replay_speed_option.disabled = timeline_count <= 1
	if timeline_count > 0:
		if replay_prev_turn_button != null:
			replay_prev_turn_button.disabled = current_frame_index <= 0
		if replay_next_turn_button != null:
			replay_next_turn_button.disabled = current_frame_index < 0 or current_frame_index >= timeline_count - 1


func prepare_launch(launch: Dictionary) -> Dictionary:
	var replay_turn_numbers := _to_int_array(launch.get("turn_numbers", []))

	var requested_entry_turn_number := int(launch.get("entry_turn_number", 0))
	if requested_entry_turn_number > 0 and not replay_turn_numbers.has(requested_entry_turn_number):
		replay_turn_numbers.append(requested_entry_turn_number)
	replay_turn_numbers.sort()
	var entry_turn_number := replay_turn_numbers[0] if not replay_turn_numbers.is_empty() else 0

	return {
		"match_dir": str(launch.get("match_dir", "")),
		"entry_source": str(launch.get("entry_source", "")),
		"turn_numbers": replay_turn_numbers,
		"current_turn_index": replay_turn_numbers.find(entry_turn_number),
		"entry_turn_number": entry_turn_number,
		"requested_entry_turn_number": requested_entry_turn_number,
		"view_player_index": int(launch.get("view_player_index", 0)),
		"selected_deck_ids": _to_int_array(launch.get("selected_deck_ids", [])),
		"player_labels": _to_string_array(launch.get("player_labels", [])),
	}


func default_playback_speed() -> float:
	return DEFAULT_PLAYBACK_SPEED


func load_turn(
	snapshot_loader: RefCounted,
	state_restorer: RefCounted,
	match_dir: String,
	turn_number: int,
	fallback_view_player: int
) -> Dictionary:
	if snapshot_loader == null:
		return {}
	if match_dir.strip_edges() == "" or turn_number <= 0:
		return {}

	var replay_variant: Variant = snapshot_loader.call("load_turn", match_dir, turn_number)
	if not (replay_variant is Dictionary):
		return {}

	var replay: Dictionary = replay_variant
	var loaded_raw_snapshot := (replay.get("raw_snapshot", {}) as Dictionary).duplicate(true)
	var loaded_view_snapshot := (replay.get("view_snapshot", {}) as Dictionary).duplicate(true)
	var restored_game_state: Variant = null
	if state_restorer != null and not loaded_view_snapshot.is_empty():
		restored_game_state = state_restorer.call("restore", loaded_view_snapshot)

	return {
		"loaded_raw_snapshot": loaded_raw_snapshot,
		"loaded_view_snapshot": loaded_view_snapshot,
		"view_player_index": int(replay.get("view_player_index", fallback_view_player)),
		"restored_game_state": restored_game_state,
	}


func step_previous_turn(current_turn_index: int, turn_numbers: Array) -> Dictionary:
	if current_turn_index <= 0:
		return {}
	var next_index := current_turn_index - 1
	return {
		"current_turn_index": next_index,
		"turn_number": turn_numbers[next_index],
	}


func step_next_turn(current_turn_index: int, turn_numbers: Array) -> Dictionary:
	if current_turn_index < 0 or current_turn_index >= turn_numbers.size() - 1:
		return {}
	var next_index := current_turn_index + 1
	return {
		"current_turn_index": next_index,
		"turn_number": turn_numbers[next_index],
	}


func step_previous_frame(current_frame_index: int, timeline_count: int) -> Dictionary:
	if current_frame_index <= 0 or timeline_count <= 0:
		return {}
	return {"frame_index": current_frame_index - 1}


func step_next_frame(current_frame_index: int, timeline_count: int) -> Dictionary:
	if current_frame_index < 0 or current_frame_index >= timeline_count - 1:
		return {}
	return {"frame_index": current_frame_index + 1}


func validate_playback_speed(speed: float) -> Dictionary:
	if speed not in [0.5, 1.0, 2.0, 4.0]:
		return {"accepted": false, "speed": 1.0}
	return {"accepted": true, "speed": speed}


func restore_live_game_state(state_restorer: RefCounted, raw_snapshot: Dictionary) -> Variant:
	if state_restorer == null or raw_snapshot.is_empty():
		return null
	return state_restorer.call("restore", raw_snapshot)


func empty_state() -> Dictionary:
	return {
		"match_dir": "",
		"turn_numbers": [],
		"current_turn_index": -1,
		"entry_source": "",
		"loaded_raw_snapshot": {},
		"loaded_view_snapshot": {},
	}


func _to_int_array(values_variant: Variant) -> Array[int]:
	var values: Array[int] = []
	if not (values_variant is Array):
		return values
	for value_variant: Variant in values_variant:
		values.append(int(value_variant))
	return values


func _to_string_array(values_variant: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (values_variant is Array):
		return values
	for value_variant: Variant in values_variant:
		values.append(str(value_variant))
	return values
