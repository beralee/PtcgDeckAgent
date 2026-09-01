class_name ReplayDiagnosticHash
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")


static func sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func sha256_text(text: String) -> String:
	return sha256_bytes(text.to_utf8_buffer())


static func file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return sha256_bytes(bytes)


static func canonical_record_hash(domain: String, value: Variant) -> String:
	# Records must round-trip through JSON. Godot parses JSON numbers as floats,
	# so use the CABT JSON canonicalizer (which renders integral floats exactly
	# like their integer source) rather than the integer-only artifact profile.
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes := PackedByteArray()
	bytes.append_array("PTCGDAP_REPLAY_DIAGNOSTIC".to_utf8_buffer())
	bytes.append(0)
	bytes.append_array(domain.to_utf8_buffer())
	bytes.append(0)
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	return sha256_bytes(bytes)


static func append_json_line(path: String, value: Dictionary) -> bool:
	return append_line(path, JSON.stringify(value))


static func append_line(path: String, line: String) -> bool:
	return append_lines(path, [line])


static func append_lines(path: String, lines: Array[String]) -> bool:
	if lines.is_empty():
		return true
	var global_path := ProjectSettings.globalize_path(path)
	var directory := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			return false
	if not FileAccess.file_exists(global_path):
		var created := FileAccess.open(path, FileAccess.WRITE)
		if created == null:
			return false
		created.close()
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return false
	file.seek_end()
	var payload := "\n".join(lines) + "\n"
	var stored := file.store_string(payload)
	file.flush()
	var accepted := stored and file.get_error() == OK
	file.close()
	return accepted


static func write_json(path: String, value: Dictionary) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var directory := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var accepted := stored and file.get_error() == OK
	file.close()
	return accepted


static func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func read_non_empty_lines(path: String) -> Array[String]:
	var lines: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return lines
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(line)
	file.close()
	return lines
