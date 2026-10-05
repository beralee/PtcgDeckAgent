extends Control
## A modal in the game's viewport. No Window, OS focus transfer or native title bar.
signal confirmed
signal canceled
signal close_requested
signal layout_updated

const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
const Touch := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const Gesture := preload("res://scripts/ui/non_battle/NonBattleGestureRouter.gd")
const GROUP := &"game_modal_dialogs"
const BACK_BEHAVIOR_META := &"game_modal_previous_back_behavior"
const BACK_FRAME_META := &"game_modal_back_frame"

@export var title := ""
@export_multiline var dialog_text := ""
@export var ok_button_text := "确定"
@export var cancel_button_text := "取消"
@export var show_cancel := false
@export var dialog_hide_on_ok := true
@export var dialog_size := Vector2(560, 300)
var min_size := Vector2i.ZERO
var scale_content := true
var show_header := true
var content_zoom := 1.0
var content_min_height := 0.0
var _panel: PanelContainer
var _column: VBoxContainer
var _heading: Label
var _close: Button
var _message: Label
var _scroll: ScrollContainer
var _surface: Control
var _content: Control
var _footer: HBoxContainer
var _ok: Button
var _cancel: Button
var _previous_focus: WeakRef
var _gesture := Gesture.new()
var _keyboard_height := -1
var _opened := false
var _submitting := false
var _order := 0
var _header: HBoxContainer
var _native_text_finger := -1

class EchoGuard extends Node:
	var until_msec := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouse and event.device == -1 and Time.get_ticks_msec() < until_msec:
			get_viewport().set_input_as_handled()

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 3900
	top_level = true
	_build()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "ModalPanel"
	add_child(_panel)
	_column = VBoxContainer.new()
	_panel.add_child(_column)
	_header = HBoxContainer.new()
	_column.add_child(_header)
	_heading = UI.label("")
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.max_lines_visible = 2
	_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_heading)
	_close = UI.action("关闭", request_cancel)
	_close.name = "ModalCloseButton"
	_header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.name = "ModalScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.scroll(_scroll)
	_column.add_child(_scroll)
	_surface = Control.new()
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_surface)
	_content = Control.new()
	_content.name = "ModalContent"
	_surface.add_child(_content)
	_message = UI.label("")
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_column.add_child(_footer)
	_cancel = UI.action("取消", request_cancel)
	_cancel.name = "ModalCancelButton"
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_cancel)
	_ok = UI.action("确定", _confirm, 1.0, true)
	_ok.name = "ModalConfirmButton"
	_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_ok)

func _ready() -> void:
	add_to_group(GROUP)
	if not is_inside_tree():
		return
	# Scene-authored content keeps its owner, so unique-name references still work.
	for child: Node in get_children():
		if child is Control and child != _panel and not child is ColorRect:
			_adopt(child)
	visibility_changed.connect(_visibility_changed)
	get_viewport().size_changed.connect(_layout)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout()

func add_content(node: Control) -> void:
	_content.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)

func get_panel() -> PanelContainer:
	return _panel

func get_title_label() -> Label:
	return _heading

func get_column() -> VBoxContainer:
	return _column

func get_footer() -> HBoxContainer:
	return _footer

func get_scroll() -> ScrollContainer:
	return _scroll

func get_content() -> Control:
	# Also supports scene setup before it enters the tree.
	var authored := get_node_or_null("Root") as Control
	if authored != null:
		_adopt(authored)
	return _content

func _adopt(child: Control) -> void:
	var owners: Array[Dictionary] = []
	_capture_owners(child, owners)
	child.owner = null
	child.reparent(_content, false)
	for record: Dictionary in owners:
		record.node.owner = record.owner

func _capture_owners(node: Node, owners: Array[Dictionary]) -> void:
	owners.append({"node": node, "owner": node.owner})
	for child: Node in node.get_children():
		_capture_owners(child, owners)

func get_ok_button() -> Button:
	return _ok

func get_cancel_button() -> Button:
	return _cancel

func popup_centered(preferred: Vector2i = Vector2i.ZERO) -> void:
	if preferred != Vector2i.ZERO:
		dialog_size = Vector2(preferred)
	if is_inside_tree():
		var tree := get_tree()
		if not tree.has_meta(BACK_BEHAVIOR_META):
			tree.set_meta(BACK_BEHAVIOR_META, tree.quit_on_go_back)
		tree.quit_on_go_back = false
		var host := get_parent()
		if host != null and host.has_method("_cancel_transient_platform_input"):
			host.call("_cancel_transient_platform_input", "modal_opened")
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and not is_ancestor_of(focus):
			_previous_focus = weakref(focus)
		_order = Time.get_ticks_usec()
		# The most recently opened sibling also needs to be the visual top layer.
		move_to_front()
		_opened = true
		_submitting = false
		show()
		_layout()
		_initial_focus.call_deferred()

func popup(rect: Rect2i = Rect2i()) -> void:
	popup_centered(rect.size)

func popup_centered_clamped(preferred: Vector2i, _fallback_ratio: float = 0.9) -> void:
	popup_centered(preferred)

func request_cancel() -> void:
	if not visible or _submitting:
		return
	hide()
	close_requested.emit()
	canceled.emit()

func _confirm() -> void:
	if _submitting or _ok.disabled or not visible:
		return
	_submitting = true
	if dialog_hide_on_ok:
		hide()
	confirmed.emit()
	_submitting = false

func _visibility_changed() -> void:
	if visible:
		_layout()
	elif _opened:
		_cleanup()

func _exit_tree() -> void:
	if _opened:
		_cleanup()

func _cleanup() -> void:
	_opened = false
	_gesture.cancel()
	_native_text_finger = -1
	Touch.clear_transient_input_state(self, "modal_closed")
	var viewport := get_viewport()
	_quarantine_mouse_echo.call_deferred(weakref(viewport), Time.get_ticks_msec() + 500)
	_restore_back_behavior.call_deferred(weakref(get_tree()))
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
	if _previous_focus != null:
		_restore_focus.call_deferred(_previous_focus)
	_previous_focus = null

static func _restore_back_behavior(reference: WeakRef) -> void:
	var tree := reference.get_ref() as SceneTree
	if tree == null or not tree.has_meta(BACK_BEHAVIOR_META):
		return
	for dialog: Node in tree.get_nodes_in_group(GROUP):
		if dialog.is_visible_in_tree() and not dialog.is_queued_for_deletion():
			return
	tree.quit_on_go_back = bool(tree.get_meta(BACK_BEHAVIOR_META))
	tree.remove_meta(BACK_BEHAVIOR_META)

static func _quarantine_mouse_echo(reference: WeakRef, until_msec: int) -> void:
	var viewport := reference.get_ref() as Viewport
	if not is_instance_valid(viewport) or not viewport.is_inside_tree() or viewport.is_queued_for_deletion():
		return
	var guard := viewport.get_node_or_null("GameModalEchoGuard")
	if guard == null:
		guard = EchoGuard.new()
		guard.name = "GameModalEchoGuard"
		viewport.add_child(guard)
	guard.until_msec = until_msec

static func _restore_focus(previous: WeakRef) -> void:
	var control := previous.get_ref() as Control
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		var ancestor: Node = control
		while ancestor != null:
			if ancestor.is_queued_for_deletion():
				return
			ancestor = ancestor.get_parent()
		control.grab_focus()

static func active_for(node: Node) -> Control:
	if not node.is_inside_tree():
		return null
	var active: Control
	for dialog: Node in node.get_tree().get_nodes_in_group(GROUP):
		if dialog.get_viewport() == node.get_viewport() and dialog.is_visible_in_tree() and not dialog.is_queued_for_deletion():
			if active == null or dialog._order > active._order:
				active = dialog
	return active

func _input(event: InputEvent) -> void:
	if not visible or active_for(self) != self:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		request_cancel()
		return
	# Native text editing/IME keeps key ownership. The gesture owner handles only
	# touch and its synthetic mouse echo, leaving real mouse/wheel input to Godot.
	if not Touch.WebTextInputBridgeScript.is_web_runtime():
		if event is InputEventScreenTouch and event.pressed and Touch.event_targets_native_text_input(self, event):
			_native_text_finger = event.index
			return
		if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index == _native_text_finger:
			if event is InputEventScreenTouch and not event.pressed:
				_native_text_finger = -1
			return
	_gesture.handle(self, event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and active_for(self) == self:
		var tree := get_tree()
		var frame := Engine.get_process_frames()
		if int(tree.get_meta(BACK_FRAME_META, -1)) != frame:
			tree.set_meta(BACK_FRAME_META, frame)
			request_cancel()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_gesture.cancel()
		_native_text_finger = -1
		Touch.clear_transient_input_state(self, "blur" if what == NOTIFICATION_APPLICATION_FOCUS_OUT else "platform_paused")

func _focus_changed(control: Control) -> void:
	if visible and active_for(self) == self and control != null and not is_ancestor_of(control):
		_initial_focus.call_deferred()

func _initial_focus() -> void:
	if not is_inside_tree() or not visible or is_queued_for_deletion() or active_for(self) != self:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		return
	# Do not summon a phone keyboard merely by opening a modal.
	if show_cancel:
		_cancel.grab_focus()
	elif show_header:
		_close.grab_focus()
	elif _ok.visible:
		_ok.grab_focus()

func _process(_delta: float) -> void:
	if not visible:
		return
	var height := DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if height != _keyboard_height:
		_keyboard_height = height
		_layout()

func _layout() -> void:
	if not is_inside_tree():
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var profile := UI.for_control(self)
	var unit: float = profile.scale
	var available := get_viewport_rect().size
	var screen_scale := get_viewport().get_screen_transform().get_scale().y
	available.y -= maxf(0, _keyboard_height) / maxf(0.01, screen_scale)
	var margin := 16.0 * unit
	var desired_scale := unit if scale_content else 1.0
	var target := Vector2(minf(dialog_size.x * desired_scale, available.x - margin * 2), minf(dialog_size.y * desired_scale, available.y - margin * 2))
	target = target.max(Vector2(1, 1))
	_panel.add_theme_stylebox_override("panel", UI.box(UI.SURFACE, UI.LINE, roundi(18 * unit), 20 * unit))
	_column.add_theme_constant_override("separation", roundi(16 * unit))
	_heading.text = title
	_heading.tooltip_text = title
	_header.visible = show_header
	_heading.add_theme_font_size_override("font_size", roundi(22 * unit))
	_message.text = dialog_text
	_message.visible = not dialog_text.is_empty()
	_message.add_theme_font_size_override("font_size", 17)
	_ok.text = ok_button_text
	_cancel.text = cancel_button_text
	_cancel.visible = show_cancel
	_footer.visible = _ok.visible or show_cancel or _footer.get_child_count() > 2
	_footer.add_theme_constant_override("separation", roundi(12 * unit))
	for button: Button in [_close, _cancel, _ok]:
		UI.button(button, unit, button == _ok)
	var content_scale := (unit if scale_content else 1.0) * content_zoom
	var chrome_height := 40 * unit
	if show_header:
		chrome_height += 64 * unit
	if _footer.visible:
		chrome_height += 64 * unit
	var content_height := maxf(maxf(80, content_min_height), (target.y - chrome_height) / content_scale)
	for child: Node in _content.get_children():
		if child is Container:
			content_height = maxf(content_height, child.get_combined_minimum_size().y)
	if not dialog_text.is_empty():
		_content.size.x = maxf(1, target.x - 40 * unit) / content_scale
		content_height = maxf(content_height, _message.get_minimum_size().y)
	_surface.custom_minimum_size = Vector2(0, content_height * content_scale)
	_content.scale = Vector2.ONE * content_scale
	_content.size = Vector2(maxf(1, target.x - 40 * unit) / content_scale, content_height)
	_panel.size = target
	_panel.position = (available - _panel.size) * 0.5
	layout_updated.emit()
