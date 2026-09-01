extends RefCounted

## Raw-byte ZIP reader for the deterministic, stored-only .ptcgai profile.
## It never extracts to disk and validates local/central names before exposing
## member bytes, preserving path evidence that ZIPReader normalizes away.

const EOCD_SIGNATURE := 0x06054B50
const CENTRAL_SIGNATURE := 0x02014B50
const LOCAL_SIGNATURE := 0x04034B50
const FIXED_EXTERNAL_ATTR := 2175008768
const FIXED_DOS_DATE := 33
const MASK32 := 0xFFFFFFFF


static func read(archive_bytes: PackedByteArray, limits: Dictionary) -> Dictionary:
	if archive_bytes.is_empty():
		return _error("package_archive_invalid")
	if archive_bytes.size() > int(limits.get("max_archive_bytes", 0)):
		return _error("package_resource_limit_exceeded")
	var eocd_offset := _find_eocd(archive_bytes)
	if eocd_offset < 0 or eocd_offset + 22 != archive_bytes.size():
		return _error("package_archive_invalid")
	if _u32(archive_bytes, eocd_offset) != EOCD_SIGNATURE:
		return _error("package_archive_invalid")
	var disk_number := _u16(archive_bytes, eocd_offset + 4)
	var central_disk := _u16(archive_bytes, eocd_offset + 6)
	var disk_entries := _u16(archive_bytes, eocd_offset + 8)
	var total_entries := _u16(archive_bytes, eocd_offset + 10)
	var central_size := _u32(archive_bytes, eocd_offset + 12)
	var central_offset := _u32(archive_bytes, eocd_offset + 16)
	var comment_length := _u16(archive_bytes, eocd_offset + 20)
	if min(disk_number, central_disk, disk_entries, total_entries, central_size, central_offset, comment_length) < 0:
		return _error("package_archive_invalid")
	if disk_number != 0 or central_disk != 0 or disk_entries != total_entries or total_entries == 0xFFFF:
		return _error("package_archive_invalid")
	if central_size == MASK32 or central_offset == MASK32 or comment_length != 0:
		return _error("package_archive_invalid")
	if central_offset + central_size != eocd_offset:
		return _error("package_archive_invalid")
	if total_entries > int(limits.get("max_entry_count", 0)):
		return _error("package_resource_limit_exceeded")

	var cursor := central_offset
	var entries: Array[Dictionary] = []
	var names: Array[String] = []
	var folded := {}
	for _entry_index in range(total_entries):
		if cursor + 46 > eocd_offset or _u32(archive_bytes, cursor) != CENTRAL_SIGNATURE:
			return _error("package_archive_invalid")
		var name_length := _u16(archive_bytes, cursor + 28)
		var extra_length := _u16(archive_bytes, cursor + 30)
		var entry_comment_length := _u16(archive_bytes, cursor + 32)
		var disk_start := _u16(archive_bytes, cursor + 34)
		var internal_attr := _u16(archive_bytes, cursor + 36)
		var external_attr := _u32(archive_bytes, cursor + 38)
		var local_offset := _u32(archive_bytes, cursor + 42)
		if min(name_length, extra_length, entry_comment_length, disk_start, internal_attr, external_attr, local_offset) < 0:
			return _error("package_archive_invalid")
		var end := cursor + 46 + name_length + extra_length + entry_comment_length
		if end > eocd_offset or local_offset + 30 > central_offset:
			return _error("package_archive_invalid")
		var raw_name := archive_bytes.slice(cursor + 46, cursor + 46 + name_length)
		var decoded := _decode_ascii_path(raw_name, int(limits.get("max_path_bytes", 0)))
		if not bool(decoded.get("ok", false)):
			return decoded
		var name := str(decoded.get("path", ""))
		if names.has(name) or folded.has(name.to_lower()):
			return _error("package_duplicate_path")
		names.append(name)
		folded[name.to_lower()] = true
		entries.append({
			"name": name,
			"raw_name": raw_name,
			"version_made": _u16(archive_bytes, cursor + 4),
			"flags": _u16(archive_bytes, cursor + 8),
			"compression": _u16(archive_bytes, cursor + 10),
			"dos_time": _u16(archive_bytes, cursor + 12),
			"dos_date": _u16(archive_bytes, cursor + 14),
			"crc32": _u32(archive_bytes, cursor + 16),
			"compressed_size": _u32(archive_bytes, cursor + 20),
			"file_size": _u32(archive_bytes, cursor + 24),
			"extra_length": extra_length,
			"comment_length": entry_comment_length,
			"disk_start": disk_start,
			"internal_attr": internal_attr,
			"external_attr": external_attr,
			"local_offset": local_offset,
		})
		cursor = end
	if cursor != eocd_offset:
		return _error("package_archive_invalid")

	var total_uncompressed := 0
	for entry in entries:
		var file_size := int(entry.get("file_size", -1))
		var compressed_size := int(entry.get("compressed_size", -1))
		if file_size < 0 or compressed_size < 0:
			return _error("package_archive_invalid")
		if file_size > int(limits.get("max_single_file_bytes", 0)):
			return _error("package_resource_limit_exceeded")
		total_uncompressed += file_size
		if total_uncompressed > int(limits.get("max_uncompressed_bytes", 0)):
			return _error("package_resource_limit_exceeded")
		if file_size > int(limits.get("max_compression_ratio", 0)) * max(compressed_size, 1):
			return _error("package_resource_limit_exceeded")
	if names != _sorted_ascii(names):
		return _error("package_archive_invalid")

	var members := {}
	var ranges: Array[Array] = []
	for entry in entries:
		if (int(entry.get("version_made", 0)) >> 8) != 3:
			return _error("package_archive_invalid")
		if int(entry.get("flags", -1)) != 0 or int(entry.get("compression", -1)) != 0:
			return _error("package_archive_invalid")
		if int(entry.get("dos_time", -1)) != 0 or int(entry.get("dos_date", -1)) != FIXED_DOS_DATE:
			return _error("package_archive_invalid")
		if int(entry.get("extra_length", -1)) != 0 or int(entry.get("comment_length", -1)) != 0:
			return _error("package_archive_invalid")
		if int(entry.get("disk_start", -1)) != 0 or int(entry.get("internal_attr", -1)) != 0:
			return _error("package_archive_invalid")
		if int(entry.get("external_attr", -1)) != FIXED_EXTERNAL_ATTR or str(entry.get("name", "")).ends_with("/"):
			return _error("package_archive_invalid")
		var local := _read_local(archive_bytes, entry, central_offset)
		if not bool(local.get("ok", false)):
			return local
		var data: PackedByteArray = local.get("data", PackedByteArray())
		if _crc32(data) != int(entry.get("crc32", -1)):
			return _error("package_archive_invalid")
		members[str(entry.get("name", ""))] = data
		ranges.append([int(entry.get("local_offset", 0)), int(local.get("end", 0))])
	ranges.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var previous_end := 0
	for range_value in ranges:
		if int(range_value[0]) < previous_end:
			return _error("package_archive_invalid")
		previous_end = int(range_value[1])
	if previous_end > central_offset:
		return _error("package_archive_invalid")
	return {"ok": true, "error_code": "", "members": members, "entry_count": entries.size()}


static func _read_local(archive_bytes: PackedByteArray, entry: Dictionary, central_offset: int) -> Dictionary:
	var offset := int(entry.get("local_offset", -1))
	if offset < 0 or offset + 30 > central_offset or _u32(archive_bytes, offset) != LOCAL_SIGNATURE:
		return _error("package_archive_invalid")
	var name_length := _u16(archive_bytes, offset + 26)
	var extra_length := _u16(archive_bytes, offset + 28)
	if name_length < 0 or extra_length != 0:
		return _error("package_archive_invalid")
	var raw_name := archive_bytes.slice(offset + 30, offset + 30 + name_length)
	if raw_name != entry.get("raw_name"):
		return _error("package_archive_invalid")
	for pair in [
		[6, "flags", 2], [8, "compression", 2], [10, "dos_time", 2], [12, "dos_date", 2],
		[14, "crc32", 4], [18, "compressed_size", 4], [22, "file_size", 4],
	]:
		var actual := _u16(archive_bytes, offset + int(pair[0])) if int(pair[2]) == 2 else _u32(archive_bytes, offset + int(pair[0]))
		if actual != int(entry.get(str(pair[1]), -1)):
			return _error("package_archive_invalid")
	var data_offset := offset + 30 + name_length
	var data_end := data_offset + int(entry.get("compressed_size", -1))
	if data_offset < 0 or data_end > central_offset:
		return _error("package_archive_invalid")
	return {"ok": true, "error_code": "", "data": archive_bytes.slice(data_offset, data_end), "end": data_end}


static func _decode_ascii_path(raw_name: PackedByteArray, max_path_bytes: int) -> Dictionary:
	if raw_name.is_empty() or raw_name.size() > max_path_bytes:
		return _error("package_path_invalid")
	for value in raw_name:
		if value < 0x20 or value > 0x7E or value == 0x5C or value == 0:
			return _error("package_path_invalid")
	var path := raw_name.get_string_from_ascii()
	if path.begins_with("/") or path.ends_with("/") or path.contains("//"):
		return _error("package_path_invalid")
	var parts := path.split("/", true)
	if parts.is_empty() or str(parts[0]).contains(":"):
		return _error("package_path_invalid")
	for part_value in parts:
		var part := str(part_value)
		if part.is_empty() or part == "." or part == "..":
			return _error("package_path_invalid")
		for character in part:
			var code := character.unicode_at(0)
			var allowed := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in [".", "_", "-"]
			if not allowed:
				return _error("package_path_invalid")
	return {"ok": true, "error_code": "", "path": path}


static func _sorted_ascii(names: Array[String]) -> Array[String]:
	var result := names.duplicate()
	result.sort()
	return result


static func _find_eocd(value: PackedByteArray) -> int:
	var start: int = max(0, value.size() - 65557)
	for index in range(value.size() - 22, start - 1, -1):
		if _u32(value, index) == EOCD_SIGNATURE:
			return index
	return -1


static func _u16(value: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 2 > value.size():
		return -1
	return int(value[offset]) | (int(value[offset + 1]) << 8)


static func _u32(value: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > value.size():
		return -1
	return (int(value[offset]) | (int(value[offset + 1]) << 8) | (int(value[offset + 2]) << 16) | (int(value[offset + 3]) << 24)) & MASK32


static func _crc32(value: PackedByteArray) -> int:
	var crc := MASK32
	for byte in value:
		crc ^= int(byte)
		for _bit in range(8):
			crc = ((crc >> 1) ^ (0xEDB88320 if (crc & 1) != 0 else 0)) & MASK32
	return (~crc) & MASK32


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}
