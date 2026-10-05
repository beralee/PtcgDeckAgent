extends RefCounted
## Mouse gestures only. Execution remains in BattleScene's existing action owner.
var scene: Control
var card: CardInstance
var card_view: Control
var start := Vector2.ZERO
var active := false
var signature := ""
var ghost: Control

func handle(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and card != null:
		cancel()
		return true
	var presenter := scene.get_node_or_null("Arena3DPresenter")
	if presenter == null: return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cancel()
			if scene.call("_is_board_modal_overlay_visible") or not scene.call("_can_view_player_start_turn_action") or str(scene.get("_pending_choice")) != "": return false
			card_view = scene.call("_battle_hand_card_at_screen_position",event.position)
			if card_view != null:
				card = card_view.card_instance
				start = event.position
				signature = current_signature(presenter)
			return false
		if card == null: return false
		if not active:
			cancel()
			return false
		var chosen := card
		var fresh := signature == current_signature(presenter)
		var local: Vector2 = presenter.get_global_transform().affine_inverse() * event.position
		var id: String = presenter.world.hit_slot(local) if presenter.get_global_rect().has_point(event.position) else ""
		var in_board: bool = presenter.get_global_rect().has_point(event.position)
		cancel()
		if not fresh or scene.call("_is_board_modal_overlay_visible") or not scene.call("_can_view_player_start_turn_action"): return true
		var gs: GameState = scene.get("_gsm").game_state
		if chosen not in gs.players[int(scene.get("_view_player"))].hand: return true
		var cd: CardData = chosen.card_data
		if not in_board: return true
		if cd.is_pokemon() or cd.card_type in ["Basic Energy","Special Energy","Tool"]:
			if not id.begins_with("my_"): return true
			# Select and resolve through the same guarded handlers as two clicks.
			scene.call("_on_hand_card_clicked",chosen,null)
			if scene.get("_selected_hand_card") == chosen: scene.call("_handle_slot_left_click",id)
		else:
			scene.call("_on_hand_card_clicked",chosen,null)
		return true
	if event is InputEventMouseMotion and card != null:
		if not active:
			var delta: Vector2 = event.position-start
			# Horizontal movement inside the hand scrolls the row. Leaving its
			# top edge promotes the same gesture to card dragging, including a
			# diagonal drag from a card at either end of a large hand.
			var hand_rect: Rect2 = scene.get("_hand_scroll").get_global_rect()
			if delta.y > -18 or event.position.y >= hand_rect.position.y + 8: return false
			active = true
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.position = start
			release.global_position = start
			scene.call("_handle_hand_drag_scroll_input",release,"arena_card_drag")
			scene.call("_clear_hand_drag_click_suppression","arena_card_drag")
			if is_instance_valid(card_view):
				card_view.set("_hand_primary_press_active",false)
			ghost = load("res://scenes/battle/BattleCardView.gd").new()
			ghost.setup_from_instance(card, "preview")
			ghost.custom_minimum_size = Vector2(106,148)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost.z_index = 90
			scene.add_child(ghost)
			ghost.modulate.a = .88
		if signature != current_signature(presenter):
			cancel()
			return true
		ghost.position = event.position - Vector2(53,100)
		presenter.world.hover_id = presenter.world.hit_slot(presenter.get_global_transform().affine_inverse() * event.position)
		return true
	return false

func current_signature(presenter: Control) -> String:
	var gsm = scene.get("_gsm")
	var frame: Dictionary = preload("res://scenes/arena3d/ArenaFrame.gd").capture(gsm.game_state,int(scene.get("_view_player")))
	return presenter._input_signature(frame)

func cancel() -> void:
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = null
	card = null
	card_view = null
	active = false
