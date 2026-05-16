class_name BattleDeckShuffleAnimator
extends RefCounted

var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func stop_deck_shuffle_effect(player_index: int) -> void:
	var existing: Variant = _get_deck_shuffle_tween_for_player(player_index)
	var preview := _get_deck_preview_for_player(player_index)
	if existing is Tween:
		(existing as Tween).kill()
	if preview != null:
		preview.rotation_degrees = 0.0
		preview.scale = Vector2.ONE
	_set_deck_shuffle_tween_for_player(player_index, null)


func stop_all_deck_shuffle_effects() -> void:
	for player_index: int in [0, 1]:
		stop_deck_shuffle_effect(player_index)


func play_deck_shuffle_effect(player_index: int) -> void:
	var preview := _get_deck_preview_for_player(player_index)
	if preview == null:
		return
	stop_deck_shuffle_effect(player_index)
	preview.pivot_offset = preview.size * 0.5
	var base_positions_variant: Variant = _get("_deck_preview_base_positions")
	var base_positions: Dictionary = base_positions_variant if base_positions_variant is Dictionary else {}
	base_positions[player_index] = preview.position
	_set_scene_var("_deck_preview_base_positions", base_positions)
	var serial := int(_get("_deck_shuffle_effect_serial")) + 1
	_set_scene_var("_deck_shuffle_effect_serial", serial)
	if _scene == null or not _scene.is_inside_tree():
		_set_deck_shuffle_tween_for_player(player_index, {"serial": serial})
		return
	var tween := _scene.create_tween()
	_set_deck_shuffle_tween_for_player(player_index, tween)
	var rotations := [5.0, -5.0, 4.0, -4.0, 3.0, -3.0, 2.0, -2.0, 1.0, 0.0]
	var scales := [
		Vector2(1.02, 1.02),
		Vector2(0.99, 0.99),
		Vector2(1.02, 1.02),
		Vector2(0.99, 0.99),
		Vector2(1.015, 1.015),
		Vector2(0.995, 0.995),
		Vector2(1.01, 1.01),
		Vector2(0.998, 0.998),
		Vector2(1.005, 1.005),
		Vector2.ONE,
	]
	for step_index: int in rotations.size():
		tween.tween_property(preview, "rotation_degrees", rotations[step_index], 0.08)
		tween.parallel().tween_property(preview, "scale", scales[step_index], 0.08)
	tween.finished.connect(func() -> void:
		if is_instance_valid(preview):
			preview.rotation_degrees = 0.0
			preview.scale = Vector2.ONE
		_set_deck_shuffle_tween_for_player(player_index, null)
	)


func refresh_deck_shuffle_detection(gs: GameState) -> void:
	if gs == null:
		return
	var counts_variant: Variant = _get("_deck_shuffle_counts")
	var counts: Dictionary = counts_variant if counts_variant is Dictionary else {}
	for player_index: int in gs.players.size():
		var player: PlayerState = gs.players[player_index]
		if player == null:
			continue
		var current_count: int = player.shuffle_count
		var previous_count: int = int(counts.get(player_index, 0))
		if current_count > previous_count:
			play_deck_shuffle_effect(player_index)
		counts[player_index] = current_count
	_set_scene_var("_deck_shuffle_counts", counts)


func _get_deck_preview_for_player(player_index: int) -> BattleCardView:
	var view_player := int(_get("_view_player"))
	if player_index == view_player:
		return _get("_my_deck_preview") as BattleCardView
	if player_index == 1 - view_player:
		return _get("_opp_deck_preview") as BattleCardView
	return null


func _get_deck_shuffle_tween_for_player(player_index: int) -> Variant:
	var view_player := int(_get("_view_player"))
	return _get("_my_deck_shuffle_tween") if player_index == view_player else _get("_opp_deck_shuffle_tween")


func _set_deck_shuffle_tween_for_player(player_index: int, tween_value: Variant) -> void:
	var view_player := int(_get("_view_player"))
	if player_index == view_player:
		_set_scene_var("_my_deck_shuffle_tween", tween_value)
	elif player_index == 1 - view_player:
		_set_scene_var("_opp_deck_shuffle_tween", tween_value)


func _get(property_name: StringName) -> Variant:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get(property_name)


func _set_scene_var(property_name: StringName, value: Variant) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_scene.set(property_name, value)
