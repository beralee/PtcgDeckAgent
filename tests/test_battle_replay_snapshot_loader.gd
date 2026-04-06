class_name TestBattleReplaySnapshotLoader
extends TestBase

const BattleReplaySnapshotLoaderScript = preload("res://scripts/engine/BattleReplaySnapshotLoader.gd")
const TEST_ROOT := "user://test_battle_replay_loader"


func _clear_dir(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path.path_join("detail.jsonl")):
		DirAccess.remove_absolute(absolute_path.path_join("detail.jsonl"))
	if DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _write_jsonl(path: String, lines: Array[Dictionary]) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	for line: Dictionary in lines:
		file.store_line(JSON.stringify(line))
	file.close()


func _write_full_snapshot_match(match_dir: String) -> void:
	_clear_dir(match_dir)
	_write_jsonl(match_dir.path_join("detail.jsonl"), [
		{
			"event_index": 0,
			"event_type": "state_snapshot",
			"turn_number": 4,
			"player_index": 0,
			"snapshot_reason": "turn_start",
			"state": {
				"current_player_index": 0,
				"players": [
					{
						"player_index": 0,
						"hand": [{"card_name": "Visible A"}, {"card_name": "Visible B"}],
						"deck": [{"card_name": "Deck A"}],
						"active": {"pokemon_name": "Pidgeot ex"},
						"bench": [],
						"discard_pile": [],
						"prizes": [],
						"lost_zone": [],
					},
					{
						"player_index": 1,
						"hand": [{"card_name": "Hidden A"}],
						"deck": [{"card_name": "Hidden Deck"}],
						"active": {"pokemon_name": "Drakloak"},
						"bench": [],
						"discard_pile": [],
						"prizes": [],
						"lost_zone": [],
					},
				],
			},
		},
	])


func test_snapshot_loader_reads_turn_start_snapshot() -> String:
	var loader = BattleReplaySnapshotLoaderScript.new()
	var replay: Dictionary = loader.load_turn("res://tests/fixtures/match_review_fixture", 6)
	return run_checks([
		assert_eq(int(replay.get("turn_number", 0)), 6, "Loader should return the requested turn number"),
		assert_eq(str(replay.get("snapshot_reason", "")), "turn_start", "Loader should prefer turn_start snapshots"),
		assert_eq(int(replay.get("view_player_index", -1)), 1, "Loader should follow the acting player of the loaded turn"),
	])


func test_snapshot_loader_hides_opponent_hand_for_view_player() -> String:
	var match_dir := TEST_ROOT.path_join("full_snapshot_match")
	_write_full_snapshot_match(match_dir)
	var loader = BattleReplaySnapshotLoaderScript.new()
	var replay: Dictionary = loader.load_turn(match_dir, 4)
	var view_snapshot: Dictionary = replay.get("view_snapshot", {})
	var state: Dictionary = view_snapshot.get("state", {})
	var players: Array = state.get("players", [])
	_clear_dir(match_dir)
	return run_checks([
		assert_eq(((players[0] as Dictionary).get("hand", []) as Array).size(), 2, "Acting player's hand should remain visible"),
		assert_true(((players[1] as Dictionary).get("hand", []) as Array).is_empty(), "Opponent hand should be hidden in replay view"),
		assert_true(((players[1] as Dictionary).get("deck", []) as Array).is_empty(), "Opponent deck should be hidden in replay view"),
	])
