class_name TestBattleSetupLayout
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")


func _set_navigation_suppressed(suppressed: bool) -> void:
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", suppressed)


func _ensure_mode_option_items(scene: Control) -> void:
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	if mode_option == null or mode_option.item_count > 0:
		return
	mode_option.add_item("自己练牌", 0)
	mode_option.add_item("AI 对战", 1)


func _force_two_player_mode(scene: Control) -> void:
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	if mode_option == null:
		return
	_ensure_mode_option_items(scene)
	mode_option.select(0)
	scene.call("_refresh_deck_options")
	scene.call("_refresh_ai_ui_visibility")


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


func test_battle_setup_applies_hud_visual_theme() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

	var setup_frame := scene.find_child("SetupFrame", true, false) as PanelContainer
	var left_column := scene.find_child("LeftColumn", true, false) as PanelContainer
	var right_column := scene.find_child("RightColumn", true, false) as PanelContainer
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var frame_style := setup_frame.get_theme_stylebox("panel") as StyleBoxFlat if setup_frame != null else null
	var left_style := left_column.get_theme_stylebox("panel") as StyleBoxFlat if left_column != null else null
	var right_style := right_column.get_theme_stylebox("panel") as StyleBoxFlat if right_column != null else null
	var option_style := mode_option.get_theme_stylebox("normal") as StyleBoxFlat if mode_option != null else null
	var button_style := start_button.get_theme_stylebox("normal") as StyleBoxFlat if start_button != null else null

	var result := run_checks([
		assert_true(frame_style != null and frame_style.bg_color.a < 0.9, "Battle setup frame should use a translucent HUD panel instead of a solid black block"),
		assert_true(frame_style != null and frame_style.border_color.a > 0.8, "Battle setup frame should have a visible HUD border instead of blending into the background"),
		assert_true(left_style != null and left_style.bg_color.a < 1.0 and left_style.border_color.a > 0.5, "Left setup column should use a translucent bordered HUD card"),
		assert_true(right_style != null and right_style.bg_color.a < 1.0 and right_style.border_color.a > 0.5, "Right setup column should use a translucent bordered HUD card"),
		assert_true(option_style != null and option_style.bg_color.a < 1.0, "Battle setup option controls should use translucent HUD inputs"),
		assert_true(button_style != null and button_style.border_color.a > 0.8, "Battle setup buttons should use explicit HUD borders"),
	])

	scene.queue_free()
	return result


func test_battle_setup_uses_true_two_column_layout() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var content_columns := scene.find_child("ContentColumns", true, false)
	var left_column := scene.find_child("LeftColumn", true, false)
	var right_column := scene.find_child("RightColumn", true, false)
	var background_gallery := scene.find_child("BackgroundGallery", true, false)
	var bgm_option := scene.find_child("BgmOption", true, false)

	var result := run_checks([
		assert_true(content_columns != null, "Battle setup should have a two-column content container"),
		assert_true(left_column != null and right_column != null, "Battle setup should keep separate left and right columns"),
		assert_true(background_gallery != null, "Left column should keep the background gallery"),
		assert_true(bgm_option != null, "Right column should keep the music selector"),
	])

	scene.queue_free()
	return result


func test_battle_setup_right_column_exposes_ai_strategy_discussion_button() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k2.6",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var discuss_button := scene.find_child("BtnDiscussStrategyAI", true, false) as Button

	var result := run_checks([
		assert_not_null(discuss_button, "Battle setup right column should expose the AI strategy discussion button"),
		assert_str_contains(discuss_button.text, "Kimi K2.6", "Strategy discussion button should name the selected LLM model"),
		assert_str_contains(discuss_button.text, "探讨策略", "Strategy discussion button should keep the strategy discussion action"),
		assert_false(discuss_button.disabled, "Strategy discussion button should be enabled when two decks are selected"),
	])

	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_strategy_discussion_uses_pair_session_and_resets_on_deck_change() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k2.6",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 101
	deck1.deck_name = "玩家测试牌"
	deck1.total_cards = 60
	deck1.cards = [{"name": "玩家牌", "count": 4, "card_type": "Pokemon", "set_code": "UTEST", "card_index": "001"}]
	var deck2 := DeckData.new()
	deck2.id = 202
	deck2.deck_name = "对手测试牌"
	deck2.total_cards = 60
	deck2.cards = [{"name": "对手牌", "count": 4, "card_type": "Pokemon", "set_code": "UTEST", "card_index": "002"}]
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("玩家测试牌")
	deck1_option.add_item("对手测试牌")
	deck2_option.add_item("对手测试牌")
	deck1_option.select(0)
	deck2_option.select(0)

	scene.call("_on_discuss_strategy_ai_pressed")
	var first_signature := str(scene.get("_strategy_discussion_signature"))
	var dialog := scene.get("_strategy_discussion_dialog") as AcceptDialog
	var first_title := ""
	if dialog != null:
		var deck_name_label := dialog.get_node_or_null("%DeckNameLabel") as Label
		if deck_name_label != null:
			first_title = deck_name_label.text
	deck1_option.select(1)
	scene.call("_on_deck1_changed", 1)
	var reset_signature := str(scene.get("_strategy_discussion_signature"))

	var result := run_checks([
		assert_eq(first_signature, "pvp:101:202", "Strategy discussion session should be keyed by mode and both deck ids"),
		assert_true(first_title.contains("玩家测试牌") and first_title.contains("对手测试牌"), "Strategy discussion dialog should show both current decks"),
		assert_eq(reset_signature, "", "Changing either deck should force the next discussion to start from a fresh session"),
	])

	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_includes_per_player_deck_view_and_edit_actions() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_view := scene.find_child("Deck1ViewButton", true, false)
	var deck1_edit := scene.find_child("Deck1EditButton", true, false)
	var deck2_view := scene.find_child("Deck2ViewButton", true, false)
	var deck2_edit := scene.find_child("Deck2EditButton", true, false)

	var result := run_checks([
		assert_true(deck1_view is Button, "Player 1 deck area should expose a view button"),
		assert_true(deck1_edit is Button, "Player 1 deck area should expose an edit button"),
		assert_true(deck2_view is Button, "Player 2 deck area should expose a view button"),
		assert_true(deck2_edit is Button, "Player 2 deck area should expose an edit button"),
	])

	scene.queue_free()
	return result


func test_battle_setup_uses_hud_deck_picker_buttons() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_picker := scene.find_child("Deck1PickerButton", true, false) as Button
	var deck2_picker := scene.find_child("Deck2PickerButton", true, false) as Button
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton

	var result := run_checks([
		assert_not_null(deck1_picker, "Player 1 deck selection should use a custom HUD picker button"),
		assert_not_null(deck2_picker, "Player 2 deck selection should use a custom HUD picker button"),
		assert_true(deck1_picker != null and deck1_picker.custom_minimum_size.y >= 50.0, "Deck picker buttons should be tall enough for mobile taps"),
		assert_true(deck2_picker != null and deck2_picker.custom_minimum_size.y >= 50.0, "Opponent deck picker button should be tall enough for mobile taps"),
		assert_true(deck1_option != null and not deck1_option.visible, "Legacy deck OptionButton should stay hidden behind the custom picker"),
		assert_true(deck2_option != null and not deck2_option.visible, "Opponent legacy OptionButton should stay hidden behind the custom picker"),
	])

	scene.queue_free()
	return result


func test_battle_setup_deck_picker_categories_keep_recent_and_all_only() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var old_deck := DeckData.new()
	old_deck.id = 901001
	old_deck.deck_name = "旧卡组"
	old_deck.total_cards = 60
	old_deck.import_date = "2026-05-01T10:00:00"
	var recent_deck := DeckData.new()
	recent_deck.id = 901002
	recent_deck.deck_name = "最近卡组"
	recent_deck.total_cards = 60
	recent_deck.import_date = "2026-05-02T10:00:00"
	var latest_deck := DeckData.new()
	latest_deck.id = 901003
	latest_deck.deck_name = "最新卡组"
	latest_deck.total_cards = 60
	latest_deck.import_date = "2026-05-05T10:00:00"
	scene.set("_deck_list", [old_deck, recent_deck, latest_deck])
	scene.set("_deck_usage_stats", {
		str(old_deck.id): {"use_count": 8, "last_used": "2026-05-02T12:00:00"},
		str(recent_deck.id): {"use_count": 2, "last_used": "2026-05-04T12:00:00"},
	})

	var recent: Array = scene.call("_decks_for_picker", 0, "recent", "")
	var all_decks: Array = scene.call("_decks_for_picker", 0, "all", "")
	var latest_meta := str(scene.call("_deck_picker_card_meta", latest_deck))
	scene.call("_ensure_deck_picker_overlay")
	var tabs := scene.get("_deck_picker_tabs") as Dictionary

	var result := run_checks([
		assert_true(tabs.has("recent"), "Deck picker should keep the recent category"),
		assert_true(tabs.has("all"), "Deck picker should keep the all category"),
		assert_false(tabs.has("frequent"), "Deck picker should remove the frequent category"),
		assert_eq((recent[0] as DeckData).id, recent_deck.id, "Recent category should sort by last_used descending"),
		assert_eq((all_decks[0] as DeckData).id, latest_deck.id, "All category should sort by import_date descending"),
		assert_false(latest_meta.contains("60张"), "Deck picker card meta should not waste space on total card count"),
		assert_false(latest_meta.contains("导入"), "Deck picker card meta should not display import timestamps"),
	])

	scene.queue_free()
	return result


func test_battle_setup_uses_hud_first_player_segment() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var segment := scene.find_child("FirstPlayerSegment", true, false) as HBoxContainer
	var random_button := scene.find_child("FirstPlayerRandomButton", true, false) as Button
	var player_one_button := scene.find_child("FirstPlayerOneButton", true, false) as Button
	var player_two_button := scene.find_child("FirstPlayerTwoButton", true, false) as Button
	var option := scene.find_child("FirstPlayerOption", true, false) as OptionButton
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	_ensure_mode_option_items(scene)

	scene.call("_on_first_player_segment_pressed", 1)
	var selected_after_player_one := option.selected if option != null else -1
	scene.call("_on_first_player_segment_pressed", 2)
	var selected_after_player_two := option.selected if option != null else -1
	var pvp_player_one_label := player_one_button.text if player_one_button != null else ""
	var pvp_player_two_label := player_two_button.text if player_two_button != null else ""
	if mode_option != null:
		mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	var ai_player_one_label := player_one_button.text if player_one_button != null else ""
	var ai_player_two_label := player_two_button.text if player_two_button != null else ""
	if mode_option != null:
		mode_option.select(0)
	scene.call("_refresh_ai_ui_visibility")
	var restored_player_one_label := player_one_button.text if player_one_button != null else ""
	var restored_player_two_label := player_two_button.text if player_two_button != null else ""

	var result := run_checks([
		assert_not_null(segment, "First-player selection should expose a HUD segmented control"),
		assert_true(option != null and not option.visible, "Legacy first-player OptionButton should stay hidden behind the HUD segment"),
		assert_true(random_button != null and random_button.custom_minimum_size.y >= 42.0, "Random first-player button should be mobile tappable"),
		assert_eq(pvp_player_one_label, "玩家1先攻", "Player 1 first-player segment should use readable Chinese"),
		assert_eq(pvp_player_two_label, "玩家2先攻", "Player 2 first-player segment should use readable Chinese"),
		assert_eq(ai_player_one_label, "玩家先攻", "AI battle should label the player first option clearly"),
		assert_eq(ai_player_two_label, "AI先攻", "AI battle should label the AI first option clearly"),
		assert_eq(restored_player_one_label, "玩家1先攻", "Switching back to two-player mode should restore player 1 label"),
		assert_eq(restored_player_two_label, "玩家2先攻", "Switching back to two-player mode should restore player 2 label"),
		assert_eq(selected_after_player_one, 1, "Pressing player 1 segment should update the legacy option state"),
		assert_eq(selected_after_player_two, 2, "Pressing player 2 segment should update the legacy option state"),
	])

	scene.queue_free()
	return result


func test_battle_setup_uses_hud_ai_strategy_segment() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	_write_battle_review_config_for_test({
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k2.6",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	})
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")

	var player_deck := DeckData.new()
	player_deck.id = 575716
	player_deck.deck_name = "Player Test Deck"
	player_deck.total_cards = 60
	var ai_deck := DeckData.new()
	ai_deck.id = 575720
	ai_deck.deck_name = "AI Test Deck"
	ai_deck.total_cards = 60
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [ai_deck])

	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_refresh_deck_options")
	scene.call("_select_option_for_deck_id", deck2_option, ai_deck.id)
	scene.call("_refresh_ai_strategy_variant_options")

	var segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var first_button: Button = null
	var second_button: Button = null
	if segment != null and segment.get_child_count() > 0:
		first_button = segment.get_child(0) as Button
	if segment != null and segment.get_child_count() > 1:
		second_button = segment.get_child(1) as Button

	scene.call("_on_ai_strategy_segment_pressed", 1)
	var selected_after_llm := ""
	if option != null and option.selected >= 0 and option.selected < option.item_count:
		selected_after_llm = str(option.get_item_metadata(option.selected))

	var result := run_checks([
		assert_not_null(segment, "AI strategy selection should expose a HUD segmented control"),
		assert_true(segment != null and segment.visible, "AI strategy segmented control should be visible in VS_AI mode"),
		assert_true(option != null and not option.visible, "Legacy AI strategy OptionButton should stay hidden behind the HUD segment"),
		assert_eq(segment.get_child_count() if segment != null else 0, 2, "Configured LLM API should expose rules and LLM strategy buttons"),
		assert_true(first_button != null and first_button.custom_minimum_size.y >= 42.0, "Rules strategy button should be mobile tappable"),
		assert_true(second_button != null and second_button.custom_minimum_size.y >= 42.0, "LLM strategy button should be mobile tappable"),
		assert_eq(selected_after_llm, "miraidon_llm", "Pressing the LLM strategy segment should update the hidden strategy state"),
	])

	scene.queue_free()
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_deck_action_buttons_use_readable_chinese_labels() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_view := scene.find_child("Deck1ViewButton", true, false) as Button
	var deck1_edit := scene.find_child("Deck1EditButton", true, false) as Button
	var deck2_view := scene.find_child("Deck2ViewButton", true, false) as Button
	var deck2_edit := scene.find_child("Deck2EditButton", true, false) as Button

	var result := run_checks([
		assert_eq(deck1_view.text, "查看", "Deck1 view button should use readable Chinese"),
		assert_eq(deck1_edit.text, "编辑", "Deck1 edit button should use readable Chinese"),
		assert_eq(deck2_view.text, "查看", "Deck2 view button should use readable Chinese"),
		assert_eq(deck2_edit.text, "编辑", "Deck2 edit button should use readable Chinese"),
	])

	scene.queue_free()
	return result


func test_battle_setup_deck_labels_use_readable_chinese() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_label := scene.find_child("Deck1Label", true, false) as Label
	var deck2_label := scene.find_child("Deck2Label", true, false) as Label

	var result := run_checks([
		assert_eq(deck1_label.text, "玩家1 卡组", "Deck1 label should use readable Chinese"),
		assert_eq(deck2_label.text, "玩家2 卡组", "Deck2 label should use readable Chinese before VS_AI mode remaps it"),
	])

	scene.queue_free()
	return result


func test_battle_setup_edit_action_prepares_battle_setup_return_context() -> String:
	_set_navigation_suppressed(true)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 101
	deck1.deck_name = "Deck A"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 202
	deck2.deck_name = "Deck B"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck A")
	deck2_option.add_item("Deck B")
	deck1_option.select(0)
	deck2_option.select(0)

	if not scene.has_method("_on_deck_edit_pressed"):
		scene.queue_free()
		return "BattleSetup should expose a deck edit handler"
	if not GameManager.has_method("consume_deck_editor_return_context"):
		scene.queue_free()
		return "GameManager should expose deck editor return context"

	scene.call("_on_deck_edit_pressed", 0)
	var context: Dictionary = GameManager.call("consume_deck_editor_return_context")

	var result := run_checks([
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "BattleSetup deck edit should set battle_setup as the return scene"),
		assert_eq(int(context.get("deck1_id", 0)), 101, "BattleSetup deck edit should preserve player 1 deck selection"),
		assert_eq(int(context.get("deck2_id", 0)), 202, "BattleSetup deck edit should preserve player 2 deck selection"),
	])

	scene.queue_free()
	_set_navigation_suppressed(false)
	return result


func test_battle_setup_edit_button_press_is_wired_to_navigation_handler() -> String:
	_set_navigation_suppressed(true)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 111
	deck1.deck_name = "Deck View"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 222
	deck2.deck_name = "Deck Edit"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck View")
	deck2_option.add_item("Deck Edit")
	deck1_option.select(0)
	deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")

	var deck1_edit := scene.find_child("Deck1EditButton", true, false) as Button
	scene.call("_on_deck_edit_pressed", 0)
	var context: Dictionary = GameManager.call("consume_deck_editor_return_context")

	var result := run_checks([
		assert_false(deck1_edit.disabled, "Battle setup edit button should stay enabled when a deck is selected"),
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Pressing the battle setup edit button should queue a return to battle_setup"),
		assert_eq(int(context.get("deck1_id", 0)), 111, "Pressing the battle setup edit button should preserve deck1 selection"),
		assert_eq(int(context.get("deck2_id", 0)), 222, "Pressing the battle setup edit button should preserve deck2 selection"),
	])

	scene.queue_free()
	_set_navigation_suppressed(false)
	return result


func test_battle_setup_view_button_press_opens_deck_dialog() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 333
	deck1.deck_name = "Deck Preview"
	deck1.total_cards = 1
	deck1.cards = [{
		"name": "Test Card",
		"count": 1,
		"card_type": "Pokemon",
		"set_code": "UTEST",
		"card_index": "001",
	}]
	var deck2 := DeckData.new()
	deck2.id = 444
	deck2.deck_name = "Deck Spare"
	deck2.total_cards = 1
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck Preview")
	deck2_option.add_item("Deck Spare")
	deck1_option.select(0)
	deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")

	var deck1_view := scene.find_child("Deck1ViewButton", true, false) as Button
	scene.call("_on_deck_view_pressed", 0)

	var dialog_opened := false
	for child: Node in scene.get_children():
		if child is AcceptDialog and (child as AcceptDialog).title == "Deck Preview":
			dialog_opened = true
			break

	var result := run_checks([
		assert_false(deck1_view.disabled, "Battle setup view button should stay enabled when a deck is selected"),
		assert_true(dialog_opened, "Pressing the battle setup view button should open the selected deck dialog"),
	])

	scene.queue_free()
	return result


func test_battle_setup_hides_ai_edit_button_in_vs_ai_mode() -> String:
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")

	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_view := scene.find_child("Deck2ViewButton", true, false) as Button
	var deck2_edit := scene.find_child("Deck2EditButton", true, false) as Button
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")

	var result := run_checks([
		assert_true(deck2_view.visible, "AI deck row should keep the view button in VS_AI mode"),
		assert_false(deck2_edit.visible, "AI deck row should hide the edit button in VS_AI mode"),
	])

	scene.queue_free()
	return result
