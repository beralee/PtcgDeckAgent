extends Control


const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const AdmissionVerifierScript := preload("res://scripts/training/DeckTrainingAdmissionVerifier.gd")
const ProgressStoreScript := preload("res://scripts/training/DeckTrainingProgressStore.gd")
const PresentationScript := preload("res://scripts/training/DeckTrainingPresentation.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

@onready var _root_margin: MarginContainer = %RootMargin
@onready var _deck_selector: GridContainer = %DeckSelector
@onready var _scenario_list: VBoxContainer = %ScenarioList
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _replay_button: Button = %ReplayButton

var _selected_deck_key := "dragapult"
var _deck_button_group := ButtonGroup.new()
var _deck_radio_buttons: Array[Button] = []
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _current_layout_context: Dictionary = {}


func _ready() -> void:
	var remembered_key := str(GameManager.get_deck_training_selected_deck_key())
	if CatalogScript.DECKS.has(remembered_key):
		_selected_deck_key = remembered_key
	_back_button.pressed.connect(_on_back_pressed)
	NonBattleTouchBridgeScript.bind_button_touch(_back_button)
	_replay_button.pressed.connect(_on_replay_pressed)
	NonBattleTouchBridgeScript.bind_button_touch(_replay_button)
	_build_deck_selector()
	_build_scenario_list()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	if GameManager != null and GameManager.has_signal("non_battle_layout_mode_changed"):
		var callback := Callable(self, "_on_non_battle_layout_mode_changed")
		if not GameManager.non_battle_layout_mode_changed.is_connected(callback):
			GameManager.non_battle_layout_mode_changed.connect(callback)


func _input(event: InputEvent) -> void:
	NonBattleTouchBridgeScript.handle_root_touch(self, event)


func _build_deck_selector() -> void:
	for child: Node in _deck_selector.get_children():
		_deck_selector.remove_child(child)
		child.queue_free()
	_deck_radio_buttons.clear()
	_deck_button_group.allow_unpress = false
	for option: Dictionary in CatalogScript.deck_options():
		var button := Button.new()
		var deck_key := str(option.get("key", "deck"))
		button.name = "DeckTrainingHudRadio_%s" % deck_key
		button.toggle_mode = true
		button.button_group = _deck_button_group
		button.custom_minimum_size = Vector2(172, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.clip_text = true
		button.set_meta("deck_training_hud_radio", true)
		button.set_meta("deck_training_deck_key", deck_key)
		button.set_meta("deck_training_deck_name", str(option.get("name", "")))
		button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(18))
		button.pressed.connect(_on_deck_selected.bind(deck_key))
		NonBattleTouchBridgeScript.bind_button_touch(button)
		_deck_selector.add_child(button)
		_deck_radio_buttons.append(button)
	_refresh_deck_radio_buttons()


func _refresh_deck_radio_buttons() -> void:
	for button: Button in _deck_radio_buttons:
		if button == null:
			continue
		var selected := str(button.get_meta("deck_training_deck_key", "")) == _selected_deck_key
		button.button_pressed = selected
		button.text = "%s %s" % [
			"◉" if selected else "○",
			str(button.get_meta("deck_training_deck_name", "")),
		]
		_style_deck_radio_button(button, selected)


func _style_deck_radio_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", Color(0.05, 0.10, 0.13, 1.0) if selected else Color(0.88, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.05, 0.10, 0.13, 1.0) if selected else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.10, 0.13, 1.0))
	button.add_theme_stylebox_override("normal", _deck_radio_style(selected, false))
	button.add_theme_stylebox_override("hover", _deck_radio_style(selected, true))
	button.add_theme_stylebox_override("pressed", _deck_radio_style(true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _deck_radio_style(selected: bool, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.83, 1.0, 0.92) if selected else Color(0.02, 0.055, 0.08, 0.90)
	if emphasized:
		style.bg_color = Color(0.17, 0.72, 0.88, 0.96) if selected else Color(0.04, 0.12, 0.16, 0.96)
	style.border_color = Color(0.36, 0.92, 1.0, 0.90 if selected or emphasized else 0.48)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _build_scenario_list() -> void:
	for child: Node in _scenario_list.get_children():
		child.queue_free()
	var catalog := CatalogScript.load_catalog()
	var errors: Array = catalog.get("errors", [])
	var all_scenarios := CatalogScript.list_scenarios()
	var scenarios := CatalogScript.list_scenarios(CatalogScript.CATALOG_PATH, _selected_deck_key)
	var admission := AdmissionVerifierScript.verify_all(all_scenarios)
	for error: Variant in admission.get("errors", []):
		errors.append(error)
	if not errors.is_empty():
		_status_label.text = "训练题库校验失败：%s" % str(errors[0])
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
		return
	_status_label.text = "每套 10 题 · 专家两回合残局 · 至少 2 个不可逆判断 · 目标为四奖或三奖反杀"
	var progress: Dictionary = ProgressStoreScript.load_progress()
	for scenario: Dictionary in scenarios:
		_scenario_list.add_child(_make_scenario_card(scenario, ProgressStoreScript.scenario_progress(progress, scenario)))
	_apply_layout()


func _make_scenario_card(scenario: Dictionary, progress_variant: Variant) -> Control:
	var progress: Dictionary = progress_variant if progress_variant is Dictionary else {}
	var panel := PanelContainer.new()
	panel.name = "DeckTrainingScenarioCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.095, 0.13, 0.96)
	style.border_color = Color(0.12, 0.78, 0.92, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.name = "DeckTrainingScenarioContent"
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var title := Label.new()
	title.name = "DeckTrainingScenarioTitle"
	title.text = "%02d  %s" % [int(scenario.get("order", 0)), str(scenario.get("title", "残局"))]
	title.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(24))
	title.add_theme_color_override("font_color", Color(0.91, 0.99, 1.0))
	box.add_child(title)
	var detail := Label.new()
	detail.name = "DeckTrainingScenarioDetail"
	detail.text = "本局目标：%s" % PresentationScript.goal_summary(scenario)
	var best_grade := str(progress.get("best_grade", ""))
	if best_grade != "":
		detail.text += " · 最佳 %s" % best_grade
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(17))
	detail.add_theme_color_override("font_color", Color(0.98, 0.76, 0.34))
	box.add_child(detail)
	var start_button := Button.new()
	start_button.name = "DeckTrainingScenarioStartButton"
	start_button.set_meta(
		"ui_test_id",
		"DeckTrainingScenarioStartButton_%s" % str(scenario.get("id", ""))
	)
	start_button.text = "开始训练"
	start_button.custom_minimum_size = Vector2(0, 58)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(20))
	start_button.pressed.connect(_on_start_scenario.bind(str(scenario.get("id", ""))))
	NonBattleTouchBridgeScript.bind_button_touch(start_button)
	box.add_child(start_button)
	panel.set_meta("start_button", start_button)
	panel.set_meta("content_box", box)
	panel.set_meta("title_label", title)
	panel.set_meta("detail_label", detail)
	panel.set_meta("panel_style", style)
	return panel


func _apply_layout_for_tests(viewport_size: Vector2, mode: String) -> void:
	_apply_layout(viewport_size, mode)


func _apply_layout(viewport_size: Vector2 = Vector2.ZERO, forced_mode: String = "") -> void:
	if _root_margin == null:
		return
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	var mode := forced_mode
	if mode == "":
		mode = str(GameManager.get("non_battle_layout_mode")) if GameManager != null else "landscape"
	var is_mobile := OS.has_feature("mobile") \
		or OS.has_feature("android") \
		or OS.has_feature("ios") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")
	var context: Dictionary = _non_battle_layout_controller.call(
		"build_context",
		size,
		mode,
		is_mobile
	)
	_current_layout_context = context.duplicate(true)
	var portrait := bool(context.get("is_portrait", false))
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	var page_margin := int(context.get("page_margin", 24.0))
	var horizontal_margin := page_margin if portrait else clampi(int(size.x * 0.075), 20, 120)
	_root_margin.add_theme_constant_override("margin_left", horizontal_margin)
	_root_margin.add_theme_constant_override("margin_right", horizontal_margin)
	_root_margin.add_theme_constant_override(
		"margin_top",
		page_margin if portrait else clampi(int(size.y * 0.035), 20, 54)
	)
	_root_margin.add_theme_constant_override(
		"margin_bottom",
		page_margin if portrait else clampi(int(size.y * 0.03), 20, 48)
	)
	var section_gap := int(context.get("section_gap", 22)) if portrait else 12
	var title_font := int(context.get("title_font_size", 44)) if portrait else 30
	var section_font := int(context.get("section_font_size", 33)) if portrait else 20
	var body_font := int(context.get("body_font_size", 27)) if portrait else 18
	var button_font := int(context.get("button_font_size", 33)) if portrait else HudThemeScript.scaled_font_size(18)
	var header_button_font := maxi(24, button_font - 7) if portrait else button_font
	var secondary_height := float(context.get("secondary_button_height", 104.0)) if portrait else 48.0
	var primary_height := float(context.get("primary_button_height", 116.0)) if portrait else 58.0
	var root_vbox := get_node_or_null("RootMargin/VBox") as VBoxContainer
	var header := get_node_or_null("RootMargin/VBox/Header") as HBoxContainer
	var title := find_child("Title", true, false) as Label
	var deck_prompt := find_child("DeckPrompt", true, false) as Label
	var scroll := find_child("Scroll", true, false) as ScrollContainer
	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", section_gap)
	if header != null:
		header.add_theme_constant_override("separation", section_gap if portrait else 18)
	if title != null:
		title.add_theme_font_size_override("font_size", title_font)
	if deck_prompt != null:
		deck_prompt.add_theme_font_size_override("font_size", section_font)
	_status_label.add_theme_font_size_override("font_size", body_font)
	_status_label.add_theme_constant_override("line_spacing", maxi(3, section_gap / 4) if portrait else 2)
	for button: Button in [_back_button, _replay_button]:
		if button == null:
			continue
		button.custom_minimum_size.y = secondary_height
		button.add_theme_font_size_override("font_size", header_button_font)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		NonBattleTouchBridgeScript.bind_button_touch(button)
	_back_button.custom_minimum_size.x = secondary_height * 1.18 if portrait else 92.0
	_replay_button.custom_minimum_size.x = secondary_height * 1.72 if portrait else 116.0

	var available_width := maxf(240.0, size.x - float(horizontal_margin * 2))
	_deck_selector.columns = 2 if portrait else 4
	var deck_button_width := (available_width - float(section_gap)) * 0.5 if portrait else 172.0
	_deck_selector.add_theme_constant_override("h_separation", section_gap if portrait else 12)
	_deck_selector.add_theme_constant_override("v_separation", section_gap if portrait else 10)
	for child: Node in _deck_selector.get_children():
		if child is not Button:
			continue
		var deck_button := child as Button
		deck_button.custom_minimum_size = Vector2(
			deck_button_width,
			secondary_height if portrait else 50.0
		)
		deck_button.add_theme_font_size_override("font_size", button_font if portrait else HudThemeScript.scaled_font_size(18))

	_scenario_list.add_theme_constant_override("separation", section_gap if portrait else 12)
	for panel: Node in _scenario_list.get_children():
		if panel is not PanelContainer:
			continue
		var scenario_panel := panel as PanelContainer
		var button: Button = panel.get_meta("start_button", null) as Button
		var box := panel.get_meta("content_box", null) as VBoxContainer
		var scenario_title := panel.get_meta("title_label", null) as Label
		var detail := panel.get_meta("detail_label", null) as Label
		var style := panel.get_meta("panel_style", null) as StyleBoxFlat
		scenario_panel.custom_minimum_size.y = float(context.get("list_item_min_height", 174.0)) if portrait else 0.0
		if box != null:
			box.add_theme_constant_override("separation", maxi(9, section_gap / 2) if portrait else 9)
		if scenario_title != null:
			scenario_title.add_theme_font_size_override(
				"font_size",
				section_font if portrait else HudThemeScript.scaled_font_size(24)
			)
		if detail != null:
			detail.add_theme_font_size_override(
				"font_size",
				body_font if portrait else HudThemeScript.scaled_font_size(17)
			)
			detail.add_theme_constant_override("line_spacing", maxi(3, section_gap / 4) if portrait else 2)
		if style != null:
			var content_margin := float(section_gap) if portrait else 18.0
			style.content_margin_left = content_margin
			style.content_margin_right = content_margin
			style.content_margin_top = content_margin if portrait else 16.0
			style.content_margin_bottom = content_margin if portrait else 16.0
			style.set_corner_radius_all(16 if portrait else 12)
		if button != null:
			button.custom_minimum_size = Vector2(0, primary_height)
			button.add_theme_font_size_override(
				"font_size",
				button_font if portrait else HudThemeScript.scaled_font_size(20)
			)
	if scroll != null:
		HudThemeScript.style_scroll_container(scroll, "auto")
		if portrait:
			NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
		else:
			NonBattleTouchBridgeScript.configure_visible_vertical_scroll(scroll)


func _on_non_battle_layout_mode_changed(_mode: String) -> void:
	_apply_layout()


func _on_deck_selected(deck_key: String) -> void:
	if not CatalogScript.DECKS.has(deck_key):
		return
	_selected_deck_key = deck_key
	_refresh_deck_radio_buttons()
	GameManager.set_deck_training_selected_deck_key(deck_key)
	_build_scenario_list()


func _on_start_scenario(scenario_id: String) -> void:
	GameManager.start_deck_training(scenario_id)


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _on_replay_pressed() -> void:
	GameManager.goto_replay_browser()
