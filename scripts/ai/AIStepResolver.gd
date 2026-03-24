class_name AIStepResolver
extends RefCounted


func resolve_pending_step(battle_scene: Control, _gsm: GameStateMachine, player_index: int) -> bool:
	if battle_scene == null:
		return false
	if str(battle_scene.get("_pending_choice")) != "effect_interaction":
		return false
	var steps: Array[Dictionary] = battle_scene.get("_pending_effect_steps")
	var step_index: int = int(battle_scene.get("_pending_effect_step_index"))
	if step_index < 0 or step_index >= steps.size():
		return false
	var step: Dictionary = steps[step_index]
	var chooser_player: int = int(battle_scene.call("_resolve_effect_step_chooser_player", step))
	if chooser_player != player_index:
		return false
	if bool(battle_scene.call("_effect_step_uses_field_assignment_ui", step)):
		return _resolve_field_assignment_step(battle_scene, step)
	if bool(battle_scene.call("_effect_step_uses_field_slot_ui", step)):
		return _resolve_field_slot_step(battle_scene, step)
	if str(step.get("ui_mode", "")) == "card_assignment":
		return _resolve_dialog_assignment_step(battle_scene, step)
	return _resolve_dialog_step(battle_scene, step)


func _resolve_dialog_step(battle_scene: Control, step: Dictionary) -> bool:
	var items: Array = step.get("items", [])
	var selected_count: int = _baseline_pick_count(items.size(), int(step.get("min_select", 1)), int(step.get("max_select", 1)))
	if selected_count <= 0:
		return false
	var selected_indices := PackedInt32Array()
	for index: int in range(selected_count):
		selected_indices.append(index)
	battle_scene.call("_handle_effect_interaction_choice", selected_indices)
	return true


func _resolve_field_slot_step(battle_scene: Control, step: Dictionary) -> bool:
	var items: Array = step.get("items", [])
	var selected_count: int = _baseline_pick_count(items.size(), int(step.get("min_select", 1)), int(step.get("max_select", 1)))
	if selected_count <= 0:
		return false
	for index: int in range(selected_count):
		battle_scene.call("_handle_field_slot_select_index", index)
	if str(battle_scene.get("_field_interaction_mode")) == "slot_select":
		battle_scene.call("_finalize_field_slot_selection")
	return true


func _resolve_field_assignment_step(battle_scene: Control, step: Dictionary) -> bool:
	var assignments_made: int = _assign_sources_to_targets(
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step.get("source_items", []),
		step.get("target_items", []),
		step.get("source_exclude_targets", {}),
		func(source_index: int, target_index: int) -> void:
			battle_scene.call("_on_field_assignment_source_chosen", source_index)
			battle_scene.call("_handle_field_assignment_target_index", target_index)
	)
	if assignments_made <= 0:
		return false
	if str(battle_scene.get("_field_interaction_mode")) == "assignment":
		battle_scene.call("_finalize_field_assignment_selection")
	return true


func _resolve_dialog_assignment_step(battle_scene: Control, step: Dictionary) -> bool:
	var assignments_made: int = _assign_sources_to_targets(
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step.get("source_items", []),
		step.get("target_items", []),
		step.get("source_exclude_targets", {}),
		func(source_index: int, target_index: int) -> void:
			battle_scene.call("_on_assignment_source_chosen", source_index)
			battle_scene.call("_on_assignment_target_chosen", target_index)
	)
	if assignments_made <= 0:
		return false
	battle_scene.call("_confirm_assignment_dialog")
	return true


func _assign_sources_to_targets(
	min_assignments: int,
	max_assignments: int,
	source_items: Array,
	target_items: Array,
	source_exclude_targets: Dictionary,
	apply_assignment: Callable
) -> int:
	if source_items.is_empty() or target_items.is_empty() or not apply_assignment.is_valid():
		return 0
	var target_assignment_count: int = _baseline_pick_count(source_items.size(), min_assignments, max_assignments)
	if target_assignment_count <= 0:
		return 0
	var assignments_made: int = 0
	for source_index: int in source_items.size():
		if assignments_made >= target_assignment_count:
			break
		var excluded_targets: Array = source_exclude_targets.get(source_index, [])
		var chosen_target_index: int = _first_legal_target_index(target_items.size(), excluded_targets)
		if chosen_target_index < 0:
			continue
		apply_assignment.call(source_index, chosen_target_index)
		assignments_made += 1
	return assignments_made


func _first_legal_target_index(target_count: int, excluded_targets: Array) -> int:
	for target_index: int in target_count:
		if target_index in excluded_targets:
			continue
		return target_index
	return -1


func _baseline_pick_count(item_count: int, min_select: int, max_select: int) -> int:
	if item_count <= 0:
		return 0
	var target_count: int = item_count
	if max_select > 0:
		target_count = mini(target_count, max_select)
	if min_select > 0:
		target_count = maxi(target_count, min_select)
	return clampi(target_count, 1, item_count)
