class_name TestReplayBrowser
extends TestBase

const DECK_CENTER_META_STATE_PATH := "user://deck_center_meta_state.json"


class FakeRecordIndex extends RefCounted:
	func list_rows() -> Array[Dictionary]:
		return [{
			"match_id": "match_new",
			"match_dir": "user://match_records/match_new",
			"recorded_at": "2026-04-04 13:00",
			"player_labels": ["Player A", "Player B"],
			"winner_index": 1,
			"first_player_index": 0,
			"turn_count": 9,
			"final_prize_counts": [2, 0],
		}]


class FakeReplayLocator extends RefCounted:
	var _result: Dictionary = {}

	func _init(result: Dictionary) -> void:
		_result = result.duplicate(true)

	func locate(_match_dir: String) -> Dictionary:
		return _result.duplicate(true)


func _remove_deck_center_meta_state_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(DECK_CENTER_META_STATE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _read_deck_center_meta_state() -> Dictionary:
	if not FileAccess.file_exists(DECK_CENTER_META_STATE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_CENTER_META_STATE_PATH))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func test_replay_browser_and_ai_settings_use_hud_panels() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var replay_scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	var settings_scene: Control = load("res://scenes/settings/Settings.tscn").instantiate()
	tree.root.add_child(replay_scene)
	tree.root.add_child(settings_scene)
	replay_scene.call("_apply_hud_theme")
	settings_scene.call("_apply_hud_theme")
	settings_scene.call("_load_config")

	var replay_frame := replay_scene.get_node_or_null("HudFrame") as PanelContainer
	var settings_frame := settings_scene.get_node_or_null("HudFrame") as PanelContainer
	var replay_style := replay_frame.get_theme_stylebox("panel") as StyleBoxFlat if replay_frame != null else null
	var settings_style := settings_frame.get_theme_stylebox("panel") as StyleBoxFlat if settings_frame != null else null
	var settings_endpoint := settings_scene.get_node_or_null("%EndpointInput") as LineEdit
	var settings_personality := settings_scene.get_node_or_null("%PersonalityInput") as LineEdit
	var settings_save := settings_scene.get_node_or_null("%BtnSave") as Button
	var settings_form := settings_scene.get_node_or_null("VBoxContainer") as Control
	var settings_guide := settings_scene.find_child("ZenMuxGuideBody", true, false) as Label
	var settings_troubleshooting := settings_scene.find_child("ZenMuxTroubleBody", true, false) as Label
	var endpoint_style := settings_endpoint.get_theme_stylebox("normal") as StyleBoxFlat if settings_endpoint != null else null
	var save_style := settings_save.get_theme_stylebox("normal") as StyleBoxFlat if settings_save != null else null

	var result := run_checks([
		assert_true(replay_style != null and replay_style.bg_color.a < 0.9, "Replay browser should use a translucent HUD frame"),
		assert_true(settings_style != null and settings_style.bg_color.a < 0.9, "AI settings should use a translucent HUD frame"),
		assert_true(settings_frame != null and settings_form != null and settings_frame.offset_bottom > settings_form.offset_bottom + 50.0, "AI settings HUD frame should extend below the button row"),
		assert_true(endpoint_style != null and endpoint_style.bg_color.a < 1.0, "AI settings inputs should use translucent HUD styling"),
		assert_true(save_style != null and save_style.border_color.a > 0.8, "AI settings buttons should use explicit HUD borders"),
		assert_eq(settings_endpoint.text if settings_endpoint != null else "", "https://zenmux.ai/api/v1", "AI settings should prefill the ZenMux API address"),
		assert_eq(settings_personality.text if settings_personality != null else "", GameManager.DEFAULT_AI_PERSONALITY, "AI settings should prefill the default AI personality"),
		assert_not_null(settings_scene.find_child("BtnUseZenMuxDefault", true, false), "AI settings should expose the original default endpoint helper button"),
		assert_not_null(settings_scene.find_child("BtnOpenZenMux", true, false), "AI settings should expose the original zenmux.ai link button"),
		assert_true(settings_guide != null and settings_guide.text.contains("https://zenmux.ai/api/v1"), "AI settings should keep the ZenMux endpoint setup guide"),
		assert_true(settings_guide != null and settings_guide.text.contains("测试连接"), "AI settings should guide players to validate the configuration"),
		assert_true(settings_troubleshooting != null and settings_troubleshooting.text.contains("401"), "AI settings should include common ZenMux failure explanations"),
	])

	replay_scene.queue_free()
	settings_scene.queue_free()
	return result


func test_main_menu_includes_battle_replay_button() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	var replay_button := scene.get_node_or_null("VBoxContainer/BtnBattleReplay")

	return run_checks([
		assert_true(replay_button is Button, "MainMenu should expose BtnBattleReplay"),
	])


func test_main_menu_uses_hud_buttons_shifted_down() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	scene.call("_apply_main_menu_hud")
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 720), GameManager.NON_BATTLE_LAYOUT_LANDSCAPE)
	var menu := scene.get_node_or_null("VBoxContainer") as VBoxContainer
	var background := scene.get_node_or_null("Background") as Control
	var start_button := scene.get_node_or_null("%BtnStartBattle") as Button
	var deck_button := scene.get_node_or_null("%BtnDeckManager") as Button
	var button_style := start_button.get_theme_stylebox("normal") as StyleBoxFlat if start_button != null else null
	var deck_style := deck_button.get_theme_stylebox("normal") as StyleBoxFlat if deck_button != null else null

	var result := run_checks([
		assert_true(menu != null and absf(menu.offset_left - -170.0) < 0.1, "Main menu button group should be wide enough for the featured deck center action"),
		assert_true(menu != null and absf(menu.offset_top - -87.0) < 0.1, "Main menu button group should move down by one button height"),
		assert_true(menu != null and absf(menu.offset_right - 170.0) < 0.1, "Main menu button group should stay centered after the redesign"),
		assert_true(menu != null and absf(menu.offset_bottom - 263.0) < 0.1, "Main menu button group bottom should move with the top"),
		assert_null(scene.get_node_or_null("MainMenuButtonBackplate"), "Main menu actions should not add an extra backplate over the title background"),
		assert_true(button_style != null and button_style.bg_color.a < 0.9 and button_style.border_color.a > 0.5, "Main menu buttons should use softer translucent HUD button styling"),
		assert_true(button_style != null and button_style.border_color.a > 0.85, "Start battle should use a high-emphasis primary color"),
		assert_eq(start_button.custom_minimum_size, Vector2(312, 52), "Main menu start button should use the unified main action size"),
		assert_true(deck_button != null and deck_button.get_index() == 1, "Deck center should be promoted directly below start battle"),
		assert_eq(deck_button.custom_minimum_size if deck_button != null else Vector2.ZERO, Vector2(312, 52), "Deck center should keep the same size as the other main actions"),
		assert_true(deck_style != null and deck_style.border_width_left >= 2 and deck_style.border_color.a > 0.9, "Deck center should use the strongest featured HUD border without changing size"),
		assert_eq(background.mouse_filter if background != null else -1, Control.MOUSE_FILTER_IGNORE, "Main menu background should not consume unhandled mascot clicks"),
	])

	scene.queue_free()
	return result


func test_main_menu_clears_deck_center_new_from_latest_local_meta_without_pending_signal() -> String:
	_remove_deck_center_meta_state_file()
	var file := FileAccess.open(DECK_CENTER_META_STATE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"latest_info": {
			"latest_revision": "local-startup-rev",
			"latest_recommendation_id": "rec-local",
			"latest_deck_id": 609793,
			"source": "unit_test",
		},
	}, "\t"))
	file.close()

	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	scene.set("_pending_deck_center_meta", {})
	scene.call("_set_deck_center_new_badge_visible", true)
	scene.call("_mark_pending_deck_center_meta_seen")

	var state := _read_deck_center_meta_state()
	var badge := scene.get("_deck_center_new_badge") as PanelContainer
	var result := run_checks([
		assert_eq(str(state.get("last_seen_revision", "")), "local-startup-rev", "Opening deck center should mark the latest locally cached deck-center revision as seen even if the startup signal is not pending anymore"),
		assert_false(badge != null and badge.visible, "Opening deck center should hide the main-menu NEW badge even when only local metadata is available"),
	])

	scene.queue_free()
	_remove_deck_center_meta_state_file()
	return result


func test_main_menu_budew_mascot_dodges_click_without_blocking_menu_layer() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	scene.call("_ensure_budew_mascot")
	var layer := scene.get_node_or_null("BudewMascotLayer") as Control
	var sprite := scene.get_node_or_null("BudewMascotLayer/BudewMascotSprite") as TextureRect
	var start := Vector2(120.0, 500.0)
	scene.set("_budew_mascot_position", start)
	var sprite_size: Vector2 = scene.call("_budew_mascot_display_size")
	var click_position := start + sprite_size * 0.5
	scene.call("_position_budew_mascot")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	press.global_position = click_position
	scene.call("_handle_budew_mascot_unhandled_input", press)
	var unhandled_dodge_tween: Tween = scene.get("_budew_mascot_dodge_tween")
	var unhandled_dodge_started := unhandled_dodge_tween != null and is_instance_valid(unhandled_dodge_tween)
	scene.call("_stop_budew_mascot_dodge")
	var target: Vector2 = scene.call("_budew_mascot_dodge_target_for_click", click_position)
	var left_click_target: Vector2 = scene.call("_budew_mascot_dodge_target_for_click", start + Vector2(2.0, sprite_size.y * 0.5))
	var right_click_target: Vector2 = scene.call("_budew_mascot_dodge_target_for_click", start + Vector2(sprite_size.x - 2.0, sprite_size.y * 0.5))
	scene.call("_apply_budew_mascot_dodge", 0.5, start, target)
	var mid_jump := float(scene.get("_budew_mascot_jump_offset"))
	scene.call("_apply_budew_mascot_dodge", 1.0, start, target)
	var end_position := scene.get("_budew_mascot_position") as Vector2

	var result := run_checks([
		assert_not_null(layer, "Main menu should create the Budew mascot layer"),
		assert_not_null(sprite, "Main menu should create the Budew mascot sprite"),
		assert_eq(layer.mouse_filter if layer != null else -1, Control.MOUSE_FILTER_IGNORE, "Budew layer should not block normal main-menu controls"),
		assert_eq(sprite.mouse_filter if sprite != null else -1, Control.MOUSE_FILTER_IGNORE, "Budew sprite should not participate in GUI hit-testing over main-menu buttons"),
		assert_true(unhandled_dodge_started, "Budew should still start a dodge tween from unhandled pointer input"),
		assert_true(absf(target.x - start.x) >= 80.0, "Budew dodge target should move sideways instead of only bobbing in place"),
		assert_true(left_click_target.x > start.x, "Clicking Budew's left side should make it dodge right"),
		assert_true(right_click_target.x < start.x, "Clicking Budew's right side should make it dodge left"),
		assert_true(target.distance_to(click_position) > start.distance_to(click_position) + 36.0, "Budew dodge target should be farther from the click point"),
		assert_true(mid_jump > 20.0, "Budew dodge should include a visible jump arc"),
		assert_eq(end_position, target, "Budew dodge tween should land on the computed target"),
	])

	scene.queue_free()
	return result


func test_main_menu_start_button_area_is_not_covered_by_budew_input_controls() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	scene.size = Vector2(1280, 720)
	scene.call("_apply_main_menu_hud")
	scene.call("_ensure_budew_mascot")
	var start_button := scene.get_node_or_null("%BtnStartBattle") as Button
	var button_center := start_button.global_position + start_button.size * 0.5 if start_button != null else Vector2(640, 360)
	var blocking_controls: Array[String] = []
	for child: Node in scene.get_children():
		if child == start_button or not (child is Control):
			continue
		if start_button != null and child.is_ancestor_of(start_button):
			continue
		var control := child as Control
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control.get_global_rect().has_point(button_center):
			blocking_controls.append(control.name)

	scene.queue_free()
	return run_checks([
		assert_not_null(start_button, "Main menu should have a start battle button"),
		assert_eq(blocking_controls, [], "No later main-menu overlay should accept GUI input over the start button center"),
	])


func test_main_menu_about_mentions_tcg_mik_dependency() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	var about_text: String = scene.call("_format_about_text")

	var result := run_checks([
		assert_str_contains(about_text, "数据来源与感谢", "About dialog should include a data-source acknowledgement section"),
		assert_str_contains(about_text, "tcg.mik.moe", "About dialog should credit tcg.mik.moe"),
		assert_str_contains(about_text, "卡组导入", "About dialog should explain the deck import dependency"),
		assert_str_contains(about_text, "赛事", "About dialog should mention tournament data usage"),
		assert_str_contains(about_text, "没有官方从属或合作关系", "About dialog should avoid implying an official partnership"),
	])

	scene.queue_free()
	return result


func test_replay_browser_renders_rows_from_record_index() -> String:
	var scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	scene.set("_record_index", FakeRecordIndex.new())
	scene.set("_replay_locator", FakeReplayLocator.new({"entry_turn_number": 6, "entry_source": "loser_key_turn", "turn_numbers": [4, 6]}))
	scene.call("_render_rows")
	var list_container := scene.find_child("ListContainer", true, false) as VBoxContainer
	var first_row := list_container.get_child(0) if list_container != null and list_container.get_child_count() > 0 else null
	var replay_button := first_row.find_child("ReplayButton", true, false) if first_row != null else null
	var delete_button := first_row.find_child("DeleteButton", true, false) if first_row != null else null
	var row_panel := first_row as PanelContainer
	var label_fonts: Array[int] = []
	if first_row != null:
		for label_node: Node in _find_labels_recursive(first_row):
			label_fonts.append((label_node as Label).get_theme_font_size("font_size"))
	label_fonts.sort()
	var smallest_label_font := label_fonts[0] if label_fonts.size() > 0 else 0
	var largest_label_font := label_fonts[label_fonts.size() - 1] if label_fonts.size() > 0 else 0

	# 收集行内所有 Label 的文本
	var all_text := ""
	if first_row != null:
		for label: Node in _find_labels_recursive(first_row):
			all_text += (label as Label).text + " "

	return run_checks([
		assert_true(list_container != null, "ReplayBrowser should expose ListContainer"),
		assert_eq(list_container.get_child_count(), 1, "ReplayBrowser should render one row for the fake index"),
		assert_true(replay_button is Button, "ReplayBrowser rows should include a Replay button"),
		assert_false((replay_button as Button).disabled, "Replay button should be enabled once locator support is wired"),
		assert_true(delete_button is Button, "ReplayBrowser rows should include a Delete button"),
		assert_true(row_panel != null and row_panel.custom_minimum_size.y >= 76.0, "Replay rows should use the same readable card height as the deck center"),
		assert_true(largest_label_font >= 23, "Replay row primary text should match the deck center list size"),
		assert_true(smallest_label_font >= 18, "Replay row secondary text should be readable instead of tiny metadata text"),
		assert_true(replay_button is Button and (replay_button as Button).get_theme_font_size("font_size") >= 21, "Replay row action buttons should use deck-center compact button text size"),
		assert_true(replay_button is Button and (replay_button as Button).custom_minimum_size.y >= 57.0, "Replay row action buttons should use deck-center compact touch height"),
		assert_true(all_text.contains("Player A"), "Replay rows should include player names"),
		assert_true(all_text.contains("Player B"), "Replay rows should include player names"),
		assert_true(all_text.contains("2026-04-04"), "Replay rows should include the recorded time"),
		assert_true(all_text.contains("2-0"), "Replay rows should include the final prize count"),
	])


func test_replay_browser_launches_battle_scene_with_locator_output() -> String:
	GameManager.consume_battle_replay_launch()
	var scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	scene.set("_auto_navigate_to_battle", false)
	scene.set("_record_index", FakeRecordIndex.new())
	scene.set("_replay_locator", FakeReplayLocator.new({
		"entry_turn_number": 6,
		"entry_source": "loser_key_turn",
		"turn_numbers": [4, 6],
	}))
	scene.call("_on_replay_pressed", {"match_dir": "user://match_records/match_a"})
	var launch: Dictionary = GameManager.consume_battle_replay_launch()

	return run_checks([
		assert_eq(str(launch.get("match_dir", "")), "user://match_records/match_a", "Replay launch should preserve match_dir"),
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay button should forward locator output into GameManager launch state"),
		assert_eq(str(launch.get("entry_source", "")), "loser_key_turn", "Replay button should preserve the locator source"),
	])


func _find_labels_recursive(node: Node) -> Array[Node]:
	var labels: Array[Node] = []
	if node is Label:
		labels.append(node)
	for child: Node in node.get_children():
		labels.append_array(_find_labels_recursive(child))
	return labels
