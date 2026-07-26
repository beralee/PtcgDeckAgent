class_name UiRuntimeProfileResolver
extends RefCounted

const UiRuntimeProfileScript := preload("res://scripts/ui/runtime/UiRuntimeProfile.gd")

const COMPACT_LANDSCAPE_MAX_HEIGHT := 720.0
const WIDE_ASPECT_THRESHOLD := 1.45


static func resolve_current(viewport_size: Vector2 = Vector2.ZERO, user_agent: String = "") -> UiRuntimeProfile:
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		var main_loop := Engine.get_main_loop() as SceneTree
		if main_loop != null and main_loop.root != null:
			size = main_loop.root.get_visible_rect().size
	return resolve(OS.get_name(), runtime_feature_flags(), DisplayServer.get_name(), size, user_agent)


static func resolve(
	os_name: String = "",
	feature_flags: Dictionary = {},
	display_server_name: String = "",
	viewport_size: Vector2 = Vector2.ZERO,
	user_agent: String = "",
	overrides: Dictionary = {}
) -> UiRuntimeProfile:
	var flags := feature_flags.duplicate(true)
	var raw_os := os_name.strip_edges().to_lower()
	var normalized_os := _normalize_os_name(os_name)
	var normalized_display := display_server_name.strip_edges().to_lower()
	var normalized_user_agent := user_agent.strip_edges().to_lower()
	var web_runtime := _is_web_runtime(raw_os, normalized_display, flags)
	var headless_runtime := not web_runtime and normalized_display == "headless"
	var mobile_like := _is_mobile_runtime(normalized_os, flags, normalized_user_agent)
	var host_kind := UiRuntimeProfileScript.HOST_NATIVE
	if web_runtime:
		host_kind = UiRuntimeProfileScript.HOST_WEB
	elif headless_runtime:
		host_kind = UiRuntimeProfileScript.HOST_HEADLESS

	var pointer_mode := _pointer_mode(host_kind, mobile_like, flags, overrides)
	var profile := UiRuntimeProfileScript.new({
		"host_kind": host_kind,
		"native_os": normalized_os,
		"pointer_mode": pointer_mode,
		"layout_class": _layout_class(viewport_size),
		"has_dom_text_input": web_runtime,
		"supports_pointer_cancel": web_runtime or pointer_mode != UiRuntimeProfileScript.POINTER_MOUSE,
		"can_suspend_without_scene_exit": web_runtime,
		"performance_tier": _performance_tier(host_kind, normalized_os, mobile_like, flags),
		"is_test_profile": bool(overrides.get("is_test_profile", false)) or headless_runtime,
		"mobile_like": mobile_like,
		"feature_flags": flags,
		"display_server_name": normalized_display,
		"viewport_size": viewport_size,
		"user_agent": user_agent,
	})
	_apply_overrides(profile, overrides)
	return profile


static func runtime_feature_flags() -> Dictionary:
	return {
		"mobile": OS.has_feature("mobile"),
		"android": OS.has_feature("android"),
		"ios": OS.has_feature("ios"),
		"web": OS.has_feature("web"),
		"web_android": OS.has_feature("web_android"),
		"web_ios": OS.has_feature("web_ios"),
	}


static func _normalize_os_name(os_name: String) -> String:
	match os_name.strip_edges().to_lower():
		"windows", "uwp":
			return UiRuntimeProfileScript.OS_WINDOWS
		"android":
			return UiRuntimeProfileScript.OS_ANDROID
		"ios", "iphone", "ipad":
			return UiRuntimeProfileScript.OS_IOS
		"macos", "osx":
			return UiRuntimeProfileScript.OS_MACOS
		_:
			return UiRuntimeProfileScript.OS_UNKNOWN


static func _is_web_runtime(normalized_os: String, display_server_name: String, flags: Dictionary) -> bool:
	if normalized_os in ["web", "html5"] or display_server_name in ["web", "html5"]:
		return true
	for feature: String in ["web", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


static func _is_mobile_runtime(normalized_os: String, flags: Dictionary, user_agent: String) -> bool:
	if normalized_os in [UiRuntimeProfileScript.OS_ANDROID, UiRuntimeProfileScript.OS_IOS]:
		return true
	for feature: String in ["mobile", "android", "ios", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	for marker: String in ["android", "iphone", "ipad", "ipod", "mobile safari", " mobile"]:
		if user_agent.contains(marker):
			return true
	return false


static func _pointer_mode(host_kind: String, mobile_like: bool, flags: Dictionary, overrides: Dictionary) -> String:
	var explicit := str(overrides.get("pointer_mode", "")).strip_edges().to_lower()
	if explicit in [
		UiRuntimeProfileScript.POINTER_MOUSE,
		UiRuntimeProfileScript.POINTER_TOUCH,
		UiRuntimeProfileScript.POINTER_HYBRID,
	]:
		return explicit
	if bool(flags.get("hybrid_pointer", false)):
		return UiRuntimeProfileScript.POINTER_HYBRID
	if mobile_like:
		return UiRuntimeProfileScript.POINTER_TOUCH
	if host_kind == UiRuntimeProfileScript.HOST_HEADLESS and bool(flags.get("touch", false)):
		return UiRuntimeProfileScript.POINTER_TOUCH
	return UiRuntimeProfileScript.POINTER_MOUSE


static func _layout_class(size: Vector2) -> String:
	if size.x <= 0.0 or size.y <= 0.0:
		return UiRuntimeProfileScript.LAYOUT_WIDE
	if size.y > size.x:
		return UiRuntimeProfileScript.LAYOUT_COMPACT_PORTRAIT
	if size.y <= COMPACT_LANDSCAPE_MAX_HEIGHT or size.x / maxf(1.0, size.y) < WIDE_ASPECT_THRESHOLD:
		return UiRuntimeProfileScript.LAYOUT_COMPACT_LANDSCAPE
	return UiRuntimeProfileScript.LAYOUT_WIDE


static func _performance_tier(host_kind: String, normalized_os: String, mobile_like: bool, flags: Dictionary) -> String:
	if host_kind == UiRuntimeProfileScript.HOST_HEADLESS:
		return UiRuntimeProfileScript.PERFORMANCE_TEST
	if bool(flags.get("web_ios", false)):
		return UiRuntimeProfileScript.PERFORMANCE_LOW
	if mobile_like or normalized_os in [UiRuntimeProfileScript.OS_ANDROID, UiRuntimeProfileScript.OS_IOS]:
		return UiRuntimeProfileScript.PERFORMANCE_MEDIUM
	return UiRuntimeProfileScript.PERFORMANCE_HIGH


static func _apply_overrides(profile: UiRuntimeProfile, overrides: Dictionary) -> void:
	if profile == null:
		return
	for key: String in [
		"host_kind",
		"native_os",
		"pointer_mode",
		"layout_class",
		"performance_tier",
	]:
		if overrides.has(key):
			profile.set(key, str(overrides[key]))
	for key: String in [
		"has_dom_text_input",
		"supports_pointer_cancel",
		"can_suspend_without_scene_exit",
		"is_test_profile",
		"mobile_like",
	]:
		if overrides.has(key):
			profile.set(key, bool(overrides[key]))
