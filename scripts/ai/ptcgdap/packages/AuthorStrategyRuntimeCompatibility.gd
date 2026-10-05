extends RefCounted
## Requirements are derived from signed policy content, never a package name.
## A version label alone grants no execution or release authority.
const AppVersion = preload("res://scripts/app/AppVersion.gd")
const PROFILES := {
	"damage_forecast_profile": {"legacy-v1": "", "reviewed-gust-v1": "0.6.3"},
	"plan_comparison_profile": {"legacy-v1": "", "resource-continuity-v1": "0.6.3", "resource-continuity-v2": "0.6.3", "card-goals-v1": "0.6.3"},
}

static func inspect(adapter: Dictionary, available: Dictionary = PROFILES) -> Dictionary:
	var required := []
	var missing := []
	var minimum := ""
	for field: String in PROFILES:
		var value: Variant = adapter.get(field, "legacy-v1")
		if not value is String or not PROFILES[field].has(value):
			return {"ok": false, "error_code": "package_runtime_profile_unknown", "runtime_compatibility": {"current_version": AppVersion.current_version(), "minimum_client_version": "", "unknown_profile": true}}
		if value == "legacy-v1":
			continue
		minimum = "0.6.3"
		required.append(field + ":" + value)
		if not available.get(field, {}).has(value):
			missing.append(field + ":" + value)
	var detail := {"current_version": AppVersion.current_version(), "current_build": AppVersion.current_build_number(), "minimum_client_version": minimum, "minimum_client_build": 63 if not minimum.is_empty() else 0, "required_profiles": required, "missing_profiles": missing}
	return {"ok": missing.is_empty(), "error_code": "" if missing.is_empty() else "package_runtime_upgrade_required", "runtime_compatibility": detail}

static func error_text(result: Dictionary) -> String:
	var code := str(result.get("error_code", ""))
	var detail: Dictionary = result.get("runtime_compatibility", {})
	var current := str(detail.get("current_version", AppVersion.current_version()))
	if code == "package_runtime_upgrade_required":
		return "此策略需要游戏 v%s（build %s）或更新的兼容版本；当前为 v%s。请更新游戏并重启后重新导入。" % [detail.get("minimum_client_version", "未知"), detail.get("minimum_client_build", "未知"), current]
	if code == "package_runtime_profile_unknown":
		return "此策略要求当前游戏 v%s 尚未识别的运行能力，无法确定最低支持版本。请向策略作者确认配套客户端；重新打包不能补齐运行能力。" % current
	return ""
