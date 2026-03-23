class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


class SpyAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		if game_state == null or ui_blocked:
			return false
		return game_state.current_player_index == player_index

	func run_single_step(_battle_scene: Control, _gsm: GameStateMachine) -> bool:
		run_count += 1
		return true


func test_ai_opponent_instantiates() -> String:
	var ai := AIOpponentScript.new()
	var blocked_state := GameState.new()
	blocked_state.current_player_index = 0
	var mismatched_state := GameState.new()
	mismatched_state.current_player_index = 1
	var matching_state := GameState.new()
	matching_state.current_player_index = 0

	var initial_checks := run_checks([
		assert_true(ai != null, "AIOpponent should instantiate"),
		assert_true(ai.has_method("configure"), "AIOpponent should expose configure"),
		assert_true(ai.has_method("should_control_turn"), "AIOpponent should expose should_control_turn"),
		assert_true(ai.has_method("run_single_step"), "AIOpponent should expose run_single_step"),
		assert_eq(ai.player_index, 1, "AIOpponent should default to player_index 1"),
		assert_eq(ai.difficulty, 1, "AIOpponent should default to difficulty 1"),
	])
	if initial_checks != "":
		return initial_checks

	ai.configure(0, 3)

	return run_checks([
		assert_eq(ai.player_index, 0, "configure() should update player_index"),
		assert_eq(ai.difficulty, 3, "configure() should update difficulty"),
		assert_false(ai.should_control_turn(null, false), "null game_state should prevent AI turn control"),
		assert_false(ai.should_control_turn(blocked_state, true), "ui_blocked should prevent AI turn control"),
		assert_false(ai.should_control_turn(mismatched_state, false), "AI should not control the wrong player's turn"),
		assert_true(ai.should_control_turn(matching_state, false), "AI should control the configured player's turn"),
		assert_false(ai.run_single_step(null, null), "run_single_step() should remain a safe no-op"),
	])


func test_battle_scene_schedules_ai_in_vs_ai_when_unblocked() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._maybe_run_ai()
	var scheduled_after_maybe_run: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	var checks := run_checks([
		assert_true(scheduled_after_maybe_run, "BattleScene should request a deferred AI step in VS_AI mode on the AI turn"),
		assert_eq(spy_ai.run_count, 1, "BattleScene should execute exactly one AI step when the deferred step runs"),
		assert_false(scene.get("_ai_step_scheduled"), "BattleScene should clear the scheduled AI step flag after running"),
	])
	GameManager.current_mode = previous_mode
	return checks


func test_battle_scene_does_not_schedule_ai_when_mode_turn_or_ui_block_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	var dialog_overlay := Panel.new()
	var handover_panel := Panel.new()
	var field_overlay := Control.new()
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", dialog_overlay)
	scene.set("_handover_panel", handover_panel)
	scene.set("_field_interaction_overlay", field_overlay)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)

	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene._maybe_run_ai()
	var scheduled_outside_vs_ai: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = GameManager.GameMode.VS_AI
	gsm.game_state.current_player_index = 0
	scene._maybe_run_ai()
	var scheduled_on_wrong_turn: bool = scene.get("_ai_step_scheduled")
	gsm.game_state.current_player_index = 1
	dialog_overlay.visible = true
	scene._maybe_run_ai()
	var scheduled_with_dialog: bool = scene.get("_ai_step_scheduled")
	dialog_overlay.visible = false
	handover_panel.visible = true
	scene._maybe_run_ai()
	var scheduled_with_handover: bool = scene.get("_ai_step_scheduled")
	handover_panel.visible = false
	field_overlay.visible = true
	scene._maybe_run_ai()
	var scheduled_with_field_overlay: bool = scene.get("_ai_step_scheduled")
	field_overlay.visible = false
	scene.set("_pending_prize_animating", true)
	scene._maybe_run_ai()
	var scheduled_with_prize_animation: bool = scene.get("_ai_step_scheduled")
	scene.set("_pending_prize_animating", false)

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(scheduled_outside_vs_ai, "AI should not schedule outside VS_AI mode"),
		assert_false(scheduled_on_wrong_turn, "AI should not schedule on the human turn"),
		assert_false(scheduled_with_dialog, "Dialog overlay should block AI scheduling"),
		assert_false(scheduled_with_handover, "Handover prompt should block AI scheduling"),
		assert_false(scheduled_with_field_overlay, "Field interaction overlay should block AI scheduling"),
		assert_false(scheduled_with_prize_animation, "Prize animation should block AI scheduling"),
		assert_eq(spy_ai.run_count, 0, "BattleScene should not run the AI when scheduling is blocked"),
	])
