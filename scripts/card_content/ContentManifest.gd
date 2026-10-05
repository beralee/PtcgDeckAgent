extends RefCounted
## Bootstrap-only dependency: never preload a game class from this module.

const ABI := "godot-4.6-card-content-1"
const MAX_OBJECT := 64 * 1024 * 1024
const MAX_EXPANDED := 128 * 1024 * 1024
const MAX_MANIFEST := 8 * 1024 * 1024

static func hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func matches(pattern: String, value: Variant) -> bool:
	if not value is String: return false
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: String in expected:
		if not value.has(key): return false
	return true

static func descriptor(value: Variant) -> bool:
	return keys(value, ["sha256", "size"]) and matches("^[0-9a-f]{64}$", value.sha256) and integer(value.size, 1, MAX_OBJECT)

static func allowed_path(path: String) -> bool:
	if path.length() > 240 or not matches("^[A-Za-z0-9_./-]+$", path): return false
	for part: String in path.split("/"):
		if part in ["", ".", ".."]: return false
	for prefix: String in ["scripts/effects/", "scripts/engine/", "scripts/data/", "scripts/ai/ptcgdap/"]:
		if path.begins_with(prefix): return path.ends_with(".gd") or path.ends_with(".gd.remap")
	for prefix: String in ["data/bundled_user/cards/", "data/card_catalog/"]:
		if path.begins_with(prefix): return path.ends_with(".json")
	if path.begins_with("contracts/ptcgdap/") and path.ends_with(".json"):
		for rejected: String in ["trust", "signing", "private", "secret"]:
			if path.to_lower().contains(rejected): return false
		return true
	return false

static func validate(manifest: Variant) -> String:
	if not keys(manifest, ["schema_version", "sequence", "content_version", "runtime_abi", "min_client_version", "platforms", "notes", "packs", "cards"]): return "manifest_fields_invalid"
	if not integer(manifest.schema_version, 1, 1) or not integer(manifest.sequence, 1, 9007199254740991): return "manifest_version_invalid"
	if not manifest.content_version is String or manifest.content_version.is_empty() or manifest.content_version.length() > 80: return "manifest_version_invalid"
	if manifest.runtime_abi != ABI: return "runtime_incompatible"
	if not matches("^[0-9]+\\.[0-9]+\\.[0-9]+$", manifest.min_client_version): return "client_version_invalid"
	if not manifest.platforms is Array or manifest.platforms.is_empty(): return "platform_invalid"
	var platforms := {}
	for platform: Variant in manifest.platforms:
		if platform not in ["windows", "android", "linux", "macos", "web"] or platforms.has(platform): return "platform_invalid"
		platforms[platform] = true
	if not manifest.notes is String or manifest.notes.length() > 4000: return "notes_invalid"
	if not manifest.packs is Array or manifest.packs.is_empty() or manifest.packs.size() > 32: return "packs_invalid"
	var paths := {}
	var seen := {}
	var expanded := 0
	for pack: Variant in manifest.packs:
		if not keys(pack, ["sha256", "size", "files"]) or not descriptor({"sha256": pack.get("sha256"), "size": pack.get("size")}): return "pack_invalid"
		if seen.has(pack.sha256): return "pack_duplicate"
		seen[pack.sha256] = true
		if not pack.files is Dictionary or pack.files.is_empty() or pack.files.size() > 20000: return "pack_members_invalid"
		for path: String in pack.files:
			var entry: Variant = pack.files[path]
			if not allowed_path(path) or not descriptor(entry): return "pack_path_rejected"
			if paths.has(path.to_lower()): return "pack_path_collision"
			paths[path.to_lower()] = entry
			expanded += int(entry.size)
	if expanded > MAX_EXPANDED: return "release_too_large"
	if not manifest.cards is Dictionary or manifest.cards.is_empty() or manifest.cards.size() > 30000: return "cards_invalid"
	for uid: String in manifest.cards:
		var entry: Variant = manifest.cards[uid]
		if not matches("^[A-Za-z0-9][A-Za-z0-9_.-]*_[A-Za-z0-9][A-Za-z0-9.-]*$", uid) or not keys(entry, ["source_sha256", "image"]): return "card_invalid"
		var path := ("data/bundled_user/cards/%s.json" % uid).to_lower()
		if not paths.has(path) or paths[path].sha256 != entry.source_sha256: return "card_source_missing"
		if entry.image != null and not descriptor(entry.image): return "image_invalid"
	return ""

static func version_at_least(current: String, minimum: String) -> bool:
	var left := current.split(".")
	var right := minimum.split(".")
	if left.size() < 3 or right.size() != 3: return false
	for index in range(3):
		if int(left[index]) != int(right[index]): return int(left[index]) > int(right[index])
	return true

static func verify(envelope: Variant, trust: Dictionary, client_version: String, platform: String) -> Dictionary:
	if not keys(envelope, ["schema_version", "key_id", "payload", "signature"]): return failure("envelope_invalid")
	if not integer(envelope.schema_version, 1, 1) or not envelope.key_id is String or not trust.has(envelope.key_id): return failure("signature_untrusted")
	if not envelope.payload is String or envelope.payload.length() > MAX_MANIFEST * 2 or not envelope.signature is String or envelope.signature.length() > 2048: return failure("envelope_invalid")
	var payload := Marshalls.base64_to_raw(envelope.payload)
	var signature := Marshalls.base64_to_raw(envelope.signature)
	if payload.is_empty() or payload.size() > MAX_MANIFEST or Marshalls.raw_to_base64(payload) != envelope.payload: return failure("envelope_invalid")
	var key := CryptoKey.new()
	if key.load_from_string(str(trust[envelope.key_id]), true) != OK: return failure("signature_untrusted")
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(payload)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, hash_context.finish(), signature, key): return failure("signature_invalid")
	var manifest: Variant = JSON.parse_string(payload.get_string_from_utf8())
	var error := validate(manifest)
	if error != "": return failure(error)
	if platform not in manifest.platforms or not version_at_least(client_version, manifest.min_client_version): return failure("client_update_required")
	return {"ok": true, "manifest": manifest, "release_id": hash_bytes(payload)}

static func verify_pack(path: String, pack: Dictionary) -> bool:
	if not object_valid(path, pack): return false
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return false
	var names := archive.get_files()
	var seen := {}
	var valid: bool = names.size() == pack.files.size()
	for name: String in names:
		if not valid: break
		if not allowed_path(name) or not pack.files.has(name) or seen.has(name.to_lower()):
			valid = false
			break
		seen[name.to_lower()] = true
		var bytes := archive.read_file(name)
		var entry: Dictionary = pack.files[name]
		valid = bytes.size() == int(entry.size) and hash_bytes(bytes) == entry.sha256
		if name.ends_with(".gd.remap"):
			var source := name.trim_suffix(".remap")
			valid = valid and pack.files.has(source) and bytes.get_string_from_utf8() == '[remap]\n\npath="res://%s"\n' % source
	archive.close()
	return valid

static func object_valid(path: String, object: Dictionary) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(object.get("size", -1)): return false
	file.close()
	return FileAccess.get_sha256(path) == object.get("sha256", "")

static func failure(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}
