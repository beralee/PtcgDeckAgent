class_name TestDeckShareQrEncoder
extends TestBase

const DeckShareQrEncoderScript := preload("res://scripts/deck_share/DeckShareQrEncoder.gd")
const DeckSharePayloadCodecScript := preload("res://scripts/deck_share/DeckSharePayloadCodec.gd")


func test_deck_share_code_roundtrip_text() -> String:
	var text := "PTCGD1.ABC123.%08X" % 12345
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(text)
	var image: Image = encoded.get("image", null)
	var decoded := DeckShareQrEncoderScript.decode_image(image)
	return run_checks([
		assert_true(bool(encoded.get("ok", false)), "code image should encode"),
		assert_not_null(image, "code image should exist"),
		assert_eq(image.get_width() if image != null else 0, DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE, "code width"),
		assert_eq(image.get_height() if image != null else 0, DeckShareQrEncoderScript.DEFAULT_PIXEL_SIZE, "code height"),
		assert_true(bool(decoded.get("ok", false)), "code image should decode"),
		assert_eq(str(decoded.get("text", "")), text, "decoded text"),
	])


func test_deck_share_code_matches_standard_qr_reference_fingerprint() -> String:
	var text := "PTCGD1.STANDARD.QR.TEST-0123456789"
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(text)
	var image: Image = encoded.get("image", null)
	if image == null:
		return "code image should exist"
	var fnv := 2166136261
	var dark_count := 0
	for y: int in DeckShareQrEncoderScript.INNER_MODULES:
		for x: int in DeckShareQrEncoderScript.INNER_MODULES:
			var px := image.get_pixel(
				(DeckShareQrEncoderScript.QUIET_ZONE_MODULES + x) * DeckShareQrEncoderScript.DEFAULT_MODULE_SIZE + int(DeckShareQrEncoderScript.DEFAULT_MODULE_SIZE / 2),
				(DeckShareQrEncoderScript.QUIET_ZONE_MODULES + y) * DeckShareQrEncoderScript.DEFAULT_MODULE_SIZE + int(DeckShareQrEncoderScript.DEFAULT_MODULE_SIZE / 2)
			)
			var bit := 1 if (px.r + px.g + px.b) / 3.0 < 0.5 else 0
			dark_count += bit
			fnv = ((fnv ^ bit) * 16777619) & 0xFFFFFFFF
	return run_checks([
		assert_eq(DeckShareQrEncoderScript.INNER_MODULES, 121, "QR version 26 module size"),
		assert_eq(dark_count, 7196, "standard QR dark module count"),
		assert_eq(fnv, 1820447415, "standard QR module fingerprint"),
	])


func test_bundled_deck_payloads_fit_current_qr_capacity() -> String:
	var dir := DirAccess.open("res://data/bundled_user/decks")
	if dir == null:
		return "bundled decks directory should exist"
	var too_large := PackedStringArray()
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file := FileAccess.open("res://data/bundled_user/decks/%s" % file_name, FileAccess.READ)
			if file == null:
				too_large.append("%s: unreadable" % file_name)
			else:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				file.close()
				if parsed is Dictionary:
					var deck := DeckData.from_dict(parsed)
					var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "test-db")
					var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
					var text := str(encoded.get("text", ""))
					if not bool(built.get("ok", false)) or not bool(encoded.get("ok", false)):
						too_large.append("%s: payload encode failed" % file_name)
					elif text.length() > DeckShareQrEncoderScript.data_capacity_bytes():
						too_large.append("%s: %d>%d" % [file_name, text.length(), DeckShareQrEncoderScript.data_capacity_bytes()])
		file_name = dir.get_next()
	dir.list_dir_end()
	return run_checks([
		assert_eq(too_large.size(), 0, "all bundled decks should fit current QR capacity: %s" % ", ".join(too_large)),
	])


func test_deck_share_code_rejects_oversize_payload() -> String:
	var too_large := "A".repeat(DeckShareQrEncoderScript.data_capacity_bytes() + 1)
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(too_large)
	var errors: PackedStringArray = encoded.get("errors", PackedStringArray())
	return run_checks([
		assert_false(bool(encoded.get("ok", true)), "oversize payload should fail"),
		assert_str_contains(errors[0] if not errors.is_empty() else "", "large", "oversize error"),
	])


func test_deck_share_code_detects_corrupted_pixels() -> String:
	var text := "PTCGD1.CORRUPTION.TEST"
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(text)
	var image: Image = encoded.get("image", null)
	if image == null:
		return "code image should exist"
	image.fill_rect(Rect2i(52, 16, 160, 40), Color.BLACK)
	var decoded := DeckShareQrEncoderScript.decode_image(image)
	return run_checks([
		assert_false(bool(decoded.get("ok", true)), "damaged code should not decode"),
	])
