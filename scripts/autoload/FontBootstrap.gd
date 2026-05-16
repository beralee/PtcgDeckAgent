extends Node

const CJK_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"
const DEFAULT_FALLBACK_FONT_SIZE := 16
const CONTROL_FONT_KEYS := [
	"font",
	"normal_font",
	"bold_font",
	"italics_font",
	"bold_italics_font",
	"mono_font",
]

var _cjk_font: Font = null


func _enter_tree() -> void:
	_install_cjk_fallback_font()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_font_to_existing_controls")


func _install_cjk_fallback_font() -> void:
	var font := _load_cjk_font()
	if font == null:
		push_warning("CJK fallback font missing: %s" % CJK_FONT_PATH)
		return
	_cjk_font = font
	var project_theme := ThemeDB.get_project_theme()
	if project_theme != null:
		project_theme.set_default_font(_cjk_font)
		if not project_theme.has_default_font_size():
			project_theme.set_default_font_size(DEFAULT_FALLBACK_FONT_SIZE)
	ThemeDB.set_fallback_font(_cjk_font)
	if ThemeDB.get_fallback_font_size() <= 0:
		ThemeDB.set_fallback_font_size(DEFAULT_FALLBACK_FONT_SIZE)


func _load_cjk_font() -> Font:
	var imported := ResourceLoader.load(CJK_FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE) as Font
	if imported != null:
		return imported
	var font_file := FontFile.new()
	var error := font_file.load_dynamic_font(CJK_FONT_PATH)
	if error == OK:
		return font_file
	return null


func _on_node_added(node: Node) -> void:
	if node is Control:
		_apply_font_to_control.call_deferred(node)


func _apply_font_to_existing_controls() -> void:
	var root := get_tree().root
	if root == null:
		return
	_apply_font_to_tree(root)


func _apply_font_to_tree(node: Node) -> void:
	if node is Control:
		_apply_font_to_control(node)
	for child: Node in node.get_children():
		_apply_font_to_tree(child)


func _apply_font_to_control(control_obj: Variant) -> void:
	if _cjk_font == null or control_obj == null:
		return
	if not (control_obj is Object) or not is_instance_valid(control_obj):
		return
	if not (control_obj is Control):
		return
	var control := control_obj as Control
	for key: String in CONTROL_FONT_KEYS:
		control.add_theme_font_override(key, _cjk_font)
