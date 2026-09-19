@tool
extends EditorPlugin

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidUpdaterExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidUpdaterExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "PtcgAppUpdater"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/app_updater/PtcgAppUpdater.aar"])
