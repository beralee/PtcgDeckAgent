class_name TestBattleLayoutController
extends TestBase

const BattleLayoutControllerScript = preload("res://scripts/ui/battle/BattleLayoutController.gd")


func test_measure_card_layout_returns_consistent_sizes() -> String:
	var controller := BattleLayoutControllerScript.new()
	var measured_variant: Variant = controller.call("measure_card_layout", Vector2(1600, 900), 1200.0, 8.0, 5, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}

	return run_checks([
		assert_true((measured.get("play_card_size", Vector2.ZERO) as Vector2).y >= 112.0, "Measured play card height should respect the minimum"),
		assert_true((measured.get("dialog_card_size", Vector2.ZERO) as Vector2).y >= 148.0, "Measured dialog card height should respect the minimum"),
		assert_eq(measured.get("prize_slot_size", Vector2.ZERO), measured.get("preview_card_size", Vector2.ZERO), "Prize slots should follow the preview card size"),
	])


func test_measure_card_layout_keeps_prize_hud_touchable_on_common_landscape_ratios() -> String:
	var controller := BattleLayoutControllerScript.new()
	var cases := [
		{"viewport": Vector2(1080, 486), "expects_sub_min": true},
		{"viewport": Vector2(960, 432), "expects_sub_min": true},
		{"viewport": Vector2(1280, 576), "expects_sub_min": false},
		{"viewport": Vector2(1280, 720), "expects_sub_min": false},
		{"viewport": Vector2(1600, 720), "expects_sub_min": false},
		{"viewport": Vector2(2400, 1080), "expects_sub_min": false},
	]
	var checks: Array[String] = []
	for test_case: Dictionary in cases:
		var viewport_size: Vector2 = test_case.get("viewport", Vector2.ZERO)
		var side_width := 0.0
		var right_width := 78.0
		var log_width := 135.0
		var center_width := viewport_size.x - side_width - right_width - log_width
		var measured_variant: Variant = controller.call("measure_card_layout", viewport_size, center_width, 1.0, 5, 0.716)
		var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
		var play_card_size: Vector2 = measured.get("play_card_size", Vector2.ZERO)
		var estimated_shell_width := _estimate_landscape_shell_width(measured)
		var label := "%sx%s" % [int(viewport_size.x), int(viewport_size.y)]

		if bool(test_case.get("expects_sub_min", false)):
			checks.append(assert_true(play_card_size.y < 112.0, "%s should be allowed below the old 112px minimum" % label))
		checks.append(assert_true(
			estimated_shell_width <= center_width + 1.0,
			"%s prize HUD, field axis, and pile HUDs should fit the center field" % label
		))

	return run_checks(checks)


func test_measure_card_layout_keeps_prize_hud_touchable_on_apple_landscape_sizes() -> String:
	var controller := BattleLayoutControllerScript.new()
	var cases := [
		{"label": "iPhone SE/8", "viewport": Vector2(1334, 750)},
		{"label": "iPhone 8 Plus", "viewport": Vector2(1920, 1080)},
		{"label": "iPhone X/XS/11 Pro", "viewport": Vector2(2436, 1125)},
		{"label": "iPhone XR/11", "viewport": Vector2(1792, 828)},
		{"label": "iPhone 12/13 mini", "viewport": Vector2(2340, 1080)},
		{"label": "iPhone 12-14", "viewport": Vector2(2532, 1170)},
		{"label": "iPhone 14 Pro", "viewport": Vector2(2556, 1179)},
		{"label": "iPhone 14 Pro Max", "viewport": Vector2(2796, 1290)},
		{"label": "iPhone 16 Pro", "viewport": Vector2(2622, 1206)},
		{"label": "iPhone 16 Pro Max", "viewport": Vector2(2868, 1320)},
		{"label": "iPad 9.7/legacy", "viewport": Vector2(1024, 768)},
		{"label": "iPad Retina", "viewport": Vector2(2048, 1536)},
		{"label": "iPad 10.2", "viewport": Vector2(2160, 1620)},
		{"label": "iPad mini 6", "viewport": Vector2(2266, 1488)},
		{"label": "iPad Air 11", "viewport": Vector2(2360, 1640)},
		{"label": "iPad Pro 11", "viewport": Vector2(2388, 1668)},
		{"label": "iPad Pro 12.9", "viewport": Vector2(2732, 2048)},
		{"label": "iPad Pro 13", "viewport": Vector2(2752, 2064)},
	]
	var checks: Array[String] = []
	for test_case: Dictionary in cases:
		var viewport_size: Vector2 = test_case.get("viewport", Vector2.ZERO)
		var center_width := _estimate_landscape_center_width(viewport_size)
		var measured_variant: Variant = controller.call("measure_card_layout", viewport_size, center_width, 1.0, 5, 0.716)
		var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
		var estimated_shell_width := _estimate_landscape_shell_width(measured)
		var label := str(test_case.get("label", "Apple viewport"))

		checks.append(assert_true(
			estimated_shell_width <= center_width + 1.0,
			"%s prize HUD should stay inside the landscape center field" % label
		))

	return run_checks(checks)


func _estimate_landscape_center_width(viewport_size: Vector2) -> float:
	var side_width := 0.0
	var right_width := 78.0
	var log_width := 135.0
	return viewport_size.x - side_width - right_width - log_width


func _estimate_landscape_shell_width(measured: Dictionary) -> float:
	var play_card_size: Vector2 = measured.get("play_card_size", Vector2.ZERO)
	var preview_card_size: Vector2 = measured.get("preview_card_size", Vector2.ZERO)
	var prize_width := preview_card_size.x * 3.0
	var field_axis_width := play_card_size.x * 6.2
	var pile_width := preview_card_size.x * 2.0 + 32.0
	var shell_gap := 32.0
	return prize_width + field_axis_width + pile_width + shell_gap


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
