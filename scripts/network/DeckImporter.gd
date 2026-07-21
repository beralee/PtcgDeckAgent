## 卡组导入器 - 从 tcg.mik.moe API 获取卡组和卡牌数据
class_name DeckImporter
extends Node

## API 基地址
const API_BASE := "https://tcg.mik.moe"
const DECK_DETAIL_URL := API_BASE + "/api/v3/deck/detail"
const CARD_DETAIL_URL := API_BASE + "/api/v3/card/card-detail"
const CARD_IMAGE_CACHE_SERVICE := preload("res://scripts/card_images/CardImageCacheService.gd")
const LIMITLESS_CARD_PARSER := preload("res://scripts/network/LimitlessCardParser.gd")
const LIMITLESS_CARD_RESOLVER := preload("res://scripts/network/LimitlessCardResolver.gd")

## 导入进度信号
signal import_progress(current: int, total: int, message: String)
## 导入完成信号
signal import_completed(deck: DeckData, errors: PackedStringArray)
## 导入失败信号
signal import_failed(error_message: String)

## HTTP 请求节点
var _http_request: HTTPRequest = null
var _image_downloader = null
var _pending_deck: DeckData = null
var _pending_import_errors: PackedStringArray = PackedStringArray()


static func request_headers_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _is_web_runtime_for_context(os_name, feature_flags, display_server_name):
		return headers
	headers.append("User-Agent: PTCGTrain/1.0")
	return headers


static func _is_web_runtime_for_context(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	var resolved_display := display_server_name.strip_edges().to_lower()
	var flags := feature_flags
	if flags.is_empty() and os_name == "" and display_server_name == "":
		flags = {
			"web": OS.has_feature("web"),
			"web_android": OS.has_feature("web_android"),
			"web_ios": OS.has_feature("web_ios"),
		}
		resolved_os = OS.get_name().strip_edges().to_lower()
		resolved_display = DisplayServer.get_name().strip_edges().to_lower()
	if resolved_os in ["web", "html5"] or resolved_display in ["web", "html5"]:
		return true
	for feature: String in ["web", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


static func parse_provider_ref(input: String) -> Dictionary:
	var text := input.strip_edges()
	if text.is_valid_int():
		var deck_id := int(text)
		return {
			"provider": "tcg_mik",
			"id": deck_id,
			"local_id": deck_id,
			"url": "https://tcg.mik.moe/decks/list/%d" % deck_id,
		}

	var limitless_regex := RegEx.new()
	limitless_regex.compile("(?i)^(?:https?://)?(?:www\\.)?limitlesstcg\\.com/decks/list/(\\d+)(?:[/?#].*)?$")
	var limitless_match := limitless_regex.search(text)
	if limitless_match != null:
		var limitless_id := int(limitless_match.get_string(1))
		return {
			"provider": "limitless",
			"id": limitless_id,
			"local_id": LIMITLESS_CARD_PARSER.limitless_deck_local_id(limitless_id),
			"url": "https://limitlesstcg.com/decks/list/%d" % limitless_id,
		}

	var tcg_regex := RegEx.new()
	tcg_regex.compile("(?i)^(?:https?://)?tcg\\.mik\\.moe/decks/list/(\\d+)(?:[/?#].*)?$")
	var tcg_match := tcg_regex.search(text)
	if tcg_match != null:
		var tcg_id := int(tcg_match.get_string(1))
		return {
			"provider": "tcg_mik",
			"id": tcg_id,
			"local_id": tcg_id,
			"url": "https://tcg.mik.moe/decks/list/%d" % tcg_id,
		}

	return {
		"provider": "",
		"id": -1,
		"local_id": -1,
		"url": text,
	}


static func generated_limitless_card_has_source_collision(existing: CardData, generated: CardData) -> bool:
	if existing == null or generated == null:
		return false
	if str(generated.source_provider).strip_edges().to_lower() != "limitless":
		return false
	if existing.get_uid() != generated.get_uid():
		return false
	if str(existing.source_provider).strip_edges().to_lower() != "limitless":
		return true
	return (
		str(existing.source_set_code).strip_edges().to_upper() != str(generated.source_set_code).strip_edges().to_upper()
		or str(existing.source_card_index).strip_edges().to_upper() != str(generated.source_card_index).strip_edges().to_upper()
		or str(existing.source_language).strip_edges().to_lower() != str(generated.source_language).strip_edges().to_lower()
	)


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 15.0
	add_child(_http_request)

	_image_downloader = CARD_IMAGE_CACHE_SERVICE.new()
	add_child(_image_downloader)
	_image_downloader.image_progress.connect(_on_image_sync_progress)
	_image_downloader.job_completed.connect(_on_image_sync_completed)


## 从 tcg.mik.moe 链接中提取 deckId
static func parse_deck_id(url: String) -> int:
	# 格式: https://tcg.mik.moe/decks/list/<id> 或 https://tcg.mik.moe/decks/list/<id>?...
	var regex := RegEx.new()
	regex.compile("(?i)(?:^|tcg\\.mik\\.moe/)decks/list/(\\d+)")
	var result := regex.search(url)
	if result:
		return int(result.get_string(1))
	# 也允许直接输入数字
	if url.strip_edges().is_valid_int():
		return int(url.strip_edges())
	return -1


## 导入卡组完整流程
func import_deck(url_or_id: String) -> void:
	var ref := parse_provider_ref(url_or_id)
	var provider := str(ref.get("provider", ""))
	if provider == "limitless":
		import_progress.emit(0, 1, "Fetching Limitless deck data...")
		_fetch_limitless_deck_detail(ref)
		return

	if provider != "tcg_mik":
		import_failed.emit("Unsupported deck URL or deck ID")
		return

	var deck_id := int(ref.get("id", -1))
	if deck_id <= 0:
		import_failed.emit("Unable to parse deck ID from tcg.mik.moe deck URL")
		return

	import_progress.emit(0, 1, "Fetching deck data...")
	_fetch_deck_detail(deck_id)


## 获取卡组详情
func _fetch_limitless_deck_detail(ref: Dictionary) -> void:
	var source_url := str(ref.get("url", ""))
	if source_url == "":
		import_failed.emit("Limitless deck URL is empty")
		return
	var callback := _on_limitless_deck_response.bind(ref)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(source_url, request_headers_for_runtime(), HTTPClient.METHOD_GET)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		import_failed.emit("Limitless deck request failed: %d" % err)


func _on_limitless_deck_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, ref: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		import_failed.emit("Limitless network request failed (result=%d)" % result)
		return
	if response_code != 200:
		import_failed.emit("Limitless deck returned HTTP %d" % response_code)
		return

	var parsed := LIMITLESS_CARD_PARSER.parse_deck_html(body.get_string_from_utf8(), str(ref.get("url", "")))
	var deck := _deck_from_limitless_parse(parsed, ref)
	var errors := deck.validate()
	var entries := deck.cards.duplicate(true)
	_fetch_limitless_cards_sequentially(deck, entries, 0, errors)


func _deck_from_limitless_parse(parsed: Dictionary, ref: Dictionary) -> DeckData:
	var deck := DeckData.new()
	deck.id = int(parsed.get("id", ref.get("local_id", 0)))
	deck.deck_name = str(parsed.get("deck_name", "Limitless %s" % str(ref.get("id", "")))).strip_edges()
	if deck.deck_name == "":
		deck.deck_name = "Limitless %s" % str(ref.get("id", ""))
	deck.source_url = str(parsed.get("source_url", ref.get("url", "")))
	deck.source_provider = "limitless"
	deck.source_id = str(parsed.get("source_id", ref.get("id", "")))
	deck.import_date = Time.get_datetime_string_from_system()
	deck.updated_at = int(Time.get_unix_time_from_system() * 1000.0)
	var cards_raw: Variant = parsed.get("cards", [])
	var cards_array: Array = cards_raw if cards_raw is Array else []
	deck.cards.clear()
	for entry: Variant in cards_array:
		if entry is Dictionary:
			deck.cards.append((entry as Dictionary).duplicate(true))
	deck.total_cards = int(parsed.get("total_cards", 0))
	return deck


func _fetch_limitless_cards_sequentially(deck: DeckData, entries: Array, index: int, errors: PackedStringArray) -> void:
	if index >= entries.size():
		_start_image_sync(deck, errors)
		return

	var entry_raw: Variant = entries[index]
	var entry: Dictionary = entry_raw if entry_raw is Dictionary else {}
	var source_set := str(entry.get("source_set_code", ""))
	var source_index := str(entry.get("source_card_index", ""))
	if source_set == "" or source_index == "":
		errors.append("Limitless card entry is missing set or number")
		call_deferred("_fetch_limitless_cards_sequentially", deck, entries, index + 1, errors)
		return

	if _try_resolve_limitless_card_entry_from_catalog(deck, entry, errors):
		import_progress.emit(index + 1, entries.size(), "Resolved Limitless card %d/%d from catalog..." % [index + 1, entries.size()])
		call_deferred("_fetch_limitless_cards_sequentially", deck, entries, index + 1, errors)
		return

	import_progress.emit(index, entries.size(), "Fetching Limitless card %d/%d..." % [index + 1, entries.size()])
	var callback := _on_limitless_card_response.bind(deck, entries, index, errors, entry)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(LIMITLESS_CARD_PARSER.card_url(source_set, source_index), request_headers_for_runtime(), HTTPClient.METHOD_GET)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		errors.append("Limitless card %s/%s request failed: %d" % [source_set, source_index, err])
		_resolve_limitless_card_entry(deck, entry, entry, errors)
		_fetch_limitless_cards_sequentially(deck, entries, index + 1, errors)


func _on_limitless_card_response(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray,
	deck: DeckData, entries: Array, index: int, errors: PackedStringArray, entry: Dictionary
) -> void:
	var parsed_card := entry.duplicate(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		parsed_card = LIMITLESS_CARD_PARSER.parse_card_html(body.get_string_from_utf8(), str(entry.get("source_url", "")))
	else:
		errors.append("Limitless card %s/%s fetch failed (HTTP %d)" % [
			str(entry.get("source_set_code", "")),
			str(entry.get("source_card_index", "")),
			response_code,
		])
	_resolve_limitless_card_entry(deck, entry, parsed_card, errors)
	_fetch_limitless_cards_sequentially(deck, entries, index + 1, errors)


func _try_resolve_limitless_card_entry_from_catalog(deck: DeckData, entry: Dictionary, errors: PackedStringArray) -> bool:
	if not CardDatabase.has_method("find_cards_by_source_ref"):
		return false
	var source_set := str(entry.get("source_set_code", "")).strip_edges()
	var source_index := str(entry.get("source_card_index", "")).strip_edges()
	var candidates: Array = CardDatabase.find_cards_by_source_ref(source_set, source_index)
	if candidates.is_empty():
		return false
	var resolved := LIMITLESS_CARD_RESOLVER.resolve_card(entry, candidates)
	var resolver_errors: Array = resolved.get("errors", []) if resolved.get("errors", []) is Array else []
	if not resolver_errors.is_empty():
		return false
	if bool(resolved.get("generated", false)):
		return false
	var card: CardData = resolved.get("card", null)
	if card == null:
		return false
	_try_register_duplicate_effect_alias(card)
	_update_limitless_deck_entry(deck, entry, card, str(resolved.get("resolved_via", "catalog_source_ref")))
	if CardImplementationStatus.is_unimplemented(card):
		errors.append("Limitless card %s/%s is not rule-runnable: %s" % [
			source_set,
			source_index,
			CardImplementationStatus.get_reason(card),
		])
	return true


func _resolve_limitless_card_entry(deck: DeckData, entry: Dictionary, parsed_card: Dictionary, errors: PackedStringArray) -> void:
	var resolved := LIMITLESS_CARD_RESOLVER.resolve_card(parsed_card, CardDatabase.get_all_cards())
	var resolver_errors: Array = resolved.get("errors", [])
	if not resolver_errors.is_empty():
		for resolver_error: Variant in resolver_errors:
			errors.append("Limitless card %s/%s resolver failed: %s" % [
				str(entry.get("source_set_code", "")),
				str(entry.get("source_card_index", "")),
				str(resolver_error),
			])
		return
	var card: CardData = resolved.get("card", null)
	if card == null:
		errors.append("Limitless card %s/%s could not be resolved" % [
			str(entry.get("source_set_code", "")),
			str(entry.get("source_card_index", "")),
		])
		return
	if bool(resolved.get("generated", false)):
		var existing := CardDatabase.get_card(card.set_code, card.card_index)
		if generated_limitless_card_has_source_collision(existing, card):
			errors.append("Limitless generated card %s/%s conflicts with existing source metadata" % [card.set_code, card.card_index])
			return
		CardDatabase.cache_card(card)
	else:
		_try_register_duplicate_effect_alias(card)
	_update_limitless_deck_entry(deck, entry, card, str(resolved.get("resolved_via", "")))
	if CardImplementationStatus.is_unimplemented(card):
		errors.append("Limitless card %s/%s is not rule-runnable: %s" % [
			str(entry.get("source_set_code", "")),
			str(entry.get("source_card_index", "")),
			CardImplementationStatus.get_reason(card),
		])


func _update_limitless_deck_entry(deck: DeckData, source_entry: Dictionary, card: CardData, resolved_via: String) -> void:
	for i in range(deck.cards.size()):
		var entry: Dictionary = deck.cards[i]
		if str(entry.get("source_set_code", "")) != str(source_entry.get("source_set_code", "")):
			continue
		if str(entry.get("source_card_index", "")) != str(source_entry.get("source_card_index", "")):
			continue
		entry["set_code"] = card.set_code
		entry["card_index"] = card.card_index
		entry["card_type"] = card.card_type
		entry["name"] = card.display_name()
		entry["name_en"] = card.name_en
		entry["effect_id"] = card.effect_id
		entry["resolved_via"] = resolved_via
		entry["source_provider"] = str(source_entry.get("source_provider", "limitless"))
		entry["source_set_code"] = str(source_entry.get("source_set_code", entry.get("source_set_code", "")))
		entry["source_card_index"] = str(source_entry.get("source_card_index", entry.get("source_card_index", "")))
		entry["source_language"] = str(source_entry.get("source_language", entry.get("source_language", "en")))
		entry["source_url"] = str(source_entry.get("source_url", entry.get("source_url", "")))
		entry["source_name"] = str(source_entry.get("source_name", source_entry.get("name", entry.get("source_name", ""))))
		deck.cards[i] = entry
		return


func _fetch_deck_detail(deck_id: int) -> void:
	var body := JSON.stringify({"deckId": deck_id})
	var headers := request_headers_for_runtime()

	var callback := _on_deck_detail_response.bind(deck_id)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(DECK_DETAIL_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		import_failed.emit("网络请求失败，错误码: %d" % err)


func _on_deck_detail_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, deck_id: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		import_failed.emit("网络连接失败 (result=%d)" % result)
		return

	if response_code != 200:
		import_failed.emit("服务器返回错误 (HTTP %d)" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		import_failed.emit("响应数据解析失败")
		return

	var resp: Dictionary = json.data
	if resp.get("code", 0) != 200:
		import_failed.emit("API 错误: %s" % resp.get("msg", "未知错误"))
		return

	var data_raw: Variant = resp.get("data")
	var data: Dictionary = data_raw if data_raw is Dictionary else {}
	var deck := DeckData.from_api_response(deck_id, data)

	# 验证基本合法性
	var errors := deck.validate()

	# 开始逐张获取卡牌详情
	var card_keys := deck.get_card_keys()
	_fetch_cards_sequentially(deck, card_keys, 0, errors)


## 顺序获取所有卡牌详情
func _fetch_cards_sequentially(deck: DeckData, keys: Array[Dictionary], index: int, errors: PackedStringArray) -> void:
	if index >= keys.size():
		_start_image_sync(deck, errors)
		return

	var key: Dictionary = keys[index]
	var set_code: String = key["set_code"]
	var card_index: String = key["card_index"]

	import_progress.emit(index, keys.size(), "正在获取卡牌 %d/%d..." % [index + 1, keys.size()])

	# 检查本地缓存
	if CardDatabase.has_card(set_code, card_index):
		var cached_card := CardDatabase.get_card(set_code, card_index)
		_try_register_duplicate_effect_alias(cached_card)
		call_deferred("_fetch_cards_sequentially", deck, keys, index + 1, errors)
		return

	# 从 API 获取
	var body := JSON.stringify({"setCode": set_code, "cardIndex": card_index})
	var headers := request_headers_for_runtime()

	var callback := _on_card_detail_response.bind(deck, keys, index, errors, set_code, card_index)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(CARD_DETAIL_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		errors.append("获取卡牌 %s/%s 失败: 网络错误" % [set_code, card_index])
		_fetch_cards_sequentially(deck, keys, index + 1, errors)


func _on_card_detail_response(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray,
	deck: DeckData, keys: Array[Dictionary], index: int, errors: PackedStringArray,
	set_code: String, card_index: String
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var resp: Dictionary = json.data
			if resp.get("code", 0) == 200:
				var data_raw: Variant = resp.get("data")
				var card_json: Dictionary = data_raw if data_raw is Dictionary else {}
				var card_data := CardData.from_api_json(card_json)
				CardDatabase.cache_card(card_data)
				_try_register_duplicate_effect_alias(card_data)
			else:
				errors.append("获取卡牌 %s/%s 失败: %s" % [set_code, card_index, resp.get("msg", "")])
		else:
			errors.append("解析卡牌 %s/%s 数据失败" % [set_code, card_index])
	else:
		errors.append("获取卡牌 %s/%s 网络错误" % [set_code, card_index])

	_fetch_cards_sequentially(deck, keys, index + 1, errors)


func _try_register_duplicate_effect_alias(card: CardData) -> void:
	if card == null:
		return
	var result := CardDatabase.try_register_duplicate_effect_alias(card)
	if bool(result.get("applied", false)) and not bool(result.get("already_registered", false)):
		print("DeckImporter: applied duplicate card effect alias %s -> %s" % [
			str(result.get("alias_effect_id", "")),
			str(result.get("source_effect_id", "")),
		])


func _start_image_sync(deck: DeckData, errors: PackedStringArray) -> void:
	var cards_to_sync: Array[CardData] = []
	for key: Dictionary in deck.get_card_keys():
		var set_code: String = key.get("set_code", "")
		var card_index: String = key.get("card_index", "")
		var card := CardDatabase.get_card(set_code, card_index)
		if card == null:
			errors.append("卡牌 %s/%s 未缓存，跳过卡图同步" % [set_code, card_index])
			continue
		cards_to_sync.append(card)

	if cards_to_sync.is_empty():
		import_progress.emit(deck.cards.size(), deck.cards.size(), "导入完成!")
		import_completed.emit(deck, errors)
		return

	_pending_deck = deck
	_pending_import_errors = PackedStringArray()
	for err: String in errors:
		_pending_import_errors.append(err)

	import_progress.emit(0, cards_to_sync.size(), "正在同步卡图...")
	_image_downloader.ensure_cards(cards_to_sync, {"priority": 5, "reason": "deck_import"})


func _on_image_sync_progress(_job_id: String, current: int, total: int) -> void:
	import_progress.emit(current, total, "正在同步本卡组卡图 %d/%d" % [current, total])


func _on_image_sync_completed(_job_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if _pending_deck == null:
		return

	for err: String in errors:
		_pending_import_errors.append(err)

	var total := int(stats.get("total", 0))
	var deck := _pending_deck
	var combined_errors := _pending_import_errors

	_pending_deck = null
	_pending_import_errors = PackedStringArray()

	import_progress.emit(total, total, "导入完成!")
	import_completed.emit(deck, combined_errors)


func _on_image_sync_failed(error_message: String) -> void:
	if _pending_deck == null:
		return

	_pending_import_errors.append("卡图同步失败: %s" % error_message)
	var deck := _pending_deck
	var combined_errors := _pending_import_errors

	_pending_deck = null
	_pending_import_errors = PackedStringArray()

	import_completed.emit(deck, combined_errors)
