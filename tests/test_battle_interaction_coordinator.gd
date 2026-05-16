class_name TestBattleInteractionCoordinator
extends TestBase

const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleInteractionStateScript := preload("res://scripts/ui/battle/states/BattleInteractionState.gd")
const BattleInteractionCoordinatorScript := preload("res://scripts/ui/battle/interactions/BattleInteractionCoordinator.gd")


class LegacyInteractionSpy:
	extends RefCounted

	var calls: Array[String] = []
	var active: bool = false

	func setup_field_interaction_panel(_scene: Node) -> void:
		calls.append("setup")

	func ensure_field_interaction_panel(_scene: Node) -> void:
		calls.append("ensure")

	func hide_field_interaction(_scene: Node) -> void:
		active = false
		calls.append("hide")

	func update_field_interaction_panel_metrics(_scene: Node, viewport_size: Vector2 = Vector2.ZERO) -> void:
		calls.append("metrics:%s" % str(viewport_size))

	func is_field_interaction_active(_scene: Node) -> bool:
		calls.append("is_active")
		return active

	func show_field_slot_choice(_scene: Node, title: String, _items: Array, _data: Dictionary = {}) -> void:
		active = true
		calls.append("slot:%s" % title)

	func show_field_assignment_interaction(_scene: Node, _step: Dictionary) -> void:
		active = true
		calls.append("assignment")

	func show_field_counter_distribution(_scene: Node, _step: Dictionary) -> void:
		active = true
		calls.append("counter")

	func on_field_interaction_clear_pressed(_scene: Node) -> void:
		calls.append("clear")

	func cancel_field_interaction(_scene: Node) -> void:
		active = false
		calls.append("cancel")

	func finalize_field_slot_selection(_scene: Node) -> void:
		calls.append("confirm_slot")

	func finalize_field_assignment_selection(_scene: Node) -> void:
		calls.append("confirm_assignment")

	func finalize_counter_distribution(_scene: Node) -> void:
		calls.append("confirm_counter")


func test_interaction_coordinator_tracks_major_modes_and_delegates() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleInteractionStateScript.new()
	context.call("set_state", "interaction", state)
	var legacy := LegacyInteractionSpy.new()
	var scene := Node.new()
	var coordinator := BattleInteractionCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	coordinator.call("show_field_slot_choice", "Choose target", [], {"prompt_type": "test"})
	var slot_active := bool(coordinator.call("is_field_interaction_active"))
	coordinator.call("show_field_assignment_interaction", {"title": "Assign"})
	coordinator.call("show_field_counter_distribution", {"title": "Counters"})

	var result := run_checks([
		assert_true(slot_active, "Coordinator should expose active state after slot prompt"),
		assert_eq(str(state.get("mode")), "counter_distribution", "Coordinator should keep the latest interaction mode"),
		assert_eq(legacy.calls, ["slot:Choose target", "is_active", "assignment", "counter"], "Coordinator should delegate major interaction prompts"),
	])
	scene.free()
	return result


func test_interaction_coordinator_clear_cancel_and_confirm_paths() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleInteractionStateScript.new()
	context.call("set_state", "interaction", state)
	var legacy := LegacyInteractionSpy.new()
	var scene := Node.new()
	var coordinator := BattleInteractionCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	state.set("mode", "slot_select")
	state.set("selected_indices", [1, 2])
	coordinator.call("clear_selection")
	coordinator.call("confirm_slot_selection")
	coordinator.call("confirm_assignment_selection")
	coordinator.call("confirm_counter_distribution")
	coordinator.call("cancel")

	var result := run_checks([
		assert_eq((state.get("selected_indices") as Array).size(), 0, "Coordinator should clear selected indices"),
		assert_false(bool(state.call("is_active")), "Coordinator should reset state on cancel"),
		assert_eq(legacy.calls, ["clear", "confirm_slot", "confirm_assignment", "confirm_counter", "cancel"], "Coordinator should delegate clear and confirm paths"),
	])
	scene.free()
	return result


func test_interaction_coordinator_self_heals_when_legacy_slot_finalize_hid_prompt() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleInteractionStateScript.new()
	context.call("set_state", "interaction", state)
	var legacy := LegacyInteractionSpy.new()
	var scene := Node.new()
	var coordinator := BattleInteractionCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	state.set("mode", "slot_select")
	legacy.active = false

	var active_after_legacy_hide := bool(coordinator.call("is_field_interaction_active"))

	var result := run_checks([
		assert_false(active_after_legacy_hide, "Coordinator should trust the legacy prompt being closed after direct legacy finalize"),
		assert_false(bool(state.call("is_active")), "Coordinator should reset stale interaction state when legacy state is already hidden"),
	])
	scene.free()
	return result
