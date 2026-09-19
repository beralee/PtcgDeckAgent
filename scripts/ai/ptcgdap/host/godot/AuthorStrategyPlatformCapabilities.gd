class_name AuthorStrategyPlatformCapabilities
extends RefCounted

## Device facts only. Package trust and decision inputs never come from this view.
const ROLLBACK_PREFIX := "ptcgdap/author_strategy/platforms/"
static var _runtime_info: Dictionary = {}


static func inspect(platform_name: String = "") -> Dictionary:
	var actual_os := OS.get_name()
	var requested_os := actual_os if platform_name.is_empty() else platform_name
	var device := {"os":requested_os, "arch":"", "version":"", "android_api":0}
	# A caller naming a different OS cannot manufacture its version or ABI.
	if requested_os == actual_os:
		device["arch"] = "arm64" if OS.has_feature("arm64") else (
			"x86_64" if OS.has_feature("x86_64") else "unsupported"
		)
		if actual_os == "Web":
			device["arch"] = "wasm32"
		device["version"] = OS.get_version()
		if actual_os == "Android" and Engine.has_singleton("JavaClassWrapper"):
			var wrapper: Object = Engine.get_singleton("JavaClassWrapper")
			var version_class: Variant = wrapper.call("wrap", "android.os.Build$VERSION")
			if version_class != null:
				var api: Variant = version_class.get("SDK_INT")
				if typeof(api) == TYPE_INT:
					device["android_api"] = api
	device["enabled"] = bool(ProjectSettings.get_setting(
		ROLLBACK_PREFIX + requested_os.to_lower() + "_enabled", true
	))
	var result := evaluate_device(device, {})
	if bool(result.get("rules_available")) and requested_os.to_lower() not in ["macos", "web"]:
		if _runtime_info.is_empty() and ClassDB.class_exists("PtcgOrtActor"):
			var actor: Object = ClassDB.instantiate("PtcgOrtActor")
			if actor != null and actor.has_method("get_runtime_info"):
				var info: Variant = actor.call("get_runtime_info")
				if info is Dictionary:
					_runtime_info = info.duplicate(true)
		result = evaluate_device(device, _runtime_info)
	return result


static func evaluate_device(device: Dictionary, runtime_info: Dictionary) -> Dictionary:
	var platform := str(device.get("os", "")).to_lower()
	var arch := str(device.get("arch", ""))
	var error := ""
	if platform not in ["windows", "macos", "android", "web"]:
		error = "author_strategy_platform_unsupported"
	elif not bool(device.get("enabled", true)):
		error = "author_strategy_platform_disabled"
	elif (platform == "windows" and arch != "x86_64") \
			or (platform == "macos" and arch not in ["x86_64", "arm64"]) \
			or (platform == "android" and arch not in ["arm64", "x86_64"]):
		error = "author_strategy_architecture_unsupported"
	elif platform == "macos" and not version_at_least(str(device.get("version", "")), 13, 3):
		error = "author_strategy_system_version_unsupported"
	elif platform == "android" and int(device.get("android_api", 0)) < 29:
		error = "author_strategy_system_version_unsupported"
	# Mac and Web ship the data-only rule interpreter, without a model backend.
	var model_available: bool = platform not in ["macos", "web"] and error.is_empty() and bool(runtime_info.get("available", false)) \
		and runtime_info.get("execution_provider") == "CPUExecutionProvider" \
		and version_at_least(str(runtime_info.get("version", "")), 1, 26)
	return {
		"platform":platform, "architecture":arch, "rules_available":error.is_empty(),
		"model_available":model_available, "error_code":error,
		"model_error_code":"" if model_available else (
			"model_web_unavailable" if platform == "web" else (
				"model_macos_temporarily_unavailable" if platform == "macos" else "model_runtime_unavailable"
			)
		),
		"runtime_version":str(runtime_info.get("version", "")),
	}


static func resolve_policy_execution_profile(requested: String, platform_name: String = "") -> String:
	var platform := OS.get_name() if platform_name.is_empty() else platform_name
	# Both Web export presets are single-threaded (including Safari/iOS).
	# Run the same selector and current-window validation through the existing
	# synchronous lane; Thread.start is unavailable in these builds.
	if platform == "Web" and requested == "worker_v1":
		return "main_thread_v1"
	return requested


static func version_at_least(value: String, major: int, minor: int) -> bool:
	var parts := value.split(".")
	if parts.size() < 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	return int(parts[0]) > major or (int(parts[0]) == major and int(parts[1]) >= minor)


static func error_text(code: String) -> String:
	match code:
		"author_strategy_platform_unsupported": return "此平台暂不支持本地策略运行。"
		"author_strategy_platform_disabled": return "此平台的本地策略运行已暂停，已安装策略仍会保留。"
		"author_strategy_architecture_unsupported": return "此设备架构暂不支持本地策略；Android 需要 ARM64 或 x86_64。"
		"author_strategy_system_version_unsupported": return "本地策略需要 macOS 13.3 或 Android 10 及以上系统。"
		"author_strategy_package_not_portable": return "此策略的数据格式尚未通过当前平台的兼容验证。"
		"model_runtime_unavailable": return "此策略需要本地模型组件，请使用包含该组件的游戏版本。"
		"model_macos_temporarily_unavailable": return "Mac 版暂不支持模型策略，请选择规则策略。"
		"model_web_unavailable": return "浏览器版暂不支持模型策略，请选择规则策略，或在 Windows / Android 版运行此策略。"
		"model_runtime_version_unsupported": return "本地模型组件版本不兼容，请更新游戏。"
	return ""
