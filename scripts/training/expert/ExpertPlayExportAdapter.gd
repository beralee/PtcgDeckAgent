extends Node

signal saved(path: String)
signal cancelled
signal failed(message: String)

const MAX_BYTES := 256 * 1024 * 1024
var _source := ""
var _dialog: FileDialog


func save_file(source: String, suggested_name: String) -> void:
	if not _source.is_empty():
		return
	_source = source
	var directory := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var error := DisplayServer.file_dialog_show(
			"保存多龙标注文件", directory, suggested_name, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
			PackedStringArray(["*.jsonl;专家示范文件;application/octet-stream"]),
			_on_native_selected
		)
		if error == OK:
			return
	if OS.has_feature("android") or OS.has_feature("ios"):
		_source = ""
		failed.emit("未能打开系统文件选择器，示范仍保存在本机，请稍后重试。")
		return
	_dialog = FileDialog.new()
	_dialog.title = "保存多龙标注文件"
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.filters = PackedStringArray(["*.jsonl ; 专家示范文件"])
	_dialog.current_dir = directory
	_dialog.current_file = suggested_name
	_dialog.file_selected.connect(_write_selected)
	_dialog.canceled.connect(_cancel)
	add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func _on_native_selected(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if not status or paths.is_empty():
		_cancel()
		return
	_write_selected(paths[0])


func _cancel() -> void:
	_clear()
	cancelled.emit()


func _clear() -> void:
	_source = ""
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _write_selected(path: String) -> void:
	# content:// is an opaque Android document URI. Never change its suffix.
	var result := copy_export(_source, path)
	_clear()
	if bool(result.ok):
		saved.emit(path)
	else:
		failed.emit("文件未能完整写入，请换一个位置重试；本机示范仍在。")


static func copy_export(source: String, destination: String) -> Dictionary:
	if source.is_empty() or destination.is_empty() or source == destination:
		return {"ok": false, "error": "expert_export_path_invalid"}
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null or input.get_length() <= 0 or input.get_length() > MAX_BYTES:
		return {"ok": false, "error": "expert_export_source_invalid"}
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		input.close()
		return {"ok": false, "error": "expert_export_destination_unwritable"}
	var remaining := input.get_length()
	var ok := true
	while remaining > 0:
		var count := mini(remaining, 128 * 1024)
		var chunk := input.get_buffer(count)
		if chunk.size() != count:
			ok = false
			break
		output.store_buffer(chunk)
		if output.get_error() != OK:
			ok = false
			break
		remaining -= count
	output.flush()
	ok = ok and remaining == 0 and output.get_error() == OK
	input.close()
	output.close()
	return {"ok": ok}
