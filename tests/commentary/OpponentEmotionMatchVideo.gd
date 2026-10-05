extends "res://tests/commentary/CommentaryMatchVideo.gd"
## Full chronological replay of a fresh, completed match. Private states only
## restore the local renderer; the production director sees allow-listed events.
const EMOTION_ROOT := "res://.tmp/opponent_emotions_20260929/match"
const EMOTION_OUT := "res://output/opponent-emotions-20260929"
const Mood := preload("res://scripts/commentary/OpponentMood.gd")
class ClockedController extends "res://scripts/commentary/OpponentTalkController.gd":
	var capture_time := 0.0
	var replay_decision_pending := false
	func _now() -> float: return capture_time
	func _settled() -> bool:
		return not replay_decision_pending and super._settled()
class EmotionModel extends RefCounted:
	var requests: Array = []
	func cancel_pending_requests() -> void: pass
	func request_json(_owner: Node, _url: String, _key: String, payload: Dictionary, callback: Callable) -> int:
		requests.append(payload.duplicate(true))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/opponent_emotion_bank_simulation.json"))
		var envelope := {"choices": [{"finish_reason": "stop", "message": {"content": JSON.stringify(fixture)}}], "usage": {"prompt_tokens": 0, "completion_tokens": 0}}
		callback.call_deferred(preload("res://scripts/commentary/CommentaryDeepSeekClient.gd").new()._parse_chat_response(200, JSON.stringify(envelope)))
		return OK
var emotion_model := EmotionModel.new()
var spoken: Array = []
var current_step := 0
var captured_moods: Dictionary = {}
var replay_report: Dictionary = {}
var screenshot_due := ""
var screenshot_at := 0
var mood_grid: GridContainer
var failures: Array = []

func _run() -> void:
	preview = "--preview" in OS.get_cmdline_user_args()
	preload("res://scripts/commentary/CommentaryPreferences.gd").save_enabled(false)
	DirAccess.make_dir_recursive_absolute(EMOTION_OUT)
	var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EMOTION_ROOT + "/private_replay.json"))
	frames = replay.frames
	replay_report = replay.report
	public_frames = JSON.parse_string(FileAccess.get_file_as_string(EMOTION_ROOT + "/public_match.json")).frames
	for i: int in frames.size():
		var gs := restorer.restore(frames[i].state)
		if JSON.stringify(Projector.snapshot(gs)).sha256_text() != str(frames[i].public_hash):
			push_error("Public replay mismatch at %s" % frames[i].step)
			get_tree().quit(2)
			return
	print("EMOTION_REPLAY_VERIFIED ", frames.size())
	get_tree().root.size = Vector2i(1600, 900)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([675700, 675701])
	GameManager.battle_3d_enabled = true
	GameManager.battle_effects_enabled = true
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	var start := 0
	while start < frames.size() and int(public_frames[start].state.turn) <= 0: start += 1
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle.set_script(ReplayScene)
	gsm = GameStateMachine.new()
	gsm.game_state = restorer.restore(frames[start].state)
	battle.set("_gsm", gsm)
	battle.set("_view_player", 0)
	battle.set("_battle_mode", "review_readonly")
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for i in 16: await get_tree().process_frame
	arena = battle.get_node("Arena3DPresenter")
	arena.world.motion_enabled = true
	arena.world.sound_enabled = false
	arena.motion.fast_enabled = false
	commentary = ClockedController.new()
	battle.add_child(commentary)
	commentary.setup(battle, arena, {"api_key": "OFFLINE_AGENT_MODEL", "ai_personality": "是一个大逗比，臭牌篓子"}, emotion_model)
	commentary.set_process(false)
	commentary.session.line_ready.connect(_spoken)
	_build_overlay()
	_setup_emotion_cover()
	if not preview:
		stream.big_endian = true
		stream.connect_to_host("127.0.0.1", 18739)
		for i in 100:
			stream.poll()
			if stream.get_status() == StreamPeerTCP.STATUS_CONNECTED: break
			await get_tree().process_frame
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			push_error("Encoder unavailable")
			get_tree().quit(3)
			return
	await _draw_frames(150)
	cover.hide()
	_apply_frame(start, false)
	await _draw_frames(120)
	for fi: int in range(start + 1, frames.size()):
		_apply_frame(fi, true)
		await _draw_frames(10)
		# Preserve the actual presentation transaction, including multi-target
		# attacks. This is replay pacing only, never a gameplay/model wait.
		var animation_wait := 0
		while arena.motion.is_busy() and animation_wait < 180:
			await _draw_frames(1)
			animation_wait += 1
		if arena.motion.is_busy():
			failures.append("Undrained visual transaction at step %d" % current_step)
			arena.motion.clear()
		await _draw_frames(6)
		var remaining := 4.0 - (float(frame_count) / FPS - float(commentary.session.last_spoken))
		if remaining > 0: await _draw_frames(ceili(remaining * FPS))
		if fi % 15 == 0: print("EMOTION_VIDEO_PROGRESS frame=", fi, " video_seconds=", float(frame_count) / FPS)
		if preview and spoken.size() >= 4: break
	await _draw_frames(45)
	cover.show()
	cover_title.text = "玛俐拿下这局\n多龙也会服气" if int(replay_report.winner) == 0 else "多龙拿下这局\n开心收尾"
	cover_detail.text = "%d 回合 · %d 个决策步骤\n\n对手的每句话都有对应心态\n心态、表情、台词同步变化\n\n本局台词由离线模拟模型提供\n比赛结果来自真实规则与策略" % [replay_report.turns, replay_report.steps]
	await _draw_frames(150)
	var evidence := {"report": replay_report, "verified_replay_frames": frames.size(), "video_frames": frame_count, "fps": FPS, "seconds": float(frame_count) / FPS, "spoken": spoken, "mood_ids_seen": captured_moods.keys(), "portrait_count": Mood.IDS.size(), "mock_requests": emotion_model.requests.size(), "paid_api_requests": 0, "preview": preview, "failures": failures}
	FileAccess.open(EMOTION_OUT + ("/preview-evidence.json" if preview else "/video-evidence.json"), FileAccess.WRITE).store_string(JSON.stringify(evidence, "\t"))
	stream.disconnect_from_host()
	commentary.close()
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 4)

func _spoken(text: String, cue: Dictionary) -> void:
	var entry := cue.duplicate(true)
	entry["text"] = text
	entry["step"] = current_step
	entry["video_time"] = float(frame_count) / FPS
	spoken.append(entry)
	captured_moods[cue.mood_id] = true
	screenshot_due = str(cue.mood_id)
	screenshot_at = frame_count + 6
	title.text = "多龙的心态 · " + str(cue.mood)
	title.add_theme_color_override("font_color", Color(Mood.entry(cue.mood_id).color))
	if commentary.panel.current_mood_id != str(cue.mood_id): failures.append("Portrait mismatch at %d" % current_step)
	print("EMOTION_SPEECH step=", current_step, " mood=", cue.mood_id, " text=", text)

func _apply_frame(index: int, animate: bool) -> void:
	current_step = int(frames[index].step)
	commentary.replay_decision_pending = bool(public_frames[index].pending)
	super._apply_frame(index, animate)
	if animate:
		for raw: Dictionary in frames[index].events:
			commentary._on_action(GameAction.create(int(raw.type), int(raw.player), raw.data, int(raw.turn), str(raw.description)))

func _draw_frames(count: int) -> void:
	for i in count:
		commentary.capture_time = float(frame_count) / FPS
		if not cover.visible: commentary._process(1.0 / FPS)
		else: commentary._layout()
		var current_mood := Mood.entry(commentary.panel.current_mood_id)
		title.text = "多龙的心态 · " + str(current_mood.label)
		title.add_theme_color_override("font_color", Color(current_mood.color))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not screenshot_due.is_empty() and frame_count >= screenshot_at:
			get_viewport().get_texture().get_image().save_png(EMOTION_OUT + "/mood-" + screenshot_due + ".png")
			screenshot_due = ""
		if not preview:
			var data := get_viewport().get_texture().get_image().save_jpg_to_buffer(.92)
			stream.put_u32(data.size())
			if stream.put_data(data) != OK:
				push_error("Encoder stream failed")
				get_tree().quit(5)
				return
		frame_count += 1

func _setup_emotion_cover() -> void:
	title.text = "18.5  玛俐长毛巨魔 × 开发者多龙"
	footer.text = "新一局真实对战回放 · 逗比性格 · 文字陪练 + 心态表情 · 台词使用离线模拟模型"
	cover_title.position = Vector2(90, 190)
	cover_title.add_theme_font_size_override("font_size", 50)
	cover_title.text = "有心态的\nAI 陪练对手"
	cover_detail.position = Vector2(94, 390)
	cover_detail.add_theme_font_size_override("font_size", 26)
	cover_detail.text = "18.5 玛俐长毛巨魔 × 开发者多龙\n性格：逗比臭牌篓子\n\n12 种心态，每句话有自己的表情\n新一局真实对战 · 文字版\n\n台词使用离线模拟模型"
	for child in cover.get_children():
		if child is Label and child.text.begins_with("PTCG DECK AGENT"):
			child.text = "PTCG DECK AGENT  /  AI COMPANION"
			child.position = Vector2(90, 120)
		if child is ColorRect: child.position = Vector2(90, 350)
	mood_grid = GridContainer.new()
	mood_grid.columns = 4
	mood_grid.position = Vector2(900, 170)
	mood_grid.add_theme_constant_override("h_separation", 10)
	mood_grid.add_theme_constant_override("v_separation", 14)
	cover.add_child(mood_grid)
	for id: String in Mood.IDS:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(130, 150)
		mood_grid.add_child(cell)
		var face := TextureRect.new()
		face.texture = Mood.portrait(id)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(130, 120)
		cell.add_child(face)
		var label := Label.new()
		label.text = Mood.entry(id).label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", Color(Mood.entry(id).color))
		cell.add_child(label)
	_label(cover, Vector2(928, 690), 19, Color("8ca9ba")).text = "表情包一览 · 对局中按真实战况触发"
