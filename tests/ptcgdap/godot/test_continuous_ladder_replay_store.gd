class_name TestContinuousLadderReplayStore
extends TestBase

const StoreScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/ContinuousLadderReplayStore.gd"
)
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")


func test_series_replay_is_written_atomically_and_never_silently_replaced() -> String:
	var root := "user://ptcgdap-tests/ladder-replay-%d" % Time.get_ticks_usec()
	var created: Dictionary = StoreScript.create(root)
	if not bool(created.get("accepted", false)):
		return "store creation failed: %s" % created
	var store: Variant = created.get("store")
	var replay := {
		"document_type": "godot_v18_public_series_replay_v1",
		"schema_version": 1,
		"profile_id": "godot_v18_ladder_v1",
		"series_id": "series-unit",
		"release_a_id": "release-a",
		"release_b_id": "release-b",
		"created_at_epoch": 1,
		"completed_at_epoch": 2,
		"games": [],
	}
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(replay)
	var first: Dictionary = store.store_replay(replay)
	var second: Dictionary = store.store_replay(replay)
	var changed := replay.duplicate(true)
	changed["completed_at_epoch"] = 3
	var conflict: Dictionary = store.store_replay(changed)
	var path := str(first.get("path", ""))
	return run_checks([
		assert_true(bool(first.get("ok", false))),
		assert_false(bool(first.get("already_downloaded", true))),
		assert_true(FileAccess.file_exists(path)),
		assert_eq(
			FileAccess.get_file_as_bytes(path),
			canonical.get("bytes", PackedByteArray()),
		),
		assert_true(bool(second.get("ok", false))),
		assert_true(bool(second.get("already_downloaded", false))),
		assert_false(bool(conflict.get("ok", true))),
		assert_eq(
			conflict.get("error_code"),
			"continuous_ladder_replay_destination_conflict",
		),
		assert_true(str(first.get("absolute_path", "")).is_absolute_path()),
	])
