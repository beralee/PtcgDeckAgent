extends "res://tests/TestBase.gd"

const Dialog := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn")
const Service := preload("res://scripts/engine/DeckDiscussionService.gd")
const CONFIG := {"endpoint": "https://example.invalid", "api_key": "ui-fixture", "model": "deepseek-v4-pro"}

class Client:
	var callbacks: Array[Callable] = []
	var synchronous := false
	func set_timeout_seconds(_seconds: float) -> void: pass
	func request_json(_parent: Node, _endpoint: String, _key: String, _payload: Dictionary, callback: Callable) -> int:
		callbacks.append(callback)
		if synchronous:
			callback.call({"answer_markdown": "同步回答"})
		return OK

func _mount(size: Vector2i = Vector2i(390, 844)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = size
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var dialog := Dialog.instantiate()
	var client := Client.new()
	dialog.get("_service").configure_dependencies(client, null, null, null)
	viewport.add_child(dialog)
	var deck := DeckData.new()
	deck.id = 9988701
	deck.deck_name = "超长名称测试卡组 / " + "DeepSeek讨论".repeat(8)
	deck.total_cards = 60
	dialog.get("_service").clear_history(deck.id)
	dialog.setup_for_deck(deck)
	dialog.popup_for_viewport(Rect2(Vector2.ZERO, size), size.y > size.x)
	await _settle()
	var config_path := GameManager.get_battle_review_api_config_path()
	var previous := FileAccess.get_file_as_string(config_path) if FileAccess.file_exists(config_path) else ""
	return {"viewport": viewport, "dialog": dialog, "client": client, "deck": deck, "config_before": previous}

func _settle() -> void:
	for frame in range(5):
		await (Engine.get_main_loop() as SceneTree).process_frame

func _dispose(h: Dictionary) -> void:
	h.dialog.get("_service").clear_history(h.deck.id)
	var path := GameManager.get_battle_review_api_config_path()
	if h.config_before.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(h.config_before)
	h.viewport.queue_free()
	await _settle()

func _bounds(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)

func _click(viewport: Viewport, point: Vector2, touch := false) -> void:
	for pressed: bool in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.pressed = pressed
			viewport.push_input(event, true)
		else:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			viewport.push_input(event, true)

func test_actual_controls_fit_resized_phone_tablet_and_desktop() -> String:
	var h := await _mount()
	var checks: Array[String] = []
	for size: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1080, 2400), Vector2i(820, 1180), Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(640, 480)]:
		h.viewport.size = size
		await _settle()
		var dialog: Control = h.dialog
		var area := Rect2(Vector2.ZERO, size).grow(1)
		var transcript := _bounds(dialog.get_node("%TranscriptScroll"))
		var input := _bounds(dialog.get_node("%InputPanel"))
		for id: String in ["CloseButton", "QuestionInput", "ResetButton", "SendButton", "TranscriptScroll"]:
			var rect := _bounds(dialog.get_node("%" + id))
			checks.append(assert_true(area.encloses(rect), "%s: %s must fit actual viewport: %s" % [size, id, rect]))
		checks.append(assert_true(transcript.size.y >= 64 and transcript.end.y <= input.position.y + 1, "%s: messages and composer must not overlap" % size))
		var row := dialog.get_node("%TranscriptList").get_child(0) as Control
		checks.append(assert_true(_bounds(row).end.x <= transcript.end.x + 1, "%s: complete message must fit without horizontal clipping" % size))
	var result := run_checks(checks)
	await _dispose(h)
	return result

func _configure_api() -> void:
	var file := FileAccess.open(GameManager.get_battle_review_api_config_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(CONFIG))

func test_enter_cannot_start_second_request_during_answer_display() -> String:
	var h := await _mount(Vector2i(1280, 800))
	_configure_api()
	var input := h.dialog.get_node("%QuestionInput") as TextEdit
	input.text = "第一条"
	_click(h.viewport, _bounds(h.dialog.get_node("%SendButton")).get_center())
	h.client.callbacks[0].call({"answer_markdown": "较长回答".repeat(200)})
	input.text = "第二条草稿"
	input.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	h.viewport.push_input(enter, true)
	var result := run_checks([
		assert_eq(h.client.callbacks.size(), 1, "Enter must not bypass the disabled Send button during rendering"),
		assert_eq(input.text, "第二条草稿", "Busy send must retain the next draft"),
	])
	await _dispose(h)
	return result

func test_synchronous_reply_and_failure_recovery_have_no_ghost_pending_rows() -> String:
	var h := await _mount(Vector2i(1280, 800))
	_configure_api()
	h.client.synchronous = true
	h.dialog.get_node("%QuestionInput").text = "同步问题"
	_click(h.viewport, _bounds(h.dialog.get_node("%SendButton")).get_center())
	await _settle()
	var no_pending: bool = h.dialog._find_last_pending_body() == null
	h.client.synchronous = false
	h.dialog.get_node("%QuestionInput").text = "失败后还要重试的问题"
	_click(h.viewport, _bounds(h.dialog.get_node("%SendButton")).get_center())
	h.client.callbacks.back().call({"status": "error", "message": "timeout"})
	await _settle()
	var result := run_checks([
		assert_true(no_pending, "A synchronous callback must not be replaced by a pending bubble"),
		assert_false(h.dialog.get_node("%SendButton").disabled, "Failure must unlock Send"),
		assert_eq(h.dialog.get_node("%QuestionInput").text, "失败后还要重试的问题", "Failure must restore the unsent draft"),
		assert_null(h.dialog._find_last_pending_body(), "Failure must remove its pending bubble"),
	])
	await _dispose(h)
	return result

func test_history_suggestions_reset_and_scrollback_survive_new_output() -> String:
	var h := await _mount()
	var service = h.dialog.get("_service")
	service.ask(h.dialog, h.deck, "已保存的问题", CONFIG)
	h.client.callbacks.back().call({"answer_markdown": "已保存回答", "suggested_questions": ["历史追问", "第二个追问"]})
	h.dialog.setup_for_deck(h.deck)
	await _settle()
	var restored: bool = h.dialog.get_node("%SuggestionButtons").get_child_count() == 2
	for index in range(14):
		h.dialog._add_message_bubble("assistant", "可以向上阅读的长历史。".repeat(35), {})
	await _settle()
	var scroll := h.dialog.get_node("%TranscriptScroll") as ScrollContainer
	scroll.scroll_vertical = 180
	h.dialog._start_streaming_assistant_message("继续输出的新回复。".repeat(400), {})
	await _settle()
	var preserved := scroll.scroll_vertical
	var reset := h.dialog.get_node("%ResetButton") as Button
	var reset_rect := _bounds(reset)
	var hit := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd").button_at_position(h.dialog, reset_rect.get_center())
	_click(h.viewport, _bounds(h.dialog.get_node("%ResetButton")).get_center(), true)
	await _settle()
	var result := run_checks([
		assert_true(restored, "Reopening must retain saved follow-up questions"),
		assert_true(hit == reset, "Clear must be hittable after a long response: %s outer=%s" % [reset_rect, _bounds(h.dialog.get_scroll())]),
		assert_eq(preserved, 180, "New output must not pull a reader away from older messages"),
		assert_eq(h.dialog.get_node("%SuggestionButtons").get_child_count(), 0, "Clear must also remove stale follow-up questions"),
		assert_eq(h.dialog.get_node("%TranscriptList").get_child_count(), 1, "Clear must remove old and streaming bubbles immediately"),
	])
	await _dispose(h)
	return result

func test_phone_errors_visible_and_touch_clear_really_recovers() -> String:
	var h := await _mount()
	h.dialog.get_node("%QuestionInput").text = "为什么无法连接？"
	_click(h.viewport, _bounds(h.dialog.get_node("%SendButton")).get_center(), true)
	await _settle()
	var status := h.dialog.get_node("%StatusLabel") as Label
	var visible_error := status.is_visible_in_tree() and not status.text.is_empty()
	h.dialog.get("_service").set("_busy", true)
	_click(h.viewport, _bounds(h.dialog.get_node("%ResetButton")).get_center(), true)
	await _settle()
	var result := run_checks([
		assert_true(visible_error, "Missing configuration must display an error on a phone"),
		assert_false(h.dialog.get("_service").is_busy(), "A real touch on Clear must recover a busy request"),
		assert_eq(h.dialog.get_node("%QuestionInput").text, "", "Clear must receive the actual touch"),
	])
	await _dispose(h)
	return result

func test_switching_context_invalidates_pending_response() -> String:
	var h := await _mount(Vector2i(1280, 800))
	var service = h.dialog.get("_service")
	service.ask(h.dialog, h.deck, "旧卡组问题", CONFIG)
	var other := DeckData.new()
	other.id = h.deck.id + 1
	other.deck_name = "新卡组"
	h.dialog.setup_for_deck(other)
	h.client.callbacks[0].call({"answer_markdown": "旧卡组回答不应出现在新会话"})
	await _settle()
	var history: Array = service.load_history(h.deck.id)
	var result := run_checks([
		assert_false(service.is_busy(), "Switching context must release pending request"),
		assert_true(history.is_empty(), "Canceled callback must not persist into another session"),
		assert_eq(h.dialog.get("_stream_full_text"), "", "Stale response must not animate in the new context"),
	])
	await _dispose(h)
	return result

func test_close_and_reopen_does_not_leave_a_busy_request() -> String:
	var h := await _mount()
	var service = h.dialog.get("_service")
	_configure_api()
	h.dialog.get_node("%QuestionInput").text = "关闭前的问题"
	_click(h.viewport, _bounds(h.dialog.get_node("%SendButton")).get_center(), true)
	_click(h.viewport, _bounds(h.dialog.get_node("%CloseButton")).get_center(), true)
	await _settle()
	var was_hidden: bool = not h.dialog.visible
	h.dialog.setup_for_deck(h.deck)
	h.dialog.popup_for_viewport(Rect2(Vector2.ZERO, h.viewport.size), true)
	await _settle()
	var result := run_checks([
		assert_true(was_hidden, "Close touch must hide the dialog"),
		assert_false(service.is_busy(), "Closing a discussion must invalidate its pending request"),
		assert_eq(h.dialog.get_node("%QuestionInput").text, "关闭前的问题", "Canceled question must remain available when the same discussion reopens"),
	])
	await _dispose(h)
	return result

func test_literal_brackets_and_long_response_are_readable() -> String:
	var h := await _mount()
	var literal := "[b]卡名[/b] [url=https://example.invalid]方括号[/url] C(60,7)"
	var body: RichTextLabel = h.dialog._add_message_bubble("assistant", literal, {})
	await _settle()
	var result := assert_eq(body.get_parsed_text(), literal, "Model/user bracket text must remain literal, without BBCode injection or stray slashes")
	await _dispose(h)
	return result

func test_keyboard_keeps_real_actions_above_occlusion_and_restores_layout() -> String:
	var h := await _mount()
	h.dialog.set_process(false)
	h.dialog.apply_portrait_keyboard_inset(320.0)
	await _settle()
	var checks: Array[String] = []
	for id: String in ["CloseButton", "QuestionInput", "ResetButton", "SendButton"]:
		checks.append(assert_true(_bounds(h.dialog.get_node("%" + id)).end.y <= 524.0, id + " must actually remain above keyboard"))
	h.dialog.apply_portrait_keyboard_inset(0.0)
	await _settle()
	checks.append(assert_true(_bounds(h.dialog.get_node("%TranscriptScroll")).size.y >= 180, "Keyboard dismissal must restore useful transcript space"))
	var result := run_checks(checks)
	await _dispose(h)
	return result
