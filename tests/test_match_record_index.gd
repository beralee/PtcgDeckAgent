class_name TestMatchRecordIndex
extends TestBase

const MatchRecordIndexScript = preload("res://scripts/engine/MatchRecordIndex.gd")
const TEST_ROOT := "user://test_match_records"


func _init() -> void:
	_clear_test_root()


func _clear_test_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root.path_join(".match_record_index_cache.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_old/detail.jsonl"))
		DirAccess.remove_absolute(absolute_root.path_join("match_new/detail.jsonl"))
		DirAccess.remove_absolute(absolute_root.path_join("match_ai/detail.jsonl"))
		DirAccess.remove_absolute(absolute_root.path_join("match_old/match.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_new/match.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_ai/match.json"))
		DirAccess.remove_absolute(absolute_root.path_join("match_old"))
		DirAccess.remove_absolute(absolute_root.path_join("match_new"))
		DirAccess.remove_absolute(absolute_root.path_join("match_ai"))
		DirAccess.remove_absolute(absolute_root)


func _write_match_fixture(
	match_id: String,
	mode: String,
	winner_index: int,
	final_prize_counts: Array,
	turn_count: int,
	started_at: String = ""
) -> void:
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
	if not started_at.is_empty():
		var detail := FileAccess.open(match_dir.path_join("detail.jsonl"), FileAccess.WRITE)
		if detail != null:
			detail.store_line(JSON.stringify({
				"event_index": 0,
				"event_type": "match_started",
				"timestamp": started_at,
			}))
			detail.close()


func test_match_record_index_lists_native_human_and_ai_replays_newest_first() -> String:
	_clear_test_root()
	_write_match_fixture("match_old", "two_player", 0, [3, 0], 6)
	_write_match_fixture("match_new", "two_player", 1, [0, 2], 9)
	_write_match_fixture("match_ai", "vs_ai", 0, [1, 0], 7)

	var index = MatchRecordIndexScript.new()
	index.set_root(TEST_ROOT)
	var rows: Array = index.list_rows()

	_clear_test_root()
	return run_checks([
		assert_eq(rows.size(), 3, "Two-player and AI native replay rows should be listed"),
		assert_eq(str((rows[0] as Dictionary).get("match_id", "")), "match_ai", "Rows should sort newest first"),
		assert_eq((rows.filter(func(row: Dictionary) -> bool: return str(row.get("match_id", "")) == "match_new")[0] as Dictionary).get("final_prize_counts", []), [0, 2], "Rows should expose final prize counts"),
		assert_true(rows.any(func(row: Dictionary) -> bool: return str(row.get("match_id", "")) == "match_ai"), "VS AI replay must remain discoverable"),
	])


func test_match_record_index_persists_summary_rows_and_invalidates_changed_matches() -> String:
	_clear_test_root()
	_write_match_fixture("match_old", "two_player", 0, [3, 0], 6)
	var first = MatchRecordIndexScript.new()
	first.set_root(TEST_ROOT)
	var first_rows: Array = first.list_rows()
	var cache_path := TEST_ROOT.path_join(".match_record_index_cache.json")
	var second = MatchRecordIndexScript.new()
	second.set_root(TEST_ROOT)
	var cached_rows: Array = second.list_rows()
	var cached_audit: Dictionary = second.audit_snapshot()
	_write_match_fixture("match_old", "two_player", 1, [0, 1], 12345)
	var changed_rows: Array = second.list_rows()
	var changed_audit: Dictionary = second.audit_snapshot()
	var checks := run_checks([
		assert_eq(first_rows, cached_rows, "Persistent summary reuse must not change replay rows"),
		assert_true(FileAccess.file_exists(cache_path), "Replay summaries should persist beside the match-record root"),
		assert_eq(int(cached_audit.get("cache_hits", 0)), 1, "A new index instance should reuse the unchanged match summary"),
		assert_eq((changed_rows[0] as Dictionary).get("turn_count"), 12345, "A changed match.json must invalidate its cached summary"),
		assert_eq(int(changed_audit.get("cache_misses", 0)), 1),
	])
	_clear_test_root()
	return checks


func test_match_record_index_uses_authoritative_match_start_time() -> String:
	_clear_test_root()
	_write_match_fixture(
		"match_ai", "vs_author_strategy_ai", 0, [0, 3], 12,
		"2026-08-23T19:34:12"
	)
	var stale_cache := FileAccess.open(
		TEST_ROOT.path_join(".match_record_index_cache.json"), FileAccess.WRITE
	)
	if stale_cache != null:
		stale_cache.store_string(JSON.stringify({
			"document_type": "match_record_index_cache_v1",
			"schema_version": 1,
			"entries": {},
		}))
		stale_cache.close()
	var index = MatchRecordIndexScript.new()
	index.set_root(TEST_ROOT)
	var rows: Array = index.list_rows()
	var row: Dictionary = rows[0] if not rows.is_empty() else {}
	var rebuilt_cache: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		TEST_ROOT.path_join(".match_record_index_cache.json")
	))
	var checks := run_checks([
		assert_eq(str(row.get("recorded_at", "")), "2026-08-23T19:34:12", "Replay labels must use match_started rather than the final match.json write time"),
		assert_eq(str(row.get("started_at_utc", "")), "2026-08-23T11:34:12Z", "Native and public replay stores need one UTC correlation key"),
		assert_true(int(row.get("recorded_unix", 0)) > 0),
		assert_true(rebuilt_cache is Dictionary and int((rebuilt_cache as Dictionary).get("schema_version", 0)) == 2, "A stale v1 summary cache must be rebuilt before rows are reused"),
	])
	_clear_test_root()
	return checks
