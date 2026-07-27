class_name TestBrowserLifecycleBridge
extends TestBase

const Bridge := preload("res://scripts/ui/web/BrowserLifecycleBridge.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")


func test_lifecycle_bridge_install_script_covers_browser_cancellation_and_errors() -> String:
	var script := Bridge.build_install_script("__testLifecycleCallback", 7)
	return run_checks([
		assert_true(script.contains("visibilitychange"), "Bridge should observe tab visibility"),
		assert_true(script.contains("pagehide"), "Bridge should observe page suspension"),
		assert_true(script.contains("pageshow"), "Bridge should observe page restoration"),
		assert_true(script.contains("pointercancel"), "Bridge should observe pointer cancellation"),
		assert_true(script.contains("touchcancel"), "Bridge should observe touch cancellation"),
		assert_true(script.contains("visualViewport"), "Bridge should observe the mobile visual viewport"),
		assert_true(script.contains("navigator.userAgent"), "Bridge should provide the browser identity to the centralized runtime profile"),
		assert_true(script.contains("navigator.maxTouchPoints"), "Bridge should expose iPad touch capability even when Safari requests a desktop user agent"),
		assert_true(script.contains("unhandledrejection"), "Bridge should capture rejected browser promises"),
		assert_true(script.contains("removeEventListener"), "Bridge must support deterministic listener cleanup"),
		assert_true(script.contains("__ptcgLifecycleQueue"), "Bridge should drain errors captured before Godot starts"),
		assert_true(script.contains("var generation = 7"), "Callback payloads should carry the installed generation"),
	])


func test_lifecycle_bridge_dispatches_cancel_and_rejects_stale_generation() -> String:
	var bridge: BrowserLifecycleBridge = Bridge.new()
	bridge.set_test_force_web(true)
	var cancel_reasons: Array[String] = []
	bridge.transient_input_cancel_requested.connect(func(reason: String) -> void:
		cancel_reasons.append(reason)
	)
	var installed := bridge.install()
	var generation := bridge.generation()
	var current := bridge.dispatch_event_for_tests("pointercancel", {"pointer_id": 9}, generation)
	bridge.uninstall()
	var stale := bridge.dispatch_event_for_tests("touchcancel", {}, generation)
	bridge.free()
	return run_checks([
		assert_true(installed, "Test Web bridge should install"),
		assert_true(current, "Current generation event should be dispatched"),
		assert_eq(cancel_reasons, ["pointercancel"], "Cancellation should emit exactly once"),
		assert_false(stale, "An uninstalled generation must ignore a late browser callback"),
	])


func test_lifecycle_bridge_install_is_idempotent() -> String:
	var bridge: BrowserLifecycleBridge = Bridge.new()
	bridge.set_test_force_web(true)
	var first := bridge.install()
	var first_generation := bridge.generation()
	var second := bridge.install()
	var second_generation := bridge.generation()
	bridge.free()
	return run_checks([
		assert_true(first and second, "Repeated install should report success"),
		assert_eq(second_generation, first_generation, "Repeated install must not create duplicate listeners or generations"),
	])


func test_platform_cancel_clears_non_battle_candidates_and_dom_text_state() -> String:
	var root := Control.new()
	var button := Button.new()
	var input := LineEdit.new()
	root.add_child(button)
	root.add_child(input)
	root.set_meta("_non_battle_touch_button_candidate", button)
	root.set_meta("_non_battle_touch_drag_start", Vector2(10, 20))
	button.set_meta("_non_battle_touch_pressed", true)
	NonBattleTouchBridgeScript.set_test_web_text_input_enabled(true)
	var requested := NonBattleTouchBridgeScript.request_test_web_text_input(input)
	NonBattleTouchBridgeScript.clear_transient_input_state(root, "pagehide")
	var checks := run_checks([
		assert_true(requested, "Test DOM text input should become active"),
		assert_false(root.has_meta("_non_battle_touch_button_candidate"), "Root button candidate must clear on lifecycle cancel"),
		assert_false(root.has_meta("_non_battle_touch_drag_start"), "Root drag origin must clear on lifecycle cancel"),
		assert_false(button.has_meta("_non_battle_touch_pressed"), "Bound button pressed state must clear recursively"),
		assert_false(input.has_meta("_web_text_input_bridge_active"), "DOM text proxy state must clear without committing again"),
	])
	NonBattleTouchBridgeScript.set_test_web_text_input_enabled(false)
	root.free()
	return checks
