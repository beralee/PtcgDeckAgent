extends TestBase

const Gate = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const FIXTURE := "res://tests/ptcgdap/fixtures/macos/e719-rules-0.4.0.ptcgai"

func test_only_uniform_lf_crlf_variants_match() -> String:
	var lf := "{\n  \"hp\": 70\n}\n"
	var crlf := lf.replace("\n", "\r\n")
	var checks: Array[String] = []
	for pair: Array in [[lf, lf], [crlf, crlf], [lf, crlf], [crlf, lf]]:
		checks.append(assert_true(Gate._matches_source_raw_hash(str(pair[0]).to_utf8_buffer(), str(pair[1]).sha256_text().to_upper())))
	for changed: String in [lf + " ", lf.replace("70", "80"), lf.replace("\n", "\r"), lf.replace("{\n", "{\r\n")]:
		checks.append(assert_false(Gate._matches_source_raw_hash(changed.to_utf8_buffer(), crlf.sha256_text().to_upper())))
	return run_checks(checks)

func _payloads() -> Dictionary:
	var archive := ZIPReader.new()
	if archive.open(FIXTURE) != OK: return {}
	var result := {}
	for path: String in ["deck/deck.csv", "deck/deck_manifest.json"]:
		result[path] = archive.read_file(path)
	archive.close()
	return result

func test_windows_download_maps_all_sixty_cards_on_native_checkout() -> String:
	var result := Gate.build(_payloads())
	return run_checks([assert_true(result.get("ok", false), "Windows CRLF receipt must map on a LF checkout"),
		assert_eq(result.get("local_deck", []).size(), 28)])

func test_reformatted_source_digest_is_rejected_even_with_matching_card_content() -> String:
	var payloads := _payloads()
	var manifest: Dictionary = JSON.parse_string(payloads["deck/deck_manifest.json"].get_string_from_utf8())
	var card := FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_007.json")
	manifest.cards[0].source_raw_sha256 = (card + " ").sha256_text().to_upper()
	payloads["deck/deck_manifest.json"] = JSON.stringify(manifest).to_utf8_buffer()
	return assert_false(Gate.build(payloads).get("ok", true), "Unrelated whitespace is not newline portability")

func test_canonical_mismatch_stays_rejected_even_with_exact_raw_hash() -> String:
	var payloads := _payloads()
	var manifest: Dictionary = JSON.parse_string(payloads["deck/deck_manifest.json"].get_string_from_utf8())
	manifest.cards[0].source_raw_sha256 = FileAccess.get_sha256("res://data/bundled_user/cards/CSV10C_007.json").to_upper()
	manifest.cards[0].source_canonical_sha256 = "A".repeat(64)
	payloads["deck/deck_manifest.json"] = JSON.stringify(manifest).to_utf8_buffer()
	return assert_false(Gate.build(payloads).get("ok", true), "Canonical card identity remains mandatory")
