class_name TestBattleRecordingCoordinator
extends TestBase

const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleRecordingStateScript := preload("res://scripts/ui/battle/states/BattleRecordingState.gd")
const BattleRecordingCoordinatorScript := preload("res://scripts/ui/battle/recording/BattleRecordingCoordinator.gd")


class LegacyRecordingSpy:
	extends RefCounted

	var calls: Array[String] = []
	var should_record: bool = true
	var can_capture: bool = true

	func set_battle_recording_output_root(_scene: Node, root_path: String) -> void:
		calls.append("root:%s" % root_path)

	func should_record_local_battle(_scene: Node) -> bool:
		calls.append("should_record")
		return should_record

	func can_capture_battle_recording_context(_scene: Node) -> bool:
		calls.append("can_capture")
		return can_capture

	func capture_battle_recording_context_if_ready(_scene: Node) -> void:
		calls.append("capture")

	func ensure_battle_recording_started(_scene: Node) -> void:
		calls.append("ensure")

	func record_battle_event(_scene: Node, event_data: Dictionary) -> void:
		calls.append("event:%s" % str(event_data.get("event_type", "")))

	func finalize_battle_recording(_scene: Node, result_data: Dictionary) -> void:
		calls.append("finalize:%s" % str(result_data.get("reason", "")))


func test_recording_coordinator_updates_state_and_delegates() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleRecordingStateScript.new()
	context.call("set_state", "recording", state)
	var legacy := LegacyRecordingSpy.new()
	var scene := Node.new()
	var coordinator := BattleRecordingCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	coordinator.call("set_output_root", "user://records")
	var should_record := bool(coordinator.call("should_record_local_battle"))
	var can_capture := bool(coordinator.call("can_capture_context"))
	coordinator.call("capture_context_if_ready")
	coordinator.call("ensure_started")
	coordinator.call("record_event", {"event_type": "turn"})
	coordinator.call("finalize", {"reason": "game_over"})

	var result := run_checks([
		assert_true(should_record, "Coordinator should return delegated should-record result"),
		assert_true(can_capture, "Coordinator should return delegated capture result"),
		assert_eq(str(state.get("output_root")), "user://records", "Coordinator should store recording output root in state"),
		assert_false(bool(state.get("started")), "Coordinator should clear started state after finalize"),
		assert_false(bool(state.get("context_captured")), "Coordinator should clear capture state after finalize"),
		assert_eq(legacy.calls, [
			"root:user://records",
			"should_record",
			"can_capture",
			"capture",
			"ensure",
			"event:turn",
			"finalize:game_over",
		], "Coordinator should delegate recording calls in order"),
	])
	scene.free()
	return result
