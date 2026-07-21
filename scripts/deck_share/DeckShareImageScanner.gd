class_name DeckShareImageScanner
extends RefCounted

signal scan_completed(texts: PackedStringArray)
signal scan_failed(message: String)

const DeckShareQrEncoderScript := preload("res://scripts/deck_share/DeckShareQrEncoder.gd")
const DeckShareDataStripScript := preload("res://scripts/deck_share/DeckShareDataStrip.gd")
const POSTER_WIDTH := 1080
const LEGACY_POSTER_SIZE := Vector2i(1080, 1920)
const POSTER_CODE_HEIGHT := int(DeckShareDataStripScript.STRIP_SIZE.y / 2)
const POSTER_SITE_LABEL_TOP_GAP := 4
const POSTER_SITE_LABEL_HEIGHT := 30
const POSTER_BOTTOM_PADDING := 8
const POSTER_CODE_BOTTOM_OFFSET := POSTER_SITE_LABEL_TOP_GAP + POSTER_SITE_LABEL_HEIGHT + POSTER_BOTTOM_PADDING
const LEGACY_FULL_WIDTH_BOTTOM_CODE_RECT := Rect2i(0, LEGACY_POSTER_SIZE.y - POSTER_CODE_HEIGHT, LEGACY_POSTER_SIZE.x, POSTER_CODE_HEIGHT)
const LEGACY_CENTERED_POSTER_CODE_RECT := Rect2i(110, 1790, DeckShareDataStripScript.STRIP_SIZE.x, POSTER_CODE_HEIGHT)
const LEGACY_POSTER_QR_RECT := Rect2i(60, 1452, DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE, DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE)


func scan_image_bytes(bytes: PackedByteArray, _source_name: String = "") -> void:
	var result := scan_bytes(bytes)
	if bool(result.get("ok", false)):
		scan_completed.emit(result.get("texts", PackedStringArray()))
	else:
		scan_failed.emit(str(result.get("error", "没有识别到卡组数据")))


static func scan_bytes(bytes: PackedByteArray) -> Dictionary:
	var image_result := _load_image_from_bytes(bytes)
	if not bool(image_result.get("ok", false)):
		return _result(false, PackedStringArray(), str(image_result.get("error", "image load failed")))
	return scan_image(image_result.get("image", null))


static func scan_image(image: Image) -> Dictionary:
	if image == null:
		return _result(false, PackedStringArray(), "missing image")

	var decode_attempts: Array[Dictionary] = []
	if image.get_width() == image.get_height():
		decode_attempts.append(DeckShareQrEncoderScript.decode_image(image))
	if _looks_like_poster_image(image.get_size()):
		decode_attempts.append(DeckShareDataStripScript.decode_image_region(image, _dynamic_poster_code_rect(image.get_size(), true)))
		decode_attempts.append(DeckShareDataStripScript.decode_image_region(image, _dynamic_poster_code_rect(image.get_size(), false)))
		decode_attempts.append(DeckShareDataStripScript.decode_image_region(image, _scale_legacy_poster_rect(LEGACY_FULL_WIDTH_BOTTOM_CODE_RECT, image.get_size())))
		decode_attempts.append(DeckShareDataStripScript.decode_image_region(image, _scale_legacy_poster_rect(LEGACY_CENTERED_POSTER_CODE_RECT, image.get_size())))
		decode_attempts.append(DeckShareQrEncoderScript.decode_image_region(image, _scale_legacy_poster_rect(LEGACY_POSTER_QR_RECT, image.get_size())))

	var discovered_rect := _find_code_rect_by_finders(image)
	if discovered_rect.size.x > 0 and discovered_rect.size.y > 0:
		decode_attempts.append(DeckShareQrEncoderScript.decode_image_region(image, discovered_rect))

	var errors := PackedStringArray()
	for attempt: Dictionary in decode_attempts:
		if bool(attempt.get("ok", false)):
			var text := str(attempt.get("text", "")).strip_edges()
			if text != "":
				return _result(true, PackedStringArray([text]), "")
		var attempt_errors: PackedStringArray = attempt.get("errors", PackedStringArray())
		for err: String in attempt_errors:
			errors.append(err)
	if errors.is_empty():
		errors.append("no deck share code found")
	return _result(false, PackedStringArray(), errors[0])


static func _load_image_from_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {"ok": false, "image": null, "error": "empty image bytes"}
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if _looks_like_png(bytes):
		err = image.load_png_from_buffer(bytes)
	elif _looks_like_jpg(bytes):
		err = image.load_jpg_from_buffer(bytes)
	elif _looks_like_webp(bytes):
		err = image.load_webp_from_buffer(bytes)
	else:
		err = image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = image.load_webp_from_buffer(bytes)
	if err != OK:
		return {"ok": false, "image": null, "error": "unsupported image format"}
	return {"ok": true, "image": image, "error": ""}


static func _looks_like_poster_image(size: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	return size.x >= 360 and size.y >= 240


static func _dynamic_poster_code_rect(target_size: Vector2i, reserve_site_footer: bool) -> Rect2i:
	var scale := float(target_size.x) / float(POSTER_WIDTH)
	var code_height := maxi(1, int(round(float(POSTER_CODE_HEIGHT) * scale)))
	var bottom_offset := int(round(float(POSTER_CODE_BOTTOM_OFFSET) * scale)) if reserve_site_footer else 0
	var y := target_size.y - bottom_offset - code_height
	return Rect2i(0, maxi(0, y), target_size.x, mini(code_height, target_size.y))


static func _dynamic_poster_code_rect_for_tests(target_size: Vector2i, reserve_site_footer: bool = true) -> Rect2i:
	return _dynamic_poster_code_rect(target_size, reserve_site_footer)


static func _scale_legacy_poster_rect(rect: Rect2i, target_size: Vector2i) -> Rect2i:
	var scale_x := float(target_size.x) / float(LEGACY_POSTER_SIZE.x)
	var scale_y := float(target_size.y) / float(LEGACY_POSTER_SIZE.y)
	var top_left := Vector2i(
		int(round(float(rect.position.x) * scale_x)),
		int(round(float(rect.position.y) * scale_y))
	)
	var bottom_right := Vector2i(
		int(round(float(rect.end.x) * scale_x)),
		int(round(float(rect.end.y) * scale_y))
	)
	return Rect2i(top_left, bottom_right - top_left)


static func _looks_like_png(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 8 \
		and int(bytes[0]) == 0x89 \
		and int(bytes[1]) == 0x50 \
		and int(bytes[2]) == 0x4E \
		and int(bytes[3]) == 0x47 \
		and int(bytes[4]) == 0x0D \
		and int(bytes[5]) == 0x0A \
		and int(bytes[6]) == 0x1A \
		and int(bytes[7]) == 0x0A


static func _looks_like_jpg(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 3 and int(bytes[0]) == 0xFF and int(bytes[1]) == 0xD8 and int(bytes[2]) == 0xFF


static func _looks_like_webp(bytes: PackedByteArray) -> bool:
	if bytes.size() < 12:
		return false
	return char(bytes[0]) + char(bytes[1]) + char(bytes[2]) + char(bytes[3]) == "RIFF" \
		and char(bytes[8]) + char(bytes[9]) + char(bytes[10]) + char(bytes[11]) == "WEBP"


static func _find_code_rect_by_finders(image: Image) -> Rect2i:
	var expected_size := DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE
	if image.get_width() < expected_size or image.get_height() < expected_size:
		return Rect2i()
	var candidates := [
		LEGACY_POSTER_QR_RECT,
		Rect2i(48, image.get_height() - expected_size - 48, expected_size, expected_size),
		Rect2i(int((image.get_width() - expected_size) / 2), image.get_height() - expected_size - 48, expected_size, expected_size),
	]
	for rect: Rect2i in candidates:
		if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect):
			continue
		if _region_has_finders(image, rect):
			return rect
	return Rect2i()


static func _region_has_finders(image: Image, rect: Rect2i) -> bool:
	var sample := image.get_region(rect)
	sample.resize(DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE, DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE, Image.INTERPOLATE_NEAREST)
	var result: Dictionary = DeckShareQrEncoderScript.decode_image(sample)
	return bool(result.get("ok", false)) or _finder_like_at(sample, 0, 0)


static func _finder_like_at(image: Image, module_x: int, module_y: int) -> bool:
	var module_size := DeckShareQrEncoderScript.DEFAULT_MODULE_SIZE
	var quiet := DeckShareQrEncoderScript.QUIET_ZONE_MODULES
	var dark_count := 0
	var samples := 0
	for y: int in 7:
		for x: int in 7:
			var expected := x == 0 or y == 0 or x == 6 or y == 6 or (x >= 2 and x <= 4 and y >= 2 and y <= 4)
			var px := image.get_pixel((quiet + module_x + x) * module_size + int(module_size / 2), (quiet + module_y + y) * module_size + int(module_size / 2))
			var actual := (px.r + px.g + px.b) / 3.0 < 0.5
			if actual == expected:
				dark_count += 1
			samples += 1
	return dark_count >= int(samples * 0.9)


static func _result(ok: bool, texts: PackedStringArray, error: String) -> Dictionary:
	return {
		"ok": ok,
		"texts": texts,
		"error": error,
	}
