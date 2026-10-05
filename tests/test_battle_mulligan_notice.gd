extends TestBase


class NoticeLayoutHost extends Control:
	var portrait := false
	var _portrait_layout_frame_rect := Rect2()

	func _is_portrait_battle_layout_active() -> bool:
		return portrait

	func _portrait_dialog_viewport_size() -> Vector2:
		return _portrait_layout_frame_rect.size


class NoticeBattleScene extends "res://scenes/battle/BattleScene.gd":
	var setup_starts := 0

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass

	func _capture_battle_recording_context_if_ready() -> void:
		pass

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _maybe_run_ai() -> void:
		pass

	func _begin_setup_flow() -> void:
		setup_starts += 1
		_pending_choice = "setup_active_0"


func _make_scene(beneficiary: int, bonus: int, available: int = 10) -> NoticeBattleScene:
	var scene := NoticeBattleScene.new()
	scene.size = Vector2(1280, 720)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for serial: int in 7 + available:
			var data := CardData.new()
			data.name = "Basic %d" % serial
			data.card_type = "Pokemon"
			data.stage = "Basic"
			data.hp = 60
			player.deck.append(CardInstance.create(data, pi))
		player.draw_cards(7)
		gsm.game_state.players.append(player)
	gsm._mulligan_counts[1 - beneficiary] = bonus
	gsm._pending_mulligan_beneficiary_index = beneficiary
	scene.set("_gsm", gsm)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	return scene


func test_real_bonus_draws_for_either_seat_continue_setup_without_clicks() -> String:
	var checks: Array[String] = []
	for beneficiary: int in 2:
		for bonus: int in [1, 2, 3]:
			var scene := _make_scene(beneficiary, bonus)
			var gsm := scene.get("_gsm") as GameStateMachine
			var data := {"beneficiary": beneficiary, "mulligan_count": bonus}
			scene._on_player_choice_required("mulligan_extra_draw", data)
			var notice := scene.get_node_or_null("MulliganNotice") as PanelContainer
			checks.append(assert_not_null(notice, "A successful automatic draw must show information"))
			if notice != null:
				var label := notice.get_node("Content/MulliganNoticeText") as Label
				checks.append(assert_str_contains(label.text, "补抽 %d 张" % bonus))
				checks.append(assert_str_contains((notice.get_node("Content/MulliganNoticeReason") as Label).text, "起手无基础宝可梦"))
				checks.append(assert_eq(notice.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The notice must not block board input"))
				checks.append(assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE))
				checks.append(assert_eq(notice.find_children("*", "Button", true, false).size(), 0, "Information must contain no draw/confirm/close buttons"))
			checks.append(assert_eq(gsm.game_state.players[beneficiary].hand.size(), 7 + bonus, "Auto draw must update the real hand"))
			checks.append(assert_eq(scene.setup_starts, 1, "Setup must proceed immediately, without waiting for the notice"))
			checks.append(assert_eq(str(scene.get("_pending_choice")), "setup_active_0", "The notice must not overwrite the next setup decision"))
			scene._on_player_choice_required("mulligan_extra_draw", data)
			checks.append(assert_eq(gsm.game_state.players[beneficiary].hand.size(), 7 + bonus, "A stale duplicate signal must not draw again"))
			checks.append(assert_eq(scene.setup_starts, 1, "A consumed bonus window must not restart setup"))
			scene.free()
	return run_checks(checks)


func test_bonus_notice_reports_actual_draw_when_deck_is_short_or_empty() -> String:
	var checks: Array[String] = []
	for available: int in [0, 1]:
		var scene := _make_scene(0, 3, available)
		scene._on_player_choice_required("mulligan_extra_draw", {"beneficiary": 0, "mulligan_count": 3})
		var gsm := scene.get("_gsm") as GameStateMachine
		var label := scene.get_node("MulliganNotice/Content/MulliganNoticeText") as Label
		checks.append(assert_str_contains(label.text, "未能补抽" if available == 0 else "补抽 1 张"))
		checks.append(assert_eq(gsm.game_state.players[0].hand.size(), 7 + available))
		checks.append(assert_false(gsm.game_state.is_game_over(), "An exhausted bonus draw must not cause deck-out"))
		checks.append(assert_eq(scene.setup_starts, 1))
		scene.free()
	return run_checks(checks)


func test_bonus_notice_dismisses_itself_without_input() -> String:
	var scene := _make_scene(0, 2)
	var tree := Engine.get_main_loop() as SceneTree
	scene._on_player_choice_required("mulligan_extra_draw", {"beneficiary": 0, "mulligan_count": 2})
	var notice := scene.get_node("MulliganNotice") as PanelContainer
	# Exercise the real notice timer in-tree without starting a full match or
	# evaluating BattleScene's @onready bindings on this stripped fixture.
	scene.remove_child(notice)
	tree.root.add_child(notice)
	await tree.process_frame
	var timer := notice.get_node("AutoDismissTimer") as Timer
	var checks: Array[String] = [
		assert_true(notice.visible, "Information must initially be visible"),
		assert_false(timer.is_stopped(), "Dismissal must start automatically"),
		assert_eq(scene.setup_starts, 1, "Setup must already be running while information remains visible"),
	]
	await tree.create_timer(timer.wait_time + 0.3).timeout
	await tree.process_frame
	checks.append(assert_false(is_instance_valid(notice), "Information must disappear without a click"))
	scene.free()
	return run_checks(checks)


func test_notice_stays_compact_after_layout_and_long_player_names() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var saved_names := GameManager.battle_player_display_names.duplicate()
	GameManager.set_battle_player_display_names(["超长玩家名称".repeat(20), "超长对手名称".repeat(20)])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	tree.root.add_child(viewport)
	var host := NoticeLayoutHost.new()
	viewport.add_child(host)
	var checks: Array[String] = []
	for dimensions: Vector2 in [Vector2(320, 568), Vector2(390, 844), Vector2(1600, 900)]:
		viewport.size = Vector2i(dimensions)
		host.size = dimensions
		load("res://scripts/ui/battle/BattleMulliganNotice.gd").show_result(host, 0, 3)
		for frame: int in 4:
			await tree.process_frame
		var notice := host.get_node("MulliganNotice") as Control
		checks.append(assert_true(notice.size.y <= 88, "Opening notice must remain a compact strip after container layout: %s" % notice.size))
		checks.append(assert_true(notice.size.x <= minf(420, dimensions.x - 24), "Notice must leave space around the board"))
		checks.append(assert_true(Rect2(Vector2.ZERO, dimensions).encloses(notice.get_rect()), "Notice must remain inside the viewport"))
		var title := notice.get_node("Content/MulliganNoticeText") as Label
		var reason := notice.get_node("Content/MulliganNoticeReason") as Label
		checks.append(assert_str_contains(title.text, "补抽 3 张", "Shorten the name, not the actual draw count"))
		checks.append(assert_str_contains(reason.text, "起手无基础宝可梦", "Shorten the name, not the reason"))
		for label: Label in [title, reason]:
			var measured := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			checks.append(assert_true(measured <= label.size.x + 1, "Both lines must remain readable without clipping"))
		for control: Node in notice.find_children("*", "Control", true, false):
			checks.append(assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Every toast element must pass input through"))
	viewport.free()
	GameManager.set_battle_player_display_names(saved_names)
	return run_checks(checks)


func test_visible_notice_reflows_when_portrait_safe_frame_changes() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	tree.root.add_child(viewport)
	var host := NoticeLayoutHost.new()
	host.size = Vector2(1600, 900)
	viewport.add_child(host)
	load("res://scripts/ui/battle/BattleMulliganNotice.gd").show_result(host, 1, 2)
	for frame: int in 3:
		await tree.process_frame
	host.portrait = true
	host._portrait_layout_frame_rect = Rect2(26, 40, 320, 700)
	# Safe frame can settle after the root resize, without another resized signal.
	for frame: int in 4:
		await tree.process_frame
	var notice := host.get_node("MulliganNotice") as Control
	var result := run_checks([
		assert_true(host._portrait_layout_frame_rect.encloses(notice.get_rect()), "An existing notice must follow the settled portrait safe frame"),
		assert_true(notice.size.y <= 88, "Orientation changes must not grow the toast height"),
	])
	viewport.free()
	return result


func test_notice_remains_readable_on_expanded_phone_canvas() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var window := Window.new()
	window.size = Vector2i(390, 844)
	window.content_scale_size = Vector2i(900, 1948)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	tree.root.add_child(window)
	var host := NoticeLayoutHost.new()
	host.size = Vector2(900, 1948)
	window.add_child(host)
	load("res://scripts/ui/battle/BattleMulliganNotice.gd").show_result(host, 0, 2)
	for frame: int in 4:
		await tree.process_frame
	var notice := host.get_node("MulliganNotice") as Control
	var title := notice.get_node("Content/MulliganNoticeText") as Label
	var pixel_scale := window.get_stretch_transform().get_scale().x
	var checks: Array[String] = [
		assert_gte(title.get_theme_font_size("font_size") * pixel_scale, 17.5, "Phone canvas scaling must not shrink text to desktop-sized logical pixels"),
		assert_true(notice.size.y * pixel_scale <= 88, "Physical phone notice height must stay compact"),
		assert_true(notice.size.x * pixel_scale <= 366.5, "Physical phone margins must remain visible"),
	]
	window.size = Vector2i(1600, 900)
	window.content_scale_size = Vector2i(1600, 900)
	host.size = Vector2(1600, 900)
	for frame: int in 4:
		await tree.process_frame
	checks.append(assert_true(notice.size.y <= 88, "The notice must shrink back after the expanded phone canvas returns to desktop"))
	window.free()
	return run_checks(checks)
