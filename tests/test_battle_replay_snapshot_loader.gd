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
		{
			"event_index": 1,
			"event_type": "action_resolved",
			"turn_number": 4,
			"player_index": 1,
			"action_type": GameAction.ActionType.DRAW_CARD,
			"description": "AI drew a card",
			"data": {"card_instance_ids": [44]},
		},
		{
			"event_index": 2,
			"event_type": "state_snapshot",
			"turn_number": 4,
			"player_index": 1,
			"snapshot_reason": "after_action_resolved",
			"state": {
				"current_player_index": 1,
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
						"hand": [{"card_name": "Hidden A"}, {"card_name": "Hidden B"}],
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
		assert_eq(((players[1] as Dictionary).get("hand", []) as Array).size(), 1, "Opponent hidden hand count should survive replay filtering"),
		assert_eq(str((((players[1] as Dictionary).get("hand", []) as Array)[0] as Dictionary).get("card_name", "")), "", "Opponent hand identity should be hidden in replay view"),
		assert_eq(((players[1] as Dictionary).get("deck", []) as Array).size(), 1, "Opponent hidden deck count should survive replay filtering"),
	])


func test_timeline_keeps_fixed_local_player_hand_and_pairs_actions_with_snapshots() -> String:
	var match_dir := TEST_ROOT.path_join("full_snapshot_match")
	_write_full_snapshot_match(match_dir)
	var loader = BattleReplaySnapshotLoaderScript.new()
	var timeline: Array = loader.call("load_timeline", match_dir, 0)
	var first: Dictionary = timeline[0] if timeline.size() > 0 else {}
	var second: Dictionary = timeline[1] if timeline.size() > 1 else {}
	var second_state: Dictionary = (second.get("view_snapshot", {}) as Dictionary).get("state", {})
	var second_players: Array = second_state.get("players", [])
	_clear_dir(match_dir)
	return run_checks([
		assert_eq(timeline.size(), 2, "Every state snapshot should become one native replay frame"),
		assert_eq(int(first.get("view_player_index", -1)), 0, "Local replay view must stay on the human seat"),
		assert_eq(((second_players[0] as Dictionary).get("hand", []) as Array).size(), 2, "Human hand identities must remain available during the AI turn"),
		assert_eq(((second_players[1] as Dictionary).get("hand", []) as Array).size(), 2, "AI hidden hand count must remain accurate"),
		assert_eq(str((((second_players[1] as Dictionary).get("hand", []) as Array)[0] as Dictionary).get("card_name", "")), "", "AI hidden hand identity must remain filtered from presentation"),
		assert_eq(str((second.get("action", {}) as Dictionary).get("description", "")), "AI drew a card", "The preceding action must drive the existing battle animation layer"),
	])
