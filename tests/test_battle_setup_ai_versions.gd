class_name TestBattleSetupAIVersions
extends TestBase

const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const DeckStrategyV18ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const V18CPGProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const EXPECTED_V18_STRENGTH_ORDER_IDS: Array[int] = [
	# Final normal-mode n100 win rate descending; strong-mode n100 breaks ties.
	800018500, 800018880, 800017631, 800018501, 18000625, 800018509,
	800016834, 800018543, 800017047, 800017407, 18000230, 800015734,
	800018502, 800018498, 800019125, 800018499, 800018105, 800033475,
	800018497, 800017097, 800015934, 800017643, 800018539, 800018359,
	800017280,
]


class FakeAIVersionRegistry extends RefCounted:
	var playable_versions: Array[Dictionary] = []

	func list_playable_versions() -> Array[Dictionary]:
		return playable_versions.duplicate(true)

	func list_playable_versions_for_strategy(strategy_id: String) -> Array[Dictionary]:
		var filtered: Array[Dictionary] = []
		for version: Dictionary in playable_versions:
			var compatible_strategy_id := str(version.get("compatible_strategy_id", ""))
			if compatible_strategy_id == "" or compatible_strategy_id == strategy_id:
				filtered.append(version.duplicate(true))
		return filtered

	func get_latest_playable_version() -> Dictionary:
		if playable_versions.is_empty():
			return {}
		return playable_versions[playable_versions.size() - 1].duplicate(true)


class FakeDeckViewDialog extends RefCounted:
	var shown_decks: Array[DeckData] = []

	func show_deck(_scene: Object, deck: DeckData) -> void:
		shown_decks.append(deck)


func _make_scene_ready() -> Control:
	var scene: Control = BattleSetupScene.instantiate()
	scene.call("_ready")
	# AI 控件在 _ready() 中被隐藏，测试需要手动初始化
	scene.call("_setup_ai_source_options")
	scene.call("_refresh_ai_version_options")
	return scene


func _make_deck(deck_id: int, deck_name: String, signature_name: String = "") -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.total_cards = 60
	if signature_name != "":
		deck.cards = [{
			"name": signature_name,
			"name_en": signature_name,
			"card_type": "Pokemon",
			"count": 1,
		}]
	return deck


func _prime_deck_options(scene: Control) -> void:
	# These are classic-AI fixtures. BattleSetup now persists a third top-level
	# author mode, so never inherit the mode left by another suite/user setting.
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.set("_deck_list", [
		_make_deck(575716, "deck-a", "喷火龙ex"),
		_make_deck(575720, "deck-b", "密勒顿ex"),
		_make_deck(578647, "deck-c", "沙奈朵ex"),
	])
	scene.set("_ai_deck_list", [
		_make_deck(578647, "deck-c", "Gardevoir ex"),
		_make_deck(610080, "deck-g175", "Gardevoir ex"),
		_make_deck(575716, "deck-a", "喷火龙ex"),
		_make_deck(575720, "deck-b", "密勒顿ex"),
		_make_deck(575657, "deck-l", "Lugia VSTAR"),
		_make_deck(609431, "deck-l175", "Lugia VSTAR"),
		_make_deck(569061, "deck-d", "阿尔宙斯 VSTAR"),
		_make_deck(579502, "deck-h", "Dragapult ex"),
		_make_deck(575723, "deck-i", "Dragapult ex"),
	])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("deck-a", 0)
	deck2_option.add_item("deck-a", 0)
	deck1_option.add_item("deck-b", 1)
	deck2_option.add_item("deck-b", 1)
	deck1_option.add_item("deck-c", 2)
	deck2_option.add_item("deck-d", 2)
	deck1_option.select(0)
	deck2_option.select(1)


func _snapshot_battle_review_config_file() -> Dictionary:
	var path: String = GameManager.get_battle_review_api_config_path()
	if not FileAccess.file_exists(path):
		return {"exists": false, "text": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "text": ""}
	var text := file.get_as_text()
	file.close()
	return {"exists": true, "text": text}


func _restore_battle_review_config_file(snapshot: Dictionary) -> void:
	var path: String = GameManager.get_battle_review_api_config_path()
	if bool(snapshot.get("exists", false)):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(str(snapshot.get("text", "")))
			file.close()
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_battle_review_config_for_test(data: Dictionary) -> void:
	var file := FileAccess.open(GameManager.get_battle_review_api_config_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _snapshot_battle_setup_settings_file() -> Dictionary:
	const PATH := "user://battle_setup.json"
	if not FileAccess.file_exists(PATH):
		return {"exists": false, "text": ""}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {"exists": false, "text": ""}
	var text := file.get_as_text()
	file.close()
	return {"exists": true, "text": text}


func _restore_battle_setup_settings_file(snapshot: Dictionary) -> void:
	const PATH := "user://battle_setup.json"
	if bool(snapshot.get("exists", false)):
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(str(snapshot.get("text", "")))
			file.close()
			return
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _variant_ids(variants: Array) -> Array[String]:
	var ids: Array[String] = []
	for variant: Dictionary in variants:
		ids.append(str(variant.get("id", "")))
	return ids


func _visible_control_child_count(parent: Control) -> int:
	var count := 0
	if parent == null:
		return count
	for child: Node in parent.get_children():
		if child is Control and (child as Control).visible:
			count += 1
	return count


func _make_author_picker_record(index: int, install_source: String = "user") -> Dictionary:
	var package_id := "pkg.large.%03d" % index
	var archive_sha256 := ("%064d" % index).right(64)
	return {
		"package_id": package_id,
		"package_version": "1.0.%d" % index,
		"archive_sha256": archive_sha256,
		"install_source": install_source,
		"install_sources": [install_source],
		"display_name": "作者策略 %03d" % index,
		"display_label": "作者策略 %03d · 测试作者 · v1.0.%d" % [index, index],
		"author_name": "测试作者",
		"deck_name": "作者卡组 %03d" % index,
		"summary": "大量策略滚动测试",
		"status": "metadata_only",
		"status_detail": "已加载",
		"stable_ref": {
			"package_id": package_id,
			"package_version": "1.0.%d" % index,
			"archive_sha256": archive_sha256,
		},
	}


func test_battle_setup_includes_ai_source_and_version_controls() -> String:
	var scene := BattleSetupScene.instantiate()
	var ai_source_label := scene.find_child("AISourceLabel", true, false)
	var ai_source_option := scene.find_child("AISourceOption", true, false)
	var ai_version_label := scene.find_child("AIVersionLabel", true, false)
	var ai_version_option := scene.find_child("AIVersionOption", true, false)
	var model_label := scene.find_child("LLMModelLabel", true, false)
	var model_option := scene.find_child("LLMModelOption", true, false)
	var model_test_button := scene.find_child("BtnTestLLMModel", true, false)
	var ai_mode_status_title := scene.find_child("AIModeStatusTitle", true, false)
	var ai_mode_status_body := scene.find_child("AIModeStatusBody", true, false)

	return run_checks([
		assert_true(ai_source_label is Label, "BattleSetup should include AISourceLabel"),
		assert_true(ai_source_option is OptionButton, "BattleSetup should include AISourceOption"),
		assert_true(ai_version_label is Label, "BattleSetup should include AIVersionLabel"),
		assert_true(ai_version_option is OptionButton, "BattleSetup should include AIVersionOption"),
		assert_true(ai_mode_status_title is Label, "BattleSetup should include the AI mode status title"),
		assert_true(ai_mode_status_body is Label, "BattleSetup should include the AI mode status description"),
		assert_true(model_label is Label, "BattleSetup should include the LLM model label"),
		assert_true(model_option is OptionButton, "BattleSetup should include the LLM model dropdown"),
		assert_true(model_test_button is Button, "BattleSetup should include the LLM model test button"),
	])


func test_battle_setup_mode_uses_hud_segment_buttons() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var mode_segment := scene.find_child("ModeSegment", true, false) as HBoxContainer
	var two_player_button := scene.find_child("ModeTwoPlayerButton", true, false) as Button
	var ai_button := scene.find_child("ModeAIButton", true, false) as Button
	var author_button := scene.find_child("ModeAuthorStrategyButton", true, false) as Button
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton

	if ai_button != null:
		ai_button.pressed.emit()
	var selected_after_ai := mode_option.selected
	var ai_controls_visible := preview_option.visible
	if author_button != null:
		author_button.pressed.emit()
	var selected_after_hidden_author_press := mode_option.selected
	if two_player_button != null:
		two_player_button.pressed.emit()
	var selected_after_two_player := mode_option.selected
	var two_player_controls_hidden := not preview_option.visible

	return run_checks([
		assert_true(mode_segment is HBoxContainer, "BattleSetup should expose mode choices as a HUD segment"),
		assert_false(mode_option.visible, "Legacy mode dropdown should stay hidden behind the HUD segment"),
		assert_eq(_visible_control_child_count(mode_segment), 2, "AI battle and author packages should share one user-facing AI mode"),
		assert_eq(two_player_button.text if two_player_button != null else "", mode_option.get_item_text(0), "Two-player mode button should mirror the hidden option label"),
		assert_eq(ai_button.text if ai_button != null else "", mode_option.get_item_text(1), "AI mode button should mirror the hidden option label"),
		assert_false(author_button.visible if author_button != null else true, "Author packages should be selected inside the AI opponent picker"),
		assert_true(author_button.disabled if author_button != null else false, "The hidden legacy button must not change mode"),
		assert_eq(selected_after_ai, 1, "Pressing AI mode should update the hidden mode option"),
		assert_true(ai_controls_visible, "Pressing AI mode should refresh AI-only setup controls"),
		assert_eq(selected_after_hidden_author_press, 1, "The hidden legacy author button must not switch away from the unified AI surface"),
		assert_eq(selected_after_two_player, 0, "Pressing two-player mode should update the hidden mode option"),
		assert_true(two_player_controls_hidden, "Pressing two-player mode should hide AI-only setup controls"),
	])


func test_battle_setup_llm_model_controls_show_in_ai_mode() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k3",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var model_row := scene.find_child("LLMModelRow", true, false) as HBoxContainer
	var model_option := scene.find_child("LLMModelOption", true, false) as OptionButton
	var discuss_button := scene.find_child("BtnDiscussStrategyAI", true, false) as Button
	mode_option.select(0)
	scene.call("_refresh_ai_ui_visibility")
	var hidden_in_two_player := model_row.visible
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	var expected_model_label := GameManager.get_battle_review_model_label(str(GameManager.get_battle_review_api_config().get("model", "")))

	var result := run_checks([
		assert_false(hidden_in_two_player, "LLM model controls should stay hidden outside VS_AI mode"),
		assert_true(model_row.visible, "LLM model controls should show in VS_AI mode"),
		assert_eq(model_option.get_item_count(), GameManager.get_supported_battle_review_models().size(), "LLM model dropdown should mirror AI settings model choices"),
		assert_str_contains(discuss_button.text, expected_model_label, "Strategy discussion button should name the selected model"),
	])
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_deepseek_provider_limits_model_picker() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-pro",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	var model_option := scene.find_child("LLMModelOption", true, false) as OptionButton
	var model_ids: Array[String] = []
	for index: int in model_option.get_item_count():
		model_ids.append(str(model_option.get_item_metadata(index)))

	var result := run_checks([
		assert_eq(model_ids, ["deepseek-v4-flash", "deepseek-v4-pro"], "DeepSeek direct should expose only its two supported models in BattleSetup"),
		assert_eq(str(model_option.get_item_metadata(model_option.selected)), "deepseek-v4-pro", "BattleSetup should retain the configured DeepSeek model"),
		assert_eq(str(scene.call("_selected_llm_model_id")), "deepseek-v4-pro", "BattleSetup should resolve the selected model inside the active provider"),
	])
	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_windows_landscape_exposes_released_ns_zoroark_cpg() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	var ns_zoroark := _make_deck(800018502, "18.0 N的索罗亚克", "N的索罗亚克ex")
	scene.set("_ai_deck_list", [ns_zoroark])
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	deck2_option.clear()
	deck2_option.add_item(ns_zoroark.deck_name)
	deck2_option.set_item_metadata(0, ns_zoroark.id)
	deck2_option.select(0)
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")

	var strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var strategy_segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var ids: Array[String] = []
	for index: int in strategy_option.get_item_count():
		ids.append(str(strategy_option.get_item_metadata(index)))

	var result := run_checks([
		assert_eq(ids, ["v18_800018502_ns_zoroark", "v18cpg_800018502_ns_zoroark"], "Released N's Zoroark should expose Rule and V18CPG choices"),
		assert_true(strategy_segment.visible, "Windows landscape should keep the released V18CPG selector visible"),
		assert_eq(strategy_segment.get_child_count(), 2, "Windows landscape should show both Rule and LLM strategy buttons"),
		assert_eq((strategy_segment.get_child(0) as Button).text, "开发工具包优化版", "The first N's Zoroark strategy button should identify the loaded toolkit strategy"),
		assert_eq((strategy_segment.get_child(1) as Button).text, "大模型版", "The second N's Zoroark strategy button should use the short LLM label"),
		assert_false((strategy_segment.get_child(1) as Button).disabled, "A released 18.0 strategy choice must be clickable"),
		assert_eq(str(scene.call("_selected_ai_strategy_variant_id")), "v18_800018502_ns_zoroark", "Rule should remain the default selected strategy"),
	])
	(strategy_segment.get_child(1) as Button).pressed.emit()
	result = run_checks([
		result,
		assert_eq(
			str(scene.call("_selected_ai_strategy_variant_id")),
			"v18cpg_800018502_ns_zoroark",
			"Clicking the visible 18.0 strategy button must change the live selection"
		),
	])
	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_hidden_author_owner_can_switch_back_to_builtin_v18_ai() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var ai_button := scene.find_child("ModeAIButton", true, false) as Button
	var author_button := scene.find_child("ModeAuthorStrategyButton", true, false) as Button
	mode_option.select(2)
	scene.call("_select_mode_option", 2)

	var author_visible := author_button.visible
	var author_enabled := not author_button.disabled
	ai_button.pressed.emit()
	var selected_after_ai_press := mode_option.selected

	var result := run_checks([
		assert_false(author_visible, "The internal author owner must stay inside the AI battle surface"),
		assert_false(author_enabled, "The hidden legacy author button must not remain interactive"),
		assert_eq(selected_after_ai_press, 1, "Pressing AI battle must leave author mode and restore built-in 18.0 selection"),
	])
	scene.queue_free()
	return result


func test_unified_ai_picker_keeps_builtin_v18_and_large_author_list_reachable() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var player_deck := _make_deck(575716, "玩家测试卡组", "喷火龙ex")
	var builtin_v18 := _make_deck(800018502, "18.0 N的索罗亚克", "N的索罗亚克ex")
	var author_records: Array[Dictionary] = []
	for index: int in 96:
		author_records.append(_make_author_picker_record(index))
	mode_option.select(1)
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [builtin_v18])
	scene.set("_author_strategy_records", author_records)
	scene.call("_apply_deck_option_controls", player_deck, builtin_v18)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "landscape")
	scene.call("_on_deck_picker_pressed", 1)

	var grid := scene.get("_deck_picker_grid") as GridContainer
	var picker_scroll := scene.find_child("DeckPickerScroll", true, false) as ScrollContainer
	var builtin_visible := false
	var last_author_visible := false
	for child: Node in grid.get_children() if grid != null else []:
		if not child is Button:
			continue
		var text := (child as Button).text
		builtin_visible = builtin_visible or text.contains("18.0 N的索罗亚克")
		last_author_visible = last_author_visible or text.begins_with("作者策略 095")

	var result := run_checks([
		assert_true(builtin_visible, "Large author catalogs must not crowd the built-in 18.0 opponent out of the unified picker"),
		assert_true(last_author_visible, "Windows users must be able to scroll to author strategies beyond the old 80-item cutoff"),
		assert_eq(grid.get_child_count() if grid != null else 0, 97, "The unified picker should render the built-in opponent and all test packages"),
		assert_true(picker_scroll != null and picker_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "The Windows AI opponent picker must keep vertical scrolling enabled"),
		assert_eq(picker_scroll.custom_minimum_size.y if picker_scroll != null else -1.0, 0.0, "The picker scroll viewport must consume remaining panel height instead of forcing the panel off-screen"),
	])
	scene.queue_free()
	return result


func test_unified_ai_picker_places_downloaded_strategies_before_bundled_packages_and_builtin_decks() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var builtin_v18 := _make_deck(800018502, "18.0 N的索罗亚克", "N的索罗亚克ex")
	var bundled_package := _make_author_picker_record(8, "built_in")
	var downloaded_package := _make_author_picker_record(7, "user")
	var author_records: Array[Dictionary] = [bundled_package, downloaded_package]
	mode_option.select(1)
	scene.set("_ai_deck_list", [builtin_v18])
	# Reverse the desired order so the picker owner must apply the priority.
	scene.set("_author_strategy_records", author_records)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "landscape")
	scene.call("_on_deck_picker_pressed", 1)

	var grid := scene.get("_deck_picker_grid") as GridContainer
	var first_ref: Dictionary = {}
	var second_ref: Dictionary = {}
	var third_deck_id := -1
	var child_debug: Array[String] = []
	for child: Node in grid.get_children() if grid != null else []:
		child_debug.append("%s|author=%s|deck=%s" % [
			str((child as Button).text) if child is Button else child.name,
			child.get_meta("author_strategy_ref", {}),
			child.get_meta("deck_id", -1),
		])
	if grid != null and grid.get_child_count() >= 3:
		first_ref = grid.get_child(0).get_meta("author_strategy_ref", {})
		second_ref = grid.get_child(1).get_meta("author_strategy_ref", {})
		third_deck_id = int(grid.get_child(2).get_meta("deck_id", -1))
	var result := run_checks([
		assert_eq(str(first_ref.get("package_id", "")), "pkg.large.007", "A newly downloaded user strategy should be the first AI opponent choice; children=%s mode=%s" % [child_debug, mode_option.selected]),
		assert_eq(str(second_ref.get("package_id", "")), "pkg.large.008", "Bundled author packages should follow downloaded strategies"),
		assert_eq(third_deck_id, builtin_v18.id, "Classic built-in AI decks should follow author strategy packages without disappearing"),
	])
	scene.queue_free()
	return result


func test_windows_landscape_battle_setup_scrolls_when_ai_settings_overflow() -> String:
	var scene := _make_scene_ready()
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "landscape")
	var scroll := scene.find_child("LandscapeSetupScroll", true, false) as ScrollContainer
	var result := run_checks([
		assert_not_null(scroll, "Windows landscape setup should own an overflow viewport"),
		assert_true(scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Windows landscape AI settings must remain vertically scrollable below the screen edge"),
		assert_true(scroll != null and scroll.get_v_scroll_bar().mouse_filter == Control.MOUSE_FILTER_STOP, "The Windows scrollbar must accept mouse dragging"),
	])
	scene.queue_free()
	return result


func test_windows_landscape_setup_hud_uses_full_height_and_shows_start_without_initial_scroll() -> String:
	var config_snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 60.0,
		"ai_test_passed": true,
		"ai_test_signature": "hud-layout-test",
	})
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_restore_battle_review_config_file(config_snapshot)
		return "SceneTree is required for the real battle-setup HUD regression"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	tree.root.add_child(viewport)
	var scene: Control = BattleSetupScene.instantiate()
	viewport.add_child(scene)
	await tree.process_frame
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "landscape")
	await tree.process_frame
	await tree.process_frame

	var setup_frame := scene.find_child("SetupFrame", true, false) as PanelContainer
	var scroll := scene.find_child("LandscapeSetupScroll", true, false) as ScrollContainer
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var frame_rect := setup_frame.get_global_rect() if setup_frame != null else Rect2()
	var scroll_rect := scroll.get_global_rect() if scroll != null else Rect2()
	var start_rect := start_button.get_global_rect() if start_button != null else Rect2()
	var vbar := scroll.get_v_scroll_bar() if scroll != null else null
	var left_vbox := scene.find_child("LeftVBox", true, false) as VBoxContainer
	var right_vbox := scene.find_child("RightVBox", true, false) as VBoxContainer
	var initially_scrollable := vbar != null and vbar.max_value > vbar.page + 0.5
	var result := run_checks([
		assert_true(setup_frame != null and frame_rect.size.y >= 688.0, "The 720p battle-setup HUD should use nearly the full window height; frame=%s scroll=%s start=%s left=%s/%s right=%s/%s range=%s/%s" % [frame_rect, scroll_rect, start_rect, left_vbox.size if left_vbox != null else Vector2.ZERO, left_vbox.get_combined_minimum_size() if left_vbox != null else Vector2.ZERO, right_vbox.size if right_vbox != null else Vector2.ZERO, right_vbox.get_combined_minimum_size() if right_vbox != null else Vector2.ZERO, vbar.max_value if vbar != null else -1.0, vbar.page if vbar != null else -1.0]),
		assert_true(setup_frame != null and frame_rect.position.x >= 0.0 and frame_rect.end.x <= 1280.0, "The landscape setup HUD must stay within the Windows viewport width; frame=%s" % frame_rect),
		assert_false(initially_scrollable, "The default AI settings should fit without an initial right-side scrollbar; range=%s/%s frame=%s scroll=%s start=%s" % [vbar.max_value if vbar != null else -1.0, vbar.page if vbar != null else -1.0, frame_rect, scroll_rect, start_rect]),
		assert_true(vbar == null or not vbar.visible, "The right-side scrollbar must stay visually hidden until the settings actually overflow"),
		assert_true(start_button != null and start_button.is_visible_in_tree(), "The start-battle button must be visible on initial Windows layout"),
		assert_true(start_button != null and start_rect.position.y >= scroll_rect.position.y and start_rect.end.y <= scroll_rect.end.y, "The start-battle button must be fully exposed in the first HUD viewport; scroll=%s start=%s" % [scroll_rect, start_rect]),
	])
	viewport.queue_free()
	await tree.process_frame
	_restore_battle_review_config_file(config_snapshot)
	return result


func test_windows_landscape_ai_picker_stays_onscreen_with_saved_portrait_preference() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var builtin_v18 := _make_deck(800018502, "18.0 N的索罗亚克", "N的索罗亚克ex")
	var author_records: Array[Dictionary] = []
	for index: int in 96:
		author_records.append(_make_author_picker_record(index))
	mode_option.select(1)
	scene.set("_ai_deck_list", [builtin_v18])
	scene.set("_author_strategy_records", author_records)
	# Reproduce a Windows landscape window while an older saved setting still
	# requests the portrait non-battle profile.
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "portrait")
	scene.call("_on_deck_picker_pressed", 1)

	var panel := scene.find_child("DeckPickerPanel", true, false) as PanelContainer
	var picker_scroll := scene.find_child("DeckPickerScroll", true, false) as ScrollContainer
	var panel_rect := Rect2(panel.position, panel.size) if panel != null else Rect2()
	var result := run_checks([
		assert_true(panel != null and panel_rect.position.y >= 0.0, "The AI picker must not start above the Windows viewport"),
		assert_true(panel != null and panel_rect.end.y <= 720.0, "A saved portrait preference must not push the AI picker below a 720p Windows viewport"),
		assert_true(picker_scroll != null and picker_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "The bounded AI picker must keep the large strategy list scrollable"),
	])
	scene.queue_free()
	return result


func test_windows_ai_picker_large_catalog_has_a_real_scroll_viewport() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree is required for the real picker-layout regression"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	tree.root.add_child(viewport)
	var scene: Control = BattleSetupScene.instantiate()
	viewport.add_child(scene)
	await tree.process_frame

	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var builtin_v18 := _make_deck(800018502, "18.0 N的索罗亚克", "N的索罗亚克ex")
	var author_records: Array[Dictionary] = []
	for index: int in 96:
		author_records.append(_make_author_picker_record(index))
	mode_option.select(1)
	scene.set("_ai_deck_list", [builtin_v18])
	scene.set("_author_strategy_records", author_records)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "portrait")
	scene.call("_on_deck_picker_pressed", 1)
	await tree.process_frame
	await tree.process_frame

	var panel := scene.find_child("DeckPickerPanel", true, false) as PanelContainer
	var picker_scroll := scene.find_child("DeckPickerScroll", true, false) as ScrollContainer
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var panel_rect := panel.get_global_rect() if panel != null else Rect2()
	var vbar := picker_scroll.get_v_scroll_bar() if picker_scroll != null else null
	var picker_root := scene.find_child("DeckPickerRoot", true, false) as VBoxContainer
	var can_scroll := vbar != null and vbar.max_value > vbar.page
	if picker_scroll != null and can_scroll:
		picker_scroll.scroll_vertical = int(vbar.max_value - vbar.page)
	await tree.process_frame
	var result := run_checks([
		assert_true(
			panel != null and panel_rect.position.y >= 0.0 and panel_rect.end.y <= 720.0,
			"The laid-out HUD picker panel must remain entirely inside the 720p viewport; rect=%s panel_min=%s root_min=%s scroll=%s scroll_min=%s grid=%s range=%s/%s" % [
				panel_rect,
				panel.get_combined_minimum_size() if panel != null else Vector2.ZERO,
				picker_root.get_combined_minimum_size() if picker_root != null else Vector2.ZERO,
				picker_scroll.size if picker_scroll != null else Vector2.ZERO,
				picker_scroll.get_combined_minimum_size() if picker_scroll != null else Vector2.ZERO,
				grid.size if grid != null else Vector2.ZERO,
				vbar.max_value if vbar != null else -1.0,
				vbar.page if vbar != null else -1.0,
			]
		),
		assert_true(picker_scroll != null and picker_scroll.size.y > 0.0, "The strategy list must receive a non-zero real scroll viewport"),
		assert_true(grid != null and picker_scroll != null and grid.size.y > picker_scroll.size.y, "A large strategy catalog must overflow inside the scroll viewport, not expand the HUD panel"),
		assert_true(can_scroll, "The real Windows scrollbar must have scrollable range for 96 strategies"),
		assert_true(picker_scroll != null and picker_scroll.scroll_vertical > 0, "The real Windows list must accept a downward scroll position"),
	])
	viewport.queue_free()
	await tree.process_frame
	return result


func test_battle_setup_exposes_rule_and_cpg_for_all_v18_decks() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	var deck2_option := scene.find_child(
		"Deck2Option",
		true,
		false
	) as OptionButton
	var mode_option := scene.find_child(
		"ModeOption",
		true,
		false
	) as OptionButton
	var strategy_option := scene.find_child(
		"AIStrategyOption",
		true,
		false
	) as OptionButton
	var checks: Array[String] = []
	mode_option.select(1)
	for deck_id: int in V18CPGProfileCatalogScript.ALL_DECK_IDS:
		var profile := V18CPGProfileCatalogScript.get_profile_for_deck(
			deck_id
		)
		var deck := _make_deck(
			deck_id,
			str(profile.get("display_name", "18.0 %d" % deck_id))
		)
		scene.set("_ai_deck_list", [deck])
		deck2_option.clear()
		deck2_option.add_item(deck.deck_name)
		deck2_option.set_item_metadata(0, deck.id)
		deck2_option.select(0)
		scene.call("_refresh_ai_ui_visibility")
		var ids: Array[String] = []
		for index: int in strategy_option.get_item_count():
			ids.append(str(strategy_option.get_item_metadata(index)))
		checks.append(assert_eq(
			ids,
			[
				str(profile.get("base_strategy_id", "")),
				str(profile.get("strategy_id", "")),
			],
			"%d should expose Rule and V18CPG in BattleSetup" % deck_id
		))
	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return run_checks(checks)


func test_battle_setup_saved_llm_variant_overrides_prebuilt_rule_selection() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 60.0,
	})
	var scene := _make_scene_ready()
	var gardevoir := _make_deck(800018497, "18.0 沙奈朵", "沙奈朵ex")
	scene.set("_ai_deck_list", [gardevoir])
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	deck2_option.clear()
	deck2_option.add_item(gardevoir.deck_name)
	deck2_option.set_item_metadata(0, gardevoir.id)
	deck2_option.select(0)
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_select_ai_strategy_option", 0)
	var initial_id := str(scene.call("_selected_ai_strategy_variant_id"))

	scene.set("_pending_ai_strategy_variant_id", "v18cpg_800018497_gardevoir")
	scene.call("_refresh_ai_strategy_variant_options")
	var restored_id := str(scene.call("_selected_ai_strategy_variant_id"))

	var result := run_checks([
		assert_eq(initial_id, "v18_800018497_gardevoir", "A newly built selector should initially use the rules variant"),
		assert_eq(restored_id, "v18cpg_800018497_gardevoir", "A persisted LLM variant must override the selector's prebuilt rules value"),
		assert_eq(str(scene.get("_pending_ai_strategy_variant_id")), "", "The persisted variant request should be consumed exactly once"),
	])
	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_missing_saved_llm_variant_falls_back_to_rules() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 60.0,
	})
	var scene := _make_scene_ready()
	var gardevoir := _make_deck(800018497, "18.0 沙奈朵", "沙奈朵ex")
	scene.set("_ai_deck_list", [gardevoir])
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	deck2_option.clear()
	deck2_option.add_item(gardevoir.deck_name)
	deck2_option.set_item_metadata(0, gardevoir.id)
	deck2_option.select(0)
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_select_ai_strategy_option", 1)

	scene.set("_pending_ai_strategy_variant_id", "removed_llm_variant")
	scene.call("_refresh_ai_strategy_variant_options")
	var restored_id := str(scene.call("_selected_ai_strategy_variant_id"))

	var result := run_checks([
		assert_eq(restored_id, "v18_800018497_gardevoir", "An unavailable persisted LLM variant must safely fall back to rules"),
		assert_eq(str(scene.get("_pending_ai_strategy_variant_id")), "", "An unavailable persisted variant should not be retried forever"),
	])
	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_llm_variant_round_trips_through_settings_file() -> String:
	var api_snapshot := _snapshot_battle_review_config_file()
	var settings_snapshot := _snapshot_battle_setup_settings_file()
	_write_battle_review_config_for_test({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 60.0,
	})
	var scene := _make_scene_ready()
	var player_deck := _make_deck(575716, "player")
	var gardevoir := _make_deck(800018497, "18.0 沙奈朵", "沙奈朵ex")
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [gardevoir])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	deck1_option.clear()
	deck1_option.add_item(player_deck.deck_name)
	deck1_option.set_item_metadata(0, player_deck.id)
	deck1_option.select(0)
	deck2_option.clear()
	deck2_option.add_item(gardevoir.deck_name)
	deck2_option.set_item_metadata(0, gardevoir.id)
	deck2_option.select(0)
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_select_ai_strategy_option", 1)
	scene.call("_save_settings")

	scene.call("_select_ai_strategy_option", 0)
	scene.call("_load_settings")
	scene.call("_refresh_ai_ui_visibility")
	var restored_id := str(scene.call("_selected_ai_strategy_variant_id"))

	var result := run_checks([
		assert_eq(restored_id, "v18cpg_800018497_gardevoir", "The selected LLM variant must survive a battle_setup.json save/load round trip"),
	])
	scene.queue_free()
	_restore_battle_setup_settings_file(settings_snapshot)
	_restore_battle_review_config_file(api_snapshot)
	return result


func test_battle_setup_defaults_to_rules_model_without_llm_api() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "",
		"model": "kimi-k3",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var strategy_segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var model_row := scene.find_child("LLMModelRow", true, false) as HBoxContainer
	var discuss_button := scene.find_child("BtnDiscussStrategyAI", true, false) as Button
	var status_title := scene.find_child("AIModeStatusTitle", true, false) as Label
	var status_body := scene.find_child("AIModeStatusBody", true, false) as Label
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	var strategy_button: Button = null
	if strategy_segment != null and strategy_segment.get_child_count() > 0:
		strategy_button = strategy_segment.get_child(0) as Button

	var result := run_checks([
		assert_true(status_title.visible, "AI mode should show the current AI mode status"),
		assert_str_contains(status_title.text, "规则模型", "No API configured should clearly identify the rules model"),
		assert_false(status_title.text.contains("："), "AI mode title should avoid full-width colon for Android glyph compatibility"),
		assert_str_contains(status_body.text, "速度快", "Rules model copy should state the speed tradeoff"),
		assert_str_contains(status_body.text, "能力较低", "Rules model copy should state the capability tradeoff"),
		assert_str_contains(status_body.text, "不用设置", "Rules model copy should state that no setup is required"),
		assert_true(strategy_segment != null and strategy_segment.visible, "Supported AI decks should still show the current AI work mode"),
		assert_false(strategy_option.visible, "Legacy strategy dropdown should stay hidden behind the HUD segment"),
		assert_true(strategy_option.disabled, "Without API there should be no LLM strategy to select"),
		assert_eq(strategy_option.get_item_count(), 1, "Without API the strategy selector should only contain the rules model"),
		assert_eq(strategy_option.get_item_text(0), "规则版", "The only available AI mode should use the short rules label"),
		assert_eq(strategy_segment.get_child_count() if strategy_segment != null else 0, 1, "Without API the HUD segment should only contain the rules model"),
		assert_true(strategy_button != null and strategy_button.disabled, "The single rules-mode segment should be shown as the locked current mode"),
		assert_eq(strategy_button.text if strategy_button != null else "", strategy_option.get_item_text(0), "HUD segment should mirror the hidden strategy label"),
		assert_false(model_row.visible, "LLM model controls should stay hidden until API is configured"),
		assert_false(discuss_button.visible, "Strategy discussion should stay hidden until API is configured"),
	])
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_llm_strategy_explains_api_and_thinking_cost() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "z-ai/glm-5.2",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var status_title := scene.find_child("AIModeStatusTitle", true, false) as Label
	var status_body := scene.find_child("AIModeStatusBody", true, false) as Label
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	strategy_option.select(1)
	scene.call("_on_ai_strategy_variant_changed", 1)

	var result := run_checks([
		assert_str_contains(status_title.text, "大模型", "Selecting an LLM strategy should identify the LLM mode"),
		assert_false(status_title.text.contains("："), "LLM mode title should avoid full-width colon for Android glyph compatibility"),
		assert_str_contains(status_body.text, "GLM 5.2", "LLM mode copy should name the selected model"),
		assert_str_contains(status_body.text, "思考时间", "LLM mode copy should set wait-time expectations"),
		assert_str_contains(status_body.text, "能力中等", "LLM mode copy should state the capability level"),
		assert_str_contains(status_body.text, "模型 API", "LLM mode copy should explain the API requirement"),
	])
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_strategy_variant_labels_are_readable_chinese() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k3",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var strategy_segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	var rules_button: Button = null
	var llm_button: Button = null
	if strategy_segment != null and strategy_segment.get_child_count() > 0:
		rules_button = strategy_segment.get_child(0) as Button
	if strategy_segment != null and strategy_segment.get_child_count() > 1:
		llm_button = strategy_segment.get_child(1) as Button

	var result := run_checks([
		assert_true(strategy_segment != null and strategy_segment.visible, "Miraidon AI should expose strategy variant choices when API is configured"),
		assert_false(strategy_option.visible, "Legacy strategy dropdown should stay hidden when the HUD segment is visible"),
		assert_eq(strategy_option.get_item_text(0), "规则版", "Rules strategy should use the short label"),
		assert_eq(strategy_option.get_item_text(1), "大模型版", "LLM strategy should use the short label"),
		assert_eq(rules_button.text if rules_button != null else "", "规则版", "Rules segment button should mirror the short label"),
		assert_eq(llm_button.text if llm_button != null else "", "大模型版", "LLM segment button should mirror the short label"),
	])
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_all_strategy_variant_labels_use_chinese_naming() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k3",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var supported_deck_ids := [
		575716, 575720, 569061, 575657, 609431, 578647, 610080, 575718,
		579502, 575723, 1700002, 1700003, 1700004, 1700005, 1700007,
		1700008, 1700011,
	]
	var checks: Array[String] = []
	for deck_id: int in supported_deck_ids:
		scene.call("_select_option_for_deck_id", deck2_option, deck_id)
		var variants: Array = scene.call("_detect_ai_strategy_variants")
		var labels: Array[String] = []
		for variant: Dictionary in variants:
			labels.append(str(variant.get("label", "")))
		checks.append(assert_eq(labels, ["规则版", "大模型版"], "Deck %d strategy labels should use the short rules/LLM naming" % deck_id))
	_restore_battle_review_config_file(snapshot)
	return run_checks(checks)


func test_battle_setup_exposes_llm_variants_for_all_selectable_llm_decks() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k3",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var expected := {
		575716: "charizard_ex_llm",
		575720: "miraidon_llm",
		569061: "arceus_giratina_llm",
		575657: "lugia_archeops_llm",
		609431: "v175_lugia_archeops_llm",
		578647: "gardevoir_llm",
		610080: "v175_gardevoir_llm",
		575718: "raging_bolt_ogerpon_llm",
		579502: "dragapult_charizard_llm",
		575723: "dragapult_dusknoir_llm",
		1700002: "v17_archaludon_dialga_llm",
		1700003: "v17_water_turtle_llm",
		1700004: "v17_palkia_gholdengo_llm",
		1700005: "v17_bomb_charizard_llm",
		1700007: "v17_miraidon_llm",
		1700008: "v17_dragapult_dusknoir_llm",
		1700011: "v17_regidrago_llm",
	}
	var checks: Array[String] = []
	for deck_id: int in expected.keys():
		scene.call("_select_option_for_deck_id", deck2_option, deck_id)
		var strategy_id := str(scene.call("_selected_ai_strategy_id"))
		var variants: Array = scene.call("_detect_ai_strategy_variants")
		var ids := _variant_ids(variants)
		checks.append(assert_true(str(expected[deck_id]) in ids, "Deck %d should expose %s behind the API gate" % [deck_id, expected[deck_id]]))
		checks.append(assert_eq(str(ids[0]) if not ids.is_empty() else "", strategy_id, "Deck %d should keep the rules strategy first" % deck_id))
	_restore_battle_review_config_file(snapshot)
	return run_checks(checks)


func test_battle_setup_selected_llm_strategy_shows_current_model_name() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "z-ai/glm-5.2",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var current_model_label := scene.find_child("AIModelCurrentLabel", true, false) as Label
	var redundant_model_label := scene.find_child("LLMModelLabel", true, false) as Label
	var discuss_button := scene.find_child("BtnDiscussStrategyAI", true, false) as Button
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	strategy_option.select(1)
	scene.call("_on_ai_strategy_variant_changed", 1)

	var result := run_checks([
		assert_true(current_model_label.visible, "Selecting an LLM strategy should reveal the current model label"),
		assert_str_contains(current_model_label.text, "GLM 5.2", "Current model label should show the concrete model name"),
		assert_false(current_model_label.text.contains("："), "Current model label should avoid full-width colon for Android glyph compatibility"),
		assert_false(redundant_model_label.visible, "Selecting an LLM strategy should not show a redundant standalone model label"),
		assert_str_contains(discuss_button.text, "GLM 5.2", "Discussion button should show the concrete model name"),
		assert_false(discuss_button.text.contains("《") or discuss_button.text.contains("》"), "Discussion button should avoid guillemets for Android glyph compatibility"),
	])
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_populates_ai_source_options() -> String:
	var scene := _make_scene_ready()
	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton

	return run_checks([
		assert_eq(ai_source_option.get_item_count(), 3, "AI source should have three options"),
		assert_eq(ai_source_option.get_item_text(0), "默认 AI", "Option 0 should be default AI"),
		assert_eq(ai_source_option.get_item_text(1), "最新训练版 AI", "Option 1 should be latest trained AI"),
		assert_eq(ai_source_option.get_item_text(2), "指定训练版本 AI", "Option 2 should be specific trained AI"),
	])


func test_battle_setup_refreshes_ai_version_options_from_registry() -> String:
	var scene := _make_scene_ready()
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-20260328-01",
			"display_name": "v015 + value1",
			"benchmark_summary": {"win_rate_vs_current_best": 0.57},
		},
		{
			"version_id": "AI-20260328-02",
			"display_name": "v016 + value2",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton

	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 2, "AI version dropdown should reflect playable versions"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-20260328-01", "First option should include version_id"),
		assert_str_contains(ai_version_option.get_item_text(0), "v015 + value1", "First option should include display_name"),
		assert_str_contains(ai_version_option.get_item_text(1), "AI-20260328-02", "Second option should include version_id"),
	])


func test_battle_setup_filters_ai_versions_to_selected_ai_strategy() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-MIRAIDON-01",
			"display_name": "miraidon build",
			"compatible_strategy_id": "miraidon",
		},
		{
			"version_id": "AI-GARDEVOIR-01",
			"display_name": "gardevoir build",
			"compatible_strategy_id": "gardevoir",
		},
		{
			"version_id": "AI-DRAGAPULT-01",
			"display_name": "dragapult build",
			"compatible_strategy_id": "dragapult_charizard",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton
	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 1, "AI version dropdown should only show versions compatible with the selected AI deck strategy"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-MIRAIDON-01", "Miraidon deck selection should keep the Miraidon-compatible version"),
	])


func test_battle_setup_ai_mode_limits_ai_decks_to_supported_shortlist() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var supported_ids: Array[int] = CardDatabase.get_supported_ai_deck_ids()
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var resolved_ids: Array[int] = []
	for i: int in deck2_option.item_count:
		deck2_option.select(i)
		var deck := scene.call("_selected_deck_for_slot", 1) as DeckData
		if deck != null:
			resolved_ids.append(deck.id)
	var missing_v18_ids: Array[int] = []
	var catalog_v18_ids: Array[int] = DeckStrategyV18ProfileCatalogScript.deck_ids()
	var resolved_v18_ids: Array[int] = []
	for deck_id: int in catalog_v18_ids:
		if deck_id not in resolved_ids:
			missing_v18_ids.append(deck_id)
	for deck_id: int in resolved_ids:
		if deck_id in catalog_v18_ids:
			resolved_v18_ids.append(deck_id)

	return run_checks([
		assert_eq(deck2_option.item_count, supported_ids.size(), "AI mode should only expose the supported AI decks"),
		assert_true(575716 in resolved_ids, "AI deck list should include Charizard ex / Pidgeot ex"),
		assert_true(575720 in resolved_ids, "AI deck list should include Miraidon"),
		assert_true(569061 in resolved_ids, "AI deck list should include Arceus / Giratina"),
		assert_true(575657 in resolved_ids, "AI deck list should include Lugia / Archeops"),
		assert_true(578647 in resolved_ids, "AI deck list should include Gardevoir"),
		assert_true(575718 in resolved_ids, "AI deck list should include Raging Bolt / Ogerpon"),
		assert_true(579502 in resolved_ids, "AI deck list should include Dragapult / Charizard"),
		assert_true(575723 in resolved_ids, "AI deck list should include Dragapult / Dusknoir"),
		assert_true(609431 in resolved_ids, "AI deck list should include 17.5 Lugia / Archeops"),
		assert_true(610080 in resolved_ids, "AI deck list should include 17.5 Gardevoir"),
		assert_true(1700002 in resolved_ids, "AI deck list should include 17.0 Archaludon / Dialga"),
		assert_true(1700003 in resolved_ids, "AI deck list should include 17.0 Water turtle"),
		assert_true(1700004 in resolved_ids, "AI deck list should include 17.0 Palkia / Gholdengo"),
		assert_true(1700005 in resolved_ids, "AI deck list should include 17.0 Bomb Charizard"),
		assert_true(1700007 in resolved_ids, "AI deck list should include 17.0 Miraidon"),
		assert_true(1700008 in resolved_ids, "AI deck list should include 17.0 Dragapult / Dusknoir"),
		assert_true(1700011 in resolved_ids, "AI deck list should include 17.0 Regidrago"),
		assert_eq(missing_v18_ids, [], "AI deck list should include all 25 registered 18.0 rule-AI decks"),
		assert_eq(resolved_v18_ids, EXPECTED_V18_STRENGTH_ORDER_IDS, "AI deck dropdown should order all 18.0 decks by final normal win rate, using strong win rate as the tie-breaker"),
	])


func test_battle_setup_ai_mode_lists_v18_ai_decks_first() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var leading_are_v18 := true
	for i: int in mini(3, deck2_option.item_count):
		var deck_id := int(deck2_option.get_item_metadata(i))
		var deck := CardDatabase.get_ai_deck(deck_id)
		leading_are_v18 = leading_are_v18 and deck != null and deck.deck_name.begins_with("18.0")

	return run_checks([
		assert_true(leading_are_v18, "Battle setup AI deck dropdown should show supported 18.0 AI decks first"),
	])


func test_battle_setup_ai_mode_selects_first_v18_ai_deck_by_default() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var selected_id := int(deck2_option.get_item_metadata(deck2_option.selected)) if deck2_option.selected >= 0 else -1
	var selected_deck := scene.call("_selected_deck_for_slot", 1) as DeckData
	return run_checks([
		assert_true(selected_id in DeckStrategyV18ProfileCatalogScript.deck_ids(), "Switching to AI mode should default to a supported 18.0 AI deck"),
		assert_true(selected_deck != null and selected_deck.deck_name.begins_with("18.0"), "Default AI deck should be labeled as 18.0"),
	])


func test_battle_setup_ai_deck_picker_opens_all_with_v18_ai_decks_first() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var picker_category := str(scene.call("_default_deck_picker_category", 1))
	var all_decks: Array = scene.call("_decks_for_picker", 1, "all", "")
	var recent_decks: Array = scene.call("_decks_for_picker", 1, "recent", "")
	var all_v18_ids: Array[int] = []
	var recent_v18_ids: Array[int] = []
	var catalog_v18_ids: Array[int] = DeckStrategyV18ProfileCatalogScript.deck_ids()
	for deck: DeckData in all_decks:
		if deck.id in catalog_v18_ids:
			all_v18_ids.append(deck.id)
	for deck: DeckData in recent_decks:
		if deck.id in catalog_v18_ids:
			recent_v18_ids.append(deck.id)

	return run_checks([
		assert_eq(picker_category, "all", "AI deck picker should open on the creation-time ordered full list"),
		assert_eq(all_v18_ids, EXPECTED_V18_STRENGTH_ORDER_IDS, "AI deck picker All category should order every 18.0 deck by benchmark strength"),
		assert_eq(recent_v18_ids, EXPECTED_V18_STRENGTH_ORDER_IDS, "AI deck picker Recent category should preserve the same 18.0 benchmark-strength order"),
	])


func test_battle_setup_ai_deck_picker_marks_llm_supported_decks_and_explains_star() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var player_deck := _make_deck(99000001, "Player Deck")
	var llm_deck := _make_deck(575716, "LLM Charizard", "Charizard ex")
	var released_v18_llm_deck := _make_deck(800018509, "18.0 LLM Raging Bolt")
	var rules_only_deck := _make_deck(561444, "Rules Dialga", "Dialga VSTAR")
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [llm_deck, released_v18_llm_deck, rules_only_deck])
	scene.call("_apply_deck_option_controls", player_deck, llm_deck)

	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var option_labels_by_id := {}
	for index: int in deck2_option.item_count:
		option_labels_by_id[int(deck2_option.get_item_metadata(index))] = deck2_option.get_item_text(index)

	scene.set("_deck_picker_slot_index", 1)
	scene.set("_deck_picker_category", "all")
	scene.set("_deck_picker_search", "")
	scene.call("_ensure_deck_picker_overlay")
	scene.call("_refresh_deck_picker")
	var legend := scene.find_child("DeckPickerLLMLegend", true, false) as Label
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var picker_labels: Array[String] = []
	for child: Node in grid.get_children():
		if child is Button:
			picker_labels.append((child as Button).text)
	var selected_button := scene.find_child("Deck2PickerButton", true, false) as Button
	var ai_legend_visible := legend != null and legend.visible
	scene.set("_deck_picker_slot_index", 0)
	scene.call("_refresh_deck_picker")
	var player_legend_hidden := legend != null and not legend.visible

	return run_checks([
		assert_eq(str(option_labels_by_id.get(575716, "")), "LLM Charizard * (60张)", "The AI deck option list should suffix LLM-supported decks with a star"),
		assert_eq(str(option_labels_by_id.get(800018509, "")), "18.0 LLM Raging Bolt * (60张)", "Released V18 LLM decks should receive the same automatic support star"),
		assert_eq(str(option_labels_by_id.get(561444, "")), "Rules Dialga (60张)", "Rules-only AI decks must not receive the LLM support star"),
		assert_true("LLM Charizard *" in picker_labels, "The visible AI deck picker HUD should mark an LLM-supported deck"),
		assert_true("18.0 LLM Raging Bolt *" in picker_labels, "The visible AI deck picker HUD should mark released V18 LLM decks"),
		assert_true("Rules Dialga" in picker_labels, "The visible AI deck picker HUD should keep rules-only names unchanged"),
		assert_eq(selected_button.text if selected_button != null else "", "LLM Charizard *", "The selected AI deck HUD button should preserve the support star"),
		assert_true(ai_legend_visible, "The AI deck picker HUD should show the star explanation above the list"),
		assert_true(player_legend_hidden, "The star explanation should stay hidden for the player deck picker"),
		assert_str_contains(legend.text if legend != null else "", "*", "The AI deck picker legend should identify the star symbol"),
		assert_str_contains(legend.text if legend != null else "", "大模型版 AI", "The AI deck picker legend should explain that starred decks support the LLM AI"),
	])


func test_battle_setup_player_deck_picker_sorts_all_decks_by_updated_at_desc() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(0)
	scene.call("_on_mode_changed", 0)

	var newest_bundled: DeckData = CardDatabase._load_deck_from_file("res://data/bundled_user/decks/1700001.json")
	if newest_bundled == null:
		return "Bundled baseline deck should load for battle setup ordering coverage"
	newest_bundled.updated_at = 3000
	var middle_player_deck := DeckData.new()
	middle_player_deck.id = 99000001
	middle_player_deck.deck_name = "player created deck"
	middle_player_deck.updated_at = 2000
	middle_player_deck.total_cards = 60
	var oldest_v18_deck := DeckData.new()
	oldest_v18_deck.id = 99000002
	oldest_v18_deck.deck_name = "18.0 old edited deck"
	oldest_v18_deck.updated_at = 1000
	oldest_v18_deck.total_cards = 60
	scene.set("_deck_list", [oldest_v18_deck, middle_player_deck, newest_bundled])

	var all_decks: Array = scene.call("_decks_for_picker", 0, "all", "")
	var sorted_ids: Array[int] = []
	for deck: DeckData in all_decks:
		sorted_ids.append(deck.id)
	return run_checks([
		assert_eq(
			sorted_ids,
			[newest_bundled.id, middle_player_deck.id, oldest_v18_deck.id],
			"Battle setup player deck picker should sort by updated_at without pinning 18.0 or modified decks",
		),
	])


func test_battle_setup_filters_dragapult_charizard_ai_versions() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 579502)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-DRAGAPULT-01",
			"display_name": "dragapult build",
			"compatible_strategy_id": "dragapult_charizard",
		},
		{
			"version_id": "AI-MIRAIDON-01",
			"display_name": "miraidon build",
			"compatible_strategy_id": "miraidon",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton
	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 1, "Dragapult / Charizard AI selection should only show compatible versions"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-DRAGAPULT-01", "Dragapult / Charizard selection should keep the deck-local version"),
	])


func test_selected_deck_for_ai_slot_reads_dedicated_ai_deck_list() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)

	var player_deck := _make_deck(700001, "player-deck", "Player Signature")
	var ai_deck := _make_deck(700002, "ai-deck", "AI Signature")
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [ai_deck])

	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("player-deck", 0)
	deck2_option.add_item("ai-deck", 0)
	deck1_option.select(0)
	deck2_option.select(0)

	var selected_ai_deck := scene.call("_selected_deck_for_slot", 1) as DeckData
	return run_checks([
		assert_not_null(selected_ai_deck, "AI slot should still resolve a selected deck in VS_AI mode"),
		assert_eq(selected_ai_deck.id if selected_ai_deck != null else -1, 700002, "AI slot should resolve from the dedicated AI deck list instead of the player deck list"),
	])


func test_apply_setup_selection_writes_default_ai_selection() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(0)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "default", "Default source should write default"),
		assert_eq(str(selection.get("version_id", "")), "", "Default source should not bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "", "Default source should not bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "", "Default source should not bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "", "Default source should not bind display_name"),
	])


func test_apply_setup_selection_enables_fixed_order_for_strong_miraidon_ai() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 575720)
	preview_option.select(1)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection.duplicate(true)

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed for strong Miraidon AI"),
		assert_eq(str(selection.get("opening_mode", "")), "fixed_order", "Strong Miraidon AI should enable fixed opening mode"),
		assert_eq(
			str(selection.get("fixed_deck_order_path", "")),
			"res://data/bundled_user/ai_fixed_deck_orders/575720.json",
			"Strong Miraidon AI should bind the bundled fixed deck order path"
		),
	])


func test_apply_setup_selection_enables_fixed_order_for_strong_v175_lugia_ai() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 609431)
	preview_option.select(1)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection.duplicate(true)

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed for strong 17.5 Lugia AI"),
		assert_eq(str(selection.get("opening_mode", "")), "fixed_order", "Strong 17.5 Lugia AI should enable fixed opening mode"),
		assert_eq(
			str(selection.get("fixed_deck_order_path", "")),
			"res://data/bundled_user/ai_fixed_deck_orders/609431.json",
			"Strong 17.5 Lugia AI should bind the bundled fixed deck order path"
		),
	])


func test_apply_setup_selection_resolves_filtered_ai_deck_ids_in_ai_mode() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck1Option", true, false), 575716)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 569061)

	var ok: bool = scene.call("_apply_setup_selection")
	var selected_ids: Array = GameManager.selected_deck_ids.duplicate()

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed in AI mode with a filtered deck list"),
		assert_eq(int(selected_ids[0]), 575716, "Player deck should still resolve correctly"),
		assert_eq(int(selected_ids[1]), 569061, "Filtered AI deck selection should resolve to Arceus / Giratina by deck id"),
	])


func test_capture_setup_selection_context_no_longer_persists_legacy_ai_strategy() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var context: Dictionary = scene.call("_capture_setup_selection_context")
	return run_checks([
		assert_false(context.has("ai_strategy"), "Deck-driven setup should not persist the removed ai_strategy field"),
	])


func test_apply_setup_selection_writes_latest_trained_ai_selection() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [{
		"version_id": "AI-20260328-03",
		"display_name": "v017 + value3",
		"agent_config_path": "user://ai_agents/agent_v017.json",
		"value_net_path": "user://ai_models/value_net_v3.json",
	}]
	scene.call("set_ai_version_registry_for_test", registry)

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(1)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection
	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "latest_trained", "Latest source should write latest_trained"),
		assert_eq(str(selection.get("version_id", "")), "AI-20260328-03", "Latest source should bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "user://ai_agents/agent_v017.json", "Latest source should bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "user://ai_models/value_net_v3.json", "Latest source should bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "v017 + value3", "Latest source should bind display_name"),
	])


func test_apply_setup_selection_falls_back_to_default_when_specific_version_missing() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	scene.call("set_ai_version_registry_for_test", FakeAIVersionRegistry.new())

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(2)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection
	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "default", "Missing specific version should fall back to default"),
		assert_eq(str(selection.get("version_id", "")), "", "Fallback should not bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "", "Fallback should not bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "", "Fallback should not bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "", "Fallback should not bind display_name"),
	])


func test_apply_setup_context_ignores_legacy_ai_strategy_and_keeps_explicit_ai_deck() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	scene.call("_apply_setup_context", {
		"deck1_id": 575716,
		"deck2_id": 575720,
		"mode": 1,
		"ai_strategy": 2,
	})
	var selected_deck := scene.call("_selected_deck_for_slot", 1) as DeckData
	return run_checks([
		assert_true(deck2_option.selected >= 0, "Legacy ai_strategy state should still leave an explicit AI deck selected"),
		assert_not_null(selected_deck, "Selected AI deck should still resolve after applying legacy context"),
		assert_eq(selected_deck.id, 575720, "Applying old ai_strategy state should preserve the requested AI deck"),
	])


func test_battle_setup_hides_legacy_ai_strategy_controls_even_in_ai_mode() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var ai_strategy_label := scene.find_child("AIStrategyLabel", true, false) as Label
	var ai_strategy_segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var ai_strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var dummy_deck := _make_deck(999, "TestDeck", "Pikachu")
	scene.set("_ai_deck_list", [dummy_deck])
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	deck2_option.clear()
	deck2_option.add_item("TestDeck")
	deck2_option.select(0)
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	return run_checks([
		assert_false(ai_strategy_label.visible, "Unsupported AI decks should not expose strategy variant labels"),
		assert_false(ai_strategy_segment.visible, "Unsupported AI decks should not expose strategy variant segments"),
		assert_false(ai_strategy_option.visible, "Unsupported AI decks should not expose strategy variant dropdowns"),
	])


func test_battle_setup_ai_preview_strength_option_only_shows_in_ai_mode() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(0)
	scene.call("_refresh_ai_ui_visibility")
	var hidden_in_two_player := preview_option.visible
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")

	return run_checks([
		assert_true(preview_option is OptionButton, "BattleSetup should include AIPreviewStrengthOption"),
		assert_false(hidden_in_two_player, "AIPreviewStrengthOption should stay hidden outside VS_AI mode"),
		assert_true(preview_option.visible, "AIPreviewStrengthOption should show in VS_AI mode"),
		assert_eq(preview_option.get_item_count(), 2, "AIPreviewStrengthOption should expose standard/fixed choices"),
		assert_eq(preview_option.get_item_text(0), "标准", "Preview strength option 0 should be standard"),
		assert_eq(preview_option.get_item_text(1), "固定", "Preview strength option 1 should be fixed"),
	])


func test_battle_setup_ai_view_button_keeps_normal_preview_for_weak_mode() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var fake_dialog := FakeDeckViewDialog.new()
	scene.set("_deck_view_dialog", fake_dialog)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 575720)
	preview_option.select(0)

	scene.call("_on_deck_view_pressed", 1)

	var result := run_checks([
		assert_eq(fake_dialog.shown_decks.size(), 1, "Weak AI preview mode should keep calling the existing deck preview dialog"),
		assert_eq(fake_dialog.shown_decks[0].id if not fake_dialog.shown_decks.is_empty() else -1, 575720, "Weak AI preview mode should preview the selected AI deck"),
	])
	scene.queue_free()
	return result


func test_battle_setup_ai_view_button_uses_normal_preview_for_strong_mode() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var fake_dialog := FakeDeckViewDialog.new()
	scene.set("_deck_view_dialog", fake_dialog)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 575720)
	preview_option.select(1)

	scene.call("_on_deck_view_pressed", 1)

	var placeholder_opened := false
	for child: Node in scene.get_children():
		if child is AcceptDialog:
			placeholder_opened = true
			break

	var result := run_checks([
		assert_false(placeholder_opened, "Strong AI preview mode should not open a placeholder dialog"),
		assert_eq(fake_dialog.shown_decks.size(), 1, "Strong AI preview mode should use the normal deck preview dialog"),
		assert_eq(fake_dialog.shown_decks[0].id if not fake_dialog.shown_decks.is_empty() else -1, 575720, "Strong AI preview mode should preview the selected AI deck"),
	])
	scene.queue_free()
	return result
