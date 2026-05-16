class_name TestBattleOverlayCoordinator
extends TestBase

const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleOverlayStateScript := preload("res://scripts/ui/battle/states/BattleOverlayState.gd")
const BattleOverlayCoordinatorScript := preload("res://scripts/ui/battle/overlays/BattleOverlayCoordinator.gd")


class LegacyOverlaySpy:
	extends RefCounted

	var calls: Array[String] = []

	func start_prize_selection(_scene: Node, player_index: int, count: int) -> void:
		calls.append("start_prize:%d:%d" % [player_index, count])

	func clear_prize_selection(_scene: Node) -> void:
		calls.append("clear_prize")

	func refresh_prize_titles(_scene: Node) -> void:
		calls.append("refresh_titles")

	func update_prize_title(_scene: Node, _label: Label, player_index: int, default_text: String, is_hud: bool) -> void:
		calls.append("update_title:%d:%s:%s" % [player_index, default_text, str(is_hud)])

	func focus_prize_panel(_scene: Node, player_index: int) -> void:
		calls.append("focus_prize:%d" % player_index)

	func show_handover_prompt(_scene: Node, target_player: int, _follow_up: Callable = Callable()) -> void:
		calls.append("handover:%d" % target_player)

	func check_two_player_handover(_scene: Node) -> void:
		calls.append("check_handover")

	func on_handover_confirmed(_scene: Node) -> void:
		calls.append("confirm_handover")

	func show_match_end_screen(_scene: Node, winner_index: int, reason: String) -> void:
		calls.append("match_end:%d:%s" % [winner_index, reason])

	func build_match_end_stats(_scene: Node, winner_index: int, reason: String) -> Dictionary:
		calls.append("stats:%d:%s" % [winner_index, reason])
		return {"winner_index": winner_index, "reason": reason}

	func refresh_match_end_screen(_scene: Node) -> void:
		calls.append("refresh_match_end")

	func refresh_match_end_dialog_if_visible(_scene: Node) -> void:
		calls.append("refresh_match_end_if_visible")


func test_overlay_coordinator_updates_overlay_state_and_delegates() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleOverlayStateScript.new()
	context.call("set_state", "overlay", state)
	var legacy := LegacyOverlaySpy.new()
	var scene := Node.new()
	var coordinator := BattleOverlayCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	coordinator.call("start_prize_selection", 1, 2)
	coordinator.call("show_handover_prompt", 1, Callable())
	coordinator.call("show_match_end_screen", 0, "test")

	var result := run_checks([
		assert_true(bool(coordinator.call("is_configured")), "Overlay coordinator should be configured"),
		assert_true(bool(state.call("has_pending_prize")), "Overlay coordinator should keep prize state updated"),
		assert_true(bool(state.get("handover_visible")), "Overlay coordinator should keep handover state updated"),
		assert_true(bool(state.get("match_end_visible")), "Overlay coordinator should keep match end state updated"),
		assert_eq(legacy.calls, ["start_prize:1:2", "handover:1", "match_end:0:test"], "Overlay coordinator should delegate legacy behavior"),
	])
	scene.free()
	return result


func test_overlay_coordinator_routes_prize_and_match_end_helpers() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleOverlayStateScript.new()
	context.call("set_state", "overlay", state)
	var legacy := LegacyOverlaySpy.new()
	var scene := Node.new()
	var coordinator := BattleOverlayCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	coordinator.call("clear_prize_selection")
	coordinator.call("refresh_prize_titles")
	coordinator.call("focus_prize_panel", 0)
	var stats: Dictionary = coordinator.call("build_match_end_stats", 1, "decked_out")
	coordinator.call("refresh_match_end_screen")
	coordinator.call("refresh_match_end_dialog_if_visible")

	var result := run_checks([
		assert_eq(stats.get("winner_index"), 1, "Coordinator should return delegated match end stats"),
		assert_eq(legacy.calls, [
			"clear_prize",
			"refresh_titles",
			"focus_prize:0",
			"stats:1:decked_out",
			"refresh_match_end",
			"refresh_match_end_if_visible",
		], "Overlay helper calls should be delegated in order"),
	])
	scene.free()
	return result
