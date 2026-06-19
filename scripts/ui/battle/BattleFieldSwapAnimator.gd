class_name BattleFieldSwapAnimator
extends RefCounted

const OVERLAY_NAME := "FieldSwapOverlay"
const MOVE_SECONDS := 0.28
const HIDDEN_SLOT_ALPHA := 0.18
const MAX_FIELD_BENCH_SIZE := 8
const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")


func capture_field_snapshot(gs: GameState, view_player: int) -> Dictionary:
	if gs == null or gs.players.size() < 2:
		return {}
	var opponent_player := 1 - view_player
	if view_player < 0 or view_player >= gs.players.size() or opponent_player < 0 or opponent_player >= gs.players.size():
		return {}
	var slots: Dictionary = {}
	_capture_player_slots(slots, "my", gs.players[view_player])
	_capture_player_slots(slots, "opp", gs.players[opponent_player])
	return {
		"view_player": view_player,
		"slots": slots,
	}


func detect_active_bench_swap(before_snapshot: Dictionary, after_snapshot: Dictionary, _action: GameAction = null) -> Dictionary:
	return detect_active_field_movement(before_snapshot, after_snapshot)


func detect_active_field_movement(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Dictionary:
	if before_snapshot.is_empty() or after_snapshot.is_empty():
		return {}
	if int(before_snapshot.get("view_player", -1)) != int(after_snapshot.get("view_player", -2)):
		return {}
	var before_slots: Dictionary = before_snapshot.get("slots", {})
	var after_slots: Dictionary = after_snapshot.get("slots", {})
	if before_slots.is_empty() or after_slots.is_empty():
		return {}
	var all_moves: Array[Dictionary] = []
	var involved_slot_ids: Array = []
	for prefix: String in ["my", "opp"]:
		var movement := _detect_side_active_field_movement(prefix, before_slots, after_slots)
		var moves: Array = movement.get("moves", [])
		for move_variant: Variant in moves:
			if move_variant is Dictionary:
				all_moves.append(move_variant as Dictionary)
		involved_slot_ids.append_array(movement.get("involved_slot_ids", []))
	if all_moves.is_empty():
		return {}
	return {
		"involved_slot_ids": _unique_strings(involved_slot_ids),
		"moves": all_moves,
	}


func play_detected_swap(scene: Object, before_snapshot: Dictionary, after_snapshot: Dictionary, _action: GameAction = null) -> bool:
	return play_detected_field_movement(scene, before_snapshot, after_snapshot)


func play_detected_field_movement(scene: Object, before_snapshot: Dictionary, after_snapshot: Dictionary) -> bool:
	var movement := detect_active_field_movement(before_snapshot, after_snapshot)
	if movement.is_empty():
		return false
	play_swap(scene, movement)
	return true


func play_swap(scene: Object, movement: Dictionary) -> void:
	if scene == null or movement.is_empty():
		return
	var overlay := _ensure_overlay(scene)
	if overlay == null:
		return
	_clear_overlay_children(overlay)
	overlay.visible = true
	var hidden_slots := _hide_involved_field_slots(scene, movement)
	var moving_views: Array[Control] = []
	for move_variant: Variant in movement.get("moves", []):
		if not (move_variant is Dictionary):
			continue
		var moving_view := _create_moving_card_view(scene, overlay, move_variant as Dictionary)
		if moving_view != null:
			moving_views.append(moving_view)
	if moving_views.is_empty():
		_restore_hidden_field_slots(hidden_slots)
		overlay.visible = false
		return
	if not (scene is Node) or not (scene as Node).is_inside_tree():
		_finish_swap_animation(overlay, hidden_slots)
		return
	var tween := (scene as Node).create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	for moving_view: Control in moving_views:
		var target_position: Vector2 = moving_view.get_meta("field_swap_target_position", moving_view.position)
		var target_size: Vector2 = moving_view.get_meta("field_swap_target_size", moving_view.size)
		tween.tween_property(moving_view, "position", target_position, MOVE_SECONDS)
		tween.tween_property(moving_view, "size", target_size, MOVE_SECONDS)
		tween.tween_property(moving_view, "scale", Vector2.ONE, MOVE_SECONDS)
	tween.finished.connect(func() -> void:
		_finish_swap_animation(overlay, hidden_slots)
	)


func _capture_player_slots(slots: Dictionary, prefix: String, player: PlayerState) -> void:
	if player == null:
		return
	slots["%s_active" % prefix] = _slot_snapshot("%s_active" % prefix, player.active_pokemon)
	for bench_index: int in MAX_FIELD_BENCH_SIZE:
		var slot: PokemonSlot = player.bench[bench_index] if bench_index < player.bench.size() else null
		slots["%s_bench_%d" % [prefix, bench_index]] = _slot_snapshot("%s_bench_%d" % [prefix, bench_index], slot)


func _slot_snapshot(slot_id: String, slot: PokemonSlot) -> Dictionary:
	var top_card: CardInstance = slot.get_top_card() if slot != null else null
	return {
		"slot_id": slot_id,
		"card_instance_id": int(top_card.instance_id) if top_card != null else -1,
		"card": top_card,
		"pokemon_name": slot.get_pokemon_name() if slot != null else "",
	}


func _detect_side_active_field_movement(prefix: String, before_slots: Dictionary, after_slots: Dictionary) -> Dictionary:
	var active_id := "%s_active" % prefix
	var before_active: Dictionary = before_slots.get(active_id, {})
	var after_active: Dictionary = after_slots.get(active_id, {})
	var old_active_card_id := int(before_active.get("card_instance_id", -1))
	var new_active_card_id := int(after_active.get("card_instance_id", -1))
	if old_active_card_id == new_active_card_id:
		return {}
	var moves: Array[Dictionary] = []
	var involved_slot_ids: Array = [active_id]
	if new_active_card_id >= 0:
		var new_active_source_id := _find_bench_slot_id_for_card(before_slots, prefix, new_active_card_id)
		if new_active_source_id != "":
			var new_active_source: Dictionary = before_slots.get(new_active_source_id, {})
			moves.append({
				"card_instance_id": new_active_card_id,
				"card": new_active_source.get("card", null),
				"pokemon_name": str(new_active_source.get("pokemon_name", "")),
				"from_slot_id": new_active_source_id,
				"to_slot_id": active_id,
				"to_snapshot": after_active,
			})
			involved_slot_ids.append(new_active_source_id)
	if old_active_card_id >= 0:
		var old_active_destination_id := _find_bench_slot_id_for_card(after_slots, prefix, old_active_card_id)
		if old_active_destination_id != "":
			var old_active_destination: Dictionary = after_slots.get(old_active_destination_id, {})
			moves.append({
				"card_instance_id": old_active_card_id,
				"card": before_active.get("card", null),
				"pokemon_name": str(before_active.get("pokemon_name", "")),
				"from_slot_id": active_id,
				"to_slot_id": old_active_destination_id,
				"to_snapshot": old_active_destination,
			})
			involved_slot_ids.append(old_active_destination_id)
	if moves.is_empty():
		return {}
	return {
		"prefix": prefix,
		"involved_slot_ids": _unique_strings(involved_slot_ids),
		"moves": moves,
	}


func _find_bench_slot_id_for_card(slots: Dictionary, prefix: String, card_instance_id: int) -> String:
	for bench_index: int in MAX_FIELD_BENCH_SIZE:
		var slot_id := "%s_bench_%d" % [prefix, bench_index]
		var snapshot: Dictionary = slots.get(slot_id, {})
		if int(snapshot.get("card_instance_id", -1)) == card_instance_id:
			return slot_id
	return ""


func _ensure_overlay(scene: Object) -> Control:
	var existing: Control = null
	if scene != null:
		existing = scene.get("_field_swap_overlay") as Control
	if existing != null and is_instance_valid(existing):
		return existing
	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 260
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var host := _overlay_host(scene)
	if host == null:
		return null
	host.add_child(overlay)
	scene.set("_field_swap_overlay", overlay)
	return overlay


func _overlay_host(scene: Object) -> Control:
	if scene is Control:
		return scene as Control
	if scene is Node:
		return (scene as Node).find_child("MainArea", true, false) as Control
	return null


func _create_moving_card_view(scene: Object, overlay: Control, move: Dictionary) -> BattleCardView:
	var card: CardInstance = move.get("card", null) as CardInstance
	if card == null:
		return null
	var from_slot_id := str(move.get("from_slot_id", ""))
	var to_slot_id := str(move.get("to_slot_id", ""))
	var from_control := _slot_control(scene, from_slot_id)
	var to_control := _slot_control(scene, to_slot_id)
	if from_control == null or to_control == null:
		return null
	var from_rect := _control_rect_in_overlay(overlay, from_control)
	var to_rect := _control_rect_in_overlay(overlay, to_control)
	if from_rect.size.x <= 0.0 or from_rect.size.y <= 0.0 or to_rect.size.x <= 0.0 or to_rect.size.y <= 0.0:
		return null
	var view: BattleCardView = BattleCardViewScript.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.custom_minimum_size = from_rect.size
	view.size = from_rect.size
	view.position = from_rect.position
	view.scale = Vector2(1.04, 1.04)
	view.pivot_offset = from_rect.size * 0.5
	view.setup_from_instance(card, BattleCardView.MODE_SLOT_ACTIVE if to_slot_id.ends_with("_active") else BattleCardView.MODE_SLOT_BENCH)
	view.set_clickable(false)
	view.set_meta("field_swap_target_position", to_rect.position)
	view.set_meta("field_swap_target_size", to_rect.size)
	overlay.add_child(view)
	return view


func _slot_control(scene: Object, slot_id: String) -> Control:
	if scene == null or slot_id == "":
		return null
	var slot_card_views_variant: Variant = scene.get("_slot_card_views")
	var slot_card_views: Dictionary = slot_card_views_variant if slot_card_views_variant is Dictionary else {}
	var card_view: Control = slot_card_views.get(slot_id, null) as Control
	if card_view != null and is_instance_valid(card_view):
		return card_view
	if scene is Node:
		var node_name := _node_name_for_slot_id(slot_id)
		if node_name != "":
			return (scene as Node).find_child(node_name, true, false) as Control
	return null


func _node_name_for_slot_id(slot_id: String) -> String:
	if slot_id == "my_active":
		return "MyActive"
	if slot_id == "opp_active":
		return "OppActive"
	if slot_id.begins_with("my_bench_"):
		return "MyBench%d" % int(slot_id.split("_")[-1])
	if slot_id.begins_with("opp_bench_"):
		return "OppBench%d" % int(slot_id.split("_")[-1])
	return ""


func _control_rect_in_overlay(overlay: Control, control: Control) -> Rect2:
	var global_rect := control.get_global_rect()
	return Rect2(global_rect.position - overlay.get_global_rect().position, global_rect.size)


func _hide_involved_field_slots(scene: Object, movement: Dictionary) -> Array[Dictionary]:
	var hidden_slots: Array[Dictionary] = []
	for slot_id_variant: Variant in movement.get("involved_slot_ids", []):
		var slot_id := str(slot_id_variant)
		var control := _slot_control(scene, slot_id)
		if control == null:
			continue
		hidden_slots.append({
			"control": control,
			"modulate": control.modulate,
		})
		control.modulate = Color(control.modulate.r, control.modulate.g, control.modulate.b, HIDDEN_SLOT_ALPHA)
	return hidden_slots


func _restore_hidden_field_slots(hidden_slots: Array[Dictionary]) -> void:
	for entry: Dictionary in hidden_slots:
		var control: Control = entry.get("control", null) as Control
		if control == null or not is_instance_valid(control):
			continue
		control.modulate = entry.get("modulate", Color.WHITE)


func _finish_swap_animation(overlay: Control, hidden_slots: Array[Dictionary]) -> void:
	_restore_hidden_field_slots(hidden_slots)
	_clear_overlay_children(overlay)
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false


func _clear_overlay_children(overlay: Control) -> void:
	if overlay == null:
		return
	for child: Node in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()


func _unique_strings(values: Array) -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for value_variant: Variant in values:
		var value := str(value_variant)
		if value == "" or seen.has(value):
			continue
		seen[value] = true
		result.append(value)
	return result
