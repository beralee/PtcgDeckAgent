class_name TestUiRuntimeProfile
extends TestBase

const Profile := preload("res://scripts/ui/runtime/UiRuntimeProfile.gd")
const Resolver := preload("res://scripts/ui/runtime/UiRuntimeProfileResolver.gd")


func test_runtime_profile_distinguishes_web_mobile_from_native_android() -> String:
	var native_android: UiRuntimeProfile = Resolver.resolve(
		"Android", {"android": true, "mobile": true}, "", Vector2(390, 844)
	)
	var web_android: UiRuntimeProfile = Resolver.resolve(
		"Web", {"web": true, "web_android": true, "mobile": true}, "web", Vector2(390, 844)
	)
	return run_checks([
		assert_eq(native_android.host_kind, Profile.HOST_NATIVE, "Native Android must stay on the native host path"),
		assert_eq(web_android.host_kind, Profile.HOST_WEB, "Android browser must use the Web host path"),
		assert_true(native_android.mobile_like, "Native Android should remain mobile-like"),
		assert_true(web_android.mobile_like, "Android browser should remain mobile-like for layout"),
		assert_false(native_android.has_dom_text_input, "Native Android should not use DOM text input"),
		assert_true(web_android.has_dom_text_input, "Mobile Web should expose DOM text input capability"),
		assert_false(native_android.can_suspend_without_scene_exit, "Native Android lifecycle is not the browser lifecycle bridge"),
		assert_true(web_android.can_suspend_without_scene_exit, "Web pages can be suspended without a Godot scene exit"),
	])


func test_runtime_profile_separates_pointer_layout_and_performance_axes() -> String:
	var desktop_web: UiRuntimeProfile = Resolver.resolve(
		"Web", {"web": true}, "web", Vector2(1440, 900), "Desktop Browser"
	)
	var iphone_web: UiRuntimeProfile = Resolver.resolve(
		"Web", {"web": true, "web_ios": true, "mobile": true}, "web", Vector2(390, 844), "iPhone"
	)
	return run_checks([
		assert_eq(desktop_web.pointer_mode, Profile.POINTER_MOUSE, "Desktop Web should default to mouse"),
		assert_eq(desktop_web.layout_class, Profile.LAYOUT_WIDE, "Desktop Web should use wide layout class"),
		assert_eq(desktop_web.performance_tier, Profile.PERFORMANCE_HIGH, "Desktop Web should keep the high presentation tier"),
		assert_eq(iphone_web.pointer_mode, Profile.POINTER_TOUCH, "iPhone Web should default to touch"),
		assert_eq(iphone_web.layout_class, Profile.LAYOUT_COMPACT_PORTRAIT, "iPhone Web should use compact portrait"),
		assert_eq(iphone_web.performance_tier, Profile.PERFORMANCE_LOW, "iPhone Web should use the low-memory presentation tier"),
	])


func test_runtime_profile_explicit_hybrid_pointer_does_not_change_host_or_layout() -> String:
	var profile: UiRuntimeProfile = Resolver.resolve(
		"Windows", {"hybrid_pointer": true}, "windows", Vector2(1280, 800)
	)
	return run_checks([
		assert_eq(profile.host_kind, Profile.HOST_NATIVE, "Hybrid pointer must not turn native Windows into Web"),
		assert_eq(profile.pointer_mode, Profile.POINTER_HYBRID, "Hybrid hardware should expose both pointer families"),
		assert_eq(profile.layout_class, Profile.LAYOUT_WIDE, "Pointer capability must not dictate layout"),
	])


func test_runtime_profile_headless_is_explicit_test_profile() -> String:
	var profile: UiRuntimeProfile = Resolver.resolve("", {}, "headless", Vector2.ZERO)
	return run_checks([
		assert_eq(profile.host_kind, Profile.HOST_HEADLESS, "Headless runner should have a dedicated host kind"),
		assert_true(profile.is_test_profile, "Headless runner should be marked as a test profile"),
		assert_eq(profile.performance_tier, Profile.PERFORMANCE_TEST, "Headless runner should not inherit a device presentation tier"),
	])


func test_game_manager_exposes_profile_without_changing_legacy_web_detection() -> String:
	var profile: UiRuntimeProfile = GameManager.resolve_ui_runtime_profile_for_context(
		"Web",
		{},
		"html5",
		Vector2(390, 844),
		"Mozilla/5.0 (iPhone) Mobile Safari",
		{"is_test_profile": true}
	)
	return run_checks([
		assert_eq(profile.host_kind, Profile.HOST_WEB, "GameManager should expose the centralized Web profile"),
		assert_eq(profile.native_os, Profile.OS_UNKNOWN, "Browser host should not pretend to be native iOS"),
		assert_true(profile.mobile_like, "Mobile Safari user agent should still drive compact layout capability"),
		assert_true(bool(GameManager.call("_is_web_runtime", "Web", {}, "html5")), "Existing Web helper must retain its result during profile introduction"),
		assert_false(bool(GameManager.call("_should_apply_native_screen_orientation", "Web", {"web_ios": true}, "html5")), "Web must continue to avoid native orientation APIs"),
	])
