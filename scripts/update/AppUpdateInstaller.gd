extends RefCounted

const Manifest := preload("res://scripts/update/AppUpdateManifest.gd")
const CACHE_ROOT := "user://app_updates"


static func availability() -> String:
	if OS.has_feature("editor"):
		return "当前是工程开发版，不能在游戏内安装发行版；重启工程也不会安装下载包。请点击“去网页下载”并运行下载后的游戏。"
	match Manifest.platform_key():
		"windows":
			return "" if OS.get_executable_path().get_extension().to_lower() == "exe" else "当前启动方式不支持自动安装。"
		"macos":
			return "macOS 版本请前往官网下载新版。"
		"android":
			return "" if Engine.has_singleton("PtcgAppUpdater") else "当前安装包还没有内置更新组件，请重新安装一次新版以启用。"
	return "此平台请使用“去网页下载”入口。"


static func begin(artifact: Dictionary, package_path: String, version: String, system_installer := false) -> Dictionary:
	var unsupported := availability()
	if not unsupported.is_empty():
		return {"error": unsupported}
	if Manifest.platform_key() == "android":
		var plugin := Engine.get_singleton("PtcgAppUpdater")
		var method := "installUpdateWithSystemInstaller" if system_installer else "installUpdate"
		# Android's JNI singleton dispatches Java calls dynamically; has_method()
		# does not enumerate them. Export inspection checks the actual DEX methods.
		var status := str(plugin.call(method, ProjectSettings.globalize_path(package_path), artifact.sha256, str(artifact.size), str(artifact.build)))
		return {"android": true, "status": status}
	if Manifest.platform_key() != "windows":
		return {"error": "请前往官网下载新版。"}
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	var session := ProjectSettings.globalize_path(CACHE_ROOT.path_join(token))
	if DirAccess.make_dir_recursive_absolute(session) != OK:
		return {"error": "无法创建更新安装目录，请检查磁盘空间。"}
	var script_name := "install_windows.ps1"
	var script_path := session.path_join(script_name)
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	if script == null:
		return {"error": "无法准备更新安装程序。"}
	script.store_string(FileAccess.get_file_as_string("res://scripts/update/" + script_name))
	script.close()
	var plan := {
		"schema": 1, "pid": OS.get_process_id(), "token": token,
		"session": session, "package": ProjectSettings.globalize_path(package_path),
		"sha256": artifact.sha256, "size": artifact.size, "entry": artifact.entry,
		"version": version, "executable": OS.get_executable_path(),
	}
	var plan_path := session.path_join("plan.json")
	var file := FileAccess.open(plan_path, FileAccess.WRITE)
	if file == null:
		return {"error": "无法保存安装计划。"}
	file.store_string(JSON.stringify(plan))
	file.close()
	var powershell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var process := OS.create_process(powershell, PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script_path, "-PlanPath", plan_path]), false)
	if process <= 0:
		return {"error": "无法启动安装程序；游戏仍可继续使用。"}
	return {"session": session, "process": process, "token": token}
