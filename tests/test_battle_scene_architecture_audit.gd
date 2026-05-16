class_name TestBattleSceneArchitectureAudit
extends TestBase

const BATTLE_SCENE_ENTRY_PATH := "res://scenes/battle/BattleScene.gd"
const BATTLE_SCENE_RUNTIME_PATH := "res://scenes/battle/BattleSceneRuntime.gd"
const BATTLE_SCENE_RUNTIME_LAYER_PATHS := [
	"res://scenes/battle/BattleSceneRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneRuntimeFoundation.gd",
]
const ARCHITECTURE_FILES := [
	"res://scripts/ui/battle/BattleSceneContext.gd",
	"res://scripts/ui/battle/states/BattleLayoutState.gd",
	"res://scripts/ui/battle/states/BattleDialogState.gd",
	"res://scripts/ui/battle/states/BattleInteractionState.gd",
	"res://scripts/ui/battle/states/BattleReplayState.gd",
	"res://scripts/ui/battle/states/BattleOverlayState.gd",
	"res://scripts/ui/battle/states/BattleAiState.gd",
	"res://scripts/ui/battle/states/BattleAdviceState.gd",
	"res://scripts/ui/battle/states/BattleRecordingState.gd",
	"res://scripts/ui/battle/states/BattleEffectState.gd",
	"res://scripts/ui/battle/display/BattleDisplayCoordinator.gd",
	"res://scripts/ui/battle/prompts/BattlePromptRequest.gd",
	"res://scripts/ui/battle/prompts/BattlePromptSelection.gd",
	"res://scripts/ui/battle/prompts/BattlePromptRouter.gd",
	"res://scripts/ui/battle/overlays/BattleOverlayCoordinator.gd",
	"res://scripts/ui/battle/interactions/BattleInteractionCoordinator.gd",
	"res://scripts/ui/battle/recording/BattleRecordingCoordinator.gd",
	"res://scripts/ui/battle/advice/BattleAdviceCoordinator.gd",
	"res://scripts/ui/battle/advice/BattleDiscussionContextBuilder.gd",
	"res://scripts/ui/battle/advice/BattleMatchEndQuickReviewBuilder.gd",
	"res://scripts/ui/battle/ai/BattleAiOpponentFactory.gd",
]


func test_battle_scene_size_is_recorded_under_current_baseline() -> String:
	var entry_text := FileAccess.get_file_as_string(BATTLE_SCENE_ENTRY_PATH)
	var entry_lines := entry_text.split("\n").size()
	var entry_functions := entry_text.count("\nfunc ")
	var runtime_layer_checks: Array[String] = []
	for path: String in BATTLE_SCENE_RUNTIME_LAYER_PATHS:
		var layer_text := FileAccess.get_file_as_string(path)
		var layer_lines := layer_text.split("\n").size()
		runtime_layer_checks.append(assert_true(FileAccess.file_exists(path), "BattleScene runtime layer should exist: %s" % path))
		runtime_layer_checks.append(assert_true(layer_lines < 3000, "BattleScene runtime layer should stay below 3000 lines: %s has %d" % [path, layer_lines]))

	var checks: Array[String] = [
		assert_true(FileAccess.file_exists(BATTLE_SCENE_RUNTIME_PATH), "BattleScene runtime compatibility layer should exist during staged refactor"),
		assert_true(entry_lines < 3000, "BattleScene entry script should stay below the 3000-line target"),
		assert_true(entry_functions < 120, "BattleScene entry script should remain a thin scene shell"),
	]
	checks.append_array(runtime_layer_checks)
	return run_checks(checks)


func test_phase_one_architecture_files_exist() -> String:
	var checks: Array[String] = []
	for path: String in ARCHITECTURE_FILES:
		checks.append(assert_true(FileAccess.file_exists(path), "Expected architecture file to exist: %s" % path))
	return run_checks(checks)


func test_phase_one_architecture_files_do_not_reflect_scene_private_state() -> String:
	var checks: Array[String] = []
	for path: String in ARCHITECTURE_FILES:
		var text := FileAccess.get_file_as_string(path)
		checks.append(assert_false("scene.get(\"_" in text, "%s should not read BattleScene private fields" % path))
		checks.append(assert_false("scene.set(\"_" in text, "%s should not write BattleScene private fields" % path))
		checks.append(assert_false("scene.call(\"_" in text, "%s should not call BattleScene private methods" % path))
	return run_checks(checks)
