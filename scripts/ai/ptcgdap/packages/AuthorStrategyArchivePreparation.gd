extends RefCounted

const Loader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const Reader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageSourceReader.gd")

## Worker boundary: files/bytes and a private loader only. No SceneTree,
## CardDatabase, policy compilation, match objects or public decision windows.
static func capture(path: String, expected_sha: String, control_distributed: bool) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": "package_file_missing"}
	var read := Reader.read_stream(file)
	file.close()
	if not bool(read.get("ok", false)):
		return read
	var bytes: PackedByteArray = read.get("archive_bytes", PackedByteArray())
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if bytes.is_empty():
		return {"ok": false, "error_code": "package_integrity_invalid"}
	hash.update(bytes)
	if hash.finish().hex_encode().to_upper() != expected_sha:
		return {"ok": false, "error_code": "package_integrity_invalid"}
	var loader := Loader.new()
	loader.prewarm_archive(bytes, not control_distributed)
	return {"ok": true, "path": path, "archive_bytes": bytes, "loader": loader}
