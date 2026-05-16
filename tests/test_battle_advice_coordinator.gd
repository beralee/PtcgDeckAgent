class_name TestBattleAdviceCoordinator
extends TestBase

const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleAdviceStateScript := preload("res://scripts/ui/battle/states/BattleAdviceState.gd")
const BattleAdviceCoordinatorScript := preload("res://scripts/ui/battle/advice/BattleAdviceCoordinator.gd")


class LegacyAdviceSpy:
	extends RefCounted

	var calls: Array[String] = []

	func ensure_battle_review_service(_scene: Node) -> void:
		calls.append("ensure_review")

	func begin_battle_review_generation(_scene: Node) -> void:
		calls.append("begin_review")

	func on_battle_review_status_changed(_scene: Node, status: String, _context: Dictionary) -> void:
		calls.append("review_status:%s" % status)

	func on_battle_review_completed(_scene: Node, review: Dictionary) -> void:
		calls.append("review_done:%s" % str(review.get("summary", "")))

	func format_battle_review(_scene: Node, review: Dictionary) -> String:
		calls.append("format_review")
		return "review:%s" % str(review.get("summary", ""))

	func setup_battle_advice_ui(_scene: Node) -> void:
		calls.append("setup_advice")

	func should_offer_battle_advice(_scene: Node) -> bool:
		calls.append("should_offer")
		return true

	func current_battle_advice_match_dir(_scene: Node) -> String:
		calls.append("match_dir")
		return "user://match"

	func ensure_battle_advice_service(_scene: Node) -> void:
		calls.append("ensure_advice")

	func on_ai_advice_pressed(_scene: Node) -> void:
		calls.append("ai_pressed")

	func on_battle_advice_status_changed(_scene: Node, status: String, _context: Dictionary) -> void:
		calls.append("advice_status:%s" % status)

	func on_battle_advice_completed(_scene: Node, result: Dictionary) -> void:
		calls.append("advice_done:%s" % str(result.get("summary", "")))

	func show_battle_advice_overlay(_scene: Node, result: Dictionary) -> void:
		calls.append("show_advice:%s" % str(result.get("summary", "")))

	func format_battle_advice(_scene: Node, result: Dictionary) -> String:
		calls.append("format_advice")
		return "advice:%s" % str(result.get("summary", ""))

	func on_review_regenerate_pressed(_scene: Node) -> void:
		calls.append("regenerate")

	func on_review_pin_pressed(_scene: Node) -> void:
		calls.append("pin")

	func on_battle_advice_panel_toggle_pressed(_scene: Node) -> void:
		calls.append("toggle")

	func refresh_battle_advice_panel(_scene: Node) -> void:
		calls.append("refresh_panel")

	func build_battle_advice_initial_snapshot(_scene: Node) -> Dictionary:
		calls.append("snapshot")
		return {"turn": 1}


func test_advice_coordinator_tracks_review_and_advice_state() -> String:
	var context := BattleSceneContextScript.new()
	var state := BattleAdviceStateScript.new()
	context.call("set_state", "advice", state)
	var legacy := LegacyAdviceSpy.new()
	var scene := Node.new()
	var coordinator := BattleAdviceCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	coordinator.call("begin_battle_review_generation")
	coordinator.call("on_battle_review_completed", {"summary": "review ok"})
	coordinator.call("on_ai_advice_pressed")
	coordinator.call("on_battle_advice_completed", {"summary": "advice ok"})

	var result := run_checks([
		assert_false(bool(state.get("review_busy")), "Review busy state should clear on completion"),
		assert_true(bool(state.call("has_cached_review")), "Completed review should be cached in state"),
		assert_false(bool(state.get("busy")), "Advice busy state should clear on completion"),
		assert_eq((state.get("last_result") as Dictionary).get("summary"), "advice ok", "Advice result should be cached in state"),
		assert_eq(legacy.calls, ["begin_review", "review_done:review ok", "ai_pressed", "advice_done:advice ok"], "Coordinator should delegate review and advice calls"),
	])
	scene.free()
	return result


func test_advice_coordinator_routes_helpers() -> String:
	var context := BattleSceneContextScript.new()
	context.call("set_state", "advice", BattleAdviceStateScript.new())
	var legacy := LegacyAdviceSpy.new()
	var scene := Node.new()
	var coordinator := BattleAdviceCoordinatorScript.new()
	coordinator.call("setup", context, legacy, scene)

	coordinator.call("ensure_battle_review_service")
	var review_text := str(coordinator.call("format_battle_review", {"summary": "A"}))
	coordinator.call("setup_battle_advice_ui")
	var offer := bool(coordinator.call("should_offer_battle_advice"))
	var match_dir := str(coordinator.call("current_battle_advice_match_dir"))
	coordinator.call("ensure_battle_advice_service")
	var advice_text := str(coordinator.call("format_battle_advice", {"summary": "B"}))
	coordinator.call("on_review_regenerate_pressed")
	coordinator.call("on_review_pin_pressed")
	coordinator.call("on_battle_advice_panel_toggle_pressed")
	coordinator.call("refresh_battle_advice_panel")
	var snapshot: Dictionary = coordinator.call("build_battle_advice_initial_snapshot")

	var result := run_checks([
		assert_eq(review_text, "review:A", "Coordinator should return formatted review text"),
		assert_true(offer, "Coordinator should return delegated offer state"),
		assert_eq(match_dir, "user://match", "Coordinator should return delegated match dir"),
		assert_eq(advice_text, "advice:B", "Coordinator should return formatted advice text"),
		assert_eq(snapshot.get("turn"), 1, "Coordinator should return delegated advice snapshot"),
		assert_eq(legacy.calls, [
			"ensure_review",
			"format_review",
			"setup_advice",
			"should_offer",
			"match_dir",
			"ensure_advice",
			"format_advice",
			"regenerate",
			"pin",
			"toggle",
			"refresh_panel",
			"snapshot",
		], "Coordinator should route helper calls in order"),
	])
	scene.free()
	return result
