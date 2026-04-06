class_name TestBattleLayoutController
extends TestBase

const BattleLayoutControllerScript = preload("res://scripts/ui/battle/BattleLayoutController.gd")


func test_measure_card_layout_returns_consistent_sizes() -> String:
	var controller := BattleLayoutControllerScript.new()
	var measured_variant: Variant = controller.call("measure_card_layout", Vector2(1600, 900), 920.0, 8.0, 5, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}

	return run_checks([
		assert_true((measured.get("play_card_size", Vector2.ZERO) as Vector2).y >= 112.0, "Measured play card height should respect the minimum"),
		assert_true((measured.get("dialog_card_size", Vector2.ZERO) as Vector2).y >= 148.0, "Measured dialog card height should respect the minimum"),
		assert_eq(measured.get("prize_slot_size", Vector2.ZERO), measured.get("preview_card_size", Vector2.ZERO), "Prize slots should follow the preview card size"),
	])


func test_resolve_backdrop_path_falls_back_to_default() -> String:
	var controller := BattleLayoutControllerScript.new()
	var resolved_path := str(controller.call("resolve_backdrop_path", "res://missing/background.png", "res://assets/ui/background.png"))

	return run_checks([
		assert_eq(resolved_path, "res://assets/ui/background.png", "Missing selected backgrounds should fall back to the default asset"),
	])


func test_load_card_back_texture_returns_texture_for_missing_asset() -> String:
	var controller := BattleLayoutControllerScript.new()
	var texture: Variant = controller.call("load_card_back_texture", "res://missing/card_back.png", true)

	return run_checks([
		assert_true(texture is Texture2D, "Missing card-back assets should still yield a generated texture"),
	])
