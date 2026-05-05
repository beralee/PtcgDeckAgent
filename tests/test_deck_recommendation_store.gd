class_name TestDeckRecommendationStore
extends TestBase

const StoreScript := preload("res://scripts/engine/DeckRecommendationStore.gd")
const COMMUNITY_DATA_PATH := "res://community/data/community-data.json"
const TEST_CACHE_PATH := "user://deck_recommendation_store_test/cache.json"


func test_store_normalizes_embedded_recommendation_article() -> String:
	var articles := _load_embedded_articles()
	if articles.is_empty():
		return "community data should include embedded recommendation articles"
	var normalized: Dictionary = StoreScript.normalize_embedded_article(articles[0])

	return run_checks([
		assert_false(normalized.is_empty(), "Embedded article should normalize into a recommendation"),
		assert_eq(str(normalized.get("id", "")), "hangzhou-lost-toolbox", "Embedded slug should become the stable recommendation id"),
		assert_eq(int(normalized.get("deck_id", 0)), 593481, "Embedded deck id should be preserved"),
		assert_eq(str(normalized.get("deck_name", "")), "非主流放逐 Box", "Embedded deck name should be preserved"),
		assert_true(str(normalized.get("import_url", "")).contains("tcg.mik.moe/decks/list/593481"), "Embedded import URL should remain importable"),
		assert_true((normalized.get("why_play", []) as Array).size() > 0, "Embedded article should expose why-play copy"),
		assert_true((normalized.get("why_play", []) as Array).size() <= 3, "Why-play copy should stay compact"),
	])


func test_store_accepts_valid_server_recommendation() -> String:
	var normalized: Dictionary = StoreScript.normalize_recommendation(_server_recommendation("daily-raging-bolt", 599382))

	return run_checks([
		assert_false(normalized.is_empty(), "Valid server recommendation should normalize"),
		assert_eq(str(normalized.get("id", "")), "daily-raging-bolt", "Server id should be preserved"),
		assert_eq(int(normalized.get("deck_id", 0)), 599382, "Server deck id should be preserved"),
		assert_eq((normalized.get("why_play", []) as Array).size(), 3, "Why-play should be capped to three items"),
		assert_eq(((normalized.get("why_play", []) as Array)[0]), "爆发窗口明确，打起来反馈很直接。", "Why-play text should preserve order"),
	])


func test_store_rejects_invalid_recommendation_shape() -> String:
	var missing_id := _server_recommendation("", 599382)
	var missing_deck_name := _server_recommendation("missing-name", 599382)
	missing_deck_name["deck_name"] = ""
	var bad_url := _server_recommendation("bad-url", 599382)
	bad_url["import_url"] = "https://example.com/not-a-deck"

	return run_checks([
		assert_true(StoreScript.normalize_recommendation(missing_id).is_empty(), "Missing id should be rejected"),
		assert_true(StoreScript.normalize_recommendation(missing_deck_name).is_empty(), "Missing deck name should be rejected"),
		assert_true(StoreScript.normalize_recommendation(bad_url).is_empty(), "Non-importable URL should be rejected"),
	])


func test_store_cache_deduplicates_bounds_and_cycles_items() -> String:
	_remove_test_cache()
	var store = StoreScript.new()
	store.set_cache_path(TEST_CACHE_PATH)
	store.load_cache()

	for i: int in range(12):
		store.upsert_item(_server_recommendation("rec-%02d" % i, 600000 + i), true)
	store.upsert_item(_server_recommendation("rec-10", 600010, "重复更新标题"), true)
	var items: Array[Dictionary] = store.get_items()
	var current_id := store.get_current_id()
	var next_item: Dictionary = store.get_next_cached(current_id)
	var saved := store.save_cache()

	var reloaded = StoreScript.new()
	reloaded.set_cache_path(TEST_CACHE_PATH)
	var reloaded_cache: Dictionary = reloaded.load_cache()
	var reloaded_items: Array = reloaded_cache.get("items", [])

	_remove_test_cache()

	return run_checks([
		assert_eq(items.size(), 10, "Cache should keep the most recent ten recommendations"),
		assert_eq(str((items[0] as Dictionary).get("id", "")), "rec-10", "Updated duplicate should move to the front"),
		assert_eq(str((items[0] as Dictionary).get("title", "")), "重复更新标题", "Updated duplicate should replace old content"),
		assert_eq(current_id, "rec-10", "Current id should track the latest current item"),
		assert_false(next_item.is_empty(), "Cache should return another item when cycling"),
		assert_true(saved, "Cache should save to user storage"),
		assert_eq(reloaded_items.size(), 10, "Saved cache should reload bounded items"),
	])


func _server_recommendation(recommendation_id: String, deck_id: int, title: String = "一套节奏直接的进攻型卡组") -> Dictionary:
	return {
		"id": recommendation_id,
		"deck_id": deck_id,
		"deck_name": "猛雷鼓 Ogerpon",
		"title": title,
		"style_summary": "高速展开、资源爆发、连续制造大伤害窗口。",
		"why_play": [
			"爆发窗口明确，打起来反馈很直接。",
			"能量调度和伤害规划有足够决策密度。",
			"适合理解当前环境速度线。",
			"第四条应该被裁掉。",
		],
		"best_for": "喜欢主动进攻的玩家。",
		"pilot_tip": "提前规划下一只攻击手。",
		"source": {
			"label": "测试样本",
			"city": "测试",
			"date": "2026-05-04",
			"players": 64,
		},
		"import_url": "https://tcg.mik.moe/decks/list/%d" % deck_id,
		"detail": {
			"sections": [
				{
					"heading": "为什么值得试",
					"body": "测试详情。",
					"bullets": ["强点一", "强点二"],
				},
			],
		},
		"generated_at": "2026-05-04T00:00:00Z",
	}


func _load_embedded_articles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMMUNITY_DATA_PATH))
	if parsed is not Dictionary:
		return result
	var briefing := ((parsed as Dictionary).get("environment_briefing", {}) as Dictionary)
	var articles_raw: Variant = briefing.get("articles", [])
	if articles_raw is Array:
		for article_raw: Variant in articles_raw as Array:
			if article_raw is Dictionary:
				result.append(article_raw as Dictionary)
	return result


func _remove_test_cache() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_CACHE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
