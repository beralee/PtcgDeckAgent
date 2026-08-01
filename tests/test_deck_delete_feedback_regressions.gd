class_name TestDeckDeleteFeedbackRegressions
extends TestBase

const DeckManagerScene := preload("res://scenes/deck_manager/DeckManager.tscn")
const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")
const MainMenuScene := preload("res://scenes/main_menu/MainMenu.tscn")
const ReplayBrowserScene := preload("res://scenes/replay_browser/ReplayBrowser.tscn")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const WebTextInputBridgeScript := preload("res://scripts/ui/non_battle/WebTextInputBridge.gd")

const DELETE_DECK_ID := 919901
const SURVIVOR_DECK_ID := 919902
const UPSERT_DECK_ID := 919903
const REPLAY_DELETE_TEST_DIR := "user://test_incremental_replay_delete"


func test_deck_delete_closes_input_transaction_before_incremental_commit() -> String:
	_cleanup_decks()
	CardDatabase.save_deck(_make_deck(DELETE_DECK_ID, "Delete Transaction Probe"))
	CardDatabase.save_deck(_make_deck(SURVIVOR_DECK_ID, "Survivor Identity Probe"))

	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = DeckManagerScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(390, 844)
	tree.root.add_child(scene)
	await tree.process_frame
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")

	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var survivor_before := _deck_row_with_id(deck_list, SURVIVOR_DECK_ID)
	var deck_to_delete := CardDatabase.get_deck(DELETE_DECK_ID)
	scene.call("_on_delete_deck", deck_to_delete)
	var confirm_button := scene.find_child("DeleteDeckConfirmButton", true, false) as Button
	var had_confirm_button := confirm_button != null
	if confirm_button != null:
		confirm_button.pressed.emit()

	var overlay_closed_before_commit := not bool(scene.call("_is_deck_action_hud_dialog_visible"))
	var delete_waits_for_idle_frame := CardDatabase.has_deck(DELETE_DECK_ID)
	await tree.process_frame

	deck_list = scene.get_node_or_null("%DeckList") as VBoxContainer
	var survivor_after := _deck_row_with_id(deck_list, SURVIVOR_DECK_ID)
	var deleted_row_after := _deck_row_with_id(deck_list, DELETE_DECK_ID)
	var result := run_checks([
		assert_true(had_confirm_button, "Portrait deck deletion should expose a touchable confirmation action"),
		assert_true(overlay_closed_before_commit, "Delete confirmation should close before the destructive commit starts"),
		assert_true(delete_waits_for_idle_frame, "Deck deletion must not rebuild UI inside the active touch callback"),
		assert_false(CardDatabase.has_deck(DELETE_DECK_ID), "The deferred delete transaction should remove the selected deck"),
		assert_null(deleted_row_after, "Incremental deletion should remove the selected deck row"),
		assert_true(survivor_before == survivor_after and is_instance_valid(survivor_before), "Deleting one deck must preserve unaffected row instances instead of rebuilding the entire list"),
	])

	scene.queue_free()
	await tree.process_frame
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	_cleanup_decks()
	return result


func test_feedback_text_touch_reopens_hidden_keyboard_without_modal_interception() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = MainMenuScene.instantiate()
	scene.position = Vector2.ZERO
	scene.size = Vector2(1080, 2400)
	tree.root.add_child(scene)
	await tree.process_frame
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1080, 2400), "portrait")
	scene.call("_show_feedback_dialog")
	await tree.process_frame

	var feedback_text := scene.find_child("FeedbackText", true, false) as TextEdit
	if feedback_text != null:
		feedback_text.grab_focus()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = feedback_text.get_global_rect().get_center() if feedback_text != null else Vector2.ZERO
	var modal_consumed_press := bool(scene.call("_handle_active_modal_input", press))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = press.position
	var modal_consumed_release := bool(scene.call("_handle_active_modal_input", release))

	var result := run_checks([
		assert_not_null(feedback_text, "Feedback dialog should contain its multiline editor"),
		assert_true(feedback_text != null and bool(feedback_text.get_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META, false)), "Feedback editor should use the native text-input path"),
		assert_true(feedback_text != null and feedback_text.virtual_keyboard_enabled and feedback_text.virtual_keyboard_show_on_focus, "Feedback editor should opt into the platform keyboard"),
		assert_false(modal_consumed_press or modal_consumed_release, "Feedback modal guard must leave editor touches to the native text control"),
		assert_true(feedback_text != null and bool(feedback_text.get_meta(NonBattleTouchBridgeScript.VIRTUAL_KEYBOARD_REOPEN_REQUESTED_META, false)), "Tapping an already-focused editor after keyboard dismissal should explicitly request the keyboard again"),
	])

	scene.queue_free()
	await tree.process_frame
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	return result


func test_ios_web_text_proxy_and_windows_native_mouse_keep_separate_owners() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Control.new()
	root.size = Vector2(640, 480)
	tree.root.add_child(root)
	var input := LineEdit.new()
	input.position = Vector2(80, 120)
	input.size = Vector2(320, 64)
	input.text = "https://old.example"
	root.add_child(input)
	NonBattleTouchBridgeScript.configure_native_line_edit(input, LineEdit.KEYBOARD_TYPE_URL)

	NonBattleTouchBridgeScript.set_test_web_input_adapter_mode("v2")
	NonBattleTouchBridgeScript.set_test_web_text_input_enabled(true)
	NonBattleTouchBridgeScript.reset_test_web_text_input_state()
	var center := input.get_global_rect().get_center()
	var web_press := InputEventScreenTouch.new()
	web_press.pressed = true
	web_press.position = center
	var web_release := InputEventScreenTouch.new()
	web_release.pressed = false
	web_release.position = center
	var web_root_owned_press := NonBattleTouchBridgeScript.handle_root_touch(root, web_press)
	var web_root_owned_release := NonBattleTouchBridgeScript.handle_root_touch(root, web_release)
	var web_request_count := WebTextInputBridgeScript.get_test_request_count()
	var web_payload := WebTextInputBridgeScript.get_test_last_payload()
	NonBattleTouchBridgeScript.commit_test_web_text_input_value("https://ios.example", true)
	var ios_committed_text := input.text
	var install_script := WebTextInputBridgeScript.get_test_install_script()

	NonBattleTouchBridgeScript.set_test_web_text_input_enabled(false)
	NonBattleTouchBridgeScript.reset_test_web_input_adapter_mode()
	var windows_press := InputEventMouseButton.new()
	windows_press.button_index = MOUSE_BUTTON_LEFT
	windows_press.pressed = true
	windows_press.position = center
	windows_press.global_position = center
	var windows_root_owned := NonBattleTouchBridgeScript.handle_root_touch(root, windows_press)
	var windows_requested_compat_focus := bool(input.get_meta(NonBattleTouchBridgeScript.FOCUS_REQUESTED_META, false))

	var result := run_checks([
		assert_false(web_root_owned_press or web_root_owned_release, "Web text touches should be routed to the DOM proxy instead of the menu button bridge"),
		assert_eq(web_request_count, 1, "One iOS touch sequence should open exactly one DOM text editor"),
		assert_eq(str(web_payload.get("input_type", "")), "url", "The iOS proxy should preserve the requested URL keyboard type"),
		assert_eq(ios_committed_text, "https://ios.example", "DOM text commits should update the Godot LineEdit"),
		assert_true(install_script.contains("input.inputMode") and install_script.contains("enterKeyHint"), "The Web proxy should expose iOS keyboard hints"),
		assert_true(install_script.contains("fontSize = '16px'"), "The iOS input should avoid Safari's automatic focus zoom"),
		assert_true(install_script.contains("_focusOptionsError"), "The Web proxy should fall back when Safari rejects focus options"),
		assert_true(install_script.contains("window.visualViewport") and install_script.contains("cleanupPosition"), "The iOS proxy should stay aligned while the visual viewport changes around the keyboard"),
		assert_true(install_script.contains("userSelect = 'text'") and install_script.contains("webkitUserSelect = 'text'"), "The iOS editor must override the shell-wide selection ban so long-press paste is available"),
		assert_true(install_script.contains("webkitTouchCallout = 'default'") and install_script.contains("touchAction = 'auto'"), "The iOS editor must allow the native paste callout and text gestures"),
		assert_true(install_script.contains("input.onpaste") and install_script.contains("clipboardData"), "Native paste events must explicitly synchronize their value back to Godot"),
		assert_true(install_script.contains("_blurRefocusOptionsError"), "A canvas focus echo immediately after the touch must not tear down the iOS editor transaction"),
		assert_false(windows_root_owned, "Windows mouse input should remain owned by Godot's native Control pipeline"),
		assert_false(windows_requested_compat_focus, "Windows native input should not receive synthetic compatibility focus"),
	])
	root.queue_free()
	await tree.process_frame
	return result


func test_deck_save_upserts_one_row_after_the_active_callback() -> String:
	_cleanup_decks()
	CardDatabase.save_deck(_make_deck(UPSERT_DECK_ID, "Upsert Before"))
	CardDatabase.save_deck(_make_deck(SURVIVOR_DECK_ID, "Upsert Survivor"))
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = DeckManagerScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var deck_list := scene.get_node_or_null("%DeckList") as VBoxContainer
	var target_before := _deck_row_with_id(deck_list, UPSERT_DECK_ID)
	var survivor_before := _deck_row_with_id(deck_list, SURVIVOR_DECK_ID)
	var deck := CardDatabase.get_deck(UPSERT_DECK_ID)
	deck.deck_name = "Upsert After"
	scene.call("_save_deck_incrementally", deck)
	var target_inside_callback := _deck_row_with_id(deck_list, UPSERT_DECK_ID)
	var survivor_inside_callback := _deck_row_with_id(deck_list, SURVIVOR_DECK_ID)
	await tree.process_frame
	deck_list = scene.get_node_or_null("%DeckList") as VBoxContainer
	var target_after := _deck_row_with_id(deck_list, UPSERT_DECK_ID)
	var survivor_after := _deck_row_with_id(deck_list, SURVIVOR_DECK_ID)
	var result := run_checks([
		assert_true(target_inside_callback == target_before, "Saving a deck must not destroy its row inside the active button callback"),
		assert_true(survivor_inside_callback == survivor_before, "Saving one deck must leave unrelated rows untouched inside the callback"),
		assert_true(target_after != null and target_after != target_before, "The saved deck row should update on the following idle frame"),
		assert_true(survivor_after == survivor_before and is_instance_valid(survivor_after), "Incremental save must preserve unrelated deck row instances"),
		assert_eq(CardDatabase.get_deck(UPSERT_DECK_ID).deck_name, "Upsert After", "Incremental UI refresh must not change the persisted deck result"),
	])
	scene.queue_free()
	await tree.process_frame
	_cleanup_decks()
	return result


func test_replay_delete_spreads_filesystem_work_across_frames() -> String:
	_cleanup_test_replay_dir()
	var global_dir := ProjectSettings.globalize_path(REPLAY_DELETE_TEST_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)
	for index: int in range(140):
		var file := FileAccess.open("%s/probe_%03d.txt" % [REPLAY_DELETE_TEST_DIR, index], FileAccess.WRITE)
		if file != null:
			file.store_string("probe")
			file.close()
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = ReplayBrowserScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var row_widget := PanelContainer.new()
	var delete_button := Button.new()
	delete_button.name = "DeleteButton"
	row_widget.add_child(delete_button)
	var replay_button := Button.new()
	replay_button.name = "ReplayButton"
	row_widget.add_child(replay_button)
	(scene.get_node_or_null("%ListContainer") as Control).add_child(row_widget)
	scene.call("_on_delete_pressed", {"match_dir": REPLAY_DELETE_TEST_DIR}, row_widget)
	var directory_exists_inside_callback := DirAccess.dir_exists_absolute(global_dir)
	var queued_job_count := (scene.get("_replay_delete_jobs") as Array).size()
	var back_disabled_while_deleting := (scene.get_node_or_null("%BtnBack") as Button).disabled
	var frames := 0
	while DirAccess.dir_exists_absolute(global_dir) and frames < 20:
		await tree.process_frame
		frames += 1
	var result := run_checks([
		assert_true(directory_exists_inside_callback, "Replay deletion should not recursively remove the directory inside the button callback"),
		assert_eq(queued_job_count, 1, "Replay deletion should create one bounded incremental job"),
		assert_true(back_disabled_while_deleting, "Navigation should stay guarded while the directory transaction is incomplete"),
		assert_false(DirAccess.dir_exists_absolute(global_dir), "The incremental replay deletion should eventually remove the full directory"),
		assert_true(frames >= 2, "A large replay directory should be split across multiple UI frames"),
		assert_false((scene.get_node_or_null("%BtnBack") as Button).disabled, "Navigation should be restored after deletion finishes"),
	])
	scene.queue_free()
	await tree.process_frame
	_cleanup_test_replay_dir()
	return result


func test_web_deck_search_yields_text_touch_and_windows_keeps_immediate_refresh() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = BattleSetupScene.instantiate()
	scene.set("_test_web_runtime_override", true)
	tree.root.add_child(scene)
	await tree.process_frame
	scene.call("_ensure_deck_picker_overlay")
	var overlay := scene.get("_deck_picker_overlay") as Control
	var search_input := scene.get("_deck_picker_search_input") as LineEdit
	if overlay != null:
		overlay.visible = true
	if search_input != null:
		search_input.position = Vector2(80, 100)
		search_input.size = Vector2(420, 80)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = search_input.get_global_rect().get_center() if search_input != null else Vector2.ZERO
	var modal_consumed_web_text_touch := bool(scene.call("_handle_deck_picker_modal_input", press))
	scene.call("_on_deck_picker_search_changed", "a")
	scene.call("_on_deck_picker_search_changed", "ab")
	scene.call("_on_deck_picker_search_changed", "abc")
	var timer := scene.get("_deck_picker_search_debounce_timer") as Timer
	var web_refresh_was_debounced := timer != null and not timer.is_stopped()
	if timer != null and not timer.is_stopped():
		await timer.timeout
	scene.set("_test_web_runtime_override", false)
	scene.call("_on_deck_picker_search_changed", "")
	var windows_refresh_left_no_timer := timer != null and timer.is_stopped()
	var result := run_checks([
		assert_not_null(search_input, "Battle setup should expose its deck search input"),
		assert_true(search_input != null and bool(search_input.get_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META, false)), "Deck search should use the native/DOM text contract"),
		assert_false(modal_consumed_web_text_touch, "The deck picker modal guard must yield iOS browser text touches"),
		assert_true(web_refresh_was_debounced, "Web deck search should coalesce rapid input instead of rebuilding the list for every character"),
		assert_true(windows_refresh_left_no_timer, "Windows deck search should keep its existing immediate refresh behavior"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func _make_deck(deck_id: int, deck_name: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.source_url = "https://tcg.mik.moe/decks/list/%d" % deck_id
	deck.import_date = "2026-07-26 00:00:00"
	deck.variant_name = deck_name
	deck.deck_code = "REGRESSION_%d" % deck_id
	deck.total_cards = 60
	deck.cards = []
	return deck


func _deck_row_with_id(node: Node, deck_id: int) -> Control:
	if node == null:
		return null
	if node is Control and int(node.get_meta("deck_id", -1)) == deck_id:
		return node as Control
	for child: Node in node.get_children():
		var found := _deck_row_with_id(child, deck_id)
		if found != null:
			return found
	return null


func _cleanup_decks() -> void:
	for deck_id: int in [DELETE_DECK_ID, SURVIVOR_DECK_ID, UPSERT_DECK_ID]:
		if CardDatabase.has_deck(deck_id):
			CardDatabase.delete_deck(deck_id)


func _cleanup_test_replay_dir() -> void:
	var global_dir := ProjectSettings.globalize_path(REPLAY_DELETE_TEST_DIR)
	if not DirAccess.dir_exists_absolute(global_dir):
		return
	_remove_test_directory_recursive(global_dir)


func _remove_test_directory_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue
		var child_path := path.path_join(entry)
		if dir.current_is_dir():
			_remove_test_directory_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
