class_name BattleCardView
extends PanelContainer

signal left_clicked(card_instance: CardInstance, card_data: CardData)
signal right_clicked(card_instance: CardInstance, card_data: CardData)
signal hand_drag_input(event: InputEvent)

const MODE_HAND := "hand"
const MODE_SLOT_ACTIVE := "slot_active"
const MODE_SLOT_BENCH := "slot_bench"
const MODE_CHOICE := "choice"
const MODE_PREVIEW := "preview"
const TOUCH_LONG_PRESS_SECONDS := 0.42
const TOUCH_LONG_PRESS_MOVE_TOLERANCE := 18.0
const HAND_PRIMARY_CLICK_MOVE_TOLERANCE := 12.0
const CARD_GALLERY_TOUCH_CLICK_MOVE_TOLERANCE := 28.0
const CARD_GALLERY_VERTICAL_CLICK_TOLERANCE := 36.0
const PRIMARY_RELEASE_FALLBACK_MIN_DELAY_MSEC := 80
const PRIMARY_RELEASE_FALLBACK_DURATION_MSEC := 1400
const ENERGY_ROW_MINIMUM_LAYOUT_GAP := 4
const CARD_FOIL_OFF := "off"
const CARD_FOIL_SHINE := "shine"
const CARD_FOIL_DEFAULT_INTENSITY := 1.2
const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")
const ENERGY_ICON_TEXTURES := {
	"R": preload("res://assets/ui/e-huo.png"),
	"W": preload("res://assets/ui/e-shui.png"),
	"G": preload("res://assets/ui/e-cao.png"),
	"L": preload("res://assets/ui/e-lei.png"),
	"P": preload("res://assets/ui/e-chao.png"),
	"F": preload("res://assets/ui/e-dou.png"),
	"D": preload("res://assets/ui/e-e.png"),
	"M": preload("res://assets/ui/e-gang.png"),
	"N": preload("res://assets/ui/e-long.png"),
	"C": preload("res://assets/ui/e-wu.png"),
}
const STATUS_ICON_TEXTURES := {
	"confused": preload("res://assets/ui/status_confusion.png"),
	"burned": preload("res://assets/ui/status_burn.png"),
	"poisoned": preload("res://assets/ui/status_poison.png"),
	"asleep": preload("res://assets/ui/status_sleep.png"),
	"paralyzed": preload("res://assets/ui/status_paralyzed.png"),
}
const STATUS_REFERENCE_CARD_HEIGHT := 168.0

class EnergyIconControl:
	extends Control

	var texture: Texture2D = null

	func _get_minimum_size() -> Vector2:
		return custom_minimum_size

	func _draw() -> void:
		if texture == null:
			return
		var texture_size := texture.get_size()
		if texture_size.x <= 0.0 or texture_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
			return
		var draw_scale := minf(size.x / texture_size.x, size.y / texture_size.y)
		var draw_size := texture_size * draw_scale
		var draw_position := (size - draw_size) * 0.5
		draw_texture_rect(texture, Rect2(draw_position, draw_size), false)


class CardInputCatcherControl:
	extends Control

	func _get_minimum_size() -> Vector2:
		return Vector2.ZERO

static var _texture_cache: Dictionary = {}
static var _failed_texture_paths: Dictionary = {}
static var _foil_shader: Shader = null
static var _empty_slot_shader: Shader = null


func _get_minimum_size() -> Vector2:
	if _field_slot_minimum_locked:
		return Vector2.ZERO
	return Vector2.ZERO


var card_instance: CardInstance = null
var card_data: CardData = null
var display_mode: String = MODE_HAND
var _selected: bool = false
var _selectable_hint: bool = false
var _selectable_hint_text: String = "可选"
var _selected_badge_text: String = "已选"
var _disabled: bool = false
var _face_down: bool = false
var _clickable: bool = true
var _back_texture: Texture2D = null
var _battle_status_active: bool = false
var _battle_status: Dictionary = {}
var _compact_preview: bool = false
var _tilt_degrees: float = 0.0
var _portrait_status_metrics_enabled: bool = false
var _status_text_scale: float = 1.0
var _field_slot_layout_size: Vector2 = Vector2.ZERO
var _field_slot_minimum_locked: bool = false
var _touch_long_press_timer: Timer = null
var _touch_long_press_active: bool = false
var _touch_long_press_index: int = -1
var _touch_long_press_start: Vector2 = Vector2.ZERO
var _touch_long_press_consumed: bool = false
var _suppress_next_left_click: bool = false
var _secondary_inspect_enabled: bool = false
var _hand_primary_press_active: bool = false
var _hand_primary_press_start: Vector2 = Vector2.ZERO
var _hand_primary_press_cancelled: bool = false
var _hand_primary_press_from_touch: bool = false
var _primary_release_fallback_ready_at_msec: int = 0
var _primary_release_fallback_until_msec: int = 0
var _primary_release_fallback_reason: String = ""
var _card_foil_effect_enabled: bool = false
var _card_foil_intensity: float = CARD_FOIL_DEFAULT_INTENSITY
var _card_foil_seed: float = -1.0
var _foil_material: ShaderMaterial = null
var _empty_slot_material: ShaderMaterial = null

var _outer_margin: MarginContainer
var _aspect_container: AspectRatioContainer
var _art_frame: PanelContainer

var _empty_slot_effect: ColorRect
var _texture_rect: TextureRect
var _missing_art_panel: PanelContainer
var _placeholder: Label
var _top_left_badge: Label
var _top_right_badge: Label
var _implementation_badge_panel: PanelContainer
var _implementation_badge_label: Label
var _info_panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _status_hud: VBoxContainer
var _status_used_panel: PanelContainer
var _status_used_label: Label
var _status_hp_value_label: Label
var _status_hp_bar_panel: PanelContainer
var _status_hp_bar: ProgressBar
var _status_condition_panel: PanelContainer
var _status_condition_row: HBoxContainer
var _status_energy_panel: PanelContainer
var _status_energy_row: HBoxContainer
var _status_tool_panel: PanelContainer
var _status_tool_label: Label
var _selection_overlay: PanelContainer
var _selection_badge_panel: PanelContainer
var _selection_badge: Label
var _input_catcher: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _clickable else Control.MOUSE_FILTER_IGNORE
	_ensure_ui()
	_ensure_touch_long_press_timer()
	_refresh()
	_apply_tilt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_tilt()
		_apply_responsive_status_metrics()


func setup_from_instance(inst: CardInstance = null, mode: String = MODE_HAND) -> void:
	_ensure_ui()
	card_instance = inst
	card_data = inst.card_data if inst != null else null
	set_card_foil_owner_index(inst.owner_index if inst != null else -1)
	_card_foil_effect_enabled = false
	set_meta("card_foil_effect_enabled", false)
	display_mode = mode
	_selected = false
	_selectable_hint = false
	if _clickable and display_mode == MODE_HAND:
		_ensure_input_catcher()
	_apply_card_input_filters()
	clear_battle_status()
	_refresh()


func setup_from_card_data(data: CardData, mode: String = MODE_CHOICE) -> void:
	_ensure_ui()
	card_instance = null
	card_data = data
	set_card_foil_owner_index(-1)
	_card_foil_effect_enabled = false
	set_meta("card_foil_effect_enabled", false)
	display_mode = mode
	_selected = false
	_selectable_hint = false
	_apply_card_input_filters()
	clear_battle_status()
	_refresh()


func set_selected(selected: bool) -> void:
	_ensure_ui()
	_selected = selected
	_update_style()


func set_selectable_hint(selectable_hint: bool) -> void:
	_ensure_ui()
	_selectable_hint = selectable_hint
	_update_style()


func set_selectable_hint_text(text: String) -> void:
	_ensure_ui()
	_selectable_hint_text = text.strip_edges() if text.strip_edges() != "" else "可选"
	_update_style()


func set_selected_badge_text(text: String) -> void:
	_ensure_ui()
	_selected_badge_text = text.strip_edges() if text.strip_edges() != "" else "已选"
	_update_style()


func set_disabled(disabled: bool) -> void:
	_ensure_ui()
	_disabled = disabled
	_update_style()
	_apply_card_foil_material()


func set_face_down(face_down: bool) -> void:
	_ensure_ui()
	_face_down = face_down
	_refresh()


func set_back_texture(texture: Texture2D) -> void:
	_ensure_ui()
	_back_texture = texture
	_refresh()


func set_clickable(clickable: bool) -> void:
	_ensure_ui()
	_clickable = clickable
	if clickable:
		_ensure_input_catcher()
	_apply_card_input_filters()
	if not clickable:
		_cancel_touch_long_press()
		clear_primary_release_fallback()


func arm_primary_release_fallback(
	reason: String = "transient_input",
	min_delay_msec: int = PRIMARY_RELEASE_FALLBACK_MIN_DELAY_MSEC,
	duration_msec: int = PRIMARY_RELEASE_FALLBACK_DURATION_MSEC
) -> void:
	var now := Time.get_ticks_msec()
	var safe_min_delay: int = maxi(0, min_delay_msec)
	var safe_duration: int = maxi(safe_min_delay + 1, duration_msec)
	_primary_release_fallback_ready_at_msec = now + safe_min_delay
	_primary_release_fallback_until_msec = now + safe_duration
	_primary_release_fallback_reason = reason


func clear_primary_release_fallback() -> void:
	_primary_release_fallback_ready_at_msec = 0
	_primary_release_fallback_until_msec = 0
	_primary_release_fallback_reason = ""


func is_primary_release_fallback_armed() -> bool:
	return _primary_release_fallback_until_msec > Time.get_ticks_msec()


func set_secondary_inspect_enabled(enabled: bool) -> void:
	_secondary_inspect_enabled = enabled


func set_compact_preview(compact: bool) -> void:
	_compact_preview = compact
	_ensure_ui()
	_update_layout()
	_update_style()


func set_wide_preview(wide: bool) -> void:
	_ensure_ui()
	_aspect_container.stretch_mode = AspectRatioContainer.STRETCH_COVER if wide else AspectRatioContainer.STRETCH_FIT


func set_tilt_degrees(degrees: float) -> void:
	_tilt_degrees = degrees
	_apply_tilt()


func set_portrait_status_metrics_enabled(enabled: bool) -> void:
	if _portrait_status_metrics_enabled == enabled:
		return
	_portrait_status_metrics_enabled = enabled
	_apply_responsive_status_metrics()
	if _battle_status_active:
		_update_battle_status_ui()


func set_status_text_scale(scale: float) -> void:
	var normalized := clampf(scale, 0.5, 1.25)
	if is_equal_approx(_status_text_scale, normalized):
		return
	_status_text_scale = normalized
	_apply_responsive_status_metrics()


func set_card_foil_effect_enabled(enabled: bool, intensity: float = CARD_FOIL_DEFAULT_INTENSITY) -> void:
	_ensure_ui()
	_card_foil_effect_enabled = enabled
	_card_foil_intensity = clampf(intensity, 0.0, 1.6)
	set_meta("card_foil_effect_enabled", _card_foil_effect_enabled)
	set_meta("card_foil_effect_intensity", _card_foil_intensity)
	_apply_card_foil_material()


func get_card_foil_effect_enabled() -> bool:
	return _card_foil_effect_enabled


func set_card_foil_owner_index(owner_index: int) -> void:
	set_meta("card_foil_owner_index", owner_index)


func get_card_foil_owner_index() -> int:
	if card_instance != null:
		return int(card_instance.owner_index)
	return int(get_meta("card_foil_owner_index", -1))


func set_card_foil_effect(mode: String, intensity: float = CARD_FOIL_DEFAULT_INTENSITY) -> void:
	set_card_foil_effect_enabled(mode != CARD_FOIL_OFF, intensity)


func get_card_foil_effect_mode() -> String:
	return CARD_FOIL_SHINE if _card_foil_effect_enabled else CARD_FOIL_OFF


func set_field_slot_layout_size(layout_size: Vector2) -> void:
	var normalized := Vector2.ZERO
	if layout_size.x > 0.0 and layout_size.y > 0.0:
		normalized = layout_size
	var was_locked := _field_slot_minimum_locked
	_field_slot_layout_size = normalized
	_field_slot_minimum_locked = normalized != Vector2.ZERO and (display_mode == MODE_SLOT_ACTIVE or display_mode == MODE_SLOT_BENCH)
	if was_locked != _field_slot_minimum_locked:
		update_minimum_size()
	_apply_responsive_status_metrics()
	if _battle_status_active:
		_update_battle_status_ui()


func set_badges(left_text: String = "", right_text: String = "") -> void:
	_ensure_ui()
	_top_left_badge.text = left_text
	_top_left_badge.visible = left_text != ""
	_top_right_badge.text = right_text
	_top_right_badge.visible = right_text != ""


func set_info(title_text: String, subtitle_text: String = "") -> void:
	_ensure_ui()
	_battle_status_active = false
	_title_label.text = title_text
	_title_label.visible = title_text != ""
	_subtitle_label.text = subtitle_text
	_subtitle_label.visible = subtitle_text != ""
	_update_overlay_visibility()


func clear_battle_status() -> void:
	_ensure_ui()
	_battle_status_active = false
	_battle_status.clear()
	_update_overlay_visibility()


func set_battle_status(data: Dictionary) -> void:
	_ensure_ui()
	_battle_status_active = true
	_battle_status = data.duplicate(true)
	_update_battle_status_ui()
	_update_overlay_visibility()


func _build_ui() -> void:
	if _texture_rect != null:
		return

	_outer_margin = MarginContainer.new()
	_make_passthrough(_outer_margin)
	_outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_outer_margin)

	_aspect_container = AspectRatioContainer.new()
	_make_passthrough(_aspect_container)
	_aspect_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aspect_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aspect_container.ratio = 0.716
	_aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_outer_margin.add_child(_aspect_container)

	_art_frame = PanelContainer.new()
	_make_passthrough(_art_frame)
	_art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aspect_container.add_child(_art_frame)

	_empty_slot_effect = ColorRect.new()
	_make_passthrough(_empty_slot_effect)
	_empty_slot_effect.name = "EmptySlotEffect"
	_empty_slot_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_slot_effect.color = Color.WHITE
	_empty_slot_effect.visible = false
	_art_frame.add_child(_empty_slot_effect)

	_texture_rect = TextureRect.new()
	_make_passthrough(_texture_rect)
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_frame.add_child(_texture_rect)

	_missing_art_panel = PanelContainer.new()
	_make_passthrough(_missing_art_panel)
	_missing_art_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_frame.add_child(_missing_art_panel)

	var missing_margin := MarginContainer.new()
	_make_passthrough(missing_margin)
	missing_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	missing_margin.add_theme_constant_override("margin_left", 12)
	missing_margin.add_theme_constant_override("margin_top", 14)
	missing_margin.add_theme_constant_override("margin_right", 12)
	missing_margin.add_theme_constant_override("margin_bottom", 14)
	_missing_art_panel.add_child(missing_margin)

	_placeholder = Label.new()
	_make_passthrough(_placeholder)
	_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placeholder.add_theme_font_size_override("font_size", 12)
	missing_margin.add_child(_placeholder)

	var overlay := MarginContainer.new()
	_make_passthrough(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 8)
	overlay.add_theme_constant_override("margin_top", 6)
	overlay.add_theme_constant_override("margin_right", 8)
	overlay.add_theme_constant_override("margin_bottom", 6)
	_art_frame.add_child(overlay)

	var overlay_vbox := VBoxContainer.new()
	_make_passthrough(overlay_vbox)
	overlay_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.add_child(overlay_vbox)

	var badge_row := HBoxContainer.new()
	_make_passthrough(badge_row)
	badge_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	badge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_theme_constant_override("separation", 6)
	overlay_vbox.add_child(badge_row)

	_top_left_badge = _make_badge_label()
	badge_row.add_child(_top_left_badge)

	_implementation_badge_panel = _make_implementation_badge()
	badge_row.add_child(_implementation_badge_panel)

	var spacer := Control.new()
	_make_passthrough(spacer)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_child(spacer)

	_top_right_badge = _make_badge_label()
	_top_right_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_row.add_child(_top_right_badge)

	var grow := Control.new()
	_make_passthrough(grow)
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_vbox.add_child(grow)

	_status_hud = VBoxContainer.new()
	_make_passthrough(_status_hud)
	_status_hud.alignment = BoxContainer.ALIGNMENT_END
	_status_hud.size_flags_vertical = Control.SIZE_SHRINK_END
	_status_hud.add_theme_constant_override("separation", 3)
	overlay_vbox.add_child(_status_hud)

	_status_used_panel = _make_status_panel()
	_status_hud.add_child(_status_used_panel)
	var used_margin := _make_status_margin(6, 2, 6, 2)
	_status_used_panel.add_child(used_margin)
	_status_used_label = Label.new()
	_make_passthrough(_status_used_label)
	_status_used_label.text = "USED"
	_status_used_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_used_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_used_label.add_theme_font_size_override("font_size", 10)
	var used_font := FontVariation.new()
	used_font.base_font = ThemeDB.fallback_font
	used_font.variation_embolden = 1.1
	_status_used_label.add_theme_font_override("font", used_font)
	used_margin.add_child(_status_used_label)

	_status_hp_bar_panel = _make_status_panel()
	_status_hud.add_child(_status_hp_bar_panel)
	var hp_bar_margin := _make_status_margin(6, 3, 6, 3)
	_status_hp_bar_panel.add_child(hp_bar_margin)
	var hp_bar_overlay := Control.new()
	_make_passthrough(hp_bar_overlay)
	hp_bar_overlay.custom_minimum_size = Vector2(0, 16)
	hp_bar_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar_margin.add_child(hp_bar_overlay)

	_status_hp_bar = ProgressBar.new()
	_make_passthrough(_status_hp_bar)
	_status_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_hp_bar.offset_top = 3
	_status_hp_bar.offset_bottom = -3
	_status_hp_bar.min_value = 0.0
	_status_hp_bar.max_value = 100.0
	_status_hp_bar.show_percentage = false
	hp_bar_overlay.add_child(_status_hp_bar)

	_status_hp_value_label = Label.new()
	_make_passthrough(_status_hp_value_label)
	_status_hp_value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_hp_value_label.clip_text = true
	var hp_font := FontVariation.new()
	hp_font.base_font = ThemeDB.fallback_font
	hp_font.variation_embolden = 1.2
	_status_hp_value_label.add_theme_font_override("font", hp_font)
	_status_hp_value_label.add_theme_font_size_override("font_size", 12)
	hp_bar_overlay.add_child(_status_hp_value_label)

	_status_condition_panel = _make_status_panel()
	_status_hud.add_child(_status_condition_panel)
	var condition_margin := _make_status_margin(6, 3, 6, 3)
	_status_condition_panel.add_child(condition_margin)
	_status_condition_row = HBoxContainer.new()
	_make_passthrough(_status_condition_row)
	_status_condition_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_condition_row.add_theme_constant_override("separation", 2)
	condition_margin.add_child(_status_condition_row)

	_status_energy_panel = _make_status_panel()
	_status_hud.add_child(_status_energy_panel)
	var energy_margin := _make_status_margin(6, 3, 6, 3)
	_status_energy_panel.add_child(energy_margin)
	_status_energy_row = HBoxContainer.new()
	_make_passthrough(_status_energy_row)
	_status_energy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_energy_row.add_theme_constant_override("separation", 2)
	energy_margin.add_child(_status_energy_row)

	_status_tool_panel = _make_status_panel(true)
	_status_hud.add_child(_status_tool_panel)
	var tool_margin := _make_status_margin(8, 2, 8, 2)
	_status_tool_panel.add_child(tool_margin)
	_status_tool_label = Label.new()
	_make_passthrough(_status_tool_label)
	_status_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_tool_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_tool_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_tool_label.clip_text = true
	_status_tool_label.add_theme_font_size_override("font_size", 9)
	tool_margin.add_child(_status_tool_label)

	_info_panel = PanelContainer.new()
	_make_passthrough(_info_panel)
	overlay_vbox.add_child(_info_panel)

	var info_margin := MarginContainer.new()
	_make_passthrough(info_margin)
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_top", 4)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_bottom", 4)
	_info_panel.add_child(info_margin)

	var info_vbox := VBoxContainer.new()
	_make_passthrough(info_vbox)
	info_vbox.add_theme_constant_override("separation", 2)
	info_margin.add_child(info_vbox)

	_title_label = Label.new()
	_make_passthrough(_title_label)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_make_passthrough(_subtitle_label)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 9)
	_subtitle_label.modulate = Color(0.92, 0.92, 0.92)
	info_vbox.add_child(_subtitle_label)

	_status_hud.visible = false
	_info_panel.visible = false

	_selection_overlay = PanelContainer.new()
	_make_passthrough(_selection_overlay)
	_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_overlay.visible = false
	_art_frame.add_child(_selection_overlay)

	var selection_margin := MarginContainer.new()
	_make_passthrough(selection_margin)
	selection_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_margin.add_theme_constant_override("margin_left", 8)
	selection_margin.add_theme_constant_override("margin_top", 7)
	selection_margin.add_theme_constant_override("margin_right", 8)
	selection_margin.add_theme_constant_override("margin_bottom", 7)
	_selection_overlay.add_child(selection_margin)

	var selection_box := VBoxContainer.new()
	_make_passthrough(selection_box)
	selection_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_margin.add_child(selection_box)

	var selection_row := HBoxContainer.new()
	_make_passthrough(selection_row)
	selection_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_box.add_child(selection_row)

	var selection_spacer := Control.new()
	_make_passthrough(selection_spacer)
	selection_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(selection_spacer)

	_selection_badge_panel = PanelContainer.new()
	_make_passthrough(_selection_badge_panel)
	_selection_badge_panel.add_theme_stylebox_override("panel", _make_selection_badge_style(true))
	selection_row.add_child(_selection_badge_panel)

	var badge_margin := MarginContainer.new()
	_make_passthrough(badge_margin)
	badge_margin.add_theme_constant_override("margin_left", 10)
	badge_margin.add_theme_constant_override("margin_top", 3)
	badge_margin.add_theme_constant_override("margin_right", 10)
	badge_margin.add_theme_constant_override("margin_bottom", 3)
	_selection_badge_panel.add_child(badge_margin)

	_selection_badge = Label.new()
	_make_passthrough(_selection_badge)
	_selection_badge.text = "已选"
	_selection_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_badge.add_theme_font_size_override("font_size", 12)
	_selection_badge.add_theme_color_override("font_color", Color(0.10, 0.06, 0.00, 1.0))
	var selection_font := FontVariation.new()
	selection_font.base_font = ThemeDB.fallback_font
	selection_font.variation_embolden = 1.4
	_selection_badge.add_theme_font_override("font", selection_font)
	badge_margin.add_child(_selection_badge)

	var selection_grow := Control.new()
	_make_passthrough(selection_grow)
	selection_grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_box.add_child(selection_grow)

	set_badges()
	_update_layout()
	_update_style()


func _ensure_input_catcher() -> void:
	if _input_catcher != null:
		return
	if _art_frame == null:
		_ensure_ui()
	_input_catcher = CardInputCatcherControl.new()
	_input_catcher.name = "CardInputCatcher"
	_input_catcher.focus_mode = Control.FOCUS_NONE
	_input_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_input_catcher.custom_minimum_size = Vector2.ZERO
	_input_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_catcher.gui_input.connect(_on_input_catcher_gui_input)
	_art_frame.add_child(_input_catcher)
	_apply_card_input_filters()


func _apply_card_input_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _clickable else Control.MOUSE_FILTER_IGNORE
	_set_child_controls_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
	if _input_catcher != null:
		_input_catcher.mouse_filter = Control.MOUSE_FILTER_STOP if _should_use_input_catcher() else Control.MOUSE_FILTER_IGNORE


func _should_use_input_catcher() -> bool:
	if not _clickable:
		return false
	return display_mode != MODE_SLOT_ACTIVE and display_mode != MODE_SLOT_BENCH


func _set_child_controls_mouse_filter(node: Node, filter: int) -> void:
	for child: Node in node.get_children():
		if child == _input_catcher:
			continue
		var control := child as Control
		if control != null:
			control.mouse_filter = filter
		_set_child_controls_mouse_filter(child, filter)


func _update_layout() -> void:
	if _outer_margin == null:
		return
	var outer_pad: int = 0 if _compact_preview else 4
	_outer_margin.add_theme_constant_override("margin_left", outer_pad)
	_outer_margin.add_theme_constant_override("margin_top", outer_pad)
	_outer_margin.add_theme_constant_override("margin_right", outer_pad)
	_outer_margin.add_theme_constant_override("margin_bottom", outer_pad)


func _ensure_ui() -> void:
	if _texture_rect == null:
		_build_ui()


func _ensure_touch_long_press_timer() -> void:
	if _touch_long_press_timer != null:
		return
	_touch_long_press_timer = Timer.new()
	_touch_long_press_timer.name = "TouchLongPressTimer"
	_touch_long_press_timer.one_shot = true
	_touch_long_press_timer.wait_time = TOUCH_LONG_PRESS_SECONDS
	_touch_long_press_timer.timeout.connect(_on_touch_long_press_timeout)
	add_child(_touch_long_press_timer)


func _make_badge_label() -> Label:
	var label := Label.new()
	_make_passthrough(label)
	label.visible = false
	label.add_theme_font_size_override("font_size", 10)
	return label


func _make_implementation_badge() -> PanelContainer:
	var panel := PanelContainer.new()
	_make_passthrough(panel)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _make_unimplemented_badge_style())

	var margin := MarginContainer.new()
	_make_passthrough(margin)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	_implementation_badge_label = Label.new()
	_make_passthrough(_implementation_badge_label)
	_implementation_badge_label.text = "未实现"
	_implementation_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_implementation_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_implementation_badge_label.add_theme_font_size_override("font_size", 10)
	var badge_font := FontVariation.new()
	badge_font.base_font = ThemeDB.fallback_font
	badge_font.variation_embolden = 1.1
	_implementation_badge_label.add_theme_font_override("font", badge_font)
	margin.add_child(_implementation_badge_label)
	return panel


func _make_status_panel(light: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	_make_passthrough(panel)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.modulate = Color(1, 1, 1, 1) if not light else Color(0.98, 0.98, 0.94, 1.0)
	return panel


func _make_status_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	_make_passthrough(margin)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_selection_badge_style(selected: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(1.0, 0.78, 0.08, 0.96)
		style.border_color = Color(1.0, 0.96, 0.48, 1.0)
		style.shadow_color = Color(1.0, 0.66, 0.08, 0.55)
	else:
		style.bg_color = Color(0.36, 0.95, 1.0, 0.72)
		style.border_color = Color(0.78, 1.0, 1.0, 0.78)
		style.shadow_color = Color(0.12, 0.72, 1.0, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(999)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_unimplemented_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.08, 0.02, 0.93)
	style.border_color = Color(1.0, 0.44, 0.12, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(1.0, 0.23, 0.04, 0.26)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 1)
	return style


func _make_passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh() -> void:
	_ensure_ui()

	var texture: Texture2D = _back_texture if _face_down else _load_texture(card_data)
	_texture_rect.texture = texture
	var show_missing_art := texture == null and not _face_down and card_data != null
	if _missing_art_panel != null:
		_missing_art_panel.visible = show_missing_art
	_placeholder.visible = texture == null and not _face_down
	_placeholder.text = _missing_art_text() if show_missing_art else _placeholder_text()

	if display_mode == MODE_PREVIEW:
		set_info("", "")
	elif card_data != null:
		set_info(card_data.name, _default_subtitle())
	else:
		set_info("", "")
	_update_implementation_badge()

	if _battle_status_active:
		_update_battle_status_ui()
		_update_overlay_visibility()

	_update_style()
	_apply_tilt()
	_apply_card_input_filters()
	_apply_card_foil_material()


func _placeholder_text() -> String:
	if _face_down:
		return ""
	if card_data == null:
		if display_mode == MODE_SLOT_ACTIVE or display_mode == MODE_SLOT_BENCH:
			return ""
		return "空位"
	return card_data.name


func _missing_art_text() -> String:
	if card_data == null:
		return ""

	var lines: Array[String] = [card_data.name]
	if card_data.card_type != "":
		lines.append(card_data.card_type)
	if card_data.is_pokemon() and card_data.hp > 0:
		lines.append("HP %d" % card_data.hp)
	elif card_data.energy_provides != "":
		lines.append("能量 %s" % card_data.energy_provides)
	lines.append("图片缺失")
	return "\n".join(lines)


func _default_subtitle() -> String:
	if card_data == null:
		return ""

	match display_mode:
		MODE_SLOT_ACTIVE, MODE_SLOT_BENCH:
			return card_data.card_type
		MODE_CHOICE:
			return "%s | %s" % [card_data.name, card_data.card_type]
		MODE_PREVIEW:
			return ""
		_:
			if card_data.is_pokemon():
				return "HP %d" % card_data.hp
			return card_data.card_type


func _load_texture(data: CardData) -> Texture2D:
	if data == null:
		return null

	var file_path := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths(data.set_code, data.card_index, data.image_local_path)
	)
	if file_path == "":
		return null

	if _texture_cache.has(file_path):
		return _texture_cache[file_path]
	if _failed_texture_paths.has(file_path):
		return null

	var image_bytes := FileAccess.get_file_as_bytes(file_path)
	if image_bytes.is_empty():
		_failed_texture_paths[file_path] = true
		return null

	var image := Image.new()
	var err := _load_image_from_buffer(image, image_bytes)
	if err != OK:
		_failed_texture_paths[file_path] = true
		return null

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[file_path] = texture
	return texture


func _load_image_from_buffer(image: Image, image_bytes: PackedByteArray) -> int:
	if image_bytes.size() >= 12:
		if image_bytes[0] == 0x89 and image_bytes[1] == 0x50 and image_bytes[2] == 0x4E and image_bytes[3] == 0x47:
			return image.load_png_from_buffer(image_bytes)
		if image_bytes[0] == 0xFF and image_bytes[1] == 0xD8:
			return image.load_jpg_from_buffer(image_bytes)
		if image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46 and image_bytes[8] == 0x57 and image_bytes[9] == 0x45 and image_bytes[10] == 0x42 and image_bytes[11] == 0x50:
			return image.load_webp_from_buffer(image_bytes)
	if image_bytes.size() >= 2 and image_bytes[0] == 0xFF and image_bytes[1] == 0xD8:
		return image.load_jpg_from_buffer(image_bytes)
	return ERR_FILE_UNRECOGNIZED


func _apply_card_foil_material() -> void:
	if _texture_rect == null:
		return
	if not _card_foil_effect_enabled or _card_foil_intensity <= 0.0 or _disabled or _face_down or _texture_rect.texture == null:
		_texture_rect.material = null
		return
	if _foil_material == null:
		_foil_material = ShaderMaterial.new()
		_foil_material.shader = _get_card_foil_shader()
		_foil_material.resource_local_to_scene = true
	if _card_foil_seed < 0.0:
		var source_id := card_instance.instance_id if card_instance != null else int(get_instance_id())
		_card_foil_seed = float(posmod(source_id * 37 + 17, 997)) / 997.0
	_foil_material.set_shader_parameter("foil_intensity", _card_foil_intensity)
	_foil_material.set_shader_parameter("foil_seed", _card_foil_seed)
	_texture_rect.material = _foil_material


func _apply_empty_slot_effect() -> void:
	if _empty_slot_effect == null:
		return
	var enabled := _is_empty_field_slot()
	_empty_slot_effect.visible = enabled
	if not enabled:
		_empty_slot_effect.material = null
		return
	if _empty_slot_material == null:
		_empty_slot_material = ShaderMaterial.new()
		_empty_slot_material.shader = _get_empty_slot_shader()
		_empty_slot_material.resource_local_to_scene = true
	_empty_slot_material.set_shader_parameter("slot_seed", float(posmod(int(get_instance_id()) * 29 + 11, 997)) / 997.0)
	_empty_slot_effect.material = _empty_slot_material


func _is_empty_field_slot() -> bool:
	return card_data == null and not _face_down and (display_mode == MODE_SLOT_ACTIVE or display_mode == MODE_SLOT_BENCH)


static func _get_card_foil_shader() -> Shader:
	if _foil_shader != null:
		return _foil_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float foil_intensity = 1.0;
uniform float foil_seed = 0.0;

void fragment() {
	vec4 base = COLOR;
	vec4 final_color = base;
	if (base.a > 0.01 && foil_intensity > 0.001) {
		float t = TIME + foil_seed * 8.0;
		float sweep_axis = UV.x * 0.62 + UV.y * 1.18;
		float sweep_center = fract(t * 0.135);
		float sweep_distance = abs(fract(sweep_axis - sweep_center + 0.5) - 0.5);
		float sweep = smoothstep(0.40, 0.0, sweep_distance);
		float core = smoothstep(0.16, 0.0, sweep_distance);
		float shimmer = 0.5 + 0.5 * sin((UV.x - UV.y + foil_seed) * 18.0 + TIME * 1.2);

		vec3 foil_light = mix(vec3(1.0, 0.94, 0.74), vec3(0.76, 0.92, 1.0), shimmer * 0.32);
		float highlight = (sweep * 0.20 + core * 0.08) * foil_intensity;
		vec3 result = base.rgb + foil_light * highlight;

		float edge = smoothstep(0.0, 0.035, UV.x) * smoothstep(0.0, 0.035, UV.y) * smoothstep(0.0, 0.035, 1.0 - UV.x) * smoothstep(0.0, 0.035, 1.0 - UV.y);
		final_color = vec4(mix(base.rgb, min(result, vec3(1.0)), edge), base.a);
	}
	COLOR = final_color;
}
"""
	_foil_shader = shader
	return _foil_shader


static func _get_empty_slot_shader() -> Shader:
	if _empty_slot_shader != null:
		return _empty_slot_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float slot_seed = 0.0;

void fragment() {
	vec2 center = UV - vec2(0.5);
	float t = TIME * 0.75 + slot_seed * 6.28318;
	float oval = length(center * vec2(0.82, 1.16));
	float pulse = 0.62 + 0.38 * sin(t);
	float ring_radius = 0.34 + 0.014 * sin(t * 0.8);
	float ring = smoothstep(0.032, 0.0, abs(oval - ring_radius));
	float core = smoothstep(0.44, 0.0, oval) * 0.18;
	float diagonal = smoothstep(0.020, 0.0, abs(fract((UV.x + UV.y) * 1.85 - t * 0.08) - 0.5)) * 0.08;
	float edge = max(
		max(smoothstep(0.035, 0.0, UV.x), smoothstep(0.035, 0.0, 1.0 - UV.x)),
		max(smoothstep(0.035, 0.0, UV.y), smoothstep(0.035, 0.0, 1.0 - UV.y))
	) * 0.18;
	float alpha = ring * (0.20 + 0.12 * pulse) + core + diagonal + edge;
	vec3 color = mix(vec3(0.18, 0.62, 0.72), vec3(0.62, 0.88, 0.92), pulse * 0.35);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.34));
}
"""
	_empty_slot_shader = shader
	return _empty_slot_shader


func _update_overlay_visibility() -> void:
	if _status_hud == null or _info_panel == null:
		return
	if _battle_status_active:
		_status_hud.visible = true
		_info_panel.visible = false
		return
	_status_hud.visible = false
	_info_panel.visible = _title_label.visible or _subtitle_label.visible


func _update_battle_status_ui() -> void:
	if _status_hud == null:
		return

	var hp_current := int(_battle_status.get("hp_current", 0))
	var hp_max := maxi(int(_battle_status.get("hp_max", 0)), 1)
	var hp_ratio := clampf(float(_battle_status.get("hp_ratio", float(hp_current) / float(hp_max))), 0.0, 1.0)
	_status_used_panel.visible = bool(_battle_status.get("ability_used_this_turn", false))
	_status_hp_value_label.text = "%d/%d" % [hp_current, hp_max]
	_status_hp_bar.value = hp_ratio * 100.0

	var status_icons_raw: Variant = _battle_status.get("status_icons", [])
	var status_total: int = 0
	if status_icons_raw is Array:
		status_total = (status_icons_raw as Array).size()

	var energy_icons_raw: Variant = _battle_status.get("energy_icons", [])
	var energy_total: int = 0
	if energy_icons_raw is Array:
		energy_total = (energy_icons_raw as Array).size()

	var tool_name := str(_battle_status.get("tool_name", ""))
	_status_tool_label.text = tool_name
	_status_condition_panel.visible = status_total > 0
	_status_energy_panel.visible = energy_total > 0
	_status_tool_panel.visible = tool_name != ""

	_clear_children(_status_condition_row)
	for status_key_variant: Variant in status_icons_raw:
		var status_key := str(status_key_variant)
		_status_condition_row.add_child(_make_status_condition_icon(status_key, status_total))

	_clear_children(_status_energy_row)
	var energy_marker_count := maxi(energy_total, 1)
	var energy_marker_size := _energy_marker_icon_size(energy_marker_count)
	_status_energy_row.add_theme_constant_override("separation", _energy_marker_separation(energy_marker_count))
	_status_energy_row.custom_minimum_size = Vector2(0, energy_marker_size)
	for energy_icon_variant: Variant in energy_icons_raw:
		_status_energy_row.add_child(_make_energy_icon(energy_icon_variant, energy_total))
	_apply_responsive_status_metrics()
	_apply_card_input_filters()


func _update_implementation_badge() -> void:
	if _implementation_badge_panel == null:
		return
	var show_badge := card_data != null and not _face_down and CardImplementationStatusScript.is_unimplemented(card_data)
	_implementation_badge_panel.visible = show_badge
	if show_badge:
		var reason := CardImplementationStatusScript.get_reason(card_data)
		_implementation_badge_panel.tooltip_text = "未实现效果" if reason == "" else "未实现效果：%s" % reason
	else:
		_implementation_badge_panel.tooltip_text = ""


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _make_energy_icon(energy_icon: Variant, energy_count: int = 1) -> Control:
	var energy_code := _energy_icon_code(energy_icon)
	var provided_count := _energy_icon_provided_count(energy_icon)
	var icon_size := _energy_marker_icon_size(energy_count)
	var texture: Texture2D = ENERGY_ICON_TEXTURES.get(energy_code, null)
	if texture != null:
		var rect := EnergyIconControl.new()
		_make_passthrough(rect)
		rect.set_meta("energy_icon_slot", true)
		rect.set_meta("energy_provided_count", provided_count)
		rect.texture = texture
		rect.custom_minimum_size = Vector2(icon_size, icon_size)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if provided_count <= 1:
			return rect

		var slot := Control.new()
		_make_passthrough(slot)
		slot.set_meta("energy_icon_slot", true)
		slot.set_meta("energy_provided_count", provided_count)
		slot.custom_minimum_size = Vector2(icon_size, icon_size)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.clip_contents = true
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.custom_minimum_size = Vector2.ZERO
		slot.add_child(rect)
		_add_energy_count_badge(slot, provided_count, icon_size)
		return slot

	var chip := Label.new()
	_make_passthrough(chip)
	chip.set_meta("energy_label_chip", true)
	chip.set_meta("energy_provided_count", provided_count)
	chip.text = energy_code if provided_count <= 1 else "%s×%d" % [energy_code, provided_count]
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.custom_minimum_size = Vector2(icon_size, icon_size)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_font_size_override("font_size", maxi(7, roundi(float(icon_size) * 0.72)))
	return chip


func _energy_icon_code(energy_icon: Variant) -> String:
	if energy_icon is Dictionary:
		var data := energy_icon as Dictionary
		var code := str(data.get("code", "C"))
		return code if code != "" else "C"
	var code := str(energy_icon)
	return code if code != "" else "C"


func _energy_icon_provided_count(energy_icon: Variant) -> int:
	if energy_icon is Dictionary:
		var data := energy_icon as Dictionary
		return maxi(int(data.get("count", 1)), 1)
	return 1


func _add_energy_count_badge(slot: Control, provided_count: int, icon_size: int) -> void:
	if slot == null or provided_count <= 1:
		return
	var badge := Label.new()
	_make_passthrough(badge)
	badge.set_meta("energy_count_badge", true)
	badge.text = "×%d" % provided_count
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(maxi(1, roundi(float(icon_size) * 0.72)), maxi(1, roundi(float(icon_size) * 0.52)))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.size_flags_vertical = Control.SIZE_SHRINK_END
	badge.add_theme_font_size_override("font_size", maxi(1, roundi(float(icon_size) * 0.48)))
	badge.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.07, 0.95))
	badge.add_theme_constant_override("outline_size", 2)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -badge.custom_minimum_size.x
	badge.offset_top = -badge.custom_minimum_size.y
	badge.offset_right = 0.0
	badge.offset_bottom = 0.0
	slot.add_child(badge)


func _make_status_condition_icon(status_key: String, status_count: int = 1) -> Control:
	var icon_size := _battle_marker_icon_size(status_count)
	var texture: Texture2D = STATUS_ICON_TEXTURES.get(status_key, null)
	if texture != null:
		var rect := TextureRect.new()
		_make_passthrough(rect)
		rect.texture = texture
		rect.custom_minimum_size = Vector2(icon_size, icon_size)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return rect

	var chip := Label.new()
	_make_passthrough(chip)
	chip.text = status_key.substr(0, 1).to_upper()
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.custom_minimum_size = Vector2(icon_size + 2, icon_size)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_font_size_override("font_size", maxi(7, roundi(float(icon_size) * 0.72)))
	return chip


func _status_ui_scale() -> float:
	var card_height := _status_card_height()
	if card_height <= 0.0:
		return 1.0
	return clampf(card_height / STATUS_REFERENCE_CARD_HEIGHT, 0.46, 1.9)


func _status_card_height() -> float:
	if _field_slot_layout_size.y > 0.0:
		return _field_slot_layout_size.y
	if custom_minimum_size.y > 0.0:
		return custom_minimum_size.y
	return size.y


func _status_card_width() -> float:
	if _field_slot_layout_size.x > 0.0:
		return _field_slot_layout_size.x
	if custom_minimum_size.x > 0.0:
		return custom_minimum_size.x
	return size.x


func _portrait_status_slot_height() -> float:
	return maxf(_status_card_height() / 5.0, 1.0)


func _status_overlay_available_height() -> float:
	var outer_pad := 0.0 if _compact_preview else 4.0
	var overlay_vertical_margin := 12.0
	return maxf(_status_card_height() - outer_pad * 2.0 - overlay_vertical_margin, 1.0)


func _visible_status_row_count() -> int:
	if not _battle_status_active:
		return 0
	var count := 1
	if _status_used_panel != null and _status_used_panel.visible:
		count += 1
	if _status_condition_panel != null and _status_condition_panel.visible:
		count += 1
	if _status_energy_panel != null and _status_energy_panel.visible:
		count += 1
	if _status_tool_panel != null and _status_tool_panel.visible:
		count += 1
	return count


func _effective_status_slot_height(base_slot_height: float) -> float:
	var visible_rows := maxi(_visible_status_row_count(), 1)
	var available_per_row := _status_overlay_available_height() / float(visible_rows)
	return maxf(minf(base_slot_height, available_per_row), 1.0)


func _status_vertical_margin_for_slot(slot_height: float) -> int:
	return clampi(roundi(slot_height * 0.08), 1, 8)


func _portrait_status_hp_font_size(hp_overlay_height: float) -> int:
	return clampi(roundi(hp_overlay_height * 0.66), 9, 48)


func _portrait_status_tool_font_size(slot_height: float, scale: float) -> int:
	var tool_margin_v := clampi(roundi(2.0 * scale), 1, 5)
	var height_limited_size := clampi(roundi(maxf(slot_height - float(tool_margin_v * 2), 1.0) * 0.58), 9, 44)
	if _status_tool_label == null or _status_tool_label.text == "":
		return height_limited_size
	var card_width := _status_card_width()
	if card_width <= 0.0:
		return height_limited_size
	var margin_h := clampi(roundi(8.0 * scale), 2, 14)
	var available_width := maxf(card_width - float(margin_h * 2), 1.0)
	var glyph_count := maxi(_status_tool_label.text.length(), 1)
	var width_limited_size := floori(available_width / (float(glyph_count) * 0.92))
	return clampi(mini(height_limited_size, width_limited_size), 9, 44)


func _status_label_font_variation(label: Label, embolden: float) -> void:
	if label == null:
		return
	var base_font := ThemeDB.get_fallback_font()
	var current_font := label.get_theme_font("font")
	if current_font is FontVariation:
		var current_variation := current_font as FontVariation
		if current_variation.base_font != null:
			base_font = current_variation.base_font
	elif current_font != null:
		base_font = current_font
	var font := FontVariation.new()
	font.base_font = base_font
	font.variation_embolden = embolden
	label.add_theme_font_override("font", font)


func _scaled_status_font_size(base_size: int, min_size: int, max_size: int) -> int:
	return clampi(roundi(float(base_size) * _status_text_scale), min_size, max_size)


func _status_row_height_multiplier() -> float:
	return 1.0


func _status_content_multiplier() -> float:
	return 1.0


func _status_base_hp_overlay_height() -> float:
	if _portrait_status_metrics_enabled:
		var slot_height := _effective_status_slot_height(_portrait_status_slot_height())
		return maxf(slot_height - float(_status_vertical_margin_for_slot(slot_height) * 2), 1.0)
	return clampf(16.0 * _status_ui_scale(), 8.0, 32.0)


func _status_hp_overlay_height() -> float:
	return _status_base_hp_overlay_height() * _status_row_height_multiplier()


func _status_icon_size() -> int:
	var hp_height := _status_base_hp_overlay_height()
	var target_size := minf(14.0 * _status_ui_scale(), hp_height - 4.0) * _status_content_multiplier()
	var max_size := 52 if _portrait_status_metrics_enabled else 26
	return clampi(roundi(target_size), 5, max_size)


func _battle_marker_icon_size(icon_count: int = 1) -> int:
	var count := maxi(icon_count, 1)
	var card_width := _status_card_width()
	var scale := _status_ui_scale()
	var margin_h := clampi(roundi(6.0 * scale), 2, 12)
	var separation := clampi(roundi(4.0 * scale), 2, 8)
	var base_size := roundi(float(_status_icon_size()) * 0.77)
	var max_size := 20
	if _portrait_status_metrics_enabled:
		var slot_height := _effective_status_slot_height(_portrait_status_slot_height())
		var content_height := maxf(slot_height - float(_status_vertical_margin_for_slot(slot_height) * 2), 1.0)
		base_size = _scaled_status_font_size(_portrait_status_hp_font_size(content_height), 7, 48)
		max_size = 48
	if card_width <= 0.0:
		return clampi(base_size, 4, max_size)
	var available_width := maxf(card_width - float(margin_h * 2) - float(maxi(count - 1, 0) * separation), 1.0)
	var fit_size := floori(available_width / float(count))
	return clampi(mini(base_size, fit_size), 4, max_size)


func _energy_marker_icon_size(icon_count: int = 1) -> int:
	var count := maxi(icon_count, 1)
	var base_size := _battle_marker_icon_size(1)
	var available_height := roundi(maxf(_status_base_hp_overlay_height(), 1.0))
	var card_width := _status_card_width()
	if card_width <= 0.0:
		return clampi(mini(base_size, available_height), 1, 48)
	var scale := _status_ui_scale()
	var margin_h := clampi(roundi(6.0 * scale), 2, 12)
	var separation := _energy_marker_separation(count)
	var layout_gap := maxi(separation, ENERGY_ROW_MINIMUM_LAYOUT_GAP)
	var available_width := maxf(card_width - float(margin_h * 2) - float(maxi(count - 1, 0) * layout_gap), 1.0)
	var fit_size := floori(available_width / float(count))
	return clampi(mini(mini(base_size, available_height), fit_size), 1, 48)


func _energy_marker_separation(icon_count: int = 1) -> int:
	var count := maxi(icon_count, 1)
	var scale := _status_ui_scale()
	var base_separation := clampi(roundi(2.0 * scale), 1, 6)
	if count <= 1:
		return base_separation
	var card_width := _status_card_width()
	if card_width <= 0.0:
		return base_separation
	var margin_h := clampi(roundi(6.0 * scale), 2, 12)
	var available_width := maxf(card_width - float(margin_h * 2), 1.0)
	var base_icon_size := _battle_marker_icon_size(1)
	if float(base_icon_size * count + base_separation * (count - 1)) > available_width:
		return 0
	var min_icon_size := 1.0
	var max_fit_separation := floori((available_width - min_icon_size * float(count)) / float(count - 1))
	return clampi(mini(base_separation, max_fit_separation), 0, base_separation)


func _apply_energy_icon_size_to_row(icon_size: int) -> void:
	if _status_energy_row == null:
		return
	for child: Node in _status_energy_row.get_children():
		var control := child as Control
		if control == null:
			continue
		if bool(control.get_meta("energy_label_chip", false)):
			control.custom_minimum_size = Vector2(icon_size, icon_size)
			if control is Label:
				(control as Label).add_theme_font_size_override("font_size", maxi(1, roundi(float(icon_size) * 0.72)))
		else:
			control.custom_minimum_size = Vector2(icon_size, icon_size)
		control.queue_redraw()
		for nested_child: Node in control.get_children():
			var nested_control := nested_child as Control
			if nested_control == null or not bool(nested_control.get_meta("energy_icon_slot", false)):
				continue
			nested_control.custom_minimum_size = Vector2.ZERO
			nested_control.queue_redraw()
		_resize_energy_count_badges(control, icon_size)


func _resize_energy_count_badges(control: Control, icon_size: int) -> void:
	if control == null:
		return
	for child: Node in control.get_children():
		var badge := child as Label
		if badge == null or not bool(badge.get_meta("energy_count_badge", false)):
			continue
		badge.custom_minimum_size = Vector2(maxi(1, roundi(float(icon_size) * 0.72)), maxi(1, roundi(float(icon_size) * 0.52)))
		badge.add_theme_font_size_override("font_size", maxi(1, roundi(float(icon_size) * 0.48)))
		badge.offset_left = -badge.custom_minimum_size.x
		badge.offset_top = -badge.custom_minimum_size.y
		badge.offset_right = 0.0
		badge.offset_bottom = 0.0


func _apply_responsive_status_metrics() -> void:
	if _status_hud == null:
		return
	var scale := _status_ui_scale()
	var height_multiplier := _status_row_height_multiplier()
	var content_multiplier := _status_content_multiplier()
	var margin_h := clampi(roundi(6.0 * scale), 2, 12)
	var margin_v := clampi(roundi(3.0 * scale), 1, 6)
	var portrait_slot_height := _portrait_status_slot_height()
	var effective_slot_height := portrait_slot_height
	if _portrait_status_metrics_enabled:
		effective_slot_height = _effective_status_slot_height(portrait_slot_height)
		margin_v = _status_vertical_margin_for_slot(effective_slot_height)
	var base_hp_overlay_height := _status_base_hp_overlay_height()
	var hp_overlay_height := base_hp_overlay_height * height_multiplier
	var base_icon_size := minf(14.0 * scale, base_hp_overlay_height - 4.0)
	var row_panel_height := (maxf(base_hp_overlay_height, base_icon_size) + float(margin_v * 2)) * height_multiplier
	var shared_tool_font_size := _scaled_status_font_size(clampi(roundi(9.0 * scale * content_multiplier), 6, 44), 5, 44)
	if _portrait_status_metrics_enabled:
		row_panel_height = effective_slot_height
		hp_overlay_height = maxf(effective_slot_height - float(margin_v * 2), 1.0)
		_status_hud.add_theme_constant_override("separation", 0)
		shared_tool_font_size = _scaled_status_font_size(_portrait_status_tool_font_size(effective_slot_height, scale), 7, 44)
	else:
		_status_hud.add_theme_constant_override("separation", clampi(roundi(3.0 * scale), 1, 7))
	if _status_used_label != null:
		_status_used_label.add_theme_font_size_override("font_size", shared_tool_font_size)
	if _status_hp_value_label != null:
		if _portrait_status_metrics_enabled:
			var hp_font_size := _scaled_status_font_size(_portrait_status_hp_font_size(hp_overlay_height), 7, 48)
			_status_hp_value_label.add_theme_font_size_override("font_size", hp_font_size)
			_status_hp_value_label.add_theme_constant_override("outline_size", clampi(roundi(float(hp_font_size) * 0.085), 2, 4))
			_status_hp_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.96))
			_status_label_font_variation(_status_hp_value_label, 1.62)
		else:
			_status_hp_value_label.add_theme_font_size_override("font_size", _scaled_status_font_size(clampi(roundi(12.0 * scale * content_multiplier), 7, 48), 6, 48))
			_status_hp_value_label.add_theme_constant_override("outline_size", 0)
			_status_label_font_variation(_status_hp_value_label, 1.2)
	if _status_tool_label != null:
		if _portrait_status_metrics_enabled:
			var tool_font_size := shared_tool_font_size
			_status_tool_label.add_theme_font_size_override("font_size", tool_font_size)
			_status_tool_label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.07, 1.0))
			_status_tool_label.add_theme_constant_override("outline_size", clampi(roundi(float(tool_font_size) * 0.06), 1, 3))
			_status_tool_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.94, 0.82))
			_status_label_font_variation(_status_tool_label, 0.0)
		else:
			_status_tool_label.add_theme_font_size_override("font_size", shared_tool_font_size)
			_status_tool_label.add_theme_constant_override("outline_size", 0)
			_status_label_font_variation(_status_tool_label, 0.0)
	if _status_condition_row != null:
		_status_condition_row.add_theme_constant_override("separation", clampi(roundi(2.0 * scale), 1, 6))
		_status_condition_row.custom_minimum_size = Vector2(0, _battle_marker_icon_size())
	if _status_energy_row != null:
		var energy_icon_count := maxi(_status_energy_row.get_child_count(), 1)
		var energy_icon_size := _energy_marker_icon_size(energy_icon_count)
		_status_energy_row.add_theme_constant_override("separation", _energy_marker_separation(energy_icon_count))
		_status_energy_row.custom_minimum_size = Vector2(0, energy_icon_size)
		_apply_energy_icon_size_to_row(energy_icon_size)
		_status_energy_row.update_minimum_size()
		_status_energy_row.queue_sort()
	var hp_overlay: Control = null
	if _status_hp_bar != null:
		hp_overlay = _status_hp_bar.get_parent() as Control
	if hp_overlay != null:
		hp_overlay.custom_minimum_size = Vector2(0, hp_overlay_height)
	if _status_hp_bar != null:
		_status_hp_bar.offset_top = margin_v
		_status_hp_bar.offset_bottom = -margin_v
	if _status_used_panel != null:
		_status_used_panel.custom_minimum_size = Vector2(0, row_panel_height)
	if _status_hp_bar_panel != null:
		_status_hp_bar_panel.custom_minimum_size = Vector2(0, row_panel_height)
	if _status_condition_panel != null:
		_status_condition_panel.custom_minimum_size = Vector2(0, row_panel_height)
	if _status_energy_panel != null:
		_status_energy_panel.custom_minimum_size = Vector2(0, row_panel_height)
	if _status_tool_panel != null:
		_status_tool_panel.custom_minimum_size = Vector2(0, row_panel_height)
	for panel_raw in [_status_used_panel, _status_hp_bar_panel, _status_condition_panel, _status_energy_panel]:
		var panel := panel_raw as PanelContainer
		var margin: MarginContainer = null
		if panel != null and panel.get_child_count() > 0:
			margin = panel.get_child(0) as MarginContainer
		if margin == null:
			continue
		margin.add_theme_constant_override("margin_left", margin_h)
		margin.add_theme_constant_override("margin_right", margin_h)
		margin.add_theme_constant_override("margin_top", margin_v)
		margin.add_theme_constant_override("margin_bottom", margin_v)
	var tool_margin: MarginContainer = null
	if _status_tool_panel != null and _status_tool_panel.get_child_count() > 0:
		tool_margin = _status_tool_panel.get_child(0) as MarginContainer
	if tool_margin != null:
		tool_margin.add_theme_constant_override("margin_left", clampi(roundi(8.0 * scale), 2, 14))
		tool_margin.add_theme_constant_override("margin_right", clampi(roundi(8.0 * scale), 2, 14))
		tool_margin.add_theme_constant_override("margin_top", clampi(roundi(2.0 * scale), 1, 5))
		tool_margin.add_theme_constant_override("margin_bottom", clampi(roundi(2.0 * scale), 1, 5))


func _update_style() -> void:
	if _info_panel == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 1.0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.set_border_width_all(2)
	style.border_color = Color(0.24, 0.3, 0.4)
	style.set_content_margin_all(2)
	if _is_empty_field_slot():
		style.bg_color = Color(0.06, 0.14, 0.17, 0.52)
		style.border_color = Color(0.36, 0.72, 0.80, 0.42)
		style.shadow_color = Color(0.10, 0.62, 0.76, 0.16)
		style.shadow_size = 7
		style.shadow_offset = Vector2.ZERO
	if _selected:
		style.bg_color = Color(0.13, 0.11, 0.05, 1.0)
		style.border_color = Color(1.0, 0.78, 0.10, 0.82)
		style.set_border_width_all(4)
		style.set_content_margin_all(4)
		style.shadow_color = Color(1.0, 0.70, 0.08, 0.32)
		style.shadow_size = 8
		style.shadow_offset = Vector2.ZERO
	elif _selectable_hint:
		style.bg_color = Color(0.04, 0.12, 0.16, 1.0)
		style.border_color = Color(0.28, 0.88, 1.0, 0.32)
		style.set_border_width_all(2)
		style.set_content_margin_all(2)
		style.shadow_color = Color(0.18, 0.78, 1.0, 0.10)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	if _disabled:
		style.border_color = Color(0.35, 0.35, 0.35)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _art_frame != null:
		_art_frame.add_theme_stylebox_override("panel", style)
	if _missing_art_panel != null:
		var missing_style := StyleBoxFlat.new()
		missing_style.bg_color = Color(0.95, 0.95, 0.9, 0.98)
		missing_style.border_color = Color(0.24, 0.28, 0.34, 0.88)
		missing_style.set_border_width_all(2)
		missing_style.set_corner_radius_all(12)
		_missing_art_panel.add_theme_stylebox_override("panel", missing_style)
	if _placeholder != null:
		_placeholder.modulate = Color(0.14, 0.15, 0.18) if _missing_art_panel != null and _missing_art_panel.visible else Color(0.92, 0.94, 0.98)
		_placeholder.add_theme_font_size_override("font_size", 14 if _missing_art_panel != null and _missing_art_panel.visible else 12)
	if _selection_overlay != null:
		_selection_overlay.visible = (_selected or _selectable_hint) and not _disabled
		var selection_style := StyleBoxFlat.new()
		if _selected:
			selection_style.bg_color = Color(1.0, 0.74, 0.08, 0.06)
			selection_style.border_color = Color(1.0, 0.88, 0.22, 0.72)
			selection_style.shadow_color = Color(1.0, 0.62, 0.02, 0.30)
			selection_style.set_border_width_all(3)
		else:
			selection_style.bg_color = Color(0.08, 0.86, 1.0, 0.025)
			selection_style.border_color = Color(0.25, 0.92, 1.0, 0.58)
			selection_style.shadow_color = Color(0.10, 0.74, 1.0, 0.16)
			selection_style.set_border_width_all(3)
		selection_style.set_corner_radius_all(14)
		selection_style.shadow_size = 10
		selection_style.shadow_offset = Vector2.ZERO
		_selection_overlay.add_theme_stylebox_override("panel", selection_style)
	if _selection_badge_panel != null:
		_selection_badge_panel.modulate = Color(1, 1, 1, 0.92 if _selected else 0.78)
		_selection_badge_panel.add_theme_stylebox_override("panel", _make_selection_badge_style(_selected))
	if _selection_badge != null:
		_selection_badge.text = _selected_badge_text if _selected else _selectable_hint_text
		_selection_badge.add_theme_color_override("font_color", Color(0.10, 0.06, 0.00, 1.0) if _selected else Color(0.01, 0.10, 0.14, 1.0))
	if _implementation_badge_panel != null:
		_implementation_badge_panel.add_theme_stylebox_override("panel", _make_unimplemented_badge_style())
	if _implementation_badge_label != null:
		_implementation_badge_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.66, 1.0))
		_implementation_badge_label.add_theme_constant_override("outline_size", 1)
		_implementation_badge_label.add_theme_color_override("font_outline_color", Color(0.10, 0.03, 0.00, 0.95))

	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.05, 0.07, 0.11, 0.78)
	overlay_style.corner_radius_top_left = 10
	overlay_style.corner_radius_top_right = 10
	overlay_style.corner_radius_bottom_right = 10
	overlay_style.corner_radius_bottom_left = 10
	_info_panel.add_theme_stylebox_override("panel", overlay_style)
	_apply_status_styles()

	modulate = Color(0.55, 0.55, 0.55) if _disabled else Color(1, 1, 1)
	if _texture_rect != null:
		_texture_rect.modulate = Color(0.8, 0.8, 0.8) if _disabled else Color(1, 1, 1)
	_apply_empty_slot_effect()


func _apply_status_styles() -> void:
	if _status_hp_bar_panel == null:
		return

	var used_style := StyleBoxFlat.new()
	used_style.bg_color = Color(0.05, 0.11, 0.18, 0.9)
	used_style.set_corner_radius_all(8)
	used_style.set_border_width_all(2)
	used_style.border_color = Color(0.2, 0.78, 0.96, 0.85)
	_status_used_panel.add_theme_stylebox_override("panel", used_style)
	_status_used_label.modulate = Color(0.82, 0.97, 1.0, 1.0)
	_status_used_label.add_theme_color_override("font_color", Color(0.82, 0.97, 1.0, 1.0))
	_status_used_label.add_theme_constant_override("outline_size", 1)
	_status_used_label.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.14, 0.95))

	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	strip_style.set_corner_radius_all(8)
	_status_energy_panel.add_theme_stylebox_override("panel", strip_style)
	var condition_style := StyleBoxFlat.new()
	condition_style.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	condition_style.set_corner_radius_all(8)
	_status_condition_panel.add_theme_stylebox_override("panel", condition_style)

	var tool_style := StyleBoxFlat.new()
	tool_style.bg_color = Color(0.94, 0.95, 0.9, 0.74)
	tool_style.set_corner_radius_all(8)
	_status_tool_panel.add_theme_stylebox_override("panel", tool_style)
	_status_tool_label.modulate = Color(0.1, 0.12, 0.14)
	_status_hp_value_label.modulate = Color(1, 1, 1)
	_status_hp_value_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	if not _portrait_status_metrics_enabled:
		_status_hp_value_label.add_theme_constant_override("outline_size", 0)

	var bar_panel_style := StyleBoxFlat.new()
	bar_panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.86)
	bar_panel_style.set_corner_radius_all(8)
	_status_hp_bar_panel.add_theme_stylebox_override("panel", bar_panel_style)

	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.15, 0.18, 0.22, 0.95)
	bar_background.set_corner_radius_all(4)
	_status_hp_bar.add_theme_stylebox_override("background", bar_background)

	var hp_ratio := clampf(float(_battle_status.get("hp_ratio", 1.0)), 0.0, 1.0)
	var fill_color := Color(0.24, 0.83, 0.42, 0.98)
	if hp_ratio <= 0.5:
		fill_color = Color(0.95, 0.76, 0.22, 0.98)
	if hp_ratio <= 0.2:
		fill_color = Color(0.92, 0.24, 0.2, 0.98)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = fill_color
	bar_fill.set_corner_radius_all(4)
	_status_hp_bar.add_theme_stylebox_override("fill", bar_fill)


func _apply_tilt() -> void:
	rotation_degrees = 0.0
	z_index = 20 if _selected else (10 if _selectable_hint else 0)
	if _art_frame == null:
		return
	_art_frame.rotation_degrees = 0.0


func _gui_input(event: InputEvent) -> void:
	_handle_card_pointer_input(event)


func _on_input_catcher_gui_input(event: InputEvent) -> void:
	_handle_card_pointer_input(event)


func _handle_card_pointer_input(event: InputEvent) -> void:
	if not _clickable:
		return
	var release_primary_click := display_mode == MODE_HAND or bool(get_meta("card_gallery_drag_input_enabled", false))
	if release_primary_click:
		hand_drag_input.emit(event)
	if _handle_touch_inspect_input(event):
		return
	if not release_primary_click and _handle_direct_touch_click_input(event):
		return
	if release_primary_click and _handle_hand_primary_click_input(event):
		return
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if not mbe.pressed:
			return
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if _suppress_next_left_click:
				_suppress_next_left_click = false
				accept_event()
				return
			left_clicked.emit(card_instance, card_data)
			accept_event()
		elif mbe.button_index == MOUSE_BUTTON_RIGHT:
			if _can_inspect_by_secondary_input():
				right_clicked.emit(card_instance, card_data)
				accept_event()


func _handle_hand_primary_click_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mbe.pressed:
			_hand_primary_press_active = true
			_hand_primary_press_start = _primary_click_event_position(event)
			_hand_primary_press_cancelled = false
			_hand_primary_press_from_touch = false
			clear_primary_release_fallback()
			accept_event()
			return true
		if _hand_primary_press_active:
			var cancelled := _hand_primary_press_cancelled
			_hand_primary_press_active = false
			_hand_primary_press_cancelled = false
			_hand_primary_press_from_touch = false
			if cancelled:
				accept_event()
				return true
			if _suppress_next_left_click:
				_suppress_next_left_click = false
				accept_event()
				return true
			left_clicked.emit(card_instance, card_data)
			accept_event()
			return true
		if _consume_primary_release_fallback():
			left_clicked.emit(card_instance, card_data)
			accept_event()
			return true
		return false

	if event is InputEventMouseMotion and _hand_primary_press_active:
		_update_hand_primary_click_motion(_primary_click_event_position(event))
		return false

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_hand_primary_press_active = true
			_hand_primary_press_start = touch.position
			_hand_primary_press_cancelled = false
			_hand_primary_press_from_touch = true
			clear_primary_release_fallback()
			accept_event()
			return true
		if _hand_primary_press_active:
			var cancelled := _hand_primary_press_cancelled
			_hand_primary_press_active = false
			_hand_primary_press_cancelled = false
			_hand_primary_press_from_touch = false
			if cancelled:
				accept_event()
				return true
			if _suppress_next_left_click:
				_suppress_next_left_click = false
				accept_event()
				return true
			left_clicked.emit(card_instance, card_data)
			accept_event()
			return true
		if _consume_primary_release_fallback():
			left_clicked.emit(card_instance, card_data)
			accept_event()
			return true
		return false

	if event is InputEventScreenDrag and _hand_primary_press_active:
		_update_hand_primary_click_motion((event as InputEventScreenDrag).position)
		return false

	return false


func _handle_direct_touch_click_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_hand_primary_press_active = true
			_hand_primary_press_start = touch.position
			_hand_primary_press_cancelled = false
			_hand_primary_press_from_touch = true
			clear_primary_release_fallback()
			accept_event()
			return true
		if _hand_primary_press_active:
			var cancelled := _hand_primary_press_cancelled
			_hand_primary_press_active = false
			_hand_primary_press_cancelled = false
			_hand_primary_press_from_touch = false
			if cancelled:
				accept_event()
				return true
			if _suppress_next_left_click:
				_suppress_next_left_click = false
				accept_event()
				return true
			left_clicked.emit(card_instance, card_data)
			accept_event()
			return true
		return false

	if event is InputEventScreenDrag and _hand_primary_press_active:
		_update_hand_primary_click_motion((event as InputEventScreenDrag).position)
		return false

	return false


func _consume_primary_release_fallback() -> bool:
	var now := Time.get_ticks_msec()
	if _primary_release_fallback_until_msec <= 0:
		return false
	if now < _primary_release_fallback_ready_at_msec:
		return false
	if now > _primary_release_fallback_until_msec:
		clear_primary_release_fallback()
		return false
	clear_primary_release_fallback()
	return true


func _update_hand_primary_click_motion(position: Vector2) -> void:
	var delta := position - _hand_primary_press_start
	if bool(get_meta("card_gallery_drag_input_enabled", false)):
		# Card galleries scroll horizontally. Vertical touch jitter on phones should not
		# cancel a card tap unless it is clearly no longer a tap.
		var horizontal_tolerance := CARD_GALLERY_TOUCH_CLICK_MOVE_TOLERANCE if _hand_primary_press_from_touch else HAND_PRIMARY_CLICK_MOVE_TOLERANCE
		if absf(delta.x) > horizontal_tolerance or absf(delta.y) > CARD_GALLERY_VERTICAL_CLICK_TOLERANCE:
			_hand_primary_press_cancelled = true
		return
	if delta.length() > HAND_PRIMARY_CLICK_MOVE_TOLERANCE:
		_hand_primary_press_cancelled = true


func _primary_click_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).global_position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.ZERO


func _handle_touch_inspect_input(event: InputEvent) -> bool:
	if not _can_inspect_by_secondary_input():
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_start_touch_long_press(touch.position, touch.index)
		else:
			if _touch_long_press_active and touch.index == _touch_long_press_index:
				var consumed := _touch_long_press_consumed
				_cancel_touch_long_press(false)
				if consumed:
					_hand_primary_press_active = false
					_hand_primary_press_cancelled = false
					_hand_primary_press_from_touch = false
					accept_event()
				return consumed
		return false

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touch_long_press_active and drag.index == _touch_long_press_index:
			if drag.position.distance_to(_touch_long_press_start) > TOUCH_LONG_PRESS_MOVE_TOLERANCE:
				_cancel_touch_long_press()
		return false

	return false


func _can_inspect_by_secondary_input() -> bool:
	return card_data != null and (display_mode == MODE_HAND or _secondary_inspect_enabled)


func _start_touch_long_press(position: Vector2, touch_index: int) -> void:
	if not _can_inspect_by_secondary_input():
		return
	_ensure_touch_long_press_timer()
	_touch_long_press_active = true
	_touch_long_press_index = touch_index
	_touch_long_press_start = position
	_touch_long_press_consumed = false
	if _touch_long_press_timer.is_inside_tree():
		_touch_long_press_timer.start()


func _cancel_touch_long_press(clear_suppression: bool = true) -> void:
	if _touch_long_press_timer != null:
		_touch_long_press_timer.stop()
	_touch_long_press_active = false
	_touch_long_press_index = -1
	_touch_long_press_consumed = false
	if clear_suppression:
		_suppress_next_left_click = false


func _on_touch_long_press_timeout() -> void:
	if not _touch_long_press_active or not _clickable or not _can_inspect_by_secondary_input():
		return
	_touch_long_press_consumed = true
	_suppress_next_left_click = true
	right_clicked.emit(card_instance, card_data)
	accept_event()
