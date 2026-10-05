extends "res://tests/TestBase.gd"
const Advice := preload("res://scripts/ui/battle/BattleAdviceController.gd")
const AdviceFormatter := preload("res://scripts/ui/battle/BattleAdviceFormatter.gd")
const ReviewFormatter := preload("res://scripts/ui/battle/BattleReviewFormatter.gd")
const Editor := preload("res://scenes/deck_editor/DeckEditor.tscn")

class AdviceScene extends Control:
	var _review_overlay_mode := "advice"
	var _review_overlay := Panel.new()
	var _review_content := RichTextLabel.new()
	var _review_title := Label.new()
	var _review_regenerate_btn := Button.new()
	var _review_pin_btn := Button.new()
	var _battle_advice_last_result: Dictionary = {}
	var _battle_advice_busy := true
	var _battle_advice_progress_text := ""
	var _battle_advice_pinned := false
	var _battle_advice_panel: PanelContainer
	var _battle_advice_panel_content: RichTextLabel
	var _battle_advice_formatter := AdviceFormatter.new()
	func _init() -> void:
		for node: Node in [_review_overlay, _review_content, _review_title, _review_regenerate_btn, _review_pin_btn]: add_child(node)
	func _bt(key: String, _args: Dictionary = {}) -> String: return key
	func _refresh_ui() -> void: pass

func test_delayed_advice_does_not_reopen_closed_overlay_or_replace_review() -> String:
	var scene := AdviceScene.new()
	var controller := Advice.new()
	scene._review_overlay.hide()
	controller.on_battle_advice_completed(scene, {"status": "completed", "strategic_thesis": "新建议"})
	var stayed_hidden := not scene._review_overlay.visible
	scene._review_overlay.show()
	scene._review_overlay_mode = "battle_review"
	scene._review_content.text = "当前复盘内容"
	controller.on_battle_advice_completed(scene, {"status": "completed", "strategic_thesis": "迟到建议"})
	var checks: Array[String] = [
		assert_true(stayed_hidden, "A late AI answer must not reopen a dismissed dialog"),
		assert_eq(scene._review_overlay_mode, "battle_review", "Late advice must not switch the visible review mode"),
		assert_eq(scene._review_content.text, "当前复盘内容", "Late advice must not overwrite another visible result"),
		assert_eq(scene._battle_advice_last_result.strategic_thesis, "迟到建议", "Closed results should still be retained for explicit reopening"),
	]
	scene.free()
	return run_checks(checks)

func test_review_and_advice_keep_model_brackets_literal() -> String:
	var marker := "[b]保留原文[/b][url=https://example.invalid]卡名[/url]"
	var view := RichTextLabel.new()
	view.bbcode_enabled = true
	view.text = AdviceFormatter.new().format_advice({"status": "completed", "strategic_thesis": marker})
	var advice_literal := view.get_parsed_text().contains(marker)
	view.text = ReviewFormatter.new().format_review({"status": "completed", "selected_turns": [{"side": "winner", "turn_number": 1, "reason": marker}], "turn_reviews": [{"turn_number": 1, "turn_goal": marker}]})
	var review_literal := view.get_parsed_text().contains(marker)
	view.free()
	return run_checks([
		assert_true(advice_literal, "AI advice must escape model-provided BBCode"),
		assert_true(review_literal, "AI review must escape model-provided BBCode"),
	])

class Client:
	var callbacks: Array[Callable] = []
	func set_timeout_seconds(_seconds: float) -> void: pass
	func request_json(_parent: Node, _url: String, _key: String, _payload: Dictionary, callback: Callable) -> int:
		callbacks.append(callback)
		return OK

func test_editor_analysis_cancel_rejects_late_results() -> String:
	var path := GameManager.get_battle_review_api_config_path()
	var previous := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"endpoint": "https://example.invalid", "api_key": "fixture", "model": "deepseek-v4-pro"}))
	file.close()
	var scene := Editor.instantiate()
	var client := Client.new()
	scene.set("_ai_client", client)
	var deck := DeckData.new()
	deck.id = 9988811
	deck.deck_name = "分析取消测试"
	scene.set("_deck", deck)
	var targets: Array[DeckData] = []
	var goals: Array[String] = []
	scene.call("_run_ai_analysis", targets, goals)
	var loading: Control = scene.get("_ai_loading_dialog")
	loading.canceled.emit()
	client.callbacks[0].call({"summary": "不应出现的已取消结果", "replacements": []})
	var result := assert_true(scene.get("_ai_summary") != "不应出现的已取消结果", "Cancel analysis must invalidate the callback, not just hide the progress dialog")
	scene.free()
	if previous.is_empty():
		DirAccess.remove_absolute(path)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(previous)
	return result
