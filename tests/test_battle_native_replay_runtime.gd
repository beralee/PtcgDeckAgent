class_name TestBattleNativeReplayRuntime
extends TestBase

const BattleScenePacked := preload("res://scenes/battle/BattleScene.tscn")
const TEST_ROOT := "user://test_native_replay_runtime"


func _remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry in [".", ".."]:
			continue
		var child_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))


func _card(name: String, card_type: String, owner: int, instance_id: int, hp: int = 0) -> Dictionary:
	return {
		"card_name": name,
		"card_type": card_type,
		"owner_index": owner,
		"instance_id": instance_id,
		"face_up": true,
		"hp": hp,
		"set_code": "TST",
		"card_index": str(instance_id),
	}


func _player(index: int, hand: Array, active_card: Dictionary) -> Dictionary:
	return {
		"player_index": index,
		"hand": hand,
		"deck": [_card("Hidden deck %d" % index, "Item", index, 700 + index)],
		"prizes": [],
		"discard_pile": [],
		"lost_zone": [],
		"active": {
			"pokemon_stack": [active_card],
			"attached_energy": [],
			"attached_tool": {},
			"damage_counters": 0,
			"status_conditions": {},
			"effects": [],
		},
		"bench": [],
	}


func _write_fixture() -> String:
	_remove_dir_recursive(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var file := FileAccess.open(TEST_ROOT.path_join("detail.jsonl"), FileAccess.WRITE)
	if file == null:
		return ""
	var local_hand := [_card("Nest Ball", "Item", 0, 101)]
	var player_active := _card("Pidgeot ex", "Pokemon", 0, 201, 280)
	var ai_active := _card("Drakloak", "Pokemon", 1, 301, 90)
	file.store_line(JSON.stringify({
		"event_index": 0,
		"event_type": "state_snapshot",
		"turn_number": 1,
		"player_index": 0,
		"snapshot_reason": "setup_complete",
		"phase": "main",
		"state": {
			"turn_number": 1,
			"current_player_index": 0,
			"phase": "main",
			"players": [
				_player(0, local_hand, player_active),
				_player(1, [_card("AI hidden card", "Item", 1, 401)], ai_active),
			],
		},
	}))
	file.store_line(JSON.stringify({
		"event_index": 1,
		"event_type": "state_snapshot",
		"turn_number": 1,
		"player_index": 0,
		"snapshot_reason": "turn_start",
		"phase": "main",
		"state": {
			"turn_number": 1,
			"current_player_index": 0,
			"phase": "main",
			"players": [
				_player(0, local_hand, player_active),
				_player(1, [_card("AI hidden card", "Item", 1, 401)], ai_active),
			],
		},
	}))
	file.store_line(JSON.stringify({
		"event_index": 2,
		"event_type": "action_resolved",
		"turn_number": 1,
		"player_index": 1,
		"action_type": GameAction.ActionType.USE_ABILITY,
		"description": "AI used an ability",
		"data": {"ability_name": "Test Ability"},
	}))
	file.store_line(JSON.stringify({
		"event_index": 3,
		"event_type": "state_snapshot",
		"turn_number": 2,
		"player_index": 1,
		"snapshot_reason": "turn_start",
		"phase": "main",
		"state": {
			"turn_number": 2,
			"current_player_index": 1,
			"phase": "main",
			"players": [
				_player(0, local_hand, player_active),
				_player(1, [
					_card("AI hidden card", "Item", 1, 401),
					_card("AI second hidden card", "Item", 1, 402),
				], ai_active),
			],
		},
	}))
	file.close()
	return TEST_ROOT


func test_formal_battle_scene_loads_native_frames_and_real_hand_views() -> String:
	var match_dir := _write_fixture()
	if match_dir.is_empty():
		return "native replay fixture could not be written"
	var previous_mode: int = GameManager.current_mode
	var previous_deck_ids: Array[int] = GameManager.selected_deck_ids.duplicate()
	var previous_player_names: Array[String] = GameManager.battle_player_display_names.duplicate()
	var previous_suppress_navigation: bool = GameManager.suppress_scene_navigation_for_tests
	var previous_requested_scene: String = GameManager.last_requested_scene_path
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [111, 222]
	GameManager.set_battle_player_display_names(["进入录像前玩家", "进入录像前对手"])
	var names_before_scene_instantiation: Array[String] = GameManager.battle_player_display_names.duplicate()
	GameManager.set_battle_replay_launch({
		"match_dir": match_dir,
		"entry_turn_number": 2,
		"entry_source": "loser_key_turn",
		"turn_numbers": [1, 2],
		"view_player_index": 0,
		"selected_deck_ids": [333, 444],
		"player_labels": ["录像玩家", "录像AI"],
	})
	var tree := Engine.get_main_loop() as SceneTree
	var scene := BattleScenePacked.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame

	var hand_container := scene.find_child("HandContainer", true, false) as HBoxContainer
	var first_hand_card := hand_container.get_child(0) as BattleCardView if hand_container != null and hand_container.get_child_count() > 0 else null
	var play_button := scene.find_child("BtnReplayPlayPause", true, false) as Button
	var continue_button := scene.find_child("BtnReplayContinue", true, false) as Button
	var next_button := scene.find_child("BtnReplayNextTurn", true, false) as Button
	var replay_exit_button := scene.find_child("BtnReplayBackToList", true, false) as Button
	var live_exit_button := scene.find_child("BtnBack", true, false) as Button
	var hud_end_turn_button := scene.find_child("HudEndTurnBtn", true, false) as Button
	var speed_option := scene.find_child("OptReplaySpeed", true, false) as OptionButton
	var initial_frame_index := int(scene.get("_replay_current_frame_index"))
	var initial_gsm := scene.get("_gsm") as GameStateMachine
	var initial_turn_number := initial_gsm.game_state.turn_number if initial_gsm != null else -1
	var initial_speed := float(scene.get("_replay_playback_speed"))
	var initial_speed_index := speed_option.selected if speed_option != null else -1
	if next_button != null:
		next_button.pressed.emit()
	await tree.process_frame
	var gsm := scene.get("_gsm") as GameStateMachine
	var manual_step_frame_index := int(scene.get("_replay_current_frame_index"))
	var manual_step_player_index := gsm.game_state.current_player_index if gsm != null else -1
	var hand_after_ai_step := gsm.game_state.players[0].hand if gsm != null else []
	var finished_button_text := play_button.text if play_button != null else ""
	if play_button != null:
		play_button.pressed.emit()
	scene.call("_on_replay_speed_selected", 3)
	scene.call("_advance_replay_playback", 1.0)
	var autoplay_frame_index := int(scene.get("_replay_current_frame_index"))
	var autoplay_finished := not bool(scene.get("_replay_is_playing"))
	var autoplay_finished_button_text := play_button.text if play_button != null else ""
	GameManager.suppress_scene_navigation_for_tests = true
	GameManager.last_requested_scene_path = ""
	if replay_exit_button != null:
		replay_exit_button.pressed.emit()
	var replay_exit_target := GameManager.last_requested_scene_path
	var checks: Array[String] = [
		assert_eq(names_before_scene_instantiation, ["进入录像前玩家", "进入录像前对手"], "Test precondition must install live player labels"),
		assert_eq(str(scene.get("_battle_mode")), "review_readonly", "Native replay must use BattleScene's read-only runtime"),
		assert_eq((scene.get("_replay_timeline") as Array).size(), 3, "Every recorded state snapshot must become one player frame"),
		assert_eq(initial_frame_index, 1, "Native replay must ignore setup frames and open from the first turn-start frame"),
		assert_eq(initial_turn_number, 1, "Native replay must show the first recorded turn on entry"),
		assert_eq(initial_speed, 2.0, "Native replay must default to 2x playback"),
		assert_eq(initial_speed_index, 2, "Native replay speed selector must visibly default to 2x"),
		assert_not_null(first_hand_card, "The normal BattleCardView hand surface must render"),
		assert_eq(first_hand_card.card_instance.card_data.name if first_hand_card != null else "", "Nest Ball", "The recorded hand identity must reach the formal hand UI"),
		assert_true(play_button != null and play_button.visible, "Formal replay must expose play/pause"),
		assert_true(continue_button != null and not continue_button.visible, "Formal replay must never offer live continuation"),
		assert_true(hud_end_turn_button != null and not hud_end_turn_button.visible, "Replay must hide the live end-turn action instead of leaving a disabled gameplay shell"),
		assert_true(live_exit_button != null and not live_exit_button.visible, "Replay must hide the duplicate live exit control"),
		assert_eq(replay_exit_button.text if replay_exit_button != null else "", "退出录像", "Replay must expose one unambiguous exit control"),
		assert_eq(manual_step_frame_index, 2, "Next step must advance from the first turn-start frame to the following recorded state"),
		assert_eq(manual_step_player_index, 1, "Next step must restore the next recorded state"),
		assert_eq(hand_after_ai_step.size(), 1, "The local hand must remain available during the AI frame"),
		assert_eq(hand_after_ai_step[0].card_data.name if not hand_after_ai_step.is_empty() else "", "Nest Ball", "AI frames must keep the recorded local hand identity"),
		assert_eq(finished_button_text, "重头播放", "The play button must become Restart after the final frame"),
		assert_eq(float(scene.get("_replay_playback_speed")), 4.0, "The actual BattleScene player must accept 4x speed"),
		assert_eq(autoplay_frame_index, 2, "Play from the end must restart at turn one and advance through the native timeline"),
		assert_true(autoplay_finished, "Native autoplay must stop immediately when it reaches the final frame"),
		assert_eq(autoplay_finished_button_text, "重头播放", "Native autoplay must expose Restart immediately at the final frame"),
		assert_null(scene.find_child("PublicReplayBattleBackdrop", true, false), "Native replay must not install the public shell renderer"),
		assert_eq(scene.get("_replay_player_labels"), ["录像玩家", "录像AI"], "Recorded labels must stay scene-local instead of becoming live match authority"),
		assert_eq(scene.get("_replay_previous_player_display_names"), ["进入录像前玩家", "进入录像前对手"], "Replay launch must capture the pre-existing live labels before setup resets them"),
		assert_eq(replay_exit_target, GameManager.SCENE_STRATEGY_HUB, "Exiting an AI strategy replay must return to the AI strategy center"),
	]
	scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	checks.append(assert_eq(GameManager.selected_deck_ids, [111, 222], "Leaving replay must restore the user's prior deck selection"))
	checks.append(assert_eq(GameManager.battle_player_display_names, ["进入录像前玩家", "进入录像前对手"], "Leaving replay must restore the user's prior player labels"))
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_deck_ids
	GameManager.set_battle_player_display_names(previous_player_names)
	GameManager.suppress_scene_navigation_for_tests = previous_suppress_navigation
	GameManager.last_requested_scene_path = previous_requested_scene
	_remove_dir_recursive(TEST_ROOT)
	return run_checks(checks)
