class_name TestDeckManager
extends TestBase

const DeckManagerScene = preload("res://scenes/deck_manager/DeckManager.tscn")
const DeckRecommendationStoreScript = preload("res://scripts/engine/DeckRecommendationStore.gd")
const TEST_RECOMMENDATION_CACHE_PATH := "user://test_deck_manager/recommendation_cache.json"


class FakeDeckSuggestionClient:
	extends Node

	signal fetch_succeeded(response: Dictionary)
	signal fetch_failed(message: String)

	var calls: Array[Dictionary] = []

	func fetch_next_recommendation(current_id: String = "", exclude_ids: PackedStringArray = PackedStringArray(), metadata: Dictionary = {}) -> int:
		calls.append({
			"current_id": current_id,
			"exclude_ids": Array(exclude_ids),
			"metadata": metadata.duplicate(true),
		})
		return OK


class FakeDeckImporter:
	extends DeckImporter

	var imported_urls: PackedStringArray = PackedStringArray()

	func import_deck(url_or_id: String) -> void:
		imported_urls.append(url_or_id)


func test_deck_manager_uses_hud_visual_theme() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.call("_apply_hud_theme")
	var frame := scene.get_node_or_null("HudFrame") as PanelContainer
	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxFlat if frame != null else null
	var import_box := scene.find_child("ImportBox", true, false) as PanelContainer
	var import_style := import_box.get_theme_stylebox("panel") as StyleBoxFlat if import_box != null else null
	var import_button := scene.get_node_or_null("%BtnImport") as Button
	var button_style := import_button.get_theme_stylebox("normal") as StyleBoxFlat if import_button != null else null

	scene.queue_free()
	return run_checks([
		assert_true(frame_style != null and frame_style.bg_color.a < 0.9, "Deck manager should use a translucent HUD frame"),
		assert_eq(frame_style.border_color if frame_style != null else Color.TRANSPARENT, Color(0.76, 0.90, 1.0, 0.96), "Deck manager frame should use a clearly visible HUD border"),
		assert_eq(frame_style.border_width_left if frame_style != null else 0, 3, "Deck manager frame border should be thick enough to read in-game"),
		assert_true(import_style != null and import_style.bg_color.a < 1.0, "Deck import dialog should use HUD panel styling"),
		assert_true(button_style != null and button_style.border_color.a > 0.85, "Deck manager buttons should use explicit HUD borders"),
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 42.0, "Deck manager top action buttons should use touch-friendly HUD height"),
	])


func test_deck_manager_loads_three_latest_recommendation_articles() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var articles: Array[Dictionary] = scene._load_recommendation_articles()
	var deck_ids: Array = []
	for article: Dictionary in articles:
		deck_ids.append(scene._extract_recommendation_deck_id(article))

	scene.queue_free()
	return run_checks([
		assert_eq(articles.size(), 3, "Deck manager should load the three embedded coach articles"),
		assert_contains(deck_ids, 593481, "Embedded recommendations should include the Hangzhou Lost Box deck"),
		assert_contains(deck_ids, 598722, "Embedded recommendations should include the Xi'an Dragapult deck"),
		assert_contains(deck_ids, 599382, "Embedded recommendations should include the Chongqing Raging Bolt deck"),
	])


func test_deck_manager_renders_recommendations_above_deck_list() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var deck_list := scene.get_node("%DeckList") as VBoxContainer
	var deck_scroll := scene.find_child("DeckScroll", true, false) as ScrollContainer
	var deck_scroll_margin := deck_list.get_parent() as MarginContainer if deck_list != null else null
	var deck_list_right_margin := deck_scroll_margin.get_theme_constant("margin_right") if deck_scroll_margin != null else 0
	var first_child: Node = deck_list.get_child(0) if deck_list.get_child_count() > 0 else null
	var section := first_child as VBoxContainer
	var feed: VBoxContainer = null
	var old_cards: HBoxContainer = null
	var card: PanelContainer = null
	var why_title: Label = null
	var import_button: Button = null
	var detail_button: Button = null
	var next_button: Button = null
	var action_row: HBoxContainer = null
	if section != null:
		feed = section.get_node_or_null("RecommendationFeed") as VBoxContainer
		old_cards = section.get_node_or_null("RecommendationCards") as HBoxContainer
		card = section.find_child("RecommendationFeedCard", true, false) as PanelContainer
		why_title = section.find_child("RecommendationWhyTitle", true, false) as Label
		import_button = section.find_child("RecommendationImportButton", true, false) as Button
		detail_button = section.find_child("RecommendationDetailButton", true, false) as Button
		next_button = section.find_child("RecommendationNextButton", true, false) as Button
		action_row = section.find_child("RecommendationActionRow", true, false) as HBoxContainer
	var section_name: String = section.name if section != null else ""
	var feed_count: int = feed.get_child_count() if feed != null else 0
	var why_title_text := why_title.text if why_title != null else ""
	var section_text := _collect_label_text(section)
	var next_before_import := false
	var next_style: StyleBoxFlat = null
	var import_style: StyleBoxFlat = null
	if action_row != null and next_button != null and import_button != null:
		next_before_import = next_button.get_parent() == action_row and import_button.get_parent() == action_row and next_button.get_index() < import_button.get_index()
	if next_button != null:
		next_style = next_button.get_theme_stylebox("normal") as StyleBoxFlat
	if import_button != null:
		import_style = import_button.get_theme_stylebox("normal") as StyleBoxFlat

	scene.queue_free()
	return run_checks([
		assert_not_null(section, "Recommendation section should be inserted into the deck list"),
		assert_eq(section_name, "RecommendationSection", "Recommendation section should sit before saved deck rows"),
		assert_null(old_cards, "Recommendation section should not keep the old three-card row"),
		assert_false(section_text.contains("今日值得一玩的卡组"), "Recommendation section should not render the old title copy"),
		assert_false(section_text.contains("不催你做作业"), "Recommendation section should not render the old subtitle copy"),
		assert_not_null(deck_scroll_margin, "Deck center list should be wrapped in a margin container for scrollbar clearance"),
		assert_eq(deck_scroll.horizontal_scroll_mode if deck_scroll != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Deck center should not introduce horizontal scrolling for the right clearance"),
		assert_gte(deck_list_right_margin, 40, "Deck center list should leave room between content and the right scrollbar"),
		assert_not_null(feed, "Recommendation section should include the feed container"),
		assert_eq(feed_count, 1, "Recommendation section should render one rich feed card"),
		assert_not_null(card, "Recommendation feed should include the current deck card"),
		assert_eq(why_title_text, "为什么值得玩", "Recommendation card should explain why this deck is worth playing"),
		assert_not_null(import_button, "Recommendation card should keep the import action"),
		assert_not_null(detail_button, "Recommendation card should keep the detail action"),
		assert_not_null(next_button, "Recommendation card should include local next action"),
		assert_true(next_before_import, "Next recommendation button should sit before the import button in the card actions"),
		assert_true(next_button != null and next_button.custom_minimum_size.y >= 42.0, "Recommendation next action should use the larger HUD button size"),
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 42.0, "Recommendation import action should use the larger HUD button size"),
		assert_true(next_style != null and import_style != null and next_style.border_color != import_style.border_color, "Recommendation actions should have visually distinct button roles"),
	])


func test_recommendation_detail_dialog_uses_footer_close_only() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	var recommendation := _remote_recommendation("remote-detail", 910014, "2026-05-05T03:20:00+08:00")
	recommendation["detail"] = {
		"sections": [
			{"heading": "完整解读", "body": "这是一段完整解读。"},
		],
	}

	scene._show_recommendation_article_dialog(recommendation)
	var overlay := scene.get_node_or_null("RecommendationDetailOverlay") as Control
	var close_button_count := _count_buttons_with_text(overlay, "关闭")
	var scroll_margin := overlay.find_child("RecommendationDetailScrollMargin", true, false) as MarginContainer if overlay != null else null
	var scroll_margin_right := scroll_margin.get_theme_constant("margin_right") if scroll_margin != null else 0

	scene.queue_free()
	return run_checks([
		assert_not_null(overlay, "Recommendation detail overlay should open"),
		assert_eq(close_button_count, 1, "Recommendation detail overlay should only keep the footer close button"),
		assert_gte(scroll_margin_right, 30, "Recommendation detail content should leave room between text and the right scrollbar"),
	])


func test_deck_manager_open_requests_latest_remote_recommendation() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	scene._ensure_recommendation_section()
	var fake_client := FakeDeckSuggestionClient.new()
	scene._recommendation_client = fake_client
	scene.add_child(fake_client)

	var started: bool = scene._start_remote_recommendation_request(
		"",
		"deck_manager_open_refresh",
		"正在检查服务器最新卡组推荐...",
		"open_refresh"
	)
	var call_count := fake_client.calls.size()
	var first_call: Dictionary = fake_client.calls[0] if call_count > 0 else {}
	var metadata: Dictionary = first_call.get("metadata", {}) if first_call.has("metadata") else {}
	var exclude_ids: Array = first_call.get("exclude_ids", []) if first_call.has("exclude_ids") else []
	var status_label := scene.find_child("RecommendationStatusLabel", true, false) as Label
	var status_text := status_label.text if status_label != null else ""
	var fetch_reason: String = scene._recommendation_fetch_reason

	scene.queue_free()
	return run_checks([
		assert_true(started, "Opening refresh request should start when the recommendation client is available"),
		assert_eq(call_count, 1, "Opening deck manager should trigger one server refresh request"),
		assert_eq(str(first_call.get("current_id", "missing")), "", "Opening refresh should request the latest server recommendation without a current id"),
		assert_eq(exclude_ids.size(), 0, "Opening refresh should ask for the latest server item before background prefetch excludes known items"),
		assert_eq(str(metadata.get("source", "")), "deck_manager_open_refresh", "Opening refresh should use the open-refresh source marker"),
		assert_eq(fetch_reason, "open_refresh", "Opening refresh should track the request reason separately from the cycle button"),
		assert_str_contains(status_text, "正在检查服务器最新卡组推荐", "Opening refresh should show a latest-recommendation status"),
	])


func test_deck_manager_remote_cycle_excludes_known_recommendations() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._recommendation_store.call("upsert_item", _remote_recommendation("remote-a", 600101, "2026-05-05T01:00:00+08:00"), false)
	scene._recommendation_store.call("upsert_item", _remote_recommendation("remote-b", 600102, "2026-05-05T02:00:00+08:00"), false)
	var fake_client := FakeDeckSuggestionClient.new()
	scene._recommendation_client = fake_client
	scene.add_child(fake_client)

	var current_id := str(scene._current_recommendation.get("id", ""))
	var started: bool = scene._start_remote_recommendation_request(
		current_id,
		"deck_manager_recommendation",
		"fetching",
		"cycle"
	)
	var first_call: Dictionary = fake_client.calls[0] if fake_client.calls.size() > 0 else {}
	var exclude_ids: Array = first_call.get("exclude_ids", []) if first_call.has("exclude_ids") else []

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_true(started, "Cycle request should start with the fake recommendation client"),
		assert_contains(exclude_ids, current_id, "Cycle request should exclude the current recommendation id"),
		assert_contains(exclude_ids, "remote-a", "Cycle request should exclude cached server recommendations"),
		assert_contains(exclude_ids, "remote-b", "Cycle request should exclude every cached server recommendation"),
	])


func test_deck_manager_next_recommendation_cycles_embedded_feed() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var first_id := str(scene._current_recommendation.get("id", ""))
	scene._on_recommendation_next_pressed()
	var next_id := str(scene._current_recommendation.get("id", ""))
	var status_label := scene.find_child("RecommendationStatusLabel", true, false) as Label
	var status_text := status_label.text if status_label != null else ""
	var feed_card := scene.find_child("RecommendationFeedCard", true, false) as PanelContainer

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_true(first_id != "", "Initial recommendation should have a stable id"),
		assert_true(next_id != "", "Next recommendation should have a stable id"),
		assert_true(first_id != next_id, "Next action should switch to another embedded recommendation locally"),
		assert_str_contains(status_text, "已切换", "Next action should update the local status copy"),
		assert_not_null(feed_card, "Recommendation feed should be rebuilt after switching"),
	])


func test_deck_manager_falls_back_when_remote_returns_current_recommendation() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var first_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({
		"ok": true,
		"recommendation": scene._current_recommendation.duplicate(true),
	})
	var next_id := str(scene._current_recommendation.get("id", ""))
	var status_label := scene.find_child("RecommendationStatusLabel", true, false) as Label
	var status_text := status_label.text if status_label != null else ""

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_true(first_id != "", "Initial recommendation should have a stable id"),
		assert_true(next_id != "", "Fallback recommendation should have a stable id"),
		assert_true(first_id != next_id, "Same remote recommendation should fall back to local cycle"),
		assert_str_contains(status_text, "已切换推荐", "Fallback status should explain that another recommendation was selected"),
	])


func test_deck_manager_cycles_remote_and_embedded_recommendations_as_one_pool() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var first_id := str(scene._current_recommendation.get("id", ""))
	var remote := _remote_recommendation()
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": remote})
	var remote_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": remote})
	var second_local_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": remote})
	var third_local_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": remote})
	var cycled_id := str(scene._current_recommendation.get("id", ""))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(remote_id, "remote-raging-bolt", "First remote fetch should add the server recommendation into the cycle"),
		assert_true(second_local_id != "" and second_local_id != first_id and second_local_id != remote_id, "Second step should move to the next embedded recommendation"),
		assert_true(third_local_id != "" and third_local_id != first_id and third_local_id != remote_id and third_local_id != second_local_id, "Third step should move to the third embedded recommendation"),
		assert_eq(cycled_id, first_id, "Fourth step should cycle back to the first embedded recommendation"),
	])


func test_deck_manager_keeps_multiple_remote_recommendations_in_date_order() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var first_id := str(scene._current_recommendation.get("id", ""))
	var newer_remote := _remote_recommendation("remote-dragapult", 598722, "2026-05-04T15:30:00Z")
	var older_remote := _remote_recommendation("remote-raging-bolt", 599382, "2026-05-04T00:00:00Z")
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": newer_remote})
	var newer_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": older_remote})
	var pool_after_older := _recommendation_pool_ids(scene)
	var older_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": newer_remote})
	var second_local_id := str(scene._current_recommendation.get("id", ""))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(newer_id, "remote-dragapult", "First remote item should enter the cycle after the first embedded item"),
		assert_eq(older_id, "remote-raging-bolt", "Older same-day remote item should be the next card, not skipped. Pool: %s" % ",".join(pool_after_older)),
		assert_true(second_local_id != "" and second_local_id != first_id and second_local_id != newer_id and second_local_id != older_id, "After both remote items, cycle should continue into embedded recommendations"),
	])


func test_deck_manager_open_refresh_shows_latest_remote_directly() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var remote := _remote_recommendation("remote-latest-arceus", 600807, "2026-05-05T00:40:00+08:00")
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "open_refresh"
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": remote})
	var current_id := str(scene._current_recommendation.get("id", ""))
	var cached_current_id := str(scene._recommendation_store.call("get_current_id"))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(current_id, "remote-latest-arceus", "Opening deck manager should show the latest server recommendation directly"),
		assert_eq(cached_current_id, "remote-latest-arceus", "Opening refresh should persist the latest server recommendation as current"),
	])


func test_deck_manager_prefetch_caches_without_switching_current() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var first_id := str(scene._current_recommendation.get("id", ""))
	var remote := _remote_recommendation("remote-prefetched", 600108, "2026-05-05T03:00:00+08:00")
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "prefetch"
	scene._recommendation_prefetch_remaining = 0
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": remote})
	var current_id := str(scene._current_recommendation.get("id", ""))
	var cached_ids: Array = []
	var cached_items: Array = scene._recommendation_store.call("get_items")
	for item_raw: Variant in cached_items:
		if item_raw is Dictionary:
			cached_ids.append(str((item_raw as Dictionary).get("id", "")))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(current_id, first_id, "Background prefetch should not switch the visible recommendation"),
		assert_contains(cached_ids, "remote-prefetched", "Background prefetch should cache the server recommendation for later cycling"),
	])


func test_deck_manager_open_refresh_failure_keeps_current_recommendation() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var first_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "open_refresh"
	scene._on_remote_recommendation_failed("server unavailable")
	var current_id := str(scene._current_recommendation.get("id", ""))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(current_id, first_id, "Opening refresh failure should keep the current recommendation instead of cycling locally"),
	])


func test_import_panel_close_button_hides_dialog_while_busy() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.get_node("%ImportPanel").visible = true
	scene._current_operation = "import"

	scene._on_close_import()
	var panel_visible: bool = scene.get_node("%ImportPanel").visible

	scene.queue_free()
	return run_checks([
		assert_false(panel_visible, "Close button should hide the import dialog even while an import is running"),
	])


func test_import_deck_name_validation_rejects_empty_and_duplicates() -> String:
	_cleanup_decks([910001])
	var existing := _make_deck(910001, "重复名称")
	CardDatabase.save_deck(existing)

	var scene: Control = DeckManagerScene.instantiate()
	var empty_error: String = scene._validate_import_deck_name("   ")
	var duplicate_error: String = scene._validate_import_deck_name("重复名称")
	var unique_error: String = scene._validate_import_deck_name("新名称")

	_cleanup_decks([existing.id])
	scene.queue_free()

	return run_checks([
		assert_true(empty_error != "", "空白名称应返回错误"),
		assert_true(duplicate_error != "", "重复名称应返回错误"),
		assert_eq(unique_error, "", "唯一名称不应返回错误"),
	])


func test_import_completed_saves_immediately_when_name_is_unique() -> String:
	_cleanup_decks([910002])
	var imported := _make_deck(910002, "唯一导入名")
	var scene: Control = DeckManagerScene.instantiate()

	scene._on_import_completed(imported, PackedStringArray())

	var saved: DeckData = CardDatabase.get_deck(imported.id)
	var pending_deck = scene._pending_import_deck

	_cleanup_decks([imported.id])
	scene.queue_free()

	return run_checks([
		assert_not_null(saved, "唯一名称导入后应直接保存"),
		assert_eq(saved.deck_name, "唯一导入名", "应保留原始唯一名称"),
		assert_null(pending_deck, "唯一名称不应进入待改名状态"),
	])


func test_recommendation_import_uses_article_deck_name() -> String:
	_cleanup_decks([910013])
	var scene: Control = DeckManagerScene.instantiate()
	var fake_importer := FakeDeckImporter.new()
	scene._importer = fake_importer
	scene.add_child(fake_importer)
	var recommendation := _remote_recommendation("remote-blissey", 910013, "2026-05-05T01:55:00+08:00")
	recommendation["deck_name"] = "南通冠军幸福蛋"
	recommendation["title"] = "把伤害变成资源的南通冠军幸福蛋"
	recommendation["import_url"] = "https://tcg.mik.moe/decks/list/910013"
	var imported := _make_deck(910013, "幸福蛋")

	scene._on_recommendation_import_pressed(recommendation)
	var requested_url := fake_importer.imported_urls[0] if fake_importer.imported_urls.size() > 0 else ""
	scene._on_import_completed(imported, PackedStringArray())
	var saved: DeckData = CardDatabase.get_deck(imported.id)
	var pending_override: String = scene._pending_import_deck_name_override

	_cleanup_decks([imported.id])
	scene.queue_free()
	return run_checks([
		assert_eq(requested_url, "https://tcg.mik.moe/decks/list/910013", "Recommendation import should request the article deck URL"),
		assert_not_null(saved, "Recommendation import should save the deck when the article name is unique"),
		assert_eq(saved.deck_name, "南通冠军幸福蛋", "Recommendation import should use the article-provided deck name instead of the variant name"),
		assert_eq(pending_override, "", "Recommendation import name override should be consumed after completion"),
	])


func test_import_result_state_hides_import_button_after_completion_or_failure() -> String:
	_cleanup_decks([910012])
	var imported := _make_deck(910012, "Result State Deck")
	var success_scene: Control = DeckManagerScene.instantiate()

	success_scene._on_import_completed(imported, PackedStringArray())
	var success_button := success_scene.get_node("%BtnDoImport") as Button
	var success_input := success_scene.get_node("%UrlInput") as LineEdit
	var success_progress := success_scene.get_node("%ProgressBar") as ProgressBar
	var success_text := str((success_scene.get_node("%ProgressLabel") as Label).text)

	_cleanup_decks([imported.id])
	success_scene.queue_free()

	var failed_scene: Control = DeckManagerScene.instantiate()
	failed_scene.get_node("%BtnDoImport").visible = true
	failed_scene.get_node("%BtnDoImport").disabled = false
	failed_scene.get_node("%UrlInput").editable = true
	failed_scene._current_operation = "import"

	failed_scene._on_import_failed("bad deck")
	var failure_button := failed_scene.get_node("%BtnDoImport") as Button
	var failure_input := failed_scene.get_node("%UrlInput") as LineEdit
	var failure_progress := failed_scene.get_node("%ProgressBar") as ProgressBar
	var failure_text := str((failed_scene.get_node("%ProgressLabel") as Label).text)

	failed_scene.queue_free()

	return run_checks([
		assert_false(success_button.visible, "Import button should hide after successful import"),
		assert_true(success_button.disabled, "Import button should stay disabled in success result state"),
		assert_false(success_input.editable, "Import input should lock after successful import"),
		assert_false(success_progress.visible, "Progress bar should hide after successful import"),
		assert_str_contains(success_text, "导入成功", "Successful import should show a direct success result"),
		assert_false(failure_button.visible, "Import button should hide after failed import"),
		assert_true(failure_button.disabled, "Import button should stay disabled in failure result state"),
		assert_false(failure_input.editable, "Import input should lock after failed import"),
		assert_false(failure_progress.visible, "Progress bar should hide after failed import"),
		assert_str_contains(failure_text, "导入失败", "Failed import should show a direct failure result"),
	])


func test_import_pressed_resets_result_state_for_next_import() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.get_node("%BtnDoImport").visible = false
	scene.get_node("%BtnDoImport").disabled = true
	scene.get_node("%UrlInput").editable = false
	scene.get_node("%ProgressLabel").text = "导入成功：旧结果"

	scene._on_import_pressed()
	var import_button := scene.get_node("%BtnDoImport") as Button
	var url_input := scene.get_node("%UrlInput") as LineEdit
	var result_text := str((scene.get_node("%ProgressLabel") as Label).text)
	var panel_visible: bool = scene.get_node("%ImportPanel").visible

	scene.queue_free()

	return run_checks([
		assert_true(panel_visible, "Import panel should open for the next import"),
		assert_true(import_button.visible, "Import button should return when starting a fresh import"),
		assert_false(import_button.disabled, "Import button should be enabled for a fresh import"),
		assert_true(url_input.editable, "Import input should be editable for a fresh import"),
		assert_eq(result_text, "", "Fresh import should clear the previous result text"),
	])


func test_import_result_close_timeout_hides_panel_only_when_idle() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.get_node("%ImportPanel").visible = true
	scene._current_operation = ""
	scene._on_import_result_close_timeout()
	var idle_hidden: bool = not scene.get_node("%ImportPanel").visible

	scene.get_node("%ImportPanel").visible = true
	scene._current_operation = "import"
	scene._on_import_result_close_timeout()
	var busy_visible: bool = scene.get_node("%ImportPanel").visible

	scene.queue_free()

	return run_checks([
		assert_true(idle_hidden, "Import result timer should close the panel after a completed import result"),
		assert_true(busy_visible, "Import result timer should not close the panel if another operation has started"),
	])


func test_import_completed_requires_rename_before_saving_duplicate_name() -> String:
	_cleanup_decks([910003, 910004])
	var existing := _make_deck(910003, "冲突卡组")
	var imported := _make_deck(910004, "冲突卡组")
	CardDatabase.save_deck(existing)

	var scene: Control = DeckManagerScene.instantiate()
	scene._on_import_completed(imported, PackedStringArray())

	var not_saved_yet: DeckData = CardDatabase.get_deck(imported.id)
	var pending_before = scene._pending_import_deck
	var confirm_before: bool = scene._rename_confirm_button.disabled if scene._rename_confirm_button != null else false

	scene._on_import_rename_text_changed("冲突卡组")
	if scene._rename_input != null:
		scene._rename_input.text = "改名后卡组"
	scene._on_import_rename_text_changed("改名后卡组")
	scene._on_confirm_import_rename()

	var saved: DeckData = CardDatabase.get_deck(imported.id)
	var pending_after = scene._pending_import_deck

	_cleanup_decks([existing.id, imported.id])
	scene.queue_free()

	return run_checks([
		assert_null(not_saved_yet, "重名导入时不应立即保存"),
		assert_not_null(pending_before, "重名导入时应进入待改名状态"),
		assert_true(confirm_before, "重名初始值时确认按钮应禁用"),
		assert_not_null(saved, "改成唯一名称后应保存卡组"),
		assert_eq(saved.deck_name, "改名后卡组", "保存后的卡组应使用新名称"),
		assert_null(pending_after, "保存后应清空待改名状态"),
	])


func test_existing_deck_name_validation_ignores_current_deck() -> String:
	_cleanup_decks([910005, 910006])
	var current := _make_deck(910005, "Current Deck")
	var other := _make_deck(910006, "Other Deck")
	CardDatabase.save_deck(current)
	CardDatabase.save_deck(other)

	var scene: Control = DeckManagerScene.instantiate()
	var keep_current_error: String = scene._validate_deck_name("  Current Deck  ", current.id)
	var other_duplicate_error: String = scene._validate_deck_name("Other Deck", current.id)

	_cleanup_decks([current.id, other.id])
	scene.queue_free()

	return run_checks([
		assert_eq(keep_current_error, "", "current deck name should remain valid when ignoring self"),
		assert_true(other_duplicate_error != "", "other deck name should still be rejected"),
	])


func test_confirm_existing_deck_rename_persists_trimmed_name() -> String:
	_cleanup_decks([910007])
	var deck := _make_deck(910007, "Old Deck Name")
	CardDatabase.save_deck(deck)

	var scene: Control = DeckManagerScene.instantiate()
	scene._on_rename_deck(deck)

	var initial_validation_error: String = scene._rename_error_label.text if scene._rename_error_label != null else "__missing__"
	if scene._rename_input != null:
		scene._rename_input.text = "  New Deck Name  "
	scene._on_rename_text_changed("  New Deck Name  ")
	scene._on_confirm_rename()

	var saved: DeckData = CardDatabase.get_deck(deck.id)

	_cleanup_decks([deck.id])
	scene.queue_free()

	return run_checks([
		assert_eq(initial_validation_error, "", "existing deck name should be valid at dialog open"),
		assert_not_null(saved, "renamed deck should still exist"),
		assert_eq(saved.deck_name, "New Deck Name", "rename should persist the trimmed deck name"),
	])


func test_duplicate_import_rename_dialog_stays_clamped_with_visible_confirm_controls() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._show_import_rename_dialog("Duplicate Deck Name")

	var dialog: AcceptDialog = scene._rename_dialog
	var scroll: ScrollContainer = null
	if dialog != null:
		for child: Node in dialog.get_children():
			if child is ScrollContainer:
				scroll = child
				break

	scene.queue_free()

	return run_checks([
		assert_not_null(dialog, "duplicate import should open the rename dialog"),
		assert_eq(dialog.size, Vector2i(460, 230), "rename dialog should use the fixed clamped size"),
		assert_not_null(scroll, "rename dialog should wrap content in a scroll container"),
		assert_not_null(scene._rename_confirm_button, "rename dialog should still expose the confirm button"),
	])


func test_import_completed_does_not_reprompt_rename_for_same_saved_deck_id() -> String:
	_cleanup_decks([910008])
	var deck := _make_deck(910008, "Same Saved Deck")
	CardDatabase.save_deck(deck)

	var scene: Control = DeckManagerScene.instantiate()
	scene._on_import_completed(deck, PackedStringArray())

	var pending_deck = scene._pending_import_deck
	var rename_dialog = scene._rename_dialog
	var saved: DeckData = CardDatabase.get_deck(deck.id)

	_cleanup_decks([deck.id])
	scene.queue_free()

	return run_checks([
		assert_not_null(saved, "same-id imported deck should remain saved"),
		assert_null(pending_deck, "same-id import completion should not enter pending rename state"),
		assert_null(rename_dialog, "same-id import completion should not reopen the rename dialog"),
	])


func _configure_recommendation_test_state(scene: Control, cache_path: String = "") -> void:
	scene._recommendation_store = DeckRecommendationStoreScript.new()
	if cache_path != "":
		scene._recommendation_store.call("set_cache_path", cache_path)
	scene._recommendation_store.call("load_cache")
	scene._recommendation_articles = scene._load_recommendation_articles()
	scene._embedded_recommendations = scene._normalize_recommendation_articles(scene._recommendation_articles)
	if not scene._embedded_recommendations.is_empty():
		scene._current_recommendation = scene._embedded_recommendations[0]


func _remote_recommendation(recommendation_id: String = "remote-raging-bolt", deck_id: int = 599382, generated_at: String = "2026-05-04T00:00:00Z") -> Dictionary:
	var deck_name := "猛雷鼓 Ogerpon" if deck_id == 599382 else "多龙喷火龙 联调推荐"
	return {
		"id": recommendation_id,
		"deck_id": deck_id,
		"deck_name": deck_name,
		"title": "服务端每日推荐",
		"style_summary": "高速展开、资源爆发、连续制造大伤害窗口。",
		"why_play": ["爆发窗口明确。", "能量调度有决策密度。", "适合理解环境速度线。"],
		"best_for": "喜欢主动进攻的玩家。",
		"pilot_tip": "提前规划下一只攻击手。",
		"source": {
			"label": "每日推荐",
			"date": "2026-05-04",
		},
		"import_url": "https://tcg.mik.moe/decks/list/%d" % deck_id,
		"detail": {"sections": []},
		"generated_at": generated_at,
	}


func _collect_label_text(node: Node) -> String:
	if node == null:
		return ""
	var parts := PackedStringArray()
	_collect_label_text_recursive(node, parts)
	return "\n".join(parts)


func _collect_label_text_recursive(node: Node, parts: PackedStringArray) -> void:
	if node is Label:
		parts.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_label_text_recursive(child, parts)


func _count_buttons_with_text(node: Node, text: String) -> int:
	if node == null:
		return 0
	var count := 0
	if node is Button and (node as Button).text == text:
		count += 1
	for child: Node in node.get_children():
		count += _count_buttons_with_text(child, text)
	return count


func _recommendation_pool_ids(scene: Control) -> PackedStringArray:
	var ids := PackedStringArray()
	var pool: Array = scene._combined_recommendation_pool()
	for item_raw: Variant in pool:
		if item_raw is Dictionary:
			ids.append(str((item_raw as Dictionary).get("id", "")))
	return ids


func _delete_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var absolute_path := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(absolute_path)


func _make_deck(deck_id: int, deck_name: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.source_url = "https://tcg.mik.moe/decks/list/%d" % deck_id
	deck.import_date = "2026-03-25 00:00:00"
	deck.variant_name = deck_name
	deck.deck_code = "UTEST_%d" % deck_id
	deck.total_cards = 60
	deck.cards = []
	return deck


func _cleanup_decks(deck_ids: Array[int]) -> void:
	for deck_id: int in deck_ids:
		if CardDatabase.has_deck(deck_id):
			CardDatabase.delete_deck(deck_id)
