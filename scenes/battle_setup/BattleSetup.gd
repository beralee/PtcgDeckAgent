## 对战设置场景
extends Control

const DeckViewDialogScript := preload("res://scripts/ui/decks/DeckViewDialog.gd")
const DeckDiscussionDialogScene := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const ZenMuxClientScript := preload("res://scripts/network/ZenMuxClient.gd")

const FIRST_PLAYER_RANDOM := -1
const FIRST_PLAYER_PLAYER_ONE := 0
const FIRST_PLAYER_PLAYER_TWO := 1
const AI_SOURCE_DEFAULT := 0
const AI_SOURCE_LATEST := 1
const AI_SOURCE_SPECIFIC := 2
const AI_PREVIEW_STRENGTH_WEAK := 0
const AI_PREVIEW_STRENGTH_STRONG := 1
const BACKGROUND_DIR := "res://assets/ui"
const DEFAULT_BACKGROUND := "res://assets/ui/background.png"
const SETTINGS_PATH := "user://battle_setup.json"
const DECK_USAGE_STATS_PATH := "user://battle_deck_usage.json"
const DEFAULT_DECK1_ID := 575716  ## 喷火龙 大比鸟
const DEFAULT_DECK2_ID := 578647  ## 沙奈朵
const MIRAIDON_DECK_ID := 575720
const ARCEUS_GIRATINA_DECK_ID := 569061
const LUGIA_ARCHEOPS_DECK_ID := 575657
const RAGING_BOLT_OGERPON_DECK_ID := 575718
const DRAGAPULT_CHARIZARD_DECK_ID := 579502
const DRAGAPULT_DUSKNOIR_DECK_ID := 575723
const BACKGROUND_CARD_SIZE := Vector2(188, 112)
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)
const DECK_PICKER_ALL := "all"
const DECK_PICKER_RECENT := "recent"
const DECK_PICKER_LIMIT := 80

## 卡组列表，与 OptionButton index 对应
var _deck_list: Array = []
var _ai_deck_list: Array = []
var _deck_usage_stats: Dictionary = {}
var _battle_backgrounds: Array[String] = []
var _background_cards: Array[PanelContainer] = []
var _selected_background_path: String = DEFAULT_BACKGROUND
var _battle_music_tracks: Array[Dictionary] = []
var _selected_battle_music_id: String = "none"
var _selected_battle_music_volume_percent: int = 20
var _ai_version_registry: RefCounted = AIVersionRegistryScript.new()
var _ai_fixed_deck_order_registry: RefCounted = AIFixedDeckOrderRegistryScript.new()
var _playable_ai_versions: Array[Dictionary] = []
var _deck_view_dialog: RefCounted = DeckViewDialogScript.new()
var _deck_strategy_registry: RefCounted = DeckStrategyRegistryScript.new()
var _pending_ai_strategy_variant_id: String = ""
var _strategy_discussion_dialog: AcceptDialog = null
var _strategy_discussion_signature := ""
var _llm_model_test_client: ZenMuxClient = ZenMuxClientScript.new()
var _pending_llm_model_test_config: Dictionary = {}
var _llm_model_test_in_progress: bool = false
var _deck_picker_overlay: Control = null
var _deck_picker_panel: PanelContainer = null
var _deck_picker_slot_index: int = 0
var _deck_picker_category: String = DECK_PICKER_RECENT
var _deck_picker_search: String = ""
var _deck_picker_tabs: Dictionary = {}
var _deck_picker_grid: GridContainer = null
var _deck_picker_search_input: LineEdit = null
var _deck_picker_subtitle: Label = null
var _mode_segment_buttons: Dictionary = {}
var _first_player_segment_buttons: Dictionary = {}
var _ai_strategy_segment_buttons: Array[Button] = []


func _ready() -> void:
	_apply_hud_theme()
	%ModeOption.clear()
	%ModeOption.add_item("自己练牌", 0)
	%ModeOption.add_item("AI 对战", 1)
	%ModeOption.item_selected.connect(_on_mode_changed)
	_setup_mode_options()

	# 旧的 AI 策略下拉不再使用。
	%AIStrategyLabel.visible = false
	%AIStrategyOption.visible = false
	%AISourceLabel.visible = false
	%AISourceOption.visible = false
	%AIVersionLabel.visible = false
	%AIVersionOption.visible = false
	_setup_ai_preview_strength_options()
	_setup_ai_strategy_segment()
	_setup_llm_model_options()

	_setup_first_player_options()
	_setup_background_gallery()
	_setup_battle_music_options()

	%BtnStart.pressed.connect(_on_start)
	%BtnBack.pressed.connect(_on_back)
	%Deck1Option.item_selected.connect(_on_deck1_changed)
	%Deck2Option.item_selected.connect(_on_deck2_changed)
	%Deck1PickerButton.pressed.connect(_on_deck_picker_pressed.bind(0))
	%Deck2PickerButton.pressed.connect(_on_deck_picker_pressed.bind(1))
	%BtnDiscussStrategyAI.pressed.connect(_on_discuss_strategy_ai_pressed)
	%Deck1ViewButton.pressed.connect(_on_deck_view_pressed.bind(0))
	%Deck1EditButton.pressed.connect(_on_deck_edit_pressed.bind(0))
	%Deck2ViewButton.pressed.connect(_on_deck_view_pressed.bind(1))
	%Deck2EditButton.pressed.connect(_on_deck_edit_pressed.bind(1))
	if not %AIStrategyOption.item_selected.is_connected(_on_ai_strategy_variant_changed):
		%AIStrategyOption.item_selected.connect(_on_ai_strategy_variant_changed)
	if not %LLMModelOption.item_selected.is_connected(_on_llm_model_changed):
		%LLMModelOption.item_selected.connect(_on_llm_model_changed)
	if not %BtnTestLLMModel.pressed.is_connected(_on_test_llm_model_pressed):
		%BtnTestLLMModel.pressed.connect(_on_test_llm_model_pressed)
	if not %BtnPreviewBgm.pressed.is_connected(_on_bgm_preview_pressed):
		%BtnPreviewBgm.pressed.connect(_on_bgm_preview_pressed)

	_load_deck_usage_stats()
	_refresh_deck_options()
	_load_settings()
	_restore_returned_setup_context()
	_refresh_ai_ui_visibility()


func _apply_hud_theme() -> void:
	var shade := get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)

	var setup_frame := find_child("SetupFrame", true, false) as PanelContainer
	if setup_frame != null:
		setup_frame.add_theme_stylebox_override("panel", _hud_panel_style(
			Color(0.025, 0.055, 0.085, 0.72),
			Color(0.30, 0.86, 1.0, 0.86),
			24,
			18,
			Color(0.0, 0.45, 0.70, 0.30)
		))

	var left_column := find_child("LeftColumn", true, false) as PanelContainer
	if left_column != null:
		left_column.add_theme_stylebox_override("panel", _hud_panel_style(
			Color(0.035, 0.075, 0.11, 0.86),
			Color(0.26, 0.84, 1.0, 0.58),
			18,
			8,
			Color(0.0, 0.40, 0.65, 0.18)
		))

	var right_column := find_child("RightColumn", true, false) as PanelContainer
	if right_column != null:
		right_column.add_theme_stylebox_override("panel", _hud_panel_style(
			Color(0.045, 0.055, 0.085, 0.88),
			Color(1.0, 0.52, 0.22, 0.55),
			18,
			8,
			Color(0.75, 0.25, 0.06, 0.15)
		))

	var title := find_child("Title", true, false) as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 34)
		title.add_theme_color_override("font_color", HUD_TEXT)
		title.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 2)

	_apply_hud_theme_recursive(self)


func _apply_hud_theme_recursive(node: Node) -> void:
	if node is ScrollContainer:
		HudThemeScript.style_scroll_container(node as ScrollContainer)
	elif node is OptionButton:
		_style_hud_option(node as OptionButton)
	elif node is Button:
		_style_hud_button(node as Button)
	elif node is HSlider:
		_style_hud_slider(node as HSlider)
	elif node is Label:
		_style_hud_label(node as Label)

	for child: Node in node.get_children():
		_apply_hud_theme_recursive(child)


func _style_hud_label(label: Label) -> void:
	if label.name == "Title":
		return
	if label.name == "AIModeStatusTitle":
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.62))
		label.add_theme_constant_override("shadow_offset_y", 1)
		return
	if label.name == "AIModeStatusBody":
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.90, 1.0))
		return
	if label.name.ends_with("SectionTitle"):
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		label.add_theme_constant_override("shadow_offset_y", 1)
		return
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", HUD_TEXT_MUTED)


func _style_hud_button(button: Button) -> void:
	var is_primary := button.name == "BtnStart"
	var is_deck_picker := button.name.ends_with("PickerButton")
	var accent := HUD_ACCENT_WARM if is_primary else HUD_ACCENT
	button.add_theme_font_size_override("font_size", 14 if is_deck_picker else 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	if is_deck_picker:
		button.add_theme_stylebox_override("normal", _hud_deck_picker_button_style(false, false))
		button.add_theme_stylebox_override("hover", _hud_deck_picker_button_style(true, false))
		button.add_theme_stylebox_override("pressed", _hud_deck_picker_button_style(true, true))
		button.add_theme_stylebox_override("disabled", _hud_deck_picker_button_style(false, false))
	else:
		button.add_theme_stylebox_override("normal", _hud_button_style(accent, false, false))
		button.add_theme_stylebox_override("hover", _hud_button_style(accent, true, false))
		button.add_theme_stylebox_override("pressed", _hud_button_style(accent, true, true))
		button.add_theme_stylebox_override("disabled", _hud_button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_color_override("font_color", HUD_TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	option.add_theme_stylebox_override("normal", _hud_input_style(false))
	option.add_theme_stylebox_override("hover", _hud_input_style(true))
	option.add_theme_stylebox_override("pressed", _hud_input_style(true))
	option.add_theme_stylebox_override("disabled", _hud_input_disabled_style())
	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_slider(slider: HSlider) -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.02, 0.05, 0.08, 0.82)
	rail.border_color = Color(0.22, 0.82, 1.0, 0.45)
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(6)
	slider.add_theme_stylebox_override("slider", rail)

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Color(0.20, 0.78, 1.0, 0.72)
	grabber_area.set_corner_radius_all(6)
	slider.add_theme_stylebox_override("grabber_area", grabber_area)
	slider.add_theme_icon_override("grabber", _make_slider_grabber_icon(HUD_ACCENT))
	slider.add_theme_icon_override("grabber_highlight", _make_slider_grabber_icon(Color(0.72, 1.0, 1.0, 1.0)))


func _hud_panel_style(fill: Color, border: Color, radius: int, shadow_size: int, shadow_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_size = shadow_size
	style.shadow_color = shadow_color
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style


func _hud_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92) if pressed else Color(0.035, 0.075, 0.105, 0.92)
	if hover and not pressed:
		style.bg_color = Color(0.055, 0.13, 0.17, 0.96)
	style.border_color = accent
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.12)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _hud_deck_picker_button_style(hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.052, 0.078, 0.94)
	if hover:
		style.bg_color = Color(0.03, 0.10, 0.13, 0.98)
	if pressed:
		style.bg_color = Color(0.22, 0.78, 1.0, 0.92)
	style.border_color = Color(0.28, 0.90, 1.0, 0.86 if hover else 0.58)
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.58, 0.9, 0.20 if hover else 0.10)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _hud_deck_picker_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.070, 0.97)
	style.border_color = Color(0.32, 0.90, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.62, 0.95, 0.30)
	style.shadow_size = 18
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style


func _hud_segment_button_style(active: bool, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.24, 0.84, 1.0, 0.94)
		style.border_color = Color(0.76, 1.0, 1.0, 1.0)
	elif pressed:
		style.bg_color = Color(0.18, 0.70, 0.90, 0.92)
		style.border_color = Color(0.54, 0.94, 1.0, 0.96)
	else:
		style.bg_color = Color(0.018, 0.052, 0.078, 0.92)
		style.border_color = Color(0.26, 0.82, 1.0, 0.72 if hover else 0.44)
		if hover:
			style.bg_color = Color(0.035, 0.10, 0.13, 0.96)
	style.set_border_width_all(2 if active or hover else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.62, 0.9, 0.18 if active or hover else 0.06)
	style.shadow_size = 8 if active or hover else 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _hud_input_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.055, 0.86)
	if hover:
		style.bg_color = Color(0.025, 0.075, 0.105, 0.92)
	style.border_color = Color(0.23, 0.78, 1.0, 0.70 if hover else 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 28
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _hud_input_disabled_style() -> StyleBoxFlat:
	var style := _hud_input_style(false)
	style.bg_color = Color(0.02, 0.025, 0.03, 0.66)
	style.border_color = Color(0.18, 0.22, 0.26, 0.50)
	return style


func _make_slider_grabber_icon(color: Color) -> Texture2D:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(9, 9)
	for y: int in 18:
		for x: int in 18:
			var distance := center.distance_to(Vector2(x, y))
			if distance <= 8.0:
				var alpha := 1.0 if distance <= 6.8 else 1.0 - (distance - 6.8) / 1.2
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)


func _setup_mode_options() -> void:
	%ModeOption.visible = false
	_mode_segment_buttons = {
		0: %ModeTwoPlayerButton,
		1: %ModeAIButton,
	}
	for option_index_variant: Variant in _mode_segment_buttons.keys():
		var option_index := int(option_index_variant)
		var button := _mode_segment_buttons[option_index] as Button
		if button == null:
			continue
		var pressed_callable := Callable(self, "_on_mode_segment_pressed").bind(option_index)
		if not button.pressed.is_connected(pressed_callable):
			button.pressed.connect(pressed_callable)
	_select_mode_option(%ModeOption.selected)


func _on_mode_segment_pressed(option_index: int) -> void:
	_select_mode_option(option_index)
	_on_mode_changed(option_index)


func _select_mode_option(option_index: int) -> void:
	if %ModeOption.item_count <= 0:
		return
	var normalized := clampi(option_index, 0, %ModeOption.item_count - 1)
	%ModeOption.select(normalized)
	_sync_mode_segment_buttons()
	_refresh_first_player_segment_labels()


func _sync_mode_segment_buttons() -> void:
	for option_index_variant: Variant in _mode_segment_buttons.keys():
		var option_index := int(option_index_variant)
		var button := _mode_segment_buttons[option_index] as Button
		if button == null:
			continue
		var active: bool = option_index == %ModeOption.selected
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(0.04, 0.10, 0.12, 1.0) if active else HUD_TEXT)
		button.add_theme_color_override("font_hover_color", Color(0.04, 0.10, 0.12, 1.0) if active else Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(0.04, 0.10, 0.12, 1.0))
		button.add_theme_stylebox_override("normal", _hud_segment_button_style(active, false, false))
		button.add_theme_stylebox_override("hover", _hud_segment_button_style(active, true, false))
		button.add_theme_stylebox_override("pressed", _hud_segment_button_style(active, true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_mode_changed(_index: int) -> void:
	_sync_mode_segment_buttons()
	_mark_strategy_discussion_deck_changed()
	_refresh_deck_options()
	_refresh_ai_ui_visibility()


func _on_deck1_changed(_index: int) -> void:
	_mark_strategy_discussion_deck_changed()
	_sync_deck_picker_buttons()
	_refresh_deck_action_buttons()


func _on_deck2_changed(_index: int) -> void:
	_mark_strategy_discussion_deck_changed()
	_refresh_ai_strategy_variant_options()
	_sync_deck_picker_buttons()
	_refresh_deck_action_buttons()


func _refresh_ai_ui_visibility() -> void:
	_sync_mode_segment_buttons()
	_refresh_first_player_segment_labels()
	var is_ai: bool = %ModeOption.selected == 1
	%Deck2Label.text = "AI 卡组" if is_ai else "玩家2 卡组"
	%AIPreviewStrengthOption.visible = is_ai
	%AIPreviewStrengthOption.disabled = not is_ai
	%Deck2EditButton.visible = not is_ai
	_refresh_ai_strategy_variant_options()
	_refresh_llm_model_controls()
	_refresh_deck_action_buttons()


func _setup_ai_preview_strength_options() -> void:
	%AIPreviewStrengthOption.clear()
	%AIPreviewStrengthOption.add_item("弱", AI_PREVIEW_STRENGTH_WEAK)
	%AIPreviewStrengthOption.add_item("强", AI_PREVIEW_STRENGTH_STRONG)
	%AIPreviewStrengthOption.select(AI_PREVIEW_STRENGTH_WEAK)


func _refresh_ai_strategy_variant_options() -> void:
	var variants := _detect_ai_strategy_variants()
	var show_variant := _is_ai_mode() and variants.size() > 0
	%AIStrategyLabel.text = "AI 工作方式"
	%AIStrategyLabel.visible = show_variant
	%AIStrategyOption.visible = false
	%AIStrategyOption.disabled = variants.size() <= 1
	%AIStrategySegment.visible = show_variant
	if not show_variant:
		%AIStrategyOption.clear()
		_clear_ai_strategy_segment_buttons()
		_refresh_llm_model_controls()
		return
	var prev_selected_id := ""
	if %AIStrategyOption.selected >= 0 and %AIStrategyOption.selected < %AIStrategyOption.item_count:
		prev_selected_id = str(%AIStrategyOption.get_item_metadata(%AIStrategyOption.selected))
	%AIStrategyOption.clear()
	for variant: Dictionary in variants:
		var idx: int = %AIStrategyOption.item_count
		%AIStrategyOption.add_item(str(variant.get("label", "")))
		%AIStrategyOption.set_item_metadata(idx, str(variant.get("id", "")))
	_rebuild_ai_strategy_segment_buttons(variants)
	var restore_id := prev_selected_id if prev_selected_id != "" else _pending_ai_strategy_variant_id
	_pending_ai_strategy_variant_id = ""
	for i: int in %AIStrategyOption.item_count:
		if str(%AIStrategyOption.get_item_metadata(i)) == restore_id:
			_select_ai_strategy_option(i)
			_refresh_llm_model_controls()
			return
	_select_ai_strategy_option(0)
	_refresh_llm_model_controls()


func _setup_ai_strategy_segment() -> void:
	%AIStrategyOption.visible = false
	%AIStrategySegment.visible = false
	_clear_ai_strategy_segment_buttons()


func _clear_ai_strategy_segment_buttons() -> void:
	_ai_strategy_segment_buttons.clear()
	var segment := %AIStrategySegment as HBoxContainer
	if segment == null:
		return
	for child: Node in segment.get_children():
		segment.remove_child(child)
		child.queue_free()


func _rebuild_ai_strategy_segment_buttons(variants: Array[Dictionary]) -> void:
	_clear_ai_strategy_segment_buttons()
	var segment := %AIStrategySegment as HBoxContainer
	if segment == null:
		return
	for option_index: int in variants.size():
		var variant := variants[option_index]
		var button := Button.new()
		var label := str(variant.get("label", ""))
		button.name = "AIStrategyVariant%dButton" % option_index
		button.text = label
		button.tooltip_text = label
		button.custom_minimum_size = Vector2(124, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		_style_hud_button(button)
		segment.add_child(button)
		_ai_strategy_segment_buttons.append(button)
		button.pressed.connect(Callable(self, "_on_ai_strategy_segment_pressed").bind(option_index))
	_sync_ai_strategy_segment_buttons()


func _on_ai_strategy_segment_pressed(option_index: int) -> void:
	_select_ai_strategy_option(option_index)
	_on_ai_strategy_variant_changed(option_index)


func _select_ai_strategy_option(option_index: int) -> void:
	if %AIStrategyOption.item_count <= 0:
		return
	var normalized := clampi(option_index, 0, %AIStrategyOption.item_count - 1)
	%AIStrategyOption.select(normalized)
	_sync_ai_strategy_segment_buttons()


func _sync_ai_strategy_segment_buttons() -> void:
	var selected_index: int = int(%AIStrategyOption.selected)
	var option_count: int = int(%AIStrategyOption.item_count)
	for option_index: int in _ai_strategy_segment_buttons.size():
		var button := _ai_strategy_segment_buttons[option_index]
		if button == null:
			continue
		var active: bool = option_index == selected_index
		button.disabled = option_count <= 1
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(0.04, 0.10, 0.12, 1.0) if active else HUD_TEXT)
		button.add_theme_color_override("font_hover_color", Color(0.04, 0.10, 0.12, 1.0) if active else Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(0.04, 0.10, 0.12, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(0.04, 0.10, 0.12, 1.0) if active else Color(0.52, 0.60, 0.66, 1.0))
		button.add_theme_stylebox_override("normal", _hud_segment_button_style(active, false, false))
		button.add_theme_stylebox_override("hover", _hud_segment_button_style(active, true, false))
		button.add_theme_stylebox_override("pressed", _hud_segment_button_style(active, true, true))
		button.add_theme_stylebox_override("disabled", _hud_segment_button_style(active, false, false))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _detect_ai_strategy_variants() -> Array[Dictionary]:
	var deck := _selected_deck_for_slot(1)
	if deck == null or _deck_strategy_registry == null:
		return []
	var base_id := _selected_ai_strategy_id()
	if base_id == "" and _deck_strategy_registry.has_method("resolve_strategy_id_for_deck"):
		base_id = str(_deck_strategy_registry.call("resolve_strategy_id_for_deck", deck))
	if base_id not in [
		"raging_bolt_ogerpon",
		"dragapult_charizard",
		"miraidon",
		"lugia_archeops",
		"charizard_ex",
		"arceus_giratina",
		"gardevoir",
		"dragapult_dusknoir",
	]:
		return []
	var labels_by_strategy := {
		"charizard_ex": ["规则版喷火龙ex", "大模型版喷火龙ex"],
		"arceus_giratina": ["规则版阿尔宙斯骑拉帝纳", "大模型版阿尔宙斯骑拉帝纳"],
		"gardevoir": ["规则版沙奈朵", "大模型版沙奈朵"],
		"dragapult_dusknoir": ["规则版多龙黑夜魔灵", "大模型版多龙黑夜魔灵"],
		"dragapult_charizard": ["规则版多龙喷火龙", "大模型版多龙喷火龙"],
		"miraidon": ["规则版密勒顿", "大模型版密勒顿"],
		"lugia_archeops": ["规则版洛奇亚始祖大鸟", "大模型版洛奇亚始祖大鸟"],
		"raging_bolt_ogerpon": ["规则版猛雷鼓", "大模型版猛雷鼓"],
	}
	var labels: Array = labels_by_strategy.get(base_id, [])
	if labels.is_empty():
		return []
	var variants: Array[Dictionary] = [{
		"id": base_id,
		"label": str(labels[0]),
	}]
	if _has_llm_api_configured():
		variants.append({
			"id": "%s_llm" % base_id,
			"label": str(labels[1]),
		})
	return variants


func _selected_ai_strategy_variant_id() -> String:
	if %AIStrategyOption.selected < 0 or %AIStrategyOption.selected >= %AIStrategyOption.item_count:
		return ""
	return str(%AIStrategyOption.get_item_metadata(%AIStrategyOption.selected))


func _on_ai_strategy_variant_changed(_index: int) -> void:
	_refresh_llm_model_controls()


func _setup_llm_model_options() -> void:
	%LLMModelOption.clear()
	for model: Dictionary in GameManager.get_supported_battle_review_models():
		var index: int = %LLMModelOption.get_item_count()
		%LLMModelOption.add_item(str(model.get("label", model.get("id", ""))))
		%LLMModelOption.set_item_metadata(index, str(model.get("id", "")))
	_select_llm_model(str(GameManager.get_battle_review_api_config().get("model", "")))
	_refresh_llm_model_controls()


func _select_llm_model(model_id: String) -> void:
	var normalized := GameManager.normalize_battle_review_model(model_id)
	for index: int in %LLMModelOption.get_item_count():
		if str(%LLMModelOption.get_item_metadata(index)) == normalized:
			%LLMModelOption.select(index)
			return
	if %LLMModelOption.get_item_count() > 0:
		%LLMModelOption.select(0)


func _selected_llm_model_id() -> String:
	var selected_index: int = %LLMModelOption.selected
	if selected_index < 0:
		return GameManager.normalize_battle_review_model("")
	return GameManager.normalize_battle_review_model(str(%LLMModelOption.get_item_metadata(selected_index)))


func _selected_llm_model_label() -> String:
	return GameManager.get_battle_review_model_label(_selected_llm_model_id())


func _has_llm_api_configured() -> bool:
	var api_config: Dictionary = GameManager.get_battle_review_api_config()
	return (
		str(api_config.get("endpoint", "")).strip_edges() != ""
		and str(api_config.get("api_key", "")).strip_edges() != ""
	)


func _is_selected_ai_strategy_llm() -> bool:
	return _selected_ai_strategy_variant_id().ends_with("_llm")


func _refresh_llm_model_controls() -> void:
	var is_ai := _is_ai_mode()
	var has_llm_api := _has_llm_api_configured()
	var selected_is_llm := _is_selected_ai_strategy_llm()
	var selected_model_label := _selected_llm_model_label()
	_refresh_ai_mode_summary(is_ai, has_llm_api, selected_is_llm, selected_model_label)
	%AIModelCurrentLabel.visible = is_ai and has_llm_api and selected_is_llm
	%AIModelCurrentLabel.text = "当前大模型: %s" % selected_model_label
	%LLMModelLabel.visible = false
	%LLMModelRow.visible = is_ai and has_llm_api
	%LLMModelOption.disabled = not is_ai or not has_llm_api
	%BtnTestLLMModel.disabled = not is_ai or not has_llm_api or _llm_model_test_in_progress
	if not is_ai or not has_llm_api:
		%LLMModelStatus.text = ""
	%LLMModelStatus.visible = is_ai and %LLMModelStatus.text.strip_edges() != ""
	%BtnDiscussStrategyAI.visible = has_llm_api
	%BtnDiscussStrategyAI.text = "与 %s 探讨策略" % selected_model_label


func _refresh_ai_mode_summary(is_ai: bool, has_llm_api: bool, selected_is_llm: bool, selected_model_label: String) -> void:
	%AIModeStatusTitle.visible = is_ai
	%AIModeStatusBody.visible = is_ai
	if not is_ai:
		return
	if selected_is_llm and has_llm_api:
		%AIModeStatusTitle.text = "当前 AI: 大模型增强"
		%AIModeStatusBody.text = "使用 %s, 会有思考时间, 能力中等; 需要有效的模型 API, 完整配置请前往 AI 设置。" % selected_model_label
		%AIModeStatusTitle.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52, 1.0))
		return
	%AIModeStatusTitle.text = "当前 AI: 规则模型(默认)"
	if has_llm_api:
		%AIModeStatusBody.text = "速度快，能力较低，不用设置。已检测到大模型 API，可在 AI 工作方式中切换到大模型版。"
	else:
		%AIModeStatusBody.text = "速度快，能力较低，不用设置。未配置大模型 API 时，对战会直接使用本地规则模型。"
	%AIModeStatusTitle.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0, 1.0))


func _on_llm_model_changed(_index: int) -> void:
	_save_llm_model_selection("已切换为 %s" % _selected_llm_model_label())
	_refresh_llm_model_controls()


func _battle_review_config_with_selected_model() -> Dictionary:
	var config: Dictionary = GameManager.get_battle_review_api_config()
	config["model"] = _selected_llm_model_id()
	var signature := GameManager.battle_review_ai_config_signature(config)
	var still_tested := bool(config.get("ai_test_passed", false)) and str(config.get("ai_test_signature", "")) == signature
	config["ai_test_passed"] = still_tested
	config["ai_test_signature"] = signature if still_tested else ""
	return config


func _save_llm_model_selection(success_message: String = "") -> bool:
	var config := _battle_review_config_with_selected_model()
	return _write_battle_review_config(config, success_message)


func _write_battle_review_config(config: Dictionary, success_message: String = "") -> bool:
	var file := FileAccess.open(GameManager.get_battle_review_api_config_path(), FileAccess.WRITE)
	if file == null:
		%LLMModelStatus.text = "保存失败：无法写入 AI 配置"
		%LLMModelStatus.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		_refresh_llm_model_controls()
		return false
	file.store_string(JSON.stringify(config, "\t"))
	file.close()
	if success_message != "":
		%LLMModelStatus.text = success_message
		%LLMModelStatus.add_theme_color_override("font_color", Color(0.34, 1.0, 0.58))
		_refresh_llm_model_controls()
	return true


func _on_test_llm_model_pressed() -> void:
	var config := _battle_review_config_with_selected_model()
	var endpoint := str(config.get("endpoint", "")).strip_edges()
	var api_key := str(config.get("api_key", "")).strip_edges()
	if endpoint == "" or api_key == "":
		%LLMModelStatus.text = "测试失败：请先在 AI 设置填写 API 地址和密钥"
		%LLMModelStatus.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		_refresh_llm_model_controls()
		return

	_pending_llm_model_test_config = config.duplicate(true)
	_llm_model_test_in_progress = true
	%BtnTestLLMModel.disabled = true
	%LLMModelStatus.text = "正在测试 %s..." % _selected_llm_model_label()
	%LLMModelStatus.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	_refresh_llm_model_controls()

	_llm_model_test_client.set_timeout_seconds(float(config.get("timeout_seconds", 60.0)))
	var error := _llm_model_test_client.request_json(
		self,
		endpoint,
		api_key,
		{
			"model": _selected_llm_model_id(),
			"messages": [{
				"role": "system",
				"content": "Return exactly one JSON object and nothing else.",
			}, {
				"role": "user",
				"content": "Return exactly {\"ok\":true}.",
			}],
			"max_tokens": 80,
		},
		_on_test_llm_model_response
	)
	if error != OK:
		_llm_model_test_in_progress = false
		%BtnTestLLMModel.disabled = false
		%LLMModelStatus.text = "测试失败：请求无法启动 (%d)" % error
		%LLMModelStatus.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		_refresh_llm_model_controls()


func _on_test_llm_model_response(response: Dictionary) -> void:
	_llm_model_test_in_progress = false
	%BtnTestLLMModel.disabled = false
	if str(response.get("status", "")) == "error":
		%LLMModelStatus.text = "测试失败：%s" % str(response.get("message", "未知错误")).left(120)
		%LLMModelStatus.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		_refresh_llm_model_controls()
		return
	if bool(response.get("ok", false)):
		var config := _pending_llm_model_test_config.duplicate(true)
		config["model"] = _selected_llm_model_id()
		config["ai_test_passed"] = true
		config["ai_test_signature"] = GameManager.battle_review_ai_config_signature(config)
		_write_battle_review_config(config, "测试通过：%s 可用，已保存" % _selected_llm_model_label())
		_refresh_ai_strategy_variant_options()
		return
	%LLMModelStatus.text = "测试失败：模型返回格式不符合预期"
	%LLMModelStatus.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	_refresh_llm_model_controls()


func _setup_first_player_options() -> void:
	%FirstPlayerOption.clear()
	_ensure_first_player_option_items()
	%FirstPlayerOption.visible = false
	_first_player_segment_buttons = {
		0: %FirstPlayerRandomButton,
		1: %FirstPlayerOneButton,
		2: %FirstPlayerTwoButton,
	}
	for option_index_variant: Variant in _first_player_segment_buttons.keys():
		var option_index := int(option_index_variant)
		var button := _first_player_segment_buttons[option_index] as Button
		if button != null:
			var pressed_callable := Callable(self, "_on_first_player_segment_pressed").bind(option_index)
			if not button.pressed.is_connected(pressed_callable):
				button.pressed.connect(pressed_callable)
	_refresh_first_player_segment_labels()
	_select_first_player_option(_first_player_option_index_from_choice(GameManager.first_player_choice))


func _ensure_first_player_option_items() -> void:
	if %FirstPlayerOption.item_count > 0:
		return
	%FirstPlayerOption.add_item("随机先后攻")
	%FirstPlayerOption.add_item("玩家1先攻")
	%FirstPlayerOption.add_item("玩家2先攻")


func _refresh_first_player_segment_labels() -> void:
	var player_one_button := get_node_or_null("%FirstPlayerOneButton") as Button
	var player_two_button := get_node_or_null("%FirstPlayerTwoButton") as Button
	if player_one_button != null:
		player_one_button.text = "玩家先攻" if _is_ai_mode() else "玩家1先攻"
	if player_two_button != null:
		player_two_button.text = "AI先攻" if _is_ai_mode() else "玩家2先攻"


func _on_first_player_segment_pressed(option_index: int) -> void:
	_select_first_player_option(option_index)


func _select_first_player_option(option_index: int) -> void:
	_ensure_first_player_option_items()
	if %FirstPlayerOption.item_count <= 0:
		return
	var normalized := clampi(option_index, 0, %FirstPlayerOption.item_count - 1)
	%FirstPlayerOption.select(normalized)
	_sync_first_player_segment_buttons()


func _sync_first_player_segment_buttons() -> void:
	for option_index_variant: Variant in _first_player_segment_buttons.keys():
		var option_index := int(option_index_variant)
		var button := _first_player_segment_buttons[option_index] as Button
		if button == null:
			continue
		var active: bool = option_index == %FirstPlayerOption.selected
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(0.04, 0.10, 0.12, 1.0) if active else HUD_TEXT)
		button.add_theme_color_override("font_hover_color", Color(0.04, 0.10, 0.12, 1.0) if active else Color.WHITE)
		button.add_theme_stylebox_override("normal", _hud_segment_button_style(active, false, false))
		button.add_theme_stylebox_override("hover", _hud_segment_button_style(active, true, false))
		button.add_theme_stylebox_override("pressed", _hud_segment_button_style(active, true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _setup_ai_source_options() -> void:
	%AISourceOption.clear()
	%AISourceOption.add_item("默认 AI", AI_SOURCE_DEFAULT)
	%AISourceOption.add_item("最新训练版 AI", AI_SOURCE_LATEST)
	%AISourceOption.add_item("指定训练版本 AI", AI_SOURCE_SPECIFIC)
	%AISourceOption.select(_ai_source_option_index_from_source(str(GameManager.ai_selection.get("source", "default"))))
	if not %AISourceOption.item_selected.is_connected(_on_ai_source_changed):
		%AISourceOption.item_selected.connect(_on_ai_source_changed)
	_refresh_ai_version_control_state()


func _refresh_ai_version_options() -> void:
	_playable_ai_versions = []
	var strategy_id := _selected_ai_strategy_id()
	if _ai_version_registry != null and strategy_id != "" and _ai_version_registry.has_method("list_playable_versions_for_strategy"):
		_playable_ai_versions = _ai_version_registry.list_playable_versions_for_strategy(strategy_id)
	elif _ai_version_registry != null:
		_playable_ai_versions = _ai_version_registry.list_playable_versions()

	%AIVersionOption.clear()
	for version: Dictionary in _playable_ai_versions:
		%AIVersionOption.add_item(_format_ai_version_option_label(version))

	var selected_version_id := str(GameManager.ai_selection.get("version_id", ""))
	if not selected_version_id.is_empty():
		var selected_index := _ai_version_option_index_from_version_id(selected_version_id)
		if selected_index >= 0:
			%AIVersionOption.select(selected_index)
	elif not _playable_ai_versions.is_empty():
		%AIVersionOption.select(0)

	_refresh_ai_version_control_state()


func set_ai_version_registry_for_test(registry: RefCounted) -> void:
	_ai_version_registry = registry
	if get_node_or_null("%AIVersionOption") != null:
		_refresh_ai_version_options()


func _ai_source_option_index_from_source(source: String) -> int:
	match source:
		"latest_trained":
			return AI_SOURCE_LATEST
		"specific_version":
			return AI_SOURCE_SPECIFIC
		_:
			return AI_SOURCE_DEFAULT


func _ai_source_from_option_index(option_index: int) -> String:
	match option_index:
		AI_SOURCE_LATEST:
			return "latest_trained"
		AI_SOURCE_SPECIFIC:
			return "specific_version"
		_:
			return "default"


func _on_ai_source_changed(_index: int) -> void:
	_refresh_ai_version_control_state()


func _ai_version_option_index_from_version_id(version_id: String) -> int:
	for idx: int in _playable_ai_versions.size():
		if str(_playable_ai_versions[idx].get("version_id", "")) == version_id:
			return idx
	return -1


func _format_ai_version_option_label(version: Dictionary) -> String:
	var version_id := str(version.get("version_id", ""))
	var display_name := str(version.get("display_name", ""))
	var label := version_id
	if not display_name.is_empty():
		label = "%s | %s" % [version_id, display_name]

	var benchmark_summary := str(version.get("benchmark_summary", ""))
	if benchmark_summary != "" and benchmark_summary != "{}":
		label += " | %s" % benchmark_summary
	return label


func _refresh_ai_version_control_state() -> void:
	var show_version_picker := _ai_source_from_option_index(%AISourceOption.selected) == "specific_version"
	%AIVersionLabel.visible = show_version_picker
	%AIVersionOption.visible = show_version_picker
	%AIVersionOption.disabled = not show_version_picker or _playable_ai_versions.is_empty()


func _selected_ai_version_record() -> Dictionary:
	var selected_index: int = %AIVersionOption.selected
	if selected_index < 0 or selected_index >= _playable_ai_versions.size():
		return {}
	return _playable_ai_versions[selected_index].duplicate(true)


func _selected_ai_strategy_id() -> String:
	var deck := _selected_deck_for_slot(1)
	if deck == null:
		return ""
	match deck.id:
		MIRAIDON_DECK_ID:
			return "miraidon"
		DEFAULT_DECK2_ID:
			return "gardevoir"
		ARCEUS_GIRATINA_DECK_ID:
			return "arceus_giratina"
		LUGIA_ARCHEOPS_DECK_ID:
			return "lugia_archeops"
		RAGING_BOLT_OGERPON_DECK_ID:
			return "raging_bolt_ogerpon"
		DRAGAPULT_CHARIZARD_DECK_ID:
			return "dragapult_charizard"
		DRAGAPULT_DUSKNOIR_DECK_ID:
			return "dragapult_dusknoir"
		DEFAULT_DECK1_ID:
			return "charizard_ex"
		_:
			return ""


func _build_ai_selection(source: String, version_record: Dictionary = {}) -> Dictionary:
	return {
		"source": source,
		"version_id": str(version_record.get("version_id", "")),
		"agent_config_path": str(version_record.get("agent_config_path", "")),
		"value_net_path": str(version_record.get("value_net_path", "")),
		"action_scorer_path": str(version_record.get("action_scorer_path", "")),
		"display_name": str(version_record.get("display_name", "")),
		"opening_mode": "default",
		"fixed_deck_order_path": "",
	}


func _resolve_ai_opening_selection(deck: DeckData) -> Dictionary:
	if not _is_ai_mode() or %AIPreviewStrengthOption.selected != AI_PREVIEW_STRENGTH_STRONG:
		return {"opening_mode": "default", "fixed_deck_order_path": ""}
	if deck == null or _ai_fixed_deck_order_registry == null:
		return {"opening_mode": "default", "fixed_deck_order_path": ""}
	var fixed_order_path := str(_ai_fixed_deck_order_registry.call("get_fixed_order_path", int(deck.id)))
	if fixed_order_path == "":
		return {"opening_mode": "default", "fixed_deck_order_path": ""}
	return {"opening_mode": "fixed_order", "fixed_deck_order_path": fixed_order_path}


func _setup_background_gallery() -> void:
	%BackgroundGallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	%BackgroundGallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_refresh_background_gallery()


func _setup_battle_music_options() -> void:
	BattleMusicManager.ensure_custom_music_dir()
	_battle_music_tracks = BattleMusicManager.get_available_battle_tracks()
	%BgmOption.clear()
	for track: Dictionary in _battle_music_tracks:
		%BgmOption.add_item(str(track.get("label", "")))
	_selected_battle_music_id = BattleMusicManager.sanitize_track_id(GameManager.selected_battle_music_id)
	_selected_battle_music_volume_percent = clampi(int(GameManager.battle_bgm_volume_percent), 0, 100)
	var selected_index := _battle_music_index_from_id(_selected_battle_music_id)
	if selected_index >= 0 and selected_index < %BgmOption.item_count:
		%BgmOption.select(selected_index)
	elif %BgmOption.item_count > 0:
		%BgmOption.select(0)
	_sync_selected_battle_music_from_option()
	%BgmVolumeSlider.value = _selected_battle_music_volume_percent
	_update_bgm_volume_value_label()
	%BgmHint.text = "自定义音乐目录: %s" % BattleMusicManager.get_custom_music_absolute_dir_path()
	if not %BgmOption.item_selected.is_connected(_on_bgm_option_changed):
		%BgmOption.item_selected.connect(_on_bgm_option_changed)
	if not %BgmVolumeSlider.value_changed.is_connected(_on_bgm_volume_changed):
		%BgmVolumeSlider.value_changed.connect(_on_bgm_volume_changed)
	_update_bgm_preview_button()


func _on_bgm_option_changed(_index: int) -> void:
	_sync_selected_battle_music_from_option()
	_update_bgm_preview_button()


func _on_bgm_volume_changed(value: float) -> void:
	_selected_battle_music_volume_percent = clampi(int(round(value)), 0, 100)
	_update_bgm_volume_value_label()
	BattleMusicManager.set_battle_music_volume_percent(_selected_battle_music_volume_percent)


func _update_bgm_volume_value_label() -> void:
	%BgmVolumeValue.text = "%d%%" % _selected_battle_music_volume_percent


func _sync_selected_battle_music_from_option() -> void:
	var selected_index: int = %BgmOption.selected
	if selected_index >= 0 and selected_index < _battle_music_tracks.size():
		_selected_battle_music_id = str(_battle_music_tracks[selected_index].get("id", "none"))
	else:
		_selected_battle_music_id = "none"
	_selected_battle_music_id = BattleMusicManager.sanitize_track_id(_selected_battle_music_id)


func _on_bgm_preview_pressed() -> void:
	_sync_selected_battle_music_from_option()
	if BattleMusicManager.is_battle_music_playing() and BattleMusicManager.get_current_track_id() == _selected_battle_music_id:
		BattleMusicManager.stop_battle_music()
		_update_bgm_preview_button()
		return
	BattleMusicManager.set_battle_music_volume_percent(_selected_battle_music_volume_percent)
	BattleMusicManager.play_battle_music(_selected_battle_music_id)
	_update_bgm_preview_button()


func _update_bgm_preview_button() -> void:
	var is_current_preview := BattleMusicManager.is_battle_music_playing() and BattleMusicManager.get_current_track_id() == _selected_battle_music_id and _selected_battle_music_id != "none"
	%BtnPreviewBgm.text = "停止试听" if is_current_preview else "试听"


func _battle_music_index_from_id(track_id: String) -> int:
	for i: int in _battle_music_tracks.size():
		if str(_battle_music_tracks[i].get("id", "")) == track_id:
			return i
	return 0


## 导出后 DirAccess 无法遍历 pck 内的 res:// 目录，
## 因此背景列表采用硬编码 + 运行时校验 ResourceLoader.exists()。
func _list_available_background_paths() -> Array[String]:
	var candidates: Array[String] = [
		"res://assets/ui/background.png",
		"res://assets/ui/background1.png",
		"res://assets/ui/background2.png",
		"res://assets/ui/background3.png",
		"res://assets/ui/background4.png",
	]
	var results: Array[String] = []
	for path: String in candidates:
		if ResourceLoader.exists(path):
			results.append(path)
	if results.is_empty():
		results.append(DEFAULT_BACKGROUND)
	return results


func _refresh_background_gallery() -> void:
	_battle_backgrounds = _list_available_background_paths()
	_selected_background_path = GameManager.selected_battle_background if GameManager.selected_battle_background != "" else DEFAULT_BACKGROUND
	_clear_background_gallery()
	for bg_path: String in _battle_backgrounds:
		var texture := _load_background_preview_texture(bg_path)
		var card := _build_background_card(bg_path, texture)
		%BackgroundGalleryRow.add_child(card)
		_background_cards.append(card)
	_refresh_background_selection()


func _background_selection_index(path: String) -> int:
	var normalized_path := path if path != "" else DEFAULT_BACKGROUND
	var idx := _battle_backgrounds.find(normalized_path)
	return idx if idx >= 0 else 0


func _clear_background_gallery() -> void:
	for child: Node in %BackgroundGalleryRow.get_children():
		%BackgroundGalleryRow.remove_child(child)
		child.queue_free()
	_background_cards.clear()


func _build_background_card(path: String, texture: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = BACKGROUND_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = true
	card.set_meta("background_path", path)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_background_path = path
			_refresh_background_selection()
	)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var preview := TextureRect.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture = texture
	margin.add_child(preview)

	return card


func _refresh_background_selection() -> void:
	if _selected_background_path == "":
		_selected_background_path = DEFAULT_BACKGROUND
	for card: PanelContainer in _background_cards:
		if card == null:
			continue
		var is_selected := str(card.get_meta("background_path", "")) == _selected_background_path
		_apply_background_card_style(card, is_selected)


func _apply_background_card_style(card: PanelContainer, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 0.72)
	style.border_color = Color(0.19, 0.36, 0.46, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	if selected:
		style.bg_color = Color(0.04, 0.12, 0.18, 0.86)
		style.border_color = Color(0.48, 0.92, 1.0, 1.0)
	card.add_theme_stylebox_override("panel", style)


func _load_deck_usage_stats() -> void:
	_deck_usage_stats.clear()
	if not FileAccess.file_exists(DECK_USAGE_STATS_PATH):
		return
	var file := FileAccess.open(DECK_USAGE_STATS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var decks_raw: Variant = (parsed as Dictionary).get("decks", {})
	if decks_raw is Dictionary:
		_deck_usage_stats = decks_raw as Dictionary


func _save_deck_usage_stats() -> void:
	var file := FileAccess.open(DECK_USAGE_STATS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"decks": _deck_usage_stats}, "\t"))
	file.close()


func _record_battle_deck_usage(decks: Array[DeckData]) -> void:
	var seen := {}
	for deck: DeckData in decks:
		if deck == null or deck.id <= 0:
			continue
		if seen.has(deck.id):
			continue
		seen[deck.id] = true
		var key := str(deck.id)
		var entry := _deck_usage_entry(deck.id).duplicate(true)
		entry["use_count"] = int(entry.get("use_count", 0)) + 1
		entry["last_used"] = Time.get_datetime_string_from_system(false, true)
		entry["deck_name"] = deck.deck_name
		_deck_usage_stats[key] = entry
	_save_deck_usage_stats()


func _deck_usage_entry(deck_id: int) -> Dictionary:
	var raw: Variant = _deck_usage_stats.get(str(deck_id), {})
	return raw if raw is Dictionary else {}


func _deck_use_count(deck: DeckData) -> int:
	if deck == null:
		return 0
	return int(_deck_usage_entry(deck.id).get("use_count", 0))


func _deck_last_used(deck: DeckData) -> String:
	if deck == null:
		return ""
	return str(_deck_usage_entry(deck.id).get("last_used", ""))


func _deck_import_key(deck: DeckData) -> String:
	if deck == null:
		return ""
	return str(deck.import_date)


func _on_deck_picker_pressed(slot_index: int) -> void:
	_deck_picker_slot_index = slot_index
	_deck_picker_category = DECK_PICKER_RECENT
	_deck_picker_search = ""
	_ensure_deck_picker_overlay()
	if _deck_picker_search_input != null:
		_deck_picker_search_input.text = ""
	_refresh_deck_picker()
	_resize_deck_picker_panel()
	_deck_picker_overlay.visible = true
	_deck_picker_overlay.move_to_front()


func _ensure_deck_picker_overlay() -> void:
	if _deck_picker_overlay != null and is_instance_valid(_deck_picker_overlay):
		return
	_deck_picker_overlay = Control.new()
	_deck_picker_overlay.name = "DeckPickerOverlay"
	_deck_picker_overlay.visible = false
	_deck_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_picker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_deck_picker_overlay)

	var shade := ColorRect.new()
	shade.name = "DeckPickerShade"
	shade.color = Color(0.0, 0.012, 0.025, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close_deck_picker()
	)
	_deck_picker_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.name = "DeckPickerCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_picker_overlay.add_child(center)

	_deck_picker_panel = PanelContainer.new()
	_deck_picker_panel.name = "DeckPickerPanel"
	_deck_picker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_picker_panel.add_theme_stylebox_override("panel", _hud_deck_picker_panel_style())
	center.add_child(_deck_picker_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_deck_picker_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "选择卡组"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", HUD_TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.60))
	title.add_theme_constant_override("shadow_offset_y", 1)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(44, 38)
	close_button.pressed.connect(_close_deck_picker)
	_style_hud_button(close_button)
	header.add_child(close_button)

	_deck_picker_subtitle = Label.new()
	_deck_picker_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_hud_label(_deck_picker_subtitle)
	root.add_child(_deck_picker_subtitle)

	_deck_picker_search_input = LineEdit.new()
	_deck_picker_search_input.placeholder_text = "搜索卡组名、ID 或类型"
	_deck_picker_search_input.custom_minimum_size = Vector2(0, 42)
	_deck_picker_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_search_input.text_changed.connect(_on_deck_picker_search_changed)
	_style_hud_line_edit(_deck_picker_search_input)
	root.add_child(_deck_picker_search_input)

	var tabs := HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_deck_picker_tabs.clear()
	for tab: Dictionary in [
		{"id": DECK_PICKER_RECENT, "label": "最近使用"},
		{"id": DECK_PICKER_ALL, "label": "全部"},
	]:
		var button := Button.new()
		button.text = str(tab.get("label", ""))
		button.custom_minimum_size = Vector2(96, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_deck_picker_category_pressed.bind(str(tab.get("id", ""))))
		tabs.add_child(button)
		_deck_picker_tabs[str(tab.get("id", ""))] = button

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll)
	root.add_child(scroll)

	_deck_picker_grid = GridContainer.new()
	_deck_picker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_grid.add_theme_constant_override("h_separation", 10)
	_deck_picker_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_deck_picker_grid)


func _resize_deck_picker_panel() -> void:
	if _deck_picker_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	_deck_picker_panel.custom_minimum_size = Vector2(
		maxf(360.0, minf(940.0, viewport_size.x * 0.92)),
		maxf(420.0, minf(760.0, viewport_size.y * 0.88))
	)


func _close_deck_picker() -> void:
	if _deck_picker_overlay != null and is_instance_valid(_deck_picker_overlay):
		_deck_picker_overlay.visible = false


func _style_hud_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_font_size_override("font_size", 15)
	line_edit.add_theme_color_override("font_color", HUD_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.74, 0.82, 0.88))
	line_edit.add_theme_stylebox_override("normal", _hud_input_style(false))
	line_edit.add_theme_stylebox_override("focus", _hud_input_style(true))
	line_edit.add_theme_stylebox_override("read_only", _hud_input_disabled_style())


func _on_deck_picker_search_changed(text: String) -> void:
	_deck_picker_search = text.strip_edges()
	_refresh_deck_picker()


func _on_deck_picker_category_pressed(category: String) -> void:
	_deck_picker_category = category
	_refresh_deck_picker()


func _refresh_deck_picker() -> void:
	if _deck_picker_grid == null:
		return
	_deck_picker_grid.columns = 1 if get_viewport_rect().size.x < 760.0 else 2
	for child: Node in _deck_picker_grid.get_children():
		child.queue_free()
	_refresh_deck_picker_tabs()

	var decks := _decks_for_picker(_deck_picker_slot_index, _deck_picker_category, _deck_picker_search)
	if _deck_picker_subtitle != null:
		_deck_picker_subtitle.text = _deck_picker_subtitle_text(_deck_picker_slot_index, _deck_picker_category, decks.size())
	if decks.is_empty():
		var empty := Label.new()
		empty.text = "没有找到符合条件的卡组"
		empty.custom_minimum_size = Vector2(0, 90)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_hud_label(empty)
		_deck_picker_grid.add_child(empty)
		return

	var selected_deck := _selected_deck_for_slot(_deck_picker_slot_index)
	var selected_id := selected_deck.id if selected_deck != null else -1
	var count := 0
	for deck: DeckData in decks:
		if count >= DECK_PICKER_LIMIT:
			break
		var is_selected := deck.id == selected_id
		var button := Button.new()
		button.text = "%s\n%s" % [deck.deck_name, _deck_picker_card_meta(deck)]
		button.tooltip_text = _deck_picker_card_tooltip(deck)
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", HUD_TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _deck_picker_card_style(is_selected, false))
		button.add_theme_stylebox_override("hover", _deck_picker_card_style(is_selected, true))
		button.add_theme_stylebox_override("pressed", _deck_picker_card_pressed_style())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_deck_picker_deck_selected.bind(_deck_picker_slot_index, deck.id))
		_deck_picker_grid.add_child(button)
		count += 1


func _refresh_deck_picker_tabs() -> void:
	for category_variant: Variant in _deck_picker_tabs.keys():
		var category := str(category_variant)
		var button := _deck_picker_tabs[category] as Button
		if button == null:
			continue
		var active := category == _deck_picker_category
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.05, 0.10, 0.13, 1.0) if active else HUD_TEXT)
		button.add_theme_stylebox_override("normal", _deck_picker_tab_style(active, false))
		button.add_theme_stylebox_override("hover", _deck_picker_tab_style(active, true))
		button.add_theme_stylebox_override("pressed", _deck_picker_tab_style(true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _deck_picker_tab_style(active: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.83, 1.0, 0.92) if active else Color(0.02, 0.055, 0.08, 0.90)
	if hover and not active:
		style.bg_color = Color(0.04, 0.12, 0.16, 0.96)
	style.border_color = Color(0.36, 0.92, 1.0, 0.86 if active or hover else 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _deck_picker_card_style(selected: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.095, 0.92)
	if hover:
		style.bg_color = Color(0.04, 0.12, 0.16, 0.98)
	if selected:
		style.bg_color = Color(0.06, 0.15, 0.19, 0.98)
	style.border_color = Color(1.0, 0.62, 0.28, 1.0) if selected else Color(0.25, 0.82, 1.0, 0.55 if not hover else 0.92)
	style.set_border_width_all(2 if selected or hover else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.62, 0.9, 0.16 if hover else 0.08)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _deck_picker_card_pressed_style() -> StyleBoxFlat:
	var style := _deck_picker_card_style(true, true)
	style.bg_color = Color(0.22, 0.82, 1.0, 0.94)
	return style


func _on_deck_picker_deck_selected(slot_index: int, deck_id: int) -> void:
	var option := _deck_option_for_slot(slot_index)
	_select_option_for_deck_id(option, deck_id)
	if slot_index == 0:
		_on_deck1_changed(option.selected)
	else:
		_on_deck2_changed(option.selected)
	_close_deck_picker()


func _decks_for_picker(slot_index: int, category: String, search: String) -> Array[DeckData]:
	var source := _deck_source_list_for_slot(slot_index)
	var decks: Array[DeckData] = []
	for deck: DeckData in source:
		if _deck_matches_search(deck, search):
			decks.append(deck)

	match category:
		DECK_PICKER_RECENT:
			decks = decks.filter(func(deck: DeckData) -> bool:
				return _deck_last_used(deck) != ""
			)
			decks.sort_custom(func(a: DeckData, b: DeckData) -> bool:
				var au := _deck_last_used(a)
				var bu := _deck_last_used(b)
				if au == bu:
					return _deck_import_key(a) > _deck_import_key(b)
				return au > bu
			)
			if decks.is_empty() and search == "":
				decks = _fallback_decks_for_picker(slot_index, source)
		_:
			decks.sort_custom(func(a: DeckData, b: DeckData) -> bool:
				if _deck_import_key(a) == _deck_import_key(b):
					return a.deck_name < b.deck_name
				return _deck_import_key(a) > _deck_import_key(b)
			)
	return decks


func _fallback_decks_for_picker(slot_index: int, source: Array) -> Array[DeckData]:
	var result: Array[DeckData] = []
	var selected := _selected_deck_for_slot(slot_index)
	if selected != null:
		result.append(selected)
	var latest: Array[DeckData] = []
	for deck: DeckData in source:
		if selected != null and deck.id == selected.id:
			continue
		latest.append(deck)
	latest.sort_custom(func(a: DeckData, b: DeckData) -> bool:
		if _deck_import_key(a) == _deck_import_key(b):
			return a.deck_name < b.deck_name
		return _deck_import_key(a) > _deck_import_key(b)
	)
	for deck: DeckData in latest:
		if result.size() >= 8:
			break
		result.append(deck)
	return result


func _deck_matches_search(deck: DeckData, search: String) -> bool:
	if deck == null:
		return false
	var query := search.strip_edges().to_lower()
	if query == "":
		return true
	return (
		deck.deck_name.to_lower().contains(query)
		or deck.variant_name.to_lower().contains(query)
		or str(deck.id).contains(query)
	)


func _deck_picker_subtitle_text(slot_index: int, category: String, count: int) -> String:
	var slot_name := "玩家1" if slot_index == 0 else ("AI" if _is_ai_mode() else "玩家2")
	var category_text := "全部卡组"
	match category:
		DECK_PICKER_RECENT:
			category_text = "最近使用"
	return "%s 卡组选择 · %s · %d 套" % [slot_name, category_text, count]


func _deck_picker_card_meta(deck: DeckData) -> String:
	var parts: Array[String] = []
	var use_count := _deck_use_count(deck)
	if use_count > 0:
		parts.append("使用%d次" % use_count)
	var last_used := _deck_last_used(deck)
	if last_used != "":
		parts.append("最近使用")
	if deck.variant_name != "" and deck.variant_name != deck.deck_name:
		parts.append(deck.variant_name)
	if parts.is_empty():
		parts.append("点击选择")
	return " · ".join(parts)


func _deck_picker_card_tooltip(deck: DeckData) -> String:
	var lines := PackedStringArray([
		"ID: %d" % deck.id,
		"名称: %s" % deck.deck_name,
	])
	var last_used := _deck_last_used(deck)
	if last_used != "":
		lines.append("最近使用过")
	var use_count := _deck_use_count(deck)
	if use_count > 0:
		lines.append("使用次数: %d" % use_count)
	return "\n".join(lines)


func _deck_option_for_slot(slot_index: int) -> OptionButton:
	return %Deck1Option if slot_index == 0 else %Deck2Option


func _deck_source_list_for_slot(slot_index: int) -> Array:
	if slot_index == 1 and _is_ai_mode():
		return _ai_deck_list
	return _deck_list


func _sync_deck_picker_buttons() -> void:
	_sync_deck_picker_button(0)
	_sync_deck_picker_button(1)


func _sync_deck_picker_button(slot_index: int) -> void:
	var button := %Deck1PickerButton if slot_index == 0 else %Deck2PickerButton
	var deck := _selected_deck_for_slot(slot_index)
	if deck == null:
		button.text = "选择卡组\n点击打开卡组库"
		button.tooltip_text = ""
		button.disabled = true
		return
	button.disabled = false
	var meta := _deck_picker_card_meta(deck)
	if meta == "点击选择":
		meta = "点击更换卡组"
	button.text = "%s\n%s" % [deck.deck_name, meta]
	button.tooltip_text = _deck_picker_card_tooltip(deck)


func _load_background_preview_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _refresh_deck_options() -> void:
	var selected_deck1 := _selected_deck_for_slot(0)
	var selected_deck2 := _selected_deck_for_slot(1)
	_deck_list = CardDatabase.get_all_decks()
	_ai_deck_list = CardDatabase.get_all_ai_decks()
	%Deck1Option.clear()
	%Deck2Option.clear()

	if _deck_list.size() < 1 or (_is_ai_mode() and _ai_deck_list.is_empty()) or (not _is_ai_mode() and _deck_list.size() < 2):
		%NoDeckWarning.visible = true
		%BtnStart.disabled = true
		_sync_deck_picker_buttons()
		_refresh_deck_action_buttons()
		return

	%NoDeckWarning.visible = false
	%BtnStart.disabled = false

	for deck: DeckData in _deck_list:
		var label := "%s (%d张)" % [deck.deck_name, deck.total_cards]
		%Deck1Option.add_item(label)
		%Deck1Option.set_item_metadata(%Deck1Option.item_count - 1, deck.id)
	if _is_ai_mode():
		for ai_deck: DeckData in _ai_deck_list:
			%Deck2Option.add_item("%s (%d张)" % [ai_deck.deck_name, ai_deck.total_cards])
			%Deck2Option.set_item_metadata(%Deck2Option.item_count - 1, ai_deck.id)
	else:
		for deck: DeckData in _deck_list:
			%Deck2Option.add_item("%s (%d张)" % [deck.deck_name, deck.total_cards])
			%Deck2Option.set_item_metadata(%Deck2Option.item_count - 1, deck.id)

	_select_option_for_deck_id(%Deck1Option, selected_deck1.id if selected_deck1 != null else DEFAULT_DECK1_ID)
	var default_deck2_id := MIRAIDON_DECK_ID if _is_ai_mode() else DEFAULT_DECK2_ID
	_select_option_for_deck_id(%Deck2Option, selected_deck2.id if selected_deck2 != null else default_deck2_id)
	_sync_deck_picker_buttons()
	_refresh_deck_action_buttons()


func _selected_deck_for_slot(slot_index: int) -> DeckData:
	var option: OptionButton = %Deck1Option if slot_index == 0 else %Deck2Option
	var selected_index := option.selected
	if selected_index < 0 or selected_index >= option.item_count:
		return null
	var selected_text := option.get_item_text(selected_index)
	var selected_metadata: Variant = option.get_item_metadata(selected_index)
	var source_list: Array = _deck_list if slot_index == 0 or not _is_ai_mode() else _ai_deck_list
	if selected_metadata is int:
		for deck: DeckData in source_list:
			if deck.id == int(selected_metadata):
				return deck
	for deck: DeckData in source_list:
		if selected_text == deck.deck_name or selected_text.begins_with(deck.deck_name):
			return deck
	return null


func _is_ai_mode() -> bool:
	return %ModeOption.selected == 1


func _select_option_for_deck_id(option: OptionButton, deck_id: int) -> void:
	if option == null or option.item_count <= 0:
		return
	var source_list: Array = _deck_list
	if option == %Deck2Option and _is_ai_mode():
		source_list = _ai_deck_list
	for i: int in option.item_count:
		var metadata: Variant = option.get_item_metadata(i)
		if metadata is int and int(metadata) == deck_id:
			option.select(i)
			_sync_deck_picker_buttons()
			return
		var label := option.get_item_text(i)
		for deck: DeckData in source_list:
			if deck.id == deck_id and (label == deck.deck_name or label.begins_with(deck.deck_name)):
				option.select(i)
				_sync_deck_picker_buttons()
				return
	if option.selected < 0:
		option.select(0)
		_sync_deck_picker_buttons()


func _first_player_choice_from_option_index(option_index: int) -> int:
	match option_index:
		1: return FIRST_PLAYER_PLAYER_ONE
		2: return FIRST_PLAYER_PLAYER_TWO
		_: return FIRST_PLAYER_RANDOM


func _first_player_option_index_from_choice(choice: int) -> int:
	match choice:
		FIRST_PLAYER_PLAYER_ONE: return 1
		FIRST_PLAYER_PLAYER_TWO: return 2
		_: return 0


func _apply_setup_selection() -> bool:
	var mode_idx: int = %ModeOption.selected
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER if mode_idx == 0 else GameManager.GameMode.VS_AI

	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	if deck1 == null or deck2 == null:
		return false

	GameManager.selected_deck_ids = [deck1.id, deck2.id]
	GameManager.first_player_choice = _first_player_choice_from_option_index(%FirstPlayerOption.selected)
	GameManager.selected_battle_background = _selected_background_path if _selected_background_path != "" else DEFAULT_BACKGROUND
	_record_battle_deck_usage([deck1, deck2])
	_sync_battle_music_preferences_from_ui()
	if _is_ai_mode():
		_save_llm_model_selection()
	GameManager.mark_current_battle_as_non_tournament()

	var ai_source := _ai_source_from_option_index(%AISourceOption.selected)
	var ai_version: Dictionary = {}
	if ai_source == "latest_trained":
		if _ai_version_registry != null:
			ai_version = _ai_version_registry.get_latest_playable_version()
	elif ai_source == "specific_version":
		ai_version = _selected_ai_version_record()
	if ai_source != "default" and ai_version.is_empty():
		ai_source = "default"
	GameManager.ai_selection = _build_ai_selection(ai_source, ai_version)
	GameManager.ai_deck_strategy = _selected_ai_strategy_variant_id()
	var ai_opening_selection := _resolve_ai_opening_selection(_selected_deck_for_slot(1))
	for key_variant: Variant in ai_opening_selection.keys():
		var key := str(key_variant)
		GameManager.ai_selection[key] = ai_opening_selection[key]
	return true


func _on_start() -> void:
	if not _apply_setup_selection():
		return
	_save_settings()
	GameManager.goto_battle()


func _on_back() -> void:
	_sync_battle_music_preferences_from_ui()
	_save_settings()
	BattleMusicManager.stop_battle_music()
	GameManager.goto_main_menu()


func _exit_tree() -> void:
	BattleMusicManager.stop_battle_music()


func _save_settings() -> void:
	_sync_battle_music_preferences_from_ui()
	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	var data := {
		"deck1_id": deck1.id if deck1 != null else -1,
		"deck2_id": deck2.id if deck2 != null else -1,
		"first_player_choice": _first_player_choice_from_option_index(%FirstPlayerOption.selected),
		"background_path": _selected_background_path,
		"battle_music_id": _selected_battle_music_id,
		"battle_bgm_volume_percent": _selected_battle_music_volume_percent,
		"mode": %ModeOption.selected,
		"ai_preview_strength_index": %AIPreviewStrengthOption.selected,
		"ai_strategy_variant_id": _selected_ai_strategy_variant_id(),
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _sync_battle_music_preferences_from_ui() -> void:
	_sync_selected_battle_music_from_option()
	_selected_battle_music_volume_percent = clampi(int(round(%BgmVolumeSlider.value)), 0, 100)
	GameManager.selected_battle_music_id = _selected_battle_music_id
	GameManager.battle_bgm_volume_percent = _selected_battle_music_volume_percent


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_apply_default_deck_selection()
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary:
		return

	var deck1_id: int = int(data.get("deck1_id", -1))
	var deck2_id: int = int(data.get("deck2_id", -1))
	var mode_idx: int = int(data.get("mode", 0))
	if mode_idx >= 0 and mode_idx < %ModeOption.item_count:
		_select_mode_option(mode_idx)
	_refresh_deck_options()
	_select_option_for_deck_id(%Deck1Option, deck1_id)
	_select_option_for_deck_id(%Deck2Option, deck2_id)
	var ai_preview_strength_index: int = int(data.get("ai_preview_strength_index", AI_PREVIEW_STRENGTH_WEAK))
	if ai_preview_strength_index >= 0 and ai_preview_strength_index < %AIPreviewStrengthOption.item_count:
		%AIPreviewStrengthOption.select(ai_preview_strength_index)
	_pending_ai_strategy_variant_id = str(data.get("ai_strategy_variant_id", ""))

	var fp_choice: int = int(data.get("first_player_choice", FIRST_PLAYER_RANDOM))
	_select_first_player_option(_first_player_option_index_from_choice(fp_choice))

	var bg_path: String = str(data.get("background_path", DEFAULT_BACKGROUND))
	if bg_path in _battle_backgrounds:
		_selected_background_path = bg_path
		_refresh_background_selection()

	_selected_battle_music_id = BattleMusicManager.sanitize_track_id(str(data.get("battle_music_id", _selected_battle_music_id)))
	_selected_battle_music_volume_percent = clampi(int(data.get("battle_bgm_volume_percent", _selected_battle_music_volume_percent)), 0, 100)
	var battle_music_index := _battle_music_index_from_id(_selected_battle_music_id)
	if battle_music_index >= 0 and battle_music_index < %BgmOption.item_count:
		%BgmOption.select(battle_music_index)
	%BgmVolumeSlider.value = _selected_battle_music_volume_percent
	_update_bgm_volume_value_label()
	_update_bgm_preview_button()


func _capture_setup_selection_context() -> Dictionary:
	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	return {
		"deck1_id": deck1.id if deck1 != null else -1,
		"deck2_id": deck2.id if deck2 != null else -1,
		"first_player_choice": _first_player_choice_from_option_index(%FirstPlayerOption.selected),
		"background_path": _selected_background_path,
		"mode": %ModeOption.selected,
		"ai_source_index": %AISourceOption.selected,
		"ai_version_index": %AIVersionOption.selected,
		"ai_preview_strength_index": %AIPreviewStrengthOption.selected,
		"ai_strategy_variant_id": _selected_ai_strategy_variant_id(),
	}


func _apply_setup_context(context: Dictionary) -> void:
	var deck1_id := int(context.get("deck1_id", -1))
	var deck2_id := int(context.get("deck2_id", -1))
	var mode_idx := int(context.get("mode", %ModeOption.selected))
	if mode_idx >= 0 and mode_idx < %ModeOption.item_count:
		_select_mode_option(mode_idx)
	_refresh_deck_options()
	_select_option_for_deck_id(%Deck1Option, deck1_id)
	_select_option_for_deck_id(%Deck2Option, deck2_id)

	var first_player_choice := int(context.get("first_player_choice", FIRST_PLAYER_RANDOM))
	_select_first_player_option(_first_player_option_index_from_choice(first_player_choice))

	var background_path := str(context.get("background_path", DEFAULT_BACKGROUND))
	if background_path in _battle_backgrounds:
		_selected_background_path = background_path
		_refresh_background_selection()

	var ai_source_index := int(context.get("ai_source_index", %AISourceOption.selected))
	if ai_source_index >= 0 and ai_source_index < %AISourceOption.item_count:
		%AISourceOption.select(ai_source_index)
	var ai_version_index := int(context.get("ai_version_index", %AIVersionOption.selected))
	if ai_version_index >= 0 and ai_version_index < %AIVersionOption.item_count:
		%AIVersionOption.select(ai_version_index)
	var ai_preview_strength_index := int(context.get("ai_preview_strength_index", %AIPreviewStrengthOption.selected))
	if ai_preview_strength_index >= 0 and ai_preview_strength_index < %AIPreviewStrengthOption.item_count:
		%AIPreviewStrengthOption.select(ai_preview_strength_index)
	_pending_ai_strategy_variant_id = str(context.get("ai_strategy_variant_id", ""))

	_refresh_ai_ui_visibility()


func _restore_returned_setup_context() -> void:
	var context: Dictionary = GameManager.consume_deck_editor_return_context()
	if str(context.get("return_scene", "")) != "battle_setup":
		return
	_apply_setup_context(context)


func _refresh_deck_action_buttons() -> void:
	%Deck1ViewButton.disabled = _selected_deck_for_slot(0) == null
	%Deck1EditButton.disabled = _selected_deck_for_slot(0) == null
	%Deck2ViewButton.disabled = _selected_deck_for_slot(1) == null
	%Deck2EditButton.disabled = _is_ai_mode() or _selected_deck_for_slot(1) == null
	var has_llm_api := _has_llm_api_configured()
	%BtnDiscussStrategyAI.visible = has_llm_api
	%BtnDiscussStrategyAI.disabled = not has_llm_api or _selected_deck_for_slot(0) == null or _selected_deck_for_slot(1) == null


func _mark_strategy_discussion_deck_changed() -> void:
	var signature := _current_strategy_discussion_signature()
	if signature == _strategy_discussion_signature:
		return
	_strategy_discussion_signature = ""
	if _strategy_discussion_dialog != null and is_instance_valid(_strategy_discussion_dialog):
		_strategy_discussion_dialog.hide()


func _current_strategy_discussion_signature() -> String:
	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	if deck1 == null or deck2 == null:
		return ""
	var mode := "ai" if _is_ai_mode() else "pvp"
	return "%s:%d:%d" % [mode, deck1.id, deck2.id]


func _strategy_discussion_session_id(deck1: DeckData, deck2: DeckData) -> int:
	var mode_offset := 700000000 if _is_ai_mode() else 710000000
	return mode_offset + (abs(deck1.id) % 10000) * 10000 + (abs(deck2.id) % 10000)


func _on_discuss_strategy_ai_pressed() -> void:
	if not _has_llm_api_configured():
		return
	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	if deck1 == null or deck2 == null:
		return
	if _strategy_discussion_dialog == null or not is_instance_valid(_strategy_discussion_dialog):
		_strategy_discussion_dialog = DeckDiscussionDialogScene.instantiate() as AcceptDialog
		add_child(_strategy_discussion_dialog)
	var signature := _current_strategy_discussion_signature()
	var reset_session := signature != _strategy_discussion_signature
	_strategy_discussion_signature = signature
	var opponent_label := "AI 卡组" if _is_ai_mode() else "玩家2 卡组"
	_strategy_discussion_dialog.call(
		"setup_for_match",
		deck1,
		deck2,
		opponent_label,
		_strategy_discussion_session_id(deck1, deck2),
		reset_session
	)
	_strategy_discussion_dialog.popup_centered(Vector2i(980, 760))
	_strategy_discussion_dialog.size = Vector2i(980, 760)


func _on_deck_view_pressed(slot_index: int) -> void:
	var deck := _selected_deck_for_slot(slot_index)
	if deck == null:
		return
	_deck_view_dialog.call("show_deck", self, deck)


func _on_deck_edit_pressed(slot_index: int) -> void:
	if _is_ai_mode() and slot_index == 1:
		return
	var deck := _selected_deck_for_slot(slot_index)
	if deck == null:
		return
	var context := _capture_setup_selection_context()
	context["return_scene"] = "battle_setup"
	GameManager.goto_deck_editor(deck.id, context)


func _apply_default_deck_selection() -> void:
	_select_option_for_deck_id(%Deck1Option, DEFAULT_DECK1_ID)
	_select_option_for_deck_id(%Deck2Option, DEFAULT_DECK2_ID)
