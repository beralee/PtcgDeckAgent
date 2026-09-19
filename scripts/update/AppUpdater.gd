extends Node
## Application-lifetime download owner: changing scenes never cancels a download.
## Installation requires an explicit player action from the home screen.

const Manifest := preload("res://scripts/update/AppUpdateManifest.gd")
const Installer := preload("res://scripts/update/AppUpdateInstaller.gd")
const Version := preload("res://scripts/app/AppVersion.gd")
const STATE_PATH := "user://app_updates/pending.json"
const ROOT := "user://app_updates"
const STALL_MS := 60000

signal changed(snapshot: Dictionary)

var _state := "idle"
var _message := ""
var _info: Dictionary = {}
var _artifact: Dictionary = {}
var _request: Node
var _generation := 0
var _downloaded := 0
var _speed := 0.0
var _last_bytes := 0
var _last_progress_ms := 0
var _sample_ms := 0
var _last_emit_ms := 0
var _hash_file: FileAccess
var _hasher: HashingContext
var _verify_path := ""
var _verified_bytes := 0
var _install: Dictionary = {}
var _install_started_ms := 0
var _after_verify := "ready"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_pending()


func snapshot() -> Dictionary:
	return {"state": _state, "message": _message, "info": _info.duplicate(true),
		"downloaded": _downloaded, "total": int(_artifact.get("size", 0)),
		"speed": _speed, "verified": _verified_bytes,
		"install_reason": Installer.availability()}


func offer(info: Dictionary) -> void:
	if _state in ["downloading", "verifying", "installing", "permission_required", "awaiting_install"]:
		return
	# Keep the already verified same release through a manual re-check.
	if _state == "ready" and _info.get("latest_version") == info.get("latest_version") and _artifact == _validated_artifact(info):
		return
	_info = info.duplicate(true)
	_artifact = _validated_artifact(info)
	_set_state("available", str(info.get("native_update_reason", "")) if _artifact.is_empty() else "下载完成后，由你决定何时安装。")


func start_download() -> void:
	if _state in ["downloading", "verifying", "installing", "permission_required", "awaiting_install"]:
		return
	_artifact = _validated_artifact(_info)
	if _artifact.is_empty():
		_fail("这个版本暂未提供适合本机的安全更新包，请使用重新下载安装。")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT)) != OK:
		_fail("无法创建下载目录，请检查存储空间或权限。")
		return
	_downloaded = 0
	_speed = 0
	_last_bytes = 0
	_sample_ms = Time.get_ticks_msec()
	_last_progress_ms = _sample_ms
	if FileAccess.file_exists(_package_path()):
		_begin_verify(_package_path())
		return
	_cancel_request()
	_request = _create_request()
	_request.download_file = _package_path() + ".part"
	_request.timeout = 0.0 # No arbitrary whole-file timeout on slow mobile links.
	add_child(_request)
	var generation := _generation
	_request.request_completed.connect(_on_download_complete.bind(generation))
	_set_state("downloading", "正在下载，可以关闭此窗口继续游戏。")
	var error: int = _request.request(str(_artifact.url), PackedStringArray(["Accept-Encoding: identity", "Cache-Control: no-cache"]))
	if error != OK:
		_fail("无法开始下载，请检查网络后重试。")


func _create_request() -> Node:
	var request := HTTPRequest.new()
	request.use_threads = true
	request.accept_gzip = false
	request.max_redirects = 0
	request.body_size_limit = int(_artifact.size)
	request.download_chunk_size = 256 * 1024
	request.timeout = 0.0
	return request


func cancel_download() -> void:
	if _state not in ["downloading", "verifying"] or _after_verify == "install":
		return
	_cancel_request()
	_hash_file = null
	_hasher = null
	_remove_partial()
	_set_state("cancelled", "下载已取消。已安装的游戏和本地数据不受影响，可以重新下载。")


func install_ready_update() -> void:
	if _state != "ready":
		return
	if not _on_home_screen():
		_message = "请先结束对局并回到首页，再安装更新。"
		_emit()
		return
	var reason := Installer.availability()
	if not reason.is_empty():
		_message = reason
		_emit()
		return
	# Rehash immediately before handing authority to an external installer.
	_after_verify = "install"
	_begin_verify(_package_path())


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _state == "downloading" and _request != null:
		_downloaded = _request.get_downloaded_bytes()
		if _downloaded != _last_bytes:
			_last_progress_ms = now
		if now - _sample_ms >= 500:
			_speed = float(_downloaded - _last_bytes) * 1000.0 / maxi(1, now - _sample_ms)
			_last_bytes = _downloaded
			_sample_ms = now
		if now - _last_progress_ms > STALL_MS:
			_fail("下载连接已中断，请检查网络后重试。")
		elif now - _last_emit_ms >= 250:
			_last_emit_ms = now
			_emit()
	elif _state == "verifying":
		_verify_step()
	elif _state in ["installing", "permission_required", "awaiting_install"]:
		_poll_install()


func _on_download_complete(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, generation: int) -> void:
	if generation != _generation or _state != "downloading":
		return
	_cancel_request()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("下载失败，请重试。若持续失败，可以重新下载安装。（%d / HTTP %d）" % [result, code])
		return
	_begin_verify(_package_path() + ".part")


func _begin_verify(path: String) -> void:
	_verify_path = path
	_hash_file = FileAccess.open(path, FileAccess.READ)
	if _hash_file == null or _hash_file.get_length() != int(_artifact.size):
		_hash_file = null
		_reject_package("下载文件不完整，请重新下载。")
		return
	_downloaded = int(_artifact.size)
	_verified_bytes = 0
	_hasher = HashingContext.new()
	_hasher.start(HashingContext.HASH_SHA256)
	_set_state("verifying", "正在校验更新文件…")


func _verify_step() -> void:
	if _hash_file == null or _hasher == null:
		return
	var remaining := _hash_file.get_length() - _hash_file.get_position()
	var chunk := _hash_file.get_buffer(mini(4 * 1024 * 1024, remaining))
	if chunk.is_empty() and remaining > 0:
		_reject_package("无法读取更新文件，请检查存储空间后重试。")
		return
	_hasher.update(chunk)
	_verified_bytes += chunk.size()
	if _hash_file.get_position() < _hash_file.get_length():
		_emit()
		return
	_hash_file = null
	var actual := _hasher.finish().hex_encode()
	_hasher = null
	if actual != str(_artifact.sha256):
		_reject_package("更新文件校验未通过，已阻止安装。请重新下载。")
		return
	if _verify_path.ends_with(".part"):
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(_verify_path), ProjectSettings.globalize_path(_package_path())) != OK:
			_fail("无法保存更新包，请检查可用空间。")
			return
	_save_pending()
	if _after_verify == "install":
		_after_verify = "ready"
		if not _on_home_screen():
			_set_state("ready", "更新已准备好。回到首页后即可安装。")
			return
		_install = Installer.begin(_artifact, _package_path(), str(_info.latest_version))
		if _install.has("error"):
			_set_state("ready", str(_install.error))
			return
		_install_started_ms = Time.get_ticks_msec()
		_set_state("installing", "正在准备安装，请稍候。")
	else:
		_set_state("ready", "更新已下载并校验。安装会关闭并重新打开游戏，本地牌组和录像会保留。" if Manifest.platform_key() != "android" else "更新已下载并校验。点击安装后，请确认 Android 系统安装提示。")


func _poll_install() -> void:
	if _install.get("android", false):
		var status := str(Engine.get_singleton("PtcgAppUpdater").call("getUpdateStatus"))
		if status == "permission_required" and _state != "permission_required":
			_set_state("permission_required", "请在系统页面允许此游戏安装更新，然后返回游戏；我们会继续打开安装确认。")
		elif status == "awaiting_user" and _state != "awaiting_install":
			_set_state("awaiting_install", "请在 Android 系统提示中确认安装。取消后仍可继续使用当前版本。")
		elif status in ["cancelled", "permission_denied"] or status.begins_with("failed"):
			_set_state("ready", "安装尚未完成，可以再次安装或重新下载安装。（%s）" % status)
		return
	var session := str(_install.get("session", ""))
	if FileAccess.file_exists(session.path_join("failed.txt")):
		_set_state("ready", "安装未能完成，当前版本仍可使用。请检查目录权限和磁盘空间后重试，或重新下载安装。")
	elif FileAccess.file_exists(session.path_join("prepared")):
		if _on_home_screen():
			get_tree().quit()
		else:
			_set_state("ready", "请回到首页后安装更新。")
	elif Time.get_ticks_msec() - _install_started_ms > 120000:
		_set_state("ready", "准备安装超时，当前版本仍可使用。请稍后重试。")


func confirm_healthy_startup() -> void:
	# Called only once the real home scene is ready, not by autoload startup.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ptcg-update-rollback="):
			_set_state("ready", "新版未能正常启动，已恢复上一版本。你可以稍后重试或重新下载安装。")
			continue
		if not argument.begins_with("--ptcg-update-token="):
			continue
		var token := argument.trim_prefix("--ptcg-update-token=")
		if token.length() != 32 or not token.is_valid_hex_number(false):
			continue
		var session := ROOT.path_join(token)
		var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(session.path_join("plan.json")))
		if not plan is Dictionary or plan.get("version") != Version.current_version():
			continue
		var receipt := FileAccess.open(session.path_join("healthy"), FileAccess.WRITE)
		if receipt != null:
			receipt.store_string(Version.current_version())
			receipt.close()
			_set_state("updated", "已更新至 %s，欢迎回来。" % Version.current_display_version())


func _validated_artifact(info: Dictionary) -> Dictionary:
	if not Manifest.valid_version(info.get("latest_version", "")):
		return {}
	if Manifest.compare_versions(str(info.latest_version), Version.current_version()) <= 0:
		return {}
	var value: Variant = info.get("artifact", {})
	return Manifest.validate_artifact(value, Manifest.platform_key(), Manifest.architecture()) if value is Dictionary else {}


func _on_home_screen() -> bool:
	return is_inside_tree() and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://scenes/main_menu/MainMenu.tscn"


func _package_path() -> String:
	return ROOT.path_join(str(_artifact.get("sha256", "invalid")) + (".apk" if _artifact.get("format") == "android_apk" else ".zip"))


func _cancel_request() -> void:
	_generation += 1
	if _request != null:
		_request.cancel_request()
		_request.queue_free()
		_request = null


func _remove_partial() -> void:
	var path := ProjectSettings.globalize_path(_package_path() + ".part")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _reject_package(message: String) -> void:
	_hash_file = null
	_hasher = null
	if _verify_path == _package_path() and FileAccess.file_exists(_verify_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_verify_path))
	_fail(message)


func _fail(message: String) -> void:
	_cancel_request()
	_hash_file = null
	_hasher = null
	_after_verify = "ready"
	_remove_partial()
	_set_state("failed", message)


func _set_state(state: String, message: String) -> void:
	_state = state
	_message = message
	_emit()


func _emit() -> void:
	changed.emit(snapshot())


func _save_pending() -> void:
	var file := FileAccess.open(STATE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_info))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(STATE_PATH + ".tmp"), ProjectSettings.globalize_path(STATE_PATH))


func _restore_pending() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 256 * 1024:
		return
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary:
		return
	_info = saved
	var candidate: Variant = _info.get("artifact", {})
	_artifact = Manifest.validate_artifact(candidate, Manifest.platform_key(), Manifest.architecture()) if candidate is Dictionary else {}
	if _artifact.is_empty() or not Manifest.valid_version(_info.get("latest_version", "")):
		return
	if Manifest.compare_versions(str(_info.latest_version), Version.current_version()) <= 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_package_path()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
		_set_state("updated", "已更新至 %s。" % Version.current_display_version())
		_artifact = {}
	elif FileAccess.file_exists(_package_path()):
		_begin_verify(_package_path())


func _exit_tree() -> void:
	_cancel_request()
	_hash_file = null
