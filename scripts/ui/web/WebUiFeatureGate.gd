class_name WebUiFeatureGate
extends RefCounted

const UiRuntimeProfileResolverScript := preload("res://scripts/ui/runtime/UiRuntimeProfileResolver.gd")

const QUERY_KEY := "web_ui_adapter"
const MODE_LEGACY := "legacy"
const MODE_V2 := "v2"

static var _resolved_mode: String = ""
static var _test_mode: String = ""


static func web_input_adapter_v2_enabled(profile: UiRuntimeProfile = null) -> bool:
	if profile != null and not profile.is_web():
		return false
	if _test_mode == MODE_V2:
		return true
	if _test_mode == MODE_LEGACY:
		return false
	var runtime_profile := profile if profile != null else UiRuntimeProfileResolverScript.resolve_current()
	if runtime_profile == null or not runtime_profile.is_web():
		return false
	return resolved_web_input_mode() == MODE_V2


static func resolved_web_input_mode() -> String:
	if _test_mode in [MODE_LEGACY, MODE_V2]:
		return _test_mode
	if _resolved_mode != "":
		return _resolved_mode
	_resolved_mode = MODE_V2
	if OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		var query_mode: Variant = JavaScriptBridge.eval(
			"(function(){try{return new URLSearchParams(window.location.search).get('%s')||'';}catch(_e){return '';}})();" % QUERY_KEY,
			true
		)
		var normalized := str(query_mode).strip_edges().to_lower()
		if normalized in [MODE_LEGACY, MODE_V2]:
			_resolved_mode = normalized
	return _resolved_mode


static func set_test_mode(mode: String) -> void:
	var normalized := mode.strip_edges().to_lower()
	_test_mode = normalized if normalized in [MODE_LEGACY, MODE_V2] else ""


static func reset_for_tests() -> void:
	_test_mode = ""
	_resolved_mode = ""
