extends Node
## Explicit offline demo: exact captured match snapshots, production 3D scene,
## production commentary protocol with an agent-authored transport double.
const ROOT := "res://.tmp/commentary_match_20260929"
const OUT := "res://output/commentary-match-20260929"
const Projector = preload("res://scripts/commentary/CommentaryPublicProjector.gd")
const Controller = preload("res://scripts/commentary/BattleCommentaryController.gd")
const FPS := 30
class ReplayScene extends "res://scenes/battle/BattleScene.gd":
	func _start_battle() -> void: pass
	func _maybe_run_ai() -> void: pass
class Restorer extends "res://scripts/engine/BattleReplayStateRestorer.gd":
	func _restore_card_data(snapshot: Dictionary) -> CardData:
		return CardData.from_dict(snapshot)
	func _restore_player_state(snapshot: Dictionary) -> PlayerState:
		var normalized := snapshot.duplicate(true)
		normalized.discard_pile = normalized.get("discard", [])
		return super._restore_player_state(normalized)
class AgentTransport extends RefCounted:
	var preparation: Array = []
	var clip: Dictionary = {}
	var requests: Array = []
	func cancel_pending_requests() -> void: pass
	func request_json(_owner: Node, _url: String, _key: String, payload: Dictionary, callback: Callable) -> int:
		var packet: Dictionary = JSON.parse_string(payload.messages[1].content)
		requests.append(packet)
		var response := {"snapshot_id":int(packet.snapshot_id)}
		if packet.mode == "prepare": response.plans = preparation
		else:
			response.kind = "analysis"
			response.text = clip.text
			response.evidence_ids = clip.evidence_ids
		var envelope := {"choices":[{"finish_reason":"stop","message":{"content":JSON.stringify(response)}}],"usage":{"prompt_tokens":0,"completion_tokens":0}}
		var parser := preload("res://scripts/commentary/CommentaryDeepSeekClient.gd").new()
		callback.call_deferred(parser._parse_chat_response(200, JSON.stringify(envelope)))
		return OK
var battle: Control
var gsm: GameStateMachine
var arena: Control
var commentary: Node
var model := AgentTransport.new()
var restorer := Restorer.new()
var frames: Array = []
var public_frames: Array = []
var edit: Dictionary
var stream := StreamPeerTCP.new()
var title: Label
var scoreboard: Label
var footer: Label
var cover: ColorRect
var cover_title: Label
var cover_detail: Label
var frame_count := 0
var chapter_marks: Array = []
var preview := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	preview = "--preview" in OS.get_cmdline_user_args()
	preload("res://scripts/commentary/CommentaryPreferences.gd").save_enabled(false)
	DirAccess.make_dir_recursive_absolute(OUT)
	var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/private_replay.json"))
	frames = replay.frames
	public_frames = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/public_match.json")).frames
	edit = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/commentary_edit.json"))
	# Every restored public board must equal the actual simulation, before capture.
	for i: int in frames.size():
		var gs := restorer.restore(frames[i].state)
		var actual := Projector.snapshot(gs)
		if JSON.stringify(actual).sha256_text() != str(frames[i].public_hash):
			FileAccess.open(ROOT+"/restore_mismatch.json",FileAccess.WRITE).store_string(JSON.stringify({"step":frames[i].step,"actual":actual,"expected":public_frames[i].state},"\t"))
			push_error("Replay projection mismatch at step " + str(frames[i].step))
			get_tree().quit(2)
			return
	print("REPLAY_VERIFIED ", frames.size())
	get_tree().root.size = Vector2i(1600,900)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([675700,675701])
	GameManager.battle_3d_enabled = true
	GameManager.battle_effects_enabled = true
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle.set_script(ReplayScene)
	gsm = GameStateMachine.new()
	gsm.game_state = restorer.restore(frames[_index(int(edit.clips[0].start_step))].state)
	battle.set("_gsm", gsm)
	battle.set("_view_player",0)
	battle.set("_battle_mode","review_readonly")
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for i in 16: await get_tree().process_frame
	arena = battle.get_node("Arena3DPresenter")
	arena.world.motion_enabled = true
	arena.world.sound_enabled = false
	arena.motion.fast_enabled = false
	model.preparation = edit.preparation
	commentary = Controller.new()
	battle.add_child(commentary)
	commentary.setup(battle,arena,{"api_key":"OFFLINE_AGENT_SIMULATION"},model)
	commentary.set_process(false)
	commentary.panel.body.add_theme_font_size_override("font_size",27)
	commentary.panel.body.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	commentary.panel.body.custom_minimum_size.x = 1250
	commentary.panel.history_button.hide()
	commentary.panel.close_button.hide()
	_build_overlay()
	if not preview:
		stream.big_endian = true
		stream.connect_to_host("127.0.0.1",18739)
		for i in 100:
			stream.poll()
			if stream.get_status() == StreamPeerTCP.STATUS_CONNECTED: break
			await get_tree().process_frame
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			push_error("Video encoder unavailable")
			get_tree().quit(3)
			return
	cover_title.text = "玛俐长毛巨魔  ×  开发者多龙"
	cover_detail.text = "18.5  /  3D 实战回放 · 文字解说测试\n\n完整对局的关键回合剪辑\n解说由离线模拟模型生成 · DeepSeek 调用 0 次"
	await _draw_frames(180)
	cover.hide()
	var seconds_per_clip: float = 116.0 / edit.clips.size()
	for ci: int in edit.clips.size():
		var clip: Dictionary = edit.clips[ci]
		chapter_marks.append({"start":float(frame_count)/FPS,"title":clip.title,"start_step":clip.start_step,"end_step":clip.end_step})
		var clip_start := frame_count
		title.text = "%02d  /  %s" % [ci+1,clip.title]
		commentary.panel.present("跟随公开战况，观察本段关键行动…","文字解说")
		commentary.panel.status.text = "真实对局回放 · 子 Agent 模拟模型 · 0 次付费调用"
		var start_index := _index(int(clip.start_step))
		var end_index := _index(int(clip.end_step))
		_apply_frame(start_index,false)
		arena.motion.clear()
		arena.motion.shown = {}
		arena._refresh()
		await _draw_frames(12)
		# Preserve all captured actions in each selected segment; reserve reading time.
		var action_frames := maxi(5, int(90.0/maxi(1,end_index-start_index)))
		for fi: int in range(start_index+1,end_index+1):
			_apply_frame(fi,true)
			await _draw_frames(action_frames)
		await _draw_frames(45)
		await _comment(clip,start_index,end_index)
		await _draw_frames(12)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+"/chapter-%02d.png" % [ci+1])
		await _draw_frames(maxi(1,roundi(seconds_per_clip*FPS)-(frame_count-clip_start)))
		print("VIDEO_CHAPTER ",ci+1," frames=",frame_count," caption=",commentary.panel.body.text)
		if preview and ci >= 2: break
	cover.show()
	cover_title.text = "多龙巴鲁托 · 拿完奖赏获胜"
	cover_detail.text = "12 个回合 / 117 个决策步骤\n\n多龙先成型，指示物持续拆后排\n长毛巨魔后期登场，未能兑现反击\n\n本局效果演示，不代表总体卡组胜率"
	await _draw_frames(180)
	FileAccess.open(OUT+"/video-evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"report":replay.report,"verified_replay_frames":frames.size(),"video_frames":frame_count,"fps":FPS,"chapters":chapter_marks,"mock_requests":model.requests.size(),"paid_api_requests":0,"preview":preview},"\t"))
	stream.disconnect_from_host()
	commentary.close()
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _index(step: int) -> int:
	for i: int in frames.size():
		if int(frames[i].step) == step: return i
	assert(false,"Missing replay step")
	return -1

func _apply_frame(index: int, animate: bool) -> void:
	gsm.game_state = restorer.restore(frames[index].state)
	if animate:
		for raw: Dictionary in frames[index].events:
			arena._on_action(GameAction.create(int(raw.type),int(raw.player),raw.data,int(raw.turn),str(raw.description)))
	battle.call("_refresh_ui")
	var p: Array = public_frames[index].state.players
	scoreboard.text = "剩余奖赏   玛俐 %d  :  %d 多龙    |    第 %d 回合" % [p[0].prizes_remaining,p[1].prizes_remaining,public_frames[index].state.turn]

func _comment(clip: Dictionary, start_index: int, end_index: int) -> void:
	var observed: Array = []
	for i: int in range(start_index,end_index+1):
		for raw: Dictionary in public_frames[i].events:
			var event := raw.duplicate(true)
			event.id = int(event.id) # Restore the production integer event contract after JSON.
			observed.append(event)
	var state: Dictionary = public_frames[end_index].state
	var knowledge: Dictionary = {}
	for i: int in range(end_index+1): knowledge = commentary.knowledge.observe(public_frames[i].state)
	model.clip = clip
	var packet := {"snapshot_id":int(clip.end_step),"state":state,"before":public_frames[start_index].state,"events":observed,"knowledge":knowledge}
	commentary.session.offer(packet)
	for attempt in 2:
		commentary.session.next_request_at = 0.0
		commentary.session.tick(float(Time.get_ticks_msec())/1000.0)
		for wait_index in 12:
			await get_tree().process_frame
			if not commentary.session.in_flight: break
	if commentary.panel.body.text != str(clip.text):
		push_error("Caption failed protocol validation at %s: %s / %s" % [clip.end_step,commentary.panel.status.text,commentary.panel.body.text])
		get_tree().quit(4)
	commentary.panel.source.text = "赛场解说 · 文字测试"
	commentary.panel.status.text = "真实对局回放 · 子 Agent 模拟模型 · 0 次付费调用"

func _draw_frames(count: int) -> void:
	for i in count:
		commentary._layout()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not preview:
			var data := get_viewport().get_texture().get_image().save_jpg_to_buffer(.92)
			stream.put_u32(data.size())
			if stream.put_data(data) != OK:
				push_error("Encoder stream failed")
				get_tree().quit(5)
				return
		frame_count += 1

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color("101f26")
	bar.size = Vector2(1600,56)
	layer.add_child(bar)
	title = _label(bar,Vector2(22,12),24,Color("e8d59a"))
	title.text = "PTCG DOJO / 18.5 实战解说"
	scoreboard = _label(bar,Vector2(890,15),21,Color("d4e9e7"))
	var bottom := ColorRect.new()
	bottom.color = Color("101f26")
	bottom.position = Vector2(0,875)
	bottom.size = Vector2(1600,25)
	layer.add_child(bottom)
	footer = _label(bottom,Vector2(20,2),15,Color("93b7ba"))
	footer.text = "18.5 玛俐长毛巨魔（本地规则）  VS  幽影接力 · 18.5 多龙黑夜魔灵 0.9.1（开发者策略）   /   实际对局 · 关键回合剪辑"
	cover = ColorRect.new()
	cover.color = Color("0b1920",.98)
	cover.size = Vector2(1600,900)
	layer.add_child(cover)
	var tag := _label(cover,Vector2(110,150),22,Color("68c7c0"))
	tag.text = "PTCG DECK AGENT    /    MATCH COMMENTARY"
	cover_title = _label(cover,Vector2(110,245),52,Color("f1dfb3"))
	cover_detail = _label(cover,Vector2(114,370),29,Color("c5d8dc"))
	var stripe := ColorRect.new()
	stripe.color = Color("68c7c0")
	stripe.position = Vector2(110,333)
	stripe.size = Vector2(90,4)
	cover.add_child(stripe)

func _label(parent: Node, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
