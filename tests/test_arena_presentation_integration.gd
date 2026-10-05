extends TestBase
const Presentation := preload("res://scripts/ui/battle/BattlePresentation.gd")

func test_windows_gallery_keeps_grove_and_all_classic_fields() -> String:
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	var paths: Array = setup.call("_list_available_background_paths")
	setup.set("_battle_backgrounds", paths)
	var expected: Array[String] = [
		"res://assets/arena3d/previews/grove.png",
		"res://assets/ui/background.png",
		"res://assets/ui/background1.png",
		"res://assets/ui/background2.png",
		"res://assets/ui/background3.png",
		"res://assets/ui/background4.png",
	]
	var checks: Array[String] = [assert_eq(paths, expected, "Windows retains only grove among 3D fields and preserves every classic field in order")]
	for previous: String in ["", "res://assets/arena3d/previews/league.png"]:
		checks.append(assert_eq(setup.call("_available_background_or_default", previous), "res://assets/arena3d/previews/grove.png", "Removed or missing selections must resolve to the visible grove field"))
	for retained: String in expected:
		checks.append(assert_eq(setup.call("_available_background_or_default", retained), retained, "Existing 2D and grove selections stay valid"))
	setup.free()
	return run_checks(checks)

func test_main_menu_and_save_identity_are_preserved() -> String:
	var error := assert_eq(GameManager.SCENE_MAIN_MENU, "res://scenes/main_menu/MainMenu.tscn", "3D battle must retain the current main menu")
	if error != "": return error
	error = assert_eq(str(ProjectSettings.get_setting("application/config/name")), "PtcgDeckAgent", "Keep existing saves")
	if error != "": return error
	return assert_eq(str(ProjectSettings.get_setting("application/run/main_scene")), GameManager.SCENE_MAIN_MENU, "Ordinary launch uses the same menu")

func test_setup_renders_grove_badge_and_classic_field_cards() -> String:
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(setup)
	await tree.process_frame
	await tree.process_frame
	var choice := setup.find_child("BattlePresentationButton", true, false) as Button
	var paths: Array = setup.get("_battle_backgrounds")
	var error := run_checks([
		assert_true(choice == null, "The separate presentation button must be removed"),
		assert_eq(paths.front(), "res://assets/arena3d/previews/grove.png", "The retained 3D field precedes classic fields"),
	])
	var cards: Array = setup.get("_background_cards")
	var count_error := assert_eq(cards.size(), 6, "The rendered gallery contains grove plus five classic fields")
	if error == "": error = count_error
	for i in range(cards.size()):
		var card := cards[i] as Control
		var badge := card.find_child("Field3DBadge", true, false) as Label
		var preview := card.find_child("FieldPreview", true, false) as TextureRect
		var caption := card.find_child("FieldName", true, false) as Label
		if i > 0:
			var classic_error := run_checks([
				assert_true(badge == null, "Classic fields must not show a 3D badge"),
				assert_true(preview != null and preview.texture != null, "Classic thumbnails remain available"),
			])
			if error == "": error = classic_error
			continue
		var detail := run_checks([
			assert_true(badge != null and badge.text == "3D", "The grove has a visible badge"),
			assert_true(badge != null and badge.anchor_right == 1.0 and badge.anchor_bottom == 1.0, "Badge is anchored at the bottom right"),
			assert_true(preview != null and preview.texture != null, "The grove has a real preview"),
			assert_true(caption != null and caption.text == "林间道馆", "The screenshot retains a readable field name"),
		])
		if error == "": error = detail
	setup.queue_free()
	await tree.process_frame
	return error

func test_saved_field_survives_deferred_gallery_and_setup_return() -> String:
	var path := "user://battle_setup.json"
	var existed := FileAccess.file_exists(path)
	var previous := FileAccess.get_file_as_string(path) if existed else ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"background_path": "res://assets/ui/background4.png"}))
	file.close()
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	tree.root.add_child(setup)
	await tree.process_frame
	await tree.process_frame
	var checks: Array[String] = [assert_eq(setup.get("_selected_background_path"), "res://assets/ui/background4.png", "Deferred thumbnails preserve the saved 2D field")]
	var context: Dictionary = setup.call("_capture_setup_selection_context")
	setup.call("_select_background_path", "res://assets/arena3d/previews/grove.png")
	setup.call("_apply_setup_context", context)
	setup.call("_refresh_background_gallery")
	checks.append(assert_eq(setup.get("_selected_background_path"), "res://assets/ui/background4.png", "A deck-editor return context preserves its 2D field"))
	context["background_path"] = "res://assets/arena3d/previews/league.png"
	setup.call("_apply_setup_context", context)
	setup.call("_refresh_background_gallery")
	checks.append(assert_eq(setup.get("_selected_background_path"), "res://assets/arena3d/previews/grove.png", "A stale deck-editor return context resolves to the retained field"))
	checks.append(assert_false(setup.call("_select_background_path", "res://assets/arena3d/previews/league.png"), "The removed field cannot be selected"))
	setup.queue_free()
	await tree.process_frame
	if existed:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(previous)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return run_checks(checks)

func test_windows_and_android_allow_3d_and_preserve_2d_choice() -> String:
	var old_mode := GameManager.battle_layout_mode
	var old_3d := GameManager.battle_3d_enabled
	var old_profile := GameManager.ui_runtime_profile
	GameManager.battle_3d_enabled = true
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var error := assert_true(Presentation.requested_3d(), "Portrait supports the adapted 3D layout")
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind": "native", "native_os": "android", "mobile_like": true})
	var mobile_error := assert_true(Presentation.requested_3d(), "Android exposes the portable 3D selection")
	GameManager.battle_3d_enabled = false
	var fallback_error := assert_false(Presentation.requested_3d(), "The player can still select 2D")
	GameManager.ui_runtime_profile = old_profile
	GameManager.battle_layout_mode = old_mode
	GameManager.battle_3d_enabled = old_3d
	return error if error != "" else (mobile_error if mobile_error != "" else fallback_error)

func test_3d_scene_pins_mode_without_changing_global_effects() -> String:
	var old_3d := GameManager.battle_3d_enabled
	var old_effects := GameManager.battle_effects_enabled
	var old_mode := GameManager.current_mode
	var old_layout := GameManager.battle_layout_mode
	var old_decks := GameManager.selected_deck_ids.duplicate()
	GameManager.battle_3d_enabled = true
	GameManager.battle_effects_enabled = true
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	GameManager.selected_deck_ids.assign([575720, 575720])
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var checks: Array[String] = [
		assert_true(scene.has_node("Arena3DPresenter"), "Install 3D in the existing battle scene"),
		assert_true(GameManager.battle_effects_enabled, "3D must not rewrite the player's effect preference"),
		assert_false(Presentation.legacy_effects_enabled(scene), "3D owns this scene's motion"),
		assert_true(Presentation.legacy_effects_enabled(null), "Other presentation owners remain unaffected"),
	]
	GameManager.battle_3d_enabled = false
	checks.append(assert_true(Presentation.is_3d_scene(scene), "A preference change cannot hot-swap a running match"))
	scene.queue_free()
	await tree.process_frame
	GameManager.battle_3d_enabled = old_3d
	GameManager.battle_effects_enabled = old_effects
	GameManager.current_mode = old_mode
	GameManager.battle_layout_mode = old_layout
	GameManager.selected_deck_ids.assign(old_decks)
	for error: String in checks:
		if error != "": return error
	return ""
