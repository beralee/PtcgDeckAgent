class_name UpdateChecker
extends Node

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")

const MANIFEST_URL := "https://ptcg.skillserver.cn/dist/updates/latest.json"
const DEFAULT_DOWNLOAD_PAGE_URL := "https://ptcg.skillserver.cn/"
const STATE_PATH := "user://update_check_state.json"
const CHECK_INTERVAL_SECONDS := 24 * 60 * 60

signal update_available(info: Dictionary)
signal no_update(info: Dictionary)
signal check_failed(message: String)

var _http_request: HTTPRequest = null
var _is_checking := false
var _force_current_check := false


func check_for_updates(force: bool = false) -> int:
	if _is_checking:
		return ERR_BUSY

	var state := _load_state()
	if not force:
		var cached_info := _cached_update_info(state)
		if not _should_check_now(state):
			if is_update_available(cached_info) and not _is_version_ignored(cached_info, state):
				update_available.emit(cached_info)
			else:
				no_update.emit(cached_info)
			return OK

	_ensure_http_request()
	if _http_request == null:
		check_failed.emit("无法创建更新检查请求")
		return ERR_CANT_CREATE

	_is_checking = true
	_force_current_check = force
	var err := _http_request.request(
		MANIFEST_URL,
		PackedStringArray(["User-Agent: PTCGDeckAgent/%s" % AppVersionScript.VERSION]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_is_checking = false
		_force_current_check = false
		_record_check_attempt()
		check_failed.emit("更新检查启动失败：%d" % err)
	return err


func ignore_version(version: String) -> void:
	var clean_version := _normalize_version_string(version)
	if clean_version == "":
		return
	var state := _load_state()
	state["ignored_version"] = clean_version
	_save_state(state)


func is_update_available(info: Dictionary, current_version: String = "") -> bool:
	if current_version == "":
		current_version = AppVersionScript.VERSION
	var latest_version := str(info.get("latest_version", ""))
	if latest_version == "":
		return false
	return compare_versions(latest_version, current_version) > 0


func compare_versions(left: String, right: String) -> int:
	var left_parts := _parse_version_parts(left)
	var right_parts := _parse_version_parts(right)
	var count := maxi(left_parts.size(), right_parts.size())
	for index: int in count:
		var left_value := int(left_parts[index]) if index < left_parts.size() else 0
		var right_value := int(right_parts[index]) if index < right_parts.size() else 0
		if left_value > right_value:
			return 1
		if left_value < right_value:
			return -1
	return 0


func normalize_manifest(data: Dictionary) -> Dictionary:
	var latest_version := _normalize_version_string(str(data.get("latest_version", data.get("version", ""))))
	if latest_version == "":
		return {}

	var info := {
		"schema_version": int(data.get("schema_version", 1)),
		"latest_version": latest_version,
		"display_version": "v%s" % latest_version,
		"release_date": str(data.get("release_date", data.get("released_at", ""))),
		"title": str(data.get("title", "v%s 更新" % latest_version)),
		"summary": _normalize_summary(data.get("summary", [])),
		"download_page_url": str(data.get("download_page_url", DEFAULT_DOWNLOAD_PAGE_URL)),
		"manifest_url": MANIFEST_URL,
	}

	var platforms: Variant = data.get("platforms", {})
	if platforms is Dictionary:
		var platform_key := current_platform_key()
		var platform_data: Variant = (platforms as Dictionary).get(platform_key, {})
		if platform_data is Dictionary:
			var platform_page := str((platform_data as Dictionary).get("download_page_url", (platform_data as Dictionary).get("page_url", "")))
			if platform_page != "":
				info["download_page_url"] = platform_page

	return info


func current_platform_key() -> String:
	var os_name := OS.get_name()
	match os_name:
		"Windows":
			return "windows"
		"macOS", "OSX":
			return "macos"
		"Android":
			return "android"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux"
		_:
			return os_name.to_lower()


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return
	_http_request = HTTPRequest.new()
	_http_request.timeout = 8.0
	_http_request.use_threads = true
	_http_request.request_completed.connect(_on_manifest_response)
	add_child(_http_request)


func _on_manifest_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var force_check := _force_current_check
	_is_checking = false
	_force_current_check = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_record_check_attempt()
		check_failed.emit("更新检查失败：result=%d" % result)
		return
	if response_code < 200 or response_code >= 300:
		_record_check_attempt()
		check_failed.emit("更新检查失败：HTTP %d" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK or not (json.data is Dictionary):
		_record_check_attempt()
		check_failed.emit("更新信息解析失败")
		return

	var info := normalize_manifest(json.data as Dictionary)
	if info.is_empty():
		_record_check_attempt()
		check_failed.emit("更新信息缺少版本号")
		return

	var state := _load_state()
	state["last_checked_at"] = int(Time.get_unix_time_from_system())
	state["latest_info"] = info
	_save_state(state)

	if is_update_available(info) and (force_check or not _is_version_ignored(info, state)):
		update_available.emit(info)
	else:
		no_update.emit(info)


func _is_version_ignored(info: Dictionary, state: Dictionary) -> bool:
	var ignored_version := _normalize_version_string(str(state.get("ignored_version", "")))
	var latest_version := _normalize_version_string(str(info.get("latest_version", "")))
	return ignored_version != "" and ignored_version == latest_version


func _should_check_now(state: Dictionary) -> bool:
	var last_checked_at := int(state.get("last_checked_at", 0))
	if last_checked_at <= 0:
		return true
	var now := int(Time.get_unix_time_from_system())
	return now - last_checked_at >= CHECK_INTERVAL_SECONDS


func _cached_update_info(state: Dictionary) -> Dictionary:
	var latest_info: Variant = state.get("latest_info", {})
	return (latest_info as Dictionary).duplicate(true) if latest_info is Dictionary else {}


func _record_check_attempt() -> void:
	var state := _load_state()
	state["last_checked_at"] = int(Time.get_unix_time_from_system())
	_save_state(state)


func _load_state() -> Dictionary:
	if not FileAccess.file_exists(STATE_PATH):
		return {}
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return (json.data as Dictionary).duplicate(true)


func _save_state(state: Dictionary) -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()


func _normalize_summary(raw_summary: Variant) -> PackedStringArray:
	var summary := PackedStringArray()
	if raw_summary is Array:
		for item: Variant in raw_summary:
			var line := str(item).strip_edges()
			if line != "":
				summary.append(line)
	elif raw_summary is PackedStringArray:
		for item: String in raw_summary:
			var line := item.strip_edges()
			if line != "":
				summary.append(line)
	else:
		var text := str(raw_summary).strip_edges()
		if text != "":
			for line: String in text.split("\n"):
				line = line.strip_edges()
				if line != "":
					summary.append(line)
	return summary


func _normalize_version_string(version: String) -> String:
	var result := version.strip_edges()
	if result.begins_with("v") or result.begins_with("V"):
		result = result.substr(1)
	var plus_index := result.find("+")
	if plus_index >= 0:
		result = result.substr(0, plus_index)
	var dash_index := result.find("-")
	if dash_index >= 0:
		result = result.substr(0, dash_index)
	return result.strip_edges()


func _parse_version_parts(version: String) -> Array[int]:
	var normalized := _normalize_version_string(version)
	var parts: Array[int] = []
	for token: String in normalized.split("."):
		var digits := ""
		for index: int in token.length():
			var code := token.unicode_at(index)
			if code < 48 or code > 57:
				break
			digits += token.substr(index, 1)
		parts.append(int(digits) if digits != "" else 0)
	while parts.size() < 3:
		parts.append(0)
	return parts
