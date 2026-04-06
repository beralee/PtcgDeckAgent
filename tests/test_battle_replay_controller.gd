class_name TestBattleReplayController
extends TestBase

const BattleReplayControllerScript = preload("res://scripts/ui/battle/BattleReplayController.gd")
const BattleSceneRefsScript = preload("res://scenes/battle/BattleSceneRefs.gd")


class FakeSnapshotLoader extends RefCounted:
	func load_turn(_match_dir: String, _turn_number: int) -> Dictionary:
		return {
			"raw_snapshot": {"state": {"turn_number": 6}},
			"view_snapshot": {"state": {"turn_number": 6, "current_player_index": 1}},
			"view_player_index": 1,
		}


class FakeStateRestorer extends RefCounted:
	func restore(snapshot: Dictionary) -> Dictionary:
		return {"restored_turn": int((snapshot.get("state", {}) as Dictionary).get("turn_number", 0))}


func test_prepare_launch_adds_entry_turn_and_sorts() -> String:
	var controller := BattleReplayControllerScript.new()
	var prepared: Dictionary = controller.call("prepare_launch", {
		"match_dir": "user://match_records/match_a",
		"entry_source": "loser_key_turn",
		"turn_numbers": [6, 2],
		"entry_turn_number": 4,
	})

	return run_checks([
		assert_eq(str(prepared.get("match_dir", "")), "user://match_records/match_a", "Prepared launch should keep the match directory"),
		assert_eq(str(prepared.get("entry_source", "")), "loser_key_turn", "Prepared launch should keep the entry source"),
		assert_eq(prepared.get("turn_numbers", []), [2, 4, 6], "Prepared launch should sort replay turns once it inserts the entry turn"),
		assert_eq(int(prepared.get("current_turn_index", -1)), 1, "Prepared launch should point the replay index at the entry turn"),
	])


func test_refresh_controls_updates_replay_buttons() -> String:
	var controller := BattleReplayControllerScript.new()
	var refs := BattleSceneRefsScript.new()
	var prev_button := Button.new()
	var next_button := Button.new()
	var continue_button := Button.new()
	var back_button := Button.new()
	refs.call("bind_replay_buttons", prev_button, next_button, continue_button, back_button)

	controller.call("refresh_controls", refs, "review_readonly", 0, [4, 6], {})

	return run_checks([
		assert_true(prev_button.visible, "Replay buttons should be visible in review mode"),
		assert_true(next_button.visible, "Replay buttons should be visible in review mode"),
		assert_true(continue_button.visible, "Replay buttons should be visible in review mode"),
		assert_true(back_button.visible, "Replay buttons should be visible in review mode"),
		assert_true(prev_button.disabled, "Previous Turn should be disabled at the first replay turn"),
		assert_false(next_button.disabled, "Next Turn should stay enabled when a later turn exists"),
		assert_true(continue_button.disabled, "Continue From Here should stay disabled until a raw snapshot is loaded"),
	])


func test_load_turn_returns_restored_state_and_view_player() -> String:
	var controller := BattleReplayControllerScript.new()
	var load_result: Dictionary = controller.call(
		"load_turn",
		FakeSnapshotLoader.new(),
		FakeStateRestorer.new(),
		"res://tests/fixtures/match_review_fixture",
		6,
		0
	)

	return run_checks([
		assert_eq(int(load_result.get("view_player_index", -1)), 1, "Loaded replay turns should expose the acting player"),
		assert_eq(int(((load_result.get("loaded_raw_snapshot", {}) as Dictionary).get("state", {}) as Dictionary).get("turn_number", 0)), 6, "Loaded replay turns should keep the raw snapshot"),
		assert_eq(int((load_result.get("restored_game_state", {}) as Dictionary).get("restored_turn", 0)), 6, "Loaded replay turns should restore view state through the restorer"),
	])
