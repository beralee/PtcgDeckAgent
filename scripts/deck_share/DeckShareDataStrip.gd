class_name DeckShareDataStrip
extends RefCounted

const DeckShareQrEncoderScript := preload("res://scripts/deck_share/DeckShareQrEncoder.gd")

const STRIP_SIZE := Vector2i(860, 156)
const MODULE_SIZE := 4
const QUIET_MODULES := 4
const LENGTH_BITS := 16
const CHECKSUM_BITS := 16
const DATA_COLUMNS := 207
const DATA_ROWS := 31
const BLACK := Color(0.02, 0.02, 0.02, 1.0)
const WHITE := Color(1.0, 1.0, 1.0, 1.0)
const BORDER := Color(0.72, 0.74, 0.76, 1.0)


static func max_text_length() -> int:
	return int((DATA_COLUMNS * DATA_ROWS - LENGTH_BITS - CHECKSUM_BITS) / 6)


static func encode_text_to_image(text: String) -> Dictionary:
	var errors := PackedStringArray()
	var clean_text := text.strip_edges()
	if clean_text == "":
		errors.append("empty payload text")
		return _result(false, null, errors)
	if clean_text.length() > max_text_length():
		errors.append("payload text is too large for deck-share strip")
		return _result(false, null, errors)
	for i: int in clean_text.length():
		if DeckShareQrEncoderScript.ALPHANUMERIC_CHARS.find(clean_text[i]) < 0:
			errors.append("payload text contains unsupported strip characters")
			return _result(false, null, errors)

	var bits: Array[int] = []
	_append_bits(bits, clean_text.length(), LENGTH_BITS)
	for i: int in clean_text.length():
		_append_bits(bits, DeckShareQrEncoderScript.ALPHANUMERIC_CHARS.find(clean_text[i]), 6)
	_append_bits(bits, _crc16(clean_text), CHECKSUM_BITS)
	while bits.size() < DATA_COLUMNS * DATA_ROWS:
		bits.append(0)

	var image := Image.create(STRIP_SIZE.x, STRIP_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(WHITE)
	image.fill_rect(Rect2i(0, 0, STRIP_SIZE.x, MODULE_SIZE), BORDER)
	image.fill_rect(Rect2i(0, STRIP_SIZE.y - MODULE_SIZE, STRIP_SIZE.x, MODULE_SIZE), BORDER)
	image.fill_rect(Rect2i(0, 0, MODULE_SIZE * 2, STRIP_SIZE.y), BLACK)
	image.fill_rect(Rect2i(STRIP_SIZE.x - MODULE_SIZE * 2, 0, MODULE_SIZE * 2, STRIP_SIZE.y), BLACK)
	for row: int in DATA_ROWS:
		for col: int in DATA_COLUMNS:
			var index := row * DATA_COLUMNS + col
			if index >= bits.size() or bits[index] == 0:
				continue
			var pos := Vector2i((QUIET_MODULES + col) * MODULE_SIZE, (QUIET_MODULES + row) * MODULE_SIZE)
			image.fill_rect(Rect2i(pos, Vector2i(MODULE_SIZE, MODULE_SIZE)), BLACK)
	return _result(true, image, PackedStringArray())


static func decode_image_region(image: Image, rect: Rect2i) -> Dictionary:
	if image == null:
		return _decode_result(false, "", PackedStringArray(["missing image"]))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return _decode_result(false, "", PackedStringArray(["invalid strip rect"]))
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if bounded.size.x <= 0 or bounded.size.y <= 0:
		return _decode_result(false, "", PackedStringArray(["strip rect is outside image"]))
	var crop := image.get_region(bounded)
	return decode_image(crop)


static func decode_image(image: Image) -> Dictionary:
	if image == null:
		return _decode_result(false, "", PackedStringArray(["missing image"]))
	var sample := image.duplicate()
	if sample.get_size() != STRIP_SIZE:
		sample.resize(STRIP_SIZE.x, STRIP_SIZE.y, Image.INTERPOLATE_NEAREST)
	var bits: Array[int] = []
	for row: int in DATA_ROWS:
		for col: int in DATA_COLUMNS:
			bits.append(1 if _sample_module_is_dark(sample, col, row) else 0)
	var offset := 0
	var text_length := _read_bits(bits, offset, LENGTH_BITS)
	offset += LENGTH_BITS
	if text_length <= 0 or text_length > max_text_length():
		return _decode_result(false, "", PackedStringArray(["invalid strip payload length"]))
	var text := ""
	for _i: int in text_length:
		var char_index := _read_bits(bits, offset, 6)
		offset += 6
		if char_index < 0 or char_index >= DeckShareQrEncoderScript.ALPHANUMERIC_CHARS.length():
			return _decode_result(false, "", PackedStringArray(["invalid strip character"]))
		text += DeckShareQrEncoderScript.ALPHANUMERIC_CHARS[char_index]
	var expected_crc := _read_bits(bits, offset, CHECKSUM_BITS)
	if expected_crc != _crc16(text):
		return _decode_result(false, "", PackedStringArray(["strip checksum mismatch"]))
	return _decode_result(true, text, PackedStringArray())


static func _sample_module_is_dark(image: Image, col: int, row: int) -> bool:
	var x0 := (QUIET_MODULES + col) * MODULE_SIZE
	var y0 := (QUIET_MODULES + row) * MODULE_SIZE
	var luminance := 0.0
	var samples := 0
	for y: int in MODULE_SIZE:
		for x: int in MODULE_SIZE:
			var px := image.get_pixel(x0 + x, y0 + y)
			luminance += (px.r + px.g + px.b) / 3.0
			samples += 1
	return samples > 0 and luminance / float(samples) < 0.5


static func _crc16(text: String) -> int:
	var crc := 0xFFFF
	for i: int in text.length():
		crc = crc ^ ((text.unicode_at(i) & 0xFF) << 8)
		for _bit: int in 8:
			if (crc & 0x8000) != 0:
				crc = ((crc << 1) ^ 0x1021) & 0xFFFF
			else:
				crc = (crc << 1) & 0xFFFF
	return crc & 0xFFFF


static func _append_bits(bits: Array[int], value: int, count: int) -> void:
	for i: int in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _read_bits(bits: Array[int], offset: int, count: int) -> int:
	if offset < 0 or offset + count > bits.size():
		return -1
	var value := 0
	for i: int in count:
		value = (value << 1) | int(bits[offset + i])
	return value


static func _result(ok: bool, image: Image, errors: PackedStringArray) -> Dictionary:
	return {
		"ok": ok and errors.is_empty(),
		"image": image,
		"errors": errors,
	}


static func _decode_result(ok: bool, text: String, errors: PackedStringArray) -> Dictionary:
	return {
		"ok": ok and errors.is_empty(),
		"text": text,
		"errors": errors,
	}
