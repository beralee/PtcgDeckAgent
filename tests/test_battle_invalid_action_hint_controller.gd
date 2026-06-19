class_name TestBattleInvalidActionHintController
extends TestBase

const HintControllerScript := preload("res://scripts/ui/battle/BattleInvalidActionHintController.gd")


class HintHost:
	extends Control

	var _pending_choice := "kept_choice"
	var _dialog_data := {"kept": true}
	var _dialog_items_data := ["kept"]
	var _is_portrait_layout := false
	var styled_buttons: Array[Button] = []

	func _style_hud_button(button: Button) -> void:
		styled_buttons.append(button)

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass


class BattlePortraitHintHost:
	extends Control

	func _is_portrait_battle_layout_active() -> bool:
		return true

	func _portrait_dialog_viewport_size() -> Vector2:
		return Vector2(390, 844)

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass


func test_portrait_invalid_action_hint_keeps_close_button_above_hand_area() -> String:
	var host := BattlePortraitHintHost.new()
	host.name = "InvalidHintPortraitHost"
	host.size = Vector2(390, 844)
	var hand_area := Control.new()
	hand_area.name = "HandArea"
	hand_area.position = Vector2(0, 650)
	hand_area.size = Vector2(390, 194)
	host.add_child(hand_area)
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_hint({
		"title": "Cannot use now",
		"reason": "This action is blocked by the current battle state. ".repeat(8),
		"detail": "Check the active Pokemon, attached cards, and turn restrictions before choosing another action. ".repeat(8),
		"hint": "Tap the confirmation button to return to the battle.",
	})

	var box := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox") as PanelContainer
	var title := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var detail := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionDetail") as Label
	var hint := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionHint") as Label
	var close_button := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionFooter/InvalidActionCloseButton") as Button
	var box_height := box.size.y if box != null and box.size.y > 0.0 else (box.custom_minimum_size.y if box != null else 0.0)
	var close_bottom := box.position.y + box_height if box != null else 99999.0
	var hand_top := hand_area.global_position.y
	var result := run_checks([
		assert_true(box != null and box_height > 0.0, "Portrait invalid hint box should have an explicit touch-safe layout height"),
		assert_true(title != null and title.visible and title.text.strip_edges() != "" and title.custom_minimum_size.y > 0.0, "Portrait invalid hint title should reserve visible height"),
		assert_true(reason != null and reason.visible and reason.text.strip_edges() != "" and reason.custom_minimum_size.y > 0.0, "Portrait invalid hint reason should reserve visible height"),
		assert_true(detail != null and detail.visible and detail.text.strip_edges() != "" and detail.custom_minimum_size.y > 0.0, "Portrait invalid hint detail should reserve visible height"),
		assert_true(hint != null and hint.visible and hint.text.strip_edges() != "" and hint.custom_minimum_size.y > 0.0, "Portrait invalid hint hint text should reserve visible height"),
		assert_true(close_button != null and close_button.custom_minimum_size.y > 0.0, "Portrait invalid hint close button should keep a visible touch target"),
		assert_true(close_bottom <= hand_top - 8.0, "Portrait invalid hint close button must stay above the hand area instead of being pushed below it"),
	])
	host.queue_free()
	return result


func test_invalid_action_hint_renders_payload_and_hides() -> String:
	var host := HintHost.new()
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_hint({
		"title": "巢穴球现在不能使用",
		"reason": "你的备战区已经满了。",
		"detail": "巢穴球需要从牌库选择基础宝可梦。",
		"hint": "先让备战区空出位置。",
	})

	var overlay := host.get_node_or_null("InvalidActionOverlay") as Control
	var title := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var detail := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionDetail") as Label
	var hint := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionHint") as Label

	var pending_before: String = host._pending_choice
	var data_before: Dictionary = host._dialog_data.duplicate(true)
	controller.hide_hint()

	return run_checks([
		assert_not_null(overlay, "Invalid action overlay should be created dynamically"),
		assert_eq(title.text, "巢穴球现在不能使用", "Title should render payload text"),
		assert_eq(reason.text, "你的备战区已经满了。", "Reason should render payload text"),
		assert_eq(detail.text, "巢穴球需要从牌库选择基础宝可梦。", "Detail should render payload text"),
		assert_eq(hint.text, "先让备战区空出位置。", "Hint should render payload text"),
		assert_eq(pending_before, "kept_choice", "Showing hint should not change pending choice"),
		assert_eq(host._dialog_data, data_before, "Showing hint should not mutate dialog data"),
		assert_false(overlay.visible, "hide_hint should hide the overlay"),
	])


func test_invalid_action_hint_accepts_plain_reason() -> String:
	var host := HintHost.new()
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_reason("本回合已经附着过能量。", "能量不能附着")
	var title := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	return run_checks([
		assert_eq(title.text, "能量不能附着", "Plain reason title should be configurable"),
		assert_eq(reason.text, "本回合已经附着过能量。", "Plain reason should be rendered"),
	])


func test_landscape_invalid_action_hint_stays_compact_with_long_text() -> String:
	var host := HintHost.new()
	host.size = Vector2(1280, 720)
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_hint({
		"title": "Cannot use now",
		"reason": "This action is blocked by the current battle state. ".repeat(8),
		"detail": "Check the active Pokemon, attached cards, and turn restrictions before choosing another action. ".repeat(8),
		"hint": "Tap the confirmation button to return to the battle.",
	})

	var box := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox") as PanelContainer
	var title := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var detail := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionDetail") as Label
	var box_height := box.size.y if box != null and box.size.y > 0.0 else (box.custom_minimum_size.y if box != null else 99999.0)
	return run_checks([
		assert_true(box != null and box_height <= 260.0, "Landscape invalid hint should stay compact instead of inheriting portrait wrapping: height %.1f" % box_height),
		assert_true(title != null and title.clip_text and title.max_lines_visible == 1 and title.custom_minimum_size.y > 0.0, "Landscape invalid hint title should use compact one-line sizing"),
		assert_true(reason != null and reason.clip_text and reason.max_lines_visible == 1 and reason.custom_minimum_size.y > 0.0, "Landscape invalid hint reason should use compact one-line sizing"),
		assert_true(detail != null and detail.clip_text and detail.max_lines_visible == 1 and detail.custom_minimum_size.y > 0.0, "Landscape invalid hint detail should use compact one-line sizing"),
	])


func test_landscape_invalid_action_hint_final_layout_stays_inside_viewport_after_frame() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree is required for the post-layout regression"
	var host := HintHost.new()
	host.name = "InvalidHintLandscapeHost"
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_hint({
		"title": "Cannot use now",
		"reason": "This action is blocked by the current battle state. ".repeat(16),
		"detail": "Check the active Pokemon, attached cards, turn restrictions, and action source before choosing another action. ".repeat(14),
		"hint": "Tap the confirmation button to return to the battle.",
	})
	await tree.process_frame
	await tree.process_frame

	var overlay := host.get_node_or_null("InvalidActionOverlay") as Control
	var box := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox") as PanelContainer
	var title := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var detail := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionDetail") as Label
	var box_rect := Rect2(box.global_position, box.size) if box != null else Rect2(Vector2.ZERO, Vector2(99999, 99999))
	var viewport_rect := Rect2(Vector2.ZERO, host.size)
	var result := run_checks([
		assert_true(overlay != null and overlay.visible and overlay.size == host.size, "Landscape invalid hint overlay should fill the host viewport after layout"),
		assert_true(box != null and box_rect.position.x >= 24.0 and box_rect.position.y >= 24.0, "Landscape invalid hint should keep screen margins after container sorting: %s" % str(box_rect)),
		assert_true(box != null and box_rect.end.x <= viewport_rect.end.x - 24.0 and box_rect.end.y <= viewport_rect.end.y - 24.0, "Landscape invalid hint must stay inside the viewport after container sorting: %s in %s" % [str(box_rect), str(viewport_rect)]),
		assert_true(box != null and box.size.y <= 260.0, "Landscape invalid hint should remain compact after container sorting, not grow into a portrait-height modal: %.1f" % (box.size.y if box != null else 0.0)),
		assert_true(title != null and title.visible and title.size.y > 0.0, "Landscape title should remain visible after compact layout"),
		assert_true(reason != null and reason.visible and reason.size.y > 0.0, "Landscape reason should remain visible after compact layout"),
		assert_true(detail != null and detail.visible and detail.size.y > 0.0, "Landscape detail should remain visible after compact layout"),
	])
	host.queue_free()
	return result


func test_portrait_invalid_action_hint_metrics_use_touch_scale() -> String:
	var host := HintHost.new()
	host._is_portrait_layout = true
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_hint({
		"title": "特性现在不能使用",
		"reason": "受到对手效果影响，当前不能使用这个特性。",
		"detail": "请检查场上的特性封锁效果。",
		"hint": "换到其他行动或结束回合。",
	})

	var box := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox") as PanelContainer
	var title := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionTitle") as Label
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var detail := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionDetail") as Label
	var hint := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionHint") as Label
	var close_button := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionFooter/InvalidActionCloseButton") as Button

	return run_checks([
		assert_true(box != null and box.custom_minimum_size.x >= 320.0 * 1.3, "Portrait invalid hint box should use the touch-scale growth target when width allows"),
		assert_true(title != null and title.get_theme_font_size("font_size") >= int(round(22.0 * 1.35 * 1.3)), "Portrait title text should use the touch-scale portrait size"),
		assert_true(reason != null and reason.get_theme_font_size("font_size") >= int(round(24.0 * 1.35 * 1.3)), "Portrait reason text should use the touch-scale portrait size"),
		assert_true(detail != null and detail.get_theme_font_size("font_size") >= int(round(18.0 * 1.35 * 1.3)), "Portrait detail text should use the touch-scale portrait size"),
		assert_true(hint != null and hint.get_theme_font_size("font_size") >= int(round(17.0 * 1.35 * 1.3)), "Portrait hint text should use the touch-scale portrait size"),
		assert_true(close_button != null and close_button.custom_minimum_size.x >= 260.0 * 1.3, "Portrait close button width should use the touch-scale growth target when width allows"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 78.0 * 1.3, "Portrait close button height should use the touch-scale growth target"),
		assert_true(close_button != null and close_button.get_theme_font_size("font_size") >= int(round(24.0 * 1.3)), "Portrait close button text should use the touch-scale growth target"),
	])


func test_portrait_invalid_action_hint_uses_battle_layout_api_and_logical_viewport() -> String:
	var host := BattlePortraitHintHost.new()
	host.size = Vector2(1600, 900)
	var controller := HintControllerScript.new()
	controller.setup(host)
	controller.show_hint({
		"title": "Cannot use now",
		"reason": "The current action is blocked by a field effect.",
	})

	var box := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox") as PanelContainer
	var reason := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionReason") as Label
	var close_button := host.get_node_or_null("InvalidActionOverlay/InvalidActionCenter/InvalidActionBox/InvalidActionVBox/InvalidActionFooter/InvalidActionCloseButton") as Button

	return run_checks([
		assert_eq(box.custom_minimum_size.x if box != null else 0.0, 374.0, "Portrait invalid hint should use logical portrait width, not the physical rotated viewport"),
		assert_true(reason != null and reason.get_theme_font_size("font_size") >= int(round(24.0 * 1.35 * 1.3)), "Battle portrait API should activate enlarged portrait reason text"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 78.0 * 1.3, "Battle portrait API should activate enlarged portrait button height"),
	])
