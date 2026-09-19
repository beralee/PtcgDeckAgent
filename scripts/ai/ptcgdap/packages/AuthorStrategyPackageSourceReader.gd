class_name AuthorStrategyPackageSourceReader
extends RefCounted

const MAX_ARCHIVE_BYTES := 16 * 1024 * 1024
const READ_CHUNK_BYTES := 64 * 1024


static func classify_source(source: String, platform: String = OS.get_name()) -> Dictionary:
	# Android document IDs are opaque. They need not contain a display filename,
	# and must never be decoded, globalized, logged, or retained after capture.
	if source.begins_with("content://"):
		if platform != "Android" or source.length() <= "content://".length():
			return _error("package_archive_invalid")
		return {"ok": true, "kind": "document_uri", "source": source}
	var path := source.strip_edges()
	if path.is_empty() or path.get_extension().to_lower() != "ptcgai":
		return _error("package_archive_invalid")
	return {"ok": true, "kind": "file", "source": path}


static func read_source(source: String, canceled: Callable = Callable()) -> Dictionary:
	if _is_canceled(canceled):
		return _error("package_import_canceled")
	var classified := classify_source(source)
	if not bool(classified.get("ok", false)):
		return classified
	var location := str(classified.get("source", ""))
	if classified.get("kind") == "file":
		var parent := DirAccess.open(location.get_base_dir())
		if not FileAccess.file_exists(location) or (parent != null and parent.is_link(location.get_file())):
			return _error("package_file_missing")
	# Godot's Android FileAccess handles content:// through the granted content
	# resolver. file_exists/DirAccess and extension checks apply only to paths.
	var stream := FileAccess.open(location, FileAccess.READ)
	if stream == null:
		return _error("package_file_missing")
	var result := read_stream(stream, canceled)
	stream.close()
	return result


static func read_stream(stream: Variant, canceled: Callable = Callable()) -> Dictionary:
	if _is_canceled(canceled):
		return _error("package_import_canceled")
	var declared_length := int(stream.get_length())
	if declared_length > MAX_ARCHIVE_BYTES:
		return _error("package_resource_limit_exceeded")
	var captured := PackedByteArray()
	while true:
		if _is_canceled(canceled):
			return _error("package_import_canceled")
		# At the limit, read only one additional byte to distinguish EOF from an
		# oversized provider stream, without ever allocating an unbounded buffer.
		var requested := mini(READ_CHUNK_BYTES, MAX_ARCHIVE_BYTES + 1 - captured.size())
		var chunk: PackedByteArray = stream.get_buffer(requested)
		var read_error := int(stream.get_error())
		if read_error != OK and read_error != ERR_FILE_EOF:
			return _error("package_file_read_failed")
		if captured.size() + chunk.size() > MAX_ARCHIVE_BYTES:
			return _error("package_resource_limit_exceeded")
		captured.append_array(chunk)
		if stream.eof_reached() or read_error == ERR_FILE_EOF:
			break
		if chunk.is_empty():
			return _error("package_file_read_failed")
	if _is_canceled(canceled):
		return _error("package_import_canceled")
	if declared_length > 0 and declared_length != captured.size():
		return _error("package_file_read_failed")
	if captured.is_empty():
		return _error("package_archive_invalid")
	return {"ok": true, "error_code": "", "archive_bytes": captured}


static func _is_canceled(canceled: Callable) -> bool:
	return canceled.is_valid() and bool(canceled.call())


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}
