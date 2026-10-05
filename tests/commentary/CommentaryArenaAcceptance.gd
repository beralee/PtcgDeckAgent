extends Node
## Explicit, offline rendered acceptance. NEVER constructs a real API client.
const Controller := preload("res://scripts/commentary/BattleCommentaryController.gd")
const Preferences := preload("res://scripts/commentary/CommentaryPreferences.gd")
var rig: Node
var commentary: Node
var checks: Array = []
var fixture: Dictionary
var output := "res://.godot_test_user/commentary_render"

class CommentatorDouble extends RefCounted:
	var requests: Array = []
	var callbacks: Array[Callable] = []
	var canceled := false
	func request_json(_owner: Node, _url: String, _key: String, payload: Dictionary, callback: Callable) -> int:
		requests.append(payload.duplicate(true))
		callbacks.append(callback)
		return OK
	func cancel_pending_requests() -> void:
		canceled = true
	func deliver(index: int, content: Dictionary) -> void:
		# Exercise the real response envelope/parser, including JSON float IDs.
		var envelope := {"choices": [{"finish_reason": "stop", "message": {"content": JSON.stringify(content)}}], "usage": {"prompt_tokens": 500, "completion_tokens": 100}}
		var client := preload("res://scripts/commentary/CommentaryDeepSeekClient.gd").new()
		callbacks[index].call(client._parse_chat_response(200, JSON.stringify(envelope)))

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	get_tree().create_timer(70).timeout.connect(func(): get_tree().quit(2))
	Preferences.save_enabled(false) # Isolated user directory; prevents auto network.
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/commentary_model_simulation.json"))
	get_tree().root.size = Vector2i(1440, 1000)
	rig = preload("res://scripts/tools/ArenaSignatureScenario.gd").new()
	add_child(rig)
	await rig.mount_combat("grimmsnarl")
	var battle: Control = rig.battle
	var presenter: Control = battle.get_node("Arena3DPresenter")
	_check(not battle.has_node("BattleCommentary"), "default_off_creates_no_agent")
	var model := CommentatorDouble.new()
	commentary = Controller.new()
	battle.add_child(commentary)
	commentary.setup(battle, presenter, {"api_key": "OFFLINE_FIXTURE_ONLY"}, model)
	await _wait(0.8)
	_check(model.requests.size() == 1, "preparation_precedes_narration")
	if model.requests.is_empty(): return _finish(false)
	var packet: Dictionary = JSON.parse_string(model.requests[0].messages[1].content)
	var preparation: Dictionary = fixture.preparation.duplicate(true)
	preparation.snapshot_id = packet.snapshot_id
	model.deliver(0, preparation)
	_check(not commentary.session.plans.is_empty(), "agent_understands_both_decks_first")
	var before_hp: int = rig.gsm.game_state.players[0].active_pokemon.get_remaining_hp()
	var accepted: bool = rig.perform_combat()
	_check(accepted, "real_attack_submitted_through_interaction_owner")
	var after_hp: int = rig.gsm.game_state.players[0].active_pokemon.get_remaining_hp()
	_check(before_hp - after_hp == 180, "real_engine_resolves_shadow_bullet_damage")
	_check(not commentary.session.stable, "action_immediately_invalidates_old_subtitle")
	# Presentation drains naturally. No network operation joins the visual gate.
	for i in range(120):
		await _wait(0.05)
		if commentary.session.stable: break
	_check(commentary.session.stable, "settled_transaction_offered")
	commentary.session.next_request_at = 0.0
	await _wait(0.2)
	_check(model.requests.size() >= 2, "public_events_reach_mock_model")
	var index := model.requests.size() - 1
	packet = JSON.parse_string(model.requests[index].messages[1].content)
	if packet.mode == "prepare":
		preparation.snapshot_id = packet.snapshot_id
		model.deliver(index, preparation)
		commentary.session.next_request_at = 0.0
		await _wait(0.2)
		index = model.requests.size() - 1
		packet = JSON.parse_string(model.requests[index].messages[1].content)
	var response := {}
	for item: Dictionary in fixture.cases:
		if item.id == "marnie_shadow_bullet_bench_damage": response = item.response.duplicate(true)
	response.snapshot_id = packet.snapshot_id
	response.evidence_ids = [-int(packet.snapshot_id)]
	model.deliver(index, response)
	await _wait(0.3)
	_check(commentary.panel.body.text == response.text, "agent_response_reaches_live_caption")
	_check(not JSON.stringify(packet).contains("SECRET"), "outbound_packet_is_public")
	_check(commentary.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "caption_does_not_intercept_board_input")
	await _geometry_and_capture("wide")
	get_tree().root.size = Vector2i(720, 1280)
	await _wait(0.6)
	await _geometry_and_capture("portrait")
	await _click(commentary.panel.history_button)
	_check(is_instance_valid(commentary.history_dialog) and commentary.history_dialog.visible, "mouse_history_uses_in_game_modal")
	if is_instance_valid(commentary.history_dialog): commentary.history_dialog.request_cancel()
	await _wait(0.25)
	var previous_emulation: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	await _touch(commentary.panel.history_button)
	_check(is_instance_valid(commentary.history_dialog) and commentary.history_dialog.visible, "raw_touch_history_without_mouse_emulation")
	if is_instance_valid(commentary.history_dialog): commentary.history_dialog.request_cancel()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	await _wait(0.25)
	# Keyboard confirm follows the same Button signal as mouse/touch.
	commentary.panel.close_button.grab_focus()
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	get_tree().root.push_input(enter)
	enter = enter.duplicate()
	enter.pressed = false
	get_tree().root.push_input(enter)
	await _wait(0.15)
	_check(commentary.closed and model.canceled, "keyboard_close_cancels_agent")
	_check(float(battle.get_meta("commentary_reserved_height")) == 0.0, "close_restores_board_space")
	await rig.close()
	rig.queue_free()
	await _two_dimensional_scene()
	await _setup_scene()
	_finish(true)

func _two_dimensional_scene() -> void:
	Preferences.save_enabled(true)
	GameManager.battle_3d_enabled = false
	ProjectSettings.set_setting("arena3d/enabled", false)
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.set_script(preload("res://scripts/tools/ArenaSignatureScenario.gd").Scene)
	get_tree().root.add_child(scene)
	await _wait(0.2)
	_check(not scene.has_node("Arena3DPresenter") and not scene.has_node("BattleCommentary"), "2d_with_opt_in_allocates_no_agent")
	Preferences.save_enabled(false)
	scene.queue_free()
	await get_tree().process_frame

func _setup_scene() -> void:
	get_tree().root.size = Vector2i(1440, 1000)
	get_tree().root.content_scale_size = Vector2i(1600, 900)
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	get_tree().root.add_child(setup)
	get_tree().current_scene = setup
	setup.set("_selected_background_path", "res://assets/arena3d/previews/grove.png")
	setup.call("_refresh_background_selection")
	await _wait(0.7)
	var option: Control = setup.find_child("CommentarySetupOption", true, false)
	_check(option != null and not option.toggle.disabled, "setup_enables_toggle_for_3d")
	await _click(option.toggle)
	_check(Preferences.enabled(), "setup_toggle_persists_opt_in")
	var previous_emulation: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	await _wait(0.25)
	await _touch(option.toggle)
	_check(not Preferences.enabled(), "setup_raw_touch_toggles_once")
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output + "/setup.png")
	setup.set("_selected_background_path", setup.DEFAULT_BACKGROUND)
	setup.call("_refresh_background_selection")
	_check(option.toggle.disabled, "setup_disables_toggle_for_2d")
	Preferences.save_enabled(false)
	setup.queue_free()
	await get_tree().process_frame

func _touch(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await get_tree().process_frame

func _geometry_and_capture(label: String) -> void:
	var field: Control = rig.battle.get_node("MainArea/CenterField/FieldArea")
	var hand: Control = rig.battle.get_node("MainArea/CenterField/HandArea")
	var panel: Control = commentary.panel
	_check(not panel.get_global_rect().intersects(field.get_global_rect()), label + "_caption_does_not_cover_board")
	_check(not panel.get_global_rect().intersects(hand.get_global_rect()), label + "_caption_does_not_cover_hand")
	_check(panel.close_button.size.y >= 44, label + "_button_target")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		get_viewport().get_texture().get_image().save_png(output + "/" + label + ".png")

func _click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _check(passed: bool, label: String) -> void:
	checks.append({"name": label, "passed": passed})
	print("COMMENTARY_CHECK ", label, " ", passed)

func _finish(completed: bool) -> void:
	var passed := completed
	for check: Dictionary in checks: passed = passed and check.passed
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "paid_requests": 0, "transport": "sub_agent_authored_fixture"}, "\t"))
	get_tree().quit(0 if passed else 1)
