class_name TestExportPresets
extends TestBase

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const REQUIRED_BUNDLED_FILTER := "data/**"


func test_web_export_includes_bundled_user_data() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var web_block := _extract_preset_block(preset_text, "Web")
	var include_filter := _extract_string_value(web_block, "include_filter")

	return run_checks([
		assert_true(web_block != "", "Web export preset should exist"),
		assert_true(include_filter.split(",").has(REQUIRED_BUNDLED_FILTER), "Web export should include bundled data files such as card JSON and card image .bin files"),
	])


func _extract_preset_block(preset_text: String, preset_name: String) -> String:
	var current_block := PackedStringArray()
	var in_block := false
	var current_name := ""
	for raw_line: String in preset_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("[preset.") and line.ends_with("]"):
			if in_block and current_name == preset_name:
				return "\n".join(current_block)
			current_block = PackedStringArray([line])
			in_block = true
			current_name = ""
			continue
		if not in_block:
			continue
		current_block.append(line)
		if line.begins_with("name="):
			current_name = _unquote(line.substr("name=".length()))
	if in_block and current_name == preset_name:
		return "\n".join(current_block)
	return ""


func _extract_string_value(block: String, key: String) -> String:
	for raw_line: String in block.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("%s=" % key):
			return _unquote(line.substr(key.length() + 1))
	return ""


func _unquote(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed
