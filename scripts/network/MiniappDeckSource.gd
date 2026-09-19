## 官方小程序卡组代码、来源身份和响应校验。无网络或文件写入。
extends RefCounted

const PROVIDER := "miniapp"
const PAGE_URL := "https://tcg.mik.moe/tools/miniapp"
# Separate from website, Limitless and image-import IDs; exact in JSON numbers.
const LOCAL_ID_BASE := 0x1000000000000


static func valid_code(value: Variant) -> bool:
	if not value is String or value.length() != 18:
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_-]{18}$")
	return regex.search(value) != null


static func parse_code(input: String) -> String:
	var text := input.strip_edges().replace("\\_", "_")
	if valid_code(text):
		return text
	var regex := RegEx.new()
	regex.compile("(?i)^https?://tcg\\.mik\\.moe/tools/miniapp/?\\?([^#]+)(?:#.*)?$")
	var found := regex.search(text)
	if found == null:
		return ""
	var code := ""
	for part: String in found.get_string(1).split("&"):
		var pair := part.split("=", true, 1)
		if pair[0] == "code":
			if code != "" or pair.size() != 2:
				return ""
			code = pair[1].uri_decode()
	return code if valid_code(code) else ""


static func provider_ref(input: String) -> Dictionary:
	var code := parse_code(input)
	if code == "":
		return {}
	return {
		"provider": PROVIDER, "id": code,
		"local_id": local_id(code), "url": PAGE_URL + "?code=" + code,
	}


static func local_id(code: String) -> int:
	return LOCAL_ID_BASE + code.sha256_text().substr(0, 12).hex_to_int()


static func resolve_local_id(code: String, existing_decks: Array) -> int:
	var occupied := {}
	for deck: DeckData in existing_decks:
		if deck.source_provider == PROVIDER and deck.source_id == code:
			return deck.id
		occupied[deck.id] = true
	var candidate := local_id(code)
	for offset: int in range(1024):
		if not occupied.has(candidate + offset):
			return candidate + offset
	return -1


static func decode_response(body: PackedByteArray, code: String, existing_decks: Array = []) -> Dictionary:
	if not valid_code(code):
		return _failure("请输入官方小程序复制的 18 位卡组 ID。")
	if body.size() > 3 * 1024 * 1024:
		return _failure("卡组响应过大，请稍后重试。")
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return _failure("卡组服务返回的数据无法解析，请稍后重试。")
	var response: Dictionary = json.data
	if response.get("code") != 200:
		return _failure("未能读取小程序卡组，请检查 ID 是否有效，或重新复制后重试。")
	var raw: Variant = response.get("data")
	if not raw is Dictionary:
		return _failure("卡组服务没有返回卡组数据。")
	var data: Dictionary = raw
	if data.get("deckCode") != code:
		return _failure("返回的卡组 ID 与输入不一致，请重试。")
	var cards: Variant = data.get("cards")
	if not cards is Array or cards.is_empty() or cards.size() > 60:
		return _failure("卡组为空或卡牌列表不完整，请检查小程序中的卡组。")
	var identity_regex := RegEx.new()
	identity_regex.compile("^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$")
	var total := 0
	var seen := {}
	for entry: Variant in cards:
		if not entry is Dictionary:
			return _failure("卡组中存在无效的卡牌条目。")
		for key: String in ["setCode", "cardIndex", "cardName", "cardType", "effectId", "nameEn"]:
			if entry.has(key) and not entry[key] is String:
				return _failure("卡组中存在无效的卡牌字段。")
		var set_code: String = entry.get("setCode", "")
		var card_index: String = entry.get("cardIndex", "")
		if identity_regex.search(set_code) == null or identity_regex.search(card_index) == null or str(entry.get("cardName", "")).is_empty():
			return _failure("卡组中有卡牌缺少系列、卡号或名称，无法准确导入。")
		var count: Variant = entry.get("count")
		if (not count is int and not count is float) or not is_finite(float(count)) or float(count) != floor(float(count)) or count < 1 or count > 60:
			return _failure("卡组中有卡牌数量无效。")
		total += int(count)
		var uid := set_code + "_" + card_index
		if seen.has(uid):
			return _failure("卡组中存在重复卡牌条目，请重新导出。")
		seen[uid] = true
	if total > 60:
		return _failure("返回的卡组超过 60 张，请检查小程序中的卡组。")
	var variant: Variant = data.get("variant")
	if variant != null and (not variant is Dictionary or not variant.get("variantName", "") is String):
		return _failure("卡组名称数据无效。")
	var id := resolve_local_id(code, existing_decks)
	if id <= 0:
		return _failure("无法为卡组分配本地编号。")
	var deck := DeckData.from_api_response(id, data)
	deck.source_provider = PROVIDER
	deck.source_id = code
	deck.deck_code = code
	deck.source_url = PAGE_URL + "?code=" + code
	deck.deck_name = deck.variant_name if deck.variant_name != "" else "小程序卡组 " + code.substr(0, 6)
	for existing: DeckData in existing_decks:
		if existing.id == id and existing.source_provider == PROVIDER and existing.source_id == code and existing.deck_name.strip_edges() != "":
			deck.deck_name = existing.deck_name
			break
	return {"ok": true, "deck": deck, "error": ""}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
