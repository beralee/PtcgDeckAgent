class_name DeckTrainingBattleController
extends RefCounted


const SessionScript := preload("res://scripts/training/DeckTrainingSession.gd")
const ProgressStoreScript := preload("res://scripts/training/DeckTrainingProgressStore.gd")
const PresentationScript := preload("res://scripts/training/DeckTrainingPresentation.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")

var _scene: Control = null
var _gsm: GameStateMachine = null
var _scenario: Dictionary = {}
var _session: DeckTrainingSession = null
var _intro_overlay: Control = null
var _intro_panel: PanelContainer = null
var _result_overlay: Control = null
var _result_panel: PanelContainer = null
var _help_overlay: Control = null
var _help_panel: PanelContainer = null
var _help_guide_text: RichTextLabel = null
var _help_showing_guide := false
var _result_recorded := false
var _layout_controller: RefCounted = NonBattleLayoutControllerScript.new()


func setup(scene: Control, gsm: GameStateMachine, scenario: Dictionary, snapshot: Dictionary) -> void:
	_scene = scene
	_gsm = gsm
	_scenario = scenario.duplicate(true)
	_session = SessionScript.new()
	_session.setup(_scenario, snapshot)
	_configure_restart_button()
	_configure_stage_help_button()
	_build_intro_overlay()


func release() -> void:
	for overlay: Control in [_intro_overlay, _result_overlay, _help_overlay]:
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	_restore_ai_button()
	_restore_stage_help_button()
	_intro_overlay = null
	_result_overlay = null
	_help_overlay = null
	_help_panel = null
	_help_guide_text = null
	_scene = null
	_gsm = null
	_session = null


func on_action_logged(action: GameAction) -> Dictionary:
	if _session == null:
		return {}
	var status := _session.on_action_logged(action, _state())
	_maybe_show_result(status)
	return status


func on_state_changed() -> Dictionary:
	if _session == null:
		return {}
	_configure_restart_button()
	var status := _session.on_state_changed(_state())
	_maybe_show_result(status)
	return status


func on_game_over(winner_index: int, reason: String) -> Dictionary:
	if _session == null:
		return {}
	var status := _session.on_game_over(winner_index, reason, _state())
	_maybe_show_result(status)
	return status


func is_terminal() -> bool:
	return _session != null and _session.is_terminal()


func is_modal_open() -> bool:
	return (_intro_overlay != null and is_instance_valid(_intro_overlay) and _intro_overlay.visible) \
		or (_result_overlay != null and is_instance_valid(_result_overlay) and _result_overlay.visible) \
		or (_help_overlay != null and is_instance_valid(_help_overlay) and _help_overlay.visible)


func restart() -> void:
	GameManager.start_deck_training(str(_scenario.get("id", "")))


func apply_layout(viewport_size: Vector2) -> void:
	var resolved_mode := _resolved_layout_mode(viewport_size)
	var layout_size := _logical_layout_size(viewport_size, resolved_mode)
	var context: Dictionary = _layout_controller.call(
		"build_context",
		layout_size,
		resolved_mode,
		_is_mobile_runtime()
	)
	var portrait := bool(context.get("is_portrait", false))
	for panel: PanelContainer in [_intro_panel, _result_panel]:
		if panel != null and is_instance_valid(panel):
			panel.custom_minimum_size = Vector2(
				float(context.get("content_width", 320.0)) if portrait else clampf(layout_size.x - 40.0, 320.0, 620.0),
				0.0
			)
			_apply_panel_metrics(panel, context, portrait)
	if _help_panel != null and is_instance_valid(_help_panel):
		var help_width := float(context.get("content_width", 320.0)) \
			if portrait \
			else clampf(layout_size.x - 40.0, 320.0, 720.0)
		var help_height := (
			clampf(layout_size.y * 0.84, 360.0, maxf(360.0, layout_size.y - 32.0))
			if portrait
			else clampf(layout_size.y * 0.82, 360.0, 760.0)
		) if _help_showing_guide else 0.0
		_help_panel.custom_minimum_size = Vector2(help_width, help_height)
		_apply_panel_metrics(_help_panel, context, portrait)
	if _help_guide_text != null and is_instance_valid(_help_guide_text):
		_help_guide_text.custom_minimum_size = Vector2(
			0.0,
			clampf(layout_size.y * 0.62, 260.0, maxf(260.0, layout_size.y - 260.0))
			if portrait
			else clampf(layout_size.y * 0.52, 220.0, 520.0)
		)
	_configure_restart_button()


func _resolved_layout_mode(viewport_size: Vector2) -> String:
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("_current_resolved_battle_layout_mode"):
		return str(_scene.call("_current_resolved_battle_layout_mode", viewport_size))
	return "portrait" if viewport_size.y > viewport_size.x else "landscape"


func _logical_layout_size(viewport_size: Vector2, resolved_mode: String) -> Vector2:
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("_battle_layout_logical_viewport_size"):
		return _scene.call("_battle_layout_logical_viewport_size", viewport_size, resolved_mode) as Vector2
	if resolved_mode == "portrait" and viewport_size.x > viewport_size.y:
		return Vector2(viewport_size.y, viewport_size.x)
	return viewport_size


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") \
		or OS.has_feature("android") \
		or OS.has_feature("ios") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")


func _apply_panel_metrics(panel: PanelContainer, context: Dictionary, portrait: bool) -> void:
	var section_gap := int(context.get("section_gap", 22)) if portrait else 18
	var margin := panel.find_child("TrainingPanelMargin", true, false) as MarginContainer
	if margin != null:
		var horizontal_margin := int(context.get("page_margin", 22)) if portrait else 28
		var vertical_margin := int(context.get("page_margin", 22)) if portrait else 24
		margin.add_theme_constant_override("margin_left", horizontal_margin)
		margin.add_theme_constant_override("margin_right", horizontal_margin)
		margin.add_theme_constant_override("margin_top", vertical_margin)
		margin.add_theme_constant_override("margin_bottom", vertical_margin)
	var box := panel.find_child("TrainingPanelContent", true, false) as VBoxContainer
	if box != null:
		box.add_theme_constant_override("separation", section_gap)
	for row_node: Node in panel.find_children("TrainingActionRow", "HFlowContainer", true, false):
		var row := row_node as HFlowContainer
		row.add_theme_constant_override("h_separation", section_gap if portrait else 12)
		row.add_theme_constant_override("v_separation", maxi(10, section_gap / 2) if portrait else 10)
	var title_font := int(context.get("title_font_size", 44)) if portrait else 30
	var section_font := int(context.get("section_font_size", 33)) if portrait else 26
	var body_font := int(context.get("body_font_size", 27)) if portrait else 18
	var button_font := int(context.get("button_font_size", 33)) if portrait else 20
	_set_label_font(panel, "StageIntroTitle", title_font)
	_set_label_font(panel, "StageGoalLabel", section_font)
	_set_label_font(panel, "StageIntroLimit", body_font)
	_set_label_font(panel, "StageHelpTitle", title_font)
	_set_label_font(panel, "StageHelpScenarioTitle", body_font if portrait else 19)
	_set_label_font(panel, "StageHelpGoalLabel", section_font if portrait else 28)
	var guide_text := panel.find_child("StageGuideText", true, false) as RichTextLabel
	if guide_text != null:
		guide_text.add_theme_font_size_override("normal_font_size", body_font if portrait else 20)
	for button_node: Node in panel.find_children("*", "Button", true, false):
		var button := button_node as Button
		button.add_theme_font_size_override("font_size", button_font)
		button.custom_minimum_size.y = (
			float(context.get("primary_button_height", 116.0))
			if button.name == "StageIntroConfirmButton"
			else float(context.get("secondary_button_height", 104.0))
		) if portrait else (58.0 if button.name == "StageIntroConfirmButton" else 52.0)


func _set_label_font(panel: PanelContainer, node_name: String, font_size: int) -> void:
	var label := panel.find_child(node_name, true, false) as Label
	if label != null:
		label.add_theme_font_size_override("font_size", font_size)


func _build_intro_overlay() -> void:
	_intro_overlay = _make_overlay("DeckTrainingIntroOverlay", 2450)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_overlay.add_child(center)
	_intro_panel = _make_panel()
	_intro_panel.name = "DeckTrainingIntroPanel"
	center.add_child(_intro_panel)
	var box := _panel_box(_intro_panel)
	var title := Label.new()
	title.name = "StageIntroTitle"
	title.text = "专家 %02d  %s" % [int(_scenario.get("order", 0)), str(_scenario.get("title", "残局训练"))]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var objective := Label.new()
	objective.name = "StageGoalLabel"
	objective.text = PresentationScript.goal_summary(_scenario)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size", 26)
	objective.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34))
	box.add_child(objective)
	var limit := Label.new()
	limit.name = "StageIntroLimit"
	limit.text = "限 %d 个我方回合 · 规则 AI 会改变中间场面 · 最后统一结算" % int(_scenario.get("turn_limit", 1))
	limit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit.add_theme_font_size_override("font_size", 18)
	limit.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34))
	box.add_child(limit)
	var buttons := HFlowContainer.new()
	buttons.name = "TrainingActionRow"
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 10)
	box.add_child(buttons)
	var guide_button := _make_button("解读", show_stage_guide)
	guide_button.name = "StageGuideButton"
	buttons.add_child(guide_button)
	var confirm := _make_button("开始训练", _on_intro_confirmed)
	confirm.name = "StageIntroConfirmButton"
	confirm.custom_minimum_size = Vector2(220, 58)
	buttons.add_child(confirm)
	apply_layout(_scene.get_viewport_rect().size)


func _on_intro_confirmed() -> void:
	if _intro_overlay != null and is_instance_valid(_intro_overlay):
		_intro_overlay.queue_free()
	_intro_overlay = null
	_intro_panel = null
	if _scene != null and _scene.has_method("_maybe_run_ai"):
		_scene.call_deferred("_maybe_run_ai")


func _maybe_show_result(status: Dictionary) -> void:
	if not bool(status.get("terminal", false)):
		return
	if not _result_recorded:
		ProgressStoreScript.record_result(str(_scenario.get("id", "")), status, int(_scenario.get("revision", 1)))
		_result_recorded = true
	if _result_overlay == null:
		_build_result_overlay(str(status.get("grade", "C")))


func _build_result_overlay(grade: String) -> void:
	_result_overlay = _make_overlay("DeckTrainingResultOverlay", 2500)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)
	_result_panel = _make_panel()
	_result_panel.name = "DeckTrainingResultPanel"
	center.add_child(_result_panel)
	var box := _panel_box(_result_panel)
	var grade_label := Label.new()
	grade_label.text = grade
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_label.add_theme_font_size_override("font_size", 96)
	grade_label.add_theme_color_override("font_color", _grade_color(grade))
	box.add_child(grade_label)
	var buttons := HFlowContainer.new()
	buttons.name = "TrainingActionRow"
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 10)
	box.add_child(buttons)
	if grade == "C":
		var guide_button := _make_button("解读", show_stage_guide)
		guide_button.name = "ResultGuideButton"
		buttons.add_child(guide_button)
	buttons.add_child(_make_button("重试", restart))
	buttons.add_child(_make_button("返回题库", _on_exit_pressed))
	apply_layout(_scene.get_viewport_rect().size)


func show_stage_goal() -> void:
	_build_help_overlay(false)


func show_stage_guide() -> void:
	_build_help_overlay(true)


func stage_goal_text() -> String:
	return PresentationScript.goal_summary(_scenario)


func stage_guide_text() -> String:
	return PresentationScript.guide_text(_scenario)


func _build_help_overlay(show_guide: bool) -> void:
	_close_help_overlay(false)
	if _scene == null or not is_instance_valid(_scene):
		return
	_help_showing_guide = show_guide
	_help_overlay = _make_overlay("DeckTrainingStageHelpOverlay", 2600)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(center)
	_help_panel = _make_panel()
	_help_panel.name = "DeckTrainingStageHelpPanel"
	center.add_child(_help_panel)
	var box := _panel_box(_help_panel)
	var title := Label.new()
	title.name = "StageHelpTitle"
	title.text = "关卡解读" if show_guide else "关卡说明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	if show_guide:
		_help_guide_text = RichTextLabel.new()
		_help_guide_text.name = "StageGuideText"
		_help_guide_text.text = stage_guide_text()
		_help_guide_text.fit_content = false
		_help_guide_text.scroll_active = true
		_help_guide_text.scroll_following = false
		_help_guide_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_help_guide_text.add_theme_font_size_override("normal_font_size", 20)
		box.add_child(_help_guide_text)
	else:
		var scenario_title := Label.new()
		scenario_title.name = "StageHelpScenarioTitle"
		scenario_title.text = str(_scenario.get("title", "残局训练"))
		scenario_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scenario_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scenario_title.add_theme_font_size_override("font_size", 19)
		scenario_title.add_theme_color_override("font_color", Color(0.69, 0.83, 0.88))
		box.add_child(scenario_title)
		var goal := Label.new()
		goal.name = "StageHelpGoalLabel"
		goal.text = stage_goal_text()
		goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.add_theme_font_size_override("font_size", 28)
		goal.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34))
		box.add_child(goal)
	var buttons := HFlowContainer.new()
	buttons.name = "TrainingActionRow"
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 10)
	box.add_child(buttons)
	if show_guide:
		buttons.add_child(_make_button("返回目标", show_stage_goal))
	else:
		var guide_button := _make_button("解读", show_stage_guide)
		guide_button.name = "StageHelpGuideButton"
		buttons.add_child(guide_button)
	buttons.add_child(_make_button("关闭", _close_help_overlay))
	apply_layout(_scene.get_viewport_rect().size)


func _close_help_overlay(resume_ai: bool = true) -> void:
	if _help_overlay != null and is_instance_valid(_help_overlay):
		_help_overlay.queue_free()
	_help_overlay = null
	_help_panel = null
	_help_guide_text = null
	_help_showing_guide = false
	if resume_ai and _scene != null and is_instance_valid(_scene) and _scene.has_method("_maybe_run_ai"):
		_scene.call_deferred("_maybe_run_ai")


func _make_overlay(node_name: String, layer: int) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = node_name
	overlay.color = Color(0.005, 0.018, 0.025, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = layer
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.add_child(overlay)
	return overlay


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.085, 0.11, 0.98)
	style.border_color = Color(0.18, 0.88, 0.95, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "TrainingPanelMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "TrainingPanelContent"
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	return box


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	return button


func _configure_restart_button() -> void:
	var button := _battle_ai_button()
	if button == null:
		return
	if not button.has_meta("deck_training_original_text"):
		button.set_meta("deck_training_original_text", button.text)
	button.text = "重开"
	button.tooltip_text = "重新开始当前残局"
	button.visible = true


func _configure_stage_help_button() -> void:
	var button := _stage_help_button()
	if button == null:
		return
	if not button.has_meta("deck_training_original_text"):
		button.set_meta("deck_training_original_text", button.text)
	if not button.has_meta("deck_training_original_tooltip"):
		button.set_meta("deck_training_original_tooltip", button.tooltip_text)
	button.text = "关卡说明"
	button.tooltip_text = "查看本关目标与完整解读"
	button.set_meta("portrait_compact_text_override", "关卡")
	button.visible = true


func _restore_ai_button() -> void:
	var button := _battle_ai_button()
	if button != null and button.has_meta("deck_training_original_text"):
		button.text = str(button.get_meta("deck_training_original_text"))
		button.remove_meta("deck_training_original_text")


func _restore_stage_help_button() -> void:
	var button := _stage_help_button()
	if button == null:
		return
	if button.has_meta("_portrait_previous_top_action_text"):
		button.remove_meta("_portrait_previous_top_action_text")
	if button.has_meta("deck_training_original_text"):
		button.text = str(button.get_meta("deck_training_original_text"))
		button.remove_meta("deck_training_original_text")
	if button.has_meta("deck_training_original_tooltip"):
		button.tooltip_text = str(button.get_meta("deck_training_original_tooltip"))
		button.remove_meta("deck_training_original_tooltip")
	button.remove_meta("portrait_compact_text_override")


func _battle_ai_button() -> Button:
	if _scene == null:
		return null
	return _scene.get("_btn_battle_discuss_ai") as Button


func _stage_help_button() -> Button:
	if _scene == null:
		return null
	return _scene.get("_btn_zeus_help") as Button


func _on_exit_pressed() -> void:
	GameManager.clear_deck_training_launch()
	GameManager.goto_deck_training()


func _grade_color(grade: String) -> Color:
	match grade:
		"S": return Color(1.0, 0.80, 0.22)
		"A": return Color(0.30, 0.95, 0.70)
		"B": return Color(0.35, 0.72, 1.0)
		_: return Color(0.82, 0.84, 0.88)


func _state() -> GameState:
	return _gsm.game_state if _gsm != null else null
