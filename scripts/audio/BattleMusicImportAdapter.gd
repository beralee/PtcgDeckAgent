class_name BattleMusicImportAdapter
extends Node

signal track_imported(track_id: String, source_name: String)
signal import_failed(message: String)

const AUDIO_FILTER := "*.ogg,*.mp3,*.wav;Audio Files;audio/ogg,audio/mpeg,audio/wav"

var _file_dialog: FileDialog = null


func pick_music() -> void:
	if _open_native_file_dialog():
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		import_failed.emit("当前系统无法打开音乐选择器，请检查系统文件服务后重试。")
		return
	_open_desktop_file_dialog()


static func native_audio_filters_for_tests() -> PackedStringArray:
	return PackedStringArray([AUDIO_FILTER])


func selected_path_display_name_for_tests(path: String) -> String:
	return _selected_path_display_name(path)


func _open_native_file_dialog() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		return false
	var error := DisplayServer.file_dialog_show(
		"添加自定义音乐",
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		native_audio_filters_for_tests(),
		_on_native_file_dialog_selected
	)
	return error == OK


func _on_native_file_dialog_selected(
	status: bool,
	selected_paths: PackedStringArray,
	_selected_filter_index: int
) -> void:
	if not status or selected_paths.is_empty():
		return
	_import_selected_path(selected_paths[0])


func _open_desktop_file_dialog() -> void:
	_clear_file_dialog()
	_file_dialog = FileDialog.new()
	_file_dialog.name = "BattleMusicFileDialog"
	_file_dialog.title = "添加自定义音乐"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray([
		"*.ogg ; OGG",
		"*.mp3 ; MP3",
		"*.wav ; WAV",
	])
	_file_dialog.file_selected.connect(_on_desktop_file_selected)
	_file_dialog.canceled.connect(_clear_file_dialog)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(900, 640))


func _on_desktop_file_selected(path: String) -> void:
	_import_selected_path(path)
	_clear_file_dialog()


func _import_selected_path(path: String) -> void:
	var source_name := _selected_path_display_name(path)
	var result := BattleMusicManager.import_custom_track_from_path(path, source_name)
	if not bool(result.get("ok", false)):
		import_failed.emit(str(result.get("error", "无法添加所选音乐。")))
		return
	track_imported.emit(str(result.get("track_id", "")), source_name)


func _selected_path_display_name(path: String) -> String:
	var decoded_path := path.uri_decode().replace("\\", "/").trim_suffix("/")
	var file_name := decoded_path.get_file().strip_edges()
	if path.begins_with("content://") and _is_opaque_android_media_id(file_name):
		return _generated_import_name()
	if file_name != "":
		return file_name
	return path.get_file().uri_decode().strip_edges()


func _is_opaque_android_media_id(file_name: String) -> bool:
	var separator_index := file_name.rfind(":")
	if separator_index <= 0 or separator_index >= file_name.length() - 1:
		return false
	return file_name.substr(separator_index + 1).is_valid_int()


func _generated_import_name() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true)
	timestamp = timestamp.replace("-", "").replace(":", "").replace(" ", "-").replace("T", "-")
	return "导入音乐-%s" % timestamp


func _clear_file_dialog() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
	_file_dialog = null
