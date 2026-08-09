class_name TestBattleSceneArchitectureAudit
extends TestBase

const BATTLE_SCENE_ENTRY_PATH := "res://scenes/battle/BattleScene.gd"
const BATTLE_SCENE_RUNTIME_PATH := "res://scenes/battle/BattleSceneRuntime.gd"
const FIELD_TRANSITION_SERVICE_PATH := "res://scripts/engine/BattleFieldTransitionService.gd"
const BOARD_ACTION_RUNTIME_PATH := "res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd"
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


func test_runtime_active_slot_changes_are_owned_by_one_transition_service() -> String:
	var runtime_paths: Array[String] = [
		"res://scripts/engine/GameStateMachine.gd",
		"res://scripts/engine/EffectProcessor.gd",
	]
	_collect_gd_files("res://scripts/effects", runtime_paths)
	var assignment_pattern := RegEx.new()
	var compiled := assignment_pattern.compile("\\.active_pokemon[\\t ]*=[\\t ]*(?!=)")
	var checks: Array[String] = [
		assert_eq(compiled, OK, "The active-slot architecture guard must compile"),
		assert_true(
			FileAccess.file_exists(FIELD_TRANSITION_SERVICE_PATH),
			"Runtime field changes must have one authoritative transition service"
		),
	]
	if compiled != OK:
		return run_checks(checks)
	for path: String in runtime_paths:
		var source := FileAccess.get_file_as_string(path)
		checks.append(assert_true(
			assignment_pattern.search(source) == null,
			"Runtime code must not mutate active_pokemon outside the transition service: %s" % path
		))
	return run_checks(checks)


func test_prize_rule_commit_precedes_and_is_absent_from_presentation_callbacks() -> String:
	var source := FileAccess.get_file_as_string(BOARD_ACTION_RUNTIME_PATH)
	var interaction_start := source.find("func _try_take_prize_from_slot")
	var animation_start := source.find("func _animate_prize_flip")
	var presentation_end := source.find("func _complete_prize_presentation", animation_start)
	var interaction_source := source.substr(interaction_start, animation_start - interaction_start)
	var animation_source := source.substr(animation_start, presentation_end - animation_start)
	var commit_index := interaction_source.find("resolve_take_prize")
	var animate_index := interaction_source.find("_animate_prize_flip")

	return run_checks([
		assert_true(interaction_start >= 0 and animation_start > interaction_start and presentation_end > animation_start, "Prize runtime boundaries must remain inspectable"),
		assert_true(commit_index >= 0, "The prize interaction must synchronously commit the rule transaction"),
		assert_true(animate_index > commit_index, "Prize rules must commit before presentation begins"),
		assert_false("resolve_take_prize" in animation_source, "Tween callbacks must never own the prize rule commit"),
		assert_false("take_prize_from_slot" in animation_source, "Presentation code must never mutate the authoritative prize zone"),
	])


func _collect_gd_files(root_path: String, output: Array[String]) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry not in [".", ".."]:
			var path := "%s/%s" % [root_path, entry]
			if dir.current_is_dir():
				_collect_gd_files(path, output)
			elif entry.ends_with(".gd"):
				output.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
