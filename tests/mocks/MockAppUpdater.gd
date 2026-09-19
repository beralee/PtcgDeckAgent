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

func _create_request() -> Node:
	var request := DownloadRequest.new()
	requests.append(request)
	return request

func _package_path() -> String:
	return "user://app_updates/updater-test.zip"

func _save_pending() -> void:
	pending = _info.duplicate(true)

func _restore_pending() -> void:
	pass

func _on_home_screen() -> bool:
	return false
