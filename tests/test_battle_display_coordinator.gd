class_name TestBattleDisplayCoordinator
extends TestBase

const BattleDisplayCoordinatorScript := preload("res://scripts/ui/battle/display/BattleDisplayCoordinator.gd")
const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")


class LegacyDisplaySpy:
	extends RefCounted

	var calls: Array[String] = []

	func refresh_ui(_scene: Node) -> void:
		calls.append("refresh_ui")

	func refresh_hand(_scene: Node) -> void:
		calls.append("refresh_hand")

	func refresh_field_card_views(_scene: Node, _game_state: GameState) -> void:
		calls.append("refresh_field")

	func show_discard_pile(_scene: Node, player_index: int, title: String) -> void:
		calls.append("discard:%d:%s" % [player_index, title])

	func show_lost_zone(_scene: Node, player_index: int, title: String) -> void:
		calls.append("lost:%d:%s" % [player_index, title])


func test_display_coordinator_wraps_legacy_refresh_entrypoints() -> String:
	var coordinator := BattleDisplayCoordinatorScript.new()
	var context := BattleSceneContextScript.new()
	var legacy := LegacyDisplaySpy.new()
	var scene := Node.new()

	coordinator.call("setup", context, legacy, scene)
	coordinator.call("refresh_all")
	coordinator.call("refresh_hand")

	var result := run_checks([
		assert_true(bool(coordinator.call("is_configured")), "Coordinator should report configured state"),
		assert_eq(legacy.calls, ["refresh_ui", "refresh_hand"], "Coordinator should delegate refresh calls in order"),
	])
	scene.free()
	return result


func test_display_coordinator_routes_zone_viewers() -> String:
	var coordinator := BattleDisplayCoordinatorScript.new()
	var context := BattleSceneContextScript.new()
	var legacy := LegacyDisplaySpy.new()
	var scene := Node.new()

	coordinator.call("setup", context, legacy, scene)
	coordinator.call("show_discard_pile", 0, "弃牌区")
	coordinator.call("show_lost_zone", 1, "失落区")

	var result := run_checks([
		assert_eq(legacy.calls, ["discard:0:弃牌区", "lost:1:失落区"], "Coordinator should delegate zone viewers"),
	])
	scene.free()
	return result
