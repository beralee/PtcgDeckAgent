class_name MatchRecordIndex
extends RefCounted

var _root: String = "user://match_records"


func set_root(root_path: String) -> void:
	_root = root_path


func list_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var absolute_root := ProjectSettings.globalize_path(_root)
	var dir := DirAccess.open(absolute_root)
	if dir == null:
		return rows

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with(".") or not dir.current_is_dir():
			continue
		var row := _build_row(_root.path_join(entry))
		if row.is_empty():
			continue
		rows.append(row)
	dir.list_dir_end()
	rows.sort_custom(_sort_rows_newest_first)
	return rows


func _build_row(match_dir: String) -> Dictionary:
	var match_payload := _read_json(match_dir.path_join("match.json"))
	var meta_variant: Variant = match_payload.get("meta", {})
	var meta: Dictionary = meta_variant if meta_variant is Dictionary else {}
	if str(meta.get("mode", "")) != "two_player":
		return {}
	var result_variant: Variant = match_payload.get("result", {})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var match_id := match_dir.get_file()
	var recorded_unix := FileAccess.get_modified_time(match_dir.path_join("match.json"))
	return {
		"match_dir": match_dir,
		"match_id": match_id,
		"recorded_at": _recorded_at(recorded_unix, match_id),
		"recorded_unix": recorded_unix,
		"winner_index": int(result.get("winner_index", -1)),
		"first_player_index": int(meta.get("first_player_index", -1)),
		"turn_count": int(result.get("turn_number", match_payload.get("turn_count", 0))),
		"player_labels": _string_array(meta.get("player_labels", [])),
		"final_prize_counts": _int_array(result.get("final_prize_counts", [])),
		"replay_entry_source": "unknown",
	}


func _recorded_at(modified_unix: int, fallback_match_id: String) -> String:
	if modified_unix <= 0:
		return fallback_match_id
	return Time.get_datetime_string_from_unix_time(modified_unix)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		result.append(str(item))
	return result


func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		result.append(int(item))
	return result


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _sort_rows_newest_first(a: Dictionary, b: Dictionary) -> bool:
	var a_unix := int(a.get("recorded_unix", 0))
	var b_unix := int(b.get("recorded_unix", 0))
	if a_unix != b_unix:
		return a_unix > b_unix
	return str(a.get("match_id", "")) < str(b.get("match_id", ""))
