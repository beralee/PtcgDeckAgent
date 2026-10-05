extends "res://scripts/update/AppUpdater.gd"

class DownloadRequest extends Node:
	signal request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray)
	var download_file := ""
	var timeout := 0.0
	var cancelled := false
	var downloaded := 0
	var calls := 0
	func request(_url: String, _headers: PackedStringArray) -> int:
		calls += 1
		return OK
	func cancel_request() -> void:
		cancelled = true
	func get_downloaded_bytes() -> int:
		return downloaded
	func complete(bytes: PackedByteArray, result: int = HTTPRequest.RESULT_SUCCESS, code: int = 200) -> void:
		var file := FileAccess.open(download_file, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		request_completed.emit(result, code, PackedStringArray(), PackedByteArray())

var requests: Array[Node] = []
var pending: Dictionary = {}
var native_status := "preparing"
var cancelled_installs := 0
var available_bytes := -1
var system_download := false
var system_status := {"state": "running", "downloaded": 0}
var system_starts := 0
var system_cancels := 0
var android_fixture := false

func _is_editor_runtime() -> bool:
	return false

func _parse_artifact(value: Dictionary) -> Dictionary:
	return Manifest.validate_artifact(value, "android", "arm64") if android_fixture else super._parse_artifact(value)

func _notifications_enabled() -> bool:
	return true

func _uses_system_download() -> bool:
	return system_download

func _start_system_download() -> Dictionary:
	system_starts += 1
	return system_status

func _system_download_status() -> Dictionary:
	return system_status

func _cancel_system_download() -> void:
	system_cancels += 1

func _create_request() -> Node:
	var request := DownloadRequest.new()
	requests.append(request)
	return request

func _package_path() -> String:
	return super._package_path() if android_fixture else "user://app_updates/updater-test.zip"

func _save_pending() -> void:
	pending = _info.duplicate(true)

func _restore_pending() -> void:
	pass

func _on_home_screen() -> bool:
	return false

func _read_android_status() -> String:
	return native_status

func _cancel_android_install() -> void:
	cancelled_installs += 1

func _available_space() -> int:
	return available_bytes
