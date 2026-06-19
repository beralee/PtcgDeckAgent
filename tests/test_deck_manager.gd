class_name TestDeckManager
extends TestBase

const DeckManagerScene = preload("res://scenes/deck_manager/DeckManager.tscn")
const DeckViewDialogScript = preload("res://scripts/ui/decks/DeckViewDialog.gd")
const DeckRecommendationStoreScript = preload("res://scripts/engine/DeckRecommendationStore.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const TEST_RECOMMENDATION_CACHE_PATH := "user://test_deck_manager/recommendation_cache.json"
const TEST_DECK_CENTER_META_STATE_PATH := "user://deck_center_meta_state.json"


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
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 63.0, "Deck manager top action buttons should use the 50%-larger HUD height"),
		assert_true(import_button != null and import_button.get_theme_font_size("font_size") >= 23, "Deck manager top action button text should be 50% larger"),
	])


func test_import_panel_portrait_uses_phone_sized_modal_controls() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")

	var import_panel := scene.get_node_or_null("%ImportPanel") as Control
	var import_bg := scene.find_child("ImportBg", true, false) as Control
	var import_box := scene.find_child("ImportBox", true, false) as Control
	var hint_label := scene.find_child("HintLabel", true, false) as Label
	var progress_label := scene.get_node_or_null("%ProgressLabel") as Label
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit
	var paste_button := scene.find_child("BtnPasteImport", true, false) as Button
	var import_button := scene.get_node_or_null("%BtnDoImport") as Button
	var close_button := scene.get_node_or_null("%BtnCloseImport") as Button
	var box_min_size := import_box.custom_minimum_size if import_box != null else Vector2.ZERO
	var guide_text := hint_label.text if hint_label != null else ""
	var modal_is_top_layer := import_panel != null and import_panel.z_index >= 1000 and import_panel.z_as_relative == false
	var modal_is_front_child := import_panel != null and import_panel.get_parent() != null and import_panel.get_parent().get_child(import_panel.get_parent().get_child_count() - 1) == import_panel

	scene.queue_free()
	return run_checks([
		assert_true(import_panel != null and import_panel.visible, "Deck import panel should open in portrait"),
		assert_true(import_panel != null and import_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Deck import panel should act as a touch-blocking modal layer"),
		assert_true(modal_is_top_layer, "Deck import panel should render above deck rows so phone taps cannot hit View/Edit buttons behind it"),
		assert_true(modal_is_front_child, "Deck import panel should move to the front when opened"),
		assert_true(import_bg != null and import_bg.mouse_filter == Control.MOUSE_FILTER_STOP, "Deck import backdrop should stop touch events from leaking to the deck list"),
		assert_true(import_box != null and import_box.mouse_filter == Control.MOUSE_FILTER_STOP, "Deck import box should own touch input while the modal is open"),
		assert_true(import_box != null and import_box.anchor_left == 0.0 and import_box.anchor_right == 1.0, "Deck import portrait box should be a full-width HUD sheet"),
		assert_true(import_box != null and import_box.anchor_top == 0.0 and import_box.anchor_bottom == 1.0, "Deck import portrait box should be a full-height HUD sheet"),
		assert_true(box_min_size.x >= 340.0, "Deck import portrait sheet should use most of a phone-width screen"),
		assert_true(box_min_size.y >= 780.0, "Deck import portrait sheet should use full phone height"),
		assert_true(hint_label != null and hint_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "Deck import portrait hint should wrap instead of shrinking text"),
		assert_true(guide_text.contains("tcg.mik.moe") and guide_text.contains("574793"), "Deck import portrait guide should show the website and an example deck id"),
		assert_true(guide_text.contains("复制") and guide_text.contains("粘贴"), "Deck import portrait guide should explain the copy and paste flow"),
		assert_true(progress_label != null and progress_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "Deck import portrait progress text should wrap instead of clipping"),
		assert_true(url_input != null and url_input.custom_minimum_size.y >= 128.0, "Deck import portrait URL input should be a large phone touch target"),
		assert_true(url_input != null and url_input.get_theme_font_size("font_size") >= 29, "Deck import portrait URL input text should be phone-readable"),
		assert_true(url_input != null and url_input.virtual_keyboard_enabled and url_input.virtual_keyboard_show_on_focus, "Deck import URL input should rely on native mobile keyboard-on-focus behavior"),
		assert_true(url_input != null and url_input.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_URL, "Deck import URL input should request the URL keyboard type"),
		assert_true(url_input != null and url_input.context_menu_enabled, "Deck import URL input should keep the native paste context menu enabled"),
		assert_true(paste_button != null and paste_button.visible, "Deck import portrait dialog should include a one-tap paste button for phone users"),
		assert_true(paste_button != null and paste_button.custom_minimum_size.y >= 104.0, "Deck import paste button should be phone-sized"),
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 104.0, "Deck import portrait confirm button should be phone-sized"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 104.0, "Deck import portrait close button should be phone-sized"),
		assert_true(import_button != null and import_button.get_theme_font_size("font_size") >= 33, "Deck import portrait button text should be phone-readable"),
	])


func test_import_panel_blocks_and_restores_background_deck_controls() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")

	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var fake_row_button := Button.new()
	fake_row_button.name = "FakeDeckRowViewButton"
	fake_row_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if deck_list != null:
		deck_list.add_child(fake_row_button)

	var back_button := scene.get_node_or_null("%BtnBack") as Button
	var back_filter_before := back_button.mouse_filter if back_button != null else -1
	var row_filter_before := fake_row_button.mouse_filter

	scene.call("_on_import_pressed")
	var back_blocked := back_button != null and back_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var row_blocked := fake_row_button.mouse_filter == Control.MOUSE_FILTER_IGNORE

	scene.call("_on_close_import")
	var back_restored := back_button != null and back_button.mouse_filter == back_filter_before
	var row_restored := fake_row_button.mouse_filter == row_filter_before

	scene.queue_free()
	return run_checks([
		assert_true(back_blocked, "Deck import modal should disable background header buttons while open"),
		assert_true(row_blocked, "Deck import modal should disable deck row buttons behind the full-screen sheet while open"),
		assert_true(back_restored, "Deck import modal should restore background header button hit testing after close"),
		assert_true(row_restored, "Deck import modal should restore deck row button hit testing after close"),
	])


func test_import_panel_gui_layer_consumes_background_touches() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(16, 760)
	var handled_press := bool(scene.call("_handle_import_modal_gui_input_for_tests", press))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	var handled_release := bool(scene.call("_handle_import_modal_gui_input_for_tests", release))

	scene.queue_free()
	return run_checks([
		assert_true(handled_press and handled_release, "Deck import modal GUI layer should consume phone touches before deck row buttons behind it can react"),
	])


func test_import_panel_modal_consumes_background_touch_when_open() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_show_import_panel")

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(12, 760)
	var handled_press := bool(scene.call("_handle_import_panel_modal_input_for_tests", press))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	var handled_release := bool(scene.call("_handle_import_panel_modal_input_for_tests", release))
	scene.call("_hide_import_panel")
	var handled_hidden := bool(scene.call("_handle_import_panel_modal_input_for_tests", press))

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	scene.queue_free()
	return run_checks([
		assert_true(handled_press and handled_release, "Deck import modal should consume background phone touches while open"),
		assert_false(handled_hidden, "Deck import modal should not consume touches after it is closed"),
	])


func test_import_panel_url_input_uses_feedback_style_focus_path() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")
	await tree.process_frame
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = url_input.get_global_rect().get_center() if url_input != null else Vector2(80, 330)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	var import_panel := scene.get_node_or_null("%ImportPanel") as Control
	var handled_press := bool(NonBattleTouchBridgeScript.handle_root_touch(import_panel, press)) if import_panel != null else false
	var handled_release := bool(NonBattleTouchBridgeScript.handle_root_touch(import_panel, release)) if import_panel != null else false
	var focus_requested := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.FOCUS_REQUESTED_META, false))
	var native_marked := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META, false))
	var focus_bridge_bound := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.FOCUS_TOUCH_BOUND_META, false))
	var has_manual_modal_handler := false
	for control_name: String in ["ImportPanel", "ImportBg", "ImportBox"]:
		var control := scene.find_child(control_name, true, false) as Control
		if control == null:
			continue
		for connection: Dictionary in control.gui_input.get_connections():
			var callable := connection.get("callable") as Callable
			if callable.is_valid() and str(callable.get_method()) == "_on_import_modal_gui_input":
				has_manual_modal_handler = true

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	scene.queue_free()
	return run_checks([
		assert_true(handled_press and handled_release, "Deck import URL input taps should be handled by the same focus bridge path as the working feedback dialog"),
		assert_true(focus_requested, "Deck import URL input tap should request focus and open the Android keyboard"),
		assert_false(native_marked, "Deck import URL input should not use the native-bypass path that skips the shared focus bridge"),
		assert_true(focus_bridge_bound, "Deck import URL input should bind the shared focus touch bridge"),
		assert_false(has_manual_modal_handler, "Deck import modal should not install manual gui_input guards that can swallow input-field taps"),
		assert_true(url_input != null and url_input.mouse_filter == Control.MOUSE_FILTER_STOP, "Deck import URL input should still stop events inside the modal hit area"),
		assert_true(url_input != null and url_input.virtual_keyboard_enabled and url_input.virtual_keyboard_show_on_focus, "Deck import URL input should request the native mobile keyboard on focus"),
		assert_true(url_input != null and url_input.context_menu_enabled, "Deck import URL input should keep native paste support enabled"),
	])


func test_import_panel_url_input_is_focus_bridge_bound_like_feedback_dialog() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit
	var native_marked := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META, false))
	var focus_bridge_bound := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.FOCUS_TOUCH_BOUND_META, false))

	scene.queue_free()
	return run_checks([
		assert_false(native_marked, "Deck import URL input should use the feedback-style focus bridge instead of native bypass"),
		assert_true(focus_bridge_bound, "Deck import URL input should be bound to the non-battle focus bridge"),
	])


func test_import_panel_modal_keeps_input_focus_bridge_after_text_entry_and_blocks_echoes() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")
	await tree.process_frame
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit
	if url_input != null:
		url_input.text = "574793"

	var input_touch := InputEventScreenTouch.new()
	input_touch.pressed = true
	input_touch.position = url_input.get_global_rect().get_center() if url_input != null else Vector2(80, 330)
	var input_release := InputEventScreenTouch.new()
	input_release.pressed = false
	input_release.position = input_touch.position
	var import_panel := scene.get_node_or_null("%ImportPanel") as Control
	var handled_input_touch := bool(NonBattleTouchBridgeScript.handle_root_touch(import_panel, input_touch)) if import_panel != null else false
	var handled_input_release := bool(NonBattleTouchBridgeScript.handle_root_touch(import_panel, input_release)) if import_panel != null else false
	var focus_requested := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.FOCUS_REQUESTED_META, false))

	var echo_press := InputEventMouseButton.new()
	echo_press.button_index = MOUSE_BUTTON_LEFT
	echo_press.pressed = true
	echo_press.position = Vector2(24, 760)
	echo_press.global_position = echo_press.position
	var handled_echo_press := bool(scene.call("_handle_import_panel_modal_input_for_tests", echo_press))
	var echo_release := InputEventMouseButton.new()
	echo_release.button_index = MOUSE_BUTTON_LEFT
	echo_release.pressed = false
	echo_release.position = echo_press.position
	echo_release.global_position = echo_press.position
	var handled_echo_release := bool(scene.call("_handle_import_panel_modal_input_for_tests", echo_release))

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	scene.queue_free()
	return run_checks([
		assert_true(handled_input_touch and handled_input_release, "Deck import URL input should remain on the feedback-style focus bridge after text entry"),
		assert_true(focus_requested, "Deck import URL input should request focus after text entry when tapped again"),
		assert_true(handled_echo_press and handled_echo_release, "Deck import modal should consume Android tap echoes outside the input after text entry"),
	])


func test_import_panel_paste_button_copies_clipboard_to_url_input() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")

	scene.call("_apply_import_paste_text_for_tests", "https://tcg.mik.moe/decks/list/574793")
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit
	var progress_label := scene.get_node_or_null("%ProgressLabel") as Label
	var pasted_text := url_input.text if url_input != null else ""
	var progress_text := progress_label.text if progress_label != null else ""

	scene.queue_free()
	return run_checks([
		assert_eq(pasted_text, "https://tcg.mik.moe/decks/list/574793", "Deck import paste button should copy the clipboard into the URL input"),
		assert_true(progress_text.contains("已粘贴") or progress_text.contains("宸茬矘璐"), "Deck import paste button should tell the player that clipboard content was pasted"),
	])


func test_import_panel_url_input_touch_uses_feedback_focus_bridge() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")
	await tree.process_frame
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = url_input.get_global_rect().get_center() if url_input != null else Vector2(80, 330)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	var import_panel := scene.get_node_or_null("%ImportPanel") as Control
	var handled_press := bool(NonBattleTouchBridgeScript.handle_root_touch(import_panel, press)) if import_panel != null else false
	var handled_release := bool(NonBattleTouchBridgeScript.handle_root_touch(import_panel, release)) if import_panel != null else false
	var focus_requested := url_input != null and bool(url_input.get_meta(NonBattleTouchBridgeScript.FOCUS_REQUESTED_META, false))

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	scene.queue_free()
	return run_checks([
		assert_true(handled_press and handled_release, "Deck import URL input taps should be handled by the shared focus bridge"),
		assert_true(focus_requested, "Deck import URL input taps should request focus so Android can open the keyboard"),
	])


func test_import_panel_modal_keeps_desktop_mouse_clicks_native() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	var scene: Control = DeckManagerScene.instantiate()
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")
	scene.get_node("%ImportPanel").visible = true

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(800, 450)
	press.global_position = press.position
	var handled_press := bool(scene.call("_handle_import_panel_modal_input_for_tests", press))

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	scene.queue_free()
	return run_checks([
		assert_false(handled_press, "Deck import modal should leave ordinary desktop mouse clicks to native Godot GUI dispatch"),
	])


func test_import_panel_layout_restores_landscape_metrics_after_portrait() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1600, 900), "landscape")

	var import_box := scene.find_child("ImportBox", true, false) as Control
	var url_input := scene.get_node_or_null("%UrlInput") as LineEdit
	var import_button := scene.get_node_or_null("%BtnDoImport") as Button
	var close_button := scene.get_node_or_null("%BtnCloseImport") as Button
	var box_height := import_box.offset_bottom - import_box.offset_top if import_box != null else 0.0

	scene.queue_free()
	return run_checks([
		assert_eq(roundi(box_height), 260, "Deck import panel should restore the desktop dialog height after leaving portrait"),
		assert_true(url_input != null and url_input.custom_minimum_size.y <= 50.0, "Deck import URL input should restore compact desktop height after leaving portrait"),
		assert_true(import_button != null and import_button.custom_minimum_size.y <= 70.0, "Deck import confirm button should restore compact desktop height after leaving portrait"),
		assert_true(close_button != null and close_button.custom_minimum_size.y <= 70.0, "Deck import close button should restore compact desktop height after leaving portrait"),
		assert_true(import_button != null and import_button.get_theme_font_size("font_size") <= 26, "Deck import confirm button should restore compact desktop font after leaving portrait"),
	])


func test_deck_manager_deck_row_buttons_use_50_percent_larger_text() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var deck := _make_deck(910020, "Row Font Deck")
	var row := scene._create_deck_item(deck) as Control
	var buttons: Array[Button] = []
	_collect_buttons(row, buttons)
	var min_font_size := 999
	var min_height := 999.0
	for button: Button in buttons:
		min_font_size = mini(min_font_size, button.get_theme_font_size("font_size"))
		min_height = minf(min_height, button.custom_minimum_size.y)
	row.queue_free()
	scene.queue_free()

	return run_checks([
		assert_eq(buttons.size(), 4, "Deck rows should expose view, edit, rename and delete buttons"),
		assert_true(min_font_size >= 21, "Deck row compact button text should be 50% larger"),
		assert_true(min_height >= 57.0, "Deck row compact buttons should grow tall enough for the larger text"),
	])


func test_deck_manager_deck_row_name_and_import_date_share_large_line() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var deck := _make_deck(910022, "Row Meta Deck")
	deck.import_date = "2026-05-10 18:30:00"
	var row := scene._create_deck_item(deck) as Control
	var labels: Array[Label] = []
	_collect_labels(row, labels)
	var title_label := labels[0] if labels.size() > 0 else null
	var title_text := title_label.text if title_label != null else ""
	row.queue_free()
	scene.queue_free()

	return run_checks([
		assert_eq(labels.size(), 1, "Deck row should keep deck name and import date on one line only"),
		assert_eq(title_text, "Row Meta Deck | 导入于 2026-05-10", "Deck row should render name and import date separated by |"),
		assert_false(title_text.contains("张卡牌"), "Deck row should not show the old card-count subtitle"),
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 23, "Deck row title text should use 23px font"),
	])


func test_deck_manager_deck_row_shows_edit_date_when_available() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var deck := _make_deck(910023, "Edited Row Deck")
	deck.import_date = "2026-05-10 18:30:00"
	deck.updated_at = int(Time.get_unix_time_from_datetime_dict({
		"year": 2026,
		"month": 5,
		"day": 12,
		"hour": 8,
		"minute": 30,
		"second": 0,
	}) * 1000.0)
	var row := scene._create_deck_item(deck) as Control
	var labels: Array[Label] = []
	_collect_labels(row, labels)
	var title_text := labels[0].text if labels.size() > 0 else ""
	row.queue_free()
	scene.queue_free()

	return run_checks([
		assert_eq(title_text, "Edited Row Deck | 编辑于 2026-05-12", "Deck row should prefer the local edit date when it is available"),
	])


func test_deck_manager_sorts_decks_by_latest_edit_time_first() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var old_deck := _make_deck(910024, "Old Edited Deck")
	old_deck.updated_at = 1000
	var latest_deck := _make_deck(910025, "Latest Edited Deck")
	latest_deck.updated_at = 3000
	var middle_deck := _make_deck(910026, "Middle Edited Deck")
	middle_deck.updated_at = 2000
	var decks: Array[DeckData] = [old_deck, latest_deck, middle_deck]

	decks.sort_custom(scene._compare_decks_by_edit_time_desc)
	scene.queue_free()

	return run_checks([
		assert_eq(decks[0].id, latest_deck.id, "Deck center should place the most recently edited deck first"),
		assert_eq(decks[1].id, middle_deck.id, "Deck center should keep edit timestamps in descending order"),
		assert_eq(decks[2].id, old_deck.id, "Deck center should place the oldest edited deck last"),
	])


func test_deck_view_card_list_hides_scrollbar_and_enables_drag_scroll() -> String:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	var dialog_helper = DeckViewDialogScript.new()
	var deck := _make_deck(910027, "Drag View Deck")
	deck.cards = [
		{"name": "Drag Test Card", "set_code": "", "card_index": "", "count": 60, "card_type": "Pokemon"},
	]

	dialog_helper.show_deck(host, deck)
	var scroll := host.find_child("DeckViewCardScroll", true, false) as ScrollContainer
	var grid := host.find_child("DeckViewCardGrid", true, false) as GridContainer
	var vbar := scroll.get_v_scroll_bar() if scroll != null else null

	host.queue_free()
	return run_checks([
		assert_not_null(scroll, "Deck view should name the card-list ScrollContainer for interaction tests"),
		assert_not_null(grid, "Deck view should name the card grid for interaction tests"),
		assert_true(scroll != null and bool(scroll.get_meta("deck_card_list_drag_scroll_enabled", false)), "Deck view card list should opt into drag scrolling"),
		assert_true(scroll != null and bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), "Deck view card list should use the shared hidden portrait drag-scroll policy"),
		assert_eq(scroll.horizontal_scroll_mode if scroll != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Deck view card list should stay vertically oriented"),
		assert_eq(scroll.vertical_scroll_mode if scroll != null else -1, ScrollContainer.SCROLL_MODE_AUTO, "Deck view card list should keep logical vertical scrolling enabled"),
		assert_true(vbar != null and not vbar.visible, "Deck view card list should hide the native vertical scrollbar in portrait"),
	])


func test_deck_view_dialog_uses_large_portrait_card_grid() -> String:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	var dialog_helper = DeckViewDialogScript.new()
	var deck := _make_deck(910028, "Portrait View Deck")
	deck.cards = [
		{"name": "Portrait Test Card", "set_code": "", "card_index": "", "count": 60, "card_type": "Pokemon"},
	]

	dialog_helper.show_deck(host, deck)
	var dialog := host.find_child("DeckViewDialog", true, false) as AcceptDialog
	var scroll := host.find_child("DeckViewCardScroll", true, false) as ScrollContainer
	var grid := host.find_child("DeckViewCardGrid", true, false) as GridContainer
	var info_label := host.find_child("DeckViewInfoLabel", true, false) as Label
	var close_button := host.find_child("DeckViewCloseButton", true, false) as Button
	var first_tile := grid.get_child(0) as Control if grid != null and grid.get_child_count() > 0 else null
	var vbar := scroll.get_v_scroll_bar() if scroll != null else null

	host.queue_free()
	return run_checks([
		assert_true(dialog != null and dialog.size.x >= 990, "Portrait deck view dialog should use nearly the full phone width"),
		assert_true(dialog != null and dialog.size.y >= 2280, "Portrait deck view dialog should be a tall mobile sheet instead of a desktop popup"),
		assert_true(grid != null and grid.columns == 3, "Portrait deck view should use three large card columns"),
		assert_true(scroll != null and bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), "Portrait deck view should use hidden surface drag scrolling"),
		assert_true(vbar != null and not vbar.visible, "Portrait deck view should hide the right scrollbar"),
		assert_true(info_label != null and info_label.get_theme_font_size("font_size") >= 31, "Portrait deck view metadata should use phone-readable text"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 96.0, "Portrait deck view should use a large content-level close button"),
		assert_true(close_button != null and bool(close_button.get_meta("_non_battle_touch_bound", false)), "Portrait deck view close button should use the Android touch bridge"),
		assert_true(first_tile != null and first_tile.custom_minimum_size.x >= 275.0, "Portrait deck view card tiles should fill the phone-width sheet instead of looking like desktop thumbnails"),
		assert_true(first_tile != null and first_tile.custom_minimum_size.y >= 400.0, "Portrait deck view card tiles should leave room for a readable card image and name"),
	])


func test_deck_view_card_list_drag_moves_vertical_scroll_and_suppresses_click() -> String:
	var dialog_helper = DeckViewDialogScript.new()
	var scroll := ScrollContainer.new()
	var grid := GridContainer.new()
	scroll.add_child(grid)
	dialog_helper._configure_card_list_drag_scroll(scroll, grid)
	var vbar := scroll.get_v_scroll_bar()
	vbar.max_value = 1000.0
	vbar.page = 200.0
	scroll.scroll_vertical = 120

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(20, 200)
	var press_consumed: bool = dialog_helper._handle_card_list_drag_scroll_input(press, scroll)

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(20, 120)
	var drag_consumed: bool = dialog_helper._handle_card_list_drag_scroll_input(drag, scroll)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(20, 120)
	var release_consumed: bool = dialog_helper._handle_card_list_drag_scroll_input(release, scroll)
	var suppress_until := int(scroll.get_meta("deck_card_list_drag_suppress_until_msec", 0))
	var final_scroll := scroll.scroll_vertical

	scroll.queue_free()
	return run_checks([
		assert_true(press_consumed, "Deck view card-list drag should capture the initial press"),
		assert_true(drag_consumed, "Deck view card-list drag should consume movement after the threshold"),
		assert_true(final_scroll > 200, "Dragging upward should scroll the deck view card list downward with phone-friendly sensitivity"),
		assert_true(release_consumed, "Deck view card-list release should consume the completed drag"),
		assert_true(suppress_until > Time.get_ticks_msec(), "Deck view card-list drag should suppress the follow-up click"),
	])


func test_deck_view_right_scrollbar_accepts_android_touch_drag() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var vbar := VScrollBar.new()
	vbar.position = Vector2(900, 100)
	vbar.size = Vector2(112, 1000)
	vbar.custom_minimum_size = Vector2(112, 1000)
	vbar.min_value = 0.0
	vbar.max_value = 1600.0
	vbar.page = 300.0
	vbar.value = 0.0
	NonBattleTouchBridgeScript.bind_range_touch(vbar)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(956, 150)
	var press_consumed := bool(NonBattleTouchBridgeScript.handle_range_touch(vbar, press))
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(956, 940)
	var drag_consumed := bool(NonBattleTouchBridgeScript.handle_range_touch(vbar, drag))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = drag.position
	var release_consumed := bool(NonBattleTouchBridgeScript.handle_range_touch(vbar, release))
	var final_value := float(vbar.value)
	vbar.queue_free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)

	return run_checks([
		assert_true(press_consumed, "Portrait deck view scrollbar should capture Android ScreenTouch press"),
		assert_true(drag_consumed, "Portrait deck view scrollbar should capture Android ScreenDrag"),
		assert_true(release_consumed, "Portrait deck view scrollbar should consume release after dragging"),
		assert_true(final_value > 900.0, "Dragging near the bottom of the portrait scrollbar should move the scroll value"),
	])


func test_deck_manager_confirmation_dialog_buttons_use_large_text() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._on_delete_deck(_make_deck(910021, "Delete Font Deck"))
	var dialog := _first_confirmation_dialog(scene)
	var ok_button := dialog.get_ok_button() if dialog != null else null
	var cancel_button := dialog.get_cancel_button() if dialog != null else null
	var result := run_checks([
		assert_not_null(dialog, "Delete confirmation dialog should open"),
		assert_true(ok_button != null and ok_button.get_theme_font_size("font_size") >= 23, "Delete confirm button text should be 50% larger"),
		assert_true(cancel_button != null and cancel_button.get_theme_font_size("font_size") >= 23, "Delete cancel button text should be 50% larger"),
	])
	scene.queue_free()
	return result


func test_deck_manager_portrait_rename_uses_hud_dialog() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	var deck := _make_deck(910024, "Portrait Rename Deck")
	scene._on_rename_deck(deck)

	var overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var panel := scene.find_child("DeckActionHudPanel", true, false) as PanelContainer
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
	var default_dialog = scene._rename_dialog
	var input_height: float = scene._rename_input.custom_minimum_size.y if scene._rename_input != null else 0.0
	var input_font: int = scene._rename_input.get_theme_font_size("font_size") if scene._rename_input != null else 0
	var confirm_height: float = scene._rename_confirm_button.custom_minimum_size.y if scene._rename_confirm_button != null else 0.0
	var confirm_font: int = scene._rename_confirm_button.get_theme_font_size("font_size") if scene._rename_confirm_button != null else 0

	scene.queue_free()
	return run_checks([
		assert_not_null(overlay, "Portrait deck-row rename should open the deck-center HUD dialog layer"),
		assert_true(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Portrait rename HUD dialog should block touches behind it"),
		assert_not_null(panel, "Portrait rename HUD dialog should include a styled panel"),
		assert_true(panel_style != null and panel_style.border_color.a > 0.85, "Portrait rename HUD dialog panel should use the HUD border style"),
		assert_null(default_dialog, "Portrait deck-row rename should not use the default AcceptDialog window"),
		assert_true(input_height >= 98.0 and input_font >= 29, "Portrait rename HUD input should remain phone-sized"),
		assert_true(confirm_height >= 104.0 and confirm_font >= 33, "Portrait rename HUD confirm button should remain phone-sized"),
	])


func test_deck_manager_portrait_delete_uses_hud_dialog() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene._on_delete_deck(_make_deck(910025, "Portrait Delete Deck"))

	var overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var panel := scene.find_child("DeckActionHudPanel", true, false) as PanelContainer
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
	var default_dialog := _first_confirmation_dialog(scene)
	var delete_button := scene.find_child("DeleteDeckConfirmButton", true, false) as Button
	var cancel_button := scene.find_child("DeleteDeckCancelButton", true, false) as Button

	scene.queue_free()
	return run_checks([
		assert_not_null(overlay, "Portrait delete should open the deck-center HUD dialog layer"),
		assert_true(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Portrait delete HUD dialog should block touches behind it"),
		assert_not_null(panel, "Portrait delete HUD dialog should include a styled panel"),
		assert_true(panel_style != null and panel_style.border_color.a > 0.85, "Portrait delete HUD dialog panel should use the HUD border style"),
		assert_null(default_dialog, "Portrait delete should not create the default ConfirmationDialog window"),
		assert_true(delete_button != null and delete_button.custom_minimum_size.y >= 104.0, "Portrait delete confirm button should be phone-sized"),
		assert_true(delete_button != null and delete_button.get_theme_font_size("font_size") >= 33, "Portrait delete confirm text should be phone-readable"),
		assert_true(cancel_button != null and cancel_button.custom_minimum_size.y >= 104.0, "Portrait delete cancel button should be phone-sized"),
	])


func test_deck_manager_portrait_row_action_buttons_open_hud_dialogs() -> String:
	_cleanup_decks([910028])
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	CardDatabase.save_deck(_make_deck(910028, "Portrait Row Action Deck"))
	scene.call("_refresh_deck_list")
	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var rename_button := deck_list.find_child("DeckRowRenameButton", true, false) as Button if deck_list != null else null
	var delete_button := deck_list.find_child("DeckRowDeleteButton", true, false) as Button if deck_list != null else null

	if rename_button != null:
		rename_button.emit_signal("pressed")
	var rename_overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var rename_default_dialog = scene._rename_dialog
	scene._close_rename_dialog()

	if delete_button != null:
		delete_button.emit_signal("pressed")
	var delete_overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var delete_default_dialog := _first_confirmation_dialog(scene)

	scene.queue_free()
	_cleanup_decks([910028])
	return run_checks([
		assert_not_null(rename_button, "Portrait deck-row rename button should have a stable node name"),
		assert_not_null(delete_button, "Portrait deck-row delete button should have a stable node name"),
		assert_not_null(rename_overlay, "Tapping the portrait deck-row rename button should open the HUD dialog"),
		assert_null(rename_default_dialog, "Tapping the portrait deck-row rename button should not open an AcceptDialog"),
		assert_not_null(delete_overlay, "Tapping the portrait deck-row delete button should open the HUD dialog"),
		assert_null(delete_default_dialog, "Tapping the portrait deck-row delete button should not open a ConfirmationDialog"),
	])


func test_deck_manager_portrait_row_action_buttons_open_hud_from_android_touch() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	_cleanup_decks([910029])
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	CardDatabase.save_deck(_make_deck(910029, "Portrait Android Touch Deck"))
	scene.call("_refresh_deck_list")
	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var rename_button := deck_list.find_child("DeckRowRenameButton", true, false) as Button if deck_list != null else null
	var delete_button := deck_list.find_child("DeckRowDeleteButton", true, false) as Button if deck_list != null else null
	var rename_bound := bool(rename_button.get_meta("_non_battle_touch_bound", false)) if rename_button != null else false
	var delete_bound := bool(delete_button.get_meta("_non_battle_touch_bound", false)) if delete_button != null else false

	if rename_button != null:
		_emit_android_touch_on_button(rename_button)
	var rename_overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var rename_default_dialog = scene._rename_dialog
	scene._close_rename_dialog()

	if delete_button != null:
		_emit_android_touch_on_button(delete_button)
	var delete_overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var delete_default_dialog := _first_confirmation_dialog(scene)

	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	scene.queue_free()
	_cleanup_decks([910029])
	return run_checks([
		assert_true(rename_bound, "Portrait deck-row rename button should be bound to the Android touch bridge"),
		assert_true(delete_bound, "Portrait deck-row delete button should be bound to the Android touch bridge"),
		assert_not_null(rename_overlay, "Android ScreenTouch on portrait rename should open the HUD dialog"),
		assert_null(rename_default_dialog, "Android ScreenTouch on portrait rename should not open an AcceptDialog"),
		assert_not_null(delete_overlay, "Android ScreenTouch on portrait delete should open the HUD dialog"),
		assert_null(delete_default_dialog, "Android ScreenTouch on portrait delete should not open a ConfirmationDialog"),
	])


func test_deck_manager_portrait_hud_row_actions_commit_rename_and_delete() -> String:
	_cleanup_decks([910031])
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	CardDatabase.save_deck(_make_deck(910031, "Portrait HUD Action Deck"))
	scene.call("_refresh_deck_list")
	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var rename_button := deck_list.find_child("DeckRowRenameButton", true, false) as Button if deck_list != null else null
	if rename_button != null:
		rename_button.emit_signal("pressed")
	if scene._rename_input != null:
		scene._rename_input.text = "Portrait HUD Action Renamed"
	scene.call("_on_rename_text_changed", "Portrait HUD Action Renamed")
	var rename_confirm := scene.find_child("DeckRenameConfirmButton", true, false) as Button
	if rename_confirm != null:
		rename_confirm.emit_signal("pressed")
	var renamed_deck := CardDatabase.get_deck(910031)
	var renamed_name := renamed_deck.deck_name if renamed_deck != null else ""
	var rename_overlay_closed := not bool(scene.call("_is_deck_action_hud_dialog_visible"))

	scene.call("_refresh_deck_list")
	deck_list = scene.get_node_or_null("%DeckList") as VBoxContainer
	var delete_button := deck_list.find_child("DeckRowDeleteButton", true, false) as Button if deck_list != null else null
	if delete_button != null:
		delete_button.emit_signal("pressed")
	var delete_confirm := scene.find_child("DeleteDeckConfirmButton", true, false) as Button
	if delete_confirm != null:
		delete_confirm.emit_signal("pressed")
	var deck_deleted := not CardDatabase.has_deck(910031)
	var delete_overlay_closed := not bool(scene.call("_is_deck_action_hud_dialog_visible"))

	scene.queue_free()
	_cleanup_decks([910031])
	return run_checks([
		assert_eq(renamed_name, "Portrait HUD Action Renamed", "Portrait HUD row rename confirm should save the trimmed deck name"),
		assert_true(rename_overlay_closed, "Portrait HUD row rename confirm should close the HUD dialog"),
		assert_true(deck_deleted, "Portrait HUD row delete confirm should delete the selected deck"),
		assert_true(delete_overlay_closed, "Portrait HUD row delete confirm should close the HUD dialog"),
	])


func test_deck_manager_global_portrait_deck_row_actions_use_hud_before_scene_meta_sync() -> String:
	var previous_mode := str(GameManager.non_battle_layout_mode)
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_PORTRAIT
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	scene.call("_apply_hud_theme")

	scene._on_rename_deck(_make_deck(910026, "Global Portrait Rename Deck"))
	var rename_overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var rename_default_dialog = scene._rename_dialog
	scene._close_rename_dialog()

	scene._on_delete_deck(_make_deck(910027, "Global Portrait Delete Deck"))
	var delete_overlay := scene.find_child("DeckActionHudDialog", true, false) as Control
	var delete_default_dialog := _first_confirmation_dialog(scene)

	GameManager.non_battle_layout_mode = previous_mode
	scene.queue_free()
	return run_checks([
		assert_not_null(rename_overlay, "Deck-row rename should use the HUD dialog as soon as global portrait mode is active"),
		assert_null(rename_default_dialog, "Deck-row rename should not fall back to AcceptDialog before scene layout meta syncs"),
		assert_not_null(delete_overlay, "Deck-row delete should use the HUD dialog as soon as global portrait mode is active"),
		assert_null(delete_default_dialog, "Deck-row delete should not fall back to ConfirmationDialog before scene layout meta syncs"),
	])


func test_deck_manager_edit_requests_deck_editor_from_portrait_mode() -> String:
	var previous_mode := str(GameManager.non_battle_layout_mode)
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", true)
	if GameManager.has_method("consume_last_requested_scene_path"):
		GameManager.call("consume_last_requested_scene_path")
	if GameManager.has_method("consume_deck_editor_id"):
		GameManager.call("consume_deck_editor_id")
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_PORTRAIT
	var scene: Control = DeckManagerScene.instantiate()
	var deck := _make_deck(910030, "Portrait Edit Deck")

	scene.call("_on_edit_deck", deck)
	var requested_scene := str(GameManager.call("consume_last_requested_scene_path"))
	var editor_deck_id := int(GameManager.call("consume_deck_editor_id"))
	var mode_after := str(GameManager.non_battle_layout_mode)

	scene.queue_free()
	GameManager.non_battle_layout_mode = previous_mode
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", false)
	return run_checks([
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "Deck center edit should request the DeckEditor scene"),
		assert_eq(editor_deck_id, 910030, "Deck center edit should pass the selected deck id into DeckEditor"),
		assert_eq(mode_after, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "Deck center edit should not switch the non-battle layout mode away from portrait"),
	])


func test_deck_manager_portrait_edit_button_touch_requests_deck_editor_after_import_modal_close() -> String:
	var previous_mode := str(GameManager.non_battle_layout_mode)
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", true)
	if GameManager.has_method("consume_last_requested_scene_path"):
		GameManager.call("consume_last_requested_scene_path")
	if GameManager.has_method("consume_deck_editor_id"):
		GameManager.call("consume_deck_editor_id")
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_PORTRAIT
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_on_import_pressed")
	scene.call("_on_close_import")

	var deck := _make_deck(910033, "Portrait Touch Edit Deck")
	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var row := scene.call("_create_deck_item", deck) as Control
	if deck_list != null and row != null:
		deck_list.add_child(row)
	var buttons: Array[Button] = []
	_collect_buttons(row, buttons)
	var edit_button := buttons[1] if buttons.size() > 1 else null
	if edit_button != null:
		edit_button.size = Vector2(180, 80)
		edit_button.global_position = Vector2(120, 300)
		_emit_android_touch_on_button(edit_button)
	var requested_scene := str(GameManager.call("consume_last_requested_scene_path"))
	var editor_deck_id := int(GameManager.call("consume_deck_editor_id"))
	var import_visible := bool(scene.call("_is_import_panel_visible"))
	var edit_mouse_filter := edit_button.mouse_filter if edit_button != null else -1

	scene.queue_free()
	GameManager.non_battle_layout_mode = previous_mode
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", false)
	return run_checks([
		assert_not_null(edit_button, "Deck row should expose an edit button in portrait"),
		assert_false(import_visible, "Closed import modal must not leave DeckManager in modal-input mode"),
		assert_true(edit_mouse_filter != Control.MOUSE_FILTER_IGNORE, "Closed import modal must restore edit button hit testing"),
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "Android touch on the portrait deck-row edit button should request DeckEditor"),
		assert_eq(editor_deck_id, 910033, "Android touch on edit should pass the selected deck id"),
	])


func test_deck_manager_portrait_root_touch_routes_deck_row_edit_button() -> String:
	var previous_mode := str(GameManager.non_battle_layout_mode)
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", true)
	if GameManager.has_method("consume_last_requested_scene_path"):
		GameManager.call("consume_last_requested_scene_path")
	if GameManager.has_method("consume_deck_editor_id"):
		GameManager.call("consume_deck_editor_id")
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_PORTRAIT
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")

	var deck := _make_deck(910034, "Portrait Root Touch Edit Deck")
	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var row := scene.call("_create_deck_item", deck) as Control
	if deck_list != null and row != null:
		deck_list.add_child(row)
	var buttons: Array[Button] = []
	_collect_buttons(row, buttons)
	var edit_button := buttons[1] if buttons.size() > 1 else null
	if edit_button != null:
		edit_button.size = Vector2(180, 80)
		edit_button.global_position = Vector2(120, 300)
	var touch_position := edit_button.get_global_rect().get_center() if edit_button != null else Vector2(160, 340)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = touch_position
	scene.call("_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = touch_position
	scene.call("_input", release)
	var requested_scene := str(GameManager.call("consume_last_requested_scene_path"))
	var editor_deck_id := int(GameManager.call("consume_deck_editor_id"))

	scene.queue_free()
	GameManager.non_battle_layout_mode = previous_mode
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", false)
	return run_checks([
		assert_not_null(edit_button, "Deck row should expose an edit button for root touch routing"),
		assert_eq(requested_scene, GameManager.SCENE_DECK_EDITOR, "DeckManager root ScreenTouch bridge should route portrait edit taps to DeckEditor"),
		assert_eq(editor_deck_id, 910034, "DeckManager root ScreenTouch bridge should preserve selected deck id"),
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
		assert_not_null(deck_scroll_margin, "Deck center list should be wrapped in a margin container for content padding"),
		assert_eq(deck_scroll.horizontal_scroll_mode if deck_scroll != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Deck center should not introduce horizontal scrolling for portrait content padding"),
		assert_true(deck_list_right_margin < 80, "Deck center list should not reserve the old wide right scrollbar clearance"),
		assert_not_null(feed, "Recommendation section should include the feed container"),
		assert_eq(feed_count, 1, "Recommendation section should render one rich feed card"),
		assert_not_null(card, "Recommendation feed should include the current deck card"),
		assert_eq(why_title_text, "为什么值得玩", "Recommendation card should explain why this deck is worth playing"),
		assert_not_null(import_button, "Recommendation card should keep the import action"),
		assert_not_null(detail_button, "Recommendation card should keep the detail action"),
		assert_not_null(next_button, "Recommendation card should include local next action"),
		assert_true(next_before_import, "Next recommendation button should sit before the import button in the card actions"),
		assert_true(next_button != null and next_button.custom_minimum_size.y >= 63.0, "Recommendation next action should use the 50%-larger HUD button size"),
		assert_true(import_button != null and import_button.custom_minimum_size.y >= 63.0, "Recommendation import action should use the 50%-larger HUD button size"),
		assert_true(detail_button != null and detail_button.get_theme_font_size("font_size") >= 23, "Recommendation detail button text should be 50% larger"),
		assert_true(next_style != null and import_style != null and next_style.border_color != import_style.border_color, "Recommendation actions should have visually distinct button roles"),
	])


func test_deck_manager_marks_latest_recommendation_id_with_new_badge() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	scene._deck_center_latest_meta = {
		"latest_revision": "test-latest-recommendation-id",
		"latest_recommendation_id": str(scene._current_recommendation.get("id", "")),
		"latest_deck_id": 0,
	}
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var badge := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer
	var badge_text := _collect_label_text(badge)

	scene.queue_free()
	return run_checks([
		assert_not_null(badge, "Latest deck-center recommendation should show a NEW badge"),
		assert_str_contains(badge_text, "NEW", "Latest recommendation badge should use NEW label text"),
	])


func test_deck_manager_marks_latest_recommendation_deck_id_with_new_badge() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	scene._deck_center_latest_meta = {
		"latest_revision": "test-latest-recommendation-deck-id",
		"latest_recommendation_id": "",
		"latest_deck_id": int(scene._current_recommendation.get("deck_id", 0)),
	}
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var badge := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer

	scene.queue_free()
	return run_checks([
		assert_not_null(badge, "Latest deck-center deck id should show a NEW badge"),
	])


func test_deck_manager_rendering_recommendation_new_badge_persists_seen_revision() -> String:
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	var revision := "test-render-persist-recommendation-revision"
	scene._deck_center_latest_meta = {
		"latest_revision": revision,
		"latest_recommendation_id": str(scene._current_recommendation.get("id", "")),
		"latest_deck_id": int(scene._current_recommendation.get("deck_id", 0)),
	}
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var badge := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer
	var state: Dictionary = scene._load_deck_center_meta_state()
	var badge_seen_revision := str(state.get("last_recommendation_badge_seen_revision", ""))
	var entrance_seen_revision := str(state.get("last_seen_revision", ""))
	var matches_after_render: bool = scene._recommendation_matches_deck_center_latest(scene._current_recommendation)

	scene.queue_free()
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	return run_checks([
		assert_not_null(badge, "First render should still show the latest recommendation NEW badge"),
		assert_eq(badge_seen_revision, revision, "Rendering the NEW badge should immediately persist the recommendation seen revision"),
		assert_eq(entrance_seen_revision, revision, "Rendering the recommendation NEW badge should also clear the main-menu entrance revision"),
		assert_false(matches_after_render, "The same recommendation should not match as NEW again after the first render"),
	])


func test_deck_manager_hides_recommendation_new_badge_after_seen_revision() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	scene._deck_center_latest_meta = {
		"latest_revision": "test-seen-recommendation-revision",
		"latest_recommendation_id": str(scene._current_recommendation.get("id", "")),
		"latest_deck_id": int(scene._current_recommendation.get("deck_id", 0)),
	}
	scene._deck_center_recommendation_badge_seen_revision = "test-seen-recommendation-revision"
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var badge := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer

	scene.queue_free()
	return run_checks([
		assert_null(badge, "Seen deck-center recommendation revision should not keep showing a NEW badge"),
	])


func test_deck_manager_marks_recommendation_new_badge_seen_revision() -> String:
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	_configure_recommendation_test_state(scene)
	scene._deck_center_latest_meta = {
		"latest_revision": "test-mark-recommendation-revision",
		"latest_recommendation_id": str(scene._current_recommendation.get("id", "")),
		"latest_deck_id": int(scene._current_recommendation.get("deck_id", 0)),
	}

	var matches_before_seen: bool = scene._recommendation_matches_deck_center_latest(scene._current_recommendation)
	scene._mark_deck_center_recommendation_badge_seen()
	var state: Dictionary = scene._load_deck_center_meta_state()
	var seen_revision := str(state.get("last_recommendation_badge_seen_revision", ""))
	var main_menu_seen_revision := str(state.get("last_seen_revision", ""))
	var matches_after_seen: bool = scene._recommendation_matches_deck_center_latest(scene._current_recommendation)

	scene.queue_free()
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	return run_checks([
		assert_true(matches_before_seen, "Matching deck-center recommendation should be considered new before the card badge is marked seen"),
		assert_eq(seen_revision, "test-mark-recommendation-revision", "Rendering a recommendation NEW badge should persist the seen badge revision"),
		assert_eq(main_menu_seen_revision, "test-mark-recommendation-revision", "Rendering a deck-center recommendation NEW badge should also clear the main-menu entrance badge revision"),
		assert_false(matches_after_seen, "The same recommendation revision should not show NEW again after being marked seen"),
	])


func test_deck_manager_removes_visible_recommendation_new_badge_when_marked_seen() -> String:
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	scene._deck_center_latest_meta = {
		"latest_revision": "test-remove-visible-recommendation-revision",
		"latest_recommendation_id": str(scene._current_recommendation.get("id", "")),
		"latest_deck_id": int(scene._current_recommendation.get("deck_id", 0)),
	}
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var badge_before := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer
	scene._mark_deck_center_recommendation_badge_seen()
	var badge_after := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer
	var state: Dictionary = scene._load_deck_center_meta_state()

	scene.queue_free()
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	return run_checks([
		assert_not_null(badge_before, "Precondition: matching latest recommendation should initially render a NEW badge"),
		assert_null(badge_after, "Marking the latest recommendation as seen should remove the visible NEW badge immediately"),
		assert_eq(str(state.get("last_recommendation_badge_seen_revision", "")), "test-remove-visible-recommendation-revision", "Visible badge cleanup should still persist the recommendation seen revision"),
	])


func test_deck_manager_treats_main_menu_seen_revision_as_recommendation_badge_seen() -> String:
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene)
	var revision := "test-main-menu-seen-recommendation-revision"
	scene._save_deck_center_meta_state({
		"last_seen_revision": revision,
		"last_seen_at": 12345,
		"latest_info": {
			"latest_revision": revision,
			"latest_recommendation_id": str(scene._current_recommendation.get("id", "")),
			"latest_deck_id": int(scene._current_recommendation.get("deck_id", 0)),
		},
	})
	scene._deck_center_latest_meta = scene._load_deck_center_latest_meta()
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var seen_revision: String = str(scene._deck_center_recommendation_badge_seen_revision)
	var badge := scene.find_child("RecommendationNewBadge", true, false) as PanelContainer

	scene.queue_free()
	_delete_user_file(TEST_DECK_CENTER_META_STATE_PATH)
	return run_checks([
		assert_eq(seen_revision, revision, "Opening deck center from the main menu should satisfy the internal recommendation NEW badge state"),
		assert_null(badge, "A revision already marked seen by the main-menu entrance should not keep showing the recommendation NEW badge"),
	])


func test_recommendation_detail_dialog_uses_footer_close_only() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	scene._apply_non_battle_layout_for_tests(Vector2(1080, 2400), "portrait")
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
		assert_true(scroll_margin_right < 30, "Recommendation detail content should not reserve the old right scrollbar clearance"),
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
		assert_eq(int(metadata.get("limit", 0)), int(DeckRecommendationStoreScript.MAX_CACHE_ITEMS), "Opening refresh should ask the server for the full recommendation cache in one request"),
		assert_eq(fetch_reason, "open_refresh", "Opening refresh should track the request reason separately from the cycle button"),
		assert_str_contains(status_text, "正在检查服务器最新卡组推荐", "Opening refresh should show a latest-recommendation status"),
	])


func test_deck_manager_initial_recommendation_prefers_cached_server_pool_over_stale_embedded_current() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)

	var stale_embedded: Dictionary = scene._embedded_recommendations[1] if scene._embedded_recommendations.size() > 1 else scene._embedded_recommendations[0]
	var older_remote := _remote_recommendation("remote-older", 600401, "2026-05-05T03:00:00+08:00")
	var newer_remote := _remote_recommendation("remote-newer", 600402, "2026-05-06T03:00:00+08:00")
	scene._recommendation_store.call("upsert_item", stale_embedded, true)
	scene._recommendation_store.call("upsert_item", older_remote, false)
	scene._recommendation_store.call("upsert_item", newer_remote, false)

	scene._current_recommendation = scene._select_initial_recommendation()
	var current_id := str(scene._current_recommendation.get("id", ""))
	var stale_id := str(stale_embedded.get("id", ""))
	var pool_ids := _recommendation_pool_ids(scene)

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(current_id, "remote-newer", "Startup should show the newest cached server recommendation when the saved current id is an old embedded item"),
		assert_false(Array(pool_ids).has(stale_id), "Stale embedded recommendation should stay out of the server-backed visible pool"),
		assert_eq(Array(pool_ids), ["remote-newer", "remote-older"], "Startup visible pool should match cached server recommendations, newest first"),
	])


func test_deck_manager_open_batch_targets_recommendation_cache_capacity() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var batch_limit := int(scene.REMOTE_RECOMMENDATION_BATCH_LIMIT)
	var cache_items := int(DeckRecommendationStoreScript.MAX_CACHE_ITEMS)

	scene.queue_free()
	return run_checks([
		assert_eq(cache_items, 20, "Recommendation cache capacity should allow twenty server recommendations"),
		assert_eq(batch_limit, cache_items, "Opening refresh should fetch the full recommendation cache target in one request"),
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


func test_deck_manager_next_button_switches_cached_recommendation_before_network() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = DeckManagerScene.instantiate()
	var fake_client := FakeDeckSuggestionClient.new()
	scene._recommendation_client = fake_client
	scene.add_child(fake_client)
	tree.root.add_child(scene)
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	var first := _remote_recommendation("remote-first-cached", 600501, "2026-05-05T01:00:00+08:00")
	var second := _remote_recommendation("remote-second-cached", 600502, "2026-05-05T02:00:00+08:00")
	var normalized_first: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(first)
	var normalized_second: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(second)
	scene._recommendation_store.call("upsert_item", normalized_first, true)
	scene._recommendation_store.call("upsert_item", normalized_second, false)
	scene._current_recommendation = normalized_first
	scene._recommendation_fetch_in_progress = false
	scene._recommendation_fetch_reason = ""
	fake_client.calls.clear()
	scene._refresh_recommendation_cards()

	scene._on_recommendation_next_pressed()
	scene._refresh_recommendation_cards()
	var current_id := str(scene._current_recommendation.get("id", ""))
	var call_count := fake_client.calls.size()
	var next_button := scene.find_child("RecommendationNextButton", true, false) as Button
	var button_text := next_button.text if next_button != null else ""
	var button_disabled := next_button.disabled if next_button != null else true
	var fetch_reason := str(scene._recommendation_fetch_reason)

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(current_id, "remote-second-cached", "Next should switch to an already cached recommendation immediately"),
		assert_eq(call_count, 0, "Next should not make a follow-up server request after a local switch"),
		assert_true(fetch_reason != "cycle", "The next button should not enter the foreground network cycle state after a local switch"),
		assert_false(button_disabled, "Local switching should keep the next button enabled"),
		assert_eq(button_text, "换一套", "Local switching should not show a loading label"),
	])


func test_deck_manager_open_batch_response_caches_twenty_and_next_stays_local() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = DeckManagerScene.instantiate()
	var fake_client := FakeDeckSuggestionClient.new()
	scene._recommendation_client = fake_client
	scene.add_child(fake_client)
	tree.root.add_child(scene)
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()

	var batch: Array = []
	for index: int in range(20):
		batch.append(_remote_recommendation("remote-batch-%02d" % index, 621000 + index, "2026-06-14T14:20:00+08:00"))

	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "open_refresh"
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendations": batch})
	var current_after_batch := str(scene._current_recommendation.get("id", ""))
	var cached_items: Array = scene._recommendation_store.call("get_items")
	var cached_first := str((cached_items[0] as Dictionary).get("id", "")) if cached_items.size() > 0 else ""
	var cached_last := str((cached_items[19] as Dictionary).get("id", "")) if cached_items.size() > 19 else ""

	fake_client.calls.clear()
	scene._on_recommendation_next_pressed()
	var current_after_next := str(scene._current_recommendation.get("id", ""))
	var call_count := fake_client.calls.size()

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(cached_items.size(), 20, "Opening batch response should fill the local recommendation cache"),
		assert_eq(current_after_batch, "remote-batch-00", "Opening batch response should show the latest server recommendation first"),
		assert_eq(cached_first, "remote-batch-00", "Recommendation cache should preserve the first server item"),
		assert_eq(cached_last, "remote-batch-19", "Recommendation cache should preserve all twenty server items in order"),
		assert_eq(current_after_next, "remote-batch-01", "Next should switch to the next cached server recommendation"),
		assert_eq(call_count, 0, "Next should not request another server recommendation after the opening batch"),
	])


func test_deck_manager_prefetch_does_not_disable_recommendation_actions() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "prefetch"
	scene._refresh_recommendation_cards()

	var next_button := scene.find_child("RecommendationNextButton", true, false) as Button
	var import_button := scene.find_child("RecommendationImportButton", true, false) as Button
	var next_text := next_button.text if next_button != null else ""
	var next_disabled := next_button.disabled if next_button != null else true
	var import_disabled := import_button.disabled if import_button != null else true

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_false(next_disabled, "Background prefetch should not block switching recommendations"),
		assert_false(import_disabled, "Background prefetch should not block importing the visible recommendation"),
		assert_eq(next_text, "换一套", "Background prefetch should not show a blocking loading label"),
	])


func test_deck_manager_background_server_result_is_next_visible_recommendation() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	var first := _remote_recommendation("remote-first-cached", 600511, "2026-05-05T01:00:00+08:00")
	var second := _remote_recommendation("remote-second-cached", 600512, "2026-05-05T02:00:00+08:00")
	var fresh := _remote_recommendation("remote-fresh-from-server", 600513, "2026-05-05T03:00:00+08:00")
	var normalized_first: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(first)
	var normalized_second: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(second)
	scene._recommendation_store.call("upsert_item", normalized_first, true)
	scene._recommendation_store.call("upsert_item", normalized_second, false)
	scene._current_recommendation = normalized_second
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "cycle_background"

	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": fresh})
	var current_after_response := str(scene._current_recommendation.get("id", ""))
	scene._on_recommendation_next_pressed()
	var current_after_next := str(scene._current_recommendation.get("id", ""))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(current_after_response, "remote-second-cached", "Background server result should not unexpectedly replace the visible card"),
		assert_eq(current_after_next, "remote-fresh-from-server", "The next click after a background server response should show the fresh server recommendation first"),
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


func test_deck_manager_keeps_current_remote_when_server_returns_duplicate() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var remote := _remote_recommendation("remote-current", 600301, "2026-05-05T03:00:00+08:00")
	var normalized: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(remote)
	scene._recommendation_store.call("upsert_item", normalized, true)
	scene._current_recommendation = normalized
	var first_id := str(scene._current_recommendation.get("id", ""))
	scene._recommendation_fetch_in_progress = true
	scene._on_remote_recommendation_succeeded({
		"ok": true,
		"recommendation": remote,
	})
	var next_id := str(scene._current_recommendation.get("id", ""))
	var pool_ids := _recommendation_pool_ids(scene)

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(first_id, "remote-current", "Initial server recommendation should have a stable id"),
		assert_eq(next_id, "remote-current", "Duplicate server response should keep the current server recommendation"),
		assert_eq(Array(pool_ids), ["remote-current"], "Server recommendation pool should not fall back to embedded articles when only one server item exists"),
	])


func test_deck_manager_remote_recommendations_hide_embedded_feed() -> String:
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
	var duplicate_id := str(scene._current_recommendation.get("id", ""))
	var pool_ids := _recommendation_pool_ids(scene)

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_true(first_id != "", "Embedded fallback should still be available before the server responds"),
		assert_eq(remote_id, "remote-raging-bolt", "First remote fetch should add the server recommendation into the cycle"),
		assert_eq(duplicate_id, "remote-raging-bolt", "Duplicate server response should keep the visible server recommendation instead of switching to embedded"),
		assert_eq(Array(pool_ids), ["remote-raging-bolt"], "Once server recommendations exist, embedded 5.1 articles should not remain in the visible cycle"),
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
	var cycled_id := str(scene._current_recommendation.get("id", ""))

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_true(first_id != "", "Embedded fallback should still initialize when the server has not responded"),
		assert_eq(newer_id, "remote-dragapult", "First remote item should become visible when the server responds"),
		assert_eq(older_id, "remote-raging-bolt", "Older same-day remote item should be the next card, not skipped. Pool: %s" % ",".join(pool_after_older)),
		assert_eq(Array(pool_after_older), ["remote-dragapult", "remote-raging-bolt"], "Visible recommendation pool should match server items only, newest first"),
		assert_eq(cycled_id, "remote-dragapult", "After the oldest server item, cycling should wrap to the newest server item, not embedded recommendations"),
	])


func test_deck_manager_preserves_remote_sequence_when_timestamps_match() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var same_timestamp := "2026-06-14T14:20:00+08:00"
	var latest := _remote_recommendation("m-first-from-server", 620658, same_timestamp)
	var second := _remote_recommendation("a-second-by-id", 620880, same_timestamp)
	var third := _remote_recommendation("z-third-by-id", 620889, same_timestamp)
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "open_refresh"
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": latest})
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "prefetch"
	scene._recommendation_prefetch_remaining = 0
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": second})
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "prefetch"
	scene._recommendation_prefetch_remaining = 0
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": third})
	var pool_ids := _recommendation_pool_ids(scene)

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_eq(Array(pool_ids), ["m-first-from-server", "a-second-by-id", "z-third-by-id"], "Same-timestamp server recommendations should keep cloud sequence instead of id order"),
	])


func test_deck_manager_prefetch_rehydrates_stale_cached_server_order() -> String:
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	var scene: Control = DeckManagerScene.instantiate()
	scene._apply_hud_theme()
	_configure_recommendation_test_state(scene, TEST_RECOMMENDATION_CACHE_PATH)
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()

	var stale_second := _remote_recommendation("a-second-by-id", 620880, "2026-06-14T14:20:00+08:00")
	scene._recommendation_store.call("upsert_item", stale_second, false)
	var latest := _remote_recommendation("m-first-from-server", 620658, "2026-06-14T14:20:00+08:00")
	scene._recommendation_fetch_in_progress = true
	scene._recommendation_fetch_reason = "open_refresh"
	scene._on_remote_recommendation_succeeded({"ok": true, "recommendation": latest})
	var exclude_ids: PackedStringArray = scene._prefetch_recommendation_exclude_ids()

	scene.queue_free()
	_delete_user_file(TEST_RECOMMENDATION_CACHE_PATH)
	return run_checks([
		assert_contains(exclude_ids, "m-first-from-server", "Current latest recommendation should be excluded from prefetch"),
		assert_false(Array(exclude_ids).has("a-second-by-id"), "Stale cached server recommendation without current order metadata should be fetched again"),
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
	scene._begin_pending_import_now_for_tests()
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


func test_import_start_defers_importer_until_busy_modal_is_drawable() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	var fake_importer := FakeDeckImporter.new()
	scene._importer = fake_importer
	scene.add_child(fake_importer)
	var url_input := scene.get_node("%UrlInput") as LineEdit
	url_input.text = "https://tcg.mik.moe/decks/list/574793"

	scene._on_do_import()
	var immediate_count := fake_importer.imported_urls.size()
	var queued_url: String = scene._pending_import_start_url
	var import_button := scene.get_node("%BtnDoImport") as Button
	var progress_bar := scene.get_node("%ProgressBar") as ProgressBar
	var input_locked: bool = not url_input.editable
	var import_button_locked: bool = import_button.disabled and not import_button.visible
	var busy_visible: bool = progress_bar.visible and bool(scene.get_node("%ImportPanel").visible)

	scene._begin_pending_import_now_for_tests()
	var final_count := fake_importer.imported_urls.size()
	var requested_url := fake_importer.imported_urls[0] if final_count > 0 else ""

	scene.queue_free()
	return run_checks([
		assert_eq(immediate_count, 0, "Deck importer should not start in the same frame as the Android import button tap"),
		assert_eq(queued_url, "https://tcg.mik.moe/decks/list/574793", "Deck import should queue the requested URL while the busy modal becomes visible"),
		assert_true(input_locked, "Deck import should lock the URL input before the importer starts"),
		assert_true(import_button_locked, "Deck import should hide and disable the confirm button before the importer starts"),
		assert_true(busy_visible, "Deck import should show the busy modal before the importer starts"),
		assert_eq(final_count, 1, "Queued deck import should still start after the busy-frame handoff"),
		assert_eq(requested_url, "https://tcg.mik.moe/decks/list/574793", "Queued deck import should preserve the requested URL"),
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


func test_duplicate_import_rename_dialog_uses_phone_sized_controls_in_portrait() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.call("_apply_hud_theme")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene._show_import_rename_dialog("Duplicate Deck Name")

	var dialog: AcceptDialog = scene._rename_dialog
	var scroll: ScrollContainer = null
	if dialog != null:
		for child: Node in dialog.get_children():
			if child is ScrollContainer:
				scroll = child
				break
	var input_height: float = scene._rename_input.custom_minimum_size.y if scene._rename_input != null else 0.0
	var input_font: int = scene._rename_input.get_theme_font_size("font_size") if scene._rename_input != null else 0
	var confirm_height: float = scene._rename_confirm_button.custom_minimum_size.y if scene._rename_confirm_button != null else 0.0
	var confirm_font: int = scene._rename_confirm_button.get_theme_font_size("font_size") if scene._rename_confirm_button != null else 0

	scene.queue_free()
	return run_checks([
		assert_not_null(dialog, "duplicate import should open the rename dialog"),
		assert_true(dialog != null and dialog.size.x >= 330, "portrait rename dialog should use most of a phone-width screen"),
		assert_true(dialog != null and dialog.size.y >= 440, "portrait rename dialog should be tall enough for readable duplicate-name guidance"),
		assert_not_null(scroll, "portrait rename dialog should keep content inside a scroll container"),
		assert_true(scroll != null and bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), "portrait rename dialog should support touch drag scrolling without a visible scrollbar"),
		assert_true(input_height >= 98.0 and input_font >= 29, "portrait rename input should be large enough to tap and read"),
		assert_true(confirm_height >= 104.0 and confirm_font >= 33, "portrait rename confirm button should be large enough to tap and read"),
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


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node == null:
		return
	if node is Button:
		out.append(node as Button)
	for child: Node in node.get_children():
		_collect_buttons(child, out)


func _collect_labels(node: Node, out: Array[Label]) -> void:
	if node == null:
		return
	if node is Label:
		out.append(node as Label)
	for child: Node in node.get_children():
		_collect_labels(child, out)


func _first_confirmation_dialog(node: Node) -> ConfirmationDialog:
	if node == null:
		return null
	if node is ConfirmationDialog:
		return node as ConfirmationDialog
	for child: Node in node.get_children():
		var found := _first_confirmation_dialog(child)
		if found != null:
			return found
	return null


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


func _emit_android_touch_on_button(button: Button) -> void:
	if button == null:
		return
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = button.get_global_rect().get_center()
	button.gui_input.emit(press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	button.gui_input.emit(release)
