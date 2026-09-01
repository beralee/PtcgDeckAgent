class_name MatchRecordIndex
extends RefCounted

var _root: String = "user://match_records"
var _cache_loaded := false
var _cache_entries: Dictionary = {}
var _last_cache_hits := 0
var _last_cache_misses := 0

const CACHE_FILE_NAME := ".match_record_index_cache.json"
const CACHE_SCHEMA_VERSION := 2


func set_root(root_path: String) -> void:
	_root = root_path
	_cache_loaded = false
	_cache_entries.clear()


func audit_snapshot() -> Dictionary:
	return {
		"cache_hits": _last_cache_hits,
		"cache_misses": _last_cache_misses,
		"cache_entry_count": _cache_entries.size(),
		"cache_path": _cache_path(),
	}


func list_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	_load_cache()
	_last_cache_hits = 0
	_last_cache_misses = 0
	var next_cache: Dictionary = {}
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
		var match_dir := _root.path_join(entry)
		var match_path := match_dir.path_join("match.json")
		if not FileAccess.file_exists(match_path):
			continue
		var signature := _match_signature(match_path)
		var cached: Variant = _cache_entries.get(entry)
		var row: Dictionary = {}
		if cached is Dictionary and _same_signature((cached as Dictionary).get("signature"), signature):
			_last_cache_hits += 1
			var cached_row: Variant = (cached as Dictionary).get("row", {})
			if cached_row is Dictionary:
				row = (cached_row as Dictionary).duplicate(true)
		else:
			_last_cache_misses += 1
			row = _build_row(match_dir)
		var valid_row := not row.is_empty()
		if valid_row:
			row["match_dir"] = match_dir
			row["match_id"] = entry
		next_cache[entry] = {"signature": signature, "row": row.duplicate(true)}
		if not valid_row:
			continue
		rows.append(row)
	dir.list_dir_end()
	if next_cache != _cache_entries:
		_cache_entries = next_cache
		_persist_cache()
	rows.sort_custom(_sort_rows_newest_first)
	return rows


func _cache_path() -> String:
	return _root.path_join(CACHE_FILE_NAME)


func _load_cache() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	_cache_entries = {}
	var path := _cache_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	var root := parsed as Dictionary
	if int(root.get("schema_version", 0)) != CACHE_SCHEMA_VERSION or not (root.get("entries") is Dictionary):
		return
	_cache_entries = _coerce_integral_numbers(root.get("entries"))


func _persist_cache() -> void:
	var absolute_root := ProjectSettings.globalize_path(_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	var file := FileAccess.open(_cache_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"document_type": "match_record_index_cache_v1",
		"schema_version": CACHE_SCHEMA_VERSION,
		"entries": _cache_entries,
	}) + "\n")
	file.close()


func _match_signature(path: String) -> Dictionary:
	return {
		"modified_time": FileAccess.get_modified_time(path),
		"size": FileAccess.get_size(path),
	}


func _same_signature(a: Variant, b: Dictionary) -> bool:
	return (
		a is Dictionary
		and int((a as Dictionary).get("modified_time", -1)) == int(b.get("modified_time", -2))
		and int((a as Dictionary).get("size", -1)) == int(b.get("size", -2))
	)


func _coerce_integral_numbers(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		var array_result: Array = []
		for item: Variant in value:
			array_result.append(_coerce_integral_numbers(item))
		return array_result
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key: Variant in value:
			dictionary_result[key] = _coerce_integral_numbers(value[key])
		return dictionary_result
	return value


func _build_row(match_dir: String) -> Dictionary:
	var match_payload := _read_json(match_dir.path_join("match.json"))
	var meta_variant: Variant = match_payload.get("meta", {})
	var meta: Dictionary = meta_variant if meta_variant is Dictionary else {}
	var mode := str(meta.get("mode", ""))
	if mode not in ["two_player", "vs_ai", "vs_author_strategy_ai"]:
		return {}
	var result_variant: Variant = match_payload.get("result", {})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var match_id := match_dir.get_file()
	var match_time := _match_start_time(
		match_dir,
		match_id,
		FileAccess.get_modified_time(match_dir.path_join("match.json"))
	)
	var recorded_unix := int(match_time.get("unix_time", 0))
	return {
		"match_dir": match_dir,
		"match_id": match_id,
		"recorded_at": str(match_time.get("local_time", match_id)),
		"recorded_unix": recorded_unix,
		"started_at_utc": str(match_time.get("utc_time", "")),
		"recorded_at_source": str(match_time.get("source", "unknown")),
		"winner_index": int(result.get("winner_index", -1)),
		"mode": mode,
		"player_types": _string_array(meta.get("player_types", [])),
		"view_player_index": int(meta.get("view_player_index", 0)),
		"selected_deck_ids": _int_array(meta.get("selected_deck_ids", [])),
		"first_player_index": int(meta.get("first_player_index", -1)),
		"turn_count": int(result.get("turn_number", match_payload.get("turn_count", 0))),
		"player_labels": _string_array(meta.get("player_labels", [])),
		"final_prize_counts": _int_array(result.get("final_prize_counts", [])),
		"replay_entry_source": "unknown",
	}


func _match_start_time(
	match_dir: String,
	match_id: String,
	fallback_modified_unix: int
) -> Dictionary:
	var timestamp := _read_match_started_timestamp(match_dir.path_join("detail.jsonl"))
	var source := "detail_match_started"
	if timestamp.is_empty():
		timestamp = _timestamp_from_match_id(match_id)
		source = "match_id"
	if not timestamp.is_empty():
		var unix_time := _local_timestamp_to_unix(timestamp)
		if unix_time > 0:
			return {
				"local_time": timestamp,
				"unix_time": unix_time,
				"utc_time": "%sZ" % Time.get_datetime_string_from_unix_time(unix_time),
				"source": source,
			}
	return {
		"local_time": _local_datetime_from_unix(fallback_modified_unix, match_id),
		"unix_time": fallback_modified_unix,
		"utc_time": (
			"%sZ" % Time.get_datetime_string_from_unix_time(fallback_modified_unix)
			if fallback_modified_unix > 0 else ""
		),
		"source": "match_json_modified",
	}


func _read_match_started_timestamp(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var inspected := 0
	while not file.eof_reached() and inspected < 16:
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		inspected += 1
		var parsed: Variant = JSON.parse_string(line)
		if not parsed is Dictionary:
			continue
		if str((parsed as Dictionary).get("event_type", "")) != "match_started":
			continue
		var timestamp := str((parsed as Dictionary).get("timestamp", "")).strip_edges()
		file.close()
		return timestamp
	file.close()
	return ""


func _timestamp_from_match_id(match_id: String) -> String:
	var parts := match_id.split("_", false)
	if parts.size() < 3:
		return ""
	var date := str(parts[1])
	var time := str(parts[2])
	if date.length() != 8 or time.length() != 6 or not date.is_valid_int() or not time.is_valid_int():
		return ""
	return "%s-%s-%sT%s:%s:%s" % [
		date.substr(0, 4), date.substr(4, 2), date.substr(6, 2),
		time.substr(0, 2), time.substr(2, 2), time.substr(4, 2),
	]


func _local_timestamp_to_unix(timestamp: String) -> int:
	var naive_unix := int(Time.get_unix_time_from_datetime_string(timestamp))
	if naive_unix <= 0:
		return 0
	var timezone: Dictionary = Time.get_time_zone_from_system()
	return naive_unix - int(timezone.get("bias", 0)) * 60


func _local_datetime_from_unix(unix_time: int, fallback: String) -> String:
	if unix_time <= 0:
		return fallback
	var timezone: Dictionary = Time.get_time_zone_from_system()
	return Time.get_datetime_string_from_unix_time(
		unix_time + int(timezone.get("bias", 0)) * 60
	)


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
