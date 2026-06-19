class_name TestBattlePortraitLayout
extends TestBase

const BattleLayoutControllerScript := preload("res://scripts/ui/battle/BattleLayoutController.gd")
const BattleLayoutCoordinatorScript := preload("res://scripts/ui/battle/layouts/BattleLayoutCoordinator.gd")
const BattleDrawRevealControllerScript := preload("res://scripts/ui/battle/BattleDrawRevealController.gd")
const BattleDisplayControllerScript := preload("res://scripts/ui/battle/BattleDisplayController.gd")
const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")
const BattleScene := preload("res://scenes/battle/BattleScene.tscn")
const DeckDiscussionDialogScene := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn")
const AreaZeroUnderdepthsScript := preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")
const BATTLE_SCENE_RUNTIME_SOURCE_PATHS := [
	"res://scenes/battle/BattleSceneRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneRuntimeFoundation.gd",
]


class LayoutCoordinatorSpyScene:
	extends Node

	var calls: Array[String] = []
	var portrait_frame_rect := Rect2()
	var portrait_full_size := Vector2.ZERO
	var portrait_apply_size := Vector2.ZERO
	var landscape_apply_size := Vector2.ZERO

	func _apply_battle_canvas_transform(_rotate_canvas: bool, _physical_size: Vector2, _logical_size: Vector2) -> void:
		calls.append("canvas")

	func _set_portrait_layout_frame(frame_rect: Rect2, full_size: Vector2) -> void:
		calls.append("portrait_frame")
		portrait_frame_rect = frame_rect
		portrait_full_size = full_size

	func _apply_portrait_layout_impl(viewport_size: Vector2) -> void:
		calls.append("portrait")
		portrait_apply_size = viewport_size

	func _apply_landscape_layout_impl(viewport_size: Vector2) -> void:
		calls.append("landscape")
		landscape_apply_size = viewport_size


class PortraitHandInfoSceneStub:
	extends Control

	var _hand_scroll: ScrollContainer = null
	var _play_card_size := Vector2.ZERO
	var portrait_active := true

	func _is_portrait_battle_layout_active() -> bool:
		return portrait_active


class PortraitHudClampSceneStub:
	extends Control

	var _portrait_layout_frame_rect := Rect2(Vector2.ZERO, Vector2(390, 844))
	var _portrait_layout_full_size := Vector2(390, 844)
	var active_centers := {
		"OppActive": 150.0,
		"MyActive": 650.0,
	}

	func _portrait_layout_ui_scale(_viewport_size: Vector2) -> float:
		return 1.0

	func _portrait_horizontal_safe_inset(_viewport_size: Vector2) -> float:
		return 0.0

	func _portrait_active_center_y(active_name: String, fallback_y: float) -> float:
		return float(active_centers.get(active_name, fallback_y))

	func _control_rect_in_battle_local(control: Control) -> Rect2:
		if control == null:
			return Rect2()
		return Rect2(control.position, control.size)


class PortraitPrizeHudMetricSceneStub:
	extends Control

	var _pending_choice: String = ""
	var _pending_prize_remaining: int = 0
	var _opp_hud_left: PanelContainer = null
	var _my_hud_left: PanelContainer = null
	var _opp_hud_right: PanelContainer = null
	var _my_hud_right: PanelContainer = null

	func _init() -> void:
		_opp_hud_left = PanelContainer.new()
		_opp_hud_left.name = "OppHudLeft"
		add_child(_opp_hud_left)
		_my_hud_left = PanelContainer.new()
		_my_hud_left.name = "MyHudLeft"
		add_child(_my_hud_left)
		_opp_hud_right = PanelContainer.new()
		_opp_hud_right.name = "OppHudRight"
		add_child(_opp_hud_right)
		_my_hud_right = PanelContainer.new()
		_my_hud_right.name = "MyHudRight"
		add_child(_my_hud_right)

	func _portrait_layout_ui_scale(_viewport_size: Vector2) -> float:
		return 1.0

	func _pile_lost_panel_height(pile_panel_height: float) -> float:
		return clampf(roundf(pile_panel_height * 0.32), 24.0, 46.0)

	func _portrait_stadium_hud_height(_viewport_size: Vector2, _ui_scale: float = 1.0) -> float:
		return 64.0

	func _portrait_hud_font_size(_viewport_size: Vector2) -> int:
		return 16

	func _apply_pile_hud_row_orientation(_vertical: bool) -> void:
		pass

	func _apply_battle_axis_field_alignment() -> void:
		pass

	func _move_lost_huds_to_pile_huds(_pile_lost_height: float) -> void:
		pass

	func _apply_portrait_hud_font_metrics(_font_size: int) -> void:
		pass


func _make_basic_pokemon_card(card_name: String) -> CardData:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 70
	card_data.energy_type = "C"
	card_data.retreat_cost = 1
	return card_data


func _make_basic_energy_card(card_name: String = "Grass Energy", energy_type: String = "G") -> CardData:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = "Basic Energy"
	card_data.energy_provides = energy_type
	return card_data


func _make_stadium_card(card_name: String = "Test Stadium") -> CardData:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = "Stadium"
	return card_data


func _add_scene_to_tree(scene: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)


func _portrait_safe_width(scene: Control, viewport_size: Vector2) -> float:
	var safe_x := float(scene.call("_portrait_horizontal_safe_inset", viewport_size))
	return maxf(viewport_size.x - safe_x * 2.0, 1.0)


func _portrait_top_or_main_width(control: Control, viewport_size: Vector2) -> float:
	if control == null:
		return 0.0
	if control.size.x > 0.0:
		return control.size.x
	return viewport_size.x - control.offset_left + control.offset_right


func _expanded_portrait_active_height_before_boost(viewport_size: Vector2, bench_capacity: int, card_aspect: float) -> float:
	var controller := BattleLayoutControllerScript.new()
	var measured_variant: Variant = controller.call("measure_portrait_card_layout", viewport_size, bench_capacity, card_aspect)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var active_size: Vector2 = measured.get("active_card_size", Vector2.ZERO)
	if bench_capacity > 5:
		return active_size.y / BattleLayoutControllerScript.PORTRAIT_EXPANDED_ACTIVE_HEIGHT_SCALE
	return active_size.y


func _battle_local_rect(scene: Control, control: Control) -> Rect2:
	if scene == null or control == null:
		return Rect2()
	var rect_variant: Variant = scene.call("_control_rect_in_battle_local", control)
	return rect_variant if rect_variant is Rect2 else Rect2()


func _rect_fits_x(rect: Rect2, left: float, right: float, tolerance: float = 0.5) -> bool:
	return rect.size.x > 0.0 and rect.position.x >= left - tolerance and rect.position.x + rect.size.x <= right + tolerance


func _rects_overlap(rect_a: Rect2, rect_b: Rect2, tolerance: float = 0.5) -> bool:
	if rect_a.size.x <= 0.0 or rect_a.size.y <= 0.0 or rect_b.size.x <= 0.0 or rect_b.size.y <= 0.0:
		return false
	return (
		rect_a.position.x < rect_b.position.x + rect_b.size.x - tolerance
		and rect_a.position.x + rect_a.size.x > rect_b.position.x + tolerance
		and rect_a.position.y < rect_b.position.y + rect_b.size.y - tolerance
		and rect_a.position.y + rect_a.size.y > rect_b.position.y + tolerance
	)


func _attach_test_pile_preview(scene: Node, box_name: String, property_name: String) -> Control:
	var box := scene.find_child(box_name, true, false) as BoxContainer
	var preview := BattleCardViewScript.new()
	preview.set_clickable(false)
	preview.setup_from_instance(null, BattleCardViewScript.MODE_PREVIEW)
	if box != null:
		box.add_child(preview)
	scene.set(property_name, preview)
	return preview


func _attach_test_modal_overlay(scene: Node, overlay_name: String, child_name: String = "") -> Control:
	var overlay := Control.new()
	overlay.name = overlay_name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.add_child(overlay)
	if child_name != "":
		var child := Control.new()
		child.name = child_name
		child.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.add_child(child)
	return overlay


func test_layout_resolver_auto_portrait_for_phone_viewport() -> String:
	var controller := BattleLayoutControllerScript.new()
	var mode := str(controller.call("resolve_layout_mode", Vector2(390, 844), "auto", true))
	return assert_eq(mode, "portrait", "Auto layout should use portrait on phone-shaped mobile viewports")


func test_layout_resolver_auto_landscape_for_wide_viewport() -> String:
	var controller := BattleLayoutControllerScript.new()
	var mode := str(controller.call("resolve_layout_mode", Vector2(844, 390), "auto", true))
	return assert_eq(mode, "landscape", "Auto layout should keep landscape on wide viewports")


func test_layout_coordinator_dispatches_to_portrait_and_landscape_views() -> String:
	var scene := LayoutCoordinatorSpyScene.new()
	var controller := BattleLayoutControllerScript.new()
	var coordinator := BattleLayoutCoordinatorScript.new()
	coordinator.call("setup", scene, controller)

	var portrait_context: Dictionary = coordinator.call("apply", Vector2(390, 844), GameManager.BATTLE_LAYOUT_PORTRAIT, true)
	var portrait_mode := str(coordinator.call("active_mode"))
	var portrait_content_rect: Rect2 = portrait_context.get("content_rect", Rect2())
	var landscape_context: Dictionary = coordinator.call("apply", Vector2(844, 390), GameManager.BATTLE_LAYOUT_LANDSCAPE, true)
	var landscape_mode := str(coordinator.call("active_mode"))

	var result := run_checks([
		assert_eq(str(portrait_context.get("resolved_mode", "")), GameManager.BATTLE_LAYOUT_PORTRAIT, "Layout coordinator should dispatch forced portrait to the portrait view"),
		assert_eq(portrait_mode, GameManager.BATTLE_LAYOUT_PORTRAIT, "Layout coordinator should expose the active portrait view"),
		assert_eq(scene.portrait_full_size, Vector2(390, 844), "Portrait view should receive the logical portrait canvas size"),
		assert_eq(scene.portrait_apply_size, portrait_content_rect.size, "Portrait view should apply the aspect-constrained portrait content size"),
		assert_eq(str(landscape_context.get("resolved_mode", "")), GameManager.BATTLE_LAYOUT_LANDSCAPE, "Layout coordinator should dispatch forced landscape to the landscape view"),
		assert_eq(landscape_mode, GameManager.BATTLE_LAYOUT_LANDSCAPE, "Layout coordinator should expose the active landscape view"),
		assert_eq(scene.landscape_apply_size, Vector2(844, 390), "Landscape view should receive the physical landscape viewport"),
	])

	scene.queue_free()
	return result


func test_battle_layout_forced_portrait_uses_portrait_desktop_preview_window() -> String:
	var size := GameManager.battle_layout_desktop_window_size_for_mode(
		GameManager.BATTLE_LAYOUT_PORTRAIT,
		Vector2i(1600, 900),
		Vector2i(1920, 1080)
	)
	return run_checks([
		assert_gt(size.y, size.x, "Forced portrait should rotate the desktop preview window to a tall viewport"),
		assert_gte(size.x, 360, "Forced portrait preview should keep a usable minimum touch width"),
		assert_gte(size.y, 640, "Forced portrait preview should keep a usable minimum touch height"),
	])


func test_battle_layout_forced_landscape_restores_landscape_desktop_preview_window() -> String:
	var size := GameManager.battle_layout_desktop_window_size_for_mode(
		GameManager.BATTLE_LAYOUT_LANDSCAPE,
		Vector2i(900, 1600),
		Vector2i(1920, 1080)
	)
	return assert_gt(size.x, size.y, "Forced landscape should restore a wide desktop preview window")


func test_macos_desktop_launch_does_not_auto_maximize_window() -> String:
	return assert_false(
		bool(GameManager.call("_should_maximize_desktop_window", "macOS")),
		"macOS launch should keep the configured window size instead of entering maximized mode"
	)


func test_macos_desktop_launch_uses_large_windowed_size() -> String:
	var size: Vector2i = GameManager.call(
		"_desktop_window_size_for_os",
		"macOS",
		Vector2i(1600, 900),
		Vector2i(2560, 1600)
	)
	var aspect := float(size.x) / float(size.y)
	return run_checks([
		assert_gt(size.x, 1600, "macOS launch should enlarge the window on high-resolution screens"),
		assert_gt(size.y, 900, "macOS launch should enlarge the window height on high-resolution screens"),
		assert_true(size.x <= 2512, "macOS launch should leave a windowed horizontal margin"),
		assert_true(size.y <= 1552, "macOS launch should leave a windowed vertical margin"),
		assert_true(absf(aspect - (16.0 / 9.0)) < 0.01, "macOS launch should preserve the configured landscape aspect ratio"),
	])


func test_macos_battle_landscape_keeps_large_windowed_size() -> String:
	var size: Vector2i = GameManager.call(
		"_battle_desktop_window_size_for_os",
		"macOS",
		GameManager.BATTLE_LAYOUT_LANDSCAPE,
		Vector2i(1600, 900),
		Vector2i(2560, 1600)
	)
	var aspect := float(size.x) / float(size.y)
	return run_checks([
		assert_gt(size.x, 1600, "macOS battle landscape should not shrink back to the configured width"),
		assert_gt(size.y, 900, "macOS battle landscape should not shrink back to the configured height"),
		assert_true(size.x <= 2512, "macOS battle landscape should stay windowed horizontally"),
		assert_true(size.y <= 1552, "macOS battle landscape should stay windowed vertically"),
		assert_true(absf(aspect - (16.0 / 9.0)) < 0.01, "macOS battle landscape should preserve the configured landscape aspect ratio"),
	])


func test_forced_portrait_rotates_canvas_when_runtime_viewport_stays_landscape() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var physical := Vector2(1600, 900)
	var logical: Vector2 = scene.call("_battle_layout_logical_viewport_size", physical, GameManager.BATTLE_LAYOUT_PORTRAIT)
	scene.call("_apply_battle_canvas_transform", true, physical, logical)

	var result := run_checks([
		assert_eq(logical, Vector2(900, 1600), "Forced portrait should use a rotated logical viewport if the runtime stays landscape"),
		assert_true(absf(scene.rotation_degrees - 90.0) < 0.01, "Forced portrait fallback should rotate the battle scene root by 90 degrees"),
		assert_eq(scene.position, Vector2(1600, 0), "Rotated portrait fallback should anchor the rotated canvas inside the physical viewport"),
		assert_eq(scene.size, Vector2(900, 1600), "Rotated portrait fallback should resize the scene root to the logical portrait viewport"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_clears_rotated_portrait_canvas_transform() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_battle_canvas_transform", true, Vector2(1600, 900), Vector2(900, 1600))
	scene.call("_apply_battle_canvas_transform", false, Vector2(1600, 900), Vector2(1600, 900))

	var result := run_checks([
		assert_true(absf(scene.rotation_degrees) < 0.01, "Landscape layout should clear the forced portrait canvas rotation"),
		assert_eq(scene.position, Vector2.ZERO, "Landscape layout should reset the scene root position"),
		assert_eq(scene.size, Vector2(1600, 900), "Landscape layout should resize the scene root back to the logical landscape viewport"),
	])

	scene.queue_free()
	return result


func test_project_allows_runtime_mobile_screen_orientation_switching() -> String:
	var orientation := int(ProjectSettings.get_setting("display/window/handheld/orientation", -1))
	return assert_eq(orientation, DisplayServer.SCREEN_SENSOR, "Mobile export should allow runtime portrait/landscape orientation switching")


func test_android_export_preset_allows_runtime_mobile_screen_orientation_switching() -> String:
	var preset_text := FileAccess.get_file_as_string("res://export_presets.cfg")
	return assert_str_contains(preset_text, "screen/orientation=6", "Android export preset should allow runtime portrait/landscape orientation switching")


func test_mobile_non_battle_orientation_defaults_to_landscape() -> String:
	var previous_mode := str(GameManager.non_battle_layout_mode)
	GameManager.non_battle_layout_mode = GameManager.NON_BATTLE_LAYOUT_LANDSCAPE
	var orientation := GameManager.non_battle_handheld_orientation()
	GameManager.non_battle_layout_mode = previous_mode
	return assert_eq(
		orientation,
		DisplayServer.SCREEN_SENSOR_LANDSCAPE,
		"Non-battle mobile scenes should default to landscape so the app does not open in portrait"
	)


func test_mobile_battle_orientation_maps_only_battle_portrait_to_portrait() -> String:
	return run_checks([
		assert_eq(
			GameManager.battle_handheld_orientation_for_mode(GameManager.BATTLE_LAYOUT_PORTRAIT),
			DisplayServer.SCREEN_SENSOR_PORTRAIT,
			"Battle portrait mode should request mobile portrait orientation"
		),
		assert_eq(
			GameManager.battle_handheld_orientation_for_mode(GameManager.BATTLE_LAYOUT_LANDSCAPE),
			DisplayServer.SCREEN_SENSOR_LANDSCAPE,
			"Battle landscape mode should request mobile landscape orientation"
		),
	])


func test_battle_scene_responsive_layout_stabilization_keeps_latest_longer_window() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_schedule_responsive_layout_stabilization", 3)
	scene.call("_schedule_responsive_layout_stabilization", 2)
	var first_remaining := int(scene.get("_responsive_layout_stabilization_frames_remaining"))
	scene.call("_schedule_responsive_layout_stabilization", 6)
	var extended_remaining := int(scene.get("_responsive_layout_stabilization_frames_remaining"))

	var result := run_checks([
		assert_eq(first_remaining, 3, "Layout stabilization should not shorten an active startup relayout window"),
		assert_eq(extended_remaining, 6, "Layout stabilization should extend when a longer window is requested"),
	])

	scene.queue_free()
	return result


func test_portrait_metrics_fit_single_row_bench_shape_and_larger_hand() -> String:
	var controller := BattleLayoutControllerScript.new()
	var measured_variant: Variant = controller.call("measure_portrait_card_layout", Vector2(900, 1600), 5, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var bench_size: Vector2 = measured.get("bench_card_size", Vector2.ZERO)
	var hand_size: Vector2 = measured.get("hand_card_size", Vector2.ZERO)
	var active_size: Vector2 = measured.get("active_card_size", Vector2.ZERO)
	var columns: int = int(measured.get("bench_columns", 0))
	var rows: int = int(measured.get("bench_rows", 0))
	var total_bench_width := bench_size.x * 5.0 + 4.0 * float(measured.get("bench_gap", 0.0))
	var total_hand_width := hand_size.x * 5.0 + 4.0 * 12.0

	return run_checks([
		assert_eq(columns, 5, "Portrait player bench should use one five-card row"),
		assert_eq(rows, 1, "Five bench slots should fit into a single portrait row"),
		assert_true(total_bench_width <= 900.0, "Five bench columns should fit within the portrait content width"),
		assert_gte(bench_size.y, 220.0, "Portrait bench cards should be much larger than the old compact slots"),
		assert_true(total_hand_width <= 900.0, "Portrait hand cards should fit five visible cards across a phone-width hand rail"),
		assert_gte(hand_size.y, 220.0, "Portrait hand cards should remain touch-sized while showing five cards"),
		assert_gte(active_size.y, 260.0, "Portrait active card should stay prominent"),
	])


func test_portrait_metrics_fit_five_hand_cards_on_fold_safe_width() -> String:
	var controller := BattleLayoutControllerScript.new()
	var measured_variant: Variant = controller.call("measure_portrait_card_layout", Vector2(850, 1600), 5, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var hand_size: Vector2 = measured.get("hand_card_size", Vector2.ZERO)
	var total_hand_width := hand_size.x * 5.0 + 4.0 * 12.0

	return run_checks([
		assert_true(total_hand_width <= 850.0, "Fold-width portrait hand rail must fit five visible cards without horizontal overflow"),
		assert_gte(hand_size.y, 210.0, "Fold-width portrait hand cards should stay large enough after width limiting"),
	])


func test_portrait_metrics_compensate_for_android_expand_logical_width() -> String:
	var controller := BattleLayoutControllerScript.new()
	var content_rect: Rect2 = controller.call("portrait_content_rect", Vector2(1600, 2844))
	var measured_variant: Variant = controller.call("measure_portrait_card_layout", content_rect.size, 5, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var ui_scale := float(measured.get("ui_scale", 1.0))
	var bench_size: Vector2 = measured.get("bench_card_size", Vector2.ZERO)
	var hand_size: Vector2 = measured.get("hand_card_size", Vector2.ZERO)
	var active_size: Vector2 = measured.get("active_card_size", Vector2.ZERO)
	var five_hand_width := hand_size.x * 5.0 + 4.0 * 12.0

	return run_checks([
		assert_eq(content_rect.position, Vector2.ZERO, "Portrait content should use the full Android expanded logical canvas"),
		assert_eq(content_rect.size, Vector2(1600, 2844), "Tall Android expanded portrait content should still use the full logical viewport"),
		assert_gte(ui_scale, 1.7, "Portrait metrics should scale up on Android's expanded logical canvas so physical touch targets remain readable"),
		assert_gte(bench_size.y, 420.0, "Expanded portrait bench cards should remain readable after physical stretch mapping"),
		assert_gte(active_size.y, 470.0, "Expanded portrait active cards should remain readable after physical stretch mapping"),
		assert_true(five_hand_width <= content_rect.size.x + 0.5, "Expanded portrait hand rail should fit five visible cards inside the full logical viewport"),
	])


func test_portrait_content_rect_centers_short_wide_portrait_surface() -> String:
	var controller := BattleLayoutControllerScript.new()
	var content_rect: Rect2 = controller.call("portrait_content_rect", Vector2(1280, 1600))

	return run_checks([
		assert_eq(content_rect.position, Vector2(190, 0), "Short wide portrait content should be centered instead of stretching to the raw viewport edge"),
		assert_eq(content_rect.size, Vector2(900, 1600), "Short wide portrait content should use a 9:16 battle surface"),
	])


func test_portrait_content_rect_uses_full_tall_phone_viewport() -> String:
	var controller := BattleLayoutControllerScript.new()
	var content_rect: Rect2 = controller.call("portrait_content_rect", Vector2(900, 1950))

	return run_checks([
		assert_eq(content_rect.size, Vector2(900, 1950), "Portrait battle content should use the full tall Android viewport"),
		assert_eq(content_rect.position, Vector2.ZERO, "Portrait battle content should not introduce a second centered frame inside the real screen"),
	])


func test_rotated_portrait_metrics_scale_bench_with_hand_and_active_cards() -> String:
	var controller := BattleLayoutControllerScript.new()
	var measured_variant: Variant = controller.call("measure_portrait_card_layout", Vector2(900, 1600), 8, 0.716)
	var default_variant: Variant = controller.call("measure_portrait_card_layout", Vector2(900, 1600), 5, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var default_measured: Dictionary = default_variant if default_variant is Dictionary else {}
	var bench_size: Vector2 = measured.get("bench_card_size", Vector2.ZERO)
	var hand_size: Vector2 = measured.get("hand_card_size", Vector2.ZERO)
	var active_size: Vector2 = measured.get("active_card_size", Vector2.ZERO)
	var default_bench_size: Vector2 = default_measured.get("bench_card_size", Vector2.ZERO)
	var default_hand_size: Vector2 = default_measured.get("hand_card_size", Vector2.ZERO)
	var default_active_size: Vector2 = default_measured.get("active_card_size", Vector2.ZERO)
	var hand_area_height := float(measured.get("hand_area_height", -1.0))
	var hand_visible_cards := int(measured.get("hand_visible_cards", 0))
	var columns: int = int(measured.get("bench_columns", 0))
	var rows: int = int(measured.get("bench_rows", 0))
	var total_bench_width := bench_size.x * 4.0 + 3.0 * float(measured.get("bench_gap", 0.0))
	var total_hand_width := hand_size.x * 6.0 + 5.0 * 12.0
	var pre_boost_active_height := _expanded_portrait_active_height_before_boost(Vector2(900, 1600), 8, 0.716)
	var boosted_active_height := pre_boost_active_height * 1.10

	return run_checks([
		assert_eq(columns, 4, "Expanded portrait bench should use four columns"),
		assert_eq(rows, 2, "Expanded portrait bench should use two rows"),
		assert_eq(hand_visible_cards, 6, "Expanded portrait hand rail should size around six visible cards"),
		assert_true(total_bench_width <= 900.0, "Expanded portrait bench rows should fit four cards within the safe width"),
		assert_true(total_hand_width <= 900.0, "Expanded portrait hand rail should fit six visible cards within the safe width"),
		assert_true(absf(hand_area_height - hand_size.y) <= 0.1, "Expanded portrait hand HUD should reclaim padding and match the card height"),
		assert_gte(bench_size.y, 150.0, "Expanded portrait bench cards should remain readable after fitting eight slots"),
		assert_true(hand_size.y <= bench_size.y + 8.0, "Hand cards should be slightly smaller than bench cards so five cards fit across the hand rail"),
		assert_gte(active_size.y, bench_size.y, "Active Pokemon should remain at least as prominent as bench cards"),
		assert_true(absf(active_size.y - boosted_active_height) <= 0.5, "Area Zero portrait active cards should be 10% taller than the pre-boost expanded layout"),
		assert_true(hand_size.y >= default_hand_size.y * 0.70 - 1.0 and hand_size.y <= default_hand_size.y * 0.72, "Expanded portrait hand area should reclaim the designed 30% height budget without shrinking further"),
		assert_true(active_size.y < default_active_size.y and bench_size.y < default_bench_size.y, "Expanded portrait should proportionally shrink field cards instead of pushing regions out"),
	])


func test_portrait_area_zero_metrics_fit_small_phone_vertical_budget() -> String:
	var controller := BattleLayoutControllerScript.new()
	var viewport_size := Vector2(390, 844)
	var measured_variant: Variant = controller.call("measure_portrait_card_layout", viewport_size, 8, 0.716)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	var bench_size: Vector2 = measured.get("bench_card_size", Vector2.ZERO)
	var hand_size: Vector2 = measured.get("hand_card_size", Vector2.ZERO)
	var active_size: Vector2 = measured.get("active_card_size", Vector2.ZERO)
	var rows := int(measured.get("bench_rows", 0))
	var bench_gap := float(measured.get("bench_gap", 0.0))
	var ui_scale := float(measured.get("ui_scale", 1.0))
	var top_reserved := (BattleLayoutControllerScript.PORTRAIT_TOP_BAR_TOP_PADDING + BattleLayoutControllerScript.PORTRAIT_TOP_BAR_HEIGHT + BattleLayoutControllerScript.PORTRAIT_TOP_BAR_GAP) * ui_scale
	var stadium_reserved := maxf(BattleLayoutControllerScript.PORTRAIT_STADIUM_HEIGHT * ui_scale, 56.0)
	var center_separation_reserved := maxf(3.0 * ui_scale, 3.0)
	var field_height := (active_size.y + bench_size.y * float(rows) + bench_gap * float(maxi(rows - 1, 0))) * 2.0 + stadium_reserved
	var total_height := top_reserved + field_height + hand_size.y + center_separation_reserved

	return run_checks([
		assert_eq(rows, 2, "Area Zero on a narrow portrait phone should still use two visible bench rows"),
		assert_true(total_height <= viewport_size.y + 1.0, "Area Zero portrait metrics must fit the visible height instead of pushing HUDs up and hand down: %.1f <= %.1f" % [total_height, viewport_size.y]),
		assert_gte(bench_size.y, 58.0, "Area Zero portrait bench cards should keep the minimum readable size under the vertical budget"),
		assert_gte(active_size.y, bench_size.y, "Area Zero portrait active Pokemon should remain at least as prominent as bench cards"),
	])


func test_landscape_metrics_shrink_expanded_bench_to_fit_eight_slots() -> String:
	var controller := BattleLayoutControllerScript.new()
	var default_variant: Variant = controller.call("measure_card_layout", Vector2(1366, 768), 750.0, 8.0, 5, 0.716)
	var expanded_variant: Variant = controller.call("measure_card_layout", Vector2(1366, 768), 750.0, 1.0, 8, 0.716)
	var default_measured: Dictionary = default_variant if default_variant is Dictionary else {}
	var expanded_measured: Dictionary = expanded_variant if expanded_variant is Dictionary else {}
	var default_size: Vector2 = default_measured.get("play_card_size", Vector2.ZERO)
	var expanded_size: Vector2 = expanded_measured.get("play_card_size", Vector2.ZERO)
	var total_expanded_width := expanded_size.x * 8.0 + 1.0 * 7.0

	return run_checks([
		assert_true(expanded_size.y <= default_size.y, "Landscape eight-slot bench should not grow beyond the five-slot layout"),
		assert_true(total_expanded_width <= 712.0, "Landscape eight-slot bench should fit inside center field width after one-pixel spacing compression"),
		assert_gte(expanded_size.y, 82.0, "Landscape eight-slot bench cards should stay above the expanded minimum size"),
	])


func test_landscape_bench_slot_gap_is_one_pixel() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_landscape_layout", Vector2(1600, 900))
	var my_bench := scene.find_child("MyBench", true, false) as HBoxContainer
	var opp_bench := scene.find_child("OppBench", true, false) as HBoxContainer
	var result := run_checks([
		assert_eq(my_bench.get_theme_constant("separation") if my_bench != null else -1, 1, "Landscape player bench slots should use a one-pixel gap"),
		assert_eq(opp_bench.get_theme_constant("separation") if opp_bench != null else -1, 1, "Landscape opponent bench slots should use a one-pixel gap"),
	])
	scene.queue_free()
	return result


func test_portrait_area_zero_expanded_bench_uses_two_visible_rows() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	var my_bench := scene.find_child("MyBench", true, false) as HBoxContainer
	var opp_bench := scene.find_child("OppBench", true, false) as HBoxContainer
	scene.call("_ensure_bench_container_panel_capacity", my_bench, "MyBench", "MyBenchLbl", 8)
	scene.call("_ensure_bench_container_panel_capacity", opp_bench, "OppBench", "OppBenchLbl", 8)

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active_card := _make_basic_pokemon_card("Tera Active %d" % player_index)
		active_card.ancient_trait = "Tera"
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(active_card, player_index))
		player.active_pokemon = active_slot
		for i: int in 8:
			var bench_slot := PokemonSlot.new()
			bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Bench %d-%d" % [player_index, i]), player_index))
			player.bench.append(bench_slot)
		game_state.players.append(player)
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	var stadium_data := _make_stadium_card("Area Zero Underdepths")
	stadium_data.effect_id = AreaZeroUnderdepthsScript.EFFECT_ID
	game_state.stadium_card = CardInstance.create(stadium_data, 0)
	game_state.stadium_owner_index = 0
	gsm.game_state = game_state
	scene.set("_gsm", gsm)

	var display_size := int(scene.call("_current_bench_display_size"))
	scene.call("_sync_bench_slot_visibility", display_size)
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var portrait_grid := scene.find_child("PortraitMyBenchGrid", true, false) as VBoxContainer
	var row0: HBoxContainer = null
	var row1: HBoxContainer = null
	if portrait_grid != null:
		row0 = portrait_grid.get_node_or_null("Row0") as HBoxContainer
		row1 = portrait_grid.get_node_or_null("Row1") as HBoxContainer
	var first_slot := scene.find_child("MyBench0", true, false) as Control
	var row0_visible := 0
	var row1_visible := 0
	if row0 != null:
		for child: Node in row0.get_children():
			if child is Control and (child as Control).visible:
				row0_visible += 1
	if row1 != null:
		for child: Node in row1.get_children():
			if child is Control and (child as Control).visible:
				row1_visible += 1
	var safe_width := _portrait_safe_width(scene, Vector2(390, 844))
	var grid_width := portrait_grid.custom_minimum_size.x if portrait_grid != null else 9999.0
	var hand_area := scene.find_child("HandArea", true, false) as Control
	var hand_scroll := scene.find_child("HandScroll", true, false) as Control
	var hand_container := scene.find_child("HandContainer", true, false) as Control
	var my_active := scene.find_child("MyActive", true, false) as Control
	var opp_active := scene.find_child("OppActive", true, false) as Control
	var safe_viewport_size := Vector2(_portrait_safe_width(scene, Vector2(390, 844)), 844)
	var expected_active_height := _expanded_portrait_active_height_before_boost(safe_viewport_size, 8, 0.716) * 1.10

	var result := run_checks([
		assert_eq(display_size, 8, "Area Zero with Tera in play should expand visible bench capacity to eight"),
		assert_true(my_bench != null and not my_bench.visible, "Expanded portrait layout should still hide the horizontal bench host"),
		assert_true(portrait_grid != null and portrait_grid.visible, "Expanded portrait layout should use a visible two-row grid"),
		assert_eq(row0_visible, 4, "Expanded portrait first bench row should contain four visible slots"),
		assert_eq(row1_visible, 4, "Expanded portrait second bench row should contain four visible slots"),
		assert_true(grid_width <= safe_width + 0.5, "Expanded portrait bench grid should fit within safe portrait width"),
		assert_true(first_slot != null and first_slot.custom_minimum_size.y >= 58.0, "Expanded portrait bench slots should keep the minimum readable size"),
		assert_true(hand_area != null and hand_container != null and absf(hand_area.custom_minimum_size.y - hand_container.custom_minimum_size.y) <= 0.1, "Expanded portrait hand HUD should match the resized hand card height"),
		assert_true(hand_scroll != null and hand_container != null and absf(hand_scroll.custom_minimum_size.y - hand_container.custom_minimum_size.y) <= 0.1, "Expanded portrait hand scroll area should not reserve extra vertical padding"),
		assert_true(my_active != null and absf(my_active.custom_minimum_size.y - expected_active_height) <= 0.5, "Area Zero portrait player active card should receive the 10% height boost"),
		assert_true(opp_active != null and absf(opp_active.custom_minimum_size.y - expected_active_height) <= 0.5, "Area Zero portrait opponent active card should receive the 10% height boost"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_area_zero_repeated_relayout_does_not_drift_vertical_regions() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	var my_bench := scene.find_child("MyBench", true, false) as HBoxContainer
	var opp_bench := scene.find_child("OppBench", true, false) as HBoxContainer
	scene.call("_ensure_bench_container_panel_capacity", my_bench, "MyBench", "MyBenchLbl", 8)
	scene.call("_ensure_bench_container_panel_capacity", opp_bench, "OppBench", "OppBenchLbl", 8)

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active_card := _make_basic_pokemon_card("Tera Active %d" % player_index)
		active_card.ancient_trait = "Tera"
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(active_card, player_index))
		player.active_pokemon = active_slot
		for i: int in 8:
			var bench_slot := PokemonSlot.new()
			bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Bench %d-%d" % [player_index, i]), player_index))
			player.bench.append(bench_slot)
		game_state.players.append(player)
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	var stadium_data := _make_stadium_card("Area Zero Underdepths")
	stadium_data.effect_id = AreaZeroUnderdepthsScript.EFFECT_ID
	game_state.stadium_card = CardInstance.create(stadium_data, 0)
	game_state.stadium_owner_index = 0
	gsm.game_state = game_state
	scene.set("_gsm", gsm)

	var viewport_size := Vector2(390, 844)
	scene.call("_sync_bench_slot_visibility", scene.call("_current_bench_display_sizes"))
	scene.call("_apply_portrait_layout", viewport_size)
	scene.call("_finalize_portrait_layout_constraints")
	var hand_area := scene.find_child("HandArea", true, false) as Control
	var opp_right_group := scene.find_child("OppPortraitRightHudGroup", true, false) as Control
	var my_right_group := scene.find_child("MyPortraitRightHudGroup", true, false) as Control
	var first_hand_rect := _battle_local_rect(scene, hand_area)
	var first_opp_right_rect := _battle_local_rect(scene, opp_right_group)
	var first_my_right_rect := _battle_local_rect(scene, my_right_group)
	for _i: int in 6:
		scene.call("_sync_bench_slot_visibility", scene.call("_current_bench_display_sizes"))
		scene.call("_apply_portrait_layout", viewport_size)
		scene.call("_finalize_portrait_layout_constraints")
	var final_hand_rect := _battle_local_rect(scene, hand_area)
	var final_opp_right_rect := _battle_local_rect(scene, opp_right_group)
	var final_my_right_rect := _battle_local_rect(scene, my_right_group)

	var result := run_checks([
		assert_true(absf(final_hand_rect.position.y - first_hand_rect.position.y) <= 0.5, "Area Zero portrait hand area must not drift downward across repeated relayouts: %.1f -> %.1f" % [first_hand_rect.position.y, final_hand_rect.position.y]),
		assert_true(absf(final_opp_right_rect.position.y - first_opp_right_rect.position.y) <= 0.5, "Area Zero opponent pile HUD must not drift upward across repeated relayouts: %.1f -> %.1f" % [first_opp_right_rect.position.y, final_opp_right_rect.position.y]),
		assert_true(absf(final_my_right_rect.position.y - first_my_right_rect.position.y) <= 0.5, "Area Zero player pile HUD must not drift upward across repeated relayouts: %.1f -> %.1f" % [first_my_right_rect.position.y, final_my_right_rect.position.y]),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_area_zero_expands_only_tera_side_bench_grid() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	var my_bench := scene.find_child("MyBench", true, false) as HBoxContainer
	var opp_bench := scene.find_child("OppBench", true, false) as HBoxContainer
	scene.call("_ensure_bench_container_panel_capacity", my_bench, "MyBench", "MyBenchLbl", 8)
	scene.call("_ensure_bench_container_panel_capacity", opp_bench, "OppBench", "OppBenchLbl", 8)

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	var my_player := PlayerState.new()
	my_player.player_index = 0
	var my_active_card := _make_basic_pokemon_card("Tera Active")
	my_active_card.ancient_trait = "Tera"
	var my_active_slot := PokemonSlot.new()
	my_active_slot.pokemon_stack.append(CardInstance.create(my_active_card, 0))
	my_player.active_pokemon = my_active_slot
	for i: int in 8:
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("My Bench %d" % i), 0))
		my_player.bench.append(bench_slot)
	var opp_player := PlayerState.new()
	opp_player.player_index = 1
	var opp_active_slot := PokemonSlot.new()
	opp_active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Plain Active"), 1))
	opp_player.active_pokemon = opp_active_slot
	for i: int in 5:
		var opp_slot := PokemonSlot.new()
		opp_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Opp Bench %d" % i), 1))
		opp_player.bench.append(opp_slot)
	game_state.players.append(my_player)
	game_state.players.append(opp_player)
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	var stadium_data := _make_stadium_card("Area Zero Underdepths")
	stadium_data.effect_id = AreaZeroUnderdepthsScript.EFFECT_ID
	game_state.stadium_card = CardInstance.create(stadium_data, 0)
	game_state.stadium_owner_index = 0
	gsm.game_state = game_state
	scene.set("_gsm", gsm)

	var display_sizes: Dictionary = scene.call("_current_bench_display_sizes")
	scene.call("_sync_bench_slot_visibility", display_sizes)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_finalize_portrait_layout_constraints")

	var my_grid := scene.find_child("PortraitMyBenchGrid", true, false) as VBoxContainer
	var opp_grid := scene.find_child("PortraitOppBenchGrid", true, false) as HBoxContainer
	var my_row0 := (my_grid.get_node_or_null("Row0") as HBoxContainer) if my_grid != null else null
	var my_row1 := (my_grid.get_node_or_null("Row1") as HBoxContainer) if my_grid != null else null
	var my_row0_visible := 0
	var my_row1_visible := 0
	if my_row0 != null:
		for child: Node in my_row0.get_children():
			if child is Control and (child as Control).visible:
				my_row0_visible += 1
	if my_row1 != null:
		for child: Node in my_row1.get_children():
			if child is Control and (child as Control).visible:
				my_row1_visible += 1
	var opp_visible := 0
	if opp_grid != null:
		for child_opp: Node in opp_grid.get_children():
			if child_opp is Control and (child_opp as Control).visible:
				opp_visible += 1
	var opp_slot5 := scene.find_child("OppBench5", true, false) as Control

	var result := run_checks([
		assert_eq(int(display_sizes.get("my", -1)), 8, "Tera side should request eight visible Bench slots"),
		assert_eq(int(display_sizes.get("opp", -1)), 5, "Non-Tera side should keep five visible Bench slots"),
		assert_true(my_grid != null and my_grid.visible, "Tera side should use a two-row portrait Bench grid"),
		assert_true(opp_grid != null and opp_grid.visible, "Non-Tera side should keep the one-row portrait Bench grid"),
		assert_eq(my_row0_visible, 4, "Tera side first row should contain four visible slots"),
		assert_eq(my_row1_visible, 4, "Tera side second row should contain four visible slots"),
		assert_eq(opp_visible, 5, "Non-Tera side should show exactly five Bench slots"),
		assert_true(opp_slot5 == null or not opp_slot5.visible, "Non-Tera side should not expose an extra sixth Bench slot"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_area_zero_expands_only_opponent_tera_side_bench_grid() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	var my_bench := scene.find_child("MyBench", true, false) as HBoxContainer
	var opp_bench := scene.find_child("OppBench", true, false) as HBoxContainer
	scene.call("_ensure_bench_container_panel_capacity", my_bench, "MyBench", "MyBenchLbl", 8)
	scene.call("_ensure_bench_container_panel_capacity", opp_bench, "OppBench", "OppBenchLbl", 8)

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	var my_player := PlayerState.new()
	my_player.player_index = 0
	var my_active_slot := PokemonSlot.new()
	my_active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Plain Active"), 0))
	my_player.active_pokemon = my_active_slot
	for i: int in 5:
		var my_slot := PokemonSlot.new()
		my_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("My Bench %d" % i), 0))
		my_player.bench.append(my_slot)
	var opp_player := PlayerState.new()
	opp_player.player_index = 1
	var opp_active_card := _make_basic_pokemon_card("Tera Active")
	opp_active_card.ancient_trait = "Tera"
	var opp_active_slot := PokemonSlot.new()
	opp_active_slot.pokemon_stack.append(CardInstance.create(opp_active_card, 1))
	opp_player.active_pokemon = opp_active_slot
	for i: int in 8:
		var opp_slot := PokemonSlot.new()
		opp_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Opp Bench %d" % i), 1))
		opp_player.bench.append(opp_slot)
	game_state.players.append(my_player)
	game_state.players.append(opp_player)
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	var stadium_data := _make_stadium_card("Area Zero Underdepths")
	stadium_data.effect_id = AreaZeroUnderdepthsScript.EFFECT_ID
	game_state.stadium_card = CardInstance.create(stadium_data, 0)
	game_state.stadium_owner_index = 0
	gsm.game_state = game_state
	scene.set("_gsm", gsm)

	var display_sizes: Dictionary = scene.call("_current_bench_display_sizes")
	scene.call("_sync_bench_slot_visibility", display_sizes)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_finalize_portrait_layout_constraints")

	var my_grid := scene.find_child("PortraitMyBenchGrid", true, false) as HBoxContainer
	var opp_grid := scene.find_child("PortraitOppBenchGrid", true, false) as VBoxContainer
	var opp_row0 := (opp_grid.get_node_or_null("Row0") as HBoxContainer) if opp_grid != null else null
	var opp_row1 := (opp_grid.get_node_or_null("Row1") as HBoxContainer) if opp_grid != null else null
	var my_visible := 0
	if my_grid != null:
		for child_my: Node in my_grid.get_children():
			if child_my is Control and (child_my as Control).visible:
				my_visible += 1
	var opp_row0_visible := 0
	var opp_row1_visible := 0
	if opp_row0 != null:
		for child_opp0: Node in opp_row0.get_children():
			if child_opp0 is Control and (child_opp0 as Control).visible:
				opp_row0_visible += 1
	if opp_row1 != null:
		for child_opp1: Node in opp_row1.get_children():
			if child_opp1 is Control and (child_opp1 as Control).visible:
				opp_row1_visible += 1
	var my_slot5 := scene.find_child("MyBench5", true, false) as Control

	var result := run_checks([
		assert_eq(int(display_sizes.get("my", -1)), 5, "Non-Tera player side should keep five visible Bench slots"),
		assert_eq(int(display_sizes.get("opp", -1)), 8, "Opponent Tera side should request eight visible Bench slots"),
		assert_true(my_grid != null and my_grid.visible, "Non-Tera player side should keep the one-row portrait Bench grid"),
		assert_true(opp_grid != null and opp_grid.visible, "Opponent Tera side should use a two-row portrait Bench grid"),
		assert_eq(my_visible, 5, "Non-Tera player side should show exactly five Bench slots"),
		assert_eq(opp_row0_visible, 4, "Opponent Tera side first row should contain four visible slots"),
		assert_eq(opp_row1_visible, 4, "Opponent Tera side second row should contain four visible slots"),
		assert_true(my_slot5 == null or not my_slot5.visible, "Non-Tera player side should not expose an extra sixth Bench slot"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_edge_hud_overlay_clamps_away_from_bench_rows() -> String:
	var scene := PortraitHudClampSceneStub.new()
	var overlay := Control.new()
	overlay.name = "PortraitEdgeHudOverlay"
	scene.add_child(overlay)
	var opp_bench := Control.new()
	opp_bench.name = "PortraitOppBenchGrid"
	opp_bench.position = Vector2(20, 110)
	opp_bench.size = Vector2(340, 140)
	scene.add_child(opp_bench)
	var my_bench := Control.new()
	my_bench.name = "PortraitMyBenchGrid"
	my_bench.position = Vector2(20, 600)
	my_bench.size = Vector2(340, 160)
	scene.add_child(my_bench)
	var groups: Array[Control] = []
	for group_name: String in ["OppPortraitLeftHudGroup", "OppPortraitRightHudGroup", "MyPortraitLeftHudGroup", "MyPortraitRightHudGroup"]:
		var group := Control.new()
		group.name = group_name
		group.custom_minimum_size = Vector2(120, 120)
		overlay.add_child(group)
		groups.append(group)
	var view := BattlePortraitLayoutView.new()
	view.setup(scene, null)
	view.position_edge_hud_overlay(Vector2(390, 844), 0.0, 0.0)
	var margin := maxf(4.0, 390.0 * 0.012)
	var opp_min_y := opp_bench.position.y + opp_bench.size.y + margin
	var my_max_y := my_bench.position.y - margin
	var opp_left := scene.find_child("OppPortraitLeftHudGroup", true, false) as Control
	var opp_right := scene.find_child("OppPortraitRightHudGroup", true, false) as Control
	var my_left := scene.find_child("MyPortraitLeftHudGroup", true, false) as Control
	var my_right := scene.find_child("MyPortraitRightHudGroup", true, false) as Control
	var result := run_checks([
		assert_gte(opp_left.position.y, opp_min_y - 0.5, "Opponent left HUD should be pushed below the opponent Bench row"),
		assert_gte(opp_right.position.y, opp_min_y - 0.5, "Opponent pile HUD should be pushed below the opponent Bench row"),
		assert_true(my_left.position.y + my_left.size.y <= my_max_y + 0.5, "Player left HUD should be pushed above the player Bench grid"),
		assert_true(my_right.position.y + my_right.size.y <= my_max_y + 0.5, "Player pile HUD should be pushed above the player Bench grid"),
	])
	scene.queue_free()
	return result


func test_battle_setup_layout_selector_defaults_legacy_auto_to_landscape_segment() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_AUTO
	var scene: Control = BattleSetupScene.instantiate()
	_add_scene_to_tree(scene)
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_AUTO
	scene.call("_setup_battle_layout_options")

	var option := scene.find_child("BattleLayoutOption", true, false) as OptionButton
	var label := scene.find_child("BattleLayoutLabel", true, false) as Label
	var segment := scene.find_child("BattleLayoutSegment", true, false) as HBoxContainer
	var landscape_button := scene.find_child("BattleLayoutLandscapeButton", true, false) as Button
	var selected_meta := str(option.get_item_metadata(option.selected)) if option != null and option.selected >= 0 else ""

	var result := run_checks([
		assert_not_null(label, "Battle setup should show a battle layout label under the background selector"),
		assert_not_null(segment, "Battle setup should expose battle layout as segment buttons"),
		assert_true(option != null and not option.visible, "Battle setup should keep the legacy battle layout option hidden"),
		assert_eq(selected_meta, GameManager.BATTLE_LAYOUT_LANDSCAPE, "Legacy auto layout should map to the visible landscape segment on desktop"),
		assert_true(landscape_button != null and landscape_button.get_theme_color("font_color") == Color(0.04, 0.10, 0.12, 1.0), "Landscape button should render as the active segment"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_battle_setup_layout_selector_exposes_landscape_and_portrait_segments() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	_add_scene_to_tree(scene)
	scene.call("_setup_battle_layout_options")
	var option := scene.find_child("BattleLayoutOption", true, false) as OptionButton
	var landscape_button := scene.find_child("BattleLayoutLandscapeButton", true, false) as Button
	var portrait_button := scene.find_child("BattleLayoutPortraitButton", true, false) as Button
	var metas: Array[String] = []
	var portrait_option_label := ""
	if option != null:
		for i: int in option.item_count:
			metas.append(str(option.get_item_metadata(i)))
		if option.item_count > 1:
			portrait_option_label = option.get_item_text(1)

	var result := run_checks([
		assert_eq(metas.size(), 2, "Battle setup layout selector should expose only landscape and portrait modes"),
		assert_false(GameManager.BATTLE_LAYOUT_AUTO in metas, "Battle layout selector should not expose auto mode"),
		assert_true(GameManager.BATTLE_LAYOUT_LANDSCAPE in metas, "Battle layout selector should include landscape mode"),
		assert_true(GameManager.BATTLE_LAYOUT_PORTRAIT in metas, "Battle layout selector should include portrait mode"),
		assert_true(landscape_button != null and landscape_button.text == "横屏", "Battle layout segment should include a landscape button"),
		assert_eq(portrait_button.text if portrait_button != null else "", "竖屏（手机建议使用）", "Battle layout segment should include the phone-recommended portrait button"),
		assert_eq(portrait_option_label, "竖屏（手机建议使用）", "Hidden battle layout option should use the same phone recommendation label"),
	])

	scene.queue_free()
	return result


func test_battle_setup_does_not_apply_battle_orientation_before_navigation() -> String:
	var file := FileAccess.open("res://scenes/battle_setup/BattleSetup.gd", FileAccess.READ)
	if file == null:
		return "BattleSetup.gd should be readable for the navigation orientation guard"
	var source := file.get_as_text()
	file.close()

	return run_checks([
		assert_false(source.contains("apply_battle_layout_orientation"), "Battle setup should only save the layout preference; battle orientation must be applied after BattleScene loads"),
	])


func test_battle_scene_defers_mobile_initial_orientation_until_first_frame() -> String:
	var source := ""
	for path: String in BATTLE_SCENE_RUNTIME_SOURCE_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return "BattleScene runtime source should be readable for the initial orientation guard: %s" % path
		source += "\n# %s\n%s" % [path, file.get_as_text()]
		file.close()
	var ready_start := source.find("func _ready()")
	var ready_end := source.find("\nfunc _exit_tree()", ready_start)
	var ready_source := source.substr(ready_start, ready_end - ready_start) if ready_start >= 0 and ready_end > ready_start else ""
	var scene: Control = BattleScene.instantiate()
	var defer_mobile := bool(scene.call("_should_defer_initial_battle_orientation_for_runtime", true))
	var defer_desktop := bool(scene.call("_should_defer_initial_battle_orientation_for_runtime", false))

	var result := run_checks([
		assert_true(ready_source.contains("_schedule_initial_battle_layout_orientation()"), "BattleScene._ready should schedule initial battle orientation instead of applying it synchronously"),
		assert_false(ready_source.contains("GameManager.apply_battle_layout_orientation()"), "BattleScene._ready must not synchronously rotate the previous setup frame"),
		assert_true(defer_mobile, "Mobile initial battle orientation should wait until BattleScene has presented a first frame"),
		assert_false(defer_desktop, "Desktop battle window shaping can stay synchronous"),
	])

	scene.queue_free()
	return result


func test_battle_setup_layout_selector_writes_game_manager() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_AUTO
	var scene: Control = BattleSetupScene.instantiate()
	_add_scene_to_tree(scene)
	scene.call("_setup_battle_layout_options")
	var portrait_button := scene.find_child("BattleLayoutPortraitButton", true, false) as Button
	if portrait_button == null:
		scene.queue_free()
		GameManager.battle_layout_mode = previous_layout
		return "Battle setup should expose BattleLayoutPortraitButton before write-through can be tested"

	portrait_button.pressed.emit()
	var result := run_checks([
		assert_eq(GameManager.battle_layout_mode, GameManager.BATTLE_LAYOUT_PORTRAIT, "Battle setup should write selected portrait layout to GameManager"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_battle_setup_first_run_layout_defaults_to_portrait_on_mobile_runtimes() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	var android_default := str(scene.call("_default_battle_layout_mode_for_first_run", "Android"))
	var ios_default := str(scene.call("_default_battle_layout_mode_for_first_run", "iOS"))
	var mobile_feature_default := str(scene.call("_default_battle_layout_mode_for_first_run", "", {"mobile": true}, "headless", Vector2.ZERO))
	var web_android_default := str(scene.call("_default_battle_layout_mode_for_first_run", "", {"web_android": true}, "headless", Vector2.ZERO))
	var web_ios_default := str(scene.call("_default_battle_layout_mode_for_first_run", "", {"web_ios": true}, "headless", Vector2.ZERO))
	var phone_web_viewport_default := str(scene.call("_default_battle_layout_mode_for_first_run", "Web", {}, "web", Vector2(390, 844)))
	var windows_default := str(scene.call("_default_battle_layout_mode_for_first_run", "Windows"))
	var desktop_web_default := str(scene.call("_default_battle_layout_mode_for_first_run", "Web", {}, "web", Vector2(1440, 900)))

	var result := run_checks([
		assert_eq(android_default, GameManager.BATTLE_LAYOUT_PORTRAIT, "Android first run should default to portrait battle layout"),
		assert_eq(ios_default, GameManager.BATTLE_LAYOUT_PORTRAIT, "iOS first run should default to portrait battle layout"),
		assert_eq(mobile_feature_default, GameManager.BATTLE_LAYOUT_PORTRAIT, "Generic mobile runtime should default to portrait battle layout"),
		assert_eq(web_android_default, GameManager.BATTLE_LAYOUT_PORTRAIT, "Android mobile browser should default to portrait battle layout"),
		assert_eq(web_ios_default, GameManager.BATTLE_LAYOUT_PORTRAIT, "iOS mobile browser should default to portrait battle layout"),
		assert_eq(phone_web_viewport_default, GameManager.BATTLE_LAYOUT_PORTRAIT, "Phone-sized Web viewport should default to portrait battle layout"),
		assert_eq(windows_default, GameManager.BATTLE_LAYOUT_LANDSCAPE, "Windows first run should default to landscape battle layout"),
		assert_eq(desktop_web_default, GameManager.BATTLE_LAYOUT_LANDSCAPE, "Desktop-sized Web viewport should keep landscape as the first-run default"),
	])

	scene.queue_free()
	return result


func test_battle_scene_hides_in_battle_layout_switch_button() -> String:
	var scene: Control = BattleScene.instantiate()
	var button := scene.find_child("BtnBattleLayout", true, false) as Button
	var more_button := scene.find_child("BtnBattleMore", true, false) as Button

	var result := run_checks([
		assert_not_null(button, "Battle scene may keep the layout button node for compatibility"),
		assert_eq(button.text, "布局", "Battle layout switch button should have a compact default label before runtime sync"),
		assert_true(button != null and not button.visible, "Battle scene should not expose an in-battle layout switch button"),
		assert_not_null(more_button, "Battle scene may keep the portrait more-actions node for compatibility"),
		assert_true(more_button != null and not more_button.visible, "Battle scene should not expose the portrait more-actions button by default"),
	])

	scene.queue_free()
	return result


func test_portrait_layout_collapses_side_panels_and_enlarges_hand() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var backdrop := TextureRect.new()
	backdrop.name = "BattleBackdrop"
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	scene.add_child(backdrop)
	scene.move_child(backdrop, 0)
	var my_deck_preview := _attach_test_pile_preview(scene, "MyDeckHudBox", "_my_deck_preview")
	var my_discard_preview := _attach_test_pile_preview(scene, "MyDiscardHudBox", "_my_discard_preview")
	var opp_deck_preview := _attach_test_pile_preview(scene, "OppDeckHudBox", "_opp_deck_preview")
	var opp_discard_preview := _attach_test_pile_preview(scene, "OppDiscardHudBox", "_opp_discard_preview")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var left_panel := scene.get_node("MainArea/LeftPanel") as Control
	var right_panel := scene.get_node("MainArea/RightPanel") as Control
	var log_panel := scene.get_node("MainArea/LogPanel") as Control
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	var my_bench := scene.find_child("MyBench", true, false) as BoxContainer
	var portrait_grid := scene.find_child("PortraitMyBenchGrid", true, false) as HBoxContainer
	var first_bench_slot := scene.find_child("MyBench0", true, false) as Control
	var my_prize_hud := scene.find_child("MyHudLeft", true, false) as Control
	var opp_prize_hud := scene.find_child("OppHudLeft", true, false) as Control
	var opp_prize_title := scene.find_child("OppHudLeftTitle", true, false) as Label
	var opp_prize_value := scene.find_child("OppHudLeftValue", true, false) as Label
	var my_pile_hud := scene.find_child("MyHudRight", true, false) as Control
	var opp_pile_hud := scene.find_child("OppHudRight", true, false) as Control
	var my_pile_vbox := scene.find_child("MyHudRightVBox", true, false) as VBoxContainer
	var opp_pile_vbox := scene.find_child("OppHudRightVBox", true, false) as VBoxContainer
	var my_prize_host := scene.find_child("MyPrizeHudHost", true, false) as Control
	var opp_prize_host := scene.find_child("OppPrizeHudHost", true, false) as Control
	var my_pile_stack := scene.find_child("MyHudDataRow", true, false) as HBoxContainer
	var opp_pile_stack := scene.find_child("OppHudDataRow", true, false) as HBoxContainer
	var my_deck_value := scene.find_child("MyDeckHudValue", true, false) as Label
	var my_deck_caption := scene.find_child("MyDeckHudCaption", true, false) as Label
	var my_deck_panel := scene.find_child("MyDeckHudPanel", true, false) as Control
	var my_vstar_caption := scene.find_child("MyVstarCaption", true, false) as Label
	var my_vstar_value := scene.find_child("MyVstarValue", true, false) as Label
	var my_vstar_panel := scene.find_child("InfoMyVstar", true, false) as Control
	var my_lost_panel := scene.find_child("InfoMyLost", true, false) as Control
	var opp_vstar_panel := scene.find_child("InfoEnemyVstar", true, false) as Control
	var opp_lost_panel := scene.find_child("InfoEnemyLost", true, false) as Control
	var my_vstar_image := my_vstar_panel.find_child("HudImageTexture", true, false) as TextureRect if my_vstar_panel != null else null
	var opp_vstar_image := opp_vstar_panel.find_child("HudImageTexture", true, false) as TextureRect if opp_vstar_panel != null else null
	var my_status_stack := scene.find_child("MyPortraitStatusStack", true, false) as VBoxContainer
	var opp_status_stack := scene.find_child("OppPortraitStatusStack", true, false) as VBoxContainer
	var my_left_group := scene.find_child("MyPortraitLeftHudGroup", true, false) as BoxContainer
	var opp_left_group := scene.find_child("OppPortraitLeftHudGroup", true, false) as BoxContainer
	var my_right_group := scene.find_child("MyPortraitRightHudGroup", true, false) as BoxContainer
	var opp_right_group := scene.find_child("OppPortraitRightHudGroup", true, false) as BoxContainer
	var edge_overlay := scene.find_child("PortraitEdgeHudOverlay", true, false) as Control
	var dialog_overlay := scene.find_child("DialogOverlay", true, false) as Control
	var my_prize_title := scene.find_child("MyHudLeftTitle", true, false) as Label
	var my_prize_value := scene.find_child("MyHudLeftValue", true, false) as Label
	var stadium_center := scene.find_child("StadiumCenterSection", true, false) as Control
	var vstar_section := scene.find_child("VstarSection", true, false) as Control
	var stadium_sections := scene.find_child("StadiumSections", true, false) as HBoxContainer
	var turn_action_column := scene.find_child("TurnActionColumn", true, false) as Control
	var my_active_row := scene.find_child("MyActiveRow", true, false) as HBoxContainer
	var opp_active_row := scene.find_child("OppActiveRow", true, false) as HBoxContainer
	var my_field_shell := scene.find_child("MyFieldShell", true, false) as HBoxContainer
	var opp_field_shell := scene.find_child("OppFieldShell", true, false) as HBoxContainer
	var my_field_inner := scene.find_child("MyFieldInner", true, false) as VBoxContainer
	var opp_field_inner := scene.find_child("OppFieldInner", true, false) as VBoxContainer
	var main_area := scene.find_child("MainArea", true, false) as Control
	var top_bar := scene.find_child("TopBar", true, false) as Control
	var hand_area := scene.find_child("HandArea", true, false) as Control
	var layout_button := scene.find_child("BtnBattleLayout", true, false) as Button
	var more_button := scene.find_child("BtnBattleMore", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false) as Button
	var zeus_button := scene.find_child("BtnZeusHelp", true, false) as Button
	var compact_hand_scroll_limit := 240.0 + float(HudThemeScript.SCROLLBAR_PORTRAIT_TOUCH_THICKNESS + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING)
	var visible_bench_slots := 0
	if portrait_grid != null:
		for child: Node in portrait_grid.get_children():
			if child is Control and (child as Control).visible:
				visible_bench_slots += 1

	var result := run_checks([
		assert_false(left_panel.visible, "Portrait layout should hide the permanent prize side panel"),
		assert_false(right_panel.visible, "Portrait layout should hide the permanent deck/discard side panel"),
		assert_false(log_panel.visible, "Portrait layout should hide the permanent battle log panel"),
		assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Portrait layout should crop the center of the battle backdrop instead of squeezing it"),
		assert_eq(backdrop.size, Vector2(390, 844), "Portrait backdrop should cover the full logical portrait canvas"),
		assert_true(my_prize_hud != null and my_prize_hud.visible, "Portrait layout should keep self prize count visible in the left HUD"),
		assert_true(opp_prize_hud != null and opp_prize_hud.visible, "Portrait layout should keep opponent prize count visible in the left HUD"),
		assert_true(my_prize_value != null and my_prize_value.visible, "Portrait self prize HUD should show the remaining-prize count label"),
		assert_true(opp_prize_value != null and opp_prize_value.visible, "Portrait opponent prize HUD should show the remaining-prize count label"),
		assert_true(my_prize_title != null and not my_prize_title.visible, "Portrait self prize HUD should hide the redundant title text"),
		assert_true(opp_prize_title != null and not opp_prize_title.visible, "Portrait opponent prize HUD should hide the redundant title text"),
		assert_true(my_prize_hud != null and my_pile_hud != null and my_pile_hud.custom_minimum_size.x > my_prize_hud.custom_minimum_size.x, "Portrait self pile HUD should be wide enough for side-by-side card-backed deck/discard panels"),
		assert_true(opp_prize_hud != null and opp_pile_hud != null and opp_pile_hud.custom_minimum_size.x > opp_prize_hud.custom_minimum_size.x, "Portrait opponent pile HUD should be wide enough for side-by-side card-backed deck/discard panels"),
		assert_true(my_prize_host != null and not my_prize_host.visible, "Portrait layout should hide self prize cards until prize selection"),
		assert_true(opp_prize_host != null and not opp_prize_host.visible, "Portrait layout should hide opponent prize cards until prize selection"),
		assert_true(my_pile_stack != null and my_pile_stack.get_child_count() == 2, "Portrait layout should use a horizontal self deck/discard row"),
		assert_true(opp_pile_stack != null and opp_pile_stack.get_child_count() == 2, "Portrait layout should use a horizontal opponent deck/discard row"),
		assert_true(my_active_row != null and my_active_row.get_child_count() == 1, "Portrait self active row should keep HUD panels away from the active Pokemon"),
		assert_true(opp_active_row != null and opp_active_row.get_child_count() == 1, "Portrait opponent active row should keep HUD panels away from the active Pokemon"),
		assert_true(my_active_row != null and my_active_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Portrait active row should center the active Pokemon only"),
		assert_true(opp_active_row != null and opp_active_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Opponent portrait active row should center the active Pokemon only"),
		assert_true(opp_field_inner != null and opp_field_inner.alignment == BoxContainer.ALIGNMENT_END, "Portrait opponent field content should press toward the battle axis"),
		assert_true(my_field_inner != null and my_field_inner.alignment == BoxContainer.ALIGNMENT_BEGIN, "Portrait self field content should press toward the battle axis"),
		assert_true(edge_overlay != null and edge_overlay.visible, "Portrait layout should use a floating edge-HUD overlay"),
		assert_true(edge_overlay != null and edge_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Portrait edge-HUD overlay should not block card or bench clicks outside HUD panels"),
		assert_true(dialog_overlay != null and edge_overlay != null and dialog_overlay.z_index > edge_overlay.z_index, "Selection dialogs should render above floating portrait HUD rails"),
		assert_true(my_left_group != null and my_left_group.get_parent() == edge_overlay, "Portrait self prize/status group should live in the floating edge overlay"),
		assert_true(opp_left_group != null and opp_left_group.get_parent() == edge_overlay, "Portrait opponent prize/status group should live in the floating edge overlay"),
		assert_true(my_prize_hud != null and my_left_group != null and my_prize_hud.get_parent() == my_left_group, "Self prize HUD should be in the self left-edge group"),
		assert_true(opp_prize_hud != null and opp_left_group != null and opp_prize_hud.get_parent() == opp_left_group, "Opponent prize HUD should be in the opponent left-edge group"),
		assert_true(my_right_group != null and my_right_group.get_parent() == edge_overlay, "Portrait self deck/discard group should live in the floating edge overlay"),
		assert_true(opp_right_group != null and opp_right_group.get_parent() == edge_overlay, "Portrait opponent deck/discard group should live in the floating edge overlay"),
		assert_true(my_pile_hud != null and my_pile_hud.get_parent() == my_right_group, "Self deck/discard HUD should stay on the floating field edge, not beside the active Pokemon"),
		assert_true(opp_pile_hud != null and opp_pile_hud.get_parent() == opp_right_group, "Opponent deck/discard HUD should stay on the floating field edge, not beside the active Pokemon"),
		assert_true(my_left_group != null and my_left_group.position.x >= 0.0 and my_left_group.position.x + my_left_group.size.x <= 390.0, "Self left edge HUD should remain inside the portrait viewport"),
		assert_true(my_right_group != null and my_right_group.position.x >= 0.0 and my_right_group.position.x + my_right_group.size.x <= 390.0, "Self right edge HUD should remain inside the portrait viewport"),
		assert_true(opp_left_group != null and opp_left_group.position.x >= 0.0 and opp_left_group.position.x + opp_left_group.size.x <= 390.0, "Opponent left edge HUD should remain inside the portrait viewport"),
		assert_true(opp_right_group != null and opp_right_group.position.x >= 0.0 and opp_right_group.position.x + opp_right_group.size.x <= 390.0, "Opponent right edge HUD should remain inside the portrait viewport"),
		assert_true(main_area != null and main_area.position.x > 0.0 and main_area.size.x < 390.0, "Portrait main area should reserve horizontal safe insets so hand content cannot spill off screen"),
		assert_true(top_bar != null and top_bar.position.x > 0.0 and top_bar.size.x < 390.0, "Portrait top bar should reserve horizontal safe insets so action buttons stay fully visible"),
		assert_true(hand_area != null and hand_area.clip_contents, "Portrait hand area should clip overflowing hand cards inside the safe canvas"),
		assert_true(hand_scroll != null and hand_scroll.clip_contents, "Portrait hand scroll should clip cards instead of letting them bleed outside the viewport"),
		assert_false(my_field_shell != null and my_prize_hud != null and my_field_shell.is_ancestor_of(my_prize_hud), "Portrait self prize HUD must not consume FieldShell layout width"),
		assert_false(my_field_shell != null and my_pile_hud != null and my_field_shell.is_ancestor_of(my_pile_hud), "Portrait self pile HUD must not consume FieldShell layout width"),
		assert_false(opp_field_shell != null and opp_prize_hud != null and opp_field_shell.is_ancestor_of(opp_prize_hud), "Portrait opponent prize HUD must not consume FieldShell layout width"),
		assert_false(opp_field_shell != null and opp_pile_hud != null and opp_field_shell.is_ancestor_of(opp_pile_hud), "Portrait opponent pile HUD must not consume FieldShell layout width"),
		assert_true(my_status_stack != null and not my_status_stack.visible, "Portrait self VSTAR stack placeholder should not reserve left-side width"),
		assert_true(opp_status_stack != null and not opp_status_stack.visible, "Portrait opponent VSTAR stack placeholder should not reserve left-side width"),
		assert_true(my_vstar_panel != null and my_left_group != null and my_vstar_panel.get_parent() == my_left_group, "Self VSTAR panel should sit next to the self prize HUD on the left rail"),
		assert_true(opp_vstar_panel != null and opp_left_group != null and opp_vstar_panel.get_parent() == opp_left_group, "Opponent VSTAR panel should sit next to the opponent prize HUD on the left rail"),
		assert_true(my_lost_panel != null and my_pile_vbox != null and my_lost_panel.get_parent() == my_pile_vbox, "Self lost-zone HUD should live under the self deck/discard HUD"),
		assert_true(opp_lost_panel != null and opp_pile_vbox != null and opp_lost_panel.get_parent() == opp_pile_vbox, "Opponent lost-zone HUD should live under the opponent deck/discard HUD"),
		assert_true(my_lost_panel != null and my_pile_stack != null and my_lost_panel.get_index() == my_pile_stack.get_index() + 1, "Self lost-zone HUD should sit directly below the deck/discard row"),
		assert_true(opp_lost_panel != null and opp_pile_stack != null and opp_lost_panel.get_index() == opp_pile_stack.get_index() + 1, "Opponent lost-zone HUD should sit directly below the deck/discard row"),
		assert_true(my_vstar_panel != null and my_prize_hud != null and my_vstar_panel.get_index() > my_prize_hud.get_index(), "Self VSTAR panel should be directly after the self prize HUD"),
		assert_true(opp_vstar_panel != null and opp_prize_hud != null and opp_vstar_panel.get_index() > opp_prize_hud.get_index(), "Opponent VSTAR panel should be directly after the opponent prize HUD"),
		assert_true(my_vstar_image != null and my_vstar_image.visible and my_vstar_image.texture != null, "Self VSTAR HUD should render the VSTAR PNG instead of text"),
		assert_true(opp_vstar_image != null and opp_vstar_image.visible and opp_vstar_image.texture != null, "Opponent VSTAR HUD should render the VSTAR PNG instead of text"),
		assert_true(my_deck_panel != null and my_deck_panel.custom_minimum_size.y >= 78.0, "Portrait deck HUD should reserve room for a card-backed preview panel"),
		assert_true(my_deck_preview != null and my_deck_preview.visible, "Portrait self deck HUD should show its card-backed preview"),
		assert_true(my_discard_preview != null and my_discard_preview.visible, "Portrait self discard HUD should show its card preview slot"),
		assert_true(opp_deck_preview != null and opp_deck_preview.visible, "Portrait opponent deck HUD should show its card-backed preview"),
		assert_true(opp_discard_preview != null and opp_discard_preview.visible, "Portrait opponent discard HUD should show its card preview slot"),
		assert_true(first_bench_slot != null and my_deck_preview != null and absf(my_deck_preview.custom_minimum_size.y - first_bench_slot.custom_minimum_size.y * 0.5) <= 2.0, "Portrait pile preview height should be half of the bench card slot height"),
		assert_true(first_bench_slot != null and my_deck_preview != null and absf(my_deck_preview.custom_minimum_size.x - first_bench_slot.custom_minimum_size.x * 0.5) <= 2.0, "Portrait pile preview width should be half of the bench card slot width"),
		assert_true(my_deck_caption != null and my_deck_caption.get_theme_font_size("font_size") >= 16, "Portrait pile captions should stay readable without overpowering cards"),
		assert_true(my_deck_value != null and my_deck_value.get_theme_font_size("font_size") >= 16, "Portrait pile values should stay readable without overpowering cards"),
		assert_eq(my_deck_caption.get_theme_font_size("font_size") if my_deck_caption != null else -1, my_deck_value.get_theme_font_size("font_size") if my_deck_value != null else -2, "Portrait pile captions should use the same size as pile count values"),
		assert_eq(my_prize_title.get_theme_font_size("font_size") if my_prize_title != null else -1, my_deck_value.get_theme_font_size("font_size") if my_deck_value != null else -2, "Portrait prize title should match pile count text size"),
		assert_eq(my_prize_value.get_theme_font_size("font_size") if my_prize_value != null else -1, my_deck_value.get_theme_font_size("font_size") if my_deck_value != null else -2, "Portrait prize count should match pile count text size"),
		assert_true(my_vstar_caption != null and not my_vstar_caption.visible, "Portrait VSTAR caption should be hidden because the PNG carries the label"),
		assert_true(my_vstar_value != null and not my_vstar_value.visible, "Portrait VSTAR value should be hidden because the PNG carries the label"),
		assert_true(stadium_sections != null and stadium_sections.alignment == BoxContainer.ALIGNMENT_BEGIN, "Portrait stadium HUD row should use edge-to-edge spacing"),
		assert_true(vstar_section != null and not vstar_section.visible, "Portrait central status section should be hidden after player status moves beside prizes"),
		assert_true(turn_action_column != null and stadium_sections != null and turn_action_column.get_parent() == stadium_sections, "Portrait end-turn action should move out of the hidden VSTAR section"),
		assert_true(stadium_center != null and turn_action_column != null and stadium_center.custom_minimum_size.x + turn_action_column.custom_minimum_size.x + 8.0 <= 390.0, "Portrait stadium and end-turn HUDs should fit within the phone viewport"),
		assert_true(layout_button != null and not layout_button.visible, "Portrait top bar should hide the layout switch"),
		assert_true(more_button != null and not more_button.visible, "Portrait top bar should not expose the removed more button"),
		assert_true(back_button != null and back_button.visible, "Portrait top bar should keep exit visible"),
		assert_true(discuss_button != null and discuss_button.visible, "Portrait top bar should expose AI discussion directly"),
		assert_true(zeus_button != null and zeus_button.visible, "Portrait top bar should expose Zeus help directly"),
		assert_true(hand_scroll != null and hand_scroll.custom_minimum_size.y >= 150.0, "Portrait hand area should remain touch-sized"),
		assert_true(hand_scroll != null and hand_scroll.custom_minimum_size.y <= compact_hand_scroll_limit, "Portrait hand area should stay compact while reserving the enlarged touch scrollbar"),
		assert_true(my_bench != null and not my_bench.visible, "Portrait layout should replace the horizontal bench with a grid"),
		assert_true(portrait_grid != null and portrait_grid.visible, "Portrait bench should use a visible one-row stack"),
		assert_eq(visible_bench_slots, 5, "Portrait bench should keep five visible slots in the default one-row layout"),
		assert_true(portrait_grid != null and portrait_grid.mouse_filter == Control.MOUSE_FILTER_PASS, "Portrait bench grid should pass fallback taps for playing Basic Pokemon"),
		assert_true(first_bench_slot != null and first_bench_slot.custom_minimum_size.y >= 80.0, "Portrait bench slots should be large enough to read"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_hand_info_label_does_not_feedback_expand_hand_height() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := PortraitHandInfoSceneStub.new()
	scene.size = Vector2(390, 844)
	scene._play_card_size = Vector2(150, 210)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.custom_minimum_size = Vector2(360, 220)
	hand_scroll.size = Vector2(360, 640)
	scene._hand_scroll = hand_scroll
	var hand_container := HBoxContainer.new()
	hand_container.custom_minimum_size = Vector2(0, 210)
	hand_container.size = Vector2(360, 640)

	var first_label := Label.new()
	first_label.text = "AI action summary that may be long enough to wrap on a narrow phone screen"
	controller.call("_apply_portrait_hand_info_label_metrics", scene, hand_container, first_label)
	var first_size := first_label.custom_minimum_size

	hand_scroll.size = Vector2(360, 900)
	hand_container.size = Vector2(360, 900)
	var second_label := Label.new()
	second_label.text = "A different AI action summary should not use the already-expanded runtime height as its next baseline"
	controller.call("_apply_portrait_hand_info_label_metrics", scene, hand_container, second_label)

	var result := run_checks([
		assert_eq(first_size.y, 220.0, "Portrait hand info text should use the configured hand rail height, not the current expanded runtime height"),
		assert_eq(second_label.custom_minimum_size.y, first_size.y, "Repeated AI action text refreshes must not feed back into a taller hand rail"),
		assert_true(second_label.clip_text, "AI action text in the hand rail should clip instead of forcing layout growth"),
		assert_eq(second_label.max_lines_visible, 2, "Portrait AI action text should be capped to a small number of visible lines"),
	])

	scene.queue_free()
	return result


func test_landscape_hand_card_row_restores_center_alignment_after_ai_text() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := PortraitHandInfoSceneStub.new()
	scene.portrait_active = false
	scene._play_card_size = Vector2(130, 182)
	var hand_container := HBoxContainer.new()
	hand_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	hand_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hand_container.custom_minimum_size = Vector2(480, 360)

	controller.call("_restore_portrait_hand_card_row_metrics", scene, hand_container)

	var result := run_checks([
		assert_eq(hand_container.alignment, BoxContainer.ALIGNMENT_CENTER, "Landscape hand cards should restore centered row alignment after AI text is cleared"),
		assert_eq(hand_container.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Landscape hand card row should fill the hand rail so centering can work"),
		assert_eq(hand_container.custom_minimum_size.x, 0.0, "Landscape hand card row should not keep the previous AI text width"),
		assert_eq(hand_container.custom_minimum_size.y, 182.0, "Landscape hand card row should keep the current card height"),
	])

	scene.queue_free()
	return result


func test_llm_wait_hud_label_does_not_join_hand_layout_container() -> String:
	var scene: Control = BattleScene.instantiate()
	var hand_title := scene.find_child("HandTitle", true, false) as Label
	scene.set("_hand_title", hand_title)
	scene.call("_ensure_llm_wait_label")

	var wait_label := scene.get("_ai_llm_wait_label") as Label
	var hand_vbox := scene.find_child("HandVBox", true, false) as VBoxContainer
	var result := run_checks([
		assert_true(wait_label != null and wait_label.get_parent() == scene, "LLM wait HUD should be an overlay child of the battle scene"),
		assert_true(wait_label != null and wait_label.get_parent() != hand_vbox, "LLM wait HUD must not become a HandVBox row that changes hand-area height"),
		assert_true(wait_label != null and wait_label.clip_text, "LLM wait HUD should clip long model text inside its overlay bounds"),
	])

	scene.queue_free()
	return result


func test_portrait_llm_wait_hud_anchors_to_hand_hud_top_center() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_ensure_llm_wait_label")
	var turn_label := scene.find_child("LblTurn", true, false) as Label
	if turn_label != null:
		turn_label.visible = true
	scene.call("_update_llm_wait_hud", 3)

	var wait_label := scene.get("_ai_llm_wait_label") as Label
	var top_bar := scene.find_child("TopBar", true, false) as Control
	var hand_area := scene.find_child("HandArea", true, false) as Control
	var wait_rect := Rect2(wait_label.position, wait_label.size) if wait_label != null else Rect2()
	var top_rect := _battle_local_rect(scene, top_bar)
	var hand_rect := _battle_local_rect(scene, hand_area)
	var wait_center_x := wait_rect.position.x + wait_rect.size.x * 0.5
	var hand_center_x := hand_rect.position.x + hand_rect.size.x * 0.5
	var wait_font_size := wait_label.get_theme_font_size("font_size") if wait_label != null else 0
	var turn_visible_during_wait := turn_label.visible if turn_label != null else true
	scene.call("_stop_llm_wait_hud")
	var turn_visible_after_wait := turn_label.visible if turn_label != null else false
	var result := run_checks([
		assert_true(wait_label != null and not wait_label.visible, "Portrait LLM wait HUD should hide after the wait stops"),
		assert_false(_rects_overlap(wait_rect, top_rect), "Portrait LLM wait HUD should not stay in the screen-top HUD band"),
		assert_true(_rects_overlap(wait_rect, hand_rect), "Portrait LLM wait HUD should anchor inside the hand HUD instead of floating at the top of the screen"),
		assert_true(absf(wait_center_x - hand_center_x) <= 2.0, "Portrait LLM wait HUD should be horizontally centered on the hand HUD"),
		assert_true(wait_rect.position.y >= hand_rect.position.y - 1.0 and wait_rect.position.y <= hand_rect.position.y + 18.0, "Portrait LLM wait HUD should sit on the upper edge of the hand HUD"),
		assert_true(wait_font_size >= 56, "Portrait LLM wait HUD font should be at least four times the old 14px mobile size"),
		assert_true(wait_rect.size.y >= float(wait_font_size) + 14.0, "Portrait LLM wait HUD should reserve enough height for the enlarged thinking text"),
		assert_eq(wait_label.max_lines_visible if wait_label != null else 0, 1, "Portrait LLM wait HUD should remain a single-line overlay label"),
		assert_false(turn_visible_during_wait, "LLM wait HUD should hide the normal top turn text while active"),
		assert_true(turn_visible_after_wait, "LLM wait HUD should restore the normal top turn text when it stops"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_llm_wait_hud_uses_top_center_hud_slot() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_landscape_layout", Vector2(1600, 900))
	scene.call("_ensure_llm_wait_label")
	var turn_label := scene.find_child("LblTurn", true, false) as Label
	if turn_label != null:
		turn_label.visible = true
	scene.call("_update_llm_wait_hud", 4)

	var wait_label := scene.get("_ai_llm_wait_label") as Label
	var hand_area := scene.find_child("HandArea", true, false) as Control
	var wait_rect := Rect2(wait_label.position, wait_label.size) if wait_label != null else Rect2()
	var hand_rect := _battle_local_rect(scene, hand_area)
	var wait_center_x := wait_rect.position.x + wait_rect.size.x * 0.5
	var scene_center_x := scene.size.x * 0.5
	var turn_visible_during_wait := turn_label.visible if turn_label != null else true
	scene.call("_stop_llm_wait_hud")
	var turn_visible_after_wait := turn_label.visible if turn_label != null else false
	var result := run_checks([
		assert_true(wait_label != null and not wait_label.visible, "Landscape LLM wait HUD should hide after the wait stops"),
		assert_true(wait_rect.position.y <= 8.0 and wait_rect.size.y <= 48.0, "Landscape LLM wait HUD should occupy the top HUD band"),
		assert_true(absf(wait_center_x - scene_center_x) <= 2.0, "Landscape LLM wait HUD should stay centered in the HUD"),
		assert_false(_rects_overlap(wait_rect, hand_rect), "Landscape LLM wait HUD should not occupy the hand area"),
		assert_eq(wait_label.max_lines_visible if wait_label != null else 0, 1, "Landscape LLM wait HUD should stay single-line"),
		assert_false(turn_visible_during_wait, "LLM wait HUD should hide the landscape top-center turn text while active"),
		assert_true(turn_visible_after_wait, "LLM wait HUD should restore the landscape top-center turn text when it stops"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_top_bar_uses_double_height_touch_profile() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var top_bar := scene.find_child("TopBar", true, false) as Control
	var main_area := scene.find_child("MainArea", true, false) as Control
	var more_button := scene.find_child("BtnBattleMore", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false) as Button
	var zeus_button := scene.find_child("BtnZeusHelp", true, false) as Button
	var phase_label := scene.find_child("LblPhase", true, false) as Label
	var turn_label := scene.find_child("LblTurn", true, false) as Label
	var top_bar_height := top_bar.offset_bottom - top_bar.offset_top if top_bar != null else 0.0
	var back_width := back_button.custom_minimum_size.x if back_button != null else -1.0
	var discuss_width := discuss_button.custom_minimum_size.x if discuss_button != null else -2.0
	var zeus_width := zeus_button.custom_minimum_size.x if zeus_button != null else -3.0
	var top_bar_right := scene.find_child("TopBarRight", true, false) as Control

	var result := run_checks([
		assert_true(top_bar_height >= 104.0, "Portrait top status bar should be twice the old 52px compact height"),
		assert_true(main_area != null and top_bar != null and main_area.offset_top >= top_bar.offset_bottom + 4.0, "Portrait battlefield should start below the taller top bar"),
		assert_true(more_button != null and not more_button.visible, "Portrait more button should be removed from the top bar"),
		assert_true(back_button != null and back_button.custom_minimum_size.y >= 104.0, "Portrait exit button should share the doubled top touch height"),
		assert_true(discuss_button != null and discuss_button.visible, "Portrait AI discussion button should be visible directly"),
		assert_true(zeus_button != null and zeus_button.visible, "Portrait Zeus button should be visible directly"),
		assert_true(absf(discuss_width - back_width) < 0.1 and absf(zeus_width - back_width) < 0.1, "Portrait direct top action buttons should keep the same width"),
		assert_true(back_width >= 84.0, "Portrait direct top action buttons should use a wider touch target"),
		assert_true(back_button != null and back_button.get_theme_font_size("font_size") >= 24, "Portrait exit button text should be doubled"),
		assert_true(discuss_button != null and discuss_button.get_theme_font_size("font_size") >= 24, "Portrait AI discussion button text should be doubled"),
		assert_true(zeus_button != null and zeus_button.get_theme_font_size("font_size") >= 24, "Portrait Zeus button text should be doubled"),
		assert_true(phase_label != null and phase_label.get_theme_font_size("font_size") >= 24, "Portrait phase text should be doubled"),
		assert_true(turn_label != null and turn_label.get_theme_font_size("font_size") >= 24, "Portrait turn text should be doubled"),
		assert_true(phase_label != null and phase_label.clip_text, "Portrait phase text should clip instead of spilling into action buttons"),
		assert_true(turn_label != null and turn_label.clip_text, "Portrait turn text should clip instead of spilling into action buttons"),
		assert_true(top_bar_right != null and top_bar_right.size_flags_horizontal == Control.SIZE_SHRINK_END, "Portrait direct top actions should only reserve their actual button width"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_top_status_uses_visible_two_line_text_column() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.turn_number = 3
	game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		game_state.players.append(player)
	for card_index: int in 5:
		game_state.players[1].hand.append(CardInstance.create(_make_basic_pokemon_card("Opponent Hand %d" % card_index), 1))
	gsm.game_state = game_state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_refresh_ui")

	var top_bar_left := scene.find_child("TopBarLeft", true, false) as Control
	var top_bar_center := scene.find_child("TopBarCenter", true, false) as Control
	var phase_label := scene.find_child("LblPhase", true, false) as Label
	var turn_label := scene.find_child("LblTurn", true, false) as Label
	var result := run_checks([
		assert_true(top_bar_left != null and top_bar_left.visible, "Portrait top status column should stay visible"),
		assert_true(top_bar_left is MarginContainer, "Portrait top status column should fill the label instead of centering it at a 1px clipped minimum"),
		assert_true(top_bar_center != null and not top_bar_center.visible, "Portrait should collapse the separate turn column to give status text enough width"),
		assert_true(turn_label != null and not turn_label.visible, "Portrait turn label should not consume a second narrow text slot"),
		assert_true(phase_label != null and phase_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Portrait status label should fill the visible status column"),
		assert_true(phase_label != null and phase_label.text.find("\n") >= 0, "Portrait status should use two lines inside the left status column"),
		assert_str_contains(phase_label.text if phase_label != null else "", "T3 我方", "Portrait status should include the active turn line"),
		assert_str_contains(phase_label.text if phase_label != null else "", "对手 5张", "Portrait status should include opponent hand count"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_top_bar_uses_direct_core_actions_without_log_drawer() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var more_button := scene.find_child("BtnBattleMore", true, false) as Button
	var hand_button := scene.find_child("BtnOpponentHand", true, false) as Button
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false) as Button
	var zeus_button := scene.find_child("BtnZeusHelp", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var descriptors: Array = scene.call("_portrait_action_descriptors")
	var descriptor_text := ""
	for descriptor_variant: Variant in descriptors:
		var descriptor: Dictionary = descriptor_variant if descriptor_variant is Dictionary else {}
		descriptor_text += "%s\n" % str(descriptor.get("text", ""))

	var result := run_checks([
		assert_true(more_button != null and not more_button.visible, "Portrait top bar should remove the more drawer button"),
		assert_true(discuss_button != null and discuss_button.visible, "Portrait top bar should expose AI discussion directly"),
		assert_true(zeus_button != null and zeus_button.visible, "Portrait top bar should expose Zeus help directly"),
		assert_true(back_button != null and back_button.visible, "Portrait top bar should keep exit directly visible"),
		assert_true(hand_button == null or not hand_button.visible or hand_button.text == "对手", "Portrait opponent hand action should use compact direct text when visible"),
		assert_eq(discuss_button.text if discuss_button != null else "", "AI", "Portrait AI discussion should use compact direct text"),
		assert_eq(zeus_button.text if zeus_button != null else "", "宙斯", "Portrait Zeus help should use compact direct text"),
		assert_false(descriptor_text.contains("查看日志"), "Portrait actions should no longer expose a battle log entry"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_battle_discussion_popup_uses_safe_touch_metrics() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var dialog := DeckDiscussionDialogScene.instantiate() as AcceptDialog
	scene.add_child(dialog)
	scene.set("_battle_discussion_dialog", dialog)
	scene.call("_popup_battle_discussion_dialog_for_current_layout")

	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var popup_size := Vector2(float(dialog.size.x), float(dialog.size.y))
	var title_label := dialog.get_node_or_null("%TitleLabel") as Label
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var stacked_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/Actions") as HBoxContainer
	var composer_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/ComposerRow/Actions") as HBoxContainer
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as Control
	var input_panel := dialog.get_node_or_null("%InputPanel") as Control
	var roots: Array[Node] = scene.call("_portrait_popup_text_roots")
	var result := run_checks([
		assert_true(popup_size.x <= frame_rect.size.x, "Portrait AI discussion dialog should stay inside the safe portrait frame"),
		assert_true(popup_size.y <= frame_rect.size.y, "Portrait AI discussion dialog should stay inside the safe portrait frame height"),
		assert_true(popup_size.y >= frame_rect.size.y * 0.66, "Portrait AI discussion dialog should visibly apply the taller portrait profile"),
		assert_true(popup_size.y <= frame_rect.size.y * 0.70, "Portrait AI discussion dialog should stay below a full-height mobile sheet after the increase"),
		assert_true(dialog.min_size.x <= dialog.size.x and dialog.min_size.y <= dialog.size.y, "Portrait AI discussion min size should not force desktop dimensions"),
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 34, "Portrait AI discussion title should use mobile battle-scale text"),
		assert_true(question_input != null and question_input.get_theme_font_size("font_size") >= 30, "Portrait AI discussion input should use mobile battle-scale text"),
		assert_true(send_button != null and send_button.custom_minimum_size.x >= 80.0 and send_button.custom_minimum_size.x <= 96.0, "Portrait AI discussion send button should use a readable right-side touch width"),
		assert_true(send_button != null and send_button.custom_minimum_size.y >= 150.0, "Portrait AI discussion send button should match the input box height on the right side"),
		assert_true(send_button != null and send_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Portrait AI discussion send button should fill its right-side action cell"),
		assert_null(stacked_actions, "Portrait AI discussion should not stack action buttons below the input field"),
		assert_not_null(composer_actions, "Portrait AI discussion should keep action buttons beside the text input"),
		assert_true(transcript_scroll != null and input_panel != null and transcript_scroll.offset_bottom <= input_panel.offset_top - 8.0, "Portrait AI discussion transcript should not overlap the input panel"),
		assert_false(dialog in roots, "BattleScene should let DeckDiscussionDialog own its portrait text metrics"),
	])

	dialog.queue_free()
	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_battle_discussion_popup_scales_on_android_canvas() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(1600, 2844))
	var dialog := DeckDiscussionDialogScene.instantiate() as AcceptDialog
	scene.add_child(dialog)
	scene.set("_battle_discussion_dialog", dialog)
	scene.call("_popup_battle_discussion_dialog_for_current_layout")

	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var title_label := dialog.get_node_or_null("%TitleLabel") as Label
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var stacked_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/Actions") as HBoxContainer
	var composer_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/ComposerRow/Actions") as HBoxContainer
	var result := run_checks([
		assert_true(dialog.size.x <= frame_rect.size.x, "Android portrait AI discussion dialog should stay inside the safe frame width"),
		assert_true(dialog.size.y <= frame_rect.size.y, "Android portrait AI discussion dialog should stay inside the safe frame height"),
		assert_true(dialog.size.y >= int(round(frame_rect.size.y * 0.66)), "Android portrait AI discussion dialog should apply the taller portrait profile"),
		assert_true(dialog.size.y <= int(round(frame_rect.size.y * 0.70)), "Android portrait AI discussion dialog should remain a centered dialog after the height increase"),
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 60, "Android portrait AI discussion title should scale with top battle buttons"),
		assert_true(question_input != null and question_input.get_theme_font_size("font_size") >= 53, "Android portrait AI discussion input should scale with top battle buttons"),
		assert_true(send_button != null and send_button.custom_minimum_size.y >= 270.0, "Android portrait AI discussion send button should match the scaled input height"),
		assert_null(stacked_actions, "Android portrait AI discussion should not stack action buttons below the text input"),
		assert_not_null(composer_actions, "Android portrait AI discussion should keep action buttons beside the text input"),
	])

	dialog.queue_free()
	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_card_selection_dialog_uses_near_screen_width() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var card := CardInstance.create(_make_basic_pokemon_card("Choice Pokemon"), 0)
	scene.call("_show_dialog", "Choose a Pokemon", [card], {"presentation": "cards", "allow_cancel": true})
	var dialog_box := scene.find_child("DialogBox", true, false) as Control
	var dialog_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	var expected_width := float(scene.call("_portrait_popup_near_width"))
	var result := run_checks([
		assert_true(dialog_box != null and absf(dialog_box.custom_minimum_size.x - expected_width) < 0.1, "Portrait card selection dialog should use the near-screen popup width"),
		assert_true(dialog_scroll != null and dialog_scroll.visible, "Card-selection dialog should keep the card gallery visible"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_portrait_modal_overlays_keep_visible_frame_after_relayout() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	var field_overlay := _attach_test_modal_overlay(scene, "FieldInteractionOverlay", "FieldInteractionLayout")
	var draw_overlay := _attach_test_modal_overlay(scene, "DrawRevealOverlay", "DrawRevealStage")
	var match_end_overlay := _attach_test_modal_overlay(scene, "MatchEndOverlay", "MatchEndCenter")

	scene.call("_apply_portrait_layout", Vector2(1600, 2844))
	var large_frame: Rect2 = scene.get("_portrait_layout_frame_rect")
	var field_child := field_overlay.get_child(0) as Control
	var draw_child := draw_overlay.get_child(0) as Control
	var match_end_child := match_end_overlay.get_child(0) as Control
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var small_frame: Rect2 = scene.get("_portrait_layout_frame_rect")
	var checks: Array[String] = []
	for overlay_name: String in [
		"DialogOverlay",
		"HandoverPanel",
		"CoinFlipOverlay",
		"DetailOverlay",
		"DiscardOverlay",
		"ReviewOverlay",
	]:
		var overlay := scene.find_child(overlay_name, true, false) as Control
		checks.append(assert_eq(overlay.size if overlay != null else Vector2.ZERO, small_frame.size, "%s should keep a visible portrait frame after relayout" % overlay_name))
	checks.append(assert_eq(field_overlay.size, small_frame.size, "Field interaction overlay should follow the active portrait frame"))
	checks.append(assert_eq(draw_overlay.size, small_frame.size, "Draw reveal overlay should follow the active portrait frame"))
	checks.append(assert_eq(match_end_overlay.size, small_frame.size, "Match end overlay should follow the active portrait frame"))
	checks.append(assert_eq(field_child.size if field_child != null else Vector2.ZERO, small_frame.size, "Dynamic full-rect field child should keep following after anchors are converted to explicit rects"))
	checks.append(assert_eq(draw_child.size if draw_child != null else Vector2.ZERO, small_frame.size, "Dynamic full-rect draw child should keep following after anchors are converted to explicit rects"))
	checks.append(assert_eq(match_end_child.size if match_end_child != null else Vector2.ZERO, small_frame.size, "Match end center should keep following the active portrait frame"))
	checks.append(assert_true(large_frame.size.x > small_frame.size.x and large_frame.size.y > small_frame.size.y, "Regression setup should exercise a real Android-to-phone portrait relayout"))
	var result := run_checks(checks)

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_portrait_dynamic_modal_overlays_created_after_layout_get_visible_frame() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(1600, 2844))
	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var field_overlay := _attach_test_modal_overlay(scene, "FieldInteractionOverlay", "FieldInteractionLayout")
	var draw_overlay := _attach_test_modal_overlay(scene, "DrawRevealOverlay", "DrawRevealStage")
	var match_end_overlay := _attach_test_modal_overlay(scene, "MatchEndOverlay", "MatchEndCenter")
	scene.set("_field_interaction_overlay", field_overlay)
	scene.set("_draw_reveal_overlay", draw_overlay)
	scene.set("_match_end_overlay", match_end_overlay)
	scene.call("_apply_portrait_popup_text_metrics")
	var field_child := field_overlay.get_child(0) as Control
	var draw_child := draw_overlay.get_child(0) as Control
	var match_end_child := match_end_overlay.get_child(0) as Control
	var result := run_checks([
		assert_eq(field_overlay.size, frame_rect.size, "Field interaction overlay created after portrait layout should immediately receive the visible frame"),
		assert_eq(draw_overlay.size, frame_rect.size, "Draw reveal overlay created after portrait layout should immediately receive the visible frame"),
		assert_eq(match_end_overlay.size, frame_rect.size, "Match end overlay created after portrait layout should immediately receive the visible frame"),
		assert_eq(field_child.size if field_child != null else Vector2.ZERO, frame_rect.size, "Late field overlay child should fill the synced frame"),
		assert_eq(draw_child.size if draw_child != null else Vector2.ZERO, frame_rect.size, "Late draw overlay child should fill the synced frame"),
		assert_eq(match_end_child.size if match_end_child != null else Vector2.ZERO, frame_rect.size, "Late match end center should fill the synced frame"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_portrait_invalid_action_hint_created_after_layout_gets_visible_frame() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(1600, 2844))
	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	scene.call("_show_invalid_action_hint", {
		"title": "Cannot use now",
		"reason": "This action is blocked.",
	})

	var overlay := scene.find_child("InvalidActionOverlay", true, false) as Control
	var center := scene.find_child("InvalidActionCenter", true, false) as Control
	var box := scene.find_child("InvalidActionBox", true, false) as PanelContainer
	var result := run_checks([
		assert_true(overlay != null and overlay.visible, "Invalid action hint should create a visible overlay after portrait layout"),
		assert_eq(overlay.size if overlay != null else Vector2.ZERO, frame_rect.size, "Invalid action overlay should receive the active Android portrait frame"),
		assert_eq(center.size if center != null else Vector2.ZERO, frame_rect.size, "Invalid action center should fill the synced overlay frame"),
		assert_true(box != null and box.custom_minimum_size.x <= frame_rect.size.x, "Invalid action hint box should stay inside the portrait frame"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_portrait_invalid_action_hint_close_button_stays_above_hand_area() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_show_invalid_action_hint", {
		"title": "Cannot use now",
		"reason": "This action is blocked by the current battle state. ".repeat(8),
		"detail": "Check the active Pokemon, attached cards, and turn restrictions before choosing another action. ".repeat(8),
		"hint": "Tap the confirmation button to return to the battle.",
	})

	var hand_area := scene.find_child("HandArea", true, false) as Control
	var box := scene.find_child("InvalidActionBox", true, false) as PanelContainer
	var title := scene.find_child("InvalidActionTitle", true, false) as Label
	var reason := scene.find_child("InvalidActionReason", true, false) as Label
	var detail := scene.find_child("InvalidActionDetail", true, false) as Label
	var close_button := scene.find_child("InvalidActionCloseButton", true, false) as Button
	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var hand_height := maxf(hand_area.size.y, hand_area.custom_minimum_size.y) if hand_area != null else 0.0
	var hand_top := frame_rect.position.y + frame_rect.size.y - hand_height
	var box_bottom := box.position.y + box.size.y if box != null else 99999.0
	var title_height := maxf(title.size.y, title.get_combined_minimum_size().y) if title != null else 0.0
	var reason_height := maxf(reason.size.y, reason.get_combined_minimum_size().y) if reason != null else 0.0
	var detail_height := maxf(detail.size.y, detail.get_combined_minimum_size().y) if detail != null else 0.0
	var result := run_checks([
		assert_true(hand_top > 0.0, "Portrait battle scene should expose the hand area top for invalid action clamping"),
		assert_true(box != null and box.size.y > 0.0, "Portrait invalid hint should resolve an explicit box rect in the real battle scene"),
		assert_true(title != null and title.visible and title.text.strip_edges() != "" and title_height > 0.0, "Portrait invalid hint title should remain visible after clamping: size %s, min %s" % [str(title.size if title != null else Vector2.ZERO), str(title.get_combined_minimum_size() if title != null else Vector2.ZERO)]),
		assert_true(reason != null and reason.visible and reason.text.strip_edges() != "" and reason_height > 0.0, "Portrait invalid hint reason should remain visible after clamping: size %s, min %s" % [str(reason.size if reason != null else Vector2.ZERO), str(reason.get_combined_minimum_size() if reason != null else Vector2.ZERO)]),
		assert_true(detail != null and detail.visible and detail.text.strip_edges() != "" and detail_height > 0.0, "Portrait invalid hint detail should remain visible after clamping: size %s, min %s" % [str(detail.size if detail != null else Vector2.ZERO), str(detail.get_combined_minimum_size() if detail != null else Vector2.ZERO)]),
		assert_true(close_button != null and close_button.custom_minimum_size.y > 0.0, "Portrait invalid hint close button should keep a visible touch target"),
		assert_true(box_bottom <= hand_top - 8.0, "Portrait invalid hint close button must stay above the hand area in the real battle scene: box bottom %.1f, hand top %.1f" % [box_bottom, hand_top]),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_invalid_action_hint_stays_compact_and_ignores_portrait_clamp() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	var scene: Control = BattleScene.instantiate()
	var viewport_size := Vector2(1600, 900)
	scene.call("_apply_landscape_layout", viewport_size)
	scene.call("_show_invalid_action_hint", {
		"title": "Cannot use now",
		"reason": "This action is blocked by the current battle state. ".repeat(8),
		"detail": "Check the active Pokemon, attached cards, and turn restrictions before choosing another action. ".repeat(8),
		"hint": "Tap the confirmation button to return to the battle.",
	})
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
		await tree.process_frame

	var box := scene.find_child("InvalidActionBox", true, false) as PanelContainer
	var title := scene.find_child("InvalidActionTitle", true, false) as Label
	var reason := scene.find_child("InvalidActionReason", true, false) as Label
	var detail := scene.find_child("InvalidActionDetail", true, false) as Label
	var hint := scene.find_child("InvalidActionHint", true, false) as Label
	var close_button := scene.find_child("InvalidActionCloseButton", true, false) as Button
	var box_height := box.size.y if box != null and box.size.y > 0.0 else (box.custom_minimum_size.y if box != null else 99999.0)
	var box_rect := Rect2(box.global_position, box.size) if box != null else Rect2(Vector2.ZERO, Vector2(99999, 99999))
	var result := run_checks([
		assert_true(box != null and box_height <= viewport_size.y * 0.34, "Landscape invalid hint should stay compact instead of inheriting portrait clamp metrics: height %.1f" % box_height),
		assert_true(box != null and box_rect.position.y >= 24.0 and box_rect.end.y <= viewport_size.y - 24.0, "Landscape invalid hint should remain inside the screen after container sorting: %s" % str(box_rect)),
		assert_true(title != null and title.clip_text and title.max_lines_visible == 1 and title.custom_minimum_size.y > 0.0, "Landscape title should use compact fixed-line sizing, not portrait touch sizing"),
		assert_true(reason != null and reason.clip_text and reason.max_lines_visible == 1 and reason.custom_minimum_size.y > 0.0, "Landscape reason should use compact fixed-line sizing, not portrait touch sizing"),
		assert_true(detail != null and detail.clip_text and detail.max_lines_visible == 1 and detail.custom_minimum_size.y > 0.0, "Landscape detail should use compact fixed-line sizing, not portrait touch sizing"),
		assert_true(hint != null and hint.clip_text and hint.max_lines_visible == 1 and hint.custom_minimum_size.y > 0.0, "Landscape hint should use compact fixed-line sizing, not portrait touch sizing"),
		assert_true(close_button != null and close_button.custom_minimum_size == Vector2(220, 58), "Landscape close button should keep the original compact size"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_portrait_full_library_effect_search_dialog_has_visible_frame() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_portrait_layout", Vector2(1600, 2844))

	var visible_cards: Array[CardInstance] = []
	var visible_labels: Array[String] = []
	for i: int in 12:
		var card_name := "Deck Pokemon %02d" % i
		visible_cards.append(CardInstance.create(_make_basic_pokemon_card(card_name), 0))
		visible_labels.append(card_name)
	var selectable_cards: Array[CardInstance] = [visible_cards[1], visible_cards[4], visible_cards[8]]
	var card_indices := [-1, 0, -1, -1, 1, -1, -1, -1, 2, -1, -1, -1]
	var source_card := CardInstance.create(_make_stadium_card("Test Mesagoza"), 0)
	var step := {
		"id": "search_pokemon",
		"title": "Choose a Pokemon",
		"items": selectable_cards,
		"labels": ["Deck Pokemon 01", "Deck Pokemon 04", "Deck Pokemon 08"],
		"presentation": "cards",
		"card_items": visible_cards,
		"card_indices": card_indices,
		"choice_labels": visible_labels,
		"visible_scope": "own_full_deck",
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	}
	var steps: Array[Dictionary] = []
	steps.append(step)
	scene.call("_start_effect_interaction", "play_stadium", 0, steps, source_card)

	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var dialog_overlay := scene.find_child("DialogOverlay", true, false) as Control
	var dialog_center := scene.find_child("DialogCenter", true, false) as Control
	var dialog_box := scene.find_child("DialogBox", true, false) as Control
	var dialog_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	var dialog_row := scene.get("_dialog_card_row") as HBoxContainer
	var expected_width := float(scene.call("_portrait_popup_near_width"))
	var first_card := dialog_row.get_child(0) as Control if dialog_row != null and dialog_row.get_child_count() > 0 else null
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var result := run_checks([
		assert_eq(str(scene.get("_pending_choice")), "effect_interaction", "Full-library card search should stay in the effect-interaction flow"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Android portrait full-library search should show the shared dialog overlay"),
		assert_eq(dialog_overlay.position if dialog_overlay != null else Vector2(-1, -1), frame_rect.position, "Portrait dialog overlay should be anchored to the active portrait frame"),
		assert_eq(dialog_overlay.size if dialog_overlay != null else Vector2.ZERO, frame_rect.size, "Portrait dialog overlay should have a non-zero Android portrait frame size"),
		assert_eq(dialog_center.size if dialog_center != null else Vector2.ZERO, frame_rect.size, "Dialog center should fill the visible portrait overlay frame"),
		assert_true(dialog_box != null and absf(dialog_box.custom_minimum_size.x - expected_width) < 0.1, "Android portrait search dialog should use the near-screen popup width"),
		assert_true(dialog_scroll != null and dialog_scroll.visible and dialog_scroll.custom_minimum_size.y >= dialog_card_size.y, "Full-library card gallery should keep a visible card-height scroll lane"),
		assert_eq(dialog_row.get_child_count() if dialog_row != null else 0, visible_cards.size(), "Full-library search should render every visible deck card, including disabled cards"),
		assert_eq(first_card.custom_minimum_size if first_card != null else Vector2.ZERO, dialog_card_size, "Rendered search cards should use the active Android portrait dialog card metrics"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_layout_resizes_already_open_setup_bench_card_dialog() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")

	var stale_landscape_dialog_size := Vector2(148, 208)
	scene.set("_dialog_card_size", stale_landscape_dialog_size)
	var basic_a := CardInstance.create(_make_basic_pokemon_card("Setup Bench A"), 0)
	var basic_b := CardInstance.create(_make_basic_pokemon_card("Setup Bench B"), 0)
	scene.call("_show_dialog", "Setup bench", ["完成", "Setup Bench A", "Setup Bench B"], {
		"presentation": "cards",
		"card_items": [basic_a, basic_b],
		"card_indices": [1, 2],
		"choice_labels": ["Setup Bench A", "Setup Bench B"],
		"utility_actions": [{"label": "完成", "index": 0}],
		"allow_cancel": false,
	})

	var dialog_row := scene.get("_dialog_card_row") as HBoxContainer
	var dialog_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	var dialog_title := scene.find_child("DialogTitle", true, false) as Label
	var utility_row := scene.get("_dialog_utility_row") as HBoxContainer
	var utility_button := utility_row.get_child(0) as Button if utility_row != null and utility_row.get_child_count() > 0 else null
	var card_before := dialog_row.get_child(0) as BattleCardViewScript if dialog_row != null and dialog_row.get_child_count() > 0 else null
	var card_size_before := card_before.custom_minimum_size if card_before != null else Vector2.ZERO
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var portrait_dialog_size: Vector2 = scene.get("_dialog_card_size")
	var card_after := dialog_row.get_child(0) as BattleCardViewScript if dialog_row != null and dialog_row.get_child_count() > 0 else null
	var expected_scroll_height := float(scene.call("_dialog_card_scroll_height"))

	var result := run_checks([
		assert_eq(card_size_before, stale_landscape_dialog_size, "Setup bench dialog should start from the stale pre-portrait card size in this regression scenario"),
		assert_eq(card_after.custom_minimum_size if card_after != null else Vector2.ZERO, portrait_dialog_size, "Portrait layout should resize an already-open setup bench card dialog to the current portrait dialog card size"),
		assert_true(dialog_scroll != null and absf(dialog_scroll.custom_minimum_size.y - expected_scroll_height) <= 0.1, "Portrait layout should also resize the already-open card dialog scroll lane"),
		assert_true(dialog_title != null and dialog_title.get_theme_font_size("font_size") >= 28, "Portrait layout should double the already-open setup bench dialog title text"),
		assert_true(utility_button != null and utility_button.get_theme_font_size("font_size") >= 34, "Portrait layout should double the already-open setup bench utility button text"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_discard_overlay_uses_near_screen_width() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	scene.set("_discard_overlay", scene.find_child("DiscardOverlay", true, false))
	scene.set("_discard_title", scene.find_child("DiscardTitle", true, false))
	scene.set("_discard_list", scene.find_child("DiscardList", true, false))
	scene.call("_setup_discard_gallery")
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.discard_pile.append(CardInstance.create(_make_basic_pokemon_card("Discarded %d" % player_index), player_index))
		game_state.players.append(player)
	gsm.game_state = game_state
	scene.set("_gsm", gsm)
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	scene.call("_show_discard_pile", 0, "己方弃牌区")
	var discard_box := scene.find_child("DiscardBox", true, false) as Control
	var close_button := scene.find_child("DiscardCloseBtn", true, false) as Button
	var expected_width := float(scene.call("_portrait_popup_near_width"))
	var result := run_checks([
		assert_true(discard_box != null and absf(discard_box.custom_minimum_size.x - expected_width) < 0.1, "Portrait discard overlay should use the near-screen popup width"),
		assert_true(discard_box != null and discard_box.custom_minimum_size.x <= 390.0, "Portrait discard overlay should stay inside the portrait content width"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 112.0, "Portrait discard close button should use the large popup button target"),
		assert_true(close_button != null and close_button.get_theme_font_size("font_size") >= 34, "Portrait discard close button text should double"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_detail_overlay_uses_near_screen_width() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_detail_overlay", scene.find_child("DetailOverlay", true, false))
	scene.set("_detail_title", scene.find_child("DetailTitle", true, false))
	scene.set("_detail_content", scene.find_child("DetailContent", true, false))
	scene.set("_detail_close_btn", scene.find_child("DetailCloseBtn", true, false))
	scene.call("_setup_detail_preview")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	scene.call("_show_card_detail", _make_basic_pokemon_card("Detail Pokemon"))
	var detail_box := scene.find_child("DetailBox", true, false) as Control
	var close_button := scene.find_child("DetailCloseBtn", true, false) as Button
	var expected_width := float(scene.call("_portrait_popup_near_width"))
	var result := run_checks([
		assert_true(detail_box != null and absf(detail_box.custom_minimum_size.x - expected_width) < 0.1, "Portrait detail overlay should use the near-screen popup width"),
		assert_true(detail_box != null and detail_box.custom_minimum_size.x <= 390.0, "Portrait detail overlay should stay inside the portrait content width"),
		assert_true(close_button != null and close_button.custom_minimum_size.x >= 112.0, "Portrait detail close button should no longer be a tiny desktop target"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 112.0, "Portrait detail close button should use the large popup button target"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_detail_close_button_closes_on_touch_down() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_detail_overlay", scene.find_child("DetailOverlay", true, false))
	scene.set("_detail_title", scene.find_child("DetailTitle", true, false))
	scene.set("_detail_content", scene.find_child("DetailContent", true, false))
	scene.set("_detail_close_btn", scene.find_child("DetailCloseBtn", true, false))
	scene.call("_setup_detail_preview")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	scene.call("_show_card_detail", _make_basic_pokemon_card("Detail Pokemon"))
	var overlay := scene.find_child("DetailOverlay", true, false) as Control
	var close_button := scene.find_child("DetailCloseBtn", true, false) as Button
	if close_button != null:
		close_button.emit_signal("button_down")
	var result := run_checks([
		assert_true(close_button != null, "Portrait detail close button should exist"),
		assert_true(close_button != null and close_button.button_down.is_connected(Callable(scene, "_hide_card_detail")), "Portrait detail close button should close on touch down"),
		assert_true(overlay != null and not overlay.visible, "Portrait detail overlay should close immediately on close touch"),
		assert_true(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Closed detail overlay should not keep blocking input"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_center_axis_huds_share_stadium_height() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_style_vstar_lost_huds")

	var field_area := scene.find_child("FieldArea", true, false) as VBoxContainer
	var stadium_bar := scene.find_child("StadiumBar", true, false) as Control
	var turn_action_column := scene.find_child("TurnActionColumn", true, false) as Control
	var end_turn_button := scene.find_child("HudEndTurnBtn", true, false) as Button
	var my_vstar_panel := scene.find_child("InfoMyVstar", true, false) as Control
	var my_lost_panel := scene.find_child("InfoMyLost", true, false) as Control
	var my_pile_stack := scene.find_child("MyHudDataRow", true, false) as HBoxContainer
	var my_pile_vbox := scene.find_child("MyHudRightVBox", true, false) as VBoxContainer
	var my_vstar_image := my_vstar_panel.find_child("HudImageTexture", true, false) as TextureRect if my_vstar_panel != null else null
	var stadium_height := stadium_bar.custom_minimum_size.y if stadium_bar != null else 0.0
	var expected_vstar_height := stadium_height * 0.7
	var vstar_aspect := my_vstar_image.texture.get_size().x / my_vstar_image.texture.get_size().y if my_vstar_image != null and my_vstar_image.texture != null else 0.0

	var result := run_checks([
		assert_eq(field_area.get_theme_constant("separation") if field_area != null else -1, 0, "Portrait active Pokemon gap should be exactly the stadium HUD row without extra VBox spacing"),
		assert_true(end_turn_button != null and is_equal_approx(end_turn_button.custom_minimum_size.y, stadium_height), "Portrait end-turn button height should match the gap between active Pokemon"),
		assert_true(turn_action_column != null and is_equal_approx(turn_action_column.custom_minimum_size.y, stadium_height), "Portrait end-turn column should fill the central stadium row"),
		assert_true(my_vstar_panel != null and absf(my_vstar_panel.custom_minimum_size.y - expected_vstar_height) <= 1.0, "Portrait VSTAR HUD height should be 30 percent shorter than the stadium HUD height"),
		assert_true(my_vstar_image != null and my_vstar_image.texture != null, "Portrait VSTAR HUD should use the VSTAR PNG"),
		assert_true(my_vstar_image != null and my_vstar_panel != null and absf(my_vstar_image.custom_minimum_size.y - my_vstar_panel.custom_minimum_size.y) <= 1.0, "Portrait VSTAR image should use the reduced panel height"),
		assert_true(my_vstar_panel != null and vstar_aspect > 0.0 and absf(my_vstar_panel.custom_minimum_size.x - expected_vstar_height * vstar_aspect) <= 1.0, "Portrait VSTAR HUD width should preserve the PNG aspect ratio after the height reduction"),
		assert_true(my_lost_panel != null and my_pile_vbox != null and my_lost_panel.get_parent() == my_pile_vbox, "Portrait Lost Zone HUD should move under the pile HUD"),
		assert_true(my_lost_panel != null and my_pile_stack != null and is_equal_approx(my_lost_panel.custom_minimum_size.x, my_pile_stack.custom_minimum_size.x), "Portrait Lost Zone HUD should align with the deck/discard row edges"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_critical_controls_fit_safe_width_contract() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var checks: Array[String] = []
	for viewport_size: Vector2 in [Vector2(390, 844), Vector2(882, 1600), Vector2(900, 1600), Vector2(1280, 1600), Vector2(1600, 2844)]:
		var scene: Control = BattleScene.instantiate()
		var phase_label := scene.find_child("LblPhase", true, false) as Label
		var turn_label := scene.find_child("LblTurn", true, false) as Label
		if phase_label != null:
			phase_label.text = "Current deck: very long deck name that must not expand the portrait top bar | Opponent hand: 99"
		if turn_label != null:
			turn_label.text = "Round 12 | Player 2 action | very long phase text that must be clipped"
		scene.call("_apply_portrait_layout", viewport_size)
		scene.call("_apply_portrait_layout", viewport_size)
		var top_bar := scene.find_child("TopBar", true, false) as Control
		var top_bar_left := scene.find_child("TopBarLeft", true, false) as Control
		var top_bar_center := scene.find_child("TopBarCenter", true, false) as Control
		phase_label = scene.find_child("LblPhase", true, false) as Label
		turn_label = scene.find_child("LblTurn", true, false) as Label
		var main_area := scene.find_child("MainArea", true, false) as Control
		var center_field := scene.find_child("CenterField", true, false) as Control
		var field_area := scene.find_child("FieldArea", true, false) as Control
		var opp_field_shell := scene.find_child("OppFieldShell", true, false) as Control
		var my_field_shell := scene.find_child("MyFieldShell", true, false) as Control
		var opp_field_inner := scene.find_child("OppFieldInner", true, false) as Control
		var my_field_inner := scene.find_child("MyFieldInner", true, false) as Control
		var opp_active_row := scene.find_child("OppActiveRow", true, false) as Control
		var my_active_row := scene.find_child("MyActiveRow", true, false) as Control
		var opp_active := scene.find_child("OppActive", true, false) as Control
		var my_active := scene.find_child("MyActive", true, false) as Control
		var opp_bench_grid := scene.find_child("PortraitOppBenchGrid", true, false) as Control
		var my_bench_grid := scene.find_child("PortraitMyBenchGrid", true, false) as Control
		var hand_area := scene.find_child("HandArea", true, false) as Control
		var hand_scroll := scene.find_child("HandScroll", true, false) as Control
		var hand_container := scene.find_child("HandContainer", true, false) as HBoxContainer
		var stadium_center := scene.find_child("StadiumCenterSection", true, false) as Control
		var turn_action_column := scene.find_child("TurnActionColumn", true, false) as Control
		var stadium_sections := scene.find_child("StadiumSections", true, false) as HBoxContainer
		var hud_end_turn := scene.find_child("HudEndTurnBtn", true, false) as Button
		var play_card_size: Vector2 = scene.get("_play_card_size")
		if hand_container != null:
			for card_index: int in range(6):
				var card_stub := Control.new()
				card_stub.custom_minimum_size = play_card_size
				hand_container.add_child(card_stub)
		scene.call("_finalize_portrait_layout_constraints")
		var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
		var safe_width := _portrait_safe_width(scene, frame_rect.size)
		var frame_safe_x := float(scene.call("_portrait_horizontal_safe_inset", frame_rect.size))
		var frame_safe_left := frame_rect.position.x + frame_safe_x
		var frame_safe_right := frame_rect.position.x + frame_rect.size.x - frame_safe_x
		var top_width := _portrait_top_or_main_width(top_bar, viewport_size)
		var main_width := _portrait_top_or_main_width(main_area, viewport_size)
		var top_rect := _battle_local_rect(scene, top_bar)
		var main_rect := _battle_local_rect(scene, main_area)
		var hand_rect := _battle_local_rect(scene, hand_area)
		var hand_scroll_rect := _battle_local_rect(scene, hand_scroll)
		var stadium_rect := _battle_local_rect(scene, stadium_center)
		var end_rect := _battle_local_rect(scene, turn_action_column)
		var end_button_rect := _battle_local_rect(scene, hud_end_turn)
		var stadium_gap := float(stadium_sections.get_theme_constant("separation")) if stadium_sections != null else 0.0
		var stadium_width := stadium_center.custom_minimum_size.x if stadium_center != null else 0.0
		var end_width := turn_action_column.custom_minimum_size.x if turn_action_column != null else 0.0
		var five_hand_width := play_card_size.x * 5.0 + 4.0 * 12.0
		checks.append(assert_true(top_bar != null and top_bar.clip_contents, "Portrait top bar should clip inside the safe frame for %s" % str(viewport_size)))
		checks.append(assert_true(top_bar != null and top_bar.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait top bar minimum width must not exceed safe width for %s: %.1f <= %.1f" % [str(viewport_size), top_bar.get_combined_minimum_size().x if top_bar != null else -1.0, safe_width]))
		checks.append(assert_true(top_bar_left != null and top_bar_left.clip_contents and top_bar_left.custom_minimum_size.x <= 0.5, "Portrait top left text slot must be compressible for %s" % str(viewport_size)))
		checks.append(assert_true(top_bar_center != null and top_bar_center.clip_contents and top_bar_center.custom_minimum_size.x <= 0.5, "Portrait top center text slot must be compressible for %s" % str(viewport_size)))
		checks.append(assert_true(phase_label != null and phase_label.clip_text and phase_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Portrait phase label must clip instead of forcing top bar width for %s" % str(viewport_size)))
		checks.append(assert_true(turn_label != null and turn_label.clip_text and turn_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Portrait turn label must clip instead of forcing top bar width for %s" % str(viewport_size)))
		checks.append(assert_true(main_area != null and main_area.clip_contents, "Portrait main area should clip inside the safe frame for %s" % str(viewport_size)))
		checks.append(assert_true(top_width <= safe_width + 0.5, "Portrait top bar width should fit safe width for %s: %.1f <= %.1f" % [str(viewport_size), top_width, safe_width]))
		checks.append(assert_true(main_width <= safe_width + 0.5, "Portrait main area width should fit safe width for %s: %.1f <= %.1f" % [str(viewport_size), main_width, safe_width]))
		checks.append(assert_true(_rect_fits_x(top_rect, frame_safe_left, frame_safe_right), "Portrait top bar actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(top_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(_rect_fits_x(main_rect, frame_safe_left, frame_safe_right), "Portrait main area actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(main_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(_rect_fits_x(hand_rect, frame_safe_left, frame_safe_right), "Portrait hand area actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(hand_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(_rect_fits_x(hand_scroll_rect, frame_safe_left, frame_safe_right), "Portrait hand scroll actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(hand_scroll_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(_rect_fits_x(stadium_rect, frame_safe_left, frame_safe_right), "Portrait stadium HUD actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(stadium_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(_rect_fits_x(end_rect, frame_safe_left, frame_safe_right), "Portrait end-turn column actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(end_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(_rect_fits_x(end_button_rect, frame_safe_left, frame_safe_right), "Portrait end-turn button actual rect must stay inside the visible frame for %s: %s within %.1f..%.1f" % [str(viewport_size), str(end_button_rect), frame_safe_left, frame_safe_right]))
		checks.append(assert_true(hand_area != null and hand_area.clip_contents, "Portrait hand panel must clip overflowing cards for %s" % str(viewport_size)))
		checks.append(assert_true(hand_scroll != null and hand_scroll.clip_contents, "Portrait hand scroll must clip overflowing cards for %s" % str(viewport_size)))
		checks.append(assert_true(hand_area != null and hand_area.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait hand panel minimum width must not be expanded by hand cards for %s: %.1f <= %.1f" % [str(viewport_size), hand_area.get_combined_minimum_size().x if hand_area != null else -1.0, safe_width]))
		checks.append(assert_true(hand_scroll != null and hand_scroll.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait hand scroll minimum width must not be expanded by hand cards for %s: %.1f <= %.1f" % [str(viewport_size), hand_scroll.get_combined_minimum_size().x if hand_scroll != null else -1.0, safe_width]))
		for field_control: Control in [center_field, field_area, opp_field_shell, my_field_shell, opp_field_inner, my_field_inner, opp_active_row, my_active_row]:
			checks.append(assert_true(field_control != null and absf(field_control.custom_minimum_size.x - safe_width) <= 0.5, "Portrait field axis control should inherit safe width for %s: %s min %.1f expected %.1f" % [str(viewport_size), field_control.name if field_control != null else "<null>", field_control.custom_minimum_size.x if field_control != null else -1.0, safe_width]))
			checks.append(assert_true(field_control != null and field_control.clip_contents, "Portrait field axis control should clip stale wide children for %s: %s" % [str(viewport_size), field_control.name if field_control != null else "<null>"]))
		checks.append(assert_true(opp_bench_grid != null and opp_bench_grid.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait opponent bench grid minimum width must fit safe frame for %s: %.1f <= %.1f" % [str(viewport_size), opp_bench_grid.get_combined_minimum_size().x if opp_bench_grid != null else -1.0, safe_width]))
		checks.append(assert_true(my_bench_grid != null and my_bench_grid.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait self bench grid minimum width must fit safe frame for %s: %.1f <= %.1f" % [str(viewport_size), my_bench_grid.get_combined_minimum_size().x if my_bench_grid != null else -1.0, safe_width]))
		checks.append(assert_true(opp_active != null and opp_active.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait opponent active Pokemon minimum width must fit safe frame for %s" % str(viewport_size)))
		checks.append(assert_true(my_active != null and my_active.get_combined_minimum_size().x <= safe_width + 0.5, "Portrait self active Pokemon minimum width must fit safe frame for %s" % str(viewport_size)))
		checks.append(assert_true(stadium_width + end_width + stadium_gap * 2.0 <= safe_width + 0.5, "Portrait stadium + end-turn controls must fit safe width for %s: %.1f <= %.1f" % [str(viewport_size), stadium_width + end_width + stadium_gap * 2.0, safe_width]))
		checks.append(assert_true(hud_end_turn != null and hud_end_turn.custom_minimum_size.y >= 44.0, "Portrait end-turn button should stay touch-sized for %s" % str(viewport_size)))
		if viewport_size.x >= 780.0:
			checks.append(assert_true(five_hand_width <= safe_width + 0.5, "Portrait logical phone width should show five hand cards for %s: %.1f <= %.1f" % [str(viewport_size), five_hand_width, safe_width]))
		scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return run_checks(checks)


func test_portrait_direct_layout_uses_expanded_logical_canvas_as_visible_frame() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var viewport_size := Vector2(1600, 2844)
	scene.call("_apply_portrait_layout", viewport_size)

	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var top_bar := scene.find_child("TopBar", true, false) as Control
	var main_area := scene.find_child("MainArea", true, false) as Control
	var safe_width := _portrait_safe_width(scene, frame_rect.size)
	var top_width := _portrait_top_or_main_width(top_bar, viewport_size)
	var main_width := _portrait_top_or_main_width(main_area, viewport_size)
	var frame_safe_x := float(scene.call("_portrait_horizontal_safe_inset", frame_rect.size))
	var frame_safe_left := frame_rect.position.x + frame_safe_x
	var frame_safe_right := frame_rect.position.x + frame_rect.size.x - frame_safe_x
	var top_rect := _battle_local_rect(scene, top_bar)
	var main_rect := _battle_local_rect(scene, main_area)

	var result := run_checks([
		assert_eq(frame_rect.position, Vector2.ZERO, "Direct portrait layout should use the full expanded logical canvas origin"),
		assert_eq(frame_rect.size, viewport_size, "Direct portrait layout should use the expanded logical canvas as the visible battle frame"),
		assert_true(top_width <= safe_width + 0.5, "Top bar should be constrained to the full portrait frame: %.1f <= %.1f" % [top_width, safe_width]),
		assert_true(main_width <= safe_width + 0.5, "Main area and hand rail should be constrained to the full portrait frame: %.1f <= %.1f" % [main_width, safe_width]),
		assert_true(_rect_fits_x(top_rect, frame_safe_left, frame_safe_right), "Top bar actual rect should stay in the full portrait frame: %s within %.1f..%.1f" % [str(top_rect), frame_safe_left, frame_safe_right]),
		assert_true(_rect_fits_x(main_rect, frame_safe_left, frame_safe_right), "Main area actual rect should stay in the full portrait frame: %s within %.1f..%.1f" % [str(main_rect), frame_safe_left, frame_safe_right]),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_direct_layout_centers_short_wide_visible_frame() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var viewport_size := Vector2(1280, 1600)
	scene.call("_apply_portrait_layout", viewport_size)

	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var top_bar := scene.find_child("TopBar", true, false) as Control
	var main_area := scene.find_child("MainArea", true, false) as Control
	var safe_x := float(scene.call("_portrait_horizontal_safe_inset", frame_rect.size))
	var frame_safe_left := frame_rect.position.x + safe_x
	var frame_safe_right := frame_rect.position.x + frame_rect.size.x - safe_x
	var result := run_checks([
		assert_eq(frame_rect, Rect2(Vector2(190, 0), Vector2(900, 1600)), "Direct short-wide portrait layout should center a 9:16 visible battle frame"),
		assert_true(_rect_fits_x(_battle_local_rect(scene, top_bar), frame_safe_left, frame_safe_right), "Top bar should fit inside the centered short-wide portrait frame"),
		assert_true(_rect_fits_x(_battle_local_rect(scene, main_area), frame_safe_left, frame_safe_right), "Main area should fit inside the centered short-wide portrait frame"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_direct_relayout_recomputes_frame_after_viewport_change() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(900, 1600))
	scene.call("_apply_portrait_layout", Vector2(1600, 2844))

	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var top_bar := scene.find_child("TopBar", true, false) as Control
	var main_area := scene.find_child("MainArea", true, false) as Control
	var safe_x := float(scene.call("_portrait_horizontal_safe_inset", frame_rect.size))
	var frame_safe_left := frame_rect.position.x + safe_x
	var frame_safe_right := frame_rect.position.x + frame_rect.size.x - safe_x
	var result := run_checks([
		assert_eq(frame_rect, Rect2(Vector2.ZERO, Vector2(1600, 2844)), "Portrait relayout must not reuse the previous smaller frame after viewport size changes"),
		assert_true(_rect_fits_x(_battle_local_rect(scene, top_bar), frame_safe_left, frame_safe_right), "Top bar should fit the recomputed expanded frame after relayout"),
		assert_true(_rect_fits_x(_battle_local_rect(scene, main_area), frame_safe_left, frame_safe_right), "Main area should fit the recomputed expanded frame after relayout"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_field_content_presses_toward_battle_axis() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_landscape_layout", Vector2(1600, 900))
	var opp_field_inner := scene.find_child("OppFieldInner", true, false) as VBoxContainer
	var my_field_inner := scene.find_child("MyFieldInner", true, false) as VBoxContainer
	var result := run_checks([
		assert_eq(scene.size, Vector2(1600, 900), "Direct landscape layout should size the scene root to the landscape viewport"),
		assert_true(opp_field_inner != null and opp_field_inner.alignment == BoxContainer.ALIGNMENT_END, "Landscape opponent field content should press down toward the battle axis"),
		assert_true(my_field_inner != null and my_field_inner.alignment == BoxContainer.ALIGNMENT_BEGIN, "Landscape self field content should press up toward the battle axis"),
	])
	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_field_interaction_panel_uses_safe_touch_width() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.set("_play_card_size", Vector2(108, 150))
	scene.call("_setup_field_interaction_panel")
	scene.call("_update_field_interaction_panel_metrics", Vector2(390, 844))

	var panel := scene.get("_field_interaction_panel") as Control
	var clear_button := scene.get("_field_interaction_clear_btn") as Button
	var cancel_button := scene.get("_field_interaction_cancel_btn") as Button
	var confirm_button := scene.get("_field_interaction_confirm_btn") as Button
	var title_label := scene.get("_field_interaction_title_lbl") as Label
	var status_label := scene.get("_field_interaction_status_lbl") as Label
	var result := run_checks([
		assert_true(panel != null and panel.custom_minimum_size.x <= 366.0, "Portrait field interaction panel should clamp to safe phone width instead of keeping a desktop minimum"),
		assert_true(clear_button != null and clear_button.custom_minimum_size.y >= 56.0, "Field interaction clear button should be touch-sized"),
		assert_true(cancel_button != null and cancel_button.custom_minimum_size.y >= 56.0, "Field interaction cancel button should be touch-sized"),
		assert_true(confirm_button != null and confirm_button.custom_minimum_size.y >= 56.0, "Field interaction confirm button should be touch-sized"),
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 18, "Field interaction title should use touch-readable text"),
		assert_true(status_label != null and status_label.get_theme_font_size("font_size") >= 16, "Field interaction status should use touch-readable text"),
	])

	scene.queue_free()
	return result


func test_portrait_popup_text_metrics_double_fixed_overlay_fonts() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var dialog_title := scene.find_child("DialogTitle", true, false) as Label
	var detail_title := scene.find_child("DetailTitle", true, false) as Label
	var detail_content := scene.find_child("DetailContent", true, false) as RichTextLabel
	var discard_title := scene.find_child("DiscardTitle", true, false) as Label
	var review_title := scene.find_child("ReviewTitle", true, false) as Label
	var handover_label := scene.find_child("HandoverLbl", true, false) as Label
	var coin_label := scene.find_child("CoinResultLbl", true, false) as Label

	var result := run_checks([
		assert_true(dialog_title != null and dialog_title.get_theme_font_size("font_size") >= 28, "Portrait dialog title font should double from the compact scene default"),
		assert_true(detail_title != null and detail_title.get_theme_font_size("font_size") >= 30, "Portrait detail title font should double"),
		assert_true(detail_content != null and detail_content.get_theme_font_size("normal_font_size") >= 28, "Portrait detail body font should be touch-readable"),
		assert_true(discard_title != null and discard_title.get_theme_font_size("font_size") >= 26, "Portrait discard title font should double"),
		assert_true(review_title != null and review_title.get_theme_font_size("font_size") >= 30, "Portrait review title font should double"),
		assert_true(handover_label != null and handover_label.get_theme_font_size("font_size") >= 28, "Portrait handover prompt font should double"),
		assert_true(coin_label != null and coin_label.get_theme_font_size("font_size") >= 32, "Portrait coin prompt font should double"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_text_dialog_scales_dynamic_option_and_footer_fonts() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_show_dialog", "Test prompt", ["Option A"], {"allow_cancel": true})

	var dialog_title := scene.find_child("DialogTitle", true, false) as Label
	var cancel_button := scene.find_child("DialogCancel", true, false) as Button
	var confirm_button := scene.find_child("DialogConfirm", true, false) as Button
	var dynamic_option_label: Label = null
	var dialog_card_row := scene.get("_dialog_card_row") as Node
	if dialog_card_row != null:
		dynamic_option_label = _find_label_with_text(dialog_card_row, "Option A")

	var result := run_checks([
		assert_true(dialog_title != null and dialog_title.get_theme_font_size("font_size") >= 28, "Dynamic text dialog title should stay scaled after show_dialog rebuilds content"),
		assert_true(dynamic_option_label != null and dynamic_option_label.get_theme_font_size("font_size") >= 38, "Dynamic text dialog options should scale after they are created"),
		assert_true(cancel_button != null and cancel_button.get_theme_font_size("font_size") >= 34, "Dialog cancel button font should double in portrait"),
		assert_true(confirm_button != null and confirm_button.get_theme_font_size("font_size") >= 34, "Dialog confirm button font should double in portrait"),
		assert_true(cancel_button != null and cancel_button.custom_minimum_size.y >= 112.0, "Dialog button height should use the large portrait popup target"),
		assert_true(confirm_button != null and confirm_button.custom_minimum_size.y >= 112.0, "Dialog confirm button should use the large portrait popup target"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_mulligan_prompt_uses_large_stable_text_option() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	var previous_mode: int = GameManager.current_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var scene: Control = BattleScene.instantiate()
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	scene.call("_on_player_choice_required", "mulligan_extra_draw", {"beneficiary": 0, "mulligan_count": 1})
	var dialog_box := scene.find_child("DialogBox", true, false) as Control
	var first_box_size := dialog_box.custom_minimum_size if dialog_box != null else Vector2.ZERO
	var first_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	var first_panels := _text_hud_panels(scene.get("_dialog_card_row") as Node)
	var first_panel := first_panels[0] if not first_panels.is_empty() else null

	scene.call("_on_player_choice_required", "mulligan_extra_draw", {"beneficiary": 0, "mulligan_count": 2})
	var second_box_size := dialog_box.custom_minimum_size if dialog_box != null else Vector2.ZERO
	var second_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	var second_panels := _text_hud_panels(scene.get("_dialog_card_row") as Node)
	var second_panel := second_panels[0] if not second_panels.is_empty() else null
	var safe_width := _portrait_safe_width(scene, Vector2(390, 844))

	var result := run_checks([
		assert_true(first_panel != null and first_panel.custom_minimum_size.y >= 112.0, "First portrait mulligan prompt button should use a large touch height"),
		assert_true(second_panel != null and second_panel.custom_minimum_size.y >= 112.0, "Second portrait mulligan prompt button should keep the large touch height"),
		assert_true(first_panel != null and first_panel.custom_minimum_size.x <= first_box_size.x, "First portrait mulligan prompt button should not force the dialog wider"),
		assert_true(second_panel != null and second_panel.custom_minimum_size.x <= second_box_size.x, "Second portrait mulligan prompt button should not force the dialog wider"),
		assert_true(first_scroll != null and first_panel != null and first_scroll.custom_minimum_size.y >= first_panel.custom_minimum_size.y, "First portrait mulligan prompt scroll area should fit the large button"),
		assert_true(second_scroll != null and second_panel != null and second_scroll.custom_minimum_size.y >= second_panel.custom_minimum_size.y, "Second portrait mulligan prompt scroll area should fit the large button"),
		assert_true(first_box_size.x <= safe_width + 0.5 and second_box_size.x <= safe_width + 0.5, "Portrait mulligan prompt dialog should stay within the safe portrait width"),
		assert_true(absf(first_box_size.x - second_box_size.x) <= 0.5, "Repeated portrait mulligan prompts should keep a stable width"),
		assert_true(absf(first_box_size.y - second_box_size.y) <= 0.5, "Repeated portrait mulligan prompts should keep a stable height"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	GameManager.current_mode = previous_mode
	return result


func test_portrait_field_interaction_popup_text_metrics_double_after_layout() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_play_card_size", Vector2(108, 150))
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_setup_field_interaction_panel")
	scene.call("_update_field_interaction_panel_metrics", Vector2(390, 844))

	var title_label := scene.get("_field_interaction_title_lbl") as Label
	var status_label := scene.get("_field_interaction_status_lbl") as Label
	var cancel_button := scene.get("_field_interaction_cancel_btn") as Button
	var confirm_button := scene.get("_field_interaction_confirm_btn") as Button
	var result := run_checks([
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 36, "Portrait field interaction title should double from the touch profile"),
		assert_true(status_label != null and status_label.get_theme_font_size("font_size") >= 32, "Portrait field interaction status text should double from the touch profile"),
		assert_true(cancel_button != null and cancel_button.get_theme_font_size("font_size") >= 36, "Portrait field interaction cancel button should double from the touch profile"),
		assert_true(cancel_button != null and cancel_button.custom_minimum_size.y >= 112.0, "Portrait field interaction cancel button should use the large portrait popup target"),
		assert_true(confirm_button != null and confirm_button.custom_minimum_size.y >= 112.0, "Portrait field interaction confirm button should use the large portrait popup target"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_field_assignment_source_cards_use_dialog_touch_size() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_setup_field_interaction_panel")

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Active %d" % player_index), player_index))
		player.active_pokemon = active_slot
		game_state.players.append(player)
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Bench Target"), 0))
	game_state.players[0].bench.append(bench_slot)
	gsm.game_state = game_state
	scene.set("_gsm", gsm)

	var energy_card := CardInstance.create(_make_basic_energy_card("Grass Energy", "G"), 0)
	scene.call("_show_field_assignment_interaction", {
		"title": "Glass Trumpet",
		"ui_mode": "card_assignment",
		"source_items": [energy_card],
		"source_labels": ["Grass Energy"],
		"target_items": [bench_slot],
		"target_labels": ["Bench Target"],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	})

	var row := scene.get("_field_interaction_row") as HBoxContainer
	var source_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var scroll := scene.get("_field_interaction_scroll") as ScrollContainer
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var play_card_size: Vector2 = scene.get("_play_card_size")
	var cancel_button := scene.get("_field_interaction_cancel_btn") as Button
	var confirm_button := scene.get("_field_interaction_confirm_btn") as Button
	var clear_button := scene.get("_field_interaction_clear_btn") as Button
	var panel := scene.get("_field_interaction_panel") as Control
	scene.set("_field_interaction_assignment_entries", [{"source_index": 0, "target_index": 0}])
	scene.call("_refresh_field_interaction_status")
	var visible_button_min_width := 0.0
	var visible_button_count := 0
	for button_variant: Variant in [clear_button, cancel_button, confirm_button]:
		var button := button_variant as Button
		if button != null and button.visible:
			visible_button_count += 1
			visible_button_min_width += button.custom_minimum_size.x
	if visible_button_count > 1:
		visible_button_min_width += float(visible_button_count - 1) * 10.0
	var cancel_style := cancel_button.get_theme_stylebox("normal") as StyleBoxFlat if cancel_button != null else null
	var confirm_style := confirm_button.get_theme_stylebox("normal") as StyleBoxFlat if confirm_button != null else null
	var result := run_checks([
		assert_true(source_card != null and source_card.custom_minimum_size.y >= dialog_card_size.y, "Portrait field-assignment source card buttons should use the dialog card touch height"),
		assert_true(source_card != null and source_card.custom_minimum_size.y > play_card_size.y, "Portrait field-assignment source card buttons should be larger than the hand card size"),
		assert_true(scroll != null and scroll.custom_minimum_size.y >= dialog_card_size.y, "Portrait field-assignment source row should reserve enough vertical space for enlarged cards"),
		assert_true(cancel_button != null and cancel_button.custom_minimum_size.y >= 112.0, "Portrait field-assignment cancel button should keep the large popup touch target"),
		assert_true(confirm_button != null and confirm_button.custom_minimum_size.y >= 112.0, "Portrait field-assignment confirm button should keep the large popup touch target"),
		assert_true(cancel_button != null and bool(cancel_button.get_meta("field_interaction_hud_button", false)), "Portrait field-assignment cancel button should use the unified HUD button style"),
		assert_true(confirm_button != null and bool(confirm_button.get_meta("field_interaction_hud_button", false)), "Portrait field-assignment confirm button should use the unified HUD button style"),
		assert_true(cancel_style != null and cancel_style.border_color.a > 0.8, "Portrait field-assignment cancel button should have a visible HUD border"),
		assert_true(confirm_style != null and confirm_style.border_color.a > 0.8, "Portrait field-assignment confirm button should have a visible HUD border"),
		assert_true(panel != null and visible_button_min_width <= panel.custom_minimum_size.x + 0.5, "Portrait field-assignment HUD buttons should fit together when Clear, Cancel, and Confirm are visible"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_popup_text_metrics_restore_when_leaving_portrait() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var dialog_title := scene.find_child("DialogTitle", true, false) as Label
	var scaled_size := dialog_title.get_theme_font_size("font_size") if dialog_title != null else 0
	scene.call("_restore_portrait_popup_text_metrics")
	var restored_size := dialog_title.get_theme_font_size("font_size") if dialog_title != null else 0

	var result := run_checks([
		assert_true(scaled_size >= 28, "Portrait setup should scale the dialog title before restore"),
		assert_eq(restored_size, 14, "Leaving portrait should restore fixed overlay font sizes instead of leaving doubled text in landscape"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_scrollbars_use_double_touch_profile_for_hand_and_dialogs() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	var dialog_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	var hand_bar := hand_scroll.get_h_scroll_bar() if hand_scroll != null else null
	var dialog_bar := dialog_scroll.get_h_scroll_bar() if dialog_scroll != null else null
	var expected_thickness := HudThemeScript.SCROLLBAR_PORTRAIT_TOUCH_THICKNESS
	var result := run_checks([
		assert_eq(hand_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Portrait hand row should preserve ScrollContainer sizing while hiding the native horizontal bar"),
		assert_true(bool(hand_scroll.get_meta("hand_drag_scroll_enabled", false)), "Portrait hand row should expose the drag-scroll contract"),
		assert_true(hand_bar != null and bool(hand_bar.get_meta("hand_hidden_scrollbar", false)) and hand_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Portrait hand scrollbar should be hidden and non-interactive"),
		assert_eq(str(dialog_bar.get_meta("hud_scrollbar_profile")) if dialog_bar != null and dialog_bar.has_meta("hud_scrollbar_profile") else "", "portrait_touch", "Portrait card dialog scrollbar should use the enlarged touch profile"),
		assert_eq(int(dialog_bar.get_meta("hud_scrollbar_thickness")) if dialog_bar != null and dialog_bar.has_meta("hud_scrollbar_thickness") else -1, expected_thickness, "Portrait card dialog scrollbar thickness should double the normal touch rail"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_scrollbars_restore_when_leaving_portrait() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	var hand_bar := hand_scroll.get_h_scroll_bar() if hand_scroll != null else null
	var portrait_drag_enabled := bool(hand_scroll.get_meta("hand_drag_scroll_enabled", false)) if hand_scroll != null else false
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	scene.call("_restore_portrait_scrollbar_metrics")

	var result := run_checks([
		assert_true(portrait_drag_enabled, "Portrait setup should enable hand drag scrolling"),
		assert_eq(hand_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Leaving portrait should keep hand ScrollContainer sizing stable while drag scrolling remains enabled"),
		assert_true(hand_bar != null and bool(hand_bar.get_meta("hand_hidden_scrollbar", false)) and hand_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Leaving portrait should keep the hand native scrollbar hidden"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var found := _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func _text_hud_panels(node: Node) -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	_collect_text_hud_panels(node, panels)
	return panels


func _collect_text_hud_panels(node: Node, panels: Array[PanelContainer]) -> void:
	if node == null:
		return
	if node is PanelContainer and node.has_meta("dialog_text_choice_index"):
		panels.append(node as PanelContainer)
	for child: Node in node.get_children():
		_collect_text_hud_panels(child, panels)


func test_portrait_selected_hand_energy_attaches_to_reparented_bench_slot() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	scene.call("_apply_portrait_layout", Vector2(900, 1600))
	scene.set("_handover_panel", scene.find_child("HandoverPanel", true, false))
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Active %d" % player_index), player_index))
		player.active_pokemon = active_slot
		game_state.players.append(player)
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Bench Target"), 0))
	game_state.players[0].bench.append(bench_slot)
	var energy_card := CardInstance.create(_make_basic_energy_card("Grass Energy", "G"), 0)
	game_state.players[0].hand.append(energy_card)
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state = game_state
	scene.set("_gsm", gsm)
	scene.set("_selected_hand_card", energy_card)

	scene.call("_handle_slot_left_click", "my_bench_0")

	var result := run_checks([
		assert_eq(bench_slot.attached_energy.size(), 1, "Portrait bench target click should use the normal attach-energy path after bench reparenting"),
		assert_eq(scene.get("_selected_hand_card"), null, "Successful portrait bench energy attach should clear the selected hand card"),
	])
	scene.queue_free()
	return result


func test_portrait_reparented_bench_slot_keeps_mouse_input_binding() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	scene.call("_apply_portrait_layout", Vector2(900, 1600))
	scene.set("_handover_panel", scene.find_child("HandoverPanel", true, false))
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Active %d" % player_index), player_index))
		player.active_pokemon = active_slot
		game_state.players.append(player)
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Bench Target"), 0))
	game_state.players[0].bench.append(bench_slot)
	var energy_card := CardInstance.create(_make_basic_energy_card("Grass Energy", "G"), 0)
	game_state.players[0].hand.append(energy_card)
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state = game_state
	scene.set("_gsm", gsm)
	scene.set("_selected_hand_card", energy_card)

	var bench_panel := scene.find_child("MyBench0", true, false) as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	if bench_panel != null:
		event.position = bench_panel.get_global_rect().get_center()
		event.global_position = event.position
		bench_panel.emit_signal("gui_input", event)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = event.position
		release.global_position = event.global_position
		bench_panel.emit_signal("gui_input", release)

	var result := run_checks([
		assert_true(bench_panel != null and bench_panel.get_parent() != scene.find_child("MyBench", true, false), "Portrait layout should reparent the bench slot out of the hidden horizontal bench"),
		assert_eq(bench_slot.attached_energy.size(), 1, "Reparented portrait bench slot gui_input should still attach the selected hand Energy"),
		assert_eq(scene.get("_selected_hand_card"), null, "Successful portrait bench gui_input action should clear the selected hand card"),
	])
	scene.queue_free()
	return result


func test_portrait_discard_hud_panels_open_discard_dialog() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.discard_pile.append(CardInstance.create(_make_basic_pokemon_card("Discarded %d" % player_index), player_index))
		game_state.players.append(player)
	gsm.game_state = game_state
	scene.set("_gsm", gsm)
	scene.set("_discard_overlay", scene.find_child("DiscardOverlay", true, false))
	scene.set("_discard_title", scene.find_child("DiscardTitle", true, false))
	scene.set("_discard_list", scene.find_child("DiscardList", true, false))
	scene.set("_discard_card_scroll", scene.find_child("DiscardCardScroll", true, false))
	scene.set("_discard_card_row", scene.find_child("DiscardCardRow", true, false))
	scene.set("_discard_utility_row", scene.find_child("DiscardUtilityRow", true, false))
	scene.call("_bind_discard_hud_openers")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var my_panel := scene.find_child("MyDiscardHudPanel", true, false) as Control
	if my_panel != null:
		my_panel.emit_signal("gui_input", event)
	var discard_overlay := scene.find_child("DiscardOverlay", true, false) as Control
	var self_opened := discard_overlay != null and discard_overlay.visible
	if discard_overlay != null:
		discard_overlay.visible = false
	var opp_panel := scene.find_child("OppDiscardHudPanel", true, false) as Control
	if opp_panel != null:
		opp_panel.emit_signal("gui_input", event)
	var opponent_opened := discard_overlay != null and discard_overlay.visible

	var result := run_checks([
		assert_true(self_opened, "Portrait self discard HUD panel should open the discard dialog"),
		assert_true(opponent_opened, "Portrait opponent discard HUD panel should open the discard dialog"),
	])
	scene.queue_free()
	return result


func test_portrait_layout_uses_full_tall_viewport_without_inner_frame() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var backdrop := TextureRect.new()
	backdrop.name = "BattleBackdrop"
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	scene.add_child(backdrop)
	scene.move_child(backdrop, 0)
	scene.call("_apply_portrait_layout", Vector2(900, 1950))

	var top_bar := scene.get_node("TopBar") as Control
	var main_area := scene.get_node("MainArea") as Control
	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var result := run_checks([
		assert_eq(backdrop.size, Vector2(900, 1950), "Portrait backdrop should still cover the full tall Android canvas"),
		assert_eq(frame_rect, Rect2(Vector2.ZERO, Vector2(900, 1950)), "Portrait layout should not reuse or create a stale inner content frame"),
		assert_eq(top_bar.offset_top, 4.0, "Portrait top bar should start from the real viewport safe top, not a centered inner frame"),
		assert_eq(main_area.position.y + main_area.size.y, 1950.0, "Portrait main area should consume the real tall screen height"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_layout_restores_top_actions_after_portrait() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var backdrop := TextureRect.new()
	backdrop.name = "BattleBackdrop"
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.add_child(backdrop)
	scene.move_child(backdrop, 0)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_set_portrait_huds_on_field_edges", false)
	scene.call("_sync_portrait_top_action_visibility", false)
	var controller := BattleLayoutControllerScript.new()
	controller.call("apply_backdrop_rect", backdrop, Vector2(1600, 900), 180.0)
	scene.call("_apply_landscape_layout", Vector2(1600, 900))
	scene.call("_style_end_turn_hud_buttons")

	var more_button := scene.find_child("BtnBattleMore", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false) as Button
	var my_vstar_panel := scene.find_child("InfoMyVstar", true, false) as Control
	var my_lost_panel := scene.find_child("InfoMyLost", true, false) as Control
	var opp_vstar_panel := scene.find_child("InfoEnemyVstar", true, false) as Control
	var opp_lost_panel := scene.find_child("InfoEnemyLost", true, false) as Control
	var my_vstar_image := my_vstar_panel.find_child("HudImageTexture", true, false) as TextureRect if my_vstar_panel != null else null
	var my_pile_vbox := scene.find_child("MyHudRightVBox", true, false) as VBoxContainer
	var opp_pile_vbox := scene.find_child("OppHudRightVBox", true, false) as VBoxContainer
	var my_pile_stack := scene.find_child("MyHudDataRow", true, false) as HBoxContainer
	var opp_pile_stack := scene.find_child("OppHudDataRow", true, false) as HBoxContainer
	var my_status_stack := scene.find_child("MyLandscapeStatusStack", true, false) as VBoxContainer
	var opp_status_stack := scene.find_child("OppLandscapeStatusStack", true, false) as VBoxContainer
	var my_status_slot := scene.find_child("MyLandscapeStatusSlot", true, false) as CenterContainer
	var opp_status_slot := scene.find_child("OppLandscapeStatusSlot", true, false) as CenterContainer
	var my_status_spacer := scene.find_child("MyLandscapeStatusLeftSpacer", true, false) as Control
	var opp_status_spacer := scene.find_child("OppLandscapeStatusLeftSpacer", true, false) as Control
	var my_active_row := scene.find_child("MyActiveRow", true, false) as HBoxContainer
	var opp_active_row := scene.find_child("OppActiveRow", true, false) as HBoxContainer
	var my_active_card := scene.find_child("MyActive", true, false) as Control
	var stadium_bar := scene.find_child("StadiumBar", true, false) as Control
	var stadium_sections := scene.find_child("StadiumSections", true, false) as HBoxContainer
	var stadium_center := scene.find_child("StadiumCenterSection", true, false) as Control
	var landscape_stadium_left_spacer := scene.find_child("LandscapeStadiumLeftSpacer", true, false) as Control
	var stadium_spacer := scene.find_child("LostZoneSection", true, false) as Control
	var info_columns := scene.find_child("InfoColumns", true, false) as HBoxContainer
	var turn_action_column := scene.find_child("TurnActionColumn", true, false) as Control
	var hud_end_turn_button := scene.find_child("HudEndTurnBtn", true, false) as Button
	var vstar_section := scene.find_child("VstarSection", true, false) as Control
	var my_vstar_value := scene.find_child("MyVstarValue", true, false) as Label
	var my_lost_value := scene.find_child("MyLostValue", true, false) as Label
	var my_deck_value := scene.find_child("MyDeckHudValue", true, false) as Label
	var stadium_label := scene.find_child("StadiumLbl", true, false) as Label
	var stadium_button := scene.find_child("BtnStadiumAction", true, false) as Button
	var stadium_section_gap := float(stadium_sections.get_theme_constant("separation")) if stadium_sections != null else 0.0
	var left_panel := scene.find_child("LeftPanel", true, false) as Control
	var right_panel := scene.find_child("RightPanel", true, false) as Control
	var log_panel := scene.find_child("LogPanel", true, false) as Control
	var landscape_side_width := 0.0 if left_panel == null or not left_panel.visible else clampf(1600.0 * 0.05, 72.0, 108.0)
	var landscape_right_width := 0.0 if right_panel == null or not right_panel.visible else landscape_side_width + 6.0
	var landscape_log_width := 0.0 if log_panel == null or not log_panel.visible else clampf(1600.0 * 0.15, 144.0, 252.0)
	var landscape_center_width := 1600.0 - landscape_side_width - landscape_right_width - landscape_log_width
	var landscape_bench_spacing := float(clampi(int(1600.0 * 0.004), 4, 10))
	var landscape_measured_variant: Variant = controller.call(
		"measure_card_layout",
		Vector2(1600, 900),
		landscape_center_width,
		landscape_bench_spacing,
		5,
		0.716
	)
	var landscape_measured: Dictionary = landscape_measured_variant if landscape_measured_variant is Dictionary else {}
	var landscape_prize_slot_size: Vector2 = landscape_measured.get("prize_slot_size", Vector2.ZERO)
	var landscape_preview_card_size: Vector2 = landscape_measured.get("preview_card_size", Vector2.ZERO)
	var expected_lost_width: float = float(scene.call("_landscape_pile_lost_panel_width", landscape_preview_card_size))
	var expected_status_slot_width: float = float(scene.call("_landscape_status_side_column_width", my_active_card.custom_minimum_size if my_active_card != null else Vector2.ZERO, my_vstar_panel.custom_minimum_size.x if my_vstar_panel != null else 0.0))
	var expected_stadium_left_spacer_width := roundf(landscape_prize_slot_size.x * 3.0)
	var expected_stadium_center_x := (
		expected_stadium_left_spacer_width
		+ stadium_section_gap
		+ (stadium_center.custom_minimum_size.x if stadium_center != null else 0.0) * 0.5
	)
	var vstar_aspect := my_vstar_image.texture.get_size().x / my_vstar_image.texture.get_size().y if my_vstar_image != null and my_vstar_image.texture != null else 0.0
	var actual_stadium_center_x := (
		landscape_stadium_left_spacer.custom_minimum_size.x
		+ stadium_section_gap
		+ stadium_center.custom_minimum_size.x * 0.5
	) if landscape_stadium_left_spacer != null and stadium_center != null else -1.0

	var result := run_checks([
		assert_true(more_button != null and not more_button.visible, "Landscape layout should hide the portrait more button"),
		assert_true(back_button != null and back_button.visible, "Landscape layout should restore the exit button"),
		assert_true(discuss_button != null and discuss_button.visible, "Landscape layout should restore AI discussion when it was visible before portrait"),
		assert_true(vstar_section != null and not vstar_section.visible, "Landscape layout should hide the old central status section once VSTAR moves beside active Pokemon"),
		assert_true(turn_action_column != null and stadium_sections != null and turn_action_column.get_parent() == stadium_sections, "Landscape layout should put the end-turn column directly in the stadium row"),
		assert_true(my_status_slot != null and my_active_row != null and my_status_slot.get_parent() == my_active_row, "Landscape layout should reserve a right-side slot for self VSTAR beside the active Pokemon"),
		assert_true(opp_status_slot != null and opp_active_row != null and opp_status_slot.get_parent() == opp_active_row, "Landscape layout should reserve a right-side slot for opponent VSTAR beside the active Pokemon"),
		assert_true(my_status_stack != null and my_status_slot != null and my_status_stack.get_parent() == my_status_slot, "Landscape self VSTAR stack should be centered inside its right-side slot"),
		assert_true(opp_status_stack != null and opp_status_slot != null and opp_status_stack.get_parent() == opp_status_slot, "Landscape opponent VSTAR stack should be centered inside its right-side slot"),
		assert_eq(my_status_spacer.custom_minimum_size.x if my_status_spacer != null else -1.0, my_status_slot.custom_minimum_size.x if my_status_slot != null else -2.0, "Landscape self active card should stay centered by balancing the right-side status slot with a left spacer"),
		assert_eq(opp_status_spacer.custom_minimum_size.x if opp_status_spacer != null else -1.0, opp_status_slot.custom_minimum_size.x if opp_status_slot != null else -2.0, "Landscape opponent active card should stay centered by balancing the right-side status slot with a left spacer"),
		assert_true(my_vstar_panel != null and my_status_stack != null and my_vstar_panel.get_parent() == my_status_stack, "Landscape layout should put self VSTAR in the active-row stack"),
		assert_true(opp_vstar_panel != null and opp_status_stack != null and opp_vstar_panel.get_parent() == opp_status_stack, "Landscape layout should put opponent VSTAR in the active-row stack"),
		assert_true(my_lost_panel != null and my_pile_vbox != null and my_lost_panel.get_parent() == my_pile_vbox, "Landscape layout should put self lost-zone below deck/discard HUD"),
		assert_true(opp_lost_panel != null and opp_pile_vbox != null and opp_lost_panel.get_parent() == opp_pile_vbox, "Landscape layout should put opponent lost-zone above deck/discard HUD"),
		assert_true(my_lost_panel != null and my_pile_stack != null and my_lost_panel.get_index() == my_pile_stack.get_index() + 1, "Landscape self lost-zone should sit directly below deck/discard"),
		assert_true(opp_lost_panel != null and opp_pile_stack != null and opp_lost_panel.get_index() + 1 == opp_pile_stack.get_index(), "Landscape opponent lost-zone should sit directly above deck/discard"),
		assert_true(stadium_center != null and stadium_center.custom_minimum_size.x <= 420.0, "Landscape stadium center should stay compact instead of stretching across the battlefield"),
		assert_true(landscape_stadium_left_spacer != null and landscape_stadium_left_spacer.visible and landscape_stadium_left_spacer.get_parent() == stadium_sections, "Landscape stadium row should include a left anchor spacer before the stadium HUD"),
		assert_true(landscape_stadium_left_spacer != null and stadium_center != null and landscape_stadium_left_spacer.get_index() < stadium_center.get_index(), "Landscape stadium anchor spacer should sit before the stadium HUD"),
		assert_true(absf(landscape_stadium_left_spacer.custom_minimum_size.x - expected_stadium_left_spacer_width) <= 1.0 if landscape_stadium_left_spacer != null else false, "Landscape stadium anchor spacer should match the prize HUD grid width: actual %.1f expected %.1f" % [landscape_stadium_left_spacer.custom_minimum_size.x if landscape_stadium_left_spacer != null else -1.0, expected_stadium_left_spacer_width]),
		assert_true(absf(actual_stadium_center_x - expected_stadium_center_x) <= 1.0, "Landscape stadium HUD center should be anchored after the prize HUD width: actual %.1f expected %.1f" % [actual_stadium_center_x, expected_stadium_center_x]),
		assert_eq(stadium_spacer.size_flags_horizontal if stadium_spacer != null else -1, Control.SIZE_EXPAND_FILL, "Landscape stadium row should use the old lost-zone slot as flexible space between stadium and end-turn"),
		assert_eq(turn_action_column.size_flags_horizontal if turn_action_column != null else -1, Control.SIZE_SHRINK_END, "Landscape end-turn column should anchor to the right edge of the stadium row"),
		assert_true(stadium_spacer != null and turn_action_column != null and stadium_spacer.get_index() < turn_action_column.get_index(), "Landscape flexible spacer should sit before the end-turn column so it pushes the button right"),
		assert_eq(stadium_sections.alignment if stadium_sections != null else -1, BoxContainer.ALIGNMENT_BEGIN, "Landscape stadium row should keep deterministic left-to-right anchoring"),
		assert_true(my_status_slot != null and absf(my_status_slot.custom_minimum_size.x - expected_status_slot_width) <= 1.0, "Landscape VSTAR slot should use the active-card distance target: actual %.1f expected %.1f" % [my_status_slot.custom_minimum_size.x if my_status_slot != null else -1.0, expected_status_slot_width]),
		assert_true(my_vstar_panel != null and my_vstar_panel.custom_minimum_size.y > 31.0 and my_vstar_panel.custom_minimum_size.y <= 62.0, "Landscape VSTAR HUD should use the landscape-only doubled image height"),
		assert_true(my_vstar_image != null and my_vstar_image.texture != null, "Landscape VSTAR HUD should render the PNG"),
		assert_true(my_vstar_panel != null and vstar_aspect > 0.0 and absf(my_vstar_panel.custom_minimum_size.x - my_vstar_panel.custom_minimum_size.y * vstar_aspect) <= 1.0, "Landscape VSTAR HUD width should preserve the PNG aspect ratio"),
		assert_true(my_vstar_value != null and not my_vstar_value.visible, "Landscape VSTAR text should be hidden because the PNG carries the label"),
		assert_eq(my_lost_value.get_theme_font_size("font_size") if my_lost_value != null else -1, my_deck_value.get_theme_font_size("font_size") if my_deck_value != null else -2, "Landscape lost-zone HUD text should match the deck/discard count text size"),
		assert_true(my_lost_panel != null and absf(my_lost_panel.custom_minimum_size.x - expected_lost_width) <= 1.0, "Landscape self LOST width should match the pile row width"),
		assert_true(opp_lost_panel != null and absf(opp_lost_panel.custom_minimum_size.x - expected_lost_width) <= 1.0, "Landscape opponent LOST width should match the pile row width"),
		assert_true(hud_end_turn_button != null and absf(hud_end_turn_button.custom_minimum_size.x - expected_lost_width) <= 1.0, "Landscape end-turn button width should match LOST width"),
		assert_true(turn_action_column != null and absf(turn_action_column.custom_minimum_size.x - expected_lost_width) <= 1.0, "Landscape end-turn column should align to LOST width"),
		assert_true(hud_end_turn_button != null and hud_end_turn_button.custom_minimum_size.y <= 31.0, "Landscape end-turn button should be 30 percent shorter than the previous 44px HUD target"),
		assert_true(hud_end_turn_button != null and hud_end_turn_button.get_theme_font_size("font_size") >= 16, "Landscape end-turn text should be 30 percent larger and centered in the shorter button"),
		assert_true(stadium_label != null and stadium_label.custom_minimum_size.y <= 31.0 and stadium_label.get_theme_font_size("font_size") >= 16, "Landscape stadium label should match the shorter larger-text HUD button metrics"),
		assert_true(stadium_button != null and stadium_button.custom_minimum_size.y <= 31.0 and stadium_button.get_theme_font_size("font_size") >= 16, "Landscape stadium action button should match the shorter larger-text HUD button metrics"),
		assert_true(stadium_bar != null and hud_end_turn_button != null and stadium_bar.custom_minimum_size.y >= hud_end_turn_button.custom_minimum_size.y, "Landscape stadium bar should be tall enough to contain the end-turn button"),
		assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_SCALE, "Landscape layout should restore the legacy stretched backdrop mode"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_stadium_card_uses_floating_active_size_overlay() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_landscape_layout", Vector2(1600, 900))

	var stadium_bar := scene.find_child("StadiumBar", true, false) as Control
	var hand_area := scene.find_child("HandArea", true, false) as Control
	var stadium_row := scene.find_child("StadiumActionRow", true, false) as Control
	var active_card := scene.find_child("MyActive", true, false) as Control
	var stadium_bar_height := stadium_bar.custom_minimum_size.y if stadium_bar != null else -1.0
	var hand_area_height := hand_area.custom_minimum_size.y if hand_area != null else -1.0
	var active_size := active_card.custom_minimum_size if active_card != null else Vector2.ZERO

	var stadium_card := scene.call("_ensure_stadium_card_view") as Control
	scene.call("_apply_stadium_card_view_metrics", active_size.x, active_size.y)
	if stadium_card != null:
		stadium_card.visible = true
	scene.call("_position_stadium_card_view")
	var overlay := scene.find_child("StadiumCardOverlay", true, false) as Control

	var result := run_checks([
		assert_true(stadium_card != null and overlay != null and stadium_card.get_parent() == overlay, "Stadium card should live in a root overlay instead of the stadium HUD row"),
		assert_false(stadium_row != null and stadium_card != null and stadium_row.is_ancestor_of(stadium_card), "Stadium card must not participate in StadiumActionRow layout sizing"),
		assert_true(stadium_card != null and active_size != Vector2.ZERO and stadium_card.custom_minimum_size == active_size, "Stadium card should use the same size as active battle Pokemon"),
		assert_eq(stadium_bar.custom_minimum_size.y if stadium_bar != null else -2.0, stadium_bar_height, "Floating stadium card must not change StadiumBar height"),
		assert_eq(hand_area.custom_minimum_size.y if hand_area != null else -2.0, hand_area_height, "Floating stadium card must not push the hand area down"),
	])
	scene.queue_free()
	return result


func test_portrait_empty_stadium_hud_uses_zone_label() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var gsm := GameStateMachine.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	scene.call("_refresh_stadium_card_hud", gsm.game_state, 0, true)
	var label := scene.find_child("StadiumLbl", true, false) as Label

	var result := run_checks([
		assert_true(label != null and label.visible, "Portrait empty Stadium HUD should keep a visible zone label"),
		assert_eq(label.text if label != null else "", "竞技场区", "Portrait empty Stadium HUD should use the compact zone label"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_stadium_card_preview_uses_two_thirds_active_height() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var active_card := scene.find_child("MyActive", true, false) as Control
	var active_size := active_card.custom_minimum_size if active_card != null else Vector2.ZERO
	var gsm := GameStateMachine.new()
	var stadium := CardInstance.create(_make_stadium_card("Portrait Stadium"), 0)
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	scene.call("_refresh_stadium_card_hud", gsm.game_state, 0, true)
	var card_view := scene.get("_stadium_card_view") as Control
	var overlay := scene.find_child("StadiumCardOverlay", true, false) as Control
	var frame_rect: Rect2 = scene.get("_portrait_layout_frame_rect")
	var expected_size := active_size * (2.0 / 3.0)

	var result := run_checks([
		assert_true(card_view != null and card_view.visible, "Portrait Stadium card preview should be visible when a Stadium is in play"),
		assert_eq(overlay.size if overlay != null else Vector2.ZERO, frame_rect.size, "Portrait Stadium card overlay should follow the active portrait frame"),
		assert_true(active_size != Vector2.ZERO and card_view != null and absf(card_view.custom_minimum_size.y - expected_size.y) <= 1.0, "Portrait Stadium card preview height should be two thirds of the active-card height"),
		assert_true(active_size != Vector2.ZERO and card_view != null and absf(card_view.custom_minimum_size.x - expected_size.x) <= 1.0, "Portrait Stadium card preview width should scale with the reduced height"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_modal_raise_order_keeps_first_prompt_clickable_after_portrait_z_order() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var dialog_overlay := scene.find_child("DialogOverlay", true, false) as Control
	var handover_panel := scene.find_child("HandoverPanel", true, false) as Control
	if dialog_overlay != null:
		dialog_overlay.visible = true
	if handover_panel != null:
		handover_panel.visible = true
	var portrait_handover_above := handover_panel != null and dialog_overlay != null and handover_panel.z_index > dialog_overlay.z_index

	scene.call("_raise_dialog_overlay_for_input")
	var dialog_above_stale_handover := dialog_overlay != null and handover_panel != null and dialog_overlay.z_index > handover_panel.z_index
	var dialog_last_after_raise := dialog_overlay != null and dialog_overlay.get_parent() != null and dialog_overlay.get_index() == dialog_overlay.get_parent().get_child_count() - 1

	scene.call("_raise_handover_overlay_for_input")
	var handover_above_stale_dialog := dialog_overlay != null and handover_panel != null and handover_panel.z_index > dialog_overlay.z_index
	var handover_last_after_raise := handover_panel != null and handover_panel.get_parent() != null and handover_panel.get_index() == handover_panel.get_parent().get_child_count() - 1

	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	if dialog_overlay != null:
		dialog_overlay.visible = true
	if handover_panel != null:
		handover_panel.visible = false
	scene.call("_apply_landscape_layout", Vector2(1600, 900))
	var landscape_dialog_above_handover := dialog_overlay != null and handover_panel != null and dialog_overlay.z_index > handover_panel.z_index

	var result := run_checks([
		assert_true(portrait_handover_above, "Portrait layout may put handover above dialog while handover is the active modal"),
		assert_true(dialog_above_stale_handover, "Showing a dialog should raise it above any stale handover blocker"),
		assert_true(dialog_last_after_raise, "Showing a dialog should move it to the end of the root child order so later overlays cannot intercept input"),
		assert_true(handover_above_stale_dialog, "Showing a handover prompt should raise it above any stale dialog blocker"),
		assert_true(handover_last_after_raise, "Showing a handover prompt should move it to the end of the root child order so later overlays cannot intercept input"),
		assert_true(landscape_dialog_above_handover, "Landscape layout should restore dialog above inactive handover overlays"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_landscape_pile_hud_uses_horizontal_compact_rows() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_landscape_pile_hud_metrics", Vector2(64, 90))

	var my_row := scene.find_child("MyHudDataRow", true, false) as HBoxContainer
	var opp_row := scene.find_child("OppHudDataRow", true, false) as HBoxContainer
	var my_hud := scene.find_child("MyHudRight", true, false) as Control
	var opp_hud := scene.find_child("OppHudRight", true, false) as Control
	var my_deck_panel := scene.find_child("MyDeckHudPanel", true, false) as Control
	var my_discard_panel := scene.find_child("MyDiscardHudPanel", true, false) as Control
	var my_lost_panel := scene.find_child("InfoMyLost", true, false) as Control
	var opp_lost_panel := scene.find_child("InfoEnemyLost", true, false) as Control

	var result := run_checks([
		assert_not_null(my_row, "Landscape layout should render self deck/discard in a horizontal row"),
		assert_not_null(opp_row, "Landscape layout should render opponent deck/discard in a horizontal row"),
		assert_true(my_row != null and my_row.get_child_count() == 2, "Self landscape pile row should contain deck and discard panels side by side"),
		assert_true(opp_row != null and opp_row.get_child_count() == 2, "Opponent landscape pile row should contain deck and discard panels side by side"),
		assert_eq(my_hud.size_flags_horizontal if my_hud != null else -1, Control.SIZE_SHRINK_CENTER, "Self landscape pile HUD should not consume expandable field width"),
		assert_eq(opp_hud.size_flags_horizontal if opp_hud != null else -1, Control.SIZE_SHRINK_CENTER, "Opponent landscape pile HUD should not consume expandable field width"),
		assert_true(my_hud != null and my_hud.custom_minimum_size.x <= 160.0, "Self landscape pile HUD should only reserve the compact width needed for two pile previews"),
		assert_true(my_lost_panel != null and my_row != null and my_lost_panel.get_index() == my_row.get_index() + 1, "Self landscape lost-zone should sit below deck/discard"),
		assert_true(opp_lost_panel != null and opp_row != null and opp_lost_panel.get_index() + 1 == opp_row.get_index(), "Opponent landscape lost-zone should sit above deck/discard"),
		assert_eq(my_deck_panel.size_flags_horizontal if my_deck_panel != null else -1, Control.SIZE_SHRINK_CENTER, "Deck panel should shrink to its preview content"),
		assert_eq(my_discard_panel.size_flags_horizontal if my_discard_panel != null else -1, Control.SIZE_SHRINK_CENTER, "Discard panel should shrink to its preview content"),
	])

	scene.queue_free()
	return result


func test_portrait_pile_hud_uses_horizontal_card_preview_rows_after_landscape() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_landscape_pile_hud_metrics", Vector2(64, 90))
	scene.call("_apply_portrait_field_hud_metrics", Vector2(390, 844), Vector2(72, 100), Vector2(122, 170))

	var my_row := scene.find_child("MyHudDataRow", true, false) as HBoxContainer
	var opp_row := scene.find_child("OppHudDataRow", true, false) as HBoxContainer
	var my_deck_panel := scene.find_child("MyDeckHudPanel", true, false) as Control
	var my_discard_panel := scene.find_child("MyDiscardHudPanel", true, false) as Control
	var my_hud := scene.find_child("MyHudRight", true, false) as Control

	var result := run_checks([
		assert_not_null(my_row, "Portrait layout should keep self deck/discard in a horizontal card-preview row"),
		assert_not_null(opp_row, "Portrait layout should keep opponent deck/discard in a horizontal card-preview row"),
		assert_true(my_row != null and my_row.get_child_count() == 2, "Self portrait pile row should keep both pile panels side by side"),
		assert_true(opp_row != null and opp_row.get_child_count() == 2, "Opponent portrait pile row should keep both pile panels side by side"),
		assert_true(my_deck_panel != null and my_discard_panel != null and my_hud != null and my_hud.custom_minimum_size.x >= my_deck_panel.custom_minimum_size.x + my_discard_panel.custom_minimum_size.x, "Portrait pile HUD should reserve enough width for both preview panels"),
	])

	scene.queue_free()
	return result


func test_portrait_top_action_restore_keeps_original_visibility_after_repeated_layouts() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_sync_portrait_top_action_visibility", false)

	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button

	var result := run_checks([
		assert_true(discuss_button != null and discuss_button.visible, "Repeated portrait relayouts should not overwrite the stored landscape visibility"),
		assert_true(back_button != null and back_button.visible, "Exit should stay visible after repeated portrait relayouts"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_review_top_actions_keep_replay_controls_visible() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	var prev_button := scene.find_child("BtnReplayPrevTurn", true, false) as Button
	var next_button := scene.find_child("BtnReplayNextTurn", true, false) as Button
	var continue_button := scene.find_child("BtnReplayContinue", true, false) as Button
	var list_button := scene.find_child("BtnReplayBackToList", true, false) as Button
	var back_button := scene.find_child("BtnBack", true, false) as Button
	var opponent_hand_button := scene.find_child("BtnOpponentHand", true, false) as Button
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false) as Button
	var zeus_button := scene.find_child("BtnZeusHelp", true, false) as Button
	var refs: RefCounted = scene.get("_battle_scene_refs")
	if refs != null:
		refs.call("bind_replay_buttons", prev_button, next_button, continue_button, list_button)
	scene.set("_battle_mode", "review_readonly")
	var turn_numbers: Array = scene.get("_replay_turn_numbers")
	turn_numbers.clear()
	turn_numbers.append_array([1, 2, 3])
	scene.set("_replay_current_turn_index", 1)
	scene.set("_replay_loaded_raw_snapshot", {"turn": 2})
	scene.call("_refresh_replay_controls")
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var result := run_checks([
		assert_true(prev_button != null and prev_button.visible, "Portrait replay mode should show the previous-turn button"),
		assert_true(next_button != null and next_button.visible, "Portrait replay mode should show the next-turn button"),
		assert_true(continue_button != null and continue_button.visible, "Portrait replay mode should show the continue-from-here button"),
		assert_true(list_button != null and list_button.visible, "Portrait replay mode should show the back-to-replay-list button"),
		assert_true(back_button != null and back_button.visible, "Portrait replay mode should keep Exit visible"),
		assert_eq(prev_button.text if prev_button != null else "", "上回合", "Portrait replay previous button should use the compact label"),
		assert_eq(next_button.text if next_button != null else "", "下回合", "Portrait replay next button should use the compact label"),
		assert_eq(continue_button.text if continue_button != null else "", "继续", "Portrait replay continue button should use the compact label"),
		assert_eq(list_button.text if list_button != null else "", "列表", "Portrait replay list button should use the compact label"),
		assert_true(opponent_hand_button == null or not opponent_hand_button.visible, "Portrait replay mode should hide live opponent-hand actions"),
		assert_true(discuss_button == null or not discuss_button.visible, "Portrait replay mode should hide live AI discussion actions"),
		assert_true(zeus_button == null or not zeus_button.visible, "Portrait replay mode should hide live Zeus actions"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_bench_grid_fallback_targets_first_empty_bench_slot() -> String:
	var scene: Control = BattleScene.instantiate()
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Active %d" % player_index), player_index))
		player.active_pokemon = active_slot
		game_state.players.append(player)
	game_state.current_player_index = 0
	game_state.turn_number = 1
	game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state = game_state
	scene.set("_gsm", gsm)
	var first_empty := str(scene.call("_first_empty_own_bench_slot_id"))
	var occupied_slot := PokemonSlot.new()
	occupied_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_card("Occupied Bench"), 0))
	game_state.players[0].bench.append(occupied_slot)
	var second_empty := str(scene.call("_first_empty_own_bench_slot_id"))

	var result := run_checks([
		assert_eq(first_empty, "my_bench_0", "Portrait bench grid fallback should target the first empty bench slot"),
		assert_eq(second_empty, "my_bench_1", "Portrait bench grid fallback should advance past occupied bench slots"),
	])

	scene.queue_free()
	return result


func test_rotated_portrait_screen_position_maps_to_logical_canvas() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_battle_canvas_transform", true, Vector2(1600, 900), Vector2(900, 1600))

	var logical_position: Vector2 = scene.call("_screen_position_to_battle_local", Vector2(560, 360))
	var result := run_checks([
		assert_eq(logical_position, Vector2(360, 1040), "Rotated portrait input should invert the 90-degree canvas transform"),
	])

	scene.queue_free()
	return result


func test_rotated_portrait_hand_drag_uses_logical_hand_axis() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_battle_canvas_transform", true, Vector2(1600, 900), Vector2(900, 1600))
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.size = Vector2(868, 316)
	hand_scroll.custom_minimum_size = Vector2(868, 316)
	var hand_content := HBoxContainer.new()
	hand_content.custom_minimum_size = Vector2(1185, 222)
	hand_scroll.add_child(hand_content)
	scene.add_child(hand_scroll)
	scene.set("_hand_scroll", hand_scroll)
	scene.call("_setup_hand_drag_scroll")

	var hbar := hand_scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.min_value = 0.0
		hbar.max_value = 1185.0
		hbar.page = 868.0

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(220, 453)
	scene.call("_handle_hand_drag_scroll_input", press, "test")

	var drag := InputEventMouseMotion.new()
	drag.global_position = Vector2(279, 117)
	scene.call("_handle_hand_drag_scroll_input", drag, "test")
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(279, 117)
	scene.call("_handle_hand_drag_scroll_input", release, "test")

	var result := run_checks([
		assert_gt(scroll_after_drag, 250, "Rotated portrait hand drag should use the logical hand axis, not raw physical screen x"),
		assert_false(bool(scene.get("_hand_drag_active")), "Rotated portrait hand drag should end cleanly on release"),
	])
	scene.queue_free()
	return result


func test_rotated_portrait_bench_hit_uses_physical_screen_position() -> String:
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_battle_canvas_transform", true, Vector2(1600, 900), Vector2(900, 1600))
	var grid := VBoxContainer.new()
	grid.name = "PortraitMyBenchGrid"
	grid.position = Vector2(200, 900)
	grid.custom_minimum_size = Vector2(320, 300)
	grid.visible = true
	scene.add_child(grid)
	scene.set("_portrait_my_bench_grid", grid)

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		game_state.players.append(player)
	game_state.current_player_index = 0
	gsm.game_state = game_state
	scene.set("_gsm", gsm)

	var physical_center := Vector2(1600.0 - 1060.0, 360.0)
	var hit_slot := str(scene.call("_portrait_bench_grid_hit_slot_id_for_screen_position", physical_center))
	var miss_slot := str(scene.call("_portrait_bench_grid_hit_slot_id_for_screen_position", Vector2(40, 40)))

	var result := run_checks([
		assert_eq(hit_slot, "my_bench_0", "Rotated portrait bench taps should hit the visible grid after physical-to-logical mapping"),
		assert_eq(miss_slot, "", "Taps outside the visible portrait bench grid should not trigger a bench play"),
	])

	scene.queue_free()
	return result


func test_rotated_portrait_draw_reveal_anchor_uses_physical_screen_center() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.call("_apply_battle_canvas_transform", true, Vector2(1600, 900), Vector2(900, 1600))

	var rect: Rect2 = scene.call("_draw_reveal_anchor_rect")
	var controller := BattleDrawRevealControllerScript.new()
	var global_rect: Rect2 = controller.call("_get_reveal_anchor_rect", scene)
	var result := run_checks([
		assert_eq(rect.position, Vector2.ZERO, "Rotated portrait draw reveal should define the full logical portrait canvas as its local anchor"),
		assert_eq(rect.size, Vector2(900, 1600), "Rotated portrait draw reveal should use the logical portrait canvas before global conversion"),
		assert_eq(global_rect.position, Vector2.ZERO, "Rotated portrait reveal controller should convert the local anchor to the visible physical screen"),
		assert_eq(global_rect.size, Vector2(1600, 900), "Rotated portrait reveal controller should center on the visible physical screen"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_non_rotated_portrait_draw_reveal_anchor_uses_full_screen_center() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(900, 1600)

	var rect: Rect2 = scene.call("_draw_reveal_anchor_rect")
	var result := run_checks([
		assert_eq(rect.position, Vector2.ZERO, "Portrait draw reveal should anchor to the full visible screen"),
		assert_eq(rect.size, Vector2(900, 1600), "Portrait draw reveal should use full-screen center instead of the player-side field center"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_prize_hud_reappears_for_pending_prize_selection() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScene.instantiate()
	scene.set("_view_player", 0)
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", 0)
	scene.set("_pending_prize_remaining", 1)
	scene.call("_apply_portrait_layout", Vector2(390, 844))

	var my_prize_hud := scene.find_child("MyHudLeft", true, false) as Control
	var opp_prize_hud := scene.find_child("OppHudLeft", true, false) as Control
	var my_prize_host := scene.find_child("MyPrizeHudHost", true, false) as Control
	var opp_prize_host := scene.find_child("OppPrizeHudHost", true, false) as Control
	var dialog_overlay := scene.find_child("DialogOverlay", true, false) as Control
	var dialog_vbox := scene.find_child("DialogVBox", true, false) as VBoxContainer
	var dialog_buttons := scene.find_child("DialogButtons", true, false) as Control

	var result := run_checks([
		assert_true(my_prize_hud != null and my_prize_hud.visible, "Portrait layout should keep the selecting player's prize count HUD visible"),
		assert_true(opp_prize_hud != null and opp_prize_hud.visible, "Portrait layout should keep the non-selecting prize count HUD visible"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Portrait prize selection should open a centered dialog overlay"),
		assert_true(my_prize_host != null and my_prize_host.visible, "Portrait prize dialog should show the selecting player's prize cards"),
		assert_true(my_prize_host != null and dialog_vbox != null and my_prize_host.get_parent() == dialog_vbox, "Portrait prize cards should move from the edge HUD into the dialog"),
		assert_true(dialog_buttons != null and not dialog_buttons.visible, "Prize selection dialog should not expose cancel/confirm buttons"),
		assert_true(opp_prize_host != null and not opp_prize_host.visible, "Portrait layout should keep non-selecting prize cards hidden"),
	])

	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_prize_hud_stays_compact_during_area_zero_prize_selection() -> String:
	var scene := PortraitPrizeHudMetricSceneStub.new()
	var view := BattlePortraitLayoutView.new()
	view.setup(scene, BattleLayoutControllerScript.new())
	var viewport_size := Vector2(390, 844)
	var post_area_zero_bench_size := Vector2(74, 104)
	var active_size := Vector2(122, 170)
	view.call("apply_field_hud_metrics", viewport_size, post_area_zero_bench_size, active_size)
	var normal_my_height := scene._my_hud_left.custom_minimum_size.y
	var normal_opp_height := scene._opp_hud_left.custom_minimum_size.y

	scene._pending_choice = "take_prize"
	scene._pending_prize_remaining = 2
	view.call("apply_field_hud_metrics", viewport_size, post_area_zero_bench_size, active_size)
	var pending_my_height := scene._my_hud_left.custom_minimum_size.y
	var pending_opp_height := scene._opp_hud_left.custom_minimum_size.y

	var result := run_checks([
		assert_true(normal_my_height > 0.0 and normal_opp_height > 0.0, "Portrait prize HUD fixture should measure normal compact heights"),
		assert_true(absf(pending_my_height - normal_my_height) <= 0.5, "Self prize HUD should stay compact during Area Zero prize selection: %.1f -> %.1f" % [normal_my_height, pending_my_height]),
		assert_true(absf(pending_opp_height - normal_opp_height) <= 0.5, "Opponent prize HUD should stay compact during Area Zero prize selection: %.1f -> %.1f" % [normal_opp_height, pending_opp_height]),
	])

	scene.queue_free()
	return result
