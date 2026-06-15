@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	var export_plugin_script := load("res://addons/web_release_post_export/web_release_export_plugin.gd")
	_export_plugin = export_plugin_script.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin == null:
		return
	remove_export_plugin(_export_plugin)
	_export_plugin = null
