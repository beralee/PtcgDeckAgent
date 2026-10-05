extends "res://scripts/update/AppUpdater.gd"
## Copied only into the separate debug lab project. Never used by the game.

var simulate_low_space := false

func _parse_artifact(value: Dictionary) -> Dictionary:
	if not OS.has_feature("app_update_lab") or not OS.has_feature("debug"):
		return {}
	var url := str(value.get("url", ""))
	var expression := RegEx.new()
	expression.compile("^http://(127\\.0\\.0\\.1|10\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|192\\.168\\.[0-9]{1,3}\\.[0-9]{1,3}|172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9]{1,3}\\.[0-9]{1,3}):[0-9]{2,5}/(good|slow|drop|truncated|corrupt|invalid|missing|stall)$")
	if expression.search(url) == null:
		return {}
	if value.get("verification") == "android_signature":
		var checked := value.duplicate(true)
		checked.url = Manifest.ANDROID_APK_URL
		checked.arch = "arm64"
		checked.download_id = (Manifest.ANDROID_APK_URL + "\n" + str(checked.get("version", ""))).sha256_text()
		var result := Manifest.validate_artifact(checked, "android", "arm64")
		if not result.is_empty():
			result.url = url
			result.arch = Manifest.architecture()
			result.download_id = (url + "\n" + result.version).sha256_text()
		return result
	var checked := value.duplicate(true)
	checked.url = "https://ptcg.skillserver.cn/lab-validation.apk"
	var result := Manifest.validate_artifact(checked, "android", Manifest.architecture())
	if not result.is_empty():
		result.url = url
	return result

func _available_space() -> int:
	return 1 if simulate_low_space else super._available_space()

func _stall_timeout_ms() -> int:
	return 5000 # Fault cases finish quickly in the lab; game uses 60 seconds.

func reset_case() -> void:
	cancel_download()
	cancel_installation()
	if FileAccess.file_exists(_package_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_package_path()))
	_remove_partial()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	_info = {}
	_artifact = {}
	_set_state("idle", "请选择验证场景。")
