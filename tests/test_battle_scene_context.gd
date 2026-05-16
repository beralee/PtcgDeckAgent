class_name TestBattleSceneContext
extends TestBase

const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleSceneRefsScript := preload("res://scenes/battle/BattleSceneRefs.gd")
const BattleI18nScript := preload("res://scripts/ui/battle/BattleI18n.gd")
const BattleLayoutStateScript := preload("res://scripts/ui/battle/states/BattleLayoutState.gd")
const BattleDialogStateScript := preload("res://scripts/ui/battle/states/BattleDialogState.gd")
const BattleInteractionStateScript := preload("res://scripts/ui/battle/states/BattleInteractionState.gd")
const BattleReplayStateScript := preload("res://scripts/ui/battle/states/BattleReplayState.gd")
const BattleOverlayStateScript := preload("res://scripts/ui/battle/states/BattleOverlayState.gd")
const BattleAiStateScript := preload("res://scripts/ui/battle/states/BattleAiState.gd")


func test_context_defaults_are_safe() -> String:
	var context := BattleSceneContextScript.new()

	return run_checks([
		assert_null(context.get("refs"), "Context should not invent refs"),
		assert_null(context.get("gsm"), "Context should not invent a GameStateMachine"),
		assert_eq(int(context.get("view_player")), 0, "Context should default to player 0 view"),
		assert_eq(str(context.get("battle_mode")), "live", "Context should default to live mode"),
	])


func test_configure_sets_shared_dependencies() -> String:
	var context := BattleSceneContextScript.new()
	var refs := BattleSceneRefsScript.new()
	var i18n := BattleI18nScript.new()
	var gsm := GameStateMachine.new()

	context.call("configure", refs, i18n, gsm, 1, "review_readonly")

	return run_checks([
		assert_eq(context.get("refs"), refs, "Context should keep injected refs"),
		assert_eq(context.get("i18n"), i18n, "Context should keep injected i18n"),
		assert_eq(context.get("gsm"), gsm, "Context should keep injected gsm"),
		assert_eq(int(context.get("view_player")), 1, "Context should keep injected visible player"),
		assert_eq(str(context.get("battle_mode")), "review_readonly", "Context should keep injected battle mode"),
	])


func test_context_accepts_phase_one_states() -> String:
	var context := BattleSceneContextScript.new()
	var layout_state := BattleLayoutStateScript.new()
	var dialog_state := BattleDialogStateScript.new()
	var interaction_state := BattleInteractionStateScript.new()
	var replay_state := BattleReplayStateScript.new()
	var overlay_state := BattleOverlayStateScript.new()
	var ai_state := BattleAiStateScript.new()

	context.call("set_state", "layout", layout_state)
	context.call("set_state", "dialog", dialog_state)
	context.call("set_state", "interaction", interaction_state)
	context.call("set_state", "replay", replay_state)
	context.call("set_state", "overlay", overlay_state)
	context.call("set_state", "ai", ai_state)

	return run_checks([
		assert_eq(context.call("state", "layout"), layout_state, "Context should expose layout state"),
		assert_eq(context.call("state", "dialog"), dialog_state, "Context should expose dialog state"),
		assert_eq(context.call("state", "interaction"), interaction_state, "Context should expose interaction state"),
		assert_eq(context.call("state", "replay"), replay_state, "Context should expose replay state"),
		assert_eq(context.call("state", "overlay"), overlay_state, "Context should expose overlay state"),
		assert_eq(context.call("state", "ai"), ai_state, "Context should expose AI state"),
	])
