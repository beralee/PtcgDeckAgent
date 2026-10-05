extends "res://scripts/training/DeckTrainingBattleController.gd"

const ExpertCatalog := preload("res://scripts/training/expert/ExpertPlayCatalog.gd")
const Store := preload("res://scripts/training/expert/ExpertPlayStore.gd")
const Recorder := preload("res://scripts/training/expert/ExpertPlayRecorder.gd")
const FormOverlay := preload("res://scripts/training/expert/ExpertPlayFormOverlay.gd")
const ExpertTouchBridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const FeedbackGuide := preload("res://scripts/training/expert/ExpertFeedbackGuide.gd")
const REASON_TEXT := ["拿奖 / 终结", "展开场面", "保留资源", "培养下一攻击手", "先获取信息", "干扰 / 拖回合", "其他思路"]
var _recorder: RefCounted = Recorder.new()
var _started := false
var _ended := false
var _submitted := false
var _autosave_ok := false
var _previous_player := 0
var _completed_turns := 0
var _save_error: Label
var _confidence: OptionButton
var _reason: OptionButton
var _note: TextEdit
var _feedback_footer: VBoxContainer
var _draft_timer: Timer
var _saving := false
var _recovering := false


func setup_feedback_recovery(scene: Control, document: Dictionary) -> bool:
	if not _recorder.restore_feedback(document):
		return false
	_scene = scene
	_scenario = ExpertCatalog.get_scenario(str(document.scenario_id))
	if _scenario.is_empty():
		return false
	_ended = true
	_recovering = true
	_build_result_overlay("")
	return true


func setup(scene: Control, gsm: GameStateMachine, scenario: Dictionary, _snapshot: Dictionary) -> void:
	_scene = scene
	_gsm = gsm
	_scenario = scenario.duplicate(true)
	var previous: Dictionary = Store.progress().get(str(scenario.id), {})
	_recorder.begin(_scenario, _state(), Store.new_attempt_id(), int(previous.get("attempts", 0)) > 0)
	_previous_player = int(_state().current_player_index)
	_configure_restart_button()
	_configure_stage_help_button()
	_build_intro_overlay()


func is_terminal() -> bool:
	return _ended


func on_action_logged(action: GameAction) -> Dictionary:
	if _started and not _ended:
		_recorder.observe_action(action, _state())
		_autosave_ok = Store.save(_recorder.document())
	return _status()


func on_state_changed() -> Dictionary:
	if _started and not _ended and _state() != null:
		var current := int(_state().current_player_index)
		if _previous_player == 0 and current == 1:
			_completed_turns += 1
		_previous_player = current
		if _completed_turns >= int(_scenario.turn_limit):
			_finish_segment()
	return _status()


func on_game_over(_winner_index: int, _reason_text: String) -> Dictionary:
	if _started and not _ended:
		_finish_segment()
	return _status()


func _status() -> Dictionary:
	# completed here means the teaching segment ended, not strategic correctness.
	return {"completed": _ended, "failed": false, "terminal": _ended, "training_mode": ExpertCatalog.MODE}


func apply_layout(viewport_size: Vector2) -> void:
	var mode := _resolved_layout_mode(viewport_size)
	var size := _logical_layout_size(viewport_size, mode)
	var context: Dictionary = _layout_controller.build_context(size, mode, _is_mobile_runtime())
	var portrait := bool(context.is_portrait)
	var body := int(context.body_font_size) if portrait else 18
	var button_font := int(context.button_font_size) if portrait else 20
	for panel: PanelContainer in [_intro_panel, _result_panel, _help_panel]:
		if panel == null or not is_instance_valid(panel):
			continue
		var height_fraction := 0.44 if portrait and panel == _intro_panel else (0.62 if portrait and panel == _help_panel else 0.86)
		var available_height := size.y
		if panel == _result_panel:
			available_height -= float(_result_overlay.keyboard_logical_height())
		panel.custom_minimum_size = Vector2(float(context.content_width) if portrait else clampf(size.x - 32, 280, 760), maxf(100, available_height * height_fraction))
		var box := panel.find_child("TrainingPanelContent", true, false) as VBoxContainer
		if box != null:
			box.add_theme_constant_override("separation", 12)
		for button: Button in panel.find_children("*", "Button", true, false):
			button.custom_minimum_size.y = float(context.secondary_button_height) if portrait else 50
			button.add_theme_font_size_override("font_size", button_font)
			if button is OptionButton:
				button.get_popup().add_theme_font_size_override("font_size", button_font)
		for label: Label in panel.find_children("*", "Label", true, false):
			label.add_theme_font_size_override("font_size", int(context.title_font_size) if portrait and str(label.name) in ["StageIntroTitle", "StageHelpTitle"] else body)
		for edit: TextEdit in panel.find_children("*", "TextEdit", true, false):
			edit.custom_minimum_size.y = body * 5
			edit.add_theme_font_size_override("font_size", body)
	if not _recovering:
		_configure_restart_button()


func _finish_segment() -> void:
	if _ended:
		return
	_ended = true
	_recorder.pause_for_feedback(_state())
	_close_help_overlay(false)
	_build_result_overlay("")


func _build_intro_overlay() -> void:
	_intro_overlay = _make_overlay("DeckTrainingIntroOverlay", 2450)
	_intro_panel = _center_panel(_intro_overlay, "DeckTrainingIntroPanel")
	var box := _panel_box(_intro_panel)
	_label(box, "StageIntroTitle", str(_scenario.title), 30)
	_label(box, "StageGoalLabel", "这段牌，由你来教 AI", 24)
	_label(box, "StageIntroLimit", "%s · %d 个我方回合\n直接打牌，结束后点一下把握程度。没有预设标准答案。" % [str(_scenario.topic), int(_scenario.turn_limit)], 18)
	_label(box, "ExpertPublicHistory", _public_history_text(), 18)
	var session := Store.queue_state()
	if (session.remaining as Array).size() > 0:
		_label(box, "ExpertSessionProgress", "本组 %d / %d" % [int(session.total) - session.remaining.size() + 1, int(session.total)], 18)
	_save_error = _label(box, "ExpertSaveStatus", "", 17)
	var start := _make_button("看牌，开始这一题", _on_intro_confirmed)
	start.name = "StageIntroConfirmButton"
	box.add_child(start)
	box.add_child(_make_button("先回题库", _on_exit_pressed))
	apply_layout(_scene.get_viewport_rect().size)


func _on_intro_confirmed() -> void:
	if not Store.save(_recorder.document()):
		_save_error.text = "暂存没有成功，请检查存储空间后再点开始。"
		return
	_started = true
	_autosave_ok = true
	super._on_intro_confirmed()


func _build_result_overlay(_grade: String) -> void:
	_result_overlay = _make_overlay("DeckTrainingResultOverlay", 2500)
	_result_panel = _center_panel(_result_overlay, "DeckTrainingResultPanel")
	var box := _panel_box(_result_panel)
	_label(box, "StageIntroTitle", "这一手，值得教给 AI 吗？", 28)
	var initial: Dictionary = _recorder.document().initial_public_state
	var gained := int(initial.own.prizes_remaining) - int(_recorder.document().final_public_state.own.prizes_remaining)
	_autosave_ok = Store.save(_recorder.document())
	_label(box, "ExpertOutcome", "这段拿到 %d 张奖赏 · %s" % [gained, "出牌过程已暂存" if _autosave_ok else "尚未写入磁盘，请保留本页重试保存"], 18)
	_confidence = OptionButton.new()
	_confidence.name = "ExpertConfidence"
	_confidence.custom_minimum_size.y = 48
	_confidence.add_item("请选择把握程度")
	for text: String in ["有把握，可以作为示范", "可以讨论，我不确定最优", "我打错了，留作反例", "题目 / 规则有问题"]:
		_confidence.add_item(text)
	box.add_child(_confidence)
	_reason = OptionButton.new()
	_reason.name = "ExpertReason"
	_reason.custom_minimum_size.y = 46
	_reason.add_item("主要在考虑什么？（可不选）")
	for text: String in REASON_TEXT:
		_reason.add_item(text)
	box.add_child(_reason)
	_label(box, "ExpertFeedbackHint", FeedbackGuide.HINT, 16)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	box.add_child(tools)
	var template := _make_button("填入四行模板", _insert_feedback_template)
	template.name = "ExpertFeedbackTemplate"
	tools.add_child(template)
	var example := _label(box, "ExpertFeedbackExample", FeedbackGuide.EXAMPLE, 16)
	example.hide()
	tools.add_child(_make_button("查看写法示例", func() -> void: example.visible = not example.visible))
	_note = TextEdit.new()
	_note.name = "ExpertNote"
	_note.placeholder_text = FeedbackGuide.TEMPLATE + "\n（可选，最多 1000 字）"
	_note.custom_minimum_size = Vector2(0, 95)
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	ExpertTouchBridge.configure_native_text_edit(_note)
	box.add_child(_note)
	var feedback: Dictionary = _recorder.document().feedback
	_confidence.select(Recorder.CONFIDENCE.find(str(feedback.get("confidence", ""))) + 1)
	_reason.select(Recorder.REASONS.find(str(feedback.get("reason", ""))) + 1)
	_note.text = str(feedback.get("note", ""))
	_draft_timer = Timer.new()
	_draft_timer.one_shot = true
	_draft_timer.wait_time = 0.4
	_result_overlay.add_child(_draft_timer)
	_draft_timer.timeout.connect(_save_feedback_draft)
	_note.text_changed.connect(func() -> void: _draft_timer.start())
	_note.focus_exited.connect(_save_feedback_draft)
	_confidence.item_selected.connect(func(_index: int) -> void: _save_feedback_draft())
	_reason.item_selected.connect(func(_index: int) -> void: _save_feedback_draft())
	_result_overlay.persist_requested.connect(_save_feedback_draft)
	_save_error = _label(_feedback_footer, "ExpertSaveStatus", "评价会自动暂存；保存后才计入已提交示范。", 16)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_feedback_footer.add_child(actions)
	var next := _make_button("保存并下一题", _submit_and_next)
	next.name = "ExpertSubmitNext"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(next)
	var exit_button := _make_button("保存并回题库", _submit_and_exit)
	exit_button.name = "ExpertSubmitExit"
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(exit_button)
	box.add_child(_make_button("暂存评价，稍后再写", func() -> void:
		if _save_feedback_draft():
			_on_exit_pressed()
	))
	if not _recovering:
		box.add_child(_make_button("先重试一次（保留草稿）", func() -> void:
			if _save_feedback_draft(): restart()
		))
	apply_layout(_scene.get_viewport_rect().size)
	_save_feedback_draft()


func _insert_feedback_template() -> void:
	var previous := _note.text
	_note.text = FeedbackGuide.insert_template(previous)
	_save_feedback_draft()
	if not previous.strip_edges().is_empty():
		_save_error.text = "已保留原文，可对照提示补充，不会覆盖你的评价。"


func _save_feedback_draft() -> bool:
	if _submitted or _note == null or not is_instance_valid(_note):
		return true
	if _draft_timer != null: _draft_timer.stop()
	var confidence := "" if _confidence.selected <= 0 else str(Recorder.CONFIDENCE[_confidence.selected - 1])
	var reason := "" if _reason.selected <= 0 else str(Recorder.REASONS[_reason.selected - 1])
	_recorder.draft_feedback(confidence, reason, _note.text)
	var saved := Store.save(_recorder.document())
	if _save_error != null and is_instance_valid(_save_error) and not _saving:
		_save_error.text = ("评价已暂存 · %d / 1000 字；点保存后提交。" % _note.text.length()) if saved else "暂存失败，请保留本页并检查存储空间。"
	return saved


func _prepare_submission() -> bool:
	if _saving or _submitted:
		return false
	_saving = true
	_save_error.text = "正在保存…"
	_note.apply_ime()
	_note.release_focus()
	DisplayServer.virtual_keyboard_hide()
	# Native IME commits are delivered across the Android/Godot frame boundary.
	await _scene.get_tree().process_frame
	await _scene.get_tree().process_frame
	var ok := _submit()
	_saving = false
	return ok


func _submit() -> bool:
	if _submitted:
		return true
	if _confidence.selected <= 0:
		_save_error.text = "点一下把握程度就能保存，理由可以不填。"
		return false
	var reason := "" if _reason.selected <= 0 else str(Recorder.REASONS[_reason.selected - 1])
	var draft: Dictionary = _recorder.document()
	var result: Dictionary = _recorder.finish(Recorder.CONFIDENCE[_confidence.selected - 1], reason, _note.text, _state())
	if not bool(result.ok):
		_save_error.text = "备注请控制在 1000 字以内。"
		return false
	if not Store.save(_recorder.document()):
		_recorder.restore_feedback(draft)
		_save_error.text = "保存没有成功，内容还在这里；请检查存储空间后重试。"
		return false
	if not Store.advance(str(_scenario.id)):
		_save_error.text = "示范已保存，进度暂存失败；请再次点保存。"
		return false
	_submitted = true
	if _draft_timer != null: _draft_timer.stop()
	return true


func _submit_and_next() -> void:
	if not await _prepare_submission():
		return
	var remaining: Array = Store.queue_state().remaining
	if remaining.is_empty():
		_on_exit_pressed()
	else:
		GameManager.start_deck_training(str(remaining[0]))


func _submit_and_exit() -> void:
	if await _prepare_submission():
		_on_exit_pressed()


func show_stage_goal() -> void:
	show_stage_guide()


func stage_goal_text() -> String:
	return str(_scenario.prompt)


func stage_guide_text() -> String:
	return "自由打一段牌，把你的真实判断留给 AI。可以先想目标，再打牌；不要求固定路线或操作数。"


func show_stage_guide() -> void:
	_close_help_overlay(false)
	_help_overlay = _make_overlay("DeckTrainingStageHelpOverlay", 2600)
	_help_panel = _center_panel(_help_overlay, "DeckTrainingStageHelpPanel")
	var box := _panel_box(_help_panel)
	_label(box, "StageHelpTitle", str(_scenario.title), 26)
	_label(box, "StageHelpGoalLabel", stage_goal_text(), 18)
	_label(box, "ExpertPublicHistory", _public_history_text(), 18)
	if (_recorder.document().events as Array).is_empty():
		_label(box, "ExpertIntentPrompt", "这一手先追求什么？（可跳过）", 18)
		var intent := OptionButton.new()
		intent.add_item("我先自己判断")
		for text: String in REASON_TEXT:
			intent.add_item(text)
		intent.item_selected.connect(func(index: int) -> void:
			if index > 0:
				_recorder.set_intent(str(Recorder.REASONS[index - 1]))
				Store.save(_recorder.document())
		)
		box.add_child(intent)
	box.add_child(_make_button("继续打牌", _close_help_overlay))
	box.add_child(_make_button("结束这段，写下判断", _finish_manually))
	box.add_child(_make_button("暂存草稿，返回题库", _on_exit_pressed))
	_save_error = _label(box, "ExpertSaveStatus", "", 17)
	apply_layout(_scene.get_viewport_rect().size)


func _finish_manually() -> void:
	if _ended:
		_close_help_overlay(false)
		return
	if not _started or _state().phase != GameState.GamePhase.MAIN or _state().current_player_index != 0 or str(_scene.get("_pending_choice")) != "" or not _gsm.get_pending_decision_snapshot().is_empty():
		_save_error.text = "先完成当前卡牌选择，再结束这段。"
		return
	_finish_segment()


func _configure_stage_help_button() -> void:
	super._configure_stage_help_button()
	var button := _stage_help_button()
	if button != null:
		button.text = "本题 / 交卷"
		button.set_meta("portrait_compact_text_override", "交卷")
		button.tooltip_text = "查看本题、记录目标或提前结束这一段"


func _on_exit_pressed() -> void:
	DisplayServer.virtual_keyboard_hide()
	GameManager.clear_deck_training_launch()
	GameManager.goto_scene(ExpertCatalog.BROWSER)


func _center_panel(overlay: Control, node_name: String) -> PanelContainer:
	var center := CenterContainer.new()
	center.name = "ExpertFormCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := _make_panel()
	panel.name = node_name
	center.add_child(panel)
	return panel


func _make_overlay(node_name: String, layer: int) -> ColorRect:
	var overlay := super._make_overlay(node_name, layer)
	# Modal children receive input before the board's HUD router.
	overlay.set_script(FormOverlay)
	overlay.add_to_group("expert_play_forms")
	overlay.set_process_input(true)
	overlay.set_process(true)
	overlay.keyboard_layout_changed.connect(func() -> void: apply_layout(_scene.get_viewport_rect().size))
	return overlay


func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "TrainingPanelMargin"
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var scroll_parent: Node = margin
	var column: VBoxContainer
	if panel == _result_panel:
		column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		margin.add_child(column)
		scroll_parent = column
	var scroll := ScrollContainer.new()
	scroll.name = "ExpertFormScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "TrainingPanelContent"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	if column != null:
		_feedback_footer = VBoxContainer.new()
		_feedback_footer.name = "ExpertFeedbackFooter"
		_feedback_footer.add_theme_constant_override("separation", 12)
		column.add_child(_feedback_footer)
	return box


func _label(parent: Node, node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _public_history_text() -> String:
	var state := _state()
	var had_knockout := state.last_knockout_during_opponent_turn_against[0] == state.turn_number - 1
	return "上个对手回合：我方%s宝可梦被击倒。" % ("有" if had_knockout else "没有")
