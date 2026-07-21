class_name TestDeckShareImageScanner
extends TestBase

const DeckShareQrEncoderScript := preload("res://scripts/deck_share/DeckShareQrEncoder.gd")
const DeckShareDataStripScript := preload("res://scripts/deck_share/DeckShareDataStrip.gd")
const DeckShareImageScannerScript := preload("res://scripts/deck_share/DeckShareImageScanner.gd")


func test_scanner_reads_standalone_png_code() -> String:
	var text := "PTCGD1.SCANNER.TEST.12345678"
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(text)
	var image: Image = encoded.get("image", null)
	if image == null:
		return "code image should exist"
	var bytes := image.save_png_to_buffer()
	var scanned := DeckShareImageScannerScript.scan_bytes(bytes)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "scanner should read standalone PNG code"),
		assert_eq(texts.size(), 1, "scanner text count"),
		assert_eq(texts[0] if texts.size() > 0 else "", text, "scanned text"),
	])


func test_scanner_reads_horizontal_data_strip_from_poster_rect() -> String:
	var text := "PTCGD1.STRIP.TEST.12345678"
	var encoded := DeckShareDataStripScript.encode_text_to_image(text)
	var strip: Image = encoded.get("image", null)
	if strip == null:
		return "strip image should exist"
	var poster_size := Vector2i(1080, 620)
	var code_rect: Rect2i = DeckShareImageScannerScript._dynamic_poster_code_rect_for_tests(poster_size)
	strip.resize(code_rect.size.x, code_rect.size.y, Image.INTERPOLATE_NEAREST)
	var poster := Image.create(poster_size.x, poster_size.y, false, Image.FORMAT_RGBA8)
	poster.fill(Color(0.92, 0.94, 0.96, 1.0))
	poster.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), code_rect.position)
	var scanned := DeckShareImageScannerScript.scan_image(poster)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "scanner should read horizontal data strip"),
		assert_eq(texts[0] if texts.size() > 0 else "", text, "scanned strip text"),
	])


func test_scanner_reads_scaled_horizontal_data_strip_from_poster_rect() -> String:
	var text := "PTCGD1.STRIP.SCALED.12345678"
	var encoded := DeckShareDataStripScript.encode_text_to_image(text)
	var strip: Image = encoded.get("image", null)
	if strip == null:
		return "strip image should exist"
	var poster_size := Vector2i(1080, 620)
	var code_rect: Rect2i = DeckShareImageScannerScript._dynamic_poster_code_rect_for_tests(poster_size)
	strip.resize(code_rect.size.x, code_rect.size.y, Image.INTERPOLATE_NEAREST)
	var poster := Image.create(poster_size.x, poster_size.y, false, Image.FORMAT_RGBA8)
	poster.fill(Color(0.92, 0.94, 0.96, 1.0))
	poster.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), code_rect.position)
	poster.resize(720, 413, Image.INTERPOLATE_LANCZOS)
	var scanned := DeckShareImageScannerScript.scan_image(poster)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "scanner should read scaled horizontal data strip"),
		assert_eq(texts[0] if texts.size() > 0 else "", text, "scanned scaled strip text"),
	])


func test_scanner_reads_resized_jpg_code() -> String:
	var text := "PTCGD1.SCANNER.JPG.REENCODED.12345678"
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(text)
	var image: Image = encoded.get("image", null)
	if image == null:
		return "code image should exist"
	image.resize(840, 840, Image.INTERPOLATE_NEAREST)
	var bytes := image.save_jpg_to_buffer(0.92)
	var scanned := DeckShareImageScannerScript.scan_bytes(bytes)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "scanner should read resized JPG code"),
		assert_eq(texts[0] if texts.size() > 0 else "", text, "scanned JPG text"),
	])


func test_scanner_reads_code_from_poster_rect() -> String:
	var text := "PTCGD1.POSTER.RECT.12345678"
	var encoded := DeckShareQrEncoderScript.encode_text_to_image(text)
	var code: Image = encoded.get("image", null)
	if code == null:
		return "code image should exist"
	var poster := Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
	poster.fill(Color(0.92, 0.94, 0.96, 1.0))
	poster.blit_rect(code, Rect2i(Vector2i.ZERO, code.get_size()), DeckShareImageScannerScript.LEGACY_POSTER_QR_RECT.position)
	var scanned := DeckShareImageScannerScript.scan_image(poster)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "scanner should read code from generated poster rect"),
		assert_eq(texts[0] if texts.size() > 0 else "", text, "scanned poster text"),
	])


func test_scanner_reads_legacy_full_width_bottom_strip() -> String:
	var text := "PTCGD1.STRIP.LEGACY.BOTTOM.12345678"
	var encoded := DeckShareDataStripScript.encode_text_to_image(text)
	var strip: Image = encoded.get("image", null)
	if strip == null:
		return "strip image should exist"
	var code_rect: Rect2i = DeckShareImageScannerScript.LEGACY_FULL_WIDTH_BOTTOM_CODE_RECT
	strip.resize(code_rect.size.x, code_rect.size.y, Image.INTERPOLATE_NEAREST)
	var poster := Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
	poster.fill(Color(0.92, 0.94, 0.96, 1.0))
	poster.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), code_rect.position)
	var scanned := DeckShareImageScannerScript.scan_image(poster)
	var texts: PackedStringArray = scanned.get("texts", PackedStringArray())
	return run_checks([
		assert_true(bool(scanned.get("ok", false)), "scanner should keep reading legacy bottom data strips"),
		assert_eq(texts[0] if texts.size() > 0 else "", text, "scanned legacy bottom strip text"),
	])


func test_scanner_reports_clear_error_without_code() -> String:
	var image := Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.8, 0.8, 1.0))
	var scanned := DeckShareImageScannerScript.scan_image(image)
	return run_checks([
		assert_false(bool(scanned.get("ok", true)), "blank image should fail"),
		assert_true(str(scanned.get("error", "")).strip_edges() != "", "scanner should return an error"),
	])
