extends "res://scripts/tools/Arena3DSmoke.gd"
## Development-only CLI play bridge. No gameplay mutations or direct action callbacks.
## Only visible GUI text/cards and the arena's public display DTO leave this process.
var session_dir := "user://cli-player"
var sequence := 0

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(session_dir)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([575720, 575720])
	GameManager.first_player_choice = 0
	GameManager.ai_deck_strategy = "generic"
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	await _settle(.8)
	var opponent = battle.get("_ai_opponent")
	if opponent != null: opponent.use_mcts = false
	print("CLI_PLAYER_READY: ", ProjectSettings.globalize_path(session_dir))
	await _observe()
	while is_instance_valid(battle):
		await _settle(.1)
		var path := session_dir + "/command.json"
		if not FileAccess.file_exists(path): continue
		var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		DirAccess.remove_absolute(path)
		if not command is Dictionary: continue
		if str(command.get("op", "")) == "quit":
			battle.call("_release_battle_runtime_resources")
			battle.queue_free()
			await get_tree().process_frame
			get_tree().quit()
			return
		if int(command.get("snapshot", -1)) != sequence:
			print("CLI_PLAYER_REJECT: stale snapshot")
		elif str(command.get("op", "")) == "click":
			var at: Array = command.get("at", [])
			if at.size() == 2:
				await _click_point(Vector2(float(at[0]), float(at[1])), int(command.get("button", MOUSE_BUTTON_LEFT)), "cli_player")
		elif str(command.get("op", "")) == "wait":
			await _settle(clampf(float(command.get("seconds", 1)), .1, 5))
		await _observe()

func _observe() -> void:
	sequence += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(session_dir + "/screen.png")
	var items: Array = []
	_collect(battle, items)
	var presenter = battle.get_node_or_null("Arena3DPresenter")
	var world_points: Dictionary = {}
	if presenter != null:
		for key in presenter.world.cards:
			var point: Vector2 = presenter.get_global_transform() * presenter.world.camera.unproject_position(presenter.world.cards[key].node.position)
			world_points[key] = [snappedf(point.x, .1), snappedf(point.y, .1)]
	var observation := {
		"snapshot": sequence,
		"pending_prompt": str(battle.get("_pending_choice")),
		"board": presenter.last_frame if presenter != null else {},
		"world_points": world_points,
		"ui": items,
		"render_metrics": {"fps": Performance.get_monitor(Performance.TIME_FPS), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "resolution": [get_viewport().size.x,get_viewport().size.y]},
		"presentation": {"attacks":presenter.motion.attack_count,"feedback_events":presenter.motion.event_count,"busy":presenter.motion.is_busy()} if presenter != null else {},
	}
	var output := FileAccess.open(session_dir + "/observation.tmp", FileAccess.WRITE)
	output.store_string(JSON.stringify(observation, "  "))
	output.close()
	# Windows readers can briefly hold the previous file without delete sharing.
	# Never silently lose a snapshot when atomic replacement encounters that lock.
	for attempt in range(80):
		if DirAccess.rename_absolute(session_dir + "/observation.tmp", session_dir + "/observation.json") == OK: break
		await _settle(.05)
	print("CLI_PLAYER_SNAPSHOT ", sequence)
	print("CLI_INPUT_GATES ready=",battle.call("_can_view_player_start_turn_action")," modal=",battle.call("_is_board_modal_overlay_visible")," draw=",battle.get("_draw_reveal_active")," ai_wait=",battle.get("_ai_llm_waiting")," pause=",battle.call("_is_ai_action_pause_active")," handover=",battle.get("_handover_attack_vfx_delay_active"))

func _collect(node: Node, items: Array) -> void:
	if node is Control and (not node.is_visible_in_tree() or node.modulate.a < .01): return
	if node is BattleCardView:
		if not node.get("_face_down") and node.card_data != null:
			_add_item(node, node.card_data.display_name(), items, true)
		return
	if node is Button:
		_add_item(node, node.tooltip_text if node.tooltip_text.begins_with("领取奖赏") else node.text, items, not node.disabled)
	elif node is PanelContainer and not node.gui_input.get_connections().is_empty():
		var labels: Array[String] = []
		_text(node, labels)
		if not labels.is_empty(): _add_item(node, " / ".join(labels), items, true)
	for child in node.get_children():
		_collect(child, items)

func _text(node: Node, labels: Array[String]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is RichTextLabel:
		if str(node.text).strip_edges() != "": labels.append(str(node.text))
	for child in node.get_children(): _text(child, labels)

func _add_item(control: Control, title: String, items: Array, enabled: bool) -> void:
	var rect := control.get_global_rect().intersection(get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent is Control:
		if parent.clip_contents: rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	if rect.size.x < 2 or rect.size.y < 2: return
	items.append({"text": title, "enabled": enabled, "at": [snappedf(rect.get_center().x, .1), snappedf(rect.get_center().y, .1)], "path": str(battle.get_path_to(control))})
