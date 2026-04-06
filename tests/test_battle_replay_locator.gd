class_name TestBattleReplayLocator
extends TestBase

const BattleReplayLocatorScript = preload("res://scripts/engine/BattleReplayLocator.gd")
const TEST_ROOT := "user://test_battle_replay_locator"


func _clear_dir(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path.path_join("review")):
		DirAccess.remove_absolute(absolute_path.path_join("review/review.json"))
		DirAccess.remove_absolute(absolute_path.path_join("review"))
	if FileAccess.file_exists(absolute_path.path_join("match.json")):
		DirAccess.remove_absolute(absolute_path.path_join("match.json"))
	if FileAccess.file_exists(absolute_path.path_join("turns.json")):
		DirAccess.remove_absolute(absolute_path.path_join("turns.json"))
	if FileAccess.file_exists(absolute_path.path_join("detail.jsonl")):
		DirAccess.remove_absolute(absolute_path.path_join("detail.jsonl"))
	if DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _write_jsonl(path: String, lines: Array[Dictionary]) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	for line: Dictionary in lines:
		file.store_line(JSON.stringify(line))
	file.close()


func _write_match_fixture(match_dir: String, include_review: bool) -> void:
	_clear_dir(match_dir)
	_write_json(match_dir.path_join("match.json"), {
		"meta": {
			"mode": "two_player",
			"player_labels": ["Player A", "Player B"],
			"first_player_index": 0,
		},
		"result": {
			"winner_index": 0,
			"reason": "prize_out",
			"turn_count": 6,
		},
	})
	_write_json(match_dir.path_join("turns.json"), {
		"turns": [
			{"turn_number": 4, "snapshot_reasons": ["turn_start"], "has_turn_start_snapshot": true},
			{"turn_number": 5, "snapshot_reasons": ["post_action"], "has_turn_start_snapshot": false},
			{"turn_number": 6, "snapshot_reasons": ["turn_start"], "has_turn_start_snapshot": true},
		]
	})
	_write_jsonl(match_dir.path_join("detail.jsonl"), [
		{"event_index": 0, "event_type": "state_snapshot", "turn_number": 4, "player_index": 0, "snapshot_reason": "turn_start", "state": {"current_player_index": 0}},
		{"event_index": 1, "event_type": "action_resolved", "turn_number": 5, "player_index": 0},
		{"event_index": 2, "event_type": "state_snapshot", "turn_number": 6, "player_index": 1, "snapshot_reason": "turn_start", "state": {"current_player_index": 1}},
	])
	if include_review:
		_write_json(match_dir.path_join("review/review.json"), {
			"status": "completed",
			"selected_turns": [
				{"turn_number": 4, "side": "winner", "player_index": 0},
				{"turn_number": 6, "side": "loser", "player_index": 1},
			],
		})


func test_locator_prefers_loser_key_turn_from_review() -> String:
	var match_dir := TEST_ROOT.path_join("with_review")
	_write_match_fixture(match_dir, true)
	var locator = BattleReplayLocatorScript.new()
	var result: Dictionary = locator.locate(match_dir)
	_clear_dir(match_dir)
	return run_checks([
		assert_eq(int(result.get("entry_turn_number", 0)), 6, "Locator should choose the loser key turn when review exists"),
		assert_eq(str(result.get("entry_source", "")), "loser_key_turn", "Locator should report loser_key_turn source"),
		assert_eq(result.get("turn_numbers", []), [4, 5, 6], "Locator should expose all turns that have any snapshot"),
	])


func test_locator_falls_back_to_loser_last_full_turn_without_review() -> String:
	var match_dir := TEST_ROOT.path_join("no_review")
	_write_match_fixture(match_dir, false)
	var locator = BattleReplayLocatorScript.new()
	var result: Dictionary = locator.locate(match_dir)
	_clear_dir(match_dir)
	return run_checks([
		assert_eq(int(result.get("entry_turn_number", 0)), 6, "Locator should fall back to the loser's last full turn"),
		assert_eq(str(result.get("entry_source", "")), "loser_last_full_turn", "Locator should fall back when review is missing"),
	])
