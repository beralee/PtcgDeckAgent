## DeckImporter 单元测试（仅测试纯函数部分，不测试网络）
class_name TestDeckImporter
extends TestBase


func test_parse_deck_id_full_url() -> String:
	var id := DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/574793")
	return assert_eq(id, 574793, "完整URL解析")


func test_parse_deck_id_with_query() -> String:
	var id := DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/574793?tab=cards")
	return assert_eq(id, 574793, "带查询参数URL解析")


func test_parse_deck_id_number_only() -> String:
	var id := DeckImporter.parse_deck_id("574793")
	return assert_eq(id, 574793, "纯数字解析")


func test_parse_deck_id_number_with_spaces() -> String:
	var id := DeckImporter.parse_deck_id("  574793  ")
	return assert_eq(id, 574793, "带空格数字解析")


func test_parse_deck_id_invalid() -> String:
	var id := DeckImporter.parse_deck_id("not_a_valid_url")
	return assert_eq(id, -1, "无效输入返回-1")


func test_parse_deck_id_empty() -> String:
	var id := DeckImporter.parse_deck_id("")
	return assert_eq(id, -1, "空字符串返回-1")


func test_parse_deck_id_partial_url() -> String:
	var id := DeckImporter.parse_deck_id("decks/list/12345")
	return assert_eq(id, 12345, "部分URL解析")


func test_parse_deck_id_different_numbers() -> String:
	return run_checks([
		assert_eq(DeckImporter.parse_deck_id("1"), 1, "ID=1"),
		assert_eq(DeckImporter.parse_deck_id("999999"), 999999, "ID=999999"),
		assert_eq(DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/1"), 1, "URL ID=1"),
	])


func test_imported_card_uses_image_metadata_defaults() -> String:
	var json := {
		"name": "妙蛙种子",
		"cardType": "Pokemon",
		"setCode": "151C",
		"cardIndex": "001",
	}
	var card := CardData.from_api_json(json)
	return run_checks([
		assert_eq(card.image_url, "https://tcg.mik.moe/static/img/151C/001.png", "卡图URL默认值"),
		assert_eq(card.image_local_path, "user://cards/images/151C/001.png", "卡图本地路径默认值"),
	])

func test_web_deck_import_headers_avoid_forbidden_user_agent() -> String:
	var web_headers := DeckImporter.request_headers_for_runtime("Web", {}, "web")
	var web_android_headers := DeckImporter.request_headers_for_runtime("", {"web_android": true}, "")
	var android_headers := DeckImporter.request_headers_for_runtime("Android", {"android": true}, "")
	var windows_headers := DeckImporter.request_headers_for_runtime("Windows", {}, "")
	return run_checks([
		assert_true(_headers_contain_prefix(web_headers, "Content-Type:"), "Web deck import should keep JSON content type"),
		assert_false(_headers_contain_prefix(web_headers, "User-Agent:"), "Web deck import must not set the browser-forbidden User-Agent header"),
		assert_false(_headers_contain_prefix(web_android_headers, "User-Agent:"), "Android browser deck import must use the Web header branch"),
		assert_true(_headers_contain_prefix(android_headers, "User-Agent:"), "Native deck import should keep the client User-Agent header"),
		assert_true(_headers_contain_prefix(windows_headers, "User-Agent:"), "Desktop deck import should keep the client User-Agent header"),
	])


func test_web_card_image_sync_skips_remote_downloads() -> String:
	var web_headers := CardImageDownloader.request_headers_for_runtime("Web", {}, "web")
	var web_android_headers := CardImageDownloader.request_headers_for_runtime("", {"web_android": true}, "")
	var android_headers := CardImageDownloader.request_headers_for_runtime("Android", {"android": true}, "")
	var windows_headers := CardImageDownloader.request_headers_for_runtime("Windows", {}, "")
	return run_checks([
		assert_false(CardImageDownloader.should_sync_remote_images_for_runtime("Web", {}, "web"), "Web card image sync should not try cross-origin PNG reads"),
		assert_false(CardImageDownloader.should_sync_remote_images_for_runtime("", {"web_android": true}, ""), "Android browser card image sync should use the Web skip branch"),
		assert_true(CardImageDownloader.should_sync_remote_images_for_runtime("Android", {"android": true}, ""), "Native card image sync should keep remote downloads"),
		assert_true(CardImageDownloader.should_sync_remote_images_for_runtime("Windows", {}, ""), "Desktop card image sync should keep remote downloads"),
		assert_false(_headers_contain_prefix(web_headers, "User-Agent:"), "Web card image sync must not set User-Agent"),
		assert_false(_headers_contain_prefix(web_android_headers, "User-Agent:"), "Android browser card image sync must use the Web header branch"),
		assert_true(_headers_contain_prefix(android_headers, "User-Agent:"), "Native card image sync should keep User-Agent"),
		assert_true(_headers_contain_prefix(windows_headers, "User-Agent:"), "Desktop card image sync should keep User-Agent"),
	])


func _headers_contain_prefix(headers: PackedStringArray, prefix: String) -> bool:
	for header: String in headers:
		if header.begins_with(prefix):
			return true
	return false
