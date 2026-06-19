extends Control

const CARD_IMAGE_DOWNLOADER := preload("res://scripts/network/CardImageDownloader.gd")
const DeckSuggestionClientScript := preload("res://scripts/network/DeckSuggestionClient.gd")
const DeckRecommendationStoreScript := preload("res://scripts/engine/DeckRecommendationStore.gd")
const DeckViewDialogScript := preload("res://scripts/ui/decks/DeckViewDialog.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

const CARD_TILE_WIDTH := 100
const CARD_TILE_HEIGHT := 140
const VIEW_GRID_COLUMNS := 6
const RENAME_DIALOG_SIZE := Vector2i(460, 230)
const COMMUNITY_DATA_PATH := "res://community/data/community-data.json"
const DECK_CENTER_META_STATE_PATH := "user://deck_center_meta_state.json"
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const HUD_DANGER := Color(1.0, 0.28, 0.22, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)
const HUD_FRAME_BORDER := Color(0.76, 0.90, 1.0, 0.96)
const HUD_CARD_BORDER := Color(0.48, 0.72, 1.0, 0.78)
const HUD_RECOMMENDATION_BORDER := Color(1.0, 0.76, 0.30, 0.96)
const HUD_SECONDARY := Color(0.50, 0.80, 1.0, 1.0)
const HUD_RENAME := Color(0.72, 0.64, 1.0, 1.0)
const IMPORT_RESULT_AUTO_CLOSE_SECONDS := 1.4
const REMOTE_RECOMMENDATION_PREFETCH_STEPS := 0
const DECK_CENTER_SCROLLBAR_RIGHT_CLEARANCE := 40
const RECOMMENDATION_DETAIL_SCROLLBAR_RIGHT_CLEARANCE := 34
const HUD_BUTTON_FONT_SIZE := 23
const HUD_BUTTON_COMPACT_FONT_SIZE := 21
const HUD_BUTTON_MIN_HEIGHT := 63.0
const HUD_BUTTON_COMPACT_MIN_HEIGHT := 57.0
const HUD_BUTTON_TEXT_HORIZONTAL_PADDING := 34.0
const REMOTE_RECOMMENDATION_BATCH_LIMIT := 20
const IMPORT_DECK_GUIDE_TEXT := "导入步骤：\n1. 在浏览器打开 tcg.mik.moe，进入你想玩的卡组页面。\n2. 复制浏览器地址栏里的完整链接，例如 https://tcg.mik.moe/decks/list/574793。\n3. 回到这里，点击下面的输入框并粘贴链接；也可以只输入末尾数字 ID，例如 574793。\n4. 点“导入卡组”，等待卡组和卡图同步完成。"
const IMPORT_MODAL_PREVIOUS_MOUSE_FILTER_META := "_import_modal_previous_mouse_filter"
const IMPORT_URL_FOCUS_REQUESTED_META := "_import_url_focus_requested"
const DECK_ACTION_HUD_DIALOG_NAME := "DeckActionHudDialog"

const ENERGY_TYPE_LABELS: Dictionary = {
	"R": "火", "W": "水", "G": "草", "L": "雷",
	"P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无色",
}

var _importer: DeckImporter = null
var _image_syncer = null
var _current_operation: String = ""
var _panel_mode: String = "import"
var _pending_import_start_url := ""
var _pending_import_deck: DeckData = null
var _pending_import_errors: PackedStringArray = PackedStringArray()
var _pending_import_deck_name_override := ""
var _rename_dialog: AcceptDialog = null
var _rename_input: LineEdit = null
var _rename_error_label: Label = null
var _rename_confirm_button: Button = null
var _rename_target_deck: DeckData = null
var _rename_ignore_deck_id: int = -1
var _rename_context: String = ""
var _rename_forced: bool = false
var _deck_action_hud_overlay: Control = null
var _deck_action_hud_panel: PanelContainer = null
var _deck_action_hud_context: String = ""
var _texture_cache: Dictionary = {}
var _failed_texture_paths: Dictionary = {}
var _deck_view_dialog: RefCounted = DeckViewDialogScript.new()
var _recommendation_client: Node = null
var _recommendation_fetch_in_progress := false
var _recommendation_fetch_reason := ""
var _recommendation_prefetch_remaining := 0
var _recommendation_prefetch_seen_ids: Dictionary = {}
var _recommendation_remote_order_batch := 0
var _pending_remote_recommendation_id := ""
var _recommendation_store: RefCounted = null
var _recommendation_articles: Array[Dictionary] = []
var _embedded_recommendations: Array[Dictionary] = []
var _current_recommendation: Dictionary = {}
var _deck_center_latest_meta: Dictionary = {}
var _deck_center_recommendation_badge_seen_revision := ""
var _recommendation_section: VBoxContainer = null
var _recommendation_feed: VBoxContainer = null
var _recommendation_status_label: Label = null
var _recommendation_next_button: Button = null
var _recommendation_detail_overlay: Control = null
var _import_result_close_timer: Timer = null
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _current_non_battle_layout_context: Dictionary = {}


func _ready() -> void:
	_apply_hud_theme()
	_connect_non_battle_layout_signal()
	_setup_deck_recommendations()
	%BtnImport.pressed.connect(_on_import_pressed)
	%BtnSyncImages.pressed.connect(_on_sync_images_pressed)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnDoImport.pressed.connect(_on_do_import)
	%BtnCloseImport.pressed.connect(_on_close_import)
	_ensure_import_paste_button()
	_setup_import_panel_input_guards()

	CardDatabase.decks_changed.connect(_refresh_deck_list)
	_refresh_deck_list()

	_importer = DeckImporter.new()
	add_child(_importer)
	_importer.import_progress.connect(_on_import_progress)
	_importer.import_completed.connect(_on_import_completed)
	_importer.import_failed.connect(_on_import_failed)

	_image_syncer = CARD_IMAGE_DOWNLOADER.new()
	add_child(_image_syncer)
	_image_syncer.progress.connect(_on_image_sync_progress)
	_image_syncer.completed.connect(_on_image_sync_completed)
	_image_syncer.failed.connect(_on_image_sync_failed)
	call_deferred("_apply_non_battle_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_non_battle_layout()


func _input(event: InputEvent) -> void:
	if _is_deck_action_hud_dialog_visible():
		if NonBattleTouchBridgeScript.handle_root_touch(_deck_action_hud_overlay, event):
			return
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			accept_event()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
	if _is_import_panel_visible():
		var import_panel := get_node_or_null("%ImportPanel") as Control
		if import_panel != null and NonBattleTouchBridgeScript.handle_root_touch(import_panel, event):
			return
		if _handle_import_panel_modal_input(event):
			return
		return
	NonBattleTouchBridgeScript.handle_root_touch(self, event)


func _setup_import_panel_input_guards() -> void:
	_ensure_import_paste_button()
	var modal_controls: Array[Control] = [
		get_node_or_null("%ImportPanel") as Control,
		find_child("ImportBg", true, false) as Control,
		find_child("ImportBox", true, false) as Control,
	]
	var modal_callback := Callable(self, "_on_import_modal_gui_input")
	for control: Control in modal_controls:
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		if control.gui_input.is_connected(modal_callback):
			control.gui_input.disconnect(modal_callback)
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input != null:
		_configure_import_feedback_line_edit(url_input)


func _ensure_import_paste_button() -> Button:
	var existing := find_child("BtnPasteImport", true, false) as Button
	if existing != null:
		return existing
	var button_row := find_child("BtnRow", true, false) as HBoxContainer
	if button_row == null:
		return null
	var paste_button := Button.new()
	paste_button.name = "BtnPasteImport"
	paste_button.unique_name_in_owner = true
	paste_button.text = "粘贴链接"
	paste_button.custom_minimum_size = Vector2(120, 35)
	paste_button.pressed.connect(_on_paste_import_url)
	button_row.add_child(paste_button)
	button_row.move_child(paste_button, 0)
	_style_hud_button(paste_button, HUD_ACCENT_WARM)
	NonBattleTouchBridgeScript.bind_button_touch(paste_button)
	return paste_button


func _on_import_modal_gui_input(event: InputEvent) -> void:
	_handle_import_modal_gui_input(event)


func _handle_import_modal_gui_input_for_tests(event: InputEvent) -> bool:
	return _handle_import_modal_gui_input(event)


func _handle_import_modal_gui_input(event: InputEvent) -> bool:
	if not _is_import_panel_visible():
		return false
	if _event_targets_import_url_input(event):
		return false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_consume_import_modal_event()
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_consume_import_modal_event()
			return true
	return false


func _configure_import_feedback_line_edit(input: LineEdit, keyboard_type: int = LineEdit.KEYBOARD_TYPE_URL) -> void:
	if input == null:
		return
	input.focus_mode = Control.FOCUS_ALL
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.context_menu_enabled = true
	input.virtual_keyboard_enabled = true
	input.virtual_keyboard_show_on_focus = true
	input.virtual_keyboard_type = keyboard_type
	input.set("shortcut_keys_enabled", true)
	input.set("middle_mouse_paste_enabled", true)
	if input.has_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META):
		input.remove_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META)
	NonBattleTouchBridgeScript.bind_focus_control_touch(input)


func _consume_import_modal_event() -> void:
	accept_event()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _show_import_panel() -> void:
	var import_panel := get_node_or_null("%ImportPanel") as Control
	if import_panel == null:
		return
	import_panel.visible = true
	import_panel.z_as_relative = false
	import_panel.z_index = 2500
	import_panel.move_to_front()
	_set_import_background_controls_blocked(true)


func _hide_import_panel() -> void:
	var import_panel := get_node_or_null("%ImportPanel") as Control
	if import_panel != null:
		import_panel.visible = false
	_set_import_background_controls_blocked(false)
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input != null and url_input.has_focus():
		url_input.release_focus()
	if DisplayServer.get_name() != "headless":
		DisplayServer.virtual_keyboard_hide()


func _set_import_background_controls_blocked(blocked: bool) -> void:
	var content_root := get_node_or_null("MarginContainer") as Control
	if content_root == null:
		return
	_set_control_tree_mouse_filter_blocked(content_root, blocked)


func _set_control_tree_mouse_filter_blocked(node: Node, blocked: bool) -> void:
	if node is Control:
		var control := node as Control
		if blocked:
			if not control.has_meta(IMPORT_MODAL_PREVIOUS_MOUSE_FILTER_META):
				control.set_meta(IMPORT_MODAL_PREVIOUS_MOUSE_FILTER_META, control.mouse_filter)
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif control.has_meta(IMPORT_MODAL_PREVIOUS_MOUSE_FILTER_META):
			control.mouse_filter = int(control.get_meta(IMPORT_MODAL_PREVIOUS_MOUSE_FILTER_META))
			control.remove_meta(IMPORT_MODAL_PREVIOUS_MOUSE_FILTER_META)
	for child: Node in node.get_children():
		_set_control_tree_mouse_filter_blocked(child, blocked)


func _connect_non_battle_layout_signal() -> void:
	if GameManager == null or not GameManager.has_signal("non_battle_layout_mode_changed"):
		return
	var callback := Callable(self, "_on_non_battle_layout_mode_changed")
	if not GameManager.non_battle_layout_mode_changed.is_connected(callback):
		GameManager.non_battle_layout_mode_changed.connect(callback)


func _on_non_battle_layout_mode_changed(_mode: String) -> void:
	_apply_non_battle_layout()
	_refresh_deck_list()
	call_deferred("_apply_non_battle_layout")


func _apply_non_battle_layout_for_tests(viewport_size: Vector2, mode: String) -> void:
	_apply_non_battle_layout(viewport_size, mode)


func _apply_non_battle_layout(viewport_size: Vector2 = Vector2.ZERO, forced_mode: String = "") -> void:
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	var mode := forced_mode
	if mode == "":
		mode = str(GameManager.get("non_battle_layout_mode")) if GameManager != null else "landscape"
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var context: Dictionary = _non_battle_layout_controller.call("build_context", size, mode, is_mobile)
	var portrait := bool(context.get("is_portrait", false))
	_current_non_battle_layout_context = context.duplicate(true)
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin != null:
		var value := int(context.get("page_margin", 24.0))
		margin.add_theme_constant_override("margin_left", value)
		margin.add_theme_constant_override("margin_top", value)
		margin.add_theme_constant_override("margin_right", value)
		margin.add_theme_constant_override("margin_bottom", value)
	_apply_deck_manager_mobile_metrics(self, context, portrait)
	_apply_import_panel_layout(context, portrait, size)
	_apply_deck_center_scroll_clearance()


func _handle_import_panel_modal_input_for_tests(event: InputEvent) -> bool:
	return _handle_import_panel_modal_input(event)


func _handle_import_panel_modal_input(event: InputEvent) -> bool:
	var import_panel := get_node_or_null("%ImportPanel") as Control
	if import_panel == null or not import_panel.visible:
		return false
	if event is InputEventMouseButton and not _should_bridge_import_panel_mouse_event():
		return false
	if _event_targets_import_url_input(event):
		return false
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		_consume_import_modal_event()
		return true
	var position := _event_global_position(event)
	if position.x == INF or position.y == INF:
		return false
	if _control_rect_with_layout_fallback(import_panel).has_point(position):
		_consume_import_modal_event()
		return true
	return false


func _is_import_panel_visible() -> bool:
	var import_panel := get_node_or_null("%ImportPanel") as Control
	return import_panel != null and import_panel.visible


func _event_targets_import_url_input(event: InputEvent) -> bool:
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input == null or not url_input.visible or not url_input.editable:
		return false
	var position := _event_global_position(event)
	if position.x == INF or position.y == INF:
		return false
	var rect := _control_rect_with_layout_fallback(url_input)
	var max_input_height := maxf(url_input.custom_minimum_size.y * 1.6, 160.0)
	if rect.size.y > max_input_height:
		rect.size.y = max_input_height
	return rect.has_point(position)


func _should_bridge_import_panel_mouse_event() -> bool:
	if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		return true
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _event_global_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return mouse_button.global_position if mouse_button.global_position != Vector2.ZERO else mouse_button.position
	return Vector2(INF, INF)


func _control_rect_with_layout_fallback(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var rect := control.get_global_rect()
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		return rect
	var fallback_size := control.size
	if fallback_size.x <= 0.0 or fallback_size.y <= 0.0:
		var context_size: Vector2 = _current_non_battle_layout_context.get("viewport_size", size if size.x > 0.0 and size.y > 0.0 else Vector2(1600, 900))
		fallback_size.x = maxf(fallback_size.x, context_size.x)
		fallback_size.y = maxf(fallback_size.y, context_size.y)
	return Rect2(control.global_position, fallback_size)


func _apply_import_panel_layout(context: Dictionary, portrait: bool, viewport_size: Vector2) -> void:
	var import_panel := get_node_or_null("%ImportPanel") as Control
	var import_bg := find_child("ImportBg", true, false) as Control
	var import_box := find_child("ImportBox", true, false) as PanelContainer
	if import_panel != null:
		import_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		import_panel.z_as_relative = false
		import_panel.z_index = 1000
		import_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if import_bg != null:
		import_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		import_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if import_box == null:
		return
	import_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := import_box.get_node_or_null("VBox") as VBoxContainer
	var title_label := import_box.get_node_or_null("VBox/TitleLabel") as Label
	var hint_label := import_box.get_node_or_null("VBox/HintLabel") as Label
	var progress_label := get_node_or_null("%ProgressLabel") as Label
	var progress_bar := get_node_or_null("%ProgressBar") as ProgressBar
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	var button_row := import_box.get_node_or_null("VBox/BtnRow") as HBoxContainer
	var paste_button := _ensure_import_paste_button()
	var import_button := get_node_or_null("%BtnDoImport") as Button
	var close_button := get_node_or_null("%BtnCloseImport") as Button
	if hint_label != null:
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if progress_label != null:
		progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if url_input != null:
		_configure_import_feedback_line_edit(url_input)
	if not portrait:
		import_box.anchor_left = 0.5
		import_box.anchor_top = 0.5
		import_box.anchor_right = 0.5
		import_box.anchor_bottom = 0.5
		import_box.custom_minimum_size = Vector2(500, 260)
		import_box.offset_left = -250.0
		import_box.offset_right = 250.0
		import_box.offset_top = -130.0
		import_box.offset_bottom = 130.0
		if vbox != null:
			vbox.add_theme_constant_override("separation", 10)
		if hint_label != null:
			hint_label.custom_minimum_size.y = 0.0
			hint_label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
		if progress_label != null:
			progress_label.custom_minimum_size.y = 0.0
			progress_label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
		if url_input != null:
			url_input.custom_minimum_size = Vector2(0.0, 38.0)
			url_input.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
		if progress_bar != null:
			progress_bar.custom_minimum_size.y = 0.0
		if button_row != null:
			button_row.add_theme_constant_override("separation", 20)
		for button: Button in [paste_button, import_button, close_button]:
			if button == null:
				continue
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.custom_minimum_size.y = HUD_BUTTON_MIN_HEIGHT
			button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(HUD_BUTTON_FONT_SIZE))
		return

	var margin := float(context.get("page_margin", 24.0))
	var input_height := float(context.get("input_height", 98.0))
	var box_width := maxf(320.0, viewport_size.x - margin * 2.0)
	var box_height := maxf(560.0, viewport_size.y - margin * 2.0)
	import_box.anchor_left = 0.0
	import_box.anchor_top = 0.0
	import_box.anchor_right = 1.0
	import_box.anchor_bottom = 1.0
	import_box.custom_minimum_size = Vector2(box_width, box_height)
	import_box.offset_left = margin
	import_box.offset_right = -margin
	import_box.offset_top = margin
	import_box.offset_bottom = -margin

	var section_gap := int(context.get("section_gap", 22))
	var title_font := int(context.get("title_font_size", 44))
	var body_font := int(context.get("body_font_size", 27))
	var input_font := int(context.get("input_font_size", 29))
	var button_font := int(context.get("button_font_size", 33))
	var button_height := maxf(float(context.get("secondary_button_height", 104.0)), input_height)
	var portrait_input_height := maxf(input_height * 1.32, 128.0)
	if vbox != null:
		vbox.add_theme_constant_override("separation", section_gap)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", title_font)
	if hint_label != null:
		hint_label.add_theme_font_size_override("font_size", body_font)
		hint_label.custom_minimum_size.y = maxf(hint_label.custom_minimum_size.y, float(body_font) * 9.2)
		hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if progress_label != null:
		progress_label.add_theme_font_size_override("font_size", body_font)
		progress_label.custom_minimum_size.y = maxf(progress_label.custom_minimum_size.y, float(body_font) * 2.0)
	if url_input != null:
		url_input.custom_minimum_size = Vector2(maxf(260.0, box_width - margin), maxf(url_input.custom_minimum_size.y, portrait_input_height))
		url_input.add_theme_font_size_override("font_size", input_font)
		url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_configure_import_feedback_line_edit(url_input)
	if progress_bar != null:
		progress_bar.custom_minimum_size.y = maxf(progress_bar.custom_minimum_size.y, input_height * 0.36)
	if button_row != null:
		button_row.add_theme_constant_override("separation", maxi(16, roundi(float(section_gap) * 0.78)))
	for button: Button in [paste_button, import_button, close_button]:
		if button == null:
			continue
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, button_height)
		button.add_theme_font_size_override("font_size", button_font)
		NonBattleTouchBridgeScript.bind_button_touch(button)


func _apply_deck_manager_mobile_metrics(node: Node, context: Dictionary, portrait: bool) -> void:
	if node is Button:
		var button := node as Button
		var height := float(context.get("secondary_button_height", 57.0)) if portrait else button.custom_minimum_size.y
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, height)
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", HUD_BUTTON_FONT_SIZE)) if portrait else button.get_theme_font_size("font_size"))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	elif node is LineEdit:
		var input := node as LineEdit
		input.custom_minimum_size.y = maxf(input.custom_minimum_size.y, float(context.get("input_height", 38.0)))
		input.add_theme_font_size_override("font_size", int(context.get("input_font_size", 15)))
	elif node is Label:
		var label := node as Label
		if label.name in ["Title", "TitleLabel"]:
			label.add_theme_font_size_override("font_size", int(context.get("title_font_size", 32)) if portrait else HudThemeScript.scaled_font_size(32))
	for child: Node in node.get_children():
		_apply_deck_manager_mobile_metrics(child, context, portrait)


func _apply_hud_theme() -> void:
	var shade := get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_ensure_hud_frame()
	_style_hud_labels_recursive(self)
	for button_name: String in ["BtnImport", "BtnSyncImages", "BtnBack", "BtnPasteImport", "BtnDoImport", "BtnCloseImport"]:
		var button := get_node_or_null("%" + button_name) as Button
		if button != null:
			var accent := HUD_ACCENT
			if button_name in ["BtnImport", "BtnPasteImport", "BtnDoImport"]:
				accent = HUD_ACCENT_WARM
			elif button_name in ["BtnSyncImages", "BtnCloseImport"]:
				accent = HUD_SECONDARY
			_style_hud_button(button, accent)
	var import_box := find_child("ImportBox", true, false) as PanelContainer
	if import_box != null:
		import_box.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.92), HUD_FRAME_BORDER, 20))
	var import_bg := find_child("ImportBg", true, false) as ColorRect
	if import_bg != null:
		import_bg.color = Color(0.0, 0.0, 0.0, 0.42)
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input != null:
		_style_hud_line_edit(url_input)
	var empty_label := get_node_or_null("%EmptyLabel") as Label
	if empty_label != null:
		empty_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	HudThemeScript.apply_scrollbars_recursive(self)
	_apply_deck_center_scroll_clearance()


func _apply_deck_center_scroll_clearance() -> void:
	var deck_scroll := find_child("DeckScroll", true, false) as ScrollContainer
	if deck_scroll != null:
		deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var portrait := str(get_meta("non_battle_layout_mode", "")) == "portrait"
		if portrait:
			HudThemeScript.style_scroll_container(deck_scroll, "auto")
			NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(deck_scroll)
		else:
			deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
			HudThemeScript.style_scroll_container(deck_scroll, "auto")
			NonBattleTouchBridgeScript.configure_visible_vertical_scroll(deck_scroll)
			var vbar := deck_scroll.get_v_scroll_bar()
			if vbar != null:
				NonBattleTouchBridgeScript.bind_range_touch(vbar)
	var deck_scroll_margin := find_child("DeckScrollMargin", true, false) as MarginContainer
	if deck_scroll_margin != null:
		var portrait := str(get_meta("non_battle_layout_mode", "")) == "portrait"
		var clearance := 18 if portrait else DECK_CENTER_SCROLLBAR_RIGHT_CLEARANCE
		deck_scroll_margin.add_theme_constant_override("margin_right", clearance)


func _ensure_hud_frame() -> void:
	if get_node_or_null("HudFrame") != null:
		return
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return
	var frame := PanelContainer.new()
	frame.name = "HudFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_mode = margin.layout_mode
	frame.anchors_preset = margin.anchors_preset
	frame.anchor_left = margin.anchor_left
	frame.anchor_top = margin.anchor_top
	frame.anchor_right = margin.anchor_right
	frame.anchor_bottom = margin.anchor_bottom
	frame.offset_left = margin.offset_left + 8
	frame.offset_top = margin.offset_top + 8
	frame.offset_right = margin.offset_right - 8
	frame.offset_bottom = margin.offset_bottom - 8
	frame.grow_horizontal = margin.grow_horizontal
	frame.grow_vertical = margin.grow_vertical
	frame.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.72), HUD_FRAME_BORDER, 24))
	add_child(frame)
	move_child(frame, margin.get_index())


func _style_hud_labels_recursive(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.name in ["Title", "TitleLabel"]:
			label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(32))
			label.add_theme_color_override("font_color", HUD_TEXT)
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
			label.add_theme_constant_override("shadow_offset_y", 2)
		else:
			label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	for child: Node in node.get_children():
		_style_hud_labels_recursive(child)


func _hud_panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.34)
	style.shadow_size = 14
	style.set_content_margin_all(10)
	return style


func _hud_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base := Color(0.016, 0.046, 0.066, 0.94)
	var accent_fill := Color(accent.r, accent.g, accent.b, 0.94)
	style.bg_color = base.lerp(accent_fill, 0.20)
	if hover and not pressed:
		style.bg_color = base.lerp(accent_fill, 0.34)
	if pressed:
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.border_color = Color(accent.r, accent.g, accent.b, 1.0 if hover or pressed else 0.88)
	style.set_border_width_all(3 if hover or pressed else 2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.36 if hover or pressed else 0.20)
	style.shadow_size = 12 if hover or pressed else 7
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _style_hud_button(button: Button, accent: Color, compact: bool = false) -> void:
	var font_size := HudThemeScript.scaled_font_size(HUD_BUTTON_COMPACT_FONT_SIZE if compact else HUD_BUTTON_FONT_SIZE)
	var min_height := HUD_BUTTON_COMPACT_MIN_HEIGHT if compact else HUD_BUTTON_MIN_HEIGHT
	var min_width := _hud_button_min_width_for_text(button.text, font_size)
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, min_width), maxf(button.custom_minimum_size.y, min_height))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", _hud_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _hud_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _hud_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _hud_button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _hud_button_min_width_for_text(text: String, font_size: int) -> float:
	var units := 0.0
	for i: int in text.length():
		var code := text.unicode_at(i)
		if code <= 0x20:
			units += 0.35
		elif code < 0x80:
			units += 0.62
		else:
			units += 1.0
	return ceilf(units * float(font_size) + HUD_BUTTON_TEXT_HORIZONTAL_PADDING)


func _style_hud_line_edit(input: LineEdit) -> void:
	var keyboard_type := LineEdit.KEYBOARD_TYPE_URL if input.name == "UrlInput" else LineEdit.KEYBOARD_TYPE_DEFAULT
	_configure_import_feedback_line_edit(input, keyboard_type)
	input.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
	input.add_theme_color_override("font_color", HUD_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", HUD_ACCENT)
	input.add_theme_stylebox_override("normal", _hud_input_style(false))
	input.add_theme_stylebox_override("focus", _hud_input_style(true))


func _hud_input_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.055, 0.88)
	if hover:
		style.bg_color = Color(0.025, 0.075, 0.105, 0.94)
	style.border_color = Color(0.23, 0.78, 1.0, 0.70 if hover else 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _setup_deck_recommendations() -> void:
	_recommendation_store = DeckRecommendationStoreScript.new()
	_recommendation_store.call("load_cache")
	_recommendation_articles = _load_recommendation_articles()
	_embedded_recommendations = _normalize_recommendation_articles(_recommendation_articles)
	_current_recommendation = _select_initial_recommendation()
	_deck_center_latest_meta = _load_deck_center_latest_meta()
	_ensure_recommendation_client()
	_ensure_recommendation_section()
	_request_latest_remote_recommendation_on_open()


func _load_deck_center_latest_meta() -> Dictionary:
	var root := _load_deck_center_meta_state()
	var recommendation_seen_revision := str(root.get("last_recommendation_badge_seen_revision", "")).strip_edges()
	var entrance_seen_revision := str(root.get("last_seen_revision", "")).strip_edges()
	var latest_raw: Variant = root.get("latest_info", {})
	if latest_raw is Dictionary:
		var latest_meta := (latest_raw as Dictionary).duplicate(true)
		var latest_revision := str(latest_meta.get("latest_revision", "")).strip_edges()
		if recommendation_seen_revision == "" and latest_revision != "" and entrance_seen_revision == latest_revision:
			recommendation_seen_revision = entrance_seen_revision
		_deck_center_recommendation_badge_seen_revision = recommendation_seen_revision
		return latest_meta
	var root_latest_revision := str(root.get("latest_revision", "")).strip_edges()
	if recommendation_seen_revision == "" and root_latest_revision != "" and entrance_seen_revision == root_latest_revision:
		recommendation_seen_revision = entrance_seen_revision
	_deck_center_recommendation_badge_seen_revision = recommendation_seen_revision
	return root.duplicate(true)


func _load_deck_center_meta_state() -> Dictionary:
	if not FileAccess.file_exists(DECK_CENTER_META_STATE_PATH):
		return {}
	var raw_text := FileAccess.get_file_as_string(DECK_CENTER_META_STATE_PATH)
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _save_deck_center_meta_state(state: Dictionary) -> void:
	var file := FileAccess.open(DECK_CENTER_META_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()


func _ensure_recommendation_client() -> void:
	if _recommendation_client != null and is_instance_valid(_recommendation_client):
		return
	_recommendation_client = DeckSuggestionClientScript.new()
	_recommendation_client.name = "DeckSuggestionClient"
	_recommendation_client.fetch_succeeded.connect(_on_remote_recommendation_succeeded)
	_recommendation_client.fetch_failed.connect(_on_remote_recommendation_failed)
	add_child(_recommendation_client)


func _load_recommendation_articles() -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	if not FileAccess.file_exists(COMMUNITY_DATA_PATH):
		return articles

	var raw_text := FileAccess.get_file_as_string(COMMUNITY_DATA_PATH)
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is not Dictionary:
		return articles

	var root := parsed as Dictionary
	var briefing_raw: Variant = root.get("environment_briefing", {})
	var briefing: Dictionary = briefing_raw if briefing_raw is Dictionary else {}
	var source_articles_raw: Variant = briefing.get("articles", [])
	var source_articles: Array = source_articles_raw if source_articles_raw is Array else []
	if source_articles.is_empty():
		var single_article: Variant = briefing.get("article", {})
		if single_article is Dictionary:
			source_articles.append(single_article)

	for article_raw: Variant in source_articles:
		if article_raw is not Dictionary:
			continue
		var article := article_raw as Dictionary
		if _extract_recommendation_import_url(article) == "":
			continue
		articles.append(article)

	articles.sort_custom(_compare_recommendation_articles)
	return articles


func _normalize_recommendation_articles(articles: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for article: Dictionary in articles:
		var normalized: Dictionary = DeckRecommendationStoreScript.normalize_embedded_article(article)
		if not normalized.is_empty():
			result.append(normalized)
	return result


func _select_initial_recommendation() -> Dictionary:
	var fallback: Dictionary = {}
	if _recommendation_store != null:
		fallback = (_recommendation_store.call("get_current_or_fallback", _embedded_recommendations) as Dictionary)
	elif not _embedded_recommendations.is_empty():
		fallback = _embedded_recommendations[0].duplicate(true)

	var pool := _combined_recommendation_pool()
	if pool.is_empty():
		return fallback

	var fallback_id := str(fallback.get("id", "")).strip_edges()
	if fallback_id != "":
		for item: Dictionary in pool:
			if str(item.get("id", "")).strip_edges() == fallback_id:
				return item.duplicate(true)
	return (pool[0] as Dictionary).duplicate(true)


func _compare_recommendation_articles(a: Dictionary, b: Dictionary) -> bool:
	var source_a := _as_dictionary(a.get("source", {}))
	var source_b := _as_dictionary(b.get("source", {}))
	var date_a := str(source_a.get("date", "")).replace(".", "")
	var date_b := str(source_b.get("date", "")).replace(".", "")
	if date_a != date_b:
		return date_a > date_b
	return int(source_a.get("players", 0)) > int(source_b.get("players", 0))


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _ensure_recommendation_section() -> void:
	var deck_list_container := get_node_or_null("%DeckList") as VBoxContainer
	if deck_list_container == null:
		return
	if _recommendation_section != null and is_instance_valid(_recommendation_section):
		return

	_recommendation_section = VBoxContainer.new()
	_recommendation_section.name = "RecommendationSection"
	_recommendation_section.add_theme_constant_override("separation", 10)
	deck_list_container.add_child(_recommendation_section)
	deck_list_container.move_child(_recommendation_section, 0)

	_recommendation_feed = VBoxContainer.new()
	_recommendation_feed.name = "RecommendationFeed"
	_recommendation_feed.add_theme_constant_override("separation", 8)
	_recommendation_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recommendation_section.add_child(_recommendation_feed)

	_recommendation_status_label = Label.new()
	_recommendation_status_label.name = "RecommendationStatusLabel"
	_recommendation_status_label.text = ""
	_recommendation_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_recommendation_status_label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(12))
	_recommendation_status_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	_recommendation_section.add_child(_recommendation_status_label)


func _refresh_recommendation_cards() -> void:
	_ensure_recommendation_section()
	if _recommendation_section == null or _recommendation_feed == null:
		return

	for child: Node in _recommendation_feed.get_children():
		_recommendation_feed.remove_child(child)
		child.queue_free()
	_recommendation_next_button = null

	if _current_recommendation.is_empty() and _recommendation_store != null:
		_current_recommendation = (_recommendation_store.call("get_current_or_fallback", _embedded_recommendations) as Dictionary)

	_recommendation_section.visible = true
	if _current_recommendation.is_empty():
		_recommendation_feed.add_child(_create_recommendation_placeholder())
		if _recommendation_next_button != null:
			_recommendation_next_button.disabled = _recommendation_ui_blocked_by_fetch()
		return

	var should_mark_recommendation_badge_seen := _recommendation_matches_deck_center_latest(_current_recommendation)
	_recommendation_feed.add_child(_create_recommendation_feed_card(_current_recommendation))
	if should_mark_recommendation_badge_seen:
		_mark_deck_center_recommendation_badge_seen(false)
	if _recommendation_next_button != null:
		var fetch_blocks_ui := _recommendation_ui_blocked_by_fetch()
		_recommendation_next_button.disabled = fetch_blocks_ui or _current_operation != ""
		_recommendation_next_button.text = "获取中..." if fetch_blocks_ui else "换一套"


func _create_recommendation_placeholder() -> PanelContainer:
	var portrait := _is_deck_manager_portrait_layout()
	var context := _current_non_battle_layout_context
	var panel := PanelContainer.new()
	panel.name = "RecommendationFeedCard"
	panel.custom_minimum_size = Vector2(0, maxf(120.0, float(context.get("list_item_min_height", 120.0)) * 1.5) if portrait else 120.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.030, 0.070, 0.098, 0.92), HUD_RECOMMENDATION_BORDER, 16))
	var label := Label.new()
	label.text = "暂时没有可展示的推荐卡组。你仍然可以手动导入卡组。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
	label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	panel.add_child(label)
	return panel


func _create_recommendation_feed_card(recommendation: Dictionary) -> PanelContainer:
	var portrait := _is_deck_manager_portrait_layout()
	var context := _current_non_battle_layout_context
	var body_font := int(context.get("body_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15)
	var meta_font := int(context.get("meta_font_size", 12)) if portrait else HudThemeScript.scaled_font_size(12)
	var section_font := int(context.get("section_font_size", 17)) if portrait else HudThemeScript.scaled_font_size(17)
	var title_font := int(context.get("title_font_size", 23)) if portrait else HudThemeScript.scaled_font_size(23)
	var panel := PanelContainer.new()
	panel.name = "RecommendationFeedCard"
	panel.custom_minimum_size = Vector2(0, maxf(420.0, float(context.get("list_item_min_height", 260.0)) * 1.52) if portrait else 260.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.030, 0.070, 0.098, 0.94), HUD_RECOMMENDATION_BORDER, 18))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(context.get("section_gap", 9)) if portrait else 9)
	panel.add_child(vbox)

	var deck_name := str(recommendation.get("deck_name", "推荐卡组"))
	var title_text := str(recommendation.get("title", deck_name))
	var style_summary := str(recommendation.get("style_summary", ""))
	var source_text := _recommendation_source_text(recommendation)
	var import_url := str(recommendation.get("import_url", ""))
	var deck_id := int(recommendation.get("deck_id", 0))

	var meta := Label.new()
	meta.text = source_text
	meta.add_theme_font_size_override("font_size", meta_font)
	meta.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	vbox.add_child(meta)

	var deck_label := Label.new()
	deck_label.name = "RecommendationDeckName"
	deck_label.text = deck_name
	deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	deck_label.add_theme_font_size_override("font_size", title_font)
	deck_label.add_theme_color_override("font_color", HUD_TEXT)

	var deck_header := HBoxContainer.new()
	deck_header.name = "RecommendationDeckHeader"
	deck_header.add_theme_constant_override("separation", 8)
	deck_header.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(deck_header)
	deck_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_header.add_child(deck_label)
	if _recommendation_matches_deck_center_latest(recommendation):
		deck_header.add_child(_create_recommendation_new_badge())

	var title := Label.new()
	title.name = "RecommendationTitle"
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", section_font)
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	vbox.add_child(title)

	if style_summary != "":
		var summary_label := Label.new()
		summary_label.text = style_summary
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		summary_label.add_theme_font_size_override("font_size", body_font)
		summary_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.96, 1.0))
		vbox.add_child(summary_label)

	var why_title := Label.new()
	why_title.name = "RecommendationWhyTitle"
	why_title.text = "为什么值得玩"
	why_title.add_theme_font_size_override("font_size", body_font)
	why_title.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	vbox.add_child(why_title)

	var why_items: Array = recommendation.get("why_play", [])
	for bullet_raw: Variant in why_items:
		var bullet := str(bullet_raw).strip_edges()
		if bullet == "":
			continue
		var bullet_label := Label.new()
		bullet_label.text = "• " + bullet
		bullet_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		bullet_label.add_theme_font_size_override("font_size", body_font)
		bullet_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
		vbox.add_child(bullet_label)

	var best_for := str(recommendation.get("best_for", "")).strip_edges()
	if best_for != "":
		vbox.add_child(_create_recommendation_line("适合谁", best_for))

	var pilot_tip := str(recommendation.get("pilot_tip", "")).strip_edges()
	if pilot_tip != "":
		vbox.add_child(_create_recommendation_line("上手看点", pilot_tip))

	var button_row := HBoxContainer.new()
	button_row.name = "RecommendationActionRow"
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	var button_spacer := Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(button_spacer)

	_recommendation_next_button = Button.new()
	_recommendation_next_button.name = "RecommendationNextButton"
	var fetch_blocks_ui := _recommendation_ui_blocked_by_fetch()
	_recommendation_next_button.text = "获取中..." if fetch_blocks_ui else "换一套"
	_recommendation_next_button.custom_minimum_size = Vector2(112, 42)
	_recommendation_next_button.disabled = fetch_blocks_ui or _current_operation != ""
	_recommendation_next_button.pressed.connect(_on_recommendation_next_pressed)
	button_row.add_child(_recommendation_next_button)
	_style_hud_button(_recommendation_next_button, HUD_SECONDARY)
	_apply_recommendation_button_mobile_metrics(_recommendation_next_button)

	var import_button := Button.new()
	import_button.name = "RecommendationImportButton"
	import_button.text = "更新本地" if deck_id > 0 and CardDatabase.has_deck(deck_id) else "导入这套"
	import_button.custom_minimum_size = Vector2(124, 42)
	import_button.disabled = import_url == "" or _current_operation != "" or fetch_blocks_ui
	import_button.pressed.connect(_on_recommendation_import_pressed.bind(recommendation))
	button_row.add_child(import_button)
	_style_hud_button(import_button, HUD_ACCENT_WARM)
	_apply_recommendation_button_mobile_metrics(import_button)

	var read_button := Button.new()
	read_button.name = "RecommendationDetailButton"
	read_button.text = "查看完整解读"
	read_button.custom_minimum_size = Vector2(150, 42)
	read_button.pressed.connect(_on_recommendation_read_pressed.bind(recommendation))
	button_row.add_child(read_button)
	_style_hud_button(read_button, HUD_ACCENT)
	_apply_recommendation_button_mobile_metrics(read_button)

	return panel


func _is_deck_manager_portrait_layout() -> bool:
	if str(get_meta("non_battle_layout_mode", "")) == "portrait":
		return true
	if bool(_current_non_battle_layout_context.get("is_portrait", false)):
		return true
	if GameManager != null and str(GameManager.get("non_battle_layout_mode")) == "portrait":
		return true
	var viewport_size := get_viewport_rect().size if is_inside_tree() else size
	var mobile_like := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return mobile_like and viewport_size.y > viewport_size.x


func _deck_manager_portrait_scale() -> float:
	return float(_current_non_battle_layout_context.get("portrait_scale", 1.0)) if _is_deck_manager_portrait_layout() else 1.0


func _apply_recommendation_button_mobile_metrics(button: Button) -> void:
	if button == null or not _is_deck_manager_portrait_layout():
		return
	var context := _current_non_battle_layout_context
	var height := maxf(145.0, float(context.get("secondary_button_height", 96.0)) * 0.86)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, height)
	button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 32)))
	NonBattleTouchBridgeScript.bind_button_touch(button)


func _recommendation_ui_blocked_by_fetch() -> bool:
	if not _recommendation_fetch_in_progress:
		return false
	return not (_recommendation_fetch_reason in ["prefetch", "cycle_background"])


func _recommendation_matches_deck_center_latest(recommendation: Dictionary) -> bool:
	if _deck_center_latest_meta.is_empty():
		return false
	var latest_revision := str(_deck_center_latest_meta.get("latest_revision", "")).strip_edges()
	if latest_revision != "" and latest_revision == _deck_center_recommendation_badge_seen_revision:
		return false
	var latest_recommendation_id := str(_deck_center_latest_meta.get("latest_recommendation_id", "")).strip_edges()
	var recommendation_id := str(recommendation.get("id", "")).strip_edges()
	if latest_recommendation_id != "" and recommendation_id != "" and latest_recommendation_id == recommendation_id:
		return true

	var latest_deck_id := int(_deck_center_latest_meta.get("latest_deck_id", 0))
	var recommendation_deck_id := int(recommendation.get("deck_id", 0))
	return latest_deck_id > 0 and latest_deck_id == recommendation_deck_id


func _mark_deck_center_recommendation_badge_seen(remove_visible_badges: bool = true) -> void:
	var revision := str(_deck_center_latest_meta.get("latest_revision", "")).strip_edges()
	if revision == "":
		return
	if revision == _deck_center_recommendation_badge_seen_revision:
		if remove_visible_badges:
			_remove_recommendation_new_badges()
		return
	var state := _load_deck_center_meta_state()
	state["last_recommendation_badge_seen_revision"] = revision
	state["last_recommendation_badge_seen_at"] = int(Time.get_unix_time_from_system())
	state["last_seen_revision"] = revision
	state["last_seen_at"] = int(state.get("last_recommendation_badge_seen_at", Time.get_unix_time_from_system()))
	if not _deck_center_latest_meta.is_empty():
		state["latest_info"] = _deck_center_latest_meta.duplicate(true)
	_save_deck_center_meta_state(state)
	_deck_center_recommendation_badge_seen_revision = revision
	if remove_visible_badges:
		_remove_recommendation_new_badges()


func _remove_recommendation_new_badges() -> void:
	for badge: Node in find_children("RecommendationNewBadge", "PanelContainer", true, false):
		if badge == null or not is_instance_valid(badge):
			continue
		var parent := badge.get_parent()
		if parent != null:
			parent.remove_child(badge)
		badge.queue_free()


func _create_recommendation_new_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "RecommendationNewBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(52, 24)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.83, 0.20, 0.96)
	style.border_color = Color(1.0, 1.0, 1.0, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "RecommendationNewBadgeText"
	label.text = "NEW"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(11))
	label.add_theme_color_override("font_color", Color(0.14, 0.08, 0.02, 1.0))
	badge.add_child(label)
	return badge


func _create_recommendation_line(label_text: String, body_text: String) -> VBoxContainer:
	var portrait := _is_deck_manager_portrait_layout()
	var context := _current_non_battle_layout_context
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", maxi(2, int(float(context.get("portrait_scale", 1.0)) * 4.0)) if portrait else 2)
	var title := Label.new()
	title.text = label_text
	title.add_theme_font_size_override("font_size", int(context.get("body_font_size", 14)) if portrait else HudThemeScript.scaled_font_size(14))
	title.add_theme_color_override("font_color", HUD_ACCENT)
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
	body.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	box.add_child(body)
	return box


func _recommendation_available_count() -> int:
	return _combined_recommendation_pool().size()


func _recommendation_exclude_ids(extra_id: String = "") -> PackedStringArray:
	var ids := PackedStringArray()
	var seen := {}
	_append_recommendation_id_value(ids, seen, extra_id)
	_append_recommendation_id(ids, seen, _current_recommendation)
	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		for cached_raw: Variant in cached_items:
			if cached_raw is Dictionary:
				_append_recommendation_id(ids, seen, cached_raw as Dictionary)
	for embedded: Dictionary in _embedded_recommendations:
		_append_recommendation_id(ids, seen, embedded)
	return ids


func _prefetch_recommendation_exclude_ids() -> PackedStringArray:
	var seen := {}
	var ids := PackedStringArray()
	_append_recommendation_id(ids, seen, _current_recommendation)
	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		for cached_raw: Variant in cached_items:
			if cached_raw is not Dictionary:
				continue
			var cached := cached_raw as Dictionary
			if int(cached.get("server_order_batch", -1)) == _recommendation_remote_order_batch:
				_append_recommendation_id(ids, seen, cached)
	for embedded: Dictionary in _embedded_recommendations:
		_append_recommendation_id(ids, seen, embedded)
	for item_id: String in ids:
		seen[item_id] = true
	for seen_id: Variant in _recommendation_prefetch_seen_ids.keys():
		_append_recommendation_id_value(ids, seen, str(seen_id))
	return ids


func _append_recommendation_id(ids: PackedStringArray, seen: Dictionary, recommendation: Dictionary) -> void:
	_append_recommendation_id_value(ids, seen, str(recommendation.get("id", "")))


func _append_recommendation_id_value(ids: PackedStringArray, seen: Dictionary, raw_id: String) -> void:
	var item_id := raw_id.strip_edges()
	if item_id == "" or seen.has(item_id):
		return
	seen[item_id] = true
	ids.append(item_id)


func _recommendation_source_text(recommendation: Dictionary) -> String:
	var source := _as_dictionary(recommendation.get("source", {}))
	var parts: PackedStringArray = []
	var label := str(source.get("label", "")).strip_edges()
	if label == "":
		label = "卡组推荐"
	parts.append(label)
	var date_text := str(source.get("date", "")).strip_edges()
	if date_text != "":
		parts.append(date_text)
	var players := int(source.get("players", 0))
	if players > 0:
		parts.append("%d人样本" % players)
	var generated_at := str(recommendation.get("generated_at", "")).strip_edges()
	if date_text == "" and generated_at != "":
		parts.append(generated_at)
	return " · ".join(parts)


func _normalize_recommendation_input(item: Dictionary) -> Dictionary:
	var normalized: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(item)
	if normalized.is_empty():
		normalized = DeckRecommendationStoreScript.normalize_embedded_article(item)
	return normalized


func _set_recommendation_status(message: String) -> void:
	if _recommendation_status_label == null or not is_instance_valid(_recommendation_status_label):
		return
	_recommendation_status_label.text = message


func _on_recommendation_next_pressed() -> void:
	if _current_operation != "":
		_set_recommendation_status("当前正在导入或同步，完成后再切换推荐。")
		return
	if _recommendation_fetch_in_progress and _recommendation_ui_blocked_by_fetch():
		_set_recommendation_status("推荐数据加载中，完成后再切换。")
		return
	_switch_to_local_next_recommendation("已切换本地推荐。")


func _request_latest_remote_recommendation_on_open() -> void:
	if not is_inside_tree() or _recommendation_fetch_in_progress:
		return
	_start_remote_recommendation_request(
		"",
		"deck_manager_open_refresh",
		"正在加载服务器最新卡组推荐...",
		"open_refresh",
		PackedStringArray(),
		true,
		REMOTE_RECOMMENDATION_BATCH_LIMIT
	)


func _start_remote_recommendation_request(
	current_id: String,
	source: String,
	status_message: String,
	reason: String,
	exclude_ids: PackedStringArray = PackedStringArray(),
	refresh_on_start: bool = true,
	limit: int = 1
) -> bool:
	_ensure_recommendation_client()
	if _recommendation_client == null:
		return false
	_recommendation_fetch_in_progress = true
	_recommendation_fetch_reason = reason
	if status_message != "":
		_set_recommendation_status(status_message)
	if refresh_on_start:
		_refresh_recommendation_cards()
	var request_exclude_ids := exclude_ids
	if request_exclude_ids.size() == 0 and reason != "open_refresh":
		request_exclude_ids = _recommendation_exclude_ids(current_id)
	var request_limit := limit
	if reason == "open_refresh" and request_limit <= 1:
		request_limit = REMOTE_RECOMMENDATION_BATCH_LIMIT
	var err: int = _recommendation_client.call("fetch_next_recommendation", current_id, request_exclude_ids, {
		"source": source,
		"limit": request_limit,
	})
	if err != OK:
		_recommendation_fetch_in_progress = false
		_recommendation_fetch_reason = ""
		if refresh_on_start:
			_refresh_recommendation_cards()
		return false
	return true


func _request_remote_recommendation(background: bool = false) -> bool:
	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	return _start_remote_recommendation_request(
		current_id,
		"deck_manager_background_refresh" if background else "deck_manager_recommendation",
		"" if background else "正在从服务器获取新的卡组推荐...",
		"cycle_background" if background else "cycle",
		PackedStringArray(),
		not background
	)


func _begin_remote_recommendation_prefetch() -> void:
	if not is_inside_tree() or _recommendation_fetch_in_progress:
		return
	if _recommendation_client == null:
		return
	_recommendation_prefetch_remaining = REMOTE_RECOMMENDATION_PREFETCH_STEPS
	_recommendation_prefetch_seen_ids = {}
	_request_next_remote_recommendation_prefetch()


func _request_next_remote_recommendation_prefetch() -> void:
	if _recommendation_prefetch_remaining <= 0 or _recommendation_fetch_in_progress:
		return
	_recommendation_prefetch_remaining -= 1
	var started := _start_remote_recommendation_request(
		"",
		"deck_manager_prefetch",
		"",
		"prefetch",
		_prefetch_recommendation_exclude_ids(),
		false
	)
	if not started:
		_recommendation_prefetch_remaining = 0
		_refresh_recommendation_cards()


func _switch_to_local_next_recommendation(status_message: String) -> bool:
	if _recommendation_store == null:
		_recommendation_store = DeckRecommendationStoreScript.new()
		_recommendation_store.call("load_cache")

	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	var pool := _combined_recommendation_pool()
	var next_recommendation := _select_pending_remote_recommendation_from_pool(pool, current_id)
	if next_recommendation.is_empty():
		next_recommendation = _select_next_recommendation_from_pool(pool, current_id)
	if next_recommendation.is_empty() or str(next_recommendation.get("id", "")) == current_id and _recommendation_available_count() <= 1:
		_set_recommendation_status("暂时没有更多推荐，本地会保留当前这一套。")
		return false

	var normalized := _normalize_recommendation_input(next_recommendation)
	if normalized.is_empty():
		_set_recommendation_status("下一套推荐数据不完整，已跳过。")
		return false

	_current_recommendation = normalized
	if str(normalized.get("id", "")).strip_edges() == _pending_remote_recommendation_id:
		_pending_remote_recommendation_id = ""
	_recommendation_store.call("upsert_item", normalized, true)
	_recommendation_store.call("save_cache")
	_set_recommendation_status(status_message)
	_refresh_recommendation_cards()
	return true


func _select_pending_remote_recommendation_from_pool(pool: Array[Dictionary], current_id: String) -> Dictionary:
	var pending_id := _pending_remote_recommendation_id.strip_edges()
	if pending_id == "":
		return {}
	if pending_id == current_id:
		_pending_remote_recommendation_id = ""
		return {}
	for item: Dictionary in pool:
		if str(item.get("id", "")).strip_edges() == pending_id:
			return item.duplicate(true)
	_pending_remote_recommendation_id = ""
	return {}


func _combined_recommendation_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var seen := {}
	var embedded_ids := {}
	for item: Dictionary in _embedded_recommendations:
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id != "":
			embedded_ids[item_id] = true

	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		var cached_candidates: Array[Dictionary] = []
		for cached_raw: Variant in cached_items:
			if cached_raw is not Dictionary:
				continue
			var cached := cached_raw as Dictionary
			var cached_id := str(cached.get("id", "")).strip_edges()
			if cached_id == "" or embedded_ids.has(cached_id):
				continue
			var normalized_cached := _normalize_recommendation_input(cached)
			if not normalized_cached.is_empty():
				cached_candidates.append(normalized_cached)
		for cached: Dictionary in _sort_recommendations_for_pool(cached_candidates):
			_append_recommendation_to_pool(pool, seen, cached)
	if not pool.is_empty():
		return pool

	for embedded: Dictionary in _embedded_recommendations:
		_append_recommendation_to_pool(pool, seen, embedded)

	if pool.is_empty() and not _current_recommendation.is_empty():
		_append_recommendation_to_pool(pool, seen, _current_recommendation)
	return pool


func _sort_recommendations_for_pool(items: Array[Dictionary]) -> Array[Dictionary]:
	var source := items.duplicate(true)
	var result: Array[Dictionary] = []
	while not source.is_empty():
		var best_index := 0
		for index: int in range(1, source.size()):
			if _recommendation_pool_item_before(source[index], source[best_index]):
				best_index = index
		result.append(source[best_index])
		source.remove_at(best_index)
	return result


func _recommendation_pool_item_before(left: Dictionary, right: Dictionary) -> bool:
	var left_batch := int(left.get("server_order_batch", -1))
	var right_batch := int(right.get("server_order_batch", -1))
	if left_batch != right_batch:
		return left_batch > right_batch
	var left_order := int(left.get("server_order", -1))
	var right_order := int(right.get("server_order", -1))
	if left_order >= 0 and right_order >= 0 and left_order != right_order:
		return left_order < right_order
	if left_order >= 0 and right_order < 0:
		return true
	if left_order < 0 and right_order >= 0:
		return false
	var left_key := _recommendation_sort_key(left)
	var right_key := _recommendation_sort_key(right)
	if left_key != right_key:
		return left_key > right_key
	return str(left.get("id", "")) < str(right.get("id", ""))


func _recommendation_sort_key(recommendation: Dictionary) -> String:
	var generated_at := str(recommendation.get("generated_at", "")).strip_edges()
	if generated_at != "":
		var datetime_text := generated_at.trim_suffix("Z")
		var plus_index := datetime_text.find("+")
		if plus_index >= 0:
			datetime_text = datetime_text.substr(0, plus_index)
		return datetime_text.replace(" ", "T")
	var source := _as_dictionary(recommendation.get("source", {}))
	var source_date := str(source.get("date", "")).strip_edges()
	if source_date != "":
		return "%sT00:00:00" % source_date.replace(".", "-").replace("/", "-")
	return ""


func _append_recommendation_to_pool(pool: Array[Dictionary], seen: Dictionary, recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	if normalized.is_empty():
		return
	var item_id := str(normalized.get("id", "")).strip_edges()
	if item_id == "" or seen.has(item_id):
		return
	seen[item_id] = true
	pool.append(normalized)


func _select_next_recommendation_from_pool(pool: Array[Dictionary], current_id: String) -> Dictionary:
	if pool.is_empty():
		return {}
	if current_id == "":
		return pool[0].duplicate(true)
	for index: int in pool.size():
		if str(pool[index].get("id", "")) != current_id:
			continue
		for step: int in range(1, pool.size() + 1):
			var next_index := (index + step) % pool.size()
			var next_item := pool[next_index]
			if str(next_item.get("id", "")) != current_id:
				return next_item.duplicate(true)
		return {}
	return pool[0].duplicate(true)


func _normalize_remote_recommendation_batch(raw_recommendations: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	_recommendation_remote_order_batch = _next_remote_order_batch()
	var server_order := 0
	for raw_item: Variant in raw_recommendations:
		if raw_item is not Dictionary:
			continue
		var normalized := _normalize_recommendation_input(raw_item as Dictionary)
		if normalized.is_empty():
			continue
		var item_id := str(normalized.get("id", "")).strip_edges()
		if item_id == "" or seen.has(item_id):
			continue
		seen[item_id] = true
		normalized["server_order_batch"] = _recommendation_remote_order_batch
		normalized["server_order"] = server_order
		server_order += 1
		result.append(normalized)
		if result.size() >= REMOTE_RECOMMENDATION_BATCH_LIMIT:
			break
	return result


func _handle_empty_remote_recommendation_response(fetch_reason: String) -> void:
	if fetch_reason == "cycle_background":
		return
	if fetch_reason == "prefetch":
		_recommendation_prefetch_remaining = 0
		_set_recommendation_status("已同步已可用的服务器推荐，可以继续换一套。")
		_refresh_recommendation_cards()
		return
	if fetch_reason == "open_refresh":
		_set_recommendation_status("服务器推荐数据不完整，已保留当前推荐。")
		_refresh_recommendation_cards()
		return
	_set_recommendation_status("服务器推荐数据不完整，已切回本地推荐。")
	_switch_to_local_next_recommendation("服务器推荐数据不完整，已切换本地推荐。")


func _handle_remote_recommendation_batch(fetch_reason: String, raw_recommendations: Array) -> void:
	var normalized_items := _normalize_remote_recommendation_batch(raw_recommendations)
	if normalized_items.is_empty():
		_handle_empty_remote_recommendation_response(fetch_reason)
		return

	if _recommendation_store == null:
		_recommendation_store = DeckRecommendationStoreScript.new()
		_recommendation_store.call("load_cache")

	for index: int in normalized_items.size():
		_recommendation_store.call("upsert_item", normalized_items[index], fetch_reason == "open_refresh" and index == 0)
	_recommendation_store.call("save_cache")

	if fetch_reason == "cycle_background":
		var background_id := str((normalized_items[0] as Dictionary).get("id", "")).strip_edges()
		var current_id := str(_current_recommendation.get("id", "")).strip_edges()
		if background_id != "" and background_id != current_id:
			_pending_remote_recommendation_id = background_id
			_set_recommendation_status("已准备好新的服务器推荐，点“换一套”查看。")
			_refresh_recommendation_cards()
		return

	if fetch_reason == "prefetch":
		for item: Dictionary in normalized_items:
			var prefetched_id := str(item.get("id", "")).strip_edges()
			if prefetched_id != "":
				_recommendation_prefetch_seen_ids[prefetched_id] = true
		_recommendation_prefetch_remaining = 0
		_set_recommendation_status("已同步更多服务器推荐，可以继续换一套。")
		_refresh_recommendation_cards()
		return

	_pending_remote_recommendation_id = ""
	_current_recommendation = (normalized_items[0] as Dictionary).duplicate(true)
	_recommendation_store.call("set_current_id", str(_current_recommendation.get("id", "")))
	_recommendation_store.call("save_cache")
	var count_text := str(normalized_items.size())
	_set_recommendation_status("已加载服务器推荐 %s 套，切换将直接使用本地缓存。" % count_text)
	_refresh_recommendation_cards()


func _on_remote_recommendation_succeeded(response: Dictionary) -> void:
	var fetch_reason := _recommendation_fetch_reason
	_recommendation_fetch_reason = ""
	_recommendation_fetch_in_progress = false
	if response.has("recommendations"):
		_handle_remote_recommendation_batch(fetch_reason, DeckSuggestionClientScript.extract_recommendations(response))
		return
	var raw_recommendation: Dictionary = DeckSuggestionClientScript.extract_recommendation(response)
	var normalized := _normalize_recommendation_input(raw_recommendation)
	if normalized.is_empty():
		_handle_empty_remote_recommendation_response(fetch_reason)
		return

	if _recommendation_store == null:
		_recommendation_store = DeckRecommendationStoreScript.new()
		_recommendation_store.call("load_cache")
	normalized = _apply_remote_recommendation_order(normalized, fetch_reason)

	if fetch_reason == "prefetch":
		var prefetched_id := str(normalized.get("id", "")).strip_edges()
		if prefetched_id != "":
			_recommendation_prefetch_seen_ids[prefetched_id] = true
		_recommendation_store.call("upsert_item", normalized, false)
		_recommendation_store.call("save_cache")
		if _recommendation_prefetch_remaining > 0:
			_request_next_remote_recommendation_prefetch()
		else:
			_set_recommendation_status("已同步更多服务器推荐，可以继续换一套。")
			_refresh_recommendation_cards()
		return

	if fetch_reason == "cycle_background":
		_recommendation_store.call("upsert_item", normalized, false)
		_recommendation_store.call("save_cache")
		var background_id := str(normalized.get("id", "")).strip_edges()
		var current_id := str(_current_recommendation.get("id", "")).strip_edges()
		if background_id != "" and background_id != current_id:
			_pending_remote_recommendation_id = background_id
			_set_recommendation_status("已准备好新的服务器推荐，点“换一套”查看。")
			_refresh_recommendation_cards()
		return

	if fetch_reason == "open_refresh":
		_pending_remote_recommendation_id = ""
		_current_recommendation = normalized
		_recommendation_store.call("upsert_item", normalized, true)
		_recommendation_store.call("save_cache")
		var latest_deck_name := str(normalized.get("deck_name", "最新卡组推荐"))
		_set_recommendation_status("已更新服务器推荐：%s。" % latest_deck_name)
		_refresh_recommendation_cards()
		return

	_recommendation_store.call("upsert_item", normalized, false)
	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	var next_recommendation := _select_next_recommendation_from_pool(_combined_recommendation_pool(), current_id)
	if next_recommendation.is_empty():
		_set_recommendation_status("服务器推荐已保存，但暂时没有可切换的下一套。")
		_recommendation_store.call("save_cache")
		_refresh_recommendation_cards()
		return

	_current_recommendation = next_recommendation
	_recommendation_store.call("upsert_item", next_recommendation, true)
	_recommendation_store.call("save_cache")
	var deck_name := str(next_recommendation.get("deck_name", "新卡组推荐"))
	_set_recommendation_status("已切换推荐：%s。" % deck_name)
	_refresh_recommendation_cards()


func _apply_remote_recommendation_order(recommendation: Dictionary, fetch_reason: String) -> Dictionary:
	var result := recommendation.duplicate(true)
	var item_id := str(result.get("id", "")).strip_edges()
	if item_id == "":
		return result
	if fetch_reason == "open_refresh" or _recommendation_remote_order_batch <= 0:
		_recommendation_remote_order_batch = _next_remote_order_batch()
	if fetch_reason == "open_refresh":
		result["server_order_batch"] = _recommendation_remote_order_batch
		result["server_order"] = 0
		return result
	var existing_order := _cached_recommendation_server_order(item_id)
	if existing_order >= 0:
		result["server_order_batch"] = _recommendation_remote_order_batch
		result["server_order"] = existing_order
		return result
	result["server_order_batch"] = _recommendation_remote_order_batch
	result["server_order"] = _next_remote_server_order(_recommendation_remote_order_batch)
	return result


func _next_remote_order_batch() -> int:
	var max_batch := 0
	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		for cached_raw: Variant in cached_items:
			if cached_raw is not Dictionary:
				continue
			max_batch = maxi(max_batch, int((cached_raw as Dictionary).get("server_order_batch", 0)))
	return maxi(int(Time.get_unix_time_from_system()), max_batch + 1)


func _cached_recommendation_server_order(recommendation_id: String) -> int:
	if _recommendation_store == null:
		return -1
	var cached_items: Array = _recommendation_store.call("get_items")
	for cached_raw: Variant in cached_items:
		if cached_raw is not Dictionary:
			continue
		var cached := cached_raw as Dictionary
		if str(cached.get("id", "")).strip_edges() == recommendation_id:
			return int(cached.get("server_order", -1))
	return -1


func _next_remote_server_order(batch: int) -> int:
	var max_order := -1
	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		for cached_raw: Variant in cached_items:
			if cached_raw is not Dictionary:
				continue
			var cached := cached_raw as Dictionary
			if int(cached.get("server_order_batch", -1)) != batch:
				continue
			max_order = maxi(max_order, int(cached.get("server_order", -1)))
	return max_order + 1


func _on_remote_recommendation_failed(message: String) -> void:
	var fetch_reason := _recommendation_fetch_reason
	_recommendation_fetch_reason = ""
	_recommendation_fetch_in_progress = false
	if fetch_reason == "cycle_background":
		return
	if fetch_reason == "prefetch":
		_recommendation_prefetch_remaining = 0
		_set_recommendation_status("已同步已可用的服务器推荐，可以继续换一套。")
		_refresh_recommendation_cards()
		return
	if fetch_reason == "open_refresh":
		_set_recommendation_status(message)
		_refresh_recommendation_cards()
		return
	_switch_to_local_next_recommendation(message)


func _extract_recommendation_bullets(article: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var sections_raw: Variant = article.get("sections", [])
	var sections: Array = sections_raw if sections_raw is Array else []
	for section_raw: Variant in sections:
		if section_raw is not Dictionary:
			continue
		var section := section_raw as Dictionary
		var heading := str(section.get("heading", ""))
		var bullets_raw: Variant = section.get("bullets", [])
		var bullets: Array = bullets_raw if bullets_raw is Array else []
		if not heading.contains("今天怎么练") and result.size() > 0:
			continue
		for bullet_raw: Variant in bullets:
			var bullet := str(bullet_raw).strip_edges()
			if bullet == "":
				continue
			result.append(bullet)
			if result.size() >= 2:
				return result
	return result


func _extract_recommendation_import_url(article: Dictionary) -> String:
	var snapshot := _as_dictionary(article.get("deck_snapshot", {}))
	var import_url := str(snapshot.get("import_url", snapshot.get("source_url", ""))).strip_edges()
	if import_url != "":
		return import_url

	var links_raw: Variant = article.get("links", [])
	var links: Array = links_raw if links_raw is Array else []
	for link_raw: Variant in links:
		if link_raw is not Dictionary:
			continue
		var link := link_raw as Dictionary
		var url := str(link.get("url", "")).strip_edges()
		if url.contains("tcg.mik.moe/decks/list/"):
			return url
	return ""


func _extract_recommendation_deck_id(article: Dictionary) -> int:
	var snapshot := _as_dictionary(article.get("deck_snapshot", {}))
	var raw_id: Variant = snapshot.get("deck_id", 0)
	var deck_id := int(raw_id) if str(raw_id).is_valid_int() else 0
	if deck_id > 0:
		return deck_id
	return DeckImporter.parse_deck_id(_extract_recommendation_import_url(article))


func _show_recommendation_article_dialog(recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	if normalized.is_empty():
		return
	_close_recommendation_detail_overlay()
	var portrait := _is_deck_manager_portrait_layout()
	var context := _current_non_battle_layout_context
	var portrait_scale := _deck_manager_portrait_scale()
	var viewport_size: Vector2 = context.get("viewport_size", get_viewport_rect().size if is_inside_tree() else Vector2(1080, 2400))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1080, 2400) if portrait else Vector2(1280, 720)

	var overlay := Control.new()
	overlay.name = "RecommendationDetailOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recommendation_detail_overlay = overlay

	var shade := ColorRect.new()
	shade.name = "RecommendationDetailShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	var margin := MarginContainer.new()
	margin.name = "RecommendationDetailMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin_value := roundi(24.0 * portrait_scale) if portrait else 24
	margin.offset_left = margin_value
	margin.offset_top = margin_value
	margin.offset_right = -margin_value
	margin.offset_bottom = -margin_value
	overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.name = "RecommendationDetailPanel"
	if portrait:
		panel.custom_minimum_size = Vector2(
			maxf(320.0, viewport_size.x - float(margin_value * 2)),
			maxf(560.0, viewport_size.y - float(margin_value * 2))
		)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.98), Color(HUD_RECOMMENDATION_BORDER.r, HUD_RECOMMENDATION_BORDER.g, HUD_RECOMMENDATION_BORDER.b, 0.92), 22))
	margin.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", int(context.get("section_gap", 12)) if portrait else 12)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", roundi(12.0 * portrait_scale) if portrait else 12)
	outer.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var deck_name := Label.new()
	deck_name.text = str(normalized.get("deck_name", "推荐卡组"))
	deck_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	deck_name.add_theme_font_size_override("font_size", int(context.get("title_font_size", 24)) if portrait else HudThemeScript.scaled_font_size(24))
	deck_name.add_theme_color_override("font_color", HUD_TEXT)
	title_box.add_child(deck_name)

	var meta := Label.new()
	meta.text = _recommendation_source_text(normalized)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD
	meta.add_theme_font_size_override("font_size", int(context.get("meta_font_size", 14)) if portrait else HudThemeScript.scaled_font_size(14))
	meta.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	title_box.add_child(meta)

	var scroll := ScrollContainer.new()
	scroll.name = "RecommendationDetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HudThemeScript.style_scroll_container(scroll, "auto")
	if portrait:
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	outer.add_child(scroll)

	var content_margin := MarginContainer.new()
	content_margin.name = "RecommendationDetailScrollMargin"
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right", 12 if portrait else RECOMMENDATION_DETAIL_SCROLLBAR_RIGHT_CLEARANCE)
	scroll.add_child(content_margin)

	var content := VBoxContainer.new()
	content.name = "RecommendationDetailContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(context.get("section_gap", 12)) if portrait else 12)
	content_margin.add_child(content)

	var title := Label.new()
	title.text = str(normalized.get("title", normalized.get("deck_name", "推荐卡组")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", int(context.get("section_font_size", 18)) if portrait else HudThemeScript.scaled_font_size(18))
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	content.add_child(title)

	var style_summary := str(normalized.get("style_summary", "")).strip_edges()
	if style_summary != "":
		content.add_child(_create_recommendation_detail_paragraph(style_summary, HUD_TEXT_MUTED))

	var why_items: Array = normalized.get("why_play", [])
	if not why_items.is_empty():
		content.add_child(_create_recommendation_detail_heading("为什么值得玩"))
		for bullet_raw: Variant in why_items:
			var bullet := str(bullet_raw).strip_edges()
			if bullet != "":
				content.add_child(_create_recommendation_detail_paragraph("• " + bullet, HUD_TEXT_MUTED))

	var best_for := str(normalized.get("best_for", "")).strip_edges()
	if best_for != "":
		content.add_child(_create_recommendation_detail_heading("适合谁"))
		content.add_child(_create_recommendation_detail_paragraph(best_for, HUD_TEXT_MUTED))

	var pilot_tip := str(normalized.get("pilot_tip", "")).strip_edges()
	if pilot_tip != "":
		content.add_child(_create_recommendation_detail_heading("上手看点"))
		content.add_child(_create_recommendation_detail_paragraph(pilot_tip, HUD_TEXT_MUTED))

	var detail := _as_dictionary(normalized.get("detail", {}))
	var sections_raw: Variant = detail.get("sections", [])
	var sections: Array = sections_raw if sections_raw is Array else []
	for section_raw: Variant in sections:
		if section_raw is not Dictionary:
			continue
		var section := section_raw as Dictionary
		var heading := str(section.get("heading", "")).strip_edges()
		var body := str(section.get("body", "")).strip_edges()
		var bullets_raw: Variant = section.get("bullets", [])
		var bullets: Array = bullets_raw if bullets_raw is Array else []
		if heading != "":
			content.add_child(_create_recommendation_detail_heading(heading))
		if body != "":
			content.add_child(_create_recommendation_detail_paragraph(body, HUD_TEXT_MUTED))
		for bullet_raw: Variant in bullets:
			var bullet := str(bullet_raw).strip_edges()
			if bullet != "":
				content.add_child(_create_recommendation_detail_paragraph("• " + bullet, HUD_TEXT_MUTED))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(10.0 * portrait_scale) if portrait else 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(footer)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	var import_button := Button.new()
	import_button.text = "导入这套"
	import_button.custom_minimum_size = Vector2(124, 42)
	import_button.disabled = str(normalized.get("import_url", "")).strip_edges() == "" or _current_operation != ""
	import_button.pressed.connect(_on_recommendation_detail_import_pressed.bind(normalized))
	footer.add_child(import_button)
	_style_hud_button(import_button, HUD_ACCENT_WARM)
	_apply_recommendation_button_mobile_metrics(import_button)

	var open_button := Button.new()
	open_button.name = "RecommendationDetailOpenButton"
	open_button.text = "打开原卡表"
	open_button.custom_minimum_size = Vector2(136, 42)
	open_button.disabled = str(normalized.get("import_url", "")).strip_edges() == ""
	open_button.pressed.connect(_on_recommendation_open_pressed.bind(normalized))
	footer.add_child(open_button)
	_style_hud_button(open_button, HUD_ACCENT)
	_apply_recommendation_button_mobile_metrics(open_button)

	var close_footer_button := Button.new()
	close_footer_button.name = "RecommendationDetailCloseButton"
	close_footer_button.text = "关闭"
	close_footer_button.custom_minimum_size = Vector2(96, 42)
	close_footer_button.pressed.connect(_close_recommendation_detail_overlay)
	footer.add_child(close_footer_button)
	_style_hud_button(close_footer_button, HUD_SECONDARY)
	_apply_recommendation_button_mobile_metrics(close_footer_button)

	add_child(overlay)
	move_child(overlay, get_child_count() - 1)


func _create_recommendation_detail_heading(text: String) -> Label:
	var portrait := _is_deck_manager_portrait_layout()
	var context := _current_non_battle_layout_context
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", int(context.get("section_font_size", 17)) if portrait else HudThemeScript.scaled_font_size(17))
	label.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	return label


func _create_recommendation_detail_paragraph(text: String, color: Color) -> Label:
	var portrait := _is_deck_manager_portrait_layout()
	var context := _current_non_battle_layout_context
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
	label.add_theme_color_override("font_color", color)
	return label


func _on_recommendation_detail_import_pressed(recommendation: Dictionary) -> void:
	_close_recommendation_detail_overlay()
	_on_recommendation_import_pressed(recommendation)


func _close_recommendation_detail_overlay() -> void:
	if _recommendation_detail_overlay != null and is_instance_valid(_recommendation_detail_overlay):
		_recommendation_detail_overlay.queue_free()
	_recommendation_detail_overlay = null


func _compare_decks_by_edit_time_desc(a: DeckData, b: DeckData) -> bool:
	var a_time := _deck_edit_timestamp(a)
	var b_time := _deck_edit_timestamp(b)
	if a_time == b_time:
		var a_import := str(a.import_date) if a != null else ""
		var b_import := str(b.import_date) if b != null else ""
		if a_import == b_import:
			var a_name := str(a.deck_name) if a != null else ""
			var b_name := str(b.deck_name) if b != null else ""
			if a_name == b_name:
				var a_id := int(a.id) if a != null else 0
				var b_id := int(b.id) if b != null else 0
				return a_id < b_id
			return a_name < b_name
		return a_import > b_import
	return a_time > b_time


func _deck_edit_timestamp(deck: DeckData) -> int:
	if deck == null:
		return 0
	return int(deck.updated_at)


func _deck_row_date_label(deck: DeckData) -> String:
	if _deck_edit_timestamp(deck) > 0:
		return "编辑于"
	return "导入于"


func _deck_row_date_text(deck: DeckData) -> String:
	if deck == null:
		return ""
	var timestamp := _deck_edit_timestamp(deck)
	if timestamp <= 0:
		return str(deck.import_date).substr(0, 10)
	var unix_seconds := timestamp
	if timestamp > 100000000000:
		unix_seconds = int(timestamp / 1000)
	var datetime := Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
	]


func _refresh_deck_list() -> void:
	var deck_list_container: VBoxContainer = %DeckList
	var deck_scroll := find_child("DeckScroll", true, false) as ScrollContainer
	var previous_scroll := deck_scroll.scroll_vertical if deck_scroll != null else 0
	_refresh_recommendation_cards()
	for child: Node in deck_list_container.get_children():
		if child != %EmptyLabel and child != _recommendation_section:
			child.queue_free()

	var decks := CardDatabase.get_all_decks()
	decks.sort_custom(_compare_decks_by_edit_time_desc)
	%EmptyLabel.visible = decks.is_empty()

	for deck: DeckData in decks:
		deck_list_container.add_child(_create_deck_item(deck))
	if deck_scroll != null and previous_scroll > 0:
		deck_scroll.scroll_vertical = previous_scroll
		deck_scroll.set_deferred("scroll_vertical", previous_scroll)
	if _is_import_panel_visible():
		_set_import_background_controls_blocked(true)


func _create_deck_item(deck: DeckData) -> Control:
	var portrait := str(get_meta("non_battle_layout_mode", "")) == "portrait"
	var context := _current_non_battle_layout_context
	var gap := int(context.get("section_gap", 12)) if portrait else 12
	var body_font := int(context.get("body_font_size", 23)) if portrait else HudThemeScript.scaled_font_size(23)
	var button_font := maxi(20, int(context.get("button_font_size", 28)) - 5) if portrait else HudThemeScript.scaled_font_size(HUD_BUTTON_COMPACT_FONT_SIZE)
	var row_button_height := maxf(float(context.get("secondary_button_height", 84.0)) * 0.76, 72.0) if portrait else 38.0
	var row_height := maxf(
		float(context.get("list_item_min_height", 148.0)),
		row_button_height * 2.0 + float(gap) * 3.0 + float(body_font) * 1.45
	) if portrait else 76.0
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, row_height)
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.075, 0.11, 0.88), HUD_CARD_BORDER, 16))

	var hbox: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	hbox.add_theme_constant_override("separation", gap)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = "%s | %s %s" % [deck.deck_name, _deck_row_date_label(deck), _deck_row_date_text(deck)]
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", body_font)
	name_label.add_theme_color_override("font_color", HUD_TEXT)
	info_vbox.add_child(name_label)

	var button_parent: Container = hbox
	if portrait:
		var grid := GridContainer.new()
		grid.name = "DeckRowButtonGrid"
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", gap)
		grid.add_theme_constant_override("v_separation", gap)
		hbox.add_child(grid)
		button_parent = grid

	var btn_view := Button.new()
	btn_view.text = "查看"
	btn_view.custom_minimum_size = Vector2(78, 38)
	btn_view.pressed.connect(_on_view_deck.bind(deck))
	button_parent.add_child(btn_view)

	var btn_edit := Button.new()
	btn_edit.text = "编辑"
	btn_edit.custom_minimum_size = Vector2(78, 38)
	btn_edit.pressed.connect(_on_edit_deck.bind(deck))
	button_parent.add_child(btn_edit)

	var btn_rename := Button.new()
	btn_rename.name = "DeckRowRenameButton"
	btn_rename.text = "重命名"
	btn_rename.custom_minimum_size = Vector2(96, 38)
	btn_rename.pressed.connect(_on_rename_deck.bind(deck))
	button_parent.add_child(btn_rename)

	var btn_delete := Button.new()
	btn_delete.name = "DeckRowDeleteButton"
	btn_delete.text = "删除"
	btn_delete.custom_minimum_size = Vector2(78, 38)
	btn_delete.pressed.connect(_on_delete_deck.bind(deck))
	button_parent.add_child(btn_delete)

	_style_hud_button(btn_view, HUD_SECONDARY, true)
	_style_hud_button(btn_edit, HUD_ACCENT, true)
	_style_hud_button(btn_rename, HUD_RENAME, true)
	_style_hud_button(btn_delete, HUD_DANGER, true)
	for button: Button in [btn_view, btn_edit, btn_rename, btn_delete]:
		NonBattleTouchBridgeScript.bind_button_touch(button)
	if portrait:
		for button: Button in [btn_view, btn_edit, btn_rename, btn_delete]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, row_button_height)
			button.add_theme_font_size_override("font_size", button_font)

	return panel


func _on_import_pressed() -> void:
	if _current_operation != "":
		return
	_cancel_import_result_auto_close()
	_pending_import_deck_name_override = ""
	_panel_mode = "import"
	_configure_operation_panel()
	%UrlInput.text = ""
	%UrlInput.editable = true
	%ProgressLabel.text = ""
	%ProgressBar.visible = false
	%BtnDoImport.visible = true
	%BtnDoImport.disabled = false
	_show_import_panel()


func _on_recommendation_import_pressed(recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	var import_url := str(normalized.get("import_url", "")).strip_edges()
	if import_url == "":
		_set_recommendation_status("这套推荐缺少可导入的卡组链接。")
		return
	var recommended_deck_name := str(normalized.get("deck_name", "")).strip_edges()
	_start_import_from_url(import_url, "正在导入推荐卡组...", recommended_deck_name)


func _on_recommendation_open_pressed(recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	var import_url := str(normalized.get("import_url", "")).strip_edges()
	if import_url == "":
		return
	var err := OS.shell_open(import_url)
	if err != OK:
		push_warning("无法打开推荐卡表: %s" % import_url)


func _on_recommendation_read_pressed(recommendation: Dictionary) -> void:
	_show_recommendation_article_dialog(recommendation)


func _on_close_import() -> void:
	_cancel_import_result_auto_close()
	_hide_import_panel()


func _focus_import_url_input() -> void:
	if _panel_mode != "import":
		return
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input == null or not url_input.editable:
		return
	url_input.set_meta(IMPORT_URL_FOCUS_REQUESTED_META, true)
	if not is_inside_tree():
		return
	if not _is_import_panel_visible() or not url_input.visible:
		return
	if not url_input.is_inside_tree():
		return
	url_input.focus_mode = Control.FOCUS_ALL
	url_input.grab_focus()
	url_input.caret_column = url_input.text.length()


func _on_paste_import_url() -> void:
	if _panel_mode != "import":
		return
	var clipboard_text := ""
	if DisplayServer.get_name() != "headless":
		clipboard_text = DisplayServer.clipboard_get().strip_edges()
	_apply_import_paste_text(clipboard_text)


func _apply_import_paste_text_for_tests(text: String) -> void:
	_apply_import_paste_text(text)


func _apply_import_paste_text(text: String) -> void:
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input == null or not url_input.editable:
		return
	var clipboard_text := text.strip_edges()
	if clipboard_text == "":
		%ProgressLabel.text = "剪贴板为空。请先在浏览器复制 tcg.mik.moe 卡组链接，或直接输入末尾数字 ID。"
		return
	url_input.text = clipboard_text
	url_input.caret_column = url_input.text.length()
	%ProgressLabel.text = "已粘贴剪贴板内容，确认无误后点击“导入卡组”。"
	_focus_import_url_input()


func _on_do_import() -> void:
	if _panel_mode != "import":
		return

	var url: String = %UrlInput.text.strip_edges()
	if url.is_empty():
		%ProgressLabel.text = "请输入卡组链接或卡组 ID。"
		return

	_start_import_from_url(url, "正在导入卡组...")


func _start_import_from_url(url: String, progress_text: String, deck_name_override: String = "") -> void:
	if _current_operation != "":
		return

	_cancel_import_result_auto_close()
	_pending_import_deck_name_override = deck_name_override.strip_edges()
	_current_operation = "import"
	_panel_mode = "import"
	_configure_operation_panel()
	_set_operation_busy(true)
	_show_import_panel()
	%UrlInput.text = url
	%UrlInput.editable = false
	%BtnDoImport.visible = false
	%BtnDoImport.disabled = true
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = progress_text
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input != null and url_input.has_focus():
		url_input.release_focus()
	if DisplayServer.get_name() != "headless":
		DisplayServer.virtual_keyboard_hide()
	_queue_import_deck_start(url)


func _queue_import_deck_start(url: String) -> void:
	_pending_import_start_url = url
	call_deferred("_begin_pending_import_after_busy_frame")


func _begin_pending_import_after_busy_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	_begin_pending_import_now()


func _begin_pending_import_now() -> void:
	var url := _pending_import_start_url
	if url == "":
		return
	_pending_import_start_url = ""
	if _current_operation != "import":
		return
	if _importer == null:
		_on_import_failed("Deck importer is not ready")
		return
	_importer.import_deck(url)


func _begin_pending_import_now_for_tests() -> void:
	_begin_pending_import_now()


func _on_sync_images_pressed() -> void:
	if _current_operation != "":
		return

	_cancel_import_result_auto_close()
	_panel_mode = "sync_images"
	_configure_operation_panel()
	_show_import_panel()
	_current_operation = "sync_images"
	_set_operation_busy(true)
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = "正在同步卡图..."
	_image_syncer.sync_cached_cards()


func _on_import_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_import_completed(deck: DeckData, errors: PackedStringArray) -> void:
	_apply_pending_import_deck_name_override(deck)
	if _has_duplicate_deck_name(deck.deck_name, deck.id):
		_pending_import_deck = deck
		_pending_import_errors = PackedStringArray(errors)
		_show_import_rename_dialog(deck.deck_name)
		return

	_finalize_import_save(deck, errors)


func _finalize_import_save(deck: DeckData, errors: PackedStringArray) -> void:
	CardDatabase.save_deck(deck)
	_current_operation = ""
	_pending_import_deck_name_override = ""
	_set_operation_busy(false)

	var result_message := ""
	if errors.is_empty():
		result_message = "导入成功：%s（%d 张卡）" % [deck.deck_name, deck.total_cards]
	else:
		result_message = "导入成功，包含 %d 条警告" % errors.size()
		for err: String in errors:
			push_warning("导入警告：%s" % err)
	_show_import_result(result_message)


func _has_duplicate_deck_name(deck_name: String, ignored_deck_id: int = -1) -> bool:
	var normalized_name: String = deck_name.strip_edges()
	if normalized_name == "":
		return false

	for deck: DeckData in CardDatabase.get_all_decks():
		if deck.id == ignored_deck_id:
			continue
		if deck.deck_name.strip_edges() == normalized_name:
			return true

	return false


func _validate_deck_name(deck_name: String, ignored_deck_id: int = -1) -> String:
	var normalized_name: String = deck_name.strip_edges()
	if normalized_name == "":
		return "请输入卡组名称。"
	if _has_duplicate_deck_name(normalized_name, ignored_deck_id):
		return "已有已保存卡组使用该名称。"
	return ""


func _validate_import_deck_name(deck_name: String) -> String:
	return _validate_deck_name(deck_name)


func _apply_pending_import_deck_name_override(deck: DeckData) -> void:
	var override_name := _pending_import_deck_name_override.strip_edges()
	_pending_import_deck_name_override = ""
	if deck == null or override_name == "":
		return
	deck.deck_name = override_name


func _is_deck_action_hud_dialog_visible() -> bool:
	return _deck_action_hud_overlay != null and is_instance_valid(_deck_action_hud_overlay) and _deck_action_hud_overlay.visible


func _close_deck_action_hud_dialog(context_filter: String = "") -> void:
	if context_filter != "" and _deck_action_hud_context != context_filter:
		return
	if _deck_action_hud_overlay != null and is_instance_valid(_deck_action_hud_overlay):
		_deck_action_hud_overlay.queue_free()
	_deck_action_hud_overlay = null
	_deck_action_hud_panel = null
	_deck_action_hud_context = ""


func _deck_action_hud_dialog_size(preferred_size: Vector2) -> Vector2:
	if not _is_deck_manager_portrait_layout():
		return preferred_size
	var context := _current_non_battle_layout_context
	var viewport_size: Vector2 = context.get("viewport_size", size if size.x > 0.0 and size.y > 0.0 else Vector2(390, 844))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(390, 844)
	var margin := float(context.get("page_margin", 24.0))
	var width := maxf(320.0, viewport_size.x - margin * 2.0)
	var height := clampf(preferred_size.y, 340.0, maxf(340.0, viewport_size.y - margin * 2.0))
	return Vector2(width, height)


func _create_deck_action_hud_shell(title: String, message_text: String, preferred_size: Vector2, context: String) -> Dictionary:
	_close_deck_action_hud_dialog()

	_deck_action_hud_overlay = Control.new()
	_deck_action_hud_overlay.name = DECK_ACTION_HUD_DIALOG_NAME
	_deck_action_hud_overlay.layout_mode = 1
	_deck_action_hud_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_action_hud_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_action_hud_overlay.z_as_relative = false
	_deck_action_hud_overlay.z_index = 2600
	add_child(_deck_action_hud_overlay)

	var shade := ColorRect.new()
	shade.name = "DeckActionHudShade"
	shade.layout_mode = 1
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.024, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_action_hud_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.name = "DeckActionHudCenter"
	center.layout_mode = 1
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_action_hud_overlay.add_child(center)

	_deck_action_hud_panel = PanelContainer.new()
	_deck_action_hud_panel.name = "DeckActionHudPanel"
	_deck_action_hud_panel.custom_minimum_size = _deck_action_hud_dialog_size(preferred_size)
	_deck_action_hud_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.98), HUD_FRAME_BORDER, 22))
	center.add_child(_deck_action_hud_panel)

	var root := VBoxContainer.new()
	root.name = "DeckActionHudRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", int(_current_non_battle_layout_context.get("section_gap", 22)))
	_deck_action_hud_panel.add_child(root)

	var title_label := Label.new()
	title_label.name = "DeckActionHudTitle"
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", int(_current_non_battle_layout_context.get("title_font_size", 40)))
	title_label.add_theme_color_override("font_color", HUD_TEXT)
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.74, 1.0, 0.58))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.name = "DeckActionHudScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, maxf(150.0, _deck_action_hud_panel.custom_minimum_size.y - 190.0))
	HudThemeScript.style_scroll_container(scroll)
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "DeckActionHudContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(maxf(260.0, _deck_action_hud_panel.custom_minimum_size.x - 52.0), 0.0)
	content.add_theme_constant_override("separation", int(_current_non_battle_layout_context.get("section_gap", 22)))
	scroll.add_child(content)

	var message := Label.new()
	message.name = "DeckActionHudMessage"
	message.text = message_text
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", int(_current_non_battle_layout_context.get("body_font_size", 27)))
	message.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	content.add_child(message)

	var footer := HBoxContainer.new()
	footer.name = "DeckActionHudFooter"
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", maxi(14, int(_current_non_battle_layout_context.get("section_gap", 22)) / 2))
	root.add_child(footer)

	_deck_action_hud_context = context
	_deck_action_hud_overlay.move_to_front()
	return {
		"overlay": _deck_action_hud_overlay,
		"panel": _deck_action_hud_panel,
		"root": root,
		"scroll": scroll,
		"content": content,
		"footer": footer,
	}


func _create_deck_action_hud_button(text: String, accent: Color, node_name: String = "") -> Button:
	var button := Button.new()
	if node_name != "":
		button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_hud_button(button, accent)
	if _is_deck_manager_portrait_layout():
		var context := _current_non_battle_layout_context
		var input_height := float(context.get("input_height", 98.0))
		var button_height := maxf(float(context.get("secondary_button_height", 104.0)), input_height)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, button_height)
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 33)))
	NonBattleTouchBridgeScript.bind_button_touch(button)
	return button


func _show_rename_hud_dialog(initial_name: String, title: String, message_text: String) -> void:
	var shell := _create_deck_action_hud_shell(title, message_text, Vector2(520.0, 520.0), "rename")
	var content := shell.get("content") as VBoxContainer
	var footer := shell.get("footer") as HBoxContainer
	if content == null or footer == null:
		return

	_rename_dialog = null
	_rename_input = LineEdit.new()
	_rename_input.name = "DeckRenameInput"
	_rename_input.text = initial_name
	_rename_input.text_changed.connect(_on_rename_text_changed)
	_rename_input.virtual_keyboard_enabled = true
	_rename_input.virtual_keyboard_show_on_focus = true
	_style_hud_line_edit(_rename_input)
	var context := _current_non_battle_layout_context
	_rename_input.custom_minimum_size.y = maxf(_rename_input.custom_minimum_size.y, float(context.get("input_height", 98.0)))
	_rename_input.add_theme_font_size_override("font_size", int(context.get("input_font_size", 29)))
	NonBattleTouchBridgeScript.bind_focus_control_touch(_rename_input)
	content.add_child(_rename_input)

	_rename_error_label = Label.new()
	_rename_error_label.name = "DeckRenameError"
	_rename_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rename_error_label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 27)))
	_rename_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	content.add_child(_rename_error_label)

	var cancel_button := _create_deck_action_hud_button("\u53d6\u6d88", HUD_SECONDARY, "DeckRenameCancelButton")
	cancel_button.pressed.connect(_on_rename_close_requested)
	footer.add_child(cancel_button)

	_rename_confirm_button = _create_deck_action_hud_button("\u786e\u8ba4", HUD_ACCENT_WARM, "DeckRenameConfirmButton")
	_rename_confirm_button.pressed.connect(_on_confirm_rename)
	footer.add_child(_rename_confirm_button)

	_on_rename_text_changed(initial_name)


func _on_rename_deck(deck: DeckData) -> void:
	_show_rename_dialog(
		deck.deck_name,
		"重命名卡组",
		"请输入新的卡组名称。",
		deck.id,
		true
	)
	_rename_target_deck = deck
	_rename_context = "existing"
	_rename_forced = false


func _show_import_rename_dialog(initial_name: String) -> void:
	_show_rename_dialog(
		initial_name,
		"卡组名称重复",
		"导入的卡组名称已存在，请输入一个不同的名称后再保存。",
		-1
	)
	_rename_target_deck = _pending_import_deck
	_rename_context = "import"
	_rename_forced = true


func _show_rename_dialog(initial_name: String, title: String, message_text: String, ignored_deck_id: int, prefer_hud_dialog: bool = false) -> void:
	_close_rename_dialog(false)

	_rename_ignore_deck_id = ignored_deck_id
	if prefer_hud_dialog and _is_deck_manager_portrait_layout():
		_show_rename_hud_dialog(initial_name, title, message_text)
		return

	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = title
	_rename_dialog.ok_button_text = "\u786e\u8ba4"
	_rename_dialog.dialog_hide_on_ok = false
	_rename_dialog.close_requested.connect(_on_rename_close_requested)
	_rename_dialog.confirmed.connect(_on_confirm_rename)
	var dialog_size := _rename_dialog_size_for_current_layout()
	_rename_dialog.min_size = dialog_size
	_rename_dialog.size = dialog_size

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(dialog_size.x - 40, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll)
	_rename_dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(dialog_size.x - 60, 0)
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	var message := Label.new()
	message.text = message_text
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(message)

	_rename_input = LineEdit.new()
	_rename_input.text = initial_name
	_rename_input.text_changed.connect(_on_rename_text_changed)
	content.add_child(_rename_input)

	_rename_error_label = Label.new()
	_rename_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rename_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	content.add_child(_rename_error_label)

	add_child(_rename_dialog)
	_rename_confirm_button = _rename_dialog.get_ok_button()
	if _rename_confirm_button != null:
		_style_hud_button(_rename_confirm_button, HUD_ACCENT_WARM)
	_apply_rename_dialog_layout(scroll, content, message)
	_on_rename_text_changed(initial_name)

	if is_inside_tree():
		_popup_rename_dialog_centered()


func _rename_dialog_size_for_current_layout() -> Vector2i:
	if not _is_deck_manager_portrait_layout():
		return RENAME_DIALOG_SIZE
	var context := _current_non_battle_layout_context
	var viewport_size: Vector2 = context.get("viewport_size", size if size.x > 0.0 and size.y > 0.0 else Vector2(390, 844))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(390, 844)
	var margin := float(context.get("page_margin", 24.0))
	var input_height := float(context.get("input_height", 98.0))
	var width := minf(maxf(float(context.get("content_width", viewport_size.x - margin * 2.0)), 320.0), maxf(320.0, viewport_size.x - margin * 2.0))
	var height := minf(maxf(440.0, input_height * 4.7), maxf(440.0, viewport_size.y - margin * 2.0))
	return Vector2i(roundi(width), roundi(height))


func _apply_rename_dialog_layout(scroll: ScrollContainer, content: VBoxContainer, message: Label) -> void:
	if _rename_dialog == null:
		return
	var dialog_size := _rename_dialog_size_for_current_layout()
	_rename_dialog.min_size = dialog_size
	_rename_dialog.size = dialog_size
	if not _is_deck_manager_portrait_layout():
		if scroll != null:
			scroll.custom_minimum_size = Vector2(dialog_size.x - 40, 120)
			HudThemeScript.style_scroll_container(scroll)
		if content != null:
			content.custom_minimum_size = Vector2(dialog_size.x - 60, 0)
		return
	var context := _current_non_battle_layout_context
	var body_font := int(context.get("body_font_size", 27))
	var input_font := int(context.get("input_font_size", 29))
	var button_font := int(context.get("button_font_size", 33))
	var input_height := float(context.get("input_height", 98.0))
	var button_height := maxf(float(context.get("secondary_button_height", 104.0)), input_height)
	var gap := int(context.get("section_gap", 22))
	if scroll != null:
		scroll.custom_minimum_size = Vector2(maxf(260.0, float(dialog_size.x) - 32.0), maxf(230.0, float(dialog_size.y) - button_height - 92.0))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		HudThemeScript.style_scroll_container(scroll)
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	if content != null:
		content.custom_minimum_size = Vector2(maxf(240.0, float(dialog_size.x) - 52.0), 0.0)
		content.add_theme_constant_override("separation", gap)
	if message != null:
		message.add_theme_font_size_override("font_size", body_font)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD
	if _rename_error_label != null:
		_rename_error_label.add_theme_font_size_override("font_size", body_font)
		_rename_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if _rename_input != null:
		_style_hud_line_edit(_rename_input)
		_rename_input.custom_minimum_size.y = maxf(_rename_input.custom_minimum_size.y, input_height)
		_rename_input.add_theme_font_size_override("font_size", input_font)
		NonBattleTouchBridgeScript.bind_focus_control_touch(_rename_input)
	if _rename_confirm_button != null:
		_rename_confirm_button.custom_minimum_size.y = maxf(_rename_confirm_button.custom_minimum_size.y, button_height)
		_rename_confirm_button.add_theme_font_size_override("font_size", button_font)
		NonBattleTouchBridgeScript.bind_button_touch(_rename_confirm_button)


func _popup_rename_dialog_centered() -> void:
	if _rename_dialog == null or not is_instance_valid(_rename_dialog):
		return
	_rename_dialog.popup_centered(_rename_dialog_size_for_current_layout())

func _on_rename_text_changed(new_text: String) -> void:
	var validation_error: String = _validate_deck_name(new_text, _rename_ignore_deck_id)
	if _rename_error_label != null:
		_rename_error_label.text = validation_error
	if _rename_confirm_button != null:
		_rename_confirm_button.disabled = validation_error != ""


func _on_confirm_rename() -> void:
	if _rename_target_deck == null or _rename_input == null:
		return

	var new_name: String = _rename_input.text.strip_edges()
	var validation_error: String = _validate_deck_name(new_name, _rename_ignore_deck_id)
	if validation_error != "":
		_on_rename_text_changed(new_name)
		return

	var deck := _rename_target_deck
	var is_import_rename := _rename_context == "import"
	var errors := PackedStringArray(_pending_import_errors)
	deck.deck_name = new_name

	if is_import_rename:
		_pending_import_deck = null
		_pending_import_errors = PackedStringArray()
	else:
		CardDatabase.save_deck(deck)

	_close_rename_dialog()

	if is_import_rename:
		_finalize_import_save(deck, errors)


func _on_rename_close_requested() -> void:
	if _rename_forced:
		if _rename_dialog != null and is_instance_valid(_rename_dialog) and is_inside_tree():
			_popup_rename_dialog_centered()
		return

	_close_rename_dialog()


func _close_rename_dialog(clear_target: bool = true) -> void:
	if _rename_dialog != null and is_instance_valid(_rename_dialog):
		_rename_dialog.queue_free()
	_close_deck_action_hud_dialog("rename")

	_rename_dialog = null
	_rename_input = null
	_rename_error_label = null
	_rename_confirm_button = null
	_rename_ignore_deck_id = -1
	_rename_context = ""
	_rename_forced = false

	if clear_target:
		_rename_target_deck = null


func _on_import_rename_text_changed(new_text: String) -> void:
	_on_rename_text_changed(new_text)


func _on_confirm_import_rename() -> void:
	_on_confirm_rename()


func _on_import_rename_close_requested() -> void:
	_on_rename_close_requested()


func _close_import_rename_dialog() -> void:
	_close_rename_dialog()


func _on_import_failed(error_message: String) -> void:
	_current_operation = ""
	_set_operation_busy(false)
	_pending_import_deck = null
	_pending_import_errors = PackedStringArray()
	_pending_import_deck_name_override = ""
	_show_import_result("导入失败：%s" % error_message)


func _show_import_result(message: String) -> void:
	%ProgressBar.visible = false
	%UrlInput.editable = false
	%BtnDoImport.visible = false
	%BtnDoImport.disabled = true
	%ProgressLabel.text = message
	_schedule_import_result_auto_close()


func _schedule_import_result_auto_close() -> void:
	if not is_inside_tree():
		return
	_ensure_import_result_close_timer()
	_import_result_close_timer.start(IMPORT_RESULT_AUTO_CLOSE_SECONDS)


func _ensure_import_result_close_timer() -> void:
	if _import_result_close_timer != null and is_instance_valid(_import_result_close_timer):
		return
	_import_result_close_timer = Timer.new()
	_import_result_close_timer.name = "ImportResultCloseTimer"
	_import_result_close_timer.one_shot = true
	_import_result_close_timer.timeout.connect(_on_import_result_close_timeout)
	add_child(_import_result_close_timer)


func _cancel_import_result_auto_close() -> void:
	if _import_result_close_timer != null and is_instance_valid(_import_result_close_timer):
		_import_result_close_timer.stop()


func _on_import_result_close_timeout() -> void:
	if _current_operation == "":
		_hide_import_panel()


func _on_image_sync_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_image_sync_completed(stats: Dictionary, errors: PackedStringArray) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)

	var total := int(stats.get("total", 0))
	var downloaded := int(stats.get("downloaded", 0))
	var updated := int(stats.get("updated", 0))
	var skipped := int(stats.get("skipped", 0))

	if errors.is_empty():
		%ProgressLabel.text = "同步完成：共 %d 张，下载 %d 张，跳过 %d 张，更新 %d 张" % [
			total, downloaded, skipped, updated
		]
	else:
		%ProgressLabel.text = "同步完成：共 %d 张，下载 %d 张，警告 %d 条" % [
			total, downloaded, errors.size()
		]
		for err: String in errors:
			push_warning("卡图同步警告：%s" % err)


func _on_image_sync_failed(error_message: String) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%ProgressLabel.text = "同步失败：%s" % error_message


func _on_edit_deck(deck: DeckData) -> void:
	GameManager.goto_deck_editor(deck.id)


func _on_view_deck(deck: DeckData) -> void:
	_deck_view_dialog.call("show_deck", self, deck)


const VIEW_CATEGORY_ORDER: Dictionary = {
	"Pokemon": 0,
	"Item": 1,
	"Tool": 2,
	"Supporter": 3,
	"Stadium": 4,
	"Basic Energy": 5,
	"Special Energy": 6,
}


func _sort_entries_by_category(cards: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = cards.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = VIEW_CATEGORY_ORDER.get(a.get("card_type", ""), 99)
		var ob: int = VIEW_CATEGORY_ORDER.get(b.get("card_type", ""), 99)
		if oa != ob:
			return oa < ob
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


func _create_view_tile(card_name: String, set_code: String, card_index: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_TILE_WIDTH, CARD_TILE_HEIGHT + 20)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.22, 0.3, 1.0)
	sb.border_color = Color(0.3, 0.32, 0.4, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var tex_rect := TextureRect.new()
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.custom_minimum_size = Vector2(CARD_TILE_WIDTH - 8, CARD_TILE_HEIGHT - 8)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var texture := _load_card_texture(set_code, card_index)
	if texture != null:
		tex_rect.texture = texture
	else:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(CARD_TILE_WIDTH - 8, CARD_TILE_HEIGHT - 8)
		tex_rect.texture = placeholder
	vbox.add_child(tex_rect)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(11))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(CARD_TILE_WIDTH - 8, 0)
	vbox.add_child(label)

	return panel


func _on_view_tile_input(event: InputEvent, set_code: String, card_index: String) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var card := CardDatabase.get_card(set_code, card_index)
		if card != null:
			_show_card_detail(card)


func _show_card_detail(card: CardData) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = card.name
	dialog.ok_button_text = "关闭"
	dialog.size = Vector2i(500, 480)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	HudThemeScript.style_scroll_container(scroll)
	dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var header := Label.new()
	header.text = card.name
	header.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(20))
	content.add_child(header)

	var meta_parts: PackedStringArray = []
	meta_parts.append(card.card_type)
	if card.mechanic != "":
		meta_parts.append(card.mechanic)
	if card.set_code != "":
		meta_parts.append("%s %s" % [card.set_code, card.card_index])
	if card.rarity != "":
		meta_parts.append(card.rarity)
	var meta_label := Label.new()
	meta_label.text = " | ".join(meta_parts)
	meta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content.add_child(meta_label)

	if card.is_pokemon():
		_add_detail_separator(content)
		var stat_parts: PackedStringArray = []
		stat_parts.append("HP %d" % card.hp)
		stat_parts.append("属性: %s" % _energy_display(card.energy_type))
		stat_parts.append("阶段: %s" % card.stage)
		stat_parts.append("撤退: %d" % card.retreat_cost)
		var stat_label := Label.new()
		stat_label.text = " | ".join(stat_parts)
		content.add_child(stat_label)

		if card.evolves_from != "":
			var evo_label := Label.new()
			evo_label.text = "从 %s 进化" % card.evolves_from
			content.add_child(evo_label)

		var weakness_text := ""
		if card.weakness_energy != "":
			weakness_text = "弱点: %s %s" % [_energy_display(card.weakness_energy), card.weakness_value]
		var resist_text := ""
		if card.resistance_energy != "":
			resist_text = "抗性: %s %s" % [_energy_display(card.resistance_energy), card.resistance_value]
		if weakness_text != "" or resist_text != "":
			var wr_label := Label.new()
			wr_label.text = "  ".join([weakness_text, resist_text]).strip_edges()
			content.add_child(wr_label)

		for ab: Dictionary in card.abilities:
			_add_detail_separator(content)
			var ab_title := Label.new()
			ab_title.text = "[特性] %s" % ab.get("name", "")
			ab_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			content.add_child(ab_title)
			if ab.get("text", "") != "":
				var ab_text := Label.new()
				ab_text.text = str(ab.get("text", ""))
				ab_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(ab_text)

		for atk: Dictionary in card.attacks:
			_add_detail_separator(content)
			var cost_str: String = str(atk.get("cost", ""))
			var dmg_str: String = str(atk.get("damage", ""))
			var atk_header := Label.new()
			var parts: PackedStringArray = []
			if cost_str != "":
				parts.append("[%s]" % cost_str)
			parts.append(str(atk.get("name", "")))
			if dmg_str != "":
				parts.append(dmg_str)
			atk_header.text = " ".join(parts)
			atk_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
			content.add_child(atk_header)
			if atk.get("text", "") != "":
				var atk_text := Label.new()
				atk_text.text = str(atk.get("text", ""))
				atk_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(atk_text)

	if card.description != "":
		_add_detail_separator(content)
		var desc := Label.new()
		desc.text = card.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(desc)

	if card.effect_id != "":
		_add_detail_separator(content)
		var eid := Label.new()
		eid.text = "效果ID: %s" % card.effect_id
		eid.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(eid)

	if card.name_en != "":
		var en_label := Label.new()
		en_label.text = "英文名: %s" % card.name_en
		en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(en_label)

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _add_detail_separator(container: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	container.add_child(sep)


func _energy_display(energy_code: String) -> String:
	return ENERGY_TYPE_LABELS.get(energy_code, energy_code)


func _load_card_texture(set_code: String, card_index: String) -> Texture2D:
	var file_path := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths(set_code, card_index)
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
		if image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46:
			if image_bytes[8] == 0x57 and image_bytes[9] == 0x45 and image_bytes[10] == 0x42 and image_bytes[11] == 0x50:
				return image.load_webp_from_buffer(image_bytes)
	return ERR_FILE_UNRECOGNIZED


func _show_delete_deck_hud_dialog(deck: DeckData) -> void:
	var message := "\u786e\u5b9a\u8981\u5220\u9664\u5361\u7ec4\u201c%s\u201d\u5417\uff1f" % deck.deck_name
	var shell := _create_deck_action_hud_shell("\u786e\u8ba4\u5220\u9664", message, Vector2(520.0, 390.0), "delete")
	var footer := shell.get("footer") as HBoxContainer
	if footer == null:
		return

	var cancel_button := _create_deck_action_hud_button("\u53d6\u6d88", HUD_SECONDARY, "DeleteDeckCancelButton")
	cancel_button.pressed.connect(_close_deck_action_hud_dialog)
	footer.add_child(cancel_button)

	var delete_button := _create_deck_action_hud_button("\u5220\u9664", HUD_DANGER, "DeleteDeckConfirmButton")
	delete_button.pressed.connect(func() -> void:
		CardDatabase.delete_deck(deck.id)
		_close_deck_action_hud_dialog("delete")
	)
	footer.add_child(delete_button)


func _on_delete_deck(deck: DeckData) -> void:
	if _is_deck_manager_portrait_layout():
		_show_delete_deck_hud_dialog(deck)
		return

	var confirm := ConfirmationDialog.new()
	confirm.title = "确认删除"
	confirm.dialog_text = "确定要删除卡组“%s”吗？" % deck.deck_name
	confirm.ok_button_text = "删除"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func() -> void:
		CardDatabase.delete_deck(deck.id)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	_style_hud_button(confirm.get_ok_button(), HUD_DANGER)
	_style_hud_button(confirm.get_cancel_button(), HUD_SECONDARY)
	if is_inside_tree():
		confirm.popup_centered()


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _configure_operation_panel() -> void:
	var title_label: Label = $ImportPanel/ImportBox/VBox/TitleLabel
	var hint_label: Label = $ImportPanel/ImportBox/VBox/HintLabel
	var paste_button := _ensure_import_paste_button()

	if _panel_mode == "sync_images":
		title_label.text = "同步卡图"
		hint_label.visible = false
		%UrlInput.visible = false
		%BtnDoImport.visible = false
		if paste_button != null:
			paste_button.visible = false
	else:
		title_label.text = "导入卡组"
		hint_label.visible = true
		%UrlInput.visible = true
		%BtnDoImport.visible = true
		if paste_button != null:
			paste_button.visible = true

	%BtnCloseImport.text = "关闭"
	if _panel_mode == "import":
		title_label.text = "导入卡组"
		hint_label.text = IMPORT_DECK_GUIDE_TEXT
		%UrlInput.placeholder_text = "粘贴卡组链接或输入数字 ID，例如 574793"
		if paste_button != null:
			paste_button.text = "粘贴链接"
		%BtnDoImport.text = "导入卡组"
	%BtnCloseImport.text = "关闭"


func _set_operation_busy(busy: bool) -> void:
	%BtnImport.disabled = busy
	%BtnSyncImages.disabled = busy
	%BtnBack.disabled = busy
	_refresh_recommendation_cards()
