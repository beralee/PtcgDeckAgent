class_name TestDeckEditorSaveValidation
extends TestBase

const GameModal := preload("res://scripts/ui/GameModalDialog.gd")

const EditorScene := preload("res://scenes/deck_editor/DeckEditor.tscn")
const DECK_ID := 919927
const SET_CODE := "UTEST_SAVE"
var _cards: Array[CardData] = []


func _entry(index: int, count: int) -> Dictionary:
	var card := _cards[index]
	return {"set_code": card.set_code, "card_index": card.card_index,
		"name": card.name, "name_en": card.name_en, "card_type": card.card_type, "count": count}


func _open_editor() -> Control:
	_cards.clear()
	var cache: Dictionary = CardDatabase.get("_card_cache")
	for spec: Array in [
		["皮卡丘", "Pokemon"], ["雷能量", "Basic Energy"],
		["皮卡丘", "Pokemon"], ["特殊能量", "Special Energy"],
		["ACE 物品", "Item"], ["ACE 道具", "Tool"], ["ACE 能量", "Special Energy"],
	]:
		var card := CardData.new()
		card.set_code = SET_CODE
		card.card_index = str(_cards.size())
		card.name = spec[0]
		card.card_type = spec[1]
		_cards.append(card)
		cache[card.get_uid()] = card
	_cards[4].mechanic = "ACE SPEC"
	_cards[5].rarity = "ACE"
	_cards[6].is_tags = PackedStringArray(["ACE SPEC"])
	var deck := DeckData.new()
	deck.id = DECK_ID
	deck.deck_name = "保存校验测试"
	deck.cards = [_entry(0, 4), _entry(1, 56)]
	deck.total_cards = 60
	CardDatabase.save_deck(deck)
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.goto_deck_editor(DECK_ID)
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	var editor := EditorScene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(editor)
	await (Engine.get_main_loop() as SceneTree).process_frame
	# Replacement tests must not download synthetic card artwork.
	var image_service: Node = editor.get("_image_cache_service")
	if image_service != null:
		image_service.queue_free()
	editor.set("_image_cache_service", null)
	return editor


func _close_editor(editor: Control) -> void:
	editor.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	CardDatabase.delete_deck(DECK_ID)
	var cache: Dictionary = CardDatabase.get("_card_cache")
	for card: CardData in _cards:
		cache.erase(card.get_uid())
	_cards.clear()


func test_save_rejects_fifth_copy_across_printings_without_changing_original() -> String:
	var editor := await _open_editor()
	var original := CardDatabase.get_deck(DECK_ID).to_dict().duplicate(true)
	var path := CardDatabase.DECKS_DIR + str(DECK_ID) + ".json"
	var file_before := FileAccess.get_file_as_string(path)
	editor.call("_do_replace", 1, _cards[2])
	var checks: Array[String] = [
		assert_eq(CardDatabase.get_deck(DECK_ID).to_dict(), original, "替换前后已保存的内存卡组应保持独立"),
	]
	(editor.get_node("%BtnSave") as Button).pressed.emit()
	var dialog := editor.get_node_or_null("SaveErrorDialog") as GameModal
	checks.append(assert_true(dialog != null and dialog.visible, "超限保存应弹出错误提示"))
	if dialog != null:
		checks.append(assert_str_contains(dialog.dialog_text, "皮卡丘", "错误应指出超限卡名"))
		checks.append(assert_str_contains(dialog.dialog_text, "5", "不同印刷应合计为 5 张"))
	checks.append(assert_true(bool(editor.get("_dirty")), "保存被拒后应保留未保存状态"))
	checks.append(assert_eq(CardDatabase.get_deck(DECK_ID).to_dict(), original, "拒绝保存不应改写内存卡组"))
	checks.append(assert_eq(FileAccess.get_file_as_string(path), file_before, "拒绝保存不应改写文件"))
	if dialog != null:
		dialog.hide()
	editor.call("_do_replace", 2, _cards[1])
	(editor.get_node("%BtnSave") as Button).pressed.emit()
	checks.append(assert_false(bool(editor.get("_dirty")), "修正超限数量后应能正常保存"))
	checks.append(assert_eq(CardDatabase.get_deck(DECK_ID).cards, original["cards"], "修正后应保存合法的四张同名卡"))
	await _close_editor(editor)
	return run_checks(checks)


func test_save_rejects_ace_and_special_energy_limits() -> String:
	var editor := await _open_editor()
	var path := CardDatabase.DECKS_DIR + str(DECK_ID) + ".json"
	var file_before := FileAccess.get_file_as_string(path)
	var checks: Array[String] = []
	var cases := [
		{"cards": [_entry(4, 1), _entry(5, 1), _entry(1, 58)], "error": "ACE SPEC"},
		{"cards": [_entry(4, 2), _entry(1, 58)], "error": "ACE SPEC"},
		{"cards": [_entry(6, 1), _entry(5, 1), _entry(1, 58)], "error": "ACE SPEC"},
		{"cards": [_entry(3, 5), _entry(1, 55)], "error": "特殊能量"},
		{"cards": [_entry(1, 59)], "error": "59"},
	]
	for scenario: Dictionary in cases:
		var draft: DeckData = editor.get("_deck")
		draft.cards.assign(scenario["cards"])
		# A stale cached total must not bypass the size check.
		draft.total_cards = 60
		editor.set("_dirty", true)
		(editor.get_node("%BtnSave") as Button).pressed.emit()
		var dialog := editor.get_node_or_null("SaveErrorDialog") as GameModal
		checks.append(assert_true(dialog != null and dialog.visible, "非法卡组应提示：%s" % scenario["error"]))
		if dialog != null:
			checks.append(assert_str_contains(dialog.dialog_text, scenario["error"], "应指出本次保存失败原因"))
			dialog.hide()
		checks.append(assert_true(bool(editor.get("_dirty")), "非法卡组不能被标为已保存"))
		checks.append(assert_eq(FileAccess.get_file_as_string(path), file_before, "非法卡组不能覆盖已有文件"))
	await _close_editor(editor)
	return run_checks(checks)


func test_save_accepts_four_copies_basic_energy_and_one_ace_then_isolates_further_edits() -> String:
	var editor := await _open_editor()
	var draft: DeckData = editor.get("_deck")
	draft.cards = [_entry(0, 2), _entry(2, 2), _entry(3, 4), _entry(6, 1), _entry(1, 51)]
	editor.set("_dirty", true)
	(editor.get_node("%BtnSave") as Button).pressed.emit()
	var saved := CardDatabase.get_deck(DECK_ID).to_dict().duplicate(true)
	var path := CardDatabase.DECKS_DIR + str(DECK_ID) + ".json"
	var checks: Array[String] = [
		assert_false(bool(editor.get("_dirty")), "合法卡组应保存成功"),
		assert_eq(saved["cards"], draft.cards, "保存应包含全部合法卡牌数量"),
		assert_eq(FileAccess.get_file_as_string(path), JSON.stringify(saved, "\t"), "合法卡组应完整写入文件"),
	]
	editor.call("_do_replace", 4, _cards[0])
	checks.append(assert_eq(CardDatabase.get_deck(DECK_ID).to_dict(), saved, "保存后继续编辑也不能提前修改已保存卡组"))
	await _close_editor(editor)
	return run_checks(checks)


func test_save_missing_card_data_cannot_skip_ace_validation() -> String:
	var editor := await _open_editor()
	var draft: DeckData = editor.get("_deck")
	draft.cards[0]["set_code"] = "UTEST_MISSING_SAVE"
	editor.set("_dirty", true)
	var path := CardDatabase.DECKS_DIR + str(DECK_ID) + ".json"
	var file_before := FileAccess.get_file_as_string(path)
	(editor.get_node("%BtnSave") as Button).pressed.emit()
	var dialog := editor.get_node_or_null("SaveErrorDialog") as GameModal
	var checks: Array[String] = [
		assert_true(dialog != null and dialog.visible, "缺少卡牌数据时不能绕过校验"),
		assert_true(bool(editor.get("_dirty")), "缺少卡牌数据仍应保留草稿"),
		assert_eq(FileAccess.get_file_as_string(path), file_before, "缺少数据不能覆盖存档"),
	]
	if dialog != null:
		checks.append(assert_str_contains(dialog.dialog_text, "卡牌数据", "应解释缺失卡牌数据"))
	await _close_editor(editor)
	return run_checks(checks)
