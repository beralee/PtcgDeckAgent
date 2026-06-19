class_name BattleStadiumHudCoordinator
extends RefCounted

const BATTLE_CARD_VIEW := preload("res://scenes/battle/BattleCardView.gd")
const STADIUM_CARD_OVERLAY_Z_INDEX := 70
const PORTRAIT_STADIUM_CARD_SCALE := 2.0 / 3.0
const PORTRAIT_EMPTY_STADIUM_HUD_TEXT := "竞技场区"

var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func ensure_stadium_card_overlay() -> Control:
	var cached := _get("_stadium_card_overlay") as Control
	if cached != null and is_instance_valid(cached):
		return cached
	var overlay := _find("StadiumCardOverlay", true, false) as Control
	if overlay == null:
		overlay = Control.new()
		overlay.name = "StadiumCardOverlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _scene != null and overlay.get_parent() != _scene:
		var old_parent := overlay.get_parent()
		if old_parent != null:
			old_parent.remove_child(overlay)
		_scene.add_child(overlay)
		overlay.owner = _scene.owner
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.z_as_relative = false
	overlay.z_index = STADIUM_CARD_OVERLAY_Z_INDEX
	overlay.clip_contents = false
	_set_scene_var("_stadium_card_overlay", overlay)
	if _scene != null and _scene.has_method("_sync_portrait_modal_overlay_rects"):
		_scene.call("_sync_portrait_modal_overlay_rects")
	return overlay


func ensure_stadium_card_view() -> BattleCardView:
	var cached := _get("_stadium_card_view") as BattleCardView
	if cached != null and is_instance_valid(cached):
		var existing_overlay := ensure_stadium_card_overlay()
		if existing_overlay != null and cached.get_parent() != existing_overlay:
			var current_parent := cached.get_parent()
			if current_parent != null:
				current_parent.remove_child(cached)
			existing_overlay.add_child(cached)
			cached.owner = existing_overlay.owner
		return cached
	var overlay := ensure_stadium_card_overlay()
	if overlay == null:
		return null
	var existing := overlay.get_node_or_null("StadiumCardView") as BattleCardView
	if existing == null:
		existing = _find("StadiumCardView", true, false) as BattleCardView
	var card_view: BattleCardView = existing if existing != null else BATTLE_CARD_VIEW.new()
	_set_scene_var("_stadium_card_view", card_view)
	card_view.name = "StadiumCardView"
	card_view.visible = false
	card_view.custom_minimum_size = Vector2.ZERO
	card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
	card_view.set_compact_preview(true)
	if card_view.has_method("set_wide_preview"):
		card_view.call("set_wide_preview", false)
	card_view.set_clickable(true)
	card_view.set_secondary_inspect_enabled(true)
	card_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_view.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	if card_view.get_parent() != overlay:
		var old_parent := card_view.get_parent()
		if old_parent != null:
			old_parent.remove_child(card_view)
		overlay.add_child(card_view)
		card_view.owner = overlay.owner
	var left_cb := Callable(_scene, "_on_stadium_card_left_clicked")
	if not card_view.left_clicked.is_connected(left_cb):
		card_view.left_clicked.connect(left_cb)
	var right_cb := Callable(_scene, "_on_stadium_card_right_clicked")
	if not card_view.right_clicked.is_connected(right_cb):
		card_view.right_clicked.connect(right_cb)
	return card_view


func apply_stadium_card_view_metrics(width: float, height: float) -> void:
	var resolved_size := Vector2(maxf(width, 1.0), maxf(height, 1.0))
	if bool(_call("_is_portrait_battle_layout_active")):
		resolved_size = Vector2(
			maxf(resolved_size.x * PORTRAIT_STADIUM_CARD_SCALE, 1.0),
			maxf(resolved_size.y * PORTRAIT_STADIUM_CARD_SCALE, 1.0)
		)
	_set_scene_var("_stadium_card_view_metrics", resolved_size)
	var card_view := _get("_stadium_card_view") as BattleCardView
	if card_view == null or not is_instance_valid(card_view):
		return
	card_view.custom_minimum_size = resolved_size
	card_view.size = resolved_size
	card_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	position_stadium_card_view()


func position_stadium_card_view() -> void:
	var overlay := ensure_stadium_card_overlay()
	var card_view := _get("_stadium_card_view") as BattleCardView
	if overlay == null or card_view == null or not is_instance_valid(card_view):
		return
	var card_size_variant: Variant = _get("_stadium_card_view_metrics")
	var card_size: Vector2 = card_size_variant if card_size_variant is Vector2 else Vector2.ZERO
	if card_size == Vector2.ZERO:
		var active_size_variant: Variant = _get("_field_active_card_size")
		var play_size_variant: Variant = _get("_play_card_size")
		var active_size: Vector2 = active_size_variant if active_size_variant is Vector2 else Vector2.ZERO
		var play_size: Vector2 = play_size_variant if play_size_variant is Vector2 else Vector2.ZERO
		card_size = active_size if active_size != Vector2.ZERO else play_size
	card_size = Vector2(maxf(card_size.x, 1.0), maxf(card_size.y, 1.0))
	var anchor_rect := stadium_card_anchor_rect()
	var target_position := anchor_rect.position + (anchor_rect.size - card_size) * 0.5
	var root_control := _scene as Control
	var bounds_size := root_control.size if root_control != null else Vector2.ZERO
	if bounds_size == Vector2.ZERO and _scene != null and _scene.is_inside_tree():
		bounds_size = _scene.get_viewport().get_visible_rect().size
	if bounds_size.x > 0.0 and bounds_size.y > 0.0:
		target_position.x = clampf(target_position.x, 2.0, maxf(2.0, bounds_size.x - card_size.x - 2.0))
		target_position.y = clampf(target_position.y, 2.0, maxf(2.0, bounds_size.y - card_size.y - 2.0))
	card_view.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	card_view.position = target_position.round()
	card_view.custom_minimum_size = card_size
	card_view.size = card_size


func stadium_card_anchor_rect() -> Rect2:
	var stadium_center := _get("_stadium_center_section") as Control
	if stadium_center == null:
		stadium_center = _find("StadiumCenterSection", true, false) as Control
	var anchor_rect := _as_rect(_call("_control_rect_in_battle_local", [stadium_center]), Rect2())
	if anchor_rect.size != Vector2.ZERO:
		return anchor_rect
	var action_row := _call("_stadium_action_row_node") as Control
	anchor_rect = _as_rect(_call("_control_rect_in_battle_local", [action_row]), Rect2())
	if anchor_rect.size != Vector2.ZERO:
		return anchor_rect
	var root_control := _scene as Control
	var root_size := root_control.size if root_control != null else Vector2.ZERO
	if root_size == Vector2.ZERO and _scene != null and _scene.is_inside_tree():
		root_size = _scene.get_viewport().get_visible_rect().size
	return Rect2(root_size * 0.5, Vector2.ZERO)


func stadium_action_effect(gs: GameState) -> BaseEffect:
	var gsm: Variant = _get("_gsm")
	if gsm == null or gs == null or gs.stadium_card == null or gs.stadium_card.card_data == null:
		return null
	return gsm.effect_processor.get_effect(gs.stadium_card.card_data.effect_id)


func is_action_stadium(gs: GameState) -> bool:
	var effect := stadium_action_effect(gs)
	return effect != null and effect.can_use_as_stadium_action(gs.stadium_card, gs)


func is_stadium_effect_used_this_turn(gs: GameState, player_index: int) -> bool:
	if gs == null or gs.stadium_card == null or gs.stadium_card.card_data == null:
		return false
	return (
		gs.stadium_effect_used_turn == gs.turn_number
		and gs.stadium_effect_used_player == player_index
		and gs.stadium_effect_used_effect_id == gs.stadium_card.card_data.effect_id
	)


func set_legacy_stadium_hud_visible(visible: bool) -> void:
	var action_row := _call("_stadium_action_row_node") as HBoxContainer
	var stadium_label := _get("_stadium_lbl") as Label
	if stadium_label == null:
		stadium_label = _find("StadiumLbl", true, false) as Label
	var stadium_button := _get("_btn_stadium_action") as Button
	if stadium_button == null:
		stadium_button = _find("BtnStadiumAction", true, false) as Button
	var stadium_center := _get("_stadium_center_section") as PanelContainer
	if stadium_center == null:
		stadium_center = _find("StadiumCenterSection", true, false) as PanelContainer
	if stadium_center != null:
		stadium_center.self_modulate = Color(1, 1, 1, 1 if visible else 0)
		stadium_center.mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	if action_row != null:
		action_row.visible = true
	if stadium_label != null:
		stadium_label.visible = visible
	if stadium_button != null:
		stadium_button.visible = false
		stadium_button.disabled = true


func refresh_stadium_card_hud(gs: GameState, current_player: int, is_my_turn: bool) -> void:
	var stadium_label := _get("_stadium_lbl") as Label
	if stadium_label == null:
		stadium_label = _find("StadiumLbl", true, false) as Label
	var stadium_button := _get("_btn_stadium_action") as Button
	if stadium_button == null:
		stadium_button = _find("BtnStadiumAction", true, false) as Button
	if gs == null or gs.stadium_card == null:
		var existing_card_view := _get("_stadium_card_view") as BattleCardView
		if existing_card_view != null and is_instance_valid(existing_card_view):
			existing_card_view.visible = false
			existing_card_view.custom_minimum_size = Vector2.ZERO
			existing_card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
			existing_card_view.set_badges("", "")
		var show_empty_stadium_hud := str(_get("_active_battle_layout_mode")) != "landscape"
		set_legacy_stadium_hud_visible(show_empty_stadium_hud)
		if stadium_label != null:
			stadium_label.text = PORTRAIT_EMPTY_STADIUM_HUD_TEXT if bool(_call("_is_portrait_battle_layout_active")) else _bt("battle.stadium.none")
			stadium_label.visible = show_empty_stadium_hud
		if stadium_button != null:
			stadium_button.visible = false
			stadium_button.disabled = true
		return

	var card_view := ensure_stadium_card_view()
	set_legacy_stadium_hud_visible(false)
	if stadium_label != null:
		stadium_label.visible = false
	if stadium_button != null:
		stadium_button.visible = false
		stadium_button.disabled = true
	if card_view == null:
		if stadium_label != null:
			stadium_label.visible = true
			stadium_label.text = _bt("battle.stadium.label", {"name": gs.stadium_card.card_data.name})
		return

	card_view.visible = true
	var metrics_variant: Variant = _get("_stadium_card_view_metrics")
	var metrics: Vector2 = metrics_variant if metrics_variant is Vector2 else Vector2.ZERO
	card_view.custom_minimum_size = metrics if metrics != Vector2.ZERO else card_view.custom_minimum_size
	if card_view.card_instance != gs.stadium_card:
		card_view.setup_from_instance(gs.stadium_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
	card_view.set_compact_preview(true)
	if card_view.has_method("set_wide_preview"):
		card_view.call("set_wide_preview", false)
	card_view.set_clickable(true)
	card_view.set_secondary_inspect_enabled(true)
	card_view.set_disabled(false)
	card_view.set_selectable_hint(false)
	card_view.set_info("", "")
	var gsm: Variant = _get("_gsm")
	var is_action := is_action_stadium(gs)
	var can_use: bool = is_action and is_my_turn and gsm != null and bool(gsm.can_use_stadium_effect(current_player))
	var used: bool = is_action and is_stadium_effect_used_this_turn(gs, current_player)
	card_view.set_badges("USED" if used else "", "USE" if can_use else "")
	card_view.tooltip_text = "点击：打开竞技场行动；右键或长按：查看卡牌详情。"
	position_stadium_card_view()
	_call("_request_stadium_hud_debug_overlay_refresh")


func _bt(key: String, params: Dictionary = {}) -> String:
	var translated: Variant = _call("_bt", [key, params])
	return str(translated) if translated != null else key


func _get(property_name: StringName) -> Variant:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get(property_name)


func _set_scene_var(property_name: StringName, value: Variant) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_scene.set(property_name, value)


func _call(method_name: StringName, args: Array = []) -> Variant:
	if _scene == null or not is_instance_valid(_scene) or not _scene.has_method(method_name):
		return null
	return _scene.callv(method_name, args)


func _node(path: NodePath) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(path)


func _find(name: String, recursive: bool = true, owned: bool = false) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.find_child(name, recursive, owned)


func _as_rect(value: Variant, fallback: Rect2) -> Rect2:
	return value if value is Rect2 else fallback
