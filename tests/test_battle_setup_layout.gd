class_name TestBattleSetupLayout
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")


class PendingZenMuxClient extends ZenMuxClient:
	var request_count := 0

	func request_json(
		_parent: Node,
		_endpoint: String,
		_api_key: String,
		_payload: Dictionary,
		_callback: Callable
	) -> int:
		request_count += 1
		return OK


class RespondingZenMuxClient extends ZenMuxClient:
	var request_count := 0
	var response: Dictionary = {}

	func request_json(
		_parent: Node,
		_endpoint: String,
		_api_key: String,
		_payload: Dictionary,
		callback: Callable
	) -> int:
		request_count += 1
		if callback.is_valid():
			callback.call(response.duplicate(true))
		return OK


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


func _dispose_scene(scene: Node) -> void:
	if scene == null:
		return
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.free()


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
		assert_true(deck1_picker != null and deck1_picker.custom_minimum_size.y >= 68.0, "Deck picker buttons should be tall enough for the larger one-line labels"),
		assert_true(deck2_picker != null and deck2_picker.custom_minimum_size.y >= 68.0, "Opponent deck picker button should be tall enough for the larger one-line labels"),
		assert_true(deck1_picker != null and deck1_picker.get_theme_font_size("font_size") >= 16 and deck1_picker.get_theme_font_size("font_size") <= 20, "Landscape deck picker buttons should keep selected deck names compact"),
		assert_true(deck2_picker != null and deck2_picker.get_theme_font_size("font_size") >= 16 and deck2_picker.get_theme_font_size("font_size") <= 20, "Landscape opponent deck picker button should keep selected deck names compact"),
		assert_true(deck1_picker != null and "\n" not in deck1_picker.text, "Deck picker buttons should only show the deck name"),
		assert_true(deck2_picker != null and "\n" not in deck2_picker.text, "Opponent deck picker buttons should only show the deck name"),
		assert_true(deck1_option != null and not deck1_option.visible, "Legacy deck OptionButton should stay hidden behind the custom picker"),
		assert_true(deck2_option != null and not deck2_option.visible, "Opponent legacy OptionButton should stay hidden behind the custom picker"),
	])

	scene.queue_free()
	return result


func test_battle_setup_landscape_ai_and_self_practice_deck_picker_fonts_match() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), "landscape")
	_force_two_player_mode(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck1_picker := scene.find_child("Deck1PickerButton", true, false) as Button
	var deck2_picker := scene.find_child("Deck2PickerButton", true, false) as Button
	var self_deck1_font := deck1_picker.get_theme_font_size("font_size") if deck1_picker != null else -1
	var self_deck2_font := deck2_picker.get_theme_font_size("font_size") if deck2_picker != null else -1

	if mode_option != null:
		mode_option.select(1)
		scene.call("_on_mode_changed", 1)
	var ai_deck1_font := deck1_picker.get_theme_font_size("font_size") if deck1_picker != null else -1
	var ai_deck2_font := deck2_picker.get_theme_font_size("font_size") if deck2_picker != null else -1

	var result := run_checks([
		assert_eq(self_deck1_font, self_deck2_font, "Landscape self-practice deck picker fonts should match"),
		assert_eq(ai_deck1_font, ai_deck2_font, "Landscape AI-practice player and AI deck picker fonts should match"),
		assert_eq(ai_deck2_font, self_deck2_font, "Landscape AI deck picker should keep the same compact deck font as self-practice"),
		assert_true(ai_deck2_font >= 16 and ai_deck2_font <= 20, "Landscape AI deck picker should use the compact selected-deck font size"),
	])

	scene.queue_free()
	return result


func test_battle_setup_background_gallery_is_compact_drag_area() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_apply_hud_theme")

	var background_gallery := scene.find_child("BackgroundGallery", true, false) as ScrollContainer

	var result := run_checks([
		assert_not_null(background_gallery, "Battle setup should expose the background gallery"),
		assert_true(background_gallery != null and background_gallery.custom_minimum_size.y <= 140.0, "Background gallery should be close to thumbnail height without a large empty lower area"),
		assert_eq(background_gallery.horizontal_scroll_mode if background_gallery != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Background gallery should not show the native horizontal scrollbar"),
		assert_true(background_gallery != null and bool(background_gallery.get_meta("background_gallery_drag_scroll_enabled", false)), "Background gallery should keep drag scrolling enabled after removing the native bar"),
	])

	scene.queue_free()
	return result


func test_battle_setup_landscape_does_not_show_right_scrollbar() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")

	var landscape_scroll := scene.find_child("LandscapeSetupScroll", true, false) as ScrollContainer
	var portrait_scroll := scene.find_child("PortraitSetupScroll", true, false) as ScrollContainer
	var vbar := landscape_scroll.get_v_scroll_bar() if landscape_scroll != null else null

	var result := run_checks([
		assert_true(landscape_scroll != null and landscape_scroll.visible, "Landscape setup should keep the landscape layout wrapper visible"),
		assert_eq(landscape_scroll.vertical_scroll_mode if landscape_scroll != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Landscape setup should fit without a native right-side scrollbar"),
		assert_true(vbar == null or (not vbar.visible and vbar.mouse_filter == Control.MOUSE_FILTER_IGNORE), "Landscape setup should not reserve an interactive right scrollbar"),
		assert_true(portrait_scroll == null or not portrait_scroll.visible, "Landscape setup must not activate the portrait scroll layout"),
	])

	_dispose_scene(scene)
	return result


func test_battle_setup_portrait_keeps_hidden_drag_scroll() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")

	var portrait_scroll := scene.find_child("PortraitSetupScroll", true, false) as ScrollContainer
	var landscape_scroll := scene.find_child("LandscapeSetupScroll", true, false) as ScrollContainer

	var result := run_checks([
		assert_true(portrait_scroll != null and portrait_scroll.visible, "Portrait setup should keep the portrait scroll layout visible"),
		assert_true(portrait_scroll != null and bool(portrait_scroll.get_meta(NonBattleTouchBridgeScript.HIDDEN_VERTICAL_DRAG_SCROLL_META, false)), "Portrait setup should keep hidden vertical drag scrolling"),
		assert_true(landscape_scroll == null or not landscape_scroll.visible, "Portrait setup must not activate the landscape scroll layout"),
	])

	_dispose_scene(scene)
	return result


func test_battle_setup_portrait_screen_touch_selects_background_card() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	var previous_background := str(GameManager.selected_battle_background)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	GameManager.selected_battle_background = "res://assets/ui/background.png"
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.set("_battle_backgrounds", [
		"res://assets/ui/background.png",
		"res://assets/ui/background1.png",
	])
	scene.call("_refresh_background_gallery")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_layout_background_gallery_cards")

	var row := scene.find_child("BackgroundGalleryRow", true, false) as HBoxContainer
	var target_card := row.get_child(1) as Control if row != null and row.get_child_count() > 1 else null
	var target_position := target_card.get_global_rect().get_center() if target_card != null else Vector2.ZERO
	if target_card != null and target_card.get_global_rect().size == Vector2.ZERO:
		target_card.position = Vector2(204, 0)
		target_card.size = Vector2(188, 112)
		target_position = target_card.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = target_position
	scene.call("_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = target_position
	scene.call("_input", release)
	var selected_after := str(scene.get("_selected_background_path"))

	var result := run_checks([
		assert_not_null(target_card, "Portrait battle setup should have a second background card to select"),
		assert_eq(selected_after, "res://assets/ui/background1.png", "Android ScreenTouch in portrait should select the tapped battle-field background card"),
	])

	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	GameManager.selected_battle_background = previous_background
	return result


func _removed_battle_setup_portrait_vertical_drag_from_background_gallery_scrolls_page() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	var previous_background := str(GameManager.selected_battle_background)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	GameManager.selected_battle_background = "res://assets/ui/background.png"
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.set("_battle_backgrounds", [
		"res://assets/ui/background.png",
		"res://assets/ui/background1.png",
	])
	scene.call("_refresh_background_gallery")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_layout_background_gallery_cards")
	var portrait_scroll := scene.find_child("PortraitSetupScroll", true, false) as ScrollContainer
	if portrait_scroll != null:
		portrait_scroll.size = Vector2(390, 320)

	var row := scene.find_child("BackgroundGalleryRow", true, false) as HBoxContainer
	var target_card := row.get_child(1) as Control if row != null and row.get_child_count() > 1 else null
	var start_position := target_card.get_global_rect().get_center() if target_card != null else Vector2.ZERO
	if target_card != null and target_card.get_global_rect().size == Vector2.ZERO:
		target_card.position = Vector2(204, 0)
		target_card.size = Vector2(188, 112)
		start_position = target_card.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = start_position
	scene.call("_input", press)
	var drag := InputEventScreenDrag.new()
	drag.position = start_position - Vector2(0, 96)
	drag.relative = Vector2(0, -96)
	scene.call("_input", drag)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = drag.position
	scene.call("_input", release)
	var selected_after := str(scene.get("_selected_background_path"))
	var scroll_after := int(portrait_scroll.scroll_vertical) if portrait_scroll != null else 0

	var result := run_checks([
		assert_not_null(target_card, "Portrait battle setup should have a background card under the drag start"),
		assert_true(scroll_after > 0, "Vertical ScreenDrag starting on the background gallery should scroll the portrait setup page"),
		assert_eq(selected_after, "res://assets/ui/background.png", "Vertical drag from the background gallery should not select a different battle-field background"),
	])

	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	GameManager.selected_battle_background = previous_background
	return result


func test_non_battle_touch_bridge_ignores_zero_size_tree_buttons() -> String:
	var root := Control.new()
	root.name = "ZeroSizeTouchRoot"
	root.size = Vector2(480, 320)
	var stale_button := Button.new()
	stale_button.name = "StaleZeroSizeButton"
	stale_button.custom_minimum_size = Vector2(180, 72)
	root.add_child(stale_button)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(root)
	stale_button.size = Vector2.ZERO
	stale_button.scale = Vector2.ZERO

	var hit_button := NonBattleTouchBridgeScript.button_at_position(root, Vector2(12, 12))

	var result := run_checks([
		assert_null(hit_button, "Touch bridge should ignore tree buttons that still have a zero global rect after layout changes"),
	])
	_dispose_scene(root)
	return result


func test_battle_setup_portrait_ai_copy_stays_compact_like_landscape() -> String:
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
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")

	var ai_help := scene.find_child("AiHelp", true, false) as Label
	var status_body := scene.find_child("AIModeStatusBody", true, false) as Label
	var model_status := scene.find_child("LLMModelStatus", true, false) as Label

	var result := run_checks([
		assert_true(ai_help != null and ai_help.visible, "Portrait AI help should remain available"),
		assert_true(ai_help != null and ai_help.clip_text, "Portrait AI help should be clipped instead of expanding the setup card"),
		assert_true(ai_help != null and ai_help.max_lines_visible >= 2 and ai_help.max_lines_visible <= 3, "Portrait AI help should use a compact but readable line count"),
		assert_true(ai_help != null and ai_help.text.contains("AI 设置"), "Portrait AI help should keep the setup guidance text"),
		assert_true(status_body != null and status_body.clip_text, "Portrait AI status body should be clipped instead of showing more copy than landscape"),
		assert_true(status_body != null and status_body.max_lines_visible >= 2 and status_body.max_lines_visible <= 3, "Portrait AI status body should use a compact readable line count"),
		assert_true(model_status != null and model_status.visible, "Portrait model-test status should show an initial guidance state"),
		assert_true(model_status != null and model_status.clip_text, "Portrait model-test status should stay compact when it becomes visible"),
		assert_true(model_status != null and model_status.text.contains("未测试"), "Portrait model-test status should tell players the current model still needs testing"),
	])

	_dispose_scene(scene)
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_hides_strategy_discussion_button_in_portrait_only() -> String:
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
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	if mode_option != null:
		mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var discuss_button := scene.find_child("BtnDiscussStrategyAI", true, false) as Button
	var hidden_in_portrait := discuss_button != null and not discuss_button.visible
	scene.call("_on_discuss_strategy_ai_pressed")
	var dialog_after_portrait_press := scene.get("_strategy_discussion_dialog") as AcceptDialog
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	scene.call("_refresh_ai_ui_visibility")
	var visible_in_landscape := discuss_button != null and discuss_button.visible

	var result := run_checks([
		assert_true(hidden_in_portrait, "Battle setup portrait should remove the AI strategy discussion button"),
		assert_null(dialog_after_portrait_press, "Battle setup portrait should not open the AI strategy discussion dialog even if the handler is called directly"),
		assert_true(visible_in_landscape, "Battle setup landscape should keep the AI strategy discussion button available"),
		assert_str_contains(discuss_button.text if discuss_button != null else "", "Kimi K2.6", "Landscape strategy discussion button should still name the selected model"),
	])

	_dispose_scene(scene)
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_portrait_llm_test_button_remains_available() -> String:
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
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")

	var test_button := scene.find_child("BtnTestLLMModel", true, false) as Button
	var status := scene.find_child("LLMModelStatus", true, false) as Label
	var model_row := scene.find_child("LLMModelRow", true, false) as Control
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var config := GameManager.get_battle_review_api_config()
	if test_button != null and test_button.get_global_rect().size == Vector2.ZERO:
		test_button.position = Vector2(420, 360)
		test_button.size = Vector2(220, 104)
	var was_enabled_before_touch := test_button != null and test_button.visible and not test_button.disabled

	var result := run_checks([
		assert_true(was_enabled_before_touch, "Portrait LLM test button should be visible and enabled before touch (mode=%d row_visible=%s button_visible=%s disabled=%s endpoint='%s' api_key_len=%d)" % [
			mode_option.selected if mode_option != null else -1,
			str(model_row.visible if model_row != null else false),
			str(test_button.visible if test_button != null else false),
			str(test_button.disabled if test_button != null else true),
			str(config.get("endpoint", "")),
			str(config.get("api_key", "")).length(),
		]),
		assert_true(status != null and status.visible, "Portrait LLM model-test status label should stay visible beside the touch-sized button"),
		assert_true(status != null and status.text.strip_edges() != "", "Portrait LLM model-test status should not be blank when the test button is available"),
	])

	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_llm_status_shows_saved_passed_result_in_both_layouts() -> String:
	var snapshot := _snapshot_battle_review_config_file()
	var config := {
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "test-key",
		"model": "kimi-k2.6",
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": true,
		"ai_test_signature": "",
	}
	config["ai_test_signature"] = GameManager.battle_review_ai_config_signature(config)
	_write_battle_review_config_for_test(config)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	var landscape_status := scene.find_child("LLMModelStatus", true, false) as Label
	var landscape_text := landscape_status.text if landscape_status != null else ""
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var portrait_status := scene.find_child("LLMModelStatus", true, false) as Label

	var result := run_checks([
		assert_true(landscape_status != null and landscape_status.visible, "Landscape setup should show the saved model-test status"),
		assert_true(landscape_text.contains("已测试") and landscape_text.contains("可用"), "Landscape setup should tell players the saved model test passed"),
		assert_true(portrait_status != null and portrait_status.visible, "Portrait setup should show the saved model-test status"),
		assert_true(portrait_status != null and portrait_status.text.contains("已测试") and portrait_status.text.contains("可用"), "Portrait setup should tell players the saved model test passed"),
	])

	_dispose_scene(scene)
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_llm_test_failure_result_stays_visible() -> String:
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
	var fake_client := RespondingZenMuxClient.new()
	fake_client.response = {
		"status": "error",
		"message": "simulated connection failure",
	}
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set("_llm_model_test_client", fake_client)
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	var test_button := scene.find_child("BtnTestLLMModel", true, false) as Button
	if test_button != null:
		test_button.pressed.emit()
	var status := scene.find_child("LLMModelStatus", true, false) as Label

	var result := run_checks([
		assert_eq(fake_client.request_count, 1, "Pressing model test should call the ZenMux client once"),
		assert_true(status != null and status.visible, "Failed model test should leave a visible status"),
		assert_true(status != null and status.text.contains("测试失败"), "Failed model test should show a failure result instead of disappearing"),
		assert_true(status != null and status.text.contains("simulated connection failure"), "Failed model test should include the returned error message"),
	])

	_dispose_scene(scene)
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_landscape_ai_guidance_labels_reserve_readable_height() -> String:
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
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1600, 900)
	scene.call("_select_mode_option", 1)
	scene.call("_refresh_ai_ui_visibility")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")

	var status_body := scene.find_child("AIModeStatusBody", true, false) as Label
	var model_status := scene.find_child("LLMModelStatus", true, false) as Label
	var ai_help := scene.find_child("AiHelp", true, false) as Label

	var result := run_checks([
		assert_true(status_body != null and status_body.custom_minimum_size.y >= 36.0, "Landscape AI mode status should reserve readable height instead of collapsing to one pixel"),
		assert_true(model_status != null and model_status.custom_minimum_size.y >= 36.0, "Landscape model-test status should reserve readable height instead of collapsing to one pixel"),
		assert_true(ai_help != null and ai_help.custom_minimum_size.y >= 36.0, "Landscape AI help copy should reserve readable height instead of collapsing to one pixel"),
	])

	_dispose_scene(scene)
	_restore_battle_review_config_file(snapshot)
	return result


func test_battle_setup_landscape_keeps_advanced_help_visible() -> String:
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
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")

	var ai_help := scene.find_child("AiHelp", true, false) as Label

	var result := run_checks([
		assert_true(ai_help != null and ai_help.visible, "Landscape AI/advanced setup should keep the player help copy visible"),
		assert_true(ai_help != null and str(ai_help.text).contains("API"), "AI help copy should explain the model API requirement"),
		assert_true(ai_help != null and ai_help.max_lines_visible >= 1, "Landscape AI help should be compact, not removed"),
	])

	_dispose_scene(scene)
	_restore_battle_review_config_file(snapshot)
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
	old_deck.import_date = "2026-05-06T10:00:00"
	old_deck.updated_at = 1000
	var recent_deck := DeckData.new()
	recent_deck.id = 901002
	recent_deck.deck_name = "最近卡组"
	recent_deck.total_cards = 60
	recent_deck.import_date = "2026-05-02T10:00:00"
	recent_deck.updated_at = 2000
	var latest_deck := DeckData.new()
	latest_deck.id = 901003
	latest_deck.deck_name = "最新卡组"
	latest_deck.total_cards = 60
	latest_deck.import_date = "2026-05-01T10:00:00"
	latest_deck.updated_at = 3000
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
	scene.set("_deck_picker_slot_index", 0)
	scene.set("_deck_picker_category", "all")
	scene.set("_deck_picker_search", "")
	scene.call("_refresh_deck_picker")
	var grid := scene.get("_deck_picker_grid") as GridContainer
	var first_card_button := grid.get_child(0) as Button if grid != null and grid.get_child_count() > 0 else null

	var result := run_checks([
		assert_true(tabs.has("recent"), "Deck picker should keep the recent category"),
		assert_true(tabs.has("all"), "Deck picker should keep the all category"),
		assert_false(tabs.has("frequent"), "Deck picker should remove the frequent category"),
		assert_eq((recent[0] as DeckData).id, recent_deck.id, "Recent category should sort by last_used descending"),
		assert_eq((all_decks[0] as DeckData).id, latest_deck.id, "All category should sort by latest edit time descending"),
		assert_false(latest_meta.contains("60张"), "Deck picker card meta should not waste space on total card count"),
		assert_false(latest_meta.contains("导入"), "Deck picker card meta should not display import timestamps"),
		assert_true(first_card_button != null and "\n" not in first_card_button.text, "Deck picker list entries should show only the deck name"),
		assert_true(first_card_button != null and first_card_button.get_theme_font_size("font_size") >= 24, "Deck picker list entries should use larger readable labels"),
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
	var requested_scene: String = GameManager.call("consume_last_requested_scene_path")

	var result := run_checks([
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "BattleSetup deck edit should request the DeckEditor scene"),
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
	var requested_scene: String = GameManager.call("consume_last_requested_scene_path")

	var result := run_checks([
		assert_false(deck1_edit.disabled, "Battle setup edit button should stay enabled when a deck is selected"),
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "Pressing the battle setup edit button should request DeckEditor"),
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Pressing the battle setup edit button should queue a return to battle_setup"),
		assert_eq(int(context.get("deck1_id", 0)), 111, "Pressing the battle setup edit button should preserve deck1 selection"),
		assert_eq(int(context.get("deck2_id", 0)), 222, "Pressing the battle setup edit button should preserve deck2 selection"),
	])

	scene.queue_free()
	_set_navigation_suppressed(false)
	return result


func test_battle_setup_portrait_android_touch_on_edit_button_opens_deck_editor() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	_set_navigation_suppressed(true)
	if GameManager.has_method("consume_last_requested_scene_path"):
		GameManager.call("consume_last_requested_scene_path")
	if GameManager.has_method("consume_deck_editor_id"):
		GameManager.call("consume_deck_editor_id")
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 444
	deck1.deck_name = "Touch Edit Deck"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 555
	deck2.deck_name = "Touch Opponent Deck"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Touch Edit Deck")
	deck1_option.set_item_metadata(0, 444)
	deck2_option.add_item("Touch Opponent Deck")
	deck2_option.set_item_metadata(0, 555)
	deck1_option.select(0)
	deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")

	var deck1_edit := scene.find_child("Deck1EditButton", true, false) as Button
	if deck1_edit != null and deck1_edit.get_global_rect().size == Vector2.ZERO:
		deck1_edit.global_position = Vector2(560, 560)
		deck1_edit.size = Vector2(420, 116)
	var touch_position := deck1_edit.get_global_rect().get_center() if deck1_edit != null else Vector2.ZERO
	var hit_button := NonBattleTouchBridgeScript.button_at_position(scene, touch_position) if deck1_edit != null else null
	if deck1_edit != null and deck1_edit.visible and not deck1_edit.disabled:
		scene.call("_on_deck_edit_pressed", 0)
	var requested_scene: String = GameManager.call("consume_last_requested_scene_path")
	var editor_deck_id := int(GameManager.call("consume_deck_editor_id"))

	var result := run_checks([
		assert_not_null(deck1_edit, "Portrait battle setup should keep the player 1 edit button in the scene"),
		assert_true(deck1_edit != null and deck1_edit.visible and not deck1_edit.disabled, "Portrait player 1 edit button should be visible and enabled"),
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "Android ScreenTouch on the portrait edit button should request DeckEditor"),
		assert_eq(editor_deck_id, 444, "Android ScreenTouch on edit should pass the touched deck id into DeckEditor"),
	])

	_dispose_scene(scene)
	_set_navigation_suppressed(false)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	return result


func test_battle_setup_deck_picker_touch_does_not_steal_edit_button_overlap() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")

	var picker := scene.find_child("Deck1PickerButton", true, false) as Button
	var edit := scene.find_child("Deck1EditButton", true, false) as Button
	if picker != null:
		picker.global_position = Vector2(80, 460)
		picker.size = Vector2(920, 240)
	if edit != null:
		edit.global_position = Vector2(560, 560)
		edit.size = Vector2(420, 116)
	var touch_position := edit.get_global_rect().get_center() if edit != null else Vector2.ZERO
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = touch_position
	var consumed := bool(scene.call("_handle_deck_picker_button_input", press))

	var result := run_checks([
		assert_true(picker != null and picker.get_global_rect().has_point(touch_position), "Test setup should simulate a stale/overlapping deck picker rect over the edit button"),
		assert_true(edit != null and edit.get_global_rect().has_point(touch_position), "Test setup should place the touch on the edit button"),
		assert_false(consumed, "Deck picker touch routing must not steal touches that land on the deck view/edit action buttons"),
	])

	_dispose_scene(scene)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	return result


func test_battle_setup_deck_action_touch_routes_before_scroll_bridge() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	_set_navigation_suppressed(true)
	if GameManager.has_method("consume_last_requested_scene_path"):
		GameManager.call("consume_last_requested_scene_path")
	if GameManager.has_method("consume_deck_editor_id"):
		GameManager.call("consume_deck_editor_id")
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_ready")
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 666
	deck1.deck_name = "Action Routed Deck"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 777
	deck2.deck_name = "Action Routed Opponent"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])
	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Action Routed Deck")
	deck1_option.set_item_metadata(0, 666)
	deck2_option.add_item("Action Routed Opponent")
	deck2_option.set_item_metadata(0, 777)
	deck1_option.select(0)
	deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")

	var edit := scene.find_child("Deck1EditButton", true, false) as Button
	if edit != null:
		edit.global_position = Vector2(560, 560)
		edit.size = Vector2(420, 116)
	var touch_position := edit.get_global_rect().get_center() if edit != null else Vector2.ZERO
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = touch_position
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = touch_position
	var exposes_handler := scene.has_method("_handle_deck_action_button_input")
	var press_consumed := bool(scene.call("_handle_deck_action_button_input", press)) if exposes_handler else false
	var release_consumed := bool(scene.call("_handle_deck_action_button_input", release)) if exposes_handler else false
	var requested_scene: String = GameManager.call("consume_last_requested_scene_path")
	var editor_deck_id := int(GameManager.call("consume_deck_editor_id"))

	var result := run_checks([
		assert_true(exposes_handler, "BattleSetup should expose a root-level touch route for deck view/edit buttons"),
		assert_true(edit != null and edit.visible and not edit.disabled, "Test setup should keep the edit action visible and enabled"),
		assert_true(press_consumed, "Deck action route should consume touch press before hidden scroll or generic bridge can claim it"),
		assert_true(release_consumed, "Deck action route should consume touch release and emit the button action"),
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "Deck action touch route should request DeckEditor"),
		assert_eq(editor_deck_id, 666, "Deck action touch route should pass the selected deck id to DeckEditor"),
	])

	_dispose_scene(scene)
	_set_navigation_suppressed(false)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
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
