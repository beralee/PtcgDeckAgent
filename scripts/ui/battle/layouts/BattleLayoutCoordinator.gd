class_name BattleLayoutCoordinator
extends RefCounted

const BattleLandscapeLayoutViewScript := preload("res://scripts/ui/battle/layouts/BattleLandscapeLayoutView.gd")
const BattlePortraitLayoutViewScript := preload("res://scripts/ui/battle/layouts/BattlePortraitLayoutView.gd")

var _scene: Node = null
var _metrics_controller: RefCounted = null
var _landscape_view: RefCounted = null
var _portrait_view: RefCounted = null
var _active_view: RefCounted = null


func setup(scene: Node, metrics_controller: RefCounted) -> void:
	_scene = scene
	_metrics_controller = metrics_controller
	_landscape_view = BattleLandscapeLayoutViewScript.new()
	_portrait_view = BattlePortraitLayoutViewScript.new()
	_landscape_view.setup(scene, metrics_controller)
	_portrait_view.setup(scene, metrics_controller)


func is_configured(scene: Node, metrics_controller: RefCounted) -> bool:
	return _scene == scene and _metrics_controller == metrics_controller and _landscape_view != null and _portrait_view != null


func apply(viewport_size: Vector2, preferred_mode: String, is_mobile: bool = false) -> Dictionary:
	if _scene == null or _metrics_controller == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {}

	var resolved_mode := str(_metrics_controller.call("resolve_layout_mode", viewport_size, preferred_mode, is_mobile))
	var rotate_canvas := _should_rotate_portrait_canvas(viewport_size, resolved_mode, preferred_mode)
	var logical_size := _logical_viewport_size(viewport_size, rotate_canvas)
	if _scene.has_method("_apply_battle_canvas_transform"):
		_scene.call("_apply_battle_canvas_transform", rotate_canvas, viewport_size, logical_size)

	var context := {
		"viewport_size": viewport_size,
		"logical_size": logical_size,
		"resolved_mode": resolved_mode,
		"rotate_canvas": rotate_canvas,
		"content_rect": Rect2(Vector2.ZERO, logical_size),
	}

	var next_view: RefCounted = _landscape_view
	if resolved_mode == "portrait":
		var content_rect_variant: Variant = _metrics_controller.call("portrait_content_rect", logical_size)
		context["content_rect"] = content_rect_variant if content_rect_variant is Rect2 else Rect2(Vector2.ZERO, logical_size)
		next_view = _portrait_view

	if _active_view != next_view:
		if _active_view != null:
			_active_view.exit()
		_active_view = next_view

	if _active_view != null:
		_active_view.apply(context)
	return context


func active_mode() -> String:
	return _active_view.mode() if _active_view != null else ""


func prepare_landscape_layout(context: Dictionary) -> void:
	if _landscape_view != null and _landscape_view.has_method("prepare_layout"):
		_landscape_view.call("prepare_layout", context)


func apply_landscape_pile_hud_metrics(preview_card_size: Vector2) -> void:
	if _landscape_view != null and _landscape_view.has_method("apply_pile_hud_metrics"):
		_landscape_view.call("apply_pile_hud_metrics", preview_card_size)


func apply_landscape_status_huds_beside_active(card_size: Vector2, stadium_height: float, row_gap: int) -> void:
	if _landscape_view != null and _landscape_view.has_method("apply_status_huds_beside_active"):
		_landscape_view.call("apply_status_huds_beside_active", card_size, stadium_height, row_gap)


func move_landscape_status_stack_to_active_row(
	stack_name: String,
	left_spacer_name: String,
	right_slot_name: String,
	active_row: HBoxContainer,
	active_card: Control,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer,
	panel_width: float,
	panel_height: float,
	stack_height: float,
	side_column_width: float,
	gap: int
) -> void:
	if _landscape_view != null and _landscape_view.has_method("move_status_stack_to_active_row"):
		_landscape_view.call(
			"move_status_stack_to_active_row",
			stack_name,
			left_spacer_name,
			right_slot_name,
			active_row,
			active_card,
			vstar_panel,
			lost_panel,
			panel_width,
			panel_height,
			stack_height,
			side_column_width,
			gap
		)


func apply_landscape_direct(viewport_size: Vector2) -> void:
	if _scene != null and _scene.has_method("_apply_battle_canvas_transform"):
		_scene.call("_apply_battle_canvas_transform", false, viewport_size, viewport_size)
	if _landscape_view == null:
		return
	if _active_view != _landscape_view:
		if _active_view != null:
			_active_view.exit()
		_active_view = _landscape_view
	_landscape_view.call("apply", {
		"viewport_size": viewport_size,
		"logical_size": viewport_size,
		"resolved_mode": "landscape",
		"rotate_canvas": false,
		"content_rect": Rect2(Vector2.ZERO, viewport_size),
	})


func apply_portrait_base_layout(context: Dictionary) -> void:
	if _portrait_view != null and _portrait_view.has_method("apply_base_layout"):
		_portrait_view.call("apply_base_layout", context)


func apply_portrait_stadium_hud_metrics(viewport_size: Vector2, ui_scale: float) -> void:
	if _portrait_view != null and _portrait_view.has_method("apply_stadium_hud_metrics"):
		_portrait_view.call("apply_stadium_hud_metrics", viewport_size, ui_scale)


func sync_portrait_prize_hud_visibility(is_portrait: Variant = null) -> void:
	if _portrait_view != null and _portrait_view.has_method("sync_prize_hud_visibility"):
		_portrait_view.call("sync_prize_hud_visibility", is_portrait)


func sync_portrait_top_action_visibility(is_portrait: Variant = null) -> void:
	if _portrait_view != null and _portrait_view.has_method("sync_top_action_visibility"):
		_portrait_view.call("sync_top_action_visibility", is_portrait)


func set_portrait_top_status_compact(enabled: bool) -> void:
	if _portrait_view != null and _portrait_view.has_method("set_top_status_compact"):
		_portrait_view.call("set_top_status_compact", enabled)


func set_portrait_turn_action_in_stadium(enabled: bool, action_width: float = 0.0, row_gap: int = 4, action_height: float = 0.0) -> void:
	if _portrait_view != null and _portrait_view.has_method("set_turn_action_in_stadium"):
		_portrait_view.call("set_turn_action_in_stadium", enabled, action_width, row_gap, action_height)


func apply_portrait_field_hud_metrics(viewport_size: Vector2, bench_card_size: Vector2, active_card_size: Vector2 = Vector2.ZERO) -> Dictionary:
	if _portrait_view == null or not _portrait_view.has_method("apply_field_hud_metrics"):
		return {}
	var metrics_variant: Variant = _portrait_view.call("apply_field_hud_metrics", viewport_size, bench_card_size, active_card_size)
	return metrics_variant if metrics_variant is Dictionary else {}


func enforce_portrait_field_axis_width(safe_width: float) -> void:
	if _portrait_view != null and _portrait_view.has_method("enforce_field_axis_width"):
		_portrait_view.call("enforce_field_axis_width", safe_width)


func position_portrait_edge_hud_overlay(viewport_size: Vector2, status_width: float, row_gap: float) -> void:
	if _portrait_view != null and _portrait_view.has_method("position_edge_hud_overlay"):
		_portrait_view.call("position_edge_hud_overlay", viewport_size, status_width, row_gap)


func position_portrait_edge_hud_group(group_name: String, anchor: Vector2, from_left: bool) -> void:
	if _portrait_view != null and _portrait_view.has_method("position_edge_hud_group"):
		_portrait_view.call("position_edge_hud_group", group_name, anchor, from_left)


func set_portrait_huds_on_field_edges(
	enabled: bool,
	status_width: float = 0.0,
	status_panel_height: float = 0.0,
	row_gap: float = 0.0,
	viewport_size: Vector2 = Vector2.ZERO
) -> void:
	if _portrait_view != null and _portrait_view.has_method("set_huds_on_field_edges"):
		_portrait_view.call("set_huds_on_field_edges", enabled, status_width, status_panel_height, row_gap, viewport_size)


func move_portrait_hud_pair_to_field_edges(
	left_group_name: String,
	status_stack_name: String,
	left_hud: PanelContainer,
	right_hud: PanelContainer,
	field_shell: HBoxContainer,
	field_inner: Control,
	active_row: HBoxContainer,
	active_card: Control,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer,
	status_width: float,
	status_panel_height: float,
	row_gap: float
) -> void:
	if _portrait_view != null and _portrait_view.has_method("move_hud_pair_to_field_edges"):
		_portrait_view.call(
			"move_hud_pair_to_field_edges",
			left_group_name,
			status_stack_name,
			left_hud,
			right_hud,
			field_shell,
			field_inner,
			active_row,
			active_card,
			vstar_panel,
			lost_panel,
			status_width,
			status_panel_height,
			row_gap
		)


func apply_portrait_direct(viewport_size: Vector2) -> void:
	if _portrait_view == null:
		return
	var content_rect_variant: Variant = _metrics_controller.call("portrait_content_rect", viewport_size) if _metrics_controller != null else Rect2()
	var frame_rect: Rect2 = content_rect_variant if content_rect_variant is Rect2 else Rect2(Vector2.ZERO, viewport_size)
	var full_size := viewport_size
	if _scene != null and _scene.has_method("_apply_battle_canvas_transform"):
		_scene.call("_apply_battle_canvas_transform", false, viewport_size, full_size)
	_portrait_view.call("apply", {
		"viewport_size": viewport_size,
		"logical_size": full_size,
		"resolved_mode": "portrait",
		"rotate_canvas": false,
		"content_rect": frame_rect,
	})


func _logical_viewport_size(viewport_size: Vector2, rotate_canvas: bool) -> Vector2:
	if rotate_canvas:
		return Vector2(viewport_size.y, viewport_size.x)
	return viewport_size


func _should_rotate_portrait_canvas(viewport_size: Vector2, resolved_mode: String, preferred_mode: String) -> bool:
	if resolved_mode != "portrait":
		return false
	if viewport_size.x <= viewport_size.y:
		return false
	return preferred_mode == "portrait"
