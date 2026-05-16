class_name BattleDrawRevealController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")

const HUMAN_CONFIRM_HINT := "Click to continue"
const AI_HOLD_HINT := "AI drawing..."
const AI_AUTO_CONTINUE_SECONDS := 0.6
const TURN_START_AUTO_CONTINUE_SECONDS := 0.18
const REVEAL_SCALE := Vector2(2.0, 2.0)
const REVEAL_STAGGER_SECONDS := 0.08
const FLY_TO_HAND_SECONDS := 0.08
const DISCARD_FLY_SECONDS := 0.14
const BATCH_MAX_COLUMNS := 4
const BATCH_CARD_GAP := Vector2.ZERO
const BATCH_AREA_PADDING := Vector2(16.0, 16.0)


func enqueue_reveal(scene: Object, action: GameAction) -> void:
	if scene == null or action == null:
		return
	var queue: Array = scene.get("_draw_reveal_queue")
	queue.append(action)
	scene.set("_draw_reveal_queue", queue)
	if action.action_type == GameAction.ActionType.DRAW_CARD:
		scene.set("_draw_reveal_pending_hand_refresh", true)
	_ensure_overlay(scene)
	if scene.get("_draw_reveal_current_action") == null and not _should_defer_for_handover(scene, action.player_index):
		_start_next_reveal(scene)


func confirm_current_reveal(scene: Object) -> void:
	if scene == null or scene.get("_draw_reveal_waiting_for_confirm") != true:
		return
	_begin_fly_to_hand(scene)


func run_auto_continue(scene: Object) -> void:
	if scene == null or scene.get("_draw_reveal_auto_continue_pending") != true:
		return
	_begin_fly_to_hand(scene)


func _draw_fly_duration_seconds() -> float:
	return FLY_TO_HAND_SECONDS


func _discard_fly_duration_seconds() -> float:
	return DISCARD_FLY_SECONDS


func resume_if_ready(scene: Object) -> void:
	if scene == null:
		return
	if scene.get("_draw_reveal_current_action") != null:
		return
	var queue: Array = scene.get("_draw_reveal_queue")
	if queue.is_empty():
		return
	var next_action: GameAction = queue[0] as GameAction
	if _should_defer_for_handover(scene, next_action.player_index):
		return
	_start_next_reveal(scene)


func is_active(scene: Object) -> bool:
	return scene.get("_draw_reveal_active") == true


func _start_next_reveal(scene: Object) -> void:
	var queue: Array = scene.get("_draw_reveal_queue")
	if queue.is_empty():
		_finish_all_reveals(scene)
		return
	var action: GameAction = queue.pop_front() as GameAction
	scene.set("_draw_reveal_queue", queue)
	scene.set("_draw_reveal_current_action", action)
	scene.set("_draw_reveal_active", true)
	scene.set("_draw_reveal_waiting_for_confirm", false)
	scene.set("_draw_reveal_auto_continue_pending", false)
	scene.set("_draw_reveal_pending_hand_refresh", action.action_type == GameAction.ActionType.DRAW_CARD)
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", false)
	scene.set("_draw_reveal_visible_instance_ids", [])
	if action.action_type == GameAction.ActionType.DRAW_CARD and action.player_index == int(scene.get("_view_player")) and scene.has_method("_refresh_hand"):
		scene.set("_draw_reveal_allow_hand_refresh_during_fly", true)
		scene.call("_refresh_hand")
		scene.set("_draw_reveal_allow_hand_refresh_during_fly", false)
	var cards: Array[CardInstance] = _cards_from_action(scene, action)
	if cards.is_empty():
		_finish_current_reveal(scene)
		return
	if action.action_type == GameAction.ActionType.DISCARD:
		_begin_discard_reveal(scene, cards, action.player_index)
		return
	if cards.size() == 1:
		_begin_single_card_reveal(scene, cards[0], action.player_index)
		return
	_begin_batch_reveal(scene, cards, action.player_index)


func _begin_single_card_reveal(scene: Object, card: CardInstance, player_index: int) -> void:
	var overlay: Control = _ensure_overlay(scene)
	var card_view: BattleCardView = _create_reveal_card_view(scene, overlay, card, player_index)
	var staged_views: Array[BattleCardView] = [card_view]
	scene.set("_draw_reveal_card_views", staged_views)
	_position_card_at_deck_origin(scene, card_view, player_index)
	overlay.visible = true
	_set_hint_text(overlay, "")
	var keep_face_down: bool = _should_keep_face_down(scene, player_index)
	var reveal_scale := _reveal_scale(scene)

	if scene is Node and (scene as Node).is_inside_tree():
		var tween: Tween = _create_reveal_tween(scene, card_view, _center_position(scene, card_view), reveal_scale, keep_face_down)
		tween.finished.connect(func() -> void:
			_enter_hold_state(scene, player_index)
		)
		return

	card_view.position = _center_position(scene, card_view)
	card_view.set_face_down(keep_face_down)
	card_view.scale = reveal_scale
	_enter_hold_state(scene, player_index)


func _begin_batch_reveal(scene: Object, cards: Array[CardInstance], player_index: int) -> void:
	var overlay: Control = _ensure_overlay(scene)
	overlay.visible = true
	_set_hint_text(overlay, "")
	var batch_scale: Vector2 = _batch_reveal_scale(scene, _make_probe_card_view(scene), cards.size())
	if scene is Node and (scene as Node).is_inside_tree():
		_reveal_batch_card(scene, overlay, cards, player_index, 0, batch_scale)
		return

	var staged_views: Array[BattleCardView] = []
	var keep_face_down: bool = _should_keep_face_down(scene, player_index)
	for index: int in cards.size():
		var card_view: BattleCardView = _create_reveal_card_view(scene, overlay, cards[index], player_index)
		card_view.position = _batch_stack_position(scene, card_view, index, cards.size())
		card_view.set_face_down(keep_face_down)
		card_view.scale = batch_scale
		staged_views.append(card_view)
	scene.set("_draw_reveal_card_views", staged_views)
	_enter_hold_state(scene, player_index)


func _reveal_batch_card(
	scene: Object,
	overlay: Control,
	cards: Array[CardInstance],
	player_index: int,
	index: int,
	batch_scale: Vector2
) -> void:
	var card_view: BattleCardView = _create_reveal_card_view(scene, overlay, cards[index], player_index)
	var staged_views: Array[BattleCardView] = scene.get("_draw_reveal_card_views")
	staged_views.append(card_view)
	scene.set("_draw_reveal_card_views", staged_views)
	_position_card_at_deck_origin(scene, card_view, player_index)
	var tween: Tween = _create_reveal_tween(
		scene,
		card_view,
		_batch_stack_position(scene, card_view, index, cards.size()),
		batch_scale,
		_should_keep_face_down(scene, player_index)
	)
	tween.finished.connect(func() -> void:
		if index + 1 < cards.size():
			_reveal_batch_card(scene, overlay, cards, player_index, index + 1, batch_scale)
		else:
			_enter_hold_state(scene, player_index)
	)


func _enter_hold_state(scene: Object, player_index: int) -> void:
	var overlay: Control = _ensure_overlay(scene)
	if _should_auto_continue(scene, player_index):
		scene.set("_draw_reveal_auto_continue_pending", true)
		scene.set("_draw_reveal_waiting_for_confirm", false)
		_set_hint_text(overlay, AI_HOLD_HINT if _is_ai_reveal(scene, player_index) else "")
		if scene is Node and (scene as Node).is_inside_tree():
			var timer: SceneTreeTimer = (scene as Node).get_tree().create_timer(_auto_continue_delay_seconds(scene, player_index))
			scene.set("_draw_reveal_resume_timer", timer)
			timer.timeout.connect(func() -> void:
				run_auto_continue(scene)
			)
	else:
		scene.set("_draw_reveal_waiting_for_confirm", true)
		scene.set("_draw_reveal_auto_continue_pending", false)
		_set_hint_text(overlay, HUMAN_CONFIRM_HINT)


func _begin_fly_to_hand(scene: Object) -> void:
	scene.set("_draw_reveal_waiting_for_confirm", false)
	scene.set("_draw_reveal_auto_continue_pending", false)
	scene.set("_draw_reveal_resume_timer", null)
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", true)
	var overlay: Control = _ensure_overlay(scene)
	_set_hint_text(overlay, "")
	var card_views: Array[BattleCardView] = scene.get("_draw_reveal_card_views")
	if card_views.is_empty():
		_finish_current_reveal(scene)
		return
	var action: GameAction = scene.get("_draw_reveal_current_action") as GameAction
	var player_index: int = action.player_index if action != null else int(scene.get("_view_player"))
	if scene is Node and (scene as Node).is_inside_tree():
		var tween: Tween = (scene as Node).create_tween()
		for index: int in card_views.size():
			var card_view: BattleCardView = card_views[index]
			if card_view == null:
				continue
			tween.tween_property(
				card_view,
				"global_position",
				_hand_target_position(scene, card_view, player_index, index, card_views.size()),
				FLY_TO_HAND_SECONDS
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(card_view, "scale", Vector2.ONE, FLY_TO_HAND_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.tween_callback(func() -> void:
				_mark_card_landed(scene, card_view, player_index, index + 1)
			)
		tween.finished.connect(func() -> void:
			_finish_current_reveal(scene)
		)
		return
	for index: int in card_views.size():
		var card_view: BattleCardView = card_views[index]
		if card_view == null:
			continue
		_mark_card_landed(scene, card_view, player_index, index + 1)
	_finish_current_reveal(scene)


func _begin_discard_reveal(scene: Object, cards: Array[CardInstance], player_index: int) -> void:
	var overlay: Control = _ensure_overlay(scene)
	overlay.visible = true
	_set_hint_text(overlay, "")
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", true)
	var staged_views: Array[BattleCardView] = []
	var keep_face_down: bool = _should_keep_face_down(scene, player_index)
	for index: int in cards.size():
		var card_view: BattleCardView = _create_reveal_card_view(scene, overlay, cards[index], player_index)
		card_view.global_position = _discard_source_position(scene, card_view, player_index, index, cards.size())
		card_view.set_face_down(keep_face_down)
		card_view.scale = Vector2.ONE
		staged_views.append(card_view)
	scene.set("_draw_reveal_card_views", staged_views)
	if player_index == int(scene.get("_view_player")) and scene.has_method("_refresh_hand"):
		scene.call("_refresh_hand")
	if not (scene is Node and (scene as Node).is_inside_tree()):
		return
	var tween: Tween = (scene as Node).create_tween()
	for index: int in staged_views.size():
		var card_view: BattleCardView = staged_views[index]
		if card_view == null:
			continue
		tween.tween_property(
			card_view,
			"global_position",
			_discard_target_position(scene, card_view, player_index, index, staged_views.size()),
			DISCARD_FLY_SECONDS
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(card_view, "scale", Vector2(0.72, 0.72), DISCARD_FLY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			_mark_discard_card_landed(scene, card_view, player_index, index + 1)
		)
	tween.finished.connect(func() -> void:
		_finish_current_reveal(scene)
	)


func _finish_current_reveal(scene: Object) -> void:
	_clear_card_views(scene)
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", false)
	scene.set("_draw_reveal_visible_instance_ids", [])
	scene.set("_draw_reveal_current_action", null)
	if (scene.get("_draw_reveal_queue") as Array).is_empty():
		_finish_all_reveals(scene)
	else:
		_start_next_reveal(scene)


func _finish_all_reveals(scene: Object) -> void:
	scene.set("_draw_reveal_active", false)
	scene.set("_draw_reveal_waiting_for_confirm", false)
	scene.set("_draw_reveal_auto_continue_pending", false)
	scene.set("_draw_reveal_current_action", null)
	scene.set("_draw_reveal_resume_timer", null)
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", false)
	scene.set("_draw_reveal_visible_instance_ids", [])
	var overlay: Control = scene.get("_draw_reveal_overlay") as Control
	if overlay != null:
		overlay.visible = false
		_set_hint_text(overlay, "")
	scene.set("_draw_reveal_pending_hand_refresh", false)
	scene.call("_refresh_hand")
	if scene.has_method("_maybe_run_ai"):
		scene.call("_maybe_run_ai")


func _clear_card_views(scene: Object) -> void:
	var card_views: Array[BattleCardView] = scene.get("_draw_reveal_card_views")
	for card_view: BattleCardView in card_views:
		if card_view == null:
			continue
		if is_instance_valid(card_view):
			card_view.queue_free()
	var cleared_views: Array[BattleCardView] = []
	scene.set("_draw_reveal_card_views", cleared_views)


func _create_reveal_card_view(scene: Object, overlay: Control, card: CardInstance, player_index: int) -> BattleCardView:
	var stage: Control = overlay.get_node("Stage") as Control
	var card_view: BattleCardView = BattleCardViewScript.new()
	card_view.name = "DrawRevealCard"
	card_view.custom_minimum_size = scene.get("_play_card_size")
	card_view.set_clickable(false)
	card_view.setup_from_instance(card, BattleCardViewScript.MODE_PREVIEW)
	card_view.set_back_texture(_back_texture_for_player(scene, player_index))
	card_view.set_face_down(true)
	card_view.scale = Vector2.ONE
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(card_view)
	return card_view


func _create_reveal_tween(
	scene: Object,
	card_view: BattleCardView,
	target_position: Vector2,
	target_scale: Vector2 = REVEAL_SCALE,
	keep_face_down: bool = false
) -> Tween:
	card_view.pivot_offset = _card_visual_size(card_view) * 0.5
	var tween: Tween = (scene as Node).create_tween()
	tween.tween_property(card_view, "global_position", target_position, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "scale", target_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not keep_face_down:
		tween.tween_interval(REVEAL_STAGGER_SECONDS)
		tween.tween_callback(func() -> void:
			if is_instance_valid(card_view):
				card_view.set_face_down(false)
		)
	return tween


func _make_probe_card_view(scene: Object) -> BattleCardView:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = scene.get("_play_card_size")
	return card_view


func _cards_from_action(scene: Object, action: GameAction) -> Array[CardInstance]:
	if scene == null or action == null:
		return []
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return []
	var player_index: int = action.player_index
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return []
	var source_cards: Array[CardInstance] = gsm.game_state.players[player_index].hand
	if action.action_type == GameAction.ActionType.DISCARD and str(action.data.get("source_zone", "")) == "hand":
		source_cards = gsm.game_state.players[player_index].discard_pile
	var by_id: Dictionary = {}
	for card: CardInstance in source_cards:
		by_id[card.instance_id] = card
	var ordered: Array[CardInstance] = []
	for id_variant: Variant in action.data.get("card_instance_ids", []):
		var instance_id: int = int(id_variant)
		if by_id.has(instance_id):
			ordered.append(by_id[instance_id])
	return ordered


func _ensure_overlay(scene: Object) -> Control:
	var overlay: Control = scene.get("_draw_reveal_overlay") as Control
	if overlay != null:
		return overlay
	overlay = _build_overlay(scene)
	scene.set("_draw_reveal_overlay", overlay)
	if overlay.get_parent() == null and scene is Node:
		(scene as Node).add_child(overlay)
	if scene.has_method("_apply_portrait_popup_text_metrics"):
		scene.call("_apply_portrait_popup_text_metrics")
	return overlay


func _build_overlay(scene: Object) -> Control:
	var overlay: Control = Control.new()
	overlay.name = "DrawRevealOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	overlay.visible = false
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if scene.get("_draw_reveal_waiting_for_confirm") != true:
			return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_current_reveal(scene)
	)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(shade)

	var stage: Control = Control.new()
	stage.name = "Stage"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(stage)

	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(0.98, 0.96, 0.88, 0.95)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-120, -80)
	hint.custom_minimum_size = Vector2(240, 28)
	overlay.add_child(hint)

	return overlay


func _set_hint_text(overlay: Control, text: String) -> void:
	if overlay == null:
		return
	var hint: Label = overlay.get_node_or_null("Hint") as Label
	if hint != null:
		hint.text = text
		hint.visible = text != ""


func _position_card_at_deck_origin(scene: Object, card_view: Control, player_index: int) -> void:
	if card_view == null:
		return
	var preview: Control = null
	var view_player: int = int(scene.get("_view_player"))
	if player_index == view_player:
		preview = scene.get("_my_deck_preview")
	elif player_index == 1 - view_player:
		preview = scene.get("_opp_deck_preview")
	if preview != null:
		card_view.global_position = preview.global_position
	else:
		card_view.position = Vector2.ZERO


func _center_position(scene: Object, card_view: Control) -> Vector2:
	var card_size: Vector2 = _card_visual_size(card_view)
	var anchor_rect: Rect2 = _get_reveal_anchor_rect(scene)
	if anchor_rect.size != Vector2.ZERO:
		return Vector2(
			anchor_rect.position.x + (anchor_rect.size.x - card_size.x) * 0.5,
			anchor_rect.position.y + (anchor_rect.size.y - card_size.y) * 0.5
		)
	var viewport_size: Vector2 = Vector2(1280, 720)
	if scene is Node and (scene as Node).get_viewport() != null:
		viewport_size = (scene as Node).get_viewport().get_visible_rect().size
	return Vector2(
		(viewport_size.x - card_size.x) * 0.5,
		(viewport_size.y - card_size.y) * 0.5
	)


func _batch_stack_position(scene: Object, card_view: Control, index: int, total: int) -> Vector2:
	var scale: Vector2 = _batch_reveal_scale(scene, card_view, total)
	var card_size: Vector2 = _card_visual_size(card_view) * scale
	var anchor_rect: Rect2 = _get_reveal_anchor_rect(scene)
	var batch_center: Vector2 = _center_position(scene, card_view) + _card_visual_size(card_view) * 0.5
	if anchor_rect.size != Vector2.ZERO:
		batch_center = anchor_rect.position + anchor_rect.size * 0.5
	var columns := _batch_column_count(scene, card_view, total)
	var gap := _batch_card_gap(scene)
	var row: int = index / columns
	var row_count: int = int(ceil(float(total) / float(columns)))
	var row_items: int = mini(columns, total - row * columns)
	var total_height: float = row_count * card_size.y + maxi(0, row_count - 1) * gap.y
	var row_width: float = row_items * card_size.x + maxi(0, row_items - 1) * gap.x
	var column: int = index % columns
	var top_left_y: float = batch_center.y - total_height * 0.5 + row * (card_size.y + gap.y)
	var top_left_x: float = batch_center.x - row_width * 0.5 + column * (card_size.x + gap.x)
	return Vector2(top_left_x, top_left_y)


func _batch_reveal_scale(scene: Object, card_view: Control, total: int) -> Vector2:
	return _reveal_scale(scene)


func _reveal_scale(scene: Object) -> Vector2:
	if _is_portrait_reveal_layout(scene):
		return Vector2.ONE
	return REVEAL_SCALE


func _is_portrait_reveal_layout(scene: Object) -> bool:
	return scene != null and scene.has_method("_is_portrait_battle_layout_active") and bool(scene.call("_is_portrait_battle_layout_active"))


func _batch_column_count(scene: Object, card_view: Control, total: int) -> int:
	var max_columns := mini(BATCH_MAX_COLUMNS, maxi(total, 1))
	if not _is_portrait_reveal_layout(scene):
		return max_columns
	var anchor_rect := _get_reveal_anchor_rect(scene)
	if anchor_rect.size.x <= 0.0:
		return max_columns
	var gap := _batch_card_gap(scene)
	var card_width := maxf(_card_visual_size(card_view).x * _batch_reveal_scale(scene, card_view, total).x, 1.0)
	var available_width := maxf(anchor_rect.size.x - BATCH_AREA_PADDING.x * 2.0, card_width)
	var columns_fit := int(floor((available_width + gap.x) / (card_width + gap.x)))
	return clampi(columns_fit, 1, max_columns)


func _batch_card_gap(scene: Object) -> Vector2:
	if _is_portrait_reveal_layout(scene):
		return Vector2.ZERO
	return BATCH_CARD_GAP


func _hand_target_anchor(scene: Object, player_index: int) -> Control:
	if not (scene is Node):
		return null
	var scene_node: Node = scene as Node
	if _uses_top_center_hand_target(scene, player_index):
		return scene_node.get_node_or_null("MainArea/CenterField") as Control
	return scene_node.get_node_or_null("MainArea/CenterField/HandArea") as Control


func _hand_target_position(scene: Object, card_view: Control, player_index: int, index: int = 0, total: int = 1) -> Vector2:
	var hand_anchor: Control = _hand_target_anchor(scene, player_index)
	if hand_anchor == null:
		return _center_position(scene, card_view)
	var card_size: Vector2 = _card_visual_size(card_view)
	var target: Vector2 = _hand_target_base_position(hand_anchor, card_size, _uses_top_center_hand_target(scene, player_index))
	var centered_index: float = float(index) - (float(total - 1) * 0.5)
	return Vector2(
		target.x + centered_index * 14.0,
		target.y + centered_index * 4.0
	)


func _hand_target_base_position(anchor: Control, card_size: Vector2, use_top_center: bool) -> Vector2:
	if anchor == null:
		return Vector2.ZERO
	var x: float = anchor.global_position.x + (anchor.size.x - card_size.x) * 0.5
	var y: float
	if use_top_center:
		y = anchor.global_position.y + 16.0
	else:
		y = anchor.global_position.y + (anchor.size.y - card_size.y) * 0.5
	return Vector2(x, y)


func _discard_source_position(scene: Object, card_view: Control, player_index: int, index: int = 0, total: int = 1) -> Vector2:
	return _hand_target_position(scene, card_view, player_index, index, total)


func _discard_target_position(scene: Object, card_view: Control, player_index: int, index: int = 0, total: int = 1) -> Vector2:
	var discard_preview: Control = _discard_target_anchor(scene, player_index)
	if discard_preview == null:
		return _center_position(scene, card_view)
	var card_size: Vector2 = _card_visual_size(card_view)
	var target := Vector2(
		discard_preview.global_position.x + (discard_preview.size.x - card_size.x * 0.72) * 0.5,
		discard_preview.global_position.y + (discard_preview.size.y - card_size.y * 0.72) * 0.5
	)
	var centered_index: float = float(index) - (float(total - 1) * 0.5)
	return Vector2(target.x + centered_index * 10.0, target.y + centered_index * 3.0)


func _discard_target_anchor(scene: Object, player_index: int) -> Control:
	if player_index == int(scene.get("_view_player")):
		return scene.get("_my_discard_preview") as Control
	return scene.get("_opp_discard_preview") as Control


func _card_visual_size(card_view: Control) -> Vector2:
	var card_size: Vector2 = card_view.size if card_view.size != Vector2.ZERO else card_view.custom_minimum_size
	if card_size == Vector2.ZERO:
		return Vector2(130, 182)
	return card_size


func _get_center_field(scene: Object) -> Control:
	if not (scene is Node):
		return null
	var scene_node: Node = scene as Node
	return scene_node.get_node_or_null("MainArea/CenterField") as Control


func _get_reveal_anchor_rect(scene: Object) -> Rect2:
	if not (scene is Node):
		return Rect2()
	var scene_node: Node = scene as Node
	if scene_node.has_method("_draw_reveal_anchor_rect"):
		var custom_rect_variant: Variant = scene_node.call("_draw_reveal_anchor_rect")
		if custom_rect_variant is Rect2:
			var custom_rect: Rect2 = custom_rect_variant
			if custom_rect.size != Vector2.ZERO:
				return _local_rect_to_global_bounds(scene_node, custom_rect)
	if scene_node is Control:
		var scene_control := scene_node as Control
		if scene_control.size != Vector2.ZERO:
			return Rect2(scene_control.global_position, scene_control.size)
	var main_area: Control = scene_node.get_node_or_null("MainArea") as Control
	if main_area != null:
		return Rect2(main_area.global_position, main_area.size)
	var center_field: Control = _get_center_field(scene)
	if center_field != null:
		return Rect2(center_field.global_position, center_field.size)
	return Rect2()


func _local_rect_to_global_bounds(scene_node: Node, local_rect: Rect2) -> Rect2:
	if not scene_node is CanvasItem:
		return local_rect
	var canvas_item := scene_node as CanvasItem
	var x0 := local_rect.position.x
	var y0 := local_rect.position.y
	var x1 := local_rect.position.x + local_rect.size.x
	var y1 := local_rect.position.y + local_rect.size.y
	var transform := canvas_item.get_global_transform()
	var points: Array[Vector2] = [
		transform * Vector2(x0, y0),
		transform * Vector2(x1, y0),
		transform * Vector2(x0, y1),
		transform * Vector2(x1, y1),
	]
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point: Vector2 in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	min_point = _snap_vector2_to_zero(min_point)
	max_point = _snap_vector2_to_zero(max_point)
	return Rect2(min_point, max_point - min_point)


func _snap_vector2_to_zero(value: Vector2) -> Vector2:
	if absf(value.x) < 0.001:
		value.x = 0.0
	if absf(value.y) < 0.001:
		value.y = 0.0
	return value


func _should_defer_for_handover(scene: Object, player_index: int) -> bool:
	if GameManager.current_mode != GameManager.GameMode.TWO_PLAYER:
		return false
	var handover_panel: Control = scene.get("_handover_panel") as Control
	if handover_panel != null and handover_panel.visible:
		return true
	var pending_handover: Callable = scene.get("_pending_handover_action") as Callable
	if pending_handover.is_valid():
		return true
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return false
	return player_index == gsm.game_state.current_player_index and player_index != int(scene.get("_view_player"))


func _is_ai_reveal(_scene: Object, player_index: int) -> bool:
	return GameManager.current_mode == GameManager.GameMode.VS_AI and player_index == 1


func _is_hidden_two_player_reveal(scene: Object, player_index: int) -> bool:
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and player_index != int(scene.get("_view_player"))


func _is_hidden_opponent_reveal(scene: Object, player_index: int) -> bool:
	if player_index == int(scene.get("_view_player")):
		return false
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER or GameManager.current_mode == GameManager.GameMode.VS_AI


func _uses_top_center_hand_target(scene: Object, player_index: int) -> bool:
	return _is_hidden_opponent_reveal(scene, player_index)


func _should_keep_face_down(scene: Object, player_index: int) -> bool:
	return _is_hidden_opponent_reveal(scene, player_index)


func _should_auto_continue(scene: Object, player_index: int) -> bool:
	return _is_turn_start_draw_reveal(scene) or _is_ai_reveal(scene, player_index) or _is_hidden_two_player_reveal(scene, player_index)


func _auto_continue_delay_seconds(scene: Object, player_index: int) -> float:
	if _is_turn_start_draw_reveal(scene) and not _is_ai_reveal(scene, player_index):
		return TURN_START_AUTO_CONTINUE_SECONDS
	return AI_AUTO_CONTINUE_SECONDS


func _is_turn_start_draw_reveal(scene: Object) -> bool:
	var action: GameAction = scene.get("_draw_reveal_current_action") as GameAction
	if action == null or action.action_type != GameAction.ActionType.DRAW_CARD:
		return false
	return bool(action.data.get("turn_start", false)) or str(action.data.get("draw_source", "")) == "turn_start"


func _back_texture_for_player(scene: Object, player_index: int) -> Texture2D:
	if _is_hidden_opponent_reveal(scene, player_index):
		return scene.get("_opponent_card_back_texture") as Texture2D
	return scene.get("_player_card_back_texture") as Texture2D


func _set_visible_reveal_count(scene: Object, visible_count: int) -> void:
	var action: GameAction = scene.get("_draw_reveal_current_action") as GameAction
	if action == null:
		scene.set("_draw_reveal_visible_instance_ids", [])
		return
	var visible_ids: Array[int] = []
	var reveal_ids: Array = action.data.get("card_instance_ids", [])
	for index: int in mini(visible_count, reveal_ids.size()):
		visible_ids.append(int(reveal_ids[index]))
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", true)
	scene.set("_draw_reveal_visible_instance_ids", visible_ids)


func _mark_card_landed(scene: Object, card_view: BattleCardView, player_index: int, landed_count: int) -> void:
	_set_visible_reveal_count(scene, landed_count)
	if card_view != null and is_instance_valid(card_view):
		card_view.visible = false
	if player_index == int(scene.get("_view_player")):
		scene.call("_refresh_hand")


func _mark_discard_card_landed(scene: Object, card_view: BattleCardView, _player_index: int, landed_count: int) -> void:
	_set_visible_reveal_count(scene, landed_count)
	if card_view != null and is_instance_valid(card_view):
		card_view.visible = false
	if scene.has_method("_refresh_ui"):
		scene.call("_refresh_ui")
