class_name TestBattlePromptRouter
extends TestBase

const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleDialogStateScript := preload("res://scripts/ui/battle/states/BattleDialogState.gd")
const BattlePromptRouterScript := preload("res://scripts/ui/battle/prompts/BattlePromptRouter.gd")
const BattlePromptRequestScript := preload("res://scripts/ui/battle/prompts/BattlePromptRequest.gd")
const BattlePromptSelectionScript := preload("res://scripts/ui/battle/prompts/BattlePromptSelection.gd")


class LegacyPromptSpy:
	extends RefCounted

	var calls: Array[String] = []

	func handle(selected_indices: PackedInt32Array) -> void:
		calls.append("handle:%d" % (selected_indices[0] if not selected_indices.is_empty() else -1))


func test_prompt_router_classifies_current_prompt_choice() -> String:
	var context := BattleSceneContextScript.new()
	var dialog_state := BattleDialogStateScript.new()
	dialog_state.set("pending_choice", "setup_active_0")
	context.call("set_state", "dialog", dialog_state)

	var router := BattlePromptRouterScript.new()
	router.call("setup", context)

	return run_checks([
		assert_eq(str(router.call("pending_choice")), "setup_active_0", "Router should read prompt state from context"),
		assert_eq(str(router.call("classify_choice", "setup_active_0")), "setup", "Setup prompt should be classified"),
		assert_eq(str(router.call("classify_choice", "effect_interaction")), "effect", "Effect prompt should be classified"),
		assert_eq(str(router.call("classify_choice", "game_over")), "match_end", "Match end prompt should be classified"),
	])


func test_prompt_router_delegates_to_legacy_handler_during_migration() -> String:
	var router := BattlePromptRouterScript.new()
	var spy := LegacyPromptSpy.new()
	var selected := PackedInt32Array([2])

	router.call("route_choice", selected, Callable(spy, "handle"))

	return run_checks([
		assert_eq(spy.calls, ["handle:2"], "Router should delegate to the current legacy handler while migration is staged"),
	])


func test_prompt_request_and_selection_are_data_only() -> String:
	var request := BattlePromptRequestScript.new()
	request.call("configure", "attack", "Choose", ["a", "b"], {"min_select": 1})
	var selection := BattlePromptSelectionScript.new()
	selection.call("configure", PackedInt32Array([1]))

	var before_reset := run_checks([
		assert_eq(str(request.get("choice")), "attack", "Request should store choice"),
		assert_eq((request.get("items") as Array).size(), 2, "Request should store items"),
		assert_eq(int(selection.call("first_index")), 1, "Selection should expose the first chosen index"),
	])
	if before_reset != "":
		return before_reset

	request.call("reset")
	selection.call("reset")
	return run_checks([
		assert_eq(str(request.get("choice")), "", "Request choice should reset"),
		assert_eq((request.get("items") as Array).size(), 0, "Request items should reset"),
		assert_eq(int(selection.call("first_index")), -1, "Selection should reset"),
	])
