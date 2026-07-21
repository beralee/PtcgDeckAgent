class_name DeckShareQrEncoder
extends RefCounted

# QR Code Model 2 encoder/reader for this deck-share payload.
# The generation logic is a GDScript port of the MIT-licensed Nayuki QR Code
# generator structure, reduced to the alphanumeric mode used by Base45 payloads.
# Source: https://github.com/nayuki/QR-Code-generator

const VERSION := 26
const INNER_MODULES := VERSION * 4 + 17
const QUIET_ZONE_MODULES := 4
const TOTAL_MODULES := INNER_MODULES + QUIET_ZONE_MODULES * 2
const DEFAULT_MODULE_SIZE := 3
const DEFAULT_PIXEL_SIZE := TOTAL_MODULES * DEFAULT_MODULE_SIZE
const ALPHANUMERIC_CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
const MODE_ALPHANUMERIC := 0x2
const CHAR_COUNT_BITS := 11
const ECC_ORDINAL_QUARTILE := 2
const ECC_FORMAT_BITS_QUARTILE := 3
const MASK_PATTERN := 0
const BLACK := Color(0.02, 0.02, 0.02, 1.0)
const WHITE := Color(1.0, 1.0, 1.0, 1.0)

const ECC_CODEWORDS_PER_BLOCK_QUARTILE := [
	-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30,
	28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
]
const NUM_ERROR_CORRECTION_BLOCKS_QUARTILE := [
	-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20,
	23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68,
]


static func encode_text_to_image(text: String, module_size: int = DEFAULT_MODULE_SIZE) -> Dictionary:
	var errors := PackedStringArray()
	var clean_text := text.strip_edges()
	if clean_text == "":
		errors.append("empty payload text")
		return _result(false, null, errors)
	if not _is_alphanumeric(clean_text):
		errors.append("payload text contains characters outside QR alphanumeric mode")
		return _result(false, null, errors)
	if clean_text.length() > data_capacity_bytes():
		errors.append("payload text is too large for QR version %d-Q" % VERSION)
		return _result(false, null, errors)
	if module_size <= 0:
		errors.append("module size must be positive")
		return _result(false, null, errors)

	var data_codewords := _encode_alphanumeric_data(clean_text)
	var function_modules := _empty_bool_grid(INNER_MODULES)
	var modules := _empty_bool_grid(INNER_MODULES)
	_draw_function_patterns(modules, function_modules)
	var all_codewords := _add_ecc_and_interleave(data_codewords)
	_draw_codewords(modules, function_modules, all_codewords)
	_apply_mask(modules, function_modules, MASK_PATTERN)
	_draw_format_bits(modules, function_modules, MASK_PATTERN)

	var image := _render_modules_to_image(modules, module_size)
	return _result(true, image, PackedStringArray())


static func decode_image(image: Image) -> Dictionary:
	if image == null:
		return _decode_result(false, "", PackedStringArray(["missing image"]))
	var square := image.duplicate()
	if square.get_width() != DEFAULT_PIXEL_SIZE or square.get_height() != DEFAULT_PIXEL_SIZE:
		square.resize(DEFAULT_PIXEL_SIZE, DEFAULT_PIXEL_SIZE, Image.INTERPOLATE_NEAREST)
	return _decode_square_image(square)


static func decode_image_region(image: Image, rect: Rect2i) -> Dictionary:
	if image == null:
		return _decode_result(false, "", PackedStringArray(["missing image"]))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return _decode_result(false, "", PackedStringArray(["invalid code rect"]))
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if bounded.size.x <= 0 or bounded.size.y <= 0:
		return _decode_result(false, "", PackedStringArray(["code rect is outside image"]))
	var crop := image.get_region(bounded)
	crop.resize(DEFAULT_PIXEL_SIZE, DEFAULT_PIXEL_SIZE, Image.INTERPOLATE_NEAREST)
	return _decode_square_image(crop)


static func data_capacity_bytes() -> int:
	var capacity_bits := _get_num_data_codewords(VERSION) * 8
	var max_chars := 0
	for n: int in range(0, 2048):
		var bits := 4 + CHAR_COUNT_BITS + int(n / 2) * 11 + (6 if n % 2 == 1 else 0)
		if bits <= capacity_bits:
			max_chars = n
		else:
			break
	return max_chars


static func _encode_alphanumeric_data(text: String) -> PackedByteArray:
	var bits: Array[int] = []
	_append_bits(bits, MODE_ALPHANUMERIC, 4)
	_append_bits(bits, text.length(), CHAR_COUNT_BITS)
	var i := 0
	while i + 1 < text.length():
		var value := ALPHANUMERIC_CHARS.find(text[i]) * 45 + ALPHANUMERIC_CHARS.find(text[i + 1])
		_append_bits(bits, value, 11)
		i += 2
	if i < text.length():
		_append_bits(bits, ALPHANUMERIC_CHARS.find(text[i]), 6)

	var capacity_bits := _get_num_data_codewords(VERSION) * 8
	_append_bits(bits, 0, min(4, capacity_bits - bits.size()))
	while bits.size() % 8 != 0:
		bits.append(0)
	var pad := 0xEC
	while bits.size() < capacity_bits:
		_append_bits(bits, pad, 8)
		pad = 0x11 if pad == 0xEC else 0xEC

	var bytes := PackedByteArray()
	bytes.resize(int(bits.size() / 8))
	for bit_index: int in bits.size():
		if int(bits[bit_index]) != 0:
			bytes[bit_index >> 3] = int(bytes[bit_index >> 3]) | (1 << (7 - (bit_index & 7)))
	return bytes


static func _decode_square_image(image: Image) -> Dictionary:
	var sampled := _sample_total_modules(image)
	var quiet_error := _validate_quiet_zone(sampled)
	if quiet_error != "":
		return _decode_result(false, "", PackedStringArray([quiet_error]))

	var modules := _crop_inner_modules(sampled)
	var function_modules := _empty_bool_grid(INNER_MODULES)
	var expected_function_modules := _empty_bool_grid(INNER_MODULES)
	_draw_function_patterns(expected_function_modules, function_modules)
	var function_error := _validate_function_patterns(modules, expected_function_modules, function_modules)
	if function_error != "":
		return _decode_result(false, "", PackedStringArray([function_error]))

	var mask := _read_mask_from_format_bits(modules)
	if mask < 0:
		return _decode_result(false, "", PackedStringArray(["format bits are invalid"]))
	_apply_mask(modules, function_modules, mask)
	var all_codewords := _read_codewords(modules, function_modules)
	if all_codewords.size() != _get_num_raw_data_modules(VERSION) / 8:
		return _decode_result(false, "", PackedStringArray(["QR codewords are truncated"]))

	var split := _split_interleaved_blocks(all_codewords)
	if not bool(split.get("ok", false)):
		return _decode_result(false, "", PackedStringArray([str(split.get("error", "QR block split failed"))]))
	var blocks: Array = split.get("blocks", [])
	if not _verify_block_ecc(blocks):
		return _decode_result(false, "", PackedStringArray(["QR error correction check failed"]))

	var data := _extract_data_codewords(blocks)
	return _decode_alphanumeric_data(data)


static func _sample_total_modules(image: Image) -> Array:
	var modules: Array = []
	for y: int in TOTAL_MODULES:
		var row: Array[bool] = []
		for x: int in TOTAL_MODULES:
			var px := image.get_pixel(
				int((float(x) + 0.5) * float(image.get_width()) / float(TOTAL_MODULES)),
				int((float(y) + 0.5) * float(image.get_height()) / float(TOTAL_MODULES))
			)
			row.append(_is_dark(px))
		modules.append(row)
	return modules


static func _validate_quiet_zone(sampled: Array) -> String:
	for y: int in TOTAL_MODULES:
		for x: int in TOTAL_MODULES:
			var in_quiet := x < QUIET_ZONE_MODULES or y < QUIET_ZONE_MODULES \
				or x >= TOTAL_MODULES - QUIET_ZONE_MODULES or y >= TOTAL_MODULES - QUIET_ZONE_MODULES
			if in_quiet and bool(sampled[y][x]):
				return "QR quiet zone is damaged"
	return ""


static func _crop_inner_modules(sampled: Array) -> Array:
	var modules: Array = []
	for y: int in INNER_MODULES:
		var row: Array[bool] = []
		for x: int in INNER_MODULES:
			row.append(bool(sampled[y + QUIET_ZONE_MODULES][x + QUIET_ZONE_MODULES]))
		modules.append(row)
	return modules


static func _validate_function_patterns(modules: Array, expected: Array, function_modules: Array) -> String:
	for y: int in INNER_MODULES:
		for x: int in INNER_MODULES:
			if bool(function_modules[y][x]) and bool(modules[y][x]) != bool(expected[y][x]):
				return "QR function pattern mismatch"
	return ""


static func _decode_alphanumeric_data(data: PackedByteArray) -> Dictionary:
	var bits := _bytes_to_bits(data)
	var offset := 0
	var mode := _read_bits(bits, offset, 4)
	offset += 4
	if mode != MODE_ALPHANUMERIC:
		return _decode_result(false, "", PackedStringArray(["QR payload mode is not alphanumeric"]))
	var count := _read_bits(bits, offset, CHAR_COUNT_BITS)
	offset += CHAR_COUNT_BITS
	if count < 0 or count > data_capacity_bytes():
		return _decode_result(false, "", PackedStringArray(["QR character count is invalid"]))

	var chars := PackedStringArray()
	var remaining := count
	while remaining >= 2:
		if offset + 11 > bits.size():
			return _decode_result(false, "", PackedStringArray(["QR payload is truncated"]))
		var value := _read_bits(bits, offset, 11)
		offset += 11
		var first := int(value / 45)
		var second := value % 45
		if first >= ALPHANUMERIC_CHARS.length() or second >= ALPHANUMERIC_CHARS.length():
			return _decode_result(false, "", PackedStringArray(["QR alphanumeric value is invalid"]))
		chars.append(ALPHANUMERIC_CHARS[first])
		chars.append(ALPHANUMERIC_CHARS[second])
		remaining -= 2
	if remaining == 1:
		if offset + 6 > bits.size():
			return _decode_result(false, "", PackedStringArray(["QR payload is truncated"]))
		var value := _read_bits(bits, offset, 6)
		if value >= ALPHANUMERIC_CHARS.length():
			return _decode_result(false, "", PackedStringArray(["QR alphanumeric value is invalid"]))
		chars.append(ALPHANUMERIC_CHARS[value])
	return _decode_result(true, "".join(chars), PackedStringArray())


static func _draw_function_patterns(modules: Array, function_modules: Array) -> void:
	for i: int in INNER_MODULES:
		_set_function_module(modules, function_modules, 6, i, i % 2 == 0)
		_set_function_module(modules, function_modules, i, 6, i % 2 == 0)

	_draw_finder_pattern(modules, function_modules, 3, 3)
	_draw_finder_pattern(modules, function_modules, INNER_MODULES - 4, 3)
	_draw_finder_pattern(modules, function_modules, 3, INNER_MODULES - 4)

	var positions := _alignment_pattern_positions()
	var numalign := positions.size()
	for i: int in numalign:
		for j: int in numalign:
			var skip := (i == 0 and j == 0) or (i == 0 and j == numalign - 1) or (i == numalign - 1 and j == 0)
			if not skip:
				_draw_alignment_pattern(modules, function_modules, positions[i], positions[j])

	_draw_format_bits(modules, function_modules, 0)
	_draw_version(modules, function_modules)


static func _draw_format_bits(modules: Array, function_modules: Array, mask: int) -> void:
	var data := (ECC_FORMAT_BITS_QUARTILE << 3) | mask
	var rem := data
	for _i: int in 10:
		rem = (rem << 1) ^ (((rem >> 9) & 1) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412

	for i: int in range(0, 6):
		_set_function_module(modules, function_modules, 8, i, _get_bit(bits, i))
	_set_function_module(modules, function_modules, 8, 7, _get_bit(bits, 6))
	_set_function_module(modules, function_modules, 8, 8, _get_bit(bits, 7))
	_set_function_module(modules, function_modules, 7, 8, _get_bit(bits, 8))
	for i: int in range(9, 15):
		_set_function_module(modules, function_modules, 14 - i, 8, _get_bit(bits, i))

	for i: int in range(0, 8):
		_set_function_module(modules, function_modules, INNER_MODULES - 1 - i, 8, _get_bit(bits, i))
	for i: int in range(8, 15):
		_set_function_module(modules, function_modules, 8, INNER_MODULES - 15 + i, _get_bit(bits, i))
	_set_function_module(modules, function_modules, 8, INNER_MODULES - 8, true)


static func _read_mask_from_format_bits(modules: Array) -> int:
	var read_bits := 0
	for i: int in range(0, 6):
		if bool(modules[i][8]):
			read_bits |= 1 << i
	if bool(modules[7][8]):
		read_bits |= 1 << 6
	if bool(modules[8][8]):
		read_bits |= 1 << 7
	if bool(modules[8][7]):
		read_bits |= 1 << 8
	for i: int in range(9, 15):
		if bool(modules[8][14 - i]):
			read_bits |= 1 << i
	for mask: int in range(0, 8):
		if _format_bits_for_mask(mask) == read_bits:
			return mask
	return -1


static func _format_bits_for_mask(mask: int) -> int:
	var data := (ECC_FORMAT_BITS_QUARTILE << 3) | mask
	var rem := data
	for _i: int in 10:
		rem = (rem << 1) ^ (((rem >> 9) & 1) * 0x537)
	return ((data << 10) | rem) ^ 0x5412


static func _draw_version(modules: Array, function_modules: Array) -> void:
	var rem := VERSION
	for _i: int in 12:
		rem = (rem << 1) ^ (((rem >> 11) & 1) * 0x1F25)
	var bits := (VERSION << 12) | rem
	for i: int in 18:
		var bit := _get_bit(bits, i)
		var a := INNER_MODULES - 11 + i % 3
		var b := int(i / 3)
		_set_function_module(modules, function_modules, a, b, bit)
		_set_function_module(modules, function_modules, b, a, bit)


static func _draw_finder_pattern(modules: Array, function_modules: Array, center_x: int, center_y: int) -> void:
	for dy: int in range(-4, 5):
		for dx: int in range(-4, 5):
			var x := center_x + dx
			var y := center_y + dy
			if x >= 0 and x < INNER_MODULES and y >= 0 and y < INNER_MODULES:
				var dist: int = max(abs(dx), abs(dy))
				_set_function_module(modules, function_modules, x, y, dist != 2 and dist != 4)


static func _draw_alignment_pattern(modules: Array, function_modules: Array, center_x: int, center_y: int) -> void:
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var dist: int = max(abs(dx), abs(dy))
			_set_function_module(modules, function_modules, center_x + dx, center_y + dy, dist != 1)


static func _set_function_module(modules: Array, function_modules: Array, x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	function_modules[y][x] = true


static func _alignment_pattern_positions() -> Array[int]:
	var numalign := int(VERSION / 7) + 2
	var step := int((VERSION * 8 + numalign * 3 + 5) / (numalign * 4 - 4)) * 2
	var result: Array[int] = [6]
	for i: int in range(numalign - 2, -1, -1):
		result.append(INNER_MODULES - 7 - i * step)
	return result


static func _add_ecc_and_interleave(data: PackedByteArray) -> PackedByteArray:
	var numblocks := NUM_ERROR_CORRECTION_BLOCKS_QUARTILE[VERSION]
	var blockecclen := ECC_CODEWORDS_PER_BLOCK_QUARTILE[VERSION]
	var rawcodewords := int(_get_num_raw_data_modules(VERSION) / 8)
	var numshortblocks := numblocks - rawcodewords % numblocks
	var shortblocklen := int(rawcodewords / numblocks)
	var divisor := _reed_solomon_compute_divisor(blockecclen)
	var blocks: Array[PackedByteArray] = []
	var k := 0
	for i: int in numblocks:
		var data_len := shortblocklen - blockecclen + (0 if i < numshortblocks else 1)
		var dat := data.slice(k, k + data_len)
		k += data_len
		var ecc := _reed_solomon_compute_remainder(dat, divisor)
		if i < numshortblocks:
			dat.append(0)
		var block := PackedByteArray()
		block.append_array(dat)
		block.append_array(ecc)
		blocks.append(block)

	var result := PackedByteArray()
	for i: int in blocks[0].size():
		for j: int in blocks.size():
			if i != shortblocklen - blockecclen or j >= numshortblocks:
				result.append(blocks[j][i])
	return result


static func _split_interleaved_blocks(codewords: PackedByteArray) -> Dictionary:
	var numblocks := NUM_ERROR_CORRECTION_BLOCKS_QUARTILE[VERSION]
	var blockecclen := ECC_CODEWORDS_PER_BLOCK_QUARTILE[VERSION]
	var rawcodewords := int(_get_num_raw_data_modules(VERSION) / 8)
	var numshortblocks := numblocks - rawcodewords % numblocks
	var shortblocklen := int(rawcodewords / numblocks)
	var block_len := shortblocklen + 1
	var blocks: Array[PackedByteArray] = []
	for _j: int in numblocks:
		var block := PackedByteArray()
		block.resize(block_len)
		blocks.append(block)

	var k := 0
	for i: int in block_len:
		for j: int in numblocks:
			if i == shortblocklen - blockecclen and j < numshortblocks:
				continue
			if k >= codewords.size():
				return {"ok": false, "blocks": [], "error": "QR codewords ended early"}
			blocks[j][i] = codewords[k]
			k += 1
	if k != codewords.size():
		return {"ok": false, "blocks": [], "error": "QR codewords have trailing data"}
	return {"ok": true, "blocks": blocks, "error": ""}


static func _verify_block_ecc(blocks: Array) -> bool:
	var blockecclen := ECC_CODEWORDS_PER_BLOCK_QUARTILE[VERSION]
	var rawcodewords := int(_get_num_raw_data_modules(VERSION) / 8)
	var numblocks := NUM_ERROR_CORRECTION_BLOCKS_QUARTILE[VERSION]
	var numshortblocks := numblocks - rawcodewords % numblocks
	var shortblocklen := int(rawcodewords / numblocks)
	var data_start_ecc := shortblocklen - blockecclen + 1
	var divisor := _reed_solomon_compute_divisor(blockecclen)
	for j: int in blocks.size():
		var block: PackedByteArray = blocks[j]
		var data_len := shortblocklen - blockecclen + (0 if j < numshortblocks else 1)
		var dat := block.slice(0, data_len)
		var expected := _reed_solomon_compute_remainder(dat, divisor)
		for i: int in blockecclen:
			if int(block[data_start_ecc + i]) != int(expected[i]):
				return false
	return true


static func _extract_data_codewords(blocks: Array) -> PackedByteArray:
	var blockecclen := ECC_CODEWORDS_PER_BLOCK_QUARTILE[VERSION]
	var rawcodewords := int(_get_num_raw_data_modules(VERSION) / 8)
	var numblocks := NUM_ERROR_CORRECTION_BLOCKS_QUARTILE[VERSION]
	var numshortblocks := numblocks - rawcodewords % numblocks
	var shortblocklen := int(rawcodewords / numblocks)
	var result := PackedByteArray()
	for j: int in blocks.size():
		var block: PackedByteArray = blocks[j]
		var data_len := shortblocklen - blockecclen + (0 if j < numshortblocks else 1)
		result.append_array(block.slice(0, data_len))
	return result


static func _draw_codewords(modules: Array, function_modules: Array, data: PackedByteArray) -> void:
	var bit_index := 0
	var right := INNER_MODULES - 1
	while right > 0:
		if right == 6:
			right -= 1
		for vert: int in INNER_MODULES:
			for j: int in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := INNER_MODULES - 1 - vert if upward else vert
				if not bool(function_modules[y][x]) and bit_index < data.size() * 8:
					modules[y][x] = _get_bit(data[bit_index >> 3], 7 - (bit_index & 7))
					bit_index += 1
		right -= 2


static func _read_codewords(modules: Array, function_modules: Array) -> PackedByteArray:
	var bits: Array[int] = []
	var right := INNER_MODULES - 1
	while right > 0:
		if right == 6:
			right -= 1
		for vert: int in INNER_MODULES:
			for j: int in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := INNER_MODULES - 1 - vert if upward else vert
				if not bool(function_modules[y][x]):
					bits.append(1 if bool(modules[y][x]) else 0)
		right -= 2

	var byte_count := int(_get_num_raw_data_modules(VERSION) / 8)
	var result := PackedByteArray()
	result.resize(byte_count)
	for i: int in byte_count * 8:
		if i < bits.size() and int(bits[i]) != 0:
			result[i >> 3] = int(result[i >> 3]) | (1 << (7 - (i & 7)))
	return result


static func _apply_mask(modules: Array, function_modules: Array, mask: int) -> void:
	for y: int in INNER_MODULES:
		for x: int in INNER_MODULES:
			if not bool(function_modules[y][x]) and _mask_bit(mask, x, y):
				modules[y][x] = not bool(modules[y][x])


static func _mask_bit(mask: int, x: int, y: int) -> bool:
	match mask:
		0:
			return (x + y) % 2 == 0
		1:
			return y % 2 == 0
		2:
			return x % 3 == 0
		3:
			return (x + y) % 3 == 0
		4:
			return (int(x / 3) + int(y / 2)) % 2 == 0
		5:
			return (x * y) % 2 + (x * y) % 3 == 0
		6:
			return ((x * y) % 2 + (x * y) % 3) % 2 == 0
		7:
			return ((x + y) % 2 + (x * y) % 3) % 2 == 0
	return false


static func _render_modules_to_image(modules: Array, module_size: int) -> Image:
	var pixel_size := TOTAL_MODULES * module_size
	var image := Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	image.fill(WHITE)
	for y: int in INNER_MODULES:
		for x: int in INNER_MODULES:
			if bool(modules[y][x]):
				image.fill_rect(Rect2i(
					(x + QUIET_ZONE_MODULES) * module_size,
					(y + QUIET_ZONE_MODULES) * module_size,
					module_size,
					module_size
				), BLACK)
	return image


static func _get_num_raw_data_modules(version: int) -> int:
	var result := (16 * version + 128) * version + 64
	if version >= 2:
		var numalign := int(version / 7) + 2
		result -= (25 * numalign - 10) * numalign - 55
		if version >= 7:
			result -= 36
	return result


static func _get_num_data_codewords(version: int) -> int:
	return int(_get_num_raw_data_modules(version) / 8) \
		- int(ECC_CODEWORDS_PER_BLOCK_QUARTILE[version]) * int(NUM_ERROR_CORRECTION_BLOCKS_QUARTILE[version])


static func _reed_solomon_compute_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for _i: int in degree:
		for j: int in degree:
			result[j] = _reed_solomon_multiply(result[j], root)
			if j + 1 < degree:
				result[j] = int(result[j]) ^ int(result[j + 1])
		root = _reed_solomon_multiply(root, 0x02)
	return result


static func _reed_solomon_compute_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b: int in data:
		var factor := b ^ int(result[0])
		for i: int in range(0, result.size() - 1):
			result[i] = result[i + 1]
		result[result.size() - 1] = 0
		for i: int in divisor.size():
			result[i] = int(result[i]) ^ _reed_solomon_multiply(divisor[i], factor)
	return result


static func _reed_solomon_multiply(x: int, y: int) -> int:
	var z := 0
	for i: int in range(7, -1, -1):
		z = (z << 1) ^ (((z >> 7) & 1) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF


static func _bytes_to_bits(bytes: PackedByteArray) -> Array[int]:
	var bits: Array[int] = []
	for byte: int in bytes:
		for i: int in range(7, -1, -1):
			bits.append((byte >> i) & 1)
	return bits


static func _append_bits(bits: Array[int], value: int, count: int) -> void:
	for i: int in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _read_bits(bits: Array[int], offset: int, count: int) -> int:
	var value := 0
	for i: int in count:
		value = (value << 1) | int(bits[offset + i])
	return value


static func _get_bit(value: int, bit_index: int) -> bool:
	return ((value >> bit_index) & 1) != 0


static func _empty_bool_grid(size: int) -> Array:
	var grid: Array = []
	for _y: int in size:
		var row: Array[bool] = []
		for _x: int in size:
			row.append(false)
		grid.append(row)
	return grid


static func _is_alphanumeric(text: String) -> bool:
	for i: int in text.length():
		if ALPHANUMERIC_CHARS.find(text[i]) < 0:
			return false
	return true


static func _is_dark(color: Color) -> bool:
	return (color.r + color.g + color.b) / 3.0 < 0.5


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
