class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")

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


func test_battle_scene_only_runs_ai_in_vs_ai_when_unblocked() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_difficulty: int = GameManager.ai_difficulty
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.ai_difficulty = 2
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	var checks := run_checks([
		assert_true(scene._is_ai_turn_ready(), "AI turn should be schedulable"),
		assert_false(scene.get("_ai_opponent") == null, "BattleScene should create an AI opponent on demand"),
		assert_eq(int(scene.get("_ai_opponent").difficulty), 2, "BattleScene should configure AI with GameManager difficulty"),
	])
	GameManager.current_mode = previous_mode
	GameManager.ai_difficulty = previous_difficulty
	return checks


func test_battle_scene_ai_readiness_respects_mode_turn_and_ui_blocks() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var dialog_overlay := Panel.new()
	var handover_panel := Panel.new()
	var field_overlay := Control.new()
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", dialog_overlay)
	scene.set("_handover_panel", handover_panel)
	scene.set("_field_interaction_overlay", field_overlay)
	scene._setup_ai_for_tests()

	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var not_vs_ai_ready: bool = scene._is_ai_turn_ready()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	gsm.game_state.current_player_index = 0
	var wrong_turn_ready: bool = scene._is_ai_turn_ready()
	gsm.game_state.current_player_index = 1
	dialog_overlay.visible = true
	var blocked_by_dialog: bool = scene._is_ai_turn_ready()
	dialog_overlay.visible = false
	handover_panel.visible = true
	var blocked_by_handover: bool = scene._is_ai_turn_ready()
	handover_panel.visible = false
	field_overlay.visible = true
	var blocked_by_field_overlay: bool = scene._is_ai_turn_ready()
	field_overlay.visible = false
	scene.set("_pending_prize_animating", true)
	var blocked_by_prize_animation: bool = scene._is_ai_turn_ready()
	scene.set("_pending_prize_animating", false)

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(not_vs_ai_ready, "AI should not schedule outside VS_AI mode"),
		assert_false(wrong_turn_ready, "AI should not schedule on the human turn"),
		assert_false(blocked_by_dialog, "Dialog overlay should block AI scheduling"),
		assert_false(blocked_by_handover, "Handover prompt should block AI scheduling"),
		assert_false(blocked_by_field_overlay, "Field interaction overlay should block AI scheduling"),
		assert_false(blocked_by_prize_animation, "Prize animation should block AI scheduling"),
	])
