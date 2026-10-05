extends RefCounted
const Manifest := preload("res://scripts/card_content/ContentManifest.gd")

var root: String
var _trust: Dictionary
var _version: String
var _platform: String
var _current := {}

func _init(directory: String = "user://card_content", trust: Dictionary = {}, version: String = "", platform: String = "") -> void:
	root = directory
	_trust = trust.duplicate(true)
	_version = version
	_platform = platform
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join("objects")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join("releases")))

func object_path(hash: String, is_pack: bool = true) -> String:
	return root.path_join("objects").path_join(hash + (".zip" if is_pack else ".img"))

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func write_json(path: String, value: Dictionary) -> Error:
	return atomic_write(path, JSON.stringify(value).to_utf8_buffer())

func atomic_write(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

func put_object(object: Dictionary, bytes: PackedByteArray, is_pack: bool = true) -> Error:
	if not Manifest.descriptor({"sha256": object.get("sha256"), "size": object.get("size")}): return ERR_INVALID_DATA
	if bytes.size() != int(object.size) or Manifest.hash_bytes(bytes) != object.sha256: return ERR_FILE_CORRUPT
	var destination := object_path(object.sha256, is_pack)
	var error := atomic_write(destination + ".candidate", bytes)
	if error != OK: return error
	if is_pack and not Manifest.verify_pack(destination + ".candidate", object):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination + ".candidate"))
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(destination + ".candidate"), ProjectSettings.globalize_path(destination))

func missing_packs(manifest: Dictionary) -> Array:
	var missing := []
	for pack: Dictionary in manifest.get("packs", []):
		if not Manifest.verify_pack(object_path(pack.sha256), pack): missing.append(pack.duplicate(true))
	return missing

func assess(envelope: Dictionary) -> Dictionary:
	var checked := Manifest.verify(envelope, _trust, _version, _platform)
	if not checked.ok: return checked
	var state := read_json(root.path_join("state.json"))
	if checked.release_id == state.get("failed", ""): return Manifest.failure("candidate_previously_failed")
	if int(checked.manifest.sequence) <= int(state.get("sequence", 0)) and checked.release_id != state.get("active", ""):
		return Manifest.failure("release_sequence_rejected")
	return checked

func stage(envelope: Dictionary) -> Dictionary:
	var checked := assess(envelope)
	if not checked.ok: return checked
	if not missing_packs(checked.manifest).is_empty(): return Manifest.failure("snapshot_incomplete")
	if write_json(root.path_join("releases/%s.json" % checked.release_id), envelope) != OK: return Manifest.failure("storage_failed")
	if write_json(root.path_join("pending.json"), {"release_id": checked.release_id}) != OK: return Manifest.failure("storage_failed")
	return checked

func _release(id: String) -> Dictionary:
	if not Manifest.matches("^[0-9a-f]{64}$", id): return Manifest.failure("release_missing")
	var checked := Manifest.verify(read_json(root.path_join("releases/%s.json" % id)), _trust, _version, _platform)
	if not checked.ok: return checked
	if checked.release_id != id or not missing_packs(checked.manifest).is_empty(): return Manifest.failure("snapshot_incomplete")
	return checked

func prepare_boot() -> Dictionary:
	var state := read_json(root.path_join("state.json"))
	var trial := read_json(root.path_join("trial.json"))
	if not trial.is_empty():
		state.active = trial.get("previous", "")
		state.failed = trial.get("candidate", "")
		if write_json(root.path_join("state.json"), state) != OK: return Manifest.failure("storage_failed")
		_remove("trial.json")
		_remove("pending.json")
	var pending := read_json(root.path_join("pending.json"))
	if not pending.is_empty():
		var candidate := _release(str(pending.get("release_id", "")))
		if candidate.get("ok", false) and candidate.release_id != state.get("failed", "") and int(candidate.manifest.sequence) > int(state.get("sequence", 0)):
			var previous := str(state.get("active", ""))
			if write_json(root.path_join("trial.json"), {"previous": previous, "candidate": candidate.release_id}) != OK: return Manifest.failure("storage_failed")
			state.previous = previous
			state.active = candidate.release_id
			state.sequence = int(candidate.manifest.sequence)
			if write_json(root.path_join("state.json"), state) != OK: return Manifest.failure("storage_failed")
		_remove("pending.json")
	var active := str(state.get("active", ""))
	if active != "":
		var checked := _release(active)
		if checked.get("ok", false):
			_current = checked
			return checked.duplicate(true)
		# Corruption of a healthy snapshot falls back before any pack is mounted.
		state.failed = active
		var previous := _release(str(state.get("previous", "")))
		state.active = previous.get("release_id", "") if previous.get("ok", false) else ""
		if write_json(root.path_join("state.json"), state) != OK: return Manifest.failure("storage_failed")
		_remove("trial.json")
		if previous.get("ok", false):
			_current = previous
			return previous.duplicate(true)
	_current = {}
	return {"ok": true, "release_id": "", "manifest": {}}

func confirm_boot() -> void:
	_remove("trial.json")

func current() -> Dictionary:
	return _current.duplicate(true)

func _remove(name: String) -> void:
	var path := ProjectSettings.globalize_path(root.path_join(name))
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
