extends RefCounted
## Exported only through the existing web_ui_e2e test bridge. Uses a synthetic
## deck and endpoint intercepted by Playwright, never the player's credentials.
var dialog: Control
var deck: DeckData

func open(scene: Node, mode: String = "deck") -> Dictionary:
	if not is_instance_valid(dialog):
		dialog = load("res://scenes/deck_editor/DeckDiscussionDialog.tscn").instantiate()
		scene.add_child(dialog)
		deck = DeckData.new()
		deck.id = 9988891
		deck.deck_name = "DeepSeek 跨平台讨论测试卡组"
		deck.total_cards = 60
		dialog.get("_service").clear_history(deck.id)
		var file := FileAccess.open(GameManager.get_battle_review_api_config_path(), FileAccess.WRITE)
		file.store_string(JSON.stringify({"endpoint": "https://deepseek-ui.invalid/v1", "api_key": "e2e-fixture", "model": "deepseek-v4-pro"}))
		file.close()
	if mode == "battle":
		dialog.setup_for_battle_context(deck, {"perspective_label": "玩家一", "state": {"turn_number": 2}, "public_counts": {}}, deck.id)
	elif mode == "match":
		dialog.setup_for_match(deck, deck, "测试对手", deck.id)
	else:
		dialog.setup_for_deck(deck)
	dialog.popup_for_viewport(Rect2(Vector2.ZERO, scene.get_viewport_rect().size), scene.get_viewport_rect().size.y > scene.get_viewport_rect().size.x)
	return snapshot()

func snapshot() -> Dictionary:
	if not is_instance_valid(dialog): return {"visible": false}
	var messages: Array[String] = []
	for row: Node in dialog.get_node("%TranscriptList").get_children():
		var body: RichTextLabel = dialog._find_message_body_in_row(row)
		if body != null: messages.append(body.get_parsed_text())
	return {"visible": dialog.visible, "messages": messages, "busy": dialog.get("_service").is_busy(),
		"send_disabled": dialog.get_node("%SendButton").disabled, "input": dialog.get_node("%QuestionInput").text,
		"status": dialog.get_node("%StatusLabel").text, "suggestion_count": dialog.get_node("%SuggestionButtons").get_child_count()}
