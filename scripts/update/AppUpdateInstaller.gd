extends RefCounted

const Manifest := preload("res://scripts/update/AppUpdateManifest.gd")
const CACHE_ROOT := "user://app_updates"


static func availability() -> String:
	if OS.has_feature("editor"):
		return "编辑器中可以检查版本；游戏内安装请使用已导出的游戏。"
	match Manifest.platform_key():
		"windows":
			return "" if OS.get_executable_path().get_extension().to_lower() == "exe" else "当前启动方式不支持自动安装。"
		"macos":
			var target := mac_bundle(OS.get_executable_path())
			if target.is_empty() or target.begins_with("/Volumes/") or "/AppTranslocation/" in target:
				return "请先将游戏移到“应用程序”或可写文件夹，再使用游戏内更新。"
			return ""
		"android":
			return "" if Engine.has_singleton("PtcgAppUpdater") else "当前安装包还没有内置更新组件，请重新安装一次新版以启用。"
	return "此平台请使用重新下载安装入口。"


static func mac_bundle(executable: String) -> String:
	var marker := executable.rfind(".app/Contents/MacOS/")
	return executable.substr(0, marker + 4) if marker > 0 else ""


static func begin(artifact: Dictionary, package_path: String, version: String) -> Dictionary:
	var unsupported := availability()
	if not unsupported.is_empty():
		return {"error": unsupported}
	if Manifest.platform_key() == "android":
		var plugin := Engine.get_singleton("PtcgAppUpdater")
		var status := str(plugin.call("installUpdate", ProjectSettings.globalize_path(package_path), artifact.sha256, str(artifact.size), str(artifact.build)))
		return {"android": true, "status": status} if status in ["preparing", "permission_required"] else {"error": "安装未能开始：%s" % status}
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	var session := ProjectSettings.globalize_path(CACHE_ROOT.path_join(token))
	if DirAccess.make_dir_recursive_absolute(session) != OK:
		return {"error": "无法创建更新安装目录，请检查磁盘空间。"}
	var windows := Manifest.platform_key() == "windows"
	var script_name := "install_windows.ps1" if windows else "install_macos.sh"
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
	var process: int
	if windows:
		var powershell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		process = OS.create_process(powershell, PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script_path, "-PlanPath", plan_path]), false)
	else:
		# Positional arguments only; no interpolation/eval of server or file text.
		process = OS.create_process("/bin/bash", PackedStringArray([script_path, session, str(OS.get_process_id()), plan.package, artifact.sha256, str(artifact.size), artifact.entry, mac_bundle(OS.get_executable_path()), token, version]), false)
	if process <= 0:
		return {"error": "无法启动安装程序；游戏仍可继续使用。"}
	return {"session": session, "process": process, "token": token}
