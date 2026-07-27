class_name TestUiInteractionWatchdog
extends TestBase

const RegistryScript := preload("res://scripts/ui/interactions/UiInteractionSessionRegistry.gd")
const SessionScript := preload("res://scripts/ui/interactions/UiInteractionSession.gd")
const WatchdogScript := preload("res://scripts/ui/interactions/UiInteractionWatchdog.gd")
const BattleSceneScript := preload("res://scenes/battle/BattleScene.gd")
const DialogControllerScript := preload("res://scripts/ui/battle/BattleDialogController.gd")
const InteractionControllerScript := preload("res://scripts/ui/battle/BattleInteractionController.gd")


class ProgressSceneStub:
	extends RefCounted

	var _dialog_generation := 1
	var _dialog_user_input_generation := -1
	var _dialog_user_input_position := Vector2(-1.0, -1.0)
	var _dialog_user_input_source := ""
	var _dialog_echo_action_pending := ""
	var _dialog_same_position_action_locked := true
	var _dialog_modal_transition_origin_position := Vector2(-1.0, -1.0)
	var progress_sources: Array[String] = []

	func _mark_ui_interaction_progress(source: String = "") -> bool:
		progress_sources.append(source)
		return true

	func _finish_modal_input_interaction(
		_reason: String = "",
		_slot_suppression_mode: String = "arm",
		_origin_position: Vector2 = Vector2(-1.0, -1.0)
	) -> void:
		pass


func test_watchdog_times_out_stalled_session_and_calls_recovery_once() -> String:
	var registry: UiInteractionSessionRegistry = RegistryScript.new()
	var recovered := [0]
	var watchdog: UiInteractionWatchdog = WatchdogScript.new()
	watchdog.setup(registry, func(_session: UiInteractionSession) -> void: recovered[0] += 1)
	var session := registry.open_session(
		"draw_reveal", "draw_reveal", "presentation", SessionScript.POLICY_SAFE_COMPLETE_PRESENTATION,
		1000, {}, 100
	)
	var early := watchdog.tick(1099)
	var timed_out := watchdog.tick(1100)
	var duplicate := watchdog.tick(2200)
	return run_checks([
		assert_eq(early, null, "Watchdog should not recover before the hard timeout"),
		assert_eq(timed_out, session, "Watchdog should return the exact timed-out session"),
		assert_eq(session.state, SessionScript.STATE_TIMED_OUT, "The session should reach a terminal timeout state"),
		assert_eq(recovered[0], 1, "Recovery callback should run exactly once"),
		assert_eq(duplicate, null, "A terminal session must not be recovered twice"),
	])


func test_progress_extends_watchdog_deadline() -> String:
	var registry: UiInteractionSessionRegistry = RegistryScript.new()
	var watchdog: UiInteractionWatchdog = WatchdogScript.new()
	watchdog.setup(registry)
	var session := registry.open_session(
		"effect", "effect_step", "human_choice", SessionScript.POLICY_REBUILD_REQUIRED_HUMAN_PROMPT,
		1000, {}, 100
	)
	session.mark_progress(900, session.generation)
	var original_deadline := watchdog.tick(1100)
	var extended_deadline := watchdog.tick(1900)
	return run_checks([
		assert_eq(original_deadline, null, "Recent progress should keep the interaction alive"),
		assert_eq(extended_deadline, session, "The timeout should be measured from the last real progress"),
	])


func test_battle_scene_marks_only_human_effect_step_progress() -> String:
	var scene := BattleSceneScript.new()
	var registry := RegistryScript.new()
	scene.set("_ui_interaction_sessions", registry)
	var session := registry.open_session(
		"effect_human",
		"effect_step",
		"human_choice",
		SessionScript.POLICY_REBUILD_REQUIRED_HUMAN_PROMPT,
		1000,
		{},
		100
	)
	var marked := bool(scene.call("_mark_ui_interaction_progress", "dialog_card"))
	var refreshed_at := session.last_progress_at_msec
	var early_timeout := registry.timeout_if_stalled(refreshed_at + 999)
	var exact_timeout := registry.timeout_if_stalled(refreshed_at + 1000)

	var ai_session := registry.open_session(
		"effect_ai",
		"effect_step",
		"ai_choice",
		SessionScript.POLICY_AI_FALLBACK,
		1000,
		{},
		200,
		true
	)
	var ai_before := ai_session.last_progress_at_msec
	var ai_marked := bool(scene.call("_mark_ui_interaction_progress", "dialog_card"))
	var result := run_checks([
		assert_true(marked, "Human effect input should refresh the current interaction deadline"),
		assert_true(refreshed_at > 100, "Progress should move the deadline to the real input time"),
		assert_null(early_timeout, "The refreshed session must remain active before its new deadline"),
		assert_eq(exact_timeout, session, "The refreshed session should still retain the configured hard timeout"),
		assert_false(ai_marked, "Human UI input must not extend an AI-owned interaction"),
		assert_eq(ai_session.last_progress_at_msec, ai_before, "AI session progress should remain unchanged"),
	])
	scene.free()
	return result


func test_dialog_and_field_input_forward_progress_to_the_watchdog_session() -> String:
	var scene := ProgressSceneStub.new()
	var dialog_controller := DialogControllerScript.new()
	var interaction_controller := InteractionControllerScript.new()
	dialog_controller.call("_record_dialog_fresh_input", scene, "dialog_card")
	interaction_controller.call("mark_modal_input_consumed", scene, "field_slot_select")
	return run_checks([
		assert_true("dialog_card" in scene.progress_sources, "Card HUD input should mark effect interaction progress"),
		assert_true("field_slot_select" in scene.progress_sources, "Field HUD input should mark effect interaction progress"),
	])
