class_name TestUiInteractionSession
extends TestBase

const Session := preload("res://scripts/ui/interactions/UiInteractionSession.gd")
const Registry := preload("res://scripts/ui/interactions/UiInteractionSessionRegistry.gd")


func test_interaction_session_finishes_exactly_once() -> String:
	var session: UiInteractionSession = Session.new({
		"session_id": "draw:1",
		"generation": 1,
		"owner": "draw_reveal",
		"interaction_type": "presentation",
		"opened_at_msec": 1000,
	})
	var finished_counter := {"value": 0}
	session.finished.connect(func(_finished_session: UiInteractionSession) -> void:
		finished_counter["value"] = int(finished_counter["value"]) + 1
	)
	var first := session.complete("tween_finished", 1, 1100)
	var second := session.timeout("late_timer", 1, 1200)
	return run_checks([
		assert_true(first, "The active session should complete"),
		assert_false(second, "A late timer must not finish the session twice"),
		assert_eq(int(finished_counter["value"]), 1, "Finished signal must emit exactly once"),
		assert_eq(session.state, Session.STATE_COMPLETED, "The first terminal state must remain authoritative"),
		assert_eq(session.finish_reason, "tween_finished", "Late callbacks must not replace the finish reason"),
	])


func test_interaction_session_rejects_stale_generation_callback() -> String:
	var session: UiInteractionSession = Session.new({
		"session_id": "dialog:2",
		"generation": 2,
		"owner": "dialog",
		"interaction_type": "required_choice",
		"opened_at_msec": 2000,
	})
	return run_checks([
		assert_false(session.complete("old_callback", 1, 2010), "An old generation must not complete the current prompt"),
		assert_true(session.is_active(), "The current prompt must remain active after a stale callback"),
		assert_true(session.mark_progress(2020, 2), "The current generation should still accept progress"),
		assert_eq(session.last_progress_at_msec, 2020, "Current generation progress should be recorded"),
	])


func test_registry_keeps_one_blocking_session_and_ignores_old_completion() -> String:
	var registry: UiInteractionSessionRegistry = Registry.new()
	var first: UiInteractionSession = registry.open_session(
		"draw", "presentation", "draw_reveal", Session.POLICY_SAFE_COMPLETE_PRESENTATION, 5000, {}, 3000
	)
	var rejected := registry.open_session(
		"dialog", "choice", "required_choice", Session.POLICY_REBUILD_REQUIRED_HUMAN_PROMPT, 10000, {}, 3010
	)
	var second: UiInteractionSession = registry.open_session(
		"dialog", "choice", "required_choice", Session.POLICY_REBUILD_REQUIRED_HUMAN_PROMPT, 10000, {}, 3020, true
	)
	var stale_finish := registry.finish_current(first.session_id, first.generation, "old_tween", 3030)
	return run_checks([
		assert_not_null(first, "The first blocking session should open"),
		assert_null(rejected, "A second blocking session must be rejected without explicit replacement"),
		assert_not_null(second, "Explicit replacement should create a new generation"),
		assert_eq(first.state, Session.STATE_CANCELLED, "Replaced session should close deterministically"),
		assert_false(stale_finish, "The old session callback must not finish the replacement"),
		assert_eq(registry.current_session(), second, "The replacement session must remain current"),
		assert_true(second.is_active(), "The replacement session should remain active"),
	])


func test_registry_times_out_only_after_no_progress_budget() -> String:
	var registry: UiInteractionSessionRegistry = Registry.new()
	var session: UiInteractionSession = registry.open_session(
		"draw", "presentation", "draw_reveal", Session.POLICY_SAFE_COMPLETE_PRESENTATION, 500, {}, 4000
	)
	var early := registry.timeout_if_stalled(4499)
	var timed_out := registry.timeout_if_stalled(4500)
	return run_checks([
		assert_null(early, "Session should stay active before the full timeout budget"),
		assert_eq(timed_out, session, "The stalled current session should be returned for policy handling"),
		assert_eq(session.state, Session.STATE_TIMED_OUT, "Stalled session should reach the timed_out terminal state"),
		assert_null(registry.current_session(), "Registry should release a timed-out blocking session"),
	])
