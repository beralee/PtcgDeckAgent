class_name TestMatchRecordIndex
extends TestBase

const MatchRecordIndexScript = preload("res://scripts/engine/MatchRecordIndex.gd")
const TEST_ROOT := "user://test_match_records"


func _init() -> void:
	_clear_test_root()


func _clear_test_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root.path_join("match_old/match.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_new/match.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_ai/match.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_old"))
		DirAccess.remove_absolute(absolute_root.path_join("match_new"))
		DirAccess.remove_absolute(absolute_root.path_join("match_ai"))
		DirAccess.remove_absolute(absolute_root)


func _write_match_fixture(match_id: String, mode: String, winner_index: int, final_prize_counts: Array, turn_count: int) -> void:
	var match_dir := TEST_ROOT.path_join(match_id)
	var absolute_match_dir := ProjectSettings.globalize_path(match_dir)
	DirAccess.make_dir_recursive_absolute(absolute_match_dir)
	var file := FileAccess.open(match_dir.path_join("match.json"), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"meta": {
			"mode": mode,
			"player_labels": ["Player A", "Player B"],
			"first_player_index": 0,
		},
		"result": {
			"winner_index": winner_index,
			"turn_number": turn_count,
			"final_prize_counts": final_prize_counts,
		},
	}))
	file.close()


func test_match_record_index_lists_only_two_player_rows_newest_first() -> String:
	_clear_test_root()
	_write_match_fixture("match_old", "two_player", 0, [3, 0], 6)
	_write_match_fixture("match_new", "two_player", 1, [0, 2], 9)
	_write_match_fixture("match_ai", "vs_ai", 0, [1, 0], 7)

	var index = MatchRecordIndexScript.new()
	index.set_root(TEST_ROOT)
	var rows: Array = index.list_rows()

	_clear_test_root()
	return run_checks([
		assert_eq(rows.size(), 2, "Only two-player rows should be listed"),
		assert_eq(str((rows[0] as Dictionary).get("match_id", "")), "match_new", "Rows should sort newest first"),
		assert_eq((rows[0] as Dictionary).get("final_prize_counts", []), [0, 2], "Rows should expose final prize counts"),
	])
