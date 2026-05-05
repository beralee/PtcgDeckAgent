class_name TestHudScrollbarTheme
extends TestBase

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const HudScrollContainerScript := preload("res://scripts/ui/HudScrollContainer.gd")
const BattleSceneScript := preload("res://scenes/battle/BattleScene.gd")
const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")


func test_hud_theme_styles_touch_scroll_container_bars() -> String:
	var scroll := ScrollContainer.new()
	var content := Control.new()
	content.custom_minimum_size = Vector2(1200, 900)
	scroll.add_child(content)

	HudThemeScript.style_scroll_container(scroll, "touch")
	var vbar := scroll.get_v_scroll_bar()
	var hbar := scroll.get_h_scroll_bar()
	var h_grabber := hbar.get_theme_stylebox("grabber") as StyleBoxFlat
	var h_track := hbar.get_theme_stylebox("scroll") as StyleBoxFlat

	var result := run_checks([
		assert_true(scroll.has_meta("hud_scrollbar_styled"), "ScrollContainer should be tagged after HUD scrollbar styling"),
		assert_eq(str(vbar.get_meta("hud_scrollbar_profile", "")), "touch", "Vertical scrollbar should record touch profile"),
		assert_eq(str(hbar.get_meta("hud_scrollbar_profile", "")), "touch", "Horizontal scrollbar should record touch profile"),
		assert_gte(int(vbar.get_meta("hud_scrollbar_thickness", 0)), 32, "Touch vertical scrollbar should be wide enough for mobile dragging"),
		assert_gte(int(hbar.get_meta("hud_scrollbar_thickness", 0)), 32, "Touch horizontal scrollbar should be tall enough for mobile dragging"),
		assert_gte(int(vbar.get_meta("hud_scrollbar_minimum_grab", 0)), 64, "Touch vertical grabber should have a large minimum length"),
		assert_true(vbar.has_theme_stylebox_override("grabber"), "Vertical scrollbar should have a HUD grabber style"),
		assert_true(hbar.has_theme_stylebox_override("scroll"), "Horizontal scrollbar should have a HUD track style"),
		assert_true(h_grabber != null and h_grabber.bg_color.a <= 0.56, "Default scrollbar grabber should stay visually muted"),
		assert_true(h_track != null and h_track.bg_color.a <= 0.50, "Scrollbar track should not visually compete with cards"),
	])

	scroll.queue_free()
	return result


func test_hud_scroll_container_applies_style_on_ready() -> String:
	var scroll := HudScrollContainerScript.new()
	scroll.hud_scroll_profile = "touch"
	var content := Control.new()
	content.custom_minimum_size = Vector2(900, 900)
	scroll.add_child(content)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scroll)

	var vbar := scroll.get_v_scroll_bar()
	var result := run_checks([
		assert_true(scroll.has_meta("hud_scrollbar_styled"), "HudScrollContainer should self-apply shared styling"),
		assert_eq(str(vbar.get_meta("hud_scrollbar_profile", "")), "touch", "HudScrollContainer should pass its configured profile to internal bars"),
		assert_gte(vbar.custom_minimum_size.x, 32.0, "HudScrollContainer vertical bar should expose a mobile-sized drag target"),
	])

	scroll.queue_free()
	return result


func test_battle_setup_background_gallery_uses_hud_scrollbar_style() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_apply_hud_theme")

	var gallery := scene.find_child("BackgroundGallery", true, false) as ScrollContainer
	var hbar := gallery.get_h_scroll_bar() if gallery != null else null
	var result := run_checks([
		assert_not_null(gallery, "Battle setup should still expose the background gallery scroll area"),
		assert_true(gallery != null and gallery.has_meta("hud_scrollbar_styled"), "Battle setup gallery should receive shared HUD scrollbar styling"),
		assert_true(hbar != null and hbar.has_theme_stylebox_override("grabber"), "Battle setup gallery horizontal bar should use the HUD grabber"),
		assert_true(hbar != null and float(hbar.custom_minimum_size.y) >= 22.0, "Battle setup gallery horizontal drag target should be wider than the default theme"),
	])

	scene.queue_free()
	return result


func test_battle_card_scroll_height_reserves_touch_clearance() -> String:
	var scene := BattleSceneScript.new()
	var card_height := 128.0
	var expected_clearance := float(HudThemeScript.SCROLLBAR_TOUCH_THICKNESS + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING)
	var scroll_height := float(scene.call("_card_scroll_height_with_scrollbar", card_height))
	var result := run_checks([
		assert_eq(scroll_height, card_height + expected_clearance, "Card scroll areas should reserve touch scrollbar clearance below cards"),
		assert_gte(expected_clearance, 40.0, "Touch scrollbar clearance should be large enough to avoid covering card bottoms"),
	])
	scene.free()
	return result


func test_battle_hand_scroll_height_keeps_single_scrollbar_width_compact() -> String:
	var scene := BattleSceneScript.new()
	var card_height := 128.0
	var dialog_scroll_height := float(scene.call("_card_scroll_height_with_scrollbar", card_height))
	var hand_scroll_height := float(scene.call("_hand_scroll_height_with_scrollbar", card_height))
	var result := run_checks([
		assert_eq(dialog_scroll_height - hand_scroll_height, float(HudThemeScript.SCROLLBAR_TOUCH_THICKNESS), "Hand area should be one touch scrollbar width shorter than popup card scrollers"),
		assert_eq(hand_scroll_height, card_height + float(HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING), "Hand area should keep only a slim bottom clearance"),
	])
	scene.free()
	return result
