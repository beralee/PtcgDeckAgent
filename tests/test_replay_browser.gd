class_name TestReplayBrowser
extends TestBase


class FakeRecordIndex extends RefCounted:
	func list_rows() -> Array[Dictionary]:
		return [{
			"match_id": "match_new",
			"match_dir": "user://match_records/match_new",
			"recorded_at": "2026-04-04 13:00",
			"player_labels": ["Player A", "Player B"],
			"winner_index": 1,
			"first_player_index": 0,
			"turn_count": 9,
			"final_prize_counts": [2, 0],
		}]


class FakeReplayLocator extends RefCounted:
	var _result: Dictionary = {}

	func _init(result: Dictionary) -> void:
		_result = result.duplicate(true)

	func locate(_match_dir: String) -> Dictionary:
		return _result.duplicate(true)


func test_main_menu_includes_battle_replay_button() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	var replay_button := scene.get_node_or_null("VBoxContainer/BtnBattleReplay")

	return run_checks([
		assert_true(replay_button is Button, "MainMenu should expose BtnBattleReplay"),
	])


func test_replay_browser_renders_rows_from_record_index() -> String:
	var scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	scene.set("_record_index", FakeRecordIndex.new())
	scene.set("_replay_locator", FakeReplayLocator.new({"entry_turn_number": 6, "entry_source": "loser_key_turn", "turn_numbers": [4, 6]}))
	scene.call("_render_rows")
	var list_container := scene.find_child("ListContainer", true, false) as VBoxContainer
	var first_row := list_container.get_child(0) if list_container != null and list_container.get_child_count() > 0 else null
	var replay_button := first_row.find_child("ReplayButton", true, false) if first_row != null else null
	var delete_button := first_row.find_child("DeleteButton", true, false) if first_row != null else null

	# 收集行内所有 Label 的文本
	var all_text := ""
	if first_row != null:
		for label: Node in _find_labels_recursive(first_row):
			all_text += (label as Label).text + " "

	return run_checks([
		assert_true(list_container != null, "ReplayBrowser should expose ListContainer"),
		assert_eq(list_container.get_child_count(), 1, "ReplayBrowser should render one row for the fake index"),
		assert_true(replay_button is Button, "ReplayBrowser rows should include a Replay button"),
		assert_false((replay_button as Button).disabled, "Replay button should be enabled once locator support is wired"),
		assert_true(delete_button is Button, "ReplayBrowser rows should include a Delete button"),
		assert_true(all_text.contains("Player A"), "Replay rows should include player names"),
		assert_true(all_text.contains("Player B"), "Replay rows should include player names"),
		assert_true(all_text.contains("2026-04-04"), "Replay rows should include the recorded time"),
		assert_true(all_text.contains("2-0"), "Replay rows should include the final prize count"),
	])


func test_replay_browser_launches_battle_scene_with_locator_output() -> String:
	GameManager.consume_battle_replay_launch()
	var scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	scene.set("_auto_navigate_to_battle", false)
	scene.set("_record_index", FakeRecordIndex.new())
	scene.set("_replay_locator", FakeReplayLocator.new({
		"entry_turn_number": 6,
		"entry_source": "loser_key_turn",
		"turn_numbers": [4, 6],
	}))
	scene.call("_on_replay_pressed", {"match_dir": "user://match_records/match_a"})
	var launch: Dictionary = GameManager.consume_battle_replay_launch()

	return run_checks([
		assert_eq(str(launch.get("match_dir", "")), "user://match_records/match_a", "Replay launch should preserve match_dir"),
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay button should forward locator output into GameManager launch state"),
		assert_eq(str(launch.get("entry_source", "")), "loser_key_turn", "Replay button should preserve the locator source"),
	])


func _find_labels_recursive(node: Node) -> Array[Node]:
	var labels: Array[Node] = []
	if node is Label:
		labels.append(node)
	for child: Node in node.get_children():
		labels.append_array(_find_labels_recursive(child))
	return labels
