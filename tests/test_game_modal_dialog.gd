extends "res://tests/TestBase.gd"

const Manager := preload("res://scenes/deck_manager/DeckManager.tscn")
const Editor := preload("res://scenes/deck_editor/DeckEditor.tscn")
const Modal := preload("res://scripts/ui/GameModalDialog.gd")

func test_android_back_closes_only_foreground_and_restores_app_behavior() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous := tree.quit_on_go_back
	var first := Modal.new()
	var second := Modal.new()
	tree.root.add_child(first)
	tree.root.add_child(second)
	first.popup_centered()
	second.popup_centered()
	await tree.process_frame
	var quit_blocked := not tree.quit_on_go_back
	second.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	first.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	var one_closed := first.visible and not second.visible
	first.request_cancel()
	await tree.process_frame
	var result := run_checks([
		assert_true(quit_blocked, "Android Back must not quit the app while a modal is open"),
		assert_true(one_closed, "A single Back notification must close only the foreground modal"),
		assert_eq(tree.quit_on_go_back, previous, "The previous app Back behavior must return after all modals close"),
	])
	first.queue_free()
	second.queue_free()
	await tree.process_frame
	return result

func test_authored_discussion_keeps_named_controls_after_entering_tree() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var dialog := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn").instantiate()
	tree.root.add_child(dialog)
	var deck := DeckData.new()
	deck.deck_name = "中文输入与场景引用"
	dialog.setup_for_deck(deck)
	dialog.popup_centered()
	await tree.process_frame
	var result := run_checks([
		assert_not_null(dialog.get_node_or_null("%SendButton"), "Scene-owned controls must survive reparenting into the modal body"),
		assert_not_null(dialog.get_node_or_null("%QuestionInput"), "The original text composer must remain addressable"),
		assert_false(_has_window(dialog), "Discussion must remain entirely inside the game viewport"),
	])
	dialog.request_cancel()
	dialog.queue_free()
	await tree.process_frame
	return result

func test_modal_mouse_touch_cancel_and_reopen_do_not_leak_input() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	tree.root.add_child(viewport)
	var background := Button.new()
	background.size = Vector2(390, 844)
	viewport.add_child(background)
	var counts := {"background": 0, "confirmed": 0, "canceled": 0}
	background.pressed.connect(func(): counts.background += 1)
	var modal := Modal.new()
	modal.show_cancel = true
	modal.title = "确认操作"
	modal.dialog_text = "只有前景窗口可以收到操作。"
	viewport.add_child(modal)
	modal.confirmed.connect(func(): counts.confirmed += 1)
	modal.canceled.connect(func(): counts.canceled += 1)
	background.grab_focus()
	modal.popup_centered()
	await tree.process_frame
	await tree.process_frame
	var point := modal.get_ok_button().get_global_rect().get_center()
	_mouse_click(viewport, point)
	await tree.process_frame
	var focus_restored := background.has_focus()
	modal.popup_centered()
	await tree.process_frame
	var press := InputEventScreenTouch.new()
	press.index = 2
	press.position = modal.get_cancel_button().get_global_rect().get_center()
	press.pressed = true
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventScreenTouch
	release.pressed = false
	viewport.push_input(release, true)
	await tree.process_frame
	_mouse_click(viewport, press.position, -1)
	modal.popup_centered()
	await tree.process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	viewport.push_input(escape, true)
	var result := run_checks([
		assert_eq(counts.confirmed, 1, "Mouse confirmation should fire once"),
		assert_eq(counts.canceled, 2, "Touch cancel and Escape should each dismiss once"),
		assert_eq(counts.background, 0, "Closing touch and emulated mouse must not click through"),
		assert_true(focus_restored, "Closing must restore the previous keyboard focus"),
		assert_false(modal.visible, "Repeated open/close must release the modal"),
	])
	viewport.queue_free()
	await tree.process_frame
	return result

func test_modal_keeps_footer_in_view_after_rotation_and_keyboard() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	tree.root.add_child(viewport)
	var modal := Modal.new()
	modal.dialog_text = "较长的提示内容。".repeat(60)
	viewport.add_child(modal)
	modal.popup_centered()
	await tree.process_frame
	await tree.process_frame
	var portrait_fits := Rect2(Vector2.ZERO, viewport.size).encloses(modal.get_panel().get_rect())
	viewport.size = Vector2i(844, 390)
	await tree.process_frame
	await tree.process_frame
	var landscape_fits := Rect2(Vector2.ZERO, viewport.size).encloses(modal.get_panel().get_rect())
	modal.set_process(false)
	modal.set("_keyboard_height", 160)
	modal.call("_layout")
	await tree.process_frame
	await tree.process_frame
	var footer_bottom := modal.get_ok_button().get_global_rect().end.y
	var result := run_checks([
		assert_true(portrait_fits and landscape_fits, "The actual panel must fit both orientations"),
		assert_true(footer_bottom <= 230, "The confirm action must stay above the keyboard"),
		assert_true(modal.get_scroll().get_v_scroll_bar().max_value > modal.get_scroll().get_v_scroll_bar().page, "Long content should scroll without displacing the footer"),
	])
	viewport.queue_free()
	await tree.process_frame
	return result

func _mouse_click(viewport: Viewport, point: Vector2, device: int = 0) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.device = device
	press.pressed = true
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	viewport.push_input(release, true)

func test_desktop_rename_stays_in_game_canvas() -> String:
	var scene := Manager.instantiate()
	var deck := DeckData.new()
	deck.id = 9912345
	deck.deck_name = "重命名输入检查"
	scene.call("_on_rename_deck", deck)
	var input := scene.find_child("DeckRenameInput", true, false)
	var result := run_checks([
		assert_null(scene.get("_rename_dialog"), "Desktop rename must not open an OS/embedded Window"),
		assert_not_null(scene.find_child("DeckActionHudDialog", true, false), "Desktop rename needs an in-canvas modal"),
		assert_not_null(input, "Rename must retain its editable name field"),
	])
	scene.free()
	return result

func test_desktop_delete_uses_same_canvas_as_rename() -> String:
	var scene := Manager.instantiate()
	var deck := DeckData.new()
	deck.id = 9912345
	deck.deck_name = "删除确认检查"
	scene.call("_on_delete_deck", deck)
	var result := run_checks([
		assert_not_null(scene.find_child("DeleteDeckConfirmButton", true, false), "Desktop deletion must use the shared in-game confirmation"),
		assert_false(_has_window(scene), "Deck actions must not create native Window nodes"),
	])
	scene.free()
	return result

func test_editor_save_and_leave_prompts_are_controls() -> String:
	var scene := Editor.instantiate()
	var result := run_checks([
		assert_true(scene.get_node("UnsavedDialog") is Control, "Unsaved confirmation must share the game input surface"),
		assert_true(scene.get_node("SaveErrorDialog") is Control, "Validation errors must share the game input surface"),
	])
	scene.free()
	return result

func _has_window(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Window or _has_window(child):
			return true
	return false
