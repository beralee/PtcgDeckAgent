class_name TestBattleSetupMusic
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")
const SETTINGS_PATH := "user://battle_setup.json"


func _set_navigation_suppressed(suppressed: bool) -> void:
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", suppressed)


func _force_two_player_mode(scene: Control) -> void:
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	if mode_option == null:
		return
	if mode_option.item_count > 0:
		mode_option.select(0)
	scene.call("_refresh_deck_options")
	scene.call("_refresh_ai_ui_visibility")


func _read_settings_text() -> String:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _restore_settings_text(original_text: String) -> void:
	if original_text == "":
		var absolute_path := ProjectSettings.globalize_path(SETTINGS_PATH)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func _write_settings(data: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _snapshot_game_manager_state() -> Dictionary:
	return {
		"current_mode": int(GameManager.current_mode),
		"selected_deck_ids": GameManager.selected_deck_ids.duplicate(),
		"first_player_choice": int(GameManager.first_player_choice),
		"selected_battle_music_id": str(GameManager.selected_battle_music_id),
		"battle_bgm_volume_percent": int(GameManager.battle_bgm_volume_percent),
		"battle_layout_mode": str(GameManager.battle_layout_mode),
		"dynamic_stadium_background_enabled": bool(GameManager.dynamic_stadium_background_enabled),
		"ai_selection": GameManager.ai_selection.duplicate(true),
		"ai_deck_strategy": str(GameManager.ai_deck_strategy),
		"suppress_scene_navigation_for_tests": bool(GameManager.suppress_scene_navigation_for_tests),
		"last_requested_scene_path": str(GameManager.last_requested_scene_path),
	}


func _restore_game_manager_state(snapshot: Dictionary) -> void:
	GameManager.current_mode = int(snapshot.get("current_mode", GameManager.GameMode.TWO_PLAYER))
	var restored_deck_ids: Array[int] = []
	for deck_id_variant: Variant in snapshot.get("selected_deck_ids", [0, 0]):
		restored_deck_ids.append(int(deck_id_variant))
	GameManager.selected_deck_ids = restored_deck_ids
	GameManager.first_player_choice = int(snapshot.get("first_player_choice", -1))
	GameManager.selected_battle_music_id = str(snapshot.get("selected_battle_music_id", "none"))
	GameManager.battle_bgm_volume_percent = int(snapshot.get("battle_bgm_volume_percent", 20))
	GameManager.battle_layout_mode = str(snapshot.get("battle_layout_mode", GameManager.BATTLE_LAYOUT_AUTO))
	GameManager.dynamic_stadium_background_enabled = bool(snapshot.get("dynamic_stadium_background_enabled", true))
	GameManager.ai_selection = (snapshot.get("ai_selection", {}) as Dictionary).duplicate(true)
	GameManager.ai_deck_strategy = str(snapshot.get("ai_deck_strategy", "generic"))
	GameManager.suppress_scene_navigation_for_tests = bool(snapshot.get("suppress_scene_navigation_for_tests", false))
	GameManager.last_requested_scene_path = str(snapshot.get("last_requested_scene_path", ""))


func _dispose_scene(scene: Node) -> void:
	if scene == null:
		return
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.free()


func test_battle_setup_populates_bgm_option() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_setup_battle_music_options")

	var bgm_option := scene.get_node("%BgmOption") as OptionButton
	var bgm_hint := scene.get_node("%BgmHint") as Label
	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	var bgm_volume_value := scene.get_node("%BgmVolumeValue") as Label
	var preview_button := scene.get_node("%BtnPreviewBgm") as Button
	var expected_prefix := ProjectSettings.globalize_path("user://custom_bgm")

	var result := run_checks([
		assert_true(bgm_option != null, "对战设置页应存在 BGM 下拉框"),
		assert_true(bgm_option.item_count >= 1, "BGM 下拉框至少应包含无音乐选项"),
		assert_true(str(bgm_hint.text).contains(expected_prefix), "应显示自定义音乐的绝对路径"),
		assert_true(bgm_volume_slider != null, "应提供 BGM 音量滑块"),
		assert_true(bgm_volume_value != null, "应提供 BGM 音量文本"),
		assert_true(preview_button != null, "应提供 BGM 试听按钮"),
	])

	_dispose_scene(scene)
	_restore_game_manager_state(gm_snapshot)
	return result


func test_battle_setup_applies_selected_bgm_volume_to_game_manager() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_setup_battle_music_options")
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

	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	bgm_volume_slider.value = 37
	scene.call("_apply_setup_selection")
	var applied := int(GameManager.get("battle_bgm_volume_percent"))

	_dispose_scene(scene)
	_restore_game_manager_state(gm_snapshot)
	return run_checks([
		assert_eq(applied, 37, "应把对战 BGM 音量写入 GameManager"),
	])


func test_battle_setup_defaults_bgm_volume_to_20_without_saved_settings() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var original_settings_text := _read_settings_text()
	_restore_settings_text("")
	var previous_track := GameManager.selected_battle_music_id
	var previous_volume := int(GameManager.battle_bgm_volume_percent)
	GameManager.load_battle_setup_preferences()

	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	var bgm_volume_value := scene.get_node("%BgmVolumeValue") as Label

	var result := run_checks([
		assert_eq(int(round(bgm_volume_slider.value)), 20, "首次启动且没有保存设置时，BGM 音量应默认为 20"),
		assert_eq(bgm_volume_value.text, "20%", "首次启动时应显示 20% 的默认 BGM 音量"),
	])

	_dispose_scene(scene)
	GameManager.selected_battle_music_id = previous_track
	GameManager.battle_bgm_volume_percent = previous_volume
	_restore_settings_text(original_settings_text)
	_restore_game_manager_state(gm_snapshot)
	return result


func test_battle_setup_portrait_migrates_legacy_bgm_volume_100_to_20() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var original_settings_text := _read_settings_text()
	_write_settings({
		"battle_layout_mode": GameManager.BATTLE_LAYOUT_PORTRAIT,
		"battle_music_id": "pokemon_sv_battle_gym_leader",
		"battle_bgm_volume_percent": 100,
		"mode": 0,
	})
	GameManager.load_battle_setup_preferences()
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	var bgm_volume_slider := scene.find_child("BgmVolumeSlider", true, false) as HSlider
	var bgm_volume_value := scene.find_child("BgmVolumeValue", true, false) as Label
	var selected_volume := int(scene.get("_selected_battle_music_volume_percent"))

	var result := run_checks([
		assert_eq(int(round(bgm_volume_slider.value)), 20, "Portrait BattleSetup should migrate legacy saved BGM volume 100 to the shared 20 default"),
		assert_eq(bgm_volume_value.text, "20%", "Portrait BattleSetup volume label should show the migrated 20 default"),
		assert_eq(selected_volume, 20, "Portrait BattleSetup internal selected BGM volume should also migrate to 20"),
	])

	_dispose_scene(scene)
	_restore_settings_text(original_settings_text)
	_restore_game_manager_state(gm_snapshot)
	return result


func test_battle_setup_back_persists_bgm_volume_setting() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var original_settings_text := _read_settings_text()
	_restore_settings_text("")
	_set_navigation_suppressed(true)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	bgm_volume_slider.value = 24
	scene.call("_on_back")

	var saved_text := _read_settings_text()
	var json := JSON.new()
	var parse_ok := json.parse(saved_text) == OK
	var saved_data: Dictionary = json.data if parse_ok and json.data is Dictionary else {}

	_dispose_scene(scene)
	_set_navigation_suppressed(false)
	_restore_settings_text(original_settings_text)
	_restore_game_manager_state(gm_snapshot)
	return run_checks([
		assert_true(parse_ok, "返回对战设置后应写入 battle_setup.json"),
		assert_eq(int(saved_data.get("battle_bgm_volume_percent", -1)), 24, "返回主菜单时应持久化当前 BGM 音量"),
	])


func test_battle_setup_preview_button_reflects_playing_state() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_setup_battle_music_options")

	var bgm_option := scene.get_node("%BgmOption") as OptionButton
	var preview_button := scene.get_node("%BtnPreviewBgm") as Button
	bgm_option.select(1)
	scene.call("_on_bgm_preview_pressed")
	var after_start := preview_button.text
	scene.call("_on_bgm_preview_pressed")
	var after_stop := preview_button.text

	BattleMusicManager.stop_battle_music()
	_dispose_scene(scene)
	_restore_game_manager_state(gm_snapshot)
	return run_checks([
		assert_eq(after_start, "停止试听", "开始试听后按钮文案应切换"),
		assert_eq(after_stop, "试听", "停止试听后按钮文案应恢复"),
	])


func test_battle_setup_preview_respects_volume_slider_changes_in_real_time() -> String:
	var gm_snapshot := _snapshot_game_manager_state()
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)
	scene.call("_setup_battle_music_options")

	var bgm_option := scene.get_node("%BgmOption") as OptionButton
	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	bgm_option.select(1)
	scene.call("_on_bgm_preview_pressed")
	bgm_volume_slider.value = 25
	scene.call("_on_bgm_volume_changed", 25.0)
	var audio_player := BattleMusicManager.get_node("BattleMusicPlayer") as AudioStreamPlayer
	var quiet_volume := float(audio_player.volume_db)
	bgm_volume_slider.value = 90
	scene.call("_on_bgm_volume_changed", 90.0)
	var loud_volume := float(audio_player.volume_db)

	BattleMusicManager.stop_battle_music()
	_dispose_scene(scene)
	_restore_game_manager_state(gm_snapshot)
	return run_checks([
		assert_true(loud_volume > quiet_volume, "试听中调高音量应立即提高播放器音量"),
	])
