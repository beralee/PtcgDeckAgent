class_name DeckRecommendationStore
extends RefCounted

const CACHE_PATH := "user://deck_recommendations/cache.json"
const SCHEMA_VERSION := 1
const MAX_CACHE_ITEMS := 10
const MAX_WHY_PLAY_ITEMS := 3
const MAX_DETAIL_SECTIONS := 8
const MAX_DETAIL_BULLETS := 5
const MAX_ID_LENGTH := 96
const MAX_TITLE_LENGTH := 96
const MAX_SUMMARY_LENGTH := 140
const MAX_BODY_LENGTH := 520
const MAX_URL_LENGTH := 260

var cache_path: String = CACHE_PATH
var _cache: Dictionary = _empty_cache()


func set_cache_path(path: String) -> void:
	cache_path = path


func load_cache() -> Dictionary:
	var cache := _empty_cache()
	if FileAccess.file_exists(cache_path):
		var raw_text := FileAccess.get_file_as_string(cache_path)
		var parsed: Variant = JSON.parse_string(raw_text)
		if parsed is Dictionary:
			cache = _normalize_cache(parsed as Dictionary)
	_cache = cache
	return _cache.duplicate(true)


func save_cache(cache: Dictionary = {}) -> bool:
	if not cache.is_empty():
		_cache = _normalize_cache(cache)
	var dir_path := ProjectSettings.globalize_path(cache_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		return false
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_cache, "\t"))
	file.close()
	return true


func get_items() -> Array[Dictionary]:
	if _cache.is_empty():
		load_cache()
	var items: Array[Dictionary] = []
	for raw_item: Variant in _cache.get("items", []):
		if raw_item is Dictionary:
			items.append((raw_item as Dictionary).duplicate(true))
	return items


func get_current_id() -> String:
	if _cache.is_empty():
		load_cache()
	return str(_cache.get("current_id", ""))


func set_current_id(recommendation_id: String) -> void:
	if _cache.is_empty():
		load_cache()
	_cache["current_id"] = _clean_text(recommendation_id, MAX_ID_LENGTH)
	_cache["updated_at"] = int(Time.get_unix_time_from_system())


func upsert_item(raw_item: Dictionary, make_current: bool = true) -> Dictionary:
	var item := normalize_recommendation(raw_item)
	if item.is_empty():
		return {}
	if _cache.is_empty():
		load_cache()
	var items: Array = _cache.get("items", [])
	var filtered: Array = []
	var item_id := str(item.get("id", ""))
	for existing_raw: Variant in items:
		if existing_raw is not Dictionary:
			continue
		var existing := existing_raw as Dictionary
		if str(existing.get("id", "")) == item_id:
			continue
		filtered.append(existing)
	filtered.push_front(item)
	while filtered.size() > MAX_CACHE_ITEMS:
		filtered.pop_back()
	_cache["schema_version"] = SCHEMA_VERSION
	_cache["items"] = filtered
	_cache["updated_at"] = int(Time.get_unix_time_from_system())
	if make_current:
		_cache["current_id"] = item_id
	return item.duplicate(true)


func get_current_or_fallback(fallbacks: Array[Dictionary] = []) -> Dictionary:
	if _cache.is_empty():
		load_cache()
	var current_id := str(_cache.get("current_id", ""))
	for item: Dictionary in get_items():
		if current_id != "" and str(item.get("id", "")) == current_id:
			return item.duplicate(true)
	var first_cached := _first_valid_from(get_items())
	if not first_cached.is_empty():
		return first_cached
	return _first_valid_from(fallbacks)


func get_next_cached(current_id: String) -> Dictionary:
	var items := get_items()
	if items.size() <= 1:
		return {}
	var current_index := -1
	for i: int in items.size():
		if str(items[i].get("id", "")) == current_id:
			current_index = i
			break
	if current_index < 0:
		return items[0].duplicate(true)
	for step: int in range(1, items.size()):
		var next_index := (current_index + step) % items.size()
		if str(items[next_index].get("id", "")) != current_id:
			return items[next_index].duplicate(true)
	return {}


func get_next_from_list(current_id: String, items: Array[Dictionary]) -> Dictionary:
	if items.is_empty():
		return {}
	if current_id == "":
		return items[0].duplicate(true)
	for i: int in items.size():
		if str(items[i].get("id", "")) != current_id:
			return items[i].duplicate(true)
	return items[0].duplicate(true)


static func normalize_recommendation(raw: Dictionary) -> Dictionary:
	var item_id := _clean_text(raw.get("id", raw.get("slug", "")), MAX_ID_LENGTH)
	var import_url := _clean_text(raw.get("import_url", raw.get("source_url", "")), MAX_URL_LENGTH)
	var import_deck_id := DeckImporter.parse_deck_id(import_url)
	var deck_id := _coerce_deck_id(raw.get("deck_id", 0), import_url)
	var deck_name := _clean_text(raw.get("deck_name", ""), MAX_TITLE_LENGTH)
	var title := _clean_text(raw.get("title", ""), MAX_TITLE_LENGTH)
	var style_summary := _clean_text(raw.get("style_summary", raw.get("summary", "")), MAX_SUMMARY_LENGTH)
	if item_id == "" or deck_name == "" or import_url == "" or import_deck_id <= 0 or deck_id <= 0:
		return {}
	if title == "" and style_summary == "":
		return {}

	var result := {
		"id": item_id,
		"deck_id": deck_id,
		"deck_name": deck_name,
		"title": title,
		"style_summary": style_summary,
		"why_play": _normalize_string_array(raw.get("why_play", []), MAX_WHY_PLAY_ITEMS, MAX_SUMMARY_LENGTH),
		"best_for": _clean_text(raw.get("best_for", ""), MAX_SUMMARY_LENGTH),
		"pilot_tip": _clean_text(raw.get("pilot_tip", ""), MAX_SUMMARY_LENGTH),
		"source": _normalize_source(raw.get("source", {})),
		"import_url": import_url,
		"detail": _normalize_detail(raw.get("detail", {})),
		"generated_at": _clean_text(raw.get("generated_at", ""), MAX_TITLE_LENGTH),
	}
	return result


static func normalize_embedded_article(article: Dictionary) -> Dictionary:
	var hero := _as_dictionary(article.get("hero", {}))
	var source := _as_dictionary(article.get("source", {}))
	var import_url := _extract_embedded_import_url(article)
	var deck_id := _extract_embedded_deck_id(article, import_url)
	var deck_name := _clean_text(hero.get("deck_name", "推荐卡组"), MAX_TITLE_LENGTH)
	var source_label := _embedded_source_label(source)
	var raw := {
		"id": _clean_text(article.get("slug", "embedded-%d" % deck_id), MAX_ID_LENGTH),
		"deck_id": deck_id,
		"deck_name": deck_name,
		"title": _clean_text(hero.get("title", deck_name), MAX_TITLE_LENGTH),
		"style_summary": _clean_text(hero.get("thesis", "这套牌值得作为近期环境样本试一试。"), MAX_SUMMARY_LENGTH),
		"why_play": _extract_embedded_why_play(article),
		"best_for": _clean_text("适合想理解近期环境取舍，并喜欢从赛事样本里试新思路的玩家。", MAX_SUMMARY_LENGTH),
		"pilot_tip": _extract_embedded_pilot_tip(article),
		"source": {
			"label": source_label,
			"city": source.get("city", ""),
			"date": source.get("date", ""),
			"players": source.get("players", 0),
			"url": "",
		},
		"import_url": import_url,
		"detail": _embedded_detail(article),
		"generated_at": _clean_text(article.get("generated_at", ""), MAX_TITLE_LENGTH),
	}
	return normalize_recommendation(raw)


static func _normalize_cache(raw: Dictionary) -> Dictionary:
	var cache := _empty_cache()
	cache["current_id"] = _clean_text(raw.get("current_id", ""), MAX_ID_LENGTH)
	cache["updated_at"] = int(raw.get("updated_at", 0))
	var items: Array = []
	var raw_items: Variant = raw.get("items", [])
	if raw_items is Array:
		for raw_item: Variant in raw_items as Array:
			if raw_item is not Dictionary:
				continue
			var item := normalize_recommendation(raw_item as Dictionary)
			if item.is_empty():
				continue
			var duplicate := false
			for existing: Dictionary in items:
				if str(existing.get("id", "")) == str(item.get("id", "")):
					duplicate = true
					break
			if duplicate:
				continue
			items.append(item)
			if items.size() >= MAX_CACHE_ITEMS:
				break
	cache["items"] = items
	if str(cache.get("current_id", "")) == "" and not items.is_empty():
		cache["current_id"] = str((items[0] as Dictionary).get("id", ""))
	return cache


static func _empty_cache() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"current_id": "",
		"items": [],
		"updated_at": 0,
	}


static func _first_valid_from(items: Array[Dictionary]) -> Dictionary:
	for item: Dictionary in items:
		var normalized := normalize_recommendation(item)
		if not normalized.is_empty():
			return normalized
	return {}


static func _clean_text(value: Variant, max_length: int) -> String:
	var text := str(value).strip_edges()
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	while "\n\n\n" in text:
		text = text.replace("\n\n\n", "\n\n")
	if max_length > 0 and text.length() > max_length:
		text = text.left(max_length).strip_edges()
	return text


static func _normalize_string_array(value: Variant, max_items: int, max_length: int) -> Array[String]:
	var result: Array[String] = []
	var raw_items: Array = value if value is Array else []
	for raw_item: Variant in raw_items:
		var text := _clean_text(raw_item, max_length)
		if text == "":
			continue
		result.append(text)
		if result.size() >= max_items:
			break
	return result


static func _normalize_source(value: Variant) -> Dictionary:
	var source := _as_dictionary(value)
	return {
		"label": _clean_text(source.get("label", ""), MAX_TITLE_LENGTH),
		"city": _clean_text(source.get("city", ""), 32),
		"date": _clean_text(source.get("date", ""), 32),
		"players": maxi(0, int(source.get("players", 0))),
		"url": _clean_source_url(source.get("url", "")),
	}


static func _normalize_detail(value: Variant) -> Dictionary:
	var detail := _as_dictionary(value)
	var sections: Array[Dictionary] = []
	var raw_sections: Variant = detail.get("sections", [])
	if raw_sections is Array:
		for raw_section: Variant in raw_sections as Array:
			if raw_section is not Dictionary:
				continue
			var section := raw_section as Dictionary
			var heading := _clean_text(section.get("heading", ""), MAX_TITLE_LENGTH)
			var body := _clean_text(section.get("body", ""), MAX_BODY_LENGTH)
			var bullets := _normalize_string_array(section.get("bullets", []), MAX_DETAIL_BULLETS, MAX_SUMMARY_LENGTH)
			if heading == "" and body == "" and bullets.is_empty():
				continue
			sections.append({
				"heading": heading,
				"body": body,
				"bullets": bullets,
			})
			if sections.size() >= MAX_DETAIL_SECTIONS:
				break
	return {"sections": sections}


static func _clean_source_url(value: Variant) -> String:
	var url := _clean_text(value, MAX_URL_LENGTH)
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	return ""


static func _coerce_deck_id(value: Variant, import_url: String) -> int:
	var raw_text := str(value).strip_edges()
	if raw_text.is_valid_int():
		var explicit_id := int(raw_text)
		if explicit_id > 0:
			return explicit_id
	return DeckImporter.parse_deck_id(import_url)


static func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _extract_embedded_import_url(article: Dictionary) -> String:
	var snapshot := _as_dictionary(article.get("deck_snapshot", {}))
	var import_url := _clean_text(snapshot.get("import_url", snapshot.get("source_url", "")), MAX_URL_LENGTH)
	if import_url != "":
		return import_url
	var links_raw: Variant = article.get("links", [])
	var links: Array = links_raw if links_raw is Array else []
	for link_raw: Variant in links:
		if link_raw is not Dictionary:
			continue
		var link := link_raw as Dictionary
		var url := _clean_text(link.get("url", ""), MAX_URL_LENGTH)
		if DeckImporter.parse_deck_id(url) > 0:
			return url
	return ""


static func _extract_embedded_deck_id(article: Dictionary, import_url: String) -> int:
	var snapshot := _as_dictionary(article.get("deck_snapshot", {}))
	return _coerce_deck_id(snapshot.get("deck_id", 0), import_url)


static func _embedded_source_label(source: Dictionary) -> String:
	var city := _clean_text(source.get("city", ""), 24)
	if city == "":
		return "近期赛事样本"
	return "%s赛样本" % city


static func _extract_embedded_why_play(article: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var hero := _as_dictionary(article.get("hero", {}))
	var sections_raw: Variant = article.get("sections", [])
	var sections: Array = sections_raw if sections_raw is Array else []
	var priority_words := ["为什么", "差异", "判断"]
	for section_raw: Variant in sections:
		if section_raw is not Dictionary:
			continue
		var section := section_raw as Dictionary
		var heading := str(section.get("heading", ""))
		var use_section := false
		for word: String in priority_words:
			if word in heading:
				use_section = true
				break
		if not use_section:
			continue
		_append_section_bullets(result, section)
		if result.size() >= MAX_WHY_PLAY_ITEMS:
			break
	if result.is_empty():
		var thesis := _clean_text(hero.get("thesis", ""), MAX_SUMMARY_LENGTH)
		if thesis != "":
			result.append(thesis)
	return result


static func _append_section_bullets(result: Array[String], section: Dictionary) -> void:
	var bullets_raw: Variant = section.get("bullets", [])
	var bullets: Array = bullets_raw if bullets_raw is Array else []
	for bullet_raw: Variant in bullets:
		var bullet := _clean_text(bullet_raw, MAX_SUMMARY_LENGTH)
		if bullet == "":
			continue
		result.append(bullet)
		if result.size() >= MAX_WHY_PLAY_ITEMS:
			return
	if result.size() < MAX_WHY_PLAY_ITEMS:
		var body := _clean_text(section.get("body", ""), MAX_SUMMARY_LENGTH)
		if body != "":
			result.append(body)


static func _extract_embedded_pilot_tip(article: Dictionary) -> String:
	var sections_raw: Variant = article.get("sections", [])
	var sections: Array = sections_raw if sections_raw is Array else []
	for section_raw: Variant in sections:
		if section_raw is not Dictionary:
			continue
		var section := section_raw as Dictionary
		var heading := str(section.get("heading", ""))
		if not ("今天怎么练" in heading or "上手" in heading):
			continue
		var body := _clean_text(section.get("body", ""), MAX_SUMMARY_LENGTH)
		if body != "":
			return body
		var bullets := _normalize_string_array(section.get("bullets", []), 1, MAX_SUMMARY_LENGTH)
		if not bullets.is_empty():
			return bullets[0]
	return ""


static func _embedded_detail(article: Dictionary) -> Dictionary:
	var sections: Array[Dictionary] = []
	var sections_raw: Variant = article.get("sections", [])
	var source_sections: Array = sections_raw if sections_raw is Array else []
	for raw_section: Variant in source_sections:
		if raw_section is not Dictionary:
			continue
		var section := raw_section as Dictionary
		sections.append({
			"heading": section.get("heading", ""),
			"body": section.get("body", ""),
			"bullets": section.get("bullets", []),
		})
	return _normalize_detail({"sections": sections})
