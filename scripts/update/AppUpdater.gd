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
var _last_install_poll_ms := 0
var _issue := ""
var _system_installer_next := false
var _system_transfer := false
var _system_poll_ms := 0
var _system_download_key := ""
var _download_total := 0
var _open_dialogs: Array[WeakRef] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Recover/abandon a native session left by a killed Android process before
	# restoring the package UI. This also invalidates callbacks from that attempt.
	_read_android_status()
	_restore_pending()
	# UI belongs to the home scene. The autoload owns no global overlay/buttons.


func snapshot() -> Dictionary:
	return {"state": _state, "message": _message, "info": _info.duplicate(true),
		"downloaded": _downloaded, "total": int(_artifact.get("size", 0)) if int(_artifact.get("size", 0)) > 0 else _download_total,
		"speed": _speed, "verified": _verified_bytes,
		"install_reason": _install_availability(), "issue": _issue,
		"compatibility_install": _system_installer_next or _issue in ["failed_3", "failed_confirmation", "failed_install", "failed_external", "external_cancelled", "install_timeout", "cancelled_restart"],
		"system_download": _system_transfer, "notifications_enabled": _notifications_enabled()}


func offer(info: Dictionary) -> void:
	if _state in ["downloading", "verifying", "installing", "permission_required", "awaiting_install"]:
		return
	if _is_editor_runtime():
		_info = info.duplicate(true)
		_info["website_only"] = true
		_info["artifact"] = {}
		_info["native_update_reason"] = _install_availability()
		_artifact = {}
		_set_state("available", _install_availability())
		return
	# Keep the already verified same release through a manual re-check.
	var offered := _validated_artifact(info)
	if _state == "ready" and _info.get("latest_version") == info.get("latest_version") and (_artifact == offered or (offered.get("verification") == "android_signature" and offered.get("url") == _artifact.get("url"))):
		return
	_info = info.duplicate(true)
	_system_installer_next = false
	_artifact = _validated_artifact(info)
	_info["artifact"] = _artifact.duplicate(true)
	_set_state("available", str(info.get("native_update_reason", "")) if _artifact.is_empty() else "下载完成后，由你决定何时安装。")


func start_download() -> void:
	if _is_editor_runtime():
		_set_state("available", _install_availability())
		return
	if _state in ["downloading", "verifying", "installing", "permission_required", "awaiting_install"]:
		return
	_system_installer_next = false
	_artifact = _validated_artifact(_info)
	if _artifact.is_empty():
		_fail("这个版本暂未提供适合本机的安全更新包，请点击“去网页下载”。")
		return
	_system_download_key = _download_key()
	_download_total = 0
	if _is_fixed_download() and not _uses_system_download():
		_fail("当前安装包缺少 Android 更新组件，请使用去网页下载。")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT)) != OK:
		_fail("无法创建下载目录，请检查存储空间或权限。")
		return
	var space := _available_space()
	if space >= 0 and space < int(_artifact.size) + 16 * 1024 * 1024:
		_issue = "storage"
		_fail("存储空间不足，请清理空间后重新下载。当前游戏和本地数据不受影响。")
		return
	_issue = ""
	_save_pending() # Also records how to recover an interrupted download.
	_downloaded = 0
	_speed = 0
	_last_bytes = 0
	_sample_ms = Time.get_ticks_msec()
	_last_progress_ms = _sample_ms
	if not _is_fixed_download() and FileAccess.file_exists(_package_path()):
		_begin_verify(_package_path())
		return
	if _uses_system_download():
		_system_transfer = true
		_set_state("downloading", "系统正在下载，通知栏可查看进度；离开游戏也会继续。")
		_apply_system_download(_start_system_download())
		return
	_cancel_request()
	_request = _create_request()
	if _request == null:
		_fail("无法创建下载任务，请稍后重试或点击“去网页下载”。")
		return
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
	# Godot's threaded request uses blocking reads and joins on cancel_request().
	# A peer that never sends its body can otherwise freeze timeout/cancellation.
	request.use_threads = false
	request.accept_gzip = false
	request.max_redirects = 0
	request.body_size_limit = int(_artifact.size)
	request.download_chunk_size = 256 * 1024
	request.timeout = 0.0
	return request


func _uses_system_download() -> bool:
	# Android plugin calls are JNI-dispatched; Object.has_method() does not list
	# these Java methods. The plugin and this script ship together in the APK.
	return OS.get_name() == "Android" and Engine.has_singleton("PtcgAppUpdater")


func _start_system_download() -> Dictionary:
	if _is_fixed_download():
		var result: Variant = JSON.parse_string(str(Engine.get_singleton("PtcgAppUpdater").call("startFixedDownload", _artifact.url, _download_key(), _artifact.version, str(_info.get("display_version", "新版本")))))
		return result if result is Dictionary else {"state": "failed"}
	var value: Variant = JSON.parse_string(str(Engine.get_singleton("PtcgAppUpdater").call("startDownload", _artifact.url, _artifact.sha256, str(_artifact.size), str(_info.get("display_version", "新版本")))))
	return value if value is Dictionary else {"state": "failed"}


func _system_download_status() -> Dictionary:
	var value: Variant = JSON.parse_string(str(Engine.get_singleton("PtcgAppUpdater").call("getDownloadStatus", _system_download_key if not _system_download_key.is_empty() else _download_key())))
	return value if value is Dictionary else {"state": "failed"}


func _cancel_system_download() -> void:
	if _uses_system_download():
		Engine.get_singleton("PtcgAppUpdater").call("cancelDownload", _system_download_key if not _system_download_key.is_empty() else _download_key())


func _notifications_enabled() -> bool:
	return not _uses_system_download() or bool(Engine.get_singleton("PtcgAppUpdater").call("updateNotificationsEnabled"))


func open_notification_settings() -> void:
	if _uses_system_download():
		Engine.get_singleton("PtcgAppUpdater").call("openUpdateNotificationSettings")


func _poll_system_download() -> void:
	_apply_system_download(_system_download_status())


func _apply_system_download(data: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	_downloaded = int(data.get("downloaded", 0))
	_download_total = maxi(0, int(data.get("total", 0)))
	if now - _sample_ms >= 500:
		_speed = maxf(0, float(_downloaded - _last_bytes) * 1000.0 / maxi(1, now - _sample_ms))
		_last_bytes = _downloaded
		_sample_ms = now
	match str(data.get("state", "failed")):
		"completed":
			_system_transfer = false
			var downloaded_path := _package_path()
			if _is_fixed_download() and not _accept_fixed_package(data.get("resolved", {})):
				_fail("安装包未通过身份校验，请重新下载或去网页下载。")
				return
			_begin_verify(downloaded_path)
		"failed", "missing":
			var validation := str(data.get("validation_error", ""))
			if validation in ["failed_package_invalid", "failed_identity", "failed_signer", "failed_version"]:
				_handle_android_status(validation)
				return
			var reason := int(data.get("reason", 0))
			_issue = "system_download_%d" % reason
			_fail("存储空间不足，请清理后重新下载。" if reason == 1006 else "系统下载未完成或任务已取消，请重新下载。当前游戏仍可使用。")
		"paused":
			_speed = 0
			_set_state("downloading", "正在等待 Wi-Fi，连接后系统会继续下载。" if int(data.get("reason", 0)) == 3 else "正在等待网络或系统重试，恢复后会继续下载。")
		"importing":
			_speed = 0
			_set_state("downloading", "下载已完成，正在整理文件，随后将校验安装包…")
		"pending":
			_set_state("downloading", "下载已交给系统，正在等待开始；通知栏可查看进度。")
		_:
			_set_state("downloading", "系统正在下载，通知栏可查看进度；离开游戏也会继续。")


func _available_space() -> int:
	var directory := DirAccess.open(ROOT)
	return directory.get_space_left() if directory != null else -1


func _is_fixed_download() -> bool:
	return _artifact.get("verification") == "android_signature"


func _download_key() -> String:
	return str(_artifact.get("download_id", _artifact.get("sha256", "invalid")))


func _accept_fixed_package(resolved: Variant) -> bool:
	if not resolved is Dictionary or resolved.get("version") != _info.get("latest_version"):
		return false
	# Only native download status calls this after checking APK identity, signing
	# certificates and version. It is never merged from the public manifest.
	var candidate := {"url": _artifact.url, "format": _artifact.format, "arch": _artifact.arch,
		"entry": _artifact.entry, "size": resolved.get("size"), "sha256": resolved.get("sha256"), "build": resolved.get("build")}
	var parsed := _parse_artifact(candidate)
	if parsed.is_empty():
		return false
	_artifact = parsed
	_info["artifact"] = parsed.duplicate(true)
	return true


func _stall_timeout_ms() -> int:
	return STALL_MS


func _install_availability() -> String:
	return Installer.availability()


func _is_editor_runtime() -> bool:
	return OS.has_feature("editor")


func redownload() -> void:
	if _state not in ["ready", "failed", "cancelled", "available"]:
		return
	_cancel_system_download()
	if FileAccess.file_exists(_package_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_package_path()))
	_remove_partial()
	_set_state("available", "正在重新下载更新包。")
	start_download()


func cancel_installation() -> void:
	if not _install.get("android", false) or _state not in ["installing", "permission_required", "awaiting_install"]:
		return
	_cancel_android_install()
	_install = {}
	_set_state("ready", "安装已取消，当前游戏仍可使用。需要时可以再次安装或去网页下载。")


func _cancel_android_install() -> void:
	if Engine.has_singleton("PtcgAppUpdater"):
		Engine.get_singleton("PtcgAppUpdater").call("cancelUpdate")


func _read_android_status() -> String:
	return str(Engine.get_singleton("PtcgAppUpdater").call("getUpdateStatus")) if Engine.has_singleton("PtcgAppUpdater") else "failed_activity"


func cancel_download() -> void:
	if _state not in ["downloading", "verifying"] or _after_verify == "install":
		return
	if _system_transfer:
		_cancel_system_download()
		_system_transfer = false
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
	var reason := _install_availability()
	if not reason.is_empty():
		_message = reason
		_emit()
		return
	# Rehash immediately before handing authority to an external installer.
	_system_installer_next = bool(snapshot().compatibility_install)
	_after_verify = "install"
	_begin_verify(_package_path())


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _state == "downloading" and _system_transfer:
		if now - _system_poll_ms >= 500:
			_system_poll_ms = now
			_poll_system_download()
	elif _state == "downloading" and _request != null:
		_downloaded = _request.get_downloaded_bytes()
		if _downloaded != _last_bytes:
			_last_progress_ms = now
		if now - _sample_ms >= 500:
			_speed = float(_downloaded - _last_bytes) * 1000.0 / maxi(1, now - _sample_ms)
			_last_bytes = _downloaded
			_sample_ms = now
		if now - _last_progress_ms > _stall_timeout_ms():
			_issue = "network_timeout"
			_fail("下载连接已中断，请检查网络后重试。")
		elif now - _last_emit_ms >= 250:
			_last_emit_ms = now
			_emit()
	elif _state == "verifying":
		_verify_step()
	elif _state in ["installing", "permission_required", "awaiting_install"] and now - _last_install_poll_ms >= 250:
		_last_install_poll_ms = now
		_poll_install()


func _on_download_complete(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, generation: int) -> void:
	if generation != _generation or _state != "downloading":
		return
	_cancel_request()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_issue = "download_%d_http_%d" % [result, code]
		if result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN or result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			_fail("无法保存下载文件，请检查存储空间后重试。")
		else:
			_fail("下载未完成，可能是网络中断或下载地址暂时不可用。请重新下载，半包不会用于安装。")
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
	_cancel_system_download() # Verified private copy now owns installation; clean OS cache.
	if _verify_path != _package_path():
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(_verify_path), ProjectSettings.globalize_path(_package_path())) != OK:
			_fail("无法保存更新包，请检查可用空间。")
			return
	_save_pending()
	if _after_verify == "install":
		_after_verify = "ready"
		if not _on_home_screen():
			_set_state("ready", "更新已准备好。回到首页后即可安装。")
			return
		_install = Installer.begin(_artifact, _package_path(), str(_info.latest_version), _system_installer_next)
		if _install.has("error"):
			_set_state("ready", str(_install.error))
			return
		_install_started_ms = Time.get_ticks_msec()
		_set_state("installing", "正在准备安装，请稍候。")
		if _install.get("android", false):
			_handle_android_status(str(_install.get("status", "preparing")))
	else:
		_set_state("ready", "更新已下载并校验。安装会关闭并重新打开游戏，本地牌组和录像会保留。" if Manifest.platform_key() != "android" else "更新已下载并校验。点击安装后，请确认 Android 系统安装提示。")


func _poll_install() -> void:
	if _install.get("android", false):
		_handle_android_status(_read_android_status())
		if _state == "installing" and Time.get_ticks_msec() - _install_started_ms > 120000:
			_cancel_android_install()
			_issue = "install_timeout"
			_set_state("ready", "准备安装超时，已停止本次安装。请重试，或重新下载更新包。")
		return
	var session := str(_install.get("session", ""))
	if FileAccess.file_exists(session.path_join("failed.txt")):
		_set_state("ready", "安装未能完成，当前版本仍可使用。请检查目录权限和磁盘空间后重试，或去网页下载。")
	elif FileAccess.file_exists(session.path_join("prepared")):
		if _on_home_screen():
			# Preparation is not authority to mutate. Only this final handshake is.
			var permission := FileAccess.open(session.path_join("proceed"), FileAccess.WRITE)
			if permission != null:
				permission.close()
				get_tree().quit()
			else:
				_cancel_install_preparation("无法确认安装，请检查磁盘空间后重试。")
		else:
			_cancel_install_preparation("请回到首页后安装更新。")
	elif Time.get_ticks_msec() - _install_started_ms > 120000:
		_cancel_install_preparation("准备安装超时，当前版本仍可使用。请稍后重试。")


func _handle_android_status(status: String) -> void:
	if status == "preparing" and _state == "permission_required":
		_install_started_ms = Time.get_ticks_msec()
		_set_state("installing", "已获得权限，正在准备安装，请稍候。")
	elif status == "permission_required" and _state != "permission_required":
		_set_state("permission_required", "请在系统页面允许此游戏安装更新，然后返回游戏；也可以取消安装继续游戏。")
	elif status in ["awaiting_user", "awaiting_foreground", "awaiting_external"]:
		var message := "请返回游戏，随后会打开 Android 系统安装确认页。" if status == "awaiting_foreground" else "请确认 Android 系统安装提示。安装完成前请保留当前游戏，无需卸载。"
		if _state != "awaiting_install" or _message != message:
			_set_state("awaiting_install", message)
	elif status in ["cancelled", "cancelled_restart", "permission_denied", "external_cancelled"]:
		_issue = status
		var message := "本次安装已取消，当前版本仍可使用。可以再次安装。"
		if status == "permission_denied":
			message = "尚未获得安装权限。点击安装后，允许此来源安装应用；也可继续使用当前版本。"
		elif status == "cancelled_restart":
			message = "游戏重启中断了上次安装。更新包已保留，可使用系统安装器重试。"
		elif status == "external_cancelled":
			message = "系统安装页已关闭，更新尚未完成。安装包已保留，可再次使用系统安装器；无需卸载游戏。"
		_set_state("ready", message)
	elif status.begins_with("failed"):
		_issue = status
		var messages := {
			"failed_file_missing": "更新文件已丢失或无法读取，请重新下载。",
			"failed_integrity": "更新文件已损坏，请重新下载。",
			"failed_package_invalid": "下载的文件不是可安装的 Android 安装包，已阻止安装。请重新下载或使用官网入口。",
			"failed_identity": "安装包不属于当前游戏，已阻止安装。请重新下载或使用官网入口。",
			"failed_signer": "安装包签名与当前游戏不一致，不能覆盖安装。请使用官网入口；无需卸载当前游戏。",
			"failed_version": "安装包版本不符合本次更新，已阻止安装。请重新检查更新。",
			"failed_4": "Android 无法解析这个安装包，请重新下载或使用官网入口。",
			"failed_5": "安装包与当前应用冲突，请使用官网入口；无需卸载当前游戏。",
			"failed_7": "安装包与此设备不兼容，请使用官网入口选择适合的版本。",
		}
		if messages.has(status):
			_verify_path = _package_path()
			_reject_package(messages[status])
		else:
			var message := "系统未能完成安装，可以重试、重新下载更新包或使用官网入口。当前游戏仍可使用。"
			if status == "failed_3":
				message = "安装被系统中止，可能是确认页关闭或系统拦截。更新包已保留，可点击“使用系统安装器”重试；无需重新下载或卸载游戏。"
			elif status in ["failed_confirmation", "failed_install", "failed_external"]:
				message = "未能完成系统安装流程。更新包已保留，可点击“使用系统安装器”重试，或前往官网下载。"
			elif status == "failed_verification":
				message = "安装未通过 Android 系统安全校验。请查看系统提示，确认使用官网安装包；当前游戏和本地数据仍保留。"
			elif status in ["failed_storage", "failed_6"]:
				message = "安装所需空间不足。请清理存储空间后再次安装，已下载的文件会保留。"
			elif status in ["failed_permission_settings", "failed_2"]:
				message = "系统阻止了安装。请检查“允许此来源安装应用”或设备管理限制，再重试。"
			_set_state("ready", message)
	elif status == "success":
		_set_state("updated", "更新已安装，请重新打开游戏。")


func _cancel_install_preparation(message: String) -> void:
	var session := str(_install.get("session", ""))
	if not session.is_empty():
		var marker := FileAccess.open(session.path_join("cancelled"), FileAccess.WRITE)
		if marker != null:
			marker.close()
	_set_state("ready", message)


func confirm_healthy_startup() -> void:
	# Called only once the real home scene is ready, not by autoload startup.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ptcg-update-rollback="):
			_set_state("ready", "新版未能正常启动，已恢复上一版本。你可以稍后重试或去网页下载。")
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
	return _parse_artifact(value) if value is Dictionary else {}


func _parse_artifact(value: Dictionary) -> Dictionary:
	return Manifest.validate_artifact(value, Manifest.platform_key(), Manifest.architecture())


func _on_home_screen() -> bool:
	return is_inside_tree() and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://scenes/main_menu/MainMenu.tscn"


func _package_path() -> String:
	return ROOT.path_join(_download_key() + (".apk" if _artifact.get("format") == "android_apk" else ".zip"))


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
	var imported_path := ROOT.path_join(_system_download_key + ".apk")
	if (_verify_path == _package_path() or (_system_download_key.length() == 64 and _verify_path == imported_path)) and FileAccess.file_exists(_verify_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_verify_path))
	_fail(message)


func _fail(message: String) -> void:
	if _uses_system_download():
		_cancel_system_download()
	_system_transfer = false
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
	if _is_editor_runtime():
		return
	var file := FileAccess.open(STATE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_info))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(STATE_PATH + ".tmp"), ProjectSettings.globalize_path(STATE_PATH))


func _restore_pending() -> void:
	# Source runs share user:// with exported games but cannot replace the editor
	# executable. Leave the installed client's pending package untouched.
	if _is_editor_runtime():
		return
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 256 * 1024:
		return
	var saved: Variant = JSON.parse_string(file.get_as_text())
	# Windows will not delete this file while FileAccess still owns its handle.
	file.close()
	if not saved is Dictionary:
		return
	_info = saved
	var candidate: Variant = _info.get("artifact", {})
	_artifact = _parse_artifact(candidate) if candidate is Dictionary else {}
	_system_download_key = _download_key()
	_info["artifact"] = _artifact.duplicate(true)
	if not Manifest.valid_version(_info.get("latest_version", "")):
		return
	if Manifest.compare_versions(str(_info.latest_version), Version.current_version()) <= 0:
		_cancel_system_download()
		if not _artifact.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_package_path()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
		_info = {}
		_artifact = {}
		_set_state("idle", "")
	elif _artifact.is_empty():
		return
	elif _restore_system_download():
		return
	elif not _is_fixed_download() and FileAccess.file_exists(_package_path()):
		_begin_verify(_package_path())
	else:
		_remove_partial()
		_set_state("cancelled", "上次下载未完成，可重新下载。未完成的文件不会用于安装。")


func _restore_system_download() -> bool:
	if not _uses_system_download():
		return false
	var data := _system_download_status()
	if data.get("state") == "missing":
		return false
	_system_transfer = true
	_sample_ms = Time.get_ticks_msec()
	_apply_system_download(data)
	return true


func register_dialog(dialog: Control) -> void:
	_open_dialogs.append(weakref(dialog))


func has_open_dialog() -> bool:
	_open_dialogs = _open_dialogs.filter(func(ref: WeakRef) -> bool: return ref.get_ref() != null and not ref.get_ref().is_queued_for_deletion())
	return not _open_dialogs.is_empty()


func activate_update_entry() -> void:
	if not _on_home_screen():
		return
	# A ready entry is itself the player's install action. Keep the same rehash,
	# home-screen and platform gates used by the dialog's install button.
	if _state == "ready":
		install_ready_update()
	show_progress_dialog()


func show_progress_dialog() -> void:
	if not _on_home_screen() or has_open_dialog() or _info.is_empty():
		return
	var home := get_tree().current_scene
	if home.has_method("_show_update_dialog"):
		home.call("_show_update_dialog", _info)
		return
	var dialog := preload("res://scripts/update/AppUpdateDialog.gd").new()
	home.add_child(dialog)
	dialog.configure(self, _info)


func _exit_tree() -> void:
	_cancel_request()
	_hash_file = null
