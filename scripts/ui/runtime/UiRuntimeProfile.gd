class_name UiRuntimeProfile
extends RefCounted

const HOST_NATIVE := "native"
const HOST_WEB := "web"
const HOST_HEADLESS := "headless"

const OS_WINDOWS := "windows"
const OS_ANDROID := "android"
const OS_IOS := "ios"
const OS_MACOS := "macos"
const OS_UNKNOWN := "unknown"

const POINTER_MOUSE := "mouse"
const POINTER_TOUCH := "touch"
const POINTER_HYBRID := "hybrid"

const LAYOUT_COMPACT_PORTRAIT := "compact_portrait"
const LAYOUT_COMPACT_LANDSCAPE := "compact_landscape"
const LAYOUT_WIDE := "wide"

const PERFORMANCE_LOW := "low"
const PERFORMANCE_MEDIUM := "medium"
const PERFORMANCE_HIGH := "high"
const PERFORMANCE_TEST := "test"

var host_kind: String = HOST_NATIVE
var native_os: String = OS_UNKNOWN
var pointer_mode: String = POINTER_MOUSE
var layout_class: String = LAYOUT_WIDE
var has_dom_text_input: bool = false
var supports_pointer_cancel: bool = false
var can_suspend_without_scene_exit: bool = false
var performance_tier: String = PERFORMANCE_HIGH
var is_test_profile: bool = false
var mobile_like: bool = false
var feature_flags: Dictionary = {}
var display_server_name: String = ""
var viewport_size: Vector2 = Vector2.ZERO
var user_agent: String = ""


func _init(values: Dictionary = {}) -> void:
	host_kind = str(values.get("host_kind", host_kind))
	native_os = str(values.get("native_os", native_os))
	pointer_mode = str(values.get("pointer_mode", pointer_mode))
	layout_class = str(values.get("layout_class", layout_class))
	has_dom_text_input = bool(values.get("has_dom_text_input", has_dom_text_input))
	supports_pointer_cancel = bool(values.get("supports_pointer_cancel", supports_pointer_cancel))
	can_suspend_without_scene_exit = bool(values.get("can_suspend_without_scene_exit", can_suspend_without_scene_exit))
	performance_tier = str(values.get("performance_tier", performance_tier))
	is_test_profile = bool(values.get("is_test_profile", is_test_profile))
	mobile_like = bool(values.get("mobile_like", mobile_like))
	feature_flags = (values.get("feature_flags", {}) as Dictionary).duplicate(true)
	display_server_name = str(values.get("display_server_name", display_server_name))
	viewport_size = values.get("viewport_size", viewport_size) as Vector2
	user_agent = str(values.get("user_agent", user_agent))


func is_web() -> bool:
	return host_kind == HOST_WEB


func is_native() -> bool:
	return host_kind == HOST_NATIVE


func is_headless() -> bool:
	return host_kind == HOST_HEADLESS


func prefers_touch() -> bool:
	return pointer_mode in [POINTER_TOUCH, POINTER_HYBRID]


func to_dictionary() -> Dictionary:
	return {
		"host_kind": host_kind,
		"native_os": native_os,
		"pointer_mode": pointer_mode,
		"layout_class": layout_class,
		"has_dom_text_input": has_dom_text_input,
		"supports_pointer_cancel": supports_pointer_cancel,
		"can_suspend_without_scene_exit": can_suspend_without_scene_exit,
		"performance_tier": performance_tier,
		"is_test_profile": is_test_profile,
		"mobile_like": mobile_like,
		"feature_flags": feature_flags.duplicate(true),
		"display_server_name": display_server_name,
		"viewport_size": viewport_size,
		"user_agent": user_agent,
	}


func fingerprint() -> String:
	return JSON.stringify(to_dictionary())
