class_name TestUiInteractionWatchdog
extends TestBase

const RegistryScript := preload("res://scripts/ui/interactions/UiInteractionSessionRegistry.gd")
const SessionScript := preload("res://scripts/ui/interactions/UiInteractionSession.gd")
const WatchdogScript := preload("res://scripts/ui/interactions/UiInteractionWatchdog.gd")


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

