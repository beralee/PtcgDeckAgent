class_name TestBattleStateObjects
extends TestBase

const BattleLayoutStateScript := preload("res://scripts/ui/battle/states/BattleLayoutState.gd")
const BattleDialogStateScript := preload("res://scripts/ui/battle/states/BattleDialogState.gd")
const BattleInteractionStateScript := preload("res://scripts/ui/battle/states/BattleInteractionState.gd")
const BattleReplayStateScript := preload("res://scripts/ui/battle/states/BattleReplayState.gd")
const BattleOverlayStateScript := preload("res://scripts/ui/battle/states/BattleOverlayState.gd")
const BattleAiStateScript := preload("res://scripts/ui/battle/states/BattleAiState.gd")
const BattleAdviceStateScript := preload("res://scripts/ui/battle/states/BattleAdviceState.gd")
const BattleRecordingStateScript := preload("res://scripts/ui/battle/states/BattleRecordingState.gd")
const BattleEffectStateScript := preload("res://scripts/ui/battle/states/BattleEffectState.gd")


func test_layout_state_reset_restores_metrics_and_frames() -> String:
	var state := BattleLayoutStateScript.new()
	state.set("play_card_size", Vector2(1, 2))
	state.set("dialog_card_size", Vector2(3, 4))
	state.set("detail_card_size", Vector2(5, 6))
	state.set("portrait_layout_frame_rect", Rect2(1, 2, 3, 4))
	state.set("active_battle_layout_mode", "portrait")

	state.call("reset")

	return run_checks([
		assert_eq(state.get("play_card_size"), Vector2(130, 182), "Layout play card size should reset to the current default"),
		assert_eq(state.get("dialog_card_size"), Vector2(148, 208), "Layout dialog card size should reset to the current default"),
		assert_eq(state.get("detail_card_size"), Vector2(300, 420), "Layout detail card size should reset to the current default"),
		assert_eq(state.get("portrait_layout_frame_rect"), Rect2(), "Layout portrait frame should reset"),
		assert_eq(str(state.get("active_battle_layout_mode")), "", "Layout active mode should reset"),
	])


func test_dialog_state_reset_clears_pending_choice_and_selection() -> String:
	var state := BattleDialogStateScript.new()
	state.set("pending_choice", "retreat")
	state.set("multi_selected_indices", [1, 2])
	state.set("assignment_selected_source_index", 3)
	state.set("assignment_assignments", [{"source": 0, "target": 1}])

	state.call("reset")

	return run_checks([
		assert_eq(str(state.get("pending_choice")), "", "Dialog pending choice should reset"),
		assert_eq((state.get("multi_selected_indices") as Array).size(), 0, "Dialog multi selection should reset"),
		assert_eq(int(state.get("assignment_selected_source_index")), -1, "Dialog assignment source should reset"),
		assert_eq((state.get("assignment_assignments") as Array).size(), 0, "Dialog assignments should reset"),
	])


func test_interaction_state_reset_clears_field_selection() -> String:
	var state := BattleInteractionStateScript.new()
	state.set("mode", "slot_choice")
	state.set("data", {"kind": "test"})
	state.set("selected_indices", [0, 1])
	state.set("assignment_entries", [{"source": 0}])
	state.set("position", "bottom")

	state.call("reset")

	return run_checks([
		assert_eq(str(state.get("mode")), "", "Interaction mode should reset"),
		assert_eq((state.get("data") as Dictionary).size(), 0, "Interaction data should reset"),
		assert_eq((state.get("selected_indices") as Array).size(), 0, "Interaction selection should reset"),
		assert_eq((state.get("assignment_entries") as Array).size(), 0, "Interaction assignments should reset"),
		assert_eq(str(state.get("position")), "center", "Interaction position should reset to center"),
	])


func test_replay_state_reset_clears_loaded_snapshot_and_turn_cursor() -> String:
	var state := BattleReplayStateScript.new()
	state.set("match_dir", "user://matches/test")
	state.set("turn_numbers", [2, 4, 6])
	state.set("current_turn_index", 2)
	state.set("entry_source", "review")
	state.set("loaded_raw_snapshot", {"state": {"turn": 6}})
	state.set("loaded_view_snapshot", {"state": {"turn": 6}})

	state.call("reset")

	return run_checks([
		assert_eq(str(state.get("match_dir")), "", "Replay match dir should reset"),
		assert_eq((state.get("turn_numbers") as Array).size(), 0, "Replay turn numbers should reset"),
		assert_eq(int(state.get("current_turn_index")), -1, "Replay current turn index should reset"),
		assert_eq(str(state.get("entry_source")), "", "Replay entry source should reset"),
		assert_eq((state.get("loaded_raw_snapshot") as Dictionary).size(), 0, "Replay raw snapshot should reset"),
		assert_eq((state.get("loaded_view_snapshot") as Dictionary).size(), 0, "Replay view snapshot should reset"),
	])


func test_overlay_state_tracks_prize_handover_and_match_end() -> String:
	var state := BattleOverlayStateScript.new()
	state.call("start_prize_selection", 1, 2)
	state.call("set_handover", 1, true)
	state.call("set_match_end", 0, "test")

	var before_reset := run_checks([
		assert_true(bool(state.call("has_pending_prize")), "Overlay state should know when prize selection is pending"),
		assert_true(bool(state.get("handover_visible")), "Overlay handover flag should be visible"),
		assert_eq(int(state.get("match_end_winner_index")), 0, "Overlay match end winner should be stored"),
	])
	if before_reset != "":
		return before_reset

	state.call("reset")
	return run_checks([
		assert_false(bool(state.call("has_pending_prize")), "Overlay prize selection should reset"),
		assert_false(bool(state.get("handover_visible")), "Overlay handover visibility should reset"),
		assert_false(bool(state.get("match_end_visible")), "Overlay match end visibility should reset"),
	])


func test_ai_advice_recording_and_effect_states_reset() -> String:
	var ai_state := BattleAiStateScript.new()
	ai_state.set("running", true)
	ai_state.set("llm_waiting", true)
	ai_state.set("latest_opponent_action_text", "attack")

	var advice_state := BattleAdviceStateScript.new()
	advice_state.set("last_result", {"summary": "ok"})
	advice_state.set("review_last_review", {"turns": [1]})
	advice_state.set("busy", true)

	var recording_state := BattleRecordingStateScript.new()
	recording_state.set("output_root", "user://records")
	recording_state.set("started", true)

	var effect_state := BattleEffectStateScript.new()
	effect_state.set("kind", "ability")
	effect_state.set("step_index", 0)
	effect_state.set("steps", [{"type": "slot_select"}])

	ai_state.call("reset")
	advice_state.call("reset")
	recording_state.call("reset")
	effect_state.call("reset")

	return run_checks([
		assert_false(bool(ai_state.call("is_waiting")), "AI wait state should reset"),
		assert_eq(str(ai_state.get("latest_opponent_action_text")), "", "AI latest action text should reset"),
		assert_false(bool(advice_state.get("busy")), "Advice busy flag should reset"),
		assert_false(bool(advice_state.call("has_cached_review")), "Advice cached review should reset"),
		assert_false(bool(recording_state.call("is_active")), "Recording state should reset"),
		assert_false(bool(effect_state.call("is_active")), "Effect state should reset"),
	])
